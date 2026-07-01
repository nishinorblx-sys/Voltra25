from pathlib import Path
import re

def regex_once(text, pattern, new, label):
    next_text, count = re.subn(pattern, new, text, count=1, flags=re.S)
    if count == 0:
        print("skipped", label)
        return text
    return next_text

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

brain = regex_once(
    brain,
    r'\tlocal boxCross = chooseBoxCross\(context, carrier\).*?\n\tend\n\n\tlocal strikerInDangerZone',
    '''\tif carrier.Role == "Winger" and wingerWide and carrier.Pitch.Z >= 520 and pressure.Closest > 18 then
\t\tlocal diagonalX = carrier.Pitch.X < PitchConfig.HALF_WIDTH and 154 or 270
\t\tlocal diagonalZ = math.min(PitchConfig.PITCH_LENGTH - 45, math.max(carrier.Pitch.Z + 36, 650))
\t\tlocal diagonalPitch = PitchConfig.ClampInsidePitch(Vector3.new(diagonalX, 3, diagonalZ))
\t\tlocal straightPitch = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X, 3, PitchConfig.PITCH_LENGTH - 20))
\t\tlocal diagonalSpace = AIContextBuilder.SpaceAt(context, carrier.Side, diagonalPitch, 22)
\t\tlocal straightSpace = AIContextBuilder.SpaceAt(context, carrier.Side, straightPitch, 24)
\t\tif diagonalSpace then
\t\t\tlocal target = PitchConfig.TeamPitchPositionToWorld(diagonalPitch, carrier.Side, context.Options)
\t\t\tassignment.TargetWorld = target
\t\t\tassignment.MovementTarget = target
\t\t\tassignment.PrimaryAssignment = "WingerDiagonalGoalCarry"
\t\t\tassignment.MovementUrgency = 1
\t\t\tassignment.SprintAllowed = true
\t\t\tcarrier.Model:SetAttribute("AIWingerAttackLane", "DiagonalGoal")
\t\t\tcarrier.Model:SetAttribute("AIWingerTargetGoalDistance", PitchConfig.PITCH_LENGTH - diagonalPitch.Z)
\t\t\tself.LastAction[carrier.Model] = "WingerDiagonalGoalCarry"
\t\t\treturn
\t\telseif straightSpace and carrier.Pitch.Z < PitchConfig.PITCH_LENGTH - 24 then
\t\t\tlocal target = PitchConfig.TeamPitchPositionToWorld(straightPitch, carrier.Side, context.Options)
\t\t\tassignment.TargetWorld = target
\t\t\tassignment.MovementTarget = target
\t\t\tassignment.PrimaryAssignment = "WingerEndLineCarry"
\t\t\tassignment.MovementUrgency = 1
\t\t\tassignment.SprintAllowed = true
\t\t\tcarrier.Model:SetAttribute("AIWingerAttackLane", "EndLine")
\t\t\tcarrier.Model:SetAttribute("AIWingerTargetGoalDistance", PitchConfig.PITCH_LENGTH - straightPitch.Z)
\t\t\tself.LastAction[carrier.Model] = "WingerEndLineCarry"
\t\t\treturn
\t\telse
\t\t\tcarrier.Model:SetAttribute("AIWingerAttackLane", "")
\t\tend
\tend

\tlocal boxCross = chooseBoxCross(context, carrier)
\tlocal wingerPass = boxCross or AIPassingDecisionService.ChooseWingerWide(context, carrier, self.Style, self.Difficulty)
\tcarrier.Model:SetAttribute("AIWingerWideDecision", wingerPass and wingerPass.PassKind or "")
\tif wingerPass and (wingerEndLine or wingerChanceZone or pressure.Under or wingerPass.Score > 390) then
\t\tif self:_kickPass(context, carrier, wingerPass) then
\t\t\tself.CarrySince[carrier.Model] = nil
\t\t\treturn
\t\tend
\tend

\tlocal strikerInDangerZone''',
    "insert winger attacking carry before crosses"
)

brain = regex_once(
    brain,
    r'\tlocal strikerInDangerZone = carrier\.Role == "ST" and PitchConfig\.InZone\(carrier\.Pitch, "OpponentBox"\).*?\n\tend\n\n\tlocal shot = AIShootingDecisionService\.Evaluate',
    '''\tlocal strikerInDangerZone = carrier.Role == "ST" and PitchConfig.InZone(carrier.Pitch, "OpponentBox")
\tlocal strikerUnderClosePressure = carrier.Role == "ST" and pressure.Closest <= 15
\tlocal strikerGoalDistance = PitchConfig.PITCH_LENGTH - carrier.Pitch.Z
\tlocal strikerCanDriveDeeper = false
\tlocal strikerDriveChance = 0
\tif carrier.Role == "ST" and strikerInDangerZone and not strikerUnderClosePressure and strikerGoalDistance > 50 then
\t\tlocal depthAlpha = math.clamp((132 - strikerGoalDistance) / 82, 0, 1)
\t\tstrikerDriveChance = math.clamp(0.3 + depthAlpha * 0.7, 0.3, 1)
\t\tlocal deeperZ = math.max(carrier.Pitch.Z + 18, PitchConfig.PITCH_LENGTH - math.max(50, strikerGoalDistance - 24))
\t\tlocal deeperPitch = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X + (PitchConfig.HALF_WIDTH - carrier.Pitch.X) * 0.18, 3, math.min(deeperZ, PitchConfig.PITCH_LENGTH - 45)))
\t\tstrikerCanDriveDeeper = AIContextBuilder.SpaceAt(context, carrier.Side, deeperPitch, 18)
\t\tcarrier.Model:SetAttribute("AIStrikerDriveDeeperChance", strikerDriveChance)
\t\tcarrier.Model:SetAttribute("AIStrikerGoalDistance", strikerGoalDistance)
\t\tcarrier.Model:SetAttribute("AIStrikerDriveDeeperSpace", strikerCanDriveDeeper)
\t\tif strikerCanDriveDeeper and self.Random:NextNumber() <= strikerDriveChance then
\t\t\tlocal target = PitchConfig.TeamPitchPositionToWorld(deeperPitch, carrier.Side, context.Options)
\t\t\tassignment.TargetWorld = target
\t\t\tassignment.MovementTarget = target
\t\t\tassignment.PrimaryAssignment = "StrikerDriveDeeperForShot"
\t\t\tassignment.MovementUrgency = 1
\t\t\tassignment.SprintAllowed = true
\t\t\tcarrier.Model:SetAttribute("AIStrikerBoxShootNow", false)
\t\t\tself.LastAction[carrier.Model] = "StrikerDriveDeeperForShot"
\t\t\treturn
\t\tend
\telse
\t\tcarrier.Model:SetAttribute("AIStrikerDriveDeeperChance", 0)
\t\tcarrier.Model:SetAttribute("AIStrikerGoalDistance", strikerGoalDistance)
\t\tcarrier.Model:SetAttribute("AIStrikerDriveDeeperSpace", false)
\tend
\tif strikerInDangerZone then
\t\tlocal immediateShot = AIShootingDecisionService.Evaluate(context, carrier, self.Style, self.Difficulty)
\t\tcarrier.Model:SetAttribute("AIStrikerBoxShootNow", true)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePressure", false)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassReceiver", "")
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassKind", "")
\t\tif self:_shoot(context, carrier, immediateShot) then
\t\t\tself.CarrySince[carrier.Model] = nil
\t\t\treturn
\t\tend
\telseif strikerUnderClosePressure then
\t\tlocal strikerEscapePass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, true)
\t\tcarrier.Model:SetAttribute("AIStrikerBoxShootNow", false)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePressure", true)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassReceiver", strikerEscapePass and strikerEscapePass.Receiver and strikerEscapePass.Receiver.Model.Name or "")
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassKind", strikerEscapePass and strikerEscapePass.PassKind or "")
\t\tif strikerEscapePass and self:_kickPass(context, carrier, strikerEscapePass) then
\t\t\tself.CarrySince[carrier.Model] = nil
\t\t\treturn
\t\tend
\telse
\t\tcarrier.Model:SetAttribute("AIStrikerBoxShootNow", false)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePressure", false)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassReceiver", "")
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassKind", "")
\tend

\tlocal shot = AIShootingDecisionService.Evaluate''',
    "replace striker box shoot with drive deeper chance"
)

brain_path.write_text(brain, encoding="utf-8", newline="\n")

print("updated striker deeper carries and winger attacking lane carries")