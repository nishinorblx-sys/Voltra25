--!strict
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
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

local function makeButton(parent: Instance, title: string, subtitle: string, selected: boolean, accentColor: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = selected and Color3.fromRGB(14, 24, 18) or Color3.fromRGB(8, 13, 15)
	button.BackgroundTransparency = selected and .02 or .1
	button.BorderSizePixel = 0
	button.ZIndex = 102
	button.Selectable = true
	button.Parent = parent
	corner(button, 12)

	local line = stroke(button, selected and accentColor or Color3.fromRGB(105, 119, 118), selected and .02 or .48, selected and 3 or 1.3)

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(.5, .5)
	glow.Position = UDim2.fromScale(.5, .5)
	glow.Size = UDim2.fromScale(1.06, 1.1)
	glow.BackgroundColor3 = accentColor
	glow.BackgroundTransparency = selected and .76 or 1
	glow.BorderSizePixel = 0
	glow.ZIndex = 101
	glow.Parent = button
	corner(glow, 16)

	local stripe = Instance.new("Frame")
	stripe.Name = "TopStripe"
	stripe.Position = UDim2.fromOffset(16, 14)
	stripe.Size = UDim2.new(1, -32, 0, 12)
	stripe.BackgroundColor3 = accentColor
	stripe.BackgroundTransparency = selected and 0 or .28
	stripe.BorderSizePixel = 0
	stripe.ZIndex = 103
	stripe.Parent = button
	corner(stripe, 7)

	local badge = Instance.new("TextLabel")
	badge.Name = "ChoiceBadge"
	badge.AnchorPoint = Vector2.new(.5, 0)
	badge.Position = UDim2.new(.5, 0, 0, 44)
	badge.Size = UDim2.fromOffset(64, 64)
	badge.BackgroundColor3 = Color3.fromRGB(4, 8, 8)
	badge.BackgroundTransparency = .04
	badge.BorderSizePixel = 0
	badge.Text = string.sub(title, 1, 1)
	badge.TextColor3 = accentColor
	badge.TextSize = 28
	badge.Font = Theme.Fonts.Display
	badge.ZIndex = 103
	badge.Parent = button
	corner(badge, 32)
	stroke(badge, accentColor, .18, 2)

	local titleLabel = text(button, title, UDim2.fromScale(.08, .50), UDim2.fromScale(.84, .16), 25, selected and accentColor or Theme.Colors.White, Theme.Fonts.Display)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center

	local subtitleLabel = text(button, subtitle, UDim2.fromScale(.11, .68), UDim2.fromScale(.78, .16), 13, Theme.Colors.White, Theme.Fonts.Body)
	subtitleLabel.TextTransparency = .12

	local selectedPip = Instance.new("TextLabel")
	selectedPip.Name = "SelectedPip"
	selectedPip.AnchorPoint = Vector2.new(.5, .5)
	selectedPip.Position = UDim2.new(.5, 0, 1, -22)
	selectedPip.Size = UDim2.fromOffset(116, 24)
	selectedPip.BackgroundColor3 = accentColor
	selectedPip.BackgroundTransparency = selected and .06 or 1
	selectedPip.BorderSizePixel = 0
	selectedPip.Text = "SELECTED"
	selectedPip.TextColor3 = Theme.Colors.Black
	selectedPip.TextSize = 8
	selectedPip.Font = Theme.Fonts.Strong
	selectedPip.ZIndex = 104
	selectedPip.Parent = button
	corner(selectedPip, 12)

	local function setFocused(focused: boolean)
		if focused then UISoundService.PlayHover() end
		tween(button, {BackgroundTransparency = focused and .01 or (selected and .02 or .1), BackgroundColor3 = focused and Color3.fromRGB(13, 25, 20) or (selected and Color3.fromRGB(14, 24, 18) or Color3.fromRGB(8, 13, 15))}, .1)
		tween(glow, {BackgroundTransparency = focused and .62 or (selected and .76 or 1)}, .1)
		tween(line, {Color = accentColor, Transparency = focused and 0 or (selected and .02 or .48), Thickness = focused and 4 or (selected and 3 or 1.3)}, .1)
		tween(titleLabel, {TextColor3 = focused and accentColor or (selected and accentColor or Theme.Colors.White)}, .1)
		tween(stripe, {BackgroundTransparency = focused and 0 or (selected and 0 or .28)}, .1)
		tween(badge, {TextColor3 = accentColor, BackgroundTransparency = focused and 0 or .04}, .1)
		tween(selectedPip, {BackgroundTransparency = focused and .02 or (selected and .06 or 1)}, .1)
	end

	button.MouseEnter:Connect(function() setFocused(true) end)
	button.SelectionGained:Connect(function() setFocused(true) end)
	button.MouseLeave:Connect(function()
		if selected then return end
		setFocused(false)
	end)
	button.SelectionLost:Connect(function() if not selected then setFocused(false) end end)

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
	panel.Size = UDim2.fromOffset(910, 520)
	panel.BackgroundColor3 = Color3.fromRGB(3, 9, 8)
	panel.BackgroundTransparency = .04
	panel.BorderSizePixel = 0
	panel.ZIndex = 100
	panel.Parent = overlay
	corner(panel, 18)
	stroke(panel, Theme.Colors.Electric, .02, 2.4)

	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(.5, .5)
	glow.Position = UDim2.fromScale(.5, .5)
	glow.Size = UDim2.fromScale(1.018, 1.036)
	glow.BackgroundColor3 = Theme.Colors.Electric
	glow.BackgroundTransparency = .9
	glow.BorderSizePixel = 0
	glow.ZIndex = 99
	glow.Parent = panel
	corner(glow, 22)

	local top = Instance.new("Frame")
	top.AnchorPoint = Vector2.new(.5, 0)
	top.Position = UDim2.new(.5, 0, 0, 0)
	top.Size = UDim2.new(.82, 0, 0, 2)
	top.BackgroundColor3 = Theme.Colors.Electric
	top.BorderSizePixel = 0
	top.ZIndex = 103
	top.Parent = panel

	text(panel, "AI CAMPAIGN MATCH", UDim2.fromOffset(0, 52), UDim2.new(1, 0, 0, 22), 13, Theme.Colors.Electric, Theme.Fonts.Strong)
	text(panel, "CHOOSE HOW TO PLAY", UDim2.fromOffset(0, 82), UDim2.new(1, 0, 0, 58), 39, Theme.Colors.White, Theme.Fonts.Display)
	local hint = text(panel, "A / X SELECT     B / CIRCLE BACK", UDim2.fromOffset(0, 136), UDim2.new(1, 0, 0, 20), 10, Theme.Colors.Silver, Theme.Fonts.Strong)
	hint.TextTransparency = .08

	local divider = Instance.new("Frame")
	divider.AnchorPoint = Vector2.new(.5, 0)
	divider.Position = UDim2.new(.5, 0, 0, 174)
	divider.Size = UDim2.fromOffset(260, 3)
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

	local manual = makeButton(panel, "MANUALLY PLAY", "Control your squad on the pitch", true, Theme.Colors.Electric)
	manual.Position = UDim2.fromOffset(76, 220)
	manual.Size = UDim2.fromOffset(360, 212)

	local manage = makeButton(panel, "MANAGE MATCH", "AI plays while you manage tactics", false, Color3.fromHex("24C6B8"))
	manage.Position = UDim2.fromOffset(474, 220)
	manage.Size = UDim2.fromOffset(360, 212)

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
	cancel.Position = UDim2.new(.5, 0, 1, -20)
	cancel.Size = UDim2.fromOffset(250, 46)
	cancel.ZIndex = 103
	cancel.Parent = panel
	cancel.Selectable = true
	corner(cancel, 10)
	stroke(cancel, Color3.fromRGB(120, 128, 138), .36, 1.2)
	manual.NextSelectionRight = manage
	manual.NextSelectionDown = cancel
	manage.NextSelectionLeft = manual
	manage.NextSelectionDown = cancel
	cancel.NextSelectionUp = manual
	cancel.NextSelectionLeft = manual
	cancel.NextSelectionRight = manage

	local closing = false
	local function close(run: (() -> ())?)
		if closing then return end
		closing = true
		UISoundService.PlayClick()
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(overlay) then
			GuiService.SelectedObject = nil
		end
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

	local choices = {manual, manage, cancel}
	local selectedIndex = 1
	local lastMoveAt = 0
	local function selectIndex(index: number)
		selectedIndex = math.clamp(index, 1, #choices)
		local target = choices[selectedIndex]
		if target then
			GuiService.SelectedObject = target
			UISoundService.PlayHover()
		end
	end
	local inputConnection: RBXScriptConnection? = nil
	inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if closing then return end
		if input.KeyCode == Enum.KeyCode.ButtonA then
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(overlay) and selected:IsA("GuiButton") then
				selected:Activate()
			else
				choices[selectedIndex]:Activate()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonB then
			close(callbacks and callbacks.OnCancel)
		elseif input.KeyCode == Enum.KeyCode.DPadLeft then
			selectIndex(1)
		elseif input.KeyCode == Enum.KeyCode.DPadRight then
			selectIndex(2)
		elseif input.KeyCode == Enum.KeyCode.DPadDown then
			selectIndex(3)
		elseif input.KeyCode == Enum.KeyCode.DPadUp then
			selectIndex(selectedIndex == 3 and 1 or selectedIndex)
		end
	end)
	local stickConnection: RBXScriptConnection? = nil
	stickConnection = UserInputService.InputChanged:Connect(function(input)
		if closing or input.KeyCode ~= Enum.KeyCode.Thumbstick1 then return end
		local now = os.clock()
		if now - lastMoveAt < .34 then return end
		local x = input.Position.X
		local y = input.Position.Y
		if math.abs(x) < .62 and math.abs(y) < .62 then return end
		lastMoveAt = now
		if y < -.62 then
			selectIndex(3)
		elseif y > .62 then
			selectIndex(selectedIndex == 3 and 1 or selectedIndex)
		elseif x < -.62 then
			selectIndex(1)
		elseif x > .62 then
			selectIndex(2)
		end
	end)
	overlay.Destroying:Connect(function()
		if inputConnection then inputConnection:Disconnect();inputConnection=nil end
		if stickConnection then stickConnection:Disconnect();stickConnection=nil end
	end)

	tween(overlay, {BackgroundTransparency = .38}, .16)
	tween(panel, {Position = UDim2.fromScale(.5, .5), BackgroundTransparency = .08}, .22)
	task.defer(function()
		selectIndex(1)
	end)
end

return Modal
