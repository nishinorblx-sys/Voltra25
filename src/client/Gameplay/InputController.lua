--!strict
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)

local Controller = {}
Controller.__index = Controller

function Controller.new(remote: RemoteEvent, aim: (string?,number?) -> any)
	return setmetatable({Remote = remote, Aim = aim, Keys = {}, Charge = nil, Connections = {}, AutoSwitch = "Assisted", ReceiverAssist = "Light", FreeKickCurve = 0, FreeKickLift = 0, LastFreeKickAt = 0}, Controller)
end

function Controller:SetAutoSwitch(mode: string?)
	self.AutoSwitch = mode == "Off" and "Off" or mode == "Instant" and "Instant" or "Assisted"
end

function Controller:SetReceiverAssist(mode: string?)
	self.ReceiverAssist = mode == "Off" and "Off" or mode == "Assisted" and "Assisted" or "Light"
end

function Controller:SetSuppressed(suppressed:boolean)
	self.Suppressed=suppressed
	if suppressed then
		self.Charge=nil
	else
		for _,key in {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl} do
			self.Keys[key] = UserInputService:IsKeyDown(key) or nil
		end
	end
end

function Controller:ResetFreeKickModifiers()
	self.FreeKickCurve = 0
	self.FreeKickLift = 0
	self.LastFreeKickAt = os.clock()
end

function Controller:_aim(kind: string,charge:number?): any
	local value = self.Aim(kind,charge)
	if type(value) == "table" then
		return value
	end
	return {Direction = value}
end

function Controller:_chargeStart(kind: string)
	if not self.Charge then
		self.Charge = {Kind = kind, Started = os.clock()}
	end
end

function Controller:_chargeEnd(kind: string)
	local current = self.Charge
	if not current or current.Kind ~= kind then
		return
	end
	local charge = math.clamp((os.clock() - current.Started) / (Config.Ball.MaxChargeTime / 3), 0, 1)
	self.Charge = nil
	local aim = self:_aim(kind,charge)
	if kind == "Shot" then
		self.Remote:FireServer({Type = "Shot", Direction = aim.Direction, AimPosition = aim.Position, GoalTarget = aim.GoalTarget, Charge = charge, FreeKickCurve = aim.FreeKickCurve, FreeKickLift = aim.FreeKickLift, PenaltySlot = aim.PenaltySlot})
	else
		local altDown = self.Keys[Enum.KeyCode.LeftAlt] == true or self.Keys[Enum.KeyCode.RightAlt] == true
		local ctrlDown = self.Keys[Enum.KeyCode.LeftControl] == true or self.Keys[Enum.KeyCode.RightControl] == true
		local manualLobbed = altDown and ctrlDown
		local manual = ctrlDown and not manualLobbed
		local lofted = altDown and not ctrlDown
		local through=not manualLobbed and not manual and not lofted and self.Keys[Enum.KeyCode.W] == true and charge >= 0.18
		local passType=manualLobbed and"ManualLobbed"or manual and"Manual"or lofted and"Lofted"or through and"Through"or"Ground"
		local isManual = manual or manualLobbed
		self.Remote:FireServer({Type = "Pass", Direction = aim.Direction, AimPosition = aim.Position, TargetModel = isManual and nil or aim.TargetModel, Charge = charge, PassType = passType, AutoSwitch = isManual and"Off"or self.AutoSwitch, ReceiverAssist = isManual and"Off"or self.ReceiverAssist})
	end
end

function Controller:_createMobileControls()
	if self.TouchGui or not UserInputService.TouchEnabled then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRMobileMatchControls"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 130
	gui.Parent = Players.LocalPlayer.PlayerGui
	DeviceScaleService.Apply(gui)
	self.TouchGui = gui
	self.TouchVector = Vector2.zero
	local base = Instance.new("Frame")
	base.Name = "MoveStick"
	base.AnchorPoint = Vector2.new(0, 1)
	base.Position = UDim2.new(0, 34, 1, -42)
	base.Size = UDim2.fromOffset(142, 142)
	base.BackgroundColor3 = Color3.fromHex("070A06")
	base.BackgroundTransparency = .34
	base.BorderSizePixel = 0
	base.ZIndex = 130
	base.Parent = gui
	local baseCorner = Instance.new("UICorner")
	baseCorner.CornerRadius = UDim.new(1, 0)
	baseCorner.Parent = base
	local baseStroke = Instance.new("UIStroke")
	baseStroke.Color = Color3.fromHex("B7FF1A")
	baseStroke.Transparency = .42
	baseStroke.Thickness = 2
	baseStroke.Parent = base
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(.5, .5)
	knob.Position = UDim2.fromScale(.5, .5)
	knob.Size = UDim2.fromOffset(48, 48)
	knob.BackgroundColor3 = Color3.fromHex("B7FF1A")
	knob.BackgroundTransparency = .08
	knob.BorderSizePixel = 0
	knob.ZIndex = 131
	knob.Parent = base
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob
	local touchInput = nil
	local function updateStick(input)
		local center = Vector2.new(base.AbsolutePosition.X + base.AbsoluteSize.X * .5, base.AbsolutePosition.Y + base.AbsoluteSize.Y * .5)
		local point = Vector2.new(input.Position.X, input.Position.Y)
		local delta = point - center
		local radius = base.AbsoluteSize.X * .42
		if delta.Magnitude > radius then delta = delta.Unit * radius end
		self.TouchVector = radius > 0 and Vector2.new(delta.X / radius, -delta.Y / radius) or Vector2.zero
		knob.Position = UDim2.new(.5, delta.X, .5, delta.Y)
	end
	local function stopStick()
		touchInput = nil
		self.TouchVector = Vector2.zero
		knob.Position = UDim2.fromScale(.5, .5)
	end
	table.insert(self.Connections, base.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchInput = input
			updateStick(input)
		end
	end))
	table.insert(self.Connections, UserInputService.TouchMoved:Connect(function(input)
		if input == touchInput then updateStick(input) end
	end))
	table.insert(self.Connections, UserInputService.TouchEnded:Connect(function(input)
		if input == touchInput then stopStick() end
	end))
	local function makeButton(name, text, position, size, callback)
		local button = Instance.new("TextButton")
		button.Name = name
		button.AnchorPoint = Vector2.new(.5, .5)
		button.Position = position
		button.Size = size
		button.BackgroundColor3 = Color3.fromHex("071009")
		button.BackgroundTransparency = .12
		button.BorderSizePixel = 0
		button.Text = text
		button.TextColor3 = Color3.fromHex("F5F7F2")
		button.TextSize = 12
		button.Font = Enum.Font.GothamBlack
		button.AutoButtonColor = true
		button.ZIndex = 132
		button.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = button
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromHex("B7FF1A")
		s.Transparency = .35
		s.Thickness = 1
		s.Parent = button
		button.Activated:Connect(function()
			if not self.Suppressed then callback(button) end
		end)
		return button
	end
	makeButton("ShotButton", "SHOOT", UDim2.new(1, -88, 1, -154), UDim2.fromOffset(82, 82), function()
		self:_chargeStart("Shot")
		task.delay(.16, function()
			if self.Charge and self.Charge.Kind == "Shot" then self:_chargeEnd("Shot") end
		end)
	end)
	makeButton("PassButton", "PASS", UDim2.new(1, -174, 1, -90), UDim2.fromOffset(76, 76), function()
		self:_chargeStart("Pass")
		task.delay(.13, function()
			if self.Charge and self.Charge.Kind == "Pass" then self:_chargeEnd("Pass") end
		end)
	end)
	makeButton("TackleButton", "TACKLE", UDim2.new(1, -82, 1, -62), UDim2.fromOffset(70, 70), function()
		self.Remote:FireServer({Type = "Tackle"})
	end)
	makeButton("SlideButton", "SLIDE", UDim2.new(1, -247, 1, -58), UDim2.fromOffset(62, 62), function()
		self.Remote:FireServer({Type = "SlideTackle"})
	end)
	makeButton("SkillButton", "SKILL", UDim2.new(1, -258, 1, -132), UDim2.fromOffset(58, 58), function()
		local aim = self:_aim("Skill")
		self.Remote:FireServer({Type = "DribbleMove", Direction = aim.Direction})
	end)
	makeButton("SwitchButton", "SWITCH", UDim2.new(1, -326, 1, -66), UDim2.fromOffset(58, 58), function()
		local aim = self:_aim("Switch")
		self.Remote:FireServer({Type = "Switch", TargetModel = aim.TargetModel, AimPosition = aim.Position})
	end)
	local sprinting = false
	makeButton("SprintButton", "SPRINT", UDim2.new(0, 230, 1, -72), UDim2.fromOffset(82, 50), function(button)
		sprinting = not sprinting
		self.Keys[Enum.KeyCode.LeftShift] = sprinting or nil
		button.Text = sprinting and "SPRINT ON" or "SPRINT"
	end)
	makeButton("BlockButton", "BLOCK", UDim2.new(0, 326, 1, -72), UDim2.fromOffset(78, 50), function()
		self.Remote:FireServer({Type = "Block", Active = true})
		task.delay(.45, function()
			self.Remote:FireServer({Type = "Block", Active = false})
		end)
	end)
end

function Controller:Start()
	self:_createMobileControls()
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		local isMouseAction = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
		if self.Suppressed or (processed and not isMouseAction) then
			return
		end
		if isMouseAction and UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D
			or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift
			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then
			self.Keys[key] = true
		elseif key == Enum.KeyCode.E then
			self.Remote:FireServer({Type = "Tackle"})
		elseif key==Enum.KeyCode.F then
			self.Remote:FireServer({Type="SlideTackle"})
		elseif key==Enum.KeyCode.C then
			local aim=self:_aim("Skill");self.Remote:FireServer({Type="DribbleMove",Direction=aim.Direction})
		elseif key==Enum.KeyCode.R then
			self.Remote:FireServer({Type="Block",Active=true})
		elseif key == Enum.KeyCode.Q then
			local aim=self:_aim("Switch");self.Remote:FireServer({Type = "Switch",TargetModel=aim.TargetModel,AimPosition=aim.Position})
		elseif key == Enum.KeyCode.L then
			self.Remote:FireServer({Type = "DebugFreeKick"})
		elseif key == Enum.KeyCode.K then
			self.Remote:FireServer({Type = "DebugPenaltyAttack"})
		elseif key == Enum.KeyCode.O then
			self.Remote:FireServer({Type = "DebugPenaltyDefense"})
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_chargeStart("Shot")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_chargeStart("Pass")
		end
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
		if self.Suppressed then return end
		local isMouseAction = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
		if isMouseAction and UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D
			or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift
			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then
			self.Keys[key] = nil
		elseif key==Enum.KeyCode.R then
			self.Remote:FireServer({Type="Block",Active=false})
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_chargeEnd("Shot")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_chargeEnd("Pass")
		end
	end))
end

function Controller:Move(): Vector2
	local keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
	if keyboard.Magnitude > 1 then
		keyboard = keyboard.Unit
	end
	local touch = self.TouchVector or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or touch
end

function Controller:Sprinting(): boolean
	return self.Keys[Enum.KeyCode.LeftShift] == true or self.Keys[Enum.KeyCode.RightShift] == true
end

function Controller:ChargeValue(): number
	return self.Charge and math.clamp((os.clock() - self.Charge.Started) / (Config.Ball.MaxChargeTime / 3), 0, 1) or 0
end

function Controller:ChargeKind(): string
	return self.Charge and self.Charge.Kind or ""
end

function Controller:FreeKickModifiers(): (number, number)
	local curveClamp = math.clamp(tonumber(workspace:GetAttribute("VTRFreeKickCurveClamp")) or 1, 0, 2.5)
	local liftClamp = math.clamp(tonumber(workspace:GetAttribute("VTRFreeKickLiftClamp")) or 1, 0, 2.5)
	local now = os.clock()
	local dt = math.clamp(now - (self.LastFreeKickAt > 0 and self.LastFreeKickAt or now), 0, 0.08)
	self.LastFreeKickAt = now
	local curveRate = tonumber(workspace:GetAttribute("VTRFreeKickCurveRate")) or 0.72
	local liftRate = tonumber(workspace:GetAttribute("VTRFreeKickLiftRate")) or 0.72
	local curveInput = (self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0)
	local liftInput = (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0)
	self.FreeKickCurve = math.clamp((self.FreeKickCurve or 0) + curveInput * curveRate * dt, -curveClamp, curveClamp)
	self.FreeKickLift = math.clamp((self.FreeKickLift or 0) + liftInput * liftRate * dt, -liftClamp, liftClamp)
	return self.FreeKickCurve, self.FreeKickLift
end

function Controller:Destroy()
	if self.TouchGui then self.TouchGui:Destroy();self.TouchGui=nil end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return Controller
