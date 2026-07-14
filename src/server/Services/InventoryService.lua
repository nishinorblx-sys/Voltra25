--!strict
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))

local CardFactoryService = require(script.Parent.CardFactoryService)
local PackInstanceFactory = require(script.Parent.Parent.Data.PackInstanceFactory)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local CardProgressionResolver = require(ReplicatedStorage.VTR.Shared.CardProgressionResolver)

local InventoryService = {}
InventoryService.__index = InventoryService

local function packIdFrom(value: any): string?
	if type(value) == "string" then
		return value
	end
	if type(value) ~= "table" then
		return nil
	end
	return value.packId or value.PackId or value.Id or value.id or value.ItemId or value.itemId or value.Pack
end

local function packCount(value: any): number
	if type(value) ~= "table" then
		return 1
	end
	if value.MigratedToPackInventory == true then
		return 0
	end
	return math.clamp(math.floor(tonumber(value.Count or value.quantity or value.Quantity or value.Amount) or 1), 0, 25)
end

local function ensurePackInventory(profile: any)
	profile.PackInventory = profile.PackInventory or {}
	local seen: {[string]: boolean} = {}
	for index = #profile.PackInventory, 1, -1 do
		local pack = profile.PackInventory[index]
		if type(pack) == "table" and PackInstanceFactory.Hydrate(pack) then
			seen[tostring(pack.packInstanceId)] = true
		else
			table.remove(profile.PackInventory, index)
		end
	end
	local function addLegacy(entry: any, source: string)
		local id = packIdFrom(entry)
		if type(id) ~= "string" or not Catalog.Packs[id] then return end
		local count = packCount(entry)
		if count <= 0 then return end
		for index = 1, count do
			local instance = type(entry) == "table" and table.clone(entry) or nil
			if index == 1 and instance and (instance.packInstanceId or instance.PackInstanceId) then
				if not PackInstanceFactory.Hydrate(instance) then instance = nil end
			else
				instance = PackInstanceFactory.Create(id, source)
				if instance and type(entry) == "table" and count == 1 then
					entry.packInstanceId = instance.packInstanceId
					entry.PackInstanceId = instance.packInstanceId
				end
			end
			if instance and not seen[tostring(instance.packInstanceId)] then
				seen[tostring(instance.packInstanceId)] = true
				table.insert(profile.PackInventory, instance)
			end
		end
		if type(entry) == "table" and count > 1 then
			entry.MigratedToPackInventory = true
			entry.Count = 0
			entry.quantity = 0
			entry.Quantity = 0
		end
	end
	for _, pack in profile.UnopenedPacks or {} do
		addLegacy(pack, "Legacy")
	end
	if profile.Inventory and type(profile.Inventory.Items) == "table" then
		for _, item in profile.Inventory.Items do
			if type(item) == "table" and (item.Kind == "Pack" or item.Type == "Pack") then
				addLegacy(item, "InventoryItem")
			end
		end
	end
end

function InventoryService.new(profiles: any)
	return setmetatable({ Profiles = profiles }, InventoryService)
end

function InventoryService:HasCard(player: Player, cardInstanceId: string): boolean
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false end
	for _, card in profile.PlayerCardInventory do
		if card.cardInstanceId == cardInstanceId then return true end
	end
	return false
end

function InventoryService:AddCard(player: Player, playerDefinition: any, metadata: any?): (boolean, any?)
	local profile = self.Profiles:GetProfile(player)
	if not profile or type(playerDefinition) ~= "table" or type(playerDefinition.playerId) ~= "string" then return false, nil end
	local instance = CardFactoryService.Create(playerDefinition)
	if not instance then return false,nil end
	table.insert(profile.PlayerCardInventory, instance)
	if type(metadata) == "table" then
		profile.PlayerCardMeta = type(profile.PlayerCardMeta) == "table" and profile.PlayerCardMeta or {}
		local cardId = instance.cardInstanceId or instance.Id
		profile.PlayerCardMeta[cardId] = profile.PlayerCardMeta[cardId] or {}
		for key, value in metadata do profile.PlayerCardMeta[cardId][key] = value end
	end
	if self.Profiles.Save then self.Profiles:Save(player) end
	return true, instance
end

function InventoryService:GetCards(player: Player): { any }
	local profile = self.Profiles:GetProfile(player)
	return profile and profile.PlayerCardInventory or {}
end

function InventoryService:GetCardDetails(player: Player, cardInstanceId: string): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	for _, card in profile.PlayerCardInventory do
		if card.cardInstanceId == cardInstanceId then
			local details = CardFactoryService.GetDetails(card)
			return details and CardProgressionResolver.Resolve(details, profile.PlayerCardMeta[card.cardInstanceId or card.Id]) or nil
		end
	end
	return nil
end

function InventoryService:AddPack(player: Player, id: string, name: string, rarity: string, count: number, transactionId: string?): (boolean, { any }?)
	local profile = self.Profiles:GetProfile(player)
	if not profile or type(id) ~= "string" or count <= 0 or count > 25 then return false, nil end
	if transactionId and (transactionId == "" or #transactionId > 160) then return false, nil end
	ensurePackInventory(profile)
	profile.InventoryGrantLedger = type(profile.InventoryGrantLedger) == "table" and profile.InventoryGrantLedger or {}
	local existing = transactionId and profile.InventoryGrantLedger[transactionId] or nil
	if type(existing) == "table" then
		local restored = {}
		for _, packId in existing.PackInstanceIds or {} do
			for _, pack in profile.PackInventory do
				if pack.packInstanceId == packId or pack.PackInstanceId == packId then table.insert(restored, pack) break end
			end
		end
		return true, restored
	end
	local granted = {}
	for _ = 1, count do
		local instance = PackInstanceFactory.Create(id, rarity == "Store" and "Purchase" or rarity)
		if not instance then return false, nil end
		table.insert(profile.PackInventory, instance)
		table.insert(granted, instance)
	end
	if transactionId then
		local ids = {}
		for _, pack in granted do table.insert(ids, pack.packInstanceId or pack.PackInstanceId) end
		profile.InventoryGrantLedger[transactionId] = { GrantedAt = os.time(), PackInstanceIds = ids }
		local ledgerCount = 0
		for _ in profile.InventoryGrantLedger do ledgerCount += 1 end
		while ledgerCount > 256 do
			local oldestId = nil
			local oldestAt = math.huge
			for grantId, entry in profile.InventoryGrantLedger do
				local grantedAt = tonumber(entry.GrantedAt) or 0
				if grantedAt < oldestAt then oldestAt = grantedAt oldestId = grantId end
			end
			if not oldestId then break end
			profile.InventoryGrantLedger[oldestId] = nil
			ledgerCount -= 1
		end
	end
	if self.Profiles.Save then self.Profiles:Save(player) end
	return true, granted
end

function InventoryService:GetPack(player: Player, packInstanceId: string): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile or type(packInstanceId) ~= "string" then return nil end
	ensurePackInventory(profile)
	for _, pack in profile.PackInventory do if pack.packInstanceId == packInstanceId or pack.PackInstanceId == packInstanceId then return pack end end
	return nil
end

function InventoryService:ConsumePack(player: Player, id: string): boolean
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false end
	ensurePackInventory(profile)
	for _, pack in profile.PackInventory do
		if (pack.packInstanceId == id or pack.PackInstanceId == id or pack.packId == id or pack.Id == id) and (pack.status or pack.Status) == "unopened" then
			pack.status = "opened";pack.Status = "opened";pack.openedAt = os.time();pack.Count = 0
			if self.Profiles.Save then self.Profiles:Save(player) end
			return true
		end
	end
	return false
end

function InventoryService:GetUnopenedPacks(player: Player): { any }
	local profile=self.Profiles:GetProfile(player);local result={};if not profile then return result end
	ensurePackInventory(profile)
	for _,pack in profile.PackInventory do if (pack.status or pack.Status)=="unopened" then local definition=Catalog.Packs[pack.packId or pack.Id];if definition then local odds=definition.Odds or{};table.insert(result,{packInstanceId=pack.packInstanceId or pack.PackInstanceId,packId=definition.Id,name=definition.Name,description=definition.Description,quantity=1,status="unopened",purchasedAt=pack.purchasedAt,openedAt=0,cardCount=definition.CardCount,odds=table.clone(odds),guaranteedMinRarity=definition.GuaranteedMinRarity,bestPossibleRarity=(odds.Mythic and "Mythic") or (odds.Icon and "Icon") or (odds.Legendary and "Legendary") or (odds.Elite and "Elite") or (odds.Rare and "Rare") or (odds.Gold and "Gold") or "Silver"}) end end end
	table.sort(result,function(a,b) return (a.purchasedAt or 0)<(b.purchasedAt or 0) end);return result
end

function InventoryService:GetOwnedPlayers(player: Player): { any }
	local profile=self.Profiles:GetProfile(player);local result={};if not profile then return result end
	local activeProject=profile.CampaignProgress and profile.CampaignProgress.ActiveProject
	for _,card in profile.PlayerCardInventory do
		local cardId=card.cardInstanceId or card.Id
		local meta=table.clone(profile.PlayerCardMeta[cardId] or{})
		if activeProject and activeProject.CardInstanceId==cardId then
			meta.CampaignProjectActive=true
			meta.QuickSellBlocked=true
			meta.TransferBlocked=true
			meta.CampaignVariant="Ascension"
		end
		table.insert(result,CardProgressionResolver.Resolve(card,meta))
	end
	table.sort(result,function(a,b) return (tonumber(a.Rating)or 0)>(tonumber(b.Rating)or 0) end);return result
end

function InventoryService:GetOwnedCosmetics(player: Player): any
	local profile=self.Profiles:GetProfile(player);if not profile then return {Cosmetics={},Kits={},Stadiums={},Consumables={}} end
	local function ownedDefinitions(definitions:any,ids:any):any local result={};for _,definition in definitions do if table.find(ids,definition.Id) then table.insert(result,table.clone(definition)) end end;return result end
	local consumables={};for _,item in profile.Inventory.Items or {} do if item.Kind=="Consumable" then table.insert(consumables,table.clone(item)) end end
	return {Cosmetics=ownedDefinitions(Catalog.Cosmetics,profile.StoreOwnership.Cosmetics),Kits=ownedDefinitions(Catalog.Kits,profile.StoreOwnership.Kits),Stadiums=ownedDefinitions(Catalog.Stadiums,profile.StoreOwnership.Stadiums),Consumables=consumables}
end

function InventoryService:GetInventoryHistory(player: Player): { any }
	local profile=self.Profiles:GetProfile(player);local result={};if not profile then return result end
	ensurePackInventory(profile)
	for _,pack in profile.PackInventory do if (pack.status or pack.Status)=="opened" then local definition=Catalog.Packs[pack.packId or pack.Id];if definition then table.insert(result,{type="PackOpened",packInstanceId=pack.packInstanceId or pack.PackInstanceId,packId=definition.Id,name=definition.Name,openedAt=pack.openedAt,bestPull=pack.bestPull}) end end end
	table.sort(result,function(a,b) return (a.openedAt or 0)>(b.openedAt or 0) end);while #result>50 do table.remove(result) end;return result
end

function InventoryService:GetInventorySummary(player: Player): any?
	local profile=self.Profiles:GetProfile(player);if not profile then return nil end;local packs=self:GetUnopenedPacks(player);local owned=self:GetOwnedCosmetics(player)
	return {UnopenedPacks=#packs,Players=#profile.PlayerCardInventory,Cosmetics=#owned.Cosmetics,Kits=#owned.Kits,Stadiums=#owned.Stadiums,Consumables=#owned.Consumables}
end

function InventoryService:GetClientData(player: Player): any?
	local summary=self:GetInventorySummary(player);if not summary then return nil end;local owned=self:GetOwnedCosmetics(player)
	return {Summary=summary,Packs=self:GetUnopenedPacks(player),Players=self:GetOwnedPlayers(player),Cosmetics=owned.Cosmetics,Kits=owned.Kits,Stadiums=owned.Stadiums,Consumables=owned.Consumables,History=self:GetInventoryHistory(player)}
end

return InventoryService
