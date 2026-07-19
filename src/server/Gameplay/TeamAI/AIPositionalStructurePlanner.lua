--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)

local Planner = {}

local function slot(id: string, family: string, pitch: Vector3, priority: number, rest: boolean?, sprint: boolean?): any
	return {Id = id, RoleFamily = family, TargetPitch = PitchConfig.ClampInsidePitch(pitch), Priority = priority, RestDefense = rest == true, SprintAllowed = sprint == true}
end

function Planner.Build(context: any, side: string, style: any, intent: any, spatial: any): {any}
	local ball = context.BallTeam[side]
	local width = style and style:Ratio("AttackingWidth") or .5
	local support = 30 + (style and style:Ratio("SupportDistance") or .5) * 42
	local depth = style and style:Ratio("DefensiveDepth") or .5
	local wideL = 45 + (1 - width) * 45
	local wideR = PitchConfig.PITCH_WIDTH - wideL
	local z = ball.Z
	local intentName = tostring(intent and intent.Intent or "")
	local teamBrain = context.TeamBrain and context.TeamBrain[side]
	local identity = tostring(teamBrain and teamBrain.AttackingIdentity or "")
	local corridor = tostring(teamBrain and teamBrain.AttackCorridor or "")
	if context.OwnerSide == side then
		local firstLine = math.max(62, z - 58)
		local pivotZ = math.max(120, z + 34)
		local advanceZ = math.min(676, z + 92)
		if intentName == "CounterAttack" or intentName == "DirectRelease" then
			advanceZ = math.min(696, z + 145)
			pivotZ = math.max(110, z + 58)
		elseif intentName == "BuildOut" or intentName == "AttractPress" then
			advanceZ = math.min(520, z + 80)
			pivotZ = math.max(118, z + 28)
		end
		if identity == "DirectAssault" then
			advanceZ = math.min(700, z + 165)
			pivotZ = math.max(105, z + 68)
			support = math.max(support, 54)
		elseif identity == "PositionalControl" then
			advanceZ = math.min(560, z + 74)
			pivotZ = math.max(118, z + 24)
			support = math.min(support, 42)
		elseif identity == "CentralDomination" or corridor == "Central" then
			wideL = 78
			wideR = PitchConfig.PITCH_WIDTH - 78
			support = math.min(support, 38)
		elseif identity == "WideOverload" or corridor == "Wide" then
			wideL = 35
			wideR = PitchConfig.PITCH_WIDTH - 35
			advanceZ = math.min(688, z + 106)
		elseif identity == "FluidRotation" then
			support = math.clamp(support, 28, 52)
		end
		local bestWide = spatial and spatial:BestCell(side, z + 70, true)
		local farOutlet = bestWide and bestWide.Point or Vector3.new(ball.X < PitchConfig.HALF_WIDTH and wideR or wideL, 3, advanceZ)
		return {
			slot("goalkeeper-reset", "GK", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(22, z - 92)), 95, false, false),
			slot("left-first-line", "CB", Vector3.new(118, 3, firstLine), 90, true, false),
			slot("right-first-line", "CB", Vector3.new(306, 3, firstLine), 90, true, false),
			slot("pivot", "CDM", Vector3.new(PitchConfig.HALF_WIDTH, 3, pivotZ), 86, false, false),
			slot("immediate-support", "CM", Vector3.new(math.clamp(ball.X + (ball.X < PitchConfig.HALF_WIDTH and support or -support), 70, 354), 3, math.max(80, z + 22)), 84, false, false),
			slot("left-width", "Winger", Vector3.new(wideL, 3, advanceZ), 76, false, true),
			slot("right-width", "Winger", Vector3.new(wideR, 3, advanceZ), 76, false, true),
			slot("central-forward", "ST", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.min(690, advanceZ + 34)), 72, false, true),
			slot("far-side-switch", "Winger", farOutlet, 68, false, true),
			slot("rest-defense", "CB", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(78, z - 92)), 88, true, false),
		}
	end
	local line = 90 + depth * 220
	if intentName == "LowBlock" or intentName == "ProtectBox" then line = 76 + depth * 82 end
	if intentName == "HighPress" then line = 300 + depth * 170 end
	if teamBrain then
		line = math.clamp(72 + (tonumber(teamBrain.DefensiveLineHeight) or depth) * 270, 64, 470)
		if teamBrain.DefensiveIdentity == "BoxProtection" then line = math.min(line, 145) end
		if teamBrain.DefensiveIdentity == "CollectiveHunt" then line = math.max(line, 315) end
	end
	return {
		slot("primary-presser", "ST", Vector3.new(ball.X, 3, math.min(620, ball.Z + 18)), 95, false, true),
		slot("cover-presser", "CM", Vector3.new(math.clamp(ball.X + (ball.X < PitchConfig.HALF_WIDTH and 48 or -48), 70, 354), 3, math.min(610, ball.Z + 8)), 82, false, true),
		slot("central-lane-block", "CDM", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.clamp(ball.Z - 42, 95, 510)), 86, false, false),
		slot("left-back-line", "CB", Vector3.new(132, 3, line), 90, true, false),
		slot("right-back-line", "CB", Vector3.new(292, 3, line), 90, true, false),
		slot("left-wide-cover", "Fullback", Vector3.new(62, 3, line + 25), 76, true, false),
		slot("right-wide-cover", "Fullback", Vector3.new(362, 3, line + 25), 76, true, false),
		slot("box-protection", "CB", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(58, line - 22)), 88, true, false),
	}
end

return Planner
