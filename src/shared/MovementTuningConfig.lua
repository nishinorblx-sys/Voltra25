--!strict

return table.freeze({
	JogMin = 13.8,
	JogMax = 23.8,
	SprintMin = 19.5,
	SprintMax = 40.5,
	AccelerationMin = 4.2,
	AccelerationMax = 20.5,
	Deceleration = 17.5,
	SprintTurnPenalty = 0.78,
	SharpTurnDot = 0.35,
	DribbleJogMultiplier = 0.85,
	DribbleSprintMultiplier = 0.78,
	LowStaminaThreshold = 28,
	LowStaminaMinimumMultiplier = 0.72,
	DebugAttributes = table.freeze({
		CurrentSpeed = "currentSpeed",
		TargetSpeed = "targetSpeed",
		Stamina = "stamina",
		SprintMultiplier = "sprintMultiplier",
		BallControlModifier = "ballControlModifier",
	}),
})
