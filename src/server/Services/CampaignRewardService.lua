--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)

local Service = {}

local function addItem(profile: any, itemId: string, kind: string, amount: number)
	profile.Inventory = profile.Inventory or { Items = {} }
	profile.Inventory.Items = profile.Inventory.Items or {}
	for _, item in profile.Inventory.Items do
		if item.Id == itemId and item.Kind == kind then item.Quantity = (tonumber(item.Quantity) or 0) + amount return end
	end
	table.insert(profile.Inventory.Items, { Id = itemId, Kind = kind, Quantity = amount, AcquiredAt = os.time() })
end

local function unlockCosmetic(profile: any, cosmeticId: string)
	profile.StoreOwnership.Cosmetics = profile.StoreOwnership.Cosmetics or {}
	if not table.find(profile.StoreOwnership.Cosmetics, cosmeticId) then table.insert(profile.StoreOwnership.Cosmetics, cosmeticId) end
	profile.CampaignProgress.Unlocks = profile.CampaignProgress.Unlocks or {}
	if not table.find(profile.CampaignProgress.Unlocks, cosmeticId) then table.insert(profile.CampaignProgress.Unlocks, cosmeticId) end
end

function Service.Calculate(profile: any, season: any, fixture: any, result: string, objectiveCompleted: boolean, managerQualified: boolean): any
	local division = Config.GetDivision(season.DivisionId)
	local reward = division.Rewards[result]
	local managerModifier = fixture.Mode == "Manage" and (managerQualified and Config.Manager.QualifiedModifier or Config.Manager.PassiveModifier) or 1
	local retryModifier = fixture.IsPromotionFinal and math.max(1, tonumber(season.PromotionFinalAttempts) or 1) > 1 and 0.25 or 1
	local recoveryModifier = fixture.IsRecovery and Config.RecoveryRewardModifier or 1
	local objectiveCoins = objectiveCompleted and division.ObjectiveCoins or 0
	local financeModifier = 1 + Config.GetFinanceBonus(profile.CampaignProgress.Facilities.club_finance)
	local beforeFinance = math.floor((reward.Coins + objectiveCoins) * managerModifier * retryModifier * recoveryModifier + 0.5)
	local coins = math.floor(beforeFinance * financeModifier + 0.5)
	local xp = math.floor(reward.XP * managerModifier * retryModifier * recoveryModifier + 0.5)
	local vip = profile.StoreOwnership and type(profile.StoreOwnership.GamePasses) == "table" and table.find(profile.StoreOwnership.GamePasses, "vip_pass") ~= nil
	return {
		BaseCoins = reward.Coins, ObjectiveCoins = objectiveCoins, ManagerModifier = managerModifier,
		RetryModifier = retryModifier, RecoveryModifier = recoveryModifier, FinanceModifier = financeModifier, VipModifier = vip and 2 or 1,
		PreVIPCoins = coins, PreVIPXP = xp, FinalCoins = coins * (vip and 2 or 1), FinalXP = xp * (vip and 2 or 1),
	}
end

function Service.GrantMatch(player: Player, profile: any, season: any, fixture: any, result: string, objectiveCompleted: boolean, managerQualified: boolean, progression: any, resultKey: string): (boolean, any?)
	local key = "match:" .. fixture.FixtureId .. ":attempt:" .. tostring(math.max(1, tonumber(season.PromotionFinalAttempts) or 1))
	if season.RewardLedger[key] then return true, season.RewardLedger[key] end
	local breakdown = Service.Calculate(profile, season, fixture, result, objectiveCompleted, managerQualified)
	local reward = progression:GrantMatchRewards(player, { Title = "ASCENSION " .. result:upper(), Coins = breakdown.PreVIPCoins, XP = breakdown.PreVIPXP, TransactionId = "ascension:match:" .. resultKey })
	if not reward then return false, nil end
	breakdown.GrantedCoins = reward.Coins
	breakdown.GrantedXP = reward.XP
	season.RewardLedger[key] = breakdown
	fixture.RewardGranted = true
	return true, breakdown
end

function Service.GrantStarMilestones(player: Player, profile: any, season: any, inventory: any, progression: any, projectService: any): (any, boolean)
	local granted = {}
	local allSucceeded = true
	local division = Config.GetDivision(season.DivisionId)
	for _, starTarget in Config.StarMilestoneOrder do
		if season.Stars >= starTarget and season.ClaimedStarMilestones[starTarget] ~= true then
			local key = "star:" .. season.SeasonId .. ":" .. starTarget
			if season.RewardLedger[key] == nil then
				local success = true
				local payload = { Stars = starTarget, Type = Config.StarMilestones[starTarget].Type }
				if starTarget == 4 then
					local reward = progression:GrantMatchRewards(player, { Title = "ASCENSION STAR REWARD", Coins = division.StarCoins, XP = 0, TransactionId = "ascension:" .. key })
					success = reward ~= nil
					payload.Coins = reward and reward.Coins or 0
				elseif starTarget == 8 then
					addItem(profile, "stamina_boost", "Consumable", 1)
					payload.ItemId = "stamina_boost"
				elseif starTarget == 12 then
					local ok = inventory:AddPack(player, division.PackId, division.Name .. " REWARD", "Campaign", 1, "ascension:" .. key)
					success = ok == true
					payload.PackId = division.PackId
				elseif starTarget == 16 then
					if profile.CampaignProgress.ActiveProject then
						local xp = projectService.GrantXP(profile, 2, key)
						payload.ProjectXP = xp
					else
						profile.CampaignProgress.CampaignTrainingTokens = (tonumber(profile.CampaignProgress.CampaignTrainingTokens) or 0) + 2
						payload.TrainingTokens = 2
					end
				elseif starTarget == 20 then
					season.ScoutingQualityBonus = 1
					payload.ScoutingQualityBonus = 1
				elseif starTarget == 24 then
					local firstKey = "perfect:" .. division.Id
					if profile.CampaignProgress.PerfectSeasonRewards[firstKey] ~= true then
						profile.CampaignProgress.PerfectSeasonRewards[firstKey] = true
						profile.CampaignProgress.FacilityPoints += 1
						unlockCosmetic(profile, division.PerfectCosmeticId)
						payload.FacilityPoints = 1
						payload.CosmeticId = division.PerfectCosmeticId
					else
						local chestCoins = math.floor(division.StarCoins * 0.5)
						local reward = progression:GrantMatchRewards(player, { Title = "CAMPAIGN CHAMPION CHEST", Coins = chestCoins, XP = 0, TransactionId = "ascension:perfect:" .. season.SeasonId })
						success = reward ~= nil
						payload.Coins = reward and reward.Coins or 0
						if success then
							addItem(profile, "chemistry_charge", "Consumable", 1)
							payload.ItemId = "chemistry_charge"
							if profile.CampaignProgress.ActiveProject then
								payload.ProjectXP = projectService.GrantXP(profile, 2, key)
							else
								profile.CampaignProgress.CampaignTrainingTokens += 2
								payload.TrainingTokens = 2
							end
						end
					end
					if success then season.PerfectSeason = true end
				end
				if success then
					season.RewardLedger[key] = payload
					season.ClaimedStarMilestones[starTarget] = true
					table.insert(profile.CampaignProgress.PendingPresentation, { Id = key, Type = "StarMilestone", Data = payload })
					table.insert(granted, payload)
				else
					allSucceeded = false
					break
				end
			end
		end
	end
	return granted, allSucceeded
end

function Service.GrantPromotion(profile: any, season: any): any
	local division = Config.GetDivision(season.DivisionId)
	local first = profile.CampaignProgress.FirstPromotionRewards[division.Id] ~= true
	local payload = { DivisionId = division.Id, FirstPromotion = first, FacilityPoints = 0, RepeatTokens = 0 }
	if first then
		profile.CampaignProgress.FirstPromotionRewards[division.Id] = true
		profile.CampaignProgress.FacilityPoints += 1
		payload.FacilityPoints = 1
		unlockCosmetic(profile, division.BadgeId)
		payload.BadgeId = division.BadgeId
		if division.Id == "voltra_masters" and profile.CampaignProgress.FacilityLedger.masters_title_bonus ~= true then
			profile.CampaignProgress.FacilityLedger.masters_title_bonus = true
			profile.CampaignProgress.FacilityPoints += 1
			payload.FacilityPoints += 1
		end
	else
		local tokens = (tonumber(profile.CampaignProgress.RepeatPromotionTokens[division.Id]) or 0) + 1
		profile.CampaignProgress.RepeatPromotionTokens[division.Id] = tokens
		payload.RepeatTokens = tokens
	end
	return payload
end

return Service
