--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local LegacyConfig = require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)

local CampaignMigration = {}

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[copy(key)] = copy(child) end
	return result
end

local function merge(target: any, template: any): (any, boolean)
	local changed = type(target) ~= "table"
	if type(target) ~= "table" then target = {} end
	for key, value in template do
		if target[key] == nil then
			target[key] = copy(value)
			changed = true
		elseif type(value) == "table" then
			if type(target[key]) == "table" then
				local _, childChanged = merge(target[key], value)
				changed = changed or childChanged
			else
				target[key] = copy(value)
				changed = true
			end
		end
	end
	return target, changed
end

local function countTierTeams(completedTeams: any, tierId: string): number
	if type(completedTeams) ~= "table" then return 0 end
	local count = 0
	for teamId, completed in completedTeams do
		if completed == true and string.find(tostring(teamId), tierId, 1, true) then count += 1 end
	end
	return count
end

local function highestLegacyClear(completedTeams: any, rewardsClaimed: any, unlocked: number): number
	local highest = math.clamp(unlocked - 1, 0, #LegacyConfig.CampaignDifficulties)
	for index, tier in LegacyConfig.CampaignDifficulties do
		local rewardKey = "campaign_tier_clear_" .. tostring(tier.Id)
		if type(rewardsClaimed) == "table" and rewardsClaimed[rewardKey] == true then highest = math.max(highest, index) end
		if countTierTeams(completedTeams, tostring(tier.Id)) >= 5 then highest = math.max(highest, index) end
	end
	return highest
end

local function legacyIsMeaningful(unlocked: number, completedTeams: any, rewardsClaimed: any): boolean
	return unlocked > 1 or type(completedTeams) == "table" and next(completedTeams) ~= nil or type(rewardsClaimed) == "table" and next(rewardsClaimed) ~= nil
end

function CampaignMigration.Normalize(profile: any, timestamp: number?): (any, boolean)
	local changed = false
	local original = type(profile.CampaignProgress) == "table" and profile.CampaignProgress or {}
	local oldUnlocked = math.clamp(math.floor(tonumber(original.UnlockedDifficulty) or 1), 1, #LegacyConfig.CampaignDifficulties)
	local oldCompleted = type(original.CompletedTeams) == "table" and original.CompletedTeams or {}
	local oldRewards = type(original.RewardsClaimed) == "table" and original.RewardsClaimed or {}
	local progress, merged = merge(original, Config.CreateProgress())
	changed = changed or merged or type(profile.CampaignProgress) ~= "table"
	profile.CampaignProgress = progress
	local version = Config.DataVersion
	if progress.Version ~= version then progress.Version = version changed = true end
	local highest = math.clamp(math.floor(tonumber(progress.HighestUnlockedDivision) or 1), 1, #Config.Divisions)
	if progress.HighestUnlockedDivision ~= highest then progress.HighestUnlockedDivision = highest changed = true end
	local facilityPoints = math.max(0, math.floor(tonumber(progress.FacilityPoints) or 0))
	if progress.FacilityPoints ~= facilityPoints then progress.FacilityPoints = facilityPoints changed = true end
	local facilitySpent = math.max(0, math.floor(tonumber(progress.FacilityPointsSpent) or 0))
	if progress.FacilityPointsSpent ~= facilitySpent then progress.FacilityPointsSpent = facilitySpent changed = true end
	local trainingTokens = math.max(0, math.floor(tonumber(progress.CampaignTrainingTokens) or 0))
	if progress.CampaignTrainingTokens ~= trainingTokens then progress.CampaignTrainingTokens = trainingTokens changed = true end
	local trainingSequence = math.max(0, math.floor(tonumber(progress.CampaignTrainingTokenSequence) or 0))
	if progress.CampaignTrainingTokenSequence ~= trainingSequence then progress.CampaignTrainingTokenSequence = trainingSequence changed = true end
	for _, facilityId in Config.FacilityOrder do
		local level = math.clamp(math.floor(tonumber(progress.Facilities[facilityId]) or 0), 0, 3)
		if progress.Facilities[facilityId] ~= level then progress.Facilities[facilityId] = level changed = true end
	end
	if type(progress.ActiveProject) == "table" then
		if type(progress.ActiveProject.XPGrantLedger) ~= "table" then progress.ActiveProject.XPGrantLedger = {} changed = true end
		if type(progress.ActiveProject.AppliedNodeIds) ~= "table" then progress.ActiveProject.AppliedNodeIds = {} changed = true end
		local promotedSeasons = math.max(0, math.floor(tonumber(progress.ActiveProject.PromotedSeasons) or 0))
		if progress.ActiveProject.PromotedSeasons ~= promotedSeasons then progress.ActiveProject.PromotedSeasons = promotedSeasons changed = true end
	end
	if progress.ActiveProject == nil and type(progress.ActiveSeason) == "table" and progress.ActiveSeason.PendingProjectUpgrade ~= nil then
		progress.ActiveSeason.PendingProjectUpgrade = nil
		changed = true
	end
	for _, lifetime in progress.ProjectLifetimeByCard do
		if type(lifetime) == "table" then
			if type(lifetime.AppliedNodes) ~= "table" then lifetime.AppliedNodes = {} changed = true end
			local promotedSeasons = math.max(0, math.floor(tonumber(lifetime.PromotedSeasons) or 0))
			if lifetime.PromotedSeasons ~= promotedSeasons then lifetime.PromotedSeasons = promotedSeasons changed = true end
		end
	end
	local activeMastery = progress.Mastery and progress.Mastery.Active
	if type(activeMastery) == "table" then
		if type(activeMastery.Formations) ~= "table" then activeMastery.Formations = {} changed = true end
		if type(activeMastery.FormationByFixture) ~= "table" then activeMastery.FormationByFixture = {} changed = true end
	end
	while #progress.History > Config.HistoryLimit do table.remove(progress.History) changed = true end
	local migrationVersion = tonumber(progress.MigrationVersion) or 0
	if migrationVersion >= Config.ProfileMigrationVersion then return progress, changed end

	progress.Legacy.UnlockedDifficulty = oldUnlocked
	progress.Legacy.CompletedTeams = copy(oldCompleted)
	progress.Legacy.RewardsClaimed = copy(oldRewards)
	local highestCleared = highestLegacyClear(oldCompleted, oldRewards, oldUnlocked)
	progress.Legacy.HighestClearedLegacyTier = highestCleared
	progress.Legacy.MigratedAt = timestamp or os.time()
	local meaningful = legacyIsMeaningful(oldUnlocked, oldCompleted, oldRewards)
	if meaningful then
		local mappedTier = math.max(oldUnlocked, highestCleared)
		local divisionIndex = Config.LegacyTierMapping[math.clamp(mappedTier, 1, 12)] or 1
		progress.HighestUnlockedDivision = math.max(progress.HighestUnlockedDivision, divisionIndex)
		progress.Placement.Completed = true
		progress.Placement.AssignedDivision = Config.Divisions[progress.HighestUnlockedDivision].Id
		progress.Placement.Result = "Legacy"
		progress.Placement.Reason = "Legacy Campaign progress preserved"
		progress.Placement.CompletedAt = progress.Legacy.MigratedAt
		for tierIndex = 1, highestCleared do
			local recordIndex = Config.LegacyTierMapping[tierIndex]
			local division = recordIndex and Config.Divisions[recordIndex]
			if division then progress.DivisionRecords[division.Id].LegacyCleared = true end
		end
		local legacyPoints = math.min(6, math.floor(highestCleared / 2))
		if progress.FacilityLedger.legacy_migration ~= true then
			progress.FacilityPoints += legacyPoints
			progress.FacilityLedger.legacy_migration = true
		end
		if progress.LegacyHistoryGranted ~= true then
			table.insert(progress.History, 1, {
				Type = "LegacyMigration", Badge = "ASCENSION LEGACY", LegacyTier = highestCleared,
				DivisionId = Config.Divisions[divisionIndex].Id, FacilityPoints = legacyPoints, CompletedAt = progress.Legacy.MigratedAt,
			})
			progress.LegacyHistoryGranted = true
		end
	end
	progress.MigrationVersion = Config.ProfileMigrationVersion
	changed = true
	return progress, changed
end

function CampaignMigration.Copy(value: any): any
	return copy(value)
end

function CampaignMigration.ClientSummary(progress: any): any
	progress = type(progress) == "table" and progress or {}
	local placement = type(progress.Placement) == "table" and progress.Placement or {}
	local season = type(progress.ActiveSeason) == "table" and progress.ActiveSeason or nil
	local project = type(progress.ActiveProject) == "table" and progress.ActiveProject or nil
	return {
		Version = progress.Version,
		HighestUnlockedDivision = progress.HighestUnlockedDivision,
		Placement = { Completed = placement.Completed == true, AssignedDivision = placement.AssignedDivision, Result = placement.Result },
		ActiveSeason = season and {
			SeasonId = season.SeasonId, DivisionId = season.DivisionId, SeasonNumber = season.SeasonNumber,
			Status = season.Status, Points = season.Points, Stars = season.Stars,
			ScoutingFocus = season.ScoutingFocus, ProjectDecision = season.ProjectDecision,
			PendingProjectUpgrade = season.PendingProjectUpgrade and true or nil,
			PendingPromotionChoice = type(season.PendingPromotionChoice) == "table" and season.PendingPromotionChoice.Claimed ~= true and true or nil,
		} or nil,
		ActiveProject = project and {
			CardInstanceId = project.CardInstanceId, PlayerName = project.PlayerName,
			XP = project.XP, CurrentMilestone = project.CurrentMilestone,
		} or nil,
		HasPendingMatch = type(progress.PendingMatch) == "table" and progress.PendingMatch.ResultState ~= "Committed",
	}
end

return CampaignMigration
