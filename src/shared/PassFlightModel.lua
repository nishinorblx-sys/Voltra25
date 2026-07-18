--!strict
local Model = {}

function Model.Duration(flight: any, distance: number, charge: number, passType: string?): number
	local alpha = math.clamp(distance / math.max(tonumber(flight.PassTravelDistanceForMax) or 160, 1), 0, 1)
	local amount = math.clamp(charge, 0, 1)
	local driven = passType == "Through" or passType == "Manual"
	local minimum = driven and (tonumber(flight.ThroughPassTravelTimeMin) or 0.56) or (tonumber(flight.GroundPassTravelTimeMin) or 0.42)
	local maximum = driven and (tonumber(flight.ThroughPassTravelTimeMax) or 2.05) or (tonumber(flight.GroundPassTravelTimeMax) or 1.72)
	local duration = minimum + (maximum - minimum) * (alpha ^ 0.72)
	return math.clamp(duration * (1 - amount * 0.18), minimum * 0.84, maximum)
end

return table.freeze(Model)
