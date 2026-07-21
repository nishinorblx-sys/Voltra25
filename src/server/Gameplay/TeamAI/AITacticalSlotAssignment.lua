--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)
local AITacticalContract = require(script.Parent.AITacticalContract)
local AIPlayerInstructionConfig = require(game:GetService("ReplicatedStorage").VTR.Shared.AIPlayerInstructionConfig)

local Solver = {}

local INF = 1e8

local function roleAllowed(info: any, slot: any): boolean
	if info.IsGoalkeeper then
		return slot.RoleFamily == "GK" or slot.Line == "Goalkeeper"
	end
	if slot.RoleFamily == "GK" or slot.Line == "Goalkeeper" then
		return false
	end
	return true
end

local function roleCost(info: any, slot: any): number
	if not roleAllowed(info, slot) then return INF end
	local preferred = {}
	for _, role in ipairs(slot.PreferredRoles or {}) do preferred[tostring(role)] = true end
	local allowed = {}
	for _, role in ipairs(slot.AllowedRoles or {}) do allowed[tostring(role)] = true end
	if preferred[info.Role] then return -34 end
	if allowed[info.Role] then return -18 end
	if slot.RoleFamily == "CB" and (info.Role == "Fullback" or info.Role == "CDM") then return -8 end
	if slot.RoleFamily == "Fullback" and (info.Role == "CB" or info.Role == "Winger") then return -4 end
	if slot.RoleFamily == "Wingback" and (info.Role == "Fullback" or info.Role == "Winger") then return -12 end
	if slot.RoleFamily == "CDM" and (info.Role == "CM" or info.Role == "CB") then return -8 end
	if slot.RoleFamily == "CM" and (info.Role == "CDM" or info.Role == "CAM") then return -10 end
	if slot.RoleFamily == "CAM" and (info.Role == "CM" or info.Role == "Winger" or info.Role == "ST") then return -6 end
	if slot.RoleFamily == "Winger" and (info.Role == "Fullback" or info.Role == "CAM") then return -6 end
	if slot.RoleFamily == "ST" and (info.Role == "Winger" or info.Role == "CAM") then return -8 end
	return 26
end

local function laneCost(info: any, slot: any): number
	local currentLane = tostring(info.Lane or PitchConfig.GetLane(info.Pitch))
	local slotLane = tostring(slot.Lane or PitchConfig.GetLane(slot.TargetPitch))
	if currentLane == slotLane then return -6 end
	if (currentLane == "LeftWide" or currentLane == "LeftHalfSpace" or currentLane == "Left") and (slotLane == "LeftWide" or slotLane == "LeftHalfSpace" or slotLane == "Left") then return -3 end
	if (currentLane == "RightWide" or currentLane == "RightHalfSpace" or currentLane == "Right") and (slotLane == "RightWide" or slotLane == "RightHalfSpace" or slotLane == "Right") then return -3 end
	return slotLane == "Central" and 3 or 9
end

local function previousSlotId(context: any, side: string, model: Model): string
	local previous = context.PreviousAssignments and context.PreviousAssignments[side] and context.PreviousAssignments[side][model]
	return tostring(previous and previous.TacticalSlot and previous.TacticalSlot.ContinuityKey or previous and previous.PrimaryAssignment or model:GetAttribute("AITacticalSlot") or "")
end

local function assignmentCost(context: any, side: string, info: any, slot: any, playerOrder: number, slotOrder: number): number
	if not roleAllowed(info, slot) then return INF end
	if slot.LockedModel and slot.LockedModel ~= info.Model then return INF end
	local distance = PitchConfig.GetDistanceStuds(info.Pitch, slot.TargetPitch)
	local stamina = math.clamp(tonumber(info.Stamina) or tonumber(info.Model:GetAttribute("VTRSprintEnergy")) or 75, 0, 100)
	local cost = distance
	cost += roleCost(info, slot)
	cost += laneCost(info, slot)
	cost -= stamina * (slot.SprintAllowed and .055 or .025)
	if slot.RestDefense and (info.Role == "CB" or info.Role == "Fullback" or info.Role == "CDM") then
		cost -= 16
	end
	if context.OwnerSide == side then
		if info.OffBallInstruction == "HoldPosition" then
			cost += PitchConfig.GetDistanceStuds(info.BasePitch, slot.TargetPitch) > 18 and 55 or -12
			if slot.SprintAllowed then cost += 28 end
		elseif info.OffBallInstruction == "SupportBall" and (slot.Id == "ball-side-pivot" or slot.Id == "left-support" or slot.Id == "right-support" or slot.Id == "between-lines-receiver") then
			cost -= 34
		elseif info.OffBallInstruction == "AttackSpace" and (slot.Line == "Forward" or slot.Id == "left-width" or slot.Id == "right-width" or slot.Id == "central-forward" or slot.Id == "second-ball-midfielder") then
			cost -= 34
		end
	else
		if info.DefensiveInstruction == "HoldShape" and slot.SprintAllowed then cost += 36 end
		if info.DefensiveInstruction == "HuntBall" and slot.SprintAllowed then cost -= 34 end
	end
	if info.IsUserControlled then
		cost -= 10
	end
	local previousKey = previousSlotId(context, side, info.Model)
	if previousKey ~= "" then
		if previousKey == tostring(slot.ContinuityKey or slot.Id) or previousKey == tostring(slot.Id) then
			cost -= 36
		else
			cost += 15
		end
	end
	if (tonumber(info.Model:GetAttribute("AITacticalHoldUntil")) or 0) > (context.Now or os.clock()) and previousKey ~= "" and previousKey ~= tostring(slot.ContinuityKey or slot.Id) then
		cost += 34
	end
	return cost + playerOrder * .001 + slotOrder * .0001
end

local function solve(costs: {{number}}, playersCount: number, slotsCount: number): {number}
	local memo: {[number]: {Cost: number, Picks: {number}}} = {}
	local function dp(playerIndex: number, mask: number): {Cost: number, Picks: {number}}
		if playerIndex > playersCount then
			return {Cost = 0, Picks = {}}
		end
		local key = playerIndex * 4096 + mask
		local cached = memo[key]
		if cached then return cached end
		local bestCost = INF
		local bestPicks = {}
		for slotIndex = 1, slotsCount do
			local bit = bit32.lshift(1, slotIndex - 1)
			if bit32.band(mask, bit) == 0 then
				local cost = costs[playerIndex][slotIndex]
				if cost < INF then
					local child = dp(playerIndex + 1, bit32.bor(mask, bit))
					local total = cost + child.Cost
					if total < bestCost then
						bestCost = total
						bestPicks = table.clone(child.Picks)
						table.insert(bestPicks, 1, slotIndex)
					end
				end
			end
		end
		local result = {Cost = bestCost, Picks = bestPicks}
		memo[key] = result
		return result
	end
	return dp(1, 0).Picks
end

local function createAssignment(context: any, side: string, info: any, slot: any, targetWorld: Vector3, planStep: any): any
	local forbiddenActions = table.clone(slot.ForbiddenActions or {})
	local allowedActions = table.clone(slot.AllowedActions or {})
	local roleRules = context.RuleEffects and context.RuleEffects[side] and context.RuleEffects[side].Role
	if roleRules and roleRules.AllowedActions then
		for action in pairs(roleRules.AllowedActions) do table.insert(allowedActions, action) end
	end
	if roleRules and roleRules.ForbiddenActions then
		for action in pairs(roleRules.ForbiddenActions) do table.insert(forbiddenActions, action) end
	end
	if slot.RestDefense == true then
		for _, action in ipairs({"Shoot", "Dribble", "RiskDribble", "BoxRun", "CarryForward"}) do
			table.insert(forbiddenActions, action)
		end
	end
	local now = context.Now or os.clock()
	local playerContract = AITacticalContract.Player({
		SlotId = slot.Id,
		TargetRegion = slot.TargetRegion,
		PreferredTarget = targetWorld,
		AllowedActions = allowedActions,
		ForbiddenActions = forbiddenActions,
		PlanStep = planStep,
		CoverTarget = slot.CoverRequirement,
		MinimumHoldUntil = now + math.max(.45, planStep and tonumber(planStep.MinimumHold) or .2),
		AbortConditions = slot.RestDefense and {"BallBehindLine", "MarkedRunnerFree"} or {"PlanExpired", "ReceiverClosed"},
		ReplacementRequirement = slot.RestDefense and "MustStayGoalSide" or nil,
	})
	return {
		Model = info.Model,
		Info = info,
		Role = info.Role,
		Phase = context.OwnerSide == side and "TeamPossession" or "TeamDefense",
		PrimaryAssignment = slot.Id,
		MovementTarget = targetWorld,
		TargetWorld = targetWorld,
		TargetPitch = slot.TargetPitch,
		MovementUrgency = slot.SprintAllowed and .94 or .72,
		SprintAllowed = slot.SprintAllowed,
		FaceWorld = context.BallWorld,
		SupportTarget = context.Owner,
		TacticalSlot = slot,
		PlayerContract = playerContract,
		AllowedActions = playerContract.AllowedActions,
		ForbiddenActions = playerContract.ForbiddenActions,
		PlanStep = planStep,
		MinimumHoldUntil = playerContract.MinimumHoldUntil,
		ReservedByUser = info.IsUserControlled == true,
		OffBallInstruction = AIPlayerInstructionConfig.Normalize({OffBall=info.OffBallInstruction,Defending=info.DefensiveInstruction},info.SpecificRole).OffBall,
		DefensiveInstruction = AIPlayerInstructionConfig.Normalize({OffBall=info.OffBallInstruction,Defending=info.DefensiveInstruction},info.SpecificRole).Defending,
		InstructionEffect = "",
	}
end

local function exposeUserGaps(context: any, side: string, assignments: any)
	for model, assignment in pairs(assignments) do
		if assignment.ReservedByUser and assignment.TacticalSlot and assignment.TacticalSlot.TargetRegion then
			local info = context.Players[model]
			local radius = tonumber(assignment.TacticalSlot.TargetRegion.Radius) or 18
			local distance = info and PitchConfig.GetDistanceStuds(info.Pitch, assignment.TacticalSlot.TargetPitch) or 0
			local gap = distance > radius * 1.65
			model:SetAttribute("AITacticalCoverageGap", gap)
			if gap then
				local bestModel = nil
				local bestDistance = math.huge
				for otherModel, otherAssignment in pairs(assignments) do
					local otherInfo = context.Players[otherModel]
					if otherModel ~= model and otherInfo and not otherInfo.IsUserControlled and otherAssignment.TacticalSlot and otherAssignment.TacticalSlot.Id ~= assignment.TacticalSlot.Id then
						local d = PitchConfig.GetDistanceStuds(otherInfo.Pitch, assignment.TacticalSlot.TargetPitch)
						if d < bestDistance then
							bestModel = otherModel
							bestDistance = d
						end
					end
				end
				if bestModel and assignments[bestModel] then
					assignments[bestModel].CompensatesUserSlot = assignment.TacticalSlot.Id
					assignments[bestModel].PlayerContract.CoverTarget = assignment.TacticalSlot.Id
					bestModel:SetAttribute("AICompensatesUserSlot", assignment.TacticalSlot.Id)
				end
			end
		end
	end
end

function Solver.Assign(context: any, side: string, slots: {any}): any
	local assignments = {}
	local players = {}
	for _, info in ipairs(context.Teams[side].List) do
		if info.Root then
			table.insert(players, info)
		end
	end
	table.sort(players, function(a, b)
		return (tonumber(a.Index) or 0) < (tonumber(b.Index) or 0)
	end)
	local normalizedSlots = {}
	for _, rawSlot in ipairs(slots) do
		table.insert(normalizedSlots, AITacticalContract.Slot(rawSlot))
	end
	table.sort(normalizedSlots, function(a, b)
		local aKey = tostring(a.ContinuityKey or a.Id)
		local bKey = tostring(b.ContinuityKey or b.Id)
		if aKey == bKey then return tostring(a.Id) < tostring(b.Id) end
		return aKey < bKey
	end)
	local count = math.min(#players, #normalizedSlots)
	if count == 0 then
		return assignments
	end
	while #players > count do table.remove(players) end
	while #normalizedSlots > count do table.remove(normalizedSlots) end
	local costs = {}
	for playerIndex, info in ipairs(players) do
		costs[playerIndex] = {}
		for slotIndex, slot in ipairs(normalizedSlots) do
			costs[playerIndex][slotIndex] = assignmentCost(context, side, info, slot, playerIndex, slotIndex)
		end
	end
	local picks = solve(costs, #players, #normalizedSlots)
	local plan = context.TeamPlans and context.TeamPlans[side]
	local planStep = plan and plan.PlanStep
	for playerIndex, slotIndex in ipairs(picks) do
		local info = players[playerIndex]
		local slot = normalizedSlots[slotIndex]
		if info and slot then
			local targetWorld = PitchConfig.TeamPitchPositionToWorld(slot.TargetPitch, side, context.Options)
			local assignment = createAssignment(context, side, info, slot, targetWorld, planStep)
			assignments[info.Model] = assignment
			local now = context.Now or os.clock()
			info.Model:SetAttribute("AITacticalSlot", slot.Id)
			info.Model:SetAttribute("AITacticalFunction", slot.Function)
			info.Model:SetAttribute("AITacticalHoldUntil", now + .85)
			info.Model:SetAttribute("AIRestDefense", slot.RestDefense)
			info.Model:SetAttribute("AITeamContractSlot", assignment.PlayerContract.SlotId)
			info.Model:SetAttribute("AITeamContractActions", table.concat(assignment.PlayerContract.AllowedActions, ","))
			info.Model:SetAttribute("AITeamContractPlanStep", planStep and planStep.Id or "")
			info.Model:SetAttribute("AITeamContractPassBias", planStep and planStep.PassBias or "")
			info.Model:SetAttribute("AITacticalReservedByUser", info.IsUserControlled == true)
		end
	end
	exposeUserGaps(context, side, assignments)
	return assignments
end

return Solver
