from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

passing_path = Path("src/server/Gameplay/AIPassingDecisionService.lua")
passing = passing_path.read_text(encoding="utf-8")

passing = passing.replace("scoredKind ==", "kind ==")

anchor = '''\tscore += routeBias(stage, mood, receiver, kind, forwardGain)
\tif trailingCover and kind == "Back" then'''

insert = '''\tscore += routeBias(stage, mood, receiver, kind, forwardGain)
\tif kind == "Back" then
\t\tlocal backPenalty = passer.Pitch.Z >= PitchConfig.HALF_LENGTH and 42 or 24
\t\tif passerPressure.Heavy then
\t\t\tbackPenalty -= 12
\t\telseif not passerPressure.Under then
\t\t\tbackPenalty += 10
\t\tend
\t\tif forwardGain < -48 then
\t\t\tbackPenalty += 18
\t\tend
\t\tscore -= backPenalty
\telseif forwardGain > 6 then
\t\tscore += math.clamp(forwardGain, 0, 58) * 0.42
\t\tif passerPressure.Under or passerPressure.Heavy then
\t\t\tscore += laneClear and (open or veryOpen) and 24 or 0
\t\tend
\telseif kind == "Side" and (passerPressure.Under or passerPressure.Heavy) and laneClear and (open or veryOpen) then
\t\tscore += 18
\tend
\tif trailingCover and kind == "Back" then'''

if "local backPenalty = passer.Pitch.Z >= PitchConfig.HALF_LENGTH" not in passing:
    passing = replace_once(passing, anchor, insert, "progressive pass scoring")

passing = replace_once(
    passing,
    '\tlocal alternate = nil\n\tfor _, receiver in ipairs(context.Teams[passer.Side].List) do',
    '\tlocal alternate = nil\n\tlocal progressive = nil\n\tfor _, receiver in ipairs(context.Teams[passer.Side].List) do',
    "progressive local"
)

anchor2 = '''\t\t\t\tif scored.LaneClear and scored.Score > 2 and (not forcedSafe or scored.Safe) and (not best or scored.Score > best.Score) then
\t\t\t\t\tbest = scored
\t\t\t\tend'''

insert2 = '''\t\t\t\tif scored.LaneClear and scored.ForwardGain > 8 and scored.Kind ~= "Back" and scored.Score > -8 and (scored.Safe or scored.ForwardGain > 22) and (not progressive or scored.Score > progressive.Score) then
\t\t\t\t\tprogressive = scored
\t\t\t\tend
\t\t\t\tif scored.LaneClear and scored.Score > 2 and (not forcedSafe or scored.Safe) and (not best or scored.Score > best.Score) then
\t\t\t\t\tbest = scored
\t\t\t\tend'''

if "local progressive = nil" in passing and "progressive = scored" not in passing:
    passing = replace_once(passing, anchor2, insert2, "progressive candidate")

anchor3 = '''\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)
\tif trailing and alternate and passerPressure.Under and math.abs(trailing.Score - alternate.Score) <= 18 then
\t\treturn Randomizer:NextNumber() < 0.5 and trailing or alternate
\tend
\treturn best or bestSafe or fallback'''

insert3 = '''\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)
\tif passerPressure.Heavy or passerPressure.Under then
\t\tif progressive then
\t\t\treturn progressive
\t\tend
\t\tif best and best.Kind ~= "Back" then
\t\t\treturn best
\t\tend
\t\tif passer.Pitch.Z >= PitchConfig.HALF_LENGTH and not passerPressure.Heavy then
\t\t\tif alternate and alternate.Kind ~= "Back" then
\t\t\t\treturn alternate
\t\t\tend
\t\t\treturn nil
\t\tend
\tend
\tif passer.Pitch.Z >= PitchConfig.HALF_LENGTH and best and best.Kind == "Back" and alternate and alternate.Kind ~= "Back" then
\t\treturn alternate
\tend
\tif trailing and alternate and passerPressure.Under and math.abs(trailing.Score - alternate.Score) <= 18 then
\t\treturn alternate.Kind ~= "Back" and alternate or trailing
\tend
\treturn best or bestSafe or fallback'''

if "passer.Pitch.Z >= PitchConfig.HALF_LENGTH and not passerPressure.Heavy" not in passing:
    passing = replace_once(passing, anchor3, insert3, "pressure choose progressive")

passing_path.write_text(passing, encoding="utf-8", newline="\n")

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

anchor4 = '''\tlocal pass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, forcedSafe)
\tcarrier.Model:SetAttribute("AIForcedSafe", forcedSafe)'''

insert4 = '''\tlocal pass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, forcedSafe)
\tlocal inOpponentHalf = carrier.Pitch.Z >= PitchConfig.HALF_LENGTH
\tlocal passIsBackwards = pass ~= nil and pass.Kind == "Back" and (pass.ForwardGain or 0) < -8
\tlocal forwardCarryPitch = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X, 3, carrier.Pitch.Z + (attackStage == "FinalChance" and 18 or 38)))
\tlocal forwardSpace = AIContextBuilder.SpaceAt(context, carrier.Side, forwardCarryPitch, pressure.Under and 16 or 22)
\tlocal takeOnPress = inOpponentHalf and passIsBackwards and forwardSpace and not pressure.Heavy
\tif takeOnPress then
\t\tpass = nil
\t\tforcedSafe = false
\t\tcarrier.Model:SetAttribute("AIAvoidBackPass", true)
\telse
\t\tcarrier.Model:SetAttribute("AIAvoidBackPass", false)
\tend
\tcarrier.Model:SetAttribute("AIForwardSpace", forwardSpace)
\tcarrier.Model:SetAttribute("AIForcedSafe", forcedSafe)'''

if "local takeOnPress = inOpponentHalf and passIsBackwards" not in brain:
    brain = replace_once(brain, anchor4, insert4, "brain forward space vars")

old_pass_gate = '''\tif pass and (forcedSafe or pass.Score > (8 - passTempo * 20) or carriedFor > math.max(0.06, 0.28 - passTempo * 0.18)) then'''
new_pass_gate = '''\tif pass and (forcedSafe or pass.Kind ~= "Back" and pass.Score > (2 - passTempo * 22) or pass.Kind == "Back" and pass.Score > 36 or carriedFor > math.max(0.05, 0.24 - passTempo * 0.16)) then'''

if old_pass_gate in brain:
    brain = brain.replace(old_pass_gate, new_pass_gate, 1)
else:
    brain = brain.replace(
        '\tif pass and (forcedSafe or pass.Score > (18 - passTempo * 16) or carriedFor > math.max(0.14, 0.46 - passTempo * 0.28)) then',
        new_pass_gate,
        1
    )

anchor5 = '''\tlocal dribble = AIDribblingDecisionService.Evaluate(context, carrier, self.Style)
\tcarrier.Model:SetAttribute("AIDribbleScore", dribble.Score)'''

insert5 = '''\tif forwardSpace and (pressure.None or takeOnPress or (inOpponentHalf and pressure.Under and not pass)) then
\t\tlocal target = PitchConfig.TeamPitchPositionToWorld(forwardCarryPitch, carrier.Side, context.Options)
\t\tassignment.TargetWorld = target
\t\tassignment.MovementTarget = target
\t\tassignment.PrimaryAssignment = takeOnPress and "TakeOnPressForward" or "CarryForwardSpace"
\t\tassignment.MovementUrgency = 1
\t\tassignment.SprintAllowed = true
\t\tself.LastAction[carrier.Model] = assignment.PrimaryAssignment
\t\treturn
\tend

\tlocal dribble = AIDribblingDecisionService.Evaluate(context, carrier, self.Style)
\tcarrier.Model:SetAttribute("AIDribbleScore", dribble.Score)'''

if "TakeOnPressForward" not in brain:
    brain = replace_once(brain, anchor5, insert5, "forward carry before dribble")

old_threshold = '''\tlocal dribbleThreshold = defensiveMood == "AggressiveRisk" and -6 or defensiveMood == "Pressing" and 3 or pressure.Heavy and 22 or 5'''
new_threshold = '''\tlocal dribbleThreshold = takeOnPress and -12 or defensiveMood == "AggressiveRisk" and -6 or defensiveMood == "Pressing" and 3 or pressure.Heavy and 22 or 5'''

brain = replace_once(brain, old_threshold, new_threshold, "dribble threshold take on")

brain_path.write_text(brain, encoding="utf-8", newline="\n")

print("updated progression pressure and back pass behavior")