--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local PlayerDatabase = require(script.Parent.Parent.Data.PlayerDatabase)

local Service = {}

local function ownedBasePlayers(profile: any): any
	local result = {}
	for _, card in profile.PlayerCardInventory or {} do
		local id = tostring(card.basePlayerId or card.BasePlayerId or card.playerId or card.PlayerId or "")
		if id ~= "" then result[id] = true end
	end
	return result
end

local function positionsMatch(player: any, allowed: any): boolean
	for _, position in player.positions or {} do if table.find(allowed, position) then return true end end
	return table.find(allowed, player.bestPosition) ~= nil
end

local function baseIdentity(player: any): string
	return tostring(player.basePlayerId or player.playerId)
end

local function sanitize(player: any): any
	return {
		playerId = player.playerId, displayName = player.displayName, shortName = player.shortName,
		overall = player.overall, bestPosition = player.bestPosition, positions = table.clone(player.positions or {}),
		country = player.country, club = player.club, league = player.league, rarity = player.rarity,
		cardType = player.cardType, portraitSeed = player.portraitSeed, appearance = table.clone(player.appearance or {}),
		mainStats = table.clone(player.mainStats or {}),
	}
end

local function seedFor(season: any, reroll: number): number
	return bit32.band((tonumber(season.Seed) or 1) + 12347 + reroll * 100003, 0x7fffffff)
end

function Service.Generate(profile: any, season: any, reroll: boolean?): any
	local division = Config.GetDivision(season.DivisionId)
	if not division then return nil end
	local focus = Config.ScoutingFocuses[season.ScoutingFocus] and season.ScoutingFocus or "Any Position"
	local allowed = Config.ScoutingFocuses[focus]
	local minimum = math.min(division.ScoutingMax, division.ScoutingMin + math.clamp(math.floor(tonumber(season.ScoutingQualityBonus) or 0), 0, 1))
	local maximum = division.ScoutingMax
	local facilityLevel = math.clamp(math.floor(tonumber(profile.CampaignProgress.Facilities.scouting) or 0), 0, 3)
	local count = math.min(5, division.ScoutingChoices + (facilityLevel >= 2 and 1 or 0))
	local previous = {}
	if reroll and type(season.PendingPromotionChoice) == "table" then
		for _, id in season.PendingPromotionChoice.OptionIds or {} do previous[id] = true end
	end
	local owned = ownedBasePlayers(profile)
	local preferred = {}
	local fallback = {}
	local previousFallback = {}
	local previousSeen = {}
	for _, player in PlayerDatabase.Players do
		local identity = baseIdentity(player)
		if player.overall >= minimum and player.overall <= maximum and player.cardType == "Base" and player.rarity ~= "Icon" and player.rarity ~= "Mythic" and positionsMatch(player, allowed) then
			if previous[player.playerId] then
				if not previousSeen[player.playerId] then previousSeen[player.playerId] = true table.insert(previousFallback, player) end
			elseif not owned[identity] then table.insert(preferred, player) else table.insert(fallback, player) end
		end
	end
	if #preferred + #fallback < count then
		for _, player in PlayerDatabase.Players do
			if player.overall >= minimum and player.overall <= maximum and player.cardType == "Base" and player.rarity ~= "Icon" and player.rarity ~= "Mythic" then
				if previous[player.playerId] then
					if not previousSeen[player.playerId] then previousSeen[player.playerId] = true table.insert(previousFallback, player) end
				elseif not table.find(preferred, player) and not table.find(fallback, player) then
					if not owned[baseIdentity(player)] then table.insert(preferred, player) else table.insert(fallback, player) end
				end
			end
		end
	end
	table.sort(preferred, function(a, b) return a.playerId < b.playerId end)
	table.sort(fallback, function(a, b) return a.playerId < b.playerId end)
	table.sort(previousFallback, function(a, b) return a.playerId < b.playerId end)
	local pool = {}
	for _, player in preferred do table.insert(pool, player) end
	for _, player in fallback do table.insert(pool, player) end
	if #pool < count then for index = 1, math.min(count - #pool, #previousFallback) do table.insert(pool, previousFallback[index]) end end
	if #pool < count then return nil end
	local random = Random.new(seedFor(season, reroll and 1 or 0))
	local selected = {}
	local usedBase = {}
	while #selected < count and #pool > 0 do
		local player = table.remove(pool, random:NextInteger(1, #pool))
		local identity = baseIdentity(player)
		if not usedBase[identity] then usedBase[identity] = true table.insert(selected, player) end
	end
	if #selected < count then return nil end
	local optionIds = {}
	local options = {}
	for _, player in selected do table.insert(optionIds, player.playerId) table.insert(options, sanitize(player)) end
	local choice = {
		ChoiceId = season.SeasonId .. ":promotion:" .. tostring((tonumber(season.ScoutingRerollsUsed) or 0) + 1),
		DivisionId = division.Id, SeasonId = season.SeasonId, Focus = focus, MinimumOverall = minimum, MaximumOverall = maximum,
		OptionIds = optionIds, Options = options, GeneratedAt = os.time(), Claimed = false, SelectedPlayerId = nil,
		RerollAvailable = facilityLevel >= 3 and (tonumber(season.ScoutingRerollsUsed) or 0) < 1,
	}
	season.PendingPromotionChoice = choice
	return choice
end

function Service.Reroll(profile: any, season: any): (boolean, string, any?)
	if math.floor(tonumber(profile.CampaignProgress.Facilities.scouting) or 0) < 3 then return false, "Upgrade Scouting Network to level 3 first.", nil end
	local choice = season.PendingPromotionChoice
	if type(choice) ~= "table" or choice.Claimed == true then return false, "No promotion choice is available.", nil end
	if (tonumber(season.ScoutingRerollsUsed) or 0) >= 1 then return false, "The scouting reroll has already been used this season.", nil end
	season.ScoutingRerollsUsed = 1
	local generated = Service.Generate(profile, season, true)
	if not generated then season.ScoutingRerollsUsed = 0 return false, "Scouting could not create a new valid shortlist.", nil end
	generated.RerollAvailable = false
	return true, "Scouting shortlist refreshed.", generated
end

function Service.Claim(player: Player, profile: any, season: any, playerId: string, inventory: any): (boolean, string, any?)
	local choice = season.PendingPromotionChoice
	if type(choice) ~= "table" then return false, "No promotion player is waiting to be claimed.", nil end
	if choice.Claimed == true then return false, "This promotion player was already claimed.", nil end
	if type(playerId) ~= "string" or #playerId > 96 or not table.find(choice.OptionIds or {}, playerId) then return false, "Select a player from the persisted scouting shortlist.", nil end
	local existingCard = nil
	for _, card in profile.PlayerCardInventory or {} do
		local cardId = card.cardInstanceId or card.Id
		local meta = profile.PlayerCardMeta[cardId]
		if meta and meta.CampaignChoiceId == choice.ChoiceId then existingCard = card break end
	end
	if existingCard then playerId = tostring(existingCard.playerId or existingCard.PlayerId or playerId) end
	if not table.find(choice.OptionIds or {}, playerId) then return false, "The persisted promotion delivery does not match this shortlist.", nil end
	local definition = PlayerDatabase.Get(playerId)
	if not definition then return false, "That player definition is unavailable.", nil end
	local metadata = {
		CampaignBound = true, CampaignReward = true, QuickSellBlocked = true, TransferBlocked = true,
		AcquisitionSource = "CampaignPromotion", CampaignDivisionId = season.DivisionId,
		CampaignSeasonId = season.SeasonId, CampaignVariant = "Ascension", CampaignChoiceId = choice.ChoiceId,
	}
	local granted, card = true, existingCard
	if not card then granted, card = inventory:AddCard(player, definition, metadata) end
	if not granted or not card then return false, "The promotion player could not be added to your club.", nil end
	local cardId = card.cardInstanceId or card.Id
	profile.PlayerCardMeta[cardId] = profile.PlayerCardMeta[cardId] or {}
	local meta = profile.PlayerCardMeta[cardId]
	for key, value in metadata do meta[key] = value end
	choice.Claimed = true
	choice.SelectedPlayerId = playerId
	choice.ClaimedCardInstanceId = cardId
	choice.ClaimedAt = os.time()
	season.PromotionRewardPlayer = sanitize(definition)
	return true, definition.displayName .. " joined your club.", card
end

return Service
