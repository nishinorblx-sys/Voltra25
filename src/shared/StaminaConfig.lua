--!strict

return table.freeze({
	Maximum = 100,
	SprintDrainLowRating = 11.8,
	SprintDrainHighRating = 8,
	JogRecoveryLowRating = 5.6,
	JogRecoveryHighRating = 8.2,
	IdleRecoveryLowRating = 10.2,
	IdleRecoveryHighRating = 14.2,
	ExhaustedRecoveryThreshold = 24,
	MinimumMovementMagnitude = 0.12,
	SprintDurationRampSeconds = 8,
	SprintDurationMaximumMultiplier = 1.1,
	PossessionDrainMultiplier = 1.05,
	RequestWatchdogSeconds = 1.6,
	SimulationStepSeconds = 0.1,
})
