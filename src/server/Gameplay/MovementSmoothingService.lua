--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tuning = require(ReplicatedStorage.VTR.Shared.DribbleTuningConfig)

local Service = {}
Service.__index = Service

function Service.new()
	return setmetatable({States = {}}, Service)
end

function Service:Update(model: Model, desired: Vector3, hasBall: boolean, sprinting: boolean): (Vector3, number)
	local now = os.clock()
	local state = self.States[model] or {Direction = Vector3.zero, UpdatedAt = now, PenaltyUntil = 0}
	self.States[model] = state
	local dt = math.clamp(now - state.UpdatedAt, 1 / 120, 0.12)
	state.UpdatedAt = now
	local magnitude = math.clamp(desired.Magnitude, 0, 1)
	local desiredUnit = magnitude > 0.05 and desired.Unit or Vector3.zero
	local previous = state.Direction.Magnitude > 0.05 and state.Direction.Unit or desiredUnit
	local turnDot = previous.Magnitude > 0 and desiredUnit.Magnitude > 0 and previous:Dot(desiredUnit) or 1
	if hasBall and turnDot < Tuning.SharpTurnDot then
		state.PenaltyUntil = now + Tuning.BallControlRecoveryTime
	end
	local agility = math.clamp(tonumber(model:GetAttribute("Agility")) or 60, 1, 99) / 99
	local smoothing = hasBall and Tuning.InputSmoothingTime * (1.18 - agility * 0.38) or Tuning.InputSmoothingNoBall
	if sprinting and hasBall then smoothing *= 1.35 end
	local alpha = 1 - math.exp(-dt / smoothing)
	state.Direction = state.Direction:Lerp(desiredUnit * magnitude, alpha)
	local penalty = now < state.PenaltyUntil and Tuning.SharpTurnSpeedPenalty or 1
	model:SetAttribute("InputTurnDot", turnDot)
	model:SetAttribute("DribbleTurnPenalty", penalty)
	return state.Direction, penalty
end

function Service:Clear(model: Model)
	self.States[model] = nil
end

return Service
