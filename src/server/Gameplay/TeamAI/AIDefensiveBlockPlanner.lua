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

local function slot(id: string, family: string, pitch: Vector3, priority: number, rest: boolean?, sprint: boolean?, duty: string?): any
	local targetPitch = PitchConfig.ClampInsidePitch(pitch)
	local isRest = rest == true
	local line = (family == "CB" or family == "Fullback") and "Back" or family == "ST" and "Forward" or "Midfield"
	local lane = targetPitch.X < 145 and "Left" or targetPitch.X > 279 and "Right" or "Central"
	local actions = isRest and {"Cover", "Tackle", "Clear", "Receive", "Pass"} or {"Press", "Tackle", "Cover", "Receive", "Pass"}
	local slotData = AITacticalContract.Slot({
		Id = id,
		Function = defensiveFunction(id, duty),
		RoleFamily = family,
		AllowedRoles = {family},
		PreferredRoles = {family},
		TargetPitch = targetPitch,
		TargetRegion = AITacticalContract.Region(targetPitch, isRest and 15 or 20, lane, line),
		Lane = lane,
		Line = line,
		Priority = priority,
		RestDefense = isRest,
		ContinuityKey = id .. ":" .. tostring(duty or id),
		SprintAllowed = sprint == true,
		AllowedActions = actions,
		ForbiddenActions = isRest and {"Shoot", "Dribble", "RiskDribble", "BoxRun", "CarryForward"} or {},
		CoverRequirement = isRest and "ProtectGoalSide" or "CloseBallSide",
	})
	slotData.DefensiveDuty = duty or id
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
	local high = intentName == "HighPress"
	local blockWidth = clamp(190 + widthRatio * 86 - compact * 42, 152, 258)
	local centerShift = clamp((ball.X - PitchConfig.HALF_WIDTH) * (.22 + zone * .18), -32, 32)
	local centerX = clamp(PitchConfig.HALF_WIDTH + centerShift, 110, 314)
	local backZ = low and clamp(64 + depthRatio * 74, 58, 148) or high and clamp(285 + depthRatio * 145, 260, 455) or clamp(132 + depthRatio * 178, 112, 330)
	local backMidGap = clamp(58 - compact * 20 + (low and -8 or high and 6 or 0), 36, 58)
	local midForwardGap = clamp(68 - compact * 18 + (high and 5 or 0), 40, 68)
	if reaction then
		local gapAdjust = (tonumber(reaction.LineGap) or 0) * 42
		backMidGap = clamp(backMidGap + gapAdjust, 30, 64)
		midForwardGap = clamp(midForwardGap + gapAdjust, 34, 74)
	end
	local midZ = clamp(backZ + backMidGap, 96, 540)
	local forwardZ = clamp(midZ + midForwardGap, 138, 630)
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
	local primaryTarget = Vector3.new(ball.X + (ballSide == "Left" and 10 or ballSide == "Right" and -10 or 0), 3, ball.Z + (high and 20 or 10))
	local primary = nearestRole(context, side, {ST = true, Winger = true, CAM = true, CM = press > .82}, primaryTarget, used)
	if primary then used[primary.Model] = true end
	local coverTarget = Vector3.new(clamp((ball.X + centerX) * .5, 78, 346), 3, clamp(ball.Z - 18, midZ - 24, forwardZ))
	local cover = nearestRole(context, side, {CM = true, CDM = true, CAM = true}, coverTarget, used)
	if cover then used[cover.Model] = true end
	local slots = {
		slot("primary-presser", "ST", primaryTarget, high and 98 or 90, false, true, "PrimaryPress"),
		slot("cover-presser", "CM", coverTarget, 88, false, high, "CoverPress"),
		slot("pivot-lane-blocker", "CDM", Vector3.new(centerX, 3, midZ), 92, false, false, "PivotLaneBlock"),
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
		BallSideShift = centerShift,
		FarSideTuck = farSideTuck,
		PressureDirection = forceDirection,
		ForceDirection = forceDirection,
		BlockedLane = lane > .6 and "CentralPivot" or "ForwardCentral",
		ConcededLane = "SideOrBack",
		PrimaryPresser = primary and primary.Model or nil,
		CoverPresser = cover and cover.Model or nil,
		Slots = slots,
		GeneratedAt = now,
		ExpiresAt = now + (high and .75 or 1.15),
		Compactness = compact,
	}
	return plan
end

return Planner
