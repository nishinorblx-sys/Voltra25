--!strict

local Config = {}

Config.Version = 3
Config.MaxProfiles = 20
Config.MaxImportBytes = 24000
Config.ProfileNameMax = 32

Config.Scopes = table.freeze({"Global", "Phase", "Role", "MatchState", "Execution"})
Config.Phases = table.freeze({"BuildUp", "Progression", "FinalThird", "TransitionAttack", "TransitionDefense", "DefensiveBlock", "Press", "SetPiece"})
Config.Roles = table.freeze({"GK", "CB", "Fullback", "CDM", "CM", "CAM", "Winger", "ST"})
Config.MatchStates = table.freeze({"Neutral", "Leading", "Trailing", "LateLeading", "LateTrailing"})
Config.Categories = table.freeze({"Possession", "Pass Direction", "Reception", "Support", "Runs", "Defense", "Stamina", "Chance Creation", "Goalkeeper", "Set Pieces", "Execution"})

local function list(...: string): {string}
	return table.freeze({...})
end

local function setting(id: string, label: string, category: string, default: number, low: string, high: string, public: boolean, scopes: {string}, systems: {string}, min: number?, max: number?, step: number?, unit: string?): any
	return table.freeze({
		Id = id,
		Label = label,
		Category = category,
		Description = label,
		Min = min or 0,
		Max = max or 100,
		Step = step or 1,
		Unit = unit or "%",
		Default = default,
		LowLabel = low,
		HighLabel = high,
		Visibility = public and "Public" or "Developer",
		Scopes = scopes,
		Systems = systems,
	})
end

local definitions = {
	setting("BuildUpSpeed", "BUILD-UP SPEED", "Possession", 50, "Patient build-up", "Fast build-up", true, list("Global", "Phase", "MatchState"), list("AIPhaseService", "AIAssignmentService")),
	setting("PassingDirectness", "PASSING DIRECTNESS", "Pass Direction", 50, "Circulate", "Go vertical", true, list("Global", "Phase", "Role", "MatchState"), list("AIPassingDecisionService")),
	setting("AttackingWidth", "ATTACKING WIDTH", "Support", 52, "Narrow", "Wide", true, list("Global", "Phase", "Role"), list("AIAssignmentService")),
	setting("DefensiveWidth", "DEFENSIVE WIDTH", "Defense", 50, "Compact", "Wide", true, list("Global", "Phase", "MatchState"), list("AIDefensiveCoordinator")),
	setting("DefensiveDepth", "DEFENSIVE DEPTH", "Defense", 50, "Deep block", "High line", true, list("Global", "Phase", "MatchState"), list("AIAssignmentService", "AIDefensiveCoordinator")),
	setting("PressingIntensity", "PRESSING INTENSITY", "Defense", 48, "Hold shape", "Press hard", true, list("Global", "Phase", "Role", "MatchState"), list("AIDefensiveCoordinator", "AITeamController")),
	setting("CounterAttackFrequency", "COUNTER ATTACK", "Possession", 45, "Secure first", "Break immediately", true, list("Global", "Phase", "MatchState"), list("AIPossessionDirector", "AITacticalStoryService")),
	setting("OverlapFrequency", "OVERLAP FREQUENCY", "Runs", 45, "Hold line", "Overlap often", true, list("Global", "Role", "Phase"), list("AIRunCoordinator", "AIAssignmentService")),
	setting("CrossingFrequency", "CROSSING FREQUENCY", "Chance Creation", 45, "Retain and combine", "Deliver crosses", true, list("Global", "Phase", "Role"), list("AIPassingDecisionService")),
	setting("LongShotFrequency", "LONG SHOT FREQUENCY", "Chance Creation", 35, "Work closer", "Shoot early", true, list("Global", "Phase", "Role"), list("AIShootingDecisionService", "AIPlayerBrain")),
	setting("DribblingFreedom", "DRIBBLING FREEDOM", "Possession", 45, "Release ball", "Carry more", true, list("Global", "Role", "Phase"), list("AIDribblingDecisionService")),
	setting("RiskLevel", "RISK LEVEL", "Pass Direction", 45, "Protect ball", "Accept risk", true, list("Global", "Phase", "MatchState"), list("AIPassingDecisionService", "AIShootingDecisionService")),
	setting("SupportDistance", "SUPPORT DISTANCE", "Support", 50, "Short options", "Longer shape", true, list("Global", "Phase", "Role"), list("AIAssignmentService", "AISupportCoordinator")),
	setting("PassTempo", "PASS TEMPO", "Possession", 50, "Slow circulation", "Rapid circulation", true, list("Global", "Phase", "MatchState"), list("AIPlayerBrain")),
	setting("ForwardPassPriority", "FORWARD PASS PRIORITY", "Pass Direction", 52, "Neutral progression", "Seek line gains", true, list("Global", "Phase", "Role", "MatchState"), list("AIPassingDecisionService")),
	setting("BackPassSafety", "BACK-PASS SAFETY", "Pass Direction", 52, "Emergencies only", "Use safety player", true, list("Global", "Phase", "Role", "MatchState"), list("AIPassingDecisionService")),
	setting("SwitchPlayFrequency", "SWITCH PLAY", "Pass Direction", 50, "Stay same side", "Find far side", true, list("Global", "Phase", "MatchState"), list("AIPassingDecisionService", "AITacticalStoryService")),
	setting("ThroughBallFrequency", "THROUGH-BALL FREQUENCY", "Pass Direction", 48, "Rare through balls", "Seek runs behind", true, list("Global", "Phase", "Role"), list("AIPassingDecisionService")),
	setting("PassRisk", "PASS RISK", "Pass Direction", 45, "Protect the ball", "Attempt difficult passes", true, list("Global", "Phase", "Role", "MatchState"), list("AIPassingDecisionService")),
	setting("FirstTouchDirectness", "FIRST TOUCH DIRECTNESS", "Reception", 50, "Secure first", "Attack first touch", true, list("Global", "Role", "Phase"), list("PassReceptionService", "AIPlayerBrain")),
	setting("ReceiverTrapAggression", "RECEIVER TRAP", "Reception", 50, "Cushion ball", "Attack contact", true, list("Global", "Role", "Phase"), list("PassReceptionService")),
	setting("RunsInBehind", "RUNS IN BEHIND", "Runs", 50, "Come short", "Attack space", true, list("Global", "Role", "Phase"), list("AIRunCoordinator", "AIAssignmentService")),
	setting("UnderlapFrequency", "UNDERLAP FREQUENCY", "Runs", 50, "Stay outside", "Run inside", true, list("Global", "Role", "Phase"), list("AIRunCoordinator", "AIAssignmentService")),
	setting("BoxRuns", "BOX RUNS", "Chance Creation", 50, "Hold edge", "Attack box", true, list("Global", "Role", "Phase"), list("AIRunCoordinator", "AIAssignmentService")),
	setting("CutbackFrequency", "CUTBACK FREQUENCY", "Chance Creation", 50, "Cross or shoot", "Find cutback", true, list("Global", "Phase", "Role"), list("AIPassingDecisionService")),
	setting("FinalThirdPatience", "FINAL-THIRD PATIENCE", "Possession", 52, "Attack now", "Work defense", true, list("Global", "Phase", "MatchState"), list("AIPlayerBrain", "AITacticalStoryService")),
	setting("ShotPatience", "SHOT PATIENCE", "Chance Creation", 50, "Shoot early", "Wait for quality", true, list("Global", "Phase", "Role"), list("AIShootingDecisionService")),
	setting("OneTouchPassing", "ONE-TOUCH PASSING", "Possession", 50, "Control first", "Play first time", true, list("Global", "Role", "Phase"), list("AIPlayerBrain", "PassReceptionService")),
	setting("WidthDiscipline", "WIDTH DISCIPLINE", "Support", 52, "Free rotate", "Hold lane", true, list("Global", "Role", "Phase"), list("AIAssignmentService")),
	setting("FullbackAttack", "FULLBACK ATTACK", "Runs", 50, "Stay back", "Join attack", true, list("Global", "Role", "Phase"), list("AIRunCoordinator", "AIAssignmentService")),
	setting("MidfieldRotation", "MIDFIELD ROTATION", "Support", 50, "Hold spots", "Rotate often", true, list("Global", "Role", "Phase"), list("AIAssignmentService")),
	setting("CreativeFreedom", "CREATIVE FREEDOM", "Possession", 50, "Structured", "Inventive", true, list("Global", "Role", "Phase"), list("AITacticalStoryService", "AIPassingDecisionService")),
	setting("PressTriggerDistance", "PRESS TRIGGER DISTANCE", "Defense", 50, "Wait closer", "Trigger early", true, list("Global", "Phase", "Role"), list("AIDefensiveCoordinator", "AITeamController")),
	setting("CounterPress", "COUNTER PRESS", "Defense", 50, "Recover shape", "Press after loss", true, list("Global", "Phase", "MatchState"), list("AIDefensiveCoordinator", "AITacticalStoryService")),
	setting("TackleAggression", "TACKLE AGGRESSION", "Defense", 50, "Delay", "Step in", true, list("Global", "Role", "Phase"), list("AITacklingDecisionService")),
	setting("InterceptionRisk", "INTERCEPTION RISK", "Defense", 50, "Hold lane", "Jump passes", true, list("Global", "Role", "Phase"), list("AIDefensiveCoordinator", "AITacklingDecisionService")),
	setting("MarkingTightness", "MARKING TIGHTNESS", "Defense", 55, "Zone off", "Tight mark", true, list("Global", "Role", "Phase"), list("AIDefensiveCoordinator")),
	setting("LaneBlocking", "LANE BLOCKING", "Defense", 55, "Track runners", "Block lanes", true, list("Global", "Phase", "Role"), list("AIDefensiveCoordinator")),
	setting("BackLineCompactness", "BACK LINE COMPACTNESS", "Defense", 58, "Spread", "Compact", true, list("Global", "Phase", "MatchState"), list("AIDefensiveCoordinator", "AIAssignmentService")),
	setting("BoxProtection", "BOX PROTECTION", "Defense", 58, "Step out", "Protect box", true, list("Global", "Phase", "Role", "MatchState"), list("AIDefensiveCoordinator", "AIAssignmentService")),
	setting("ZoneDiscipline", "ZONE DISCIPLINE", "Defense", 58, "Follow man", "Hold zone", true, list("Global", "Role", "Phase"), list("AIDefensiveCoordinator")),
	setting("LooseBallAggression", "LOOSE BALL", "Defense", 52, "Hold shape", "Attack loose balls", true, list("Global", "Role", "Phase"), list("AILooseBallService", "AIAssignmentService")),
	setting("RecoveryRuns", "RECOVERY RUNS", "Runs", 62, "Conserve", "Recover hard", true, list("Global", "Role", "Phase"), list("AIRunCoordinator", "AIAssignmentService")),
	setting("SprintConservation", "SPRINT CONSERVATION", "Stamina", 60, "Spend energy", "Save energy", true, list("Global", "Role", "Phase", "MatchState"), list("AIMovementExecutor", "StaminaService")),
	setting("KeeperAggression", "KEEPER AGGRESSION", "Goalkeeper", 50, "Stay home", "Claim space", true, list("Global", "Role", "Phase"), list("AIGoalkeeperService")),
	setting("KeeperDistributionRisk", "KEEPER DISTRIBUTION RISK", "Goalkeeper", 45, "Safe release", "Riskier release", true, list("Global", "Role", "Phase"), list("AIGoalkeeperService")),
	setting("ShortGKDistribution", "SHORT GK DISTRIBUTION", "Goalkeeper", 55, "Go long", "Play short", true, list("Global", "Role", "Phase"), list("AIGoalkeeperService")),
	setting("LongGKDistribution", "LONG GK DISTRIBUTION", "Goalkeeper", 45, "Avoid long", "Launch long", true, list("Global", "Role", "Phase"), list("AIGoalkeeperService")),
	setting("FreeKickShortPass", "FREE-KICK SHORT PASS", "Set Pieces", 50, "Shoot/cross", "Play short", true, list("Global", "Phase"), list("SetPieceService")),
	setting("FreeKickLongPass", "FREE-KICK LONG PASS", "Set Pieces", 50, "Keep short", "Go long", true, list("Global", "Phase"), list("SetPieceService", "AIPassingDecisionService")),
	setting("CornerNearPost", "CORNER NEAR POST", "Set Pieces", 50, "Far/edge", "Near post", true, list("Global", "Phase"), list("SetPieceService")),
	setting("CornerFarPost", "CORNER FAR POST", "Set Pieces", 50, "Near/edge", "Far post", true, list("Global", "Phase"), list("SetPieceService")),
	setting("SetPiecePatience", "SET-PIECE PATIENCE", "Set Pieces", 50, "Fast restart", "Wait for runs", true, list("Global", "Phase"), list("SetPieceService")),
	setting("ClearanceHeight", "CLEARANCE HEIGHT", "Defense", 55, "Low clear", "High clear", true, list("Global", "Role", "Phase"), list("BallService", "AIPlayerBrain")),
	setting("StaminaPressLimit", "STAMINA PRESS LIMIT", "Stamina", 50, "Press tired", "Save tired legs", true, list("Global", "Role", "Phase"), list("AIDefensiveCoordinator", "StaminaService")),
	setting("DefensiveLineStepUp", "DEFENSIVE LINE STEP", "Defense", 50, "Drop", "Step up", true, list("Global", "Phase", "MatchState"), list("AIDefensiveCoordinator", "AIAssignmentService")),
	setting("PossessionPatience", "POSSESSION PATIENCE", "Possession", 50, "Release quickly", "Wait for structure", true, list("Global", "Phase", "MatchState"), list("AIPlayerBrain", "AITacticalStoryService")),
	setting("MinimumHoldTime", "MINIMUM HOLD TIME", "Possession", 0.18, "Immediate decisions", "Longer observation", false, list("Global", "Phase", "Role", "Execution"), list("AIPlayerBrain"), 0.05, 1.5, 0.05, "s"),
	setting("MaximumHoldTime", "MAXIMUM HOLD TIME", "Possession", 1.45, "Move rapidly", "Carry and draw", false, list("Global", "Phase", "Role", "Execution"), list("AIPlayerBrain"), 0.3, 3, 0.05, "s"),
	setting("DrawPressureBias", "DRAW PRESSURE", "Possession", 50, "Avoid pressure", "Invite pressure", false, list("Global", "Phase", "Role"), list("AIPlayerBrain")),
	setting("CarryBeforePassBias", "CARRY BEFORE PASS", "Possession", 50, "Pass now", "Improve angle", false, list("Global", "Phase", "Role"), list("AIPlayerBrain", "AIDribblingDecisionService")),
	setting("DecisionCommitment", "DECISION COMMITMENT", "Possession", 50, "Reconsider often", "Commit plan", false, list("Global", "Phase", "Execution"), list("AIPlayerBrain", "AITacticalStoryService")),
	setting("PlanAbortThreshold", "PLAN ABORT THRESHOLD", "Possession", 50, "Abort easily", "Hold plan", false, list("Global", "Phase", "Execution"), list("AITacticalStoryService")),
	setting("ForwardPassBias", "FORWARD PASS BIAS", "Pass Direction", 0, "Discourage progression", "Reward progression", false, list("Global", "Phase", "Role", "MatchState"), list("AIPassingDecisionService"), -100, 100, 1, "pts"),
	setting("LateralPassBias", "LATERAL PASS BIAS", "Pass Direction", 0, "Avoid sideways", "Use circulation", false, list("Global", "Phase", "Role", "MatchState"), list("AIPassingDecisionService"), -100, 100, 1, "pts"),
	setting("BackPassBias", "BACK/RESET PASS BIAS", "Pass Direction", 0, "Avoid resets", "Recycle freely", false, list("Global", "Phase", "Role", "MatchState"), list("AIPassingDecisionService"), -100, 100, 1, "pts"),
	setting("SidePassPriority", "SIDE-PASS PRIORITY", "Pass Direction", 50, "Prefer vertical", "Shift block", false, list("Global", "Phase", "Role"), list("AIPassingDecisionService")),
	setting("RecycleBias", "RECYCLE POSSESSION", "Pass Direction", 50, "Keep attacking lane", "Reset and rebuild", false, list("Global", "Phase", "MatchState"), list("AIPassingDecisionService", "AITacticalStoryService")),
	setting("LineBreakBias", "LINE-BREAKING PASS", "Pass Direction", 50, "Protect possession", "Break lines", false, list("Global", "Phase", "Role"), list("AIPassingDecisionService")),
	setting("SafePassBias", "SAFE PASS BIAS", "Pass Direction", 50, "Accept risk", "Protect retention", false, list("Global", "Phase", "MatchState"), list("AIPassingDecisionService")),
	setting("LobPassBias", "LOFTED PASS BIAS", "Pass Direction", 50, "Ground passes", "Aerial routes", false, list("Global", "Phase", "Role"), list("AIPassingDecisionService")),
	setting("PassToFeetBias", "PASS TO FEET", "Reception", 50, "Lead into space", "Find feet", false, list("Global", "Phase", "Role"), list("AIPassingDecisionService", "AIPassExecutionPlanner")),
	setting("LeadRunBias", "LEAD RUN", "Reception", 50, "Feet first", "Lead runner", false, list("Global", "Phase", "Role"), list("AIPassingDecisionService", "AIPassExecutionPlanner")),
	setting("RetentionProbabilityWeight", "RETENTION WEIGHT", "Pass Direction", 50, "Ignore completion", "Protect completion", false, list("Global", "Phase", "Execution"), list("AIPassingDecisionService")),
	setting("ReceiverNextOptionsWeight", "NEXT OPTIONS WEIGHT", "Pass Direction", 50, "Ignore next action", "Plan next pass", false, list("Global", "Phase", "Execution"), list("AIPassingDecisionService")),
	setting("ReceiverIsolationPenalty", "ISOLATION PENALTY", "Support", 50, "Accept isolation", "Avoid isolation", false, list("Global", "Phase", "Execution"), list("AIPassingDecisionService", "AISupportCoordinator")),
	setting("AerialContestPenalty", "AERIAL CONTEST PENALTY", "Pass Direction", 50, "Accept contests", "Avoid contests", false, list("Global", "Phase", "Execution"), list("AIPassingDecisionService")),
	setting("ImmediateSupportDistance", "IMMEDIATE SUPPORT DISTANCE", "Support", 34, "Tight triangles", "Wider support", false, list("Global", "Phase", "Role"), list("AIAssignmentService", "AISupportCoordinator"), 14, 72, 1, "studs"),
	setting("TriangleStrength", "TRIANGLE STRENGTH", "Support", 50, "Loose support", "Triangle play", false, list("Global", "Phase", "Role"), list("AIAssignmentService", "AITacticalStoryService")),
	setting("MaxMajorRuns", "MAX MAJOR RUNS", "Runs", 2, "Few runs", "Many runs", false, list("Global", "Phase", "Execution"), list("AIRunCoordinator"), 1, 5, 1, "players"),
	setting("RestDefenseMinimum", "REST DEFENSE", "Defense", 3, "Commit bodies", "Protect counter", false, list("Global", "Phase", "MatchState"), list("AIRunCoordinator", "AIAssignmentService"), 1, 6, 1, "players"),
	setting("RunCommitment", "RUN COMMITMENT", "Runs", 50, "Cancel runs", "Commit runs", false, list("Global", "Phase", "Role"), list("AIRunCoordinator")),
	setting("RunCooldown", "RUN COOLDOWN", "Runs", 0.8, "Repeat runs", "Rest between runs", false, list("Global", "Phase", "Role"), list("AIRunCoordinator"), 0.1, 3, 0.1, "s"),
	setting("LaneReservationStrictness", "LANE RESERVATION", "Runs", 50, "Share lanes", "Reserve lanes", false, list("Global", "Phase", "Execution"), list("AIRunCoordinator")),
	setting("OffsideSafetyMargin", "OFFSIDE SAFETY", "Runs", 8, "Risk line", "Stay safe", false, list("Global", "Phase", "Role"), list("AIRunCoordinator", "AIAssignmentService"), 0, 22, 1, "studs"),
	setting("MaxPressers", "MAX PRESSERS", "Defense", 2, "Solo press", "Swarm press", false, list("Global", "Phase", "Execution"), list("AIDefensiveCoordinator"), 1, 5, 1, "players"),
	setting("PressDuration", "PRESS DURATION", "Defense", 1.2, "Brief jump", "Sustain press", false, list("Global", "Phase", "Role"), list("AIDefensiveCoordinator"), 0.3, 4, 0.1, "s"),
	setting("CoverPresserAggression", "COVER PRESSER", "Defense", 50, "Cover lanes", "Step to ball", false, list("Global", "Phase", "Role"), list("AIDefensiveCoordinator")),
	setting("SequencePersistence", "SEQUENCE PERSISTENCE", "Possession", 50, "New idea often", "Keep sequence", false, list("Global", "Phase", "Execution"), list("AITacticalStoryService")),
	setting("ThirdManSequenceBias", "THIRD-MAN SEQUENCE", "Support", 50, "Simple options", "Third-player play", false, list("Global", "Phase", "Role"), list("AITacticalStoryService", "AIAssignmentService")),
	setting("LookaheadPasses", "LOOKAHEAD PASSES", "Execution", 1, "Immediate choice", "Plan ahead", false, list("Global", "Execution"), list("AIPassingDecisionService"), 0, 3, 1, "passes"),
	setting("CandidateBreadth", "CANDIDATE BREADTH", "Execution", 5, "Few candidates", "More candidates", false, list("Global", "Execution"), list("AIPassingDecisionService"), 2, 10, 1, "options"),
}

local byId: {[string]: any} = {}
local order = {}
for _, item in ipairs(definitions) do
	byId[item.Id] = item
	table.insert(order, item.Id)
end

local function hasValue(values: {string}, value: string): boolean
	return table.find(values, value) ~= nil
end

local function finite(value: any): number?
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return nil
	end
	return number
end

local function cleanSettingValue(id: string, value: any): number?
	local meta = byId[id]
	local number = meta and finite(value) or nil
	if not meta or number == nil then
		return nil
	end
	local stepped = math.round(number / meta.Step) * meta.Step
	return math.clamp(stepped, meta.Min, meta.Max)
end

local function cleanOverrideMap(source: any, scope: string?): {[string]: number}
	local result: {[string]: number} = {}
	if type(source) ~= "table" then
		return result
	end
	for id, value in pairs(source) do
		local key = tostring(id)
		local meta = byId[key]
		local cleaned = cleanSettingValue(key, value)
		if meta and cleaned ~= nil and (not scope or hasValue(meta.Scopes, scope)) then
			result[key] = cleaned
		end
	end
	return result
end

local function cleanNested(source: any, allowedKeys: {string}, scope: string): {[string]: {[string]: number}}
	local result: {[string]: {[string]: number}} = {}
	if type(source) ~= "table" then
		return result
	end
	for _, key in ipairs(allowedKeys) do
		local cleaned = cleanOverrideMap(source[key], scope)
		if next(cleaned) then
			result[key] = cleaned
		end
	end
	return result
end

function Config.Get(id: string): any?
	return byId[id]
end

function Config.All(): {any}
	local result = {}
	for _, id in ipairs(order) do
		table.insert(result, byId[id])
	end
	return result
end

function Config.Public(): {any}
	local result = {}
	for _, id in ipairs(order) do
		local meta = byId[id]
		if meta.Visibility == "Public" then
			table.insert(result, meta)
		end
	end
	return result
end

function Config.IsKnown(id: string): boolean
	return byId[id] ~= nil
end

function Config.ValidateSettingValue(id: string, value: any): (boolean, number?)
	local cleaned = cleanSettingValue(id, value)
	return cleaned ~= nil, cleaned
end

function Config.NormalizeProfile(source: any, baseSliders: {[string]: number}?): any
	local payload = type(source) == "table" and source or {}
	local global = cleanOverrideMap(payload.GlobalOverrides or payload.Sliders, "Global")
	if baseSliders then
		for id, value in pairs(global) do
			local base = finite(baseSliders[id])
			if base ~= nil and math.abs(base - value) < 0.0001 then
				global[id] = nil
			end
		end
	end
	local result = {
		Version = Config.Version,
		GlobalOverrides = global,
		PhaseOverrides = cleanNested(payload.PhaseOverrides, Config.Phases, "Phase"),
		RoleOverrides = cleanNested(payload.RoleOverrides, Config.Roles, "Role"),
		MatchStateOverrides = cleanNested(payload.MatchStateOverrides, Config.MatchStates, "MatchState"),
		ExecutionOverrides = cleanOverrideMap(payload.ExecutionOverrides, "Execution"),
	}
	return result
end

function Config.Resolve(baseSliders: {[string]: number}?, profile: any?, context: any?): any
	local resolved: {[string]: number} = {}
	for _, id in ipairs(order) do
		local meta = byId[id]
		local base = baseSliders and finite(baseSliders[id])
		resolved[id] = base ~= nil and math.clamp(base, meta.Min, meta.Max) or meta.Default
	end
	local normalized = Config.NormalizeProfile(profile or {}, baseSliders)
	local function apply(map: any, source: string)
		for id, value in pairs(map or {}) do
			if byId[id] and value ~= nil then
				resolved[id] = value
			end
		end
	end
	apply(normalized.GlobalOverrides, "Global")
	local phase = context and context.Phase
	if type(phase) == "string" then apply(normalized.PhaseOverrides[phase], "Phase") end
	local role = context and context.Role
	if type(role) == "string" then apply(normalized.RoleOverrides[role], "Role") end
	if type(context) == "table" and type(context.Instructions) == "table" then apply(cleanOverrideMap(context.Instructions), "Instruction") end
	local matchState = context and context.MatchState
	if type(matchState) == "string" then apply(normalized.MatchStateOverrides[matchState], "MatchState") end
	if type(context) == "table" and type(context.Sequence) == "table" then apply(cleanOverrideMap(context.Sequence), "Sequence") end
	apply(normalized.ExecutionOverrides, "Execution")
	if type(context) == "table" and type(context.Emergency) == "table" then apply(cleanOverrideMap(context.Emergency), "Emergency") end
	return resolved
end

function Config.ClientMetadata(developer: boolean): any
	local settings = {}
	for _, id in ipairs(order) do
		local meta = byId[id]
		if developer or meta.Visibility == "Public" then
			table.insert(settings, meta)
		end
	end
	return {
		Version = Config.Version,
		Settings = settings,
		Scopes = Config.Scopes,
		Phases = Config.Phases,
		Roles = Config.Roles,
		MatchStates = Config.MatchStates,
		Categories = Config.Categories,
		MaxProfiles = Config.MaxProfiles,
	}
end

function Config.SanitizeProfileName(value: any): string?
	if type(value) ~= "string" then return nil end
	local cleaned = value:gsub("[%c<>]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	cleaned = cleaned:sub(1, Config.ProfileNameMax)
	if #cleaned < 1 then return nil end
	return cleaned
end

return table.freeze(Config)
