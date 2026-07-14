--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.StaminaConfig)

local Service = {}
Service.__index = Service

local function ratingAlpha(model: Model): number
	local rating = math.clamp(tonumber(model:GetAttribute("Stamina")) or 65, 1, 99)
	return math.clamp((rating - 35) / 64, 0, 1)
end

local function mirror(model: Model, energy: number, duration: number, locked: boolean, actual: boolean)
	model:SetAttribute("VTRSprintEnergy", energy)
	model:SetAttribute("VTRSprintStamina", energy)
	model:SetAttribute("VTRStamina", energy)
	model:SetAttribute("VTREndurance", energy)
	model:SetAttribute("VTRSprintDuration", duration)
	model:SetAttribute("VTRSprintLocked", locked)
	model:SetAttribute("VTRSprinting", actual)
end

function Service.new()
	return setmetatable({}, Service)
end

function Service:Step(model: Model, dt: number, state: any): (number, number, boolean, boolean)
	local energy = math.clamp(tonumber(model:GetAttribute("VTRSprintEnergy")) or tonumber(model:GetAttribute("VTRSprintStamina")) or Config.Maximum, 0, Config.Maximum)
	local duration = math.max(0, tonumber(model:GetAttribute("VTRSprintDuration")) or 0)
	local locked = model:GetAttribute("VTRSprintLocked") == true
	local movement = math.clamp(tonumber(state.MoveMagnitude) or 0, 0, 1)
	local requested = state.SprintRequested == true or state.Sprinting == true
	local allowed = state.SprintAllowed ~= false and state.Frozen ~= true and state.Stunned ~= true and state.ActionLocked ~= true
	local actual = requested and allowed and not locked and energy > 0 and movement >= Config.MinimumMovementMagnitude
	local paused = state.SimulationPaused == true
	local alpha = ratingAlpha(model)
	if not paused then
		if actual then
			duration += dt
			local drain = Config.SprintDrainLowRating + (Config.SprintDrainHighRating - Config.SprintDrainLowRating) * alpha
			local ramp = 1 + math.clamp(duration / Config.SprintDurationRampSeconds, 0, 1) * (Config.SprintDurationMaximumMultiplier - 1)
			local possession = if state.HasBall == true then Config.PossessionDrainMultiplier else 1
			energy = math.max(0, energy - drain * ramp * possession * dt)
		else
			duration = math.max(0, duration - dt * 2)
			local speed = math.max(0, tonumber(state.CurrentSpeed) or 0)
			local idle = speed < 2.5 and movement < 0.15
			local low = if idle then Config.IdleRecoveryLowRating else Config.JogRecoveryLowRating
			local high = if idle then Config.IdleRecoveryHighRating else Config.JogRecoveryHighRating
			energy = math.min(Config.Maximum, energy + (low + (high - low) * alpha) * dt)
		end
	end
	if energy <= 0.05 then
		locked = true
		actual = false
	elseif locked and energy >= Config.ExhaustedRecoveryThreshold then
		locked = false
		actual = requested and allowed and movement >= Config.MinimumMovementMagnitude
	end
	mirror(model, energy, duration, locked, actual)
	return energy, energy, actual, locked
end

return Service
