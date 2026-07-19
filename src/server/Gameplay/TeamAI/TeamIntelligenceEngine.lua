--!strict

local RunService = game:GetService("RunService")
local PitchConfig = require(script.Parent.Parent.PitchConfig)
local AIWorldModel = require(script.Parent.AIWorldModel)
local AISpatialControlMap = require(script.Parent.AISpatialControlMap)
local AITacticalIntentDirector = require(script.Parent.AITacticalIntentDirector)
local AIPositionalStructurePlanner = require(script.Parent.AIPositionalStructurePlanner)
local AITacticalSlotAssignment = require(script.Parent.AITacticalSlotAssignment)
local AIPossessionDirector = require(script.Parent.AIPossessionDirector)
local AISupportCoordinator = require(script.Parent.AISupportCoordinator)
local AIRunCoordinator = require(script.Parent.AIRunCoordinator)
local AIDefensivePlan = require(script.Parent.AIDefensivePlan)
local AIDefensiveBlockPlanner = require(script.Parent.AIDefensiveBlockPlanner)
local AITeamMemory = require(script.Parent.AITeamMemory)
local AITeamMetrics = require(script.Parent.AITeamMetrics)
local AITeamBrain = require(script.Parent.AITeamBrain)
local AIMovementService = require(script.Parent.Parent.AIMovementService)
local AIDebugService = require(script.Parent.Parent.AIDebugService)
local AIDifficultyService = require(script.Parent.Parent.AIDifficultyService)
local AITacticalStyleService = require(script.Parent.Parent.AITacticalStyleService)

local Engine = {}
Engine.__index = Engine

local function debugEnabled(): boolean
	return workspace:GetAttribute("VTRKickoffDebug") == true and (RunService:IsStudio() or game.PrivateServerId ~= "")
end

local function baseAssignment(context: any, info: any): any
	local target = PitchConfig.TeamPitchPositionToWorld(info.BasePitch, info.Side, context.Options)
	return {
		Model = info.Model,
		Info = info,
		Role = info.Role,
		Phase = "TeamShape",
		PrimaryAssignment = "HoldTeamShape",
		MovementTarget = target,
		TargetWorld = target,
		TargetPitch = info.BasePitch,
		MovementUrgency = .55,
		SprintAllowed = false,
		FaceWorld = context.BallWorld,
		SupportTarget = context.Owner,
	}
end

local function looseBallAssignments(context: any, side: string): any
	local assignments = {}
	local best = nil
	local bestDistance = math.huge
	for _, info in ipairs(context.Teams[side].List) do
		if info.Root and not info.IsUserControlled then
			local distance = PitchConfig.GetDistanceStuds(info.World, context.BallWorld)
			if distance < bestDistance then
				best = info
				bestDistance = distance
			end
		end
	end
	for _, info in ipairs(context.Teams[side].List) do
		if info.Root and not info.IsUserControlled then
			local assignment = baseAssignment(context, info)
			if info == best then
				assignment.PrimaryAssignment = "AttackLooseBall"
				assignment.TargetWorld = context.BallWorld
				assignment.MovementTarget = context.BallWorld
				assignment.MovementUrgency = 1
				assignment.SprintAllowed = true
			end
			assignments[info.Model] = assignment
		end
	end
	return assignments
end

function Engine.new(teams: any, formations: any, pitchCFrame: CFrame, width: number, length: number, ball: BasePart, possession: any, ballService: any, difficultyName: string, tactics: any?, executor: any): any
	local homeTactics = type(tactics) == "table" and tactics.HomeTactics or tactics
	local awayTactics = type(tactics) == "table" and tactics.AwayTactics or tactics
	local homeStyle = AITacticalStyleService.new(homeTactics)
	local awayStyle = AITacticalStyleService.new(awayTactics)
	local difficulty = AIDifficultyService.Resolve(difficultyName, Random.new())
	local self = setmetatable({
		Teams = teams,
		Formations = formations,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Ball = ball,
		Possession = possession,
		BallService = ballService,
		Half = 1,
		ExternalPhase = nil,
		Styles = {Home = homeStyle, Away = awayStyle},
		Difficulty = difficulty,
		Spatial = AISpatialControlMap.new(),
		Intent = AITacticalIntentDirector.new(),
		PossessionPlans = AIPossessionDirector.new(),
		Memory = AITeamMemory.new(),
		Metrics = AITeamMetrics.new(),
		DefensiveBlock = AIDefensiveBlockPlanner.new(),
		DefensiveDuties = {Home = {}, Away = {}},
		Movement = AIMovementService.new(executor),
		TeamBrain = AITeamBrain.new(ballService, {Home = homeStyle, Away = awayStyle}, difficulty),
		Debug = AIDebugService.new(),
		CurrentAssignments = {Home = {}, Away = {}},
		CurrentStructures = {Home = {}, Away = {}},
		CurrentIntents = {Home = nil, Away = nil},
		LastContext = nil,
		ManualTackleSides = {},
		FirstMatchAssistance = nil,
		WasLive = false,
		Accum = {Spatial = .25, Intent = .24, Structure = .24, Carrier = .1, Movement = .04, Debug = .5},
		LastPassStateKey = "",
		ReceiverRouteSequence = 0,
	}, Engine)
	local function routeReceiver(model: Model, target: Vector3, passKind: string?, execution: any)
		self:_routeReceiverBeforePass(model, target, passKind, execution)
	end
	self.TeamBrain:SetImmediateReceiverRoute(routeReceiver)
	return self
end

function Engine:_attackSigns(): {[string]: number}
	local home = (self.Half or 1) >= 2 and 1 or -1
	return {Home = home, Away = -home}
end

function Engine:_isLive(): boolean
	return self.ExternalPhase == nil or self.ExternalPhase == "Live" or self.ExternalPhase == "IN PLAY"
end

function Engine:_firstMatchBlend(now: number): number
	local state = self.FirstMatchAssistance
	if not state then return 0 end
	local blend = AIDifficultyService.FirstMatchBlend(state.RestoreStartedAt, now)
	if blend <= 0 then self.FirstMatchAssistance = nil end
	return blend
end

function Engine:_context(): any
	local start = os.clock()
	local context = AIWorldModel.Build(self.Teams, self.Formations, self.PitchCFrame, self.Width, self.Length, self.Ball, self.Possession, self:_attackSigns(), self.LastContext)
	context.FirstMatchAssistance = self:_firstMatchBlend(context.Now or os.clock())
	context.FirstMatchPassTempoCap = AIDifficultyService.FirstMatchPassTempoCap(context.FirstMatchAssistance)
	context.ManualTackleSides = self.ManualTackleSides
	context.DefensivePress = context.DefensivePress or {Home = {}, Away = {}}
	context.PressPaused = context.PressPaused or {Home = false, Away = false}
	self.Metrics:Sample("WorldMs", os.clock() - start)
	return context
end

function Engine:_routeReceiverBeforePass(model: Model, target: Vector3, passKind: string?, execution: any)
	if typeof(target) ~= "Vector3" or not model or not model.Parent then return end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	local side = tostring(model:GetAttribute("VTRTeam") or "")
	local mode = tostring(execution and execution.SelectedLocomotionMode or model:GetAttribute("VTRReceiveLocomotionMode") or "Run")
	local sprint = mode == "SprintBurst"
	local assignment = {
		PrimaryAssignment = "ReceivePass",
		TargetWorld = target,
		MovementTarget = target,
		FaceWorld = self.Ball and self.Ball.Position or target,
		MovementUrgency = 1,
		SprintAllowed = sprint,
		Phase = "PassReception",
		SprintConservation = 0,
	}
	if self.CurrentAssignments[side] then
		self.CurrentAssignments[side][model] = assignment
	end
	self.Movement.State[model] = nil
	self.ReceiverRouteSequence += 1
	local ticket = "ReceivePass:TeamAI:" .. tostring(self.ReceiverRouteSequence)
	self.Movement.Executor:SetCommand(model, {
		Target = Vector3.new(target.X, root.Position.Y, target.Z),
		Urgency = 1,
		LocomotionMode = sprint and "SprintBurst" or mode == "Jog" and "Jog" or "Run",
		SprintAllowed = sprint,
		SprintRequired = sprint,
		Essential = true,
		BurstMaximumSeconds = 3,
		RecoveryMinimumSeconds = .8,
		MinimumEnergy = 15,
		AssignmentId = ticket,
		RunTicketId = ticket,
		FaceTarget = self.Ball and self.Ball.Position or target,
	})
	model:SetAttribute("currentAssignment", "ReceivePass")
	model:SetAttribute("targetPosition", target)
	model:SetAttribute("MovementTarget", target)
	model:SetAttribute("SupportRole", "ReceivePass")
	model:SetAttribute("AttackAssignment", "ReceivePass")
	model:SetAttribute("TeamPhase", "PassReception")
	model:SetAttribute("MovementMode", sprint and "SprintBurst" or mode == "Jog" and "Jog" or "Run")
	model:SetAttribute("VTRReceiveHardLock", true)
	model:SetAttribute("VTRReceiveHardLockUntil", (self.LastContext and self.LastContext.Now or os.clock()) + math.max(.65, tonumber(execution and execution.BallETA) or .9))
	model:SetAttribute("VTRReceiveLocomotionMode", mode)
	model:SetAttribute("VTRReceiveDesiredArrivalVelocity", execution and execution.DesiredArrivalVelocity or model:GetAttribute("VTRReceiveDesiredArrivalVelocity"))
	model:SetAttribute("VTRReceiveBrakingDistance", execution and execution.BrakingDistance or model:GetAttribute("VTRReceiveBrakingDistance"))
	model:SetAttribute("VTRReceiveContactKind", execution and execution.ContactKind or model:GetAttribute("VTRReceiveContactKind"))
	model:SetAttribute("VTRReceivePreferredFoot", execution and execution.PreferredFoot or model:GetAttribute("VTRReceivePreferredFoot"))
	model:SetAttribute("VTRAIMovementIntensity", 1)
	model:SetAttribute("VTRAIIntentionUntil", (self.LastContext and self.LastContext.Now or os.clock()) + math.max(.45, tonumber(execution and execution.BallETA) or .8))
end

function Engine:_publishTeamContext(context: any)
	context.TeamIntent = self.CurrentIntents
	context.TeamPlans = self.CurrentPlans
	context.TeamStructures = self.CurrentStructures
	context.TeamSpatialMap = self.Spatial
	local stories = {}
	for _, side in ipairs({"Home", "Away"}) do
		local intent = self.CurrentIntents[side]
		local plan = self.CurrentPlans and self.CurrentPlans[side]
		local name = tostring(intent and intent.Intent or "")
		local movement = name == "AttractPress" and "Recycle" or name == "SwitchPlay" and "Switch" or name == "CounterAttack" and "Counter" or name == "CreateChance" and "Chance" or name == "DirectRelease" and "Direct" or "Possession"
		stories[side] = {Action = plan and plan.Route and plan.Route[plan.Step] or name, Movement = movement, Intent = name}
	end
	context.TeamStories = stories
end

function Engine:_buildAssignments(context: any)
	local start = os.clock()
	local intents = self.CurrentIntents
	local plans = {Home = nil, Away = nil}
	local assignments = {Home = {}, Away = {}}
	local structures = {Home = {}, Away = {}}
	for _, side in ipairs({"Home", "Away"}) do
		if context.LooseBall then
			assignments[side] = looseBallAssignments(context, side)
		else
			local plan = self.PossessionPlans:Update(context, side, intents[side], self.Spatial, self.Memory)
			plans[side] = plan
			local block = nil
			local slots
			if context.OwnerSide == side then
				slots = AIPositionalStructurePlanner.Build(context, side, self.Styles[side], intents[side], self.Spatial)
			else
				block = self.DefensiveBlock:Build(context, side, self.Styles[side], intents[side])
				slots = block.Slots
				context.DefensiveBlockPlans = context.DefensiveBlockPlans or {}
				context.DefensiveBlockPlans[side] = block
			end
			structures[side] = slots
			local sideAssignments = AITacticalSlotAssignment.Assign(context, side, slots)
			for _, info in ipairs(context.Teams[side].List) do
				if info.Root and not info.IsUserControlled and not sideAssignments[info.Model] then
					sideAssignments[info.Model] = baseAssignment(context, info)
				end
			end
			if context.OwnerSide == side then
				AISupportCoordinator.Apply(context, side, sideAssignments, plan)
				AIRunCoordinator.Apply(context, side, sideAssignments, plan, self.Styles[side])
			else
				AIDefensivePlan.Apply(context, side, sideAssignments, intents[side], block, self.DefensiveDuties[side])
				AIDefensivePlan.ApplyIncomingPass(context, side, sideAssignments, self.DefensiveDuties[side])
			end
			assignments[side] = sideAssignments
		end
	end
	self.CurrentPlans = plans
	self.CurrentStructures = structures
	self.CurrentAssignments = assignments
	self.Metrics:Sample("AssignmentMs", os.clock() - start)
end

function Engine:SetHalf(half: number?)
	local nextHalf = half or 1
	if self.Half ~= nextHalf then
		self.CurrentAssignments = {Home = {}, Away = {}}
		self.CurrentStructures = {Home = {}, Away = {}}
		self.CurrentIntents = {Home = nil, Away = nil}
		self.Movement:Clear()
		self.TeamBrain:Clear()
		self.Intent:Reset()
		self.PossessionPlans:Reset()
		self.Memory:Reset()
		self.DefensiveBlock:Reset()
		self.DefensiveDuties = {Home = {}, Away = {}}
	end
	self.Half = nextHalf
end

function Engine:SetExternalPhase(phase: string?)
	self.ExternalPhase = phase
end

function Engine:SetManualTackleSides(sides: {[string]: boolean}?)
	self.ManualTackleSides = sides or {}
end

function Engine:SetFirstMatchAssistance(active: boolean)
	self.FirstMatchAssistance = active and {RestoreStartedAt = nil} or nil
end

function Engine:BeginFirstMatchRestoration()
	if self.FirstMatchAssistance then
		self.FirstMatchAssistance.RestoreStartedAt = os.clock()
	end
end

function Engine:UpdateTactics(side: string, tactics: any)
	local targetSide = side == "Away" and "Away" or "Home"
	local style = AITacticalStyleService.new(tactics)
	self.Styles[targetSide] = style
	self.TeamBrain:UpdateStyle(targetSide, style)
	self.TeamBrain:SetImmediateReceiverRoute(function(model: Model, target: Vector3, passKind: string?, execution: any)
		self:_routeReceiverBeforePass(model, target, passKind, execution)
	end)
	self.CurrentAssignments[targetSide] = {}
	self.Intent:Reset(targetSide)
	self.PossessionPlans:Reset(targetSide)
	self.Memory:Reset(targetSide)
	self.DefensiveBlock:Reset(targetSide)
	self.DefensiveDuties[targetSide] = {}
end

function Engine:ClearTransientPlans(side: string?)
	local targetSide = side == "Away" and "Away" or "Home"
	self.CurrentAssignments[targetSide] = {}
	self.CurrentStructures[targetSide] = {}
	self.CurrentIntents[targetSide] = nil
	self.Intent:Reset(targetSide)
	self.PossessionPlans:Reset(targetSide)
	self.Memory:Reset(targetSide)
	self.DefensiveBlock:Reset(targetSide)
	self.DefensiveDuties[targetSide] = {}
	self.TeamBrain:Clear(targetSide)
	for _, model in ipairs(self.Teams[targetSide] or {}) do
		self.Movement.State[model] = nil
		self.Movement.Executor:Clear(model)
		for _, attribute in ipairs({"AIAssignment", "AITacticalSlot", "AIRestDefense", "TeamPlan", "TeamDefensiveIntent", "AIDefensiveDutyId", "AIDefensiveDuty", "AIIncomingPassDuty", "VTRRunTicketId", "VTRRunApproved", "VTRRunKind", "VTRSupportRun"}) do
			model:SetAttribute(attribute, nil)
		end
	end
end

function Engine:ResetFootballer(model: Model)
	self.Movement.State[model] = nil
	self.Movement.Executor:Clear(model)
	for _, side in ipairs({"Home", "Away"}) do
		self.CurrentAssignments[side][model] = nil
	end
	self.TeamBrain:ResetFootballer(model)
	for _, attribute in ipairs({"VTRAISprintRequested", "VTRReceiveTarget", "VTRPreparingReceive", "VTRReceiveUntil", "VTRReceiveRouteSprintRequested", "VTRAIAlternatePassChaser", "VTRPrepareToReceive", "VTRPotentialReceiveTarget", "VTRPrepareReceiveUntil", "AIMiddlePassMistakeMemory", "AITacticalSlot", "AIRestDefense", "TeamPlan", "TeamDefensiveIntent", "AIDefensiveDutyId", "AIDefensiveDuty", "AIIncomingPassDuty"}) do
		model:SetAttribute(attribute, nil)
	end
end

function Engine:Step(dt: number)
	local frameStart = os.clock()
	local live = self:_isLive()
	if not live then
		if self.WasLive then
			for _, side in ipairs({"Home", "Away"}) do
				for _, model in ipairs(self.Teams[side] or {}) do
					self.Movement.Executor:Clear(model)
				end
			end
			self.CurrentAssignments = {Home = {}, Away = {}}
			self.Movement:Clear()
			self.TeamBrain:Clear()
		end
		self.WasLive = false
		return
	end
	self.WasLive = true
	local context = self:_context()
	local possessionChanged = self.Memory:ObservePossession(context.OwnerSide, context.Owner, context.Now or os.clock())
	context.TeamStageResetUntil = self.Memory.StageResetUntil
	if possessionChanged and context.OwnerSide then
		for _, info in ipairs(context.Teams[context.OwnerSide].List) do
			info.Model:SetAttribute("AILastPasserRole", nil)
			info.Model:SetAttribute("AILastPasserName", nil)
			info.Model:SetAttribute("AILastPassReceivedAt", nil)
			info.Model:SetAttribute("AITeamOffenseStage", 1)
		end
	end
	self.LastContext = context
	self.Accum.Spatial += dt
	if self.Accum.Spatial >= .2 then
		local start = os.clock()
		self.Spatial:Update(context)
		self.Metrics.Cells = #self.Spatial.Cells
		self.Metrics:Sample("SpatialMs", os.clock() - start)
		self.Accum.Spatial = 0
	end
	self.Accum.Intent += dt
	if self.Accum.Intent >= .22 or not self.CurrentIntents.Home then
		local start = os.clock()
		self.CurrentIntents = self.Intent:Update(context, self.Styles, self.Spatial, self.Memory)
		self.Metrics:Sample("IntentMs", os.clock() - start)
		self.Accum.Intent = 0
	end
	self:_publishTeamContext(context)
	self.TeamBrain:Declare(context)
	local passStateKey = context.PassInFlight and (tostring(self.Ball:GetAttribute("VTRPassStartedAt") or "") .. ":" .. tostring(self.Ball:GetAttribute("VTRPassReceiver") or "") .. ":" .. tostring(self.Ball:GetAttribute("VTRTrajectoryId") or "")) or ""
	local urgent = context.LooseBall or context.PassInFlight or passStateKey ~= self.LastPassStateKey
	self.LastPassStateKey = passStateKey
	self.Accum.Structure += dt
	if urgent or self.Accum.Structure >= .24 or not next(self.CurrentAssignments.Home) then
		self.Accum.Structure = 0
		self:_buildAssignments(context)
		self:_publishTeamContext(context)
	end
	self.Accum.Carrier += dt
	if self.Accum.Carrier >= .09 then
		local start = os.clock()
		self.Accum.Carrier = 0
		self.TeamBrain:Step(context, self.CurrentAssignments)
		self.Metrics:Sample("CarrierMs", os.clock() - start)
	end
	self.Accum.Movement += dt
	if self.Accum.Movement >= .03 then
		self.Accum.Movement = 0
		for _, side in ipairs({"Home", "Away"}) do
			for model, assignment in pairs(self.CurrentAssignments[side]) do
				local info = context.Players[model]
				if info and assignment then
					self.Movement:Apply(info, assignment, context, dt)
				end
			end
		end
	end
	self.Movement:Step(dt)
	self.Accum.Debug += dt
	if self.Accum.Debug >= .33 then
		self.Accum.Debug = 0
		self.Debug:Update(context, self.CurrentAssignments)
		if debugEnabled() then
			workspace:SetAttribute("VTRTeamAIWorldMs", self.Metrics.WorldMs)
			workspace:SetAttribute("VTRTeamAISpatialMs", self.Metrics.SpatialMs)
			workspace:SetAttribute("VTRTeamAIIntentHome", self.CurrentIntents.Home and self.CurrentIntents.Home.Intent or "")
			workspace:SetAttribute("VTRTeamAIIntentAway", self.CurrentIntents.Away and self.CurrentIntents.Away.Intent or "")
		end
	end
	self.Metrics:Frame(os.clock() - frameStart)
end

function Engine:Destroy()
	self.Debug:Destroy()
	self.Movement:Clear()
	self.TeamBrain:Clear()
	self.Memory:Reset()
end

return Engine
