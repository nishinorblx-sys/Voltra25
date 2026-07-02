--!strict

local FormationPositionService = require(script.Parent.FormationPositionService)
local KickoffPositionService = require(script.Parent.KickoffPositionService)
local CornerPositioningService=require(script.Parent.CornerPositioningService)
local Workspace=game:GetService("Workspace")

local Service = {}
Service.__index = Service

local DURATIONS = {ThrowIn = 1.5, Corner = 2.0, GoalKick = 1.8, FreeKick=1.6, Penalty=2.0, Kickoff = 1.4}

local function root(model:Model):BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clearSpaceAround(models:any,center:Vector3,radius:number,pitchCFrame:CFrame,width:number,length:number,exceptModel:Model?)
	for _,team in models do
		for _,model in team do
			if model~=exceptModel then
				local modelRoot=root(model)
				if modelRoot then
					local offset=Vector3.new(modelRoot.Position.X-center.X,0,modelRoot.Position.Z-center.Z)
					if offset.Magnitude<radius then
						local direction=offset.Magnitude>.05 and offset.Unit or pitchCFrame.RightVector
						local desired=center+direction*radius
						local localPoint=pitchCFrame:PointToObjectSpace(desired)
						localPoint=Vector3.new(math.clamp(localPoint.X,-width*.5+3,width*.5-3),modelRoot.Position.Y,math.clamp(localPoint.Z,-length*.5+3,length*.5-3))
						local world=pitchCFrame:PointToWorldSpace(localPoint)
						model:PivotTo(CFrame.lookAt(world,Vector3.new(center.X,world.Y,center.Z)))
					end
				end
			end
		end
	end
end

local function stat(model:Model,key:string,primary:string?):number
	return tonumber(model:GetAttribute(key)) or (primary and tonumber(model:GetAttribute(primary))) or tonumber(model:GetAttribute("overall")) or 60
end

local function isKeeper(model:Model):boolean
	return tostring(model:GetAttribute("position") or "")=="GK"
end

local function chooseBest(team:{Model},statKey:string,fallbackKey:string?):Model
	local bestScore=-math.huge
	local tied={team[1]}
	for _,candidate in team do
		if not isKeeper(candidate) and candidate:GetAttribute("VTRSentOff")~=true then
			local score=stat(candidate,statKey,fallbackKey)
			if score>bestScore then
				bestScore=score
				tied={candidate}
			elseif score==bestScore then
				table.insert(tied,candidate)
			end
		end
	end
	return tied[math.random(1,math.max(1,#tied))] or team[1]
end

local function face(model:Model,position:Vector3,target:Vector3)
	local modelRoot=root(model)
	if not modelRoot then return end
	model:PivotTo(CFrame.lookAt(Vector3.new(position.X,modelRoot.Position.Y,position.Z),Vector3.new(target.X,modelRoot.Position.Y,target.Z)))
	modelRoot.AssemblyLinearVelocity=Vector3.zero
	modelRoot.AssemblyAngularVelocity=Vector3.zero
	local humanoid=model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero,false)end
end

local function localWorld(pitchCFrame:CFrame,x:number,y:number,z:number):Vector3
	return pitchCFrame:PointToWorldSpace(Vector3.new(x,y,z))
end

local function markerPart(names:{string}):BasePart?
	for _,name in names do
		local found=Workspace:FindFirstChild(name,true)
		if found and found:IsA("BasePart")then return found end
	end
	return nil
end

local function debugEnabled(): boolean
	return Workspace:GetAttribute("VTRKickoffDebug") ~= false
end

local function debugKickoff(message: string, ...: any)
	if debugEnabled() then
		print("[VTR KICKOFF][SetPiece] " .. message, ...)
	end
end

local function penaltySpotFromMarker(goalSign:number,pitchCFrame:CFrame,length:number):Vector3
	local marker=goalSign==1 and markerPart({"HomePen","HomePenaltySpot","PenaltyHome"}) or markerPart({"AwayPen","AwayPenaltySpot","PenaltyAway"})
	if marker then
		return marker.Position
	end
	return pitchCFrame:PointToWorldSpace(Vector3.new(0,1.15,goalSign*(length*.5-12)))
end

local function penaltyBoxFromMarker(goalSign:number):BasePart?
	if goalSign==1 then
		return markerPart({"HomeBox","HomePenaltyBox","HomePenaltyArea","Home18Box"})
	end
	return markerPart({"AwayBox","AwayPenaltyBox","AwayPenaltyArea","Away18Box"})
end

local function setPieceGoalSign(team:string):number
	-- Home attacks the Away goal in half one. StadiumAnalyzer defines
	-- HomeGoal at +Z and AwayGoal at -Z, so Home set pieces target -Z.
	-- MatchRuntime passes Half to swap after halftime.
	return team=="Home" and -1 or 1
end

local function arrangePenalty(teams:any,restartTeam:string,spot:Vector3,pitchCFrame:CFrame,width:number,length:number,taker:Model,half:number?,boxPart:BasePart?)
	local goalSign=setPieceGoalSign(restartTeam)
	if (half or 1)>=2 then goalSign=-goalSign end
	local defending=restartTeam=="Home"and"Away"or"Home"
	local goalCenter=localWorld(pitchCFrame,0,3,goalSign*length*.5)
	local toGoal=Vector3.new(goalCenter.X-spot.X,0,goalCenter.Z-spot.Z)
	local behind=toGoal.Magnitude>.05 and-toGoal.Unit or-pitchCFrame.LookVector*goalSign
	local approach=spot+behind*7.2
	face(taker,approach,goalCenter)
	taker:SetAttribute("VTRForceIdle",true)
	for _,side in {"Home","Away"}do
		for index,model in teams[side]do
			if model~=taker then
				if side==defending and isKeeper(model)then
					local keeperSpot=localWorld(pitchCFrame,0,3,goalSign*(length*.5-2.2))
					face(model,keeperSpot,spot)
					model:SetAttribute("VTRForceIdle",true)
				else
					-- Penalty setup: everyone except taker and goalkeeper waits outside
					-- the penalty area, spread across the edge of the box. They should
					-- not shuffle or run in place until the kick is taken.
					local row=math.floor((index-1)/7)
					local column=((index-1)%7)-3
					local x=math.clamp(column*11,-width*.5+10,width*.5-10)
					local z=goalSign*(length*.5-67-row*7)
					if boxPart then
						local boxLocal=pitchCFrame:PointToObjectSpace(boxPart.Position)
						local boxWidth=math.max(boxPart.Size.X,boxPart.Size.Z)
						local boxDepth=math.min(boxPart.Size.X,boxPart.Size.Z)
						x=math.clamp(boxLocal.X+column*math.max(9,boxWidth/6),-width*.5+10,width*.5-10)
						z=boxLocal.Z-goalSign*(boxDepth*.5+7+row*7)
					end
					face(model,localWorld(pitchCFrame,x,3,z),spot)
					model:SetAttribute("VTRForceIdle",true)
				end
			end
		end
	end
	return spot,goalSign
end

local function arrangeFreeKick(teams:any,restartTeam:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,taker:Model,half:number?)
	local localBall=pitchCFrame:PointToObjectSpace(location)
	local goalSign=setPieceGoalSign(restartTeam)
	if (half or 1)>=2 then goalSign=-goalSign end
	local goal=localWorld(pitchCFrame,0,3,goalSign*length*.5)
	local approach=location-Vector3.new(goal.X-location.X,0,goal.Z-location.Z).Unit*4.2
	face(taker,approach,goal)
	local defending=restartTeam=="Home"and"Away"or"Home"
	local wallCenter=location+Vector3.new(goal.X-location.X,0,goal.Z-location.Z).Unit*55
	local right=pitchCFrame.RightVector
	local wallCount=0
	for _,model in teams[defending]do
		if not isKeeper(model) and wallCount<4 then
			wallCount+=1
			face(model,wallCenter+right*((wallCount-2.5)*4.2),location)
			model:SetAttribute("VTRSetPieceWall",true)
		end
	end
	local attackers=teams[restartTeam]
	for index,model in attackers do
		if model~=taker then
			if isKeeper(model) then
				local homeSpot=localWorld(pitchCFrame,0,3,-goalSign*(length*.5-8))
				face(model,homeSpot,location)
				model:SetAttribute("VTRForceIdle",true)
			else
				local x=((index%5)-2)*13
				local z=goalSign*(length*.5-34-(index%3)*6)
				if index==4 or index==5 then z=0 end
				face(model,localWorld(pitchCFrame,x,3,z),location)
			end
		end
	end
	for index,model in teams[defending]do
		if model:GetAttribute("VTRSetPieceWall")~=true and not isKeeper(model) then
			local x=((index%6)-2.5)*10
			local z=goalSign*(length*.5-23-(index%4)*7)
			face(model,localWorld(pitchCFrame,x,3,z),location)
		elseif isKeeper(model)then
			face(model,localWorld(pitchCFrame,0,3,goalSign*(length*.5-2)),location)
		end
	end
	return localWorld(pitchCFrame,0,1.15,localBall.Z),goalSign
end

local function arrangeSimpleFreeKick(teams:any,restartTeam:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,taker:Model,half:number?)
	local goalSign=setPieceGoalSign(restartTeam)
	if (half or 1)>=2 then goalSign=-goalSign end
	local goal=localWorld(pitchCFrame,0,3,goalSign*length*.5)
	local toGoal=Vector3.new(goal.X-location.X,0,goal.Z-location.Z)
	local goalDirection=toGoal.Magnitude>.05 and toGoal.Unit or pitchCFrame.LookVector*goalSign
	face(taker,location-goalDirection*4.2,goal)
	local defending=restartTeam=="Home"and"Away"or"Home"
	for _,side in {"Home","Away"}do
		for index,model in teams[side]do
			if model~=taker then
				local modelRoot=root(model)
				local sideSign=side==restartTeam and -goalSign or goalSign
				local lane=((index%7)-3)*9
				local depth=side==restartTeam and 34+(index%3)*9 or 48+(index%4)*8
				local desired=localWorld(pitchCFrame,lane,3,math.clamp((pitchCFrame:PointToObjectSpace(location).Z)+sideSign*depth,-length*.5+18,length*.5-18))
				if modelRoot and (Vector3.new(modelRoot.Position.X-location.X,0,modelRoot.Position.Z-location.Z)).Magnitude<58 then
					face(model,desired,location)
				else
					face(model,modelRoot and modelRoot.Position or desired,location)
				end
				model:SetAttribute("VTRSetPieceWall",nil)
			end
		end
	end
	for _,model in teams[defending]do
		if isKeeper(model)then face(model,localWorld(pitchCFrame,0,3,goalSign*(length*.5-2)),location)end
	end
	return goalSign
end

function Service.new(remote: RemoteEvent, world: any, teams: any, formation: any, possession: any, teamControl: any,ballService:any,isPaused:(() -> boolean)?)
	return setmetatable({Remote = remote, World = world, Teams = teams, Formation = formation, Possession = possession, TeamControl = teamControl,BallService=ballService, Sequence = 0,ActiveCorner=nil,RestartMode=nil,IsPaused=isPaused}, Service)
end

function Service:_delayActive(seconds:number,sequence:number,callback:() -> ())
	task.spawn(function()
		local remaining=math.max(0,seconds)
		while remaining>0 do
			if self.Sequence~=sequence or not self.World.Ball.Parent then return end
			local step=math.min(.1,remaining)
			task.wait(step)
			if not (self.IsPaused and self.IsPaused())then remaining-=step end
		end
		if self.Sequence==sequence and self.World.Ball.Parent then callback()end
	end)
end

local function cornerAttr(model:Model,key:string,fallback:number):number
	return tonumber(model:GetAttribute(key)) or fallback
end

local function cornerAerialScore(model:Model):number
	local overall=cornerAttr(model,"overall",60)
	local heading=tonumber(model:GetAttribute("HeadingAccuracy")) or tonumber(model:GetAttribute("Heading")) or tonumber(model:GetAttribute("Finishing")) or overall
	local jumping=tonumber(model:GetAttribute("Jumping")) or tonumber(model:GetAttribute("PHY")) or overall
	local strength=tonumber(model:GetAttribute("Strength")) or tonumber(model:GetAttribute("PHY")) or overall
	local height=tonumber(model:GetAttribute("Height")) or 70
	return overall*.18+heading*.36+jumping*.18+strength*.12+math.clamp(height-66,0,16)*1.2
end

local function nearestCornerDefenderDistance(data:any,teams:any,receiver:Model):number
	local receiverRoot=root(receiver)
	if not receiverRoot then return 0 end
	local best=math.huge
	for _,defender in teams[data.DefendingTeam] or {} do
		if not isKeeper(defender) and defender:GetAttribute("VTRSentOff")~=true then
			local defenderRoot=root(defender)
			if defenderRoot then
				best=math.min(best,(Vector3.new(defenderRoot.Position.X-receiverRoot.Position.X,0,defenderRoot.Position.Z-receiverRoot.Position.Z)).Magnitude)
			end
		end
	end
	return best
end

local function cornerLanding(data:any,receiver:Model,role:string): (Vector3,string,number)
	local goalSign=tonumber(data.GoalSign)or 1
	local cornerSign=tonumber(data.CornerSign)or 1
	local length=tonumber(data.Length)or 704
	local x=0
	local z=goalSign*(length*.5-18)
	local delivery="Cross"
	local power=.64
	if role=="NearPost" then
		x=cornerSign*5
		z=goalSign*(length*.5-8)
		delivery="Driven"
		power=.74
	elseif role=="FarPost" then
		x=-cornerSign*11
		z=goalSign*(length*.5-11)
		delivery="Lob"
		power=.7
	elseif role=="PenaltySpot" then
		x=0
		z=goalSign*(length*.5-18)
		delivery="Cross"
		power=.66
	else
		x=-cornerSign*4
		z=goalSign*(length*.5-25)
		delivery="Cross"
		power=.62
	end
	local planned=data.PitchCFrame:PointToWorldSpace(Vector3.new(x,.15,z))
	local receiverRoot=root(receiver)
	if receiverRoot then
		local velocity=Vector3.new(receiverRoot.AssemblyLinearVelocity.X,0,receiverRoot.AssemblyLinearVelocity.Z)
		local lead=velocity.Magnitude>1.5 and velocity.Unit*math.clamp(velocity.Magnitude*.28,3,12) or Vector3.zero
		planned=planned:Lerp(receiverRoot.Position+lead,.32)
	end
	return planned,delivery,power
end

local function cornerDeliveryPlan(data:any,teams:any,restartTeam:string): any
	local best:Model?=nil
	local bestScore=-math.huge
	local bestRole="PenaltySpot"
	for _,candidate in teams[restartTeam] or {} do
		if candidate~=data.Taker and not isKeeper(candidate) and candidate:GetAttribute("VTRSentOff")~=true then
			local candidateRoot=root(candidate)
			if candidateRoot then
				local localPosition=data.PitchCFrame:PointToObjectSpace(candidateRoot.Position)
				local role=tostring(candidate:GetAttribute("VTRCornerRole") or "")
				local position=tostring(candidate:GetAttribute("position") or "")
				local inBox=math.abs(localPosition.X)<=data.Width*.42 and (tonumber(data.GoalSign)or 1)>0 and localPosition.Z>=data.Length*.5-125 or math.abs(localPosition.X)<=data.Width*.42 and localPosition.Z<=-data.Length*.5+125
				if inBox and role~="ShortOption" then
					local score=cornerAerialScore(candidate)
					score+=role=="NearPost" and 20 or role=="FarPost" and 20 or role=="PenaltySpot" and 16 or role=="Rebound" and 4 or 0
					score+=position=="ST" and 24 or position=="CB" and 22 or position=="CAM" and 12 or position=="CM" and 8 or 0
					score+=math.clamp(nearestCornerDefenderDistance(data,teams,candidate),0,22)*1.45
					score-=math.abs(localPosition.X)*.025
					if score>bestScore then
						best=candidate
						bestScore=score
						bestRole=role~="" and role or "PenaltySpot"
					end
				end
			end
		end
	end
	if best then
		local target,delivery,power=cornerLanding(data,best,bestRole)
		return{Receiver=best,Target=target,Delivery=delivery,Power=power,Role=bestRole}
	end
	local goalSign=tonumber(data.GoalSign)or 1
	return{Receiver=nil,Target=data.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,goalSign*((tonumber(data.Length)or 704)*.5-18))),Delivery="Cross",Power=.62,Role="PenaltySpot"}
end


function Service:_releaseCorner(player:Player,payload:any)
	local active=self.ActiveCorner;if not active or active.Player~=player then return false end
	if payload.ServerAI~=true and active.Player~=player then return false end
	local delivery=payload.Delivery;local allowed={Cross=true,Driven=true,Lob=true,Short=true};if not allowed[delivery]then return false end
	local power=math.clamp(tonumber(payload.Power)or 0,0,1);local target=payload.Target
	if typeof(target)~="Vector3"then return false end
	if delivery=="Short"then local shortRoot=active.Data.ShortOption and active.Data.ShortOption:FindFirstChild("HumanoidRootPart")::BasePart?;if shortRoot then target=shortRoot.Position end end
	local plannedReceiver:Model?=nil
	if delivery~="Short"then
		local requested=payload.Receiver
		local team=active.Data.Team or active.Data.RestartTeam or tostring(active.Data.Taker:GetAttribute("VTRTeam") or "Home")
		if typeof(requested)=="Instance" and requested:IsA("Model") and requested:GetAttribute("VTRTeam")==team and requested~=active.Data.Taker and not isKeeper(requested) then
			plannedReceiver=requested
			target=select(1,cornerLanding(active.Data,requested,tostring(requested:GetAttribute("VTRCornerRole") or "PenaltySpot")))
			delivery="Cross"
			power=math.clamp(power>.05 and power or .66,.45,.78)
			active.Data.CornerReceiver=plannedReceiver
			active.Data.CornerPlanRole=tostring(requested:GetAttribute("VTRCornerRole") or "PenaltySpot")
		else
			local plan=cornerDeliveryPlan(active.Data,self.Teams,team)
			plannedReceiver=plan.Receiver
			target=plan.Target
			delivery=plan.Delivery
			power=plan.Power
			active.Data.CornerReceiver=plannedReceiver
			active.Data.CornerPlanRole=plan.Role
		end
	end
	local takerRoot=active.Data.Taker:FindFirstChild("HumanoidRootPart")::BasePart?;if takerRoot then takerRoot.Anchored=false;takerRoot.AssemblyLinearVelocity=Vector3.zero;takerRoot.AssemblyAngularVelocity=Vector3.zero end
	active.Data.Taker:SetAttribute("VTRForceIdle",nil)
	self.World.Ball.Anchored=false;self.World.Ball:SetNetworkOwner(nil);self.Possession:ForcePickup(active.Data.Taker)
	local kicked=self.BallService:CornerKick(active.Data.Taker,target,delivery,power,delivery=="Short"and active.Data.ShortOption or plannedReceiver)
	if not kicked then self.World.Ball.Anchored=true;return false end
	CornerPositioningService.ActivateRuns(active.Data,target)
	self.ActiveCorner=nil;self.Remote:FireClient(player,{Type="CornerReleased",Delivery=delivery,Target=target})
	active.OnReady();return true
end

function Service:HandleAction(player:Player,payload:any):boolean
	if type(payload)=="table"and payload.Type=="CornerKick"then return self:_releaseCorner(player,payload)end
	return false
end

function Service:Start(player: Player, kind: string, restartTeam: string, location: Vector3, onReady: () -> (), userControlled:boolean?, forcedTaker:Model?)
	self.Sequence += 1
	local sequence = self.Sequence
	self.Possession:Reset()
	self.World.Ball.Anchored = true
	self.World.Ball.AssemblyLinearVelocity = Vector3.zero
	self.World.Ball.AssemblyAngularVelocity = Vector3.zero
	local taker: Model
	local kickoffPartner: Model? = nil
	local setPieceCutscene = false
	if kind == "ThrowIn" then
		taker = FormationPositionService.ThrowIn(self.Teams, restartTeam, location, self.World.PitchCFrame, self.World.Width, self.World.Length)
	elseif kind == "Corner" then
		local cornerData=CornerPositioningService.Position(self.Teams,restartTeam,location,self.World.PitchCFrame,self.World.Width,self.World.Length,self.World.Ball.Size.X*.5);cornerData.PitchCFrame=self.World.PitchCFrame;cornerData.Width=self.World.Width;cornerData.Length=self.World.Length;cornerData.Team=restartTeam;taker=cornerData.Taker;self.ActiveCorner={Player=player,Data=cornerData,OnReady=onReady,Sequence=sequence}
	elseif kind == "GoalKick" then
		taker = FormationPositionService.GoalKick(self.Teams, self.Formation, restartTeam, location, self.World.PitchCFrame, self.World.Width, self.World.Length)
	elseif kind=="Penalty"then
		local goalSign=setPieceGoalSign(restartTeam)
		if (self.Half or 1)>=2 then goalSign=-goalSign end
		local spot=penaltySpotFromMarker(goalSign,self.World.PitchCFrame,self.World.Length)
		taker=chooseBest(self.Teams[restartTeam],"Finishing","SHO")
		arrangePenalty(self.Teams,restartTeam,spot,self.World.PitchCFrame,self.World.Width,self.World.Length,taker,self.Half,penaltyBoxFromMarker(goalSign))
		location=spot
	elseif kind=="FreeKick"then
		taker=(forcedTaker and forcedTaker.Parent and forcedTaker:GetAttribute("VTRTeam")==restartTeam and not isKeeper(forcedTaker) and forcedTaker) or chooseBest(self.Teams[restartTeam],"FkAccuracy","PAS")
		local freeGoalSign=setPieceGoalSign(restartTeam)
		if (self.Half or 1)>=2 then freeGoalSign=-freeGoalSign end
		local goalPosition=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,freeGoalSign*self.World.Length*.5))
		setPieceCutscene=(Vector3.new(goalPosition.X-location.X,0,goalPosition.Z-location.Z)).Magnitude<=190
		if setPieceCutscene then
			arrangeFreeKick(self.Teams,restartTeam,location,self.World.PitchCFrame,self.World.Width,self.World.Length,taker,self.Half)
		else
			arrangeSimpleFreeKick(self.Teams,restartTeam,location,self.World.PitchCFrame,self.World.Width,self.World.Length,taker,self.Half)
		end
	else
		taker,kickoffPartner = KickoffPositionService.Position(self.Teams, self.Formation, self.World.PitchCFrame, restartTeam or "Home", self.Half)
		restartTeam = restartTeam or "Home"
	end
	local takerRoot = taker:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ballPosition = kind == "Corner"and self.ActiveCorner.Data.BallPosition or kind == "Kickoff" and self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0, 1.3, 0))or (kind=="FreeKick"or kind=="Penalty")and(location+self.World.PitchCFrame.UpVector*1.15)or takerRoot and (takerRoot.Position + takerRoot.CFrame.LookVector * 2.4 + Vector3.new(0, -1.6, 0)) or location
	self.World.Ball.CFrame = CFrame.new(ballPosition)
	if userControlled==true and player and player.Parent then self.TeamControl:SetActive(player, taker, kind)end
	if kind=="FreeKick"or kind=="Penalty"or kind=="GoalKick"or kind=="ThrowIn"then
		self.RestartMode = (kind=="GoalKick" or kind=="ThrowIn") and kind or kind=="FreeKick" and (setPieceCutscene and "DirectShotFreeKick" or "LongFreeKick") or kind
		self.RestartTaker=taker
		self.RestartTeam=restartTeam
		if kind~="GoalKick"and kind~="ThrowIn"then clearSpaceAround(self.Teams,ballPosition,kind=="Penalty"and 22 or self.RestartMode=="LongFreeKick" and 20 or 18,self.World.PitchCFrame,self.World.Width,self.World.Length,taker)end
		self.Possession:ForcePickup(taker)
		self.World.Ball.Anchored=true
		taker:SetAttribute("VTRForceIdle",true)
		taker:SetAttribute("VTRSetPieceTaker",true)
		taker:SetAttribute("VTRSetPieceKind",kind)
		self.World.Ball:SetAttribute("VTRSetPieceReady",kind)
	end
	local duration = DURATIONS[kind] or 1.6
	local payloadGoalSign=(kind=="FreeKick"or kind=="Penalty")and setPieceGoalSign(restartTeam)or nil
	if payloadGoalSign and (self.Half or 1)>=2 then payloadGoalSign=-payloadGoalSign end
	if kind=="Penalty"then
		self.RestartGoalSign=payloadGoalSign
		self.World.Ball:SetAttribute("VTRPenaltyGoalSign",payloadGoalSign)
	else
		self.RestartGoalSign=nil
		self.World.Ball:SetAttribute("VTRPenaltyGoalSign",nil)
	end
	local goalPosition=payloadGoalSign and self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,payloadGoalSign*self.World.Length*.5))or nil
	local displayKind=tostring(self.World.Ball:GetAttribute("VTRRestartDisplayKind") or kind)
	self.World.Ball:SetAttribute("VTRRestartDisplayKind",nil)
	self.Remote:FireClient(player, {Type = "SetPiece", Kind = displayKind, ActualKind = kind, Team = restartTeam, Location = ballPosition, Taker = taker, Duration = duration, GoalSign=payloadGoalSign, GoalPosition=goalPosition, Cutscene=kind=="Penalty"or(kind=="FreeKick"and setPieceCutscene), Mode=self.RestartMode, FouledPlayerName=tostring(taker:GetAttribute("DisplayName") or taker.Name)})
	if kind=="Corner"then
		local data=self.ActiveCorner.Data
		if userControlled==true and player and player.Parent then self.Remote:FireClient(player,{Type="CornerMode",Team=restartTeam,Taker=taker,Ball=self.World.Ball,Location=ballPosition,CornerSign=data.CornerSign,GoalSign=data.GoalSign,PitchCFrame=self.World.PitchCFrame,PitchWidth=self.World.Width,PitchLength=self.World.Length,TeamModels=self.Teams})
		else self:_delayActive(1.25,sequence,function()if self.ActiveCorner and self.ActiveCorner.Sequence==sequence then local target=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,data.GoalSign*(self.World.Length*.5-18)));self:_releaseCorner(player,{Delivery="Cross",Power=.65,Target=target,ServerAI=true})end end)end
		return
	end
	if kind=="FreeKick"or kind=="Penalty"or kind=="GoalKick"or kind=="ThrowIn"then
		return
	end
	self:_delayActive(duration,sequence,function()
		if self.Sequence ~= sequence or not self.World.Ball.Parent then
			return
		end
		self.World.Ball.Anchored = false
		self.World.Ball:SetNetworkOwner(nil)
		self.Possession:ForcePickup(taker)
		if kind=="FreeKick" and self.RestartMode=="LongFreeKick" and userControlled~=true then
			local takerRoot=root(taker)
			local best:Model?=nil;local bestScore=-math.huge
			if takerRoot then
				for _,teammate in self.Teams[restartTeam]or{}do
					if teammate~=taker and not isKeeper(teammate)then
						local teammateRoot=root(teammate)
						if teammateRoot then
							local distance=(teammateRoot.Position-takerRoot.Position).Magnitude
							if distance>10 and distance<85 then
								local score=(tonumber(teammate:GetAttribute("overall"))or 60)/100-math.abs(distance-38)/70
								if score>bestScore then bestScore=score;best=teammate end
							end
						end
					end
				end
			end
			local receiverRoot=best and root(best)
			if takerRoot and receiverRoot then
				local offset=receiverRoot.Position-takerRoot.Position
				self.BallService:Kick(taker,"Pass",offset,math.clamp(offset.Magnitude/85,.25,.68),best,"Lofted",offset.Magnitude,receiverRoot.Position)
			end
		end
		if kind=="Kickoff" and kickoffPartner and kickoffPartner.Parent then
			local takerRoot=root(taker)
			local partnerRoot=root(kickoffPartner)
			if takerRoot and partnerRoot then
				local offset=partnerRoot.Position-takerRoot.Position
				debugKickoff("auto pass attempt", "taker", taker.Name, "partner", kickoffPartner.Name, "distance", math.floor(offset.Magnitude*10)/10, "userControlled", userControlled==true)
				if offset.Magnitude>1 then
					local target=partnerRoot.Position+offset.Unit*2.4
					if self.BallService and self.BallService.Last then self.BallService.Last[taker]={}end
					kickoffPartner:SetAttribute("VTRForceIdle",nil)
					kickoffPartner:SetAttribute("VTRFrozenIdle",nil)
					local partnerHumanoid=kickoffPartner:FindFirstChildOfClass("Humanoid")
					if partnerHumanoid then
						partnerHumanoid.PlatformStand=false
						partnerHumanoid.Sit=false
						partnerHumanoid.AutoRotate=true
						partnerHumanoid:ChangeState(Enum.HumanoidStateType.Running)
					end
					if partnerRoot then partnerRoot.Anchored=false end
					local released=self.BallService:Kick(taker,"Pass",target-takerRoot.Position,.16,kickoffPartner,"Ground",offset.Magnitude,target)
					debugKickoff("auto pass result", "released", released, "owner", self.Possession:GetOwner() and self.Possession:GetOwner().Name or "nil", "ballSpeed", math.floor(self.World.Ball.AssemblyLinearVelocity.Magnitude*10)/10)
					if released then
						taker:SetAttribute("VTRNoAutoPassUntil",nil)
						kickoffPartner:SetAttribute("VTRNoAutoPassUntil",nil)
						kickoffPartner:SetAttribute("VTRKickoffReturnUntil",os.clock()+1.35)
						debugKickoff("receiver return window", kickoffPartner.Name, "until", kickoffPartner:GetAttribute("VTRKickoffReturnUntil"))
					end
				else
					debugKickoff("auto pass skipped; partner too close", "distance", math.floor(offset.Magnitude*10)/10)
				end
			else
				debugKickoff("auto pass skipped; missing roots", "takerRoot", takerRoot ~= nil, "partnerRoot", partnerRoot ~= nil)
			end
		end
		self:ReleaseRestartTaker()
		if kind=="Kickoff" then
			debugKickoff("release restart taker complete", "owner", self.Possession:GetOwner() and self.Possession:GetOwner().Name or "nil")
		end
		onReady()
		if kind=="Kickoff" and kickoffPartner and kickoffPartner.Parent and userControlled==true and player and player.Parent then
			task.defer(function()
				if kickoffPartner.Parent then
					self.TeamControl:SetActive(player,kickoffPartner,"KickoffReceiver")
				end
			end)
		end
	end)
end

function Service:Cancel()
	self.Sequence += 1
	if self.ActiveCorner and self.ActiveCorner.Data and self.ActiveCorner.Data.Taker then local taker=self.ActiveCorner.Data.Taker;taker:SetAttribute("VTRForceIdle",nil);local takerRoot=taker:FindFirstChild("HumanoidRootPart")::BasePart?;if takerRoot then takerRoot.Anchored=false end end
	self.ActiveCorner=nil
	self.RestartMode=nil
	self.RestartTaker=nil
	self.RestartTeam=nil
	self.RestartGoalSign=nil
	self.World.Ball:SetAttribute("VTRPenaltyGoalSign",nil)
end

function Service:ReleaseRestartTaker()
	for _,team in self.Teams do
		for _,model in team do
			local wasRestartSpecial=model:GetAttribute("VTRForceIdle")==true or model:GetAttribute("VTRSetPieceTaker")==true or model:GetAttribute("VTRSetPieceWall")==true
			if model:GetAttribute("VTRForceIdle")==true then
				model:SetAttribute("VTRForceIdle",nil)
			end
			if model:GetAttribute("VTRFrozenIdle")==true then
				model:SetAttribute("VTRFrozenIdle",nil)
			end
			if model:GetAttribute("VTRPresentationState")~=nil then
				model:SetAttribute("VTRPresentationState",nil)
			end
			if model:GetAttribute("VTRSetPieceTaker")==true then
				model:SetAttribute("VTRSetPieceTaker",nil)
			end
			if model:GetAttribute("VTRSetPieceKind")~=nil then
				model:SetAttribute("VTRSetPieceKind",nil)
			end
			if model:GetAttribute("VTRFreeKickCurve")~=nil then model:SetAttribute("VTRFreeKickCurve",nil)end
			if model:GetAttribute("VTRFreeKickLift")~=nil then model:SetAttribute("VTRFreeKickLift",nil)end
			if model:GetAttribute("VTRFreeKickTarget")~=nil then model:SetAttribute("VTRFreeKickTarget",nil)end
			if model:GetAttribute("VTRFreeKickFlightTime")~=nil then model:SetAttribute("VTRFreeKickFlightTime",nil)end
			if model:GetAttribute("VTRPenaltySlot")~=nil then model:SetAttribute("VTRPenaltySlot",nil)end
			if model:GetAttribute("VTRPenaltyMissHigh")~=nil then model:SetAttribute("VTRPenaltyMissHigh",nil)end
			if model:GetAttribute("VTRPenaltyUserKeeper")~=nil then model:SetAttribute("VTRPenaltyUserKeeper",nil)end
			if model:GetAttribute("VTRNoAutoPassUntil")~=nil then model:SetAttribute("VTRNoAutoPassUntil",nil)end
			if wasRestartSpecial then
				if model:GetAttribute("VTRReceiveTarget")~=nil then model:SetAttribute("VTRReceiveTarget",nil)end
				if model:GetAttribute("VTRPreparingReceive")~=nil then model:SetAttribute("VTRPreparingReceive",false)end
				if model:GetAttribute("VTRReceiveUntil")~=nil then model:SetAttribute("VTRReceiveUntil",nil)end
				if model:GetAttribute("VTRReceiveLockedAt")~=nil then model:SetAttribute("VTRReceiveLockedAt",nil)end
				if model:GetAttribute("VTRReceiveIntercept")~=nil then model:SetAttribute("VTRReceiveIntercept",nil)end
				if model:GetAttribute("AIDebugExpectedPass")~=nil then model:SetAttribute("AIDebugExpectedPass",nil)end
				if model:GetAttribute("AIDebugPassTarget")~=nil then model:SetAttribute("AIDebugPassTarget",nil)end
				if model:GetAttribute("AIDebugPassKind")~=nil then model:SetAttribute("AIDebugPassKind",nil)end
			end
			if model:GetAttribute("VTRSetPieceWall")==true then
				model:SetAttribute("VTRSetPieceWall",nil)
			end
			local humanoid=model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand=false
				humanoid.Sit=false
				humanoid.AutoRotate=true
				if humanoid.WalkSpeed<=0 then humanoid.WalkSpeed=16 end
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
			local modelRoot=root(model)
			if modelRoot then
				modelRoot.Anchored=false
				modelRoot.AssemblyLinearVelocity=Vector3.zero
				modelRoot.AssemblyAngularVelocity=Vector3.zero
			end
		end
	end
	self.World.Ball:SetAttribute("VTRSetPieceReady",nil)
	self.World.Ball:SetAttribute("VTRPenaltyGoalSign",nil)
	self.RestartMode=nil
	self.RestartTaker=nil
	self.RestartTeam=nil
	self.RestartGoalSign=nil
end

return Service
