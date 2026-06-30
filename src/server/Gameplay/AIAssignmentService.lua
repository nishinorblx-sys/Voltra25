--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)
local AIFormationService = require(script.Parent.AIFormationService)
local AILooseBallService = require(script.Parent.AILooseBallService)
local AIGoalkeeperService = require(script.Parent.AIGoalkeeperService)
local AIDefensiveDecisionService = require(script.Parent.AIDefensiveDecisionService)
local AISquadPersonalityService = require(script.Parent.AISquadPersonalityService)

local Service = {}
Service.__index = Service

local function roleWeight(info: any, roles: {[string]: number}): number
	return roles[info.Role] or roles[info.SpecificRole] or 0
end

local function asWorld(context: any, side: string, pitch: Vector3): Vector3
	return PitchConfig.TeamPitchPositionToWorld(PitchConfig.ClampInsidePitch(pitch), side, context.Options)
end

local function makeAssignment(context: any, info: any, name: string, pitch: Vector3, urgency: number, sprint: boolean?, faceWorld: Vector3?): any
	local targetWorld = asWorld(context, info.Side, pitch)
	return {
		Model = info.Model,
		Info = info,
		Role = info.Role,
		Zone = info.SpecificRole,
		Phase = "",
		PrimaryAssignment = name,
		MovementTarget = targetWorld,
		TargetWorld = targetWorld,
		TargetPitch = pitch,
		MovementUrgency = urgency,
		SprintAllowed = sprint == true,
		FaceWorld = faceWorld or context.BallWorld,
		MarkTarget = nil,
		SupportTarget = context.Owner,
	}
end

local function baseWithPhase(info: any, phase: string, ballPitch: Vector3, style: any): Vector3
	local base = info.BasePitch
	if phase == "OwnPossession_BuildUp" then
		if info.Role == "CB" then
			return Vector3.new(base.X + (base.X < PitchConfig.HALF_WIDTH and -18 or 18), 3, math.max(78, ballPitch.Z - 45))
		elseif info.Role == "Fullback" then
			local width = style:Ratio("AttackingWidth")
			local wideX = base.X < PitchConfig.HALF_WIDTH and 45 + (1 - width) * 46 or 379 - (1 - width) * 46
			return Vector3.new(wideX, 3, math.max(base.Z, ballPitch.Z + 28))
		elseif info.Role == "CDM" then
			return Vector3.new(212, 3, math.max(120, ballPitch.Z + 35))
		end
	elseif phase == "Transition_JustWonBall" then
		if info.Role == "ST" or info.Role == "Winger" then
			return Vector3.new(base.X, 3, math.min(690, math.max(base.Z, ballPitch.Z + 115)))
		end
	end
	return base
end

local function defendingBase(info: any, ballPitch: Vector3, style: any): Vector3
	local base = info.BasePitch
	local depth = style:Ratio("DefensiveDepth")
	local lineZ = AIDefensiveDecisionService.LineHeight(ballPitch, depth)
	if info.Role == "CB" then
		return Vector3.new(base.X, 3, lineZ)
	elseif info.Role == "Fullback" then
		local ballSide = ballPitch.X < PitchConfig.HALF_WIDTH and "Left" or "Right"
		local ownSide = base.X < PitchConfig.HALF_WIDTH and "Left" or "Right"
		local x = ownSide == ballSide and base.X or base.X + (PitchConfig.HALF_WIDTH - base.X) * 0.4
		return Vector3.new(x, 3, lineZ + 20)
	elseif info.Role == "CDM" then
		return Vector3.new(212, 3, math.max(95, lineZ + 58))
	elseif info.Role == "CM" or info.Role == "CAM" then
		return Vector3.new(base.X + (PitchConfig.HALF_WIDTH - base.X) * 0.22, 3, math.max(130, lineZ + 92))
	elseif info.Role == "Winger" then
		local defensiveWidth = style:Ratio("DefensiveWidth")
		local tuckedX = base.X + (PitchConfig.HALF_WIDTH - base.X) * (0.58 - defensiveWidth * 0.24)
		return Vector3.new(tuckedX, 3, math.max(160, lineZ + 126))
	elseif info.Role == "ST" then
		return Vector3.new(base.X, 3, math.max(260, ballPitch.Z + 95))
	end
	return base
end

local function shortSupportTarget(info: any, ballPitch: Vector3, style: any): Vector3
	local sideSign = info.Pitch.X >= ballPitch.X and 1 or -1
	local supportDistance = 34 + style:Ratio("SupportDistance") * 34
	if ballPitch.X < 90 then
		return Vector3.new(ballPitch.X + supportDistance, 3, ballPitch.Z + 15)
	elseif ballPitch.X > 334 then
		return Vector3.new(ballPitch.X - supportDistance, 3, ballPitch.Z + 15)
	end
	return Vector3.new(ballPitch.X + supportDistance * sideSign, 3, ballPitch.Z + 20)
end

local function onsideZ(context:any, side:string, fallback:number):number
	local line=AIContextBuilder.DefensiveLineZ(context,side)
	if line > 90 then
		return math.clamp(math.min(fallback,line-7),0,704)
	end
	return math.clamp(fallback,0,704)
end

local function forwardSupportTarget(context:any, info: any, ballPitch: Vector3): Vector3
	return Vector3.new(PitchConfig.GetLaneCenter(info.Lane), 3, onsideZ(context,info.Side,ballPitch.Z + 72))
end

local function recycleTarget(ballPitch: Vector3): Vector3
	if ballPitch.X < 90 or ballPitch.X > 334 then
		return Vector3.new(212, 3, math.max(60, ballPitch.Z - 60))
	end
	return Vector3.new(ballPitch.X, 3, math.max(60, ballPitch.Z - 70))
end

local function wideOutletTarget(context:any, info: any, ballPitch: Vector3, style: any): Vector3
	local width = style:Ratio("AttackingWidth")
	local discipline = style:Ratio("WidthDiscipline")
	local left = info.BasePitch.X < PitchConfig.HALF_WIDTH
	local touchlineX = left and 35 or 389
	local wideX = left and 45 + (1 - width) * 55 or 379 - (1 - width) * 55
	wideX = wideX + (touchlineX - wideX) * discipline * 0.38
	return Vector3.new(wideX, 3, onsideZ(context,info.Side,math.min(690, math.max(info.BasePitch.Z, ballPitch.Z + 40))))
end

local function runBehindTarget(context: any, info: any): Vector3
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, info.Side)
	local currentZ = math.clamp(info.Pitch.Z, 0, 704)
	local safeLine = defensiveLine > 90 and defensiveLine - 7 or 704
	local desiredZ = math.min(math.max(currentZ + 22, defensiveLine - 20), safeLine, 704)
	return Vector3.new(PitchConfig.GetLaneCenter(info.Lane), 3, math.clamp(desiredZ, 0, 704))
end

local function chooseClosest(list: {any}, scoreFn: (any) -> number): any?
	local best = nil
	local bestScore = -math.huge
	for _, info in ipairs(list) do
		local score = scoreFn(info)
		if score > bestScore then
			best = info
			bestScore = score
		end
	end
	return best
end

function Service.new(style: any)
	return setmetatable({Style = style}, Service)
end

function Service:_assignLoose(context: any, side: string, phase: string, assignments: any)
	local chaser, cover = AILooseBallService.ChooseChasers(context, side)
	local projected = AILooseBallService.ProjectBall(context, 0.22)
	local ballPitch = context.BallTeam[side]
	for _, info in ipairs(context.Teams[side].List) do
		local assignment
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.7, false)
		elseif info == chaser then
			assignment = makeAssignment(context, info, "ChaseLooseBall", PitchConfig.WorldToTeamPitchPosition(projected, side, context.Options), 1, true)
		elseif info == cover then
			assignment = makeAssignment(context, info, "CoverLooseBall", Vector3.new(ballPitch.X, 3, math.max(35, ballPitch.Z - 34)), 0.82, true)
		elseif info.Role == "ST" or info.Role == "Winger" then
			assignment = makeAssignment(context, info, "PrepareCounter", Vector3.new(info.BasePitch.X, 3, math.min(690, math.max(info.BasePitch.Z, ballPitch.Z + 80))), 0.78, true)
		elseif PitchConfig.InZone(ballPitch, "OwnBox") and (info.Role == "CB" or info.Role == "CDM") then
			assignment = makeAssignment(context, info, "ProtectGoal", Vector3.new(info.BasePitch.X, 3, 70), 0.86, true)
		else
			assignment = makeAssignment(context, info, "RecoverShape", defendingBase(info, ballPitch, self.Style), 0.74, false)
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:_assignAttack(context: any, side: string, phase: string, assignments: any)
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	local ballPitch = context.BallTeam[side]
	local list = context.Teams[side].List
	local used: any = {}
	local function eligible(info: any): boolean
		return info.Model ~= owner and not info.IsUserControlled and not info.IsGoalkeeper and used[info] ~= true
	end
	local short = chooseClosest(list, function(info)
		if not eligible(info) then return -math.huge end
		local distance = PitchConfig.GetDistanceStuds(info.World, context.BallWorld)
		if distance > 120 or info.Pitch.Z > ballPitch.Z + 95 then return -math.huge end
		return -math.abs(distance - 55) + roleWeight(info, {CM = 16, CDM = 14, CAM = 12, Fullback = 8, Winger = 6}) + AISquadPersonalityService.SupportBias(info)
	end)
	if short then used[short] = true end
	local forward = chooseClosest(list, function(info)
		if not eligible(info) then return -math.huge end
		return (info.Pitch.Z - ballPitch.Z) + roleWeight(info, {ST = 18, Winger = 14, CAM = 12, CM = 8})
	end)
	if forward then used[forward] = true end
	local recycle = chooseClosest(list, function(info)
		if not eligible(info) then return -math.huge end
		return (ballPitch.Z - info.Pitch.Z) + roleWeight(info, {CDM = 20, CM = 15, CB = 12, Fullback = 8})
	end)
	if recycle then used[recycle] = true end
	local runBehind = chooseClosest(list, function(info)
		if not eligible(info) or self.Style:Ratio("BuildUpSpeed") + self.Style:Ratio("RunsInBehind") < 0.65 then return -math.huge end
		local target = runBehindTarget(context, info)
		if not AIContextBuilder.SpaceAt(context, side, target, 18) then return -math.huge end
		return roleWeight(info, {ST = 24, Winger = 20, CAM = 7}) + self.Style:Ratio("RunsInBehind") * 30 + AISquadPersonalityService.RunBehindBias(info)
	end)
	if runBehind then used[runBehind] = true end
	local overlap = chooseClosest(list, function(info)
		if not eligible(info) or info.Role ~= "Fullback" or (not self.Style:CanOverlap(info.Stamina) and self.Style:Ratio("FullbackAttack") < 0.5) then return -math.huge end
		local sameSide = (info.BasePitch.X < PitchConfig.HALF_WIDTH and ballPitch.X < PitchConfig.HALF_WIDTH) or (info.BasePitch.X > PitchConfig.HALF_WIDTH and ballPitch.X > PitchConfig.HALF_WIDTH)
		return sameSide and (self.Style:Ratio("OverlapFrequency") * 42 + self.Style:Ratio("FullbackAttack") * 30 + info.Stamina * 0.12) or -math.huge
	end)
	if overlap then used[overlap] = true end

	for _, info in ipairs(list) do
		local assignment
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.62, false)
		elseif info.Model == owner then
			assignment = makeAssignment(context, info, "BallCarrierDecision", info.Pitch + Vector3.new(0, 0, 18), 1, true)
		elseif info == short then
		assignment = makeAssignment(context, info, "ShortSupport", shortSupportTarget(info, ballPitch, self.Style), 0.82, info.Stamina > 45)
		elseif info == forward then
			assignment = makeAssignment(context, info, "ForwardSupport", forwardSupportTarget(context, info, ballPitch), 0.9, true)
		elseif info == recycle then
			assignment = makeAssignment(context, info, "RecycleSupport", recycleTarget(ballPitch), 0.74, false)
		elseif info == runBehind then
			assignment = makeAssignment(context, info, phase == "Transition_JustWonBall" and "CounterSprint" or "RunBehind", runBehindTarget(context, info), 1, true)
		elseif info == overlap then
			local sideSign = info.BasePitch.X < PitchConfig.HALF_WIDTH and -1 or 1
			assignment = makeAssignment(context, info, "OverlapRun", Vector3.new(math.clamp(ballPitch.X + sideSign * 42, 35, 389), 3, math.min(690, ballPitch.Z + 72)), 0.94, true)
		elseif info.Role == "Winger" or info.Role == "Fullback" then
			assignment = makeAssignment(context, info, "WideOutlet", wideOutletTarget(context, info, ballPitch, self.Style), 0.78, info.Stamina > 35)
		elseif info.Role == "CM" or info.Role == "CAM" then
			local z=onsideZ(context,side,math.max(info.BasePitch.Z,ballPitch.Z+54))
			local x=info.BasePitch.X+(ballPitch.X-info.BasePitch.X)*0.32
			assignment = makeAssignment(context, info, "ExtraSupport", Vector3.new(x,3,z), 0.84, info.Stamina > 32)
		elseif info.Role == "CB" or (info.Role == "CDM" and info.Pitch.Z < ballPitch.Z) then
			assignment = makeAssignment(context, info, "StayBackCover", Vector3.new(info.BasePitch.X, 3, math.max(65, math.min(info.BasePitch.Z, ballPitch.Z - 75))), 0.7, false)
		else
			assignment = makeAssignment(context, info, "HoldShape", baseWithPhase(info, phase, ballPitch, self.Style), 0.74, false)
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:_assignDefense(context: any, side: string, phase: string, assignments: any)
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	local ballPitch = context.BallTeam[side]
	local primary = chooseClosest(context.Teams[side].List, function(info)
		if info.IsUserControlled or info.IsGoalkeeper then return -math.huge end
		if info.Role == "CB" and not AIDefensiveDecisionService.ShouldCenterBackStep(info, ballPitch) then return -math.huge end
		local distance = ownerInfo and PitchConfig.GetDistanceStuds(info.World, ownerInfo.World) or PitchConfig.GetDistanceStuds(info.World, context.BallWorld)
		return -distance + roleWeight(info, {ST = 10, Winger = 8, CM = 7, CDM = 6, Fullback = 4, CB = -8}) + self.Style:Pressing() * 18 + self.Style:Ratio("PressTriggerDistance") * 12 + self.Style:Ratio("TackleAggression") * 8 + AISquadPersonalityService.PressBias(info)
	end)
	local cover = chooseClosest(context.Teams[side].List, function(info)
		if info.IsUserControlled or info == primary or info.IsGoalkeeper then return -math.huge end
		local distance = ownerInfo and PitchConfig.GetDistanceStuds(info.World, ownerInfo.World) or PitchConfig.GetDistanceStuds(info.World, context.BallWorld)
		return -math.abs(distance - 28) + roleWeight(info, {CDM = 18, CM = 12, CB = 8, Fullback = 6})
	end)
	local pressRadius = 26 + self.Style:Ratio("PressTriggerDistance") * 34 + self.Style:Pressing() * 18
	local maxPressers = ballPitch.Z < 150 and 3 or ballPitch.Z < 360 and 2 or 1
	local pressers: {[any]: boolean} = {}
	if primary then pressers[primary] = true end
	if cover and maxPressers >= 2 then pressers[cover] = true end
	if ownerInfo and maxPressers >= 3 then
		local extra = chooseClosest(context.Teams[side].List, function(info)
			if info.IsUserControlled or info == primary or info == cover or info.IsGoalkeeper then return -math.huge end
			local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
			if distance > pressRadius then return -math.huge end
			return -distance + roleWeight(info, {Winger = 12, CM = 10, CDM = 8, Fullback = 7, ST = 6, CB = -4}) + self.Style:Pressing() * 18
		end)
		if extra then pressers[extra] = true end
	end
	for _, info in ipairs(context.Teams[side].List) do
		local assignment
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.72, false)
		elseif info == primary and ownerInfo then
			assignment = makeAssignment(context, info, "PressBallCarrier", AIDefensiveDecisionService.ContainTarget(ownerInfo.Pitch), 1, true, ownerInfo.World)
			assignment.MarkTarget = owner
		elseif info == cover and ownerInfo then
			assignment = makeAssignment(context, info, "CoverPresser", AIDefensiveDecisionService.CoverPresserTarget(ownerInfo.Pitch), 0.88, true, ownerInfo.World)
			assignment.MarkTarget = owner
		elseif pressers[info] and ownerInfo then
			assignment = makeAssignment(context, info, "ContainBallCarrier", AIDefensiveDecisionService.ContainTarget(ownerInfo.Pitch), 0.94, true, ownerInfo.World)
			assignment.MarkTarget = owner
		else
			local base = defendingBase(info, ballPitch, self.Style)
			local name = "RecoverShape"
			if info.Role == "CB" and ballPitch.Z < 132 then
				name = "ProtectBox"
			elseif info.Role == "Fullback" and (ballPitch.X < 90 or ballPitch.X > 334) then
				name = "DefendWide"
			elseif info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM" then
				name = "BlockPassingLane"
				if ownerInfo then
					for _, receiver in ipairs(context.Teams[ownerInfo.Side].List) do
						if receiver.Model ~= owner and receiver.Pitch.Z > ownerInfo.Pitch.Z and PitchConfig.GetDistanceStuds(receiver.World, ownerInfo.World) < 125 then
							base = AIDefensiveDecisionService.BlockLaneTarget(ownerInfo.Pitch, receiver.Pitch)
							assignment = makeAssignment(context, info, name, base, 0.78, false, ownerInfo.World)
							assignment.MarkTarget = receiver.Model
							break
						end
					end
				end
			elseif info.Role == "ST" then
				name = "HoldDefensiveLine"
			end
			assignment = assignment or makeAssignment(context, info, name, base, 0.74, false, ownerInfo and ownerInfo.World or context.BallWorld)
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:Build(context: any, phases: {[string]: string}): any
	local assignments: any = {Home = {}, Away = {}}
	for _, side in ipairs({"Home", "Away"}) do
		local phase = phases[side] or "LooseBall"
		assignments[side] = self:BuildSide(context, side, phase)
	end
	return assignments
end

function Service:BuildSide(context: any, side: string, phase: string): any
	local assignments = {}
	if phase == "LooseBall" then
		self:_assignLoose(context, side, phase, assignments)
	elseif context.OwnerSide == side then
		self:_assignAttack(context, side, phase, assignments)
	else
		self:_assignDefense(context, side, phase, assignments)
	end
	return assignments
end

return Service
