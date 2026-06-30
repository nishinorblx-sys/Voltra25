--!strict
local Controller = {}
Controller.__index = Controller

local function getMarker(): BasePart?
	local marker = workspace:FindFirstChild("CornerCamera", true)
	if marker and marker:IsA("BasePart") then
		marker.LocalTransparencyModifier = 1
		return marker
	end
	return nil
end

local function sign(value: number): number
	return value >= 0 and 1 or -1
end

function Controller.new(data: any)
	return setmetatable({
		Camera = workspace.CurrentCamera,
		PitchCFrame = data.PitchCFrame,
		GoalSign = data.GoalSign,
		CornerSign = data.CornerSign,
		Marker = getMarker(),
		FieldOfView = 55,
	}, Controller)
end

function Controller:SetTarget(_target: Vector3)
	-- Corner camera is now fully authored by the CornerCamera marker.
end

function Controller:_resolveMarkerCFrame(): (CFrame, number)
	local marker = self.Marker
	if not marker or not marker.Parent then
		local fallback = self.PitchCFrame * CFrame.new(self.CornerSign * -18, 9, self.GoalSign * (self.PitchLength and self.PitchLength * 0.5 or 55))
		return fallback, self.FieldOfView
	end

	local reference = self.PitchCFrame:ToObjectSpace(marker.CFrame)
	local referencePosition = reference.Position
	local referenceCornerSign = sign(referencePosition.X)
	local referenceGoalSign = sign(referencePosition.Z)
	local mirrorX = self.CornerSign / referenceCornerSign
	local mirrorZ = self.GoalSign / referenceGoalSign

	local function mirrorVector(vector: Vector3): Vector3
		return Vector3.new(vector.X * mirrorX, vector.Y, vector.Z * mirrorZ)
	end

	local mirroredPosition = Vector3.new(
		referencePosition.X * mirrorX,
		referencePosition.Y,
		referencePosition.Z * mirrorZ
	)
	local worldPosition = self.PitchCFrame:PointToWorldSpace(mirroredPosition)
	local worldLook = self.PitchCFrame:VectorToWorldSpace(mirrorVector(reference.LookVector))
	local worldUp = self.PitchCFrame:VectorToWorldSpace(mirrorVector(reference.UpVector))
	local fov = tonumber(marker:GetAttribute("FieldOfView")) or self.FieldOfView

	return CFrame.lookAt(worldPosition, worldPosition + worldLook, worldUp), fov
end

function Controller:Update(_dt: number)
	local desired, fov = self:_resolveMarkerCFrame()
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Camera.CFrame = desired
	self.Camera.FieldOfView = fov
end

function Controller:Destroy()
end

return Controller
