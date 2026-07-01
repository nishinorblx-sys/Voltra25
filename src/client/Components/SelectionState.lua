--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local SelectionState = {}

function SelectionState.decorate(target: GuiObject, showPlayerBadge: boolean?)
	local parent = target.Parent
	if not parent then return end
	target.ZIndex = 2

	local glow = Instance.new("Frame")
	glow.Name = "SelectionGlow"
	glow.AnchorPoint = target.AnchorPoint
	glow.BackgroundColor3 = Theme.Colors.White
	glow.BackgroundTransparency = 0.91
	glow.BorderSizePixel = 0
	glow.Position = target.Position
	glow.Size = UDim2.new(target.Size.X.Scale, target.Size.X.Offset + 8, target.Size.Y.Scale, target.Size.Y.Offset + 8)
	glow.ZIndex = 1
	glow.Parent = parent
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 10)
	glowCorner.Parent = glow
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Color = Theme.Colors.White
	glowStroke.Thickness = 2
	glowStroke.Transparency = 0.78
	glowStroke.Parent = glow
	TweenService:Create(glowStroke, TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.9 }):Play()

	if not showPlayerBadge then return end
	local badge = Instance.new("TextLabel")
	badge.Name = "SelectedCheck"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.BackgroundColor3 = Theme.Colors.White
	badge.BorderSizePixel = 0
	-- Sit just outside the portrait bounds so the badge never obscures card data.
	badge.Position = UDim2.new(1, 3, 0, -3)
	badge.Size = UDim2.fromOffset(18, 18)
	badge.Text = utf8.char(10003)
	badge.TextColor3 = Theme.Colors.Black
	badge.TextSize = 11
	badge.Font = Theme.Fonts.Strong
	badge.ZIndex = 4
	badge.Parent = target
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = badge
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Theme.Colors.Black
	badgeStroke.Thickness = 1
	badgeStroke.Transparency = 0.55
	badgeStroke.Parent = badge

	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.Name = "SelectedLabel"
	selectedLabel.AnchorPoint = Vector2.new(0.5, 0)
	selectedLabel.BackgroundColor3 = Theme.Colors.Black
	selectedLabel.BackgroundTransparency = 0.12
	selectedLabel.BorderSizePixel = 0
	selectedLabel.Position = UDim2.new(0.5, 0, 1, 4)
	selectedLabel.Size = UDim2.fromOffset(66, 15)
	selectedLabel.Text = "SELECTED"
	selectedLabel.TextColor3 = Theme.Colors.White
	selectedLabel.TextSize = 7
	selectedLabel.Font = Theme.Fonts.Strong
	selectedLabel.ZIndex = 4
	selectedLabel.Parent = target
	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 4)
	labelCorner.Parent = selectedLabel
end

return SelectionState
