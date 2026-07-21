--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)
local PenaltyBoxService = require(script.Parent.Parent.PenaltyBoxService)
local AITacticalContract = require(script.Parent.AITacticalContract)

local Planner = {}
Planner.__index = Planner

local function clamp(value: number, low: number, high: number): number
	return math.clamp(value, math.min(low, high), math.max(low, high))
end

local function sideOf(x: number): string
	if x < PitchConfig.HALF_WIDTH - 40 then return "Left" end
	if x > PitchConfig.HALF_WIDTH + 40 then return "Right" end
	return "Center"
end

local function defensiveFunction(id: string, duty: string?): string
	local name = tostring(duty or id)
	if name == "PrimaryPress" then return "Presser" end
	if name == "CoverPress" then return "CoverPress" end
	if name == "PivotLaneBlock" or name == "CentralLaneBlock" then return "LaneBlock" end
	if name == "CutbackProtect" or name == "FarPostProtect" or name == "BackLine" or name == "WideZone" then return "RestDefense" end
	return name
end

local function slot(id: string, family: string, pitch: Vector3, priority: number, rest: boolean?, sprint: boolean?, duty: string?, lockedModel: Model?, allowedRoles: {string}?): any
	local targetPitch = PitchConfig.ClampInsidePitch(pitch)
	local isRest = rest == true
	local line = (family == "CB" or family == "Fullback") and "Back" or family == "ST" and "Forward" or "Midfield"
	local lane = targetPitch.X < 145 and "Left" or targetPitch.X > 279 and "Right" or "Central"
	local actions = isRest and {"Cover", "Tackle", "Clear", "Receive", "Pass"} or {"Press", "Tackle", "Cover", "Receive", "Pass"}
	local slotData = AITacticalContract.Slot({
		Id = id,
		Function = defensiveFunction(id, duty),
		RoleFamily = family,
		AllowedRoles = allowedRoles or {family},
		PreferredRoles = {family},
		TargetPitch = targetPitch,
		TargetRegion = AITacticalContract.Region(targetPitch, isRest and 15 or 20, lane, line),
		Lane = lane,
		Line = line,
		ActionProfile = isRest and "RestDefender" or "Presser",
		Priority = priority,
		RestDefense = isRest,
		ContinuityKey = string.format("%03d:%s:%s", 999 - math.floor(priority), id, tostring(duty or id)),
		SprintAllowed = sprint == true,
		AllowedActions = actions,
		ForbiddenActions = isRest and {"Shoot", "Dribble", "RiskDribble", "BoxRun", "CarryForward"} or {},
		CoverRequirement = isRest and "ProtectGoalSide" or "CloseBallSide",
	})
	slotData.DefensiveDuty = duty or id
	slotData.LockedModel = lockedModel
	return slotData
end

local function goalkeeperSlot(pitch: Vector3, high: boolean): any
	local targetPitch = PitchConfig.ClampInsidePitch(pitch)
	return AITacticalContract.Slot({
		Id = "goalkeeper-sweeper-cover",
		Function = "Sweeper cover",
		RoleFamily = "GK",
		AllowedRoles = {"GK"},
		PreferredRoles = {"GK"},
		TargetPitch = targetPitch,
		TargetRegion = AITacticalContract.Region(targetPitch, 20, "Central", "Goalkeeper"),
		Lane = "Central",
		Line = "Goalkeeper",
		ActionProfile = "Goalkeeper",
		Priority = 99,
		ContinuityKey = "000:goalkeeper-sweeper-cover",
		SprintAllowed = high,
		AllowedActions = {"Receive", "Pass", "Clear", "Cover"},
	})
end

local function nearestRole(context: any, side: string, roleSet: {[string]: boolean}, target: Vector3, used: {[Model]: boolean}): any?
	local best = nil
	local bestScore = math.huge
	for _, info in ipairs(context.Teams[side].List) do
		if info.Root and not info.IsUserControlled and not used[info.Model] then
			local rolePenalty = roleSet[info.Role] and 0 or 38
			local distance = PitchConfig.GetDistanceStuds(info.Pitch, target)
			local stamina = math.clamp(tonumber(info.Stamina) or tonumber(info.Model:GetAttribute("VTRSprintEnergy")) or 75, 0, 100)
			local score = distance + rolePenalty - stamina * .05
			if score < bestScore then
				best = info
				bestScore = score
			end
		end
	end
	return best
end

local function opponentClosest(context: any, defendingSide: string, roleSet: {[string]: boolean}?, target: Vector3, preferWide: boolean?): any?
	local opponentSide = defendingSide == "Home" and "Away" or "Home"
	local best = nil
	local bestScore = math.huge
	for _, info in ipairs(((context.Teams or {})[opponentSide] or {}).List or {}) do
		if info.Root then
			local pitch = PitchConfig.WorldToTeamPitchPosition(info.World, defendingSide, context.Options)
			local rolePenalty = roleSet and not roleSet[info.Role] and 34 or 0
			local wideBonus = preferWide and math.abs(pitch.X - PitchConfig.HALF_WIDTH) > 86 and -12 or 0
			local score = PitchConfig.GetDistanceStuds(pitch, target) + rolePenalty + wideBonus
			if score < bestScore then
				best = {Info = info, Pitch = pitch, World = info.World}
				bestScore = score
			end
		end
	end
	return best
end

local function opponentGoalFacing(info: any, pitch: Vector3): boolean
	local root = info.Root
	if not root then
		return false
	end
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local goalward = Vector3.new(PitchConfig.HALF_WIDTH - pitch.X, 0, -math.max(1, pitch.Z))
	local facingGoal = facing.Magnitude > .01 and goalward.Magnitude > .01 and facing.Unit:Dot(goalward.Unit) > .18
	local carryingGoalward = moving.Magnitude > 4 and moving.Unit:Dot(Vector3.new(0, 0, -1)) > .22
	return facingGoal or carryingGoalward
end

local function carrierInfo(context: any, side: string): any?
	local owner = context.Owner
	if not owner then
		return nil
	end
	local info = context.Players and context.Players[owner]
	if not info or info.Side == side then
		return nil
	end
	local pitch = PitchConfig.WorldToTeamPitchPosition(info.World, side, context.Options)
	return {Info = info, Pitch = pitch, World = info.World}
end

local function carrierPressure(context: any, side: string, point: Vector3): any
	local closest = math.huge
	local active = 0
	local cover = 0
	for _, info in ipairs(((context.Teams or {})[side] or {}).List or {}) do
		if info.Root then
			local distance = PitchConfig.GetDistanceStuds(info.Pitch, point)
			closest = math.min(closest, distance)
			local assignment = tostring(info.Model:GetAttribute("currentAssignment") or info.Model:GetAttribute("AIDefensiveDuty") or "")
			local pressing = assignment == "PressBallCarrier" or assignment == "ContainBallCarrier" or assignment == "StepToCarrier" or assignment == "EdgeOfBoxPress" or assignment == "CarrierBreachPress"
			if pressing or distance <= 10 then
				active += 1
			end
			if info.Pitch.Z < point.Z - 18 and (info.Role == "CB" or info.Role == "Fullback" or info.Role == "CDM") then
				cover += 1
			end
		end
	end
	return {Closest = closest, Active = active, Cover = cover}
end

function Planner.new(): any
	return setmetatable({Duties = {Home = {}, Away = {}}, LineStates = {Home = nil, Away = nil}}, Planner)
end

function Planner:Reset(side: string?)
	if side then
		self.Duties[side] = {}
		self.LineStates[side] = nil
	else
		self.Duties = {Home = {}, Away = {}}
		self.LineStates = {Home = nil, Away = nil}
	end
end

function Planner:Build(context: any, side: string, style: any, intent: any): any
	local now = context.Now or os.clock()
	local ball = context.BallTeam[side]
	local widthRatio = style and style:Ratio("DefensiveWidth") or .5
	local depthRatio = style and style:Ratio("DefensiveDepth") or .5
	local compact = style and style:Ratio("BackLineCompactness") or .58
	local zone = style and style:Ratio("ZoneDiscipline") or .58
	local box = style and style:Ratio("BoxProtection") or .58
	local lane = style and style:Ratio("LaneBlocking") or .55
	local press = style and style:Ratio("PressingIntensity") or .5
	local intentName = tostring(intent and intent.Intent or "")
	local teamBrain = context.TeamBrain and context.TeamBrain[side]
	local reaction = context.TeamReactions and context.TeamReactions[side] and context.TeamReactions[side].AgainstOpponentAttack
	local pressRules = context.RuleEffects and context.RuleEffects[side] and context.RuleEffects[side].Press
	if teamBrain then
		depthRatio = math.clamp(tonumber(teamBrain.DefensiveLineHeight) or depthRatio, 0, 1)
		compact = math.clamp(tonumber(teamBrain.TeamCompactness) or compact, 0, 1)
		press = math.clamp(tonumber(teamBrain.PressingIntensity) or press, 0, 1)
		if teamBrain.DefensiveIdentity == "BoxProtection" then
			depthRatio = math.min(depthRatio, .32)
			box = math.max(box, .86)
			compact = math.max(compact, .84)
		elseif teamBrain.DefensiveIdentity == "CollectiveHunt" then
			depthRatio = math.max(depthRatio, .72)
			press = math.max(press, .86)
		elseif teamBrain.DefensiveIdentity == "CentralLock" or teamBrain.DefensiveIdentity == "LaneDisruption" then
			lane = math.max(lane, .84)
			compact = math.max(compact, .78)
		elseif teamBrain.DefensiveIdentity == "FlankIsolation" then
			zone = math.max(zone, .72)
		elseif teamBrain.OpponentIdentity == "DirectAssault" then
			depthRatio = math.min(depthRatio, .42)
			compact = math.max(compact, .72)
		end
	end
	if reaction then
		depthRatio = math.clamp(depthRatio + (tonumber(reaction.LineHeight) or 0), 0, 1)
		widthRatio = math.clamp(widthRatio + (tonumber(reaction.BlockWidth) or 0), 0, 1)
		compact = math.clamp(compact + (tonumber(reaction.CentralScreens) or 0) * .34 + (tonumber(reaction.ZoneDiscipline) or 0) * .24, 0, 1)
		lane = math.clamp(lane + (tonumber(reaction.LaneProtection) or 0) + (tonumber(reaction.ForceOutside) or 0) * .4, 0, 1)
		box = math.clamp(box + (tonumber(reaction.CutbackProtection) or 0) + (tonumber(reaction.FarPostProtection) or 0) + (tonumber(reaction.DepthCover) or 0) * .3, 0, 1)
		press = math.clamp(press + (tonumber(reaction.PressChase) or 0) + (tonumber(reaction.LooseBallOvercommit) or 0), 0, 1)
	end
	if pressRules then
		depthRatio = math.clamp(depthRatio + (tonumber(pressRules.PressHeight) or 0), 0, 1)
		press = math.clamp(press + (tonumber(pressRules.Pressers) or 0) * .18, 0, 1)
	end
	local low = intentName == "LowBlock" or intentName == "ProtectLead"
	local resetPress = intentName == "OpponentResetPress" or intentName ~= "PressBroken" and context.OpponentResetPress and context.OpponentResetPress[side] and context.OpponentResetPress[side].Active == true
	local high = intentName == "HighPress" or intentName == "HighPressBuildUp" or intentName == "HighPressLocked" or intentName == "HighPressCompression" or resetPress
	local compression = intentName == "HighPressCompression"
	local boxMetrics = PenaltyBoxService.DefensiveBoxMetrics(side, context.Options)
	local boxEdgeZ = tonumber(boxMetrics.BoxEdgeZ) or PitchConfig.Zones.OwnBox.ZMax
	local carrier = carrierInfo(context, side)
	local carrierPitch = carrier and carrier.Pitch or ball
	local centralCarrier = carrier and math.abs(carrierPitch.X - PitchConfig.HALF_WIDTH) <= 74
	local carrierOutsideBox = carrier and carrierPitch.Z > boxEdgeZ + 2
	local carrierNearEdge = carrierOutsideBox and carrierPitch.Z <= boxEdgeZ + 96
	local carrierAttackingBox = carrier and opponentGoalFacing(carrier.Info, carrierPitch)
	local targetPitch = context.PassTargetTeam and context.PassTargetTeam[side]
	local ballInstance = context.Ball or context.World and context.World.Ball
	local crossIncoming = ballInstance and (ballInstance:GetAttribute("VTRCrossActive") == true or ballInstance:GetAttribute("VTRCutbackActive") == true) or false
	local pressure = carrier and carrierPressure(context, side, carrierPitch) or {Closest = math.huge, Active = 0, Cover = 0}
	local backwardOrSidewaysPass = context.PassInFlight == true and typeof(targetPitch) == "Vector3" and targetPitch.Z >= ball.Z - 6
	local carrierTurningAway = carrier and not carrierAttackingBox and carrierOutsideBox
	local noPressureAdvance = carrierOutsideBox and carrierAttackingBox and pressure.Closest > 10
	local advanceLine = backwardOrSidewaysPass or carrierTurningAway
	local throughPassBehind = context.PassInFlight == true and typeof(targetPitch) == "Vector3" and targetPitch.Z <= boxEdgeZ + 14 and targetPitch.Z < ball.Z - 34
	local attackerInBox = false
	local dangerousRunnerBehind = false
	local highestRunner = nil
	for _, opponent in ipairs(((context.Teams or {})[side == "Home" and "Away" or "Home"] or {}).List or {}) do
		if opponent.Root then
			local pitch = PitchConfig.WorldToTeamPitchPosition(opponent.World, side, context.Options)
			if pitch.Z <= boxEdgeZ + 2 and pitch.X >= boxMetrics.XMin and pitch.X <= boxMetrics.XMax then
				attackerInBox = true
			end
			if (opponent.Role == "ST" or opponent.Role == "Winger" or opponent.Role == "CAM") and pitch.Z <= boxEdgeZ + 22 and pitch.Z < ball.Z - 28 then
				local nearest = opponentClosest(context, side, {CB = true, Fullback = true, CDM = true}, pitch, false)
				local unmarked = nearest == nil or PitchConfig.GetDistanceStuds(nearest.Pitch, pitch) > 28
				if unmarked then
					dangerousRunnerBehind = true
					highestRunner = {Info = opponent, Pitch = pitch, World = opponent.World}
				end
			end
		end
	end
	local previousLine = self.LineStates[side]
	local lineState = "HoldEdge"
	local emergencyReason = ""
	if resetPress then
		lineState = "HoldEdge"
	elseif low then
		lineState = "LowBlock"
	elseif throughPassBehind or intentName == "PressBroken" then
		lineState = "EmergencyDrop"
		emergencyReason = throughPassBehind and "ThroughPassBehind" or "PressBroken"
	elseif previousLine == "EmergencyDrop" and (advanceLine or not dangerousRunnerBehind and not attackerInBox) then
		lineState = "RecoverForward"
	elseif advanceLine and not dangerousRunnerBehind and not attackerInBox then
		lineState = "RecoverForward"
	elseif attackerInBox and ball.Z <= boxEdgeZ + 4 then
		lineState = "ProtectSixYardBox"
		emergencyReason = "AttackerInsideBox"
	elseif attackerInBox and carrierOutsideBox then
		lineState = "ContainAtEdge"
		emergencyReason = "BoxRunnerHeldAtEdge"
	elseif dangerousRunnerBehind then
		lineState = "TrackDepthRun"
		emergencyReason = "RunnerBehind"
	elseif noPressureAdvance then
		lineState = carrierNearEdge and "ContainAtEdge" or "StepToCarrier"
	elseif centralCarrier and carrierNearEdge and carrierAttackingBox and context.PassInFlight ~= true then
		lineState = "ContainAtEdge"
	elseif carrierOutsideBox and carrierPitch.Z <= boxEdgeZ + 70 and carrierAttackingBox then
		lineState = "StepToCarrier"
	end
	local threatResolved = previousLine == "EmergencyDrop" and (lineState == "HoldEdge" or lineState == "RecoverForward")
	self.LineStates[side] = lineState
	local outsideBoxWithoutDepth = ball.Z > boxEdgeZ + 2 and not throughPassBehind and not dangerousRunnerBehind and not attackerInBox and not crossIncoming
	local edgeAnchor = clamp(boxEdgeZ + 18 + depthRatio * 24 - box * 8, boxEdgeZ + 4, boxEdgeZ + 44)
	local nearBoxAnchor = clamp(boxEdgeZ + 8 + depthRatio * 14 - box * 4, boxEdgeZ + 4, boxEdgeZ + 24)
	local lowAnchor = clamp(boxEdgeZ + 2 + depthRatio * 10, boxEdgeZ + 2, boxEdgeZ + 14)
	local emergencyAnchor = tonumber(boxMetrics.EmergencyBoxAnchorZ) or math.max(28, boxEdgeZ - 48)
	local trueEmergencyDrop = lineState == "EmergencyDrop" or lineState == "ProtectSixYardBox" and ball.Z <= boxEdgeZ + 4
	local resetData = context.OpponentResetPress and context.OpponentResetPress[side] or nil
	local resetTarget = resetData and typeof(resetData.TargetPitch) == "Vector3" and resetData.TargetPitch or typeof(targetPitch) == "Vector3" and targetPitch or ball
	local depthThreatAdjustment = dangerousRunnerBehind and 42 or throughPassBehind and 70 or 0
	local minimumHighLineZ = clamp(PitchConfig.HALF_LENGTH - 28 + depthRatio * 36 + press * 28 - depthThreatAdjustment, PitchConfig.HALF_LENGTH - 42, PitchConfig.HALF_LENGTH + 36)
	local minimumBackLineZ = edgeAnchor
	if resetPress then
		minimumBackLineZ = minimumHighLineZ
	elseif high then
		minimumBackLineZ = compression and 330 or 250
	elseif lineState == "LowBlock" then
		minimumBackLineZ = trueEmergencyDrop and math.max(emergencyAnchor, boxEdgeZ - 20) or lowAnchor
	elseif trueEmergencyDrop then
		minimumBackLineZ = emergencyAnchor
	elseif lineState == "TrackDepthRun" then
		minimumBackLineZ = nearBoxAnchor
	elseif lineState == "StepToCarrier" or lineState == "ContainAtEdge" or lineState == "RecoverForward" then
		minimumBackLineZ = nearBoxAnchor
	elseif outsideBoxWithoutDepth then
		minimumBackLineZ = edgeAnchor
	end
	local blockWidth = clamp(190 + widthRatio * 86 - compact * 42, 152, 258)
	local centerShift = clamp((ball.X - PitchConfig.HALF_WIDTH) * (.22 + zone * .18), -32, 32)
	local centerX = clamp(PitchConfig.HALF_WIDTH + centerShift, 110, 314)
	local backZ = low and clamp(64 + depthRatio * 74, 58, 148) or high and clamp(285 + depthRatio * 145, 260, 455) or clamp(132 + depthRatio * 178, 112, 330)
	backZ = math.max(backZ, minimumBackLineZ)
	if trueEmergencyDrop then
		backZ = clamp(boxEdgeZ - 28 + depthRatio * 18, emergencyAnchor, boxEdgeZ + 6)
	elseif lineState == "TrackDepthRun" then
		backZ = clamp(boxEdgeZ + 8 + depthRatio * 14, minimumBackLineZ, boxEdgeZ + 24)
	elseif lineState == "LowBlock" then
		backZ = clamp(backZ, minimumBackLineZ, boxEdgeZ + 12)
	elseif lineState == "RecoverForward" then
		backZ = clamp(math.max(backZ, nearBoxAnchor + 4), nearBoxAnchor, boxEdgeZ + 38)
	end
	if resetPress then
		backZ = clamp(math.max(backZ, minimumHighLineZ), minimumHighLineZ, PitchConfig.HALF_LENGTH + 52)
	end
	if not high and not trueEmergencyDrop then
		backZ = math.max(backZ, minimumBackLineZ)
	end
	if not high and not low and not trueEmergencyDrop and ball.Z > boxEdgeZ + 120 then
		backZ = math.max(backZ, clamp(ball.Z - 115, boxEdgeZ + 38, 410))
	end
	if noPressureAdvance and not high and not trueEmergencyDrop then
		backZ = math.max(backZ, clamp(carrierPitch.Z - (carrierNearEdge and 32 or 44), minimumBackLineZ, carrierNearEdge and boxEdgeZ + 42 or 430))
	end
	if not high and (lineState == "StepToCarrier" or lineState == "ContainAtEdge" or lineState == "RecoverForward" or lineState == "HoldEdge") and ball.Z <= boxEdgeZ + 120 then
		backZ = clamp(backZ, minimumBackLineZ, math.max(minimumBackLineZ, math.min(boxEdgeZ + 42, carrierPitch.Z - 12)))
	end
	local backMidGap = clamp(58 - compact * 20 + (low and -8 or high and 6 or 0), 36, 58)
	local midForwardGap = clamp(68 - compact * 18 + (high and 5 or 0), 40, 68)
	local midZ = clamp(backZ + backMidGap, 96, 540)
	local forwardZ = clamp(midZ + midForwardGap, 138, 630)
	local pressAnchorZ = ball.Z
	if resetPress then
		pressAnchorZ = clamp(resetTarget.Z, 500, 706)
		local forwardMidGap = clamp(48 - compact * 8 - press * 6, 34, 52)
		local midBackGap = clamp(56 - compact * 8 - press * 5, 38, 58)
		forwardZ = clamp(pressAnchorZ - 8, PitchConfig.HALF_LENGTH + 38, 704)
		midZ = clamp(forwardZ - forwardMidGap, PitchConfig.HALF_LENGTH + 2, 660)
		backZ = clamp(math.max(midZ - midBackGap, minimumHighLineZ), minimumHighLineZ, 610)
		backMidGap = midZ - backZ
		midForwardGap = forwardZ - midZ
	elseif high then
		local threatZ = 0
		local fastestThreat = 0
		for _, opponent in ipairs(((context.Teams or {})[side == "Home" and "Away" or "Home"] or {}).List or {}) do
			if opponent.Root then
				local pitch = PitchConfig.WorldToTeamPitchPosition(opponent.World, side, context.Options)
				if pitch.Z < ball.Z - 20 then
					threatZ = math.max(threatZ, pitch.Z)
					fastestThreat = math.max(fastestThreat, tonumber(opponent.Stats and opponent.Stats.pace) or 60)
				end
			end
		end
		local targetPitch = context.PassTargetTeam and context.PassTargetTeam[side]
		if typeof(targetPitch) == "Vector3" and targetPitch.Z > pressAnchorZ - 12 then
			pressAnchorZ = math.max(pressAnchorZ, targetPitch.Z)
		end
		local speedThreat = threatZ > 0 and math.clamp((fastestThreat - 62) / 35, 0, 1) or .2
		local forwardMidGap = clamp((compression and 42 or 45) - compact * 10 - press * 7, 30, compression and 44 or 45)
		local midBackGap = clamp((compression and 50 or 48) - compact * 9 - zone * 5 + speedThreat * 10, 38, compression and 58 or 54)
		forwardZ = clamp(pressAnchorZ - (compression and 12 or 6), 410, 696)
		midZ = clamp(forwardZ - forwardMidGap, 330, 650)
		backZ = clamp(midZ - midBackGap, compression and 330 or 250, 570)
		backMidGap = midZ - backZ
		midForwardGap = forwardZ - midZ
	end
	if reaction then
		local gapAdjust = (tonumber(reaction.LineGap) or 0) * 42
		backMidGap = clamp(backMidGap + gapAdjust, 30, 64)
		midForwardGap = clamp(midForwardGap + gapAdjust, 34, 74)
		if not high then
			midZ = clamp(backZ + backMidGap, 96, 540)
			forwardZ = clamp(midZ + midForwardGap, 138, 630)
		end
	end
	local defensiveLineReach = math.clamp(tonumber(style and style.Get and style:Get("DefensiveLineStepUp")) or 50, 0, 100)
	local backLineCeilingZ = PitchConfig.HALF_LENGTH + math.floor(4 + defensiveLineReach * .32 + .5)
	if not trueEmergencyDrop and backZ > backLineCeilingZ then
		backZ = backLineCeilingZ
		backMidGap = midZ - backZ
	end
	local halfWidth = blockWidth * .5
	local leftX = clamp(centerX - halfWidth * .45, 42, 180)
	local rightX = clamp(centerX + halfWidth * .45, 244, 382)
	local farSideTuck = clamp(20 + zone * 25 + compact * 12, 20, 52)
	if reaction then
		farSideTuck = clamp(farSideTuck + (tonumber(reaction.FarPostProtection) or 0) * 24 + (tonumber(reaction.SwitchDefender) or 0) * 18, 20, 72)
	end
	local ballSide = sideOf(ball.X)
	local forceDirection = ballSide == "Left" and "TouchlineLeft" or ballSide == "Right" and "TouchlineRight" or "Backward"
	if pressRules and pressRules.PressDirection then
		forceDirection = tostring(pressRules.PressDirection)
	end
	local used: {[Model]: boolean} = {}
	local primaryAnchor = resetPress and resetTarget or ball
	local primaryTarget = Vector3.new(primaryAnchor.X + (ballSide == "Left" and 12 or ballSide == "Right" and -12 or 0), 3, clamp(primaryAnchor.Z - 2, 48, PitchConfig.PITCH_LENGTH - 18))
	local primary = nearestRole(context, side, {ST = true, Winger = true, CAM = true}, primaryTarget, used)
	if primary then used[primary.Model] = true end
	local nearOutlet = opponentClosest(context, side, {Fullback = true, Winger = true, CB = true, GK = true}, Vector3.new(primaryAnchor.X, 3, primaryAnchor.Z - 10), true)
	local centralOutlet = opponentClosest(context, side, {CDM = true, CM = true, CAM = true}, Vector3.new(PitchConfig.HALF_WIDTH, 3, primaryAnchor.Z - 26), false)
	local farOutlet = opponentClosest(context, side, {CB = true, Fullback = true, GK = true}, Vector3.new(ballSide == "Left" and 318 or 106, 3, primaryAnchor.Z - 8), true)
	local nearOutletTarget = nearOutlet and Vector3.new(nearOutlet.Pitch.X + (PitchConfig.HALF_WIDTH - nearOutlet.Pitch.X) * .18, 3, clamp(nearOutlet.Pitch.Z - 12, midZ, forwardZ + 8)) or Vector3.new(ballSide == "Left" and 96 or 328, 3, clamp(ball.Z - 18, midZ, forwardZ))
	local centralTarget = centralOutlet and Vector3.new(centralOutlet.Pitch.X, 3, clamp(centralOutlet.Pitch.Z - 14, midZ - 8, forwardZ)) or Vector3.new(PitchConfig.HALF_WIDTH, 3, clamp(ball.Z - 28, midZ - 4, forwardZ))
	local farTarget = farOutlet and Vector3.new((farOutlet.Pitch.X + PitchConfig.HALF_WIDTH) * .5, 3, clamp(farOutlet.Pitch.Z - 14, midZ, forwardZ)) or Vector3.new(ballSide == "Left" and 294 or 130, 3, clamp(ball.Z - 24, midZ, forwardZ))
	local nearPresser = nearestRole(context, side, {Winger = true, ST = true, CAM = true, Fullback = high}, nearOutletTarget, used)
	if nearPresser then used[nearPresser.Model] = true end
	local centralPresser = nearestRole(context, side, {CAM = true, CM = true, ST = true}, centralTarget, used)
	if centralPresser then used[centralPresser.Model] = true end
	local farPresser = nearestRole(context, side, {Winger = true, ST = true, CAM = true}, farTarget, used)
	if farPresser then used[farPresser.Model] = true end
	local supportTarget = Vector3.new(clamp(PitchConfig.HALF_WIDTH + (ball.X - PitchConfig.HALF_WIDTH) * .28, 100, 324), 3, clamp(ball.Z - 42, backZ + 18, midZ + 18))
	local support = nearestRole(context, side, {CM = true, CAM = true, CDM = true}, supportTarget, used)
	if support then used[support.Model] = true end
	local centralSupportTarget = Vector3.new(PitchConfig.HALF_WIDTH, 3, clamp(ball.Z - 52, backZ + 18, midZ + 10))
	local centralSupport = nearestRole(context, side, {CM = true, CDM = true, CAM = true}, centralSupportTarget, used)
	if centralSupport then used[centralSupport.Model] = true end
	local pivotTarget = Vector3.new(clamp(PitchConfig.HALF_WIDTH + centerShift * .35, 125, 299), 3, clamp(ball.Z - 62, backZ + 14, midZ))
	local pivot = nearestRole(context, side, {CDM = true, CM = true}, pivotTarget, used)
	if pivot then used[pivot.Model] = true end
	local stepTarget = Vector3.new(carrierPitch.X + (PitchConfig.HALF_WIDTH - carrierPitch.X) * .18, 3, clamp(backZ + 14, backZ + 8, math.max(backZ + 8, carrierPitch.Z - 6)))
	local stepDefender = nil
	if lineState == "StepToCarrier" or lineState == "ContainAtEdge" then
		local stepRoles = noPressureAdvance and not carrierNearEdge and {CDM = true, CM = true, CAM = true, Fullback = true} or {CB = true, Fullback = true, CDM = true, CM = true}
		stepDefender = nearestRole(context, side, stepRoles, stepTarget, used)
		if stepDefender then used[stepDefender.Model] = true end
	end
	local insideCoverTarget = Vector3.new(clamp(PitchConfig.HALF_WIDTH + (carrierPitch.X - PitchConfig.HALF_WIDTH) * .18, 132, 292), 3, clamp(backZ - 12, minimumBackLineZ - 18, backZ - 6))
	local farCoverX = carrierPitch.X < PitchConfig.HALF_WIDTH and clamp(rightX - farSideTuck * .35, 222, 350) or clamp(leftX + farSideTuck * .35, 74, 202)
	local farCoverTarget = Vector3.new(farCoverX, 3, clamp(backZ - 8, minimumBackLineZ - 14, backZ + 2))
	local deepCoverTarget = Vector3.new(ballSide == "Left" and rightX or leftX, 3, clamp(backZ - (high and 10 or 0), 48, 560))
	local highestThreat = opponentClosest(context, side, {ST = true, Winger = true, CAM = true}, Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(80, backZ - 22)), false)
	if highestThreat and high then
		deepCoverTarget = Vector3.new(highestThreat.Pitch.X + (PitchConfig.HALF_WIDTH - highestThreat.Pitch.X) * .2, 3, clamp(math.min(backZ - 10, highestThreat.Pitch.Z - 8), 80, backZ - 8))
	end
	if lineState == "StepToCarrier" or lineState == "ContainAtEdge" or lineState == "RecoverForward" or lineState == "HoldEdge" or lineState == "LowBlock" then
		deepCoverTarget = Vector3.new(deepCoverTarget.X, 3, clamp(backZ - 8, minimumBackLineZ, backZ - 4))
	elseif lineState == "TrackDepthRun" and highestRunner then
		deepCoverTarget = Vector3.new(highestRunner.Pitch.X + (PitchConfig.HALF_WIDTH - highestRunner.Pitch.X) * .16, 3, clamp(math.min(backZ - 8, highestRunner.Pitch.Z - 4), minimumBackLineZ, backZ - 4))
	end
	if high then
		local maxDepth = press >= .82 and 120 or 145
		deepCoverTarget = Vector3.new(deepCoverTarget.X, 3, math.max(deepCoverTarget.Z, forwardZ - maxDepth))
	end
	local deepCover = nearestRole(context, side, {CB = true, Fullback = true}, deepCoverTarget, used)
	if deepCover then used[deepCover.Model] = true end
	local cutbackZ = trueEmergencyDrop and clamp(92 + box * 52, 84, 160) or clamp(boxEdgeZ + 8, minimumBackLineZ, boxEdgeZ + 18)
	local farPostZ = trueEmergencyDrop and clamp(58 + box * 44, 54, 126) or clamp(boxEdgeZ + 6, minimumBackLineZ, boxEdgeZ + 16)
	local nonEmergencyLine = lineState == "HoldEdge" or lineState == "StepToCarrier" or lineState == "ContainAtEdge" or lineState == "RecoverForward"
	local normalShape = not high and nonEmergencyLine and not throughPassBehind and not dangerousRunnerBehind and not attackerInBox and not crossIncoming
	local normalBackLineMaxDelta = normalShape and 3 or trueEmergencyDrop and 42 or dangerousRunnerBehind and 22 or 14
	local slots = {}
	if normalShape then
		local normalShift = clamp((ball.X - PitchConfig.HALF_WIDTH) * .3, -42, 42)
		local normalCenterX = clamp(PitchConfig.HALF_WIDTH + normalShift, 92, 332)
		local cbHalf = clamp(30 + (1 - compact) * 16, 28, 48)
		local fbHalf = clamp(104 + widthRatio * 34 - compact * 10, 92, 138)
		local midHalf = clamp(76 + widthRatio * 30 - compact * 8, 66, 108)
		local frontHalf = clamp(52 + widthRatio * 20, 48, 76)
		local farHold = clamp(farSideTuck * .55, 14, 34)
		local leftCBX = clamp(normalCenterX - cbHalf, 154, PitchConfig.HALF_WIDTH - 16)
		local rightCBX = clamp(normalCenterX + cbHalf, PitchConfig.HALF_WIDTH + 16, 270)
		local leftFBX = ballSide == "Right" and clamp(normalCenterX - fbHalf + farHold, 58, leftCBX - 28) or clamp(normalCenterX - fbHalf, 36, leftCBX - 34)
		local rightFBX = ballSide == "Left" and clamp(normalCenterX + fbHalf - farHold, rightCBX + 28, 366) or clamp(normalCenterX + fbHalf, rightCBX + 34, 388)
		local fullbackZ = backZ
		local leftMidX = clamp(normalCenterX - midHalf, 72, PitchConfig.HALF_WIDTH - 34)
		local rightMidX = clamp(normalCenterX + midHalf, PitchConfig.HALF_WIDTH + 34, 352)
		local ballSideMidX = ballSide == "Left" and leftMidX or ballSide == "Right" and rightMidX or normalCenterX
		local farSwitchX = ballSide == "Left" and rightMidX or ballSide == "Right" and leftMidX or normalCenterX + frontHalf
		slots = {
			goalkeeperSlot(Vector3.new(PitchConfig.HALF_WIDTH + normalShift * .15, 3, clamp(backZ - 105, 16, 460)), false),
			slot("primary-presser", "ST", primaryTarget, 98, false, true, "PrimaryPress", primary and primary.Model or nil, {"ST", "Winger", "CAM"}),
			slot("normal-nearest-pass-blocker", "Winger", Vector3.new(ballSideMidX, 3, clamp(forwardZ - 4, midZ + 28, 632)), 91, false, false, "NearestPassBlock", nearPresser and nearPresser.Model or nil, {"Winger", "ST", "CAM", "CM"}),
			slot("normal-left-midfield-lane", "CM", Vector3.new(leftMidX, 3, midZ), 90, false, false, "CoverLeftSide", nil, {"CM", "CDM", "CAM", "Winger"}),
			slot("normal-central-midfield-screen", "CDM", Vector3.new(normalCenterX, 3, clamp(midZ - 4, backZ + 28, forwardZ - 28)), 95, false, false, "CoverCenter", pivot and pivot.Model or nil, {"CDM", "CM"}),
			slot("normal-right-midfield-lane", "CM", Vector3.new(rightMidX, 3, midZ), 90, false, false, "CoverRightSide", nil, {"CM", "CDM", "CAM", "Winger"}),
			slot("normal-far-switch-guard", "Winger", Vector3.new(farSwitchX, 3, clamp(forwardZ - 10, midZ + 24, 626)), 84, false, false, "FarSwitchGuard", farPresser and farPresser.Model or nil, {"Winger", "ST", "CAM", "CM"}),
			slot("left-center-back", "CB", Vector3.new(leftCBX, 3, backZ), 99, true, false, "BackLine", nil, {"CB", "CDM"}),
			slot("right-center-back", "CB", Vector3.new(rightCBX, 3, backZ), 99, true, false, "BackLine", nil, {"CB", "CDM"}),
			slot("left-fullback-zone", "Fullback", Vector3.new(leftFBX, 3, fullbackZ), 98, true, false, "WideZone", nil, {"Fullback", "CB", "Winger"}),
			slot("right-fullback-zone", "Fullback", Vector3.new(rightFBX, 3, fullbackZ), 98, true, false, "WideZone", nil, {"Fullback", "CB", "Winger"}),
		}
	else
		slots = {
			goalkeeperSlot(Vector3.new(PitchConfig.HALF_WIDTH + centerShift * .2, 3, clamp(backZ - (compression and 72 or high and 82 or 105), 16, 460)), high),
			slot("primary-presser", "ST", primaryTarget, high and 98 or 90, false, true, "PrimaryPress", primary and primary.Model or nil, {"ST", "Winger", "CAM"}),
			slot("ball-side-outlet-presser", "Winger", nearOutletTarget, high and 96 or 86, false, high, "BallSideOutletPress", nearPresser and nearPresser.Model or nil, {"Winger", "ST", "CAM", "Fullback"}),
			slot("central-outlet-presser", "CAM", centralTarget, high and 95 or 87, false, high, "CentralOutletPress", centralPresser and centralPresser.Model or nil, {"CAM", "CM", "ST"}),
			slot("far-side-return-blocker", "Winger", farTarget, high and 90 or 82, false, high, "FarSideReturnBlock", farPresser and farPresser.Model or nil, {"Winger", "ST", "CAM"}),
			slot("ball-side-midfield-squeezer", "CM", supportTarget, high and 91 or 85, false, high, "BallSideMidfieldSqueeze", support and support.Model or nil, {"CM", "CAM", "CDM"}),
			slot("central-midfield-squeezer", "CM", centralSupportTarget, high and 89 or 83, false, high, "CentralMidfieldSqueeze", centralSupport and centralSupport.Model or nil, {"CM", "CDM", "CAM"}),
			slot("pivot-screen", "CDM", pivotTarget, 93, false, false, "PivotScreen", pivot and pivot.Model or nil, {"CDM", "CM"}),
			slot("edge-step-defender", "CB", stepTarget, (lineState == "StepToCarrier" or lineState == "ContainAtEdge") and 99 or 72, false, lineState == "StepToCarrier" or lineState == "ContainAtEdge", "StepToCarrier", stepDefender and stepDefender.Model or nil, {"CB", "Fullback", "CDM", "CM", "CAM"}),
			slot("inside-cover-defender", "CB", insideCoverTarget, (lineState == "StepToCarrier" or lineState == "ContainAtEdge") and 96 or 78, true, false, "InsideCover", nil, {"CB", "Fullback", "CDM"}),
			slot("far-side-cover-defender", "Fullback", farCoverTarget, (lineState == "StepToCarrier" or lineState == "ContainAtEdge") and 92 or 76, true, false, "FarSideCover", nil, {"Fullback", "CB", "CDM"}),
			slot("deep-cover-defender", "CB", deepCoverTarget, 97, true, false, "DeepCover", deepCover and deepCover.Model or nil, {"CB", "Fullback"}),
			slot("cover-presser", "CM", centralTarget, 84, false, high, "CoverPress", nil, {"CM", "CDM", "CAM"}),
			slot("midfield-press-support", "CM", supportTarget, 82, false, high, "MidfieldPressSupport", nil, {"CM", "CDM", "CAM"}),
			slot("pivot-lane-blocker", "CDM", Vector3.new(centerX, 3, midZ), 80, false, false, "PivotLaneBlock"),
			slot("cam-feet-lane-blocker", "CM", Vector3.new(clamp(centerX + (ball.X < PitchConfig.HALF_WIDTH and 28 or -28), 96, 328), 3, clamp(midZ + 22, 120, 570)), 86, false, false, "CentralLaneBlock"),
			slot("left-center-back", "CB", Vector3.new(leftX, 3, backZ), 94, true, false, "BackLine"),
			slot("right-center-back", "CB", Vector3.new(rightX, 3, backZ), 94, true, false, "BackLine"),
			slot("left-fullback-zone", "Fullback", Vector3.new(ballSide == "Right" and clamp(leftX + farSideTuck, 62, 202) or clamp(leftX - 36, 35, 172), 3, backZ + 18), 93, true, false, "WideZone"),
			slot("right-fullback-zone", "Fullback", Vector3.new(ballSide == "Left" and clamp(rightX - farSideTuck, 222, 362) or clamp(rightX + 36, 252, 389), 3, backZ + 18), 93, true, false, "WideZone"),
			slot("cutback-protector", "CDM", Vector3.new(PitchConfig.HALF_WIDTH, 3, cutbackZ), 90, true, false, "CutbackProtect"),
			slot("far-post-protector", "Fullback", Vector3.new(ballSide == "Left" and 332 or 92, 3, farPostZ), 80, true, false, "FarPostProtect"),
		}
	end
	local plan = {
		BlockCenter = Vector3.new(centerX, 3, (backZ + forwardZ) * .5),
		BlockWidth = blockWidth,
		BackLineZ = backZ,
		MidfieldLineZ = midZ,
		ForwardLineZ = forwardZ,
		PressAnchorZ = pressAnchorZ,
		HighPressPhase = high and intentName or "",
		HighPressBlockDepth = forwardZ - backZ,
		TeamBlockDepth = forwardZ - (normalShape and backZ or deepCoverTarget.Z),
		ForwardMidGap = forwardZ - midZ,
		MidBackGap = midZ - backZ,
		BallSideShift = centerShift,
		FarSideTuck = farSideTuck,
		PressureDirection = forceDirection,
		ForceDirection = forceDirection,
		BlockedLane = lane > .6 and "CentralPivot" or "ForwardCentral",
		ConcededLane = "SideOrBack",
		PrimaryPresser = primary and primary.Model or nil,
		CoverPresser = centralPresser and centralPresser.Model or nil,
		DeepCover = normalShape and nil or deepCover and deepCover.Model or nil,
		NormalShape = normalShape,
		NormalBackLineMaxDelta = normalBackLineMaxDelta,
		CrossIncoming = crossIncoming,
		StepDefender = stepDefender and stepDefender.Model or nil,
		InsideCoverTarget = insideCoverTarget,
		FarSideCoverTarget = farCoverTarget,
		DefensiveLineState = lineState,
		BoxEdgeAnchorZ = boxEdgeZ,
		BoxFrontEdgeZ = boxEdgeZ,
		DefensiveEdgeAnchorZ = edgeAnchor,
		NormalLineAnchorZ = edgeAnchor,
		LowBlockAnchorZ = lowAnchor,
		BackLineMinimumZ = minimumBackLineZ,
		BackLineCeilingZ = backLineCeilingZ,
		ResolvedBackLineTargetZ = backZ,
		EmergencyBoxAnchorZ = emergencyAnchor,
		EmergencyLineAnchorZ = emergencyAnchor,
		EmergencyDropReason = emergencyReason,
		ThreatResolved = threatResolved,
		EdgeOfBoxPressure = lineState == "StepToCarrier" or lineState == "ContainAtEdge",
		RetreatCapped = backZ <= boxEdgeZ + 42 and backZ >= minimumBackLineZ,
		NoPressureAdvance = noPressureAdvance,
		NoPressureThreshold = 10,
		AdvanceLineTrigger = advanceLine,
		RecoverForward = lineState == "RecoverForward",
		ClosestPresserDistance = pressure.Closest,
		ActivePresserCount = pressure.Active,
		CarrierFacingGoal = carrierAttackingBox == true,
		CarrierForwardSpeed = carrier and carrier.Info and carrier.Info.Root and math.max(0, -Vector3.new(carrier.Info.Root.AssemblyLinearVelocity.X, 0, carrier.Info.Root.AssemblyLinearVelocity.Z):Dot(Vector3.new(0, 0, 1))) or 0,
		DepthRunnerThreat = dangerousRunnerBehind,
		LineCoverAvailable = pressure.Cover,
		OpponentResetPress = resetPress,
		ResetPressStartedAt = resetData and resetData.StartedAt or 0,
		ResetPressExpiresAt = resetData and resetData.ExpiresAt or 0,
		ResetPressReceiver = resetData and resetData.Receiver or nil,
		ResetPressReceiverName = resetData and resetData.ReceiverName or "",
		ResetPassDirection = resetData and resetData.PassDirection or "",
		ResetPressConfidence = resetData and resetData.Confidence or 0,
		ResetPressState = resetData and resetData.State or "",
		HighLineMinimumZ = minimumHighLineZ,
		HighLineTargetZ = backZ,
		HalfwayLock = resetPress and backZ >= PitchConfig.HALF_LENGTH - 24,
		BlockCompressionState = resetPress and (backZ >= PitchConfig.HALF_LENGTH - 24 and "LockedAtHalfway" or "CompressingUp") or high and "HighPress" or lineState,
		PressBrokenReason = emergencyReason,
		Slots = slots,
		GeneratedAt = now,
		ExpiresAt = now + (high and .75 or 1.15),
		Compactness = compact,
	}
	return plan
end

return Planner
