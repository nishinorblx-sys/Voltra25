--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Power = require(ReplicatedStorage.VTR.Shared.PassingPowerConfig)

local Service = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function Service.Predict(passerPosition: Vector3, receiverRoot: BasePart, through: boolean?, charge: number): (Vector3, number)
	local target = receiverRoot.Position
	local velocity = flat(receiverRoot.AssemblyLinearVelocity)
	if velocity.Magnitude > 19 then velocity = velocity.Unit * 19 end
	for _ = 1, 2 do
		local distance = flat(target - passerPosition).Magnitude
		local speed = Service.RequiredInitialSpeed(distance, charge)
		local leadTime = math.clamp(distance / math.max(speed, 1) * (through and 0.52 or 0.66), 0.08, through and 0.46 or 0.86)
		local lead = velocity * leadTime
		local maxLead = through and 8 or 15
		if lead.Magnitude > maxLead then lead = lead.Unit * maxLead end
		target = receiverRoot.Position + lead
	end
	return target, flat(target - passerPosition).Magnitude
end

function Service.RequiredInitialSpeed(distance: number, charge: number): number
	return Power.SpeedForDistance(distance,charge)
end

return Service
