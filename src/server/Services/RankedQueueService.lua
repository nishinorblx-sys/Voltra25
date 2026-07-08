--!strict
local function vtrLoadWorldCampaignWinProgress()
	VTRWorldCampaignWinProgress.TryRegisterFromArgs(nil)
	local current = script
	while current do
		local services = current:FindFirstChild("Services")
		if services and services:FindFirstChild("WorldCampaignWinProgressService") then
			VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)
			return require(services:WaitForChild("WorldCampaignWinProgressService"))
		end

		if current.Parent then
			local sibling = current.Parent:FindFirstChild("Services")
			if sibling and sibling:FindFirstChild("WorldCampaignWinProgressService") then
				VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)
				return require(sibling:WaitForChild("WorldCampaignWinProgressService"))
			end
		end

		current = current.Parent
	end

	return require(game:GetService("ServerScriptService"):WaitForChild("VTRServer"):WaitForChild("Services"):WaitForChild("WorldCampaignWinProgressService"))
end

local VTRWorldCampaignWinProgress = vtrLoadWorldCampaignWinProgress()
local function vtrLoadPackInventoryConsume()
	local current = script
	while current do
		local services = current:FindFirstChild("Services")
		if services and services:FindFirstChild("PackInventoryConsumeService") then
			return require(services:WaitForChild("PackInventoryConsumeService"))
		end

		if current.Parent then
			local sibling = current.Parent:FindFirstChild("Services")
			if sibling and sibling:FindFirstChild("PackInventoryConsumeService") then
				return require(sibling:WaitForChild("PackInventoryConsumeService"))
			end
		end

		current = current.Parent
	end

	return require(game:GetService("ServerScriptService"):WaitForChild("VTRServer"):WaitForChild("Services"):WaitForChild("PackInventoryConsumeService"))
end

local VTRPackInventoryConsume = vtrLoadPackInventoryConsume()
local RankedWinPackReward=require(script.Parent.RankedWinPackReward)
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Service = {}
Service.__index = Service

local QUEUE_MAP = "VTR25_GlobalRankedQueue_v2"
local MATCH_MAP = "VTR25_GlobalRankedMatches_v2"
local RESULT_MAP = "VTR25_GlobalRankedResults_v2"
local QUEUE_TTL = 150
local MATCH_TTL = 180
local MATCH_ASSIGNMENT_ACCEPT_SECONDS = 75
local POLL_SECONDS = 1.75

local WEATHER = { "Clear", "Cloudy", "Rain" }
local TIMES = { "Day", "Evening", "Night" }
local TEAM_STAT_KEYS = {"Possession","Shots","ShotsOnTarget","ShotsOffTarget","BlockedShots","ExpectedGoals","PassesAttempted","PassesCompleted","PassAccuracy","KeyPasses","BigChanceCreated","BigChancesCreated","Crosses","CompletedCrosses","DribblesCompleted","DribbleAccuracy","TacklesAttempted","TacklesCompleted","Interceptions","Clearances","Errors","Saves","Corners","Fouls","Offsides","YellowCards","RedCards","Goals"}

local function pick(source:any,keys:{string}):any
	local result={}
	if type(source)~="table"then return result end
	for _,key in keys do
		local value=source[key]
		if type(value)=="number"or type(value)=="string"or type(value)=="boolean"then
			result[key]=value
		end
	end
	return result
end

local function compactGoals(goals:any):any
	local result={}
	if type(goals)~="table"then return result end
	for index,goal in goals do
		if index>24 then break end
		table.insert(result,{Team=goal.Team,Scorer=goal.Scorer,Assist=goal.Assist,GameSeconds=goal.GameSeconds,OwnGoal=goal.OwnGoal})
	end
	return result
end

local function compactRatings(ratings:any):any
	local result={}
	if type(ratings)~="table"then return result end
	for index,entry in ratings do
		if index>32 then break end
		table.insert(result,{Team=entry.Team,Name=entry.Name,Position=entry.Position,Rating=entry.Rating,Goals=entry.Goals,Assists=entry.Assists,Events=pick(entry.Events or{},{"Goal","Assist","ShotOnTarget","KeyPass","BigChanceCreated","SuccessfulPass","BadPass"})})
	end
	return result
end

local function compactMotm(motm:any):any
	if type(motm)~="table"then return nil end
	return{Team=motm.Team,Name=motm.Name,Position=motm.Position,Rating=motm.Rating,Goals=motm.Goals,Assists=motm.Assists}
end

local function compactMatchStats(stats:any):any
	if type(stats)~="table"then return{}end
	local full=type(stats.Full)=="table"and stats.Full or{}
	return{
		ResultId=stats.ResultId,
		PlayerRating=stats.PlayerRating,
		Team=stats.Team,
		Match=pick(stats.Match or{},TEAM_STAT_KEYS),
		MOTM=compactMotm(stats.MOTM or full.MOTM),
		Full={
			HomeScore=full.HomeScore,
			AwayScore=full.AwayScore,
			Home=pick(full.Home or{},TEAM_STAT_KEYS),
			Away=pick(full.Away or{},TEAM_STAT_KEYS),
			Goals=compactGoals(full.Goals),
			PlayerRatings=compactRatings(full.PlayerRatings),
			MOTM=compactMotm(full.MOTM),
		},
	}
end

local function compactReward(reward:any):any
	if type(reward)~="table"then return nil end
	return pick(reward,{"Title","Coins","XP","PackGranted","PackId","PackInstanceId","PackName","Pack","Rarity"})
end

local function compactPendingResult(payload:any,includeStats:boolean):any
	return{
		MatchId=tostring(payload.MatchId or ""),
		ResultId=tostring(payload.ResultId or payload.MatchId or ""),
		Result=tostring(payload.Result or ""),
		Opponent=tostring(payload.Opponent or "Opponent"),
		OpponentTag=tostring(payload.OpponentTag or ""),
		OpponentTeamName=tostring(payload.OpponentTeamName or ""),
		Score=tostring(payload.Score or "0-0"),
		MatchStats=includeStats~=false and compactMatchStats(payload.MatchStats) or nil,
		Reward=compactReward(payload.Reward),
		PackId=payload.PackId,
		PackInstanceId=payload.PackInstanceId,
		AppliedInMatchServer=payload.AppliedInMatchServer==true,
	}
end

function Service:_teamTag(player: Player): string
	local profile=self.Profiles:GetProfile(player)
	local club=profile and profile.ClubMembership or nil
	local tag=club and tostring(club.Abbreviation or "") or ""
	if #tag>=2 then return string.upper(string.sub(tag,1,4)) end
	local name=club and tostring(club.Name or "") or player.DisplayName
	tag=string.upper(string.sub((name:gsub("[^%a]","")),1,4))
	return tag~="" and tag or "VTR"
end

function Service:_teamName(player: Player): string
	local profile=self.Profiles:GetProfile(player)
	local club=profile and profile.ClubMembership or nil
	local name=club and tostring(club.Name or "") or ""
	return name~="" and name or player.DisplayName
end

function Service:_summaryForRoster(roster: any): any
	local team=roster and roster.Team or{}
	local function normalizePosition(value:any):string
		local text=string.upper(tostring(value or ""))
		local aliases={["LEFT WING"]="LW",["RIGHT WING"]="RW",["STRIKER"]="ST",["CENTRE FORWARD"]="CF",["CENTER FORWARD"]="CF",["LEFT MIDFIELD"]="LM",["RIGHT MIDFIELD"]="RM",["CENTRE MIDFIELD"]="CM",["CENTER MIDFIELD"]="CM",["DEFENSIVE MIDFIELD"]="CDM",["ATTACKING MIDFIELD"]="CAM",["LEFT BACK"]="LB",["RIGHT BACK"]="RB",["CENTRE BACK"]="CB",["CENTER BACK"]="CB",["GOALKEEPER"]="GK"}
		return aliases[text] or text
	end
	local function rosterAverage(group:any?):number
		local total,count=0,0
		for _,player in roster and roster.StartingXI or{}do
			local position=normalizePosition(player.PositionSlot or player.SquadSlot or player.ExpectedPosition or player.bestPosition or player.Position)
			if not group or group[position]==true then total+=tonumber(player.overall or player.Rating)or 0;count+=1 end
		end
		return count>0 and math.floor(total/count+.5)or 0
	end
	local attack=tonumber(team.attack or team.Attack)or rosterAverage({LW=true,RW=true,ST=true,CF=true,LM=true,RM=true})
	local midfield=tonumber(team.midfield or team.Midfield)or rosterAverage({CM=true,CDM=true,CAM=true,LM=true,RM=true})
	local defense=tonumber(team.defense or team.Defense)or rosterAverage({GK=true,LB=true,RB=true,CB=true,LWB=true,RWB=true})
	local overall=tonumber(team.overall or team.Overall)or rosterAverage(nil)
	if attack<=0 then attack=rosterAverage({LW=true,RW=true,ST=true,CF=true,LM=true,RM=true})end
	if midfield<=0 then midfield=rosterAverage({CM=true,CDM=true,CAM=true,LM=true,RM=true})end
	if defense<=0 then defense=rosterAverage({GK=true,LB=true,RB=true,CB=true,LWB=true,RWB=true})end
	if overall<=0 then overall=rosterAverage(nil)end
	return {
		teamName=team.teamName or team.Name or "VOLTRA FC",
		logo=team.logo or team.Logo,
		country=team.country or team.Country or "VTR",
		league=team.league or team.League or "RANKED",
		overall=overall,
		attack=attack,
		midfield=midfield,
		defense=defense,
		BadgeIdentity=team.BadgeIdentity or team.badgeIdentity,
		colors=team.colors or team.Colors,
		kits=team.kits or team.Kits,
		HomeKitData=team.kits and team.kits.Home or team.Kits and team.Kits.Home,
		AwayKitData=team.kits and team.kits.Away or team.Kits and team.Kits.Away,
	}
end

function Service:_matchFoundPayload(player: Player, opponent: Player, controlledSide: string, homeRoster: any, awayRoster: any, matchId: string?): any
	return {
		Opponent=opponent.Name,
		ControlledSide=controlledSide,
		Home=homeRoster and homeRoster.Team and homeRoster.Team.teamName or "HOME",
		Away=awayRoster and awayRoster.Team and awayRoster.Team.teamName or "AWAY",
		HomeSummary=self:_summaryForRoster(homeRoster),
		AwaySummary=self:_summaryForRoster(awayRoster),
		MatchId=matchId,
		Status="Matched",
	}
end

local function rankedFoundRemote(): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local remote = folder:FindFirstChild("RankedMatchFound")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "RankedMatchFound"
		remote.Parent = folder
	end
	return remote :: RemoteEvent
end

function Service.new(profiles: any, runtime: any, rankedProfiles: any, notifications: any, rankedSquads: any, progression: any?, publish: ((Player, string, any) -> ())?)
	local self = setmetatable({
		Profiles = profiles,
		Runtime = runtime,
		RankedProfiles = rankedProfiles,
		Notifications = notifications,
		RankedSquads = rankedSquads,
		Progression = progression,
		Publish = publish,
		Queue = {},
		QueuedAt = {},
		QueueSetup = {},
		QueueRoster = {},
		QueueDevice = {},
		GlobalQueued = {},
		GlobalTeleporting = {},
		PendingTeleportMatches = {},
		LastMatchFound = {},
		Random = Random.new(),
		GlobalEnabled = not RunService:IsStudio() and game.PlaceId ~= 0,
	}, Service)
	self:_startGlobalPoll()
	self:_startRankedTeleportWatcher()
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

function Service:_clearMatchAssignmentForUserId(userId: any)
	local id = tonumber(userId)
	if not id then return end
	local map = self:_matchMap()
	if not map then return end
	pcall(function()
		map:RemoveAsync(self:_matchKey(id))
	end)
end

function Service:_clearMatchAssignment(assignment: any?)
	if type(assignment) ~= "table" then return end
	self:_clearMatchAssignmentForUserId(assignment.HomeUserId)
	self:_clearMatchAssignmentForUserId(assignment.AwayUserId)
end

function Service:_clearMatchAssignmentsFor(matchId: any, home: Player?, away: Player?)
	if home then self:_clearMatchAssignmentForUserId(home.UserId) end
	if away then self:_clearMatchAssignmentForUserId(away.UserId) end
	if tostring(matchId or "") ~= "" then
		self.PendingTeleportMatches[tostring(matchId)] = nil
	end
end

function Service:_assignmentExpired(assignment: any): boolean
	local created = tonumber(assignment and assignment.CreatedAt) or 0
	return created > 0 and os.time() - created > MATCH_ASSIGNMENT_ACCEPT_SECONDS
end

function Service:_resultMap(): any?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(RESULT_MAP)
	end)
	return ok and map or nil
end

function Service:_resultKey(player: Player): string
	return "ranked-result:" .. tostring(player.UserId)
end

function Service:_publishMenuData(player: Player)
	if self.Publish and self.RankedProfiles and self.RankedProfiles.GetClientData then
		pcall(function()
			self.Publish(player, "Ranked", self.RankedProfiles:GetClientData(player))
		end)
	end
	if self.Publish and self.Progression then
		if self.Progression.GetClientData then
			pcall(function()
				self.Publish(player, "Progression", self.Progression:GetClientData(player))
			end)
		end
		if self.Progression.Inventory and self.Progression.Inventory.GetClientData then
			pcall(function()
				self.Publish(player, "Inventory", self.Progression.Inventory:GetClientData(player))
			end)
		end
	end
end

function Service:_savePlayer(player: Player)
	if not self.Profiles or not self.Profiles.Store or not self.Profiles.Store.SaveAsync then return end
	pcall(function()
		self.Profiles.Store:SaveAsync(player.UserId)
	end)
end

function Service:_savePlayers(players: { Player })
	for _, player in players do
		if player and player.Parent == Players then
			self:_savePlayer(player)
		end
	end
end

local function hasPackInstance(profile: any, packInstanceId: string): boolean
	if packInstanceId == "" then return false end
	for _, pack in profile.PackInventory or {} do
		if tostring(pack.packInstanceId or pack.PackInstanceId or "") == packInstanceId then return true end
	end
	return false
end

function Service:_grantSpecificRankedPack(player: Player, packId: string?): boolean
	local id = tostring(packId or "bronze_pack")
	local granted = false
	if self.Progression and self.Progression.Inventory and self.Progression.Inventory.AddPack then
		local ok, result = pcall(function()
			local addResult = self.Progression.Inventory:AddPack(player, id, id, "RankedWin", 1)
			if addResult ~= nil and addResult ~= false and player and typeof(player) == "Instance" and player:IsA("Player") then
				VTRPendingPackAnimation.Queue(player, id)
			end
			return addResult
		end)
		granted = ok and result ~= nil and result ~= false
	end
	if not granted then
		local reward = RankedWinPackReward.Grant(self.Progression, player, self.Publish)
		granted = type(reward) == "table" and reward.PackGranted == true
	end
	self:_publishMenuData(player)
	if granted then self:_savePlayer(player) end
	return granted
end

function Service:_writePendingRankedResult(player: Player, payload: any)
	local map = self:_resultMap()
	if not map then return end
	local compact=compactPendingResult(payload,true)
	local ok=pcall(function()
		map:SetAsync(self:_resultKey(player), compact, 900, os.time())
	end)
	if not ok then
		pcall(function()
			map:SetAsync(self:_resultKey(player), compactPendingResult(payload,false), 900, os.time())
		end)
	end
end

function Service:_consumePendingRankedResult(player: Player)
	local map = self:_resultMap()
	if not map then return end
	local ok, payload = pcall(function()
		return map:GetAsync(self:_resultKey(player))
	end)
	if not ok or type(payload) ~= "table" then return end
	local profile = self.Profiles:GetProfile(player)
	if not profile then return end
	local result = tostring(payload.Result or "")
	local opponent = tostring(payload.Opponent or "Opponent")
	local opponentTag = tostring(payload.OpponentTag or "")
	local opponentTeamName = tostring(payload.OpponentTeamName or "")
	local score = tostring(payload.Score or "0-0")
	local resultId = tostring(payload.ResultId or payload.MatchId or "")
	local matchStats = type(payload.MatchStats) == "table" and payload.MatchStats or {}
	matchStats.ResultId = resultId
	local applied = self.RankedProfiles:RecordServerResult(player, result, 0, opponent, score, matchStats, opponentTag, opponentTeamName)
	local reward = type(payload.Reward) == "table" and payload.Reward or nil
	if reward then
		matchStats.Reward = reward
	end
	if applied and reward and self.Progression then
		self.Progression:GrantMatchRewards(player, {
			Title = reward.Title or (result == "Win" and "RANKED VICTORY" or result == "Draw" and "RANKED DRAW" or "RANKED MATCH"),
			Coins = tonumber(reward.Coins) or 0,
			XP = tonumber(reward.XP) or 0,
		})
	end
	if result == "Win" or result == "ForfeitWin" then
		local packId = tostring(payload.PackId or "")
		local packInstanceId = tostring(payload.PackInstanceId or "")
		local matchServerAlreadyPersisted = payload.AppliedInMatchServer == true and (packInstanceId == "" or hasPackInstance(profile, packInstanceId))
		if packId ~= "" and (applied or not matchServerAlreadyPersisted) then
			self:_grantSpecificRankedPack(player, packId)
		end
	end
	if reward and resultId ~= "" and self.RankedProfiles.AttachHistoryReward then
		self.RankedProfiles:AttachHistoryReward(player,resultId,reward)
	end
	self:_publishMenuData(player)
	if applied then self:_savePlayer(player) end
	pcall(function()
		map:RemoveAsync(self:_resultKey(player))
	end)
end

function Service:_removeGlobal(player: Player)
	self.GlobalQueued[player] = nil
	self.GlobalTeleporting[player] = nil
	if self.LastMatchFound then self.LastMatchFound[player]=nil end
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
	if self.LastMatchFound then self.LastMatchFound[player]=nil end
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
	VTRWorldCampaignWinProgress.TryRegisterFromArgs(self)
	session.RankedWinRewards=session.RankedWinRewards or{}
	session.RankedWinPackGrant=function(_,winner:Player)
		session.RankedWinRewards=session.RankedWinRewards or{}
		local existing=session.RankedWinRewards[winner.UserId]
		if existing then return existing end
		local reward=RankedWinPackReward.Grant(self.Progression,winner,self.Publish)
		session.RankedWinRewards[winner.UserId]=reward
		return reward
	end
	local function resultFor(player: Player, side: string, homeScore: number, awayScore: number): string
		if session.RankedForceLossUserId==player.UserId or session.ForfeitBy==player.UserId then
			return "ForfeitLoss"
		elseif session.ForfeitBy then
			return "ForfeitWin"
		end
		if homeScore==awayScore then return "Draw" end
		local won=(side=="Home" and homeScore>awayScore)or(side=="Away" and awayScore>homeScore)
		return won and "Win" or "Loss"
	end
	local function rpFor(result: string): number
		if result=="Win" or result=="ForfeitWin" then return 35 end
		if result=="Draw" then return 12 end
		return -20
	end
	session.OnRankedEnded = function(ended: any)
		local homeScore = ended.World.HomeScore.Value
		local awayScore = ended.World.AwayScore.Value
		local homeResult = resultFor(home,"Home",homeScore,awayScore)
		local awayResult = resultFor(away,"Away",homeScore,awayScore)
		local score = tostring(homeScore) .. "-" .. tostring(awayScore)
		local serialized = ended.Stats:Serialize(homeScore, awayScore, ended.Clock:Payload().GameSeconds)
		local function updateObjectives(target: Player, side: string)
			local team = side == "Home" and serialized.Home or serialized.Away
			if self.Progression then self.Progression:UpdateObjectivesFromMatch(target, team) end
		end
		updateObjectives(home, "Home")
		updateObjectives(away, "Away")
		session.MatchId = tostring(session.MatchId or HttpService:GenerateGUID(false))
		self:_clearMatchAssignmentsFor(session.MatchId, home, away)
	local function personal(side: string): any
			local best = nil
			for _, entry in serialized.PlayerRatings or {} do
				if entry.Team == side and (not best or entry.Rating > best.Rating) then best = entry end
			end
			return {
				ResultId = session.MatchId .. ":" .. side,
				PlayerRating = best and best.Rating or 6,
				Team = side,
				Match = side == "Home" and serialized.Home or serialized.Away,
				Full = serialized,
				MOTM = serialized.MOTM,
			}
		end
		if ended.RankedResultsRecorded==true then return end
		ended.RankedResultsRecorded=true
		local homePersonal = personal("Home")
		local awayPersonal = personal("Away")
		local homeApplied = self.RankedProfiles:RecordServerResult(home, homeResult, rpFor(homeResult), away.Name, score, homePersonal, self:_teamTag(away), self:_teamName(away))
		local awayApplied = self.RankedProfiles:RecordServerResult(away, awayResult, rpFor(awayResult), home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), awayPersonal, self:_teamTag(home), self:_teamName(home))
		local homePack = nil
		local awayPack = nil
		if homeResult=="Win" or homeResult=="ForfeitWin" then homePack = session.RankedWinPackGrant(session,home) end
		if awayResult=="Win" or awayResult=="ForfeitWin" then awayPack = session.RankedWinPackGrant(session,away) end
		self:_writePendingRankedResult(home,{MatchId=session.MatchId,ResultId=homePersonal.ResultId,Result=homeResult,Opponent=away.Name,OpponentTag=self:_teamTag(away),OpponentTeamName=self:_teamName(away),Score=score,MatchStats=homePersonal,PackId=homePack and homePack.PackId or nil,AppliedInMatchServer=homeApplied})
		self:_writePendingRankedResult(away,{MatchId=session.MatchId,ResultId=awayPersonal.ResultId,Result=awayResult,Opponent=home.Name,OpponentTag=self:_teamTag(home),OpponentTeamName=self:_teamName(home),Score=tostring(awayScore).."-"..tostring(homeScore),MatchStats=awayPersonal,PackId=awayPack and awayPack.PackId or nil,AppliedInMatchServer=awayApplied})
		if self.Publish and self.RankedProfiles.GetClientData then
			pcall(function()self.Publish(home,"Ranked",self.RankedProfiles:GetClientData(home))end)
			pcall(function()self.Publish(away,"Ranked",self.RankedProfiles:GetClientData(away))end)
		end
	end
	session.OnBeforeResult = function(ended: any)
		local rewards = {}
		local homeScore=ended.World.HomeScore.Value
		local awayScore=ended.World.AwayScore.Value
		local homeResult=resultFor(home,"Home",homeScore,awayScore)
		local awayResult=resultFor(away,"Away",homeScore,awayScore)
		local appliedByUser:any={}
		local personalByUser:any={}
		local scoreByUser:any={[home.UserId]=tostring(homeScore).."-"..tostring(awayScore),[away.UserId]=tostring(awayScore).."-"..tostring(homeScore)}
		if ended.RankedResultsRecorded~=true then
			ended.RankedResultsRecorded=true
			local score=tostring(homeScore).."-"..tostring(awayScore)
			ended.MatchId = tostring(ended.MatchId or session.MatchId or HttpService:GenerateGUID(false))
			session.MatchId = ended.MatchId
			self:_clearMatchAssignmentsFor(session.MatchId, home, away)
			local serialized=ended.Stats:Serialize(homeScore,awayScore,ended.Clock:Payload().GameSeconds)
			local function personal(side:string):any
				local best=nil
				for _,entry in serialized.PlayerRatings or{}do
					if entry.Team==side and (not best or entry.Rating>best.Rating)then best=entry end
				end
				return{ResultId=session.MatchId..":"..side,PlayerRating=best and best.Rating or 6,Team=side,Match=side=="Home"and serialized.Home or serialized.Away,Full=serialized,MOTM=serialized.MOTM}
			end
			local homePersonal=personal("Home")
			local awayPersonal=personal("Away")
			local homeApplied=self.RankedProfiles:RecordServerResult(home,homeResult,rpFor(homeResult),away.Name,score,homePersonal,self:_teamTag(away),self:_teamName(away))
			local awayApplied=self.RankedProfiles:RecordServerResult(away,awayResult,rpFor(awayResult),home.Name,tostring(awayScore).."-"..tostring(homeScore),awayPersonal,self:_teamTag(home),self:_teamName(home))
			appliedByUser[home.UserId]=homeApplied
			appliedByUser[away.UserId]=awayApplied
			personalByUser[home.UserId]=homePersonal
			personalByUser[away.UserId]=awayPersonal
			if self.Publish and self.RankedProfiles.GetClientData then
				pcall(function()self.Publish(home,"Ranked",self.RankedProfiles:GetClientData(home))end)
				pcall(function()self.Publish(away,"Ranked",self.RankedProfiles:GetClientData(away))end)
			end
			if self.Publish and self.Progression then
				if self.Progression.GetClientData then
					pcall(function()self.Publish(home,"Progression",self.Progression:GetClientData(home))end)
					pcall(function()self.Publish(away,"Progression",self.Progression:GetClientData(away))end)
				end
				if self.Progression.Inventory and self.Progression.Inventory.GetClientData then
					pcall(function()self.Publish(home,"Inventory",self.Progression.Inventory:GetClientData(home))end)
					pcall(function()self.Publish(away,"Inventory",self.Progression.Inventory:GetClientData(away))end)
				end
			end
		end
		for participant, result in {[home]=homeResult,[away]=awayResult} do
			local won=result=="Win" or result=="ForfeitWin"
			local draw=result=="Draw"
			local coins = 900 + (won and 900 or draw and 450 or 225)
			local xp = 140 + (won and 110 or draw and 55 or 25)
			local reward=nil
			if self.Progression then
				reward = self.Progression:GrantMatchRewards(participant, {
					Title = won and "RANKED VICTORY" or draw and "RANKED DRAW" or "RANKED MATCH",
					Coins = coins,
					XP = xp,
				})
			end
			if won then
				session.RankedWinRewards=session.RankedWinRewards or{}
				local packReward=session.RankedWinRewards[participant.UserId]
				if not packReward then
					packReward=RankedWinPackReward.Grant(self.Progression,participant,self.Publish)
					session.RankedWinRewards[participant.UserId]=packReward
				end
				reward=reward or{}
				for key,value in packReward do
					reward[key]=value
				end
				reward.Title="RANKED VICTORY"
			end
			local side = participant == home and "Home" or "Away"
			local resultId = tostring(session.MatchId or ended.MatchId or HttpService:GenerateGUID(false)) .. ":" .. side
			local matchStats = personalByUser[participant.UserId] or {ResultId=resultId,Team=side}
			local packReward = session.RankedWinRewards and session.RankedWinRewards[participant.UserId] or nil
			if reward then rewards[participant.UserId] = reward end
			if reward and self.RankedProfiles.AttachHistoryReward then
				self.RankedProfiles:AttachHistoryReward(participant,tostring(matchStats.ResultId or resultId),reward)
			end
			self:_writePendingRankedResult(participant,{
				MatchId=tostring(session.MatchId or ended.MatchId or ""),
				ResultId=tostring(matchStats.ResultId or resultId),
				Result=result,
				Opponent=participant==home and away.Name or home.Name,
				OpponentTag=participant==home and self:_teamTag(away) or self:_teamTag(home),
				OpponentTeamName=participant==home and self:_teamName(away) or self:_teamName(home),
				Score=scoreByUser[participant.UserId] or (participant==home and tostring(homeScore).."-"..tostring(awayScore) or tostring(awayScore).."-"..tostring(homeScore)),
				MatchStats=matchStats,
				Reward=reward,
				PackId=packReward and packReward.PackId or nil,
				PackInstanceId=packReward and packReward.PackInstanceId or nil,
				AppliedInMatchServer=appliedByUser[participant.UserId]==true,
			})
		end
		self:_savePlayers({home,away})
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
		local matchId=HttpService:GenerateGUID(false)
		local homeFound=self:_matchFoundPayload(home,away,"Home",homeRoster,awayRoster,matchId)
		local awayFound=self:_matchFoundPayload(away,home,"Away",homeRoster,awayRoster,matchId)
		self.LastMatchFound[home]=homeFound
		self.LastMatchFound[away]=awayFound
		rankedFoundRemote():FireClient(home,homeFound)
		rankedFoundRemote():FireClient(away,awayFound)
		self.Notifications:Send(home, "OPPONENT FOUND", away.Name .. " is ready. Starting local test match.", "Info")
		self.Notifications:Send(away, "OPPONENT FOUND", home.Name .. " is ready. Starting local test match.", "Info")
		task.defer(function()
			local success, message = self.Runtime:StartRankedMatch(home, away, homeSetup, awaySetup, homeRoster, awayRoster)
			if not success then
				self.Notifications:Send(home, "MATCH FAILED", message, "Error")
				self.Notifications:Send(away, "MATCH FAILED", message, "Error")
				return
			end
			if self.LastMatchFound then self.LastMatchFound[home]=nil;self.LastMatchFound[away]=nil end
			self.RankedSquads:ConsumeLoans(home)
			self.RankedSquads:ConsumeLoans(away)
			local session = self.Runtime:GetSession(home)
			if session then self:_attachResultHandlers(session, home, away) end
		end)
	end
end

function Service:_ticketFor(player: Player, profile: any, roster: any, device: string): any
	local crossplay = not profile.UIState or not profile.UIState.Settings or profile.UIState.Settings.Crossplay ~= false
	local summary=self:_summaryForRoster(roster)
	return {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		JobId = game.JobId,
		PlaceId = game.PlaceId,
		DeviceType = device,
		Crossplay = crossplay,
		CreatedAt = os.time(),
		TeamName = summary.teamName,
		TeamLogo = summary.logo,
		TeamOverall = summary.overall,
		TeamAttack = summary.attack,
		TeamMidfield = summary.midfield,
		TeamDefense = summary.defense,
		TeamBadgeIdentity = roster.Team.BadgeIdentity or roster.Team.badgeIdentity,
		TeamFlagImage = roster.Team.FlagImage or roster.Team.flagImage,
		TeamBadgeImage = roster.Team.BadgeImage or roster.Team.badgeImage or roster.Team.LogoImage or roster.Team.logoImage,
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
		HomeLogo = homeTicket.TeamLogo,
		AwayLogo = awayTicket.TeamLogo,
		HomeFlagImage = homeTicket.TeamFlagImage,
		AwayFlagImage = awayTicket.TeamFlagImage,
		HomeBadgeImage = homeTicket.TeamBadgeImage,
		AwayBadgeImage = awayTicket.TeamBadgeImage,
		HomeBadgeIdentity = homeTicket.TeamBadgeIdentity,
		AwayBadgeIdentity = awayTicket.TeamBadgeIdentity,
		HomeOverall = homeTicket.TeamOverall,
		AwayOverall = awayTicket.TeamOverall,
		HomeAttack = homeTicket.TeamAttack,
		AwayAttack = awayTicket.TeamAttack,
		HomeMidfield = homeTicket.TeamMidfield,
		AwayMidfield = awayTicket.TeamMidfield,
		HomeDefense = homeTicket.TeamDefense,
		AwayDefense = awayTicket.TeamDefense,
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
	rankedFoundRemote():FireClient(player,{
		Opponent = player.UserId == tonumber(assignment.HomeUserId) and assignment.AwayName or assignment.HomeName,
		HomeName = assignment.HomeName,
		AwayName = assignment.AwayName,
		HomeTeamName = assignment.HomeTeamName,
		AwayTeamName = assignment.AwayTeamName,
		HomeLogo = assignment.HomeLogo,
		AwayLogo = assignment.AwayLogo,
		HomeBadgeIdentity = assignment.HomeBadgeIdentity,
		AwayBadgeIdentity = assignment.AwayBadgeIdentity,
		HomeOverall = assignment.HomeOverall,
		AwayOverall = assignment.AwayOverall,
		HomeAttack = assignment.HomeAttack,
		AwayAttack = assignment.AwayAttack,
		HomeMidfield = assignment.HomeMidfield,
		AwayMidfield = assignment.AwayMidfield,
		HomeDefense = assignment.HomeDefense,
		AwayDefense = assignment.AwayDefense,
		Role = assignment.Role,
		MatchId = assignment.MatchId,
	})
	task.wait(3.15)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = assignment.AccessCode
	options:SetTeleportData(assignment)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(tonumber(assignment.PlaceId) or game.PlaceId, { player }, options)
	end)
	if not ok then
		self.GlobalTeleporting[player] = nil
		self.Notifications:Send(player, "MATCH TELEPORT FAILED", tostring(err), "Error")
	else
		self:_clearMatchAssignmentForUserId(player.UserId)
	end
end

function Service:_checkAssignment(player: Player): boolean
	local matchMap = self:_matchMap()
	if not matchMap then return false end
	local ok, assignment = pcall(function()
		return matchMap:GetAsync(self:_matchKey(player.UserId))
	end)
	if ok and type(assignment) == "table" and assignment.MatchMode == "Ranked1v1" and type(assignment.AccessCode) == "string" then
		if self:_assignmentExpired(assignment) then
			self:_clearMatchAssignment(assignment)
			return false
		end
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

function Service:_rankedTeleportData(player: Player): any?
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if type(teleportData) == "table" and teleportData.MatchMode == "Ranked1v1" then
		return teleportData
	end
	return nil
end

function Service:_tryStartTeleportRanked()
	if self.RankedTeleportStarted then return end
	local found = {}
	for _, player in Players:GetPlayers() do
		local data = self:_rankedTeleportData(player)
		if data then
			found[player] = data
		end
	end
	local homePlayer = nil
	local awayPlayer = nil
	local data = nil
	for player, teleportData in found do
		local homeId = tonumber(teleportData.HomeUserId)
		local awayId = tonumber(teleportData.AwayUserId)
		if player.UserId == homeId then homePlayer = player end
		if player.UserId == awayId then awayPlayer = player end
		data = teleportData
	end
	if not homePlayer or not awayPlayer or not data then return end
	if not homePlayer.Character or not awayPlayer.Character then return end
	if not homePlayer.Character:FindFirstChildOfClass("Humanoid") or not awayPlayer.Character:FindFirstChildOfClass("Humanoid") then return end
	local homeProfile = self.Profiles:GetProfile(homePlayer)
	local awayProfile = self.Profiles:GetProfile(awayPlayer)
	if not homeProfile or not awayProfile then return end
	local homeReady, homeMessage, homeRoster = self.RankedSquads:GetRoster(homePlayer)
	local awayReady, awayMessage, awayRoster = self.RankedSquads:GetRoster(awayPlayer)
	if not homeReady or not awayReady or not homeRoster or not awayRoster then
		self.Notifications:Send(homePlayer, "RANKED MATCH", homeMessage or "Home roster unavailable.", "Error")
		self.Notifications:Send(awayPlayer, "RANKED MATCH", awayMessage or "Away roster unavailable.", "Error")
		return
	end
	self.RankedTeleportStarted = true
	local homeSetup = self:BuildRankedSetup(homePlayer, homeProfile, homeRoster)
	local awaySetup = self:BuildRankedSetup(awayPlayer, awayProfile, awayRoster)
	local success, message = self.Runtime:StartRankedMatch(homePlayer, awayPlayer, homeSetup, awaySetup, homeRoster, awayRoster)
	if not success then
		self.RankedTeleportStarted = false
		self.Notifications:Send(homePlayer, "MATCH FAILED", message, "Error")
		self.Notifications:Send(awayPlayer, "MATCH FAILED", message, "Error")
		return
	end
	self.RankedSquads:ConsumeLoans(homePlayer)
	self.RankedSquads:ConsumeLoans(awayPlayer)
	local session = self.Runtime:GetSession(homePlayer)
	if session then
		session.PrivateRankedMatch = true
		session.MatchId = tostring(data.MatchId or HttpService:GenerateGUID(false))
		session.ReturnPlaceId = tonumber(data.ReturnPlaceId) or tonumber(data.PlaceId) or game.PlaceId
		self:_attachResultHandlers(session, homePlayer, awayPlayer)
	end
end

function Service:_startRankedTeleportWatcher()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if self:_rankedTeleportData(player) then
					self:_tryStartTeleportRanked()
					break
				end
			end
			task.wait(.35)
		end
	end)
end

function Service:_startGlobalPoll()
	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			if self.GlobalEnabled then
				for _, online in Players:GetPlayers() do
					if online:GetAttribute("VTRInMatch") ~= true then
						self:_consumePendingRankedResult(online)
					end
				end
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
	if self.LastMatchFound then self.LastMatchFound[player]=nil end
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
	local found=self.LastMatchFound and self.LastMatchFound[player] or nil
	return true, found and "Opponent found. Match starting." or "Searching for a ranked opponent.", found or { Status = "Searching", Position = table.find(self.Queue, player) or 0, Global = false }
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
	self:_clearMatchAssignmentForUserId(player.UserId)
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
