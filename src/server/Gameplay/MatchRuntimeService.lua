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
local MatchAnimationService=require(script.Parent.MatchAnimationService)
local MatchCharacterFactory=require(script.Parent.MatchCharacterFactory)
local GoalkeeperService=require(script.Parent.GoalkeeperService)
local OffsideService=require(script.Parent.OffsideService)
local GameplayLinkDebugService=require(script.Parent.GameplayLinkDebugService)
local Service={};Service.__index=Service
local PREMATCH_PRESENTATION_DURATION=66.0
local GOAL_REPLAY_RESTART_TIMEOUT=12.0
local function kickoffDebugEnabled():boolean
	return Workspace:GetAttribute("VTRKickoffDebug")~=false
end
local function debugKickoff(message:string,...:any)
	if kickoffDebugEnabled()then print("[VTR KICKOFF][Runtime] "..message,...)end
end
local function broadcast(remote:RemoteEvent,session:any,payload:any)
	for _,participant in session.Players or{session.Player}do if participant.Parent==Players then remote:FireClient(participant,payload)end end
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
local function markerCFrame(name:string):CFrame?
	local marker=Workspace:FindFirstChild(name) or Workspace:FindFirstChild(name,true)
	if not marker then return nil end
	if marker:IsA("BasePart")then return marker.CFrame end
	if marker:IsA("Model")then return marker:GetPivot()end
	if marker:IsA("Attachment")then return marker.WorldCFrame end
	return nil
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
	local world=buildWorld(player,finalSetup);local teams,formation=TeamSpawnService.Spawn(world.Folder,world.PitchCFrame,world.Width,world.Length,player,home,away,finalSetup);local models={};for _,m in teams.Home do table.insert(models,m)end;for _,m in teams.Away do table.insert(models,m)end;BallCollisionService.ApplyPlayers(models);for _,m in models do m:SetAttribute("VTRSession",player.UserId)end
	for _,group in{"Width","Depth","Press","Passing","Runs","Shape","Keeper"}do workspace:SetAttribute("TacticalDebug"..group,false)end;workspace:SetAttribute("TacticalDebug",false)
	local postGoalAnchorGuard=world.Ball:GetPropertyChangedSignal("Anchored"):Connect(function()
		local untilTime=tonumber(world.Ball:GetAttribute("VTRPostGoalPhysicsUntil"))or 0
		if untilTime>os.clock() and world.Ball.Anchored then
			local velocity=world.Ball:GetAttribute("VTRPostGoalVelocity")
			local angular=world.Ball:GetAttribute("VTRPostGoalAngularVelocity")
			world.Ball.Anchored=false
			if typeof(velocity)=="Vector3"then world.Ball.AssemblyLinearVelocity=velocity end
			if typeof(angular)=="Vector3"then world.Ball.AssemblyAngularVelocity=angular end
			world.Ball:SetNetworkOwner(nil)
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
	local stats=StatsService.new(models,world.PitchCFrame,world.Width,world.Length);local possession=PossessionService.new(world.Ball,self.State);local animations=MatchAnimationService.new(models);local ballService=BallService.new(world.Ball,possession,self.State,stats,models,animations);local teamControl=TeamControlService.new(self.State,teams,world.Ball,possession,ballService,world.PitchCFrame,world.Width,world.Length);local duration=math.max(60,finalSetup.MatchLength*60)
	local session={Player=player,Players=players,SidePlayers={Home=player,Away=opponent},PlayerSides={[player]="Home"},PlayerState={},StepOwner=player,Ranked=opponent~=nil,Setup=finalSetup,World=world,Teams=teams,Formation=formation,Models=models,Stats=stats,Possession=possession,BallService=ballService,Animations=animations,TeamControl=teamControl,Grounding=BallGroundingService.new(world.Ball,world.PitchCFrame,models),Clock=MatchClockService.new(duration),StaminaService=StaminaService.new(),Remaining=duration,Duration=duration,HalfTimeTriggered=false,Phase="PRE MATCH",Running=false,Ended=false,Accumulator=0,LastPositions={},MovementSpeeds={},BenchData={Home=home.Bench or{},Away=away.Bench or{}},UsedBench={Home={},Away={}},PauseSecondsByPlayer={},PauseRequester=nil,PauseResumeVotes={},PauseGrantIndex=0,PauseTimerAccumulator=0,Connections={postGoalAnchorGuard}}
	session.LinkDebug=GameplayLinkDebugService.new()
	if opponent then session.PlayerSides[opponent]="Away"end
	for _,participant in players do local hum=humanoids[participant];session.PlayerState[participant]={Stamina=Config.Stamina.Maximum,Endurance=Config.Stamina.Maximum,SprintRequested=false,PreviousSpeed=hum.WalkSpeed,PreviousJump=hum.JumpPower,ReturnCFrame=parkedReturnCFrames[participant] or CFrame.new(0,8,0)};session.PauseSecondsByPlayer[participant]=60;hum.WalkSpeed=0;hum.JumpPower=0;participant:SetAttribute("VTRInMatch",true);self.Sessions[participant]=session end
	for _,model in models do local modelRoot=model:FindFirstChild("HumanoidRootPart")::BasePart?;if modelRoot then session.LastPositions[model]=modelRoot.Position end end
	session.Goals=GoalService.new(world.Ball,world.PitchCFrame,world.Width,world.Length,function(team)self:_goal(session,team)end);session.AI=AIService.new(teams,formation,world.PitchCFrame,world.Width,world.Length,finalSetup.Difficulty,world.Ball,possession,ballService,finalSetup.TeamTactics);session.Goalkeepers=GoalkeeperService.new(world.Ball,teams,world.PitchCFrame,world.Width,world.Length,ballService,animations,self.State,session.AI);session.SetPieces=SetPieceService.new(self.State,world,teams,formation,possession,teamControl,ballService);session.OutOfBounds=OutOfBoundsService.new(world.Ball,world.PitchCFrame,world.Width,world.Length,ballService,function(kind,restartTeam,location)self:_startSetPiece(session,kind,restartTeam,location)end)
	session.Referee=RefereeService.new(self.State,stats,function(restartTeam:string,location:Vector3,restartKind:string?,forcedTaker:Model?)if not session.Ended then self:_startSetPiece(session,restartKind or "FreeKick",restartTeam,location,forcedTaker)end end,world.PitchCFrame,world.Width,world.Length);ballService:SetReferee(session.Referee)
	session.Offside=OffsideService.new(self.State,stats,teams,world.PitchCFrame,function(restartTeam:string,location:Vector3)if not session.Ended then session.World.Ball:SetAttribute("VTRRestartDisplayKind","Offside");self:_startSetPiece(session,"FreeKick",restartTeam,location)end end);ballService:SetOffsideService(session.Offside)
	local homeSummary=TeamDatabase.Summary(home.Team);local awaySummary=TeamDatabase.Summary(away.Team);local watchMode=finalSetup.WatchMode==true
	if watchMode then
		for _,model in models do
			model:SetAttribute("controlledByUser",false)
			model:SetAttribute("aiControlled",true)
			model:SetAttribute("VTRUserId",nil)
		end
	end
	self:_startPrematchPresentation(session)
	for _,participant in players do local side=session.PlayerSides[participant];local activePlayer=watchMode and(teams.Home[10]or teams.Home[1])or teamControl:Register(participant,side);self.State:FireClient(participant,{Type="MatchStarted",Ranked=session.Ranked,WatchMode=watchMode,ControlledSide=side,Opponent=opponent and(opponent==participant and player.Name or opponent.Name)or(watchMode and"AI vs AI"or"AI"),WorldName=world.Folder.Name,Ball=world.Ball,Home=home.Team.teamName,Away=away.Team.teamName,HomeSummary=homeSummary,AwaySummary=awaySummary,HomeLogo=home.Team.logo,AwayLogo=away.Team.logo,HomeColor=home.Team.colors.Primary,AwayColor=away.Team.colors.Primary,HomeTeamId=home.Team.teamId,AwayTeamId=away.Team.teamId,HomeLineup=home.StartingXI or{},AwayLineup=away.StartingXI or{},HomeBench=home.Bench or{},AwayBench=away.Bench or{},Duration=session.Remaining,Difficulty=finalSetup.Difficulty,ActivePlayer=activePlayer,TeamModels=teams,PitchCFrame=world.PitchCFrame,PitchWidth=world.Width,PitchLength=world.Length})end
	task.delay(PREMATCH_PRESENTATION_DURATION,function()if self.Sessions[player]==session and not session.PrematchSkipped and session.Phase=="PRE MATCH"then self:_startSetPiece(session,"Kickoff","Home",world.PitchCFrame.Position)end end)
	return true,opponent and"Ranked 1v1 match loaded."or(watchMode and"AI vs AI match loaded."or"Playable AI match loaded."),{Setup=finalSetup,Home=homeSummary,Away=awaySummary,WorldName=world.Folder.Name,Objective="PLAY YOUR FIRST MATCH",ObjectiveCompletedNow=not watchMode,WatchMode=watchMode}
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
		tween:Play()
		local finished=false
		local connection=tween.Completed:Connect(function()finished=true end)
		while model.Parent and not finished and not session.Ended and not session.PrematchSkipped do task.wait()end
		connection:Disconnect()
		tween:Cancel()
	end
	if session.Ended or session.PrematchSkipped then
		if animations then animations:ForceIdle(model)end
		return
	end
	if model.Parent then model:PivotTo(target)end
	if animations then animations:ForceIdle(model)end
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
	end)
end

function Service:_skipPrematch(session:any)
	if session.Ended or session.PrematchSkipped or session.Phase~="PRE MATCH"then return end
	session.PrematchSkipped=true
	session.PresentationActive=false
	self:_teleportPresentationStage(session,"Kickoff","KickoffReady")
	self:_destroyPresentationOfficials(session)
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
	self:_setPlayersFrozen(session,true)
	broadcast(self.State,session,self:_pausePayload(session,true,requester))
end

function Service:_resumePause(session:any)
	if not session.Paused then return end
	session.Paused=false
	session.PauseRequester=nil
	session.PauseResumeVotes={}
	self:_setPlayersFrozen(session,not session.Running)
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
	if kind~="Kickoff"then session.Clock:Record(kind)end
	session.Running=false;session.Phase=kind;session.Possession:Reset();session.TeamControl.Receiving:Clear();session.AI:SetExternalPhase(kind)
	if kind=="Kickoff"then debugKickoff("start set piece","team",restartTeam,"running",session.Running,"phase",session.Phase)end
	self:_setPlayersFrozen(session,true)
	if session.Goalkeepers then session.Goalkeepers:Reset()end
	local watchMode=session.Setup and session.Setup.WatchMode==true
	local sideController=if watchMode then nil else session.SidePlayers and session.SidePlayers[restartTeam]
	local controller=sideController or session.Player
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
	session.SetPieces:Start(controller,kind,restartTeam,location,function()
		if session.Ended then return end
		if kind=="Kickoff"then debugKickoff("ready callback","team",restartTeam,"owner",session.Possession:GetOwner()and session.Possession:GetOwner().Name or"nil","ballSpeed",math.floor(session.World.Ball.AssemblyLinearVelocity.Magnitude*10)/10)end
		session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session);task.delay(.18,function()if not session.Ended and session.Running then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end end)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY"})
		if kind=="Kickoff"then debugKickoff("phase broadcast","phase",session.Phase,"running",session.Running,"externalPhaseCleared",true)end
	end,sideController~=nil,forcedTaker)
	if kind~="Kickoff" then
		task.delay(10,function()
			if session.Ended or session.Running or session.SetPieceAutoSeq~=setPieceAutoSeq then return end
			if session.Phase==kind then
				self:_autoReleaseSetPiece(session,controller)
			end
		end)
	end
	if kind=="Corner"and session.SetPieces.ActiveCorner then session.Animations:ForceIdle(session.SetPieces.ActiveCorner.Data.Taker)end
	if session.Setup and session.Setup.WatchMode==true or sideController==nil then
		if kind=="Penalty"then
			session.PendingAIPenalty={Player=controller,AttackingSide=restartTeam,At=os.clock()+2.35}
		elseif kind=="FreeKick"then
			task.delay(1.6,function()if not session.Ended and not session.Running and session.Phase=="FreeKick"then self:_releaseAIFieldRestart(session)end end)
		elseif kind=="GoalKick"then
			task.delay(1.2,function()if not session.Ended and not session.Running and session.Phase=="GoalKick"then self:_releaseGoalKickClearance(session,controller)end end)
		elseif kind=="ThrowIn"then
			task.delay(1.0,function()if not session.Ended and not session.Running and session.Phase=="ThrowIn"then self:_releaseAIThrowIn(session)end end)
		end
	end
	self:_setPlayersFrozen(session,true)
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
	local currentGoalVelocity=session.World.Ball.AssemblyLinearVelocity
	local entryGoalVelocity=session.World.Ball:GetAttribute("VTRGoalEntryVelocity")
	local goalVelocity=typeof(entryGoalVelocity)=="Vector3"and entryGoalVelocity.Magnitude>currentGoalVelocity.Magnitude and entryGoalVelocity or currentGoalVelocity
	local entryAngularVelocity=session.World.Ball:GetAttribute("VTRGoalEntryAngularVelocity")
	local goalAngularVelocity=typeof(entryAngularVelocity)=="Vector3"and entryAngularVelocity or session.World.Ball.AssemblyAngularVelocity
	local penaltyGoal=session.World.Ball:GetAttribute("VTRPenaltyShotActive")==true
	local goalPhysicsUntil=os.clock()+(penaltyGoal and 4.5 or 3.5)
	session.World.Ball:SetAttribute("VTRPostGoalPhysicsUntil",goalPhysicsUntil)
	session.World.Ball:SetAttribute("VTRGoalCalledAt",os.clock())
	session.World.Ball:SetAttribute("VTRPostGoalVelocity",goalVelocity)
	session.World.Ball:SetAttribute("VTRPostGoalAngularVelocity",goalAngularVelocity)
	BallCollisionService.ApplyScoredBall(session.World.Ball)
	session.World.Ball.Anchored=false
	session.World.Ball:SetNetworkOwner(nil)
	session.Running=false
	self:_setPlayersFrozen(session,true)
	session.World.Ball.Anchored=false
	session.World.Ball:SetNetworkOwner(nil)
	session.World.Ball.AssemblyLinearVelocity=goalVelocity
	session.World.Ball.AssemblyAngularVelocity=goalAngularVelocity
	if team=="Home"then session.World.HomeScore.Value+=1 else session.World.AwayScore.Value+=1 end
	local scorerModel=session.BallService:GetLastTouchPlayer()
	if scorerModel then session.Animations:PlayAction(scorerModel,"GoalCelebration")end
	local scorer=scorerModel and scorerModel:GetAttribute("DisplayName")or nil
	local ownGoal=scorerModel~=nil and scorerModel:GetAttribute("VTRTeam")~=team
	session.Stats:Goal(team,scorerModel,ownGoal,clockPayloadForGoal.GameSeconds)
	local cornerTeam=session.World.Ball:GetAttribute("VTRLastCornerTeam");local cornerAt=tonumber(session.World.Ball:GetAttribute("VTRCornerTakenAt"))or 0;if cornerTeam==team and os.clock()-cornerAt<10 then session.Stats:Add(team,"CornerGoals");broadcast(self.State,session,{Type="CornerObjective",Event="cornerGoal"})end
	session.Clock:Record("Goal")
	session.Possession:Release(nil,0)
	session.World.Ball.AssemblyLinearVelocity=goalVelocity
	session.World.Ball.AssemblyAngularVelocity=goalAngularVelocity
	local clockPayload=clockPayloadForGoal;broadcast(self.State,session,{Type="Goal",Team=team,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,GameSeconds=clockPayload.GameSeconds,AddedMinutes=clockPayload.AddedMinutes,InAddedTime=clockPayload.InAddedTime,AddedElapsed=clockPayload.AddedElapsed,Scorer=scorer,ScorerModel=scorerModel,Penalty=penaltyGoal})
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
		if session.World and session.World.Ball then BallCollisionService.ApplyBall(session.World.Ball);session.World.Ball:SetAttribute("VTRPostGoalPhysicsUntil",nil);session.World.Ball:SetAttribute("VTRPostGoalVelocity",nil);session.World.Ball:SetAttribute("VTRPostGoalAngularVelocity",nil);session.World.Ball:SetAttribute("VTRGoalCalledAt",nil);session.World.Ball:SetAttribute("VTRGoalEntryVelocity",nil);session.World.Ball:SetAttribute("VTRGoalEntryAngularVelocity",nil)end
		if session.Ended then return end
		self:_markReplayRestartReady(session)
	end)
end

function Service:_halfTime(session:any)
	if session.HalfTimeTriggered or session.Ended then return end
	session.HalfTimeTriggered=true;session.Running=false;session.Phase="HALF TIME";session.Possession:Reset();self:_setPlayersFrozen(session,true)
	local gameSeconds=session.Clock:Payload().GameSeconds
	local payload=self:_pausePayload(session,true,nil)
	payload.Type="HalfTime";payload.HalfTime=true;payload.PauseRemaining=30;payload.Home=session.World.HomeScore.Value;payload.Away=session.World.AwayScore.Value;payload.Stats=session.Stats:Serialize(session.World.HomeScore.Value,session.World.AwayScore.Value,gameSeconds)
	session.HalfTimeBreak=true;session.HalfTimeBreakEndsAt=os.clock()+38;session.HalfTimeTimerAccumulator=0
	broadcast(self.State,session,payload)
	task.delay(38,function()if not session.Ended and session.HalfTimeBreak then self:_resumeHalfTime(session)end end)
end

function Service:_resumeHalfTime(session:any)
	if session.Ended or not session.HalfTimeBreak then return end
	session.HalfTimeBreak=false
	session.HalfTimeBreakEndsAt=nil
	broadcast(self.State,session,{Type="HalfTimeResume"})
	session.Clock:StartSecondHalf();if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end;if session.Referee and session.Referee.SetHalf then session.Referee:SetHalf(2)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end;if session.OutOfBounds and session.OutOfBounds.SetHalf then session.OutOfBounds:SetHalf(2)end;self:_startSetPiece(session,"Kickoff","Away",session.World.PitchCFrame.Position)
end

function Service:_penaltyTarget(session:any,shooter:Model,payload:any):(Vector3,string,number)
	local goalSign=tonumber(session.SetPieces and session.SetPieces.RestartGoalSign)or(tostring(shooter:GetAttribute("VTRTeam"))=="Home"and-1 or 1)
	local aim=typeof(payload.AimPosition)=="Vector3"and payload.AimPosition or session.World.Ball.Position
	local slot=PenaltyConfig.IsValidSlot(payload.PenaltySlot)and payload.PenaltySlot or PenaltyConfig.SlotFromGoalPoint(session.World.PitchCFrame,session.World.Length,goalSign,aim,session.World.Width)
	local target=PenaltyConfig.PointForSlot(session.World.PitchCFrame,session.World.Length,goalSign,slot,session.World.Width)
	local charge=math.clamp(tonumber(payload.Charge)or .55,0,1)
	shooter:SetAttribute("VTRPenaltySlot",slot)
	shooter:SetAttribute("VTRPenaltyMissHigh",false)
	return target,slot,charge
end

function Service:_setPenaltyKeeperGuess(session:any,defendingSide:string,slot:string?)
	local keeper=getGoalkeeper(session.Teams[defendingSide])
	if not keeper then return end
	local goalSign=tonumber(session.SetPieces and session.SetPieces.RestartGoalSign)or(defendingSide=="Home"and 1 or-1)
	local guess=PenaltyConfig.IsValidSlot(slot)and slot or PenaltyConfig.RandomSlot(Random.new())
	keeper:SetAttribute("VTRPenaltyGuessSlot",guess)
	keeper:SetAttribute("VTRPenaltyGuessPoint",PenaltyConfig.PointForSlot(session.World.PitchCFrame,session.World.Length,goalSign,guess,session.World.Width))
end

function Service:_releaseAIPenalty(session:any)
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
	session.World.Ball:SetNetworkOwner(nil)
	session.Possession:ForcePickup(taker)
	self:_setPieceRunup(session,taker,"Shot")
	session.World.Ball:SetAttribute("VTRPenaltyShotActive",true)
	session.BallService:Kick(taker,"Shot",target-takerRoot.Position,.62,nil,nil,nil,target)
	if setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
	session.PendingAIPenalty=nil
	session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=true})
end

function Service:_releaseAIFieldRestart(session:any)
	local setPieces=session.SetPieces
	local taker=setPieces and setPieces.RestartTaker
	local takerRoot=modelRoot(taker)
	if not taker or not takerRoot or not session.World or not session.World.Ball then return end
	session.World.Ball.Anchored=false
	session.World.Ball:SetNetworkOwner(nil)
	session.Possession:ForcePickup(taker)
	if session.BallService and session.BallService.Last then session.BallService.Last[taker]={}end
	local mode=setPieces.RestartMode
	local goalSign=tonumber(setPieces.RestartGoalSign)or(tostring(taker:GetAttribute("VTRTeam"))=="Home"and-1 or 1)
	local released=false
	if mode=="DirectShotFreeKick" then
		local goalPosition=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,goalSign*session.World.Length*.5))
		local freeKickDistance=Vector3.new(goalPosition.X-takerRoot.Position.X,0,goalPosition.Z-takerRoot.Position.Z).Magnitude
		if freeKickDistance<=190 then
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
	session.World.Ball:SetNetworkOwner(nil)
	session.Possession:ForcePickup(taker)
	local localTaker=session.World.PitchCFrame:PointToObjectSpace(takerRoot.Position)
	local goalSign=localTaker.Z>=0 and 1 or -1
	local lane=(tonumber(taker:GetAttribute("VTRIndex"))or 1)%3-1
	local target=session.World.PitchCFrame:PointToWorldSpace(Vector3.new(lane*session.World.Width*.16,3,0))
	local direction=target-takerRoot.Position
	if direction.Magnitude<1 then direction=session.World.PitchCFrame:VectorToWorldSpace(Vector3.new(0,0,-goalSign))end
	local distance=Vector3.new(direction.X,0,direction.Z).Magnitude
	session.BallService:Kick(taker,"Pass",direction,math.clamp(distance/360,.55,.92),nil,"Lofted",distance,target)
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
	session.World.Ball:SetNetworkOwner(nil)
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
		if session.Phase~="PRE MATCH"or session.PrematchSkipped then return end
		session.PrematchSkipVotes=session.PrematchSkipVotes or{}
		session.PrematchSkipVotes[player]=true
		if not session.Ranked then
			self:_skipPrematch(session)
			return
		end
		local ready=true
		for _,participant in session.Players do
			if not session.PrematchSkipVotes[participant]then ready=false;break end
		end
		broadcast(self.State,session,{Type="PrematchSkipQueued",PlayerName=player.Name,Ready=ready})
		if ready then self:_skipPrematch(session)end
		return
	end
	if payload.Type=="HalfTimeResume"then
		if session.HalfTimeBreak then self:_resumeHalfTime(session)end
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
				self.State:FireClient(player,{Type="ActivePlayer",Model=keeper,Name=keeper:GetAttribute("DisplayName"),Position=keeper:GetAttribute("position"),Reason="PenaltyDefense"})
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
	if not session.Running and not session.Paused and (session.Phase=="FreeKick"or session.Phase=="Penalty"or session.Phase=="GoalKick"or session.Phase=="ThrowIn") then
		local releaseAction=payload.Type=="Pass"or payload.Type=="Shot"or payload.Type=="Clearance"
		if releaseAction then
			local restartTeam=session.SetPieces and session.SetPieces.RestartTeam
			local playerSide=session.PlayerSides[player]or"Home"
			local penaltyKeeperAction=session.Phase=="Penalty" and payload.Type=="Shot" and restartTeam and playerSide~=restartTeam
			if restartTeam and playerSide~=restartTeam and not penaltyKeeperAction then
				self.State:FireClient(player,{Type="Info",Message="Opponent set piece. Waiting for their decision.",Important=true})
				return
			end
			if session.Phase=="FreeKick" and session.SetPieces and session.SetPieces.RestartMode=="LongFreeKick" and payload.Type~="Pass" then
				self.State:FireClient(player,{Type="Info",Message="Long free kick: choose a pass target.",Important=true})
				return
			end
			local before=session.BallService.MotionStarted
			local restartMode=session.SetPieces and session.SetPieces.RestartMode or nil
			local restartActive=session.TeamControl:GetActive(player)
			if session.Phase=="GoalKick"then
				self:_releaseGoalKickClearance(session,player)
				return
			end
			if session.Phase=="Penalty" and payload.Type=="Shot" and session.SetPieces and session.SetPieces.RestartTaker and restartActive~=session.SetPieces.RestartTaker then
				local defendingSide=session.PlayerSides[player]or"Home"
				local goalSign=tonumber(session.SetPieces.RestartGoalSign)or(defendingSide=="Home"and 1 or-1)
				local aim=typeof(payload.AimPosition)=="Vector3"and payload.AimPosition or session.World.Ball.Position
				local slot=PenaltyConfig.IsValidSlot(payload.PenaltySlot)and payload.PenaltySlot or PenaltyConfig.SlotFromGoalPoint(session.World.PitchCFrame,session.World.Length,goalSign,aim,session.World.Width)
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
				self:_setPenaltyKeeperGuess(session,defendingSide,nil)
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
			session.World.Ball:SetNetworkOwner(nil)
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
				session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session);task.delay(.18,function()if not session.Ended and session.Running then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end end)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=(restartMode=="DirectShotFreeKick"or restartMode=="Penalty") and payload.Type=="Shot"})
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
		for _,participant in session.Players do local state=session.PlayerState[participant];local active=session.TeamControl:GetActive(participant);if active and state then local sprinting=active:GetAttribute("VTRSprintLocked")~=true and(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0)>.1 and state.Stamina>=Config.Stamina.MinimumToSprint;activeOwners[active]=participant;sprintingByModel[active]=sprinting end end
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
		local currentHalf=session.Clock and session.Clock:Payload().Half or 1;if session.AI and session.AI.SetHalf then session.AI:SetHalf(currentHalf)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(currentHalf)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(currentHalf)end;if session.Stats and session.Stats.RecordPositions then session.Stats:RecordPositions(session.Models,dt)end;session.BallService:Step(dt);session.TeamControl:Step();session.Animations:Step(session.Possession:GetOwner());session.Grounding:Step();session.AI:Step(dt);session.Goalkeepers:Step(dt);session.Goals:Step();if session.Running then session.OutOfBounds:Step()end;RefereeService.Enforce(session.Models,session.World.PitchCFrame,session.World.Width,session.World.Length);if session.LinkDebug then session.LinkDebug:Step(session,dt)end
		if session.Clock:ShouldEndMatch()then self:EndMatch(session.StepOwner,true)elseif not session.HalfTimeTriggered and session.Clock:ShouldHalfTime()then self:_halfTime(session)elseif session.Accumulator>=.1 then session.Accumulator=0;local clockPayload=session.Clock:Payload();for _,participant in session.Players do local state=session.PlayerState[participant];self.State:FireClient(participant,{Type="Clock",GameSeconds=clockPayload.GameSeconds,Half=clockPayload.Half,AddedMinutes=clockPayload.AddedMinutes,InAddedTime=clockPayload.InAddedTime,AddedElapsed=clockPayload.AddedElapsed,Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,Stamina=state and state.Stamina or Config.Stamina.Maximum,Endurance=state and state.Endurance or Config.Stamina.Maximum})end
		end
	end
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

function Service:EndMatch(player:Player,showResult:boolean):boolean
	local session=self.Sessions[player]
	if not session then return false end
	for _,connection in session.Connections or{}do if connection and connection.Disconnect then connection:Disconnect()end end
	session.Ended=true;session.Running=false;if session.SetPieces then session.SetPieces:Cancel()end
	if showResult then
		local gameSeconds=session.Clock:Payload().GameSeconds
		local rewards=session.OnBeforeResult and session.OnBeforeResult(session)or{}
		local rankedPackChoices={
			{Name="Voltra Spark Pack",Rarity="Common"},
			{Name="Street Pulse Pack",Rarity="Rare"},
			{Name="Neon Tactics Pack",Rarity="Rare"},
			{Name="Elite Matchday Pack",Rarity="Epic"},
			{Name="Voltra Vault Pack",Rarity="Epic"},
			{Name="Ranked Champion Pack",Rarity="Mythic"},
			{Name="Icon Voltage Pack",Rarity="Mythic"},
		}
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
				if session.PrivateRankedMatch and session.ReturnPlaceId and session.ForfeitBy ~= participant.UserId then
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
					rewardPayload.PackName=rewardPayload.PackName or rewardPayload.Pack or"Ranked Champion Pack"
					rewardPayload.Rarity=rewardPayload.Rarity or"Mythic"
				end
				self.State:FireClient(participant,{Type="MatchEnded",Ranked=session.Ranked,LocalSide=side,Result=result,Forfeit=session.ForfeitBy~=nil,ForfeitReason=session.ForfeitReason,RankedLossUserId=session.RankedForceLossUserId,Home=homeScore,Away=awayScore,Stats=resultStats,Reward=rewardPayload,RankedWinPack=rankedWin and rewardPayload or nil})
			end
		end
		if session.OnRankedEnded then task.defer(session.OnRankedEnded,session)end
		if session.OnCompleted then task.defer(session.OnCompleted,session)end
		task.defer(function()
			for _,participant in session.Players or{player}do
				local character=participant.Character;local state=session.PlayerState and session.PlayerState[participant]
				if character then local accountRoot=character:FindFirstChild("HumanoidRootPart")::BasePart?;if accountRoot then accountRoot.Anchored=false end;character:SetAttribute("VTRParked",nil);character:SetAttribute("VTRCinematicParked",nil);character:SetAttribute("VTRSession",nil);character:SetAttribute("VTRSprinting",nil);character:PivotTo(state and state.ReturnCFrame or CFrame.new(0,8,0));local humanoid=character:FindFirstChildOfClass("Humanoid");if humanoid then humanoid.WalkSpeed=state and state.PreviousSpeed or 16;humanoid.JumpPower=state and state.PreviousJump or 50;humanoid.AutoRotate=true end end
				session.TeamControl:Destroy(participant);self.Sessions[participant]=nil;if participant.Parent==Players then participant:SetAttribute("VTRInMatch",false)end
			end
			if session.LinkDebug then session.LinkDebug:Destroy()end;if session.AI then session.AI:Destroy()end;if session.Animations then session.Animations:Destroy()end;if session.OfficialAnimations then session.OfficialAnimations:Destroy()end;if session.World and session.World.Folder and session.World.Folder.Parent then session.World.Folder:Destroy()end
		end)
		return true
	end
	for _,participant in session.Players or{player}do
		local character=participant.Character;local state=session.PlayerState and session.PlayerState[participant]
		if character then local accountRoot=character:FindFirstChild("HumanoidRootPart")::BasePart?;if accountRoot then accountRoot.Anchored=false end;character:SetAttribute("VTRParked",nil);character:SetAttribute("VTRCinematicParked",nil);character:SetAttribute("VTRSession",nil);character:SetAttribute("VTRSprinting",nil);character:PivotTo(state and state.ReturnCFrame or CFrame.new(0,8,0));local humanoid=character:FindFirstChildOfClass("Humanoid");if humanoid then humanoid.WalkSpeed=state and state.PreviousSpeed or 16;humanoid.JumpPower=state and state.PreviousJump or 50;humanoid.AutoRotate=true end end
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
	else
		self:EndMatch(player,false)
	end
end
return Service
