--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local MatchConfig=require(ReplicatedStorage.VTR.Shared.MatchConfig)
local TeamDatabase=require(script.Parent.Parent.Data.TeamDatabase)
local ObjectiveService=require(script.Parent.ObjectiveService)
local Service={};Service.__index=Service
local function contains(list:any,value:any):boolean return table.find(list,value)~=nil end
local function stadium(id:string):any?for _,item in MatchConfig.Stadiums do if item.Id==id then return item end end;return nil end
local function kit(team:any,name:string):any?return team and team.kits[name]or nil end
local function colorDistance(first:string,second:string):number local a,b=Color3.fromHex(first),Color3.fromHex(second);return math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B)end
function Service.new(profiles:any,publish:(Player,string,any)->(),progression:any,runtime:any,rankedSquads:any?)return setmetatable({Profiles=profiles,Publish=publish,Progression=progression,Runtime=runtime,RankedSquads=rankedSquads},Service)end
function Service:_ensure(profile:any):any local setup=profile.MatchSetup;if not setup or not TeamDatabase.Get(setup.HomeTeamId)or not TeamDatabase.Get(setup.AwayTeamId)or(setup.HomeTeamId==setup.AwayTeamId and setup.MatchType~="Friendly")then local home,away=TeamDatabase.Teams[1],TeamDatabase.Teams[2];setup={MatchLength=6,Difficulty="Professional",MatchType="Objective Match",HomeTeamId=home.teamId,AwayTeamId=away.teamId,HomeKit="Home",AwayKit="Away",StadiumId="voltra_arena",Weather="Clear",Time="Evening",Completed=false,SavedAt=0,KitConflict=false};profile.MatchSetup=setup end;return setup end
function Service:_validate(setup:any):(boolean,string)
	if not contains(MatchConfig.MatchLengths,setup.MatchLength)then return false,"Invalid match length."end;if not contains(MatchConfig.Difficulties,setup.Difficulty)then return false,"Invalid difficulty."end;if not contains(MatchConfig.MatchTypes,setup.MatchType)then return false,"Invalid match type."end;if not contains(MatchConfig.Weather,setup.Weather)or not contains(MatchConfig.Times,setup.Time)then return false,"Invalid presentation settings."end
	local home,away=TeamDatabase.Get(setup.HomeTeamId),TeamDatabase.Get(setup.AwayTeamId);if not home or not away then return false,"Select two valid teams."end;if home.teamId==away.teamId and setup.MatchType~="Friendly"then return false,"Mirror matches are only available in Friendly mode."end;if not kit(home,setup.HomeKit)or not kit(away,setup.AwayKit)then return false,"Invalid kit selection."end;local venue=stadium(setup.StadiumId);if not venue or not contains(venue.WeatherSupport,setup.Weather)then return false,"Selected stadium does not support this weather."end;return true,"Match setup valid."
end
function Service:GetClientData(player:Player):any?local profile=self.Profiles:GetProfile(player);if not profile then return nil end;local setup=self:_ensure(profile);local home,away=TeamDatabase.Get(setup.HomeTeamId),TeamDatabase.Get(setup.AwayTeamId);return{Setup=table.clone(setup),Teams={TeamDatabase.Summary(home),TeamDatabase.Summary(away)},Countries=TeamDatabase.GetCountries(),TeamCount=TeamDatabase.Count,Stadiums=MatchConfig.Stadiums,Options={MatchLengths=MatchConfig.MatchLengths,Difficulties=MatchConfig.Difficulties,MatchTypes=MatchConfig.MatchTypes,Weather=MatchConfig.Weather,Times=MatchConfig.Times,KitTypes=MatchConfig.KitTypes}}end
function Service:GetRoster(_player:Player,teamId:string):any?return TeamDatabase.GetRoster(teamId)end
function Service:GetTeams(_player:Player,country:any,league:any):any?if type(country)~="string"or#country>50 or type(league)~="string"or#league>60 then return nil end;return TeamDatabase.GetSummaries(country,league)end
function Service:Save(player:Player,payload:any):(boolean,string,any?)local profile=self.Profiles:GetProfile(player);if not profile or type(payload)~="table"then return false,"Profile unavailable.",nil end;local nextSetup=table.clone(self:_ensure(profile));for key,value in payload do if nextSetup[key]~=nil then nextSetup[key]=value end end;local valid,message=self:_validate(nextSetup);if not valid then return false,message,nil end;nextSetup.Completed=true;nextSetup.SavedAt=os.time();local home,away=TeamDatabase.Get(nextSetup.HomeTeamId),TeamDatabase.Get(nextSetup.AwayTeamId);nextSetup.KitConflict=colorDistance(home.kits[nextSetup.HomeKit].Primary,away.kits[nextSetup.AwayKit].Primary)<.35;profile.MatchSetup=nextSetup;return true,"Match settings saved.",table.clone(nextSetup)end
function Service:StartMatch(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	local success,text,data=self.Runtime:StartMatch(player,setup);if not success then return false,text,nil end
	local session=self.Runtime:GetSession(player);if session then session.OnBeforeResult=function(ended:any)local current=self.Profiles:GetProfile(player);if not current or ended.World.HomeScore.Value<=ended.World.AwayScore.Value then return{}end;current.Currency.Coins+=1000;current.Season.XP+=150;return{[player.UserId]={Title="VICTORY STAR",Coins=1000,XP=150}}end;session.OnCompleted=function(ended:any)local current=self.Profiles:GetProfile(player);if not current then return end;local serialized=ended.Stats:Serialize(ended.World.HomeScore.Value,ended.World.AwayScore.Value,ended.Clock:Payload().GameSeconds);for _,objective in current.Objectives do if objective.status~="claimed"then if objective.objectiveId=="daily_complete_passes"then objective.progress=math.min(objective.target,objective.progress+(serialized.Home.PassesCompleted or 0))elseif objective.objectiveId=="weekly_score_goals"then objective.progress=math.min(objective.target,objective.progress+(serialized.Home.Goals or 0))end;if objective.status=="active"and objective.progress>=objective.target then objective.status="claimable"end end end;self.Publish(player,"Objective",ObjectiveService.Serialize(current.Objectives));self.Publish(player,"Progression",self.Progression:GetClientData(player))end end
	local completed=false;for _,objective in profile.Objectives do if objective.objectiveId=="play_first_match_placeholder"and objective.status~="claimed"then completed=objective.progress<objective.target;objective.progress=1;if objective.status=="active"then objective.status="claimable"end;break end end
	self.Publish(player,"Objective",ObjectiveService.Serialize(profile.Objectives));self.Publish(player,"Progression",self.Progression:GetClientData(player));data.ObjectiveCompletedNow=completed;return true,text,data
end
function Service:WatchMatch(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	local watchSetup=table.clone(setup);watchSetup.WatchMode=true;watchSetup.TeamTactics=profile.TeamTactics
	local homeRoster=nil
	if self.RankedSquads then
		local ready,text,roster=self.RankedSquads:GetRoster(player)
		if not ready then return false,text,nil end
		homeRoster=roster
		watchSetup.HomeTeamId=roster.Team.teamId
		watchSetup.HomeKit="Home"
	end
	local success,text,data=self.Runtime:StartMatch(player,watchSetup,nil,nil,homeRoster,nil);if not success then return false,text,nil end
	if data then data.ObjectiveCompletedNow=false;data.WatchMode=true end
	return true,"AI vs AI match loaded.",data
end
function Service:ReturnToMenu(player:Player):boolean return self.Runtime:ReturnToMenu(player)end
return Service
