--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("VTR"):WaitForChild("Shared")
local NetworkConfig = require(Shared:WaitForChild("NetworkConfig"))
local Theme = require(Shared:WaitForChild("Theme"))

local player = Players.LocalPlayer
if RunService:IsStudio() and player.UserId <= 0 then
	return
end

local remote = ReplicatedStorage:WaitForChild("VTR"):WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.DeveloperFunction) :: RemoteFunction

local ok, response = pcall(function()
	return remote:InvokeServer("GetDeveloperPackGrant", {})
end)
if not ok or type(response) ~= "table" or response.Success ~= true or type(response.Data) ~= "table" then
	return
end

local data = response.Data
local packs = type(data.Packs) == "table" and data.Packs or {}
local players = type(data.Players) == "table" and data.Players or {}
if #packs == 0 then return end

local selectedPack = 1
local selectedPlayer = 1
local quantity = 1
local collapsed = false
local suppressedForOnboarding = player:GetAttribute("VTRForceWorldCupOnboardingRoute") == true

local gui = Instance.new("ScreenGui")
gui.Name = "OwnerPackGrantBar"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 900
gui.Enabled = not suppressedForOnboarding
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(.5, 0)
bar.BackgroundColor3 = Theme.Colors.Black
bar.BackgroundTransparency = .04
bar.BorderSizePixel = 0
bar.Position = UDim2.new(.5, 0, 0, 10)
bar.Size = UDim2.fromOffset(880, 46)
bar.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = bar

local stroke = Instance.new("UIStroke")
stroke.Color = Theme.Colors.Electric
stroke.Transparency = .25
stroke.Thickness = 1
stroke.Parent = bar

local function makeText(className: string, text: string, x: number, width: number): any
	local item = Instance.new(className)
	item.Name = text:gsub("%W", "") .. className
	item.BackgroundColor3 = Theme.Colors.Gunmetal
	item.BorderSizePixel = 0
	item.Position = UDim2.fromOffset(x, 8)
	item.Size = UDim2.fromOffset(width, 30)
	item.Font = Theme.Fonts.Strong
	item.Text = text
	item.TextColor3 = Theme.Colors.White
	item.TextSize = 10
	item.TextXAlignment = Enum.TextXAlignment.Center
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.Parent = bar
	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, 6)
	itemCorner.Parent = item
	return item
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.fromOffset(86, 30)
title.Font = Theme.Fonts.Display
title.Text = "DEV PACKS"
title.TextColor3 = Theme.Colors.Electric
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local targetBox = makeText("TextBox", "PLAYER", 102, 136) :: TextBox
targetBox.ClearTextOnFocus = false
targetBox.PlaceholderText = "PLAYER"
targetBox.Text = players[1] and tostring(players[1].Name) or ""

local prevPlayer = makeText("TextButton", "<", 244, 28) :: TextButton
local nextPlayer = makeText("TextButton", ">", 276, 28) :: TextButton
local packButton = makeText("TextButton", "", 314, 178) :: TextButton
local qtyMinus = makeText("TextButton", "-", 500, 30) :: TextButton
local qtyLabel = makeText("TextLabel", "x1", 534, 42) :: TextLabel
local qtyPlus = makeText("TextButton", "+", 580, 30) :: TextButton
local grant = makeText("TextButton", "GIVE", 620, 74) :: TextButton
grant.BackgroundColor3 = Theme.Colors.Electric
grant.TextColor3 = Theme.Colors.Black
local cancelFive = makeText("TextButton", "CANCEL 5V5", 704, 96) :: TextButton
cancelFive.BackgroundColor3 = Theme.Colors.Danger
cancelFive.TextColor3 = Theme.Colors.White
local hide = makeText("TextButton", "_", 812, 42) :: TextButton

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(102, 38)
status.Size = UDim2.fromOffset(590, 18)
status.Font = Theme.Fonts.Strong
status.Text = ""
status.TextColor3 = Theme.Colors.Muted
status.TextSize = 8
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = bar

local function selectedPackData(): any
	return packs[math.clamp(selectedPack, 1, #packs)]
end

local function selectedPlayerData(): any?
	return players[math.clamp(selectedPlayer, 1, math.max(#players, 1))]
end

local function setStatus(text: string, success: boolean?)
	status.Text = text
	status.TextColor3 = success == false and Theme.Colors.Danger or success == true and Theme.Colors.Electric or Theme.Colors.Muted
	task.delay(3, function()
		if status.Parent and status.Text == text then status.Text = "" end
	end)
end

local function refresh()
	gui.Enabled = not suppressedForOnboarding
	local pack = selectedPackData()
	packButton.Text = pack and string.upper(tostring(pack.Name or pack.Id)) or "PACK"
	qtyLabel.Text = "x" .. tostring(quantity)
	local selected = selectedPlayerData()
	if selected and targetBox.Text == "" then
		targetBox.Text = tostring(selected.Name)
	end
end

player:GetAttributeChangedSignal("VTRForceWorldCupOnboardingRoute"):Connect(function()
	suppressedForOnboarding = player:GetAttribute("VTRForceWorldCupOnboardingRoute") == true
	gui.Enabled = not suppressedForOnboarding
end)

local function cyclePlayer(delta: number)
	if #players == 0 then return end
	selectedPlayer = ((selectedPlayer - 1 + delta) % #players) + 1
	local selected = selectedPlayerData()
	targetBox.Text = selected and tostring(selected.Name) or ""
end

local function refreshServerData()
	local refreshOk, refreshed = pcall(function()
		return remote:InvokeServer("GetDeveloperPackGrant", {})
	end)
	if refreshOk and type(refreshed) == "table" and refreshed.Success == true and type(refreshed.Data) == "table" then
		packs = type(refreshed.Data.Packs) == "table" and refreshed.Data.Packs or packs
		players = type(refreshed.Data.Players) == "table" and refreshed.Data.Players or players
		selectedPack = math.clamp(selectedPack, 1, math.max(#packs, 1))
		selectedPlayer = math.clamp(selectedPlayer, 1, math.max(#players, 1))
		refresh()
	end
end

prevPlayer.Activated:Connect(function() cyclePlayer(-1) end)
nextPlayer.Activated:Connect(function() cyclePlayer(1) end)
packButton.Activated:Connect(function()
	selectedPack = (selectedPack % #packs) + 1
	refresh()
end)
qtyMinus.Activated:Connect(function()
	quantity = math.max(1, quantity - 1)
	refresh()
end)
qtyPlus.Activated:Connect(function()
	quantity = math.min(25, quantity + 1)
	refresh()
end)
hide.Activated:Connect(function()
	collapsed = not collapsed
		local targetSize = collapsed and UDim2.fromOffset(110, 46) or UDim2.fromOffset(880, 46)
	TweenService:Create(bar, TweenInfo.new(.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
	for _, child in bar:GetChildren() do
		if child:IsA("GuiObject") and child ~= title and child ~= hide then
			child.Visible = not collapsed
		end
	end
	hide.Position = collapsed and UDim2.fromOffset(58, 8) or UDim2.fromOffset(812, 8)
	hide.Text = collapsed and "+" or "_"
end)
cancelFive.Activated:Connect(function()
	cancelFive.Text = "..."
	local cancelOk, result = pcall(function()
		return remote:InvokeServer("CancelFiveVFive", {})
	end)
	cancelFive.Text = "CANCEL 5V5"
	if not cancelOk or type(result) ~= "table" then
		setStatus("5v5 cancel failed.", false)
		return
	end
	setStatus(result.Message or (result.Success and "5v5 cancelled." or "5v5 cancel failed."), result.Success == true)
end)
grant.Activated:Connect(function()
	local pack = selectedPackData()
	if not pack then return end
	local target = targetBox.Text
	if target == "" then
		local selected = selectedPlayerData()
		target = selected and tostring(selected.Name) or ""
	end
	if target == "" then
		setStatus("Choose a player first.", false)
		return
	end
	grant.Text = "..."
	local grantOk, result = pcall(function()
		return remote:InvokeServer("GrantPack", {Target = target, PackId = pack.Id, Quantity = quantity})
	end)
	grant.Text = "GIVE"
	if not grantOk or type(result) ~= "table" then
		setStatus("Grant failed.", false)
		return
	end
	setStatus(result.Message or (result.Success and "Pack granted." or "Grant failed."), result.Success == true)
	if result.Success and type(result.Data) == "table" and type(result.Data.State) == "table" then
		packs = type(result.Data.State.Packs) == "table" and result.Data.State.Packs or packs
		players = type(result.Data.State.Players) == "table" and result.Data.State.Players or players
	end
	refresh()
end)

refresh()
task.spawn(function()
	while gui.Parent do
		task.wait(10)
		refreshServerData()
	end
end)
