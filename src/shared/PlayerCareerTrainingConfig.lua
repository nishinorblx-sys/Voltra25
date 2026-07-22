--!strict

local PlayerCareerConfig = require(script.Parent.PlayerCareerConfig)

local Config = {}

Config.Grades = table.freeze({F = 0, D = 1, C = 2, B = 3, A = 4, ["A+"] = 5})
Config.MaxWeeklySlots = 5
Config.SessionExpirySeconds = 60 * 60
Config.Drills = PlayerCareerConfig.TrainingDrills

function Config.NormalizeGrade(value: any): string?
	local grade = tostring(value or "")
	if Config.Grades[grade] ~= nil then return grade end
	return nil
end

function Config.ScoreToGrade(score: number, maxScore: number): string
	local ratio = math.clamp(score / math.max(1, maxScore), 0, 1)
	if ratio >= 0.94 then return "A+" end
	if ratio >= 0.84 then return "A" end
	if ratio >= 0.7 then return "B" end
	if ratio >= 0.55 then return "C" end
	if ratio >= 0.38 then return "D" end
	return "F"
end

return table.freeze(Config)
