--!strict

local Config = {}

Config.DataVersion = 1
Config.ProfileMigrationVersion = 1
Config.LeagueFixtureCount = 7
Config.PromotionThreshold = 12
Config.RecoveryFixtureCount = 3
Config.RecoveryThreshold = 6
Config.MaximumPromotionAttempts = 3
Config.RecoveryRewardModifier = 0.7
Config.HistoryLimit = 20
Config.PendingMatchLifetime = 20 * 60
Config.PendingMatchStaleAfter = 35 * 60
Config.Manager = {
	QualifiedModifier = 0.85,
	PassiveModifier = 0.4,
	RequiredInteractions = 2,
	RequiresSecondHalfInteraction = true,
	Mentalities = { "Balanced", "Attack", "Defend", "High Press", "Counter Attack" },
	Formations = { "4-3-3", "4-2-3-1", "4-4-2", "3-5-2", "5-3-2" },
}

Config.Divisions = {
	{
		Id = "academy_circuit", Name = "ACADEMY CIRCUIT", Index = 1, Accent = Color3.fromHex("8D989E"), MinOverall = 50, MaxOverall = 62,
		Difficulty = "Beginner", MatchLength = 3, ScoutingMin = 60, ScoutingMax = 66, ScoutingChoices = 3,
		Rewards = { Loss = { Coins = 350, XP = 70 }, Draw = { Coins = 500, XP = 90 }, Win = { Coins = 700, XP = 120 } },
		ObjectiveCoins = 100, StarCoins = 1200, PackId = "bronze_pack", BadgeId = "ascension_academy_badge", PerfectCosmeticId = "ascension_academy_perfect",
	},
	{
		Id = "street_league", Name = "STREET LEAGUE", Index = 2, Accent = Color3.fromHex("B77742"), MinOverall = 60, MaxOverall = 69,
		Difficulty = "Amateur", MatchLength = 3, ScoutingMin = 66, ScoutingMax = 71, ScoutingChoices = 3,
		Rewards = { Loss = { Coins = 450, XP = 80 }, Draw = { Coins = 650, XP = 105 }, Win = { Coins = 900, XP = 140 } },
		ObjectiveCoins = 140, StarCoins = 1800, PackId = "silver_pack", BadgeId = "ascension_street_badge", PerfectCosmeticId = "ascension_street_perfect",
	},
	{
		Id = "city_championship", Name = "CITY CHAMPIONSHIP", Index = 3, Accent = Color3.fromHex("C9D2D9"), MinOverall = 68, MaxOverall = 76,
		Difficulty = "Semi Pro", MatchLength = 4, ScoutingMin = 72, ScoutingMax = 76, ScoutingChoices = 3,
		Rewards = { Loss = { Coins = 550, XP = 90 }, Draw = { Coins = 800, XP = 120 }, Win = { Coins = 1100, XP = 160 } },
		ObjectiveCoins = 180, StarCoins = 2500, PackId = "gold_pack", BadgeId = "ascension_city_badge", PerfectCosmeticId = "ascension_city_perfect",
	},
	{
		Id = "national_division", Name = "NATIONAL DIVISION", Index = 4, Accent = Color3.fromHex("E3B84D"), MinOverall = 75, MaxOverall = 83,
		Difficulty = "Professional", MatchLength = 4, ScoutingMin = 77, ScoutingMax = 81, ScoutingChoices = 4,
		Rewards = { Loss = { Coins = 700, XP = 105 }, Draw = { Coins = 1000, XP = 145 }, Win = { Coins = 1400, XP = 190 } },
		ObjectiveCoins = 220, StarCoins = 3400, PackId = "rare_pack", BadgeId = "ascension_national_badge", PerfectCosmeticId = "ascension_national_perfect",
	},
	{
		Id = "continental_elite", Name = "CONTINENTAL ELITE", Index = 5, Accent = Color3.fromHex("A58AC7"), MinOverall = 82, MaxOverall = 90,
		Difficulty = "World Class", MatchLength = 6, ScoutingMin = 82, ScoutingMax = 86, ScoutingChoices = 4,
		Rewards = { Loss = { Coins = 900, XP = 120 }, Draw = { Coins = 1250, XP = 165 }, Win = { Coins = 1750, XP = 220 } },
		ObjectiveCoins = 260, StarCoins = 4500, PackId = "elite_pack", BadgeId = "ascension_continental_badge", PerfectCosmeticId = "ascension_continental_perfect",
	},
	{
		Id = "voltra_masters", Name = "VOLTRA MASTERS", Index = 6, Accent = Color3.fromHex("F0E3AE"), MinOverall = 89, MaxOverall = 99,
		Difficulty = "Ultimate", MatchLength = 6, ScoutingMin = 87, ScoutingMax = 90, ScoutingChoices = 5,
		Rewards = { Loss = { Coins = 1150, XP = 140 }, Draw = { Coins = 1600, XP = 190 }, Win = { Coins = 2200, XP = 260 } },
		ObjectiveCoins = 300, StarCoins = 6000, PackId = "voltra_pack", BadgeId = "ascension_masters_badge", PerfectCosmeticId = "ascension_masters_perfect",
	},
}

Config.DivisionOrder = {}
Config.DivisionById = {}
for _, division in Config.Divisions do
	Config.DivisionOrder[division.Index] = division.Id
	Config.DivisionById[division.Id] = division
end

Config.LegacyTierMapping = {
	[1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3, [6] = 3,
	[7] = 4, [8] = 4, [9] = 5, [10] = 5, [11] = 6, [12] = 6,
}

Config.PlacementBands = {
	{ Maximum = 62, Division = 1 },
	{ Maximum = 69, Division = 2 },
	{ Maximum = 76, Division = 3 },
	{ Maximum = 83, Division = 4 },
	{ Maximum = 89, Division = 5 },
	{ Maximum = 99, Division = 6 },
}

Config.ScoutingFocuses = {
	Goalkeeper = { "GK" },
	Defender = { "CB", "LB", "RB", "LWB", "RWB" },
	Midfielder = { "CDM", "CM", "CAM", "LM", "RM" },
	Winger = { "LW", "RW", "LM", "RM" },
	Striker = { "ST", "CF" },
	["Any Position"] = { "GK", "CB", "LB", "RB", "LWB", "RWB", "CDM", "CM", "CAM", "LM", "RM", "LW", "RW", "ST", "CF" },
}
Config.ScoutingFocusOrder = { "Goalkeeper", "Defender", "Midfielder", "Winger", "Striker", "Any Position" }

Config.TacticalIdentities = {
	high_press = { Id = "high_press", Name = "HIGH PRESS", Formation = "4-3-3", Preset = "High Press", Strength = "Forces rushed decisions high up the pitch.", Weakness = "Space appears behind the first press.", CounterTactic = "Counter Attack", Objectives = { "completed_passes", "goals", "low_fouls" }, Intensity = { PressingIntensity = 70, DefensiveDepth = 64 } },
	low_block = { Id = "low_block", Name = "LOW BLOCK", Formation = "5-3-2", Preset = "Defend", Strength = "Protects the box with a compact shape.", Weakness = "Concedes territory and set pieces.", CounterTactic = "Wing Play", Objectives = { "shots_on_target", "corners", "possession" }, Intensity = { DefensiveDepth = 28, DefensiveWidth = 42 } },
	counter_attack = { Id = "counter_attack", Name = "COUNTER ATTACK", Formation = "4-2-3-1", Preset = "Counter Attack", Strength = "Breaks quickly after winning possession.", Weakness = "Can be pinned back by patient circulation.", CounterTactic = "Possession", Objectives = { "completed_passes", "low_fouls", "max_conceded" }, Intensity = { CounterAttackFrequency = 72, PassingDirectness = 66 } },
	wing_play = { Id = "wing_play", Name = "WING PLAY", Formation = "4-4-2", Preset = "Attack", Strength = "Overloads wide areas and attacks crosses.", Weakness = "Leaves gaps between fullbacks and midfield.", CounterTactic = "High Press", Objectives = { "tackles_won", "goals", "clean_sheet" }, Intensity = { AttackingWidth = 72, CrossingFrequency = 72 } },
	possession = { Id = "possession", Name = "POSSESSION", Formation = "4-2-3-1", Preset = "Balanced", Strength = "Controls tempo through short passing.", Weakness = "Vulnerable to direct transitions.", CounterTactic = "Counter Attack", Objectives = { "tackles_won", "shots_on_target", "goal_difference" }, Intensity = { PassingDirectness = 28, BuildUpSpeed = 38 } },
	direct_long_ball = { Id = "direct_long_ball", Name = "DIRECT LONG BALL", Formation = "4-4-2", Preset = "Attack", Strength = "Moves the ball forward before the defense settles.", Weakness = "Can surrender possession under pressure.", CounterTactic = "High Press", Objectives = { "possession", "completed_passes", "clean_sheet" }, Intensity = { PassingDirectness = 78, BuildUpSpeed = 66 } },
	balanced_rival = { Id = "balanced_rival", Name = "BALANCED RIVAL", Formation = "4-3-3", Preset = "Balanced", Strength = "Adapts without exposing an obvious weakness.", Weakness = "A clear tactical commitment can dictate the game.", CounterTactic = "Balanced", Objectives = { "goals", "shots_on_target", "completed_passes", "tackles_won" }, Intensity = {} },
	promotion_boss = { Id = "promotion_boss", Name = "PROMOTION BOSS", Formation = "4-2-3-1", Preset = "High Press", Strength = "Combines elite pressure with disciplined possession.", Weakness = "Its high line can be attacked after turnovers.", CounterTactic = "Counter Attack", Objectives = { "goal_difference", "max_conceded", "shots_on_target" }, Intensity = { PressingIntensity = 68, DefensiveDepth = 62, RiskLevel = 60 } },
}
Config.TacticalIdentityOrder = { "high_press", "low_block", "counter_attack", "wing_play", "possession", "direct_long_ball", "balanced_rival" }

Config.Objectives = {
	completed_passes = { Id = "completed_passes", Title = "CONTROL THE BALL", Description = "Complete 25 passes.", Metric = "PassesCompleted", Target = 25, Modes = { Manual = true, Manage = true } },
	shots_on_target = { Id = "shots_on_target", Title = "TEST THE KEEPER", Description = "Record 4 shots on target.", Metric = "ShotsOnTarget", Target = 4, Modes = { Manual = true, Manage = true } },
	goals = { Id = "goals", Title = "ATTACK WITH PURPOSE", Description = "Score at least 2 goals.", Metric = "Goals", Target = 2, Modes = { Manual = true, Manage = true } },
	tackles_won = { Id = "tackles_won", Title = "WIN IT BACK", Description = "Complete 5 tackles.", Metric = "TacklesCompleted", Target = 5, Modes = { Manual = true, Manage = true } },
	possession = { Id = "possession", Title = "SET THE TEMPO", Description = "Finish with at least 52% possession.", Metric = "Possession", Target = 52, Modes = { Manual = true, Manage = true } },
	clean_sheet = { Id = "clean_sheet", Title = "SHUT THEM OUT", Description = "Keep a clean sheet.", Metric = "GoalsConcededMaximum", Target = 0, Modes = { Manual = true, Manage = true } },
	max_conceded = { Id = "max_conceded", Title = "STAY COMPACT", Description = "Concede no more than 1 goal.", Metric = "GoalsConcededMaximum", Target = 1, Modes = { Manual = true, Manage = true } },
	corners = { Id = "corners", Title = "FORCE THE ISSUE", Description = "Win at least 3 corners.", Metric = "Corners", Target = 3, Modes = { Manual = true, Manage = true } },
	low_fouls = { Id = "low_fouls", Title = "CONTROLLED AGGRESSION", Description = "Commit no more than 2 fouls.", Metric = "FoulsMaximum", Target = 2, Modes = { Manual = true, Manage = true } },
	goal_difference = { Id = "goal_difference", Title = "MAKE A STATEMENT", Description = "Win by at least 2 goals.", Metric = "GoalDifference", Target = 2, Modes = { Manual = true, Manage = true } },
	project_goal = { Id = "project_goal", Title = "PROJECT FINISH", Description = "Score with your Club Project player.", Metric = "ProjectGoals", Target = 1, Modes = { Manual = true } },
	project_assist = { Id = "project_assist", Title = "PROJECT CREATOR", Description = "Assist with your Club Project player.", Metric = "ProjectAssists", Target = 1, Modes = { Manual = true } },
	project_rating = { Id = "project_rating", Title = "PROJECT LEADER", Description = "Earn a 7.5 match rating with your Club Project player.", Metric = "ProjectRating", Target = 7.5, Modes = { Manual = true, Manage = true } },
	manager_changes = { Id = "manager_changes", Title = "ACTIVE MANAGER", Description = "Apply 3 valid tactical changes.", Metric = "ManagerTacticalChanges", Target = 3, Modes = { Manage = true } },
	manager_substitution = { Id = "manager_substitution", Title = "CHANGE THE GAME", Description = "Make a valid substitution.", Metric = "ManagerSubstitutions", Target = 1, Modes = { Manage = true } },
	second_half_improvement = { Id = "second_half_improvement", Title = "HALFTIME RESPONSE", Description = "Improve the result after halftime.", Metric = "SecondHalfImprovement", Target = 1, Modes = { Manage = true } },
	win_after_mentality = { Id = "win_after_mentality", Title = "TACTICAL TURN", Description = "Win after changing mentality.", Metric = "WinAfterMentalityChange", Target = 1, Modes = { Manage = true } },
}
Config.ManagerObjectivePool = { "manager_changes", "manager_substitution", "second_half_improvement", "win_after_mentality" }

Config.StarMilestones = {
	[4] = { Type = "Coins" },
	[8] = { Type = "Consumable", ItemId = "stamina_boost", Amount = 1 },
	[12] = { Type = "Pack" },
	[16] = { Type = "ProjectXP", Amount = 2 },
	[20] = { Type = "ScoutingQuality", Amount = 1 },
	[24] = { Type = "PerfectSeason" },
}
Config.StarMilestoneOrder = { 4, 8, 12, 16, 20, 24 }

Config.Facilities = {
	scouting = { Id = "scouting", Name = "SCOUTING NETWORK", Levels = { [1] = { Cost = 1, Text = "Reveal the exact promotion OVR range." }, [2] = { Cost = 2, Text = "Add one promotion choice, up to five." }, [3] = { Cost = 3, Text = "Unlock one persisted scouting reroll each season." } } },
	academy = { Id = "academy", Name = "ACADEMY", Levels = { [1] = { Cost = 1, Text = "Earn bonus Project XP from style objectives." }, [2] = { Cost = 2, Text = "Unlock secondary positions at 12 Project XP." }, [3] = { Cost = 3, Text = "Unlock the Ascended II Project node." } } },
	tactical_lab = { Id = "tactical_lab", Name = "TACTICAL LAB", Levels = { [1] = { Cost = 1, Text = "Reveal opponent formations." }, [2] = { Cost = 2, Text = "Reveal opponent strengths and weaknesses." }, [3] = { Cost = 3, Text = "Reveal and apply a temporary counter plan." } } },
	club_finance = { Id = "club_finance", Name = "CLUB FINANCE", Levels = { [1] = { Cost = 1, CoinBonus = 0.05, Text = "+5% Campaign coins." }, [2] = { Cost = 2, CoinBonus = 0.10, Text = "+10% Campaign coins." }, [3] = { Cost = 3, CoinBonus = 0.15, Text = "+15% Campaign coins." } } },
	stadium = { Id = "stadium", Name = "STADIUM", Levels = { [1] = { Cost = 1, Text = "Display an Ascension match banner." }, [2] = { Cost = 2, Text = "Add club-color crowd treatment." }, [3] = { Cost = 3, Text = "Unlock a promotion entrance and trophy display." } } },
}
Config.FacilityOrder = { "scouting", "academy", "tactical_lab", "club_finance", "stadium" }

Config.Project = {
	MaximumBaseOverall = 82,
	MaximumEffectiveOverall = 90,
	MaximumOverallBoost = 5,
	ProtectedCardTypes = { Icon = true, Mythic = true, Legendary = true, Limited = true, Champion = true, Storm = true },
	Milestones = { 3, 7, 12, 18, 26 },
	RepeatOverallMilestones = { 34, 44, 56 },
	VisualTiers = { [18] = "AscendedI", [26] = "AscendedII" },
	ValidAddedPositions = {
		GK = {}, CB = { "LB", "RB", "CDM" }, LB = { "LWB", "CB", "LM" }, RB = { "RWB", "CB", "RM" },
		LWB = { "LB", "LM" }, RWB = { "RB", "RM" }, CDM = { "CM", "CB" }, CM = { "CDM", "CAM", "LM", "RM" },
		CAM = { "CM", "CF", "LW", "RW" }, LM = { "LW", "CM", "LWB" }, RM = { "RW", "CM", "RWB" },
		LW = { "LM", "RW", "ST", "CF" }, RW = { "RM", "LW", "ST", "CF" }, ST = { "CF", "LW", "RW" }, CF = { "ST", "CAM", "LW", "RW" },
	},
	RolePlayStyles = {
		GK = { "Far Reach", "Cross Claimer", "Quick Reflexes", "Long Throw" },
		Defender = { "Anticipate", "Block", "Aerial", "Intercept", "Recovery Defender" },
		Creator = { "Threaded", "Long Switch", "Technical", "Incisive Pass", "First Touch" },
		Attacker = { "Clean Strike", "Quick Release", "Outside the Box", "Explosive Start", "Power Header" },
	},
	AttributePackages = {
		Attacker = {
			{ Id = "attacker_pace_finish", Name = "PACE + FINISHING", Main = { PAC = 2, SHO = 2 }, Detailed = { acceleration = 2, sprintSpeed = 2, finishing = 3 } },
			{ Id = "attacker_shoot_dribble", Name = "SHOOTING + DRIBBLING", Main = { SHO = 2, DRI = 2 }, Detailed = { shotPower = 2, ballControl = 2, dribbling = 2 } },
			{ Id = "attacker_physical_heading", Name = "PHYSICAL + HEADING", Main = { PHY = 2, SHO = 1 }, Detailed = { strength = 2, jumping = 2, headingAccuracy = 3 } },
		},
		Creator = {
			{ Id = "creator_pass_vision", Name = "PASSING + VISION", Main = { PAS = 3 }, Detailed = { shortPassing = 2, longPassing = 2, vision = 3 } },
			{ Id = "creator_dribble_agility", Name = "DRIBBLING + AGILITY", Main = { DRI = 3 }, Detailed = { dribbling = 2, ballControl = 2, agility = 3 } },
			{ Id = "creator_pace_pass", Name = "PACE + PASSING", Main = { PAC = 2, PAS = 2 }, Detailed = { acceleration = 2, shortPassing = 2, vision = 2 } },
		},
		Defender = {
			{ Id = "defender_def_physical", Name = "DEFENDING + PHYSICAL", Main = { DEF = 3, PHY = 2 }, Detailed = { standingTackle = 2, defensiveAwareness = 2, strength = 2 } },
			{ Id = "defender_pace_def", Name = "PACE + DEFENDING", Main = { PAC = 2, DEF = 3 }, Detailed = { sprintSpeed = 2, interceptions = 2, standingTackle = 2 } },
			{ Id = "defender_pass_def", Name = "PASSING + DEFENDING", Main = { PAS = 2, DEF = 3 }, Detailed = { shortPassing = 2, interceptions = 2, defensiveAwareness = 2 } },
		},
		GK = {
			{ Id = "gk_reflex_diving", Name = "REFLEXES + DIVING", Main = { REF = 3, DIV = 2 }, Detailed = { reflexes = 3, diving = 2 } },
			{ Id = "gk_handle_position", Name = "HANDLING + POSITIONING", Main = { HAN = 3, POS = 2 }, Detailed = { handling = 3, positioning = 2 } },
			{ Id = "gk_kick_reflex", Name = "KICKING + REFLEXES", Main = { KIC = 3, REF = 2 }, Detailed = { kicking = 3, reflexes = 2 } },
		},
	},
}

Config.MasteryContracts = {
	youth_revolution = { Id = "youth_revolution", Name = "YOUTH REVOLUTION", Description = "Use a Starting XI averaging age 23 or younger with no card above 86 OVR.", FixtureCount = 3, Rules = { MaximumAverageAge = 23, MaximumOverall = 86 }, Reward = { ProjectXP = 4, FacilityPoints = 1, CosmeticId = "mastery_youth_badge" } },
	national_core = { Id = "national_core", Name = "NATIONAL CORE", Description = "Start at least seven players from one nation.", FixtureCount = 3, Rules = { SameNationStarters = 7 }, Reward = { ItemId = "national_scouting_token", Amount = 1 } },
	no_superstars = { Id = "no_superstars", Name = "NO SUPERSTARS", Description = "Win three matches without top-end special cards.", FixtureCount = 3, Rules = { ExcludeProtectedCardTypes = true, RequiredWins = 3 }, Reward = { ItemId = "ascension_training_token", Amount = 1, Coins = 3500 } },
	tactical_master = { Id = "tactical_master", Name = "TACTICAL MASTER", Description = "Use a different valid formation in every fixture.", FixtureCount = 3, Rules = { UniqueFormations = true }, Reward = { FacilityPoints = 1, CosmeticId = "mastery_tactical_badge" } },
	giant_killer = { Id = "giant_killer", Name = "GIANT KILLER", Description = "Win three matches against opponents rated five to eight OVR above your squad.", FixtureCount = 3, Rules = { OpponentMinimumDelta = 5, OpponentMaximumDelta = 8, RequiredWins = 3 }, Reward = { Coins = 6000, ProjectXP = 4, CosmeticId = "mastery_giant_killer_badge" } },
}
Config.MasteryOrder = { "youth_revolution", "national_core", "no_superstars", "tactical_master", "giant_killer" }

Config.UI = {
	Title = "VOLTRA ASCENSION",
	Subtitle = "BUILD THE CLUB. READ THE MATCH. RISE THROUGH SIX DIVISIONS.",
	NoSquad = "Complete your Ultimate Team Starting XI before entering Ascension.",
	Placement = "One fixture sets your starting division. Your squad OVR and match performance both matter.",
	ProjectSkip = "You can play without a Club Project, but this season will not build permanent card progression.",
	ManagerPassive = "Make two valid changes, including one after halftime, to earn full manager eligibility.",
}

function Config.GetDivision(value: any): any?
	if type(value) == "number" then return Config.Divisions[math.clamp(math.floor(value), 1, #Config.Divisions)] end
	return type(value) == "string" and Config.DivisionById[value] or nil
end

function Config.GetFinanceBonus(level: any): number
	local definition = Config.Facilities.club_finance.Levels[math.clamp(math.floor(tonumber(level) or 0), 0, 3)]
	return definition and definition.CoinBonus or 0
end

function Config.CreateProgress(): any
	local records = {}
	for _, division in Config.Divisions do
		records[division.Id] = {
			SeasonsPlayed = 0, Promotions = 0, Titles = 0, PerfectSeasons = 0,
			BestPoints = 0, BestGoalDifference = -99, LongestUnbeatenRun = 0,
			ManualTitles = 0, ManagerTitles = 0, LegacyCleared = false,
		}
	end
	return {
		Version = Config.DataVersion,
		MigrationVersion = 0,
		UnlockedDifficulty = 1,
		CompletedTeams = {},
		RewardsClaimed = {},
		Legacy = {
			UnlockedDifficulty = 1,
			CompletedTeams = {},
			RewardsClaimed = {},
			HighestClearedLegacyTier = 0,
			MigratedAt = 0,
		},
		Placement = {
			Completed = false,
			Fixture = nil,
			Result = nil,
			AssignedDivision = nil,
			Reason = nil,
			CompletedAt = 0,
		},
		HighestUnlockedDivision = 1,
		ActiveSeason = nil,
		DivisionRecords = records,
		FirstPromotionRewards = {},
		PerfectSeasonRewards = {},
		RepeatPromotionTokens = {},
		Facilities = { scouting = 0, academy = 0, tactical_lab = 0, club_finance = 0, stadium = 0 },
		FacilityPoints = 0,
		FacilityPointsSpent = 0,
		FacilityLedger = {},
		ActiveProject = nil,
		ProjectHistory = {},
		ProjectLifetimeByCard = {},
		CampaignTrainingTokens = 0,
		CampaignTrainingTokenSequence = 0,
		History = {},
		Mastery = { Unlocked = false, WeekKey = "", Active = nil, CompletedWeeks = {}, History = {} },
		ResultLedger = {},
		PendingMatch = nil,
		PendingPresentation = {},
		LegacyHistoryGranted = false,
		AscensionChampion = false,
	}
end

return table.freeze(Config)
