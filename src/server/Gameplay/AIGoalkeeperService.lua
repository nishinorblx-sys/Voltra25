--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)

local Service = {}

function Service.PositionTarget(context: any, keeper: any): Vector3
	local ballPitch = context.BallTeam[keeper.Side]
	local owner = context.Owner
	local ownPossession = owner ~= nil and owner:GetAttribute("VTRTeam") == keeper.Side
	local halfLength = PitchConfig.PITCH_LENGTH * 0.5
	local frontEdge = PitchConfig.Zones.OwnBox.ZMax - 8
	local lineDepth = 14
	local z = lineDepth
	if ownPossession and ballPitch.Z > halfLength then
		local advance = math.clamp((ballPitch.Z - halfLength) / halfLength, 0, 1)
		z = lineDepth + (frontEdge - lineDepth) * advance
	end
	local ballToCenter = ballPitch.X - PitchConfig.HALF_WIDTH
	local coverScale = ownPossession and 0.34 or 0.72
	local x = PitchConfig.HALF_WIDTH + ballToCenter * coverScale
	local targetPitch = Vector3.new(math.clamp(x, 146, 278), 3, math.clamp(z, lineDepth, frontEdge))
	return PitchConfig.TeamPitchPositionToWorld(targetPitch, keeper.Side, context.Options)
end

function Service.ShouldRush(context: any, keeper: any): boolean
	if not keeper.Root then
		return false
	end
	local ballPitch = context.BallTeam[keeper.Side]
	if not PitchConfig.InZone(ballPitch, "OwnBox") or (context.BallVelocity.Magnitude < 8 and context.Owner ~= nil) then
		return false
	end
	local keeperDistance = PitchConfig.GetDistanceStuds(keeper.World, context.BallWorld)
	local nearestAttackerDistance = math.huge
	for _, attacker in ipairs(context.Teams[keeper.OpponentSide].List) do
		if attacker.Root then
			nearestAttackerDistance = math.min(nearestAttackerDistance, PitchConfig.GetDistanceStuds(attacker.World, context.BallWorld))
		end
	end
	return keeperDistance < nearestAttackerDistance - 8 or (keeper.Stats.overall or 60) > 78 and keeperDistance < nearestAttackerDistance - 3
end

function Service.ChooseDistribution(context: any, keeper: any): any?
	local best = nil
	local bestScore = -math.huge
	for _, teammate in ipairs(context.Teams[keeper.Side].List) do
		if teammate.Model ~= keeper.Model and teammate.Root then
			local distance = PitchConfig.GetDistanceStuds(keeper.World, teammate.World)
			local open = select(1, AIContextBuilder.IsOpen(context, teammate))
			local targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(teammate.Pitch.X, 3, teammate.Pitch.Z + math.clamp(distance / 18, 2, 8)))
			local targetWorld = PitchConfig.TeamPitchPositionToWorld(targetPitch, keeper.Side, context.Options)
			local laneClear = AIContextBuilder.PassingLaneClear(context, keeper, targetWorld, "Ground")
			local score = (open and 24 or -8) + (laneClear and 18 or -18) - math.abs(distance - 42) * 0.2 + teammate.Pitch.Z * 0.04
			if laneClear and distance < 125 and score > bestScore then
				best = {Receiver = teammate, Target = targetWorld, Distance = distance, PassKind = "Ground", Score = score}
				bestScore = score
			end
		end
	end
	return best
end

return Service
