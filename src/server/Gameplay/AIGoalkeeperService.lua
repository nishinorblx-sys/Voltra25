--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)

local Service = {}

local function setDebug(keeper: any, key: string, value: any)
	if keeper and keeper.Model then
		keeper.Model:SetAttribute(key, value)
	end
end

local function opponentSide(side: string): string
	return side == "Home" and "Away" or "Home"
end

local function nearestOpponentDistance(context: any, side: string, point: Vector3): number
	local best = math.huge
	local opponents = context.Teams and context.Teams[opponentSide(side)]
	for _, opponent in ipairs(opponents and opponents.List or {}) do
		if opponent.Root and not opponent.IsGoalkeeper then
			best = math.min(best, PitchConfig.GetDistanceStuds(opponent.World, point))
		end
	end
	return best
end

local function nearestAttackerArrival(context: any, side: string, point: Vector3): number
	local distance = nearestOpponentDistance(context, side, point)
	if distance == math.huge then
		return math.huge
	end
	return distance / 21
end

local function keeperArrival(keeper: any, point: Vector3): number
	local pace = math.clamp(tonumber(keeper.Stats and keeper.Stats.pace) or tonumber(keeper.Stats and keeper.Stats.overall) or 72, 35, 99)
	return PitchConfig.GetDistanceStuds(keeper.World, point) / (18 + pace * 0.08)
end

local function rolePriority(role: string): number
	if role == "Winger" then
		return 5
	elseif role == "Wingback" or role == "Fullback" then
		return 4
	elseif role == "CB" then
		return 3
	elseif role == "CDM" then
		return 2.5
	elseif role == "CM" or role == "CAM" then
		return 2
	end
	return 1
end

local function isWideOutlet(teammate: any): boolean
	return teammate.Role == "Winger"
		or teammate.Role == "Wingback"
		or teammate.Role == "Fullback"
		or teammate.Pitch.X <= 98
		or teammate.Pitch.X >= PitchConfig.PITCH_WIDTH - 98
end

local function isShortBuildoutRole(teammate: any): boolean
	return teammate.Role == "CB"
		or teammate.Role == "Fullback"
		or teammate.Role == "Wingback"
		or teammate.Role == "CDM"
		or teammate.Role == "CM"
end

local function distributionTargetPitch(teammate: any, long: boolean): Vector3
	local lane = PitchConfig.GetLane(teammate.Pitch)
	local x = teammate.Pitch.X
	if long and (lane == "LeftWide" or teammate.Pitch.X < PitchConfig.HALF_WIDTH) then
		x = math.clamp(teammate.Pitch.X - 10, 22, PitchConfig.HALF_WIDTH - 38)
	elseif long and (lane == "RightWide" or teammate.Pitch.X >= PitchConfig.HALF_WIDTH) then
		x = math.clamp(teammate.Pitch.X + 10, PitchConfig.HALF_WIDTH + 38, PitchConfig.PITCH_WIDTH - 22)
	end
	local lead = long and 18 or teammate.Role == "CB" and 4 or 8
	return PitchConfig.ClampInsidePitch(Vector3.new(x, 3, teammate.Pitch.Z + lead))
end

local function primeDistributionReceiver(context: any, keeper: any, pass: any)
	local receiver = pass and pass.Receiver
	if not receiver or not receiver.Model then
		return
	end
	local now = context.Now or os.clock()
	local distance = PitchConfig.GetDistanceStuds(keeper.World, pass.Target)
	local ballEta = math.clamp(distance / (pass.PassKind == "Lofted" and 66 or 78), .45, pass.PassKind == "Lofted" and 2.9 or 1.8)
	local receiverEta = math.clamp(PitchConfig.GetDistanceStuds(receiver.World, pass.Target) / 24, .18, 2.4)
	local expires = now + math.clamp(ballEta + 1.4, 1.25, 5.4)
	receiver.Model:SetAttribute("VTRReceiveTarget", pass.Target)
	receiver.Model:SetAttribute("VTRReceiveIntercept", pass.Target)
	receiver.Model:SetAttribute("VTRReceiveUntil", expires)
	receiver.Model:SetAttribute("VTRReceiveBallETA", ballEta)
	receiver.Model:SetAttribute("VTRReceiveReceiverETA", receiverEta)
	receiver.Model:SetAttribute("VTRReceiveOpponentETA", nearestAttackerArrival(context, keeper.Side, pass.Target))
	receiver.Model:SetAttribute("VTRReceiveRouteConfidence", math.clamp((pass.Score or 40) / 90, .55, .96))
	receiver.Model:SetAttribute("VTRReceiveRouteSprintRequested", true)
	receiver.Model:SetAttribute("VTRReceivePassFamily", pass.PassKind or "Ground")
	receiver.Model:SetAttribute("VTRPreparingReceive", true)
	receiver.Model:SetAttribute("VTRReceiveCommitted", true)
	receiver.Model:SetAttribute("VTRReceiveHardLock", true)
	receiver.Model:SetAttribute("VTRReceiveHardLockUntil", expires)
	receiver.Model:SetAttribute("VTRForcedPassReceiver", true)
	receiver.Model:SetAttribute("VTRForcedReceiveUntil", expires)
	receiver.Model:SetAttribute("VTRAITargetedPass", true)
	receiver.Model:SetAttribute("VTRRunTicketId", nil)
	receiver.Model:SetAttribute("VTRRunApproved", false)
	receiver.Model:SetAttribute("VTRRunKind", nil)
	receiver.Model:SetAttribute("VTRRunTrigger", nil)
	receiver.Model:SetAttribute("VTRRunTarget", nil)
	receiver.Model:SetAttribute("VTRRunExpiry", nil)
	receiver.Model:SetAttribute("VTRSupportRun", nil)
	receiver.Model:SetAttribute("VTRSupportKind", nil)
	receiver.Model:SetAttribute("currentAssignment", "ReceivePass")
	receiver.Model:SetAttribute("AIAssignment", "ReceivePass")
	receiver.Model:SetAttribute("SupportRole", "ReceivePass")
	receiver.Model:SetAttribute("AttackAssignment", "ReceivePass")
	receiver.Model:SetAttribute("TeamPhase", "GoalkeeperDistribution")
end

function Service.PositionTarget(context: any, keeper: any): Vector3
	local ballPitch = context.BallTeam[keeper.Side]
	local owner = context.Owner
	local ownPossession = owner ~= nil and owner:GetAttribute("VTRTeam") == keeper.Side
	local halfLength = PitchConfig.PITCH_LENGTH * 0.5
	local frontEdge = PitchConfig.Zones.OwnBox.ZMax + 42
	local lineDepth = 18
	local state = "GoalkeeperReady"
	local z = lineDepth
	if context.MotionKind == "Shot" or typeof(context.ShotTargetWorld) == "Vector3" then
		state = "SaveAttempt"
		z = math.clamp(ballPitch.Z * .45, 22, PitchConfig.Zones.OwnBox.ZMax - 18)
	elseif context.Owner == nil and PitchConfig.InZone(ballPitch, "OwnBox") and Service.ShouldRush(context, keeper) then
		state = "SweepLooseBall"
		z = math.clamp(ballPitch.Z, 12, PitchConfig.Zones.OwnBox.ZMax + 14)
	elseif ownPossession and ballPitch.Z > halfLength then
		state = "SupportPossession"
		local advance = math.clamp((ballPitch.Z - halfLength) / halfLength, 0, 1)
		z = lineDepth + (frontEdge - lineDepth) * advance
	elseif ownPossession then
		state = keeper.Model:GetAttribute("VTRGoalkeeperHolding") == true and "HoldBall" or "ShiftWithBall"
		z = math.clamp(42 + ballPitch.Z * .25, lineDepth, PitchConfig.Zones.OwnBox.ZMax + 10)
	elseif ballPitch.Z <= PitchConfig.Zones.OwnBox.ZMax + 105 then
		state = "DefendApproach"
		z = math.clamp(24 + ballPitch.Z * .28, lineDepth, PitchConfig.Zones.OwnBox.ZMax - 10)
	else
		state = "RecoverPosition"
		z = math.clamp(32 + math.max(0, ballPitch.Z - halfLength) * .12, lineDepth, PitchConfig.Zones.OwnBox.ZMax)
	end
	local ballToCenter = ballPitch.X - PitchConfig.HALF_WIDTH
	local coverScale = ownPossession and 0.34 or state == "SaveAttempt" and 0.82 or 0.64
	local x = PitchConfig.HALF_WIDTH + ballToCenter * coverScale
	local targetPitch = Vector3.new(math.clamp(x, 132, 292), 3, math.clamp(z, lineDepth, frontEdge))
	local targetWorld = PitchConfig.TeamPitchPositionToWorld(targetPitch, keeper.Side, context.Options)
	setDebug(keeper, "GKState", state)
	setDebug(keeper, "GKPositionTarget", targetWorld)
	setDebug(keeper, "GKLateralShift", targetPitch.X - PitchConfig.HALF_WIDTH)
	setDebug(keeper, "GKForwardDepth", targetPitch.Z)
	setDebug(keeper, "GKSweepTarget", state == "SweepLooseBall" and context.BallWorld or nil)
	setDebug(keeper, "GKSweepArrivalTime", state == "SweepLooseBall" and keeperArrival(keeper, context.BallWorld) or nil)
	setDebug(keeper, "GKNearestAttackerArrival", nearestAttackerArrival(context, keeper.Side, context.BallWorld))
	setDebug(keeper, "GKCanUseHands", targetPitch.Z <= PitchConfig.Zones.OwnBox.ZMax)
	setDebug(keeper, "GKReadyStance", state == "GoalkeeperReady" or state == "DefendApproach" or state == "SaveAttempt")
	setDebug(keeper, "GKRecoveryTarget", state == "RecoverPosition" and targetWorld or nil)
	return targetWorld
end

function Service.ShouldRush(context: any, keeper: any): boolean
	if not keeper.Root then
		return false
	end
	local ballPitch = context.BallTeam[keeper.Side]
	if not PitchConfig.InZone(ballPitch, "OwnBox") or (context.BallVelocity.Magnitude < 8 and context.Owner ~= nil) then
		return false
	end
	local keeperDistance = PitchConfig.GetDistanceStuds(keeper.World, context.BallWorld)
	local nearestAttackerDistance = math.huge
	for _, attacker in ipairs(context.Teams[keeper.OpponentSide].List) do
		if attacker.Root then
			nearestAttackerDistance = math.min(nearestAttackerDistance, PitchConfig.GetDistanceStuds(attacker.World, context.BallWorld))
		end
	end
	return keeperDistance < nearestAttackerDistance - 8 or (keeper.Stats.overall or 60) > 78 and keeperDistance < nearestAttackerDistance - 3
end

function Service.ChooseDistribution(context: any, keeper: any): any?
	setDebug(keeper, "GKState", "DistributeBall")
	local bestLong = nil
	local bestLongScore = -math.huge
	local bestShort = nil
	local bestShortScore = -math.huge
	for _, teammate in ipairs(context.Teams[keeper.Side].List) do
		if teammate.Model ~= keeper.Model and teammate.Root and not teammate.IsGoalkeeper then
			local distance = PitchConfig.GetDistanceStuds(keeper.World, teammate.World)
			local open = select(1, AIContextBuilder.IsOpen(context, teammate))
			local openness = nearestOpponentDistance(context, keeper.Side, teammate.World)
			local roleScore = rolePriority(tostring(teammate.Role or ""))
			local targetPitch = distributionTargetPitch(teammate, isWideOutlet(teammate) and distance >= 82)
			local targetWorld = PitchConfig.TeamPitchPositionToWorld(targetPitch, keeper.Side, context.Options)
			local longOutlet = isWideOutlet(teammate) and distance >= 82 and distance <= 238 and teammate.Pitch.Z >= 150
			if longOutlet then
				local laneClear = AIContextBuilder.PassingLaneClear(context, keeper, targetWorld, "Lofted")
				local targetOpen = nearestOpponentDistance(context, keeper.Side, targetWorld)
				local score = (open and 20 or -4) + (laneClear and 22 or -26) + math.clamp(targetOpen, 0, 32) * .9 + roleScore * 7 + teammate.Pitch.Z * .035 - math.abs(distance - 178) * .08
				if laneClear and targetOpen >= 10 and score > bestLongScore then
					bestLong = {Receiver = teammate, Target = targetWorld, Distance = PitchConfig.GetDistanceStuds(keeper.World, targetWorld), PassKind = "Lofted", Score = score, Kind = "GoalkeeperLongWing", Safe = true, LaneClear = true}
					bestLongScore = score
				end
			end
			if isShortBuildoutRole(teammate) and distance <= 132 then
				local shortTargetPitch = distributionTargetPitch(teammate, false)
				local shortTargetWorld = PitchConfig.TeamPitchPositionToWorld(shortTargetPitch, keeper.Side, context.Options)
				local laneClear = AIContextBuilder.PassingLaneClear(context, keeper, shortTargetWorld, "Ground")
				local targetOpen = nearestOpponentDistance(context, keeper.Side, shortTargetWorld)
				local score = (open and 18 or -5) + (laneClear and 22 or -30) + math.clamp(openness, 0, 28) * .65 + math.clamp(targetOpen, 0, 28) * .45 + roleScore * 5 - math.abs(distance - 54) * .18 + teammate.Pitch.Z * .025
				if laneClear and targetOpen >= 8 and score > bestShortScore then
					bestShort = {Receiver = teammate, Target = shortTargetWorld, Distance = PitchConfig.GetDistanceStuds(keeper.World, shortTargetWorld), PassKind = "Ground", Score = score, Kind = "GoalkeeperShortBuildout", Safe = true, LaneClear = true}
					bestShortScore = score
				end
			end
		end
	end
	local pass = bestLong or bestShort
	setDebug(keeper, "GKDistributionType", pass and (pass.PassKind == "Lofted" and "LongWing" or "ShortBuildout") or "Hold")
	setDebug(keeper, "GKDistributionReceiver", pass and pass.Receiver and pass.Receiver.Model and pass.Receiver.Model.Name or "")
	setDebug(keeper, "GKDistributionTarget", pass and pass.Target or nil)
	setDebug(keeper, "GKLongWingAvailable", bestLong ~= nil)
	setDebug(keeper, "GKShortOptionAvailable", bestShort ~= nil)
	if pass then
		primeDistributionReceiver(context, keeper, pass)
	end
	return pass
end

return Service
