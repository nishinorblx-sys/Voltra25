--!strict
local Config = {
	MinPassDistance = 0,
	MaxPassDistance = 240,
	ChargeBonus = 18,
	AbsoluteMaxSpeed = 136,
	AssistRadius = {Short = 18, Medium = 28, Long = 42},
}

function Config.SpeedForDistance(distance: number, charge: number): number
	distance = math.clamp(distance, 0, Config.MaxPassDistance)
	local distanceSpeed = 38 + math.sqrt(distance) * 5.55
	local chargeBonus = math.clamp(charge, 0, 1) * (8 + distance * 0.045)
	return math.clamp(distanceSpeed + chargeBonus, 40, Config.AbsoluteMaxSpeed)
end

function Config.ArrivalSpeedRatio(charge:number):number
	return 0.25 + math.clamp(charge,0,1) * 0.5
end

function Config.LiftForDistance(distance:number,charge:number,through:boolean?):number
	local distanceLift=math.clamp((distance-14)/190,0,1)*0.09
	local chargeLift=math.clamp(charge,0,1)*0.018
	return math.clamp(0.032+distanceLift+chargeLift+(through and 0.028 or 0),0.032,0.158)
end

return table.freeze(Config)
