--!strict

local ShotPowerModel = {}

ShotPowerModel.AccurateMax = 90
ShotPowerModel.OverhitStart = 90
ShotPowerModel.MaxPercent = 100

local function normalized(value: any): number
	local amount = tonumber(value) or 0
	if amount > 1.25 then amount /= 100 end
	return math.clamp(amount, 0, 1)
end

local function smoothstep(value: number): number
	local amount = math.clamp(value, 0, 1)
	return amount * amount * (3 - 2 * amount)
end

function ShotPowerModel.ToPercent(power: any): number
	return normalized(power) * 100
end

function ShotPowerModel.ScaleInputPower(power: any): number
	return normalized(power)
end

function ShotPowerModel.SpeedScale(power: any): number
	local amount = normalized(power)
	return 0.18 + 0.82 * (amount * 0.35 + smoothstep(amount) * 0.65)
end

function ShotPowerModel.OverhitAmount(power: any): number
	return smoothstep(math.clamp((normalized(power) - 0.9) / 0.1, 0, 1))
end

function ShotPowerModel.IsOverhit(power: any): boolean
	return normalized(power) > 0.9
end

function ShotPowerModel.HighLift(power: any): number
	return ShotPowerModel.OverhitAmount(power) * 2.4
end

function ShotPowerModel.PlacementMultiplier(power: any): number
	return 1 - ShotPowerModel.OverhitAmount(power) * 0.24
end

function ShotPowerModel.ComposureMultiplier(power: any): number
	return 1 - ShotPowerModel.OverhitAmount(power) * 0.18
end

function ShotPowerModel.ApplyToVelocity(velocity: any, power: any): any
	if typeof(velocity) ~= "Vector3" then return velocity end
	local lift = ShotPowerModel.HighLift(power)
	return Vector3.new(velocity.X, velocity.Y + lift, velocity.Z)
end

function ShotPowerModel.ApplyToTarget(_origin: any, target: any, power: any): any
	if typeof(target) ~= "Vector3" then return target end
	return target + Vector3.yAxis * ShotPowerModel.HighLift(power) * 0.16
end

function ShotPowerModel.ApplyToArcHeight(arcHeight: any, power: any): number
	return (tonumber(arcHeight) or 0) + ShotPowerModel.HighLift(power) * 0.3
end

return table.freeze(ShotPowerModel)
