--!strict

local Config = {}
local AIBehaviorTuningConfig = require(script.Parent.AIBehaviorTuningConfig)

Config.Version = 3
Config.SliderNames = {
	"BuildUpSpeed", "PassingDirectness", "AttackingWidth", "DefensiveWidth", "DefensiveDepth", "PressingIntensity", "CounterAttackFrequency", "OverlapFrequency", "CrossingFrequency", "LongShotFrequency", "DribblingFreedom", "RiskLevel", "SupportDistance", "PassTempo", "ForwardPassPriority", "BackPassSafety", "SwitchPlayFrequency", "ThroughBallFrequency", "PassRisk", "FirstTouchDirectness", "ReceiverTrapAggression", "RunsInBehind", "UnderlapFrequency", "BoxRuns", "CutbackFrequency", "FinalThirdPatience", "ShotPatience", "OneTouchPassing", "WidthDiscipline", "FullbackAttack", "MidfieldRotation", "CreativeFreedom", "PressTriggerDistance", "CounterPress", "TackleAggression", "InterceptionRisk", "MarkingTightness", "LaneBlocking", "BackLineCompactness", "BoxProtection", "ZoneDiscipline", "LooseBallAggression", "RecoveryRuns", "SprintConservation", "KeeperAggression", "KeeperDistributionRisk", "ShortGKDistribution", "LongGKDistribution", "FreeKickShortPass", "FreeKickLongPass", "CornerNearPost", "CornerFarPost", "SetPiecePatience", "ClearanceHeight", "StaminaPressLimit", "DefensiveLineStepUp",
}

local definitions = {
	balanced_control = {"Balanced Control", "A stable two-way structure with protected midfield support.", 2, 2, "MEDIUM", "MEDIUM", {50,50,52,50,50,48,45,45,45,35,45,45,50,50,52,52,50,48,45,50,52,50,40,50,48,52,50,48,58,48,48,50,50,48,48,50,55,55,58,58,58,52,62,60,50,45,55,45,50,50,50,50,50,55,55,50}},
	short_possession = {"Short Possession", "Patient triangles, close support, and frequent third-player combinations.", 2, 3, "LOW", "MEDIUM", {30,20,58,48,58,55,18,38,25,20,48,32,28,72,48,82,66,24,28,32,72,25,62,40,72,86,78,82,78,48,82,64,48,72,42,58,58,70,68,60,78,58,72,84,48,28,90,18,78,25,48,45,82,40,68,62}},
	vertical_combination = {"Vertical Combination", "Fast line-breaking combinations and aggressive third-player movement.", 3, 2, "HIGH", "MEDIUM-HIGH", {68,78,54,48,58,56,68,52,45,42,55,68,48,68,84,32,45,82,72,78,58,84,58,68,58,38,36,62,55,52,72,68,55,58,52,58,55,52,58,55,52,62,68,48,55,62,40,70,40,68,58,55,42,62,48,58}},
	wing_overload = {"Wing Overload", "A winger, overlapping fullback, and underlapping midfielder overload the ball side.", 3, 2, "MEDIUM-HIGH", "HIGH", {56,48,88,58,52,48,45,90,88,25,55,55,42,55,58,55,70,55,52,55,62,58,78,76,84,55,52,58,88,88,68,62,50,45,48,52,54,54,55,60,60,55,72,58,50,48,55,45,52,48,72,78,60,55,55,52}},
	central_overload = {"Central Overload", "Midfielders, an inverted fullback, and a roaming creator overload central zones.", 2, 3, "MEDIUM", "MEDIUM", {42,34,38,44,58,56,30,28,18,38,60,52,34,64,62,70,35,58,48,42,70,45,82,70,78,78,68,74,42,55,92,82,52,68,48,60,60,68,70,65,75,58,72,74,50,35,82,25,75,30,55,45,72,45,65,62}},
	counter_attack = {"Counter Attack", "A compact block releases three immediate runners after regaining possession.", 3, 1, "HIGH", "MEDIUM-HIGH", {75,85,68,50,32,30,95,28,55,32,55,72,60,72,90,20,72,92,75,86,48,92,30,72,52,25,28,48,65,22,35,62,30,20,46,58,55,62,72,72,70,68,88,52,58,78,25,88,30,80,65,60,35,82,38,32}},
	high_press = {"High Press", "A coordinated high block compresses opponents with three defensive duties.", 3, 3, "HIGH", "VERY HIGH", {68,62,60,60,82,94,70,62,50,38,58,72,44,78,72,38,58,68,68,72,70,72,55,72,60,38,36,72,65,65,72,68,88,96,72,78,78,82,78,68,72,80,92,28,75,62,62,52,48,55,60,58,42,68,35,88}},
	low_block_counter = {"Low Block Counter", "Compact box protection followed by a controlled two-run counter.", 2, 1, "LOW-MEDIUM", "LOW", {28,75,42,32,18,18,90,12,52,28,40,42,62,38,72,72,65,78,48,62,65,70,15,42,35,45,42,38,72,8,25,40,18,8,58,72,88,92,94,95,92,58,92,80,35,65,35,82,35,70,55,50,65,88,75,18}},
	protect_lead = {"Protect The Lead", "A low-risk late-game plan with compact marking and maximum recovery discipline.", 1, 1, "VERY LOW", "LOW", {24,40,72,45,28,30,40,10,30,20,32,18,58,28,28,90,82,20,15,35,72,18,10,18,35,88,82,48,88,5,20,25,30,12,42,68,85,90,90,90,92,52,95,88,28,20,72,55,82,25,45,45,88,78,82,28}},
	all_out_attack = {"All-Out Attack", "A time-limited emergency plan with five lanes and maximum box occupation.", 5, 4, "EXTREME", "EXTREME", {88,82,82,68,90,92,85,92,78,72,78,95,30,88,95,5,58,92,95,90,45,95,88,95,82,12,10,78,70,95,88,95,92,98,82,78,58,55,50,40,40,90,60,10,85,90,40,80,25,88,90,88,15,45,15,95}},
}

local aliases = {
	Balanced = "balanced_control", Possession = "short_possession", ["Tiki Taka"] = "short_possession", ["Counter Attack"] = "counter_attack", ["High Press"] = "high_press", Gegenpress = "high_press", ["Wing Play"] = "wing_overload", ["Direct Long Ball"] = "vertical_combination", ["Low Block"] = "low_block_counter", ["Park The Bus"] = "low_block_counter",
}

local details = {
	balanced_control = {{"4-3-3", "4-2-3-1", "4-4-2"}, "2-3-5 / 3-2-5", "4-4-2 medium block", "3-2", {"Reliable passing options", "Stable rest defense", "Flexible against most opponents"}, {"No extreme overload", "Can be outnumbered by specialist systems"}},
	short_possession = {{"4-3-3", "4-2-3-1", "3-5-2"}, "3-2-5", "4-1-4-1 compact block", "3-2", {"Controls midfield", "Creates short passing triangles", "Protects the ball"}, {"Space behind an advancing fullback", "Can become too patient against a low block"}},
	vertical_combination = {{"4-2-3-1", "4-3-3"}, "2-3-5", "4-4-2 medium-high block", "3-2", {"Breaks lines quickly", "Creates through-ball opportunities", "Strong central progression"}, {"Higher turnover risk", "Space after failed combinations"}},
	wing_overload = {{"4-3-3", "4-2-3-1"}, "3-2-5 with ball-side overload", "4-1-4-1 medium block", "3-2", {"Creates crosses and cutbacks", "Overloads isolated fullbacks", "Uses the far post"}, {"Exposed on the opposite transition", "Requires disciplined rest defense"}},
	central_overload = {{"4-2-3-1", "3-5-2", "4-3-3"}, "3-2-4-1", "4-3-2-1 compact block", "3-2", {"Creates central combinations", "Strong cutback occupation", "Excellent between the lines"}, {"Vulnerable to wide switches", "Can become congested"}},
	counter_attack = {{"4-4-2", "4-2-3-1", "5-3-2"}, "Direct 3-run transition", "4-4-2 / 5-3-2 compact block", "3-2 after transition settles", {"Attacks open space quickly", "Strong through-ball threat", "Punishes high lines"}, {"Concedes possession", "Can isolate the ball carrier"}},
	high_press = {{"4-3-3", "4-2-3-1"}, "2-3-5 aggressive occupation", "4-3-3 high block", "2-3", {"Wins the ball high", "Forces rushed passes", "Creates short-field attacks"}, {"Space behind the press", "High stamina cost", "Vulnerable when the first line is broken"}},
	low_block_counter = {{"5-3-2", "4-4-2"}, "Two-run counter", "5-4-1 / 4-5-1 low block", "Most players behind the ball", {"Protects the box", "Difficult to play through centrally", "Conserves stamina"}, {"Concedes territory", "Slow progression after recovery"}},
	protect_lead = {{"5-3-2", "4-4-2", "4-2-3-1"}, "Safe 3-2 circulation", "Compact medium-low block", "4-2", {"Controls late-game risk", "Protects central and box zones", "Limits transition exposure"}, {"Low attacking threat", "Can invite pressure if selected too early"}},
	all_out_attack = {{"3-5-2", "4-3-3", "4-4-2"}, "3-2-5 / 2-3-5", "High emergency press", "Minimum 2 players plus one midfielder", {"Maximum attacking presence", "Strong late-game pressure", "Many box targets"}, {"Highly vulnerable to counters", "Rapid stamina drain", "Not suitable as a full-match default"}},
}

local order = {"balanced_control", "short_possession", "vertical_combination", "wing_overload", "central_overload", "counter_attack", "high_press", "low_block_counter", "protect_lead", "all_out_attack"}
local presets = {}
for id, definition in definitions do
	local values = definition[7]
	assert(#values == #Config.SliderNames, id .. " does not define every tactic slider")
	local sliders = {}
	for index, name in Config.SliderNames do sliders[name] = values[index] end
	local detail = details[id]
	presets[id] = table.freeze({Id = id, Name = definition[1], Description = definition[2], MaxMajorRuns = definition[3], MaxPressers = definition[4], Risk = definition[5], StaminaDemand = definition[6], RecommendedFormations = table.freeze(detail[1]), InPossessionShape = detail[2], OutOfPossessionShape = detail[3], RestDefenseShape = detail[4], Strengths = table.freeze(detail[5]), Weaknesses = table.freeze(detail[6]), Sliders = table.freeze(sliders)})
end

function Config.ResolveId(value: any): string
	local id = tostring(value or "")
	if presets[id] then return id end
	return aliases[id] or "balanced_control"
end

function Config.IsKnown(value: any): boolean
	local id = tostring(value or "")
	return presets[id] ~= nil or aliases[id] ~= nil
end

function Config.Get(value: any): any
	return presets[Config.ResolveId(value)]
end

function Config.Normalize(payload: any): any
	local source = type(payload) == "table" and payload or {}
	local id = Config.ResolveId(source.PresetId or source.BasePresetId or source.Identity)
	local preset = presets[id]
	local supplied = type(source.Sliders) == "table" and source.Sliders or {}
	local sliders = {}
	for _, name in Config.SliderNames do
		local override = type(source.GlobalOverrides) == "table" and tonumber(source.GlobalOverrides[name]) or nil
		local value = override or tonumber(supplied[name])
		if not value or value ~= value or value == math.huge or value == -math.huge then value = preset.Sliders[name] end
		sliders[name] = math.clamp(value, 0, 100)
	end
	local behavior = AIBehaviorTuningConfig.NormalizeProfile(source, preset.Sliders)
	return {
		Version = Config.Version,
		PresetId = id,
		BasePresetId = id,
		Identity = preset.Name,
		Sliders = sliders,
		Custom = source.Custom == true or next(behavior.GlobalOverrides) ~= nil or next(behavior.PhaseOverrides) ~= nil or next(behavior.RoleOverrides) ~= nil or next(behavior.MatchStateOverrides) ~= nil or next(behavior.ExecutionOverrides) ~= nil,
		GlobalOverrides = behavior.GlobalOverrides,
		PhaseOverrides = behavior.PhaseOverrides,
		RoleOverrides = behavior.RoleOverrides,
		MatchStateOverrides = behavior.MatchStateOverrides,
		ExecutionOverrides = behavior.ExecutionOverrides,
		SavedAt = tonumber(source.SavedAt) or os.time(),
	}
end

Config.Presets = table.freeze(presets)
Config.Order = table.freeze(order)
Config.LegacyAliases = table.freeze(aliases)

return table.freeze(Config)
