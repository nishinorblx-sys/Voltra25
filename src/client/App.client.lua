--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GameplayConfig = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local FocusController = require(script.Parent.Controllers.FocusController)
local MatchGameplayController = require(script.Parent.Gameplay.GameplayController)

FocusController.new():Start(Players.LocalPlayer:WaitForChild("PlayerGui"))
MatchGameplayController.new():Start()

local teleportData = TeleportService:GetLocalPlayerTeleportData()
local reservedRankedBoot = type(teleportData) == "table" and teleportData.MatchMode == "Ranked1v1"

local function showReservedRankedBoot()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRRankedReservedBoot")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRRankedReservedBoot"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 150
	gui.Parent = playerGui
	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Theme.Colors.Black
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui
	for index = 1, 4 do
		local slash = Instance.new("Frame")
		slash.BackgroundColor3 = index % 2 == 0 and Theme.Colors.Electric or Theme.Colors.Gunmetal
		slash.BackgroundTransparency = index % 2 == 0 and 0.8 or 0.38
		slash.BorderSizePixel = 0
		slash.AnchorPoint = Vector2.new(0.5, 0.5)
		slash.Position = UDim2.fromScale(0.16 + index * 0.18, 0.5)
		slash.Size = UDim2.fromScale(0.055, 1.35)
		slash.Rotation = 24
		slash.Parent = bg
	end
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.43)
	title.Size = UDim2.fromScale(0.78, 0.08)
	title.Font = Theme.Fonts.Display
	title.Text = "RANKED 1V1 SERVER"
	title.TextColor3 = Theme.Colors.Electric
	title.TextSize = 32
	title.Parent = bg
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.fromScale(0.5, 0.51)
	sub.Size = UDim2.fromScale(0.78, 0.05)
	sub.Font = Theme.Fonts.Strong
	sub.Text = "SYNCING BOTH TEAMS  /  LOADING RESERVED MATCH"
	sub.TextColor3 = Theme.Colors.Silver
	sub.TextSize = 10
	sub.Parent = bg
	Players.LocalPlayer:GetAttributeChangedSignal("VTRInMatch"):Connect(function()
		if Players.LocalPlayer:GetAttribute("VTRInMatch") == true then
			task.delay(1.2, function()
				if gui.Parent then gui:Destroy() end
			end)
		end
	end)
	return gui
end

if GameplayConfig.AutoStartTestMatch then
	local GameplayController = require(script.Parent.Controllers.GameplayController)
	GameplayController.new():Start()
elseif reservedRankedBoot then
	showReservedRankedBoot()
else
	local UIController = require(script.Parent.Controllers.UIController)
	UIController.new():Start()
end
