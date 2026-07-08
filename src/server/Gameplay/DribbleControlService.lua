local DribbleControlService = {}

local LastFacing = setmetatable({}, { __mode = "k" })

local function root(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function flat(value)
	if typeof(value) ~= "Vector3" then
		return Vector3.zero
	end

	return Vector3.new(value.X, 0, value.Z)
end

local function finite(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function safeUnit(value, fallback)
	local f = flat(value)

	if f.Magnitude > 0.001 and finite(f.X) and finite(f.Z) then
		return f.Unit
	end

	local b = flat(fallback)

	if b.Magnitude > 0.001 then
		return b.Unit
	end

	return Vector3.zAxis
end

local function signedAngle(from, to)
	local cross = from.X * to.Z - from.Z * to.X
	local dot = math.clamp(from:Dot(to), -1, 1)
	return math.atan2(cross, dot)
end

function DribbleControlService.Rotate(model, direction, ownsBall, sprinting, dt)
	local modelRoot = root(model)
	if not modelRoot then
		return
	end

	dt = math.clamp(tonumber(dt) or 1 / 60, 1 / 240, 1 / 15)

	local current = LastFacing[model] or safeUnit(modelRoot.CFrame.LookVector, Vector3.zAxis)
	local target = safeUnit(direction, current)

	local dot = math.clamp(current:Dot(target), -1, 1)
	local penalty = ownsBall and math.clamp((1 - dot) * 0.42, 0, 0.5) or 0
	local turnRate = ownsBall and 5.6 or 8.4

	if sprinting then
		turnRate *= 0.82
	end

	local angle = signedAngle(current, target)
	local maxStep = turnRate * dt
	local step = math.clamp(angle, -maxStep, maxStep)
	local rotated = CFrame.fromAxisAngle(Vector3.yAxis, step):VectorToWorldSpace(current)

	if rotated.Magnitude < 0.001 then
		rotated = target
	end

	rotated = rotated.Unit
	LastFacing[model] = rotated

	local position = modelRoot.Position
	model:PivotTo(CFrame.lookAt(position, position + rotated))

	model:SetAttribute("InputTurnDot", dot)
	model:SetAttribute("VTRTurnDot", dot)
	model:SetAttribute("DribbleTurnPenalty", penalty)
	model:SetAttribute("VTRDribbleFacingX", rotated.X)
	model:SetAttribute("VTRDribbleFacingZ", rotated.Z)
end

function DribbleControlService.Clear(model)
	LastFacing[model] = nil
end

return DribbleControlService
