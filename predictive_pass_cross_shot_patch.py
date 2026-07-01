from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

assignment_path = Path("src/server/Gameplay/AIAssignmentService.lua")
assignment = assignment_path.read_text(encoding="utf-8")

incoming_helpers = '''local function incomingPassThreat(context: any, defendingSide: string): (any?, Vector3?)
\tlocal ball = context.Ball
\tif not ball then
\t\treturn nil, nil
\tend
\tlocal passTeam = tostring(ball:GetAttribute("VTRPassTeam") or ball:GetAttribute("LastTouchTeam") or "")
\tif passTeam == "" or passTeam == defendingSide then
\t\treturn nil, nil
\tend
\tlocal receiverName = tostring(ball:GetAttribute("VTRPassReceiver") or "")
\tlocal target = ball:GetAttribute("VTRPassTarget") or ball:GetAttribute("VTRLobTarget")
\tif receiverName == "" then
\t\treturn nil, typeof(target) == "Vector3" and PitchConfig.WorldToTeamPitchPosition(target, defendingSide, context.Options) or nil
\tend
\tlocal attackingSide = defendingSide == "Home" and "Away" or "Home"
\tfor _, attacker in ipairs(context.Teams[attackingSide].List) do
\t\tif attacker.Model.Name == receiverName then
\t\t\tlocal pitchTarget = typeof(target) == "Vector3" and PitchConfig.WorldToTeamPitchPosition(target, defendingSide, context.Options) or PitchConfig.WorldToTeamPitchPosition(attacker.World, defendingSide, context.Options)
\t\t\treturn attacker, pitchTarget
\t\tend
\tend
\treturn nil, typeof(target) == "Vector3" and PitchConfig.WorldToTeamPitchPosition(target, defendingSide, context.Options) or nil
end

local function incomingPressRank(context: any, info: any, targetPitch: Vector3, roles: {[string]: boolean}): number
\tlocal rank = 1
\tlocal targetWorld = PitchConfig.TeamPitchPositionToWorld(targetPitch, info.Side, context.Options)
\tlocal distance = PitchConfig.GetDistanceStuds(info.World, targetWorld)
\tfor _, teammate in ipairs(context.Teams[info.Side].List) do
\t\tif teammate.Model ~= info.Model and teammate.Root and roles[teammate.Role] == true then
\t\t\tlocal teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, targetWorld)
\t\t\tif teammateDistance < distance then
\t\t\t\trank += 1
\t\t\tend
\t\tend
\tend
\treturn rank
end

'''

if "local function incomingPassThreat" not in assignment:
    marker = "local function simpleDefensiveRoleTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean, Model?)"
    if marker not in assignment:
        raise RuntimeError("Could not find simpleDefensiveRoleTarget")
    assignment = assignment.replace(marker, incoming_helpers + marker, 1)

anchor = '''\tif shadow and shadow.Target and context.Players[shadow.Target] then
\t\tlocal oldInfo = context.Players[shadow.Target]
\t\tlocal oldPitch = PitchConfig.WorldToTeamPitchPosition(oldInfo.World, info.Side, context.Options)
\t\tlocal sideOffset = info.Pitch.X < oldPitch.X and -10 or 10
\t\tlocal target = Vector3.new(
\t\t\tmath.clamp(oldPitch.X + sideOffset, 0, PitchConfig.PITCH_WIDTH),
\t\t\t3,
\t\t\tmath.clamp(oldPitch.Z - 8, 34, 520)
\t\t)
\t\treturn "PostPressShadow", target, 0.86, true, oldInfo.Model
\tend'''

insert = '''\tif shadow and shadow.Target and context.Players[shadow.Target] then
\t\tlocal oldInfo = context.Players[shadow.Target]
\t\tlocal oldPitch = PitchConfig.WorldToTeamPitchPosition(oldInfo.World, info.Side, context.Options)
\t\tlocal sideOffset = info.Pitch.X < oldPitch.X and -10 or 10
\t\tlocal target = Vector3.new(
\t\t\tmath.clamp(oldPitch.X + sideOffset, 0, PitchConfig.PITCH_WIDTH),
\t\t\t3,
\t\t\tmath.clamp(oldPitch.Z - 8, 34, 520)
\t\t)
\t\treturn "PostPressShadow", target, 0.86, true, oldInfo.Model
\tend

\tlocal incomingReceiver, incomingTarget = incomingPassThreat(context, info.Side)
\tif incomingTarget then
\t\tlocal receiverRole = incomingReceiver and incomingReceiver.Role or ""
\t\tlocal target = PitchConfig.ClampInsidePitch(Vector3.new(incomingTarget.X, 3, incomingTarget.Z - 4))
\t\tlocal distanceToTarget = PitchConfig.GetDistanceStuds(info.World, PitchConfig.TeamPitchPositionToWorld(target, info.Side, context.Options))
\t\tif info.Role == "CB" and (receiverRole == "ST" or receiverRole == "CAM") and distanceToTarget <= 155 then
\t\t\tlocal rank = incomingPressRank(context, info, target, {CB = true})
\t\t\tif rank == 1 then
\t\t\t\treturn "EarlyCBPressPassTarget", target, 1, true, incomingReceiver and incomingReceiver.Model or nil
\t\t\tend
\t\telseif info.Role == "Fullback" and receiverRole == "Winger" and sameWideSide(info, incomingTarget) and distanceToTarget <= 145 then
\t\t\treturn "EarlyFullbackPressPassTarget", target, 1, true, incomingReceiver and incomingReceiver.Model or nil
\t\telseif (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") and (receiverRole == "CDM" or receiverRole == "CM" or receiverRole == "CAM") and distanceToTarget <= 145 then
\t\t\tlocal rank = incomingPressRank(context, info, target, {CDM = true, CM = true, CAM = true})
\t\t\tif rank == 1 then
\t\t\t\treturn "EarlyMidfielderPressPassTarget", target, 1, true, incomingReceiver and incomingReceiver.Model or nil
\t\t\telseif rank == 2 then
\t\t\t\treturn "EarlyMidfielderCoverPassTarget", AIDefensiveDecisionService.CoverPresserTarget(target), 0.94, true, incomingReceiver and incomingReceiver.Model or nil
\t\t\tend
\t\telseif distanceToTarget <= 78 and not info.IsGoalkeeper then
\t\t\treturn "EarlyClosePassTargetPressure", target, 0.96, true, incomingReceiver and incomingReceiver.Model or nil
\t\tend
\tend'''

if "EarlyCBPressPassTarget" not in assignment:
    assignment = replace_once(assignment, anchor, insert, "incoming pass pressure")

assignment_path.write_text(assignment, encoding="utf-8", newline="\n")

movement_path = Path("src/server/Gameplay/AIMovementService.lua")
movement = movement_path.read_text(encoding="utf-8")

pressure_names = [
    "EarlyCBPressPassTarget",
    "EarlyFullbackPressPassTarget",
    "EarlyMidfielderPressPassTarget",
    "EarlyMidfielderCoverPassTarget",
    "EarlyClosePassTargetPressure",
]
line_match = re.search(r'\tlocal pressureAssignment = .*?\n', movement)
if line_match:
    line = line_match.group(0).rstrip()
    for name in pressure_names:
        token = f'or assignmentName == "{name}"'
        if token not in line:
            line += f' {token}'
    movement = movement[:line_match.start()] + line + "\n" + movement[line_match.end():]

if 'or assignmentName == "EarlyMidfielderCoverPassTarget") and "Secondary"' not in movement:
    movement = movement.replace(
        '(assignmentName == "CoverPresser" or assignmentName == "AggressiveMidfieldCover" or assignmentName == "MidfielderPressureCover") and "Secondary"',
        '(assignmentName == "CoverPresser" or assignmentName == "AggressiveMidfieldCover" or assignmentName == "MidfielderPressureCover" or assignmentName == "EarlyMidfielderCoverPassTarget") and "Secondary"',
        1
    )

movement_path.write_text(movement, encoding="utf-8", newline="\n")

passing_path = Path("src/server/Gameplay/AIPassingDecisionService.lua")
passing = passing_path.read_text(encoding="utf-8")

lead_helper = '''local function leadRunTarget(context: any, passer: any, receiver: any, targetPitch: Vector3, kind: string): Vector3
\tlocal receiverRoot = receiver.Root
\tlocal runnerVelocity = receiverRoot and Vector3.new(receiverRoot.AssemblyLinearVelocity.X, 0, receiverRoot.AssemblyLinearVelocity.Z) or Vector3.zero
\tlocal forwardLead = math.clamp(receiver.Pitch.Z - passer.Pitch.Z, -8, 48) * 0.18
\tlocal velocityLead = Vector3.zero
\tif runnerVelocity.Magnitude > 1.5 then
\t\tlocal aheadWorld = receiver.World + runnerVelocity.Unit * math.clamp(runnerVelocity.Magnitude * (kind == "Through" and 0.38 or kind == "Lofted" and 0.42 or 0.28), 5, 24)
\t\tvelocityLead = PitchConfig.WorldToTeamPitchPosition(aheadWorld, passer.Side, context.Options) - receiver.Pitch
\tend
\tlocal extraForward = (receiver.Role == "Winger" or receiver.Role == "ST") and math.max(8, forwardLead) or math.max(2, forwardLead * 0.55)
\tif kind == "BackPass" then
\t\textraForward = 0
\t\tvelocityLead = Vector3.zero
\tend
\treturn PitchConfig.ClampInsidePitch(Vector3.new(targetPitch.X + velocityLead.X * 0.65, 3, math.max(targetPitch.Z, receiver.Pitch.Z + extraForward + math.max(0, velocityLead.Z * 0.65))))
end

'''

if "local function leadRunTarget" not in passing:
    passing = passing.replace("local function passTarget(context: any, passer: any, receiver: any, kind: string): Vector3", lead_helper + "local function passTarget(context: any, passer: any, receiver: any, kind: string): Vector3", 1)

passing = replace_once(
    passing,
    '''\tif kind == "Through" then
\t\tlocal defensiveLine = AIContextBuilder.DefensiveLineZ(context, passer.Side)
\t\tlocal laneX = receiver.Pitch.X
\t\tlocal receiverLead = math.clamp(receiver.Pitch.Z - passer.Pitch.Z, 12, 42) * 0.22
\t\tlocal lineLead = math.clamp(defensiveLine - receiver.Pitch.Z, -12, 28) * 0.16
\t\tlocal targetZ = receiver.Pitch.Z + math.clamp(5 + receiverLead + lineLead, 5, 16)
\t\tlocal targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(laneX, 3, math.clamp(targetZ, 0, 704)))
\t\treturn PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)
\tend
\tlocal forwardLead = math.clamp(receiver.Pitch.Z - passer.Pitch.Z, -8, 28) * 0.14
\tlocal targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(receiver.Pitch.X, 3, receiver.Pitch.Z + math.max(2, forwardLead)))
\tlocal target = PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)''',
    '''\tif kind == "Through" then
\t\tlocal defensiveLine = AIContextBuilder.DefensiveLineZ(context, passer.Side)
\t\tlocal laneX = receiver.Pitch.X
\t\tlocal receiverLead = math.clamp(receiver.Pitch.Z - passer.Pitch.Z, 12, 42) * 0.22
\t\tlocal lineLead = math.clamp(defensiveLine - receiver.Pitch.Z, -12, 28) * 0.16
\t\tlocal targetZ = receiver.Pitch.Z + math.clamp(5 + receiverLead + lineLead, 5, 16)
\t\tlocal targetPitch = leadRunTarget(context, passer, receiver, Vector3.new(laneX, 3, math.clamp(targetZ, 0, 704)), kind)
\t\treturn PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)
\tend
\tlocal targetPitch = leadRunTarget(context, passer, receiver, Vector3.new(receiver.Pitch.X, 3, receiver.Pitch.Z), kind)
\tlocal target = PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)''',
    "lead normal passes"
)

passing = replace_once(
    passing,
    'if receiver.Role == "ST" and receiver.Pitch.Z >= 585 then return "LowCross", 520 end',
    'if receiver.Role == "ST" and receiver.Pitch.Z >= 585 then return "Lofted", 610 end',
    "winger cross first st"
)

passing = replace_once(
    passing,
    'if receiver.Role == "ST" and receiver.Pitch.Z >= 590 then return "LowCross", 560 end',
    'if receiver.Role == "ST" and receiver.Pitch.Z >= 590 then return "Lofted", 640 end',
    "winger endline cross st"
)

passing_path.write_text(passing, encoding="utf-8", newline="\n")

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

cross_helper = '''local function chooseBoxCross(context: any, carrier: any): any?
\tif carrier.Role ~= "Winger" or carrier.Pitch.Z < 610 or not (carrier.Pitch.X < 105 or carrier.Pitch.X > 319) then
\t\treturn nil
\tend
\tlocal best = nil
\tlocal bestScore = -math.huge
\tfor _, receiver in ipairs(context.Teams[carrier.Side].List) do
\t\tif receiver.Model ~= carrier.Model and receiver.Root and not receiver.IsGoalkeeper and receiver.Pitch.Z >= 570 and receiver.Pitch.Z <= 690 and receiver.Pitch.X >= 118 and receiver.Pitch.X <= 306 then
\t\t\tlocal pressure = AIContextBuilder.Pressure(context, receiver)
\t\t\tlocal score = (receiver.Role == "ST" and 80 or receiver.Role == "CAM" and 64 or receiver.Role == "CM" and 48 or 34)
\t\t\tscore += receiver.Stats.finishing * 0.3 + receiver.Stats.overall * 0.12
\t\t\tscore -= pressure.Score * 18
\t\t\tif score > bestScore then
\t\t\t\tbestScore = score
\t\t\t\tbest = receiver
\t\t\tend
\t\tend
\tend
\tif not best then
\t\treturn nil
\tend
\tlocal farPostX = carrier.Pitch.X < PitchConfig.HALF_WIDTH and 284 or 140
\tlocal leadZ = math.clamp(math.max(best.Pitch.Z + 10, 622), 610, 682)
\tlocal targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(best.Pitch.X + (farPostX - best.Pitch.X) * 0.35, 3, leadZ))
\tlocal target = PitchConfig.TeamPitchPositionToWorld(targetPitch, carrier.Side, context.Options)
\treturn {
\t\tReceiver = best,
\t\tScore = bestScore + 120,
\t\tKind = "Forward",
\t\tPassKind = "Lofted",
\t\tTarget = target,
\t\tDistance = PitchConfig.GetDistanceStuds(carrier.World, target),
\t\tLaneClear = true,
\t\tSafe = true,
\t\tForwardGain = targetPitch.Z - carrier.Pitch.Z,
\t\tStage = AIContextBuilder.AttackStage(context, carrier.Side),
\t\tDefensiveMood = AIContextBuilder.DefensiveMood(context, carrier.Side, carrier),
\t}
end

'''

if "local function chooseBoxCross" not in brain:
    brain = brain.replace("function Service.new(ballService: any, style: any, difficulty: any)", cross_helper + "function Service.new(ballService: any, style: any, difficulty: any)", 1)

brain = replace_once(
    brain,
    '''\tlocal wingerPass = AIPassingDecisionService.ChooseWingerWide(context, carrier, self.Style, self.Difficulty)
\tcarrier.Model:SetAttribute("AIWingerWideDecision", wingerPass and wingerPass.PassKind or "")''',
    '''\tlocal boxCross = chooseBoxCross(context, carrier)
\tlocal wingerPass = boxCross or AIPassingDecisionService.ChooseWingerWide(context, carrier, self.Style, self.Difficulty)
\tcarrier.Model:SetAttribute("AIWingerWideDecision", wingerPass and wingerPass.PassKind or "")''',
    "box cross"
)

brain = replace_once(
    brain,
    '''\tlocal enoughBoxSpace = attackStage == "FinalChance" and PitchConfig.InZone(carrier.Pitch, "OpponentBox") and pressure.Closest > 11
\tlocal strikerShootBias = carrier.Role == "ST" and shot.Good and (PitchConfig.InZone(carrier.Pitch, "OpponentBox") or PitchConfig.InZone(carrier.Pitch, "CentralShootingZone"))
\tif shot.Good and (strikerShootBias or shot.Score > 32 or enoughBoxSpace) and (not pressure.Heavy or enoughBoxSpace or strikerShootBias) then''',
    '''\tlocal closeToDanger = carrier.Pitch.Z >= 590 or PitchConfig.InZone(carrier.Pitch, "OpponentBox") or PitchConfig.InZone(carrier.Pitch, "CentralShootingZone")
\tlocal enoughBoxSpace = attackStage == "FinalChance" and PitchConfig.InZone(carrier.Pitch, "OpponentBox") and pressure.Closest > 10
\tlocal openDangerShot = closeToDanger and pressure.Closest > 10
\tlocal strikerShootBias = carrier.Role == "ST" and shot.Good and (PitchConfig.InZone(carrier.Pitch, "OpponentBox") or PitchConfig.InZone(carrier.Pitch, "CentralShootingZone"))
\tif openDangerShot then
\t\tcarrier.Model:SetAttribute("VTROpenDangerShotChance", 0.8)
\t\tcarrier.Model:SetAttribute("VTROpenDangerShotChanceUntil", context.Now + 2.8)
\telse
\t\tcarrier.Model:SetAttribute("VTROpenDangerShotChance", nil)
\t\tcarrier.Model:SetAttribute("VTROpenDangerShotChanceUntil", nil)
\tend
\tif (shot.Good or openDangerShot) and (openDangerShot or strikerShootBias or shot.Score > 26 or enoughBoxSpace) and (not pressure.Heavy or enoughBoxSpace or strikerShootBias or openDangerShot) then''',
    "open shot chance"
)

brain = replace_once(
    brain,
    '''\tlocal direction = pass.Target - passer.Root.Position
\tif direction.Magnitude < 4 then''',
    '''\tlocal direction = pass.Target - passer.Root.Position
\tif pass.Receiver and pass.Receiver.Root then
\t\tlocal receiverVelocity = flat(pass.Receiver.Root.AssemblyLinearVelocity)
\t\tif receiverVelocity.Magnitude > 1.5 and (pass.PassKind == "Through" or pass.PassKind == "Lofted" or pass.ForwardGain and pass.ForwardGain > 8) then
\t\t\tlocal lead = receiverVelocity.Unit * math.clamp(receiverVelocity.Magnitude * (pass.PassKind == "Lofted" and 0.42 or 0.3), 5, 24)
\t\t\tlocal leadTarget = pass.Target + lead
\t\t\tlocal leadPitch = PitchConfig.WorldToTeamPitchPosition(leadTarget, passer.Side, context.Options)
\t\t\tif leadPitch.Z >= pass.Receiver.Pitch.Z - 2 then
\t\t\t\tpass.Target = PitchConfig.TeamPitchPositionToWorld(PitchConfig.ClampInsidePitch(Vector3.new(leadPitch.X, 3, leadPitch.Z)), passer.Side, context.Options)
\t\t\t\tdirection = pass.Target - passer.Root.Position
\t\t\tend
\t\tend
\tend
\tif direction.Magnitude < 4 then''',
    "final lead pass"
)

brain_path.write_text(brain, encoding="utf-8", newline="\n")

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

gk = replace_once(
    gk,
    '''\tlocal rating=keeperRating(keeper)
\tlocal shooterStat=shooterRating(shooter)
\tlocal goalChance=math.clamp(.5+(shooterStat-rating)/100,.05,.95)
\treturn 1-goalChance''',
    '''\tlocal rating=keeperRating(keeper)
\tlocal shooterStat=shooterRating(shooter)
\tif shooter and (tonumber(shooter:GetAttribute("VTROpenDangerShotChanceUntil")) or 0) >= os.clock() then
\t\tlocal baseGoalChance = tonumber(shooter:GetAttribute("VTROpenDangerShotChance")) or 0.8
\t\tlocal goalChance = math.clamp(baseGoalChance + (shooterStat - rating) / 100, 0.08, 0.96)
\t\treturn 1 - goalChance
\tend
\tlocal goalChance=math.clamp(.5+(shooterStat-rating)/100,.05,.95)
\treturn 1-goalChance''',
    "open danger gk chance"
)

gk_path.write_text(gk, encoding="utf-8", newline="\n")

print("updated predictive defending, lead passing, crosses, and open danger shots")