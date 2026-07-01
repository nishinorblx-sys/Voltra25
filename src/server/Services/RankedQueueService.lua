--!strict
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Service = {}
Service.__index = Service

local QUEUE_MAP = "VTR25_GlobalRankedQueue_v1"
local MATCH_MAP = "VTR25_GlobalRankedMatches_v1"
local QUEUE_TTL = 150
local MATCH_TTL = 180
local POLL_SECONDS = 1.75

local WEATHER = { "Clear", "Cloudy", "Rain" }
local TIMES = { "Day", "Evening", "Night" }

function Service.new(profiles: any, runtime: any, rankedProfiles: any, notifications: any, rankedSquads: any, progression: any?)
	local self = setmetatable({
		Profiles = profiles,
		Runtime = runtime,
		RankedProfiles = rankedProfiles,
		Notifications = notifications,
		RankedSquads = rankedSquads,
		Progression = progression,
		Queue = {},
		QueuedAt = {},
		QueueSetup = {},
		QueueRoster = {},
		QueueDevice = {},
		GlobalQueued = {},
		GlobalTeleporting = {},
		PendingTeleportMatches = {},
		Random = Random.new(),
		GlobalEnabled = not RunService:IsStudio() and game.PlaceId ~= 0,
	}, Service)
	self:_startGlobalPoll()
	return self
end

function Service:BuildRankedSetup(player: Player, profile: any, roster: any): any
	local saved = profile.MatchSetup or {}
	return {
		MatchLength = 8,
		Difficulty = "World Class",
		MatchType = "Ranked",
		WatchMode = false,
		HomeTeamId = roster.Team.teamId,
		AwayTeamId = roster.Team.teamId,
		HomeKit = "Home",
		AwayKit = "Away",
		StadiumId = type(saved.StadiumId) == "string" and saved.StadiumId or "voltra_arena",
		Weather = WEATHER[self.Random:NextInteger(1, #WEATHER)],
		Time = TIMES[self.Random:NextInteger(1, #TIMES)],
		Completed = true,
		SavedAt = os.time(),
		KitConflict = false,
	}
end

function Service:_rankedSetup(player: Player, profile: any, roster: any): any
	return self:BuildRankedSetup(player, profile, roster)
end

function Service:_ticketKey(player: Player): string
	return tostring(player.UserId) .. ":" .. game.JobId
end

function Service:_matchKey(userId: number): string
	return "u:" .. tostring(userId)
end

function Service:_queueMap(): any?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(QUEUE_MAP)
	end)
	return ok and map or nil
end

function Service:_matchMap(): any?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(MATCH_MAP)
	end)
	return ok and map or nil
end

function Service:_removeGlobal(player: Player)
	self.GlobalQueued[player] = nil
	self.GlobalTeleporting[player] = nil
	player:SetAttribute("VTRRankedQueued", nil)
	local map = self:_queueMap()
	if map then
		pcall(function()
			map:RemoveAsync(self:_ticketKey(player))
		end)
	end
end

function Service:_remove(player: Player)
	local index = table.find(self.Queue, player)
	if index then table.remove(self.Queue, index) end
	self.QueuedAt[player] = nil
	self.QueueSetup[player] = nil
	self.QueueRoster[player] = nil
	self.QueueDevice[player] = nil
	player:SetAttribute("VTRRankedQueued", nil)
	if self.GlobalEnabled then self:_removeGlobal(player) end
end

function Service:_valid(player: Player): boolean
	return player.Parent == Players and self.Profiles:GetProfile(player) ~= nil and player:GetAttribute("VTRInMatch") ~= true
end

function Service:_compatibleTickets(home: any, away: any): boolean
	if not home or not away or home.UserId == away.UserId then return false end
	local homeCross = home.Crossplay ~= false
	local awayCross = away.Crossplay ~= false
	if homeCross and awayCross then return true end
	return tostring(home.DeviceType or "KeyboardMouse") == tostring(away.DeviceType or "KeyboardMouse")
end

function Service:_compatible(home: Player, away: Player): boolean
	local homeProfile = self.Profiles:GetProfile(home)
	local awayProfile = self.Profiles:GetProfile(away)
	local homeCross = not homeProfile or not homeProfile.UIState or not homeProfile.UIState.Settings or homeProfile.UIState.Settings.Crossplay ~= false
	local awayCross = not awayProfile or not awayProfile.UIState or not awayProfile.UIState.Settings or awayProfile.UIState.Settings.Crossplay ~= false
	if homeCross and awayCross then return true end
	return (self.QueueDevice[home] or "KeyboardMouse") == (self.QueueDevice[away] or "KeyboardMouse")
end

function Service:_nextPair(): (Player?, Player?)
	for firstIndex = 1, #self.Queue do
		local first = self.Queue[firstIndex]
		for secondIndex = firstIndex + 1, #self.Queue do
			local second = self.Queue[secondIndex]
			if self:_compatible(first, second) then
				table.remove(self.Queue, secondIndex)
				table.remove(self.Queue, firstIndex)
				return first, second
			end
		end
	end
	return nil, nil
end

function Service:_attachResultHandlers(session: any, home: Player, away: Player)
	session.OnRankedEnded = function(ended: any)
		local homeScore = ended.World.HomeScore.Value
		local awayScore = ended.World.AwayScore.Value
		local homeResult = homeScore > awayScore and "Win" or homeScore < awayScore and "Loss" or "Draw"
		local awayResult = homeResult == "Win" and "Loss" or homeResult == "Loss" and "Win" or "Draw"
		local homeRP = homeResult == "Win" and 35 or homeResult == "Draw" and 12 or -20
		local awayRP = awayResult == "Win" and 35 or awayResult == "Draw" and 12 or -20
		local score = tostring(homeScore) .. "-" .. tostring(awayScore)
		local serialized = ended.Stats:Serialize(homeScore, awayScore, ended.Clock:Payload().GameSeconds)
		local function updateObjectives(target: Player, side: string)
			local team = side == "Home" and serialized.Home or serialized.Away
			if self.Progression then self.Progression:UpdateObjectivesFromMatch(target, team) end
		end
		updateObjectives(home, "Home")
		updateObjectives(away, "Away")
		local function personal(side: string): any
			local best = nil
			for _, entry in serialized.PlayerRatings or {} do
				if entry.Team == side and (not best or entry.Rating > best.Rating) then best = entry end
			end
			return {
				PlayerRating = best and best.Rating or 6,
				Team = side,
				Match = side == "Home" and serialized.Home or serialized.Away,
				Full = serialized,
				MOTM = serialized.MOTM,
			}
		end
		self.RankedProfiles:RecordServerResult(home, homeResult, homeRP, away.Name, score, personal("Home"))
		self.RankedProfiles:RecordServerResult(away, awayResult, awayRP, home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), personal("Away"))
	end
	session.OnBeforeResult = function(ended: any)
		local rewards = {}
		local homeWon = ended.World.HomeScore.Value > ended.World.AwayScore.Value
		local awayWon = ended.World.AwayScore.Value > ended.World.HomeScore.Value
		local draw = ended.World.HomeScore.Value == ended.World.AwayScore.Value
		for participant, won in { [home] = homeWon, [away] = awayWon } do
			local coins = 900 + (won and 900 or draw and 450 or 225)
			local xp = 140 + (won and 110 or draw and 55 or 25)
			if self.Progression then
				local reward = self.Progression:GrantMatchRewards(participant, {
					Title = won and "RANKED VICTORY" or draw and "RANKED DRAW" or "RANKED MATCH",
					Coins = coins,
					XP = xp,
				})
				if reward then rewards[participant.UserId] = reward end
			end
		end
		return rewards
	end
end

function Service:_pair()
	while #self.Queue >= 2 do
		local home, away = self:_nextPair()
		if not home or not away then break end
		self.QueuedAt[home] = nil
		self.QueuedAt[away] = nil
		home:SetAttribute("VTRRankedQueued", nil)
		away:SetAttribute("VTRRankedQueued", nil)
		if not self:_valid(home) or not self:_valid(away) then
			if self:_valid(home) then table.insert(self.Queue, home) end
			if self:_valid(away) then table.insert(self.Queue, away) end
			continue
		end
		local homeProfile = self.Profiles:GetProfile(home)
		local awayProfile = self.Profiles:GetProfile(away)
		local homeRoster = self.QueueRoster[home]
		local awayRoster = self.QueueRoster[away]
		local homeSetup = self.QueueSetup[home] or (homeProfile and homeRoster and self:_rankedSetup(home, homeProfile, homeRoster))
		local awaySetup = self.QueueSetup[away] or (awayProfile and awayRoster and self:_rankedSetup(away, awayProfile, awayRoster))
		self.QueueSetup[home] = nil
		self.QueueSetup[away] = nil
		self.QueueRoster[home] = nil
		self.QueueRoster[away] = nil
		self.QueueDevice[home] = nil
		self.QueueDevice[away] = nil
		if not homeSetup or not awaySetup or not homeRoster or not awayRoster then
			self.Notifications:Send(home, "RANKED QUEUE", "Ultimate Team lineup unavailable.", "Error")
			self.Notifications:Send(away, "RANKED QUEUE", "Ultimate Team lineup unavailable.", "Error")
			continue
		end
		self.Notifications:Send(home, "OPPONENT FOUND", away.Name .. " is ready. Starting local test match.", "Info")
		self.Notifications:Send(away, "OPPONENT FOUND", home.Name .. " is ready. Starting local test match.", "Info")
		task.defer(function()
			local success, message = self.Runtime:StartRankedMatch(home, away, homeSetup, awaySetup, homeRoster, awayRoster)
			if not success then
				self.Notifications:Send(home, "MATCH FAILED", message, "Error")
				self.Notifications:Send(away, "MATCH FAILED", message, "Error")
				return
			end
			self.RankedSquads:ConsumeLoans(home)
			self.RankedSquads:ConsumeLoans(away)
			local session = self.Runtime:GetSession(home)
			if session then self:_attachResultHandlers(session, home, away) end
		end)
	end
end

function Service:_ticketFor(player: Player, profile: any, roster: any, device: string): any
	local crossplay = not profile.UIState or not profile.UIState.Settings or profile.UIState.Settings.Crossplay ~= false
	return {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		JobId = game.JobId,
		PlaceId = game.PlaceId,
		DeviceType = device,
		Crossplay = crossplay,
		CreatedAt = os.time(),
		TeamName = roster.Team.teamName,
		TeamLogo = roster.Team.logo,
		TeamOverall = roster.Team.overall,
	}
end

function Service:_writeGlobalTicket(player: Player, ticket: any): boolean
	local map = self:_queueMap()
	if not map then return false end
	local ok = pcall(function()
		map:SetAsync(self:_ticketKey(player), ticket, QUEUE_TTL, os.time())
	end)
	return ok
end

function Service:_makeAssignment(matchId: string, accessCode: string, privateServerId: string, homeTicket: any, awayTicket: any, role: string): any
	return {
		MatchMode = "Ranked1v1",
		MatchId = matchId,
		AccessCode = accessCode,
		PrivateServerId = privateServerId,
		PlaceId = game.PlaceId,
		ReturnPlaceId = game.PlaceId,
		HomeUserId = homeTicket.UserId,
		AwayUserId = awayTicket.UserId,
		HomeName = homeTicket.Name,
		AwayName = awayTicket.Name,
		HomeTeamName = homeTicket.TeamName,
		AwayTeamName = awayTicket.TeamName,
		HomeOverall = homeTicket.TeamOverall,
		AwayOverall = awayTicket.TeamOverall,
		Role = role,
		CreatedAt = os.time(),
	}
end

function Service:_publishGlobalMatch(homeTicket: any, awayTicket: any): (boolean, string)
	local matchMap = self:_matchMap()
	local queueMap = self:_queueMap()
	if not matchMap or not queueMap then return false, "Global matchmaking is unavailable." end
	local okReserve, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not okReserve or type(accessCode) ~= "string" then
		return false, "Could not reserve match server."
	end
	local matchId = HttpService:GenerateGUID(false)
	local homeAssignment = self:_makeAssignment(matchId, accessCode, tostring(privateServerId or ""), homeTicket, awayTicket, "Home")
	local awayAssignment = self:_makeAssignment(matchId, accessCode, tostring(privateServerId or ""), homeTicket, awayTicket, "Away")
	local okSet = pcall(function()
		matchMap:SetAsync(self:_matchKey(homeTicket.UserId), homeAssignment, MATCH_TTL, os.time())
		matchMap:SetAsync(self:_matchKey(awayTicket.UserId), awayAssignment, MATCH_TTL, os.time())
		queueMap:RemoveAsync(tostring(homeTicket.UserId) .. ":" .. tostring(homeTicket.JobId))
		queueMap:RemoveAsync(tostring(awayTicket.UserId) .. ":" .. tostring(awayTicket.JobId))
	end)
	if not okSet then return false, "Could not publish match assignment." end
	return true, matchId
end

function Service:_teleportToAssignment(player: Player, assignment: any)
	if self.GlobalTeleporting[player] then return end
	self.GlobalTeleporting[player] = true
	self.GlobalQueued[player] = nil
	self.QueuedAt[player] = nil
	player:SetAttribute("VTRRankedQueued", nil)
	self.Notifications:Send(player, "OPPONENT FOUND", "Reserved 1v1 match server ready.", "Info")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = assignment.AccessCode
	options:SetTeleportData(assignment)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(tonumber(assignment.PlaceId) or game.PlaceId, { player }, options)
	end)
	if not ok then
		self.GlobalTeleporting[player] = nil
		self.Notifications:Send(player, "MATCH TELEPORT FAILED", tostring(err), "Error")
	end
end

function Service:_checkAssignment(player: Player): boolean
	local matchMap = self:_matchMap()
	if not matchMap then return false end
	local ok, assignment = pcall(function()
		return matchMap:GetAsync(self:_matchKey(player.UserId))
	end)
	if ok and type(assignment) == "table" and assignment.MatchMode == "Ranked1v1" and type(assignment.AccessCode) == "string" then
		self:_teleportToAssignment(player, assignment)
		return true
	end
	return false
end

function Service:_tryPairGlobal()
	local queueMap = self:_queueMap()
	if not queueMap then return end
	local ok, entries = pcall(function()
		return queueMap:GetRangeAsync(Enum.SortDirection.Ascending, 24)
	end)
	if not ok or type(entries) ~= "table" or #entries < 2 then return end
	local localTicketsByUser: { [number]: any } = {}
	for player, ticket in self.GlobalQueued do
		if player.Parent == Players and not self.GlobalTeleporting[player] then
			localTicketsByUser[player.UserId] = ticket
		end
	end
	for _, homeEntry in entries do
		local homeTicket = homeEntry.value
		if type(homeTicket) == "table" and localTicketsByUser[tonumber(homeTicket.UserId) or -1] then
			for _, awayEntry in entries do
				local awayTicket = awayEntry.value
				if type(awayTicket) == "table" and homeTicket.UserId ~= awayTicket.UserId and self:_compatibleTickets(homeTicket, awayTicket) then
					local success = self:_publishGlobalMatch(homeTicket, awayTicket)
					if success then return end
				end
			end
		end
	end
end

function Service:_startGlobalPoll()
	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			if self.GlobalEnabled then
				for player in self.GlobalQueued do
					if player.Parent ~= Players or player:GetAttribute("VTRInMatch") == true then
						self:_removeGlobal(player)
					else
						self:_checkAssignment(player)
					end
				end
				self:_tryPairGlobal()
			end
		end
	end)
end

function Service:_joinGlobal(player: Player, profile: any, roster: any, device: string): (boolean, string, any?)
	if self.GlobalQueued[player] then
		return true, "Already searching for a global ranked opponent.", { Status = "Searching", Position = 1, Global = true }
	end
	local ticket = self:_ticketFor(player, profile, roster, device)
	if not self:_writeGlobalTicket(player, ticket) then
		return false, "Global queue is unavailable right now.", nil
	end
	self.GlobalQueued[player] = ticket
	self.QueuedAt[player] = os.clock()
	player:SetAttribute("VTRRankedQueued", true)
	self.Notifications:Send(player, "RANKED QUEUE", roster.Team.teamName .. " / OVR " .. roster.Team.overall .. " / Searching global queue.", "Info")
	self:_checkAssignment(player)
	self:_tryPairGlobal()
	return true, "Searching global ranked queue.", { Status = "Searching", Position = 1, Global = true }
end

function Service:Join(player: Player, payload: any?): (boolean, string, any?)
	if player:GetAttribute("VTRInMatch") == true then return false, "You are already in a match.", nil end
	if self.QueuedAt[player] then return true, "Already searching for an opponent.", { Status = "Searching", Position = table.find(self.Queue, player) or 1, Global = self.GlobalQueued[player] ~= nil } end
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local squadReady, squadMessage, roster = self.RankedSquads:GetRoster(player)
	if not squadReady or not roster then return false, squadMessage, nil end
	local device = type(payload) == "table" and tostring(payload.DeviceType or "") or ""
	if device ~= "Touch" and device ~= "Gamepad" and device ~= "KeyboardMouse" then device = "KeyboardMouse" end
	if self.GlobalEnabled then
		local ok, message, data = self:_joinGlobal(player, profile, roster, device)
		if ok then return ok, message, data end
		warn("[VTR RANKED QUEUE] Global queue fallback: " .. tostring(message))
	end
	self.QueueDevice[player] = device
	self.QueueRoster[player] = roster
	self.QueueSetup[player] = self:_rankedSetup(player, profile, roster)
	table.insert(self.Queue, player)
	self.QueuedAt[player] = os.clock()
	player:SetAttribute("VTRRankedQueued", true)
	self.Notifications:Send(player, "RANKED QUEUE", roster.Team.teamName .. " / OVR " .. roster.Team.overall .. " / Searching local fallback queue.", "Info")
	self:_pair()
	return true, #self.Queue == 0 and "Opponent found. Match starting." or "Searching for a ranked opponent.", { Status = #self.Queue == 0 and "Matched" or "Searching", Position = table.find(self.Queue, player) or 0, Global = false }
end

function Service:Leave(player: Player): (boolean, string, any?)
	if not self.QueuedAt[player] and not self.GlobalQueued[player] then return false, "You are not currently queued.", nil end
	self:_remove(player)
	return true, "Ranked search cancelled.", { Status = "Idle" }
end

function Service:GetStatus(player: Player): any
	return {
		Status = (self.QueuedAt[player] or self.GlobalQueued[player]) and "Searching" or player:GetAttribute("VTRInMatch") and "InMatch" or "Idle",
		Position = table.find(self.Queue, player) or 0,
		QueuedPlayers = #self.Queue,
		Global = self.GlobalQueued[player] ~= nil,
	}
end

function Service:PlayerRemoving(player: Player)
	self:_remove(player)
end

function Service:HandleTeleportedPlayer(player: Player): boolean
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if type(teleportData) ~= "table" or teleportData.MatchMode ~= "Ranked1v1" then return false end
	player:SetAttribute("VTRReservedRankedBoot", true)
	player:SetAttribute("VTRRankedMatchId", tostring(teleportData.MatchId or ""))
	local matchId = tostring(teleportData.MatchId or "")
	local bucket = self.PendingTeleportMatches[matchId]
	if not bucket then
		bucket = { Data = teleportData, Players = {}, Started = false }
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
	local home = bucket.Players[tonumber(data.HomeUserId) or -1]
	local away = bucket.Players[tonumber(data.AwayUserId) or -2]
	local startedAt = os.clock()
	while os.clock() - startedAt < 45 do
		if home and away and home.Parent == Players and away.Parent == Players then
			local homeProfile = self.Profiles:GetProfile(home)
			local awayProfile = self.Profiles:GetProfile(away)
			local homeCharacterReady = home.Character and home.Character:FindFirstChildOfClass("Humanoid")
			local awayCharacterReady = away.Character and away.Character:FindFirstChildOfClass("Humanoid")
			if homeProfile and awayProfile and homeCharacterReady and awayCharacterReady then
				local homeReady, homeMessage, homeRoster = self.RankedSquads:GetRoster(home)
				local awayReady, awayMessage, awayRoster = self.RankedSquads:GetRoster(away)
				if not homeReady or not homeRoster then
					self.Notifications:Send(home, "MATCH FAILED", homeMessage or "Home lineup unavailable.", "Error")
					return
				end
				if not awayReady or not awayRoster then
					self.Notifications:Send(away, "MATCH FAILED", awayMessage or "Away lineup unavailable.", "Error")
					return
				end
				bucket.Started = true
				local homeSetup = self:BuildRankedSetup(home, homeProfile, homeRoster)
				local awaySetup = self:BuildRankedSetup(away, awayProfile, awayRoster)
				local success, message = self.Runtime:StartRankedMatch(home, away, homeSetup, awaySetup, homeRoster, awayRoster)
				if not success then
					self.Notifications:Send(home, "MATCH FAILED", message, "Error")
					self.Notifications:Send(away, "MATCH FAILED", message, "Error")
					return
				end
				self.RankedSquads:ConsumeLoans(home)
				self.RankedSquads:ConsumeLoans(away)
				local session = self.Runtime:GetSession(home)
				if session then
					session.PrivateRankedMatch = true
					session.ReturnPlaceId = tonumber(data.ReturnPlaceId) or game.PlaceId
					session.MatchId = matchId
					self:_attachResultHandlers(session, home, away)
				end
				return
			end
		end
		task.wait(0.5)
		home = bucket.Players[tonumber(data.HomeUserId) or -1]
		away = bucket.Players[tonumber(data.AwayUserId) or -2]
	end
	if home and home.Parent == Players then self.Notifications:Send(home, "MATCH FAILED", "Opponent did not reach the reserved server.", "Error") end
	if away and away.Parent == Players then self.Notifications:Send(away, "MATCH FAILED", "Opponent did not reach the reserved server.", "Error") end
end

return Service
