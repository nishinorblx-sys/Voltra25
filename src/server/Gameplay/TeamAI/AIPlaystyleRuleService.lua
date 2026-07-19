--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)

local Service = {}

local function asList(value: any): {any}
	return type(value) == "table" and value or {}
end

local function finite(value: any): number?
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return nil
	end
	return number
end

local function text(value: any): string
	return tostring(value or "")
end

local function matchString(ruleValue: any, actual: any): boolean
	if ruleValue == nil or ruleValue == "" then return true end
	if type(ruleValue) == "table" then
		for _, item in ipairs(ruleValue) do
			if tostring(item) == tostring(actual) then return true end
		end
		return false
	end
	return tostring(ruleValue) == tostring(actual)
end

local function zoneFor(context: any, side: string): string
	local ball = context.BallTeam and context.BallTeam[side]
	if not ball then return "" end
	if ball.Z >= 610 then return "OpponentBox" end
	if ball.Z >= 495 then return "FinalThird" end
	if ball.Z >= 247 then return "MiddleThird" end
	return "DefensiveThird"
end

local function phaseFor(context: any, side: string): string
	if context.LooseBall then return "LooseBall" end
	if context.PassInFlight then return "PassInFlight" end
	if context.OwnerSide == side then return "InPossession" end
	if context.OwnerSide then return "OutOfPossession" end
	return "Neutral"
end

local function ruleMatches(rule: any, context: any, side: string, extra: any?): boolean
	if type(rule) ~= "table" then return false end
	if rule.Enabled == false then return false end
	if not matchString(rule.Side, side) then return false end
	if not matchString(rule.Phase, phaseFor(context, side)) then return false end
	if not matchString(rule.PossessionState or rule.Possession, context.OwnerSide == side and "InPossession" or context.OwnerSide and "OutOfPossession" or "Neutral") then return false end
	if not matchString(rule.MatchState, context.MatchState or context.ExternalPhase or "Live") then return false end
	if not matchString(rule.PlanStep or rule.RequiredPlanStep, extra and extra.PlanStepId or "") then return false end
	if not matchString(rule.Zone or rule.PitchZone, zoneFor(context, side)) then return false end
	if extra then
		if not matchString(rule.Role, extra.Role) then return false end
		if not matchString(rule.Function or rule.TacticalFunction, extra.Function) then return false end
	end
	return true
end

local function addNumber(effect: any, key: string, value: any, low: number?, high: number?)
	local numeric = finite(value)
	if numeric then
		effect[key] = math.clamp((effect[key] or 0) + numeric, low or -math.huge, high or math.huge)
	end
end

local function addSet(effect: any, key: string, value: any)
	if value == nil then return end
	effect[key] = effect[key] or {}
	if type(value) == "table" then
		for _, item in ipairs(value) do effect[key][tostring(item)] = true end
	else
		effect[key][tostring(value)] = true
	end
end

local function applyPositioning(effect: any, rule: any)
	addSet(effect, "AllowedFunctions", rule.AllowedFunction or rule.AllowedFunctions)
	addSet(effect, "ForbiddenFunctions", rule.ForbiddenFunction or rule.ForbiddenFunctions)
	addNumber(effect, "Width", rule.Width or rule.WidthDelta, -1, 1)
	addNumber(effect, "Depth", rule.Depth or rule.DepthDelta, -1, 1)
	addNumber(effect, "Rotation", rule.Rotation or rule.RotationDelta, -1, 1)
	addNumber(effect, "RestDefense", rule.RestDefense or rule.RestDefence or rule.RestDefenseDelta, -4, 4)
	addNumber(effect, "SupportDistance", rule.SupportDistance or rule.SupportDistanceDelta, -1, 1)
	if typeof(rule.TargetRegion) == "Vector3" then effect.TargetRegion = rule.TargetRegion end
end

local function applyPress(effect: any, rule: any)
	addSet(effect, "PresserEligibility", rule.PresserEligibility or rule.EligibleRoles)
	if rule.Trigger then effect.Trigger = text(rule.Trigger) end
	if rule.PressDirection then effect.PressDirection = text(rule.PressDirection) end
	if rule.CoverResponsibility then effect.CoverResponsibility = text(rule.CoverResponsibility) end
	if rule.AbortCondition then effect.AbortCondition = text(rule.AbortCondition) end
	addNumber(effect, "PressHeight", rule.PressHeight or rule.PressHeightDelta, -1, 1)
	addNumber(effect, "Pressers", rule.Pressers or rule.PresserDelta, -4, 4)
end

local function applyPass(effect: any, rule: any)
	if rule.PreferredReceiverFunction then effect.PreferredReceiverFunction = text(rule.PreferredReceiverFunction) end
	if rule.PassFamily then effect.PassFamily = text(rule.PassFamily) end
	if rule.RequiredPlanStep then effect.RequiredPlanStep = text(rule.RequiredPlanStep) end
	addNumber(effect, "Risk", rule.Risk or rule.RiskDelta, -1, 1)
	addNumber(effect, "MinimumLaneQuality", rule.MinimumLaneQuality, 0, 1)
end

local function applySequence(effect: any, rule: any)
	if rule.NextStep then effect.NextStep = text(rule.NextStep) end
	if rule.FallbackRoute or rule.FallbackStep then effect.FallbackStep = text(rule.FallbackRoute or rule.FallbackStep) end
	if rule.PreferredReceiver then effect.PreferredReceiver = text(rule.PreferredReceiver) end
	addSet(effect, "RequiredOccupations", rule.RequiredOccupation or rule.RequiredOccupations)
	addSet(effect, "RunRequests", rule.RunRequest or rule.RunRequests)
end

local function applyRole(effect: any, rule: any)
	addSet(effect, "AllowedFunctions", rule.AllowedFunction or rule.AllowedFunctions)
	addSet(effect, "RunTypes", rule.RunType or rule.RunTypes)
	addSet(effect, "AllowedActions", rule.AllowedAction or rule.AllowedActions)
	addSet(effect, "ForbiddenActions", rule.ForbiddenAction or rule.ForbiddenActions)
	if rule.SupportBehavior then effect.SupportBehavior = text(rule.SupportBehavior) end
	if rule.DefensiveDuty then effect.DefensiveDuty = text(rule.DefensiveDuty) end
	addNumber(effect, "RiskPermission", rule.RiskPermission or rule.RiskDelta, -1, 1)
end

function Service.Evaluate(style: any, context: any, side: string, extra: any?): any
	local plan = context.TeamPlans and context.TeamPlans[side]
	local planStep = plan and plan.PlanStep
	local scope = {
		PlanStepId = extra and extra.PlanStepId or planStep and planStep.Id or "",
		Role = extra and extra.Role or nil,
		Function = extra and extra.Function or nil,
	}
	local effects = {
		Positioning = {},
		Press = {},
		Pass = {},
		Sequence = {},
		Role = {},
		MetricsTargets = type(style and style.MetricsTargets) == "table" and style.MetricsTargets or {},
		ValidRules = 0,
		IgnoredRules = 0,
	}
	local function visit(list: any, apply: (any, any) -> (), target: any)
		for _, rule in ipairs(asList(list)) do
			if ruleMatches(rule, context, side, scope) then
				local ok = pcall(function() apply(target, rule) end)
				if ok then effects.ValidRules += 1 else effects.IgnoredRules += 1 end
			elseif type(rule) ~= "table" then
				effects.IgnoredRules += 1
			end
		end
	end
	visit(style and style.PositioningRules, applyPositioning, effects.Positioning)
	visit(style and style.PressRules, applyPress, effects.Press)
	visit(style and style.PassRules, applyPass, effects.Pass)
	visit(style and style.SequenceRules, applySequence, effects.Sequence)
	visit(style and style.RoleInstructions, applyRole, effects.Role)
	return effects
end

function Service.ContextFor(context: any, side: string, role: string?, functionName: string?): any
	return {
		Phase = phaseFor(context, side),
		Role = role,
		MatchState = context.MatchState or context.ExternalPhase or "Live",
		PlanStep = context.TeamPlans and context.TeamPlans[side] and context.TeamPlans[side].PlanStep and context.TeamPlans[side].PlanStep.Id or "",
		PitchZone = zoneFor(context, side),
		PossessionState = context.OwnerSide == side and "InPossession" or context.OwnerSide and "OutOfPossession" or "Neutral",
		Emergency = context.LooseBall and {LooseBallAggression = 85} or context.PassInFlight and {ReceiverTrapAggression = 85} or nil,
	}
end

return Service
