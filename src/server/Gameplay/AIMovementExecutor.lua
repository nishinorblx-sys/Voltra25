--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StaminaConfig = require(ReplicatedStorage.VTR.Shared.StaminaConfig)
local MovementStatsResolver = require(ReplicatedStorage.VTR.Shared.MovementStatsResolver)
local Service = {}
Service.__index = Service

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Service.new()
	return setmetatable({Commands = {}, Bursts = {}}, Service)
end

function Service:SetCommand(model: Model, payload: any)
	local target = typeof(payload.Target) == "Vector3" and payload.Target or (root(model) and root(model).Position or Vector3.zero)
	local now = os.clock()
	local command = self.Commands[model]
	if not command then
		command = {LastPosition = root(model) and root(model).Position or target, CheckAt = now, LastCommandAt = 0, StuckCount = 0, IsStuck = false, LastDirection = Vector3.zAxis, Speed = 0}
		self.Commands[model] = command
	elseif command.Target and (command.Target - target).Magnitude > 2.5 then
		command.IsStuck, command.StuckCount, command.CheckAt = false, 0, now
		command.LastPosition = root(model) and root(model).Position or target
	end
	for key, value in payload do command[key] = value end
	command.Target = target
	command.Urgency = math.clamp(tonumber(payload.Urgency) or 0.7, 0, 1)
	model:SetAttribute("movementTarget", target)
	model:SetAttribute("executingMovement", true)
end

function Service:Clear(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero, false) end
	self.Commands[model], self.Bursts[model] = nil, nil
	model:SetAttribute("VTRMoveDirection", nil)
	model:SetAttribute("VTRMoveMagnitude", 0)
	model:SetAttribute("VTRAISprintRequested", false)
	model:SetAttribute("isStuck", false)
	model:SetAttribute("executingMovement", false)
end

function Service:_sprint(model: Model, command: any, now: number, moving: boolean): boolean
	if not moving or command.LocomotionMode ~= "SprintBurst" or command.SprintAllowed ~= true or command.SprintRequired ~= true then return false end
	if model:GetAttribute("VTRForceIdle") == true or model:GetAttribute("VTRFrozenIdle") == true or model:GetAttribute("VTRSprintLocked") == true or (tonumber(model:GetAttribute("VTRStunnedUntil")) or 0) > now then return false end
	local staminaMax = tonumber(StaminaConfig.Maximum) or 100
	local energy = math.clamp(tonumber(model:GetAttribute("VTRSprintEnergy")) or staminaMax, 0, staminaMax)
	local burst = self.Bursts[model]
	if not burst or burst.Ticket ~= command.RunTicketId then
		if burst and now < (burst.CooldownUntil or 0) then return false end
		if energy < (tonumber(command.MinimumEnergy) or 100) then return false end
		burst = {Ticket = command.RunTicketId, StartedAt = now, CooldownUntil = 0}
		self.Bursts[model] = burst
	elseif (burst.CooldownUntil or 0) > 0 then
		if now < burst.CooldownUntil or energy < (tonumber(command.MinimumEnergy) or 100) then return false end
		burst.StartedAt = now
		burst.CooldownUntil = 0
	end
	if now - burst.StartedAt > math.max(tonumber(command.BurstMaximumSeconds) or 0, 0) then
		burst.CooldownUntil = now + math.max(tonumber(command.RecoveryMinimumSeconds) or 0, 0)
		return false
	end
	return energy > 0
end

function Service:Step(dt: number)
	local now = os.clock()
	for model, command in self.Commands do
		if not model.Parent or (model:GetAttribute("controlledByUser") == true and model:GetAttribute("aiControlled") ~= true) then self:Clear(model);continue end
		local humanoid, modelRoot = model:FindFirstChildOfClass("Humanoid"), root(model)
		if not humanoid or not modelRoot or humanoid.Health <= 0 then self.Commands[model] = nil;continue end
		if model:GetAttribute("VTRForceIdle") == true or model:GetAttribute("VTRFrozenIdle") == true then
			humanoid.WalkSpeed = 0;humanoid:Move(Vector3.zero, false);modelRoot.AssemblyLinearVelocity = Vector3.zero
			model:SetAttribute("VTRMoveMagnitude", 0);model:SetAttribute("VTRAISprintRequested", false);continue
		end
		if (tonumber(model:GetAttribute("VTRStunnedUntil")) or 0) > now or model:GetAttribute("VTRRedCard") == true then
			humanoid.WalkSpeed = 0;humanoid:Move(Vector3.zero, false);modelRoot.AssemblyLinearVelocity = Vector3.zero;model:SetAttribute("VTRAISprintRequested", false);continue
		end
		if model:GetAttribute("VTRGoalkeeperSaving") == true then continue end
		if modelRoot.Anchored then
			modelRoot.Anchored = false
			modelRoot.AssemblyLinearVelocity = Vector3.zero
			modelRoot.AssemblyAngularVelocity = Vector3.zero
		end
		if humanoid.PlatformStand or humanoid.Sit then
			humanoid.PlatformStand = false
			humanoid.Sit = false
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		humanoid.AutoRotate = true
		local offset = command.Target - modelRoot.Position
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		local distance = horizontal.Magnitude
		local velocity = Vector3.new(modelRoot.AssemblyLinearVelocity.X, 0, modelRoot.AssemblyLinearVelocity.Z)
		local receiving = model:GetAttribute("VTRPreparingReceive") == true and typeof(model:GetAttribute("VTRReceiveTarget")) == "Vector3"
		local assignmentId = tostring(command.AssignmentId or "")
		local chasingLoose = assignmentId:find("ChaseLooseBall", 1, true) ~= nil or assignmentId:find("CoverLooseBall", 1, true) ~= nil or assignmentId:find("AttackLooseBall", 1, true) ~= nil or assignmentId:find("DangerZoneLooseBallRecovery", 1, true) ~= nil or assignmentId:find("ShotGoalkeeperClaim", 1, true) ~= nil
		local ballETA = tonumber(model:GetAttribute("VTRReceiveBallETA")) or math.huge
		local faceTarget = typeof(command.FaceTarget) == "Vector3" and command.FaceTarget or nil
		local faceOffset = faceTarget and Vector3.new(faceTarget.X - modelRoot.Position.X, 0, faceTarget.Z - modelRoot.Position.Z) or Vector3.zero
		local microDirection = faceOffset.Magnitude > 0.2 and faceOffset.Unit or command.LastDirection
		local direction = distance > (receiving and 0.08 or 0.2) and horizontal.Unit or receiving and ballETA < 1.2 and microDirection or velocity.Magnitude > 0.5 and velocity.Unit or command.LastDirection
		if direction.Magnitude < 0.1 then direction = Vector3.zAxis end
		command.LastDirection = direction
		local mode = tostring(command.LocomotionMode or "Jog")
		local moveThreshold = (receiving or chasingLoose) and 0.08 or 0.6
		local moving = mode ~= "Idle" and (distance > moveThreshold or (receiving or chasingLoose) and faceOffset.Magnitude > 0.2)
		local sprintRequested = self:_sprint(model, command, now, moving)
		model:SetAttribute("VTRMoveMagnitude", moving and 1 or 0)
		model:SetAttribute("VTRAISprintRequested", sprintRequested)
		local staminaMax = tonumber(StaminaConfig.Maximum) or 100
		local reserve = math.clamp(tonumber(model:GetAttribute("VTRSprintEnergy")) or staminaMax, 0, staminaMax)
		local resolved = MovementStatsResolver.Resolve(model, {MoveMagnitude = moving and 1 or 0, Sprinting = sprintRequested, StaminaRatio = reserve / staminaMax, HasBall = model:GetAttribute("VTRHasBall") == true, TurnDot = 1, TurnPenalty = 1, UserControlled = false})
		local multiplier = mode == "Walk" and 0.58 or mode == "Jog" and 0.76 or 1
		local targetSpeed = resolved.TargetSpeed * multiplier
		local rate = targetSpeed > command.Speed and resolved.AccelerationRate or resolved.DecelerationRate
		command.Speed += math.clamp(targetSpeed - command.Speed, -rate * dt, rate * dt)
		humanoid.WalkSpeed = math.max(0.1, command.Speed)
		model:SetAttribute("distanceToTarget", distance);model:SetAttribute("currentSpeed", velocity.Magnitude);model:SetAttribute("isStuck", command.IsStuck);model:SetAttribute("VTRMoveDirection", direction);model:SetAttribute("executingMovement", true)
		if not moving then humanoid:Move(Vector3.zero, false);continue end
		humanoid:Move(direction, false)
		local commandInterval = receiving and 0.08 or command.IsStuck and 0.12 or 0.32
		if now - command.LastCommandAt >= commandInterval then humanoid:MoveTo(distance <= 1.35 and modelRoot.Position + direction * (receiving and 2.5 or 6) or command.Target);command.LastCommandAt = now end
		if now - command.CheckAt >= 0.7 then
			local moved = (modelRoot.Position - command.LastPosition).Magnitude
			command.IsStuck = moved < 0.65 and distance > 4
			command.StuckCount = command.IsStuck and command.StuckCount + 1 or 0
			command.LastPosition, command.CheckAt = modelRoot.Position, now
		end
	end
end

function Service:Destroy()
	for model in self.Commands do self:Clear(model) end
	table.clear(self.Commands);table.clear(self.Bursts)
end

return Service
