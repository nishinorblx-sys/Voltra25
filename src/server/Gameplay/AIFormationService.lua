--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}

local FORMATIONS = {
	["4-3-3"] = {
		{Name = "GK", Role = "GK", X = 212, Z = 35, Lane = "Center"},
		{Name = "LB", Role = "Fullback", X = 75, Z = 165, Lane = "LeftWide"},
		{Name = "LCB", Role = "CB", X = 165, Z = 135, Lane = "LeftHalfSpace"},
		{Name = "RCB", Role = "CB", X = 259, Z = 135, Lane = "RightHalfSpace"},
		{Name = "RB", Role = "Fullback", X = 349, Z = 165, Lane = "RightWide"},
		{Name = "CDM", Role = "CDM", X = 212, Z = 255, Lane = "Center"},
		{Name = "LCM", Role = "CM", X = 150, Z = 345, Lane = "LeftHalfSpace"},
		{Name = "RCM", Role = "CM", X = 274, Z = 345, Lane = "RightHalfSpace"},
		{Name = "LW", Role = "Winger", X = 65, Z = 525, Lane = "LeftWide"},
		{Name = "ST", Role = "ST", X = 212, Z = 570, Lane = "Center"},
		{Name = "RW", Role = "Winger", X = 359, Z = 525, Lane = "RightWide"},
	},
	["4-2-3-1"] = {
		{Name = "GK", Role = "GK", X = 212, Z = 35, Lane = "Center"},
		{Name = "LB", Role = "Fullback", X = 75, Z = 165, Lane = "LeftWide"},
		{Name = "LCB", Role = "CB", X = 165, Z = 135, Lane = "LeftHalfSpace"},
		{Name = "RCB", Role = "CB", X = 259, Z = 135, Lane = "RightHalfSpace"},
		{Name = "RB", Role = "Fullback", X = 349, Z = 165, Lane = "RightWide"},
		{Name = "LDM", Role = "CDM", X = 170, Z = 280, Lane = "LeftHalfSpace"},
		{Name = "RDM", Role = "CDM", X = 254, Z = 280, Lane = "RightHalfSpace"},
		{Name = "LM", Role = "Winger", X = 70, Z = 455, Lane = "LeftWide"},
		{Name = "CAM", Role = "CAM", X = 212, Z = 455, Lane = "Center"},
		{Name = "RM", Role = "Winger", X = 354, Z = 455, Lane = "RightWide"},
		{Name = "ST", Role = "ST", X = 212, Z = 585, Lane = "Center"},
	},
	["4-4-2"] = {
		{Name = "GK", Role = "GK", X = 212, Z = 35, Lane = "Center"},
		{Name = "LB", Role = "Fullback", X = 75, Z = 165, Lane = "LeftWide"},
		{Name = "LCB", Role = "CB", X = 165, Z = 135, Lane = "LeftHalfSpace"},
		{Name = "RCB", Role = "CB", X = 259, Z = 135, Lane = "RightHalfSpace"},
		{Name = "RB", Role = "Fullback", X = 349, Z = 165, Lane = "RightWide"},
		{Name = "LM", Role = "Winger", X = 70, Z = 365, Lane = "LeftWide"},
		{Name = "LCM", Role = "CM", X = 170, Z = 345, Lane = "LeftHalfSpace"},
		{Name = "RCM", Role = "CM", X = 254, Z = 345, Lane = "RightHalfSpace"},
		{Name = "RM", Role = "Winger", X = 354, Z = 365, Lane = "RightWide"},
		{Name = "LST", Role = "ST", X = 178, Z = 575, Lane = "LeftHalfSpace"},
		{Name = "RST", Role = "ST", X = 246, Z = 575, Lane = "RightHalfSpace"},
	},
}

function Service.GetFormation(name: string?): {any}
	return FORMATIONS[name or "4-3-3"] or FORMATIONS["4-3-3"]
end

function Service.GetSlot(name: string?, index: number): any
	return Service.GetFormation(name)[index] or FORMATIONS["4-3-3"][index] or FORMATIONS["4-3-3"][1]
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
