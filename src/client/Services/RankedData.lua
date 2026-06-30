--!strict
local Factory = require(script.Parent.MockModeService)

return Factory.new({
	Id = "Ranked",
	Kicker = "7-WIN TOURNAMENT",
	Title = "RANKED RUN",
	Subtitle = "Enter with your current squad. Seven wins earns a Mythic Pack; three losses ends the run.",
	Tabs = {
		{
			Id = "Run",
			Label = "TOURNAMENT",
			Description = "Current run progress",
			Cards = {
				{ Title = "7-WIN PATH", Subtitle = "0 WINS / 0 LOSSES", Meta = "ENDS AT 3 LOSSES", Accent = true, Action = { Label = "ENTER MATCH", Operation = "RankedQueue", Loading = true } },
				{ Title = "NEXT OPPONENT", Subtitle = "AI TOURNAMENT SQUAD", Meta = "ONLINE 1V1 SLOT READY FOR LATER", Action = { Label = "PREVIEW", Operation = "Toast", Message = "Opponent preview will show squad, tactics and star player." } },
			},
		},
		{
			Id = "Rewards",
			Label = "REWARDS",
			Description = "Reward improves with each win",
			Cards = {
				{ Title = "1 WIN", Subtitle = "BRONZE PACK", Meta = "RUN REWARD", Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "3 WINS", Subtitle = "GOLD PACK", Meta = "RUN REWARD", Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "5 WINS", Subtitle = "ELITE PACK", Meta = "RUN REWARD", Accent = true, Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "7 WINS", Subtitle = "MYTHIC PACK", Meta = "PERFECT RUN", Accent = true, Action = { Label = "CLAIM WHEN COMPLETE", Operation = "Toast", Message = "Finish a 7-win run to claim the Mythic Pack." } },
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
