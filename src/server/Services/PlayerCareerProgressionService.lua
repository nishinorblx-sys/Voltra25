--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CareerConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerConfig)
local ProgressionConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerProgressionConfig)

local Service = {}

function Service.ApplyTrainingXP(career: any, channels: any, grade: string, repetitionCount: number): any
	career.Development = type(career.Development) == "table" and career.Development or {}
	career.Development.XP = type(career.Development.XP) == "table" and career.Development.XP or {}
	local gradeValue = ({F = 4, D = 8, C = 13, B = 19, A = 26, ["A+"] = 32})[grade] or 0
	local multiplier = ProgressionConfig.RepetitionMultiplier(math.max(0, repetitionCount))
	local granted = {}
	for _, channel in channels or {} do
		local key = tostring(channel)
		local amount = math.floor(gradeValue * multiplier + 0.5)
		career.Development.XP[key] = math.max(0, tonumber(career.Development.XP[key]) or 0) + amount
		granted[key] = amount
	end
	return granted
end

function Service.ApplyWeeklyReview(career: any): any
	local identity = career.Identity or {}
	local age = math.max(16, (tonumber(os.date("!*t").year) or 2026) - (tonumber(identity.BirthYear) or 2008))
	local attributes = career.Development and career.Development.Attributes or {}
	local xp = career.Development and career.Development.XP or {}
	local changes = {}
	local channelToAttribute = {
		Pace = "Pace",
		Power = "Strength",
		Endurance = "Stamina",
		Agility = "Agility",
		["Ball Control"] = "BallControl",
		Dribbling = "Dribbling",
		["Short Passing"] = "ShortPassing",
		["Long Passing"] = "LongPassing",
		Vision = "Vision",
		Finishing = "Finishing",
		["Shot Technique"] = "ShotPower",
		Aerial = "Aerial",
		["Defensive Awareness"] = "DefensiveAwareness",
		Tackling = "Tackling",
		Goalkeeping = "Goalkeeping",
		Composure = "Composure",
		Positioning = "Positioning",
		Leadership = "Leadership",
	}
	for channel, amount in xp do
		local attribute = channelToAttribute[channel]
		if attribute then
			local current = tonumber(attributes[attribute]) or 55
			local cost = CareerConfig.AttributeCost(current, age)
			local multiplier = CareerConfig.AgeDevelopmentMultiplier(age, channel)
			local delta = math.min(ProgressionConfig.WeeklyAdaptationCap, (tonumber(amount) or 0) / math.max(1, cost) * multiplier)
			if delta > 0 then
				attributes[attribute] = math.clamp(current + delta, 1, 99)
				xp[channel] = math.max(0, (tonumber(amount) or 0) - cost * delta)
				changes[attribute] = delta
			end
		end
	end
	career.Development.Attributes = attributes
	career.Overall = CareerConfig.PositionOverall(identity.PrimaryPosition or "ST", attributes)
	career.Development.DisplayedOverall = career.Overall
	career.Development.PositionOveralls = career.Development.PositionOveralls or {}
	career.Development.PositionOveralls[identity.PrimaryPosition or "ST"] = career.Overall
	return changes
end

return Service
