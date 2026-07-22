--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReceptionInterceptResolver = require(ReplicatedStorage.VTR.Shared.ReceptionInterceptResolver)

local Planner = {}

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

local function root(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stat(model: Model?, name: string, fallback: number): number
	return math.clamp(tonumber(model and model:GetAttribute(name)) or fallback, 1, 99)
end

local function eta(model: Model?, target: Vector3, speed: number, acceleration: number, tolerance: number): number
	local modelRoot = root(model)
	if not modelRoot then return math.huge end
	return ReceptionInterceptResolver.EstimateReachTime({
		Position = modelRoot.Position,
		Velocity = modelRoot.AssemblyLinearVelocity,
		Facing = modelRoot.CFrame.LookVector,
		Target = target,
		MaximumSpeed = speed,
		Acceleration = acceleration,
		ContactTolerance = tolerance,
		PreparationSeconds = .08,
	})
end

local function movement(model: Model?, sprintEnergy: number?): any
	local pace = stat(model, "PAC", 62)
	local control = stat(model, "BallControl", stat(model, "DRI", 62))
	local energy = math.clamp((sprintEnergy or tonumber(model and model:GetAttribute("VTRSprintEnergy")) or 100) / 100, .25, 1)
	local jog = 11.5 + pace * .045
	local run = 15.5 + pace * .08
	local sprint = (20 + pace * .105) * math.clamp(.72 + energy * .28, .72, 1)
	local acceleration = 8.5 + pace * .075 + control * .025
	local tolerance = 2.1 + math.clamp((control - 55) * .018, -.3, .85)
	return {Jog = jog, Run = run, Sprint = sprint, Acceleration = acceleration, Tolerance = tolerance, Control = control, Energy = energy}
end

local function routeIntercept(receiver: Model, target: Vector3, ballPosition: any, ballETA: number): (Vector3, number)
	if typeof(ballPosition) ~= "Vector3" then return target, ballETA end
	local modelRoot = root(receiver)
	if not modelRoot then return target, ballETA end
	local segment = flat(target - ballPosition)
	local remaining = segment.Magnitude
	if remaining < 12 then return target, ballETA end
	local direction = segment.Unit
	local receiverOffset = flat(modelRoot.Position - ballPosition)
	local receiverAlong = math.clamp(receiverOffset:Dot(direction), 0, remaining)
	local lateral = math.max(0, (receiverOffset - direction * receiverAlong).Magnitude)
	local velocity = flat(modelRoot.AssemblyLinearVelocity)
	local speedLead = math.max(0, velocity:Dot(direction)) * .16
	local lead = math.clamp(7 + lateral * .18 + speedLead, 6, 22)
	local finalBuffer = math.clamp(remaining * .28, 6, 18)
	local minAlong = math.min(remaining, 5)
	local maxAlong = math.max(minAlong, remaining - finalBuffer)
	local desiredAlong = math.clamp(receiverAlong + lead, minAlong, maxAlong)
	local point = ballPosition + direction * desiredAlong
	local etaAtPoint = ballETA * math.clamp(desiredAlong / remaining, .08, 1)
	return Vector3.new(point.X, target.Y, point.Z), etaAtPoint
end

function Planner.Solve(input: any): any
	local receiver = input.ReceiverModel or input.Receiver and input.Receiver.Model
	local target = input.Target
	if typeof(target) ~= "Vector3" or not receiver then return nil end
	local ballETA = math.max(.05, tonumber(input.BallETA) or .8)
	local passFamily = tostring(input.PassFamily or "Ground")
	local profile = movement(receiver, input.SprintEnergy)
	local interceptPoint, interceptETA = routeIntercept(receiver, target, input.BallPosition, ballETA)
	local jogETA = eta(receiver, interceptPoint, profile.Jog, profile.Acceleration, profile.Tolerance)
	local runETA = eta(receiver, interceptPoint, profile.Run, profile.Acceleration, profile.Tolerance)
	local sprintETA = eta(receiver, interceptPoint, profile.Sprint, profile.Acceleration, profile.Tolerance)
	local selected = "Jog"
	local selectedETA = jogETA
	if jogETA > interceptETA - .2 then
		selected = "Run"
		selectedETA = runETA
	end
	if selectedETA > interceptETA + .05 then
		selected = "SprintBurst"
		selectedETA = sprintETA
	end
	local deficit = selectedETA - interceptETA
	local reachable = selectedETA <= interceptETA + .35
	if deficit > .35 then
		reachable = false
	end
	local rootPart = root(receiver)
	local currentVelocity = rootPart and flat(rootPart.AssemblyLinearVelocity).Magnitude or 0
	local desiredSpeed
	local contactKind = "FrontFoot"
	local firstTouch = "Stop"
	if passFamily == "Through" then
		desiredSpeed = profile.Run * .82
		contactKind = "Carry"
		firstTouch = "CarryForward"
	elseif passFamily == "Lofted" or passFamily == "Lob" or passFamily == "FarPostCross" then
		desiredSpeed = 3
		contactKind = "Aerial"
		firstTouch = "Stop"
	else
		desiredSpeed = deficit < -.2 and 2.5 or deficit < .08 and 5.5 or 7
		firstTouch = desiredSpeed > 5 and "Carry" or "Stop"
	end
	local deceleration = 24
	local brakingDistance = math.max(0, (currentVelocity * currentVelocity - desiredSpeed * desiredSpeed) / (2 * deceleration))
	local modelRoot = rootPart
	local facingTarget = target
	if modelRoot then
		local attack = input.AttackDirection
		if typeof(attack) == "Vector3" and attack.Magnitude > .01 and passFamily ~= "Ground" then
			facingTarget = modelRoot.Position + attack.Unit * 12
		elseif typeof(input.BallPosition) == "Vector3" then
			facingTarget = input.BallPosition
		end
	end
	local preferredFoot = tostring(receiver:GetAttribute("PreferredFoot") or "Right")
	if typeof(input.NearestPressure) == "Vector3" and modelRoot then
		local pressure = flat(input.NearestPressure - modelRoot.Position)
		if pressure.Magnitude > .1 then
			local localRight = flat(modelRoot.CFrame.RightVector)
			preferredFoot = pressure.Unit:Dot(localRight) > 0 and "Left" or "Right"
		end
	end
	local opponentETA = tonumber(input.OpponentETA) or math.huge
	return {
		Target = target,
		InterceptPoint = interceptPoint,
		PassFamily = passFamily,
		BallETA = interceptETA,
		JogETA = jogETA,
		RunETA = runETA,
		SprintETA = sprintETA,
		SelectedMovementETA = selectedETA,
		SelectedLocomotionMode = selected,
		TimingDeficit = deficit,
		DesiredArrivalVelocity = desiredSpeed,
		BrakingDistance = brakingDistance,
		FacingTarget = facingTarget,
		ContactKind = contactKind,
		PreferredFoot = preferredFoot,
		FirstTouchIntent = firstTouch,
		OpponentETA = opponentETA,
		OpponentMargin = opponentETA - math.min(ballETA, selectedETA),
		Reachable = reachable,
		ExpectedContactQuality = math.clamp(1 - math.max(0, deficit) * 1.4 + math.clamp((opponentETA - ballETA) * .35, -.5, .5), 0, 1),
	}
end

return table.freeze(Planner)
