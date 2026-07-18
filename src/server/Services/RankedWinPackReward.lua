--!strict
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local RewardEconomyConfig = require(ReplicatedStorage.VTR.Shared.RewardEconomyConfig)
local PackInstanceFactory = require(script.Parent.Parent.Data.PackInstanceFactory)

local Service = {}

local PackWeights = RewardEconomyConfig.RankedWinPackWeights

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

local function rollReel(length: number, stopIndex: number): ({any}, any)
	local reel = {}
	for index = 1, length do
		reel[index] = Service.Roll()
	end
	return reel, table.clone(reel[stopIndex])
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
	local stopIndex = math.random(26, 30)
	local reel, pack = rollReel(38, stopIndex)
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
	local reelPayload = {}
	for index, reelPack in reel do
		reelPayload[index] = {
			PackId = reelPack.PackId,
			Name = reelPack.Name,
			Rarity = reelPack.Rarity,
		}
	end
	-- Inventory fallbacks are rare, but the visible landing must still match the
	-- pack that was successfully stored for the player.
	if reelPayload[stopIndex] and reelPayload[stopIndex].PackId ~= grantedId then
		local definition = Catalog.Packs[grantedId]
		reelPayload[stopIndex] = {
			PackId = grantedId,
			Name = definition and definition.Name or pack.Name,
			Rarity = definition and packRarity(definition) or pack.Rarity,
		}
	end
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
		RouletteReel = reelPayload,
		RouletteStopIndex = stopIndex,
	}
end

return Service
