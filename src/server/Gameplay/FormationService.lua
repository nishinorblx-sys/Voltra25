--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FormationConfig = require(ReplicatedStorage.VTR.Shared.FormationConfig)

local Service = {}

function Service.Get(name: string?): {any}
	local output = {}
	for index, slot in ipairs(FormationConfig.IterSlots(name)) do
		output[index] = FormationConfig.ToSpawnAnchor(slot)
	end
	return output
end

function Service.Build(name: string?, width: number, length: number): {Vector2}
	return FormationConfig.BuildSpawn(name, width, length)
end

function Service.GetAssignment(name: string?, index: number): any
	return Service.Get(name)[index] or Service.Get(FormationConfig.Default)[index] or Service.Get(FormationConfig.Default)[1]
end

function Service.WorldPosition(name: string?, index: number, side: string, pitchCFrame: CFrame, width: number, length: number): Vector3
	local slot = Service.GetAssignment(name, index)
	local sign = side == "Home" and 1 or -1
	return pitchCFrame:PointToWorldSpace(Vector3.new(slot.X * width * 0.46, 3, slot.Z * length * 0.48 * sign))
end

return Service
