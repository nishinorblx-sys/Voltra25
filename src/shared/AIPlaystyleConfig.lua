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

local builtIns = {}
local builtInOrder = {}
for _, id in ipairs(AITacticConfig.Order) do
	builtIns[id] = table.freeze(builtInPlaystyle(id))
	table.insert(builtInOrder, id)
end

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
	return builtIns[AITacticConfig.ResolveId(id)]
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

return table.freeze(Config)
