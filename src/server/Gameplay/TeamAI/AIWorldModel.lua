--!strict

local AIContextBuilder = require(script.Parent.Parent.AIContextBuilder)
local PitchConfig = require(script.Parent.Parent.PitchConfig)

local World = {}

local function lineFor(list: {any}, roles: {[string]: boolean}): number
	local total = 0
	local count = 0
	for _, info in ipairs(list) do
		if info.Root and roles[info.Role] == true then
			total += info.Pitch.Z
			count += 1
		end
	end
	return count > 0 and total / count or 0
end

local function centroid(list: {any}): Vector3
	local total = Vector3.zero
	local count = 0
	for _, info in ipairs(list) do
		if info.Root then
			total += info.Pitch
			count += 1
		end
	end
	return count > 0 and total / count or Vector3.new(PitchConfig.HALF_WIDTH, 3, PitchConfig.HALF_LENGTH)
end

local function sideState(context: any, side: string): any
	local team = context.Teams[side]
	local list = team and team.List or {}
	local ball = context.BallTeam and context.BallTeam[side] or Vector3.new(PitchConfig.HALF_WIDTH, 3, PitchConfig.HALF_LENGTH)
	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge
	for _, info in ipairs(list) do
		if info.Root then
			minX = math.min(minX, info.Pitch.X)
			maxX = math.max(maxX, info.Pitch.X)
			minZ = math.min(minZ, info.Pitch.Z)
			maxZ = math.max(maxZ, info.Pitch.Z)
		end
	end
	return {
		Centroid = centroid(list),
		DefensiveLine = lineFor(list, {CB = true, Fullback = true}),
		MidfieldLine = lineFor(list, {CDM = true, CM = true, CAM = true}),
		ForwardLine = lineFor(list, {Winger = true, ST = true}),
		BlockWidth = minX < math.huge and maxX - minX or 0,
		BlockDepth = minZ < math.huge and maxZ - minZ or 0,
		BallSide = ball.X < PitchConfig.HALF_WIDTH - 42 and "Left" or ball.X > PitchConfig.HALF_WIDTH + 42 and "Right" or "Center",
		StrongSide = ball.X < PitchConfig.HALF_WIDTH and "Left" or "Right",
		WeakSide = ball.X < PitchConfig.HALF_WIDTH and "Right" or "Left",
	}
end

function World.Build(teams: any, formations: any, pitchCFrame: CFrame, width: number, length: number, ball: BasePart, possession: any, attackSigns: {[string]: number}, previous: any?): any
	local context = AIContextBuilder.Build(teams, formations, pitchCFrame, width, length, ball, possession, attackSigns)
	context.WorldModelVersion = 1
	context.StaticCache = previous and previous.StaticCache or {}
	context.DerivedTeams = {
		Home = sideState(context, "Home"),
		Away = sideState(context, "Away"),
	}
	context.MatchState = context.OwnerSide == "Home" and "HomePossession" or context.OwnerSide == "Away" and "AwayPossession" or context.LooseBall and "LooseBall" or "Neutral"
	context.BallState = {
		Position = context.BallWorld,
		Velocity = context.BallVelocity,
		Owner = context.Owner,
		OwnerSide = context.OwnerSide,
		Loose = context.LooseBall,
		PassInFlight = context.PassInFlight,
		Target = ball and ball:GetAttribute("VTRPassTarget") or nil,
		Receiver = ball and ball:GetAttribute("VTRPassReceiver") or nil,
	}
	return context
end

return World
