--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local Migration = require(script.Parent.CampaignMigration)
local SeasonGenerator = require(script.Parent.CampaignSeasonGenerator)
local ObjectiveEvaluator = require(script.Parent.CampaignObjectiveEvaluator)
local RewardService = require(script.Parent.CampaignRewardService)
local ScoutingService = require(script.Parent.CampaignScoutingService)
local ProjectService = require(script.Parent.CampaignProjectService)
local FacilityService = require(script.Parent.CampaignFacilityService)
local TeamDatabase = require(script.Parent.Parent.Data.TeamDatabase)
local OpponentTacticSelector = require(script.Parent.Parent.Gameplay.OpponentTacticSelector)

local Service = {}
Service.__index = Service

local READ_ACTIONS = {
	GetCampaignState = true,
	GetCampaignEligibleProjects = true,
	GetCampaignHistory = true,
	GetCampaignMastery = true,
}

local function copy(value: any): any
	return Migration.Copy(value)
end

local function analytics(player: Player, eventName: string, properties: any?)
	pcall(function() AnalyticsService:LogCustomEvent(player, eventName, 1, properties or {}) end)
end

local function resultFrom(scoreFor: number, scoreAgainst: number, penaltyWinner: string?): string
	if scoreFor > scoreAgainst then return "Win" end
	if scoreFor < scoreAgainst then return "Loss" end
	if penaltyWinner == "Home" then return "Win" end
	if penaltyWinner == "Away" then return "Loss" end
	return "Draw"
end

local function leaguePoints(result: string): number
	return result == "Win" and 3 or result == "Draw" and 1 or 0
end

local function protectedClass(value: any): boolean
	local normalized = string.lower(tostring(value or ""))
	for name in Config.Project.ProtectedCardTypes do
		if string.lower(tostring(name)) == normalized then return true end
	end
	return false
end

local function currentFixture(season: any): any?
	if not season then return nil end
	if season.Status == "Preseason" or season.Status == "Active" then
		for _, fixture in season.LeagueFixtures or {} do if not fixture.Played then return fixture end end
	elseif season.Status == "Recovery" then
		for _, fixture in season.RecoveryFixtures or {} do if not fixture.Played then return fixture end end
	elseif season.Status == "PromotionFinal" then
		return season.PromotionFinal
	end
	return nil
end

local function publicFixture(fixture: any, tacticalLab: number): any
	if not fixture then return nil end
	local result = {
		FixtureId = fixture.FixtureId, Index = fixture.Index, OpponentTeamId = fixture.OpponentTeamId,
		OpponentTeamName = fixture.OpponentTeamName, OpponentOverall = fixture.OpponentOverall,
		OpponentCountry = fixture.OpponentCountry, OpponentLeague = fixture.OpponentLeague,
		TacticIdentity = fixture.TacticIdentity, TacticLabel = fixture.TacticLabel,
		StarPlayerId = fixture.StarPlayerId, StarPlayerName = fixture.StarPlayerName,
		ObjectiveId = fixture.ObjectiveId, ObjectiveTitle = fixture.ObjectiveTitle,
		ObjectiveDescription = fixture.ObjectiveDescription, ObjectiveMetric = fixture.ObjectiveMetric,
		ObjectiveTarget = fixture.ObjectiveTarget, IsPlacement = fixture.IsPlacement,
		IsRecovery = fixture.IsRecovery, IsPromotionFinal = fixture.IsPromotionFinal,
		Played = fixture.Played, Result = fixture.Result, HomeScore = fixture.HomeScore,
		AwayScore = fixture.AwayScore, StarsEarned = copy(fixture.StarsEarned or {}), Mode = fixture.Mode,
	}
	if tacticalLab >= 1 then result.Formation = fixture.Formation result.OpponentScouting = OpponentTacticSelector.Scout({Fixture = fixture}) end
	if tacticalLab >= 2 then result.Strength = fixture.Strength result.Weakness = fixture.Weakness end
	if tacticalLab >= 3 then result.CounterTactic = fixture.CounterTactic result.CounterPlanApplied = fixture.CounterPlanApplied == true end
	return result
end

local function publicChoice(choice: any): any?
	if type(choice) ~= "table" then return nil end
	return {
		ChoiceId = choice.ChoiceId, DivisionId = choice.DivisionId, SeasonId = choice.SeasonId,
		Focus = choice.Focus, MinimumOverall = choice.MinimumOverall, MaximumOverall = choice.MaximumOverall,
		Options = copy(choice.Options or {}), RerollAvailable = choice.RerollAvailable == true,
		Claimed = choice.Claimed == true, SelectedPlayerId = choice.SelectedPlayerId, Repeat = choice.Repeat == true,
	}
end

local function publicProject(project: any): any?
	if type(project) ~= "table" then return nil end
	return {
		CardInstanceId = project.CardInstanceId, BasePlayerId = project.BasePlayerId, PlayerName = project.PlayerName,
		Position = project.Position, StartTime = project.StartTime, StartSeason = project.StartSeason,
		XP = project.XP, LifetimeXP = project.LifetimeXP, CurrentMilestone = project.CurrentMilestone,
		PendingUpgradeChoice = copy(project.PendingUpgradeChoice), AppliedNodeIds = copy(project.AppliedNodeIds or {}),
		SeasonsCompleted = project.SeasonsCompleted, PromotedSeasons = project.PromotedSeasons,
		OVRBoost = project.OVRBoost, VisualTier = project.VisualTier,
		BoundStatus = project.BoundStatus,
	}
end

local function publicProjectHistory(history: any): any
	local result = {}
	for _, project in type(history) == "table" and history or {} do
		local sanitized = publicProject(project)
		if sanitized then
			sanitized.RetiredAt = project.RetiredAt
			table.insert(result, sanitized)
		end
	end
	return result
end

local function publicSeason(season: any, tacticalLab: number): any?
	if type(season) ~= "table" then return nil end
	local league = {}
	for _, fixture in season.LeagueFixtures or {} do table.insert(league, publicFixture(fixture, tacticalLab)) end
	local recovery = {}
	for _, fixture in season.RecoveryFixtures or {} do table.insert(recovery, publicFixture(fixture, tacticalLab)) end
	return {
		SeasonId = season.SeasonId, DivisionId = season.DivisionId, DivisionIndex = season.DivisionIndex,
		SeasonNumber = season.SeasonNumber, Status = season.Status, StartedAt = season.StartedAt,
		ScoutingFocus = season.ScoutingFocus, ScoutingLocked = season.ScoutingLocked,
		ProjectDecision = season.ProjectDecision,
		ScoutingQualityBonus = season.ScoutingQualityBonus, Points = season.Points, Wins = season.Wins,
		Draws = season.Draws, Losses = season.Losses, GoalsFor = season.GoalsFor, GoalsAgainst = season.GoalsAgainst,
		LeagueFixtures = league, RecoveryFixtures = recovery, PromotionFinal = publicFixture(season.PromotionFinal, tacticalLab),
		CurrentFixtureId = season.CurrentFixtureId, LeagueFixturesCompleted = season.LeagueFixturesCompleted,
		RecoveryPoints = season.RecoveryPoints, PromotionFinalAttempts = season.PromotionFinalAttempts,
		Stars = season.Stars, ClaimedStarMilestones = copy(season.ClaimedStarMilestones or {}),
		PendingProjectUpgrade = copy(season.PendingProjectUpgrade), PendingPromotionChoice = publicChoice(season.PendingPromotionChoice),
		CompletedAt = season.CompletedAt, Promoted = season.Promoted, PerfectSeason = season.PerfectSeason,
		ManagerMatches = season.ManagerMatches, ManualMatches = season.ManualMatches,
	}
end

local function publicMasteryActive(active: any, tacticalLab: number): any?
	if type(active) ~= "table" then return nil end
	local fixtures = {}
	for _, fixture in active.Fixtures or {} do table.insert(fixtures, publicFixture(fixture, tacticalLab)) end
	return {
		WeekKey = active.WeekKey,
		ContractId = active.ContractId,
		StartedAt = active.StartedAt,
		CompletedAt = active.CompletedAt,
		CurrentIndex = active.CurrentIndex,
		Wins = active.Wins,
		Completed = active.Completed == true,
		Succeeded = active.Succeeded == true,
		SquadOverallAtStart = active.SquadOverallAtStart,
		Fixtures = fixtures,
	}
end

local function publicMasteryHistory(history: any): any
	local result = {}
	for _, entry in type(history) == "table" and history or {} do
		table.insert(result, {
			WeekKey = entry.WeekKey,
			ContractId = entry.ContractId,
			StartedAt = entry.StartedAt,
			CompletedAt = entry.CompletedAt,
			Wins = entry.Wins,
			Completed = entry.Completed == true,
			Succeeded = entry.Succeeded == true,
		})
	end
	return result
end

local function presentationPriority(item: any): number
	return item.Type == "ProjectUpgrade" and 1 or item.Type == "PromotionChoice" and 2 or item.Type == "FacilityUpgrade" and 3 or 4
end

function Service.new(profiles: any, publish: any, progression: any, inventory: any, rankedSquads: any)
	return setmetatable({
		Profiles = profiles, Publish = publish, Progression = progression, Inventory = inventory,
		RankedSquads = rankedSquads, MatchSetup = nil, LastActions = {}, PageViewed = {}, TransactionLocks = {}, ResultCommitting = {},
	}, Service)
end

function Service:SetMatchSetup(matchSetup: any)
	self.MatchSetup = matchSetup
end

function Service:PlayerRemoving(player: Player)
	self.LastActions[player] = nil
	self.PageViewed[player] = nil
	self.TransactionLocks[player] = nil
end

function Service:RecordManagerInteraction(player: Player, session: any, kind: string, metadata: any?): (boolean, any?)
	if type(session) ~= "table" or session.Player ~= player or type(session.CampaignAscension) ~= "table" or type(session.Setup) ~= "table" or session.Setup.WatchMode ~= true then return false, nil end
	local manager = session.CampaignManager
	if type(manager) ~= "table" or not table.find({ "Mentality", "Formation", "HalftimeInstruction", "Substitution", "PlayerInstructions" }, kind) then return false, nil end
	local now = os.clock()
	if now - (tonumber(manager.LastActionAt) or 0) < 0.35 then return false, manager end
	manager.LastActionAt = now
	manager.Total = (tonumber(manager.Total) or 0) + 1
	manager.UniqueCategories = type(manager.UniqueCategories) == "table" and manager.UniqueCategories or {}
	manager.UniqueCategories[kind] = true
	if kind == "Mentality" then
		manager.TacticalChanges = (tonumber(manager.TacticalChanges) or 0) + 1
		manager.MentalityChanges = (tonumber(manager.MentalityChanges) or 0) + 1
	elseif kind == "Formation" then
		manager.TacticalChanges = (tonumber(manager.TacticalChanges) or 0) + 1
		manager.FormationChanges = (tonumber(manager.FormationChanges) or 0) + 1
	elseif kind == "HalftimeInstruction" then
		manager.HalftimeInstructions = (tonumber(manager.HalftimeInstructions) or 0) + 1
	elseif kind == "Substitution" then
		manager.Substitutions = (tonumber(manager.Substitutions) or 0) + 1
	elseif kind == "PlayerInstructions" then
		manager.TacticalChanges = (tonumber(manager.TacticalChanges) or 0) + 1
		manager.PlayerInstructionChanges = (tonumber(manager.PlayerInstructionChanges) or 0) + 1
	end
	if type(metadata) == "table" and metadata.AfterHalf == true then
		manager.AfterHalf = true
		manager.SecondHalfInteractions = (tonumber(manager.SecondHalfInteractions) or 0) + 1
	else
		manager.FirstHalfInteractions = (tonumber(manager.FirstHalfInteractions) or 0) + 1
	end
	return true, manager
end

function Service:_profile(player: Player): (any?, any?)
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil, nil end
	local progress = Migration.Normalize(profile)
	local pending = progress.PendingMatch
	if type(pending) == "table" and pending.ResultState ~= "Committed" and (tonumber(pending.ExpiresAt) or 0) < os.time() then
		local season = progress.ActiveSeason
		local final = season and season.PromotionFinal
		if pending.Placement ~= true and pending.Mastery ~= true and final and final.FixtureId == pending.FixtureId and final.Played ~= true then
			season.PromotionFinalAttempts = math.max(0, (tonumber(season.PromotionFinalAttempts) or 0) - 1)
		end
		progress.PendingMatch = nil
		self.Profiles:Save(player, true)
	end
	return profile, progress
end

function Service:_publish(player: Player, profile: any?)
	profile = profile or self.Profiles:GetProfile(player)
	if not profile then return end
	self.Publish(player, "Campaign", self:GetCampaignState(player))
	self.Publish(player, "Progression", self.Progression:GetClientData(player))
end

function Service:_save(player: Player, profile: any, force: boolean?): boolean
	local saved = self.Profiles:Save(player, force == true)
	if saved then self:_publish(player, profile) end
	return saved
end

function Service:GetCampaignState(player: Player): any?
	local profile, progress = self:_profile(player)
	if not profile then return nil end
	local ready, readyMessage, roster = self.RankedSquads:GetRoster(player)
	local tacticalLab = tonumber(progress.Facilities.tactical_lab) or 0
	local division = Config.GetDivision(progress.ActiveSeason and progress.ActiveSeason.DivisionId or progress.HighestUnlockedDivision)
	local presentations = copy(progress.PendingPresentation or {})
	table.sort(presentations, function(a, b) local ap, bp = presentationPriority(a), presentationPriority(b) if ap ~= bp then return ap < bp end return tostring(a.Id) < tostring(b.Id) end)
	local divisions = {}
	for _, definition in Config.Divisions do
		table.insert(divisions, {
			Id = definition.Id, Name = definition.Name, Index = definition.Index, Accent = definition.Accent, MinOverall = definition.MinOverall,
			MaxOverall = definition.MaxOverall, Difficulty = definition.Difficulty, MatchLength = definition.MatchLength,
			PromotionThreshold = Config.PromotionThreshold, ScoutingMin = definition.ScoutingMin,
			ScoutingMax = definition.ScoutingMax, ScoutingChoices = definition.ScoutingChoices,
			PackId = definition.PackId, StarCoins = definition.StarCoins,
			Unlocked = definition.Index <= progress.HighestUnlockedDivision,
		})
	end
	return {
		Version = progress.Version,
		Title = Config.UI.Title,
		Subtitle = Config.UI.Subtitle,
		Placement = {
			Completed = progress.Placement.Completed, Fixture = publicFixture(progress.Placement.Fixture, tacticalLab),
			Result = progress.Placement.Result, AssignedDivision = progress.Placement.AssignedDivision,
			Reason = progress.Placement.Reason, CompletedAt = progress.Placement.CompletedAt,
		},
		HighestUnlockedDivision = progress.HighestUnlockedDivision,
		CurrentDivision = division and { Id = division.Id, Name = division.Name, Index = division.Index } or nil,
		ActiveSeason = publicSeason(progress.ActiveSeason, tacticalLab),
		CurrentFixture = publicFixture(currentFixture(progress.ActiveSeason), tacticalLab),
		DivisionRecords = copy(progress.DivisionRecords),
		Facilities = FacilityService.Public(profile),
		FacilityPoints = progress.FacilityPoints,
		FacilityPointsSpent = progress.FacilityPointsSpent,
		ActiveProject = publicProject(progress.ActiveProject),
		ActiveProjectCard = progress.ActiveProject and ProjectService.GetPublicCard(profile, progress.ActiveProject.CardInstanceId) or nil,
		ProjectHistory = publicProjectHistory(progress.ProjectHistory),
		CampaignTrainingTokens = progress.CampaignTrainingTokens,
		RepeatPromotionTokens = copy(progress.RepeatPromotionTokens),
		History = copy(progress.History),
		Mastery = {
			Unlocked = progress.Mastery.Unlocked == true,
			WeekKey = progress.Mastery.WeekKey,
			Active = publicMasteryActive(progress.Mastery.Active, tacticalLab),
			History = publicMasteryHistory(progress.Mastery.History),
		},
		AscensionChampion = progress.AscensionChampion == true,
		PendingPresentation = presentations,
		HasPendingMatch = type(progress.PendingMatch) == "table" and progress.PendingMatch.ResultState ~= "Committed",
		PendingRecoverable = type(progress.PendingMatch) == "table" and progress.PendingMatch.ResultState ~= "Committed",
		PendingMatchId = type(progress.PendingMatch) == "table" and progress.PendingMatch.PendingId or nil,
		PendingMatchMode = type(progress.PendingMatch) == "table" and progress.PendingMatch.Mode or nil,
		SquadReady = ready,
		SquadMessage = readyMessage,
		Squad = roster and {
			ClubName = roster.Team.teamName, Badge = roster.Team.logo, Formation = roster.Formation,
			Overall = roster.Team.overall, Chemistry = self:_squadChemistry(profile),
			Colors = copy(roster.Team.colors), BadgeIdentity = copy(roster.Team.BadgeIdentity or roster.Team.badgeIdentity),
			ProjectCardInstanceId = progress.ActiveProject and progress.ActiveProject.CardInstanceId or nil,
		} or nil,
		Divisions = divisions,
		ScoutingFocuses = copy(Config.ScoutingFocusOrder),
		StarMilestones = copy(Config.StarMilestones),
		MasteryDefinitions = self:_publicMasteryDefinitions(),
		Copy = copy(Config.UI),
	}
end

function Service:_squadChemistry(profile: any): number
	local chemistry = 0
	local cards = {}
	for _, id in profile.Squad or {} do
		for _, card in profile.PlayerCardInventory or {} do if card.Id == id or card.cardInstanceId == id then table.insert(cards, card) break end end
	end
	for index, card in cards do
		for nextIndex = index + 1, #cards do
			local other = cards[nextIndex]
			if card.Nation == other.Nation then chemistry += 1 end
			if card.Club == other.Club then chemistry += 1 end
		end
	end
	return math.min(33, chemistry)
end

function Service:_publicMasteryDefinitions(): any
	local result = {}
	for _, id in Config.MasteryOrder do
		local definition = Config.MasteryContracts[id]
		table.insert(result, { Id = definition.Id, Name = definition.Name, Description = definition.Description, FixtureCount = definition.FixtureCount, Reward = copy(definition.Reward) })
	end
	return result
end

function Service:GetCampaignEligibleProjects(player: Player): (boolean, string, any?)
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false, "Profile unavailable.", nil end
	return true, "Eligible Club Projects loaded.", ProjectService.GetEligible(profile)
end

function Service:_readyRoster(player: Player): (boolean, string, any?)
	local ready, message, roster = self.RankedSquads:GetRoster(player)
	if not ready then return false, message, nil end
	return true, message, roster
end

function Service:StartCampaignPlacement(player: Player, mode: string?): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	if progress.Placement.Completed then return false, "Placement is already complete.", self:GetCampaignState(player) end
	local ready, message, roster = self:_readyRoster(player)
	if not ready then return false, message, { Navigate = "Squad" } end
	if not progress.Placement.Fixture then progress.Placement.Fixture = SeasonGenerator.CreatePlacement(player.UserId, roster.Team.overall, roster.Team.teamId) end
	if not progress.Placement.Fixture then return false, "Ascension could not build a valid placement opponent.", nil end
	return self:_startFixture(player, profile, progress, progress.Placement.Fixture, mode or "Manual", true, false)
end

function Service:StartCampaignSeason(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	if not progress.Placement.Completed then return false, "Complete placement before starting a season.", nil end
	local active = progress.ActiveSeason
	if active and active.Status ~= "Promoted" and active.Status ~= "Failed" then return false, "Your current Ascension season is still active.", self:GetCampaignState(player) end
	if active and active.PendingPromotionChoice and active.PendingPromotionChoice.Claimed ~= true then return false, "Choose your promotion player before starting another season.", self:GetCampaignState(player) end
	if progress.ActiveProject and progress.ActiveProject.PendingUpgradeChoice then return false, "Resolve your Club Project upgrade before starting another season.", self:GetCampaignState(player) end
	local ready, message, roster = self:_readyRoster(player)
	if not ready then return false, message, { Navigate = "Squad" } end
	local divisionIndex = progress.HighestUnlockedDivision
	if active and active.Status == "Failed" then divisionIndex = active.DivisionIndex end
	local record = progress.DivisionRecords[Config.Divisions[divisionIndex].Id]
	local seasonNumber = (tonumber(record.SeasonsPlayed) or 0) + 1
	local activeSnapshot = copy(active)
	progress.ActiveSeason = SeasonGenerator.CreateSeason(player.UserId, divisionIndex, seasonNumber, roster.Team.teamId)
	if not progress.ActiveSeason then return false, "Ascension could not build a complete opponent schedule.", nil end
	progress.ActiveSeason.ProjectDecision = progress.ActiveProject and "Continue" or nil
	if not self:_save(player, profile, true) then
		progress.ActiveSeason = activeSnapshot
		return false, "Ascension could not save the new season.", nil
	end
	analytics(player, "ascension_season_started", { Division = progress.ActiveSeason.DivisionId, Season = seasonNumber })
	return true, "Ascension preseason opened.", self:GetCampaignState(player)
end

function Service:ChooseCampaignScoutingFocus(player: Player, focus: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local season = progress and progress.ActiveSeason
	if not profile or not season then return false, "Start a season first.", nil end
	if type(focus) ~= "string" or #focus > 32 or not Config.ScoutingFocuses[focus] then return false, "Choose a valid scouting focus.", nil end
	if season.ScoutingLocked or season.LeagueFixturesCompleted > 0 then return false, "Scouting focus locked when the first fixture started.", nil end
	local previousFocus = season.ScoutingFocus
	season.ScoutingFocus = focus
	if not self:_save(player, profile, true) then
		season.ScoutingFocus = previousFocus
		return false, "The scouting focus could not be saved.", nil
	end
	analytics(player, "ascension_focus_selected", { Division = season.DivisionId, Focus = focus })
	return true, focus .. " scouting selected.", self:GetCampaignState(player)
end

function Service:SelectCampaignProject(player: Player, cardId: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local season = progress and progress.ActiveSeason
	if not profile or not season or season.Status ~= "Preseason" then return false, "Club Projects can be selected during preseason.", nil end
	local progressSnapshot = copy(progress)
	local metaSnapshot = copy(profile.PlayerCardMeta)
	local success, message, data = ProjectService.Select(profile, cardId, season.SeasonId)
	if success then
		season.ProjectDecision = "Selected"
		local appliedTokens = 0
		local pendingChoice = nil
		while (tonumber(progress.CampaignTrainingTokens) or 0) > 0 do
			local amount = math.min(8, math.floor(tonumber(progress.CampaignTrainingTokens) or 0))
			progress.CampaignTrainingTokenSequence = (tonumber(progress.CampaignTrainingTokenSequence) or 0) + 1
			local granted, generated = ProjectService.GrantXP(profile, amount, "training-token:" .. tostring(progress.CampaignTrainingTokenSequence))
			if granted <= 0 then break end
			progress.CampaignTrainingTokens = math.max(0, progress.CampaignTrainingTokens - granted)
			appliedTokens += granted
			pendingChoice = generated or pendingChoice
		end
		if pendingChoice then
			season.PendingProjectUpgrade = copy(pendingChoice)
			table.insert(progress.PendingPresentation, 1, { Id = pendingChoice.ChoiceId, Type = "ProjectUpgrade", Data = copy(pendingChoice) })
		end
		if not self:_save(player, profile, true) then
			profile.CampaignProgress = progressSnapshot
			profile.PlayerCardMeta = metaSnapshot
			return false, "The Club Project selection could not be saved.", nil
		end
		analytics(player, "ascension_project_selected", { Division = season.DivisionId })
		if appliedTokens > 0 then message ..= " " .. tostring(appliedTokens) .. " banked Project XP applied." end
	end
	return success, message, success and self:GetCampaignState(player) or data
end

function Service:SkipCampaignProject(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local season = progress and progress.ActiveSeason
	if not profile or not season or season.Status ~= "Preseason" then return false, "Club Project decisions are made during preseason.", nil end
	if progress.ActiveProject then return false, "Retire the active Club Project before skipping it.", nil end
	local previousDecision = season.ProjectDecision
	season.ProjectDecision = "Skipped"
	if not self:_save(player, profile, true) then
		season.ProjectDecision = previousDecision
		return false, "The Club Project decision could not be saved.", nil
	end
	return true, "This season will continue without Club Project progression.", self:GetCampaignState(player)
end

function Service:RetireCampaignProject(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local season = progress.ActiveSeason
	local atBoundary = not season or season.Status == "Preseason" or season.Status == "Promoted" or season.Status == "Failed"
	local project = progress.ActiveProject
	local hadPermanentUpgrade = project and #(project.AppliedNodeIds or {}) > 0 or false
	local progressSnapshot = copy(progress)
	local metaSnapshot = copy(profile.PlayerCardMeta)
	local success, message = ProjectService.Retire(profile, atBoundary)
	if success then
		if season and season.Status == "Preseason" then season.ProjectDecision = nil end
		if not self:_save(player, profile, true) then
			profile.CampaignProgress = progressSnapshot
			profile.PlayerCardMeta = metaSnapshot
			return false, "The Club Project retirement could not be saved.", nil
		end
		local fallbackDivision = Config.GetDivision(progress.HighestUnlockedDivision)
		analytics(player, "ascension_abandoned", {
			Division = season and season.DivisionId or fallbackDivision and fallbackDivision.Id,
			PermanentUpgrades = hadPermanentUpgrade,
		})
	end
	return success, message, self:GetCampaignState(player)
end

function Service:StartCampaignFixture(player: Player, mode: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local season = progress and progress.ActiveSeason
	if not profile or not season then return false, "Start an Ascension season first.", nil end
	if progress.ActiveProject and progress.ActiveProject.PendingUpgradeChoice then return false, "Resolve your Club Project upgrade before the next fixture.", self:GetCampaignState(player) end
	if not season.ScoutingFocus then return false, "Choose a scouting focus before the first fixture.", nil end
	if not season.ProjectDecision then return false, "Select a Club Project or choose to play this season without one.", nil end
	local fixture = currentFixture(season)
	if not fixture then return false, "No Ascension fixture is ready.", self:GetCampaignState(player) end
	return self:_startFixture(player, profile, progress, fixture, mode, false, false)
end

function Service:_launchPending(player: Player, profile: any, progress: any, fixture: any): (boolean, string, any?)
	local pending = progress.PendingMatch
	if type(pending) ~= "table" then return false, "No pending Ascension match exists.", nil end
	if not self.MatchSetup then
		progress.PendingMatch = nil
		if fixture.IsPromotionFinal then
			local season = progress.ActiveSeason
			if season then season.PromotionFinalAttempts = math.max(0, (tonumber(season.PromotionFinalAttempts) or 0) - 1) end
		end
		self.Profiles:Save(player, true)
		return false, "Ascension match coordinator is unavailable.", nil
	end
	local success, launchMessage, data = self.MatchSetup:StartCampaignAscension(player, pending.PendingId)
	if not success then
		if not (type(data) == "table" and data.PendingRecoverable == true) then
			progress.PendingMatch = nil
			if fixture.IsPromotionFinal then
				local season = progress.ActiveSeason
				if season then season.PromotionFinalAttempts = math.max(0, (tonumber(season.PromotionFinalAttempts) or 0) - 1) end
			end
		end
		self.Profiles:Save(player, true)
	end
	return success, launchMessage, data
end

function Service:ResumeCampaignMatch(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local pending = progress and progress.PendingMatch
	if not profile or type(pending) ~= "table" then return false, "No pending Ascension match exists.", nil end
	local fixture = self:_fixtureForPending(progress, pending)
	if not fixture or fixture.Played then
		progress.PendingMatch = nil
		self.Profiles:Save(player, true)
		return false, "The pending Ascension fixture is no longer available.", nil
	end
	return self:_launchPending(player, profile, progress, fixture)
end

function Service:_startFixture(player: Player, profile: any, progress: any, fixture: any, mode: string, placement: boolean, mastery: boolean): (boolean, string, any?)
	mode = mode == "Manage" and "Manage" or mode == "Manual" and "Manual" or ""
	if mode == "" then return false, "Choose PLAY MATCH or MANAGE MATCH.", nil end
	if placement and mode == "Manage" then return false, "Placement must be played manually.", nil end
	if fixture.Mode and fixture.Mode ~= mode then return false, "This fixture is locked to " .. fixture.Mode .. " mode.", nil end
	local pending = progress.PendingMatch
	if type(pending) == "table" and pending.ResultState ~= "Committed" and (tonumber(pending.ExpiresAt) or 0) >= os.time() then
		if pending.FixtureId ~= fixture.FixtureId or pending.Mode ~= mode then return false, "Another Ascension fixture is already pending.", { PendingId = pending.PendingId } end
		return self:_launchPending(player, profile, progress, fixture)
	end
	local ready, message, roster = self:_readyRoster(player)
	if not ready then return false, message, { Navigate = "Squad" } end
	local season = progress.ActiveSeason
	local fixtureSnapshot = copy(fixture)
	local seasonSnapshot = not placement and not mastery and {
		ScoutingLocked = season.ScoutingLocked,
		Status = season.Status,
		PromotionFinalAttempts = season.PromotionFinalAttempts,
	} or nil
	if not placement and not mastery then
		SeasonGenerator.LockModeObjective(fixture, mode, season.Seed)
		season.ScoutingLocked = true
		season.Status = season.Status == "Preseason" and "Active" or season.Status
		if fixture.IsPromotionFinal then season.PromotionFinalAttempts = math.min(Config.MaximumPromotionAttempts, (tonumber(season.PromotionFinalAttempts) or 0) + 1) end
	elseif not fixture.Mode then
		fixture.Mode = mode
	end
	local projectCard = progress.ActiveProject and progress.ActiveProject.CardInstanceId or nil
	local projectStarting = false
	for _, playerData in roster.StartingXI do if playerData.cardInstanceId == projectCard then projectStarting = true break end end
	local pendingId = "asc_pending_" .. HttpService:GenerateGUID(false)
	progress.PendingMatch = {
		PendingId = pendingId, SeasonId = placement and "placement" or fixture.SeasonId, FixtureId = fixture.FixtureId,
		DivisionId = fixture.DivisionId, Mode = mode, CreatedAt = os.time(), ExpiresAt = os.time() + Config.PendingMatchLifetime,
		ReturnPlaceId = game.PlaceId, ResultState = "Pending", Placement = placement, Mastery = mastery,
		SquadOverall = roster.Team.overall, ProjectCardInstanceId = projectStarting and projectCard or nil,
		SetupSnapshot = { OpponentTeamId = fixture.OpponentTeamId, Difficulty = Config.GetDivision(fixture.DivisionId).Difficulty, MatchLength = Config.GetDivision(fixture.DivisionId).MatchLength },
	}
	if not self.Profiles:Save(player, true) then
		progress.PendingMatch = nil
		table.clear(fixture)
		for key, value in fixtureSnapshot do fixture[key] = value end
		if seasonSnapshot then
			season.ScoutingLocked = seasonSnapshot.ScoutingLocked
			season.Status = seasonSnapshot.Status
			season.PromotionFinalAttempts = seasonSnapshot.PromotionFinalAttempts
		end
		return false, "Ascension could not save the pending fixture.", nil
	end
	analytics(player, placement and "ascension_placement_started" or fixture.IsPromotionFinal and "ascension_promotion_final_started" or "ascension_fixture_started", { Division = fixture.DivisionId, Mode = mode, OpponentOVR = fixture.OpponentOverall })
	return self:_launchPending(player, profile, progress, fixture)
end

function Service:BuildPendingRuntime(player: Player, pendingId: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local pending = progress and progress.PendingMatch
	if not profile or type(pending) ~= "table" then return false, "No pending Ascension match exists.", nil end
	if type(pendingId) ~= "string" or #pendingId > 96 or pending.PendingId ~= pendingId then return false, "Pending Ascension match does not match this server.", nil end
	if pending.ResultState == "Committed" or (tonumber(pending.ExpiresAt) or 0) < os.time() then return false, "Pending Ascension match expired.", nil end
	local fixture = nil
	if pending.Placement then
		fixture = progress.Placement.Fixture
	elseif pending.Mastery then
		local active = progress.Mastery.Active
		for _, value in active and active.Fixtures or {} do if value.FixtureId == pending.FixtureId then fixture = value break end end
	else
		local season = progress.ActiveSeason
		if not season or season.SeasonId ~= pending.SeasonId then return false, "Ascension season changed before launch.", nil end
		for _, value in season.LeagueFixtures or {} do if value.FixtureId == pending.FixtureId then fixture = value break end end
		for _, value in season.RecoveryFixtures or {} do if value.FixtureId == pending.FixtureId then fixture = value break end end
		if season.PromotionFinal and season.PromotionFinal.FixtureId == pending.FixtureId then fixture = season.PromotionFinal end
	end
	if not fixture or fixture.Played then return false, "Ascension fixture is no longer available.", nil end
	if fixture.OpponentTeamId ~= pending.SetupSnapshot.OpponentTeamId then return false, "Ascension fixture validation failed.", nil end
	local ready, message, homeRoster = self:_readyRoster(player)
	if not ready then return false, message, nil end
	local awayRoster = TeamDatabase.GetRoster(fixture.OpponentTeamId)
	if not awayRoster then return false, "Opponent roster is unavailable.", nil end
	awayRoster.Formation = fixture.Formation or awayRoster.Formation
	local opponentTactics = OpponentTacticSelector.Resolve({Fixture = fixture, Roster = awayRoster, TeamMetadata = awayRoster.Team})
	local opponentScouting = OpponentTacticSelector.Scout({Fixture = fixture, Roster = awayRoster, TeamMetadata = awayRoster.Team})
	local division = Config.GetDivision(fixture.DivisionId)
	local baseSetup = profile.MatchSetup or {}
	local setup = {
		MatchLength = division.MatchLength, Difficulty = division.Difficulty, MatchType = "Objective Match",
		HomeTeamId = homeRoster.Team.teamId, AwayTeamId = awayRoster.Team.teamId, HomeKit = "Home", AwayKit = "Away",
		StadiumId = baseSetup.StadiumId or "voltra_arena", Weather = baseSetup.Weather or "Clear", Time = baseSetup.Time or "Evening",
		Completed = true, CampaignAscension = true, AscensionPendingId = pending.PendingId,
		AscensionSeasonId = pending.SeasonId, AscensionFixtureId = pending.FixtureId, AscensionDivisionId = pending.DivisionId,
		AscensionMode = pending.Mode, AscensionObjective = fixture.ObjectiveTitle, WatchMode = pending.Mode == "Manage",
		TeamTactics = copy(profile.TeamTactics), RequireWinner = fixture.IsPromotionFinal == true,
		HomeFormation = homeRoster.Formation, AwayFormation = awayRoster.Formation,
		AwayTactics = opponentTactics, AscensionOpponentTactics = opponentTactics, OpponentScouting = opponentScouting,
		AscensionPromotionFinal = fixture.IsPromotionFinal == true,
		NoPrematch = false, StadiumAscensionLevel = progress.Facilities.stadium,
	}
	if fixture.CounterPlanApplied and progress.Facilities.tactical_lab >= 3 then setup.AscensionCounterPlan = fixture.CounterTactic end
	return true, "Ascension fixture validated.", { Setup = setup, HomeRoster = homeRoster, AwayRoster = awayRoster, Pending = copy(pending), Fixture = copy(fixture) }
end

function Service:AttachRuntime(player: Player, session: any, pendingId: string): (boolean, string)
	local profile, progress = self:_profile(player)
	local pending = progress and progress.PendingMatch
	if not profile or type(pending) ~= "table" or pending.PendingId ~= pendingId then return false, "Pending Ascension match changed." end
	session.CampaignAscension = { PendingId = pending.PendingId, SeasonId = pending.SeasonId, FixtureId = pending.FixtureId, DivisionId = pending.DivisionId, Mode = pending.Mode, Placement = pending.Placement, Mastery = pending.Mastery }
	session.CampaignManager = {
		Total = 0, FirstHalfInteractions = 0, SecondHalfInteractions = 0, UniqueCategories = {},
		TacticalChanges = 0, MentalityChanges = 0, FormationChanges = 0, Substitutions = 0,
		HalftimeInstructions = 0, AfterHalf = false, SecondHalfImprovement = false,
		FirstHalfGoalDifference = 0, CurrentFormation = session.Setup.HomeFormation or session.Setup.Formation,
		CurrentMentality = session.Setup.TeamTactics and session.Setup.TeamTactics.Identity or "Balanced",
	}
	session.OnBeforeResult = function(ended: any)
		local reward = self:CommitResult(player, ended)
		return reward and { [player.UserId] = reward } or {}
	end
	session.OnCompleted = function(ended: any) self:CommitResult(player, ended) end
	return true, "Ascension runtime attached."
end

function Service:_fixtureForPending(progress: any, pending: any): (any?, any?)
	if pending.Placement then return progress.Placement.Fixture, nil end
	if pending.Mastery then
		local active = progress.Mastery.Active
		for _, fixture in active and active.Fixtures or {} do if fixture.FixtureId == pending.FixtureId then return fixture, active end end
		return nil, active
	end
	local season = progress.ActiveSeason
	if not season or season.SeasonId ~= pending.SeasonId then return nil, season end
	for _, fixture in season.LeagueFixtures or {} do if fixture.FixtureId == pending.FixtureId then return fixture, season end end
	for _, fixture in season.RecoveryFixtures or {} do if fixture.FixtureId == pending.FixtureId then return fixture, season end end
	if season.PromotionFinal and season.PromotionFinal.FixtureId == pending.FixtureId then return season.PromotionFinal, season end
	return nil, season
end

function Service:CommitResult(player: Player, session: any): any?
	local profile, progress = self:_profile(player)
	local tag = session and session.CampaignAscension
	if not profile or type(tag) ~= "table" then return nil end
	local matchId = tostring(session.MatchId or session.World and session.World.Folder and session.World.Folder.Name or tag.PendingId)
	local ledgerKey = tostring(tag.SeasonId) .. ":" .. tostring(tag.FixtureId) .. ":" .. matchId
	local existing = progress.ResultLedger[ledgerKey]
	if existing then return copy(existing.Payload) end
	local pending = progress.PendingMatch
	if type(pending) ~= "table" or pending.PendingId ~= tag.PendingId then return nil end
	local fixture, season = self:_fixtureForPending(progress, pending)
	if not fixture then return nil end
	local commitLockKey = tostring(pending.PendingId)
	if self.ResultCommitting[commitLockKey] then return nil end
	if fixture.Played then return nil end
	self.ResultCommitting[commitLockKey] = true
	local function finish(payload: any?): any?
		self.ResultCommitting[commitLockKey] = nil
		return payload
	end
	local scoreFor = tonumber(session.World.HomeScore.Value) or 0
	local scoreAgainst = tonumber(session.World.AwayScore.Value) or 0
	local stats = session.Stats:Serialize(scoreFor, scoreAgainst, session.Clock:Payload().GameSeconds)
	local result = resultFrom(scoreFor, scoreAgainst, session.PenaltyShootoutWinner)
	if fixture.IsPromotionFinal and result == "Draw" then result = "Loss" end
	local validFinish = session.Ended == true
	local manager = session.CampaignManager or {}
	manager.SecondHalfImprovement = scoreFor - scoreAgainst > (tonumber(manager.FirstHalfGoalDifference) or scoreFor - scoreAgainst)
	local managerQualified = pending.Mode ~= "Manage" or ObjectiveEvaluator.ManagerQualified(manager)
	if pending.Mode == "Manage" and not managerQualified then analytics(player, "ascension_manager_passive", { Division = pending.DivisionId, FixtureId = pending.FixtureId }) end
	local stars = ObjectiveEvaluator.EvaluateStars(fixture, stats, {
		Mode = pending.Mode, Manager = manager, ValidFinish = validFinish, Forfeit = session.ForfeitBy == player.UserId,
		Stats = stats, ProjectCardInstanceId = pending.ProjectCardInstanceId, Result = result,
	})
	local objectiveCompleted = stars[3].Earned == true
	if pending.Placement then return finish(self:_commitPlacement(player, profile, progress, pending, fixture, result, scoreFor, scoreAgainst, stats, ledgerKey)) end
	if pending.Mastery then return finish(self:_commitMastery(player, profile, progress, pending, fixture, season, result, scoreFor, scoreAgainst, stats, ledgerKey, managerQualified)) end

	local rewardOk, breakdown = RewardService.GrantMatch(player, profile, season, fixture, result, objectiveCompleted, managerQualified, self.Progression, pending.PendingId)
	if not rewardOk then return finish(nil) end
	fixture.Result = result
	fixture.HomeScore = scoreFor
	fixture.AwayScore = scoreAgainst
	fixture.Mode = pending.Mode
	fixture.MatchId = matchId
	fixture.PlayedAt = os.time()
	local newlyEarnedStars = {}
	if not fixture.IsRecovery then
		fixture.StarsEarned = fixture.StarsEarned or {}
		for _, star in stars do
			if star.Earned and fixture.StarsEarned[star.Id] ~= true then
				fixture.StarsEarned[star.Id] = true
				season.Stars += 1
				table.insert(newlyEarnedStars, star)
			end
		end
	end
	local projectXP, projectMilestone = self:_grantProjectMatchXP(profile, season, fixture, pending, stats, stars, managerQualified, ledgerKey)
	local milestones, milestonesGranted = RewardService.GrantStarMilestones(player, profile, season, self.Inventory, self.Progression, ProjectService)
	if not milestonesGranted then return finish(nil) end
	fixture.Attempts = fixture.Attempts or {}
	table.insert(fixture.Attempts, { MatchId = matchId, Result = result, HomeScore = scoreFor, AwayScore = scoreAgainst, PlayedAt = fixture.PlayedAt })
	local points = 0
	if not fixture.IsPromotionFinal then
		fixture.Played = true
		points = leaguePoints(result)
		if fixture.IsRecovery then season.RecoveryPoints += points else season.Points += points season.LeagueFixturesCompleted += 1 end
		season.Wins += result == "Win" and 1 or 0
		season.Draws += result == "Draw" and 1 or 0
		season.Losses += result == "Loss" and 1 or 0
		season.GoalsFor += scoreFor
		season.GoalsAgainst += scoreAgainst
	else
		fixture.Played = result == "Win" or season.PromotionFinalAttempts >= Config.MaximumPromotionAttempts
	end
	if pending.Mode == "Manage" then season.ManagerMatches += 1 else season.ManualMatches += 1 end
	self:_advanceSeason(player, profile, progress, season, fixture, result)
	local payload = {
		Title = result == "Win" and "ASCENSION VICTORY" or result == "Draw" and "ASCENSION DRAW" or "ASCENSION DEFEAT",
		CampaignAscension = true, Result = result, Division = Config.GetDivision(season.DivisionId).Name,
		Opponent = fixture.OpponentTeamName, Home = scoreFor, Away = scoreAgainst, LeaguePoints = points,
		SeasonPoints = season.Points, Stars = stars, SeasonStars = season.Stars, RewardBreakdown = breakdown,
		Coins = breakdown.GrantedCoins, XP = breakdown.GrantedXP, Vip2x = breakdown.VipModifier == 2,
		ProjectXP = projectXP, ProjectMilestone = projectMilestone, StarMilestones = milestones,
		SeasonStatus = season.Status, PromotionFinalAttempts = season.PromotionFinalAttempts,
		Promoted = season.Promoted, PendingPromotionChoice = publicChoice(season.PendingPromotionChoice),
		FacilityPoints = progress.FacilityPoints, NextCTA = self:_nextCTA(season),
	}
	progress.ResultLedger[ledgerKey] = { CommittedAt = os.time(), Payload = copy(payload) }
	pending.ResultState = "Committed"
	pending.ResultLedgerKey = ledgerKey
	progress.PendingMatch = nil
	self.Profiles:RecordMatchResult(player, "Campaign", ledgerKey, result, { Division = season.DivisionId, FixtureId = fixture.FixtureId })
	local saved = self:_save(player, profile, true)
	if saved then
		for _, star in newlyEarnedStars do
			analytics(player, "ascension_star_earned", {
				Division = season.DivisionId,
				Mode = pending.Mode,
				Star = star.Id,
				Stars = season.Stars,
				Objective = fixture.ObjectiveId,
			})
		end
		for _, milestone in milestones do
			analytics(player, "ascension_star_milestone", {
				Division = season.DivisionId,
				Stars = milestone.Stars,
				Reward = milestone.Type,
			})
		end
		analytics(player, "ascension_fixture_completed", { Division = season.DivisionId, Mode = pending.Mode, Result = result, Stars = season.Stars, Objective = fixture.ObjectiveId })
	end
	return finish(payload)
end

function Service:_commitPlacement(player: Player, profile: any, progress: any, pending: any, fixture: any, result: string, scoreFor: number, scoreAgainst: number, stats: any, ledgerKey: string): any
	local baseIndex = 1
	for _, band in Config.PlacementBands do if pending.SquadOverall <= band.Maximum then baseIndex = band.Division break end end
	local performance = (scoreFor - scoreAgainst) * 12 + ((tonumber(stats.Home.Possession) or 50) - 50) + ((tonumber(stats.Home.ShotsOnTarget) or 0) - (tonumber(stats.Away.ShotsOnTarget) or 0)) * 2
	local assigned = baseIndex
	local reason = "Squad OVR and a close placement result kept the expected division."
	if result == "Win" and scoreFor - scoreAgainst >= 2 and performance >= 20 then assigned += 1 reason = "A strong win raised placement by one division."
	elseif result == "Loss" and scoreAgainst - scoreFor >= 3 then assigned -= 1 reason = "A heavy loss lowered placement by one division." end
	assigned = math.clamp(math.max(assigned, progress.HighestUnlockedDivision), 1, #Config.Divisions)
	local division = Config.GetDivision(assigned)
	local rewardBand = Config.Divisions[1].Rewards[result]
	local reward = self.Progression:GrantMatchRewards(player, { Title = "ASCENSION PLACEMENT", Coins = rewardBand.Coins, XP = rewardBand.XP, TransactionId = "ascension:placement:" .. pending.PendingId })
	if not reward then return nil end
	fixture.Played = true fixture.Result = result fixture.HomeScore = scoreFor fixture.AwayScore = scoreAgainst fixture.MatchId = ledgerKey fixture.PlayedAt = os.time()
	progress.Placement.Completed = true
	progress.Placement.Result = result
	progress.Placement.AssignedDivision = division.Id
	progress.Placement.Reason = reason
	progress.Placement.CompletedAt = os.time()
	progress.HighestUnlockedDivision = math.max(progress.HighestUnlockedDivision, assigned)
	local payload = { Title = "PLACEMENT COMPLETE", CampaignAscension = true, Placement = true, Result = result, Division = division.Name, AssignedDivision = division.Id, Reason = reason, Home = scoreFor, Away = scoreAgainst, Coins = reward.Coins, XP = reward.XP, NextCTA = "START FIRST SEASON" }
	progress.ResultLedger[ledgerKey] = { CommittedAt = os.time(), Payload = copy(payload) }
	table.insert(progress.PendingPresentation, { Id = "placement:" .. ledgerKey, Type = "Placement", Data = copy(payload) })
	progress.PendingMatch = nil
	self.Profiles:RecordMatchResult(player, "Campaign", ledgerKey, result, { Placement = true, Division = division.Id })
	self:_save(player, profile, true)
	analytics(player, "ascension_placement_completed", { Division = division.Id, Result = result })
	return payload
end

function Service:_grantProjectMatchXP(profile: any, season: any, fixture: any, pending: any, stats: any, stars: any, managerQualified: boolean, ledgerKey: string): (number, any?)
	if not pending.ProjectCardInstanceId or pending.Mode == "Manage" and not managerQualified then return 0, nil end
	local retry = fixture.IsPromotionFinal and (tonumber(season.PromotionFinalAttempts) or 0) > 1
	local completionAmount = retry and 0 or 1
	if not retry and stars[3].Earned then completionAmount += 1 end
	local ratingEntry = nil
	for _, entry in stats.PlayerRatings or {} do if entry.cardInstanceId == pending.ProjectCardInstanceId then ratingEntry = entry break end end
	if not retry and ratingEntry and ((tonumber(ratingEntry.Rating) or 0) >= 7.5 or (tonumber(ratingEntry.Goals) or 0) + (tonumber(ratingEntry.Assists) or 0) >= 2 or (tonumber(ratingEntry.DefensiveActions) or 0) >= 5 or (tonumber(ratingEntry.Saves) or 0) >= 4) then completionAmount += 1 end
	if not retry and stars[3].Earned and (tonumber(profile.CampaignProgress.Facilities.academy) or 0) >= 1 then completionAmount += 1 end
	local granted, pendingChoice = ProjectService.GrantXP(profile, completionAmount, "fixture:" .. ledgerKey)
	if fixture.IsPromotionFinal and fixture.Result == "Win" then
		local promotionGranted, promotionChoice = ProjectService.GrantXP(profile, 2, "promotion-final:" .. season.SeasonId .. ":" .. fixture.FixtureId)
		granted += promotionGranted
		pendingChoice = promotionChoice or pendingChoice
	end
	if pendingChoice then
		season.PendingProjectUpgrade = copy(pendingChoice)
		table.insert(profile.CampaignProgress.PendingPresentation, 1, { Id = pendingChoice.ChoiceId, Type = "ProjectUpgrade", Data = copy(pendingChoice) })
	end
	return granted, pendingChoice and pendingChoice.Milestone or nil
end

function Service:_advanceSeason(player: Player, profile: any, progress: any, season: any, fixture: any, result: string)
	if fixture.IsPromotionFinal then
		if result == "Win" then
			season.Status = "Promoted"
			season.Promoted = true
			self:_completeSeason(player, profile, progress, season, true)
		elseif season.PromotionFinalAttempts >= Config.MaximumPromotionAttempts then
			season.Status = "Failed"
			self:_completeSeason(player, profile, progress, season, false)
		else
			season.Status = "PromotionFinal"
		end
	elseif fixture.IsRecovery then
		local played = 0
		for _, value in season.RecoveryFixtures do if value.Played then played += 1 end end
		if season.RecoveryPoints >= Config.RecoveryThreshold then season.Status = "PromotionFinal"
		elseif played >= Config.RecoveryFixtureCount then season.Status = "Failed" self:_completeSeason(player, profile, progress, season, false) end
	elseif season.LeagueFixturesCompleted >= Config.LeagueFixtureCount then
		if season.Points >= Config.PromotionThreshold then
			season.Status = "PromotionFinal"
		else
			season.Status = "Recovery"
			if #season.RecoveryFixtures == 0 then
				local ready, _, roster = self.RankedSquads:GetRoster(player)
				season.RecoveryFixtures = SeasonGenerator.CreateRecovery(season, ready and roster.Team.teamId or nil)
			end
			analytics(player, "ascension_recovery_started", { Division = season.DivisionId })
		end
	end
	local nextFixture = currentFixture(season)
	season.CurrentFixtureId = nextFixture and nextFixture.FixtureId or nil
	season.UpdatedAt = os.time()
end

function Service:_completeSeason(player: Player, profile: any, progress: any, season: any, promoted: boolean)
	if season.CompletedAt and season.CompletedAt > 0 then return end
	season.CompletedAt = os.time()
	local division = Config.GetDivision(season.DivisionId)
	local record = progress.DivisionRecords[division.Id]
	record.SeasonsPlayed += 1
	record.BestPoints = math.max(record.BestPoints, season.Points)
	record.BestGoalDifference = math.max(record.BestGoalDifference, season.GoalsFor - season.GoalsAgainst)
	local unbeaten = 0
	local bestUnbeaten = 0
	local function includeResult(result: any)
		if result == "Loss" then unbeaten = 0 elseif result == "Win" or result == "Draw" then unbeaten += 1 bestUnbeaten = math.max(bestUnbeaten, unbeaten) end
	end
	for _, playedFixture in season.LeagueFixtures or {} do if playedFixture.Played then includeResult(playedFixture.Result) end end
	for _, playedFixture in season.RecoveryFixtures or {} do if playedFixture.Played then includeResult(playedFixture.Result) end end
	for _, attempt in season.PromotionFinal and season.PromotionFinal.Attempts or {} do includeResult(attempt.Result) end
	record.LongestUnbeatenRun = math.max(tonumber(record.LongestUnbeatenRun) or 0, bestUnbeaten)
	if season.PerfectSeason then record.PerfectSeasons += 1 end
	local promotionReward = nil
	if promoted then
		record.Promotions += 1
		record.Titles += 1
		if season.ManagerMatches > 0 and season.ManualMatches == 0 then record.ManagerTitles += 1 else record.ManualTitles += 1 end
		progress.HighestUnlockedDivision = math.max(progress.HighestUnlockedDivision, math.min(#Config.Divisions, division.Index + 1))
		promotionReward = RewardService.GrantPromotion(profile, season)
		season.PromotionReward = copy(promotionReward)
		local shouldGenerate = promotionReward.FirstPromotion or promotionReward.RepeatTokens >= 3
		if shouldGenerate then
			local choice = ScoutingService.Generate(profile, season, false)
			if choice then
				choice.Repeat = not promotionReward.FirstPromotion
				table.insert(progress.PendingPresentation, { Id = choice.ChoiceId, Type = "PromotionChoice", Data = publicChoice(choice) })
			end
		end
		if division.Id == "voltra_masters" then progress.AscensionChampion = true progress.Mastery.Unlocked = true end
		table.insert(progress.PendingPresentation, { Id = "promotion:" .. season.SeasonId, Type = "Promotion", Data = copy(promotionReward) })
		analytics(player, "ascension_promoted", { Division = division.Id, Stars = season.Stars })
	else
		analytics(player, "ascension_season_failed", { Division = division.Id, Stars = season.Stars })
	end
	if progress.ActiveProject then
		progress.ActiveProject.SeasonsCompleted += 1
		if promoted then progress.ActiveProject.PromotedSeasons = (tonumber(progress.ActiveProject.PromotedSeasons) or 0) + 1 end
		local meta = profile.PlayerCardMeta[progress.ActiveProject.CardInstanceId]
		if meta and meta.CampaignProgression then meta.CampaignProgression.SeasonsCompleted = (tonumber(meta.CampaignProgression.SeasonsCompleted) or 0) + 1 end
		local lifetime = progress.ProjectLifetimeByCard[progress.ActiveProject.CardInstanceId]
		if type(lifetime) == "table" and promoted then lifetime.PromotedSeasons = (tonumber(lifetime.PromotedSeasons) or 0) + 1 end
		local pendingChoice = ProjectService.GeneratePendingUpgrade(profile)
		if pendingChoice then
			season.PendingProjectUpgrade = copy(pendingChoice)
			local presented = false
			for _, presentation in progress.PendingPresentation do
				if presentation.Id == pendingChoice.ChoiceId then presented = true break end
			end
			if not presented then table.insert(progress.PendingPresentation, 1, { Id = pendingChoice.ChoiceId, Type = "ProjectUpgrade", Data = copy(pendingChoice) }) end
		end
	end
	local history = {
		Type = "Season", SeasonId = season.SeasonId, DivisionId = division.Id, DivisionName = division.Name, SeasonNumber = season.SeasonNumber,
		StartedAt = season.StartedAt, CompletedAt = season.CompletedAt, Wins = season.Wins, Draws = season.Draws,
		Losses = season.Losses, Points = season.Points, GoalsFor = season.GoalsFor, GoalsAgainst = season.GoalsAgainst,
		Stars = season.Stars, Promoted = promoted, PerfectSeason = season.PerfectSeason,
		ManualMatches = season.ManualMatches, ManagerMatches = season.ManagerMatches,
		ProjectCardInstanceId = progress.ActiveProject and progress.ActiveProject.CardInstanceId or nil,
		ProjectUpgrades = progress.ActiveProject and copy(progress.ActiveProject.AppliedNodeIds) or {},
		ScoutingReward = season.PromotionRewardPlayer, FacilityPointsEarned = promotionReward and promotionReward.FacilityPoints or 0,
	}
	table.insert(progress.History, 1, history)
	while #progress.History > Config.HistoryLimit do table.remove(progress.History) end
end

function Service:_nextCTA(season: any): string
	if season.PendingProjectUpgrade then return "CHOOSE PROJECT UPGRADE" end
	if season.PendingPromotionChoice and season.PendingPromotionChoice.Claimed ~= true then return "CHOOSE PROMOTION PLAYER" end
	if season.Status == "Promoted" or season.Status == "Failed" then return "RETURN TO ASCENSION" end
	return "NEXT FIXTURE"
end

function Service:ChooseCampaignProjectUpgrade(player: Player, optionId: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local progressSnapshot = copy(progress)
	local metaSnapshot = copy(profile.PlayerCardMeta)
	local success, message = ProjectService.ChooseUpgrade(profile, optionId)
	if success then
		if progress.ActiveSeason then progress.ActiveSeason.PendingProjectUpgrade = progress.ActiveProject and progress.ActiveProject.PendingUpgradeChoice or nil end
		if progress.ActiveSeason then
			for _, history in progress.History do
				if history.SeasonId == progress.ActiveSeason.SeasonId then history.ProjectUpgrades = progress.ActiveProject and copy(progress.ActiveProject.AppliedNodeIds) or {} break end
			end
		end
		for index = #progress.PendingPresentation, 1, -1 do if progress.PendingPresentation[index].Type == "ProjectUpgrade" then table.remove(progress.PendingPresentation, index) end end
		if progress.ActiveProject and progress.ActiveProject.PendingUpgradeChoice then table.insert(progress.PendingPresentation, 1, { Id = progress.ActiveProject.PendingUpgradeChoice.ChoiceId, Type = "ProjectUpgrade", Data = copy(progress.ActiveProject.PendingUpgradeChoice) }) end
		if not self:_save(player, profile, true) then
			profile.CampaignProgress = progressSnapshot
			profile.PlayerCardMeta = metaSnapshot
			return false, "The Club Project upgrade could not be saved.", nil
		end
		analytics(player, "ascension_project_upgrade_selected", { Milestone = progress.ActiveProject and progress.ActiveProject.CurrentMilestone or 0 })
	end
	return success, message, self:GetCampaignState(player)
end

function Service:GenerateCampaignPromotionChoice(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local season = progress and progress.ActiveSeason
	if not profile or not season or season.Promoted ~= true then return false, "Win a promotion final first.", nil end
	if season.PendingPromotionChoice then return true, "Promotion shortlist already generated.", publicChoice(season.PendingPromotionChoice) end
	local promotionReward = season.PromotionReward
	if type(promotionReward) ~= "table" or promotionReward.FirstPromotion ~= true and (tonumber(promotionReward.RepeatTokens) or 0) < 3 then
		return false, "Three repeat-promotion tokens are required for another shortlist.", nil
	end
	local progressSnapshot = copy(progress)
	local choice = ScoutingService.Generate(profile, season, false)
	if not choice then return false, "A valid scouting shortlist could not be generated.", nil end
	choice.Repeat = promotionReward.FirstPromotion ~= true
	if not self:_save(player, profile, true) then
		profile.CampaignProgress = progressSnapshot
		return false, "The promotion shortlist could not be saved.", nil
	end
	analytics(player, "ascension_promotion_choice_generated", { Division = season.DivisionId })
	return true, "Promotion shortlist generated.", publicChoice(choice)
end

function Service:RerollCampaignPromotionChoice(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local season = progress and progress.ActiveSeason
	if not profile or not season then return false, "No active promotion choice.", nil end
	local progressSnapshot = copy(progress)
	local success, message, choice = ScoutingService.Reroll(profile, season)
	if success and not self:_save(player, profile, true) then
		profile.CampaignProgress = progressSnapshot
		return false, "The scouting reroll could not be saved.", nil
	end
	return success, message, choice and publicChoice(choice) or nil
end

function Service:ChooseCampaignPromotionPlayer(player: Player, playerId: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local season = progress and progress.ActiveSeason
	if not profile or not season then return false, "No promotion choice is available.", nil end
	local progressSnapshot = copy(progress)
	local repeatChoice = season.PendingPromotionChoice and season.PendingPromotionChoice.Repeat == true
	local success, message, card = ScoutingService.Claim(player, profile, season, playerId, self.Inventory)
	if success then
		if repeatChoice then progress.RepeatPromotionTokens[season.DivisionId] = math.max(0, (tonumber(progress.RepeatPromotionTokens[season.DivisionId]) or 0) - 3) end
		for _, history in progress.History do
			if history.SeasonId == season.SeasonId then history.ScoutingReward = copy(season.PromotionRewardPlayer) break end
		end
		for index = #progress.PendingPresentation, 1, -1 do if progress.PendingPresentation[index].Type == "PromotionChoice" then table.remove(progress.PendingPresentation, index) end end
		if not self:_save(player, profile, true) then
			profile.CampaignProgress = progressSnapshot
			return false, "The signing is protected and will be recovered. Try the choice again.", nil
		end
		analytics(player, "ascension_promotion_choice_claimed", { Division = season.DivisionId })
	end
	return success, message, success and { Card = card, State = self:GetCampaignState(player) } or nil
end

function Service:UpgradeCampaignFacility(player: Player, facilityId: string, requestId: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local progressSnapshot = copy(progress)
	local success, message, data = FacilityService.Upgrade(profile, facilityId, requestId)
	if success then
		if data.Replayed == true then return true, message, self:GetCampaignState(player) end
		local pendingChoice = ProjectService.GeneratePendingUpgrade(profile)
		if pendingChoice and progress.ActiveSeason then
			progress.ActiveSeason.PendingProjectUpgrade = copy(pendingChoice)
			local presented = false
			for _, presentation in progress.PendingPresentation do if presentation.Id == pendingChoice.ChoiceId then presented = true break end end
			if not presented then table.insert(progress.PendingPresentation, 1, { Id = pendingChoice.ChoiceId, Type = "ProjectUpgrade", Data = copy(pendingChoice) }) end
		end
		if not self:_save(player, profile, true) then
			profile.CampaignProgress = progressSnapshot
			return false, "The facility upgrade could not be saved. No points were spent.", nil
		end
		analytics(player, "ascension_facility_upgraded", { Facility = facilityId, Level = data.Level })
	end
	return success, message, success and self:GetCampaignState(player) or data
end

function Service:ApplyCampaignCounterPlan(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local season = progress and progress.ActiveSeason
	if not profile or not season then return false, "No active season.", nil end
	if progress.Facilities.tactical_lab < 3 then return false, "Upgrade Tactical Lab to level 3 first.", nil end
	local fixture = currentFixture(season)
	if not fixture then return false, "No fixture is ready.", nil end
	local previous = fixture.CounterPlanApplied
	fixture.CounterPlanApplied = true
	if not self:_save(player, profile, true) then
		fixture.CounterPlanApplied = previous
		return false, "The counter plan could not be saved.", nil
	end
	return true, fixture.CounterTactic .. " will be applied for this fixture only.", self:GetCampaignState(player)
end

function Service:AcknowledgeCampaignPresentation(player: Player, presentationId: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile or type(presentationId) ~= "string" or #presentationId > 128 then return false, "Invalid presentation.", nil end
	for index, item in progress.PendingPresentation do
		if item.Id == presentationId then
			table.remove(progress.PendingPresentation, index)
			if not self:_save(player, profile, true) then
				table.insert(progress.PendingPresentation, index, item)
				return false, "The acknowledgement could not be saved.", nil
			end
			return true, "Presentation acknowledged.", self:GetCampaignState(player)
		end
	end
	return false, "Presentation is no longer pending.", self:GetCampaignState(player)
end

function Service:GetCampaignHistory(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	return true, "Ascension history loaded.", { History = copy(progress.History), DivisionRecords = copy(progress.DivisionRecords), ProjectHistory = publicProjectHistory(progress.ProjectHistory) }
end

local function weekKey(): string
	return os.date("!%Y-W%W", os.time())
end

function Service:GetCampaignMastery(player: Player): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local now = os.time()
	local utc = os.date("!*t", now)
	local days = (8 - utc.wday) % 7
	local reset = now + days * 86400 + (24 - utc.hour) * 3600 - utc.min * 60 - utc.sec
	local tacticalLab = math.clamp(math.floor(tonumber(progress.Facilities.tactical_lab) or 0), 0, 3)
	return true, "Mastery contracts loaded.", { Unlocked = progress.Mastery.Unlocked == true, WeekKey = weekKey(), Active = publicMasteryActive(progress.Mastery.Active, tacticalLab), History = publicMasteryHistory(progress.Mastery.History), Definitions = self:_publicMasteryDefinitions(), ResetsAt = reset }
end

function Service:StartCampaignMastery(player: Player, contractId: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	if not profile or not progress.Mastery.Unlocked then return false, "Win Voltra Masters to unlock Mastery Contracts.", nil end
	if type(contractId) ~= "string" or #contractId > 48 or not Config.MasteryContracts[contractId] then return false, "Choose a valid Mastery Contract.", nil end
	local key = weekKey()
	if progress.Mastery.CompletedWeeks[key] then return false, "This week's Mastery reward is already complete.", nil end
	if progress.Mastery.Active and progress.Mastery.Active.WeekKey == key then return false, "A Mastery Contract is already active this week.", copy(progress.Mastery.Active) end
	local ready, message, roster = self:_readyRoster(player)
	if not ready then return false, message, { Navigate = "Squad" } end
	local fixtures = SeasonGenerator.CreateMasteryFixtures(player.UserId, contractId, key, roster.Team.overall, roster.Team.teamId)
	if not fixtures then return false, "A valid deterministic Mastery schedule is unavailable for this squad.", nil end
	local candidate = { ContractId = contractId, Formations = {}, FormationByFixture = {} }
	local valid, validation = self:_validateMasteryRoster(profile, candidate, roster, fixtures[1])
	if not valid then return false, validation, nil end
	local previousActive = copy(progress.Mastery.Active)
	progress.Mastery.Active = { WeekKey = key, ContractId = contractId, StartedAt = os.time(), Fixtures = fixtures, CurrentIndex = 1, Wins = 0, Completed = false, Succeeded = false, Formations = {}, FormationByFixture = {}, SquadOverallAtStart = roster.Team.overall }
	if not self:_save(player, profile, true) then
		progress.Mastery.Active = previousActive
		return false, "The Mastery Contract could not be saved.", nil
	end
	analytics(player, "ascension_mastery_started", { Contract = contractId })
	return true, "Mastery Contract started.", self:GetCampaignState(player)
end

function Service:_validateMasteryRoster(profile: any, active: any, roster: any, fixture: any?): (boolean, string)
	local definition = Config.MasteryContracts[active.ContractId]
	if type(definition) ~= "table" or type(definition.Rules) ~= "table" then return false, "This Mastery Contract is no longer available." end
	local rules = definition.Rules
	if rules.MaximumAverageAge then
		local total = 0
		for _, player in roster.StartingXI do total += tonumber(player.age) or 30 if (tonumber(player.overall) or 99) > rules.MaximumOverall then return false, "Youth Revolution OVR cap is not met." end end
		if total / 11 > rules.MaximumAverageAge then return false, "Youth Revolution requires a Starting XI average age of 23 or younger." end
	end
	if rules.SameNationStarters then
		local countries = {}
		for _, player in roster.StartingXI do local country = tostring(player.country or player.nationality or "") countries[country] = (countries[country] or 0) + 1 end
		local best = 0 for _, count in countries do best = math.max(best, count) end
		if best < rules.SameNationStarters then return false, "National Core requires seven starters from one nation." end
	end
	if rules.ExcludeProtectedCardTypes then
		for _, player in roster.StartingXI do if protectedClass(player.cardType) or protectedClass(player.rarity) then return false, "No Superstars excludes top-end special cards." end end
	end
	if rules.OpponentMinimumDelta and fixture then
		local delta = (tonumber(fixture.OpponentOverall) or 0) - (tonumber(roster.Team.overall) or 0)
		if delta < rules.OpponentMinimumDelta or delta > rules.OpponentMaximumDelta then return false, "Giant Killer requires an opponent five to eight OVR above your current squad." end
	end
	if rules.UniqueFormations and fixture then
		active.Formations = type(active.Formations) == "table" and active.Formations or {}
		active.FormationByFixture = type(active.FormationByFixture) == "table" and active.FormationByFixture or {}
		local lockedFormation = active.FormationByFixture[fixture.FixtureId]
		if lockedFormation and lockedFormation ~= roster.Formation then return false, "This Mastery fixture is locked to " .. lockedFormation .. "." end
		if not lockedFormation and table.find(active.Formations, roster.Formation) then return false, "Tactical Master requires a new formation for every fixture." end
	end
	return true, "Mastery roster validated."
end

function Service:StartCampaignMasteryFixture(player: Player, mode: string): (boolean, string, any?)
	local profile, progress = self:_profile(player)
	local active = progress and progress.Mastery.Active
	if not profile or not active or active.Completed then return false, "No active Mastery fixture.", nil end
	if progress.ActiveProject and progress.ActiveProject.PendingUpgradeChoice then return false, "Resolve your Club Project upgrade before the next fixture.", self:GetCampaignState(player) end
	local ready, message, roster = self:_readyRoster(player)
	if not ready then return false, message, nil end
	if type(active.Fixtures) ~= "table" then return false, "Mastery Contract fixtures are unavailable.", nil end
	local fixture = active.Fixtures[math.max(1, math.floor(tonumber(active.CurrentIndex) or 1))]
	if not fixture then return false, "Mastery Contract has no remaining fixtures.", nil end
	local valid, validation = self:_validateMasteryRoster(profile, active, roster, fixture)
	if not valid then return false, validation, nil end
	local formationAdded = false
	if Config.MasteryContracts[active.ContractId].Rules.UniqueFormations and not active.FormationByFixture[fixture.FixtureId] then
		active.FormationByFixture[fixture.FixtureId] = roster.Formation
		table.insert(active.Formations, roster.Formation)
		formationAdded = true
	end
	local success, launchMessage, data = self:_startFixture(player, profile, progress, fixture, mode, false, true)
	if not success and formationAdded and type(progress.PendingMatch) ~= "table" then
		active.FormationByFixture[fixture.FixtureId] = nil
		for index = #active.Formations, 1, -1 do
			if active.Formations[index] == roster.Formation then table.remove(active.Formations, index) break end
		end
		self:_save(player, profile, true)
	end
	return success, launchMessage, data
end

function Service:_commitMastery(player: Player, profile: any, progress: any, pending: any, fixture: any, active: any, result: string, scoreFor: number, scoreAgainst: number, stats: any, ledgerKey: string, managerQualified: boolean): any
	local nextWins = (tonumber(active.Wins) or 0) + (result == "Win" and 1 or 0)
	local nextIndex = (tonumber(active.CurrentIndex) or 1) + 1
	local definition = Config.MasteryContracts[active.ContractId]
	local finished = nextIndex > definition.FixtureCount
	local requiredWins = tonumber(definition.Rules.RequiredWins) or 0
	local succeeded = finished and nextWins >= requiredWins
	local rewardSeason = { DivisionId = Config.Divisions[6].Id, PromotionFinalAttempts = 1 }
	local rewardFixture = { Mode = pending.Mode, IsPromotionFinal = false, IsRecovery = false }
	local breakdown = RewardService.Calculate(profile, rewardSeason, rewardFixture, result, false, managerQualified)
	local reward = self.Progression:GrantMatchRewards(player, { Title = "MASTERY FIXTURE", Coins = breakdown.PreVIPCoins, XP = breakdown.PreVIPXP, TransactionId = "ascension:mastery:fixture:" .. pending.PendingId })
	if not reward then return nil end
	breakdown.GrantedCoins = reward.Coins
	breakdown.GrantedXP = reward.XP
	local completionCoins = nil
	local completionProjectXP = 0
	local completionFacilityPoints = 0
	if succeeded and definition.Reward.Coins then
		completionCoins = self.Progression:GrantMatchRewards(player, { Title = "MASTERY COMPLETE", Coins = definition.Reward.Coins, XP = 0, TransactionId = "ascension:mastery:complete:" .. active.WeekKey })
		if not completionCoins then return nil end
	end
	fixture.Played = true fixture.Result = result fixture.HomeScore = scoreFor fixture.AwayScore = scoreAgainst fixture.PlayedAt = os.time()
	active.Wins = nextWins
	active.CurrentIndex = nextIndex
	if finished then
		active.Completed = true
		active.Succeeded = succeeded
		active.CompletedAt = os.time()
		local contractReward = definition.Reward
		if succeeded then
			if contractReward.ProjectXP and progress.ActiveProject then completionProjectXP = ProjectService.GrantXP(profile, contractReward.ProjectXP, "mastery:" .. active.WeekKey) end
			if contractReward.FacilityPoints then
				local facilityKey = "mastery:" .. active.WeekKey
				if progress.FacilityLedger[facilityKey] ~= true then
					completionFacilityPoints = math.max(0, math.floor(tonumber(contractReward.FacilityPoints) or 0))
					progress.FacilityPoints += completionFacilityPoints
					progress.FacilityLedger[facilityKey] = true
				end
			end
			if contractReward.ItemId then
				profile.Inventory.Items = profile.Inventory.Items or {}
				local found = nil
				for _, item in profile.Inventory.Items do if item.Id == contractReward.ItemId and item.Kind == "Consumable" then found = item break end end
				if found then found.Quantity = (tonumber(found.Quantity) or 0) + (contractReward.Amount or 1) else table.insert(profile.Inventory.Items, { Id = contractReward.ItemId, Kind = "Consumable", Quantity = contractReward.Amount or 1, AcquiredAt = os.time() }) end
			end
			if contractReward.CosmeticId then profile.StoreOwnership.Cosmetics = profile.StoreOwnership.Cosmetics or {} if not table.find(profile.StoreOwnership.Cosmetics, contractReward.CosmeticId) then table.insert(profile.StoreOwnership.Cosmetics, contractReward.CosmeticId) end end
			progress.Mastery.CompletedWeeks[active.WeekKey] = true
		end
		table.insert(progress.Mastery.History, 1, copy(active))
		while #progress.Mastery.History > Config.HistoryLimit do table.remove(progress.Mastery.History) end
		analytics(player, succeeded and "ascension_mastery_completed" or "ascension_mastery_failed", { Contract = active.ContractId, Wins = active.Wins })
	end
	local payload = { Title = finished and (succeeded and "MASTERY COMPLETE" or "MASTERY FAILED") or "MASTERY " .. result:upper(), CampaignAscension = true, Mastery = true, Result = result, Home = scoreFor, Away = scoreAgainst, Coins = reward.Coins + (completionCoins and completionCoins.Coins or 0), XP = reward.XP, RewardBreakdown = breakdown, Contract = active.ContractId, ContractCompleted = active.Completed, ContractSucceeded = active.Succeeded, Wins = active.Wins, RequiredWins = requiredWins, ProjectXP = completionProjectXP, FacilityPoints = completionFacilityPoints, MasteryReward = succeeded and copy(definition.Reward) or nil, NextCTA = active.Completed and "RETURN TO ASCENSION" or "NEXT MASTERY FIXTURE" }
	progress.ResultLedger[ledgerKey] = { CommittedAt = os.time(), Payload = copy(payload) }
	progress.PendingMatch = nil
	self.Profiles:RecordMatchResult(player, "Campaign", ledgerKey, result, { Mastery = true, Contract = active.ContractId })
	self:_save(player, profile, true)
	return payload
end

function Service:_dispatchAction(player: Player, action: string, payload: any): (boolean, string, any?)
	if action == "GetCampaignState" then
		local data = self:GetCampaignState(player)
		if data and self.PageViewed[player] ~= true then
			self.PageViewed[player] = true
			analytics(player, "ascension_page_view", {
				Division = data.CurrentDivision and data.CurrentDivision.Id or data.HighestUnlockedDivision,
				Season = data.ActiveSeason and data.ActiveSeason.SeasonNumber or 0,
			})
		end
		return data ~= nil, data and "Ascension loaded." or "Ascension unavailable.", data
	elseif action == "GetCampaignEligibleProjects" then return self:GetCampaignEligibleProjects(player)
	elseif action == "StartCampaignPlacement" then return self:StartCampaignPlacement(player, payload.Mode)
	elseif action == "StartCampaignSeason" then return self:StartCampaignSeason(player)
	elseif action == "ChooseCampaignScoutingFocus" then return self:ChooseCampaignScoutingFocus(player, tostring(payload.Focus or ""))
	elseif action == "SelectCampaignProject" then return self:SelectCampaignProject(player, tostring(payload.CardInstanceId or ""))
	elseif action == "SkipCampaignProject" then return self:SkipCampaignProject(player)
	elseif action == "RetireCampaignProject" then return self:RetireCampaignProject(player)
	elseif action == "StartCampaignFixture" then return self:StartCampaignFixture(player, tostring(payload.Mode or ""))
	elseif action == "ResumeCampaignMatch" then return self:ResumeCampaignMatch(player)
	elseif action == "ChooseCampaignProjectUpgrade" then return self:ChooseCampaignProjectUpgrade(player, tostring(payload.OptionId or ""))
	elseif action == "GenerateCampaignPromotionChoice" then return self:GenerateCampaignPromotionChoice(player)
	elseif action == "RerollCampaignPromotionChoice" then return self:RerollCampaignPromotionChoice(player)
	elseif action == "ChooseCampaignPromotionPlayer" then return self:ChooseCampaignPromotionPlayer(player, tostring(payload.PlayerId or ""))
	elseif action == "UpgradeCampaignFacility" then return self:UpgradeCampaignFacility(player, tostring(payload.FacilityId or ""), tostring(payload.RequestId or ""))
	elseif action == "ApplyCampaignCounterPlan" then return self:ApplyCampaignCounterPlan(player)
	elseif action == "AcknowledgeCampaignPresentation" then return self:AcknowledgeCampaignPresentation(player, tostring(payload.PresentationId or ""))
	elseif action == "GetCampaignHistory" then return self:GetCampaignHistory(player)
	elseif action == "GetCampaignMastery" then return self:GetCampaignMastery(player)
	elseif action == "StartCampaignMastery" then return self:StartCampaignMastery(player, tostring(payload.ContractId or ""))
	elseif action == "StartCampaignMasteryFixture" then return self:StartCampaignMasteryFixture(player, tostring(payload.Mode or ""))
	end
	return false, "Unsupported Campaign action.", nil
end

function Service:Handle(player: Player, action: string, payload: any): (boolean, string, any?)
	payload = type(payload) == "table" and payload or {}
	if type(action) ~= "string" or #action > 48 then return false, "Invalid Campaign action.", nil end
	local now = os.clock()
	local playerActions = self.LastActions[player] or {}
	self.LastActions[player] = playerActions
	local cooldown = READ_ACTIONS[action] and 0.1 or 0.45
	if now - (playerActions[action] or 0) < cooldown then return false, "Please wait.", nil end
	playerActions[action] = now
	if not READ_ACTIONS[action] and self.TransactionLocks[player] then return false, "Another Ascension action is still processing.", nil end
	if not READ_ACTIONS[action] then self.TransactionLocks[player] = true end
	local ok, success, message, data = pcall(self._dispatchAction, self, player, action, payload)
	if not READ_ACTIONS[action] then self.TransactionLocks[player] = nil end
	if not ok then
		warn("[VTR ASCENSION] " .. action .. " failed for " .. player.UserId .. ": " .. tostring(success))
		return false, "Ascension could not complete that action. Please try again.", nil
	end
	return success, message, data
end

return Service
