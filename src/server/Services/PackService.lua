--!strict

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
	return setmetatable({ Profiles = profiles, Inventory = inventory, LastOpen = {} }, PackService)
end

function PackService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	local inventory = {}
	local history = {}
	for _, owned in profile.PackInventory do
		local definition = PackData[owned.packId or owned.Id]
		if definition and (owned.status or owned.Status) == "unopened" then
			table.insert(inventory, {
				packInstanceId = owned.packInstanceId or owned.PackInstanceId,
				packId = definition.Id,
				name = definition.Name,
				description = definition.Description,
				quantity = 1,
				status = "unopened",
				purchasedAt = owned.purchasedAt,
				openedAt = 0,
				CardCount = definition.CardCount,
				Odds = table.clone(definition.Odds or {}),
				GuaranteedMinRarity = definition.GuaranteedMinRarity,
			})
		elseif definition and (owned.status or owned.Status) == "opened" then
			table.insert(history,{packInstanceId=owned.packInstanceId or owned.PackInstanceId,packId=definition.Id,name=definition.Name,description=definition.Description,status="opened",purchasedAt=owned.purchasedAt,openedAt=owned.openedAt,bestPull=owned.bestPull})
		end
	end
	table.sort(inventory, function(a, b) if a.purchasedAt == b.purchasedAt then return a.packInstanceId < b.packInstanceId end return a.purchasedAt < b.purchasedAt end)
	table.sort(history,function(a,b) return (a.openedAt or 0)>(b.openedAt or 0) end);while #history>20 do table.remove(history) end
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
	local previousCardCount = #profile.PlayerCardInventory
	local reveals = {}
	local success = pcall(function()
		local rolled = {};local guaranteeMet = definition.GuaranteedMinRarity == nil
		for index = 1, definition.CardCount do local rarity = rollRarity(definition.Odds or { Starter = 100 });rolled[index] = rarity;if definition.GuaranteedMinRarity and (rarityRank[rarity] or 0) >= (rarityRank[definition.GuaranteedMinRarity] or 0) then guaranteeMet = true end end
		if not guaranteeMet then rolled[#rolled] = definition.GuaranteedMinRarity end
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
				table.insert(reveals, details)
			else
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
	local best=reveals[1];for _,card in reveals do if (card.Rating or card.overall or 0)>(best.Rating or best.overall or 0) then best=card end end
	owned.bestPull={cardInstanceId=best.cardInstanceId or best.Id,playerId=best.playerId or best.PlayerId,name=best.Name or best.displayName,rating=best.Rating or best.overall,position=best.Position or best.bestPosition,rarity=best.Rarity or best.rarity,cardType=best.CardType or best.cardType}
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
