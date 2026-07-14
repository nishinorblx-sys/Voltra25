--!strict

local PlayabilityUnlockConfig = {}

local ALWAYS_AVAILABLE = {
	Home = true,
	WorldCup = true,
	Settings = true,
}

local TWO_MATCH_ROUTES = {
	UltimateTeam = true,
	Inventory = true,
}

local THREE_MATCH_ROUTES = {
	Campaign = true,
	Store = true,
}

local WORLD_CUP_ROUTES = {
	Ranked = true,
	MyPlayer = true,
	FiveVFive = true,
	Clubs = true,
	Career = true,
}

local function state(progression: any): (boolean, number, boolean)
	if type(progression) ~= "table" then return true, 3, true end
	local progress = if type(progression.PlayabilityProgress) == "table" then progression.PlayabilityProgress else progression
	if type(progress) ~= "table" then return true, 3, true end
	local legacy = progress.LegacyAccessGranted == true
	local completed = math.max(0, math.floor(tonumber(progress.CompletedMatches) or 0))
	local worldCupComplete = legacy or progress.FirstWorldCupRunCompleted == true
	return legacy, completed, worldCupComplete
end

function PlayabilityUnlockConfig.RouteUnlocked(progression: any, route: string): boolean
	if ALWAYS_AVAILABLE[route] then return true end
	local legacy, completed, worldCupComplete = state(progression)
	if legacy then return true end
	if TWO_MATCH_ROUTES[route] then return completed >= 2 end
	if THREE_MATCH_ROUTES[route] then return completed >= 3 end
	if WORLD_CUP_ROUTES[route] then return worldCupComplete end
	return worldCupComplete
end

function PlayabilityUnlockConfig.FeatureUnlocked(progression: any, feature: string): boolean
	local legacy, completed, worldCupComplete = state(progression)
	if legacy then return true end
	if feature == "PlayerDetails" or feature == "FirstReward" then return completed >= 1 end
	if feature == "Squad" or feature == "Inventory" then return completed >= 2 end
	if feature == "Packs" or feature == "Chemistry" or feature == "Ascension" then return completed >= 3 end
	if feature == "Ranked" or feature == "AdvancedCompetitiveSettings" then return worldCupComplete end
	return worldCupComplete
end

function PlayabilityUnlockConfig.ClientSummary(progression: any): any
	local legacy, completed, worldCupComplete = state(progression)
	return {
		CompletedMatches = completed,
		LegacyAccess = legacy,
		FirstReward = legacy or completed >= 1,
		Squad = legacy or completed >= 2,
		Inventory = legacy or completed >= 2,
		Packs = legacy or completed >= 3,
		Chemistry = legacy or completed >= 3,
		Ascension = legacy or completed >= 3,
		Ranked = worldCupComplete,
		AdvancedCompetitiveSettings = worldCupComplete,
	}
end

function PlayabilityUnlockConfig.RouteRequirement(route: string): string
	if TWO_MATCH_ROUTES[route] then return "Complete two World Cup matches to unlock this section." end
	if THREE_MATCH_ROUTES[route] then return "Complete three World Cup matches to unlock this section." end
	if WORLD_CUP_ROUTES[route] then return "Complete your opening World Cup run to unlock this section." end
	return "Keep playing your opening World Cup run to unlock this section."
end

return table.freeze(PlayabilityUnlockConfig)
