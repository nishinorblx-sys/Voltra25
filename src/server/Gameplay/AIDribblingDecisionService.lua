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
	local wideWinger = carrier.Role == "Winger" and (carrier.Pitch.X < 100 or carrier.Pitch.X > 324)
	local forwardStep = wideWinger and carrier.Pitch.Z >= 610 and 13 or 30
	if pressure.None and not wideWinger then
		forwardStep = 42
	elseif pressure.None and wideWinger and carrier.Pitch.Z < 610 then
		forwardStep = 36
	end
	if wideWinger and carrier.Pitch.Z >= 675 then
		forwardStep = -18
	end
	local forwardTarget = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X, 3, carrier.Pitch.Z + forwardStep))
	local centralOpen = openAt(context, carrier, forwardTarget, pressure.None and 20 or 16)
	local touchline = carrier.Pitch.X < PitchConfig.HALF_WIDTH and 0 or PitchConfig.PITCH_WIDTH
	local wideDirection = touchline - carrier.Pitch.X >= 0 and 1 or -1
	local wideX = carrier.Pitch.X + wideDirection * 18
	local insideDirection = carrier.Pitch.X < PitchConfig.HALF_WIDTH and 1 or -1
	local insideTarget = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X + insideDirection * 34, 3, math.max(carrier.Pitch.Z - 8, math.min(carrier.Pitch.Z + 12, 642))))
	local insideOpen = wideWinger and openAt(context, carrier, insideTarget, 16)
	local wideTarget = PitchConfig.ClampInsidePitch(Vector3.new(wideX, 3, carrier.Pitch.Z + (wideWinger and carrier.Pitch.Z >= 610 and 8 or 25)))
	local wideOpen = openAt(context, carrier, wideTarget, 14)
	local chosenPitch = centralOpen and forwardTarget or insideOpen and insideTarget or wideOpen and wideTarget or nil
	if wideWinger and carrier.Pitch.Z >= 675 then
		chosenPitch = insideOpen and insideTarget or PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X + insideDirection * 26, 3, carrier.Pitch.Z - 22))
	end
	local canDribble = chosenPitch ~= nil and (carrier.Stats.dribbling >= 55 or pressure.None and carrier.Stats.dribbling >= 45) and (freedom > 0.35 or pressure.None)
	local score = (centralOpen and 28 or 0) + (insideOpen and 20 or 0) + (wideOpen and 14 or 0) + (carrier.Stats.dribbling - 60) * 0.35 + freedom * 20 - pressure.Score * 22
	if pressure.None and centralOpen then
		score += 22
	end
	if wideWinger and carrier.Pitch.Z >= 610 then
		score -= 10
	end
	if wideWinger and carrier.Pitch.Z >= 675 then
		score -= 35
	end
	return {
		CanDribble = canDribble,
		Score = score,
		Target = chosenPitch and PitchConfig.TeamPitchPositionToWorld(chosenPitch, carrier.Side, context.Options) or carrier.World,
		Pressure = pressure,
	}
end

return Service
