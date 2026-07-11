--!strict

local Config = {}

Config.Default = table.freeze({
	Archetype = "Finisher",
	Role = "CF",
	TraitA = "Threaded",
	TraitB = "Explosive Start",
	Style = "Poacher+",
	Attributes = table.freeze({}),
	Traits = table.freeze({}),
})

Config.Archetypes = table.freeze({
	Finisher = table.freeze({
		Title = "FINISHER",
		Tagline = "Score. Clinch. Win.",
		Focus = "Shooting + Positioning + Attack",
		Color = "A943FF",
		Icon = "V",
		Stats = table.freeze({SHO = 82, PAS = 66, DRI = 74, DEF = 55, PHY = 70, PAC = 76, acceleration = 78, agility = 74, stamina = 72, shotPower = 80, longShots = 76, standingTackle = 55, slidingTackle = 50, dribbling = 76}),
	}),
	Playmaker = table.freeze({
		Title = "PLAYMAKER",
		Tagline = "Make plays. Control the game.",
		Focus = "Passing + Vision + Creativity",
		Color = "00D46A",
		Icon = "*",
		Stats = table.freeze({SHO = 68, PAS = 82, DRI = 80, DEF = 58, PHY = 66, PAC = 74, acceleration = 76, agility = 82, stamina = 78, shotPower = 68, longShots = 74, standingTackle = 58, slidingTackle = 52, dribbling = 82}),
	}),
	Defender = table.freeze({
		Title = "DEFENDER",
		Tagline = "Stop. Defend. Dominate.",
		Focus = "Defense + Strength + Positioning",
		Color = "167CFF",
		Icon = "[]",
		Stats = table.freeze({SHO = 58, PAS = 70, DRI = 68, DEF = 82, PHY = 80, PAC = 72, acceleration = 70, agility = 68, stamina = 80, shotPower = 65, longShots = 55, standingTackle = 84, slidingTackle = 80, dribbling = 68}),
	}),
	Speedster = table.freeze({
		Title = "SPEEDSTER",
		Tagline = "Fast. Agile. Unstoppable.",
		Focus = "Pace + Dribbling + Agility",
		Color = "FFCC00",
		Icon = "Z",
		Stats = table.freeze({SHO = 70, PAS = 68, DRI = 82, DEF = 54, PHY = 66, PAC = 86, acceleration = 88, agility = 86, stamina = 80, shotPower = 72, longShots = 66, standingTackle = 52, slidingTackle = 48, dribbling = 84}),
	}),
	AllRounder = table.freeze({
		Title = "ALL-ROUNDER",
		Tagline = "Adapt. Balance. Impact.",
		Focus = "Balanced attributes",
		Color = "B7FF1A",
		Icon = "O",
		Stats = table.freeze({SHO = 74, PAS = 74, DRI = 74, DEF = 70, PHY = 74, PAC = 76, acceleration = 76, agility = 76, stamina = 82, shotPower = 74, longShots = 72, standingTackle = 70, slidingTackle = 66, dribbling = 76}),
	}),
})

Config.Order = table.freeze({"Finisher", "Playmaker", "Defender", "Speedster", "AllRounder"})
Config.Roles = table.freeze({"CF", "MID", "CB"})
Config.AttributeOrder = table.freeze({
	{Key = "PAC", Label = "Pace", Color = "FFCC00"},
	{Key = "SHO", Label = "Shooting", Color = "A943FF"},
	{Key = "PAS", Label = "Passing", Color = "00D46A"},
	{Key = "DRI", Label = "Dribbling", Color = "00D46A"},
	{Key = "DEF", Label = "Defense", Color = "167CFF"},
	{Key = "PHY", Label = "Physical", Color = "FFCC00"},
	{Key = "acceleration", Label = "Acceleration", Color = "FFCC00"},
	{Key = "agility", Label = "Agility", Color = "A943FF"},
	{Key = "stamina", Label = "Stamina", Color = "B7FF1A"},
	{Key = "shotPower", Label = "Shot Power", Color = "A943FF"},
	{Key = "longShots", Label = "Long Shots", Color = "A943FF"},
	{Key = "standingTackle", Label = "Tackling", Color = "167CFF"},
})
Config.Traits = table.freeze({
	"Threaded",
	"Long Switch",
	"Explosive Start",
	"Clean Strike",
	"Quick Release",
	"Outside the Box",
	"Recovery Defender",
	Threaded = table.freeze({Title = "Threaded", Description = "Ground passes travel faster through narrow gaps and are slightly harder to intercept."}),
	LongSwitch = table.freeze({Title = "Long Switch", Description = "More accurate and powerful diagonal passes across the pitch."}),
	ExplosiveStart = table.freeze({Title = "Explosive Start", Description = "Faster acceleration during the first few steps of a sprint."}),
	CleanStrike = table.freeze({Title = "Clean Strike", Description = "Shots taken with good balance have improved power and accuracy."}),
	QuickRelease = table.freeze({Title = "Quick Release", Description = "Reduced delay between receiving the ball and shooting."}),
	OutsideTheBox = table.freeze({Title = "Outside the Box", Description = "Improved shot power and reduced accuracy loss from long range."}),
	RecoveryDefender = table.freeze({Title = "Recovery Defender", Description = "Gains a temporary running boost after being beaten by an attacker."}),
})
Config.TraitOrder = table.freeze({"Threaded", "LongSwitch", "ExplosiveStart", "CleanStrike", "QuickRelease", "OutsideTheBox", "RecoveryDefender"})
Config.Styles = table.freeze({"Poacher+", "Tempo+", "Lockdown+", "Burst+"})
Config.Milestones = table.freeze({
	{Level = 10, Reward = "+10 attributes"},
	{Level = 20, Reward = "+1 trait point"},
	{Level = 30, Reward = "+12 attributes"},
	{Level = 40, Reward = "+1 trait point"},
	{Level = 50, Reward = "+15 attributes"},
})

local function clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = clone(child)
	end
	return result
end

function Config.AttributeBudgetForLevel(level: number?): number
	local value = math.max(1, math.floor(tonumber(level) or 1))
	local budget = 20 + (value - 1) * 2
	if value >= 10 then budget += 10 end
	if value >= 30 then budget += 12 end
	if value >= 50 then budget += 15 end
	return budget
end

function Config.TraitBudgetForLevel(level: number?): number
	local value = math.max(1, math.floor(tonumber(level) or 1))
	local budget = 0
	if value >= 10 then budget += 1 end
	if value >= 20 then budget += 1 end
	if value >= 30 then budget += 1 end
	if value >= 40 then budget += 1 end
	if value >= 50 then budget += 1 end
	return budget
end

local function orderedBudgetClamp(values: any, order: {any}, budget: number, maximum: number): ({[string]: number}, number)
	local result = {}
	local spent = 0
	values = type(values) == "table" and values or {}
	for _, entry in order do
		local key = tostring(entry.Key or entry)
		local raw = math.floor(tonumber(values[key]) or 0)
		local value = math.clamp(raw, 0, maximum)
		if spent + value > budget then
			value = math.max(0, budget - spent)
		end
		if value > 0 then
			result[key] = value
			spent += value
		end
	end
	return result, spent
end

function Config.Normalize(source: any, level: number?): any
	source = type(source) == "table" and source or {}
	local playerLevel = math.max(1, math.floor(tonumber(level or source.Level) or 1))
	local archetype = tostring(source.Archetype or Config.Default.Archetype)
	if not Config.Archetypes[archetype] then
		archetype = Config.Default.Archetype
	end
	local role = tostring(source.Role or Config.Default.Role)
	if not table.find(Config.Roles, role) then
		role = Config.Default.Role
	end
	local style = tostring(source.Style or Config.Default.Style)
	if not table.find(Config.Styles, style) then
		style = Config.Default.Style
	end
	local attributes, attributeSpent = orderedBudgetClamp(source.Attributes or source.SpentAttributes, Config.AttributeOrder, Config.AttributeBudgetForLevel(playerLevel), 99)
	local traits, traitSpent = orderedBudgetClamp(source.Traits or source.TraitLevels, Config.TraitOrder, Config.TraitBudgetForLevel(playerLevel), 3)
	local activeTraits = {}
	for _, id in Config.TraitOrder do
		if (traits[id] or 0) > 0 then
			table.insert(activeTraits, Config.Traits[id].Title)
		end
	end
	return {
		Archetype = archetype,
		Role = role,
		TraitA = activeTraits[1] or Config.Default.TraitA,
		TraitB = activeTraits[2] or Config.Default.TraitB,
		Style = style,
		Level = playerLevel,
		Attributes = attributes,
		AttributeBudget = Config.AttributeBudgetForLevel(playerLevel),
		AttributePointsSpent = attributeSpent,
		AttributePointsAvailable = math.max(0, Config.AttributeBudgetForLevel(playerLevel) - attributeSpent),
		Traits = traits,
		TraitBudget = Config.TraitBudgetForLevel(playerLevel),
		TraitPointsSpent = traitSpent,
		TraitPointsAvailable = math.max(0, Config.TraitBudgetForLevel(playerLevel) - traitSpent),
		UpdatedAt = tonumber(source.UpdatedAt) or os.time(),
	}
end

function Config.StatsFor(builder: any): any
	local normalized = Config.Normalize(builder)
	local archetype = Config.Archetypes[normalized.Archetype] or Config.Archetypes[Config.Default.Archetype]
	local stats = clone(archetype.Stats)
	for _, entry in Config.AttributeOrder do
		local key = tostring(entry.Key)
		stats[key] = math.clamp((tonumber(stats[key]) or 60) + (tonumber(normalized.Attributes[key]) or 0), 1, 99)
	end
	stats.overall = math.floor(((stats.SHO or 70) + (stats.PAS or 70) + (stats.DRI or 70) + (stats.DEF or 70) + (stats.PHY or 70) + (stats.PAC or 70)) / 6 + 0.5)
	return stats
end

return table.freeze(Config)
