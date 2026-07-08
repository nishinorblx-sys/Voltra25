--!strict

local UIConfig = {}

UIConfig.Navigation = {
	{ Id = "Home", Label = "HOME", Icon = "H", Order = 1 },
	{ Id = "UltimateTeam", Label = "SQUAD BUILDER", Icon = "XI", Order = 2 },
	{ Id = "WorldCup", Label = "WORLD CUP", Icon = "WC", Order = 4 },
	{ Id = "Play", Label = "CAMPAIGN", Icon = "C", Order = 5 },
	{ Id = "Ranked", Label = "RANKED", Icon = "R", Order = 6 },
	{ Id = "Inventory", Label = "INVENTORY", Icon = "I", Order = 7 },
	{ Id = "Store", Label = "STORE", Icon = "S", Order = 8 },
}

UIConfig.Home = {
	Kicker = "VTR LITE",
	Subtitle = "Play AI, earn packs, improve your squad, then chase the 7-win Mythic run.",
	Featured = {
		Tag = "CORE LOOP",
		Title = "CAMPAIGN\nROAD",
		Description = "Beat AI squads, win packs, upgrade your XI and enter Ranked when your club is ready.",
		Action = "CONTINUE CAMPAIGN",
		Target = "Play",
	},
}

UIConfig.Pages = {
	UltimateTeam = { Kicker = "VTR LITE SQUAD", Title = "SQUAD BUILDER", Subtitle = "Formation, tactics, bench, reserves and player instructions." },
	Inventory = { Kicker = "YOUR COLLECTION", Title = "INVENTORY", Subtitle = "Packs, owned players and club items." },
	Store = { Kicker = "VOLTRA MARKET", Title = "STORE", Subtitle = "Buy coins with Robux placeholders, then spend coins on sealed player packs." },
	WorldCup = { Kicker = "NATIONAL STAGE", Title = "WORLD CUP", Subtitle = "Pick a nation, draw groups, qualify, and chase the trophy." },
	Play = { Kicker = "OFFLINE CAMPAIGN", Title = "CAMPAIGN", Subtitle = "Seven difficulty ladders. Five squads each. Win packs and unlock the next tier." },
	Ranked = { Kicker = "7-WIN TOURNAMENT", Title = "RANKED", Subtitle = "Enter with your current squad. Seven wins earns a Mythic Pack; three losses ends the run." },
}

UIConfig.PlayModes = {
	{ Title = "STREET LEVEL", Description = "AI squads 55-62 OVR. Reward: Bronze Pack.", Tag = "TIER 1", Target = "Play" },
	{ Title = "VOLTRA MASTERS", Description = "AI squads 91-95 OVR. Reward: Icon Pack.", Tag = "TIER 7", Target = "Play" },
}

return table.freeze(UIConfig)
