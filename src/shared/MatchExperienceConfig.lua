--!strict

local profiles = table.freeze({
	Acquisition = table.freeze({Name = "Acquisition", Duration = 4, SkipLock = 0, ReadinessTimeout = 5, Tunnel = false, Lineup = false, StadiumTour = false}),
	Standard = table.freeze({Name = "Standard", Duration = 8, SkipLock = 0.5, ReadinessTimeout = 6, Tunnel = false, Lineup = false, StadiumTour = true}),
	Broadcast = table.freeze({Name = "Broadcast", Duration = 20, SkipLock = 0.5, ReadinessTimeout = 8, Tunnel = true, Lineup = true, StadiumTour = true}),
})

local aliases = {
	FirstMatch = "Acquisition",
	Tutorial = "Acquisition",
	Compact = "Standard",
	Immersive = "Broadcast",
	Ranked = "Broadcast",
}

local function normalize(value: any): string
	local text = tostring(value or "")
	local resolved = aliases[text] or text
	if profiles[resolved] ~= nil then
		return resolved
	end
	return "Standard"
end

local function resolve(setup: any, profile: any): string
	local settings = if type(profile) == "table" then profile.Settings else nil
	if type(setup) == "table" then
		local mode = string.lower(tostring(setup.Mode or setup.MatchType or ""))
		local round = string.lower(tostring(setup.WorldCupRound or setup.Round or ""))
		if string.find(mode, "ranked", 1, true) ~= nil or string.find(round, "semifinal", 1, true) ~= nil or string.find(round, "final", 1, true) ~= nil then
			return "Broadcast"
		end
	end
	local progress = if type(profile) == "table" and type(profile.PlayabilityProgress) == "table" then profile.PlayabilityProgress else nil
	local completed = math.max(0, math.floor(tonumber(progress and progress.CompletedMatches) or 0))
	local legacy = progress and progress.LegacyAccessGranted == true
	if type(setup) == "table" and (setup.WorldCupOnboarding == true or setup.Tutorial == true or setup.FirstPlayableMatch == true) then return "Acquisition" end
	if completed < 3 and not legacy then return "Acquisition" end
	if type(settings) == "table" and settings.ImmersivePresentation == true then
		return "Broadcast"
	end
	return "Standard"
end

local function get(value: any): any
	return profiles[normalize(value)]
end

return table.freeze({
	Profiles = profiles,
	Normalize = normalize,
	Resolve = resolve,
	Get = get,
})
