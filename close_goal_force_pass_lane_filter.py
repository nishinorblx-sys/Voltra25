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

brain = replace_once(
    brain,
    'local runningIntoSpaceDanger = (carrier.Model:GetAttribute("AICarryIntoSpace") == true or self.LastAction[carrier.Model] == "CarryForwardSpace" or self.LastAction[carrier.Model] == "TakeOnPressForward") and pressure.Closest <= 10',
    'local runningIntoSpaceDanger = pressure.Closest <= 25 or ((carrier.Model:GetAttribute("AICarryIntoSpace") == true or self.LastAction[carrier.Model] == "CarryForwardSpace" or self.LastAction[carrier.Model] == "TakeOnPressForward") and pressure.Closest <= 25)',
    "25 stud force pass"
)

brain = replace_once(
    brain,
    'carrier.Model:SetAttribute("AIRunningIntoSpaceDanger", runningIntoSpaceDanger)',
    'carrier.Model:SetAttribute("AIRunningIntoSpaceDanger", runningIntoSpaceDanger)\n\tcarrier.Model:SetAttribute("AIForcePassPressure25", pressure.Closest <= 25)',
    "25 stud attribute"
)

brain_path.write_text(brain, encoding="utf-8", newline="\n")

passing_path = Path("src/server/Gameplay/AIPassingDecisionService.lua")
passing = passing_path.read_text(encoding="utf-8")

passing = passing.replace("scoredKind", "kind")
passing = passing.replace("score += open or veryOpen and 20 or 8", "score += (open or veryOpen) and 20 or 8")
passing = passing.replace("score += laneClear and (open or veryOpen) and 24 or 0", "score += (laneClear and (open or veryOpen)) and 24 or 0")

lane_helper = '''local function flatPass(vector: Vector3): Vector3
\treturn Vector3.new(vector.X, 0, vector.Z)
end

local function laneInterceptionRisk(context: any, passer: any, target: Vector3, passKind: string): number
\tif passKind == "Lofted" or passKind == "FarPostCross" or passKind == "LowCross" then
\t\treturn 0
\tend
\tlocal start = passer.World
\tlocal segment = flatPass(target - start)
\tlocal length = segment.Magnitude
\tif length < 8 then
\t\treturn 0
\tend
\tlocal direction = segment.Unit
\tlocal risk = 0
\tfor _, defender in ipairs(context.Teams[passer.OpponentSide].List) do
\t\tif defender.Root and not defender.IsGoalkeeper then
\t\t\tlocal defenderOffset = flatPass(defender.World - start)
\t\t\tlocal along = defenderOffset:Dot(direction)
\t\t\tif along > 6 and along < length - 4 then
\t\t\t\tlocal closest = start + direction * along
\t\t\t\tlocal lateral = PitchConfig.GetDistanceStuds(defender.World, closest)
\t\t\t\tlocal pace = defender.Stats and defender.Stats.pace or 60
\t\t\t\tlocal interceptions = defender.Stats and defender.Stats.interceptions or defender.Stats and defender.Stats.defending or 60
\t\t\t\tlocal reach = 7.5 + math.clamp((pace - 55) * 0.045, -1.2, 2.2) + math.clamp((interceptions - 55) * 0.07, -1.4, 3)
\t\t\t\tif passKind == "Through" then
\t\t\t\t\treach += 2
\t\t\t\tend
\t\t\t\tif lateral <= reach + 4 then
\t\t\t\t\tlocal laneCut = math.clamp((reach + 4 - lateral) / (reach + 4), 0, 1)
\t\t\t\t\tlocal defenderQuality = math.clamp((pace * 0.45 + interceptions * 0.55) / 100, 0.35, 1)
\t\t\t\t\tlocal centrality = 1 - math.abs((along / length) - 0.5) * 0.5
\t\t\t\t\trisk = math.max(risk, laneCut * defenderQuality * centrality)
\t\t\t\tend
\t\t\tend
\t\tend
\tend
\treturn math.clamp(risk, 0, 1)
end

'''

if "local function laneInterceptionRisk" not in passing:
    marker = "local function passTarget(context: any, passer: any, receiver: any, kind: string): Vector3"
    if marker not in passing:
        raise RuntimeError("Could not find passTarget")
    passing = passing.replace(marker, lane_helper + marker, 1)

old_lane = '''\tlocal laneClear = targetKind == "Lofted" and AIContextBuilder.PassingLaneClear(context, passer, target, "Lobbed") or AIContextBuilder.PassingLaneClear(context, passer, target, targetKind == "Through" and "Driven" or "Ground")
\tlocal pressure = AIContextBuilder.Pressure(context, receiver)
\tlocal safe = (open or veryOpen) and laneClear and distance < 115 and not (pressure.Under and kind == "Back")
\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)'''

new_lane = '''\tlocal laneClear = targetKind == "Lofted" and AIContextBuilder.PassingLaneClear(context, passer, target, "Lobbed") or AIContextBuilder.PassingLaneClear(context, passer, target, targetKind == "Through" and "Driven" or "Ground")
\tlocal laneRisk = laneInterceptionRisk(context, passer, target, targetKind)
\tif laneRisk >= 0.54 and targetKind ~= "Lofted" then
\t\tif Randomizer:NextNumber() < 0.2 and distance >= 24 and forwardGain >= -8 then
\t\t\ttargetKind = "Lofted"
\t\t\ttarget = passTarget(context, passer, receiver, targetKind)
\t\t\tlaneClear = AIContextBuilder.PassingLaneClear(context, passer, target, "Lobbed")
\t\t\tlaneRisk = laneInterceptionRisk(context, passer, target, targetKind)
\t\telse
\t\t\tlaneClear = false
\t\tend
\tend
\tlocal pressure = AIContextBuilder.Pressure(context, receiver)
\tlocal safe = (open or veryOpen) and laneClear and laneRisk < 0.46 and distance < 115 and not (pressure.Under and kind == "Back")
\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)'''

passing = replace_once(passing, old_lane, new_lane, "lane interception filter")

if "score -= laneRisk * 96" not in passing:
    passing = replace_once(
        passing,
        '\tscore += difficulty.PassRisk * 10',
        '\tscore -= laneRisk * 96\n\tif laneRisk >= 0.54 then\n\t\tscore -= 42\n\telseif laneRisk >= 0.36 then\n\t\tscore -= 20\n\tend\n\tif targetKind == "Lofted" and laneRisk < 0.26 and forwardGain >= -4 then\n\t\tscore += 10\n\tend\n\tscore += difficulty.PassRisk * 10',
        "lane risk scoring"
    )

passing = replace_once(
    passing,
    '\t\tLaneClear = laneClear,',
    '\t\tLaneClear = laneClear,\n\t\tLaneRisk = laneRisk,',
    "lane risk result"
)

passing_path.write_text(passing, encoding="utf-8", newline="\n")

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

gk = regex_once(
    gk,
    r'local function saveProbability\(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number\?,shooter:Model\?\):number.*?end\n\nfunction Service.new',
    '''local function saveProbability(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number?,shooter:Model?):number
\tlocal rating=keeperRating(keeper)
\tlocal shooterStat=shooterRating(shooter)
\tlocal shooterRoot = root(shooter)
\tif shooterRoot and PitchConfig.GetDistanceStuds(shooterRoot.Position, target) <= 70 then
\t\tlocal goalChance = math.clamp(0.95 + (shooterStat - rating) / 160, 0.65, 0.99)
\t\treturn 1 - goalChance
\tend
\tif shooter and (tonumber(shooter:GetAttribute("VTRLongShotChanceUntil")) or 0) >= os.clock() then
\t\tlocal goalChance = tonumber(shooter:GetAttribute("VTRLongShotGoalChance")) or 0.18
\t\tgoalChance = math.clamp(goalChance + (shooterStat - rating) / 140, 0.08, 0.38)
\t\treturn 1 - goalChance
\tend
\tif shooter and (tonumber(shooter:GetAttribute("VTROpenDangerShotChanceUntil")) or 0) >= os.clock() then
\t\tlocal baseGoalChance = tonumber(shooter:GetAttribute("VTROpenDangerShotChance")) or 0.9
\t\tlocal goalChance = math.clamp(baseGoalChance + (shooterStat - rating) / 120, 0.22, 0.97)
\t\treturn 1 - goalChance
\tend
\tlocal shotXG = xg or 0
\tlocal baseGoalChance = shotXG >= 0.18 and 0.72 or shotXG >= 0.1 and 0.64 or 0.56
\tlocal goalChance=math.clamp(baseGoalChance+(shooterStat-rating)/120,.18,.92)
\treturn 1-goalChance
end

function Service.new''',
    "70 stud 95 percent shot chance"
)

if 'local PitchConfig = require(script.Parent.PitchConfig)' not in gk:
    gk = gk.replace(
        'local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)',
        'local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)\nlocal PitchConfig = require(script.Parent.PitchConfig)',
        1
    )

gk_path.write_text(gk, encoding="utf-8", newline="\n")

print("updated 70 stud scoring, 25 stud forced passing, and lane interception filtering")