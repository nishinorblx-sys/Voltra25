local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VTRReplicated = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRReplicated"))
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local folder = VTRReplicated.GetOrCreateRemoteFolder("PackRewardAnimationRemotes")

local showRemote = folder:FindFirstChild("ShowPackRewardAnimation")
if not showRemote then
	showRemote = Instance.new("RemoteEvent")
	showRemote.Name = "ShowPackRewardAnimation"
	showRemote.Parent = folder
end

local ackRemote = folder:FindFirstChild("AckPackRewardAnimation")
if not ackRemote then
	ackRemote = Instance.new("RemoteEvent")
	ackRemote.Name = "AckPackRewardAnimation"
	ackRemote.Parent = folder
end

local store = DataStoreService:GetDataStore("PendingPackRewardAnimations_v3")
local pending = {}
local started = false

local function normalizePack(pack)
	if typeof(pack) == "string" then
		return pack
	end

	if typeof(pack) == "table" then
		return pack.Id or pack.id or pack.Name or pack.name or pack.PackId or pack.packId or pack.Key or pack.key
	end

	if typeof(pack) == "Instance" then
		return pack:GetAttribute("PackId") or pack:GetAttribute("PackName") or pack.Name
	end

	return nil
end

local function keyFor(playerOrUserId)
	local userId = typeof(playerOrUserId) == "Instance" and playerOrUserId.UserId or playerOrUserId
	return tostring(userId)
end

local function cleanQueue(queue)
	local out = {}

	if typeof(queue) ~= "table" then
		return out
	end

	for _, entry in ipairs(queue) do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and typeof(entry.pack) == "string" and entry.pack ~= "" then
			table.insert(out, entry)
		end
	end

	return out
end

local function loadQueue(player)
	local ok, result = pcall(function()
		return store:GetAsync(keyFor(player))
	end)

	local queue = ok and cleanQueue(result) or {}
	pending[player.UserId] = queue
	return queue
end

local function saveQueue(playerOrUserId, queue)
	pcall(function()
		store:SetAsync(keyFor(playerOrUserId), cleanQueue(queue))
	end)
end

local function fireQueue(player, queue)
	if typeof(queue) ~= "table" or #queue == 0 then
		return
	end

	showRemote:FireClient(player, queue)
end

local PendingPackAnimationService = {}

function PendingPackAnimationService.Queue(player, pack)
	if not player or not player:IsA("Player") then
		return nil
	end

	local packName = normalizePack(pack)
	if not packName or packName == "" then
		return nil
	end

	local entry = {
		id = HttpService:GenerateGUID(false),
		pack = packName,
		t = os.time(),
	}

	local queue = pending[player.UserId]
	if typeof(queue) ~= "table" then
		queue = loadQueue(player)
	end

	table.insert(queue, entry)
	pending[player.UserId] = queue
	saveQueue(player, queue)

	task.delay(2, function()
		if player.Parent == Players and player:GetAttribute("VTRInMatch") ~= true and player:GetAttribute("VTRRankedMatchEnding") ~= true then
			fireQueue(player, { entry })
		end
	end)

	return entry.id
end

function PendingPackAnimationService.Flush(player)
	local queue = pending[player.UserId]
	if typeof(queue) ~= "table" then
		queue = loadQueue(player)
	end

	fireQueue(player, queue)
end

function PendingPackAnimationService.Ack(player, ids)
	if not player or not player:IsA("Player") then
		return
	end

	if typeof(ids) ~= "table" then
		return
	end

	local remove = {}
	for _, id in ipairs(ids) do
		if typeof(id) == "string" then
			remove[id] = true
		end
	end

	local queue = pending[player.UserId]
	if typeof(queue) ~= "table" then
		queue = loadQueue(player)
	end

	local kept = {}
	for _, entry in ipairs(queue) do
		if not remove[entry.id] then
			table.insert(kept, entry)
		end
	end

	pending[player.UserId] = kept
	saveQueue(player, kept)
end

function PendingPackAnimationService.Start()
	if started then
		return
	end

	started = true

	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent ~= Players then
				return
			end

			local queue = loadQueue(player)
			fireQueue(player, queue)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pending[player.UserId] = nil
	end)

	ackRemote.OnServerEvent:Connect(function(player, ids)
		PendingPackAnimationService.Ack(player, ids)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			local queue = loadQueue(player)
			fireQueue(player, queue)
		end)
	end
end

PendingPackAnimationService.Start()

return PendingPackAnimationService
