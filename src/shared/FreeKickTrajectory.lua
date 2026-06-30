--!strict

local Trajectory = {}

local GRAVITY = 59
local BASE_SPEED = 104

local function clampNumber(value: any, fallback: number, minValue: number, maxValue: number): number
	local numberValue = tonumber(value)
	if numberValue == nil then
		numberValue = fallback
	end
	return math.clamp(numberValue, minValue, maxValue)
end

function Trajectory.Compute(startPosition: Vector3, targetPosition: Vector3, curve: number?, lift: number?)
	local delta = targetPosition - startPosition
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local distance = flat.Magnitude
	local liftValue = math.clamp(lift or 0, -2.5, 2.5)
	local curveValue = math.clamp(curve or 0, -2.5, 2.5)
	local flightTime = math.clamp(distance / BASE_SPEED, 0.46, 1.55) + liftValue * 0.16
	flightTime = math.clamp(flightTime, 0.38, 1.95)
	local curveStuds = clampNumber(workspace:GetAttribute("VTRFreeKickCurveStuds"), 16, 0, 42)
	local lateral = flat.Magnitude > 0.1 and flat.Unit:Cross(Vector3.yAxis) * (curveValue >= 0 and -1 or 1) or Vector3.xAxis
	local desiredBend = math.clamp(math.abs(curveValue) / 2.5, 0, 1) * curveStuds
	local strength = desiredBend > 0 and (8 * desiredBend) / (flightTime * flightTime) or 0
	local baseVelocity = delta / flightTime + Vector3.yAxis * (GRAVITY * flightTime * 0.5)
	local compensation = -lateral * (strength * flightTime * 0.5)
	return {
		Gravity = GRAVITY,
		FlightTime = flightTime,
		Lateral = lateral,
		Strength = strength,
		BaseVelocity = baseVelocity,
		Compensation = compensation,
		InitialVelocity = baseVelocity + compensation,
	}
end

function Trajectory.PointAt(startPosition: Vector3, solved: any, alpha: number): Vector3
	alpha = math.clamp(alpha, 0, 1)
	local time = solved.FlightTime * alpha
	return startPosition
		+ solved.InitialVelocity * time
		- Vector3.yAxis * (0.5 * solved.Gravity * time * time)
		+ solved.Lateral * (0.5 * solved.Strength * time * time)
end

return table.freeze(Trajectory)
