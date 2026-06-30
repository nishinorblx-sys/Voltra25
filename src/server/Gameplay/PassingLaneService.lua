--!strict
local Service = {}

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function clearance(from: Vector3, to: Vector3, opponents: {Model}): number
	local segment = flat(to - from)
	if segment.Magnitude < 0.1 then return 0 end
	local nearest = 20
	for _, opponent in opponents do
		local opponentRoot = root(opponent)
		if opponentRoot then
			local offset = flat(opponentRoot.Position - from)
			local alpha = math.clamp(offset:Dot(segment) / segment:Dot(segment), 0, 1)
			nearest = math.min(nearest, flat(opponentRoot.Position - (from + segment * alpha)).Magnitude)
		end
	end
	return math.clamp((nearest - 1.5) / 10, 0, 1)
end

function Service.Adjust(context: any, assignment: any, target: Vector3): (Vector3, number)
	local owner = assignment.SupportTarget
	local ownerRoot = owner and root(owner)
	if not ownerRoot then return target, 0 end
	local supportRole = assignment.SupportRole
	if supportRole ~= "ShortSupport" and supportRole ~= "DiagonalSupport" and supportRole ~= "Underlap" and supportRole ~= "RecycleOption" and supportRole ~= "BackPassOption" then
		return target, clearance(ownerRoot.Position, target, context.Opponents or {})
	end
	local best = target
	local bestScore = -1
	local right = context.PitchCFrame.RightVector
	for _, offset in {-9, 0, 9} do
		local candidate = target + right * offset
		local score = clearance(ownerRoot.Position, candidate, context.Opponents or {}) - math.abs(offset) / 90
		if score > bestScore then best, bestScore = candidate, score end
	end
	return best, bestScore
end

return Service
