--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)

local Map = {}
Map.__index = Map

local GRID_X = 13
local GRID_Z = 21

local function arrival(info: any, point: Vector3): number
	if not info or not info.Root then return math.huge end
	local velocity = Vector3.new(info.Root.AssemblyLinearVelocity.X, 0, info.Root.AssemblyLinearVelocity.Z)
	local origin = info.CanonicalPitch or info.Pitch
	local distance = PitchConfig.GetDistanceStuds(origin, point)
	local pace = info.Stats and tonumber(info.Stats.pace) or 60
	local stamina = math.clamp(tonumber(info.Stamina) or tonumber(info.Model:GetAttribute("VTRSprintEnergy")) or 70, 0, 100)
	local speed = 15 + math.clamp((pace - 45) / 55, 0, 1) * 14 + stamina * 0.025
	local toPoint = point - origin
	local turnPenalty = velocity.Magnitude > 1 and toPoint.Magnitude > .01 and math.clamp(1 - velocity.Unit:Dot(toPoint.Unit), 0, 2) * 0.12 or 0
	return distance / math.max(8, speed) + turnPenalty
end

local function nearest(list: {any}, point: Vector3): (number, number)
	local best = math.huge
	local second = math.huge
	for _, info in ipairs(list) do
		if info.Root then
			local t = arrival(info, point)
			if t < best then
				second = best
				best = t
			elseif t < second then
				second = t
			end
		end
	end
	return best, second
end

function Map.new(): any
	local points = {}
	for z = 1, GRID_Z do
		for x = 1, GRID_X do
			table.insert(points, Vector3.new((x - .5) / GRID_X * PitchConfig.PITCH_WIDTH, 3, (z - .5) / GRID_Z * PitchConfig.PITCH_LENGTH))
		end
	end
	return setmetatable({Points = points, Cells = {}, LastFullUpdate = 0, Resolution = {X = GRID_X, Z = GRID_Z}, UpdateRate = 5}, Map)
end

function Map:Update(context: any): any
	local cells = {}
	self.ContextOptions = context.Options
	for index, point in ipairs(self.Points) do
		local home, homeSecond = nearest(context.Teams.Home.List, point)
		local away, awaySecond = nearest(context.Teams.Away.List, point)
		local ballDistance = PitchConfig.GetDistanceStuds(point, context.BallCanonical or context.BallTeam.Home)
		local homePoint = PitchConfig.CanonicalPitchToTeamPitchPosition(point, "Home", context.Options)
		local awayPoint = PitchConfig.CanonicalPitchToTeamPitchPosition(point, "Away", context.Options)
		cells[index] = {
			Point = point,
			CanonicalPoint = point,
			HomeArrival = home,
			AwayArrival = away,
			HomeSecond = homeSecond,
			AwaySecond = awaySecond,
			HomeAdvantage = away - home,
			AwayAdvantage = home - away,
			BallDistance = ballDistance,
			HomeLineBreakValue = math.clamp((homePoint.Z - PitchConfig.HALF_LENGTH) / PitchConfig.HALF_LENGTH, -1, 1),
			AwayLineBreakValue = math.clamp((awayPoint.Z - PitchConfig.HALF_LENGTH) / PitchConfig.HALF_LENGTH, -1, 1),
			LineBreakValue = math.clamp((point.Z - PitchConfig.HALF_LENGTH) / PitchConfig.HALF_LENGTH, -1, 1),
			TouchlinePenalty = point.X < 28 or point.X > PitchConfig.PITCH_WIDTH - 28,
		}
	end
	self.Cells = cells
	self.LastFullUpdate = context.Now or os.clock()
	return self
end

function Map:BestCell(side: string, minimumZ: number?, wide: boolean?): any?
	local best = nil
	local bestScore = -math.huge
	for _, cell in ipairs(self.Cells) do
		local canonicalPoint = cell.CanonicalPoint or cell.Point
		local point = PitchConfig.CanonicalPitchToTeamPitchPosition(canonicalPoint, side, self.ContextOptions)
		if not minimumZ or point.Z >= minimumZ then
			local wideOk = not wide or point.X < 100 or point.X > PitchConfig.PITCH_WIDTH - 100
			if wideOk then
				local advantage = side == "Home" and cell.HomeAdvantage or cell.AwayAdvantage
				local lineBreak = side == "Home" and cell.HomeLineBreakValue or cell.AwayLineBreakValue
				local score = advantage * 20 + lineBreak * 25 - (cell.TouchlinePenalty and 8 or 0)
				if score > bestScore then
					best = table.clone(cell)
					best.Point = point
					best.TacticalPoint = point
					best.CanonicalPoint = canonicalPoint
					bestScore = score
				end
			end
		end
	end
	return best
end

return Map
