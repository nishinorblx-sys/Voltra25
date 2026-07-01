from pathlib import Path

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

anchor = '''\tlocal shot = AIShootingDecisionService.Evaluate(context, carrier, self.Style, self.Difficulty)
\tcarrier.Model:SetAttribute("AIShotScore", shot.Score)'''

insert = '''\tif carrier.Role == "ST" and pressure.Closest <= 15 then
\t\tlocal strikerEscapePass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, true)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePressure", true)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassReceiver", strikerEscapePass and strikerEscapePass.Receiver and strikerEscapePass.Receiver.Model.Name or "")
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassKind", strikerEscapePass and strikerEscapePass.PassKind or "")
\t\tif strikerEscapePass and self:_kickPass(context, carrier, strikerEscapePass) then
\t\t\tself.CarrySince[carrier.Model] = nil
\t\t\treturn
\t\tend
\telse
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePressure", false)
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassReceiver", "")
\t\tcarrier.Model:SetAttribute("AIStrikerEscapePassKind", "")
\tend

\tlocal shot = AIShootingDecisionService.Evaluate(context, carrier, self.Style, self.Difficulty)
\tcarrier.Model:SetAttribute("AIShotScore", shot.Score)'''

if "AIStrikerEscapePressure" not in brain:
    brain = replace_once(brain, anchor, insert, "striker escape before shot")

brain_path.write_text(brain, encoding="utf-8", newline="\n")

assignment_path = Path("src/server/Gameplay/AIAssignmentService.lua")
assignment = assignment_path.read_text(encoding="utf-8")

old = '''\tif best then
\t\tlocal behind = best.Role == "ST" and 30 or 24
\t\tlocal lateral = best.Pitch.X < PitchConfig.HALF_WIDTH and 18 or -18
\t\tlocal target = Vector3.new(
\t\t\tmath.clamp(best.Pitch.X + lateral, 112, 312),
\t\t\t3,
\t\t\tmath.clamp(best.Pitch.Z - behind, math.max(175, ballPitch.Z - 44), math.max(230, ballPitch.Z + 42))
\t\t)
\t\treturn best.Role == "ST" and "TrailStrikerCover" or "TrailMidfielderCover", target
\tend'''

new = '''\tif best then
\t\tlocal behind = best.Role == "ST" and 34 or 26
\t\tlocal lateralSide = info.Pitch.X < PitchConfig.HALF_WIDTH and -1 or 1
\t\tif math.abs(info.Pitch.X - PitchConfig.HALF_WIDTH) < 14 then
\t\t\tlateralSide = ballPitch.X < PitchConfig.HALF_WIDTH and 1 or -1
\t\tend
\t\tlocal lateral = best.Role == "ST" and lateralSide * 44 or lateralSide * 32
\t\tlocal target = Vector3.new(
\t\t\tmath.clamp(best.Pitch.X + lateral, 86, 338),
\t\t\t3,
\t\t\tmath.clamp(best.Pitch.Z - behind, math.max(175, ballPitch.Z - 48), math.max(230, ballPitch.Z + 38))
\t\t)
\t\treturn best.Role == "ST" and "TrailStrikerCoverWide" or "TrailMidfielderCoverWide", target
\tend'''

assignment = replace_once(assignment, old, new, "wide striker cover")

assignment_path.write_text(assignment, encoding="utf-8", newline="\n")

passing_path = Path("src/server/Gameplay/AIPassingDecisionService.lua")
passing = passing_path.read_text(encoding="utf-8")

passing = passing.replace(
    'local trailingCover = receiverAssignment == "TrailStrikerCover" or receiverAssignment == "TrailMidfielderCover" or receiverAssignment == "TrailingPassBack"',
    'local trailingCover = receiverAssignment == "TrailStrikerCover" or receiverAssignment == "TrailMidfielderCover" or receiverAssignment == "TrailStrikerCoverWide" or receiverAssignment == "TrailMidfielderCoverWide" or receiverAssignment == "TrailingPassBack"'
)

passing = passing.replace(
    'local isTrailing = assignment == "TrailStrikerCover" or assignment == "TrailMidfielderCover" or assignment == "TrailingPassBack"',
    'local isTrailing = assignment == "TrailStrikerCover" or assignment == "TrailMidfielderCover" or assignment == "TrailStrikerCoverWide" or assignment == "TrailMidfielderCoverWide" or assignment == "TrailingPassBack"'
)

passing_path.write_text(passing, encoding="utf-8", newline="\n")

print("updated striker escape passing and wider cover support")