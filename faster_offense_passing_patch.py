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

team_path = Path("src/server/Gameplay/AITeamController.lua")
team = team_path.read_text(encoding="utf-8")

team = regex_once(
    team,
    r'Accum = \{Phase = [0-9.]+, Assignment = [0-9.]+, OnBall = [0-9.]+, Movement = [0-9.]+, Debug = 0.25\}',
    'Accum = {Phase = 0.035, Assignment = 0.035, OnBall = 0.03, Movement = 0.03, Debug = 0.25}',
    "accum table"
)

team = regex_once(team, r'if self\.Accum\.Phase >= [0-9.]+ then', 'if self.Accum.Phase >= 0.035 then', "phase refresh")
team = regex_once(team, r'if self\.Accum\.Assignment >= [0-9.]+ or not next\(self\.CurrentAssignments\.Home\) then', 'if self.Accum.Assignment >= 0.035 or not next(self.CurrentAssignments.Home) then', "assignment refresh")
team = regex_once(team, r'if self\.Accum\.OnBall >= [0-9.]+ then', 'if self.Accum.OnBall >= 0.03 then', "onball refresh")
team = regex_once(team, r'if self\.Accum\.Movement >= [0-9.]+ then', 'if self.Accum.Movement >= 0.03 then', "movement refresh")

team_path.write_text(team, encoding="utf-8", newline="\n")

passing_path = Path("src/server/Gameplay/AIPassingDecisionService.lua")
passing = passing_path.read_text(encoding="utf-8")

passing = passing.replace("scoredKind", "kind")

passing = replace_once(
    passing,
    'score += laneClear and 26 or -34',
    'score += laneClear and 38 or -86',
    "lane clear score"
)

passing = replace_once(
    passing,
    'score += kind == "Forward" and (30 + directness * 24 + forwardPriority * 24) or kind == "Side" and (8 - directness * 5) or (-16 + backPassSafety * 8 - directness * 24)',
    'score += kind == "Forward" and (42 + directness * 28 + forwardPriority * 28) or kind == "Side" and (26 - directness * 3) or (-42 + backPassSafety * 4 - directness * 30)',
    "pass direction score"
)

if "local fastDistributionBias = true" not in passing:
    passing = replace_once(
        passing,
        '\tscore += routeBias(stage, mood, receiver, kind, forwardGain)',
        '\tscore += routeBias(stage, mood, receiver, kind, forwardGain)\n\tlocal fastDistributionBias = true\n\tif kind == "Back" then\n\t\tscore -= passer.Pitch.Z >= PitchConfig.HALF_LENGTH and 58 or 34\n\t\tif forwardGain < -38 then\n\t\t\tscore -= 20\n\t\tend\n\telseif kind == "Side" then\n\t\tscore += laneClear and 24 or -28\n\t\tif passerPressure.Under or passerPressure.Heavy then\n\t\t\tscore += open or veryOpen and 20 or 8\n\t\tend\n\telseif kind == "Forward" then\n\t\tscore += laneClear and 28 or -42\n\t\tscore += math.clamp(forwardGain, 0, 70) * 0.36\n\t\tif open or veryOpen then\n\t\t\tscore += 16\n\t\tend\n\tend',
        "fast distribution bias"
    )

passing = replace_once(
    passing,
    'if not laneClear then\n\t\tscore -= 38\n\tend',
    'if not laneClear then\n\t\tscore -= 72\n\tend',
    "extra lane penalty"
)

passing = replace_once(
    passing,
    '\tlocal alternate = nil\n\tlocal progressive = nil',
    '\tlocal alternate = nil\n\tlocal progressive = nil\n\tlocal sideways = nil',
    "sideways local"
)

if "sideways = scored" not in passing:
    passing = replace_once(
        passing,
        '\t\t\t\tif scored.LaneClear and scored.ForwardGain > 8 and scored.Kind ~= "Back" and scored.Score > -8 and (scored.Safe or scored.ForwardGain > 22) and (not progressive or scored.Score > progressive.Score) then\n\t\t\t\t\tprogressive = scored\n\t\t\t\tend',
        '\t\t\t\tif scored.LaneClear and scored.ForwardGain > 8 and scored.Kind ~= "Back" and scored.Score > -8 and (scored.Safe or scored.ForwardGain > 22) and (not progressive or scored.Score > progressive.Score) then\n\t\t\t\t\tprogressive = scored\n\t\t\t\tend\n\t\t\t\tif scored.LaneClear and scored.Kind == "Side" and scored.Score > -12 and (scored.Safe or scored.Distance <= 70) and (not sideways or scored.Score > sideways.Score) then\n\t\t\t\t\tsideways = scored\n\t\t\t\tend',
        "sideways candidate"
    )

if "sideways and (not best or best.Kind == \"Back\"" not in passing:
    passing = replace_once(
        passing,
        '\tif passerPressure.Heavy or passerPressure.Under then\n\t\tif progressive then\n\t\t\treturn progressive\n\t\tend',
        '\tif passerPressure.Heavy or passerPressure.Under then\n\t\tif progressive then\n\t\t\treturn progressive\n\t\tend\n\t\tif sideways and (not best or best.Kind == "Back" or sideways.Score >= best.Score - 18) then\n\t\t\treturn sideways\n\t\tend',
        "sideways pressure return"
    )

passing_path.write_text(passing, encoding="utf-8", newline="\n")

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

brain = regex_once(
    brain,
    r'local holdLimit = pressure\.Under and \([^)]+\) or \([^)]+\)',
    'local holdLimit = pressure.Under and (0.38 - passTempo * 0.2) or (1.05 - passTempo * 0.52 - firstTouchDirectness * 0.22)',
    "hold limit"
)

brain = regex_once(
    brain,
    r'self\.NextDecision\[carrier\.Model\] = now \+ math\.max\([^)]+\)\)',
    'self.NextDecision[carrier.Model] = now + math.max(0.025, math.min(AIDifficultyService.NextDecisionDelay(self.Difficulty) * (0.46 - passTempo * 0.24), holdLimit * 0.42))',
    "next decision"
)

brain = replace_once(
    brain,
    '\tlocal forcedSafe = wingerEndLine or (defensiveMood ~= "AggressiveRisk" and (pressure.Heavy or pressure.Under or carriedFor >= holdLimit * 0.65 or self.Style:Risk() < 0.38))',
    '\tlocal forcedSafe = wingerEndLine or (defensiveMood ~= "AggressiveRisk" and (pressure.Heavy or carriedFor >= holdLimit * 0.45 or self.Style:Risk() < 0.3))',
    "forced safe"
)

brain = regex_once(
    brain,
    r'if pass and \(forcedSafe or pass\.Kind ~= "Back" and pass\.Score > \([^)]+\) or pass\.Kind == "Back" and pass\.Score > [0-9.]+ or carriedFor > math\.max\([^)]+\)\) then',
    'if pass and (forcedSafe or pass.Kind ~= "Back" and pass.Score > (-8 - passTempo * 18) or pass.Kind == "Back" and pass.Score > 58 or carriedFor > math.max(0.025, 0.16 - passTempo * 0.1)) then',
    "pass gate"
)

old_shot = '''\tlocal closeToDanger = carrier.Pitch.Z >= 590 or PitchConfig.InZone(carrier.Pitch, "OpponentBox") or PitchConfig.InZone(carrier.Pitch, "CentralShootingZone")
\tlocal enoughBoxSpace = attackStage == "FinalChance" and PitchConfig.InZone(carrier.Pitch, "OpponentBox") and pressure.Closest > 10
\tlocal openDangerShot = closeToDanger and pressure.Closest > 10'''

new_shot = '''\tlocal dangerZone = PitchConfig.Zones.OpponentBox
\tlocal closeToDanger = carrier.Pitch.X >= dangerZone.XMin - 5 and carrier.Pitch.X <= dangerZone.XMax + 5 and carrier.Pitch.Z >= dangerZone.ZMin - 5
\tlocal enoughBoxSpace = attackStage == "FinalChance" and PitchConfig.InZone(carrier.Pitch, "OpponentBox") and pressure.Closest > 9
\tlocal openDangerShot = closeToDanger and pressure.Closest > 9'''

brain = replace_once(brain, old_shot, new_shot, "shot danger range")

brain = replace_once(
    brain,
    'carrier.Model:SetAttribute("VTROpenDangerShotChance", 0.8)',
    'carrier.Model:SetAttribute("VTROpenDangerShotChance", 0.84)',
    "open danger shot chance"
)

brain = replace_once(
    brain,
    'if (shot.Good or openDangerShot) and (openDangerShot or strikerShootBias or shot.Score > 26 or enoughBoxSpace) and (not pressure.Heavy or enoughBoxSpace or strikerShootBias or openDangerShot) then',
    'if (shot.Good or openDangerShot) and (openDangerShot or strikerShootBias or shot.Score > 22 or enoughBoxSpace) and (not pressure.Heavy or enoughBoxSpace or strikerShootBias or openDangerShot) then',
    "shot threshold"
)

brain_path.write_text(brain, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = replace_once(
    ball,
    'local finalSpeed = math.clamp(baseSpeed * consistency * (1 + variation) * throughScale, 40, PassingPower.AbsoluteMaxSpeed)',
    'local speedBias = passType == "BackPass" and 0.96 or passType == "Ground" and 1.12 or passType == "Through" and 1.1 or passType == "Lofted" and 1.06 or 1.08\n\t\tlocal finalSpeed = math.clamp(baseSpeed * consistency * (1 + variation) * throughScale * speedBias, 40, PassingPower.AbsoluteMaxSpeed)',
    "pass speed"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

print("updated faster offensive passing and closer danger shots")