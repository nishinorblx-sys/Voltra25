--!strict
local Service = {}

local function offsideLimit(context: any, attackSign: number): number
	local progress = {}
	for _, opponent in context.Opponents or {} do
		local root = opponent:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local localPosition = context.PitchCFrame:PointToObjectSpace(root.Position)
			table.insert(progress, localPosition.Z * attackSign)
		end
	end
	table.sort(progress, function(a, b) return a > b end)
	return (progress[2] or context.Length * 0.4) - 2
end

function Service.Calculate(context: any, assignment: any): (Vector3, string)
	local baseLocal = context.PitchCFrame:PointToObjectSpace(assignment.BasePosition)
	local ballLocal = context.PitchCFrame:PointToObjectSpace(context.Ball.Position)
	local attackSign = context.AttackSign or (context.Side == "Home" and -1 or 1)
	local role = assignment.Role
	local run = assignment.SupportRole or "HoldShape"
	local x, z = baseLocal.X, baseLocal.Z
	if role == "GK" then return assignment.BasePosition, "GoalkeeperSupport" end
	if run == "ShortSupport" then
		local side = (assignment.Model:GetAttribute("VTRIndex") or 1) % 2 == 0 and -1 or 1
		x, z = ballLocal.X + side * 11, ballLocal.Z - attackSign * 7
	elseif run == "ThroughRun" then
		x, z = baseLocal.X * 0.78, ballLocal.Z + attackSign * 30
	elseif run == "WideRun" then
		x, z = math.sign(baseLocal.X) * context.Width * 0.43, ballLocal.Z + attackSign * 18
	elseif run == "Overlap" then
		x, z = math.sign(baseLocal.X) * context.Width * 0.46, ballLocal.Z + attackSign * 25
	elseif run == "DiagonalSupport" or run == "Underlap" then
		local opposite = math.sign(baseLocal.X) == math.sign(ballLocal.X) and -1 or 1
		x, z = ballLocal.X + opposite * 18, ballLocal.Z + attackSign * 12
	elseif run == "RecycleOption" or run == "BackPassOption" then
		x, z = ballLocal.X * 0.65 + baseLocal.X * 0.35, ballLocal.Z - attackSign * 17
	elseif run == "HoldWidth" then
		x, z = math.sign(baseLocal.X) * context.Width * 0.43, ballLocal.Z + attackSign * 6
	elseif run == "FarPostRun" or run == "BoxRun" then
		x, z = -math.sign(ballLocal.X == 0 and baseLocal.X or ballLocal.X) * context.Width * 0.31, ballLocal.Z + attackSign * 29
	else
		x, z = baseLocal.X + ballLocal.X * 0.1, baseLocal.Z + attackSign * 6
	end
	if role == "CB" then z = ballLocal.Z - attackSign * 31 end
	if role == "CDM" and run ~= "ShortSupport" then z = ballLocal.Z - attackSign * 18 end
	if run == "ThroughRun" or run == "FarPostRun" or run == "BoxRun" or run == "Overlap" then
		local progress = z * attackSign
		z = math.min(progress, offsideLimit(context, attackSign)) * attackSign
	end
	x = math.clamp(x, -context.Width * 0.46, context.Width * 0.46)
	z = math.clamp(z, -context.Length * 0.44, context.Length * 0.44)
	return context.PitchCFrame:PointToWorldSpace(Vector3.new(x, 3, z)), run
end

return Service
