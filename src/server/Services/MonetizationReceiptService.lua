--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local EconomyConfig = require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local MonetizationConfig = require(ReplicatedStorage.VTR.Shared.MonetizationConfig)
local PlayerDatabase = require(script.Parent.Parent.Data.PlayerDatabase)
local StarCardOfferService = require(script.Parent.StarCardOfferService)

local Service = {}
Service.__index = Service

local function celebrationPackRemote(): RemoteEvent
	local root = ReplicatedStorage:FindFirstChild("VTR") or Instance.new("Folder")
	root.Name = "VTR"
	root.Parent = ReplicatedStorage
	local remotes = root:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = root
	local remote = remotes:FindFirstChild("CelebrationPackReveal") or Instance.new("RemoteEvent")
	remote.Name = "CelebrationPackReveal"
	remote.Parent = remotes
	return remote :: RemoteEvent
end

local function has(list: any, id: string): boolean
	return type(list) == "table" and table.find(list, id) ~= nil
end

local function addUnique(list: any, id: string)
	if type(list) ~= "table" or id == "" or has(list, id) then return end
	table.insert(list, id)
end

local function ensureProfileFields(profile: any)
	profile.Currency = type(profile.Currency) == "table" and profile.Currency or {}
	profile.Currency.Coins = tonumber(profile.Currency.Coins) or 0
	profile.Currency.Bolts = tonumber(profile.Currency.Bolts) or 0
	profile.Currency.VoltraPoints = tonumber(profile.Currency.VoltraPoints) or 0
	profile.StoreOwnership = type(profile.StoreOwnership) == "table" and profile.StoreOwnership or {}
	profile.StoreOwnership.Kits = type(profile.StoreOwnership.Kits) == "table" and profile.StoreOwnership.Kits or {}
	profile.StoreOwnership.Stadiums = type(profile.StoreOwnership.Stadiums) == "table" and profile.StoreOwnership.Stadiums or {}
	profile.StoreOwnership.Cosmetics = type(profile.StoreOwnership.Cosmetics) == "table" and profile.StoreOwnership.Cosmetics or {}
	profile.StoreOwnership.GamePasses = type(profile.StoreOwnership.GamePasses) == "table" and profile.StoreOwnership.GamePasses or {}
	profile.ActiveBoosts = type(profile.ActiveBoosts) == "table" and profile.ActiveBoosts or {}
	profile.PurchaseHistory = type(profile.PurchaseHistory) == "table" and profile.PurchaseHistory or {}
	profile.Inventory = type(profile.Inventory) == "table" and profile.Inventory or {Items = {}}
	profile.Inventory.Items = type(profile.Inventory.Items) == "table" and profile.Inventory.Items or {}
	profile.UIState = type(profile.UIState) == "table" and profile.UIState or {}
	profile.UIState.EquippedCosmetics = type(profile.UIState.EquippedCosmetics) == "table" and profile.UIState.EquippedCosmetics or {}
	profile.StarCard = type(profile.StarCard) == "table" and profile.StarCard or {Offer = nil, RerollsToday = 0, RerollDay = 0}
end

local function findCosmetic(id: string): any?
	for _, item in Catalog.Cosmetics do
		if item.Id == id then return item end
	end
	return nil
end
local function findKit(id: string): any?
	for _, kit in Catalog.Kits do
		if kit.Id == id then return kit end
	end
	return nil
end

local function grantCosmetic(profile: any, id: string)
	local cosmetic = findCosmetic(id)
	if cosmetic then
		addUnique(profile.StoreOwnership.Cosmetics, id)
	end
end

local function grantKit(profile: any, id: string)
	for _, kit in Catalog.Kits do
		if kit.Id == id then
			addUnique(profile.StoreOwnership.Kits, id)
			return
		end
	end
end

local function grantStadium(profile: any, id: string)
	for _, stadium in Catalog.Stadiums do
		if stadium.Id == id then
			addUnique(profile.StoreOwnership.Stadiums, id)
			return
		end
	end
end

local function syncOwnedAttributes(player: Player, profile: any)
	ensureProfileFields(profile)
	for _, kit in Catalog.Kits do
		player:SetAttribute("VTROwnedKit_" .. kit.Id, has(profile.StoreOwnership.Kits, kit.Id))
	end
	for _, cosmetic in Catalog.Cosmetics do
		player:SetAttribute("VTROwnedCosmetic_" .. cosmetic.Id, has(profile.StoreOwnership.Cosmetics, cosmetic.Id))
	end
	for _, stadium in Catalog.Stadiums do
		player:SetAttribute("VTROwnedStadium_" .. stadium.Id, has(profile.StoreOwnership.Stadiums, stadium.Id))
	end
end

function Service.new(profiles: any, inventory: any, progression: any, publish: (Player, string, any) -> ())
	return setmetatable({Profiles = profiles, Inventory = inventory, Progression = progression, Publish = publish, Started = false}, Service)
end

function Service:_publish(player: Player, profile: any)
	syncOwnedAttributes(player, profile)
	if self.Publish then
		self.Publish(player, "Currency", {Coins = profile.Currency.Coins, Bolts = profile.Currency.Bolts, VoltraPoints = profile.Currency.VoltraPoints or 0})
		if self.Progression and self.Progression.GetClientData then
			self.Publish(player, "Progression", self.Progression:GetClientData(player))
		end
		if self.Inventory and self.Inventory.GetClientData then
			self.Publish(player, "Inventory", self.Inventory:GetClientData(player))
		end
		self.Publish(player, "UIState", profile.UIState)
	end
end

function Service:_grantStarCard(player: Player, profile: any)
	local offer = StarCardOfferService.GetOffer(profile, player.UserId)
	local definition = offer and PlayerDatabase.Get(tostring(offer.PlayerId or ""))
	if not definition then return end
	local ok, card = self.Inventory:AddCard(player, definition)
	if ok and card then
		table.insert(profile.Inventory.Items, {Id = card.cardInstanceId, Kind = "PlayerCard", Quantity = 1, AcquiredAt = os.time()})
		profile.StarCard.PurchasedOffer = definition.playerId
	end
end

function Service:_grantDailyDeal(player: Player, profile: any)
	local roll = math.random(1, 100)
	if roll <= 35 then
		profile.Currency.Coins = math.min(EconomyConfig.MaximumCoins, profile.Currency.Coins + 12000)
	elseif roll <= 58 then
		profile.Currency.VoltraPoints = math.min(EconomyConfig.MaximumVoltraPoints, profile.Currency.VoltraPoints + 250)
	elseif roll <= 82 then
		if self.Inventory then self.Inventory:AddPack(player, "gold_pack", Catalog.Packs.gold_pack.Name, "DailyDeal", 1) end
	else
		grantCosmetic(profile, "goal_fx_smoke")
	end
end

function Service:_grantProduct(player: Player, profile: any, product: any)
	ensureProfileFields(profile)
	if product.Kind == "CoinPack" then
		profile.Currency.Coins = math.min(EconomyConfig.MaximumCoins, profile.Currency.Coins + math.max(0, tonumber(product.Coins) or 0))
	elseif product.Kind == "VoltraPoints" then
		profile.Currency.VoltraPoints = math.min(EconomyConfig.MaximumVoltraPoints, profile.Currency.VoltraPoints + math.max(0, tonumber(product.VoltraPoints) or 0))
	elseif product.Kind == "LaunchBundle" then
		profile.Currency.Coins = math.min(EconomyConfig.MaximumCoins, profile.Currency.Coins + math.max(0, tonumber(product.Coins) or 0))
		profile.Currency.VoltraPoints = math.min(EconomyConfig.MaximumVoltraPoints, profile.Currency.VoltraPoints + math.max(0, tonumber(product.VoltraPoints) or 0))
		for _, cosmeticId in product.Cosmetics or {} do grantCosmetic(profile, cosmeticId) end
		for _, packId in product.Packs or {} do
			local pack = Catalog.Packs[packId]
			if pack and self.Inventory then self.Inventory:AddPack(player, packId, pack.Name, "LaunchBundle", 1) end
		end
	elseif product.Kind == "CoinBoost" then
		local now = os.time()
		local current = math.max(now, tonumber(profile.ActiveBoosts.Coins2xUntil) or 0)
		profile.ActiveBoosts.Coins2xUntil = current + math.max(0, tonumber(product.DurationSeconds) or 0)
	elseif product.Kind == "Kit" then
		grantKit(profile, tostring(product.GrantItemId or ""))
	elseif product.Kind == "Cosmetic" then
		local grantId = tostring(product.GrantItemId or "")
		if not has(profile.StoreOwnership.Cosmetics, grantId) then
			grantCosmetic(profile, grantId)
		end
	elseif product.Kind == "CelebrationPack" then
		local pool = product.Pool or {}
		if #pool > 0 then
			local awarded = tostring(pool[math.random(1, #pool)])
			grantCosmetic(profile, awarded)
			celebrationPackRemote():FireClient(player, {PackId = product.Id, PackName = product.Name, Pool = pool, Awarded = awarded})
		end
	elseif product.Kind == "DailyDeal" then
		self:_grantDailyDeal(player, profile)
	elseif product.Kind == "StarCard" then
		self:_grantStarCard(player, profile)
	elseif product.Kind == "StarReroll" then
		StarCardOfferService.Reroll(profile, player.UserId)
	end
end

function Service:_grantGamePass(player: Player, profile: any, pass: any)
	ensureProfileFields(profile)
	addUnique(profile.StoreOwnership.GamePasses, pass.Id)
	player:SetAttribute("VTRGamePass_" .. pass.Id, true)
	if pass.Id == "vip_pass" then player:SetAttribute("VTRVIP", true) end
	for _, id in pass.Unlocks or {} do
		if findCosmetic(id) then
			grantCosmetic(profile, id)
		elseif findKit(id) then
			grantKit(profile, id)
		else
			grantStadium(profile, id)
		end
	end
end

function Service:_syncOwnedPasses(player: Player)
	task.spawn(function()
		if self.Profiles.WaitForProfile then self.Profiles:WaitForProfile(player, 8) end
		local profile = self.Profiles:GetProfile(player)
		if not profile then return end
		ensureProfileFields(profile)
		syncOwnedAttributes(player, profile)
		local changed = false
		for _, pass in MonetizationConfig.GamePasses do
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
			end)
			if ok and owns and not has(profile.StoreOwnership.GamePasses, pass.Id) then
				self:_grantGamePass(player, profile, pass)
				changed = true
			end
		end
		if changed then
			if self.Profiles.Save then self.Profiles:Save(player) end
			self:_publish(player, profile)
		end
	end)
end

function Service:Start()
	if self.Started then return end
	self.Started = true
	celebrationPackRemote()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local profile = self.Profiles:GetProfile(player)
		if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end
		ensureProfileFields(profile)
		local purchaseId = tostring(receiptInfo.PurchaseId or "")
		if purchaseId ~= "" and profile.PurchaseHistory[purchaseId] == true then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local product = MonetizationConfig.GetProductById(receiptInfo.ProductId)
		if not product then
			warn("[VTR MONETIZATION] Unknown product id: " .. tostring(receiptInfo.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = pcall(function()
			self:_grantProduct(player, profile, product)
		end)
		if not ok then
			warn("[VTR MONETIZATION] Grant failed: " .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if purchaseId ~= "" then profile.PurchaseHistory[purchaseId] = true end
		if self.Profiles.Save then self.Profiles:Save(player) end
		self:_publish(player, profile)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then return end
		local profile = self.Profiles:GetProfile(player)
		if not profile then return end
		for _, pass in MonetizationConfig.GamePasses do
			if pass.GamePassId == gamePassId then
				self:_grantGamePass(player, profile, pass)
				if self.Profiles.Save then self.Profiles:Save(player) end
				self:_publish(player, profile)
				break
			end
		end
	end)
	for _, player in Players:GetPlayers() do self:_syncOwnedPasses(player) end
	Players.PlayerAdded:Connect(function(player) self:_syncOwnedPasses(player) end)
end

return Service
