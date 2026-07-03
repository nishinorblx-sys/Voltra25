local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedFolder = ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage
local Config = require(sharedFolder:WaitForChild("SevenWinLoginRewardConfig"))

local store = DataStoreService:GetDataStore(Config.ClaimKey .. "_Path_v4")
local pendingByUserId = {}
local started = false

local function getRemotesRoot()
	local vtr = ReplicatedStorage:FindFirstChild("VTR")
	if not vtr then
		vtr = Instance.new("Folder")
		vtr.Name = "VTR"
		vtr.Parent = ReplicatedStorage
	end

	local remotesRoot = vtr:FindFirstChild("Remotes")
	if not remotesRoot then
		remotesRoot = Instance.new("Folder")
		remotesRoot.Name = "Remotes"
		remotesRoot.Parent = vtr
	end

	return remotesRoot
end

local remotesRoot = getRemotesRoot()
local remotes = remotesRoot:FindFirstChild(Config.RemoteFolderName)
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = Config.RemoteFolderName
	remotes.Parent = remotesRoot
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
	for _, name in ipairs({ "Wins", "wins", "TotalWins", "totalWins", "PathWins" }) do
		local value = player:GetAttribute(name)
		if typeof(value) == "number" then
			return math.max(0, math.floor(value))
		end
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

		if typeof(value) == "table" and (value.Enabled == false or value.enabled == false or value.Available == false or value.available == false) then
			enabled = false
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

local function rollRewards(pathWins)
	local packs = getAvailablePacks()
	local rewards = {}

	if #packs == 0 then
		return rewards
	end

	for _ = 1, math.max(1, pathWins) do
		table.insert(rewards, packs[math.random(1, #packs)])
	end

	return rewards
end

local function readState(player)
	local ok, result = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)

	if ok and typeof(result) == "table" then
		result.claimedWins = tonumber(result.claimedWins) or 0
		return result
	end

	if ok and result == true then
		return {
			claimedWins = getWins(player),
		}
	end

	return {
		claimedWins = 0,
	}
end

local function writeState(player, state)
	pcall(function()
		store:SetAsync(tostring(player.UserId), state)
	end)
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

local function getPathWins(player)
	local wins = getWins(player)
	local state = readState(player)
	return math.max(0, wins - (tonumber(state.claimedWins) or 0)), wins, state
end

local function sendPending(player)
	local pathWins, totalWins = getPathWins(player)
	if pathWins < Config.MinimumWins then
		return
	end

	local rewards = rollRewards(pathWins)
	if #rewards == 0 then
		return
	end

	pendingByUserId[player.UserId] = {
		rewards = rewards,
		pathWins = pathWins,
		totalWins = totalWins,
	}

	pendingRemote:FireClient(player, rewards, pathWins)
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

	for _, attr in ipairs({ "Wins", "wins", "TotalWins", "totalWins", "PathWins" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if not pendingByUserId[player.UserId] then
				sendPending(player)
			end
		end)
	end
end

confirmRemote.OnServerInvoke = function(player)
	local pending = pendingByUserId[player.UserId]
	local pathWins, totalWins, state = getPathWins(player)

	if pathWins < Config.MinimumWins then
		state.claimedWins = totalWins
		state.updatedAt = os.time()
		writeState(player, state)
		pendingByUserId[player.UserId] = nil

		player:SetAttribute("PathWins", 0)
		player:SetAttribute("PathLosses", 0)
		player:SetAttribute("PathGames", 0)
		player:SetAttribute("DivisionPathWins", 0)
		player:SetAttribute("DivisionPathLosses", 0)
		player:SetAttribute("DivisionPathGames", 0)

		return false, {}
	end

	if not pending then
		pending = {
			rewards = rollRewards(pathWins),
			pathWins = pathWins,
			totalWins = totalWins,
		}
	end

	if typeof(pending.rewards) ~= "table" or #pending.rewards == 0 then
		state.claimedWins = totalWins
		state.updatedAt = os.time()
		writeState(player, state)
		pendingByUserId[player.UserId] = nil
		return false, {}
	end

	for _, packName in ipairs(pending.rewards) do
		grantPack(player, packName)
	end

	state.claimedWins = totalWins
	state.lastClaimedPathWins = pending.pathWins
	state.updatedAt = os.time()
	writeState(player, state)

	pendingByUserId[player.UserId] = nil

	player:SetAttribute("PathWins", 0)
	player:SetAttribute("PathLosses", 0)
	player:SetAttribute("PathGames", 0)
	player:SetAttribute("DivisionPathWins", 0)
	player:SetAttribute("DivisionPathLosses", 0)
	player:SetAttribute("DivisionPathGames", 0)

	return true, pending.rewards
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
