--!strict
local function vtrLoadShotPowerModel()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local vtr = ReplicatedStorage:FindFirstChild("VTR")
	local shared = (vtr and vtr:FindFirstChild("Shared")) or ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage
	return require(shared:WaitForChild("ShotPowerModel"))
end

local VTRShotPowerModel = vtrLoadShotPowerModel()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PassFlightModel = require(ReplicatedStorage.VTR.Shared.PassFlightModel)
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local Physics = require(ReplicatedStorage.VTR.Shared.BallPhysicsConfig)
local PassingPower = require(ReplicatedStorage.VTR.Shared.PassingPowerConfig)
local Scaling = require(ReplicatedStorage.VTR.Shared.StatScalingConfig)
local BallCurveService = require(script.Parent.BallCurveService)
local PassArrivalPlanner = require(script.Parent.PassArrivalPlanner)
local PassInterceptService = require(script.Parent.PassInterceptService)
local FreeKickTrajectory = require(ReplicatedStorage.VTR.Shared.FreeKickTrajectory)
local AIPassingDecisionService = require(script.Parent.AIPassingDecisionService)
local BallTrajectory = require(ReplicatedStorage.VTR.Shared.BallTrajectory)
local BallContactResolver = require(ReplicatedStorage.VTR.Shared.BallContactResolver)
local TackleResolver = require(ReplicatedStorage.VTR.Shared.TackleResolver)
local DribbleTargetResolver = require(ReplicatedStorage.VTR.Shared.DribbleTargetResolver)

local Service = {}
Service.__index = Service
local TARGETED_SHOT_GRAVITY=29.5
local OFFSIDE_EXEMPT_RESTARTS={Corner=true,ThrowIn=true,GoalKick=true}
local ballisticVelocity: (Vector3, Vector3, number, number?) -> Vector3?

local function flat(vector: Vector3): Vector3
	local value = Vector3.new(vector.X, 0, vector.Z)
	return value.Magnitude > 0.01 and value.Unit or Vector3.zAxis
end

local contactPartKinds = {
	{"LeftFoot", "LeftFoot"},
	{"RightFoot", "RightFoot"},
	{"LeftLowerLeg", "LeftFoot"},
	{"RightLowerLeg", "RightFoot"},
	{"Left Leg", "LeftFoot"},
	{"Right Leg", "RightFoot"},
	{"LeftUpperLeg", "Thigh"},
	{"RightUpperLeg", "Thigh"},
	{"LowerTorso", "Thigh"},
	{"UpperTorso", "Chest"},
	{"Torso", "Chest"},
	{"Head", "Header"},
}

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
	ball:SetAttribute("VTRLobLanded", nil)
	ball:SetAttribute("VTRPassTarget", nil)
	ball:SetAttribute("VTRShotTarget", nil)
end

local function isGoalDetectorPart(instance: Instance?): boolean
	local current = instance
	while current do
		if current:GetAttribute("VTRGoalDetector") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isGoalNetOrBackstop(instance: Instance?): boolean
	local current = instance
	while current do
		local name = string.lower(current.Name)
		if string.find(name, "goalnet", 1, true) or string.find(name, "net", 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
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
		part.AssemblyLinearVelocity = part.AssemblyLinearVelocity.Unit * maxLinear
	end
	if part.AssemblyAngularVelocity.Magnitude > maxAngular then
		part.AssemblyAngularVelocity = part.AssemblyAngularVelocity.Unit * maxAngular
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
	return setmetatable({Ball = ball, Possession = possession, Remote = remote, Stats = stats, Models = models, Animations=animations, Last = {}, Accumulator = 0, LastContactBallPosition = ball.Position, Raycast = raycast, Random = Random.new(), Curve = BallCurveService.new(ball), LastTouchPlayer = nil, LastTouchTeam = nil, MotionKind = "Loose", MotionStarted = 0, DribbleVelocity = Vector3.zero, TrajectorySequence = 0, PassSequence = 0, PendingTackles = {}, PositionHistory={},HistoryAccumulator=0,LastHardCorrectionAt = 0, LastLooseContactAt = 0, Telemetry = nil, TelemetryAt = {}, PassReception = nil, ContactPartCache = {}}, Service)
end

function Service:_recordPositionHistory(dt:number)
	self.HistoryAccumulator=(tonumber(self.HistoryAccumulator)or 0)+dt
	if self.HistoryAccumulator<1/30 then return end
	self.HistoryAccumulator=0
	local models:any={}
	for _,model in self.Models do
		local modelRoot=self:_root(model)
		if modelRoot then models[model]={Position=modelRoot.Position,Facing=modelRoot.CFrame.LookVector}end
	end
	table.insert(self.PositionHistory,{Time=workspace:GetServerTimeNow(),Ball=self.Ball.Position,Models=models})
	local cutoff=workspace:GetServerTimeNow()-.55
	while self.PositionHistory[1]and self.PositionHistory[1].Time<cutoff do table.remove(self.PositionHistory,1)end
end

function Service:_historyAt(clientTime:any):any?
	local now=workspace:GetServerTimeNow()
	local target=math.clamp(tonumber(clientTime)or now,now-.32,now)
	local best=nil
	local bestDistance=math.huge
	for _,snapshot in self.PositionHistory do
		local distance=math.abs(snapshot.Time-target)
		if distance<bestDistance then best=snapshot;bestDistance=distance end
	end
	return best
end

function Service:SetPassReceptionService(service: any?)
	self.PassReception = service
end

function Service:SetTelemetry(callback: any)
	self.Telemetry = callback
end

function Service:_primePassReceiver(passer: Model, receiver: Model?, target: Vector3?, eta: number?, duration: number?, passType: string?)
	if not receiver or not receiver.Parent or typeof(target) ~= "Vector3" then return end
	if receiver:GetAttribute("VTRTeam") ~= passer:GetAttribute("VTRTeam") then return end
	local receiverRoot = self:_root(receiver)
	local distance = receiverRoot and (Vector3.new(target.X, receiverRoot.Position.Y, target.Z) - receiverRoot.Position).Magnitude or 0
	local now = os.clock()
	local ballETA = math.max(0.05, tonumber(eta) or distance / 52)
	local receiveUntil = now + math.clamp(tonumber(duration) or ballETA + 1.35, 1.1, 5.5)
	local arrival = PassArrivalPlanner.Solve({ReceiverModel = receiver, Target = target, BallETA = ballETA, PassFamily = passType or "Ground", BallPosition = self.Ball.Position})
	local passFamily = tostring(passType or "Ground")
	local forcedAirRoute = passFamily == "Lofted" or passFamily == "Lob" or passFamily == "FarPostCross" or passFamily == "Cross" or receiver:GetAttribute("VTRSetPieceReceiver") == true
	local sprint = forcedAirRoute or arrival and arrival.SelectedLocomotionMode == "SprintBurst" or false
	receiver:SetAttribute("VTRReceiveTarget", target)
	receiver:SetAttribute("VTRReceiveIntercept", arrival and arrival.InterceptPoint or target)
	receiver:SetAttribute("VTRReceiveUntil", receiveUntil)
	receiver:SetAttribute("VTRReceiveBallETA", ballETA)
	receiver:SetAttribute("VTRReceiveReceiverETA", arrival and arrival.SelectedMovementETA or distance / 26)
	receiver:SetAttribute("VTRReceiveOpponentETA", math.huge)
	receiver:SetAttribute("VTRReceiveRouteConfidence", forcedAirRoute and .96 or arrival and arrival.ExpectedContactQuality or .86)
	receiver:SetAttribute("VTRReceiveTrajectoryConfidence", .72)
	receiver:SetAttribute("VTRReceiveRouteSprintRequested", sprint)
	receiver:SetAttribute("VTRReceiveDistance", distance)
	receiver:SetAttribute("VTRReceiveLocomotionMode", sprint and "SprintBurst" or arrival and arrival.SelectedLocomotionMode or "Run")
	receiver:SetAttribute("VTRReceivePassFamily", passFamily)
	receiver:SetAttribute("VTRReceiveDesiredArrivalVelocity", arrival and arrival.DesiredArrivalVelocity or nil)
	receiver:SetAttribute("VTRReceiveBrakingDistance", arrival and arrival.BrakingDistance or nil)
	receiver:SetAttribute("VTRReceiveContactKind", forcedAirRoute and "Aerial" or arrival and arrival.ContactKind or nil)
	receiver:SetAttribute("VTRReceivePreferredFoot", arrival and arrival.PreferredFoot or nil)
	receiver:SetAttribute("VTRFirstTouchIntent", forcedAirRoute and "Secure" or arrival and arrival.FirstTouchIntent or nil)
	receiver:SetAttribute("VTRPreparingReceive", true)
	receiver:SetAttribute("VTRReceiveCommitted", true)
	receiver:SetAttribute("VTRReceiveLockedAt", now)
	receiver:SetAttribute("VTRReceiveHardLock", true)
	receiver:SetAttribute("VTRReceiveHardLockUntil", receiveUntil)
	receiver:SetAttribute("VTRForcedPassReceiver", true)
	receiver:SetAttribute("VTRForcedReceiveUntil", receiveUntil)
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

function Service:_closestPassReceiverToTarget(passer: Model, target: Vector3, current: Model?): Model?
	local team = tostring(passer:GetAttribute("VTRTeam") or "")
	local best = nil
	local bestDistance = math.huge
	for _, candidate in self.Models do
		if candidate ~= passer and candidate:GetAttribute("VTRTeam") == team and candidate:GetAttribute("VTRSentOff") ~= true then
			local candidateRoot = self:_root(candidate)
			local humanoid = candidate:FindFirstChildOfClass("Humanoid")
			if candidateRoot and humanoid and humanoid.Health > 0 then
				local distance = (Vector3.new(candidateRoot.Position.X, 0, candidateRoot.Position.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
				if candidate == current then distance -= 1.5 end
				if distance < bestDistance then
					best = candidate
					bestDistance = distance
				end
			end
		end
	end
	return best or current
end

function Service:_emitTelemetry(model: Model?, eventName: string, properties: any?)
	if eventName=="playability_possession_contact"then
		local key=tostring(model and model.Name or"")..":"..tostring(properties and properties.contactOutcome or"")
		local now=os.clock();if now-(tonumber(self.TelemetryAt[key])or -math.huge)<1 then return end;self.TelemetryAt[key]=now
	end
	if self.Telemetry then self.Telemetry(model, eventName, properties or {}) end
end

function Service:_root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Service:_contactPoints(model: Model, modelRoot: BasePart): {any}
	local cache = self.ContactPartCache[model]
	if not cache then
		cache = {Entries = {}, Active = {}, Fallback = {Position = modelRoot.Position, PreviousPosition = modelRoot.Position, Kind = tostring(model:GetAttribute("PreferredFoot") or "Right") == "Left" and "LeftFoot" or "RightFoot"}}
		for _, definition in contactPartKinds do
			local part = model:FindFirstChild(definition[1])
			if part and part:IsA("BasePart") then table.insert(cache.Entries, {Part = part, Position = part.Position, Kind = definition[2]}) end
		end
		self.ContactPartCache[model] = cache
	end
	table.clear(cache.Active)
	for _, entry in cache.Entries do
		if entry.Part.Parent then
			entry.PreviousPosition = entry.Position
			entry.Position = entry.Part.Position
			table.insert(cache.Active, entry)
		end
	end
	if #cache.Active == 0 then
		cache.Fallback.PreviousPosition = cache.Fallback.Position
		cache.Fallback.Position = modelRoot.Position - modelRoot.CFrame.UpVector * 2.2 + modelRoot.CFrame.LookVector * 0.8
		table.insert(cache.Active, cache.Fallback)
	end
	return cache.Active
end

function Service:_contactCandidate(model: Model): any?
	local modelRoot = self:_root(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not modelRoot or not humanoid then return nil end
	local reception = self.PassReception and self.PassReception:GetContactTuning(model) or nil
	local ballRadius = math.max(self.Ball.Size.X * 0.5, Config.Ball.Radius or 1)
	local expected = reception and reception.Expected == true or model == self.ExpectedReceiver
	local receiveDistance = expected and (tonumber(model:GetAttribute("VTRReceiveDistance")) or 0) or 0
	local targetedAI = expected and model:GetAttribute("VTRAITargetedPass") == true
	local receiveFamily = tostring(model:GetAttribute("VTRReceivePassFamily") or model:GetAttribute("VTRPrePassFamily") or model:GetAttribute("AIDebugPassKind") or "")
	local lobbedTarget = targetedAI and (receiveFamily == "Lob" or receiveFamily == "Lofted" or receiveFamily == "ManualLobbed" or self.Ball:GetAttribute("VTRLobPassActive") == true)
	local receiveReach = reception and math.clamp((reception.Tolerance or 2.65) + math.clamp(receiveDistance / 30, 0, targetedAI and (lobbedTarget and 2.65 or 1.9) or 1.25), 2.4, targetedAI and (lobbedTarget and 7.2 or 5.65) or 4.85) or nil
	local controlHeight = reception and reception.ControlHeight or tostring(model:GetAttribute("position") or "") == "GK" and 3 or 2.15
	if lobbedTarget then
		controlHeight = math.max(controlHeight, 7.4)
	end
	return {
		Model = model,
		Key = model.Name,
		RootPosition = modelRoot.Position,
		RootVelocity = modelRoot.AssemblyLinearVelocity,
		Facing = modelRoot.CFrame.LookVector,
		MoveDirection = model:GetAttribute("VTRMoveDirection"),
		ContactPoints = self:_contactPoints(model, modelRoot),
		Control = tonumber(model:GetAttribute("BallControl")) or tonumber(model:GetAttribute("DRI")) or 60,
		Balance = tonumber(model:GetAttribute("Balance")) or 60,
		Agility = tonumber(model:GetAttribute("Agility")) or tonumber(model:GetAttribute("DRI")) or 60,
		Strength = tonumber(model:GetAttribute("Strength")) or tonumber(model:GetAttribute("PHY")) or 60,
		PreferredFoot = tostring(model:GetAttribute("PreferredFoot") or "Right"),
		Pressure = self:_pressure(model),
		ExpectedReceiver = expected,
		TargetedAIReceiver = targetedAI,
		UserControlled = model:GetAttribute("controlledByUser") == true or model:GetAttribute("VTRUserId") ~= nil,
		CanControl = (tonumber(model:GetAttribute("VTRStunnedUntil")) or 0) <= os.clock() and (tonumber(model:GetAttribute("VTRCannotRecoverBallUntil")) or 0) <= os.clock(),
		ContactReach = receiveReach or tostring(model:GetAttribute("position") or "") == "GK" and 2.35 or 1.75,
		ControlHeight = controlHeight,
		Valid = humanoid.Health > 0 and model:GetAttribute("VTRSentOff") ~= true,
	}
end

function Service:_isTargetedLobReceiver(model: Model?): boolean
	if not model then return false end
	local family = tostring(model:GetAttribute("VTRReceivePassFamily") or model:GetAttribute("VTRPrePassFamily") or model:GetAttribute("AIDebugPassKind") or "")
	return model:GetAttribute("VTRAITargetedPass") == true
		and (family == "Lob" or family == "Lofted" or family == "ManualLobbed" or self.Ball:GetAttribute("VTRLobPassActive") == true)
end

function Service:_pressure(model:Model):number
	local modelRoot=self:_root(model);if not modelRoot then return 0 end
	local team=model:GetAttribute("VTRTeam");local pressure=0
	for _,opponent in self.Models do if opponent:GetAttribute("VTRTeam")~=team then local opponentRoot=self:_root(opponent);if opponentRoot then local distance=(opponentRoot.Position-modelRoot.Position).Magnitude;if distance<12 then pressure=math.max(pressure,1-distance/12)end end end end
	return pressure
end

function Service:_rollingBallClaimCandidate(preferred: Model?): Model?
	if self.Possession:GetOwner() ~= nil then return nil end
	local velocity = self.Ball.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if horizontalSpeed < 0.05 and tostring(self.Ball:GetAttribute("VTRMotionKind") or self.MotionKind or "") ~= "Loose" then return nil end
	local best: Model? = nil
	local bestScore = math.huge
	for _, model in self.Models do
		local assignment = tostring(model:GetAttribute("currentAssignment") or model:GetAttribute("SupportRole") or "")
		local activeChaser = assignment == "ChaseLooseBall" or assignment == "CoverLooseBall" or assignment == "ReceivePass" or model:GetAttribute("VTRPreparingReceive") == true or model:GetAttribute("VTRAITargetedPass") == true or model:GetAttribute("VTRAIAlternatePassChaser") == true
		if model == preferred then activeChaser = true end
		local looseClosePickup = tostring(self.Ball:GetAttribute("VTRMotionKind") or self.MotionKind or "") == "Loose"
		if activeChaser == false and looseClosePickup and model:GetAttribute("aiControlled") == true and model:GetAttribute("controlledByUser") ~= true then
			local root = self:_root(model)
			activeChaser = root ~= nil and (Vector3.new(self.Ball.Position.X - root.Position.X, 0, self.Ball.Position.Z - root.Position.Z).Magnitude <= 5.8)
		end
		if activeChaser and model:GetAttribute("aiControlled") == true and model:GetAttribute("controlledByUser") ~= true and (self.Possession.Blocked[model] or 0) <= os.clock() then
			local root = self:_root(model)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and model:GetAttribute("VTRSentOff") ~= true then
				local offset = self.Ball.Position - root.Position
				local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
				local vertical = math.abs(offset.Y)
				local targetedLob = self:_isTargetedLobReceiver(model)
				local projectedBall = self.Ball.Position
				if targetedLob and horizontalSpeed > 1.5 then
					local direction = Vector3.new(velocity.X, 0, velocity.Z).Unit
					projectedBall = self.Ball.Position + direction * math.clamp(horizontalSpeed * 0.28, 7, 20)
					local projectedOffset = projectedBall - root.Position
					horizontal = math.min(horizontal, Vector3.new(projectedOffset.X, 0, projectedOffset.Z).Magnitude)
				end
				local reach = targetedLob and 15.5 or model == preferred and 9.25 or 8.25
				local height = targetedLob and 8.4 or 5.4
				if horizontal <= reach and vertical <= height then
					local movingTowardBall = 0
					local move = model:GetAttribute("VTRMoveDirection")
					local toBall = Vector3.new(projectedBall.X - root.Position.X, 0, projectedBall.Z - root.Position.Z)
					if typeof(move) == "Vector3" and move.Magnitude > 0.05 and toBall.Magnitude > 0.05 then
						movingTowardBall = move.Unit:Dot(toBall.Unit)
					end
					local score = horizontal - movingTowardBall * 1.4 - (model == preferred and 2.2 or 0) - (targetedLob and 3.4 or 0)
					if score < bestScore then
						best = model
						bestScore = score
					end
				end
			end
		end
	end
	return best
end

function Service:_allowed(model: Model, action: string): boolean
	local now = os.clock()
	self.Last[model] = self.Last[model] or {}
	local cooldown = Config.Validation.ActionCooldowns[action] or 0.2
	if action == "Pass" and model:GetAttribute("aiControlled") == true and (tonumber(model:GetAttribute("AIInstantPressurePassUntil")) or 0) > now then
		cooldown = math.min(cooldown, 0.08)
	end
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

function Service:_beginBallAction(model: Model?, kind: string)
	self.ActionSequence = (tonumber(self.ActionSequence) or 0) + 1
	self.ActiveBallActionId = self.ActionSequence
	self.Ball:SetAttribute("VTRBallActionId", self.ActiveBallActionId)
	self.Ball:SetAttribute("VTRBallActionKind", kind)
	self.Ball:SetAttribute("VTRBallActionActor", model and model.Name or nil)
	self.Ball:SetAttribute("VTRBallActionStartedAt", os.clock())
	self:_cancelKinematicFlight()
	if self.Curve then self.Curve:Stop() end
	self.PendingCurve = nil
	self.PassCurveStarted = nil
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
	if self.OffsideCandidates then
		for candidate in pairs(self.OffsideCandidates) do
			if candidate and candidate.Parent then
				candidate:SetAttribute("VTRPassOffsideReceiver", nil)
				candidate:SetAttribute("VTRPassOffsideAtKick", nil)
				candidate:SetAttribute("VTRPassOffsideSnapshotAt", nil)
			end
		end
	end
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
		for candidate in pairs(candidates) do
			candidate:SetAttribute("VTRPassOffsideReceiver", true)
			candidate:SetAttribute("VTRPassOffsideAtKick", true)
			candidate:SetAttribute("VTRPassOffsideSnapshotAt", self.OffsidePassStartedAt)
		end
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

function Service:GoalkeeperSave(keeper: Model, savePoint: Vector3, forceHold: boolean?): boolean
	if self.MotionKind ~= "Shot" and self.MotionKind ~= "Deflection" then return false end
	self:_cancelKinematicFlight()
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
	if highQualityShot and forceHold ~= true then
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
	self.Ball.AssemblyLinearVelocity = Vector3.zero
	self.Ball.AssemblyAngularVelocity = Vector3.zero
	self.Ball.CanCollide=false;self.Ball.CanTouch=false;self.Ball.Massless=true
	self:_touch(keeper)
	self.Possession:ForcePickup(keeper)
	self.Remote:FireAllClients({Type="GoalkeeperSave",Actor=keeper,SavePoint=savePoint})
	return true
end

function Service:GoalkeeperClaim(keeper: Model): boolean
	local keeperRoot = self:_root(keeper)
	if not keeperRoot then return false end
	if self.PassReception then self.PassReception:Cancel("GoalkeeperClaim") end
	self:_cancelKinematicFlight()
	keeperRoot.AssemblyLinearVelocity = Vector3.zero
	keeperRoot.AssemblyAngularVelocity = Vector3.zero
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
	self.Ball.AssemblyLinearVelocity = Vector3.zero
	self.Ball.AssemblyAngularVelocity = Vector3.zero
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
	if delivery=="Short"then return self:Kick(model,"Pass",delta,power,receiver,"Ground",distance)end
	if not self:_allowed(model,"Pass")then return false end
	self:_beginBallAction(model, "Corner")
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
	self.ExpectedReceiver=receiver;self.PassTargetPoint=target;self.LastPassTeam=cornerTeam;self.LastPasser=model;self.LastPassOrigin=origin;self.Stats:RecordPassAttempt(model)
	self.CornerPlan={Team=tostring(model:GetAttribute("VTRTeam")or"Home"),Target=target,Receiver=receiver,Started=os.clock(),Entered=false}
	if self.Animations then self.Animations:PlayAction(model,"Pass")end
	self.Stats:Add(self.CornerPlan.Team,"Corners");self.Possession:Release(velocity,.4)
	if self.PassReception and receiver then self.PassSequence=(self.PassSequence or 0)+1;self.PassReception:OnPassLaunched({PassId=self.PassSequence,TrajectoryId=0,Passer=model,Receiver=receiver,PassFamily="Cross",InitialReceivePoint=landing,InitialVelocity=velocity,PassDistance=distance,InitialETA=flightTime,Duration=flightTime,Confidence=.78})end
	self.Remote:FireAllClients({Type="CornerKick",Actor=model,Delivery=delivery,Target=target,Power=power,ObjectiveEvent="cornerTaken"});return true
end

function Service:ReleaseGoalkeeperHold(keeper:Model?)
	self:_cancelKinematicFlight()
	destroyGoalkeeperCatchWelds(self.Ball)
	self.Ball:SetAttribute("VTRGoalkeeperHeld",nil)
	self.Ball.Anchored=false
	pcall(function() self.Ball:SetNetworkOwner(nil) end)
	self.Ball.CanCollide=true;self.Ball.CanTouch=true;self.Ball.Massless=false
	self.Ball.AssemblyLinearVelocity=Vector3.zero
	self.Ball.AssemblyAngularVelocity=Vector3.zero
	if keeper then
		local keeperRoot=self:_root(keeper)
		if keeperRoot then
			keeperRoot.AssemblyLinearVelocity=Vector3.zero
			keeperRoot.AssemblyAngularVelocity=Vector3.zero
			self.Ball.CFrame=CFrame.new(keeperRoot.Position+keeperRoot.CFrame.LookVector*2.2+Vector3.new(0,-1.15,0))
		end
	end
	self:ClearGoalkeeperHoldState(keeper)
end

function Service:ClearGoalkeeperHoldState(keeper:Model?)
	self:_cancelKinematicFlight()
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
				ownerRoot.AssemblyLinearVelocity=Vector3.zero
				ownerRoot.AssemblyAngularVelocity=Vector3.zero
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
		self.Ball.AssemblyLinearVelocity=Vector3.zero
		self.Ball.AssemblyAngularVelocity=Vector3.zero
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
	local modelRoot = self:_root(model)
	local facing = modelRoot and flat(modelRoot.CFrame.LookVector) or horizontal.Magnitude > 0.05 and horizontal.Unit or Vector3.zAxis
	local targetDirection = horizontal.Magnitude > 0.05 and horizontal.Unit or facing
	local facingDot = math.clamp(facing:Dot(targetDirection), -1, 1)
	local bodyPenalty = (1 - math.clamp((facingDot + 0.2) / 1.2, 0, 1)) * 0.16
	local aimClean = math.clamp(statClean - pressure * 0.2 - sprintPenalty - bodyPenalty, 0.24, 0.985)
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
	local overhit = VTRShotPowerModel.OverhitAmount(charge)
	local placement = VTRShotPowerModel.PlacementMultiplier(charge)
	local missRadius = (1 - aimClean) * (1.35 + distance * 0.018) / math.max(placement, 0.1)
	missRadius += pressure * (0.9 + distance * 0.013)
	missRadius += math.abs(powerError) * (1.0 + distance * 0.011)
	missRadius += overhit * (0.8 + distance * 0.008)
	if math.abs(powerError) <= 0.08 then
		missRadius *= 0.62
	end
	if pressure < 0.16 and powerQuality > 0.84 and aimClean > 0.76 then
		missRadius *= 0.48
	end
	local lateralError = self.Random:NextNumber(-missRadius, missRadius)
	local verticalError = self.Random:NextNumber(-missRadius * 0.34, missRadius * 0.44)
	if powerError > 0.08 then
		verticalError += (powerError - 0.08) * (3.2 + distance * 0.008)
	elseif powerError < -0.16 then
		verticalError -= (-powerError - 0.16) * (2.2 + distance * 0.01)
	end
	local target = intendedTarget + lateralAxis * lateralError + Vector3.yAxis * verticalError
	target = VTRShotPowerModel.ApplyToTarget(origin, target, charge)
	local quality = math.clamp((aimClean * 0.52 + powerQuality * 0.34 + (1 - pressure) * 0.14) * VTRShotPowerModel.ComposureMultiplier(charge), 0.05, 0.98)
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
	local powerScale = VTRShotPowerModel.SpeedScale(charge) * shotPowerScaleFor(model, shooting)
	local shotSpeed = (Config.Ball.ShotMinSpeed + (Config.Ball.ShotMaxSpeed - Config.Ball.ShotMinSpeed) * powerScale) * (0.92 + shooting / 950)
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

function Service:_flightConfig(): any
	return Config.Ball.Flight or {}
end

function Service:_trajectoryEndFor(kind: string, velocity: Vector3, targetPoint: Vector3?): Vector3
	if typeof(targetPoint) == "Vector3" then return targetPoint end
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local direction = horizontal.Magnitude > 0.05 and horizontal.Unit or flat(velocity)
	local distance = kind == "Shot" and 205 or math.clamp(velocity.Magnitude * 1.35, 35, PassingPower.MaxPassDistance)
	return self.Ball.Position + direction * distance
end

local function passTravelDuration(flight:any,distance:number,amount:number,passType:string?):number
	return PassFlightModel.Duration(flight,distance,amount,passType)
end

local function passRolloutVelocity(data:any,position:Vector3,velocity:Vector3):Vector3
	if not data or data.KickKind~="Pass"then return velocity end
	local horizontal=Vector3.new(velocity.X,0,velocity.Z)
	local target=typeof(data.End)=="Vector3"and data.End or position+horizontal
	local toTarget=Vector3.new(target.X-position.X,0,target.Z-position.Z)
	local direction=horizontal.Magnitude>.1 and horizontal.Unit or toTarget.Magnitude>.1 and toTarget.Unit or Vector3.zAxis
	local flight=data.FlightConfig or{}
	local distance=tonumber(data.PassDistance)or toTarget.Magnitude
	local alpha=math.clamp(distance/math.max(tonumber(flight.PassTravelDistanceForMax)or 160,1),0,1)
	local through=data.PassType=="Through"or data.PassType=="Manual"
	local minSpeed=through and(tonumber(flight.ThroughPassRolloutSpeedMin)or 12)or(tonumber(flight.GroundPassRolloutSpeedMin)or 8)
	local maxSpeed=through and(tonumber(flight.ThroughPassRolloutSpeedMax)or 28)or(tonumber(flight.GroundPassRolloutSpeedMax)or 22)
	local speed=minSpeed+(maxSpeed-minSpeed)*(alpha^.78)
	if data.TutorialPhysics==true then speed*=1.22 end
	return direction*speed+Vector3.new(0,math.clamp(velocity.Y,-2,1.5),0)
end

function Service:PredictPassRolloutVelocity(data: any, position: Vector3, velocity: Vector3): Vector3
	return passRolloutVelocity(data, position, velocity)
end

function Service:_groundedPassPosition(data:any,position:Vector3):Vector3
	if not data or data.KickKind~="Pass"or data.PassType=="Lofted"or data.PassType=="ManualLobbed"then return position end
	local hit=workspace:Raycast(position+Vector3.new(0,4,0),Vector3.new(0,-12,0),self.Raycast)
	if not hit or hit.Normal.Y<=0.55 then return position end
	local desired=hit.Position+hit.Normal*((Config.Ball.Radius or 1.15)+0.012)
	local maxLift=data.PassType=="Through"and .42 or .18
	if position.Y>desired.Y+maxLift then
		return Vector3.new(position.X,desired.Y+maxLift,position.Z)
	end
	if position.Y<desired.Y then
		return Vector3.new(position.X,desired.Y,position.Z)
	end
	return position
end

function Service:_buildKinematicTrajectory(model: Model, kind: string, velocity: Vector3, amount: number, passType: string?, targetPoint: Vector3?): any?
	local flight = self:_flightConfig()
	local startPosition = self.Ball.Position
	local endPosition = self:_trajectoryEndFor(kind, velocity, targetPoint)
	local distance = (Vector3.new(endPosition.X, 0, endPosition.Z) - Vector3.new(startPosition.X, 0, startPosition.Z)).Magnitude
	if distance < 1 then return nil end
	local curveAxis = nil
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = math.max(horizontalVelocity.Magnitude, 1)
	local trajectoryKind = "Straight"
	local arcHeight = 0
	local curve = 0
	local control1 = nil
	local control2 = nil
	if kind == "Pass" then
		local lofted = passType == "Lofted" or passType == "ManualLobbed"
		local driven = passType == "Through" or passType == "Manual" or amount >= (flight.DrivenPassCharge or 0.62)
		if lofted then
			speed = math.clamp(speed, flight.LoftedPassSpeedMin or 48, flight.LoftedPassSpeedMax or 92)
			arcHeight = math.clamp((flight.LoftedPassHeightMin or 10) + distance * 0.08 + amount * 13, flight.LoftedPassHeightMin or 10, flight.LoftedPassHeightMax or 34)
		elseif driven then
			speed = math.clamp(speed, flight.DrivenPassSpeedMin or 78, flight.DrivenPassSpeedMax or 136)
			arcHeight = flight.DrivenPassArcHeight or 0.42
		else
			speed = math.clamp(speed, flight.GroundPassSpeedMin or 50, flight.GroundPassSpeedMax or 120)
			arcHeight = flight.GroundPassArcHeight or 0.18
		end
	else
		local variant = tostring(model:GetAttribute("VTRShotVariant") or "Normal")
		local finesse = variant == "Finesse"
		local chip = variant == "Chip"
		if finesse then
			trajectoryKind = "Bezier"
			speed = math.clamp(speed * (flight.FinesseSpeedMultiplier or 0.82), flight.NormalShotSpeedMin or 82, (flight.NormalShotSpeedMax or 178) * 0.9)
			local flatDirection = flat(endPosition - startPosition)
			local side = tostring(model:GetAttribute("VTRShotFoot") or "Right") == "Left" and -1 or 1
			local right = Vector3.new(-flatDirection.Z, 0, flatDirection.X) * side
			curveAxis = right
			curve = math.clamp((flight.FinesseCurveMax or 32) * (0.45 + amount * 0.55), 0, flight.FinesseCurveMax or 32)
			local lift = math.clamp((flight.FinesseLiftMin or 5) + amount * 8, flight.FinesseLiftMin or 5, flight.FinesseLiftMax or 13)
			control1 = startPosition:Lerp(endPosition, 0.32) + Vector3.yAxis * lift + right * (curve * 0.55)
			control2 = startPosition:Lerp(endPosition, 0.72) + Vector3.yAxis * (lift * 0.72) + right * curve
		elseif chip then
			speed = math.clamp(speed * 0.72, flight.ChipSpeedMin or 50, flight.ChipSpeedMax or 92)
			arcHeight = math.clamp((flight.ChipHeightMin or 13) + amount * 14, flight.ChipHeightMin or 13, flight.ChipHeightMax or 30)
		else
			speed = math.clamp(speed, flight.NormalShotSpeedMin or 82, flight.NormalShotSpeedMax or 178)
			arcHeight = (flight.NormalShotArcMin or 0.6) + ((flight.NormalShotArcMax or 3.8) - (flight.NormalShotArcMin or 0.6)) * math.clamp(amount, 0, 1)
		end
	end
	local duration = kind=="Pass" and passTravelDuration(flight,distance,amount,passType) or math.clamp(distance / math.max(speed, 1), 0.12, 2.2)
	local data = BallTrajectory.Create(trajectoryKind, startPosition, endPosition, {
		Duration = duration,
		ArcHeight = arcHeight,
		Curve = trajectoryKind == "Bezier" and 0 or curve,
		CurveAxis = curveAxis,
		Control1 = control1,
		Control2 = control2,
		ArcLength = true,
		Samples = flight.LookupSamples or 40,
		ReleaseVelocityMultiplier = flight.ReleaseVelocityMultiplier or 0.92,
	})
	data.KickKind = kind
	data.PassType = passType
	data.PassDistance = distance
	data.TutorialPhysics = self.Ball:GetAttribute("VTRTutorialPhysics") == true
	data.FlightConfig = flight
	data.MotionKind = kind
	data.StartServerTime = workspace:GetServerTimeNow()
	data.Debug = flight.Debug == true
	return data
end

function Service:_cancelKinematicFlight()
	local active = self.ActiveTrajectory
	if not active then return end
	self.ActiveTrajectory = nil
	self.Ball:SetAttribute("VTRKinematicFlight", nil)
	self.Ball:SetAttribute("VTRTrajectoryId", nil)
	self.Ball.Anchored = false
	self.Ball.CanCollide = true
	self.Ball.CanTouch = true
	self.Ball.CanQuery = true
	pcall(function() self.Ball:SetNetworkOwner(nil) end)
end

function Service:_finishKinematicFlight(position: Vector3, velocity: Vector3, reason: string)
	local active = self.ActiveTrajectory
	if not active then return end
	self.ActiveTrajectory = nil
	self.Ball:SetAttribute("VTRKinematicFlight", nil)
	self.Ball:SetAttribute("VTRTrajectoryId", nil)
	self.Ball.Anchored = false
	self.Ball.CanCollide = true
	self.Ball.CanTouch = true
	self.Ball.CanQuery = true
	pcall(function() self.Ball:SetNetworkOwner(nil) end)
	self.Ball.CFrame = CFrame.new(position)
	self.Ball.AssemblyLinearVelocity = velocity
	local radius = math.max(self.Ball.Size.X * 0.5, 0.1)
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontal.Magnitude > 0.1 then self.Ball.AssemblyAngularVelocity = Vector3.yAxis:Cross(horizontal.Unit) * (horizontal.Magnitude / radius) end
	if reason == "Collision" then
		self.MotionKind = active.Kind == "Shot" and "Deflection" or "Loose"
		self.Ball:SetAttribute("VTRMotionKind", self.MotionKind)
		if self.PassReception and active.Kind == "Pass" then self.PassReception:MarkTrajectoryDeflected(active.Id, reason) end
	end
end

function Service:_startKinematicFlight(model: Model, kind: string, velocity: Vector3, amount: number, receiver: Model?, passType: string?, targetPoint: Vector3?): boolean
	if Config.Ball.KinematicFlightEnabled ~= true or (kind ~= "Pass" and kind ~= "Shot") then return false end
	local trajectory = self:_buildKinematicTrajectory(model, kind, velocity, amount, passType, targetPoint)
	if not trajectory then return false end
	self:_cancelKinematicFlight()
	self.TrajectorySequence = (self.TrajectorySequence or 0) + 1
	trajectory.Id = self.TrajectorySequence
	local releaseVelocity = BallTrajectory.ReleaseVelocity(trajectory)
	self.ActiveTrajectory = {Id = trajectory.Id, Data = trajectory, Kind = kind, Kicker = model, Receiver = receiver, Previous = trajectory.Start, Started = os.clock()}
	self.Possession:Release(nil, kind == "Shot" and 0.55 or 0.25)
	self.Curve:Stop()
	self.Ball.Anchored = true
	self.Ball.CanCollide = false
	self.Ball.CanTouch = false
	self.Ball.CanQuery = true
	self.Ball.CFrame = CFrame.new(trajectory.Start)
	self.Ball.AssemblyLinearVelocity = releaseVelocity
	self.Ball:SetAttribute("VTRKinematicFlight", true)
	self.Ball:SetAttribute("VTRTrajectoryId", trajectory.Id)
	self.Ball:SetAttribute("VTRTrajectoryStart", trajectory.StartServerTime)
	self.Ball:SetAttribute("VTRTrajectoryDuration", trajectory.Duration)
	self.Remote:FireAllClients({Type = "BallTrajectory", Trajectory = trajectory, Actor = model, Receiver = receiver, MotionKind = kind})
	return true
end

function Service:_segmentPointDistance(a: Vector3, b: Vector3, p: Vector3): (number, Vector3)
	local ab = b - a
	local t = ab.Magnitude > 0.0001 and math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) or 0
	local point = a + ab * t
	return (p - point).Magnitude, point
end

function Service:_stepKinematicFlight(dt: number): boolean
	local active = self.ActiveTrajectory
	if not active then return false end
	local data = active.Data
	local alpha = math.clamp((workspace:GetServerTimeNow() - (tonumber(data.StartServerTime) or workspace:GetServerTimeNow())) / math.max(tonumber(data.Duration) or 1, 0.05), 0, 1)
	local previous = active.Previous or self.Ball.Position
	local position = BallTrajectory.Sample(data, alpha)
	local velocity = BallTrajectory.Velocity(data, alpha)
	position=self:_groundedPassPosition(data,position)
	if data and data.KickKind=="Pass"and data.PassType~="Lofted"and data.PassType~="ManualLobbed"then
		velocity=Vector3.new(velocity.X,math.clamp(velocity.Y,-1.5,1.2),velocity.Z)
	end
	local flight = self:_flightConfig()
	local radius = math.max(self.Ball.Size.X * 0.5, Config.Ball.Radius or 1) * (flight.SpherecastRadiusMultiplier or 1.08)
	local delta = position - previous
	local hit = nil
	if delta.Magnitude > 0.001 and workspace.Spherecast then
		local ok, result = pcall(function() return workspace:Spherecast(previous, radius, delta, self.Raycast) end)
		if ok then hit = result end
	end
	if hit and (hit.Normal.Y > 0.55 or isGoalDetectorPart(hit.Instance) or active.Kind == "Shot" and isGoalNetOrBackstop(hit.Instance)) then hit = nil end
	if hit then
		self:_finishKinematicFlight(hit.Position, velocity, "Collision")
		return true
	end
	local now = os.clock()
	local candidates = {}
	for _, model in self.Models do
		if model ~= active.Kicker or now - (active.Started or now) >= (flight.KickerGraceTime or 0.12) then
			local candidate = self:_contactCandidate(model)
			if candidate and candidate.Valid then table.insert(candidates, candidate) end
		end
	end
	local evaluation = BallContactResolver.ResolveSwept(candidates, {PreviousPosition = previous, Position = position, Velocity = velocity, Radius = radius, Duration = dt})
	local contact = evaluation and {Evaluation = evaluation, Closest = evaluation.BallContactPoint, Model = evaluation.Candidate.Model} or nil
	if contact then
		local receiveMultiplier = tonumber(flight.ReceiveVelocityMultiplier) or .18
		local outcome = contact.Evaluation.Outcome
		self:_emitTelemetry(contact.Model,"playability_possession_contact",{contactOutcome=outcome,contactKind=contact.Evaluation.ContactKind,contactScore=math.floor(contact.Evaluation.Score*100+.5),relativeSpeed=math.floor((contact.Evaluation.RelativeSpeed or 0)+.5),expectedReceiver=contact.Evaluation.Candidate.ExpectedReceiver==true})
		local rolloutScale = outcome == "Controlled" and receiveMultiplier or outcome == "HeavyTouch" and math.max(receiveMultiplier, 0.42) or math.max(receiveMultiplier, 0.68)
		local rollout = passRolloutVelocity(data, contact.Closest, velocity) * rolloutScale
		self:_finishKinematicFlight(contact.Closest, rollout, "Received")
		local handled = self.PassReception and self.PassReception:HandleContact(contact.Model, contact.Evaluation, contact.Closest, velocity) == true
		if not handled then
			if contact.Evaluation.Outcome == "Controlled" and self.Possession:Pickup(contact.Model) then
				self:_finalizePickup(contact.Model, false)
			elseif outcome == "HeavyTouch" then
				self.Possession:Block(contact.Model, .1)
				self.Ball.AssemblyLinearVelocity = rollout
			else
				self.Possession:Block(contact.Model, .14)
				local root = self:_root(contact.Model)
				local normal = root and flat(contact.Closest - root.Position) or flat(rollout)
				self.Ball.AssemblyLinearVelocity = rollout + normal * 5
			end
		end
		return true
	end
	self.Ball.CFrame = CFrame.new(position)
	self.Ball.AssemblyLinearVelocity = velocity
	active.Previous = position
	if alpha >= 1 then
		self:_finishKinematicFlight(position, passRolloutVelocity(data,position,BallTrajectory.ReleaseVelocity(data)), "Complete")
	end
	return true
end

function Service:Kick(model: Model, kind: string, direction: Vector3, charge: number?, receiver: Model?, passType: string?, passDistance: number?, targetPoint:Vector3?): boolean
	if self.Possession:GetOwner() ~= model or not self:_allowed(model, kind) then
		return false
	end
	if self.PassReception then self.PassReception:Cancel(kind == "Pass" and "PassReplacedByNewAction" or "TrajectoryReplaced") end
	self:_beginBallAction(model, kind)
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
		local aiPasser = model:GetAttribute("aiControlled") == true and model:GetAttribute("controlledByUser") ~= true
		if aiPasser then
			consistency = math.clamp(consistency + 0.025, 0.98, 1.045)
		end
		local variation = self.Random:NextNumber(-1, 1) * (1 - passing / 100) * (aiPasser and 0.004 or 0.018)
		local throughScale = passType == "Through" and 0.94 or 1
		local speedBias = passType == "BackPass" and 0.96 or passType == "Ground" and 1.12 or passType == "Through" and 1.1 or passType == "Lofted" and 1.06 or 1.08
		local finalSpeed = math.clamp(baseSpeed * consistency * (1 + variation) * throughScale * speedBias, 40, PassingPower.AbsoluteMaxSpeed)
		local modelRoot = self:_root(model)
		if passType=="Lofted"then
			local destination=targetPoint or(modelRoot and modelRoot.Position+direction)or(self.Ball.Position+direction)
			destination=Vector3.new(destination.X,self.Ball.Position.Y,destination.Z)
			receiver=self:_closestPassReceiverToTarget(model,destination,receiver)
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
		if not receiver and self.PassTargetPoint then
			receiver = self:_closestPassReceiverToTarget(model, self.PassTargetPoint, nil)
		end
		if not receiver and targetPoint then
			receiver = self:_closestPassReceiverToTarget(model, targetPoint, nil)
		end
		if not receiver and modelRoot then
			receiver = self:_closestPassReceiverToTarget(model, modelRoot.Position + direction, nil)
		end
		if self.PassTargetPoint then self.Ball:SetAttribute("VTRPassTarget", self.PassTargetPoint) end
		self.Ball:SetAttribute("VTRShotTarget", nil)
		self.Stats:RecordPassAttempt(model)
		self.LastPassTeam = team
		self.LastPasser=model
		self.LastPassOrigin=modelRoot and modelRoot.Position or self.Ball.Position
		if self.ExpectedReceiver and self.ExpectedReceiver ~= receiver then
			self.ExpectedReceiver:SetAttribute("VTRReceiverAssistMode",nil)
		end
		self.ExpectedReceiver = receiver
		local plannedEta = self.PassPlan and tonumber(self.PassPlan.FlightTime) or nil
		if not plannedEta then
			local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			plannedEta = (passDistance or direction.Magnitude) / math.max(horizontalSpeed, 1)
		end
		self:_primePassReceiver(model, receiver, self.PassTargetPoint or targetPoint, plannedEta, nil, passType)
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
		if model:GetAttribute("VTRTutorialShot")==true and executedTarget and modelRoot then
			local horizontal=Vector3.new(velocity.X,0,velocity.Z)
			local shotDistance=Vector3.new(executedTarget.X-modelRoot.Position.X,0,executedTarget.Z-modelRoot.Position.Z).Magnitude
			local targetSpeed=math.clamp(shotDistance/1.18,58,92)
			if horizontal.Magnitude>.1 then
				velocity=horizontal.Unit*targetSpeed+Vector3.yAxis*math.clamp(velocity.Y*.42,4,18)
				horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z)
				flightTime=horizontalDistance/math.max(horizontalVelocity.Magnitude,1)
			end
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
		if not execution and overhit > 0 then goalChance *= VTRShotPowerModel.ComposureMultiplier(rawShotPower) end
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
	local kinematicStarted = self:_startKinematicFlight(model, kind, velocity, amount, receiver, passType, kind == "Pass" and self.PassTargetPoint or (self.ShotPlan and self.ShotPlan.Target or targetPoint))
	if not kinematicStarted then
		self.Possession:Release(velocity, kind == "Shot" and 0.55 or 0.25)
		if kind == "Pass" and self.PendingCurve then self.Curve:Start(self.PendingCurve.Model,self.PendingCurve.Direction,self.PendingCurve.Speed,self.PendingCurve.Distance);self.PendingCurve=nil elseif not (kind=="Pass" and self.PassCurveStarted==true) and (kind=="Pass"or kind~="Shot")then self.Curve:Stop()end
	else
		self.PendingCurve=nil
	end
	self.PassCurveStarted=nil
	if kind == "Pass" then
		self.PassSequence = (self.PassSequence or 0) + 1
		local activePass = self.ActiveTrajectory and self.ActiveTrajectory.Kind == "Pass" and self.ActiveTrajectory.Kicker == model and self.ActiveTrajectory or nil
		local duration = activePass and activePass.Data and tonumber(activePass.Data.Duration) or (passDistance or direction.Magnitude) / math.max(flat(velocity).Magnitude, 1)
		if not receiver and self.PassTargetPoint then
			receiver = self:_closestPassReceiverToTarget(model, self.PassTargetPoint, nil)
			self.ExpectedReceiver = receiver
			self.Ball:SetAttribute("VTRPassReceiver", receiver and receiver.Name or nil)
			self:_primePassReceiver(model, receiver, self.PassTargetPoint, duration, duration + 1.3, passType)
		end
		if self.PassReception then
			self.PassReception:OnPassLaunched({
				PassId = self.PassSequence,
				TrajectoryId = activePass and activePass.Id or 0,
				Passer = model,
				Receiver = receiver,
				PassFamily = passType or "Ground",
				InitialReceivePoint = self.PassTargetPoint or targetPoint,
				InitialVelocity = velocity,
				PassDistance = passDistance or direction.Magnitude,
				InitialETA = duration,
				Duration = duration,
				Confidence = receiver and 0.82 or 0,
			})
		end
	end
	local actorUserId=tonumber(model:GetAttribute("VTRUserId"))
	local eventPayload={Type=kind,Actor=model,ActorUserId=actorUserId,ActorControlledByUser=model:GetAttribute("controlledByUser")==true,Receiver=receiver,Charge=amount,PassFamily=kind=="Pass"and(passType or"Ground")or nil}
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
	self:_beginBallAction(model, "Skill")
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
	if self.PassReception then self.PassReception:Cancel("TrajectoryReplaced")end
	self:_beginBallAction(model, "Clearance")
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
	if self.PassReception then self.PassReception:Cancel("TrajectoryReplaced")end
	self:_beginBallAction(model, "Clearance")
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

function Service:_recordTackleOutcome(model: Model, token: number, outcome: string, slide: boolean, owner: Model?, details: any?): boolean
	local pending = self.PendingTackles[model]
	if type(pending) ~= "table" or pending.Token ~= token then return false end
	self.PendingTackles[model] = nil
	local won = outcome == "TackleWonPossession" or outcome == "TackleWonLooseBall"
	self.Stats:RecordTackle(model, won)
	model:SetAttribute("VTRLastTackleOutcome", outcome)
	model:SetAttribute("VTRTackleRecoveryUntil", os.clock() + (won and (slide and 1.05 or .42) or (slide and 1.2 or .58)))
	if slide then model:SetAttribute("VTRSlideTackleLockUntil", os.clock() + 1.05) end
	self.Remote:FireAllClients({Type = "TackleOutcome", Outcome = outcome, Actor = model, Victim = owner, Slide = slide, GeometryBand = details and details.GeometryBand, Quality = details and details.Quality})
	self:_emitTelemetry(model,"playability_tackle_outcome",{tackleOutcome=outcome,tackleGeometryBand=tostring(details and details.GeometryBand or(slide and"Slide"or"Standing")),slide=slide})
	return true
end

function Service:_resolveTackle(model: Model, owner: Model, slide: boolean, startModel: Vector3, token: number)
	local pending = self.PendingTackles[model]
	if type(pending) ~= "table" or pending.Token ~= token then return end
	if not model.Parent or not owner.Parent or self.Possession:GetOwner() ~= owner then self:_recordTackleOutcome(model, token, "TackleBlocked", slide, owner);return end
	if tostring(owner:GetAttribute("position") or "") == "GK" and (tonumber(owner:GetAttribute("VTRGoalkeeperTackleImmuneUntil")) or 0) > os.clock() then self:_recordTackleOutcome(model, token, "TackleBlocked", slide, owner);return end
	local modelRoot = self:_root(model)
	local ownerRoot = self:_root(owner)
	if not modelRoot or not ownerRoot then self:_recordTackleOutcome(model, token, "TackleBlocked", slide, owner);return end
	local now = os.clock()
	local historical=pending.Historical
	local historicalModel=historical and historical.Models and historical.Models[model]
	local historicalOwner=historical and historical.Models and historical.Models[owner]
	local result = TackleResolver.Resolve({
		Slide = slide,
		StartPosition = startModel,
		EndPosition = modelRoot.Position,
		BallStartPosition = historical and historical.Ball or self.Ball.Position,
		BallPosition = self.Ball.Position,
		OwnerStartPosition = historicalOwner and historicalOwner.Position or ownerRoot.Position,
		OwnerPosition = ownerRoot.Position,
		Facing = historicalModel and historicalModel.Facing or modelRoot.CFrame.LookVector,
		OwnerFacing = historicalOwner and historicalOwner.Facing or ownerRoot.CFrame.LookVector,
		Tackle = tonumber(model:GetAttribute(slide and "SlidingTackle" or "StandingTackle")) or tonumber(model:GetAttribute("DEF")) or 55,
		Dribbling = tonumber(owner:GetAttribute("Dribbling")) or tonumber(owner:GetAttribute("DRI")) or 55,
		Strength = tonumber(model:GetAttribute("Strength")) or tonumber(model:GetAttribute("PHY")) or 60,
		OwnerBalance = tonumber(owner:GetAttribute("Balance")) or 60,
		Stamina = tonumber(model:GetAttribute("VTRSprintEnergy")) or 100,
		Exposure = (tonumber(owner:GetAttribute("VTRPostSkillVulnerableUntil")) or 0) > now and 1 or 0.45,
		ActiveSkill = (tonumber(owner:GetAttribute("VTRDribbleMoveUntil")) or 0) > now,
		PostSkillExposure = (tonumber(owner:GetAttribute("VTRPostSkillVulnerableUntil")) or 0) > now,
	})
	local outcome = result.Outcome
	if outcome == "TackleFoul" then
		if self.Referee and self:_canAutoFoul(model, owner) then
			if self:_recordTackleOutcome(model, token, outcome, slide, owner, result) then
				owner:SetAttribute("VTRStunnedUntil", math.max(tonumber(owner:GetAttribute("VTRStunnedUntil")) or 0, now + (slide and .68 or .32)))
				owner:SetAttribute("VTRCannotRecoverBallUntil", math.max(tonumber(owner:GetAttribute("VTRCannotRecoverBallUntil")) or 0, now + (slide and .68 or .32)))
				self.Referee:CallFoul(model, owner, slide and "Slide Tackle" or "Standing Tackle", ownerRoot.Position, slide and result.Approach == "Behind", nil)
			end
		else
			self:_recordTackleOutcome(model, token, "TackleBlocked", slide, owner, result)
		end
		return
	end
	if outcome == "TackleWonPossession" then
		if owner:GetAttribute("VTRGoalkeeperHolding") == true then self:ClearGoalkeeperHoldState(owner) end
		local tackleRange=slide and Config.Ball.SlideTackleRange or Config.Ball.StandingTackleRange
		local pickupDistance:any=tackleRange+1
		if historical then pickupDistance=nil end
		if not self.Possession:ForcePickup(model,pickupDistance) then self:_recordTackleOutcome(model, token, "TackleBlocked", slide, owner, result);return end
		if not self:_recordTackleOutcome(model, token, outcome, slide, owner, result) then return end
		self.Stats:Event(owner, "PossessionLost")
		self.Possession:Block(owner, slide and .9 or .55)
		owner:SetAttribute("VTRStunnedUntil", now + (slide and .62 or .3))
		owner:SetAttribute("VTRCannotRecoverBallUntil", now + (slide and .62 or .3))
		model:SetAttribute("VTRNoAutoPassUntil", now + .8)
		self:_touch(model)
		self.MotionKind = "Tackle"
		self.MotionStarted = now
		self.Remote:FireAllClients({Type = slide and "SlideTackle" or "Tackle", Actor = model, Victim = owner})
		return
	end
	if outcome == "TackleWonLooseBall" then
		local direction = flat(self.Ball.Position - modelRoot.Position)
		self.Possession:Release(direction * (slide and 24 or 17), .25)
		if not self:_recordTackleOutcome(model, token, outcome, slide, owner, result) then return end
		self.Stats:Event(owner, "PossessionLost")
		self.Possession:Block(owner, slide and .72 or .38)
		self:_touch(model)
		self.MotionKind = "Tackle"
		self.MotionStarted = now
		return
	end
	self.Possession:Block(model, slide and .65 or .38)
	self:_recordTackleOutcome(model, token, outcome, slide, owner, result)
end

function Service:Tackle(model: Model, slide: boolean?, clientTime:any?): boolean
	if self.PendingTackles[model] then return false end
	local owner = self.Possession:GetOwner()
	local modelRoot = self:_root(model)
	local ownerRoot = owner and self:_root(owner)
	if not owner or owner == model or not modelRoot or not ownerRoot then return false end
	if tostring(owner:GetAttribute("position") or "") == "GK" and (tonumber(owner:GetAttribute("VTRGoalkeeperTackleImmuneUntil")) or 0) > os.clock() then return false end
	if not self:_allowed(model,"Tackle")then return false end
	local isSlide = slide == true
	if self.Animations then self.Animations:PlayAction(model, isSlide and "SlideTackle" or "Tackle") end
	self.TackleSequence = (tonumber(self.TackleSequence) or 0) + 1
	local token = self.TackleSequence
	local historical=self:_historyAt(clientTime)
	local historicalModel=historical and historical.Models and historical.Models[model]
	self.PendingTackles[model] = {Token = token, Owner = owner,Historical=historical}
	local delaySeconds = isSlide and (Config.Ball.SlideTackleContactSeconds or .22) or (Config.Ball.StandingTackleContactSeconds or .16)
	local startModel = historicalModel and historicalModel.Position or modelRoot.Position
	task.delay(delaySeconds, function() self:_resolveTackle(model, owner, isSlide, startModel, token) end)
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
		local horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z)
		local horizontalTarget=Vector3.new(toTarget.X,0,toTarget.Z)
		if toTarget.Magnitude<2 or horizontalVelocity.Magnitude>.1 and horizontalTarget:Dot(horizontalVelocity)<=0 then self.ShotPlan=nil end
	else self.ShotPlan=nil end
	if passPlan and passPlan.Lofted and os.clock()-passPlan.Started<(passPlan.FlightTime or 0)+.08 then velocity+=Vector3.yAxis*math.max(0,workspace.Gravity-(passPlan.EffectiveGravity or workspace.Gravity))*dt end
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local ground = workspace:Raycast(self.Ball.Position, Vector3.new(0, -Physics.GROUND_HEIGHT_TOLERANCE * 2, 0), self.Raycast)
	local grounded = ground ~= nil and math.abs(velocity.Y) < 8
	local age = os.clock() - self.MotionStarted
	local tutorialPhysics=self.Ball:GetAttribute("VTRTutorialPhysics")==true
	local passTravelLimit=tutorialPhysics and 5.2 or 3.8
	local passTravel = (self.MotionKind == "Pass" or self.MotionKind=="Clearance") and self.PassTargetPoint and age < passTravelLimit
	local preservation = self.MotionKind == "Shot" and age < 1.15 and 0.34 or passTravel and(tutorialPhysics and 0.26 or 0.42) or 1
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
			self.Ball:SetAttribute("VTRLobLanded", true)
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
		local minimumRollSpeed=tutorialPhysics and 17 or 14
		if remaining > 5 and horizontal.Magnitude > 0.1 and horizontal.Magnitude < minimumRollSpeed then
			self.Ball.AssemblyLinearVelocity = Vector3.new(horizontal.Unit.X * minimumRollSpeed, velocity.Y, horizontal.Unit.Z * minimumRollSpeed)
		end
	end
	local angularDecay = math.exp(-Physics.ANGULAR_DAMPING * dt)
	self.Ball.AssemblyAngularVelocity *= angularDecay
	if self.Ball.AssemblyLinearVelocity.Magnitude > Physics.MAX_BALL_SPEED then
		self.Ball.AssemblyLinearVelocity = self.Ball.AssemblyLinearVelocity.Unit * Physics.MAX_BALL_SPEED
	end
end

function Service:_finalizePickup(nearest: Model, forcedReceiverPickup: boolean): boolean
	local team = nearest:GetAttribute("VTRTeam")
	local previousTeam=tostring(self.Ball:GetAttribute("VTRLastPossessionTeam") or "")
	local pickupReason="LooseRecovery"
	if self.LastPassTeam then
		if self.LastPassTeam==team then pickupReason=forcedReceiverPickup and "PassReceived" or "TeamPassRecovered" else pickupReason="Turnover" end
	elseif previousTeam~="" and previousTeam~=team then pickupReason="Turnover" end
	self.Ball:SetAttribute("VTRLastPossessionTeam",team)
	self.Remote:FireAllClients({Type="PossessionContext",Owner=nearest:GetAttribute("DisplayName")or nearest.Name,Model=nearest,Team=team,Reason=pickupReason})
	if self.LastPassTeam==team and self.Offside and self:_isOffsideCandidate(nearest) then
		if self.PassReception then self.PassReception:Cancel("Offside") end
		self.Offside:Call(nearest)
		self:_clearOffsideSnapshot()
		self.LastPassTeam=nil;self.LastPasser=nil;self.LastPassOrigin=nil;self.ExpectedReceiver=nil;self.PassPlan=nil
		clearFlightAttributes(self.Ball);self.Ball:SetAttribute("VTRPassStartedAt",nil);self.Ball:SetAttribute("VTRPassTeam",nil);self.Ball:SetAttribute("VTRPassReceiver",nil)
		return false
	end
	if self.LastPassTeam then
		if self.LastPassTeam==team and self.LastPasser then
			self.Stats:RecordPassCompleted(self.LastPasser,nearest,self.LastPassOrigin,self.Ball.Position)
			if AIPassingDecisionService.RecordPassOutcome then AIPassingDecisionService.RecordPassOutcome(self.LastPasser,nearest,true,self.Models) end
		elseif self.LastPasser then
			self.Stats:RecordPassFailed(self.LastPasser,nearest)
			if AIPassingDecisionService.RecordPassOutcome then AIPassingDecisionService.RecordPassOutcome(self.LastPasser,nearest,false,self.Models) end
		end
	end
	local receivedPassAsGoalkeeper = self.MotionKind=="Pass" and tostring(nearest:GetAttribute("position") or "")=="GK"
	self.LastPassTeam = nil
	self.LastPasser=nil;self.LastPassOrigin=nil
	local completedReceiver=self.ExpectedReceiver
	self.ExpectedReceiver = nil
	if completedReceiver and completedReceiver.Parent then completedReceiver:SetAttribute("VTRReceiverAssistMode",nil)end
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
	return true
end

function Service:ResolveReceptionPickup(model: Model, touchVelocity: Vector3, _reason: string): boolean
	local maxDistance = self:_isTargetedLobReceiver(model) and 15.25 or 7.5
	if not self.Possession:ForcePickup(model, maxDistance) then return false end
	self.Ball.AssemblyLinearVelocity = touchVelocity
	self.Ball.AssemblyAngularVelocity = Vector3.zero
	return self:_finalizePickup(model, true)
end

function Service:Step(dt: number)
	self:_recordPositionHistory(dt)
	if self.Ball:GetAttribute("VTRWorldPaused")==true then return end
	local owner = self.Possession:GetOwner()
	self:_guardGoalkeeperHold(owner)
	if owner then
		self.LastContactBallPosition=self.Ball.Position
		self.Accumulator=0
		self:_cancelKinematicFlight()
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
		local movement = owner:GetAttribute("VTRMoveDirection")
		local moveVector = typeof(movement) == "Vector3" and Vector3.new(movement.X, 0, movement.Z) or Vector3.zero
		local ownerVelocity = Vector3.new(ownerRoot.AssemblyLinearVelocity.X, 0, ownerRoot.AssemblyLinearVelocity.Z)
		local now = os.clock()
		local serverNow = workspace:GetServerTimeNow()
		if self.DribbleTouchOwner ~= owner then
			self.DribbleTouchOwner = owner
			self.NextDribbleTouchAt = now
			self.DribbleTouchStartedAt = serverNow
			self.DribbleTouchDuration = Config.Ball.DribbleTouchMaximumSeconds or 0.45
			self.DribbleVelocity = self.Ball.AssemblyLinearVelocity
			self.DribbleDivergenceStartedAt = nil
		end
		local moving = moveVector.Magnitude > 0.08 or ownerVelocity.Magnitude > 2.5
		if moving and now >= (tonumber(self.NextDribbleTouchAt) or 0) then
			local duration = math.clamp((Config.Ball.DribbleTouchMaximumSeconds or 0.45) - ownerVelocity.Magnitude * 0.006, Config.Ball.DribbleTouchMinimumSeconds or 0.28, Config.Ball.DribbleTouchMaximumSeconds or 0.45)
			self.NextDribbleTouchAt = now + duration
			self.DribbleTouchStartedAt = serverNow
			self.DribbleTouchDuration = duration
			self.Ball:SetAttribute("VTRDribbleTouchStartedAt", serverNow)
			self.Ball:SetAttribute("VTRDribbleTouchDuration", duration)
		elseif not moving then
			self.NextDribbleTouchAt = now + 0.18
		end
		local touchDuration = math.max(tonumber(self.DribbleTouchDuration) or 0.4, 0.05)
		local touchPhase = moving and math.clamp((serverNow - (tonumber(self.DribbleTouchStartedAt) or serverNow)) / touchDuration, 0, 1) or 0
		local look = Vector3.new(ownerRoot.CFrame.LookVector.X, 0, ownerRoot.CFrame.LookVector.Z)
		local targetData = DribbleTargetResolver.Resolve({
			RootPosition = ownerRoot.Position,
			RootLookVector = look,
			MoveVector = moveVector,
			HorizontalVelocity = ownerVelocity,
			Sprinting = sprinting,
			CloseControl = closeControl,
			BallControl = tonumber(owner:GetAttribute("BallControl")) or tonumber(owner:GetAttribute("DRI")) or 60,
			TurnDot = moveVector.Magnitude > 0.08 and look.Magnitude > 0.05 and moveVector.Unit:Dot(look.Unit) or 1,
			TouchPhase = touchPhase,
			BallRadius = math.max(self.Ball.Size.X * 0.5, Config.Ball.Radius or 1),
			VerticalOffset = Config.Ball.DribbleVerticalOffset,
			ActionLocked = (tonumber(owner:GetAttribute("VTRActionLockedUntil")) or 0) > now,
		})
		local target = keepDribbleTargetAtFeet(self.Ball, self.Raycast, ownerRoot, targetData.Target, targetData.TouchDirection)
		self.Ball:SetAttribute("VTRDribbleServerTarget", target)
		self.Ball:SetAttribute("VTRDribbleTouchSide", targetData.TouchSide)
		local currentPosition = self.Ball.Position
		local targetOffset = target - currentPosition
		local targetHorizontal = Vector3.new(targetOffset.X, 0, targetOffset.Z)
		local errorMagnitude=targetHorizontal.Magnitude
		self.Ball:SetAttribute("VTRDribbleServerDivergence", errorMagnitude)
		if errorMagnitude > 3.5 then
			self.DribbleDivergenceStartedAt = self.DribbleDivergenceStartedAt or now
			self.Ball:SetAttribute("VTRDribbleSustainedDivergence", now - self.DribbleDivergenceStartedAt)
		else
			self.DribbleDivergenceStartedAt = nil
			self.Ball:SetAttribute("VTRDribbleSustainedDivergence", 0)
		end
		local hardDistance=targetData.HardRecoveryDistance
		if errorMagnitude>hardDistance and now-(self.LastHardCorrectionAt or 0)>=(Config.Ball.DribbleHardCorrectionCooldown or .18)then
			local relativeVelocity = Vector3.new(self.Ball.AssemblyLinearVelocity.X, 0, self.Ball.AssemblyLinearVelocity.Z) - ownerVelocity
			local recoveryBlocked = (tonumber(owner:GetAttribute("VTRStunnedUntil")) or 0) > now or (tonumber(owner:GetAttribute("VTRCannotRecoverBallUntil")) or 0) > now
			if recoveryBlocked or relativeVelocity.Magnitude > 62 then
				self.Possession:Release(nil, 0.22)
				self.Ball:SetAttribute("VTRDribbleLostAt", serverNow)
				return
			end
			self.LastHardCorrectionAt=now
			local correction=targetHorizontal.Unit*math.min(Config.Ball.DribbleMaximumCorrection or 2.2,math.max(0,errorMagnitude-(Config.Ball.DribbleControlledDistance or 5.8)))
			local corrected=currentPosition+correction
			corrected=Vector3.new(corrected.X,currentPosition.Y+math.clamp(target.Y-currentPosition.Y,-.8,.8),corrected.Z)
			self.Ball.CFrame=CFrame.new(corrected)
			self.Ball:SetAttribute("VTRHardCorrectionCount",(tonumber(self.Ball:GetAttribute("VTRHardCorrectionCount"))or 0)+1)
			self.Ball:SetAttribute("VTRLastHardCorrectionMagnitude",errorMagnitude)
			self.Ball:SetAttribute("VTRLastHardCorrectionReason","DribbleEnvelope")
			targetHorizontal=Vector3.new(target.X-corrected.X,0,target.Z-corrected.Z)
			errorMagnitude=targetHorizontal.Magnitude
		end
		local response = if errorMagnitude <= 2 then 2.5 elseif errorMagnitude <= 6 then targetData.CorrectionStrength else targetData.CorrectionStrength * 1.35
		local currentHorizontal=Vector3.new(self.Ball.AssemblyLinearVelocity.X,0,self.Ball.AssemblyLinearVelocity.Z)
		local relative=currentHorizontal-ownerVelocity
		local spring=targetHorizontal*response-relative*.58
		local touchImpulse = math.sin(touchPhase * math.pi) * (sprinting and 3.2 or 2.1)
		local desired = ownerVelocity + spring + targetData.TouchDirection * touchImpulse
		if desired.Magnitude > Config.Ball.MaxDribbleSpeed then
			desired = desired.Unit * Config.Ball.MaxDribbleSpeed
		end
		local verticalError=target.Y-self.Ball.Position.Y
		local verticalVelocity=math.clamp(verticalError*18-self.Ball.AssemblyLinearVelocity.Y*.72,-8,8)
		self.Ball.AssemblyLinearVelocity = Vector3.new(desired.X, verticalVelocity, desired.Z)
		local horizontal = Vector3.new(desired.X, 0, desired.Z)
		if horizontal.Magnitude > 0.2 then self.Ball.AssemblyAngularVelocity = Vector3.yAxis:Cross(horizontal.Unit) * (horizontal.Magnitude / math.max(self.Ball.Size.X * 0.5, 0.1)) end
		self.Stats:Add(tostring(owner:GetAttribute("VTRTeam") or "Home"), "Possession", dt)
		return
	end
	if self:_stepKinematicFlight(dt) then
		self.LastContactBallPosition=self.Ball.Position
		self.Accumulator=0
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
	local earlyClaimer = self:_rollingBallClaimCandidate(nil)
	if earlyClaimer and self.Possession:ForcePickup(earlyClaimer, self:_isTargetedLobReceiver(earlyClaimer) and 15.25 or 9.25) then
		self:_emitTelemetry(earlyClaimer, "playability_possession_contact", {contactOutcome = "ImmediateRollingClaim"})
		self:_finalizePickup(earlyClaimer, false)
		return
	end
	self.Accumulator += dt
	if self.Accumulator <= 0.04 then
		return
	end
	local contactDuration=self.Accumulator
	self.Accumulator = 0
	local contactStart=self.LastContactBallPosition
	self.LastContactBallPosition=self.Ball.Position
	local nearest: Model? = nil
	local candidates = {}
	for _, model in self.Models do
		local candidate = self:_contactCandidate(model)
		if candidate and candidate.Valid then table.insert(candidates, candidate) end
	end
	local contact = BallContactResolver.ResolveSwept(candidates, {
		PreviousPosition = contactStart,
		Position = self.Ball.Position,
		Velocity = self.Ball.AssemblyLinearVelocity,
		Radius = math.max(self.Ball.Size.X * 0.5, Config.Ball.Radius or 1),
		Duration = contactDuration,
	})
	if contact and self.PassReception and self.PassReception:HandleContact(contact.Candidate.Model, contact, contact.ContactPoint, self.Ball.AssemblyLinearVelocity) then return end
	if contact and contact.Outcome == "Controlled" then
		nearest = contact.Candidate.Model
		self:_emitTelemetry(nearest,"playability_possession_contact",{contactOutcome="Controlled"})
	elseif contact then
		local claimer = self:_rollingBallClaimCandidate(contact.Candidate.Model)
		if claimer then
			nearest = claimer
			self:_emitTelemetry(nearest,"playability_possession_contact",{contactOutcome="RollingClaim"})
		end
	end
	if not nearest then
		local claimer = self:_rollingBallClaimCandidate(nil)
		if claimer then
			nearest = claimer
			self:_emitTelemetry(nearest,"playability_possession_contact",{contactOutcome="RollingProximityClaim"})
		end
	end
	if not nearest and contact and os.clock() - self.LastLooseContactAt >= 0.1 then
		self.LastLooseContactAt = os.clock()
		local model = contact.Candidate.Model
		local modelRoot = model and self:_root(model)
		if modelRoot then
			self:_emitTelemetry(model,"playability_possession_contact",{contactOutcome="Deflected"})
			local away = flat(self.Ball.Position - modelRoot.Position)
			local velocity = self.Ball.AssemblyLinearVelocity
			local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
			local deflected = horizontal:Lerp(away * math.max(5, math.min(horizontal.Magnitude, 14)), 0.3)
			self.Ball.AssemblyLinearVelocity = Vector3.new(deflected.X, math.max(velocity.Y, 1.5), deflected.Z)
			self.Ball:SetAttribute("VTRLastLooseContact", model.Name)
			self.Remote:FireAllClients({Type="LooseBallContact",Actor=model})
		end
	end
	if nearest then
		if self.Possession:Pickup(nearest) or self.Possession:ForcePickup(nearest, 8.75) then
			self:_finalizePickup(nearest, false)
		end
	end
end

return Service
