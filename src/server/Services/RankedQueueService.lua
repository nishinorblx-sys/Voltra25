local MATCHUP_PANEL_DELAY = 0.85
--!strict
local Players=game:GetService("Players")

local Service={}
Service.__index=Service

function Service.new(profiles:any,runtime:any,rankedProfiles:any,notifications:any,rankedSquads:any,progression:any?)
	return setmetatable({Profiles=profiles,Runtime=runtime,RankedProfiles=rankedProfiles,Notifications=notifications,RankedSquads=rankedSquads,Progression=progression,Queue={},QueuedAt={},QueueSetup={},QueueRoster={},QueueDevice={},Random=Random.new()},Service)
end

function Service:_rankedSetup(player:Player,profile:any,roster:any):any
	local saved=profile.MatchSetup or{}
	return{MatchLength=8,Difficulty="World Class",MatchType="Ranked",WatchMode=true,HomeTeamId=roster.Team.teamId,AwayTeamId=roster.Team.teamId,HomeKit="Home",AwayKit="Away",StadiumId=type(saved.StadiumId)=="string"and saved.StadiumId or"voltra_arena",Weather=({"Clear","Cloudy","Rain"})[self.Random:NextInteger(1,3)],Time=({"Day","Evening","Night"})[self.Random:NextInteger(1,3)],Completed=true,SavedAt=os.time(),KitConflict=false}
end

function Service:_remove(player:Player)
	local index=table.find(self.Queue,player);if index then table.remove(self.Queue,index)end
	self.QueuedAt[player]=nil;self.QueueSetup[player]=nil;self.QueueRoster[player]=nil;self.QueueDevice[player]=nil;player:SetAttribute("VTRRankedQueued",nil)
end

function Service:_valid(player:Player):boolean
	return player.Parent==Players and self.Profiles:GetProfile(player)~=nil and player:GetAttribute("VTRInMatch")~=true
end

function Service:_compatible(home:Player,away:Player):boolean
	local homeProfile=self.Profiles:GetProfile(home);local awayProfile=self.Profiles:GetProfile(away)
	local homeCross=not homeProfile or not homeProfile.UIState or not homeProfile.UIState.Settings or homeProfile.UIState.Settings.Crossplay~=false
	local awayCross=not awayProfile or not awayProfile.UIState or not awayProfile.UIState.Settings or awayProfile.UIState.Settings.Crossplay~=false
	if homeCross and awayCross then return true end
	return (self.QueueDevice[home]or"KeyboardMouse")==(self.QueueDevice[away]or"KeyboardMouse")
end

function Service:_nextPair(): (Player?, Player?)
	for firstIndex=1,#self.Queue do
		local first=self.Queue[firstIndex]
		for secondIndex=firstIndex+1,#self.Queue do
			local second=self.Queue[secondIndex]
			if self:_compatible(first,second)then
				table.remove(self.Queue,secondIndex)
				table.remove(self.Queue,firstIndex)
				return first,second
			end
		end
	end
	return nil,nil
end

function Service:_pair()
	while #self.Queue>=2 do
		local home,away=self:_nextPair();if not home or not away then break end;self.QueuedAt[home]=nil;self.QueuedAt[away]=nil;home:SetAttribute("VTRRankedQueued",nil);away:SetAttribute("VTRRankedQueued",nil)
		if not self:_valid(home)or not self:_valid(away)then if self:_valid(home)then table.insert(self.Queue,home)end;if self:_valid(away)then table.insert(self.Queue,away)end;continue end
		local homeProfile=self.Profiles:GetProfile(home);local awayProfile=self.Profiles:GetProfile(away);local homeRoster=self.QueueRoster[home];local awayRoster=self.QueueRoster[away];local homeSetup=self.QueueSetup[home]or(homeProfile and homeRoster and self:_rankedSetup(home,homeProfile,homeRoster));local awaySetup=self.QueueSetup[away]or(awayProfile and awayRoster and self:_rankedSetup(away,awayProfile,awayRoster));self.QueueSetup[home]=nil;self.QueueSetup[away]=nil;self.QueueRoster[home]=nil;self.QueueRoster[away]=nil;self.QueueDevice[home]=nil;self.QueueDevice[away]=nil
		if not homeSetup or not awaySetup or not homeRoster or not awayRoster then self.Notifications:Send(home,"RANKED QUEUE","Ultimate Team lineup unavailable.","Error");self.Notifications:Send(away,"RANKED QUEUE","Ultimate Team lineup unavailable.","Error");continue end
		self.Notifications:Send(home,"OPPONENT FOUND",away.Name.." is ready. Starting watch match.","Info");self.Notifications:Send(away,"OPPONENT FOUND",home.Name.." is ready. Starting watch match.","Info")
		task.defer(function()
			local success,message=self.Runtime:StartRankedMatch(home,away,homeSetup,awaySetup,homeRoster,awayRoster)
			if not success then self.Notifications:Send(home,"MATCH FAILED",message,"Error");self.Notifications:Send(away,"MATCH FAILED",message,"Error");return end
			self.RankedSquads:ConsumeLoans(home);self.RankedSquads:ConsumeLoans(away)
			local session=self.Runtime:GetSession(home);if session then session.OnRankedEnded=function(ended:any)
				local homeScore=ended.World.HomeScore.Value;local awayScore=ended.World.AwayScore.Value;local homeResult=homeScore>awayScore and"Win"or homeScore<awayScore and"Loss"or"Draw";local awayResult=homeResult=="Win"and"Loss"or homeResult=="Loss"and"Win"or"Draw";local homeRP=homeResult=="Win"and 35 or homeResult=="Draw"and 12 or-20;local awayRP=awayResult=="Win"and 35 or awayResult=="Draw"and 12 or-20;local score=tostring(homeScore).."-"..tostring(awayScore)
				local serialized=ended.Stats:Serialize(homeScore,awayScore,ended.Clock:Payload().GameSeconds)
				local function updateObjectives(target:Player,side:string)local team=side=="Home"and serialized.Home or serialized.Away;if self.Progression then self.Progression:UpdateObjectivesFromMatch(target,team)end end;updateObjectives(home,"Home");updateObjectives(away,"Away")
				local function personal(side:string):any local best=nil;for _,entry in serialized.PlayerRatings or{}do if entry.Team==side and(not best or entry.Rating>best.Rating)then best=entry end end;return{PlayerRating=best and best.Rating or 6,Team=side,Match=side=="Home"and serialized.Home or serialized.Away,Full=serialized,MOTM=serialized.MOTM}end
				self.RankedProfiles:RecordServerResult(home,homeResult,homeRP,away.Name,score,personal("Home"));self.RankedProfiles:RecordServerResult(away,awayResult,awayRP,home.Name,tostring(awayScore).."-"..tostring(homeScore),personal("Away"))
			end;session.OnBeforeResult=function(ended:any)local rewards={};local homeWon=ended.World.HomeScore.Value>ended.World.AwayScore.Value;local awayWon=ended.World.AwayScore.Value>ended.World.HomeScore.Value;local draw=ended.World.HomeScore.Value==ended.World.AwayScore.Value;for participant,won in{[home]=homeWon,[away]=awayWon}do local coins=900+(won and 900 or draw and 450 or 225);local xp=140+(won and 110 or draw and 55 or 25);if self.Progression then local reward=self.Progression:GrantMatchRewards(participant,{Title=won and"RANKED VICTORY"or draw and"RANKED DRAW"or"RANKED MATCH",Coins=coins,XP=xp});if reward then rewards[participant.UserId]=reward end end end;return rewards end end
		end)
	end
end

function Service:Join(player:Player,payload:any?):(boolean,string,any?)
	if player:GetAttribute("VTRInMatch")==true then return false,"You are already in a match.",nil end
	if self.QueuedAt[player]then return true,"Already searching for an opponent.",{Status="Searching",Position=table.find(self.Queue,player)or 1}end
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local squadReady,squadMessage,roster=self.RankedSquads:GetRoster(player);if not squadReady or not roster then return false,squadMessage,nil end
	local device=type(payload)=="table"and tostring(payload.DeviceType or"")or"";if device~="Touch"and device~="Gamepad"and device~="KeyboardMouse"then device="KeyboardMouse"end
	self.QueueDevice[player]=device;self.QueueRoster[player]=roster;self.QueueSetup[player]=self:_rankedSetup(player,profile,roster);table.insert(self.Queue,player);self.QueuedAt[player]=os.clock();player:SetAttribute("VTRRankedQueued",true);self.Notifications:Send(player,"RANKED QUEUE",roster.Team.teamName.." / OVR "..roster.Team.overall.." / Searching watch queue.","Info");self:_pair()
	return true,#self.Queue==0 and"Opponent found. Watch match starting."or"Searching for a ranked opponent.",{Status=#self.Queue==0 and"Matched"or"Searching",Position=table.find(self.Queue,player)or 0}
end

function Service:Leave(player:Player):(boolean,string,any?)
	if not self.QueuedAt[player]then return false,"You are not currently queued.",nil end;self:_remove(player);return true,"Ranked search cancelled.",{Status="Idle"}
end

function Service:GetStatus(player:Player):any
	return{Status=self.QueuedAt[player]and"Searching"or player:GetAttribute("VTRInMatch")and"InMatch"or"Idle",Position=table.find(self.Queue,player)or 0,QueuedPlayers=#self.Queue}
end

function Service:PlayerRemoving(player:Player)self:_remove(player)end

return Service
