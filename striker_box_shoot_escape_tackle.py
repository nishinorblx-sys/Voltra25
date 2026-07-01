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

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

brain = regex_once(
    brain,
    r'\tif carrier\.Role == "ST" and pressure\.Closest <= 15 then.*?\n\tend\n\n\tlocal shot = AIShootingDecisionService\.Evaluate\(context, carrier, self\.Style, self\.Difficulty\)',
    '''\tlocal strikerInDangerZone = carrier.Role == "ST" and PitchConfig.InZone(carrier.Pitch, "OpponentBox")
\tlocal strikerUnderClosePressure = carrier.Role == "ST" and pressure.Closest <= 15
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

\tlocal shot = AIShootingDecisionService.Evaluate(context, carrier, self.Style, self.Difficulty)''',
    "replace striker escape block"
)

brain = replace_once(
    brain,
    'local runningIntoSpaceDanger = pressure.Closest <= 25 or ((carrier.Model:GetAttribute("AICarryIntoSpace") == true or self.LastAction[carrier.Model] == "CarryForwardSpace" or self.LastAction[carrier.Model] == "TakeOnPressForward") and pressure.Closest <= 25)',
    'local runningIntoSpaceDanger = pressure.Closest <= 25 or strikerUnderClosePressure or ((carrier.Model:GetAttribute("AICarryIntoSpace") == true or self.LastAction[carrier.Model] == "CarryForwardSpace" or self.LastAction[carrier.Model] == "TakeOnPressForward") and pressure.Closest <= 25)',
    "include striker pressure in force pass"
)

brain = replace_once(
    brain,
    'if forwardSpace and not runningIntoSpaceDanger and (pressure.None or takeOnPress or (inOpponentHalf and pressure.Under and not pass)) then',
    'if forwardSpace and not runningIntoSpaceDanger and not strikerUnderClosePressure and (pressure.None or takeOnPress or (inOpponentHalf and pressure.Under and not pass)) then',
    "block striker carry under pressure"
)

brain = replace_once(
    brain,
    'local dribbleThreshold = takeOnPress and -12 or defensiveMood == "AggressiveRisk" and -6 or defensiveMood == "Pressing" and 3 or pressure.Heavy and 22 or 5',
    'local dribbleThreshold = strikerUnderClosePressure and 999 or takeOnPress and -12 or defensiveMood == "AggressiveRisk" and -6 or defensiveMood == "Pressing" and 3 or pressure.Heavy and 22 or 5',
    "block striker dribble under pressure"
)

brain = regex_once(
    brain,
    r'\t\tfor model, assignment in pairs\(assignmentsBySide\[side\]\) do\n\t\t\tif assignment\.PrimaryAssignment == "PressBallCarrier".*?\n\t\t\tend\n\t\tend',
    '''\t\tfor model, assignment in pairs(assignmentsBySide[side]) do
\t\t\tlocal defender = context.Players[model]
\t\t\tif defender then
\t\t\t\tlocal primary = assignment.PrimaryAssignment
\t\t\t\tlocal strikerEmergencyTackle = carrier.Role == "ST" and PitchConfig.GetDistanceStuds(defender.World, carrier.World) <= 18
\t\t\t\tif strikerEmergencyTackle or primary == "PressBallCarrier" or primary == "ContainBallCarrier" or primary == "CoverPresser" or primary == "CloseLongCarryGap" or primary == "EarlyCBPressPassTarget" or primary == "EarlyClosePassTargetPressure" or primary == "CenterBackPressureStriker" or primary == "AggressiveCBPressStriker" or primary == "AggressiveCBStepOut" then
\t\t\t\t\tlocal canTackle, slide = AITacklingDecisionService.CanTackle(context, defender, carrier, self.Style)
\t\t\t\t\tif canTackle then
\t\t\t\t\t\tif self.BallService:Tackle(model, slide) then
\t\t\t\t\t\t\tself.LastAction[model] = slide and "SlideTackle" or "Tackle"
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\tend
\t\tend''',
    "defenders tackle striker carrier"
)

brain_path.write_text(brain, encoding="utf-8", newline="\n")

assignment_path = Path("src/server/Gameplay/AIAssignmentService.lua")
assignment = assignment_path.read_text(encoding="utf-8")

assignment = replace_once(
    assignment,
    'local tightlyMarked = nearest <= 13',
    'local tightlyMarked = nearest <= 15',
    "striker tightly marked distance"
)

assignment = replace_once(
    assignment,
    'return "ComeShort", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(340, ballPitch.Z - 30)), 0.84, false',
    'return "ComeShortToEscapePressure", Vector3.new(PitchConfig.HALF_WIDTH + (info.Pitch.X < PitchConfig.HALF_WIDTH and 28 or -28), 3, math.max(340, ballPitch.Z - 38)), 0.92, true',
    "striker come short escape angle"
)

assignment_path.write_text(assignment, encoding="utf-8", newline="\n")

print("updated striker box shooting, escape passing, and emergency tackling")