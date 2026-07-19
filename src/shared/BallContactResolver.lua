--!strict

local Resolver = {}

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

local function pointOf(contact: any, key: string): Vector3?
	if typeof(contact) == "Vector3" then return contact end
	if type(contact) ~= "table" then return nil end
	local value = contact[key]
	if typeof(value) == "Vector3" then return value end
	return typeof(contact.Position) == "Vector3" and contact.Position or nil
end

local function closestMovingPoints(ballStart: Vector3, ballEnd: Vector3, bodyStart: Vector3, bodyEnd: Vector3): (number, number, Vector3, Vector3)
	local ballDelta = ballEnd - ballStart
	local bodyDelta = bodyEnd - bodyStart
	local relativeStart = ballStart - bodyStart
	local relativeDelta = ballDelta - bodyDelta
	local denominator = relativeDelta:Dot(relativeDelta)
	local alpha = denominator > 0.000001 and math.clamp(-relativeStart:Dot(relativeDelta) / denominator, 0, 1) or 0
	local ballPoint = ballStart + ballDelta * alpha
	local bodyPoint = bodyStart + bodyDelta * alpha
	return (ballPoint - bodyPoint).Magnitude, alpha, ballPoint, bodyPoint
end

local function evaluateAt(candidate: any, ball: any, contactDistance: number, contactTime: number, ballPosition: Vector3, contactPoint: Vector3, contactKind: string?): any
	local ballVelocity = typeof(ball.Velocity) == "Vector3" and ball.Velocity or Vector3.zero
	local rootPosition = typeof(candidate.RootPosition) == "Vector3" and candidate.RootPosition or Vector3.zero
	local rootVelocity = typeof(candidate.RootVelocity) == "Vector3" and candidate.RootVelocity or Vector3.zero
	local moveDirection = typeof(candidate.MoveDirection) == "Vector3" and flat(candidate.MoveDirection) or Vector3.zero
	local facing = typeof(candidate.Facing) == "Vector3" and flat(candidate.Facing) or Vector3.zAxis
	if facing.Magnitude < 0.01 then facing = Vector3.zAxis else facing = facing.Unit end
	local radius = math.max(0.2, tonumber(ball.Radius) or 1)
	local expected = candidate.ExpectedReceiver == true
	local targetedAI = candidate.TargetedAIReceiver == true
	local reachMaximum = expected and (targetedAI and 5.85 or 5.05) or 2.65
	local maximumDistance = radius + math.clamp(tonumber(candidate.ContactReach) or 1.75, 1.2, reachMaximum)
	local maximumHeight = radius + math.clamp(tonumber(candidate.ControlHeight) or 2.15, 1.6, 6.4)
	local relativeHeight = ballPosition.Y - math.min(contactPoint.Y, rootPosition.Y)
	local toBall = flat(ballPosition - rootPosition)
	local facingDot = toBall.Magnitude > 0.05 and facing:Dot(toBall.Unit) or 1
	local horizontalRootVelocity = flat(rootVelocity)
	local relativeVelocity = flat(ballVelocity) - horizontalRootVelocity
	local speedReach = math.clamp(relativeVelocity.Magnitude / 125, 0, expected and (targetedAI and 1.25 or 1.05) or 0.65)
	maximumDistance += (expected and (targetedAI and 0.85 or 0.68) or 0.35) + speedReach
	maximumHeight += expected and 0.35 or 0.22
	local control = math.clamp((tonumber(candidate.Control) or 60) / 100, 0.1, 0.99)
	local balance = math.clamp((tonumber(candidate.Balance) or 60) / 100, 0.1, 0.99)
	local agility = math.clamp((tonumber(candidate.Agility) or 60) / 100, 0.1, 0.99)
	local strength = math.clamp((tonumber(candidate.Strength) or 60) / 100, 0.1, 0.99)
	local bodyPosition = math.clamp((facingDot + 0.2) / 1.2, 0, 1)
	local movementPosition = moveDirection.Magnitude > 0.05 and toBall.Magnitude > 0.05 and math.clamp((moveDirection.Unit:Dot(toBall.Unit) + 0.35) / 1.35, 0, 1) or 0.5
	local momentum = math.clamp(horizontalRootVelocity.Magnitude / 24, 0, 1) * movementPosition
	local speedPenalty = math.clamp(relativeVelocity.Magnitude / 105, 0, 0.55)
	local pressurePenalty = math.clamp(tonumber(candidate.Pressure) or 0, 0, 1) * 0.13
	local expectedBonus = expected and 0.085 or 0
	local footPreference = tostring(candidate.PreferredFoot or "Right")
	local preferredContact = contactKind == footPreference .. "Foot"
	local contactBonus = preferredContact and 0.035 or (contactKind == "Chest" or contactKind == "Header") and -0.02 or 0
	local proximity = math.clamp(1 - contactDistance / math.max(maximumDistance, 0.1), 0, 1)
	local score = control * 0.3 + balance * 0.12 + agility * 0.1 + strength * 0.06 + bodyPosition * 0.15 + movementPosition * 0.07 + momentum * 0.05 + proximity * 0.22 + expectedBonus + contactBonus - speedPenalty - pressurePenalty
	local valid = candidate.Valid ~= false and contactDistance <= maximumDistance and relativeHeight >= -radius * 1.35 and relativeHeight <= maximumHeight
	local controlledThreshold = expected and 0.44 or 0.51
	local heavyThreshold = expected and 0.22 or 0.3
	local outcome = score >= controlledThreshold and "Controlled" or score >= heavyThreshold and "HeavyTouch" or "Deflected"
	if candidate.CanControl == false then outcome = "Deflected" elseif candidate.UserControlled == true then outcome = "Controlled" end
	return {
		Candidate = candidate,
		Valid = valid,
		ContactPoint = contactPoint,
		BallContactPoint = ballPosition,
		ContactKind = contactKind,
		ContactDistance = contactDistance,
		ContactTime = contactTime,
		RelativeHeight = relativeHeight,
		RelativeSpeed = relativeVelocity.Magnitude,
		FacingDot = facingDot,
		Score = score,
		Outcome = outcome,
	}
end

function Resolver.Evaluate(candidate: any, ball: any): any
	local ballPosition = typeof(ball.Position) == "Vector3" and ball.Position or Vector3.zero
	local rootPosition = typeof(candidate.RootPosition) == "Vector3" and candidate.RootPosition or Vector3.zero
	local contacts = type(candidate.ContactPoints) == "table" and candidate.ContactPoints or {rootPosition}
	local bestDistance = math.huge
	local bestPoint = rootPosition
	local bestKind = nil
	for _, contact in contacts do
		local point = pointOf(contact, "Position")
		if point then
			local distance = (point - ballPosition).Magnitude
			if distance < bestDistance then
				bestDistance, bestPoint = distance, point
				bestKind = type(contact) == "table" and contact.Kind or nil
			end
		end
	end
	local ballVelocity = typeof(ball.Velocity) == "Vector3" and flat(ball.Velocity) or Vector3.zero
	local rootVelocity = typeof(candidate.RootVelocity) == "Vector3" and flat(candidate.RootVelocity) or Vector3.zero
	return evaluateAt(candidate, ball, bestDistance, bestDistance / math.max((ballVelocity - rootVelocity).Magnitude, 1), ballPosition, bestPoint, bestKind)
end

function Resolver.EvaluateSwept(candidate: any, ball: any): any
	local ballStart = typeof(ball.PreviousPosition) == "Vector3" and ball.PreviousPosition or typeof(ball.Position) == "Vector3" and ball.Position or Vector3.zero
	local ballEnd = typeof(ball.Position) == "Vector3" and ball.Position or ballStart
	local rootPosition = typeof(candidate.RootPosition) == "Vector3" and candidate.RootPosition or Vector3.zero
	local contacts = type(candidate.ContactPoints) == "table" and candidate.ContactPoints or {rootPosition}
	local bestDistance = math.huge
	local bestAlpha = 1
	local bestBallPoint = ballEnd
	local bestBodyPoint = rootPosition
	local bestKind = nil
	for _, contact in contacts do
		local bodyEnd = pointOf(contact, "Position")
		if bodyEnd then
			local bodyStart = pointOf(contact, "PreviousPosition") or bodyEnd
			local distance, alpha, ballPoint, bodyPoint = closestMovingPoints(ballStart, ballEnd, bodyStart, bodyEnd)
			if distance < bestDistance or math.abs(distance - bestDistance) <= 0.001 and alpha < bestAlpha then
				bestDistance, bestAlpha, bestBallPoint, bestBodyPoint = distance, alpha, ballPoint, bodyPoint
				bestKind = type(contact) == "table" and contact.Kind or nil
			end
		end
	end
	local duration = math.max(tonumber(ball.Duration) or 0, 0)
	return evaluateAt(candidate, ball, bestDistance, bestAlpha * duration, bestBallPoint, bestBodyPoint, bestKind)
end

function Resolver.Resolve(candidates: {any}, ball: any): any?
	local evaluations = {}
	for _, candidate in candidates do
		local evaluation = Resolver.Evaluate(candidate, ball)
		if evaluation.Valid then table.insert(evaluations, evaluation) end
	end
	table.sort(evaluations, function(a, b)
		if math.abs(a.ContactTime - b.ContactTime) > 0.004 then return a.ContactTime < b.ContactTime end
		if math.abs(a.Score - b.Score) > 0.001 then return a.Score > b.Score end
		return tostring(a.Candidate.Key or "") < tostring(b.Candidate.Key or "")
	end)
	local best = evaluations[1]
	local second = evaluations[2]
	if best and second and math.abs(best.ContactTime - second.ContactTime) <= 0.04 and math.abs(best.Score - second.Score) <= 0.08 then best.Outcome = "Deflected" end
	return best
end

function Resolver.ResolveSwept(candidates: {any}, ball: any): any?
	local evaluations = {}
	for _, candidate in candidates do
		local evaluation = Resolver.EvaluateSwept(candidate, ball)
		if evaluation.Valid then table.insert(evaluations, evaluation) end
	end
	table.sort(evaluations, function(a, b)
		if math.abs(a.ContactTime - b.ContactTime) > 0.008 then return a.ContactTime < b.ContactTime end
		if math.abs(a.Score - b.Score) > 0.001 then return a.Score > b.Score end
		return tostring(a.Candidate.Key or "") < tostring(b.Candidate.Key or "")
	end)
	local best = evaluations[1]
	local second = evaluations[2]
	if best and second and math.abs(best.ContactTime - second.ContactTime) <= 0.025 and math.abs(best.Score - second.Score) <= 0.07 then best.Outcome = "Deflected" end
	return best
end

return table.freeze(Resolver)
