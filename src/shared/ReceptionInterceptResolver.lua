--!strict

local Resolver = {}

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

local function finite(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
	return value
end

local function safeDirection(value: Vector3, fallback: Vector3): Vector3
	local horizontal = flat(value)
	if horizontal.Magnitude > 0.001 then return horizontal.Unit end
	local safeFallback = flat(fallback)
	return safeFallback.Magnitude > 0.001 and safeFallback.Unit or Vector3.zAxis
end

function Resolver.EstimateReachTime(input: any): number
	local position = typeof(input.Position) == "Vector3" and input.Position or Vector3.zero
	local target = typeof(input.Target) == "Vector3" and input.Target or position
	local offset = flat(target - position)
	local distance = offset.Magnitude
	if distance <= math.max(0, finite(input.ContactTolerance, 0)) then return 0 end
	local direction = safeDirection(offset, Vector3.zAxis)
	local velocity = typeof(input.Velocity) == "Vector3" and flat(input.Velocity) or Vector3.zero
	local facing = safeDirection(typeof(input.Facing) == "Vector3" and input.Facing or velocity, direction)
	local maximumSpeed = math.max(1, finite(input.MaximumSpeed, 18))
	local acceleration = math.max(1, finite(input.Acceleration, 12))
	local currentAlong = math.clamp(velocity:Dot(direction), 0, maximumSpeed)
	local remaining = math.max(0, distance - math.max(0, finite(input.ContactTolerance, 0)))
	local accelerationTime = math.max(0, (maximumSpeed - currentAlong) / acceleration)
	local accelerationDistance = currentAlong * accelerationTime + 0.5 * acceleration * accelerationTime * accelerationTime
	local travelTime: number
	if remaining <= accelerationDistance and accelerationDistance > 0.001 then
		travelTime = (-currentAlong + math.sqrt(math.max(0, currentAlong * currentAlong + 2 * acceleration * remaining))) / acceleration
	else
		travelTime = accelerationTime + math.max(0, remaining - accelerationDistance) / maximumSpeed
	end
	local turnDot = math.clamp(facing:Dot(direction), -1, 1)
	local turnPenalty = math.acos(turnDot) / math.pi * math.max(0, finite(input.MaximumTurnPenalty, 0.34))
	local blockedPenalty = input.Blocked == true and math.max(0, finite(input.BlockedPenalty, 0.45)) or 0
	return math.max(0, travelTime + turnPenalty + blockedPenalty + math.max(0, finite(input.PreparationSeconds, 0)))
end

function Resolver.Resolve(input: any): any
	local receiver = input.Receiver or {}
	local samples = type(input.Samples) == "table" and input.Samples or {}
	local opponents = type(input.Opponents) == "table" and input.Opponents or {}
	local allowedHeight = math.max(0.5, finite(input.AllowedControlHeight, 5.8))
	local groundY = finite(input.GroundY, typeof(receiver.Position) == "Vector3" and receiver.Position.Y - 3 or 0)
	local safety = math.max(0, finite(input.ReachSafetySeconds, 0.1))
	local opponentMargin = math.max(0, finite(input.OpponentWinMargin, 0.08))
	local chosen = nil
	local fallback = nil
	for _, sample in samples do
		local point = sample.Position
		local arrival = finite(sample.Time, -1)
		local height = typeof(point) == "Vector3" and point.Y - groundY or math.huge
		if typeof(point) ~= "Vector3" or arrival < 0 or sample.InsideBounds == false or height < -1.5 or height > allowedHeight then continue end
		local receiverETA = Resolver.EstimateReachTime({
			Position = receiver.Position,
			Velocity = receiver.Velocity,
			Facing = receiver.Facing,
			Target = point,
			MaximumSpeed = receiver.MaximumSpeed,
			Acceleration = receiver.Acceleration,
			MaximumTurnPenalty = receiver.MaximumTurnPenalty,
			PreparationSeconds = receiver.PreparationSeconds,
			ContactTolerance = receiver.ContactTolerance,
			Blocked = receiver.Blocked,
		})
		local opponentETA = math.huge
		local likelyOpponent = nil
		for _, opponent in opponents do
			local eta = Resolver.EstimateReachTime({
				Position = opponent.Position,
				Velocity = opponent.Velocity,
				Facing = opponent.Facing,
				Target = point,
				MaximumSpeed = opponent.MaximumSpeed,
				Acceleration = opponent.Acceleration,
				MaximumTurnPenalty = opponent.MaximumTurnPenalty,
				PreparationSeconds = opponent.PreparationSeconds,
				ContactTolerance = opponent.ContactTolerance,
				Blocked = opponent.Blocked,
			})
			if eta < opponentETA then opponentETA = eta;likelyOpponent = opponent.Model end
		end
		local opponentWinning = opponentETA + opponentMargin < math.min(receiverETA, arrival)
		local arrivalMargin = arrival - receiverETA
		local routeConfidence = math.clamp(0.5 + arrivalMargin * 0.3 - (opponentWinning and 0.42 or 0), 0, 1)
		local reachable = receiverETA <= arrival - safety
		local candidate = {
			Point = point,
			Velocity = sample.Velocity,
			BallETA = arrival,
			ReceiverETA = receiverETA,
			OpponentETA = opponentETA,
			LikelyOpponent = likelyOpponent,
			OpponentWinning = opponentWinning,
			Reachable = reachable,
			RouteConfidence = routeConfidence,
			TrajectoryConfidence = math.clamp(finite(sample.Confidence, 1), 0, 1),
			ControllableHeight = height,
			Sample = sample,
		}
		if not fallback or receiverETA - arrival < fallback.ReceiverETA - fallback.BallETA then fallback = candidate end
		if not reachable then continue end
		if not chosen then
			chosen = candidate
		elseif input.PassFamily == "Through" and not opponentWinning and chosen.OpponentWinning and arrival <= chosen.BallETA + 0.25 then
			chosen = candidate
		end
		if chosen == candidate and not opponentWinning then break end
	end
	if chosen then return chosen end
	if fallback then return fallback end
	return {Point = nil, BallETA = math.huge, ReceiverETA = math.huge, OpponentETA = math.huge, OpponentWinning = false, RouteConfidence = 0, TrajectoryConfidence = 0}
end

function Resolver.Smooth(previous: Vector3?, target: Vector3, deltaTime: number, responseSeconds: number, maximumSpeed: number, force: boolean?): Vector3
	if typeof(previous) ~= "Vector3" or force == true then return target end
	local dt = math.clamp(finite(deltaTime, 0), 0, 0.25)
	local alpha = 1 - math.exp(-dt / math.max(0.02, finite(responseSeconds, 0.2)))
	local desired = previous:Lerp(target, alpha)
	local offset = desired - previous
	local maximumStep = math.max(0, finite(maximumSpeed, 40)) * dt
	if offset.Magnitude > maximumStep and maximumStep > 0 then return previous + offset.Unit * maximumStep end
	return desired
end

function Resolver.DirectionDivergence(initial: Vector3, current: Vector3): number
	local a = flat(initial)
	local b = flat(current)
	if a.Magnitude <= 0.1 or b.Magnitude <= 0.1 then return 0 end
	return 1 - math.clamp(a.Unit:Dot(b.Unit), -1, 1)
end

return table.freeze(Resolver)
