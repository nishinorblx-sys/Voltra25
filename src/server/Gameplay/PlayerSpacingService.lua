--!strict
local Service = {}

function Service.Apply(model: Model, target: Vector3, assignedTargets: {[Model]: Vector3}, minimumSpacing: number): Vector3
	local adjusted = target
	for teammate, otherTarget in assignedTargets do
		if teammate ~= model then
			local offset = adjusted - otherTarget
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < minimumSpacing then
				local direction = flat.Magnitude > 0.05 and flat.Unit or Vector3.new((model:GetAttribute("VTRIndex") or 1) % 2 == 0 and 1 or -1, 0, 0)
				adjusted += direction * (minimumSpacing - flat.Magnitude) * 0.9
			end
		end
	end
	return adjusted
end

return Service
