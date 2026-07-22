--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local UISoundService = require(script.Parent.Parent.Services.UISoundService)

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

local function button(parent: Instance, name: string, title: string, subtitle: string, position: UDim2, color: Color3, iconAsset: string): TextButton
	local item = Instance.new("TextButton")
	item.Name = name
	item.Position = position
	item.Size = UDim2.fromScale(.42, .42)
	item.BackgroundColor3 = Color3.fromHex("0B130E")
	item.BackgroundTransparency = 0
	item.BorderSizePixel = 0
	item.AutoButtonColor = false
	item.Selectable = true
	item.Text = ""
	item.ZIndex = 304
	item.Parent = parent
	corner(item, 10)
	local outline = Instance.new("UIStroke")
	outline.Name = "PromptStroke"
	outline.Color = color
	outline.Transparency = .28
	outline.Thickness = 1.5
	outline.Parent = item
	local scale = Instance.new("UIScale")
	scale.Name = "PromptScale"
	scale.Parent = item
	local stripe = Instance.new("Frame")
	stripe.Name = "AccentStripe"
	stripe.Position = UDim2.fromScale(0, 0)
	stripe.Size = UDim2.fromScale(1, .08)
	stripe.BackgroundColor3 = color
	stripe.BackgroundTransparency = .05
	stripe.BorderSizePixel = 0
	stripe.ZIndex = 305
	stripe.Parent = item
	corner(stripe, 10)
	local badge = Instance.new("Frame")
	badge.Name = "ModeIcon"
	badge.AnchorPoint = Vector2.new(.5, .5)
	badge.Position = UDim2.fromScale(.5, .31)
	badge.Size = UDim2.fromOffset(74, 74)
	badge.BackgroundColor3 = color
	badge.BackgroundTransparency = .1
	badge.BorderSizePixel = 0
	badge.ZIndex = 306
	badge.Parent = item
	corner(badge, 37)
	stroke(badge, Color3.fromHex("FFFFFF"), .6, 1)
	local icon = Instance.new("ImageLabel")
	icon.Name = "IconImage"
	icon.AnchorPoint = Vector2.new(.5, .5)
	icon.BackgroundTransparency = 1
	icon.Image = iconAsset
	icon.Position = UDim2.fromScale(.5, .5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(.72, .72)
	icon.ZIndex = 307
	icon.Parent = badge
	local titleLabel = label(item, title, UDim2.fromScale(.06, .50), UDim2.fromScale(.88, .18), 24, Theme.Colors.White)
	titleLabel.ZIndex = 308
	local sub = label(item, subtitle, UDim2.fromScale(.08, .70), UDim2.fromScale(.84, .16), 10, Color3.fromHex("C9D0C3"))
	sub.Font = Theme.Fonts.Strong
	sub.ZIndex = 308
	local selected = Instance.new("TextLabel")
	selected.Name = "SelectedPip"
	selected.AnchorPoint = Vector2.new(.5, 1)
	selected.Position = UDim2.fromScale(.5, .98)
	selected.Size = UDim2.fromScale(.84, .12)
	selected.BackgroundColor3 = color
	selected.BackgroundTransparency = .12
	selected.BorderSizePixel = 0
	selected.Text = "SELECTED"
	selected.TextColor3 = Color3.fromHex("061006")
	selected.TextSize = 9
	selected.Font = Theme.Fonts.Strong
	selected.Visible = false
	selected.ZIndex = 307
	selected.Parent = item
	corner(selected, 6)
	return item
end

local function setButtonSelected(item: TextButton, selected: boolean)
	local outline = item:FindFirstChild("PromptStroke")
	local scale = item:FindFirstChild("PromptScale")
	local pip = item:FindFirstChild("SelectedPip")
	local stripe = item:FindFirstChild("AccentStripe")
	if outline and outline:IsA("UIStroke") then
		TweenService:Create(outline, TweenInfo.new(.12), {
			Transparency = selected and 0 or .28,
			Thickness = selected and 4 or 1.5,
		}):Play()
	end
	if scale and scale:IsA("UIScale") then
		TweenService:Create(scale, TweenInfo.new(.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Scale = selected and 1.045 or 1,
		}):Play()
	end
	if pip and pip:IsA("GuiObject") then
		pip.Visible = selected
	end
	if stripe and stripe:IsA("GuiObject") then
		TweenService:Create(stripe, TweenInfo.new(.12), {
			BackgroundTransparency = selected and 0 or .05,
		}):Play()
	end
	TweenService:Create(item, TweenInfo.new(.12), {
		BackgroundColor3 = selected and Color3.fromHex("102013") or Color3.fromHex("0B130E"),
	}):Play()
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
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromHex("030503")
	overlay.BackgroundTransparency = 1
	overlay.Active = true
	overlay.ZIndex = 300
	overlay.Parent = gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(.5, .5)
	panel.Position = UDim2.fromScale(.5, .52)
	panel.Size = UDim2.fromOffset(720, 390)
	panel.BackgroundColor3 = Color3.fromHex("071209")
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.ZIndex = 302
	panel.Parent = overlay
	corner(panel, 16)
	stroke(panel, Theme.Colors.Electric, .03, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = .86
	scale.Parent = panel
	local topBar = Instance.new("Frame")
	topBar.Position = UDim2.fromScale(.05, .06)
	topBar.Size = UDim2.fromScale(.9, .018)
	topBar.BackgroundColor3 = Theme.Colors.Electric
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 303
	topBar.Parent = panel
	corner(topBar, 4)
	label(panel, "VOLTRA MATCHDAY", UDim2.fromScale(.12, .1), UDim2.fromScale(.76, .07), 12, Theme.Colors.Electric)
	label(panel, "PLAY OR MANAGE", UDim2.fromScale(.08, .17), UDim2.fromScale(.84, .14), 34, Theme.Colors.White)
	local hint = label(panel, "A / X SELECT     B / CIRCLE BACK", UDim2.fromScale(.08, .31), UDim2.fromScale(.84, .06), 11, Color3.fromHex("A9FF0A"))
	hint.Font = Theme.Fonts.Strong
	local manual = button(panel, "ManualPlay", "PLAY", "Control the squad yourself", UDim2.fromScale(.06, .43), Theme.Colors.Electric, "rbxassetid://136932491275794")
	local manage = button(panel, "ManageMatch", "MANAGE", "Coach tactics while AI plays", UDim2.fromScale(.52, .43), Color3.fromHex("DDE6D8"), "rbxassetid://94181255091137")
	local cancel = Instance.new("TextButton")
	cancel.Name = "Cancel"
	cancel.AnchorPoint = Vector2.new(.5, 1)
	cancel.Position = UDim2.fromScale(.5, .965)
	cancel.Size = UDim2.fromOffset(220, 36)
	cancel.BackgroundColor3 = Color3.fromHex("141D16")
	cancel.BackgroundTransparency = .12
	cancel.BorderSizePixel = 0
	cancel.AutoButtonColor = false
	cancel.Selectable = true
	cancel.Text = "CANCEL / BACK"
	cancel.TextColor3 = Color3.fromHex("F5F7F2")
	cancel.TextSize = 11
	cancel.Font = Theme.Fonts.Strong
	cancel.ZIndex = 305
	cancel.Parent = panel
	corner(cancel, 8)
	local cancelStroke = Instance.new("UIStroke")
	cancelStroke.Name = "PromptStroke"
	cancelStroke.Color = Color3.fromHex("F5F7F2")
	cancelStroke.Transparency = .5
	cancelStroke.Thickness = 1
	cancelStroke.Parent = cancel
	local cancelScale = Instance.new("UIScale")
	cancelScale.Name = "PromptScale"
	cancelScale.Parent = cancel
	local cancelPip = Instance.new("Frame")
	cancelPip.Name = "SelectedPip"
	cancelPip.AnchorPoint = Vector2.new(.5, 1)
	cancelPip.Position = UDim2.fromScale(.5, 1.18)
	cancelPip.Size = UDim2.fromScale(.65, .1)
	cancelPip.BackgroundColor3 = Theme.Colors.Electric
	cancelPip.BorderSizePixel = 0
	cancelPip.Visible = false
	cancelPip.ZIndex = 306
	cancelPip.Parent = cancel
	corner(cancelPip, 4)
	local settled = false
	local connections: {RBXScriptConnection} = {}
	local function choose(value: string?)
		if settled then return end
		settled = true
		UISoundService.PlayClick()
		for _, connection in connections do
			connection:Disconnect()
		end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
		TweenService:Create(panel, TweenInfo.new(.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1, Position = UDim2.fromScale(.5, .56)}):Play()
		TweenService:Create(overlay, TweenInfo.new(.18), {BackgroundTransparency = 1}):Play()
		task.delay(.2, function()
			if gui.Parent then gui:Destroy() end
			done:Fire(value)
			done:Destroy()
		end)
	end
	manual.Activated:Connect(function() choose("Manual") end)
	manage.Activated:Connect(function() choose("Manage") end)
	cancel.Activated:Connect(function() choose(nil) end)
	local options = {manual, manage, cancel}
	local selectedIndex = 0
	local lastStickMove = 0
	local function selectIndex(index: number)
		local previousIndex = selectedIndex
		selectedIndex = math.clamp(index, 1, #options)
		for i, option in options do
			setButtonSelected(option, i == selectedIndex)
		end
		if GuiService.SelectedObject ~= options[selectedIndex] then
			GuiService.SelectedObject = options[selectedIndex]
		end
		if previousIndex ~= selectedIndex then
			UISoundService.PlayHover()
		end
	end
	for i, option in options do
		table.insert(connections, option.SelectionGained:Connect(function()
			if selectedIndex ~= i then
				selectIndex(i)
			end
		end))
		table.insert(connections, option.MouseEnter:Connect(function()
			if selectedIndex ~= i then
				selectIndex(i)
			end
		end))
	end
	local function moveHorizontal(direction: number)
		if selectedIndex == 3 then
			selectIndex(direction < 0 and 1 or 2)
		else
			selectIndex(direction < 0 and 1 or 2)
		end
	end
	local function activateSelected()
		local selected = options[selectedIndex]
		if selected == manual then
			choose("Manual")
		elseif selected == manage then
			choose("Manage")
		else
			choose(nil)
		end
	end
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or settled then return end
		local key = input.KeyCode
		if key == Enum.KeyCode.ButtonA then
			activateSelected()
		elseif key == Enum.KeyCode.ButtonB then
			choose(nil)
		elseif key == Enum.KeyCode.DPadLeft then
			moveHorizontal(-1)
		elseif key == Enum.KeyCode.DPadRight then
			moveHorizontal(1)
		elseif key == Enum.KeyCode.DPadDown then
			selectIndex(3)
		elseif key == Enum.KeyCode.DPadUp then
			if selectedIndex == 3 then selectIndex(1) end
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed or settled or input.KeyCode ~= Enum.KeyCode.Thumbstick1 then return end
		local position = input.Position
		local now = os.clock()
		if now - lastStickMove < .24 then return end
		if math.abs(position.X) >= .55 then
			lastStickMove = now
			moveHorizontal(position.X < 0 and -1 or 1)
		elseif position.Y <= -.55 then
			lastStickMove = now
			selectIndex(3)
		elseif position.Y >= .55 and selectedIndex == 3 then
			lastStickMove = now
			selectIndex(1)
		end
	end))
	TweenService:Create(overlay, TweenInfo.new(.18), {BackgroundTransparency = .08}):Play()
	TweenService:Create(panel, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = .02, Position = UDim2.fromScale(.5, .5)}):Play()
	TweenService:Create(scale, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	task.defer(function()
		if gui.Parent then
			selectIndex(1)
		end
	end)
	return done.Event:Wait()
end

return Prompt
