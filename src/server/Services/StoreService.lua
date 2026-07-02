local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DeveloperConfig = require(ReplicatedStorage.VTR.Shared.DeveloperConfig)
local EconomyConfig = require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local Catalog = require(script.Parent.Parent.Data.StoreCatalog)

local StoreService = {}
StoreService.__index = StoreService

local function find(list: any, id: string): any?
	for _, item in list do
		if item.Id == id then
			return item
		end
	end

	return nil
end

local function contains(list: any, id: string): boolean
	return table.find(list, id) ~= nil
end

function StoreService.new(profiles: any, inventory: any)
	return setmetatable({
		Profiles = profiles,
		Inventory = inventory,
		LastPurchase = {},
	}, StoreService)
end

function StoreService:Purchase(player: Player, kind: string, id: string, quantity: number?): (boolean, string)
	local p = self.Profiles:GetProfile(player)

	if not p then
		return false, "Profile unavailable."
	end

	local now = os.clock()

	if now - (self.LastPurchase[player] or 0) < 0.35 then
		return false, "Please wait."
	end

	local item
	local bucket

	if kind == "Pack" then
		item = Catalog.Packs[id]
	elseif kind == "Kit" then
		item = find(Catalog.Kits, id)
		bucket = p.StoreOwnership.Kits
	elseif kind == "StadiumTheme" then
		item = find(Catalog.StadiumThemes, id)
		bucket = p.StoreOwnership.Stadiums
	elseif kind == "Cosmetic" then
		item = find(Catalog.Cosmetics, id)
		bucket = p.StoreOwnership.Cosmetics
	end

	local count = kind == "Pack" and math.clamp(math.floor(tonumber(quantity) or 1), 1, 25) or 1

	if not item then
		return false, "Unknown item."
	end

	if bucket and contains(bucket, id) then
		return false, "Already owned."
	end

	local coins = (item.PriceCoins or 0) * count
	local bolts = (item.PriceBolts or 0) * count
	local infiniteCoins = DeveloperConfig.InfiniteCoinsEveryone == true

	if (not infiniteCoins and p.Currency.Coins < coins) or p.Currency.Bolts < bolts then
		return false, "Insufficient currency."
	end

	if infiniteCoins then
		p.Currency.Coins = EconomyConfig.MaximumCoins
	else
		p.Currency.Coins -= coins
	end

	p.Currency.Bolts -= bolts
	self.LastPurchase[player] = now

	if kind == "Pack" then
		local delivered = self.Inventory:AddPack(player, id, item.Name, "Store", count)

		if not delivered then
			if not infiniteCoins then
				p.Currency.Coins += coins
			end

			p.Currency.Bolts += bolts

			return false, "Pack delivery failed; currency restored."
		end

		if player and typeof(player) == "Instance" and player:IsA("Player") then
			VTRPendingPackAnimation.Queue(player, id)
		end
	else
		table.insert(bucket, id)
	end

	return true, kind == "Pack" and (count > 1 and (count .. " packs added to inventory.") or "Pack added to inventory.") or "Purchase complete."
end

return StoreService