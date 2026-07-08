local VTRPendingPackAnimation = require(script.Parent.Parent.Services:WaitForChild("PendingPackAnimationService"))
function VTRSecondHalfNeedsBothReady(readyCount, playerCount, timerExpired)
	if timerExpired then
		return true
	end
	return readyCount>=math.min(2, math.max(1, playerCount or 2))
end
--!strict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TeleportService=game:GetService("TeleportService")
local TweenService=game:GetService("TweenService")
local Config=require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local MovementTuning=require(ReplicatedStorage.VTR.Shared.MovementTuningConfig)
local MovementStatsResolver=require(ReplicatedStorage.VTR.Shared.MovementStatsResolver)
local Remotes=require(ReplicatedStorage.VTR.Shared.Remotes)
local PenaltyConfig=require(ReplicatedStorage.VTR.Shared.PenaltyConfig)
local VTRLiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local TeamDatabase=require(script.Parent.Parent.Data.TeamDatabase)
local TeamSpawnService=require(script.Parent.TeamSpawnService)
local PossessionService=require(script.Parent.PossessionService)
local BallService=require(script.Parent.BallService)
local GoalService=require(script.Parent.GoalService)
local AIService=require(script.Parent.AIService)
local StatsService=require(script.Parent.MatchStatsService)
local RefereeService=require(script.Parent.RefereeService)
local StadiumAnalyzer=require(script.Parent.StadiumAnalyzer)
local TeamControlService=require(script.Parent.TeamControlService)
local OutOfBoundsService=require(script.Parent.OutOfBoundsService)
local SetPieceService=require(script.Parent.SetPieceService)
local MatchClockService=require(script.Parent.MatchClockService)
local StaminaService=require(script.Parent.StaminaService)
local BallFactoryService=require(script.Parent.BallFactoryService)
local BallCollisionService=require(script.Parent.BallCollisionService)
local BallGroundingService=require(script.Parent.BallGroundingService)
local GoalShotPassThroughService=require(script.Parent.GoalShotPassThroughService)
local MatchAnimationService=require(script.Parent.MatchAnimationService)
local MatchCharacterFactory=require(script.Parent.MatchCharacterFactory)
local GoalkeeperService=require(script.Parent.GoalkeeperService)
local OffsideService=require(script.Parent.OffsideService)
local GameplayLinkDebugService=require(script.Parent.GameplayLinkDebugService)
local PitchConfig=require(script.Parent.PitchConfig)
local Service={};Service.__index=Service
local PREMATCH_PRESENTATION_DURATION=66.0
local PREMATCH_SKIP_LOCK_SECONDS=5.0
local GOAL_REPLAY_RESTART_TIMEOUT=12.0
local FINAL_CHANCE_MAX_SECONDS=24.0
local POST_FINAL_WHISTLE_RESULT_DELAY=2.0
local POST_MATCH_WORLD_CLEANUP_DELAY=8.0
local EXTRA_TIME_TOTAL_SECONDS=180
local EXTRA_TIME_HALF_PAUSE_SECONDS=30
local SHOOTING_PRACTICE_KEEPER_BASELINE={Reaction=1.75,DiveSpeed=1.15,Reach=1.65,Handling=1.65,SaveBias=1}
local function packRarity(definition:any):string
	local odds=definition and definition.Odds or{}
	if(tonumber(odds.Mythic)or 0)>0 then return"Mythic"end
	if(tonumber(odds.Icon)or 0)>0 then return"Icon"end
	if(tonumber(odds.Legendary)or 0)>0 then return"Legendary"end
	if(tonumber(odds.Elite)or 0)>0 then return"Elite"end
	if(tonumber(odds.Rare)or 0)>0 then return"Rare"end
	if(tonumber(odds.Gold)or 0)>0 then return"Gold"end
	if(tonumber(odds.Silver)or 0)>0 then return"Silver"end
	return"Common"
end
local function rankedPackChoices():{any}
	local choices={}
	for id,definition in Catalog.Packs do
		if definition.PriceCoins and definition.PriceCoins>0 and not string.find(id,"starter",1,true)and id~="voltage_standard"and id~="elite_electrum"then
			table.insert(choices,{PackId=id,Name=definition.Name,Rarity=packRarity(definition)})
		end
	end
	table.sort(choices,function(a,b)return tostring(a.PackId)<tostring(b.PackId)end)
	return choices
end
local function attackSignForSide(session:any,side:string):number
	local half=session.Clock and session.Clock:Payload().Half or 1
	if side=="Home"then return half>=2 and 1 or-1 end
	return half>=2 and-1 or 1
end
local function pitchOptionsForSession(session:any):any
	return{
		PitchCFrame=session.World.PitchCFrame,
		Width=session.World.Width,
		Length=session.World.Length,
		AttackSigns={
			Home=attackSignForSide(session,"Home"),
			Away=attackSignForSide(session,"Away"),
		},
	}
end
local function isFinalThirdForTeam(session:any,side:string,position:Vector3):boolean
	if not session or not session.World then return false end
	local pitchPosition=PitchConfig.WorldToTeamPitchPosition(position,side,pitchOptionsForSession(session))
	return pitchPosition.Z>=PitchConfig.Zones.FinalThird.ZMin
end
local function kickoffDebugEnabled():boolean
	return Workspace:GetAttribute("VTRKickoffDebug")~=false
end
local function debugKickoff(message:string,...:any)
	if kickoffDebugEnabled()then print("[VTR KICKOFF][Runtime] "..message,...)end
end
local function setServerNetworkOwner(part:BasePart?):boolean
	if not part or not part:IsA("BasePart")or not part:IsDescendantOf(Workspace)then return false end
	local ok=pcall(function()part:SetNetworkOwner(nil)end)
	return ok
end
local function broadcast(remote:RemoteEvent,session:any,payload:any)
	for _,participant in session.Players or{session.Player}do if participant.Parent==Players then remote:FireClient(participant,payload)end end
end
local function delayUnpaused(session:any,seconds:number,callback:() -> ())
	task.spawn(function()
		local remaining=math.max(0,seconds)
		while remaining>0 do
			if session.Ended then return end
			local step=math.min(.1,remaining)
			task.wait(step)
			if not session.Paused then remaining-=step end
		end
		if not session.Ended then callback()end
	end)
end
local function sanitizeRuntimeTactics(payload:any):any
	local identity=type(payload)=="table"and type(payload.Identity)=="string"and payload.Identity or"Balanced"
	if not VTRLiteConfig.TacticPresets[identity]then identity="Balanced"end
	local sliders={}
	local source=type(payload)=="table"and type(payload.Sliders)=="table"and payload.Sliders or{}
	local preset=VTRLiteConfig.TacticPresets[identity]or VTRLiteConfig.TacticPresets.Balanced
	for index,name in VTRLiteConfig.TacticSliderNames do
		sliders[name]=math.clamp(math.floor((tonumber(source[name])or preset[index]or 50)+.5),0,100)
	end
	return{Identity=identity,Sliders=sliders}
end
local function getGoalkeeper(team:{Model}?):Model?
	if not team then return nil end
	for _,model in team do
		if tostring(model:GetAttribute("position"))=="GK"then return model end
	end
	return nil
end
local function modelRoot(model:Model?):BasePart?
	return model and model:FindFirstChild("HumanoidRootPart")::BasePart?
end
local function easeInOut(t:number):number
	return t<.5 and 2*t*t or 1-((-2*t+2)^2)/2
end
local function lookAtFlat(position:Vector3,target:Vector3):CFrame
	local flat=Vector3.new(target.X,position.Y,target.Z)
	if (flat-position).Magnitude<.05 then flat=position+Vector3.zAxis end
	return CFrame.lookAt(position,flat)
end
local function safeReturnCFrame(state:any):CFrame
	if state and typeof(state.ReturnCFrame)=="CFrame" then return state.ReturnCFrame + Vector3.new(0,3,0) end
	local spawn=Workspace:FindFirstChildWhichIsA("SpawnLocation",true)
	if spawn then return spawn.CFrame + Vector3.new(0,5,0) end
	return CFrame.new(0,18,0)
end
local function markerCFrame(name:string):CFrame?
	local marker=Workspace:FindFirstChild(name) or Workspace:FindFirstChild(name,true)
	if not marker then return nil end
	if marker:IsA("BasePart")then return marker.CFrame end
	if marker:IsA("Model")then return marker:GetPivot()end
	if marker:IsA("Attachment")then return marker.WorldCFrame end
	return nil
end
local function colorFromKitValue(value:any,fallback:Color3):Color3
	if typeof(value)=="Color3"then return value end
	if type(value)=="string"then
		local ok,color=pcall(Color3.fromHex,value:gsub("#",""))
		if ok then return color end
	end
	return fallback
end
local function applyStandForFansColors(homeKit:any)
	if type(homeKit)~="table"then return end
	local primary=colorFromKitValue(homeKit.Primary,Color3.fromHex("B7FF1A"))
	local secondary=colorFromKitValue(homeKit.Secondary,Color3.fromHex("050505"))
	for _,instance in Workspace:GetDescendants()do
		if instance:IsA("BasePart")and instance.Name=="StandForFans"then
			local hasHighAttribute=instance:GetAttributes().High~=nil
			instance.Color=hasHighAttribute and primary or secondary
		end
	end
end
local function part(parent:Instance,name:string,size:Vector3,cframe:CFrame,color:Color3,collide:boolean?):Part local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cframe;p.Anchored=true;p.CanCollide=collide~=false;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Parent=parent;return p end
local function buildWorld(player:Player,setup:any):any
	local old=Workspace:FindFirstChild("VTRMatch_"..player.UserId);if old then old:Destroy()end
	local analysisOk,analysis=pcall(StadiumAnalyzer.Analyze,nil);if not analysisOk then warn("[VTR STADIUM ANALYZER] "..tostring(analysis));analysis=nil end
	local folder=Instance.new("Folder");folder.Name="VTRMatch_"..player.UserId;folder.Parent=Workspace;folder:SetAttribute("StadiumId",setup.StadiumId);folder:SetAttribute("Weather",setup.Weather);folder:SetAttribute("Time",setup.Time)
	local pitchCFrame:CFrame;local width:number;local length:number
	if analysis then
		pitchCFrame=analysis.PitchCFrame;width=analysis.Width;length=analysis.Length;folder:SetAttribute("UsesExistingStadium",true);StadiumAnalyzer.PrintReport(analysis);if Workspace:GetAttribute("VTRStadiumDebug")==true then StadiumAnalyzer.CreateDebugMarkers(analysis)end
	else
		local center=Vector3.new((player.UserId%100)*350,0,2200);pitchCFrame=CFrame.new(center+Vector3.new(0,.5,0));width=Config.Pitch.Width;length=Config.Pitch.Length
		part(folder,"Pitch",Vector3.new(width,1,length),CFrame.new(center),Color3.fromHex("173F19"));part(folder,"CenterLine",Vector3.new(width,.08,.45),pitchCFrame,Color3.fromHex("D9D9D9"),false)
		for _,z in{-length/2-10,length/2+10}do part(folder,"Stand",Vector3.new(width+30,24,14),pitchCFrame*CFrame.new(0,11.5,z),Color3.fromHex("111111"))end;for _,x in{-width/2-10,width/2+10}do part(folder,"Stand",Vector3.new(14,24,length+10),pitchCFrame*CFrame.new(x,11.5,0),Color3.fromHex("1B1B1B"))end
	end
	BallCollisionService.ApplyWorld(folder);BallCollisionService.ApplyGoalNets();local ball=BallFactoryService.Create(folder,pitchCFrame*CFrame.new(0,Config.Ball.Radius+.15,0))
	local score=Instance.new("Folder");score.Name="Score";score.Parent=folder;local home=Instance.new("IntValue");home.Name="Home";home.Parent=score;local away=home:Clone();away.Name="Away";away.Parent=score
	return{Folder=folder,Center=pitchCFrame.Position,PitchCFrame=pitchCFrame,Width=width,Length=length,Ball=ball,HomeScore=home,AwayScore=away,Analysis=analysis}
end
function Service.new()local action,state=Remotes.Create();local self=setmetatable({Action=action,State=state,Sessions={},PostMatchReturns={}},Service);action.OnServerEvent:Connect(function(player,payload)self:_action(player,payload)end);RunService.Heartbeat:Connect(function(dt)self:_step(dt)end);return self end
function Service:StartMatch(player:Player,setup:any,opponent:Player?,opponentSetup:any?,homeRoster:any?,awayRoster:any?):(boolean,string,any?)
	self:EndMatch(player,false);if opponent then self:EndMatch(opponent,false)end
	local players={player};if opponent then table.insert(players,opponent)end
	local humanoids:any={};for _,participant in players do local character=participant.Character;local hum=character and character:FindFirstChildOfClass("Humanoid");if not character or not hum then return false,participant.Name.." is not ready.",nil end;humanoids[participant]=hum end
	local finalSetup=table.clone(setup);if opponentSetup then finalSetup.AwayTeamId=opponentSetup.HomeTeamId;finalSetup.AwayKit=opponentSetup.AwayKit or"Away"end
	local home=homeRoster or TeamDatabase.GetRoster(finalSetup.HomeTeamId);local away=awayRoster or TeamDatabase.GetRoster(finalSetup.AwayTeamId);if not home or not away then return false,"Selected rosters are unavailable.",nil end
	local world=buildWorld(player,finalSetup);local teams,formation,kits=TeamSpawnService.Spawn(world.Folder,world.PitchCFrame,world.Width,world.Length,player,home,away,finalSetup);applyStandForFansColors(kits and kits.Home);local models={};for _,m in teams.Home do table.insert(models,m)end;for _,m in teams.Away do table.insert(models,m)end;BallCollisionService.ApplyPlayers(models);for _,m in models do m:SetAttribute("VTRSession",player.UserId);m:SetAttribute("VTRRankedMatch",opponent~=nil)end
	for _,group in{"Width","Depth","Press","Passing","Runs","Shape","Keeper"}do workspace:SetAttribute("TacticalDebug"..group,false)end;workspace:SetAttribute("TacticalDebug",false)
	local postGoalAnchorGuard=world.Ball:GetPropertyChangedSignal("Anchored"):Connect(function()
		local untilTime=tonumber(world.Ball:GetAttribute("VTRPostGoalPhysicsUntil"))or 0
		if untilTime>os.clock() and world.Ball.Anchored then
			local velocity=world.Ball:GetAttribute("VTRPostGoalVelocity")
			local angular=world.Ball:GetAttribute("VTRPostGoalAngularVelocity")
			world.Ball.Anchored=false
			if typeof(velocity)=="Vector3"then world.Ball.AssemblyLinearVelocity=velocity end
			if typeof(angular)=="Vector3"then world.Ball.AssemblyAngularVelocity=angular end
			setServerNetworkOwner(world.Ball)
		end
	end)
	local parkedReturnCFrames:any={}
	for index,participant in players do
		local character=participant.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")::BasePart?
		if character and root then
			parkedReturnCFrames[participant]=character:GetPivot()
			character:PivotTo(world.PitchCFrame*CFrame.new(index==1 and -10 or 10,-85,0))
			root.Anchored=true
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
			character:SetAttribute("VTRParked",true)
			character:SetAttribute("VTRCinematicParked",true)
		end
	end
	local stats=StatsService.new(models,world.PitchCFrame,world.Width,world.Length);local possession=PossessionService.new(world.Ball,self.State);local animations=MatchAnimationService.new(models);local ballService=BallService.new(world.Ball,possession,self.State,stats,models,animations);local teamControl=TeamControlService.new(self.State,teams,world.Ball,possession,ballService,world.PitchCFrame,world.Width,world.Length,animations);local duration=math.max(60,finalSetup.MatchLength*60);local practiceMode=finalSetup.ShootingPractice==true
	local session={Player=player,Players=players,SidePlayers={Home=player,Away=opponent},PlayerSides={[player]="Home"},PlayerState={},StepOwner=player,Ranked=opponent~=nil,ShootingPractice=practiceMode,Setup=finalSetup,World=world,Teams=teams,Kits=kits,Formation=formation,Models=models,Stats=stats,Possession=possession,BallService=ballService,Animations=animations,TeamControl=teamControl,Grounding=BallGroundingService.new(world.Ball,world.PitchCFrame,models),Clock=MatchClockService.new(duration),StaminaService=StaminaService.new(),Remaining=duration,Duration=duration,HalfTimeTriggered=false,Phase=practiceMode and"SHOOTING PRACTICE"or"PRE MATCH",Running=false,Ended=false,Accumulator=0,LastPositions={},MovementSpeeds={},BenchData={Home=home.Bench or{},Away=away.Bench or{}},UsedBench={Home={},Away={}},PauseSecondsByPlayer={},PauseRequester=nil,PauseResumeVotes={},PauseGrantIndex=0,PauseTimerAccumulator=0,PrematchSkipUnlockAt=os.clock()+PREMATCH_SKIP_LOCK_SECONDS,Connections={postGoalAnchorGuard}}
	session.LinkDebug=GameplayLinkDebugService.new()
	if opponent then session.PlayerSides[opponent]="Away"end
	for _,participant in players do local hum=humanoids[participant];session.PlayerState[participant]={Stamina=Config.Stamina.Maximum,Endurance=Config.Stamina.Maximum,SprintRequested=false,PreviousSpeed=hum.WalkSpeed,PreviousJump=hum.JumpPower,ReturnCFrame=parkedReturnCFrames[participant] or CFrame.new(0,8,0)};session.PauseSecondsByPlayer[participant]=60;hum.WalkSpeed=0;hum.JumpPower=0;participant:SetAttribute("VTRInMatch",true);self.Sessions[participant]=session end
	for _,model in models do local modelRoot=model:FindFirstChild("HumanoidRootPart")::BasePart?;if modelRoot then session.LastPositions[model]=modelRoot.Position end end
	session.Goals=GoalService.new(world.Ball,world.PitchCFrame,world.Width,world.Length,function(team)self:_goal(session,team)end);session.AI=AIService.new(teams,formation,world.PitchCFrame,world.Width,world.Length,finalSetup.Difficulty,world.Ball,possession,ballService,finalSetup.TeamTactics);session.Goalkeepers=GoalkeeperService.new(world.Ball,teams,world.PitchCFrame,world.Width,world.Length,ballService,animations,self.State,session.AI);session.SetPieces=SetPieceService.new(self.State,world,teams,formation,possession,teamControl,ballService,function()return session.Paused==true end);session.OutOfBounds=OutOfBoundsService.new(world.Ball,world.PitchCFrame,world.Width,world.Length,ballService,function(kind,restartTeam,location)self:_startSetPiece(session,kind,restartTeam,location)end)
	if session.AI and session.AI.SetManualTackleSides then
		local manualTackleSides:any={}
		if finalSetup.WatchMode~=true and not practiceMode then
			for _,side in session.PlayerSides do
				manualTackleSides[side]=true
			end
		end
		session.AI:SetManualTackleSides(manualTackleSides)
	end
	session.Referee=RefereeService.new(self.State,stats,function(restartTeam:string,location:Vector3,restartKind:string?,forcedTaker:Model?)if not session.Ended then self:_startSetPiece(session,restartKind or "FreeKick",restartTeam,location,forcedTaker)end end,world.PitchCFrame,world.Width,world.Length);ballService:SetReferee(session.Referee)
	session.Offside=OffsideService.new(self.State,stats,teams,world.PitchCFrame,function(restartTeam:string,location:Vector3)if not session.Ended then session.World.Ball:SetAttribute("VTRRestartDisplayKind","Offside");self:_startSetPiece(session,"FreeKick",restartTeam,location)end end);ballService:SetOffsideService(session.Offside)
	local homeSummary=TeamDatabase.Summary(home.Team);local awaySummary=TeamDatabase.Summary(away.Team);local watchMode=finalSetup.WatchMode==true
	if type(homeSummary)=="table"then
		homeSummary.Kits=home.Team.kits or home.Team.Kits or homeSummary.Kits or homeSummary.kits
		homeSummary.kits=homeSummary.Kits
		homeSummary.HomeKitData=kits and kits.Home or homeSummary.HomeKitData
		homeSummary.homeKitData=homeSummary.HomeKitData
	end
	if type(awaySummary)=="table"then
		awaySummary.Kits=away.Team.kits or away.Team.Kits or awaySummary.Kits or awaySummary.kits
		awaySummary.kits=awaySummary.Kits
		awaySummary.AwayKitData=kits and kits.Away or awaySummary.AwayKitData
		awaySummary.awayKitData=awaySummary.AwayKitData
	end
	ballService:SetFoulPolicy({HumanSides=watchMode and{}or{Home=true,Away=opponent~=nil}})
	if watchMode then
		for _,model in models do
			model:SetAttribute("controlledByUser",false)
			model:SetAttribute("aiControlled",true)
			model:SetAttribute("VTRUserId",nil)
		end
	end
	if not practiceMode then self:_startPrematchPresentation(session)end
	for _,participant in players do
		local side=session.PlayerSides[participant]
		local activePlayer=watchMode and(teams.Home[10]or teams.Home[1])or teamControl:Register(participant,side)
		local payload={Type="MatchStarted",MatchSessionId=world.Folder.Name,Ranked=session.Ranked,WatchMode=watchMode,PracticeMode=practiceMode,PrematchSkipDelay=practiceMode and 0 or PREMATCH_SKIP_LOCK_SECONDS,ControlledSide=side,Opponent=opponent and(opponent==participant and player.Name or opponent.Name)or(watchMode and"AI vs AI"or(practiceMode and"Goalkeeper"or"AI")),WorldName=world.Folder.Name,Ball=world.Ball,Home=home.Team.teamName,Away=away.Team.teamName,HomeSummary=homeSummary,AwaySummary=awaySummary,HomeLogo=home.Team.logo,AwayLogo=away.Team.logo,HomeFlagImage=home.Team.FlagImage or home.Team.flagImage or homeSummary.FlagImage or homeSummary.flagImage,AwayFlagImage=away.Team.FlagImage or away.Team.flagImage or awaySummary.FlagImage or awaySummary.flagImage,HomeBadgeIdentity=home.Team.BadgeIdentity or home.Team.badgeIdentity or homeSummary.BadgeIdentity or homeSummary.badgeIdentity,AwayBadgeIdentity=away.Team.BadgeIdentity or away.Team.badgeIdentity or awaySummary.BadgeIdentity or awaySummary.badgeIdentity,HomeColor=home.Team.colors.Primary,AwayColor=away.Team.colors.Primary,HomeTeamId=home.Team.teamId,AwayTeamId=away.Team.teamId,HomeKitData=kits and kits.Home or nil,AwayKitData=kits and kits.Away or nil,HomeFormation=home.Formation or home.Team.formation or finalSetup.HomeFormation or "4-3-3",AwayFormation=away.Formation or away.Team.formation or finalSetup.AwayFormation or "4-3-3",HomeSetup={Formation=home.Formation or home.Team.formation or "4-3-3"},AwaySetup={Formation=away.Formation or away.Team.formation or "4-3-3"},HomeLineup=home.StartingXI or{},AwayLineup=away.StartingXI or{},HomeBench=home.Bench or{},AwayBench=away.Bench or{},Duration=session.Remaining,Difficulty=finalSetup.Difficulty,ActivePlayer=activePlayer,ActivePlayerName=activePlayer and activePlayer.Name or nil,TeamModels=teams,PitchCFrame=world.PitchCFrame,PitchWidth=world.Width,PitchLength=world.Length}
		self.State:FireClient(participant,payload)
		for _,delayTime in{.55,1.35,2.75}do
			task.delay(delayTime,function()
				if participant.Parent and self.Sessions[participant]==session and not session.Ended and session.Phase=="PRE MATCH"then
					self.State:FireClient(participant,payload)
				end
			end)
		end
	end
	if practiceMode then task.defer(function()if self.Sessions[player]==session and not session.Ended then self:_resetShootingPractice(session,"START")end end)else task.delay(PREMATCH_PRESENTATION_DURATION,function()if self.Sessions[player]==session and not session.PrematchSkipped and session.Phase=="PRE MATCH"then self:_startSetPiece(session,"Kickoff","Home",world.PitchCFrame.Position)end end)end
	return true,practiceMode and"Shooting practice loaded."or(opponent and"Ranked 1v1 match loaded."or(watchMode and"AI vs AI match loaded."or"Playable AI match loaded.")),{Setup=finalSetup,Home=homeSummary,Away=awaySummary,WorldName=world.Folder.Name,Objective="PLAY YOUR FIRST MATCH",ObjectiveCompletedNow=not watchMode and not practiceMode,WatchMode=watchMode,PracticeMode=practiceMode}
end

function Service:StartRankedMatch(homePlayer:Player,awayPlayer:Player,homeSetup:any,awaySetup:any,homeRoster:any,awayRoster:any):(boolean,string,any?)
	return self:StartMatch(homePlayer,homeSetup,awayPlayer,awaySetup,homeRoster,awayRoster)
end

function Service:GetSession(player:Player):any?return self.Sessions[player]end
local kickoffFormation={
	Vector2.new(0,76),Vector2.new(-42,55),Vector2.new(-15,58),Vector2.new(15,58),Vector2.new(42,55),
	Vector2.new(-28,22),Vector2.new(0,30),Vector2.new(28,22),Vector2.new(-38,-22),Vector2.new(0,-34),Vector2.new(38,-22),
}

function Service:_syncPositions(session:any)
	for _,model in session.Models do local modelRoot=model:FindFirstChild("HumanoidRootPart")::BasePart?;if modelRoot then session.LastPositions[model]=modelRoot.Position end end
end

function Service:_ensurePresentationOfficials(session:any):{Model}
	if session.PresentationOfficials then return session.PresentationOfficials end
	local officials={}
	local team={teamId="voltra_officials",logo="V"}
	for index=1,3 do
		local kit=index==1 and{Primary="B7FF1A",Secondary="050505",Accent="FFFFFF",NumberColor="050505",Style="Lightning Trim"}or{Primary="FF7A00",Secondary="050505",Accent="B7FF1A",NumberColor="050505",Style="Lightning Trim"}
		local model=MatchCharacterFactory.Create({
			playerId="official_"..index,
			shortName=index==1 and "REF" or "AR"..tostring(index-1),
			displayName=index==1 and "VOLTRA REFEREE" or "VOLTRA ASSISTANT REFEREE",
			bestPosition="REF",
			overall=80,
			appearance={skinTone=index==1 and "Tan" or index==2 and "Light" or "MediumBrown",hairColor=index==2 and "Brown" or "Black",hairStyle=index==3 and "Shaved" or "BuzzCut"},
		},team,"Official",index,kit)
		model.Name="Official_"..index
		model:SetAttribute("VTROfficial",true)
		model:SetAttribute("VTRTeam","Officials")
		model.Parent=session.World.Folder
		table.insert(officials,model)
	end
	session.PresentationOfficials=officials
	session.OfficialAnimations=MatchAnimationService.new(officials)
	return officials
end

function Service:_destroyPresentationOfficials(session:any)
	if session.OfficialAnimations then session.OfficialAnimations:Destroy();session.OfficialAnimations=nil end
	for _,model in session.PresentationOfficials or{}do
		if model and model.Parent then model:Destroy()end
	end
	session.PresentationOfficials=nil
end

function Service:_presentationFrame(session:any,model:Model,index:number,side:string,stage:string):CFrame
	local sign=side=="Home"and 1 or-1
	local pitch=session.World.PitchCFrame
	local width=session.World.Width
	local length=session.World.Length
	local target=pitch.Position
	if stage=="Tunnel"then
		local tunnel=markerCFrame("Tunnel")
		if tunnel then
			local lane=side=="Home"and-5.1 or side=="Away"and 5.1 or index==2 and-3.1 or index==3 and 3.1 or 0
			local row=side=="Official"and(index==1 and 25.0 or 21.0)or index*1.45+(side=="Away"and .72 or 0)
			local world=(tunnel*CFrame.new(lane,3,row)).Position
			return lookAtFlat(world,(tunnel*CFrame.new(lane,3,row+10)).Position)
		end
		local row=index%2==0 and 1 or-1
		local localPos=Vector3.new(row*5.2,3,-length*.5-34-sign*(index*.55))
		if side=="Away"then localPos=Vector3.new(row*9.2,3,-length*.5-40-sign*(index*.55))end
		local world=pitch:PointToWorldSpace(localPos)
		return lookAtFlat(world,pitch:PointToWorldSpace(Vector3.new(0,3,-length*.5)))
	elseif stage=="Walkout"then
		local tunnel=markerCFrame("Tunnel")
		local anthem=markerCFrame("AnthemPoint")
		if tunnel and anthem then
			local lane=side=="Home"and-6.2 or side=="Away"and 6.2 or index==2 and-3.2 or index==3 and 3.2 or 0
			local followGap=side=="Official"and(index==1 and 19.0 or 15.0)or index*1.35
			local base=tunnel:Lerp(anthem,.36)
			local world=(base*CFrame.new(lane,3,followGap)).Position
			return lookAtFlat(world,(anthem*CFrame.new(lane,3,0)).Position)
		end
		local lane=side=="Home"and-5.5 or 5.5
		local localPos=Vector3.new(lane+(index%2==0 and 1.2 or-1.2),3,-length*.32-index*2.1)
		local world=pitch:PointToWorldSpace(localPos)
		return lookAtFlat(world,pitch:PointToWorldSpace(Vector3.new(lane,3,0)))
	elseif stage=="Lineup"then
		local anthem=markerCFrame("AnthemPoint")
		if anthem then
			if side=="Official"then
				local x=index==1 and 0 or index==2 and -3.1 or 3.1
				local world=(anthem*CFrame.new(x,3,0)).Position
				return lookAtFlat(world,(anthem*CFrame.new(x,3,-10)).Position)
			end
			local spacing=3.15
			local start=side=="Home"and -38 or 6
			local x=start+(index-1)*spacing
			local world=(anthem*CFrame.new(x,3,0)).Position
			return lookAtFlat(world,(anthem*CFrame.new(x,3,-10)).Position)
		end
		local x=-width*.42+(index-1)*(width*.84/10)
		local z=side=="Home"and-8 or 8
		local world=pitch:PointToWorldSpace(Vector3.new(x,3,z))
		return lookAtFlat(world,pitch:PointToWorldSpace(Vector3.new(0,3,0)))
	elseif stage=="Kickoff"then
		local formation=session.Formation and session.Formation[side]
		local point=formation and formation[index]or Vector2.zero
		local z=point.Y*sign
		local restartTeam="Home"
		local ownSign=sign
		if side==restartTeam and index==10 then
			local world=pitch:PointToWorldSpace(Vector3.new(0,3,ownSign*1.8))
			local face=pitch:PointToWorldSpace(Vector3.new(0,3,-ownSign*12))
			return lookAtFlat(world,face)
		elseif side==restartTeam and index==7 then
			local world=pitch:PointToWorldSpace(Vector3.new(8,3,ownSign*7.5))
			return lookAtFlat(world,pitch.Position)
		end
		local minDistance=side==restartTeam and 12 or 62
		z=ownSign*math.max(math.abs(z),minDistance)
		local world=pitch:PointToWorldSpace(Vector3.new(point.X,3,z))
		local face=pitch.Position
		return lookAtFlat(world,face)
	end
	local root=modelRoot(model)
	return root and root.CFrame or pitch
end

function Service:_movePresentationModel(session:any,model:Model,target:CFrame,duration:number,state:string)
	if session.Ended or session.PrematchSkipped then return end
	local root=modelRoot(model)
	if not root then return end
	root.Anchored=true
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
	model:SetAttribute("VTRPresentationState",state)
	model:SetAttribute("VTRForceIdle",nil)
	local animations=if model:GetAttribute("VTROfficial")==true then session.OfficialAnimations else session.Animations
	if animations then
		local animationName="Walk"
		if state=="LineupIdle"or state=="KickoffReady"then
			animationName=model:GetAttribute("position")=="GK"and"GoalkeeperIdle"or"Idle"
		end
		animations:_movement(model,animationName,1)
	end
	if duration <= 0 then
		model:PivotTo(target)
	else
		local tween=TweenService:Create(root,TweenInfo.new(duration,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{CFrame=target})
		session.PresentationTweens=session.PresentationTweens or{}
		session.PresentationTweens[tween]=true
		tween:Play()
		local finished=false
		local connection=tween.Completed:Connect(function()finished=true end)
		while model.Parent and not finished and not session.Ended and not session.PrematchSkipped do task.wait()end
		connection:Disconnect()
		if session.PresentationTweens then session.PresentationTweens[tween]=nil end
		tween:Cancel()
	end
	if session.Ended or session.PrematchSkipped then
		if animations then animations:ForceIdle(model)end
		return
	end
	if model.Parent then model:PivotTo(target)end
	if animations then animations:ForceIdle(model)end
end

function Service:_cancelPrematchPresentation(session:any)
	session.PresentationActive=false
	if session.PresentationTweens then
		for tween in session.PresentationTweens do
			pcall(function()tween:Cancel()end)
		end
		session.PresentationTweens=nil
	end
	self:_destroyPresentationOfficials(session)
	for _,model in session.Models do
		local root=modelRoot(model)
		if root then
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
		if session.Animations then session.Animations:ForceIdle(model)end
	end
end

function Service:_movePresentationStage(session:any,stage:string,duration:number)
	if session.Ended or session.PrematchSkipped then return end
	local jobs={}
	for _,side in{"Home","Away"}do
		for index,model in session.Teams[side]or{}do
			table.insert(jobs,task.spawn(function()
				self:_movePresentationModel(session,model,self:_presentationFrame(session,model,index,side,stage),duration,stage=="Kickoff"and"KickoffReady"or stage=="Lineup"and"LineupIdle"or"WalkForward")
			end))
		end
	end
	if stage~="Kickoff"then
		for index,model in self:_ensurePresentationOfficials(session)do
			table.insert(jobs,task.spawn(function()
				self:_movePresentationModel(session,model,self:_presentationFrame(session,model,index,"Official",stage),duration,stage=="Lineup"and"LineupIdle"or"WalkForward")
			end))
		end
	end
	local started=os.clock()
	while os.clock()-started<duration do
		if session.Ended or session.PrematchSkipped then return end
		task.wait(.05)
	end
	if session.Ended or session.PrematchSkipped then return end
	self:_syncPositions(session)
end

function Service:_teleportPresentationStage(session:any,stage:string,state:string)
	for _,side in{"Home","Away"}do
		for index,model in session.Teams[side]or{}do
			model:PivotTo(self:_presentationFrame(session,model,index,side,stage))
			local root=modelRoot(model)
			if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
			model:SetAttribute("VTRPresentationState",state)
			model:SetAttribute("VTRForceIdle",true)
			if session.Animations then session.Animations:ForceIdle(model)end
		end
	end
	if stage~="Kickoff"then
		for index,model in self:_ensurePresentationOfficials(session)do
			model:PivotTo(self:_presentationFrame(session,model,index,"Official",stage))
			local root=modelRoot(model)
			if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
			model:SetAttribute("VTRPresentationState",state)
			model:SetAttribute("VTRForceIdle",true)
			if session.OfficialAnimations then session.OfficialAnimations:ForceIdle(model)end
		end
	end
	self:_syncPositions(session)
end

function Service:_startPrematchPresentation(session:any)
	if session.PresentationActive then return end
	session.PresentationActive=true
	self:_ensurePresentationOfficials(session)
	for _,side in{"Home","Away"}do
		for index,model in session.Teams[side]or{}do
			model:PivotTo(self:_presentationFrame(session,model,index,side,"Tunnel"))
			local root=modelRoot(model)
			if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
			model:SetAttribute("VTRPresentationState","TunnelIdle")
			model:SetAttribute("VTRForceIdle",true)
			if session.Animations then session.Animations:ForceIdle(model)end
		end
	end
	for index,model in self:_ensurePresentationOfficials(session)do
		model:PivotTo(self:_presentationFrame(session,model,index,"Official","Tunnel"))
		local root=modelRoot(model)
		if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
		model:SetAttribute("VTRPresentationState","TunnelIdle")
		model:SetAttribute("VTRForceIdle",true)
		if session.OfficialAnimations then session.OfficialAnimations:ForceIdle(model)end
	end
	self:_syncPositions(session)
	task.spawn(function()
		task.wait(4.6)
		if session.Ended or session.PrematchSkipped then return end
		self:_movePresentationStage(session,"Walkout",11.4)
		if session.Ended or session.PrematchSkipped then return end
		self:_teleportPresentationStage(session,"Lineup","LineupIdle")
		task.delay(.35,function()
			if not session.Ended and not session.PrematchSkipped and session.PresentationActive then
				self:_teleportPresentationStage(session,"Lineup","LineupIdle")
			end
		end)
		task.wait(40.0)
		if session.Ended or session.PrematchSkipped then return end
		self:_teleportPresentationStage(session,"Kickoff","KickoffReady")
		self:_destroyPresentationOfficials(session)
		task.wait(4.8)
		if session.Ended or session.PrematchSkipped then return end
		for _,model in session.Models do
			local root=modelRoot(model)
			if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
			model:SetAttribute("VTRPresentationState","KickoffReady")
			model:SetAttribute("VTRForceIdle",true)
		end
		session.PresentationActive=false
		self:_syncPositions(session)
		task.delay(.35,function()
			if self.Sessions[session.Player]==session and not session.Ended and not session.PrematchSkipped and session.Phase=="PRE MATCH"then
				self:_startSetPiece(session,"Kickoff","Home",session.World.PitchCFrame.Position)
			end
		end)
	end)
end

function Service:_skipPrematch(session:any)
	if session.Ended or session.PrematchSkipped or session.PrematchSkipInProgress or session.Phase~="PRE MATCH"then return end
	session.PrematchSkipInProgress=true
	session.PrematchSkipped=true
	self:_cancelPrematchPresentation(session)
	self:_teleportPresentationStage(session,"Kickoff","KickoffReady")
	for _,model in session.Models do
		local root=modelRoot(model)
		if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
		model:SetAttribute("VTRPresentationState","KickoffReady")
		model:SetAttribute("VTRForceIdle",true)
	end
	self:_syncPositions(session)
	broadcast(self.State,session,{Type="PrematchSkip",Immediate=true})
	task.delay(.45,function()
		if self.Sessions[session.Player]==session and not session.Ended and session.Phase=="PRE MATCH"then
			self:_startSetPiece(session,"Kickoff","Home",session.World.PitchCFrame.Position)
		end
	end)
end

function Service:_setPieceRunup(session:any,model:Model?,actionType:string?)
	if not model or model:GetAttribute("VTRSetPieceTaker")~=true then return end
	local modelRoot=model:FindFirstChild("HumanoidRootPart")::BasePart?
	if not modelRoot then return end
	modelRoot.AssemblyLinearVelocity=Vector3.zero
	modelRoot.AssemblyAngularVelocity=Vector3.zero
	local ball=session.World and session.World.Ball
	if not ball then return end
	local toBall=Vector3.new(ball.Position.X-modelRoot.Position.X,0,ball.Position.Z-modelRoot.Position.Z)
	if toBall.Magnitude<1 then return end
	local direction=toBall.Unit
	local target=ball.Position-direction*1.85
	local targetPosition=Vector3.new(target.X,modelRoot.Position.Y,target.Z)
	local targetCFrame=CFrame.lookAt(targetPosition,Vector3.new(ball.Position.X,modelRoot.Position.Y,ball.Position.Z))
	if tostring(model:GetAttribute("VTRSetPieceKind")or"")=="Penalty" then
		model:PivotTo(targetCFrame)
		if session.Animations and actionType=="Shot" then session.Animations:PlayAction(model,"Shoot")end
		return
	end
	if actionType=="Shot" then
		model:SetAttribute("VTRForceIdle",nil)
		if session.Animations then session.Animations:_movement(model,"Jog",1.2)end
		local tween=TweenService:Create(modelRoot,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=targetCFrame})
		tween:Play()
		tween.Completed:Wait()
	else
		model:PivotTo(targetCFrame)
	end
end

function Service:_jumpFreeKickWall(session:any)
	if not session or not session.Models then return end
	for _,wallModel in session.Models do
		if wallModel:GetAttribute("VTRSetPieceWall")==true then
			local wallRoot=wallModel:FindFirstChild("HumanoidRootPart")::BasePart?
			local humanoid=wallModel:FindFirstChildOfClass("Humanoid")
			if wallRoot and humanoid then
				wallModel:SetAttribute("VTRBlocking",true)
				wallModel:SetAttribute("VTRWallJumpUntil",os.clock()+.95)
				wallModel:SetAttribute("VTRBlockUntil",os.clock()+1.1)
				wallRoot.AssemblyLinearVelocity=Vector3.new(0,34,0)
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end
end

function Service:_setPlayersFrozen(session:any,frozen:boolean)
	for _,model in session.Models do
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if humanoid then
			local keeperDiveLocked=model:GetAttribute("VTRKeeperDiveAnimationLocked")==true or model:GetAttribute("VTRGoalkeeperSaving")==true or model:GetAttribute("VTRGoalkeeperState")=="Diving" or model:GetAttribute("VTRGoalkeeperState")=="Falling"
			if frozen and keeperDiveLocked then
				model:SetAttribute("VTRFrozenIdle",nil)
				model:SetAttribute("VTRForceIdle",nil)
				humanoid:Move(Vector3.zero,false)
				continue
			end
			for _,state in{Enum.HumanoidStateType.FallingDown,Enum.HumanoidStateType.Ragdoll,Enum.HumanoidStateType.Physics,Enum.HumanoidStateType.PlatformStanding}do
				humanoid:SetStateEnabled(state,false)
			end
			if model:GetAttribute("VTRSentOff")==true then humanoid.WalkSpeed=0;humanoid:Move(Vector3.zero,false);model:SetAttribute("VTRForceIdle",true);continue end
			local exempt=false
			humanoid.WalkSpeed=frozen and 0 or Config.Movement.WalkSpeed
			if frozen then
				model:SetAttribute("VTRFrozenIdle",true)
				model:SetAttribute("VTRForceIdle",true)
				model:SetAttribute("VTRMoveMagnitude",0)
				model:SetAttribute("VTRSprinting",false)
				humanoid:Move(Vector3.zero,false)
				if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
				if session.Animations then session.Animations:ForceIdle(model)end
			elseif model:GetAttribute("VTRFrozenIdle")==true then
				model:SetAttribute("VTRFrozenIdle",nil)
				model:SetAttribute("VTRForceIdle",nil)
				humanoid.PlatformStand=false
				humanoid.Sit=false
				humanoid.AutoRotate=true
				humanoid:Move(Vector3.zero,false)
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
				if root then root.Anchored=false;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
			elseif root and root.Anchored then
				root.Anchored=false
				root.AssemblyLinearVelocity=Vector3.zero
				root.AssemblyAngularVelocity=Vector3.zero
				humanoid.PlatformStand=false
				humanoid.Sit=false
				humanoid.AutoRotate=true
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end
	end
end

function Service:_stabilizePlayers(session:any)
	for _,model in session.Models do
		if model:GetAttribute("VTRKeeperDiveAnimationLocked")==true or model:GetAttribute("VTRGoalkeeperSaving")==true then continue end
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if humanoid then
			for _,state in{Enum.HumanoidStateType.FallingDown,Enum.HumanoidStateType.Ragdoll,Enum.HumanoidStateType.Physics,Enum.HumanoidStateType.PlatformStanding}do
				humanoid:SetStateEnabled(state,false)
			end
			humanoid.PlatformStand=false
			humanoid.Sit=false
			humanoid.AutoRotate=true
			humanoid:Move(Vector3.zero,false)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			task.defer(function()
				if humanoid.Parent then humanoid:ChangeState(Enum.HumanoidStateType.Running)end
			end)
		end
		if root then
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
	end
end

function Service:_releasePlayersForLive(session:any)
	for _,model in session.Models do
		if model:GetAttribute("VTRSentOff")==true then continue end
		model:SetAttribute("VTRFrozenIdle",nil)
		model:SetAttribute("VTRForceIdle",nil)
		if model:GetAttribute("VTRPresentationState")~=nil then model:SetAttribute("VTRPresentationState",nil)end
		if model:GetAttribute("VTRSetPieceTaker")~=nil then model:SetAttribute("VTRSetPieceTaker",nil)end
		if model:GetAttribute("VTRSetPieceKind")~=nil then model:SetAttribute("VTRSetPieceKind",nil)end
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if humanoid then
			humanoid.PlatformStand=false
			humanoid.Sit=false
			humanoid.AutoRotate=true
			humanoid.WalkSpeed=Config.Movement.WalkSpeed
			humanoid:Move(Vector3.zero,false)
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		if root then
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
	end
end

function Service:_resetForSecondHalfKickoff(session:any)
	session.PendingReplayRestart=nil
	session.FinalChance=nil
	session.PendingAIPenalty=nil
	session.PendingGoalRestart=nil
	session.SetPieceAutoSeq=(session.SetPieceAutoSeq or 0)+1
	session.ManualPaused=false
	session.Paused=false
	session.PauseRequester=nil
	session.PauseResumeVotes={}
	if session.SetPieces and session.SetPieces.Cancel then session.SetPieces:Cancel()end
	if session.OutOfBounds and session.OutOfBounds.Reset then session.OutOfBounds:Reset()end
	if session.Goals and session.Goals.Unlock then session.Goals:Unlock()end
	if session.Possession then session.Possession:Reset()end
	if session.BallService then
		session.BallService:ClearGoalkeeperHoldState(nil)
		session.BallService.MotionKind="Loose"
		session.BallService.MotionStarted=os.clock()
		session.BallService.ShotPlan=nil
		session.BallService.PassPlan=nil
		session.BallService.PassTargetPoint=nil
		session.BallService.ExpectedReceiver=nil
		session.BallService.PendingCurve=nil
		if session.BallService.Curve then session.BallService.Curve:Stop()end
	end
	local ball=session.World and session.World.Ball
	if ball then
		ball.Anchored=false
		ball.CanCollide=true
		ball.CanTouch=true
		ball.Massless=false
		ball.AssemblyLinearVelocity=Vector3.zero
		ball.AssemblyAngularVelocity=Vector3.zero
		setServerNetworkOwner(ball)
		for _,attribute in{"VTRWorldPaused","VTRPauseSavedVelocity","VTRPauseSavedAngularVelocity","VTRPostGoalPhysicsUntil","VTRPostGoalVelocity","VTRPostGoalAngularVelocity","VTRGoalCalledAt","VTRGoalEntryVelocity","VTRGoalEntryAngularVelocity","VTRGoalEntryPosition","VTRGoalEntryNormal","VTRPenaltyShotActive","VTRGoalkeeperHeld","VTRGoalkeeperTracking","VTRPassTarget","VTRPassStartedAt","VTRPassTeam","VTRPassReceiver","VTRLobTarget","VTRLobPassActive","VTRSetPieceReady","VTRSetPieceKind","VTRSetPieceTeam","VTRCornerTarget"}do
			ball:SetAttribute(attribute,nil)
		end
	end
	for _,model in session.Models or{}do
		for _,attribute in{"VTRGoalkeeperHolding","VTRGoalkeeperHoldingSince","VTRKeeperMustDistributeUntil","VTRGoalkeeperSaving","VTRKeeperDiveAnimationLocked","VTRBlocking","VTRBlockUntil","VTRDribbleMoveUntil","VTRPostSkillVulnerableUntil","VTRStunnedUntil","VTRCannotRecoverBallUntil","VTRReceiverAssist","VTRPreparingReceive","VTRReceiveUntil","VTRReceiveTarget","VTRSetPieceWall","VTRWallJumpUntil","VTRPenaltyGuessSlot","VTRPenaltyGuessPoint","VTRSetPieceTaker","VTRForceIdle","VTRKickoffReady","VTRCornerTaker","VTRThrowInTaker"}do
			model:SetAttribute(attribute,nil)
		end
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if humanoid then
			humanoid.PlatformStand=false
			humanoid.Sit=false
			humanoid.AutoRotate=true
			humanoid:Move(Vector3.zero,false)
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		if root then
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
		session.MovementSpeeds[model]=0
	end
	self:_releasePlayersForLive(session)
	self:_stabilizePlayers(session)
	self:_syncPositions(session)
end

function Service:_practiceActors(session:any):(Model?,Model?)
	local shooter=session.PracticeShooter
	if not shooter or not shooter.Parent then shooter=session.Teams and session.Teams.Home and session.Teams.Home[1]or nil end
	local keeper=session.PracticeKeeper
	if not keeper or not keeper.Parent then keeper=getGoalkeeper(session.Teams and session.Teams.Away)or(session.Teams and session.Teams.Away and session.Teams.Away[1]or nil)end
	return shooter,keeper
end

function Service:_resetPracticeModel(model:Model?,frame:CFrame)
	if not model or not model.Parent then return end
	model:SetAttribute("VTRFrozenIdle",nil);model:SetAttribute("VTRForceIdle",nil);model:SetAttribute("VTRSetPieceTaker",nil);model:SetAttribute("VTRSetPieceKind",nil);model:SetAttribute("VTRCannotRecoverBallUntil",nil);model:SetAttribute("VTRStunnedUntil",nil)
	local humanoid=model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.PlatformStand=false;humanoid.Sit=false;humanoid.AutoRotate=true;humanoid.WalkSpeed=Config.Movement.WalkSpeed;humanoid:Move(Vector3.zero,false);humanoid:ChangeState(Enum.HumanoidStateType.Running)end
	model:PivotTo(frame)
	local root=modelRoot(model)
	if root then root.Anchored=false;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
end

function Service:_sanitizeShootingPracticeTuning(payload:any):any
	local source=type(payload)=="table"and payload or{}
	local keeper=type(source.Keeper)=="table"and source.Keeper or{}
	local shooting=type(source.Shooting)=="table"and source.Shooting or{}
	return{
		Keeper={
			Reaction=math.clamp(tonumber(keeper.Reaction)or 1,.05,1.75),
			DiveSpeed=math.clamp(tonumber(keeper.DiveSpeed)or 1,.05,1.65),
			Reach=math.clamp(tonumber(keeper.Reach)or 1,.05,1.65),
			Handling=math.clamp(tonumber(keeper.Handling)or 1,.05,1.65),
			SaveBias=math.clamp(tonumber(keeper.SaveBias)or 1,.05,1.65),
		},
		Shooting={
			Speed=math.clamp(tonumber(shooting.Speed)or 1,.55,1.55),
			Accuracy=math.clamp(tonumber(shooting.Accuracy)or 1,.55,1.55),
			Lift=math.clamp(tonumber(shooting.Lift)or 1.2,.55,1.55),
			Curve=math.clamp(tonumber(shooting.Curve)or 1,.55,1.55),
			FinesseCurve=math.clamp(tonumber(shooting.FinesseCurve)or 0,0,100),
			Power=math.clamp(tonumber(shooting.Power)or 1,.55,1.55),
		},
	}
end

function Service:_applyShootingPracticeTuning(session:any,tuning:any?)
	if not session or not session.ShootingPractice then return end
	local sanitized=self:_sanitizeShootingPracticeTuning(tuning or session.PracticeTuning)
	session.PracticeTuning=sanitized
	local shooter,keeper=self:_practiceActors(session)
	if keeper then
		keeper:SetAttribute("VTRPracticeKeeperReaction",math.clamp(sanitized.Keeper.Reaction*SHOOTING_PRACTICE_KEEPER_BASELINE.Reaction,.05,2.2))
		keeper:SetAttribute("VTRPracticeKeeperDiveSpeed",math.clamp(sanitized.Keeper.DiveSpeed*SHOOTING_PRACTICE_KEEPER_BASELINE.DiveSpeed,.05,2.2))
		keeper:SetAttribute("VTRPracticeKeeperReach",math.clamp(sanitized.Keeper.Reach*SHOOTING_PRACTICE_KEEPER_BASELINE.Reach,.05,2.2))
		keeper:SetAttribute("VTRPracticeKeeperHandling",math.clamp(sanitized.Keeper.Handling*SHOOTING_PRACTICE_KEEPER_BASELINE.Handling,.05,2.2))
		keeper:SetAttribute("VTRPracticeKeeperSaveBias",math.clamp(sanitized.Keeper.SaveBias*SHOOTING_PRACTICE_KEEPER_BASELINE.SaveBias,.05,2.2))
	end
	if shooter then
		shooter:SetAttribute("VTRPracticeShotSpeed",sanitized.Shooting.Speed)
		shooter:SetAttribute("VTRPracticeShotAccuracy",sanitized.Shooting.Accuracy)
		shooter:SetAttribute("VTRPracticeShotLift",sanitized.Shooting.Lift)
		shooter:SetAttribute("VTRPracticeShotCurve",sanitized.Shooting.Curve)
		shooter:SetAttribute("VTRPracticeFinesseCurve",sanitized.Shooting.FinesseCurve)
		shooter:SetAttribute("VTRPracticeShotPower",sanitized.Shooting.Power)
	end
end

function Service:_shootingPracticeLayout(session:any):any
	local pitch=session.World.PitchCFrame;local length=session.World.Length;local attackSign=attackSignForSide(session,"Home");local shotDistance=math.clamp(length*.29,56,82)
	return{
		Goal=pitch:PointToWorldSpace(Vector3.new(0,3,attackSign*(length*.5-6))),
		Ball=pitch:PointToWorldSpace(Vector3.new(0,Config.Ball.Radius+.22,attackSign*(length*.5-shotDistance))),
		Shooter=pitch:PointToWorldSpace(Vector3.new(0,3,attackSign*(length*.5-shotDistance-7))),
		Keeper=pitch:PointToWorldSpace(Vector3.new(0,3,attackSign*(length*.5-10))),
	}
end

function Service:_resetShootingPractice(session:any,reason:string?)
	if not session or not session.ShootingPractice or session.Ended then return end
	local shooter,keeper=self:_practiceActors(session)
	if not shooter or not keeper then return end
	session.PracticeShooter=shooter;session.PracticeKeeper=keeper;session.PracticeResetting=false;session.PracticeShotStartedAt=nil;session.PracticePeakShotSpeed=nil;session.PracticeShotResult=nil;session.FinalChance=nil;session.PendingReplayRestart=nil;session.PrematchSkipped=true;session.Phase="SHOOTING PRACTICE";session.Running=true
	local layout=self:_shootingPracticeLayout(session)
	self:_resetPracticeModel(shooter,lookAtFlat(layout.Shooter,layout.Goal))
	self:_resetPracticeModel(keeper,lookAtFlat(layout.Keeper,layout.Ball))
	self:_applyShootingPracticeTuning(session)
	keeper:SetAttribute("VTRGoalkeeperSaving",false);keeper:SetAttribute("VTRGoalkeeperHolding",nil);keeper:SetAttribute("VTRGoalkeeperHoldingSince",nil);keeper:SetAttribute("VTRGoalkeeperState","Ready");keeper:SetAttribute("VTRNoAutoPassUntil",nil);keeper:SetAttribute("VTRKeeperMustDistributeUntil",nil);keeper:SetAttribute("AIAssignment","GoalkeeperPosition")
	local ball=session.World.Ball
	if session.BallService then session.BallService:ReleaseGoalkeeperHold(keeper);session.BallService.MotionKind="Loose";session.BallService.MotionStarted=os.clock();session.BallService.ShotPlan=nil;session.BallService.PassPlan=nil;session.BallService.PassTargetPoint=nil;session.BallService.ExpectedReceiver=nil;session.BallService.OffsideCandidate=nil;session.BallService.OffsideCandidates=nil;session.BallService.OffsidePasser=nil;session.BallService.OffsidePassStartedAt=nil;session.BallService.LastPassTeam=nil;session.BallService.LastPasser=nil;if session.BallService.Curve then session.BallService.Curve:Stop()end end
	GoalShotPassThroughService.Clear(ball);BallCollisionService.ApplyBall(ball)
	ball.Anchored=false;ball.CanCollide=true;ball.CanTouch=true;ball.Massless=false;setServerNetworkOwner(ball);ball.CFrame=CFrame.new(layout.Ball);ball.AssemblyLinearVelocity=Vector3.zero;ball.AssemblyAngularVelocity=Vector3.zero
	for _,attribute in{"VTRPostGoalPhysicsUntil","VTRPostGoalVelocity","VTRPostGoalAngularVelocity","VTRGoalCalledAt","VTRGoalEntryVelocity","VTRGoalEntryAngularVelocity","VTRGoalEntryPosition","VTRGoalEntryNormal","VTRPenaltyShotActive","VTRGoalkeeperHeld","VTRGoalkeeperTracking","VTRPassTarget","VTRPassStartedAt","VTRPassTeam","VTRPassReceiver","VTRLobTarget","VTRLobPassActive"}do ball:SetAttribute(attribute,nil)end
	ball:SetAttribute("VTRMotionKind","Loose")
	if session.Possession then session.Possession:Reset();session.Possession:ForcePickup(shooter)end
	if session.TeamControl then if session.TeamControl.Receiving and session.TeamControl.Receiving.Clear then session.TeamControl.Receiving:Clear()end;session.TeamControl:SetActive(session.Player,shooter,"ShootingPractice")end
	if session.OutOfBounds and session.OutOfBounds.Reset then session.OutOfBounds:Reset()end;if session.Goals and session.Goals.Unlock then session.Goals:Unlock()end;if session.AI and session.AI.SetExternalPhase then session.AI:SetExternalPhase(nil)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(session.Clock and session.Clock:Payload().Half or 1)end
	self:_releasePlayersForLive(session);self:_syncPositions(session)
	broadcast(self.State,session,{Type="PracticeReset",Reason=reason or"RESET",Shooter=shooter,Keeper=keeper,Ball=ball,Tuning=session.PracticeTuning})
	broadcast(self.State,session,{Type="Phase",Phase="SHOOTING PRACTICE"})
end

function Service:_scheduleShootingPracticeReset(session:any,result:string,delaySeconds:number?)
	if not session or not session.ShootingPractice or session.Ended or session.PracticeResetting then return end
	session.PracticeResetting=true;session.PracticeShotResult=result;session.Running=false
	broadcast(self.State,session,{Type="PracticeShotResult",Result=result})
	task.delay(delaySeconds or.8,function()
		if session.Ended then return end
		self:_resetShootingPractice(session,result)
	end)
end

function Service:_practiceKeeperStoppedShot(session:any,motion:string,started:number):boolean
	local keeper=session.PracticeKeeper
	local ball=session.World and session.World.Ball
	if not keeper or not keeper.Parent or not ball then return false end
	local keeperRoot=modelRoot(keeper)
	if not keeperRoot then return false end
	local state=tostring(keeper:GetAttribute("VTRGoalkeeperState")or"")
	local saving=keeper:GetAttribute("VTRGoalkeeperSaving")==true or state=="Diving"or state=="Saved"or keeper:GetAttribute("VTRSaveTarget")~=nil
	if not saving then return false end
	local age=os.clock()-started
	if age<.14 then return false end
	local ballSpeed=ball.AssemblyLinearVelocity.Magnitude
	session.PracticePeakShotSpeed=math.max(tonumber(session.PracticePeakShotSpeed)or 0,ballSpeed)
	local peak=math.max(tonumber(session.PracticePeakShotSpeed)or 0,ballSpeed)
	local distance=(ball.Position-keeperRoot.Position).Magnitude
	if state=="Saved"then return true end
	if distance<=18 and(motion=="Deflection"or motion=="Save"or ballSpeed<=math.max(13,peak*.48))then return true end
	if distance<=10 and age>.28 and ballSpeed<=math.max(22,peak*.62)then return true end
	return false
end

function Service:_stepShootingPractice(session:any,dt:number)
	if not session or not session.ShootingPractice or session.PracticeResetting then return end
	local ball=session.World and session.World.Ball
	if not ball then return end
	local motion=session.BallService and session.BallService.MotionKind or tostring(ball:GetAttribute("VTRMotionKind")or"")
	local started=tonumber(session.PracticeShotStartedAt)
	if motion=="Shot"then
		started=started or os.clock()
		session.PracticeShotStartedAt=started
		session.PracticePeakShotSpeed=math.max(tonumber(session.PracticePeakShotSpeed)or 0,ball.AssemblyLinearVelocity.Magnitude)
		if self:_practiceKeeperStoppedShot(session,motion,started)then self:_scheduleShootingPracticeReset(session,"SAVE",.55)end
		return
	end
	if not started then return end
	if self:_practiceKeeperStoppedShot(session,motion,started)then self:_scheduleShootingPracticeReset(session,"SAVE",.55);return end
	local owner=session.Possession and session.Possession:GetOwner()or nil
	if motion=="Save"or motion=="KeeperClaim"or owner==session.PracticeKeeper or(session.PracticeKeeper and session.PracticeKeeper:GetAttribute("VTRGoalkeeperHolding")==true)then self:_scheduleShootingPracticeReset(session,"SAVE",.55);return end
	local localBall=session.World.PitchCFrame:PointToObjectSpace(ball.Position)
	local outside=math.abs(localBall.X)>session.World.Width*.58 or math.abs(localBall.Z)>session.World.Length*.56 or localBall.Y<-8
	if outside or os.clock()-started>4.2 or(os.clock()-started>1.4 and ball.AssemblyLinearVelocity.Magnitude<2.2)then self:_scheduleShootingPracticeReset(session,"MISS",.7)end
end

function Service:_pausePayload(session:any,paused:boolean,requester:Player?):any
	local gameSeconds=session.Clock and session.Clock:Payload().GameSeconds or 0
	local lineups={Home={},Away={}}
	for _,side in{"Home","Away"}do
		for _,model in session.Teams[side]or{}do
			table.insert(lineups[side],{
				Model=model,
				Name=model:GetAttribute("DisplayName")or model.Name,
				Position=model:GetAttribute("position")or"--",
				Number=model:GetAttribute("ShirtNumber")or 0,
				Overall=model:GetAttribute("overall")or 60,
				Rating=model:GetAttribute("VTRMatchRating")or 6,
				Stamina=model:GetAttribute("VTRStamina")or 100,
				PAC=model:GetAttribute("PAC")or 60,
				SHO=model:GetAttribute("SHO")or 60,
				PAS=model:GetAttribute("PAS")or 60,
				DRI=model:GetAttribute("DRI")or 60,
				DEF=model:GetAttribute("DEF")or 60,
				PHY=model:GetAttribute("PHY")or 60,
			})
		end
	end
	local benches={Home={},Away={}}
	for _,side in{"Home","Away"}do
		for index,entry in session.BenchData and session.BenchData[side] or{}do
			local copy=table.clone(entry)
			copy.BenchIndex=index
			copy.Used=session.UsedBench and session.UsedBench[side] and session.UsedBench[side][index] or false
			table.insert(benches[side],copy)
		end
	end
	local remaining=requester and session.PauseSecondsByPlayer and session.PauseSecondsByPlayer[requester] or 60
	return{Type="PauseState",Paused=paused,Requester=requester and requester.Name or nil,PauseRemaining=math.max(0,math.floor((remaining or 0)+.5)),Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,Stats=session.Stats:Serialize(session.World.HomeScore.Value,session.World.AwayScore.Value,gameSeconds),Lineups=lineups,Benches=benches}
end

function Service:_freezeWorldForPause(session:any)
	if session.PauseWorldFrozen==true then return end
	session.PauseWorldFrozen=true
	session.PauseFrozenParts={}
	session.PauseFrozenTracks={}
	local root=session.World and session.World.Folder
	if root then
		for _,inst in root:GetDescendants()do
			if inst:IsA("BasePart")then
				table.insert(session.PauseFrozenParts,{Part=inst,Anchored=inst.Anchored,Linear=inst.AssemblyLinearVelocity,Angular=inst.AssemblyAngularVelocity})
				inst.AssemblyLinearVelocity=Vector3.zero
				inst.AssemblyAngularVelocity=Vector3.zero
				inst.Anchored=true
			end
		end
	end
	local ball=session.World and session.World.Ball
	if ball and ball.Parent and not table.find(session.PauseFrozenParts,ball)then
		ball.AssemblyLinearVelocity=Vector3.zero
		ball.AssemblyAngularVelocity=Vector3.zero
		ball.Anchored=true
		ball:SetAttribute("VTRWorldPaused",true)
	end
	for _,model in session.Models or{}do
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:Move(Vector3.zero,false)
			humanoid.WalkSpeed=0
			model:SetAttribute("VTRFrozenIdle",true)
			model:SetAttribute("VTRForceIdle",true)
			local animator=humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _,track in animator:GetPlayingAnimationTracks()do
					local speed=1
					pcall(function()speed=track.Speed end)
					table.insert(session.PauseFrozenTracks,{Track=track,Speed=speed})
					pcall(function()track:AdjustSpeed(0)end)
				end
			end
		end
	end
end

function Service:_resumeWorldFromPause(session:any)
	if session.PauseWorldFrozen~=true then return end
	session.PauseWorldFrozen=false
	for _,entry in session.PauseFrozenParts or{}do
		local part=entry.Part
		if part and part.Parent then
			part.Anchored=entry.Anchored==true
			part.AssemblyLinearVelocity=typeof(entry.Linear)=="Vector3"and entry.Linear or Vector3.zero
			part.AssemblyAngularVelocity=typeof(entry.Angular)=="Vector3"and entry.Angular or Vector3.zero
		end
	end
	for _,entry in session.PauseFrozenTracks or{}do
		local track=entry.Track
		if track then pcall(function()track:AdjustSpeed(tonumber(entry.Speed)or 1)end)end
	end
	session.PauseFrozenParts=nil
	session.PauseFrozenTracks=nil
	local ball=session.World and session.World.Ball
	if ball and ball.Parent then ball:SetAttribute("VTRWorldPaused",nil)end
	for _,model in session.Models or{}do
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if humanoid and model:GetAttribute("VTRSentOff")~=true then
			model:SetAttribute("VTRFrozenIdle",nil)
			model:SetAttribute("VTRForceIdle",nil)
			humanoid.WalkSpeed=Config.Movement.WalkSpeed
			humanoid.PlatformStand=false
			humanoid.Sit=false
			humanoid.AutoRotate=true
			humanoid:Move(Vector3.zero,false)
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		if root and model:GetAttribute("VTRSentOff")~=true then
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
	end
end

function Service:_openPause(session:any,requester:Player?)
	if session.Ended or session.Paused then return end
	local remaining=requester and session.PauseSecondsByPlayer and session.PauseSecondsByPlayer[requester] or 60
	if remaining<=0 then
		if requester then self.State:FireClient(requester,{Type="Info",Message="No pause time available until the next 30-minute window.",Important=true})end
		return
	end
	session.Paused=true
	session.PauseQueued=false
	session.PauseRequestedBy=nil
	session.PauseRequester=requester
	session.PauseResumeVotes={}
	self:_freezeWorldForPause(session)
	self:_setPlayersFrozen(session,true)
	broadcast(self.State,session,self:_pausePayload(session,true,requester))
end

function Service:_resumePause(session:any)
	session.ManualPaused = false
	session.Paused = false
	session.PauseQueued=false
	session.PauseRequestedBy=nil
	session.PauseRequester=nil
	session.PauseResumeVotes={}
	self:_resumeWorldFromPause(session)
	self:_setPlayersFrozen(session,false)
	if not session.Ended then
		self:_releasePlayersForLive(session)
		self:_stabilizePlayers(session)
		self:_syncPositions(session)
		task.delay(.16,function()
			if not session.Ended and not session.Paused then
				self:_releasePlayersForLive(session)
				self:_stabilizePlayers(session)
				self:_syncPositions(session)
			end
		end)
	end
	broadcast(self.State,session,self:_pausePayload(session,false,nil))
end

function Service:_checkQueuedPause(session:any)
	if session.PauseQueued and not session.Paused then
		self:_openPause(session,session.PauseRequestedBy)
	end
end

function Service:_autoReleaseSetPiece(session:any,controller:Player?)
	if not session or session.Ended or session.Running then return end
	local phase=session.Phase
	if phase=="Corner" then
		local active=session.SetPieces and session.SetPieces.ActiveCorner
		if active and session.SetPieces._releaseCorner then
			local data=active.Data
			local target=data and data.PitchCFrame and data.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,(tonumber(data.GoalSign)or 1)*((tonumber(data.Length)or session.World.Length)*.5-18))) or session.World.Ball.Position
			session.SetPieces:_releaseCorner(active.Player,{Delivery="Cross",Power=.65,Target=target,ServerAI=true})
		end
	elseif phase=="FreeKick" then
		self:_releaseAIFieldRestart(session)
	elseif phase=="GoalKick" then
		self:_releaseGoalKickClearance(session,controller or session.StepOwner)
	elseif phase=="ThrowIn" then
		self:_releaseAIThrowIn(session)
	elseif phase=="Penalty" then
		self:_releaseAIPenalty(session)
	end
end

function Service:_startSetPiece(session:any,kind:string,restartTeam:string,location:Vector3,forcedTaker:Model?)
	if session.Ended then return end
	if session.FinalChance and session.Clock and(session.Clock:ShouldEndMatch()or session.Clock:ShouldHalfTime())then
		if kind=="FreeKick"or kind=="Penalty"then
			self:_holdFinalChanceForSetPiece(session,kind,restartTeam)
		else
			local target=session.FinalChance.Target or(session.Clock:ShouldHalfTime()and"HalfTime"or"FullTime")
			self:_clearFinalChance(session)
			if target=="HalfTime"then
				self:_halfTime(session)
			else
				self:EndMatch(session.StepOwner,true)
			end
			return
		end
	end
	if kind~="Kickoff"then session.Clock:Record(kind)end
	session.Running=false;session.Phase=kind;session.Possession:Reset();session.TeamControl.Receiving:Clear();session.AI:SetExternalPhase(kind)
	if kind=="Kickoff"then debugKickoff("start set piece","team",restartTeam,"running",session.Running,"phase",session.Phase)end
	self:_setPlayersFrozen(session,true)
	if session.Goalkeepers then session.Goalkeepers:Reset()end
	local watchMode=session.Setup and session.Setup.WatchMode==true
	local sideController=if watchMode then nil else session.SidePlayers and session.SidePlayers[restartTeam]
	local setPiecePlayer=sideController or session.Player
	local controller=sideController
	if session.SetPieces then
		session.SetPieces.Half = session.Clock and session.Clock:Payload().Half or 1
	end
	local currentHalf=session.Clock and session.Clock:Payload().Half or 1
	if session.AI and session.AI.SetHalf then session.AI:SetHalf(currentHalf)end
	if session.Referee and session.Referee.SetHalf then session.Referee:SetHalf(currentHalf)end
	if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(currentHalf)end
	if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(currentHalf)end
	session.SetPieceAutoSeq=(session.SetPieceAutoSeq or 0)+1
	local setPieceAutoSeq=session.SetPieceAutoSeq
	session.SetPieces:Start(setPiecePlayer,kind,restartTeam,location,function()
		if session.Ended then return end
		if kind=="Kickoff"then debugKickoff("ready callback","team",restartTeam,"owner",session.Possession:GetOwner()and session.Possession:GetOwner().Name or"nil","ballSpeed",math.floor(session.World.Ball.AssemblyLinearVelocity.Magnitude*10)/10)end
		if kind=="FreeKick"or kind=="Penalty"then self:_resumeFinalChanceAfterSetPiece(session)end
		session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session);task.delay(.18,function()if not session.Ended and session.Running then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end end)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY"})
		if kind=="Kickoff"then debugKickoff("phase broadcast","phase",session.Phase,"running",session.Running,"externalPhaseCleared",true)end
	end,sideController~=nil,forcedTaker)
	if kind=="Penalty"then
		session.PenaltyActionLockedUntil=os.clock()+2
	end
	if kind=="Penalty"and session.SidePlayers then
		local defendingSide=restartTeam=="Home"and"Away"or"Home"
		local defender=session.SidePlayers[defendingSide]
		local keeper=getGoalkeeper(session.Teams[defendingSide])
		if defender and defender~=controller and keeper then
			session.TeamControl:SetActive(defender,keeper,"PenaltyDefense")
			keeper:SetAttribute("VTRPenaltyUserKeeper",true)
			local goalSign=tonumber(session.SetPieces and session.SetPieces.RestartGoalSign)or(restartTeam=="Home"and-1 or 1)
			local goalPosition=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,goalSign*session.World.Length*.5))
			self.State:FireClient(defender,{Type="ActivePlayer",Model=keeper,Name=keeper:GetAttribute("DisplayName"),Position=keeper:GetAttribute("position"),Reason="PenaltyDefense",PenaltyLocation=session.World.Ball.Position,GoalPosition=goalPosition})
		end
	end
	
	if kind~="Kickoff"then
		local autoDelay=tonumber(workspace:GetAttribute("VTRSetPieceAutoDecisionDelay"))or 10
		delayUnpaused(session,autoDelay,function()
			if session.Ended or session.Running or session.SetPieceAutoSeq~=setPieceAutoSeq or session.Phase~=kind then return end
			self:_autoReleaseSetPiece(session,controller)
		end)
	end
	if kind=="Corner"and session.SetPieces.ActiveCorner then session.Animations:ForceIdle(session.SetPieces.ActiveCorner.Data.Taker)end
	if session.Setup and session.Setup.WatchMode==true or sideController==nil then
		if kind=="Penalty"then
			session.PendingAIPenalty={Player=controller,AttackingSide=restartTeam,At=os.clock()+2.35}
		elseif kind=="FreeKick"then
			delayUnpaused(session,1.6,function()if not session.Ended and not session.Running and session.Phase=="FreeKick"then self:_releaseAIFieldRestart(session)end end)
		elseif kind=="GoalKick"then
			delayUnpaused(session,1.2,function()if not session.Ended and not session.Running and session.Phase=="GoalKick"then self:_releaseGoalKickClearance(session,controller)end end)
		elseif kind=="ThrowIn"then
			delayUnpaused(session,1.0,function()if not session.Ended and not session.Running and session.Phase=="ThrowIn"then self:_releaseAIThrowIn(session)end end)
		end
	end
	self:_setPlayersFrozen(session,kind~="ThrowIn" and kind~="GoalKick")
	self:_syncPositions(session)
	self:_checkQueuedPause(session)
end

function Service:_allReplayAcks(session:any):boolean
	local hasActiveParticipant=false
	for _,participant in session.Players or{}do
		if participant.Parent==Players then
			hasActiveParticipant=true
			if not session.ReplayRestartAcks or session.ReplayRestartAcks[participant]~=true then
				return false
			end
		end
	end
	return hasActiveParticipant
end

function Service:_queueReplayRestart(session:any,kind:string,restartTeam:string,location:Vector3)
	session.PendingReplayRestart={Kind=kind,Team=restartTeam,Location=location,Ready=false,TimeoutAt=os.clock()+GOAL_REPLAY_RESTART_TIMEOUT}
	session.ReplayRestartAcks={}
	debugKickoff("replay restart hold queued","kind",kind,"team",restartTeam)
end

function Service:_resumeReplayRestart(session:any,reason:string)
	local pending=session.PendingReplayRestart
	if not pending or session.Ended or pending.Ready~=true then return end
	session.PendingReplayRestart=nil
	session.ReplayRestartAcks=nil
	debugKickoff("replay restart released","reason",reason,"kind",pending.Kind,"team",pending.Team)
	if session.FinalChanceGoalScored==true then
		session.FinalChanceGoalScored=nil
		local target=session.FinalChance and session.FinalChance.Target or "FullTime"
		self:_clearFinalChance(session)
		if target=="HalfTime"then
			self:_halfTime(session)
		else
			self:EndMatch(session.StepOwner,true)
		end
		return
	end
	self:_startSetPiece(session,pending.Kind,pending.Team,pending.Location)
end

function Service:_markReplayRestartReady(session:any)
	local pending=session.PendingReplayRestart
	if not pending or session.Ended then return end
	pending.Ready=true
	pending.TimeoutAt=os.clock()+GOAL_REPLAY_RESTART_TIMEOUT
	debugKickoff("replay restart ready","kind",pending.Kind,"team",pending.Team,"allAcked",self:_allReplayAcks(session))
	if self:_allReplayAcks(session)then self:_resumeReplayRestart(session,"client ack")end
end

function Service:_ackReplayFinished(session:any,player:Player)
	local pending=session.PendingReplayRestart
	if not pending or session.Ended then return end
	session.ReplayRestartAcks=session.ReplayRestartAcks or{}
	session.ReplayRestartAcks[player]=true
	debugKickoff("replay finished ack","player",player.Name,"ready",pending.Ready==true,"allAcked",self:_allReplayAcks(session))
	if pending.Ready==true and self:_allReplayAcks(session)then self:_resumeReplayRestart(session,"client ack")end
end

function Service:_goal(session:any,team:string)
	if not session.Running then return end
	local clockPayloadForGoal=session.Clock:Payload()
	if (clockPayloadForGoal.Half or 1)>=2 then
		-- GoalService resolves physical goal hitboxes as first-half scoring sides:
		-- AwayGoal -> Home scores, HomeGoal -> Away scores. After halftime the
		-- teams switch ends, so the credited scoring side must flip.
		team=team=="Home"and"Away"or"Home"
	end
	if session.ShootingPractice then
		if session.Goalkeepers and session.Goalkeepers.FinishActiveDiveAfterGoal then session.Goalkeepers:FinishActiveDiveAfterGoal()end
		session.Running=false
		GoalShotPassThroughService.Clear(session.World.Ball)
		self:_scheduleShootingPracticeReset(session,"GOAL",1.45)
		return
	end
	local currentGoalVelocity=session.World.Ball.AssemblyLinearVelocity
	local entryGoalVelocity=session.World.Ball:GetAttribute("VTRGoalEntryVelocity")
	local goalVelocity=typeof(entryGoalVelocity)=="Vector3"and entryGoalVelocity.Magnitude>currentGoalVelocity.Magnitude and entryGoalVelocity or currentGoalVelocity
	local entryAngularVelocity=session.World.Ball:GetAttribute("VTRGoalEntryAngularVelocity")
	local goalAngularVelocity=typeof(entryAngularVelocity)=="Vector3"and entryAngularVelocity or session.World.Ball.AssemblyAngularVelocity
	local entryPosition=session.World.Ball:GetAttribute("VTRGoalEntryPosition")
	local penaltyGoal=session.World.Ball:GetAttribute("VTRPenaltyShotActive")==true
	local goalPhysicsUntil=os.clock()+(penaltyGoal and 4.5 or 3.5)
	session.World.Ball:SetAttribute("VTRPostGoalPhysicsUntil",goalPhysicsUntil)
	session.World.Ball:SetAttribute("VTRGoalCalledAt",os.clock())
	session.World.Ball:SetAttribute("VTRPostGoalVelocity",goalVelocity)
	session.World.Ball:SetAttribute("VTRPostGoalAngularVelocity",goalAngularVelocity)
	GoalShotPassThroughService.Clear(session.World.Ball)
	BallCollisionService.ApplyScoredBall(session.World.Ball)
	session.World.Ball.Anchored=false
	setServerNetworkOwner(session.World and session.World.Ball)
	if session.Goalkeepers and session.Goalkeepers.FinishActiveDiveAfterGoal then session.Goalkeepers:FinishActiveDiveAfterGoal()end
	session.Running=false
	if session.FinalChance then session.FinalChanceGoalScored=true end
	self:_setPlayersFrozen(session,kind~="ThrowIn" and kind~="GoalKick")
	session.World.Ball.Anchored=false
	setServerNetworkOwner(session.World and session.World.Ball)
	session.World.Ball.AssemblyLinearVelocity=goalVelocity
	session.World.Ball.AssemblyAngularVelocity=goalAngularVelocity
	broadcast(self.State,session,{Type="GoalSoundPreview",Team=team})
	task.wait(.08)
	broadcast(self.State,session,{Type="GoalSoundPreview",Team=team})
	task.wait(.08)
	if team=="Home"then session.World.HomeScore.Value+=1 else session.World.AwayScore.Value+=1 end
	local scorerModel=session.BallService:GetLastTouchPlayer()
	local scorer=scorerModel and scorerModel:GetAttribute("DisplayName")or nil
	local ownGoal=scorerModel~=nil and scorerModel:GetAttribute("VTRTeam")~=team
	session.Stats:Goal(team,scorerModel,ownGoal,clockPayloadForGoal.GameSeconds)
	local cornerTeam=session.World.Ball:GetAttribute("VTRLastCornerTeam");local cornerAt=tonumber(session.World.Ball:GetAttribute("VTRCornerTakenAt"))or 0;if cornerTeam==team and os.clock()-cornerAt<10 then session.Stats:Add(team,"CornerGoals");broadcast(self.State,session,{Type="CornerObjective",Event="cornerGoal"})end
	session.Clock:Record("Goal")
	session.Possession:Release(nil,0)
	session.World.Ball.AssemblyLinearVelocity=goalVelocity
	session.World.Ball.AssemblyAngularVelocity=goalAngularVelocity
	local scoringPlayer=session.SidePlayers and session.SidePlayers[team];local customGoalMusic=scoringPlayer and tostring(scoringPlayer:GetAttribute("VTRCustomGoalMusicId")or"")or"";local customGoalMusicStart=scoringPlayer and tonumber(scoringPlayer:GetAttribute("VTRCustomGoalMusicStart"))or 0;local goalMusic=scoringPlayer and tostring(scoringPlayer:GetAttribute("VTRGoalMusic")or"")or"";local goalEffect=scoringPlayer and tostring(scoringPlayer:GetAttribute("VTRGoalEffect")or"")or"";local goalCelebration=scoringPlayer and tostring(scoringPlayer:GetAttribute("VTRCelebration")or"")or"";local canCelebrate=scorerModel and scorerModel:GetAttribute("VTRTeam")==team and goalCelebration~="";if canCelebrate then scorerModel:SetAttribute("VTRCelebrating",true);task.delay(6.2,function()if scorerModel and scorerModel.Parent then scorerModel:SetAttribute("VTRCelebrating",nil)end end)end;local clockPayload=clockPayloadForGoal;broadcast(self.State,session,{Type="Goal",Team=team,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,GameSeconds=clockPayload.GameSeconds,AddedMinutes=clockPayload.AddedMinutes,InAddedTime=clockPayload.InAddedTime,AddedElapsed=clockPayload.AddedElapsed,Scorer=scorer,ScorerModel=scorerModel,Penalty=penaltyGoal,GoalMusicId=customGoalMusic~=""and customGoalMusic or(goalMusic~=""and goalMusic or nil),GoalMusicStart=customGoalMusic~=""and customGoalMusicStart or nil,GoalEffectId=goalEffect~=""and goalEffect or nil,CelebrationId=canCelebrate and goalCelebration or nil})
	if penaltyGoal then task.delay(1.1,function()if session.World and session.World.Ball then session.World.Ball:SetAttribute("VTRPenaltyShotActive",nil)end end)end
	self:_checkQueuedPause(session)
	local restartTeam=team=="Home"and"Away"or"Home"
	self:_queueReplayRestart(session,"Kickoff",restartTeam,session.World.PitchCFrame.Position)
	task.spawn(function()
		local started=os.clock()
		local lastSpeed=goalVelocity.Magnitude
		local lastVelocity=goalVelocity
		local minWait=penaltyGoal and 3.6 or 2.8
		local maxWait=penaltyGoal and 4.5 or 3.5
		while not session.Ended and session.World and session.World.Ball and session.World.Ball.Parent do
			session.World.Ball.Anchored=false
			local elapsed=os.clock()-started
			local velocity=session.World.Ball.AssemblyLinearVelocity
			local speed=velocity.Magnitude
			if lastVelocity.Magnitude>8 and speed>5 and velocity:Dot(lastVelocity)<-8 then
				session.World.Ball.AssemblyLinearVelocity=velocity*.58
				session.World.Ball.AssemblyAngularVelocity*=.65
				velocity=session.World.Ball.AssemblyLinearVelocity
				speed=velocity.Magnitude
			end
			if elapsed<1.2 and lastSpeed>8 and speed<1 then
				session.World.Ball.AssemblyLinearVelocity=goalVelocity
				session.World.Ball.AssemblyAngularVelocity=goalAngularVelocity
				speed=goalVelocity.Magnitude
				velocity=goalVelocity
			end
			lastSpeed=speed
			lastVelocity=velocity
			if elapsed>=minWait then break end
			if elapsed>=maxWait then break end
			task.wait(.12)
		end
		if session.World and session.World.Ball then BallCollisionService.ApplyBall(session.World.Ball);session.World.Ball:SetAttribute("VTRPostGoalPhysicsUntil",nil);session.World.Ball:SetAttribute("VTRPostGoalVelocity",nil);session.World.Ball:SetAttribute("VTRPostGoalAngularVelocity",nil);session.World.Ball:SetAttribute("VTRGoalCalledAt",nil);session.World.Ball:SetAttribute("VTRGoalEntryVelocity",nil);session.World.Ball:SetAttribute("VTRGoalEntryAngularVelocity",nil);session.World.Ball:SetAttribute("VTRGoalEntryPosition",nil);session.World.Ball:SetAttribute("VTRGoalEntryNormal",nil)end
		if session.Ended then return end
		self:_markReplayRestartReady(session)
	end)
end

function Service:_halfTime(session:any)
	if session.HalfTimeTriggered or session.Ended then return end
	session.HalfTimeTriggered=true;session.Running=false;session.Phase="HALF TIME";session.Possession:Reset();self:_setPlayersFrozen(session,true)
	local gameSeconds=session.Clock:Payload().GameSeconds
	local payload=self:_pausePayload(session,true,nil)
	local halfTimeBreakSeconds=session.ExtraTimeActive==true and (tonumber(session.ExtraTimeHalfPauseSeconds) or EXTRA_TIME_HALF_PAUSE_SECONDS) or 45
	payload.Type="HalfTime";payload.HalfTime=true;payload.ExtraTime=session.ExtraTimeActive==true;payload.PauseRemaining=halfTimeBreakSeconds;payload.Home=session.World.HomeScore.Value;payload.Away=session.World.AwayScore.Value;payload.Stats=session.Stats:Serialize(session.World.HomeScore.Value,session.World.AwayScore.Value,gameSeconds)
	session.HalfTimeBreak=true;session.HalfTimeBreakEndsAt=os.clock()+halfTimeBreakSeconds;session.HalfTimeTimerAccumulator=0;session.HalfTimeResumeVotes={}
	broadcast(self.State,session,payload)
	task.delay(halfTimeBreakSeconds,function()if not session.Ended and session.HalfTimeBreak then self:_resumeHalfTime(session)end end)
end

function Service:_resumeHalfTime(session:any)
	if session.Ended or not session.HalfTimeBreak then return end
	if session.HalfTimeResuming then return end
	session.HalfTimeResuming=true
	session.HalfTimeBreak=false
	session.HalfTimeBreakEndsAt=nil
	session.HalfTimeResumeVotes={}
	session.ManualPaused=false
	session.Paused=false
	session.PauseRequester=nil
	session.PauseResumeVotes={}
	if session.World and session.World.Ball then
		session.World.Ball.Anchored=false
		session.World.Ball:SetAttribute("VTRWorldPaused",nil)
		session.World.Ball:SetAttribute("VTRPauseSavedVelocity",nil)
		session.World.Ball:SetAttribute("VTRPauseSavedAngularVelocity",nil)
		setServerNetworkOwner(session.World and session.World.Ball)
	end
	for _,model in session.Models or{}do
		model:SetAttribute("VTRPauseSavedVelocity",nil)
		model:SetAttribute("VTRPauseSavedAngularVelocity",nil)
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if root then
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
	end
	self:_resetForSecondHalfKickoff(session)
	session.SecondHalfStartedAt=os.clock()
	session.Clock:StartSecondHalf();if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end;if session.Referee and session.Referee.SetHalf then session.Referee:SetHalf(2)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end;if session.OutOfBounds and session.OutOfBounds.SetHalf then session.OutOfBounds:SetHalf(2)end;self:_startSetPiece(session,"Kickoff","Away",session.World.PitchCFrame.Position)
	broadcast(self.State,session,{Type=session.ExtraTimeActive==true and "ExtraTimeResume" or "HalfTimeResume",ExtraTime=session.ExtraTimeActive==true})
	task.delay(.35,function()
		if not session.Ended and session.HalfTimeResuming and session.Phase=="Kickoff" then
			broadcast(self.State,session,{Type=session.ExtraTimeActive==true and "ExtraTimeResume" or "HalfTimeResume",ExtraTime=session.ExtraTimeActive==true})
		end
	end)
	task.delay(4.5,function()
		if not session.Ended and session.HalfTimeResuming and session.Phase=="Kickoff" and not session.Running then
			self:_forceSecondHalfKickoffLive(session)
		end
	end)
	task.delay(7,function()
		if not session.Ended and session.HalfTimeResuming and not session.Running then
			self:_forceSecondHalfKickoffLive(session)
		end
		session.HalfTimeResuming=nil
	end)
end

function Service:_watchdogResetSecondHalf(session:any,player:Player?):boolean
	if not session or session.Ended then return false end
	local half=session.Clock and session.Clock.Payload and session.Clock:Payload().Half or 1
	if half<2 then return false end
	local clockPayload=session.Clock and session.Clock.Payload and session.Clock:Payload()
	local gameSeconds=clockPayload and tonumber(clockPayload.GameSeconds)or 0
	if gameSeconds>3000 then return false end
	if os.clock()-(tonumber(session.SecondHalfWatchdogResetAt)or 0)<8 then return false end
	session.SecondHalfWatchdogResetAt=os.clock()
	session.Running=false
	session.Paused=false
	session.ManualPaused=false
	session.HalfTimeBreak=false
	session.HalfTimeBreakEndsAt=nil
	session.HalfTimeResumeVotes={}
	session.HalfTimeResuming=true
	if session.Possession then session.Possession:Reset()end
	if session.TeamControl and session.TeamControl.Receiving then session.TeamControl.Receiving:Clear()end
	if session.SetPieces then session.SetPieces:Cancel()end
	if session.World and session.World.Ball then
		session.World.Ball.Anchored=false
		session.World.Ball.AssemblyLinearVelocity=Vector3.zero
		session.World.Ball.AssemblyAngularVelocity=Vector3.zero
		session.World.Ball:SetAttribute("VTRWorldPaused",nil)
		session.World.Ball:SetAttribute("VTRMotionKind",nil)
		setServerNetworkOwner(session.World and session.World.Ball)
	end
	self:_resetForSecondHalfKickoff(session)
	if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end
	if session.Referee and session.Referee.SetHalf then session.Referee:SetHalf(2)end
	if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end
	if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end
	if session.OutOfBounds and session.OutOfBounds.SetHalf then session.OutOfBounds:SetHalf(2)end
	broadcast(self.State,session,{Type=session.ExtraTimeActive==true and "ExtraTimeResume" or "HalfTimeResume",ExtraTime=session.ExtraTimeActive==true})
	self:_startSetPiece(session,"Kickoff","Away",session.World.PitchCFrame.Position)
	task.delay(6,function()
		if not session.Ended and session.HalfTimeResuming and not session.Running then
			self:_forceSecondHalfKickoffLive(session)
		end
		session.HalfTimeResuming=nil
	end)
	return true
end

function Service:_forceSecondHalfKickoffLive(session:any)
	if session.Ended then return end
	session.HalfTimeBreak=false
	session.HalfTimeBreakEndsAt=nil
	session.ManualPaused=false
	session.Paused=false
	local clockPayload=session.Clock and session.Clock.Payload and session.Clock:Payload()
	if session.Clock and clockPayload and (tonumber(clockPayload.Half)or 1)<2 then session.Clock:StartSecondHalf()end
	local setPieces=session.SetPieces
	local taker=setPieces and setPieces.RestartTaker
	local partner:Model?=nil
	local team=session.Teams and session.Teams.Away
	if team then
		for _,candidate in team do
			if candidate~=taker and tostring(candidate:GetAttribute("position")or"")~="GK"then partner=candidate;break end
		end
	end
	local ball=session.World and session.World.Ball
	if ball then
		ball.Anchored=false
		ball:SetAttribute("VTRWorldPaused",nil)
		ball:SetAttribute("VTRSetPieceReady",nil)
		setServerNetworkOwner(ball)
	end
	if taker and taker.Parent and ball then
		session.Possession:ForcePickup(taker)
		local takerRoot=modelRoot(taker)
		local partnerRoot=partner and modelRoot(partner)
		local target=partnerRoot and partnerRoot.Position or (takerRoot and takerRoot.Position+session.World.PitchCFrame:VectorToWorldSpace(Vector3.new(0,0,-18)) or session.World.PitchCFrame.Position)
		if takerRoot then session.BallService:Kick(taker,"Pass",target-takerRoot.Position,.18,partner,"Ground",(target-takerRoot.Position).Magnitude,target)end
	end
	if setPieces and setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
	if session.OutOfBounds and session.OutOfBounds.Reset then session.OutOfBounds:Reset()end
	if session.Goals and session.Goals.Unlock then session.Goals:Unlock()end
	session.Phase="IN PLAY"
	if session.AI and session.AI.SetExternalPhase then session.AI:SetExternalPhase(nil)end
	self:_setPlayersFrozen(session,false);self:_releasePlayersForLive(session);self:_stabilizePlayers(session);session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY"})
end

function Service:_isWorldCupKnockoutTiebreakMatch(session:any):boolean
	if not session or session.Ranked or session.ShootingPractice then
		return false
	end

	local setup=session.Setup or{}
	local mode=tostring(setup.MatchType or setup.MatchMode or setup.Mode or setup.Type or setup.Competition or "")
	local stage=tostring(setup.WorldCupStage or setup.Stage or setup.Round or setup.KnockoutRound or "")
	local lowerMode=string.lower(mode)
	local lowerStage=string.lower(stage)

	local worldCup=session.PrivateWorldCupMatch==true or setup.WorldCup==true or setup.WorldCupSolo==true or string.find(lowerMode,"worldcup",1,true)~=nil or string.find(lowerMode,"world cup",1,true)~=nil
	if not worldCup then
		return false
	end

	if setup.WorldCupKnockout==true or setup.Knockout==true or setup.IsKnockout==true then
		return true
	end

	if lowerStage~="" and not string.find(lowerStage,"group",1,true) then
		return true
	end

	return session.PrivateWorldCupMatch==true and setup.WorldCupGroup~=true and setup.GroupStage~=true
end

function Service:_scoreTied(session:any):boolean
	return session and session.World and session.World.HomeScore.Value==session.World.AwayScore.Value
end

function Service:_resetForExtraTimeKickoff(session:any)
	session.PendingReplayRestart=nil
	session.FinalChance=nil
	session.PendingAIPenalty=nil
	session.PendingGoalRestart=nil
	session.SetPieceAutoSeq=(session.SetPieceAutoSeq or 0)+1
	session.ManualPaused=false
	session.Paused=false
	session.PauseRequester=nil
	session.PauseResumeVotes={}
	session.HalfTimeTriggered=false
	session.HalfTimeBreak=false
	session.HalfTimeBreakEndsAt=nil
	session.HalfTimeResumeVotes={}
	session.HalfTimeResuming=nil
	if session.SetPieces and session.SetPieces.Cancel then session.SetPieces:Cancel()end
	if session.OutOfBounds and session.OutOfBounds.Reset then session.OutOfBounds:Reset()end
	if session.Goals and session.Goals.Unlock then session.Goals:Unlock()end
	if session.Possession then session.Possession:Reset()end
	if session.TeamControl and session.TeamControl.Receiving then session.TeamControl.Receiving:Clear()end
	if session.AI and session.AI.SetExternalPhase then session.AI:SetExternalPhase(nil)end
	if session.BallService then
		session.BallService:ClearGoalkeeperHoldState(nil)
		session.BallService.MotionKind="Loose"
		session.BallService.MotionStarted=os.clock()
		session.BallService.ShotPlan=nil
		session.BallService.PassPlan=nil
		session.BallService.PassTargetPoint=nil
		session.BallService.ExpectedReceiver=nil
		session.BallService.PendingCurve=nil
		if session.BallService.Curve then session.BallService.Curve:Stop()end
	end

	local ball=session.World and session.World.Ball
	if ball then
		ball.Anchored=false
		ball.CanCollide=true
		ball.CanTouch=true
		ball.Massless=false
		ball.CFrame=CFrame.new(session.World.PitchCFrame.Position+Vector3.new(0,Config.Ball.Radius+.15,0))
		ball.AssemblyLinearVelocity=Vector3.zero
		ball.AssemblyAngularVelocity=Vector3.zero
		setServerNetworkOwner(ball)
		for _,attribute in{"VTRWorldPaused","VTRPauseSavedVelocity","VTRPauseSavedAngularVelocity","VTRPostGoalPhysicsUntil","VTRPostGoalVelocity","VTRPostGoalAngularVelocity","VTRGoalCalledAt","VTRGoalEntryVelocity","VTRGoalEntryAngularVelocity","VTRGoalEntryPosition","VTRGoalEntryNormal","VTRPenaltyShotActive","VTRGoalkeeperHeld","VTRGoalkeeperTracking","VTRPassTarget","VTRPassStartedAt","VTRPassTeam","VTRPassReceiver","VTRLobTarget","VTRLobPassActive","VTRSetPieceReady","VTRSetPieceKind","VTRSetPieceTeam","VTRCornerTarget"}do
			ball:SetAttribute(attribute,nil)
		end
	end

	for _,model in session.Models or{}do
		for _,attribute in{"VTRGoalkeeperHolding","VTRGoalkeeperHoldingSince","VTRKeeperMustDistributeUntil","VTRGoalkeeperSaving","VTRKeeperDiveAnimationLocked","VTRBlocking","VTRBlockUntil","VTRDribbleMoveUntil","VTRPostSkillVulnerableUntil","VTRStunnedUntil","VTRCannotRecoverBallUntil","VTRReceiverAssist","VTRPreparingReceive","VTRReceiveUntil","VTRReceiveTarget","VTRSetPieceWall","VTRWallJumpUntil","VTRPenaltyGuessSlot","VTRPenaltyGuessPoint","VTRSetPieceTaker","VTRForceIdle","VTRKickoffReady","VTRCornerTaker","VTRThrowInTaker"}do
			model:SetAttribute(attribute,nil)
		end
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if humanoid then
			humanoid.PlatformStand=false
			humanoid.Sit=false
			humanoid.AutoRotate=true
			humanoid:Move(Vector3.zero,false)
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		if root then
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
		session.MovementSpeeds[model]=0
	end

	self:_releasePlayersForLive(session)
	self:_stabilizePlayers(session)
	self:_syncPositions(session)
end

function Service:_startWorldCupExtraTime(session:any):boolean
	if not self:_isWorldCupKnockoutTiebreakMatch(session) or not self:_scoreTied(session) or session.ExtraTimeStarted==true then
		return false
	end

	session.ExtraTimeStarted=true
	session.ExtraTimeActive=true
	session.ExtraTimeCompleted=false
	session.ExtraTimeHalfPauseSeconds=EXTRA_TIME_HALF_PAUSE_SECONDS
	session.Clock=MatchClockService.new(EXTRA_TIME_TOTAL_SECONDS)
	session.Running=false
	session.Phase="EXTRA TIME"
	session.Paused=false
	session.ManualPaused=false
	session.HalfTimeTriggered=false

	self:_resetForExtraTimeKickoff(session)
	broadcast(self.State,session,{Type="ExtraTime",Phase="EXTRA TIME",Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,Duration=EXTRA_TIME_TOTAL_SECONDS,HalfPause=EXTRA_TIME_HALF_PAUSE_SECONDS})
	task.delay(2.25,function()
		if session.Ended or not session.ExtraTimeActive then return end
		self:_startSetPiece(session,"Kickoff","Home",session.World.PitchCFrame.Position)
	end)

	return true
end

function Service:_takeShootoutPenalty(session:any,side:string,round:number):boolean
	local team=session.Teams and session.Teams[side]
	local taker=team and team[((round-1)%math.max(1,#team))+1]
	local overall=tonumber(taker and taker:GetAttribute("overall"))or 72
	local sho=tonumber(taker and taker:GetAttribute("SHO"))or overall
	local pressure=round>5 and -4 or 0
	local chance=math.clamp(.58+(sho-70)*.006+pressure*.01,.48,.86)
	return math.random()<chance
end

function Service:_startWorldCupPenaltyShootout(session:any):boolean
	if not self:_isWorldCupKnockoutTiebreakMatch(session) or not self:_scoreTied(session) or session.PenaltyShootoutStarted==true then
		return false
	end

	session.PenaltyShootoutStarted=true
	session.Running=false
	session.Paused=false
	session.ManualPaused=false
	session.Phase="PENALTY SHOOTOUT"
	self:_setPlayersFrozen(session,true)
	if session.AI and session.AI.SetExternalPhase then session.AI:SetExternalPhase("PENALTY SHOOTOUT")end
	if session.Possession then session.Possession:Reset()end
	if session.World and session.World.Ball then
		session.World.Ball.AssemblyLinearVelocity=Vector3.zero
		session.World.Ball.AssemblyAngularVelocity=Vector3.zero
		session.World.Ball.Anchored=true
		session.World.Ball:SetAttribute("VTRWorldPaused",true)
	end

	local homePens=0
	local awayPens=0
	local rounds={}

	for round=1,5 do
		local homeScored=self:_takeShootoutPenalty(session,"Home",round)
		local awayScored=self:_takeShootoutPenalty(session,"Away",round)
		if homeScored then homePens+=1 end
		if awayScored then awayPens+=1 end
		table.insert(rounds,{Round=round,Home=homeScored,Away=awayScored,HomeTotal=homePens,AwayTotal=awayPens})
		local remaining=5-round
		if homePens>awayPens+remaining or awayPens>homePens+remaining then
			break
		end
	end

	local round=5
	while homePens==awayPens and round<12 do
		round+=1
		local homeScored=self:_takeShootoutPenalty(session,"Home",round)
		local awayScored=self:_takeShootoutPenalty(session,"Away",round)
		if homeScored then homePens+=1 end
		if awayScored then awayPens+=1 end
		table.insert(rounds,{Round=round,Home=homeScored,Away=awayScored,HomeTotal=homePens,AwayTotal=awayPens})
	end

	if homePens==awayPens then
		if math.random()<.5 then homePens+=1 else awayPens+=1 end
	end

	session.PenaltyShootout={Home=homePens,Away=awayPens,Rounds=rounds}
	session.PenaltyShootoutWinner=homePens>awayPens and"Home"or"Away"
	session.World.Ball:SetAttribute("VTRWorldPaused",nil)

	broadcast(self.State,session,{Type="PenaltyShootout",Phase="PENALTY SHOOTOUT",Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,PenaltyHome=homePens,PenaltyAway=awayPens,Winner=session.PenaltyShootoutWinner,Rounds=rounds})
	task.delay(4.5,function()
		if not session.Ended then
			self:EndMatch(session.StepOwner,true)
		end
	end)

	return true
end

function Service:_resolveWorldCupKnockoutTiebreak(session:any):boolean
	if not self:_isWorldCupKnockoutTiebreakMatch(session) then
		return false
	end

	if not self:_scoreTied(session) then
		return false
	end

	if session.ExtraTimeStarted~=true then
		return self:_startWorldCupExtraTime(session)
	end

	session.ExtraTimeCompleted=true
	return self:_startWorldCupPenaltyShootout(session)
end

function Service:_penaltyTarget(session:any,shooter:Model,payload:any):(Vector3,string,number)
	local goalSign=tonumber(session.SetPieces and session.SetPieces.RestartGoalSign)or(tostring(shooter:GetAttribute("VTRTeam"))=="Home"and-1 or 1)
	local aim=typeof(payload.AimPosition)=="Vector3"and payload.AimPosition or session.World.Ball.Position
	local slot=PenaltyConfig.NormalizeSlot(payload.PenaltySlot)or PenaltyConfig.SlotFromGoalPoint(session.World.PitchCFrame,session.World.Length,goalSign,aim,session.World.Width)
	local target=PenaltyConfig.PointForSlot(session.World.PitchCFrame,session.World.Length,goalSign,slot,session.World.Width)
	local charge=math.clamp(tonumber(payload.Charge)or .55,0,1)
	shooter:SetAttribute("VTRPenaltySlot",slot)
	shooter:SetAttribute("VTRPenaltyMissHigh",false)
	return target,slot,charge
end

function Service:_setPenaltyKeeperGuess(session:any,defendingSide:string,slot:string?)
	local keeper=getGoalkeeper(session.Teams[defendingSide])
	if not keeper then return end
	local goalSign=tonumber(session.SetPieces and session.SetPieces.RestartGoalSign)or(defendingSide=="Home"and-1 or 1)
	local guess=PenaltyConfig.NormalizeSlot(slot)or PenaltyConfig.RandomSlot(Random.new())
	keeper:SetAttribute("VTRPenaltyGuessSlot",guess)
	keeper:SetAttribute("VTRPenaltyGuessPoint",PenaltyConfig.PointForSlot(session.World.PitchCFrame,session.World.Length,goalSign,guess,session.World.Width))
end

function Service:_latestPenaltyAim(session:any, taker:Model?): Vector3?
	local source = taker
	local player = nil
	if taker then
		for participant, model in session.TeamControl.Active do
			if model == taker then
				player = participant
				break
			end
		end
	end
	local updated = source and tonumber(source:GetAttribute("VTRPenaltyAimUpdatedAt")) or 0
	if player then
		updated = math.max(updated, tonumber(player:GetAttribute("VTRPenaltyAimUpdatedAt")) or 0)
	end
	if os.clock() - updated > 12 then return nil end
	local x = source and tonumber(source:GetAttribute("VTRPenaltyAimX")) or nil
	local y = source and tonumber(source:GetAttribute("VTRPenaltyAimY")) or nil
	local z = source and tonumber(source:GetAttribute("VTRPenaltyAimZ")) or nil
	if player then
		x = tonumber(player:GetAttribute("VTRPenaltyAimX")) or x
		y = tonumber(player:GetAttribute("VTRPenaltyAimY")) or y
		z = tonumber(player:GetAttribute("VTRPenaltyAimZ")) or z
	end
	if x and y and z then
		return Vector3.new(x, y, z)
	end
	return nil
end

function Service:_releaseAIPenalty(session:any)
	local pending = session.PendingAIPenalty
	local taker = pending and pending.Taker or session.SetPieces and session.SetPieces.RestartTaker
	local aim = self:_latestPenaltyAim(session, taker)
	if aim and taker and taker.Parent then
		local setPieces=session.SetPieces
		local attackingSide=tostring(setPieces and setPieces.RestartTeam or taker:GetAttribute("VTRTeam")or"Away")
		local defendingSide=attackingSide=="Home"and"Away"or"Home"
		local goalSign=tonumber(setPieces and setPieces.RestartGoalSign)or(attackingSide=="Home"and-1 or 1)
		local slot=PenaltyConfig.SlotFromGoalPoint(session.World.PitchCFrame,session.World.Length,goalSign,aim,session.World.Width)
		aim=PenaltyConfig.PointForSlot(session.World.PitchCFrame,session.World.Length,goalSign,slot,session.World.Width)
		taker:SetAttribute("VTRPenaltySlot",slot)
		taker:SetAttribute("VTRPenaltyMissHigh",false)
		local keeper=getGoalkeeper(session.Teams[defendingSide])
		if not keeper or keeper:GetAttribute("VTRPenaltyGuessSlot")==nil then
			self:_setPenaltyKeeperGuess(session,defendingSide,nil)
		end
		session.Possession:ForcePickup(taker)
		local direction = aim - ((taker:FindFirstChild("HumanoidRootPart") :: BasePart).Position)
		session.World.Ball:SetAttribute("VTRPenaltyShotActive",true)
		session.BallService:Kick(taker, "Shot", direction, 1, nil, "Penalty", direction.Magnitude, aim)
		if session.SetPieces and session.SetPieces.ReleaseRestartTaker then session.SetPieces:ReleaseRestartTaker() end
		self:_resumeFinalChanceAfterSetPiece(session)
		session.PendingAIPenalty = nil
		session.OutOfBounds:Reset()
		session.Goals:Unlock()
		session.Phase = "IN PLAY"
		session.AI:SetExternalPhase(nil)
		self:_setPlayersFrozen(session, session.Paused == true)
		if not session.Paused then self:_releasePlayersForLive(session); self:_stabilizePlayers(session) end
		session.Running = true
		self:_syncPositions(session)
		broadcast(self.State, session, {Type = "Phase", Phase = "IN PLAY"})
		return
	end
	local setPieces=session.SetPieces
	local taker=setPieces and setPieces.RestartTaker
	local takerRoot=taker and taker:FindFirstChild("HumanoidRootPart")::BasePart?
	if not taker or not takerRoot then return end
	local attackingSide=tostring(setPieces.RestartTeam or taker:GetAttribute("VTRTeam")or"Away")
	local defendingSide=attackingSide=="Home"and"Away"or"Home"
	local keeper=getGoalkeeper(session.Teams[defendingSide])
	if not keeper or keeper:GetAttribute("VTRPenaltyGuessSlot")==nil then
		self:_setPenaltyKeeperGuess(session,defendingSide,nil)
	end
	local slot=PenaltyConfig.RandomSlot(Random.new())
	local target=PenaltyConfig.PointForSlot(session.World.PitchCFrame,session.World.Length,tonumber(setPieces.RestartGoalSign)or(attackingSide=="Home"and-1 or 1),slot,session.World.Width)
	taker:SetAttribute("VTRPenaltySlot",slot)
	taker:SetAttribute("VTRPenaltyMissHigh",false)
	session.World.Ball.Anchored=false
	setServerNetworkOwner(session.World and session.World.Ball)
	session.Possession:ForcePickup(taker)
	self:_setPieceRunup(session,taker,"Shot")
	session.World.Ball:SetAttribute("VTRPenaltyShotActive",true)
	session.BallService:Kick(taker,"Shot",target-takerRoot.Position,.62,nil,nil,nil,target)
	if setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
	self:_resumeFinalChanceAfterSetPiece(session)
	session.PendingAIPenalty=nil
	session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=true})
end

function Service:_releaseAIFieldRestart(session:any)
	local setPieces=session.SetPieces
	local taker=setPieces and setPieces.RestartTaker
	local takerRoot=modelRoot(taker)
	if not taker or not takerRoot or not session.World or not session.World.Ball then return end
	session.World.Ball.Anchored=false
	setServerNetworkOwner(session.World and session.World.Ball)
	session.Possession:ForcePickup(taker)
	if session.BallService and session.BallService.Last then session.BallService.Last[taker]={}end
	local mode=setPieces.RestartMode
	local goalSign=tonumber(setPieces.RestartGoalSign)or(tostring(taker:GetAttribute("VTRTeam"))=="Home"and-1 or 1)
	local released=false
	if mode=="DirectShotFreeKick" then
		local goalPosition=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,goalSign*session.World.Length*.5))
		local freeKickDistance=Vector3.new(goalPosition.X-takerRoot.Position.X,0,goalPosition.Z-takerRoot.Position.Z).Magnitude
		if freeKickDistance<=200 then
			local localTaker=session.World.PitchCFrame:PointToObjectSpace(takerRoot.Position)
			local side=localTaker.X>=0 and -1 or 1
			if math.random()<.5 then side=-side end
			local top=math.random()<.52
			local target=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(side*11,top and 6.2 or 2.45,goalSign*session.World.Length*.5))
			taker:SetAttribute("VTRFreeKickGoalChance",.3)
			taker:SetAttribute("VTRFreeKickGoalChanceUntil",os.clock()+4)
			taker:SetAttribute("VTRFreeKickDirectShot",true)
			taker:SetAttribute("VTRFreeKickShotDistance",freeKickDistance)
			taker:SetAttribute("VTRFreeKickCurve",side*.85)
			taker:SetAttribute("VTRFreeKickLift",top and .75 or -.15)
			if self._setPieceRunup then self:_setPieceRunup(session,taker,"Shot")end
			released=session.BallService:Kick(taker,"Shot",target-takerRoot.Position,.72,nil,nil,nil,target)
			if not released then
				if session.BallService and session.BallService.Last then session.BallService.Last[taker]={}end
				released=session.BallService:Kick(taker,"Shot",target-takerRoot.Position,.72,nil,nil,nil,target)
			end
			if setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
			self:_resumeFinalChanceAfterSetPiece(session)
			session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=false})
			return
		end
	end
	local team=tostring(taker:GetAttribute("VTRTeam")or"Home")
	local opponents=session.Teams[team=="Home"and"Away"or"Home"]or{}
	local bestReceiver:Model?=nil
	local bestScore=-math.huge
	local fallbackReceiver:Model?=nil
	local fallbackDistance=math.huge
	for _,candidate in session.Teams[team]or{}do
		if candidate~=taker and candidate:GetAttribute("VTRSentOff")~=true and tostring(candidate:GetAttribute("position")or"")~="GK"then
			local candidateRoot=modelRoot(candidate)
			if candidateRoot then
				local localCandidate=session.World.PitchCFrame:PointToObjectSpace(candidateRoot.Position)
				local localTaker=session.World.PitchCFrame:PointToObjectSpace(takerRoot.Position)
				local distance=(candidateRoot.Position-takerRoot.Position).Magnitude
				local forwardGain=goalSign*(localCandidate.Z-localTaker.Z)
				local nearestOpponent=math.huge
				for _,opponent in opponents do
					local opponentRoot=modelRoot(opponent)
					if opponentRoot then nearestOpponent=math.min(nearestOpponent,(opponentRoot.Position-candidateRoot.Position).Magnitude)end
				end
				local openBonus=math.clamp((nearestOpponent-7)/24,0,1)*34
				local role=tostring(candidate:GetAttribute("position")or"")
				local roleBonus=(role=="ST"or role=="CAM"or role=="CM"or role=="W"or role=="LW"or role=="RW")and 10 or 0
				local shortFreeKickBonus=mode=="DirectShotFreeKick" and distance<58 and 18 or 0
				local score=forwardGain*.18-math.abs(distance-(mode=="DirectShotFreeKick"and 32 or 62))*.22+(tonumber(candidate:GetAttribute("overall"))or 60)*.08+openBonus+roleBonus+shortFreeKickBonus
				if distance>10 and distance<fallbackDistance then
					fallbackDistance=distance
					fallbackReceiver=candidate
				end
				if distance>12 and distance<132 and nearestOpponent>6 and score>bestScore then
					bestScore=score
					bestReceiver=candidate
				end
			end
		end
	end
	bestReceiver=bestReceiver or fallbackReceiver
	local receiverRoot=bestReceiver and modelRoot(bestReceiver)
	if receiverRoot then
		local receiverLocal=session.World.PitchCFrame:PointToObjectSpace(receiverRoot.Position)
		local lead=math.clamp((receiverRoot.Position-takerRoot.Position).Magnitude*.08,3,10)
		local targetLocal=Vector3.new(receiverLocal.X,.15,receiverLocal.Z+goalSign*lead)
		targetLocal=Vector3.new(math.clamp(targetLocal.X,-session.World.Width*.5+8,session.World.Width*.5-8),targetLocal.Y,math.clamp(targetLocal.Z,-session.World.Length*.5+10,session.World.Length*.5-10))
		local target=session.World.PitchCFrame:PointToWorldSpace(targetLocal)
		local offset=target-takerRoot.Position
		local distance=math.max(offset.Magnitude,1)
		local passKind=distance>72 and"Lofted"or"Ground"
		released=session.BallService:Kick(taker,"Pass",offset,math.clamp(distance/(passKind=="Lofted"and 118 or 95),.24,.66),bestReceiver,passKind,distance,target)
		if not released then
			if session.BallService and session.BallService.Last then session.BallService.Last[taker]={}end
			released=session.BallService:Kick(taker,"Pass",offset,.42,bestReceiver,passKind,distance,target)
		end
		if released then
			bestReceiver:SetAttribute("VTRPendingFreeKickReceiveTarget",target)
		end
	end
	if not released then
		if session.BallService and session.BallService.Last then session.BallService.Last[taker]={}end
		released=session.BallService:Clearance(taker,session.World.PitchCFrame:VectorToWorldSpace(Vector3.new(0,0,goalSign)))
	end
	if setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
	self:_resumeFinalChanceAfterSetPiece(session)
	if bestReceiver and bestReceiver.Parent and bestReceiver:GetAttribute("VTRPendingFreeKickReceiveTarget")~=nil then
		local target=bestReceiver:GetAttribute("VTRPendingFreeKickReceiveTarget")
		if typeof(target)=="Vector3"then
			bestReceiver:SetAttribute("VTRReceiveTarget",target)
			bestReceiver:SetAttribute("VTRPreparingReceive",true)
			bestReceiver:SetAttribute("VTRReceiveUntil",os.clock()+4.8)
			bestReceiver:SetAttribute("VTRReceiveLockedAt",os.clock())
			bestReceiver:SetAttribute("AIDebugExpectedPass",true)
			bestReceiver:SetAttribute("AIDebugPassTarget",target)
			bestReceiver:SetAttribute("AIDebugPassKind","FreeKick")
		end
		bestReceiver:SetAttribute("VTRPendingFreeKickReceiveTarget",nil)
	end
	session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=false})
end

function Service:_releaseGoalKickClearance(session:any,player:Player?)
	local setPieces=session.SetPieces
	local restartTaker=setPieces and setPieces.RestartTaker
	local active=player and session.TeamControl and session.TeamControl:GetActive(player)or nil
	local taker=(active and active==restartTaker and active)or restartTaker
	if not taker or not taker.Parent then return false end
	local takerRoot=modelRoot(taker)
	if not takerRoot then return false end
	session.World.Ball.Anchored=false
	setServerNetworkOwner(session.World and session.World.Ball)
	session.Possession:ForcePickup(taker)
	local pitch=session.World.PitchCFrame
	local localTaker=pitch:PointToObjectSpace(takerRoot.Position)
	local goalSign=localTaker.Z>=0 and 1 or -1
	local team=tostring(taker:GetAttribute("VTRTeam")or"Home")
	local bestReceiver:Model?=nil
	local bestScore=-math.huge
	local fallback:Model?=nil
	local fallbackScore=-math.huge
	for _,candidate in session.Teams[team]or{}do
		if candidate~=taker and candidate:GetAttribute("VTRSentOff")~=true and tostring(candidate:GetAttribute("position")or"")~="GK"then
			local candidateRoot=modelRoot(candidate)
			if candidateRoot then
				local localCandidate=pitch:PointToObjectSpace(candidateRoot.Position)
				local centerScore=120-math.abs(localCandidate.Z)-math.abs(localCandidate.X)*.38
				local role=tostring(candidate:GetAttribute("position")or"")
				local roleBonus=(role=="CDM"or role=="CM"or role=="CAM"or role=="ST")and 18 or 0
				local rating=(tonumber(candidate:GetAttribute("overall"))or 60)*.08
				local score=centerScore+roleBonus+rating
				if score>fallbackScore then
					fallbackScore=score
					fallback=candidate
				end
				if math.abs(localCandidate.Z)<=session.World.Length*.18 and math.abs(localCandidate.X)<=session.World.Width*.34 and score>bestScore then
					bestScore=score
					bestReceiver=candidate
				end
			end
		end
	end
	bestReceiver=bestReceiver or fallback
	local receiverRoot=bestReceiver and modelRoot(bestReceiver)
	local target:Vector3
	local distance:number
	if receiverRoot then
		local receiverLocal=pitch:PointToObjectSpace(receiverRoot.Position)
		local lead=math.clamp((receiverRoot.Position-takerRoot.Position).Magnitude*.10,8,18)
		local targetLocal=Vector3.new(
			math.clamp(receiverLocal.X,-session.World.Width*.30,session.World.Width*.30),
			3.2,
			math.clamp(receiverLocal.Z-goalSign*lead,-session.World.Length*.12,session.World.Length*.12)
		)
		target=pitch:PointToWorldSpace(targetLocal)
	else
		target=pitch:PointToWorldSpace(Vector3.new(0,3.2,-goalSign*session.World.Length*.06))
	end
	local direction=target-takerRoot.Position
	if direction.Magnitude<1 then direction=pitch:VectorToWorldSpace(Vector3.new(0,0,-goalSign))end
	distance=Vector3.new(direction.X,0,direction.Z).Magnitude
	if session.BallService and session.BallService.Last then session.BallService.Last[taker]={}end
	local shortPass=receiverRoot~=nil and distance<=92
	local passType=shortPass and"Ground"or"Lofted"
	local charge=shortPass and math.clamp(distance/115,.24,.48)or math.clamp(distance/185,.74,.96)
	local released=session.BallService:Kick(taker,"Pass",direction,charge,bestReceiver,passType,distance,target)
	if bestReceiver and released then
		bestReceiver:SetAttribute("VTRReceiveTarget",target)
		bestReceiver:SetAttribute("VTRPreparingReceive",true)
		bestReceiver:SetAttribute("VTRReceiveUntil",os.clock()+5.2)
		bestReceiver:SetAttribute("VTRReceiveLockedAt",os.clock())
	end
	if setPieces and setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
	session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY"})
	return true
end

function Service:_releaseAIThrowIn(session:any)
	local setPieces=session.SetPieces
	local taker=setPieces and setPieces.RestartTaker
	local takerRoot=modelRoot(taker)
	if not taker or not takerRoot then return false end
	local team=tostring(taker:GetAttribute("VTRTeam")or"Home")
	local touchSign=session.World.PitchCFrame:PointToObjectSpace(takerRoot.Position).X>=0 and 1 or-1
	local bestTarget:Model?=nil
	local bestDistance=math.huge
	for _,model in session.Teams[team]or{}do
		if model~=taker then
			local root=modelRoot(model)
			if root then
				local distance=(root.Position-takerRoot.Position).Magnitude
				if distance<bestDistance then bestDistance=distance;bestTarget=model end
			end
		end
	end
	local targetRoot=modelRoot(bestTarget)
	local target=targetRoot and targetRoot.Position or takerRoot.Position+session.World.PitchCFrame:VectorToWorldSpace(Vector3.new(-touchSign*24,0,12))
	session.World.Ball.Anchored=false
	setServerNetworkOwner(session.World and session.World.Ball)
	session.Possession:ForcePickup(taker)
	session.BallService:Kick(taker,"Pass",target-takerRoot.Position,.34,nil,"Manual",(target-takerRoot.Position).Magnitude,target)
	if setPieces and setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
	session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY"})
	return true
end

function Service:_action(player:Player,payload:any)
	local session=self.Sessions[player]
	if not session or type(payload)~="table"then return end
	if payload.Type=="ReplayFinished"then
		self:_ackReplayFinished(session,player)
		return
	end
	if payload.Type=="PrematchSkip"then
		if session.Phase~="PRE MATCH"or session.PrematchSkipped or session.PrematchSkipInProgress then return end
		local unlockAt=tonumber(session.PrematchSkipUnlockAt)or 0
		if os.clock()<unlockAt then
			self.State:FireClient(player,{Type="PrematchSkipLocked",Remaining=math.max(1,math.ceil(unlockAt-os.clock()))})
			return
		end
		local now=os.clock()
		session.PrematchSkipRequestTimes=session.PrematchSkipRequestTimes or{}
		if now-(tonumber(session.PrematchSkipRequestTimes[player])or 0)<.65 then return end
		session.PrematchSkipRequestTimes[player]=now
		session.PrematchSkipVotes=session.PrematchSkipVotes or{}
		session.PrematchSkipVotes[player]=true
		if not session.Ranked then
			self:_skipPrematch(session)
			return
		end
		local ready=true
		local readyCount=0
		local totalCount=0
		for _,participant in session.Players do
			totalCount+=1
			if session.PrematchSkipVotes[participant]then readyCount+=1 else ready=false end
		end
		broadcast(self.State,session,{Type="PrematchSkipQueued",PlayerName=player.Name,Ready=ready,ReadyCount=readyCount,TotalCount=totalCount})
		if ready then self:_skipPrematch(session)end
		return
	end
	if payload.Type=="HalfTimeResume"then
		if not session.HalfTimeBreak then return end
		session.HalfTimeResumeVotes=session.HalfTimeResumeVotes or{}
		session.HalfTimeResumeVotes[player]=true
		local readyCount=0
		for _,participant in session.Players do
			if session.HalfTimeResumeVotes[participant]then readyCount+=1 end
		end
		local ready=VTRSecondHalfNeedsBothReady(readyCount,#session.Players,false)
		broadcast(self.State,session,{Type="HalfTimeResumeVote",PlayerName=player.Name,Ready=ready,ReadyCount=readyCount,PlayerCount=#session.Players})
		if ready then self:_resumeHalfTime(session)end
		return
	end
	if payload.Type=="AITacticsDebug"then
		local side=payload.Side=="Away"and"Away"or"Home"
		local tactics=sanitizeRuntimeTactics(payload.Tactics)
		if session.AI and session.AI.UpdateTactics then session.AI:UpdateTactics(side,tactics)end
		for name,value in pairs(tactics.Sliders or{})do
			if type(name)=="string"then workspace:SetAttribute("VTRTactic_"..side.."_"..name,math.clamp(tonumber(value)or 50,0,100))end
		end
		local debug=type(payload.Debug)=="table"and payload.Debug or{}
		for _,group in{"Width","Depth","Press","Passing","Runs","Shape","Keeper"}do
			workspace:SetAttribute("TacticalDebug"..group,debug[group]==true)
		end
		workspace:SetAttribute("TacticalDebug",debug.Width==true or debug.Depth==true or debug.Press==true or debug.Passing==true or debug.Runs==true or debug.Shape==true or debug.Keeper==true)
		self.State:FireClient(player,{Type="AITacticsDebugApplied",Side=side,Tactics=tactics})
		return
	end
	if payload.Type=="ShootingPracticeTuning" and session.ShootingPractice then
		self:_applyShootingPracticeTuning(session,payload.Tuning)
		return
	end
	if payload.Type=="ShootingPracticeReset" and session.ShootingPractice then
		self:_applyShootingPracticeTuning(session,payload.Tuning)
		self:_resetShootingPractice(session,"MANUAL")
		return
	end
	if payload.Type=="SecondHalfWatchdogReset"then
		self:_watchdogResetSecondHalf(session,player)
		return
	end
	if session.ShootingPractice and payload.Type~="Shot"and payload.Type~="Move"and payload.Type~="Sprint"and payload.Type~="ReceiverAssistOverride"and payload.Type~="Pause"and payload.Type~="Forfeit"then
		return
	end
	if session.ShootingPractice and payload.Type=="Shot"then
		payload.PracticeShotTarget=true
	end
	if session.Setup and session.Setup.WatchMode==true and payload.Type~="Pause"and payload.Type~="Forfeit"then return end
	if session.Paused and payload.Type~="Pause"and payload.Type~="Forfeit"and payload.Type~="ManualSubstitution"then return end
	if session.SetPieces and session.SetPieces:HandleAction(player,payload)then return end
	if payload.Type=="DebugCorner"then
		if RunService:IsStudio()and session.Running then local ballLocal=session.World.PitchCFrame:PointToObjectSpace(session.World.Ball.Position);local x=ballLocal.X>=0 and session.World.Width*.5+2 or-session.World.Width*.5-2;local location=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(x,.2,-session.World.Length*.5-2));self:_startSetPiece(session,"Corner","Home",location)end
		return
	end
	if payload.Type=="DebugFreeKick"then
		if session.Running or session.Phase=="IN PLAY"then
			local side=session.PlayerSides[player]or"Home"
			local active=session.TeamControl and session.TeamControl:GetActive(player)or nil
			if active and active:GetAttribute("position")=="GK"then active=nil end
			local sign=side=="Home"and-1 or 1
			local location=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.2,sign*(session.World.Length*.5-132)))
			self:_startSetPiece(session,"FreeKick",side,location,active)
		end
		return
	end
	if payload.Type=="DebugPenaltyAttack"then
		if session.Running or session.Phase=="IN PLAY"then
			local side=session.PlayerSides[player]or"Home"
			local sign=side=="Home"and-1 or 1
			if session.Clock and session.Clock.Payload and (session.Clock:Payload().Half or 1)>=2 then sign=-sign end
			local spot=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.2,sign*(session.World.Length*.5-12)))
			self:_startSetPiece(session,"Penalty",side,spot)
		end
		return
	end
	if payload.Type=="DebugPenaltyDefense"then
		if session.Running or session.Phase=="IN PLAY"then
			local playerSide=session.PlayerSides[player]or"Home"
			local attackingSide=playerSide=="Home"and"Away"or"Home"
			local sign=attackingSide=="Home"and-1 or 1
			if session.Clock and session.Clock.Payload and (session.Clock:Payload().Half or 1)>=2 then sign=-sign end
			local spot=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.2,sign*(session.World.Length*.5-12)))
			self:_startSetPiece(session,"Penalty",attackingSide,spot)
			local keeper=getGoalkeeper(session.Teams[playerSide])
			if keeper then
				session.TeamControl:SetActive(player,keeper,"PenaltyDefense")
				keeper:SetAttribute("VTRPenaltyUserKeeper",true)
				local goalPosition=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,sign*session.World.Length*.5))
				self.State:FireClient(player,{Type="ActivePlayer",Model=keeper,Name=keeper:GetAttribute("DisplayName"),Position=keeper:GetAttribute("position"),Reason="PenaltyDefense",PenaltyLocation=session.World.Ball.Position,GoalPosition=goalPosition})
			end
			session.PendingAIPenalty={Player=player,AttackingSide=attackingSide,DefendingSide=playerSide,At=os.clock()+2.35}
		end
		return
	end
	if payload.Type=="Pause"then
		if payload.Active==true then
			if session.Ranked and session.Running and session.Phase=="IN PLAY"then
				if session.PauseQueued and session.PauseRequestedBy==player then
					session.PauseQueued=false
					session.PauseRequestedBy=nil
					broadcast(self.State,session,{Type="PauseQueue",Queued=false,PlayerName=player.Name})
				else
					session.PauseQueued=true
					session.PauseRequestedBy=player
					broadcast(self.State,session,{Type="PauseQueue",Queued=true,PlayerName=player.Name})
				end
			else
				self:_openPause(session,player)
			end
		else
			if session.Paused then
				session.PauseResumeVotes=session.PauseResumeVotes or{}
				session.PauseResumeVotes[player]=true
				local ready=true
				for _,participant in session.Players do
					if not session.PauseResumeVotes[participant] then ready=false;break end
				end
				broadcast(self.State,session,{Type="PauseResumeVote",PlayerName=player.Name,Ready=ready})
				if ready then self:_resumePause(session)end
			else
				session.PauseQueued=false
				session.PauseRequestedBy=nil
				broadcast(self.State,session,{Type="PauseQueue",Queued=false,PlayerName=player.Name})
			end
		end
		return
	end
	if payload.Type=="Forfeit"then
		if session.Ranked then
			self:_applyRankedForfeit(session,player,"Forfeit")
		else
			local side=session.PlayerSides[player]or"Home";local opponentSide=side=="Home"and"Away"or"Home"
			if opponentSide=="Home"then session.World.HomeScore.Value=math.max(session.World.HomeScore.Value,session.World.AwayScore.Value+3)else session.World.AwayScore.Value=math.max(session.World.AwayScore.Value,session.World.HomeScore.Value+3)end
			session.ForfeitBy=player.UserId
		end
		self:EndMatch(session.StepOwner,true)
		return
	end
	if payload.Type=="ManualSubstitution"then
		local side=session.PlayerSides[player]or"Home"
		local benchIndex=math.floor(tonumber(payload.BenchIndex)or 0)
		local outgoing=payload.OutgoingModel
		if benchIndex<1 or not outgoing or typeof(outgoing)~="Instance" or not outgoing:IsA("Model") or outgoing:GetAttribute("VTRTeam")~=side then return end
		if session.UsedBench[side][benchIndex] then return end
		local incoming=session.BenchData[side] and session.BenchData[side][benchIndex]
		if not incoming then return end
		outgoing:SetAttribute("playerId",incoming.playerId)
		outgoing:SetAttribute("DisplayName",incoming.displayName or incoming.shortName or"SUBSTITUTE")
		outgoing:SetAttribute("overall",incoming.overall or 60)
		outgoing:SetAttribute("VTRSprintStamina",100)
		outgoing:SetAttribute("VTREndurance",100)
		outgoing:SetAttribute("VTRStamina",100)
		outgoing:SetAttribute("VTRSprintLocked",false)
		for _,key in{"PAC","SHO","PAS","DRI","DEF","PHY"}do outgoing:SetAttribute(key,tonumber(incoming.mainStats and incoming.mainStats[key])or incoming.overall or 60)end
		local detailed=incoming.detailedStats or incoming.DetailedStats or{}
		local shooting=tonumber(incoming.mainStats and incoming.mainStats.SHO)or tonumber(incoming.SHO)or incoming.overall or 60
		outgoing:SetAttribute("ShotPower",tonumber(incoming.shotPower)or tonumber(incoming.ShotPower)or tonumber(detailed.shotPower)or tonumber(detailed.ShotPower)or shooting)
		outgoing:SetAttribute("LongShots",tonumber(incoming.longShots)or tonumber(incoming.LongShots)or tonumber(detailed.longShots)or tonumber(detailed.LongShots)or shooting)
		session.UsedBench[side][benchIndex]=true
		session.Clock:Record("Substitution")
		broadcast(self.State,session,{Type="Substitution",Side=side,Outgoing=tostring(payload.OutgoingName or outgoing.Name),Incoming=outgoing:GetAttribute("DisplayName"),Model=outgoing})
		if session.TeamControl:GetActive(player)==outgoing then self.State:FireClient(player,{Type="ActivePlayer",Model=outgoing,Name=outgoing:GetAttribute("DisplayName"),Position=outgoing:GetAttribute("position"),Reason="ManualSubstitution"})end
		return
	end
	if payload.Type=="ManualPositionSwap"then
		local side=session.PlayerSides[player]or"Home"
		local modelA=payload.ModelA
		local modelB=payload.ModelB
		if typeof(modelA)~="Instance"or typeof(modelB)~="Instance"or not modelA:IsA("Model")or not modelB:IsA("Model")then return end
		if modelA:GetAttribute("VTRTeam")~=side or modelB:GetAttribute("VTRTeam")~=side then return end
		local posA=tostring(modelA:GetAttribute("position")or"--")
		local posB=tostring(modelB:GetAttribute("position")or"--")
		local indexA=tonumber(modelA:GetAttribute("VTRIndex"))or 0
		local indexB=tonumber(modelB:GetAttribute("VTRIndex"))or 0
		modelA:SetAttribute("position",posB)
		modelB:SetAttribute("position",posA)
		modelA:SetAttribute("VTRIndex",indexB)
		modelB:SetAttribute("VTRIndex",indexA)
		broadcast(self.State,session,{Type="Info",Message="Positions swapped",Important=false})
		if session.TeamControl:GetActive(player)==modelA then self.State:FireClient(player,{Type="ActivePlayer",Model=modelA,Name=modelA:GetAttribute("DisplayName"),Position=modelA:GetAttribute("position"),Reason="PositionSwap"})
		elseif session.TeamControl:GetActive(player)==modelB then self.State:FireClient(player,{Type="ActivePlayer",Model=modelB,Name=modelB:GetAttribute("DisplayName"),Position=modelB:GetAttribute("position"),Reason="PositionSwap"})end
		return
	end
	if payload.Type=="ReceiverAssistOverride"then
		if session.TeamControl and session.TeamControl.SetManualReceiveOverride then
			session.TeamControl:SetManualReceiveOverride(player,payload.Active==true)
		end
		return
	end
	if not session.Running and not session.Paused and (session.Phase=="FreeKick"or session.Phase=="Penalty"or session.Phase=="GoalKick"or session.Phase=="ThrowIn") then
		local releaseAction=payload.Type=="Pass"or payload.Type=="Shot"or payload.Type=="Clearance"or payload.Type=="PenaltyGuess"
		if releaseAction then
			local restartTeam=session.SetPieces and session.SetPieces.RestartTeam
			local playerSide=session.PlayerSides[player]or"Home"
			local penaltyKeeperAction=session.Phase=="Penalty" and (payload.Type=="PenaltyGuess" or payload.Type=="Shot") and restartTeam and playerSide~=restartTeam
			if restartTeam and playerSide~=restartTeam and not penaltyKeeperAction then
				self.State:FireClient(player,{Type="Info",Message="Opponent set piece. Waiting for their decision.",Important=true})
				return
			end
			if session.Phase=="Penalty" and payload.Type=="PenaltyGuess" then
				local defendingSide=session.PlayerSides[player]or"Home"
				local goalSign=tonumber(session.SetPieces and session.SetPieces.RestartGoalSign)or(defendingSide=="Home"and-1 or 1)
				local aim=typeof(payload.AimPosition)=="Vector3"and payload.AimPosition or session.World.Ball.Position
				local slot=PenaltyConfig.NormalizeSlot(payload.PenaltySlot)or PenaltyConfig.SlotFromGoalPoint(session.World.PitchCFrame,session.World.Length,goalSign,aim,session.World.Width)
				self:_setPenaltyKeeperGuess(session,defendingSide,slot)
				self.State:FireClient(player,{Type="Info",Message="Keeper dive: "..string.gsub(slot,"_"," "),Important=false})
				return
			end
			if session.Phase=="FreeKick" and session.SetPieces and session.SetPieces.RestartMode=="LongFreeKick" and payload.Type~="Pass" then
				self.State:FireClient(player,{Type="Info",Message="Long free kick: choose a pass target.",Important=true})
				return
			end
			local before=session.BallService.MotionStarted
			local restartMode=session.SetPieces and session.SetPieces.RestartMode or nil
			local restartActive=session.TeamControl:GetActive(player)
			if session.Phase=="GoalKick"and payload.Type~="Pass"then
				self:_releaseGoalKickClearance(session,player)
				return
			end
			if session.Phase=="Penalty" and payload.Type=="Shot" and os.clock() < (tonumber(session.PenaltyActionLockedUntil) or 0) then
				self.State:FireClient(player,{Type="Info",Message="WAIT FOR THE WHISTLE",Important=false})
				return
			end
			if session.Phase=="Penalty" and payload.Type=="Shot" and session.SetPieces and session.SetPieces.RestartTaker and restartActive~=session.SetPieces.RestartTaker then
				local defendingSide=session.PlayerSides[player]or"Home"
				local goalSign=tonumber(session.SetPieces.RestartGoalSign)or(defendingSide=="Home"and-1 or 1)
				local aim=typeof(payload.AimPosition)=="Vector3"and payload.AimPosition or session.World.Ball.Position
				local slot=PenaltyConfig.NormalizeSlot(payload.PenaltySlot)or PenaltyConfig.SlotFromGoalPoint(session.World.PitchCFrame,session.World.Length,goalSign,aim,session.World.Width)
				self:_setPenaltyKeeperGuess(session,defendingSide,slot)
				self.State:FireClient(player,{Type="Info",Message="Keeper dive: "..string.gsub(slot,"_"," "),Important=false})
				return
			end
			if restartMode=="DirectShotFreeKick" and restartActive and payload.Type=="Shot" then
				restartActive:SetAttribute("VTRFreeKickCurve",math.clamp(tonumber(payload.FreeKickCurve) or 0,-2.5,2.5))
				restartActive:SetAttribute("VTRFreeKickLift",math.clamp(tonumber(payload.FreeKickLift) or 0,-2.5,2.5))
			end
			if session.Phase=="Penalty" and restartActive and payload.Type=="Shot"then
				local target,slot,charge=self:_penaltyTarget(session,restartActive,payload)
				local defendingSide=tostring(restartActive:GetAttribute("VTRTeam"))=="Home"and"Away"or"Home"
				local keeper=getGoalkeeper(session.Teams[defendingSide])
				if not keeper or keeper:GetAttribute("VTRPenaltyGuessSlot")==nil then self:_setPenaltyKeeperGuess(session,defendingSide,nil)end
				payload.AimPosition=target
				payload.GoalTarget=true
				payload.PenaltySlot=slot
				payload.Charge=charge
			end
			if session.Phase=="FreeKick" or session.Phase=="Penalty" then
				self:_setPieceRunup(session,restartActive,payload.Type)
			end
			if session.Phase=="Penalty" and payload.Type=="Shot"then
				session.World.Ball:SetAttribute("VTRPenaltyShotActive",true)
			end
			if restartMode=="DirectShotFreeKick" and payload.Type=="Shot" then
				self:_jumpFreeKickWall(session)
			end
			session.World.Ball.Anchored=false
			setServerNetworkOwner(session.World and session.World.Ball)
			session.TeamControl:Handle(player,payload)
			local released=session.BallService.MotionStarted~=before and (session.BallService.MotionKind=="Pass"or session.BallService.MotionKind=="Shot"or session.BallService.MotionKind=="Clearance")
			if not released then
				local active=session.TeamControl:GetActive(player)
				local activeRoot=active and active:FindFirstChild("HumanoidRootPart")::BasePart?
				local aimPosition=typeof(payload.AimPosition)=="Vector3"and payload.AimPosition or nil
				local direction=typeof(payload.Direction)=="Vector3"and payload.Direction or nil
				if active and activeRoot and session.Possession:GetOwner()~=active then session.Possession:ForcePickup(active)end
				if active and activeRoot and payload.Type=="Pass"then
					local target=aimPosition or(direction and activeRoot.Position+direction.Unit*42)or(activeRoot.Position+activeRoot.CFrame.LookVector*42)
					local offset=target-activeRoot.Position
					if offset.Magnitude>1 then session.BallService:Kick(active,"Pass",offset,tonumber(payload.Charge)or .25,nil,"Manual",offset.Magnitude,target)end
				elseif active and activeRoot and payload.Type=="Shot"then
					local target=aimPosition
					local offset=target and(target-activeRoot.Position)or direction
					if offset and offset.Magnitude>.1 then
						if payload.GoalTarget~=true then session.BallService:LowClearance(active,offset,tonumber(payload.Charge)or .45)
						else session.BallService:Kick(active,"Shot",offset,tonumber(payload.Charge)or .55,nil,nil,nil,target)end
					end
				elseif active and payload.Type=="Clearance"then
					local side=tostring(active:GetAttribute("VTRTeam")or"Home");local sign=side=="Home"and-1 or 1
					session.BallService:Clearance(active,session.World.PitchCFrame:VectorToWorldSpace(Vector3.new(0,0,sign)))
				end
				released=session.BallService.MotionStarted~=before and (session.BallService.MotionKind=="Pass"or session.BallService.MotionKind=="Shot"or session.BallService.MotionKind=="Clearance")
			end
			if released then
				if session.SetPieces and session.SetPieces.ReleaseRestartTaker then session.SetPieces:ReleaseRestartTaker()end
				if session.Phase=="FreeKick"or session.Phase=="Penalty"then self:_resumeFinalChanceAfterSetPiece(session)end
				session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session);task.delay(.18,function()if not session.Ended and session.Running then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end end)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=(restartMode=="Penalty") and payload.Type=="Shot"})
			else
				session.World.Ball.Anchored=true
			end
		end
		return
	end
	if not session.Running or session.Paused then return end
	local character=player.Character
	if not character then return end
	if payload.Type=="Sprint"then
		local playerState=session.PlayerState and session.PlayerState[player];if playerState then playerState.SprintRequested=payload.Active==true end
		if session.TeamControl and session.TeamControl.SetManualReceiveOverride then
			session.TeamControl:SetManualReceiveOverride(player,payload.Active==true)
		end
	elseif payload.Type=="Context"then
		local active=session.TeamControl:GetActive(player);local owns=active and session.Possession:GetOwner()==active
		if owns and active then active:SetAttribute("VTRCloseControl",payload.Active==true)end
	elseif payload.Type=="CallPass"then
		-- Q is a team-control/support request only. Never auto-pass for the
		-- player-controlled team; the user must press RMB/LMB for the ball action.
		self.State:FireClient(player,{Type="Info",Message="Support run requested.",Important=false})
	else
		session.TeamControl:Handle(player,payload)
	end
end

function Service:_step(dt:number)
	local seen:any={}
	for _,session in self.Sessions do
		if seen[session]then continue end;seen[session]=true
		if session.Ended then continue end
		if session.Paused then
			local requester=session.PauseRequester
			if requester and session.PauseSecondsByPlayer then
				session.PauseSecondsByPlayer[requester]=math.max(0,(session.PauseSecondsByPlayer[requester] or 0)-dt)
			end
			session.PauseTimerAccumulator=(session.PauseTimerAccumulator or 0)+dt
			if session.PauseTimerAccumulator>=.5 then
				session.PauseTimerAccumulator=0
				local remaining=requester and session.PauseSecondsByPlayer and session.PauseSecondsByPlayer[requester] or 0
				broadcast(self.State,session,{Type="PauseTimer",Remaining=math.max(0,math.floor((remaining or 0)+.5))})
			end
			if requester and session.PauseSecondsByPlayer and (session.PauseSecondsByPlayer[requester] or 0)<=0 then self:_resumePause(session)end
			continue
		end
		if session.PendingAIPenalty and not session.Running and session.Phase=="Penalty"and os.clock()>=session.PendingAIPenalty.At then
			self:_releaseAIPenalty(session)
		end
		if session.HalfTimeBreak then
			session.HalfTimeTimerAccumulator=(session.HalfTimeTimerAccumulator or 0)+dt
			if session.HalfTimeTimerAccumulator>=.5 then
				session.HalfTimeTimerAccumulator=0
				local remaining=math.max(0,math.ceil((tonumber(session.HalfTimeBreakEndsAt)or os.clock())-os.clock()))
				broadcast(self.State,session,{Type="HalfTimeTimer",Remaining=remaining})
				if remaining<=0 then self:_resumeHalfTime(session)end
			end
		end
		if session.PendingReplayRestart and session.PendingReplayRestart.Ready==true and os.clock()>=(tonumber(session.PendingReplayRestart.TimeoutAt)or math.huge)then
			self:_resumeReplayRestart(session,"timeout")
		end
		if session.World and session.World.Ball and (tonumber(session.World.Ball:GetAttribute("VTRPostGoalPhysicsUntil"))or 0)>os.clock()then
			local velocity=session.World.Ball:GetAttribute("VTRPostGoalVelocity")
			local angular=session.World.Ball:GetAttribute("VTRPostGoalAngularVelocity")
			session.World.Ball.Anchored=false
			if typeof(velocity)=="Vector3"and session.World.Ball.AssemblyLinearVelocity.Magnitude<1 and os.clock()-(tonumber(session.World.Ball:GetAttribute("VTRGoalCalledAt"))or 0)<1.2 then session.World.Ball.AssemblyLinearVelocity=velocity end
			if typeof(angular)=="Vector3"and session.World.Ball.AssemblyAngularVelocity.Magnitude<1 then session.World.Ball.AssemblyAngularVelocity=angular end
			if session.Grounding then session.Grounding:Step()end
		end
		if session.Paused or session.ManualPaused then
			continue
		end
		if not session.Running then continue end
		session.Accumulator+=dt;session.Clock:Step(dt)
		local grantIndex=math.floor((session.Clock:Payload().GameSeconds or 0)/1800)
		if grantIndex>(session.PauseGrantIndex or 0)then
			for _,participant in session.Players do
				session.PauseSecondsByPlayer[participant]=(session.PauseSecondsByPlayer[participant] or 0)+60*(grantIndex-(session.PauseGrantIndex or 0))
			end
			session.PauseGrantIndex=grantIndex
		end
		local activeOwners:any={};local sprintingByModel:any={};local gameRate=session.Clock:GetRate()
		for _,participant in session.Players do local state=session.PlayerState[participant];local active=session.TeamControl:GetActive(participant);if active and state then local sprintLocked=active:GetAttribute("VTRSprintLocked")==true and active:GetAttribute("controlledByUser")~=true;local sprinting=not sprintLocked and(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0)>.1 and state.Stamina>=math.min(1,Config.Stamina.MinimumToSprint);activeOwners[active]=participant;sprintingByModel[active]=sprinting end end
		for _,footballer in session.Models do
			local footballerRoot=footballer:FindFirstChild("HumanoidRootPart")::BasePart?;local participant=activeOwners[footballer];local playerState=participant and session.PlayerState[participant];local modelSpeed=footballerRoot and Vector3.new(footballerRoot.AssemblyLinearVelocity.X,0,footballerRoot.AssemblyLinearVelocity.Z).Magnitude or 0;local modelSprinting=participant~=nil and sprintingByModel[footballer]==true;local modelMove=participant and(tonumber(footballer:GetAttribute("VTRMoveMagnitude"))or 0)or(modelSpeed>.5 and 1 or 0);local reserve,endurance=session.StaminaService:Step(footballer,dt,{Sprinting=modelSprinting,MoveMagnitude=modelMove,CurrentSpeed=modelSpeed,HasBall=session.Possession:GetOwner()==footballer,UserControlled=participant~=nil,GameRate=gameRate});if playerState then playerState.Stamina=reserve;playerState.Endurance=endurance end
		end
		for _,participant in session.Players do
			local playerState=session.PlayerState[participant];local active=session.TeamControl:GetActive(participant);local humanoid=active and active:FindFirstChildOfClass("Humanoid");if not active or not playerState then continue end
			local sprinting=sprintingByModel[active]==true;active:SetAttribute("VTRSprinting",sprinting);local moveMagnitude=math.clamp(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0,0,1);local turnDot=math.clamp(tonumber(active:GetAttribute("VTRTurnDot"))or 1,-1,1);local ownsBall=session.Possession:GetOwner()==active
			local resolved=MovementStatsResolver.Resolve(active,{MoveMagnitude=moveMagnitude,Sprinting=sprinting,StaminaRatio=playerState.Stamina/Config.Stamina.Maximum,HasBall=ownsBall,TurnDot=turnDot,TurnPenalty=tonumber(active:GetAttribute("DribbleTurnPenalty"))or 1,UserControlled=true});local target=resolved.TargetSpeed;local current=session.MovementSpeeds[active]or 0;local switchedAt=tonumber(active:GetAttribute("VTRControlSwitchedAt"))or 0
			local immediateUntil=tonumber(active:GetAttribute("VTRImmediateControlUntil"))or 0
			if os.clock()<immediateUntil and moveMagnitude>.08 then
				-- A receiver/collector responds on the first input frame. Preserve a
				-- tiny amount of acceleration feel without the old sluggish delay.
				current=math.max(current,target*(ownsBall and 1 or .92))
			else local ramp=target>current and resolved.AccelerationRate or resolved.DecelerationRate;current+=math.clamp(target-current,-ramp*dt,ramp*dt)end;session.MovementSpeeds[active]=current
			active:SetAttribute(MovementTuning.DebugAttributes.CurrentSpeed,current);active:SetAttribute(MovementTuning.DebugAttributes.TargetSpeed,target);active:SetAttribute(MovementTuning.DebugAttributes.Stamina,playerState.Stamina);active:SetAttribute(MovementTuning.DebugAttributes.SprintMultiplier,resolved.SprintMultiplier);active:SetAttribute(MovementTuning.DebugAttributes.BallControlModifier,resolved.BallControlModifier);if humanoid then humanoid.WalkSpeed=math.max(.1,current)end
		end
		for _,model in session.Models do local modelRoot=model:FindFirstChild("HumanoidRootPart")::BasePart?;if modelRoot then local last=session.LastPositions[model];local limit=math.max(8,(model:GetAttribute("VTRUserId")and 40 or 48)*math.min(dt+.12,.28));if last and(modelRoot.Position-last).Magnitude>limit then local facing=Vector3.new(modelRoot.CFrame.LookVector.X,0,modelRoot.CFrame.LookVector.Z);model:PivotTo(CFrame.lookAt(last,last+(facing.Magnitude>.01 and facing.Unit or Vector3.zAxis)))else session.LastPositions[model]=modelRoot.Position end end end
		local currentHalf=session.Clock and session.Clock:Payload().Half or 1;if session.AI and session.AI.SetHalf then session.AI:SetHalf(currentHalf)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(currentHalf)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(currentHalf)end;if session.Stats and session.Stats.RecordPositions then session.Stats:RecordPositions(session.Models,dt)end;session.BallService:Step(dt);session.TeamControl:Step();session.Animations:Step(session.Possession:GetOwner());session.Grounding:Step();if not session.ShootingPractice then session.AI:Step(dt)end;session.Goalkeepers:Step(dt);session.Goals:Step();if session.Running and not session.ShootingPractice then session.OutOfBounds:Step()end;if not session.ShootingPractice then RefereeService.Enforce(session.Models,session.World.PitchCFrame,session.World.Width,session.World.Length)end;if session.LinkDebug then session.LinkDebug:Step(session,dt)end
		if session.ShootingPractice then
			self:_stepShootingPractice(session,dt)
		elseif session.Clock:ShouldEndMatch()then
			local finalChanceEnd=session.FinalChance and self:_finalChanceShouldEnd(session)or false
			if finalChanceEnd then
				self:_clearFinalChance(session)
				self:EndMatch(session.StepOwner,true)
			elseif session.FinalChance then
				-- Keep the last attack alive until it leaves the final third, a shot dies, or possession changes.
			elseif not self:_startFinalChance(session,"FullTime")then
				self:EndMatch(session.StepOwner,true)
			end
		elseif not session.HalfTimeTriggered and session.Clock:ShouldHalfTime()then
			local finalChanceEnd=session.FinalChance and self:_finalChanceShouldEnd(session)or false
			if finalChanceEnd then
				self:_clearFinalChance(session)
				self:_halfTime(session)
			elseif session.FinalChance then
				-- Keep the first-half last attack alive until it resolves.
			elseif not self:_startFinalChance(session,"HalfTime")then
				self:_halfTime(session)
			end
		elseif session.Accumulator>=.1 then session.Accumulator=0;local clockPayload=session.Clock:Payload();for _,participant in session.Players do local state=session.PlayerState[participant];self.State:FireClient(participant,{Type="Clock",GameSeconds=clockPayload.GameSeconds,Half=clockPayload.Half,AddedMinutes=clockPayload.AddedMinutes,InAddedTime=clockPayload.InAddedTime,AddedElapsed=clockPayload.AddedElapsed,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,Stamina=state and state.Stamina or Config.Stamina.Maximum,Endurance=state and state.Endurance or Config.Stamina.Maximum})end
		end
	end
end

function Service:_finalChanceCandidate(session:any): string?
	local owner=session.Possession and session.Possession:GetOwner() or nil
	local side=owner and tostring(owner:GetAttribute("VTRTeam")or"")or nil
	if (not side or side=="")and session.BallService and session.BallService.GetLastTouchTeam then
		side=session.BallService:GetLastTouchTeam()
	end
	if not side or side==""then
		side=tostring(session.World.Ball:GetAttribute("VTRLastPossessionTeam")or"")
	end
	if side~="Home"and side~="Away"then return nil end
	local ball=session.World and session.World.Ball
	local ownerRoot=owner and owner:FindFirstChild("HumanoidRootPart")::BasePart?
	local ownerInThird=ownerRoot and isFinalThirdForTeam(session,side,ownerRoot.Position)or false
	local ballInThird=ball and isFinalThirdForTeam(session,side,ball.Position)or false
	return (ownerInThird or ballInThird)and side or nil
end

function Service:_holdFinalChanceForSetPiece(session:any,kind:string,restartTeam:string)
	local chance=session.FinalChance
	if not chance then return end
	chance.SetPieceActive=true
	chance.SetPieceKind=kind
	chance.SetPieceTeam=restartTeam
	chance.SetPiecePausedAt=os.clock()
end

function Service:_resumeFinalChanceAfterSetPiece(session:any)
	local chance=session.FinalChance
	if not chance or chance.SetPieceActive~=true then return end
	local pausedAt=tonumber(chance.SetPiecePausedAt)or os.clock()
	local startedAt=tonumber(chance.StartedAt)or os.clock()
	chance.StartedAt=startedAt+math.max(0,os.clock()-pausedAt)
	chance.SetPieceActive=nil
	chance.SetPieceKind=nil
	chance.SetPieceTeam=nil
	chance.SetPiecePausedAt=nil
	chance.RestartReleasedAt=os.clock()
end

function Service:_startFinalChance(session:any,target:string?): boolean
	local side=self:_finalChanceCandidate(session)
	if not side then return false end
	local owner=session.Possession and session.Possession:GetOwner() or nil
	local motionKind=session.BallService and session.BallService.MotionKind or ""
	session.FinalChance={
		Team=side,
		Target=target or"FullTime",
		StartedAt=os.clock(),
		StartedOwner=owner,
		StartedMotionKind=motionKind,
		StartedMotionAt=session.BallService and session.BallService.MotionStarted or 0,
		ShotSeen=motionKind=="Shot",
	}
	broadcast(self.State,session,{Type="FinalChance",Active=true,Team=side})
	return true
end

function Service:_finalChanceShouldEnd(session:any): (boolean,string?)
	local chance=session.FinalChance
	if not chance then return false,nil end
	if chance.SetPieceActive==true then
		return false,nil
	end
	if os.clock()-(tonumber(chance.StartedAt)or os.clock())>=FINAL_CHANCE_MAX_SECONDS then
		return true,"timeout"
	end
	local side=tostring(chance.Team or "")
	local ball=session.World and session.World.Ball
	local ballService=session.BallService
	local motionKind=ballService and tostring(ballService.MotionKind or "")or""
	if motionKind=="Shot"then
		chance.ShotSeen=true
		return false,nil
	end
	if chance.ShotSeen==true then
		return true,"shot_stopped"
	end
	local owner=session.Possession and session.Possession:GetOwner() or nil
	if owner then
		local ownerSide=tostring(owner:GetAttribute("VTRTeam")or"")
		if ownerSide~=side then
			return true,"possession_changed"
		end
	end
	if motionKind=="Save"or motionKind=="KeeperClaim"or motionKind=="Tackle"then
		return true,"possession_changed"
	end
	if ball and not isFinalThirdForTeam(session,side,ball.Position)then
		return true,"left_final_third"
	end
	return false,nil
end

function Service:_clearFinalChance(session:any)
	if not session.FinalChance then return end
	session.FinalChance=nil
	broadcast(self.State,session,{Type="FinalChance",Active=false})
end

function Service:_finalWhistleFreeze(session:any)
	session.Phase="FULL TIME"
	session.Running=false
	session.ManualPaused=false
	session.Paused=false
	if session.AI and session.AI.SetDisabled then
		session.AI:SetDisabled(true)
	elseif session.AI and session.AI.SetExternalPhase then
		session.AI:SetExternalPhase("FULL TIME")
	end
	if session.Possession then session.Possession:Reset()end
	if session.TeamControl and session.TeamControl.Receiving then session.TeamControl.Receiving:Clear()end
	self:_setPlayersFrozen(session,true)
	if session.World and session.World.Ball then
		session.World.Ball.AssemblyLinearVelocity=Vector3.zero
		session.World.Ball.AssemblyAngularVelocity=Vector3.zero
		session.World.Ball.Anchored=true
		session.World.Ball:SetAttribute("VTRWorldPaused",true)
		session.World.Ball:SetAttribute("VTRMotionKind","FullTime")
	end
	broadcast(self.State,session,{Type="Phase",Phase="FULL TIME",HoldCutscene=true})
end

function Service:_applyRankedForfeit(session:any,player:Player,reason:string?)
	if not session or session.Ended or not session.Ranked then return false end
	local side=session.PlayerSides and session.PlayerSides[player] or "Home"
	local opponentSide=side=="Home" and "Away" or "Home"
	if opponentSide=="Home" then
		session.World.HomeScore.Value=math.max(session.World.HomeScore.Value,session.World.AwayScore.Value+3)
	else
		session.World.AwayScore.Value=math.max(session.World.AwayScore.Value,session.World.HomeScore.Value+3)
	end
	session.ForfeitBy=player.UserId
	session.ForfeitReason=reason or "Leave"
	session.RankedForceLossUserId=player.UserId
	for _,participant in session.Players or{}do
		if participant==player then
			participant:SetAttribute("VTRRankedResult","Loss")
			participant:SetAttribute("VTRRankedForfeitLoss",true)
		else
			participant:SetAttribute("VTRRankedResult","Win")
			participant:SetAttribute("VTRRankedForfeitWin",true)
		end
	end
	return true
end

function Service:_applyWorldCupForfeit(session:any,player:Player,reason:string?)
	if not session or session.Ended or session.PrivateWorldCupMatch~=true then return false end
	session.World.AwayScore.Value=math.max(session.World.AwayScore.Value,session.World.HomeScore.Value+3)
	session.ForfeitBy=player.UserId
	session.ForfeitReason=reason or "Leave"
	return true
end

function Service:EndMatch(player:Player,showResult:boolean):boolean
	local session=self.Sessions[player]
	if not session then return false end
	if session.Ended then return false end
	for _,connection in session.Connections or{}do if connection and connection.Disconnect then connection:Disconnect()end end
	self:_clearFinalChance(session)
	session.Ended=true;session.Running=false;if session.SetPieces then session.SetPieces:Cancel()end
	if showResult then self:_finalWhistleFreeze(session)end
	if showResult then
		local gameSeconds=session.Clock:Payload().GameSeconds
		local rewards=session.OnBeforeResult and session.OnBeforeResult(session)or{}
		local rankedPackChoices=rankedPackChoices()
		local resultStats=session.Stats:Serialize(session.World.HomeScore.Value,session.World.AwayScore.Value,gameSeconds)
		for _,participant in session.Players do
			local side=session.PlayerSides[participant]or"Home"
			local homeScore=session.World.HomeScore.Value
			local awayScore=session.World.AwayScore.Value
			local result="Draw"
			if session.RankedForceLossUserId==participant.UserId or session.ForfeitBy==participant.UserId then
				result="ForfeitLoss"
			elseif session.ForfeitBy then
				result="ForfeitWin"
			elseif homeScore~=awayScore then
				local sideWon=(side=="Home"and homeScore>awayScore)or(side=="Away"and awayScore>homeScore)
				result=sideWon and"Win"or"Loss"
			end
			if participant.Parent==Players then
				local shouldReturnToOrigin=(session.PrivateRankedMatch==true or session.PrivateAICampaignMatch==true) and session.ReturnPlaceId
				if shouldReturnToOrigin then
					self.PostMatchReturns[participant]={PlaceId=session.ReturnPlaceId,IssuedAt=os.clock()}
				elseif self.PostMatchReturns then
					self.PostMatchReturns[participant]=nil
				end
			if session.Ranked then
				participant:SetAttribute("VTRRankedMatchEnding",true)
				participant:SetAttribute("VTRRankedQueueLockedUntil",os.clock()+10)
			end
				local rewardPayload=rewards and rewards[participant.UserId]or nil
				local rankedWin=session.Ranked==true and(result=="Win"or result=="ForfeitWin")
				if rankedWin then
					rewardPayload=rewardPayload or{}
					if session.RankedWinPackGrant and rewardPayload.PackGranted~=true then
						local ok,packReward=pcall(session.RankedWinPackGrant,session,participant,rewardPayload)
						if ok and type(packReward)=="table"then
							for key,value in packReward do
								rewardPayload[key]=value
							end
						end
					end
					rewardPayload.PackChoices=rewardPayload.PackChoices or rankedPackChoices
					local definition=rewardPayload.PackId and Catalog.Packs[tostring(rewardPayload.PackId)]or nil
					rewardPayload.PackName=definition and definition.Name or rewardPayload.PackName or rewardPayload.Pack or"VOLTRA PACK"
					rewardPayload.Pack=rewardPayload.PackName
					rewardPayload.Rarity=definition and packRarity(definition) or rewardPayload.Rarity or"Rare"
				end
				self.State:FireClient(participant,{Type="MatchEnded",Ranked=session.Ranked,LocalSide=side,Result=result,Forfeit=session.ForfeitBy~=nil,ForfeitReason=session.ForfeitReason,RankedLossUserId=session.RankedForceLossUserId,Home=homeScore,Away=awayScore,PenaltyShootout=session.PenaltyShootout,PenaltyShootoutWinner=session.PenaltyShootoutWinner,ExtraTime=session.ExtraTimeStarted==true,Stats=resultStats,Reward=rewardPayload,RankedWinPack=rankedWin and rewardPayload or nil,ResultDelay=POST_FINAL_WHISTLE_RESULT_DELAY})
			end
		end
		if session.OnRankedEnded then task.defer(session.OnRankedEnded,session)end
		if session.OnCompleted then task.defer(session.OnCompleted,session)end
		task.delay(POST_MATCH_WORLD_CLEANUP_DELAY,function()
			for _,participant in session.Players or{player}do
				local character=participant.Character;local state=session.PlayerState and session.PlayerState[participant]
				if character then local accountRoot=character:FindFirstChild("HumanoidRootPart")::BasePart?;if accountRoot then accountRoot.Anchored=false end;character:SetAttribute("VTRParked",nil);character:SetAttribute("VTRCinematicParked",nil);character:SetAttribute("VTRSession",nil);character:SetAttribute("VTRSprinting",nil);character:PivotTo(safeReturnCFrame(state));local humanoid=character:FindFirstChildOfClass("Humanoid");if humanoid then humanoid.WalkSpeed=state and state.PreviousSpeed or 16;humanoid.JumpPower=state and state.PreviousJump or 50;humanoid.AutoRotate=true;humanoid.PlatformStand=false;humanoid.Sit=false;humanoid.Health=math.max(1,humanoid.MaxHealth);humanoid.PlatformStand=false;humanoid.Sit=false;humanoid.Health=math.max(1,humanoid.MaxHealth) end end
				session.TeamControl:Destroy(participant);self.Sessions[participant]=nil;if participant.Parent==Players then participant:SetAttribute("VTRInMatch",false)end
			end
			if session.LinkDebug then session.LinkDebug:Destroy()end;if session.AI then session.AI:Destroy()end;if session.Animations then session.Animations:Destroy()end;if session.OfficialAnimations then session.OfficialAnimations:Destroy()end;if session.World and session.World.Folder and session.World.Folder.Parent then session.World.Folder:Destroy()end
		end)
		return true
	end
	for _,participant in session.Players or{player}do
		local character=participant.Character;local state=session.PlayerState and session.PlayerState[participant]
		if character then local accountRoot=character:FindFirstChild("HumanoidRootPart")::BasePart?;if accountRoot then accountRoot.Anchored=false end;character:SetAttribute("VTRParked",nil);character:SetAttribute("VTRCinematicParked",nil);character:SetAttribute("VTRSession",nil);character:SetAttribute("VTRSprinting",nil);character:PivotTo(safeReturnCFrame(state));local humanoid=character:FindFirstChildOfClass("Humanoid");if humanoid then humanoid.WalkSpeed=state and state.PreviousSpeed or 16;humanoid.JumpPower=state and state.PreviousJump or 50;humanoid.AutoRotate=true;humanoid.PlatformStand=false;humanoid.Sit=false;humanoid.Health=math.max(1,humanoid.MaxHealth);humanoid.PlatformStand=false;humanoid.Sit=false;humanoid.Health=math.max(1,humanoid.MaxHealth) end end
		session.TeamControl:Destroy(participant);self.Sessions[participant]=nil;participant:SetAttribute("VTRInMatch",false)
	end
	if session.LinkDebug then session.LinkDebug:Destroy()end;if session.AI then session.AI:Destroy()end;if session.Animations then session.Animations:Destroy()end;if session.OfficialAnimations then session.OfficialAnimations:Destroy()end;if session.World.Folder.Parent then session.World.Folder:Destroy()end
	return true
end
function Service:ReturnToMenu(player:Player):boolean
	local pendingReturn=self.PostMatchReturns and self.PostMatchReturns[player]
	if pendingReturn then
		self.PostMatchReturns[player]=nil
		if player:GetAttribute("VTRRankedTeleporting")==true then return true end
		player:SetAttribute("VTRRankedTeleporting",true)
		local ok,err=pcall(function()
			TeleportService:TeleportAsync(tonumber(pendingReturn.PlaceId)or game.PlaceId,{player})
		end)
		if not ok then
			player:SetAttribute("VTRRankedTeleporting",nil)
			warn("[VTR RANKED RETURN] "..tostring(err))
		end
		return ok
	end
	local session=self.Sessions[player]
	if session and (session.PrivateRankedMatch==true or session.PrivateAICampaignMatch==true) and session.ReturnPlaceId then
		local returnPlaceId=session.ReturnPlaceId
		self:EndMatch(player,false)
		if self.PostMatchReturns then
			self.PostMatchReturns[player]={PlaceId=returnPlaceId,IssuedAt=os.clock()}
		end
		return self:ReturnToMenu(player)
	end
	return self:EndMatch(player,false)
end

function Service:PlayerRemoving(player:Player)
	if self.PostMatchReturns then self.PostMatchReturns[player]=nil end
	player:SetAttribute("VTRRankedTeleporting",nil)
	player:SetAttribute("VTRRankedQueueLockedUntil",os.clock()+10)
	local session=self.Sessions[player]
	if not session then return end
	if not session.Ended and session.Ranked then
		self:_applyRankedForfeit(session,player,"Leave")
		self:EndMatch(session.StepOwner,true)
	elseif not session.Ended and session.PrivateWorldCupMatch==true then
		self:_applyWorldCupForfeit(session,player,"Leave")
		self:EndMatch(session.StepOwner,true)
	else
		self:EndMatch(player,false)
	end
end
return Service
