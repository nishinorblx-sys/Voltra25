local ShotPowerModel = {}

ShotPowerModel.AccurateMax = 89
ShotPowerModel.OverhitStart = 90
ShotPowerModel.MaxPercent = 100

local function numberValue(value)
	local n = tonumber(value)
	if not n then
		return nil
	end
	return n
end

function ShotPowerModel.ToPercent(power)
	local n = numberValue(power)
	if not n then
		return 0
	end

	if n <= 1.25 then
		return math.clamp(n * 100, 0, 100)
	end

	return math.clamp(n, 0, 100)
end

function ShotPowerModel.ScaleInputPower(power)
	local n = numberValue(power)
	if not n then
		return power
	end

	local percent = ShotPowerModel.ToPercent(n)
	local scaled = math.clamp(percent / ShotPowerModel.AccurateMax, 0, 1)

	if n <= 1.25 then
		return scaled
	end

	return scaled * 100
end

function ShotPowerModel.IsOverhit(power)
	return ShotPowerModel.ToPercent(power) > ShotPowerModel.OverhitStart
end

function ShotPowerModel.OverhitAmount(power)
	local percent = ShotPowerModel.ToPercent(power)

	if percent <= ShotPowerModel.OverhitStart then
		return 0
	end

	return math.clamp((percent - ShotPowerModel.OverhitStart) / (ShotPowerModel.MaxPercent - ShotPowerModel.OverhitStart), 0, 1)
end

function ShotPowerModel.HighLift(power)
	local amount = ShotPowerModel.OverhitAmount(power)

	if amount <= 0 then
		return 0
	end

	return 55 + amount * amount * 145
end

function ShotPowerModel.ApplyToVelocity(velocity, power)
	if typeof(velocity) ~= "Vector3" then
		return velocity
	end

	local lift = ShotPowerModel.HighLift(power)

	if lift <= 0 then
		return velocity
	end

	return Vector3.new(velocity.X, math.max(velocity.Y, 0) + lift, velocity.Z)
end

function ShotPowerModel.ApplyToTarget(origin, target, power)
	if typeof(target) ~= "Vector3" then
		return target
	end

	local lift = ShotPowerModel.HighLift(power)

	if lift <= 0 then
		return target
	end

	return target + Vector3.new(0, lift * 0.7, 0)
end

function ShotPowerModel.ApplyToArcHeight(arcHeight, power)
	local lift = ShotPowerModel.HighLift(power)

	if lift <= 0 then
		return arcHeight
	end

	return (tonumber(arcHeight) or 0) + lift * 0.55
end

return ShotPowerModel
