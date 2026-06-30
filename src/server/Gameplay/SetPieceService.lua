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
			local x=((index%5)-2)*13
			local z=goalSign*(length*.5-34-(index%3)*6)
			if index==4 or index==5 then z=0 end
			face(model,localWorld(pitchCFrame,x,3,z),location)
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

function Service.new(remote: RemoteEvent, world: any, teams: any, formation: any, possession: any, teamControl: any,ballService:any)
	return setmetatable({Remote = remote, World = world, Teams = teams, Formation = formation, Possession = possession, TeamControl = teamControl,BallService=ballService, Sequence = 0,ActiveCorner=nil,RestartMode=nil}, Service)
end

function Service:_releaseCorner(player:Player,payload:any)
	local active=self.ActiveCorner;if not active or active.Player~=player then return false end
	if payload.ServerAI~=true and active.Player~=player then return false end
	local delivery=payload.Delivery;local allowed={Cross=true,Driven=true,Lob=true,Short=true};if not allowed[delivery]then return false end
	local power=math.clamp(tonumber(payload.Power)or 0,0,1);local target=payload.Target
	if typeof(target)~="Vector3"then return false end
	local localTarget=self.World.PitchCFrame:PointToObjectSpace(target)
	-- Keep the exact authored mouse point. Corner aiming intentionally has no
	-- penalty-box or pitch-edge clamp; the player can overhit a cross anywhere.
	target=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(localTarget.X,.15,localTarget.Z))
	if delivery=="Short"then local shortRoot=active.Data.ShortOption and active.Data.ShortOption:FindFirstChild("HumanoidRootPart")::BasePart?;if shortRoot then target=shortRoot.Position end end
	local takerRoot=active.Data.Taker:FindFirstChild("HumanoidRootPart")::BasePart?;if takerRoot then takerRoot.Anchored=false;takerRoot.AssemblyLinearVelocity=Vector3.zero;takerRoot.AssemblyAngularVelocity=Vector3.zero end
	active.Data.Taker:SetAttribute("VTRForceIdle",nil)
	self.World.Ball.Anchored=false;self.World.Ball:SetNetworkOwner(nil);self.Possession:ForcePickup(active.Data.Taker)
	local kicked=self.BallService:CornerKick(active.Data.Taker,target,delivery,power,delivery=="Short"and active.Data.ShortOption or nil)
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
		local cornerData=CornerPositioningService.Position(self.Teams,restartTeam,location,self.World.PitchCFrame,self.World.Width,self.World.Length,self.World.Ball.Size.X*.5);cornerData.PitchCFrame=self.World.PitchCFrame;taker=cornerData.Taker;self.ActiveCorner={Player=player,Data=cornerData,OnReady=onReady,Sequence=sequence}
	elseif kind == "GoalKick" then
		taker = FormationPositionService.GoalKick(self.Teams, restartTeam, location, self.World.PitchCFrame, self.World.Width, self.World.Length)
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
		setPieceCutscene=(Vector3.new(goalPosition.X-location.X,0,goalPosition.Z-location.Z)).Magnitude<=170
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
	self.Remote:FireClient(player, {Type = "SetPiece", Kind = kind, Team = restartTeam, Location = ballPosition, Taker = taker, Duration = duration, GoalSign=payloadGoalSign, GoalPosition=goalPosition, Cutscene=kind=="Penalty"or(kind=="FreeKick"and setPieceCutscene), Mode=self.RestartMode, FouledPlayerName=tostring(taker:GetAttribute("DisplayName") or taker.Name)})
	if kind=="Corner"then
		local data=self.ActiveCorner.Data
		if userControlled==true and player and player.Parent then self.Remote:FireClient(player,{Type="CornerMode",Team=restartTeam,Taker=taker,Ball=self.World.Ball,Location=ballPosition,CornerSign=data.CornerSign,GoalSign=data.GoalSign,PitchCFrame=self.World.PitchCFrame,PitchWidth=self.World.Width,PitchLength=self.World.Length})
		else task.delay(1.25,function()if self.ActiveCorner and self.ActiveCorner.Sequence==sequence then local target=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,data.GoalSign*(self.World.Length*.5-16)));self:_releaseCorner(player,{Delivery="Cross",Power=.55,Target=target,ServerAI=true})end end)end
		return
	end
	if kind=="FreeKick"or kind=="Penalty"or kind=="GoalKick"or kind=="ThrowIn"then
		return
	end
	task.delay(duration, function()
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
					if released then
						taker:SetAttribute("VTRNoAutoPassUntil",nil)
						kickoffPartner:SetAttribute("VTRNoAutoPassUntil",os.clock()+.18)
					end
				end
			end
		end
		self:ReleaseRestartTaker()
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
