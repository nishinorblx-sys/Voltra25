from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

mobile_path = Path("src/client/Components/VoltraLiteMobileControls.lua")
mobile_path.parent.mkdir(parents=True, exist_ok=True)

mobile_path.write_text('''--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Controls = {}
Controls.__index = Controls

local GREEN = Color3.fromHex("B7FF1A")
local WHITE = Color3.fromHex("F5F7F2")
local BLACK = Color3.fromHex("061006")
local RED = Color3.fromHex("FF4056")

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

local function circle(parent: Instance, name: string, size: number, pos: UDim2, text: string, textSize: number, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = pos
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = BLACK
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = WHITE
	button.TextSize = textSize
	button.Font = Enum.Font.GothamBlack
	button.ZIndex = 210
	button.Parent = parent
	corner(button, size)
	stroke(button, color or GREEN, 0.04, 2)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.58, 0.58)
	glow.BackgroundColor3 = color or GREEN
	glow.BackgroundTransparency = 0.72
	glow.BorderSizePixel = 0
	glow.ZIndex = 209
	glow.Parent = button
	corner(glow, size)
	return button
end

local function pressed(button: TextButton, state: boolean)
	button.BackgroundTransparency = state and 0.01 or 0.1
	local glow = button:FindFirstChild("Glow")
	if glow and glow:IsA("Frame") then
		glow.BackgroundTransparency = state and 0.26 or 0.72
	end
	local line = button:FindFirstChildOfClass("UIStroke")
	if line then line.Thickness = state and 3 or 2 end
end

function Controls.new(controller: any)
	local self = setmetatable({}, Controls)
	self.Controller = controller
	self.Connections = {}
	self.MoveInput = Vector2.zero
	self.PassMode = nil
	self.Defending = false

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
	base.BackgroundTransparency = 0.32
	base.BorderSizePixel = 0
	base.Active = true
	base.ZIndex = 205
	base.Parent = root
	corner(base, 130)
	stroke(base, GREEN, 0.32, 1)

	local arrows = Instance.new("TextLabel")
	arrows.BackgroundTransparency = 1
	arrows.Size = UDim2.fromScale(1, 1)
	arrows.Text = "▲\\n◀     ▶\\n▼"
	arrows.TextColor3 = GREEN
	arrows.TextTransparency = 0.16
	arrows.TextSize = 20
	arrows.Font = Enum.Font.GothamBlack
	arrows.ZIndex = 206
	arrows.Parent = base

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(56, 56)
	knob.BackgroundColor3 = GREEN
	knob.BackgroundTransparency = 0.03
	knob.BorderSizePixel = 0
	knob.ZIndex = 207
	knob.Parent = base
	corner(knob, 56)
	stroke(knob, WHITE, 0.62, 1)

	self.Joystick = base
	self.Knob = knob

	self.PassButton = circle(root, "PassButton", 78, UDim2.new(1, -188, 1, -104), "PASS", 16, GREEN)
	self.ShootButton = circle(root, "ShootButton", 86, UDim2.new(1, -102, 1, -184), "SHOOT", 17, GREEN)
	self.LobButton = circle(root, "LobButton", 64, UDim2.new(1, -218, 1, -190), "LOB", 15, GREEN)

	self.TackleButton = circle(root, "TackleButton", 82, UDim2.new(1, -110, 1, -132), "TACKLE", 13, RED)
	self.SlideButton = circle(root, "SlideButton", 72, UDim2.new(1, -205, 1, -112), "SLIDE", 13, RED)

	self.SwitchButton = circle(root, "SwitchButton", 56, UDim2.new(1, -78, 1, -276), "SWITCH", 9, GREEN)

	local moveTouch: InputObject? = nil
	local function updateMove(input: InputObject)
		local center = Vector2.new(base.AbsolutePosition.X + base.AbsoluteSize.X * 0.5, base.AbsolutePosition.Y + base.AbsoluteSize.Y * 0.5)
		local delta = Vector2.new(input.Position.X, input.Position.Y) - center
		local radius = base.AbsoluteSize.X * 0.4
		if delta.Magnitude > radius then delta = delta.Unit * radius end
		self.MoveInput = radius > 0 and Vector2.new(delta.X / radius, -delta.Y / radius) or Vector2.zero
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
			self.MoveInput = Vector2.zero
			knob.Position = UDim2.fromScale(0.5, 0.5)
		end
	end))

	self:_bindChargeButton(self.PassButton, "Pass", nil)
	self:_bindChargeButton(self.ShootButton, "Shot", nil)
	self:_bindChargeButton(self.LobButton, "Pass", "Lofted")

	self.TackleButton.Activated:Connect(function()
		controller.Remote:FireServer({Type = "Tackle"})
	end)

	self.SlideButton.Activated:Connect(function()
		controller.Remote:FireServer({Type = "SlideTackle"})
	end)

	self.SwitchButton.Activated:Connect(function()
		local aim = controller:_aim("Switch")
		controller.Remote:FireServer({Type = "Switch", TargetModel = aim.TargetModel, AimPosition = aim.Position})
	end)

	self:SetDefending(false)

	return self
end

function Controls:_bindChargeButton(button: TextButton, kind: string, passMode: string?)
	local touch: InputObject? = nil
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		touch = input
		self.PassMode = passMode
		pressed(button, true)
		self.Controller:_chargeStart(kind)
	end)
	UserInputService.TouchEnded:Connect(function(input)
		if input ~= touch then return end
		self.PassMode = passMode
		self.Controller:_chargeEnd(kind)
		pressed(button, false)
		touch = nil
	end)
end

function Controls:SetDefending(defending: boolean)
	self.Defending = defending == true
	self.PassButton.Visible = not self.Defending
	self.ShootButton.Visible = not self.Defending
	self.LobButton.Visible = not self.Defending
	self.TackleButton.Visible = self.Defending
	self.SlideButton.Visible = self.Defending
	self.SwitchButton.Visible = true
end

function Controls:MoveVector(): Vector2
	return self.MoveInput
end

function Controls:AimVector(_kind: string?): Vector2?
	if self.MoveInput.Magnitude > 0.12 then
		return self.MoveInput.Unit
	end
	return nil
end

function Controls:IsManualAim(_kind: string?): boolean
	return false
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
''', encoding="utf-8", newline="\n")

input_path = Path("src/client/Gameplay/InputController.lua")
text = input_path.read_text(encoding="utf-8")

start = text.find("\nfunction Controller:_createMobileControls()")
finish = text.find("\nfunction Controller:Start()", start)
if start != -1 and finish != -1:
    text = text[:start] + "\n" + text[finish:]

text = text.replace("\n\tself:_createMobileControls()", "")

text = text.replace(
'''function Controller:Move(): Vector2
	local keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
	if keyboard.Magnitude > 1 then
		keyboard = keyboard.Unit
	end
	local mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or mobile
end

	local mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or mobile
end''',
'''function Controller:Move(): Vector2
	local keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
	if keyboard.Magnitude > 1 then
		keyboard = keyboard.Unit
	end
	local mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or mobile
end''',
1
)

if "VoltraLiteMobileControls" not in text:
    text = replace_once(
        text,
        'local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)',
        'local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)\nlocal VoltraLiteMobileControls = require(script:FindFirstAncestor("VTRClient").Components.VoltraLiteMobileControls)',
        "mobile controls require"
    )

if "self.MobileControls = VoltraLiteMobileControls.new(self)" not in text:
    text = replace_once(
        text,
'''function Controller:Start()
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)''',
'''function Controller:Start()
	if UserInputService.TouchEnabled and not self.MobileControls then
		self.MobileControls = VoltraLiteMobileControls.new(self)
	end
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)''',
        "mobile controls start"
    )

text = replace_once(
    text,
'''		local mobileMode = self:MobilePassMode()
		local passType=mobileMode or manualLobbed and"ManualLobbed"or manual and"Manual"or lofted and"Lofted"or through and"Through"or"Ground"
		local isManual = manual or manualLobbed or self:MobileManualAim("Pass")
		self.Remote:FireServer({Type = "Pass", Direction = aim.Direction, AimPosition = aim.Position, TargetModel = isManual and nil or aim.TargetModel, Charge = charge, PassType = passType, AutoSwitch = isManual and"Off"or self.AutoSwitch, ReceiverAssist = isManual and"Off"or self.ReceiverAssist})''',
'''		local mobileMode = self:MobilePassMode()
		local passType=mobileMode or manualLobbed and"ManualLobbed"or manual and"Manual"or lofted and"Lofted"or through and"Through"or"Ground"
		local isMobile = self.MobileControls ~= nil
		local isManual = manual or manualLobbed or self:MobileManualAim("Pass")
		local autoSwitch = isMobile and "Off" or (isManual and "Off" or self.AutoSwitch)
		local receiverAssist = isMobile and "Off" or (isManual and "Off" or self.ReceiverAssist)
		self.Remote:FireServer({Type = "Pass", Direction = aim.Direction, AimPosition = aim.Position, TargetModel = isManual and nil or aim.TargetModel, Charge = charge, PassType = passType, AutoSwitch = autoSwitch, ReceiverAssist = receiverAssist})''',
    "mobile pass auto switch off"
)

if "function Controller:SetMobileDefending" not in text:
    text = text.replace(
'''function Controller:Sprinting(): boolean
	return self.Keys[Enum.KeyCode.LeftShift] == true or self.Keys[Enum.KeyCode.RightShift] == true
end''',
'''function Controller:SetMobileDefending(defending: boolean)
	if self.MobileControls and self.MobileControls.SetDefending then
		self.MobileControls:SetDefending(defending)
	end
end

function Controller:Sprinting(): boolean
	return true
end''',
1
    )

text = replace_once(
    text,
'''function Controller:Destroy()
	if self.TouchGui then self.TouchGui:Destroy();self.TouchGui=nil end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end''',
'''function Controller:Destroy()
	if self.MobileControls then self.MobileControls:Destroy();self.MobileControls=nil end
	if self.TouchGui then self.TouchGui:Destroy();self.TouchGui=nil end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end''',
    "destroy mobile controls"
)

input_path.write_text(text, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = replace_once(
    gameplay,
'''local root=self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?;local hasBall=self.Ball:GetAttribute("OwnerModel")==self.ActiveModel.Name or self.SetPieceMode=="PenaltyDefense";local charge=self.Input:ChargeValue();''',
'''local root=self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?;local hasBall=self.Ball:GetAttribute("OwnerModel")==self.ActiveModel.Name or self.SetPieceMode=="PenaltyDefense";if self.Input and self.Input.SetMobileDefending then self.Input:SetMobileDefending(not hasBall)end;local charge=self.Input:ChargeValue();''',
    "mobile defense mode"
)

gameplay = replace_once(
    gameplay,
'''elseif payload.Type=="Pass"then if self.HUD then self.HUD:HideKickoffScorer()end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Pass")end''',
'''elseif payload.Type=="Pass"then if self.HUD then self.HUD:HideKickoffScorer()end;if self.Ball then self.Ball.LocalTransparencyModifier=0 end;if self.Visual then self.Visual:PlayFlightTrail()end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Pass")end''',
    "mobile pass visibility trail"
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = replace_once(
    runtime,
'''local sprinting=state.SprintRequested==true and active:GetAttribute("VTRSprintLocked")~=true and(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0)>.1 and state.Stamina>=Config.Stamina.MinimumToSprint''',
'''local sprinting=active:GetAttribute("VTRSprintLocked")~=true and(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0)>.1 and state.Stamina>=Config.Stamina.MinimumToSprint''',
    "automatic sprint"
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

print("fixed mobile joystick movement, mobile defense buttons, removed sprint button, fixed mobile pass visibility")