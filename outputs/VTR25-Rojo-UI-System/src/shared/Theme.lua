local Theme = {}

Theme.Colors = {
	Electric = Color3.fromHex("B7FF1A"),
	Neon = Color3.fromHex("9FFF00"),
	Black = Color3.fromHex("050505"),
	Graphite = Color3.fromHex("111111"),
	Gunmetal = Color3.fromHex("1B1B1B"),
	Silver = Color3.fromHex("D9D9D9"),
	White = Color3.fromHex("F5F7F2"),
	Muted = Color3.fromHex("858A80"),
	Border = Color3.fromHex("30332D"),
	Danger = Color3.fromHex("FF4A55"),
	Warning = Color3.fromHex("FFCB45"),
	Pitch = Color3.fromHex("172211"),
}

Theme.Fonts = {
	Display = Enum.Font.GothamBlack,
	Strong = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Regular = Enum.Font.Gotham,
}

Theme.Space = { XS = 6, SM = 10, MD = 16, LG = 24, XL = 32, XXL = 48 }
Theme.Radius = { Small = 4, Medium = 8, Large = 12 }
Theme.Motion = { Fast = 0.12, Standard = 0.22, Slow = 0.45 }

Theme.Breakpoints = {
	Compact = 760,
	Wide = 1180,
}

return Theme
