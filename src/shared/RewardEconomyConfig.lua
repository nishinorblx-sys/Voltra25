--!strict

local Config = {}

Config.WorldCupFinishPacks = table.freeze({
	["GROUP STAGE"] = "bronze_pack",
	["Round of 32"] = "bronze_pack",
	["Round of 16"] = "silver_pack",
	["Quarter Final"] = "gold_pack",
	["Semi Final"] = "rare_pack",
	["Final"] = "elite_pack",
	["CHAMPIONS"] = "champion_pack",
})

Config.RankedPathPackByWins = table.freeze({
	[1] = "bronze_pack",
	[2] = "bronze_pack",
	[3] = "silver_pack",
	[4] = "gold_pack",
	[5] = "rare_pack",
	[6] = "elite_pack",
	[7] = "legendary_pack",
})

-- A ranked win always feels useful, while prestige packs remain genuine chase results.
Config.RankedWinPackWeights = table.freeze({
	common_pack = 500,
	bronze_pack = 300,
	silver_pack = 130,
	gold_pack = 50,
	rare_pack = 14,
	elite_pack = 4,
	rising_star_pack = 2,
	totw_pack = 1.5,
	voltra_pack = 1,
	event_pack = 0.75,
	hero_pack = 0.35,
	champion_pack = 0.2,
	legendary_pack = 0.12,
	limited_pack = 0.05,
	icon_pack = 0.03,
	mythic_storm_pack = 0.015,
	mythic_pack = 0.005,
})

return table.freeze(Config)
