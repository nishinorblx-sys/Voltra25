--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local GoalAimPlaneService = require(script.Parent.GoalAimPlaneService)

local Controller = {}
Controller.__index = Controller

local function footballerFrom(instance: Instance?): Model?
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") and current:GetAttribute("VTRTeam") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Controller.new(camera: Camera, pitchCFrame: CFrame, width: number, length: number)
	return setmetatable({Camera = camera, Mouse=Players.LocalPlayer:GetMouse(), PitchCFrame = pitchCFrame, Width = width, Length = length, GoalPlane = GoalAimPlaneService.new(pitchCFrame, width, length), AimWorldPosition = pitchCFrame.Position, GoalAiming = false, GoalAimPoint = nil}, Controller)
end

function Controller:SetActive(model: Model?)
	self.Active = model
end

function Controller:_opponentGoalZ(): number
	local side = self.Active and tostring(self.Active:GetAttribute("VTRTeam") or "Home") or "Home"
	return side == "Home" and -self.Length / 2 or self.Length / 2
end

function Controller:Update()
	-- Mouse.UnitRay is already aligned to the rendered cursor and avoids the
	-- inconsistent top-bar inset behavior of manual viewport conversion.
	local ray = self.Mouse.UnitRay
	local origin = self.PitchCFrame:PointToObjectSpace(ray.Origin)
	local direction = self.PitchCFrame:VectorToObjectSpace(ray.Direction)
	self.GoalAiming = false
	self.GoalAimPoint = nil
	local goalAiming, goalPoint = self.GoalPlane:ProjectRay(self.Active, ray.Origin, ray.Direction)
	-- A keeper stands in front of the goal plane and is a natural mouse target.
	-- Treat hitting the opposing GK as goal aim, then place the reticle on the
	-- corresponding point of the net behind them.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = self.Active and {self.Active} or {}
	rayParams.RespectCanCollide = false
	local result = workspace:Raycast(ray.Origin, ray.Direction * 3000, rayParams)
	local hitPlayer = result and footballerFrom(result.Instance) or nil
	local activeTeam = self.Active and self.Active:GetAttribute("VTRTeam")
	if hitPlayer and hitPlayer:GetAttribute("position") == "GK" and hitPlayer:GetAttribute("VTRTeam") ~= activeTeam then
		if not goalPoint then
			local keeperRoot = hitPlayer:FindFirstChild("HumanoidRootPart") :: BasePart?
			goalPoint = self.GoalPlane:ClampPoint(self.Active, keeperRoot and keeperRoot.Position or result.Position)
		end
		goalAiming = true
	end
	if goalAiming and goalPoint then
		self.GoalAimPoint = goalPoint
		self.AimWorldPosition = goalPoint
		self.GoalAiming = true
		return
	end
	local hitLocal: Vector3
	if math.abs(direction.Y) > 0.0001 then
		local pitchTime = -origin.Y / direction.Y
		hitLocal = pitchTime > 0 and (origin + direction * pitchTime) or (origin + direction * 220)
	else
		hitLocal = origin + direction * 220
	end
	hitLocal = Vector3.new(math.clamp(hitLocal.X, -self.Width / 2, self.Width / 2), 0.12, math.clamp(hitLocal.Z, -self.Length / 2, self.Length / 2))
	self.AimWorldPosition = self.PitchCFrame:PointToWorldSpace(hitLocal)
end

function Controller:GetAimWorldPosition(): Vector3
	return self.AimWorldPosition
end

function Controller:GetAimDirectionFromPlayer(playerPosition: Vector3): Vector3
	local direction = self.AimWorldPosition - playerPosition
	return direction.Magnitude > 0.01 and direction.Unit or self.Camera.CFrame.LookVector
end

function Controller:IsAimingAtGoal(): boolean
	return self.GoalAiming
end

function Controller:GetGoalAimPoint(charge:number?): Vector3?
	if self.GoalAimPoint and charge and charge>0 then return self.GoalPlane:ApplyShotPower(self.Active,self.GoalAimPoint,charge)end
	return self.GoalAimPoint
end

return Controller
