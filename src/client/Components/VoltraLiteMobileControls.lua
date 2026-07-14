--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ActionTuning = require(ReplicatedStorage.VTR.Shared.ActionTuningConfig)
local DeviceConfig = require(ReplicatedStorage.VTR.Shared.DeviceGameplayConfig)

local Controls = {}
Controls.__index = Controls

local GREEN = Color3.fromHex("B7FF1A")
local WHITE = Color3.fromHex("F5F7F2")
local BLACK = Color3.fromHex("061006")
local RED = Color3.fromHex("FF4056")
local AMBER = Color3.fromHex("FFC83D")

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number): UIStroke
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Transparency = transparency
	item.Thickness = thickness
	item.Parent = parent
	return item
end

local function controlScale(): number
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	return math.clamp(math.min(viewport.X / 1920, viewport.Y / 1080), 0.78, 1.08)
end

local function circle(parent: Instance, name: string, size: number, position: UDim2, label: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = BLACK
	button.BackgroundTransparency = 0.3
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = label
	button.TextColor3 = WHITE
	button.TextSize = math.max(12, math.floor(size * 0.17))
	button.TextWrapped = true
	button.Font = Enum.Font.GothamBlack
	button.ZIndex = 210
	button.Parent = parent
	corner(button, size)
	stroke(button, color, 0.32, 1.5)
	local fill = Instance.new("Frame")
	fill.Name = "StateFill"
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.fromScale(0.5, 1)
	fill.Size = UDim2.fromScale(0.72, 0)
	fill.BackgroundColor3 = color
	fill.BackgroundTransparency = 0.67
	fill.BorderSizePixel = 0
	fill.ZIndex = 209
	fill.Parent = button
	corner(fill, size)
	return button
end

local function setPressed(button: TextButton, active: boolean, color: Color3?)
	button.BackgroundTransparency = if active then 0.08 else 0.3
	local outline = button:FindFirstChildOfClass("UIStroke")
	if outline then
		if color then outline.Color = color end
		outline.Thickness = if active then 2.4 else 1.5
		outline.Transparency = if active then 0.08 else 0.32
	end
	local fill = button:FindFirstChild("StateFill")
	if fill and fill:IsA("Frame") then
		if color then fill.BackgroundColor3 = color end
		fill.Size = if active then UDim2.fromScale(0.72, 0.72) else UDim2.fromScale(0.72, 0)
	end
end

function Controls.new(controller: any)
	local self = setmetatable({}, Controls)
	self.Controller = controller
	self.Connections = {}
	self.MoveInput = Vector2.zero
	self.ActionAim = {}
	self.ActionMagnitude = {}
	self.ActionTouches = {}
	self.PassMode = nil
	self.Defending = false
	self.ContextAction = "Through"
	self.SprintMode = "Toggle"
	self.Handedness = "Right"

	self.Gui = Instance.new("ScreenGui")
	self.Gui.Name = "VTRLiteMobileControls"
	self.Gui.IgnoreGuiInset = true
	self.Gui.ResetOnSpawn = false
	self.Gui.DisplayOrder = 170
	self.Gui.Enabled = false
	self.Gui.Parent = Players.LocalPlayer.PlayerGui

	local root = Instance.new("Frame")
	root.Name = "Controls"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = self.Gui
	self.Root = root

	local scale = controlScale()
	self.ControlScale = scale
	local function px(value: number): number
		return math.floor(value * scale + 0.5)
	end

	local base = Instance.new("Frame")
	base.Name = "MovementJoystick"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Position = UDim2.new(0, px(126), 1, -px(136))
	base.Size = UDim2.fromOffset(px(164), px(164))
	base.BackgroundColor3 = BLACK
	base.BackgroundTransparency = 0.44
	base.BorderSizePixel = 0
	base.Active = true
	base.ZIndex = 205
	base.Parent = root
	corner(base, px(164))
	stroke(base, GREEN, 0.45, 1.2)

	local arrows = Instance.new("TextLabel")
	arrows.BackgroundTransparency = 1
	arrows.Size = UDim2.fromScale(1, 1)
	arrows.Text = "+"
	arrows.TextColor3 = GREEN
	arrows.TextTransparency = 0.2
	arrows.TextSize = px(38)
	arrows.Font = Enum.Font.GothamBlack
	arrows.ZIndex = 206
	arrows.Parent = base

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(px(66), px(66))
	knob.BackgroundColor3 = GREEN
	knob.BackgroundTransparency = 0.18
	knob.BorderSizePixel = 0
	knob.ZIndex = 207
	knob.Parent = base
	corner(knob, px(66))
	stroke(knob, WHITE, 0.72, 1)
	self.Joystick = base
	self.Knob = knob

	local large = px(math.clamp(68, DeviceConfig.Mobile.ActionButtonMinimum, DeviceConfig.Mobile.ActionButtonMaximum))
	local medium = px(math.clamp(62, DeviceConfig.Mobile.ActionButtonMinimum, DeviceConfig.Mobile.ActionButtonMaximum))
	self.PrimaryButton = circle(root, "PrimaryAction", large, UDim2.new(1, -px(108), 1, -px(156)), "PASS", GREEN)
	self.SecondaryButton = circle(root, "SecondaryAction", large, UDim2.new(1, -px(182), 1, -px(244)), "SHOOT", GREEN)
	self.SprintButton = circle(root, "SprintAction", medium, UDim2.new(1, -px(290), 1, -px(126)), "SPRINT", GREEN)
	self.ContextButton = circle(root, "ContextAction", medium, UDim2.new(1, -px(310), 1, -px(220)), "THROUGH", GREEN)

	local aimLine = Instance.new("Frame")
	aimLine.Name = "ActionAimLine"
	aimLine.AnchorPoint = Vector2.new(0, 0.5)
	aimLine.BackgroundColor3 = GREEN
	aimLine.BackgroundTransparency = 0.18
	aimLine.BorderSizePixel = 0
	aimLine.Size = UDim2.fromOffset(0, px(3))
	aimLine.Visible = false
	aimLine.ZIndex = 208
	aimLine.Parent = root
	corner(aimLine, px(3))
	self.AimLine = aimLine

	local moveTouch: InputObject? = nil
	local function updateMove(input: InputObject)
		local center = base.AbsolutePosition + base.AbsoluteSize * 0.5
		local delta = Vector2.new(input.Position.X, input.Position.Y) - center
		local radius = base.AbsoluteSize.X * 0.4
		if delta.Magnitude > radius then delta = delta.Unit * radius end
		self.MoveInput = if radius > 0 then Vector2.new(delta.X / radius, -delta.Y / radius) else Vector2.zero
		knob.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
	end

	table.insert(self.Connections, base.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and moveTouch == nil then
			moveTouch = input
			updateMove(input)
		end
	end))
	table.insert(self.Connections, UserInputService.TouchMoved:Connect(function(input)
		if input == moveTouch then
			updateMove(input)
		else
			self:_updateActionTouch(input)
		end
	end))
	table.insert(self.Connections, UserInputService.TouchEnded:Connect(function(input)
		if input == moveTouch then
			moveTouch = nil
			self.MoveInput = Vector2.zero
			knob.Position = UDim2.fromScale(0.5, 0.5)
		else
			self:_finishActionTouch(input, false)
		end
	end))

	self:_bindActionButton(self.PrimaryButton, "Primary")
	self:_bindActionButton(self.SecondaryButton, "Secondary")
	self:_bindActionButton(self.SprintButton, "Sprint")
	self:_bindActionButton(self.ContextButton, "Context")
	self:SetDefending(false)
	return self
end

function Controls:_buttonCenter(button: TextButton): Vector2
	return button.AbsolutePosition + button.AbsoluteSize * 0.5
end

function Controls:_showAim(button: TextButton, delta: Vector2)
	local length = delta.Magnitude
	if length < ActionTuning.MobileDeadZonePixels * (self.ControlScale or 1) then
		self.AimLine.Visible = false
		return
	end
	local center = self:_buttonCenter(button)
	self.AimLine.Position = UDim2.fromOffset(center.X, center.Y)
	self.AimLine.Size = UDim2.fromOffset(length, math.max(2, math.floor(3 * (self.ControlScale or 1))))
	self.AimLine.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	self.AimLine.Visible = true
end

function Controls:_updateActionTouch(input: InputObject)
	for button, state in self.ActionTouches do
		if state.Input == input then
			local center = self:_buttonCenter(button)
			local delta = Vector2.new(input.Position.X, input.Position.Y) - center
			local maximum = ActionTuning.MobileMaximumDragPixels * (self.ControlScale or 1)
			if delta.Magnitude > maximum then delta = delta.Unit * maximum end
			local deadZone = ActionTuning.MobileDeadZonePixels * (self.ControlScale or 1)
			local direction = if delta.Magnitude > deadZone then Vector2.new(delta.X, -delta.Y).Unit else Vector2.zero
			self.ActionAim[state.Kind] = direction
			self.ActionMagnitude[state.Kind] = delta.Magnitude
			state.Delta = delta
			self:_showAim(button, delta)
			return
		end
	end
end

function Controls:_beginActionTouch(button: TextButton, input: InputObject, role: string)
	if self.ActionTouches[button] ~= nil then
		return
	end
	local kind = ""
	local options: any = nil
	if role == "Primary" then
		kind = if self.Defending then "Tackle" else "Pass"
		options = if self.Defending then nil else {PassMode = "Ground"}
	elseif role == "Secondary" then
		kind = if self.Defending then "Switch" else "Shot"
	elseif role == "Context" then
		if self.Defending then
			kind = "SlideTackle"
		elseif self.ContextAction == "Skill" then
			kind = "Skill"
		else
			kind = "Pass"
			options = {PassMode = if self.ContextAction == "Cross" or self.ContextAction == "Lob" then "Lob" else "Through"}
		end
	elseif role == "Sprint" then
		kind = "Sprint"
	end
	self.ActionTouches[button] = {Input = input, Role = role, Kind = kind, Delta = Vector2.zero}
	self.ActionAim[kind] = Vector2.zero
	self.ActionMagnitude[kind] = 0
	setPressed(button, true)
	if kind == "Pass" or kind == "Shot" then
		self.Controller:BeginMobileAction(kind, options)
	elseif kind == "Sprint" and self.SprintMode == "Hold" then
		self.Controller:SetSprintRequested(true)
	end
end

function Controls:_finishActionTouch(input: InputObject, cancelled: boolean)
	for button, state in self.ActionTouches do
		if state.Input == input then
			self.ActionTouches[button] = nil
			self.AimLine.Visible = false
			setPressed(button, false)
			if cancelled then
				if state.Kind == "Pass" or state.Kind == "Shot" then self.Controller:CancelMobileAction(state.Kind) end
			elseif state.Kind == "Pass" then
				local delta = state.Delta
				local swipe = ActionTuning.MobilePassSwipePixels * (self.ControlScale or 1)
				if state.Role == "Primary" and delta.Magnitude >= swipe and -delta.Y > math.abs(delta.X) * 0.7 then self.PassMode = "Through" elseif state.Role == "Context" then self.PassMode = if self.ContextAction == "Cross" or self.ContextAction == "Lob" then "Lob" else "Through" else self.PassMode = "Ground" end
				self.Controller:EndMobileAction("Pass")
			elseif state.Kind == "Shot" then
				self.Controller:EndMobileAction("Shot")
			elseif state.Kind == "Sprint" then
				if self.SprintMode == "Hold" then self.Controller:SetSprintRequested(false) else self.Controller:ToggleSprint() end
			else
				self.Controller:TriggerMobileAction(state.Kind)
			end
			return
		end
	end
end

function Controls:_bindActionButton(button: TextButton, role: string)
	table.insert(self.Connections, button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if self.ShootingOnly and role ~= "Secondary" then
			return
		end
		self:_beginActionTouch(button, input, role)
	end))
end

function Controls:SetPreferences(sprintMode: string?, handedness: string?)
	self.SprintMode = if sprintMode == "Hold" then "Hold" else "Toggle"
	self.Handedness = if handedness == "Left" then "Left" else "Right"
	local scale = self.ControlScale or 1
	local function px(value: number): number return math.floor(value * scale + 0.5) end
	if self.Handedness == "Left" then
		self.Joystick.Position = UDim2.new(1, -px(126), 1, -px(136))
		self.PrimaryButton.Position = UDim2.new(0, px(108), 1, -px(156))
		self.SecondaryButton.Position = UDim2.new(0, px(182), 1, -px(244))
		self.SprintButton.Position = UDim2.new(0, px(290), 1, -px(126))
		self.ContextButton.Position = UDim2.new(0, px(310), 1, -px(220))
	else
		self.Joystick.Position = UDim2.new(0, px(126), 1, -px(136))
		self.PrimaryButton.Position = UDim2.new(1, -px(108), 1, -px(156))
		self.SecondaryButton.Position = UDim2.new(1, -px(182), 1, -px(244))
		self.SprintButton.Position = UDim2.new(1, -px(290), 1, -px(126))
		self.ContextButton.Position = UDim2.new(1, -px(310), 1, -px(220))
	end
end

function Controls:SetVisible(visible: boolean)
	self.Gui.Enabled = visible == true
end

function Controls:PulseMovement(intensity: number?)
	local strength = math.clamp(tonumber(intensity) or 1, 1, 2)
	local outline = self.Joystick:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Transparency = 0.05
		outline.Thickness = 2.4 * strength
		TweenService:Create(outline, TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.45, Thickness = 1.2}):Play()
	end
end

function Controls:SetContextAction(action: string?)
	local value = tostring(action or "Through")
	if value ~= "Through" and value ~= "Cross" and value ~= "Lob" and value ~= "Skill" and value ~= "SlideTackle" and value ~= "Block" then
		value = if self.Defending then "SlideTackle" else "Through"
	end
	self.ContextAction = value
	self.ContextButton.Text = string.upper(if value == "SlideTackle" then "SLIDE" else value)
end

function Controls:SetDefending(defending: boolean)
	self.Defending = defending == true
	if self.ShootingOnly then
		self.PrimaryButton.Visible = false
		self.SecondaryButton.Visible = true
		self.SecondaryButton.Text = "SHOOT"
		self.SprintButton.Visible = false
		self.ContextButton.Visible = false
		return
	end
	self.PrimaryButton.Visible = true
	self.SecondaryButton.Visible = true
	self.SprintButton.Visible = true
	self.ContextButton.Visible = true
	self.PrimaryButton.Text = if self.Defending then "TACKLE" else "PASS"
	self.SecondaryButton.Text = if self.Defending then "SWITCH" else "SHOOT"
	local color = if self.Defending then RED else GREEN
	local outline = self.PrimaryButton:FindFirstChildOfClass("UIStroke")
	if outline then outline.Color = color end
	self:SetContextAction(if self.Defending then "SlideTackle" else "Through")
end

function Controls:SetShootingOnly(active: boolean)
	self.ShootingOnly = active == true
	self.PassMode = nil
	for button, state in self.ActionTouches do
		self:_finishActionTouch(state.Input, true)
		setPressed(button, false)
	end
	self:SetDefending(self.Defending)
end

function Controls:SetSprintState(requested: boolean, actual: boolean, allowed: boolean, exhausted: boolean)
	if not allowed then
		self.SprintButton.Text = "SPRINT"
		self.SprintButton.TextColor3 = Color3.fromHex("7B8378")
		setPressed(self.SprintButton, false, Color3.fromHex("596057"))
	elseif exhausted then
		self.SprintButton.Text = if requested then "RECOVER" else "SPRINT"
		self.SprintButton.TextColor3 = AMBER
		setPressed(self.SprintButton, false, AMBER)
	else
		self.SprintButton.Text = if actual then "SPRINTING" else "SPRINT"
		self.SprintButton.TextColor3 = WHITE
		setPressed(self.SprintButton, requested, GREEN)
	end
end

function Controls:MoveVector(): Vector2
	return self.MoveInput
end

function Controls:AimVector(kind: string?): Vector2?
	local key = if kind == "GamepadShot" then "Shot" elseif kind == "Pass" then "Pass" else kind
	local value = self.ActionAim[key or ""]
	return if value and value.Magnitude > 0 then value else nil
end

function Controls:IsManualAim(kind: string?): boolean
	local key = if kind == "GamepadShot" then "Shot" else kind or ""
	return (tonumber(self.ActionMagnitude[key]) or 0) > ActionTuning.MobileDeadZonePixels * (self.ControlScale or 1)
end

function Controls:ConsumePassMode(): string?
	local mode = self.PassMode
	self.PassMode = nil
	return mode
end

function Controls:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	if self.Gui then
		self.Gui:Destroy()
	end
end

return Controls
