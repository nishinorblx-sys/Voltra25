--!strict

local Service = {}

local ATTACK_KEYS = {
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

local DEFENSE_KEYS = {
	"StructuredContainment",
	"LaneDisruption",
	"DepthProtection",
	"FlankIsolation",
	"CentralLock",
	"BaitAndCollapse",
	"CollectiveHunt",
	"BoxProtection",
	"DynamicCoverage",
	"TacticalCounterSystem",
}

local PRESETS = {
	balanced_control = {
		Attack = {PositionalControl = .62, AdaptiveController = .38},
		Defense = {StructuredContainment = .58, DynamicCoverage = .42},
	},
	short_possession = {
		Attack = {PositionalControl = .86, FluidRotation = .14},
		Defense = {StructuredContainment = .72, LaneDisruption = .28},
	},
	vertical_combination = {
		Attack = {VerticalCombination = .82, DirectAssault = .18},
		Defense = {LaneDisruption = .76, StructuredContainment = .24},
	},
	wing_overload = {
		Attack = {WideOverload = .86, PositionalControl = .14},
		Defense = {FlankIsolation = .78, StructuredContainment = .22},
	},
	central_overload = {
		Attack = {CentralDomination = .68, FluidRotation = .32},
		Defense = {CentralLock = .82, LaneDisruption = .18},
	},
	counter_attack = {
		Attack = {CounterattackingTrap = .58, DirectAssault = .42},
		Defense = {BaitAndCollapse = .58, DepthProtection = .42},
	},
	high_press = {
		Attack = {VerticalCombination = .54, DirectAssault = .46},
		Defense = {CollectiveHunt = .9, LaneDisruption = .1},
	},
	low_block_counter = {
		Attack = {CounterattackingTrap = .82, DirectAssault = .18},
		Defense = {BoxProtection = .72, DepthProtection = .28},
	},
	protect_lead = {
		Attack = {PositionalControl = .58, CounterattackingTrap = .42},
		Defense = {BoxProtection = .86, StructuredContainment = .14},
	},
	all_out_attack = {
		Attack = {DirectAssault = .42, WideOverload = .32, CentralDomination = .26},
		Defense = {CollectiveHunt = .84, DepthProtection = .16},
	},
}

local function ratio(style: any, key: string): number
	if style and style.Ratio then
		local ok, value = pcall(function() return style:Ratio(key) end)
		if ok and type(value) == "number" then return math.clamp(value, 0, 1) end
	end
	return .5
end

local function normalize(map: {[string]: number}, keys: {string}): {[string]: number}
	local result = {}
	local total = 0
	for _, key in ipairs(keys) do
		local value = math.max(0, tonumber(map[key]) or 0)
		result[key] = value
		total += value
	end
	if total <= 0 then
		result[keys[1]] = 1
		return result
	end
	for _, key in ipairs(keys) do
		result[key] = result[key] / total
	end
	return result
end

local function classifyAttack(style: any): {[string]: number}
	local direct = ratio(style, "PassingDirectness")
	local tempo = ratio(style, "PassTempo")
	local width = ratio(style, "AttackingWidth")
	local counter = ratio(style, "CounterAttackFrequency")
	local runs = ratio(style, "RunsInBehind")
	local support = ratio(style, "SupportDistance")
	local rotation = ratio(style, "MidfieldRotation")
	return normalize({
		PositionalControl = (1 - direct) * .28 + (1 - tempo) * .16 + (1 - support) * .22,
		VerticalCombination = direct * .22 + tempo * .2 + runs * .16 + ratio(style, "OneTouchPassing") * .18,
		DirectAssault = direct * .25 + runs * .22 + counter * .18 + tempo * .16,
		WideOverload = width * .34 + ratio(style, "OverlapFrequency") * .2 + ratio(style, "CrossingFrequency") * .18,
		CentralDomination = (1 - width) * .24 + rotation * .2 + ratio(style, "ThroughBallFrequency") * .15,
		CounterattackingTrap = counter * .32 + direct * .14 + (1 - ratio(style, "DefensiveDepth")) * .16,
		HighPressSwarm = ratio(style, "PressingIntensity") * .2 + ratio(style, "CounterPress") * .16,
		LowBlockFortress = (1 - ratio(style, "DefensiveDepth")) * .16 + (1 - ratio(style, "PressingIntensity")) * .14,
		FluidRotation = rotation * .28 + ratio(style, "CreativeFreedom") * .18 + ratio(style, "UnderlapFrequency") * .13,
		AdaptiveController = ratio(style, "RiskLevel") * .12 + .16,
	}, ATTACK_KEYS)
end

local function classifyDefense(style: any): {[string]: number}
	local depth = ratio(style, "DefensiveDepth")
	local press = ratio(style, "PressingIntensity")
	local compact = ratio(style, "BackLineCompactness")
	local lane = ratio(style, "LaneBlocking")
	local box = ratio(style, "BoxProtection")
	local zone = ratio(style, "ZoneDiscipline")
	return normalize({
		StructuredContainment = compact * .2 + zone * .22 + (1 - press) * .1,
		LaneDisruption = lane * .32 + press * .1,
		DepthProtection = (1 - depth) * .28 + compact * .16,
		FlankIsolation = ratio(style, "DefensiveWidth") * .22 + zone * .16,
		CentralLock = lane * .22 + compact * .18 + (1 - ratio(style, "DefensiveWidth")) * .16,
		BaitAndCollapse = (1 - press) * .18 + ratio(style, "CounterAttackFrequency") * .2,
		CollectiveHunt = press * .38 + depth * .18 + ratio(style, "CounterPress") * .2,
		BoxProtection = box * .34 + (1 - depth) * .18,
		DynamicCoverage = zone * .24 + ratio(style, "MidfieldRotation") * .16,
		TacticalCounterSystem = ratio(style, "RiskLevel") * .12 + .12,
	}, DEFENSE_KEYS)
end

function Service.Blends(style: any): any
	local presetId = tostring(style and style.PresetId or style and style.Tactics and style.Tactics.PresetId or "balanced_control")
	local preset = PRESETS[presetId]
	if preset and not (style and style.Tactics and style.Tactics.Custom == true) then
		return {Attack = normalize(preset.Attack, ATTACK_KEYS), Defense = normalize(preset.Defense, DEFENSE_KEYS), PresetId = presetId, BuiltIn = true}
	end
	return {Attack = classifyAttack(style), Defense = classifyDefense(style), PresetId = presetId, BuiltIn = false}
end

function Service.Leading(map: {[string]: number}): (string, number)
	local best = ""
	local bestScore = -math.huge
	for key, value in pairs(map or {}) do
		local score = tonumber(value) or 0
		if score > bestScore then
			best = key
			bestScore = score
		end
	end
	return best, bestScore
end

Service.AttackKeys = table.freeze(ATTACK_KEYS)
Service.DefenseKeys = table.freeze(DEFENSE_KEYS)
Service.Presets = table.freeze(PRESETS)

return Service
