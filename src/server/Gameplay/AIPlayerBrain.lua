--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIDifficultyService = require(script.Parent.AIDifficultyService)
local AIContextBuilder = require(script.Parent.AIContextBuilder)
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

function Service.new(ballService: any, style: any, difficulty: any)
	return setmetatable({BallService = ballService, Style = style, Difficulty = difficulty, NextDecision = {}, CarrySince = {}, LastAction = {}, Random = Random.new()}, Service)
end

function Service:_setReceiver(pass: any)
	if not pass or not pass.Receiver then
		return
	end
	local receiver = pass.Receiver.Model
	receiver:SetAttribute("VTRReceiveTarget", pass.Target)
	receiver:SetAttribute("VTRPreparingReceive", true)
	receiver:SetAttribute("VTRReceiveUntil", os.clock() + math.clamp((pass.Distance or 45) / 24, 2.8, 5.4))
	receiver:SetAttribute("VTRReceiveLockedAt", os.clock())
	receiver:SetAttribute("AIDebugExpectedPass", true)
	receiver:SetAttribute("AIDebugPassTarget", pass.Target)
	receiver:SetAttribute("AIDebugPassKind", pass.PassKind or "Ground")
	receiver:SetAttribute("AIDebugPassScore", pass.Score or 0)
end

function Service:_kickPass(context: any, passer: any, pass: any): boolean
	if not passer.Root or not pass then
		return false
	end
	self:_setReceiver(pass)
	local direction = pass.Target - passer.Root.Position
	if pass.Receiver and pass.Receiver.Root then
		local receiverVelocity = flat(pass.Receiver.Root.AssemblyLinearVelocity)
		if receiverVelocity.Magnitude > 1.5 and (pass.PassKind == "Through" or pass.PassKind == "Lofted" or pass.ForwardGain and pass.ForwardGain > 8) then
			local lead = receiverVelocity.Unit * math.clamp(receiverVelocity.Magnitude * (pass.PassKind == "Lofted" and 0.42 or 0.3), 5, 24)
			local leadTarget = pass.Target + lead
			local leadPitch = PitchConfig.WorldToTeamPitchPosition(leadTarget, passer.Side, context.Options)
			if leadPitch.Z >= pass.Receiver.Pitch.Z - 2 then
				pass.Target = PitchConfig.TeamPitchPositionToWorld(PitchConfig.ClampInsidePitch(Vector3.new(leadPitch.X, 3, leadPitch.Z)), passer.Side, context.Options)
				direction = pass.Target - passer.Root.Position
			end
		end
	end
	if direction.Magnitude < 4 then
		return false
	end
	local passKind = pass.PassKind == "Through" and "Through" or (pass.PassKind == "Lofted" or pass.PassKind == "FarPostCross") and "Lofted" or "Ground"
	local power = math.clamp((pass.Distance or direction.Magnitude) / (passKind == "Through" and 145 or passKind == "Lofted" and 130 or 110), passKind == "Lofted" and 0.32 or 0.12, passKind == "Through" and 0.46 or passKind == "Lofted" and 0.68 or 0.78)
	local kicked = self.BallService:Kick(passer.Model, "Pass", direction, power, pass.Receiver.Model, passKind, pass.Distance or direction.Magnitude, pass.Target)
	if kicked then
		self.LastAction[passer.Model] = (pass.PassKind == "LowCross" or pass.PassKind == "FarPostCross") and "Cross" or pass.PassKind == "Cutback" and "Cutback" or pass.PassKind == "Through" and "ThroughPass" or "Pass"
	else
		pass.Receiver.Model:SetAttribute("VTRReceiveTarget", nil)
		pass.Receiver.Model:SetAttribute("VTRPreparingReceive", false)
		pass.Receiver.Model:SetAttribute("VTRReceiveUntil", nil)
		pass.Receiver.Model:SetAttribute("VTRReceiveLockedAt", nil)
		pass.Receiver.Model:SetAttribute("AIDebugExpectedPass", nil)
	end
	return kicked
end

function Service:_shoot(context: any, shooter: any, shot: any): boolean
	if not shooter.Root then
		return false
	end
	local direction = shot.Target - shooter.Root.Position
	local charge = math.clamp(0.46 + shooter.Stats.shotPower / 240 + (shot.Distance or 80) / 420, 0.45, 0.86)
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
	local passTempo = self.Style:Ratio("PassTempo")
	local firstTouchDirectness = self.Style:Ratio("FirstTouchDirectness")
	local holdLimit = pressure.Under and (0.38 - passTempo * 0.2) or (1.05 - passTempo * 0.52 - firstTouchDirectness * 0.22)
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
	holdLimit = math.clamp(holdLimit, 0.18, 1.45)
	local nextDecision = self.NextDecision[carrier.Model] or 0
	carrier.Model:SetAttribute("AIPressureScore", pressure.Score)
	carrier.Model:SetAttribute("AIHeavyPressure", pressure.Heavy)
	carrier.Model:SetAttribute("AICarriedFor", carriedFor)
	carrier.Model:SetAttribute("AIHoldLimit", holdLimit)
	carrier.Model:SetAttribute("AIAttackStage", attackStage)
	carrier.Model:SetAttribute("AIDefensiveMood", defensiveMood)
	carrier.Model:SetAttribute("AICarryIntoSpace", false)
	if (tonumber(carrier.Model:GetAttribute("VTRKickoffReturnUntil")) or 0) > now and carriedFor >= 0.03 then
		local kickoffReturn = AIPassingDecisionService.ChooseKickoffReturn(context, carrier, self.Style, self.Difficulty)
		if kickoffReturn and self:_kickPass(context, carrier, kickoffReturn) then
			carrier.Model:SetAttribute("VTRKickoffReturnUntil", nil)
			self.CarrySince[carrier.Model] = nil
			return
		end
	end
	if carrier.IsGoalkeeper then
		local waitDone = carriedFor >= 0.35 or pressure.Under or pressure.Heavy
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

	self.NextDecision[carrier.Model] = now + math.max(0.04, math.min(AIDifficultyService.NextDecisionDelay(self.Difficulty) * (0.72 - passTempo * 0.42), holdLimit * 0.65))

	local boxCross = chooseBoxCross(context, carrier)
	local wingerPass = boxCross or AIPassingDecisionService.ChooseWingerWide(context, carrier, self.Style, self.Difficulty)
	carrier.Model:SetAttribute("AIWingerWideDecision", wingerPass and wingerPass.PassKind or "")
	if wingerPass and (wingerEndLine or wingerChanceZone or pressure.Under or wingerPass.Score > 390) then
		if self:_kickPass(context, carrier, wingerPass) then
			self.CarrySince[carrier.Model] = nil
			return
		end
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


	local forcedSafe = wingerEndLine or (defensiveMood ~= "AggressiveRisk" and (pressure.Heavy or carriedFor >= holdLimit * 0.45 or self.Style:Risk() < 0.3))
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
	carrier.Model:SetAttribute("AIForcedSafe", forcedSafe)
	carrier.Model:SetAttribute("AIPassScore", pass and pass.Score or -999)
	carrier.Model:SetAttribute("AIPassReceiver", pass and pass.Receiver and pass.Receiver.Model.Name or "")
	carrier.Model:SetAttribute("AIPassKind", pass and pass.PassKind or "")
	carrier.Model:SetAttribute("AIPassLaneClear", pass and pass.LaneClear or false)
	if pass and (forcedSafe or pass.Kind ~= "Back" and pass.Score > (-8 - passTempo * 18) or pass.Kind == "Back" and pass.Score > 58 or carriedFor > math.max(0.025, 0.16 - passTempo * 0.1)) then
		if self:_kickPass(context, carrier, pass) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	end

	if forwardSpace and (pressure.None or takeOnPress or (inOpponentHalf and pressure.Under and not pass)) then
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
	local dribbleThreshold = takeOnPress and -12 or defensiveMood == "AggressiveRisk" and -6 or defensiveMood == "Pressing" and 3 or pressure.Heavy and 22 or 5
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
		for model, assignment in pairs(assignmentsBySide[side]) do
			if assignment.PrimaryAssignment == "PressBallCarrier" or assignment.PrimaryAssignment == "ContainBallCarrier" or assignment.PrimaryAssignment == "CoverPresser" or assignment.PrimaryAssignment == "CloseLongCarryGap" then
				local defender = context.Players[model]
				if defender then
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
			local receiveTarget = info.Model:GetAttribute("VTRReceiveTarget")
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
				local target = predictReceivePoint(context, info, receiveTarget)
				local assignment = assignmentsBySide[side][info.Model]
				if assignment then
					assignment.PrimaryAssignment = "ReceivePass"
					assignment.TargetWorld = target
					assignment.MovementTarget = target
					assignment.MovementUrgency = 1
					assignment.SprintAllowed = true
					assignment.FaceWorld = context.BallWorld
					info.Model:SetAttribute("VTRReceiveIntercept", target)
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
