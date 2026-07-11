--!strict

local CardVisualConfig = {}

local function visual(primary: string, secondary: string, trim: string, glow: string, pattern: string, border: string, shine: number, animation: string, effect: string?)
	return table.freeze({
		primaryColor = Color3.fromHex(primary),
		secondaryColor = Color3.fromHex(secondary),
		trimColor = Color3.fromHex(trim),
		glowColor = Color3.fromHex(glow),
		backgroundPattern = pattern,
		borderStyle = border,
		shineIntensity = shine,
		animationStyle = animation,
		effectStyle = effect or "None",
	})
end

CardVisualConfig.Rarities = table.freeze({
	Starter = visual("07120A", "122817", "79A94A", "B7FF1A", "Circuit", "Single", 0.08, "None"),
	Common = visual("242725", "111311", "777D78", "AEB4AA", "Matte", "Single", 0.04, "None"),
	Bronze = visual("6F3F24", "25170F", "C47C48", "D89561", "Brushed", "Double", 0.18, "Sweep"),
	Silver = visual("A9B0B3", "33393C", "EDF1F2", "D9D9D9", "Brushed", "Double", 0.24, "Sweep"),
	Gold = visual("B88712", "2D2206", "FFE084", "FFCB45", "Facet", "Double", 0.32, "Sweep"),
	Rare = visual("80610C", "102407", "E6C24F", "B7FF1A", "Energy", "Double", 0.42, "Pulse"),
	Elite = visual("401564", "0B1608", "B86DFF", "B7FF1A", "Prism", "Electric", 0.52, "Pulse"),
	Legendary = visual("070707", "2C2105", "F2C14E", "FFCB45", "Lightning", "Electric", 0.68, "Sweep"),
	Icon = visual("ECE8DC", "8D7B52", "E2BE63", "FFF3C7", "Prestige", "Double", 0.72, "Sweep"),
	Mythic = visual("020302", "102405", "B7FF1A", "9FFF00", "Lightning", "Electric", 0.9, "Lightning"),
})

CardVisualConfig.Types = table.freeze({
	Base = visual("111111", "191919", "D9D9D9", "B7FF1A", "None", "Single", 0, "None"),
	["Team of the Week"] = visual("050505", "1F1A04", "EACB4F", "B7FF1A", "Chevron", "Electric", 0.2, "Pulse", "BurningElectric"),
	["Rising Star"] = visual("10243B", "22103A", "78D8FF", "B7FF1A", "Rays", "Double", 0.24, "Sweep", "Starburst"),
	["Voltra Hero"] = visual("151006", "4B160D", "FF784F", "B7FF1A", "Lightning", "Electric", 0.3, "Pulse", "EmberVolt"),
	Hero = visual("151006", "4B160D", "FF784F", "B7FF1A", "Lightning", "Electric", 0.3, "Pulse", "EmberVolt"),
	Champion = visual("271B02", "070707", "FFE084", "FFCB45", "Crown", "Double", 0.36, "Sweep", "GoldFloodlight"),
	Event = visual("071B18", "172344", "55F2D2", "B7FF1A", "Prism", "Electric", 0.3, "Pulse", "PrismSparks"),
	Spark = visual("071B18", "172344", "55F2D2", "B7FF1A", "Prism", "Electric", 0.3, "Pulse", "PrismSparks"),
	Electrum = visual("120E22", "061B20", "80F7FF", "E8D27A", "Circuit", "Electric", 0.34, "Sweep", "PrismSparks"),
	Limited = visual("290B18", "090909", "FF5C91", "B7FF1A", "Facet", "Electric", 0.4, "Lightning", "MagentaLightning"),
	Storm = visual("020403", "162503", "B7FF1A", "57FFB0", "Lightning", "Electric", 0.58, "Lightning", "BurningElectric"),
	Mythic = visual("020302", "102405", "B7FF1A", "9FFF00", "Lightning", "Electric", 0.72, "Lightning", "MagentaLightning"),
})

function CardVisualConfig.Get(rarity: string?, cardType: string?): any
	local rarityVisual = CardVisualConfig.Rarities[rarity or ""] or CardVisualConfig.Rarities.Common
	local typeVisual = CardVisualConfig.Types[cardType or "Base"] or CardVisualConfig.Types.Base
	if not cardType or cardType == "Base" then return rarityVisual end
	return table.freeze({
		primaryColor = rarityVisual.primaryColor:Lerp(typeVisual.primaryColor, 0.32),
		secondaryColor = rarityVisual.secondaryColor:Lerp(typeVisual.secondaryColor, 0.38),
		trimColor = typeVisual.trimColor,
		glowColor = typeVisual.glowColor,
		backgroundPattern = typeVisual.backgroundPattern,
		borderStyle = typeVisual.borderStyle,
		shineIntensity = math.max(rarityVisual.shineIntensity, typeVisual.shineIntensity),
		animationStyle = typeVisual.animationStyle ~= "None" and typeVisual.animationStyle or rarityVisual.animationStyle,
		effectStyle = typeVisual.effectStyle ~= "None" and typeVisual.effectStyle or rarityVisual.effectStyle,
	})
end

function CardVisualConfig.TypeForRarity(rarity: string): string
	return rarity == "Mythic" and "Limited"
		or rarity == "Legendary" and "Champion"
		or rarity == "Elite" and "Rising Star"
		or "Base"
end

return table.freeze(CardVisualConfig)
