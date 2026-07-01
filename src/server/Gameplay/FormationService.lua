--!strict
local Service = {}

local FORMATIONS = {
	["4-3-3"] = {
		{Name = "GK", Role = "GK", X = 0, Z = 0.88},
		{Name = "LB", Role = "Fullback", X = -0.72, Z = 0.57},
		{Name = "LCB", Role = "CB", X = -0.25, Z = 0.64},
		{Name = "RCB", Role = "CB", X = 0.25, Z = 0.64},
		{Name = "RB", Role = "Fullback", X = 0.72, Z = 0.57},
		{Name = "LCM", Role = "CM", X = -0.34, Z = 0.14},
		{Name = "CDM", Role = "CDM", X = 0, Z = 0.30},
		{Name = "RCM", Role = "CM", X = 0.34, Z = 0.14},
		{Name = "LW", Role = "Winger", X = -0.74, Z = -0.48},
		{Name = "ST", Role = "ST", X = 0, Z = -0.70},
		{Name = "RW", Role = "Winger", X = 0.74, Z = -0.48},
	},
	["4-4-2"] = {
		{Name = "GK", Role = "GK", X = 0, Z = 0.88},
		{Name = "LB", Role = "Fullback", X = -0.72, Z = 0.58},
		{Name = "LCB", Role = "CB", X = -0.25, Z = 0.65},
		{Name = "RCB", Role = "CB", X = 0.25, Z = 0.65},
		{Name = "RB", Role = "Fullback", X = 0.72, Z = 0.58},
		{Name = "LM", Role = "Winger", X = -0.72, Z = 0.05},
		{Name = "LCM", Role = "CM", X = -0.22, Z = 0.14},
		{Name = "RCM", Role = "CM", X = 0.22, Z = 0.14},
		{Name = "LS", Role = "ST", X = -0.24, Z = -0.60},
		{Name = "RS", Role = "ST", X = 0.24, Z = -0.67},
		{Name = "RM", Role = "Winger", X = 0.72, Z = 0.05},
	},
	["4-2-3-1"] = {
		{Name = "GK", Role = "GK", X = 0, Z = 0.88},
		{Name = "LB", Role = "Fullback", X = -0.72, Z = 0.58},
		{Name = "LCB", Role = "CB", X = -0.25, Z = 0.65},
		{Name = "RCB", Role = "CB", X = 0.25, Z = 0.65},
		{Name = "RB", Role = "Fullback", X = 0.72, Z = 0.58},
		{Name = "LDM", Role = "CDM", X = -0.24, Z = 0.29},
		{Name = "RDM", Role = "CDM", X = 0.24, Z = 0.29},
		{Name = "CAM", Role = "CAM", X = 0, Z = -0.10},
		{Name = "LW", Role = "Winger", X = -0.72, Z = -0.38},
		{Name = "ST", Role = "ST", X = 0, Z = -0.70},
		{Name = "RW", Role = "Winger", X = 0.72, Z = -0.38},
	},
	["3-5-2"] = {
		{Name = "GK", Role = "GK", X = 0, Z = 0.88},
		{Name = "LCB", Role = "CB", X = -0.42, Z = 0.64},
		{Name = "CB", Role = "CB", X = 0, Z = 0.70},
		{Name = "RCB", Role = "CB", X = 0.42, Z = 0.64},
		{Name = "RM", Role = "Winger", X = 0.76, Z = 0.05},
		{Name = "LCM", Role = "CM", X = -0.26, Z = 0.12},
		{Name = "CDM", Role = "CDM", X = 0, Z = 0.26},
		{Name = "RCM", Role = "CM", X = 0.26, Z = 0.12},
		{Name = "LM", Role = "Winger", X = -0.76, Z = 0.05},
		{Name = "LS", Role = "ST", X = -0.24, Z = -0.62},
		{Name = "RS", Role = "ST", X = 0.24, Z = -0.62},
	},
	["5-3-2"] = {
		{Name = "GK", Role = "GK", X = 0, Z = 0.88},
		{Name = "LWB", Role = "Fullback", X = -0.82, Z = 0.44},
		{Name = "LCB", Role = "CB", X = -0.36, Z = 0.64},
		{Name = "CB", Role = "CB", X = 0, Z = 0.70},
		{Name = "RCB", Role = "CB", X = 0.36, Z = 0.64},
		{Name = "RWB", Role = "Fullback", X = 0.82, Z = 0.44},
		{Name = "LCM", Role = "CM", X = -0.28, Z = 0.10},
		{Name = "RCM", Role = "CM", X = 0.28, Z = 0.10},
		{Name = "CAM", Role = "CAM", X = 0, Z = -0.05},
		{Name = "LS", Role = "ST", X = -0.24, Z = -0.62},
		{Name = "RS", Role = "ST", X = 0.24, Z = -0.62},
	},
}

function Service.Get(name: string?): {any}
	return FORMATIONS[name or "4-3-3"] or FORMATIONS["4-3-3"]
end

function Service.Build(name: string?, width: number, length: number): {Vector2}
	local points = {}
	for index, slot in Service.Get(name) do
		points[index] = Vector2.new(slot.X * width * 0.46, slot.Z * length * 0.48)
	end
	return points
end

function Service.GetAssignment(name: string?, index: number): any
	return Service.Get(name)[index] or Service.Get("4-3-3")[index]
end

function Service.WorldPosition(name: string?, index: number, side: string, pitchCFrame: CFrame, width: number, length: number): Vector3
	local slot = Service.GetAssignment(name, index)
	local sign = side == "Home" and 1 or -1
	return pitchCFrame:PointToWorldSpace(Vector3.new(slot.X * width * 0.46, 3, slot.Z * length * 0.48 * sign))
end

return Service
