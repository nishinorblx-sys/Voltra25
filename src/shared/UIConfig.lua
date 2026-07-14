--!strict

local UIConfig = {}

UIConfig.Navigation = {
	{ Id = "Home", Label = "HOME", Icon = "H", Order = 1 },
	{ Id = "UltimateTeam", Label = "SQUAD BUILDER", Icon = "XI", Order = 2 },
	{ Id = "WorldCup", Label = "WORLD CUP", Icon = "WC", Order = 4 },
	{ Id = "Campaign", Label = "ASCENSION", Icon = "A", Order = 5 },
	{ Id = "MyPlayer", Label = "MY PLAYER", Icon = "MP", Order = 5.5 },
	{ Id = "FiveVFive", Label = "PLAY", Icon = "▶︎", Order = 6 },
	{ Id = "Ranked", Label = "RANKED", Icon = "R", Order = 7 },
	{ Id = "Inventory", Label = "INVENTORY", Icon = "I", Order = 8 },
	{ Id = "Store", Label = "STORE", Icon = "S", Order = 9 },
}

UIConfig.Home = {
	Kicker = "VTR LITE",
	Subtitle = "Develop your club through Ascension, then take it into Ranked.",
	Featured = {
		Tag = "CLUB DEVELOPMENT",
		Title = "VOLTRA\nASCENSION",
		Description = "Earn promotion, develop a favorite player, and scout the signing your squad needs.",
		Action = "CONTINUE ASCENSION",
		Target = "Campaign",
	},
}

UIConfig.Pages = {
	UltimateTeam = { Kicker = "VTR LITE SQUAD", Title = "SQUAD BUILDER", Subtitle = "Formation, tactics, bench, reserves and player instructions." },
	Inventory = { Kicker = "YOUR COLLECTION", Title = "INVENTORY", Subtitle = "Packs, owned players and club items." },
	Store = { Kicker = "VOLTRA MARKET", Title = "STORE", Subtitle = "Buy coins with Robux placeholders, then spend coins on sealed player packs." },
	WorldCup = { Kicker = "NATIONAL STAGE", Title = "WORLD CUP", Subtitle = "Pick a nation, draw groups, qualify, and chase the trophy." },
	Campaign = { Kicker = "CLUB DEVELOPMENT", Title = "VOLTRA ASCENSION", Subtitle = "Earn promotion, develop a favorite player, and build a club worth taking into Ranked." },
	MyPlayer = { Kicker = "PLAY MODE", Title = "MY PLAYER", Subtitle = "Build your Voltra footballer for online PLAY lobbies." },
	FiveVFive = { Kicker = "ONLINE MODE", Title = "5V5", Subtitle = "Queue ten players, teleport together, and play assigned 70 OVR outfield slots with AI goalkeepers." },
	Ranked = { Kicker = "7-WIN TOURNAMENT", Title = "RANKED", Subtitle = "Enter with your current squad. Seven wins earns a Mythic Pack; three losses ends the run." },
}

UIConfig.PlayModes = {
	{ Title = "ACADEMY CIRCUIT", Description = "Begin your deterministic club-development path.", Tag = "DIVISION 1", Target = "Campaign" },
	{ Title = "VOLTRA MASTERS", Description = "Win the summit division and unlock Mastery Contracts.", Tag = "DIVISION 6", Target = "Campaign" },
}

return table.freeze(UIConfig)
