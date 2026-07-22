--!strict

local HttpService = game:GetService("HttpService")

local AITacticConfig = require(script.Parent.AITacticConfig)
local AIBehaviorTuningConfig = require(script.Parent.AIBehaviorTuningConfig)

local Config = {}

Config.SchemaVersion = 1
Config.MaxDrafts = 30
Config.MaxPublishedFamilies = 30
Config.MaxImportBytes = 60000

local HIGH_IMPACT = {
	"BuildUpSpeed",
	"PassTempo",
	"PassingDirectness",
	"RunsInBehind",
	"PressingIntensity",
	"DefensiveDepth",
	"BackLineCompactness",
	"LaneBlocking",
	"SupportDistance",
	"WidthDiscipline",
}

local BASIC_PLAYSTYLE_ID = "basic_possession"
local QUICK_PASSING_PLAYSTYLE_ID = "quick_passing"
local VERTICAL_TIKI_TAKA_PLAYSTYLE_ID = "vertical_tiki_taka"
local WING_PLAY_PLAYSTYLE_ID = "wing_play"
local ROUTE_ONE_PLAYSTYLE_ID = "route_one"
local PARK_THE_BUS_PLAYSTYLE_ID = "park_the_bus"
local COUNTER_ATTACK_PLAYSTYLE_ID = "counter_attack"
local GEGENPRESS_PLAYSTYLE_ID = "gegenpress"

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end

local function now(): number
	return os.time()
end

local function safeText(value: any, fallback: string, maximum: number): string
	local text = tostring(value or ""):gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then text = fallback end
	if #text > maximum then text = text:sub(1, maximum) end
	return text
end

local function slug(value: any, fallback: string): string
	local text = string.lower(safeText(value, fallback, 48))
	text = text:gsub("[^%w_%- ]", ""):gsub("%s+", "_"):gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
	if text == "" then text = fallback end
	return text:sub(1, 48)
end

local function countMap(map: any): number
	local count = 0
	for _ in pairs(type(map) == "table" and map or {}) do count += 1 end
	return count
end

local function cleanRules(list: any, maximum: number): {any}
	local result = {}
	if type(list) ~= "table" then return result end
	for _, item in ipairs(list) do
		if type(item) == "table" and #result < maximum then
			local nextItem = {}
			for key, value in pairs(item) do
				if type(key) == "string" and #key <= 40 and type(value) ~= "function" and type(value) ~= "userdata" and type(value) ~= "thread" then
					nextItem[key] = clone(value)
				end
			end
			table.insert(result, nextItem)
		end
	end
	return result
end

local function builtInPlaystyle(presetId: string): any
	local preset = AITacticConfig.Get(presetId)
	return {
		SchemaVersion = Config.SchemaVersion,
		PlaystyleId = preset.Id,
		Version = 1,
		Status = "Published",
		Name = preset.Name,
		Description = preset.Description,
		BasePresetId = preset.Id,
		Tactics = AITacticConfig.Normalize({PresetId = preset.Id}),
		RoleInstructions = {},
		PassRules = {},
		PositioningRules = {},
		PressRules = {},
		SequenceRules = {},
		MetricsTargets = {Possession = 50, PassCompletion = 84, ShotQuality = 50, Compactness = 60},
		CreatedAt = 0,
		UpdatedAt = 0,
		PublishedAt = 0,
		AuthorUserId = 0,
		BuiltIn = true,
	}
end

local function basicPossessionPlaystyle(): any
	local preset = AITacticConfig.Get("balanced_control")
	local tactics = AITacticConfig.Normalize({
		PresetId = "balanced_control",
		Sliders = {
			BuildUpSpeed = 48,
			PassTempo = 66,
			PassingDirectness = 32,
			ForwardPassPriority = 46,
			BackPassSafety = 78,
			SwitchPlayFrequency = 68,
			SupportDistance = 34,
			PressingIntensity = 54,
			DefensiveDepth = 58,
			BackLineCompactness = 66,
			LaneBlocking = 72,
			ZoneDiscipline = 76,
			DefensiveLineStepUp = 68,
			RunsInBehind = 34,
			WidthDiscipline = 76,
		},
	})
	return {
		SchemaVersion = Config.SchemaVersion,
		PlaystyleId = BASIC_PLAYSTYLE_ID,
		Version = 1,
		Status = "Published",
		Name = "SAFE Possession",
		Description = "Simple unit football: safe possession plus compact five-lane defending with two central CBs, wide fullback cover, midfield screens, and limited pressers.",
		BasePresetId = preset.Id,
		Tactics = tactics,
		RoleInstructions = {
			{Phase = "InPossession", Role = {"CB", "Fullback", "CDM", "CM", "CAM", "Winger", "ST"}, AllowedFunctions = {"SupportShort", "SupportBehind", "HoldLane", "StretchFarSide", "RunBehindBlockedLane"}, SupportBehavior = "TwoShortOptionsAndReset"},
			{Phase = "InPossession", Role = {"Winger", "ST", "CAM"}, RunTypes = {"BlockedLaneRunBehind"}, RiskPermissions = "OnlyWhenPasserFacesForwardAndOnside"},
			{Phase = "OutOfPossession", Role = {"ST", "Winger", "CAM", "CM", "CDM", "Fullback", "CB"}, DefensiveDuty = "CompactFiveLaneBlock", AllowedFunctions = {"PressBall", "BlockForwardLane", "CoverBehindPresser", "CoverWing", "TrackDirectPass", "HoldLine"}},
		},
		PassRules = {
			{Phase = "InPossession", PassFamily = "Safe Forward", Risk = -.28, MinimumLaneQuality = .68, RequiredPlanStep = "FirstLook"},
			{Phase = "InPossession", PassFamily = "Sideways", Risk = -.36, MinimumLaneQuality = .62, RequiredPlanStep = "ForwardBlocked"},
			{Phase = "InPossession", PassFamily = "Backward Reset", Risk = -.42, MinimumLaneQuality = .58, RequiredPlanStep = "NoSafeSidePass"},
			{Phase = "InPossession", PreferredReceiverFunction = "FarSideWide", PassFamily = "Switch", Risk = -.14, MinimumLaneQuality = .64, RequiredPlanStep = "AfterSafePasses"},
		},
		PositioningRules = {
			{Phase = "InPossession", TargetRegion = "BallSideTriangle", SupportDistance = -.28, Width = .1, RestDefense = 1},
			{Phase = "InPossession", TargetRegion = "FiveLaneOccupation", Width = .18, Rotation = "MoveWithBallAfterPass"},
			{Phase = "InPossession", Function = "FarSideWide", Width = .24, Depth = .04},
			{Phase = "OutOfPossession", Depth = .12, Width = -.06, RestDefense = 1, SupportDistance = -.12},
		},
		PressRules = {
			{Phase = "OutOfPossession", Trigger = "OpponentCarrier", PresserEligibility = {"NearestNonGoalkeeper"}, PressDirection = "CenterSideToWide", CoverResponsibility = "SecondNearestBlocksForwardPass", Pressers = 1, PressHeight = .08, AbortCondition = "PassThroughFirstPressure"},
			{Phase = "OutOfPossession", Trigger = "DirectPassLaunched", PresserEligibility = {"NearestBackLine"}, PressDirection = "AttackReceiver", CoverResponsibility = "OneDefenderBehindOneMidfielderSecondBall", Pressers = 1},
			{Phase = "OutOfPossession", PitchZone = "DefensiveThird", Trigger = "ProtectBoxEdge", PressDirection = "HoldLineAndScreenCenter", CoverResponsibility = "TwoCBsCentralFullbacksWide", Pressers = 1},
		},
		SequenceRules = {
			{Phase = "InPossession", NextStep = "safe-forward", PreferredReceiver = "free-midfielder-or-winger", RequiredOccupations = {"short-option", "reset-behind", "far-side-wide"}, FallbackStep = "sideways"},
			{Phase = "InPossession", NextStep = "sideways", PreferredReceiver = "different-angle-option", RequiredOccupations = {"five-lanes"}, FallbackStep = "reset"},
			{Phase = "InPossession", NextStep = "blocked-lane-run", PreferredReceiver = "runner-behind-defender", RequiredOccupations = {"passer-facing-forward", "runner-onside"}, FallbackStep = "return-to-shape"},
		},
		MetricsTargets = {Possession = 56, PassCompletion = 88, ShotQuality = 46, Compactness = 82, DistributedPress = 72, BoxEdgeRetreatLimit = 132, ShortOptions = 2, MaxRunsBehind = 2, LaneOccupation = 5, CompactDefense = 1, MaxNormalBackLineSteppers = 1},
		CreatedAt = 0,
		UpdatedAt = 0,
		PublishedAt = 0,
		AuthorUserId = 0,
		BuiltIn = true,
	}
end

local function quickPassingPlaystyle(): any
	local preset = AITacticConfig.Get("short_possession")
	local tactics = AITacticConfig.Normalize({
		PresetId = "short_possession",
		Sliders = {
			BuildUpSpeed = 52,
			PassTempo = 84,
			PassingDirectness = 24,
			ForwardPassPriority = 48,
			BackPassSafety = 86,
			SwitchPlayFrequency = 62,
			ThroughBallFrequency = 48,
			LobPassBias = 12,
			FreeKickLongPass = 15,
			LongGKDistribution = 10,
			ShortGKDistribution = 94,
			OneTouchPassing = 90,
			FirstTouchDirectness = 62,
			ReceiverTrapAggression = 22,
			CounterAttackFrequency = 28,
			RiskLevel = 36,
			PassRisk = 34,
			PossessionPatience = 94,
			SupportDistance = 18,
			ImmediateSupportDistance = 18,
			RunsInBehind = 26,
			MaxMajorRuns = 30,
			OverlapFrequency = 42,
			UnderlapFrequency = 64,
			FullbackAttack = 54,
			AttackingWidth = 54,
			WidthDiscipline = 84,
			MidfieldRotation = 92,
			BoxRuns = 52,
			CutbackFrequency = 76,
			CrossingFrequency = 18,
			DefensiveDepth = 64,
			DefensiveWidth = 48,
			PressingIntensity = 66,
			PressTriggerDistance = 66,
			CounterPress = 72,
			BackLineCompactness = 76,
			LaneBlocking = 82,
			ZoneDiscipline = 82,
			DefensiveLineStepUp = 74,
			BoxProtection = 64,
			MarkingTightness = 64,
			InterceptionRisk = 58,
			RecoveryRuns = 72,
			TackleAggression = 48,
			StaminaPressLimit = 72,
			SprintConservation = 56,
			LongShotFrequency = 20,
			ShotPatience = 86,
			CreativeFreedom = 72,
			FinalThirdPatience = 90,
		},
		GlobalOverrides = {
			MinimumHoldTime = 0.05,
			MaximumHoldTime = 0.85,
		},
		ExecutionOverrides = {
			PassReception = {
				MinimumHoldTime = 0,
				FirstTouchDirectness = 94,
				OneTouchPassing = 96,
				ReceiverTrapAggression = 10,
			},
		},
	})
	return {
		SchemaVersion = Config.SchemaVersion,
		PlaystyleId = QUICK_PASSING_PLAYSTYLE_ID,
		Version = 1,
		Status = "Published",
		Name = "Tiki-Taka",
		Description = "Short pass-and-move football that overwhelms defenders through triangles, rotations, one-touch combinations, and constant repositioning instead of speed.",
		BasePresetId = preset.Id,
		Tactics = tactics,
		RoleInstructions = {
			{Phase = "InPossession", Role = {"CB", "Fullback", "CDM", "CM", "CAM", "Winger", "ST"}, AllowedFunctions = {"FirstTimePass", "SupportShort", "ThirdManRun", "ForwardOpenSpaceRun", "HoldLane"}, SupportBehavior = "PassAndMoveTwoOptions"},
			{Phase = "InPossession", Role = {"CM", "CAM", "Winger", "ST"}, RunTypes = {"PostPassOpenSpaceRun", "ThirdManRun", "BounceRun"}, SupportBehavior = "RunAfterPass"},
			{Phase = "OutOfPossession", Role = {"ST", "Winger", "CAM", "CM", "CDM", "Fullback", "CB"}, DefensiveDuty = "CompactFiveLaneBlock", AllowedFunctions = {"PressBall", "BlockForwardLane", "CoverBehindPresser", "CoverWing", "HoldLine"}},
		},
		PassRules = {
			{Phase = "InPossession", Trigger = "JustReceived", PassFamily = "Ground", Risk = -.2, MinimumLaneQuality = .62, RequiredPlanStep = "FirstTimeOption"},
			{Phase = "InPossession", PreferredReceiverFunction = "NearPassingTriangle", PassFamily = "Ground", Risk = -.24, MinimumLaneQuality = .58, RequiredPlanStep = "OneTouch"},
			{Phase = "InPossession", PreferredReceiverFunction = "ThirdManPosition", PassFamily = "Ground", Risk = -.12, MinimumLaneQuality = .6, RequiredPlanStep = "Bounce"},
			{Phase = "InPossession", PassFamily = "Safe Forward", Risk = -.1, MinimumLaneQuality = .64, RequiredPlanStep = "ForwardSpace"},
		},
		PositioningRules = {
			{Phase = "InPossession", TargetRegion = "BallSideTriangle", SupportDistance = -.36, Width = .04, Rotation = "PassAndMove"},
			{Phase = "InPossession", TargetRegion = "FiveLaneOccupation", Width = .14, Rotation = "MoveWithBallAfterPass"},
			{Phase = "InPossession", Function = "PostPassRun", Depth = .18, SupportDistance = -.1},
			{Phase = "OutOfPossession", Depth = .1, Width = -.04, RestDefense = 1, SupportDistance = -.1},
		},
		PressRules = {
			{Phase = "OutOfPossession", Trigger = "OpponentCarrier", PresserEligibility = {"NearestNonGoalkeeper"}, PressDirection = "CenterSideToWide", CoverResponsibility = "SecondNearestBlocksForwardPass", Pressers = 1, PressHeight = .08, AbortCondition = "PassThroughFirstPressure"},
			{Phase = "OutOfPossession", Trigger = "DirectPassLaunched", PresserEligibility = {"NearestBackLine"}, PressDirection = "AttackReceiver", CoverResponsibility = "OneDefenderBehindOneMidfielderSecondBall", Pressers = 1},
		},
		SequenceRules = {
			{Phase = "InPossession", NextStep = "first-time-pass", PreferredReceiver = "clean-short-option", RequiredOccupations = {"two-short-options", "third-man-option"}, FallbackStep = "trap-if-open-space"},
			{Phase = "InPossession", NextStep = "post-pass-run", PreferredReceiver = "previous-passer", RequiredOccupations = {"open-forward-space"}, FallbackStep = "return-to-shape"},
			{Phase = "InPossession", NextStep = "third-man-bounce", PreferredReceiver = "runner-after-pass", RequiredOccupations = {"two-short-options"}, FallbackStep = "one-or-two-pass-recycle"},
		},
		MetricsTargets = {Possession = 64, PassCompletion = 92, ShotQuality = 50, Compactness = 78, FirstTimePassChance = 88, QuickPassing = 1, TikiTaka = 1, MaxShortPassDistance = 25, TriangleNearbyTeammates = 3, RecycleLimit = 2, ShortOptions = 3, MaxRunsBehind = 2, LaneOccupation = 5, SlideTackleFrequency = 32, LongBalls = 6, SecondBalls = 36, CounterPress = 72, MaxPressers = 3},
		CreatedAt = 0,
		UpdatedAt = 0,
		PublishedAt = 0,
		AuthorUserId = 0,
		BuiltIn = true,
	}
end

local function tacticalPlaystyle(id: string, name: string, presetId: string, description: string, sliders: any, roleInstructions: any, passRules: any, positioningRules: any, pressRules: any, sequenceRules: any, metrics: any): any
	local preset = AITacticConfig.Get(presetId)
	local tactics = AITacticConfig.Normalize({PresetId = presetId, Sliders = sliders})
	return {
		SchemaVersion = Config.SchemaVersion,
		PlaystyleId = id,
		Version = 1,
		Status = "Published",
		Name = name,
		Description = description,
		BasePresetId = preset.Id,
		Tactics = tactics,
		RoleInstructions = roleInstructions,
		PassRules = passRules,
		PositioningRules = positioningRules,
		PressRules = pressRules,
		SequenceRules = sequenceRules,
		MetricsTargets = metrics,
		CreatedAt = 0,
		UpdatedAt = 0,
		PublishedAt = 0,
		AuthorUserId = 0,
		BuiltIn = true,
	}
end

local function verticalTikiTakaPlaystyle(): any
	return tacticalPlaystyle(VERTICAL_TIKI_TAKA_PLAYSTYLE_ID, "Vertical Tiki-Taka", "vertical_combination", "Possession waves that begin safely, then break lines as soon as a forward-facing defender or midfielder has time to play between the lines.", {
		BuildUpSpeed = 74, PassTempo = 88, PassingDirectness = 56, ForwardPassPriority = 82, BackPassSafety = 58, SwitchPlayFrequency = 46, ThroughBallFrequency = 82, LobPassBias = 28, FreeKickLongPass = 32, LongGKDistribution = 24, ShortGKDistribution = 80, OneTouchPassing = 86, FirstTouchDirectness = 84, ReceiverTrapAggression = 18, CounterAttackFrequency = 60, RiskLevel = 68, PassRisk = 66, PossessionPatience = 60, SupportDistance = 22, ImmediateSupportDistance = 20, RunsInBehind = 76, MaxMajorRuns = 64, OverlapFrequency = 48, UnderlapFrequency = 84, FullbackAttack = 62, AttackingWidth = 52, WidthDiscipline = 68, MidfieldRotation = 90, BoxRuns = 72, CutbackFrequency = 70, CrossingFrequency = 30, DefensiveDepth = 68, DefensiveWidth = 48, PressingIntensity = 72, PressTriggerDistance = 72, CounterPress = 78, BackLineCompactness = 76, LaneBlocking = 80, ZoneDiscipline = 70, DefensiveLineStepUp = 80, BoxProtection = 58, MarkingTightness = 70, InterceptionRisk = 68, RecoveryRuns = 80, TackleAggression = 58, StaminaPressLimit = 66, SprintConservation = 42, LongShotFrequency = 34, ShotPatience = 56, CreativeFreedom = 80, FinalThirdPatience = 56,
	}, {
		{Phase = "InPossession", Role = {"CM", "CAM", "CDM"}, AllowedFunctions = {"ProgressivePass", "ThirdManRun", "SupportTriangle", "LineBreak"}, RunTypes = {"PassAndMoveLane", "BehindBackRun"}},
		{Phase = "InPossession", Role = {"ST"}, AllowedFunctions = {"DropBetweenLines", "FirstTimeLayoff", "ThroughBall"}, SupportBehavior = "StrikerBounce"},
		{Phase = "InPossession", Role = {"Winger", "CAM"}, RunTypes = {"BeyondStrikerDrop", "AdvancedRunner"}, RiskPermissions = "PasserCanSeeLine"},
	}, {
		{Phase = "InPossession", PreferredReceiverFunction = "striker-or-attacking-midfielder", PassFamily = "Progressive Ground", Risk = -.06, MinimumLaneQuality = .6, RequiredPlanStep = "ForwardFirstLook"},
		{Phase = "InPossession", PreferredReceiverFunction = "third-man-runner", PassFamily = "OneTouchThrough", Risk = .08, MinimumLaneQuality = .64, RequiredPlanStep = "StrikerBounce"},
		{Phase = "InPossession", PassFamily = "Sideways Reposition", Risk = -.24, MinimumLaneQuality = .58, RequiredPlanStep = "LineBlocked"},
	}, {
		{Phase = "InPossession", TargetRegion = "BallTriangle", SupportDistance = -.42, Rotation = "ImmediateNewLane"},
		{Phase = "InPossession", TargetRegion = "BetweenLines", Depth = .18, Width = -.08},
		{Phase = "InPossession", Function = "RunnerBeyondDrop", Depth = .28, RestDefense = 2},
	}, {
		{Phase = "OutOfPossession", Trigger = "OpponentCarrier", PressDirection = "BlockCentralProgression", CoverResponsibility = "MidfieldScreen", Pressers = 1},
	}, {
		{Phase = "InPossession", NextStep = "vertical-first-look", PreferredReceiver = "striker-cam-runner", RequiredOccupations = {"triangle", "between-lines"}, FallbackStep = "sideways-reposition"},
		{Phase = "InPossession", NextStep = "striker-bounce", PreferredReceiver = "runner-beyond", RequiredOccupations = {"striker-drop", "runner-onside"}, FallbackStep = "midfield-reset"},
	}, {FirstTimePassChance = 84, QuickPassing = 1, VerticalTikiTaka = 1, ForwardFacingTrigger = 1, RecycleLimit = 1, ShortOptions = 3, MaxRunsBehind = 3, LaneOccupation = 5, SlideTackleFrequency = 44, LongBalls = 18, SecondBalls = 48, CounterPress = 78, MaxPressers = 3})
end

local function wingPlayPlaystyle(): any
	return tacticalPlaystyle(WING_PLAY_PLAYSTYLE_ID, "Wing Play", "wing_overload", "Circulate normally until midfield is established in the opponent half, then release touchline wingers with lobbed passes, long through balls, overlaps, crosses, and resets through fullbacks.", {
		BuildUpSpeed = 60, PassTempo = 68, PassingDirectness = 50, ForwardPassPriority = 62, BackPassSafety = 70, SwitchPlayFrequency = 94, ThroughBallFrequency = 54, LobPassBias = 60, FreeKickLongPass = 78, LongGKDistribution = 54, ShortGKDistribution = 58, OneTouchPassing = 50, FirstTouchDirectness = 54, ReceiverTrapAggression = 48, CounterAttackFrequency = 50, RiskLevel = 54, PassRisk = 48, PossessionPatience = 66, SupportDistance = 50, ImmediateSupportDistance = 32, RunsInBehind = 64, MaxMajorRuns = 62, OverlapFrequency = 94, UnderlapFrequency = 40, FullbackAttack = 80, AttackingWidth = 96, WidthDiscipline = 94, MidfieldRotation = 44, BoxRuns = 82, CutbackFrequency = 80, CrossingFrequency = 92, DefensiveDepth = 56, DefensiveWidth = 78, PressingIntensity = 56, PressTriggerDistance = 54, CounterPress = 48, BackLineCompactness = 62, LaneBlocking = 70, ZoneDiscipline = 80, DefensiveLineStepUp = 62, BoxProtection = 68, MarkingTightness = 62, InterceptionRisk = 54, RecoveryRuns = 72, TackleAggression = 54, StaminaPressLimit = 72, SprintConservation = 58, LongShotFrequency = 40, ShotPatience = 58, CreativeFreedom = 66, FinalThirdPatience = 62,
	}, {
		{Phase = "InPossession", Role = {"Winger", "LM", "RM"}, AllowedFunctions = {"StayWide", "TouchlineRelease", "DriveToEndline", "SideRetreatPass", "FullbackReset"}, RunTypes = {"WideReceive", "TouchlineSprint", "EndlineRun"}},
		{Phase = "InPossession", Role = {"Fullback"}, AllowedFunctions = {"Overlap", "Underlap", "WideSupport"}, RunTypes = {"OutsideOverlapWhenWingerInside", "UnderlapWhenWingerWide"}},
		{Phase = "InPossession", Role = {"ST"}, AllowedFunctions = {"AttackBoxCenter", "NearPostRun"}, SupportBehavior = "BoxTarget"},
	}, {
		{Phase = "InPossession", PreferredReceiverFunction = "touchline-winger-after-midfield-advance", PassFamily = "Wide Release", Risk = -.08, MinimumLaneQuality = .58, Zone = "Wide"},
		{Phase = "InPossession", PreferredReceiverFunction = "far-side-wide", PassFamily = "Switch", Risk = -.04, MinimumLaneQuality = .62, RequiredPlanStep = "WingCrowded"},
		{Phase = "FinalThird", PassFamily = "Low Cross Cutback", Risk = -.02, MinimumLaneQuality = .56, Zone = "Byline"},
	}, {
		{Phase = "InPossession", TargetRegion = "WideLanes", Width = .38, Depth = .12},
		{Phase = "FinalThird", TargetRegion = "BoxAndCutback", Width = .2, Depth = .24, RestDefense = 2},
	}, {
		{Phase = "OutOfPossession", Trigger = "OpponentWideReceive", PressDirection = "FullbackPressPathToGoal", CoverResponsibility = "WingerTracksFullback", Pressers = 1},
	}, {
		{Phase = "InPossession", NextStep = "wide-progression", PreferredReceiver = "winger-fullback", RequiredOccupations = {"both-wide-lanes"}, FallbackStep = "recycle-switch"},
		{Phase = "FinalThird", NextStep = "cross-cutback", PreferredReceiver = "striker-or-late-midfielder", RequiredOccupations = {"central-box", "back-post", "edge-cutback"}, FallbackStep = "switch-side"},
	}, {FirstTimePassChance = 48, QuickPassing = 0, SidePressureEscape = 1, WingReleaseAfterMidfieldAdvance = 1, WingSidelineOffset = 10, WingEndlineTargetOffset = 10, ShortOptions = 2, MaxRunsBehind = 3, LaneOccupation = 5, SlideTackleFrequency = 40, LongBalls = 48, SecondBalls = 68, CounterPress = 48, MaxPressers = 2})
end

local function routeOnePlaystyle(): any
	return tacticalPlaystyle(ROUTE_ONE_PLAYSTYLE_ID, "Route One", "counter_attack", "Direct football from defenders and goalkeeper into striker, wide targets, channels, flick-ons, and second balls.", {
		BuildUpSpeed = 90, PassTempo = 74, PassingDirectness = 96, ForwardPassPriority = 96, BackPassSafety = 28, SwitchPlayFrequency = 34, ThroughBallFrequency = 72, LobPassBias = 98, FreeKickLongPass = 98, LongGKDistribution = 100, ShortGKDistribution = 8, OneTouchPassing = 38, FirstTouchDirectness = 82, ReceiverTrapAggression = 68, CounterAttackFrequency = 68, RiskLevel = 80, PassRisk = 74, PossessionPatience = 18, SupportDistance = 66, ImmediateSupportDistance = 40, RunsInBehind = 82, MaxMajorRuns = 80, OverlapFrequency = 36, UnderlapFrequency = 18, FullbackAttack = 34, AttackingWidth = 76, WidthDiscipline = 70, MidfieldRotation = 22, BoxRuns = 86, CutbackFrequency = 24, CrossingFrequency = 82, DefensiveDepth = 46, DefensiveWidth = 58, PressingIntensity = 44, PressTriggerDistance = 40, CounterPress = 40, BackLineCompactness = 72, LaneBlocking = 62, ZoneDiscipline = 74, DefensiveLineStepUp = 50, BoxProtection = 74, MarkingTightness = 70, InterceptionRisk = 56, RecoveryRuns = 78, TackleAggression = 66, StaminaPressLimit = 82, SprintConservation = 68, LongShotFrequency = 68, ShotPatience = 24, CreativeFreedom = 44, FinalThirdPatience = 20,
	}, {
		{Phase = "InPossession", Role = {"GK", "CB", "Fullback"}, AllowedFunctions = {"LongPass", "ChannelBall", "ClearToStriker"}, RiskPermissions = "AvoidRiskyShortPassUnderPress"},
		{Phase = "InPossession", Role = {"ST"}, AllowedFunctions = {"TargetReceive", "HoldUp", "FlickOn"}, SupportBehavior = "MainLongBallTarget"},
		{Phase = "InPossession", Role = {"Winger", "CAM", "CM"}, RunTypes = {"SecondBallRun", "FlickOnSupport", "ChannelSprint"}},
	}, {
		{Phase = "InPossession", PreferredReceiverFunction = "target-striker", PassFamily = "Long Direct", Risk = .06, MinimumLaneQuality = .46, RequiredPlanStep = "FirstOption"},
		{Phase = "InPossession", PreferredReceiverFunction = "wide-channel", PassFamily = "Long Diagonal", Risk = .08, MinimumLaneQuality = .5, RequiredPlanStep = "PressedBackline"},
		{Phase = "FinalThird", PassFamily = "Early Shot Cross Through", Risk = .1, MinimumLaneQuality = .48},
	}, {
		{Phase = "InPossession", TargetRegion = "SecondBallUnderStriker", SupportDistance = .18, Depth = .18},
		{Phase = "InPossession", Function = "StrikerTarget", Depth = .32, Width = -.08},
		{Phase = "OutOfPossession", RestDefense = 3, Depth = -.08},
	}, {
		{Phase = "OutOfPossession", Trigger = "LooseSecondBall", PressDirection = "AttackDropZone", CoverResponsibility = "DeepMidfielderRestDefense", Pressers = 2},
	}, {
		{Phase = "InPossession", NextStep = "direct-target", PreferredReceiver = "striker-or-wide-channel", RequiredOccupations = {"second-ball-midfielder", "runner-around-striker"}, FallbackStep = "clear-safe"},
	}, {FirstTimePassChance = 36, QuickPassing = 0, RouteOne = 1, DirectActionsToBox = 4, StrikerContestFirst = 1, ShortOptions = 1, MaxRunsBehind = 4, LaneOccupation = 4, SlideTackleFrequency = 58, LongBalls = 98, SecondBalls = 100, CounterPress = 40, MaxPressers = 2})
end

local function parkTheBusPlaystyle(): any
	return tacticalPlaystyle(PARK_THE_BUS_PLAYSTYLE_ID, "Park the Bus", "low_block_counter", "Extreme compact defensive safety: protect central zones, slow the match, clear danger, and counter only through safe outlets.", {
		BuildUpSpeed = 24, PassTempo = 36, PassingDirectness = 60, ForwardPassPriority = 38, BackPassSafety = 94, SwitchPlayFrequency = 48, ThroughBallFrequency = 28, LobPassBias = 82, FreeKickLongPass = 72, LongGKDistribution = 82, ShortGKDistribution = 22, OneTouchPassing = 24, FirstTouchDirectness = 32, ReceiverTrapAggression = 78, CounterAttackFrequency = 38, RiskLevel = 12, PassRisk = 8, PossessionPatience = 92, SupportDistance = 22, ImmediateSupportDistance = 18, RunsInBehind = 16, MaxMajorRuns = 12, OverlapFrequency = 4, UnderlapFrequency = 4, FullbackAttack = 2, AttackingWidth = 40, WidthDiscipline = 98, MidfieldRotation = 6, BoxRuns = 14, CutbackFrequency = 16, CrossingFrequency = 42, DefensiveDepth = 8, DefensiveWidth = 34, PressingIntensity = 16, PressTriggerDistance = 12, CounterPress = 6, BackLineCompactness = 100, LaneBlocking = 98, ZoneDiscipline = 100, DefensiveLineStepUp = 6, BoxProtection = 100, MarkingTightness = 80, InterceptionRisk = 24, RecoveryRuns = 100, TackleAggression = 46, StaminaPressLimit = 96, SprintConservation = 94, LongShotFrequency = 52, ShotPatience = 24, CreativeFreedom = 18, FinalThirdPatience = 24,
	}, {
		{Phase = "OutOfPossession", Role = {"CB", "Fullback", "CDM", "CM", "Winger"}, DefensiveDuty = "DeepCompactBlock", AllowedFunctions = {"HoldLine", "ProtectCenter", "CoverWideLow", "ClearDanger"}},
		{Phase = "InPossession", Role = {"CB", "Fullback", "CDM"}, AllowedFunctions = {"ClearDanger", "SimpleNearbyPass", "RecycleBack"}, RiskPermissions = "SafetyFirst"},
		{Phase = "InPossession", Role = {"ST"}, AllowedFunctions = {"OutletHoldUp", "WinFoul", "CarryWide"}},
	}, {
		{Phase = "InPossession", PassFamily = "Safe Reset", Risk = -.52, MinimumLaneQuality = .54, Zone = "OwnThird"},
		{Phase = "OutOfPossession", PassFamily = "ClearanceToOutlet", Risk = -.18, MinimumLaneQuality = .34, RequiredPlanStep = "Danger"},
	}, {
		{Phase = "OutOfPossession", TargetRegion = "LowCentralBlock", Width = -.28, Depth = -.46, RestDefense = 8},
		{Phase = "InPossession", TargetRegion = "OutletOnly", Depth = -.16, Width = -.12},
	}, {
		{Phase = "OutOfPossession", Trigger = "OpponentCarrier", PressDirection = "DelayAndProtectBox", CoverResponsibility = "TwoLinesCentral", Pressers = 1, PressHeight = -.45, AbortCondition = "NoClearWin"},
	}, {
		{Phase = "OutOfPossession", NextStep = "hold-low-block", PreferredReceiver = "none", RequiredOccupations = {"box-protection", "wide-low-cover", "striker-outlet"}, FallbackStep = "clear-danger"},
	}, {FirstTimePassChance = 14, QuickPassing = 0, ParkTheBus = 1, BoxEdgeRetreatLimit = 8, CompactLineGap = 4, AttackCommitmentLimit = 4, StrikerOutletHigh = 1, ShortOptions = 2, MaxRunsBehind = 1, LaneOccupation = 3, SlideTackleFrequency = 48, LongBalls = 80, SecondBalls = 72, CounterPress = 6, MaxPressers = 1})
end

local function counterAttackPlaystyle(): any
	return tacticalPlaystyle(COUNTER_ATTACK_PLAYSTYLE_ID, "Counter-Attack", "counter_attack", "Compact defending followed by immediate forward passes into open space, fast wingers, striker runs, and staggered midfield cover.", {
		BuildUpSpeed = 72, PassTempo = 78, PassingDirectness = 74, ForwardPassPriority = 88, BackPassSafety = 54, SwitchPlayFrequency = 54, ThroughBallFrequency = 94, LobPassBias = 62, FreeKickLongPass = 68, LongGKDistribution = 76, ShortGKDistribution = 38, OneTouchPassing = 66, FirstTouchDirectness = 82, ReceiverTrapAggression = 20, CounterAttackFrequency = 100, RiskLevel = 74, PassRisk = 70, PossessionPatience = 34, SupportDistance = 62, ImmediateSupportDistance = 32, RunsInBehind = 98, MaxMajorRuns = 88, OverlapFrequency = 52, UnderlapFrequency = 60, FullbackAttack = 42, AttackingWidth = 80, WidthDiscipline = 74, MidfieldRotation = 40, BoxRuns = 78, CutbackFrequency = 66, CrossingFrequency = 54, DefensiveDepth = 36, DefensiveWidth = 46, PressingIntensity = 38, PressTriggerDistance = 34, CounterPress = 20, BackLineCompactness = 88, LaneBlocking = 90, ZoneDiscipline = 92, DefensiveLineStepUp = 38, BoxProtection = 84, MarkingTightness = 66, InterceptionRisk = 72, RecoveryRuns = 98, TackleAggression = 50, StaminaPressLimit = 84, SprintConservation = 70, LongShotFrequency = 48, ShotPatience = 32, CreativeFreedom = 72, FinalThirdPatience = 26,
	}, {
		{Phase = "TransitionAttack", Role = {"Winger", "LM", "RM"}, RunTypes = {"DeepStartSprintBehindFullback", "OpenChannelRun"}, SupportBehavior = "SprintOnRecovery"},
		{Phase = "TransitionAttack", Role = {"ST"}, RunTypes = {"DirectRunBehind", "ShowToCreateWingerSpace"}},
		{Phase = "TransitionAttack", Role = {"CM", "CDM"}, AllowedFunctions = {"ForwardSupport", "CounterRestDefense"}, DefensiveDuty = "OneGoesOneStays"},
	}, {
		{Phase = "TransitionAttack", PreferredReceiverFunction = "fast-winger-or-striker-space", PassFamily = "Through Ball", Risk = .08, MinimumLaneQuality = .48, RequiredPlanStep = "ImmediateRecovery"},
		{Phase = "TransitionAttack", PreferredReceiverFunction = "open-channel", PassFamily = "Early Long Pass", Risk = .04, MinimumLaneQuality = .46},
	}, {
		{Phase = "OutOfPossession", TargetRegion = "CompactMidBlock", Depth = -.22, Width = -.12, RestDefense = 4},
		{Phase = "TransitionAttack", TargetRegion = "ThreeRunnerCounter", Depth = .36, Width = .22},
	}, {
		{Phase = "OutOfPossession", Trigger = "AllowAdvanceThenWin", PressDirection = "ProtectCentralLane", CoverResponsibility = "CompactMidfield", Pressers = 1},
	}, {
		{Phase = "TransitionAttack", NextStep = "first-forward-pass", PreferredReceiver = "space-runner", RequiredOccupations = {"fast-winger", "striker", "one-deep-midfielder"}, FallbackStep = "settle-possession"},
	}, {FirstTimePassChance = 64, QuickPassing = 1, CounterAttack = 1, CounterPassLimit = 5, SafePossessionFallback = 1, RestMidfielder = 1, ShortOptions = 2, MaxRunsBehind = 4, LaneOccupation = 4, SlideTackleFrequency = 44, LongBalls = 72, SecondBalls = 72, CounterPress = 20, MaxPressers = 2})
end

local function gegenpressPlaystyle(): any
	return tacticalPlaystyle(GEGENPRESS_PLAYSTYLE_ID, "Gegenpress", "high_press", "Coordinated counter-press after losing possession: first presser delays, second blocks escape, third covers behind, team compresses pitch.", {
		BuildUpSpeed = 80, PassTempo = 90, PassingDirectness = 68, ForwardPassPriority = 90, BackPassSafety = 44, SwitchPlayFrequency = 38, ThroughBallFrequency = 84, LobPassBias = 40, FreeKickLongPass = 42, LongGKDistribution = 34, ShortGKDistribution = 78, OneTouchPassing = 82, FirstTouchDirectness = 86, ReceiverTrapAggression = 16, CounterAttackFrequency = 94, RiskLevel = 80, PassRisk = 74, PossessionPatience = 28, SupportDistance = 22, ImmediateSupportDistance = 18, RunsInBehind = 82, MaxMajorRuns = 76, OverlapFrequency = 68, UnderlapFrequency = 74, FullbackAttack = 74, AttackingWidth = 62, WidthDiscipline = 56, MidfieldRotation = 82, BoxRuns = 84, CutbackFrequency = 64, CrossingFrequency = 44, DefensiveDepth = 90, DefensiveWidth = 56, PressingIntensity = 100, PressTriggerDistance = 94, CounterPress = 100, BackLineCompactness = 94, LaneBlocking = 96, ZoneDiscipline = 66, DefensiveLineStepUp = 96, BoxProtection = 68, MarkingTightness = 86, InterceptionRisk = 90, RecoveryRuns = 100, TackleAggression = 78, StaminaPressLimit = 58, SprintConservation = 12, LongShotFrequency = 42, ShotPatience = 28, CreativeFreedom = 74, FinalThirdPatience = 30,
	}, {
		{Phase = "AfterPossessionLoss", Role = {"ST", "Winger", "CAM", "CM"}, AllowedFunctions = {"FirstPresser", "SecondPresser", "ThirdCover", "LaneScreen"}, DefensiveDuty = "CounterPressWindow"},
		{Phase = "OutOfPossession", Role = {"Fullback"}, DefensiveDuty = "CompressWidthAndCoverBehindWinger", AllowedFunctions = {"PressReceiver", "CoverSpaceBehind"}},
		{Phase = "OutOfPossession", Role = {"CB", "CDM"}, DefensiveDuty = "HighCoverBehindPress", AllowedFunctions = {"InterceptDirectPass", "DelayIfPressBeaten"}},
	}, {
		{Phase = "AfterRecovery", PreferredReceiverFunction = "direct-shot-forward-runner", PassFamily = "Immediate Attack", Risk = .06, MinimumLaneQuality = .48, RequiredPlanStep = "RecoveredHigh"},
		{Phase = "AfterRecovery", PreferredReceiverFunction = "unmarked-attacker", PassFamily = "FirstTimePass", Risk = -.02, MinimumLaneQuality = .54},
	}, {
		{Phase = "AfterPossessionLoss", TargetRegion = "CompressAroundBall", SupportDistance = -.34, Depth = .28, Width = -.18, RestDefense = 2},
		{Phase = "OutOfPossession", TargetRegion = "HighCompactBlock", Depth = .32, Width = -.1},
	}, {
		{Phase = "AfterPossessionLoss", Trigger = "PossessionLost", PresserEligibility = {"LoserOrClosest"}, PressDirection = "ForceWideOrBack", CoverResponsibility = "SecondBlocksEscapeThirdCovers", Pressers = 3, PressHeight = .38, AbortCondition = "PressBeatenOrWindowExpired"},
		{Phase = "OutOfPossession", Trigger = "BackPassTouchlineHeavyTouchLooseBall", PresserEligibility = {"NearestThreeWithSupport"}, PressDirection = "Trap", CoverResponsibility = "RemainingPlayersLaneScreen", Pressers = 3},
		{Phase = "DefensiveThird", Trigger = "PossessionLost", PressDirection = "DelayProtectBox", CoverResponsibility = "RecoverCompact", Pressers = 1, AbortCondition = "ShotThreat"},
	}, {
		{Phase = "AfterPossessionLoss", NextStep = "counterpress-window", PreferredReceiver = "none", RequiredOccupations = {"first-presser", "escape-blocker", "cover-player"}, FallbackStep = "recover-mid-block"},
		{Phase = "AfterRecovery", NextStep = "attack-disorganized-opponent", PreferredReceiver = "runner-or-shot", RequiredOccupations = {"nearby-attackers-forward"}, FallbackStep = "normal-possession"},
	}, {FirstTimePassChance = 84, QuickPassing = 1, Gegenpress = 1, CounterPressWindowSeconds = 4, PressEscapeAbort = 1, TouchlineTrap = 1, BoxEdgeRetreatLimit = 18, ShortOptions = 3, MaxRunsBehind = 3, LaneOccupation = 5, SlideTackleFrequency = 72, LongBalls = 34, SecondBalls = 94, CounterPress = 100, MaxPressers = 3})
end

local builtIns = {
	[BASIC_PLAYSTYLE_ID] = table.freeze(basicPossessionPlaystyle()),
	[QUICK_PASSING_PLAYSTYLE_ID] = table.freeze(quickPassingPlaystyle()),
	[VERTICAL_TIKI_TAKA_PLAYSTYLE_ID] = table.freeze(verticalTikiTakaPlaystyle()),
	[WING_PLAY_PLAYSTYLE_ID] = table.freeze(wingPlayPlaystyle()),
	[ROUTE_ONE_PLAYSTYLE_ID] = table.freeze(routeOnePlaystyle()),
	[PARK_THE_BUS_PLAYSTYLE_ID] = table.freeze(parkTheBusPlaystyle()),
	[COUNTER_ATTACK_PLAYSTYLE_ID] = table.freeze(counterAttackPlaystyle()),
	[GEGENPRESS_PLAYSTYLE_ID] = table.freeze(gegenpressPlaystyle()),
}
local builtInOrder = {BASIC_PLAYSTYLE_ID, QUICK_PASSING_PLAYSTYLE_ID, VERTICAL_TIKI_TAKA_PLAYSTYLE_ID, WING_PLAY_PLAYSTYLE_ID, ROUTE_ONE_PLAYSTYLE_ID, PARK_THE_BUS_PLAYSTYLE_ID, COUNTER_ATTACK_PLAYSTYLE_ID, GEGENPRESS_PLAYSTYLE_ID}

function Config.SafeId(value: any, fallback: string?): string
	return slug(value, fallback or ("playstyle_" .. HttpService:GenerateGUID(false):gsub("%-", ""):sub(1, 10)))
end

function Config.DraftId(): string
	return "draft_" .. HttpService:GenerateGUID(false):gsub("%-", ""):sub(1, 18)
end

function Config.Count(map: any): number
	return countMap(map)
end

function Config.Normalize(playstyle: any, authorUserId: number?, base: any?): any
	local source = type(playstyle) == "table" and playstyle or {}
	local seed = type(base) == "table" and base or nil
	local name = safeText(source.Name or (seed and seed.Name), "New Playstyle", 40)
	local id = Config.SafeId(source.PlaystyleId or source.Id or name, "playstyle")
	local status = tostring(source.Status or (seed and seed.Status) or "Draft")
	if status ~= "Published" and status ~= "Archived" then status = "Draft" end
	local version = math.max(1, math.floor(tonumber(source.Version or (seed and seed.Version) or 1) or 1))
	local tacticSource = source.Tactics or source.RuntimeTactics or source
	if seed and source.Tactics == nil and source.Sliders == nil and source.GlobalOverrides == nil then tacticSource = seed.Tactics end
	local tactics = AITacticConfig.Normalize(tacticSource)
	local behavior = AIBehaviorTuningConfig.NormalizeProfile(tactics, AITacticConfig.Get(tactics.PresetId).Sliders)
	tactics.GlobalOverrides = behavior.GlobalOverrides
	tactics.PhaseOverrides = behavior.PhaseOverrides
	tactics.RoleOverrides = behavior.RoleOverrides
	tactics.MatchStateOverrides = behavior.MatchStateOverrides
	tactics.ExecutionOverrides = behavior.ExecutionOverrides
	tactics.Custom = true
	return {
		SchemaVersion = Config.SchemaVersion,
		PlaystyleId = id,
		Version = version,
		Status = status,
		Name = name,
		Description = safeText(source.Description or (seed and seed.Description), "", 160),
		BasePresetId = AITacticConfig.ResolveId(source.BasePresetId or tactics.BasePresetId or tactics.PresetId),
		Tactics = tactics,
		RoleInstructions = type(source.RoleInstructions) == "table" and clone(source.RoleInstructions) or (seed and clone(seed.RoleInstructions) or {}),
		PassRules = cleanRules(source.PassRules or (seed and seed.PassRules), 40),
		PositioningRules = cleanRules(source.PositioningRules or (seed and seed.PositioningRules), 40),
		PressRules = cleanRules(source.PressRules or (seed and seed.PressRules), 30),
		SequenceRules = cleanRules(source.SequenceRules or (seed and seed.SequenceRules), 30),
		MetricsTargets = type(source.MetricsTargets) == "table" and clone(source.MetricsTargets) or (seed and clone(seed.MetricsTargets) or {}),
		CreatedAt = tonumber(source.CreatedAt) or (seed and tonumber(seed.CreatedAt)) or now(),
		UpdatedAt = now(),
		PublishedAt = tonumber(source.PublishedAt) or (status == "Published" and now() or 0),
		AuthorUserId = math.floor(tonumber(source.AuthorUserId or authorUserId) or 0),
		BuiltIn = source.BuiltIn == true,
	}
end

function Config.DraftFromTactics(name: string, tactics: any, authorUserId: number?): any
	return Config.Normalize({PlaystyleId = Config.DraftId(), Name = name, Status = "Draft", Tactics = tactics}, authorUserId)
end

function Config.ResolveBuiltIn(id: any): any?
	local key = tostring(id or "")
	if builtIns[key] then return builtIns[key] end
	if key == "" or key == "balanced_control" or key == "short_possession" or key == "Possession" or key == "Basic Possession" or key == "SAFE Possession" or key == "Safe Possession" then
		return builtIns[BASIC_PLAYSTYLE_ID]
	end
	if key == "Quick Passing" or key == "Tiki-Taka" or key == "Tiki Taka" then return builtIns[QUICK_PASSING_PLAYSTYLE_ID] end
	if key == "vertical_combination" or key == "Vertical Tiki-Taka" or key == "Vertical Tiki Taka" then return builtIns[VERTICAL_TIKI_TAKA_PLAYSTYLE_ID] end
	if key == "wing_overload" or key == "Wing Play" then return builtIns[WING_PLAY_PLAYSTYLE_ID] end
	if key == "Route One" or key == "route_one" or key == "Direct Long Ball" then return builtIns[ROUTE_ONE_PLAYSTYLE_ID] end
	if key == "low_block_counter" or key == "Park the Bus" or key == "Park The Bus" then return builtIns[PARK_THE_BUS_PLAYSTYLE_ID] end
	if key == "counter_attack" or key == "Counter-Attack" or key == "Counter Attack" then return builtIns[COUNTER_ATTACK_PLAYSTYLE_ID] end
	if key == "high_press" or key == "Gegenpress" then return builtIns[GEGENPRESS_PLAYSTYLE_ID] end
	return nil
end

function Config.NextVersion(publishedByVersion: any): number
	local highest = 0
	for version in pairs(type(publishedByVersion) == "table" and publishedByVersion or {}) do
		highest = math.max(highest, tonumber(version) or 0)
	end
	return highest + 1
end

function Config.Validate(playstyle: any): (boolean, any)
	local normalized = Config.Normalize(playstyle)
	if normalized.Name == "" then return false, "Playstyle name is required." end
	if #normalized.PlaystyleId < 2 then return false, "Playstyle id is invalid." end
	return true, normalized
end

function Config.Encode(playstyle: any): string
	return HttpService:JSONEncode(Config.Normalize(playstyle))
end

function Config.Decode(text: any): (boolean, any)
	local json = tostring(text or "")
	if #json < 2 or #json > Config.MaxImportBytes then return false, "Import size is invalid." end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok or type(decoded) ~= "table" then return false, "Invalid playstyle JSON." end
	return Config.Validate(decoded)
end

function Config.ClientMetadata(): any
	local behavior = AIBehaviorTuningConfig.ClientMetadata(true)
	local settings = {}
	local byId = {}
	for _, item in ipairs(behavior.Settings or {}) do byId[item.Id] = item end
	for _, id in ipairs(HIGH_IMPACT) do
		if byId[id] then table.insert(settings, byId[id]) end
	end
	return {
		SchemaVersion = Config.SchemaVersion,
		HighImpactSettings = settings,
		AllSettings = behavior.Settings,
		Phases = behavior.Phases,
		Roles = behavior.Roles,
		MatchStates = behavior.MatchStates,
		Scopes = behavior.Scopes,
		Scenarios = {"Build Out", "Midfield Progression", "Final Third", "Counter Press", "Low Block", "Protect Lead"},
		Zones = {"Own Box", "Backline", "Half Space", "Wide Lane", "Between Lines", "Box Edge", "Penalty Area"},
		PassFamilies = {"CB Switch", "Fullback Progression", "Midfield Bounce", "Third Man", "Through Ball", "Cutback", "Safe Reset"},
		PositionFamilies = {"Rest Defense", "Wide Overload", "Central Overload", "Run In Behind", "Support Triangle", "Counter Shape"},
		SequenceFamilies = {"Stage 1 Backline", "Stage 2 Midfield", "Striker Bounce", "Wing Overload", "Late Protection"},
		MaxDrafts = Config.MaxDrafts,
		MaxPublishedFamilies = Config.MaxPublishedFamilies,
	}
end

Config.BuiltIns = table.freeze(builtIns)
Config.BuiltInOrder = table.freeze(builtInOrder)
Config.HighImpactSettingIds = table.freeze(HIGH_IMPACT)
Config.BasicPlaystyleId = BASIC_PLAYSTYLE_ID
Config.QuickPassingPlaystyleId = QUICK_PASSING_PLAYSTYLE_ID
Config.VerticalTikiTakaPlaystyleId = VERTICAL_TIKI_TAKA_PLAYSTYLE_ID
Config.WingPlayPlaystyleId = WING_PLAY_PLAYSTYLE_ID
Config.RouteOnePlaystyleId = ROUTE_ONE_PLAYSTYLE_ID
Config.ParkTheBusPlaystyleId = PARK_THE_BUS_PLAYSTYLE_ID
Config.CounterAttackPlaystyleId = COUNTER_ATTACK_PLAYSTYLE_ID
Config.GegenpressPlaystyleId = GEGENPRESS_PLAYSTYLE_ID

return table.freeze(Config)
