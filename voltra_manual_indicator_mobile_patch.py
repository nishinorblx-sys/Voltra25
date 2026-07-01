from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

def insert_after_signature(text, signature, block, label):
    if block in text:
        return text
    idx = text.find(signature)
    if idx == -1:
        print("skipped", label)
        return text
    insert_at = idx + len(signature)
    return text[:insert_at] + block + text[insert_at:]

comp_dir = Path("src/client/Components")
comp_dir.mkdir(parents=True, exist_ok=True)

(comp_dir / "VoltraControlledPlayerIndicator.lua").write_text('''--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Indicator = {}
Indicator.__index = Indicator

local function makeRing(): Part
	local part = Instance.new("Part")
	part.Name = "VTRControlledPlayerRing"
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromHex("B7FF1A")
	part.Transparency = 0.14
	part.Size = Vector3.new(0.18, 4.8, 4.8)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function makeBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "VTRControlledPlayerTag"
	gui.Size = UDim2.fromOffset(120, 42)
	gui.StudsOffset = Vector3.new(0, 4.25, 0)
	gui.AlwaysOnTop = true
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "Tag"
	text.BackgroundTransparency = 0.12
	text.BackgroundColor3 = Color3.fromHex("060906")
	text.BorderSizePixel = 0
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.fromScale(0.5, 0)
	text.Size = UDim2.fromOffset(84, 24)
	text.Text = "YOU"
	text.TextColor3 = Color3.fromHex("F5F7F2")
	text.TextSize = 12
	text.Font = Enum.Font.GothamBlack
	text.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("B7FF1A")
	stroke.Transparency = 0.08
	stroke.Thickness = 1.6
	stroke.Parent = text
	local point = Instance.new("TextLabel")
	point.BackgroundTransparency = 1
	point.AnchorPoint = Vector2.new(0.5, 0)
	point.Position = UDim2.fromScale(0.5, 0.48)
	point.Size = UDim2.fromOffset(30, 18)
	point.Text = "▼"
	point.TextColor3 = Color3.fromHex("B7FF1A")
	point.TextSize = 18
	point.Font = Enum.Font.GothamBlack
	point.Parent = holder
	return gui
end

function Indicator.new(modelGetter: () -> Model?)
	local self = setmetatable({}, Indicator)
	self.ModelGetter = modelGetter
	self.Ring = makeRing()
	self.Ring.Parent = workspace
	self.Highlight = Instance.new("Highlight")
	self.Highlight.Name = "VTRControlledPlayerHighlight"
	self.Highlight.FillColor = Color3.fromHex("B7FF1A")
	self.Highlight.FillTransparency = 0.78
	self.Highlight.OutlineColor = Color3.fromHex("F5F7F2")
	self.Highlight.OutlineTransparency = 0.08
	self.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	self.Highlight.Parent = workspace
	self.Tag = makeBillboard()
	self.Tag.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Connection = RunService.RenderStepped:Connect(function()
		self:_step()
	end)
	return self
end

function Indicator:_step()
	local model = self.ModelGetter and self.ModelGetter() or nil
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not model or not root or not root:IsA("BasePart") then
		self.Ring.Transparency = 1
		self.Highlight.Adornee = nil
		self.Tag.Adornee = nil
		return
	end
	self.Ring.Transparency = 0.14
	self.Ring.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.75, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	self.Highlight.Adornee = model
	self.Tag.Adornee = root
end

function Indicator:Destroy()
	if self.Connection then self.Connection:Disconnect() end
	if self.Ring then self.Ring:Destroy() end
	if self.Highlight then self.Highlight:Destroy() end
	if self.Tag then self.Tag:Destroy() end
end

return Indicator
''', encoding="utf-8", newline="\n")

(comp_dir / "VoltraLiteMobileControls.lua").write_text('''--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Controls = {}
Controls.__index = Controls

local GREEN = Color3.fromHex("B7FF1A")
local WHITE = Color3.fromHex("F5F7F2")
local BLACK = Color3.fromHex("060906")

local function circle(parent: Instance, name: string, size: number, pos: UDim2, text: string, textSize: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = pos
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = BLACK
	button.BackgroundTransparency = 0.22
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = WHITE
	button.TextSize = textSize
	button.Font = Enum.Font.GothamBlack
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = GREEN
	stroke.Transparency = 0.06
	stroke.Thickness = 2
	stroke.Parent = button
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("111811")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("050805"))
	})
	glow.Rotation = 90
	glow.Parent = button
	return button
end

local function setPressed(button: TextButton, pressed: boolean)
	button.BackgroundColor3 = pressed and Color3.fromHex("173117") or BLACK
	button.BackgroundTransparency = pressed and 0.06 or 0.22
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = pressed and 3 or 2
	end
end

local function makeAimLine(parent: Instance): Frame
	local line = Instance.new("Frame")
	line.Name = "AimLine"
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.BackgroundColor3 = GREEN
	line.BackgroundTransparency = 0.15
	line.BorderSizePixel = 0
	line.Visible = false
	line.ZIndex = 212
	line.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = line
	return line
end

local function makeReceiverRing(parent: Instance): Frame
	local ring = Instance.new("Frame")
	ring.Name = "ReceiverRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(24, 24)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.ZIndex = 212
	ring.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = GREEN
	stroke.Transparency = 0.04
	stroke.Thickness = 2
	stroke.Parent = ring
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	return ring
end

function Controls.new(controller: any)
	local self = setmetatable({}, Controls)
	self.Controller = controller
	self.Connections = {}
	self.TouchMoveVector = Vector2.zero
	self.TouchAimVector = nil
	self.TouchAimKind = nil
	self.SprintLatched = false
	self.Gui = Instance.new("ScreenGui")
	self.Gui.Name = "VTRLiteMobileControls"
	self.Gui.IgnoreGuiInset = true
	self.Gui.ResetOnSpawn = false
	self.Gui.DisplayOrder = 165
	self.Gui.Parent = Players.LocalPlayer.PlayerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = self.Gui
	self.Root = root

	local joystickBase = circle(root, "JoystickBase", 130, UDim2.new(0, 96, 1, -108), "", 12)
	joystickBase.Text = ""
	joystickBase.BackgroundTransparency = 0.34
	local arrows = Instance.new("TextLabel")
	arrows.BackgroundTransparency = 1
	arrows.Size = UDim2.fromScale(1, 1)
	arrows.Text = "▲      ▶\\n\\n◀      ▼"
	arrows.TextColor3 = GREEN
	arrows.TextSize = 18
	arrows.Font = Enum.Font.GothamBlack
	arrows.Parent = joystickBase
	local joystickKnob = circle(joystickBase, "JoystickKnob", 56, UDim2.fromScale(0.5, 0.5), "", 12)
	joystickKnob.Text = ""
	joystickKnob.BackgroundTransparency = 0.02
	self.JoystickBase = joystickBase
	self.JoystickKnob = joystickKnob

	self.PassButton = circle(root, "PassButton", 78, UDim2.new(1, -188, 1, -102), "PASS", 16)
	self.ShootButton = circle(root, "ShootButton", 86, UDim2.new(1, -102, 1, -182), "SHOOT", 17)
	self.LobButton = circle(root, "LobButton", 64, UDim2.new(1, -218, 1, -188), "LOB", 15)
	self.SprintButton = circle(root, "SprintTackleButton", 70, UDim2.new(1, -96, 1, -76), "SPRINT", 14)
	self.SwitchButton = circle(root, "SwitchButton", 52, UDim2.new(1, -78, 1, -274), "SWITCH", 10)

	self.PowerArc = Instance.new("Frame")
	self.PowerArc.AnchorPoint = Vector2.new(0.5, 0.5)
	self.PowerArc.Position = UDim2.fromScale(0.5, 0.5)
	self.PowerArc.Size = UDim2.fromScale(1.18, 1.18)
	self.PowerArc.BackgroundTransparency = 1
	self.PowerArc.Parent = self.ShootButton
	local powerStroke = Instance.new("UIStroke")
	powerStroke.Color = GREEN
	powerStroke.Transparency = 0.12
	powerStroke.Thickness = 4
	powerStroke.Parent = self.PowerArc
	local powerCorner = Instance.new("UICorner")
	powerCorner.CornerRadius = UDim.new(1, 0)
	powerCorner.Parent = self.PowerArc
	self.PowerArc.Visible = false

	self.AimLine = makeAimLine(root)
	self.ReceiverRing = makeReceiverRing(root)

	local moveTouch = nil
	table.insert(self.Connections, joystickBase.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			moveTouch = input
			self:_updateMove(input.Position)
		end
	end))
	table.insert(self.Connections, UserInputService.TouchMoved:Connect(function(input)
		if input == moveTouch then
			self:_updateMove(input.Position)
		end
	end))
	table.insert(self.Connections, UserInputService.TouchEnded:Connect(function(input)
		if input == moveTouch then
			moveTouch = nil
			self.TouchMoveVector = Vector2.zero
			self.JoystickKnob.Position = UDim2.fromScale(0.5, 0.5)
		end
	end))

	self:_bindAction(self.PassButton, "Pass", 0.12, false)
	self:_bindAction(self.ShootButton, "Shot", 0.14, true)
	self:_bindAction(self.LobButton, "Lob", 0.12, false)

	self.SwitchButton.Activated:Connect(function()
		local aim = controller:_aim("Switch")
		controller.Remote:FireServer({Type = "Switch", TargetModel = aim.TargetModel, AimPosition = aim.Position})
	end)

	local sprintTapTimes = {}
	self.SprintButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		local now = os.clock()
		table.insert(sprintTapTimes, now)
		while #sprintTapTimes > 0 and now - sprintTapTimes[1] > 0.35 do
			table.remove(sprintTapTimes, 1)
		end
		if #sprintTapTimes >= 2 then
			self.Controller.Keys[Enum.KeyCode.LeftShift] = true
			task.delay(0.55, function()
				if self.Controller.Keys[Enum.KeyCode.LeftShift] == true then
					self.Controller.Keys[Enum.KeyCode.LeftShift] = nil
				end
			end)
			return
		end
		self.Controller.Keys[Enum.KeyCode.LeftShift] = true
		setPressed(self.SprintButton, true)
	end)
	self.SprintButton.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		self.Controller.Keys[Enum.KeyCode.LeftShift] = nil
		setPressed(self.SprintButton, false)
		self.Controller.Remote:FireServer({Type = "Tackle"})
	end)

	return self
end

function Controls:_updateMove(position: Vector2)
	local center = Vector2.new(self.JoystickBase.AbsolutePosition.X + self.JoystickBase.AbsoluteSize.X * 0.5, self.JoystickBase.AbsolutePosition.Y + self.JoystickBase.AbsoluteSize.Y * 0.5)
	local delta = position - center
	local radius = self.JoystickBase.AbsoluteSize.X * 0.39
	if delta.Magnitude > radius then
		delta = delta.Unit * radius
	end
	self.TouchMoveVector = radius > 0 and Vector2.new(delta.X / radius, -delta.Y / radius) or Vector2.zero
	self.JoystickKnob.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
end

function Controls:_setAim(button: GuiObject, position: Vector2, kind: string)
	local center = Vector2.new(button.AbsolutePosition.X + button.AbsoluteSize.X * 0.5, button.AbsolutePosition.Y + button.AbsoluteSize.Y * 0.5)
	local delta = position - center
	local visual = delta.Magnitude > 12 and delta or Vector2.zero
	local unit = visual.Magnitude > 0 and visual.Unit or Vector2.zero
	self.TouchAimVector = Vector2.new(unit.X, -unit.Y)
	self.TouchAimKind = kind
	local length = math.max(12, math.min(138, visual.Magnitude))
	self.AimLine.Visible = visual.Magnitude > 8
	self.AimLine.Position = UDim2.fromOffset(center.X, center.Y)
	self.AimLine.Size = UDim2.fromOffset(length, 4)
	self.AimLine.Rotation = math.deg(math.atan2(visual.Y, visual.X))
	self.ReceiverRing.Visible = visual.Magnitude > 18
	self.ReceiverRing.Position = UDim2.fromOffset(center.X + unit.X * math.min(110, visual.Magnitude), center.Y + unit.Y * math.min(110, visual.Magnitude))
end

function Controls:_clearAim()
	self.TouchAimVector = nil
	self.TouchAimKind = nil
	self.AimLine.Visible = false
	self.ReceiverRing.Visible = false
	self.PowerArc.Visible = false
end

function Controls:_bindAction(button: TextButton, kind: string, tapWindow: number, showPowerArc: boolean)
	local touch = nil
	local beganAt = 0
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		touch = input
		beganAt = os.clock()
		setPressed(button, true)
		if kind == "Lob" then
			self.Controller.TouchPassMode = "Lofted"
			self.Controller:_chargeStart("Pass")
		else
			self.Controller:_chargeStart(kind)
		end
		if showPowerArc then
			self.PowerArc.Visible = true
		end
	end)
	UserInputService.TouchMoved:Connect(function(input)
		if input ~= touch then return end
		self:_setAim(button, input.Position, kind)
	end)
	UserInputService.TouchEnded:Connect(function(input)
		if input ~= touch then return end
		local heldFor = os.clock() - beganAt
		if kind == "Lob" then
			self.Controller.TouchPassMode = "Lofted"
			self.Controller:_chargeEnd("Pass")
		else
			self.Controller:_chargeEnd(kind)
		end
		if heldFor <= tapWindow then
			if kind == "Shot" then
				self.Controller.TouchQuickShot = true
			end
		end
		self:_clearAim()
		setPressed(button, false)
		touch = nil
	end)
end

function Controls:MoveVector(): Vector2
	return self.TouchMoveVector
end

function Controls:Destroy()
	if self.Gui then self.Gui:Destroy() end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return Controls
''', encoding="utf-8", newline="\n")

input_path = Path("src/client/Gameplay/InputController.lua")
if input_path.exists():
    text = input_path.read_text(encoding="utf-8", errors="ignore")

    if 'VoltraLiteMobileControls' not in text:
        text = replace_once(
            text,
            'local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)',
            'local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)\nlocal VoltraLiteMobileControls = require(script:FindFirstAncestor("VTRClient").Components.VoltraLiteMobileControls)',
            "input require mobile controls"
        )

    if 'self.MobileControls = VoltraLiteMobileControls.new(self)' not in text:
        text = insert_after_signature(
            text,
            'function Controller:Start()',
            '\n\tif UserInputService.TouchEnabled then\n\t\tself.MobileControls = VoltraLiteMobileControls.new(self)\n\tend',
            "input start mobile controls"
        )

    text = re.sub(
        r'function Controller:Move\(\): Vector2\s*.*?end',
        '''function Controller:Move(): Vector2
\tlocal keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
\tif keyboard.Magnitude > 1 then
\t\tkeyboard = keyboard.Unit
\tend
\tlocal mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
\treturn keyboard.Magnitude > 0.05 and keyboard or mobile
end''',
        text,
        count=1,
        flags=re.S
    )

    if 'self.TouchAimVector' not in text:
        text = insert_after_signature(
            text,
            'function Controller:_aim(kind)',
            '''\n\tif self.TouchAimVector and self.TouchAimVector.Magnitude > 0.12 then
\t\tlocal camera = workspace.CurrentCamera
\t\tif camera then
\t\t\tlocal look = camera.CFrame.LookVector
\t\t\tlocal right = camera.CFrame.RightVector
\t\t\tlocal planarLook = Vector3.new(look.X, 0, look.Z)
\t\t\tlocal planarRight = Vector3.new(right.X, 0, right.Z)
\t\t\tif planarLook.Magnitude < 0.01 then planarLook = Vector3.new(0, 0, -1) end
\t\t\tif planarRight.Magnitude < 0.01 then planarRight = Vector3.new(1, 0, 0) end
\t\t\tplanarLook = planarLook.Unit
\t\t\tplanarRight = planarRight.Unit
\t\t\tlocal dir = planarRight * self.TouchAimVector.X + planarLook * self.TouchAimVector.Y
\t\t\tif dir.Magnitude > 0.01 then
\t\t\t\tdir = dir.Unit
\t\t\t\treturn {Direction = dir, Position = dir * 60, TargetModel = nil}
\t\t\tend
\t\tend
\tend''',
            "input touch aim override"
        )

    if 'if self.MobileControls then self.MobileControls:Destroy();self.MobileControls=nil end' not in text:
        text = replace_once(
            text,
            '''function Controller:Destroy()
\tfor _, connection in self.Connections do
\t\tconnection:Disconnect()
\tend
\ttable.clear(self.Connections)
end''',
            '''function Controller:Destroy()
\tif self.MobileControls then self.MobileControls:Destroy();self.MobileControls=nil end
\tfor _, connection in self.Connections do
\t\tconnection:Disconnect()
\tend
\ttable.clear(self.Connections)
end''',
            "input destroy mobile controls"
        )

    input_path.write_text(text, encoding="utf-8", newline="\n")
    print("patched", input_path)

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
if gameplay_path.exists():
    text = gameplay_path.read_text(encoding="utf-8", errors="ignore")

    if 'VoltraControlledPlayerIndicator' not in text:
        text = replace_once(
            text,
            'local RankedQueuePresentation=require(script.Parent.Parent.Components.RankedQueuePresentation)',
            'local RankedQueuePresentation=require(script.Parent.Parent.Components.RankedQueuePresentation)\nlocal VoltraControlledPlayerIndicator=require(script.Parent.Parent.Components.VoltraControlledPlayerIndicator)',
            "gameplay require indicator"
        )

    if 'self.ControlledIndicator=VoltraControlledPlayerIndicator.new' not in text:
        text = replace_once(
            text,
            'self.HUD:SetPauseButtonCallback(function()self:_setPaused(true)end)',
            'self.HUD:SetPauseButtonCallback(function()self:_setPaused(true)end)\n\tif not self.ControlledIndicator then self.ControlledIndicator=VoltraControlledPlayerIndicator.new(function() return self.ActiveModel end) end',
            "gameplay init indicator"
        )

    if 'if self.ControlledIndicator then self.ControlledIndicator:Destroy();self.ControlledIndicator=nil end' not in text:
        text = insert_after_signature(
            text,
            'function Controller:_cleanup(full)',
            '\n\tif self.ControlledIndicator then self.ControlledIndicator:Destroy();self.ControlledIndicator=nil end',
            "gameplay cleanup indicator"
        )

    gameplay_path.write_text(text, encoding="utf-8", newline="\n")
    print("patched", gameplay_path)

print("voltra manual indicator and mobile controls patch applied")