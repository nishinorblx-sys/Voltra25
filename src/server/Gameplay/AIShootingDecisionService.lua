--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local PenaltyBoxService = require(script.Parent.PenaltyBoxService)

local Service = {}

local laneOpenTo: (any, any, number) -> boolean

local function goalTarget(context: any, shooter: any): Vector3
	local attackSign = context.AttackSigns and context.AttackSigns[shooter.Side] or PitchConfig.GetAttackDirection(shooter.Side, context.Options)
	local rectangle = GoalModelResolver.ResolveByAttackSign(attackSign, context.PitchCFrame, context.Width, context.Length)	local goalPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, PitchConfig.PITCH_LENGTH)
	local center = PitchConfig.TeamPitchPositionToWorld(goalPitch, shooter.Side, context.Options)
	local distance = PitchConfig.GetDistanceStuds(shooter.World, center)
	local pressure = AIContextBuilder.Pressure(context, shooter)
	local leftOpen = laneOpenTo(context, shooter, 180)
	local rightOpen = laneOpenTo(context, shooter, 244)
	local width = math.max(1, rectangle.RightBound - rectangle.Left)
	local height = math.max(1, rectangle.Top - rectangle.Bottom)
	local closeAlpha = math.clamp((150 - distance) / 120, 0, 1)
	local cornerInset = math.clamp(width * (0.1 + pressure.Score * 0.04), 0.25, width * 0.18)
	local leftX = rectangle.Left + cornerInset
	local rightX = rectangle.RightBound - cornerInset
	local sideBias = shooter.Pitch.X < PitchConfig.HALF_WIDTH and rightX or leftX
	if leftOpen ~= rightOpen then
		sideBias = leftOpen and leftX or rightX
	end
	local top = math.clamp(rectangle.Top - height * math.clamp(0.12 + pressure.Score * 0.08, 0.12, 0.26), rectangle.Bottom, rectangle.Top)
	local low = math.clamp(rectangle.Bottom + height * 0.24, rectangle.Bottom, rectangle.Top)
	local vertical = closeAlpha > 0.68 and low or top
	return GoalModelResolver.Point(rectangle, sideBias, vertical)
end

laneOpenTo = function(context: any, shooter: any, targetPitchX: number): boolean
	local target = PitchConfig.TeamPitchPositionToWorld(Vector3.new(targetPitchX, 3, PitchConfig.PITCH_LENGTH), shooter.Side, context.Options)
	for _, defender in ipairs(context.Teams[shooter.OpponentSide].List) do
		if defender.Root then
			local distance, t = AIContextBuilder.DistancePointToSegment(defender.World, shooter.World, target)
			if t > 0.05 and t < 0.98 and distance < 6 then
				return false
			end
		end
	end
	return true
end

function Service.Evaluate(context: any, shooter: any, style: any, difficulty: any): any
	local goal = goalTarget(context, shooter)
	local distance = PitchConfig.GetDistanceStuds(shooter.World, goal)
	local pressure = AIContextBuilder.Pressure(context, shooter)
	local leftOpen = laneOpenTo(context, shooter, 180)
	local rightOpen = laneOpenTo(context, shooter, 244)
	local clearAngle = leftOpen or rightOpen
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, shooter.Side)
	local oneVOne = shooter.Pitch.Z > defensiveLine and pressure.Closest > 20 and distance < 160
	local wideAngle = (shooter.Pitch.X < 80 or shooter.Pitch.X > 344) and shooter.Pitch.Z > 580
	local insideBox = PitchConfig.InZone(shooter.Pitch, "OpponentBox")
	local insideWorkspaceBox = PenaltyBoxService.IsInsideAttackingBox(shooter.Side, shooter.World, context.Options)
	local inDangerBox = insideBox or insideWorkspaceBox
	local central = PitchConfig.InZone(shooter.Pitch, "CentralShootingZone")
	local edge = PitchConfig.InZone(shooter.Pitch, "EdgeOfBoxZone")
	local closeChance = inDangerBox and distance < 78
	local longShotAllowed = style:Ratio("LongShotFrequency") > 0.55 and shooter.Stats.longShots >= 72
	local good = closeChance or (inDangerBox and distance < 115 and clearAngle and not pressure.Heavy) or (central and distance < 150 and shooter.Stats.shooting >= 75 and clearAngle) or oneVOne
	if shooter.Role == "ST" and (inDangerBox or central) then
		good = true
	end
	if inDangerBox and pressure.Closest > 12 and clearAngle then
		good = true
	end
	if edge and longShotAllowed and clearAngle and not pressure.Heavy then
		good = true
	end
	local bad = distance > 210 or (wideAngle and not inDangerBox) or (pressure.Heavy and not closeChance) or (not inDangerBox and shooter.Stats.shooting < 55)
	local score = 0
	score += inDangerBox and 46 or central and 28 or edge and 12 or -10
	score += closeChance and 30 or distance < 105 and 14 or 0
	score += clearAngle and 26 or -24
	score += oneVOne and 32 or 0
	score += (shooter.Stats.shooting - 60) * 0.45
	score -= pressure.Score * (closeChance and 14 or 34)
	score -= wideAngle and 22 or 0
	score -= math.max(0, distance - 120) * 0.12
	score += math.max(0, 90 - distance) * 0.22
	score += difficulty.ShotSelect * 12
	if shooter.Role == "ST" then
		score += (inDangerBox or central) and 58 or 18
	end
	return {
		Good = good and not bad,
		Bad = bad,
		Score = score,
		Target = goal,
		Distance = distance,
		ClearAngle = clearAngle,
		Pressure = pressure,
	}
end

return Service
