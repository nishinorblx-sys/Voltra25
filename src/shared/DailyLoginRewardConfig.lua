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
		Name = "Daily Rewards",
		Subtitle = "Log in each day to build your club.",
		Rewards = {
			{Type = "Coins", Amount = 1000, Label = "Coins", Short = "1,000"},
			{Type = "VoltraPoints", Amount = 250, Label = "Voltra Points", Short = "250"},
			{Type = "Celebration", ItemId = "basic_goal_celebration", Name = "Basic Goal Celebration", Label = "Basic Goal Celebration", Short = "Basic"},
			{Type = "Pack", ItemId = "common_pack", Name = "Common Pack", Label = "Common Pack", Short = "Common"},
			{Type = "Coins", Amount = 2000, Label = "Coins", Short = "2,000"},
			{Type = "Pack", ItemId = "rare_pack", Name = "Rare Pack", Label = "Rare Pack", Short = "Rare"},
			{Type = "RandomPlayer", MinOVR = 75, MaxOVR = 82, Name = "75-82 OVR Random Player", Label = "75-82 OVR Random Player", Short = "75-82"},
			{Type = "Coins", Amount = 3000, Label = "Coins", Short = "3,000"},
			{Type = "VoltraPoints", Amount = 500, Label = "Voltra Points", Short = "500"},
			{Type = "Pack", ItemId = "elite_pack", Name = "Elite Pack", Label = "Elite Pack", Short = "Elite"},
			{Type = "RandomPlayer", MinOVR = 80, MaxOVR = 84, Name = "80-84 OVR Random Player", Label = "80-84 OVR Random Player", Short = "80-84"},
			{Type = "Coins", Amount = 5000, Label = "Coins", Short = "5,000"},
			{Type = "Pack", ItemId = "legendary_pack", Name = "Legendary Pack", Label = "Legendary Pack", Short = "Legendary"},
			{Type = "RandomPlayer", MinOVR = 83, MaxOVR = 88, Name = "83-88 OVR Random Player", Label = "83-88 OVR Random Player", Short = "83-88"},
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
