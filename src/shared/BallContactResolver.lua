--!strict

local Resolver = {}

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

function Resolver.Evaluate(candidate: any, ball: any): any
	local ballPosition = typeof(ball.Position) == "Vector3" and ball.Position or Vector3.zero
	local ballVelocity = typeof(ball.Velocity) == "Vector3" and ball.Velocity or Vector3.zero
	local rootPosition = typeof(candidate.RootPosition) == "Vector3" and candidate.RootPosition or Vector3.zero
	local rootVelocity = typeof(candidate.RootVelocity) == "Vector3" and candidate.RootVelocity or Vector3.zero
	local moveDirection = typeof(candidate.MoveDirection) == "Vector3" and flat(candidate.MoveDirection) or Vector3.zero
	local facing = typeof(candidate.Facing) == "Vector3" and flat(candidate.Facing) or Vector3.zAxis
	if facing.Magnitude < 0.01 then facing = Vector3.zAxis else facing = facing.Unit end
	local contacts = type(candidate.ContactPoints) == "table" and candidate.ContactPoints or {rootPosition - Vector3.yAxis * 2.2 + facing * 0.8}
	local contactDistance = math.huge
	local contactPoint = rootPosition
	local contactKind = nil
	for _, contact in contacts do
		local point = typeof(contact) == "Vector3" and contact or type(contact) == "table" and contact.Position or nil
		if typeof(point) == "Vector3" then
			local distance = (point - ballPosition).Magnitude
			if distance < contactDistance then
				contactDistance = distance
				contactPoint = point
				contactKind = type(contact) == "table" and contact.Kind or nil
			end
		end
	end
	local relativeHeight = ballPosition.Y - math.min(contactPoint.Y, rootPosition.Y)
	local radius = math.max(0.2, tonumber(ball.Radius) or 1)
	local maximumDistance = radius + math.clamp(tonumber(candidate.ContactReach) or 1.75, 1.2, 2.4)
	local maximumHeight = radius + math.clamp(tonumber(candidate.ControlHeight) or 2.15, 1.6, 6.4)
	local toBall = flat(ballPosition - rootPosition)
	local facingDot = toBall.Magnitude > 0.05 and facing:Dot(toBall.Unit) or 1
	local horizontalRootVelocity = flat(rootVelocity)
	local relativeVelocity = flat(ballVelocity) - horizontalRootVelocity
	local movingAway = toBall.Magnitude > maximumDistance and relativeVelocity.Magnitude > 1 and relativeVelocity:Dot(toBall.Unit) > 8
	local closingSpeed = toBall.Magnitude > 0.05 and math.max(0, -relativeVelocity:Dot(toBall.Unit)) or 0
	local contactTime = math.max(0, contactDistance - radius - 0.35) / math.max(closingSpeed + horizontalRootVelocity.Magnitude * 0.2, 1)
	local control = math.clamp((tonumber(candidate.Control) or 60) / 100, 0.1, 0.99)
	local balance = math.clamp((tonumber(candidate.Balance) or 60) / 100, 0.1, 0.99)
	local strength = math.clamp((tonumber(candidate.Strength) or 60) / 100, 0.1, 0.99)
	local bodyPosition = math.clamp((facingDot + 0.2) / 1.2, 0, 1)
	local movementPosition = moveDirection.Magnitude > 0.05 and toBall.Magnitude > 0.05 and math.clamp((moveDirection.Unit:Dot(toBall.Unit) + 0.35) / 1.35, 0, 1) or 0.5
	local momentum = math.clamp(horizontalRootVelocity.Magnitude / 24, 0, 1) * movementPosition
	local speedPenalty = math.clamp(relativeVelocity.Magnitude / 120, 0, 0.45)
	local expectedBonus = candidate.ExpectedReceiver == true and 0.025 or 0
	local score = control * 0.34 + balance * 0.15 + strength * 0.08 + bodyPosition * 0.2 + movementPosition * 0.08 + momentum * 0.07 + math.clamp(1 - contactDistance / math.max(maximumDistance, 0.1), 0, 1) * 0.2 + expectedBonus - speedPenalty
	local valid = candidate.Valid ~= false and contactDistance <= maximumDistance and relativeHeight >= -radius and relativeHeight <= maximumHeight and facingDot > -0.42 and not movingAway
	return {
		Candidate = candidate,
		Valid = valid,
		ContactPoint = contactPoint,
		ContactKind = contactKind,
		ContactDistance = contactDistance,
		ContactTime = contactTime,
		RelativeHeight = relativeHeight,
		FacingDot = facingDot,
		Score = score,
		Outcome = score >= 0.48 and "Controlled" or "Loose",
	}
end

function Resolver.Resolve(candidates: {any}, ball: any): any?
	local evaluations = {}
	for _, candidate in candidates do
		local evaluation = Resolver.Evaluate(candidate, ball)
		if evaluation.Valid then table.insert(evaluations, evaluation) end
	end
	table.sort(evaluations, function(a, b)
		if math.abs(a.ContactTime - b.ContactTime) > 0.015 then return a.ContactTime < b.ContactTime end
		if math.abs(a.Score - b.Score) > 0.001 then return a.Score > b.Score end
		return tostring(a.Candidate.Key or "") < tostring(b.Candidate.Key or "")
	end)
	local best = evaluations[1]
	local second = evaluations[2]
	if best and second and math.abs(best.ContactTime - second.ContactTime) <= 0.04 and math.abs(best.Score - second.Score) <= 0.08 then
		best.Outcome = "Loose"
	end
	return best
end

return table.freeze(Resolver)
