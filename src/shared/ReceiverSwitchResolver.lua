--!strict

local Resolver = {}

local transferETA = table.freeze({Newcomer = 0.62, Standard = 0.4, Manual = -1})
local prepareETA = table.freeze({Newcomer = 1, Standard = 0.75, Manual = -1})
local reachGrace = table.freeze({Newcomer = 0.58, Standard = 0.3, Manual = 0.12})

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

local function safeMode(value: any): string
	local mode = tostring(value or "Standard")
	return transferETA[mode] ~= nil and mode or "Standard"
end

function Resolver.EstimateBallETA(ballPosition: Vector3, ballVelocity: Vector3, target: Vector3, trajectoryETA: number?): number
	if type(trajectoryETA) == "number" and trajectoryETA == trajectoryETA then
		return math.clamp(trajectoryETA, 0, 8)
	end
	local offset = flat(target - ballPosition)
	local distance = offset.Magnitude
	if distance <= 0.1 then return 0 end
	local velocity = flat(ballVelocity)
	local speed = velocity.Magnitude
	if speed <= 0.75 then return math.huge end
	local alignment = math.clamp(velocity.Unit:Dot(offset.Unit), -1, 1)
	if alignment <= 0.05 then return math.huge end
	return math.clamp(distance / math.max(speed * math.max(alignment, 0.35), 1), 0, 8)
end

function Resolver.EstimatePlayerETA(position: Vector3, velocity: Vector3, target: Vector3, maximumSpeed: number?): number
	local distance = flat(target - position).Magnitude
	if distance <= 1.6 then return 0 end
	local current = flat(velocity)
	local speed = math.max(tonumber(maximumSpeed) or 18, 1)
	local approach = current.Magnitude > 0.5 and math.clamp(current.Unit:Dot(flat(target - position).Unit), -1, 1) or 0
	local reaction = approach < -0.25 and 0.2 or approach < 0.2 and 0.1 or 0
	return reaction + math.max(0, distance - 1.6) / speed
end

function Resolver.Evaluate(input: any): any
	local mode = safeMode(input.Mode)
	local target = typeof(input.InterceptionPoint) == "Vector3" and input.InterceptionPoint or input.ReceivePoint
	if typeof(target) ~= "Vector3" then return {Mode = mode, Reachable = false, Diverged = true, Prepare = false, Transfer = false, BallETA = math.huge} end
	local ballPosition = typeof(input.BallPosition) == "Vector3" and input.BallPosition or target
	local ballVelocity = typeof(input.BallVelocity) == "Vector3" and input.BallVelocity or Vector3.zero
	local initialDirection = typeof(input.InitialDirection) == "Vector3" and flat(input.InitialDirection) or Vector3.zero
	local currentDirection = flat(ballVelocity)
	local diverged = input.MotionKind ~= nil and tostring(input.MotionKind) ~= "Pass"
	if not diverged and initialDirection.Magnitude > 0.1 and currentDirection.Magnitude > 2 then
		diverged = initialDirection.Unit:Dot(currentDirection.Unit) < 0.52
	end
	local ballETA = Resolver.EstimateBallETA(ballPosition, ballVelocity, target, input.TrajectoryETA)
	local receiverPosition = typeof(input.ReceiverPosition) == "Vector3" and input.ReceiverPosition or target
	local receiverVelocity = typeof(input.ReceiverVelocity) == "Vector3" and input.ReceiverVelocity or Vector3.zero
	local receiverETA = Resolver.EstimatePlayerETA(receiverPosition, receiverVelocity, target, input.ReceiverSpeed)
	local reachable = not diverged and ballETA < math.huge and receiverETA <= ballETA + reachGrace[mode]
	local actualPossession = input.ActualCollector == true
	return {
		Mode = mode,
		BallETA = ballETA,
		ReceiverETA = receiverETA,
		Reachable = reachable,
		Diverged = diverged,
		Prepare = mode ~= "Manual" and reachable and ballETA <= prepareETA[mode],
		Transfer = actualPossession or mode ~= "Manual" and reachable and ballETA <= transferETA[mode],
	}
end

function Resolver.SelectCollector(candidates: {any}, target: Vector3): any?
	local best = nil
	local bestETA = math.huge
	local bestKey = ""
	for _, candidate in candidates do
		if candidate.Valid ~= false and typeof(candidate.Position) == "Vector3" then
			local eta = Resolver.EstimatePlayerETA(candidate.Position, typeof(candidate.Velocity) == "Vector3" and candidate.Velocity or Vector3.zero, target, candidate.Speed)
			local key = tostring(candidate.Key or candidate.Model or "")
			if eta < bestETA - 0.001 or math.abs(eta - bestETA) <= 0.001 and key < bestKey then
				best = candidate
				bestETA = eta
				bestKey = key
			end
		end
	end
	if best then best.ContactETA = bestETA end
	return best
end

return table.freeze(Resolver)
