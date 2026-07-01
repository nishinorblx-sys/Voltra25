from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

passing_path = Path("src/server/Gameplay/AIPassingDecisionService.lua")
passing = passing_path.read_text(encoding="utf-8")

if "local MiddleMistakeMemory" not in passing:
    passing = passing.replace(
        "local Randomizer = Random.new()",
        '''local Randomizer = Random.new()
local MiddleMistakeMemory = {Home = 0, Away = 0}

local function isCentralLaneX(x: number): boolean
\treturn x >= 112 and x <= 312
end

local function isWingLaneX(x: number): boolean
\treturn x <= 104 or x >= 320
end

local function memoryForSide(side: string): number
\treturn math.clamp(MiddleMistakeMemory[side] or 0, 0, 1)
end

local function setMemory(side: string, value: number)
\tif side == "Home" or side == "Away" then
\t\tMiddleMistakeMemory[side] = math.clamp(value, 0, 1)
\tend
end

function Service.GetMiddleMistakeMemory(side: string): number
\treturn memoryForSide(side)
end

function Service.RecordPassOutcome(passer: Model?, receiver: Model?, success: boolean)
\tif not passer then return end
\tlocal side = tostring(passer:GetAttribute("VTRTeam") or "")
\tif side ~= "Home" and side ~= "Away" then return end
\tlocal memory = memoryForSide(side)
\tlocal central = passer:GetAttribute("AIPassCentralLane") == true
\tlocal outnumbered = passer:GetAttribute("AIPassMiddleOutnumbered") == true
\tlocal wing = passer:GetAttribute("AIPassWingEscape") == true
\tif central and outnumbered and not success then
\t\tmemory += 0.34
\telseif central and not success then
\t\tmemory += 0.18
\telseif wing and success then
\t\tmemory -= 0.18
\telseif success then
\t\tmemory -= 0.04
\tend
\tsetMemory(side, memory)
\tpasser:SetAttribute("AIMiddlePassMistakeMemory", memoryForSide(side))
\tpasser:SetAttribute("AILastPassLearnedWide", wing and success)
end''',
        1
    )

if "local function centralOutnumberedAround" not in passing:
    passing = passing.replace(
        '''local function sameSide(a: any, b: any): boolean
\treturn (a.Pitch.X < PitchConfig.HALF_WIDTH and b.Pitch.X < PitchConfig.HALF_WIDTH)
\t\tor (a.Pitch.X > PitchConfig.HALF_WIDTH and b.Pitch.X > PitchConfig.HALF_WIDTH)
end''',
        '''local function sameSide(a: any, b: any): boolean
\treturn (a.Pitch.X < PitchConfig.HALF_WIDTH and b.Pitch.X < PitchConfig.HALF_WIDTH)
\t\tor (a.Pitch.X > PitchConfig.HALF_WIDTH and b.Pitch.X > PitchConfig.HALF_WIDTH)
end

local function centralOutnumberedAround(context: any, passer: any, targetZ: number?): boolean
\tlocal zCenter = targetZ or passer.Pitch.Z
\tlocal zMin = math.min(passer.Pitch.Z, zCenter) - 36
\tlocal zMax = math.max(passer.Pitch.Z, zCenter) + 42
\tlocal teammates = 0
\tlocal opponents = 0
\tfor _, info in ipairs(context.Teams[passer.Side].List) do
\t\tif info.Root and not info.IsGoalkeeper and isCentralLaneX(info.Pitch.X) and info.Pitch.Z >= zMin and info.Pitch.Z <= zMax then
\t\t\tteammates += 1
\t\tend
\tend
\tfor _, info in ipairs(context.Teams[passer.OpponentSide].List) do
\t\tif info.Root and not info.IsGoalkeeper and isCentralLaneX(info.Pitch.X) and info.Pitch.Z >= zMin and info.Pitch.Z <= zMax then
\t\t\topponents += 1
\t\tend
\tend
\treturn opponents >= teammates + 1 and opponents >= 2
end''',
        1
    )

passing = replace_once(
    passing,
    '''\tlocal pressure = AIContextBuilder.Pressure(context, receiver)
\tlocal safe = (open or veryOpen) and laneClear and laneRisk < 0.46 and distance < 115 and not (pressure.Under and kind == "Back")
\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)''',
    '''\tlocal pressure = AIContextBuilder.Pressure(context, receiver)
\tlocal safe = (open or veryOpen) and laneClear and laneRisk < 0.46 and distance < 115 and not (pressure.Under and kind == "Back")
\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)
\tlocal sideMemory = memoryForSide(passer.Side)
\tlocal centralPass = isCentralLaneX(passer.Pitch.X) and isCentralLaneX(receiver.Pitch.X)
\tlocal receiverWide = isWingLaneX(receiver.Pitch.X) or receiver.Role == "Winger" or receiver.Role == "Fullback"
\tlocal centralTrap = isCentralLaneX(passer.Pitch.X) and centralOutnumberedAround(context, passer, receiver.Pitch.Z)
\tlocal middleOutnumbered = centralPass and centralOutnumberedAround(context, passer, receiver.Pitch.Z)''',
    "central trap variables"
)

if "score -= 42 + sideMemory * 76" not in passing:
    passing = passing.replace(
        '''\tscore += routeBias(stage, mood, receiver, kind, forwardGain)''',
        '''\tscore += routeBias(stage, mood, receiver, kind, forwardGain)
\tif middleOutnumbered then
\t\tscore -= 42 + sideMemory * 76
\telseif centralPass and sideMemory > 0.12 then
\t\tscore -= sideMemory * (kind == "Forward" and 52 or 34)
\tend
\tif receiverWide and (centralTrap or sideMemory >= 0.22) then
\t\tscore += 26 + sideMemory * 70
\t\tif kind == "Side" then
\t\t\tscore += 18
\t\tend
\t\tif receiver.Role == "Winger" then
\t\t\tscore += 18
\t\telseif receiver.Role == "Fullback" then
\t\t\tscore += 10
\t\tend
\tend''',
        1
    )

passing = replace_once(
    passing,
    '''\t\tDefensiveMood = mood,
\t}''',
    '''\t\tDefensiveMood = mood,
\t\tMiddlePass = centralPass,
\t\tMiddleOutnumbered = middleOutnumbered,
\t\tWingEscape = receiverWide and (centralTrap or sideMemory >= 0.22),
\t}''',
    "pass result learning fields"
)

passing = replace_once(
    passing,
    '''\tlocal progressive = nil
\tlocal sideways = nil''',
    '''\tlocal progressive = nil
\tlocal sideways = nil
\tlocal wingEscape = nil''',
    "wing escape local"
)

passing = replace_once(
    passing,
    '''\t\t\t\tif scored.LaneClear and scored.Kind == "Side" and scored.Score > -12 and (scored.Safe or scored.Distance <= 70) and (not sideways or scored.Score > sideways.Score) then
\t\t\t\t\tsideways = scored
\t\t\t\tend''',
    '''\t\t\t\tif scored.LaneClear and scored.Kind == "Side" and scored.Score > -12 and (scored.Safe or scored.Distance <= 70) and (not sideways or scored.Score > sideways.Score) then
\t\t\t\t\tsideways = scored
\t\t\t\tend
\t\t\t\tif scored.LaneClear and scored.WingEscape and scored.Score > -20 and (not wingEscape or scored.Score > wingEscape.Score) then
\t\t\t\t\twingEscape = scored
\t\t\t\tend''',
    "track wing escape"
)

passing = replace_once(
    passing,
    '''\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)
\tif passerPressure.Heavy or passerPressure.Under then''',
    '''\tlocal passerPressure = AIContextBuilder.Pressure(context, passer)
\tlocal sideMemory = memoryForSide(passer.Side)
\tlocal centralTrap = isCentralLaneX(passer.Pitch.X) and centralOutnumberedAround(context, passer, passer.Pitch.Z + 36)
\tif wingEscape and (centralTrap or sideMemory >= 0.34) then
\t\tif not best or best.MiddlePass or wingEscape.Score >= best.Score - (26 + sideMemory * 44) then
\t\t\treturn wingEscape
\t\tend
\tend
\tif passerPressure.Heavy or passerPressure.Under then''',
    "prefer wing learned escape"
)

passing_path.write_text(passing, encoding="utf-8", newline="\n")

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

brain = replace_once(
    brain,
    '''\tlocal passKind = pass.PassKind == "Through" and "Through" or (pass.PassKind == "Lofted" or pass.PassKind == "FarPostCross") and "Lofted" or "Ground"
\tlocal power = math.clamp((pass.Distance or direction.Magnitude) / (passKind == "Through" and 145 or passKind == "Lofted" and 130 or 110), passKind == "Lofted" and 0.32 or 0.12, passKind == "Through" and 0.46 or passKind == "Lofted" and 0.68 or 0.78)
\tlocal kicked = self.BallService:Kick(passer.Model, "Pass", direction, power, pass.Receiver.Model, passKind, pass.Distance or direction.Magnitude, pass.Target)''',
    '''\tlocal passKind = pass.PassKind == "Through" and "Through" or (pass.PassKind == "Lofted" or pass.PassKind == "FarPostCross") and "Lofted" or "Ground"
\tlocal power = math.clamp((pass.Distance or direction.Magnitude) / (passKind == "Through" and 145 or passKind == "Lofted" and 130 or 110), passKind == "Lofted" and 0.32 or 0.12, passKind == "Through" and 0.46 or passKind == "Lofted" and 0.68 or 0.78)
\tpasser.Model:SetAttribute("AIPassCentralLane", pass.MiddlePass == true)
\tpasser.Model:SetAttribute("AIPassMiddleOutnumbered", pass.MiddleOutnumbered == true)
\tpasser.Model:SetAttribute("AIPassWingEscape", pass.WingEscape == true)
\tpasser.Model:SetAttribute("AIPassMiddleMemory", AIPassingDecisionService.GetMiddleMistakeMemory and AIPassingDecisionService.GetMiddleMistakeMemory(passer.Side) or 0)
\tlocal kicked = self.BallService:Kick(passer.Model, "Pass", direction, power, pass.Receiver.Model, passKind, pass.Distance or direction.Magnitude, pass.Target)''',
    "set learning attrs before pass"
)

brain_path.write_text(brain, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

if 'local AIPassingDecisionService = require(script.Parent.AIPassingDecisionService)' not in ball:
    ball = ball.replace(
        'local FreeKickTrajectory = require(ReplicatedStorage.VTR.Shared.FreeKickTrajectory)',
        'local FreeKickTrajectory = require(ReplicatedStorage.VTR.Shared.FreeKickTrajectory)\nlocal AIPassingDecisionService = require(script.Parent.AIPassingDecisionService)',
        1
    )

ball = replace_once(
    ball,
    '''\t\tif self.LastPassTeam then
\t\t\tif self.LastPassTeam==team and self.LastPasser then self.Stats:RecordPassCompleted(self.LastPasser,nearest,self.LastPassOrigin,self.Ball.Position)
\t\t\telseif self.LastPasser then self.Stats:RecordPassFailed(self.LastPasser,nearest)end
\t\tend''',
    '''\t\tif self.LastPassTeam then
\t\t\tif self.LastPassTeam==team and self.LastPasser then
\t\t\t\tself.Stats:RecordPassCompleted(self.LastPasser,nearest,self.LastPassOrigin,self.Ball.Position)
\t\t\t\tif AIPassingDecisionService.RecordPassOutcome then AIPassingDecisionService.RecordPassOutcome(self.LastPasser,nearest,true) end
\t\t\telseif self.LastPasser then
\t\t\t\tself.Stats:RecordPassFailed(self.LastPasser,nearest)
\t\t\t\tif AIPassingDecisionService.RecordPassOutcome then AIPassingDecisionService.RecordPassOutcome(self.LastPasser,nearest,false) end
\t\t\tend
\t\tend''',
    "record pass learning outcome"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

print("added middle pass mistake learning and wing escape preference")