--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local SettingsRuntimeService = require(script.Parent.Parent.Services.SettingsRuntimeService)
local UISoundService = require(script.Parent.Parent.Services.UISoundService)
local PageBase = require(script.Parent.PageBase)

local SettingsPage = {}
local TABS = {"Controls", "Audio", "Camera", "Accessibility", "Account"}
local CAMERA_PRESETS = {"Tactical", "Pro"}
local NUMBER_NAMES = {Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9"}
local KEY_DEFAULTS = {
	PauseKey = "M",
	ManualPassKey = "LeftControl",
	LobbedPassKey = "LeftAlt",
	ChangePlayerKey = "Q",
	TackleKey = "E",
	SlideTackleKey = "F",
	SkipKey = "Space",
}

local CONTROL_ROWS = {
	{Key = "PauseKey", Title = "PAUSE", Subtitle = "Open or close the pause menu.", Editable = true},
	{Key = "ManualPassKey", Title = "MANUAL PASS HOLD", Subtitle = "Hold this key to charge and release a manual pass.", Editable = true},
	{Key = "LobbedPassKey", Title = "MANUAL LOB HOLD", Subtitle = "Hold this key to charge and release an unassisted manual lobbed pass.", Editable = true},
	{Key = "ChangePlayerKey", Title = "CHANGE PLAYER", Subtitle = "Switch to the best nearby teammate or defender.", Editable = true},
	{Key = "TackleKey", Title = "TACKLE", Subtitle = "Standing tackle / defensive challenge.", Editable = true},
	{Key = "SlideTackleKey", Title = "SLIDE TACKLE", Subtitle = "Slide tackle input.", Editable = true},
	{Key = "SkipKey", Title = "SKIP", Subtitle = "Prematch and replay skip is Space.", Editable = false},
}

local function label(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3?, font: Enum.Font?): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = value
	item.TextColor3 = color or Theme.Colors.White
	item.TextSize = textSize
	item.Font = font or Theme.Fonts.Body
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function settings(context: any): any
	context.Data.UIState.Settings = context.Data.UIState.Settings or {}
	return context.Data.UIState.Settings
end

local function commit(context: any, key: string, value: any, saveState: boolean?)
	local current = settings(context)
	current[key] = value
	SettingsRuntimeService.Apply(current)
	if saveState ~= false then
		context.StateService:SetSetting(key, value)
	end
end

local function normalizeOptionValue(key: string, value: any): string
	local text = tostring(value)
	if key == "CameraPreset" then
		if text == "Broadcast" or text == "WideBroadcast" or text == "Wide Broadcast" or text == "CloseBroadcast" or text == "Close Broadcast" or text == "End to End" then return "Tactical" end
	end
	return text
end

local function row(parent: Instance, title: string, subtitle: string, y: number): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundColor3 = Theme.Colors.Black
	holder.BackgroundTransparency = .78
	holder.BorderSizePixel = 0
	holder.Position = UDim2.fromOffset(18, y)
	holder.Size = UDim2.new(1, -36, 0, 64)
	holder.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.Medium)
	corner.Parent = holder
	label(holder, title, UDim2.fromOffset(14, 8), UDim2.new(.52, -14, 0, 22), 11, Theme.Colors.White, Theme.Fonts.Strong)
	label(holder, subtitle, UDim2.fromOffset(14, 31), UDim2.new(.55, -14, 0, 22), 8, Theme.Colors.Muted, Theme.Fonts.Body)
	return holder
end

local function toggle(parent: Instance, context: any, key: string, title: string, subtitle: string, y: number)
	local holder = row(parent, title, subtitle, y)
	local current = settings(context)[key] == true
	local button = Button.new({Text = current and "ON" or "OFF", Variant = current and "Primary" or "Secondary", Size = UDim2.fromOffset(92, 34), OnActivated = function()
		commit(context, key, not current)
		if context.RefreshSettings then context.RefreshSettings(key) end
	end})
	button.AnchorPoint = Vector2.new(1, .5)
	button.Position = UDim2.new(1, -14, .5, 0)
	button.Parent = holder
end

local function option(parent: Instance, context: any, key: string, title: string, subtitle: string, y: number, values: {string})
	local holder = row(parent, title, subtitle, y)
	local current = normalizeOptionValue(key, settings(context)[key] or values[1])
	local x = 0
	for index, value in ipairs(values) do
		local active = value == current
		local width = math.clamp(72 + #value * 5, 96, 154)
		local button = Button.new({Text = value, Variant = active and "Primary" or "Secondary", Size = UDim2.fromOffset(width, 32), OnActivated = function()
			commit(context, key, value)
			if context.RefreshSettings then context.RefreshSettings(key) end
		end})
		button.AnchorPoint = Vector2.new(1, .5)
		button.Position = UDim2.new(1, -14 - x, .5, 0)
		button.Parent = holder
		x += width + 8
	end
end

local function slider(parent: Instance, context: any, key: string, title: string, subtitle: string, y: number, fallback: number)
	local holder = row(parent, title, subtitle, y)
	local current = math.clamp(tonumber(settings(context)[key]) or fallback, 0, 1)
	local readout = label(holder, tostring(math.floor(current * 100 + .5)) .. "%", UDim2.new(1, -70, 0, 8), UDim2.fromOffset(56, 20), 12, Theme.Colors.Electric, Theme.Fonts.Display)
	readout.TextXAlignment = Enum.TextXAlignment.Right
	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.BackgroundColor3 = Theme.Colors.Gunmetal
	track.BorderSizePixel = 0
	track.Position = UDim2.new(.58, 0, .5, 8)
	track.Size = UDim2.new(.32, 0, 0, 8)
	track.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.Colors.Electric
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(current, 1)
	fill.Parent = track
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	local thumb = Instance.new("TextButton")
	thumb.AnchorPoint = Vector2.new(.5, .5)
	thumb.AutoButtonColor = false
	thumb.BackgroundColor3 = Theme.Colors.White
	thumb.BorderSizePixel = 0
	thumb.Position = UDim2.fromScale(current, .5)
	thumb.Size = UDim2.fromOffset(16, 16)
	thumb.Text = ""
	thumb.Parent = track
	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)
	thumbCorner.Parent = thumb
	local dragging = false
	local pendingValue = current
	local function setFromX(x: number, saveState: boolean?)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		alpha = math.floor(alpha * 100 + .5) / 100
		pendingValue = alpha
		fill.Size = UDim2.fromScale(alpha, 1)
		thumb.Position = UDim2.fromScale(alpha, .5)
		readout.Text = tostring(math.floor(alpha * 100 + .5)) .. "%"
		commit(context, key, alpha, saveState)
	end
	local function beginDrag(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X, false)
		end
	end
	track.InputBegan:Connect(beginDrag)
	thumb.InputBegan:Connect(beginDrag)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X, false)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				commit(context, key, pendingValue, true)
			end
			dragging = false
		end
	end)
end

local function displayKeyName(name: string): string
	return string.upper(NUMBER_NAMES[name] or name)
end

local function inputName(input: InputObject): string?
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode.Name == "Unknown" then return nil end
		return NUMBER_NAMES[input.KeyCode.Name] or input.KeyCode.Name
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then return "MouseButton1" end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MouseButton2" end
	if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MouseButton3" end
	return nil
end

local function keybind(parent: Instance, context: any, key: string, title: string, subtitle: string, y: number, editable: boolean)
	local holder = row(parent, title, subtitle, y)
	local current = tostring(settings(context)[key] or KEY_DEFAULTS[key] or "M")
	local waiting = false
	local button = Button.new({Text = displayKeyName(current), Variant = editable and "Primary" or "Secondary", Size = UDim2.fromOffset(150, 34), OnActivated = function()
		if not editable then return end
		waiting = true
	end})
	button.AnchorPoint = Vector2.new(1, .5)
	button.Position = UDim2.new(1, -14, .5, 0)
	button.Parent = holder
	button.Activated:Connect(function()
		if editable then
			button.Text = "PRESS KEY"
		end
	end)
	if editable then
		local connection: RBXScriptConnection?
		connection = UserInputService.InputBegan:Connect(function(input, processed)
			if not waiting or processed then return end
			local name = inputName(input)
			if not name then return end
			waiting = false
			button.Text = displayKeyName(name)
			UISoundService.PlayType()
			commit(context, key, name)
			if context.RefreshSettings then context.RefreshSettings(key) end
			if connection then connection:Disconnect() end
		end)
	end
end

local function panel(parent: Instance, title: string, position: UDim2, size: UDim2): Frame
	local frame = Panel.new({Name = title:gsub("%W", ""), Position = position, Size = size})
	frame.Parent = parent
	label(frame, string.upper(title), UDim2.fromOffset(18, 12), UDim2.new(1, -36, 0, 28), 16, Theme.Colors.White, Theme.Fonts.Display)
	return frame
end

local function renderTab(context: any, scroll: ScrollingFrame, active: string)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Heading" and child.Name ~= "Tabs" then
			child:Destroy()
		end
	end
	if active == "Controls" then
		local box = panel(scroll, "Controls", UDim2.fromOffset(0, 154), UDim2.new(1, 0, 0, 610))
		for index, item in ipairs(CONTROL_ROWS) do
			keybind(box, context, item.Key, item.Title, item.Subtitle, 52 + (index - 1) * 74, item.Editable ~= false)
		end
	elseif active == "Audio" then
		local mix = panel(scroll, "Audio Mix", UDim2.fromOffset(0, 154), UDim2.new(1, 0, 0, 242))
		slider(mix, context, "MasterVolume", "MASTER VOLUME", "Controls global game audio.", 52, .8)
		toggle(mix, context, "MenuMusic", "MENU MUSIC", "Turns menu soundtrack audio on or off.", 126)
	elseif active == "Camera" then
		local cam = panel(scroll, "Camera Options", UDim2.fromOffset(0, 154), UDim2.new(1, 0, 0, 190))
		option(cam, context, "CameraPreset", "CAMERA PRESET", "Tactical or Pro.", 52, CAMERA_PRESETS)
	elseif active == "Accessibility" then
		local access = panel(scroll, "Accessibility", UDim2.fromOffset(0, 154), UDim2.new(1, 0, 0, 220))
		toggle(access, context, "HighContrast", "HIGH CONTRAST", "Increases scene contrast and UI readability.", 52)
		toggle(access, context, "ReducedMotion", "REDUCE MOTION", "Shortens UI transitions and presentation movement.", 126)
	elseif active == "Account" then
		local account = panel(scroll, "Account", UDim2.fromOffset(0, 154), UDim2.new(1, 0, 0, RunService:IsStudio() and 220 or 144))
		toggle(account, context, "Crossplay", "CROSS-PLAY", "On queues against all devices. Off only pairs same-device players.", 52)
		if RunService:IsStudio() then
			local reset = Button.new({Text = "RESET PROFILE", Variant = "Secondary", Size = UDim2.fromOffset(156, 36), OnActivated = function()
				if context.Persist then
					context.Persist("Settings", {Operation = "Developer", ServerAction = "DeveloperResetProfile"}, {})
				end
				if context.Toast then
					context.Toast({Title = "SETTINGS", Message = "Studio reset profile request sent.", Kind = "Info"})
				end
			end})
			reset.Position = UDim2.fromOffset(18, 132)
			reset.Parent = account
		end
	end
end

function SettingsPage.new(context: any): CanvasGroup
	local group, scroll = PageBase.new("Settings", 900)
	PageBase.heading(scroll, "SETTINGS", "GAME SETTINGS", "Adjust controls, audio, camera, accessibility, and account matchmaking.")
	local active = (context.Data.UIState.SelectedTabs and context.Data.UIState.SelectedTabs.Settings) or "Controls"
	if not table.find(TABS, active) then active = "Controls" end
	context.Data.UIState.SelectedTabs = context.Data.UIState.SelectedTabs or {}
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(0, 96)
	tabs.Size = UDim2.new(1, 0, 0, 42)
	tabs.Parent = scroll
	context.RefreshSettings = function()
		renderTab(context, scroll, active)
	end
	for index, tab in ipairs(TABS) do
		local button = Button.new({Text = tab, Variant = tab == active and "Primary" or "Secondary", Size = UDim2.new(1 / #TABS, -8, 0, 36), OnActivated = function()
			if tab == active then return end
			active = tab
			context.Data.UIState.SelectedTabs.Settings = tab
			context.StateService:SetTab("Settings", tab)
			context.RefreshSettings()
		end})
		button.Position = UDim2.new((index - 1) / #TABS, 4, 0, 0)
		button.Parent = tabs
	end
	renderTab(context, scroll, active)
	return group
end

return SettingsPage
