--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PitchConfig = require(script.Parent.PitchConfig)
local FormationConfig = require(ReplicatedStorage.VTR.Shared.FormationConfig)

local Service = {}

function Service.GetFormation(name: string?): {any}
	return FormationConfig.BuildAI(name)
end

function Service.GetSlot(name: string?, index: number): any
	return Service.GetFormation(name)[index] or FormationConfig.BuildAI(FormationConfig.Default)[index] or FormationConfig.BuildAI(FormationConfig.Default)[1]
end

function Service.GetBasePitchPosition(name: string?, index: number): Vector3
	local slot = Service.GetSlot(name, index)
	return Vector3.new(slot.X, 3, slot.Z)
end

function Service.GetBaseWorldPosition(name: string?, index: number, side: string, options: any): Vector3
	return PitchConfig.TeamPitchPositionToWorld(Service.GetBasePitchPosition(name, index), side, options)
end

function Service.IsDefenderRole(role: string): boolean
	return role == "CB" or role == "Fullback" or role == "GK"
end

function Service.IsMidfielderRole(role: string): boolean
	return role == "CDM" or role == "CM" or role == "CAM"
end

function Service.IsAttackerRole(role: string): boolean
	return role == "ST" or role == "Winger" or role == "CAM"
end

function Service.GetPreferredLane(slot: any): string
	return slot.Lane or PitchConfig.GetLane(Vector3.new(slot.X or 212, 0, slot.Z or 371))
end

return Service
