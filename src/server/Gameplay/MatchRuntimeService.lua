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
local StaminaConfig=require(ReplicatedStorage.VTR.Shared.StaminaConfig)
local MatchFormatConfig=require(ReplicatedStorage.VTR.Shared.MatchFormatConfig)
local MatchExperienceConfig=require(ReplicatedStorage.VTR.Shared.MatchExperienceConfig)
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
local PlayBuilderConfig=require(ReplicatedStorage.VTR.Shared.PlayBuilderConfig)
local GoalModelResolver=require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local FormationService=require(script.Parent.FormationService)
local DeveloperAccessService=require(script.Parent.Parent.Services.DeveloperAccessService)
local GameplayDebugPolicy=require(script.Parent.GameplayDebugPolicy)
local ReplayRestartGate=require(script.Parent.ReplayRestartGate)
local Service={};Service.__index=Service
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
local function allParticipantsReady(session:any,field:string):boolean
	local ready=session[field]
	if type(ready)~="table"then return false end
	local count=0
	for _,participant in session.Players or{session.Player}do
		if participant.Parent==Players then
			count+=1
			if ready[participant]~=true then return false end
		end
	end
	return count>0
end
local function presentationStopped(session:any):boolean
	return session.Ended==true or session.PrematchSkipped==true or session.PresentationFinished==true
end
local function developmentAccess(player:Player):boolean
	return(RunService:IsStudio()or game.PrivateServerId~="")and DeveloperAccessService.IsAuthorized(player)
end
local function worldCupSession(session:any):boolean
	local setup=session and session.Setup or{}
	return session and session.PrivateWorldCupMatch==true or setup.WorldCup==true or setup.WorldCupSolo==true or setup.WorldCupOnboarding==true or setup.WorldCupTutorial==true or tostring(setup.Competition or"")=="WorldCup"
end
local function matchMode(session:any):string
	if session.Ranked then return"Ranked"end
	if session.FiveVFive then return"Play"end
	if session.ShootingPractice then return"ShootingPractice"end
	if worldCupSession(session)then return"WorldCup"end
	if session.Setup and session.Setup.CampaignAscension==true then return"Campaign"end
	return"Custom"
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
local function applyAscensionStadium(world:any,setup:any,homeKit:any)
	if setup.CampaignAscension~=true then return end
	local level=math.clamp(math.floor(tonumber(setup.StadiumAscensionLevel)or 0),0,3)
	world.Folder:SetAttribute("VTRAscensionStadiumLevel",level)
	if level>=2 then
		local primary=colorFromKitValue(homeKit and homeKit.Primary,Color3.fromHex("B7FF1A"))
		local secondary=colorFromKitValue(homeKit and homeKit.Secondary,Color3.fromHex("050505"))
		local index=0
		for _,instance in Workspace:GetDescendants()do
			if instance:IsA("BasePart")and(instance.Name=="StandForFans"or(instance.Name=="Stand"and instance:IsDescendantOf(world.Folder)))then
				index+=1
				instance.Color=index%3==0 and primary or secondary
				if level>=3 and index%6==0 then instance.Material=Enum.Material.Neon end
			end
		end
	end
	if level>=3 and setup.AscensionPromotionFinal==true then
		local model=Instance.new("Model")
		model.Name="AscensionTrophyDisplay"
		model.Parent=world.Folder
		local baseCFrame=world.PitchCFrame*CFrame.new(world.Width/2+8,1.2,-world.Length*.24)
		local gold=Color3.fromHex("F2C94C")
		part(model,"Base",Vector3.new(4,.8,4),baseCFrame,gold,false)
		local stem=part(model,"Stem",Vector3.new(2.8,.8,.8),baseCFrame*CFrame.new(0,1.7,0)*CFrame.Angles(0,0,math.rad(90)),gold,false)
		stem.Shape=Enum.PartType.Cylinder
		local cup=part(model,"Trophy",Vector3.new(2.7,2.7,2.7),baseCFrame*CFrame.new(0,3.25,0),gold,false)
		cup.Shape=Enum.PartType.Ball
		part(model,"Plinth",Vector3.new(2.2,.55,2.2),baseCFrame*CFrame.new(0,.7,0),Color3.fromHex("111111"),false)
	end
end
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
function Service.new()local action,state=Remotes.Create();local self=setmetatable({Action=action,State=state,Sessions={},PostMatchReturns={},CampaignAscension=nil,Analytics=nil},Service);action.OnServerEvent:Connect(function(player,payload)self:_action(player,payload)end);RunService.Heartbeat:Connect(function(dt)self:_step(dt)end);return self end
function Service:SetCampaignAscension(service:any)self.CampaignAscension=service end
function Service:SetAnalytics(service:any)self.Analytics=service end
function Service:_track(session:any,player:Player,eventName:string,properties:any?)
	if not self.Analytics then return end
	local fields={mode=matchMode(session),presentationProfile=tostring(session.PresentationProfile or"Standard"),matchFormat=tostring(session.MatchFormat or"Standard")}
	local state=session.PlayerState and session.PlayerState[player]
	if state then fields.device=tostring(state.Device or"Unknown");fields.assistanceMode=tostring(state.ReceiverAssistMode or"Standard");fields.cameraPreset=tostring(state.CameraPreset or"Auto")end
	for key,value in type(properties)=="table"and properties or{}do fields[key]=value end
	self.Analytics:TrackOnce(player,tostring(session.World and session.World.Folder.Name or session.StartedAt or"match"),eventName,fields)
end
function Service:_controlEnabled(session:any)
	if session.ControlEnabledAt then return end
	session.ControlEnabledAt=os.clock()
	for _,participant in session.Players do
		self:_track(session,participant,"playability_control_enabled",{stageDuration=session.ControlEnabledAt-(tonumber(session.StartedAt)or session.ControlEnabledAt)})
		if developmentAccess(participant)and self.Analytics then
			self.State:FireClient(participant,{Type="PlayabilityDiagnostics",Summary=self.Analytics:GetSummary(participant),ControlSeconds=session.ControlEnabledAt-(tonumber(session.StartedAt)or session.ControlEnabledAt)})
		end
	end
end
function Service:StartMatch(player:Player,setup:any,opponent:Player?,opponentSetup:any?,homeRoster:any?,awayRoster:any?):(boolean,string,any?)
	if self.Analytics then self.Analytics:MarkMatchRequested(player,{mode=opponent and"Ranked"or tostring(setup and(setup.Competition or setup.MatchType)or"Custom")});self.Analytics:Track(player,"playability_runtime_creation_started",{mode=opponent and"Ranked"or tostring(setup and(setup.Competition or setup.MatchType)or"Custom")})end
	self:EndMatch(player,false);if opponent then self:EndMatch(opponent,false)end
	local players={player};if opponent then table.insert(players,opponent)end
	local humanoids:any={};for _,participant in players do local character=participant.Character;local hum=character and character:FindFirstChildOfClass("Humanoid");if not character or not hum then return false,participant.Name.." is not ready.",nil end;humanoids[participant]=hum end
	local finalSetup=table.clone(setup);if opponentSetup then finalSetup.AwayTeamId=opponentSetup.HomeTeamId;finalSetup.AwayKit=opponentSetup.AwayKit or"Away"end
	finalSetup.MatchFormat=MatchFormatConfig.Normalize(finalSetup.MatchFormat or finalSetup.MatchLength)
	finalSetup.PresentationProfile=opponent and"Broadcast"or MatchExperienceConfig.Normalize(finalSetup.PresentationProfile)
	local format=MatchFormatConfig.Get(finalSetup.MatchFormat)
	local presentation=MatchExperienceConfig.Get(finalSetup.PresentationProfile)
	local noPrematch=finalSetup.NoPrematch==true or finalSetup.SkipPrematch==true or finalSetup.NoPresentation==true or finalSetup.FiveVFive==true
	local home=homeRoster or TeamDatabase.GetRoster(finalSetup.HomeTeamId);local away=awayRoster or TeamDatabase.GetRoster(finalSetup.AwayTeamId);if not home or not away then return false,"Selected rosters are unavailable.",nil end
	local world=buildWorld(player,finalSetup);local teams,formation,kits=TeamSpawnService.Spawn(world.Folder,world.PitchCFrame,world.Width,world.Length,player,home,away,finalSetup);applyStandForFansColors(kits and kits.Home);applyAscensionStadium(world,finalSetup,kits and kits.Home);local models={};for _,m in teams.Home do table.insert(models,m)end;for _,m in teams.Away do table.insert(models,m)end;BallCollisionService.ApplyPlayers(models);for _,m in models do m:SetAttribute("VTRSession",player.UserId);m:SetAttribute("VTRRankedMatch",opponent~=nil)end
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
	local stats=StatsService.new(models,world.PitchCFrame,world.Width,world.Length);local possession=PossessionService.new(world.Ball,self.State);local animations=MatchAnimationService.new(models);local ballService=BallService.new(world.Ball,possession,self.State,stats,models,animations);local teamControl=TeamControlService.new(self.State,teams,world.Ball,possession,ballService,world.PitchCFrame,world.Width,world.Length,animations);local duration=math.max(60,tonumber(format.RealSeconds)or 300);local practiceMode=finalSetup.ShootingPractice==true
	local session={Player=player,Players=players,SidePlayers={Home=player,Away=opponent},PlayerSides={[player]="Home"},PlayerState={},StepOwner=player,Ranked=opponent~=nil,ShootingPractice=practiceMode,Setup=finalSetup,World=world,Teams=teams,Kits=kits,Formation=formation,Models=models,Stats=stats,Possession=possession,BallService=ballService,Animations=animations,TeamControl=teamControl,Grounding=BallGroundingService.new(world.Ball,world.PitchCFrame,models),Clock=MatchClockService.new(duration),StaminaService=StaminaService.new(),Remaining=duration,Duration=duration,MatchFormat=finalSetup.MatchFormat,Format=format,PresentationProfile=finalSetup.PresentationProfile,Presentation=presentation,NoPrematch=noPrematch,ClientReady={},PresentationReady={},MatchStartPayloads={},HalfTimeTriggered=false,Phase=practiceMode and"SHOOTING PRACTICE"or"PRE MATCH",Running=false,Ended=false,Accumulator=0,StartedAt=os.clock(),LastPositions={},MovementSpeeds={},BenchData={Home=home.Bench or{},Away=away.Bench or{}},UsedBench={Home={},Away={}},PauseSecondsByPlayer={},PauseRequester=nil,PauseResumeVotes={},PauseGrantIndex=0,PauseTimerAccumulator=0,PrematchSkipUnlockAt=os.clock()+(noPrematch and 0 or math.max(0,tonumber(presentation.SkipLock)or 0)),Connections={postGoalAnchorGuard}}
	session.LinkDebug=GameplayLinkDebugService.new()
	if opponent then session.PlayerSides[opponent]="Away"end
	for _,participant in players do local hum=humanoids[participant];session.PlayerState[participant]={Stamina=Config.Stamina.Maximum,Endurance=Config.Stamina.Maximum,SprintRequested=false,SprintActual=false,SprintLastSignalAt=0,PreviousSpeed=hum.WalkSpeed,PreviousJump=hum.JumpPower,ReturnCFrame=parkedReturnCFrames[participant] or CFrame.new(0,8,0)};session.PauseSecondsByPlayer[participant]=60;hum.WalkSpeed=0;hum.JumpPower=0;participant:SetAttribute("VTRInMatch",true);self.Sessions[participant]=session end
	for _,model in models do local modelRoot=model:FindFirstChild("HumanoidRootPart")::BasePart?;if modelRoot then session.LastPositions[model]=modelRoot.Position end end
	if finalSetup.WorldCupTutorial==true then world.Ball:SetAttribute("VTRTutorialPhysics",true)end
	session.Goals=GoalService.new(world.Ball,world.PitchCFrame,world.Width,world.Length,function(team)self:_goal(session,team)end);session.AI=AIService.new(teams,formation,world.PitchCFrame,world.Width,world.Length,finalSetup.Difficulty,world.Ball,possession,ballService,finalSetup.TeamTactics);session.Goalkeepers=GoalkeeperService.new(world.Ball,teams,world.PitchCFrame,world.Width,world.Length,ballService,animations,self.State,session.AI);session.SetPieces=SetPieceService.new(self.State,world,teams,formation,possession,teamControl,ballService,function()return session.Paused==true end);session.OutOfBounds=OutOfBoundsService.new(world.Ball,world.PitchCFrame,world.Width,world.Length,ballService,function(kind,restartTeam,location)self:_startSetPiece(session,kind,restartTeam,location)end)
	if finalSetup.CampaignAscension==true and session.AI and session.AI.UpdateTactics then
		if type(finalSetup.AscensionOpponentTactics)=="table"then session.AI:UpdateTactics("Away",sanitizeRuntimeTactics(finalSetup.AscensionOpponentTactics))end
		if type(finalSetup.AscensionCounterPlan)=="string"and finalSetup.AscensionCounterPlan~=""then session.AI:UpdateTactics("Home",sanitizeRuntimeTactics({Identity=finalSetup.AscensionCounterPlan}))end
	end
	if session.AI and session.AI.SetManualTackleSides then
		local manualTackleSides:any={}
		if finalSetup.WatchMode~=true and not practiceMode then
			for _,side in session.PlayerSides do
				manualTackleSides[side]=true
			end
		end
		session.AI:SetManualTackleSides(manualTackleSides)
	end
	session.Referee=RefereeService.new(self.State,stats,function(restartTeam:string,location:Vector3,restartKind:string?,forcedTaker:Model?)if not session.Ended then self:_startSetPiece(session,restartKind or "FreeKick",restartTeam,location,forcedTaker)end end,world.PitchCFrame,world.Width,world.Length);session.Referee.RedCardsEnabled=finalSetup.RedCardsEnabled~=false;ballService:SetReferee(session.Referee)
	session.Offside=OffsideService.new(self.State,stats,teams,world.PitchCFrame,function(restartTeam:string,location:Vector3)if not session.Ended then session.World.Ball:SetAttribute("VTRRestartDisplayKind","Offside");self:_startSetPiece(session,"FreeKick",restartTeam,location)end end);ballService:SetOffsideService(session.Offside)
	if finalSetup.WorldCupOnboarding==true then
		session.WorldCupOnboarding=true
		session.WorldCupTutorial=finalSetup.WorldCupTutorial==true
		session.WorldCupFirstPassPending=false
		world.Ball:SetAttribute("VTRWorldCupFirstPassPending",nil)
		session.OffsideDisabled=true
		ballService:SetOffsideService(nil)
		if session.SetPieces then session.SetPieces.OnboardingNoAutoKickoff=true end
	end
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
	for _,participant in players do
		local side=session.PlayerSides[participant]
		local activePlayer=watchMode and(teams.Home[10]or teams.Home[1])or teamControl:Register(participant,side)
		if session.WorldCupTutorial==true and not watchMode then
			local tutorialStarter=teams.Home[10]or teams.Home[9]or teams.Home[1]
			if tutorialStarter then
				teamControl:SetActive(participant,tutorialStarter,"TutorialMovement")
				activePlayer=tutorialStarter
			end
		end
		local payload={Type="MatchStarted",MatchSessionId=world.Folder.Name,Ranked=session.Ranked,WatchMode=watchMode,PracticeMode=practiceMode,DeveloperAccess=developmentAccess(participant)and not session.Ranked and not worldCupSession(session),Setup=finalSetup,MatchFormat=session.MatchFormat,PresentationProfile=session.PresentationProfile,PresentationDuration=tonumber(presentation.Duration)or 8,ForceCameraMode=finalSetup.ForceCameraMode,NoPrematch=noPrematch,PrematchSkipDelay=(practiceMode or noPrematch)and 0 or math.max(0,tonumber(presentation.SkipLock)or 0),ControlledSide=side,Opponent=opponent and(opponent==participant and player.Name or opponent.Name)or(watchMode and"AI vs AI"or(practiceMode and"Goalkeeper"or"AI")),WorldName=world.Folder.Name,Ball=world.Ball,Home=home.Team.teamName,Away=away.Team.teamName,HomeSummary=homeSummary,AwaySummary=awaySummary,HomeLogo=home.Team.logo,AwayLogo=away.Team.logo,HomeFlagImage=home.Team.FlagImage or home.Team.flagImage or homeSummary.FlagImage or homeSummary.flagImage,AwayFlagImage=away.Team.FlagImage or away.Team.flagImage or awaySummary.FlagImage or awaySummary.flagImage,HomeBadgeIdentity=home.Team.BadgeIdentity or home.Team.badgeIdentity or homeSummary.BadgeIdentity or homeSummary.badgeIdentity,AwayBadgeIdentity=away.Team.BadgeIdentity or away.Team.badgeIdentity or awaySummary.BadgeIdentity or awaySummary.badgeIdentity,HomeColor=home.Team.colors.Primary,AwayColor=away.Team.colors.Primary,HomeTeamId=home.Team.teamId,AwayTeamId=away.Team.teamId,HomeKitData=kits and kits.Home or nil,AwayKitData=kits and kits.Away or nil,HomeFormation=home.Formation or home.Team.formation or finalSetup.HomeFormation or "4-3-3",AwayFormation=away.Formation or away.Team.formation or finalSetup.AwayFormation or "4-3-3",HomeSetup={Formation=home.Formation or home.Team.formation or "4-3-3"},AwaySetup={Formation=away.Formation or away.Team.formation or "4-3-3"},HomeLineup=home.StartingXI or{},AwayLineup=away.StartingXI or{},HomeBench=home.Bench or{},AwayBench=away.Bench or{},Duration=session.Remaining,Difficulty=finalSetup.Difficulty,ActivePlayer=activePlayer,ActivePlayerName=activePlayer and activePlayer.Name or nil,TeamModels=teams,PitchCFrame=world.PitchCFrame,PitchWidth=world.Width,PitchLength=world.Length}
		session.MatchStartPayloads[participant]=payload
		self.State:FireClient(participant,payload)
		self:_track(session,participant,"playability_runtime_ready",{stageDuration=os.clock()-session.StartedAt})
		self:_track(session,participant,"playability_active_player_assigned",{})
	end
	self:_beginClientReadiness(session)
	return true,practiceMode and"Shooting practice loaded."or(opponent and"Ranked 1v1 match loaded."or(watchMode and"AI vs AI match loaded."or"Playable AI match loaded.")),{Setup=finalSetup,Home=homeSummary,Away=awaySummary,WorldName=world.Folder.Name,Objective="PLAY YOUR FIRST MATCH",ObjectiveCompletedNow=not watchMode and not practiceMode,WatchMode=watchMode,PracticeMode=practiceMode}
end

function Service:StartRankedMatch(homePlayer:Player,awayPlayer:Player,homeSetup:any,awaySetup:any,homeRoster:any,awayRoster:any):(boolean,string,any?)
	return self:StartMatch(homePlayer,homeSetup,awayPlayer,awaySetup,homeRoster,awayRoster)
end

local FIVE_V_FIVE_SLOTS = {
	{Position = "GK", Label = "GK", Automatic = true, X = 0, Y = -54},
	{Position = "CB", Label = "CB", X = 0, Y = -28},
	{Position = "MID", Label = "MID", X = -22, Y = 4},
	{Position = "MID", Label = "MID", X = 22, Y = 4},
	{Position = "CF", Label = "CF", X = -15, Y = 38},
	{Position = "CF", Label = "CF", X = 15, Y = 38},
}

local function fiveVFiveSlots(teamSize:number): {any}
	teamSize = math.clamp(math.floor(tonumber(teamSize) or 5), 3, 5)
	if teamSize == 3 then
		return {FIVE_V_FIVE_SLOTS[1], FIVE_V_FIVE_SLOTS[2], FIVE_V_FIVE_SLOTS[3], FIVE_V_FIVE_SLOTS[5]}
	elseif teamSize == 4 then
		return {FIVE_V_FIVE_SLOTS[1], FIVE_V_FIVE_SLOTS[2], FIVE_V_FIVE_SLOTS[3], FIVE_V_FIVE_SLOTS[4], FIVE_V_FIVE_SLOTS[5]}
	end
	return FIVE_V_FIVE_SLOTS
end

local function fiveVFiveCard(name: string, userId: number?, slot: any, index: number, builder: any?): any
	builder = userId and userId > 0 and PlayBuilderConfig.Normalize(builder) or nil
	local stats = builder and PlayBuilderConfig.StatsFor(builder) or nil
	local role = tostring(slot.Position or builder and builder.Role or "MID")
	return {
		playerId = "fivevfive_" .. tostring(userId or index) .. "_" .. tostring(index),
		AppearanceUserId = userId,
		UserId = userId,
		cardInstanceId = "",
		displayName = name,
		shortName = name,
		bestPosition = role,
		Position = role,
		overall = stats and stats.overall or 70,
		rarity = "Common",
		cardType = "MyPlayer",
		PAC = stats and stats.PAC or 70,
		SHO = stats and stats.SHO or 70,
		PAS = stats and stats.PAS or 70,
		DRI = stats and stats.DRI or 70,
		DEF = stats and stats.DEF or 70,
		PHY = stats and stats.PHY or 70,
		acceleration = stats and stats.acceleration or 70,
		agility = stats and stats.agility or 70,
		stamina = stats and stats.stamina or 70,
		shotPower = stats and stats.shotPower or 70,
		longShots = stats and stats.longShots or 70,
		standingTackle = stats and stats.standingTackle or 70,
		slidingTackle = stats and stats.slidingTackle or 70,
		dribbling = stats and stats.dribbling or 70,
		positions = {role},
		PlayBuilder = builder,
		PlayArchetype = builder and builder.Archetype or nil,
		PlayTraitA = builder and builder.TraitA or nil,
		PlayTraitB = builder and builder.TraitB or nil,
		PlayTraitLevels = builder and builder.Traits or nil,
		PlayStyle = builder and builder.Style or nil,
		FormationCoordinate = {X = slot.X, Y = slot.Y},
		FormationLabel = slot.Label,
		ExpectedPosition = slot.Position,
	}
end

local function fiveVFiveTeam(side: string, players: {Player}, color: string, accent: string, teamSize: number, buildersByUserId: {[number]: any}?): any
	local starting = {}
	for index, slot in fiveVFiveSlots(teamSize) do
		local source = slot.Automatic and nil or players[index - 1]
		local builder = source and buildersByUserId and buildersByUserId[source.UserId] or nil
		table.insert(starting, fiveVFiveCard(source and (source.DisplayName ~= "" and source.DisplayName or source.Name) or (side .. " AUTO GK"), source and source.UserId or 0, slot, index, builder))
	end
	local starPlayers = {}
	for index = 1, math.min(3, #starting) do
		table.insert(starPlayers, starting[index])
	end
	local totalOverall = 0
	local counted = 0
	for _, playerCard in starting do
		if tonumber(playerCard.UserId) and tonumber(playerCard.UserId) > 0 then
			totalOverall += tonumber(playerCard.overall) or 70
			counted += 1
		end
	end
	local teamOverall = counted > 0 and math.floor(totalOverall / counted + 0.5) or 70
	return {
		Team = {
			teamId = "fivevfive_" .. string.lower(side),
			teamName = side == "Home" and "5V5 HOME" or "5V5 AWAY",
			logo = side == "Home" and "H" or "A",
			country = "ONLINE",
			league = "5V5",
			overall = teamOverall,
			attack = teamOverall,
			midfield = teamOverall,
			defense = teamOverall,
			colors = {Primary = color, Secondary = "050505", Accent = accent},
			kits = {
				Home = {Primary = color, Secondary = "050505", Accent = accent, NumberColor = "050505", Style = "Solid"},
				Away = {Primary = color, Secondary = "050505", Accent = accent, NumberColor = "050505", Style = "Solid"},
			},
			formation = "5V5",
			starPlayers = starPlayers,
		},
		Formation = "5V5",
		StartingXI = starting,
		Bench = {},
	}
end

function Service:StartFiveVFiveMatch(participants: {Player}, data: any): (boolean, string, any?)
	local teamSize = math.clamp(math.floor(tonumber(data and data.TeamSize) or 5), 3, 5)
	local required = teamSize * 2
	if #participants < required then return false, "Need " .. tostring(required) .. " players for this lobby.", nil end
	for _, participant in participants do self:EndMatch(participant, false) end
	local homePlayers = {}
	local awayPlayers = {}
	local teamByUserId = {}
	local buildersByUserId = {}
	if type(data and data.Players) == "table" then
		for _, entry in data.Players do
			local userId = tonumber(entry.UserId)
			local team = tostring(entry.Team or "")
			if userId then
				buildersByUserId[userId] = PlayBuilderConfig.Normalize(entry.PlayBuilder)
			end
			if userId and (team == "Home" or team == "Away") then
				teamByUserId[userId] = team
			end
		end
	end
	for _, participant in participants do
		local team = teamByUserId[participant.UserId]
		if team == "Home" and #homePlayers < teamSize then
			table.insert(homePlayers, participant)
		elseif team == "Away" and #awayPlayers < teamSize then
			table.insert(awayPlayers, participant)
		end
	end
	for _, participant in participants do
		if not table.find(homePlayers, participant) and not table.find(awayPlayers, participant) then
			if #homePlayers < teamSize then
				table.insert(homePlayers, participant)
			elseif #awayPlayers < teamSize then
				table.insert(awayPlayers, participant)
			end
		end
	end
	if #homePlayers ~= teamSize or #awayPlayers ~= teamSize then return false, "5v5 teams were not assigned correctly.", nil end
	local setup = {
		MatchLength = 8,
		Difficulty = "World Class",
		MatchType = "FiveVFive",
		HomeTeamId = "fivevfive_home",
		AwayTeamId = "fivevfive_away",
		HomeKit = "Home",
		AwayKit = "Away",
		Weather = "Clear",
		Time = "Evening",
		Completed = true,
		FiveVFive = true,
		SkipPrematch = true,
		NoPresentation = true,
		RedCardsEnabled = false,
		ForceCameraMode = "PlayThirdPerson",
	}
	local homeRoster = fiveVFiveTeam("Home", homePlayers, "B7FF1A", "FFFFFF", teamSize, buildersByUserId)
	local awayRoster = fiveVFiveTeam("Away", awayPlayers, "2F6BFF", "FFFFFF", teamSize, buildersByUserId)
	local success, message, payload = self:StartMatch(homePlayers[1], setup, awayPlayers[1], setup, homeRoster, awayRoster)
	if not success then return success, message, payload end
	local session = self:GetSession(homePlayers[1])
	if not session then return false, "5v5 session did not start.", nil end
	session.FiveVFive = true
	session.MatchId = tostring(data and data.MatchId or HttpService:GenerateGUID(false))
	session.ReturnPlaceId = tonumber(data and data.ReturnPlaceId) or game.PlaceId
	local function attachParticipant(participant: Player, side: string, model: Model?)
		local character = participant.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not character or not root then return end
		if not table.find(session.Players, participant) then table.insert(session.Players, participant) end
		session.PlayerSides[participant] = side
		self.Sessions[participant] = session
		session.PlayerState[participant] = session.PlayerState[participant] or {
			Stamina = Config.Stamina.Maximum,
			Endurance = Config.Stamina.Maximum,
			SprintRequested = false,
			SprintActual = false,
			SprintLastSignalAt = 0,
			PreviousSpeed = hum.WalkSpeed,
			PreviousJump = hum.JumpPower,
			ReturnCFrame = character:GetPivot(),
		}
		session.PauseSecondsByPlayer[participant] = session.PauseSecondsByPlayer[participant] or 60
		character:PivotTo(session.World.PitchCFrame * CFrame.new(side == "Home" and -18 or 18, -85, 0))
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		character:SetAttribute("VTRParked", true)
		character:SetAttribute("VTRCinematicParked", true)
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		participant:SetAttribute("VTRInMatch", true)
		if model then
			session.TeamControl.PlayerSides[participant] = side
			if session.TeamControl.LockActive then
				session.TeamControl:LockActive(participant, model, "FiveVFive")
			else
				session.TeamControl:SetActive(participant, model, "FiveVFive")
			end
			model:SetAttribute("VTRFiveVFiveAssignedUserId", participant.UserId)
		end
	end
	for index, participant in homePlayers do
		local model = session.Teams.Home[index + 1]
		attachParticipant(participant, "Home", model)
	end
	for index, participant in awayPlayers do
		local model = session.Teams.Away[index + 1]
		attachParticipant(participant, "Away", model)
	end
	for _, model in session.Teams.Home do
		model:SetAttribute("VTRFiveVFive", true)
		if tostring(model:GetAttribute("position") or "") == "GK" then
			model:SetAttribute("VTRFiveVFiveAIKeeper", true)
			model:SetAttribute("controlledByUser", false)
			model:SetAttribute("aiControlled", true)
			model:SetAttribute("VTRUserId", nil)
		end
	end
	for _, model in session.Teams.Away do
		model:SetAttribute("VTRFiveVFive", true)
		if tostring(model:GetAttribute("position") or "") == "GK" then
			model:SetAttribute("VTRFiveVFiveAIKeeper", true)
			model:SetAttribute("controlledByUser", false)
			model:SetAttribute("aiControlled", true)
			model:SetAttribute("VTRUserId", nil)
		end
	end
	local summaryHome = {teamName = homeRoster.Team.teamName, logo = homeRoster.Team.logo, overall = homeRoster.Team.overall, attack = homeRoster.Team.attack, midfield = homeRoster.Team.midfield, defense = homeRoster.Team.defense, colors = homeRoster.Team.colors}
	local summaryAway = {teamName = awayRoster.Team.teamName, logo = awayRoster.Team.logo, overall = awayRoster.Team.overall, attack = awayRoster.Team.attack, midfield = awayRoster.Team.midfield, defense = awayRoster.Team.defense, colors = awayRoster.Team.colors}
	local function fireStart(participant: Player)
		local side = session.PlayerSides[participant] or "Home"
		local activePlayer = session.TeamControl:GetActive(participant)
		local startPayload = {
			Type = "MatchStarted",
			MatchSessionId = session.World.Folder.Name,
			Ranked = false,
			FiveVFive = true,
			ForceCameraMode = "PlayThirdPerson",
			WatchMode = false,
			PracticeMode = false,
			NoPrematch = true,
			PrematchSkipDelay = 0,
			ControlledSide = side,
			Opponent = side == "Home" and "5V5 AWAY" or "5V5 HOME",
			WorldName = session.World.Folder.Name,
			Ball = session.World.Ball,
			Home = homeRoster.Team.teamName,
			Away = awayRoster.Team.teamName,
			HomeSummary = summaryHome,
			AwaySummary = summaryAway,
			HomeLogo = homeRoster.Team.logo,
			AwayLogo = awayRoster.Team.logo,
			HomeColor = homeRoster.Team.colors.Primary,
			AwayColor = awayRoster.Team.colors.Primary,
			HomeTeamId = homeRoster.Team.teamId,
			AwayTeamId = awayRoster.Team.teamId,
			HomeKitData = session.Kits and session.Kits.Home or nil,
			AwayKitData = session.Kits and session.Kits.Away or nil,
			HomeFormation = "5V5",
			AwayFormation = "5V5",
			HomeSetup = {Formation = "5V5"},
			AwaySetup = {Formation = "5V5"},
			HomeLineup = homeRoster.StartingXI,
			AwayLineup = awayRoster.StartingXI,
			HomeBench = {},
			AwayBench = {},
			Duration = session.Remaining,
			Difficulty = "World Class",
			ActivePlayer = activePlayer,
			ActivePlayerName = activePlayer and activePlayer.Name or nil,
			TeamModels = session.Teams,
			PitchCFrame = session.World.PitchCFrame,
			PitchWidth = session.World.Width,
			PitchLength = session.World.Length,
		}
		self.State:FireClient(participant, startPayload)
	end
	for _, participant in session.Players do fireStart(participant) end
	return true, "5v5 match loaded.", payload
end

function Service:GetFiveVFiveSession(matchId: string): any?
	for _, session in self.Sessions do
		if session and session.FiveVFive==true and tostring(session.MatchId or "")==tostring(matchId or "") and not session.Ended then
			return session
		end
	end
	return nil
end

function Service:GetFiveVFiveSessions(): {any}
	local sessions = {}
	local seen: {[any]: boolean} = {}
	for _, session in self.Sessions do
		if session and session.FiveVFive==true and not session.Ended and not seen[session] then
			seen[session] = true
			table.insert(sessions, session)
		end
	end
	return sessions
end

function Service:CancelFiveVFiveMatches(reason: string?): {any}
	local cancelled = {}
	for _, session in self:GetFiveVFiveSessions() do
		local players = {}
		for _, participant in session.Players or {} do
			table.insert(players, {UserId = participant.UserId, Name = participant.Name, DisplayName = participant.DisplayName})
		end
		table.insert(cancelled, {MatchId = tostring(session.MatchId or ""), Players = players})
		session.ForfeitReason = reason or "DeveloperCancel"
		session.FiveVFiveCancelled = true
		self:EndMatch(session.StepOwner, true)
	end
	return cancelled
end

function Service:RejoinFiveVFivePlayer(player: Player, data: any): (boolean, string)
	local session = self:GetFiveVFiveSession(tostring(data and data.MatchId or ""))
	if not session then return false, "5v5 match is no longer running." end
	local assigned: Model? = nil
	local side = "Home"
	for _, teamSide in {"Home","Away"} do
		for _, model in session.Teams[teamSide] or {} do
			if tonumber(model:GetAttribute("VTRFiveVFiveAssignedUserId")) == player.UserId then
				assigned = model
				side = teamSide
				break
			end
		end
	end
	if not assigned then return false, "Your 5v5 slot was not found." end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not hum or not root then return false, "Character is not ready." end
	if not table.find(session.Players, player) then table.insert(session.Players, player) end
	session.PlayerSides[player] = side
	self.Sessions[player] = session
	session.PlayerState[player] = {
		Stamina = Config.Stamina.Maximum,
		Endurance = Config.Stamina.Maximum,
		SprintRequested = false,
		SprintActual = false,
		SprintLastSignalAt = 0,
		PreviousSpeed = hum.WalkSpeed,
		PreviousJump = hum.JumpPower,
		ReturnCFrame = character:GetPivot(),
	}
	session.PauseSecondsByPlayer[player] = 60
	character:PivotTo(session.World.PitchCFrame * CFrame.new(side=="Home" and -18 or 18, -85, 0))
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:SetAttribute("VTRParked", true)
	character:SetAttribute("VTRCinematicParked", true)
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	player:SetAttribute("VTRInMatch", true)
	session.TeamControl.PlayerSides[player] = side
	if session.TeamControl.LockActive then
		session.TeamControl:LockActive(player, assigned, "FiveVFiveRejoin")
	else
		session.TeamControl:SetActive(player, assigned, "FiveVFiveRejoin")
	end
	local payload = {
		Type = "MatchStarted",
		MatchSessionId = session.World.Folder.Name,
		Ranked = false,
		FiveVFive = true,
		ForceCameraMode = "PlayThirdPerson",
		WatchMode = false,
		PracticeMode = false,
		PrematchSkipDelay = 0,
		ControlledSide = side,
		Opponent = side=="Home" and "5V5 AWAY" or "5V5 HOME",
		WorldName = session.World.Folder.Name,
		Ball = session.World.Ball,
		Home = "5V5 HOME",
		Away = "5V5 AWAY",
		HomeSummary = {teamName="5V5 HOME",logo="H",overall=70,attack=70,midfield=70,defense=70},
		AwaySummary = {teamName="5V5 AWAY",logo="A",overall=70,attack=70,midfield=70,defense=70},
		HomeLogo = "H",
		AwayLogo = "A",
		HomeColor = "B7FF1A",
		AwayColor = "2F6BFF",
		HomeTeamId = "fivevfive_home",
		AwayTeamId = "fivevfive_away",
		HomeFormation = "5V5",
		AwayFormation = "5V5",
		HomeSetup = {Formation="5V5"},
		AwaySetup = {Formation="5V5"},
		HomeLineup = {},
		AwayLineup = {},
		HomeBench = {},
		AwayBench = {},
		Duration = session.Remaining,
		Difficulty = "World Class",
		ActivePlayer = assigned,
		ActivePlayerName = assigned.Name,
		TeamModels = session.Teams,
		PitchCFrame = session.World.PitchCFrame,
		PitchWidth = session.World.Width,
		PitchLength = session.World.Length,
	}
	self.State:FireClient(player, payload)
	return true, "Rejoined 5v5 match."
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
	if presentationStopped(session)then return end
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
		while model.Parent and not finished and not presentationStopped(session)do task.wait()end
		connection:Disconnect()
		if session.PresentationTweens then session.PresentationTweens[tween]=nil end
		tween:Cancel()
	end
	if presentationStopped(session)then
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
	if presentationStopped(session)then return end
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
		if presentationStopped(session)then return end
		task.wait(.05)
	end
	if presentationStopped(session)then return end
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

function Service:_finishPrematchPresentation(session:any)
	if session.Ended or session.PresentationFinished or session.Phase~="PRE MATCH"then return end
	session.PresentationFinished=true
	self:_cancelPrematchPresentation(session)
	self:_teleportPresentationStage(session,"Kickoff","KickoffReady")
	self:_destroyPresentationOfficials(session)
	for _,model in session.Models do
		local root=modelRoot(model)
		if root then root.Anchored=true;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
		model:SetAttribute("VTRPresentationState","KickoffReady")
		model:SetAttribute("VTRForceIdle",true)
	end
	self:_syncPositions(session)
	task.delay(.15,function()
		if self.Sessions[session.Player]==session and not session.Ended and session.Phase=="PRE MATCH"then
			self:_startSetPiece(session,"Kickoff","Home",session.World.PitchCFrame.Position)
		end
	end)
end

function Service:_startPrematchPresentation(session:any)
	if session.PresentationActive or session.PresentationFinished then return end
	session.PresentationActive=true
	session.PresentationStartedAt=os.clock()
	for _,participant in session.Players do self:_track(session,participant,"playability_presentation_started",{})end
	local profile=tostring(session.PresentationProfile or"Standard")
	local duration=math.max(1,tonumber(session.Presentation and session.Presentation.Duration)or 8)
	if profile~="Broadcast"then
		self:_teleportPresentationStage(session,"Kickoff","KickoffReady")
		task.spawn(function()
			local earliest=session.PresentationStartedAt+math.max(.5,duration-.35)
			local deadline=session.PresentationStartedAt+duration
			while not presentationStopped(session)and os.clock()<deadline do
				if os.clock()>=earliest and allParticipantsReady(session,"PresentationReady")then break end
				task.wait(.05)
			end
			if not presentationStopped(session)then self:_finishPrematchPresentation(session)end
		end)
		return
	end
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
		task.wait(math.min(1.5,duration*.08))
		if presentationStopped(session)then return end
		self:_movePresentationStage(session,"Walkout",math.min(4,duration*.22))
		if presentationStopped(session)then return end
		self:_teleportPresentationStage(session,"Lineup","LineupIdle")
		local kickoffAt=session.PresentationStartedAt+math.max(5,duration-2.5)
		while not presentationStopped(session)and os.clock()<kickoffAt do task.wait(.05)end
		if presentationStopped(session)then return end
		self:_teleportPresentationStage(session,"Kickoff","KickoffReady")
		self:_destroyPresentationOfficials(session)
		local earliest=session.PresentationStartedAt+math.max(1,duration-.35)
		local deadline=session.PresentationStartedAt+duration
		while not presentationStopped(session)and os.clock()<deadline do
			if os.clock()>=earliest and allParticipantsReady(session,"PresentationReady")then break end
			task.wait(.05)
		end
		if not presentationStopped(session)then self:_finishPrematchPresentation(session)end
	end)
end

function Service:_beginClientReadiness(session:any)
	if session.ReadinessStarted then return end
	session.ReadinessStarted=true
	task.spawn(function()
		local timeout=math.max(2,tonumber(session.Presentation and session.Presentation.ReadinessTimeout)or 6)
		local deadline=os.clock()+timeout
		while not session.Ended and not allParticipantsReady(session,"ClientReady")and os.clock()<deadline do task.wait(.05)end
		if session.Ended or self.Sessions[session.Player]~=session then return end
		session.ReadinessCompletedAt=os.clock()
		if session.WorldCupTutorial==true then
			self:_startWorldCupTutorial(session)
			self:_controlEnabled(session)
		elseif session.ShootingPractice==true then
			self:_resetShootingPractice(session,"START")
			self:_controlEnabled(session)
		elseif session.NoPrematch==true then
			session.PrematchSkipped=true
			self:_startSetPiece(session,"Kickoff","Home",session.World.PitchCFrame.Position)
		else
			for _,participant in session.Players do
				local payload=session.MatchStartPayloads[participant]
				if payload and participant.Parent==Players then
					local presentationPayload=table.clone(payload)
					presentationPayload.Type="PresentationStart"
					self.State:FireClient(participant,presentationPayload)
				end
			end
			self:_startPrematchPresentation(session)
		end
	end)
end

function Service:_skipPrematch(session:any)
	if session.Ended or session.PrematchSkipped or session.PrematchSkipInProgress or session.Phase~="PRE MATCH"then return end
	session.PrematchSkipInProgress=true
	session.PrematchSkipped=true
	for _,participant in session.Players do self:_track(session,participant,"playability_presentation_skipped",{stageDuration=os.clock()-(tonumber(session.PresentationStartedAt)or os.clock())})end
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

function Service:_forceEndPrematchForResult(session:any,reason:string?)
	if not session or session.Ended or session.Phase~="PRE MATCH"then return end
	session.PrematchSkipped=true
	session.PrematchSkipInProgress=false
	session.PresentationFinished=true
	session.PresentationReady=session.PresentationReady or{}
	for _,participant in session.Players or{}do
		session.PresentationReady[participant]=true
	end
	self:_cancelPrematchPresentation(session)
	broadcast(self.State,session,{Type="PrematchCancelled",Reason=reason or"Result"})
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
	if frozen then
		for _,state in session.PlayerState or{}do state.SprintRequested=false;state.SprintActual=false;state.SprintLastSignalAt=0 end
	end
	for _,model in session.Models do
		model:SetAttribute("VTRFrozen",frozen)
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


local function reviveMatchBallForKickoff(session:any,reason:string?)
	local ball=session.World and session.World.Ball
	if not ball or not ball.Parent then
		return
	end

	pcall(function()GoalShotPassThroughService.Clear(ball)end)
	pcall(function()BallCollisionService.ApplyBall(ball)end)

	ball.Anchored=false
	ball.CanCollide=true
	ball.CanTouch=true
	ball.CanQuery=true
	ball.Massless=false
	ball.Transparency=0
	pcall(function()ball.LocalTransparencyModifier=0 end)
	ball.AssemblyLinearVelocity=Vector3.zero
	ball.AssemblyAngularVelocity=Vector3.zero
	ball.CFrame=CFrame.new(session.World.PitchCFrame.Position+Vector3.new(0,Config.Ball.Radius+.2,0))
	setServerNetworkOwner(ball)

	for _,attribute in{"OwnerModel","OwnerUserId","VTRWorldPaused","VTRPauseSavedVelocity","VTRPauseSavedAngularVelocity","VTRPostGoalPhysicsUntil","VTRPostGoalVelocity","VTRPostGoalAngularVelocity","VTRGoalCalledAt","VTRGoalEntryVelocity","VTRGoalEntryAngularVelocity","VTRGoalEntryPosition","VTRGoalEntryNormal","VTRPenaltyShotActive","VTRGoalkeeperHeld","VTRGoalkeeperTracking","VTRGoalkeeperReleaseCameraUntil","VTRPassTarget","VTRPassStartedAt","VTRPassTeam","VTRPassReceiver","VTRLobTarget","VTRLobPassActive","VTRSetPieceReady","VTRSetPieceKind","VTRSetPieceTeam","VTRSetPieceTaker","VTRSetPieceLocked","VTRCornerTarget","VTRLastCornerTeam","VTRCornerTakenAt","VTRMotionKind","VTRRestartDisplayKind"}do
		ball:SetAttribute(attribute,nil)
	end

	if session.BallService then
		session.BallService.MotionKind="Loose"
		session.BallService.MotionStarted=os.clock()
		session.BallService.ShotPlan=nil
		session.BallService.PassPlan=nil
		session.BallService.PassTargetPoint=nil
		session.BallService.ExpectedReceiver=nil
		session.BallService.PendingCurve=nil
		session.BallService.Last={}
		session.BallService.LastTouchPlayer=nil
		session.BallService.LastTouchTeam=nil
		if session.BallService.Curve then session.BallService.Curve:Stop()end
		if session.BallService.ClearGoalkeeperHoldState then session.BallService:ClearGoalkeeperHoldState(nil)end
	end

	if session.Possession then
		session.Possession:Reset()
	end

	if session.TeamControl and session.TeamControl.Receiving then
		session.TeamControl.Receiving:Clear()
	end

	broadcast(session.State or session.Remote or Remotes.Create(),session,{Type="BallRevived",Reason=reason or"Kickoff",Ball=ball})
end


function Service:_resetForSecondHalfKickoff(session:any)
	session.PendingReplayRestart=nil
	session.ReplayRestartGate=nil
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
		reviveMatchBallForKickoff(session,"SecondHalfReset")
		ball=session.World and session.World.Ball
		if not ball then return end
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
	session.PracticeShooter=shooter;session.PracticeKeeper=keeper;session.PracticeResetting=false;session.PracticeShotStartedAt=nil;session.PracticePeakShotSpeed=nil;session.PracticeShotResult=nil;session.FinalChance=nil;session.PendingReplayRestart=nil;session.ReplayRestartGate=nil;session.PrematchSkipped=true;session.Phase="SHOOTING PRACTICE";session.Running=true
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

function Service:_setLocalFiveVFivePause(session:any,player:Player,paused:boolean)
	if not session or session.FiveVFive~=true then return end
	session.LocalPausedPlayers=session.LocalPausedPlayers or{}
	if paused then
		session.LocalPausedPlayers[player]=true
		local active=session.TeamControl and session.TeamControl:GetActive(player)or nil
		local humanoid=active and active:FindFirstChildOfClass("Humanoid")
		if active then
			active:SetAttribute("VTRMoveMagnitude",0)
			active:SetAttribute("VTRMoveDirection",Vector3.zero)
			active:SetAttribute("VTRSprinting",false)
			active:SetAttribute("VTRCloseControl",false)
		end
		if humanoid then humanoid:Move(Vector3.zero,false)end
	else
		session.LocalPausedPlayers[player]=nil
	end
	local payload=self:_pausePayload(session,paused,player)
	payload.LocalOnly=true
	self.State:FireClient(player,payload)
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
		self:_controlEnabled(session)
		if kind=="Kickoff"and session.WorldCupOnboarding==true and session.WorldCupOnboardingMidfieldStarted~=true then
			session.WorldCupOnboardingMidfieldStarted=true
			task.defer(function()self:_beginWorldCupOnboardingPossession(session)end)
		end
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
			self.State:FireClient(defender,{Type="ActivePlayer",Model=keeper,Name=keeper:GetAttribute("DisplayName"),Position=keeper:GetAttribute("position"),Reason="PenaltyDefense",PenaltyLocation=session.World.Ball.Position,GoalPosition=goalPosition,GoalSign=goalSign})
		end
	end
	
	if kind~="Kickoff"and not(session.PenaltyShootoutStarted==true and session.PenaltyShootoutResolved~=true and kind=="Penalty")then
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
	local gate=session.ReplayRestartGate
	if not gate then return false end
	return gate:IsComplete(function(participant:Instance):boolean
		return participant.Parent==Players
	end)
end

function Service:_queueReplayRestart(session:any,kind:string,restartTeam:string,location:Vector3):number
	session.ReplayRestartSequence=(tonumber(session.ReplayRestartSequence)or 0)+1
	local replayId=session.ReplayRestartSequence
	session.PendingReplayRestart={Kind=kind,Team=restartTeam,Location=location,Ready=false,ReplayId=replayId}
	session.ReplayRestartGate=ReplayRestartGate.new(replayId,session.Players or{})
	debugKickoff("replay restart hold queued","id",replayId,"kind",kind,"team",restartTeam)
	return replayId
end

function Service:_resumeReplayRestart(session:any,reason:string)
	local pending=session.PendingReplayRestart
	if not pending or session.Ended or pending.Ready~=true then return end
	session.PendingReplayRestart=nil
	session.ReplayRestartGate=nil
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
	debugKickoff("replay restart ready","kind",pending.Kind,"team",pending.Team,"allAcked",self:_allReplayAcks(session))
	if self:_allReplayAcks(session)then self:_resumeReplayRestart(session,"client ack")end
end

function Service:_ackReplayFinished(session:any,player:Player,replayId:any)
	local pending=session.PendingReplayRestart
	if not pending or session.Ended then return end
	local gate=session.ReplayRestartGate
	local numericId=tonumber(replayId)
	if not gate or not numericId or numericId~=tonumber(pending.ReplayId)or not gate:Acknowledge(player,numericId)then
		debugKickoff("replay finished ack ignored","player",player.Name,"id",replayId,"expected",pending.ReplayId)
		return
	end
	debugKickoff("replay finished ack","player",player.Name,"id",numericId,"ready",pending.Ready==true,"pending",gate:PendingCount(function(participant:Instance):boolean return participant.Parent==Players end))
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
	for _,participant in session.Players do self:_track(session,participant,"playability_first_goal",{scoringSide=team})end
	if session.ShootingPractice then
		if session.Goalkeepers and session.Goalkeepers.FinishActiveDiveAfterGoal then session.Goalkeepers:FinishActiveDiveAfterGoal()end
		session.Running=false
		GoalShotPassThroughService.Clear(session.World.Ball)
		self:_scheduleShootingPracticeReset(session,"GOAL",1.45)
		return
	end
	if session.WorldCupTutorial==true and session.TutorialStage==3 then
		if session.TutorialShootingRestarting==true then return end
		session.TutorialShootingRestarting=true
		if session.Goalkeepers and session.Goalkeepers.FinishActiveDiveAfterGoal then session.Goalkeepers:FinishActiveDiveAfterGoal()end
		BallCollisionService.ApplyScoredBall(session.World.Ball)
		session.World.Ball.Anchored=false
		setServerNetworkOwner(session.World and session.World.Ball)
		self:_tutorialPrompt(session,"SHOOTING COMPLETE","",1,1)
		task.delay(1.6,function()if self.Sessions[session.Player]==session and not session.Ended then self:_restartWorldCupTutorialStage(session,4)end end)
		return
	end
	if session.WorldCupTutorial==true and session.TutorialStage==4 then
		if session.TutorialRestarting==true then return end
		session.TutorialRestarting=true
		self:_playTutorialRestartTransition(session)
		task.delay(.75,function()if self.Sessions[session.Player]==session and not session.Ended then self:_restartWorldCupTutorialStage(session,4)end end)
		return
	end
	local currentGoalVelocity=session.World.Ball.AssemblyLinearVelocity
	local entryGoalVelocity=session.World.Ball:GetAttribute("VTRGoalEntryVelocity")
	local goalVelocity=typeof(entryGoalVelocity)=="Vector3"and entryGoalVelocity.Magnitude>currentGoalVelocity.Magnitude and entryGoalVelocity or currentGoalVelocity
	local entryAngularVelocity=session.World.Ball:GetAttribute("VTRGoalEntryAngularVelocity")
	local goalAngularVelocity=typeof(entryAngularVelocity)=="Vector3"and entryAngularVelocity or session.World.Ball.AssemblyAngularVelocity
	local entryPosition=session.World.Ball:GetAttribute("VTRGoalEntryPosition")
	local penaltyGoal=session.World.Ball:GetAttribute("VTRPenaltyShotActive")==true
	if session.PenaltyShootoutStarted==true and session.PenaltyShootoutResolved~=true and session.RankedShootout and penaltyGoal then
		local activeSide=tostring(session.RankedShootout.ActiveSide or team)
		if session.Goalkeepers and session.Goalkeepers.FinishActiveDiveAfterGoal then session.Goalkeepers:FinishActiveDiveAfterGoal()end
		GoalShotPassThroughService.Clear(session.World.Ball)
		self:_completeRankedShootoutAttempt(session,activeSide,true,"Goal")
		return
	end
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
	local restartTeam=team=="Home"and"Away"or"Home"
	local replayId=self:_queueReplayRestart(session,"Kickoff",restartTeam,session.World.PitchCFrame.Position)
	local scoringPlayer=session.SidePlayers and session.SidePlayers[team];local customGoalMusic=scoringPlayer and tostring(scoringPlayer:GetAttribute("VTRCustomGoalMusicId")or"")or"";local customGoalMusicStart=scoringPlayer and tonumber(scoringPlayer:GetAttribute("VTRCustomGoalMusicStart"))or 0;local goalMusic=scoringPlayer and tostring(scoringPlayer:GetAttribute("VTRGoalMusic")or"")or"";local goalEffect=scoringPlayer and tostring(scoringPlayer:GetAttribute("VTRGoalEffect")or"")or"";local goalCelebration=scoringPlayer and tostring(scoringPlayer:GetAttribute("VTRCelebration")or"")or"";local canCelebrate=scorerModel and scorerModel:GetAttribute("VTRTeam")==team and goalCelebration~="";if canCelebrate then scorerModel:SetAttribute("VTRCelebrating",true);task.delay(6.2,function()if scorerModel and scorerModel.Parent then scorerModel:SetAttribute("VTRCelebrating",nil)end end)end;local clockPayload=clockPayloadForGoal;broadcast(self.State,session,{Type="Goal",ReplayId=replayId,Team=team,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,GameSeconds=clockPayload.GameSeconds,AddedMinutes=clockPayload.AddedMinutes,InAddedTime=clockPayload.InAddedTime,AddedElapsed=clockPayload.AddedElapsed,Scorer=scorer,ScorerModel=scorerModel,Penalty=penaltyGoal,GoalMusicId=customGoalMusic~=""and customGoalMusic or(goalMusic~=""and goalMusic or nil),GoalMusicStart=customGoalMusic~=""and customGoalMusicStart or nil,GoalEffectId=goalEffect~=""and goalEffect or nil,CelebrationId=canCelebrate and goalCelebration or nil})
	if penaltyGoal then task.delay(1.1,function()if session.World and session.World.Ball then session.World.Ball:SetAttribute("VTRPenaltyShotActive",nil)end end)end
	self:_checkQueuedPause(session)
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
	for _,participant in session.Players do self:_track(session,participant,"playability_halftime",{})end
	session.HalfTimeTriggered=true;session.Running=false;session.Phase="HALF TIME";session.Possession:Reset();self:_setPlayersFrozen(session,true)
	if session.CampaignManager then session.CampaignManager.FirstHalfGoalDifference=session.World.HomeScore.Value-session.World.AwayScore.Value end
	local gameSeconds=session.Clock:Payload().GameSeconds
	local payload=self:_pausePayload(session,true,nil)
	local halfTimeBreakSeconds=session.ExtraTimeActive==true and (tonumber(session.ExtraTimeHalfPauseSeconds) or EXTRA_TIME_HALF_PAUSE_SECONDS) or math.max(3,tonumber(session.Format and session.Format.HalftimeSeconds)or 7)
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
	reviveMatchBallForKickoff(session,"SecondHalfKickoff")
	session.SecondHalfStartedAt=os.clock()
	session.Clock:StartSecondHalf();if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end;if session.Referee and session.Referee.SetHalf then session.Referee:SetHalf(2)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end;if session.OutOfBounds and session.OutOfBounds.SetHalf then session.OutOfBounds:SetHalf(2)end;reviveMatchBallForKickoff(session,"SecondHalfKickoffStart")
	self:_startSetPiece(session,"Kickoff","Away",session.World.PitchCFrame.Position)
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
	reviveMatchBallForKickoff(session,"SecondHalfWatchdog")
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
		reviveMatchBallForKickoff(session,"ForceSecondHalfLive")
		ball=session.World and session.World.Ball
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
	if setup.RequireWinner==true then return true end
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

function Service:_beginWorldCupOnboardingPossession(session:any)
	if not session or session.Ended or session.WorldCupOnboarding~=true then return end
	if session.WorldCupTutorial==true then return end
	local player=session.Player
	local active=session.TeamControl and session.TeamControl:GetActive(player)or nil
	if not active or not active.Parent then
		active=session.Teams and session.Teams.Home and (session.Teams.Home[6]or session.Teams.Home[7]or session.Teams.Home[1])or nil
		if active and session.TeamControl then session.TeamControl:SetActive(player,active,"WorldCupOnboarding")end
	end
	if not active or not active.Parent then return end
	local root=active:FindFirstChild("HumanoidRootPart")::BasePart?
	if not root then return end
	local pitch=session.World and session.World.PitchCFrame or CFrame.new()
	local safePosition=pitch:PointToWorldSpace(Vector3.new(0,3,-42))
	local facing=pitch.LookVector
	active:PivotTo(CFrame.lookAt(safePosition,safePosition+Vector3.new(facing.X,0,facing.Z)))
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
	if session.World and session.World.Ball then
		session.World.Ball.Anchored=false
		session.World.Ball.AssemblyLinearVelocity=Vector3.zero
		session.World.Ball.AssemblyAngularVelocity=Vector3.zero
		session.World.Ball.CFrame=CFrame.new(safePosition+pitch.LookVector*2.35+Vector3.new(0,-1.55,0))
		session.World.Ball:SetAttribute("VTRWorldCupFirstPassPending",true)
	end
	if session.Possession then session.Possession:Reset();session.Possession:ForcePickup(active)end
	session.WorldCupFirstPassPending=true
	session.WorldCupFirstPassPasser=active
	active:SetAttribute("VTRNoAutoPassUntil",os.clock()+999)
	if self.State then self.State:FireClient(player,{Type="ActivePlayer",Model=active,Name=active:GetAttribute("DisplayName"),Position=active:GetAttribute("position"),Reason="WorldCupOnboarding"})end
end

local function tutorialRoot(model:Model?):BasePart?
	return model and model:FindFirstChild("HumanoidRootPart")::BasePart? or nil
end

local function flatUnit(vector:Vector3,fallback:Vector3):Vector3
	local flat=Vector3.new(vector.X,0,vector.Z)
	return flat.Magnitude>.05 and flat.Unit or fallback
end

local function tutorialWorldPoint(session:any,localPos:Vector3):Vector3
	local pitch=session.World and session.World.PitchCFrame or CFrame.new()
	local right=flatUnit(pitch.RightVector,Vector3.xAxis)
	local look=flatUnit(pitch.LookVector,Vector3.zAxis)
	return pitch.Position+right*localPos.X+Vector3.new(0,localPos.Y,0)+look*localPos.Z
end

local function tutorialPitchGoalPoint(session:any,goalSign:number,x:number,y:number,distanceFromLine:number):Vector3
	local world=session.World
	local pitch=world and world.PitchCFrame or CFrame.new()
	local length=world and tonumber(world.Length)or Config.Pitch.Length
	local z=goalSign*(length*.5-distanceFromLine)
	return pitch:PointToWorldSpace(Vector3.new(x,y,z))
end

local function tutorialPart(parent:Instance,name:string,size:Vector3,offset:CFrame,color:Color3,root:BasePart):BasePart
	local part=Instance.new("Part")
	part.Name=name
	part.Size=size
	part.Color=color
	part.Material=Enum.Material.SmoothPlastic
	part.Anchored=false
	part.CanCollide=name~="HumanoidRootPart"
	part.CanTouch=true
	part.CanQuery=true
	part.Massless=true
	part.CFrame=root.CFrame*offset
	part.Parent=parent
	if part~=root then
		local weld=Instance.new("WeldConstraint")
		weld.Part0=root
		weld.Part1=part
		weld.Parent=part
	end
	return part
end

local function createTutorialGoalkeeper(parent:Instance):Model
	local model=Instance.new("Model")
	model.Name="TutorialGoalkeeper"
	model:SetAttribute("DisplayName","Goalkeeper")
	model:SetAttribute("position","GK")
	model:SetAttribute("IsGoalkeeper",true)
	model:SetAttribute("Goalkeeper",true)
	model:SetAttribute("VTRGoalkeeper",true)
	model:SetAttribute("VTRTutorialKeeper",true)
	model:SetAttribute("VTRTutorialFrozen",true)
	model:SetAttribute("VTRTeam","Away")
	local root=Instance.new("Part")
	root.Name="HumanoidRootPart"
	root.Size=Vector3.new(2.4,2.4,1.2)
	root.Transparency=1
	root.Anchored=true
	root.CanCollide=false
	root.CanTouch=true
	root.CanQuery=true
	root.Parent=model
	model.PrimaryPart=root
	local humanoid=Instance.new("Humanoid")
	humanoid.Name="Humanoid"
	humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed=0
	humanoid.JumpPower=0
	humanoid.Parent=model
	local kit=Color3.fromHex("1A1F2C")
	local gloves=Color3.fromHex("B7FF1A")
	local skin=Color3.fromRGB(235,188,145)
	tutorialPart(model,"Torso",Vector3.new(2.6,2.6,1.15),CFrame.new(0,0,0),kit,root)
	tutorialPart(model,"Head",Vector3.new(1.35,1.05,1.05),CFrame.new(0,1.95,0),skin,root)
	tutorialPart(model,"Left Arm",Vector3.new(.7,2.25,.7),CFrame.new(-1.75,.1,0),gloves,root)
	tutorialPart(model,"Right Arm",Vector3.new(.7,2.25,.7),CFrame.new(1.75,.1,0),gloves,root)
	tutorialPart(model,"Left Leg",Vector3.new(.82,2.25,.82),CFrame.new(-.55,-2.2,0),Color3.fromHex("10131B"),root)
	tutorialPart(model,"Right Leg",Vector3.new(.82,2.25,.82),CFrame.new(.55,-2.2,0),Color3.fromHex("10131B"),root)
	model.Parent=parent
	return model
end

local function cloneTutorialGoalkeeper(source:Model?,parent:Instance):Model?
	if not source then return nil end
	local oldArchivable=source.Archivable
	source.Archivable=true
	local ok,clone=pcall(function()return source:Clone()end)
	source.Archivable=oldArchivable
	if not ok or not clone or not clone:IsA("Model")then return nil end
	clone.Name="TutorialShootingGoalkeeper"
	clone:SetAttribute("DisplayName",source:GetAttribute("DisplayName")or"Goalkeeper")
	clone:SetAttribute("position","GK")
	clone:SetAttribute("IsGoalkeeper",true)
	clone:SetAttribute("Goalkeeper",true)
	clone:SetAttribute("VTRGoalkeeper",true)
	clone:SetAttribute("VTRTutorialKeeper",true)
	clone:SetAttribute("VTRTeam","Away")
	clone:SetAttribute("VTRParked",nil)
	clone:SetAttribute("VTRCinematicParked",nil)
	clone:SetAttribute("aiControlled",true)
	clone:SetAttribute("controlledByUser",false)
	clone:SetAttribute("AIAssignment","GoalkeeperPosition")
	clone:SetAttribute("VTRGoalkeeperState","Ready")
	clone.Parent=parent
	return clone
end

function Service:_tutorialPivot(session:any,model:Model?,localPos:Vector3,lookSign:number?)
	local root=tutorialRoot(model)
	if not root then return end
	local pitch=session.World and session.World.PitchCFrame or CFrame.new()
	local world=tutorialWorldPoint(session,localPos)
	local look=flatUnit(pitch.LookVector,Vector3.zAxis)*(lookSign or 1)
	root.Anchored=false
	model:PivotTo(CFrame.lookAt(world,world+Vector3.new(look.X,0,look.Z)))
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
	if session.LastPositions then session.LastPositions[model]=root.Position end
end

function Service:_tutorialBallTo(session:any,model:Model?)
	local root=tutorialRoot(model)
	if not root or not session.World or not session.World.Ball then return end
	local ball=session.World.Ball
	ball.Anchored=false
	ball.AssemblyLinearVelocity=Vector3.zero
	ball.AssemblyAngularVelocity=Vector3.zero
	ball.CFrame=CFrame.new(root.Position+root.CFrame.LookVector*2.25+Vector3.new(0,-1.55,0))
	if session.Possession then session.Possession:Reset();session.Possession:ForcePickup(model)end
	model:SetAttribute("VTRNoAutoPassUntil",os.clock()+999)
end

function Service:_tutorialSetActive(session:any,model:Model?,reason:string)
	if not model then return end
	local player=session.Player
	if session.TeamControl then session.TeamControl:SetActive(player,model,reason)end
	self.State:FireClient(player,{Type="ActivePlayer",Model=model,Name=model:GetAttribute("DisplayName"),Position=model:GetAttribute("position"),Reason=reason})
end

function Service:_tutorialPrompt(session:any,message:string,action:string?,count:number?,target:number?,requiresOk:boolean?,targetModel:Model?,targetModels:any?,goalSign:number?,laneTarget:Vector3?,helpLevel:number?,routePoints:any?,currentPoint:number?)
	self.State:FireClient(session.Player,{Type="TutorialStage",Message=message,Action=action,Count=count,Target=target,RequiresOk=requiresOk==true,TargetModel=targetModel,TargetModels=targetModels,GoalSign=goalSign,LaneTarget=laneTarget,HelpLevel=helpLevel,RoutePoints=routePoints,CurrentPoint=currentPoint})
end

function Service:_playTutorialRestartTransition(session:any)
	self.State:FireClient(session.Player,{Type="TutorialRestart"})
end

function Service:_tutorialNextPassTarget(session:any,owner:Model?):Model?
	local options=session and session.TutorialPassTargets
	if type(options)~="table"or #options<=0 then return nil end
	local ownerIndex=1
	for index,model in options do
		if model==owner then ownerIndex=index;break end
	end
	for offset=1,#options do
		local candidate=options[((ownerIndex+offset-1)%#options)+1]
		if candidate and candidate.Parent and candidate~=owner then return candidate end
	end
	return nil
end

function Service:_tutorialPassReceiverTargets(session:any,owner:Model?):{Model}
	local result={}
	local options=session and session.TutorialPassTargets
	if type(options)~="table"then return result end
	for _,candidate in options do
		if candidate and candidate.Parent and candidate~=owner then
			table.insert(result,candidate)
		end
	end
	return result
end

function Service:_tutorialUpdatePassTarget(session:any,owner:Model?)
	if not session or session.Ended or session.WorldCupTutorial~=true or session.TutorialStage~=2 then return end
	local target=self:_tutorialNextPassTarget(session,owner)
	session.TutorialPassTarget=target
	local count=tonumber(session.TutorialPasses)or 0
	local message=count>0 and"COMPLETE 3 PASSES WITHOUT GETTING TACKLED"or"RIGHT CLICK - PASS"
	self:_tutorialPrompt(session,message,"Pass",count,3,false,target,self:_tutorialPassReceiverTargets(session,owner))
end

function Service:_setTutorialDrillMode(session:any,active:boolean)
	session.Running=active
	session.Phase=active and "IN PLAY" or "TUTORIAL"
	if session.AI and session.AI.SetExternalPhase then session.AI:SetExternalPhase(active and "Tutorial" or nil)end
	if session.Goals and session.Goals.Unlock then session.Goals:Unlock()end
	broadcast(self.State,session,{Type="Phase",Phase=active and"IN PLAY"or"TUTORIAL"})
end

function Service:_startWorldCupTutorial(session:any)
	if not session or session.Ended then return end
	session.WorldCupTutorial=true
	session.PrematchSkipped=true
	session.World.HomeScore.Value=0
	session.World.AwayScore.Value=0
	self:_setTutorialDrillMode(session,true)
	self:_restartWorldCupTutorialStage(session,1)
end

function Service:_restartWorldCupTutorialStage(session:any,stage:number)
	if not session or session.Ended then return end
	session.TutorialStage=stage
	session.TutorialPasses=0
	session.TutorialStops=0
	session.TutorialShotTaken=false
	session.TutorialFocusAsked=false
	session.TutorialSwitched=false
	session.TutorialTackled=false
	session.TutorialAllowAI=false
	session.TutorialRestarting=false
	session.TutorialReady=stage~=2
	session.TutorialStageModels=nil
	session.TutorialDefender=nil
	session.TutorialMovementStartPosition=nil
	session.TutorialMovementStartedAt=nil
	session.TutorialMovementInputStartedAt=nil
	session.TutorialMovementInputActiveUntil=nil
	session.TutorialMovementCompleted=nil
	session.TutorialMovementHelpLevel=0
	session.TutorialMovementLaneTarget=nil
	session.TutorialMovementPoints=nil
	session.TutorialMovementPointIndex=nil
	session.TutorialMovementSprintPrompted=nil
	session.TutorialMovementSprintSeen=nil
	session.TutorialShootingRestarting=nil
	session.TutorialShotStartedAt=nil
	session.TutorialDefenseAttackers=nil
	session.TutorialDefenseDefenders=nil
	session.TutorialDefenseGoalSign=nil
	session.TutorialDefenseShotAt=nil
	session.TutorialDefenseNextAttackAt=nil
	session.TutorialDefenseStopCooldownUntil=nil
	if session.TutorialShootingClone and session.TutorialShootingClone.Parent then
		session.TutorialShootingClone:Destroy()
	end
	if session.TutorialShootingClone and type(session.Models)=="table"then
		for index=#session.Models,1,-1 do
			if session.Models[index]==session.TutorialShootingClone then
				table.remove(session.Models,index)
			end
		end
	end
	if session.TutorialShootingClone and session.Teams and type(session.Teams.Away)=="table"then
		for index=#session.Teams.Away,1,-1 do
			if session.Teams.Away[index]==session.TutorialShootingClone then
				table.remove(session.Teams.Away,index)
			end
		end
	end
	session.TutorialShootingClone=nil
	session.TutorialShootingKeeper=nil
	session.WorldCupFirstPassPending=false
	session.WorldCupFirstPassPasser=nil
	if session.World and session.World.Ball then session.World.Ball:SetAttribute("VTRWorldCupFirstPassPending",nil)end
	local home=session.Teams and session.Teams.Home or{}
	local away=session.Teams and session.Teams.Away or{}
	for _,model in session.Models or{}do
		model:SetAttribute("VTRNoAutoPassUntil",os.clock()+999)
		model:SetAttribute("VTRTutorialFrozen",nil)
		model:SetAttribute("VTRTutorialPressing",nil)
		model:SetAttribute("VTRTutorialShot",nil)
		model:SetAttribute("VTRPracticeShotSpeed",nil)
		model:SetAttribute("VTRPracticeShotLift",nil)
		model:SetAttribute("VTRSprinting",false)
		local root=tutorialRoot(model)
		if root then
			local park=(session.World and session.World.PitchCFrame or CFrame.new())*CFrame.new(0,-70,0)
			model:PivotTo(park)
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
			root.Anchored=true
			if session.LastPositions then session.LastPositions[model]=root.Position end
		end
	end
	if stage==1 then
		local attacker=home[10]or home[9]or home[1]
		local attackSign=1
		local pointLocals={
			Vector3.new(0,3,-42),
			Vector3.new(-24,3,-8),
			Vector3.new(-4,3,30),
			Vector3.new(28,3,66),
			Vector3.new(4,3,108),
		}
		self:_tutorialPivot(session,attacker,Vector3.new(0,3,-74),attackSign)
		local root=tutorialRoot(attacker)
		session.TutorialMovementStartPosition=root and root.Position or nil
		session.TutorialMovementStartedAt=os.clock()
		session.TutorialMovementPoints={}
		if session.World then
			for _,localPoint in pointLocals do
				table.insert(session.TutorialMovementPoints,tutorialWorldPoint(session,localPoint))
			end
		end
		session.TutorialMovementPointIndex=1
		session.TutorialMovementLaneTarget=session.TutorialMovementPoints and session.TutorialMovementPoints[1]or nil
		session.TutorialStageModels={attacker}
		self:_tutorialSetActive(session,attacker,"TutorialMovement")
		self:_tutorialBallTo(session,attacker)
		self:_tutorialPrompt(session,"MOVE INTO SPACE","Move",0,5,false,nil,nil,nil,session.TutorialMovementLaneTarget,0,session.TutorialMovementPoints,1)
	elseif stage==2 then
		local a,b,c=home[6]or home[1],home[8]or home[2]or home[1],home[10]or home[3]or home[1]
		local defender=away[5]or away[4]or away[1]
		self:_tutorialPivot(session,a,Vector3.new(0,3,-62),1)
		self:_tutorialPivot(session,b,Vector3.new(-54,3,34),1)
		self:_tutorialPivot(session,c,Vector3.new(54,3,34),1)
		self:_tutorialPivot(session,defender,Vector3.new(0,3,0),-1)
		local defenderRoot=tutorialRoot(defender)
		if defenderRoot then defenderRoot.Anchored=true end
		if defender then defender:SetAttribute("aiControlled",false);defender:SetAttribute("controlledByUser",false)end
		session.TutorialStageModels={a,b,c,defender}
		session.TutorialPassTargets={a,b,c}
		session.TutorialDefender=defender
		session.WorldCupFirstPassPending=true
		session.WorldCupFirstPassPasser=a
		if session.World and session.World.Ball then session.World.Ball:SetAttribute("VTRWorldCupFirstPassPending",true)end
		self:_tutorialSetActive(session,a,"TutorialPassing")
		self:_tutorialBallTo(session,a)
		session.TutorialPassTarget=b
		self:_tutorialPrompt(session,"RIGHT CLICK - PASS","Pass",0,3,true,b,{b,c})
	elseif stage==3 then
		local attacker=home[9]or home[10]or home[1]
		local goalSign=1
		local sourceKeeper=getGoalkeeper(away)or away[1]
		local keeper=cloneTutorialGoalkeeper(sourceKeeper,session.World and session.World.Folder or workspace)
		local rectangle=session.World and GoalModelResolver.ResolveByAttackSign(goalSign,session.World.PitchCFrame,session.World.Width,session.World.Length)or nil
		if attacker and rectangle then
			local width=rectangle.RightBound-rectangle.Left
			local goalCenter=tutorialPitchGoalPoint(session,goalSign,0,3.2,0)
			local shotStart=tutorialPitchGoalPoint(session,goalSign,0,3.2,62)
			local look=goalCenter-shotStart
			local root=tutorialRoot(attacker)
			if root then
				root.Anchored=false
				attacker:PivotTo(CFrame.lookAt(shotStart,shotStart+Vector3.new(look.X,0,look.Z)))
				root.AssemblyLinearVelocity=Vector3.zero
				root.AssemblyAngularVelocity=Vector3.zero
				if session.LastPositions then session.LastPositions[attacker]=root.Position end
			end
		else
			self:_tutorialPivot(session,attacker,Vector3.new(0,3,goalSign*session.World.Length*.5-goalSign*78),goalSign)
		end
		if attacker then
			attacker:SetAttribute("VTRTutorialShot",true)
			attacker:SetAttribute("VTRPracticeShotSpeed",0.56)
			attacker:SetAttribute("VTRPracticeShotLift",0.72)
		end
		if keeper and rectangle then
			session.TutorialShootingClone=keeper
			session.TutorialShootingKeeper=keeper
			if session.Teams and type(session.Teams.Away)=="table"then table.insert(session.Teams.Away,1,keeper)end
			local width=rectangle.RightBound-rectangle.Left
			local lineCenter=tutorialPitchGoalPoint(session,goalSign,0,3.2,0)
			local keeperPosition=tutorialPitchGoalPoint(session,goalSign,0,3.2,7)
			local look=lineCenter-keeperPosition
			keeper:PivotTo(CFrame.lookAt(keeperPosition,keeperPosition+Vector3.new(look.X,0,look.Z)))
			keeper:SetAttribute("position","GK")
			keeper:SetAttribute("IsGoalkeeper",true)
			keeper:SetAttribute("Goalkeeper",true)
			keeper:SetAttribute("VTRGoalkeeper",true)
			keeper:SetAttribute("VTRTutorialKeeper",true)
			keeper:SetAttribute("VTRParked",nil)
			keeper:SetAttribute("VTRCinematicParked",nil)
			keeper:SetAttribute("aiControlled",true)
			keeper:SetAttribute("controlledByUser",false)
			keeper:SetAttribute("VTRTutorialFrozen",nil)
			keeper:SetAttribute("AIAssignment","GoalkeeperPosition")
			keeper:SetAttribute("VTRGoalkeeperState","Ready")
			for _,descendant in keeper:GetDescendants()do
				if descendant:IsA("BasePart")then
					descendant.LocalTransparencyModifier=0
					if descendant.Name~="HumanoidRootPart"then descendant.Transparency=0 else descendant.Transparency=1 end
					descendant.CanCollide=descendant.Name~="HumanoidRootPart"
					descendant.CanTouch=true
				end
			end
			local keeperRoot=tutorialRoot(keeper)
			if keeperRoot then
				keeperRoot.Anchored=false
				keeperRoot.AssemblyLinearVelocity=Vector3.zero
				keeperRoot.AssemblyAngularVelocity=Vector3.zero
				if session.LastPositions then session.LastPositions[keeper]=keeperRoot.Position end
			end
			if type(session.Models)=="table"and not table.find(session.Models,keeper)then table.insert(session.Models,keeper)end
			BallCollisionService.ApplyPlayers({keeper})
		end
		session.TutorialShootingGoalSign=goalSign
		session.TutorialStageModels={attacker,keeper}
		self:_tutorialSetActive(session,attacker,"TutorialShooting")
		self:_tutorialBallTo(session,attacker)
		self:_tutorialPrompt(session,"HOLD LEFT CLICK - SHOOT","Shoot",0,1,false,nil,nil,goalSign)
	elseif stage==4 then
		local d1,d2=home[4]or home[1],home[5]or home[2]
		local a1,a2,a3=away[9]or away[1],away[10]or away[2],away[11]or away[3]
		self:_tutorialPivot(session,d1,Vector3.new(-8,3,session.World.Length*.5-150),-1)
		self:_tutorialPivot(session,d2,Vector3.new(10,3,session.World.Length*.5-142),-1)
		self:_tutorialPivot(session,a1,Vector3.new(-14,3,session.World.Length*.5-205),-1)
		self:_tutorialPivot(session,a2,Vector3.new(10,3,session.World.Length*.5-212),-1)
		self:_tutorialPivot(session,a3,Vector3.new(0,3,session.World.Length*.5-230),-1)
		session.TutorialDefenseAttackers={a1,a2,a3}
		session.TutorialDefenseDefenders={d1,d2}
		session.TutorialDefenseGoalSign=-1
		for _,attacker in{a1,a2,a3}do
			if attacker then
				attacker:SetAttribute("aiControlled",true)
				attacker:SetAttribute("controlledByUser",false)
				attacker:SetAttribute("VTRNoAutoPassUntil",nil)
				attacker:SetAttribute("VTRSprinting",true)
			end
		end
		if d2 then
			d2:SetAttribute("aiControlled",true)
			d2:SetAttribute("controlledByUser",false)
		end
		self:_tutorialSetActive(session,d1,"TutorialDefending")
		self:_tutorialBallTo(session,a1)
		session.TutorialAllowAI=true
		self:_tutorialPrompt(session,"SWITCH PLAYER","Switch",0,1)
	elseif stage==5 then
		self:_setTutorialDrillMode(session,false)
		self:_tutorialPrompt(session,"START MATCH","StartMatch",3,3)
	end
end

function Service:_completeWorldCupTutorial(session:any)
	if not session or session.Ended then return end
	for _,participant in session.Players do self:_track(session,participant,"playability_tutorial_complete",{})end
	session.WorldCupTutorial=false
	session.WorldCupOnboarding=false
	session.WorldCupOnboardingMidfieldStarted=true
	session.WorldCupFirstPassPending=false
	if type(session.Setup)=="table"then
		session.Setup.WorldCupTutorial=false
		session.Setup.WorldCupOnboarding=false
	end
	if session.World and session.World.Ball then session.World.Ball:SetAttribute("VTRWorldCupFirstPassPending",nil);session.World.Ball:SetAttribute("VTRTutorialPhysics",nil)end
	session.OffsideDisabled=false
	if session.BallService and session.Offside then session.BallService:SetOffsideService(session.Offside)end
	if session.SetPieces then session.SetPieces.OnboardingNoAutoKickoff=false end
	local active=session.TeamControl and session.TeamControl:GetActive(session.Player)or nil
	for _,model in session.Models or{}do
		local root=tutorialRoot(model)
		if root then
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
			if session.LastPositions then session.LastPositions[model]=root.Position end
		end
		model:SetAttribute("VTRNoAutoPassUntil",nil)
		model:SetAttribute("VTRTutorialFrozen",nil)
		model:SetAttribute("VTRTutorialPressing",nil)
		if model~=active then
			model:SetAttribute("controlledByUser",false)
			model:SetAttribute("aiControlled",true)
			model:SetAttribute("VTRUserId",nil)
		end
	end
	session.World.HomeScore.Value=1
	session.World.AwayScore.Value=1
	session.TutorialStage=nil
	session.TutorialAllowAI=false
	session.TutorialStageModels=nil
	session.TutorialDefender=nil
	session.TutorialShootingKeeper=nil
	session.TutorialShootingClone=nil
	session.TutorialDefenseAttackers=nil
	session.TutorialDefenseDefenders=nil
	session.TutorialDefenseGoalSign=nil
	session.TutorialDefenseShotAt=nil
	session.TutorialDefenseNextAttackAt=nil
	session.Running=false
	session.HalfTimeBreak=false
	session.HalfTimeBreakEndsAt=nil
	session.HalfTimeTriggered=true
	session.HalfTimeResuming=true
	session.Accumulator=0
	session.Phase="Kickoff"
	if session.AI and session.AI.SetExternalPhase then session.AI:SetExternalPhase(nil)end
	self:_resetForSecondHalfKickoff(session)
	session.World.HomeScore.Value=1
	session.World.AwayScore.Value=1
	session.SecondHalfStartedAt=os.clock()
	if session.Clock then session.Clock:StartSecondHalf()end
	if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end
	if session.Referee and session.Referee.SetHalf then session.Referee:SetHalf(2)end
	if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end
	if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end
	if session.OutOfBounds and session.OutOfBounds.SetHalf then session.OutOfBounds:SetHalf(2)end
	reviveMatchBallForKickoff(session,"WorldCupTutorialFullMatchStart")
	self:_tutorialPrompt(session,"","",0,0)
	self:_startSetPiece(session,"Kickoff","Away",session.World.PitchCFrame.Position)
	broadcast(self.State,session,{Type="HalfTimeResume",ExtraTime=false})
	local clockPayload=session.Clock and session.Clock:Payload()
	if clockPayload then
		broadcast(self.State,session,{Type="Clock",GameSeconds=clockPayload.GameSeconds,Half=clockPayload.Half,AddedMinutes=clockPayload.AddedMinutes,InAddedTime=clockPayload.InAddedTime,AddedElapsed=clockPayload.AddedElapsed,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value})
	end
	task.delay(1.9,function()
		if not session.Ended and session.HalfTimeResuming and session.Phase=="Kickoff" and not session.Running then
			self:_forceSecondHalfKickoffLive(session)
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

function Service:_handleWorldCupTutorialAction(session:any,player:Player,payload:any)
	if not session.WorldCupTutorial then return false end
	if payload.Type=="TutorialReady"then
		session.TutorialReady=true
		return true
	end
	if session.TutorialStage==1 and payload.Type~="Move"and payload.Type~="Sprint"and payload.Type~="TutorialStartMatch"then
		return true
	end
	if session.TutorialStage==2 and payload.Type~="Pass"and payload.Type~="Move"and payload.Type~="TutorialStartMatch"then
		return true
	end
	if session.TutorialReady~=true and payload.Type~="TutorialStartMatch"then
		return true
	end
	if payload.Type=="TutorialStartMatch" and session.TutorialStage==5 then
		self:_completeWorldCupTutorial(session)
		return true
	end
	local stage=tonumber(session.TutorialStage)or 0
	if stage==1 and payload.Type=="Move"then
		local direction=typeof(payload.Direction)=="Vector3"and payload.Direction or Vector3.zero
		if direction.Magnitude>.12 then session.TutorialMovementInputActiveUntil=os.clock()+.16;session.TutorialMovementInputStartedAt=session.TutorialMovementInputStartedAt or os.clock()end
		return false
	elseif stage==1 and payload.Type=="Sprint"then
		session.TutorialMovementSprintSeen=payload.Active==true or session.TutorialMovementSprintSeen==true
		return false
	elseif stage==2 and payload.Type=="Pass"then
		session.TutorialPasses=(session.TutorialPasses or 0)+1
		if session.TutorialPasses==1 then
			session.TutorialAllowAI=true
			session.WorldCupFirstPassPending=false
			if session.World and session.World.Ball then session.World.Ball:SetAttribute("VTRWorldCupFirstPassPending",nil)end
			if session.WorldCupFirstPassPasser and session.WorldCupFirstPassPasser.Parent then session.WorldCupFirstPassPasser:SetAttribute("VTRNoAutoPassUntil",nil)end
			local defender=session.TutorialDefender
			local defenderRoot=tutorialRoot(defender)
			if defenderRoot then defenderRoot.Anchored=false;defenderRoot.AssemblyLinearVelocity=Vector3.zero;defenderRoot.AssemblyAngularVelocity=Vector3.zero end
			if defender then defender:SetAttribute("aiControlled",false);defender:SetAttribute("controlledByUser",false);defender:SetAttribute("VTRTutorialPressing",true);defender:SetAttribute("VTRSprinting",true)end
			self:_tutorialUpdatePassTarget(session,session.Possession and session.Possession:GetOwner()or session.WorldCupFirstPassPasser)
			task.delay(.14,function()if self.Sessions[player]==session and not session.Ended then self:_tutorialUpdatePassTarget(session,session.Possession and session.Possession:GetOwner()or nil)end end)
		elseif session.TutorialPasses>=3 then
			self:_tutorialPrompt(session,"PASSING COMPLETE","",3,3)
			task.delay(1.6,function()if self.Sessions[player]==session and not session.Ended then self:_restartWorldCupTutorialStage(session,3)end end)
		else
			self:_tutorialUpdatePassTarget(session,session.Possession and session.Possession:GetOwner()or nil)
			task.delay(.14,function()if self.Sessions[player]==session and not session.Ended then self:_tutorialUpdatePassTarget(session,session.Possession and session.Possession:GetOwner()or nil)end end)
		end
		return false
	elseif stage==3 and payload.Type=="Shot"then
		session.TutorialShotTaken=true
		session.TutorialShotStartedAt=os.clock()
		self:_tutorialPrompt(session,"SCORE PAST THE GOALKEEPER","Shoot",0,1,false,nil,nil,session.TutorialShootingGoalSign or -1)
		return false
	elseif stage==3 and payload.Type=="ShootingFocus"then
		session.TutorialFocusAsked=true
		self:_tutorialPrompt(session,"SCORE PAST THE GOALKEEPER","Shoot",0,1,false,nil,nil,session.TutorialShootingGoalSign or -1)
		return true
	elseif stage==4 then
		if payload.Type=="Switch"and not session.TutorialSwitched then
			session.TutorialSwitched=true
			self:_tutorialPrompt(session,"TACKLE","Tackle",1,2)
		elseif payload.Type=="Tackle"then
			if os.clock()<(tonumber(session.TutorialDefenseStopCooldownUntil)or 0)then return false end
			session.TutorialDefenseStopCooldownUntil=os.clock()+.75
			session.TutorialTackled=true
			session.TutorialStops=(session.TutorialStops or 0)+1
			if session.TutorialStops>=2 then
				self:_tutorialPrompt(session,"DEFENDING COMPLETE","",2,2)
				task.delay(1.6,function()if self.Sessions[player]==session and not session.Ended then self:_restartWorldCupTutorialStage(session,5)end end)
			else
				self:_tutorialPrompt(session,"STOP 2 ATTACKS","Tackle",session.TutorialStops,2)
				session.TutorialDefenseShotAt=nil
				session.TutorialDefenseNextAttackAt=os.clock()+.55
			end
		end
		return false
	end
	return false
end

function Service:_stepWorldCupTutorial(session:any,dt:number)
	if not session or session.Ended or session.WorldCupTutorial~=true then return end
	if session.TutorialStage==1 then
		local active=session.TeamControl and session.TeamControl:GetActive(session.Player)or nil
		local root=tutorialRoot(active)
		local startedAt=tonumber(session.TutorialMovementStartedAt)or os.clock()
		local elapsed=os.clock()-startedAt
		local inputActive=(tonumber(session.TutorialMovementInputActiveUntil)or 0)>=os.clock()
		if not inputActive then session.TutorialMovementInputStartedAt=nil end
		if session.TutorialMovementCompleted==true then return end
		local points=session.TutorialMovementPoints
		local index=math.clamp(math.floor(tonumber(session.TutorialMovementPointIndex)or 1),1,type(points)=="table"and math.max(#points,1)or 1)
		local target=type(points)=="table"and points[index]or nil
		if root and typeof(target)=="Vector3"and(root.Position-target).Magnitude<=8.5 then
			local currentCount=math.max(0,index-1)
			local sprintRequired=index>=3
			local playerState=session.PlayerState and session.PlayerState[session.Player]or nil
			local sprinting=(active and active:GetAttribute("VTRSprinting")==true)or(playerState and playerState.SprintActual==true)
			if sprintRequired and not sprinting then
				if session.TutorialMovementSprintPrompted~=true then session.TutorialMovementSprintPrompted=true end
				self:_tutorialPrompt(session,"SHIFT TO SPRINT","Sprint",currentCount,5,false,nil,nil,nil,target,math.max(tonumber(session.TutorialMovementHelpLevel)or 0,1),points,index)
				return
			end
			index+=1
			session.TutorialMovementPointIndex=index
			if type(points)=="table"and index>#points then
				session.TutorialMovementCompleted=true
				self:_tutorialPrompt(session,"MOVEMENT COMPLETE","",5,5)
				task.delay(1.05,function()if self.Sessions[session.Player]==session and not session.Ended then self:_restartWorldCupTutorialStage(session,2)end end)
				session.TutorialStage=0
				return
			end
			session.TutorialMovementLaneTarget=points[index]
			local count=math.clamp(index-1,0,5)
			local message=count>=2 and"SHIFT TO SPRINT"or"MOVE INTO SPACE"
			local action=count>=2 and"Sprint"or"Move"
			if count>=2 then session.TutorialMovementSprintPrompted=true end
			self:_tutorialPrompt(session,message,action,count,5,false,nil,nil,nil,session.TutorialMovementLaneTarget,tonumber(session.TutorialMovementHelpLevel)or 0,points,index)
		end
		local help=tonumber(session.TutorialMovementHelpLevel)or 0
		if elapsed>=8 and help<2 then
			session.TutorialMovementHelpLevel=2
			if root and session.World then
				local localPos=session.World.PitchCFrame:PointToObjectSpace(root.Position)
				session.TutorialMovementLaneTarget=type(points)=="table"and points[index]or tutorialWorldPoint(session,Vector3.new(localPos.X,3,localPos.Z-16))
			end
			local count=math.max(0,(tonumber(session.TutorialMovementPointIndex)or 1)-1)
			self:_tutorialPrompt(session,count>=2 and"SHIFT TO SPRINT"or"MOVE INTO SPACE",count>=2 and"Sprint"or"Move",count,5,false,nil,nil,nil,session.TutorialMovementLaneTarget,2,session.TutorialMovementPoints,session.TutorialMovementPointIndex)
		elseif elapsed>=4 and help<1 then
			session.TutorialMovementHelpLevel=1
			local count=math.max(0,(tonumber(session.TutorialMovementPointIndex)or 1)-1)
			self:_tutorialPrompt(session,count>=2 and"SHIFT TO SPRINT"or"MOVE INTO SPACE",count>=2 and"Sprint"or"Move",count,5,false,nil,nil,nil,session.TutorialMovementLaneTarget,1,session.TutorialMovementPoints,session.TutorialMovementPointIndex)
		end
		return
	end
	if session.TutorialStage==3 then
		local keeper=session.TutorialShootingKeeper or(session.TutorialStageModels and session.TutorialStageModels[2])or getGoalkeeper(session.Teams and session.Teams.Away)
		local goalSign=tonumber(session.TutorialShootingGoalSign)or -1
		if keeper and keeper.Parent and session.World then
			local keeperRoot=tutorialRoot(keeper)
			local rectangle=GoalModelResolver.ResolveByAttackSign(goalSign,session.World.PitchCFrame,session.World.Width,session.World.Length)
			local goalCenter=tutorialPitchGoalPoint(session,goalSign,0,3.2,0)
			local world=tutorialPitchGoalPoint(session,goalSign,0,3.2,7)
			local look=goalCenter-world
			local keeperBusy=keeper:GetAttribute("VTRGoalkeeperSaving")==true or keeper:GetAttribute("VTRGoalkeeperHolding")==true or keeper:GetAttribute("VTRKeeperDiveAnimationLocked")==true
			if keeperRoot and session.TutorialShotTaken~=true and not keeperBusy then
				keeper:PivotTo(CFrame.lookAt(world,world+Vector3.new(look.X,0,look.Z)))
				keeperRoot.AssemblyLinearVelocity=Vector3.zero
				keeperRoot.AssemblyAngularVelocity=Vector3.zero
				if session.LastPositions then session.LastPositions[keeper]=keeperRoot.Position end
			end
			if keeperRoot then keeperRoot.Anchored=false end
			keeper:SetAttribute("position","GK")
			keeper:SetAttribute("IsGoalkeeper",true)
			keeper:SetAttribute("Goalkeeper",true)
			keeper:SetAttribute("VTRGoalkeeper",true)
			keeper:SetAttribute("VTRTutorialFrozen",nil)
			keeper:SetAttribute("AIAssignment","GoalkeeperPosition")
			keeper:SetAttribute("VTRParked",nil)
			keeper:SetAttribute("VTRCinematicParked",nil)
			for _,descendant in keeper:GetDescendants()do
				if descendant:IsA("BasePart")then
					descendant.LocalTransparencyModifier=0
					if descendant.Name~="HumanoidRootPart"then descendant.Transparency=0 end
					descendant.CanTouch=true
				end
			end
		end
		local owner=session.Possession and session.Possession:GetOwner()or nil
		local saved=(session.World and session.World.Ball and session.World.Ball:GetAttribute("VTRGoalkeeperHeld")==true)or(owner~=nil and owner==keeper)or(session.BallService and session.BallService.MotionKind=="Save")
		if saved and session.TutorialShootingRestarting~=true then
			session.TutorialShootingRestarting=true
			self:_playTutorialRestartTransition(session)
			task.delay(.75,function()if self.Sessions[session.Player]==session and not session.Ended then self:_restartWorldCupTutorialStage(session,3)end end)
		end
		return
	end
	if session.TutorialStage==4 then
		if session.TutorialAllowAI~=true then return end
		local attackers=session.TutorialDefenseAttackers
		if type(attackers)~="table"or #attackers<=0 then return end
		local owner=session.Possession and session.Possession:GetOwner()or nil
		if owner and tostring(owner:GetAttribute("VTRTeam")or"")=="Home"then
			if os.clock()>=(tonumber(session.TutorialDefenseStopCooldownUntil)or 0)then
				session.TutorialDefenseStopCooldownUntil=os.clock()+.9
				session.TutorialStops=(session.TutorialStops or 0)+1
				if session.TutorialStops>=2 then
					self:_tutorialPrompt(session,"DEFENDING COMPLETE","",2,2)
					task.delay(1.6,function()if self.Sessions[session.Player]==session and not session.Ended then self:_restartWorldCupTutorialStage(session,5)end end)
					return
				end
				self:_tutorialPrompt(session,"STOP 2 ATTACKS","Tackle",session.TutorialStops,2)
				session.TutorialDefenseShotAt=nil
				session.TutorialDefenseNextAttackAt=os.clock()+.55
			end
			if os.clock()<(tonumber(session.TutorialDefenseNextAttackAt)or 0)then return end
		end
		if not owner or tostring(owner:GetAttribute("VTRTeam")or"")~="Away"then
			local index=((tonumber(session.TutorialStops)or 0)%#attackers)+1
			local nextAttacker=attackers[index]or attackers[1]
			if nextAttacker and nextAttacker.Parent then
				self:_tutorialBallTo(session,nextAttacker)
				owner=nextAttacker
			end
		end
		if not owner or not owner.Parent or tostring(owner:GetAttribute("VTRTeam")or"")~="Away"then return end
		local ownerRoot=tutorialRoot(owner)
		local humanoid=owner:FindFirstChildOfClass("Humanoid")
		local goalSign=tonumber(session.TutorialDefenseGoalSign)or 1
		if not ownerRoot or not humanoid or not session.World then return end
		local goalTarget=tutorialPitchGoalPoint(session,goalSign,0,2.4,6)
		local offset=goalTarget-ownerRoot.Position
		local flat=Vector3.new(offset.X,0,offset.Z)
		owner:SetAttribute("VTRSprinting",true)
		owner:SetAttribute("VTRTutorialPressing",true)
		if flat.Magnitude>.25 then
			local attackSpeed=math.max((Config.Movement and Config.Movement.SprintSpeed)or 24,26)
			humanoid.WalkSpeed=attackSpeed
			humanoid:Move(flat.Unit,false)
			ownerRoot.AssemblyLinearVelocity=Vector3.new(flat.Unit.X*attackSpeed,ownerRoot.AssemblyLinearVelocity.Y,flat.Unit.Z*attackSpeed)
		end
		for index,attacker in attackers do
			if attacker and attacker.Parent and attacker~=owner then
				local root=tutorialRoot(attacker)
				local supportHumanoid=attacker:FindFirstChildOfClass("Humanoid")
				if root and supportHumanoid then
					local laneX=(index-2)*32
					local ownerLocal=session.World.PitchCFrame:PointToObjectSpace(ownerRoot.Position)
					local supportLocal=Vector3.new(laneX,3,math.clamp(ownerLocal.Z+goalSign*22,-session.World.Length*.5+36,session.World.Length*.5-36))
					local supportTarget=tutorialWorldPoint(session,supportLocal)
					local supportOffset=supportTarget-root.Position
					local supportFlat=Vector3.new(supportOffset.X,0,supportOffset.Z)
					if supportFlat.Magnitude>4 then
						local supportSpeed=math.max((Config.Movement and Config.Movement.RunSpeed)or 17,18)
						supportHumanoid.WalkSpeed=supportSpeed
						supportHumanoid:Move(supportFlat.Unit,false)
						root.AssemblyLinearVelocity=Vector3.new(supportFlat.Unit.X*supportSpeed,root.AssemblyLinearVelocity.Y,supportFlat.Unit.Z*supportSpeed)
					else
						supportHumanoid:Move(Vector3.zero,false)
						root.AssemblyLinearVelocity=Vector3.new(0,root.AssemblyLinearVelocity.Y,0)
					end
					attacker:SetAttribute("VTRSprinting",supportFlat.Magnitude>18)
					if session.LastPositions then session.LastPositions[attacker]=root.Position end
				end
			end
		end
		local shotReady=flat.Magnitude<=105 and os.clock()>=(tonumber(session.TutorialDefenseShotAt)or 0)
		if shotReady and session.BallService then
			session.TutorialDefenseShotAt=os.clock()+2.35
			local lateral=(ownerRoot.Position-goalTarget):Dot(session.World.PitchCFrame.RightVector)
			local shotTarget=goalTarget+session.World.PitchCFrame.RightVector*math.clamp(lateral,-10,10)
			session.BallService:Kick(owner,"Shot",shotTarget-ownerRoot.Position,.46,nil,nil,nil,shotTarget)
		end
		if session.LastPositions then session.LastPositions[owner]=ownerRoot.Position end
		return
	end
	if session.TutorialStage~=2 or session.TutorialAllowAI~=true then return end
	local defender=session.TutorialDefender
	local owner=session.Possession and session.Possession:GetOwner()or nil
	if not defender or not owner or not defender.Parent or not owner.Parent then return end
	if tostring(owner:GetAttribute("VTRTeam")or"")~="Home"then return end
	if session.TeamControl and session.TeamControl:GetActive(session.Player)~=owner then
		self:_tutorialSetActive(session,owner,"TutorialPassing")
	end
	self:_tutorialUpdatePassTarget(session,owner)
	local defenderRoot=tutorialRoot(defender)
	local ownerRoot=tutorialRoot(owner)
	local humanoid=defender:FindFirstChildOfClass("Humanoid")
	if not defenderRoot or not humanoid then return end
	defenderRoot.Anchored=false
	defender:SetAttribute("VTRTutorialPressing",true)
	defender:SetAttribute("VTRSprinting",true)
	local pressureTarget=ownerRoot and ownerRoot.Position or nil
	if session.BallService and session.BallService.MotionKind=="Pass" and typeof(session.BallService.PassTargetPoint)=="Vector3"then
		pressureTarget=session.BallService.PassTargetPoint
	elseif typeof(session.World and session.World.Ball and session.World.Ball:GetAttribute("VTRPassTarget"))=="Vector3"then
		pressureTarget=session.World.Ball:GetAttribute("VTRPassTarget")
	end
	if not pressureTarget then return end
	local offset=pressureTarget-defenderRoot.Position
	local flat=Vector3.new(offset.X,0,offset.Z)
	if flat.Magnitude<=5.6 then
		if session.BallService and session.BallService.MotionKind=="Pass" then
			defenderRoot.AssemblyLinearVelocity=Vector3.zero
			humanoid:Move(Vector3.zero,false)
		elseif session.Possession then
			session.Possession:ForcePickup(defender)
			defenderRoot.AssemblyLinearVelocity=Vector3.zero
			humanoid:Move(Vector3.zero,false)
		end
	elseif flat.Magnitude>.25 then
		local pressSpeed=math.max((Config.Movement and Config.Movement.SprintSpeed)or 24,30)
		humanoid.WalkSpeed=pressSpeed
		humanoid:Move(flat.Unit,false)
		defenderRoot.AssemblyLinearVelocity=Vector3.new(flat.Unit.X*pressSpeed,defenderRoot.AssemblyLinearVelocity.Y,flat.Unit.Z*pressSpeed)
	else
		defender:SetAttribute("VTRSprinting",false)
		humanoid:Move(Vector3.zero,false)
	end
	if session.LastPositions then session.LastPositions[defender]=defenderRoot.Position end
end

function Service:_resetForExtraTimeKickoff(session:any)
	session.PendingReplayRestart=nil
	session.ReplayRestartGate=nil
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

function Service:_startRankedPenaltyShootout(session:any):boolean
	if session.Ranked~=true or not self:_scoreTied(session) or session.PenaltyShootoutStarted==true then
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
		session.World.Ball:SetAttribute("VTRWorldPaused",nil)
		session.World.Ball:SetAttribute("VTRPenaltyShotActive",nil)
	end

	session.PenaltyShootout={Home=0,Away=0,Rounds={},Attempts={},Ranked=true,Manual=true}
	session.PenaltyShootoutWinner=nil
	session.RankedShootout={NextAttempt=1,HomeTaken=0,AwayTaken=0,Active=false,ShotStartedAt=0}
	broadcast(self.State,session,{Type="PenaltyShootout",Phase="PENALTY SHOOTOUT",Ranked=true,Manual=true,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,PenaltyHome=0,PenaltyAway=0,Winner=nil,Rounds={}})
	task.delay(1.15,function()
		if not session.Ended and session.PenaltyShootoutStarted==true and session.PenaltyShootoutResolved~=true then
			self:_beginRankedShootoutAttempt(session)
		end
	end)

	return true
end

function Service:_rankedShootoutTaker(session:any,side:string,taken:number):Model?
	local team=session.Teams and session.Teams[side]or{}
	local choices={}
	for _,model in team do
		if model and model.Parent and tostring(model:GetAttribute("position")or"")~="GK" and model:GetAttribute("VTRSentOff")~=true then
			table.insert(choices,model)
		end
	end
	if #choices==0 then return team[1] end
	return choices[(taken%#choices)+1]
end

function Service:_rankedShootoutCanEnd(session:any):boolean
	local shootout=session.RankedShootout
	local pens=session.PenaltyShootout
	if not shootout or not pens then return false end
	local home=tonumber(pens.Home)or 0
	local away=tonumber(pens.Away)or 0
	local homeTaken=tonumber(shootout.HomeTaken)or 0
	local awayTaken=tonumber(shootout.AwayTaken)or 0
	if homeTaken<5 or awayTaken<5 then
		local homeRemaining=5-homeTaken
		local awayRemaining=5-awayTaken
		return home>away+awayRemaining or away>home+homeRemaining
	end
	return homeTaken==awayTaken and home~=away
end

function Service:_beginRankedShootoutAttempt(session:any)
	local shootout=session.RankedShootout
	local pens=session.PenaltyShootout
	if not shootout or not pens or session.Ended or session.PenaltyShootoutResolved==true then return end
	if self:_rankedShootoutCanEnd(session)then
		pens.Home=tonumber(pens.Home)or 0
		pens.Away=tonumber(pens.Away)or 0
		session.PenaltyShootoutWinner=pens.Home>pens.Away and"Home"or"Away"
		session.PenaltyShootoutResolved=true
		broadcast(self.State,session,{Type="PenaltyShootout",Phase="COMPLETE",Ranked=true,Manual=true,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,PenaltyHome=pens.Home,PenaltyAway=pens.Away,Winner=session.PenaltyShootoutWinner,Rounds=pens.Rounds})
		task.delay(2.2,function()if not session.Ended then self:EndMatch(session.StepOwner,true)end end)
		return
	end
	local attempt=tonumber(shootout.NextAttempt)or 1
	local side=attempt%2==1 and"Home"or"Away"
	local round=math.floor((attempt+1)/2)
	local takenKey=side=="Home"and"HomeTaken"or"AwayTaken"
	local taker=self:_rankedShootoutTaker(session,side,tonumber(shootout[takenKey])or 0)
	if not taker then
		self:_completeRankedShootoutAttempt(session,side,false,"NoTaker")
		return
	end
	shootout.Active=true
	shootout.ActiveSide=side
	shootout.ActiveRound=round
	shootout.ActiveAttempt=attempt
	shootout.ActiveTaker=taker
	shootout.ShotStartedAt=0
	local goalSign=side=="Home"and-1 or 1
	local spot=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,1.15,goalSign*(session.World.Length*.5-12)))
	broadcast(self.State,session,{Type="PenaltyShootout",Phase="ATTEMPT",Ranked=true,Manual=true,ActiveSide=side,Round=round,Attempt=attempt,Taker=taker:GetAttribute("DisplayName")or taker.Name,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,PenaltyHome=pens.Home,PenaltyAway=pens.Away,Winner=nil,Rounds=pens.Rounds})
	self:_startSetPiece(session,"Penalty",side,spot,taker)
end

function Service:_completeRankedShootoutAttempt(session:any,side:string,scored:boolean,reason:string?)
	local shootout=session.RankedShootout
	local pens=session.PenaltyShootout
	if not shootout or not pens or shootout.Active~=true or session.PenaltyShootoutResolved==true then return end
	side=side=="Away"and"Away"or"Home"
	shootout.Active=false
	if side=="Home"then shootout.HomeTaken=(tonumber(shootout.HomeTaken)or 0)+1 else shootout.AwayTaken=(tonumber(shootout.AwayTaken)or 0)+1 end
	if scored then pens[side]=(tonumber(pens[side])or 0)+1 end
	local round=tonumber(shootout.ActiveRound)or math.max(tonumber(shootout.HomeTaken)or 0,tonumber(shootout.AwayTaken)or 0)
	local entry=pens.Rounds[round]or{Round=round,HomeTotal=tonumber(pens.Home)or 0,AwayTotal=tonumber(pens.Away)or 0}
	entry[side]=scored==true
	entry.HomeTotal=tonumber(pens.Home)or 0
	entry.AwayTotal=tonumber(pens.Away)or 0
	entry.Reason=reason
	pens.Rounds[round]=entry
	table.insert(pens.Attempts,{Round=round,Side=side,Scored=scored==true,Reason=reason,HomeTotal=entry.HomeTotal,AwayTotal=entry.AwayTotal})
	shootout.NextAttempt=(tonumber(shootout.ActiveAttempt)or tonumber(shootout.NextAttempt)or 1)+1
	shootout.ShotStartedAt=0
	if session.World and session.World.Ball then
		session.World.Ball:SetAttribute("VTRPenaltyShotActive",nil)
		session.World.Ball:SetAttribute("VTRPostGoalPhysicsUntil",nil)
		session.World.Ball:SetAttribute("VTRWorldPaused",nil)
		session.World.Ball.Anchored=true
		session.World.Ball.AssemblyLinearVelocity=Vector3.zero
		session.World.Ball.AssemblyAngularVelocity=Vector3.zero
	end
	if session.Possession then session.Possession:Reset()end
	if session.OutOfBounds then session.OutOfBounds:Reset()end
	if session.Goals then session.Goals:Unlock()end
	session.Running=false
	session.Phase="PENALTY SHOOTOUT"
	self:_setPlayersFrozen(session,true)
	broadcast(self.State,session,{Type="PenaltyShootout",Phase="RESULT",Ranked=true,Manual=true,ResultSide=side,Scored=scored==true,Reason=reason,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,PenaltyHome=pens.Home,PenaltyAway=pens.Away,Winner=nil,Rounds=pens.Rounds})
	task.delay(1.55,function()
		if not session.Ended and session.PenaltyShootoutStarted==true and session.PenaltyShootoutResolved~=true then
			self:_beginRankedShootoutAttempt(session)
		end
	end)
end

function Service:_stepRankedPenaltyShootout(session:any)
	local shootout=session.RankedShootout
	if not shootout or shootout.Active~=true or session.PenaltyShootoutResolved==true then return end
	local ball=session.World and session.World.Ball
	local side=tostring(shootout.ActiveSide or"Home")
	local shotStarted=tonumber(shootout.ShotStartedAt)or 0
	local defendingSide=side=="Home"and"Away"or"Home"
	local keeper=getGoalkeeper(session.Teams[defendingSide])
	local owner=session.Possession and session.Possession:GetOwner()or nil
	if owner==keeper or (keeper and keeper:GetAttribute("VTRGoalkeeperHolding")==true)or session.BallService.MotionKind=="Save"then
		self:_completeRankedShootoutAttempt(session,side,false,"Save")
		return
	end
	if not ball then return end
	if shotStarted<=0 and session.BallService and session.BallService.MotionKind=="Shot" and session.BallService:GetLastTouchTeam()==side then
		shotStarted=session.BallService.MotionStarted or os.clock()
		shootout.ShotStartedAt=shotStarted
	end
	if shotStarted<=0 then return end
	local localPosition=session.World.PitchCFrame:PointToObjectSpace(ball.Position)
	local outside=math.abs(localPosition.X)>session.World.Width*.5+2 or math.abs(localPosition.Z)>session.World.Length*.5+2
	local elapsed=os.clock()-shotStarted
	if outside or elapsed>=1 then
		self:_completeRankedShootoutAttempt(session,side,false,"Miss")
	end
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
	local guess=PenaltyConfig.NormalizeSlot(slot)
	if not guess then
		guess=keeper:GetAttribute("VTRPenaltyUserKeeper")==true and "MIDDLE" or PenaltyConfig.RandomSlot(Random.new())
	end
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

local DEBUG_ACTIONS={AITacticsDebug=true,ShootingPracticeTuning=true,DebugCorner=true,DebugFreeKick=true,DebugPenaltyAttack=true,DebugPenaltyDefense=true}
function Service:_debugActionAllowed(session:any,player:Player,actionType:string):boolean
	local now=os.clock()
	session.DebugActionAt=session.DebugActionAt or{}
	local allowed=GameplayDebugPolicy.CanUse(actionType,{Authorized=DeveloperAccessService.IsAuthorized(player),IsStudio=RunService:IsStudio(),IsPrivateServer=game.PrivateServerId~="",Ranked=session.Ranked==true,WorldCup=worldCupSession(session),ShootingPractice=session.ShootingPractice==true,RateReady=now-(tonumber(session.DebugActionAt[player])or 0)>=.75})
	if allowed then session.DebugActionAt[player]=now;return true end
	if self.Analytics then self.Analytics:TrackOnce(player,tostring(session.World and session.World.Folder.Name or"match")..":"..actionType,"playability_debug_action_rejected",{mode=matchMode(session),actionFamily=actionType})end
	return false
end
function Service:_action(player:Player,payload:any)
	local session=self.Sessions[player]
	if not session or type(payload)~="table"then return end
	local actionType=tostring(payload.Type or"")
	if DEBUG_ACTIONS[actionType]and not self:_debugActionAllowed(session,player,actionType)then return end
	if actionType=="ActionQueueCancelled"or actionType=="MobileActionCancelled"then
		local eventName=actionType=="ActionQueueCancelled"and"playability_action_queue_cancelled"or"playability_mobile_action_cancelled"
		self:_track(session,player,eventName,{cancellationReason=tostring(payload.Reason or"cancelled"),actionFamily=tostring(payload.ActionFamily or"")})
		return
	end
	if payload.Type=="ClientReady"then
		if tostring(payload.MatchSessionId or"")~=tostring(session.World and session.World.Folder.Name or"")then return end
		if session.Phase=="PRE MATCH"or session.ShootingPractice==true or session.WorldCupTutorial==true then
			session.ClientReady[player]=true
			local state=session.PlayerState and session.PlayerState[player]
			if state then
				local device=tostring(payload.Device or"");state.Device=table.find({"KeyboardMouse","Gamepad","Touch"},device)and device or"Unknown"
				local assist=tostring(payload.ReceiverAssistMode or"");state.ReceiverAssistMode=table.find({"Newcomer","Standard","Manual"},assist)and assist or"Standard"
				local camera=tostring(payload.CameraPreset or"");state.CameraPreset=table.find({"Tactical","Pro","Roblox"},camera)and camera or"Auto"
			end
		end
		return
	end
	if payload.Type=="PresentationReady"then
		if tostring(payload.MatchSessionId or"")~=tostring(session.World and session.World.Folder.Name or"")then return end
		if session.PresentationActive==true and session.Phase=="PRE MATCH"then session.PresentationReady[player]=true end
		return
	end
	if payload.Type=="ReplayFinished"then
		self:_ackReplayFinished(session,player,payload.ReplayId)
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
		if developmentAccess(player)and not session.Ranked and not worldCupSession(session)then self:_applyShootingPracticeTuning(session,payload.Tuning)end
		self:_resetShootingPractice(session,"MANUAL")
		return
	end
	if payload.Type=="SecondHalfWatchdogReset"then
		self:_watchdogResetSecondHalf(session,player)
		return
	end
	if payload.Type=="CampaignManagerAction"then
		if not session.CampaignAscension or not session.Setup or session.Setup.WatchMode~=true then return end
		local manager=session.CampaignManager
		if type(manager)~="table"then return end
		local now=os.clock()
		if now-(tonumber(manager.LastActionAt)or 0)<.35 then return end
		local action=tostring(payload.Action or"")
		local half=session.Clock and session.Clock:Payload().Half or 1
		local afterHalf=half>=2 or session.HalfTimeBreak==true or session.ExtraTimeStarted==true
		local applied=false
		if action=="Mentality"then
			local mentality=tostring(payload.Value or"")
			local aliases={Balanced="Balanced",Attack="High Press",Defend="Low Block",["High Press"]="High Press",["Counter Attack"]="Counter Attack"}
			local identity=aliases[mentality]
			if identity and manager.CurrentMentality~=mentality then
				local tactics=sanitizeRuntimeTactics({Identity=identity})
				if session.AI and session.AI.UpdateTactics then session.AI:UpdateTactics("Home",tactics)end
				manager.CurrentMentality=mentality
				applied=true
			end
		elseif action=="Formation"then
			local formation=tostring(payload.Value or"")
			if table.find({"4-3-3","4-2-3-1","4-4-2","3-5-2","5-3-2"},formation)and manager.CurrentFormation~=formation then
				session.Formation.Home=FormationService.Build(formation,session.World.Width,session.World.Length)
				if session.AI then
					session.AI.Formations.Home=formation
					if session.AI.Controller and session.AI.Controller.Formations then session.AI.Controller.Formations.Home=formation end
				end
				manager.CurrentFormation=formation
				applied=true
			end
		elseif action=="HalftimeInstruction"and afterHalf and manager.HalftimeInstructionApplied~=true then
			local instruction=tostring(payload.Value or"Balanced")
			if table.find({"Balanced","Attack","Defend","High Press","Counter Attack"},instruction)then
				local aliases={Balanced="Balanced",Attack="High Press",Defend="Low Block",["High Press"]="High Press",["Counter Attack"]="Counter Attack"}
				local tactics=sanitizeRuntimeTactics({Identity=aliases[instruction]})
				if session.AI and session.AI.UpdateTactics then session.AI:UpdateTactics("Home",tactics)end
				manager.HalftimeInstructionApplied=true
				manager.CurrentHalftimeInstruction=instruction
				applied=true
			end
		end
		if applied then
			local recorded=self.CampaignAscension and self.CampaignAscension:RecordManagerInteraction(player,session,action,{AfterHalf=afterHalf})
			if recorded then self.State:FireClient(player,{Type="CampaignManagerState",Manager=table.clone(manager),Objective=session.Setup.AscensionObjective})end
		else
			self:_track(session,player,"playability_manager_input_error",{actionFamily=action})
		end
		return
	end
	if session.WorldCupTutorial==true and (payload.Type=="TutorialStartMatch"or payload.Type=="TutorialReady")then
		self:_handleWorldCupTutorialAction(session,player,payload)
		return
	end
	if session.WorldCupTutorial==true and session.TutorialStage==1 and payload.Type~="Move"and payload.Type~="Sprint"then
		return
	end
	if session.WorldCupTutorial==true and session.TutorialStage==2 and payload.Type~="Pass"and payload.Type~="Move"then
		return
	end
	if session.ShootingPractice and payload.Type~="Shot"and payload.Type~="Move"and payload.Type~="Sprint"and payload.Type~="ReceiverAssistOverride"and payload.Type~="Pause"and payload.Type~="Forfeit"then
		return
	end
	if session.ShootingPractice and payload.Type=="Shot"then
		payload.PracticeShotTarget=true
	end
	if session.WorldCupTutorial==true and payload.Type=="Shot"then
		payload.Charge=math.clamp(tonumber(payload.Charge)or.58,.35,1)
		payload.GoalTarget=true
		local goalSign=tonumber(session.TutorialShootingGoalSign)or -1
		if session.World then
			local rectangle=GoalModelResolver.ResolveByAttackSign(goalSign,session.World.PitchCFrame,session.World.Width,session.World.Length)
			local aim=typeof(payload.AimPosition)=="Vector3"and payload.AimPosition or nil
			local offset=aim and(aim-rectangle.PlanePoint)or Vector3.zero
			local width=rectangle.RightBound-rectangle.Left
			local horizontal=aim and offset:Dot(rectangle.Right)or(rectangle.Left+width*.5)
			local vertical=aim and offset:Dot(rectangle.Up)or math.max(2.4,(rectangle.Top-rectangle.Bottom)*.38)
			horizontal=math.clamp(horizontal,rectangle.Left+2.1,rectangle.RightBound-2.1)
			vertical=math.clamp(vertical,rectangle.Bottom+1.4,rectangle.Top-1.2)
			payload.AimPosition=rectangle.PlanePoint+rectangle.Right*horizontal+rectangle.Up*vertical
		end
	end
	if session.Setup and session.Setup.WatchMode==true and payload.Type~="Pause"and payload.Type~="Forfeit"and payload.Type~="ManualSubstitution"then return end
	if session.FiveVFive==true and session.LocalPausedPlayers and session.LocalPausedPlayers[player] and payload.Type~="Pause"and payload.Type~="Forfeit"then return end
	if session.Paused and payload.Type~="Pause"and payload.Type~="Forfeit"and payload.Type~="ManualSubstitution"then return end
	if session.SetPieces and session.SetPieces:HandleAction(player,payload)then return end
	if payload.Type=="DebugCorner"then
		if session.Running then local ballLocal=session.World.PitchCFrame:PointToObjectSpace(session.World.Ball.Position);local x=ballLocal.X>=0 and session.World.Width*.5+2 or-session.World.Width*.5-2;local location=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(x,.2,-session.World.Length*.5-2));self:_startSetPiece(session,"Corner","Home",location)end
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
				self.State:FireClient(player,{Type="ActivePlayer",Model=keeper,Name=keeper:GetAttribute("DisplayName"),Position=keeper:GetAttribute("position"),Reason="PenaltyDefense",PenaltyLocation=session.World.Ball.Position,GoalPosition=goalPosition,GoalSign=sign})
			end
			session.PendingAIPenalty={Player=player,AttackingSide=attackingSide,DefendingSide=playerSide,At=os.clock()+2.35}
		end
		return
	end
	if payload.Type=="Pause"then
		if session.FiveVFive==true then
			self:_setLocalFiveVFivePause(session,player,payload.Active==true)
			return
		end
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
		if session.CampaignAscension and session.Setup and session.Setup.WatchMode==true and session.CampaignManager then
			local manager=session.CampaignManager
			local half=session.Clock and session.Clock:Payload().Half or 1
			local recorded=self.CampaignAscension and self.CampaignAscension:RecordManagerInteraction(player,session,"Substitution",{AfterHalf=half>=2 or session.HalfTimeBreak==true})
			if recorded then self.State:FireClient(player,{Type="CampaignManagerState",Manager=table.clone(manager),Objective=session.Setup.AscensionObjective})end
		end
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
			if released and session.PenaltyShootoutStarted==true and session.PenaltyShootoutResolved~=true and session.RankedShootout and session.Phase=="Penalty" and payload.Type=="Shot"then
				session.RankedShootout.ShotStartedAt=os.clock()
			end
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
	if actionType=="Move"and typeof(payload.Direction)=="Vector3"and payload.Direction.Magnitude>.08 then
		self:_track(session,player,"playability_first_move",{})
	elseif actionType=="Pass"then
		self:_track(session,player,"playability_first_pass_attempt",{actionFamily=tostring(payload.PassType or"Ground")})
	elseif actionType=="Shot"then
		self:_track(session,player,"playability_first_shot",{actionFamily="Shot"})
	elseif actionType=="Tackle"or actionType=="SlideTackle"then
		self:_track(session,player,"playability_first_tackle",{actionFamily=actionType})
	end
	if payload.Type=="Sprint"then
		if session.WorldCupTutorial==true then self:_handleWorldCupTutorialAction(session,player,payload)end
		local playerState=session.PlayerState and session.PlayerState[player];if playerState then playerState.SprintRequested=payload.Active==true;playerState.SprintLastSignalAt=os.clock()end
	elseif payload.Type=="Context"then
		local active=session.TeamControl:GetActive(player);local owns=active and session.Possession:GetOwner()==active
		if owns and active then active:SetAttribute("VTRCloseControl",payload.Active==true)end
	elseif payload.Type=="CallPass"then
		-- Q is a team-control/support request only. Never auto-pass for the
		-- player-controlled team; the user must press RMB/LMB for the ball action.
		self.State:FireClient(player,{Type="Info",Message="Support run requested.",Important=false})
	else
		local motionStarted=tonumber(session.BallService and session.BallService.MotionStarted)or 0
		local passer=session.TeamControl:GetActive(player)
		session.TeamControl:Handle(player,payload)
		if actionType=="Pass"and session.BallService and session.BallService.MotionKind=="Pass"and(tonumber(session.BallService.MotionStarted)or 0)>motionStarted then
			session.PlayabilityPendingPass={Player=player,Passer=passer,Side=passer and tostring(passer:GetAttribute("VTRTeam")or"")or"",At=os.clock(),ActionFamily=tostring(payload.PassType or"Ground")}
		end
		if session.WorldCupTutorial==true then
			self:_handleWorldCupTutorialAction(session,player,payload)
		end
	end
end

function Service:_stepPlayabilityTelemetry(session:any)
	local pending=session.PlayabilityPendingPass
	if pending then
		local owner=session.Possession and session.Possession:GetOwner()or nil
		if owner and owner~=pending.Passer then
			if tostring(owner:GetAttribute("VTRTeam")or"")==pending.Side then self:_track(session,pending.Player,"playability_first_pass_completed",{actionFamily=pending.ActionFamily})end
			session.PlayabilityPendingPass=nil
		elseif os.clock()-(tonumber(pending.At)or 0)>5 then
			session.PlayabilityPendingPass=nil
		end
	end
	local correctionCount=tonumber(session.World and session.World.Ball and session.World.Ball:GetAttribute("VTRHardCorrectionCount"))or 0
	if correctionCount>(tonumber(session.PlayabilityHardCorrectionCount)or 0)then
		session.PlayabilityHardCorrectionCount=correctionCount
		local owner=session.Possession and session.Possession:GetOwner()or nil
		local ownerId=tonumber(owner and owner:GetAttribute("VTRUserId"))or 0
		for _,participant in session.Players do
			if participant.UserId==ownerId then
				local magnitude=tonumber(session.World.Ball:GetAttribute("VTRLastHardCorrectionMagnitude"))or 0
				self:_track(session,participant,"playability_ball_hard_correction",{hardCorrectionMagnitudeBand=magnitude<8 and"6-8"or magnitude<12 and"8-12"or"12+"})
				break
			end
		end
	end
end

function Service:_step(dt:number)
	local seen:any={}
	for _,session in self.Sessions do
		if seen[session]then continue end;seen[session]=true
		if session.Ended then continue end
		self:_stepPlayabilityTelemetry(session)
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
		if session.WorldCupFirstPassPending==true and session.Possession then
			local owner=session.Possession:GetOwner()
			if owner and owner~=session.WorldCupFirstPassPasser and tostring(owner:GetAttribute("VTRTeam")or"")=="Home"then
				session.WorldCupFirstPassPending=false
				if session.World and session.World.Ball then session.World.Ball:SetAttribute("VTRWorldCupFirstPassPending",nil)end
				if session.WorldCupFirstPassPasser and session.WorldCupFirstPassPasser.Parent then session.WorldCupFirstPassPasser:SetAttribute("VTRNoAutoPassUntil",nil)end
				if session.WorldCupTutorial==true and session.TutorialStage==2 then
					session.TutorialAllowAI=true
					local defender=session.TutorialDefender
					local defenderRoot=tutorialRoot(defender)
					if defenderRoot then defenderRoot.Anchored=false;defenderRoot.AssemblyLinearVelocity=Vector3.zero;defenderRoot.AssemblyAngularVelocity=Vector3.zero end
					if defender then defender:SetAttribute("aiControlled",false);defender:SetAttribute("controlledByUser",false);defender:SetAttribute("VTRTutorialPressing",true)end
				end
			end
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
		if session.PendingReplayRestart and session.PendingReplayRestart.Ready==true and self:_allReplayAcks(session)then
			self:_resumeReplayRestart(session,"all participants finished")
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
		session.Accumulator+=dt
		if session.WorldCupTutorial~=true then session.Clock:Step(dt)end
		local grantIndex=math.floor((session.Clock:Payload().GameSeconds or 0)/1800)
		if grantIndex>(session.PauseGrantIndex or 0)then
			for _,participant in session.Players do
				session.PauseSecondsByPlayer[participant]=(session.PauseSecondsByPlayer[participant] or 0)+60*(grantIndex-(session.PauseGrantIndex or 0))
			end
			session.PauseGrantIndex=grantIndex
		end
		local activeOwners:any={};local sprintingByModel:any={}
		for _,participant in session.Players do
			local state=session.PlayerState[participant]
			local active=session.TeamControl:GetActive(participant)
			if active and state then
				if state.SprintRequested==true and os.clock()-(tonumber(state.SprintLastSignalAt)or 0)>StaminaConfig.RequestWatchdogSeconds then state.SprintRequested=false end
				local root=active:FindFirstChild("HumanoidRootPart")::BasePart?
				local speed=root and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude or 0
				local move=math.clamp(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0,0,1)
				local frozen=active:GetAttribute("VTRFrozen")==true or active:GetAttribute("VTRSentOff")==true
				local stunned=(tonumber(active:GetAttribute("VTRStunnedUntil"))or 0)>os.clock()
				local reserve,endurance,actual=session.StaminaService:Step(active,dt,{SprintRequested=state.SprintRequested==true,SprintAllowed=session.Running==true and session.Paused~=true,MoveMagnitude=move,CurrentSpeed=speed,HasBall=session.Possession:GetOwner()==active,UserControlled=true,Frozen=frozen,Stunned=stunned,ActionLocked=active:GetAttribute("VTRActionSprintLocked")==true})
				state.Stamina=reserve;state.Endurance=endurance;state.SprintActual=actual
				activeOwners[active]=participant;sprintingByModel[active]=actual
			end
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
		local currentHalf=session.Clock and session.Clock:Payload().Half or 1;if session.AI and session.AI.SetHalf then session.AI:SetHalf(currentHalf)end;if session.Offside and session.Offside.SetHalf and session.OffsideDisabled~=true then session.Offside:SetHalf(currentHalf)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(currentHalf)end;if session.Stats and session.Stats.RecordPositions then session.Stats:RecordPositions(session.Models,dt)end;session.BallService:Step(dt);session.TeamControl:Step();session.Animations:Step(session.Possession:GetOwner());session.Grounding:Step();local tutorialAI=session.WorldCupTutorial and session.TutorialAllowAI==true and session.TutorialStage~=1;if not session.ShootingPractice and (not session.WorldCupTutorial or tutorialAI) then session.AI:Step(dt)end;self:_stepWorldCupTutorial(session,dt);session.Goalkeepers:Step(dt);session.Goals:Step();if session.Running and not session.ShootingPractice and not session.WorldCupTutorial then session.OutOfBounds:Step()end;if not session.ShootingPractice and not session.WorldCupTutorial then RefereeService.Enforce(session.Models,session.World.PitchCFrame,session.World.Width,session.World.Length)end;if session.LinkDebug then session.LinkDebug:Step(session,dt)end
		if session.WorldCupTutorial then
			local owner=session.Possession and session.Possession:GetOwner()or nil
			if session.TutorialStage==2 and not session.TutorialRestarting and owner and tostring(owner:GetAttribute("VTRTeam")or"")=="Away"then
				session.TutorialRestarting=true
				broadcast(self.State,session,{Type="Info",Message="Tackled. Restarting passing drill.",Important=true})
				self:_playTutorialRestartTransition(session)
				task.delay(.65,function()if not session.Ended then self:_restartWorldCupTutorialStage(session,2)end end)
			end
		elseif session.ShootingPractice then
			self:_stepShootingPractice(session,dt)
		elseif session.PenaltyShootoutStarted==true and session.PenaltyShootoutResolved~=true then
			self:_stepRankedPenaltyShootout(session)
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
		elseif session.Accumulator>=.1 then session.Accumulator=0;local clockPayload=session.Clock:Payload();for _,participant in session.Players do local state=session.PlayerState[participant];self.State:FireClient(participant,{Type="Clock",GameSeconds=clockPayload.GameSeconds,Half=clockPayload.Half,AddedMinutes=clockPayload.AddedMinutes,InAddedTime=clockPayload.InAddedTime,AddedElapsed=clockPayload.AddedElapsed,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,Stamina=state and state.Stamina or Config.Stamina.Maximum,Endurance=state and state.Stamina or Config.Stamina.Maximum,SprintActual=state and state.SprintActual==true,SprintLocked=(session.TeamControl:GetActive(participant)and session.TeamControl:GetActive(participant):GetAttribute("VTRSprintLocked")==true)or false})end
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
	if os.clock()-(tonumber(chance.StartedAt)or os.clock())>=math.max(3,tonumber(session.Format and session.Format.FinalChanceSeconds)or 10)then
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
	self:_forceEndPrematchForResult(session,reason or"Leave")
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

function Service:_markWorldCupResultOutbox(session:any)
	local setup=session and session.Setup
	if not session or type(setup)~="table"or(setup.WorldCup~=true and session.PrivateWorldCupMatch~=true)then return end
	local homeScore=tonumber(session.World and session.World.HomeScore and session.World.HomeScore.Value)
	local awayScore=tonumber(session.World and session.World.AwayScore and session.World.AwayScore.Value)
	if homeScore==nil or awayScore==nil then return end
	local pendingId=tostring(setup.WorldCupPendingMatchId or session.WorldCupPendingMatch and session.WorldCupPendingMatch.Id or "")
	for _,participant in session.Players or{session.Player}do
		if participant and participant.Parent==Players then
			participant:SetAttribute("VTRWorldCupResultPending",true)
			participant:SetAttribute("VTRWorldCupResultHomeScore",homeScore)
			participant:SetAttribute("VTRWorldCupResultAwayScore",awayScore)
			participant:SetAttribute("VTRWorldCupResultPendingId",pendingId)
			participant:SetAttribute("VTRWorldCupResultAt",os.time())
		end
	end
end

function Service:EndMatch(player:Player,showResult:boolean):boolean
	local session=self.Sessions[player]
	if not session then return false end
	if session.Ended then return false end
	if showResult and session.WorldCupTutorial~=true and session.PenaltyShootoutResolved~=true and self:_resolveWorldCupKnockoutTiebreak(session)then
		return true
	end
	if showResult and session.Ranked==true and session.PenaltyShootoutResolved~=true and self:_scoreTied(session) and not session.ForfeitBy and not session.RankedForceLossUserId then
		return self:_startRankedPenaltyShootout(session)
	end
	for _,connection in session.Connections or{}do if connection and connection.Disconnect then connection:Disconnect()end end
	self:_clearFinalChance(session)
	session.Ended=true;session.Running=false;if session.SetPieces then session.SetPieces:Cancel()end
	self:_markWorldCupResultOutbox(session)
	if session.OnWorldCupCompleted then
		local ok,err=pcall(session.OnWorldCupCompleted,session)
		if not ok then warn("[VTR WORLDCUP RESULT] completion hook failed: "..tostring(err))end
	end
	if showResult then self:_finalWhistleFreeze(session)end
	if showResult then
		local gameSeconds=session.Clock:Payload().GameSeconds
		local rewards={}
		if session.OnBeforeResult then
			local ok,result=pcall(session.OnBeforeResult,session)
			if ok and type(result)=="table"then rewards=result elseif not ok then warn("[VTR MATCH RESULT] OnBeforeResult failed: "..tostring(result))end
		end
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
			elseif homeScore==awayScore and session.PenaltyShootoutWinner then
				result=(side==session.PenaltyShootoutWinner)and"Win"or"Loss"
			elseif homeScore~=awayScore then
				local sideWon=(side=="Home"and homeScore>awayScore)or(side=="Away"and awayScore>homeScore)
				result=sideWon and"Win"or"Loss"
			end
			self:_track(session,participant,"playability_match_complete",{result=result,stageDuration=os.clock()-(tonumber(session.StartedAt)or os.clock())})
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
				self.State:FireClient(participant,{Type="MatchEnded",Ranked=session.Ranked,LocalSide=side,Result=result,Forfeit=session.ForfeitBy~=nil,ForfeitReason=session.ForfeitReason,RankedLossUserId=session.RankedForceLossUserId,Home=homeScore,Away=awayScore,PenaltyShootout=session.PenaltyShootout,PenaltyShootoutWinner=session.PenaltyShootoutWinner,ExtraTime=session.ExtraTimeStarted==true,Stats=resultStats,Reward=rewardPayload,RankedWinPack=rankedWin and rewardPayload or nil,ResultDelay=math.max(2,tonumber(session.Format and session.Format.FullTimeSeconds)or 6)})
			end
		end
		if session.OnRankedEnded then task.defer(function()local ok,err=pcall(session.OnRankedEnded,session);if not ok then warn("[VTR MATCH RESULT] OnRankedEnded failed: "..tostring(err))end end)end
		if session.OnCompleted then task.defer(function()local ok,err=pcall(session.OnCompleted,session);if not ok then warn("[VTR MATCH RESULT] OnCompleted failed: "..tostring(err))end end)end
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
	if not session.Ended then self:_track(session,player,"playability_abandoned",{abandonmentStage=tostring(session.Phase or"Unknown")})end
	if session.FiveVFive==true and not session.Ended then
		if session.LocalPausedPlayers then session.LocalPausedPlayers[player]=nil end
		if session.TeamControl then session.TeamControl:Destroy(player)end
		self.Sessions[player]=nil
		session.PlayerSides[player]=nil
		session.PlayerState[player]=nil
		session.PauseSecondsByPlayer[player]=nil
		for index=#session.Players,1,-1 do
			if session.Players[index]==player then table.remove(session.Players,index)end
		end
		return
	end
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
