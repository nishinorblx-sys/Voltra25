--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Prompt = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number?)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Transparency = transparency
	item.Thickness = thickness or 1
	item.Parent = parent
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = text
	item.TextColor3 = color
	item.TextSize = textSize
	item.Font = Theme.Fonts.Display
	item.TextXAlignment = Enum.TextXAlignment.Center
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.ZIndex = 303
	item.Parent = parent
	return item
end

local function button(parent: Instance, name: string, title: string, subtitle: string, position: UDim2, color: Color3): TextButton
	local item = Instance.new("TextButton")
	item.Name = name
	item.Position = position
	item.Size = UDim2.fromScale(.42, .34)
	item.BackgroundColor3 = Color3.fromHex("070A06")
	item.BackgroundTransparency = .04
	item.BorderSizePixel = 0
	item.AutoButtonColor = true
	item.Text = ""
	item.ZIndex = 304
	item.Parent = parent
	corner(item, 12)
	stroke(item, color, .12, 2)
	local glow = Instance.new("Frame")
	glow.Position = UDim2.fromScale(.06, .1)
	glow.Size = UDim2.fromScale(.88, .22)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = .06
	glow.BorderSizePixel = 0
	glow.ZIndex = 305
	glow.Parent = item
	corner(glow, 8)
	label(item, title, UDim2.fromScale(.06, .33), UDim2.fromScale(.88, .24), 20, Theme.Colors.White)
	local sub = label(item, subtitle, UDim2.fromScale(.08, .6), UDim2.fromScale(.84, .24), 10, Color3.fromHex("C9D0C3"))
	sub.Font = Theme.Fonts.Strong
	return item
end

function Prompt.Choose(): string?
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRAIMatchModePrompt")
	if old then old:Destroy() end
	local done = Instance.new("BindableEvent")
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRAIMatchModePrompt"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 380
	gui.Parent = playerGui
	local overlay = Instance.new("CanvasGroup")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromHex("030503")
	overlay.BackgroundTransparency = .08
	overlay.GroupTransparency = 1
	overlay.Active = true
	overlay.ZIndex = 300
	overlay.Parent = gui
	local panel = Instance.new("CanvasGroup")
	panel.AnchorPoint = Vector2.new(.5, .5)
	panel.Position = UDim2.fromScale(.5, .52)
	panel.Size = UDim2.fromOffset(620, 330)
	panel.BackgroundColor3 = Color3.fromHex("081008")
	panel.BackgroundTransparency = .02
	panel.BorderSizePixel = 0
	panel.GroupTransparency = 1
	panel.ZIndex = 302
	panel.Parent = overlay
	corner(panel, 18)
	stroke(panel, Theme.Colors.White, .18, 2)
	local scale = Instance.new("UIScale")
	scale.Scale = .86
	scale.Parent = panel
	label(panel, "AI CAMPAIGN MATCH", UDim2.fromScale(.12, .08), UDim2.fromScale(.76, .08), 12, Theme.Colors.White)
	label(panel, "CHOOSE HOW TO PLAY", UDim2.fromScale(.08, .16), UDim2.fromScale(.84, .15), 31, Theme.Colors.White)
	local manual = button(panel, "ManualPlay", "MANUALLY PLAY", "Control your squad on the pitch", UDim2.fromScale(.06, .43), Theme.Colors.White)
	local manage = button(panel, "ManageMatch", "MANAGE MATCH", "AI plays while you manage tactics", UDim2.fromScale(.52, .43), Color3.fromHex("D9D9D9"))
	local cancel = Instance.new("TextButton")
	cancel.Name = "Cancel"
	cancel.AnchorPoint = Vector2.new(.5, 1)
	cancel.Position = UDim2.fromScale(.5, .96)
	cancel.Size = UDim2.fromOffset(180, 30)
	cancel.BackgroundColor3 = Color3.fromHex("111611")
	cancel.BackgroundTransparency = .12
	cancel.BorderSizePixel = 0
	cancel.Text = "CANCEL"
	cancel.TextColor3 = Color3.fromHex("F5F7F2")
	cancel.TextSize = 10
	cancel.Font = Theme.Fonts.Strong
	cancel.ZIndex = 305
	cancel.Parent = panel
	corner(cancel, 8)
	stroke(cancel, Color3.fromHex("F5F7F2"), .62)
	local settled = false
	local function choose(value: string?)
		if settled then return end
		settled = true
		TweenService:Create(panel, TweenInfo.new(.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1, Position = UDim2.fromScale(.5, .56)}):Play()
		TweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 1}):Play()
		task.delay(.2, function()
			if gui.Parent then gui:Destroy() end
			done:Fire(value)
			done:Destroy()
		end)
	end
	manual.Activated:Connect(function() choose("Manual") end)
	manage.Activated:Connect(function() choose("Manage") end)
	cancel.Activated:Connect(function() choose(nil) end)
	TweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 0}):Play()
	TweenService:Create(panel, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {GroupTransparency = 0, Position = UDim2.fromScale(.5, .5)}):Play()
	TweenService:Create(scale, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	return done.Event:Wait()
end

return Prompt
