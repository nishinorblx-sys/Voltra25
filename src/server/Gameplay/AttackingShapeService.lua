--!strict
local AttackingRunService = require(script.Parent.AttackingRunService)
local PassingLaneService = require(script.Parent.PassingLaneService)

local Service = {}

function Service.Calculate(context: any, assignment: any): (Vector3, string)
	local target, behavior = AttackingRunService.Calculate(context, assignment)
	local adjusted, laneScore = PassingLaneService.Adjust(context, assignment, target)
	assignment.PassingLaneScore = laneScore
	return adjusted, behavior
end

return Service
