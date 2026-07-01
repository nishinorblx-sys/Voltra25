from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

prematch_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
prematch = prematch_path.read_text(encoding="utf-8")

prematch = re.sub(
    r'local function formationEntries\(data: any, side: string\): \{any\}.*?end\n\nlocal function groupRange',
    '''local function formationRoleOrder(position: string): number
\tlocal key = roleKey(position)
\tlocal order = {
\t\tGK = 1,
\t\tLB = 2,
\t\tCB = 3,
\t\tRB = 4,
\t\tLWB = 2,
\t\tRWB = 4,
\t\tCDM = 5,
\t\tLM = 6,
\t\tCM = 7,
\t\tRM = 8,
\t\tCAM = 9,
\t\tLW = 10,
\t\tRW = 11,
\t\tST = 12,
\t}
\treturn order[key] or 20
end

local function formationGroupOrder(position: string): number
\tlocal group = lineGroupForPosition(position)
\tif group == "GK" then return 1 end
\tif group == "DEF" then return 2 end
\tif group == "MID" then return 3 end
\tif group == "ATT" then return 4 end
\treturn 5
end

local function modelNameKey(model: Model?): string
\tif not model then return "" end
\treturn string.lower(tostring(model:GetAttribute("DisplayName") or model.Name))
end

local function playerNameKey(player: any): string
\tif type(player) ~= "table" then return "" end
\treturn string.lower(tostring(player.DisplayName or player.Name or player.name or player.playerName or ""))
end

local function formationEntries(data: any, side: string): {any}
\tlocal models = sortedModels(data, side)
\tlocal players = side == "Home" and (data.HomeLineup or {}) or (data.AwayLineup or {})
\tlocal usedModels: {[Model]: boolean} = {}
\tlocal result = {}
\tfor index = 1, 11 do
\t\tlocal player = players[index]
\t\tlocal position = positionFromEntry(player)
\t\tlocal matched: Model? = nil
\t\tlocal playerKey = playerNameKey(player)
\t\tif playerKey ~= "" then
\t\t\tfor _, model in models do
\t\t\t\tif not usedModels[model] and modelNameKey(model) == playerKey then
\t\t\t\t\tmatched = model
\t\t\t\t\tbreak
\t\t\t\tend
\t\t\tend
\t\tend
\t\tif not matched then
\t\t\tmatched = models[index]
\t\tend
\t\tif matched then
\t\t\tusedModels[matched] = true
\t\tend
\t\tif position == "" then position = positionFromModel(matched) end
\t\tif position == "" then
\t\t\tlocal fallback = {"GK", "LB", "CB", "CB", "RB", "CDM", "CDM", "CAM", "LM", "RM", "ST"}
\t\t\tposition = fallback[index] or "CM"
\t\tend
\t\ttable.insert(result, {Model = matched, Player = player, Position = position, OriginalIndex = index})
\tend
\ttable.sort(result, function(a, b)
\t\tlocal groupA = formationGroupOrder(a.Position)
\t\tlocal groupB = formationGroupOrder(b.Position)
\t\tif groupA ~= groupB then return groupA < groupB end
\t\tlocal roleA = formationRoleOrder(a.Position)
\t\tlocal roleB = formationRoleOrder(b.Position)
\t\tif roleA ~= roleB then return roleA < roleB end
\t\treturn (a.OriginalIndex or 0) < (b.OriginalIndex or 0)
\tend)
\treturn result
end

local function entriesForGroup(data: any, side: string, groupName: string): {any}
\tlocal result = {}
\tfor _, entry in formationEntries(data, side) do
\t\tif lineGroupForPosition(entry.Position) == groupName then
\t\t\ttable.insert(result, entry)
\t\tend
\tend
\treturn result
end

local function groupRange''',
    prematch,
    count=1,
    flags=re.S
)

if "local function showEntryGroupPreview" not in prematch:
    prematch = prematch.replace(
        '''function Presentation.Duration(): number''',
        '''local function showEntryGroupPreview(container: Frame, entries: {any})
\tlocal models = {}
\tlocal players = {}
\tfor _, entry in entries do
\t\ttable.insert(models, entry.Model)
\t\ttable.insert(players, entry.Player)
\tend
\tshowPlayerGroupPreview(container, models, players, 1, math.max(1, #entries))
end

function Presentation.Duration(): number''',
        1
    )

prematch = replace_once(
    prematch,
    'showPlayerGroupPreview(groupPreview, sortedModels(data, "Home"), lineupData(data, "Home"), 1, 1)',
    'showEntryGroupPreview(groupPreview, entriesForGroup(data, "Home", "GK"))',
    "initial goalkeeper group"
)

prematch = replace_once(
    prematch,
    '''\t\t\tsetLineHighlight(dots, group[6], group[4], group[5])
\t\t\tlocal list = sortedModels(data, side)
\t\t\tlocal players = lineupData(data, side)
\t\t\tlocal firstIndex, lastIndex = groupRange(data, side, group[6], group[4], group[5])
\t\t\tintroTitle.Text = group[2]
\t\t\tshowPlayerGroupPreview(groupPreview, list, players, firstIndex, lastIndex)''',
    '''\t\t\tsetLineHighlight(dots, group[6], group[4], group[5])
\t\t\tintroTitle.Text = group[2]
\t\t\tshowEntryGroupPreview(groupPreview, entriesForGroup(data, side, group[6]))''',
    "line group preview"
)

prematch_path.write_text(prematch, encoding="utf-8", newline="\n")

mobile_path = Path("src/client/Components/VoltraLiteMobileControls.lua")
mobile_path.parent.mkdir(parents=True, exist_ok=True)
mobile_path.write_text('''--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Controls = {}
Controls.__index = Controls

local GREEN = Color3.fromHex("B7FF1A")
local WHITE = Color3.fromHex("F5F7F2")
local BLACK = Color3.fromHex("061006")

local function corner(parent: Instance, radius: number)
\tlocal item = Instance.new("UICorner")
\titem.CornerRadius = UDim.new(0, radius)
\titem.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number)
\tlocal item = Instance.new("UIStroke")
\titem.Color = color
\titem.Transparency = transparency
\titem.Thickness = thickness
\titem.Parent = parent
\treturn item
end

local function circle(parent: Instance, name: string, size: number, pos: UDim2, text: string, textSize: number): TextButton
\tlocal button = Instance.new("TextButton")
\tbutton.Name = name
\tbutton.AnchorPoint = Vector2.new(0.5, 0.5)
\tbutton.Position = pos
\tbutton.Size = UDim2.fromOffset(size, size)
\tbutton.BackgroundColor3 = BLACK
\tbutton.BackgroundTransparency = 0.12
\tbutton.BorderSizePixel = 0
\tbutton.AutoButtonColor = false
\tbutton.Text = text
\tbutton.TextColor3 = WHITE
\tbutton.TextSize = textSize
\tbutton.Font = Enum.Font.GothamBlack
\tbutton.ZIndex = 210
\tbutton.Parent = parent
\tcorner(button, size)
\tstroke(button, GREEN, 0.06, 2)
\tlocal inner = Instance.new("Frame")
\tinner.Name = "GreenGlow"
\tinner.AnchorPoint = Vector2.new(0.5, 0.5)
\tinner.Position = UDim2.fromScale(0.5, 0.5)
\tinner.Size = UDim2.fromScale(0.58, 0.58)
\tinner.BackgroundColor3 = GREEN
\tinner.BackgroundTransparency = 0.78
\tinner.BorderSizePixel = 0
\tinner.ZIndex = 209
\tinner.Parent = button
\tcorner(inner, size)
\treturn button
end

local function pressed(button: TextButton, state: boolean)
\tbutton.BackgroundTransparency = state and 0.02 or 0.12
\tbutton.BackgroundColor3 = state and Color3.fromHex("173617") or BLACK
\tlocal glow = button:FindFirstChild("GreenGlow")
\tif glow and glow:IsA("Frame") then
\t\tglow.BackgroundTransparency = state and 0.32 or 0.78
\tend
\tlocal line = button:FindFirstChildOfClass("UIStroke")
\tif line then line.Thickness = state and 3 or 2 end
end

function Controls.new(controller: any)
\tlocal self = setmetatable({}, Controls)
\tself.Controller = controller
\tself.Connections = {}
\tself.MoveVector = Vector2.zero
\tself.ButtonAimVector = nil
\tself.ButtonAimKind = nil
\tself.ManualKind = nil
\tself.PassMode = nil
\tself.Gui = Instance.new("ScreenGui")
\tself.Gui.Name = "VTRLiteMobileControls"
\tself.Gui.IgnoreGuiInset = true
\tself.Gui.ResetOnSpawn = false
\tself.Gui.DisplayOrder = 170
\tself.Gui.Parent = Players.LocalPlayer.PlayerGui
\tlocal root = Instance.new("Frame")
\troot.BackgroundTransparency = 1
\troot.Size = UDim2.fromScale(1, 1)
\troot.Parent = self.Gui
\tself.Root = root
\tlocal base = Instance.new("Frame")
\tbase.Name = "MovementJoystick"
\tbase.AnchorPoint = Vector2.new(0.5, 0.5)
\tbase.Position = UDim2.new(0, 98, 1, -108)
\tbase.Size = UDim2.fromOffset(130, 130)
\tbase.BackgroundColor3 = BLACK
\tbase.BackgroundTransparency = 0.34
\tbase.BorderSizePixel = 0
\tbase.Active = true
\tbase.ZIndex = 205
\tbase.Parent = root
\tcorner(base, 130)
\tstroke(base, GREEN, 0.42, 1)
\tlocal knob = Instance.new("Frame")
\tknob.Name = "Knob"
\tknob.AnchorPoint = Vector2.new(0.5, 0.5)
\tknob.Position = UDim2.fromScale(0.5, 0.5)
\tknob.Size = UDim2.fromOffset(56, 56)
\tknob.BackgroundColor3 = GREEN
\tknob.BackgroundTransparency = 0.04
\tknob.BorderSizePixel = 0
\tknob.Active = false
\tknob.ZIndex = 207
\tknob.Parent = base
\tcorner(knob, 56)
\tstroke(knob, WHITE, 0.64, 1)
\tlocal arrows = Instance.new("TextLabel")
\tarrows.BackgroundTransparency = 1
\tarrows.Size = UDim2.fromScale(1, 1)
\tarrows.Text = "▲\\n◀     ▶\\n▼"
\tarrows.TextColor3 = GREEN
\tarrows.TextTransparency = 0.18
\tarrows.TextSize = 20
\tarrows.Font = Enum.Font.GothamBlack
\tarrows.ZIndex = 206
\tarrows.Parent = base
\tself.Joystick = base
\tself.Knob = knob
\tself.PassButton = circle(root, "PassButton", 78, UDim2.new(1, -188, 1, -104), "PASS", 16)
\tself.ShootButton = circle(root, "ShootButton", 86, UDim2.new(1, -102, 1, -184), "SHOOT", 17)
\tself.LobButton = circle(root, "LobButton", 64, UDim2.new(1, -218, 1, -190), "LOB", 15)
\tself.SprintButton = circle(root, "SprintTackleButton", 70, UDim2.new(1, -96, 1, -76), "SPRINT", 12)
\tself.SwitchButton = circle(root, "SwitchButton", 52, UDim2.new(1, -76, 1, -276), "SWITCH", 9)
\tlocal aimLine = Instance.new("Frame")
\taimLine.Name = "AimLine"
\taimLine.AnchorPoint = Vector2.new(0, 0.5)
\taimLine.BackgroundColor3 = GREEN
\taimLine.BackgroundTransparency = 0.12
\taimLine.BorderSizePixel = 0
\taimLine.Visible = false
\taimLine.ZIndex = 215
\taimLine.Parent = root
\tcorner(aimLine, 4)
\tself.AimLine = aimLine
\tlocal ring = Instance.new("Frame")
\tring.Name = "ReceiverRing"
\tring.AnchorPoint = Vector2.new(0.5, 0.5)
\tring.Size = UDim2.fromOffset(28, 28)
\tring.BackgroundTransparency = 1
\tring.Visible = false
\tring.ZIndex = 215
\tring.Parent = root
\tcorner(ring, 28)
\tstroke(ring, GREEN, 0.02, 2)
\tself.ReceiverRing = ring
\tlocal moveTouch = nil
\tlocal function updateMove(input: InputObject)
\t\tlocal center = Vector2.new(base.AbsolutePosition.X + base.AbsoluteSize.X * 0.5, base.AbsolutePosition.Y + base.AbsoluteSize.Y * 0.5)
\t\tlocal delta = Vector2.new(input.Position.X, input.Position.Y) - center
\t\tlocal radius = base.AbsoluteSize.X * 0.40
\t\tif delta.Magnitude > radius then delta = delta.Unit * radius end
\t\tself.MoveVector = radius > 0 and Vector2.new(delta.X / radius, -delta.Y / radius) or Vector2.zero
\t\tknob.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
\tend
\ttable.insert(self.Connections, base.InputBegan:Connect(function(input)
\t\tif input.UserInputType == Enum.UserInputType.Touch then
\t\t\tmoveTouch = input
\t\t\tupdateMove(input)
\t\tend
\tend))
\ttable.insert(self.Connections, UserInputService.TouchMoved:Connect(function(input)
\t\tif input == moveTouch then updateMove(input) end
\tend))
\ttable.insert(self.Connections, UserInputService.TouchEnded:Connect(function(input)
\t\tif input == moveTouch then
\t\t\tmoveTouch = nil
\t\t\tself.MoveVector = Vector2.zero
\t\t\tknob.Position = UDim2.fromScale(0.5, 0.5)
\t\tend
\tend))
\tself:_bindAction(self.PassButton, "Pass")
\tself:_bindAction(self.ShootButton, "Shot")
\tself:_bindAction(self.LobButton, "Lob")
\tself.SwitchButton.Activated:Connect(function()
\t\tlocal aim = controller:_aim("Switch")
\t\tcontroller.Remote:FireServer({Type = "Switch", TargetModel = aim.TargetModel, AimPosition = aim.Position})
\tend)
\tlocal sprintStarted = 0
\tlocal lastTap = 0
\tself.SprintButton.InputBegan:Connect(function(input)
\t\tif input.UserInputType ~= Enum.UserInputType.Touch then return end
\t\tsprintStarted = os.clock()
\t\tif sprintStarted - lastTap < 0.34 then
\t\t\tcontroller.Keys[Enum.KeyCode.LeftShift] = true
\t\t\ttask.delay(0.55, function() controller.Keys[Enum.KeyCode.LeftShift] = nil end)
\t\telse
\t\t\tcontroller.Keys[Enum.KeyCode.LeftShift] = true
\t\tend
\t\tlastTap = sprintStarted
\t\tpressed(self.SprintButton, true)
\tend)
\tself.SprintButton.InputEnded:Connect(function(input)
\t\tif input.UserInputType ~= Enum.UserInputType.Touch then return end
\t\tcontroller.Keys[Enum.KeyCode.LeftShift] = nil
\t\tpressed(self.SprintButton, false)
\t\tif os.clock() - sprintStarted < 0.28 then
\t\t\tcontroller.Remote:FireServer({Type = "Tackle"})
\t\tend
\tend)
\treturn self
end

function Controls:_drawButtonAim(button: GuiObject, pos: Vector2, kind: string)
\tlocal center = Vector2.new(button.AbsolutePosition.X + button.AbsoluteSize.X * 0.5, button.AbsolutePosition.Y + button.AbsoluteSize.Y * 0.5)
\tlocal delta = pos - center
\tif delta.Magnitude < 14 then
\t\tself.ButtonAimVector = nil
\t\tself.ButtonAimKind = nil
\t\tself.ManualKind = nil
\t\tself.AimLine.Visible = false
\t\tself.ReceiverRing.Visible = false
\t\treturn
\tend
\tlocal unit = delta.Unit
\tself.ButtonAimVector = Vector2.new(unit.X, -unit.Y)
\tself.ButtonAimKind = kind
\tself.ManualKind = kind == "Lob" and "Pass" or kind
\tlocal length = math.clamp(delta.Magnitude, 22, 140)
\tself.AimLine.Visible = true
\tself.AimLine.Position = UDim2.fromOffset(center.X, center.Y)
\tself.AimLine.Size = UDim2.fromOffset(length, 4)
\tself.AimLine.Rotation = math.deg(math.atan2(delta.Y, delta.X))
\tself.ReceiverRing.Visible = true
\tself.ReceiverRing.Position = UDim2.fromOffset(center.X + unit.X * length, center.Y + unit.Y * length)
end

function Controls:_clearButtonAim()
\tself.ButtonAimVector = nil
\tself.ButtonAimKind = nil
\tself.ManualKind = nil
\tself.AimLine.Visible = false
\tself.ReceiverRing.Visible = false
end

function Controls:_bindAction(button: TextButton, kind: string)
\tlocal touch = nil
\tbutton.InputBegan:Connect(function(input)
\t\tif input.UserInputType ~= Enum.UserInputType.Touch then return end
\t\ttouch = input
\t\tpressed(button, true)
\t\tif kind == "Lob" then
\t\t\tself.PassMode = "Lofted"
\t\t\tself.Controller:_chargeStart("Pass")
\t\telse
\t\t\tself.Controller:_chargeStart(kind)
\t\tend
\tend)
\tUserInputService.TouchMoved:Connect(function(input)
\t\tif input == touch then self:_drawButtonAim(button, Vector2.new(input.Position.X, input.Position.Y), kind) end
\tend)
\tUserInputService.TouchEnded:Connect(function(input)
\t\tif input ~= touch then return end
\t\tif kind == "Lob" then
\t\t\tself.PassMode = "Lofted"
\t\t\tself.Controller:_chargeEnd("Pass")
\t\telse
\t\t\tself.Controller:_chargeEnd(kind)
\t\tend
\t\tpressed(button, false)
\t\tself:_clearButtonAim()
\t\ttouch = nil
\tend)
end

function Controls:MoveVector(): Vector2
\treturn self.MoveVector
end

function Controls:AimVector(kind: string?): Vector2?
\tlocal actionKind = kind == "Lob" and "Pass" or kind
\tif self.ButtonAimVector and (self.ButtonAimKind == kind or self.ManualKind == actionKind) then
\t\treturn self.ButtonAimVector
\tend
\tif self.MoveVector.Magnitude > 0.12 then
\t\treturn self.MoveVector.Unit
\tend
\treturn nil
end

function Controls:IsManualAim(kind: string?): boolean
\treturn self.ManualKind == kind
end

function Controls:ConsumePassMode(): string?
\tlocal mode = self.PassMode
\tself.PassMode = nil
\treturn mode
end

function Controls:Destroy()
\tif self.Gui then self.Gui:Destroy() end
\tfor _, connection in self.Connections do connection:Disconnect() end
\ttable.clear(self.Connections)
end

return Controls
''', encoding="utf-8", newline="\n")

input_path = Path("src/client/Gameplay/InputController.lua")
input_text = input_path.read_text(encoding="utf-8")

start = input_text.find("\nfunction Controller:_createMobileControls()")
finish = input_text.find("\nfunction Controller:Start()", start)
if start != -1 and finish != -1:
    input_text = input_text[:start] + "\n" + input_text[finish:]

input_text = input_text.replace("\n\tself:_createMobileControls()", "")

if "VoltraLiteMobileControls" not in input_text:
    input_text = replace_once(
        input_text,
        'local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)',
        'local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)\nlocal VoltraLiteMobileControls = require(script:FindFirstAncestor("VTRClient").Components.VoltraLiteMobileControls)',
        "mobile require"
    )

input_text = replace_once(
    input_text,
    '''function Controller:Start()
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)''',
    '''function Controller:Start()
	if UserInputService.TouchEnabled and not self.MobileControls then
		self.MobileControls = VoltraLiteMobileControls.new(self)
	end
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)''',
    "start mobile controls"
)

input_text = re.sub(
    r'function Controller:Move\(\): Vector2.*?end\n',
    '''function Controller:Move(): Vector2
\tlocal keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
\tif keyboard.Magnitude > 1 then
\t\tkeyboard = keyboard.Unit
\tend
\tlocal mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
\treturn keyboard.Magnitude > 0.05 and keyboard or mobile
end

''',
    input_text,
    count=1,
    flags=re.S
)

if "function Controller:MobileAimVector" not in input_text:
    input_text = input_text.replace(
        "function Controller:Sprinting(): boolean",
        '''function Controller:MobileAimVector(kind: string?): Vector2?
\treturn self.MobileControls and self.MobileControls:AimVector(kind) or nil
end

function Controller:MobileManualAim(kind: string?): boolean
\treturn self.MobileControls and self.MobileControls:IsManualAim(kind) or false
end

function Controller:MobilePassMode(): string?
\treturn self.MobileControls and self.MobileControls:ConsumePassMode() or nil
end

function Controller:Sprinting(): boolean''',
        1
    )

input_text = re.sub(
    r'\t\tlocal altDown = self\.Keys\[Enum\.KeyCode\.LeftAlt\] == true or self\.Keys\[Enum\.KeyCode\.RightAlt\] == true.*?\t\tself\.Remote:FireServer\(\{Type = "Pass".*?\}\)',
    '''\t\tlocal altDown = self.Keys[Enum.KeyCode.LeftAlt] == true or self.Keys[Enum.KeyCode.RightAlt] == true
\t\tlocal ctrlDown = self.Keys[Enum.KeyCode.LeftControl] == true or self.Keys[Enum.KeyCode.RightControl] == true
\t\tlocal manualLobbed = altDown and ctrlDown
\t\tlocal manual = ctrlDown and not manualLobbed
\t\tlocal lofted = altDown and not ctrlDown
\t\tlocal through=not manualLobbed and not manual and not lofted and self.Keys[Enum.KeyCode.W] == true and charge >= 0.18
\t\tlocal mobileMode = self:MobilePassMode()
\t\tlocal passType=mobileMode or manualLobbed and"ManualLobbed"or manual and"Manual"or lofted and"Lofted"or through and"Through"or"Ground"
\t\tlocal isManual = manual or manualLobbed or self:MobileManualAim("Pass")
\t\tself.Remote:FireServer({Type = "Pass", Direction = aim.Direction, AimPosition = aim.Position, TargetModel = isManual and nil or aim.TargetModel, Charge = charge, PassType = passType, AutoSwitch = isManual and"Off"or self.AutoSwitch, ReceiverAssist = isManual and"Off"or self.ReceiverAssist})''',
    input_text,
    count=1,
    flags=re.S
)

input_text = replace_once(
    input_text,
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
    "destroy mobile"
)

input_path.write_text(input_text, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

if "function Controller:_mobileAimPayload" not in gameplay:
    gameplay = gameplay.replace(
        '''function Controller:_reticleSwitchTarget(point:Vector3?):Model?
\tif not point or not self.ActiveModel or not self.TeamModels then return nil end
\tlocal side=tostring(self.ActiveModel:GetAttribute("VTRTeam")or"Home");local best:Model?=nil;local bestDistance=12
\tfor _,teammate in self.TeamModels[side]or{}do if teammate~=self.ActiveModel then local teammateRoot=teammate:FindFirstChild("HumanoidRootPart")::BasePart?;if teammateRoot then local distance=Vector3.new(teammateRoot.Position.X-point.X,0,teammateRoot.Position.Z-point.Z).Magnitude;if distance<bestDistance then best=teammate;bestDistance=distance end end end end
\treturn best
end''',
        '''function Controller:_reticleSwitchTarget(point:Vector3?):Model?
\tif not point or not self.ActiveModel or not self.TeamModels then return nil end
\tlocal side=tostring(self.ActiveModel:GetAttribute("VTRTeam")or"Home");local best:Model?=nil;local bestDistance=12
\tfor _,teammate in self.TeamModels[side]or{}do if teammate~=self.ActiveModel then local teammateRoot=teammate:FindFirstChild("HumanoidRootPart")::BasePart?;if teammateRoot then local distance=Vector3.new(teammateRoot.Position.X-point.X,0,teammateRoot.Position.Z-point.Z).Magnitude;if distance<bestDistance then best=teammate;bestDistance=distance end end end end
\treturn best
end

function Controller:_mobileAimPayload(kind:string?,charge:number?,root:BasePart):any?
\tif not self.Input or not self.Input.MobileAimVector then return nil end
\tlocal vector=self.Input:MobileAimVector(kind)
\tif not vector or vector.Magnitude<=0.08 then return nil end
\tlocal camera=workspace.CurrentCamera
\tif not camera then return nil end
\tlocal look=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
\tlocal right=Vector3.new(camera.CFrame.RightVector.X,0,camera.CFrame.RightVector.Z)
\tif look.Magnitude<0.01 then look=Vector3.new(0,0,-1)end
\tif right.Magnitude<0.01 then right=Vector3.new(1,0,0)end
\tlook=look.Unit;right=right.Unit
\tlocal direction=right*vector.X+look*vector.Y
\tif direction.Magnitude<0.01 then return nil end
\tdirection=direction.Unit
\tlocal amount=math.clamp(charge or 0,0,1)
\tlocal distance=20+amount*92
\tif kind=="Shot"then distance=92+amount*90 end
\tlocal position=root.Position+direction*distance
\tlocal goalTarget=false
\tif kind=="Shot"then
\t\tlocal pitch=self.Camera and self.Camera.PitchCFrame
\t\tlocal width=self.Camera and self.Camera.Width or 424
\t\tlocal length=self.Camera and self.Camera.Length or 742
\t\tif pitch then
\t\t\tlocal goalA=pitch:PointToWorldSpace(Vector3.new(0,3,-length*.5))
\t\t\tlocal goalB=pitch:PointToWorldSpace(Vector3.new(0,3,length*.5))
\t\t\tlocal toA=Vector3.new(goalA.X-root.Position.X,0,goalA.Z-root.Position.Z)
\t\t\tlocal toB=Vector3.new(goalB.X-root.Position.X,0,goalB.Z-root.Position.Z)
\t\t\tlocal dotA=toA.Magnitude>1 and direction:Dot(toA.Unit)or-1
\t\t\tlocal dotB=toB.Magnitude>1 and direction:Dot(toB.Unit)or-1
\t\t\tlocal chosen=dotA>dotB and goalA or goalB
\t\t\tlocal chosenDot=math.max(dotA,dotB)
\t\t\tlocal chosenDistance=Vector3.new(chosen.X-root.Position.X,0,chosen.Z-root.Position.Z).Magnitude
\t\t\tif chosenDot>.42 and chosenDistance<=170 then
\t\t\t\tlocal localGoal=pitch:PointToObjectSpace(chosen)
\t\t\t\tlocal side=direction:Dot(pitch.RightVector)>=0 and 1 or -1
\t\t\t\tlocal high=((math.floor(os.clock()*10)+math.floor(root.Position.X))%2)==0
\t\t\t\tposition=pitch:PointToWorldSpace(Vector3.new(side*11,high and 6.2 or 2.45,localGoal.Z))
\t\t\t\tgoalTarget=true
\t\t\telse
\t\t\t\tposition=root.Position+direction*(90+amount*80)
\t\t\t\tgoalTarget=false
\t\t\tend
\t\tend
\tend
\treturn{Direction=direction,Position=position,GoalTarget=goalTarget,TargetModel=kind=="Pass"and self:_reticleSwitchTarget(position)or nil}
end''',
        1
    )

gameplay = re.sub(
    r'function Controller:_aimPayload\(kind:string\?,shotCharge:number\?\):any.*?end\nfunction Controller:_playPrematchSkipTransition',
    '''function Controller:_aimPayload(kind:string?,shotCharge:number?):any
\tlocal root=self.ActiveModel and self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?
\tif root then
\t\tlocal mobile=self:_mobileAimPayload(kind or "",shotCharge or 0,root)
\t\tif mobile then
\t\t\tif mobile.GoalTarget and mobile.Position and self.GoalTarget then self.GoalTarget:Lock(mobile.Position)end
\t\t\treturn mobile
\t\tend
\tend
\tlocal position=self.MouseAim:GetAimWorldPosition();local switchTarget=kind=="Switch"and self:_reticleSwitchTarget(position)or nil
\tif not root then return{Direction=self.Camera:Aim(kind),Position=position,GoalTarget=false,TargetModel=switchTarget or(kind=="Pass"and self.LockedPassTarget or nil)}end
\tlocal goalTarget=kind=="Shot"and self.MouseAim:IsAimingAtGoal();position=goalTarget and self.MouseAim:GetGoalAimPoint(shotCharge or 0)or position
\tlocal penaltySlot=nil
\tif kind=="Shot" and (self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense") then
\t\tlocal goalSign=tonumber(self.Ball:GetAttribute("VTRPenaltyGoalSign"))or(self.ControlledSide=="Home"and-1 or 1)
\t\tif position then penaltySlot=PenaltyConfig.SlotFromGoalPoint(self.Camera.PitchCFrame,self.Camera.Length,goalSign,position,self.Camera.Width);position=PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,penaltySlot,self.Camera.Width);goalTarget=true end
\tend
\tif goalTarget and position and self.GoalTarget then self.GoalTarget:Lock(position)end;local offset=position and(position-root.Position)or Vector3.zero;local direction=offset.Magnitude>.01 and offset.Unit or self.MouseAim:GetAimDirectionFromPlayer(root.Position);local freeKickCurve,freeKickLift=0,0;if kind=="Shot"and self.SetPieceMode=="DirectShotFreeKick"and self.Input and self.Input.FreeKickModifiers then freeKickCurve,freeKickLift=self.Input:FreeKickModifiers()end;return{Direction=direction,Position=position,GoalTarget=goalTarget,TargetModel=switchTarget or(kind=="Pass"and self.LockedPassTarget or nil),FreeKickCurve=freeKickCurve,FreeKickLift=freeKickLift,PenaltySlot=penaltySlot}
end
function Controller:_playPrematchSkipTransition''',
    gameplay,
    count=1,
    flags=re.S
)

gameplay = gameplay.replace(
    '''local aimingAtGoal=self.MouseAim:IsAimingAtGoal();local goalPoint=self.MouseAim:GetGoalAimPoint(chargeKind=="Shot"and charge or 0);local aimPosition=aimingAtGoal and goalPoint or self.MouseAim:GetAimWorldPosition();''',
    '''local aimingAtGoal=self.MouseAim:IsAimingAtGoal();local goalPoint=self.MouseAim:GetGoalAimPoint(chargeKind=="Shot"and charge or 0);local aimPosition=aimingAtGoal and goalPoint or self.MouseAim:GetAimWorldPosition();local mobilePreview=root and self:_mobileAimPayload(chargeKind~=""and chargeKind or"Pass",charge,root)or nil;if mobilePreview then aimPosition=mobilePreview.Position;aimingAtGoal=mobilePreview.GoalTarget end;''',
    1
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

print("fixed prematch formation groups, mobile controls, joystick reticle aim, and mobile shot targeting")