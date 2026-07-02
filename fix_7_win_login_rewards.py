from pathlib import Path

root = Path.cwd()

def write(path, text):
    p = root / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text.strip() + "\n", encoding="utf-8")

write("src/shared/SevenWinLoginRewardConfig.lua", r'''
local SevenWinLoginRewardConfig = {}

SevenWinLoginRewardConfig.MinimumWins = 7
SevenWinLoginRewardConfig.BaseChance = 0.55
SevenWinLoginRewardConfig.ChancePerWin = 0.035
SevenWinLoginRewardConfig.MaxChance = 0.95
SevenWinLoginRewardConfig.ClaimKey = "SevenWinLoginReward_v1"
SevenWinLoginRewardConfig.RemoteFolderName = "SevenWinLoginRewardRemotes"
SevenWinLoginRewardConfig.PendingRemoteName = "PendingSevenWinLoginReward"
SevenWinLoginRewardConfig.ConfirmRemoteName = "ConfirmSevenWinLoginReward"
SevenWinLoginRewardConfig.FallbackPacks = {
	"BronzePack",
	"SilverPack",
	"GoldPack",
}

return SevenWinLoginRewardConfig
''')

write("src/server/Services/SevenWinLoginRewardService.lua", r'''
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
''')

write("src/server/SevenWinLoginReward.server.lua", r'''
require(script.Parent.Services.SevenWinLoginRewardService)
''')

write("src/client/Components/SevenWinLoginRewardPanel.lua", r'''
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local SevenWinLoginRewardPanel = {}

local function makeLabel(parent, name, text, size, position, fontSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.GothamBold
	label.TextSize = fontSize
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

function SevenWinLoginRewardPanel.Show(rewards, wins, onConfirm)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("SevenWinLoginRewardGui")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SevenWinLoginRewardGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10000
	gui.Parent = playerGui

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0.28
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(540, 420)
	panel.BackgroundColor3 = Color3.fromRGB(21, 27, 39)
	panel.Parent = shade

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(83, 154, 255)
	stroke.Parent = panel

	makeLabel(panel, "Title", "7 WIN LOGIN REWARD", UDim2.new(1, -48, 0, 48), UDim2.fromOffset(24, 22), 28)
	makeLabel(panel, "SubTitle", tostring(wins) .. " wins detected. You earned these packs.", UDim2.new(1, -48, 0, 34), UDim2.fromOffset(24, 68), 17)

	local list = Instance.new("ScrollingFrame")
	list.Name = "RewardList"
	list.BackgroundColor3 = Color3.fromRGB(13, 18, 28)
	list.BackgroundTransparency = 0.15
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(32, 120)
	list.Size = UDim2.new(1, -64, 1, -206)
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = panel

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 14)
	listCorner.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = list

	local counts = {}
	for _, packName in ipairs(rewards) do
		counts[packName] = (counts[packName] or 0) + 1
	end

	local names = {}
	for packName in pairs(counts) do
		table.insert(names, packName)
	end
	table.sort(names)

	for index, packName in ipairs(names) do
		local row = Instance.new("Frame")
		row.Name = packName
		row.BackgroundColor3 = Color3.fromRGB(31, 43, 65)
		row.Size = UDim2.new(1, 0, 0, 54)
		row.LayoutOrder = index
		row.Parent = list

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 12)
		rowCorner.Parent = row

		makeLabel(row, "PackName", packName, UDim2.new(1, -92, 1, 0), UDim2.fromOffset(18, 0), 18).TextXAlignment = Enum.TextXAlignment.Left
		makeLabel(row, "Count", "x" .. tostring(counts[packName]), UDim2.fromOffset(66, 1, 1, 0), UDim2.new(1, -78, 0, 0), 20)
	end

	local button = Instance.new("TextButton")
	button.Name = "ConfirmButton"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -28)
	button.Size = UDim2.fromOffset(250, 54)
	button.BackgroundColor3 = Color3.fromRGB(48, 139, 255)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 20
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = "CONFIRM"
	button.AutoButtonColor = true
	button.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 14)
	buttonCorner.Parent = button

	panel.Size = UDim2.fromOffset(500, 386)
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(540, 420),
	}):Play()

	local busy = false
	button.MouseButton1Click:Connect(function()
		if busy then
			return
		end

		busy = true
		button.Text = "SENDING..."
		local ok = onConfirm()

		if ok then
			gui:Destroy()
		else
			button.Text = "TRY AGAIN"
			busy = false
		end
	end)
end

return SevenWinLoginRewardPanel
''')

write("src/client/Services/SevenWinLoginRewardClient.lua", r'''
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local Config = require(sharedFolder and sharedFolder:WaitForChild("SevenWinLoginRewardConfig") or ReplicatedStorage:WaitForChild("SevenWinLoginRewardConfig"))
local Panel = require(script.Parent.Parent.Components.SevenWinLoginRewardPanel)

local remotes = ReplicatedStorage:WaitForChild(Config.RemoteFolderName)
local pendingRemote = remotes:WaitForChild(Config.PendingRemoteName)
local confirmRemote = remotes:WaitForChild(Config.ConfirmRemoteName)

local started = false

local SevenWinLoginRewardClient = {}

function SevenWinLoginRewardClient.Start()
	if started then
		return
	end

	started = true

	pendingRemote.OnClientEvent:Connect(function(rewards, wins)
		if typeof(rewards) ~= "table" or #rewards == 0 then
			return
		end

		Panel.Show(rewards, wins, function()
			local ok = false
			local success = pcall(function()
				ok = confirmRemote:InvokeServer()
			end)

			return success and ok == true
		end)
	end)
end

SevenWinLoginRewardClient.Start()

return SevenWinLoginRewardClient
''')

write("src/client/SevenWinLoginReward.client.lua", r'''
require(script.Parent.Services.SevenWinLoginRewardClient)
''')