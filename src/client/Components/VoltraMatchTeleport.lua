--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Teleport = {}

function Teleport.Run(title: string, callback: () -> any): any
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRMatchTeleport")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRMatchTeleport"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 390
	gui.Parent = playerGui
	local overlay = Instance.new("CanvasGroup")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromHex("020402")
	overlay.GroupTransparency = 1
	overlay.ZIndex = 390
	overlay.Parent = gui
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(.5, .5)
	text.Position = UDim2.fromScale(.5, .47)
	text.Size = UDim2.fromScale(.8, .1)
	text.Text = string.upper(title)
	text.TextColor3 = Theme.Colors.White
	text.TextSize = 34
	text.Font = Theme.Fonts.Display
	text.ZIndex = 392
	text.Parent = overlay
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(.5, .5)
	sub.Position = UDim2.fromScale(.5, .56)
	sub.Size = UDim2.fromScale(.8, .04)
	sub.Text = "TELEPORTING TO VOLTRA MATCH"
	sub.TextColor3 = Theme.Colors.Electric
	sub.TextSize = 11
	sub.Font = Theme.Fonts.Strong
	sub.ZIndex = 392
	sub.Parent = overlay
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(.5, .5)
	bar.Position = UDim2.fromScale(.5, .62)
	bar.Size = UDim2.fromScale(.38, .008)
	bar.BackgroundColor3 = Color3.fromHex("111711")
	bar.BorderSizePixel = 0
	bar.ZIndex = 392
	bar.Parent = overlay
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Colors.Electric
	fill.BorderSizePixel = 0
	fill.ZIndex = 393
	fill.Parent = bar
	TweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 0}):Play()
	TweenService:Create(fill, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
	task.wait(.28)
	local result = callback()
	task.wait(.28)
	TweenService:Create(overlay, TweenInfo.new(.22), {GroupTransparency = 1}):Play()
	task.delay(.24, function()
		if gui.Parent then gui:Destroy() end
	end)
	return result
end

return Teleport
