--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarCardConfig = require(ReplicatedStorage.VTR.Shared.StarCardConfig)
local PlayerDatabase = require(script.Parent.Parent.Data.PlayerDatabase)
local CardInstanceFactory = require(script.Parent.Parent.Data.CardInstanceFactory)

local Service = {}

local function dayIndex(now: number?): number
	return math.floor(math.max(0, now or os.time()) / StarCardConfig.DaySeconds)
end

local function nextReset(now: number?): number
	local stamp = math.max(0, now or os.time())
	return (math.floor(stamp / StarCardConfig.DaySeconds) + 1) * StarCardConfig.DaySeconds
end

local function hash(value: string): number
	local result = 2166136261
	for index = 1, #value do
		result = (bit32.bxor(result, string.byte(value, index)) * 16777619) % 4294967296
	end
	return result
end

local function candidates(): {any}
	local result = {}
	for _, player in PlayerDatabase.Players do
		local overall = tonumber(player.overall) or 0
		if overall >= StarCardConfig.MinOverall and overall <= StarCardConfig.MaxOverall then
			table.insert(result, player)
		end
	end
	table.sort(result, function(a, b)
		if a.overall == b.overall then
			return tostring(a.playerId) < tostring(b.playerId)
		end
		return a.overall > b.overall
	end)
	return result
end

local function choose(seed: string, avoidPlayerId: string?): any?
	local pool = candidates()
	if #pool == 0 then return nil end
	local start = (hash(seed) % #pool) + 1
	for offset = 0, #pool - 1 do
		local index = ((start + offset - 1) % #pool) + 1
		local player = pool[index]
		if tostring(player.playerId) ~= tostring(avoidPlayerId or "") then
			return player
		end
	end
	return pool[start]
end

local function ensureState(profile: any): any
	profile.StarCard = type(profile.StarCard) == "table" and profile.StarCard or {}
	profile.StarCard.RerollsToday = tonumber(profile.StarCard.RerollsToday) or 0
	profile.StarCard.RerollDay = tonumber(profile.StarCard.RerollDay) or 0
	return profile.StarCard
end

function Service.GetOffer(profile: any, userId: number, now: number?): any?
	local state = ensureState(profile)
	local day = dayIndex(now)
	local playerId = tostring(state.OfferPlayerId or state.Offer or "")
	local definition = playerId ~= "" and PlayerDatabase.Get(playerId) or nil
	if state.OfferDay ~= day or not definition then
		definition = choose(tostring(userId) .. ":" .. tostring(day) .. ":daily", nil)
		state.OfferDay = day
		state.OfferPlayerId = definition and definition.playerId or nil
		state.Offer = state.OfferPlayerId
		state.RerollDay = day
		state.RerollsToday = 0
	end
	if not definition then return nil end
	return {
		Player = CardInstanceFactory.GetDetails({playerId = definition.playerId, cardInstanceId = "star_offer_" .. tostring(definition.playerId)}) or definition,
		PlayerId = definition.playerId,
		OfferDay = state.OfferDay,
		RerollsToday = state.RerollsToday,
		NextResetAt = nextReset(now),
		SecondsUntilReset = math.max(0, nextReset(now) - math.max(0, now or os.time())),
		MinOverall = StarCardConfig.MinOverall,
		MaxOverall = StarCardConfig.MaxOverall,
	}
end

function Service.Reroll(profile: any, userId: number, now: number?): any?
	Service.GetOffer(profile, userId, now)
	local state = ensureState(profile)
	local day = dayIndex(now)
	if state.RerollDay ~= day then
		state.RerollDay = day
		state.RerollsToday = 0
	end
	state.RerollsToday += 1
	local current = tostring(state.OfferPlayerId or state.Offer or "")
	local definition = choose(tostring(userId) .. ":" .. tostring(day) .. ":reroll:" .. tostring(state.RerollsToday), current)
	state.OfferDay = day
	state.OfferPlayerId = definition and definition.playerId or nil
	state.Offer = state.OfferPlayerId
	return Service.GetOffer(profile, userId, now)
end

return Service
