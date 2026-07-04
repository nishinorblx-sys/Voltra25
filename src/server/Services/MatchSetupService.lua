local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))
local MATCHUP_PANEL_DELAY = 0.85
--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TeleportService=game:GetService("TeleportService")
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
function Service.new(profiles:any,publish:(Player,string,any)->(),progression:any,runtime:any,rankedSquads:any?)
	local self=setmetatable({Profiles=profiles,Publish=publish,Progression=progression,Runtime=runtime,RankedSquads=rankedSquads,SoloTeleportConnections={}},Service)
	task.defer(function()
		for _,player in Players:GetPlayers()do self:HandleSoloCampaignTeleport(player)end
		table.insert(self.SoloTeleportConnections,Players.PlayerAdded:Connect(function(player)task.defer(function()self:HandleSoloCampaignTeleport(player)end)end))
	end)
	return self
end
function Service:_ensure(profile:any):any local setup=profile.MatchSetup;if not setup or not TeamDatabase.Get(setup.HomeTeamId)or not TeamDatabase.Get(setup.AwayTeamId)or(setup.HomeTeamId==setup.AwayTeamId and setup.MatchType~="Friendly")then local home,away=TeamDatabase.Teams[1],TeamDatabase.Teams[2];setup={MatchLength=6,Difficulty="Professional",MatchType="Objective Match",HomeTeamId=home.teamId,AwayTeamId=away.teamId,HomeKit="Home",AwayKit="Away",StadiumId="voltra_arena",Weather="Clear",Time="Evening",Completed=false,SavedAt=0,KitConflict=false,CampaignTeamId="",CampaignTier=0,CampaignReplay=false};profile.MatchSetup=setup end;setup.CampaignTeamId=setup.CampaignTeamId or"";setup.CampaignTier=tonumber(setup.CampaignTier)or 0;setup.CampaignReplay=setup.CampaignReplay==true;return setup end
function Service:_validate(setup:any):(boolean,string)
	if not contains(MatchConfig.MatchLengths,setup.MatchLength)then return false,"Invalid match length."end;if not contains(MatchConfig.Difficulties,setup.Difficulty)then return false,"Invalid difficulty."end;if not contains(MatchConfig.MatchTypes,setup.MatchType)then return false,"Invalid match type."end;if not contains(MatchConfig.Weather,setup.Weather)or not contains(MatchConfig.Times,setup.Time)then return false,"Invalid presentation settings."end
	local home,away=TeamDatabase.Get(setup.HomeTeamId),TeamDatabase.Get(setup.AwayTeamId);if not home or not away then return false,"Select two valid teams."end;if home.teamId==away.teamId and setup.MatchType~="Friendly"then return false,"Mirror matches are only available in Friendly mode."end;if not kit(home,setup.HomeKit)or not kit(away,setup.AwayKit)then return false,"Invalid kit selection."end;local venue=stadium(setup.StadiumId);if not venue or not contains(venue.WeatherSupport,setup.Weather)then return false,"Selected stadium does not support this weather."end;return true,"Match setup valid."
end
function Service:_isCampaignMatch(setup:any):boolean
	return type(setup)=="table" and type(setup.CampaignTeamId)=="string" and setup.CampaignTeamId~=""
end

local function clonePracticePlayer(player:any):any?
	if type(player)~="table"then return nil end
	local copy=table.clone(player)
	if type(player.appearance)=="table"then copy.appearance=table.clone(player.appearance)end
	if type(player.mainStats)=="table"then copy.mainStats=table.clone(player.mainStats)end
	if type(player.detailedStats)=="table"then copy.detailedStats=table.clone(player.detailedStats)end
	if type(player.positions)=="table"then copy.positions=table.clone(player.positions)end
	return copy
end

local function playerHasPosition(player:any,position:string):boolean
	if type(player)~="table"then return false end
	if player.bestPosition==position or player.Position==position or player.PositionSlot==position or player.FormationSlot==position or player.SquadSlot==position then return true end
	local positions=type(player.positions)=="table"and player.positions or{}
	return table.find(positions,position)~=nil
end

local function choosePracticeStriker(roster:any):any?
	local starting=type(roster)=="table"and type(roster.StartingXI)=="table"and roster.StartingXI or{}
	for _,candidate in starting do if candidate and(candidate.PositionSlot=="ST"or candidate.FormationSlot=="ST"or candidate.SquadSlot=="ST")then return clonePracticePlayer(candidate)end end
	for _,candidate in starting do if playerHasPosition(candidate,"ST")then return clonePracticePlayer(candidate)end end
	for _,candidate in starting do if candidate and not playerHasPosition(candidate,"GK")then return clonePracticePlayer(candidate)end end
	return nil
end

local function choosePracticeKeeper(roster:any):any?
	local starting=type(roster)=="table"and type(roster.StartingXI)=="table"and roster.StartingXI or{}
	local bench=type(roster)=="table"and type(roster.Bench)=="table"and roster.Bench or{}
	for _,candidate in starting do if playerHasPosition(candidate,"GK")then return clonePracticePlayer(candidate)end end
	for _,candidate in bench do if playerHasPosition(candidate,"GK")then return clonePracticePlayer(candidate)end end
	return nil
end

local function practiceBest(player:any):any
	return player and{{playerId=player.playerId,displayName=player.displayName,shortName=player.shortName,overall=player.overall,bestPosition=player.bestPosition}}or{}
end

function Service:_teleportSoloCampaign(player:Player,action:string):(boolean,string,any?)
	if RunService:IsStudio() or game.PrivateServerId~="" or player:GetAttribute("VTRAICampaignSoloServer")==true then return false,"",nil end
	local code=nil
	local ok,err=pcall(function()code=TeleportService:ReserveServer(game.PlaceId)end)
	if not ok or not code then return false,"Could not reserve a solo campaign server.",nil end
	local options=Instance.new("TeleportOptions")
	options.ReservedServerAccessCode=code
	local profile=self.Profiles:GetProfile(player)
	local setupSnapshot=profile and profile.MatchSetup and table.clone(profile.MatchSetup) or nil
	options:SetTeleportData({MatchMode="AICampaignSolo",Action=action,ReturnPlaceId=game.PlaceId,Setup=setupSnapshot,AutoStart=true,DirectIntro=true,Campaign=true})
	local sent,teleportErr=pcall(function()TeleportService:TeleportAsync(game.PlaceId,{player},options)end)
	if not sent then return false,tostring(teleportErr),nil end
	return true,"Teleporting to solo campaign server.",{Teleporting=true,SoloCampaign=true,Action=action}
end

function Service:_tagSoloCampaignSession(player:Player,session:any?)
	if not session or player:GetAttribute("VTRAICampaignSoloServer")~=true then return end
	session.PrivateAICampaignMatch=true
	session.ReturnPlaceId=tonumber(player:GetAttribute("VTRAICampaignReturnPlaceId")) or game.PlaceId
end

function Service:HandleSoloCampaignTeleport(player:Player):boolean
	local joinData=player:GetJoinData()
	local teleportData=joinData and joinData.TeleportData
	if type(teleportData)~="table" or teleportData.MatchMode~="AICampaignSolo" then return false end
	player:SetAttribute("VTRAICampaignSoloServer",true)
	player:SetAttribute("VTRAICampaignAutoStarting",true)
	player:SetAttribute("VTRAICampaignReturnPlaceId",tonumber(teleportData.ReturnPlaceId) or game.PlaceId)
	task.spawn(function()
		local started=os.clock()
		local action=tostring(teleportData.Action or "Manual")
		while player.Parent==Players and os.clock()-started<45 do
			local profile=self.Profiles:GetProfile(player)
			if profile then
				if type(teleportData.Setup)=="table" then
					profile.MatchSetup=table.clone(teleportData.Setup)
					profile.MatchSetup.Completed=true
				end
				local character=player.Character
				if character and character:FindFirstChildOfClass("Humanoid") then
					local ok,message,data
					if action=="Manage" then
						ok,message,data=self:WatchMatch(player)
					else
						ok,message,data=self:StartMatch(player)
					end
					if ok then
						player:SetAttribute("VTRAICampaignAutoStarting",false)
						player:SetAttribute("VTRAICampaignDirectIntro",true)
						return
					end
				end
			end
			task.wait(.35)
		end
		player:SetAttribute("VTRAICampaignAutoStarting",false)
	end)
	return true
end

function Service:GetClientData(player:Player):any?local profile=self.Profiles:GetProfile(player);if not profile then return nil end;local setup=self:_ensure(profile);local home,away=TeamDatabase.Get(setup.HomeTeamId),TeamDatabase.Get(setup.AwayTeamId);return{Setup=table.clone(setup),Teams={TeamDatabase.Summary(home),TeamDatabase.Summary(away)},Countries=TeamDatabase.GetCountries(),TeamCount=TeamDatabase.Count,Stadiums=MatchConfig.Stadiums,Options={MatchLengths=MatchConfig.MatchLengths,Difficulties=MatchConfig.Difficulties,MatchTypes=MatchConfig.MatchTypes,Weather=MatchConfig.Weather,Times=MatchConfig.Times,KitTypes=MatchConfig.KitTypes}}end
function Service:GetRoster(_player:Player,teamId:string):any?return TeamDatabase.GetRoster(teamId)end
function Service:GetTeams(_player:Player,country:any,league:any):any?if type(country)~="string"or#country>50 or type(league)~="string"or#league>60 then return nil end;return TeamDatabase.GetSummaries(country,league)end
function Service:Save(player:Player,payload:any):(boolean,string,any?)local profile=self.Profiles:GetProfile(player);if not profile or type(payload)~="table"then return false,"Profile unavailable.",nil end;local nextSetup=table.clone(self:_ensure(profile));for key,value in payload do if nextSetup[key]~=nil then nextSetup[key]=value end end;local valid,message=self:_validate(nextSetup);if not valid then return false,message,nil end;nextSetup.Completed=true;nextSetup.SavedAt=os.time();local home,away=TeamDatabase.Get(nextSetup.HomeTeamId),TeamDatabase.Get(nextSetup.AwayTeamId);nextSetup.KitConflict=colorDistance(home.kits[nextSetup.HomeKit].Primary,away.kits[nextSetup.AwayKit].Primary)<.35;profile.MatchSetup=nextSetup;if self.Profiles.Save then self.Profiles:Save(player)end;return true,"Match settings saved.",table.clone(nextSetup)end
function Service:StartMatch(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	if self:_isCampaignMatch(setup) and player:GetAttribute("VTRAICampaignSoloServer")~=true then
		local teleporting,teleportMessage,teleportData=self:_teleportSoloCampaign(player,"Manual")
		if teleporting then return true,teleportMessage,teleportData end
	end
	local homeRoster=nil
	local launchSetup=setup
	if self.RankedSquads then
		local ready,rosterMessage,roster=self.RankedSquads:GetRoster(player)
		if not ready then return false,rosterMessage,nil end
		homeRoster=roster
		launchSetup=table.clone(setup)
		launchSetup.HomeTeamId=roster.Team.teamId
		launchSetup.HomeKit="Home"
	end
	local success,text,data=self.Runtime:StartMatch(player,launchSetup,nil,nil,homeRoster,nil);if not success then return false,text,nil end;if data then data.AIMatchTeleport=true;data.MatchLaunchType="Manual"end
	local session=self.Runtime:GetSession(player);if session then
		self:_tagSoloCampaignSession(player,session)
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
	if self:_isCampaignMatch(setup) and player:GetAttribute("VTRAICampaignSoloServer")~=true then
		local teleporting,teleportMessage,teleportData=self:_teleportSoloCampaign(player,"Manage")
		if teleporting then return true,teleportMessage,teleportData end
	end
	local watchSetup=table.clone(setup);watchSetup.WatchMode=true;watchSetup.TeamTactics=profile.TeamTactics
	local homeRoster=nil
	if self.RankedSquads then
		local ready,text,roster=self.RankedSquads:GetRoster(player)
		if not ready then return false,text,nil end
		homeRoster=roster
		watchSetup.HomeTeamId=roster.Team.teamId
		watchSetup.HomeKit="Home"
	end
	local success,text,data=self.Runtime:StartMatch(player,watchSetup,nil,nil,homeRoster,nil);if not success then return false,text,nil end;if data then data.AIMatchTeleport=true;data.MatchLaunchType="Manage"end
	local session=self.Runtime:GetSession(player)
	self:_tagSoloCampaignSession(player,session)
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
			if player and typeof(player) == "Instance" and player:IsA("Player") then
				VTRPendingPackAnimation.Queue(player, packId)
			end
			local cleared=0;local tierId=tier and tier.Id or"";for completedId,done in progress.CompletedTeams do if done and string.find(tostring(completedId),tierId,1,true)then cleared+=1 end end
			local firstTierClear=cleared>=4
			local tierClearKey="campaign_tier_clear_"..tostring(tierId)
			local voltraGranted=false
			if firstTierClear and progress.RewardsClaimed[tierClearKey]~=true then
				progress.RewardsClaimed[tierClearKey]=true
				if self.Progression and self.Progression.Inventory and self.Progression.Inventory:AddPack(player,"voltra_pack","voltra_pack","CampaignTierClear",1)then packsGranted+=1;voltraGranted=true end
				if player and typeof(player) == "Instance" and player:IsA("Player") then
					VTRPendingPackAnimation.Queue(player, "voltra_pack")
				end
			end
			return{[player.UserId]={Title=firstTierClear and"CAMPAIGN TIER CLEAR"or"CAMPAIGN CLEAR",Coins=0,XP=0,Pack=(tier and tier.Reward or"Campaign Pack")..(voltraGranted and" + Voltra Pack"or""),BonusPack=voltraGranted and"VOLTRA PACK"or nil,VoltraPack=voltraGranted,LeagueClear=voltraGranted,PackId=packId,Packs=packsGranted}}
		end
		session.OnCompleted=function(ended:any)
			local current=self.Profiles:GetProfile(player);if not current or ended.World.HomeScore.Value<=ended.World.AwayScore.Value or replay then return end
			local progress=current.CampaignProgress or{UnlockedDifficulty=1,CompletedTeams={},RewardsClaimed={}};current.CampaignProgress=progress;progress.CompletedTeams=progress.CompletedTeams or{};progress.CompletedTeams[teamId]=true
			local cleared=0;local tierId=tier and tier.Id or"";for completedId,done in progress.CompletedTeams do if done and string.find(tostring(completedId),tierId,1,true)then cleared+=1 end end
			if cleared>=5 and tierIndex>=(tonumber(progress.UnlockedDifficulty)or 1)then progress.UnlockedDifficulty=math.min(#VTRLiteConfig.CampaignDifficulties,tierIndex+1)end
			if self.Profiles.Save then self.Profiles:Save(player)end
			self.Publish(player,"Progression",self.Progression:GetClientData(player))
		end
	end
	if data then data.ObjectiveCompletedNow=false;data.WatchMode=true end
	return true,"AI vs AI match loaded.",data
end
function Service:StartShootingPractice(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local setup=self:_ensure(profile)
	local homeRoster=nil
	if self.RankedSquads then
		local ready,rosterMessage,roster=self.RankedSquads:GetRoster(player)
		if not ready then return false,rosterMessage,nil end
		homeRoster=roster
	end
	homeRoster=homeRoster or TeamDatabase.GetRoster(setup.HomeTeamId)
	if not homeRoster then return false,"Your shooting practice roster could not be loaded.",nil end
	local striker=choosePracticeStriker(homeRoster)
	if not striker then return false,"Put a striker or outfield player in your Starting XI first.",nil end
	striker.FormationSlot="ST";striker.PositionSlot="ST";striker.SquadSlot=striker.SquadSlot or"ST";striker.VTRPracticeShooter=true
	local awayRoster=TeamDatabase.GetRoster(setup.AwayTeamId)
	if not awayRoster then
		local fallback=TeamDatabase.Teams[2]or TeamDatabase.Teams[1]
		awayRoster=fallback and TeamDatabase.GetRoster(fallback.teamId)or nil
	end
	local keeper=choosePracticeKeeper(awayRoster)
	if not keeper then return false,"A goalkeeper could not be loaded for shooting practice.",nil end
	keeper.FormationSlot="GK";keeper.PositionSlot="GK";keeper.SquadSlot="GK";keeper.bestPosition="GK";keeper.VTRPracticeKeeper=true
	local practiceSetup=table.clone(setup);practiceSetup.ShootingPractice=true;practiceSetup.PracticeMode="Shooting";practiceSetup.MatchType="Friendly";practiceSetup.Completed=true;practiceSetup.HomeTeamId=homeRoster.Team.teamId;practiceSetup.AwayTeamId=awayRoster.Team.teamId;practiceSetup.HomeKit="Home";practiceSetup.AwayKit="Away";practiceSetup.WatchMode=false;practiceSetup.CampaignTeamId=""
	local practiceHome={Team=homeRoster.Team,StartingXI={[10]=striker},Bench={},Reserves={},Formation="4-3-3",BestPlayers=practiceBest(striker)}
	local practiceAway={Team=awayRoster.Team,StartingXI={[1]=keeper},Bench={},Reserves={},Formation="4-3-3",BestPlayers=practiceBest(keeper)}
	local success,text,data=self.Runtime:StartMatch(player,practiceSetup,nil,nil,practiceHome,practiceAway)
	if not success then return false,text,nil end
	if data then data.AIMatchTeleport=true;data.MatchLaunchType="ShootingPractice";data.PracticeMode="Shooting";data.ObjectiveCompletedNow=false end
	return true,"Shooting practice loaded.",data
end
function Service:ReturnToMenu(player:Player):boolean return self.Runtime:ReturnToMenu(player)end
return Service
