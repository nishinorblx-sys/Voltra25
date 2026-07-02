--!strict
local Service = {}

function Service.SetTarget(receiver: Model, point: Vector3)
	receiver:SetAttribute("VTRReceiveTarget", point)
	receiver:SetAttribute("VTRPreparingReceive", true)
	receiver:SetAttribute("VTRReceiveCommitted", true)
end

function Service.Clear(receiver: Model)
	receiver:SetAttribute("VTRReceiveTarget", nil)
	receiver:SetAttribute("VTRPreparingReceive", false)
	receiver:SetAttribute("VTRReceiveCommitted", nil)
end

function Service.Step(receiver: Model, point: Vector3, ball: BasePart)
	if receiver:GetAttribute("VTRManualReceiveOverride") == true then return end
	local humanoid = receiver:FindFirstChildOfClass("Humanoid")
	local receiverRoot = receiver:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not receiverRoot then return end
	local ballVelocity = Vector3.new(ball.AssemblyLinearVelocity.X, 0, ball.AssemblyLinearVelocity.Z)
	local distanceToPoint = (receiverRoot.Position - point).Magnitude
	local distanceToBall = (receiverRoot.Position - ball.Position).Magnitude
	local intercept = distanceToBall < 13 and ball.Position + ballVelocity * 0.08 or point
	humanoid.WalkSpeed = distanceToPoint < 4.5 and 11.5 or math.max(humanoid.WalkSpeed, 18)
	humanoid:MoveTo(Vector3.new(intercept.X, receiverRoot.Position.Y, intercept.Z))
end

return Service
