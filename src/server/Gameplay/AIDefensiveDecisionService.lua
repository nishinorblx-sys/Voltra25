--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}

function Service.ShouldCenterBackStep(info: any, ballPitch: Vector3): boolean
	return info.Role == "CB" and ballPitch.Z < 315 and ballPitch.X > 90 and ballPitch.X < 334
end

function Service.LineHeight(ballPitch: Vector3, defensiveDepthRatio: number): number
	if ballPitch.Z > 520 then
		return 270 + defensiveDepthRatio * 60
	elseif ballPitch.Z > 330 then
		return 190 + defensiveDepthRatio * 70
	elseif ballPitch.Z > 160 then
		return 120 + defensiveDepthRatio * 65
	end
	return 80 + defensiveDepthRatio * 50
end

function Service.BlockLaneTarget(carrierPitch: Vector3, receiverPitch: Vector3): Vector3
	local midpoint = carrierPitch:Lerp(receiverPitch, 0.65)
	return PitchConfig.ClampInsidePitch(Vector3.new(midpoint.X, 3, midpoint.Z))
end

function Service.CoverPresserTarget(carrierPitch: Vector3): Vector3
	return PitchConfig.ClampInsidePitch(Vector3.new(carrierPitch.X + (PitchConfig.HALF_WIDTH - carrierPitch.X) * 0.25, 3, math.max(35, carrierPitch.Z - 20)))
end

function Service.ContainTarget(carrierPitch: Vector3): Vector3
	local ownGoal = Vector3.new(PitchConfig.HALF_WIDTH, 3, 0)
	local goalSide = carrierPitch - ownGoal
	return PitchConfig.ClampInsidePitch(carrierPitch - (goalSide.Magnitude > 1 and goalSide.Unit or Vector3.zAxis) * 3.5)
end

return Service
