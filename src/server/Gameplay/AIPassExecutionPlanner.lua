--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReceptionInterceptResolver = require(ReplicatedStorage.VTR.Shared.ReceptionInterceptResolver)
local PassingPowerConfig = require(ReplicatedStorage.VTR.Shared.PassingPowerConfig)
local GameplayConfig = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local PassFlightModel = require(ReplicatedStorage.VTR.Shared.PassFlightModel)

local Planner = {}

local function flat(value: Vector3): Vector3
	return Vector3.new(value.X, 0, value.Z)
end

local function reachInput(info: any, target: Vector3, energy: number?): any
	local root = info and info.Root
	local pace = math.clamp(tonumber(info and info.Stats and info.Stats.pace) or tonumber(info and info.Model and info.Model:GetAttribute("PAC")) or 60, 1, 99)
	local reception = math.clamp(tonumber(info and info.Stats and info.Stats.reception) or pace, 1, 99)
	local energyRatio = math.clamp((energy or 100) / 100, 0.35, 1)
	return {
		Position = root and root.Position or info.World,
		Velocity = root and root.AssemblyLinearVelocity or Vector3.zero,
		Facing = root and root.CFrame.LookVector or Vector3.zAxis,
		Target = target,
		MaximumSpeed = (15 + pace * 0.1) * energyRatio,
		Acceleration = 9 + pace * 0.08 + reception * 0.02,
		MaximumTurnPenalty = 0.36 - math.clamp((reception - 55) * 0.002, -0.04, 0.08),
		ContactTolerance = 2.05 + math.clamp((reception - 55) * 0.018, -0.35, 0.8),
	}
end

local function nearestOpponentETA(context: any, side: string, target: Vector3): number
	local opponentSide = side == "Home" and "Away" or "Home"
	local best = math.huge
	for _, opponent in ipairs(context.Teams[opponentSide].List) do
		if opponent.Root and not opponent.IsGoalkeeper then
			best = math.min(best, ReceptionInterceptResolver.EstimateReachTime(reachInput(opponent, target, tonumber(opponent.Model:GetAttribute("VTRSprintEnergy")) or 100)))
		end
	end
	return best
end

local function candidateTarget(pass: any, power: number): Vector3
	local receiver = pass.Receiver
	local target = pass.Target
	if not receiver or not receiver.Root then return target end
	local family = tostring(pass.PassKind or "Ground")
	if family ~= "Through" and family ~= "Lofted" and family ~= "FarPostCross" then return target end
	local velocity = flat(receiver.Root.AssemblyLinearVelocity)
	if velocity.Magnitude < 1 then return target end
	local existingLead = flat(target - receiver.Root.Position).Magnitude
	if existingLead >= 24 then return target end
	local leadSeconds = family == "Through" and 0.12 + power * 0.14 or 0.15 + power * 0.12
	return target + velocity * leadSeconds
end

function Planner.Plan(context: any, passer: any, pass: any, style: any, difficulty: any): any?
	if not passer or not passer.Root or not pass or not pass.Receiver or not pass.Receiver.Root then return nil end
	local family = tostring(pass.PassKind or "Ground")
	local powers = family == "Through" and {0.22, 0.3, 0.38, 0.46, 0.54} or (family == "Lofted" or family == "FarPostCross") and {0.34, 0.44, 0.54, 0.64} or {0.14, 0.24, 0.34, 0.46, 0.58}
	local best = nil
	local flight = GameplayConfig.Ball.Flight or {}
	local receiverEnergy = tonumber(pass.Receiver.Model:GetAttribute("VTRSprintEnergy")) or 100
	for _, power in ipairs(powers) do
		local target = candidateTarget(pass, power)
		local distance = flat(target - passer.Root.Position).Magnitude
		if distance < 5 or distance > PassingPowerConfig.MaxPassDistance then continue end
		local initialSpeed = PassingPowerConfig.SpeedForDistance(distance, power)
		local passType = family == "Through" and "Through" or (family == "Lofted" or family == "FarPostCross") and "Lofted" or "Ground"
		local ballETA = PassFlightModel.Duration(flight, distance, power, passType)
		local arrivalSpeed = distance / math.max(ballETA, 0.05) * (family == "Through" and 0.48 or 0.42)
		local receiverETA = ReceptionInterceptResolver.EstimateReachTime(reachInput(pass.Receiver, target, receiverEnergy))
		local opponentETA = nearestOpponentETA(context, passer.Side, target)
		local timingError = math.abs(ballETA - receiverETA)
		local receiverLate = receiverETA - ballETA
		local opponentMargin = opponentETA - math.min(ballETA, receiverETA)
		local contactSpeed = arrivalSpeed
		local laneRisk = math.clamp(tonumber(pass.LaneRisk) or 0, 0, 1)
		local passQuality = math.clamp(tonumber(passer.Stats and passer.Stats.passQuality) or tonumber(passer.Stats and passer.Stats.passing) or 60, 1, 99)
		local receiverReception = math.clamp(tonumber(pass.Receiver.Stats and pass.Receiver.Stats.reception) or tonumber(pass.Receiver.Stats and pass.Receiver.Stats.ballControl) or 60, 1, 99)
		local energyPenalty = receiverEnergy < 25 and math.max(0, distance - 26) / 60 or 0
		local touchPenalty = math.max(0, contactSpeed - (family == "Through" and 58 or 48)) / 28
		local score = 1.15 - timingError * math.clamp(0.84 - receiverReception * 0.002, 0.52, 0.78) - math.max(0, receiverLate) * 1.25 + math.clamp(opponentMargin, -1, 1) * 0.55 - laneRisk * math.clamp(1.08 - passQuality * 0.004, 0.58, 0.96) - energyPenalty - touchPenalty
		score += (passQuality - 60) * 0.004 + (receiverReception - 60) * 0.004
		score += (tonumber(difficulty and difficulty.PassRisk) or 0) * 0.08
		if style then score += style:Ratio("PassRisk") * 0.04 end
		if opponentETA + 0.08 < math.min(receiverETA, ballETA) then score -= 1.2 end
		local committedRun = pass.Receiver.Model:GetAttribute("VTRRunTicketId") ~= nil or tostring(pass.Receiver.Model:GetAttribute("currentAssignment") or ""):find("Run") ~= nil
		if committedRun and (family == "Through" or family == "Lofted") then score += 0.18 end
		local result = {Target = target, Power = power, Distance = distance, BallETA = ballETA, ReceiverETA = receiverETA, OpponentETA = opponentETA, ExpectedContactSpeed = contactSpeed, Viability = score, Family = family}
		if not best or result.Viability > best.Viability then best = result end
	end
	if not best or best.Viability < -0.58 then return nil end
	return best
end

return table.freeze(Planner)
