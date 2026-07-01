--!strict
local Service = {}

local Packs = {
	{PackId = "bronze_pack", Name = "Voltra Spark Pack", Rarity = "Common", Weight = 34},
	{PackId = "silver_pack", Name = "Street Pulse Pack", Rarity = "Rare", Weight = 25},
	{PackId = "gold_pack", Name = "Neon Tactics Pack", Rarity = "Rare", Weight = 18},
	{PackId = "elite_pack", Name = "Elite Matchday Pack", Rarity = "Epic", Weight = 12},
	{PackId = "champion_pack", Name = "Voltra Vault Pack", Rarity = "Epic", Weight = 7},
	{PackId = "hero_pack", Name = "Ranked Champion Pack", Rarity = "Mythic", Weight = 3},
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

function Service.Grant(progression: any, player: Player, publish: ((Player, string, any) -> ())?): any
	local pack = Service.Roll()
	local granted = false
	local grantedId = pack.PackId
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
				break
			end
		end
	end
	if publish and progression and progression.GetClientData then
		pcall(function()
			publish(player, "Progression", progression:GetClientData(player))
		end)
	end
	return {
		Title = "RANKED WIN REWARD",
		Coins = 0,
		XP = 0,
		Pack = pack.Name,
		PackName = pack.Name,
		PackId = grantedId,
		Rarity = pack.Rarity,
		Packs = granted and 1 or 0,
		PackGranted = granted,
		InventoryStored = granted,
		Source = "RankedWin",
	}
end

return Service
