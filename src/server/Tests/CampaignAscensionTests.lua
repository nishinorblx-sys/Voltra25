--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local Resolver = require(ReplicatedStorage.VTR.Shared.CardProgressionResolver)
local Migration = require(script.Parent.Parent.Services.CampaignMigration)
local Generator = require(script.Parent.Parent.Services.CampaignSeasonGenerator)
local Objective = require(script.Parent.Parent.Services.CampaignObjectiveEvaluator)
local Scouting = require(script.Parent.Parent.Services.CampaignScoutingService)
local Project = require(script.Parent.Parent.Services.CampaignProjectService)
local Facility = require(script.Parent.Parent.Services.CampaignFacilityService)
local Reward = require(script.Parent.Parent.Services.CampaignRewardService)
local Ascension = require(script.Parent.Parent.Services.CampaignAscensionService)
local PlayerDatabase = require(script.Parent.Parent.Data.PlayerDatabase)
local TeamDatabase = require(script.Parent.Parent.Data.TeamDatabase)
local LegacyConfig = require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)

local Tests = {}

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[clone(key)] = clone(child) end
	return result
end

local function equal(left: any, right: any, seen: any?): boolean
	if left == right then return true end
	if type(left) ~= "table" or type(right) ~= "table" then return false end
	seen = seen or {}
	if seen[left] == right then return true end
	seen[left] = right
	for key, value in left do if not equal(value, right[key], seen) then return false end end
	for key in right do if left[key] == nil then return false end end
	return true
end

local function expect(condition: any, message: string)
	if not condition then error(message, 2) end
end

local function expectEqual(actual: any, expected: any, message: string)
	if actual ~= expected then error(message .. " | expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function newProfile(): any
	local profile = {
		CampaignProgress = Config.CreateProgress(),
		PlayerCardInventory = {}, PlayerCardMeta = {}, PackInventory = {}, InventoryGrantLedger = {}, RewardTransactionLedger = {},
		Inventory = { Items = {} }, StoreOwnership = { GamePasses = {}, Cosmetics = {} },
		Currency = { Coins = 0, Bolts = 0, VoltraPoints = 0 }, Profile = { Level = 1, XP = 0, SelectedClub = "TEST", Avatar = { UserId = 0, HeadshotType = "HeadShot", OutfitId = 0 } },
		Season = { Name = "TEST", Level = 1, XP = 0, RequiredXP = 1000 }, ClubMembership = { ClubName = "TEST CLUB" },
		Squad = {}, Bench = {}, Reserves = {}, TeamTactics = {}, MatchSetup = {},
	}
	Migration.Normalize(profile, 1000)
	return profile
end

local function fixtureSignature(season: any): string
	local values = {}
	for _, fixture in season.LeagueFixtures do table.insert(values, fixture.OpponentTeamId .. ":" .. fixture.ObjectiveId .. ":" .. fixture.TacticIdentity) end
	table.insert(values, season.PromotionFinal.OpponentTeamId)
	return table.concat(values, "|")
end

local function eligibleDefinition(): any
	for _, definition in PlayerDatabase.Players do
		local validPositions = Config.Project.ValidAddedPositions[definition.bestPosition] or {}
		local hasNewPosition = false
		for _, position in validPositions do if not table.find(definition.positions, position) then hasNewPosition = true break end end
		if definition.overall <= Config.Project.MaximumBaseOverall and definition.cardType == "Base" and not Config.Project.ProtectedCardTypes[definition.rarity] and definition.bestPosition ~= "GK" and hasNewPosition then return definition end
	end
	error("No eligible project definition exists")
end

local function cardFrom(definition: any, id: string): any
	local card = clone(definition)
	card.Id = id
	card.cardInstanceId = id
	card.BaseOverall = definition.overall
	card.Rating = definition.overall
	return card
end

local function mockCommit(result: string, configure: ((any, any, any) -> ())?): any
	local profile = newProfile()
	local ownTeam = TeamDatabase.Teams[1]
	local roster = TeamDatabase.GetRoster(ownTeam.teamId)
	local season = Generator.CreateSeason(7711, 2, 1, ownTeam.teamId)
	expect(season ~= nil, "Commit test season was not generated")
	season.ScoutingFocus = "Any Position"
	season.ProjectDecision = "Skipped"
	season.Status = "Active"
	local fixture = season.LeagueFixtures[1]
	fixture.Mode = "Manual"
	fixture.ObjectiveId = "completed_passes"
	fixture.ObjectiveTitle = Config.Objectives.completed_passes.Title
	fixture.ObjectiveDescription = Config.Objectives.completed_passes.Description
	fixture.ObjectiveMetric = "PassesCompleted"
	fixture.ObjectiveTarget = 25
	profile.CampaignProgress.Placement.Completed = true
	profile.CampaignProgress.ActiveSeason = season
	local pending = {
		PendingId = "pending_" .. result, SeasonId = season.SeasonId, FixtureId = fixture.FixtureId, DivisionId = season.DivisionId,
		Mode = "Manual", CreatedAt = os.time(), ExpiresAt = os.time() + 600, ResultState = "Pending", Placement = false, Mastery = false,
		SquadOverall = roster.Team.overall, ProjectCardInstanceId = nil, SetupSnapshot = { OpponentTeamId = fixture.OpponentTeamId },
	}
	profile.CampaignProgress.PendingMatch = pending
	if configure then configure(profile, season, fixture) end
	local profiles: any = { RecordCalls = 0, SaveCalls = 0 }
	function profiles:GetProfile(_player: any): any return profile end
	function profiles:Save(_player: any, _force: boolean?): boolean self.SaveCalls += 1 return true end
	function profiles:RecordMatchResult(_player: any, _mode: string, _id: string, _result: string, _metadata: any): boolean self.RecordCalls += 1 return true end
	local progression: any = { Calls = 0 }
	function progression:GrantMatchRewards(_player: any, payload: any): any
		profile.RewardTransactionLedger = profile.RewardTransactionLedger or {}
		local previous = profile.RewardTransactionLedger[payload.TransactionId]
		if previous then return clone(previous) end
		self.Calls += 1
		local granted = { Coins = math.floor(tonumber(payload.Coins) or 0), XP = math.floor(tonumber(payload.XP) or 0), Vip2x = false }
		profile.Currency.Coins += granted.Coins
		profile.RewardTransactionLedger[payload.TransactionId] = clone(granted)
		return granted
	end
	function progression:GetClientData(_player: any): any return {} end
	local inventory: any = { PackCalls = 0 }
	function inventory:AddPack(_player: any, _packId: string, _name: string, _source: string, _amount: number, transactionId: string): (boolean, any)
		if profile.InventoryGrantLedger[transactionId] then return true, profile.InventoryGrantLedger[transactionId] end
		self.PackCalls += 1
		profile.InventoryGrantLedger[transactionId] = { "pack" .. self.PackCalls }
		return true, profile.InventoryGrantLedger[transactionId]
	end
	function inventory:AddCard(_player: any, definition: any, _metadata: any): (boolean, any)
		local card = cardFrom(definition, "commit_scouting_" .. tostring(#profile.PlayerCardInventory + 1))
		table.insert(profile.PlayerCardInventory, card)
		return true, card
	end
	local ranked: any = {}
	function ranked:GetRoster(_player: any): (boolean, string, any) return true, "Ready", roster end
	local service = Ascension.new(profiles, function() end, progression, inventory, ranked)
	local player = { UserId = 7711, Name = "AscensionTest", DisplayName = "AscensionTest" }
	local scores = result == "Win" and { 3, 1 } or result == "Draw" and { 2, 2 } or { 0, 2 }
	local statsObject: any = {}
	function statsObject:Serialize(homeScore: number, awayScore: number, _seconds: number): any
		return {
			HomeScore = homeScore, AwayScore = awayScore,
			Home = { PassesCompleted = 30, Shots = 8, ShotsOnTarget = 5, TacklesCompleted = 4, Possession = 55, Corners = 2, Fouls = 1 },
			Away = { PassesCompleted = 20, Shots = 4, ShotsOnTarget = 2, TacklesCompleted = 2, Possession = 45, Corners = 1, Fouls = 2 },
			PlayerRatings = {},
		}
	end
	local clock: any = {}
	function clock:Payload(): any return { GameSeconds = 180, Half = 2 } end
	local session = {
		CampaignAscension = { PendingId = pending.PendingId, SeasonId = pending.SeasonId, FixtureId = pending.FixtureId },
		MatchId = "match_" .. result, World = { HomeScore = { Value = scores[1] }, AwayScore = { Value = scores[2] }, Folder = { Name = "folder" } },
		Stats = statsObject, Clock = clock, Ended = true, PenaltyShootoutWinner = nil, CampaignManager = {},
	}
	return { Profile = profile, Season = season, Fixture = fixture, Pending = pending, Profiles = profiles, Progression = progression, Inventory = inventory, Service = service, Player = player, Session = session }
end

local function publicState(status: string?, variant: string?): any
	local season = Generator.CreateSeason(8899, 2, 4, nil)
	expect(season ~= nil, "UI season was not generated")
	season.Status = status or "Active"
	season.ScoutingFocus = "Any Position"
	season.ProjectDecision = "Skipped"
	local current = season.LeagueFixtures[1]
	if variant == "Recovery" then season.Status = "Recovery" current = clone(current) current.IsRecovery = true season.RecoveryFixtures = { current }
	elseif variant == "Final" then season.Status = "PromotionFinal" current = season.PromotionFinal
	elseif variant == "Project" then season.PendingProjectUpgrade = { ChoiceId = "project", Milestone = 3, Options = {} }
	elseif variant == "Signing" then season.PendingPromotionChoice = { ChoiceId = "signing", Claimed = false, Options = {} }
	elseif variant == "Focus" then season.ScoutingFocus = nil
	elseif variant == "ProjectDecision" then season.ProjectDecision = nil end
	local divisions = {}
	for _, division in Config.Divisions do table.insert(divisions, { Id = division.Id, Name = division.Name, Index = division.Index, Accent = division.Accent, PromotionThreshold = Config.PromotionThreshold, ScoutingMin = division.ScoutingMin, ScoutingMax = division.ScoutingMax, ScoutingChoices = division.ScoutingChoices, Unlocked = true }) end
	return {
		Title = Config.UI.Title, Subtitle = Config.UI.Subtitle, Placement = { Completed = true }, HighestUnlockedDivision = 2,
		CurrentDivision = { Id = Config.Divisions[2].Id, Name = Config.Divisions[2].Name, Index = 2 }, ActiveSeason = season,
		CurrentFixture = current, DivisionRecords = Config.CreateProgress().DivisionRecords, Facilities = {}, FacilityPoints = 0,
		ActiveProject = nil, ActiveProjectCard = nil, ProjectHistory = {}, RepeatPromotionTokens = {}, History = {},
		Mastery = { Unlocked = false }, AscensionChampion = false, PendingPresentation = {}, HasPendingMatch = variant == "Pending",
		SquadReady = true, SquadMessage = "Ready", Squad = { ClubName = "TEST CLUB", Overall = 72, Chemistry = 24, Formation = "4-3-3", Colors = {} },
		Divisions = divisions, ScoutingFocuses = clone(Config.ScoutingFocusOrder), StarMilestones = clone(Config.StarMilestones), MasteryDefinitions = {}, Copy = clone(Config.UI),
	}
end

function Tests.Run(): any
	local results = { Passed = 0, Failed = 0, Failures = {}, Names = {} }
	local function test(name: string, callback: () -> ())
		local ok, message = pcall(callback)
		table.insert(results.Names, name)
		if ok then results.Passed += 1 else results.Failed += 1 table.insert(results.Failures, name .. ": " .. tostring(message)) end
	end

	test("client campaign service loads", function()
		local vtr = ReplicatedStorage:FindFirstChild("VTR")
		local remotes = vtr:FindFirstChild(NetworkConfig.FolderName) or Instance.new("Folder")
		remotes.Name = NetworkConfig.FolderName
		remotes.Parent = vtr
		local remote = remotes:FindFirstChild(NetworkConfig.MatchFunction) or Instance.new("RemoteFunction")
		remote.Name = NetworkConfig.MatchFunction
		remote.Parent = remotes
		local clientService = require(StarterPlayer.StarterPlayerScripts.VTRClient.Services.CampaignService)
		expect(type(clientService.GetState) == "function" and type(clientService.UpgradeFacility) == "function", "Client Campaign service did not load")
	end)

	test("progression payload sanitizes campaign ledgers", function()
		local progress = Config.CreateProgress()
		progress.ResultLedger.secret = { Reward = 999999 }
		progress.PendingMatch = { PendingId = "private", ResultState = "Pending" }
		progress.ActiveSeason = { DivisionId = "academy_circuit", SeasonNumber = 1, Status = "Active", Points = 4, Stars = 2, RewardLedger = { secret = true } }
		local payload = Migration.ClientSummary(progress)
		expect(payload.HasPendingMatch == true, "Campaign summary lost pending status")
		expect(payload.ResultLedger == nil, "Result ledger leaked to client")
		expect(payload.PendingMatch == nil, "Pending match internals leaked to client")
		expect(payload.ActiveSeason.RewardLedger == nil, "Season reward ledger leaked to client")
		local profile = newProfile()
		profile.CampaignProgress.ProjectHistory = { { PlayerName = "TEST PROJECT", AppliedNodeIds = {}, XPGrantLedger = { secret = true } } }
		profile.CampaignProgress.Mastery.CompletedWeeks.secret = true
		profile.CampaignProgress.Mastery.Active = { WeekKey = "2099-W01", ContractId = "tactical_master", CurrentIndex = 1, Wins = 0, Completed = false, Succeeded = false, Fixtures = {}, FormationByFixture = { secret = "4-3-3" }, Formations = { "4-3-3" } }
		local profiles: any = {}
		function profiles:GetProfile(_player: any): any return profile end
		function profiles:Save(_player: any, _force: boolean?): boolean return true end
		local service = Ascension.new(profiles, function() end, {}, {}, {})
		local historyOk, _, history = service:GetCampaignHistory({ UserId = 1 } :: any)
		expect(historyOk and history.ProjectHistory[1].XPGrantLedger == nil, "Retired Project grant ledger leaked to client")
		local masteryOk, _, mastery = service:GetCampaignMastery({ UserId = 1 } :: any)
		expect(masteryOk and mastery.Active.FormationByFixture == nil and mastery.CompletedWeeks == nil, "Mastery anti-replay state leaked to client")
	end)

	test("migration fresh profile", function()
		local profile = {}
		local progress, changed = Migration.Normalize(profile, 101)
		expect(changed, "Fresh migration must report a change")
		expectEqual(progress.MigrationVersion, Config.ProfileMigrationVersion, "Migration version")
		expect(not progress.Placement.Completed, "Fresh profiles require placement")
		expectEqual(progress.FacilityPoints, 0, "Fresh facility points")
	end)

	test("migration legacy levels and idempotency", function()
		local tier = LegacyConfig.CampaignDifficulties[8]
		local completed = {}
		for index = 1, 5 do completed[tier.Id .. "_opponent_" .. index] = true end
		local profile = { CampaignProgress = { UnlockedDifficulty = 9, CompletedTeams = completed, RewardsClaimed = { ["campaign_tier_clear_" .. tier.Id] = true } } }
		local progress = Migration.Normalize(profile, 202)
		expect(progress.Placement.Completed, "Legacy profile should skip placement")
		expect(progress.HighestUnlockedDivision >= 5, "Legacy access floor was lost")
		expectEqual(progress.Legacy.HighestClearedLegacyTier, 8, "Legacy highest clear")
		expectEqual(progress.FacilityPoints, 4, "Legacy facility formula")
		expect(progress.DivisionRecords.national_division.LegacyCleared, "Legacy clear record missing")
		local historyCount = #progress.History
		local points = progress.FacilityPoints
		local _, changedAgain = Migration.Normalize(profile, 303)
		expect(not changedAgain, "Second normalized migration should be stable")
		expectEqual(progress.FacilityPoints, points, "Migration duplicated points")
		expectEqual(#progress.History, historyCount, "Migration duplicated history")
	end)

	test("migration malformed and max legacy", function()
		local malformed = { CampaignProgress = "invalid" }
		local normalized = Migration.Normalize(malformed, 404)
		expect(type(normalized.DivisionRecords) == "table", "Malformed profile was not repaired")
		local finalTier = LegacyConfig.CampaignDifficulties[12]
		local profile = { CampaignProgress = { UnlockedDifficulty = 12, CompletedTeams = false, RewardsClaimed = { ["campaign_tier_clear_" .. finalTier.Id] = true }, Facilities = "bad", History = "bad" } }
		local progress = Migration.Normalize(profile, 505)
		expectEqual(progress.HighestUnlockedDivision, 6, "Max legacy division")
		expectEqual(progress.FacilityPoints, 6, "Max legacy facility points")
		expectEqual(progress.Legacy.HighestClearedLegacyTier, 12, "Max legacy clear")
	end)

	test("season generation deterministic and valid", function()
		local own = TeamDatabase.Teams[1].teamId
		local first = Generator.CreateSeason(12345, 3, 7, own)
		local second = Generator.CreateSeason(12345, 3, 7, own)
		local other = Generator.CreateSeason(54321, 3, 7, own)
		expect(first and second and other, "Season generation failed")
		expectEqual(first.Seed, second.Seed, "Stable seed")
		expectEqual(fixtureSignature(first), fixtureSignature(second), "Stable schedule")
		expect(first.Seed ~= other.Seed, "Different users share a seed")
		expectEqual(#first.LeagueFixtures, Config.LeagueFixtureCount, "League fixture count")
		local seen = {}
		for _, fixture in first.LeagueFixtures do
			expect(not seen[fixture.OpponentTeamId], "Duplicate league opponent")
			expect(fixture.OpponentTeamId ~= own, "Own team selected")
			expect(TeamDatabase.GetRoster(fixture.OpponentTeamId) ~= nil, "Invalid opponent roster")
			expect(Config.Objectives[fixture.ObjectiveId].Modes.Manual == true, "Incompatible manual objective")
			seen[fixture.OpponentTeamId] = true
		end
		expect(not seen[first.PromotionFinal.OpponentTeamId], "Promotion opponent duplicated")
		Generator.LockModeObjective(first.LeagueFixtures[1], "Manage", first.Seed)
		expect(Config.Objectives[first.LeagueFixtures[1].ObjectiveId].Modes.Manage == true, "Incompatible manager objective")
	end)

	test("season generation covers widening placement recovery and mastery", function()
		for index = 1, #Config.Divisions do
			local season = Generator.CreateSeason(4000 + index, index, 1, nil)
			expect(season ~= nil, "Division " .. index .. " has no valid widened schedule")
			local division = Config.Divisions[index]
			for _, fixture in season.LeagueFixtures do
				expect(fixture.OpponentOverall >= division.MinOverall - 30 and fixture.OpponentOverall <= division.MaxOverall + 30, "Opponent escaped widening bounds")
			end
			local recovery = Generator.CreateRecovery(season, nil)
			expectEqual(#recovery, Config.RecoveryFixtureCount, "Recovery fixture count")
		end
		expect(Generator.CreatePlacement(99, 72, nil) ~= nil, "Placement generation failed")
		local giant = nil
		local squadOverall = 0
		for overall = 45, 92 do
			giant = Generator.CreateMasteryFixtures(9090, "giant_killer", "2026-W27", overall, nil)
			if giant then squadOverall = overall break end
		end
		expect(giant ~= nil and #giant == 3, "Giant Killer schedule unavailable")
		local seen = {}
		for _, fixture in giant do
			local delta = fixture.OpponentOverall - squadOverall
			expect(delta >= 5 and delta <= 8, "Giant Killer OVR delta invalid")
			expect(not seen[fixture.OpponentTeamId], "Giant Killer duplicate")
			seen[fixture.OpponentTeamId] = true
		end
	end)

	test("resolver applies progression without mutation", function()
		local card = { overall = 88, Rating = 88, bestPosition = "CM", positions = { "CM" }, weakFoot = 4, skillMoves = 4, mainStats = { PAC = 98, PAS = 80 }, detailedStats = { vision = 97 }, playStyles = { "Base Style" } }
		local original = clone(card)
		local meta = { CampaignProgression = { OverallBoost = 5, MainStatBoosts = { PAC = 8, PAS = 4 }, DetailedStatBoosts = { vision = 8 }, AddedPositions = { "CAM", "CM" }, WeakFootBoost = 3, SkillMovesBoost = 3, PlayStyles = { "Threaded", "Base Style" }, CampaignBound = true, VisualTier = "AscendedII" } }
		local resolved = Resolver.Resolve(card, meta)
		expect(equal(card, original), "Resolver mutated base card")
		expectEqual(resolved.Rating, 90, "Effective OVR cap")
		expectEqual(resolved.mainStats.PAC, 99, "Main stat cap")
		expectEqual(resolved.detailedStats.vision, 99, "Detailed stat cap")
		expect(table.find(resolved.positions, "CAM") ~= nil, "Added position missing")
		expectEqual(resolved.weakFoot, 5, "Weak-foot cap")
		expectEqual(resolved.skillMoves, 5, "Skill cap")
		expect(resolved.CampaignBound and resolved.QuickSellBlocked and resolved.TransferBlocked, "Bound protection missing")
		expect(equal(resolved, Resolver.Resolve(card, meta)), "Repeated resolution is unstable")
		expect(equal(resolved, Resolver.Resolve(resolved, meta)), "Serialized card resolution reapplied progression")
	end)

	test("club project eligibility progression validation and retirement", function()
		local profile = newProfile()
		local definition = eligibleDefinition()
		local card = cardFrom(definition, "project_card")
		table.insert(profile.PlayerCardInventory, card)
		local eligible = Project.IsEligible(profile, card)
		expect(eligible, "Valid project rejected")
		local eligibleCards = Project.GetEligible(profile)
		expectEqual(#eligibleCards, 1, "Eligible Project card missing")
		expect(type(eligibleCards[1].portraitSeed) == "number", "Eligible Project portrait seed missing")
		expect(type(eligibleCards[1].appearance) == "table", "Eligible Project appearance missing")
		profile.PlayerCardMeta.project_card = { Loan = true }
		expect(not Project.IsEligible(profile, card), "Loan project accepted")
		profile.PlayerCardMeta.project_card = {}
		local high = clone(card) high.overall = 90 high.Rating = 90 high.BaseOverall = 90
		expect(not Project.IsEligible(profile, high), "High OVR project accepted")
		local protected = clone(card) protected.cardType = "Icon"
		expect(not Project.IsEligible(profile, protected), "Protected project accepted")
		local selected = Project.Select(profile, "project_card", "season_one")
		expect(selected, "Project selection failed")
		local granted, pending = Project.GrantXP(profile, 3, "fixture_one")
		expectEqual(granted, 3, "Project XP grant")
		expect(pending and pending.Milestone == 3, "Project milestone not generated")
		local repeated = Project.GrantXP(profile, 3, "fixture_one")
		expectEqual(repeated, 0, "Project XP duplicated")
		expect(not Project.ChooseUpgrade(profile, "invalid"), "Invalid project choice accepted")
		expect(Project.ChooseUpgrade(profile, pending.Options[1].Id), "Persisted project choice failed")
		local meta = profile.PlayerCardMeta.project_card
		expect(meta.CampaignBound and meta.QuickSellBlocked and meta.TransferBlocked, "Project protection missing")
		local validPosition = nil
		for _, position in Config.Project.ValidAddedPositions[definition.bestPosition] do if not table.find(definition.positions, position) then validPosition = position break end end
		expect(validPosition ~= nil, "No position test option")
		local active = profile.CampaignProgress.ActiveProject
		active.PendingUpgradeChoice = { ChoiceId = "position_choice", Milestone = 12, Options = { { Id = "bad_position", Name = "BAD", Kind = "Position", Position = "GK" } } }
		expect(not Project.ChooseUpgrade(profile, "bad_position"), "Invalid added position accepted")
		active.PendingUpgradeChoice.Options = { { Id = "valid_position", Name = "VALID", Kind = "Position", Position = validPosition } }
		expect(Project.ChooseUpgrade(profile, "valid_position"), "Valid added position rejected")
		expect(table.find(meta.CampaignProgression.AddedPositions, validPosition) ~= nil, "Added position not persisted")
		meta.CampaignProgression.OverallBoost = Config.Project.MaximumOverallBoost
		active.PendingUpgradeChoice = { ChoiceId = "cap_choice", Milestone = 26, NodeId = "cap", Options = { { Id = "cap_option", Name = "CAP", Kind = "Ascension", Overall = 1, VisualTier = "AscendedII", Package = { Main = {}, Detailed = {} } } } }
		expect(not Project.ChooseUpgrade(profile, "cap_option"), "Project OVR cap bypassed")
		active.PendingUpgradeChoice = nil
		expect(not Project.Retire(profile, false), "Project retired mid-season")
		expect(Project.Retire(profile, true), "Project retirement failed")
		expect(profile.CampaignProgress.ActiveProject == nil and #profile.CampaignProgress.ProjectHistory == 1, "Project history missing")
		local abandonProfile = newProfile()
		table.insert(abandonProfile.PlayerCardInventory, cardFrom(definition, "abandoned_project"))
		expect(Project.Select(abandonProfile, "abandoned_project", "preseason"), "Abandonment Project selection failed")
		expect(Project.Retire(abandonProfile, true), "Pre-upgrade Project abandonment failed")
		expectEqual(#abandonProfile.CampaignProgress.ProjectHistory, 0, "Pre-upgrade abandonment was recorded as a graduate")
		local tokenProfile = newProfile()
		local tokenCard = cardFrom(definition, "token_project")
		table.insert(tokenProfile.PlayerCardInventory, tokenCard)
		tokenProfile.CampaignProgress.CampaignTrainingTokens = 10
		tokenProfile.CampaignProgress.ActiveSeason = { SeasonId = "token_season", DivisionId = "academy_circuit", Status = "Preseason", LeagueFixtures = {}, RecoveryFixtures = {}, Facilities = {} }
		local profiles: any = {}
		function profiles:GetProfile(_player: any): any return tokenProfile end
		function profiles:Save(_player: any, _force: boolean?): boolean return true end
		local progression: any = {}
		function progression:GetClientData(_player: any): any return {} end
		local ranked: any = {}
		function ranked:GetRoster(_player: any): (boolean, string, any?) return false, "Squad unavailable", nil end
		local service = Ascension.new(profiles, function() end, progression, {}, ranked)
		expect(service:SelectCampaignProject({ UserId = 99 } :: any, tokenCard.Id), "Token Project selection failed")
		expectEqual(tokenProfile.CampaignProgress.CampaignTrainingTokens, 0, "Banked Project XP was not consumed")
		expectEqual(tokenProfile.CampaignProgress.ActiveProject.XP, 10, "Banked Project XP was not applied")
		expect(tokenProfile.CampaignProgress.ActiveProject.PendingUpgradeChoice ~= nil, "Banked Project XP did not persist its pending choice")
	end)

	test("scouting focus quality reroll claim and recovery", function()
		local profile = newProfile()
		profile.CampaignProgress.Facilities.scouting = 3
		local season = { SeasonId = "scout_season", Seed = 555, DivisionId = "city_championship", ScoutingFocus = "Goalkeeper", ScoutingQualityBonus = 1, ScoutingRerollsUsed = 0 }
		local choice = Scouting.Generate(profile, season, false)
		expect(choice ~= nil, "Scouting choice generation failed")
		expectEqual(#choice.Options, math.min(5, Config.Divisions[3].ScoutingChoices + 1), "Scouting facility choice count")
		expectEqual(choice.MinimumOverall, Config.Divisions[3].ScoutingMin + 1, "Scouting quality bonus")
		local previous = {}
		for _, option in choice.Options do
			expect(option.overall >= choice.MinimumOverall and option.overall <= choice.MaximumOverall, "Scouting OVR range")
			expect(table.find(option.positions, "GK") ~= nil or option.bestPosition == "GK", "Scouting focus mismatch")
			expect(not previous[option.playerId], "Duplicate scouting option")
			previous[option.playerId] = true
		end
		local rerolled, _, nextChoice = Scouting.Reroll(profile, season)
		expect(rerolled and nextChoice, "Scouting reroll failed")
		for _, id in nextChoice.OptionIds do expect(not previous[id], "Reroll repeated an option") end
		expect(not Scouting.Reroll(profile, season), "Second scouting reroll succeeded")
		expect(not Scouting.Claim({} :: any, profile, season, "invalid", {}), "Unpersisted scouting option claimed")
		local inventory: any = { Calls = 0 }
		function inventory:AddCard(_player: any, definition: any, _metadata: any): (boolean, any)
			self.Calls += 1
			local card = cardFrom(definition, "scouting_card_" .. self.Calls)
			table.insert(profile.PlayerCardInventory, card)
			return true, card
		end
		local selectedId = nextChoice.OptionIds[1]
		local claimed, _, card = Scouting.Claim({} :: any, profile, season, selectedId, inventory)
		expect(claimed and card, "Persisted scouting option failed")
		local meta = profile.PlayerCardMeta[card.cardInstanceId]
		expect(meta.CampaignBound and meta.CampaignReward and meta.QuickSellBlocked and meta.TransferBlocked, "Scouting card protection missing")
		expect(not Scouting.Claim({} :: any, profile, season, selectedId, inventory), "Duplicate scouting claim succeeded")
		local recoveryProfile = newProfile()
		recoveryProfile.CampaignProgress.Facilities.scouting = 3
		local recoverySeason = { SeasonId = "recover_choice", Seed = 777, DivisionId = "city_championship", ScoutingFocus = "Any Position", ScoutingQualityBonus = 0, ScoutingRerollsUsed = 0 }
		local recoveryChoice = Scouting.Generate(recoveryProfile, recoverySeason, false)
		local definition = PlayerDatabase.Get(recoveryChoice.OptionIds[1])
		local existing = cardFrom(definition, "recovered_card")
		table.insert(recoveryProfile.PlayerCardInventory, existing)
		recoveryProfile.PlayerCardMeta.recovered_card = { CampaignChoiceId = recoveryChoice.ChoiceId }
		local rejectingInventory: any = {}
		function rejectingInventory:AddCard(): (boolean, any?) error("Recovery attempted a duplicate AddCard") end
		expect(Scouting.Claim({} :: any, recoveryProfile, recoverySeason, recoveryChoice.OptionIds[1], rejectingInventory), "Interrupted scouting delivery was not repaired")
	end)

	test("facility costs effects max and duplicate request", function()
		local profile = newProfile()
		expect(not Facility.Upgrade(profile, "scouting", ""), "Missing facility request id accepted")
		expect(not Facility.Upgrade(profile, "scouting", "insufficient"), "Facility upgraded without points")
		profile.CampaignProgress.FacilityPoints = 20
		local first, _, data = Facility.Upgrade(profile, "club_finance", "request_one")
		expect(first and data.Level == 1, "Facility level one failed")
		local points = profile.CampaignProgress.FacilityPoints
		local duplicate, _, duplicateData = Facility.Upgrade(profile, "club_finance", "request_one")
		expect(duplicate and duplicateData.Level == 1 and duplicateData.Replayed == true, "Duplicate facility response was not recovered")
		expectEqual(profile.CampaignProgress.FacilityPoints, points, "Duplicate facility request spent points")
		expect(not Facility.Upgrade(profile, "academy", "request_one"), "Facility request id reused across facilities")
		expect(Facility.Upgrade(profile, "club_finance", "request_two"), "Facility level two failed")
		expect(Facility.Upgrade(profile, "club_finance", "request_three"), "Facility level three failed")
		expect(not Facility.Upgrade(profile, "club_finance", "request_four"), "Facility exceeded max level")
		expectEqual(Config.GetFinanceBonus(3), 0.15, "Finance effect")
		expectEqual(Facility.Public(profile)[4].Level, 3, "Facility public level")
		local rollbackProfile = newProfile()
		rollbackProfile.CampaignProgress.FacilityPoints = 1
		local profiles: any = {}
		function profiles:GetProfile(_player: any): any return rollbackProfile end
		function profiles:Save(_player: any, _force: boolean?): boolean return false end
		local service = Ascension.new(profiles, function() end, {}, {}, {})
		local upgraded = service:UpgradeCampaignFacility({ UserId = 77 } :: any, "scouting", "save_failure")
		expect(not upgraded, "Unsaved facility upgrade reported success")
		expectEqual(rollbackProfile.CampaignProgress.FacilityPoints, 1, "Unsaved facility upgrade spent points")
		expectEqual(rollbackProfile.CampaignProgress.Facilities.scouting, 0, "Unsaved facility upgrade changed level")
	end)

	test("reward scaling promotion tokens and star idempotency", function()
		local profile = newProfile()
		profile.CampaignProgress.Facilities.club_finance = 3
		profile.StoreOwnership.GamePasses = { "vip_pass" }
		local season = { DivisionId = "national_division", PromotionFinalAttempts = 1 }
		local manual = Reward.Calculate(profile, season, { Mode = "Manual", IsPromotionFinal = false }, "Win", true, true)
		expectEqual(manual.FinanceModifier, 1.15, "Finance reward modifier")
		expectEqual(manual.VipModifier, 2, "VIP reward modifier")
		local passive = Reward.Calculate(profile, season, { Mode = "Manage", IsPromotionFinal = false }, "Win", true, false)
		expectEqual(passive.ManagerModifier, Config.Manager.PassiveModifier, "Passive manager modifier")
		local recovery = Reward.Calculate(profile, season, { Mode = "Manual", IsPromotionFinal = false, IsRecovery = true }, "Win", true, true)
		expectEqual(recovery.RecoveryModifier, Config.RecoveryRewardModifier, "Recovery reward modifier")
		expect(recovery.PreVIPCoins < manual.PreVIPCoins and recovery.PreVIPXP < manual.PreVIPXP, "Recovery rewards were not reduced")
		season.PromotionFinalAttempts = 2
		local retry = Reward.Calculate(profile, season, { Mode = "Manual", IsPromotionFinal = true }, "Loss", false, true)
		expectEqual(retry.RetryModifier, 0.25, "Promotion retry modifier")
		local promotionSeason = { DivisionId = "academy_circuit" }
		local first = Reward.GrantPromotion(profile, promotionSeason)
		local second = Reward.GrantPromotion(profile, promotionSeason)
		expect(first.FirstPromotion and first.FacilityPoints == 1, "First promotion reward")
		expect(not second.FirstPromotion and second.RepeatTokens == 1, "Repeat promotion token")
		local starSeason = { SeasonId = "stars", DivisionId = "academy_circuit", Stars = 24, ClaimedStarMilestones = {}, RewardLedger = {}, PerfectSeason = false, ScoutingQualityBonus = 0 }
		local progression: any = { Calls = 0 }
		function progression:GrantMatchRewards(_player: any, payload: any): any self.Calls += 1 return { Coins = payload.Coins or 0, XP = payload.XP or 0 } end
		local inventory: any = { Calls = 0 }
		function inventory:AddPack(): (boolean, any) self.Calls += 1 return true, { "pack" } end
		local projectService: any = {}
		function projectService.GrantXP(): number return 0 end
		local granted = Reward.GrantStarMilestones({} :: any, profile, starSeason, inventory, progression, projectService)
		expectEqual(#granted, 6, "All star milestones")
		local calls = progression.Calls
		local packs = inventory.Calls
		local points = profile.CampaignProgress.FacilityPoints
		expectEqual(#Reward.GrantStarMilestones({} :: any, profile, starSeason, inventory, progression, projectService), 0, "Star milestone duplicated")
		expectEqual(progression.Calls, calls, "Star coin transaction duplicated")
		expectEqual(inventory.Calls, packs, "Star pack duplicated")
		expectEqual(profile.CampaignProgress.FacilityPoints, points, "Perfect-season point duplicated")
		local failedProfile = newProfile()
		failedProfile.CampaignProgress.PerfectSeasonRewards["perfect:academy_circuit"] = true
		local failedSeason = { SeasonId = "failed_chest", DivisionId = "academy_circuit", Stars = 24, ClaimedStarMilestones = { [4] = true, [8] = true, [12] = true, [16] = true, [20] = true }, RewardLedger = {}, PerfectSeason = false, ScoutingQualityBonus = 0 }
		local failingProgression: any = {}
		function failingProgression:GrantMatchRewards(): any? return nil end
		local failed, failedSafely = Reward.GrantStarMilestones({} :: any, failedProfile, failedSeason, inventory, failingProgression, projectService)
		expectEqual(#failed, 0, "Failed repeat perfect-season transaction was claimed")
		expect(not failedSafely, "Failed repeat perfect-season transaction reported complete")
		expect(failedSeason.ClaimedStarMilestones[24] ~= true, "Failed repeat perfect-season milestone was marked claimed")
		expect(failedSeason.PerfectSeason ~= true, "Failed repeat perfect-season transaction marked the season perfect")
		expectEqual(failedProfile.CampaignProgress.CampaignTrainingTokens, 0, "Failed repeat perfect-season transaction granted Project tokens")
	end)

	test("objective and manager authority", function()
		local fixture = { ObjectiveTitle = "CONTROL", ObjectiveDescription = "Complete passes", ObjectiveMetric = "PassesCompleted", ObjectiveTarget = 25 }
		local stats = { HomeScore = 2, AwayScore = 0, Home = { PassesCompleted = 30, Shots = 4, TacklesCompleted = 1 }, PlayerRatings = {} }
		local passive = Objective.EvaluateStars(fixture, stats, { Mode = "Manage", Manager = { Total = 0, AfterHalf = false }, ValidFinish = true, Forfeit = false, Stats = stats })
		expect(not passive[1].Earned and not passive[3].Earned, "Passive manager earned active stars")
		local activeManager = { Total = 2, AfterHalf = true }
		local active = Objective.EvaluateStars(fixture, stats, { Mode = "Manage", Manager = activeManager, ValidFinish = true, Forfeit = false, Stats = stats })
		expect(active[1].Earned and active[3].Earned, "Qualified manager stars failed")
		local shootoutStats = { HomeScore = 1, AwayScore = 1, Home = { PassesCompleted = 30, Shots = 4, TacklesCompleted = 1 }, PlayerRatings = {} }
		local shootout = Objective.EvaluateStars(fixture, shootoutStats, { Mode = "Manual", ValidFinish = true, Forfeit = false, Stats = shootoutStats, Result = "Win" })
		expect(shootout[2].Earned, "Shootout win did not earn the fixture-result star")
		local service = Ascension.new({}, function() end, {}, {}, {})
		local player = { UserId = 1 }
		local session = { Player = player, CampaignAscension = {}, Setup = { WatchMode = true }, CampaignManager = { Total = 0, LastActionAt = -1, UniqueCategories = {} } }
		expect(service:RecordManagerInteraction(player :: any, session, "Mentality", { AfterHalf = false }), "Valid manager interaction rejected")
		expect(not service:RecordManagerInteraction(player :: any, session, "Formation", { AfterHalf = true }), "Manager spam counted")
		session.CampaignManager.LastActionAt = -1
		expect(service:RecordManagerInteraction(player :: any, session, "Formation", { AfterHalf = true }), "Second-half interaction rejected")
		session.CampaignManager.LastActionAt = -1
		expect(service:RecordManagerInteraction(player :: any, session, "PlayerInstructions", { AfterHalf = true }), "Live player instruction interaction rejected")
		expect(Objective.ManagerQualified(session.CampaignManager), "Manager qualification failed")
		expectEqual(session.CampaignManager.TacticalChanges, 3, "Manager tactical count")
		expectEqual(session.CampaignManager.PlayerInstructionChanges, 1, "Manager player instruction count")
		expectEqual(session.CampaignManager.SecondHalfInteractions, 2, "Manager second-half count")
		expect(not service:RecordManagerInteraction({ UserId = 2 } :: any, session, "Substitution", {}), "Foreign player counted a manager action")
	end)

	test("result commits win draw loss and duplicate safely", function()
		for result, points in { Win = 3, Draw = 1, Loss = 0 } do
			local context = mockCommit(result, nil)
			if result == "Win" then
				context.Service.ResultCommitting[context.Pending.PendingId] = true
				local competing = clone(context.Session)
				competing.MatchId = context.Session.MatchId .. "_competing"
				expect(context.Service:CommitResult(context.Player :: any, competing) == nil, "Concurrent fixture callback bypassed the pending-match lock")
				expectEqual(context.Progression.Calls, 0, "Concurrent fixture callback granted a reward")
				context.Service.ResultCommitting[context.Pending.PendingId] = nil
			end
			local payload = context.Service:CommitResult(context.Player :: any, context.Session)
			expect(payload and payload.Result == result, result .. " result commit failed")
			expectEqual(context.Season.Points, points, result .. " league points")
			expectEqual(context.Season.LeagueFixturesCompleted, 1, result .. " fixture count")
			expect(context.Fixture.Played, result .. " fixture not played")
			local duplicate = context.Service:CommitResult(context.Player :: any, context.Session)
			expect(duplicate and equal(duplicate, payload), result .. " duplicate callback did not recover payload")
			expectEqual(context.Profiles.RecordCalls, 1, result .. " match history duplicated")
			expectEqual(context.Progression.Calls, 1, result .. " reward duplicated")
			local replay = clone(context.Session)
			replay.MatchId = context.Session.MatchId .. "_replay"
			expect(context.Service:CommitResult(context.Player :: any, replay) == nil, result .. " replay commit succeeded")
		end
	end)

	test("result transition recovery promotion and final retry", function()
		local recoveryStart = mockCommit("Loss", function(profile, season, _fixture)
			season.LeagueFixturesCompleted = 6
			season.Points = 6
			for index = 1, 6 do season.LeagueFixtures[index].Played = true end
			local finalLeagueFixture = season.LeagueFixtures[7]
			finalLeagueFixture.Mode = "Manual"
			profile.CampaignProgress.PendingMatch.FixtureId = finalLeagueFixture.FixtureId
			profile.CampaignProgress.PendingMatch.SetupSnapshot.OpponentTeamId = finalLeagueFixture.OpponentTeamId
		end)
		recoveryStart.Service:CommitResult(recoveryStart.Player :: any, recoveryStart.Session)
		expectEqual(recoveryStart.Season.Status, "Recovery", "Recovery was not opened")
		expectEqual(#recoveryStart.Season.RecoveryFixtures, 3, "Recovery schedule missing")

		local promoted = mockCommit("Win", function(profile, season, fixture)
			season.Status = "PromotionFinal"
			season.PromotionFinalAttempts = 1
			profile.CampaignProgress.PendingMatch.FixtureId = season.PromotionFinal.FixtureId
			profile.CampaignProgress.PendingMatch.SeasonId = season.SeasonId
			profile.CampaignProgress.PendingMatch.SetupSnapshot.OpponentTeamId = season.PromotionFinal.OpponentTeamId
			fixture.Mode = nil
			season.PromotionFinal.Mode = "Manual"
		end)
		promoted.Session.CampaignAscension.FixtureId = promoted.Season.PromotionFinal.FixtureId
		promoted.Session.CampaignAscension.PendingId = promoted.Pending.PendingId
		promoted.Fixture = promoted.Season.PromotionFinal
		local promotionPayload = promoted.Service:CommitResult(promoted.Player :: any, promoted.Session)
		expect(promotionPayload and promoted.Season.Status == "Promoted" and promoted.Season.Promoted, "Promotion final win failed")
		expect(promoted.Profile.CampaignProgress.FirstPromotionRewards[promoted.Season.DivisionId] == true, "First promotion was not recorded")
		expectEqual(promoted.Profile.CampaignProgress.DivisionRecords[promoted.Season.DivisionId].LongestUnbeatenRun, 1, "Unbeaten record was not updated")
		local promotionChoice = promoted.Season.PendingPromotionChoice
		expect(promotionChoice and #promotionChoice.OptionIds > 0, "Promotion signing choice missing")
		expect(promoted.Service:ChooseCampaignPromotionPlayer(promoted.Player :: any, promotionChoice.OptionIds[1]), "Promotion signing claim failed")
		expect(promoted.Profile.CampaignProgress.History[1].ScoutingReward ~= nil, "Promotion signing was not linked to history")

		local retry = mockCommit("Loss", function(profile, season, fixture)
			season.Status = "PromotionFinal"
			season.PromotionFinalAttempts = 2
			profile.CampaignProgress.PendingMatch.FixtureId = season.PromotionFinal.FixtureId
			profile.CampaignProgress.PendingMatch.SetupSnapshot.OpponentTeamId = season.PromotionFinal.OpponentTeamId
			fixture.Mode = nil
			season.PromotionFinal.Mode = "Manual"
		end)
		retry.Session.CampaignAscension.FixtureId = retry.Season.PromotionFinal.FixtureId
		local retryPayload = retry.Service:CommitResult(retry.Player :: any, retry.Session)
		expect(retryPayload and retryPayload.RewardBreakdown.RetryModifier == 0.25, "Final retry reward was not reduced")
		expectEqual(retry.Season.Status, "PromotionFinal", "Retry ended promotion final early")
		expect(not retry.Season.PromotionFinal.Played, "Retry locked the final early")

		local stale = mockCommit("Win", function(profile, season, _fixture)
			season.Status = "PromotionFinal"
			season.PromotionFinalAttempts = 1
			profile.CampaignProgress.PendingMatch.FixtureId = season.PromotionFinal.FixtureId
			profile.CampaignProgress.PendingMatch.SetupSnapshot.OpponentTeamId = season.PromotionFinal.OpponentTeamId
			profile.CampaignProgress.PendingMatch.ExpiresAt = os.time() - 1
		end)
		stale.Service:_profile(stale.Player :: any)
		expect(stale.Profile.CampaignProgress.PendingMatch == nil, "Expired pending match was not cleared")
		expectEqual(stale.Season.PromotionFinalAttempts, 0, "Expired teleport consumed a promotion-final attempt")

		local projectProfile = newProfile()
		local definition = eligibleDefinition()
		local projectCard = cardFrom(definition, "retry_project")
		table.insert(projectProfile.PlayerCardInventory, projectCard)
		expect(Project.Select(projectProfile, projectCard.Id, "retry_season"), "Retry Project selection failed")
		local projectSeason = { SeasonId = "retry_season", PromotionFinalAttempts = 2, PendingProjectUpgrade = nil }
		local projectFixture = { FixtureId = "retry_final", IsPromotionFinal = true, Result = "Win" }
		local projectPending = { ProjectCardInstanceId = projectCard.Id, Mode = "Manual" }
		local projectStars = { {}, {}, { Earned = false } }
		local projectStats = { PlayerRatings = {} }
		local projectService = Ascension.new({}, function() end, {}, {}, {})
		local retryProjectXP = projectService:_grantProjectMatchXP(projectProfile, projectSeason, projectFixture, projectPending, projectStats, projectStars, true, "retry_result")
		expectEqual(retryProjectXP, 2, "Retry promotion win did not grant its one-time Project XP")
		expectEqual(projectService:_grantProjectMatchXP(projectProfile, projectSeason, projectFixture, projectPending, projectStats, projectStars, true, "retry_result"), 0, "Retry promotion Project XP duplicated")
	end)

	test("mastery facility reward is idempotent", function()
		local context = mockCommit("Loss", nil)
		context.Pending.Mastery = true
		context.Pending.SeasonId = "mastery_test"
		context.Session.CampaignAscension.SeasonId = "mastery_test"
		context.Profile.CampaignProgress.Mastery.Unlocked = true
		context.Profile.CampaignProgress.Mastery.Active = {
			WeekKey = "2099-W01", ContractId = "tactical_master", StartedAt = 1,
			Fixtures = { context.Fixture }, CurrentIndex = 3, Wins = 0, Completed = false,
			Succeeded = false, Formations = { "4-3-3", "4-4-2", "3-5-2" }, FormationByFixture = {},
		}
		local points = context.Profile.CampaignProgress.FacilityPoints
		local payload = context.Service:CommitResult(context.Player :: any, context.Session)
		expect(payload and payload.ContractSucceeded == true, "Mastery completion failed")
		expectEqual(payload.FacilityPoints, 1, "Mastery Facility Point missing from result")
		expectEqual(context.Profile.CampaignProgress.FacilityPoints, points + 1, "Mastery Facility Point was not granted")
		local duplicate = context.Service:CommitResult(context.Player :: any, context.Session)
		expect(duplicate and equal(duplicate, payload), "Duplicate mastery callback did not recover its result")
		expectEqual(context.Profile.CampaignProgress.FacilityPoints, points + 1, "Mastery Facility Point duplicated")
		local passive = mockCommit("Loss", nil)
		passive.Pending.Mastery = true
		passive.Pending.Mode = "Manage"
		passive.Pending.SeasonId = "mastery_passive"
		passive.Session.CampaignAscension.SeasonId = "mastery_passive"
		passive.Profile.CampaignProgress.Mastery.Unlocked = true
		passive.Profile.CampaignProgress.Mastery.Active = { WeekKey = "2099-W02", ContractId = "tactical_master", StartedAt = 1, Fixtures = { passive.Fixture }, CurrentIndex = 1, Wins = 0, Completed = false, Succeeded = false, Formations = {}, FormationByFixture = {} }
		local passivePayload = passive.Service:CommitResult(passive.Player :: any, passive.Session)
		expect(passivePayload and passivePayload.RewardBreakdown.ManagerModifier == Config.Manager.PassiveModifier, "Passive Mastery manager received full rewards")
	end)

	test("ui state construction and narrow layout", function()
		local pageModule = StarterPlayer.StarterPlayerScripts.VTRClient.Pages.CampaignPage
		local Page = require(pageModule)
		local cases = {
			{ "PLAY PLACEMENT", nil, "Placement", true }, { "START FIRST SEASON", nil, "NoSeason", false },
			{ "CHOOSE SCOUTING FOCUS", "Preseason", "Focus", false }, { "SELECT CLUB PROJECT", "Preseason", "ProjectDecision", false },
			{ "PLAY MATCH", "Active", nil, false }, { "PLAY RECOVERY MATCH", "Recovery", "Recovery", false },
			{ "PLAY PROMOTION FINAL", "PromotionFinal", "Final", false }, { "CHOOSE PROJECT UPGRADE", "Active", "Project", false },
			{ "CHOOSE YOUR SIGNING", "Active", "Signing", false }, { "START NEXT DIVISION", "Promoted", nil, false },
			{ "START NEW SEASON", "Failed", nil, false }, { "RESUME MATCH", "Active", "Pending", false },
		}
		for _, entry in cases do
			local state = entry[4] and publicState("Active", nil) or entry[3] == "NoSeason" and publicState("Active", nil) or publicState(entry[2], entry[3])
			if entry[4] then state.Placement.Completed = false state.ActiveSeason = nil state.CurrentFixture = nil end
			if entry[3] == "NoSeason" then state.ActiveSeason = nil state.CurrentFixture = nil end
			local fakeService: any = {}
			function fakeService:GetState(): any return { Success = true, Message = "Loaded", Data = state } end
			local root = Page.new({ CampaignService = fakeService, ViewportWidth = entry[1] == "PLAY RECOVERY MATCH" and 390 or 1280, Toast = function() end, Navigate = function() end })
			task.wait()
			local found = false
			for _, descendant in root:GetDescendants() do if descendant:IsA("TextButton") and descendant.Text == entry[1] then found = true break end end
			expect(found, "UI state missing CTA " .. entry[1])
			root:Destroy()
		end
	end)

	return results
end

return Tests
