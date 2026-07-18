--!strict

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(8, 13, 24),
	PanelSoft = Color3.fromRGB(13, 20, 34),
	PanelRaised = Color3.fromRGB(20, 29, 47),
	PanelInset = Color3.fromRGB(10, 16, 27),
	Stroke = Color3.fromRGB(103, 255, 0),
	StrokeDim = Color3.fromRGB(44, 58, 75),
	Accent = Color3.fromRGB(182, 255, 22),
	AccentSoft = Color3.fromRGB(103, 255, 0),
	White = Color3.fromRGB(246, 250, 255),
	Silver = Color3.fromRGB(177, 187, 204),
	Muted = Color3.fromRGB(117, 128, 150),
	DarkText = Color3.fromRGB(8, 13, 20),
	Warning = Color3.fromRGB(255, 193, 72),
	Error = Color3.fromRGB(255, 95, 109),
}

Theme.Fonts = {
	Display = Enum.Font.GothamBlack,
	Strong = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
}

Theme.Radius = {
	Panel = 28,
	Card = 12,
	Control = 10,
	Pill = 999,
}

return table.freeze(Theme)
