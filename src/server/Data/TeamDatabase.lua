--!strict

local PlayerDatabase = require(script.Parent.PlayerDatabase)

local MINIMUM_TEAMS_PER_COUNTRY = 18
local MAX_ROSTER_SIZE = 25
local DEFAULT_FORMATION = "4-3-3"

local palette = {
	{ "B7FF1A", "050505", "D9D9D9" }, { "245BFF", "F5F7F2", "FFCB45" },
	{ "D91E36", "F5F7F2", "111111" }, { "7D2CFF", "111111", "B7FF1A" },
	{ "FF7A18", "050505", "F5F7F2" }, { "17C3B2", "111111", "D9D9D9" },
	{ "F5D547", "192A56", "F5F7F2" }, { "D9D9D9", "1B1B1B", "9FFF00" },
}
local generatedNames = {
	"Apex", "Athletic", "City", "Comets", "Dynamos", "Eclipse", "Forge", "Guardians", "Metro",
	"Neon", "Nova", "Olympic", "Pulse", "Rangers", "Rovers", "Storm", "Titans", "United",
}

local function slug(value: string): string
	local result = string.lower(value):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	return result ~= "" and result or "vtr"
end

local function dominant(counts: { [string]: number }, fallback: string): string
	local winner, highest = fallback, -1
	for value, count in counts do
		if count > highest or (count == highest and value < winner) then winner, highest = value, count end
	end
	return winner
end

local function compactPlayer(player: any): any
	return {
		playerId = player.playerId, displayName = player.displayName, shortName = player.shortName,
		overall = player.overall, bestPosition = player.bestPosition, rarity = player.rarity,
		cardType = player.cardType, country = player.country, club = player.club,
		portraitSeed = player.portraitSeed, appearance = player.appearance, mainStats = player.mainStats,
	}
end

local function matches(player: any, positions: { string }): boolean
	for _, position in positions do
		if player.bestPosition == position or table.find(player.positions, position) then return true end
	end
	return false
end

local function arrangeRoster(source: { any }): { any }
	local sorted = table.clone(source)
	table.sort(sorted, function(a, b)
		if a.overall == b.overall then return a.playerId < b.playerId end
		return a.overall > b.overall
	end)
	local used: { [string]: boolean } = {}
	local starting = {}
	local rolePlan = {
		{ "GK" }, { "LB", "LWB", "CB" }, { "CB" }, { "CB" }, { "RB", "RWB", "CB" },
		{ "CM", "CDM", "CAM" }, { "CDM", "CM" }, { "CM", "CAM" },
		{ "LW", "LM", "ST" }, { "ST", "CF" }, { "RW", "RM", "ST" },
	}
	for _, positions in rolePlan do
		local chosen = nil
		for _, player in sorted do
			if not used[player.playerId] and matches(player, positions) then chosen = player; break end
		end
		if not chosen then
			for _, player in sorted do if not used[player.playerId] then chosen = player; break end end
		end
		if chosen then used[chosen.playerId] = true; table.insert(starting, chosen) end
	end
	local arranged = table.clone(starting)
	for _, player in sorted do
		if not used[player.playerId] and #arranged < MAX_ROSTER_SIZE then table.insert(arranged, player) end
	end
	return arranged
end

local function mean(players: { any }, predicate: ((any) -> boolean)?): number
	local total, count = 0, 0
	for _, player in players do
		if not predicate or predicate(player) then total += player.overall; count += 1 end
	end
	return count > 0 and math.floor(total / count + 0.5) or 0
end

local playersByClub: { [string]: { any } } = {}
local playersByCountry: { [string]: { any } } = {}
local countryLeagueCounts: { [string]: { [string]: number } } = {}
for _, player in PlayerDatabase.Players do
	playersByClub[player.club] = playersByClub[player.club] or {}
	table.insert(playersByClub[player.club], player)
	playersByCountry[player.country] = playersByCountry[player.country] or {}
	table.insert(playersByCountry[player.country], player)
	countryLeagueCounts[player.country] = countryLeagueCounts[player.country] or {}
	countryLeagueCounts[player.country][player.league] = (countryLeagueCounts[player.country][player.league] or 0) + 1
end

local teams, byId = {}, {}
local teamsByCountry: { [string]: { any } } = {}

local function register(teamName: string, country: string, league: string, source: { any }, generated: boolean)
	local roster = arrangeRoster(source)
	if #roster < 18 then return end
	local starting = {}; for index = 1, math.min(11, #roster) do table.insert(starting, roster[index]) end
	local index = #teams + 1
	local colors = palette[(index - 1) % #palette + 1]
	local id = string.format("%s_%s_%03d", slug(country), slug(teamName), index)
	local forwards = { ST = true, CF = true, LW = true, RW = true, LM = true, RM = true }
	local midfielders = { CM = true, CDM = true, CAM = true, LM = true, RM = true }
	local defenders = { GK = true, CB = true, LB = true, RB = true, LWB = true, RWB = true }
	local team = {
		teamId = id, teamName = teamName, country = country, league = league,
		overall = mean(starting), attack = mean(starting, function(p) return forwards[p.bestPosition] == true end),
		midfield = mean(starting, function(p) return midfielders[p.bestPosition] == true end),
		defense = mean(starting, function(p) return defenders[p.bestPosition] == true end),
		formation = DEFAULT_FORMATION, badgePreset = generated and "GeneratedHex" or "ClubShield",
		logo = string.upper(string.sub(teamName:gsub("[^%a]", ""), 1, 2)), generated = generated,
		colors = { Primary = colors[1], Secondary = colors[2], Accent = colors[3] },
		kits = {
			Home = { Name = "Home", Primary = colors[1], Secondary = colors[2], Accent = colors[3], Style = "Vertical Stripes", NumberColor = colors[3] },
			Away = { Name = "Away", Primary = colors[2], Secondary = colors[3], Accent = colors[1], Style = "Solid", NumberColor = colors[1] },
			Third = { Name = "Third", Primary = colors[3], Secondary = colors[1], Accent = colors[2], Style = "Diagonal Sash", NumberColor = colors[2] },
		},
		roster = roster,
	}
	team.homeKit, team.awayKit, team.thirdKit = team.kits.Home, team.kits.Away, team.kits.Third
	team.starPlayers = { roster[1], roster[2], roster[3] }
	table.insert(teams, team); byId[id] = team
	teamsByCountry[country] = teamsByCountry[country] or {}; table.insert(teamsByCountry[country], team)
end

-- CSV clubs remain the first-class teams. Their country and circuit are inferred from their roster metadata.
local clubNames = {}; for club in playersByClub do table.insert(clubNames, club) end; table.sort(clubNames)
for _, club in clubNames do
	local clubPlayers = playersByClub[club]
	if #clubPlayers >= 18 then
		local countries, leagues = {}, {}
		for _, player in clubPlayers do
			countries[player.country] = (countries[player.country] or 0) + 1
			leagues[player.league] = (leagues[player.league] or 0) + 1
		end
		register(club, dominant(countries, "Global"), dominant(leagues, "Voltra League"), clubPlayers, false)
	end
end

-- Every imported country receives a playable 18-team circuit, even when CSV club coverage is sparse.
local countries = {}; for country in playersByCountry do table.insert(countries, country) end; table.sort(countries)
for _, country in countries do
	local countryPlayers = table.clone(playersByCountry[country])
	table.sort(countryPlayers, function(a, b) return a.overall > b.overall end)
	local circuit = dominant(countryLeagueCounts[country], country .. " Circuit")
	local numberNeeded = MINIMUM_TEAMS_PER_COUNTRY - #(teamsByCountry[country] or {})
	for generatedIndex = 1, numberNeeded do
		local pool, seen = {}, {}
		local start = ((generatedIndex - 1) * 11) % math.max(1, #countryPlayers)
		for step = 0, math.min(#countryPlayers, MAX_ROSTER_SIZE) - 1 do
			local player = countryPlayers[(start + step) % #countryPlayers + 1]
			if player and not seen[player.playerId] then seen[player.playerId] = true; table.insert(pool, player) end
		end
		if #pool < 18 then
			for _, player in PlayerDatabase.Players do
				if not seen[player.playerId] then seen[player.playerId] = true; table.insert(pool, player) end
				if #pool >= MAX_ROSTER_SIZE then break end
			end
		end
		register(country .. " " .. generatedNames[((generatedIndex - 1) % #generatedNames) + 1], country, circuit, pool, true)
	end
end

for _, country in countries do
	assert(#(teamsByCountry[country] or {}) >= MINIMUM_TEAMS_PER_COUNTRY, "Team coverage failed for " .. country)
	for _, team in teamsByCountry[country] do assert(#team.roster >= 18, "Incomplete roster for " .. team.teamId) end
end

local function playerSummaryList(source: { any }): { any }
	local result = {}; for _, player in source do table.insert(result, compactPlayer(player)) end; return result
end

local Database = { Count = #teams, CountryCount = #countries, Teams = teams, ById = byId, MinimumPerCountry = MINIMUM_TEAMS_PER_COUNTRY }

function Database.Get(id: string): any? return byId[id] end
function Database.Summary(team: any): any
	return {
		teamId = team.teamId, teamName = team.teamName, country = team.country, league = team.league,
		overall = team.overall, attack = team.attack, midfield = team.midfield, defense = team.defense,
		logo = team.logo, colors = table.clone(team.colors), kits = team.kits, formation = team.formation,
		badgePreset = team.badgePreset, generated = team.generated,
		starPlayers = playerSummaryList(team.starPlayers),
	}
end
function Database.GetSummaries(country: string?, league: string?): { any }
	local source = country and teamsByCountry[country] or teams
	local result = {}
	for _, team in source or {} do
		if not league or league == "" or team.league == league then table.insert(result, Database.Summary(team)) end
	end
	table.sort(result, function(a, b)
		if a.overall == b.overall then return a.teamName < b.teamName end
		return a.overall > b.overall
	end)
	return result
end
function Database.GetCountries(): { any }
	local result = {}
	for _, country in countries do
		local leagues, seen = {}, {}
		for _, team in teamsByCountry[country] or {} do
			if not seen[team.league] then seen[team.league] = true; table.insert(leagues, team.league) end
		end
		table.sort(leagues)
		table.insert(result, { Country = country, Leagues = leagues, TeamCount = #(teamsByCountry[country] or {}) })
	end
	return result
end
function Database.GetRoster(id: string): any?
	local team = byId[id]; if not team then return nil end
	local starting, bench, reserves = {}, {}, {}
	for index, player in team.roster do
		local destination = index <= 11 and starting or index <= 18 and bench or reserves
		table.insert(destination, compactPlayer(player))
	end
	return { Team = Database.Summary(team), StartingXI = starting, Bench = bench, Reserves = reserves, Formation = team.formation, BestPlayers = playerSummaryList(team.starPlayers) }
end

return table.freeze(Database)
