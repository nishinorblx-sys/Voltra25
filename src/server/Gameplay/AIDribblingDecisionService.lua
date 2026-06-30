--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)

local Service = {}

local function openAt(context: any, info: any, pitchTarget: Vector3, radius: number): boolean
	return AIContextBuilder.SpaceAt(context, info.Side, PitchConfig.ClampInsidePitch(pitchTarget), radius)
end

function Service.Evaluate(context: any, carrier: any, style: any): any
	local freedom = style:Ratio("DribblingFreedom")
	local pressure = AIContextBuilder.Pressure(context, carrier)
	local forwardTarget = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X, 3, carrier.Pitch.Z + 30))
	local centralOpen = openAt(context, carrier, forwardTarget, 16)
	local touchline = carrier.Pitch.X < PitchConfig.HALF_WIDTH and 0 or PitchConfig.PITCH_WIDTH
	local wideDirection = touchline - carrier.Pitch.X >= 0 and 1 or -1
	local wideX = carrier.Pitch.X + wideDirection * 18
	local wideTarget = PitchConfig.ClampInsidePitch(Vector3.new(wideX, 3, carrier.Pitch.Z + 25))
	local wideOpen = openAt(context, carrier, wideTarget, 14)
	local chosenPitch = centralOpen and forwardTarget or wideOpen and wideTarget or nil
	local canDribble = chosenPitch ~= nil and carrier.Stats.dribbling >= 55 and (freedom > 0.35 or pressure.None)
	local score = (centralOpen and 28 or 0) + (wideOpen and 14 or 0) + (carrier.Stats.dribbling - 60) * 0.35 + freedom * 20 - pressure.Score * 22
	return {
		CanDribble = canDribble,
		Score = score,
		Target = chosenPitch and PitchConfig.TeamPitchPositionToWorld(chosenPitch, carrier.Side, context.Options) or carrier.World,
		Pressure = pressure,
	}
end

return Service
