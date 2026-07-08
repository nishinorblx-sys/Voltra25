--!strict

local Factory = require(script.Parent.MockModeService)

return Factory.new({
	Id = "Store",
	Kicker = "VOLTRA MARKET",
	Title = "STORE",
	Subtitle = "Gamepasses, Voltra Points, cosmetic drops, boosts, and sealed player packs.",
	Tabs = {
		{
			Id = "Passes",
			Label = "PASSES",
			Description = "Permanent premium supporter and customisation gamepasses.",
			Cards = {},
		},
		{
			Id = "Coins",
			Label = "COINS",
			Description = "Robux coin bundles for normal progression, packs, and squad building.",
			Cards = {},
		},
		{
			Id = "VoltraPoints",
			Label = "VOLTRA POINTS",
			Description = "Premium currency for cosmetics, bundles, star cards, and limited items.",
			Cards = {},
		},
		{
			Id = "Boosts",
			Label = "BOOSTS",
			Description = "Launch bundle, coin boosts, daily deal spin, and Star Card offers.",
			Cards = {},
		},
		{
			Id = "Packs",
			Label = "PACKS",
			Description = "Coin-purchased packs by rarity tier plus the charged Voltra Pack.",
			Cards = {},
		},
		{
			Id = "Kits",
			Label = "KITS",
			Description = "Founder, limited, premium, and animated Voltra kits.",
			Cards = {},
		},
		{
			Id = "Boots",
			Label = "BOOTS",
			Description = "Premium boot styles worn by your squad in matches.",
			Cards = {},
		},
		{
			Id = "GoalEffects",
			Label = "GOAL FX",
			Description = "Equip goal effects everyone sees when you score.",
			Cards = {},
		},
		{
			Id = "Celebrations",
			Label = "CELEBRATIONS",
			Description = "Celebration pack rolls plus equipable celebrations and walkouts.",
			Cards = {},
		},
		{
			Id = "Club",
			Label = "CLUB",
			Description = "Premium club, stadium, goal music, and identity customisation.",
			Cards = {},
		},
	},
})
