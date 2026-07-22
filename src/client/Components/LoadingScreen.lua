--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local LoadingScreen = {}

local function fadeOut(frame: Frame)
	TweenService:Create(frame, TweenInfo.new(Theme.Animation.Page), {BackgroundTransparency = 1}):Play()
	for _, child in ipairs(frame:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
			TweenService:Create(child, TweenInfo.new(Theme.Animation.Page), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
		elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
			TweenService:Create(child, TweenInfo.new(Theme.Animation.Page), {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
		elseif child:IsA("Frame") then
			TweenService:Create(child, TweenInfo.new(Theme.Animation.Page), {BackgroundTransparency = 1}):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, TweenInfo.new(Theme.Animation.Page), {Transparency = 1}):Play()
		end
	end
end

function LoadingScreen.new(parent: Instance, statusText: string?): Frame
	local group = Instance.new("Frame")
	group.Name = "LoadingScreen"
	group.BackgroundColor3 = Theme.Colors.Black
	group.BorderSizePixel = 0
	group.Size = UDim2.fromScale(1, 1)
	group.ZIndex = 100
	group.Parent = parent
	local logo = Instance.new("TextLabel")
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.BackgroundColor3 = Theme.Colors.Electric
	logo.BorderSizePixel = 0
	logo.Position = UDim2.fromScale(0.5, 0.44)
	logo.Size = UDim2.fromOffset(72, 72)
	logo.Text = "V"
	logo.TextColor3 = Theme.Colors.Black
	logo.TextSize = 45
	logo.Font = Theme.Fonts.Display
	logo.ZIndex = 101
	logo.Parent = group
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.Large)
	corner.Parent = logo
	local scale = Instance.new("UIScale")
	scale.Parent = logo
	TweenService:Create(scale, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 }):Play()
	local status = Instance.new("TextLabel")
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0.5, 0.52)
	status.Size = UDim2.fromOffset(320, 28)
	status.Text = statusText or "CONNECTING TO VOLTRA SERVICES"
	status.TextColor3 = Theme.Colors.Muted
	status.TextSize = 9
	status.Font = Theme.Fonts.Strong
	status.ZIndex = 101
	status.Parent = group
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.BackgroundColor3 = Theme.Colors.Gunmetal
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromScale(0.5, 0.565)
	bar.Size = UDim2.fromOffset(220, 3)
	bar.ZIndex = 101
	bar.Parent = group
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.Colors.Electric
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0.18, 1)
	fill.ZIndex = 102
	fill.Parent = bar
	TweenService:Create(fill, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(0.82, 0) }):Play()
	return group
end

function LoadingScreen.complete(group: Frame, callback: (() -> ())?)
	fadeOut(group)
	local tween = TweenService:Create(group, TweenInfo.new(Theme.Animation.Page), { BackgroundTransparency = 1 })
	tween.Completed:Once(function() group:Destroy(); if callback then callback() end end)
	tween:Play()
end

return LoadingScreen
