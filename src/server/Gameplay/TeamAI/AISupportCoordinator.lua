--!strict

local Coordinator = {}

function Coordinator.Apply(context: any, side: string, assignments: any, plan: any)
	for model, assignment in pairs(assignments) do
		if assignment.PrimaryAssignment == "immediate-support" or assignment.PrimaryAssignment == "pivot" or assignment.PrimaryAssignment == "far-side-switch" then
			model:SetAttribute("SupportRole", assignment.PrimaryAssignment)
			model:SetAttribute("TeamPlan", plan and plan.Intent or "")
		end
	end
end

return Coordinator
