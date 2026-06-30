--!strict
return table.freeze({
	Maximum = 100,
	-- Long-term match ceiling. 70 points across 75 game minutes leaves an
	-- average, normally-used player near 30 endurance around 75:00.
	EnduranceDrainPerGameMinute = 70 / 75,
	SprintEnduranceDrainPerRealSecond = 0.033,
	HighStatEnduranceReduction = 0.12,
	LowStatEnduranceIncrease = 0.10,
	-- Short-term sprint reserve. It can recover, but never above endurance.
	SprintReserveDrainMin = 2.25,
	SprintReserveDrainMax = 3.15,
	JogRecoveryMin = 5.5,
	JogRecoveryMax = 8,
	IdleRecoveryMin = 13,
	IdleRecoveryMax = 18,
	UnusedRecoveryMultiplier = 1.3,
	-- Once the short-term reserve is fully depleted, sprint stays unavailable
	-- until this percentage has recovered. This prevents Shift tapping at 1%.
	ExhaustedRecoveryThreshold = 30,
	SprintDurationRampSeconds = 8,
	SprintDurationMaxPenalty = 0.12,
})
