from pathlib import Path
import re

root = Path.cwd()

ranked_path = root / "src/client/Pages/RankedPage.lua"
if ranked_path.exists():
	text = ranked_path.read_text(encoding="utf-8", errors="ignore")

	text = re.sub(r"\nlocal function vtrIsRankedUiRoot\(obj\).*?\nend\s*\n\s*local function vtrFixRankedRogueText\(root\).*?\nend\s*", "\n", text, flags=re.S)
	text = re.sub(r"\nlocal function vtrSafeRankNumber\(value\).*?\nend\s*\n\s*local function vtrRankedPathData\(value\).*?\nend\s*\n\s*local function vtrFixPathStatText\(root, rankedData\).*?\nend\s*", "\n", text, flags=re.S)
	text = re.sub(r"\n\s*vtrFixRankedRogueText\([^\n]*\)\s*", "\n", text)
	text = re.sub(r"\n\s*vtrFixPathStatText\([^\n]*\)\s*", "\n", text)
	text = re.sub(r"\n\s*task\.defer\(function\(\)\s*\n\s*vtrFixRankedRogueText\(script\.Parent\)\s*\n\s*end\)\s*", "\n", text, flags=re.S)

	text = text.replace("ScrollBarThickness = 0", "ScrollBarThickness = 6")
	text = text.replace("ScrollingEnabled = false", "ScrollingEnabled = true")
	text = text.replace("AutomaticCanvasSize = Enum.AutomaticSize.None", "AutomaticCanvasSize = Enum.AutomaticSize.Y")

	ranked_path.write_text(text.strip() + "\n", encoding="utf-8")
	print("cleaned src/client/Pages/RankedPage.lua")

client_fix = root / "src/client/Services/RankedStatsPanelFixClient.lua"
client_fix.parent.mkdir(parents=True, exist_ok=True)

client_fix.write_text(r'''
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local RankedStatsPanelFixClient = {}

local started = false
local lastFix = 0

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function textOf(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		return tostring(obj.Text or "")
	end
	return ""
end

local function isText(obj, value)
	return lower(textOf(obj)) == lower(value)
end

local function findRankedPanel(playerGui)
	local recordLabel

	for _, obj in ipairs(playerGui:GetDescendants()) do
		if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isText(obj, "PATH RECORD") then
			recordLabel = obj
			break
		end
	end

	if not recordLabel then
		return nil
	end

	local current = recordLabel.Parent
	while current and current ~= playerGui do
		if current:IsA("Frame") or current:IsA("CanvasGroup") or current:IsA("ScrollingFrame") then
			local hasDivision = false
			for _, child in ipairs(current:GetDescendants()) do
				if (child:IsA("TextLabel") or child:IsA("TextButton")) and string.find(lower(textOf(child)), "division") then
					hasDivision = true
					break
				end
			end

			if hasDivision then
				return current
			end
		end

		current = current.Parent
	end

	return recordLabel.Parent
end

local function findLabel(root, text)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if isText(obj, text) then
				return obj
			end
		end
	end

	return nil
end

local function findRecordValue(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			local raw = tostring(obj.Text or "")
			local wins, draws, losses = string.match(raw, "(%d+)%s*W%s*/%s*(%d+)%s*D%s*/%s*(%d+)%s*L")
			if wins and draws and losses then
				return obj, wins, draws, losses
			end
		end
	end

	return nil, nil, nil, nil
end

local function makeValue(root, name)
	local label = root:FindFirstChild(name)

	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 30
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = false
	label.TextScaled = false
	label.AutomaticSize = Enum.AutomaticSize.None
	label.ZIndex = 50
	label.Parent = root

	return label
end

local function relative(root, absolute)
	return Vector2.new(absolute.X - root.AbsolutePosition.X, absolute.Y - root.AbsolutePosition.Y)
end

local function stabilizeValue(root, header, valueLabel, text, y)
	if not header or not valueLabel then
		return
	end

	local pos = relative(root, Vector2.new(header.AbsolutePosition.X, y))
	valueLabel.AnchorPoint = Vector2.new(0, 0)
	valueLabel.Position = UDim2.fromOffset(pos.X, pos.Y)
	valueLabel.Size = UDim2.fromOffset(140, 46)
	valueLabel.Text = tostring(text)
	valueLabel.Visible = true
	valueLabel.TextTransparency = 0
	valueLabel.LayoutOrder = 0
end

local function hideLooseDigits(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if obj.Name ~= "VTRStablePathWins" and obj.Name ~= "VTRStablePathLosses" then
				local clean = string.gsub(tostring(obj.Text or ""), "%s+", "")
				if string.match(clean, "^%d+$") and obj.AbsoluteSize.Y < 80 then
					local parentName = lower(obj.Parent and obj.Parent.Name or "")
					local objName = lower(obj.Name)
					if string.find(parentName, "path") or string.find(objName, "path") or string.find(parentName, "stat") or string.find(objName, "stat") then
						obj.Visible = false
						obj.TextTransparency = 1
					end
				end
			end
		elseif obj:IsA("ScrollingFrame") and obj == root then
			obj.CanvasPosition = Vector2.new(0, 0)
		end
	end
end

function RankedStatsPanelFixClient.Fix()
	local now = os.clock()
	if now - lastFix < 0.15 then
		return
	end

	lastFix = now

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local root = findRankedPanel(playerGui)
	if not root then
		return
	end

	local recordValue, wins, _, losses = findRecordValue(root)
	if not recordValue then
		return
	end

	local winsHeader = findLabel(root, "PATH WINS")
	local lossesHeader = findLabel(root, "PATH LOSSES")
	local y = recordValue.AbsolutePosition.Y

	local winsValue = makeValue(root, "VTRStablePathWins")
	local lossesValue = makeValue(root, "VTRStablePathLosses")

	stabilizeValue(root, winsHeader, winsValue, wins, y)
	stabilizeValue(root, lossesHeader, lossesValue, losses, y)
	hideLooseDigits(root)

	if root:IsA("ScrollingFrame") then
		root.CanvasPosition = Vector2.new(0, 0)
	end
end

function RankedStatsPanelFixClient.Start()
	if started then
		return
	end

	started = true

	task.defer(function()
		for _ = 1, 20 do
			RankedStatsPanelFixClient.Fix()
			task.wait(0.25)
		end
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.DescendantAdded:Connect(function()
		task.defer(RankedStatsPanelFixClient.Fix)
	end)
end

RankedStatsPanelFixClient.Start()

return RankedStatsPanelFixClient
'''.strip() + "\n", encoding="utf-8")

runner = root / "src/client/RankedStatsPanelFix.client.lua"
runner.write_text('require(script.Parent.Services.RankedStatsPanelFixClient)\n', encoding="utf-8")

service = root / "src/server/Services/SevenWinLoginRewardService.lua"
service.parent.mkdir(parents=True, exist_ok=True)

service.write_text(r'''
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedFolder = ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage
local Config = require(sharedFolder:WaitForChild("SevenWinLoginRewardConfig"))

local store = DataStoreService:GetDataStore(Config.ClaimKey .. "_Path_v3")
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

	if not pending and pathWins >= Config.MinimumWins then
		pending = {
			rewards = rollRewards(pathWins),
			pathWins = pathWins,
			totalWins = totalWins,
		}
	end

	if not pending or typeof(pending.rewards) ~= "table" or #pending.rewards == 0 then
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
'''.strip() + "\n", encoding="utf-8")

print("patched src/client/Services/RankedStatsPanelFixClient.lua")
print("patched src/client/RankedStatsPanelFix.client.lua")
print("patched src/server/Services/SevenWinLoginRewardService.lua")