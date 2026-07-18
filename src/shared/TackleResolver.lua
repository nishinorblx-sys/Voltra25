--!strict

local GameplayConfig = require(script.Parent.GameplayConfig)

local Resolver = {}

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

local function segmentDistance(a: Vector3, b: Vector3, point: Vector3): number
	local segment = flat(b - a)
	if segment.Magnitude < 0.001 then return flat(point - a).Magnitude end
	local alpha = math.clamp(flat(point - a):Dot(segment) / segment:Dot(segment), 0, 1)
	return flat(point - (a + segment * alpha)).Magnitude
end

local function synchronizedSweepDistance(a0:Vector3,a1:Vector3,b0:Vector3,b1:Vector3):number
	-- Both segments cover the same contact window. Measuring their relative
	-- motion catches crossings that endpoint-only hitboxes miss under latency.
	return segmentDistance(flat(a0-b0),flat(a1-b1),Vector3.zero)
end

function Resolver.Resolve(input: any): any
	local slide = input.Slide == true
	local reach = slide and GameplayConfig.Ball.SlideTackleRange or GameplayConfig.Ball.StandingTackleRange
	local start = typeof(input.StartPosition) == "Vector3" and input.StartPosition or Vector3.zero
	local finish = typeof(input.EndPosition) == "Vector3" and input.EndPosition or start
	local ballPosition = typeof(input.BallPosition) == "Vector3" and input.BallPosition or finish
	local ownerPosition = typeof(input.OwnerPosition) == "Vector3" and input.OwnerPosition or ballPosition
	local facing = typeof(input.Facing) == "Vector3" and flat(input.Facing) or Vector3.zAxis
	local toBall = flat(ballPosition - finish)
	local facingDot = facing.Magnitude > 0.01 and toBall.Magnitude > 0.01 and facing.Unit:Dot(toBall.Unit) or 1
	local ballStart=typeof(input.BallStartPosition)=="Vector3"and input.BallStartPosition or ballPosition
	local ownerStart=typeof(input.OwnerStartPosition)=="Vector3"and input.OwnerStartPosition or ownerPosition
	local extendedFinish=finish+(slide and(facing.Magnitude>.01 and facing.Unit or Vector3.zAxis)*2.2 or Vector3.zero)
	local ballContactDistance=synchronizedSweepDistance(start,extendedFinish,ballStart,ballPosition)
	local bodyDistance=synchronizedSweepDistance(start,finish,ownerStart,ownerPosition)
	local ownerFacing = typeof(input.OwnerFacing) == "Vector3" and flat(input.OwnerFacing) or Vector3.zAxis
	local toTackler = flat(finish - ownerPosition)
	local approachDot = ownerFacing.Magnitude > 0.01 and toTackler.Magnitude > 0.01 and ownerFacing.Unit:Dot(toTackler.Unit) or 0
	local approach = approachDot < -0.35 and "Behind" or approachDot > 0.35 and "Front" or "Side"
	if ballContactDistance > reach or facingDot < (slide and -0.2 or 0.05) then
		return {Outcome = "TackleMiss", Quality = 0, Approach = approach, BallDistance = ballContactDistance, GeometryBand = "Outside"}
	end
	local tackle = math.clamp((tonumber(input.Tackle) or 55) / 100, 0.1, 0.99)
	local dribbling = math.clamp((tonumber(input.Dribbling) or 55) / 100, 0.1, 0.99)
	local strength = math.clamp((tonumber(input.Strength) or 60) / 100, 0.1, 0.99)
	local balance = math.clamp((tonumber(input.OwnerBalance) or 60) / 100, 0.1, 0.99)
	local stamina = math.clamp((tonumber(input.Stamina) or 100) / 100, 0, 1)
	local exposure = math.clamp(tonumber(input.Exposure) or 0.45, 0, 1)
	local timing = math.clamp(1 - ballContactDistance / reach, 0, 1)
	local quality = timing * 0.34 + math.max(0, facingDot) * 0.17 + tackle * 0.23 + strength * 0.1 + stamina * 0.08 + exposure * 0.18 - dribbling * 0.13 - balance * 0.08
	if input.ActiveSkill == true then quality -= 0.25 end
	if input.PostSkillExposure == true then quality += 0.24 end
	local bodyFirst = bodyDistance + 0.28 < ballContactDistance
	local foul = bodyFirst and (approach ~= "Front" or slide) or approach == "Behind" and ballContactDistance > reach * 0.45
	if foul then return {Outcome = "TackleFoul", Quality = quality, Approach = approach, BallDistance = ballContactDistance, GeometryBand = "BodyFirst"} end
	if quality >= 0.64 then return {Outcome = "TackleWonPossession", Quality = quality, Approach = approach, BallDistance = ballContactDistance, GeometryBand = "Clean"} end
	if quality >= 0.43 then return {Outcome = "TackleWonLooseBall", Quality = quality, Approach = approach, BallDistance = ballContactDistance, GeometryBand = "Glancing"} end
	return {Outcome = "TackleBlocked", Quality = quality, Approach = approach, BallDistance = ballContactDistance, GeometryBand = "Marginal"}
end

return table.freeze(Resolver)
