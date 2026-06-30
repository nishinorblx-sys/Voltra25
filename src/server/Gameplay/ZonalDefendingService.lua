--!strict
local Service = {}

function Service.Calculate(context: any, assignment: any): (Vector3, string)
	local baseLocal = context.PitchCFrame:PointToObjectSpace(assignment.BasePosition)
	local ballLocal = context.PitchCFrame:PointToObjectSpace(context.Ball.Position)
	local role = assignment.Role
	if role == "GK" then
		local ownSign = -(context.AttackSign or (context.Side == "Home" and -1 or 1))
		local goalZ = ownSign * (context.Length / 2 - 8)
		if context.Possession:GetOwner() == nil and math.abs(ballLocal.Z - goalZ) < 22 and math.abs(ballLocal.X) < 17 then
			return Vector3.new(context.Ball.Position.X, 3, context.Ball.Position.Z), "ClaimLooseBall"
		end
		local x = math.clamp(ballLocal.X * 0.18, -10, 10)
		return context.PitchCFrame:PointToWorldSpace(Vector3.new(x, 3, goalZ)), "ProtectGoal"
	end
	if assignment.PressAssignment == "Primary" then
		return Vector3.new(context.Ball.Position.X, 3, context.Ball.Position.Z), "HardPress"
	elseif assignment.PressAssignment == "Secondary" then
		local markRoot = assignment.MarkTarget and assignment.MarkTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		local markLocal = markRoot and context.PitchCFrame:PointToObjectSpace(markRoot.Position) or ballLocal
		local cover = Vector3.new(ballLocal.X * 0.58 + markLocal.X * 0.28 + baseLocal.X * 0.14, 3, ballLocal.Z * 0.58 + markLocal.Z * 0.28 + baseLocal.Z * 0.14)
		return context.PitchCFrame:PointToWorldSpace(cover), "CoverPress"
	elseif assignment.PressAssignment == "LaneBlocker" then
		local markRoot = assignment.MarkTarget and assignment.MarkTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		local markLocal = markRoot and context.PitchCFrame:PointToObjectSpace(markRoot.Position) or baseLocal
		local central = ballLocal:Lerp(markLocal, 0.48)
		return context.PitchCFrame:PointToWorldSpace(central), "BlockLane"
	end
	local compactness = context.Compactness
	local shiftX = ballLocal.X * (0.12 + compactness * 0.14)
	local shiftZ = ballLocal.Z * (0.035 + compactness * 0.055)
	local targetX = baseLocal.X * compactness + shiftX
	local targetZ = baseLocal.Z + shiftZ
	if role == "CB" then
		targetZ = baseLocal.Z + math.clamp(shiftZ, -7, 7)
		targetX = baseLocal.X + math.clamp(shiftX, -8, 8)
	elseif role == "Fullback" then
		targetX = baseLocal.X + math.clamp(shiftX, -12, 12)
	elseif role == "Winger" and math.sign(baseLocal.X) ~= math.sign(ballLocal.X) then
		targetX *= 0.68
	elseif role == "ST" then
		targetX *= 0.45
	end
	local markRoot = assignment.MarkTarget and assignment.MarkTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
	if markRoot and (role == "CB" or role == "Fullback" or role == "CM" or role == "CDM") then
		local markLocal = context.PitchCFrame:PointToObjectSpace(markRoot.Position)
		if role == "CB" then
			targetX = targetX * 0.55 + markLocal.X * 0.45
		elseif role == "Fullback" then
			targetX = targetX * 0.42 + markLocal.X * 0.58
			targetZ = targetZ * 0.68 + markLocal.Z * 0.32
		else
			targetX = targetX * 0.7 + markLocal.X * 0.3
			targetZ = targetZ * 0.74 + markLocal.Z * 0.26
		end
	end
	return context.PitchCFrame:PointToWorldSpace(Vector3.new(targetX, 3, targetZ)), "HoldZone"
end

return Service
