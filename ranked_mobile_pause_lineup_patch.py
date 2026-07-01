from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

def regex_once(text, pattern, new, label):
    next_text, count = re.subn(pattern, new, text, count=1, flags=re.S)
    if count == 0:
        print("skipped", label)
        return text
    return next_text

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = runtime.replace(
    'Message="No pause time available until the next 15-minute window."',
    'Message="No pause time available until the next 30-minute window."'
)

runtime = runtime.replace(
    'local grantIndex=math.floor((session.Clock:Payload().GameSeconds or 0)/900)',
    'local grantIndex=math.floor((session.Clock:Payload().GameSeconds or 0)/1800)'
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

input_path = Path("src/client/Gameplay/InputController.lua")
inp = input_path.read_text(encoding="utf-8")

if "local Players = game:GetService(\"Players\")" not in inp:
    inp = inp.replace(
        'local UserInputService = game:GetService("UserInputService")',
        'local UserInputService = game:GetService("UserInputService")\nlocal Players = game:GetService("Players")',
        1
    )

if "DeviceScaleService" not in inp:
    inp = inp.replace(
        'local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)',
        'local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)\nlocal DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)',
        1
    )

mobile_function = '''function Controller:_createMobileControls()
\tif self.TouchGui or not UserInputService.TouchEnabled then return end
\tlocal gui = Instance.new("ScreenGui")
\tgui.Name = "VTRMobileMatchControls"
\tgui.IgnoreGuiInset = true
\tgui.ResetOnSpawn = false
\tgui.DisplayOrder = 130
\tgui.Parent = Players.LocalPlayer.PlayerGui
\tDeviceScaleService.Apply(gui)
\tself.TouchGui = gui
\tself.TouchVector = Vector2.zero
\tlocal base = Instance.new("Frame")
\tbase.Name = "MoveStick"
\tbase.AnchorPoint = Vector2.new(0, 1)
\tbase.Position = UDim2.new(0, 34, 1, -42)
\tbase.Size = UDim2.fromOffset(142, 142)
\tbase.BackgroundColor3 = Color3.fromHex("070A06")
\tbase.BackgroundTransparency = .34
\tbase.BorderSizePixel = 0
\tbase.ZIndex = 130
\tbase.Parent = gui
\tlocal baseCorner = Instance.new("UICorner")
\tbaseCorner.CornerRadius = UDim.new(1, 0)
\tbaseCorner.Parent = base
\tlocal baseStroke = Instance.new("UIStroke")
\tbaseStroke.Color = Color3.fromHex("B7FF1A")
\tbaseStroke.Transparency = .42
\tbaseStroke.Thickness = 2
\tbaseStroke.Parent = base
\tlocal knob = Instance.new("Frame")
\tknob.Name = "Knob"
\tknob.AnchorPoint = Vector2.new(.5, .5)
\tknob.Position = UDim2.fromScale(.5, .5)
\tknob.Size = UDim2.fromOffset(48, 48)
\tknob.BackgroundColor3 = Color3.fromHex("B7FF1A")
\tknob.BackgroundTransparency = .08
\tknob.BorderSizePixel = 0
\tknob.ZIndex = 131
\tknob.Parent = base
\tlocal knobCorner = Instance.new("UICorner")
\tknobCorner.CornerRadius = UDim.new(1, 0)
\tknobCorner.Parent = knob
\tlocal touchInput = nil
\tlocal function updateStick(input)
\t\tlocal center = Vector2.new(base.AbsolutePosition.X + base.AbsoluteSize.X * .5, base.AbsolutePosition.Y + base.AbsoluteSize.Y * .5)
\t\tlocal point = Vector2.new(input.Position.X, input.Position.Y)
\t\tlocal delta = point - center
\t\tlocal radius = base.AbsoluteSize.X * .42
\t\tif delta.Magnitude > radius then delta = delta.Unit * radius end
\t\tself.TouchVector = radius > 0 and Vector2.new(delta.X / radius, -delta.Y / radius) or Vector2.zero
\t\tknob.Position = UDim2.new(.5, delta.X, .5, delta.Y)
\tend
\tlocal function stopStick()
\t\ttouchInput = nil
\t\tself.TouchVector = Vector2.zero
\t\tknob.Position = UDim2.fromScale(.5, .5)
\tend
\ttable.insert(self.Connections, base.InputBegan:Connect(function(input)
\t\tif input.UserInputType == Enum.UserInputType.Touch then
\t\t\ttouchInput = input
\t\t\tupdateStick(input)
\t\tend
\tend))
\ttable.insert(self.Connections, UserInputService.TouchMoved:Connect(function(input)
\t\tif input == touchInput then updateStick(input) end
\tend))
\ttable.insert(self.Connections, UserInputService.TouchEnded:Connect(function(input)
\t\tif input == touchInput then stopStick() end
\tend))
\tlocal function makeButton(name, text, position, size, callback)
\t\tlocal button = Instance.new("TextButton")
\t\tbutton.Name = name
\t\tbutton.AnchorPoint = Vector2.new(.5, .5)
\t\tbutton.Position = position
\t\tbutton.Size = size
\t\tbutton.BackgroundColor3 = Color3.fromHex("071009")
\t\tbutton.BackgroundTransparency = .12
\t\tbutton.BorderSizePixel = 0
\t\tbutton.Text = text
\t\tbutton.TextColor3 = Color3.fromHex("F5F7F2")
\t\tbutton.TextSize = 12
\t\tbutton.Font = Enum.Font.GothamBlack
\t\tbutton.AutoButtonColor = true
\t\tbutton.ZIndex = 132
\t\tbutton.Parent = gui
\t\tlocal c = Instance.new("UICorner")
\t\tc.CornerRadius = UDim.new(1, 0)
\t\tc.Parent = button
\t\tlocal s = Instance.new("UIStroke")
\t\ts.Color = Color3.fromHex("B7FF1A")
\t\ts.Transparency = .35
\t\ts.Thickness = 1
\t\ts.Parent = button
\t\tbutton.Activated:Connect(function()
\t\t\tif not self.Suppressed then callback(button) end
\t\tend)
\t\treturn button
\tend
\tmakeButton("ShotButton", "SHOOT", UDim2.new(1, -88, 1, -154), UDim2.fromOffset(82, 82), function()
\t\tself:_chargeStart("Shot")
\t\ttask.delay(.16, function()
\t\t\tif self.Charge and self.Charge.Kind == "Shot" then self:_chargeEnd("Shot") end
\t\tend)
\tend)
\tmakeButton("PassButton", "PASS", UDim2.new(1, -174, 1, -90), UDim2.fromOffset(76, 76), function()
\t\tself:_chargeStart("Pass")
\t\ttask.delay(.13, function()
\t\t\tif self.Charge and self.Charge.Kind == "Pass" then self:_chargeEnd("Pass") end
\t\tend)
\tend)
\tmakeButton("TackleButton", "TACKLE", UDim2.new(1, -82, 1, -62), UDim2.fromOffset(70, 70), function()
\t\tself.Remote:FireServer({Type = "Tackle"})
\tend)
\tmakeButton("SlideButton", "SLIDE", UDim2.new(1, -247, 1, -58), UDim2.fromOffset(62, 62), function()
\t\tself.Remote:FireServer({Type = "SlideTackle"})
\tend)
\tmakeButton("SkillButton", "SKILL", UDim2.new(1, -258, 1, -132), UDim2.fromOffset(58, 58), function()
\t\tlocal aim = self:_aim("Skill")
\t\tself.Remote:FireServer({Type = "DribbleMove", Direction = aim.Direction})
\tend)
\tmakeButton("SwitchButton", "SWITCH", UDim2.new(1, -326, 1, -66), UDim2.fromOffset(58, 58), function()
\t\tlocal aim = self:_aim("Switch")
\t\tself.Remote:FireServer({Type = "Switch", TargetModel = aim.TargetModel, AimPosition = aim.Position})
\tend)
\tlocal sprinting = false
\tmakeButton("SprintButton", "SPRINT", UDim2.new(0, 230, 1, -72), UDim2.fromOffset(82, 50), function(button)
\t\tsprinting = not sprinting
\t\tself.Keys[Enum.KeyCode.LeftShift] = sprinting or nil
\t\tbutton.Text = sprinting and "SPRINT ON" or "SPRINT"
\tend)
\tmakeButton("BlockButton", "BLOCK", UDim2.new(0, 326, 1, -72), UDim2.fromOffset(78, 50), function()
\t\tself.Remote:FireServer({Type = "Block", Active = true})
\t\ttask.delay(.45, function()
\t\t\tself.Remote:FireServer({Type = "Block", Active = false})
\t\tend)
\tend)
end

'''

if "function Controller:_createMobileControls()" not in inp:
    inp = inp.replace("function Controller:Start()", mobile_function + "function Controller:Start()", 1)

inp = replace_once(
    inp,
    "function Controller:Start()\n\ttable.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)",
    "function Controller:Start()\n\tself:_createMobileControls()\n\ttable.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)",
    "start mobile controls"
)

inp = replace_once(
    inp,
    '''function Controller:Move(): Vector2
\tlocal keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
\tif keyboard.Magnitude > 1 then
\t\tkeyboard = keyboard.Unit
\tend
\treturn keyboard
end''',
    '''function Controller:Move(): Vector2
\tlocal keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
\tif keyboard.Magnitude > 1 then
\t\tkeyboard = keyboard.Unit
\tend
\tlocal touch = self.TouchVector or Vector2.zero
\treturn keyboard.Magnitude > 0.05 and keyboard or touch
end''',
    "mobile move vector"
)

inp = replace_once(
    inp,
    '''function Controller:Destroy()
\tfor _, connection in self.Connections do
\t\tconnection:Disconnect()
\tend
\ttable.clear(self.Connections)
end''',
    '''function Controller:Destroy()
\tif self.TouchGui then self.TouchGui:Destroy();self.TouchGui=nil end
\tfor _, connection in self.Connections do
\t\tconnection:Disconnect()
\tend
\ttable.clear(self.Connections)
end''',
    "destroy mobile controls"
)

input_path.write_text(inp, encoding="utf-8", newline="\n")

hud_path = Path("src/client/Gameplay/MatchHUDController.lua")
hud = hud_path.read_text(encoding="utf-8")

if "local function applyBadgeArt" not in hud:
    hud = hud.replace(
        '''local function badgeColor(value: any, fallback: Color3): Color3
\tif typeof(value) == "Color3" then return value end
\tif type(value) == "string" then
\t\tlocal clean = string.gsub(value, "#", "")
\t\tlocal ok, result = pcall(Color3.fromHex, clean)
\t\tif ok then return result end
\tend
\treturn fallback
end''',
        '''local function badgeColor(value: any, fallback: Color3): Color3
\tif typeof(value) == "Color3" then return value end
\tif type(value) == "string" then
\t\tlocal clean = string.gsub(value, "#", "")
\t\tlocal ok, result = pcall(Color3.fromHex, clean)
\t\tif ok then return result end
\tend
\treturn fallback
end

local function applyBadgeArt(container: GuiObject, primary: Color3, accent: Color3?)
\tcontainer.ClipsDescendants = true
\tif container:IsA("TextLabel") or container:IsA("TextButton") then
\t\tcontainer.Text = ""
\tend
\tfor _, child in container:GetChildren() do
\t\tif child.Name == "BadgeArt" then child:Destroy() end
\tend
\tlocal art = Instance.new("Frame")
\tart.Name = "BadgeArt"
\tart.BackgroundTransparency = 1
\tart.Size = UDim2.fromScale(1, 1)
\tart.ZIndex = container.ZIndex + 1
\tart.Parent = container
\tlocal shield = Instance.new("Frame")
\tshield.Name = "Shield"
\tshield.AnchorPoint = Vector2.new(.5, .5)
\tshield.Position = UDim2.fromScale(.5, .5)
\tshield.Size = UDim2.fromScale(.74, .82)
\tshield.BackgroundColor3 = primary
\tshield.BorderSizePixel = 0
\tshield.ZIndex = art.ZIndex + 1
\tshield.Parent = art
\tlocal shieldCorner = Instance.new("UICorner")
\tshieldCorner.CornerRadius = UDim.new(.18, 0)
\tshieldCorner.Parent = shield
\tlocal stripe = Instance.new("Frame")
\tstripe.Name = "Stripe"
\tstripe.AnchorPoint = Vector2.new(.5, .5)
\tstripe.Position = UDim2.fromScale(.5, .5)
\tstripe.Size = UDim2.fromScale(.28, 1.12)
\tstripe.Rotation = -18
\tstripe.BackgroundColor3 = accent or Color3.fromHex("F5F7F2")
\tstripe.BackgroundTransparency = .05
\tstripe.BorderSizePixel = 0
\tstripe.ZIndex = shield.ZIndex + 1
\tstripe.Parent = shield
\tlocal cap = Instance.new("Frame")
\tcap.Name = "Cap"
\tcap.Position = UDim2.fromScale(.13, .08)
\tcap.Size = UDim2.fromScale(.74, .22)
\tcap.BackgroundColor3 = Color3.fromHex("F5F7F2")
\tcap.BackgroundTransparency = .08
\tcap.BorderSizePixel = 0
\tcap.ZIndex = shield.ZIndex + 2
\tcap.Parent = shield
\tlocal point = Instance.new("Frame")
\tpoint.Name = "Point"
\tpoint.AnchorPoint = Vector2.new(.5, 1)
\tpoint.Position = UDim2.fromScale(.5, 1.06)
\tpoint.Size = UDim2.fromScale(.42, .28)
\tpoint.Rotation = 45
\tpoint.BackgroundColor3 = primary:Lerp(Color3.fromHex("050505"), .24)
\tpoint.BorderSizePixel = 0
\tpoint.ZIndex = shield.ZIndex
\tpoint.Parent = shield
\tlocal outline = Instance.new("UIStroke")
\toutline.Color = Color3.fromHex("F5F7F2")
\toutline.Transparency = .18
\toutline.Thickness = 1
\toutline.Parent = shield
end''',
        1
    )

hud = replace_once(
    hud,
    'homeBadge.TextXAlignment = Enum.TextXAlignment.Center;homeBadge.BackgroundColor3=badgeColor(data.HomeColor,Theme.Colors.Electric);homeBadge.BackgroundTransparency=0;homeBadge.TextColor3=Theme.Colors.Black',
    'homeBadge.TextXAlignment = Enum.TextXAlignment.Center;homeBadge.BackgroundColor3=badgeColor(data.HomeColor,Theme.Colors.Electric);homeBadge.BackgroundTransparency=0;homeBadge.TextColor3=Theme.Colors.Black;applyBadgeArt(homeBadge,badgeColor(data.HomeColor,Theme.Colors.Electric),Theme.Colors.White)',
    "home badge art"
)

hud = replace_once(
    hud,
    'awayBadge.TextXAlignment = Enum.TextXAlignment.Center;awayBadge.BackgroundColor3=badgeColor(data.AwayColor,Theme.Colors.Silver);awayBadge.BackgroundTransparency=0;awayBadge.TextColor3=Theme.Colors.Black',
    'awayBadge.TextXAlignment = Enum.TextXAlignment.Center;awayBadge.BackgroundColor3=badgeColor(data.AwayColor,Theme.Colors.Silver);awayBadge.BackgroundTransparency=0;awayBadge.TextColor3=Theme.Colors.Black;applyBadgeArt(awayBadge,badgeColor(data.AwayColor,Theme.Colors.Silver),Theme.Colors.Electric)',
    "away badge art"
)

hud = replace_once(
    hud,
    'activeBadge.TextXAlignment=Enum.TextXAlignment.Center;activeBadge.BackgroundColor3=badgeColor(data.HomeColor,Theme.Colors.Electric);activeBadge.BackgroundTransparency=0.08;activeBadge.TextColor3=Theme.Colors.Black;corner(activeBadge,21)',
    'activeBadge.TextXAlignment=Enum.TextXAlignment.Center;activeBadge.BackgroundColor3=badgeColor(data.HomeColor,Theme.Colors.Electric);activeBadge.BackgroundTransparency=0.08;activeBadge.TextColor3=Theme.Colors.Black;corner(activeBadge,21);applyBadgeArt(activeBadge,badgeColor(data.HomeColor,Theme.Colors.Electric),Theme.Colors.White)',
    "active badge art"
)

if "PauseQueueButton" not in hud:
    hud = replace_once(
        hud,
        '''\thelp.Visible = false
\tlocal result=setmetatable({''',
        '''\thelp.Visible = false
\tlocal pauseButton = Instance.new("TextButton")
\tpauseButton.Name = "PauseQueueButton"
\tpauseButton.AnchorPoint = Vector2.new(1, 0)
\tpauseButton.Position = UDim2.new(1, -22, 0, 58)
\tpauseButton.Size = UDim2.fromOffset(142, 36)
\tpauseButton.BackgroundColor3 = Theme.Colors.Electric
\tpauseButton.BorderSizePixel = 0
\tpauseButton.AutoButtonColor = true
\tpauseButton.Text = data.Ranked and "QUEUE PAUSE" or "PAUSE"
\tpauseButton.TextColor3 = Theme.Colors.Black
\tpauseButton.TextSize = 10
\tpauseButton.Font = Theme.Fonts.Display
\tpauseButton.ZIndex = 42
\tpauseButton.Visible = data.WatchMode ~= true
\tpauseButton.Parent = gui
\tcorner(pauseButton, 6)
\tlocal result=setmetatable({''',
        "create pause button"
    )
    hud = replace_once(
        hud,
        '''\t\tHelp = help,''',
        '''\t\tHelp = help,
\t\tPauseButton = pauseButton,''',
        "result pause button"
    )
    hud = replace_once(
        hud,
        '''\t}, Controller)
\treturn result
end''',
        '''\t}, Controller)
\tif pauseButton then
\t\tpauseButton.Activated:Connect(function()
\t\t\tif result.PauseButtonCallback then result.PauseButtonCallback() end
\t\tend)
\tend
\treturn result
end''',
        "connect pause button"
    )

hud = replace_once(
    hud,
    'function Controller:SetPauseButtonCallback(callback:()->())self.PauseButtonCallback=callback end',
    '''function Controller:SetPauseButtonCallback(callback:()->())
\tself.PauseButtonCallback=callback
\tif self.PauseButton then self.PauseButton.Visible=true end
end''',
    "pause callback method"
)

hud = replace_once(
    hud,
    '''\tlocal text=queued and(string.upper(playerName).." QUEUED A PAUSE")or(string.upper(playerName).." CANCELLED PAUSE QUEUE")''',
    '''\tlocal text=queued and(string.upper(playerName).." QUEUED A PAUSE")or(string.upper(playerName).." CANCELLED PAUSE QUEUE")
\tif self.PauseButton then
\t\tself.PauseButton.Text = queued and "CANCEL PAUSE" or "QUEUE PAUSE"
\t\tself.PauseButton.BackgroundColor3 = queued and Theme.Colors.Silver or Theme.Colors.Electric
\tend''',
    "pause button queue state"
)

formation_helper = '''local homeLine=lineups[controlledSide] or lineups.Home or{}
\t\tlocal roleCounts:any={}
\t\tfor i,entry in homeLine do
\t\t\tif i>11 then break end
\t\t\tlocal pos=string.upper(tostring(entry.Position or entry.bestPosition or""))
\t\t\tlocal band=(pos=="GK"and"GK")or((pos=="LB"or pos=="LWB")and"LEFTBACK")or((pos=="RB"or pos=="RWB")and"RIGHTBACK")or(pos=="CB"and"CB")or(pos=="CDM"and"CDM")or(pos=="CM"and"CM")or(pos=="CAM"and"CAM")or((pos=="LM"or pos=="LW")and"LEFTWIDE")or((pos=="RM"or pos=="RW")and"RIGHTWIDE")or((pos=="ST"or pos=="CF"or pos=="SS")and"ST")or"OTHER"
\t\t\troleCounts[band]=(roleCounts[band]or 0)+1
\t\tend
\t\tlocal roleSeen:any={}
\t\tlocal function spreadX(band:string,base:number):number
\t\t\troleSeen[band]=(roleSeen[band]or 0)+1
\t\t\tlocal count=roleCounts[band]or 1
\t\t\tif count<=1 then return base end
\t\t\tlocal gap=math.min(.22,.68/math.max(1,count-1))
\t\t\treturn math.clamp(base+(roleSeen[band]-(count+1)/2)*gap,.10,.90)
\t\tend
\t\tlocal function coordFor(entry:any,index:number):Vector2
\t\t\tlocal pos=string.upper(tostring(entry.Position or entry.bestPosition or""))
\t\t\tif pos=="GK"then return Vector2.new(.50,.88)end
\t\t\tif pos=="LB"or pos=="LWB"then return Vector2.new(.17,.68)end
\t\t\tif pos=="RB"or pos=="RWB"then return Vector2.new(.83,.68)end
\t\t\tif pos=="CB"then return Vector2.new(spreadX("CB",.50),.70)end
\t\t\tif pos=="CDM"then return Vector2.new(spreadX("CDM",.50),.55)end
\t\t\tif pos=="CM"then return Vector2.new(spreadX("CM",.50),.44)end
\t\t\tif pos=="CAM"then return Vector2.new(spreadX("CAM",.50),.34)end
\t\t\tif pos=="LM"or pos=="LW"then return Vector2.new(.18,pos=="LM"and.34 or.23)end
\t\t\tif pos=="RM"or pos=="RW"then return Vector2.new(.82,pos=="RM"and.34 or.23)end
\t\t\tif pos=="ST"or pos=="CF"or pos=="SS"then return Vector2.new(spreadX("ST",.50),.16)end
\t\t\treturn Vector2.new(.18+((index-1)%4)*.21,.28+math.floor((index-1)/4)*.18)
\t\tend'''

hud = re.sub(
    r'local homeLine=lineups\[controlledSide\] or lineups\.Home or\{\}\n\t\tlocal coords=\{GK=.*?\n\t\tend',
    formation_helper,
    hud,
    flags=re.S
)

hud = hud.replace('"SQUAD  /  FORMATION 4-3-3"', '"SQUAD  /  FORMATION"')
hud = hud.replace('label(pitch,"4-3-3"', 'label(pitch,"FORMATION"')

hud_path.write_text(hud, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

if "SetPauseButtonCallback(function()self:_setPaused(true)end)" not in gameplay:
    gameplay = replace_once(
        gameplay,
        '''\tself.HUD:SetManualSubstitutionCallback(function(benchIndex:number,outgoingModel:Model,outgoingName:string)''',
        '''\tself.HUD:SetPauseButtonCallback(function()self:_setPaused(true)end)
\tself.HUD:SetManualSubstitutionCallback(function(benchIndex:number,outgoingModel:Model,outgoingName:string)''',
        "hook pause button"
    )

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

print("added ranked pause queue button, mobile controls, 30 minute pause grants, formation-aware lineup dots, and shield badges")