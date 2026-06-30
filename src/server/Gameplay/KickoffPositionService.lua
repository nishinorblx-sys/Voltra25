--!strict
local Service = {}

local function move(model: Model, position: Vector3, facing: Vector3)
	model:PivotTo(CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z)))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid then
		for _,state in {Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Physics, Enum.HumanoidStateType.PlatformStanding} do
			humanoid:SetStateEnabled(state, false)
		end
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:Move(Vector3.zero, false)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

function Service.Position(teams: any, formation: any, pitchCFrame: CFrame, restartTeam: string, half: number?): (Model, Model?)
	local center = pitchCFrame.Position
	for _, side in {"Home", "Away"} do
		local baseSign = side == "Home" and 1 or -1
		local ownSign = (half or 1) >= 2 and -baseSign or baseSign
		local sideFormation = formation[side] or formation
		for index, model in teams[side] do
			local point = sideFormation[index] or Vector2.zero
			local z = point.Y * ownSign
			-- Everyone starts in their own half; the non-kickoff team is also
			-- outside the larger VTR kickoff circle.
			local minDistance = side == restartTeam and 12 or 62
			z = ownSign * math.max(math.abs(z), minDistance)
			local position = pitchCFrame:PointToWorldSpace(Vector3.new(point.X, 3, z))
			move(model, position, center)
		end
	end
	local taker = teams[restartTeam][10] or teams[restartTeam][1]
	local baseSign = restartTeam == "Home" and 1 or -1
	local ownSign = (half or 1) >= 2 and -baseSign or baseSign
	local takerPosition = pitchCFrame:PointToWorldSpace(Vector3.new(0, 3, ownSign * 1.8))
	move(taker, takerPosition, pitchCFrame:PointToWorldSpace(Vector3.new(0, 3, -ownSign * 12)))
	local partner = teams[restartTeam][7] or teams[restartTeam][8]
	if partner and partner ~= taker then
		move(partner, pitchCFrame:PointToWorldSpace(Vector3.new(8, 3, ownSign * 7.5)), center)
	end
	return taker, partner
end

return Service
