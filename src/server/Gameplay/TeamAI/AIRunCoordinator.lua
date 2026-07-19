--!strict

local Coordinator = {}

function Coordinator.Apply(context: any, side: string, assignments: any, plan: any, style: any)
	local budget = math.clamp(math.floor(1 + (style and style:Ratio("RunsInBehind") or .5) * 3), 1, 4)
	local teamBrain = context.TeamBrain and context.TeamBrain[side]
	if teamBrain then
		budget = math.clamp(math.floor(tonumber(teamBrain.AttackingRunners) or budget), 1, 5)
	end
	local used = 0
	for model, assignment in pairs(assignments) do
		local slot = assignment.TacticalSlot
		local runner = slot and (slot.Id == "central-forward" or slot.Id == "left-width" or slot.Id == "right-width")
		if runner and used < budget then
			used += 1
			assignment.SprintAllowed = true
			assignment.MovementUrgency = math.max(assignment.MovementUrgency or .7, .96)
			model:SetAttribute("VTRRunApproved", true)
			model:SetAttribute("VTRRunTicketId", tostring(plan and plan.Intent or "Run") .. ":" .. slot.Id)
		else
			model:SetAttribute("VTRRunApproved", false)
		end
	end
end

return Coordinator
