--!strict
local VTRGoalPassThrough = require(script.Parent:WaitForChild("GoalShotPassThroughService"))
local function vtrXGPercent(value)
	local n = tonumber(value) or 0
	if n <= 1 then
		n = n * 100
	end
	if n < 0 then
		return 0
	end
	if n > 100 then
		return 100
	end
	return n
end

local function vtrXGIsGoal(threshold, rolled)
	return vtrXGPercent(rolled) <= vtrXGPercent(threshold)
end


local FormationPositionService = require(script.Parent.FormationPositionService)
local KickoffPositionService = require(script.Parent.KickoffPositionService)
local CornerPositioningService=require(script.Parent.CornerPositioningService)
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local GoalModelResolver=require(ReplicatedStorage.VTR.Shared.GoalModelResolver)

local Service = {}
Service.__index = Service

local DURATIONS = {ThrowIn = 0.15, Corner = 2.0, GoalKick = 1.8, FreeKick=1.6, Penalty=2.0, Kickoff = 1.4}

local function vtrClearSetPiecePreview(self, player)
	if self.Remote then
		self.Remote:FireAllClients({Type="ClearSetPiecePreview", Player=player})
	end
	if self.Event then
		self.Event:FireAllClients({Type="ClearSetPiecePreview", Player=player})
	end
	if self.ClientRemote then
		self.ClientRemote:FireAllClients({Type="ClearSetPiecePreview", Player=player})
	end
end

local function vtrGoalSideName(goalSide)
	local s=tostring(goalSide or "")
	if string.find(s,"Home") then
		return "Home"
	end
	if string.find(s,"Away") then
		return "Away"
	end
	return s
end

local function vtrFixHomeGoalLateral(goalSide, lateral)
	if vtrGoalSideName(goalSide)=="Home" then
		return -lateral
	end
	return lateral
end

local function root(model:Model):BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function primeSetPieceReceiver(taker: Model?, receiver: Model?, target: Vector3?, family: string?, launchDelay: number?, confidence: number?)
	if not taker or not receiver or typeof(target) ~= "Vector3" then return end
	local receiverRoot = root(receiver)
	local takerRoot = root(taker)
	if not receiverRoot or not takerRoot then return end
	local now = os.clock()
	local distance = Vector3.new(target.X - takerRoot.Position.X, 0, target.Z - takerRoot.Position.Z).Magnitude
	local airFamily = family == "Lofted" or family == "Cross" or family == "FarPostCross"
	local eta = airFamily and math.clamp(distance / 42, .45, 3.4) or math.clamp(distance / 56, .25, 2.8)
	local receiverEta = math.clamp(Vector3.new(target.X - receiverRoot.Position.X, 0, target.Z - receiverRoot.Position.Z).Magnitude / 25, .15, 2.8)
	local mode = airFamily and "SprintBurst" or receiverEta > eta + .18 and "SprintBurst" or receiverEta > eta - .08 and "Run" or "Jog"
	local expires = now + math.clamp(eta + 1.45, 1.25, 5.2)
	receiver:SetAttribute("VTRPrePassId", tostring(taker.Name) .. ":" .. tostring(receiver.Name) .. ":SetPiece:" .. tostring(math.floor(now * 100)))
	receiver:SetAttribute("VTRPrePassPhase", "Committed")
	receiver:SetAttribute("VTRPrePassPasser", taker.Name)
	receiver:SetAttribute("VTRPrePassTarget", target)
	receiver:SetAttribute("VTRPrePassFamily", family or "Ground")
	receiver:SetAttribute("VTRPrePassExpectedLaunchAt", now + (launchDelay or .12))
	receiver:SetAttribute("VTRPrePassExpectedBallETA", eta)
	receiver:SetAttribute("VTRPrePassReceiverETA", receiverEta)
	receiver:SetAttribute("VTRPrePassConfidence", confidence or .82)
	receiver:SetAttribute("VTRPrePassMovementMode", mode)
	receiver:SetAttribute("VTRPrePassExpiresAt", expires)
	receiver:SetAttribute("VTRPrePassFirstTouchIntent", family == "Cross" and "Finish" or "Secure")
	receiver:SetAttribute("VTRPrepareToReceive", true)
	receiver:SetAttribute("VTRPotentialReceiveTarget", target)
	receiver:SetAttribute("VTRPrepareReceiveUntil", expires)
	receiver:SetAttribute("VTRReceiveTarget", target)
	receiver:SetAttribute("VTRReceiveIntercept", target)
	receiver:SetAttribute("VTRReceiveUntil", expires)
	receiver:SetAttribute("VTRReceiveBallETA", eta)
	receiver:SetAttribute("VTRReceiveReceiverETA", receiverEta)
	receiver:SetAttribute("VTRReceiveOpponentETA", math.huge)
	receiver:SetAttribute("VTRReceiveRouteConfidence", confidence or .88)
	receiver:SetAttribute("VTRReceiveTrajectoryConfidence", airFamily and .86 or .74)
	receiver:SetAttribute("VTRReceiveRouteSprintRequested", true)
	receiver:SetAttribute("VTRReceiveLocomotionMode", mode)
	receiver:SetAttribute("VTRReceiveContactKind", airFamily and "Aerial" or "FrontFoot")
	receiver:SetAttribute("VTRFirstTouchIntent", family == "Cross" and "Finish" or "Secure")
	receiver:SetAttribute("VTRPreparingReceive", true)
	receiver:SetAttribute("VTRReceiveCommitted", true)
	receiver:SetAttribute("VTRReceiveLockedAt", now)
	receiver:SetAttribute("VTRReceiveHardLock", true)
	receiver:SetAttribute("VTRReceiveHardLockUntil", expires)
	receiver:SetAttribute("VTRForcedPassReceiver", true)
	receiver:SetAttribute("VTRForcedReceiveUntil", expires)
	receiver:SetAttribute("VTRAITargetedPass", receiver:GetAttribute("aiControlled") == true and receiver:GetAttribute("controlledByUser") ~= true)
	receiver:SetAttribute("VTRRunTicketId", nil)
	receiver:SetAttribute("VTRRunApproved", false)
	receiver:SetAttribute("VTRRunKind", nil)
	receiver:SetAttribute("VTRRunTrigger", nil)
	receiver:SetAttribute("VTRRunTarget", nil)
	receiver:SetAttribute("VTRRunExpiry", nil)
	receiver:SetAttribute("VTRSupportRun", nil)
	receiver:SetAttribute("VTRSupportKind", nil)
	receiver:SetAttribute("currentAssignment", "ReceivePass")
	receiver:SetAttribute("AIAssignment", "ReceivePass")
	receiver:SetAttribute("SupportRole", "ReceivePass")
	receiver:SetAttribute("AttackAssignment", "ReceivePass")
	receiver:SetAttribute("TeamPhase", "PassReception")
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
						local desired=center+direction*(radius+2.5)
						local localPoint=pitchCFrame:PointToObjectSpace(desired)
						local currentLocal=pitchCFrame:PointToObjectSpace(modelRoot.Position)
						local safeRootY=math.max(currentLocal.Y,2.8)
						localPoint=Vector3.new(math.clamp(localPoint.X,-width*.5+3,width*.5-3),safeRootY,math.clamp(localPoint.Z,-length*.5+3,length*.5-3))
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

local function closestKickoffPartner(team:{Model}?, taker:Model?):Model?
	local takerRoot=taker and root(taker)
	if not team or not takerRoot then return nil end
	local best:Model?=nil
	local bestDistance=math.huge
	for _,candidate in team do
		if candidate~=taker and candidate:GetAttribute("VTRSentOff")~=true and not isKeeper(candidate)then
			local candidateRoot=root(candidate)
			local humanoid=candidate:FindFirstChildOfClass("Humanoid")
			if candidateRoot and humanoid and humanoid.Health>0 then
				local distance=(Vector3.new(candidateRoot.Position.X,0,candidateRoot.Position.Z)-Vector3.new(takerRoot.Position.X,0,takerRoot.Position.Z)).Magnitude
				if distance<bestDistance then
					best=candidate
					bestDistance=distance
				end
			end
		end
	end
	return best
end

local function face(model:Model,position:Vector3,target:Vector3)
	local modelRoot=root(model)
	if not modelRoot then return end
	local placed = Vector3.new(position.X,modelRoot.Position.Y,position.Z)
	model:PivotTo(CFrame.lookAt(placed,Vector3.new(target.X,modelRoot.Position.Y,target.Z)))
	modelRoot.AssemblyLinearVelocity=Vector3.zero
	modelRoot.AssemblyAngularVelocity=Vector3.zero
	model:SetAttribute("VTRIntentionalRepositionUntil", os.clock() + 1.2)
	model:SetAttribute("targetPosition", placed)
	model:SetAttribute("MovementTarget", placed)
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
	return Workspace:GetAttribute("VTRKickoffDebug") == true and (RunService:IsStudio() or game.PrivateServerId ~= "")
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

local function penaltyKeeperSpot(goalSign:number,pitchCFrame:CFrame,width:number,length:number):Vector3
	local rectangle=GoalModelResolver.ResolveByAttackSign(goalSign,pitchCFrame,width,length)
	local goalHeight=rectangle.Top-rectangle.Bottom
	local goalCenter=pitchCFrame:PointToWorldSpace(Vector3.new(0,0,goalSign*length*.5))
	return Vector3.new(goalCenter.X,rectangle.PlanePoint.Y,goalCenter.Z)+rectangle.Up*(rectangle.Bottom+goalHeight*.08)-rectangle.Normal*1.35
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
					local keeperSpot=penaltyKeeperSpot(goalSign,pitchCFrame,width,length)
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

local freeKickTempAttributes = {
	"VTRFreeKickType",
	"VTRFreeKickRole",
	"VTRFreeKickMarker",
	"VTRFreeKickMarkedBy",
	"VTRFreeKickWallIndex",
	"VTRFreeKickWallSize",
	"VTRFreeKickRunDelay",
	"VTRSetPieceWall",
	"VTRWallJumpUntil",
	"VTRPrePassId",
	"VTRPrePassPhase",
	"VTRPrePassPasser",
	"VTRPrePassTarget",
	"VTRPrePassFamily",
	"VTRPrePassExpectedLaunchAt",
	"VTRPrePassExpectedBallETA",
	"VTRPrePassReceiverETA",
	"VTRPrePassConfidence",
	"VTRPrePassMovementMode",
	"VTRPrePassExpiresAt",
	"VTRPrePassFirstTouchIntent",
	"VTRPrepareToReceive",
	"VTRPotentialReceiveTarget",
	"VTRPrepareReceiveUntil",
}

local function freeKickRole(model:Model):string
	local role=tostring(model:GetAttribute("position")or"")
	if role=="LB"or role=="RB"or role=="LWB"or role=="RWB"then return"FB"end
	if role=="CB"then return"CB"end
	if role=="CDM"then return"CDM"end
	if role=="CM"or role=="CAM"then return"CM"end
	if role=="LW"or role=="RW"or role=="W"then return"W"end
	if role=="ST"or role=="CF"then return"ST"end
	if role=="GK"then return"GK"end
	return role
end

local function clearFreeKickTemp(model:Model)
	for _,attribute in freeKickTempAttributes do
		if model:GetAttribute(attribute)~=nil then model:SetAttribute(attribute,nil)end
	end
end

local setPieceReceiveAttributes = {
	"VTRReceiveTarget",
	"VTRPreparingReceive",
	"VTRReceiveUntil",
	"VTRReceiveLockedAt",
	"VTRReceiveIntercept",
	"VTRReceiveHardLock",
	"VTRReceiveHardLockUntil",
	"VTRForcedPassReceiver",
	"VTRForcedReceiveUntil",
	"VTRAITargetedPass",
	"VTRAIAlternatePassChaser",
	"VTRReceiveRouteSprintRequested",
	"VTRReceiveCommitted",
	"VTRReceiveBallETA",
	"VTRReceiveReceiverETA",
	"VTRReceiveOpponentETA",
	"VTRReceiveRouteConfidence",
	"VTRReceiveTrajectoryConfidence",
	"VTRReceiveLocomotionMode",
	"VTRReceiveContactKind",
	"VTRFirstTouchIntent",
	"AIDebugExpectedPass",
	"AIDebugPassTarget",
	"AIDebugPassKind",
}

local function clearSetPieceReceiveIntent(model: Model)
	for _, attribute in setPieceReceiveAttributes do
		if model:GetAttribute(attribute) ~= nil then
			model:SetAttribute(attribute, attribute == "VTRPreparingReceive" and false or nil)
		end
	end
end

local function aliveOutfield(team:{Model}?,exclude:Model?):{Model}
	local result={}
	for _,model in team or{}do
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		if model~=exclude and not isKeeper(model) and model:GetAttribute("VTRSentOff")~=true and (not humanoid or humanoid.Health>0)then table.insert(result,model)end
	end
	return result
end

local function chooseRole(candidates:{Model},used:{[Model]:boolean},score:(Model)->number):Model?
	local best:Model?=nil
	local bestScore=-math.huge
	for _,candidate in candidates do
		if not used[candidate]then
			local value=score(candidate)
			if value>bestScore then
				best=candidate
				bestScore=value
			end
		end
	end
	if best then used[best]=true end
	return best
end

local function roleBonus(model:Model,roles:{[string]:number}):number
	return roles[freeKickRole(model)]or 0
end

local function clampPitch(localPoint:Vector3,width:number,length:number):Vector3
	return Vector3.new(math.clamp(localPoint.X,-width*.5+8,width*.5-8),localPoint.Y,math.clamp(localPoint.Z,-length*.5+8,length*.5-8))
end

local function freeKickWorld(pitchCFrame:CFrame,width:number,length:number,x:number,z:number):Vector3
	local point=clampPitch(Vector3.new(x,3,z),width,length)
	return pitchCFrame:PointToWorldSpace(point)
end

local function freeKickLaneX(lane:string,width:number,ballX:number?):number
	local side=ballX and ballX>=0 and 1 or -1
	if lane=="LeftWing"then return -width*.36 end
	if lane=="LeftHalf"then return -width*.18 end
	if lane=="Center"then return 0 end
	if lane=="RightHalf"then return width*.18 end
	if lane=="RightWing"then return width*.36 end
	if lane=="NearPost"then return math.clamp(side*width*.13,-28,28)end
	if lane=="FarPost"then return math.clamp(-side*width*.18,-34,34)end
	return 0
end

local function placeFreeKick(model:Model?,position:Vector3,target:Vector3,occupied:{Vector3},minDistance:number,roleName:string?,pitchCFrame:CFrame,width:number,length:number)
	if not model then return end
	local localPoint=pitchCFrame:PointToObjectSpace(position)
	local adjusted=clampPitch(localPoint,width,length)
	local desired=pitchCFrame:PointToWorldSpace(adjusted)
	local right=pitchCFrame.RightVector
	local tries=0
	while tries<10 do
		local ok=true
		for _,point in occupied do
			if Vector3.new(desired.X-point.X,0,desired.Z-point.Z).Magnitude<minDistance then ok=false break end
		end
		if ok then break end
		tries+=1
		local step=math.ceil(tries*.5)*minDistance
		local sign=tries%2==0 and 1 or -1
		localPoint=pitchCFrame:PointToObjectSpace(desired+right*step*sign)
		desired=pitchCFrame:PointToWorldSpace(clampPitch(localPoint,width,length))
	end
	table.insert(occupied,desired)
	face(model,desired,target)
	if roleName then model:SetAttribute("VTRFreeKickRole",roleName)end
	model:SetAttribute("VTRForceIdle",true)
end

local function classifyFreeKick(restartTeam:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,half:number?):(string,number,number,number,number)
	local localBall=pitchCFrame:PointToObjectSpace(location)
	local goalSign=setPieceGoalSign(restartTeam)
	if (half or 1)>=2 then goalSign=-goalSign end
	local goalZ=goalSign*length*.5
	local ownZ=-goalSign*length*.5
	local distanceToGoal=math.abs(goalZ-localBall.Z)
	local distanceToOwn=math.abs(ownZ-localBall.Z)
	local lateral=math.abs(localBall.X)
	local angle=math.deg(math.atan2(lateral,math.max(distanceToGoal,1)))
	local direct=distanceToOwn>=170 and distanceToGoal>=46 and distanceToGoal<=195 and angle<=26 and lateral<=width*.3
	local kind=direct and"DirectShootingFreeKick"or"NormalPassingFreeKick"
	return kind,goalSign,distanceToGoal,angle,localBall.X
end

local function wallSizeFor(kind:string,distance:number,angle:number):number
	if kind~="DirectShootingFreeKick"then return 0 end
	if angle>22 then return angle>30 and 1 or 2 end
	if distance<92 and angle<16 then return 5 end
	if distance<145 and angle<20 then return 4 end
	if distance<190 and angle<24 then return 3 end
	return 2
end

local function limitedFreeKickPosition(model:Model?,desired:Vector3,maxMove:number,pitchCFrame:CFrame,width:number,length:number):Vector3
	local modelRoot=model and root(model)
	if not modelRoot then return desired end
	local current=modelRoot.Position
	local offset=Vector3.new(desired.X-current.X,0,desired.Z-current.Z)
	local moved=offset.Magnitude>maxMove and current+offset.Unit*maxMove or desired
	local localPoint=pitchCFrame:PointToObjectSpace(moved)
	return pitchCFrame:PointToWorldSpace(clampPitch(Vector3.new(localPoint.X,3,localPoint.Z),width,length))
end

local function arrangeNormalPassingFreeKick(teams:any,restartTeam:string,defending:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,taker:Model,goalSign:number,localBall:Vector3,goal:Vector3,attackers:{Model},defenders:{Model},attackUsed:{[Model]:boolean},defendUsed:{[Model]:boolean},occupied:{Vector3})
	local function localOf(model:Model):Vector3?
		local modelRoot=root(model)
		return modelRoot and pitchCFrame:PointToObjectSpace(modelRoot.Position) or nil
	end
	local function sameSideScore(model:Model):number
		local point=localOf(model)
		if not point then return -math.huge end
		local distance=Vector3.new(point.X-localBall.X,0,point.Z-localBall.Z).Magnitude
		return -math.abs(distance-28)+roleBonus(model,{CM=18,CDM=16,FB=12,W=8,ST=2})+stat(model,"PAS")*.08
	end
	local shortOption=chooseRole(attackers,attackUsed,sameSideScore)
	local resetOption=chooseRole(attackers,attackUsed,function(model)
		local point=localOf(model)
		if not point then return -math.huge end
		local behind=-goalSign*(point.Z-localBall.Z)
		return math.clamp(behind,-20,70)+roleBonus(model,{CB=22,CDM=18,FB=12,CM=8})+stat(model,"PAS")*.08-math.abs(point.X-localBall.X)*.08
	end)
	local forwardOption=chooseRole(attackers,attackUsed,function(model)
		local point=localOf(model)
		if not point then return -math.huge end
		local forward=goalSign*(point.Z-localBall.Z)
		return math.clamp(forward,-18,82)+roleBonus(model,{CM=16,CAM=16,W=15,ST=12,FB=5})+stat(model,"BallControl","DRI")*.08-math.abs(point.X-localBall.X)*.04
	end)
	local side=localBall.X>=0 and -1 or 1
	if shortOption then
		local desired=freeKickWorld(pitchCFrame,width,length,localBall.X+side*20,localBall.Z-goalSign*7)
		placeFreeKick(shortOption,limitedFreeKickPosition(shortOption,desired,25,pitchCFrame,width,length),location,occupied,8,"NormalShortOption",pitchCFrame,width,length)
		primeSetPieceReceiver(taker,shortOption,root(shortOption)and(root(shortOption)::BasePart).Position or desired,"Ground",.16,.86)
	end
	if resetOption then
		local point=localOf(resetOption) or localBall
		local desired=freeKickWorld(pitchCFrame,width,length,math.clamp(point.X,-width*.42,width*.42),math.min(math.max(localBall.Z-goalSign*24,point.Z-goalSign*10),point.Z+goalSign*10))
		placeFreeKick(resetOption,limitedFreeKickPosition(resetOption,desired,18,pitchCFrame,width,length),location,occupied,10,"NormalResetOption",pitchCFrame,width,length)
	end
	if forwardOption then
		local point=localOf(forwardOption) or localBall
		local laneX=math.clamp(point.X+side*8,-width*.42,width*.42)
		local desired=freeKickWorld(pitchCFrame,width,length,laneX,localBall.Z+goalSign*24)
		placeFreeKick(forwardOption,limitedFreeKickPosition(forwardOption,desired,20,pitchCFrame,width,length),location,occupied,10,"NormalForwardOption",pitchCFrame,width,length)
	end
	for _,model in attackers do
		if not attackUsed[model]then
			local role=freeKickRole(model)
			local maxMove=role=="CB"and 15 or role=="FB"and 18 or role=="W"and 16 or role=="ST"and 18 or 20
			local point=localOf(model)
			if point then
				local desired=point
				if role=="CB"and goalSign*(point.Z-localBall.Z)>-8 then desired=Vector3.new(point.X,3,localBall.Z-goalSign*18)
				elseif role=="FB"then desired=Vector3.new(math.clamp(point.X,-width*.44,width*.44),3,point.Z)
				elseif role=="CDM"then desired=Vector3.new(math.clamp(point.X,-32,32),3,math.min(math.max(point.Z,localBall.Z-goalSign*34),localBall.Z+goalSign*4))
				elseif role=="W"then desired=Vector3.new(math.clamp(point.X,-width*.44,width*.44),3,point.Z)
				elseif role=="ST"then desired=Vector3.new(math.clamp(point.X,-width*.18,width*.18),3,point.Z)
				end
				placeFreeKick(model,limitedFreeKickPosition(model,pitchCFrame:PointToWorldSpace(desired),maxMove,pitchCFrame,width,length),location,occupied,8,"NormalShapeHold",pitchCFrame,width,length)
			end
		end
	end
	local keeper=nil
	for _,model in teams[defending]or{}do if isKeeper(model)then keeper=model break end end
	if keeper then
		placeFreeKick(keeper,freeKickWorld(pitchCFrame,width,length,0,goalSign*(length*.5-2.6)),location,occupied,6,"Goalkeeper",pitchCFrame,width,length)
	end
	local presser=chooseRole(defenders,defendUsed,function(model)
		local modelRoot=root(model)
		return modelRoot and -Vector3.new(modelRoot.Position.X-location.X,0,modelRoot.Position.Z-location.Z).Magnitude+roleBonus(model,{ST=16,W=12,CM=6}) or -math.huge
	end)
	if presser then
		local directionToBall=root(presser) and (Vector3.new(location.X-root(presser).Position.X,0,location.Z-root(presser).Position.Z)) or Vector3.new(0,0,goalSign)
		local desired=location-(directionToBall.Magnitude>.05 and directionToBall.Unit or pitchCFrame.LookVector*goalSign)*18
		placeFreeKick(presser,limitedFreeKickPosition(presser,desired,18,pitchCFrame,width,length),location,occupied,9,"NormalFreeKickPresser",pitchCFrame,width,length)
	end
	local midfieldScreen=chooseRole(defenders,defendUsed,function(model)return roleBonus(model,{CDM=18,CM=14,W=6,FB=4})+stat(model,"DEF")*.12 end)
	if midfieldScreen then
		local point=localOf(midfieldScreen)
		local desired=point and pitchCFrame:PointToWorldSpace(Vector3.new(math.clamp(point.X,-width*.32,width*.32),3,point.Z))or location
		placeFreeKick(midfieldScreen,limitedFreeKickPosition(midfieldScreen,desired,16,pitchCFrame,width,length),location,occupied,10,"NormalCentralScreen",pitchCFrame,width,length)
	end
	for _,model in defenders do
		if not defendUsed[model]then
			local point=localOf(model)
			if point then
				local role=freeKickRole(model)
				local maxMove=role=="CB"and 10 or role=="FB"and 12 or role=="W"and 12 or 14
				local desired=point
				if role=="CB"then desired=Vector3.new(math.clamp(point.X,-32,32),3,point.Z)
				elseif role=="FB"then desired=Vector3.new(math.clamp(point.X,-width*.42,width*.42),3,point.Z)
				end
				placeFreeKick(model,limitedFreeKickPosition(model,pitchCFrame:PointToWorldSpace(desired),maxMove,pitchCFrame,width,length),location,occupied,8,"NormalDefensiveShape",pitchCFrame,width,length)
			end
		end
	end
	return shortOption
end

local function selectWall(defenders:{Model},used:{[Model]:boolean},location:Vector3,count:number):{Model}
	local chosen={}
	table.sort(defenders,function(a,b)
		local ar=root(a)
		local br=root(b)
		local ad=ar and Vector3.new(ar.Position.X-location.X,0,ar.Position.Z-location.Z).Magnitude or math.huge
		local bd=br and Vector3.new(br.Position.X-location.X,0,br.Position.Z-location.Z).Magnitude or math.huge
		local as=ad-roleBonus(a,{CM=16,CDM=14,W=6,FB=0,ST=-4,CB=-10})
		local bs=bd-roleBonus(b,{CM=16,CDM=14,W=6,FB=0,ST=-4,CB=-10})
		return as<bs
	end)
	for _,model in defenders do
		if #chosen>=count then break end
		if not used[model]then
			used[model]=true
			table.insert(chosen,model)
		end
	end
	return chosen
end

local function arrangeRoleFreeKick(teams:any,restartTeam:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,taker:Model,half:number?)
	local kind,goalSign,distanceToGoal,angle,lateral=classifyFreeKick(restartTeam,location,pitchCFrame,width,length,half)
	local defending=restartTeam=="Home"and"Away"or"Home"
	local goal=localWorld(pitchCFrame,0,3,goalSign*length*.5)
	local localBall=pitchCFrame:PointToObjectSpace(location)
	local toGoal=Vector3.new(goal.X-location.X,0,goal.Z-location.Z)
	local goalDirection=toGoal.Magnitude>.05 and toGoal.Unit or pitchCFrame.LookVector*goalSign
	local attackUsed={[taker]=true}
	local defendUsed={}
	local occupied={}
	for _,side in{"Home","Away"}do
		for _,model in teams[side]or{}do clearFreeKickTemp(model)end
	end
	placeFreeKick(taker,location-goalDirection*4.2,goal,occupied,5,"Taker",pitchCFrame,width,length)
	taker:SetAttribute("VTRSetPieceTaker",true)
	taker:SetAttribute("VTRFreeKickType",kind)
	local attackers=aliveOutfield(teams[restartTeam],taker)
	local defenders=aliveOutfield(teams[defending],nil)
	if kind=="NormalPassingFreeKick"then
		arrangeNormalPassingFreeKick(teams,restartTeam,defending,location,pitchCFrame,width,length,taker,goalSign,localBall,goal,attackers,defenders,attackUsed,defendUsed,occupied)
		for _,side in{"Home","Away"}do
			for _,model in teams[side]or{}do
				if model~=taker then model:SetAttribute("VTRFreeKickType",kind)end
			end
		end
		return kind,goalSign,0
	end
	local shortOption=chooseRole(attackers,attackUsed,function(model)return stat(model,"PAS")+stat(model,"BallControl","DRI")*.35+roleBonus(model,{CM=18,CDM=14,FB=10,W=6})end)
	local shortSide=lateral>=0 and -1 or 1
	local shortBehind=11
	if shortOption then
		local short=freeKickWorld(pitchCFrame,width,length,localBall.X+shortSide*14,localBall.Z-goalSign*shortBehind)
		placeFreeKick(shortOption,short,location,occupied,8,"ShortOption",pitchCFrame,width,length)
	end
	local wallCount=wallSizeFor(kind,distanceToGoal,angle)
	local wall=selectWall(defenders,defendUsed,location,wallCount)
	local wallDistance=math.clamp(distanceToGoal*.28,30,52)
	local wallCenter=location+goalDirection*wallDistance
	local wallRight=pitchCFrame.RightVector
	for index,model in wall do
		local offset=(index-(#wall+1)*.5)*4.6
		placeFreeKick(model,wallCenter+wallRight*offset,location,occupied,4.2,"Wall",pitchCFrame,width,length)
		model:SetAttribute("VTRSetPieceWall",true)
		model:SetAttribute("VTRFreeKickWallIndex",index)
		model:SetAttribute("VTRFreeKickWallSize",#wall)
	end
	local keeper=nil
	for _,model in teams[defending]or{}do if isKeeper(model)then keeper=model break end end
	if keeper then
		local wallSide=#wall>0 and (lateral>=0 and 1 or -1) or 0
		local wideAngle=angle>22
		local keeperX=wideAngle and math.clamp(localBall.X*.28,-10,10) or math.clamp(-wallSide*8-localBall.X*.08,-13,13)
		local keeperDepth=wideAngle and 6.8 or 2.4
		placeFreeKick(keeper,freeKickWorld(pitchCFrame,width,length,keeperX,goalSign*(length*.5-keeperDepth)),location,occupied,6,"Goalkeeper",pitchCFrame,width,length)
	end
	local function pickRunner(roleName:string,roles:{[string]:number},extra:(Model)->number):Model?
		return chooseRole(attackers,attackUsed,function(model)return roleBonus(model,roles)+extra(model)+stat(model,"Acceleration","PAC")*.15 end)
	end
	local nearRunner=pickRunner("NearPostRunner",{ST=12,W=10,CM=3},function(model)return stat(model,"Heading","PHY")*.35+stat(model,"Aggression","PHY")*.2 end)
	local centralRunner=pickRunner("CentralRunner",{ST=18,CB=10,W=4},function(model)return stat(model,"Heading","PHY")*.45+stat(model,"Strength","PHY")*.35+stat(model,"Height","PHY")*.2 end)
	local farRunner=pickRunner("FarPostRunner",{ST=12,W=10,CB=7},function(model)return stat(model,"Heading","PHY")*.45+stat(model,"AttackingPosition","SHO")*.25 end)
	local rebound=chooseRole(attackers,attackUsed,function(model)return roleBonus(model,{ST=10,CAM=9,CM=5,W=5})+stat(model,"Reactions")*.25+stat(model,"SHO")*.2 end)
	local edge=chooseRole(attackers,attackUsed,function(model)return roleBonus(model,{CM=14,CAM=12,CDM=8,W=6})+stat(model,"LongShots","SHO")*.3+stat(model,"PAS")*.2+stat(model,"BallControl","DRI")*.2 end)
	local stayBackA=chooseRole(attackers,attackUsed,function(model)return roleBonus(model,{CB=20,FB=15,CDM=14,CM=5})+stat(model,"DEF")*.45 end)
	local stayBackB=chooseRole(attackers,attackUsed,function(model)return roleBonus(model,{CB=20,FB=15,CDM=14,CM=5})+stat(model,"DEF")*.45 end)
	local stayBackC=chooseRole(attackers,attackUsed,function(model)return roleBonus(model,{CDM=16,CM=10,FB=7,CB=7})+stat(model,"DEF")*.25+stat(model,"PAS")*.15 end)
	local nearX=freeKickLaneX("NearPost",width,localBall.X)
	local farX=freeKickLaneX("FarPost",width,localBall.X)
	local edgeX=math.clamp(-nearX*.9,-30,30)
	local reboundX=math.clamp(nearX*.35,-12,12)
	if angle>22 then
		nearX=math.clamp(localBall.X*.45,-34,34)
		farX=-nearX
		edgeX=math.clamp(-nearX*.72,-32,32)
		reboundX=math.clamp(nearX*.45,-18,18)
	end
	local attackLineZ=goalSign*(length*.5-26)
	local centralZ=goalSign*(length*.5-36)
	local edgeZ=goalSign*(length*.5-64)
	if nearRunner then placeFreeKick(nearRunner,freeKickWorld(pitchCFrame,width,length,nearX,attackLineZ),location,occupied,9,"NearPostRunner",pitchCFrame,width,length);nearRunner:SetAttribute("VTRFreeKickRunDelay",0)end
	if centralRunner then placeFreeKick(centralRunner,freeKickWorld(pitchCFrame,width,length,0,centralZ),location,occupied,9,"CentralRunner",pitchCFrame,width,length);centralRunner:SetAttribute("VTRFreeKickRunDelay",.16)end
	if farRunner then placeFreeKick(farRunner,freeKickWorld(pitchCFrame,width,length,farX,attackLineZ+goalSign*5),location,occupied,9,"FarPostRunner",pitchCFrame,width,length);farRunner:SetAttribute("VTRFreeKickRunDelay",.32)end
	if rebound then placeFreeKick(rebound,freeKickWorld(pitchCFrame,width,length,reboundX,goalSign*(length*.5-48)),location,occupied,10,"PenaltySpotTarget",pitchCFrame,width,length)end
	if edge then placeFreeKick(edge,freeKickWorld(pitchCFrame,width,length,edgeX,edgeZ),location,occupied,12,"EdgeSecondBall",pitchCFrame,width,length)end
	local stayZ=math.clamp(localBall.Z-goalSign*42,-length*.5+24,length*.5-24)
	if stayBackA then placeFreeKick(stayBackA,freeKickWorld(pitchCFrame,width,length,-24,stayZ),location,occupied,12,"CounterProtection",pitchCFrame,width,length)end
	if stayBackB then placeFreeKick(stayBackB,freeKickWorld(pitchCFrame,width,length,24,stayZ-goalSign*5),location,occupied,12,"CounterProtection",pitchCFrame,width,length)end
	if stayBackC then placeFreeKick(stayBackC,freeKickWorld(pitchCFrame,width,length,0,stayZ-goalSign*13),location,occupied,12,"CounterProtection",pitchCFrame,width,length)end
	local supportLanes={"LeftWing","LeftHalf","Center","RightHalf","RightWing"}
	local supportIndex=0
	for _,model in attackers do
		if not attackUsed[model]then
			local role=freeKickRole(model)
			supportIndex+=1
			local laneName=supportLanes[((supportIndex-1)%#supportLanes)+1]
			local lane=role=="W"and(model:GetAttribute("position")=="LW"and freeKickLaneX("LeftWing",width)or freeKickLaneX("RightWing",width))or freeKickLaneX(laneName,width)
			local z=math.clamp(localBall.Z+goalSign*(role=="ST"and 58 or 34),-length*.5+30,length*.5-30)
			placeFreeKick(model,freeKickWorld(pitchCFrame,width,length,lane,z),location,occupied,9,"ConnectedSupport",pitchCFrame,width,length)
		end
	end
	local markerTargets={}
	local markerLimit=angle>22 and 2 or 1
	for _,model in {centralRunner,nearRunner,farRunner,rebound}do
		if model and #markerTargets<markerLimit then table.insert(markerTargets,model)end
	end
	for index,targetModel in markerTargets do
		local marker=chooseRole(defenders,defendUsed,function(model)return roleBonus(model,{CDM=14,CM=12,FB=8,CB=2,W=2})+stat(model,"DEF")*.35+stat(model,"PHY")*.15-index end)
		local targetRoot=targetModel and root(targetModel)
		if marker and targetRoot then
			local targetLocal=pitchCFrame:PointToObjectSpace(targetRoot.Position)
			placeFreeKick(marker,freeKickWorld(pitchCFrame,width,length,targetLocal.X,targetLocal.Z-goalSign*5),location,occupied,7,"Marker",pitchCFrame,width,length)
			marker:SetAttribute("VTRFreeKickMarker",targetModel.Name)
			targetModel:SetAttribute("VTRFreeKickMarkedBy",marker.Name)
		end
	end
	local nearPostDef=chooseRole(defenders,defendUsed,function(model)return roleBonus(model,{FB=15,CB=12,CDM=6})+stat(model,"DEF")*.25 end)
	local centerBackA=chooseRole(defenders,defendUsed,function(model)return roleBonus(model,{CB=20,CDM=8,FB=6})+stat(model,"DEF")*.35+stat(model,"PHY")*.2 end)
	local centerBackB=chooseRole(defenders,defendUsed,function(model)return roleBonus(model,{CB=20,CDM=8,FB=6})+stat(model,"DEF")*.35+stat(model,"PHY")*.2 end)
	local farPostDef=chooseRole(defenders,defendUsed,function(model)return roleBonus(model,{FB=15,CB=12,CDM=6})+stat(model,"DEF")*.25 end)
	local edgeDef=chooseRole(defenders,defendUsed,function(model)return roleBonus(model,{CDM=18,CM=13,FB=6})+stat(model,"DEF")*.25+stat(model,"PAS")*.08 end)
	local outlet=chooseRole(defenders,defendUsed,function(model)return roleBonus(model,{ST=18,W=13,CM=5})+stat(model,"PAC")*.25+stat(model,"PAS")*.08 end)
	if angle>22 then
		if nearPostDef then placeFreeKick(nearPostDef,freeKickWorld(pitchCFrame,width,length,nearX,goalSign*(length*.5-32)),location,occupied,8,"NearPostZone",pitchCFrame,width,length)end
		if centerBackA then placeFreeKick(centerBackA,freeKickWorld(pitchCFrame,width,length,-10,goalSign*(length*.5-48)),location,occupied,8,"CentralBoxDefender",pitchCFrame,width,length)end
		if centerBackB then placeFreeKick(centerBackB,freeKickWorld(pitchCFrame,width,length,10,goalSign*(length*.5-54)),location,occupied,8,"CentralBoxDefender",pitchCFrame,width,length)end
		if farPostDef then placeFreeKick(farPostDef,freeKickWorld(pitchCFrame,width,length,farX,goalSign*(length*.5-34)),location,occupied,8,"FarPostZone",pitchCFrame,width,length)end
	else
		if centerBackA then placeFreeKick(centerBackA,freeKickWorld(pitchCFrame,width,length,-10,goalSign*(length*.5-54)),location,occupied,8,"CentralBoxDefender",pitchCFrame,width,length)end
		if centerBackB then placeFreeKick(centerBackB,freeKickWorld(pitchCFrame,width,length,10,goalSign*(length*.5-58)),location,occupied,8,"CentralBoxDefender",pitchCFrame,width,length)end
		if nearPostDef then placeFreeKick(nearPostDef,freeKickWorld(pitchCFrame,width,length,freeKickLaneX("LeftHalf",width),goalSign*(length*.5-66)),location,occupied,10,"WideFreeKickDefender",pitchCFrame,width,length)end
		if farPostDef then placeFreeKick(farPostDef,freeKickWorld(pitchCFrame,width,length,freeKickLaneX("RightHalf",width),goalSign*(length*.5-70)),location,occupied,10,"WideFreeKickDefender",pitchCFrame,width,length)end
	end
	if edgeDef then placeFreeKick(edgeDef,freeKickWorld(pitchCFrame,width,length,localBall.X>=0 and -18 or 18,goalSign*(length*.5-92)),location,occupied,11,"DefensiveSecondBall",pitchCFrame,width,length)end
	if outlet then placeFreeKick(outlet,freeKickWorld(pitchCFrame,width,length,localBall.X>=0 and-width*.28 or width*.28,math.clamp(localBall.Z-goalSign*92,-length*.5+35,length*.5-35)),location,occupied,14,"CounterOutlet",pitchCFrame,width,length)end
	local defendLanes=localBall.X>=0 and {"LeftWing","LeftHalf","Center","RightHalf","RightWing"} or {"RightWing","RightHalf","Center","LeftHalf","LeftWing"}
	local defendIndex=0
	for _,model in defenders do
		if not defendUsed[model]then
			local role=freeKickRole(model)
			defendIndex+=1
			local laneName=defendLanes[((defendIndex-1)%#defendLanes)+1]
			local x=role=="FB"and(localBall.X>=0 and freeKickLaneX("LeftWing",width)or freeKickLaneX("RightWing",width))or freeKickLaneX(laneName,width)
			local depth=role=="ST"and 96 or (role=="CM"or role=="CDM")and 74 or 58
			local z=math.clamp(localBall.Z-goalSign*depth,-length*.5+28,length*.5-28)
			local freeRole=role=="ST"and"CounterOutlet"or role=="FB"and"WideFreeKickDefender"or(role=="CM"or role=="CDM")and"EdgeFreeKickScreen"or"CompactBlock"
			placeFreeKick(model,freeKickWorld(pitchCFrame,width,length,x,z),location,occupied,12,freeRole,pitchCFrame,width,length)
		end
	end
	if angle>22 and centralRunner then
		primeSetPieceReceiver(taker,centralRunner,root(centralRunner)and(root(centralRunner)::BasePart).Position or location,"Cross",.18,.86)
	elseif rebound then
		primeSetPieceReceiver(taker,rebound,root(rebound)and(root(rebound)::BasePart).Position or location,"Ground",.2,.74)
	elseif shortOption then
		primeSetPieceReceiver(taker,shortOption,root(shortOption)and(root(shortOption)::BasePart).Position or location,"Ground",.16,.72)
	end
	for _,side in{"Home","Away"}do
		for _,model in teams[side]or{}do
			if model~=taker then model:SetAttribute("VTRFreeKickType",kind)end
		end
	end
	return kind,goalSign,#wall
end

local function arrangeFreeKick(teams:any,restartTeam:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,taker:Model,half:number?)
	local kind,goalSign=arrangeRoleFreeKick(teams,restartTeam,location,pitchCFrame,width,length,taker,half)
	local localBall=pitchCFrame:PointToObjectSpace(location)
	return localWorld(pitchCFrame,0,1.15,localBall.Z),goalSign,kind
end

local function arrangeSimpleFreeKick(teams:any,restartTeam:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,taker:Model,half:number?)
	local _,goalSign=arrangeRoleFreeKick(teams,restartTeam,location,pitchCFrame,width,length,taker,half)
	return goalSign
end

function Service.DebugArrangeFreeKick(teams:any,restartTeam:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,taker:Model,half:number?)
	return arrangeRoleFreeKick(teams,restartTeam,location,pitchCFrame,width,length,taker,half)
end

function Service.DebugClearFreeKickTemp(model:Model)
	clearFreeKickTemp(model)
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

local function cornerPowerForTarget(data:any,target:Vector3,delivery:string):number
	local origin=typeof(data.BallPosition)=="Vector3" and data.BallPosition or data.PitchCFrame.Position
	local flat=Vector3.new(target.X-origin.X,0,target.Z-origin.Z)
	local distance=flat.Magnitude
	if delivery=="Driven"then
		return math.clamp((distance-72)/42,.34,.92)
	elseif delivery=="Lob"then
		return math.clamp((distance-48)/24,.48,.98)
	end
	return math.clamp((distance-58)/32,.42,.9)
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
			local receiverRoot=root(requested)
			if receiverRoot then
				local velocity=Vector3.new(receiverRoot.AssemblyLinearVelocity.X,0,receiverRoot.AssemblyLinearVelocity.Z)
				local lead=velocity.Magnitude>1.5 and velocity.Unit*math.clamp(velocity.Magnitude*.18,1.5,7) or Vector3.zero
				target=receiverRoot.Position+lead
			else
				target=select(1,cornerLanding(active.Data,requested,tostring(requested:GetAttribute("VTRCornerRole") or "PenaltySpot")))
			end
			delivery=delivery=="Driven" and "Driven" or "Lob"
			power=cornerPowerForTarget(active.Data,target,delivery)
			active.Data.CornerReceiver=plannedReceiver
			active.Data.CornerPlanRole=tostring(requested:GetAttribute("VTRCornerRole") or "PenaltySpot")
		else
			local plan=cornerDeliveryPlan(active.Data,self.Teams,team)
			plannedReceiver=plan.Receiver
			target=plan.Target
			delivery=plan.Delivery
			power=cornerPowerForTarget(active.Data,target,delivery)
			active.Data.CornerReceiver=plannedReceiver
			active.Data.CornerPlanRole=plan.Role
		end
	end
	local takerRoot=active.Data.Taker:FindFirstChild("HumanoidRootPart")::BasePart?;if takerRoot then takerRoot.Anchored=false;takerRoot.AssemblyLinearVelocity=Vector3.zero;takerRoot.AssemblyAngularVelocity=Vector3.zero end
	active.Data.Taker:SetAttribute("VTRForceIdle",nil)
	self.World.Ball.Anchored=false;pcall(function() self.World.Ball:SetNetworkOwner(nil) end);self.Possession:ForcePickup(active.Data.Taker)
	primeSetPieceReceiver(active.Data.Taker, delivery=="Short"and active.Data.ShortOption or plannedReceiver, target, delivery=="Short" and "Ground" or "Cross", .18, .86)
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
	if self.BallService then
		if self.BallService.StopForRestart then
			self.BallService:StopForRestart()
		end
		self.BallService.LastPassTeam=nil;self.BallService.LastPasser=nil;self.BallService.LastPassOrigin=nil;self.BallService.ExpectedReceiver=nil;self.BallService.PassPlan=nil;self.BallService.PassTargetPoint=nil;self.BallService.OffsideCandidate=nil;self.BallService.OffsideCandidates=nil;self.BallService.OffsidePasser=nil;self.BallService.OffsidePassStartedAt=nil
	end
	self.Possession:Reset()
	self.World.Ball.Anchored = true
	pcall(function() self.World.Ball:SetNetworkOwner(nil) end)
	self.World.Ball.AssemblyLinearVelocity = Vector3.zero
	self.World.Ball.AssemblyAngularVelocity = Vector3.zero
	local taker: Model
	local kickoffPartner: Model? = nil
	local setPieceCutscene = false
	local freeKickSetupType: string? = nil
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
		taker=(forcedTaker and forcedTaker.Parent and forcedTaker:GetAttribute("VTRTeam")==restartTeam and not isKeeper(forcedTaker) and forcedTaker) or chooseBest(self.Teams[restartTeam],"Finishing","SHO")
		arrangePenalty(self.Teams,restartTeam,spot,self.World.PitchCFrame,self.World.Width,self.World.Length,taker,self.Half,penaltyBoxFromMarker(goalSign))
		location=spot
	elseif kind=="FreeKick"then
		taker=(forcedTaker and forcedTaker.Parent and forcedTaker:GetAttribute("VTRTeam")==restartTeam and not isKeeper(forcedTaker) and forcedTaker) or chooseBest(self.Teams[restartTeam],"FkAccuracy","PAS")
		local freeGoalSign=setPieceGoalSign(restartTeam)
		if (self.Half or 1)>=2 then freeGoalSign=-freeGoalSign end
		local goalPosition=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,freeGoalSign*self.World.Length*.5))
		setPieceCutscene=(Vector3.new(goalPosition.X-location.X,0,goalPosition.Z-location.Z)).Magnitude<=200
		if setPieceCutscene then
			local _,_,setupType=arrangeFreeKick(self.Teams,restartTeam,location,self.World.PitchCFrame,self.World.Width,self.World.Length,taker,self.Half)
			freeKickSetupType=setupType
		else
			local setupType
			setupType=arrangeRoleFreeKick(self.Teams,restartTeam,location,self.World.PitchCFrame,self.World.Width,self.World.Length,taker,self.Half)
			freeKickSetupType=setupType
		end
		setPieceCutscene=freeKickSetupType=="DirectShootingFreeKick"
	else
		taker,kickoffPartner = KickoffPositionService.Position(self.Teams, self.Formation, self.World.PitchCFrame, restartTeam or "Home", self.Half)
		restartTeam = restartTeam or "Home"
	end
	local takerRoot = taker:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ballRadius=math.max(.35,self.World.Ball.Size.Y*.5)
	local restartLocal=self.World.PitchCFrame:PointToObjectSpace(location)
	local freeKickBallPosition=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(restartLocal.X,ballRadius,restartLocal.Z))
	local penaltyBallPosition=location+self.World.PitchCFrame.UpVector*1.15
	local ballPosition = kind == "Corner"and self.ActiveCorner.Data.BallPosition or kind == "Kickoff" and self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0, 1.3, 0))or kind=="FreeKick"and freeKickBallPosition or kind=="Penalty"and penaltyBallPosition or takerRoot and (takerRoot.Position + takerRoot.CFrame.LookVector * 2.4 + Vector3.new(0, -1.6, 0)) or location
	self.World.Ball.CFrame = CFrame.new(ballPosition)
	self.World.Ball.AssemblyLinearVelocity = Vector3.zero
	self.World.Ball.AssemblyAngularVelocity = Vector3.zero
	if userControlled==true and player and player.Parent then self.TeamControl:SetActive(player, taker, kind)end
	if kind=="FreeKick"or kind=="Penalty"or kind=="GoalKick"or kind=="ThrowIn"then
		self.RestartMode = (kind=="GoalKick" or kind=="ThrowIn") and kind or kind=="FreeKick" and (freeKickSetupType=="DirectShootingFreeKick" and "DirectShotFreeKick" or "LongFreeKick") or kind
		self.RestartTaker=taker
		self.RestartTeam=restartTeam
		if kind~="GoalKick"and kind~="ThrowIn"then clearSpaceAround(self.Teams,ballPosition,kind=="Penalty"and 22 or self.RestartMode=="LongFreeKick" and 20 or 18,self.World.PitchCFrame,self.World.Width,self.World.Length,taker)end
		self.Possession:ForcePickup(taker)
		self.World.Ball.Anchored=true
		if kind~="GoalKick" then taker:SetAttribute("VTRForceIdle",true)end
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
	self.Remote:FireClient(player, {Type = "SetPiece", Kind = displayKind, ActualKind = kind, Team = restartTeam, Location = ballPosition, Taker = taker, Duration = duration, GoalSign=payloadGoalSign, GoalPosition=goalPosition, Cutscene=kind=="Penalty"or(kind=="FreeKick"and setPieceCutscene), Mode=self.RestartMode, FouledPlayerName=tostring(taker:GetAttribute("DisplayName") or taker.Name), UserControlled=userControlled==true, WatchOnly=userControlled~=true})
	if kind=="Corner"then
		local data=self.ActiveCorner.Data
		if userControlled==true and player and player.Parent then self.Remote:FireClient(player,{Type="CornerMode",Team=restartTeam,Taker=taker,Ball=self.World.Ball,Location=ballPosition,CornerSign=data.CornerSign,GoalSign=data.GoalSign,PitchCFrame=self.World.PitchCFrame,PitchWidth=self.World.Width,PitchLength=self.World.Length,TeamModels=self.Teams})
		else self:_delayActive(1.25,sequence,function()if self.ActiveCorner and self.ActiveCorner.Sequence==sequence then local target=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,data.GoalSign*(self.World.Length*.5-18)));self:_releaseCorner(player,{Delivery="Cross",Power=.65,Target=target,ServerAI=true})end end)end
		return
	end
	if kind=="FreeKick"or kind=="Penalty"or kind=="GoalKick"or kind=="ThrowIn"then
		if (kind=="GoalKick" or kind=="ThrowIn") and userControlled~=true then
			local takerRoot = root(taker)
			local best: Model? = nil
			local bestDistance = math.huge
			if takerRoot then
				for _, teammate in self.Teams[restartTeam] or {} do
					if teammate ~= taker and teammate:GetAttribute("VTRSentOff") ~= true and not isKeeper(teammate) then
						local teammateRoot = root(teammate)
						if teammateRoot then
							local distance = (teammateRoot.Position - takerRoot.Position).Magnitude
							local role = tostring(teammate:GetAttribute("position") or "")
							local roleBonus = (role == "CB" or role == "LB" or role == "RB" or role == "CM" or role == "CDM") and -12 or 0
							if distance + roleBonus < bestDistance then
								best = teammate
								bestDistance = distance + roleBonus
							end
						end
					end
				end
			end
			local bestRoot = best and root(best)
			if takerRoot and bestRoot then
				local offset = bestRoot.Position - takerRoot.Position
				local direction = offset.Magnitude > .1 and offset.Unit or takerRoot.CFrame.LookVector
				local target = bestRoot.Position + direction * math.clamp(kind == "GoalKick" and 9 or 5, 4, 10)
				primeSetPieceReceiver(taker, best, target, kind == "GoalKick" and "Ground" or "ThrowIn", .25, .68)
			end
		end
		return
	end
	self:_delayActive(duration,sequence,function()
		if self.Sequence ~= sequence or not self.World.Ball.Parent then
			return
		end
		self.World.Ball.Anchored = false
		pcall(function() self.World.Ball:SetNetworkOwner(nil) end)
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
				primeSetPieceReceiver(taker,best,receiverRoot.Position,"Lofted",.14,.84)
				self.BallService:Kick(taker,"Pass",offset,math.clamp(offset.Magnitude/85,.25,.68),best,"Lofted",offset.Magnitude,receiverRoot.Position)
			end
		end
		if kind=="Kickoff" then
			kickoffPartner=closestKickoffPartner(self.Teams[restartTeam],taker) or kickoffPartner
		end
		if kind=="Kickoff" and kickoffPartner and kickoffPartner.Parent and self.OnboardingNoAutoKickoff~=true then
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
					primeSetPieceReceiver(taker,kickoffPartner,target,"Ground",.08,.9)
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
		if kind=="Kickoff" and kickoffPartner and kickoffPartner.Parent and self.OnboardingNoAutoKickoff~=true and userControlled==true and player and player.Parent then
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
	self:ReleaseRestartTaker()
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
			if model:GetAttribute("VTRFrozen")==true then
				model:SetAttribute("VTRFrozen",nil)
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
			clearFreeKickTemp(model)
			clearSetPieceReceiveIntent(model)
			if wasRestartSpecial then
				model:SetAttribute("VTRPostSetPieceReleasedAt", os.clock())
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
				model:SetAttribute("VTRIntentionalRepositionUntil", nil)
				for _,attribute in {"targetPosition","MovementTarget"} do
					if model:GetAttribute(attribute)~=nil then model:SetAttribute(attribute,nil) end
				end
				for _,attribute in {"currentAssignment","AIAssignment","SupportRole","AttackAssignment"} do
					local value=tostring(model:GetAttribute(attribute)or"")
					if value=="PostSetPieceRecover"or value=="SetPiece"or string.find(value,"FreeKick",1,true)or string.find(value,"Penalty",1,true)then
						model:SetAttribute(attribute,nil)
					end
				end
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
