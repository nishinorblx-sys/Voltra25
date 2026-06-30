--!strict

local CardFactoryService = require(script.Parent.CardFactoryService)
local PackInstanceFactory = require(script.Parent.Parent.Data.PackInstanceFactory)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)

local InventoryService = {}
InventoryService.__index = InventoryService

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

function InventoryService:AddCard(player: Player, playerDefinition: any): (boolean, any?)
	local profile = self.Profiles:GetProfile(player)
	if not profile or type(playerDefinition) ~= "table" or type(playerDefinition.playerId) ~= "string" then return false, nil end
	local instance = CardFactoryService.Create(playerDefinition)
	if not instance then return false,nil end
	table.insert(profile.PlayerCardInventory, instance)
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
		if card.cardInstanceId == cardInstanceId then return CardFactoryService.GetDetails(card) end
	end
	return nil
end

function InventoryService:AddPack(player: Player, id: string, name: string, rarity: string, count: number): (boolean, { any }?)
	local profile = self.Profiles:GetProfile(player)
	if not profile or type(id) ~= "string" or count <= 0 or count > 25 then return false, nil end
	local granted = {}
	for _ = 1, count do
		local instance = PackInstanceFactory.Create(id, rarity == "Store" and "Purchase" or rarity)
		if not instance then return false, nil end
		table.insert(profile.PackInventory, instance)
		table.insert(granted, instance)
	end
	return true, granted
end

function InventoryService:GetPack(player: Player, packInstanceId: string): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile or type(packInstanceId) ~= "string" then return nil end
	for _, pack in profile.PackInventory do if pack.packInstanceId == packInstanceId or pack.PackInstanceId == packInstanceId then return pack end end
	return nil
end

function InventoryService:ConsumePack(player: Player, id: string): boolean
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false end
	for _, pack in profile.PackInventory do
		if (pack.packInstanceId == id or pack.PackInstanceId == id or pack.packId == id or pack.Id == id) and (pack.status or pack.Status) == "unopened" then
			pack.status = "opened";pack.Status = "opened";pack.openedAt = os.time();pack.Count = 0
			return true
		end
	end
	return false
end

function InventoryService:GetUnopenedPacks(player: Player): { any }
	local profile=self.Profiles:GetProfile(player);local result={};if not profile then return result end
	for _,pack in profile.PackInventory do if (pack.status or pack.Status)=="unopened" then local definition=Catalog.Packs[pack.packId or pack.Id];if definition then table.insert(result,{packInstanceId=pack.packInstanceId or pack.PackInstanceId,packId=definition.Id,name=definition.Name,description=definition.Description,quantity=1,status="unopened",purchasedAt=pack.purchasedAt,openedAt=0,cardCount=definition.CardCount,odds=table.clone(definition.Odds or {}),guaranteedMinRarity=definition.GuaranteedMinRarity,bestPossibleRarity=(definition.Odds.Mythic and "Mythic") or (definition.Odds.Icon and "Icon") or (definition.Odds.Legendary and "Legendary") or (definition.Odds.Elite and "Elite") or (definition.Odds.Rare and "Rare") or (definition.Odds.Gold and "Gold") or "Silver"}) end end end
	table.sort(result,function(a,b) return (a.purchasedAt or 0)<(b.purchasedAt or 0) end);return result
end

function InventoryService:GetOwnedPlayers(player: Player): { any }
	local profile=self.Profiles:GetProfile(player);local result={};if not profile then return result end
	for _,card in profile.PlayerCardInventory do local copy=table.clone(card);copy.Meta=table.clone(profile.PlayerCardMeta[card.Id] or {});table.insert(result,copy) end
	table.sort(result,function(a,b) return a.Rating>b.Rating end);return result
end

function InventoryService:GetOwnedCosmetics(player: Player): any
	local profile=self.Profiles:GetProfile(player);if not profile then return {Cosmetics={},Kits={},Stadiums={},Consumables={}} end
	local function ownedDefinitions(definitions:any,ids:any):any local result={};for _,definition in definitions do if table.find(ids,definition.Id) then table.insert(result,table.clone(definition)) end end;return result end
	local consumables={};for _,item in profile.Inventory.Items or {} do if item.Kind=="Consumable" then table.insert(consumables,table.clone(item)) end end
	return {Cosmetics=ownedDefinitions(Catalog.Cosmetics,profile.StoreOwnership.Cosmetics),Kits=ownedDefinitions(Catalog.Kits,profile.StoreOwnership.Kits),Stadiums=ownedDefinitions(Catalog.Stadiums,profile.StoreOwnership.Stadiums),Consumables=consumables}
end

function InventoryService:GetInventoryHistory(player: Player): { any }
	local profile=self.Profiles:GetProfile(player);local result={};if not profile then return result end
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
