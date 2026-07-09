--!strict
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local PackInstanceFactory = require(script.Parent.Parent.Data.PackInstanceFactory)

local Service = {}

local PackWeights = {
	common_pack = 260,
	bronze_pack = 190,
	silver_pack = 150,
	gold_pack = 115,
	rare_pack = 84,
	elite_pack = 62,
	rising_star_pack = 48,
	totw_pack = 40,
	voltra_pack = 32,
	event_pack = 26,
	hero_pack = 18,
	champion_pack = 13,
	legendary_pack = 8,
	icon_pack = 4,
	limited_pack = 3,
	mythic_storm_pack = 2,
	mythic_pack = 1,
}

local function packRarity(definition: any): string
	local odds = definition and definition.Odds or {}
	if (tonumber(odds.Mythic) or 0) > 0 then return "Mythic" end
	if (tonumber(odds.Icon) or 0) > 0 then return "Icon" end
	if (tonumber(odds.Legendary) or 0) > 0 then return "Legendary" end
	if (tonumber(odds.Elite) or 0) > 0 then return "Elite" end
	if (tonumber(odds.Rare) or 0) > 0 then return "Rare" end
	if (tonumber(odds.Gold) or 0) > 0 then return "Gold" end
	if (tonumber(odds.Silver) or 0) > 0 then return "Silver" end
	return "Common"
end

local function storePacks(): {any}
	local packs = {}
	for id, definition in Catalog.Packs do
		if definition.PriceCoins and definition.PriceCoins > 0 and not string.find(id, "starter", 1, true) and id ~= "voltage_standard" and id ~= "elite_electrum" then
			table.insert(packs, {
				PackId = id,
				Name = definition.Name,
				Rarity = packRarity(definition),
				Weight = PackWeights[id] or math.max(1, math.floor(100000 / math.max(tonumber(definition.PriceCoins) or 10000, 1))),
			})
		end
	end
	table.sort(packs, function(a, b) return tostring(a.PackId) < tostring(b.PackId) end)
	return packs
end

function Service.Roll(): any
	local Packs = storePacks()
	local total = 0
	for _, pack in Packs do
		total += pack.Weight
	end
	local roll = math.random() * total
	local cursor = 0
	for _, pack in Packs do
		cursor += pack.Weight
		if roll <= cursor then
			return table.clone(pack)
		end
	end
	return table.clone(Packs[1])
end

local function directAddPack(progression: any, player: Player, packId: string): any?
	local profile = progression and progression.Profiles and progression.Profiles:GetProfile(player)
	if not profile then return nil end
	profile.PackInventory = profile.PackInventory or {}
	local instance = PackInstanceFactory.Create(packId, "RankedWin")
	if not instance then return nil end
	table.insert(profile.PackInventory, instance)
	if player and typeof(player) == "Instance" and player:IsA("Player") then
		VTRPendingPackAnimation.Queue(player, packId)
	end
	return instance
end

local function publishAll(progression: any, publish: ((Player, string, any) -> ())?, player: Player)
	if not publish or not progression then return end
	if progression.GetClientData then
		pcall(function()
			publish(player, "Progression", progression:GetClientData(player))
		end)
	end
	if progression.Inventory and progression.Inventory.GetClientData then
		pcall(function()
			publish(player, "Inventory", progression.Inventory:GetClientData(player))
		end)
	end
end

function Service.Grant(progression: any, player: Player, publish: ((Player, string, any) -> ())?): any
	local pack = Service.Roll()
	local matchReward = progression and progression.GrantMatchRewards and progression:GrantMatchRewards(player, {
		Title = "RANKED WIN REWARD",
		Coins = 1500,
		XP = 350,
	}) or nil
	local granted = false
	local grantedId = pack.PackId
	local grantedInstance = nil
	if progression and progression.Inventory and progression.Inventory.AddPack then
		local attempts = {pack.PackId}
		for _, fallback in storePacks() do
			if fallback.PackId ~= pack.PackId then
				table.insert(attempts, fallback.PackId)
			end
		end
		for _, packId in attempts do
			local ok, result = pcall(function()
				local definition = Catalog.Packs[packId]
				local addResult = progression.Inventory:AddPack(player, packId, definition and definition.Name or packId, "RankedWin", 1)
				if addResult and player and typeof(player) == "Instance" and player:IsA("Player") then
					VTRPendingPackAnimation.Queue(player, packId)
				end
				return addResult
			end)
			if ok and result then
				granted = true
				grantedId = packId
				if Catalog.Packs[packId] then
					pack.PackId = packId
					pack.Name = Catalog.Packs[packId].Name
					pack.Rarity = packRarity(Catalog.Packs[packId])
				end
				if type(result) == "table" then
					grantedInstance = result[1]
				end
				break
			end
		end
	end
	if not granted then
		grantedInstance = directAddPack(progression, player, pack.PackId)
		if grantedInstance then
			granted = true
			grantedId = pack.PackId
		end
	end
	publishAll(progression, publish, player)
	return {
		Title = "RANKED WIN REWARD",
		Coins = matchReward and matchReward.Coins or 1500,
		XP = matchReward and matchReward.XP or 350,
		Pack = pack.Name,
		PackName = pack.Name,
		PackId = grantedId,
		PackInstanceId = grantedInstance and (grantedInstance.packInstanceId or grantedInstance.PackInstanceId) or nil,
		Rarity = pack.Rarity,
		Packs = granted and 1 or 0,
		PackGranted = granted,
		InventoryStored = granted,
		Source = "RankedWin",
	}
end

return Service
