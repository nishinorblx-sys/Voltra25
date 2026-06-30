--!strict

local Config = {}

Config.CampaignDifficulties = {
	{ Id = "street_level", Name = "Street Level", Range = {55, 62}, Reward = "Bronze Pack", PackId = "bronze_pack" },
	{ Id = "local_league", Name = "Local League", Range = {63, 68}, Reward = "Silver Pack", PackId = "silver_pack" },
	{ Id = "regional_pro", Name = "Regional Pro", Range = {69, 74}, Reward = "Gold Pack", PackId = "gold_pack" },
	{ Id = "national_class", Name = "National Class", Range = {75, 80}, Reward = "Rare Pack", PackId = "rare_pack" },
	{ Id = "continental_elite", Name = "Continental Elite", Range = {81, 85}, Reward = "Elite Pack", PackId = "elite_pack" },
	{ Id = "world_class", Name = "World Class", Range = {86, 90}, Reward = "Legendary Pack", PackId = "legendary_pack" },
	{ Id = "voltra_masters", Name = "Voltra Masters", Range = {91, 95}, Reward = "Icon Pack", PackId = "icon_pack" },
}

Config.RankedRewards = {
	[0] = "No Pack",
	[1] = "Bronze Pack",
	[2] = "Silver Pack",
	[3] = "Gold Pack",
	[4] = "Rare Pack",
	[5] = "Elite Pack",
	[6] = "Legendary Pack",
	[7] = "Mythic Pack",
}

Config.TacticPresets = {
	Balanced = {50, 50, 50, 50, 50, 45, 45, 45, 45, 35, 45, 45},
	Possession = {28, 22, 48, 42, 45, 35, 18, 35, 18, 12, 28, 24},
	["Counter Attack"] = {74, 78, 58, 42, 42, 38, 88, 48, 32, 34, 52, 62},
	["High Press"] = {62, 58, 55, 62, 76, 88, 58, 56, 44, 36, 58, 68},
	["Park The Bus"] = {18, 22, 28, 24, 14, 16, 28, 10, 12, 10, 18, 18},
	["Wing Play"] = {56, 50, 86, 54, 48, 48, 48, 82, 88, 28, 56, 48},
	["Direct Long Ball"] = {86, 92, 62, 48, 46, 44, 76, 32, 58, 46, 40, 70},
	["Tiki Taka"] = {34, 12, 44, 38, 52, 42, 18, 34, 12, 12, 26, 26},
	Gegenpress = {72, 62, 60, 64, 82, 94, 72, 66, 48, 42, 66, 78},
	["Low Block"] = {22, 28, 32, 22, 18, 20, 58, 16, 18, 18, 24, 26},
}

Config.TacticSliderNames = {
	"BuildUpSpeed", "PassingDirectness", "AttackingWidth", "DefensiveWidth",
	"DefensiveDepth", "PressingIntensity", "CounterAttackFrequency", "OverlapFrequency",
	"CrossingFrequency", "LongShotFrequency", "DribblingFreedom", "RiskLevel",
	"SupportDistance", "PassTempo", "ForwardPassPriority", "BackPassSafety",
	"SwitchPlayFrequency", "ThroughBallFrequency", "PassRisk", "FirstTouchDirectness",
	"ReceiverTrapAggression", "RunsInBehind", "UnderlapFrequency", "BoxRuns",
	"CutbackFrequency", "FinalThirdPatience", "ShotPatience", "OneTouchPassing",
	"WidthDiscipline", "FullbackAttack", "MidfieldRotation", "CreativeFreedom",
	"PressTriggerDistance", "CounterPress", "TackleAggression", "InterceptionRisk",
	"MarkingTightness", "LaneBlocking", "BackLineCompactness", "BoxProtection",
	"ZoneDiscipline", "LooseBallAggression", "RecoveryRuns", "SprintConservation",
	"KeeperAggression", "KeeperDistributionRisk", "ShortGKDistribution", "LongGKDistribution",
	"FreeKickShortPass", "FreeKickLongPass", "CornerNearPost", "CornerFarPost",
	"SetPiecePatience", "ClearanceHeight", "StaminaPressLimit", "DefensiveLineStepUp",
}

Config.PositionInstructions = {
	GK = {"Stay Back", "Sweeper Keeper", "Short Distribution", "Long Distribution", "Come For Crosses", "Stay On Line"},
	CB = {"Stay Back", "Step Up", "Aggressive Interceptions", "Conservative Interceptions", "Ball Playing Defender", "Cover Center"},
	FB = {"Stay Back", "Balanced", "Join Attack", "Overlap", "Underlap", "Inverted", "Conservative Defending", "Aggressive Press"},
	CDM = {"Stay Back", "Balanced", "Drop Between Defenders", "Cover Center", "Cover Wing", "Cut Passing Lanes", "Man Mark", "Deep Playmaker"},
	CM = {"Stay Back", "Balanced", "Get Forward", "Free Roam", "Cover Center", "Cover Wing", "Late Runs Into Box", "Support Wide"},
	CAM = {"Stay Forward", "Come Back On Defense", "Free Roam", "Get Into Box", "Stay On Edge", "Create Chances", "Press Back Line"},
	W = {"Stay Wide", "Cut Inside", "Come Short", "Get In Behind", "Come Back On Defense", "Get Into Box", "Free Roam"},
	ST = {"Stay Central", "Drift Wide", "Get In Behind", "Target Man", "False 9", "Press Back Line", "Stay Forward", "Come Back On Defense"},
}

function Config.DefaultTactics(): any
	local values = {}
	for index, name in Config.TacticSliderNames do
		values[name] = Config.TacticPresets.Balanced[index] or 50
	end
	return { Identity = "Balanced", Sliders = values }
end

return table.freeze(Config)
