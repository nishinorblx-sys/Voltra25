from pathlib import Path

assignment_path = Path("src/server/Gameplay/AIAssignmentService.lua")
text = assignment_path.read_text(encoding="utf-8")

text = text.replace(
    '\tlocal ownerPitch = ownerInfo and ownerInfo.Pitch or ballPitch',
    '\tlocal ownerPitch = ballPitch',
    1
)

marker = '\tlocal carrierHasCarriedIntoSpace = ownerInfo and ownerInfo.Model:GetAttribute("AICarryIntoSpace") == true and (tonumber(ownerInfo.Model:GetAttribute("AICarriedFor")) or 0) >= 2'

insert = '''\tlocal carrierDistance = ownerInfo and PitchConfig.GetDistanceStuds(info.World, ownerInfo.World) or math.huge
\tlocal defensiveHalfPressure = ownerInfo ~= nil and ballPitch.Z <= PitchConfig.HALF_LENGTH
\tlocal defensiveThirdPressure = ownerInfo ~= nil and ballPitch.Z <= 285
\tif ownerInfo and not pressPaused and defensiveHalfPressure then
\t\tif info.Role == "CB" and (ownerRole == "ST" or ownerRole == "CAM") and carrierDistance <= 95 then
\t\t\treturn "AggressiveCBPressStriker", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\telseif info.Role == "Fullback" and (ownerRole == "Winger" or ownerRole == "LW" or ownerRole == "RW") and sameSide and carrierDistance <= 85 then
\t\t\treturn "AggressiveFullbackPressWinger", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\telseif defensiveThirdPressure and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") and carrierDistance <= 90 then
\t\t\tlocal rank = midfieldPressRank(context, info, ownerInfo)
\t\t\tif rank == 1 then
\t\t\t\treturn "AggressiveMidfieldPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
\t\t\telseif rank == 2 and carrierDistance <= 105 then
\t\t\t\treturn "AggressiveMidfieldCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.94, true, faceModel
\t\t\tend
\t\tend
\tend'''

if "AggressiveCBPressStriker" not in text:
    if marker not in text:
        raise RuntimeError("Could not find insertion point in AIAssignmentService.lua")
    text = text.replace(marker, marker + "\n" + insert, 1)

text = text.replace(
    '\t\treturn "HoldCenterBackLine", Vector3.new(info.BasePitch.X, 3, base.Z), 0.76, false, nil',
    '\t\tif ownerInfo and ownerRole ~= "" and ballPitch.Z <= 285 and carrierDistance <= 110 then\n\t\t\treturn "AggressiveCBStepOut", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.96, true, faceModel\n\t\tend\n\t\treturn "HoldCenterBackLine", Vector3.new(info.BasePitch.X, 3, base.Z), 0.76, false, nil',
    1
)

text = text.replace(
    '\t\treturn "HoldFullbackLine", base, 0.74, false, nil',
    '\t\tif ownerInfo and ballSide ~= "Center" and sameSide and carrierDistance <= 95 then\n\t\t\treturn "AggressiveFullbackStepOut", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.96, true, faceModel\n\t\tend\n\t\treturn "HoldFullbackLine", base, 0.74, false, nil',
    1
)

assignment_path.write_text(text, encoding="utf-8", newline="\n")

movement_path = Path("src/server/Gameplay/AIMovementService.lua")
movement = movement_path.read_text(encoding="utf-8")

old_pressure = 'local pressureAssignment = assignmentName == "PressBallCarrier" or assignmentName == "ContainBallCarrier" or assignmentName == "CloseLongCarryGap" or assignmentName == "TrackRunner" or assignmentName == "PrimaryPressRotation" or assignmentName == "CenterBackPressureStriker" or assignmentName == "FullbackPressureWinger"'
new_pressure = 'local pressureAssignment = assignmentName == "PressBallCarrier" or assignmentName == "ContainBallCarrier" or assignmentName == "CloseLongCarryGap" or assignmentName == "TrackRunner" or assignmentName == "PrimaryPressRotation" or assignmentName == "CenterBackPressureStriker" or assignmentName == "FullbackPressureWinger" or assignmentName == "AggressiveCBPressStriker" or assignmentName == "AggressiveFullbackPressWinger" or assignmentName == "AggressiveMidfieldPress" or assignmentName == "AggressiveMidfieldCover" or assignmentName == "AggressiveCBStepOut" or assignmentName == "AggressiveFullbackStepOut"'

if old_pressure in movement:
    movement = movement.replace(old_pressure, new_pressure, 1)

old_stamina = 'if mode == "Sprint" and stamina < 30 and not (assignmentName == "ChaseLooseBall" or assignmentName == "CounterSprint" or assignmentName == "PressBallCarrier" or assignmentName == "CloseLongCarryGap" or assignmentName == "PrimaryPressRotation" or assignmentName == "CenterBackPressureStriker" or assignmentName == "FullbackPressureWinger") then'
new_stamina = 'if mode == "Sprint" and stamina < 30 and not pressureAssignment and not (assignmentName == "ChaseLooseBall" or assignmentName == "CounterSprint") then'

if old_stamina in movement:
    movement = movement.replace(old_stamina, new_stamina, 1)

old_press_attr = 'model:SetAttribute("PressAssignment", (assignmentName == "PressBallCarrier" or assignmentName == "CloseLongCarryGap" or assignmentName == "PrimaryPressRotation" or assignmentName == "CenterBackPressureStriker" or assignmentName == "FullbackPressureWinger") and "Primary" or assignmentName == "CoverPresser" and "Secondary" or "Hold")'
new_press_attr = 'model:SetAttribute("PressAssignment", pressureAssignment and "Primary" or (assignmentName == "CoverPresser" or assignmentName == "AggressiveMidfieldCover") and "Secondary" or "Hold")'

if old_press_attr in movement:
    movement = movement.replace(old_press_attr, new_press_attr, 1)

movement_path.write_text(movement, encoding="utf-8", newline="\n")

print("updated defensive pressure mix")