--!strict

local HttpService = game:GetService("HttpService")
local PlayerDatabase = require(script.Parent.PlayerDatabase)

local CardInstanceFactory = {}

local function roleFor(position: string): string
	if position == "GK" then return "KEEPER" end
	if position == "CB" or position == "LB" or position == "RB" then return "DEFENDER" end
	if position == "CM" or position == "CDM" or position == "CAM" then return "CREATOR" end
	return "ATTACKER"
end

function CardInstanceFactory.Create(playerDefinition: any): any
	local instanceId = "card_" .. HttpService:GenerateGUID(false)
	local cardType = playerDefinition.cardType
	return {
		cardInstanceId = instanceId,
		playerId = playerDefinition.playerId,
		displayName = playerDefinition.displayName,
		rarity = playerDefinition.rarity,
		overall = playerDefinition.overall,
		bestPosition = playerDefinition.bestPosition,
		positions = table.clone(playerDefinition.positions),
		appearance = table.clone(playerDefinition.appearance),
		portraitSeed = playerDefinition.portraitSeed,
		mainStats = table.clone(playerDefinition.mainStats),
		cardType = cardType,
		location = "club",
		-- Compatibility aliases for the current squad and mode UI.
		Id = instanceId,
		PlayerId = playerDefinition.playerId,
		Name = playerDefinition.displayName,
		Rating = playerDefinition.overall,
		Position = playerDefinition.bestPosition,
		Rarity = playerDefinition.rarity,
		CardType = cardType,
		MainStats = table.clone(playerDefinition.mainStats),
		ShortName = playerDefinition.shortName,
		Country = playerDefinition.country,
		League = playerDefinition.league,
		Club = playerDefinition.fictionalClub,
		Nation = playerDefinition.nationality,
		RoleTag = roleFor(playerDefinition.bestPosition),
	}
end

function CardInstanceFactory.Hydrate(instance: any): boolean
	local definition = PlayerDatabase.Get(instance.playerId or instance.PlayerId or "")
	if not definition then return false end
	instance.cardInstanceId = instance.cardInstanceId or instance.Id or ("card_" .. HttpService:GenerateGUID(false))
	instance.playerId = definition.playerId
	instance.displayName = definition.displayName
	instance.rarity = definition.rarity
	instance.overall = definition.overall
	instance.bestPosition = definition.bestPosition
	instance.positions = table.clone(definition.positions)
	instance.appearance = table.clone(definition.appearance)
	instance.mainStats = table.clone(definition.mainStats)
	instance.cardType = definition.cardType
	instance.portraitSeed = definition.portraitSeed
	instance.location = instance.location or instance.Location or "club"
	instance.Location = instance.location
	instance.Id = instance.cardInstanceId
	instance.PlayerId = definition.playerId
	instance.Name = definition.displayName
	instance.Rating = definition.overall
	instance.Position = definition.bestPosition
	instance.Rarity = instance.rarity
	instance.CardType = instance.cardType
	instance.MainStats = table.clone(definition.mainStats)
	instance.ShortName = definition.shortName
	instance.Country = definition.country
	instance.League = definition.league
	instance.Club = definition.fictionalClub
	instance.Nation = definition.nationality
	instance.RoleTag = roleFor(definition.bestPosition)
	return true
end

function CardInstanceFactory.FromLegacy(legacy: any, ordinal: number): any
	local rarity = legacy.Rarity or legacy.rarity or "Starter"
	local pool = PlayerDatabase.Pools[rarity] or PlayerDatabase.Pools.Starter
	local wantedPosition = legacy.Position or legacy.bestPosition
	local candidates = {}
	for _, definition in pool do if not wantedPosition or definition.bestPosition == wantedPosition then table.insert(candidates, definition) end end
	if #candidates == 0 then candidates = pool end
	return CardInstanceFactory.Create(candidates[((ordinal - 1) % #candidates) + 1])
end

function CardInstanceFactory.GetDetails(instance: any): any?
	local definition = PlayerDatabase.Get(instance.playerId or instance.PlayerId or "")
	if not definition then return nil end
	local details = table.clone(definition)
	details.cardInstanceId = instance.cardInstanceId or instance.Id
	details.rarity = definition.rarity
	details.cardType = instance.cardType or instance.CardType or definition.cardType
	details.Rarity = details.rarity
	details.CardType = details.cardType
	details.Id = details.cardInstanceId
	details.PlayerId = details.playerId
	details.Name = details.displayName
	details.Rating = details.overall
	details.Position = details.bestPosition
	details.Club = details.fictionalClub
	details.Nation = details.nationality
	details.MainStats = table.clone(details.mainStats)
	return details
end

return CardInstanceFactory
