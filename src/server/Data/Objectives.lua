--!strict

return {
	{
		objectiveId = "build_first_xi", groupId = "starter_journey", sortOrder = 1,
		title = "BUILD FIRST XI", description = "Fill all 11 starting squad positions",
		progress = 0, target = 11, reward = { Type = "XP", Amount = 250 },
		status = "locked", nextObjectiveId = "open_first_pack", cadence = "Starter",
	},
	{
		objectiveId = "open_first_pack", groupId = "starter_journey", sortOrder = 2,
		title = "OPEN FIRST PACK", description = "Open your first VTR player pack",
		progress = 0, target = 1, reward = { Type = "Coins", Amount = 500 },
		status = "locked", nextObjectiveId = "upgrade_squad_rating", cadence = "Starter",
	},
	{
		objectiveId = "upgrade_squad_rating", groupId = "starter_journey", sortOrder = 3,
		title = "UPGRADE SQUAD RATING", description = "Reach a squad rating of 75",
		progress = 0, target = 75, reward = { Type = "XP", Amount = 500 },
		status = "locked", nextObjectiveId = "play_first_match_placeholder", cadence = "Starter",
	},
	{
		objectiveId = "play_first_match_placeholder", groupId = "starter_journey", sortOrder = 4,
		title = "PLAY YOUR FIRST MATCH", description = "Reach the server-validated temporary match scene",
		progress = 0, target = 1, reward = { Type = "Pack", Amount = 1, ItemId = "voltage_standard" },
		status = "locked", nextObjectiveId = "claim_daily_reward", cadence = "Starter",
	},
	{
		objectiveId = "claim_daily_reward", groupId = "starter_journey", sortOrder = 5,
		title = "CLAIM DAILY REWARD", description = "Claim a reward from the daily inbox",
		progress = 0, target = 1, reward = { Type = "Bolts", Amount = 50 },
		status = "locked", nextObjectiveId = nil, cadence = "Starter",
	},
	{
		objectiveId = "daily_visit_store", groupId = "daily", sortOrder = 1,
		title = "EXPLORE THE STORE", description = "View any store category",
		progress = 0, target = 1, reward = { Type = "Coins", Amount = 300 },
		status = "locked", nextObjectiveId = nil, cadence = "Daily",
	},
	{
		objectiveId = "weekly_customize_club", groupId = "weekly", sortOrder = 1,
		title = "MAKE IT YOURS", description = "Equip a club kit and stadium",
		progress = 0, target = 2, reward = { Type = "Pack", Amount = 1, ItemId = "voltage_standard" },
		status = "locked", nextObjectiveId = nil, cadence = "Weekly",
	},
	{
		objectiveId = "milestone_level_5", groupId = "milestone", sortOrder = 1,
		title = "FIRST SURGE", description = "Reach account level 5",
		progress = 1, target = 5, reward = { Type = "Bolts", Amount = 150 },
		status = "locked", nextObjectiveId = nil, cadence = "Milestone",
	},
	{
		objectiveId="welcome_loan_player",groupId="loan_trials",sortOrder=1,title="WELCOME LOAN",description="Claim a five-match loan player for your first competitive squad",
		progress=1,target=1,reward={Type="LoanPlayer",Amount=1,Matches=5,Pool="Silver"},status="locked",nextObjectiveId=nil,cadence="Loan",
	},
	{
		objectiveId="daily_complete_passes",groupId="daily",sortOrder=2,title="KEEP THE CURRENT",description="Complete 25 passes across matches",
		progress=0,target=25,reward={Type="Consumable",Amount=1,ItemId="stamina_boost"},status="locked",nextObjectiveId=nil,cadence="Daily",
	},
	{
		objectiveId="weekly_score_goals",groupId="weekly",sortOrder=2,title="VOLTAGE FINISHER",description="Score 10 goals this week",
		progress=0,target=10,reward={Type="Pack",Amount=1,ItemId="gold_pack"},status="locked",nextObjectiveId=nil,cadence="Weekly",
	},
}
