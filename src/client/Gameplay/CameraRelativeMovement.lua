--!strict
local Module = {}

local DEBUG_COLORS = {
	Forward = Color3.fromHex("35D9FF"),
	Right = Color3.fromHex("FFB020"),
	Move = Color3.fromHex("FFFFFF"),
}

local debugFolder: Folder? = nil

local function flat(vector: Vector3, fallback: Vector3): Vector3
	local projected = Vector3.new(vector.X, 0, vector.Z)
	return projected.Magnitude > 0.001 and projected.Unit or fallback
end

function Module.GetBasis(camera: Camera): (Vector3, Vector3)
	local forward = flat(camera.CFrame.LookVector, Vector3.new(0, 0, -1))
	local right = flat(camera.CFrame.RightVector, Vector3.new(1, 0, 0))
	-- Re-orthogonalize after removing Y so steep tactical camera angles
	-- cannot skew diagonal input.
	right = forward:Cross(Vector3.yAxis)
	if right.Magnitude < 0.001 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	return forward, right
end

function Module.GetMoveDirection(camera: Camera, inputVector: Vector2): Vector3
	local forward, right = Module.GetBasis(camera)
	local direction = forward * inputVector.Y + right * inputVector.X
	return direction.Magnitude > 1 and direction.Unit or direction
end

local function arrow(parent: Folder, name: string, color: Color3): Part
	local part = parent:FindFirstChild(name) :: Part?
	if part then
		return part
	end
	part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.18
	part.Size = Vector3.new(0.16, 0.16, 6)
	part.Parent = parent
	return part
end

local function placeArrow(part: Part, origin: Vector3, direction: Vector3)
	if direction.Magnitude < 0.05 then
		part.Transparency = 1
		return
	end
	part.Transparency = 0.18
	local length = 6
	local unit = direction.Unit
	part.CFrame = CFrame.lookAt(origin + unit * length * 0.5, origin + unit * length)
end

function Module.UpdateDebug(origin: Vector3, camera: Camera, finalDirection: Vector3)
	if workspace:GetAttribute("GameplayDebug") ~= true then
		if debugFolder then
			debugFolder:Destroy()
			debugFolder = nil
		end
		return
	end
	if not debugFolder then
		debugFolder = Instance.new("Folder")
		debugFolder.Name = "VTRMovementDebug"
		debugFolder.Parent = workspace
	end
	local forward, right = Module.GetBasis(camera)
	local raisedOrigin = origin + Vector3.new(0, 0.25, 0)
	placeArrow(arrow(debugFolder, "CameraForward", DEBUG_COLORS.Forward), raisedOrigin, forward)
	placeArrow(arrow(debugFolder, "CameraRight", DEBUG_COLORS.Right), raisedOrigin, right)
	placeArrow(arrow(debugFolder, "FinalMoveDirection", DEBUG_COLORS.Move), raisedOrigin, finalDirection)
end

function Module.ClearDebug()
	if debugFolder then
		debugFolder:Destroy()
		debugFolder = nil
	end
end

return Module
