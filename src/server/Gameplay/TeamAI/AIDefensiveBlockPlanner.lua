--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)

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

local function slot(id: string, family: string, pitch: Vector3, priority: number, rest: boolean?, sprint: boolean?, duty: string?): any
	return {Id = id, RoleFamily = family, TargetPitch = PitchConfig.ClampInsidePitch(pitch), Priority = priority, RestDefense = rest == true, SprintAllowed = sprint == true, DefensiveDuty = duty or id}
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
	local low = intentName == "LowBlock" or intentName == "ProtectBox" or intentName == "ProtectLead"
	local high = intentName == "HighPress"
	local blockWidth = clamp(190 + widthRatio * 86 - compact * 42, 152, 258)
	local centerShift = clamp((ball.X - PitchConfig.HALF_WIDTH) * (.22 + zone * .18), -32, 32)
	local centerX = clamp(PitchConfig.HALF_WIDTH + centerShift, 110, 314)
	local backZ = low and clamp(64 + depthRatio * 74, 58, 148) or high and clamp(285 + depthRatio * 145, 260, 455) or clamp(132 + depthRatio * 178, 112, 330)
	local backMidGap = clamp(58 - compact * 20 + (low and -8 or high and 6 or 0), 36, 58)
	local midForwardGap = clamp(68 - compact * 18 + (high and 5 or 0), 40, 68)
	local midZ = clamp(backZ + backMidGap, 96, 540)
	local forwardZ = clamp(midZ + midForwardGap, 138, 630)
	local halfWidth = blockWidth * .5
	local leftX = clamp(centerX - halfWidth * .45, 42, 180)
	local rightX = clamp(centerX + halfWidth * .45, 244, 382)
	local farSideTuck = clamp(20 + zone * 25 + compact * 12, 20, 52)
	local ballSide = sideOf(ball.X)
	local forceDirection = ballSide == "Left" and "TouchlineLeft" or ballSide == "Right" and "TouchlineRight" or "Backward"
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
