--!strict
local Service = {}

local DIFFICULTIES = {
	["Street Level"] = {DecisionMin = 0.7, DecisionMax = 1.1, Mistake = 0.28, Discipline = 0.38, PassRisk = 0.24, ShotSelect = 0.35, Press = 0.35, Stamina = 0.72},
	["Local League"] = {DecisionMin = 0.55, DecisionMax = 0.9, Mistake = 0.2, Discipline = 0.5, PassRisk = 0.34, ShotSelect = 0.46, Press = 0.44, Stamina = 0.78},
	["Regional Pro"] = {DecisionMin = 0.4, DecisionMax = 0.7, Mistake = 0.14, Discipline = 0.62, PassRisk = 0.48, ShotSelect = 0.58, Press = 0.56, Stamina = 0.84},
	["National Class"] = {DecisionMin = 0.3, DecisionMax = 0.55, Mistake = 0.1, Discipline = 0.74, PassRisk = 0.6, ShotSelect = 0.7, Press = 0.68, Stamina = 0.9},
	["Continental Elite"] = {DecisionMin = 0.2, DecisionMax = 0.4, Mistake = 0.065, Discipline = 0.84, PassRisk = 0.72, ShotSelect = 0.8, Press = 0.78, Stamina = 0.95},
	["World Class"] = {DecisionMin = 0.15, DecisionMax = 0.3, Mistake = 0.04, Discipline = 0.92, PassRisk = 0.84, ShotSelect = 0.9, Press = 0.88, Stamina = 1},
	["Voltra Masters"] = {DecisionMin = 0.1, DecisionMax = 0.2, Mistake = 0.025, Discipline = 0.98, PassRisk = 0.94, ShotSelect = 0.96, Press = 0.94, Stamina = 1.04},
}

local ALIASES = {
	Amateur = "Street Level",
	["Semi Pro"] = "Local League",
	Professional = "Regional Pro",
	Legendary = "Voltra Masters",
}

function Service.Resolve(name: string?, random: Random?): any
	local canonical = ALIASES[name or ""] or name or "Regional Pro"
	local base = DIFFICULTIES[canonical] or DIFFICULTIES["Regional Pro"]
	local resolved: any = table.clone(base)
	resolved.Name = canonical
	resolved.Random = random or Random.new()
	return resolved
end

function Service.NextDecisionDelay(difficulty: any): number
	local random = difficulty.Random or Random.new()
	return random:NextNumber(difficulty.DecisionMin or 0.25, difficulty.DecisionMax or 0.45)
end

function Service.ApplyMistake(value: number, difficulty: any, scale: number?): number
	local mistake = (difficulty.Mistake or 0) * (scale or 1)
	if mistake <= 0 then
		return value
	end
	local random = difficulty.Random or Random.new()
	return value + random:NextNumber(-mistake, mistake)
end

return Service
