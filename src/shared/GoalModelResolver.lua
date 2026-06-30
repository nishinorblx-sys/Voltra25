--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local Resolver = {}

export type GoalRectangle = {
	PlanePoint: Vector3,
	Normal: Vector3,
	Right: Vector3,
	Up: Vector3,
	Left: number,
	RightBound: number,
	Bottom: number,
	Top: number,
	Hitbox: BasePart?,
}

local function partsOf(instance: Instance): {BasePart}
	local parts = {}
	if instance:IsA("BasePart") then table.insert(parts, instance) end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then table.insert(parts, descendant) end
	end
	return parts
end

local function namedPart(instance: Instance, name: string): BasePart?
	local found = instance:FindFirstChild(name, true)
	return found and found:IsA("BasePart") and found or nil
end

function Resolver.GetHitboxForSide(scoringSide:string):BasePart?
	-- A goal named for the defending side awards the opposing/scoring side.
	local name=scoringSide=="Home"and"AwayGoal"or"HomeGoal"
	local direct=workspace:FindFirstChild(name)
	return direct and direct:IsA("BasePart")and direct or nil
end

local function rectangleFromHitbox(hitbox:BasePart,expectedNormal:Vector3):GoalRectangle
	local right=hitbox.CFrame.RightVector;local up=hitbox.CFrame.UpVector;local normal=hitbox.CFrame.LookVector
	if normal:Dot(expectedNormal)<0 then normal=-normal end
	local width=hitbox.Size.X;local height=hitbox.Size.Y
	local bottomLeft=hitbox.Position-right*(width*.5)-up*(height*.5)
	return{PlanePoint=bottomLeft,Normal=normal.Unit,Right=right,Up=up,Left=0,RightBound=width,Bottom=0,Top=height,Hitbox=hitbox}
end

local function candidateScore(instance: Instance, pitchCFrame: CFrame, targetZ: number): number?
	local name = string.lower(instance.Name)
	if not string.find(name, "goal", 1, true) and not string.find(name, "net", 1, true) then return nil end
	local parts = partsOf(instance)
	if #parts == 0 then return nil end
	local sum = Vector3.zero
	for _, part in parts do sum += part.Position end
	local localCenter = pitchCFrame:PointToObjectSpace(sum / #parts)
	return math.abs(localCenter.Z - targetZ) + math.abs(localCenter.X) * 0.1
end

local function resolveCandidate(side: string, pitchCFrame: CFrame, length: number): Instance?
	local targetZ = side == "Home" and -length / 2 or length / 2
	local best: Instance? = nil
	local bestScore = math.huge
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("Model") or instance:IsA("BasePart") then
			local score = candidateScore(instance, pitchCFrame, targetZ)
			if score and score < bestScore then best, bestScore = instance, score end
		end
	end
	return best
end

function Resolver.ResolveSide(side: string, pitchCFrame: CFrame, width: number, length: number): GoalRectangle
	local targetZ = side == "Home" and -length / 2 or length / 2
	local up = pitchCFrame.UpVector
	local right = pitchCFrame.RightVector
	local expectedNormal = pitchCFrame.LookVector * (targetZ < 0 and -1 or 1)
	local normal = expectedNormal
	local authoritativeHitbox=Resolver.GetHitboxForSide(side)
	if authoritativeHitbox then return rectangleFromHitbox(authoritativeHitbox,expectedNormal)end
	local candidate = resolveCandidate(side, pitchCFrame, length)
	if candidate then
		local leftPost = namedPart(candidate, "LeftPost")
		local rightPost = namedPart(candidate, "RightPost")
		local crossbar = namedPart(candidate, "Crossbar")
		local plane = namedPart(candidate, "GoalPlane")
		if leftPost and rightPost then
			local across = rightPost.Position - leftPost.Position
			if across.Magnitude > 1 then
				right = across.Unit
				local leftThickness = math.max(0.12, math.abs(leftPost.Size:Dot(right)))
				local rightThickness = math.max(0.12, math.abs(rightPost.Size:Dot(right)))
				local insideLeft = leftPost.Position + right * leftThickness * 0.5
				local insideRight = rightPost.Position - right * rightThickness * 0.5
				local ground = math.min(leftPost.Position.Y - leftPost.Size.Y * 0.5, rightPost.Position.Y - rightPost.Size.Y * 0.5)
				local top = crossbar and (crossbar.Position.Y - crossbar.Size.Y * 0.5) or (ground + math.min(leftPost.Size.Y, rightPost.Size.Y))
				local planePoint = plane and plane.Position or (insideLeft + insideRight) * 0.5
				if plane then normal = plane.CFrame.LookVector; if normal:Dot(expectedNormal) < 0 then normal = -normal end end
				return {PlanePoint = Vector3.new(planePoint.X, ground, planePoint.Z), Normal = normal.Unit, Right = right, Up = up, Left = 0, RightBound = (insideRight - insideLeft).Magnitude, Bottom = 0, Top = math.max(1, top - ground)}
			end
		end
		local parts = partsOf(candidate)
		local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
		local zSum = 0
		for _, part in parts do
			local localPosition = pitchCFrame:PointToObjectSpace(part.Position)
			minX = math.min(minX, localPosition.X - part.Size.X * 0.5)
			maxX = math.max(maxX, localPosition.X + part.Size.X * 0.5)
			minY = math.min(minY, localPosition.Y - part.Size.Y * 0.5)
			maxY = math.max(maxY, localPosition.Y + part.Size.Y * 0.5)
			zSum += localPosition.Z
		end
		if maxX > minX and maxY > minY then
			local localPlane = Vector3.new(minX, minY, zSum / #parts)
			return {PlanePoint = pitchCFrame:PointToWorldSpace(localPlane), Normal = normal.Unit, Right = right, Up = up, Left = 0.12, RightBound = maxX - minX - 0.12, Bottom = 0.08, Top = maxY - minY - 0.12}
		end
	end
	local goalWidth = math.min(Config.Pitch.GoalWidth, width * 0.28)
	local planePoint = pitchCFrame:PointToWorldSpace(Vector3.new(-goalWidth / 2, 0, targetZ))
	return {PlanePoint = planePoint, Normal = normal.Unit, Right = right, Up = up, Left = 0.12, RightBound = goalWidth - 0.12, Bottom = 0.08, Top = Config.Pitch.GoalHeight - 0.12}
end

function Resolver.Resolve(active: Model?, pitchCFrame: CFrame, width: number, length: number): GoalRectangle
	local side = active and tostring(active:GetAttribute("VTRTeam") or "Home") or "Home"
	return Resolver.ResolveSide(side, pitchCFrame, width, length)
end

function Resolver.Point(rectangle: GoalRectangle, horizontal: number, vertical: number): Vector3
	return rectangle.PlanePoint + rectangle.Right * horizontal + rectangle.Up * vertical
end

function Resolver.ClampPoint(rectangle: GoalRectangle, point: Vector3): Vector3
	local offset = point - rectangle.PlanePoint
	return Resolver.Point(rectangle, math.clamp(offset:Dot(rectangle.Right), rectangle.Left, rectangle.RightBound), math.clamp(offset:Dot(rectangle.Up), rectangle.Bottom, rectangle.Top))
end

function Resolver.ProjectRay(rectangle: GoalRectangle, origin: Vector3, direction: Vector3): (boolean, Vector3?)
	local denominator = direction:Dot(rectangle.Normal)
	if math.abs(denominator) < 0.0001 then return false, nil end
	local time = (rectangle.PlanePoint - origin):Dot(rectangle.Normal) / denominator
	if time <= 0 then return false, nil end
	local hit = origin + direction * time
	local offset = hit - rectangle.PlanePoint
	local x, y = offset:Dot(rectangle.Right), offset:Dot(rectangle.Up)
	local captureX = rectangle.Hitbox and 0 or (rectangle.RightBound - rectangle.Left) * 0.3
	local captureY = rectangle.Hitbox and 0 or (rectangle.Top - rectangle.Bottom) * 0.45
	if x < rectangle.Left - captureX or x > rectangle.RightBound + captureX or y < rectangle.Bottom - captureY or y > rectangle.Top + captureY then return false, nil end
	return true, Resolver.ClampPoint(rectangle, hit)
end

return Resolver
