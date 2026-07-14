--!strict

local Trajectory = {}

local function finiteNumber(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
	return value
end

local function clamp01(value: any): number
	return math.clamp(finiteNumber(value, 0), 0, 1)
end

local function safeUnit(vector: Vector3, fallback: Vector3): Vector3
	if vector.Magnitude > 0.0001 then return vector.Unit end
	return fallback.Magnitude > 0.0001 and fallback.Unit or Vector3.zAxis
end

local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
end

local function bezierDerivative(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t)
end

local function lateral(startPosition: Vector3, endPosition: Vector3, provided: Vector3?): Vector3
	if typeof(provided) == "Vector3" and provided.Magnitude > 0.001 then return provided.Unit end
	local flat = Vector3.new(endPosition.X - startPosition.X, 0, endPosition.Z - startPosition.Z)
	local forward = safeUnit(flat, Vector3.zAxis)
	return Vector3.new(-forward.Z, 0, forward.X)
end

local function rawSample(data: any, t: number): Vector3
	t = clamp01(t)
	local startPosition = data.Start
	local endPosition = data.End
	if typeof(startPosition) ~= "Vector3" or typeof(endPosition) ~= "Vector3" then return Vector3.zero end
	local kind = tostring(data.Kind or "Straight")
	if kind == "Bezier" then
		return bezier(startPosition, data.Control1 or startPosition, data.Control2 or endPosition, endPosition, t)
	end
	local point = startPosition:Lerp(endPosition, t)
	local lift = finiteNumber(data.ArcHeight, 0)
	if lift ~= 0 then point += Vector3.yAxis * (4 * lift * t * (1 - t)) end
	local curve = finiteNumber(data.Curve, 0)
	if curve ~= 0 then point += lateral(startPosition, endPosition, data.CurveAxis) * (4 * curve * t * (1 - t)) end
	return point
end

local function rawDerivative(data: any, t: number): Vector3
	t = clamp01(t)
	local startPosition = data.Start
	local endPosition = data.End
	if typeof(startPosition) ~= "Vector3" or typeof(endPosition) ~= "Vector3" then return Vector3.zero end
	local kind = tostring(data.Kind or "Straight")
	if kind == "Bezier" then
		return bezierDerivative(startPosition, data.Control1 or startPosition, data.Control2 or endPosition, endPosition, t)
	end
	local base = endPosition - startPosition
	local lift = finiteNumber(data.ArcHeight, 0)
	if lift ~= 0 then base += Vector3.yAxis * (4 * lift * (1 - 2 * t)) end
	local curve = finiteNumber(data.Curve, 0)
	if curve ~= 0 then base += lateral(startPosition, endPosition, data.CurveAxis) * (4 * curve * (1 - 2 * t)) end
	return base
end

function Trajectory.BuildLookup(data: any, samples: number?): {number}
	local count = math.clamp(math.floor(finiteNumber(samples, 40)), 8, 96)
	local lookup = table.create(count + 1)
	local previous = rawSample(data, 0)
	local length = 0
	lookup[1] = 0
	for index = 1, count do
		local t = index / count
		local point = rawSample(data, t)
		length += (point - previous).Magnitude
		lookup[index + 1] = length
		previous = point
	end
	if length <= 0.0001 then
		for index = 1, count + 1 do lookup[index] = (index - 1) / count end
		data.Length = 0
		return lookup
	end
	for index = 1, count + 1 do lookup[index] = lookup[index] / length end
	data.Length = length
	return lookup
end

function Trajectory.DistanceAlphaToT(data: any, alpha: number): number
	alpha = clamp01(alpha)
	local lookup = data.Lookup
	if type(lookup) ~= "table" or #lookup < 2 then return alpha end
	if alpha <= 0 then return 0 end
	if alpha >= 1 then return 1 end
	local count = #lookup - 1
	for index = 1, count do
		local a = tonumber(lookup[index]) or 0
		local b = tonumber(lookup[index + 1]) or 1
		if alpha <= b then
			local span = math.max(b - a, 0.000001)
			return ((index - 1) + (alpha - a) / span) / count
		end
	end
	return 1
end

function Trajectory.Sample(data: any, alpha: number): Vector3
	local progress = clamp01(alpha)
	if data.ArcLength == true then progress = Trajectory.DistanceAlphaToT(data, progress) end
	return rawSample(data, progress)
end

function Trajectory.Tangent(data: any, alpha: number): Vector3
	local progress = clamp01(alpha)
	if data.ArcLength == true then progress = Trajectory.DistanceAlphaToT(data, progress) end
	return rawDerivative(data, progress)
end

function Trajectory.Velocity(data: any, alpha: number): Vector3
	local duration = math.max(finiteNumber(data.Duration, 1), 0.05)
	return Trajectory.Tangent(data, alpha) / duration
end

function Trajectory.ReleaseVelocity(data: any): Vector3
	local velocity = Trajectory.Velocity(data, 1)
	local multiplier = finiteNumber(data.ReleaseVelocityMultiplier, 1)
	return velocity * multiplier
end

function Trajectory.Create(kind: string, startPosition: Vector3, endPosition: Vector3, options: any?): any
	options = options or {}
	local data = {
		Kind = kind,
		Start = startPosition,
		End = endPosition,
		Duration = math.max(finiteNumber(options.Duration, 1), 0.05),
		ArcHeight = finiteNumber(options.ArcHeight, 0),
		Curve = finiteNumber(options.Curve, 0),
		CurveAxis = typeof(options.CurveAxis) == "Vector3" and safeUnit(options.CurveAxis, lateral(startPosition, endPosition, nil)) or lateral(startPosition, endPosition, nil),
		ArcLength = options.ArcLength == true,
		ReleaseVelocityMultiplier = finiteNumber(options.ReleaseVelocityMultiplier, 1),
	}
	if kind == "Bezier" then
		data.Control1 = options.Control1 or startPosition:Lerp(endPosition, 0.33)
		data.Control2 = options.Control2 or startPosition:Lerp(endPosition, 0.66)
	end
	data.Lookup = Trajectory.BuildLookup(data, options.Samples)
	return data
end

return Trajectory
