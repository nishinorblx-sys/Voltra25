from pathlib import Path
import re

assignment_path = Path("src/server/Gameplay/AIAssignmentService.lua")
text = assignment_path.read_text(encoding="utf-8")

shape_fn = '''local function shapeMotion(context: any, info: any, target: Vector3, depth: number?, width: number?): Vector3
\tlocal seed = 0
\tlocal name = info.Model and info.Model.Name or tostring(info.Role or "")
\tfor i = 1, #name do
\t\tseed += string.byte(name, i) or 0
\tend
\tlocal now = context.Now or os.clock()
\tlocal depthAmount = depth or 14
\tlocal widthAmount = width or 5
\tlocal waveA = math.sin(now * (0.82 + (seed % 7) * 0.035) + seed * 0.19)
\tlocal waveB = math.cos(now * (0.58 + (seed % 5) * 0.04) + seed * 0.13)
\tlocal stagger = ((seed % 7) - 3) * 3
\treturn PitchConfig.ClampInsidePitch(Vector3.new(target.X + waveB * widthAmount, target.Y, target.Z + waveA * depthAmount + stagger))
end

'''

if "local function shapeMotion" not in text:
    marker = "local function simpleDefensiveShapeTarget(info: any, ballPitch: Vector3, base: Vector3, style: any): Vector3"
    if marker not in text:
        raise RuntimeError("Could not find simpleDefensiveShapeTarget")
    text = text.replace(marker, shape_fn + marker, 1)

text = text.replace(
    '\tlocal ballInDefensiveThird = ballPitch.Z <= PitchConfig.Zones.DefensiveThird.ZMax',
    '\tlocal ballInOwnHalf = ballPitch.Z <= PitchConfig.HALF_LENGTH',
    1
)

old_block = '''\tif ownerInfo and ballInDefensiveThird then
\t\tif info.Role == "CB" and ownerInfo.Role == "ST" then
\t\t\treturn "CenterBackPressureStriker", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\tend
\t\tif info.Role == "Fullback" and ownerInfo.Role == "Winger" and sameWideSide(info, ownerPitch) then
\t\t\treturn "FullbackPressureWinger", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.98, true, faceModel
\t\tend
\tend'''

new_block = '''\tif ownerInfo and ballInOwnHalf then
\t\tlocal carrierDistance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
\t\tlocal ownerMidfielder = ownerInfo.Role == "CDM" or ownerInfo.Role == "CM" or ownerInfo.Role == "CAM"
\t\tlocal infoMidfielder = info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM"
\t\tif info.Role == "CB" and (ownerInfo.Role == "ST" or ownerInfo.Role == "CAM") and carrierDistance <= 125 then
\t\t\treturn "CenterBackPressureStriker", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\tend
\t\tif info.Role == "Fullback" and ownerInfo.Role == "Winger" and sameWideSide(info, ownerPitch) and carrierDistance <= 115 then
\t\t\treturn "FullbackPressureWinger", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.98, true, faceModel
\t\tend
\t\tif infoMidfielder and ownerMidfielder and carrierDistance <= 120 then
\t\t\tlocal rank = midfieldPressRank(context, info, ownerInfo)
\t\t\tif rank == 1 then
\t\t\t\treturn "MidfielderPressureMidfielder", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\t\telseif rank == 2 then
\t\t\t\treturn "MidfielderPressureCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.94, true, faceModel
\t\t\tend
\t\tend
\tend'''

if old_block in text:
    text = text.replace(old_block, new_block, 1)
elif "MidfielderPressureMidfielder" not in text:
    marker = '\tif pressState and pressState.Active and pressState.Primary == info.Model and ownerInfo then'
    if marker not in text:
        raise RuntimeError("Could not find pressure insert marker")
    text = text.replace(marker, new_block + "\n\n" + marker, 1)

text = text.replace(
    '\treturn "DefensiveShape", simpleDefensiveShapeTarget(info, ballPitch, base, style), 0.82, false, nil',
    '\tlocal shapeTarget = shapeMotion(context, info, simpleDefensiveShapeTarget(info, ballPitch, base, style), 18, 6)\n\treturn "DefensiveShape", shapeTarget, 0.86, true, nil',
    1
)

assignment_path.write_text(text, encoding="utf-8", newline="\n")

movement_path = Path("src/server/Gameplay/AIMovementService.lua")
movement = movement_path.read_text(encoding="utf-8")

movement = movement.replace(
    'local closeHoldAssignment = assignmentName == "DefensiveShape" or assignmentName == "DefensiveRestBlock" or assignmentName == "PostPressShadow"',
    'local closeHoldAssignment = assignmentName == "DefensiveRestBlock" or assignmentName == "PostPressShadow"',
    1
)

pressure_line = '\tlocal pressureAssignment = assignmentName == "PressBallCarrier" or assignmentName == "ContainBallCarrier" or assignmentName == "CloseLongCarryGap" or assignmentName == "TrackRunner" or assignmentName == "PrimaryPressRotation" or assignmentName == "CenterBackPressureStriker" or assignmentName == "FullbackPressureWinger" or assignmentName == "AggressiveCBPressStriker" or assignmentName == "AggressiveFullbackPressWinger" or assignmentName == "AggressiveMidfieldPress" or assignmentName == "AggressiveMidfieldCover" or assignmentName == "AggressiveCBStepOut" or assignmentName == "AggressiveFullbackStepOut" or assignmentName == "MidfielderPressureMidfielder" or assignmentName == "MidfielderPressureCover"\n'
movement = re.sub(r'\tlocal pressureAssignment = .*?\n', pressure_line, movement, count=1)

movement = re.sub(
    r'\tif mode == "Sprint" and stamina < 30 and not \(assignmentName == "ChaseLooseBall".*?\) then',
    '\tif mode == "Sprint" and stamina < 30 and not pressureAssignment and not (assignmentName == "ChaseLooseBall" or assignmentName == "CounterSprint") then',
    movement,
    count=1
)

if 'local pressTag = pressureAssignment' not in movement:
    movement = re.sub(
        r'\tmodel:SetAttribute\("PressAssignment", .*?\)\n',
        '\tlocal pressTag = pressureAssignment and ((assignmentName == "CoverPresser" or assignmentName == "AggressiveMidfieldCover" or assignmentName == "MidfielderPressureCover") and "Secondary" or "Primary") or "Hold"\n\tmodel:SetAttribute("PressAssignment", pressTag)\n',
        movement,
        count=1
    )

movement_path.write_text(movement, encoding="utf-8", newline="\n")

print("updated lively defensive shape and role pressure")