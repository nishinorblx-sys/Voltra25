--!strict

local AIPlayerBrain = require(script.Parent.Parent.AIPlayerBrain)

local Brain = {}
Brain.__index = Brain

local STYLE_KEYS = {
	"PositionalControl",
	"VerticalCombination",
	"DirectAssault",
	"WideOverload",
	"CentralDomination",
	"CounterattackingTrap",
	"HighPressSwarm",
	"LowBlockFortress",
	"FluidRotation",
	"AdaptiveController",
}

local DEFENSIVE_NAMES = {
	PositionalControl = "StructuredContainment",
	VerticalCombination = "LaneDisruption",
	DirectAssault = "DepthProtection",
	WideOverload = "FlankIsolation",
	CentralDomination = "CentralLock",
	CounterattackingTrap = "BaitAndCollapse",
	HighPressSwarm = "CollectiveHunt",
	LowBlockFortress = "BoxProtection",
	FluidRotation = "DynamicCoverage",
	AdaptiveController = "TacticalCounterSystem",
}

local function ratio(style: any, key: string, fallback: number?): number
	if style and style.Ratio then
		local ok, value = pcall(function() return style:Ratio(key) end)
		if ok and type(value) == "number" then return math.clamp(value, 0, 1) end
	end
	return fallback or .5
end

local function styleConfidence(style: any): any
	local direct = ratio(style, "PassingDirectness")
	local tempo = ratio(style, "PassTempo")
	local width = ratio(style, "AttackingWidth")
	local press = ratio(style, "PressingIntensity")
	local depth = ratio(style, "DefensiveDepth")
	local compact = ratio(style, "BackLineCompactness")
	local support = ratio(style, "SupportDistance")
	local runs = ratio(style, "RunsInBehind")
	local rotation = ratio(style, "MidfieldRotation")
	local counter = ratio(style, "CounterAttackFrequency")
	local cross = ratio(style, "CrossingFrequency")
	local closeSupportBonus = support < .45 and .14 or .04
	local fluidLaneBonus = ratio(style, "WidthDiscipline") < .45 and .12 or .04
	local scores = {
		PositionalControl = (1 - direct) * .22 + (1 - tempo) * .18 + (1 - math.abs(support - .34)) * .18 + compact * .16 + (1 - counter) * .12,
		VerticalCombination = direct * .22 + tempo * .2 + closeSupportBonus + runs * .14 + ratio(style, "OneTouchPassing") * .16,
		DirectAssault = direct * .24 + tempo * .2 + runs * .2 + counter * .14 + (1 - support) * .1,
		WideOverload = width * .3 + cross * .2 + ratio(style, "OverlapFrequency") * .18 + ratio(style, "UnderlapFrequency") * .12 + ratio(style, "SwitchPlayFrequency") * .1,
		CentralDomination = (1 - width) * .2 + rotation * .22 + (1 - support) * .18 + ratio(style, "ThroughBallFrequency") * .12 + compact * .08,
		CounterattackingTrap = counter * .28 + (1 - depth) * .16 + (1 - press) * .12 + compact * .18 + direct * .12,
		HighPressSwarm = press * .34 + depth * .22 + ratio(style, "CounterPress") * .16 + ratio(style, "PressTriggerDistance") * .12,
		LowBlockFortress = (1 - depth) * .28 + compact * .24 + ratio(style, "BoxProtection") * .18 + (1 - press) * .12,
		FluidRotation = rotation * .28 + ratio(style, "CreativeFreedom") * .18 + fluidLaneBonus + ratio(style, "UnderlapFrequency") * .12,
		AdaptiveController = math.min(.95, math.max(direct, 1 - direct) * .1 + math.max(press, 1 - press) * .1 + ratio(style, "RiskLevel") * .12 + ratio(style, "DecisionCommitment") * .12),
	}
	local total = 0
	for _, key in ipairs(STYLE_KEYS) do
		scores[key] = math.clamp(scores[key] or 0, 0, 1)
		total += scores[key]
	end
	if total > 0 then
		for _, key in ipairs(STYLE_KEYS) do scores[key] = math.clamp(scores[key] / total * 2.8, 0, 1) end
	end
	return scores
end

local function leadingStyle(confidence: any): string
	local best = "PositionalControl"
	local bestScore = -math.huge
	for _, key in ipairs(STYLE_KEYS) do
		local score = tonumber(confidence[key]) or 0
		if score > bestScore then
			best = key
			bestScore = score
		end
	end
	return best
end

local function observedOpponent(context: any, side: string, style: any): any
	local opponent = side == "Home" and "Away" or "Home"
	local team = context.Teams and context.Teams[opponent] and context.Teams[opponent].List or {}
	local count = 0
	local nearBall = 0
	local wide = 0
	local high = 0
	for _, info in ipairs(team) do
		if info.Root then
			count += 1
			if context.BallWorld and info.World and (Vector3.new(info.World.X - context.BallWorld.X, 0, info.World.Z - context.BallWorld.Z)).Magnitude <= 75 then nearBall += 1 end
			if info.Pitch and (info.Pitch.X < 100 or info.Pitch.X > 324) then wide += 1 end
			if info.Pitch and info.Pitch.Z > 430 then high += 1 end
		end
	end
	local base = styleConfidence(style)
	if count > 0 then
		base.WideOverload = math.clamp(base.WideOverload + wide / count * .22, 0, 1)
		base.CentralDomination = math.clamp(base.CentralDomination + (1 - wide / count) * .12, 0, 1)
		base.DirectAssault = math.clamp(base.DirectAssault + high / count * .16, 0, 1)
		base.HighPressSwarm = math.clamp(base.HighPressSwarm + nearBall / count * .18, 0, 1)
		base.FluidRotation = math.clamp(base.FluidRotation + math.min(.18, nearBall / math.max(1, count) * .08), 0, 1)
	end
	return base
end

local function buildDeclaration(context: any, side: string, style: any, opponentStyle: any): any
	local ownConfidence = styleConfidence(style)
	local identity = leadingStyle(ownConfidence)
	local opponentConfidence = observedOpponent(context, side, opponentStyle)
	local opponentIdentity = leadingStyle(opponentConfidence)
	local attackCorridor = identity == "WideOverload" and "Wide" or identity == "CentralDomination" and "Central" or identity == "DirectAssault" and "Behind" or identity == "CounterattackingTrap" and "CounterLanes" or "Balanced"
	local defensiveIdentity = DEFENSIVE_NAMES[identity] or "StructuredContainment"
	local compactness = math.clamp((ratio(style, "BackLineCompactness") + ratio(style, "LaneBlocking") + ratio(style, "BoxProtection")) / 3, 0, 1)
	local lineHeight = ratio(style, "DefensiveDepth")
	local press = ratio(style, "PressingIntensity")
	local support = ratio(style, "SupportDistance")
	local runners = math.clamp(math.floor(1 + ratio(style, "RunsInBehind") * 3 + ratio(style, "CounterAttackFrequency") * 1.5), 1, 5)
	if opponentIdentity == "DirectAssault" then
		lineHeight = math.min(lineHeight, .44)
		compactness = math.max(compactness, .72)
	elseif opponentIdentity == "WideOverload" then
		compactness = math.max(compactness, .62)
	elseif opponentIdentity == "CentralDomination" or opponentIdentity == "VerticalCombination" then
		compactness = math.max(compactness, .78)
	elseif opponentIdentity == "HighPressSwarm" then
		support = math.min(support, .38)
	end
	return {
		Side = side,
		AttackingIdentity = identity,
		DefensiveIdentity = defensiveIdentity,
		OpponentIdentity = opponentIdentity,
		OpponentStyleConfidence = opponentConfidence,
		OwnStyleConfidence = ownConfidence,
		AttackCorridor = attackCorridor,
		FormationWidth = ratio(style, "AttackingWidth"),
		DefensiveLineHeight = lineHeight,
		TeamCompactness = compactness,
		BallSideShift = ratio(style, "DefensiveWidth") < .5 and .72 or .56,
		SupportDistance = support,
		ForwardPassPreference = ratio(style, "ForwardPassPriority"),
		PassingTempo = ratio(style, "PassTempo"),
		RiskTolerance = ratio(style, "RiskLevel"),
		AttackingRunners = runners,
		RotationFrequency = ratio(style, "MidfieldRotation"),
		CounterattackCommitment = ratio(style, "CounterAttackFrequency"),
		PressingIntensity = press,
		RestDefense = math.max(2, math.floor(2 + compactness * 3 + ratio(style, "RestDefenseMinimum", .5) * 2)),
		AfterGain = identity == "CounterattackingTrap" or identity == "DirectAssault" and "ForwardFirst" or identity == "PositionalControl" and "SecureShape" or "ExploitOpening",
		AfterLoss = press > .68 and "Counterpress" or compactness > .7 and "RestoreCompactShape" or "RecoverShape",
	}
end

function Brain.new(ballService: any, styles: any, difficulty: any): any
	local home = AIPlayerBrain.new(ballService, styles.Home, difficulty)
	local away = AIPlayerBrain.new(ballService, styles.Away, difficulty)
	return setmetatable({
		BallService = ballService,
		Styles = styles,
		Difficulty = difficulty,
		Execution = {Home = home, Away = away},
		Declarations = {Home = nil, Away = nil},
		LastAction = {},
	}, Brain)
end

function Brain:SetImmediateReceiverRoute(callback: any)
	for _, side in ipairs({"Home", "Away"}) do
		local executor = self.Execution[side]
		if executor then executor:SetImmediateReceiverRoute(callback) end
	end
end

function Brain:UpdateStyle(side: string, style: any)
	local targetSide = side == "Away" and "Away" or "Home"
	self.Styles[targetSide] = style
	self.Execution[targetSide] = AIPlayerBrain.new(self.BallService, style, self.Difficulty)
end

function Brain:Clear(side: string?)
	if side then
		local targetSide = side == "Away" and "Away" or "Home"
		if self.Execution[targetSide] then self.Execution[targetSide]:Clear() end
		self.Declarations[targetSide] = nil
	else
		for _, executor in pairs(self.Execution) do executor:Clear() end
		self.Declarations = {Home = nil, Away = nil}
	end
end

function Brain:ResetFootballer(model: Model)
	for _, executor in pairs(self.Execution) do
		executor.NextDecision[model] = nil
		executor.CarrySince[model] = nil
		executor.LastAction[model] = nil
	end
end

function Brain:Declare(context: any): any
	local declarations = {}
	for _, side in ipairs({"Home", "Away"}) do
		declarations[side] = buildDeclaration(context, side, self.Styles[side], self.Styles[side == "Home" and "Away" or "Home"])
		for _, info in ipairs(context.Teams[side].List) do
			info.Model:SetAttribute("AITeamBrainAttack", declarations[side].AttackingIdentity)
			info.Model:SetAttribute("AITeamBrainDefense", declarations[side].DefensiveIdentity)
			info.Model:SetAttribute("AITeamBrainOpponent", declarations[side].OpponentIdentity)
			info.Model:SetAttribute("AITeamBrainCorridor", declarations[side].AttackCorridor)
			info.Model:SetAttribute("AITeamBrainRunners", declarations[side].AttackingRunners)
			info.Model:SetAttribute("AITeamBrainCompactness", declarations[side].TeamCompactness)
			info.Model:SetAttribute("AITeamBrainLineHeight", declarations[side].DefensiveLineHeight)
			info.Model:SetAttribute("AITeamBrainAfterGain", declarations[side].AfterGain)
			info.Model:SetAttribute("AITeamBrainAfterLoss", declarations[side].AfterLoss)
		end
	end
	self.Declarations = declarations
	context.TeamBrain = declarations
	return declarations
end

function Brain:Step(context: any, assignmentsBySide: any)
	self:Declare(context)
	for _, side in ipairs({"Home", "Away"}) do
		local executor = self.Execution[side]
		if executor then executor:StepSide(context, assignmentsBySide, side) end
	end
end

return Brain
