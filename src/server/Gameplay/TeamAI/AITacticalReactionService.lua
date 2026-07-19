--!strict

local AIStyleProfileService = require(script.Parent.AIStyleProfileService)

local Service = {}

local ATTACK_REACTIONS: {[string]: any} = {
	PositionalControl = {CentralScreens = .22, ZoneDiscipline = .18, PressChase = -.12, LineGap = -.08},
	VerticalCombination = {LineGap = -.22, BetweenLinesPressure = .24, RunnerTracking = .2, DepthCover = .16},
	DirectAssault = {LineHeight = -.28, DepthCover = .3, SecondBallCoverage = .24, CenterBackStepOut = -.22},
	WideOverload = {BallSideShift = .24, CutbackProtection = .28, FarPostProtection = .28, SwitchDefender = .18, CenterBackWidePull = -.22},
	CentralDomination = {BlockWidth = -.22, CentralScreens = .3, LaneProtection = .3, ForceOutside = .24},
	CounterattackingTrap = {RestDefense = .28, AttackingCommitment = -.22, PressBait = -.2},
	HighPressSwarm = {ImmediateCentralProtection = .24, LineRecovery = .2, LooseBallOvercommit = -.18},
	LowBlockFortress = {ForwardOutletProtection = .24, SecondRunnerTracking = .22, FullbackAdvance = -.22},
	FluidRotation = {ZoneDiscipline = .28, Handoff = .24, LongTracking = -.18},
	AdaptiveController = {ReactionHysteresis = .24, MixedResponse = .2},
}

local DEFENSE_REACTIONS: {[string]: any} = {
	StructuredContainment = {AttackingWidth = .12, SupportDistance = .08, CentralForce = -.08},
	LaneDisruption = {AttackingWidth = .2, ThirdMan = .22, AroundCoverShadow = .24},
	DepthProtection = {BetweenLines = .24, Patience = .18, BoxEntryControl = .2, DirectOutlet = -.1},
	FlankIsolation = {SwitchPreference = .34, InsideSupport = .24, WingRisk = -.12},
	CentralLock = {AttackingWidth = .32, OutsideInside = .24},
	BaitAndCollapse = {RestDefense = .28, TrapAvoidance = .26, RepeatPattern = -.16},
	CollectiveHunt = {CloseEscapeSupport = .32, DirectOutlet = .3, SupportDistance = -.18},
	BoxProtection = {AttackingWidth = .24, CutbackPreference = .3, SecondBallCoverage = .24, BoxEdgeOccupation = .22},
	DynamicCoverage = {TemporaryOverload = .24, SwitchPreference = .22, Tempo = .18},
	TacticalCounterSystem = {MixedRoutes = .24, RepeatPattern = -.24},
}

local function topTwo(confidence: {[string]: number}): {any}
	local list = {}
	for key, value in pairs(confidence or {}) do
		table.insert(list, {Key = key, Value = tonumber(value) or 0})
	end
	table.sort(list, function(a, b)
		if a.Value == b.Value then return a.Key < b.Key end
		return a.Value > b.Value
	end)
	return {list[1], list[2]}
end

local function addWeighted(output: any, source: any, weight: number)
	for key, value in pairs(source or {}) do
		output[key] = (output[key] or 0) + (tonumber(value) or 0) * weight
	end
end

local function blend(confidence: {[string]: number}, matrix: any): any
	local output = {}
	local strongest = topTwo(confidence)
	local total = 0
	for _, item in ipairs(strongest) do
		if item and item.Value > 0 then total += item.Value end
	end
	if total <= 0 then return output end
	for _, item in ipairs(strongest) do
		if item and item.Value > 0 then
			addWeighted(output, matrix[item.Key], item.Value / total)
		end
	end
	output.Top = strongest[1] and strongest[1].Key or ""
	output.Second = strongest[2] and strongest[2].Key or ""
	output.TopConfidence = strongest[1] and strongest[1].Value or 0
	output.SecondConfidence = strongest[2] and strongest[2].Value or 0
	output.Blended = strongest[1] ~= nil and strongest[2] ~= nil and (strongest[2].Value or 0) >= (strongest[1].Value or 0) * .62
	return output
end

function Service.ForSide(context: any, side: string): any
	local observation = context.OpponentObservation and context.OpponentObservation[side]
	local attack = observation and observation.OpponentAttackConfidence or {}
	local defense = observation and observation.OpponentDefenseConfidence or {}
	local againstAttack = blend(attack, ATTACK_REACTIONS)
	local againstDefense = blend(defense, DEFENSE_REACTIONS)
	local active = context.OwnerSide == side and againstDefense or againstAttack
	return {
		AgainstOpponentAttack = againstAttack,
		AgainstOpponentDefense = againstDefense,
		Active = active,
		OpponentAttackIdentity = observation and observation.OpponentAttackIdentity or select(1, AIStyleProfileService.Leading(attack)),
		OpponentDefenseIdentity = observation and observation.OpponentDefenseIdentity or select(1, AIStyleProfileService.Leading(defense)),
	}
end

function Service.ApplyNumber(base: number, reaction: any, key: string, scale: number, low: number, high: number): number
	return math.clamp(base + (tonumber(reaction and reaction[key]) or 0) * scale, low, high)
end

return Service
