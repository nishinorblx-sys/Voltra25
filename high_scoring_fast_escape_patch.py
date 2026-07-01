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

old = '''\tlocal forcedSafe = wingerEndLine or (defensiveMood ~= "AggressiveRisk" and (pressure.Heavy or carriedFor >= holdLimit * 0.45 or self.Style:Risk() < 0.3))
\tlocal pass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, forcedSafe)'''

new = '''\tlocal runningIntoSpaceDanger = (carrier.Model:GetAttribute("AICarryIntoSpace") == true or self.LastAction[carrier.Model] == "CarryForwardSpace" or self.LastAction[carrier.Model] == "TakeOnPressForward") and pressure.Closest <= 10
\tlocal forcedSafe = wingerEndLine or runningIntoSpaceDanger or (defensiveMood ~= "AggressiveRisk" and (pressure.Heavy or carriedFor >= holdLimit * 0.45 or self.Style:Risk() < 0.3))
\tlocal pass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, forcedSafe)'''

brain = replace_once(brain, old, new, "running into space force pass")

old2 = '''\tcarrier.Model:SetAttribute("AIForcedSafe", forcedSafe)
\tcarrier.Model:SetAttribute("AIPassScore", pass and pass.Score or -999)'''

new2 = '''\tcarrier.Model:SetAttribute("AIRunningIntoSpaceDanger", runningIntoSpaceDanger)
\tcarrier.Model:SetAttribute("AIForcedSafe", forcedSafe)
\tcarrier.Model:SetAttribute("AIPassScore", pass and pass.Score or -999)'''

brain = replace_once(brain, old2, new2, "running danger attribute")

old3 = '''\tif pass and (forcedSafe or pass.Kind ~= "Back" and pass.Score > (-8 - passTempo * 18) or pass.Kind == "Back" and pass.Score > 58 or carriedFor > math.max(0.025, 0.16 - passTempo * 0.1)) then'''

new3 = '''\tif pass and (runningIntoSpaceDanger or forcedSafe or pass.Kind ~= "Back" and pass.Score > (-8 - passTempo * 18) or pass.Kind == "Back" and pass.Score > 58 or carriedFor > math.max(0.025, 0.16 - passTempo * 0.1)) then'''

brain = replace_once(brain, old3, new3, "force pass gate")

old4 = '''\tif forwardSpace and (pressure.None or takeOnPress or (inOpponentHalf and pressure.Under and not pass)) then'''

new4 = '''\tif forwardSpace and not runningIntoSpaceDanger and (pressure.None or takeOnPress or (inOpponentHalf and pressure.Under and not pass)) then'''

brain = replace_once(brain, old4, new4, "stop carrying into 10 stud pressure")

brain_path.write_text(brain, encoding="utf-8", newline="\n")

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

gk = regex_once(
    gk,
    r'local function saveProbability\(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number\?,shooter:Model\?\):number.*?end\n\nfunction Service.new',
    '''local function saveProbability(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number?,shooter:Model?):number
\tlocal rating=keeperRating(keeper)
\tlocal shooterStat=shooterRating(shooter)
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
    "save probability high scoring"
)

gk_path.write_text(gk, encoding="utf-8", newline="\n")

print("updated forced escape passing and high scoring goalkeeper tuning")