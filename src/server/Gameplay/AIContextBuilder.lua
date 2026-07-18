--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIFormationService = require(script.Parent.AIFormationService)
local AttributeAIService = require(script.Parent.AttributeAIService)

local Service = {}

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function Service.PlayerStats(model: Model): any
	return AttributeAIService.Profile(model)
end

function Service.Build(teams: any, formations: any, pitchCFrame: CFrame, width: number, length: number, ball: BasePart, possession: any, attackSigns: {[string]: number}): any
	local options = {PitchCFrame = pitchCFrame, Width = width, Length = length, AttackSigns = attackSigns}
	local owner = possession:GetOwner()
	local ownerSide = owner and tostring(owner:GetAttribute("VTRTeam") or "") or nil
	local ballVelocity = flat(ball.AssemblyLinearVelocity)
	local motionKind = tostring(ball:GetAttribute("VTRMotionKind") or "Loose")
	local lastTouchTeam = tostring(ball:GetAttribute("LastTouchTeam") or "")
	local passStartedAt = tonumber(ball:GetAttribute("VTRPassStartedAt")) or 0
	local passTarget = ball:GetAttribute("VTRPassTarget")
	local passReceiver = tostring(ball:GetAttribute("VTRPassReceiver") or "")
	local passAge = os.clock() - passStartedAt
	local kinematicFlight = ball:GetAttribute("VTRKinematicFlight") == true
	local ballSpeed = ballVelocity.Magnitude
	local receiveLocked = false
	for _, side in ipairs({"Home", "Away"}) do
		for _, model in ipairs(teams[side] or {}) do
			if model:GetAttribute("VTRPreparingReceive") == true and (tonumber(model:GetAttribute("VTRReceiveUntil")) or 0) > os.clock() then
				receiveLocked = true
				break
			end
		end
		if receiveLocked then
			break
		end
	end
	local passInFlight = owner == nil
		and (motionKind == "Pass" or motionKind == "Corner")
		and (lastTouchTeam == "Home" or lastTouchTeam == "Away")
		and (typeof(passTarget) == "Vector3" or ball:GetAttribute("VTRLobPassActive") == true)
		and (kinematicFlight or ballSpeed > 18 or receiveLocked and passAge < 2.4 or passAge < 0.35)
		and ((passReceiver ~= "" and passAge < 3.2) or (receiveLocked and passAge < 3.6) or passAge < 0.35)
	if passInFlight then
		ownerSide = lastTouchTeam
	end
	local loose = owner == nil and not passInFlight
	local context: any = {
		Teams = {Home = {List = {}, ByModel = {}}, Away = {List = {}, ByModel = {}}},
		Players = {},
		Formations = formations,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Options = options,
		AttackSigns = attackSigns,
		Ball = ball,
		BallWorld = ball.Position,
		BallVelocity = ballVelocity,
		BallTeam = {
			Home = PitchConfig.WorldToTeamPitchPosition(ball.Position, "Home", options),
			Away = PitchConfig.WorldToTeamPitchPosition(ball.Position, "Away", options),
		},
		Possession = possession,
		Owner = owner,
		OwnerSide = ownerSide,
		LooseBall = loose,
		PassInFlight = passInFlight,
		WorldCupFirstPassPending = ball:GetAttribute("VTRWorldCupFirstPassPending")==true,
		MotionKind = motionKind,
		Now = os.clock(),
	}

	for _, side in ipairs({"Home", "Away"}) do
		for index, model in ipairs(teams[side] or {}) do
			local modelRoot = root(model)
			local formationName = formations[side] or "4-3-3"
			local slot = AIFormationService.GetSlot(formationName, index)
			local worldPosition = modelRoot and modelRoot.Position or PitchConfig.TeamPitchPositionToWorld(Vector3.new(slot.X, 3, slot.Z), side, options)
			local pitchPosition = PitchConfig.WorldToTeamPitchPosition(worldPosition, side, options)
			local stats = Service.PlayerStats(model)
			local info = {
				Model = model,
				Root = modelRoot,
				Side = side,
				OpponentSide = side == "Home" and "Away" or "Home",
				Index = index,
				Role = tostring(slot.Role),
				SpecificRole = tostring(slot.Name),
				Slot = slot,
				BasePitch = Vector3.new(slot.X, 3, slot.Z),
				BaseWorld = PitchConfig.TeamPitchPositionToWorld(Vector3.new(slot.X, 3, slot.Z), side, options),
				World = worldPosition,
				Pitch = pitchPosition,
				Lane = slot.Lane or PitchConfig.GetLane(pitchPosition),
				Stats = stats,
				Stamina = stats.currentStamina,
				IsUserControlled = model:GetAttribute("aiControlled") ~= true and (model:GetAttribute("controlledByUser") == true or model:GetAttribute("VTRUserId") ~= nil),
				IsGoalkeeper = tostring(slot.Role) == "GK" or tostring(model:GetAttribute("position")) == "GK",
				HasBall = owner == model,
				MovementProfile = tostring(model:GetAttribute("VTRAIMovementProfile") or "Balanced"),
			}
			context.Players[model] = info
			context.Teams[side].ByModel[model] = info
			table.insert(context.Teams[side].List, info)
		end
	end

	return context
end

function Service.NearestOpponent(context: any, info: any, point: Vector3?): (any?, number)
	local bestInfo = nil
	local bestDistance = math.huge
	local origin = point or info.World
	for _, opponent in ipairs(context.Teams[info.OpponentSide].List) do
		if opponent.Root then
			local distance = PitchConfig.GetDistanceStuds(origin, opponent.World)
			if distance < bestDistance then
				bestDistance = distance
				bestInfo = opponent
			end
		end
	end
	return bestInfo, bestDistance
end

function Service.NearestTeammate(context: any, info: any, predicate: ((any) -> boolean)?): (any?, number)
	local bestInfo = nil
	local bestDistance = math.huge
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and (not predicate or predicate(teammate)) then
			local distance = PitchConfig.GetDistanceStuds(info.World, teammate.World)
			if distance < bestDistance then
				bestDistance = distance
				bestInfo = teammate
			end
		end
	end
	return bestInfo, bestDistance
end

function Service.DistancePointToSegment(point: Vector3, a: Vector3, b: Vector3): (number, number)
	local ap = flat(point - a)
	local ab = flat(b - a)
	local lengthSquared = ab:Dot(ab)
	if lengthSquared <= 0.001 then
		return ap.Magnitude, 0
	end
	local t = math.clamp(ap:Dot(ab) / lengthSquared, 0, 1)
	local closest = flat(a) + ab * t
	return (flat(point) - closest).Magnitude, t
end

function Service.PassingLaneClear(context: any, passer: any, target: Vector3, passKind: string?): boolean
	local blockedDistance = passKind == "Driven" and 9 or passKind == "Lobbed" and 4 or 7
	for _, opponent in ipairs(context.Teams[passer.OpponentSide].List) do
		if opponent.Root then
			local distance, t = Service.DistancePointToSegment(opponent.World, passer.World, target)
			if t > 0.05 and t < 0.95 and distance < blockedDistance then
				return false
			end
		end
	end
	return true
end

function Service.IsOpen(context: any, info: any): (boolean, boolean, boolean)
	local _, distance = Service.NearestOpponent(context, info)
	return distance > 20, distance > 30, distance <= 10
end

function Service.Pressure(context: any, info: any): any
	local count20 = 0
	local closest = math.huge
	local under = false
	for _, opponent in ipairs(context.Teams[info.OpponentSide].List) do
		if opponent.Root and info.Root then
			local distance = PitchConfig.GetDistanceStuds(opponent.World, info.World)
			closest = math.min(closest, distance)
			if distance <= 20 then
				local toCarrier = flat(info.World - opponent.World)
				local facing = flat(opponent.Root.CFrame.LookVector)
				local moving = flat(opponent.Root.AssemblyLinearVelocity)
				local facingToward = facing.Magnitude > 0.01 and toCarrier.Magnitude > 0.01 and facing.Unit:Dot(toCarrier.Unit) > 0.1
				local movingToward = moving.Magnitude > 0.5 and toCarrier.Magnitude > 0.01 and moving.Unit:Dot(toCarrier.Unit) > 0.1
				if facingToward or movingToward then
					under = true
					count20 += 1
				end
			end
		end
	end
	return {
		Under = under,
		Heavy = closest <= 10,
		Closest = closest,
		Count18 = count20,
		Count20 = count20,
		None = closest > 20,
		Score = 1 - math.clamp((closest - 10) / 10, 0, 1),
	}
end

function Service.AttackStage(context: any, side: string): string
	local ballPitch = context.BallTeam[side]
	if PitchConfig.InZone(ballPitch, "OpponentBox") or ballPitch.Z >= 610 then
		return "FinalChance"
	elseif ballPitch.Z >= 495 then
		if ballPitch.X < 90 or ballPitch.X > 334 then
			return "WideAttack"
		end
		return "CentralAttack"
	elseif ballPitch.Z >= 247 then
		return "Progression"
	end
	return "BuildUp"
end

function Service.DefensiveMood(context: any, attackingSide: string, carrier: any?): string
	local defendingSide = attackingSide == "Home" and "Away" or "Home"
	local origin = carrier and carrier.World or context.BallWorld
	local pressers = 0
	local overcommitted = 0
	local closest = math.huge
	for _, defender in ipairs(context.Teams[defendingSide].List) do
		if defender.Root then
			local distance = PitchConfig.GetDistanceStuds(defender.World, origin)
			closest = math.min(closest, distance)
			local assignment = tostring(defender.Model:GetAttribute("currentAssignment") or "")
			if distance <= 22 then
				local velocity = flat(defender.Root.AssemblyLinearVelocity)
				local toBall = flat(origin - defender.World)
				if velocity.Magnitude > 3 and toBall.Magnitude > 0.01 and velocity.Unit:Dot(toBall.Unit) > 0.2 then
					pressers += 1
				end
			end
			if distance <= 12 and (assignment == "PressBallCarrier" or assignment == "ContainBallCarrier") then
				overcommitted += 1
			end
		end
	end
	if closest <= 7 or pressers >= 3 or overcommitted >= 2 then
		return "AggressiveRisk"
	elseif closest <= 20 or pressers >= 1 then
		return "Pressing"
	end
	return "Passive"
end

function Service.DefensiveLineZ(context: any, attackingSide: string): number
	local defendingSide = attackingSide == "Home" and "Away" or "Home"
	local bestZ = 0
	for _, defender in ipairs(context.Teams[defendingSide].List) do
		if defender.Role == "CB" or defender.Role == "Fullback" then
			local asAttackerPitch = PitchConfig.WorldToTeamPitchPosition(defender.World, attackingSide, context.Options)
			if asAttackerPitch.Z > bestZ then
				bestZ = asAttackerPitch.Z
			end
		end
	end
	return bestZ
end

function Service.SpaceAt(context: any, side: string, teamPitchPoint: Vector3, radius: number): boolean
	local world = PitchConfig.TeamPitchPositionToWorld(teamPitchPoint, side, context.Options)
	local opponentSide = side == "Home" and "Away" or "Home"
	for _, opponent in ipairs(context.Teams[opponentSide].List) do
		if opponent.Root and PitchConfig.GetDistanceStuds(opponent.World, world) < radius then
			return false
		end
	end
	return true
end

return Service
