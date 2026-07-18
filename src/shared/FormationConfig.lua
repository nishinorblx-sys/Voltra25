--!strict

local Config = {}

local DEFAULT_ORDER = {"GK","LB","CB1","CB2","RB","CDM","CM1","CM2","LW","ST","RW"}

local function slot(x: number, y: number, label: string, expected: string, role: string?, lane: string?): any
	return {X = x, Y = y, Label = label, Expected = expected, Role = role or expected, Lane = lane}
end

Config.Order = DEFAULT_ORDER
Config.Default = "4-3-3"
Config.PitchWidth = 424
Config.PitchLength = 742
Config.AIAnchorZMin = 35
Config.AIAnchorZMax = 585
Config.Orders = {
	["4-3-3"] = DEFAULT_ORDER,
	["4-4-2"] = DEFAULT_ORDER,
	["4-2-3-1"] = DEFAULT_ORDER,
	["3-5-2"] = DEFAULT_ORDER,
	["5-3-2"] = DEFAULT_ORDER,
	["5V5"] = {"GK","CB1","CM1","CM2","ST","RW"},
}

Config.Formations = {
	["4-3-3"] = {
		GK = slot(.50,.88,"GK","GK","GK","Center"),
		LB = slot(.18,.70,"LB","LB","Fullback","LeftWide"),
		CB1 = slot(.38,.70,"LCB","CB","CB","LeftHalfSpace"),
		CB2 = slot(.62,.70,"RCB","CB","CB","RightHalfSpace"),
		RB = slot(.82,.70,"RB","RB","Fullback","RightWide"),
		CDM = slot(.50,.56,"CDM","CDM","CDM","Center"),
		CM1 = slot(.32,.48,"LCM","CM","CM","LeftHalfSpace"),
		CM2 = slot(.68,.48,"RCM","CM","CM","RightHalfSpace"),
		LW = slot(.18,.25,"LW","LW","Winger","LeftWide"),
		ST = slot(.50,.18,"ST","ST","ST","Center"),
		RW = slot(.82,.25,"RW","RW","Winger","RightWide"),
	},
	["4-4-2"] = {
		GK = slot(.50,.88,"GK","GK","GK","Center"),
		LB = slot(.18,.70,"LB","LB","Fullback","LeftWide"),
		CB1 = slot(.38,.70,"LCB","CB","CB","LeftHalfSpace"),
		CB2 = slot(.62,.70,"RCB","CB","CB","RightHalfSpace"),
		RB = slot(.82,.70,"RB","RB","Fullback","RightWide"),
		CM1 = slot(.38,.49,"LCM","CM","CM","LeftHalfSpace"),
		CDM = slot(.62,.49,"RCM","CM","CM","RightHalfSpace"),
		CM2 = slot(.62,.24,"RS","ST","ST","RightHalfSpace"),
		LW = slot(.16,.46,"LM","LW","Winger","LeftWide"),
		ST = slot(.38,.24,"LS","ST","ST","LeftHalfSpace"),
		RW = slot(.84,.46,"RM","RW","Winger","RightWide"),
	},
	["4-2-3-1"] = {
		GK = slot(.50,.88,"GK","GK","GK","Center"),
		LB = slot(.18,.70,"LB","LB","Fullback","LeftWide"),
		CB1 = slot(.38,.70,"LCB","CB","CB","LeftHalfSpace"),
		CB2 = slot(.62,.70,"RCB","CB","CB","RightHalfSpace"),
		RB = slot(.82,.70,"RB","RB","Fullback","RightWide"),
		CM1 = slot(.38,.54,"LDM","CDM","CDM","LeftHalfSpace"),
		CM2 = slot(.62,.54,"RDM","CDM","CDM","RightHalfSpace"),
		CDM = slot(.50,.38,"CAM","CAM","CAM","Center"),
		LW = slot(.20,.35,"LM","LW","Winger","LeftWide"),
		ST = slot(.50,.18,"ST","ST","ST","Center"),
		RW = slot(.80,.35,"RM","RW","Winger","RightWide"),
	},
	["3-5-2"] = {
		GK = slot(.50,.88,"GK","GK","GK","Center"),
		LB = slot(.28,.70,"LCB","CB","CB","LeftHalfSpace"),
		CB1 = slot(.50,.73,"CB","CB","CB","Center"),
		CB2 = slot(.72,.70,"RCB","CB","CB","RightHalfSpace"),
		RB = slot(.86,.48,"RM","RW","Winger","RightWide"),
		CM1 = slot(.37,.50,"LCM","CM","CM","LeftHalfSpace"),
		CDM = slot(.50,.58,"CDM","CDM","CDM","Center"),
		CM2 = slot(.63,.50,"RCM","CM","CM","RightHalfSpace"),
		LW = slot(.14,.48,"LM","LW","Winger","LeftWide"),
		ST = slot(.39,.22,"LS","ST","ST","LeftHalfSpace"),
		RW = slot(.61,.22,"RS","ST","ST","RightHalfSpace"),
	},
	["5-3-2"] = {
		GK = slot(.50,.88,"GK","GK","GK","Center"),
		LB = slot(.12,.62,"LWB","LB","Fullback","LeftWide"),
		CB1 = slot(.34,.70,"LCB","CB","CB","LeftHalfSpace"),
		CDM = slot(.50,.74,"CB","CB","CB","Center"),
		CB2 = slot(.66,.70,"RCB","CB","CB","RightHalfSpace"),
		RB = slot(.88,.62,"RWB","RB","Fullback","RightWide"),
		CM1 = slot(.35,.45,"LCM","CM","CM","LeftHalfSpace"),
		CM2 = slot(.65,.45,"RCM","CM","CM","RightHalfSpace"),
		LW = slot(.50,.50,"CAM","CAM","CAM","Center"),
		ST = slot(.39,.22,"LS","ST","ST","LeftHalfSpace"),
		RW = slot(.61,.22,"RS","ST","ST","RightHalfSpace"),
	},
	["5V5"] = {
		GK = slot(.50,.88,"GK","GK","GK","Center"),
		CB1 = slot(.50,.64,"CB","CB","CB","Center"),
		CM1 = slot(.32,.46,"LMID","CM","CM","LeftHalfSpace"),
		CM2 = slot(.68,.46,"RMID","CM","CM","RightHalfSpace"),
		ST = slot(.38,.22,"LCF","ST","ST","LeftHalfSpace"),
		RW = slot(.62,.22,"RCF","ST","ST","RightHalfSpace"),
	},
}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

function Config.NormalizeName(name: string?): string
	local clean = tostring(name or Config.Default)
	return Config.Formations[clean] and clean or Config.Default
end

function Config.GetOrder(name: string?): {string}
	local clean = Config.NormalizeName(name)
	return Config.Orders[clean] or DEFAULT_ORDER
end

function Config.GetFormation(name: string?): any
	return Config.Formations[Config.NormalizeName(name)]
end

function Config.GetSlot(name: string?, indexOrSlot: any): any
	local clean = Config.NormalizeName(name)
	local formation = Config.Formations[clean]
	local key = indexOrSlot
	if type(indexOrSlot) == "number" then
		key = (Config.Orders[clean] or DEFAULT_ORDER)[indexOrSlot]
	end
	local resolved = formation[key]
	if resolved then
		return resolved
	end
	local fallbackKey = DEFAULT_ORDER[type(indexOrSlot) == "number" and indexOrSlot or 1] or "GK"
	return Config.Formations[Config.Default][fallbackKey] or Config.Formations[Config.Default].GK
end

function Config.IterSlots(name: string?): {any}
	local clean = Config.NormalizeName(name)
	local output = {}
	for index, key in ipairs(Config.GetOrder(clean)) do
		local item = Config.GetSlot(clean, key)
		output[index] = {
			Key = key,
			Name = tostring(item.Label or key),
			Role = tostring(item.Role or item.Expected or item.Label or key),
			Expected = tostring(item.Expected or item.Role or item.Label or key),
			X = item.X,
			Y = item.Y,
			Lane = item.Lane,
			Label = item.Label,
		}
	end
	return output
end

function Config.ToSpawnAnchor(slotInfo: any): any
	local x = (clamp01(tonumber(slotInfo.X) or .5) - .5) * 2
	local z = (clamp01(tonumber(slotInfo.Y) or .5) - .5) * 2
	return {Name = tostring(slotInfo.Label or slotInfo.Expected or "CM"), Role = tostring(slotInfo.Role or slotInfo.Expected or "CM"), X = x, Z = z}
end

function Config.ToAIAnchor(slotInfo: any): any
	local x = clamp01(tonumber(slotInfo.X) or .5) * Config.PitchWidth
	local attackingDepth = 1 - clamp01(tonumber(slotInfo.Y) or .5)
	local z = Config.AIAnchorZMin + math.pow(attackingDepth, 1.15) * (Config.AIAnchorZMax - Config.AIAnchorZMin)
	return {
		Name = tostring(slotInfo.Label or slotInfo.Expected or "CM"),
		Role = tostring(slotInfo.Role or slotInfo.Expected or "CM"),
		X = x,
		Z = z,
		Lane = slotInfo.Lane,
	}
end

function Config.BuildSpawn(name: string?, width: number, length: number): {Vector2}
	local points = {}
	for index, slotInfo in ipairs(Config.IterSlots(name)) do
		local anchor = Config.ToSpawnAnchor(slotInfo)
		points[index] = Vector2.new(anchor.X * width * 0.46, anchor.Z * length * 0.48)
	end
	return points
end

function Config.BuildAI(name: string?): {any}
	local points = {}
	for index, slotInfo in ipairs(Config.IterSlots(name)) do
		points[index] = Config.ToAIAnchor(slotInfo)
	end
	return points
end

return Config
