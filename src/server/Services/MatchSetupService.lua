local MATCHUP_PANEL_DELAY = 0.85
--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local MatchConfig=require(ReplicatedStorage.VTR.Shared.MatchConfig)
local VTRLiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local TeamDatabase=require(script.Parent.Parent.Data.TeamDatabase)
local ObjectiveService=require(script.Parent.ObjectiveService)
local Service={};Service.__index=Service
local function contains(list:any,value:any):boolean return table.find(list,value)~=nil end
local PACK_FALLBACKS={rare_pack="elite_pack",legendary_pack="champion_pack",icon_pack="hero_pack"}
local function packIdFor(id:string?):string return PACK_FALLBACKS[id or""]or id or"bronze_pack"end
local function stadium(id:string):any?for _,item in MatchConfig.Stadiums do if item.Id==id then return item end end;return nil end
local function kit(team:any,name:string):any?return team and team.kits[name]or nil end
local function colorDistance(first:string,second:string):number local a,b=Color3.fromHex(first),Color3.fromHex(second);return math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B)end
function Service.new(profiles:any,publish:(Player,string,any)->(),progression:any,runtime:any,rankedSquads:any?)return setmetatable({Profiles=profiles,Publish=publish,Progression=progression,Runtime=runtime,RankedSquads=rankedSquads},Service)end
function Service:_ensure(profile:any):any local setup=profile.MatchSetup;if not setup or not TeamDatabase.Get(setup.HomeTeamId)or not TeamDatabase.Get(setup.AwayTeamId)or(setup.HomeTeamId==setup.AwayTeamId and setup.MatchType~="Friendly")then local home,away=TeamDatabase.Teams[1],TeamDatabase.Teams[2];setup={MatchLength=6,Difficulty="Professional",MatchType="Objective Match",HomeTeamId=home.teamId,AwayTeamId=away.teamId,HomeKit="Home",AwayKit="Away",StadiumId="voltra_arena",Weather="Clear",Time="Evening",Completed=false,SavedAt=0,KitConflict=false,CampaignTeamId="",CampaignTier=0,CampaignReplay=false};profile.MatchSetup=setup end;setup.CampaignTeamId=setup.CampaignTeamId or"";setup.CampaignTier=tonumber(setup.CampaignTier)or 0;setup.CampaignReplay=setup.CampaignReplay==true;return setup end
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
	local session=self.Runtime:GetSession(player);if session then
		session.OnBeforeResult=function(ended:any)
			local homeScore=ended.World.HomeScore.Value
			local awayScore=ended.World.AwayScore.Value
			local homeWon=homeScore>awayScore
			local drew=homeScore==awayScore
			local coins=650+(homeWon and 650 or drew and 300 or 150)
			local xp=110+(homeWon and 90 or drew and 45 or 20)
			local reward=self.Progression:GrantMatchRewards(player,{Title=homeWon and"VICTORY REWARD"or drew and"DRAW REWARD"or"MATCH REWARD",Coins=coins,XP=xp})
			return reward and{[player.UserId]=reward}or{}
		end
		session.OnCompleted=function(ended:any)
			local serialized=ended.Stats:Serialize(ended.World.HomeScore.Value,ended.World.AwayScore.Value,ended.Clock:Payload().GameSeconds)
			self.Progression:UpdateObjectivesFromMatch(player,serialized.Home)
		end
	end
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
	local session=self.Runtime:GetSession(player)
	if session and type(watchSetup.CampaignTeamId)=="string" and watchSetup.CampaignTeamId~="" then
		local teamId=watchSetup.CampaignTeamId
		local tierIndex=math.clamp(tonumber(watchSetup.CampaignTier)or 1,1,#VTRLiteConfig.CampaignDifficulties)
		local tier=VTRLiteConfig.CampaignDifficulties[tierIndex]
		local replay=watchSetup.CampaignReplay==true
		session.OnBeforeResult=function(ended:any)
			local current=self.Profiles:GetProfile(player);if not current or ended.World.HomeScore.Value<=ended.World.AwayScore.Value or replay then return{}end
			local progress=current.CampaignProgress or{UnlockedDifficulty=1,CompletedTeams={},RewardsClaimed={}};current.CampaignProgress=progress;progress.CompletedTeams=progress.CompletedTeams or{};progress.RewardsClaimed=progress.RewardsClaimed or{}
			if progress.CompletedTeams[teamId]==true then return{}end
			local rewardKey="campaign_"..tostring(teamId)
			if progress.RewardsClaimed[rewardKey]==true then return{}end
			progress.RewardsClaimed[rewardKey]=true
			local packId=packIdFor(tier and tier.PackId or"bronze_pack")
			local packsGranted=0
			if self.Progression and self.Progression.Inventory and self.Progression.Inventory:AddPack(player,packId,packId,"Campaign",1)then packsGranted+=1 end
			local cleared=0;local tierId=tier and tier.Id or"";for completedId,done in progress.CompletedTeams do if done and string.find(tostring(completedId),tierId,1,true)then cleared+=1 end end
			local firstTierClear=cleared>=4
			local tierClearKey="campaign_tier_clear_"..tostring(tierId)
			local voltraGranted=false
			if firstTierClear and progress.RewardsClaimed[tierClearKey]~=true then
				progress.RewardsClaimed[tierClearKey]=true
				if self.Progression and self.Progression.Inventory and self.Progression.Inventory:AddPack(player,"voltra_pack","voltra_pack","CampaignTierClear",1)then packsGranted+=1;voltraGranted=true end
			end
			return{[player.UserId]={Title=firstTierClear and"CAMPAIGN TIER CLEAR"or"CAMPAIGN CLEAR",Coins=0,XP=0,Pack=(tier and tier.Reward or"Campaign Pack")..(voltraGranted and" + Voltra Pack"or""),BonusPack=voltraGranted and"VOLTRA PACK"or nil,VoltraPack=voltraGranted,LeagueClear=voltraGranted,PackId=packId,Packs=packsGranted}}
		end
		session.OnCompleted=function(ended:any)
			local current=self.Profiles:GetProfile(player);if not current or ended.World.HomeScore.Value<=ended.World.AwayScore.Value or replay then return end
			local progress=current.CampaignProgress or{UnlockedDifficulty=1,CompletedTeams={},RewardsClaimed={}};current.CampaignProgress=progress;progress.CompletedTeams=progress.CompletedTeams or{};progress.CompletedTeams[teamId]=true
			local cleared=0;local tierId=tier and tier.Id or"";for completedId,done in progress.CompletedTeams do if done and string.find(tostring(completedId),tierId,1,true)then cleared+=1 end end
			if cleared>=5 and tierIndex>=(tonumber(progress.UnlockedDifficulty)or 1)then progress.UnlockedDifficulty=math.min(#VTRLiteConfig.CampaignDifficulties,tierIndex+1)end
			self.Publish(player,"Progression",self.Progression:GetClientData(player))
		end
	end
	if data then data.ObjectiveCompletedNow=false;data.WatchMode=true end
	return true,"AI vs AI match loaded.",data
end
function Service:ReturnToMenu(player:Player):boolean return self.Runtime:ReturnToMenu(player)end
return Service
