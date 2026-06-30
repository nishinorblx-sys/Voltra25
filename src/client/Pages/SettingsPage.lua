--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local SettingsRuntimeService = require(script.Parent.Parent.Services.SettingsRuntimeService)
local PageBase = require(script.Parent.PageBase)

local SettingsPage = {}
local TABS = {"Controls", "Audio", "Camera", "Accessibility", "Account"}
local CAMERA_PRESETS = {"Broadcast", "End to End", "Pro"}
local LANGUAGES = {"English", "Spanish", "French", "Portuguese"}
local NUMBER_NAMES = {Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9"}

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

local function commit(context: any, key: string, value: any)
	local current = settings(context)
	current[key] = value
	SettingsRuntimeService.Apply(current)
	context.StateService:SetSetting(key, value)
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
	local current = tostring(settings(context)[key] or values[1])
	local x = 0
	for index, value in values do
		local active = value == current
		local button = Button.new({Text = value, Variant = active and "Primary" or "Secondary", Size = UDim2.fromOffset(index == 2 and 112 or 96, 32), OnActivated = function()
			commit(context, key, value)
			if context.RefreshSettings then context.RefreshSettings(key) end
		end})
		button.AnchorPoint = Vector2.new(1, .5)
		button.Position = UDim2.new(1, -14 - x, .5, 0)
		button.Parent = holder
		x += (index == 2 and 120 or 104)
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
	local function setFromX(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		alpha = math.floor(alpha * 100 + .5) / 100
		fill.Size = UDim2.fromScale(alpha, 1)
		readout.Text = tostring(math.floor(alpha * 100 + .5)) .. "%"
		commit(context, key, alpha)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
		end
	end)
end

local function keybind(parent: Instance, context: any, key: string, title: string, subtitle: string, y: number, editable: boolean)
	local holder = row(parent, title, subtitle, y)
	local current = tostring(settings(context)[key] or (key == "SkipKey" and "Space" or "M"))
	local waiting = false
	local button = Button.new({Text = current, Variant = editable and "Primary" or "Secondary", Size = UDim2.fromOffset(116, 34), OnActivated = function()
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
			local name = input.KeyCode.Name
			local displayed = NUMBER_NAMES[name] or name
			if #name == 1 or NUMBER_NAMES[name] then
				waiting = false
				button.Text = displayed
				commit(context, key, displayed)
				if connection then connection:Disconnect() end
			elseif name == "Space" then
				waiting = false
				button.Text = "SPACE"
				commit(context, key, "Space")
				if connection then connection:Disconnect() end
			end
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
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "Heading" and child.Name ~= "Tabs" then
			child:Destroy()
		end
	end
	if active == "Controls" then
		local box = panel(scroll, "Controls", UDim2.fromOffset(0, 154), UDim2.new(1, 0, 0, 220))
		keybind(box, context, "PauseKey", "PAUSE", "Click the key button, then press a letter or number.", 52, true)
		keybind(box, context, "SkipKey", "SKIP", "Prematch and replay skip is Space.", 126, false)
	elseif active == "Audio" then
		local mix = panel(scroll, "Audio Mix", UDim2.fromOffset(0, 154), UDim2.new(.5, -10, 0, 242))
		slider(mix, context, "MasterVolume", "MASTER VOLUME", "Controls global game audio.", 52, .8)
		toggle(mix, context, "MenuMusic", "MENU MUSIC", "Turns menu soundtrack audio on or off.", 126)
		local comm = panel(scroll, "Commentary", UDim2.new(.5, 10, 0, 154), UDim2.new(.5, -10, 0, 242))
		option(comm, context, "CommentaryLanguage", "COMMENTARY LANGUAGE", "Choose match commentary language.", 52, LANGUAGES)
		slider(comm, context, "CommentaryVolume", "COMMENTARY VOLUME", "Separate commentary mix level.", 126, .7)
	elseif active == "Camera" then
		local cam = panel(scroll, "Camera Options", UDim2.fromOffset(0, 154), UDim2.new(1, 0, 0, 190))
		option(cam, context, "CameraPreset", "CAMERA PRESET", "Broadcast, End to End, or Pro player-follow camera.", 52, CAMERA_PRESETS)
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
	local group, scroll = PageBase.new("Settings", 560)
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
	for index, tab in TABS do
		local button = Button.new({Text = tab, Variant = tab == active and "Primary" or "Secondary", Size = UDim2.new(1 / #TABS, -8, 0, 36), OnActivated = function()
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
