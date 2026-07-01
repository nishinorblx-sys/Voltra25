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

scale_path = Path("src/client/Services/DeviceScaleService.lua")
scale_path.parent.mkdir(parents=True, exist_ok=True)
scale_path.write_text('''--!strict
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Service = {}
local BASE = Vector2.new(1920, 1080)

function Service.GetScale(): number
\tlocal camera = Workspace.CurrentCamera
\tlocal viewport = camera and camera.ViewportSize or BASE
\tlocal topLeft = GuiService:GetGuiInset()
\tlocal usable = Vector2.new(math.max(1, viewport.X), math.max(1, viewport.Y - topLeft.Y))
\tlocal scale = math.min(usable.X / BASE.X, usable.Y / BASE.Y)
\treturn math.clamp(scale, 0.42, 1)
end

function Service.Apply(root: Instance, name: string?): UIScale
\tlocal scaleName = name or "VTRDeviceScale"
\tlocal scale = root:FindFirstChild(scaleName)
\tif not scale or not scale:IsA("UIScale") then
\t\tscale = Instance.new("UIScale")
\t\tscale.Name = scaleName
\t\tscale.Parent = root
\tend
\tscale.Scale = Service.GetScale()
\tlocal camera = Workspace.CurrentCamera
\tif camera and root:GetAttribute("VTRDeviceScaleBound") ~= true then
\t\troot:SetAttribute("VTRDeviceScaleBound", true)
\t\tcamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
\t\t\tif scale.Parent then
\t\t\t\tscale.Scale = Service.GetScale()
\t\t\tend
\t\tend)
\tend
\treturn scale
end

return Service
''', encoding="utf-8", newline="\n")

setpiece_path = Path("src/server/Gameplay/SetPieceService.lua")
setpiece = setpiece_path.read_text(encoding="utf-8")
setpiece = setpiece.replace(
    'setPieceCutscene=(Vector3.new(goalPosition.X-location.X,0,goalPosition.Z-location.Z)).Magnitude<=170',
    'setPieceCutscene=(Vector3.new(goalPosition.X-location.X,0,goalPosition.Z-location.Z)).Magnitude<=190'
)
setpiece_path.write_text(setpiece, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

direct_block = '''\tif mode=="DirectShotFreeKick" then
\t\tlocal goalPosition=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,goalSign*session.World.Length*.5))
\t\tlocal freeKickDistance=Vector3.new(goalPosition.X-takerRoot.Position.X,0,goalPosition.Z-takerRoot.Position.Z).Magnitude
\t\tif freeKickDistance<=190 then
\t\t\tlocal localTaker=session.World.PitchCFrame:PointToObjectSpace(takerRoot.Position)
\t\t\tlocal side=localTaker.X>=0 and -1 or 1
\t\t\tif math.random()<.5 then side=-side end
\t\t\tlocal top=math.random()<.52
\t\t\tlocal target=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(side*11,top and 6.2 or 2.45,goalSign*session.World.Length*.5))
\t\t\ttaker:SetAttribute("VTRFreeKickGoalChance",.3)
\t\t\ttaker:SetAttribute("VTRFreeKickGoalChanceUntil",os.clock()+4)
\t\t\ttaker:SetAttribute("VTRFreeKickDirectShot",true)
\t\t\ttaker:SetAttribute("VTRFreeKickShotDistance",freeKickDistance)
\t\t\ttaker:SetAttribute("VTRFreeKickCurve",side*.85)
\t\t\ttaker:SetAttribute("VTRFreeKickLift",top and .75 or -.15)
\t\t\tif self._setPieceRunup then self:_setPieceRunup(session,taker,"Shot")end
\t\t\treleased=session.BallService:Kick(taker,"Shot",target-takerRoot.Position,.72,nil,nil,nil,target)
\t\t\tif not released then
\t\t\t\tif session.BallService and session.BallService.Last then session.BallService.Last[taker]={}end
\t\t\t\treleased=session.BallService:Kick(taker,"Shot",target-takerRoot.Position,.72,nil,nil,nil,target)
\t\t\tend
\t\t\tif setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
\t\t\tsession.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=false})
\t\t\treturn
\t\tend
\tend
'''

if "VTRFreeKickDirectShot" not in runtime:
    runtime = replace_once(
        runtime,
        '''\tlocal released=false
\tlocal team=tostring(taker:GetAttribute("VTRTeam")or"Home")''',
        '''\tlocal released=false
''' + direct_block + '''\tlocal team=tostring(taker:GetAttribute("VTRTeam")or"Home")''',
        "direct free kick shot block"
    )

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

if "VTRFreeKickGoalChanceUntil" not in gk:
    if "local shooterRoot = root(shooter)" in gk:
        gk = gk.replace(
            "local shooterRoot = root(shooter)",
            '''local shooterRoot = root(shooter)
\tif shooter and (tonumber(shooter:GetAttribute("VTRFreeKickGoalChanceUntil")) or 0) >= os.clock() then
\t\tlocal goalChance = math.clamp(tonumber(shooter:GetAttribute("VTRFreeKickGoalChance")) or .3, .01, .99)
\t\tif shooterRoot then
\t\t\tshooter:SetAttribute("VTRShotDistanceGoalChance", goalChance)
\t\t\tshooter:SetAttribute("VTRShotDistancePercent", math.floor(goalChance * 100 + .5))
\t\tend
\t\tkeeper:SetAttribute("VTRDistanceGoalChance", math.floor(goalChance * 100 + .5))
\t\treturn 1 - goalChance
\tend''',
            1
        )
    else:
        gk = regex_once(
            gk,
            r'(local function saveProbability\(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number\?,shooter:Model\?\):number\n)',
            r'''\1\tif shooter and (tonumber(shooter:GetAttribute("VTRFreeKickGoalChanceUntil")) or 0) >= os.clock() then
\t\tlocal goalChance = math.clamp(tonumber(shooter:GetAttribute("VTRFreeKickGoalChance")) or .3, .01, .99)
\t\tkeeper:SetAttribute("VTRDistanceGoalChance", math.floor(goalChance * 100 + .5))
\t\treturn 1 - goalChance
\tend
''',
            "free kick goalkeeper chance"
        )

gk_path.write_text(gk, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

if "VTRFreeKickGoalChanceUntil" not in ball:
    ball = regex_once(
        ball,
        r'(local shotChance\s*=\s*[^\n]+\n)',
        r'''\1\t\tif (tonumber(model:GetAttribute("VTRFreeKickGoalChanceUntil")) or 0) >= os.clock() then
\t\t\tshotChance = math.clamp(tonumber(model:GetAttribute("VTRFreeKickGoalChance")) or .3, .01, .99)
\t\tend
''',
        "free kick shot popup chance"
    )

ball_path.write_text(ball, encoding="utf-8", newline="\n")

for path in Path("src/client").rglob("*.lua"):
    if path == scale_path:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    if 'Instance.new("ScreenGui")' not in text:
        continue
    original = text
    if "DeviceScaleService" not in text:
        lines = text.splitlines()
        insert_at = 1 if lines and lines[0].strip() == "--!strict" else 0
        lines.insert(insert_at, 'local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)')
        text = "\n".join(lines) + "\n"
    names = re.findall(r'local\s+(\w+)\s*=\s*Instance\.new\("ScreenGui"\)', text)
    for name in names:
        if f"DeviceScaleService.Apply({name}" in text:
            continue
        text, count = re.subn(
            rf'({name}\.Parent\s*=\s*Players\.LocalPlayer\.PlayerGui)',
            rf'\1\n\tDeviceScaleService.Apply({name})',
            text,
            count=1
        )
        if count == 0:
            text, count = re.subn(
                rf'({name}\.Parent\s*=\s*game:GetService\("Players"\)\.LocalPlayer\.PlayerGui)',
                rf'\1\n\tDeviceScaleService.Apply({name})',
                text,
                count=1
            )
    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print("scaled", path)

print("patched AI direct free kicks and device UI scaling")