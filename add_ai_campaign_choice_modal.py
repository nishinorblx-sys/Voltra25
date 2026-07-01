from pathlib import Path

component_path = Path("src/client/Components/AICampaignPlayChoiceModal.lua")
component_path.write_text(r'''--!strict
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local UISoundService = require(script.Parent.Parent.Services.UISoundService)

local Modal = {}

local function tween(instance: Instance, props: {[string]: any}, time: number?)
	local item = TweenService:Create(instance, TweenInfo.new(time or .18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	item:Play()
	return item
end

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
	return item
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Transparency = transparency
	item.Thickness = thickness
	item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	item.Parent = parent
	return item
end

local function text(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = value
	item.TextColor3 = color
	item.TextSize = textSize
	item.Font = font
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Center
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.ZIndex = 102
	item.Parent = parent
	return item
end

local function makeButton(parent: Instance, title: string, subtitle: string, selected: boolean): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = Color3.fromRGB(6, 12, 10)
	button.BackgroundTransparency = selected and .06 or .18
	button.BorderSizePixel = 0
	button.ZIndex = 102
	button.Parent = parent
	corner(button, 24)

	local line = stroke(button, selected and Theme.Colors.Electric or Color3.fromRGB(115, 122, 132), selected and .03 or .42, selected and 2.5 or 1.2)

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(.5, .5)
	glow.Position = UDim2.fromScale(.5, .5)
	glow.Size = UDim2.fromScale(1.06, 1.1)
	glow.BackgroundColor3 = Theme.Colors.Electric
	glow.BackgroundTransparency = selected and .82 or 1
	glow.BorderSizePixel = 0
	glow.ZIndex = 101
	glow.Parent = button
	corner(glow, 28)

	local titleLabel = text(button, title, UDim2.fromScale(.08, .38), UDim2.fromScale(.84, .2), 31, selected and Theme.Colors.Electric or Theme.Colors.White, Theme.Fonts.Display)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center

	local subtitleLabel = text(button, subtitle, UDim2.fromScale(.1, .6), UDim2.fromScale(.8, .18), 16, Theme.Colors.Silver, Theme.Fonts.Body)

	local accent = Instance.new("Frame")
	accent.AnchorPoint = Vector2.new(.5, 1)
	accent.Position = UDim2.new(.5, 0, 1, -14)
	accent.Size = UDim2.fromOffset(72, 6)
	accent.BackgroundColor3 = selected and Theme.Colors.Electric or Theme.Colors.Silver
	accent.BackgroundTransparency = selected and 0 or .38
	accent.BorderSizePixel = 0
	accent.ZIndex = 103
	accent.Parent = button
	corner(accent, 8)

	button.MouseEnter:Connect(function()
		UISoundService.PlayHover()
		tween(button, {BackgroundTransparency = .04}, .1)
		tween(glow, {BackgroundTransparency = .82}, .1)
		tween(line, {Color = Theme.Colors.Electric, Transparency = .08, Thickness = 2.1}, .1)
		tween(titleLabel, {TextColor3 = Theme.Colors.Electric}, .1)
		tween(accent, {BackgroundColor3 = Theme.Colors.Electric, BackgroundTransparency = 0}, .1)
	end)

	button.MouseLeave:Connect(function()
		if selected then return end
		tween(button, {BackgroundTransparency = .18}, .1)
		tween(glow, {BackgroundTransparency = 1}, .1)
		tween(line, {Color = Color3.fromRGB(115, 122, 132), Transparency = .42, Thickness = 1.2}, .1)
		tween(titleLabel, {TextColor3 = Theme.Colors.White}, .1)
		tween(accent, {BackgroundColor3 = Theme.Colors.Silver, BackgroundTransparency = .38}, .1)
	end)

	return button
end

function Modal.Show(parent: Instance, callbacks: any)
	local overlay = Instance.new("Frame")
	overlay.Name = "AICampaignChoiceOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 95
	overlay.Parent = parent

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(.5, .5)
	panel.Position = UDim2.fromScale(.5, .54)
	panel.Size = UDim2.fromOffset(980, 560)
	panel.BackgroundColor3 = Color3.fromRGB(5, 10, 10)
	panel.BackgroundTransparency = .14
	panel.BorderSizePixel = 0
	panel.ZIndex = 100
	panel.Parent = overlay
	corner(panel, 34)
	stroke(panel, Theme.Colors.Electric, .08, 2)

	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(.5, .5)
	glow.Position = UDim2.fromScale(.5, .5)
	glow.Size = UDim2.fromScale(1.025, 1.045)
	glow.BackgroundColor3 = Theme.Colors.Electric
	glow.BackgroundTransparency = .9
	glow.BorderSizePixel = 0
	glow.ZIndex = 99
	glow.Parent = panel
	corner(glow, 38)

	local top = Instance.new("Frame")
	top.AnchorPoint = Vector2.new(.5, 0)
	top.Position = UDim2.new(.5, 0, 0, 0)
	top.Size = UDim2.new(.82, 0, 0, 2)
	top.BackgroundColor3 = Theme.Colors.Electric
	top.BorderSizePixel = 0
	top.ZIndex = 103
	top.Parent = panel

	text(panel, "AI CAMPAIGN MATCH", UDim2.fromOffset(0, 66), UDim2.new(1, 0, 0, 24), 18, Theme.Colors.Electric, Theme.Fonts.Strong)
	text(panel, "CHOOSE HOW TO PLAY", UDim2.fromOffset(0, 110), UDim2.new(1, 0, 0, 74), 55, Theme.Colors.White, Theme.Fonts.Display)

	local divider = Instance.new("Frame")
	divider.AnchorPoint = Vector2.new(.5, 0)
	divider.Position = UDim2.new(.5, 0, 0, 206)
	divider.Size = UDim2.fromOffset(330, 3)
	divider.BackgroundColor3 = Theme.Colors.Electric
	divider.BorderSizePixel = 0
	divider.ZIndex = 103
	divider.Parent = panel

	local notch = Instance.new("Frame")
	notch.AnchorPoint = Vector2.new(.5, 0)
	notch.Position = UDim2.new(.5, 0, 1, -1)
	notch.Size = UDim2.fromOffset(28, 28)
	notch.BackgroundColor3 = Theme.Colors.Electric
	notch.BorderSizePixel = 0
	notch.Rotation = 45
	notch.ZIndex = 102
	notch.Parent = divider

	local manual = makeButton(panel, "MANUALLY PLAY", "Control your squad on the pitch", true)
	manual.Position = UDim2.fromOffset(86, 268)
	manual.Size = UDim2.fromOffset(400, 230)

	local manage = makeButton(panel, "MANAGE MATCH", "AI plays while you manage tactics", false)
	manage.Position = UDim2.fromOffset(526, 268)
	manage.Size = UDim2.fromOffset(400, 230)

	local cancel = Instance.new("TextButton")
	cancel.AutoButtonColor = false
	cancel.Text = "CANCEL"
	cancel.TextColor3 = Theme.Colors.White
	cancel.TextSize = 19
	cancel.Font = Theme.Fonts.Display
	cancel.BackgroundColor3 = Color3.fromRGB(8, 12, 16)
	cancel.BackgroundTransparency = .05
	cancel.BorderSizePixel = 0
	cancel.AnchorPoint = Vector2.new(.5, 1)
	cancel.Position = UDim2.new(.5, 0, 1, -18)
	cancel.Size = UDim2.fromOffset(300, 58)
	cancel.ZIndex = 103
	cancel.Parent = panel
	corner(cancel, 16)
	stroke(cancel, Color3.fromRGB(120, 128, 138), .36, 1.2)

	local closing = false
	local function close(run: (() -> ())?)
		if closing then return end
		closing = true
		UISoundService.PlayClick()
		tween(overlay, {BackgroundTransparency = 1}, .12)
		tween(panel, {Position = UDim2.fromScale(.5, .54), BackgroundTransparency = .3}, .14)
		task.delay(.14, function()
			if overlay.Parent then overlay:Destroy() end
			if run then run() end
		end)
	end

	manual.Activated:Connect(function()
		close(callbacks and callbacks.OnManual)
	end)

	manage.Activated:Connect(function()
		close(callbacks and callbacks.OnManage)
	end)

	cancel.Activated:Connect(function()
		close(callbacks and callbacks.OnCancel)
	end)

	tween(overlay, {BackgroundTransparency = .38}, .16)
	tween(panel, {Position = UDim2.fromScale(.5, .5), BackgroundTransparency = .08}, .22)
end

return Modal
''', encoding="utf-8", newline="\n")

page_path = Path("src/client/Pages/MatchSetupPage.lua")
page = page_path.read_text(encoding="utf-8")

if "AICampaignPlayChoiceModal" not in page:
    page = page.replace(
        "local MatchPresentation=require(script.Parent.Parent.Components.MatchPresentation)",
        "local MatchPresentation=require(script.Parent.Parent.Components.MatchPresentation)\nlocal AICampaignPlayChoiceModal=require(script.Parent.Parent.Components.AICampaignPlayChoiceModal)",
        1
    )

old = '''local start=Button.new({Text="START MATCH",Variant="Primary",Size=UDim2.fromOffset(220,48),OnActivated=function()launch(false)end});start.AnchorPoint=Vector2.new(1,0);start.Position=UDim2.new(.5,-8,0,370);start.Parent=card;local watch=Button.new({Text="WATCH MATCH",Variant="Secondary",Size=UDim2.fromOffset(220,48),OnActivated=function()launch(true)end});watch.AnchorPoint=Vector2.new(0,0);watch.Position=UDim2.new(.5,8,0,370);watch.Parent=card'''

new = '''local choose=Button.new({Text="CHOOSE HOW TO PLAY",Variant="Primary",Size=UDim2.fromOffset(300,52),OnActivated=function()AICampaignPlayChoiceModal.Show(context.Root or group,{OnManual=function()launch(false)end,OnManage=function()launch(true)end})end});choose.AnchorPoint=Vector2.new(.5,0);choose.Position=UDim2.new(.5,0,0,370);choose.Parent=card'''

if old not in page:
    raise SystemExit("Could not find the old START MATCH / WATCH MATCH buttons in MatchSetupPage.lua")

page = page.replace(old, new, 1)

page_path.write_text(page, encoding="utf-8", newline="\n")

print("added AI campaign choice modal and wired ready button")