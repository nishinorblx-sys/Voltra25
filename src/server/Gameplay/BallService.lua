local VTR_CLOSE_DRIBBLE_DISTANCE=0.62
--!strict


local function vtrLoadShotPowerModel()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local vtr = ReplicatedStorage:FindFirstChild("VTR")
	local shared = (vtr and vtr:FindFirstChild("Shared")) or ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage
	return require(shared:WaitForChild("ShotPowerModel"))
end

local VTRShotPowerModel = vtrLoadShotPowerModel()
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
local OFFSIDE_EXEMPT_RESTARTS={Corner=true,ThrowIn=true,GoalKick=true}
local ballisticVelocity: (Vector3, Vector3, number, number?) -> Vector3?

local function flat(vector: Vector3): Vector3
	local value = Vector3.new(vector.X, 0, vector.Z)
	return value.Magnitude > 0.01 and value.Unit or Vector3.zAxis
end

local function keepDribbleTargetAtFeet(ball: BasePart, raycast: RaycastParams, ownerRoot: BasePart, target: Vector3, direction: Vector3): Vector3
	local radius = math.max(ball.Size.Y * 0.5, Config.Ball.Radius or 0.1)
	local visualRadius = math.max(radius - 0.18, radius * 0.86)
	local rootFlat = Vector3.new(ownerRoot.Position.X, 0, ownerRoot.Position.Z)
	local targetFlat = Vector3.new(target.X, 0, target.Z)
	local offset = targetFlat - rootFlat
	local minSeparation = math.max(radius * 1.65, 2.15)
	if offset.Magnitude < minSeparation then
		local safeDirection = direction.Magnitude > 0.01 and direction.Unit or flat(ownerRoot.CFrame.LookVector)
		targetFlat = rootFlat + safeDirection * minSeparation
	end

	local origin = Vector3.new(targetFlat.X, ownerRoot.Position.Y + 3.5, targetFlat.Z)
	local ground = workspace:Raycast(origin, Vector3.new(0, -10, 0), raycast)
	local y = ownerRoot.Position.Y - Config.Ball.DribbleVerticalOffset
	if ground and ground.Normal.Y > 0.55 then
		y = ground.Position.Y + visualRadius + 0.015
	end

	local maxOwnedHeight = ownerRoot.Position.Y - 0.35
	return Vector3.new(targetFlat.X, math.min(y, maxOwnedHeight), targetFlat.Z)
end

local function clearFlightAttributes(ball: BasePart)
	ball:SetAttribute("VTRLobTarget", nil)
	ball:SetAttribute("VTRLobPassActive", nil)
	ball:SetAttribute("VTRPassTarget", nil)
	ball:SetAttribute("VTRShotTarget", nil)
end

local function destroyGoalkeeperCatchWelds(ball:BasePart)
	for _,child in ball:GetChildren() do
		if child:IsA("WeldConstraint") and child.Name=="VTRGoalkeeperCatchWeld" then
			child:Destroy()
		end
	end
end

local function clampAssembly(part: BasePart, maxLinear: number, maxAngular: number)
	if part.AssemblyLinearVelocity.Magnitude > maxLinear then
		part.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(part.AssemblyLinearVelocity.Unit * maxLinear, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	end
	if part.AssemblyAngularVelocity.Magnitude > maxAngular then
		part.AssemblyAngularVelocity = VTRShotPowerModel.ApplyToVelocity(part.AssemblyAngularVelocity.Unit * maxAngular, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	end
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
function Service:SetFoulPolicy(policy:any)self.FoulPolicy=policy end

function Service:_clearOffsideSnapshot()
	self.OffsideCandidate=nil
	self.OffsideCandidates=nil
	self.OffsidePasser=nil
	self.OffsidePassStartedAt=nil
end

function Service:_recordOffsideSnapshot(passer:Model,team:string,ballPosition:Vector3)
	self:_clearOffsideSnapshot()
	if not self.Offside then return end
	local restartKind=tostring(passer:GetAttribute("VTRSetPieceKind")or self.Ball:GetAttribute("VTRSetPieceReady")or"")
	if OFFSIDE_EXEMPT_RESTARTS[restartKind] then return end
	local candidates={}
	for _,candidate in self.Models do
		if candidate~=passer and candidate:GetAttribute("VTRTeam")==team and self.Offside:IsOffside(passer,candidate,ballPosition)then
			candidates[candidate]=true
			if not self.OffsideCandidate then self.OffsideCandidate=candidate end
		end
	end
	if next(candidates)then
		self.OffsideCandidates=candidates
		self.OffsidePasser=passer
		self.OffsidePassStartedAt=os.clock()
	end
end

function Service:_isOffsideCandidate(model:Model):boolean
	local candidates=self.OffsideCandidates
	return candidates~=nil and candidates[model]==true
end

function Service:_canAutoFoul(offender:Model, victim:Model):boolean
	if offender:GetAttribute("aiControlled")~=true then return true end
	local policy=self.FoulPolicy
	if type(policy)~="table"then return true end
	local humanSides=policy.HumanSides or{}
	local humanCount=0
	for _,hasHuman in humanSides do if hasHuman==true then humanCount+=1 end end
	if humanCount<=0 then return true end
	local offenderSide=tostring(offender:GetAttribute("VTRTeam")or"")
	local victimSide=tostring(victim:GetAttribute("VTRTeam")or"")
	if humanCount==1 then
		return humanSides[offenderSide]~=true and humanSides[victimSide]==true
	end
	return false
end

function Service:_qualityParryVelocity(keeper: Model, savePoint: Vector3, shotPlan: any): Vector3
	local keeperRoot = self:_root(keeper)
	local incoming = self.Ball.AssemblyLinearVelocity
	local incomingFlat = flat(incoming)
	local forward = incomingFlat.Magnitude > .05 and incomingFlat.Unit or Vector3.zAxis
	local right = keeperRoot and flat(keeperRoot.CFrame.RightVector) or Vector3.xAxis
	if right.Magnitude < .05 then right = Vector3.xAxis else right = right.Unit end
	local offset = keeperRoot and (savePoint - keeperRoot.Position) or Vector3.zero
	local side = offset:Dot(right) >= 0 and 1 or -1
	local verticalOffset = offset.Y
	local shotTarget = shotPlan and shotPlan.Target
	if typeof(shotTarget) == "Vector3" and keeperRoot then
		local targetOffset = shotTarget - keeperRoot.Position
		side = targetOffset:Dot(right) >= 0 and 1 or -1
		verticalOffset = math.max(verticalOffset, targetOffset.Y)
	end
	local speed = math.clamp(incoming.Magnitude * .58 + 30, 54, 118)
	if verticalOffset >= 3.4 then
		return (forward * .44 + Vector3.yAxis * .9).Unit * math.clamp(speed * .92, 48, 102)
	end
	local sideDirection = (forward * .42 + right * side * .72 + Vector3.yAxis * .16)
	return sideDirection.Unit * speed
end

function Service:GoalkeeperSave(keeper: Model, savePoint: Vector3): boolean
	if self.MotionKind ~= "Shot" and self.MotionKind ~= "Deflection" then return false end
	local shotPlan = self.ShotPlan
	local highQualityShot = shotPlan and (
		(tonumber(shotPlan.RawCharge) or 0) >= .83
		or (tonumber(shotPlan.PowerQuality) or 0) >= .83
		or (tonumber(shotPlan.Quality) or 0) >= .83
	)
	self.Curve:Stop()
	self.ShotPlan = nil
	self.PassPlan = nil
	self.PassTargetPoint = nil
	clearFlightAttributes(self.Ball)
	self.Ball:SetAttribute("VTRPassStartedAt", nil)
	self.Ball:SetAttribute("VTRPassTeam", nil)
	self.Ball:SetAttribute("VTRPassReceiver", nil)
	self.ExpectedReceiver = nil
	self.LastPassTeam = nil
	self:_clearOffsideSnapshot()
	self.MotionKind = "Save"
	self.MotionStarted = os.clock()
	self.Ball:SetAttribute("VTRMotionKind", "Save")
	self.Ball:SetAttribute("VTRGoalkeeperReleaseCameraUntil", os.clock() + 1.6)
	self:ReleaseGoalkeeperHold(keeper)
	if highQualityShot then
		local parryVelocity = self:_qualityParryVelocity(keeper, savePoint, shotPlan)
		self.Ball:SetAttribute("VTRGoalkeeperHeld", nil)
		self.Ball.Anchored = false
		pcall(function() self.Ball:SetNetworkOwner(nil) end)
		self.Ball.CFrame = CFrame.new(savePoint)
		self.Ball.CanCollide = true
		self.Ball.CanTouch = true
		self.Ball.Massless = false
		self.Ball.AssemblyLinearVelocity = parryVelocity
		self.Ball.AssemblyAngularVelocity = Vector3.new(
			self.Random:NextNumber(-8, 8),
			self.Random:NextNumber(-16, 16),
			self.Random:NextNumber(-8, 8)
		)
		keeper:SetAttribute("VTRGoalkeeperHolding", nil)
		keeper:SetAttribute("VTRGoalkeeperHoldingSince", nil)
		self.Possession:Reset()
		self.Possession:Block(keeper, .65)
		self:_touch(keeper)
		self.Remote:FireAllClients({Type="GoalkeeperSave",Actor=keeper,SavePoint=savePoint,Deflection=true})
		return true
	end
	local keeperRoot = self:_root(keeper)
	local catchPosition=keeperRoot and(keeperRoot.Position+keeperRoot.CFrame.LookVector*1.15+Vector3.new(0,0.25,0))or savePoint
	self.Ball:SetAttribute("VTRGoalkeeperHeld",true)
	keeper:SetAttribute("VTRGoalkeeperHolding",true)
	keeper:SetAttribute("VTRGoalkeeperHoldingSince",os.clock())
	self.Ball.Anchored = false
	pcall(function() self.Ball:SetNetworkOwner(nil) end)
	self.Ball.CFrame = CFrame.new(catchPosition)
	self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	self.Ball.AssemblyAngularVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	self.Ball.CanCollide=false;self.Ball.CanTouch=false;self.Ball.Massless=true
	self:_touch(keeper)
	self.Possession:ForcePickup(keeper)
	self.Remote:FireAllClients({Type="GoalkeeperSave",Actor=keeper,SavePoint=savePoint})
	return true
end

function Service:GoalkeeperClaim(keeper: Model): boolean
	local keeperRoot = self:_root(keeper)
	if not keeperRoot then return false end
	keeperRoot.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	keeperRoot.AssemblyAngularVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	self.Curve:Stop()
	self.ShotPlan = nil
	self.PassPlan = nil
	self.PassTargetPoint = nil
	clearFlightAttributes(self.Ball)
	self.Ball:SetAttribute("VTRPassStartedAt", nil)
	self.Ball:SetAttribute("VTRPassTeam", nil)
	self.Ball:SetAttribute("VTRPassReceiver", nil)
	self.ExpectedReceiver = nil
	self.LastPassTeam = nil
	self:_clearOffsideSnapshot()
	self.MotionKind = "KeeperClaim"
	self.MotionStarted = os.clock()
	self.Ball:SetAttribute("VTRMotionKind", "KeeperClaim")
	self.Ball:SetAttribute("VTRGoalkeeperReleaseCameraUntil", os.clock() + 1.6)
	self:ReleaseGoalkeeperHold(keeper)
	keeper:SetAttribute("VTRGoalkeeperHolding", nil)
	keeper:SetAttribute("VTRGoalkeeperHoldingSince", nil)
	self.Ball:SetAttribute("VTRGoalkeeperHeld", nil)
	local holdPosition = keeperRoot.Position + keeperRoot.CFrame.LookVector * 2.15 + Vector3.new(0, -1.8, 0)
	self.Ball.Anchored = false
	pcall(function() self.Ball:SetNetworkOwner(nil) end)
	self.Ball.CFrame = CFrame.new(holdPosition)
	self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	self.Ball.AssemblyAngularVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	self.Ball.CanCollide = true
	self.Ball.CanTouch = true
	self.Ball.Massless = false
	self:_touch(keeper)
	self.Possession:ForcePickup(keeper)
	self.Remote:FireAllClients({Type = "GoalkeeperClaim", Actor = keeper})
	return true
end

function Service:CornerKick(model:Model,target:Vector3,delivery:string,power:number,receiver:Model?):boolean
	if self.Possession:GetOwner()~=model then return false end
	local origin=self.Ball.Position;local delta=target-origin;local horizontal=Vector3.new(delta.X,0,delta.Z);local distance=horizontal.Magnitude;if distance<2 then return false end
	power=math.clamp(power,0,1)
	local vtrRawShotPower = power
	power = VTRShotPowerModel.ScaleInputPower(power)
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
	local cornerTeam=tostring(model:GetAttribute("VTRTeam")or"Home");self:_touch(model);self.MotionKind="Corner";self.MotionStarted=os.clock();self.Ball:SetAttribute("VTRMotionKind","Corner");self.Ball:SetAttribute("VTRLastCornerTeam",cornerTeam);self.Ball:SetAttribute("VTRCornerTakenAt",os.clock());self.Ball:SetAttribute("VTRCornerEnteredBox",false);self.Ball:SetAttribute("VTRPassTarget",target);self.Ball:SetAttribute("VTRShotTarget",nil);self.Ball:SetAttribute("VTRPassTeam",cornerTeam);self.Ball:SetAttribute("VTRPassReceiver",receiver and receiver.Name or nil);self.Ball:SetAttribute("VTRPassStartedAt",os.clock())
	self.CornerPlan={Team=tostring(model:GetAttribute("VTRTeam")or"Home"),Target=target,Receiver=receiver,Started=os.clock(),Entered=false}
	if self.Animations then self.Animations:PlayAction(model,"Pass")end
	self.Stats:Add(self.CornerPlan.Team,"Corners");self.Possession:Release(velocity,.4);self.Remote:FireAllClients({Type="CornerKick",Actor=model,Delivery=delivery,Target=target,Power=power,ObjectiveEvent="cornerTaken"});return true
end

function Service:ReleaseGoalkeeperHold(keeper:Model?)
	destroyGoalkeeperCatchWelds(self.Ball)
	self.Ball:SetAttribute("VTRGoalkeeperHeld",nil)
	self.Ball.Anchored=false
	pcall(function() self.Ball:SetNetworkOwner(nil) end)
	self.Ball.CanCollide=true;self.Ball.CanTouch=true;self.Ball.Massless=false
	self.Ball.AssemblyLinearVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	self.Ball.AssemblyAngularVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	if keeper then
		local keeperRoot=self:_root(keeper)
		if keeperRoot then
			keeperRoot.AssemblyLinearVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
			keeperRoot.AssemblyAngularVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
			self.Ball.CFrame=CFrame.new(keeperRoot.Position+keeperRoot.CFrame.LookVector*2.2+Vector3.new(0,-1.15,0))
		end
	end
	self:ClearGoalkeeperHoldState(keeper)
end

function Service:ClearGoalkeeperHoldState(keeper:Model?)
	destroyGoalkeeperCatchWelds(self.Ball)
	self.Ball:SetAttribute("VTRGoalkeeperHeld",nil)
	self.Ball.Anchored=false
	self.Ball.CanCollide=true;self.Ball.CanTouch=true;self.Ball.Massless=false
	pcall(function() self.Ball:SetNetworkOwner(nil) end)
	local function clearKeeper(model:Model?)
		if not model then return end
		model:SetAttribute("VTRGoalkeeperHolding",nil)
		model:SetAttribute("VTRGoalkeeperHoldingSince",nil)
		model:SetAttribute("VTRKeeperMustDistributeUntil",nil)
	end
	if keeper then
		clearKeeper(keeper)
	else
		for _,model in self.Models do
			if model:GetAttribute("VTRGoalkeeperHolding")==true or tostring(model:GetAttribute("position")or"")=="GK" then
				clearKeeper(model)
			end
		end
	end
end

function Service:PrepareGoalkeeperBallAction(keeper: Model?)
	if not keeper then return end
	if keeper:GetAttribute("VTRGoalkeeperHolding") == true or self.Ball:GetAttribute("VTRGoalkeeperHeld") == true or self.Ball:FindFirstChild("VTRGoalkeeperCatchWeld") then
		self:ReleaseGoalkeeperHold(keeper)
	end
	keeper:SetAttribute("VTRKeeperMustDistributeUntil", nil)
	keeper:SetAttribute("AIAssignment", "GoalkeeperPosition")
	keeper:SetAttribute("VTRNoAutoPassUntil", os.clock() + 0.45)
end

function Service:_guardGoalkeeperHold(owner:Model?)
	local weld=self.Ball:FindFirstChild("VTRGoalkeeperCatchWeld")
	local held=self.Ball:GetAttribute("VTRGoalkeeperHeld")==true
	local ballSpeed=self.Ball.AssemblyLinearVelocity.Magnitude
	local ballSpin=self.Ball.AssemblyAngularVelocity.Magnitude
	if ballSpeed > Physics.MAX_BALL_SPEED * 1.15 or ballSpin > 220 then
		destroyGoalkeeperCatchWelds(self.Ball)
		self.Ball:SetAttribute("VTRGoalkeeperHeld", nil)
		clampAssembly(self.Ball, Physics.MAX_BALL_SPEED, 160)
		if owner then
			local ownerRoot=self:_root(owner)
			if ownerRoot and ownerRoot.AssemblyLinearVelocity.Magnitude > 78 then
				ownerRoot.AssemblyLinearVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
				ownerRoot.AssemblyAngularVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
			end
		end
	end
	if owner and owner:GetAttribute("VTRGoalkeeperHolding")==true and tostring(owner:GetAttribute("position")or"")=="GK" then
		local ownerRoot=self:_root(owner)
		local ownerSpeed=ownerRoot and ownerRoot.AssemblyLinearVelocity.Magnitude or 0
		if ballSpeed>36 or ballSpin>95 or ownerSpeed>80 then
			self:ReleaseGoalkeeperHold(owner)
			if ownerRoot then
				ownerRoot.AssemblyLinearVelocity=Vector3.zero
				ownerRoot.AssemblyAngularVelocity=Vector3.zero
			end
			return
		end
		if not weld and not held then
			self:ClearGoalkeeperHoldState(owner)
		end
		return
	end
	if not weld and not held then return end
	if ballSpeed>18 or ballSpin>55 then
		self:ReleaseGoalkeeperHold(owner)
	else
		self:ClearGoalkeeperHoldState(nil)
		self.Ball.AssemblyLinearVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
		self.Ball.AssemblyAngularVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	end
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

local function shotStat(model: Model, primary: string, fallback: string?, default: number): number
	local value = tonumber(model:GetAttribute(primary))
	if value == nil and fallback then
		value = tonumber(model:GetAttribute(fallback))
	end
	return math.clamp(value or default, 1, 99)
end

local function shotPowerScaleFor(model: Model, shooting: number): number
	if model:GetAttribute("VTRRankedMatch") ~= true then
		return 1
	end
	local shotPower = shotStat(model, "ShotPower", "SHO", shooting)
	local vtrRawShotPower = shotPower
	shotPower = VTRShotPowerModel.ScaleInputPower(shotPower)
	local alpha = math.clamp((shotPower - 27) / 72, 0, 1)
	return 0.85 + (0.92 - 0.85) * alpha
end

function Service:_resolveTargetedShot(model: Model, intendedTarget: Vector3, charge: number): any
	local origin = self.Ball.Position
	local offset = intendedTarget - origin
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	local distance = horizontal.Magnitude
	local pressure = self:_pressure(model)
	local shooting = shotStat(model, "SHO", "Shooting", 60)
	local finishing = shotStat(model, "Finishing", nil, shooting)
	local composure = shotStat(model, "Composure", nil, shooting)
	local weakFoot = math.clamp(tonumber(model:GetAttribute("WeakFoot")) or 3, 1, 5)
	local statClean = math.clamp(0.38 + shooting / 390 + finishing / 520 + composure / 560 + weakFoot / 115, 0.42, 0.98)
	local sprintPenalty = model:GetAttribute("VTRSprinting") == true and 0.055 or 0
	local aimClean = math.clamp(statClean - pressure * 0.23 - sprintPenalty, 0.24, 0.985)
	local idealPower = math.clamp(0.5 + distance / 520 + math.max(0, offset.Y) / 82, 0.5, 0.82)
	local powerError = charge - idealPower
	local powerQuality = math.clamp(1 - math.abs(powerError) / 0.34, 0, 1)
	local forward = horizontal.Magnitude > 0.05 and horizontal.Unit or flat(offset)
	local lateralAxis = Vector3.yAxis:Cross(forward)
	if lateralAxis.Magnitude < 0.05 then
		lateralAxis = Vector3.xAxis
	else
		lateralAxis = lateralAxis.Unit
	end
	local missRadius = (1 - aimClean) * (1.35 + distance * 0.018)
	missRadius += pressure * (0.9 + distance * 0.013)
	missRadius += math.abs(powerError) * (1.0 + distance * 0.011)
	if math.abs(powerError) <= 0.08 then
		missRadius *= 0.62
	end
	if pressure < 0.16 and powerQuality > 0.84 and aimClean > 0.76 then
		missRadius *= 0.48
	end
	local lateralError = self.Random:NextNumber(-missRadius, missRadius)
	local verticalError = self.Random:NextNumber(-missRadius * 0.34, missRadius * 0.44)
	if powerError > 0.08 then
		verticalError += (powerError - 0.08) * (9.5 + distance * 0.024)
	elseif powerError < -0.16 then
		verticalError -= (-powerError - 0.16) * (2.2 + distance * 0.01)
	end
	local target = intendedTarget + lateralAxis * lateralError + Vector3.yAxis * verticalError
	if typeof(target) == "Vector3" then
		target = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, target, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	end
	local quality = math.clamp(aimClean * 0.52 + powerQuality * 0.34 + (1 - pressure) * 0.14 - math.max(0, charge - 0.9) * 0.12, 0.05, 0.98)
	return {
		Target = target,
		IntendedTarget = intendedTarget,
		Quality = quality,
		AimClean = aimClean,
		PowerQuality = powerQuality,
		PowerError = powerError,
		Pressure = pressure,
		LateralError = lateralError,
		VerticalError = verticalError,
	}
end

function Service:_shotVelocity(model: Model, direction: Vector3, charge: number, targetPoint:Vector3?): Vector3
	local modelRoot = self:_root(model)
	local team = model:GetAttribute("VTRTeam")
	local pressure = self:_pressure(model)
	local shooting = math.clamp(tonumber(model:GetAttribute("SHO")) or 60, 1, 99)
	local finishing = math.clamp(tonumber(model:GetAttribute("Finishing")) or shooting, 1, 99)
	local composure = math.clamp(tonumber(model:GetAttribute("Composure")) or shooting, 1, 99)
	local weakFoot = math.clamp(tonumber(model:GetAttribute("WeakFoot")) or 3, 1, 5)
	local highCharge = math.clamp((charge - 0.72) / 0.28, 0, 1)
	local powerScale = math.clamp(charge * 0.76 + charge * charge * 0.11 + highCharge ^ 1.55 * 0.26, 0, 1.13) * shotPowerScaleFor(model, shooting)
	local shotSpeed = (Config.Ball.ShotMinSpeed + (Config.Ball.ShotMaxSpeed - Config.Ball.ShotMinSpeed) * powerScale) * (0.92 + shooting / 950) + highCharge * highCharge * 24
	if targetPoint then
		if model:GetAttribute("VTRSetPieceTaker")==true and tostring(model:GetAttribute("VTRSetPieceKind") or "")=="FreeKick" then
			local origin=self.Ball.Position
			local lift=math.clamp(tonumber(model:GetAttribute("VTRFreeKickLift")) or 0,-2.5,2.5)*0.5
			local curve=math.clamp(tonumber(model:GetAttribute("VTRFreeKickCurve")) or 0,-2.5,2.5)
			local solved=FreeKickTrajectory.Compute(origin,targetPoint,curve,lift)
			self.PendingFreeKickTrajectory = {
				Target = targetPoint,
				Lateral = solved.Lateral,
				Strength = solved.Strength,
				FlightTime = solved.FlightTime,
				Gravity = solved.Gravity,
			}
			model:SetAttribute("VTRFreeKickTarget",targetPoint)
			model:SetAttribute("VTRFreeKickFlightTime",solved.FlightTime)
			model:SetAttribute("VTRFreeKickEffectiveGravity",solved.Gravity)
			model:SetAttribute("VTRFreeKickTrajectoryActive",true)
			return solved.InitialVelocity
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
	local rawShotPower = amount
	local velocity: Vector3
	local shotVariant="Normal"
	local practiceShotPowerScale=kind=="Shot"and math.clamp(tonumber(model:GetAttribute("VTRPracticeShotPower"))or 1,.55,1.55)or 1
	if kind=="Shot"then
		rawShotPower = math.clamp(amount * practiceShotPowerScale, 0, 1)
		amount = math.clamp(VTRShotPowerModel.ScaleInputPower(rawShotPower), 0, 1)
	end
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
			local horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z)
			local flightTime=distance/math.max(horizontalVelocity.Magnitude,1)
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
		self.Ball:SetAttribute("VTRShotTarget", nil)
		self.Stats:RecordPassAttempt(model)
		self.LastPassTeam = team
		self.LastPasser=model
		self.LastPassOrigin=modelRoot and modelRoot.Position or self.Ball.Position
		self.ExpectedReceiver = receiver
		self.Ball:SetAttribute("VTRPassStartedAt", os.clock())
		self.Ball:SetAttribute("VTRPassTeam", team)
		self.Ball:SetAttribute("VTRPassReceiver", receiver and receiver.Name or nil)
		self:_recordOffsideSnapshot(model,team,self.Ball.Position)
	elseif kind == "Shot" then
		self.Ball:SetAttribute("VTRPassStartedAt", nil)
		self.Ball:SetAttribute("VTRPassTeam", nil)
		self.Ball:SetAttribute("VTRPassReceiver", nil)
		self.Ball:SetAttribute("VTRPassTarget", nil)
		self.Ball:SetAttribute("VTRLobTarget", nil)
		self.Ball:SetAttribute("VTRLobPassActive", nil)
		self:_clearOffsideSnapshot()
		local modelRoot=self:_root(model)
		if targetPoint and modelRoot then
			local facing=flat(modelRoot.CFrame.LookVector)
			local shotDir=flat(targetPoint-modelRoot.Position)
			local facingDot=facing.Magnitude>.05 and shotDir.Magnitude>.05 and math.clamp(facing.Unit:Dot(shotDir.Unit),-1,1)or 1
			if facingDot<.72 then amount*=math.clamp(.55+math.max(facingDot,0)*.55,.55,.95)end
		end
		local penaltySlot=tostring(model:GetAttribute("VTRPenaltySlot")or"")
		local shotType = (passType == "Penalty" or penaltySlot ~= "") and "Penalty" or nil
		local directFreeKick = model:GetAttribute("VTRSetPieceTaker")==true and tostring(model:GetAttribute("VTRSetPieceKind") or "")=="FreeKick"
		local freeKickTrajectory=false
		shotVariant=tostring(model:GetAttribute("VTRShotVariant")or"Normal")
		local finesseShot=shotVariant=="Finesse"
		local lowDrivenShot=shotVariant=="LowDriven"
		local executedTarget = targetPoint
		local execution = nil
		if targetPoint and not directFreeKick and shotType ~= "Penalty" then
			execution = self:_resolveTargetedShot(model, targetPoint, amount)
			executedTarget = execution.Target
		end
		local overhit = VTRShotPowerModel.OverhitAmount(rawShotPower)
		if overhit > 0 and executedTarget and modelRoot then
			local shotFlat = flat(executedTarget - modelRoot.Position)
			local lateralAxis = shotFlat.Magnitude > .05 and Vector3.new(-shotFlat.Z, 0, shotFlat.X).Unit or Vector3.xAxis
			executedTarget += Vector3.yAxis * (7 + overhit * 13) + lateralAxis * self.Random:NextNumber(-1, 1) * (1.2 + overhit * 3.2)
		end
		local accuracyScale=math.clamp(tonumber(model:GetAttribute("VTRPracticeShotAccuracy"))or 1,.45,1.75)
		if executedTarget and modelRoot then
			local intended=targetPoint or executedTarget
			local baseDirection=flat(executedTarget-modelRoot.Position)
			local lateralAxis=baseDirection.Magnitude>.05 and Vector3.new(-baseDirection.Z,0,baseDirection.X).Unit or Vector3.xAxis
			if accuracyScale<1 then
				executedTarget+=lateralAxis*self.Random:NextNumber(-1,1)*(1-accuracyScale)*18+Vector3.yAxis*self.Random:NextNumber(-1,1)*(1-accuracyScale)*7
			elseif intended then
				executedTarget=executedTarget:Lerp(intended,math.clamp((accuracyScale-1)*.55,0,.42))
			end
		end
		local shotDirection = executedTarget and modelRoot and (executedTarget - modelRoot.Position) or direction
		velocity = self:_shotVelocity(model, shotDirection, amount,executedTarget)
		local shotSpeedScale=math.clamp(tonumber(model:GetAttribute("VTRPracticeShotSpeed"))or 1,.45,1.75)
		local liftScale=math.clamp(tonumber(model:GetAttribute("VTRPracticeShotLift"))or 1,.45,1.75)
		local curveScale=math.clamp(tonumber(model:GetAttribute("VTRPracticeShotCurve"))or 1,.45,1.75)
		local powerVelocityScale=math.clamp(1+(practiceShotPowerScale-1)*.65,.7,1.36)
		if powerVelocityScale~=1 then velocity*=powerVelocityScale end
		if shotSpeedScale~=1 then velocity*=shotSpeedScale end
		if liftScale~=1 then velocity+=Vector3.yAxis*((liftScale-1)*22*math.clamp(amount,.2,1))end
		if curveScale~=1 then local shotFlat=flat(shotDirection);local lateralAxis=shotFlat.Magnitude>.05 and Vector3.new(-shotFlat.Z,0,shotFlat.X).Unit or Vector3.xAxis;velocity+=lateralAxis*((curveScale-1)*28*math.clamp(amount,.2,1))end
		if finesseShot then velocity=Vector3.new(velocity.X*.82,velocity.Y*.74,velocity.Z*.82)end
		if lowDrivenShot then
			local horizontal=Vector3.new(velocity.X,0,velocity.Z)
			if horizontal.Magnitude>.05 then
				local drivenSpeed=math.min(Physics.MAX_BALL_SPEED,horizontal.Magnitude*1.12+8)
				velocity=horizontal.Unit*drivenSpeed+Vector3.yAxis*math.clamp(velocity.Y*.06,0,2.2)
			end
		end
		freeKickTrajectory=model:GetAttribute("VTRFreeKickTrajectoryActive")==true
		if not executedTarget then velocity*=Physics.SHOT_MULTIPLIER end
		local effectiveShotGravity=tonumber(model:GetAttribute("VTRFreeKickEffectiveGravity")) or TARGETED_SHOT_GRAVITY
		self.ShotPlan=executedTarget and{Target=executedTarget,IntendedTarget=targetPoint,Started=os.clock(),EffectiveGravity=effectiveShotGravity,Charge=amount,RawCharge=rawShotPower,PenaltySlot=penaltySlot~=""and penaltySlot or nil,PenaltyMissHigh=model:GetAttribute("VTRPenaltyMissHigh")==true}or nil
		if freeKickTrajectory and self.ShotPlan and self.PendingFreeKickTrajectory then
			self.ShotPlan.FreeKickTrajectory = self.PendingFreeKickTrajectory
			self.ShotPlan.EffectiveGravity = self.PendingFreeKickTrajectory.Gravity or effectiveShotGravity
			self.ShotPlan.Target = self.PendingFreeKickTrajectory.Target or targetPoint
			executedTarget = self.ShotPlan.Target
		end
		self.PendingFreeKickTrajectory = nil
		local horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z)
		local horizontalDistance=executedTarget and Vector3.new(executedTarget.X-self.Ball.Position.X,0,executedTarget.Z-self.Ball.Position.Z).Magnitude or 65
		local flightTime=tonumber(model:GetAttribute("VTRFreeKickFlightTime")) or horizontalDistance/math.max(horizontalVelocity.Magnitude,1)
		if executedTarget then
			self.Ball:SetAttribute("VTRShotTarget", executedTarget)
		else
			self.Ball:SetAttribute("VTRShotTarget", nil)
		end
		model:SetAttribute("VTRFinesseShot",finesseShot or nil)
		if not freeKickTrajectory then
			velocity+=self.Curve:StartShot(model,shotDirection,flightTime,executedTarget)
		else
			self.Curve:Stop()
		end
		if velocity.Magnitude > Physics.MAX_BALL_SPEED then velocity = velocity.Unit * Physics.MAX_BALL_SPEED end
		model:SetAttribute("VTRFreeKickTrajectoryActive",nil)
		model:SetAttribute("VTRFreeKickEffectiveGravity",nil)
		model:SetAttribute("VTRFinesseShot",nil)
		model:SetAttribute("VTRShotVariant",nil)
		model:SetAttribute("VTRShotFoot",nil)
		local shotRoot=self:_root(model)
		local shotDistance = 190
		if shotRoot and executedTarget then
			shotDistance = Vector3.new(shotRoot.Position.X - executedTarget.X, 0, shotRoot.Position.Z - executedTarget.Z).Magnitude
		elseif shotRoot then
			shotDistance = direction.Magnitude
		end
		local shooting = shotStat(model, "SHO", "Shooting", 60)
		local composure = shotStat(model, "Composure", nil, shooting)
		local powerQuality = execution and execution.PowerQuality or math.clamp(1 - math.abs(amount - 0.68) / 0.42, 0, 1)
		local goalChance = shotType == "Penalty" and self.Stats:CalculateXG(model,shotRoot and shotRoot.Position or self.Ball.Position,self:_pressure(model),shotType) or execution and execution.Quality or math.clamp(0.18 + shooting / 260 + composure / 520 + amount * 0.16 - self:_pressure(model) * 0.22, 0.05, 0.82)
		if overhit > 0 then
			goalChance *= math.clamp(1 - overhit * .82, .08, 1)
		end
		local shotChance = shotType == "Penalty" and goalChance or math.clamp(goalChance, 0.05, 0.98)
		if (tonumber(model:GetAttribute("VTRFreeKickGoalChanceUntil")) or 0) >= os.clock() then
			goalChance = math.clamp(tonumber(model:GetAttribute("VTRFreeKickGoalChance")) or .3, 0, 1)
			shotChance = math.clamp(goalChance, 0.05, 0.98)
		end
		goalChance = math.clamp(goalChance, 0, 1)
		shotChance = math.clamp(shotChance, .05, .95)
		model:SetAttribute("VTRLastShotScoringChance",shotChance)
		model:SetAttribute("VTRLastShotScoringPercent",math.floor(shotChance*100+.5))
		model:SetAttribute("VTRShotDistanceStuds",shotDistance)
		model:SetAttribute("VTRShotPowerQuality",powerQuality)
		model:SetAttribute("VTRShotPressure",execution and execution.Pressure or self:_pressure(model))
		model:SetAttribute("VTRShotSpeed",velocity.Magnitude)
		model:SetAttribute("VTRShotTravelTime",flightTime)
		self.LastShotChance=shotChance
		self.LastShotChancePercent=math.floor(shotChance*100+.5)
		self.LastShotXG=shotChance
		local shotOnTarget=executedTarget~=nil
		if self.ShotPlan then
			self.ShotPlan.Quality=shotChance
			self.ShotPlan.AimClean=execution and execution.AimClean or nil
			self.ShotPlan.PowerQuality=powerQuality
			self.ShotPlan.PowerError=execution and execution.PowerError or nil
			self.ShotPlan.Pressure=execution and execution.Pressure or self:_pressure(model)
			self.ShotPlan.Speed=velocity.Magnitude
			self.ShotPlan.TravelTime=flightTime
			self.ShotPlan.ShotType=shotType
		end
		self.LastShooter=model
		self.Stats:RecordShot(model,shotOnTarget,shotChance)
	elseif kind == "Skill" then
		self.Ball:SetAttribute("VTRPassStartedAt", nil)
		self.Ball:SetAttribute("VTRPassTeam", nil)
		self.Ball:SetAttribute("VTRPassReceiver", nil)
		self:_clearOffsideSnapshot()
		velocity = (flat(direction) + Vector3.new(0, 0.1, 0)).Unit * Config.Ball.SkillTouchSpeed
	else
		return false
	end
	if velocity.Magnitude > Physics.MAX_BALL_SPEED then
		velocity = velocity.Unit * Physics.MAX_BALL_SPEED
	end
	self:_touch(model)
	if self.Animations then
		if kind=="Shot" and model:GetAttribute("VTRSuppressNextShotAnimation")==true then
			model:SetAttribute("VTRSuppressNextShotAnimation",nil)
		else
			self.Animations:PlayAction(model,kind=="Shot"and tostring(model:GetAttribute("VTRShotAnimation")or"Shoot")or kind)
		end
	end
	self.MotionKind = kind
	self.MotionStarted = os.clock()
	self.Ball:SetAttribute("VTRMotionKind",kind)
	self.Possession:Release(velocity, kind == "Shot" and 0.55 or 0.25)
	if kind == "Pass" and self.PendingCurve then self.Curve:Start(self.PendingCurve.Model,self.PendingCurve.Direction,self.PendingCurve.Speed,self.PendingCurve.Distance);self.PendingCurve=nil elseif not (kind=="Pass" and self.PassCurveStarted==true) and (kind=="Pass"or kind~="Shot")then self.Curve:Stop()end;self.PassCurveStarted=nil
	local eventPayload={Type=kind,Actor=model,Receiver=receiver,Charge=amount}
	if kind=="Shot"then
		eventPayload.ShotVariant=shotVariant
		eventPayload.ScoringChance=self.LastShotChance
		eventPayload.ScoringChancePercent=self.LastShotChancePercent
		eventPayload.ShotXG=self.LastShotChance
		eventPayload.StatsXG=self.LastShotChance
		eventPayload.ShotQuality=self.LastShotChance
		eventPayload.PowerQuality=self.ShotPlan and self.ShotPlan.PowerQuality or nil
		eventPayload.ShotPressure=self.ShotPlan and self.ShotPlan.Pressure or nil
		eventPayload.ShotSpeed=self.ShotPlan and self.ShotPlan.Speed or nil
		eventPayload.ShotTravelTime=self.ShotPlan and self.ShotPlan.TravelTime or nil
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
	if model:GetAttribute("VTRGoalkeeperHolding")==true then self:ClearGoalkeeperHoldState(model)end
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
	self.Ball:SetAttribute("VTRShotTarget",nil)
	self.Ball:SetAttribute("VTRPassStartedAt", nil)
	self.Ball:SetAttribute("VTRPassTeam", nil)
	self.Ball:SetAttribute("VTRPassReceiver", nil)
	self:_touch(model);self.MotionKind="Clearance";self.MotionStarted=os.clock();self.Ball:SetAttribute("VTRMotionKind","Clearance");self.Stats:Event(model,"Clearance");if self.Animations then self.Animations:PlayAction(model,"Shoot")end;self.Possession:Release(velocity,.4);self.Remote:FireAllClients({Type="Clearance",Actor=model,Target=destination});return true
end

function Service:LowClearance(model:Model,fieldDirection:Vector3?,charge:number?):boolean
	if self.Possession:GetOwner()~=model or not self:_allowed(model,"Pass")then return false end
	if model:GetAttribute("VTRGoalkeeperHolding")==true then self:ClearGoalkeeperHoldState(model)end
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
	self.Ball:SetAttribute("VTRShotTarget",nil)
	self.Ball:SetAttribute("VTRPassStartedAt", nil)
	self.Ball:SetAttribute("VTRPassTeam", nil)
	self.Ball:SetAttribute("VTRPassReceiver", nil)
	self:_touch(model);self.MotionKind="Clearance";self.MotionStarted=os.clock();self.Ball:SetAttribute("VTRMotionKind","Clearance");self.Stats:Event(model,"Clearance");if self.Animations then self.Animations:PlayAction(model,"Shoot")end;self.Possession:Release(velocity,.35);self.Remote:FireAllClients({Type="Clearance",Actor=model,Target=self.PassTargetPoint});return true
end

function Service:Tackle(model: Model,slide:boolean?): boolean
	if not self:_allowed(model, "Tackle") then
		return false
	end
	local action=slide and"SlideTackle"or"Tackle"
	if self.Animations then self.Animations:PlayAction(model,action)end
	local owner = self.Possession:GetOwner()
	local modelRoot = self:_root(model)
	local ownerRoot = owner and self:_root(owner)
	if not owner or owner == model or not modelRoot or not ownerRoot then
		return false
	end
	local rootDistance=(modelRoot.Position-ownerRoot.Position).Magnitude
	local ballDistance=(modelRoot.Position-self.Ball.Position).Magnitude
	local ownerSpeed=Vector3.new(ownerRoot.AssemblyLinearVelocity.X,0,ownerRoot.AssemblyLinearVelocity.Z).Magnitude
	local range=(Config.Ball.TackleRange or 7)+(slide and 2.4 or 2.1)+(ownerSpeed<2 and 2.2 or 0)
	if rootDistance>range and ballDistance>range+1.8 then
		return false
	end
	local ownerFacing=flat(ownerRoot.CFrame.LookVector)
	local toTackler=flat(modelRoot.Position-ownerRoot.Position)
	local angleDot=ownerFacing:Dot(toTackler)
	local approach=angleDot>.35 and"Front"or angleDot<-.35 and"Behind"or"Side"
	local now=os.clock()
	local duringSkill=(tonumber(owner:GetAttribute("VTRDribbleMoveUntil"))or 0)>now
	local vulnerable=(tonumber(owner:GetAttribute("VTRPostSkillVulnerableUntil"))or 0)>now and not duringSkill
	local foulChance=approach=="Behind"and.8 or approach=="Side"and.4 or 0
	local forceCard=false
	local redChance:number?=nil
	if self.Referee and self.Referee.IsPenaltyFoul and self.Referee:IsPenaltyFoul(model, owner, ownerRoot.Position) then
		foulChance = math.max(foulChance, slide and 1 or .85)
	end
	if slide then
		foulChance=approach=="Behind"and 1 or approach=="Side"and.4 or.12
		if duringSkill then foulChance=1 end
		if approach=="Behind"then forceCard=true;redChance=.08 end
	end
	if vulnerable and approach~="Behind"then foulChance=0 end
	if not self:_canAutoFoul(model,owner)then foulChance=0 end
	if foulChance>0 and self.Random:NextNumber()<foulChance and self.Referee then
		self.Stats:RecordTackle(model,false)
		owner:SetAttribute("VTRStunnedUntil",math.max(tonumber(owner:GetAttribute("VTRStunnedUntil"))or 0,now+1.0))
		owner:SetAttribute("VTRCannotRecoverBallUntil",math.max(tonumber(owner:GetAttribute("VTRCannotRecoverBallUntil"))or 0,now+1.0))
		self.Referee:CallFoul(model,owner,slide and"Slide Tackle"or"Standing Tackle",ownerRoot.Position,forceCard,redChance)
		return false
	end
	local tackleStat=math.clamp(tonumber(model:GetAttribute(slide and"SlidingTackle"or"StandingTackle"))or tonumber(model:GetAttribute("DEF"))or 55,1,99)
	local dribbling=math.clamp(tonumber(owner:GetAttribute("Dribbling"))or tonumber(owner:GetAttribute("DRI"))or 55,1,99)
	local disparity=dribbling-tackleStat
	local chance=disparity<=10 and 1 or disparity<=30 and(1-(disparity-10)/20*.5)or 0
	if ownerSpeed<2 then chance=math.max(chance,.92)end
	if ballDistance<=range*.72 then chance=math.max(chance,.96)end
	if duringSkill then chance=.1 elseif vulnerable and approach~="Behind"then chance=1 end
	if self.Random:NextNumber() > chance then
		self.Stats:RecordTackle(model,false)
		self.Possession:Block(model, 0.35)
		owner:SetAttribute("VTRStunnedUntil",math.max(tonumber(owner:GetAttribute("VTRStunnedUntil"))or 0,now+1.0))
		owner:SetAttribute("VTRCannotRecoverBallUntil",math.max(tonumber(owner:GetAttribute("VTRCannotRecoverBallUntil"))or 0,now+1.0))
		return false
	end
	self.Stats:RecordTackle(model,true)
	self.Stats:Event(owner,"PossessionLost")
	if slide then model:SetAttribute("VTRSlideTackleLockUntil", now + 0.95) end
	self:_touch(model)
	self.MotionKind = "Tackle"
	self.MotionStarted = os.clock()
	if owner:GetAttribute("VTRGoalkeeperHolding")==true then self:ClearGoalkeeperHoldState(owner)end
	self.Possession:ForcePickup(model)
	model:SetAttribute("VTRNoAutoPassUntil",now+1)
	self.Possession:Block(owner,slide and 1.5 or 1.0)
	owner:SetAttribute("VTRStunnedUntil",now+(slide and 1.5 or 1.0))
	owner:SetAttribute("VTRCannotRecoverBallUntil",now+(slide and 1.5 or 1.0))
	local ownerHumanoid=owner:FindFirstChildOfClass("Humanoid")
	if ownerHumanoid then ownerHumanoid:Move(Vector3.zero,false)end
	self.Remote:FireAllClients({Type = slide and"SlideTackle"or"Tackle", Actor = model,Victim=owner})
	return true
end

function Service:_applyLoosePhysics(dt: number)
	local velocity = self.Ball.AssemblyLinearVelocity
	local shotPlan=self.ShotPlan
	local passPlan=self.PassPlan
	if shotPlan and os.clock()-shotPlan.Started<2.5 then
		velocity+=Vector3.yAxis*math.max(0,workspace.Gravity-shotPlan.EffectiveGravity)*dt
		if shotPlan.FreeKickTrajectory then
			velocity += shotPlan.FreeKickTrajectory.Lateral * shotPlan.FreeKickTrajectory.Strength * dt
		end
		local toTarget=shotPlan.Target-self.Ball.Position
		local horizontalVelocity=VTRShotPowerModel.ApplyToVelocity(Vector3.new(velocity.X,0,velocity.Z), vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
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
		if math.abs(velocity.Y)<3.2 then
			velocity=Vector3.new(velocity.X,0,velocity.Z)
		elseif velocity.Y<0 and math.abs(velocity.Y)<9 then
			velocity=Vector3.new(velocity.X,velocity.Y*.22,velocity.Z)
		end
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
	self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.new(horizontal.X, velocity.Y, horizontal.Z), vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	if passTravel and self.PassTargetPoint then
		local remaining = (Vector3.new(self.PassTargetPoint.X, 0, self.PassTargetPoint.Z) - Vector3.new(self.Ball.Position.X, 0, self.Ball.Position.Z)).Magnitude
		if remaining > 5 and horizontal.Magnitude > 0.1 and horizontal.Magnitude < 14 then
			self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.new(horizontal.Unit.X * 14, velocity.Y, horizontal.Unit.Z * 14), vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
		end
	end
	local angularDecay = math.exp(-Physics.ANGULAR_DAMPING * dt)
	self.Ball.AssemblyAngularVelocity *= angularDecay
	if self.Ball.AssemblyLinearVelocity.Magnitude > Physics.MAX_BALL_SPEED then
		self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(self.Ball.AssemblyLinearVelocity.Unit * Physics.MAX_BALL_SPEED, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	end
end

function Service:Step(dt: number)
	if self.Ball:GetAttribute("VTRWorldPaused")==true then return end
	local owner = self.Possession:GetOwner()
	self:_guardGoalkeeperHold(owner)
	if owner then
		self.Ball:SetAttribute("VTRMotionKind","Dribble")
		clearFlightAttributes(self.Ball)
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
		local distance = Scaling.TouchDistance(tonumber(owner:GetAttribute("DRI")) or 60, sprinting) * (closeControl and 0.48 or 0.78)
		local movement = owner:GetAttribute("VTRMoveDirection")
		local touchDirection = typeof(movement) == "Vector3" and movement.Magnitude > 0.1 and movement.Unit or flat(ownerRoot.CFrame.LookVector)
		local ownerVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.new(ownerRoot.AssemblyLinearVelocity.X, 0, ownerRoot.AssemblyLinearVelocity.Z), vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
		local now = os.clock()
		if self.DribbleTouchOwner ~= owner then
			self.DribbleTouchOwner = owner
			self.NextDribbleTouchAt = now + 0.12
			self.DribbleTouchBoostUntil = nil
		end
		local movingForward = ownerVelocity.Magnitude > 2.5 and ownerVelocity.Unit:Dot(touchDirection) > 0.25
		if movingForward and now >= (tonumber(self.NextDribbleTouchAt) or 0) then
			self.NextDribbleTouchAt = now + 0.5
			self.DribbleTouchBoostUntil = now + 0.16
		elseif not movingForward then
			self.NextDribbleTouchAt = now + 0.18
			self.DribbleTouchBoostUntil = nil
		end
		local touchPulse = 0
		local boostUntil = tonumber(self.DribbleTouchBoostUntil) or 0
		if boostUntil > now then
			local alpha = math.clamp((boostUntil - now) / 0.16, 0, 1)
			touchPulse = (sprinting and 2.35 or 1.75) * alpha
		end
		local lead = ownerVelocity.Magnitude > 6 and ownerVelocity.Unit:Dot(touchDirection) > 0.35 and math.clamp(ownerVelocity.Magnitude * 0.026, 0, sprinting and 0.65 or 0.36) or 0
		local target = ownerRoot.Position + touchDirection * (distance + lead + touchPulse) - Vector3.new(0, Config.Ball.DribbleVerticalOffset, 0)
		if typeof(target) == "Vector3" then
			target = VTRShotPowerModel.ApplyToTarget(self.Ball.Position, target, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
		end
		target = keepDribbleTargetAtFeet(self.Ball, self.Raycast, ownerRoot, target, touchDirection)
		local currentPosition = self.Ball.Position
		local targetOffset = target - currentPosition
		local targetHorizontal = Vector3.new(targetOffset.X, 0, targetOffset.Z)
		if targetHorizontal.Magnitude < 18 then
			local stableTarget = Vector3.new(target.X, math.min(target.Y, ownerRoot.Position.Y - 0.35), target.Z)
			self.Ball.CFrame = CFrame.new(stableTarget)
		end
		local desired = ownerVelocity + touchDirection * (touchPulse > 0 and (sprinting and 18 or 13) or 0)
		if desired.Magnitude > Config.Ball.MaxDribbleSpeed then
			desired = desired.Unit * Config.Ball.MaxDribbleSpeed
		end
		self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.new(desired.X, 0, desired.Z), vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
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
	if self.MotionKind == "Pass" and self.ExpectedReceiver and self.ExpectedReceiver.Parent and self.ExpectedReceiver:GetAttribute("VTRManualReceiveOverride") ~= true then
		local receiverRoot = self:_root(self.ExpectedReceiver)
		local humanoid = self.ExpectedReceiver:FindFirstChildOfClass("Humanoid")
		if receiverRoot and humanoid and humanoid.Health > 0 and self.Possession:GetOwner() == nil then
			local receiverIsGoalkeeper = tostring(self.ExpectedReceiver:GetAttribute("position") or "") == "GK"
			local ballVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.new(self.Ball.AssemblyLinearVelocity.X, 0, self.Ball.AssemblyLinearVelocity.Z), vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
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
			if canGuidePass and not receiverIsGoalkeeper and not self.Possession:CanPickup(self.ExpectedReceiver) and ballVelocity.Magnitude > 1 then
				local carryDirection = ballVelocity.Unit
				local receiverVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.new(receiverRoot.AssemblyLinearVelocity.X, 0, receiverRoot.AssemblyLinearVelocity.Z), vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
				local desiredDirection = receiverVelocity.Magnitude > 1.5 and receiverVelocity.Unit or carryDirection
				local frontPoint = receiverRoot.Position + desiredDirection * 2.6 + Vector3.new(0, -1.45, 0)
				local toFront = frontPoint - self.Ball.Position
				local guide = toFront.Magnitude > 0.05 and toFront.Unit * math.min(toFront.Magnitude * 5.5, 18) or Vector3.zero
				self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(ballVelocity * 0.72 + guide, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
			end
			local canTrapPass = not receiverIsGoalkeeper and canGuidePass and distanceToBall <= (Config.Ball.PossessionRange + 1.35) and pathDistance <= 4.75
			if self.Possession:CanPickup(self.ExpectedReceiver) or canTrapPass then
				self.Possession:ForcePickup(self.ExpectedReceiver)
				if ballVelocity.Magnitude > 1 then
					local carryDirection = ballVelocity.Unit
					local receiverVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.new(receiverRoot.AssemblyLinearVelocity.X, 0, receiverRoot.AssemblyLinearVelocity.Z), vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
					local desiredDirection = receiverVelocity.Magnitude > 1.5 and receiverVelocity.Unit or carryDirection
					self.ExpectedReceiver:SetAttribute("VTRMoveDirection", carryDirection)
					local frontPoint = receiverRoot.Position + desiredDirection * 2.6 + Vector3.new(0, -1.45, 0)
					local toFront = frontPoint - self.Ball.Position
					local guide = toFront.Magnitude > 0.05 and toFront.Unit * math.min(toFront.Magnitude * 10, 28) or Vector3.zero
					self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(receiverVelocity * 0.55 + guide + desiredDirection * 7, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
				else
					local forward = Vector3.new(receiverRoot.CFrame.LookVector.X, 0, receiverRoot.CFrame.LookVector.Z)
					if forward.Magnitude < 0.05 then forward = Vector3.zAxis end
					self.Ball.AssemblyLinearVelocity = VTRShotPowerModel.ApplyToVelocity(forward.Unit * 8, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
				end
				self.Ball.AssemblyAngularVelocity = VTRShotPowerModel.ApplyToVelocity(Vector3.zero, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
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
		local previousTeam=tostring(self.Ball:GetAttribute("VTRLastPossessionTeam") or "")
		local pickupReason="LooseRecovery"
		if self.LastPassTeam then
			if self.LastPassTeam==team then
				pickupReason=forcedReceiverPickup and "PassReceived" or "TeamPassRecovered"
			else
				pickupReason="Turnover"
			end
		elseif previousTeam~="" and previousTeam~=team then
			pickupReason="Turnover"
		end
		self.Ball:SetAttribute("VTRLastPossessionTeam",team)
		self.Remote:FireAllClients({Type="PossessionContext",Owner=nearest:GetAttribute("DisplayName")or nearest.Name,Model=nearest,Team=team,Reason=pickupReason})
		if self.LastPassTeam==team and self.Offside and self:_isOffsideCandidate(nearest) then
			self.Offside:Call(nearest)
			self:_clearOffsideSnapshot()
			self.LastPassTeam=nil;self.LastPasser=nil;self.LastPassOrigin=nil;self.ExpectedReceiver=nil;self.PassPlan=nil
			clearFlightAttributes(self.Ball);self.Ball:SetAttribute("VTRPassStartedAt",nil);self.Ball:SetAttribute("VTRPassTeam",nil);self.Ball:SetAttribute("VTRPassReceiver",nil)
			return
		end
		if self.LastPassTeam then
			if self.LastPassTeam==team and self.LastPasser then
				self.Stats:RecordPassCompleted(self.LastPasser,nearest,self.LastPassOrigin,self.Ball.Position)
				if AIPassingDecisionService.RecordPassOutcome then AIPassingDecisionService.RecordPassOutcome(self.LastPasser,nearest,true) end
			elseif self.LastPasser then
				self.Stats:RecordPassFailed(self.LastPasser,nearest)
				if AIPassingDecisionService.RecordPassOutcome then AIPassingDecisionService.RecordPassOutcome(self.LastPasser,nearest,false) end
			end
		end
		local receivedPassAsGoalkeeper = self.MotionKind=="Pass" and tostring(nearest:GetAttribute("position") or "")=="GK"
		self.LastPassTeam = nil
		self.LastPasser=nil;self.LastPassOrigin=nil
		self.ExpectedReceiver = nil
		self:_clearOffsideSnapshot()
		self.PassPlan=nil
		clearFlightAttributes(self.Ball)
		self.Ball:SetAttribute("VTRPassStartedAt", nil)
		self.Ball:SetAttribute("VTRPassTeam", nil)
		self.Ball:SetAttribute("VTRPassReceiver", nil)
		self:_touch(nearest)
		if receivedPassAsGoalkeeper then
			self.Ball:SetAttribute("VTRGoalkeeperHeld", nil)
			nearest:SetAttribute("VTRGoalkeeperHolding", nil)
			nearest:SetAttribute("VTRGoalkeeperHoldingSince", nil)
			self:ReleaseGoalkeeperHold(nearest)
		end
		if self.CornerPlan and nearest:GetAttribute("VTRTeam")==self.CornerPlan.Team then self.Stats:Add(self.CornerPlan.Team,"CornerReachedTeammate");self.Remote:FireAllClients({Type="CornerObjective",Event="cornerReachedTeammate",Team=self.CornerPlan.Team});self.CornerPlan=nil end
	end
end

return Service
