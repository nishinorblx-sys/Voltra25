from pathlib import Path

def replace_one(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

assignment_path = Path("src/server/Gameplay/AIAssignmentService.lua")
text = assignment_path.read_text(encoding="utf-8")

text = replace_one(
    text,
    '\tlocal defensiveThirdPressure = ownerInfo ~= nil and ballPitch.Z <= 285',
    '\tlocal defensiveThirdPressure = ownerInfo ~= nil and ballPitch.Z <= PitchConfig.HALF_LENGTH',
    "defensiveThirdPressure to own half"
)

text = replace_one(
    text,
    '\tlocal defensiveHalfPressure = ownerInfo ~= nil and ballPitch.Z <= PitchConfig.HALF_LENGTH',
    '\tlocal defensiveHalfPressure = ownerInfo ~= nil and ballPitch.Z <= PitchConfig.HALF_LENGTH',
    "defensiveHalfPressure already own half"
)

text = replace_one(
    text,
    'elseif defensiveThirdPressure and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") and carrierDistance <= 90 then',
    'elseif defensiveThirdPressure and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") and carrierDistance <= 110 then',
    "midfielder pressure distance"
)

text = replace_one(
    text,
    'if info.Role == "CB" and (ownerRole == "ST" or ownerRole == "CAM") and carrierDistance <= 95 then',
    'if info.Role == "CB" and (ownerRole == "ST" or ownerRole == "CAM") and carrierDistance <= 115 then',
    "cb pressure distance"
)

text = replace_one(
    text,
    'elseif info.Role == "Fullback" and (ownerRole == "Winger" or ownerRole == "LW" or ownerRole == "RW") and sameSide and carrierDistance <= 85 then',
    'elseif info.Role == "Fullback" and (ownerRole == "Winger" or ownerRole == "LW" or ownerRole == "RW") and sameSide and carrierDistance <= 105 then',
    "fullback pressure distance"
)

assignment_path.write_text(text, encoding="utf-8", newline="\n")

team_path = Path("src/server/Gameplay/AITeamController.lua")
team = team_path.read_text(encoding="utf-8")

team = replace_one(
    team,
    'Accum = {Phase = 0.08, Assignment = 0.1, OnBall = 0.08, Movement = 0.06, Debug = 0.25}',
    'Accum = {Phase = 0.05, Assignment = 0.05, OnBall = 0.04, Movement = 0.04, Debug = 0.25}',
    "ai update accum"
)

team = replace_one(
    team,
    'if self.Accum.Phase >= 0.08 then',
    'if self.Accum.Phase >= 0.05 then',
    "phase refresh"
)

team = replace_one(
    team,
    'if self.Accum.Assignment >= 0.1 or not next(self.CurrentAssignments.Home) then',
    'if self.Accum.Assignment >= 0.05 or not next(self.CurrentAssignments.Home) then',
    "assignment refresh"
)

team = replace_one(
    team,
    'if self.Accum.OnBall >= 0.08 then',
    'if self.Accum.OnBall >= 0.04 then',
    "on ball refresh"
)

team = replace_one(
    team,
    'if self.Accum.Movement >= 0.06 then',
    'if self.Accum.Movement >= 0.04 then',
    "movement refresh"
)

team_path.write_text(team, encoding="utf-8", newline="\n")

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

brain = replace_one(
    brain,
    '\t\tlocal waitDone = carriedFor >= 0.65 or pressure.Under',
    '\t\tlocal waitDone = carriedFor >= 0.35 or pressure.Under or pressure.Heavy',
    "goalkeeper distribution wait"
)

brain = replace_one(
    brain,
    '\tif now < nextDecision and carriedFor < holdLimit then',
    '\tif now < nextDecision and carriedFor < holdLimit and not pressure.Under and not pressure.Heavy then',
    "skip wait under pressure"
)

brain = replace_one(
    brain,
    '\tself.NextDecision[carrier.Model] = now + math.max(0.08, math.min(AIDifficultyService.NextDecisionDelay(self.Difficulty) * (1.12 - passTempo * 0.55), holdLimit))',
    '\tself.NextDecision[carrier.Model] = now + math.max(0.04, math.min(AIDifficultyService.NextDecisionDelay(self.Difficulty) * (0.72 - passTempo * 0.42), holdLimit * 0.65))',
    "faster next decision"
)

brain = replace_one(
    brain,
    '\tlocal forcedSafe = wingerEndLine or (defensiveMood ~= "AggressiveRisk" and (pressure.Heavy or carriedFor >= holdLimit or self.Style:Risk() < 0.38 or (pressure.Under and passTempo > 0.55)))',
    '\tlocal forcedSafe = wingerEndLine or (defensiveMood ~= "AggressiveRisk" and (pressure.Heavy or pressure.Under or carriedFor >= holdLimit * 0.65 or self.Style:Risk() < 0.38))',
    "forced safe pressure"
)

brain = replace_one(
    brain,
    '\tif pass and (forcedSafe or pass.Score > (18 - passTempo * 16) or carriedFor > math.max(0.14, 0.46 - passTempo * 0.28)) then',
    '\tif pass and (forcedSafe or pass.Score > (8 - passTempo * 20) or carriedFor > math.max(0.06, 0.28 - passTempo * 0.18)) then',
    "faster pass trigger"
)

brain_path.write_text(brain, encoding="utf-8", newline="\n")

passing_path = Path("src/server/Gameplay/AIPassingDecisionService.lua")
passing = passing_path.read_text(encoding="utf-8")

old = '''\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)

\tlocal score = 0'''
new = '''\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)

\tlocal score = 0'''

passing = replace_one(passing, old, new, "passer pressure anchor")

old2 = '''\tscore += difficulty.PassRisk * 10'''
new2 = '''\tif passerPressure.Heavy then
\t\tscore += scoredKind == "Side" and 22 or scoredKind == "Back" and 18 or 0
\t\tscore += distance <= 58 and 16 or 0
\t\tscore += laneClear and 12 or 0
\telseif passerPressure.Under then
\t\tscore += scoredKind == "Side" and 14 or scoredKind == "Back" and 10 or 0
\t\tscore += distance <= 64 and 8 or 0
\tend
\tscore += difficulty.PassRisk * 10'''

if "passerPressure.Heavy" not in passing:
    passing = replace_one(passing, old2, new2, "pressure pass score")
else:
    print("skipped pressure pass score")

passing_path.write_text(passing, encoding="utf-8", newline="\n")

print("updated own-half press and faster passing")
