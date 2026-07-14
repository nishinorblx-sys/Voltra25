--!strict

return table.freeze({
	JogMin = 15.5,
	JogMax = 20.5,
	SprintMin = 22,
	SprintMax = 31,
	AccelerationMin = 10.5,
	AccelerationMax = 16.5,
	Deceleration = 18,
	SprintTurnPenalty = 0.84,
	SharpTurnDot = 0.35,
	DribbleJogMinMultiplier = 0.9,
	DribbleJogMaxMultiplier = 0.94,
	DribbleSprintMinMultiplier = 0.84,
	DribbleSprintMaxMultiplier = 0.88,
	LowEnergyThreshold = 24,
	LowEnergyMinimumMultiplier = 0.92,
	DebugAttributes = table.freeze({
		CurrentSpeed = "currentSpeed",
		TargetSpeed = "targetSpeed",
		Stamina = "stamina",
		SprintMultiplier = "sprintMultiplier",
		BallControlModifier = "ballControlModifier",
	}),
})
