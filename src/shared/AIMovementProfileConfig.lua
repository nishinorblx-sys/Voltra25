--!strict
local Config = {}

Config.Default = "Balanced"
Config.Order = {"Balanced", "ComeShort", "GetInBehind", "StayWide", "FreeRoam", "StayBack", "AggressivePress", "RecoveryRunner"}
Config.Profiles = {
	Balanced = {Name = "BALANCED", Description = "Keeps the player's natural role and team shape."},
	ComeShort = {Name = "COME SHORT", Description = "Checks toward the ball to offer a safer passing lane."},
	GetInBehind = {Name = "GET IN BEHIND", Description = "Attacks space behind the defensive line with committed runs."},
	StayWide = {Name = "STAY WIDE", Description = "Holds the touchline to stretch the opposition shape."},
	FreeRoam = {Name = "FREE ROAM", Description = "Moves between nearby lanes to become available."},
	StayBack = {Name = "STAY BACK", Description = "Protects the team's rest defense during attacks."},
	AggressivePress = {Name = "AGGRESSIVE PRESS", Description = "Closes the ball quickly when the team loses possession."},
	RecoveryRunner = {Name = "RECOVERY RUNNER", Description = "Prioritizes sprinting back into the defensive block."},
}

function Config.IsValid(value: any): boolean
	return type(value) == "string" and Config.Profiles[value] ~= nil
end

return table.freeze(Config)
