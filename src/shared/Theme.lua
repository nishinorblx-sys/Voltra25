--!strict

local Theme = {
	Colors = {
		Electric = Color3.fromHex("B7FF1A"),
		Neon = Color3.fromHex("9FFF00"),
		Black = Color3.fromHex("050505"),
		Graphite = Color3.fromHex("111111"),
		Gunmetal = Color3.fromHex("1B1B1B"),
		Raised = Color3.fromHex("242620"),
		Silver = Color3.fromHex("D9D9D9"),
		White = Color3.fromHex("F5F7F2"),
		Muted = Color3.fromHex("858A80"),
		Border = Color3.fromHex("30332D"),
		Danger = Color3.fromHex("FF4A55"),
		Warning = Color3.fromHex("FFCB45"),
		Pitch = Color3.fromHex("172211"),
	},
	Fonts = {
		Display = Enum.Font.GothamBlack,
		Strong = Enum.Font.GothamBold,
		Body = Enum.Font.GothamMedium,
		Regular = Enum.Font.Gotham,
	},
	Spacing = {
		XXS = 4, XS = 6, SM = 10, MD = 16, LG = 24, XL = 32, XXL = 48,
	},
	Radius = {
		Small = 4, Medium = 7, Large = 12, Pill = 100,
	},
	Glow = {
		Color = Color3.fromHex("B7FF1A"),
		Transparency = 0.82,
		StrokeTransparency = 0.18,
	},
	Animation = {
		Hover = 0.12,
		Press = 0.08,
		Standard = 0.22,
		Page = 0.28,
		Slow = 0.48,
		EasingStyle = Enum.EasingStyle.Quart,
		EasingDirection = Enum.EasingDirection.Out,
	},
	Layout = {
		SidebarWidth = 220,
		CompactSidebarWidth = 188,
		TopbarHeight = 78,
		ContentPadding = 30,
		DesignWidth = 1280,
		DesignHeight = 720,
		CompactBreakpoint = 760,
		MinimumScale = 0.5,
		MaximumScale = 2.25,
	},
}

return table.freeze(Theme)
