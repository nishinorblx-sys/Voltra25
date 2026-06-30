--!strict
local Service = {}

function Service.Apply(context: any, assignment: any, target: Vector3): (Vector3, string)
	if assignment.Phase == "TransitionDefense" then
		if assignment.PressAssignment == "Primary" or assignment.PressAssignment == "Secondary" then
			return Vector3.new(context.Ball.Position.X, 3, context.Ball.Position.Z), "CounterPress"
		end
		return assignment.BasePosition:Lerp(target, 0.45), "RecoverShape"
	elseif assignment.Phase == "TransitionAttack" then
		local localTarget = context.PitchCFrame:PointToObjectSpace(target)
		local attackSign = context.AttackSign or (context.Side == "Home" and -1 or 1)
		if assignment.Role == "Winger" or assignment.Role == "ST" or assignment.Role == "CAM" then
			localTarget = Vector3.new(localTarget.X * 1.12, 3, localTarget.Z + attackSign * 12)
		elseif assignment.Role == "CM" or assignment.Role == "CDM" then
			localTarget += Vector3.new(0, 0, attackSign * 6)
		end
		return context.PitchCFrame:PointToWorldSpace(localTarget), "BreakForward"
	end
	return target, assignment.SupportRole or assignment.PressAssignment or "HoldShape"
end

return Service
