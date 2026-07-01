from pathlib import Path

path = Path("src/server/Gameplay/AIAssignmentService.lua")
text = path.read_text(encoding="utf-8")

old_owner = '\tlocal ownerPitch = ownerInfo and ownerInfo.Pitch or ballPitch'
new_owner = '\tlocal ownerPitch = ballPitch'

if old_owner in text:
    text = text.replace(old_owner, new_owner, 1)

marker = '\tlocal carrierHasCarriedIntoSpace = ownerInfo and ownerInfo.Model:GetAttribute("AICarryIntoSpace") == true and (tonumber(ownerInfo.Model:GetAttribute("AICarriedFor")) or 0) >= 2'

insert = '''\tlocal defensiveThird = ownerInfo ~= nil and ballPitch.Z <= 245
\tif ownerInfo and not pressPaused and defensiveThird then
\t\tif info.Role == "CB" and (ownerRole == "ST" or ownerRole == "CAM") then
\t\t\treturn "AttackStrikerInDefensiveThird", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\telseif info.Role == "Fullback" and (ownerRole == "Winger" or ownerRole == "LW" or ownerRole == "RW") and sameSide then
\t\t\treturn "PressWingerInDefensiveThird", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\telseif (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then
\t\t\tlocal rank = midfieldPressRank(context, info, ownerInfo)
\t\t\tif rank == 1 then
\t\t\t\treturn "MidfielderDefensiveThirdPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\t\telseif rank == 2 then
\t\t\t\treturn "MidfielderDefensiveThirdCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.92, true, faceModel
\t\t\tend
\t\tend
\tend'''

if "AttackStrikerInDefensiveThird" not in text:
    if marker not in text:
        raise RuntimeError("Could not find defensiveRoleTarget insertion point")
    text = text.replace(marker, marker + "\n" + insert, 1)

old_cb = '''\t\telseif ownerRole == "ST" and PitchConfig.GetDistanceStuds(info.World, ownerInfo.World) <= 34 and ownerPitch.Z < info.Pitch.Z + 28 then
\t\t\treturn "StepToStrikerFeet", Vector3.new(info.BasePitch.X, 3, math.max(45, ownerPitch.Z - 8)), 0.88, true, faceModel'''

new_cb = '''\t\telseif ownerRole == "ST" and ballPitch.Z <= 285 then
\t\t\treturn "StepToStrikerFeet", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel'''

if old_cb in text:
    text = text.replace(old_cb, new_cb, 1)

old_fb = '''\t\t\treturn "StepToWinger", Vector3.new(sideLaneX(info, true), 3, math.clamp(ballPitch.Z - 8, 58, 310)), 0.88, true, faceModel'''

new_fb = '''\t\t\treturn "StepToWinger", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.98, true, faceModel'''

if old_fb in text:
    text = text.replace(old_fb, new_fb, 1)

path.write_text(text, encoding="utf-8", newline="\n")
print("updated", path)