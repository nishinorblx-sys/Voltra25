--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)
local AITacticalContract = require(script.Parent.AITacticalContract)

local Coordinator = {}

local RUN_BY_REQUEST: {[string]: string} = {
	["central-forward"] = "RunBehind",
	["left-width"] = "RunBehind",
	["right-width"] = "RunBehind",
	["checking-striker"] = "CheckingRun",
	["overlap"] = "Overlap",
	["underlap"] = "Underlap",
	["third-man"] = "ThirdManRun",
	["second-ball-midfielder"] = "ThirdManRun",
	["counter-lane"] = "CounterLane",
	["second-wave"] = "SecondWaveRun",
	["near-post"] = "NearPostRun",
	["far-post"] = "FarPostRun",
	["cutback-arrival"] = "CutbackArrival",
	["recovery"] = "RecoveryRun",
}

local function laneFor(target: Vector3): string
	if target.X < 145 then return "Left" end
	if target.X > 279 then return "Right" end
	return "Central"
end

local function requested(step: any, slot: any): (boolean, string?)
	if not step then return false, nil end
	for _, request in ipairs(step.RunRequests or {}) do
		local text = tostring(request)
		if text == slot.Id or text == slot.Function then
			return true, RUN_BY_REQUEST[text] or RUN_BY_REQUEST[slot.Id] or "RunBehind"
		end
		if text == "overlap" and (slot.Id == "left-width" or slot.Id == "right-width" or slot.Id == "left-wingback" or slot.Id == "right-wingback") then return true, "Overlap" end
		if text == "underlap" and (slot.Id == "left-width" or slot.Id == "right-width" or slot.Id == "between-lines-receiver") then return true, "Underlap" end
		if text == "third-man" and (slot.Id == "second-ball-midfielder" or slot.Id == "between-lines-receiver") then return true, "ThirdManRun" end
		if text == "counter-lane" and (slot.Id == "left-width" or slot.Id == "right-width" or slot.Id == "central-forward") then return true, "CounterLane" end
		if text == "second-wave" and (slot.Id == "second-ball-midfielder" or slot.Id == "ball-side-pivot" or slot.Id == "far-side-pivot") then return true, "SecondWaveRun" end
		if text == "near-post" and slot.Id == "central-forward" then return true, "NearPostRun" end
		if text == "far-post" and (slot.Id == "left-width" or slot.Id == "right-width") then return true, "FarPostRun" end
		if text == "cutback-arrival" and slot.Id == "second-ball-midfielder" then return true, "CutbackArrival" end
	end
	return false, nil
end

local function likelyPasserHasLane(context: any, side: string, assignment: any): boolean
	local owner = context.Owner
	if not owner or context.OwnerSide ~= side or not context.Players or not context.Players[owner] then
		return false
	end
	local carrier = context.Players[owner]
	local targetWorld = assignment.TargetWorld or carrier.World
	local clear = true
	for _, opponent in ipairs(context.Teams[carrier.OpponentSide].List) do
		if opponent.Root then
			local ap = Vector3.new(opponent.World.X - carrier.World.X, 0, opponent.World.Z - carrier.World.Z)
			local ab = Vector3.new(targetWorld.X - carrier.World.X, 0, targetWorld.Z - carrier.World.Z)
			local lengthSquared = ab:Dot(ab)
			if lengthSquared > .01 then
				local t = math.clamp(ap:Dot(ab) / lengthSquared, 0, 1)
				local closest = Vector3.new(carrier.World.X, 0, carrier.World.Z) + ab * t
				local distance = (Vector3.new(opponent.World.X, 0, opponent.World.Z) - closest).Magnitude
				if t > .08 and t < .95 and distance < 10 then
					clear = false
					break
				end
			end
		end
	end
	return clear
end

local function restDefenseCount(assignments: any, excludingModel: Model?): number
	local count = 0
	for model, assignment in pairs(assignments) do
		if model ~= excludingModel and assignment.TacticalSlot and assignment.TacticalSlot.RestDefense == true then
			count += 1
		end
	end
	return count
end

local function requiredRest(context: any, side: string): number
	local teamBrain = context.TeamBrain and context.TeamBrain[side]
	local reaction = context.TeamReactions and context.TeamReactions[side] and context.TeamReactions[side].AgainstOpponentAttack
	local positioningRules = context.RuleEffects and context.RuleEffects[side] and context.RuleEffects[side].Positioning
	local extra = (tonumber(reaction and reaction.RestDefense) or 0) * 2
	extra += tonumber(positioningRules and positioningRules.RestDefense) or 0
	return math.max(1, math.min(4, (tonumber(teamBrain and teamBrain.RestDefense) or 2) + extra))
end

local function protectsRestDefense(context: any, side: string, assignments: any, model: Model, assignment: any): boolean
	if assignment.TacticalSlot and assignment.TacticalSlot.RestDefense == true then
		return false
	end
	local remaining = restDefenseCount(assignments, model)
	if remaining < requiredRest(context, side) then
		return false
	end
	local hasCentral = false
	for otherModel, other in pairs(assignments) do
		if otherModel ~= model and other.TacticalSlot and other.TacticalSlot.RestDefense == true and other.TargetPitch then
			if laneFor(other.TargetPitch) == "Central" then
				hasCentral = true
			end
		end
	end
	return hasCentral
end

local function onlyCentralScreen(assignments: any, model: Model, assignment: any): boolean
	local slot = assignment.TacticalSlot
	if not slot or not (slot.Id == "ball-side-pivot" or slot.Id == "far-side-pivot") then
		return false
	end
	local centralScreens = 0
	for otherModel, other in pairs(assignments) do
		local otherSlot = other.TacticalSlot
		if otherModel ~= model and otherSlot and (otherSlot.RestDefense == true or otherSlot.Id == "ball-side-pivot" or otherSlot.Id == "far-side-pivot") and other.TargetPitch and laneFor(other.TargetPitch) == "Central" then
			centralScreens += 1
		end
	end
	return centralScreens <= 0
end

local function targetForRun(context: any, side: string, assignment: any, runKind: string): Vector3
	local slot = assignment.TacticalSlot
	local base = slot and slot.TargetPitch or assignment.TargetPitch or context.BallTeam[side]
	if runKind == "CheckingRun" then
		return PitchConfig.ClampInsidePitch(Vector3.new(base.X, 3, math.max(95, context.BallTeam[side].Z + 24)))
	elseif runKind == "Overlap" then
		local x = base.X < PitchConfig.HALF_WIDTH and 36 or 388
		return PitchConfig.ClampInsidePitch(Vector3.new(x, 3, math.min(690, context.BallTeam[side].Z + 118)))
	elseif runKind == "Underlap" then
		local x = base.X < PitchConfig.HALF_WIDTH and 158 or 266
		return PitchConfig.ClampInsidePitch(Vector3.new(x, 3, math.min(675, context.BallTeam[side].Z + 104)))
	elseif runKind == "ThirdManRun" then
		return PitchConfig.ClampInsidePitch(Vector3.new(PitchConfig.HALF_WIDTH, 3, math.min(650, context.BallTeam[side].Z + 94)))
	elseif runKind == "CounterLane" then
		return PitchConfig.ClampInsidePitch(Vector3.new(base.X < PitchConfig.HALF_WIDTH and 118 or 306, 3, math.min(700, context.BallTeam[side].Z + 168)))
	elseif runKind == "SecondWaveRun" then
		return PitchConfig.ClampInsidePitch(Vector3.new(PitchConfig.HALF_WIDTH, 3, math.min(620, context.BallTeam[side].Z + 76)))
	elseif runKind == "NearPostRun" then
		return PitchConfig.ClampInsidePitch(Vector3.new(context.BallTeam[side].X < PitchConfig.HALF_WIDTH and 178 or 246, 3, 682))
	elseif runKind == "FarPostRun" then
		return PitchConfig.ClampInsidePitch(Vector3.new(context.BallTeam[side].X < PitchConfig.HALF_WIDTH and 288 or 136, 3, 682))
	elseif runKind == "CutbackArrival" then
		return PitchConfig.ClampInsidePitch(Vector3.new(PitchConfig.HALF_WIDTH, 3, 598))
	elseif runKind == "RecoveryRun" then
		return PitchConfig.ClampInsidePitch(Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(70, context.BallTeam[side].Z - 110)))
	end
	return PitchConfig.ClampInsidePitch(Vector3.new(base.X, 3, math.min(700, base.Z + 64)))
end

local function canLayer(planStep: any): boolean
	local id = tostring(planStep and planStep.Id or "")
	return id == "box-occupation" or id == "cutback" or id == "finish"
end

local function finalThirdTrigger(context: any, side: string, planStep: any): boolean
	local id = tostring(planStep and planStep.Id or "")
	return context.BallTeam[side].Z >= 520 or id == "cutback" or id == "entry" or id == "box-occupation"
end

local function clearRun(model: Model, assignment: any)
	assignment.RunApproved = false
	assignment.RunTicketId = nil
	assignment.RunKind = nil
	assignment.RunTarget = nil
	assignment.RunTrigger = nil
	assignment.RunExpiry = nil
	model:SetAttribute("VTRRunApproved", false)
	model:SetAttribute("VTRRunTicketId", nil)
	model:SetAttribute("VTRRunKind", nil)
end

function Coordinator.Apply(context: any, side: string, assignments: any, plan: any, style: any)
	local planStep = plan and plan.PlanStep
	local budget = math.clamp(math.floor(1 + (style and style:Ratio("RunsInBehind") or .5) * 3), 1, 4)
	local teamBrain = context.TeamBrain and context.TeamBrain[side]
	if teamBrain then
		budget = math.clamp(math.floor(tonumber(teamBrain.AttackingRunners) or budget), 1, 5)
	end
	local attackReaction = context.TeamReactions and context.TeamReactions[side] and context.TeamReactions[side].AgainstOpponentAttack
	local roleRules = context.RuleEffects and context.RuleEffects[side] and context.RuleEffects[side].Role
	if attackReaction then
		budget = math.max(1, math.floor(budget + (tonumber(attackReaction.AttackingCommitment) or 0) * 2 + (tonumber(attackReaction.FullbackAdvance) or 0) * 2))
	end
	local used = 0
	local usedLanes: {[string]: boolean} = {}
	for model, assignment in pairs(assignments) do
		clearRun(model, assignment)
		local slot = assignment.TacticalSlot
		if not slot then
			continue
		end
		if slot.RestDefense == true then
			if assignment.PlayerContract then assignment.PlayerContract.ReplacementRequirement = assignment.PlayerContract.ReplacementRequirement or "HoldRestDefense" end
			continue
		end
		if assignment.ReservedByUser == true then
			continue
		end
		local isRequested, runKind = requested(planStep, slot)
		if assignment.OffBallInstruction == "HoldPosition" then
			if assignment.PlayerContract then assignment.PlayerContract.ReplacementRequirement = "InstructionHoldPosition" end
			model:SetAttribute("AIInstructionRunAllowed", false)
			continue
		elseif assignment.OffBallInstruction == "SupportBall" and runKind == "RunBehind" then
			model:SetAttribute("AIInstructionRunAllowed", false)
			continue
		elseif assignment.OffBallInstruction == "AttackSpace" and not isRequested then
			if slot.Id == "left-width" or slot.Id == "right-width" or slot.Id == "central-forward" then
				isRequested = true;runKind = "RunBehind"
			elseif slot.Id == "left-wingback" or slot.Id == "right-wingback" then
				isRequested = true;runKind = "Overlap"
			elseif slot.Id == "second-ball-midfielder" or slot.Id == "between-lines-receiver" then
				isRequested = true;runKind = "ThirdManRun"
			end
		end
		if roleRules and roleRules.RunTypes and next(roleRules.RunTypes) and runKind and roleRules.RunTypes[runKind] ~= true then
			isRequested = false
		end
		if not isRequested or not runKind then
			continue
		end
		if (slot.Id == "left-width" or slot.Id == "right-width" or slot.Id == "far-side-switch") and (runKind == "NearPostRun" or runKind == "FarPostRun" or runKind == "CutbackArrival") and not finalThirdTrigger(context, side, planStep) then
			continue
		end
		local access = likelyPasserHasLane(context, side, assignment)
		if not access and tostring(planStep and planStep.PassBias or "") ~= "Commit" and tostring(planStep and planStep.PassBias or "") ~= "ForwardEarly" then
			continue
		end
		if not protectsRestDefense(context, side, assignments, model, assignment) then
			if assignment.PlayerContract then assignment.PlayerContract.ReplacementRequirement = "RejectedRestDefenseBreak" end
			continue
		end
		if onlyCentralScreen(assignments, model, assignment) then
			if assignment.PlayerContract then assignment.PlayerContract.ReplacementRequirement = "OnlyCentralScreenProtected" end
			continue
		end
		local targetPitch = targetForRun(context, side, assignment, runKind)
		local lane = laneFor(targetPitch)
		if usedLanes[lane] and not canLayer(planStep) then
			continue
		end
		if used >= budget then
			continue
		end
		used += 1
		usedLanes[lane] = true
		local now = context.Now or os.clock()
		local runContract = AITacticalContract.Run({
			Id = tostring(plan and plan.Intent or "Run") .. ":" .. tostring(planStep and planStep.Id or "step") .. ":" .. slot.Id,
			Kind = runKind,
			Runner = model,
			TargetRegion = AITacticalContract.Region(targetPitch, 18, lane, slot.Line),
			Trigger = planStep and planStep.Id or plan and plan.Intent or "TeamPlan",
			StartTime = now,
			Expiry = now + ((runKind == "Overlap" or runKind == "Underlap") and 3.2 or 2.6),
			CancelConditions = {"PassPlayedElsewhere", "OffsideRisk", "RestDefenseBroken", "LaneBlocked"},
			VacatedSlot = slot.Id,
			ReplacementSlot = "rest-defense",
		})
		runContract.OffsideConstraint = runKind == "RunBehind" or runKind == "CounterLane"
		assignment.SprintAllowed = true
		assignment.MovementUrgency = math.max(assignment.MovementUrgency or .7, .96)
		assignment.TargetPitch = targetPitch
		assignment.TargetWorld = PitchConfig.TeamPitchPositionToWorld(targetPitch, side, context.Options)
		assignment.MovementTarget = assignment.TargetWorld
		assignment.RunContract = runContract
		assignment.RunApproved = true
		assignment.RunTicketId = runContract.Id
		assignment.RunKind = runContract.Kind
		assignment.RunTarget = targetPitch
		assignment.RunTrigger = runContract.Trigger
		assignment.RunExpiry = runContract.Expiry
		assignment.InstructionEffect = assignment.OffBallInstruction == "AttackSpace" and "AttackSpaceRun" or assignment.InstructionEffect
		assignment.InstructionRunAllowed = true
		if assignment.PlayerContract then
			assignment.PlayerContract.RunContract = runContract
			assignment.PlayerContract.ReplacementRequirement = "RestDefenseCoverage"
		end
		model:SetAttribute("VTRRunApproved", true)
		model:SetAttribute("VTRRunTicketId", runContract.Id)
		model:SetAttribute("VTRRunKind", runContract.Kind)
		model:SetAttribute("VTRRunTrigger", tostring(runContract.Trigger))
		model:SetAttribute("VTRRunExpiry", runContract.Expiry)
	end
end

return Coordinator
