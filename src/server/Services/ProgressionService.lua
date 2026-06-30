--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local ObjectiveService = require(script.Parent.ObjectiveService)
local DeveloperAccessService=require(script.Parent.DeveloperAccessService)
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)

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

function ProgressionService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	return {
		Level = profile.Profile.Level,
		XP = profile.Profile.XP,
		Season = copy(profile.Season),
		SeasonRewards = copy(Catalog.SeasonRewards),
		DivisionRewards = copy(Catalog.DivisionRewards),
		Currency = copy(profile.Currency),
		Objectives = ObjectiveService.Serialize(profile.Objectives),
		Ranked = copy(profile.Ranked),
		RankedRewards = copy(profile.RankedRewards),
		RewardsInbox = copy(profile.RewardsInbox),
		PackInventory = copy(profile.PackInventory),
		PlayerCardInventory = copy(profile.PlayerCardInventory),
		TeamTactics = copy(profile.TeamTactics),
		PlayerInstructions = copy(profile.PlayerInstructions),
		CustomTactics = copy(profile.CustomTactics),
		ClubMembership = copy(profile.ClubMembership),
		ProClubMembership=copy(profile.ProClubMembership),
		ProClubsPlayer=copy(profile.ProClubsPlayer),
		CareerSaveSlots = copy(profile.CareerSaveSlots),
		StoreOwnership = copy(profile.StoreOwnership),
		StoreCatalog = { Packs = copy(Catalog.Packs), Kits = copy(Catalog.Kits), Stadiums = copy(Catalog.Stadiums), Cosmetics = copy(Catalog.Cosmetics),Consumables=copy(Catalog.Consumables) },
		Onboarding = copy(profile.Onboarding),
		DeveloperAccess=DeveloperAccessService.IsAuthorized(player),
		DeveloperStudioAccess=DeveloperAccessService.IsStudio(),
	}
end

function ProgressionService:_grantObjectiveReward(player: Player, profile: any, objective: any): boolean
	local reward = objective.reward
	if reward.Type == "XP" then
		profile.Season.XP += reward.Amount
		while profile.Season.XP >= profile.Season.RequiredXP do
			profile.Season.XP -= profile.Season.RequiredXP
			profile.Season.Level += 1
			profile.Season.RequiredXP = math.floor(profile.Season.RequiredXP * 1.08)
		end
		profile.Profile.XP = profile.Season.XP
		profile.Profile.Level = profile.Season.Level
	elseif reward.Type == "Pack" then
		return self.Inventory:AddPack(player, reward.ItemId or "voltage_standard", "OBJECTIVE REWARD PACK", "Objective", reward.Amount or 1)
	elseif reward.Type == "Coins" then
		profile.Currency.Coins += reward.Amount
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

function ProgressionService:_publishAll(player: Player, profile: any)
	self.Publish(player, "Progression", self:GetClientData(player))
	self.Publish(player, "SeasonProgress", { Name = profile.Season.Name, Level = profile.Season.Level, XP = profile.Season.XP, RequiredXP = profile.Season.RequiredXP })
	self.Publish(player, "Currency", { Coins = profile.Currency.Coins, Bolts = profile.Currency.Bolts })
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
