from pathlib import Path
import re

root = Path.cwd()
service_path = root / "src/server/Services/WorldCampaignWinProgressService.lua"
service_path.parent.mkdir(parents=True, exist_ok=True)

service_path.write_text(r'''
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldCampaignWinProgressService = {}

local recent = {}

local function s(value)
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function lower(value)
	return string.lower(s(value))
end

local function isPlayer(value)
	return typeof(value) == "Instance" and value:IsA("Player")
end

local function isTable(value)
	return typeof(value) == "table"
end

local function hasWord(value, word)
	return string.find(lower(value), string.lower(word), 1, true) ~= nil
end

local function modeOf(value)
	if isTable(value) then
		local direct = value.Mode or value.mode or value.MatchMode or value.matchMode or value.GameMode or value.gameMode or value.Type or value.type or value.Kind or value.kind or value.Competition or value.competition
		if direct then
			local m = modeOf(direct)
			if m then
				return m
			end
		end

		for _, child in pairs(value) do
			if typeof(child) == "string" then
				local m = modeOf(child)
				if m then
					return m
				end
			end
		end
	end

	local text = lower(value)
	if hasWord(text, "worldcup") or hasWord(text, "world cup") or hasWord(text, "world_cup") then
		return "WorldCup"
	end

	if hasWord(text, "campaign") or hasWord(text, "fixture") or hasWord(text, "objective") or hasWord(text, "mission") then
		return "Campaign"
	end

	return nil
end

local function resultIsWin(value)
	if value == true then
		return true
	end

	if isTable(value) then
		local direct = value.Won or value.won or value.IsWin or value.isWin or value.Win or value.win or value.Victory or value.victory
		if direct ~= nil then
			return direct == true or lower(direct) == "true" or lower(direct) == "win" or lower(direct) == "won" or lower(direct) == "victory"
		end

		local result = value.Result or value.result or value.Outcome or value.outcome or value.State or value.state
		if result ~= nil then
			return resultIsWin(result)
		end

		local homeScore = tonumber(value.HomeScore or value.homeScore or value.homeGoals or value.HomeGoals)
		local awayScore = tonumber(value.AwayScore or value.awayScore or value.awayGoals or value.AwayGoals)
		local playerTeam = value.PlayerTeam or value.playerTeam or value.UserTeam or value.userTeam or value.Team or value.team
		local winnerTeam = value.WinnerTeam or value.winnerTeam or value.WinningTeam or value.winningTeam or value.Winner or value.winner

		if winnerTeam and playerTeam and lower(winnerTeam) == lower(playerTeam) then
			return true
		end

		if homeScore and awayScore and playerTeam then
			local t = lower(playerTeam)
			if (hasWord(t, "home") or t == "1") and homeScore > awayScore then
				return true
			end
			if (hasWord(t, "away") or t == "2") and awayScore > homeScore then
				return true
			end
		end
	end

	local text = lower(value)
	return text == "win" or text == "won" or text == "victory" or text == "completewin" or text == "success"
end

local function profileModules()
	local modules = {}

	local roots = {
		ServerScriptService,
		ServerScriptService:FindFirstChild("VTRServer"),
		ServerScriptService:FindFirstChild("VTRServer") and ServerScriptService.VTRServer:FindFirstChild("Services"),
	}

	for _, parent in ipairs(roots) do
		if parent then
			for _, name in ipairs({ "StoreService", "ProfileService", "ProgressionService", "DataService", "PlayerDataService" }) do
				local child = parent:FindFirstChild(name)
				if child and child:IsA("ModuleScript") then
					local ok, module = pcall(require, child)
					if ok and typeof(module) == "table" then
						table.insert(modules, module)
					end
				end
			end
		end
	end

	return modules
end

local cachedModules = nil

local function modules()
	if cachedModules then
		return cachedModules
	end

	cachedModules = profileModules()
	return cachedModules
end

local function getProfile(player)
	for _, module in ipairs(modules()) do
		local tries = {
			function()
				return module.GetProfile and module:GetProfile(player)
			end,
			function()
				return module.GetProfile and module:GetProfile(player.UserId)
			end,
			function()
				return module.GetData and module:GetData(player)
			end,
			function()
				return module.GetData and module:GetData(player.UserId)
			end,
			function()
				return module.GetPlayerData and module:GetPlayerData(player)
			end,
			function()
				return module.Profiles and module.Profiles[player]
			end,
			function()
				return module.Profiles and module.Profiles[player.UserId]
			end,
		}

		for _, fn in ipairs(tries) do
			local ok, result = pcall(fn)
			if ok and typeof(result) == "table" then
				return result
			end
		end
	end

	return nil
end

local function dataOf(profile)
	if typeof(profile) ~= "table" then
		return nil
	end

	if typeof(profile.Data) == "table" then
		return profile.Data
	end

	return profile
end

local function save(player)
	for _, module in ipairs(modules()) do
		local tries = {
			function()
				if module.Save then
					module:Save(player)
				end
			end,
			function()
				if module.SaveAsync then
					module:SaveAsync(player)
				end
			end,
			function()
				if module.SavePlayer then
					module:SavePlayer(player)
				end
			end,
			function()
				if module.MarkDirty then
					module:MarkDirty(player)
				end
			end,
		}

		for _, fn in ipairs(tries) do
			pcall(fn)
		end
	end
end

local function publish(player, key, value)
	local vtr = ReplicatedStorage:FindFirstChild("VTR")
	local remotes = vtr and vtr:FindFirstChild("Remotes")
	if not remotes then
		return
	end

	local dataUpdated = remotes:FindFirstChild("DataUpdated")
	if dataUpdated and dataUpdated:IsA("RemoteEvent") then
		pcall(function()
			dataUpdated:FireClient(player, key, value)
		end)
	end

	local updateData = remotes:FindFirstChild("UpdateData")
	if updateData and updateData:IsA("RemoteEvent") then
		pcall(function()
			updateData:FireClient(player, key, value)
		end)
	end
end

local function ensure(data, key)
	if typeof(data[key]) ~= "table" then
		data[key] = {}
	end

	return data[key]
end

local function inc(tableValue, key, amount)
	tableValue[key] = tonumber(tableValue[key]) or 0
	tableValue[key] += amount
end

local function markRecent(player, mode, contextId)
	local token = tostring(player.UserId) .. ":" .. tostring(mode) .. ":" .. tostring(contextId or "")
	local now = os.clock()

	if recent[token] and now - recent[token] < 8 then
		return false
	end

	recent[token] = now
	return true
end

function WorldCampaignWinProgressService.RegisterWin(player, mode, context)
	if not isPlayer(player) then
		return false
	end

	mode = modeOf(mode) or modeOf(context)
	if mode ~= "WorldCup" and mode ~= "Campaign" then
		return false
	end

	local contextId = nil
	if isTable(context) then
		contextId = context.MatchId or context.matchId or context.GameId or context.gameId or context.FixtureId or context.fixtureId or context.CampaignId or context.campaignId or context.ObjectiveId or context.objectiveId
	end

	if not markRecent(player, mode, contextId) then
		return false
	end

	local profile = getProfile(player)
	local data = dataOf(profile)
	if not data then
		return false
	end

	data.Stats = data.Stats or {}
	data.Progression = data.Progression or {}

	if mode == "WorldCup" then
		local worldCup = ensure(data, "WorldCup")
		inc(worldCup, "Wins", 1)
		inc(worldCup, "GamesPlayed", 1)
		inc(data.Stats, "WorldCupWins", 1)
		inc(data.Progression, "WorldCupWins", 1)
		data.LastWorldCupWinAt = os.time()
		publish(player, "WorldCup", worldCup)
	else
		local campaign = ensure(data, "Campaign")
		local fixtures = ensure(data, "Fixtures")
		local objectives = ensure(data, "Objectives")
		inc(campaign, "Wins", 1)
		inc(campaign, "GamesPlayed", 1)
		inc(fixtures, "Wins", 1)
		inc(objectives, "Wins", 1)
		inc(data.Stats, "CampaignWins", 1)
		inc(data.Progression, "CampaignWins", 1)
		data.LastCampaignWinAt = os.time()
		publish(player, "Campaign", campaign)
		publish(player, "Fixtures", fixtures)
		publish(player, "Objectives", objectives)
	end

	data.UpdatedAt = os.time()
	save(player)
	publish(player, "Stats", data.Stats)
	publish(player, "Progression", data.Progression)

	return true
end

local function collectPlayers(value, out)
	if isPlayer(value) then
		out[value] = true
		return
	end

	if not isTable(value) then
		return
	end

	for _, key in ipairs({ "Player", "player", "User", "user", "Owner", "owner" }) do
		if isPlayer(value[key]) then
			out[value[key]] = true
		end
	end

	local userId = value.UserId or value.userId or value.PlayerUserId or value.playerUserId
	if userId then
		local player = Players:GetPlayerByUserId(tonumber(userId) or 0)
		if player then
			out[player] = true
		end
	end

	for _, key in ipairs({ "Players", "players", "TeamPlayers", "teamPlayers", "UserPlayers", "userPlayers" }) do
		local list = value[key]
		if isTable(list) then
			for _, child in pairs(list) do
				collectPlayers(child, out)
			end
		end
	end
end

local function collectWinnerPlayers(value, out)
	if not isTable(value) then
		return
	end

	for _, key in ipairs({ "WinnerPlayer", "winnerPlayer", "WinningPlayer", "winningPlayer", "Player", "player" }) do
		collectPlayers(value[key], out)
	end

	local winnerTeam = value.WinnerTeam or value.winnerTeam or value.WinningTeam or value.winningTeam or value.WinnerSide or value.winnerSide
	if winnerTeam then
		local w = lower(winnerTeam)
		if hasWord(w, "home") or w == "1" then
			collectPlayers(value.HomePlayers or value.homePlayers or value.HomeTeamPlayers or value.homeTeamPlayers or value.HomeTeam or value.homeTeam, out)
		elseif hasWord(w, "away") or w == "2" then
			collectPlayers(value.AwayPlayers or value.awayPlayers or value.AwayTeamPlayers or value.awayTeamPlayers or value.AwayTeam or value.awayTeam, out)
		end
	end
end

function WorldCampaignWinProgressService.TryRegisterFromArgs(...)
	local args = { ... }
	local mode = nil
	local won = false
	local players = {}
	local context = nil

	for _, value in ipairs(args) do
		mode = mode or modeOf(value)

		if isTable(value) then
			context = context or value
			if resultIsWin(value) then
				won = true
			end
			collectWinnerPlayers(value, players)
		elseif resultIsWin(value) then
			won = true
		elseif isPlayer(value) then
			players[value] = true
		end
	end

	if not mode then
		return false
	end

	if not won then
		for _, value in ipairs(args) do
			if isTable(value) then
				local result = value.Result or value.result or value.Outcome or value.outcome or value.MatchResult or value.matchResult
				if resultIsWin(result) then
					won = true
					break
				end
			end
		end
	end

	if not won then
		return false
	end

	local changed = false
	for player in pairs(players) do
		changed = WorldCampaignWinProgressService.RegisterWin(player, mode, context) or changed
	end

	return changed
end

return WorldCampaignWinProgressService
'''.strip() + "\n", encoding="utf-8")

loader = r'''
local function vtrLoadWorldCampaignWinProgress()
	local current = script
	while current do
		local services = current:FindFirstChild("Services")
		if services and services:FindFirstChild("WorldCampaignWinProgressService") then
			return require(services:WaitForChild("WorldCampaignWinProgressService"))
		end

		if current.Parent then
			local sibling = current.Parent:FindFirstChild("Services")
			if sibling and sibling:FindFirstChild("WorldCampaignWinProgressService") then
				return require(sibling:WaitForChild("WorldCampaignWinProgressService"))
			end
		end

		current = current.Parent
	end

	return require(game:GetService("ServerScriptService"):WaitForChild("VTRServer"):WaitForChild("Services"):WaitForChild("WorldCampaignWinProgressService"))
end

local VTRWorldCampaignWinProgress = vtrLoadWorldCampaignWinProgress()
'''

def clean_line(line):
	line = re.sub(r'".*?"', '""', line)
	line = re.sub(r"'.*?'", "''", line)
	line = re.sub(r"--.*$", "", line)
	return line

def delta(line):
	c = clean_line(line)
	inc = len(re.findall(r"\bfunction\b", c)) + len(re.findall(r"\bthen\b", c)) + len(re.findall(r"\bdo\b", c)) + len(re.findall(r"\brepeat\b", c))
	dec = len(re.findall(r"\bend\b", c)) + len(re.findall(r"\buntil\b", c))
	return inc - dec

def insert_loader(text):
	if "VTRWorldCampaignWinProgress" in text:
		return text

	lines = text.splitlines()
	index = 0
	while index < len(lines) and lines[index].startswith("--!"):
		index += 1

	lines.insert(index, loader.strip())
	return "\n".join(lines) + "\n"

def args_from(raw):
	args = []
	for part in raw.split(","):
		part = part.strip()
		if part == "" or part == "...":
			continue
		part = part.split("=")[0].strip()
		if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", part):
			args.append(part)
	return args

def function_should_patch(name, block):
	low = (name + "\n" + block).lower()

	if "vtrworldcampaignwinprogress" in low:
		return False

	if not any(x in low for x in ["campaign", "worldcup", "world cup", "fixture", "objective", "mission"]):
		return False

	return any(x in low for x in ["win", "won", "victory", "complete", "finish", "result", "resolve", "endmatch", "matchend", "award", "progress"])

def patch_functions(text):
	lines = text.splitlines()
	out = []
	i = 0
	changed = False

	while i < len(lines):
		line = lines[i]
		m = re.match(r"^(\s*)(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_:\.]*)\s*\((.*)\)", line)

		if not m:
			out.append(line)
			i += 1
			continue

		start = i
		depth = 1
		j = i + 1
		block = [line]

		while j < len(lines) and depth > 0:
			block.append(lines[j])
			depth += delta(lines[j])
			j += 1

		block_text = "\n".join(block)

		if not function_should_patch(m.group(2), block_text):
			out.extend(block)
			i = j
			continue

		args = args_from(m.group(3))
		passed = ["self"] if ":" in m.group(2) else []
		passed.extend(args)
		passed_expr = ", ".join(passed) if passed else "nil"
		indent = m.group(1) + "\t"

		out.append(block[0])
		out.append(indent + "VTRWorldCampaignWinProgress.TryRegisterFromArgs(" + passed_expr + ")")
		out.extend(block[1:])
		changed = True
		i = j

	return "\n".join(out) + "\n", changed

def patch_branches(text):
	if "VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)" in text:
		return text, False

	lines = text.splitlines()
	out = []
	changed = False

	for i, line in enumerate(lines):
		out.append(line)
		low = line.lower()

		if not any(x in low for x in ["campaign", "worldcup", "world cup", "fixture", "objective", "mission"]):
			continue

		if not any(x in low for x in ["win", "won", "victory", "complete", "result", "finish", "success"]):
			continue

		if not re.search(r"\bif\b|\belseif\b", line) or "then" not in low:
			continue

		indent = re.match(r"^(\s*)", line).group(1) + "\t"
		out.append(indent + "VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)")
		changed = True

	return "\n".join(out) + "\n", changed

patched = []

for path in sorted((root / "src/server").rglob("*.lua")):
	if path == service_path:
		continue

	text = path.read_text(encoding="utf-8", errors="ignore")
	low = text.lower()
	path_low = path.as_posix().lower()

	if not any(x in low or x in path_low for x in ["campaign", "worldcup", "world cup", "fixture", "objective", "mission", "matchruntime", "referee"]):
		continue

	if not any(x in low for x in ["win", "won", "victory", "complete", "finish", "result", "resolve", "award", "progress"]):
		continue

	original = text
	text = insert_loader(text)
	text, a = patch_functions(text)
	text, b = patch_branches(text)

	if text != original and (a or b):
		path.write_text(text.strip() + "\n", encoding="utf-8")
		patched.append(path.relative_to(root).as_posix())

print("created src/server/Services/WorldCampaignWinProgressService.lua")
for item in patched:
	print("patched", item)