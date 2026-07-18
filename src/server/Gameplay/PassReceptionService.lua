--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BallTrajectory = require(ReplicatedStorage.VTR.Shared.BallTrajectory)
local MovementStatsResolver = require(ReplicatedStorage.VTR.Shared.MovementStatsResolver)
local PassReceptionConfig = require(ReplicatedStorage.VTR.Shared.PassReceptionConfig)
local ReceptionInterceptResolver = require(ReplicatedStorage.VTR.Shared.ReceptionInterceptResolver)
local ReceiverAssistConfig = require(ReplicatedStorage.VTR.Shared.ReceiverAssistConfig)
local StaminaConfig = require(ReplicatedStorage.VTR.Shared.StaminaConfig)
local ReceiverMovementService = require(script.Parent.ReceiverMovementService)

local Service = {}
Service.__index = Service

local completedReasons = {
	IntendedReceiverControlled = true,
	AlternateTeammateControlled = true,
	FirstTimePass = true,
	FirstTimeShot = true,
}

local eventByPhase = {
	Committed = "playability_reception_committed",
	ControlPrepared = "playability_reception_camera_prepared",
	ContactWindow = "playability_reception_contact",
	Completed = "playability_reception_completed",
	Cancelled = "playability_reception_cancelled",
}

local function root(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

local function finiteNumber(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
	return value
end

local function finiteVector(value: any, maximum: number?): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z and value.Magnitude <= (maximum or math.huge)
end

local function etaBand(value: number): string
	if value == math.huge then return "unreachable" end
	if value <= 0.25 then return "0-.25" end
	if value <= 0.5 then return ".25-.5" end
	if value <= 1 then return ".5-1" end
	if value <= 2 then return "1-2" end
	return "2+"
end

local function distanceBand(value: number): string
	if value <= 15 then return "0-15" end
	if value <= 35 then return "15-35" end
	if value <= 65 then return "35-65" end
	if value <= 100 then return "65-100" end
	return "100+"
end

local function confidenceBand(value: number): string
	if value < 0.35 then return "low" end
	if value < 0.72 then return "medium" end
	return "high"
end

local function copyAction(payload: any): any
	return {
		Type = payload.Type,
		Direction = payload.Direction,
		AimPosition = payload.AimPosition,
		TargetModel = payload.TargetModel,
		Charge = math.clamp(finiteNumber(payload.Charge, 0), 0, 1),
		PassType = payload.PassType,
		AutoSwitch = payload.AutoSwitch,
		ReceiverAssistMode = payload.ReceiverAssistMode,
		ReceiverAssist = payload.ReceiverAssist,
		ManualAim = payload.ManualAim == true,
		GoalTarget = payload.GoalTarget == true,
		ShotVariant = payload.ShotVariant,
		ActionFamily = payload.ActionFamily,
	}
end

function Service.new(remote: RemoteEvent, teams: any, ball: BasePart, possession: any, ballService: any, pitchCFrame: CFrame, width: number, length: number)
	return setmetatable({
		Remote = remote,
		Teams = teams,
		Ball = ball,
		Possession = possession,
		BallService = ballService,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Sequence = 0,
		Active = nil,
		ByReceiver = {},
		ByPlayer = {},
		NextPass = {},
		TerminalIds = {},
		TerminalOrder = {},
		InputAt = {},
		Accumulator = 0,
		Telemetry = nil,
		TeamControl = nil,
		SolverSamples = 0,
		SolverOpponents = 0,
		LastSolverCost = 0,
		Metrics = {Attempted = 0, IntendedCompletions = 0, AlternateCompletions = 0, Interceptions = 0, UserRouteAbandonMisses = 0, Overrides = 0, Retargets = 0, EndpointCorrections = 0, TransferCount = 0, TransferETATotal = 0},
	}, Service)
end

function Service:SetTeamControl(teamControl: any)
	self.TeamControl = teamControl
end

function Service:SetTelemetry(callback: any)
	self.Telemetry = callback
end

function Service:_emit(contract: any, eventName: string, properties: any?)
	if not self.Telemetry or not contract.Player then return end
	local payload = {
		receptionId = contract.Id,
		receptionRevision = contract.Revision,
		assistanceMode = contract.AssistanceMode,
		autoSwitchMode = contract.AutoSwitchMode,
		passFamily = contract.PassFamily,
		passDistanceBand = distanceBand(contract.PassDistance or 0),
		ballEtaBand = etaBand(contract.BallETA or math.huge),
		receiverEtaBand = etaBand(contract.ReceiverETA or math.huge),
		opponentEtaBand = etaBand(contract.OpponentETA or math.huge),
		routeConfidenceBand = confidenceBand(contract.RouteConfidence or 0),
		retargetCount = contract.RetargetCount or 0,
	}
	for key, value in properties or {} do payload[key] = value end
	self.Telemetry(contract.Player, eventName, payload)
end

function Service:_fire(contract: any, payload: any)
	local player = contract.Player
	if player and player.Parent then
		payload.ContractId = contract.Id
		payload.Revision = contract.Revision
		payload.Model = payload.Model or contract.Receiver
		self.Remote:FireClient(player, payload)
	end
end

function Service:_snapshot(contract: any): any
	return {
		Type = "ReceptionUpdated",
		Model = contract.Receiver,
		Phase = contract.Phase,
		ReceivePoint = contract.LiveInterceptPoint,
		BallETA = contract.BallETA,
		ReceiverETA = contract.ReceiverETA,
		Contested = contract.OpponentETA + PassReceptionConfig.OpponentWinMargin < contract.BallETA,
		AssistanceMode = contract.AssistanceMode,
		AutoSwitchMode = contract.AutoSwitchMode,
		PassFamily = contract.PassFamily,
	}
end

function Service:_transition(contract: any, phase: string, properties: any?)
	if contract.Terminal or contract.Phase == phase or PassReceptionConfig.PhaseSet[phase] ~= true then return false end
	contract.Phase = phase
	contract.LastUpdateAt = os.clock()
	if contract.Receiver and contract.Receiver.Parent then ReceiverMovementService.SetPhase(contract.Receiver, phase, contract.Revision) end
	local eventName = eventByPhase[phase]
	if eventName then self:_emit(contract, eventName, properties) end
	return true
end

function Service:_rememberTerminal(contract: any)
	self.TerminalIds[contract.Id] = contract.Phase
	table.insert(self.TerminalOrder, contract.Id)
	while #self.TerminalOrder > 64 do
		local removed = table.remove(self.TerminalOrder, 1)
		self.TerminalIds[removed] = nil
	end
end

function Service:_clearReceiver(contract: any)
	local receiver = contract.Receiver
	if receiver and receiver.Parent and receiver:GetAttribute("VTRReceptionContractId") == contract.Id then
		ReceiverMovementService.Clear(receiver)
	end
	self.ByReceiver[receiver] = nil
	if contract.Player and self.ByPlayer[contract.Player] == contract then self.ByPlayer[contract.Player] = nil end
end

function Service:_terminal(contract: any, phase: string, reason: string, properties: any?): boolean
	if contract.Terminal then return false end
	if PassReceptionConfig.TerminalReasons[reason] ~= true then reason = "MatchInterrupted" end
	contract.Terminal = true
	contract.Phase = phase
	contract.CancelReason = phase == "Cancelled" and reason or nil
	contract.CompletedAt = os.clock()
	if phase == "Completed" then
		if reason == "AlternateTeammateControlled" or properties and properties.actualCollectorRelation == "Teammate" then self.Metrics.AlternateCompletions += 1 else self.Metrics.IntendedCompletions += 1 end
	elseif reason == "OpponentIntercepted" or reason == "GoalkeeperClaim" then
		self.Metrics.Interceptions += 1
	elseif reason == "ReceiverUnreachable" then
		self.Metrics.UserRouteAbandonMisses += 1
	end
	contract.QueuedAction = nil
	if self.Active == contract then self.Active = nil end
	self:_clearReceiver(contract)
	self:_rememberTerminal(contract)
	local payloadType = phase == "Completed" and "ReceptionCompleted" or "ReceptionCancelled"
	self:_fire(contract, {Type = payloadType, Reason = reason, Model = contract.Receiver})
	local merged = {completionReason = reason}
	for key, value in properties or {} do merged[key] = value end
	self:_emit(contract, phase == "Completed" and "playability_reception_completed" or "playability_reception_cancelled", merged)
	return true
end

function Service:Cancel(reason: string): boolean
	local contract = self.Active
	return contract and self:_terminal(contract, "Cancelled", reason) or false
end

function Service:CancelForReceiver(receiver: Model, reason: string): boolean
	local contract = self.ByReceiver[receiver]
	return contract and self:_terminal(contract, "Cancelled", reason) or false
end

function Service:CancelForPlayer(player: Player, reason: string): boolean
	local contract = self.ByPlayer[player]
	return contract and self:_terminal(contract, "Cancelled", reason) or false
end

function Service:CancelQueuedAction(player: Player, reason: string, contractId: any?, revision: any?)
	local contract = self.ByPlayer[player]
	if not contract or not contract.QueuedAction then return end
	if contractId ~= nil and math.floor(finiteNumber(contractId, -1)) ~= contract.Id then return end
	if revision ~= nil and math.floor(finiteNumber(revision, -1)) ~= contract.Revision then return end
	contract.QueuedAction = nil
	if contract.Receiver and contract.Receiver.Parent then contract.Receiver:SetAttribute("VTRReceptionQueuedAction", nil) end
	self:_fire(contract, {Type = "ReceptionQueuedAction", Action = nil, Reason = reason})
end

function Service:ConfigureNextPass(passer: Model, context: any)
	self.NextPass[passer] = {
		Player = context.Player,
		AssistanceMode = ReceiverAssistConfig.Normalize(context.AssistanceMode),
		AutoSwitchMode = ReceiverAssistConfig.Normalize(context.AutoSwitchMode),
		ManualPass = context.ManualPass == true,
		ExpiresAt = os.clock() + 1,
	}
end

function Service:ClearNextPass(passer: Model)
	self.NextPass[passer] = nil
end

function Service:_playerForReceiver(receiver: Model, side: string, preferred: Player?): Player?
	if self.TeamControl then
		for player, active in self.TeamControl.Active do
			if active == receiver then return player end
		end
	end
	if preferred and preferred.Parent then return preferred end
	if self.TeamControl then
		for player, playerSide in self.TeamControl.PlayerSides do
			if playerSide == side then return player end
		end
	end
	return nil
end

function Service:OnPassLaunched(launch: any): any?
	local passer = launch.Passer
	local receiver = launch.Receiver
	if typeof(passer) ~= "Instance" or not passer:IsA("Model") or typeof(receiver) ~= "Instance" or not receiver:IsA("Model") then return nil end
	if not passer.Parent or not receiver.Parent or passer == receiver then return nil end
	local side = tostring(passer:GetAttribute("VTRTeam") or "")
	if side == "" or tostring(receiver:GetAttribute("VTRTeam") or "") ~= side then return nil end
	if self.Active then self:_terminal(self.Active, "Cancelled", "NewPassReplacedContract") end
	local nextContext = self.NextPass[passer]
	self.NextPass[passer] = nil
	if nextContext and nextContext.ExpiresAt < os.clock() then nextContext = nil end
	local family = PassReceptionConfig.NormalizeFamily(launch.PassFamily)
	local manual = family == "Manual" or nextContext and nextContext.ManualPass == true
	if manual then family = "Manual" end
	local assistance = manual and "Manual" or ReceiverAssistConfig.Normalize(nextContext and nextContext.AssistanceMode or receiver:GetAttribute("VTRReceiverAssistMode"), "Standard")
	local autoSwitch = ReceiverAssistConfig.Normalize(nextContext and nextContext.AutoSwitchMode or assistance, assistance)
	local player = self:_playerForReceiver(receiver, side, nextContext and nextContext.Player or nil)
	local alreadyControlled = player ~= nil and self.TeamControl ~= nil and self.TeamControl:GetActive(player) == receiver
	self.Sequence += 1
	local now = os.clock()
	local duration = math.clamp(finiteNumber(launch.Duration, 2.5) + 1.15, PassReceptionConfig.MinimumContractDuration, PassReceptionConfig.MaximumContractDuration)
	local initialPoint = finiteVector(launch.InitialReceivePoint) and launch.InitialReceivePoint or root(receiver) and (root(receiver) :: BasePart).Position or self.Ball.Position
	local trajectoryId = math.max(0, math.floor(finiteNumber(launch.TrajectoryId, 0)))
	local contract = {
		Id = self.Sequence,
		Revision = 1,
		PassId = math.max(0, math.floor(finiteNumber(launch.PassId, self.Sequence))),
		TrajectoryId = trajectoryId,
		Passer = passer,
		PasserSide = side,
		Receiver = receiver,
		ReceiverSide = side,
		Player = player,
		PassFamily = family,
		ManualPass = manual,
		StartedAt = now,
		ExpiresAt = now + duration,
		InitialReceivePoint = initialPoint,
		LiveInterceptPoint = initialPoint,
		PreviousInterceptPoint = initialPoint,
		BallETA = math.max(0, finiteNumber(launch.InitialETA, duration - 1.15)),
		ReceiverETA = math.huge,
		OpponentETA = math.huge,
		RouteConfidence = math.clamp(finiteNumber(launch.Confidence, 0.7), 0, 1),
		TrajectoryConfidence = trajectoryId > 0 and 1 or 0.72,
		AssistanceMode = assistance,
		AutoSwitchMode = autoSwitch,
		Phase = "Anticipating",
		CameraPrepared = false,
		ControlTransferred = alreadyControlled,
		ControlTransferredAt = alreadyControlled and now or nil,
		ContactStartedAt = nil,
		FirstTouchIntent = nil,
		FirstTouchIntentVector = Vector3.zero,
		QueuedAction = nil,
		ExplicitOverride = false,
		RetargetCount = 0,
		LastRetargetAt = 0,
		LastUpdateAt = now,
		CancelReason = nil,
		CompletedAt = nil,
		Terminal = false,
		PassDistance = finiteNumber(launch.PassDistance, flat(initialPoint - self.Ball.Position).Magnitude),
		InitialDirection = finiteVector(launch.InitialVelocity) and launch.InitialVelocity or self.Ball.AssemblyLinearVelocity,
		LastDirection = finiteVector(launch.InitialVelocity) and launch.InitialVelocity or self.Ball.AssemblyLinearVelocity,
		RouteSprintRequested = false,
		MaterialDeflection = false,
	}
	self.Active = contract
	self.Metrics.Attempted += 1
	self.ByReceiver[receiver] = contract
	if player then self.ByPlayer[player] = contract end
	self:_solve(contract, 1 / PassReceptionConfig.UpdateRate)
	ReceiverMovementService.SetRoute(receiver, contract)
	self:_fire(contract, {Type = "ReceptionStarted", ReceivePoint = initialPoint, Phase = contract.Phase, AssistanceMode = assistance, AutoSwitchMode = autoSwitch, PassFamily = family})
	self:_emit(contract, "playability_reception_started")
	self:_transition(contract, "Committed")
	return contract
end

function Service:_insideBounds(point: Vector3): boolean
	local localPoint = self.PitchCFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= self.Width * 0.5 + 3 and math.abs(localPoint.Z) <= self.Length * 0.5 + 3
end

function Service:_landingETA(contract: any): number
	local active = self.BallService.ActiveTrajectory
	if active and active.Id == contract.TrajectoryId and type(active.Data) == "table" then
		local data = active.Data
		local started = finiteNumber(data.StartServerTime, workspace:GetServerTimeNow())
		local duration = math.max(0.05, finiteNumber(data.Duration, 1))
		return math.max(0.05, started + duration - workspace:GetServerTimeNow())
	end
	return math.max(0.05, finiteNumber(contract.BallETA, 0.6))
end

function Service:_trajectorySamples(contract: any): {any}
	local samples = {}
	local active = self.BallService.ActiveTrajectory
	local serverNow = workspace:GetServerTimeNow()
	local interval = PassReceptionConfig.CandidateInterval
	local horizon = math.min(PassReceptionConfig.CandidateHorizon, math.max(0.4, contract.ExpiresAt - os.clock()))
	if active and active.Id == contract.TrajectoryId and type(active.Data) == "table" then
		local data = active.Data
		local started = finiteNumber(data.StartServerTime, serverNow)
		local duration = math.max(0.05, finiteNumber(data.Duration, 1))
		for future = PassReceptionConfig.MinimumCandidateTime, horizon, interval do
			local alpha = (serverNow + future - started) / duration
			if alpha > 1 then break end
			local point = BallTrajectory.Sample(data, alpha)
			table.insert(samples, {Time = future, Position = point, Velocity = BallTrajectory.Velocity(data, alpha), InsideBounds = self:_insideBounds(point), Confidence = 1})
		end
		local endRemaining = started + duration - serverNow
		if endRemaining < horizon then
			local endPoint = BallTrajectory.Sample(data, 1)
			local endVelocity = BallTrajectory.Velocity(data, 1)
			local rolloutVelocity = self.BallService.PredictPassRolloutVelocity and self.BallService:PredictPassRolloutVelocity(data, endPoint, endVelocity) or endVelocity
			local horizontal = flat(rolloutVelocity)
			for rollout = math.max(interval, interval - endRemaining % interval), math.min(1.2, horizon - math.max(0, endRemaining)), interval do
				local decay = math.exp(-0.42 * rollout)
				local point = endPoint + horizontal * ((1 - decay) / 0.42)
				point = Vector3.new(point.X, endPoint.Y, point.Z)
				table.insert(samples, {Time = math.max(0, endRemaining) + rollout, Position = point, Velocity = horizontal * decay, InsideBounds = self:_insideBounds(point), Confidence = 0.82})
			end
		end
	else
		local position = self.Ball.Position
		local velocity = self.Ball.AssemblyLinearVelocity
		local family = contract.PassFamily
		for future = PassReceptionConfig.MinimumCandidateTime, horizon, interval do
			local decay = math.exp(-0.42 * future)
			local horizontal = flat(velocity) * ((1 - decay) / 0.42)
			local vertical = (family == "Lob" or family == "Cross") and velocity.Y * future - workspace.Gravity * 0.5 * future * future or 0
			local point = position + horizontal + Vector3.yAxis * vertical
			if family ~= "Lob" and family ~= "Cross" then point = Vector3.new(point.X, position.Y, point.Z) end
			table.insert(samples, {Time = future, Position = point, Velocity = flat(velocity) * decay + Vector3.yAxis * (velocity.Y - workspace.Gravity * future), InsideBounds = self:_insideBounds(point), Confidence = 0.66})
		end
	end
	return samples
end

function Service:_movementProfile(model: Model, sprinting: boolean): any
	local maximum = math.max(1, finiteNumber(StaminaConfig.Maximum, 100))
	local energy = math.clamp(finiteNumber(model:GetAttribute("VTRSprintEnergy"), maximum), 0, maximum)
	local legalSprint = sprinting and energy > 0.01 and model:GetAttribute("VTRSprintLocked") ~= true
	local profile = MovementStatsResolver.Resolve(model, {MoveMagnitude = 1, Sprinting = legalSprint, StaminaRatio = energy / maximum, HasBall = false, TurnDot = 1, TurnPenalty = 1, UserControlled = model:GetAttribute("controlledByUser") == true})
	profile.SprintAllowed = legalSprint
	return profile
end

function Service:_opponents(contract: any, target: Vector3): {any}
	local opponents = {}
	local opposite = contract.ReceiverSide == "Home" and "Away" or "Home"
	for _, model in self.Teams[opposite] or {} do
		local modelRoot = root(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if modelRoot and humanoid and humanoid.Health > 0 and model:GetAttribute("VTRSentOff") ~= true and flat(modelRoot.Position - target).Magnitude <= PassReceptionConfig.MaximumNearbyOpponentDistance then
			local movement = self:_movementProfile(model, true)
			table.insert(opponents, {Model = model, Position = modelRoot.Position, Velocity = modelRoot.AssemblyLinearVelocity, Facing = modelRoot.CFrame.LookVector, MaximumSpeed = movement.TargetSpeed, Acceleration = movement.AccelerationRate, ContactTolerance = 2.4, PreparationSeconds = 0.06})
		end
	end
	return opponents
end

function Service:_solve(contract: any, deltaTime: number): any
	local receiver = contract.Receiver
	local receiverRoot = root(receiver)
	local humanoid = receiver:FindFirstChildOfClass("Humanoid")
	if not receiverRoot or not humanoid or humanoid.Health <= 0 then return nil end
	local tuning = PassReceptionConfig.Get(contract.AssistanceMode)
	local jog = self:_movementProfile(receiver, false)
	local sprint = self:_movementProfile(receiver, true)
	local samples = self:_trajectorySamples(contract)
	local target = contract.PassFamily == "Lob" and contract.InitialReceivePoint or contract.LiveInterceptPoint or contract.InitialReceivePoint
	local opponents = self:_opponents(contract, target)
	local started = os.clock()
	local solved = ReceptionInterceptResolver.Resolve({
		PassFamily = contract.PassFamily,
		Samples = samples,
		Receiver = {Position = receiverRoot.Position, Velocity = receiverRoot.AssemblyLinearVelocity, Facing = receiverRoot.CFrame.LookVector, MaximumSpeed = sprint.TargetSpeed, Acceleration = sprint.AccelerationRate, MaximumTurnPenalty = 0.34, PreparationSeconds = PassReceptionConfig.ContactPreparationSeconds, ContactTolerance = tuning.ContactTolerance, Blocked = receiver:GetAttribute("VTRForceIdle") == true},
		Opponents = opponents,
		GroundY = receiverRoot.Position.Y - 3,
		AllowedControlHeight = tuning.AllowedControlHeight,
		ReachSafetySeconds = PassReceptionConfig.ReachSafetySeconds,
		OpponentWinMargin = PassReceptionConfig.OpponentWinMargin,
	})
	self.LastSolverCost = os.clock() - started
	self.SolverSamples = #samples
	self.SolverOpponents = #opponents
	if solved.Point then
		local force = contract.MaterialDeflection == true
		local routePoint = solved.Point
		if contract.PassFamily == "Lob" and finiteVector(contract.InitialReceivePoint) and contract.MaterialDeflection ~= true then
			routePoint = contract.InitialReceivePoint
			solved.BallETA = self:_landingETA(contract)
			solved.Point = routePoint
		end
		contract.PreviousInterceptPoint = contract.LiveInterceptPoint
		contract.LiveInterceptPoint = ReceptionInterceptResolver.Smooth(contract.LiveInterceptPoint, routePoint, deltaTime, tuning.InterceptSmoothing, tuning.MaximumTargetSpeed, force)
		contract.MaterialDeflection = false
		contract.BallETA = solved.BallETA
		contract.ReceiverETA = solved.ReceiverETA
		contract.OpponentETA = solved.OpponentETA
		contract.RouteConfidence = solved.RouteConfidence
		contract.TrajectoryConfidence = solved.TrajectoryConfidence
		local jogETA = ReceptionInterceptResolver.EstimateReachTime({Position = receiverRoot.Position, Velocity = receiverRoot.AssemblyLinearVelocity, Facing = receiverRoot.CFrame.LookVector, Target = solved.Point, MaximumSpeed = jog.TargetSpeed, Acceleration = jog.AccelerationRate, ContactTolerance = tuning.ContactTolerance, PreparationSeconds = PassReceptionConfig.ContactPreparationSeconds})
		local preSwitch = not contract.ControlTransferred
		local sprintAllowed = tuning.AutoSprint == "Required" or tuning.AutoSprint == "ClearlyRequired" or tuning.AutoSprint == "PreSwitchOnly" and preSwitch
		local sprintRequired = jogETA > solved.BallETA - PassReceptionConfig.ReachSafetySeconds
		if tuning.AutoSprint == "ClearlyRequired" then sprintRequired = jogETA > solved.BallETA + 0.06 end
		contract.RouteSprintRequested = sprint.SprintAllowed == true and sprintAllowed and sprintRequired
	end
	return solved
end

function Service:_retarget(contract: any, receiver: Model, reason: string): boolean
	if contract.Terminal or receiver == contract.Receiver or contract.RetargetCount >= PassReceptionConfig.MaximumRetargets then return false end
	if os.clock() - contract.LastRetargetAt < PassReceptionConfig.RetargetHysteresisSeconds then return false end
	if receiver:GetAttribute("VTRTeam") ~= contract.ReceiverSide or not root(receiver) then return false end
	local old = contract.Receiver
	local oldPlayer = contract.Player
	if old and old.Parent and old:GetAttribute("VTRReceptionContractId") == contract.Id then ReceiverMovementService.Clear(old) end
	self.ByReceiver[old] = nil
	if oldPlayer and self.ByPlayer[oldPlayer] == contract then self.ByPlayer[oldPlayer] = nil end
	contract.Receiver = receiver
	contract.Player = self:_playerForReceiver(receiver, contract.ReceiverSide, oldPlayer)
	contract.Revision += 1
	contract.RetargetCount += 1
	self.Metrics.Retargets += 1
	contract.LastRetargetAt = os.clock()
	contract.ControlTransferred = false
	contract.ControlTransferredAt = nil
	contract.CameraPrepared = false
	contract.QueuedAction = nil
	contract.ExplicitOverride = false
	contract.LiveInterceptPoint = root(receiver) and (root(receiver) :: BasePart).Position or contract.LiveInterceptPoint
	self.ByReceiver[receiver] = contract
	if contract.Player then self.ByPlayer[contract.Player] = contract end
	ReceiverMovementService.SetRoute(receiver, contract)
	if oldPlayer and oldPlayer ~= contract.Player and oldPlayer.Parent then
		self.Remote:FireClient(oldPlayer, {Type = "ReceptionCancelled", ContractId = contract.Id, Revision = contract.Revision - 1, Model = old, Reason = "Retargeted"})
	end
	self:_fire(contract, {Type = "ReceptionRetargeted", Model = receiver, PreviousModel = old, Reason = reason, ReceivePoint = contract.LiveInterceptPoint})
	self:_emit(contract, "playability_reception_retargeted", {retargetReason = reason})
	return true
end

function Service:_materialRetarget(contract: any)
	if not contract.MaterialDeflection or contract.ManualPass then return end
	local target = contract.LiveInterceptPoint or self.Ball.Position
	local receiverRoot = root(contract.Receiver)
	if not receiverRoot then return end
	local currentETA = ReceptionInterceptResolver.EstimateReachTime({Position = receiverRoot.Position, Velocity = receiverRoot.AssemblyLinearVelocity, Facing = receiverRoot.CFrame.LookVector, Target = target, MaximumSpeed = self:_movementProfile(contract.Receiver, true).TargetSpeed, Acceleration = 12, ContactTolerance = PassReceptionConfig.Get(contract.AssistanceMode).ContactTolerance})
	local best = nil
	local bestETA = currentETA
	for _, teammate in self.Teams[contract.ReceiverSide] or {} do
		if teammate ~= contract.Receiver then
			local teammateRoot = root(teammate)
			local humanoid = teammate:FindFirstChildOfClass("Humanoid")
			if teammateRoot and humanoid and humanoid.Health > 0 and teammate:GetAttribute("VTRSentOff") ~= true then
				local movement = self:_movementProfile(teammate, true)
				local eta = ReceptionInterceptResolver.EstimateReachTime({Position = teammateRoot.Position, Velocity = teammateRoot.AssemblyLinearVelocity, Facing = teammateRoot.CFrame.LookVector, Target = target, MaximumSpeed = movement.TargetSpeed, Acceleration = movement.AccelerationRate, ContactTolerance = PassReceptionConfig.Get(contract.AssistanceMode).ContactTolerance})
				if eta + PassReceptionConfig.RetargetAdvantageSeconds < bestETA then best = teammate;bestETA = eta end
			end
		end
	end
	if best then self:_retarget(contract, best, "MaterialDeflection") end
end

function Service:_prepareAndTransfer(contract: any)
	local player = contract.Player
	if not player or not player.Parent or contract.ExplicitOverride then return end
	local autoTuning = PassReceptionConfig.Get(contract.AutoSwitchMode)
	local opponentWinning = contract.OpponentETA + PassReceptionConfig.OpponentWinMargin < math.min(contract.ReceiverETA, contract.BallETA)
	local reachable = contract.LiveInterceptPoint ~= nil and contract.ReceiverETA <= contract.BallETA + 0.12 and contract.RouteConfidence >= 0.24 and not opponentWinning
	if autoTuning.CameraPrepareETA >= 0 and reachable and not contract.CameraPrepared and contract.BallETA <= autoTuning.CameraPrepareETA then
		contract.CameraPrepared = true
		self:_transition(contract, "ControlPrepared")
		self:_fire(contract, {Type = "ReceptionCameraPrepare", ReceivePoint = contract.LiveInterceptPoint, BallETA = contract.BallETA, Mode = contract.AutoSwitchMode})
	end
	if contract.ControlTransferred or autoTuning.ControlTransferETA < 0 or not reachable or contract.BallETA > autoTuning.ControlTransferETA then return end
	if self.TeamControl and self.TeamControl.CanReceptionTransfer and not self.TeamControl:CanReceptionTransfer(player, contract.Receiver) then return end
	contract.ControlTransferred = true
	contract.ControlTransferredAt = os.clock()
	self.Metrics.TransferCount += 1
	self.Metrics.TransferETATotal += contract.BallETA
	if self.TeamControl then self.TeamControl:SetActive(player, contract.Receiver, "PassReceiver") end
	self:_fire(contract, {Type = "ReceptionControlTransfer", ReceivePoint = contract.LiveInterceptPoint, BallETA = contract.BallETA})
	self:_emit(contract, "playability_reception_control_transferred", {controlTransferETA = contract.BallETA})
end

function Service:_updateContract(contract: any, deltaTime: number)
	if contract.Terminal then return end
	local now = os.clock()
	local receiver = contract.Receiver
	local humanoid = receiver and receiver:FindFirstChildOfClass("Humanoid")
	if not receiver or not receiver.Parent or not root(receiver) or not humanoid or humanoid.Health <= 0 or receiver:GetAttribute("VTRSentOff") == true then self:_terminal(contract, "Cancelled", "ReceiverInvalid");return end
	if now >= contract.ExpiresAt then self:_terminal(contract, "Cancelled", "ContractExpired");return end
	local activeTrajectory = self.BallService.ActiveTrajectory
	if activeTrajectory and contract.TrajectoryId > 0 and activeTrajectory.Id ~= contract.TrajectoryId then self:_terminal(contract, "Cancelled", "TrajectoryReplaced");return end
	local owner = self.Possession:GetOwner()
	if owner and owner ~= contract.Passer then
		if owner == contract.Receiver then
			self:_terminal(contract, "Completed", "IntendedReceiverControlled")
		elseif owner:GetAttribute("VTRTeam") == contract.ReceiverSide then
			self:_terminal(contract, "Completed", "AlternateTeammateControlled", {actualCollectorRelation = "Teammate"})
		else
			self:_terminal(contract, "Cancelled", tostring(owner:GetAttribute("position") or "") == "GK" and "GoalkeeperClaim" or "OpponentIntercepted")
		end
		return
	end
	local currentDirection = self.Ball.AssemblyLinearVelocity
	local divergence = ReceptionInterceptResolver.DirectionDivergence(contract.LastDirection or contract.InitialDirection, currentDirection)
	local tuning = PassReceptionConfig.Get(contract.AssistanceMode)
	if currentDirection.Magnitude > 3 and divergence >= tuning.CancellationDivergence then contract.MaterialDeflection = true end
	if currentDirection.Magnitude > 3 then contract.LastDirection = currentDirection end
	self:_materialRetarget(contract)
	local solved = self:_solve(contract, deltaTime)
	if not solved or not solved.Point then
		if contract.BallETA <= 0.2 or now - contract.StartedAt > PassReceptionConfig.MinimumContractDuration and self.Ball.AssemblyLinearVelocity.Magnitude < 1 then self:_terminal(contract, "Cancelled", "ReceiverUnreachable") end
		return
	end
	ReceiverMovementService.SetRoute(receiver, contract)
	self:_prepareAndTransfer(contract)
	if now - (contract.LastNetworkUpdateAt or 0) >= 0.18 then
		contract.LastNetworkUpdateAt = now
		self:_fire(contract, self:_snapshot(contract))
	end
end

function Service:Step(deltaTime: number)
	self.Accumulator += math.max(0, deltaTime)
	local interval = 1 / PassReceptionConfig.UpdateRate
	if self.Accumulator < interval then return end
	local elapsed = math.min(self.Accumulator, 0.2)
	self.Accumulator = 0
	local contract = self.Active
	if contract then self:_updateContract(contract, elapsed) end
end

function Service:_identity(player: Player, model: Model, contractId: any, revision: any, clientTimestamp: any): any?
	local contract = self.ByPlayer[player]
	if not contract or contract.Terminal or contract.Receiver ~= model then return nil end
	if contractId == nil or math.floor(finiteNumber(contractId, -1)) ~= contract.Id then return nil end
	if revision == nil or math.floor(finiteNumber(revision, -1)) ~= contract.Revision then return nil end
	if clientTimestamp == nil or math.abs(workspace:GetServerTimeNow() - finiteNumber(clientTimestamp, -math.huge)) > PassReceptionConfig.InputTimestampWindow then return nil end
	return contract
end

function Service:_rate(player: Player, key: string, seconds: number): boolean
	local now = os.clock()
	local playerRates = self.InputAt[player]
	if not playerRates then playerRates = {};self.InputAt[player] = playerRates end
	if now - (finiteNumber(playerRates[key], -math.huge)) < seconds then return false end
	playerRates[key] = now
	return true
end

function Service:HandleMovement(player: Player, model: Model, direction: Vector3, contractId: any, revision: any, clientTimestamp: any): (Vector3, number, boolean)
	local contract = self:_identity(player, model, contractId, revision, clientTimestamp)
	if not contract or not contract.ControlTransferred or not finiteVector(direction, 1.1) then return direction, 0, false end
	if not self:_rate(player, "Move", PassReceptionConfig.InputRateSeconds) then
		local target = contract.LiveInterceptPoint
		if target and not contract.ExplicitOverride and contract.AssistanceMode ~= "Manual" then return ReceiverMovementService.RouteDirection(model, target), 1, true end
		return direction, 0, false
	end
	local input = flat(direction)
	if input.Magnitude > 1 then input = input.Unit end
	contract.FirstTouchIntentVector = input
	if input.Magnitude > 0.08 then
		model:SetAttribute("VTRFirstTouchIntentVector", input)
		if not contract.FirstTouchIntentRecorded then
			contract.FirstTouchIntentRecorded = true
			self:_emit(contract, "playability_first_touch_intent", {inputReinterpretedAsFirstTouch = contract.AssistanceMode ~= "Manual"})
		end
	end
	if contract.ExplicitOverride or contract.AssistanceMode == "Manual" then return input, 0, false end
	local tuning = PassReceptionConfig.Get(contract.AssistanceMode)
	local route = ReceiverMovementService.RouteDirection(model, contract.LiveInterceptPoint)
	local takeoverThreshold = math.min(tuning.DecisiveInputThreshold, 0.72)
	if input.Magnitude >= takeoverThreshold then
		contract.ExplicitOverride = true
		self.Metrics.Overrides += 1
		self:_emit(contract, "playability_reception_override", {overrideKind = "AutomaticDecisiveInput"})
		return input, 0, false
	end
	local movement, assisted = ReceiverMovementService.BlendUserMovement(model, contract.LiveInterceptPoint, input, tuning.PostSwitchRouteWeight, tuning.UserRouteInfluence)
	return movement, assisted, true
end

function Service:SetOverride(player: Player, model: Model, active: boolean, contractId: any, revision: any, clientTimestamp: any): boolean
	local contract = self:_identity(player, model, contractId, revision, clientTimestamp)
	if not contract or not contract.ControlTransferred or not self:_rate(player, "Override", PassReceptionConfig.OverrideRateSeconds) then return false end
	if active then
		contract.ExplicitOverride = true
		contract.QueuedAction = nil
		self.Metrics.Overrides += 1
		self:_emit(contract, "playability_reception_override", {overrideKind = "LegacyExplicit"})
	end
	return true
end

function Service:QueueAction(player: Player, model: Model, payload: any): boolean
	local contract = self:_identity(player, model, payload.ReceptionContractId, payload.ReceptionRevision, payload.ReceptionClientTime)
	if not contract or not contract.ControlTransferred or not self:_rate(player, "Action", PassReceptionConfig.ActionRateSeconds) then return false end
	local action = tostring(payload.Type or "")
	if action ~= "Pass" and action ~= "Shot" or not finiteVector(payload.Direction, 1.1) then return false end
	if payload.AimPosition ~= nil and not finiteVector(payload.AimPosition, 100000) then return false end
	local target = payload.TargetModel
	if target ~= nil then
		if typeof(target) ~= "Instance" or not target:IsA("Model") or target:GetAttribute("VTRTeam") ~= contract.ReceiverSide then return false end
		local found = false
		for _, teammate in self.Teams[contract.ReceiverSide] or {} do if teammate == target then found = true;break end end
		if not found then return false end
	end
	contract.QueuedAction = {Payload = copyAction(payload), CreatedAt = os.clock(), ExpiresAt = os.clock() + PassReceptionConfig.QueuedActionMaximumSeconds, ContractId = contract.Id, Revision = contract.Revision, Receiver = model}
	model:SetAttribute("VTRReceptionQueuedAction", action)
	self:_fire(contract, {Type = "ReceptionQueuedAction", Action = action})
	self:_emit(contract, "playability_first_time_action", {firstTimeAction = action, actionState = "Queued"})
	return true
end

function Service:_firstTouch(contract: any, receiver: Model, incomingVelocity: Vector3): (string, Vector3)
	local receiverRoot = root(receiver)
	if not receiverRoot then return "Stop", Vector3.zero end
	local tuning = PassReceptionConfig.Get(contract.AssistanceMode)
	local queued = contract.QueuedAction
	if queued and queued.ContractId == contract.Id and queued.Revision == contract.Revision and queued.Receiver == receiver and os.clock() <= queued.ExpiresAt then
		return queued.Payload.Type == "Shot" and "FirstTimeShot" or "FirstTimePass", incomingVelocity
	end
	contract.QueuedAction = nil
	local intent = flat(contract.FirstTouchIntentVector or Vector3.zero)
	local forward = flat(receiverRoot.CFrame.LookVector)
	local right = flat(receiverRoot.CFrame.RightVector)
	if intent.Magnitude <= 0.12 and receiver:GetAttribute("VTRUserSprintRequested") == true and forward.Magnitude > 0.05 then intent = forward.Unit end
	if intent.Magnitude <= 0.12 then return "Stop", incomingVelocity * (0.3 - tuning.FirstTouchAssistance * 0.18) end
	intent = intent.Unit
	local forwardDot = forward.Magnitude > 0.05 and intent:Dot(forward.Unit) or 1
	local sideDot = right.Magnitude > 0.05 and intent:Dot(right.Unit) or 0
	local style = forwardDot < -0.42 and "TurnAway" or math.abs(sideDot) > 0.52 and (sideDot > 0 and "CarryRight" or "CarryLeft") or "CarryForward"
	local incomingSpeed = flat(incomingVelocity).Magnitude
	local carrySpeed = math.clamp(incomingSpeed * (0.24 - tuning.FirstTouchAssistance * 0.08) + (receiver:GetAttribute("VTRUserSprintRequested") == true and 2.5 or 0), 4, 11)
	local receiverVelocity = flat(receiverRoot.AssemblyLinearVelocity)
	return style, receiverVelocity * (0.48 + tuning.FirstTouchAssistance * 0.16) + intent * carrySpeed
end

function Service:HandleContact(model: Model, evaluation: any, contactPosition: Vector3, incomingVelocity: Vector3): boolean
	local contract = self.Active
	if not contract or contract.Terminal or not evaluation or evaluation.Valid ~= true then return false end
	local side = tostring(model:GetAttribute("VTRTeam") or "")
	if side ~= contract.ReceiverSide then
		local reason = evaluation.Outcome == "Controlled" and (tostring(model:GetAttribute("position") or "") == "GK" and "GoalkeeperClaim" or "OpponentIntercepted") or "BallDeflectedLoose"
		self:_terminal(contract, "Cancelled", reason, {actualCollectorRelation = "Opponent"})
		return false
	end
	local completionReason = "IntendedReceiverControlled"
	if model ~= contract.Receiver then
		if not self:_retarget(contract, model, "ActualContact") then return false end
		completionReason = "AlternateTeammateControlled"
	end
	if evaluation.Outcome ~= "Controlled" then
		self:_terminal(contract, "Cancelled", "BallDeflectedLoose", {actualCollectorRelation = model == contract.Receiver and "Intended" or "Teammate"})
		return false
	end
	contract.ContactStartedAt = os.clock()
	local relativeHeight = finiteNumber(evaluation.RelativeHeight, 0)
	local contactKind = tostring(evaluation.ContactKind or (relativeHeight >= 4.8 and "Header" or relativeHeight >= 3.35 and "Chest" or relativeHeight >= 2.25 and "Thigh" or tostring(model:GetAttribute("PreferredFoot") or "Right") == "Left" and "LeftFoot" or "RightFoot"))
	self:_transition(contract, "ContactWindow", {contactDistanceBand = distanceBand(finiteNumber(evaluation.ContactDistance, 0)), contactHeightBand = distanceBand(math.abs(finiteNumber(evaluation.RelativeHeight, 0)))})
	self:_fire(contract, {Type = "ReceptionContact", Model = model, ContactPoint = contactPosition, ContactKind = contactKind})
	local style, touchVelocity = self:_firstTouch(contract, model, incomingVelocity)
	contract.FirstTouchIntent = style
	self:_transition(contract, "FirstTouch")
	if self.BallService.Animations then self.BallService.Animations:PlayAction(model, contactKind == "Header" and "Header" or "Receive") end
	if self.BallService.ResolveReceptionPickup and not self.BallService:ResolveReceptionPickup(model, touchVelocity, completionReason) then
		self:_terminal(contract, "Cancelled", "BallDeflectedLoose")
		return false
	end
	model:SetAttribute("VTRFirstTouchStyle", style)
	model:SetAttribute("VTRReceiveContactKind", contactKind)
	local receivedAt = os.clock()
	model:SetAttribute("VTRReceivedAt", receivedAt)
	model:SetAttribute("VTRImmediateControlUntil", os.clock() + 0.25)
	self.Remote:FireAllClients({Type = "FirstTouch", Actor = model, Mode = contract.AssistanceMode, Outcome = style, ContactKind = contactKind})
	task.delay(0.5, function()
		if model.Parent and tonumber(model:GetAttribute("VTRReceivedAt")) == receivedAt then
			model:SetAttribute("VTRFirstTouchStyle", nil)
			model:SetAttribute("VTRReceiveContactKind", nil)
		end
	end)
	if self.TeamControl and contract.Player then self.TeamControl:OnReceptionCollector(contract.Player, model, completionReason, contract.AutoSwitchMode) end
	local queued = contract.QueuedAction
	local terminalReason = style == "FirstTimePass" and "FirstTimePass" or style == "FirstTimeShot" and "FirstTimeShot" or completionReason
	self:_terminal(contract, "Completed", terminalReason, {firstTouchIntent = style, actualCollectorRelation = completionReason == "IntendedReceiverControlled" and "Intended" or "Teammate"})
	if queued and (style == "FirstTimePass" or style == "FirstTimeShot") and self.TeamControl and contract.Player then
		local action = copyAction(queued.Payload)
		task.defer(function()
			if model.Parent and self.Possession:GetOwner() == model then self.TeamControl:Handle(contract.Player, action) end
		end)
	end
	return true
end

function Service:MarkTrajectoryDeflected(trajectoryId: number?, reason: string?)
	local contract = self.Active
	if not contract or contract.Terminal then return end
	if trajectoryId and contract.TrajectoryId > 0 and trajectoryId ~= contract.TrajectoryId then return end
	contract.MaterialDeflection = true
	contract.TrajectoryConfidence = math.min(contract.TrajectoryConfidence or 1, 0.52)
	self:_emit(contract, "playability_reception_route_conflict", {conflictReason = tostring(reason or "Deflection")})
end

function Service:GetContractForReceiver(receiver: Model): any?
	return self.ByReceiver[receiver]
end

function Service:GetContactTuning(model: Model): any?
	local contract = self.ByReceiver[model]
	if not contract or contract.Terminal then return nil end
	local tuning = PassReceptionConfig.Get(contract.AssistanceMode)
	return {Tolerance = tuning.ContactTolerance, ControlHeight = tuning.AllowedControlHeight, Expected = model == contract.Receiver}
end

function Service:GetDiagnostics(): any
	local contract = self.Active
	local metrics = table.clone(self.Metrics)
	metrics.AverageTransferETA = metrics.TransferCount > 0 and metrics.TransferETATotal / metrics.TransferCount or 0
	return {
		ActiveContractCount = contract and 1 or 0,
		SolverCost = self.LastSolverCost,
		CandidateSampleCount = self.SolverSamples,
		NearbyOpponentCount = self.SolverOpponents,
		RouteTarget = contract and contract.LiveInterceptPoint or nil,
		BallETA = contract and contract.BallETA or nil,
		ReceiverETA = contract and contract.ReceiverETA or nil,
		OpponentETA = contract and contract.OpponentETA or nil,
		Phase = contract and contract.Phase or nil,
		CancelReason = contract and contract.CancelReason or nil,
		Summary = metrics,
	}
end

function Service:Destroy()
	if self.Active then self:_terminal(self.Active, "Cancelled", "MatchInterrupted") end
	for receiver in self.ByReceiver do if receiver.Parent then ReceiverMovementService.Clear(receiver) end end
	table.clear(self.ByReceiver)
	table.clear(self.ByPlayer)
	table.clear(self.NextPass)
	table.clear(self.InputAt)
	table.clear(self.TerminalIds)
	table.clear(self.TerminalOrder)
	self.Active = nil
end

return Service
