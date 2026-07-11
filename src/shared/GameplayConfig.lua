--!strict

local GameplayConfig = {
	AutoStartTestMatch = false,
	Movement = {
		WalkSpeed = 16,
		SprintSpeed = 23,
		Acceleration = 11,
		TurnResponsiveness = 14,
		MaxServerHorizontalSpeed = 31,
	},
	Stamina = {
		Maximum = 100,
		DrainPerSecond = 19,
		RecoveryPerSecond = 13,
		RecoveryDelay = 0.7,
		MinimumToSprint = 5,
	},
	Camera = {
		Distance = 12,
		Height = 5.5,
		FocusHeight = 2.3,
		Sensitivity = 0.0028,
		MinPitch = math.rad(-18),
		MaxPitch = math.rad(38),
		FieldOfView = 72,
		SprintFieldOfView = 77,
	},
	Ball = {
		Name = "MatchBall",
		Radius = 1.15,
		PossessionRange = 5.2,
		DribbleDistance = 2.35,
		DribbleVerticalOffset = 1.68,
		DribbleResponsiveness = 15,
		MaxDribbleSpeed = 36,
		PickupCooldown = 0.3,
		PassSpeed = 56,
		ShotMinSpeed = 70,
		ShotMaxSpeed = 142,
		ShotLift = 0.085,
		MaxChargeTime = 1.25,
		TackleRange = 7,
		TackleCooldown = 0.85,
		SkillTouchSpeed = 30,
	},
	Validation = {
		ActionCooldowns = { Pass = 0.22, Shot = 0.3, Tackle = 0.5, Skill = 0.45, Sprint = 0.08 },
		MinimumAimDot = -0.2,
		MaximumPayloadMagnitude = 1.1,
	},
	Pitch = {
		Width = 120,
		Length = 180,
		GoalWidth = 26,
		GoalHeight = 10,
	},
	Match = {
		KickoffDelay = 2.5,
		GoalRestartDelay = 3,
		StateRate = 0.1,
		AIThinkRate = 0.18,
	},
}

return table.freeze(GameplayConfig)
