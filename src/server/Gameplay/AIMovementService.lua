--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}
Service.__index = Service

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Service.new(executor: any)
	return setmetatable({Executor = executor, State = {}}, Service)
end

function Service:_state(model: Model, position: Vector3): any
	local state = self.State[model]
	if not state then
		state = {Target = position, LastPosition = position, LastMovedAt = os.clock(), LastAssignment = "", AssignmentChangedAt = 0, StuckSince = nil, Sidestep = 1}
		self.State[model] = state
	end
	return state
end

function Service:Apply(info: any, assignment: any, context: any, dt: number)
	if info.IsUserControlled or not info.Root then
		return
	end
	local model = info.Model
	local now = context.Now or os.clock()
	local state = self:_state(model, info.World)
	local assignmentName = assignment.PrimaryAssignment or "RecoverShape"
	if state.LastAssignment ~= assignmentName and now - (state.AssignmentChangedAt or 0) >= 0.5 then
		state.LastAssignment = assignmentName
		state.AssignmentChangedAt = now
		state.StuckSince = nil
		state.LastPosition = info.World
		state.LastMovedAt = now
	end

	local target = assignment.TargetWorld or info.World
	local targetDistance = PitchConfig.GetDistanceStuds(info.World, target)
	local closeHoldAssignment = assignmentName == "DefensiveRestBlock" or assignmentName == "PostPressShadow"
	if (target - state.Target).Magnitude >= 6 then
		state.Target = target
		state.StuckSince = nil
		state.LastPosition = info.World
		state.LastMovedAt = now
	elseif targetDistance < 4 then
		if closeHoldAssignment then
			state.Target = info.World
		else
			local teamForward = context.PitchCFrame.LookVector * (context.AttackSigns[info.Side] or 1)
			local laneSign = info.Pitch.X >= PitchConfig.HALF_WIDTH and 1 or -1
			state.Target = info.World + (teamForward + context.PitchCFrame.RightVector * laneSign * 0.18).Unit * 8
		end
	end

	local moved = PitchConfig.GetDistanceStuds(info.World, state.LastPosition)
	local urgentRun = assignmentName == "RunBehind" or assignmentName == "CounterSprint" or assignmentName == "WideOutlet" or assignmentName == "ExtraSupport" or (assignment.MovementUrgency or 0) >= 0.9
	if now - (state.LastMovedAt or now) >= (urgentRun and 0.45 or 0.75) then
		if targetDistance > (urgentRun and 5 or 8) and moved < (urgentRun and 0.85 or 1.5) then
			state.StuckSince = state.StuckSince or now
			state.Sidestep = -(state.Sidestep or 1)
			state.Target += context.PitchCFrame.RightVector * (urgentRun and 2.5 or 4) * state.Sidestep
		else
			state.StuckSince = nil
		end
		state.LastMovedAt = now
		state.LastPosition = info.World
	end

	local distance = PitchConfig.GetDistanceStuds(info.World, state.Target)
	local pressureAssignment = assignmentName == "PressBallCarrier" or assignmentName == "ContainBallCarrier" or assignmentName == "CloseLongCarryGap" or assignmentName == "TrackRunner" or assignmentName == "PrimaryPressRotation" or assignmentName == "CenterBackPressureStriker" or assignmentName == "FullbackPressureWinger" or assignmentName == "AggressiveCBPressStriker" or assignmentName == "AggressiveFullbackPressWinger" or assignmentName == "AggressiveMidfieldPress" or assignmentName == "AggressiveMidfieldCover" or assignmentName == "AggressiveCBStepOut" or assignmentName == "AggressiveFullbackStepOut" or assignmentName == "MidfielderPressureMidfielder" or assignmentName == "MidfielderPressureCover"
	local mode = "Jog"
	if pressureAssignment and distance <= 18 then
		mode = "Jockey"
	elseif distance > 22 and (assignment.SprintAllowed == true or (assignment.MovementUrgency or 0) >= 0.72) then
		mode = "Sprint"
	elseif distance < 8 then
		mode = "Walk"
	end
	local stamina = info.Stamina or 60
	local urgency = math.clamp(assignment.MovementUrgency or 0.72, 0.1, 1)
	if mode == "Sprint" and stamina < 30 and not pressureAssignment and not (assignmentName == "ChaseLooseBall" or assignmentName == "CounterSprint") then
		urgency = math.min(urgency, 0.62)
	end
	if assignmentName ~= "GoalkeeperPosition" then
		urgency = math.max(urgency, 0.74)
	end
	if urgentRun then
		urgency = math.max(urgency, 0.92)
	end
	if closeHoldAssignment and distance < 5 then
		urgency = math.min(urgency, 0.2)
		mode = "Idle"
	end

	model:SetAttribute("currentAssignment", assignmentName)
	model:SetAttribute("targetPosition", state.Target)
	model:SetAttribute("movementUrgency", urgency)
	model:SetAttribute("faceTarget", assignment.FaceWorld or context.BallWorld)
	model:SetAttribute("TacticalRole", info.Role)
	model:SetAttribute("TacticalZone", info.SpecificRole)
	model:SetAttribute("TeamPhase", assignment.Phase or "")
	model:SetAttribute("MovementTarget", state.Target)
	model:SetAttribute("Urgency", urgency)
	local pressTag = pressureAssignment and ((assignmentName == "CoverPresser" or assignmentName == "AggressiveMidfieldCover" or assignmentName == "MidfielderPressureCover") and "Secondary" or "Primary") or "Hold"
	model:SetAttribute("PressAssignment", pressTag)
	model:SetAttribute("SupportRole", assignmentName)
	model:SetAttribute("AttackAssignment", assignmentName)
	model:SetAttribute("MarkTarget", assignment.MarkTarget and assignment.MarkTarget.Name or "")
	model:SetAttribute("TargetDistance", distance)
	model:SetAttribute("MovementMode", mode)
	model:SetAttribute("AIStuck", state.StuckSince ~= nil)
	model:SetAttribute("AIStuckSeconds", state.StuckSince and now - state.StuckSince or 0)

	self.Executor:SetTarget(model, Vector3.new(state.Target.X, info.World.Y, state.Target.Z), urgency)
end

function Service:Step(dt: number)
	self.Executor:Step(dt)
end

function Service:Clear()
	table.clear(self.State)
end

return Service
