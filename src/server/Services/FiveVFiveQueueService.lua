--!strict

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local PlayBuilderConfig = require(ReplicatedStorage.VTR.Shared.PlayBuilderConfig)

local Service = {}
Service.__index = Service

local MATCH_SIZE = 10
local ACTIVE_MATCH_MAP = "VTR25_FiveVFiveActiveMatches_v1"
local LOBBY_MAP = "VTR25_FiveVFiveLobbies_v1"
local ACTIVE_MATCH_TTL = 45 * 60
local LOBBY_TTL = 5 * 60
local LOBBY_HEARTBEAT_SECONDS = 45
local ARRIVAL_WAIT_SECONDS = 60

local function playerName(player: Player): string
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

local function activeMap(): any?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(ACTIVE_MATCH_MAP)
	end)
	return ok and map or nil
end

local function lobbyMap(): any?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(LOBBY_MAP)
	end)
	return ok and map or nil
end

local function activeKey(userId: any): string
	return "u:" .. tostring(tonumber(userId) or 0)
end

local function compactPlayer(player: Player, builder: any?): any
	local entry = {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = playerName(player),
	}
	if builder then
		local normalized = PlayBuilderConfig.Normalize(builder)
		local stats = PlayBuilderConfig.StatsFor(normalized)
		entry.PlayBuilder = normalized
		entry.PlayOverall = stats.overall
		entry.PlayArchetype = normalized.Archetype
	end
	return entry
end

local function compactMatchPlayer(player: Player, team: string?, builder: any?): any
	local entry = compactPlayer(player, builder)
	if team == "Home" or team == "Away" then
		entry.Team = team
	end
	return entry
end

local function cleanText(value: any, fallback: string, maxLength: number): string
	local text = tostring(value or fallback):gsub("[%c\r\n\t]", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then text = fallback end
	return string.sub(text, 1, maxLength)
end

local function validTeamSize(value: any): number
	local size = math.floor(tonumber(value) or 5)
	if size ~= 3 and size ~= 4 and size ~= 5 then size = 5 end
	return size
end

local function characterReady(player: Player): boolean
	local character = player.Character
	if not character then return false end
	if not character:FindFirstChildOfClass("Humanoid") then return false end
	if not character:FindFirstChild("HumanoidRootPart") then return false end
	return true
end

function Service.new(runtime: any, publish: ((Player, string, any) -> ())?, notifications: any?, profiles: any?)
	local self = setmetatable({
		Runtime = runtime,
		Publish = publish,
		Notifications = notifications,
		Profiles = profiles,
		Queue = {},
		ByPlayer = {},
		Matches = {},
		Lobbies = {},
		PlayerLobby = {},
		PendingTeleportMatches = {},
	}, Service)
	task.spawn(function()
		while true do
			task.wait(LOBBY_HEARTBEAT_SECONDS)
			for _, lobby in self.Lobbies do
				self:_writeLobby(lobby)
			end
		end
	end)
	return self
end

function Service:_notify(player: Player, title: string, message: string, kind: string?)
	if self.Notifications then
		self.Notifications:Send(player, title, message, kind or "Info")
	end
end

function Service:_profile(player: Player): any?
	if not self.Profiles or not self.Profiles.GetProfile then
		return nil
	end
	return self.Profiles:GetProfile(player)
end

function Service:_playBuilder(player: Player): any
	local profile = self:_profile(player)
	if profile then
		local level = profile.Profile and profile.Profile.Level or profile.Season and profile.Season.Level or 1
		profile.PlayBuilder = PlayBuilderConfig.Normalize(profile.PlayBuilder, level)
		return profile.PlayBuilder
	end
	return PlayBuilderConfig.Normalize(nil)
end

function Service:_refreshEntryBuilder(entry: any): any
	if type(entry)~="table"then return entry end
	local userId=tonumber(entry.UserId)or 0
	local player=userId>0 and Players:GetPlayerByUserId(userId)or nil
	if player then
		local builder=self:_playBuilder(player)
		local stats=PlayBuilderConfig.StatsFor(builder)
		entry.PlayBuilder=builder
		entry.PlayOverall=stats.overall
		entry.PlayArchetype=builder.Archetype
	end
	return entry
end

function Service:_refreshMatchPayloadBuilders(payload: any): any
	if type(payload)~="table"then return payload end
	for _,entry in payload.Players or{}do
		self:_refreshEntryBuilder(entry)
	end
	return payload
end

function Service:GetPlayBuilder(player: Player): (boolean, string, any?)
	return true, "PLAY builder loaded.", self:_playBuilder(player)
end

function Service:SavePlayBuilder(player: Player, payload: any?): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then
		return false, "Profile unavailable.", nil
	end
	local level = profile.Profile and profile.Profile.Level or profile.Season and profile.Season.Level or 1
	local builder = PlayBuilderConfig.Normalize(payload, level)
	builder.UpdatedAt = os.time()
	profile.PlayBuilder = builder
	local lobby = self:_currentLobby(player)
	if lobby then
		for _, entry in lobby.Players or {} do
			if tonumber(entry.UserId) == player.UserId then
				entry.PlayBuilder = builder
			end
		end
		self:_writeLobby(lobby)
	end
	if self.Profiles and self.Profiles.Save then
		task.defer(function()
			self.Profiles:Save(player)
		end)
	end
	return true, "PLAY builder saved.", builder
end

function Service:_countQueued(): number
	local total = 0
	for _, entry in self.Queue do
		if entry.Player and entry.Player.Parent == Players then total += 1 end
	end
	return total
end

function Service:_queuedPlayers(): {any}
	local queued = {}
	for _, entry in self.Queue do
		local player = entry.Player
		if player and player.Parent == Players then
			table.insert(queued, compactPlayer(player, self:_playBuilder(player)))
		end
	end
	return queued
end

function Service:_remove(player: Player)
	local entry = self.ByPlayer[player]
	self.ByPlayer[player] = nil
	player:SetAttribute("VTRFiveVFiveQueued", nil)
	for index = #self.Queue, 1, -1 do
		if self.Queue[index] == entry or self.Queue[index].Player == player then
			table.remove(self.Queue, index)
		end
	end
end

function Service:_writeActive(match: any)
	local map = activeMap()
	if not map then return end
	for _, entry in match.Players or {} do
		pcall(function()
			map:SetAsync(activeKey(entry.UserId), match, ACTIVE_MATCH_TTL, os.time())
		end)
	end
end

function Service:_clearActive(match: any)
	local map = activeMap()
	if not map then return end
	for _, entry in match and match.Players or {} do
		pcall(function()
			map:RemoveAsync(activeKey(entry.UserId))
		end)
	end
end

function Service:_clearActivePlayers(players: {any})
	local map = activeMap()
	if not map then return end
	for _, entry in players or {} do
		pcall(function()
			map:RemoveAsync(activeKey(entry.UserId))
		end)
	end
end

function Service:_activeFor(player: Player): any?
	local map = activeMap()
	if not map then return nil end
	local ok, match = pcall(function()
		return map:GetAsync(activeKey(player.UserId))
	end)
	if not ok or type(match) ~= "table" then return nil end
	if tonumber(match.ExpiresAt) and tonumber(match.ExpiresAt) < os.time() then
		pcall(function() map:RemoveAsync(activeKey(player.UserId)) end)
		return nil
	end
	return match
end

function Service:_matchPayload(matchId: string, players: {any}, accessCode: string?, privateServerId: string?, teamSize: number?): any
	for _,entry in players do self:_refreshEntryBuilder(entry)end
	return {
		MatchMode = "FiveVFive",
		MatchId = matchId,
		TeamSize = validTeamSize(teamSize),
		Players = players,
		PlaceId = game.PlaceId,
		ReturnPlaceId = game.PlaceId,
		AccessCode = accessCode,
		PrivateServerId = privateServerId,
		CreatedAt = os.time(),
		ExpiresAt = os.time() + ACTIVE_MATCH_TTL,
	}
end

function Service:_lobbySummary(lobby: any): any
	local players = {}
	for _, entry in lobby.Players or {} do table.insert(players, entry) end
	return {
		LobbyId = lobby.LobbyId,
		Name = lobby.Name,
		HostUserId = lobby.HostUserId,
		HostName = lobby.HostName,
		TeamSize = lobby.TeamSize,
		RequiredPlayers = lobby.TeamSize * 2,
		PlayerCount = #players,
		Players = players,
		Home = lobby.Home or {},
		Away = lobby.Away or {},
		OpenJoin = lobby.OpenJoin == true,
		HasPassword = tostring(lobby.Password or "") ~= "",
		JobId = game.JobId,
		PlaceId = game.PlaceId,
		CreatedAt = lobby.CreatedAt,
		UpdatedAt = os.time(),
	}
end

function Service:_writeLobby(lobby: any)
	local map = lobbyMap()
	if not map or not lobby then return end
	pcall(function()
		map:SetAsync(tostring(lobby.LobbyId), self:_lobbySummary(lobby), LOBBY_TTL, os.time())
	end)
end

function Service:_removeLobbyListing(lobbyId: any)
	local map = lobbyMap()
	if not map then return end
	pcall(function()
		map:RemoveAsync(tostring(lobbyId))
	end)
end

function Service:_currentLobby(player: Player): any?
	local lobbyId = self.PlayerLobby[player]
	local lobby = lobbyId and self.Lobbies[lobbyId] or nil
	if lobbyId and not lobby then
		self.PlayerLobby[player] = nil
	end
	return lobby
end

function Service:_removeFromLobby(player: Player)
	local lobby = self:_currentLobby(player)
	if not lobby then return end
	self.PlayerLobby[player] = nil
	for index = #lobby.Players, 1, -1 do
		if tonumber(lobby.Players[index].UserId) == player.UserId then table.remove(lobby.Players, index) end
	end
	lobby.Home[player.UserId] = nil
	lobby.Away[player.UserId] = nil
	if lobby.HostUserId == player.UserId or #lobby.Players <= 0 then
		for _, entry in lobby.Players do
			local other = Players:GetPlayerByUserId(tonumber(entry.UserId) or 0)
			if other then self.PlayerLobby[other] = nil; self:_notify(other, "5V5 LOBBY", "Lobby closed.", "Error") end
		end
		self.Lobbies[lobby.LobbyId] = nil
		self:_removeLobbyListing(lobby.LobbyId)
	else
		lobby.HostUserId = tonumber(lobby.Players[1].UserId) or lobby.HostUserId
		lobby.HostName = tostring(lobby.Players[1].DisplayName or lobby.Players[1].Name or lobby.HostName)
		self:_writeLobby(lobby)
	end
end

function Service:_assignPlayer(lobby: any, userId: number, team: string?)
	lobby.Home[userId] = nil
	lobby.Away[userId] = nil
	team = team == "Away" and "Away" or team == "Home" and "Home" or nil
	if team then
		local bucket = lobby[team]
		local count = 0
		for _ in bucket do count += 1 end
		if count < lobby.TeamSize then bucket[userId] = true end
	end
end

function Service:_autoBalance(lobby: any)
	for _, entry in lobby.Players do
		local userId = tonumber(entry.UserId) or 0
		if not lobby.Home[userId] and not lobby.Away[userId] then
			local homeCount = 0
			local awayCount = 0
			for _ in lobby.Home do homeCount += 1 end
			for _ in lobby.Away do awayCount += 1 end
			if homeCount <= awayCount and homeCount < lobby.TeamSize then lobby.Home[userId] = true elseif awayCount < lobby.TeamSize then lobby.Away[userId] = true end
		end
	end
end

function Service:_teleportMatch(entries: {any}, teamSize: number?): (boolean, string, any?)
	local matchId = "fivevfive_" .. HttpService:GenerateGUID(false)
	teamSize = validTeamSize(teamSize)
	local required = teamSize * 2
	local players = {}
	local teleportPlayers = {}
	for _, entry in entries do
		if entry.Player and entry.Player.Parent == Players then
			table.insert(players, compactMatchPlayer(entry.Player, entry.Team, self:_playBuilder(entry.Player)))
			table.insert(teleportPlayers, entry.Player)
		end
	end
	if #teleportPlayers < required then return false, "Not enough 5v5 players are online.", nil end

	if RunService:IsStudio() or game.PlaceId == 0 then
		local payload = self:_matchPayload(matchId, players, nil, nil, teamSize)
		local modeLabel = tostring(teamSize) .. "v" .. tostring(teamSize)
		for _, player in teleportPlayers do
			self.Matches[player] = payload
			player:SetAttribute("VTRFiveVFiveMatchId", matchId)
			self:_notify(player, "PLAY", "Studio fallback: starting the " .. modeLabel .. " match locally.", "Info")
		end
		task.defer(function()
			local startedAt = os.clock()
			while os.clock() - startedAt < 12 do
				local ready = true
				for _, player in teleportPlayers do
					if player.Parent ~= Players or not characterReady(player) then
						ready = false
						break
					end
				end
				if ready then break end
				task.wait(.25)
			end
			if not self.Runtime or not self.Runtime.StartFiveVFiveMatch then return end
			local ok, message = self.Runtime:StartFiveVFiveMatch(teleportPlayers, self:_refreshMatchPayloadBuilders(payload))
			for _, player in teleportPlayers do
				if player.Parent == Players then
					self:_notify(player, ok and "5V5 MATCH" or "5V5 MATCH FAILED", message, ok and "Reward" or "Error")
				end
			end
		end)
		return true, "Studio " .. modeLabel .. " match starting locally.", payload
	end

	local okReserve, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not okReserve or type(accessCode) ~= "string" then
		return false, "Could not reserve a 5v5 match server.", nil
	end
	local payload = self:_matchPayload(matchId, players, accessCode, tostring(privateServerId or ""), teamSize)
	self:_writeActive(payload)
	for _, player in teleportPlayers do
		self.Matches[player] = payload
		player:SetAttribute("VTRFiveVFiveMatchId", matchId)
		self:_notify(player, "5V5 MATCH FOUND", "Teleporting to the 5v5 match server.", "Info")
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(payload)
	local okTeleport, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, teleportPlayers, options)
	end)
	if not okTeleport then
		self:_clearActive(payload)
		return false, "5v5 teleport failed: " .. tostring(err), nil
	end
	return true, "5v5 match found.", payload
end

function Service:_tryMatch(): any?
	if #self.Queue < MATCH_SIZE then return nil end
	local entries = {}
	for _, entry in self.Queue do
		if #entries >= MATCH_SIZE then break end
		if entry.Player and entry.Player.Parent == Players then table.insert(entries, entry) end
	end
	if #entries < MATCH_SIZE then return nil end
	for _, entry in entries do
		self:_remove(entry.Player)
	end
	local ok, message, payload = self:_teleportMatch(entries)
	if not ok then
		for _, entry in entries do
			if entry.Player and entry.Player.Parent == Players then
				table.insert(self.Queue, entry)
				self.ByPlayer[entry.Player] = entry
				entry.Player:SetAttribute("VTRFiveVFiveQueued", true)
				self:_notify(entry.Player, "5V5", message, "Error")
			end
		end
		return nil
	end
	return payload
end

function Service:Join(player: Player): (boolean, string, any?)
	return self:RandomJoin(player)
end

function Service:Leave(player: Player): (boolean, string, any?)
	if self.PlayerLobby[player] then
		self:_removeFromLobby(player)
		return true, "Left 5v5 lobby.", self:GetStatus(player)
	end
	if not self.ByPlayer[player] then return false, "You are not in the 5v5 queue.", self:GetStatus(player) end
	self:_remove(player)
	return true, "5v5 search cancelled.", self:GetStatus(player)
end

function Service:CreateLobby(player: Player, payload: any?): (boolean, string, any?)
	if player:GetAttribute("VTRInMatch") == true then return false, "Finish the current match first.", self:GetStatus(player) end
	local active = self:_activeFor(player)
	if active then return true, "You have a 5v5 match in progress.", {Status = "Rejoin", Mode = "FiveVFive", Match = active} end
	if self.PlayerLobby[player] then return false, "Leave your current 5v5 lobby first.", self:GetStatus(player) end
	payload = type(payload) == "table" and payload or {}
	local lobbyId = "lobby_" .. HttpService:GenerateGUID(false)
	local host = compactPlayer(player, self:_playBuilder(player))
	local lobby = {
		LobbyId = lobbyId,
		Name = cleanText(payload.Name, playerName(player) .. "'s Lobby", 32),
		HostUserId = player.UserId,
		HostName = playerName(player),
		TeamSize = validTeamSize(payload.TeamSize),
		OpenJoin = payload.OpenJoin ~= false,
		Password = payload.Password and cleanText(payload.Password, "", 24) or "",
		Players = {host},
		Home = {[player.UserId] = true},
		Away = {},
		CreatedAt = os.time(),
	}
	self.Lobbies[lobbyId] = lobby
	self.PlayerLobby[player] = lobbyId
	self:_writeLobby(lobby)
	return true, "5v5 lobby hosted.", self:GetStatus(player)
end

function Service:ListLobbies(_player: Player, query: any?): (boolean, string, any?)
	local search = string.lower(tostring(query or ""))
	local lobbies = {}
	for _, lobby in self.Lobbies do
		self:_writeLobby(lobby)
		table.insert(lobbies, self:_lobbySummary(lobby))
	end
	local map = lobbyMap()
	if map then
		local ok, pages = pcall(function()
			return map:GetRangeAsync(Enum.SortDirection.Descending, 50)
		end)
		if ok and type(pages) == "table" then
			for _, item in pages do
				local value = item.value
				if type(value) == "table" then table.insert(lobbies, value) end
			end
		end
	end
	local dedup = {}
	local filtered = {}
	for _, lobby in lobbies do
		local id = tostring(lobby.LobbyId or "")
		if id ~= "" and not dedup[id] then
			dedup[id] = true
			local haystack = string.lower(tostring(lobby.Name or "") .. " " .. tostring(lobby.HostName or ""))
			if search == "" or string.find(haystack, search, 1, true) then table.insert(filtered, lobby) end
		end
	end
	table.sort(filtered, function(a, b) return (tonumber(a.UpdatedAt) or 0) > (tonumber(b.UpdatedAt) or 0) end)
	return true, "5v5 lobbies loaded.", {Lobbies = filtered}
end

function Service:JoinLobby(player: Player, payload: any?): (boolean, string, any?)
	if player:GetAttribute("VTRInMatch") == true then return false, "Finish the current match first.", self:GetStatus(player) end
	payload = type(payload) == "table" and payload or {}
	local lobbyId = tostring(payload.LobbyId or "")
	local currentLobbyId = self.PlayerLobby[player] and tostring(self.PlayerLobby[player]) or ""
	if currentLobbyId ~= "" then
		if currentLobbyId == lobbyId then
			return true, "You are already in this PLAY lobby.", self:GetStatus(player)
		end
		return false, "Leave your current PLAY lobby before joining another.", self:GetStatus(player)
	end
	local lobby = self.Lobbies[lobbyId]
	if not lobby then
		local remoteJob = tostring(payload.JobId or "")
		if remoteJob ~= "" and remoteJob ~= game.JobId and not RunService:IsStudio() then
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData({MatchMode = "FiveVFiveLobbyJoin", LobbyId = lobbyId, Password = tostring(payload.Password or "")})
			local ok, err = pcall(function() TeleportService:TeleportAsync(game.PlaceId, {player}, options) end)
			return ok, ok and "Joining hosted 5v5 lobby." or ("Lobby teleport failed: " .. tostring(err)), self:GetStatus(player)
		end
		return false, "That 5v5 lobby is no longer available.", self:GetStatus(player)
	end
	if #lobby.Players >= lobby.TeamSize * 2 then return false, "That lobby is full.", self:GetStatus(player) end
	if lobby.OpenJoin ~= true and tostring(lobby.Password or "") ~= tostring(payload.Password or "") then
		return false, "Password required.", self:GetStatus(player)
	end
	self:_removeFromLobby(player)
	local entry = compactPlayer(player, self:_playBuilder(player))
	table.insert(lobby.Players, entry)
	self.PlayerLobby[player] = lobby.LobbyId
	self:_autoBalance(lobby)
	self:_writeLobby(lobby)
	return true, "Joined 5v5 lobby.", self:GetStatus(player)
end

function Service:RandomJoin(player: Player): (boolean, string, any?)
	local ok, _, data = self:ListLobbies(player, "")
	local lobbies = ok and data and data.Lobbies or {}
	for _, lobby in lobbies do
		if lobby.OpenJoin == true and tonumber(lobby.PlayerCount) < tonumber(lobby.RequiredPlayers) then
			return self:JoinLobby(player, lobby)
		end
	end
	return self:CreateLobby(player, {Name = playerName(player) .. "'s Lobby", TeamSize = 5, OpenJoin = true})
end

function Service:AssignLobbyPlayer(player: Player, payload: any?): (boolean, string, any?)
	local lobby = self:_currentLobby(player)
	if not lobby or lobby.HostUserId ~= player.UserId then return false, "Only the host can assign teams.", self:GetStatus(player) end
	payload = type(payload) == "table" and payload or {}
	local userId = tonumber(payload.UserId)
	if not userId then return false, "Choose a player to assign.", self:GetStatus(player) end
	local exists = false
	for _, entry in lobby.Players do if tonumber(entry.UserId) == userId then exists = true; break end end
	if not exists then return false, "Player is not in this lobby.", self:GetStatus(player) end
	self:_assignPlayer(lobby, userId, tostring(payload.Team or ""))
	self:_writeLobby(lobby)
	return true, "Team updated.", self:GetStatus(player)
end

function Service:KickLobbyPlayer(player: Player, payload: any?): (boolean, string, any?)
	local lobby = self:_currentLobby(player)
	if not lobby or lobby.HostUserId ~= player.UserId then return false, "Only the host can kick players.", self:GetStatus(player) end
	payload = type(payload) == "table" and payload or {}
	local userId = tonumber(payload.UserId)
	if not userId then return false, "Choose a player to kick.", self:GetStatus(player) end
	if userId == player.UserId then return false, "The host cannot kick themselves.", self:GetStatus(player) end
	local removed: any? = nil
	for index = #lobby.Players, 1, -1 do
		if tonumber(lobby.Players[index].UserId) == userId then
			removed = lobby.Players[index]
			table.remove(lobby.Players, index)
			break
		end
	end
	if not removed then return false, "Player is not in this lobby.", self:GetStatus(player) end
	lobby.Home[userId] = nil
	lobby.Home[tostring(userId)] = nil
	lobby.Away[userId] = nil
	lobby.Away[tostring(userId)] = nil
	local kicked = Players:GetPlayerByUserId(userId)
	if kicked then
		self.PlayerLobby[kicked] = nil
		self:_notify(kicked, "PLAY LOBBY", "You were kicked from the lobby.", "Error")
	end
	self:_autoBalance(lobby)
	self:_writeLobby(lobby)
	return true, "Player kicked from lobby.", self:GetStatus(player)
end

function Service:StartLobby(player: Player): (boolean, string, any?)
	local lobby = self:_currentLobby(player)
	if not lobby or lobby.HostUserId ~= player.UserId then return false, "Only the host can start this lobby.", self:GetStatus(player) end
	self:_autoBalance(lobby)
	local home, away = {}, {}
	for _, entry in lobby.Players do
		local online = Players:GetPlayerByUserId(tonumber(entry.UserId) or 0)
		if online and lobby.Home[online.UserId] then table.insert(home, {Player = online}) end
		if online and lobby.Away[online.UserId] then table.insert(away, {Player = online}) end
	end
	if #home ~= lobby.TeamSize or #away ~= lobby.TeamSize then
		return false, "Assign " .. tostring(lobby.TeamSize) .. " players to each team before starting.", self:GetStatus(player)
	end
	local entries = {}
	for _, entry in home do entry.Team = "Home"; table.insert(entries, entry) end
	for _, entry in away do entry.Team = "Away"; table.insert(entries, entry) end
	local ok, message, match = self:_teleportMatch(entries, lobby.TeamSize)
	if ok then
		for _, entry in lobby.Players do
			local online = Players:GetPlayerByUserId(tonumber(entry.UserId) or 0)
			if online then self.PlayerLobby[online] = nil end
		end
		self.Lobbies[lobby.LobbyId] = nil
		self:_removeLobbyListing(lobby.LobbyId)
	end
	return ok, message, match and {Status = "Matched", Match = match} or self:GetStatus(player)
end

function Service:Rejoin(player: Player): (boolean, string, any?)
	local match = self:_activeFor(player)
	if not match then return false, "No active 5v5 match to rejoin.", self:GetStatus(player) end
	if RunService:IsStudio() or not match.AccessCode then
		return false, "5v5 rejoin teleport is unavailable in Studio.", self:GetStatus(player)
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = tostring(match.AccessCode)
	options:SetTeleportData(match)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(tonumber(match.PlaceId) or game.PlaceId, {player}, options)
	end)
	return ok, ok and "Rejoining 5v5 match." or ("Rejoin failed: " .. tostring(err)), self:GetStatus(player)
end

function Service:GetStatus(player: Player): any
	local active = self:_activeFor(player)
	if active then return {Status = "Rejoin", Mode = "FiveVFive", Match = active, QueuedPlayers = self:_countQueued(), RequiredPlayers = MATCH_SIZE, QueuedPlayerNames = active.Players or {}} end
	local lobby = self:_currentLobby(player)
	if lobby then
		local summary = self:_lobbySummary(lobby)
		summary.Status = lobby.HostUserId == player.UserId and "Hosting" or "InLobby"
		summary.IsHost = lobby.HostUserId == player.UserId
		return summary
	end
	return {
		Status = self.ByPlayer[player] and "Searching" or "Idle",
		Mode = "FiveVFive",
		QueuedPlayers = self:_countQueued(),
		RequiredPlayers = MATCH_SIZE,
		QueuedPlayerNames = self:_queuedPlayers(),
	}
end

function Service:CancelActiveMatches(reason: string?): (boolean, string, any?)
	local cancelled = {}
	if self.Runtime and self.Runtime.CancelFiveVFiveMatches then
		cancelled = self.Runtime:CancelFiveVFiveMatches(reason or "DeveloperCancel")
	end
	for _, match in cancelled do
		self:_clearActivePlayers(match.Players or {})
	end
	for matchId, bucket in self.PendingTeleportMatches do
		if bucket and bucket.Data then
			self:_clearActive(bucket.Data)
		end
		self.PendingTeleportMatches[matchId] = nil
	end
	local count = #cancelled
	return true, count > 0 and ("Cancelled " .. tostring(count) .. " active 5v5 match" .. (count == 1 and "." or "es.")) or "No active 5v5 matches to cancel.", {Cancelled = cancelled, Count = count}
end

function Service:PlayerRemoving(player: Player)
	self:_remove(player)
	self:_removeFromLobby(player)
	self.Matches[player] = nil
end

function Service:_teleportData(player: Player): any?
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if type(teleportData) == "table" and (teleportData.MatchMode == "FiveVFive" or teleportData.MatchMode == "FiveVFiveLobbyJoin") then return teleportData end
	return nil
end

function Service:HandleTeleportedPlayer(player: Player): boolean
	local data = self:_teleportData(player)
	if not data then return false end
	if data.MatchMode == "FiveVFiveLobbyJoin" then
		task.defer(function()
			local ok, message = self:JoinLobby(player, data)
			self:_notify(player, "5V5 LOBBY", message, ok and "Reward" or "Error")
		end)
		return true
	end
	local matchId = tostring(data.MatchId or "")
	if matchId == "" then return false end
	if self.Runtime and self.Runtime.GetFiveVFiveSession and self.Runtime:GetFiveVFiveSession(matchId) then
		local ok, message = self.Runtime:RejoinFiveVFivePlayer(player, data)
		self:_notify(player, "5V5", message, ok and "Reward" or "Error")
		return ok
	end
	local bucket = self.PendingTeleportMatches[matchId]
	if not bucket then
		bucket = {Data = data, Players = {}, Started = false}
		self.PendingTeleportMatches[matchId] = bucket
	end
	bucket.Players[player.UserId] = player
	task.defer(function()
		self:_tryStartTeleportedMatch(matchId)
	end)
	return true
end

function Service:_tryStartTeleportedMatch(matchId: string)
	local bucket = self.PendingTeleportMatches[matchId]
	if not bucket or bucket.Started then return end
	local data = bucket.Data
	self:_refreshMatchPayloadBuilders(data)
	local required = validTeamSize(data.TeamSize) * 2
	local startedAt = os.clock()
	while os.clock() - startedAt < ARRIVAL_WAIT_SECONDS do
		local participants = {}
		for _, entry in data.Players or {} do
			local player = bucket.Players[tonumber(entry.UserId) or -1]
			if player and player.Parent == Players then table.insert(participants, player) end
		end
		if #participants >= required then
			local allCharactersReady = true
			for _, participant in participants do
				if not characterReady(participant) then
					allCharactersReady = false
					break
				end
			end
			if allCharactersReady then
				bucket.Started = true
				local ok, message = self.Runtime:StartFiveVFiveMatch(participants, data)
				if not ok then
					for _, player in participants do self:_notify(player, "5V5 MATCH FAILED", message, "Error") end
					self:_clearActive(data)
				end
				return
			end
		end
		task.wait(.5)
	end
	self.PendingTeleportMatches[matchId] = nil
	for _, player in bucket.Players do
		if player and player.Parent == Players then
			self:_notify(player, "5V5 MATCH", "Not everyone reached the match server. Sending you back.", "Error")
			if not RunService:IsStudio() then
				pcall(function() TeleportService:TeleportAsync(tonumber(data.ReturnPlaceId) or game.PlaceId, {player}) end)
			end
		end
	end
	self:_clearActive(data)
end

return Service
