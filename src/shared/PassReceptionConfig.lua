--!strict

export type ModeConfig = {
	PreSwitchRouteWeight: number,
	PostSwitchRouteWeight: number,
	UserRouteInfluence: number,
	CameraPrepareETA: number,
	ControlTransferETA: number,
	AutoSprint: string,
	RouteCorridor: number,
	ContactTolerance: number,
	FirstTouchAssistance: number,
	ExplicitOverrideOnly: boolean,
	DecisiveInputThreshold: number,
	InterceptSmoothing: number,
	MaximumTargetSpeed: number,
	CancellationDivergence: number,
	AllowedControlHeight: number,
	ContactWindowSeconds: number,
	EndpointCorrectionStuds: {[string]: number},
}

local endpointNewcomer = table.freeze({Ground = 4.5, Through = 8.5, Lob = 5.5, Cross = 1.5, Manual = 0})
local endpointStandard = table.freeze({Ground = 2.25, Through = 4.25, Lob = 2.5, Cross = 0.75, Manual = 0})
local endpointManual = table.freeze({Ground = 0, Through = 0, Lob = 0, Cross = 0, Manual = 0})

local values: {[string]: ModeConfig} = table.freeze({
	Newcomer = table.freeze({
		PreSwitchRouteWeight = 1,
		PostSwitchRouteWeight = 1,
		UserRouteInfluence = 0,
		CameraPrepareETA = 1,
		ControlTransferETA = 0.66,
		AutoSprint = "Required",
		RouteCorridor = 6.5,
		ContactTolerance = 3.05,
		FirstTouchAssistance = 0.92,
		ExplicitOverrideOnly = true,
		DecisiveInputThreshold = 1.1,
		InterceptSmoothing = 0.18,
		MaximumTargetSpeed = 52,
		CancellationDivergence = 0.42,
		AllowedControlHeight = 6.4,
		ContactWindowSeconds = 0.35,
		EndpointCorrectionStuds = endpointNewcomer,
	}),
	Standard = table.freeze({
		PreSwitchRouteWeight = 1,
		PostSwitchRouteWeight = 0.8,
		UserRouteInfluence = 0.2,
		CameraPrepareETA = 0.75,
		ControlTransferETA = 0.43,
		AutoSprint = "ClearlyRequired",
		RouteCorridor = 5,
		ContactTolerance = 2.65,
		FirstTouchAssistance = 0.62,
		ExplicitOverrideOnly = false,
		DecisiveInputThreshold = 0.78,
		InterceptSmoothing = 0.24,
		MaximumTargetSpeed = 44,
		CancellationDivergence = 0.5,
		AllowedControlHeight = 5.8,
		ContactWindowSeconds = 0.3,
		EndpointCorrectionStuds = endpointStandard,
	}),
	Manual = table.freeze({
		PreSwitchRouteWeight = 1,
		PostSwitchRouteWeight = 0,
		UserRouteInfluence = 1,
		CameraPrepareETA = -1,
		ControlTransferETA = -1,
		AutoSprint = "PreSwitchOnly",
		RouteCorridor = 3.5,
		ContactTolerance = 2.25,
		FirstTouchAssistance = 0.2,
		ExplicitOverrideOnly = false,
		DecisiveInputThreshold = 0,
		InterceptSmoothing = 0.3,
		MaximumTargetSpeed = 38,
		CancellationDivergence = 0.58,
		AllowedControlHeight = 5.2,
		ContactWindowSeconds = 0.24,
		EndpointCorrectionStuds = endpointManual,
	}),
})

local phases = table.freeze({"Anticipating", "Committed", "ControlPrepared", "ContactWindow", "FirstTouch", "Completed", "Cancelled"})
local phaseSet: {[string]: boolean} = {}
for _, phase in phases do phaseSet[phase] = true end

local terminalReasons = table.freeze({
	IntendedReceiverControlled = true,
	AlternateTeammateControlled = true,
	FirstTimePass = true,
	FirstTimeShot = true,
	OpponentIntercepted = true,
	BallDeflectedLoose = true,
	BallOut = true,
	Foul = true,
	Offside = true,
	Goal = true,
	ReceiverInvalid = true,
	ReceiverUnreachable = true,
	TrajectoryReplaced = true,
	ContractExpired = true,
	ManualOverride = true,
	MatchInterrupted = true,
	GoalkeeperClaim = true,
	Substitution = true,
	NewPassReplacedContract = true,
	SetPiece = true,
	HalfTime = true,
	FullTime = true,
})

local function normalizeMode(value: any): string
	local mode = tostring(value or "Standard")
	return values[mode] and mode or "Standard"
end

local function get(value: any): ModeConfig
	return values[normalizeMode(value)]
end

local function normalizeFamily(value: any): string
	local family = tostring(value or "Ground")
	if family == "Lofted" or family == "ManualLobbed" then return "Lob" end
	if family == "BackPass" then return "Ground" end
	if family == "Driven" then return "Through" end
	if family == "Ground" or family == "Through" or family == "Lob" or family == "Cross" or family == "Manual" then return family end
	return "Ground"
end

return table.freeze({
	Modes = table.freeze({"Newcomer", "Standard", "Manual"}),
	Values = values,
	Phases = phases,
	PhaseSet = table.freeze(phaseSet),
	TerminalReasons = terminalReasons,
	NormalizeMode = normalizeMode,
	NormalizeFamily = normalizeFamily,
	Get = get,
	UpdateRate = 15,
	CandidateInterval = 0.08,
	CandidateHorizon = 5.6,
	MinimumCandidateTime = 0.08,
	MinimumContractDuration = 0.55,
	MaximumContractDuration = 8,
	ContactPreparationSeconds = 0.08,
	ReachSafetySeconds = 0.1,
	OpponentWinMargin = 0.08,
	RetargetAdvantageSeconds = 0.22,
	RetargetHysteresisSeconds = 0.28,
	MaximumRetargets = 2,
	MaximumNearbyOpponentDistance = 110,
	InputTimestampWindow = 1,
	InputRateSeconds = 0.04,
	ActionRateSeconds = 0.08,
	OverrideRateSeconds = 0.1,
	QueuedActionMaximumSeconds = 0.58,
	EndpointCorrectionTravelLimit = 0.55,
})
