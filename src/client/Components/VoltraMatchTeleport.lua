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
	gui.DisplayOrder = 960
	gui.Parent = playerGui
	local overlay = Instance.new("CanvasGroup")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromHex("020402")
	overlay.BackgroundTransparency = 0
	overlay.GroupTransparency = 0
	overlay.Active = true
	overlay.ZIndex = 960
	overlay.Parent = gui
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(.5, .5)
	text.Position = UDim2.fromScale(.5, .45)
	text.Size = UDim2.fromScale(.82, .1)
	text.Text = string.upper(title)
	text.TextColor3 = Theme.Colors.White
	text.TextSize = 34
	text.Font = Theme.Fonts.Display
	text.ZIndex = 962
	text.Parent = overlay
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(.5, .5)
	sub.Position = UDim2.fromScale(.5, .54)
	sub.Size = UDim2.fromScale(.8, .04)
	sub.Text = "CINEMATIC MATCH LOADING"
	sub.TextColor3 = Theme.Colors.Electric
	sub.TextSize = 11
	sub.Font = Theme.Fonts.Strong
	sub.ZIndex = 962
	sub.Parent = overlay
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(.5, .5)
	bar.Position = UDim2.fromScale(.5, .61)
	bar.Size = UDim2.fromScale(.38, .008)
	bar.BackgroundColor3 = Color3.fromHex("111711")
	bar.BorderSizePixel = 0
	bar.ZIndex = 962
	bar.Parent = overlay
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Colors.Electric
	fill.BorderSizePixel = 0
	fill.ZIndex = 963
	fill.Parent = bar
	TweenService:Create(fill, TweenInfo.new(.95, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
	task.wait(.12)
	local result = callback()
	local started = os.clock()
	repeat
		if playerGui:FindFirstChild("VTRPrematchBroadcast") then break end
		task.wait(.05)
	until os.clock() - started > 2.2
	if gui.Parent then
		TweenService:Create(overlay, TweenInfo.new(.12), {GroupTransparency = 1}):Play()
		task.delay(.14, function()
			if gui.Parent then gui:Destroy() end
		end)
	end
	return result
end

return Teleport
