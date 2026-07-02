local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local Config = require(sharedFolder and sharedFolder:WaitForChild("SevenWinLoginRewardConfig") or ReplicatedStorage:WaitForChild("SevenWinLoginRewardConfig"))

local store = DataStoreService:GetDataStore(Config.ClaimKey)
local pendingByUserId = {}
local started = false

local remotes = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = Config.RemoteFolderName
	remotes.Parent = ReplicatedStorage
end

local pendingRemote = remotes:FindFirstChild(Config.PendingRemoteName)
if not pendingRemote then
	pendingRemote = Instance.new("RemoteEvent")
	pendingRemote.Name = Config.PendingRemoteName
	pendingRemote.Parent = remotes
end

local confirmRemote = remotes:FindFirstChild(Config.ConfirmRemoteName)
if not confirmRemote then
	confirmRemote = Instance.new("RemoteFunction")
	confirmRemote.Name = Config.ConfirmRemoteName
	confirmRemote.Parent = remotes
end

local function findLeaderstatWins(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	local wins = leaderstats:FindFirstChild("Wins") or leaderstats:FindFirstChild("wins") or leaderstats:FindFirstChild("WINS")
	if wins and wins:IsA("ValueBase") then
		return wins
	end

	return nil
end

local function getWins(player)
	local direct = player:GetAttribute("Wins") or player:GetAttribute("wins") or player:GetAttribute("TotalWins") or player:GetAttribute("totalWins")
	if typeof(direct) == "number" then
		return math.max(0, math.floor(direct))
	end

	local leaderstatWins = findLeaderstatWins(player)
	if leaderstatWins then
		return math.max(0, math.floor(tonumber(leaderstatWins.Value) or 0))
	end

	return 0
end

local function normalizePackName(pack)
	if typeof(pack) == "string" then
		return pack
	end

	if typeof(pack) == "table" then
		return pack.Id or pack.id or pack.Name or pack.name or pack.Key or pack.key or pack.PackId or pack.packId
	end

	return nil
end

local function collectPacksFromTable(packTable, out, seen)
	for key, value in pairs(packTable) do
		local enabled = true

		if typeof(value) == "table" then
			if value.Enabled == false or value.enabled == false or value.Available == false or value.available == false then
				enabled = false
			end
		end

		if enabled then
			local name = normalizePackName(value) or (typeof(key) == "string" and key or nil)
			if typeof(name) == "string" and name ~= "" and not seen[name] then
				seen[name] = true
				table.insert(out, name)
			end
		end
	end
end

local function getAvailablePacks()
	local out = {}
	local seen = {}

	for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
		if inst:IsA("ModuleScript") and string.find(string.lower(inst.Name), "pack") then
			local ok, packTable = pcall(require, inst)
			if ok and typeof(packTable) == "table" then
				collectPacksFromTable(packTable, out, seen)
			end
		end
	end

	if #out == 0 then
		for _, packName in ipairs(Config.FallbackPacks) do
			if not seen[packName] then
				seen[packName] = true
				table.insert(out, packName)
			end
		end
	end

	table.sort(out)
	return out
end

local function rollRewards(wins)
	local packs = getAvailablePacks()
	local rewards = {}
	local chance = math.clamp(Config.BaseChance + wins * Config.ChancePerWin, 0, Config.MaxChance)

	for _ = 1, wins do
		if math.random() <= chance and #packs > 0 then
			table.insert(rewards, packs[math.random(1, #packs)])
		end
	end

	if #rewards == 0 and #packs > 0 then
		table.insert(rewards, packs[math.random(1, #packs)])
	end

	return rewards
end

local function callGrantFunction(service, player, packName)
	local names = {
		"GrantPack",
		"AddPack",
		"GivePack",
		"AwardPack",
		"AddPackToInventory",
		"GrantItem",
		"AddItem",
		"GiveItem",
	}

	for _, name in ipairs(names) do
		local fn = service[name]
		if typeof(fn) == "function" then
			local ok = pcall(function()
				fn(service, player, packName, 1)
			end)

			if ok then
				return true
			end

			ok = pcall(function()
				fn(player, packName, 1)
			end)

			if ok then
				return true
			end

			ok = pcall(function()
				fn(service, player.UserId, packName, 1)
			end)

			if ok then
				return true
			end
		end
	end

	return false
end

local function tryGrantThroughServices(player, packName)
	local folders = {
		script.Parent,
		ServerScriptService:FindFirstChild("Services"),
		ServerScriptService,
	}

	for _, folder in ipairs(folders) do
		if folder then
			for _, inst in ipairs(folder:GetChildren()) do
				if inst:IsA("ModuleScript") and (string.find(string.lower(inst.Name), "inventory") or string.find(string.lower(inst.Name), "pack") or string.find(string.lower(inst.Name), "reward") or string.find(string.lower(inst.Name), "data")) then
					local ok, service = pcall(require, inst)
					if ok and typeof(service) == "table" and callGrantFunction(service, player, packName) then
						return true
					end
				end
			end
		end
	end

	return false
end

local inventoryStore = DataStoreService:GetDataStore("PlayerPackInventory_v1")

local function grantFallback(player, packName)
	local key = tostring(player.UserId)
	pcall(function()
		inventoryStore:UpdateAsync(key, function(old)
			old = typeof(old) == "table" and old or {}
			old[packName] = (tonumber(old[packName]) or 0) + 1
			return old
		end)
	end)

	local folder = player:FindFirstChild("PackInventory")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PackInventory"
		folder.Parent = player
	end

	local value = folder:FindFirstChild(packName)
	if not value then
		value = Instance.new("IntValue")
		value.Name = packName
		value.Parent = folder
	end

	value.Value += 1
end

local function grantPack(player, packName)
	if not tryGrantThroughServices(player, packName) then
		grantFallback(player, packName)
	end
end

local function hasClaimed(player)
	local ok, result = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)

	return ok and result == true
end

local function markClaimed(player)
	pcall(function()
		store:SetAsync(tostring(player.UserId), true)
	end)
end

local function sendPending(player)
	if hasClaimed(player) then
		return
	end

	local wins = getWins(player)
	if wins < Config.MinimumWins then
		return
	end

	local rewards = rollRewards(wins)
	if #rewards == 0 then
		return
	end

	pendingByUserId[player.UserId] = rewards
	pendingRemote:FireClient(player, rewards, wins)
end

local function bindPlayer(player)
	task.defer(function()
		task.wait(2)
		sendPending(player)
	end)

	local leaderstatWins = findLeaderstatWins(player)
	if leaderstatWins then
		leaderstatWins.Changed:Connect(function()
			if not pendingByUserId[player.UserId] then
				sendPending(player)
			end
		end)
	end

	player:GetAttributeChangedSignal("Wins"):Connect(function()
		if not pendingByUserId[player.UserId] then
			sendPending(player)
		end
	end)

	player:GetAttributeChangedSignal("TotalWins"):Connect(function()
		if not pendingByUserId[player.UserId] then
			sendPending(player)
		end
	end)
end

confirmRemote.OnServerInvoke = function(player)
	local rewards = pendingByUserId[player.UserId]
	if not rewards then
		return false, {}
	end

	if hasClaimed(player) then
		pendingByUserId[player.UserId] = nil
		return false, {}
	end

	for _, packName in ipairs(rewards) do
		grantPack(player, packName)
	end

	markClaimed(player)
	pendingByUserId[player.UserId] = nil

	return true, rewards
end

local SevenWinLoginRewardService = {}

function SevenWinLoginRewardService.Start()
	if started then
		return
	end

	started = true

	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end

	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		pendingByUserId[player.UserId] = nil
	end)
end

SevenWinLoginRewardService.Start()

return SevenWinLoginRewardService
