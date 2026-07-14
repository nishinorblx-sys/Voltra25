--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local TeamDatabase = require(script.Parent.Parent.Data.TeamDatabase)

local Generator = {}

local function hash(value: string): number
	local result = 2166136261
	for index = 1, #value do
		result = bit32.bxor(result, string.byte(value, index))
		result = bit32.band(result * 16777619, 0x7fffffff)
	end
	return math.max(1, result)
end

local function rosterValid(teamId: string): boolean
	local roster = TeamDatabase.GetRoster(teamId)
	return roster ~= nil and type(roster.StartingXI) == "table" and #roster.StartingXI >= 11
end

local function candidatePool(division: any, ownTeamId: string?, strongest: boolean?, excluded: any?): { any }
	local result = {}
	for widen = 0, 30, 3 do
		table.clear(result)
		local minimum = division.MinOverall - widen
		local maximum = division.MaxOverall + widen
		if strongest then minimum = math.max(minimum, division.MaxOverall - 3) end
		for _, team in TeamDatabase.Teams do
			if team.teamId ~= ownTeamId and not (excluded and excluded[team.teamId]) and team.overall >= minimum and team.overall <= maximum and rosterValid(team.teamId) then
				table.insert(result, team)
			end
		end
		if #result >= (strongest and 3 or 10) then break end
	end
	table.sort(result, function(a, b)
		if a.overall ~= b.overall then return a.overall < b.overall end
		return a.teamId < b.teamId
	end)
	return result
end

local function rangePool(minimum: number, maximum: number, ownTeamId: string?, excluded: any?): { any }
	local result = {}
	for _, team in TeamDatabase.Teams do
		if team.teamId ~= ownTeamId and not (excluded and excluded[team.teamId]) and team.overall >= minimum and team.overall <= maximum and rosterValid(team.teamId) then
			table.insert(result, team)
		end
	end
	table.sort(result, function(a, b)
		if a.overall ~= b.overall then return a.overall < b.overall end
		return a.teamId < b.teamId
	end)
	return result
end

local function pickIdentity(random: Random, usedIdentity: any, promotion: boolean?): any
	if promotion then return Config.TacticalIdentities.promotion_boss end
	local choices = {}
	for _, identityId in Config.TacticalIdentityOrder do
		if not usedIdentity[identityId] then table.insert(choices, identityId) end
	end
	if #choices == 0 then choices = Config.TacticalIdentityOrder end
	local id = choices[random:NextInteger(1, #choices)]
	usedIdentity[id] = true
	return Config.TacticalIdentities[id]
end

local function objectiveFor(random: Random, identity: any, mode: string?): any
	local pool = mode == "Manage" and Config.ManagerObjectivePool or identity.Objectives
	local valid = {}
	for _, objectiveId in pool do
		local objective = Config.Objectives[objectiveId]
		if objective and objective.Modes[mode or "Manual"] == true then table.insert(valid, objective) end
	end
	if #valid == 0 then
		for _, objectiveId in identity.Objectives do
			local objective = Config.Objectives[objectiveId]
			if objective and objective.Modes[mode or "Manual"] == true then table.insert(valid, objective) end
		end
	end
	if #valid == 0 then return Config.Objectives.completed_passes end
	return valid[random:NextInteger(1, #valid)]
end

local function fixtureFrom(team: any, identity: any, objective: any, seasonId: string, division: any, index: number, kind: string): any
	local star = team.starPlayers and team.starPlayers[1]
	return {
		FixtureId = string.format("%s:%s:%02d", seasonId, kind, index),
		Index = index,
		SeasonId = seasonId,
		DivisionId = division.Id,
		OpponentTeamId = team.teamId,
		OpponentTeamName = team.teamName,
		OpponentOverall = team.overall,
		OpponentCountry = team.country,
		OpponentLeague = team.league,
		Formation = identity.Formation or team.formation,
		TacticIdentity = identity.Id,
		TacticLabel = identity.Name,
		TacticPreset = identity.Preset,
		TacticModifiers = table.clone(identity.Intensity),
		Strength = identity.Strength,
		Weakness = identity.Weakness,
		CounterTactic = identity.CounterTactic,
		StarPlayerId = star and star.playerId or "",
		StarPlayerName = star and star.displayName or "UNKNOWN",
		ObjectiveId = objective.Id,
		ObjectiveTitle = objective.Title,
		ObjectiveDescription = objective.Description,
		ObjectiveMetric = objective.Metric,
		ObjectiveTarget = objective.Target,
		IsPlacement = kind == "placement",
		IsRecovery = kind == "recovery",
		IsPromotionFinal = kind == "final",
		Played = false,
		Result = nil,
		HomeScore = 0,
		AwayScore = 0,
		StarsEarned = {},
		RewardGranted = false,
		Mode = nil,
		MatchId = nil,
		PlayedAt = 0,
	}
end

local function chooseTeams(random: Random, pool: { any }, count: number): { any }
	local selected = {}
	local remaining = table.clone(pool)
	local countries = {}
	local leagues = {}
	while #selected < count and #remaining > 0 do
		local bestIndex = random:NextInteger(1, #remaining)
		for index, team in remaining do
			local best = remaining[bestIndex]
			local score = (countries[team.country] and 0 or 2) + (leagues[team.league] and 0 or 1)
			local bestScore = (countries[best.country] and 0 or 2) + (leagues[best.league] and 0 or 1)
			if score > bestScore then bestIndex = index end
		end
		local team = table.remove(remaining, bestIndex)
		table.insert(selected, team)
		countries[team.country] = true
		leagues[team.league] = true
	end
	return selected
end

function Generator.Seed(userId: number, seasonId: string, divisionId: string): number
	return hash(tostring(userId) .. ":" .. seasonId .. ":" .. divisionId)
end

function Generator.CreateSeason(userId: number, divisionIndex: number, seasonNumber: number, ownTeamId: string?): any?
	local division = Config.GetDivision(divisionIndex)
	if not division then return nil end
	local seasonId = string.format("asc_%d_%s_%d", userId, division.Id, seasonNumber)
	local seed = Generator.Seed(userId, seasonId, division.Id)
	local random = Random.new(seed)
	local pool = candidatePool(division, ownTeamId, false)
	local chosen = chooseTeams(random, pool, Config.LeagueFixtureCount)
	if #chosen ~= Config.LeagueFixtureCount then return nil end
	local usedTeams = {}
	local usedIdentities = {}
	local fixtures = {}
	for index, team in chosen do
		usedTeams[team.teamId] = true
		local identity = pickIdentity(random, usedIdentities, false)
		local objective = objectiveFor(random, identity, nil)
		table.insert(fixtures, fixtureFrom(team, identity, objective, seasonId, division, index, "league"))
	end
	local finalPool = candidatePool(division, ownTeamId, true, usedTeams)
	if #finalPool == 0 then finalPool = candidatePool(division, ownTeamId, false, usedTeams) end
	if #finalPool == 0 then return nil end
	local finalTeam = finalPool[random:NextInteger(math.max(1, math.floor(#finalPool * 0.65)), #finalPool)]
	local finalIdentity = pickIdentity(random, usedIdentities, true)
	local finalObjective = objectiveFor(random, finalIdentity, nil)
	local final = fixtureFrom(finalTeam, finalIdentity, finalObjective, seasonId, division, 8, "final")
	return {
		SeasonId = seasonId, Seed = seed, DivisionId = division.Id, DivisionIndex = division.Index, SeasonNumber = seasonNumber,
		Status = "Preseason", StartedAt = os.time(), UpdatedAt = os.time(), ScoutingFocus = nil, ScoutingLocked = false,
		ScoutingQualityBonus = 0, ScoutingRerollsUsed = 0, Points = 0, Wins = 0, Draws = 0, Losses = 0,
		GoalsFor = 0, GoalsAgainst = 0, LeagueFixtures = fixtures, RecoveryFixtures = {}, PromotionFinal = final,
		CurrentFixtureId = fixtures[1].FixtureId, LeagueFixturesCompleted = 0, RecoveryPoints = 0, PromotionFinalAttempts = 0,
		Stars = 0, ClaimedStarMilestones = {}, PendingProjectUpgrade = nil, PendingPromotionChoice = nil, RewardLedger = {},
		ProjectDecision = nil,
		CompletedAt = 0, Promoted = false, PerfectSeason = false, ManagerMatches = 0, ManualMatches = 0,
	}
end

function Generator.CreatePlacement(userId: number, squadOverall: number, ownTeamId: string?): any?
	local baseIndex = 1
	for _, band in Config.PlacementBands do if squadOverall <= band.Maximum then baseIndex = band.Division break end end
	local division = Config.GetDivision(baseIndex)
	local seed = hash(string.format("placement:%d:%d", userId, squadOverall))
	local random = Random.new(seed)
	local pool = candidatePool({ MinOverall = math.max(45, squadOverall - 3), MaxOverall = math.min(99, squadOverall + 3) }, ownTeamId, false)
	if #pool == 0 then return nil end
	local team = pool[random:NextInteger(1, #pool)]
	local identity = Config.TacticalIdentities.balanced_rival
	local objective = objectiveFor(random, identity, nil)
	return fixtureFrom(team, identity, objective, "placement_" .. userId, division, 1, "placement")
end

function Generator.CreateRecovery(season: any, ownTeamId: string?): { any }
	local division = Config.GetDivision(season.DivisionId)
	if not division then return {} end
	local random = Random.new(bit32.band((tonumber(season.Seed) or 1) + 709, 0x7fffffff))
	local excluded = {}
	for _, fixture in season.LeagueFixtures do excluded[fixture.OpponentTeamId] = true end
	excluded[season.PromotionFinal.OpponentTeamId] = true
	local selected = chooseTeams(random, candidatePool(division, ownTeamId, false, excluded), Config.RecoveryFixtureCount)
	local usedIdentities = {}
	local fixtures = {}
	for index, team in selected do
		local identity = pickIdentity(random, usedIdentities, false)
		table.insert(fixtures, fixtureFrom(team, identity, objectiveFor(random, identity, nil), season.SeasonId, division, index, "recovery"))
	end
	return fixtures
end

function Generator.CreateMasteryFixtures(userId: number, contractId: string, masteryWeek: string, squadOverall: number, ownTeamId: string?): { any }?
	local definition = Config.MasteryContracts[contractId]
	local division = Config.GetDivision(6)
	if not definition or not division then return nil end
	local seed = hash(string.format("mastery:%d:%s:%s:%d", userId, masteryWeek, contractId, math.floor(squadOverall)))
	local random = Random.new(seed)
	local rules = definition.Rules
	local pool
	if rules.OpponentMinimumDelta then
		pool = rangePool(squadOverall + rules.OpponentMinimumDelta, squadOverall + rules.OpponentMaximumDelta, ownTeamId, nil)
	else
		pool = candidatePool(division, ownTeamId, false)
	end
	local selected = chooseTeams(random, pool, definition.FixtureCount)
	if #selected ~= definition.FixtureCount then return nil end
	local seasonId = string.format("mastery_%d_%s_%s", userId, masteryWeek:gsub("[^%w]", ""), contractId)
	local usedIdentities = {}
	local fixtures = {}
	for index, team in selected do
		local identity = pickIdentity(random, usedIdentities, false)
		local objective = objectiveFor(random, identity, nil)
		local fixture = fixtureFrom(team, identity, objective, seasonId, division, index, "mastery")
		fixture.IsMastery = true
		table.insert(fixtures, fixture)
	end
	return fixtures
end

function Generator.LockModeObjective(fixture: any, mode: string, seed: number)
	if fixture.Mode then return end
	fixture.Mode = mode
	if mode ~= "Manage" then return end
	local identity = Config.TacticalIdentities[fixture.TacticIdentity] or Config.TacticalIdentities.balanced_rival
	local objective = objectiveFor(Random.new(bit32.band(seed + fixture.Index * 97, 0x7fffffff)), identity, "Manage")
	fixture.ObjectiveId = objective.Id
	fixture.ObjectiveTitle = objective.Title
	fixture.ObjectiveDescription = objective.Description
	fixture.ObjectiveMetric = objective.Metric
	fixture.ObjectiveTarget = objective.Target
end

return Generator
