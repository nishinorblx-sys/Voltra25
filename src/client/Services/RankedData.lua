--!strict
local Factory = require(script.Parent.MockModeService)

return Factory.new({
	Id = "Ranked",
	Kicker = "7-GAME PATH",
	Title = "RANKED RUN",
	Subtitle = "Enter with your current squad. Your seven-game record decides the path reward.",
	Tabs = {
		{
			Id = "Run",
			Label = "TOURNAMENT",
			Description = "Current seven-game path",
			Cards = {
				{ Title = "7-GAME PATH", Subtitle = "0 / 7 GAMES", Meta = "FINAL RECORD DECIDES REWARD", Accent = true, Action = { Label = "ENTER MATCH", Operation = "RankedQueue", Loading = true } },
				{ Title = "NEXT OPPONENT", Subtitle = "AI TOURNAMENT SQUAD", Meta = "ONLINE 1V1 SLOT READY FOR LATER", Action = { Label = "PREVIEW", Operation = "Toast", Message = "Opponent preview will show squad, tactics and star player." } },
			},
		},
		{
			Id = "Rewards",
			Label = "REWARDS",
			Description = "Reward improves with your seven-game record",
			Cards = {
				{ Title = "1+ WINS", Subtitle = "BRONZE PACK", Meta = "PATH REWARD", Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "3+ WINS", Subtitle = "GOLD PACK", Meta = "PATH REWARD", Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "5+ WINS", Subtitle = "ELITE PACK", Meta = "PATH REWARD", Accent = true, Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "7-0 RECORD", Subtitle = "MYTHIC PACK", Meta = "PERFECT PATH", Accent = true, Action = { Label = "CLAIM WHEN COMPLETE", Operation = "Toast", Message = "Finish all 7 path games to claim the record-based reward." } },
			},
		},
		{
			Id = "History",
			Label = "HISTORY",
			Description = "Completed tournament runs",
			Cards = {},
		},
	},
})
