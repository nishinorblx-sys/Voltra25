--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tuning = require(ReplicatedStorage.VTR.Shared.DribbleTuningConfig)

local Service = {}

function Service.Rotate(model: Model, direction: Vector3, hasBall: boolean, sprinting: boolean, dt: number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or direction.Magnitude < 0.05 then
		return
	end
	local current = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local target = Vector3.new(direction.X, 0, direction.Z).Unit
	if current.Magnitude < 0.05 then current = target else current = current.Unit end
	local dot = math.clamp(current:Dot(target), -1, 1)
	local signedAngle = math.atan2(current:Cross(target).Y, dot)
	local agility = math.clamp(tonumber(model:GetAttribute("Agility")) or 60, 1, 99) / 99
	local maxRate = not hasBall and Tuning.MaxTurnRateNoBall or sprinting and Tuning.MaxTurnRateSprintingWithBall or Tuning.MaxTurnRateDribbling
	maxRate *= 0.72 + agility * 0.42
	local step = math.clamp(signedAngle, -maxRate * dt, maxRate * dt)
	local rotated = CFrame.fromAxisAngle(Vector3.yAxis, step):VectorToWorldSpace(current)
	local desired = CFrame.lookAt(root.Position, root.Position + rotated)
	local smoothing = hasBall and (sprinting and 0.075 or 0.052) or 0.04
	root.CFrame = root.CFrame:Lerp(desired, 1 - math.exp(-dt / smoothing))
end

return Service
