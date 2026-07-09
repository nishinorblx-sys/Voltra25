--!strict
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))

local PackData = require(script.Parent.Parent.Data.Packs)
local PlayerDatabase = require(script.Parent.Parent.Data.PlayerDatabase)

local PackService = {}
PackService.__index = PackService

local rarityOrder = { "Starter", "Common", "Bronze", "Silver", "Gold", "Rare", "Elite", "Legendary", "Icon", "Mythic" }
local rarityRank = {};for index, rarity in rarityOrder do rarityRank[rarity] = index end

local function poolFor(rarity: string): { any }
	return PlayerDatabase.Pools[rarity]
		or ((rarity == "Common" or rarity == "Bronze") and PlayerDatabase.Pools.Starter)
		or ((rarity == "Silver" or rarity == "Gold") and PlayerDatabase.Pools.Rare)
		or (rarity == "Icon" and PlayerDatabase.Pools.Legendary)
		or PlayerDatabase.Pools.Starter
end

local function rollRarity(odds: any): string
	local roll = math.random() * 100
	local cumulative = 0
	for _, rarity in rarityOrder do
		cumulative += odds[rarity] or 0
		if roll <= cumulative then return rarity end
	end
	return "Starter"
end

local function vtrNormalizeNewPackCards(profile:any, startIndex:number)
	profile.PlayerCardInventory=profile.PlayerCardInventory or{}
	profile.PlayerCardMeta=profile.PlayerCardMeta or{}
	for index=math.max(1,startIndex),#profile.PlayerCardInventory do
		local card=profile.PlayerCardInventory[index]
		if type(card)=="table" then
			local id=card.Id or card.cardInstanceId
			card.location="club"
			card.Location="club"
			card.RosterLocation="Club"
			card.RosterSlot=nil
			if id then
				profile.PlayerCardMeta[id]=profile.PlayerCardMeta[id] or{}
				profile.PlayerCardMeta[id].AcquiredAt=profile.PlayerCardMeta[id].AcquiredAt or os.time()
				profile.PlayerCardMeta[id].NewPackPull=true
			end
		end
	end
end

local function rollCardType(definition:any,index:number): string?
	if index==1 and type(definition.GuaranteedCardType)=="string" then return definition.GuaranteedCardType end
	local weights=definition.CardTypeWeights
	if type(weights)~="table" then return nil end
	local total=0
	for _,weight in weights do total+=tonumber(weight) or 0 end
	if total<=0 then return nil end
	local roll=math.random()*total
	local cumulative=0
	for cardType,weight in weights do
		cumulative+=tonumber(weight) or 0
		if roll<=cumulative then return cardType end
	end
	return nil
end

function PackService.new(profiles: any, inventory: any)
	return setmetatable({ Profiles = profiles, Inventory = inventory, LastOpen = {}, RankedProfiles = nil }, PackService)
end

local function hasVip(profile:any):boolean
	local passes=profile and profile.StoreOwnership and profile.StoreOwnership.GamePasses
	return type(passes)=="table" and table.find(passes,"vip_pass")~=nil
end

local function boostedOdds(odds:any, vip:boolean):any
	local result=table.clone(odds or {})
	if not vip then return result end
	local total=0
	for _,rarity in rarityOrder do
		local value=tonumber(result[rarity])or 0
		if (rarityRank[rarity]or 0)>=(rarityRank.Rare or 6) then value*=1.1 end
		result[rarity]=value
		total+=value
	end
	if total>0 then
		for _,rarity in rarityOrder do result[rarity]=(tonumber(result[rarity])or 0)/total*100 end
	end
	return result
end

local function lowerRarity(rarity:string):string
	local rank=rarityRank[rarity]or rarityRank.Bronze
	return rarityOrder[math.max(1,rank-1)]or"Starter"
end

local function lowTierOdds(definition:any):any
	local odds=definition.Odds or{Starter=100}
	local minimum=definition.GuaranteedMinRarity
	if not minimum then
		local bestRank=1
		for rarity,value in odds do
			if (tonumber(value)or 0)>0 then bestRank=math.max(bestRank,rarityRank[rarity]or 1)end
		end
		minimum=rarityOrder[math.max(1,bestRank-1)]or"Bronze"
	end
	local maxRank=math.max(1,(rarityRank[minimum]or 2)-1)
	local result={}
	local total=0
	local minRank=math.max(1,maxRank-1)
	for _,rarity in rarityOrder do
		local rank=rarityRank[rarity]or 1
		if rank>=minRank and rank<=maxRank then
			local value=tonumber(odds[rarity])or 0
			if value<=0 then value=(rank==maxRank and 75 or 25)end
			result[rarity]=value
			total+=value
		end
	end
	if total<=0 then result[lowerRarity(minimum)]=100 end
	return result
end

local function rollPackRarities(definition:any,odds:any):{string}
	local count=math.max(1,math.floor(tonumber(definition.CardCount)or 1))
	local goodSlots=math.min(count,math.random()<.34 and 2 or 1)
	if count<=3 then goodSlots=1 end
	local minimum=definition.GuaranteedMinRarity
	local lowOdds=lowTierOdds(definition)
	local rolled={}
	for index=1,count do rolled[index]=rollRarity(lowOdds)end
	local usedSlots={}
	for _=1,goodSlots do
		local slot
		repeat slot=math.random(1,count)until not usedSlots[slot]
		usedSlots[slot]=true
		local rarity=rollRarity(odds)
		if minimum and (rarityRank[rarity]or 0)<(rarityRank[minimum]or 0)then rarity=minimum end
		rolled[slot]=rarity
	end
	return rolled
end

function PackService:SetRankedProfiles(rankedProfiles:any)
	self.RankedProfiles=rankedProfiles
end

function PackService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end

	if self.Inventory and self.Inventory.GetClientData then
		local data = self.Inventory:GetClientData(player)
		if data then
			return {
				Packs = data.Packs or {},
				History = data.History or {},
			}
		end
	end

	local inventory = {}
	local history = {}

	for _, owned in profile.PackInventory or {} do
		local definition = PackData[owned.packId or owned.Id]
		if definition then
			if (owned.status or owned.Status) == "unopened" then
				table.insert(inventory, {
					packInstanceId = owned.packInstanceId or owned.PackInstanceId,
					packId = definition.Id,
					name = definition.Name,
					description = definition.Description,
					CardCount = definition.CardCount,
					cardCount = definition.CardCount,
					odds = table.clone(definition.Odds or {}),
					guaranteedMinRarity = definition.GuaranteedMinRarity,
					status = "unopened",
					purchasedAt = owned.purchasedAt,
					openedAt = 0,
				})
			elseif (owned.status or owned.Status) == "opened" then
				table.insert(history, {
					packInstanceId = owned.packInstanceId or owned.PackInstanceId,
					packId = definition.Id,
					name = definition.Name,
					description = definition.Description,
					status = "opened",
					purchasedAt = owned.purchasedAt,
					openedAt = owned.openedAt,
					bestPull = owned.bestPull,
				})
			end
		end
	end

	table.sort(inventory, function(a, b)
		if a.purchasedAt == b.purchasedAt then return tostring(a.packInstanceId) < tostring(b.packInstanceId) end
		return (a.purchasedAt or 0) < (b.purchasedAt or 0)
	end)

	return { Packs = inventory, History = history }
end

function PackService:Open(player: Player, packInstanceId: string): (boolean, { any } | string)
	if type(packInstanceId) ~= "string" or #packInstanceId > 80 then return false, "Invalid pack instance." end
	local owned = self.Inventory:GetPack(player, packInstanceId)
	if not owned then return false, "Unopened pack is not owned." end
	if (owned.status or owned.Status) ~= "unopened" then return false, "This pack has already been opened." end
	local definition = PackData[owned.packId or owned.Id]
	if not definition then return false, "Pack definition unavailable." end
	local now = os.clock()
	if now - (self.LastOpen[player] or 0) < 0.75 then return false, "Please wait." end
	self.LastOpen[player] = now
	owned.status = "opening";owned.Status = "opening"
	local profile = self.Profiles:GetProfile(player)
	if not profile then owned.status="unopened";owned.Status="unopened";return false,"Profile unavailable." end
	local vipBoost=hasVip(profile)
	local odds=boostedOdds(definition.Odds or { Starter = 100 },vipBoost)
	local previousCardCount = #profile.PlayerCardInventory
	local reveals = {}
	local success = pcall(function()
		local rolled = rollPackRarities(definition,odds)
		for index, rarity in rolled do
			local pool = poolFor(rarity)
			local playerDefinition = pool[math.random(1, #pool)]
			local added, instance = self.Inventory:AddCard(player, playerDefinition)
			if not added or not instance then error("Card grant rejected") end
			local specialType=rollCardType(definition,index)
			if specialType and specialType~="Base" then
				instance.cardType=specialType
				instance.CardType=specialType
			end
			local details = self.Inventory:GetCardDetails(player, instance.cardInstanceId)
			if details then
				for key, value in instance do if details[key] == nil then details[key] = value end end
				details.cardType=instance.cardType
				details.CardType=instance.CardType
				details.VTRVipPackBoost=vipBoost
				table.insert(reveals, details)
			else
				instance.VTRVipPackBoost=vipBoost
				table.insert(reveals, instance)
			end
		end
	end)
	if not success or #reveals ~= definition.CardCount then
		while #profile.PlayerCardInventory > previousCardCount do table.remove(profile.PlayerCardInventory) end
		owned.status="unopened";owned.Status="unopened";owned.openedAt=0;owned.Count=1
		return false,"Pack roll failed safely. The pack was not consumed."
	end
	owned.status = "opened";owned.Status = "opened";owned.openedAt = os.time();owned.Count = 0
	vtrNormalizeNewPackCards(profile, previousCardCount + 1)
	local best=reveals[1];for _,card in reveals do if (card.Rating or card.overall or 0)>(best.Rating or best.overall or 0) then best=card end end
	local packRating=math.floor(tonumber(best.Rating or best.overall)or 0)
	owned.bestPull={cardInstanceId=best.cardInstanceId or best.Id,playerId=best.playerId or best.PlayerId,name=best.Name or best.displayName,rating=packRating,position=best.Position or best.bestPosition,rarity=best.Rarity or best.rarity,cardType=best.CardType or best.cardType}
	owned.packRating=packRating;owned.PackRating=packRating
	if self.RankedProfiles and self.RankedProfiles.RecordPackRating then
		self.RankedProfiles:RecordPackRating(player,packRating)
	end
	if self.Profiles.Save then self.Profiles:Save(player) end
	return true, reveals
end

function PackService:OpenAll(player: Player, packId: string): (boolean, { any } | string, number)
	if type(packId)~="string" or not PackData[packId] then return false,"Unknown pack type.",0 end
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",0 end
	local instanceIds={};for _,pack in profile.PackInventory do if (pack.packId or pack.Id)==packId and (pack.status or pack.Status)=="unopened" then table.insert(instanceIds,pack.packInstanceId or pack.PackInstanceId) end end
	if #instanceIds<2 then return false,"Open All requires at least two unopened packs of this type.",0 end
	local reveals={};local openedCount=0
	for _,instanceId in instanceIds do self.LastOpen[player]=0;local opened,result=self:Open(player,instanceId);if not opened then return false,result,openedCount end;openedCount+=1;for _,card in result::any do table.insert(reveals,card) end end
	return true,reveals,openedCount
end

return PackService
