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
			BuildUpSpeed = 72,
			PassTempo = 92,
			PassingDirectness = 44,
			ForwardPassPriority = 62,
			BackPassSafety = 58,
			SwitchPlayFrequency = 62,
			SupportDistance = 28,
			FirstTouchDirectness = 92,
			OneTouchPassing = 94,
			ReceiverTrapAggression = 18,
			RunsInBehind = 66,
			MidfieldRotation = 82,
			CreativeFreedom = 58,
			PressingIntensity = 58,
			DefensiveDepth = 58,
			BackLineCompactness = 64,
			LaneBlocking = 70,
			ZoneDiscipline = 72,
			DefensiveLineStepUp = 68,
			WidthDiscipline = 70,
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
		Name = "Quick Passing",
		Description = "One-touch pass-and-move football: receivers play first time when a clean option exists, then sprint into forward or open space to create the next passing lane.",
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
			{Phase = "InPossession", NextStep = "first-time-pass", PreferredReceiver = "clean-short-option", RequiredOccupations = {"short-option", "third-man-option"}, FallbackStep = "trap-if-open-space"},
			{Phase = "InPossession", NextStep = "post-pass-run", PreferredReceiver = "previous-passer", RequiredOccupations = {"open-forward-space"}, FallbackStep = "return-to-shape"},
			{Phase = "InPossession", NextStep = "third-man-bounce", PreferredReceiver = "runner-after-pass", RequiredOccupations = {"two-short-options"}, FallbackStep = "safe-reset"},
		},
		MetricsTargets = {Possession = 54, PassCompletion = 86, ShotQuality = 50, Compactness = 76, OneTouchPasses = 100, FirstTimePassChance = 100, PostPassRuns = 28, ShortOptions = 2, LaneOccupation = 5, MaxRunsBehind = 3, QuickPassing = 1},
		CreatedAt = 0,
		UpdatedAt = 0,
		PublishedAt = 0,
		AuthorUserId = 0,
		BuiltIn = true,
	}
end

local builtIns = {
	[BASIC_PLAYSTYLE_ID] = table.freeze(basicPossessionPlaystyle()),
	[QUICK_PASSING_PLAYSTYLE_ID] = table.freeze(quickPassingPlaystyle()),
}
local builtInOrder = {BASIC_PLAYSTYLE_ID, QUICK_PASSING_PLAYSTYLE_ID}

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
	if key == "Quick Passing" then return builtIns[QUICK_PASSING_PLAYSTYLE_ID] end
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

return table.freeze(Config)
