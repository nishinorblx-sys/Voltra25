--!strict
return table.freeze({
	InputSmoothingTime = 0.13,
	InputSmoothingNoBall = 0.065,
	MaxTurnRateNoBall = math.rad(420),
	MaxTurnRateDribbling = math.rad(235),
	MaxTurnRateSprintingWithBall = math.rad(145),
	SharpTurnSpeedPenalty = 0.68,
	BallControlRecoveryTime = 0.55,
	SharpTurnDot = -0.15,
})
