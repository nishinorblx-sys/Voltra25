--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new()
	return setmetatable({
		Camera = workspace.CurrentCamera,
		Character = nil,
		Root = nil,
		Yaw = math.rad(180),
		Pitch = math.rad(12),
		TacticalView = false,
		TacticalCFrame = nil,
	}, CameraController)
end

function CameraController:Start(character: Model)
	self:SetCharacter(character)
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Camera.FieldOfView = Config.Camera.FieldOfView
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

function CameraController:SetCharacter(character: Model)
	self.Character = character
	self.Root = character:WaitForChild("HumanoidRootPart", 15)
	local look = self.Root.CFrame.LookVector
	self.Yaw = math.atan2(-look.X, -look.Z)
end

function CameraController:GetForward(): Vector3
	return Vector3.new(-math.sin(self.Yaw), 0, -math.cos(self.Yaw)).Unit
end

function CameraController:GetRight(): Vector3
	local forward = self:GetForward()
	return Vector3.new(-forward.Z, 0, forward.X)
end

function CameraController:GetAimDirection(): Vector3
	return self:GetForward()
end

function CameraController:SetTacticalView(active: boolean, pitchCFrame: CFrame?, width: number?, length: number?)
	self.TacticalView = active == true
	if self.TacticalView and pitchCFrame then
		local cameraHeight = math.max((length or 180) * 0.82, 150)
		local back = (length or 180) * 0.18
		local side = (width or 120) * 0.14
		local position = pitchCFrame:PointToWorldSpace(Vector3.new(side, cameraHeight, back))
		local focus = pitchCFrame:PointToWorldSpace(Vector3.new(0, 0, 0))
		self.TacticalCFrame = CFrame.lookAt(position, focus)
		self.Camera.CameraType = Enum.CameraType.Scriptable
		self.Camera.FieldOfView = 58
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	elseif self.Camera then
		self.TacticalCFrame = nil
		self.Camera.CameraType = Enum.CameraType.Scriptable
		self.Camera.FieldOfView = Config.Camera.FieldOfView
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

function CameraController:Update(delta: number, sprinting: boolean)
	if self.TacticalView then
		if self.TacticalCFrame then
			self.Camera.CFrame = self.Camera.CFrame:Lerp(self.TacticalCFrame, 1 - math.exp(-8 * delta))
			self.Camera.FieldOfView += (58 - self.Camera.FieldOfView) * (1 - math.exp(-7 * delta))
		end
		return
	end
	if not self.Root or not self.Root.Parent then return end
	local mouseDelta = UserInputService:GetMouseDelta()
	self.Yaw -= mouseDelta.X * Config.Camera.Sensitivity
	self.Pitch = math.clamp(self.Pitch - mouseDelta.Y * Config.Camera.Sensitivity, Config.Camera.MinPitch, Config.Camera.MaxPitch)
	local focus = self.Root.Position + Vector3.new(0, Config.Camera.FocusHeight, 0)
	local rotation = CFrame.fromOrientation(self.Pitch, self.Yaw, 0)
	local look = rotation.LookVector
	local desired = focus - look * Config.Camera.Distance + Vector3.new(0, Config.Camera.Height - Config.Camera.FocusHeight, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { self.Character :: Model }
	local hit = workspace:Raycast(focus, desired - focus, rayParams)
	if hit then desired = hit.Position + hit.Normal * 0.5 end
	local targetCFrame = CFrame.lookAt(desired, focus)
	self.Camera.CFrame = self.Camera.CFrame:Lerp(targetCFrame, 1 - math.exp(-16 * delta))
	local targetFov = sprinting and Config.Camera.SprintFieldOfView or Config.Camera.FieldOfView
	self.Camera.FieldOfView += (targetFov - self.Camera.FieldOfView) * (1 - math.exp(-7 * delta))
end

return CameraController
