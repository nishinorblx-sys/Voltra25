--!strict

return table.freeze({
	Camera = table.freeze({
		Desktop = table.freeze({Preset = "Tactical", ZoomMode = "Moderate", FieldOfView = 66}),
		Gamepad = table.freeze({Preset = "Pro", ZoomMode = "Moderate", FieldOfView = 68}),
		Mobile = table.freeze({Preset = "Pro", ZoomMode = "Close", FieldOfView = 74}),
		SwitchBlendSeconds = 0.16,
	}),
	Mobile = table.freeze({
		ActionButtonMinimum = 54,
		ActionButtonMaximum = 72,
		AimDeadZonePixels = 11,
		AimMaximumRadiusPixels = 132,
		SwipeThresholdPixels = 54,
	}),
})
