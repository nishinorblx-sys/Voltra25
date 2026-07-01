--!strict
local PackInstanceFactory = require(script.Parent.Parent.Data.PackInstanceFactory)

local Service = {}

local Packs = {
	{PackId = "bronze_pack", Name = "Voltra Spark Pack", Rarity = "Common", Weight = 800},
	{PackId = "silver_pack", Name = "Street Pulse Pack", Rarity = "Rare", Weight = 90},
	{PackId = "gold_pack", Name = "Neon Tactics Pack", Rarity = "Rare", Weight = 50},
	{PackId = "elite_pack", Name = "Elite Matchday Pack", Rarity = "Epic", Weight = 35},
	{PackId = "champion_pack", Name = "Voltra Vault Pack", Rarity = "Epic", Weight = 18},
	{PackId = "hero_pack", Name = "Ranked Champion Pack", Rarity = "Mythic", Weight = 6},
	{PackId = "voltra_pack", Name = "Icon Voltage Pack", Rarity = "Mythic", Weight = 1},
}

local Fallbacks = {"voltra_pack", "hero_pack", "champion_pack", "elite_pack", "gold_pack", "silver_pack", "bronze_pack"}

function Service.Roll(): any
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
	local granted = false
	local grantedId = pack.PackId
	local grantedInstance = nil
	if progression and progression.Inventory and progression.Inventory.AddPack then
		local attempts = {pack.PackId}
		for _, fallback in Fallbacks do
			if fallback ~= pack.PackId then
				table.insert(attempts, fallback)
			end
		end
		for _, packId in attempts do
			local ok, result = pcall(function()
				return progression.Inventory:AddPack(player, packId, packId, "RankedWin", 1)
			end)
			if ok and result then
				granted = true
				grantedId = packId
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
		Coins = 0,
		XP = 0,
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
