--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)

local Service = {}
local Randomizer = Random.new()

local function isCentralLaneX(x: number): boolean
	return x >= 112 and x <= 312
end

local function isWingLaneX(x: number): boolean
	return x <= 104 or x >= 320
end

local function memoryForPasser(passer: any): number
	local model = typeof(passer) == "Instance" and passer or type(passer) == "table" and passer.Model or nil
	return math.clamp(tonumber(model and model:GetAttribute("AIMiddlePassMistakeMemory")) or 0, 0, 1)
end

function Service.GetMiddleMistakeMemory(passer: any): number
	return memoryForPasser(passer)
end

function Service.RecordPassOutcome(passer: Model?, receiver: Model?, success: boolean, matchModels: {Model}?)
	if not passer then return end
	local side = tostring(passer:GetAttribute("VTRTeam") or "")
	if side ~= "Home" and side ~= "Away" then return end
	local memory = memoryForPasser(passer)
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
	local resolvedMemory = math.clamp(memory, 0, 1)
	for _, model in matchModels or {passer} do if model:GetAttribute("VTRTeam") == side then model:SetAttribute("AIMiddlePassMistakeMemory", resolvedMemory) end end
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
				local interceptions = defender.Stats and (defender.Stats.interceptionSkill or defender.Stats.interceptions or defender.Stats.defending) or 60
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

local function isCenterBack(info: any): boolean
	return info.Role == "CB"
end

local function isFullback(info: any): boolean
	return info.Role == "Fullback"
end

local function isMidfielder(info: any): boolean
	return info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM"
end

local function isStriker(info: any): boolean
	return info.Role == "ST"
end

local function sameWideLane(a: any, b: any): boolean
	return (a.Pitch.X < PitchConfig.HALF_WIDTH and b.Pitch.X < PitchConfig.HALF_WIDTH) or (a.Pitch.X > PitchConfig.HALF_WIDTH and b.Pitch.X > PitchConfig.HALF_WIDTH)
end

local function fullbackCanProgress(context: any, passer: any): boolean
	local pressure = AIContextBuilder.Pressure(context, passer)
	if pressure.Heavy then return false end
	local forwardPitch = PitchConfig.ClampInsidePitch(Vector3.new(passer.Pitch.X, 3, passer.Pitch.Z + 58))
	return AIContextBuilder.SpaceAt(context, passer.Side, forwardPitch, pressure.Under and 16 or 24) == true
end

local function midfielderCanProgress(context: any, passer: any): boolean
	local pressure = AIContextBuilder.Pressure(context, passer)
	if pressure.Under or pressure.Heavy then return false end
	local forwardPitch = PitchConfig.ClampInsidePitch(Vector3.new(passer.Pitch.X + (PitchConfig.HALF_WIDTH - passer.Pitch.X) * .2, 3, passer.Pitch.Z + 48))
	return AIContextBuilder.SpaceAt(context, passer.Side, forwardPitch, 22) == true
end

local function stagedCandidate(context: any, passer: any, style: any, difficulty: any, predicate: (any) -> boolean, bonus: number): any?
	local best = nil
	for _, receiver in ipairs(context.Teams[passer.Side].List) do
		if receiver.Model ~= passer.Model and receiver.Root and not receiver.IsGoalkeeper and predicate(receiver) then
			local scored = Service.ScoreReceiver(context, passer, receiver, style, difficulty)
			if scored and scored.LaneClear then
				scored.Score += bonus
				scored.PassKind = "Ground"
				scored.Target = passTarget(context, passer, receiver, receiver.Pitch.Z < passer.Pitch.Z - 12 and "BackPass" or "Ground")
				scored.StagePlay = true
				if not best or scored.Score > best.Score then best = scored end
			end
		end
	end
	return best
end

local function chooseStagedPlay(context: any, passer: any, style: any, difficulty: any): (any?, boolean)
	local role = passer.Role
	local lastRole = tostring(passer.Model:GetAttribute("AILastPasserRole") or "")
	local lastAt = tonumber(passer.Model:GetAttribute("AILastPassReceivedAt")) or 0
	local freshLast = (context.Now or os.clock()) - lastAt <= 4
	local resetUntil = type(context.TeamStageResetUntil) == "table" and tonumber(context.TeamStageResetUntil[passer.Side]) or 0
	if resetUntil and (context.Now or os.clock()) <= resetUntil and not isCenterBack(passer) and role ~= "GK" then
		local cb = stagedCandidate(context, passer, style, difficulty, isCenterBack, 420)
		if cb then
			passer.Model:SetAttribute("AITeamOffenseStage", 1)
			return cb, true
		end
	end
	if role == "GK" then
		passer.Model:SetAttribute("AITeamOffenseStage", 1)
		local cb = stagedCandidate(context, passer, style, difficulty, isCenterBack, 260)
		if cb then return cb, true end
	end
	if isFullback(passer) and passer.Pitch.Z < 455 then
		passer.Model:SetAttribute("AITeamOffenseStage", 1)
		if fullbackCanProgress(context, passer) then
			local mid = stagedCandidate(context, passer, style, difficulty, function(receiver) return isMidfielder(receiver) and sameWideLane(passer, receiver) and receiver.Pitch.Z >= passer.Pitch.Z - 18 end, 280)
			if mid then return mid, true end
			return nil, true
		end
		local cb = stagedCandidate(context, passer, style, difficulty, isCenterBack, 300)
		if cb then return cb, true end
	end
	if isCenterBack(passer) and passer.Pitch.Z < 390 then
		passer.Model:SetAttribute("AITeamOffenseStage", 1)
		if freshLast and lastRole == "CB" then
			local fullback = stagedCandidate(context, passer, style, difficulty, function(receiver) return isFullback(receiver) and receiver.Pitch.Z >= passer.Pitch.Z - 24 end, 320)
			if fullback then return fullback, true end
		end
		local otherCB = stagedCandidate(context, passer, style, difficulty, isCenterBack, 330)
		if otherCB then return otherCB, true end
		local fullback = stagedCandidate(context, passer, style, difficulty, isFullback, 240)
		if fullback then return fullback, true end
	end
	if isMidfielder(passer) then
		passer.Model:SetAttribute("AITeamOffenseStage", 2)
		if midfielderCanProgress(context, passer) and passer.Pitch.Z < 560 then
			return nil, true
		end
		local striker = stagedCandidate(context, passer, style, difficulty, function(receiver) return isStriker(receiver) and receiver.Pitch.Z >= passer.Pitch.Z + 18 end, 310)
		if striker then return striker, true end
		local mid = stagedCandidate(context, passer, style, difficulty, function(receiver) return isMidfielder(receiver) end, 250)
		if mid then return mid, true end
	end
	if isStriker(passer) then
		passer.Model:SetAttribute("AITeamOffenseStage", 2)
		local mid = stagedCandidate(context, passer, style, difficulty, function(receiver) return isMidfielder(receiver) and receiver.Pitch.Z <= passer.Pitch.Z + 12 end, 360)
		if mid then return mid, true end
	end
	return nil, false
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

local function storyBias(context: any, passer: any, receiver: any, kind: string, targetKind: string, forwardGain: number, distance: number): number
	local story = context.TeamStories and context.TeamStories[passer.Side]
	local action = tostring(story and story.Action or "")
	local movement = tostring(story and story.Movement or "")
	local role = receiver.Role
	local supportRole = tostring(receiver.Model:GetAttribute("SupportRole") or "")
	local bias = 0
	if supportRole == "ReceivePass" then return 0 end
	if movement == "Recycle" or movement == "Secure" or movement == "Safe" then
		bias += kind == "Back" and 44 or kind == "Side" and 28 or -24
		if role == "CB" or role == "CDM" or role == "Fullback" then bias += 24 end
		if forwardGain > 34 then bias -= 36 end
	elseif movement == "Possession" or movement == "Triangle" or movement == "WallPass" or movement == "Link" then
		bias += kind == "Side" and 28 or kind == "Forward" and 18 or kind == "Back" and 8 or 0
		if role == "CM" or role == "CAM" or role == "CDM" or role == "ST" then bias += 22 end
		if distance <= 55 then bias += 16 else bias -= 10 end
		if targetKind == "Through" and action ~= "ThirdManRun" then bias -= 16 end
	elseif movement == "Wide" or movement == "WideBuild" or movement == "Overload" or movement == "Switch" then
		if role == "Winger" or role == "Fullback" then bias += 38 end
		if math.abs(receiver.Pitch.X - passer.Pitch.X) > 90 then bias += movement == "Switch" and 42 or 14 end
		if targetKind == "Lofted" and movement == "Switch" then bias += 18 end
	elseif movement == "Cross" then
		if role == "ST" or role == "Winger" or role == "CAM" then bias += 36 end
		if targetKind == "LowCross" or targetKind == "FarPostCross" or targetKind == "Lofted" or targetKind == "Cutback" then bias += 42 end
		if kind == "Back" and role == "CM" then bias += 18 end
	elseif movement == "Counter" or movement == "CounterWide" or movement == "CounterCentral" or movement == "Release" then
		bias += kind == "Forward" and 48 or kind == "Side" and 8 or -26
		if role == "ST" or role == "Winger" then bias += 34 end
		if targetKind == "Through" or targetKind == "Lofted" then bias += 22 end
	elseif movement == "Direct" or movement == "Target" or movement == "SecondBall" then
		if role == "ST" then bias += 54 elseif role == "Winger" then bias += 24 elseif role == "CM" or role == "CAM" then bias += 14 end
		if targetKind == "Lofted" or targetKind == "Through" then bias += 22 end
		if kind == "Back" then bias -= 20 end
	elseif movement == "Commit" or movement == "Chance" or movement == "FinalPress" then
		bias += kind == "Forward" and 38 or kind == "Side" and 10 or -18
		if role == "ST" or role == "Winger" or role == "CAM" then bias += 28 end
	elseif movement == "SafeCounter" then
		bias += (role == "ST" or role == "Winger") and forwardGain > 22 and 30 or kind == "Back" and 16 or 0
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
	local forwardBias = style:Get("ForwardPassBias")
	local lateralBias = style:Get("LateralPassBias")
	local backBias = style:Get("BackPassBias")
	local forwardPriority = style:Ratio("ForwardPassPriority")
	local backPassSafety = style:Ratio("BackPassSafety")
	local sidePassPriority = style:Ratio("SidePassPriority")
	local recycleBias = style:Ratio("RecycleBias")
	local safePassBias = style:Ratio("SafePassBias")
	local lineBreakBias = style:Ratio("LineBreakBias")
	local lobPassBias = style:Ratio("LobPassBias")
	local retentionWeight = style:Ratio("RetentionProbabilityWeight")
	local isolationPenalty = style:Ratio("ReceiverIsolationPenalty")
	local aerialContestPenalty = style:Ratio("AerialContestPenalty")
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
	local sideMemory = memoryForPasser(passer)
	local centralPass = isCentralLaneX(passer.Pitch.X) and isCentralLaneX(receiver.Pitch.X)
	local receiverWide = isWingLaneX(receiver.Pitch.X) or receiver.Role == "Winger" or receiver.Role == "Fullback"
	local centralTrap = isCentralLaneX(passer.Pitch.X) and centralOutnumberedAround(context, passer, receiver.Pitch.Z)
	local middleOutnumbered = centralPass and centralOutnumberedAround(context, passer, receiver.Pitch.Z)
	local passerPassQuality = passer.Stats and (passer.Stats.passQuality or passer.Stats.passing or 60) or 60
	local passerVision = passer.Stats and (passer.Stats.passVision or passer.Stats.vision or passerPassQuality) or passerPassQuality
	local receiverReception = receiver.Stats and (receiver.Stats.reception or receiver.Stats.ballControl or receiver.Stats.overall or 60) or 60

	local orientationScore = kind == "Forward" and (forwardBias + directness * 22 + forwardPriority * 34 + math.clamp(forwardGain, 0, 70) * 0.28)
		or kind == "Side" and (lateralBias + 12 + sidePassPriority * 30 - directness * 8)
		or (backBias - 18 + backPassSafety * 46 + recycleBias * 28 - directness * 18)
	local safetyScore = (laneClear and 28 or -72) + (open and 10 or veryOpen and 18 or tight and -18 or 0) + safePassBias * (safe and 22 or -8)
	local spaceScore = (veryOpen and 20 or open and 12 or tight and -18 or 0)
	local receptionScore = math.clamp((receiverReception - 55) * 0.28, -10, 18) - pressure.Score * (10 + isolationPenalty * 18)
	local nextActionScore = (targetKind == "Through" and (throughFrequency * 28 + lineBreakBias * 16) or targetKind == "Lofted" and (lobPassBias * 24 - aerialContestPenalty * math.max(0, laneRisk - 0.18) * 80 + style:Ratio("FreeKickLongPass") * 8) or 0)
	local sequenceScore = storyBias(context, passer, receiver, kind, targetKind, forwardGain, distance)
	local progressionScore = forwardGain > 45 and 16 or forwardGain > 24 and 10 or forwardGain > 8 and 5 or kind == "Back" and recycleBias * 14 or 0
	local riskScore = dangerous and (10 + risk * 10 + passRisk * 10) or 0
	riskScore -= laneRisk * math.clamp(82 + retentionWeight * 62 - passRisk * 38, 58, 132)
	local transitionRiskScore = not safe and math.max(risk, passRisk) < 0.45 and mood ~= "AggressiveRisk" and -18 or 0
	local roleScore = routeBias(stage, mood, receiver, kind, forwardGain)
	local score = orientationScore + safetyScore + spaceScore + receptionScore + nextActionScore + sequenceScore + progressionScore + riskScore + transitionRiskScore + roleScore
	score -= math.abs(distance - (directness > 0.55 and 48 or 28)) * 0.22
	score += (receiver.Stats.overall or 60) * 0.06 + (receiver.Stats.pace or 60) * 0.04 + receiverReception * 0.06 + passerPassQuality * 0.08 + passerVision * 0.05
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
		score -= (passer.Pitch.Z >= PitchConfig.HALF_LENGTH and 34 or 18) * (1 - backPassSafety * 0.55) + (1 - recycleBias) * 18
		if forwardGain < -38 then
			score -= 12 * (1 - backPassSafety * 0.45)
		end
	elseif kind == "Side" then
		score += laneClear and (10 + sidePassPriority * 18) or -28
		if passerPressure.Under or passerPressure.Heavy then
			score += (open or veryOpen) and 20 or 8
		end
	elseif kind == "Forward" then
		score += laneClear and (12 + forwardPriority * 22) or -42
		score += math.clamp(forwardGain, 0, 70) * (0.2 + lineBreakBias * 0.22)
		if open or veryOpen then
			score += 16
		end
	end
	if kind == "Back" then
		local backPenalty = (passer.Pitch.Z >= PitchConfig.HALF_LENGTH and 28 or 14) * (1 - backPassSafety * 0.65)
		if passerPressure.Heavy then
			backPenalty -= 10 + recycleBias * 14
		elseif not passerPressure.Under then
			backPenalty += 8 * (1 - recycleBias)
		end
		if forwardGain < -48 then
			backPenalty += 10 * (1 - backPassSafety)
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
	local movementProfile=tostring(receiver.MovementProfile or receiver.Model:GetAttribute("VTRAIMovementProfile")or"Balanced")
	if movementProfile=="GetInBehind"then score+=targetKind=="Through"and 34 or forwardGain>12 and 12 or 0
	elseif movementProfile=="ComeShort"then score+=targetKind=="Ground"and distance<52 and 24 or 0
	elseif movementProfile=="StayWide"then score+=receiverWide and 22 or 0
	elseif movementProfile=="FreeRoam"then score+=(open or veryOpen)and 18 or 0
	elseif movementProfile=="StayBack"and forwardGain>38 then score-=30 end
	local receiverSlot = tostring(receiver.Model:GetAttribute("AITacticalSlot") or receiver.Model:GetAttribute("AITeamContractSlot") or "")
	local receiverSupport = tostring(receiver.Model:GetAttribute("VTRSupportKind") or receiver.Model:GetAttribute("SupportRole") or "")
	local passBias = tostring(passer.Model:GetAttribute("AITeamContractPassBias") or receiver.Model:GetAttribute("AITeamContractPassBias") or "")
	local passRule = context.RuleEffects and context.RuleEffects[passer.Side] and context.RuleEffects[passer.Side].Pass
	if passBias == "ThirdMan" and (receiverSlot == "second-ball-midfielder" or receiverSupport == "ThirdManPosition") then
		score += 38
	elseif (passBias == "ForwardEarly" or passBias == "LoftedOrThrough" or passBias == "Through") and (receiverSlot == "central-forward" or receiver.Role == "ST") then
		score += (targetKind == "Through" or targetKind == "Lofted") and 44 or 24
	elseif passBias == "FarSideSwitch" or passBias == "Switch" then
		if receiverSupport == "FarSideSwitchOption" or receiverSlot == "far-side-switch" or receiverSlot == "left-width" or receiverSlot == "right-width" then
			score += math.abs(receiver.Pitch.X - passer.Pitch.X) > 120 and 42 or 16
		end
	elseif passBias == "WideTriangle" and receiverSupport == "NearPassingTriangle" then
		score += 28
	elseif passBias == "Cutback" and receiverSupport == "BoxEdgeProtection" then
		score += 34
	elseif passBias == "CentralCombination" and (receiverSlot == "ball-side-pivot" or receiverSlot == "far-side-pivot" or receiverSlot == "between-lines-receiver") then
		score += 24
	end
	if passRule then
		if passRule.PreferredReceiverFunction and (receiverSlot == passRule.PreferredReceiverFunction or receiverSupport == passRule.PreferredReceiverFunction) then
			score += 36
		end
		if passRule.PassFamily and targetKind ~= tostring(passRule.PassFamily) then
			score -= 18
		end
		if passRule.RequiredPlanStep and tostring(passer.Model:GetAttribute("AITeamContractPlanStep") or "") ~= tostring(passRule.RequiredPlanStep) then
			score -= 35
		end
		if passRule.MinimumLaneQuality and (laneRisk > 1 - tonumber(passRule.MinimumLaneQuality)) then
			score -= 48
		end
		score += (tonumber(passRule.Risk) or 0) * 30
	end
	score -= pressure.Score * (10 + isolationPenalty * 14)
	score -= laneRisk * math.clamp(100 - passerVision * 0.36 + retentionWeight * 44 - passRisk * 26, 58, 124)
	if laneRisk >= 0.54 then
		score -= 42
	elseif laneRisk >= 0.36 then
		score -= 20
	end
	if targetKind == "Lofted" and laneRisk < 0.26 and forwardGain >= -4 then
		score += 4 + lobPassBias * 14
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
		ScoreBreakdown = {
			OrientationScore = orientationScore,
			SafetyScore = safetyScore,
			SpaceScore = spaceScore,
			ReceptionScore = receptionScore,
			NextActionScore = nextActionScore,
			SequenceScore = sequenceScore,
			ProgressionScore = progressionScore,
			RiskScore = riskScore,
			TransitionRiskScore = transitionRiskScore,
			RoleScore = roleScore,
			FinalScore = score,
			ReasonCodes = {kind, targetKind, laneClear and "LaneClear" or "LaneBlocked", safe and "Safe" or "Risk"},
		},
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
	local staged, stagedDecided = chooseStagedPlay(context, passer, style, difficulty)
	if stagedDecided then
		return staged
	end
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
	local sideMemory = memoryForPasser(passer)
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
