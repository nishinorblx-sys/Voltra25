--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)
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
		ContinuityKey = id .. ":" .. tostring(duty or id),
		SprintAllowed = sprint == true,
		AllowedActions = actions,
		ForbiddenActions = isRest and {"Shoot", "Dribble", "RiskDribble", "BoxRun", "CarryForward"} or {},
		CoverRequirement = isRest and "ProtectGoalSide" or "CloseBallSide",
	})
	slotData.DefensiveDuty = duty or id
	slotData.LockedModel = lockedModel
	return slotData
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

function Planner.new(): any
	return setmetatable({Duties = {Home = {}, Away = {}}}, Planner)
end

function Planner:Reset(side: string?)
	if side then self.Duties[side] = {} else self.Duties = {Home = {}, Away = {}} end
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
	local low = intentName == "LowBlock" or intentName == "ProtectBox" or intentName == "ProtectLead"
	local high = intentName == "HighPress" or intentName == "HighPressBuildUp" or intentName == "HighPressLocked"
	local blockWidth = clamp(190 + widthRatio * 86 - compact * 42, 152, 258)
	local centerShift = clamp((ball.X - PitchConfig.HALF_WIDTH) * (.22 + zone * .18), -32, 32)
	local centerX = clamp(PitchConfig.HALF_WIDTH + centerShift, 110, 314)
	local backZ = low and clamp(64 + depthRatio * 74, 58, 148) or high and clamp(285 + depthRatio * 145, 260, 455) or clamp(132 + depthRatio * 178, 112, 330)
	local backMidGap = clamp(58 - compact * 20 + (low and -8 or high and 6 or 0), 36, 58)
	local midForwardGap = clamp(68 - compact * 18 + (high and 5 or 0), 40, 68)
	local midZ = clamp(backZ + backMidGap, 96, 540)
	local forwardZ = clamp(midZ + midForwardGap, 138, 630)
	local pressAnchorZ = ball.Z
	if high then
		local threatZ = 0
		for _, opponent in ipairs(((context.Teams or {})[side == "Home" and "Away" or "Home"] or {}).List or {}) do
			if opponent.Root then
				local pitch = PitchConfig.WorldToTeamPitchPosition(opponent.World, side, context.Options)
				if pitch.Z < ball.Z - 20 then
					threatZ = math.max(threatZ, pitch.Z)
				end
			end
		end
		local speedThreat = threatZ > 0 and math.clamp((ball.Z - threatZ) / 240, 0, 1) or .25
		local forwardMidGap = clamp(45 - compact * 10 - press * 7, 30, 45)
		local midBackGap = clamp(48 - compact * 10 - zone * 5 + speedThreat * 12, 32, 54)
		forwardZ = clamp(pressAnchorZ - 6, 410, 690)
		midZ = clamp(forwardZ - forwardMidGap, 330, 650)
		backZ = clamp(midZ - midBackGap, 250, threatZ > 0 and math.min(540, threatZ + 26) or 545)
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
	local primaryTarget = Vector3.new(ball.X + (ballSide == "Left" and 12 or ballSide == "Right" and -12 or 0), 3, clamp(ball.Z - 2, 48, PitchConfig.PITCH_LENGTH - 18))
	local primary = nearestRole(context, side, {ST = true, Winger = true, CAM = true}, primaryTarget, used)
	if primary then used[primary.Model] = true end
	local nearOutlet = opponentClosest(context, side, {Fullback = true, Winger = true, CB = true, GK = true}, Vector3.new(ball.X, 3, ball.Z - 10), true)
	local centralOutlet = opponentClosest(context, side, {CDM = true, CM = true, CAM = true}, Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z - 26), false)
	local farOutlet = opponentClosest(context, side, {CB = true, Fullback = true, GK = true}, Vector3.new(ballSide == "Left" and 318 or 106, 3, ball.Z - 8), true)
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
	local deepCoverTarget = Vector3.new(ballSide == "Left" and rightX or leftX, 3, clamp(backZ - (high and 10 or 0), 48, 560))
	local deepCover = nearestRole(context, side, {CB = true, Fullback = true}, deepCoverTarget, used)
	if deepCover then used[deepCover.Model] = true end
	local slots = {
		slot("primary-presser", "ST", primaryTarget, high and 98 or 90, false, true, "PrimaryPress", primary and primary.Model or nil, {"ST", "Winger", "CAM"}),
		slot("ball-side-outlet-presser", "Winger", nearOutletTarget, high and 96 or 86, false, high, "BallSideOutletPress", nearPresser and nearPresser.Model or nil, {"Winger", "ST", "CAM", "Fullback"}),
		slot("central-outlet-presser", "CAM", centralTarget, high and 95 or 87, false, high, "CentralOutletPress", centralPresser and centralPresser.Model or nil, {"CAM", "CM", "ST"}),
		slot("far-side-return-blocker", "Winger", farTarget, high and 90 or 82, false, high, "FarSideReturnBlock", farPresser and farPresser.Model or nil, {"Winger", "ST", "CAM"}),
		slot("ball-side-midfield-squeezer", "CM", supportTarget, high and 91 or 85, false, high, "BallSideMidfieldSqueeze", support and support.Model or nil, {"CM", "CAM", "CDM"}),
		slot("central-midfield-squeezer", "CM", centralSupportTarget, high and 89 or 83, false, high, "CentralMidfieldSqueeze", centralSupport and centralSupport.Model or nil, {"CM", "CDM", "CAM"}),
		slot("pivot-screen", "CDM", pivotTarget, 93, false, false, "PivotScreen", pivot and pivot.Model or nil, {"CDM", "CM"}),
		slot("deep-cover-defender", "CB", deepCoverTarget, 97, true, false, "DeepCover", deepCover and deepCover.Model or nil, {"CB", "Fullback"}),
		slot("cover-presser", "CM", centralTarget, 84, false, high, "CoverPress", nil, {"CM", "CDM", "CAM"}),
		slot("midfield-press-support", "CM", supportTarget, 82, false, high, "MidfieldPressSupport", nil, {"CM", "CDM", "CAM"}),
		slot("pivot-lane-blocker", "CDM", Vector3.new(centerX, 3, midZ), 80, false, false, "PivotLaneBlock"),
		slot("cam-feet-lane-blocker", "CM", Vector3.new(clamp(centerX + (ball.X < PitchConfig.HALF_WIDTH and 28 or -28), 96, 328), 3, clamp(midZ + 22, 120, 570)), 86, false, false, "CentralLaneBlock"),
		slot("left-center-back", "CB", Vector3.new(leftX, 3, backZ), 94, true, false, "BackLine"),
		slot("right-center-back", "CB", Vector3.new(rightX, 3, backZ), 94, true, false, "BackLine"),
		slot("left-fullback-zone", "Fullback", Vector3.new(ballSide == "Right" and clamp(leftX + farSideTuck, 62, 202) or clamp(leftX - 36, 35, 172), 3, backZ + 18), 82, true, false, "WideZone"),
		slot("right-fullback-zone", "Fullback", Vector3.new(ballSide == "Left" and clamp(rightX - farSideTuck, 222, 362) or clamp(rightX + 36, 252, 389), 3, backZ + 18), 82, true, false, "WideZone"),
		slot("cutback-protector", "CDM", Vector3.new(PitchConfig.HALF_WIDTH, 3, clamp(92 + box * 52, 84, 160)), 90, true, false, "CutbackProtect"),
		slot("far-post-protector", "Fullback", Vector3.new(ballSide == "Left" and 332 or 92, 3, clamp(58 + box * 44, 54, 126)), 80, true, false, "FarPostProtect"),
	}
	local plan = {
		BlockCenter = Vector3.new(centerX, 3, (backZ + forwardZ) * .5),
		BlockWidth = blockWidth,
		BackLineZ = backZ,
		MidfieldLineZ = midZ,
		ForwardLineZ = forwardZ,
		PressAnchorZ = pressAnchorZ,
		HighPressPhase = high and intentName or "",
		HighPressBlockDepth = forwardZ - backZ,
		BallSideShift = centerShift,
		FarSideTuck = farSideTuck,
		PressureDirection = forceDirection,
		ForceDirection = forceDirection,
		BlockedLane = lane > .6 and "CentralPivot" or "ForwardCentral",
		ConcededLane = "SideOrBack",
		PrimaryPresser = primary and primary.Model or nil,
		CoverPresser = centralPresser and centralPresser.Model or nil,
		DeepCover = deepCover and deepCover.Model or nil,
		Slots = slots,
		GeneratedAt = now,
		ExpiresAt = now + (high and .75 or 1.15),
		Compactness = compact,
	}
	return plan
end

return Planner
