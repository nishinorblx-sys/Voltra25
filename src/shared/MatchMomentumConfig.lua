--!strict

local Config = {}

Config.SampleMatchSeconds = 6
Config.RollingWindowSeconds = 15 * 60
Config.SmoothingPrevious = 0.55
Config.SmoothingIncoming = 0.45
Config.BigEventSmoothingPrevious = 0.25
Config.BigEventSmoothingIncoming = 0.75
Config.MaxPressure = 64
Config.MaxSamples = 96

Config.EventWeights = table.freeze({
	DefensiveThirdPossession = 1,
	MidfieldPossession = 2,
	OpponentHalfPossession = 4,
	FinalThirdPossession = 7,
	BoxEntry = 12,
	ProgressivePass = 4,
	SuccessfulDribble = 4,
	PassIntoBox = 8,
	CrossAttempt = 7,
	CrossCompleted = 8,
	Shot = 8,
	ShotInsideBox = 14,
	ShotOnTarget = 20,
	BigChanceCreated = 28,
	Goal = 40,
	Corner = 8,
	FreeKickNearBox = 9,
	HighBallWin = 10,
})

Config.MajorEvents = table.freeze({
	Goal = true,
	ShotOnTarget = true,
	BigChanceCreated = true,
	Penalty = true,
})

Config.MarkerEvents = table.freeze({
	Goal = "Goal",
	YellowCard = "YellowCard",
	RedCard = "RedCard",
	Penalty = "Penalty",
	Substitution = "Substitution",
})

return table.freeze(Config)
