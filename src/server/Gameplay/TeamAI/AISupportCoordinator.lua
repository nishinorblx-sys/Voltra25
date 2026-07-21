--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)

local Coordinator = {}

local function laneName(pitch: Vector3): string
	if pitch.X < 130 then return "Left" end
	if pitch.X > 294 then return "Right" end
	return "Central"
end

local function clampTarget(target: Vector3): Vector3
	return PitchConfig.ClampInsidePitch(Vector3.new(target.X, 3, target.Z))
end

local function world(context: any, side: string, pitch: Vector3): Vector3
	return PitchConfig.TeamPitchPositionToWorld(clampTarget(pitch), side, context.Options)
end

local function occupiedLanes(assignments: any, exceptModel: Model?): {[string]: number}
	local lanes = {}
	for model, assignment in pairs(assignments) do
		if model ~= exceptModel and assignment.TacticalSlot and assignment.TacticalSlot.RestDefense ~= true and assignment.TargetPitch then
			local lane = laneName(assignment.TargetPitch)
			lanes[lane] = (lanes[lane] or 0) + 1
		end
	end
	return lanes
end

local function clearLaneTarget(context: any, side: string, assignments: any, model: Model, desired: Vector3): Vector3
	local lanes = occupiedLanes(assignments, model)
	local lane = laneName(desired)
	if (lanes[lane] or 0) >= 3 then
		local ball = context.BallTeam[side]
		if lane == "Left" then
			desired = Vector3.new(math.min(250, ball.X + 46), 3, desired.Z)
		elseif lane == "Right" then
			desired = Vector3.new(math.max(174, ball.X - 46), 3, desired.Z)
		else
			desired = Vector3.new(ball.X < PitchConfig.HALF_WIDTH and 282 or 142, 3, desired.Z)
		end
	end
	return clampTarget(desired)
end

local function carrierDribbleLane(context: any, side: string): (number, number)
	local owner = context.Owner
	if not owner or not context.Players or not context.Players[owner] then
		local ball = context.BallTeam[side]
		return ball.X - 22, ball.X + 22
	end
	local carrier = context.Players[owner]
	return carrier.Pitch.X - 26, carrier.Pitch.X + 26
end

local function avoidDribbleLane(context: any, side: string, target: Vector3): Vector3
	local left, right = carrierDribbleLane(context, side)
	if target.X > left and target.X < right and target.Z > context.BallTeam[side].Z + 10 then
		target = Vector3.new(target.X < PitchConfig.HALF_WIDTH and left - 16 or right + 16, 3, target.Z)
	end
	return clampTarget(target)
end

local function applySupport(context: any, side: string, assignments: any, model: Model, assignment: any, supportKind: string, pitchTarget: Vector3, urgency: number)
	local targetPitch = clearLaneTarget(context, side, assignments, model, avoidDribbleLane(context, side, pitchTarget))
	local targetWorld = world(context, side, targetPitch)
	assignment.PrimaryAssignment = supportKind
	assignment.TargetPitch = targetPitch
	assignment.TargetWorld = targetWorld
	assignment.MovementTarget = targetWorld
	assignment.MovementUrgency = math.max(assignment.MovementUrgency or .7, urgency)
	assignment.SprintAllowed = assignment.SprintAllowed or urgency >= .9
	assignment.SupportKind = supportKind
	if assignment.PlayerContract then
		assignment.PlayerContract.PreferredTarget = targetWorld
		assignment.PlayerContract.TargetRegion = {Center = targetPitch, Radius = 18, Lane = laneName(targetPitch), Line = assignment.TacticalSlot and assignment.TacticalSlot.Line or "Midfield"}
	end
	model:SetAttribute("SupportRole", supportKind)
	model:SetAttribute("VTRSupportTarget", targetWorld)
	model:SetAttribute("VTRSupportKind", supportKind)
end

function Coordinator.Apply(context: any, side: string, assignments: any, plan: any)
	local step = plan and plan.PlanStep
	local stepId = tostring(step and step.Id or "")
	local ball = context.BallTeam[side]
	local reaction = context.TeamReactions and context.TeamReactions[side] and context.TeamReactions[side].AgainstOpponentDefense
	local roleRules = context.RuleEffects and context.RuleEffects[side] and context.RuleEffects[side].Role
	local ballSide = ball.X < PitchConfig.HALF_WIDTH and -1 or 1
	for model, assignment in pairs(assignments) do
		local slot = assignment.TacticalSlot
		local contract = assignment.PlayerContract
		if contract then
			contract.PlanStep = step or contract.PlanStep
			contract.PassBias = step and step.PassBias or contract.PassBias
		end
		if not slot then
			continue
		end
		if slot.RestDefense == true then
			if contract then contract.ReplacementRequirement = contract.ReplacementRequirement or "HoldRestDefense" end
			model:SetAttribute("SupportRole", assignment.PrimaryAssignment)
			model:SetAttribute("TeamPlan", plan and plan.Intent or "")
			continue
		end
		if assignment.ReservedByUser == true then
			continue
		end
		if assignment.OffBallInstruction == "HoldPosition" then
			model:SetAttribute("AIInstructionEffect", "HoldPositionSkippedSupport")
			model:SetAttribute("AIInstructionRunAllowed", false)
			continue
		elseif assignment.OffBallInstruction == "SupportBall" then
			assignment.MovementUrgency = math.max(assignment.MovementUrgency or 0, .86)
		elseif assignment.OffBallInstruction == "AttackSpace" and (slot.Id == "ball-side-pivot" or slot.Id == "far-side-pivot") then
			continue
		end
		if roleRules and roleRules.SupportBehavior then
			model:SetAttribute("VTRSupportRule", roleRules.SupportBehavior)
		end
		if slot.Id == "ball-side-pivot" or slot.Id == "left-support" or slot.Id == "right-support" then
			local xOffset = slot.Id == "ball-side-pivot" and -ballSide * 34 or ballSide * 46
			local zOffset = (stepId == "triangle" or stepId == "wide-triangle") and 22 or -16
			if reaction and (tonumber(reaction.CloseEscapeSupport) or 0) > .1 then
				xOffset *= .72
				zOffset = -8
			end
			applySupport(context, side, assignments, model, assignment, "NearPassingTriangle", Vector3.new(ball.X + xOffset, 3, ball.Z + zOffset), .86)
		elseif slot.Id == "far-side-pivot" then
			applySupport(context, side, assignments, model, assignment, "BehindBallSafetyOption", Vector3.new(PitchConfig.HALF_WIDTH - ballSide * 54, 3, ball.Z - 28), .74)
		elseif slot.Id == "second-ball-midfielder" then
			local kind = stepId == "third-man-support" and "ThirdManPosition" or stepId == "cutback" and "BoxEdgeProtection" or "SecondBallSupport"
			applySupport(context, side, assignments, model, assignment, kind, Vector3.new(PitchConfig.HALF_WIDTH, 3, math.min(610, ball.Z + 52)), .82)
		elseif slot.Id == "between-lines-receiver" then
			applySupport(context, side, assignments, model, assignment, "BetweenLinesReceiver", Vector3.new(PitchConfig.HALF_WIDTH - ballSide * 28, 3, math.min(620, ball.Z + 82)), .86)
		elseif slot.Id == "far-side-switch" or slot.Id == "right-width" or slot.Id == "left-width" then
			local farSide = ball.X < PitchConfig.HALF_WIDTH and 364 or 60
			local sameSide = ball.X < PitchConfig.HALF_WIDTH and 56 or 368
			local targetX = (stepId == "switch-ready" or stepId == "far-side-switch" or slot.Id == "far-side-switch") and farSide or sameSide
			local kind = targetX == farSide and "FarSideSwitchOption" or "WidthHold"
			if reaction and (tonumber(reaction.SwitchPreference) or 0) > .12 then
				kind = "FarSideSwitchOption"
				targetX = farSide
			end
			applySupport(context, side, assignments, model, assignment, kind, Vector3.new(targetX, 3, math.min(690, ball.Z + 96)), .84)
		end
		model:SetAttribute("TeamPlan", plan and plan.Intent or "")
	end
end

return Coordinator
