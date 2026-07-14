--!strict

local Service = {}

local routeAttributes = {
	"VTRReceptionContractId",
	"VTRReceptionRevision",
	"VTRReceptionPhase",
	"VTRReceiveTarget",
	"VTRReceiveIntercept",
	"VTRReceiveUntil",
	"VTRReceiveBallETA",
	"VTRReceiveReceiverETA",
	"VTRReceiveOpponentETA",
	"VTRReceiveRouteConfidence",
	"VTRReceiveTrajectoryConfidence",
	"VTRReceiveRouteSprintRequested",
	"VTRPreparingReceive",
	"VTRReceiveCommitted",
	"VTRReceiverAssist",
	"VTRReceiverAssistMode",
	"VTRFirstTouchIntent",
	"VTRFirstTouchIntentVector",
	"VTRReceptionQueuedAction",
	"VTRReceiveLockedAt",
	"VTRReceiveMode",
	"VTRReceiveBallSpeed",
	"VTRReceiveDistance",
	"AIDebugExpectedPass",
	"AIDebugPassTarget",
	"AIDebugPassKind",
	"AIDebugPassScore",
}

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

function Service.SetRoute(receiver: Model, contract: any)
	receiver:SetAttribute("VTRReceptionContractId", contract.Id)
	receiver:SetAttribute("VTRReceptionRevision", contract.Revision)
	receiver:SetAttribute("VTRReceptionPhase", contract.Phase)
	receiver:SetAttribute("VTRReceiveTarget", contract.LiveInterceptPoint)
	receiver:SetAttribute("VTRReceiveIntercept", contract.LiveInterceptPoint)
	receiver:SetAttribute("VTRReceiveUntil", contract.ExpiresAt)
	receiver:SetAttribute("VTRReceiveBallETA", contract.BallETA)
	receiver:SetAttribute("VTRReceiveReceiverETA", contract.ReceiverETA)
	receiver:SetAttribute("VTRReceiveOpponentETA", contract.OpponentETA)
	receiver:SetAttribute("VTRReceiveRouteConfidence", contract.RouteConfidence)
	receiver:SetAttribute("VTRReceiveTrajectoryConfidence", contract.TrajectoryConfidence)
	receiver:SetAttribute("VTRReceiveRouteSprintRequested", contract.RouteSprintRequested == true)
	receiver:SetAttribute("VTRPreparingReceive", true)
	receiver:SetAttribute("VTRReceiveCommitted", true)
	receiver:SetAttribute("VTRReceiverAssist", contract.AssistanceMode)
	receiver:SetAttribute("VTRReceiverAssistMode", contract.AssistanceMode)
end

function Service.SetPhase(receiver: Model, phase: string, revision: number)
	receiver:SetAttribute("VTRReceptionPhase", phase)
	receiver:SetAttribute("VTRReceptionRevision", revision)
end

function Service.RouteDirection(receiver: Model, point: Vector3): Vector3
	local receiverRoot = receiver:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not receiverRoot then return Vector3.zero end
	local offset = flat(point - receiverRoot.Position)
	return offset.Magnitude > 0.08 and offset.Unit or Vector3.zero
end

function Service.BlendUserMovement(receiver: Model, point: Vector3, userDirection: Vector3, routeWeight: number, userWeight: number): (Vector3, number)
	local route = Service.RouteDirection(receiver, point)
	local user = flat(userDirection)
	if user.Magnitude > 1 then user = user.Unit end
	local blended = route * math.clamp(routeWeight, 0, 1) + user * math.clamp(userWeight, 0, 1)
	if blended.Magnitude > 1 then blended = blended.Unit end
	return blended, math.clamp(route.Magnitude * routeWeight, 0, 1)
end

function Service.Clear(receiver: Model)
	for _, attribute in routeAttributes do receiver:SetAttribute(attribute, nil) end
	receiver:SetAttribute("VTRManualReceiveOverride", false)
	receiver:SetAttribute("VTRAssistedMoveMagnitude", 0)
	if receiver:GetAttribute("controlledByUser") ~= true then
		receiver:SetAttribute("VTRAISprintRequested", false)
	end
end

return Service
