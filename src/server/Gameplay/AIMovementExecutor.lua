--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StaminaConfig = require(ReplicatedStorage.VTR.Shared.StaminaConfig)
local MovementStatsResolver = require(ReplicatedStorage.VTR.Shared.MovementStatsResolver)
local StaminaService = require(script.Parent.StaminaService)
local Service = {}
Service.__index = Service

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Service.new()
	return setmetatable({Commands = {}, Stamina = StaminaService.new()}, Service)
end

function Service:SetTarget(model: Model, target: Vector3, urgency: number)
	local now = os.clock()
	local modelRoot = root(model)
	local command = self.Commands[model]
	if not command then
		command = {Target = target, Urgency = urgency, LastPosition = modelRoot and modelRoot.Position or target, CheckAt = now, LastCommandAt = 0, StuckCount = 0, IsStuck = false, LastDirection = Vector3.new(0, 0, -1)}
		self.Commands[model] = command
	else
		if (command.Target - target).Magnitude > 2.5 then
			command.IsStuck = false
			command.StuckCount = 0
			command.CheckAt = now
			command.LastPosition = modelRoot and modelRoot.Position or target
		end
		command.Target = target
		command.Urgency = urgency
	end
	model:SetAttribute("movementTarget", target)
	model:SetAttribute("executingMovement", true)
end

function Service:Clear(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero, false) end
	self.Commands[model] = nil
	model:SetAttribute("VTRMoveDirection", nil)
	model:SetAttribute("isStuck", false)
	model:SetAttribute("executingMovement", false)
end

function Service:Step(dt: number)
	local now = os.clock()
	for model, command in self.Commands do
		if not model.Parent or (model:GetAttribute("controlledByUser") == true and model:GetAttribute("aiControlled") ~= true) then
			self:Clear(model)
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local modelRoot = root(model)
		if not humanoid or not modelRoot or humanoid.Health <= 0 then
			self.Commands[model] = nil
			continue
		end
		if model:GetAttribute("VTRForceIdle") == true then
			humanoid.WalkSpeed = 0
			humanoid:Move(Vector3.zero, false)
			modelRoot.AssemblyLinearVelocity = Vector3.zero
			modelRoot.AssemblyAngularVelocity = Vector3.zero
			model:SetAttribute("VTRSprinting", false)
			model:SetAttribute("executingMovement", false)
			continue
		end
		if(tonumber(model:GetAttribute("VTRStunnedUntil"))or 0)>now or model:GetAttribute("VTRRedCard")==true then
			humanoid.WalkSpeed=0;humanoid:Move(Vector3.zero,false);modelRoot.AssemblyLinearVelocity=Vector3.zero;continue
		end
		if model:GetAttribute("VTRGoalkeeperSaving")==true then
			continue
		end
		local offset = command.Target - modelRoot.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local distance = flat.Magnitude
		local hasBall = model:GetAttribute("VTRHasBall") == true
		local receiving = model:GetAttribute("VTRPreparingReceive") == true
		local velocity = Vector3.new(modelRoot.AssemblyLinearVelocity.X, 0, modelRoot.AssemblyLinearVelocity.Z)
		local direction: Vector3
		if distance > 0.2 then
			direction = flat.Unit
			command.LastDirection = direction
		elseif velocity.Magnitude > 0.5 then
			direction = velocity.Unit
			command.LastDirection = direction
		else
			local team = tostring(model:GetAttribute("VTRTeam") or "Home")
			direction = command.LastDirection or Vector3.new(0, 0, team == "Home" and -1 or 1)
			if direction.Magnitude < 0.1 then
				direction = Vector3.new(0, 0, team == "Home" and -1 or 1)
			end
		end
		local staminaMax = tonumber(StaminaConfig.Maximum) or 100
		local moving = distance > 0.6 or hasBall or receiving or command.Urgency >= 0.45
		local reserve,_,sprinting=self.Stamina:Step(model,dt,{SprintRequested=moving and command.Urgency>=0.48,SprintAllowed=true,MoveMagnitude=moving and 1 or 0,CurrentSpeed=velocity.Magnitude,HasBall=hasBall,UserControlled=false,Frozen=model:GetAttribute("VTRForceIdle")==true,Stunned=(tonumber(model:GetAttribute("VTRStunnedUntil"))or 0)>now})
		local resolved = MovementStatsResolver.Resolve(model, {MoveMagnitude = moving and 1 or 0, Sprinting = sprinting, StaminaRatio = reserve / staminaMax, HasBall = hasBall, TurnDot = 1, TurnPenalty = 1, UserControlled = false})
		local previousSpeed = tonumber(command.Speed) or 0
		local rate = resolved.TargetSpeed > previousSpeed and resolved.AccelerationRate or resolved.DecelerationRate
		command.Speed = previousSpeed + math.clamp(resolved.TargetSpeed - previousSpeed, -rate * dt, rate * dt)
		humanoid.WalkSpeed = math.max(0.1, command.Speed)
		model:SetAttribute("distanceToTarget", distance)
		model:SetAttribute("currentSpeed", Vector3.new(modelRoot.AssemblyLinearVelocity.X, 0, modelRoot.AssemblyLinearVelocity.Z).Magnitude)
		model:SetAttribute("isStuck", command.IsStuck)
		model:SetAttribute("lastMoveCommandTime", command.LastCommandAt)
		model:SetAttribute("VTRMoveDirection", direction)
		model:SetAttribute("executingMovement", true)
		if not moving then
			humanoid:Move(Vector3.zero, false)
			if now - command.LastCommandAt >= 0.45 then
				humanoid:MoveTo(modelRoot.Position)
				command.LastCommandAt = now
			end
			continue
		end
		-- Direct steering is issued every heartbeat. MoveTo is reissued at a
		-- lower rate so the Humanoid has both a persistent destination and a
		-- reliable fallback direction on simple football pitches.
		humanoid:Move(direction, false)
		if now - command.LastCommandAt >= (command.IsStuck and 0.12 or 0.32) then
			local moveToTarget = distance <= 1.35 and modelRoot.Position + direction * 6 or Vector3.new(command.Target.X, modelRoot.Position.Y, command.Target.Z)
			humanoid:MoveTo(moveToTarget)
			command.LastCommandAt = now
		end
		local urgentRun = command.Urgency >= 0.88
		if now - command.CheckAt >= (urgentRun and 0.55 or 1.5) then
			local moved = (modelRoot.Position - command.LastPosition).Magnitude
			command.IsStuck = moved < (urgentRun and 0.55 or 1) and distance > (urgentRun and 3 or 4)
			command.StuckCount = command.IsStuck and command.StuckCount + 1 or 0
			command.LastPosition = modelRoot.Position
			command.CheckAt = now
			if command.StuckCount >= (urgentRun and 1 or 2) then
				local fallbackSpeed = math.min(humanoid.WalkSpeed, 14 + command.Urgency * 4)
				modelRoot.AssemblyLinearVelocity = Vector3.new(direction.X * fallbackSpeed, modelRoot.AssemblyLinearVelocity.Y, direction.Z * fallbackSpeed)
				humanoid:Move(direction, false)
				humanoid:MoveTo(modelRoot.Position + direction * math.max(10, distance))
			end
		end
	end
end

function Service:Destroy()
	for model in self.Commands do
		self:Clear(model)
	end
	table.clear(self.Commands)
end

return Service
