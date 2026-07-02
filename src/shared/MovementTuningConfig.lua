--!strict

return table.freeze({
	JogMin = 15.2,
	JogMax = 21.4,
	SprintMin = 21.8,
	SprintMax = 35.8,
	AccelerationMin = 5.8,
	AccelerationMax = 15.8,
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
