--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}
Service.__index = Service

local burstProfiles = {
	ReceivePass = {Maximum = 7, Cooldown = 0.08, Energy = 1, Essential = true},
	BallCarrierDecision = {Maximum = 2.4, Cooldown = 0.75, Energy = 12, Essential = true},
	DribbleSupport = {Maximum = 2.4, Cooldown = 0.85, Energy = 14, Essential = true},
	CarryForwardSpace = {Maximum = 2.8, Cooldown = 0.85, Energy = 14, Essential = true},
	TakeOnPressForward = {Maximum = 2.8, Cooldown = 0.75, Energy = 12, Essential = true},
	ForcedCarry = {Maximum = 2.2, Cooldown = 0.8, Energy = 14, Essential = true},
	WingerDiagonalGoalCarry = {Maximum = 2.8, Cooldown = 0.85, Energy = 14, Essential = true},
	WingerEndLineCarry = {Maximum = 2.8, Cooldown = 0.85, Energy = 14, Essential = true},
	RunBehind = {Maximum = 2.2, Cooldown = 3.5, Energy = 30},
	RiskOffsideRun = {Maximum = 2.2, Cooldown = 3.5, Energy = 30},
	RunBehindWide = {Maximum = 2.2, Cooldown = 3.5, Energy = 30},
	OverlapRun = {Maximum = 2.5, Cooldown = 5, Energy = 35},
	UnderlapRun = {Maximum = 2.2, Cooldown = 4.5, Energy = 35},
	CounterSprint = {Maximum = 3, Cooldown = 3, Energy = 25, Essential = true},
	ComeShortToEscapePressure = {Maximum = 2.4, Cooldown = 0.9, Energy = 14, Essential = true},
	ComeShort = {Maximum = 2.2, Cooldown = 1, Energy = 16},
	InsideTriangleSupport = {Maximum = 2.3, Cooldown = 0.95, Energy = 16},
	BallSidePivotSupport = {Maximum = 2.2, Cooldown = 0.95, Energy = 16},
	MidfieldSupport = {Maximum = 2.1, Cooldown = 1.05, Energy = 18},
	StorySecondBallSupport = {Maximum = 2.2, Cooldown = 1.05, Energy = 18},
	StoryRunBeyondOutlet = {Maximum = 2.6, Cooldown = 1, Energy = 16},
	StoryDirectOutlet = {Maximum = 2.6, Cooldown = 1, Energy = 16},
	StoryFullbackCommit = {Maximum = 2.5, Cooldown = 1.1, Energy = 18},
	StoryLateBoxRun = {Maximum = 2.4, Cooldown = 1.1, Energy = 18},
	StoryAttackBoxLane = {Maximum = 2.5, Cooldown = 1.1, Energy = 18},
	StoryCentralFinishRun = {Maximum = 2.4, Cooldown = 1.1, Energy = 18},
	PressBallCarrier = {Maximum = 1.8, Cooldown = 2.5, Energy = 28},
	PrimaryPressRotation = {Maximum = 1.8, Cooldown = 2.5, Energy = 28},
	AggressiveMidfieldPress = {Maximum = 1.8, Cooldown = 2.5, Energy = 28},
	RecoveryRun = {Maximum = 3, Cooldown = 1.5, Energy = 18, Essential = true},
	RecoverShape = {Maximum = 3, Cooldown = 1.5, Energy = 18, Essential = true},
	RunBackWithAttacker = {Maximum = 3, Cooldown = 1.5, Energy = 18, Essential = true},
	AttackLooseBall = {Maximum = 5, Cooldown = 0.18, Energy = 3, Essential = true},
	DangerZoneLooseBallRecovery = {Maximum = 5, Cooldown = 0.12, Energy = 2, Essential = true},
	ChaseLooseBall = {Maximum = 5, Cooldown = 0.2, Energy = 4, Essential = true},
	CoverLooseBall = {Maximum = 4, Cooldown = 0.25, Energy = 5, Essential = true},
	CompactPrimaryPresser = {Maximum = 2.2, Cooldown = 0.55, Energy = 12, Essential = true},
	CompactForwardLaneBlock = {Maximum = 2.1, Cooldown = 0.65, Energy = 10, Essential = true},
	CompactCoverBehindPresser = {Maximum = 2.1, Cooldown = 0.65, Energy = 10, Essential = true},
	CompactDirectPassAttackReceiver = {Maximum = 2.6, Cooldown = 0.5, Energy = 12, Essential = true},
	CompactDirectPassCoverBehind = {Maximum = 2.3, Cooldown = 0.6, Energy = 10, Essential = true},
	CompactSecondBallMidfielder = {Maximum = 2.2, Cooldown = 0.65, Energy = 10, Essential = true},
	ShotGoalkeeperClaim = {Maximum = 5, Cooldown = 0.15, Energy = 3, Essential = true},
	ShotEmergencyCenterBackCover = {Maximum = 2.8, Cooldown = 0.35, Energy = 10, Essential = true},
	ShotEmergencyFullbackCover = {Maximum = 2.7, Cooldown = 0.35, Energy = 10, Essential = true},
	ShotEmergencyMidfieldSecondBall = {Maximum = 2.7, Cooldown = 0.35, Energy = 10, Essential = true},
	ShotEmergencyWideRecovery = {Maximum = 2.6, Cooldown = 0.4, Energy = 10, Essential = true},
	ShotEmergencyFirstLineRecover = {Maximum = 2.5, Cooldown = 0.45, Energy = 10, Essential = true},
	AttackBox = {Maximum = 2, Cooldown = 4, Energy = 30},
	AttackBackPost = {Maximum = 2, Cooldown = 4, Energy = 30},
	ForwardMidfieldRun = {Maximum = 2, Cooldown = 4, Energy = 30},
}

local pressureAssignments = {
	ContainBallCarrier = true,
	CloseLongCarryGap = true,
	TrackRunner = true,
	CenterBackPressureStriker = true,
	FullbackPressureWinger = true,
	AggressiveCBPressStriker = true,
	AggressiveFullbackPressWinger = true,
	AggressiveMidfieldCover = true,
	AggressiveCBStepOut = true,
	AggressiveFullbackStepOut = true,
	MidfielderPressureMidfielder = true,
	MidfielderPressureCover = true,
	EarlyCBPressPassTarget = true,
	EarlyFullbackPressPassTarget = true,
	EarlyMidfielderPressPassTarget = true,
	EarlyMidfielderCoverPassTarget = true,
	EarlyClosePassTargetPressure = true,
	CompactPrimaryPresser = true,
	CompactForwardLaneBlock = true,
	CompactCoverBehindPresser = true,
	CompactDirectPassAttackReceiver = true,
	CompactDirectPassCoverBehind = true,
	CompactSecondBallMidfielder = true,
	ShotGoalkeeperClaim = true,
	ShotEmergencyCenterBackCover = true,
	ShotEmergencyFullbackCover = true,
	ShotEmergencyMidfieldSecondBall = true,
	ShotEmergencyWideRecovery = true,
	ShotEmergencyFirstLineRecover = true,
}

local ballPriorityAssignments = {
	ReceivePass = true,
	AttackLooseBall = true,
	DangerZoneLooseBallRecovery = true,
	ChaseLooseBall = true,
	CoverLooseBall = true,
	ShotGoalkeeperClaim = true,
}

local tacticalBurstProfile = {Maximum = 2.35, Cooldown = 0.95, Energy = 16}
local supportBurstProfile = {Maximum = 2.45, Cooldown = 0.9, Energy = 14, Essential = true}

local function rollingLobCutoffTarget(context: any, receiverWorld: Vector3): Vector3
	local ball = context.BallWorld
	local velocity = context.BallVelocity or Vector3.zero
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontal.Magnitude < 1.5 then
		return ball
	end
	local toReceiver = Vector3.new(receiverWorld.X - ball.X, 0, receiverWorld.Z - ball.Z)
	local movingPastReceiver = toReceiver.Magnitude > 0.05 and horizontal.Unit:Dot(toReceiver.Unit) > 0.15
	local lead = math.clamp(horizontal.Magnitude * (movingPastReceiver and 0.34 or 0.24), 8, 22)
	local target = ball + horizontal.Unit * lead
	return Vector3.new(target.X, receiverWorld.Y, target.Z)
end

local goalkeeperLockStates = {
	Tracking = true,
	Diving = true,
	Falling = true,
	Landing = true,
	Recovering = true,
	ReturnHome = true,
	HoldBall = true,
	Held = true,
	ClosingDown = true,
	CuttingPass = true,
	SweepLooseBall = true,
	SaveAttempt = true,
}

local goalkeeperPriorityAssignments = {
	ShotGoalkeeperClaim = true,
	ShotGoalkeeperSet = true,
	GoalkeeperPosition = true,
	CompactGoalkeeperBehindLine = true,
	GoalkeeperDistribution = true,
}

local function clearReceiveIntent(model: Model)
	model:SetAttribute("VTRPreparingReceive", nil)
	model:SetAttribute("VTRReceiveCommitted", nil)
	model:SetAttribute("VTRReceiveHardLock", nil)
	model:SetAttribute("VTRForcedPassReceiver", nil)
	model:SetAttribute("VTRAITargetedPass", nil)
	model:SetAttribute("VTRAIAlternatePassChaser", nil)
	model:SetAttribute("VTRForcedReceiveUntil", nil)
	model:SetAttribute("VTRReceiveHardLockUntil", nil)
end

local function goalkeeperPriorityActive(model: Model, assignment: any, now: number): boolean
	local state = tostring(model:GetAttribute("VTRGoalkeeperState") or model:GetAttribute("GKState") or "")
	return (tonumber(model:GetAttribute("VTRGoalkeeperActionLockUntil")) or 0) > now
		or model:GetAttribute("VTRGoalkeeperSaving") == true
		or model:GetAttribute("VTRKeeperDiveAnimationLocked") == true
		or model:GetAttribute("VTRGoalkeeperHolding") == true
		or model:GetAttribute("AIGoalkeeperLooseClaim") == true
		or goalkeeperLockStates[state] == true
		or goalkeeperPriorityAssignments[tostring(assignment and assignment.PrimaryAssignment or "")] == true
end

function Service.new(executor: any)
	return setmetatable({Executor = executor, State = {}}, Service)
end

function Service:_state(model: Model, position: Vector3): any
	local state = self.State[model]
	if not state then
		state = {Target = position, LastPosition = position, LastMovedAt = os.clock(), LastAssignment = "", AssignmentChangedAt = 0, MinimumHoldUntil = 0, StuckSince = nil, Sidestep = 1, Revision = 0, TargetCommittedUntil = 0}
		self.State[model] = state
	end
	return state
end

function Service:Apply(info: any, assignment: any, context: any, dt: number)
	if info.IsUserControlled or not info.Root then return end
	local model = info.Model
	local now = context.Now or os.clock()
	local receiveTarget = model:GetAttribute("VTRReceiveIntercept")
	if typeof(receiveTarget) ~= "Vector3" then
		receiveTarget = model:GetAttribute("VTRReceiveTarget")
	end
	local forcedUntil = tonumber(model:GetAttribute("VTRForcedReceiveUntil")) or 0
	local hardLockUntil = tonumber(model:GetAttribute("VTRReceiveHardLockUntil")) or 0
	local receiveUntil = math.max(tonumber(model:GetAttribute("VTRReceiveUntil")) or 0, forcedUntil, hardLockUntil)
	local forcedActive = model:GetAttribute("VTRForcedPassReceiver") == true or forcedUntil > now
	local hardLock = forcedActive or model:GetAttribute("VTRReceiveHardLock") == true or hardLockUntil > now or model:GetAttribute("VTRAITargetedPass") == true
	local keeperPriority = info.IsGoalkeeper and goalkeeperPriorityActive(model, assignment, now)
	if keeperPriority then
		clearReceiveIntent(model)
	end
	local namedPassReceiver = context.PassInFlight == true and typeof(context.PassTargetWorld) == "Vector3" and (context.PassReceiverName == model.Name or context.PassReceiverName == tostring(model:GetAttribute("DisplayName") or ""))
	if namedPassReceiver and typeof(receiveTarget) ~= "Vector3" then
		receiveTarget = context.PassTargetWorld
	end
	local receiveActive = not keeperPriority and typeof(receiveTarget) == "Vector3" and (namedPassReceiver or receiveUntil > now and (model:GetAttribute("VTRPreparingReceive") == true or hardLock or forcedActive))
	if receiveActive then
		local receiveFamily = tostring(model:GetAttribute("VTRReceivePassFamily") or model:GetAttribute("VTRPrePassFamily") or model:GetAttribute("AIDebugPassKind") or "")
		local lobbed = receiveFamily == "Lob" or receiveFamily == "Lofted" or receiveFamily == "ManualLobbed" or receiveFamily == "FarPostCross" or (context.Ball and context.Ball:GetAttribute("VTRLobPassActive") == true)
		local ballVelocity = context.BallVelocity or Vector3.zero
		local ballSpeed = Vector3.new(ballVelocity.X, 0, ballVelocity.Z).Magnitude
		if lobbed and hardLock and (context.Ball and context.Ball:GetAttribute("VTRLobLanded") == true or PitchConfig.GetDistanceStuds(context.BallWorld, receiveTarget) > 5.5 and ballSpeed > 1.5) then
			receiveTarget = rollingLobCutoffTarget(context, info.World)
			model:SetAttribute("VTRReceiveIntercept", receiveTarget)
			model:SetAttribute("VTRReceiveTarget", receiveTarget)
			model:SetAttribute("VTRReceiveMode", "CollectLobAfterBounce")
			model:SetAttribute("VTRLobCutoffLeadTarget", receiveTarget)
		end
		assignment = {PrimaryAssignment = "ReceivePass", TargetWorld = receiveTarget, FaceWorld = context.BallWorld, MovementUrgency = 1, SprintAllowed = true, Phase = "PassReception", SprintConservation = 0, ForcedReceiver = forcedActive or hardLock or namedPassReceiver, MovementProfile = "SprintBurst"}
	end
	local state = self:_state(model, info.World)
	local contract = assignment.PlayerContract
	if receiveActive then
		state.MinimumHoldUntil = 0
	elseif contract and tonumber(contract.MinimumHoldUntil) and (tonumber(contract.MinimumHoldUntil) or 0) > state.MinimumHoldUntil then
		state.MinimumHoldUntil = tonumber(contract.MinimumHoldUntil) or state.MinimumHoldUntil
	end
	local assignmentName = tostring(assignment.PrimaryAssignment or "RecoverShape")
	local proposedTarget = assignment.TargetWorld or info.World
	local targetShift = (proposedTarget - state.Target).Magnitude
	local emergency = ballPriorityAssignments[assignmentName] == true or assignmentName == "RecoveryRun" or assignment.Phase ~= model:GetAttribute("TeamPhase")
	local movementIQ = info.Stats and tonumber(info.Stats.movementIQ) or tonumber(model:GetAttribute("Reactions")) or 60
	local forcedReceiver = assignment.ForcedReceiver == true or model:GetAttribute("VTRForcedPassReceiver") == true
	local targetCommitSeconds = forcedReceiver and 0 or math.clamp(0.32 + (movementIQ - 55) * 0.006, 0.24, 0.62)
	if state.LastAssignment ~= assignmentName and (emergency or now >= state.MinimumHoldUntil) then
		state.LastAssignment = assignmentName
		state.AssignmentChangedAt = now
		state.MinimumHoldUntil = now + (burstProfiles[assignmentName] and 1.2 or 0.65)
		state.TargetCommittedUntil = now + targetCommitSeconds
		state.Revision += 1
		state.StuckSince = nil
		state.LastPosition = info.World
		state.LastMovedAt = now
	end
	if assignmentName == "ReceivePass" or emergency or targetShift >= 11 or now >= state.TargetCommittedUntil then
		state.Target = proposedTarget
		state.TargetCommittedUntil = now + targetCommitSeconds
		state.StuckSince = nil
	elseif targetShift >= 1 then
		state.Target = state.Target:Lerp(proposedTarget, math.clamp(dt * 4, 0, 1))
	end
	local distance = PitchConfig.GetDistanceStuds(info.World, state.Target)
	local moved = PitchConfig.GetDistanceStuds(info.World, state.LastPosition)
	local profileKey = assignment.DefensiveDuty == "PrimaryPresser" and "PressBallCarrier" or assignmentName
	local profile = burstProfiles[profileKey]
	local staminaEnergy = tonumber(info.Stamina) or tonumber(model:GetAttribute("VTRSprintEnergy")) or 100
	local hasBall = model:GetAttribute("VTRHasBall") == true or info.HasBall == true
	if hasBall and staminaEnergy > 50 and distance > 3 and (assignmentName == "BallCarrierDecision" or assignment.SprintAllowed == true or (assignment.MovementUrgency or 0) >= .82) then
		profile = profile or burstProfiles.BallCarrierDecision
		assignment.SprintAllowed = true
		assignment.SprintConservation = 0
		assignment.MovementProfile = "SprintBurst"
	end
	if not profile and assignment.SprintAllowed == true and context.OwnerSide == info.Side and distance > 7 and (assignment.MovementUrgency or 0) >= 0.72 then profile = supportBurstProfile end
	if not profile and assignment.SprintAllowed == true and distance > 9 and (assignment.MovementUrgency or 0) >= 0.72 then profile = tacticalBurstProfile end
	local urgent = profile ~= nil
	if now - state.LastMovedAt >= (urgent and 0.45 or 0.75) then
		if distance > (urgent and 5 or 8) and moved < (urgent and 0.85 or 1.5) then
			state.StuckSince = state.StuckSince or now
			state.Sidestep = -state.Sidestep
			state.Target += context.PitchCFrame.RightVector * (urgent and 2.5 or 4) * state.Sidestep
		else
			state.StuckSince = nil
		end
		state.LastMovedAt, state.LastPosition = now, info.World
	end
	local ballSpeed = (context.BallVelocity and Vector3.new(context.BallVelocity.X, 0, context.BallVelocity.Z).Magnitude) or 0
	local activeBallChase = ballPriorityAssignments[assignmentName] == true
	local mode = "Jog"
	if activeBallChase then
		mode = distance > 0.25 and "Run" or "Jog"
	elseif distance < 2.5 then
		mode = "Idle"
	elseif distance < 7 then
		mode = "Walk"
	elseif distance > 18 then
		mode = "Run"
	end
	local sprintAllowed = profile ~= nil and assignment.SprintAllowed == true and (activeBallChase and distance > 0.25 or forcedReceiver and distance > 0.75 or distance > 5)
	if activeBallChase and profile ~= nil and assignment.SprintAllowed == true and distance > 0.08 then sprintAllowed = true end
	if sprintAllowed then mode = "SprintBurst" end
	if pressureAssignments[assignmentName] and distance <= 6.5 and not activeBallChase then mode = "Run" end
	local conservation = math.clamp(tonumber(assignment.SprintConservation) or 50, 0, 100) / 100
	local maximum = profile and profile.Maximum or 0
	local cooldown = profile and profile.Cooldown or 0
	local minimumEnergy = profile and profile.Energy or 100
	if hasBall and profile then
		minimumEnergy = math.max(minimumEnergy, 50)
	end
	if profile and not profile.Essential then
		maximum *= 1 - conservation * 0.3
		cooldown *= 1 + conservation * 0.45
		minimumEnergy += conservation * 14
	end
	local urgency = math.clamp(assignment.MovementUrgency or 0.72, 0.1, 1)
	model:SetAttribute("currentAssignment", assignmentName)
	model:SetAttribute("targetPosition", state.Target)
	model:SetAttribute("movementUrgency", urgency)
	model:SetAttribute("faceTarget", assignment.FaceWorld or context.BallWorld)
	model:SetAttribute("TacticalRole", info.Role)
	model:SetAttribute("TacticalZone", info.SpecificRole)
	model:SetAttribute("TeamPhase", assignment.Phase or "")
	model:SetAttribute("MovementTarget", state.Target)
	model:SetAttribute("Urgency", urgency)
	model:SetAttribute("SupportRole", assignmentName)
	model:SetAttribute("DefensiveDuty", assignment.DefensiveDuty or "")
	model:SetAttribute("AttackAssignment", assignmentName)
	model:SetAttribute("MarkTarget", assignment.MarkTarget and assignment.MarkTarget.Name or "")
	model:SetAttribute("TargetDistance", distance)
	model:SetAttribute("MovementMode", mode)
	model:SetAttribute("VTRAIMovementIntensity", mode == "SprintBurst" and 1 or mode == "Run" and .72 or mode == "Jog" and .44 or mode == "Walk" and .22 or 0)
	model:SetAttribute("VTRAIIntentionUntil", state.TargetCommittedUntil)
	model:SetAttribute("AIStuck", state.StuckSince ~= nil)
	model:SetAttribute("AIStuckSeconds", state.StuckSince and now - state.StuckSince or 0)
	model:SetAttribute("VTRAIMovementProfile",assignment.MovementProfile or"Balanced")
	model:SetAttribute("VTRRunTicketId",assignment.RunTicketId)
	model:SetAttribute("VTRRunApproved",assignment.RunApproved==true)
	model:SetAttribute("VTRRunKind", assignment.RunKind)
	model:SetAttribute("VTRRunTarget", assignment.RunTarget)
	model:SetAttribute("VTRRunTrigger", assignment.RunTrigger)
	model:SetAttribute("VTRRunExpiry", assignment.RunExpiry)
	if contract then
		model:SetAttribute("AITeamContractSlot", contract.SlotId)
		model:SetAttribute("AITeamContractPlanStep", contract.PlanStep and contract.PlanStep.Id or "")
		model:SetAttribute("AITeamContractPassBias", contract.PlanStep and contract.PlanStep.PassBias or contract.PassBias or "")
		model:SetAttribute("AITeamContractAllowedActions", table.concat(contract.AllowedActions or {}, ","))
		model:SetAttribute("AITeamContractForbiddenActions", table.concat(contract.ForbiddenActions or {}, ","))
		model:SetAttribute("AITeamRunContract", contract.RunContract and contract.RunContract.Id or "")
		if contract.TargetRegion and typeof(contract.TargetRegion.Center) == "Vector3" then
			model:SetAttribute("AITeamContractRegionCenter", contract.TargetRegion.Center)
		end
	end
	self.Executor:SetCommand(model, {
		Target = Vector3.new(state.Target.X, info.World.Y, state.Target.Z),
		Urgency = urgency,
		LocomotionMode = mode,
		SprintAllowed = sprintAllowed,
		SprintRequired = mode == "SprintBurst",
		Essential = profile and profile.Essential == true or false,
		BurstMaximumSeconds = maximum,
		RecoveryMinimumSeconds = cooldown,
		MinimumEnergy = minimumEnergy,
		AssignmentId = assignmentName .. ":" .. tostring(state.Revision),
		RunTicketId = assignment.RunTicketId or (profile and assignmentName .. ":" .. tostring(state.Revision) or nil),
		FaceTarget = assignment.FaceWorld or context.BallWorld,
	})
end

function Service:Step(dt: number) self.Executor:Step(dt) end
function Service:Clear() table.clear(self.State) end

return Service
