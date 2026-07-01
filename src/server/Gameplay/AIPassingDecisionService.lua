--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)

local Service = {}
local Randomizer = Random.new()
local MiddleMistakeMemory = {Home = 0, Away = 0}

local function isCentralLaneX(x: number): boolean
	return x >= 112 and x <= 312
end

local function isWingLaneX(x: number): boolean
	return x <= 104 or x >= 320
end

local function memoryForSide(side: string): number
	return math.clamp(MiddleMistakeMemory[side] or 0, 0, 1)
end

local function setMemory(side: string, value: number)
	if side == "Home" or side == "Away" then
		MiddleMistakeMemory[side] = math.clamp(value, 0, 1)
	end
end

function Service.GetMiddleMistakeMemory(side: string): number
	return memoryForSide(side)
end

function Service.RecordPassOutcome(passer: Model?, receiver: Model?, success: boolean)
	if not passer then return end
	local side = tostring(passer:GetAttribute("VTRTeam") or "")
	if side ~= "Home" and side ~= "Away" then return end
	local memory = memoryForSide(side)
	local central = passer:GetAttribute("AIPassCentralLane") == true
	local outnumbered = passer:GetAttribute("AIPassMiddleOutnumbered") == true
	local wing = passer:GetAttribute("AIPassWingEscape") == true
	if central and outnumbered and not success then
		memory += 0.34
	elseif central and not success then
		memory += 0.18
	elseif wing and success then
		memory -= 0.18
	elseif success then
		memory -= 0.04
	end
	setMemory(side, memory)
	passer:SetAttribute("AIMiddlePassMistakeMemory", memoryForSide(side))
	passer:SetAttribute("AILastPassLearnedWide", wing and success)
end

local function passType(fromZ: number, toZ: number): string
	local dz = toZ - fromZ
	if dz >= 25 then
		return "Forward"
	elseif dz <= -20 then
		return "Back"
	end
	return "Side"
end

local function leadRunTarget(context: any, passer: any, receiver: any, targetPitch: Vector3, kind: string): Vector3
	local receiverRoot = receiver.Root
	local runnerVelocity = receiverRoot and Vector3.new(receiverRoot.AssemblyLinearVelocity.X, 0, receiverRoot.AssemblyLinearVelocity.Z) or Vector3.zero
	local forwardLead = math.clamp(receiver.Pitch.Z - passer.Pitch.Z, -8, 48) * 0.18
	local velocityLead = Vector3.zero
	if runnerVelocity.Magnitude > 1.5 then
		local aheadWorld = receiver.World + runnerVelocity.Unit * math.clamp(runnerVelocity.Magnitude * (kind == "Through" and 0.38 or kind == "Lofted" and 0.42 or 0.28), 5, 24)
		velocityLead = PitchConfig.WorldToTeamPitchPosition(aheadWorld, passer.Side, context.Options) - receiver.Pitch
	end
	local extraForward = (receiver.Role == "Winger" or receiver.Role == "ST") and math.max(8, forwardLead) or math.max(2, forwardLead * 0.55)
	if kind == "BackPass" then
		extraForward = 0
		velocityLead = Vector3.zero
	end
	return PitchConfig.ClampInsidePitch(Vector3.new(targetPitch.X + velocityLead.X * 0.65, 3, math.max(targetPitch.Z, receiver.Pitch.Z + extraForward + math.max(0, velocityLead.Z * 0.65))))
end

local function flatPass(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function laneInterceptionRisk(context: any, passer: any, target: Vector3, passKind: string): number
	if passKind == "Lofted" or passKind == "FarPostCross" or passKind == "LowCross" then
		return 0
	end
	local start = passer.World
	local segment = flatPass(target - start)
	local length = segment.Magnitude
	if length < 8 then
		return 0
	end
	local direction = segment.Unit
	local risk = 0
	for _, defender in ipairs(context.Teams[passer.OpponentSide].List) do
		if defender.Root and not defender.IsGoalkeeper then
			local defenderOffset = flatPass(defender.World - start)
			local along = defenderOffset:Dot(direction)
			if along > 6 and along < length - 4 then
				local closest = start + direction * along
				local lateral = PitchConfig.GetDistanceStuds(defender.World, closest)
				local pace = defender.Stats and defender.Stats.pace or 60
				local interceptions = defender.Stats and defender.Stats.interceptions or defender.Stats and defender.Stats.defending or 60
				local reach = 7.5 + math.clamp((pace - 55) * 0.045, -1.2, 2.2) + math.clamp((interceptions - 55) * 0.07, -1.4, 3)
				if passKind == "Through" then
					reach += 2
				end
				if lateral <= reach + 4 then
					local laneCut = math.clamp((reach + 4 - lateral) / (reach + 4), 0, 1)
					local defenderQuality = math.clamp((pace * 0.45 + interceptions * 0.55) / 100, 0.35, 1)
					local centrality = 1 - math.abs((along / length) - 0.5) * 0.5
					risk = math.max(risk, laneCut * defenderQuality * centrality)
				end
			end
		end
	end
	return math.clamp(risk, 0, 1)
end

local function passTarget(context: any, passer: any, receiver: any, kind: string): Vector3
	if kind == "LowCross" then
		local nearX = passer.Pitch.X < PitchConfig.HALF_WIDTH and 176 or 248
		local targetPitch = Vector3.new(nearX, 3, math.clamp(math.max(receiver.Pitch.Z, 624), 610, 666))
		return PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)
	elseif kind == "FarPostCross" then
		local farX = passer.Pitch.X < PitchConfig.HALF_WIDTH and 306 or 118
		local targetPitch = Vector3.new(farX, 3, math.clamp(math.max(receiver.Pitch.Z, 640), 622, 676))
		return PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)
	elseif kind == "Cutback" then
		local z = receiver.Role == "CM" and 548 or 584
		local x = receiver.Role == "CM" and receiver.Pitch.X + (PitchConfig.HALF_WIDTH - receiver.Pitch.X) * 0.55 or PitchConfig.HALF_WIDTH
		return PitchConfig.TeamPitchPositionToWorld(Vector3.new(x, 3, z), passer.Side, context.Options)
	elseif kind == "BackPass" then
		local targetPitch = Vector3.new(receiver.Pitch.X, 3, math.min(receiver.Pitch.Z, passer.Pitch.Z - 28))
		return PitchConfig.TeamPitchPositionToWorld(PitchConfig.ClampInsidePitch(targetPitch), passer.Side, context.Options)
	end
	if kind == "Through" then
		local defensiveLine = AIContextBuilder.DefensiveLineZ(context, passer.Side)
		local laneX = receiver.Pitch.X
		local receiverLead = math.clamp(receiver.Pitch.Z - passer.Pitch.Z, 12, 42) * 0.22
		local lineLead = math.clamp(defensiveLine - receiver.Pitch.Z, -12, 28) * 0.16
		local targetZ = receiver.Pitch.Z + math.clamp(5 + receiverLead + lineLead, 5, 16)
		local targetPitch = leadRunTarget(context, passer, receiver, Vector3.new(laneX, 3, math.clamp(targetZ, 0, 704)), kind)
		return PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)
	end
	local targetPitch = leadRunTarget(context, passer, receiver, Vector3.new(receiver.Pitch.X, 3, receiver.Pitch.Z), kind)
	local target = PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)
	return Vector3.new(target.X, receiver.World.Y, target.Z)
end

local function isWideWinger(passer: any): boolean
	return passer.Role == "Winger" and (passer.Pitch.X < 100 or passer.Pitch.X > 324)
end

local function sameSide(a: any, b: any): boolean
	return (a.Pitch.X < PitchConfig.HALF_WIDTH and b.Pitch.X < PitchConfig.HALF_WIDTH)
		or (a.Pitch.X > PitchConfig.HALF_WIDTH and b.Pitch.X > PitchConfig.HALF_WIDTH)
end

local function centralOutnumberedAround(context: any, passer: any, targetZ: number?): boolean
	local zCenter = targetZ or passer.Pitch.Z
	local zMin = math.min(passer.Pitch.Z, zCenter) - 36
	local zMax = math.max(passer.Pitch.Z, zCenter) + 42
	local teammates = 0
	local opponents = 0
	for _, info in ipairs(context.Teams[passer.Side].List) do
		if info.Root and not info.IsGoalkeeper and isCentralLaneX(info.Pitch.X) and info.Pitch.Z >= zMin and info.Pitch.Z <= zMax then
			teammates += 1
		end
	end
	for _, info in ipairs(context.Teams[passer.OpponentSide].List) do
		if info.Root and not info.IsGoalkeeper and isCentralLaneX(info.Pitch.X) and info.Pitch.Z >= zMin and info.Pitch.Z <= zMax then
			opponents += 1
		end
	end
	return opponents >= teammates + 1 and opponents >= 2
end

local function wingerPassKind(passer: any, receiver: any, pressure: any): (string?, number)
	local z = passer.Pitch.Z
	if z > 675 then
		if receiver.Role == "CAM" or receiver.Role == "CM" then return "Cutback", 600 end
		if receiver.Role == "ST" and receiver.Pitch.Z >= 590 then return "Lofted", 640 end
		if receiver.Role == "Winger" and not sameSide(passer, receiver) then return "FarPostCross", 530 end
		if receiver.Role == "Fullback" or receiver.Role == "CM" then return "BackPass", 500 end
	elseif z >= 610 then
		if receiver.Role == "ST" and receiver.Pitch.Z >= 585 then return "Lofted", 610 end
		if receiver.Role == "Winger" and not sameSide(passer, receiver) and receiver.Pitch.Z >= 565 then return "FarPostCross", 500 end
		if receiver.Role == "CAM" or receiver.Role == "CM" then return "Cutback", 480 end
		if receiver.Role == "Fullback" and sameSide(passer, receiver) then return "BackPass", 430 end
	elseif z >= 495 then
		if receiver.Role == "ST" and receiver.Pitch.Z >= 585 then return "LowCross", 430 end
		if receiver.Role == "CAM" or receiver.Role == "CM" then return "Ground", 410 end
		if receiver.Role == "Fullback" and sameSide(passer, receiver) and receiver.Pitch.Z >= passer.Pitch.Z - 65 then return "Ground", 390 end
		if receiver.Role == "Winger" and not sameSide(passer, receiver) and receiver.Pitch.Z > passer.Pitch.Z + 10 then return "Lofted", 370 end
	else
		if pressure.Under and (receiver.Role == "CM" or receiver.Role == "CAM") then return "Ground", 340 end
		if pressure.Heavy and receiver.Role == "Fullback" and sameSide(passer, receiver) then return "BackPass", 330 end
		if (receiver.Role == "ST" or receiver.Role == "Winger") and receiver.Pitch.Z > passer.Pitch.Z + 35 then return "Through", 300 end
	end
	return nil, 0
end

local function routeBias(stage: string, mood: string, receiver: any, kind: string, forwardGain: number): number
	local bias = 0
	if stage == "BuildUp" then
		if receiver.Role == "Winger" or receiver.Role == "ST" then
			bias += 28
		elseif receiver.Role == "CAM" or receiver.Role == "CM" or receiver.Role == "Fullback" then
			bias += 14
		elseif receiver.Role == "GK" or receiver.Role == "CB" then
			bias -= 10
		end
		if forwardGain > 20 then bias += 18 end
	elseif stage == "Progression" then
		if receiver.Role == "CM" or receiver.Role == "CAM" or receiver.Role == "Winger" or receiver.Role == "Fullback" then bias += 15 end
		if kind == "Forward" then bias += 8 end
	elseif stage == "WideAttack" then
		if receiver.Role == "ST" or receiver.Role == "CAM" or receiver.Role == "CM" then bias += 14 end
		if kind == "Back" then bias += 6 end
	elseif stage == "CentralAttack" then
		if receiver.Role == "ST" or receiver.Role == "Winger" or receiver.Role == "CAM" then bias += 16 end
	elseif stage == "FinalChance" then
		if receiver.Role == "ST" or receiver.Role == "Winger" or receiver.Role == "CAM" then bias += 18 end
		if forwardGain < -30 then bias += 10 end
	end
	if mood == "Pressing" then
		bias += kind == "Side" and 16 or kind == "Back" and 10 or forwardGain > 24 and 12 or 0
		if receiver.Role == "Winger" or receiver.Role == "Fullback" or receiver.Role == "CM" then bias += 8 end
	elseif mood == "AggressiveRisk" then
		bias += forwardGain > 18 and 24 or kind == "Side" and 8 or 0
		if receiver.Role == "ST" or receiver.Role == "Winger" or receiver.Role == "CAM" then bias += 10 end
	elseif mood == "Passive" then
		bias += kind == "Forward" and 18 or kind == "Side" and 6 or kind == "Back" and -8 or 0
	end
	return bias
end

function Service.ScoreReceiver(context: any, passer: any, receiver: any, style: any, difficulty: any): any
	local distance = PitchConfig.GetDistanceStuds(passer.World, receiver.World)
	if distance < 7 or distance > 135 then
		return nil
	end

	local open, veryOpen, tight = AIContextBuilder.IsOpen(context, receiver)
	local kind = passType(passer.Pitch.Z, receiver.Pitch.Z)
	local forwardGain = receiver.Pitch.Z - passer.Pitch.Z
	local stage = AIContextBuilder.AttackStage(context, passer.Side)
	local mood = AIContextBuilder.DefensiveMood(context, passer.Side, passer)
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, passer.Side)
	local timedStrikerRun = receiver.Role == "ST"
		and (passer.Role == "CM" or passer.Role == "CAM" or passer.Role == "CDM")
		and defensiveLine > 90
		and receiver.Pitch.Z >= defensiveLine - 34
		and receiver.Pitch.Z <= defensiveLine - 3
	if defensiveLine > 90 and forwardGain > 1 and receiver.Pitch.Z > defensiveLine - 3 then
		return nil
	end
	local dangerous = receiver.Pitch.Z > 495 or PitchConfig.InZone(receiver.Pitch, "OpponentBox") or math.abs(742 - receiver.Pitch.Z) < 35
	local directness = style:Directness()
	local risk = style:Risk()
	local forwardPriority = style:Ratio("ForwardPassPriority")
	local backPassSafety = style:Ratio("BackPassSafety")
	local throughFrequency = style:Ratio("ThroughBallFrequency")
	local passRisk = style:Ratio("PassRisk")
	local targetKind = "Ground"
	if timedStrikerRun and forwardGain > 12 then
		targetKind = "Through"
	elseif mood == "AggressiveRisk" and forwardGain > 16 and distance > 22 then
		targetKind = "Through"
	elseif dangerous and forwardGain > 35 and directness + risk + throughFrequency > 1.15 then
		targetKind = "Through"
	elseif mood == "Pressing" and distance > 44 and (math.abs(receiver.Pitch.X - passer.Pitch.X) > 78 or forwardGain > 20) then
		targetKind = math.abs(receiver.Pitch.X - passer.Pitch.X) > 78 and "Lofted" or "Through"
	elseif distance > 62 and forwardGain > 12 and directness + style:Ratio("FreeKickLongPass") + style:Ratio("SwitchPlayFrequency") > 1.18 then
		targetKind = "Lofted"
	end
	local receiverAssignment = tostring(receiver.Model:GetAttribute("SupportRole") or receiver.Model:GetAttribute("currentAssignment") or "")
	local trailingCover = receiverAssignment == "TrailStrikerCover" or receiverAssignment == "TrailMidfielderCover" or receiverAssignment == "TrailStrikerCoverWide" or receiverAssignment == "TrailMidfielderCoverWide" or receiverAssignment == "TrailingPassBack"
	if trailingCover and forwardGain <= -8 then
		targetKind = "BackPass"
	end
	local target = passTarget(context, passer, receiver, targetKind)
	local groundLaneClear = AIContextBuilder.PassingLaneClear(context, passer, target, targetKind == "Through" and "Driven" or "Ground")
	if targetKind == "Ground" and not groundLaneClear and distance > 48 and forwardGain > 6 and directness + passRisk > 0.85 then
		targetKind = "Lofted"
		target = passTarget(context, passer, receiver, targetKind)
	end
	local laneClear = targetKind == "Lofted" and AIContextBuilder.PassingLaneClear(context, passer, target, "Lobbed") or AIContextBuilder.PassingLaneClear(context, passer, target, targetKind == "Through" and "Driven" or "Ground")
	local laneRisk = laneInterceptionRisk(context, passer, target, targetKind)
	if laneRisk >= 0.54 and targetKind ~= "Lofted" then
		if Randomizer:NextNumber() < 0.2 and distance >= 24 and forwardGain >= -8 then
			targetKind = "Lofted"
			target = passTarget(context, passer, receiver, targetKind)
			laneClear = AIContextBuilder.PassingLaneClear(context, passer, target, "Lobbed")
			laneRisk = laneInterceptionRisk(context, passer, target, targetKind)
		else
			laneClear = false
		end
	end
	local pressure = AIContextBuilder.Pressure(context, receiver)
	local safe = (open or veryOpen) and laneClear and laneRisk < 0.46 and distance < 115 and not (pressure.Under and kind == "Back")
	local passerPressure = AIContextBuilder.Pressure(context, passer)
	local sideMemory = memoryForSide(passer.Side)
	local centralPass = isCentralLaneX(passer.Pitch.X) and isCentralLaneX(receiver.Pitch.X)
	local receiverWide = isWingLaneX(receiver.Pitch.X) or receiver.Role == "Winger" or receiver.Role == "Fullback"
	local centralTrap = isCentralLaneX(passer.Pitch.X) and centralOutnumberedAround(context, passer, receiver.Pitch.Z)
	local middleOutnumbered = centralPass and centralOutnumberedAround(context, passer, receiver.Pitch.Z)

	local score = 0
	score += (veryOpen and 24 or open and 14 or tight and -20 or 0)
	score += laneClear and 38 or -86
	score += kind == "Forward" and (42 + directness * 28 + forwardPriority * 28) or kind == "Side" and (26 - directness * 3) or (-42 + backPassSafety * 4 - directness * 30)
	score += targetKind == "Through" and (12 + throughFrequency * 22) or targetKind == "Lofted" and (directness * 14 + style:Ratio("FreeKickLongPass") * 8) or 0
	score += forwardGain > 45 and 16 or forwardGain > 24 and 10 or forwardGain > 8 and 5 or 0
	score += dangerous and (10 + risk * 10 + passRisk * 10) or 0
	score -= math.abs(distance - (directness > 0.55 and 48 or 28)) * 0.22
	score += (receiver.Stats.overall or 60) * 0.08 + (receiver.Stats.pace or 60) * 0.05
	score += routeBias(stage, mood, receiver, kind, forwardGain)
	if middleOutnumbered then
		score -= 42 + sideMemory * 76
	elseif centralPass and sideMemory > 0.12 then
		score -= sideMemory * (kind == "Forward" and 52 or 34)
	end
	if receiverWide and (centralTrap or sideMemory >= 0.22) then
		score += 26 + sideMemory * 70
		if kind == "Side" then
			score += 18
		end
		if receiver.Role == "Winger" then
			score += 18
		elseif receiver.Role == "Fullback" then
			score += 10
		end
	end
	local fastDistributionBias = true
	if kind == "Back" then
		score -= passer.Pitch.Z >= PitchConfig.HALF_LENGTH and 58 or 34
		if forwardGain < -38 then
			score -= 20
		end
	elseif kind == "Side" then
		score += laneClear and 24 or -28
		if passerPressure.Under or passerPressure.Heavy then
			score += (open or veryOpen) and 20 or 8
		end
	elseif kind == "Forward" then
		score += laneClear and 28 or -42
		score += math.clamp(forwardGain, 0, 70) * 0.36
		if open or veryOpen then
			score += 16
		end
	end
	if kind == "Back" then
		local backPenalty = passer.Pitch.Z >= PitchConfig.HALF_LENGTH and 42 or 24
		if passerPressure.Heavy then
			backPenalty -= 12
		elseif not passerPressure.Under then
			backPenalty += 10
		end
		if forwardGain < -48 then
			backPenalty += 18
		end
		score -= backPenalty
	elseif forwardGain > 6 then
		score += math.clamp(forwardGain, 0, 58) * 0.42
		if passerPressure.Under or passerPressure.Heavy then
			score += (laneClear and (open or veryOpen)) and 24 or 0
		end
	elseif kind == "Side" and (passerPressure.Under or passerPressure.Heavy) and laneClear and (open or veryOpen) then
		score += 18
	end
	if trailingCover and kind == "Back" then
		score += (passerPressure.Heavy and 18 or passerPressure.Under and 8 or -18) + backPassSafety * 6
	elseif trailingCover then
		score += 8
	end
	if timedStrikerRun then
		score += 46
	end
	score -= pressure.Score * 18
	score -= laneRisk * 96
	if laneRisk >= 0.54 then
		score -= 42
	elseif laneRisk >= 0.36 then
		score -= 20
	end
	if targetKind == "Lofted" and laneRisk < 0.26 and forwardGain >= -4 then
		score += 10
	end
	score += difficulty.PassRisk * 10
	if mood == "Passive" and forwardGain > 34 then
		score -= 14
	elseif mood == "Pressing" and targetKind ~= "Ground" then
		score += 10
	elseif mood == "AggressiveRisk" and targetKind == "Through" then
		score += 18
	end
	if not safe and math.max(risk, passRisk) < 0.45 and mood ~= "AggressiveRisk" then
		score -= 18
	end
	if not laneClear then
		score -= 72
	end
	if kind == "Back" and not passerPressure.Heavy then
		score -= passerPressure.Under and 8 or 24
	end

	return {
		Receiver = receiver,
		Score = score,
		Kind = kind,
		PassKind = targetKind,
		Target = target,
		Distance = distance,
		LaneClear = laneClear,
		LaneRisk = laneRisk,
		Safe = safe,
		ForwardGain = forwardGain,
		Stage = stage,
		DefensiveMood = mood,
		MiddlePass = centralPass,
		MiddleOutnumbered = middleOutnumbered,
		WingEscape = receiverWide and (centralTrap or sideMemory >= 0.22),
	}
end

function Service.ChooseKickoffReturn(context: any, passer: any, style: any, difficulty: any): any?
	local best = nil
	for _, receiver in ipairs(context.Teams[passer.Side].List) do
		if receiver.Model ~= passer.Model and receiver.Root then
			local gain = receiver.Pitch.Z - passer.Pitch.Z
			local distance = PitchConfig.GetDistanceStuds(passer.World, receiver.World)
			if distance >= 8 and distance <= 70 and gain <= 12 then
				local scored = Service.ScoreReceiver(context, passer, receiver, style, difficulty)
				if scored and scored.LaneClear then
					scored.Score += math.max(0, 30 - math.abs(gain + 12)) + math.max(0, 36 - math.abs(distance - 24))
					scored.PassKind = "Ground"
					scored.Target = passTarget(context, passer, receiver, "Ground")
					if not best or scored.Score > best.Score then best = scored end
				end
			end
		end
	end
	return best
end

function Service.ChooseWingerWide(context: any, passer: any, style: any, difficulty: any): any?
	if not isWideWinger(passer) then
		return nil
	end
	local pressure = AIContextBuilder.Pressure(context, passer)
	if passer.Pitch.Z < 495 and not pressure.Under and not pressure.Heavy then
		return nil
	end
	local best = nil
	for _, receiver in ipairs(context.Teams[passer.Side].List) do
		if receiver.Model ~= passer.Model and receiver.Root and not receiver.IsGoalkeeper then
			local kind, priority = wingerPassKind(passer, receiver, pressure)
			if kind then
				local distance = PitchConfig.GetDistanceStuds(passer.World, receiver.World)
				if distance >= 8 and distance <= 155 then
					local target = passTarget(context, passer, receiver, kind)
					local laneKind = (kind == "FarPostCross" or kind == "Lofted") and "Lobbed" or kind == "Through" and "Driven" or "Ground"
					local laneClear = AIContextBuilder.PassingLaneClear(context, passer, target, laneKind)
					local open, veryOpen, tight = AIContextBuilder.IsOpen(context, receiver)
					local receiverPressure = AIContextBuilder.Pressure(context, receiver)
					local score = priority
					score += laneClear and 42 or -90
					score += veryOpen and 26 or open and 16 or tight and -24 or 0
					score += receiver.Role == "ST" and 10 or receiver.Role == "CAM" and 9 or receiver.Role == "CM" and 7 or receiver.Role == "Fullback" and 4 or 0
					score -= receiverPressure.Score * 18
					score -= math.abs(distance - (kind == "BackPass" and 32 or kind == "Cutback" and 46 or 62)) * 0.12
					score += difficulty.PassRisk * 5
					if passer.Pitch.Z > 675 and (kind == "Cutback" or kind == "LowCross" or kind == "FarPostCross") then
						score += 50
					end
					if laneClear and (not best or score > best.Score) then
						best = {
							Receiver = receiver,
							Score = score,
							Kind = receiver.Pitch.Z > passer.Pitch.Z and "Forward" or receiver.Pitch.Z < passer.Pitch.Z - 20 and "Back" or "Side",
							PassKind = kind,
							Target = target,
							Distance = distance,
							LaneClear = laneClear,
							Safe = laneClear and (open or veryOpen or kind == "BackPass"),
							ForwardGain = receiver.Pitch.Z - passer.Pitch.Z,
							Stage = AIContextBuilder.AttackStage(context, passer.Side),
							DefensiveMood = AIContextBuilder.DefensiveMood(context, passer.Side, passer),
						}
					end
				end
			end
		end
	end
	return best
end

function Service.Choose(context: any, passer: any, style: any, difficulty: any, forcedSafe: boolean?): any?
	local best = nil
	local bestSafe = nil
	local fallback = nil
	local trailing = nil
	local alternate = nil
	local progressive = nil
	local sideways = nil
	local wingEscape = nil
	for _, receiver in ipairs(context.Teams[passer.Side].List) do
		if receiver.Model ~= passer.Model and receiver.Root and not receiver.IsGoalkeeper then
			local scored = Service.ScoreReceiver(context, passer, receiver, style, difficulty)
			if scored then
				local assignment = tostring(receiver.Model:GetAttribute("SupportRole") or receiver.Model:GetAttribute("currentAssignment") or "")
				local isTrailing = assignment == "TrailStrikerCover" or assignment == "TrailMidfielderCover" or assignment == "TrailStrikerCoverWide" or assignment == "TrailMidfielderCoverWide" or assignment == "TrailingPassBack"
				if scored.LaneClear and scored.Score > -4 and (not fallback or scored.Score > fallback.Score) then
					fallback = scored
				end
				if scored.Safe and (not bestSafe or scored.Score > bestSafe.Score) then
					bestSafe = scored
				end
				if scored.LaneClear and scored.ForwardGain > 8 and scored.Kind ~= "Back" and scored.Score > -8 and (scored.Safe or scored.ForwardGain > 22) and (not progressive or scored.Score > progressive.Score) then
					progressive = scored
				end
				if scored.LaneClear and scored.Kind == "Side" and scored.Score > -12 and (scored.Safe or scored.Distance <= 70) and (not sideways or scored.Score > sideways.Score) then
					sideways = scored
				end
				if scored.LaneClear and scored.WingEscape and scored.Score > -20 and (not wingEscape or scored.Score > wingEscape.Score) then
					wingEscape = scored
				end
				if scored.LaneClear and scored.Score > 2 and (not forcedSafe or scored.Safe) and (not best or scored.Score > best.Score) then
					best = scored
				end
				if scored.LaneClear and scored.Safe and scored.Score > 2 then
					if isTrailing and scored.Kind == "Back" and (not trailing or scored.Score > trailing.Score) then
						trailing = scored
					elseif not isTrailing and (not alternate or scored.Score > alternate.Score) then
						alternate = scored
					end
				end
			end
		end
	end
	local passerPressure = AIContextBuilder.Pressure(context, passer)
	local sideMemory = memoryForSide(passer.Side)
	local centralTrap = isCentralLaneX(passer.Pitch.X) and centralOutnumberedAround(context, passer, passer.Pitch.Z + 36)
	if wingEscape and (centralTrap or sideMemory >= 0.34) then
		if not best or best.MiddlePass or wingEscape.Score >= best.Score - (26 + sideMemory * 44) then
			return wingEscape
		end
	end
	if passerPressure.Heavy or passerPressure.Under then
		if progressive then
			return progressive
		end
		if sideways and (not best or best.Kind == "Back" or sideways.Score >= best.Score - 18) then
			return sideways
		end
		if best and best.Kind ~= "Back" then
			return best
		end
		if passer.Pitch.Z >= PitchConfig.HALF_LENGTH and not passerPressure.Heavy then
			if alternate and alternate.Kind ~= "Back" then
				return alternate
			end
			return nil
		end
	end
	if passer.Pitch.Z >= PitchConfig.HALF_LENGTH and best and best.Kind == "Back" and alternate and alternate.Kind ~= "Back" then
		return alternate
	end
	if trailing and alternate and passerPressure.Under and math.abs(trailing.Score - alternate.Score) <= 18 then
		return alternate.Kind ~= "Back" and alternate or trailing
	end
	return best or bestSafe or fallback
end

return Service
