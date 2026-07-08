from pathlib import Path
import re

root = Path.cwd()

service = root / "src/server/Services/RankedWinRegistrationService.lua"
service.parent.mkdir(parents=True, exist_ok=True)

service.write_text(r'''
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local RankedWinRegistrationService = {}

local processed = {}
local storeService = nil

local function now()
	return os.time()
end

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function asNumber(value)
	local n = tonumber(value)
	if not n then
		return nil
	end
	return n
end

local function dataOf(profile)
	if typeof(profile) == "table" and typeof(profile.Data) == "table" then
		return profile.Data
	end
	return profile
end

local function addUnique(list, player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	for _, existing in ipairs(list) do
		if existing == player then
			return
		end
	end

	table.insert(list, player)
end

local function addPlayersFrom(value, list)
	if typeof(value) == "Instance" and value:IsA("Player") then
		addUnique(list, value)
		return
	end

	if typeof(value) ~= "table" then
		return
	end

	for _, item in pairs(value) do
		if typeof(item) == "Instance" and item:IsA("Player") then
			addUnique(list, item)
		elseif typeof(item) == "table" then
			addPlayersFrom(item, list)
		end
	end
end

local function tryRequireStore()
	if storeService then
		return storeService
	end

	local folders = {
		script.Parent,
		ServerScriptService:FindFirstChild("Services"),
		ServerScriptService:FindFirstChild("VTRServer") and ServerScriptService.VTRServer:FindFirstChild("Services"),
		ServerScriptService,
	}

	for _, folder in ipairs(folders) do
		if folder then
			for _, name in ipairs({ "StoreService", "DataService", "ProfileService", "PlayerDataService", "ProgressionService" }) do
				local module = folder:FindFirstChild(name)
				if module and module:IsA("ModuleScript") then
					local ok, result = pcall(require, module)
					if ok and typeof(result) == "table" then
						storeService = result
						return storeService
					end
				end
			end
		end
	end

	return nil
end

local function callMethod(target, names, ...)
	if typeof(target) ~= "table" then
		return nil
	end

	for _, name in ipairs(names) do
		local fn = target[name]
		if typeof(fn) == "function" then
			local ok, result = pcall(fn, target, ...)
			if ok and result ~= nil then
				return result
			end

			ok, result = pcall(fn, ...)
			if ok and result ~= nil then
				return result
			end
		end
	end

	return nil
end

local function profileFor(player)
	local store = tryRequireStore()
	if not store then
		return nil
	end

	local direct = callMethod(store, {
		"GetProfile",
		"GetPlayerProfile",
		"GetData",
		"GetPlayerData",
		"GetProfileData",
		"ProfileFor",
	}, player)

	if typeof(direct) == "table" then
		return direct
	end

	direct = callMethod(store, {
		"GetProfile",
		"GetPlayerProfile",
		"GetData",
		"GetPlayerData",
		"GetProfileData",
		"ProfileFor",
	}, player.UserId)

	if typeof(direct) == "table" then
		return direct
	end

	for _, key in ipairs({ "Profiles", "PlayerProfiles", "ProfileByPlayer", "DataByPlayer", "LoadedProfiles" }) do
		local tableValue = store[key]
		if typeof(tableValue) == "table" then
			local profile = tableValue[player] or tableValue[player.UserId] or tableValue[tostring(player.UserId)]
			if typeof(profile) == "table" then
				return profile
			end
		end
	end

	return nil
end

local function savePlayer(player)
	local store = tryRequireStore()
	if not store then
		return
	end

	callMethod(store, {
		"Save",
		"SavePlayer",
		"SaveAsync",
		"SavePlayerAsync",
		"Flush",
		"FlushPlayer",
	}, player)

	callMethod(store, {
		"Save",
		"SavePlayer",
		"SaveAsync",
		"SavePlayerAsync",
		"Flush",
		"FlushPlayer",
	}, player.UserId)
end

local function bumpField(tbl, name, amount)
	if typeof(tbl) ~= "table" then
		return
	end

	tbl[name] = (tonumber(tbl[name]) or 0) + amount
end

local function bumpData(data, result)
	if typeof(data) ~= "table" then
		return
	end

	if result == "Win" then
		bumpField(data, "Wins", 1)
		bumpField(data, "RankedWins", 1)
		bumpField(data, "PathWins", 1)
		bumpField(data, "DivisionPathWins", 1)
	else
		bumpField(data, "Losses", 1)
		bumpField(data, "RankedLosses", 1)
		bumpField(data, "PathLosses", 1)
		bumpField(data, "DivisionPathLosses", 1)
	end

	local pathWins = tonumber(data.PathWins or data.DivisionPathWins) or 0
	local pathLosses = tonumber(data.PathLosses or data.DivisionPathLosses) or 0
	data.PathGames = pathWins + pathLosses
	data.DivisionPathGames = pathWins + pathLosses

	for _, key in ipairs({ "Ranked", "Stats", "Record", "Season", "Career" }) do
		if typeof(data[key]) ~= "table" then
			data[key] = {}
		end

		if result == "Win" then
			bumpField(data[key], "Wins", 1)
			bumpField(data[key], "RankedWins", 1)
		else
			bumpField(data[key], "Losses", 1)
			bumpField(data[key], "RankedLosses", 1)
		end
	end

	if typeof(data.Ranked) == "table" then
		if result == "Win" then
			bumpField(data.Ranked, "PathWins", 1)
			bumpField(data.Ranked, "DivisionPathWins", 1)
		else
			bumpField(data.Ranked, "PathLosses", 1)
			bumpField(data.Ranked, "DivisionPathLosses", 1)
		end

		local rankedPathWins = tonumber(data.Ranked.PathWins or data.Ranked.DivisionPathWins) or 0
		local rankedPathLosses = tonumber(data.Ranked.PathLosses or data.Ranked.DivisionPathLosses) or 0
		data.Ranked.PathGames = rankedPathWins + rankedPathLosses
		data.Ranked.DivisionPathGames = rankedPathWins + rankedPathLosses
	end

	data.UpdatedAt = now()
end

local function bumpLeaderstats(player, result)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats then
		local name = result == "Win" and "Wins" or "Losses"
		local value = leaderstats:FindFirstChild(name) or leaderstats:FindFirstChild(string.lower(name)) or leaderstats:FindFirstChild("Ranked" .. name)

		if value and value:IsA("ValueBase") then
			value.Value = (tonumber(value.Value) or 0) + 1
		end
	end

	if result == "Win" then
		player:SetAttribute("Wins", (tonumber(player:GetAttribute("Wins")) or 0) + 1)
		player:SetAttribute("RankedWins", (tonumber(player:GetAttribute("RankedWins")) or 0) + 1)
		player:SetAttribute("PathWins", (tonumber(player:GetAttribute("PathWins")) or 0) + 1)
		player:SetAttribute("DivisionPathWins", (tonumber(player:GetAttribute("DivisionPathWins")) or 0) + 1)
	else
		player:SetAttribute("Losses", (tonumber(player:GetAttribute("Losses")) or 0) + 1)
		player:SetAttribute("RankedLosses", (tonumber(player:GetAttribute("RankedLosses")) or 0) + 1)
		player:SetAttribute("PathLosses", (tonumber(player:GetAttribute("PathLosses")) or 0) + 1)
		player:SetAttribute("DivisionPathLosses", (tonumber(player:GetAttribute("DivisionPathLosses")) or 0) + 1)
	end

	local pathWins = tonumber(player:GetAttribute("PathWins")) or tonumber(player:GetAttribute("DivisionPathWins")) or 0
	local pathLosses = tonumber(player:GetAttribute("PathLosses")) or tonumber(player:GetAttribute("DivisionPathLosses")) or 0

	player:SetAttribute("PathGames", pathWins + pathLosses)
	player:SetAttribute("DivisionPathGames", pathWins + pathLosses)
end

local function award(player, result, matchKey)
	if not player or not player.Parent then
		return false
	end

	local playerKey = tostring(player.UserId) .. ":" .. tostring(matchKey)

	if processed[playerKey] then
		return false
	end

	processed[playerKey] = now()
	player:SetAttribute("VTRLastRegisteredMatchKey", tostring(matchKey))

	local profile = profileFor(player)
	if profile then
		bumpData(dataOf(profile), result)
		savePlayer(player)
	end

	bumpLeaderstats(player, result)

	return true
end

local function textWinner(value)
	local v = lower(value)

	if v == "home" or v == "hometeam" or v == "team1" or v == "a" then
		return "Home"
	end

	if v == "away" or v == "awayteam" or v == "team2" or v == "b" then
		return "Away"
	end

	return nil
end

local function getNumberFrom(value, names)
	if typeof(value) ~= "table" then
		return nil
	end

	for _, name in ipairs(names) do
		local n = asNumber(value[name])
		if n ~= nil then
			return n
		end
	end

	return nil
end

local function getValue(value, names)
	if typeof(value) ~= "table" then
		return nil
	end

	for _, name in ipairs(names) do
		if value[name] ~= nil then
			return value[name]
		end
	end

	return nil
end

local function readContextValue(value, state)
	if typeof(value) == "Instance" and value:IsA("Player") then
		local side = textWinner(value:GetAttribute("TeamSide") or value:GetAttribute("MatchSide") or value:GetAttribute("Side"))
		local teamName = lower(value.Team and value.Team.Name or value:GetAttribute("Team") or value:GetAttribute("MatchTeam"))

		if side == "Home" or string.find(teamName, "home") then
			addUnique(state.homePlayers, value)
		elseif side == "Away" or string.find(teamName, "away") then
			addUnique(state.awayPlayers, value)
		else
			addUnique(state.allPlayers, value)
		end

		return
	end

	if typeof(value) ~= "table" then
		local winner = textWinner(value)
		if winner and not state.winner then
			state.winner = winner
		end

		return
	end

	if not state.matchId then
		state.matchId = getValue(value, {
			"MatchId",
			"matchId",
			"MatchID",
			"Id",
			"id",
			"GameId",
			"gameId",
			"RoundId",
			"roundId",
		})
	end

	local winner = textWinner(getValue(value, {
		"Winner",
		"winner",
		"WinningSide",
		"winningSide",
		"WinningTeam",
		"winningTeam",
		"Result",
		"result",
		"Outcome",
		"outcome",
	}))

	if winner and not state.winner then
		state.winner = winner
	end

	local homeScore = getNumberFrom(value, {
		"HomeScore",
		"homeScore",
		"ScoreHome",
		"scoreHome",
		"HomeGoals",
		"homeGoals",
		"Team1Score",
		"team1Score",
	})

	local awayScore = getNumberFrom(value, {
		"AwayScore",
		"awayScore",
		"ScoreAway",
		"scoreAway",
		"AwayGoals",
		"awayGoals",
		"Team2Score",
		"team2Score",
	})

	if homeScore ~= nil then
		state.homeScore = homeScore
	end

	if awayScore ~= nil then
		state.awayScore = awayScore
	end

	addPlayersFrom(getValue(value, {
		"HomePlayers",
		"homePlayers",
		"HomeTeamPlayers",
		"homeTeamPlayers",
		"Team1Players",
		"team1Players",
	}), state.homePlayers)

	addPlayersFrom(getValue(value, {
		"AwayPlayers",
		"awayPlayers",
		"AwayTeamPlayers",
		"awayTeamPlayers",
		"Team2Players",
		"team2Players",
	}), state.awayPlayers)

	if typeof(value.Home) == "table" then
		addPlayersFrom(value.Home.Players or value.Home.players or value.Home.Roster or value.Home.roster, state.homePlayers)
		local n = asNumber(value.Home.Score or value.Home.score or value.Home.Goals or value.Home.goals)
		if n ~= nil then
			state.homeScore = n
		end
	end

	if typeof(value.Away) == "table" then
		addPlayersFrom(value.Away.Players or value.Away.players or value.Away.Roster or value.Away.roster, state.awayPlayers)
		local n = asNumber(value.Away.Score or value.Away.score or value.Away.Goals or value.Away.goals)
		if n ~= nil then
			state.awayScore = n
		end
	end

	if typeof(value.Teams) == "table" then
		readContextValue(value.Teams.Home or value.Teams.home or value.Teams[1], state)
		readContextValue(value.Teams.Away or value.Teams.away or value.Teams[2], state)
	end
end

local function collectFromArgs(state, ...)
	for index = 1, select("#", ...) do
		readContextValue(select(index, ...), state)
	end
end

local function completeTeamsFromPlayers(state)
	for _, player in ipairs(Players:GetPlayers()) do
		local side = textWinner(player:GetAttribute("TeamSide") or player:GetAttribute("MatchSide") or player:GetAttribute("Side"))
		local teamName = lower(player.Team and player.Team.Name or player:GetAttribute("Team") or player:GetAttribute("MatchTeam"))

		if side == "Home" or string.find(teamName, "home") then
			addUnique(state.homePlayers, player)
		elseif side == "Away" or string.find(teamName, "away") then
			addUnique(state.awayPlayers, player)
		end
	end
end

local function resolveWinner(state)
	if state.winner then
		return state.winner
	end

	if state.homeScore ~= nil and state.awayScore ~= nil then
		if state.homeScore > state.awayScore then
			return "Home"
		elseif state.awayScore > state.homeScore then
			return "Away"
		end
	end

	return nil
end

function RankedWinRegistrationService.RecordFromContext(context, ...)
	local state = {
		winner = nil,
		homeScore = nil,
		awayScore = nil,
		homePlayers = {},
		awayPlayers = {},
		allPlayers = {},
		matchId = nil,
	}

	readContextValue(context, state)
	collectFromArgs(state, ...)
	completeTeamsFromPlayers(state)

	local winner = resolveWinner(state)
	if not winner then
		return false
	end

	local matchKey = tostring(state.matchId or "") .. ":" .. tostring(state.homeScore or "x") .. ":" .. tostring(state.awayScore or "x") .. ":" .. winner

	if matchKey == ":x:x:" .. winner then
		matchKey = tostring(math.floor(now() / 15)) .. ":" .. winner
	end

	local winners = winner == "Home" and state.homePlayers or state.awayPlayers
	local losers = winner == "Home" and state.awayPlayers or state.homePlayers

	if #winners == 0 and #state.allPlayers > 0 then
		winners = state.allPlayers
	end

	local changed = false

	for _, player in ipairs(winners) do
		changed = award(player, "Win", matchKey) or changed
	end

	for _, player in ipairs(losers) do
		changed = award(player, "Loss", matchKey) or changed
	end

	return changed
end

function RankedWinRegistrationService.Register(winner, context, ...)
	return RankedWinRegistrationService.RecordFromContext(context, winner, ...)
end

function RankedWinRegistrationService.Record(winner, context, ...)
	return RankedWinRegistrationService.RecordFromContext(context, winner, ...)
end

return RankedWinRegistrationService
'''.strip() + "\n", encoding="utf-8")

loader = r'''
local function vtrLoadRankedWinRegistration()
	local current = script
	while current do
		local services = current:FindFirstChild("Services")
		if services and services:FindFirstChild("RankedWinRegistrationService") then
			return require(services:WaitForChild("RankedWinRegistrationService"))
		end

		if current.Parent then
			local sibling = current.Parent:FindFirstChild("Services")
			if sibling and sibling:FindFirstChild("RankedWinRegistrationService") then
				return require(sibling:WaitForChild("RankedWinRegistrationService"))
			end
		end

		current = current.Parent
	end

	return require(game:GetService("ServerScriptService"):WaitForChild("VTRServer"):WaitForChild("Services"):WaitForChild("RankedWinRegistrationService"))
end

local VTRRankedWinRegistration = vtrLoadRankedWinRegistration()
'''

def clean_line(line):
	line = re.sub(r'".*?"', '""', line)
	line = re.sub(r"'.*?'", "''", line)
	line = re.sub(r"--.*$", "", line)
	return line

def depth_delta(line):
	c = clean_line(line)
	inc = len(re.findall(r"\bfunction\b", c)) + len(re.findall(r"\bthen\b", c)) + len(re.findall(r"\bdo\b", c)) + len(re.findall(r"\brepeat\b", c))
	dec = len(re.findall(r"\bend\b", c)) + len(re.findall(r"\buntil\b", c))
	return inc - dec

def args_from(raw):
	out = []
	for part in raw.split(","):
		name = part.strip()
		if name == "" or name == "...":
			continue
		name = name.split(":")[0].split("=")[0].strip()
		if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", name):
			out.append(name)
	return out

def should_patch(name):
	low = name.lower()
	return (
		("match" in low or "game" in low or "round" in low)
		and ("end" in low or "finish" in low or "complete" in low or "resolve" in low or "result" in low or "conclude" in low)
	)

def success_line(line):
	low = line.strip().lower()
	if not low.startswith("return"):
		return False
	if low in { "return", "return nil", "return false" }:
		return False
	if low.startswith("return nil") or low.startswith("return false") then
		return False
	end
	return True
end

def add_loader(text):
	if "VTRRankedWinRegistration" in text:
		return text

	lines = text.splitlines()
	index = 0

	while index < len(lines) and lines[index].startswith("--!"):
		index += 1

	lines.insert(index, loader.strip())
	return "\n".join(lines) + "\n"

def patch_file(path):
	text = path.read_text(encoding="utf-8", errors="ignore")
	original = text

	text = add_loader(text)
	lines = text.splitlines()
	out = []
	i = 0

	while i < len(lines):
		line = lines[i]
		m = re.match(r"^(\s*)(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_:\.]*)\s*\((.*)\)", line)

		if not m or not should_patch(m.group(2)):
			out.append(line)
			i += 1
			continue

		depth = 1
		block = [line]
		j = i + 1

		while j < len(lines) and depth > 0:
			block.append(lines[j])
			depth += depth_delta(lines[j])
			j += 1

		block_text = "\n".join(block)
		if "vtrRegisterWinResultNow" in block_text:
			out.extend(block)
			i = j
			continue

		indent = m.group(1)
		body = indent + "\t"
		args = args_from(m.group(3))
		arg_expr = ", ".join(args) if args else "nil"
		context = "self" if ":" in m.group(2) or (args and args[0] == "self") else "nil"

		new_block = [block[0]]
		new_block.append(body + "local vtrWinResultRegistered = false")
		new_block.append(body + "local vtrWinResultArgs = { " + arg_expr + " }")
		new_block.append(body + "local vtrWinResultContext = " + context)
		new_block.append(body + "local function vtrRegisterWinResultNow()")
		new_block.append(body + "\tif vtrWinResultRegistered then")
		new_block.append(body + "\t\treturn")
		new_block.append(body + "\tend")
		new_block.append(body + "\tvtrWinResultRegistered = true")
		new_block.append(body + "\tpcall(function()")
		new_block.append(body + "\t\tVTRRankedWinRegistration.RecordFromContext(vtrWinResultContext, table.unpack(vtrWinResultArgs))")
		new_block.append(body + "\tend)")
		new_block.append(body + "end")

		depth = 1

		for index in range(1, len(block)):
			current = block[index]
			low = current.lower()

			if depth == 1 and ("matchended" in low or "match_end" in low or "gameended" in low or "result" in low or "winner" in low) and "vtrRegisterWinResultNow" not in current:
				new_block.append(body + "vtrRegisterWinResultNow()")

			if depth == 1 and current.strip().startswith("return") and "false" not in low and "nil" not in low:
				new_block.append(body + "vtrRegisterWinResultNow()")

			if depth == 1 and current.strip() == "end":
				new_block.append(body + "vtrRegisterWinResultNow()")

			new_block.append(current)
			depth += depth_delta(current)

		out.extend(new_block)
		i = j

	text = "\n".join(out) + "\n"

	if text != original:
		path.write_text(text.strip() + "\n", encoding="utf-8")
		return True

	return False

patched = []

targets = [
	root / "src/server/Gameplay/MatchRuntimeService.lua",
	root / "src/server/Gameplay/RefereeService.lua",
	root / "src/server/Gameplay/TeamControlService.lua",
]

for path in targets:
	if path.exists() and patch_file(path):
		patched.append(path.relative_to(root).as_posix())

print("patched src/server/Services/RankedWinRegistrationService.lua")
for item in patched:
	print("patched", item)