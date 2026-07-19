--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIDifficultyService = require(script.Parent.AIDifficultyService)
local AIContextBuilder = require(script.Parent.AIContextBuilder)
local AIPassExecutionPlanner = require(script.Parent.AIPassExecutionPlanner)
local AIPassingDecisionService = require(script.Parent.AIPassingDecisionService)
local AIShootingDecisionService = require(script.Parent.AIShootingDecisionService)
local AIDribblingDecisionService = require(script.Parent.AIDribblingDecisionService)
local AITacklingDecisionService = require(script.Parent.AITacklingDecisionService)
local AIGoalkeeperService = require(script.Parent.AIGoalkeeperService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)

local Service = {}
Service.__index = Service

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function estimateReceiverSpeed(receiverInfo: any): number
	local pace = receiverInfo and receiverInfo.Stats and tonumber(receiverInfo.Stats.pace) or 65
	local stamina = math.clamp(receiverInfo and receiverInfo.Stamina or 75, 0, 100)
	return 18 + math.clamp((pace - 45) / 54, 0, 1) * 13 + math.clamp(stamina / 100, 0, 1) * 3
end

local function predictReceivePoint(context: any, receiverInfo: any, requestedTarget: Vector3): Vector3
	local receiverRoot = receiverInfo.Root
	if not receiverRoot then
		return requestedTarget
	end
	local ballPosition = context.BallWorld
	local ballVelocity = flat(context.BallVelocity or Vector3.zero)
	local ballSpeed = ballVelocity.Magnitude
	local receiverPosition = receiverInfo.World
	if ballSpeed < 1.5 then
		return Vector3.new(ballPosition.X, receiverPosition.Y, ballPosition.Z)
	end

	local direction = ballVelocity.Unit
	local toReceiver = flat(receiverPosition - ballPosition)
	local along = toReceiver:Dot(direction)
	local receiverSpeed = estimateReceiverSpeed(receiverInfo)
	local bestPoint = ballPosition + direction * math.clamp(along + 8, 5, 70)
	local bestScore = math.huge

	for step = 1, 18 do
		local t = step * 0.12
		local travel = ballSpeed * t
		local projected = ballPosition + direction * travel
		local distanceToProjected = PitchConfig.GetDistanceStuds(receiverPosition, projected)
		local reachableGap = distanceToProjected - receiverSpeed * t
		local targetBias = PitchConfig.GetDistanceStuds(projected, requestedTarget) * 0.12
		local behindPenalty = travel < math.max(0, along - 2) and 80 or 0
		local score = math.abs(reachableGap) + targetBias + behindPenalty
		if reachableGap <= 3 then
			score -= 16
		end
		if score < bestScore then
			bestScore = score
			bestPoint = projected
		end
	end

	local currentBallDistance = PitchConfig.GetDistanceStuds(receiverPosition, ballPosition)
	if along < -4 and currentBallDistance < 18 then
		bestPoint = ballPosition + direction * math.clamp(ballSpeed * 0.18, 2, 14)
	elseif along < 2 then
		bestPoint = ballPosition + direction * math.clamp(ballSpeed * 0.22, 4, 18)
	end
	return Vector3.new(bestPoint.X, receiverPosition.Y, bestPoint.Z)
end

local function cutPassCoursePoint(context: any, receiverInfo: any, requestedTarget: Vector3): Vector3
	local velocity=flat(context.BallVelocity or Vector3.zero)
	local ball=context.BallWorld
	if velocity.Magnitude<2 then
		return requestedTarget
	end
	local direction=velocity.Unit
	local toTarget=flat(requestedTarget-ball)
	local remaining=toTarget.Magnitude
	if remaining<3 then
		return requestedTarget
	end
	local cutDistance=math.clamp(remaining*.9,5,58)
	if remaining<18 then
		cutDistance=math.max(remaining*.58,3.5)
	end
	local cut=ball+direction*cutDistance
	local receiverToCut=PitchConfig.GetDistanceStuds(receiverInfo.World,cut)
	local receiverToTarget=PitchConfig.GetDistanceStuds(receiverInfo.World,requestedTarget)
	if receiverToCut>receiverToTarget+26 and remaining>22 then
		cut=ball+direction*math.clamp(remaining*.72,5,42)
	end
	return Vector3.new(cut.X,receiverInfo.World.Y,cut.Z)
end

local function chooseBoxCross(context: any, carrier: any): any?
	if carrier.Role ~= "Winger" or carrier.Pitch.Z < 610 or not (carrier.Pitch.X < 105 or carrier.Pitch.X > 319) then
		return nil
	end
	local best = nil
	local bestScore = -math.huge
	for _, receiver in ipairs(context.Teams[carrier.Side].List) do
		if receiver.Model ~= carrier.Model and receiver.Root and not receiver.IsGoalkeeper and receiver.Pitch.Z >= 570 and receiver.Pitch.Z <= 690 and receiver.Pitch.X >= 118 and receiver.Pitch.X <= 306 then
			local pressure = AIContextBuilder.Pressure(context, receiver)
			local score = (receiver.Role == "ST" and 80 or receiver.Role == "CAM" and 64 or receiver.Role == "CM" and 48 or 34)
			score += receiver.Stats.finishing * 0.3 + receiver.Stats.overall * 0.12
			score -= pressure.Score * 18
			if score > bestScore then
				bestScore = score
				best = receiver
			end
		end
	end
	if not best then
		return nil
	end
	local farPostX = carrier.Pitch.X < PitchConfig.HALF_WIDTH and 284 or 140
	local leadZ = math.clamp(math.max(best.Pitch.Z + 10, 622), 610, 682)
	local targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(best.Pitch.X + (farPostX - best.Pitch.X) * 0.35, 3, leadZ))
	local target = PitchConfig.TeamPitchPositionToWorld(targetPitch, carrier.Side, context.Options)
	return {
		Receiver = best,
		Score = bestScore + 120,
		Kind = "Forward",
		PassKind = "Lofted",
		Target = target,
		Distance = PitchConfig.GetDistanceStuds(carrier.World, target),
		LaneClear = true,
		Safe = true,
		ForwardGain = targetPitch.Z - carrier.Pitch.Z,
		Stage = AIContextBuilder.AttackStage(context, carrier.Side),
		DefensiveMood = AIContextBuilder.DefensiveMood(context, carrier.Side, carrier),
	}
end

local function closestTeammateToTarget(context: any, passer: any, target: Vector3): any?
	local best = nil
	local bestScore = math.huge
	for _, teammate in ipairs(context.Teams[passer.Side].List) do
		if teammate.Model ~= passer.Model and teammate.Root and not teammate.IsGoalkeeper then
			local distance = PitchConfig.GetDistanceStuds(teammate.World, target)
			if distance < bestScore then
				best = teammate
				bestScore = distance
			end
		end
	end
	return best
end

local function distanceToPassSegment(start: Vector3, target: Vector3, point: Vector3): (number, Vector3, number)
	local segment = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
	local offset = Vector3.new(point.X - start.X, 0, point.Z - start.Z)
	local lengthSq = segment:Dot(segment)
	local alpha = lengthSq > 0.001 and math.clamp(offset:Dot(segment) / lengthSq, 0, 1) or 0
	local closest = start + segment * alpha
	return PitchConfig.GetDistanceStuds(point, closest), Vector3.new(closest.X, point.Y, closest.Z), alpha
end

local function alternatePassChasers(context: any, passer: any, primary: any?, target: Vector3): {any}
	local scored = {}
	for _, teammate in ipairs(context.Teams[passer.Side].List) do
		if teammate.Model ~= passer.Model and teammate.Root and not teammate.IsGoalkeeper and (not primary or teammate.Model ~= primary.Model) then
			local lateral, intercept, alpha = distanceToPassSegment(passer.World, target, teammate.World)
			local targetDistance = PitchConfig.GetDistanceStuds(teammate.World, target)
			if lateral <= 28 or targetDistance <= 38 then
				local stamina = tonumber(teammate.Model:GetAttribute("VTRSprintEnergy")) or teammate.Stamina or 75
				local score = lateral + targetDistance * 0.22 - alpha * 8 - math.clamp(stamina, 0, 100) * 0.025
				table.insert(scored, {Info = teammate, Target = targetDistance <= 18 and target or intercept, Score = score})
			end
		end
	end
	table.sort(scored, function(a, b) return a.Score < b.Score end)
	local result = {}
	for index = 1, math.min(2, #scored) do
		table.insert(result, scored[index])
	end
	return result
end

local function primePassChaser(model: Model, target: Vector3, now: number, ballEta: number?, routeEta: number?, primary: boolean)
	local receiveUntil = now + math.clamp((ballEta or 1.1) + (primary and 1.6 or 1.05), 1.15, primary and 5.6 or 3.8)
	model:SetAttribute("VTRPrepareToReceive", nil)
	model:SetAttribute("VTRPotentialReceiveTarget", nil)
	model:SetAttribute("VTRPrepareReceiveUntil", nil)
	model:SetAttribute("VTRReceiveTarget", target)
	model:SetAttribute("VTRReceiveIntercept", target)
	model:SetAttribute("VTRReceiveUntil", receiveUntil)
	model:SetAttribute("VTRReceiveBallETA", ballEta or 0.8)
	model:SetAttribute("VTRReceiveReceiverETA", routeEta or 0.7)
	model:SetAttribute("VTRReceiveOpponentETA", math.huge)
	model:SetAttribute("VTRReceiveRouteConfidence", primary and 0.92 or 0.72)
	model:SetAttribute("VTRReceiveRouteSprintRequested", true)
	model:SetAttribute("VTRReceiveDistance", 0)
	model:SetAttribute("VTRPreparingReceive", true)
	model:SetAttribute("VTRReceiveCommitted", primary)
	model:SetAttribute("VTRReceiveLockedAt", now)
	model:SetAttribute("VTRReceiveHardLock", primary)
	model:SetAttribute("VTRReceiveHardLockUntil", receiveUntil)
	model:SetAttribute("VTRAITargetedPass", primary)
	model:SetAttribute("VTRAIAlternatePassChaser", not primary)
	model:SetAttribute("VTRRunTicketId", nil)
	model:SetAttribute("VTRRunApproved", false)
	model:SetAttribute("currentAssignment", "ReceivePass")
	model:SetAttribute("SupportRole", "ReceivePass")
	model:SetAttribute("AttackAssignment", "ReceivePass")
	model:SetAttribute("TeamPhase", "PassReception")
end

function Service.new(ballService: any, style: any, difficulty: any)
	return setmetatable({BallService = ballService, Style = style, Difficulty = difficulty, NextDecision = {}, CarrySince = {}, LastAction = {}, Random = Random.new(), ImmediateReceiverRoute = nil}, Service)
end

function Service:SetImmediateReceiverRoute(callback: any)
	self.ImmediateReceiverRoute = callback
end

function Service:_kickPass(context: any, passer: any, pass: any): boolean
	if not passer.Root or not pass then
		return false
	end
	if not pass.Receiver or not pass.Receiver.Model or not pass.Receiver.Root then
		pass.Receiver = closestTeammateToTarget(context, passer, pass.Target or passer.World)
		if not pass.Receiver then
			return false
		end
	end
	local direction = pass.Target - passer.Root.Position
	local execution = AIPassExecutionPlanner.Plan(context, passer, pass, self.Style, self.Difficulty)
	if not execution then return false end
	pass.Target = execution.Target
	pass.Distance = execution.Distance
	direction = pass.Target - passer.Root.Position
	if direction.Magnitude < 4 then return false end
	local passKind = pass.PassKind == "Through" and "Through" or (pass.PassKind == "Lofted" or pass.PassKind == "FarPostCross") and "Lofted" or "Ground"
	local power = execution.Power
	local receiverModel = pass.Receiver and pass.Receiver.Model
	if receiverModel and receiverModel.Parent then
		local now = context.Now or os.clock()
		receiverModel:SetAttribute("VTRPrepareToReceive", true)
		receiverModel:SetAttribute("VTRPotentialReceiveTarget", pass.Target)
		receiverModel:SetAttribute("VTRPrepareReceiveUntil", now + math.clamp((execution.BallETA or .8) * .55, .22, .7))
		receiverModel:SetAttribute("VTRReceiveCommitted", false)
	end
	local alternates = alternatePassChasers(context, passer, pass.Receiver, execution.InterceptPoint or pass.Target)
	passer.Model:SetAttribute("AIPassCentralLane", pass.MiddlePass == true)
	passer.Model:SetAttribute("AIPassMiddleOutnumbered", pass.MiddleOutnumbered == true)
	passer.Model:SetAttribute("AIPassWingEscape", pass.WingEscape == true)
	passer.Model:SetAttribute("AIPassMiddleMemory", AIPassingDecisionService.GetMiddleMistakeMemory and AIPassingDecisionService.GetMiddleMistakeMemory(passer.Model) or 0)
	local kicked = self.BallService:Kick(passer.Model, "Pass", direction, power, pass.Receiver.Model, passKind, pass.Distance or direction.Magnitude, pass.Target)
	if kicked then
		if receiverModel and receiverModel.Parent then
			local now = context.Now or os.clock()
			local receiveUntil = now + math.clamp((execution.BallETA or 1.1) + 1.35, 1.2, 5.2)
			local sprint = tostring(execution.SelectedLocomotionMode or "") == "SprintBurst"
			receiverModel:SetAttribute("VTRPrepareToReceive", nil)
			receiverModel:SetAttribute("VTRPotentialReceiveTarget", nil)
			receiverModel:SetAttribute("VTRPrepareReceiveUntil", nil)
			receiverModel:SetAttribute("VTRReceiveTarget", pass.Target)
			receiverModel:SetAttribute("VTRReceiveIntercept", execution.InterceptPoint or pass.Target)
			receiverModel:SetAttribute("VTRReceiveUntil", receiveUntil)
			receiverModel:SetAttribute("VTRReceiveBallETA", execution.BallETA)
			receiverModel:SetAttribute("VTRReceiveReceiverETA", execution.ReceiverETA)
			receiverModel:SetAttribute("VTRReceiveOpponentETA", execution.OpponentETA)
			receiverModel:SetAttribute("VTRReceiveRouteConfidence", math.clamp(tonumber(execution.Viability) or 0.7, 0, 1))
			receiverModel:SetAttribute("VTRReceiveRouteSprintRequested", sprint)
			receiverModel:SetAttribute("VTRReceiveDistance", PitchConfig.GetDistanceStuds(pass.Receiver.World, pass.Target))
			receiverModel:SetAttribute("VTRPreparingReceive", true)
			receiverModel:SetAttribute("VTRReceiveCommitted", true)
			receiverModel:SetAttribute("VTRReceiveLockedAt", now)
			receiverModel:SetAttribute("VTRAITargetedPass", true)
			receiverModel:SetAttribute("VTRRunTicketId", nil)
			receiverModel:SetAttribute("VTRRunApproved", false)
			receiverModel:SetAttribute("VTRReceiveLocomotionMode", execution.SelectedLocomotionMode)
			receiverModel:SetAttribute("VTRReceiveDesiredArrivalVelocity", execution.DesiredArrivalVelocity)
			receiverModel:SetAttribute("VTRReceiveBrakingDistance", execution.BrakingDistance)
			receiverModel:SetAttribute("VTRReceiveContactKind", execution.ContactKind)
			receiverModel:SetAttribute("VTRReceivePreferredFoot", execution.PreferredFoot)
			receiverModel:SetAttribute("VTRFirstTouchIntent", execution.FirstTouchIntent)
			receiverModel:SetAttribute("currentAssignment", "ReceivePass")
			receiverModel:SetAttribute("SupportRole", "ReceivePass")
			receiverModel:SetAttribute("AILastPasserRole", passer.Role)
			receiverModel:SetAttribute("AILastPasserName", passer.Model.Name)
			receiverModel:SetAttribute("AILastPassReceivedAt", now)
			if self.ImmediateReceiverRoute then
				self.ImmediateReceiverRoute(receiverModel, execution.InterceptPoint or pass.Target, passKind, execution)
			end
		end
		local now = context.Now or os.clock()
		for _, alternate in ipairs(alternates) do
			local info = alternate.Info
			if info and info.Model and info.Model.Parent then
				local routeTarget = alternate.Target or execution.InterceptPoint or pass.Target
				local eta = info.Root and PitchConfig.GetDistanceStuds(info.World, routeTarget) / math.max(22, tonumber(info.Stats and info.Stats.pace) or 60) or execution.ReceiverETA
				primePassChaser(info.Model, routeTarget, now, execution.BallETA, eta, false)
				if self.ImmediateReceiverRoute then
					self.ImmediateReceiverRoute(info.Model, routeTarget, passKind, {
						BallETA = execution.BallETA,
						ReceiverETA = eta,
						SelectedLocomotionMode = "SprintBurst",
						DesiredArrivalVelocity = execution.DesiredArrivalVelocity,
						BrakingDistance = execution.BrakingDistance,
						ContactKind = execution.ContactKind,
						PreferredFoot = execution.PreferredFoot,
					})
				end
			end
		end
		pass.Receiver.Model:SetAttribute("AIPassAlternateChasers", #alternates)
		pass.Receiver.Model:SetAttribute("AIDebugExpectedPass", true)
		pass.Receiver.Model:SetAttribute("AIDebugPassTarget", pass.Target)
		pass.Receiver.Model:SetAttribute("AIDebugPassKind", pass.PassKind or "Ground")
		pass.Receiver.Model:SetAttribute("AIDebugPassScore", pass.Score or 0)
		pass.Receiver.Model:SetAttribute("AIDebugBallETA", execution.BallETA)
		pass.Receiver.Model:SetAttribute("AIDebugReceiverETA", execution.ReceiverETA)
		pass.Receiver.Model:SetAttribute("AIDebugOpponentETA", execution.OpponentETA)
		self.LastAction[passer.Model] = (pass.PassKind == "LowCross" or pass.PassKind == "FarPostCross") and "Cross" or pass.PassKind == "Cutback" and "Cutback" or pass.PassKind == "Through" and "ThroughPass" or "Pass"
	end
	return kicked
end

function Service:_shoot(context: any, shooter: any, shot: any): boolean
	if not shooter.Root then
		return false
	end
	local direction = shot.Target - shooter.Root.Position
	local charge = math.clamp(0.46 + shooter.Stats.shotPower / 240 + (shot.Distance or 80) / 420, 0.45, 0.86) * 0.5
	local kicked = self.BallService:Kick(shooter.Model, "Shot", direction, charge, nil, nil, nil, shot.Target)
	if kicked then
		self.LastAction[shooter.Model] = "Shot"
	end
	return kicked
end

function Service:_tryMidfieldLongShot(context: any, carrier: any, pressure: any): boolean
	if not carrier.Root or pressure.Heavy or pressure.Closest <= 24 then
		return false
	end
	if carrier.Role ~= "CM" and carrier.Role ~= "CAM" and carrier.Role ~= "CDM" then
		return false
	end
	if carrier.Pitch.Z < 540 or carrier.Pitch.Z > 610 or carrier.Pitch.X < 125 or carrier.Pitch.X > 299 then
		return false
	end
	if self.Random:NextNumber() > 0.03 then
		return false
	end
	local attackSign = context.AttackSigns and context.AttackSigns[carrier.Side] or PitchConfig.GetAttackDirection(carrier.Side, context.Options)
	local rectangle = GoalModelResolver.ResolveByAttackSign(attackSign, context.PitchCFrame, context.Width, context.Length)
	local width = math.max(1, rectangle.RightBound - rectangle.Left)
	local height = math.max(1, rectangle.Top - rectangle.Bottom)
	local side = self.Random:NextNumber() < 0.5 and rectangle.Left + width * 0.28 or rectangle.RightBound - width * 0.28
	local target = GoalModelResolver.Point(rectangle, side, rectangle.Bottom + height * 0.48)
	carrier.Model:SetAttribute("VTRLongShotGoalChance", 0.1)
	carrier.Model:SetAttribute("VTRLongShotChanceUntil", context.Now + 2.8)
	local shot = {
		Target = target,
		Distance = PitchConfig.GetDistanceStuds(carrier.World, target),
	}
	if self:_shoot(context, carrier, shot) then
		self.LastAction[carrier.Model] = "MidfieldLongShot"
		return true
	end
	carrier.Model:SetAttribute("VTRLongShotGoalChance", nil)
	carrier.Model:SetAttribute("VTRLongShotChanceUntil", nil)
	return false
end

function Service:_clear(context: any, carrier: any): boolean
	local forward = context.PitchCFrame.LookVector * (context.AttackSigns[carrier.Side] or 1)
	local kicked = self.BallService.Clearance and self.BallService:Clearance(carrier.Model, forward) or false
	if kicked then
		self.LastAction[carrier.Model] = "Clearance"
	end
	return kicked
end

function Service:_carrierDecision(context: any, carrier: any, assignment: any)
	if carrier.IsUserControlled or not carrier.Root then
		return
	end
	local now = context.Now or os.clock()
	if (tonumber(carrier.Model:GetAttribute("VTRNoAutoPassUntil")) or 0) > now then
		return
	end
	if not self.CarrySince[carrier.Model] then
		self.CarrySince[carrier.Model] = tonumber(carrier.Model:GetAttribute("VTRReceivedAt")) or now
	end
	local carriedFor = now - (self.CarrySince[carrier.Model] or now)
	local pressure = AIContextBuilder.Pressure(context, carrier)
	local attackStage = AIContextBuilder.AttackStage(context, carrier.Side)
	local defensiveMood = AIContextBuilder.DefensiveMood(context, carrier.Side, carrier)
	local wingerWide = carrier.Role == "Winger" and (carrier.Pitch.X < 100 or carrier.Pitch.X > 324)
	local wingerEndLine = wingerWide and carrier.Pitch.Z > 675
	local wingerChanceZone = wingerWide and carrier.Pitch.Z >= 610
	local passTempo = math.min(self.Style:Ratio("PassTempo"), tonumber(context.FirstMatchPassTempoCap) or 1)
	local firstMatchAssistance = math.clamp(tonumber(context.FirstMatchAssistance) or 0, 0, 1)
	local firstTouchDirectness = self.Style:Ratio("FirstTouchDirectness")
	local possessionPatience = self.Style:Ratio("PossessionPatience")
	local drawPressure = self.Style:Ratio("DrawPressureBias")
	local oneTouchPassing = self.Style:Ratio("OneTouchPassing")
	local minimumHoldTime = math.max(0.18, self.Style:Get("MinimumHoldTime"))
	local maximumHoldTime = self.Style:Get("MaximumHoldTime")
	if maximumHoldTime < minimumHoldTime then
		maximumHoldTime = minimumHoldTime
	end
	local holdLimit = pressure.Under and (0.38 - passTempo * 0.2) or (1.05 - passTempo * 0.52 - firstTouchDirectness * 0.22)
	holdLimit += possessionPatience * 0.55 + drawPressure * (pressure.None and 0.16 or pressure.Under and 0.32 or 0)
	holdLimit -= oneTouchPassing * math.clamp(firstTouchDirectness, 0, 1) * 0.2
	if defensiveMood == "Passive" then
		holdLimit += 0.45
	elseif defensiveMood == "Pressing" then
		holdLimit = math.min(holdLimit, 0.52)
	elseif defensiveMood == "AggressiveRisk" then
		holdLimit = math.min(holdLimit, 0.32)
	end
	if wingerEndLine then
		holdLimit = math.min(holdLimit, 0.12)
	elseif wingerChanceZone then
		holdLimit = math.min(holdLimit, 0.34)
	elseif wingerWide and carrier.Pitch.Z >= 495 then
		holdLimit = math.min(holdLimit, 0.5)
	end
	local story = context.TeamStories and context.TeamStories[carrier.Side]
	local storyMovement = tostring(story and story.Movement or "")
	local storyAction = tostring(story and story.Action or "")
	if storyMovement == "Counter" or storyMovement == "CounterWide" or storyMovement == "CounterCentral" or storyMovement == "Release" or storyMovement == "Chance" or storyMovement == "FinalPress" then
		holdLimit = math.min(holdLimit, 0.42)
	elseif storyMovement == "Recycle" or storyMovement == "Secure" or storyMovement == "Safe" then
		holdLimit = math.max(holdLimit, pressure.Under and 0.42 or 0.78)
	elseif storyMovement == "Cross" and carrier.Role == "Winger" then
		holdLimit = math.min(holdLimit, 0.28)
	elseif storyMovement == "Direct" or storyMovement == "Target" then
		holdLimit = math.min(holdLimit, 0.55)
	end
	holdLimit = math.clamp(holdLimit, minimumHoldTime, maximumHoldTime)
	local nextDecision = self.NextDecision[carrier.Model] or 0
	carrier.Model:SetAttribute("AIPressureScore", pressure.Score)
	carrier.Model:SetAttribute("AIHeavyPressure", pressure.Heavy)
	carrier.Model:SetAttribute("AICarriedFor", carriedFor)
	carrier.Model:SetAttribute("AIHoldLimit", holdLimit)
	carrier.Model:SetAttribute("AIMinimumHoldTime", minimumHoldTime)
	carrier.Model:SetAttribute("AIMaximumHoldTime", maximumHoldTime)
	carrier.Model:SetAttribute("AIAttackStage", attackStage)
	carrier.Model:SetAttribute("AIDefensiveMood", defensiveMood)
	carrier.Model:SetAttribute("AICarryIntoSpace", false)
	carrier.Model:SetAttribute("AITacticalStoryAction", storyAction)
	if (tonumber(carrier.Model:GetAttribute("VTRKickoffReturnUntil")) or 0) > now and carriedFor >= 0.03 then
		local kickoffReturn = AIPassingDecisionService.ChooseKickoffReturn(context, carrier, self.Style, self.Difficulty)
		if kickoffReturn and self:_kickPass(context, carrier, kickoffReturn) then
			carrier.Model:SetAttribute("VTRKickoffReturnUntil", nil)
			self.CarrySince[carrier.Model] = nil
			return
		end
	end
	if carrier.IsGoalkeeper then
		local playKeeper = carrier.Model:GetAttribute("VTRFiveVFiveAIKeeper") == true
		local waitDone = playKeeper or carriedFor >= 0.35 or pressure.Under or pressure.Heavy
		if not waitDone then
			assignment.TargetWorld = AIGoalkeeperService.PositionTarget(context, carrier)
			assignment.MovementTarget = assignment.TargetWorld
			assignment.PrimaryAssignment = "GoalkeeperDistribution"
			assignment.MovementUrgency = 0.66
			self.LastAction[carrier.Model] = "HoldForDistribution"
			return
		end
		local distribution = AIGoalkeeperService.ChooseDistribution(context, carrier)
		if distribution and self:_kickPass(context, carrier, distribution) then
			self.CarrySince[carrier.Model] = nil
			return
		end
		if self:_clear(context, carrier) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	end
	if now < nextDecision and carriedFor < holdLimit and not pressure.Under and not pressure.Heavy then
		local dribble = AIDribblingDecisionService.Evaluate(context, carrier, self.Style)
		assignment.TargetWorld = dribble.Target
		assignment.MovementTarget = dribble.Target
		assignment.PrimaryAssignment = "DribbleSupport"
		assignment.MovementUrgency = 1
		assignment.SprintAllowed = true
		self.LastAction[carrier.Model] = "Carry"
		return
	end

	self.NextDecision[carrier.Model] = now + math.max(0.04, math.min(AIDifficultyService.NextDecisionDelay(self.Difficulty) * (0.72 - passTempo * 0.42) * (1 + firstMatchAssistance * .35), holdLimit * 0.65))

	if carrier.Role == "Winger" and wingerWide and carrier.Pitch.Z >= 520 and pressure.Closest > 18 then
		local diagonalX = carrier.Pitch.X < PitchConfig.HALF_WIDTH and 154 or 270
		local diagonalZ = math.min(PitchConfig.PITCH_LENGTH - 45, math.max(carrier.Pitch.Z + 36, 650))
		local diagonalPitch = PitchConfig.ClampInsidePitch(Vector3.new(diagonalX, 3, diagonalZ))
		local straightPitch = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X, 3, PitchConfig.PITCH_LENGTH - 20))
		local diagonalSpace = AIContextBuilder.SpaceAt(context, carrier.Side, diagonalPitch, 22)
		local straightSpace = AIContextBuilder.SpaceAt(context, carrier.Side, straightPitch, 24)
		if diagonalSpace then
			local target = PitchConfig.TeamPitchPositionToWorld(diagonalPitch, carrier.Side, context.Options)
			assignment.TargetWorld = target
			assignment.MovementTarget = target
			assignment.PrimaryAssignment = "WingerDiagonalGoalCarry"
			assignment.MovementUrgency = 1
			assignment.SprintAllowed = true
			carrier.Model:SetAttribute("AIWingerAttackLane", "DiagonalGoal")
			carrier.Model:SetAttribute("AIWingerTargetGoalDistance", PitchConfig.PITCH_LENGTH - diagonalPitch.Z)
			self.LastAction[carrier.Model] = "WingerDiagonalGoalCarry"
			return
		elseif straightSpace and carrier.Pitch.Z < PitchConfig.PITCH_LENGTH - 24 then
			local target = PitchConfig.TeamPitchPositionToWorld(straightPitch, carrier.Side, context.Options)
			assignment.TargetWorld = target
			assignment.MovementTarget = target
			assignment.PrimaryAssignment = "WingerEndLineCarry"
			assignment.MovementUrgency = 1
			assignment.SprintAllowed = true
			carrier.Model:SetAttribute("AIWingerAttackLane", "EndLine")
			carrier.Model:SetAttribute("AIWingerTargetGoalDistance", PitchConfig.PITCH_LENGTH - straightPitch.Z)
			self.LastAction[carrier.Model] = "WingerEndLineCarry"
			return
		else
			carrier.Model:SetAttribute("AIWingerAttackLane", "")
		end
	end

	local boxCross = chooseBoxCross(context, carrier)
	local wingerPass = boxCross or AIPassingDecisionService.ChooseWingerWide(context, carrier, self.Style, self.Difficulty)
	carrier.Model:SetAttribute("AIWingerWideDecision", wingerPass and wingerPass.PassKind or "")
	if wingerPass and (wingerEndLine or wingerChanceZone or pressure.Under or wingerPass.Score > 390) then
		if self:_kickPass(context, carrier, wingerPass) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	end

	local strikerInDangerZone = carrier.Role == "ST" and PitchConfig.InZone(carrier.Pitch, "OpponentBox")
	local strikerUnderClosePressure = carrier.Role == "ST" and pressure.Closest <= 15
	local strikerGoalDistance = PitchConfig.PITCH_LENGTH - carrier.Pitch.Z
	local strikerCanDriveDeeper = false
	local strikerDriveChance = 0
	if carrier.Role == "ST" and strikerInDangerZone and not strikerUnderClosePressure and strikerGoalDistance > 50 then
		local depthAlpha = math.clamp((132 - strikerGoalDistance) / 82, 0, 1)
		strikerDriveChance = math.clamp(0.3 + depthAlpha * 0.7, 0.3, 1)
		local deeperZ = math.max(carrier.Pitch.Z + 18, PitchConfig.PITCH_LENGTH - math.max(50, strikerGoalDistance - 24))
		local deeperPitch = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X + (PitchConfig.HALF_WIDTH - carrier.Pitch.X) * 0.18, 3, math.min(deeperZ, PitchConfig.PITCH_LENGTH - 45)))
		strikerCanDriveDeeper = AIContextBuilder.SpaceAt(context, carrier.Side, deeperPitch, 18)
		carrier.Model:SetAttribute("AIStrikerDriveDeeperChance", strikerDriveChance)
		carrier.Model:SetAttribute("AIStrikerGoalDistance", strikerGoalDistance)
		carrier.Model:SetAttribute("AIStrikerDriveDeeperSpace", strikerCanDriveDeeper)
		if strikerCanDriveDeeper and self.Random:NextNumber() <= strikerDriveChance then
			local target = PitchConfig.TeamPitchPositionToWorld(deeperPitch, carrier.Side, context.Options)
			assignment.TargetWorld = target
			assignment.MovementTarget = target
			assignment.PrimaryAssignment = "StrikerDriveDeeperForShot"
			assignment.MovementUrgency = 1
			assignment.SprintAllowed = true
			carrier.Model:SetAttribute("AIStrikerBoxShootNow", false)
			self.LastAction[carrier.Model] = "StrikerDriveDeeperForShot"
			return
		end
	else
		carrier.Model:SetAttribute("AIStrikerDriveDeeperChance", 0)
		carrier.Model:SetAttribute("AIStrikerGoalDistance", strikerGoalDistance)
		carrier.Model:SetAttribute("AIStrikerDriveDeeperSpace", false)
	end
	if strikerInDangerZone then
		local immediateShot = AIShootingDecisionService.Evaluate(context, carrier, self.Style, self.Difficulty)
		carrier.Model:SetAttribute("AIStrikerBoxShootNow", true)
		carrier.Model:SetAttribute("AIStrikerEscapePressure", false)
		carrier.Model:SetAttribute("AIStrikerEscapePassReceiver", "")
		carrier.Model:SetAttribute("AIStrikerEscapePassKind", "")
		if self:_shoot(context, carrier, immediateShot) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	elseif strikerUnderClosePressure then
		local strikerEscapePass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, true)
		carrier.Model:SetAttribute("AIStrikerBoxShootNow", false)
		carrier.Model:SetAttribute("AIStrikerEscapePressure", true)
		carrier.Model:SetAttribute("AIStrikerEscapePassReceiver", strikerEscapePass and strikerEscapePass.Receiver and strikerEscapePass.Receiver.Model.Name or "")
		carrier.Model:SetAttribute("AIStrikerEscapePassKind", strikerEscapePass and strikerEscapePass.PassKind or "")
		if strikerEscapePass and self:_kickPass(context, carrier, strikerEscapePass) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	else
		carrier.Model:SetAttribute("AIStrikerBoxShootNow", false)
		carrier.Model:SetAttribute("AIStrikerEscapePressure", false)
		carrier.Model:SetAttribute("AIStrikerEscapePassReceiver", "")
		carrier.Model:SetAttribute("AIStrikerEscapePassKind", "")
	end

	local shot = AIShootingDecisionService.Evaluate(context, carrier, self.Style, self.Difficulty)
	carrier.Model:SetAttribute("AIShotScore", shot.Score)
	carrier.Model:SetAttribute("AIShotGood", shot.Good)
	if self:_tryMidfieldLongShot(context, carrier, pressure) then
		self.CarrySince[carrier.Model] = nil
		return
	end
	local dangerZone = PitchConfig.Zones.OpponentBox
	local closeToDanger = carrier.Pitch.X >= dangerZone.XMin - 5 and carrier.Pitch.X <= dangerZone.XMax + 5 and carrier.Pitch.Z >= dangerZone.ZMin - 5
	local enoughBoxSpace = attackStage == "FinalChance" and PitchConfig.InZone(carrier.Pitch, "OpponentBox") and pressure.Closest > 9
	local openDangerShot = closeToDanger and pressure.Closest > 9
	local strikerShootBias = carrier.Role == "ST" and shot.Good and (PitchConfig.InZone(carrier.Pitch, "OpponentBox") or PitchConfig.InZone(carrier.Pitch, "CentralShootingZone"))
	if openDangerShot then
		carrier.Model:SetAttribute("VTROpenDangerShotChance", 0.84)
		carrier.Model:SetAttribute("VTROpenDangerShotChanceUntil", context.Now + 2.8)
	else
		carrier.Model:SetAttribute("VTROpenDangerShotChance", nil)
		carrier.Model:SetAttribute("VTROpenDangerShotChanceUntil", nil)
	end
	if (shot.Good or openDangerShot) and (openDangerShot or strikerShootBias or shot.Score > 22 or enoughBoxSpace) and (not pressure.Heavy or enoughBoxSpace or strikerShootBias or openDangerShot) then
		if self:_shoot(context, carrier, shot) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	end


	local runningIntoSpaceDanger = pressure.Closest <= 25 or strikerUnderClosePressure or ((carrier.Model:GetAttribute("AICarryIntoSpace") == true or self.LastAction[carrier.Model] == "CarryForwardSpace" or self.LastAction[carrier.Model] == "TakeOnPressForward") and pressure.Closest <= 25)
	local forcedSafe = wingerEndLine or runningIntoSpaceDanger or (defensiveMood ~= "AggressiveRisk" and (pressure.Heavy or carriedFor >= holdLimit * 0.45 or self.Style:Risk() < 0.3))
	local pass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, forcedSafe)
	local inOpponentHalf = carrier.Pitch.Z >= PitchConfig.HALF_LENGTH
	local passIsBackwards = pass ~= nil and pass.Kind == "Back" and (pass.ForwardGain or 0) < -8
	local forwardCarryPitch = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X, 3, carrier.Pitch.Z + (attackStage == "FinalChance" and 18 or 38)))
	local forwardSpace = AIContextBuilder.SpaceAt(context, carrier.Side, forwardCarryPitch, pressure.Under and 16 or 22)
	local takeOnPress = inOpponentHalf and passIsBackwards and forwardSpace and not pressure.Heavy
	if takeOnPress then
		pass = nil
		forcedSafe = false
		carrier.Model:SetAttribute("AIAvoidBackPass", true)
	else
		carrier.Model:SetAttribute("AIAvoidBackPass", false)
	end
	carrier.Model:SetAttribute("AIForwardSpace", forwardSpace)
	carrier.Model:SetAttribute("AIRunningIntoSpaceDanger", runningIntoSpaceDanger)
	carrier.Model:SetAttribute("AIForcePassPressure25", pressure.Closest <= 25)
	carrier.Model:SetAttribute("AIForcedSafe", forcedSafe)
	carrier.Model:SetAttribute("AIPassScore", pass and pass.Score or -999)
	carrier.Model:SetAttribute("AIPassReceiver", pass and pass.Receiver and pass.Receiver.Model.Name or "")
	carrier.Model:SetAttribute("AIPassKind", pass and pass.PassKind or "")
	carrier.Model:SetAttribute("AIPassLaneClear", pass and pass.LaneClear or false)
	local preplannedOneTouch = oneTouchPassing > 0.72 and carriedFor <= math.max(0.22, minimumHoldTime * 0.75) and pass and pass.Safe and pass.Score > 18
	local holdWindowDone = carriedFor >= minimumHoldTime or pressure.Heavy or pressure.Under or runningIntoSpaceDanger or forcedSafe or preplannedOneTouch
	if pass and holdWindowDone and (runningIntoSpaceDanger or forcedSafe or preplannedOneTouch or pass.Kind ~= "Back" and pass.Score > (-8 - passTempo * 18) or pass.Kind == "Back" and pass.Score > 58 or carriedFor > math.max(minimumHoldTime, 0.16 - passTempo * 0.1)) then
		if self:_kickPass(context, carrier, pass) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	end

	if forwardSpace and not runningIntoSpaceDanger and not strikerUnderClosePressure and (pressure.None or takeOnPress or (inOpponentHalf and pressure.Under and not pass)) then
		local target = PitchConfig.TeamPitchPositionToWorld(forwardCarryPitch, carrier.Side, context.Options)
		assignment.TargetWorld = target
		assignment.MovementTarget = target
		assignment.PrimaryAssignment = takeOnPress and "TakeOnPressForward" or "CarryForwardSpace"
		assignment.MovementUrgency = 1
		assignment.SprintAllowed = true
		self.LastAction[carrier.Model] = assignment.PrimaryAssignment
		return
	end

	local dribble = AIDribblingDecisionService.Evaluate(context, carrier, self.Style)
	carrier.Model:SetAttribute("AIDribbleScore", dribble.Score)
	carrier.Model:SetAttribute("AIDribbleAvailable", dribble.CanDribble)
	local dribbleThreshold = strikerUnderClosePressure and 999 or takeOnPress and -12 or defensiveMood == "AggressiveRisk" and -6 or defensiveMood == "Pressing" and 3 or pressure.Heavy and 22 or 5
	if wingerChanceZone then
		dribbleThreshold += 16
	end
	if wingerEndLine then
		dribbleThreshold = 999
	end
	if dribble.CanDribble and dribble.Score > dribbleThreshold then
		assignment.TargetWorld = dribble.Target
		assignment.MovementTarget = dribble.Target
		assignment.PrimaryAssignment = "DribbleSupport"
		assignment.MovementUrgency = 1
		assignment.SprintAllowed = true
		self.LastAction[carrier.Model] = "Dribble"
		return
	end

	if PitchConfig.InZone(carrier.Pitch, "OwnBox") or pressure.Heavy then
		if self:_clear(context, carrier) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	end

	if pass and self:_kickPass(context, carrier, pass) then
		self.CarrySince[carrier.Model] = nil
		return
	end

	local fallbackZ = wingerEndLine and carrier.Pitch.Z - 28 or carrier.Pitch.Z + 32
	local fallbackX = wingerEndLine and (carrier.Pitch.X + (carrier.Pitch.X < PitchConfig.HALF_WIDTH and 28 or -28)) or carrier.Pitch.X
	local targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(fallbackX, 3, fallbackZ))
	local target = PitchConfig.TeamPitchPositionToWorld(targetPitch, carrier.Side, context.Options)
	assignment.TargetWorld = target
	assignment.MovementTarget = target
	assignment.PrimaryAssignment = "DribbleSupport"
	assignment.MovementUrgency = 1
	assignment.SprintAllowed = not wingerEndLine
	self.LastAction[carrier.Model] = wingerEndLine and "TurnAwayFromEndLine" or "ForcedCarry"
end

function Service:_defensiveActions(context: any, assignmentsBySide: any, onlySide: string?)
	if context.WorldCupFirstPassPending==true then
		return
	end
	local owner = context.Owner
	local carrier = owner and context.Players[owner]
	if not carrier then
		return
	end
	for _, side in ipairs({"Home", "Away"}) do
		if onlySide and side ~= onlySide then
			continue
		end
		if side == carrier.Side then
			continue
		end
		local manualTackleSides = context.ManualTackleSides
		if type(manualTackleSides) == "table" and manualTackleSides[side] == true then
			continue
		end
		for model, assignment in pairs(assignmentsBySide[side]) do
			local defender = context.Players[model]
			if defender then
				if defender.IsUserControlled then
					continue
				end
				local primary = assignment.PrimaryAssignment
				local distanceToCarrier = PitchConfig.GetDistanceStuds(defender.World, carrier.World)
				local closeAutoTackle = distanceToCarrier <= 8.75
				local strikerEmergencyTackle = carrier.Role == "ST" and PitchConfig.GetDistanceStuds(defender.World, carrier.World) <= 18
				if closeAutoTackle or strikerEmergencyTackle or primary == "PressBallCarrier" or primary == "ContainBallCarrier" or primary == "CoverPresser" or primary == "CloseLongCarryGap" or primary == "EarlyCBPressPassTarget" or primary == "EarlyClosePassTargetPressure" or primary == "CenterBackPressureStriker" or primary == "AggressiveCBPressStriker" or primary == "AggressiveCBStepOut" then
					local canTackle, slide = AITacklingDecisionService.CanTackle(context, defender, carrier, self.Style)
					if canTackle then
						if self.BallService:Tackle(model, slide) then
							self.LastAction[model] = slide and "SlideTackle" or "Tackle"
						end
					end
				end
			end
		end
	end
end

function Service:_receiverOverrides(context: any, assignmentsBySide: any, onlySide: string?)
	local now = context.Now or os.clock()
	for _, side in ipairs({"Home", "Away"}) do
		if onlySide and side ~= onlySide then
			continue
		end
		for _, info in ipairs(context.Teams[side].List) do
			if info.Model:GetAttribute("VTRReceptionContractId") ~= nil then
				continue
			end
			local receiveTarget = info.Model:GetAttribute("VTRReceiveIntercept")
			if typeof(receiveTarget) ~= "Vector3" then
				receiveTarget = info.Model:GetAttribute("VTRReceiveTarget")
			end
			local receiveUntil = tonumber(info.Model:GetAttribute("VTRReceiveUntil")) or now
			if context.Owner == info.Model then
				info.Model:SetAttribute("VTRReceivedAt", now)
				info.Model:SetAttribute("VTRReceiveTarget", nil)
				info.Model:SetAttribute("VTRPreparingReceive", false)
				info.Model:SetAttribute("VTRReceiveUntil", nil)
				info.Model:SetAttribute("VTRReceiveLockedAt", nil)
				info.Model:SetAttribute("VTRReceiveIntercept", nil)
				info.Model:SetAttribute("AIDebugExpectedPass", nil)
				info.Model:SetAttribute("AIDebugPassTarget", nil)
			elseif receiveUntil < now then
				info.Model:SetAttribute("VTRReceiveTarget", nil)
				info.Model:SetAttribute("VTRPreparingReceive", false)
				info.Model:SetAttribute("VTRReceiveUntil", nil)
				info.Model:SetAttribute("VTRReceiveLockedAt", nil)
				info.Model:SetAttribute("VTRReceiveIntercept", nil)
				info.Model:SetAttribute("AIDebugExpectedPass", nil)
				info.Model:SetAttribute("AIDebugPassTarget", nil)
			elseif typeof(receiveTarget) == "Vector3" and not info.IsUserControlled then
				local passKind=tostring(info.Model:GetAttribute("AIDebugPassKind") or "")
				local lobbed=passKind=="Lofted" or passKind=="FarPostCross" or (context.Ball and context.Ball:GetAttribute("VTRLobPassActive")==true)
				local committed = info.Model:GetAttribute("VTRReceiveCommitted") == true
					or info.Model:GetAttribute("VTRReceptionContractId") ~= nil
					or info.Model:GetAttribute("VTRAITargetedPass") == true
					or info.Model:GetAttribute("VTRAIAlternatePassChaser") == true
					or info.Model:GetAttribute("VTRReceiveHardLock") == true
					or (tonumber(info.Model:GetAttribute("VTRReceiveHardLockUntil")) or 0) > now
				local target = committed and receiveTarget or lobbed and predictReceivePoint(context, info, receiveTarget) or cutPassCoursePoint(context, info, receiveTarget)
				local assignment = assignmentsBySide[side][info.Model]
				if assignment then
					assignment.PrimaryAssignment = committed and "ReceivePass" or lobbed and "WaitForLobbedPass" or "CutPassCourse"
					assignment.TargetWorld = target
					assignment.MovementTarget = target
					assignment.MovementUrgency = committed and 1 or lobbed and .92 or 1
					assignment.SprintAllowed = committed or not lobbed or PitchConfig.GetDistanceStuds(info.World,target)>10
					assignment.FaceWorld = context.BallWorld
					info.Model:SetAttribute("VTRReceiveIntercept", target)
					info.Model:SetAttribute("VTRReceiveMode", committed and "CommittedIntercept" or lobbed and "WaitLob" or "CutCourse")
					info.Model:SetAttribute("VTRReceiveBallSpeed", flat(context.BallVelocity or Vector3.zero).Magnitude)
					info.Model:SetAttribute("VTRReceiveDistance", PitchConfig.GetDistanceStuds(info.World, target))
				end
			end
		end
	end
end

function Service:Step(context: any, assignmentsBySide: any)
	self:_receiverOverrides(context, assignmentsBySide)
	local owner = context.Owner
	if owner and context.Players[owner] then
		local carrier = context.Players[owner]
		local assignment = assignmentsBySide[carrier.Side] and assignmentsBySide[carrier.Side][owner]
		if assignment then
			self:_carrierDecision(context, carrier, assignment)
		end
	else
		for model in pairs(self.CarrySince) do
			self.CarrySince[model] = nil
		end
	end
	self:_defensiveActions(context, assignmentsBySide)
	for model, action in pairs(self.LastAction) do
		model:SetAttribute("AIChosenAction", action)
	end
end

function Service:StepSide(context: any, assignmentsBySide: any, side: string)
	self:_receiverOverrides(context, assignmentsBySide, side)
	local owner = context.Owner
	if owner and context.Players[owner] then
		local carrier = context.Players[owner]
		if carrier.Side == side then
			local assignment = assignmentsBySide[side] and assignmentsBySide[side][owner]
			if assignment then
				self:_carrierDecision(context, carrier, assignment)
			end
		else
			for model in pairs(self.CarrySince) do
				self.CarrySince[model] = nil
			end
		end
	else
		for model in pairs(self.CarrySince) do
			self.CarrySince[model] = nil
		end
	end
	self:_defensiveActions(context, assignmentsBySide, side)
	for model, action in pairs(self.LastAction) do
		model:SetAttribute("AIChosenAction", action)
	end
	table.clear(self.LastAction)
end

function Service:Clear()
	table.clear(self.NextDecision)
	table.clear(self.CarrySince)
	table.clear(self.LastAction)
end

return Service
