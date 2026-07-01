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

path = Path("src/server/Gameplay/GoalkeeperService.lua")
text = path.read_text(encoding="utf-8")

text = replace_once(text, "local DIVE_LEAD_TIME = 1.35", "local DIVE_LEAD_TIME = 0.72", "dive lead time")
text = replace_once(text, "local MAX_DIVE_SPEED = 46", "local MAX_DIVE_SPEED = 58", "dive speed")
text = replace_once(text, "local CATCH_RADIUS = 3.25", "local CATCH_RADIUS = 3.55", "catch radius")

helper = '''local function diveCatchFrame(position:Vector3,lookVector:Vector3,upAxis:Vector3,fallbackForward:Vector3):CFrame
\tlocal look=lookVector.Magnitude>.05 and lookVector.Unit or fallbackForward
\tlocal right=look:Cross(upAxis)
\tif right.Magnitude<.05 then
\t\tright=Vector3.new(look.Z,0,-look.X)
\tend
\tright=right.Magnitude>.05 and right.Unit or Vector3.xAxis
\tlocal up=right:Cross(look)
\tup=up.Magnitude>.05 and up.Unit or upAxis
\treturn CFrame.fromMatrix(position,right,up,-look)
end

'''

if "local function diveCatchFrame" not in text:
    marker = "local function createLateralDrive(save:any,keeperRoot:BasePart,lateralAxis:Vector3,lateralSpeed:number)"
    if marker not in text:
        raise RuntimeError("createLateralDrive marker not found")
    text = text.replace(marker, helper + marker, 1)

text = replace_once(
    text,
    "if math.abs(lateral)>7 and time>requiredTime+.4 then",
    "if math.abs(lateral)>8 and time>requiredTime+.62 then",
    "pre dive shuffle timing"
)

text = replace_once(
    text,
    "humanoid.WalkSpeed=2",
    "humanoid.WalkSpeed=1.15",
    "pre dive shuffle speed"
)

text = replace_once(
    text,
    "if not save.Launched and time<=math.min(DIVE_LEAD_TIME,requiredTime+.34)then",
    "if not save.Launched and time<=math.min(DIVE_LEAD_TIME,requiredTime+.12)then",
    "launch timing"
)

text = replace_once(
    text,
    "local flightTime=math.clamp(time,.06,1.2)",
    "local flightTime=math.clamp(time,.09,.92)",
    "flight time"
)

text = replace_once(
    text,
    "save.RootTarget=rootTarget\n\t\tsave.FixedDiveDepth",
    "save.RootTarget=rootTarget\n\t\tsave.DiveLook=(rootTarget-keeperRoot.Position)\n\t\tsave.DiveAim=target\n\t\tsave.FixedDiveDepth",
    "store dive look"
)

text = regex_once(
    text,
    r'\t\tlocal planeTangent=tangent-forward\*tangent:Dot\(forward\).*?\n\t\tsave.Keeper:PivotTo\(desiredFrame\)',
    '''\t\tlocal diveLook=save.DiveLook or (endPosition-startPosition)
\t\tlocal liveAim=target-position
\t\tlocal blend=liveAim.Magnitude>.05 and diveLook:Lerp(liveAim,.35) or diveLook
\t\tlocal desiredFrame=diveCatchFrame(position,blend,upAxis,forward)
\t\tsave.Keeper:PivotTo(desiredFrame)''',
    "dive orientation"
)

text = replace_once(
    text,
    'self.Animations:PlayActionTimed(save.Keeper,"GoalkeeperDive",flightTime+.08)',
    'self.Animations:PlayActionTimed(save.Keeper,"GoalkeeperDive",math.max(.22,flightTime+.04))',
    "animation timing"
)

text = replace_once(
    text,
    'save.Keeper:SetAttribute("VTRDiveTarget",rootTarget)',
    'save.Keeper:SetAttribute("VTRDiveTarget",rootTarget)\n\t\tsave.Keeper:SetAttribute("VTRDiveAim",target)\n\t\tsave.Keeper:SetAttribute("VTRDiveLaunchTime",time)',
    "debug attributes"
)

path.write_text(text, encoding="utf-8", newline="\n")
print("updated goalkeeper dive timing and dive-catch rotation")