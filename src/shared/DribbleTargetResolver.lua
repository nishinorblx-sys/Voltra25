--!strict

local Resolver = {}

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

function Resolver.Resolve(input: any): any
	local rootPosition = typeof(input.RootPosition) == "Vector3" and input.RootPosition or Vector3.zero
	local look = typeof(input.RootLookVector) == "Vector3" and flat(input.RootLookVector) or Vector3.zAxis
	if look.Magnitude < 0.05 then look = Vector3.zAxis else look = look.Unit end
	local move = typeof(input.MoveVector) == "Vector3" and flat(input.MoveVector) or Vector3.zero
	local velocity = typeof(input.HorizontalVelocity) == "Vector3" and flat(input.HorizontalVelocity) or Vector3.zero
	local direction = move.Magnitude > 0.08 and move.Unit or velocity.Magnitude > 1 and velocity.Unit or look
	local sprinting = input.Sprinting == true
	local close = input.CloseControl == true
	local actionLocked = input.ActionLocked == true
	local control = math.clamp((tonumber(input.BallControl) or 60) / 100, 0.2, 0.99)
	local turnDot = math.clamp(tonumber(input.TurnDot) or 1, -1, 1)
	local radius = math.max(0.2, tonumber(input.BallRadius) or 1)
	local verticalOffset = tonumber(input.VerticalOffset) or 2.45
	local baseDistance = close and 1.45 or sprinting and 2.65 or 1.9
	baseDistance += (1 - control) * (sprinting and 0.34 or 0.18)
	baseDistance += math.clamp(velocity.Magnitude * 0.018, 0, sprinting and 0.42 or 0.24)
	local phase = math.clamp(tonumber(input.TouchPhase) or 0, 0, 1)
	local pulse = math.sin(phase * math.pi) * (sprinting and 0.42 or 0.24)
	if actionLocked then pulse = 0 end
	local turnPenalty = math.clamp((1 - turnDot) * 0.42, 0, 0.72)
	local distance = math.max(radius * 1.28, baseDistance + pulse - turnPenalty)
	local target = rootPosition + direction * distance - Vector3.yAxis * verticalOffset
	return {
		Target = target,
		PredictedVisualTarget = target,
		TouchDirection = direction,
		LegalEnvelope = sprinting and 7.5 or 6,
		HardRecoveryDistance = sprinting and 9.5 or 9,
		CorrectionStrength = close and 7.2 or 4.8 + control * 1.5,
		TouchSide = phase < 0.5 and "Left" or "Right",
	}
end

return table.freeze(Resolver)
