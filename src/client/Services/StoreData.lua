--!strict

local Factory = require(script.Parent.MockModeService)

return Factory.new({
	Id = "Store",
	Kicker = "VOLTRA MARKET",
	Title = "STORE",
	Subtitle = "Buy coins first, then spend coins on sealed VTR player packs.",
	Tabs = {
		{
			Id = "Coins",
			Label = "COINS",
			Description = "Robux coin bundles. Product IDs are placeholders until live Roblox developer products are connected.",
			Cards = {},
		},
		{
			Id = "Packs",
			Label = "PACKS",
			Description = "Coin-purchased packs by rarity tier plus the charged Voltra Pack.",
			Cards = {},
		},
	},
})
