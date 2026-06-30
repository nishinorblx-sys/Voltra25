--!strict
local Service = {}
Service.__index = Service

local DEFAULTS = {
	BuildUpSpeed = 50,
	PassingDirectness = 50,
	AttackingWidth = 50,
	DefensiveWidth = 50,
	DefensiveDepth = 50,
	PressingIntensity = 50,
	CounterAttackFrequency = 45,
	OverlapFrequency = 45,
	CrossingFrequency = 45,
	LongShotFrequency = 35,
	DribblingFreedom = 45,
	RiskLevel = 45,
	SupportDistance = 50,
	PassTempo = 50,
	ForwardPassPriority = 50,
	BackPassSafety = 50,
	SwitchPlayFrequency = 50,
	ThroughBallFrequency = 50,
	PassRisk = 50,
	FirstTouchDirectness = 50,
	ReceiverTrapAggression = 50,
	RunsInBehind = 50,
	UnderlapFrequency = 50,
	BoxRuns = 50,
	CutbackFrequency = 50,
	FinalThirdPatience = 50,
	ShotPatience = 50,
	OneTouchPassing = 50,
	WidthDiscipline = 50,
	FullbackAttack = 50,
	MidfieldRotation = 50,
	CreativeFreedom = 50,
	PressTriggerDistance = 50,
	CounterPress = 50,
	TackleAggression = 50,
	InterceptionRisk = 50,
	MarkingTightness = 50,
	LaneBlocking = 50,
	BackLineCompactness = 50,
	BoxProtection = 50,
	ZoneDiscipline = 50,
	LooseBallAggression = 50,
	RecoveryRuns = 50,
	SprintConservation = 50,
	KeeperAggression = 50,
	KeeperDistributionRisk = 50,
	ShortGKDistribution = 50,
	LongGKDistribution = 50,
	FreeKickShortPass = 50,
	FreeKickLongPass = 50,
	CornerNearPost = 50,
	CornerFarPost = 50,
	SetPiecePatience = 50,
	ClearanceHeight = 50,
	StaminaPressLimit = 50,
	DefensiveLineStepUp = 50,
}

function Service.new(tactics: any?)
	local sliders = type(tactics) == "table" and type(tactics.Sliders) == "table" and tactics.Sliders or {}
	local self = {Sliders = {}}
	for name, fallback in pairs(DEFAULTS) do
		self.Sliders[name] = math.clamp(tonumber(sliders[name]) or fallback, 0, 100)
	end
	return setmetatable(self, Service)
end

function Service:Get(name: string): number
	return self.Sliders[name] or DEFAULTS[name] or 50
end

function Service:Ratio(name: string): number
	return math.clamp(self:Get(name) / 100, 0, 1)
end

function Service:BuildUpTempo(): number
	return self:Ratio("BuildUpSpeed")
end

function Service:Directness(): number
	return self:Ratio("PassingDirectness")
end

function Service:Risk(): number
	return self:Ratio("RiskLevel")
end

function Service:Pressing(): number
	return self:Ratio("PressingIntensity")
end

function Service:CanOverlap(stamina: number): boolean
	return stamina > 28 and self:Ratio("OverlapFrequency") > 0.25
end

return Service
