--!strict

return table.freeze({
	JogMin = 17,
	JogMax = 20,
	SprintMin = 25,
	SprintMax = 32,
	AccelerationMin = 7,
	AccelerationMax = 13,
	Deceleration = 15,
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
