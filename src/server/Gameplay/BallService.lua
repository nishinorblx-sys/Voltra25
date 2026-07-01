--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local Physics = require(ReplicatedStorage.VTR.Shared.BallPhysicsConfig)
local PassingPower = require(ReplicatedStorage.VTR.Shared.PassingPowerConfig)
local Scaling = require(ReplicatedStorage.VTR.Shared.StatScalingConfig)
local BallCurveService = require(script.Parent.BallCurveService)
local PassInterceptService = require(script.Parent.PassInterceptService)
local FreeKickTrajectory = require(ReplicatedStorage.VTR.Shared.FreeKickTrajectory)
local AIPassingDecisionService = require(script.Parent.AIPassingDecisionService)

local Service = {}
Service.__index = Service
local TARGETED_SHOT_GRAVITY=29.5
local ballisticVelocity: (Vector3, Vector3, number, number?) -> Vector3?

local function flat(vector: Vector3): Vector3
	local value = Vector3.new(vector.X, 0, vector.Z)
	return value.Magnitude > 0.01 and value.Unit or Vector3.zAxis
end

function Service.new(ball: BasePart, possession: any, remote: RemoteEvent, stats: any, models: {Model}, animations: any?)
	local raycast = RaycastParams.new()
	raycast.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: {Instance} = {ball}
	for _, model in models do
		table.insert(excluded, model)
	end
	raycast.FilterDescendantsInstances = excluded
	return setmetatable({Ball = ball, Possession = possession, Remote = remote, Stats = stats, Models = models, Animations=animations, Last = {}, Accumulator = 0, Raycast = raycast, Random = Random.new(), Curve = BallCurveService.new(ball), LastTouchPlayer = nil, LastTouchTeam = nil, MotionKind = "Loose", MotionStarted = 0}, Service)
end

function Service:_root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Service:_pressure(model:Model):number
	local modelRoot=self:_root(model);if not modelRoot then return 0 end
	local team=model:GetAttribute("VTRTeam");local pressure=0
	for _,opponent in self.Models do if opponent:GetAttribute("VTRTeam")~=team then local opponentRoot=self:_root(opponent);if opponentRoot then local distance=(opponentRoot.Position-modelRoot.Position).Magnitude;if distance<12 then pressure=math.max(pressure,1-distance/12)end end end end
	return pressure
end

function Service:_allowed(model: Model, action: string): boolean
	local now = os.clock()
	self.Last[model] = self.Last[model] or {}
	local cooldown = Config.Validation.ActionCooldowns[action] or 0.2
	if now - (self.Last[model][action] or 0) < cooldown then
		return false
	end
	self.Last[model][action] = now
	return true
end

function Service:_touch(model: Model)
	self.LastTouchPlayer = model
	self.LastTouchTeam = tostring(model:GetAttribute("VTRTeam") or "Home")
	self.Ball:SetAttribute("LastTouchTeam", self.LastTouchTeam)
	self.Ball:SetAttribute("LastTouchPlayer", model.Name)
end

function Service:GetLastTouchTeam(): string?
	return self.LastTouchTeam
end

function Service:GetLastTouchPlayer(): Model?
	return self.LastTouchPlayer
end

function Service:SetReferee(referee:any)self.Referee=referee end
function Service:SetOffsideService(service:any)self.Offside=service end

function Service:GoalkeeperSave(keeper: Model, savePoint: Vector3): boolean
	if self.MotionKind ~= "Shot" then return false end
	self.Curve:Stop()
	self.ShotPlan = nil
	self.PassPlan = nil
	self.PassTargetPoint = nil
	self.Ball:SetAttribute("VTRLobTarget", nil)
	self.Ball:SetAttribute("VTRLobPassActive", nil)
	self.Ball:SetAttribute("VTRPassTarget", nil)
	self.Ball:SetAttribute("VTRPassStartedAt", nil)
	self.Ball:SetAttribute("VTRPassTeam", nil)
	self.Ball:SetAttribute("VTRPassReceiver", nil)
	self.ExpectedReceiver = nil
	self.LastPassTeam = nil
	self.MotionKind = "Save"
	self.MotionStarted = os.clock()
	self.Ball:SetAttribute("VTRMotionKind", "Save")
	self:ReleaseGoalkeeperHold(keeper)
	keeper:SetAttribute("VTRGoalkeeperHolding",true)
	keeper:SetAttribute("VTRGoalkeeperHoldingSince",os.clock())
	self.Ball:SetAttribute("VTRGoalkeeperHeld",true)
	local keeperRoot = self:_root(keeper)
	local torso=keeper:FindFirstChild("Torso")::BasePart?
	local holdPosition=torso and(torso.Position+torso.CFrame.LookVector*1.05+Vector3.new(0,.18,0))or keeperRoot and(keeperRoot.Position+Vector3.new(0,.45,0))or savePoint
	self.Ball.CFrame = CFrame.new(holdPosition)
	self.Ball.AssemblyLinearVelocity = Vector3.zero
	self.Ball.AssemblyAngularVelocity = Vector3.zero
	self.Ball.CanCollide=false;self.Ball.CanTouch=false;self.Ball.Massless=true
	local catchPart=torso or keeperRoot
	if catchPart then local weld=Instance.new("WeldConstraint");weld.Name="VTRGoalkeeperCatchWeld";weld.Part0=self.Ball;weld.Part1=catchPart;weld.Parent=self.Ball end
	self:_touch(keeper)
	self.Possession:ForcePickup(keeper)
	self.Remote:FireAllClients({Type="GoalkeeperSave",Actor=keeper,SavePoint=savePoint})
	return true
end

function Service:CornerKick(model:Model,target:Vector3,delivery:string,power:number,receiver:Model?):boolean
	if self.Possession:GetOwner()~=model then return false end
	local origin=self.Ball.Position;local delta=target-origin;local horizontal=Vector3.new(delta.X,0,delta.Z);local distance=horizontal.Magnitude;if distance<2 then return false end
	power=math.clamp(power,0,1)
	if delivery=="Short"then return self:Kick(model,"Pass",delta,power,receiver,"Ground",distance)end
	if not self:_allowed(model,"Pass")then return false end
	-- Power changes arrival speed and arc, never the selected landing point.
	-- Solve one explicit flight time, then compensate the exact lateral curve
	-- displacement before launch so the curved ball still reaches the cursor.
	local speed=delivery=="Driven"and(72+power*42)or delivery=="Lob"and(48+power*24)or(58+power*32)
	local minimumTime=distance/math.max(Physics.MAX_BALL_SPEED*.88,1)
	local flightTime=math.max(minimumTime,math.clamp(distance/speed,delivery=="Driven"and .52 or .72,delivery=="Lob"and 2.75 or 2.15))
	local landing=Vector3.new(target.X,origin.Y,target.Z)
	local landingDelta=landing-origin
	local velocity=landingDelta/flightTime+Vector3.yAxis*(workspace.Gravity*flightTime*.5)
	local compensation=self.Curve:StartShot(model,landingDelta,flightTime);velocity+=compensation
	local cornerTeam=tostring(model:GetAttribute("VTRTeam")or"Home");self:_touch(model);self.MotionKind="Corner";self.MotionStarted=os.clock();self.Ball:SetAttribute("VTRMotionKind","Corner");self.Ball:SetAttribute("VTRLastCornerTeam",cornerTeam);self.Ball:SetAttribute("VTRCornerTakenAt",os.clock());self.Ball:SetAttribute("VTRCornerEnteredBox",false);self.Ball:SetAttribute("VTRPassTarget",target);self.Ball:SetAttribute("VTRPassTeam",cornerTeam);self.Ball:SetAttribute("VTRPassReceiver",receiver and receiver.Name or nil);self.Ball:SetAttribute("VTRPassStartedAt",os.clock())
	self.CornerPlan={Team=tostring(model:GetAttribute("VTRTeam")or"Home"),Target=target,Receiver=receiver,Started=os.clock(),Entered=false}
	if self.Animations then self.Animations:PlayAction(model,"Pass")end
	self.Stats:Add(self.CornerPlan.Team,"Corners");self.Possession:Release(velocity,.4);self.Remote:FireAllClients({Type="CornerKick",Actor=model,Delivery=delivery,Target=target,Power=power,ObjectiveEvent="cornerTaken"});return true
end

function Service:ReleaseGoalkeeperHold(keeper:Model?)
	local weld=self.Ball:FindFirstChild("VTRGoalkeeperCatchWeld")
	if weld then weld:Destroy()end
	self.Ball:SetAttribute("VTRGoalkeeperHeld",nil)
	self.Ball.CanCollide=true;self.Ball.CanTouch=true;self.Ball.Massless=false
	if keeper then keeper:SetAttribute("VTRGoalkeeperHolding",nil);keeper:SetAttribute("VTRGoalkeeperHoldingSince",nil)end
end

ballisticVelocity=function(origin:Vector3,target:Vector3,preferredSpeed:number,gravity:number?):Vector3?
	local delta=target-origin;local horizontal=Vector3.new(delta.X,0,delta.Z);local distance=horizontal.Magnitude
	if distance<.1 then return nil end
	gravity=gravity or workspace.Gravity;local height=delta.Y
	local minimumSpeed=math.sqrt(math.max(1,gravity*(height+math.sqrt(height*height+distance*distance))))
	local speed=math.clamp(math.max(preferredSpeed,minimumSpeed*1.015),40,Physics.MAX_BALL_SPEED)
	local speed2=speed*speed;local discriminant=speed2*speed2-gravity*(gravity*distance*distance+2*height*speed2)
	if discriminant<0 then return nil end
	local angle=math.atan((speed2-math.sqrt(discriminant))/(gravity*distance))
	return horizontal.Unit*(math.cos(angle)*speed)+Vector3.yAxis*(math.sin(angle)*speed)
end

local function distanceGoalChance(distance: number): number
	if distance <= 70 then
		return 1
	elseif distance <= 160 then
		return 1 - ((distance - 70) / 90) * 0.7
	elseif distance <= 190 then
		return 0.3 - ((distance - 160) / 30) * 0.29
	end
	return 0.01
end

function Service:_shotVelocity(model: Model, direction: Vector3, charge: number, targetPoint:Vector3?): Vector3
	local modelRoot = self:_root(model)
	local team = model:GetAttribute("VTRTeam")
	local pressure = self:_pressure(model)
	local shooting = math.clamp(tonumber(model:GetAttribute("SHO")) or 60, 1, 99)
	local finishing = math.clamp(tonumber(model:GetAttribute("Finishing")) or shooting, 1, 99)
	local composure = math.clamp(tonumber(model:GetAttribute("Composure")) or shooting, 1, 99)
	local weakFoot = math.clamp(tonumber(model:GetAttribute("WeakFoot")) or 3, 1, 5)
	local shotSpeed = (64 + (132 - 64) * charge) * (0.9 + shooting / 1000)
	if targetPoint then
		if model:GetAttribute("VTRSetPieceTaker")==true and tostring(model:GetAttribute("VTRSetPieceKind") or "")=="FreeKick" then
			local origin=self.Ball.Position
			local lift=math.clamp(tonumber(model:GetAttribute("VTRFreeKickLift")) or 0,-2.5,2.5)*0.5
			local curve=math.clamp(tonumber(model:GetAttribute("VTRFreeKickCurve")) or 0,-2.5,2.5)
			local solved=FreeKickTrajectory.Compute(origin,targetPoint,curve,lift)
			model:SetAttribute("VTRFreeKickTarget",targetPoint)
			model:SetAttribute("VTRFreeKickFlightTime",solved.FlightTime)
			return solved.BaseVelocity
		end
		local solved=ballisticVelocity(self.Ball.Position,targetPoint,shotSpeed,TARGETED_SHOT_GRAVITY)
		if solved then return solved end
	end
	local quality = math.clamp(0.42 + shooting / 420 + finishing / 520 + composure / 650 + weakFoot / 80 - pressure * 0.16 - (model:GetAttribute("VTRSprinting") == true and 0.055 or 0), 0.58, 0.985)
	local raw = direction.Magnitude > 0.1 and direction.Unit or Vector3.zAxis
	local horizontal = flat(raw)
	local powerRisk = math.max(0, charge - 0.72) * 0.055
	local angleError = (1 - quality) * 0.13 + pressure * 0.018 + powerRisk
	horizontal = CFrame.fromAxisAngle(Vector3.yAxis, self.Random:NextNumber(-angleError, angleError)):VectorToWorldSpace(horizontal)
	local chargedLift = (0.0125 + charge * 0.1275) * 0.5
	local targetLift = math.clamp(raw.Y, 0, 0.17) * 0.5
	local lift = math.max(chargedLift, targetLift * (0.36 + charge * 0.14))
	lift += self.Random:NextNumber(-1, 1) * (1 - quality) * (0.009 + charge * 0.0125) * 0.5
	lift = math.clamp(lift, 0.0045, 0.09)
	return (horizontal + Vector3.new(0, lift, 0)).Unit * shotSpeed
end

function Service:Kick(model: Model, kind: string, direction: Vector3, charge: number?, receiver: Model?, passType: string?, passDistance: number?, targetPoint:Vector3?): boolean
	if self.Possession:GetOwner() ~= model or not self:_allowed(model, kind) then
		return false
	end
	if model:GetAttribute("VTRGoalkeeperHolding")==true then self:ReleaseGoalkeeperHold(model)end
	local team = tostring(model:GetAttribute("VTRTeam") or "Home")
	local amount = math.clamp(charge or 0, 0, 1)
	local velocity: Vector3
	if kind == "Pass" then
		local passing = math.clamp(tonumber(model:GetAttribute("PAS")) or 60, 1, 99)
		local weakFoot = math.clamp(tonumber(model:GetAttribute("WeakFoot")) or 3, 1, 5)
		local balance = math.clamp(tonumber(model:GetAttribute("Balance")) or 65, 1, 99)
		local distance = math.clamp(passDistance or direction.Magnitude, 0, PassingPower.MaxPassDistance)
		local baseSpeed = PassInterceptService.RequiredInitialSpeed(distance, amount)
		local consistency = 0.94 + passing / 1650 + weakFoot / 500 + balance / 3300
		local variation = self.Random:NextNumber(-1, 1) * (1 - passing / 100) * 0.018
		local throughScale = passType == "Through" and 0.94 or 1
		local speedBias = passType == "BackPass" and 0.96 or passType == "Ground" and 1.12 or passType == "Through" and 1.1 or passType == "Lofted" and 1.06 or 1.08
		local finalSpeed = math.clamp(baseSpeed * consistency * (1 + variation) * throughScale * speedBias, 40, PassingPower.AbsoluteMaxSpeed)
		local modelRoot = self:_root(model)
		if passType=="Lofted"then
			local destination=targetPoint or(modelRoot and modelRoot.Position+direction)or(self.Ball.Position+direction)
			destination=Vector3.new(destination.X,self.Ball.Position.Y,destination.Z)
			local effectiveGravity=72;local preferredSpeed=52+amount*30+math.clamp(distance/10,0,18)
			velocity=ballisticVelocity(self.Ball.Position,destination,preferredSpeed,effectiveGravity)or(direction.Unit*finalSpeed+Vector3.yAxis*32)
			local horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z);local flightTime=distance/math.max(horizontalVelocity.Magnitude,1)
			velocity+=self.Curve:StartPass(model,destination-self.Ball.Position,horizontalVelocity.Magnitude,distance,true,flightTime)
			self.PassCurveStarted=true
			self.PendingCurve=nil;self.PassTargetPoint=destination;self.PassPlan={Target=destination,Distance=math.max(distance,1),InitialSpeed=horizontalVelocity.Magnitude,ArrivalRatio=1,Started=os.clock(),Lofted=true,EffectiveGravity=effectiveGravity,FlightTime=flightTime}
			self.Ball:SetAttribute("VTRLobTarget", destination)
			self.Ball:SetAttribute("VTRLobPassActive", true)
		else
			local passAmount=passType=="Through"and math.min(amount,.46)or amount
			local lift=PassingPower.LiftForDistance(distance,passAmount,false)
			local destination=targetPoint or(modelRoot and(modelRoot.Position+direction))or(self.Ball.Position+direction)
			local groundDirection=destination-self.Ball.Position
			velocity = (flat(groundDirection) + Vector3.new(0,lift,0)).Unit * finalSpeed
			local groundFlightTime=distance/math.max(finalSpeed,1)
			velocity+=self.Curve:StartPass(model,groundDirection,finalSpeed,distance,false,groundFlightTime)
			self.PassCurveStarted=true
			self.PendingCurve=nil
			self.PassTargetPoint=destination
			self.PassPlan=self.PassTargetPoint and{Target=self.PassTargetPoint,Distance=math.max(distance,1),InitialSpeed=finalSpeed,ArrivalRatio=PassingPower.ArrivalSpeedRatio(passAmount),Started=os.clock()}or nil
			if self.PassTargetPoint then self.Ball:SetAttribute("VTRPassTarget", self.PassTargetPoint) end
			self.Ball:SetAttribute("VTRLobTarget", nil)
			self.Ball:SetAttribute("VTRLobPassActive", nil)
		end
		if self.PassTargetPoint then self.Ball:SetAttribute("VTRPassTarget", self.PassTargetPoint) end
		self.Stats:RecordPassAttempt(model)
		self.LastPassTeam = team
		self.LastPasser=model
		self.LastPassOrigin=modelRoot and modelRoot.Position or self.Ball.Position
		self.ExpectedReceiver = receiver
		self.Ball:SetAttribute("VTRPassStartedAt", os.clock())
		self.Ball:SetAttribute("VTRPassTeam", team)
		self.Ball:SetAttribute("VTRPassReceiver", receiver and receiver.Name or nil)
		self.OffsideCandidate=receiver and self.Offside and self.Offside:IsOffside(model,receiver,self.Ball.Position)and receiver or nil
	elseif kind == "Shot" then
		self.Ball:SetAttribute("VTRPassStartedAt", nil)
		self.Ball:SetAttribute("VTRPassTeam", nil)
		self.Ball:SetAttribute("VTRPassReceiver", nil)
		local modelRoot=self:_root(model)
		if targetPoint and modelRoot then
			local facing=flat(modelRoot.CFrame.LookVector)
			local shotDir=flat(targetPoint-modelRoot.Position)
			local facingDot=facing.Magnitude>.05 and shotDir.Magnitude>.05 and math.clamp(facing.Unit:Dot(shotDir.Unit),-1,1)or 1
			if facingDot<.72 then amount*=math.clamp(.55+math.max(facingDot,0)*.55,.55,.95)end
		end
		velocity = self:_shotVelocity(model, direction, amount,targetPoint)
		if not targetPoint then velocity*=Physics.SHOT_MULTIPLIER end
		local penaltySlot=tostring(model:GetAttribute("VTRPenaltySlot")or"")
		self.ShotPlan=targetPoint and{Target=targetPoint,Started=os.clock(),EffectiveGravity=TARGETED_SHOT_GRAVITY,PenaltySlot=penaltySlot~=""and penaltySlot or nil,PenaltyMissHigh=model:GetAttribute("VTRPenaltyMissHigh")==true}or nil
		local horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z);local horizontalDistance=targetPoint and Vector3.new(targetPoint.X-self.Ball.Position.X,0,targetPoint.Z-self.Ball.Position.Z).Magnitude or 65;local flightTime=tonumber(model:GetAttribute("VTRFreeKickFlightTime")) or horizontalDistance/math.max(horizontalVelocity.Magnitude,1)
		velocity+=self.Curve:StartShot(model,direction,flightTime)
		local shotRoot=self:_root(model)
		local xg=self.Stats:CalculateXG(model,shotRoot and shotRoot.Position or self.Ball.Position,self:_pressure(model),nil)
		local shotDistance = 190
		if shotRoot and targetPoint then
			shotDistance = Vector3.new(shotRoot.Position.X - targetPoint.X, 0, shotRoot.Position.Z - targetPoint.Z).Magnitude
		elseif shotRoot then
			shotDistance = direction.Magnitude
		end
		local shotChance = distanceGoalChance(shotDistance)
		model:SetAttribute("VTRLastShotScoringChance",shotChance)
		model:SetAttribute("VTRLastShotScoringPercent",math.floor(shotChance*100+.5))
		model:SetAttribute("VTRShotDistanceStuds",shotDistance)
		self.LastShotChance=shotChance
		self.LastShotChancePercent=math.floor(shotChance*100+.5)
		self.LastShotXG=xg;self.LastShooter=model;self.Stats:RecordShot(model,targetPoint~=nil,xg)
	elseif kind == "Skill" then
		self.Ball:SetAttribute("VTRPassStartedAt", nil)
		self.Ball:SetAttribute("VTRPassTeam", nil)
		self.Ball:SetAttribute("VTRPassReceiver", nil)
		velocity = (flat(direction) + Vector3.new(0, 0.1, 0)).Unit * Config.Ball.SkillTouchSpeed
	else
		return false
	end
	if velocity.Magnitude > Physics.MAX_BALL_SPEED then
		velocity = velocity.Unit * Physics.MAX_BALL_SPEED
	end
	self:_touch(model)
	if self.Animations then self.Animations:PlayAction(model,kind=="Shot"and"Shoot"or kind)end
	self.MotionKind = kind
	self.MotionStarted = os.clock()
	self.Ball:SetAttribute("VTRMotionKind",kind)
	self.Possession:Release(velocity, kind == "Shot" and 0.55 or 0.25)
	if kind == "Pass" and self.PendingCurve then self.Curve:Start(self.PendingCurve.Model,self.PendingCurve.Direction,self.PendingCurve.Speed,self.PendingCurve.Distance);self.PendingCurve=nil elseif not (kind=="Pass" and self.PassCurveStarted==true) and (kind=="Pass"or kind~="Shot")then self.Curve:Stop()end;self.PassCurveStarted=nil
	local eventPayload={Type=kind,Actor=model,Receiver=receiver,Charge=amount}
	if kind=="Shot"then
		eventPayload.ScoringChance=self.LastShotChance
		eventPayload.ScoringChancePercent=self.LastShotChancePercent
		eventPayload.ShotXG=self.LastShotXG
	end
	self.Remote:FireAllClients(eventPayload)
	return true
end

function Service:SkillMove(model:Model,direction:Vector3):boolean
	if self.Possession:GetOwner()~=model or not self:_allowed(model,"Skill")then return false end
	local now=os.clock()
	if (tonumber(model:GetAttribute("VTRLastDribbleMoveAt")) or 0) + 1.15 > now then return false end
	model:SetAttribute("VTRLastDribbleMoveAt",now)
	local stars=math.clamp(tonumber(model:GetAttribute("SkillMoves"))or 1,1,5);local animation=stars>=4 and"DribbleMove4"or"DribbleMove1"
	if self.Animations then self.Animations:PlayAction(model,animation)end
	model:SetAttribute("VTRDribbleMoveUntil",now+.72);model:SetAttribute("VTRPostSkillVulnerableUntil",now+1.22)
	local move=flat(direction);local root=self:_root(model);local touchSpeed=10+stars*1.8;self.Ball.AssemblyLinearVelocity=move*touchSpeed+(root and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z)*.35 or Vector3.zero)
	task.delay(.78,function()if not model.Parent then return end;if self.Possession:GetOwner()==model then self.Stats:Event(model,"SuccessfulDribble")else self.Stats:Event(model,"FailedDribble")end end)
	self.Remote:FireAllClients({Type="DribbleMove",Actor=model,Animation=animation,Until=now+.72});return true
end

function Service:SetBlock(model:Model,active:boolean)
	model:SetAttribute("VTRBlocking",active==true);if active then model:SetAttribute("VTRBlockUntil",os.clock()+.8)end
end

function Service:Clearance(model:Model,fieldDirection:Vector3?):boolean
	if self.Possession:GetOwner()~=model or not self:_allowed(model,"Pass")then return false end
	local forward=fieldDirection and flat(fieldDirection)or flat((self:_root(model)and self:_root(model).CFrame.LookVector)or Vector3.zAxis)
	local angle=self.Random:NextNumber(-.22,.22)
	local direction=CFrame.fromAxisAngle(Vector3.yAxis,angle):VectorToWorldSpace(forward)
	local distance=self.Random:NextNumber(260,330)
	local origin=self.Ball.Position
	local destination=origin+direction*distance
	destination=Vector3.new(destination.X,origin.Y,destination.Z)
	local effectiveGravity=95
	local flightTime=math.clamp(distance/72,2.65,4.25)
	local velocity=(destination-origin)/flightTime+Vector3.yAxis*(effectiveGravity*flightTime*.5)
	self.PassTargetPoint=destination
	self.PassPlan={Target=destination,Distance=distance,InitialSpeed=Vector3.new(velocity.X,0,velocity.Z).Magnitude,ArrivalRatio=1,Started=os.clock(),Lofted=true,EffectiveGravity=effectiveGravity,FlightTime=flightTime,Clearance=true}
	self.Ball:SetAttribute("VTRLobTarget",destination)
	self.Ball:SetAttribute("VTRPassTarget",destination)
	self.Ball:SetAttribute("VTRLobPassActive",true)
	self.Ball:SetAttribute("VTRPassStartedAt", nil)
	self.Ball:SetAttribute("VTRPassTeam", nil)
	self.Ball:SetAttribute("VTRPassReceiver", nil)
	self:_touch(model);self.MotionKind="Clearance";self.MotionStarted=os.clock();self.Ball:SetAttribute("VTRMotionKind","Clearance");self.Stats:Event(model,"Clearance");if self.Animations then self.Animations:PlayAction(model,"Shoot")end;self.Possession:Release(velocity,.4);self.Remote:FireAllClients({Type="Clearance",Actor=model,Target=destination});return true
end

function Service:LowClearance(model:Model,fieldDirection:Vector3?,charge:number?):boolean
	if self.Possession:GetOwner()~=model or not self:_allowed(model,"Pass")then return false end
	local forward=fieldDirection and flat(fieldDirection)or flat((self:_root(model)and self:_root(model).CFrame.LookVector)or Vector3.zAxis)
	if forward.Magnitude<.05 then forward=Vector3.zAxis end
	local amount=math.clamp(charge or .45,0,1)
	local angle=self.Random:NextNumber(-.12,.12)
	local direction=CFrame.fromAxisAngle(Vector3.yAxis,angle):VectorToWorldSpace(forward.Unit)
	local distance=150+amount*135
	local origin=self.Ball.Position
	local destination=origin+direction*distance
	destination=Vector3.new(destination.X,origin.Y,destination.Z)
	local effectiveGravity=88
	local flightTime=math.clamp(distance/(68+amount*18),2.25,3.85)
	local velocity=(destination-origin)/flightTime+Vector3.yAxis*(effectiveGravity*flightTime*.5)
	self.PassTargetPoint=destination
	self.PassPlan={Target=destination,Distance=distance,InitialSpeed=Vector3.new(velocity.X,0,velocity.Z).Magnitude,ArrivalRatio=1,Started=os.clock(),Lofted=true,EffectiveGravity=effectiveGravity,FlightTime=flightTime,Clearance=true}
	self.Ball:SetAttribute("VTRLobTarget",destination)
	self.Ball:SetAttribute("VTRLobPassActive",true)
	self.Ball:SetAttribute("VTRPassTarget",self.PassTargetPoint)
	self.Ball:SetAttribute("VTRPassStartedAt", nil)
	self.Ball:SetAttribute("VTRPassTeam", nil)
	self.Ball:SetAttribute("VTRPassReceiver", nil)
	self:_touch(model);self.MotionKind="Clearance";self.MotionStarted=os.clock();self.Ball:SetAttribute("VTRMotionKind","Clearance");self.Stats:Event(model,"Clearance");if self.Animations then self.Animations:PlayAction(model,"Shoot")end;self.Possession:Release(velocity,.35);self.Remote:FireAllClients({Type="Clearance",Actor=model,Target=self.PassTargetPoint});return true
end

function Service:Tackle(model: Model,slide:boolean?): boolean
	if not self:_allowed(model, "Tackle") then
		return false
	end
	local action=slide and"SlideTackle"or"Tackle";if self.Animations then self.Animations:PlayAction(model,action)end
	local owner = self.Possession:GetOwner()
	local modelRoot = self:_root(model)
	local ownerRoot = owner and self:_root(owner)
	if not owner or owner == model or not modelRoot or not ownerRoot or (modelRoot.Position - ownerRoot.Position).Magnitude > Config.Ball.TackleRange then
		return false
	end
	local ownerFacing=flat(ownerRoot.CFrame.LookVector);local toTackler=flat(modelRoot.Position-ownerRoot.Position);local angleDot=ownerFacing:Dot(toTackler);local approach=angleDot>.35 and"Front"or angleDot<-.35 and"Behind"or"Side"
	local now=os.clock();local duringSkill=(tonumber(owner:GetAttribute("VTRDribbleMoveUntil"))or 0)>now;local vulnerable=(tonumber(owner:GetAttribute("VTRPostSkillVulnerableUntil"))or 0)>now and not duringSkill
	local foulChance=approach=="Behind"and.8 or approach=="Side"and.4 or 0
	local forceCard=false;local redChance:number?=nil
	if slide then foulChance=approach=="Behind"and 1 or approach=="Side"and.4 or.12;if duringSkill then foulChance=1 end;if approach=="Behind"then forceCard=true;redChance=.5 end end
	if vulnerable and approach~="Behind"then foulChance=0 end
	if foulChance>0 and self.Random:NextNumber()<foulChance and self.Referee then
		self.Stats:RecordTackle(model,false);self.Referee:CallFoul(model,owner,slide and"Slide Tackle"or"Standing Tackle",ownerRoot.Position,forceCard,redChance);return false
	end
	local tackleStat=math.clamp(tonumber(model:GetAttribute(slide and"SlidingTackle"or"StandingTackle"))or tonumber(model:GetAttribute("DEF"))or 55,1,99)
	local dribbling=math.clamp(tonumber(owner:GetAttribute("Dribbling"))or tonumber(owner:GetAttribute("DRI"))or 55,1,99);local disparity=dribbling-tackleStat
	local chance=disparity<=10 and 1 or disparity<=30 and(1-(disparity-10)/20*.5)or 0
	if duringSkill then chance=.1 elseif vulnerable and approach~="Behind"then chance=1 end
	if self.Random:NextNumber() > chance then
		self.Stats:RecordTackle(model,false)
		self.Possession:Block(model, 0.5)
		return false
	end
	self.Stats:RecordTackle(model,true)
	self.Stats:Event(owner,"PossessionLost")
	self:_touch(model)
	self.MotionKind = "Tackle"
	self.MotionStarted = os.clock()
	self.Possession:ForcePickup(model);model:SetAttribute("VTRNoAutoPassUntil",now+1)
	self.Possession:Block(owner,slide and 1.5 or.5);owner:SetAttribute("VTRStunnedUntil",now+(slide and 1.5 or.5))
	local ownerHumanoid=owner:FindFirstChildOfClass("Humanoid");if ownerHumanoid then ownerHumanoid:Move(Vector3.zero,false)end
	self.Remote:FireAllClients({Type = slide and"SlideTackle"or"Tackle", Actor = model,Victim=owner})
	return true
end

function Service:_applyLoosePhysics(dt: number)
	local velocity = self.Ball.AssemblyLinearVelocity
	local shotPlan=self.ShotPlan
	local passPlan=self.PassPlan
	if shotPlan and os.clock()-shotPlan.Started<2.5 then
		velocity+=Vector3.yAxis*math.max(0,workspace.Gravity-shotPlan.EffectiveGravity)*dt
		local toTarget=shotPlan.Target-self.Ball.Position
		local horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z)
		local horizontalTarget=Vector3.new(toTarget.X,0,toTarget.Z)
		if toTarget.Magnitude<2 or horizontalVelocity.Magnitude>.1 and horizontalTarget:Dot(horizontalVelocity)<=0 then self.ShotPlan=nil end
	else self.ShotPlan=nil end
	if passPlan and passPlan.Lofted and os.clock()-passPlan.Started<(passPlan.FlightTime or 0)+.08 then velocity+=Vector3.yAxis*math.max(0,workspace.Gravity-(passPlan.EffectiveGravity or workspace.Gravity))*dt end
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local ground = workspace:Raycast(self.Ball.Position, Vector3.new(0, -Physics.GROUND_HEIGHT_TOLERANCE * 2, 0), self.Raycast)
	local grounded = ground ~= nil and math.abs(velocity.Y) < 8
	local age = os.clock() - self.MotionStarted
	local passTravel = (self.MotionKind == "Pass" or self.MotionKind=="Clearance") and self.PassTargetPoint and age < 3.8
	local preservation = self.MotionKind == "Shot" and age < 1.15 and 0.34 or passTravel and 0.42 or 1
	local loftFlying=passPlan and passPlan.Lofted and age<(passPlan.FlightTime or 0)+.08
	local drag = loftFlying and 0 or grounded and Physics.ROLLING_DRAG * preservation or(self.MotionKind=="Shot"and age<2 and 0 or Physics.AIR_DRAG)
	local decay = math.exp(-drag * dt)
	horizontal *= decay
	if grounded then
		if passPlan and passPlan.Lofted and not passPlan.Landed then
			passPlan.Landed=true
			-- Give lofted passes a readable first bounce instead of a harsh
			-- physics snap. The ball keeps forward intent but loses the ugly
			-- vertical jitter that made landings feel laggy.
			if velocity.Y < -2 then
				velocity = Vector3.new(velocity.X, math.min(math.abs(velocity.Y) * .32 + 3.5, 18), velocity.Z)
			end
			horizontal *= .9
		end
		horizontal *= math.exp(-Physics.GROUND_FRICTION * dt * math.clamp(18 / math.max(horizontal.Magnitude, 1), 0.25, 1.35))
	end
	local plan=self.PassPlan
	if passTravel and plan and os.clock()-plan.Started<5 and horizontal.Magnitude>.1 then
		local toTarget=Vector3.new(plan.Target.X-self.Ball.Position.X,0,plan.Target.Z-self.Ball.Position.Z)
		if plan.Lofted then
			-- The initial ballistic velocity already solves this endpoint.
		elseif toTarget.Magnitude>1 and toTarget:Dot(horizontal)>0 then
			local progress=math.clamp(1-toTarget.Magnitude/plan.Distance,0,1)
			local retained=1-(1-plan.ArrivalRatio)*(progress^.82)
			local plannedSpeed=plan.InitialSpeed*retained
			local corrected=horizontal.Magnitude+(plannedSpeed-horizontal.Magnitude)*math.clamp(dt*7,0,1)
			horizontal=horizontal.Unit*corrected
		else self.PassPlan=nil end
	end
	if grounded and horizontal.Magnitude < Physics.STOP_THRESHOLD then
		horizontal = Vector3.zero
		if math.abs(velocity.Y) < 1.2 then
			velocity = Vector3.zero
		end
	end
	self.Ball.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
	if passTravel and self.PassTargetPoint then
		local remaining = (Vector3.new(self.PassTargetPoint.X, 0, self.PassTargetPoint.Z) - Vector3.new(self.Ball.Position.X, 0, self.Ball.Position.Z)).Magnitude
		if remaining > 5 and horizontal.Magnitude > 0.1 and horizontal.Magnitude < 14 then
			self.Ball.AssemblyLinearVelocity = Vector3.new(horizontal.Unit.X * 14, velocity.Y, horizontal.Unit.Z * 14)
		end
	end
	local angularDecay = math.exp(-Physics.ANGULAR_DAMPING * dt)
	self.Ball.AssemblyAngularVelocity *= angularDecay
	if self.Ball.AssemblyLinearVelocity.Magnitude > Physics.MAX_BALL_SPEED then
		self.Ball.AssemblyLinearVelocity = self.Ball.AssemblyLinearVelocity.Unit * Physics.MAX_BALL_SPEED
	end
end

function Service:Step(dt: number)
	local owner = self.Possession:GetOwner()
	if owner then
		self.Ball:SetAttribute("VTRMotionKind","Dribble")
		self.Ball:SetAttribute("VTRLobTarget", nil)
		self.Ball:SetAttribute("VTRLobPassActive", nil)
		self.Ball:SetAttribute("VTRPassTarget", nil)
		self.Curve:Stop()
		self.PassPlan=nil
		self.ShotPlan=nil
		self:_touch(owner)
		local ownerRoot = self:_root(owner)
		if not ownerRoot or not ownerRoot.Parent then
			self.Possession:Release(nil, 0)
			return
		end
		if owner:GetAttribute("VTRGoalkeeperHolding")==true then
			self.Stats:Add(tostring(owner:GetAttribute("VTRTeam")or"Home"),"Possession",dt)
			return
		end
		local sprinting = owner:GetAttribute("VTRSprinting") == true
		local closeControl = owner:GetAttribute("VTRCloseControl") == true
		local distance = Scaling.TouchDistance(tonumber(owner:GetAttribute("DRI")) or 60, sprinting) * (closeControl and 0.62 or 1)
		local movement = owner:GetAttribute("VTRMoveDirection")
		local touchDirection = typeof(movement) == "Vector3" and movement.Magnitude > 0.1 and movement.Unit or flat(ownerRoot.CFrame.LookVector)
		local target = ownerRoot.Position + touchDirection * distance - Vector3.new(0, Config.Ball.DribbleVerticalOffset, 0)
		local errorVector = Vector3.new(target.X - self.Ball.Position.X, 0, target.Z - self.Ball.Position.Z)
		local desired = errorVector * Config.Ball.DribbleResponsiveness + Vector3.new(ownerRoot.AssemblyLinearVelocity.X, 0, ownerRoot.AssemblyLinearVelocity.Z) * 0.7
		if desired.Magnitude > Config.Ball.MaxDribbleSpeed then
			desired = desired.Unit * Config.Ball.MaxDribbleSpeed
		end
		self.Ball.AssemblyLinearVelocity = Vector3.new(desired.X, self.Ball.AssemblyLinearVelocity.Y, desired.Z)
		local horizontal = Vector3.new(desired.X, 0, desired.Z)
		if horizontal.Magnitude > 0.2 then self.Ball.AssemblyAngularVelocity = Vector3.yAxis:Cross(horizontal.Unit) * (horizontal.Magnitude / math.max(self.Ball.Size.X * 0.5, 0.1)) end
		self.Stats:Add(tostring(owner:GetAttribute("VTRTeam") or "Home"), "Possession", dt)
		return
	end
	self.Curve:Step(dt)
	self:_applyLoosePhysics(dt)
	if (tonumber(self.Ball:GetAttribute("VTRPostGoalPhysicsUntil")) or 0) > os.clock() then
		return
	end
	if self.MotionKind=="Shot"then
		for _,model in self.Models do if model:GetAttribute("VTRBlocking")==true and(tonumber(model:GetAttribute("VTRBlockUntil"))or 0)>=os.clock()then local modelRoot=self:_root(model);if modelRoot then local offset=self.Ball.Position-modelRoot.Position;local horizontal=Vector3.new(offset.X,0,offset.Z).Magnitude;local relativeHeight=self.Ball.Position.Y-modelRoot.Position.Y;local wallJump=(tonumber(model:GetAttribute("VTRWallJumpUntil"))or 0)>=os.clock();local radius=wallJump and 4.2 or 3;local maxHeight=wallJump and 8.8 or 5.2;if horizontal<=radius and relativeHeight>=-1.2 and relativeHeight<=maxHeight then local last=tonumber(model:GetAttribute("VTRLastBlockAt"))or 0;if os.clock()-last>.5 then model:SetAttribute("VTRLastBlockAt",os.clock());local velocity=self.Ball.AssemblyLinearVelocity;local normal=flat(self.Ball.Position-modelRoot.Position);self.Ball.AssemblyLinearVelocity=(velocity-normal*2*velocity:Dot(normal))*.58+Vector3.yAxis*(wallJump and 12 or 4);self.MotionKind="Deflection";self.ShotPlan=nil;self.Curve:Stop();self.Stats:Event(model,"Block");self.Remote:FireAllClients({Type="Block",Actor=model});break end end end end end
	end
	if self.CornerPlan then
		local age=os.clock()-self.CornerPlan.Started;local distance=(self.Ball.Position-self.CornerPlan.Target).Magnitude
		if not self.CornerPlan.Entered and distance<25 then self.CornerPlan.Entered=true;self.Ball:SetAttribute("VTRCornerEnteredBox",true);self.Stats:Add(self.CornerPlan.Team,"CornersIntoBox");self.Remote:FireAllClients({Type="CornerObjective",Event="cornerEnteredBox",Team=self.CornerPlan.Team})end
		if age>8 then self.CornerPlan=nil end
	end
	self.Accumulator += dt
	if self.Accumulator <= 0.04 then
		return
	end
	self.Accumulator = 0
	local nearest: Model? = nil
	local best = Config.Ball.PossessionRange
	local forcedReceiverPickup = false
	if self.MotionKind == "Pass" and self.ExpectedReceiver and self.ExpectedReceiver.Parent and (self.ExpectedReceiver:GetAttribute("aiControlled") == true or (self.ExpectedReceiver:GetAttribute("controlledByUser") ~= true and self.ExpectedReceiver:GetAttribute("VTRUserId") == nil)) then
		local receiverRoot = self:_root(self.ExpectedReceiver)
		local humanoid = self.ExpectedReceiver:FindFirstChildOfClass("Humanoid")
		if receiverRoot and humanoid and humanoid.Health > 0 and self.Possession:GetOwner() == nil then
			local ballVelocity = Vector3.new(self.Ball.AssemblyLinearVelocity.X, 0, self.Ball.AssemblyLinearVelocity.Z)
			local receiverFlat = Vector3.new(receiverRoot.Position.X, 0, receiverRoot.Position.Z)
			local ballFlat = Vector3.new(self.Ball.Position.X, 0, self.Ball.Position.Z)
			local distanceToBall = (receiverFlat - ballFlat).Magnitude
			local pathDistance = distanceToBall
			local ahead = 0
			if ballVelocity.Magnitude > 1 then
				local direction = ballVelocity.Unit
				local offset = receiverFlat - ballFlat
				ahead = offset:Dot(direction)
				local closest = ballFlat + direction * math.clamp(ahead, -8, 18)
				pathDistance = (receiverFlat - closest).Magnitude
			end
			local preparing = self.ExpectedReceiver:GetAttribute("VTRPreparingReceive") == true and (tonumber(self.ExpectedReceiver:GetAttribute("VTRReceiveUntil")) or 0) > os.clock()
			local trapRadius = preparing and 9.5 or 6
			local canGuidePass = preparing and pathDistance <= trapRadius and distanceToBall <= 13 and ahead > -2
			if canGuidePass and not self.Possession:CanPickup(self.ExpectedReceiver) and ballVelocity.Magnitude > 1 then
				local carryDirection = ballVelocity.Unit
				local receiverVelocity = Vector3.new(receiverRoot.AssemblyLinearVelocity.X, 0, receiverRoot.AssemblyLinearVelocity.Z)
				local desiredDirection = receiverVelocity.Magnitude > 1.5 and receiverVelocity.Unit or carryDirection
				local frontPoint = receiverRoot.Position + desiredDirection * 2.6 + Vector3.new(0, -1.45, 0)
				local toFront = frontPoint - self.Ball.Position
				local guide = toFront.Magnitude > 0.05 and toFront.Unit * math.min(toFront.Magnitude * 5.5, 18) or Vector3.zero
				self.Ball.AssemblyLinearVelocity = ballVelocity * 0.72 + guide
			end
			local canTrapPass = canGuidePass and distanceToBall <= (Config.Ball.PossessionRange + 1.35) and pathDistance <= 4.75
			if self.Possession:CanPickup(self.ExpectedReceiver) or canTrapPass then
				self.Possession:ForcePickup(self.ExpectedReceiver)
				if ballVelocity.Magnitude > 1 then
					local carryDirection = ballVelocity.Unit
					local receiverVelocity = Vector3.new(receiverRoot.AssemblyLinearVelocity.X, 0, receiverRoot.AssemblyLinearVelocity.Z)
					local desiredDirection = receiverVelocity.Magnitude > 1.5 and receiverVelocity.Unit or carryDirection
					self.ExpectedReceiver:SetAttribute("VTRMoveDirection", carryDirection)
					local frontPoint = receiverRoot.Position + desiredDirection * 2.6 + Vector3.new(0, -1.45, 0)
					local toFront = frontPoint - self.Ball.Position
					local guide = toFront.Magnitude > 0.05 and toFront.Unit * math.min(toFront.Magnitude * 10, 28) or Vector3.zero
					self.Ball.AssemblyLinearVelocity = receiverVelocity * 0.55 + guide + desiredDirection * 7
				else
					local forward = Vector3.new(receiverRoot.CFrame.LookVector.X, 0, receiverRoot.CFrame.LookVector.Z)
					if forward.Magnitude < 0.05 then forward = Vector3.zAxis end
					self.Ball.AssemblyLinearVelocity = forward.Unit * 8
				end
				self.Ball.AssemblyAngularVelocity = Vector3.zero
				self.ExpectedReceiver:SetAttribute("VTRReceivedAt", os.clock())
				self.ExpectedReceiver:SetAttribute("VTRImmediateControlUntil", os.clock() + 0.25)
				self.ExpectedReceiver:SetAttribute("VTRReceiveTarget", nil)
				self.ExpectedReceiver:SetAttribute("VTRPreparingReceive", false)
				self.ExpectedReceiver:SetAttribute("VTRReceiveUntil", nil)
				self.ExpectedReceiver:SetAttribute("VTRReceiveIntercept", nil)
				self.ExpectedReceiver:SetAttribute("AIDebugExpectedPass", nil)
				nearest = self.ExpectedReceiver
				best = 0
				forcedReceiverPickup = true
			end
		end
	end
	for _, model in self.Models do
		local modelRoot = self:_root(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if modelRoot and humanoid and humanoid.Health > 0 then
			local distance = (modelRoot.Position - self.Ball.Position).Magnitude
			if distance < best and self.Possession:CanPickup(model) then
				nearest = model
				best = distance
			end
		end
	end
	if nearest and (forcedReceiverPickup or self.Possession:Pickup(nearest)) then
		local team = nearest:GetAttribute("VTRTeam")
		if self.OffsideCandidate and nearest==self.OffsideCandidate and self.Offside then self.Offside:Call(nearest);self.OffsideCandidate=nil;self.LastPassTeam=nil;self.LastPasser=nil;self.LastPassOrigin=nil;self.ExpectedReceiver=nil;self.PassPlan=nil;self.Ball:SetAttribute("VTRPassTarget",nil);self.Ball:SetAttribute("VTRPassStartedAt",nil);self.Ball:SetAttribute("VTRPassTeam",nil);self.Ball:SetAttribute("VTRPassReceiver",nil);return end
		if self.LastPassTeam then
			if self.LastPassTeam==team and self.LastPasser then
				self.Stats:RecordPassCompleted(self.LastPasser,nearest,self.LastPassOrigin,self.Ball.Position)
				if AIPassingDecisionService.RecordPassOutcome then AIPassingDecisionService.RecordPassOutcome(self.LastPasser,nearest,true) end
			elseif self.LastPasser then
				self.Stats:RecordPassFailed(self.LastPasser,nearest)
				if AIPassingDecisionService.RecordPassOutcome then AIPassingDecisionService.RecordPassOutcome(self.LastPasser,nearest,false) end
			end
		end
		self.LastPassTeam = nil
		self.LastPasser=nil;self.LastPassOrigin=nil
		self.ExpectedReceiver = nil
		self.OffsideCandidate=nil
		self.PassPlan=nil
		self.Ball:SetAttribute("VTRLobTarget", nil)
		self.Ball:SetAttribute("VTRLobPassActive", nil)
		self.Ball:SetAttribute("VTRPassTarget", nil)
		self.Ball:SetAttribute("VTRPassStartedAt", nil)
		self.Ball:SetAttribute("VTRPassTeam", nil)
		self.Ball:SetAttribute("VTRPassReceiver", nil)
		self:_touch(nearest)
		if self.CornerPlan and nearest:GetAttribute("VTRTeam")==self.CornerPlan.Team then self.Stats:Add(self.CornerPlan.Team,"CornerReachedTeammate");self.Remote:FireAllClients({Type="CornerObjective",Event="cornerReachedTeammate",Team=self.CornerPlan.Team});self.CornerPlan=nil end
	end
end

return Service
