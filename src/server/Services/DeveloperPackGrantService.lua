--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local DeveloperAccessService = require(script.Parent.DeveloperAccessService)
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))

local Service = {}
Service.__index = Service

local function packList(): {any}
	local list = {}
	for id, definition in Catalog.Packs do
		table.insert(list, {
			Id = id,
			Name = tostring(definition.Name or id),
			PriceCoins = tonumber(definition.PriceCoins) or 0,
		})
	end
	table.sort(list, function(a, b)
		if a.PriceCoins == b.PriceCoins then return tostring(a.Id) < tostring(b.Id) end
		return a.PriceCoins < b.PriceCoins
	end)
	return list
end

local function findPlayer(query: any): Player?
	local text = string.lower(tostring(query or ""))
	local userId = tonumber(query)
	for _, player in Players:GetPlayers() do
		if userId and player.UserId == userId then return player end
		if text ~= "" and (string.lower(player.Name) == text or string.lower(player.DisplayName) == text) then return player end
		if text ~= "" and (string.find(string.lower(player.Name), text, 1, true) or string.find(string.lower(player.DisplayName), text, 1, true)) then
			return player
		end
	end
	return nil
end

function Service.new(profiles: any, inventory: any, progression: any, publish: (Player, string, any) -> (), notifications: any, fiveVFiveQueue: any?)
	return setmetatable({
		Profiles = profiles,
		Inventory = inventory,
		Progression = progression,
		Publish = publish,
		Notifications = notifications,
		FiveVFiveQueue = fiveVFiveQueue,
	}, Service)
end

function Service:_clientData()
	local players = {}
	for _, player in Players:GetPlayers() do
		table.insert(players, {UserId = player.UserId, Name = player.Name, DisplayName = player.DisplayName})
	end
	table.sort(players, function(a, b) return tostring(a.Name) < tostring(b.Name) end)
	return {Packs = packList(), Players = players}
end

function Service:Handle(player: Player, action: any, payload: any): (boolean, string, any?)
	if not DeveloperAccessService.IsOwner(player) then
		return false, "Owner access required.", nil
	end
	action = tostring(action or "")
	payload = type(payload) == "table" and payload or {}
	if action == "GetDeveloperPackGrant" then
		return true, "Developer pack bar ready.", self:_clientData()
	end
	if action == "CancelFiveVFive" then
		if not self.FiveVFiveQueue or not self.FiveVFiveQueue.CancelActiveMatches then
			return false, "5v5 cancel service unavailable.", self:_clientData()
		end
		local ok, message, data = self.FiveVFiveQueue:CancelActiveMatches("DeveloperCancel")
		if self.Notifications then
			self.Notifications:Send(player, "5V5 DEV", message, ok and "Reward" or "Error")
		end
		return ok, message, data
	end
	if action ~= "GrantPack" then
		return false, "Invalid developer action.", nil
	end
	local target = findPlayer(payload.Target)
	if not target then return false, "Target player is not online.", self:_clientData() end
	local packId = tostring(payload.PackId or "")
	local definition = Catalog.Packs[packId]
	if not definition then return false, "Unknown pack.", self:_clientData() end
	local quantity = math.clamp(math.floor(tonumber(payload.Quantity) or 1), 1, 25)
	local delivered, instances = self.Inventory:AddPack(target, packId, tostring(definition.Name or packId), "DeveloperGrant", quantity)
	if not delivered then return false, "Pack grant failed.", self:_clientData() end
	for _ = 1, quantity do
		VTRPendingPackAnimation.Queue(target, packId)
	end
	if self.Publish then
		if self.Inventory.GetClientData then
			pcall(function() self.Publish(target, "Inventory", self.Inventory:GetClientData(target)) end)
		end
		if self.Progression and self.Progression.GetClientData then
			pcall(function() self.Publish(target, "Progression", self.Progression:GetClientData(target)) end)
		end
	end
	if self.Notifications then
		self.Notifications:Send(target, "DEV PACK GRANT", tostring(definition.Name or packId) .. " x" .. tostring(quantity) .. " added.", "Reward")
		self.Notifications:Send(player, "DEV PACK GRANT", "Gave " .. target.Name .. " " .. tostring(definition.Name or packId) .. " x" .. tostring(quantity) .. ".", "Reward")
	end
	if self.Profiles and self.Profiles.Save then self.Profiles:Save(target) end
	return true, "Pack granted.", {Target = target.Name, PackId = packId, Quantity = quantity, Instances = instances, State = self:_clientData()}
end

return Service
