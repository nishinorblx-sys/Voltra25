--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}
Service.__index = Service

local burstProfiles = {
	ReceivePass = {Maximum = 3, Cooldown = 0.8, Energy = 15, Essential = true},
	RunBehind = {Maximum = 2.2, Cooldown = 3.5, Energy = 30},
	RiskOffsideRun = {Maximum = 2.2, Cooldown = 3.5, Energy = 30},
	RunBehindWide = {Maximum = 2.2, Cooldown = 3.5, Energy = 30},
	OverlapRun = {Maximum = 2.5, Cooldown = 5, Energy = 35},
	UnderlapRun = {Maximum = 2.2, Cooldown = 4.5, Energy = 35},
	CounterSprint = {Maximum = 3, Cooldown = 3, Energy = 25, Essential = true},
	PressBallCarrier = {Maximum = 1.8, Cooldown = 2.5, Energy = 28},
	PrimaryPressRotation = {Maximum = 1.8, Cooldown = 2.5, Energy = 28},
	AggressiveMidfieldPress = {Maximum = 1.8, Cooldown = 2.5, Energy = 28},
	RecoveryRun = {Maximum = 3, Cooldown = 1.5, Energy = 18, Essential = true},
	RecoverShape = {Maximum = 3, Cooldown = 1.5, Energy = 18, Essential = true},
	RunBackWithAttacker = {Maximum = 3, Cooldown = 1.5, Energy = 18, Essential = true},
	ChaseLooseBall = {Maximum = 2.5, Cooldown = 1, Energy = 18, Essential = true},
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
}

local tacticalBurstProfile = {Maximum = 1.65, Cooldown = 1.25, Energy = 22}

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
	local receiveTarget = model:GetAttribute("VTRReceiveTarget")
	if model:GetAttribute("VTRPreparingReceive") == true and typeof(receiveTarget) == "Vector3" then
		assignment = {PrimaryAssignment = "ReceivePass", TargetWorld = receiveTarget, FaceWorld = context.BallWorld, MovementUrgency = 1, SprintAllowed = model:GetAttribute("VTRReceiveRouteSprintRequested") == true, Phase = "PassReception", SprintConservation = assignment.SprintConservation}
	end
	local now = context.Now or os.clock()
	local state = self:_state(model, info.World)
	local assignmentName = tostring(assignment.PrimaryAssignment or "RecoverShape")
	local proposedTarget = assignment.TargetWorld or info.World
	local targetShift = (proposedTarget - state.Target).Magnitude
	local emergency = assignmentName == "ReceivePass" or assignmentName == "ChaseLooseBall" or assignmentName == "RecoveryRun" or assignment.Phase ~= model:GetAttribute("TeamPhase")
	local movementIQ = info.Stats and tonumber(info.Stats.movementIQ) or tonumber(model:GetAttribute("Reactions")) or 60
	local targetCommitSeconds = math.clamp(0.32 + (movementIQ - 55) * 0.006, 0.24, 0.62)
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
	if not profile and assignment.SprintAllowed == true and distance > 11 and (assignment.MovementUrgency or 0) >= 0.76 then profile = tacticalBurstProfile end
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
	local mode = "Jog"
	if distance < 2.5 then mode = "Idle" elseif distance < 7 then mode = "Walk" elseif distance > 18 then mode = "Run" end
	local sprintAllowed = profile ~= nil and assignment.SprintAllowed == true and distance > 5
	if sprintAllowed then mode = "SprintBurst" end
	if pressureAssignments[assignmentName] and distance <= 6.5 then mode = "Run" end
	local conservation = math.clamp(tonumber(assignment.SprintConservation) or 50, 0, 100) / 100
	local maximum = profile and profile.Maximum or 0
	local cooldown = profile and profile.Cooldown or 0
	local minimumEnergy = profile and profile.Energy or 100
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
