--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tuning = require(ReplicatedStorage.VTR.Shared.MovementTuningConfig)

local Resolver = {}

function Resolver.Resolve(model: Model, state: any): any
	local overall = math.clamp(tonumber(model:GetAttribute("overall")) or tonumber(model:GetAttribute("Rating")) or 60, 1, 99)
	local pace = math.clamp((tonumber(model:GetAttribute("PAC")) or 60) * 0.72 + overall * 0.28, 1, 99)
	local acceleration = math.clamp((tonumber(model:GetAttribute("Acceleration")) or pace) * 0.68 + overall * 0.32, 1, 99)
	local dribbling = math.clamp(tonumber(model:GetAttribute("DRI")) or 60, 1, 99)
	local staminaRatio = math.clamp(tonumber(state.StaminaRatio) or 1, 0, 1)
	local moveMagnitude = math.clamp(tonumber(state.MoveMagnitude) or 1, 0, 1)
	local turnDot = math.clamp(tonumber(state.TurnDot) or 1, -1, 1)
	local sprinting = state.Sprinting == true
	local hasBall = state.HasBall == true
	local paceAlpha = math.clamp((pace - 35) / 64, 0, 1)
	local accelerationAlpha = math.clamp((acceleration - 35) / 64, 0, 1)
	local jog = Tuning.JogMin + (Tuning.JogMax - Tuning.JogMin) * paceAlpha
	local sprint = Tuning.SprintMin + (Tuning.SprintMax - Tuning.SprintMin) * paceAlpha
	local staminaMultiplier = if staminaRatio < Tuning.LowEnergyThreshold / 100 then Tuning.LowEnergyMinimumMultiplier + (1 - Tuning.LowEnergyMinimumMultiplier) * staminaRatio / (Tuning.LowEnergyThreshold / 100) else 1
	local turnMultiplier = sprinting and turnDot < Tuning.SharpTurnDot and Tuning.SprintTurnPenalty or 1
	turnMultiplier = math.min(turnMultiplier, tonumber(state.TurnPenalty) or 1)
	local ballControlModifier = 1
	if hasBall then
		local controlAlpha = math.clamp((dribbling - 35) / 64, 0, 1)
		ballControlModifier = if sprinting then Tuning.DribbleSprintMinMultiplier + (Tuning.DribbleSprintMaxMultiplier - Tuning.DribbleSprintMinMultiplier) * controlAlpha else Tuning.DribbleJogMinMultiplier + (Tuning.DribbleJogMaxMultiplier - Tuning.DribbleJogMinMultiplier) * controlAlpha
	end
	local sprintMultiplier = sprinting and staminaMultiplier * turnMultiplier or 1
	local targetSpeed = (sprinting and sprint or jog) * moveMagnitude * sprintMultiplier * ballControlModifier
	local accelerationRate = Tuning.AccelerationMin + (Tuning.AccelerationMax - Tuning.AccelerationMin) * accelerationAlpha
	if state.UserControlled == true then accelerationRate *= 1.12 end
	return {
		TargetSpeed = targetSpeed,
		AccelerationRate = accelerationRate,
		DecelerationRate = Tuning.Deceleration,
		SprintMultiplier = sprintMultiplier,
		BallControlModifier = ballControlModifier,
	}
end

return Resolver
