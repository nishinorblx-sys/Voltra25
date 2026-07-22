--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)
local AILooseBallService = require(script.Parent.AILooseBallService)
local AIGoalkeeperService = require(script.Parent.AIGoalkeeperService)
local AIDefensiveDecisionService = require(script.Parent.AIDefensiveDecisionService)
local PenaltyBoxService = require(script.Parent.PenaltyBoxService)
local AIRunCoordinator = require(script.Parent.AIRunCoordinator)
local AIDefensiveCoordinator = require(script.Parent.AIDefensiveCoordinator)
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AIPlayerInstructionConfig = require(ReplicatedStorage.VTR.Shared.AIPlayerInstructionConfig)

local Service = {}
Service.__index = Service

local function asWorld(context: any, side: string, pitch: Vector3): Vector3
	return PitchConfig.TeamPitchPositionToWorld(PitchConfig.ClampInsidePitch(pitch), side, context.Options)
end

local function makeAssignment(context: any, info: any, name: string, pitch: Vector3, urgency: number, sprint: boolean?, faceWorld: Vector3?): any
	local targetWorld = asWorld(context, info.Side, pitch)
	return {
		Model = info.Model,
		Info = info,
		Role = info.Role,
		Zone = info.SpecificRole,
		Phase = "",
		PrimaryAssignment = name,
		MovementTarget = targetWorld,
		TargetWorld = targetWorld,
		TargetPitch = pitch,
		MovementUrgency = urgency,
		SprintAllowed = sprint == true,
		FaceWorld = faceWorld or context.BallWorld,
		MarkTarget = nil,
		SupportTarget = context.Owner,
	}
end

local function rollingLobCutoffTarget(context: any, receiverWorld: Vector3): Vector3
	local ball = context.BallWorld
	local velocity = context.BallVelocity or Vector3.zero
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontal.Magnitude < 1.5 then
		return ball
	end
	local toReceiver = Vector3.new(receiverWorld.X - ball.X, 0, receiverWorld.Z - ball.Z)
	local movingPastReceiver = toReceiver.Magnitude > 0.05 and horizontal.Unit:Dot(toReceiver.Unit) > 0.15
	local lead = math.clamp(horizontal.Magnitude * (movingPastReceiver and 0.34 or 0.24), 8, 22)
	local target = ball + horizontal.Unit * lead
	return Vector3.new(target.X, receiverWorld.Y, target.Z)
end

local goalkeeperLockStates = {
	Tracking = true,
	Diving = true,
	Falling = true,
	Landing = true,
	Recovering = true,
	ReturnHome = true,
	HoldBall = true,
	Held = true,
	ClosingDown = true,
	CuttingPass = true,
	SweepLooseBall = true,
	SaveAttempt = true,
}

local function clearReceiveIntent(model: Model)
	model:SetAttribute("VTRPreparingReceive", nil)
	model:SetAttribute("VTRReceiveCommitted", nil)
	model:SetAttribute("VTRReceiveHardLock", nil)
	model:SetAttribute("VTRForcedPassReceiver", nil)
	model:SetAttribute("VTRAITargetedPass", nil)
	model:SetAttribute("VTRAIAlternatePassChaser", nil)
	model:SetAttribute("VTRForcedReceiveUntil", nil)
	model:SetAttribute("VTRReceiveHardLockUntil", nil)
end

local function goalkeeperPriorityActive(context: any, info: any): boolean
	if not info.IsGoalkeeper then
		return false
	end
	local model = info.Model
	local now = context.Now or os.clock()
	local actionLockUntil = tonumber(model:GetAttribute("VTRGoalkeeperActionLockUntil")) or 0
	local state = tostring(model:GetAttribute("VTRGoalkeeperState") or model:GetAttribute("GKState") or "")
	return actionLockUntil > now
		or model:GetAttribute("VTRGoalkeeperSaving") == true
		or model:GetAttribute("VTRKeeperDiveAnimationLocked") == true
		or model:GetAttribute("VTRGoalkeeperHolding") == true
		or model:GetAttribute("AIGoalkeeperLooseClaim") == true
		or goalkeeperLockStates[state] == true
end

local function lockGoalkeeperAction(context: any, info: any, seconds: number)
	if info.IsGoalkeeper then
		info.Model:SetAttribute("VTRGoalkeeperActionLockUntil", (context.Now or os.clock()) + seconds)
		clearReceiveIntent(info.Model)
	end
end

local function receiveAssignment(context: any, info: any): any?
	if goalkeeperPriorityActive(context, info) then
		clearReceiveIntent(info.Model)
		return nil
	end
	local target = info.Model:GetAttribute("VTRReceiveIntercept")
	if typeof(target) ~= "Vector3" then
		target = info.Model:GetAttribute("VTRReceiveTarget")
	end
	local now = context.Now or os.clock()
	local forcedUntil = tonumber(info.Model:GetAttribute("VTRForcedReceiveUntil")) or 0
	local hardLockUntil = tonumber(info.Model:GetAttribute("VTRReceiveHardLockUntil")) or 0
	local untilTime = math.max(tonumber(info.Model:GetAttribute("VTRReceiveUntil")) or 0, forcedUntil, hardLockUntil)
	local aiTargeted = info.Model:GetAttribute("VTRAITargetedPass") == true
	local forced = info.Model:GetAttribute("VTRForcedPassReceiver") == true or forcedUntil > now
	local hardLock = forced or aiTargeted or info.Model:GetAttribute("VTRAIAlternatePassChaser") == true or info.Model:GetAttribute("VTRReceiveHardLock") == true or hardLockUntil > now
	local namedPassReceiver = context.PassInFlight == true and typeof(context.PassTargetWorld) == "Vector3" and (context.PassReceiverName == info.Model.Name or context.PassReceiverName == tostring(info.Model:GetAttribute("DisplayName") or ""))
	if typeof(context.PassTargetWorld) == "Vector3" and (context.PassReceiverName == info.Model.Name or context.PassReceiverName == tostring(info.Model:GetAttribute("DisplayName") or "")) then
		target = info.Model:GetAttribute("VTRReceiveIntercept")
		if typeof(target) ~= "Vector3" then target = context.PassTargetWorld end
	end
	local activeReceive = namedPassReceiver or info.Model:GetAttribute("VTRPreparingReceive") == true or hardLock or forced
	if activeReceive ~= true or typeof(target) ~= "Vector3" or (untilTime <= now and not namedPassReceiver) then
		return nil
	end
	local targetPitch = PitchConfig.WorldToTeamPitchPosition(target, info.Side, context.Options)
	local ballEta = tonumber(info.Model:GetAttribute("VTRReceiveBallETA")) or 0
	local receiverEta = tonumber(info.Model:GetAttribute("VTRReceiveReceiverETA")) or math.huge
	local receiveFamily = tostring(info.Model:GetAttribute("VTRReceivePassFamily") or info.Model:GetAttribute("VTRPrePassFamily") or info.Model:GetAttribute("AIDebugPassKind") or "")
	local lobbed = receiveFamily == "Lob" or receiveFamily == "Lofted" or receiveFamily == "ManualLobbed" or receiveFamily == "FarPostCross" or (context.Ball and context.Ball:GetAttribute("VTRLobPassActive") == true)
	local ballVelocity = context.BallVelocity or Vector3.zero
	local ballSpeed = Vector3.new(ballVelocity.X, 0, ballVelocity.Z).Magnitude
	if lobbed and hardLock and (context.Ball and context.Ball:GetAttribute("VTRLobLanded") == true or PitchConfig.GetDistanceStuds(context.BallWorld, target) > 5.5 and ballSpeed > 1.5) then
		target = rollingLobCutoffTarget(context, info.World)
		targetPitch = PitchConfig.WorldToTeamPitchPosition(target, info.Side, context.Options)
		info.Model:SetAttribute("VTRReceiveIntercept", target)
		info.Model:SetAttribute("VTRReceiveTarget", target)
		info.Model:SetAttribute("VTRReceiveMode", "CollectLobAfterBounce")
		info.Model:SetAttribute("VTRLobCutoffLeadTarget", target)
	end
	local sprint = hardLock or info.Model:GetAttribute("VTRReceiveRouteSprintRequested") == true or receiverEta > math.max(0.1, ballEta - (aiTargeted and 0.18 or 0.08))
	local assignment = makeAssignment(context, info, "ReceivePass", targetPitch, 1, sprint, context.BallWorld)
	assignment.Phase = "PassReception"
	assignment.ReceptionContractId = info.Model:GetAttribute("VTRReceptionContractId")
	assignment.ForcedReceiver = hardLock or forced or namedPassReceiver
	assignment.RunTicketId = nil
	assignment.RunApproved = false
	assignment.SprintConservation = 0
	assignment.MovementProfile = sprint and "SprintBurst" or "Balanced"
	return assignment
end

local function applyReceiveOverrides(context: any, side: string, assignments: any, coordinator: any?)
	for _, info in ipairs(context.Teams[side].List) do
		local assignment = receiveAssignment(context, info)
		if assignment then
			assignments[info.Model] = assignment
			if coordinator and coordinator.Tickets then coordinator.Tickets[info.Model] = nil end
			info.Model:SetAttribute("VTRRunTicketId", nil)
			info.Model:SetAttribute("VTRRunApproved", false)
			info.Model:SetAttribute("VTRRunKind", nil)
			info.Model:SetAttribute("VTRRunTrigger", nil)
			info.Model:SetAttribute("VTRRunTarget", nil)
			info.Model:SetAttribute("VTRRunExpiry", nil)
			info.Model:SetAttribute("VTRSupportRun", nil)
			info.Model:SetAttribute("VTRSupportKind", nil)
			info.Model:SetAttribute("currentAssignment", "ReceivePass")
			info.Model:SetAttribute("AIAssignment", "ReceivePass")
			info.Model:SetAttribute("SupportRole", "ReceivePass")
			info.Model:SetAttribute("AttackAssignment", "ReceivePass")
			info.Model:SetAttribute("TeamPhase", "PassReception")
		end
	end
end

local function applyPlayerInstructions(context: any, info: any, assignment: any, attacking: boolean)
	if info.IsGoalkeeper then return end
	local pitch = assignment.TargetPitch
	if attacking then
		local offBall = AIPlayerInstructionConfig.IsOffBall(info.OffBallInstruction) and info.OffBallInstruction or AIPlayerInstructionConfig.RoleDefaults(info.SpecificRole).OffBall
		assignment.OffBallInstruction = offBall
		if offBall == "HoldPosition" then
			local dx=math.clamp(pitch.X-info.BasePitch.X,-14,14)
			local dz=math.clamp(pitch.Z-info.BasePitch.Z,-14,14)
			pitch = Vector3.new(info.BasePitch.X+dx,3,info.BasePitch.Z+dz)
			assignment.PrimaryAssignment = assignment.PrimaryAssignment == "ReceivePass" and assignment.PrimaryAssignment or "InstructionHoldPosition"
			assignment.SprintAllowed = false
			assignment.RunApproved = false
			assignment.InstructionRunAllowed = false
		elseif offBall == "SupportBall" then
			local ball=context.BallTeam[info.Side]
			local lateral=info.BasePitch.X < ball.X and -26 or 26
			pitch = Vector3.new(math.clamp(ball.X+lateral,34,390),3,math.clamp(ball.Z-24,40,682))
			assignment.PrimaryAssignment = "InstructionSupportBall"
			assignment.MovementUrgency = math.max(assignment.MovementUrgency, 0.78)
			assignment.SupportRole = "NearPassingTriangle"
		elseif offBall == "AttackSpace" then
			local role=tostring(info.Role)
			local advance=(role=="Winger" or role=="ST") and 92 or role=="Fullback" and 72 or (role=="CM" or role=="CAM") and 58 or 34
			pitch = Vector3.new(pitch.X,3,math.min(690,math.max(pitch.Z,context.BallTeam[info.Side].Z+advance)))
			assignment.PrimaryAssignment = role=="Fullback" and "InstructionOverlap" or "InstructionAttackSpace"
			assignment.MovementUrgency = math.max(assignment.MovementUrgency, 0.94)
			assignment.SprintAllowed = true
			assignment.InstructionRunAllowed = true
		end
	else
		local defending = AIPlayerInstructionConfig.IsDefending(info.DefensiveInstruction) and info.DefensiveInstruction or AIPlayerInstructionConfig.RoleDefaults(info.SpecificRole).Defending
		assignment.DefensiveInstruction = defending
		if defending == "HoldShape" then
			assignment.MovementUrgency = math.min(assignment.MovementUrgency, 0.72)
			assignment.PressPriority = (tonumber(assignment.PressPriority) or 0) - 30
			assignment.PrimaryAssignment = assignment.PrimaryAssignment == "PressBallCarrier" and "InstructionHoldShapeLane" or assignment.PrimaryAssignment
			assignment.SprintAllowed = false
		elseif defending == "HuntBall" then
			assignment.MovementUrgency = math.max(assignment.MovementUrgency, 0.98)
			assignment.PressPriority = (tonumber(assignment.PressPriority) or 0) + 34
			assignment.SprintAllowed = true
		end
	end
	assignment.TargetPitch = PitchConfig.ClampInsidePitch(pitch)
	assignment.TargetWorld = asWorld(context, info.Side, assignment.TargetPitch)
	assignment.MovementTarget = assignment.TargetWorld
	assignment.InstructionEffect = attacking and tostring(assignment.OffBallInstruction or "") or tostring(assignment.DefensiveInstruction or "")
	assignment.InstructionTarget = assignment.TargetPitch
end

local function baseWithPhase(info: any, phase: string, ballPitch: Vector3, style: any): Vector3
	local base = info.BasePitch
	local advanceBase = math.max(base.Z, ballPitch.Z)
	if phase == "OwnPossession_BuildUp" then
		if info.Role == "CB" then
			return Vector3.new(base.X + (base.X < PitchConfig.HALF_WIDTH and -18 or 18), 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 4, ballPitch.Z - 35))
		elseif info.Role == "Fullback" then
			local width = style:Ratio("AttackingWidth")
			local wideX = base.X < PitchConfig.HALF_WIDTH and 45 + (1 - width) * 46 or 379 - (1 - width) * 46
			return Vector3.new(wideX, 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 10, advanceBase, ballPitch.Z + 28))
		elseif info.Role == "CDM" then
			return Vector3.new(212, 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 18, ballPitch.Z + 35))
		end
	elseif phase == "Transition_JustWonBall" then
		if info.Role == "ST" or info.Role == "Winger" then
			return Vector3.new(base.X, 3, math.min(690, math.max(base.Z, ballPitch.Z + 115)))
		end
	end
	return base
end

local function defendingBase(info: any, ballPitch: Vector3, style: any): Vector3
	local base = info.BasePitch
	local depth = style:Ratio("DefensiveDepth")
	local lineZ = AIDefensiveDecisionService.LineHeight(ballPitch, depth)
	local function behindBall(offset: number, floorZ: number, ceilingZ: number?): number
		local ceiling = ceilingZ or 520
		return math.clamp(math.min(lineZ + offset, ballPitch.Z - offset), floorZ, ceiling)
	end
	if info.Role == "CB" then
		return Vector3.new(base.X, 3, behindBall(0, 34, 285))
	elseif info.Role == "Fullback" then
		local ballSide = ballPitch.X < PitchConfig.HALF_WIDTH and "Left" or "Right"
		local ownSide = base.X < PitchConfig.HALF_WIDTH and "Left" or "Right"
		local x = ownSide == ballSide and base.X or base.X + (PitchConfig.HALF_WIDTH - base.X) * 0.4
		return Vector3.new(x, 3, behindBall(10, 42, 305))
	elseif info.Role == "CDM" then
		return Vector3.new(212, 3, behindBall(56, 86, 400))
	elseif info.Role == "CM" or info.Role == "CAM" then
		return Vector3.new(base.X + (PitchConfig.HALF_WIDTH - base.X) * 0.22, 3, behindBall(88, 120, 470))
	elseif info.Role == "Winger" then
		local defensiveWidth = style:Ratio("DefensiveWidth")
		local tuckedX = base.X + (PitchConfig.HALF_WIDTH - base.X) * (0.58 - defensiveWidth * 0.24)
		return Vector3.new(tuckedX, 3, behindBall(112, 145, 520))
	elseif info.Role == "ST" then
		return Vector3.new(base.X, 3, behindBall(145, 180, 555))
	end
	return base
end

local function shortSupportTarget(info: any, ballPitch: Vector3, style: any): Vector3
	local sideSign = info.Pitch.X >= ballPitch.X and 1 or -1
	local supportDistance = 34 + style:Ratio("SupportDistance") * 34
	if ballPitch.X < 90 then
		return Vector3.new(ballPitch.X + supportDistance, 3, ballPitch.Z + 15)
	elseif ballPitch.X > 334 then
		return Vector3.new(ballPitch.X - supportDistance, 3, ballPitch.Z + 15)
	end
	return Vector3.new(ballPitch.X + supportDistance * sideSign, 3, ballPitch.Z + 20)
end

local function onsideZ(context:any, side:string, fallback:number):number
	local line=AIContextBuilder.DefensiveLineZ(context,side)
	if line > 90 then
		return math.clamp(math.min(fallback,line-7),0,704)
	end
	return math.clamp(fallback,0,704)
end

local function wideOutletTarget(context:any, info: any, ballPitch: Vector3, style: any): Vector3
	local width = style:Ratio("AttackingWidth")
	local discipline = style:Ratio("WidthDiscipline")
	local left = info.BasePitch.X < PitchConfig.HALF_WIDTH
	local touchlineX = left and 35 or 389
	local wideX = left and 45 + (1 - width) * 55 or 379 - (1 - width) * 55
	wideX = wideX + (touchlineX - wideX) * discipline * 0.38
	return Vector3.new(wideX, 3, onsideZ(context,info.Side,math.min(690, math.max(info.Pitch.Z + 18, info.BasePitch.Z, ballPitch.Z + 40))))
end

local function runBehindTarget(context: any, info: any): Vector3
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, info.Side)
	local currentZ = math.clamp(info.Pitch.Z, 0, 704)
	local safeLine = defensiveLine > 90 and defensiveLine - 7 or 704
	local desiredZ = math.min(math.max(currentZ + 22, defensiveLine - 20), safeLine, 704)
	return Vector3.new(PitchConfig.GetLaneCenter(info.Lane), 3, math.clamp(desiredZ, 0, 704))
end

local function strikerRunBehindTarget(context: any, info: any): (string, Vector3)
	local now = context.Now or os.clock()
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, info.Side)
	local currentZ = math.clamp(info.Pitch.Z, 0, PitchConfig.PITCH_LENGTH)
	local runUntil = tonumber(info.Model:GetAttribute("AIStrikerOffsideRunUntil")) or 0
	local recoverUntil = tonumber(info.Model:GetAttribute("AIStrikerOffsideRecoverUntil")) or 0
	if now <= runUntil then
		local desiredZ = math.max(currentZ + 28, defensiveLine + 20)
		return "RiskOffsideRun", Vector3.new(PitchConfig.GetLaneCenter(info.Lane), 3, math.clamp(desiredZ, 0, PitchConfig.PITCH_LENGTH - 18))
	end
	if now <= recoverUntil then
		return "RecoverOnsideAfterRun", runBehindTarget(context, info)
	end
	if defensiveLine >= 330 and currentZ >= defensiveLine - 82 then
		info.Model:SetAttribute("AIStrikerOffsideRunUntil", now + 3.5)
		info.Model:SetAttribute("AIStrikerOffsideRecoverUntil", now + 5.9)
		local desiredZ = math.max(currentZ + 28, defensiveLine + 20)
		return "RiskOffsideRun", Vector3.new(PitchConfig.GetLaneCenter(info.Lane), 3, math.clamp(desiredZ, 0, PitchConfig.PITCH_LENGTH - 18))
	end
	return "RunBehind", runBehindTarget(context, info)
end

local function sideOf(infoOrPitch: any): string
	local x = if typeof(infoOrPitch) == "Vector3"
		then infoOrPitch.X
		else ((infoOrPitch.Pitch and infoOrPitch.Pitch.X) or infoOrPitch.X or PitchConfig.HALF_WIDTH)
	if x < PitchConfig.HALF_WIDTH - 35 then
		return "Left"
	elseif x > PitchConfig.HALF_WIDTH + 35 then
		return "Right"
	end
	return "Center"
end

local function sameWideSide(info: any, pitch: Vector3): boolean
	local ballSide = sideOf(pitch)
	return ballSide ~= "Center" and sideOf(info) == ballSide
end

local function ballIsWide(pitch: Vector3): boolean
	return pitch.X < 100 or pitch.X > 324
end

local function ballIsCentral(pitch: Vector3): boolean
	return pitch.X >= 145 and pitch.X <= 279
end

local function carrierFacesForward(context: any, side: string, carrier: any?): boolean
	if not carrier or not carrier.Root then
		return false
	end
	local lookProgress = PitchConfig.GetForwardProgress(carrier.World, carrier.World + carrier.Root.CFrame.LookVector * 8, side, context.Options)
	local velocity = Vector3.new(carrier.Root.AssemblyLinearVelocity.X, 0, carrier.Root.AssemblyLinearVelocity.Z)
	local velocityProgress = velocity.Magnitude > 0.5 and PitchConfig.GetForwardProgress(carrier.World, carrier.World + velocity.Unit * 8, side, context.Options) or 0
	return lookProgress > 1.2 or velocityProgress > 1.2
end

local function teammateByRoleWithBall(ownerInfo: any?, roles: {[string]: boolean}): boolean
	return ownerInfo ~= nil and roles[ownerInfo.Role] == true
end

local function carrierIsPressed(context: any, ownerInfo: any?): boolean
	if not ownerInfo then
		return false
	end
	local pressure = AIContextBuilder.Pressure(context, ownerInfo)
	return pressure.Under or pressure.Heavy or pressure.Closest <= 18
end

local function isBasicPossessionStyle(style: any): boolean
	local id = tostring(style and style.Tactics and style.Tactics.PlaystyleId or "")
	local name = tostring(style and style.Tactics and style.Tactics.PlaystyleName or "")
	return id == "basic_possession"
		or name == "Basic Possession"
		or name == "SAFE Possession"
		or id == "quick_passing"
		or id == "vertical_tiki_taka"
		or name == "Quick Passing"
		or name == "Tiki-Taka"
		or (tonumber(style and style.MetricsTargets and style.MetricsTargets.QuickPassing) or 0) >= 1
		or (tonumber(style and style.MetricsTargets and style.MetricsTargets.BoxEdgeRetreatLimit) or 0) >= 100
end

local function isQuickPassingStyle(style: any): boolean
	local id = tostring(style and style.Tactics and style.Tactics.PlaystyleId or "")
	local name = tostring(style and style.Tactics and style.Tactics.PlaystyleName or "")
	return id == "quick_passing"
		or id == "vertical_tiki_taka"
		or id == "counter_attack"
		or name == "Quick Passing"
		or name == "Tiki-Taka"
		or (tonumber(style and style.MetricsTargets and style.MetricsTargets.QuickPassing) or 0) >= 1
		or (tonumber(style and style.MetricsTargets and style.MetricsTargets.FirstTimePassChance) or 0) >= 60
end

local function isWingPlayStyle(style: any): boolean
	local id = tostring(style and style.Tactics and style.Tactics.PlaystyleId or "")
	local name = tostring(style and style.Tactics and style.Tactics.PlaystyleName or "")
	return id == "wing_play"
		or id == "wing_overload"
		or name == "Wing Play"
		or (tonumber(style and style.MetricsTargets and style.MetricsTargets.WingReleaseAfterMidfieldAdvance) or 0) >= 1
end

local function isVerticalTikiTakaStyle(style: any): boolean
	local id = tostring(style and style.Tactics and style.Tactics.PlaystyleId or "")
	local name = tostring(style and style.Tactics and style.Tactics.PlaystyleName or "")
	return id == "vertical_tiki_taka" or name == "Vertical Tiki-Taka" or name == "Vertical Tiki Taka"
end

local function wingPlayTouchlineX(info: any, style: any): number
	local offset = math.clamp(tonumber(style and style.MetricsTargets and style.MetricsTargets.WingSidelineOffset) or 10, 6, 24)
	local left = info.BasePitch.X < PitchConfig.HALF_WIDTH
	return left and offset or PitchConfig.PITCH_WIDTH - offset
end

local function wingPlayEndlineZ(style: any): number
	local offset = math.clamp(tonumber(style and style.MetricsTargets and style.MetricsTargets.WingEndlineTargetOffset) or 10, 6, 28)
	return PitchConfig.PITCH_LENGTH - offset
end

local function midfieldEstablishedInOpponentHalf(context: any, side: string): boolean
	local team = context.Teams and context.Teams[side]
	if not team then return false end
	local total, advanced = 0, 0
	for _, teammate in ipairs(team.List) do
		if teammate.Root and (teammate.Role == "CDM" or teammate.Role == "CM" or teammate.Role == "CAM") then
			total += 1
			if teammate.Pitch.Z >= PitchConfig.HALF_LENGTH + 6 then
				advanced += 1
			end
		end
	end
	return total > 0 and advanced >= math.max(2, total)
end

local function closestDefenderToCarrier(context: any, info: any, ownerInfo: any?): boolean
	if not ownerInfo or not info.Root then
		return false
	end
	local best: any? = nil
	local bestDistance = math.huge
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Root and not teammate.IsGoalkeeper then
			local distance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)
			if distance < bestDistance then
				bestDistance = distance
				best = teammate
			end
		end
	end
	return best == info
end

local function cbPressed(context: any, side: string): boolean
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Role == "CB" then
			local pressure = AIContextBuilder.Pressure(context, teammate)
			if pressure.Under or pressure.Closest <= 16 then
				return true
			end
		end
	end
	return false
end

local function nearestRoleMarked(context: any, side: string, role: string, distance: number): boolean
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Role == role then
			local _, nearest = AIContextBuilder.NearestOpponent(context, teammate)
			if nearest <= distance then
				return true
			end
		end
	end
	return false
end

local function sideLaneX(info: any, wide: boolean?): number
	local left = info.BasePitch.X < PitchConfig.HALF_WIDTH
	if wide == true then
		return left and 44 or 380
	end
	return left and 118 or 306
end

local function isWingPlayWidePlayer(info: any): boolean
	local specific = tostring(info.SpecificRole or "")
	return info.Role == "Winger"
		or specific == "LW"
		or specific == "RW"
		or specific == "LM"
		or specific == "RM"
		or specific == "LWB"
		or specific == "RWB"
end

local function basicLaneCenter(info: any): number
	local x = info.BasePitch and info.BasePitch.X or info.Pitch.X
	if x < 76 then return 44 end
	if x < 170 then return 128 end
	if x < 254 then return PitchConfig.HALF_WIDTH end
	if x < 348 then return 296 end
	return 380
end

local function basicSupportPoint(ballPitch: Vector3, sideSign: number, zOffset: number, lateral: number): Vector3
	return PitchConfig.ClampInsidePitch(Vector3.new(math.clamp(ballPitch.X + sideSign * lateral, 34, 390), 3, math.clamp(ballPitch.Z + zOffset, 40, 682)))
end

local function basicPassLaneBlocked(context: any, ownerInfo: any, info: any): boolean
	if not ownerInfo or not ownerInfo.Root or not info.Root then return false end
	if info.Pitch.Z <= ownerInfo.Pitch.Z + 8 then return false end
	local feetTarget = PitchConfig.TeamPitchPositionToWorld(Vector3.new(info.Pitch.X, 3, info.Pitch.Z), info.Side, context.Options)
	if AIContextBuilder.PassingLaneClear(context, ownerInfo, feetTarget, "Ground") then return false end
	local _, nearest = AIContextBuilder.NearestOpponent(context, info)
	return nearest <= 24
end

local function basicRankedSupport(context: any, side: string, ownerInfo: any): ({any}, any?, any?)
	local ranked = {}
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Model ~= ownerInfo.Model and teammate.Root and not teammate.IsGoalkeeper then
			table.insert(ranked, {Info = teammate, Distance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)})
		end
	end
	table.sort(ranked, function(a, b) return a.Distance < b.Distance end)
	local behind, farWide = nil, nil
	local farSideLeft = ownerInfo.Pitch.X >= PitchConfig.HALF_WIDTH
	local behindScore = math.huge
	local farScore = -math.huge
	for _, entry in ipairs(ranked) do
		local info = entry.Info
		if info.Pitch.Z <= ownerInfo.Pitch.Z - 10 then
			local roleBonus = (info.Role == "CDM" or info.Role == "CB") and -22 or info.Role == "CM" and -12 or 0
			local score = math.abs(info.Pitch.X - PitchConfig.HALF_WIDTH) * .2 + math.abs((ownerInfo.Pitch.Z - 34) - info.Pitch.Z) + roleBonus
			if score < behindScore then behind = info; behindScore = score end
		end
		local isWide = info.Role == "Winger" or info.Role == "Fullback"
		local isFarSide = farSideLeft and info.BasePitch.X < PitchConfig.HALF_WIDTH or (not farSideLeft and info.BasePitch.X > PitchConfig.HALF_WIDTH)
		if isWide and isFarSide then
			local score = math.abs(info.Pitch.X - ownerInfo.Pitch.X) + math.max(0, info.Pitch.Z - ownerInfo.Pitch.Z)
			if score > farScore then farWide = info; farScore = score end
		end
	end
	return ranked, behind, farWide
end

local function pivotOffset(info: any): number
	local name = tostring(info.SpecificRole or "")
	if string.find(name, "L") then
		return -34
	elseif string.find(name, "R") then
		return 34
	end
	return info.BasePitch.X < PitchConfig.HALF_WIDTH and -28 or 28
end

local function hasDoublePivot(context: any, side: string): boolean
	local count = 0
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Role == "CDM" then
			count += 1
		end
	end
	return count >= 2
end

local function strikerLineZ(context: any, side: string): number
	local highest = 570
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Role == "ST" then
			highest = math.max(highest, teammate.Pitch.Z, teammate.BasePitch.Z)
		end
	end
	return highest
end

local function capBehindStriker(context: any, side: string, target: Vector3, minimumGap: number?): Vector3
	local strikerZ = strikerLineZ(context, side)
	local gap = minimumGap or 45
	return Vector3.new(target.X, target.Y, math.min(target.Z, strikerZ - gap))
end

local function attackingTrailCover(context: any, info: any, ballPitch: Vector3): (string, Vector3)
	local best: any? = nil
	local bestScore = -math.huge
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and (teammate.Role == "ST" or teammate.Role == "CAM" or teammate.Role == "CM") then
			local ahead = teammate.Pitch.Z - ballPitch.Z
			local roleBonus = teammate.Role == "ST" and 38 or teammate.Role == "CAM" and 24 or 14
			local sidePenalty = math.abs(teammate.Pitch.X - info.Pitch.X) * 0.06
			local score = roleBonus + math.max(ahead, -20) * 0.18 - sidePenalty
			if teammate.Pitch.Z >= ballPitch.Z - 18 and score > bestScore then
				best = teammate
				bestScore = score
			end
		end
	end
	if best then
		local behind = best.Role == "ST" and 34 or 26
		local lateralSide = info.Pitch.X < PitchConfig.HALF_WIDTH and -1 or 1
		if math.abs(info.Pitch.X - PitchConfig.HALF_WIDTH) < 14 then
			lateralSide = ballPitch.X < PitchConfig.HALF_WIDTH and 1 or -1
		end
		local lateral = best.Role == "ST" and lateralSide * 44 or lateralSide * 32
		local target = Vector3.new(
			math.clamp(best.Pitch.X + lateral, 86, 338),
			3,
			math.clamp(best.Pitch.Z - behind, math.max(175, ballPitch.Z - 48), math.max(230, ballPitch.Z + 38))
		)
		return best.Role == "ST" and "TrailStrikerCoverWide" or "TrailMidfielderCoverWide", target
	end
	local fallbackX = PitchConfig.HALF_WIDTH + (info.BasePitch.X < PitchConfig.HALF_WIDTH and -28 or 28)
	return "TrailingPassBack", Vector3.new(fallbackX, 3, math.max(190, ballPitch.Z - 28))
end

local function cdmTarget(context: any, info: any, ballPitch: Vector3, pressed: boolean, safe: boolean): (string, Vector3, number, boolean)
	local doublePivot = hasDoublePivot(context, info.Side)
	local offset = doublePivot and pivotOffset(info) or 0
	local x = PitchConfig.HALF_WIDTH + offset
	local isBallSide = not doublePivot or (ballPitch.X < PitchConfig.HALF_WIDTH and offset < 0) or (ballPitch.X >= PitchConfig.HALF_WIDTH and offset > 0)
	if cbPressed(context, info.Side) then
		return doublePivot and "DropBesideCenterBacks" or "DropBetweenCenterBacks", Vector3.new(x, 3, 115), 0.82, false
	elseif PenaltyBoxService.IsInsideDefensiveBox(info.Side, context.BallWorld, context.Options) then
		return "ProtectBoxEdge", Vector3.new(x, 3, 118), 0.9, false
	elseif isBallSide and (pressed or ballPitch.Z >= PitchConfig.HALF_LENGTH) then
		return "BallSidePivotSupport", Vector3.new(x, 3, math.max(210, ballPitch.Z - 38)), 0.84, false
	elseif doublePivot then
		local name, target = attackingTrailCover(context, info, ballPitch)
		return name, target, 0.8, false
	elseif safe then
		return "SlightAdvanceReset", Vector3.new(x, 3, math.max(info.BasePitch.Z, ballPitch.Z - 28)), 0.76, false
	end
	return "ResetOption", Vector3.new(x, 3, math.max(120, ballPitch.Z - 48)), 0.82, false
end

local function stadiumAnalysisFolder(): Instance?
	return Workspace:FindFirstChild("VTRStadiumAnalysis", true)
end

local function defensiveBoxPart(defendingSide: string): BasePart?
	local analysis = stadiumAnalysisFolder()
	local name = defendingSide == "Home" and "HomeBox" or "AwayBox"
	local found = analysis and analysis:FindFirstChild(name, true) or Workspace:FindFirstChild(name, true)
	return found and found:IsA("BasePart") and found or nil
end

local function inFrontOfDefensiveDangerZone(context: any, defendingSide: string, attacker: any): boolean
	local box = defensiveBoxPart(defendingSide)
	if box then
		local boxLocal = context.PitchCFrame:PointToObjectSpace(box.Position)
		local threatLocal = context.PitchCFrame:PointToObjectSpace(attacker.World)
		local halfWidth = math.max(box.Size.X, box.Size.Z) * 0.5
		local halfDepth = math.min(box.Size.X, box.Size.Z) * 0.5
		local xMargin = 32
		local zMargin = 60
		local xInside = threatLocal.X >= boxLocal.X - halfWidth - xMargin and threatLocal.X <= boxLocal.X + halfWidth + xMargin
		local zInside
		if boxLocal.Z >= 0 then
			zInside = threatLocal.Z <= boxLocal.Z - halfDepth and threatLocal.Z >= boxLocal.Z - halfDepth - zMargin
		else
			zInside = threatLocal.Z >= boxLocal.Z + halfDepth and threatLocal.Z <= boxLocal.Z + halfDepth + zMargin
		end
		return xInside and zInside
	end
	local zone = PitchConfig.Zones.OwnBox
	local threatPitch = PitchConfig.WorldToTeamPitchPosition(attacker.World, defendingSide, context.Options)
	local xMargin = 24
	return threatPitch.X >= zone.XMin - xMargin
		and threatPitch.X <= zone.XMax + xMargin
		and threatPitch.Z >= zone.ZMax
		and threatPitch.Z <= zone.ZMax + 60
end

local function boxStrikerThreat(context: any, defendingSide: string): any?
	local best = nil
	local bestScore = -math.huge
	for _, attacker in ipairs(context.Teams[defendingSide == "Home" and "Away" or "Home"].List) do
		if attacker.Root and inFrontOfDefensiveDangerZone(context, defendingSide, attacker) then
			local distanceToBall = PitchConfig.GetDistanceStuds(attacker.World, context.BallWorld)
			local hasBall = context.Owner == attacker.Model
			local roleBonus = attacker.Role == "ST" and 24 or attacker.Role == "CAM" and 16 or attacker.Role == "Winger" and 8 or 0
			local score = (hasBall and 120 or 0) + roleBonus - distanceToBall
			if score > bestScore then
				best = attacker
				bestScore = score
			end
		end
	end
	return best
end

local function centerBackRankToThreat(context: any, info: any, threat: any): number
	local rank = 1
	local distance = PitchConfig.GetDistanceStuds(info.World, threat.World)
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Role == "CB" and teammate.Model ~= info.Model and teammate.Root then
			local teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, threat.World)
			if teammateDistance < distance then
				rank += 1
			end
		end
	end
	return rank
end

local function markBetweenGoalAndThreat(threatPitch: Vector3, gap: number): Vector3
	return PitchConfig.ClampInsidePitch(Vector3.new(threatPitch.X, 3, math.max(32, threatPitch.Z - gap)))
end

local function strikerThreatVeryDangerous(context: any, defendingSide: string, threat: any): boolean
	if context.Owner ~= threat.Model then
		return false
	end
	local facingGoal = carrierFacesForward(context, threat.Side, threat)
	local central = threat.Pitch.X > 120 and threat.Pitch.X < 304
	local _, nearest = AIContextBuilder.NearestOpponent(context, threat)
	return facingGoal or central or nearest > 14
end

local function defensiveCdmTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean, Model?)
	local doublePivot = hasDoublePivot(context, info.Side)
	local offset = doublePivot and pivotOffset(info) or 0
	local x = PitchConfig.HALF_WIDTH + offset
	local ballSidePivot = not doublePivot or (ballPitch.X < PitchConfig.HALF_WIDTH and offset < 0) or (ballPitch.X >= PitchConfig.HALF_WIDTH and offset > 0)
	if PenaltyBoxService.IsInsideDefensiveBox(info.Side, context.BallWorld, context.Options) then
		return "ProtectPenaltySpot", Vector3.new(x, 3, 122), 0.9, false, nil
	elseif PenaltyBoxService.IsNearDefensiveBox(info.Side, context.BallWorld, context.Options, 32) then
		return ballSidePivot and "BlockBoxEntryLane" or "ScreenCenterBacks", Vector3.new(x, 3, ballSidePivot and math.max(130, ballPitch.Z - 22) or 120), 0.86, ballSidePivot, ownerInfo and ownerInfo.Model or nil
	elseif ballIsCentral(ballPitch) and ballPitch.Z >= 170 and ballPitch.Z <= 420 and ballSidePivot then
		return "StepIntoMiddleZone", Vector3.new(x, 3, math.max(118, ballPitch.Z - 18)), 0.86, true, ownerInfo and ownerInfo.Model or nil
	end
	return "ScreenCenterBacks", Vector3.new(x, 3, math.max(112, math.min(260, ballPitch.Z - (ballSidePivot and 34 or 66)))), 0.78, false, nil
end

local function pressureRank(context: any, info: any, ownerInfo: any): number
	local rank = 1
	local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and not teammate.IsGoalkeeper then
			local teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)
			if teammateDistance < distance then
				rank += 1
			end
		end
	end
	return rank
end

local function midfieldPressRank(context: any, info: any, ownerInfo: any): number
	local rank = 1
	local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and (teammate.Role == "CDM" or teammate.Role == "CM" or teammate.Role == "CAM") then
			local teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)
			if teammateDistance < distance then
				rank += 1
			end
		end
	end
	return rank
end

local function attackingRoleTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean)
	local pressed = carrierIsPressed(context, ownerInfo)
	local safe = not pressed
	local facingForward = carrierFacesForward(context, info.Side, ownerInfo)
	local ballNearAttackingBox = PenaltyBoxService.IsNearAttackingBox(info.Side, context.BallWorld, context.Options, 36)
	local ballInsideAttackingBox = PenaltyBoxService.IsInsideAttackingBox(info.Side, context.BallWorld, context.Options)
	local ballWideNearGoal = ballIsWide(ballPitch) and ballNearAttackingBox
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, info.Side)
	local highDefensiveLine = defensiveLine >= 430
	local ownerSameSideWinger = ownerInfo and isWingPlayWidePlayer(ownerInfo) and sameWideSide(ownerInfo, info.BasePitch)
	local ownerFullbackOrCM = ownerInfo and (ownerInfo.Role == "Fullback" or ownerInfo.Role == "CM") and sameWideSide(info, ownerInfo.Pitch)
	local ownerCMOrCDM = teammateByRoleWithBall(ownerInfo, {CM = true, CDM = true})
	local stMarked = nearestRoleMarked(context, info.Side, "ST", 16)
	local base = info.BasePitch
	local wingerHasBallWide = ownerInfo and isWingPlayWidePlayer(ownerInfo) and ballIsWide(ownerInfo.Pitch)
	local ballInAttackingHalf = ballPitch.Z >= PitchConfig.HALF_LENGTH
	local ballSide = sideOf(ballPitch)
	local infoSide = sideOf(info)
	local ballSideSupportX = ballPitch.X + (ballPitch.X < PitchConfig.HALF_WIDTH and 38 or -38)
	local farPostX = ballPitch.X < PitchConfig.HALF_WIDTH and 306 or 118
	local wingPlay = isWingPlayStyle(style)
	local wingPlayReleaseReady = wingPlay and midfieldEstablishedInOpponentHalf(context, info.Side)
	local verticalTikiTaka = isVerticalTikiTakaStyle(style)
	local verticalTrigger = verticalTikiTaka and ownerInfo and (ownerInfo.Role == "CB" or ownerInfo.Role == "Fullback" or ownerInfo.Role == "CDM" or ownerInfo.Role == "CM" or ownerInfo.Role == "CAM") and safe and facingForward

	if info.Role == "CB" then
		if pressed then
			return "ResetDrop", Vector3.new(base.X, 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 4, math.min(base.Z, ballPitch.Z - 95))), 0.78, false
		end
		if ballPitch.Z > info.Pitch.Z + 70 then
			return "StayBackCover", Vector3.new(base.X, 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 4, math.min(base.Z + 55, ballPitch.Z - 105))), 0.72, false
		end
		local step = Vector3.new(base.X, 3, math.min(base.Z + 90, ballPitch.Z + 42))
		if safe and AIContextBuilder.SpaceAt(context, info.Side, step, 22) then
			return "CarryIfFree", step, 0.84, true
		end
		return "StayBackCover", Vector3.new(base.X, 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 4, math.min(base.Z + 45, ballPitch.Z - 75))), 0.72, false
	elseif info.Role == "Fullback" then
		if wingerHasBallWide and sameWideSide(info, ballPitch) then
			return "WingerBackOption", Vector3.new(sideLaneX(info, true), 3, math.max(155, ballPitch.Z - 42)), 0.88, false
		end
		if ownerSameSideWinger then
			local oppositeSideAttacking = false
			for _, teammate in ipairs(context.Teams[info.Side].List) do
				if teammate.Role == "Fullback" and teammate.Model ~= info.Model and teammate.Pitch.Z > ballPitch.Z + 18 then
					oppositeSideAttacking = true
					break
				end
			end
			if not oppositeSideAttacking then
				return "OverlapRun", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, ballPitch.Z + 78)), 0.92, true
			end
		end
		if pressed then
			return "CoverCenterBack", Vector3.new(sideLaneX(info, false), 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 10, ballPitch.Z - 70)), 0.78, false
		end
		return "HoldFullbackLine", Vector3.new(base.X, 3, math.max(base.Z, math.min(ballPitch.Z - 28, 315))), 0.72, false
	elseif info.Role == "CDM" then
		return cdmTarget(context, info, ballPitch, pressed or wingerHasBallWide, safe)
	elseif info.Role == "CM" then
		if verticalTrigger and ownerInfo and ownerInfo.Model ~= info.Model then
			local supportX = math.clamp(ballPitch.X + (info.BasePitch.X < PitchConfig.HALF_WIDTH and -24 or 24), 135, 289)
			return "VerticalTikiTakaSupportRun", Vector3.new(supportX, 3, math.clamp(ballPitch.Z + 26, 340, 590)), 0.94, true
		elseif wingerHasBallWide and infoSide == ballSide then
			return "InsideTriangleSupport", Vector3.new(math.clamp(ballSideSupportX, 125, 299), 3, math.clamp(ballPitch.Z + 4, 440, 594)), 0.94, true
		elseif wingerHasBallWide then
			return "FarSideSwitchOption", Vector3.new(math.clamp(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.5, 145, 279), 3, math.clamp(ballPitch.Z + 16, 450, 584)), 0.86, true
		elseif ballWideNearGoal then
			return "HoldEdgeOfBox", Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.45, 3, 548), 0.8, false
		elseif pressed then
			return "ComeShort", shortSupportTarget(info, ballPitch, style), 0.86, info.Stamina > 42
		elseif facingForward then
			return "ForwardMidfieldRun", Vector3.new(PitchConfig.GetLaneCenter(info.Lane), 3, onsideZ(context, info.Side, ballPitch.Z + 78)), 0.92, true
		end
		return "MidfieldSupport", Vector3.new(base.X, 3, math.max(base.Z, ballPitch.Z + 38)), 0.82, true
	elseif info.Role == "CAM" then
		if verticalTrigger and ownerInfo and ownerInfo.Model ~= info.Model then
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH + (base.X < PitchConfig.HALF_WIDTH and -18 or 18), 3, onsideZ(context, info.Side, ballPitch.Z + 54)), 38)
			return "VerticalTikiTakaBetweenLines", target, 0.96, true
		elseif wingerHasBallWide then
			local cutbackZ = ballInsideAttackingBox and 584 or 552
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH, 3, cutbackZ), 35)
			return "CentralCutbackOption", target, 0.92, true
		elseif ballInAttackingHalf and ballIsWide(ballPitch) then
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH + (ballPitch.X < PitchConfig.HALF_WIDTH and -24 or 24), 3, math.clamp(ballPitch.Z + 18, 470, 590)), 40)
			return "RoamForCutback", target, 0.88, true
		elseif ballInAttackingHalf and ballIsCentral(ballPitch) then
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(455, ballPitch.Z + 38))), 45)
			return "RoamBetweenLines", target, 0.86, false
		elseif ownerCMOrCDM then
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, ballPitch.Z + 62)), 45)
			return "BetweenDefenders", target, 0.9, true
		elseif stMarked then
			return "ComeShort", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(280, ballPitch.Z - 22)), 0.84, false
		end
		local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 42))), 45)
		return "BetweenLines", target, 0.82, false
	elseif info.Role == "Winger" or wingPlay and isWingPlayWidePlayer(info) then
		if wingPlay then
			local touchlineX = wingPlayTouchlineX(info, style)
			local releaseUntil = tonumber(info.Model:GetAttribute("AIWingPlayReleaseUntil")) or 0
			local releaseTarget = info.Model:GetAttribute("AIWingPlayReleaseTarget")
			if typeof(releaseTarget) == "Vector3" and (context.Now or os.clock()) <= releaseUntil then
				local releasePitch = PitchConfig.WorldToTeamPitchPosition(releaseTarget, info.Side, context.Options)
				return "WingPlayReleaseTarget", Vector3.new(touchlineX, 3, onsideZ(context, info.Side, releasePitch.Z)), 1, info.Stamina > 34
			end
			if wingerHasBallWide and ownerInfo and ownerInfo.Model ~= info.Model and not sameWideSide(info, ballPitch) then
				return "WingPlayFarPost", Vector3.new(farPostX, 3, math.clamp(ballPitch.Z + 28, 610, 670)), 0.96, true
			end
			if wingerHasBallWide and ownerInfo and ownerInfo.Model == info.Model then
				return "WingPlayDriveEndline", Vector3.new(touchlineX, 3, onsideZ(context, info.Side, math.max(ballPitch.Z + 58, wingPlayEndlineZ(style)))), 1, info.Stamina > 34
			end
			if wingPlayReleaseReady then
				local releaseZ = math.max(base.Z, ballPitch.Z + 92)
				return "WingPlayTouchlineRun", Vector3.new(touchlineX, 3, onsideZ(context, info.Side, math.min(wingPlayEndlineZ(style), releaseZ))), 1, info.Stamina > 34
			end
			return "WingPlayTouchlineReady", Vector3.new(touchlineX, 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 46))), 0.88, info.Stamina > 38
		end
		if verticalTrigger then
			local tuckedX = info.BasePitch.X < PitchConfig.HALF_WIDTH and PitchConfig.HALF_WIDTH - 62 or PitchConfig.HALF_WIDTH + 62
			return "VerticalTikiTakaHalfSpaceRun", Vector3.new(tuckedX, 3, onsideZ(context, info.Side, ballPitch.Z + 82)), 0.98, info.Stamina > 34
		end
		if wingerHasBallWide and ownerInfo and ownerInfo.Model ~= info.Model and not sameWideSide(info, ballPitch) then
			return "AttackBackPost", Vector3.new(farPostX, 3, math.clamp(ballPitch.Z + 28, 610, 670)), 0.96, true
		end
		if ownerFullbackOrCM and highDefensiveLine then
			return "RunBehindWide", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, ballPitch.Z + 95)), 1, true
		elseif pressed then
			return "ComeShortWide", Vector3.new(sideLaneX(info, true), 3, math.max(210, ballPitch.Z - 24)), 0.86, info.Stamina > 38
		elseif ballIsCentral(ballPitch) then
			return "StayWide", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 58))), 0.86, true
		end
		local outlet = wideOutletTarget(context, info, ballPitch, style)
		return "WideOutlet", Vector3.new(outlet.X, 3, math.max(outlet.Z, ballPitch.Z + 48)), 0.86, info.Stamina > 35
	elseif info.Role == "ST" then
		if verticalTrigger then
			return "VerticalTikiTakaDropShort", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(320, math.min(ballPitch.Z + 18, 520))), 0.96, true
		end
		if wingerHasBallWide or ballWideNearGoal then
			local nearPostX = ballPitch.X < PitchConfig.HALF_WIDTH and 176 or 248
			local strikerX = ballInsideAttackingBox and nearPostX or PitchConfig.HALF_WIDTH
			return "AttackBox", Vector3.new(strikerX, 3, math.clamp(ballPitch.Z + 30, 615, 656)), 0.96, true
		end
		local _, nearest = AIContextBuilder.NearestOpponent(context, info)
		local tightlyMarked = nearest <= 15
		if safe and facingForward then
			local runName, target = strikerRunBehindTarget(context, info)
			return runName, target, 1, true
		elseif tightlyMarked or not facingForward then
			return "ComeShortToEscapePressure", Vector3.new(PitchConfig.HALF_WIDTH + (info.Pitch.X < PitchConfig.HALF_WIDTH and 28 or -28), 3, math.max(340, ballPitch.Z - 38)), 0.92, true
		end
		return "PinCenterBacks", Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 62))), 0.88, true
	end

	return "HoldShape", baseWithPhase(info, "OwnPossession_BuildUp", ballPitch, style), 0.72, false
end

local function defensiveRoleTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean, Model?)
	local base = defendingBase(info, ballPitch, style)
	local ballSide = sideOf(ballPitch)
	local sameSide = sameWideSide(info, ballPitch)
	local ownerRole = ownerInfo and ownerInfo.Role or ""
	local ownerPitch = ballPitch
	local faceModel = ownerInfo and ownerInfo.Model or nil
	local boxThreat = boxStrikerThreat(context, info.Side)
	local ballNearDefensiveBox = PenaltyBoxService.IsNearDefensiveBox(info.Side, context.BallWorld, context.Options, 60)
	local pressPaused = context.PressPaused and context.PressPaused[info.Side] == true
	local carrierHasCarriedIntoSpace = ownerInfo and ownerInfo.Model:GetAttribute("AICarryIntoSpace") == true and (tonumber(ownerInfo.Model:GetAttribute("AICarriedFor")) or 0) >= 2
	local carrierDistance = ownerInfo and PitchConfig.GetDistanceStuds(info.World, ownerInfo.World) or math.huge
	local defensiveHalfPressure = ownerInfo ~= nil and ballPitch.Z <= PitchConfig.HALF_LENGTH
	local defensiveThirdPressure = ownerInfo ~= nil and ballPitch.Z <= PitchConfig.HALF_LENGTH
	if ownerInfo and not pressPaused and defensiveHalfPressure then
		if info.Role == "CB" and (ownerRole == "ST" or ownerRole == "CAM") and carrierDistance <= 115 then
			return "AggressiveCBPressStriker", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif info.Role == "Fullback" and (ownerRole == "Winger" or ownerRole == "LW" or ownerRole == "RW") and sameSide and carrierDistance <= 105 then
			return "AggressiveFullbackPressWinger", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif defensiveThirdPressure and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") and carrierDistance <= 110 then
			local rank = midfieldPressRank(context, info, ownerInfo)
			if rank == 1 then
				return "AggressiveMidfieldPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
			elseif rank == 2 and carrierDistance <= 105 then
				return "AggressiveMidfieldCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.94, true, faceModel
			end
		end
	end
	local defensiveThird = ownerInfo ~= nil and ballPitch.Z <= 245
	if ownerInfo and not pressPaused and defensiveThird then
		if info.Role == "CB" and (ownerRole == "ST" or ownerRole == "CAM") then
			return "AttackStrikerInDefensiveThird", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif info.Role == "Fullback" and (ownerRole == "Winger" or ownerRole == "LW" or ownerRole == "RW") and sameSide then
			return "PressWingerInDefensiveThird", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then
			local rank = midfieldPressRank(context, info, ownerInfo)
			if rank == 1 then
				return "MidfielderDefensiveThirdPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
			elseif rank == 2 then
				return "MidfielderDefensiveThirdCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.92, true, faceModel
			end
		end
	end
	if ownerInfo and not pressPaused and boxThreat and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then
		local rank = midfieldPressRank(context, info, ownerInfo)
		if rank == 1 then
			return "MidfieldBoxPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif rank == 2 then
			return "SecondMidfielderBoxCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.92, true, faceModel
		end
	end
	if ownerInfo and not pressPaused and not boxThreat and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then
		local rank = midfieldPressRank(context, info, ownerInfo)
		local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
		if rank == 1 and distance <= 70 then
			return "MidfieldPressRotation", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif rank == 2 and distance <= 92 then
			return "SecondMidfielderCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.9, true, faceModel
		else
			local screenX = info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.28
			return "OrganizeMidfieldPress", Vector3.new(screenX, 3, math.clamp(ballPitch.Z + 26, 155, 430)), 0.84, true, faceModel
		end
	end
	if ownerInfo and not pressPaused and not boxThreat and carrierHasCarriedIntoSpace and closestDefenderToCarrier(context, info, ownerInfo) then
		return "CloseLongCarryGap", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
	end
	if ownerInfo and not pressPaused and not boxThreat then
		local rank = pressureRank(context, info, ownerInfo)
		local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
		if rank == 1 and distance <= 20 then
			return "PressBallCarrier", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif rank == 2 and distance <= 38 then
			return "CoverPresser", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.88, true, faceModel
		end
	end

	if info.Role == "ST" then
		if not pressPaused and ballPitch.Z >= 520 and (ownerRole == "CB" or ownerRole == "GK" or ballPitch.Z >= 610) then
			return "PressCenterBackOrKeeper", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		end
		return "BlockDefensiveMidfielder", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.clamp(ballPitch.Z + 95, 330, 560)), 0.8, false, nil
	elseif info.Role == "Winger" then
		if not pressPaused and ballSide ~= "Center" and sameSide and ballPitch.Z >= 220 then
			return "PressFullback", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.94, true, faceModel
		elseif sameSide and ballPitch.Z < 220 then
			return "TrackOverlap", Vector3.new(sideLaneX(info, true), 3, math.max(95, ballPitch.Z - 18)), 0.9, true, nil
		elseif ballPitch.Z < 170 then
			return "CounterOutlet", Vector3.new(sideLaneX(info, true), 3, 285), 0.72, false, nil
		end
		return "RecoverWideMidfield", Vector3.new(sideLaneX(info, true), 3, base.Z), 0.76, false, nil
	elseif info.Role == "CAM" then
		if not pressPaused and ballIsCentral(ballPitch) and ballPitch.Z >= 235 then
			return "PressCentralMidfield", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.9, true, faceModel
		end
		return "DropIntoMidfield", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.clamp(ballPitch.Z + 48, 250, 430)), 0.78, false, nil
	elseif info.Role == "CM" then
		if not pressPaused and ownerRole == "CM" and PitchConfig.GetDistanceStuds(info.World, ownerInfo.World) <= 44 then
			return "StepToMidfielder", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.9, true, faceModel
		elseif (ownerRole == "CAM" or ownerRole == "ST") and ballPitch.Z <= 360 then
			return "DropBetweenLines", Vector3.new(info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.3, 3, math.clamp(ballPitch.Z + 36, 165, 360)), 0.84, false, nil
		end
		return "ShiftBallSide", Vector3.new(info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.42, 3, base.Z), 0.78, false, nil
	elseif info.Role == "CDM" then
		return defensiveCdmTarget(context, info, ballPitch, ownerInfo, style)
	elseif info.Role == "Fullback" then
		if ballSide ~= "Center" and sameSide then
			if ballPitch.Z < info.Pitch.Z - 12 then
				return "RecoverRunnerBehind", Vector3.new(sideLaneX(info, true), 3, math.max(42, ballPitch.Z - 20)), 0.96, true, faceModel
			end
			local containZ = math.clamp(ownerPitch.Z - 16, 58, 320)
			local containX = sideLaneX(info, true) + (PitchConfig.HALF_WIDTH - sideLaneX(info, true)) * 0.14
			return "ShadowWingerForcePass", Vector3.new(containX, 3, containZ), 0.86, true, faceModel
		elseif ballSide ~= "Center" then
			return "TuckInside", Vector3.new(sideLaneX(info, false), 3, base.Z), 0.78, false, nil
		end
		if ownerInfo and ballSide ~= "Center" and sameSide and carrierDistance <= 95 then
			return "AggressiveFullbackStepOut", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.96, true, faceModel
		end
		return "HoldFullbackLine", base, 0.74, false, nil
	elseif info.Role == "CB" then
		if boxThreat and (ballNearDefensiveBox or context.Owner == boxThreat.Model) then
			local rank = centerBackRankToThreat(context, info, boxThreat)
			local threatPitch = PitchConfig.WorldToTeamPitchPosition(boxThreat.World, info.Side, context.Options)
			local dangerous = strikerThreatVeryDangerous(context, info.Side, boxThreat)
			if rank == 1 then
				return "MarkStriker", markBetweenGoalAndThreat(threatPitch, 7), 1, true, boxThreat.Model
			elseif dangerous then
				return "CollapseOnStriker", markBetweenGoalAndThreat(threatPitch, 14), 0.94, true, boxThreat.Model
			end
			return "ProtectGoalCenter", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(38, threatPitch.Z - 22)), 0.86, false, boxThreat.Model
		elseif ownerRole == "ST" and ballPitch.Z <= 285 then
			return "StepToStrikerFeet", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif ownerPitch.Z < info.Pitch.Z - 12 then
			return "RunBackWithAttacker", Vector3.new(info.BasePitch.X, 3, math.max(36, ownerPitch.Z - 18)), 0.96, true, faceModel
		end
		if ownerInfo and ownerRole ~= "" and ballPitch.Z <= 285 and carrierDistance <= 110 then
			return "AggressiveCBStepOut", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.96, true, faceModel
		end
		return "HoldCenterBackLine", Vector3.new(info.BasePitch.X, 3, base.Z), 0.76, false, nil
	end

	return "RecoverShape", base, 0.74, false, nil
end

local function depthStep(currentZ: number, desiredZ: number, maxStep: number): number
	local delta = math.clamp(desiredZ - currentZ, -maxStep, maxStep)
	return currentZ + delta
end

local function shapeMotion(context: any, info: any, target: Vector3, depth: number?, width: number?): Vector3
	local seed = 0
	local name = info.Model and info.Model.Name or tostring(info.Role or "")
	for i = 1, #name do
		seed += string.byte(name, i) or 0
	end
	local now = context.Now or os.clock()
	local depthAmount = math.min(depth or 1.4, 1.6)
	local widthAmount = math.min(width or 1, 1.4)
	local waveA = math.sin(now * (0.82 + (seed % 7) * 0.035) + seed * 0.19)
	local waveB = math.cos(now * (0.58 + (seed % 5) * 0.04) + seed * 0.13)
	return PitchConfig.ClampInsidePitch(Vector3.new(target.X + waveB * widthAmount, target.Y, target.Z + waveA * depthAmount))
end

local function simpleDefensiveShapeTarget(info: any, ballPitch: Vector3, base: Vector3, style: any): Vector3
	local depth = style:Ratio("DefensiveDepth")
	local lineZ = AIDefensiveDecisionService.LineHeight(ballPitch, depth)
	if info.Role == "ST" then
		local desiredZ = math.clamp(ballPitch.Z + 95, 330, 560)
		return Vector3.new(PitchConfig.HALF_WIDTH, 3, depthStep(info.Pitch.Z, desiredZ, 28))
	elseif info.Role == "Winger" then
		local desiredZ = math.clamp(ballPitch.Z + 105, 180, 520)
		return Vector3.new(sideLaneX(info, true), 3, depthStep(info.Pitch.Z, desiredZ, 30))
	elseif info.Role == "CAM" then
		local desiredZ = math.clamp(ballPitch.Z + 58, 210, 430)
		return Vector3.new(PitchConfig.HALF_WIDTH, 3, depthStep(info.Pitch.Z, desiredZ, 26))
	elseif info.Role == "CM" then
		local desiredZ = math.clamp(lineZ + 86, 130, 405)
		return Vector3.new(info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.32, 3, depthStep(info.Pitch.Z, desiredZ, 24))
	elseif info.Role == "CDM" then
		local desiredZ = math.clamp(lineZ + 50, 88, 335)
		return Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.18, 3, depthStep(info.Pitch.Z, desiredZ, 22))
	elseif info.Role == "Fullback" then
		local tuckedX = info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.18
		local desiredZ = math.clamp(lineZ + 18, 48, 292)
		return Vector3.new(tuckedX, 3, depthStep(info.Pitch.Z, desiredZ, 22))
	elseif info.Role == "CB" then
		local desiredZ = math.clamp(lineZ, 34, 255)
		return Vector3.new(info.BasePitch.X, 3, depthStep(info.Pitch.Z, desiredZ, 20))
	end
	return base
end

local function defensiveRestBlockTarget(info: any): Vector3
	if info.Role == "ST" then
		return Vector3.new(PitchConfig.HALF_WIDTH, 3, 555)
	elseif info.Role == "Winger" then
		return Vector3.new(sideLaneX(info, true), 3, 505)
	elseif info.Role == "CAM" then
		return Vector3.new(PitchConfig.HALF_WIDTH, 3, 465)
	elseif info.Role == "CM" then
		return Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.18, 3, 390)
	elseif info.Role == "CDM" then
		return Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.2, 3, 330)
	elseif info.Role == "Fullback" then
		return Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.16, 3, 285)
	elseif info.Role == "CB" then
		return Vector3.new(info.BasePitch.X, 3, 245)
	end
	return info.BasePitch
end

local function incomingPassThreat(context: any, defendingSide: string): (any?, Vector3?)
	local ball = context.Ball
	if not ball then
		return nil, nil
	end
	local passTeam = tostring(ball:GetAttribute("VTRPassTeam") or ball:GetAttribute("LastTouchTeam") or "")
	if passTeam == "" or passTeam == defendingSide then
		return nil, nil
	end
	local receiverName = tostring(ball:GetAttribute("VTRPassReceiver") or "")
	local target = ball:GetAttribute("VTRPassTarget") or ball:GetAttribute("VTRLobTarget")
	if receiverName == "" then
		return nil, typeof(target) == "Vector3" and PitchConfig.WorldToTeamPitchPosition(target, defendingSide, context.Options) or nil
	end
	local attackingSide = defendingSide == "Home" and "Away" or "Home"
	for _, attacker in ipairs(context.Teams[attackingSide].List) do
		if attacker.Model.Name == receiverName then
			local pitchTarget = typeof(target) == "Vector3" and PitchConfig.WorldToTeamPitchPosition(target, defendingSide, context.Options) or PitchConfig.WorldToTeamPitchPosition(attacker.World, defendingSide, context.Options)
			return attacker, pitchTarget
		end
	end
	return nil, typeof(target) == "Vector3" and PitchConfig.WorldToTeamPitchPosition(target, defendingSide, context.Options) or nil
end

local function incomingPressRank(context: any, info: any, targetPitch: Vector3, roles: {[string]: boolean}): number
	local rank = 1
	local targetWorld = PitchConfig.TeamPitchPositionToWorld(targetPitch, info.Side, context.Options)
	local distance = PitchConfig.GetDistanceStuds(info.World, targetWorld)
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and roles[teammate.Role] == true then
			local teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, targetWorld)
			if teammateDistance < distance then
				rank += 1
			end
		end
	end
	return rank
end

local function compactPressureRank(context: any, info: any, targetWorld: Vector3): number
	local rank = 1
	local distance = PitchConfig.GetDistanceStuds(info.World, targetWorld)
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and not teammate.IsGoalkeeper then
			local teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, targetWorld)
			if teammateDistance < distance then
				rank += 1
			end
		end
	end
	return rank
end

local function compactDangerReceiver(context: any, defendingSide: string, ownerPitch: Vector3): (any?, Vector3?)
	local opponentSide = defendingSide == "Home" and "Away" or "Home"
	local best, bestPitch = nil, nil
	local bestScore = -math.huge
	for _, attacker in ipairs(context.Teams[opponentSide].List) do
		if attacker.Root and context.Owner ~= attacker.Model then
			local pitch = PitchConfig.WorldToTeamPitchPosition(attacker.World, defendingSide, context.Options)
			local forwardThreat = math.max(0, ownerPitch.Z - pitch.Z)
			local central = 1 - math.clamp(math.abs(pitch.X - PitchConfig.HALF_WIDTH) / PitchConfig.HALF_WIDTH, 0, 1)
			local roleBonus = attacker.Role == "ST" and 34 or attacker.Role == "CAM" and 24 or attacker.Role == "Winger" and 8 or 0
			local laneBonus = pitch.X > 118 and pitch.X < 306 and 22 or 0
			local score = forwardThreat * 1.4 + central * 34 + roleBonus + laneBonus - PitchConfig.GetDistanceStuds(attacker.World, context.BallWorld) * 0.08
			if forwardThreat > 6 and score > bestScore then
				best = attacker
				bestPitch = pitch
				bestScore = score
			end
		end
	end
	return best, bestPitch
end

local function compactLineZ(ballPitch: Vector3, role: string): number
	local boxEdge = PitchConfig.Zones.OwnBox.ZMax
	local backLine
	if ballPitch.Z <= boxEdge then
		backLine = 82
	elseif ballPitch.Z <= 245 then
		backLine = math.max(boxEdge, ballPitch.Z - 34)
	elseif ballPitch.Z <= PitchConfig.HALF_LENGTH then
		backLine = math.clamp(ballPitch.Z - 92, boxEdge, 260)
	else
		backLine = math.clamp(ballPitch.Z - 142, 210, 365)
	end
	if role == "CB" or role == "Fullback" then
		return backLine
	elseif role == "CDM" then
		return math.clamp(backLine + 34, 116, 420)
	elseif role == "CM" then
		return math.clamp(backLine + 58, 145, 455)
	elseif role == "CAM" then
		return math.clamp(backLine + 78, 170, 505)
	elseif role == "Winger" then
		return math.clamp(backLine + 92, 180, 540)
	elseif role == "ST" then
		return math.clamp(backLine + 112, 205, 565)
	end
	return backLine
end

local function compactShapeTarget(info: any, ballPitch: Vector3): Vector3
	local ballWideLeft = ballPitch.X < 110
	local ballWideRight = ballPitch.X > 314
	local ballCentral = not ballWideLeft and not ballWideRight
	local leftBase = (info.BasePitch and info.BasePitch.X or info.Pitch.X) < PitchConfig.HALF_WIDTH
	local x = info.BasePitch and info.BasePitch.X or info.Pitch.X
	local lineZ = compactLineZ(ballPitch, info.Role)
	if info.Role == "CB" then
		local sideX = leftBase and 176 or 248
		local shift = ballWideLeft and -16 or ballWideRight and 16 or 0
		x = sideX + shift
	elseif info.Role == "Fullback" then
		if ballCentral then
			x = leftBase and 68 or 356
		elseif ballWideLeft then
			x = leftBase and 54 or 326
		elseif ballWideRight then
			x = leftBase and 98 or 370
		end
	elseif info.Role == "CDM" then
		x = PitchConfig.HALF_WIDTH
	elseif info.Role == "CM" or info.Role == "CAM" then
		local sideX = leftBase and 150 or 274
		if ballCentral then
			x = sideX
		elseif ballWideLeft then
			x = leftBase and 132 or 246
		elseif ballWideRight then
			x = leftBase and 178 or 292
		end
	elseif info.Role == "Winger" then
		if ballCentral then
			x = leftBase and 92 or 332
		elseif ballWideLeft then
			x = leftBase and 72 or 308
		elseif ballWideRight then
			x = leftBase and 116 or 352
		end
	elseif info.Role == "ST" then
		x = ballCentral and PitchConfig.HALF_WIDTH or ballPitch.X + (PitchConfig.HALF_WIDTH - ballPitch.X) * 0.42
	end
	return PitchConfig.ClampInsidePitch(Vector3.new(math.clamp(x, 42, 382), 3, lineZ))
end

local function compactContainTarget(carrierPitch: Vector3): Vector3
	local centerSideX = carrierPitch.X + (PitchConfig.HALF_WIDTH - carrierPitch.X) * 0.32
	return PitchConfig.ClampInsidePitch(Vector3.new(centerSideX, 3, math.max(28, carrierPitch.Z - 5)))
end

local function simpleDefensiveRoleTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean, Model?)
	local base = defendingBase(info, ballPitch, style)
	local pressState = context.DefensivePress and context.DefensivePress[info.Side] or nil
	local ownerPitch = ownerInfo and PitchConfig.WorldToTeamPitchPosition(ownerInfo.World, info.Side, context.Options) or ballPitch
	local faceModel = ownerInfo and ownerInfo.Model or nil
	local shadow = pressState and pressState.Shadow and pressState.Shadow[info.Model]
	local ballInOwnHalf = ballPitch.Z <= PitchConfig.HALF_LENGTH

	if shadow and shadow.Target and context.Players[shadow.Target] then
		local oldInfo = context.Players[shadow.Target]
		local oldPitch = PitchConfig.WorldToTeamPitchPosition(oldInfo.World, info.Side, context.Options)
		local sideOffset = info.Pitch.X < oldPitch.X and -10 or 10
		local target = Vector3.new(
			math.clamp(oldPitch.X + sideOffset, 0, PitchConfig.PITCH_WIDTH),
			3,
			math.clamp(oldPitch.Z - 8, 34, 520)
		)
		return "PostPressShadow", target, 0.86, true, oldInfo.Model
	end

	local incomingReceiver, incomingTarget = incomingPassThreat(context, info.Side)
	if incomingTarget then
		local receiverRole = incomingReceiver and incomingReceiver.Role or ""
		local target = PitchConfig.ClampInsidePitch(Vector3.new(incomingTarget.X, 3, incomingTarget.Z - 4))
		local distanceToTarget = PitchConfig.GetDistanceStuds(info.World, PitchConfig.TeamPitchPositionToWorld(target, info.Side, context.Options))
		if info.Role == "CB" and (receiverRole == "ST" or receiverRole == "CAM") and distanceToTarget <= 155 then
			local rank = incomingPressRank(context, info, target, {CB = true})
			if rank == 1 then
				return "EarlyCBPressPassTarget", target, 1, true, incomingReceiver and incomingReceiver.Model or nil
			end
		elseif info.Role == "Fullback" and receiverRole == "Winger" and sameWideSide(info, incomingTarget) and distanceToTarget <= 145 then
			return "EarlyFullbackPressPassTarget", target, 1, true, incomingReceiver and incomingReceiver.Model or nil
		elseif (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") and (receiverRole == "CDM" or receiverRole == "CM" or receiverRole == "CAM") and distanceToTarget <= 145 then
			local rank = incomingPressRank(context, info, target, {CDM = true, CM = true, CAM = true})
			if rank == 1 then
				return "EarlyMidfielderPressPassTarget", target, 1, true, incomingReceiver and incomingReceiver.Model or nil
			elseif rank == 2 then
				return "EarlyMidfielderCoverPassTarget", AIDefensiveDecisionService.CoverPresserTarget(target), 0.94, true, incomingReceiver and incomingReceiver.Model or nil
			end
		elseif distanceToTarget <= 78 and not info.IsGoalkeeper then
			return "EarlyClosePassTargetPressure", target, 0.96, true, incomingReceiver and incomingReceiver.Model or nil
		end
	end

	if ownerInfo and ballInOwnHalf then
		local carrierDistance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
		local ownerMidfielder = ownerInfo.Role == "CDM" or ownerInfo.Role == "CM" or ownerInfo.Role == "CAM"
		local infoMidfielder = info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM"
		if info.Role == "CB" and (ownerInfo.Role == "ST" or ownerInfo.Role == "CAM") and carrierDistance <= 125 then
			return "CenterBackPressureStriker", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		end
		if info.Role == "Fullback" and ownerInfo.Role == "Winger" and sameWideSide(info, ownerPitch) and carrierDistance <= 115 then
			return "FullbackPressureWinger", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.98, true, faceModel
		end
		if infoMidfielder and ownerMidfielder and carrierDistance <= 120 then
			local rank = midfieldPressRank(context, info, ownerInfo)
			if rank == 1 then
				return "MidfielderPressureMidfielder", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
			elseif rank == 2 then
				return "MidfielderPressureCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.94, true, faceModel
			end
		end
	end

	if pressState and pressState.Active and pressState.Primary == info.Model and ownerInfo then
		local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
		local target = distance <= 10 and ownerPitch or AIDefensiveDecisionService.ContainTarget(ownerPitch)
		return "PrimaryPressRotation", target, 1, true, faceModel
	end

	if ballPitch.Z >= PitchConfig.PITCH_LENGTH * (2 / 3) then
		return "DefensiveRestBlock", defensiveRestBlockTarget(info), 0.72, false, nil
	end

	local shapeTarget = shapeMotion(context, info, simpleDefensiveShapeTarget(info, ballPitch, base, style), 18, 6)
	return "DefensiveShape", shapeTarget, 0.86, true, nil
end

function Service.new(style: any)
	return setmetatable({Style = style, RunCoordinator = AIRunCoordinator.new(style), DefensiveCoordinator = AIDefensiveCoordinator.new(style)}, Service)
end

local function storyName(context: any, side: string): string
	local story = context.TeamStories and context.TeamStories[side]
	return tostring(story and story.Action or "")
end

local function storyMovement(context: any, side: string): string
	local story = context.TeamStories and context.TeamStories[side]
	return tostring(story and story.Movement or "")
end

local function storyPitchTarget(context: any, info: any, ownerInfo: any?, fallback: Vector3): (string?, Vector3?, number?, boolean?)
	local action = storyName(context, info.Side)
	local movement = storyMovement(context, info.Side)
	local ballPitch = context.BallTeam[info.Side]
	local base = info.BasePitch
	local sameSide = sameWideSide(info, ballPitch)
	local farPostX = ballPitch.X < PitchConfig.HALF_WIDTH and 306 or 118
	if movement == "Recycle" or movement == "Secure" or movement == "Safe" then
		if info.Role == "CB" then return "StoryRecycleCenterBack", Vector3.new(base.X, 3, math.max(65, ballPitch.Z - 82)), 0.72, false end
		if info.Role == "Fullback" then return "StorySafeFullback", Vector3.new(sideLaneX(info, true), 3, math.max(100, ballPitch.Z - 42)), 0.74, false end
		if info.Role == "CDM" or info.Role == "CM" then return "StorySafeSupport", Vector3.new(PitchConfig.HALF_WIDTH + (base.X < PitchConfig.HALF_WIDTH and -34 or 34), 3, math.max(145, ballPitch.Z - 28)), 0.78, false end
		if info.Role == "ST" then return "StoryOutletStriker", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(base.Z, ballPitch.Z + 54)), 0.72, false end
	elseif movement == "Wide" or movement == "WideBuild" or movement == "Overload" then
		if info.Role == "Winger" then return sameSide and "StoryWideBallSideWinger" or "StoryFarSideWinger", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, sameSide and ballPitch.Z + 42 or math.max(base.Z, ballPitch.Z + 24))), sameSide and 0.88 or 0.78, sameSide end
		if info.Role == "Fullback" then return sameSide and "StoryWideFullbackLane" or "StoryRestFullback", Vector3.new(sideLaneX(info, true), 3, sameSide and math.max(130, ballPitch.Z - 28) or math.max(80, math.min(base.Z + 32, ballPitch.Z - 62))), sameSide and 0.84 or 0.7, false end
		if info.Role == "CM" or info.Role == "CAM" then return "StoryInsideSupport", Vector3.new(math.clamp(ballPitch.X + (ballPitch.X < PitchConfig.HALF_WIDTH and 44 or -44), 132, 292), 3, math.clamp(ballPitch.Z + 8, 250, 575)), 0.82, false end
		if info.Role == "ST" then return "StoryCrossTarget", Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(520, ballPitch.Z + 58))), 0.86, false end
	elseif movement == "Cross" then
		if info.Role == "ST" then return "StoryNearPostRun", Vector3.new(ballPitch.X < PitchConfig.HALF_WIDTH and 176 or 248, 3, 632), 0.94, true end
		if info.Role == "Winger" then return sameSide and "StoryCrossCarrierSupport" or "StoryFarPostRun", Vector3.new(sameSide and sideLaneX(info, true) or farPostX, 3, sameSide and math.max(520, ballPitch.Z - 12) or 646), sameSide and 0.78 or 0.92, not sameSide end
		if info.Role == "CM" or info.Role == "CAM" then return "StoryEdgeBox", Vector3.new(PitchConfig.HALF_WIDTH + (base.X < PitchConfig.HALF_WIDTH and -28 or 28), 3, 548), 0.8, false end
	elseif movement == "Counter" or movement == "CounterWide" or movement == "CounterCentral" or movement == "Release" then
		if info.Role == "ST" then return "StoryCentralChannelRun", Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, ballPitch.Z + 112)), 1, true end
		if info.Role == "Winger" then return "StoryCounterWideRun", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, ballPitch.Z + 105)), 1, true end
		if info.Role == "CM" or info.Role == "CAM" then return "StoryCounterSupport", Vector3.new(PitchConfig.HALF_WIDTH + (base.X < PitchConfig.HALF_WIDTH and -32 or 32), 3, ballPitch.Z + 34), 0.86, false end
		if info.Role == "CB" or info.Role == "Fullback" or info.Role == "CDM" then return "StoryCounterRestDefense", Vector3.new(base.X, 3, math.max(85, math.min(base.Z + 42, ballPitch.Z - 62))), 0.7, false end
	elseif movement == "Triangle" or movement == "ThirdMan" or movement == "WallPass" or movement == "Link" then
		if info.Role == "CM" or info.Role == "CAM" then return "StoryCentralAngle", Vector3.new(PitchConfig.HALF_WIDTH + (base.X < PitchConfig.HALF_WIDTH and -42 or 42), 3, math.clamp(ballPitch.Z + (action == "ThirdManRun" and 62 or 22), 230, 585)), 0.86, action == "ThirdManRun" end
		if info.Role == "CDM" then return "StoryCentralRestOption", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(150, ballPitch.Z - 32)), 0.76, false end
		if info.Role == "Winger" then return "StoryHoldWidth", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 36))), 0.78, false end
		if info.Role == "ST" then return "StoryWallPassStriker", Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(350, ballPitch.Z + (action == "StrikerWallPass" and 12 or 44)))), 0.84, false end
	elseif movement == "Direct" or movement == "Target" or movement == "SecondBall" then
		if info.Role == "ST" then return "StoryDirectOutlet", Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 78))), 0.92, true end
		if info.Role == "Winger" then return "StoryRunBeyondOutlet", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, ballPitch.Z + 92)), 0.9, true end
		if info.Role == "CM" or info.Role == "CDM" or info.Role == "CAM" then return "StorySecondBallSupport", Vector3.new(PitchConfig.HALF_WIDTH + (base.X < PitchConfig.HALF_WIDTH and -36 or 36), 3, math.max(180, ballPitch.Z + 16)), 0.84, false end
	elseif movement == "Commit" or movement == "Chance" or movement == "FinalPress" then
		if info.Role == "Fullback" then return "StoryFullbackCommit", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, ballPitch.Z + 72)), 0.9, true end
		if info.Role == "CM" or info.Role == "CAM" then return "StoryLateBoxRun", Vector3.new(PitchConfig.HALF_WIDTH + (base.X < PitchConfig.HALF_WIDTH and -36 or 36), 3, onsideZ(context, info.Side, ballPitch.Z + 70)), 0.92, true end
		if info.Role == "Winger" then return "StoryAttackBoxLane", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, ballPitch.Z + 86)), 0.94, true end
		if info.Role == "ST" then return "StoryCentralFinishRun", Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(565, ballPitch.Z + 48))), 0.94, true end
	end
	return nil, fallback, nil, nil
end

local function applyStoryAttack(context: any, info: any, assignment: any, ownerInfo: any?)
	if not assignment or not context.TeamStories then return end
	assignment.TeamStoryAction = storyName(context, info.Side)
	local name, pitch, urgency, sprint = storyPitchTarget(context, info, ownerInfo, assignment.TargetPitch)
	if name and pitch then
		assignment.PrimaryAssignment = name
		assignment.TargetPitch = PitchConfig.ClampInsidePitch(pitch)
		assignment.TargetWorld = asWorld(context, info.Side, assignment.TargetPitch)
		assignment.MovementTarget = assignment.TargetWorld
		assignment.MovementUrgency = urgency or assignment.MovementUrgency
		assignment.SprintAllowed = sprint == nil and assignment.SprintAllowed or sprint
		info.Model:SetAttribute("AITacticalStoryAction", assignment.TeamStoryAction)
		info.Model:SetAttribute("SupportRole", name)
	end
end

local function applyStoryDefense(context: any, info: any, assignment: any, ownerInfo: any?)
	local movement = storyMovement(context, info.Side)
	if movement == "" or not assignment then return end
	assignment.TeamStoryAction = storyName(context, info.Side)
	if movement == "Press" or movement == "Counterpress" then
		if ownerInfo then
			local rank = pressureRank(context, info, ownerInfo)
			if rank == 1 then
				local target = AIDefensiveDecisionService.ContainTarget(ownerInfo.Pitch)
				assignment.PrimaryAssignment = "StoryPrimaryPresser"
				assignment.TargetPitch = target
				assignment.TargetWorld = asWorld(context, info.Side, target)
				assignment.MovementTarget = assignment.TargetWorld
				assignment.MovementUrgency = 1
				assignment.SprintAllowed = true
			elseif rank == 2 then
				local target = AIDefensiveDecisionService.CoverPresserTarget(ownerInfo.Pitch)
				assignment.PrimaryAssignment = "StoryCoverPresser"
				assignment.TargetPitch = target
				assignment.TargetWorld = asWorld(context, info.Side, target)
				assignment.MovementTarget = assignment.TargetWorld
				assignment.MovementUrgency = 0.9
				assignment.SprintAllowed = true
			elseif info.Role == "CB" or info.Role == "Fullback" then
				assignment.PrimaryAssignment = "StoryDepthProtector"
				assignment.SprintAllowed = false
			end
		end
	elseif movement == "Block" or movement == "LowBlock" or movement == "Delay" or movement == "BoxProtect" then
		local ballPitch = context.BallTeam[info.Side]
		if info.Role == "ST" then
			assignment.PrimaryAssignment = "StoryOutletInBlock"
			assignment.TargetPitch = Vector3.new(info.BasePitch.X, 3, math.max(235, ballPitch.Z + 85))
		elseif info.Role == "Winger" then
			assignment.PrimaryAssignment = "StoryNarrowWideMidfielder"
			assignment.TargetPitch = Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.55, 3, math.max(130, ballPitch.Z - 42))
		elseif info.Role == "CB" or info.Role == "Fullback" or info.Role == "CDM" then
			assignment.PrimaryAssignment = "StoryCompactDefensiveBlock"
			assignment.TargetPitch = Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.18, 3, math.max(55, math.min(info.BasePitch.Z + 26, ballPitch.Z - 38)))
		end
		assignment.TargetPitch = PitchConfig.ClampInsidePitch(assignment.TargetPitch)
		assignment.TargetWorld = asWorld(context, info.Side, assignment.TargetPitch)
		assignment.MovementTarget = assignment.TargetWorld
		assignment.MovementUrgency = math.min(assignment.MovementUrgency or 0.8, 0.82)
		assignment.SprintAllowed = false
	end
	info.Model:SetAttribute("AITacticalStoryAction", assignment.TeamStoryAction)
end

local function applyPossessionSprintBoost(context: any, side: string, assignments: any)
	local ownerInfo = context.Owner and context.Players[context.Owner]
	if not ownerInfo or ownerInfo.Side ~= side or not carrierIsPressed(context, ownerInfo) then
		return
	end
	for model, assignment in assignments do
		local info = assignment.Info
		if info and model ~= context.Owner and not info.IsGoalkeeper and assignment.PrimaryAssignment ~= "GoalkeeperPosition" and assignment.PrimaryAssignment ~= "ReceivePass" then
			local distance = PitchConfig.GetDistanceStuds(info.World, assignment.TargetWorld or info.World)
			local stamina = tonumber(info.Stamina) or tonumber(model:GetAttribute("VTRSprintEnergy")) or 75
			if distance >= 7 and stamina > 18 then
				assignment.SprintAllowed = true
				assignment.MovementUrgency = math.max(assignment.MovementUrgency or 0.72, distance > 14 and 0.94 or 0.88)
				assignment.SprintConservation = math.min(tonumber(assignment.SprintConservation) or 50, 20)
				model:SetAttribute("AIPossessionSprintBoost", true)
			else
				model:SetAttribute("AIPossessionSprintBoost", false)
			end
		elseif info then
			model:SetAttribute("AIPossessionSprintBoost", false)
		end
	end
end

local function wingerContainTarget(carrierPitch: Vector3): Vector3
	local insideX = carrierPitch.X + (PitchConfig.HALF_WIDTH - carrierPitch.X) * 0.26
	return PitchConfig.ClampInsidePitch(Vector3.new(insideX, 3, math.max(24, carrierPitch.Z - 7)))
end

local function applyFullbackWingerCarrierPress(context: any, side: string, assignments: any)
	local ownerInfo = context.Owner and context.Players[context.Owner]
	if not ownerInfo or ownerInfo.Side == side then return end
	local ownerRole = tostring(ownerInfo.Role or "")
	if ownerRole ~= "Winger" and ownerRole ~= "LW" and ownerRole ~= "RW" then return end
	local ownerPitch = PitchConfig.WorldToTeamPitchPosition(ownerInfo.World, side, context.Options)
	if ownerPitch.Z > PitchConfig.HALF_LENGTH + 135 then return end
	local ownerLeft = ownerPitch.X < PitchConfig.HALF_WIDTH
	local best, bestScore = nil, math.huge
	for _, info in ipairs(context.Teams[side].List) do
		if info.Role == "Fullback" and info.Root and not info.IsGoalkeeper then
			local sameSide = ownerLeft and info.BasePitch.X < PitchConfig.HALF_WIDTH or (not ownerLeft and info.BasePitch.X >= PitchConfig.HALF_WIDTH)
			local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
			local sidePenalty = sameSide and -38 or 42
			local score = distance + sidePenalty + math.abs(info.Pitch.Z - ownerPitch.Z) * 0.12
			if score < bestScore then
				best = info
				bestScore = score
			end
		end
	end
	if not best then return end
	local target = wingerContainTarget(ownerPitch)
	local assignment = assignments[best.Model] or makeAssignment(context, best, "FullbackPressWingerCarrier", target, 1, true, ownerInfo.Model)
	assignment.PrimaryAssignment = "FullbackPressWingerCarrier"
	assignment.TargetPitch = target
	assignment.TargetWorld = asWorld(context, side, target)
	assignment.MovementTarget = assignment.TargetWorld
	assignment.MovementUrgency = 1
	assignment.SprintAllowed = true
	assignment.SprintConservation = 0
	assignment.FaceWorld = ownerInfo.World
	assignment.MarkTarget = ownerInfo.Model
	assignment.DefensiveDuty = "PressWideCarrierGoalSide"
	assignment.MovementProfile = "SprintBurst"
	assignments[best.Model] = assignment
	best.Model:SetAttribute("AIFullbackWingerPress", true)
	best.Model:SetAttribute("AIFullbackWingerPressTarget", ownerInfo.Model.Name)
	best.Model:SetAttribute("AIFullbackWingerGoalSideTarget", assignment.TargetWorld)
	best.Model:SetAttribute("TeamDefensiveIntent", "Fullback presses winger while blocking goal path")
	for _, info in ipairs(context.Teams[side].List) do
		if info.Role == "Fullback" and info.Model ~= best.Model then
			info.Model:SetAttribute("AIFullbackWingerPress", false)
		end
	end
end

local function assignBasicPossessionAttack(service: any, context: any, side: string, phase: string, assignments: any): boolean
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	if not ownerInfo or ownerInfo.Side ~= side then return false end
	local ballPitch = context.BallTeam[side]
	local facingForward = carrierFacesForward(context, side, ownerInfo)
	local quickPassing = isQuickPassingStyle(service.Style)
	local ranked, behind, farWide = basicRankedSupport(context, side, ownerInfo)
	local beside = ranked[1] and ranked[1].Info or nil
	local angle = ranked[2] and ranked[2].Info or nil
	local used = {[ownerInfo.Model] = true}
	local runCount = 0
	local ballSideSign = ballPitch.X < PitchConfig.HALF_WIDTH and 1 or -1
	if quickPassing then
		local now = context.Now or os.clock()
		for _, info in ipairs(context.Teams[side].List) do
			local runUntil = tonumber(info.Model:GetAttribute("VTRQuickPassRunUntil")) or 0
			local runTarget = info.Model:GetAttribute("VTRQuickPassRunTarget")
			if info.Model ~= ownerInfo.Model and info.Root and not info.IsGoalkeeper and runUntil > now and typeof(runTarget) == "Vector3" then
				local targetPitch = PitchConfig.WorldToTeamPitchPosition(runTarget, side, context.Options)
				assignments[info.Model] = makeAssignment(context, info, "QuickPassingPostPassRun", targetPitch, 1, true, context.BallWorld)
				assignments[info.Model].RunKind = "PostPassOpenSpaceRun"
				assignments[info.Model].RunTrigger = "QuickPassingPassAndMove"
				assignments[info.Model].SprintConservation = 0
				assignments[info.Model].MovementProfile = "SprintBurst"
				info.Model:SetAttribute("VTRBasicPossessionRole", "QuickPostPassRun")
				used[info.Model] = true
				runCount += 1
			elseif runUntil <= now and info.Model:GetAttribute("AIQuickPassingPostPassRun") == true then
				info.Model:SetAttribute("AIQuickPassingPostPassRun", false)
				info.Model:SetAttribute("VTRQuickPassRunTarget", nil)
				info.Model:SetAttribute("VTRQuickPassRunTrigger", nil)
			end
		end
	end
	for _, entry in ipairs(ranked) do
		local info = entry.Info
		if runCount < 2 and facingForward and (info.Role == "Winger" or info.Role == "ST" or info.Role == "CAM") and basicPassLaneBlocked(context, ownerInfo, info) then
			local target = runBehindTarget(context, info)
			assignments[info.Model] = makeAssignment(context, info, "BasicRunBehindBlockedLane", target, 1, true, context.BallWorld)
			assignments[info.Model].RunKind = "RunBehind"
			assignments[info.Model].RunTrigger = "DefenderBlockedLane"
			info.Model:SetAttribute("VTRBasicPossessionRole", "RunBehindBlockedLane")
			used[info.Model] = true
			runCount += 1
		end
	end
	if beside and not used[beside.Model] then
		local sideSign = beside.Pitch.X >= ballPitch.X and 1 or -1
		local target = basicSupportPoint(ballPitch, sideSign, 2, 34)
		assignments[beside.Model] = makeAssignment(context, beside, "BasicShortBesideOption", target, .96, true, context.BallWorld)
		beside.Model:SetAttribute("VTRBasicPossessionRole", "ShortBeside")
		used[beside.Model] = true
	end
	if angle and not used[angle.Model] then
		local sideSign = angle.Pitch.X >= ballPitch.X and 1 or -1
		if beside and sideSign == (beside.Pitch.X >= ballPitch.X and 1 or -1) then sideSign = -sideSign end
		local target = basicSupportPoint(ballPitch, sideSign, 18, 48)
		assignments[angle.Model] = makeAssignment(context, angle, "BasicSecondAngleOption", target, .9, true, context.BallWorld)
		angle.Model:SetAttribute("VTRBasicPossessionRole", "SecondAngle")
		used[angle.Model] = true
	end
	if behind and not used[behind.Model] then
		local target = Vector3.new(math.clamp(ballPitch.X + (behind.Pitch.X < ballPitch.X and -24 or 24), 58, 366), 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 6, ballPitch.Z - 38))
		assignments[behind.Model] = makeAssignment(context, behind, "BasicResetBehindOption", PitchConfig.ClampInsidePitch(target), .9, false, context.BallWorld)
		behind.Model:SetAttribute("VTRBasicPossessionRole", "ResetBehind")
		used[behind.Model] = true
	end
	if farWide and not used[farWide.Model] then
		local target = Vector3.new(sideLaneX(farWide, true), 3, onsideZ(context, side, math.max(farWide.BasePitch.Z, ballPitch.Z + 26)))
		assignments[farWide.Model] = makeAssignment(context, farWide, "BasicFarSideSwitchWidth", target, .82, true, context.BallWorld)
		farWide.Model:SetAttribute("VTRBasicPossessionRole", "FarSideSwitch")
		used[farWide.Model] = true
	end
	for _, info in ipairs(context.Teams[side].List) do
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignments[info.Model] = makeAssignment(context, info, "GoalkeeperPosition", target, 0.62, false)
		elseif info.Model == owner then
			assignments[info.Model] = makeAssignment(context, info, "BallCarrierDecision", info.Pitch + Vector3.new(0, 0, 16), 1, true)
			info.Model:SetAttribute("VTRBasicPossessionRole", "Carrier")
		elseif not used[info.Model] then
			local laneX = basicLaneCenter(info)
			local z = math.clamp(math.max(info.BasePitch.Z, ballPitch.Z + (info.Role == "ST" and 52 or info.Role == "Winger" and 32 or info.Role == "CM" and 16 or -28)), 62, onsideZ(context, side, 674))
			if info.Role == "CB" then z = math.max(PitchConfig.Zones.OwnBox.ZMax + 4, math.min(info.BasePitch.Z + 38, ballPitch.Z - 68)) end
			if info.Role == "Fullback" then z = math.max(PitchConfig.Zones.OwnBox.ZMax + 10, info.BasePitch.Z, math.min(ballPitch.Z - 8, 350)) end
			if info.Role == "CDM" then z = math.max(PitchConfig.Zones.OwnBox.ZMax + 18, ballPitch.Z - 28); laneX = PitchConfig.HALF_WIDTH end
			local duplicateOffset = 0
			for model, existing in pairs(assignments) do
				if model ~= info.Model and existing.TargetPitch and math.abs(existing.TargetPitch.X - laneX) < 24 and math.abs(existing.TargetPitch.Z - z) < 26 then
					duplicateOffset += 22
				end
			end
			local target = PitchConfig.ClampInsidePitch(Vector3.new(math.clamp(laneX + duplicateOffset, 36, 388), 3, z))
			assignments[info.Model] = makeAssignment(context, info, "BasicLaneAvailable", target, .76, false, context.BallWorld)
			info.Model:SetAttribute("VTRBasicPossessionRole", "LaneAvailable")
		end
		local assignment = assignments[info.Model]
		if assignment then
			assignment.Phase = phase
			info.Model:SetAttribute("TeamPlan", quickPassing and "Quick Passing" or "SAFE Possession")
		end
	end
	owner:SetAttribute("VTRBasicPossessionSafeOptions", math.min(#ranked, 2))
	owner:SetAttribute("VTRBasicPossessionRunsBehind", runCount)
	return true
end

local function assignCompactDefense(context: any, side: string, phase: string, assignments: any): boolean
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	local ballPitch = context.BallTeam[side]
	local incomingReceiver, incomingTarget = incomingPassThreat(context, side)
	local ownerPitch = ownerInfo and PitchConfig.WorldToTeamPitchPosition(ownerInfo.World, side, context.Options) or incomingTarget or ballPitch
	local dangerousReceiver, dangerousPitch = compactDangerReceiver(context, side, ownerPitch)
	local used = {}
	local directTargetWorld = incomingTarget and PitchConfig.TeamPitchPositionToWorld(incomingTarget, side, context.Options) or nil

	for _, info in ipairs(context.Teams[side].List) do
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignments[info.Model] = makeAssignment(context, info, "CompactGoalkeeperBehindLine", target, 0.68, false)
			used[info.Model] = true
		end
	end

	if incomingTarget and directTargetWorld then
		local first, cover, secondBall = nil, nil, nil
		local firstRank, coverRank, midRank = math.huge, math.huge, math.huge
		local receiverRole = incomingReceiver and incomingReceiver.Role or ""
		local wideIncoming = incomingTarget.X < 110 or incomingTarget.X > 314 or receiverRole == "Winger"
		for _, info in ipairs(context.Teams[side].List) do
			if not info.IsGoalkeeper and info.Root then
				local ballSideFullback = info.Role == "Fullback" and ((incomingTarget.X < PitchConfig.HALF_WIDTH and info.BasePitch.X < PitchConfig.HALF_WIDTH) or (incomingTarget.X >= PitchConfig.HALF_WIDTH and info.BasePitch.X > PitchConfig.HALF_WIDTH))
				local centralBack = info.Role == "CB"
				local isMid = info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM"
				local rank = compactPressureRank(context, info, directTargetWorld)
				local firstEligible = wideIncoming and ballSideFullback or (not wideIncoming and centralBack)
				local coverEligible = centralBack
				if firstEligible and rank < firstRank then
					first = info
					firstRank = rank
				elseif coverEligible and rank < coverRank then
					cover = info
					coverRank = rank
				end
				if isMid and rank < midRank then
					secondBall = info
					midRank = rank
				end
			end
		end
		if not first then
			local fallbackRank = math.huge
			for _, info in ipairs(context.Teams[side].List) do
				if not info.IsGoalkeeper and info.Root and (info.Role == "Fullback" or info.Role == "CB") then
					local rank = compactPressureRank(context, info, directTargetWorld)
					if rank < fallbackRank then
						first = info
						fallbackRank = rank
					end
				end
			end
		end
		if first then
			local target = PitchConfig.ClampInsidePitch(Vector3.new(incomingTarget.X, 3, math.max(32, incomingTarget.Z - 4)))
			assignments[first.Model] = makeAssignment(context, first, "CompactDirectPassAttackReceiver", target, 1, true, incomingReceiver and incomingReceiver.Model or nil)
			used[first.Model] = true
		end
		if cover and not used[cover.Model] then
			local target = PitchConfig.ClampInsidePitch(Vector3.new(incomingTarget.X + (PitchConfig.HALF_WIDTH - incomingTarget.X) * 0.35, 3, math.max(PitchConfig.Zones.OwnBox.ZMax, incomingTarget.Z - 30)))
			assignments[cover.Model] = makeAssignment(context, cover, "CompactDirectPassCoverBehind", target, 0.94, true, incomingReceiver and incomingReceiver.Model or nil)
			used[cover.Model] = true
		end
		if secondBall and not used[secondBall.Model] then
			local target = PitchConfig.ClampInsidePitch(Vector3.new(PitchConfig.HALF_WIDTH + (incomingTarget.X < PitchConfig.HALF_WIDTH and -22 or 22), 3, math.clamp(incomingTarget.Z + 18, 112, 420)))
			assignments[secondBall.Model] = makeAssignment(context, secondBall, "CompactSecondBallMidfielder", target, 0.92, true, incomingReceiver and incomingReceiver.Model or nil)
			used[secondBall.Model] = true
		end
	elseif ownerInfo and ownerInfo.Side ~= side then
		local ownerWorld = ownerInfo.World
		local presser, laneBlocker, cover = nil, nil, nil
		local presserScore = math.huge
		local ownerWideLeft = ownerPitch.X < 110
		local ownerWideRight = ownerPitch.X > 314
		local ownerWide = ownerWideLeft or ownerWideRight
		for _, info in ipairs(context.Teams[side].List) do
			if not info.IsGoalkeeper and info.Root then
				local isBack = info.Role == "CB" or info.Role == "Fullback"
				local ballSideFullback = info.Role == "Fullback" and ((ownerWideLeft and info.BasePitch.X < PitchConfig.HALF_WIDTH) or (ownerWideRight and info.BasePitch.X > PitchConfig.HALF_WIDTH))
				local canStepFromBack = ballPitch.Z <= PitchConfig.Zones.OwnBox.ZMax + 62 or ballSideFullback
				local roleBias = (info.Role == "ST" or info.Role == "Winger") and -18 or (info.Role == "CM" or info.Role == "CAM" or info.Role == "CDM") and -14 or ballSideFullback and -10 or info.Role == "Fullback" and 18 or info.Role == "CB" and 42 or 0
				local distance = PitchConfig.GetDistanceStuds(info.World, ownerWorld)
				local score = distance + roleBias
				if score < presserScore and (not isBack or canStepFromBack) then
					presser = info
					presserScore = score
				end
			end
		end
		local laneScore, coverScore = math.huge, math.huge
		for _, info in ipairs(context.Teams[side].List) do
			if not info.IsGoalkeeper and info.Root and (not presser or info.Model ~= presser.Model) then
				local isMid = info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM"
				local isWideScreen = info.Role == "Winger" or info.Role == "Fullback"
				local distance = PitchConfig.GetDistanceStuds(info.World, ownerWorld)
				local laneRoleBias = isMid and -22 or isWideScreen and ownerWide and -8 or info.Role == "CB" and 34 or 8
				local score = distance + laneRoleBias
				if score < laneScore then
					laneBlocker = info
					laneScore = score
				end
				local coverRoleBias = info.Role == "CDM" and -26 or info.Role == "CM" and -18 or info.Role == "CB" and 8 or 18
				local coverCandidateScore = math.abs(info.Pitch.X - PitchConfig.HALF_WIDTH) * 0.15 + math.abs(info.Pitch.Z - math.max(PitchConfig.Zones.OwnBox.ZMax + 8, ownerPitch.Z - 24)) + coverRoleBias
				if coverCandidateScore < coverScore then
					cover = info
					coverScore = coverCandidateScore
				end
			end
		end
		if presser then
			assignments[presser.Model] = makeAssignment(context, presser, "CompactPrimaryPresser", compactContainTarget(ownerPitch), 1, true, ownerInfo.Model)
			used[presser.Model] = true
		end
		if laneBlocker and not used[laneBlocker.Model] then
			local laneTarget = dangerousPitch and AIDefensiveDecisionService.BlockLaneTarget(ownerPitch, dangerousPitch) or Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(PitchConfig.Zones.OwnBox.ZMax + 8, ownerPitch.Z - 24))
			assignments[laneBlocker.Model] = makeAssignment(context, laneBlocker, "CompactForwardLaneBlock", laneTarget, 0.96, true, dangerousReceiver and dangerousReceiver.Model or ownerInfo.Model)
			used[laneBlocker.Model] = true
		end
		if cover and used[cover.Model] then
			local backup, backupScore = nil, math.huge
			for _, info in ipairs(context.Teams[side].List) do
				if not info.IsGoalkeeper and info.Root and not used[info.Model] then
					local roleBias = info.Role == "CDM" and -24 or info.Role == "CM" and -14 or info.Role == "CB" and 2 or 16
					local score = math.abs(info.Pitch.X - PitchConfig.HALF_WIDTH) * 0.12 + math.abs(info.Pitch.Z - math.max(PitchConfig.Zones.OwnBox.ZMax + 8, ownerPitch.Z - 28)) + roleBias
					if score < backupScore then
						backup = info
						backupScore = score
					end
				end
			end
			cover = backup
		end
		if cover and not used[cover.Model] then
			assignments[cover.Model] = makeAssignment(context, cover, "CompactCoverBehindPresser", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.92, true, ownerInfo.Model)
			used[cover.Model] = true
		end
	end

	for _, info in ipairs(context.Teams[side].List) do
		if not used[info.Model] then
			local target = compactShapeTarget(info, ballPitch)
			local assignmentName = "CompactDefensiveShape"
			if info.Role == "Fullback" and math.abs(ballPitch.X - info.Pitch.X) > 120 then
				assignmentName = "CompactFarSideTuckIn"
			elseif info.Role == "CB" then
				assignmentName = "CompactHoldBoxEdgeLine"
			elseif info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM" then
				assignmentName = "CompactMidfieldScreen"
			elseif info.Role == "Winger" or info.Role == "ST" then
				assignmentName = "CompactFirstLineScreen"
			end
			assignments[info.Model] = makeAssignment(context, info, assignmentName, target, 0.84, false, ownerInfo and ownerInfo.Model or context.BallWorld)
		end
		local assignment = assignments[info.Model]
		if assignment then
			assignment.Phase = phase
			info.Model:SetAttribute("TeamDefensiveIntent", "Compact Center Protection")
			info.Model:SetAttribute("AICompactDefensiveRole", assignment.PrimaryAssignment)
			info.Model:SetAttribute("AICompactLineZ", math.floor((assignment.TargetPitch and assignment.TargetPitch.Z or 0) + 0.5))
		end
	end
	return true
end

function Service:_assignLoose(context: any, side: string, phase: string, assignments: any)
	local chaser, cover = AILooseBallService.ChooseChasers(context, side)
	local ballSpeed = (context.BallVelocity and Vector3.new(context.BallVelocity.X, 0, context.BallVelocity.Z).Magnitude) or 0
	local projected = AILooseBallService.ProjectBall(context, ballSpeed > 20 and 0.38 or ballSpeed > 8 and 0.3 or 0.22)
	local ballPitch = context.BallTeam[side]
	local shotAgainst = (context.MotionKind == "Shot" or context.MotionKind == "Deflection")
		and tostring(context.LastTouchTeam or "") ~= ""
		and tostring(context.LastTouchTeam or "") ~= side
		and ballPitch.Z <= PitchConfig.HALF_LENGTH + 80
	if shotAgainst then
		local projectedPitch = PitchConfig.WorldToTeamPitchPosition(projected, side, context.Options)
		local shotTargetWorld = context.ShotTargetWorld or projected
		local shotTargetPitch = context.ShotTargetTeam and context.ShotTargetTeam[side] or PitchConfig.WorldToTeamPitchPosition(shotTargetWorld, side, context.Options)
		local dangerPitch = PitchConfig.ClampInsidePitch(Vector3.new(
			math.clamp(shotTargetPitch.X, PitchConfig.Zones.OwnBox.XMin + 8, PitchConfig.Zones.OwnBox.XMax - 8),
			3,
			math.clamp(math.min(projectedPitch.Z, shotTargetPitch.Z), 18, PitchConfig.Zones.OwnBox.ZMax + 12)
		))
		local keeperClosest = nil
		local keeperDistance = math.huge
		for _, info in ipairs(context.Teams[side].List) do
			if info.IsGoalkeeper and info.Root then
				local distance = math.min(PitchConfig.GetDistanceStuds(info.World, projected), PitchConfig.GetDistanceStuds(info.World, shotTargetWorld))
				if distance < keeperDistance then
					keeperClosest = info
					keeperDistance = distance
				end
			end
		end
		for _, info in ipairs(context.Teams[side].List) do
			local assignment
			if info.IsGoalkeeper then
				if keeperClosest == info and (keeperDistance <= 92 or projectedPitch.Z <= PitchConfig.Zones.OwnBox.ZMax + 58 or shotTargetPitch.Z <= PitchConfig.Zones.OwnBox.ZMax + 34) then
					assignment = makeAssignment(context, info, "ShotGoalkeeperClaim", dangerPitch, 1, true, context.BallWorld)
					assignment.SprintConservation = 0
					info.Model:SetAttribute("AIGoalkeeperLooseClaim", true)
					lockGoalkeeperAction(context, info, 0.65)
				else
					local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
					assignment = makeAssignment(context, info, "ShotGoalkeeperSet", target, 0.86, false, context.BallWorld)
					info.Model:SetAttribute("AIGoalkeeperLooseClaim", false)
				end
			else
				local baseX = info.BasePitch and info.BasePitch.X or info.Pitch.X
				local targetX = math.clamp(dangerPitch.X + (baseX - PitchConfig.HALF_WIDTH) * 0.22, 42, PitchConfig.PITCH_WIDTH - 42)
				local targetZ = math.max(28, math.min(PitchConfig.Zones.OwnBox.ZMax + 8, dangerPitch.Z + 10))
				local name = "ShotEmergencyRecoverBox"
				if info.Role == "CB" then
					targetX = baseX < PitchConfig.HALF_WIDTH and math.min(dangerPitch.X - 18, 188) or math.max(dangerPitch.X + 18, 236)
					targetZ = math.max(36, math.min(PitchConfig.Zones.OwnBox.ZMax + 2, dangerPitch.Z + 8))
					name = "ShotEmergencyCenterBackCover"
				elseif info.Role == "Fullback" then
					targetX = baseX < PitchConfig.HALF_WIDTH and math.min(112, dangerPitch.X - 42) or math.max(312, dangerPitch.X + 42)
					targetZ = PitchConfig.Zones.OwnBox.ZMax + 4
					name = "ShotEmergencyFullbackCover"
				elseif info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM" then
					targetX = info.Role == "CDM" and dangerPitch.X or (baseX < PitchConfig.HALF_WIDTH and math.min(dangerPitch.X - 28, 170) or math.max(dangerPitch.X + 28, 254))
					targetZ = PitchConfig.Zones.OwnBox.ZMax + 24
					name = "ShotEmergencyMidfieldSecondBall"
				elseif info.Role == "Winger" then
					targetX = baseX < PitchConfig.HALF_WIDTH and 112 or 312
					targetZ = PitchConfig.Zones.OwnBox.ZMax + 62
					name = "ShotEmergencyWideRecovery"
				elseif info.Role == "ST" then
					targetX = PitchConfig.HALF_WIDTH
					targetZ = PitchConfig.Zones.OwnBox.ZMax + 82
					name = "ShotEmergencyFirstLineRecover"
				end
				assignment = makeAssignment(context, info, name, PitchConfig.ClampInsidePitch(Vector3.new(targetX, 3, targetZ)), 0.94, true, context.BallWorld)
				assignment.SprintConservation = 0
				assignment.ShotTargetWorld = shotTargetWorld
				info.Model:SetAttribute("AIShotEmergencyTarget", shotTargetWorld)
			end
			assignment.Phase = "ShotEmergency"
			info.Model:SetAttribute("AIShotEmergencyDefense", true)
			assignments[info.Model] = assignment
		end
		return
	end
	local dangerZoneLooseBall = ballPitch.Z <= PitchConfig.Zones.OwnBox.ZMax + 72
	if dangerZoneLooseBall then
		local targetPitch = PitchConfig.WorldToTeamPitchPosition(projected, side, context.Options)
		for _, info in ipairs(context.Teams[side].List) do
			info.Model:SetAttribute("AIShotEmergencyDefense", false)
			info.Model:SetAttribute("AIShotEmergencyTarget", nil)
			local assignment
			if info.IsGoalkeeper then
				assignment = makeAssignment(context, info, "ShotGoalkeeperClaim", targetPitch, 1, true, context.BallWorld)
				assignment.SprintConservation = 0
				info.Model:SetAttribute("AIGoalkeeperLooseClaim", true)
				info.Model:SetAttribute("VTRGoalkeeperState", "SweepLooseBall")
				lockGoalkeeperAction(context, info, 0.65)
			else
				assignment = makeAssignment(context, info, "DangerZoneLooseBallRecovery", targetPitch, 1, true, context.BallWorld)
				assignment.SprintConservation = 0
				info.Model:SetAttribute("AIDangerZoneLooseBallRecovery", true)
			end
			assignment.Phase = "DangerZoneLooseBall"
			assignments[info.Model] = assignment
		end
		return
	end
	for _, info in ipairs(context.Teams[side].List) do
		info.Model:SetAttribute("AIShotEmergencyDefense", false)
		info.Model:SetAttribute("AIShotEmergencyTarget", nil)
		local assignment
		if info.IsGoalkeeper then
			if info == chaser then
				assignment = makeAssignment(context, info, "ShotGoalkeeperClaim", PitchConfig.WorldToTeamPitchPosition(projected, side, context.Options), 1, true, context.BallWorld)
				assignment.SprintConservation = 0
				info.Model:SetAttribute("AIGoalkeeperLooseClaim", true)
				lockGoalkeeperAction(context, info, 0.65)
			else
				local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
				assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.7, false)
				info.Model:SetAttribute("AIGoalkeeperLooseClaim", false)
			end
		elseif info == chaser then
			assignment = makeAssignment(context, info, "ChaseLooseBall", PitchConfig.WorldToTeamPitchPosition(projected, side, context.Options), 1, true)
			assignment.SprintConservation = 0
		elseif info == cover then
			assignment = makeAssignment(context, info, "CoverLooseBall", Vector3.new(ballPitch.X, 3, math.max(35, ballPitch.Z - 34)), 0.82, true)
		elseif info.Role == "ST" or info.Role == "Winger" then
			assignment = makeAssignment(context, info, "PrepareCounter", Vector3.new(info.BasePitch.X, 3, math.min(690, math.max(info.BasePitch.Z, ballPitch.Z + 80))), 0.78, true)
		elseif PitchConfig.InZone(ballPitch, "OwnBox") and (info.Role == "CB" or info.Role == "CDM") then
			assignment = makeAssignment(context, info, "ProtectGoal", Vector3.new(info.BasePitch.X, 3, 70), 0.86, true)
		else
			assignment = makeAssignment(context, info, "RecoverShape", defendingBase(info, ballPitch, self.Style), 0.74, false)
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:_assignAttack(context: any, side: string, phase: string, assignments: any)
	if isBasicPossessionStyle(self.Style) and assignBasicPossessionAttack(self, context, side, phase, assignments) then
		return
	end
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	local ballPitch = context.BallTeam[side]
	local list = context.Teams[side].List

	for _, info in ipairs(list) do
		local assignment
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.62, false)
		elseif info.Model == owner then
			assignment = makeAssignment(context, info, "BallCarrierDecision", info.Pitch + Vector3.new(0, 0, 18), 1, true)
			assignment.TeamStoryAction = storyName(context, side)
			info.Model:SetAttribute("AITacticalStoryAction", assignment.TeamStoryAction)
		else
			local name, target, urgency, sprint = attackingRoleTarget(context, info, ballPitch, ownerInfo, self.Style)
			if phase == "Transition_JustWonBall" and (info.Role == "ST" or info.Role == "Winger") and target.Z > ballPitch.Z then
				name = "CounterSprint"
				urgency = math.max(urgency, 0.94)
				sprint = true
			end
			assignment = makeAssignment(context, info, name, target, urgency, sprint)
			applyStoryAttack(context, info, assignment, ownerInfo)
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:_assignDefense(context: any, side: string, phase: string, assignments: any)
	if isBasicPossessionStyle(self.Style) and assignCompactDefense(context, side, phase, assignments) then
		return
	end
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	local ballPitch = context.BallTeam[side]
	for _, info in ipairs(context.Teams[side].List) do
		local assignment
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.72, false)
		else
			local name, target, urgency, sprint, mark = simpleDefensiveRoleTarget(context, info, ballPitch, ownerInfo, self.Style)
			assignment = makeAssignment(context, info, name, target, urgency, sprint, ownerInfo and ownerInfo.World or context.BallWorld)
			if mark then
				assignment.MarkTarget = mark
			end
			applyStoryDefense(context, info, assignment, ownerInfo)
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:Build(context: any, phases: {[string]: string}): any
	local assignments: any = {Home = {}, Away = {}}
	for _, side in ipairs({"Home", "Away"}) do
		local phase = phases[side] or "LooseBall"
		assignments[side] = self:BuildSide(context, side, phase)
	end
	return assignments
end

function Service:BuildSide(context: any, side: string, phase: string): any
	local assignments = {}
	if phase == "LooseBall" then
		self:_assignLoose(context, side, phase, assignments)
	elseif context.OwnerSide == side then
		self:_assignAttack(context, side, phase, assignments)
	else
		self:_assignDefense(context, side, phase, assignments)
		applyFullbackWingerCarrierPress(context, side, assignments)
	end
	applyReceiveOverrides(context, side, assignments, self.RunCoordinator)
	for _, assignment in assignments do applyPlayerInstructions(context, assignment.Info, assignment, context.OwnerSide == side) end
	applyReceiveOverrides(context, side, assignments, self.RunCoordinator)
	if context.OwnerSide == side then self.RunCoordinator:Coordinate(context, side, assignments) elseif phase ~= "LooseBall" then self.DefensiveCoordinator:Coordinate(context, side, assignments) end
	applyReceiveOverrides(context, side, assignments, self.RunCoordinator)
	if context.OwnerSide == side then
		applyPossessionSprintBoost(context, side, assignments)
	end
	local conservation = self.Style:Get("SprintConservation")
	for _, assignment in assignments do assignment.SprintConservation = math.min(tonumber(assignment.SprintConservation) or conservation, conservation) end
	return assignments
end

return Service
