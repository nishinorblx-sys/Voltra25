--!strict

local Config = {}

Config.RemoteFolderName = "DailyLoginRewardRemotes"
Config.PendingRemoteName = "PendingDailyLoginReward"
Config.ClaimRemoteName = "ClaimDailyLoginReward"
Config.DaySeconds = 86400
Config.WeekSeconds = Config.DaySeconds * 7
Config.TrackLength = 14

Config.Weeks = {
	{
		Name = "Squad Builder Week",
		Subtitle = "Build the XI, stack coins, open packs.",
		Rewards = {
			{Type = "Coins", Amount = 1500, Label = "Coins", Short = "1,500"},
			{Type = "Bolts", Amount = 90, Label = "Bolts", Short = "90"},
			{Type = "Pack", ItemId = "bronze_pack", Label = "Bronze Pack", Short = "Bronze"},
			{Type = "Coins", Amount = 4000, Label = "Coins", Short = "4,000"},
			{Type = "Bolts", Amount = 140, Label = "Bolts", Short = "140"},
			{Type = "Pack", ItemId = "silver_pack", Label = "Silver Pack", Short = "Silver"},
			{Type = "Coins", Amount = 9000, Label = "Milestone Coins", Short = "9,000"},
			{Type = "Pack", ItemId = "gold_pack", Label = "Gold Pack", Short = "Gold"},
			{Type = "Bolts", Amount = 220, Label = "Bolts", Short = "220"},
			{Type = "Coins", Amount = 13000, Label = "Coins", Short = "13,000"},
			{Type = "Pack", ItemId = "rare_pack", Label = "Rare Pack", Short = "Rare"},
			{Type = "Bolts", Amount = 320, Label = "Bolts", Short = "320"},
			{Type = "Coins", Amount = 22000, Label = "Final Coins", Short = "22,000"},
			{Type = "Pack", ItemId = "elite_pack", Label = "Elite Pack", Short = "Elite"},
		},
	},
	{
		Name = "Campaign Climb Week",
		Subtitle = "Rewards for pushing AI tiers and club progress.",
		Rewards = {
			{Type = "Coins", Amount = 1800, Label = "Coins", Short = "1,800"},
			{Type = "Bolts", Amount = 120, Label = "Bolts", Short = "120"},
			{Type = "Pack", ItemId = "silver_pack", Label = "Silver Pack", Short = "Silver"},
			{Type = "Coins", Amount = 5200, Label = "Coins", Short = "5,200"},
			{Type = "Pack", ItemId = "gold_pack", Label = "Gold Pack", Short = "Gold"},
			{Type = "Bolts", Amount = 230, Label = "Bolts", Short = "230"},
			{Type = "Coins", Amount = 11000, Label = "Milestone Coins", Short = "11,000"},
			{Type = "Pack", ItemId = "rare_pack", Label = "Rare Pack", Short = "Rare"},
			{Type = "Bolts", Amount = 300, Label = "Bolts", Short = "300"},
			{Type = "Coins", Amount = 16500, Label = "Coins", Short = "16,500"},
			{Type = "Pack", ItemId = "gold_pack", Label = "Gold Pack", Short = "Gold"},
			{Type = "Bolts", Amount = 430, Label = "Bolts", Short = "430"},
			{Type = "Coins", Amount = 26000, Label = "Final Coins", Short = "26,000"},
			{Type = "Pack", ItemId = "elite_pack", Label = "Elite Pack", Short = "Elite"},
		},
	},
	{
		Name = "Ranked Prep Week",
		Subtitle = "Upgrade your squad before the seven-win path.",
		Rewards = {
			{Type = "Coins", Amount = 2200, Label = "Coins", Short = "2,200"},
			{Type = "Pack", ItemId = "silver_pack", Label = "Silver Pack", Short = "Silver"},
			{Type = "Bolts", Amount = 180, Label = "Bolts", Short = "180"},
			{Type = "Coins", Amount = 7500, Label = "Coins", Short = "7,500"},
			{Type = "Pack", ItemId = "gold_pack", Label = "Gold Pack", Short = "Gold"},
			{Type = "Bolts", Amount = 280, Label = "Bolts", Short = "280"},
			{Type = "Coins", Amount = 15000, Label = "Milestone Coins", Short = "15,000"},
			{Type = "Pack", ItemId = "rare_pack", Label = "Rare Pack", Short = "Rare"},
			{Type = "Bolts", Amount = 390, Label = "Bolts", Short = "390"},
			{Type = "Coins", Amount = 21000, Label = "Coins", Short = "21,000"},
			{Type = "Pack", ItemId = "gold_pack", Label = "Gold Pack", Short = "Gold"},
			{Type = "Bolts", Amount = 520, Label = "Bolts", Short = "520"},
			{Type = "Coins", Amount = 32000, Label = "Final Coins", Short = "32,000"},
			{Type = "Pack", ItemId = "voltra_pack", Label = "Voltra Pack", Short = "Voltra"},
		},
	},
	{
		Name = "World Cup Week",
		Subtitle = "National stage rewards for the tournament grind.",
		Rewards = {
			{Type = "Coins", Amount = 3000, Label = "Coins", Short = "3,000"},
			{Type = "Pack", ItemId = "gold_pack", Label = "Gold Pack", Short = "Gold"},
			{Type = "Bolts", Amount = 240, Label = "Bolts", Short = "240"},
			{Type = "Coins", Amount = 10500, Label = "Coins", Short = "10,500"},
			{Type = "Pack", ItemId = "rare_pack", Label = "Rare Pack", Short = "Rare"},
			{Type = "Bolts", Amount = 360, Label = "Bolts", Short = "360"},
			{Type = "Coins", Amount = 19000, Label = "Milestone Coins", Short = "19,000"},
			{Type = "Pack", ItemId = "elite_pack", Label = "Elite Pack", Short = "Elite"},
			{Type = "Bolts", Amount = 500, Label = "Bolts", Short = "500"},
			{Type = "Coins", Amount = 28000, Label = "Coins", Short = "28,000"},
			{Type = "Pack", ItemId = "rare_pack", Label = "Rare Pack", Short = "Rare"},
			{Type = "Bolts", Amount = 700, Label = "Bolts", Short = "700"},
			{Type = "Coins", Amount = 42000, Label = "Final Coins", Short = "42,000"},
			{Type = "Pack", ItemId = "voltra_pack", Label = "Voltra Pack", Short = "Voltra"},
		},
	},
}

function Config.WeekIndex(now: number?): number
	local stamp = math.max(0, math.floor(now or os.time()))
	return math.floor(stamp / Config.WeekSeconds)
end

function Config.WeekKey(now: number?): string
	return "week_" .. tostring(Config.WeekIndex(now))
end

function Config.WeekDefinition(now: number?): any
	local index = Config.WeekIndex(now)
	return Config.Weeks[(index % #Config.Weeks) + 1]
end

function Config.DayIndex(now: number?): number
	local stamp = math.max(0, math.floor(now or os.time()))
	return math.floor(stamp / Config.DaySeconds)
end

function Config.SecondsUntilNextDay(now: number?): number
	local stamp = math.max(0, math.floor(now or os.time()))
	return Config.DaySeconds - (stamp % Config.DaySeconds)
end

function Config.SecondsUntilWeekEnd(now: number?): number
	local stamp = math.max(0, math.floor(now or os.time()))
	return Config.WeekSeconds - (stamp % Config.WeekSeconds)
end

return table.freeze(Config)
