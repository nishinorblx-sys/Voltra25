--!strict

local QuickSellValueConfig = {}

QuickSellValueConfig.RarityBands = table.freeze({
	Starter = { Min = 10, Max = 10, RatingMin = 40, RatingMax = 64 },
	Common = { Min = 15, Max = 15, RatingMin = 45, RatingMax = 69 },
	Bronze = { Min = 25, Max = 35, RatingMin = 50, RatingMax = 64 },
	Silver = { Min = 65, Max = 85, RatingMin = 65, RatingMax = 74 },
	Gold = { Min = 160, Max = 210, RatingMin = 75, RatingMax = 82 },
	Rare = { Min = 400, Max = 520, RatingMin = 80, RatingMax = 86 },
	Elite = { Min = 830, Max = 1100, RatingMin = 84, RatingMax = 89 },
	Legendary = { Min = 2650, Max = 3450, RatingMin = 88, RatingMax = 93 },
	Icon = { Min = 7900, Max = 10400, RatingMin = 90, RatingMax = 96 },
	Mythic = { Min = 21100, Max = 27600, RatingMin = 94, RatingMax = 99 },
})

QuickSellValueConfig.SpecialPremiums = table.freeze({
	["Rising Star"] = 0.05,
	RisingStar = 0.05,
	["Team of the Week"] = 0.06,
	TeamOfTheWeek = 0.06,
	TOTW = 0.06,
	Hero = 0.08,
	Electrum = 0.08,
	Champion = 0.10,
	Storm = 0.10,
	Limited = 0.12,
	Mythic = 0.12,
})

local rarityAliases = {
	STARTER = "Starter",
	COMMON = "Common",
	BRONZE = "Bronze",
	SILVER = "Silver",
	GOLD = "Gold",
	RARE = "Rare",
	ELITE = "Elite",
	LEGENDARY = "Legendary",
	ICON = "Icon",
	MYTHIC = "Mythic",
}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function number(value: any, fallback: number): number
	local parsed = tonumber(value)
	if parsed == nil or parsed ~= parsed then return fallback end
	return parsed
end

function QuickSellValueConfig.NormalizeRarity(card: any): string
	local rarity = type(card) == "table" and (card.Rarity or card.rarity or card.Tier or card.tier) or nil
	if type(rarity) ~= "string" or rarity == "" then return "Common" end
	local direct = QuickSellValueConfig.RarityBands[rarity]
	if direct then return rarity end
	return rarityAliases[string.upper(rarity)] or "Common"
end

function QuickSellValueConfig.NormalizeCardType(card: any, meta: any?): string
	local source = meta
	if type(source) ~= "table" then source = type(card) == "table" and card.Meta or nil end
	local cardType = type(source) == "table" and (source.CardType or source.cardType) or nil
	if cardType == nil and type(card) == "table" then cardType = card.CardType or card.cardType or card.SpecialType or card.specialType end
	return tostring(cardType or "Base")
end

function QuickSellValueConfig.NaturalValue(card: any, meta: any?): number
	local rarity = QuickSellValueConfig.NormalizeRarity(card)
	local band = QuickSellValueConfig.RarityBands[rarity] or QuickSellValueConfig.RarityBands.Common
	local rating = number(type(card) == "table" and (card.Rating or card.overall or card.Overall or card.BaseOverall or card.BaseRating) or nil, band.RatingMin)
	local alpha = if band.RatingMax <= band.RatingMin then 0 else clamp01((rating - band.RatingMin) / (band.RatingMax - band.RatingMin))
	local base = band.Min + ((band.Max - band.Min) * alpha)
	local premium = QuickSellValueConfig.SpecialPremiums[QuickSellValueConfig.NormalizeCardType(card, meta)] or 0
	return math.max(1, math.floor((base * (1 + premium)) + 0.5))
end

function QuickSellValueConfig.Value(card: any, meta: any?): number
	if type(meta) == "table" then
		local stored = tonumber(meta.QuickSellValue)
		if stored then return math.max(0, math.floor(stored + 0.5)) end
	end
	if type(card) == "table" then
		local stored = tonumber(card.QuickSellValue)
		if stored then return math.max(0, math.floor(stored + 0.5)) end
		if type(card.Meta) == "table" then
			local metaStored = tonumber(card.Meta.QuickSellValue)
			if metaStored then return math.max(0, math.floor(metaStored + 0.5)) end
			return QuickSellValueConfig.NaturalValue(card, card.Meta)
		end
	end
	return QuickSellValueConfig.NaturalValue(card, meta)
end

function QuickSellValueConfig.RecoveryRate(packPrice: number): number
	if packPrice <= 2000 then return 0.25 end
	if packPrice <= 10000 then return 0.30 end
	if packPrice <= 40000 then return 0.35 end
	return 0.40
end

function QuickSellValueConfig.PurchasedPackValues(cards: { any }, packPrice: number): { number }
	local natural = {}
	local totalNatural = 0
	for index, card in cards do
		local value = QuickSellValueConfig.NaturalValue(card)
		natural[index] = value
		totalNatural += value
	end
	if totalNatural <= 0 then return natural end
	local budget = math.floor(math.max(0, packPrice) * QuickSellValueConfig.RecoveryRate(packPrice) + 0.5)
	if totalNatural <= budget then return natural end
	local values = {}
	local remainders = {}
	local assigned = 0
	for index, value in natural do
		local raw = (value / totalNatural) * budget
		local floored = math.floor(raw)
		values[index] = floored
		assigned += floored
		table.insert(remainders, { Index = index, Remainder = raw - floored })
	end
	table.sort(remainders, function(a, b)
		if a.Remainder == b.Remainder then return a.Index < b.Index end
		return a.Remainder > b.Remainder
	end)
	local remaining = budget - assigned
	local cursor = 1
	while remaining > 0 and #remainders > 0 do
		local item = remainders[cursor]
		values[item.Index] += 1
		remaining -= 1
		cursor = (cursor % #remainders) + 1
	end
	return values
end

return table.freeze(QuickSellValueConfig)
