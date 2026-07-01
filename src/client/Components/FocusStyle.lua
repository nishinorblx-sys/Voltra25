--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local FocusStyle = {}

local function tween(stroke: UIStroke, transparency: number, thickness: number)
	TweenService:Create(stroke, TweenInfo.new(Theme.Animation.Hover, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Transparency = transparency,
		Thickness = thickness,
	}):Play()
end

function FocusStyle.apply(target: GuiButton)
	if target:GetAttribute("VTRFocusStyled") then return end
	target:SetAttribute("VTRFocusStyled", true)
	target.AutoButtonColor = false
	target.Selectable = false

	-- Never add selection-image children to controls: layout objects treat them
	-- as content. VTR draws its own focus border and glow below.
	local legacySuppressor = target:FindFirstChild("VTRTransparentSelection")
	if legacySuppressor then legacySuppressor:Destroy() end
	target.SelectionImageObject = nil

	local border = Instance.new("UIStroke")
	border.Name = "VTRFocusBorder"
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Theme.Colors.White
	border.Thickness = 1
	border.Transparency = 1
	border.Parent = target

	local glow = Instance.new("UIStroke")
	glow.Name = "VTRFocusGlow"
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Color = Theme.Colors.White
	glow.Thickness = 3
	glow.Transparency = 1
	glow.Parent = target

	local focused = false
	local hovered = false
	local scale = target:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "VTRFocusScale"
		scale.Parent = target
	end
	local function render()
		if focused then
			tween(border, 0.05, 1)
			tween(glow, 0.78, 3)
			TweenService:Create(scale, TweenInfo.new(Theme.Animation.Hover, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1.025 }):Play()
		elseif hovered then
			tween(border, 0.38, 1)
			tween(glow, 0.92, 2)
			TweenService:Create(scale, TweenInfo.new(Theme.Animation.Hover, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1.01 }):Play()
		else
			tween(border, 1, 1)
			tween(glow, 1, 2)
			TweenService:Create(scale, TweenInfo.new(Theme.Animation.Hover, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	target.SelectionGained:Connect(function() focused = true; render() end)
	target.SelectionLost:Connect(function() focused = false; render() end)
	target.MouseEnter:Connect(function() hovered = true; render() end)
	target.MouseLeave:Connect(function() hovered = false; render() end)
end

function FocusStyle.install(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") then FocusStyle.apply(descendant) end
	end
	root.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") then FocusStyle.apply(descendant) end
	end)
end

return FocusStyle
