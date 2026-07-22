--!strict

local Config = {}

Config.MatchXP = table.freeze({Base = 24, RatingMultiplier = 5, MinutesMultiplier = 0.18, ManualMultiplier = 1, SimulationMultiplier = 0.55})
Config.WeeklyAdaptationCap = 0.42
Config.RepetitionPenalty = table.freeze({First = 1, Second = 0.72, Third = 0.46, Later = 0.25})
Config.PotentialSoftCaps = table.freeze({Low = 76, Normal = 84, High = 90, Elite = 94})
Config.DisplayProgressScale = 100

function Config.RepetitionMultiplier(count: number): number
	if count <= 0 then return Config.RepetitionPenalty.First end
	if count == 1 then return Config.RepetitionPenalty.Second end
	if count == 2 then return Config.RepetitionPenalty.Third end
	return Config.RepetitionPenalty.Later
end

return table.freeze(Config)
