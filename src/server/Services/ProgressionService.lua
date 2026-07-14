--!strict
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local EconomyConfig = require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local ObjectiveService = require(script.Parent.ObjectiveService)
local CampaignMigration = require(script.Parent.CampaignMigration)
local DeveloperAccessService=require(script.Parent.DeveloperAccessService)
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local StarCardOfferService=require(script.Parent.StarCardOfferService)
local PlayabilityUnlockConfig=require(ReplicatedStorage.VTR.Shared.PlayabilityUnlockConfig)

local ProgressionService = {}
ProgressionService.__index = ProgressionService

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

local function findObjective(profile: any, objectiveId: string): any?
	for _, objective in profile.Objectives do
		if objective.objectiveId == objectiveId then return objective end
	end
	return nil
end

function ProgressionService.new(profiles: any, publish: (Player, string, any) -> (), inventory: any)
	return setmetatable({ Profiles = profiles, Publish = publish, Inventory = inventory }, ProgressionService)
end

local function cardInstanceId(card: any): string
	return tostring(card and (card.cardInstanceId or card.Id) or "")
end

local function hasPlacement(profile: any, instanceId: string): boolean
	for _, placed in profile.Squad or {} do if tostring(placed) == instanceId then return true end end
	for _, placed in profile.Bench or {} do if tostring(placed) == instanceId then return true end end
	for _, placed in profile.Reserves or {} do if tostring(placed) == instanceId then return true end end
	return false
end

function ProgressionService:_firstMatchRewardDefinition(player: Player, profile: any): any?
	local pool = PlayerDatabase.Pools.Silver or PlayerDatabase.Pools.Bronze or PlayerDatabase.Players
	if type(pool) ~= "table" or #pool == 0 then return nil end
	local owned: {[string]: boolean} = {}
	for _, card in profile.PlayerCardInventory or {} do
		owned[tostring(card.playerId or card.PlayerId or "")] = true
	end
	local start = math.abs(player.UserId) % #pool + 1
	for offset = 0, #pool - 1 do
		local definition = pool[(start + offset - 1) % #pool + 1]
		if definition and not owned[tostring(definition.playerId or "")] then return definition end
	end
	return pool[start]
end

function ProgressionService:_grantFirstMatchReward(player: Player, profile: any)
	local progress = profile.PlayabilityProgress
	if type(progress) ~= "table" or progress.FirstMatchCompleted ~= true or progress.FirstRewardGranted == true then return end
	profile.InventoryGrantLedger = type(profile.InventoryGrantLedger) == "table" and profile.InventoryGrantLedger or {}
	local grantKey = "playability:first_match_starter"
	local ledger = profile.InventoryGrantLedger[grantKey]
	local instanceId = type(ledger) == "table" and tostring(ledger.CardInstanceId or "") or ""
	local instance = nil
	for _, card in profile.PlayerCardInventory or {} do
		local id = cardInstanceId(card)
		local meta = profile.PlayerCardMeta and profile.PlayerCardMeta[id]
		if id == instanceId or type(meta) == "table" and meta.GrantSource == "FirstMatchReward" then
			instance = card
			instanceId = id
			break
		end
	end
	if not instance then
		local definition = self:_firstMatchRewardDefinition(player, profile)
		if not definition then return end
		local added, created = self.Inventory:AddCard(player, definition, {GrantSource = "FirstMatchReward", GrantedAt = os.time()})
		if not added or not created then return end
		instance = created
		instanceId = cardInstanceId(created)
	end
	if instanceId == "" then return end
	profile.Reserves = type(profile.Reserves) == "table" and profile.Reserves or {}
	if not hasPlacement(profile, instanceId) then table.insert(profile.Reserves, instanceId) end
	profile.SquadState = type(profile.SquadState) == "table" and profile.SquadState or {}
	profile.SquadState.reserves = type(profile.SquadState.reserves) == "table" and profile.SquadState.reserves or {}
	if not table.find(profile.SquadState.reserves, instanceId) then table.insert(profile.SquadState.reserves, instanceId) end
	instance.location = "reserves"
	instance.Location = "reserves"
	profile.InventoryGrantLedger[grantKey] = {GrantedAt = os.time(), CardInstanceId = instanceId}
	progress.FirstRewardGranted = true
	progress.FirstRewardCardInstanceId = instanceId
	progress.FirstRewardPlayerName = tostring(instance.displayName or instance.Name or "STARTER PLAYER")
	if self.Profiles.Save then self.Profiles:Save(player, true) end
end

local function worldCupSummary(profile: any): any
	local state = type(profile.WorldCup) == "table" and profile.WorldCup or nil
	if not state then return {Active = false, Country = "", Opponent = "", Stage = "NOT STARTED", Matchday = 0, Complete = false} end
	local selected = tostring(state.SelectedCountry or "")
	local fixture = type(state.NextFixture) == "table" and state.NextFixture or nil
	local opponent = ""
	if fixture then opponent = tostring(fixture.Home == selected and fixture.Away or fixture.Home or "") end
	return {
		Active = true,
		Country = selected,
		Code = tostring(state.SelectedCode or ""),
		Opponent = opponent,
		Stage = tostring(state.Stage or "GROUP STAGE"),
		Matchday = math.max(0, math.floor(tonumber(fixture and (fixture.Matchday or fixture.Round)) or 0)),
		Complete = state.Stage == "Champion" or state.Stage == "Eliminated",
	}
end

function ProgressionService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	self:_grantFirstMatchReward(player, profile)
	return {
		Level = profile.Profile.Level,
		XP = profile.Profile.XP,
		Season = copy(profile.Season),
		SeasonRewards = copy(Catalog.SeasonRewards),
		DivisionRewards = copy(Catalog.DivisionRewards),
		Currency = copy(profile.Currency),
		Objectives = ObjectiveService.Serialize(profile.Objectives),
		Ranked = copy(profile.Ranked),
		RankedRun = copy(profile.RankedRun),
		MatchStats = copy(profile.MatchStats),
		RankedRewards = copy(profile.RankedRewards),
		RewardsInbox = copy(profile.RewardsInbox),
		PackInventory = copy(profile.PackInventory),
		CampaignProgress = CampaignMigration.ClientSummary(profile.CampaignProgress),
		PlayerCardInventory = copy(profile.PlayerCardInventory),
		TeamTactics = copy(profile.TeamTactics),
		PlayerInstructions = copy(profile.PlayerInstructions),
		CustomTactics = copy(profile.CustomTactics),
		ClubMembership = copy(profile.ClubMembership),
		ProClubMembership=copy(profile.ProClubMembership),
		ProClubsPlayer=copy(profile.ProClubsPlayer),
		CareerSaveSlots = copy(profile.CareerSaveSlots),
		StoreOwnership = copy(profile.StoreOwnership),
		StarCard = copy(StarCardOfferService.GetOffer(profile, player.UserId)),
		StoreCatalog = { Packs = copy(Catalog.Packs), CoinBundles = copy(Catalog.CoinBundles), VoltraPointBundles = copy(Catalog.VoltraPointBundles), GamePasses = copy(Catalog.GamePasses), DeveloperProducts = copy(Catalog.DeveloperProducts), Kits = copy(Catalog.Kits), Stadiums = copy(Catalog.Stadiums), Cosmetics = copy(Catalog.Cosmetics),Consumables=copy(Catalog.Consumables) },
		Onboarding = copy(profile.Onboarding),
		PlayabilityProgress = copy(profile.PlayabilityProgress),
		PlayabilityUnlocks = PlayabilityUnlockConfig.ClientSummary(profile.PlayabilityProgress),
		WorldCupSummary = worldCupSummary(profile),
		DeveloperAccess=DeveloperAccessService.IsAuthorized(player),
		DeveloperStudioAccess=DeveloperAccessService.IsStudio(),
	}
end

function ProgressionService:_setObjectiveProgress(profile: any, objectiveId: string, value: number): boolean
	local objective = findObjective(profile, objectiveId)
	if not objective or objective.status == "claimed" then return false end
	local beforeProgress = tonumber(objective.progress) or 0
	local beforeStatus = objective.status
	objective.progress = math.clamp(value, 0, objective.target)
	if objective.status == "active" and objective.progress >= objective.target then
		objective.status = "claimable"
	end
	return beforeProgress ~= objective.progress or beforeStatus ~= objective.status
end

function ProgressionService:_incrementObjective(profile: any, objectiveId: string, amount: number): boolean
	local objective = findObjective(profile, objectiveId)
	if not objective or objective.status == "claimed" then return false end
	return self:_setObjectiveProgress(profile, objectiveId, (tonumber(objective.progress) or 0) + math.max(0, amount))
end

function ProgressionService:_addXP(profile: any, amount: number): (number, number, boolean)
	local xp = math.max(0, math.floor(amount))
	if xp <= 0 then return 0, profile.Season.Level, false end
	local oldLevel = tonumber(profile.Season.Level) or 1
	profile.Season.XP += xp
	while profile.Season.XP >= profile.Season.RequiredXP do
		profile.Season.XP -= profile.Season.RequiredXP
		profile.Season.Level += 1
		profile.Season.RequiredXP = math.floor(profile.Season.RequiredXP * 1.08)
	end
	profile.Profile.XP = profile.Season.XP
	profile.Profile.Level = profile.Season.Level
	self:_setObjectiveProgress(profile, "milestone_level_5", profile.Profile.Level)
	return xp, profile.Season.Level, profile.Season.Level > oldLevel
end

function ProgressionService:_addCoins(profile: any, amount: number): number
	local coins = math.max(0, math.floor(amount))
	if coins <= 0 then return 0 end
	profile.Currency.Coins = math.min(EconomyConfig.MaximumCoins, (tonumber(profile.Currency.Coins) or 0) + coins)
	return coins
end

function ProgressionService:_grantObjectiveReward(player: Player, profile: any, objective: any): boolean
	local reward = objective.reward
	if reward.Type == "XP" then
		self:_addXP(profile, reward.Amount)
	elseif reward.Type == "Pack" then
		local granted=self.Inventory:AddPack(player, reward.ItemId or "voltage_standard", "OBJECTIVE REWARD PACK", "Objective", reward.Amount or 1)
		if not granted then return false end
		if player and typeof(player) == "Instance" and player:IsA("Player") then
			VTRPendingPackAnimation.Queue(player, reward.ItemId or "voltage_standard")
		end
	elseif reward.Type == "Coins" then
		self:_addCoins(profile, reward.Amount)
	elseif reward.Type == "Bolts" then
		profile.Currency.Bolts += reward.Amount
	elseif reward.Type=="LoanPlayer"then
		local pool=PlayerDatabase.Pools[reward.Pool or"Silver"]or PlayerDatabase.Pools.Silver or PlayerDatabase.Players;local definition=pool[math.random(1,#pool)];local added,instance=self.Inventory:AddCard(player,definition);if not added or not instance then return false end
		profile.PlayerCardMeta[instance.Id]=profile.PlayerCardMeta[instance.Id]or{};profile.PlayerCardMeta[instance.Id].LoanMatchesRemaining=math.clamp(tonumber(reward.Matches)or 5,1,99);profile.PlayerCardMeta[instance.Id].Loan=true
	elseif reward.Type=="Consumable"then
		profile.Inventory=profile.Inventory or{Items={}};local found=nil;for _,item in profile.Inventory.Items do if item.Id==reward.ItemId and item.Kind=="Consumable"then found=item;break end end;if found then found.Quantity+=(reward.Amount or 1)else table.insert(profile.Inventory.Items,{Id=reward.ItemId,Kind="Consumable",Quantity=reward.Amount or 1,AcquiredAt=os.time()})end
	end
	return true
end

function ProgressionService:UpdateObjectivesFromMatch(player: Player, teamStats: any): boolean
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false end
	local changed = false
	changed = self:_incrementObjective(profile, "daily_complete_passes", tonumber(teamStats and teamStats.PassesCompleted) or 0) or changed
	changed = self:_incrementObjective(profile, "weekly_score_goals", tonumber(teamStats and teamStats.Goals) or 0) or changed
	changed = self:_setObjectiveProgress(profile, "play_first_match_placeholder", 1) or changed
	changed = self:_setObjectiveProgress(profile, "milestone_level_5", profile.Profile.Level) or changed
	if changed then self:_publishAll(player, profile) end
	return changed
end

function ProgressionService:GrantMatchRewards(player: Player, payload: any): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	payload = type(payload) == "table" and payload or {}
	local transactionId = type(payload.TransactionId) == "string" and payload.TransactionId or nil
	if transactionId and (transactionId == "" or #transactionId > 160) then return nil end
	profile.RewardTransactionLedger = type(profile.RewardTransactionLedger) == "table" and profile.RewardTransactionLedger or {}
	if transactionId and type(profile.RewardTransactionLedger[transactionId]) == "table" then
		return copy(profile.RewardTransactionLedger[transactionId].Reward)
	end
	local title = tostring(payload.Title or "MATCH COMPLETE")
	local vip = profile.StoreOwnership and type(profile.StoreOwnership.GamePasses)=="table" and table.find(profile.StoreOwnership.GamePasses,"vip_pass") ~= nil
	local coins = (tonumber(payload.Coins) or 0) * (vip and 2 or 1)
	local xp = (tonumber(payload.XP) or 0) * (vip and 2 or 1)
	local grantedCoins = self:_addCoins(profile, coins)
	local grantedXP, level, leveledUp = self:_addXP(profile, xp)
	local granted = {
		Title = title,
		Coins = grantedCoins,
		XP = grantedXP,
		Level = level,
		LeveledUp = leveledUp,
		Vip2x = vip == true,
	}
	if transactionId then
		profile.RewardTransactionLedger[transactionId] = { GrantedAt = os.time(), Reward = copy(granted) }
		local count = 0
		for _ in profile.RewardTransactionLedger do count += 1 end
		while count > 512 do
			local oldestId = nil
			local oldestAt = math.huge
			for id, entry in profile.RewardTransactionLedger do
				local grantedAt = tonumber(entry.GrantedAt) or 0
				if grantedAt < oldestAt then oldestAt = grantedAt oldestId = id end
			end
			if not oldestId then break end
			profile.RewardTransactionLedger[oldestId] = nil
			count -= 1
		end
	end
	self:_publishAll(player, profile)
	return granted
end

function ProgressionService:_publishAll(player: Player, profile: any)
	if self.Profiles.Save then self.Profiles:Save(player) end
	self.Publish(player, "Progression", self:GetClientData(player))
	self.Publish(player, "SeasonProgress", { Name = profile.Season.Name, Level = profile.Season.Level, XP = profile.Season.XP, RequiredXP = profile.Season.RequiredXP })
	self.Publish(player, "Currency", { Coins = profile.Currency.Coins, Bolts = profile.Currency.Bolts, VoltraPoints = profile.Currency.VoltraPoints or 0 })
	self.Publish(player, "PlayerProfile", {
		Username = player.Name, DisplayName = player.DisplayName, Level = profile.Profile.Level, XP = profile.Profile.XP,
		SelectedClub = profile.Profile.SelectedClub,
		ClubIdentity = copy(profile.ClubMembership),
		Avatar = { UserId = player.UserId, HeadshotType = profile.Profile.Avatar.HeadshotType, OutfitId = profile.Profile.Avatar.OutfitId },
	})
	self.Publish(player, "Objective", ObjectiveService.Serialize(profile.Objectives))
end

function ProgressionService:Claim(player: Player, kind: string, id: string): (boolean, string, any?)
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false, "Profile unavailable.", nil end
	if kind == "Ranked" then
		for _, reward in profile.RankedRewards do
			if reward.Id == id then
				if reward.Claimed then return false, "Reward already claimed.", nil end
				reward.Claimed = true
				if string.find(reward.Description, "Pack") then
					if not self.Inventory:AddPack(player, "elite_pack", string.upper(reward.Description), "Ranked", 1) then return false, "Ranked pack grant failed.", nil end
					if player and typeof(player) == "Instance" and player:IsA("Player") then
						VTRPendingPackAnimation.Queue(player, "elite_pack")
					end
				elseif string.find(reward.Description, "Coins") then profile.Currency.Coins += 10000 end
				self:_publishAll(player, profile)
				return true, "Ranked reward claimed.", nil
			end
		end
	elseif kind == "Objective" then
		local objective = findObjective(profile, id)
		if not objective then return false, "Objective does not exist.", nil end
		if objective.status == "claimed" then return false, "Objective reward already claimed.", nil end
		if objective.status ~= "claimable" and objective.status ~= "completed" then return false, "Objective is not claimable.", nil end
		if objective.progress < objective.target then return false, "Objective is not complete.", nil end

		if not self:_grantObjectiveReward(player, profile, objective) then return false, "Objective reward grant failed.", nil end
		objective.status = "claimed"
		local nextObjective = objective.nextObjectiveId and findObjective(profile, objective.nextObjectiveId) or nil
		if nextObjective and nextObjective.status == "locked" then
			nextObjective.status = nextObjective.progress >= nextObjective.target and "claimable" or "active"
		end
		local groupCompleted = nextObjective == nil
		self:_publishAll(player, profile)
		local nextClient = nextObjective and ObjectiveService.Serialize({ nextObjective })[1] or nil
		return true, nextObjective and (nextObjective.title .. " is now active.") or "Objective group completed.", {
			claimedObjectiveId = objective.objectiveId,
			nextObjective = nextClient,
			groupCompleted = groupCompleted,
			groupId = objective.groupId,
		}
	end
	return false, "Invalid progression reward.", nil
end

return ProgressionService
