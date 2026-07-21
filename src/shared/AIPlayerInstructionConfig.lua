--!strict
local Config = {}

Config.Version = 2
Config.DefaultOffBall = "SupportBall"
Config.DefaultDefending = "Balanced"
Config.OffBallOrder = {"HoldPosition", "SupportBall", "AttackSpace"}
Config.DefendingOrder = {"HoldShape", "Balanced", "HuntBall"}
Config.OffBall = table.freeze({
	HoldPosition = table.freeze({Id = "HoldPosition", Name = "HOLD POSITION", Short = "HOLD", Description = "Stay in the assigned lane and avoid optional runs."}),
	SupportBall = table.freeze({Id = "SupportBall", Name = "SUPPORT BALL", Short = "SUPPORT", Description = "Move toward the ball and create a safe passing angle."}),
	AttackSpace = table.freeze({Id = "AttackSpace", Name = "ATTACK SPACE", Short = "ATTACK", Description = "Run beyond defenders and enter dangerous space."}),
})
Config.Defending = table.freeze({
	HoldShape = table.freeze({Id = "HoldShape", Name = "HOLD SHAPE", Short = "HOLD", Description = "Protect the assigned zone and block passing lanes."}),
	Balanced = table.freeze({Id = "Balanced", Name = "BALANCED", Short = "BALANCED", Description = "Press when nearest; otherwise recover into team shape."}),
	HuntBall = table.freeze({Id = "HuntBall", Name = "HUNT BALL", Short = "PRESS", Description = "Close early, press aggressively, and chase the next receiver."}),
})

local roleDefaults = {
	GK = {"HoldPosition", "HoldShape"},
	CB = {"HoldPosition", "HoldShape"},
	LB = {"SupportBall", "Balanced"},
	RB = {"SupportBall", "Balanced"},
	LWB = {"SupportBall", "Balanced"},
	RWB = {"SupportBall", "Balanced"},
	CDM = {"HoldPosition", "Balanced"},
	CM = {"SupportBall", "Balanced"},
	CAM = {"SupportBall", "Balanced"},
	LM = {"AttackSpace", "Balanced"},
	RM = {"AttackSpace", "Balanced"},
	LW = {"AttackSpace", "Balanced"},
	RW = {"AttackSpace", "Balanced"},
	ST = {"AttackSpace", "Balanced"},
}

local legacyMap = {
	ComeShort = {"SupportBall", "Balanced"},
	GetInBehind = {"AttackSpace", "Balanced"},
	StayWide = {"HoldPosition", "Balanced"},
	FreeRoam = {"SupportBall", "Balanced"},
	StayBack = {"HoldPosition", "HoldShape"},
	AggressivePress = {nil, "HuntBall"},
	RecoveryRunner = {"HoldPosition", "Balanced"},
}

function Config.IsOffBall(value: any): boolean
	return type(value) == "string" and Config.OffBall[value] ~= nil
end

function Config.IsDefending(value: any): boolean
	return type(value) == "string" and Config.Defending[value] ~= nil
end

function Config.RoleDefaults(role: any): any
	local defaults = roleDefaults[tostring(role or "")] or {Config.DefaultOffBall, Config.DefaultDefending}
	return {OffBall = defaults[1], Defending = defaults[2]}
end

function Config.Normalize(value: any, role: any): any
	local defaults = Config.RoleDefaults(role)
	if type(value) ~= "table" then return defaults end
	local offBall = Config.IsOffBall(value.OffBall) and value.OffBall or defaults.OffBall
	local defending = Config.IsDefending(value.Defending) and value.Defending or defaults.Defending
	return {OffBall = offBall, Defending = defending}
end

function Config.FromLegacyProfile(profileId: any, role: any): any
	local defaults = Config.RoleDefaults(role)
	local mapped = legacyMap[tostring(profileId or "")]
	if not mapped then return defaults end
	return {OffBall = mapped[1] or defaults.OffBall, Defending = mapped[2] or defaults.Defending}
end

function Config.Summary(value: any, role: any): string
	local normalized = Config.Normalize(value, role)
	local off = Config.OffBall[normalized.OffBall]
	local def = Config.Defending[normalized.Defending]
	return tostring(off and off.Short or "SUPPORT") .. " / " .. tostring(def and def.Short or "BALANCED")
end

return table.freeze(Config)
