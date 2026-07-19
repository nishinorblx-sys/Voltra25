--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)
local AITacticalContract = require(script.Parent.AITacticalContract)
local OffsidePositionUtil = require(script.Parent.Parent.OffsidePositionUtil)

local Service = {}

local function ratio(style: any, key: string, fallback: number): number
	if style and style.Ratio then
		local ok, value = pcall(function() return style:Ratio(key) end)
		if ok and type(value) == "number" then
			return math.clamp(value, 0, 1)
		end
	end
	return fallback
end

local function ballZone(ball: Vector3): string
	if ball.Z >= 560 then return "Final" end
	if ball.Z >= 380 then return "Progression" end
	if ball.Z >= 210 then return "Middle" end
	return "Build"
end

local function laneForX(x: number): string
	if x < 145 then return "Left" end
	if x > 279 then return "Right" end
	return "Central"
end

local function lineForRole(role: string): string
	if role == "GK" then return "Goalkeeper" end
	if role == "CB" or role == "Fullback" or role == "Wingback" then return "Back" end
	if role == "ST" then return "Forward" end
	return "Midfield"
end

local function keeperZ(context: any, side: string, ball: Vector3, identity: string, style: any): number
	local deepestDefender = math.huge
	for _, info in ipairs(context.Teams[side].List) do
		if info.Root and not info.IsGoalkeeper then
			deepestDefender = math.min(deepestDefender, info.Pitch.Z)
		end
	end
	local opponentThreat = PitchConfig.PITCH_LENGTH
	for _, opponent in ipairs(context.Teams[side == "Home" and "Away" or "Home"].List) do
		if opponent.Root then
			local opponentInSideFrame = PitchConfig.WorldToTeamPitchPosition(opponent.World, side, context.Options)
			opponentThreat = math.min(opponentThreat, opponentInSideFrame.Z)
		end
	end
	local aggression = ratio(style, "KeeperAggression", .45)
	local pressure = false
	if context.Owner and context.Players[context.Owner] and context.Players[context.Owner].Side == side then
		local carrier = context.Players[context.Owner]
		local closest = math.huge
		for _, opponent in ipairs(context.Teams[carrier.OpponentSide].List) do
			if opponent.Root then
				closest = math.min(closest, PitchConfig.GetDistanceStuds(carrier.World, opponent.World))
			end
		end
		pressure = closest <= 18
	end
	local z
	if ball.Z >= 600 and opponentThreat > 185 and not pressure then
		z = 55 + aggression * 40
	elseif identity == "DirectAssault" and opponentThreat > 210 and ball.Z >= 470 then
		z = 75 + aggression * 45
	else
		z = 24 + aggression * 34
	end
	if deepestDefender < math.huge then
		z = math.min(z, deepestDefender - 18)
	end
	if opponentThreat < 150 then
		z = math.min(z, 50)
	end
	return math.clamp(z, 24, ball.Z >= 600 and 95 or 65)
end

local function slot(raw: any): any
	local target = PitchConfig.ClampInsidePitch(raw.TargetPitch)
	local role = tostring(raw.RoleFamily or raw.Role or "CM")
	local lane = raw.Lane or laneForX(target.X)
	local line = raw.Line or lineForRole(role)
	local profile = raw.ActionProfile
	if not profile then
		if raw.RestDefense == true then
			profile = "RestDefender"
		elseif role == "GK" then
			profile = "Goalkeeper"
		elseif role == "ST" or line == "Forward" and role ~= "Winger" and role ~= "Wingback" then
			profile = "Forward"
		elseif role == "Winger" or role == "Wingback" then
			profile = "Winger"
		elseif role == "CAM" then
			profile = "Creator"
		elseif role == "CDM" then
			profile = "Pivot"
		elseif role == "CM" then
			profile = "SupportMidfielder"
		else
			profile = "BuildUpDefender"
		end
	end
	return AITacticalContract.Slot({
		Id = raw.Id,
		Function = raw.Function,
		RoleFamily = role,
		AllowedRoles = raw.AllowedRoles or {role},
		PreferredRoles = raw.PreferredRoles or {role},
		TargetPitch = target,
		TargetRegion = AITacticalContract.Region(target, raw.RegionRadius or 20, lane, line),
		Lane = lane,
		Line = line,
		ActionProfile = profile,
		Priority = raw.Priority or 50,
		RestDefense = raw.RestDefense == true,
		ContinuityKey = raw.ContinuityKey or raw.Id,
		SprintAllowed = raw.SprintAllowed == true,
		AllowedActions = raw.AllowedActions,
		ForbiddenActions = raw.ForbiddenActions,
		CoverRequirement = raw.CoverRequirement,
	})
end

local function transform(base: {any}, context: any, side: string, style: any, plan: any): {any}
	local teamBrain = context.TeamBrain and context.TeamBrain[side]
	local identity = tostring(teamBrain and teamBrain.AttackingIdentity or "")
	local reaction = context.TeamReactions and context.TeamReactions[side] and context.TeamReactions[side].AgainstOpponentDefense
	local rules = context.RuleEffects and context.RuleEffects[side] and context.RuleEffects[side].Positioning
	local ball = context.BallTeam[side]
	local secondLastZ = OffsidePositionUtil.SecondLastOpponentZ(context, side)
	local normalOnsideCap = math.max(PitchConfig.HALF_LENGTH, secondLastZ - 7)
	local timedOnsideCap = math.max(PitchConfig.HALF_LENGTH, secondLastZ - 4)
	local widthRatio = ratio(style, "AttackingWidth", .5)
	local supportRatio = ratio(style, "SupportDistance", .5)
	if reaction then
		widthRatio = math.clamp(widthRatio + (tonumber(reaction.AttackingWidth) or 0), 0, 1)
		supportRatio = math.clamp(supportRatio + (tonumber(reaction.SupportDistance) or 0), 0, 1)
	end
	if rules then
		widthRatio = math.clamp(widthRatio + (tonumber(rules.Width) or 0), 0, 1)
		supportRatio = math.clamp(supportRatio + (tonumber(rules.SupportDistance) or 0), 0, 1)
	end
	local zone = ballZone(ball)
	local xScale = identity == "CentralDomination" and .74 or identity == "WideOverload" and 1.18 or .88 + widthRatio * .24
	local zPush = zone == "Final" and 24 or zone == "Progression" and 16 or 0
	if identity == "DirectAssault" then
		zPush += 42
	elseif identity == "PositionalControl" then
		zPush -= 12
	end
	local supportPull = (supportRatio - .5) * 34
	local result = {}
	for _, item in ipairs(base) do
		local target = item.TargetPitch
		local x = PitchConfig.HALF_WIDTH + (target.X - PitchConfig.HALF_WIDTH) * xScale
		local z = target.Z
		if item.Line == "Forward" then
			z += zPush
		elseif item.Line == "Midfield" then
			z += zPush * .45 + supportPull
		elseif item.RestDefense then
			z = math.min(z + zPush * .12, ball.Z - 54)
		end
		local copy = table.clone(item)
		copy.TargetPitch = Vector3.new(x, 3, z)
		if rules and tonumber(rules.Depth) then
			copy.TargetPitch = Vector3.new(copy.TargetPitch.X, 3, copy.TargetPitch.Z + (tonumber(rules.Depth) or 0) * 80)
		end
		copy.SprintAllowed = copy.SprintAllowed or item.Line == "Forward" and identity ~= "PositionalControl"
		if plan and plan.PlanStep then
			copy.PlanStepId = plan.PlanStep.Id
		end
		if reaction then
			if item.Function == "Far-side width" and (tonumber(reaction.SwitchPreference) or 0) > .1 then
				copy.Priority = (copy.Priority or 50) + 6
				copy.TargetPitch = Vector3.new(copy.TargetPitch.X, 3, math.min(690, copy.TargetPitch.Z + 18))
			elseif item.Function == "Between-lines receiver" and (tonumber(reaction.BetweenLines) or 0) > .1 then
				copy.Priority = (copy.Priority or 50) + 7
			elseif item.Function == "Second-ball midfielder" and ((tonumber(reaction.SecondBallCoverage) or 0) > .1 or (tonumber(reaction.BoxEdgeOccupation) or 0) > .1) then
				copy.Priority = (copy.Priority or 50) + 5
				copy.TargetPitch = Vector3.new(copy.TargetPitch.X, 3, math.min(610, copy.TargetPitch.Z + 14))
			end
		end
		local line = tostring(copy.Line or "")
		local functionName = tostring(copy.Function or "")
		if line == "Forward" and typeof(copy.TargetPitch) == "Vector3" then
			local timed = functionName:find("Checking") ~= nil or functionName:find("Between") ~= nil
			local cap = timed and timedOnsideCap or normalOnsideCap
			if copy.TargetPitch.Z > cap then
				copy.TargetPitch = Vector3.new(copy.TargetPitch.X, 3, cap)
			end
			copy.OffsideLineZ = secondLastZ
		end
		local forbidden = rules and rules.ForbiddenFunctions
		local allowed = rules and rules.AllowedFunctions
		if allowed and next(allowed) and (allowed[copy.Id] == true or allowed[copy.Function] == true) then
			copy.Priority = (copy.Priority or 50) + 12
		end
		if forbidden and (forbidden[copy.Id] == true or forbidden[copy.Function] == true) then
			copy.Priority = (copy.Priority or 50) - 40
		end
		table.insert(result, slot(copy))
	end
	return result
end

local function selectCount(slots: {any}, count: number): {any}
	table.sort(slots, function(a, b)
		if (a.Priority or 0) == (b.Priority or 0) then
			return tostring(a.Id) < tostring(b.Id)
		end
		return (a.Priority or 0) > (b.Priority or 0)
	end)
	local result = {}
	for index = 1, math.min(count, #slots) do
		table.insert(result, slots[index])
	end
	table.sort(result, function(a, b) return tostring(a.ContinuityKey or a.Id) < tostring(b.ContinuityKey or b.Id) end)
	return result
end

local function formationBase(formation: string, count: number, context: any, side: string, style: any, plan: any): {any}
	local ball = context.BallTeam[side]
	local keeper = keeperZ(context, side, ball, tostring(context.TeamBrain and context.TeamBrain[side] and context.TeamBrain[side].AttackingIdentity or ""), style)
	if count <= 6 then
		return {
			{Id = "goalkeeper-outlet", Function = "Goalkeeper outlet", RoleFamily = "GK", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, keeper), Priority = 100, Line = "Goalkeeper", AllowedActions = {"Receive", "Pass", "Clear"}},
			{Id = "rest-defense", Function = "Central rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(82, ball.Z - 96)), Priority = 96, RestDefense = true, Line = "Back", AllowedActions = {"Receive", "Pass", "Clear", "Tackle", "Cover"}, ForbiddenActions = {"Shoot", "Dribble", "RiskDribble", "BoxRun", "CarryForward"}},
			{Id = "left-support", Function = "Left support midfielder", RoleFamily = "CM", TargetPitch = Vector3.new(142, 3, math.max(130, ball.Z + 18)), Priority = 88, Line = "Midfield"},
			{Id = "right-support", Function = "Right support midfielder", RoleFamily = "CM", TargetPitch = Vector3.new(282, 3, math.max(130, ball.Z + 18)), Priority = 87, Line = "Midfield"},
			{Id = "left-width", Function = "Left forward depth", RoleFamily = "ST", TargetPitch = Vector3.new(120, 3, math.min(690, ball.Z + 116)), Priority = 82, Line = "Forward", SprintAllowed = true},
			{Id = "right-width", Function = "Right forward depth", RoleFamily = "ST", TargetPitch = Vector3.new(304, 3, math.min(690, ball.Z + 116)), Priority = 81, Line = "Forward", SprintAllowed = true},
		}
	end
	local common = {
		{Id = "goalkeeper-outlet", Function = "Goalkeeper outlet", RoleFamily = "GK", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, keeper), Priority = 100, Line = "Goalkeeper", AllowedActions = {"Receive", "Pass", "Clear"}},
	}
	local byFormation: {[string]: {any}} = {
		["4-3-3"] = {
			{Id = "left-build-up-defender", Function = "Left build-up defender", RoleFamily = "Fullback", TargetPitch = Vector3.new(76, 3, math.max(95, ball.Z - 72)), Priority = 91, RestDefense = true, Line = "Back"},
			{Id = "left-first-line", Function = "Left center-back rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(152, 3, math.max(80, ball.Z - 96)), Priority = 95, RestDefense = true, Line = "Back"},
			{Id = "right-first-line", Function = "Right center-back rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(272, 3, math.max(80, ball.Z - 96)), Priority = 94, RestDefense = true, Line = "Back"},
			{Id = "right-build-up-defender", Function = "Right build-up defender", RoleFamily = "Fullback", TargetPitch = Vector3.new(348, 3, math.max(95, ball.Z - 72)), Priority = 90, RestDefense = true, Line = "Back"},
			{Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CDM", TargetPitch = Vector3.new(ball.X < PitchConfig.HALF_WIDTH and 170 or 254, 3, ball.Z + 24), Priority = 86, Line = "Midfield"},
			{Id = "second-ball-midfielder", Function = "Second-ball midfielder", RoleFamily = "CM", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z + 58), Priority = 84, Line = "Midfield"},
			{Id = "between-lines-receiver", Function = "Between-lines receiver", RoleFamily = "CAM", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z + 94), Priority = 83, Line = "Midfield"},
			{Id = "left-width", Function = "Ball-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(44, 3, ball.Z + 118), Priority = 80, Line = "Forward", SprintAllowed = true},
			{Id = "right-width", Function = "Far-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(380, 3, ball.Z + 118), Priority = 79, Line = "Forward", SprintAllowed = true},
			{Id = "central-forward", Function = "Depth striker", RoleFamily = "ST", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z + 142), Priority = 82, Line = "Forward", SprintAllowed = true},
		},
		["4-2-3-1"] = {
			{Id = "left-build-up-defender", Function = "Left build-up defender", RoleFamily = "Fullback", TargetPitch = Vector3.new(78, 3, ball.Z - 66), Priority = 90, RestDefense = true, Line = "Back"},
			{Id = "left-first-line", Function = "Left center-back rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(152, 3, ball.Z - 96), Priority = 95, RestDefense = true, Line = "Back"},
			{Id = "right-first-line", Function = "Right center-back rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(272, 3, ball.Z - 96), Priority = 94, RestDefense = true, Line = "Back"},
			{Id = "right-build-up-defender", Function = "Right build-up defender", RoleFamily = "Fullback", TargetPitch = Vector3.new(346, 3, ball.Z - 66), Priority = 89, RestDefense = true, Line = "Back"},
			{Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CDM", TargetPitch = Vector3.new(172, 3, ball.Z + 18), Priority = 88, Line = "Midfield"},
			{Id = "far-side-pivot", Function = "Far-side pivot", RoleFamily = "CDM", TargetPitch = Vector3.new(252, 3, ball.Z + 18), Priority = 87, Line = "Midfield"},
			{Id = "left-width", Function = "Ball-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(54, 3, ball.Z + 102), Priority = 80, Line = "Forward", SprintAllowed = true},
			{Id = "between-lines-receiver", Function = "Between-lines receiver", RoleFamily = "CAM", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z + 82), Priority = 86, Line = "Midfield"},
			{Id = "right-width", Function = "Far-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(370, 3, ball.Z + 102), Priority = 79, Line = "Forward", SprintAllowed = true},
			{Id = "central-forward", Function = "Checking striker", RoleFamily = "ST", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z + 134), Priority = 82, Line = "Forward", SprintAllowed = true},
		},
		["4-4-2"] = {
			{Id = "left-build-up-defender", Function = "Left build-up defender", RoleFamily = "Fullback", TargetPitch = Vector3.new(78, 3, ball.Z - 72), Priority = 90, RestDefense = true, Line = "Back"},
			{Id = "left-first-line", Function = "Left center-back rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(152, 3, ball.Z - 96), Priority = 95, RestDefense = true, Line = "Back"},
			{Id = "right-first-line", Function = "Right center-back rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(272, 3, ball.Z - 96), Priority = 94, RestDefense = true, Line = "Back"},
			{Id = "right-build-up-defender", Function = "Right build-up defender", RoleFamily = "Fullback", TargetPitch = Vector3.new(346, 3, ball.Z - 72), Priority = 89, RestDefense = true, Line = "Back"},
			{Id = "left-midfield-width", Function = "Ball-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(58, 3, ball.Z + 38), Priority = 84, Line = "Midfield"},
			{Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CM", TargetPitch = Vector3.new(176, 3, ball.Z + 30), Priority = 86, Line = "Midfield"},
			{Id = "far-side-pivot", Function = "Far-side pivot", RoleFamily = "CM", TargetPitch = Vector3.new(248, 3, ball.Z + 30), Priority = 85, Line = "Midfield"},
			{Id = "right-midfield-width", Function = "Far-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(366, 3, ball.Z + 38), Priority = 83, Line = "Midfield"},
			{Id = "checking-striker", Function = "Checking striker", RoleFamily = "ST", TargetPitch = Vector3.new(180, 3, ball.Z + 116), Priority = 82, Line = "Forward", SprintAllowed = true},
			{Id = "central-forward", Function = "Depth striker", RoleFamily = "ST", TargetPitch = Vector3.new(244, 3, ball.Z + 138), Priority = 81, Line = "Forward", SprintAllowed = true},
		},
		["3-5-2"] = {
			{Id = "left-first-line", Function = "Left build-up defender", RoleFamily = "CB", TargetPitch = Vector3.new(122, 3, ball.Z - 92), Priority = 96, RestDefense = true, Line = "Back"},
			{Id = "rest-defense", Function = "Central rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z - 104), Priority = 98, RestDefense = true, Line = "Back"},
			{Id = "right-first-line", Function = "Right build-up defender", RoleFamily = "CB", TargetPitch = Vector3.new(302, 3, ball.Z - 92), Priority = 95, RestDefense = true, Line = "Back"},
			{Id = "left-width", Function = "Ball-side width", RoleFamily = "Wingback", TargetPitch = Vector3.new(42, 3, ball.Z + 46), Priority = 86, Line = "Midfield", SprintAllowed = true},
			{Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CDM", TargetPitch = Vector3.new(174, 3, ball.Z + 24), Priority = 88, Line = "Midfield"},
			{Id = "second-ball-midfielder", Function = "Second-ball midfielder", RoleFamily = "CM", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z + 58), Priority = 87, Line = "Midfield"},
			{Id = "far-side-pivot", Function = "Far-side pivot", RoleFamily = "CM", TargetPitch = Vector3.new(250, 3, ball.Z + 24), Priority = 85, Line = "Midfield"},
			{Id = "right-width", Function = "Far-side width", RoleFamily = "Wingback", TargetPitch = Vector3.new(382, 3, ball.Z + 46), Priority = 84, Line = "Midfield", SprintAllowed = true},
			{Id = "checking-striker", Function = "Checking striker", RoleFamily = "ST", TargetPitch = Vector3.new(180, 3, ball.Z + 122), Priority = 82, Line = "Forward", SprintAllowed = true},
			{Id = "central-forward", Function = "Depth striker", RoleFamily = "ST", TargetPitch = Vector3.new(244, 3, ball.Z + 142), Priority = 81, Line = "Forward", SprintAllowed = true},
		},
		["5-3-2"] = {
			{Id = "left-wingback", Function = "Ball-side width", RoleFamily = "Wingback", TargetPitch = Vector3.new(44, 3, ball.Z - 18), Priority = 85, RestDefense = true, Line = "Back"},
			{Id = "left-first-line", Function = "Left build-up defender", RoleFamily = "CB", TargetPitch = Vector3.new(122, 3, ball.Z - 92), Priority = 96, RestDefense = true, Line = "Back"},
			{Id = "rest-defense", Function = "Central rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z - 104), Priority = 98, RestDefense = true, Line = "Back"},
			{Id = "right-first-line", Function = "Right build-up defender", RoleFamily = "CB", TargetPitch = Vector3.new(302, 3, ball.Z - 92), Priority = 95, RestDefense = true, Line = "Back"},
			{Id = "right-wingback", Function = "Far-side width", RoleFamily = "Wingback", TargetPitch = Vector3.new(380, 3, ball.Z - 18), Priority = 84, RestDefense = true, Line = "Back"},
			{Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CDM", TargetPitch = Vector3.new(166, 3, ball.Z + 32), Priority = 88, Line = "Midfield"},
			{Id = "second-ball-midfielder", Function = "Second-ball midfielder", RoleFamily = "CM", TargetPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, ball.Z + 66), Priority = 87, Line = "Midfield"},
			{Id = "far-side-pivot", Function = "Far-side pivot", RoleFamily = "CM", TargetPitch = Vector3.new(258, 3, ball.Z + 32), Priority = 86, Line = "Midfield"},
			{Id = "checking-striker", Function = "Checking striker", RoleFamily = "ST", TargetPitch = Vector3.new(180, 3, ball.Z + 118), Priority = 82, Line = "Forward", SprintAllowed = true},
			{Id = "central-forward", Function = "Depth striker", RoleFamily = "ST", TargetPitch = Vector3.new(244, 3, ball.Z + 138), Priority = 81, Line = "Forward", SprintAllowed = true},
		},
	}
	local selected = table.clone(common)
	for _, item in ipairs(byFormation[formation] or byFormation["4-3-3"]) do
		table.insert(selected, item)
	end
	return selected
end

function Service.Build(context: any, side: string, style: any, intent: any, spatial: any, plan: any): {any}
	local formation = tostring(context.Formations and context.Formations[side] or "4-3-3")
	local activeCount = 0
	for _, info in ipairs(context.Teams[side].List) do
		if info.Root then
			activeCount += 1
		end
	end
	local base = formationBase(formation, activeCount, context, side, style, plan)
	local transformed = transform(base, context, side, style, plan)
	return selectCount(transformed, activeCount)
end

return Service
