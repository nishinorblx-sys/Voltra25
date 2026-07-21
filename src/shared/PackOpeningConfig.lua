--!strict

local Config = {}

Config.PackOpenSoundId = "rbxassetid://76159397654832"
Config.PackOpenSoundDelaySeconds = 0.7
Config.PackOpenSoundVolume = 0.65
Config.PremiumWalkoutMinimumRating = 85
Config.SuperWalkoutMinimumRating = 90
Config.PremiumConfettiEnabled = true
Config.PremiumPyroEnabled = true
Config.PremiumSmokeEnabled = true

Config.ForcePremiumRarities = table.freeze({})

Config.WalkoutColorPalettes = table.freeze({
	Base = table.freeze({ Main = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("FFFFFF"), Secondary = Color3.fromHex("55F2D2"), Dark = Color3.fromHex("071009") }),
	Gold = table.freeze({ Main = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("FFD84A"), Secondary = Color3.fromHex("FFFFFF"), Dark = Color3.fromHex("1F1805") }),
	Rare = table.freeze({ Main = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("E6C24F"), Secondary = Color3.fromHex("FFFFFF"), Dark = Color3.fromHex("102407") }),
	Elite = table.freeze({ Main = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("B86DFF"), Secondary = Color3.fromHex("FFFFFF"), Dark = Color3.fromHex("0B0615") }),
	Legendary = table.freeze({ Main = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("FFCB45"), Secondary = Color3.fromHex("FFFFFF"), Dark = Color3.fromHex("070707") }),
	Limited = table.freeze({ Main = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("FF5C91"), Secondary = Color3.fromHex("FFE45C"), Dark = Color3.fromHex("180711") }),
	Icon = table.freeze({ Main = Color3.fromHex("E2BE63"), Accent = Color3.fromHex("FFF3C7"), Secondary = Color3.fromHex("B7FF1A"), Dark = Color3.fromHex("17120A") }),
	Mythic = table.freeze({ Main = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("FFFFFF"), Secondary = Color3.fromHex("57FFB0"), Dark = Color3.fromHex("020302") }),
})

Config.CardFrameStyle = table.freeze({
	Base = "Premium",
	Gold = "Premium",
	Rare = "Premium",
	Elite = "Elite",
	Legendary = "Elite",
	Limited = "Limited",
	Icon = "Icon",
	Mythic = "Mythic",
})

Config.RarityRank = table.freeze({
	Starter = 1,
	Common = 2,
	Bronze = 3,
	Silver = 4,
	Gold = 5,
	Rare = 6,
	Elite = 7,
	Legendary = 8,
	Icon = 9,
	Mythic = 10,
})

Config.SpecialCardTypes = table.freeze({
	Mythic = "SuperWalkout",
	Limited = "SuperWalkout",
	Storm = "SuperWalkout",
	Icon = "SuperWalkout",
	Champion = "Walkout",
	["Voltra Hero"] = "Walkout",
	Hero = "Walkout",
	Event = "Walkout",
	Spark = "Walkout",
	Electrum = "Spotlight",
	["Team of the Week"] = "Spotlight",
	["Rising Star"] = "Spotlight",
})

Config.TierOrder = table.freeze({ "QuickReveal", "Spotlight", "Walkout", "SuperWalkout" })

Config.Tiers = table.freeze({
	QuickReveal = table.freeze({
		Rank = 1,
		Duration = 2.25,
		ReducedDuration = 1.35,
		Walkout = false,
		AvatarPhase = false,
		Intensity = 0.32,
		FlashLimit = 0.16,
		HeroHold = 0.45,
		Clues = {},
		Rarities = table.freeze({ Starter = true, Common = true, Bronze = true, Silver = true }),
	}),
	Spotlight = table.freeze({
		Rank = 2,
		Duration = 3.75,
		ReducedDuration = 1.55,
		Walkout = false,
		AvatarPhase = false,
		Intensity = 0.52,
		FlashLimit = 0.2,
		HeroHold = 0.85,
		Clues = table.freeze({ "Rarity", "Nationality", "Position", "Club" }),
		Rarities = table.freeze({ Gold = true, Rare = true }),
	}),
	Walkout = table.freeze({
		Rank = 3,
		Duration = 6.35,
		ReducedDuration = 1.8,
		Walkout = true,
		AvatarPhase = true,
		Intensity = 0.78,
		FlashLimit = 0.24,
		HeroHold = 1.25,
		WalkDuration = 1.7,
		Clues = table.freeze({ "Rarity", "Nationality", "Position", "Club" }),
		Rarities = table.freeze({ Elite = true, Legendary = true }),
		MinimumRating = Config.PremiumWalkoutMinimumRating,
	}),
	SuperWalkout = table.freeze({
		Rank = 4,
		Duration = 8.05,
		ReducedDuration = 1.9,
		Walkout = true,
		AvatarPhase = true,
		Intensity = 1,
		FlashLimit = 0.28,
		HeroHold = 1.65,
		WalkDuration = 2,
		Clues = table.freeze({ "Rarity", "Nationality", "Position", "Club" }),
		Rarities = table.freeze({ Icon = true, Mythic = true }),
		MinimumRating = Config.SuperWalkoutMinimumRating,
	}),
})

Config.Phases = table.freeze({
	Preparing = 0.12,
	Blackout = 0.32,
	TunnelIgnition = 0.55,
	PackEntrance = 0.45,
	EnergyCharge = 0.7,
	ClueSequence = 0.8,
	PackRupture = 0.32,
	Silhouette = 0.45,
	Walkout = 1.7,
	Celebration = 0.7,
	RatingReveal = 0.65,
	NameReveal = 0.45,
	HeroHold = 1.1,
	RemainingCards = 0.55,
	Results = 0,
	Complete = 0,
	Cancelled = 0,
})

Config.CameraKeyframes = table.freeze({
	Start = table.freeze({ Position = Vector3.new(0, 4.6, -35), Target = Vector3.new(0, 2.8, 0), FOV = 44 }),
	Charge = table.freeze({ Position = Vector3.new(0, 4.1, -23), Target = Vector3.new(0, 2.5, 0), FOV = 40 }),
	Walkout = table.freeze({ Position = Vector3.new(0, 3.4, -18), Target = Vector3.new(0, 2.6, 15), FOV = 36 }),
	Hero = table.freeze({ Position = Vector3.new(7, 3.1, -13), Target = Vector3.new(0, 2.2, 10), FOV = 31 }),
	Card = table.freeze({ Position = Vector3.new(8.5, 3.2, -14), Target = Vector3.new(1.2, 2.35, 10), FOV = 30 }),
})

Config.EffectBudget = table.freeze({
	Max3DParts = 60,
	MaxLightBars = 12,
	MaxSparkNodes = 36,
	MaxRenderSteppedConnections = 1,
})

Config.Input = table.freeze({
	SkipAvailableAfter = 0.85,
	HoldToSkipSeconds = 0.48,
})

Config.Audio = table.freeze({
	AmbientHum = table.freeze({ Id = "", Volume = 0.18, Looped = true }),
	TunnelIgnition = table.freeze({ Id = "", Volume = 0.32 }),
	LightTick = table.freeze({ Id = "", Volume = 0.18 }),
	EnergyChargeLoop = table.freeze({ Id = "", Volume = 0.3, Looped = true }),
	ClueHit = table.freeze({ Id = "", Volume = 0.4 }),
	PackCrack = table.freeze({ Id = "", Volume = 0.44 }),
	PackBurst = table.freeze({ Id = Config.PackOpenSoundId, Volume = Config.PackOpenSoundVolume }),
	SilhouetteRise = table.freeze({ Id = "", Volume = 0.36 }),
	CrowdSwell = table.freeze({ Id = "", Volume = 0.34 }),
	Footstep = table.freeze({ Id = "", Volume = 0.22 }),
	WalkoutImpact = table.freeze({ Id = "", Volume = 0.48 }),
	RatingTick = table.freeze({ Id = "", Volume = 0.22 }),
	RatingFinalHit = table.freeze({ Id = "", Volume = 0.5 }),
	NameReveal = table.freeze({ Id = "", Volume = 0.5 }),
	CardShine = table.freeze({ Id = "", Volume = 0.32 }),
	ResultsOpen = table.freeze({ Id = "", Volume = 0.26 }),
	Skip = table.freeze({ Id = "", Volume = 0.28 }),
})

local function rating(card: any): number
	return math.floor(tonumber(card and (card.Rating or card.overall or card.Overall)) or 0)
end

local function rarity(card: any): string
	return tostring(card and (card.Rarity or card.rarity) or "Starter")
end

local function cardType(card: any): string
	return tostring(card and (card.CardType or card.cardType or card.Type or "Base") or "Base")
end

local function tierRank(tier: string): number
	return tonumber(Config.Tiers[tier] and Config.Tiers[tier].Rank) or 0
end

function Config.PaletteForCard(card: any): any
	local cardRarity = rarity(card)
	local cardTypeName = cardType(card)
	if cardTypeName == "Limited" then return Config.WalkoutColorPalettes.Limited end
	if cardTypeName == "Mythic" or cardTypeName == "Storm" then return Config.WalkoutColorPalettes.Mythic end
	if cardTypeName == "Champion" then return Config.WalkoutColorPalettes.Gold end
	if cardTypeName == "Voltra Hero" or cardTypeName == "Hero" then return Config.WalkoutColorPalettes.Legendary end
	return Config.WalkoutColorPalettes[cardRarity] or Config.WalkoutColorPalettes.Base
end

function Config.FrameStyleForCard(card: any): string
	local cardTypeName = cardType(card)
	if cardTypeName == "Limited" then return "Limited" end
	if cardTypeName == "Mythic" or cardTypeName == "Storm" then return "Mythic" end
	if cardTypeName == "Champion" or cardTypeName == "Voltra Hero" or cardTypeName == "Hero" then return "Elite" end
	return tostring(Config.CardFrameStyle[rarity(card)] or Config.CardFrameStyle.Base)
end

function Config.SortReveals(reveals: any): { any }
	local result = {}
	for _, card in reveals or {} do table.insert(result, card) end
	table.sort(result, function(a, b)
		local ar = rating(a)
		local br = rating(b)
		if ar == br then
			local rr = (Config.RarityRank[rarity(a)] or 0) - (Config.RarityRank[rarity(b)] or 0)
			if rr == 0 then return tostring(a.Name or a.displayName or "") < tostring(b.Name or b.displayName or "") end
			return rr > 0
		end
		return ar > br
	end)
	return result
end

function Config.TierForCard(card: any): string
	local best = "QuickReveal"
	local cardRarity = rarity(card)
	local cardRating = rating(card)
	local premiumAllowed = cardRating >= Config.PremiumWalkoutMinimumRating or Config.ForcePremiumRarities[cardRarity] == true
	local typeTier = Config.SpecialCardTypes[cardType(card)]
	if typeTier and (premiumAllowed or tierRank(typeTier) < tierRank("Walkout")) and tierRank(typeTier) > tierRank(best) then best = typeTier end
	for tierName, tier in Config.Tiers do
		local rank = tierRank(tierName)
		local walkoutTier = tier.Walkout == true
		if tier.Rarities and tier.Rarities[cardRarity] and (not walkoutTier or premiumAllowed) and rank > tierRank(best) then best = tierName end
		if tier.MinimumRating and cardRating >= tier.MinimumRating and rank > tierRank(best) then best = tierName end
	end
	return best
end

function Config.SelectPresentation(reveals: any, options: any?): any
	local sorted = Config.SortReveals(reveals)
	local best = sorted[1]
	local tierName = Config.TierForCard(best)
	local reduced = options and options.ReducedMotion == true or workspace:GetAttribute("VTRReducedMotion") == true
	local openAll = options and options.OpenAll == true or (tonumber(options and options.PackCount) or 1) > 1
	local tier = Config.Tiers[tierName] or Config.Tiers.QuickReveal
	return {
		Tier = tierName,
		Profile = tier,
		BestCard = best,
		Reveals = sorted,
		ReducedMotion = reduced,
		OpenAll = openAll,
		Duration = reduced and tier.ReducedDuration or tier.Duration,
		OneHeroCinematic = true,
		ExposeOverallAtPhase = "RatingReveal",
	}
end

function Config.PhaseTimeline(selection: any): { any }
	local tier = selection and selection.Profile or Config.Tiers.QuickReveal
	local reduced = selection and selection.ReducedMotion == true
	if reduced then
		return {
			{ Name = "Preparing", Duration = 0.08 },
			{ Name = "Blackout", Duration = 0.12 },
			{ Name = "PackRupture", Duration = 0.18 },
			{ Name = "Silhouette", Duration = 0.16 },
			{ Name = "Walkout", Duration = 0.8 },
			{ Name = "Celebration", Duration = 1.05 },
			{ Name = "RatingReveal", Duration = 0.7 },
			{ Name = "NameReveal", Duration = 0.75 },
			{ Name = "HeroHold", Duration = tonumber(tier.HeroHold) and math.min(tier.HeroHold, 0.45) or 0.35 },
			{ Name = "RemainingCards", Duration = 0.18 },
			{ Name = "Results", Duration = 0 },
		}
	end
	if tier.Walkout ~= true then
		return {
			{ Name = "Preparing", Duration = 0.1 },
			{ Name = "Blackout", Duration = 0.22 },
			{ Name = "TunnelIgnition", Duration = 0.42 },
			{ Name = "PackEntrance", Duration = 0.35 },
			{ Name = "EnergyCharge", Duration = tier.Rank >= 2 and 0.55 or 0.28 },
			{ Name = "ClueSequence", Duration = tier.Rank >= 2 and 2.25 or 0 },
			{ Name = "PackRupture", Duration = 0.24 },
			{ Name = "Silhouette", Duration = 0.24 },
			{ Name = "Walkout", Duration = 1.15 },
			{ Name = "Celebration", Duration = 1.05 },
			{ Name = "RatingReveal", Duration = 0.85 },
			{ Name = "NameReveal", Duration = 0.85 },
			{ Name = "HeroHold", Duration = tier.HeroHold },
			{ Name = "RemainingCards", Duration = 0.28 },
			{ Name = "Results", Duration = 0 },
		}
	end
	return {
		{ Name = "Preparing", Duration = 0.12 },
		{ Name = "Blackout", Duration = 0.32 },
		{ Name = "TunnelIgnition", Duration = 0.55 },
		{ Name = "PackEntrance", Duration = 0.45 },
		{ Name = "EnergyCharge", Duration = 0.78 + tier.Intensity * 0.35 },
		{ Name = "ClueSequence", Duration = tier.Rank >= 4 and 3.2 or 2.8 },
		{ Name = "PackRupture", Duration = 0.32 },
		{ Name = "Silhouette", Duration = 0.42 },
		{ Name = "Walkout", Duration = tier.WalkDuration or 1.7 },
		{ Name = "Celebration", Duration = 4.35 },
		{ Name = "RatingReveal", Duration = 1.25 },
		{ Name = "NameReveal", Duration = 1.35 },
		{ Name = "HeroHold", Duration = tier.HeroHold },
		{ Name = "RemainingCards", Duration = 0.44 },
		{ Name = "Results", Duration = 0 },
	}
end

return table.freeze(Config)
