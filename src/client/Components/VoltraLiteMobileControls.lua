--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Controls = {}
Controls.__index = Controls

local GREEN = Color3.fromHex("B7FF1A")
local WHITE = Color3.fromHex("F5F7F2")
local BLACK = Color3.fromHex("061006")

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Transparency = transparency
	item.Thickness = thickness
	item.Parent = parent
	return item
end

local function circle(parent: Instance, name: string, size: number, pos: UDim2, text: string, textSize: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = pos
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = BLACK
	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = WHITE
	button.TextSize = textSize
	button.Font = Enum.Font.GothamBlack
	button.ZIndex = 210
	button.Parent = parent
	corner(button, size)
	stroke(button, GREEN, 0.06, 2)
	local inner = Instance.new("Frame")
	inner.Name = "GreenGlow"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.58, 0.58)
	inner.BackgroundColor3 = GREEN
	inner.BackgroundTransparency = 0.78
	inner.BorderSizePixel = 0
	inner.ZIndex = 209
	inner.Parent = button
	corner(inner, size)
	return button
end

local function pressed(button: TextButton, state: boolean)
	button.BackgroundTransparency = state and 0.02 or 0.12
	button.BackgroundColor3 = state and Color3.fromHex("173617") or BLACK
	local glow = button:FindFirstChild("GreenGlow")
	if glow and glow:IsA("Frame") then
		glow.BackgroundTransparency = state and 0.32 or 0.78
	end
	local line = button:FindFirstChildOfClass("UIStroke")
	if line then line.Thickness = state and 3 or 2 end
end

function Controls.new(controller: any)
	local self = setmetatable({}, Controls)
	self.Controller = controller
	self.Connections = {}
	self.MoveVector = Vector2.zero
	self.ButtonAimVector = nil
	self.ButtonAimKind = nil
	self.ManualKind = nil
	self.PassMode = nil
	self.Gui = Instance.new("ScreenGui")
	self.Gui.Name = "VTRLiteMobileControls"
	self.Gui.IgnoreGuiInset = true
	self.Gui.ResetOnSpawn = false
	self.Gui.DisplayOrder = 170
	self.Gui.Parent = Players.LocalPlayer.PlayerGui
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = self.Gui
	self.Root = root
	local base = Instance.new("Frame")
	base.Name = "MovementJoystick"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Position = UDim2.new(0, 98, 1, -108)
	base.Size = UDim2.fromOffset(130, 130)
	base.BackgroundColor3 = BLACK
	base.BackgroundTransparency = 0.34
	base.BorderSizePixel = 0
	base.Active = true
	base.ZIndex = 205
	base.Parent = root
	corner(base, 130)
	stroke(base, GREEN, 0.42, 1)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(56, 56)
	knob.BackgroundColor3 = GREEN
	knob.BackgroundTransparency = 0.04
	knob.BorderSizePixel = 0
	knob.Active = false
	knob.ZIndex = 207
	knob.Parent = base
	corner(knob, 56)
	stroke(knob, WHITE, 0.64, 1)
	local arrows = Instance.new("TextLabel")
	arrows.BackgroundTransparency = 1
	arrows.Size = UDim2.fromScale(1, 1)
	arrows.Text = "▲\n◀     ▶\n▼"
	arrows.TextColor3 = GREEN
	arrows.TextTransparency = 0.18
	arrows.TextSize = 20
	arrows.Font = Enum.Font.GothamBlack
	arrows.ZIndex = 206
	arrows.Parent = base
	self.Joystick = base
	self.Knob = knob
	self.PassButton = circle(root, "PassButton", 78, UDim2.new(1, -188, 1, -104), "PASS", 16)
	self.ShootButton = circle(root, "ShootButton", 86, UDim2.new(1, -102, 1, -184), "SHOOT", 17)
	self.LobButton = circle(root, "LobButton", 64, UDim2.new(1, -218, 1, -190), "LOB", 15)
	self.SprintButton = circle(root, "SprintTackleButton", 70, UDim2.new(1, -96, 1, -76), "SPRINT", 12)
	self.SwitchButton = circle(root, "SwitchButton", 52, UDim2.new(1, -76, 1, -276), "SWITCH", 9)
	local aimLine = Instance.new("Frame")
	aimLine.Name = "AimLine"
	aimLine.AnchorPoint = Vector2.new(0, 0.5)
	aimLine.BackgroundColor3 = GREEN
	aimLine.BackgroundTransparency = 0.12
	aimLine.BorderSizePixel = 0
	aimLine.Visible = false
	aimLine.ZIndex = 215
	aimLine.Parent = root
	corner(aimLine, 4)
	self.AimLine = aimLine
	local ring = Instance.new("Frame")
	ring.Name = "ReceiverRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(28, 28)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.ZIndex = 215
	ring.Parent = root
	corner(ring, 28)
	stroke(ring, GREEN, 0.02, 2)
	self.ReceiverRing = ring
	local moveTouch = nil
	local function updateMove(input: InputObject)
		local center = Vector2.new(base.AbsolutePosition.X + base.AbsoluteSize.X * 0.5, base.AbsolutePosition.Y + base.AbsoluteSize.Y * 0.5)
		local delta = Vector2.new(input.Position.X, input.Position.Y) - center
		local radius = base.AbsoluteSize.X * 0.40
		if delta.Magnitude > radius then delta = delta.Unit * radius end
		self.MoveVector = radius > 0 and Vector2.new(delta.X / radius, -delta.Y / radius) or Vector2.zero
		knob.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
	end
	table.insert(self.Connections, base.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			moveTouch = input
			updateMove(input)
		end
	end))
	table.insert(self.Connections, UserInputService.TouchMoved:Connect(function(input)
		if input == moveTouch then updateMove(input) end
	end))
	table.insert(self.Connections, UserInputService.TouchEnded:Connect(function(input)
		if input == moveTouch then
			moveTouch = nil
			self.MoveVector = Vector2.zero
			knob.Position = UDim2.fromScale(0.5, 0.5)
		end
	end))
	self:_bindAction(self.PassButton, "Pass")
	self:_bindAction(self.ShootButton, "Shot")
	self:_bindAction(self.LobButton, "Lob")
	self.SwitchButton.Activated:Connect(function()
		local aim = controller:_aim("Switch")
		controller.Remote:FireServer({Type = "Switch", TargetModel = aim.TargetModel, AimPosition = aim.Position})
	end)
	local sprintStarted = 0
	local lastTap = 0
	self.SprintButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		sprintStarted = os.clock()
		if sprintStarted - lastTap < 0.34 then
			controller.Keys[Enum.KeyCode.LeftShift] = true
			task.delay(0.55, function() controller.Keys[Enum.KeyCode.LeftShift] = nil end)
		else
			controller.Keys[Enum.KeyCode.LeftShift] = true
		end
		lastTap = sprintStarted
		pressed(self.SprintButton, true)
	end)
	self.SprintButton.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		controller.Keys[Enum.KeyCode.LeftShift] = nil
		pressed(self.SprintButton, false)
		if os.clock() - sprintStarted < 0.28 then
			controller.Remote:FireServer({Type = "Tackle"})
		end
	end)
	return self
end

function Controls:_drawButtonAim(button: GuiObject, pos: Vector2, kind: string)
	local center = Vector2.new(button.AbsolutePosition.X + button.AbsoluteSize.X * 0.5, button.AbsolutePosition.Y + button.AbsoluteSize.Y * 0.5)
	local delta = pos - center
	if delta.Magnitude < 14 then
		self.ButtonAimVector = nil
		self.ButtonAimKind = nil
		self.ManualKind = nil
		self.AimLine.Visible = false
		self.ReceiverRing.Visible = false
		return
	end
	local unit = delta.Unit
	self.ButtonAimVector = Vector2.new(unit.X, -unit.Y)
	self.ButtonAimKind = kind
	self.ManualKind = kind == "Lob" and "Pass" or kind
	local length = math.clamp(delta.Magnitude, 22, 140)
	self.AimLine.Visible = true
	self.AimLine.Position = UDim2.fromOffset(center.X, center.Y)
	self.AimLine.Size = UDim2.fromOffset(length, 4)
	self.AimLine.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	self.ReceiverRing.Visible = true
	self.ReceiverRing.Position = UDim2.fromOffset(center.X + unit.X * length, center.Y + unit.Y * length)
end

function Controls:_clearButtonAim()
	self.ButtonAimVector = nil
	self.ButtonAimKind = nil
	self.ManualKind = nil
	self.AimLine.Visible = false
	self.ReceiverRing.Visible = false
end

function Controls:_bindAction(button: TextButton, kind: string)
	local touch = nil
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		touch = input
		pressed(button, true)
		if kind == "Lob" then
			self.PassMode = "Lofted"
			self.Controller:_chargeStart("Pass")
		else
			self.Controller:_chargeStart(kind)
		end
	end)
	UserInputService.TouchMoved:Connect(function(input)
		if input == touch then self:_drawButtonAim(button, Vector2.new(input.Position.X, input.Position.Y), kind) end
	end)
	UserInputService.TouchEnded:Connect(function(input)
		if input ~= touch then return end
		if kind == "Lob" then
			self.PassMode = "Lofted"
			self.Controller:_chargeEnd("Pass")
		else
			self.Controller:_chargeEnd(kind)
		end
		pressed(button, false)
		self:_clearButtonAim()
		touch = nil
	end)
end

function Controls:MoveVector(): Vector2
	return self.MoveVector
end

function Controls:AimVector(kind: string?): Vector2?
	local actionKind = kind == "Lob" and "Pass" or kind
	if self.ButtonAimVector and (self.ButtonAimKind == kind or self.ManualKind == actionKind) then
		return self.ButtonAimVector
	end
	if self.MoveVector.Magnitude > 0.12 then
		return self.MoveVector.Unit
	end
	return nil
end

function Controls:IsManualAim(kind: string?): boolean
	return self.ManualKind == kind
end

function Controls:ConsumePassMode(): string?
	local mode = self.PassMode
	self.PassMode = nil
	return mode
end

function Controls:Destroy()
	if self.Gui then self.Gui:Destroy() end
	for _, connection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
end

return Controls
