--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIDifficultyService = require(script.Parent.AIDifficultyService)
local AIContextBuilder = require(script.Parent.AIContextBuilder)
local AIPassingDecisionService = require(script.Parent.AIPassingDecisionService)
local AIShootingDecisionService = require(script.Parent.AIShootingDecisionService)
local AIDribblingDecisionService = require(script.Parent.AIDribblingDecisionService)
local AITacklingDecisionService = require(script.Parent.AITacklingDecisionService)
local AIGoalkeeperService = require(script.Parent.AIGoalkeeperService)

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

function Service.new(ballService: any, style: any, difficulty: any)
	return setmetatable({BallService = ballService, Style = style, Difficulty = difficulty, NextDecision = {}, CarrySince = {}, LastAction = {}}, Service)
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
	if direction.Magnitude < 4 then
		return false
	end
	local passKind = pass.PassKind == "Through" and "Through" or pass.PassKind == "Lofted" and "Lofted" or "Ground"
	local power = math.clamp((pass.Distance or direction.Magnitude) / (passKind == "Through" and 145 or passKind == "Lofted" and 130 or 110), passKind == "Lofted" and 0.32 or 0.12, passKind == "Through" and 0.46 or passKind == "Lofted" and 0.68 or 0.78)
	local kicked = self.BallService:Kick(passer.Model, "Pass", direction, power, pass.Receiver.Model, passKind, pass.Distance or direction.Magnitude, pass.Target)
	if kicked then
		self.LastAction[passer.Model] = pass.PassKind == "Through" and "ThroughPass" or "Pass"
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
	local passTempo = self.Style:Ratio("PassTempo")
	local firstTouchDirectness = self.Style:Ratio("FirstTouchDirectness")
	local holdLimit = pressure.Under and (0.72 - passTempo * 0.42) or (1.65 - passTempo * 0.75 - firstTouchDirectness * 0.28)
	holdLimit = math.clamp(holdLimit, 0.18, 1.45)
	local nextDecision = self.NextDecision[carrier.Model] or 0
	carrier.Model:SetAttribute("AIPressureScore", pressure.Score)
	carrier.Model:SetAttribute("AIHeavyPressure", pressure.Heavy)
	carrier.Model:SetAttribute("AICarriedFor", carriedFor)
	carrier.Model:SetAttribute("AIHoldLimit", holdLimit)
	if carrier.IsGoalkeeper then
		local waitDone = carriedFor >= 0.65 or pressure.Under
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
	if now < nextDecision and carriedFor < holdLimit then
		local dribble = AIDribblingDecisionService.Evaluate(context, carrier, self.Style)
		assignment.TargetWorld = dribble.Target
		assignment.MovementTarget = dribble.Target
		assignment.PrimaryAssignment = "DribbleSupport"
		assignment.MovementUrgency = 1
		assignment.SprintAllowed = true
		self.LastAction[carrier.Model] = "Carry"
		return
	end

	self.NextDecision[carrier.Model] = now + math.max(0.08, math.min(AIDifficultyService.NextDecisionDelay(self.Difficulty) * (1.12 - passTempo * 0.55), holdLimit))

	local shot = AIShootingDecisionService.Evaluate(context, carrier, self.Style, self.Difficulty)
	carrier.Model:SetAttribute("AIShotScore", shot.Score)
	carrier.Model:SetAttribute("AIShotGood", shot.Good)
	if shot.Good and shot.Score > 32 and not pressure.Heavy then
		if self:_shoot(context, carrier, shot) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	end

	local forcedSafe = pressure.Heavy or carriedFor >= holdLimit or self.Style:Risk() < 0.38 or (pressure.Under and passTempo > 0.55)
	local pass = AIPassingDecisionService.Choose(context, carrier, self.Style, self.Difficulty, forcedSafe)
	carrier.Model:SetAttribute("AIForcedSafe", forcedSafe)
	carrier.Model:SetAttribute("AIPassScore", pass and pass.Score or -999)
	carrier.Model:SetAttribute("AIPassReceiver", pass and pass.Receiver and pass.Receiver.Model.Name or "")
	carrier.Model:SetAttribute("AIPassKind", pass and pass.PassKind or "")
	carrier.Model:SetAttribute("AIPassLaneClear", pass and pass.LaneClear or false)
	if pass and (forcedSafe or pass.Score > (18 - passTempo * 16) or carriedFor > math.max(0.14, 0.46 - passTempo * 0.28)) then
		if self:_kickPass(context, carrier, pass) then
			self.CarrySince[carrier.Model] = nil
			return
		end
	end

	local dribble = AIDribblingDecisionService.Evaluate(context, carrier, self.Style)
	carrier.Model:SetAttribute("AIDribbleScore", dribble.Score)
	carrier.Model:SetAttribute("AIDribbleAvailable", dribble.CanDribble)
	if dribble.CanDribble and dribble.Score > (pressure.Heavy and 22 or 5) then
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

	local targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(carrier.Pitch.X, 3, carrier.Pitch.Z + 32))
	local target = PitchConfig.TeamPitchPositionToWorld(targetPitch, carrier.Side, context.Options)
	assignment.TargetWorld = target
	assignment.MovementTarget = target
	assignment.PrimaryAssignment = "DribbleSupport"
	assignment.MovementUrgency = 1
	assignment.SprintAllowed = true
	self.LastAction[carrier.Model] = "ForcedCarry"
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
			if assignment.PrimaryAssignment == "PressBallCarrier" or assignment.PrimaryAssignment == "ContainBallCarrier" or assignment.PrimaryAssignment == "CoverPresser" then
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
