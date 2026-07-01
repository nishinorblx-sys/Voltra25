--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.StaminaConfig)

local Service = {}
Service.__index = Service

local function buildModifier(model: Model): number
	local build = string.lower(tostring(model:GetAttribute("BodyBuild") or model:GetAttribute("BodyType") or "balanced"))
	if string.find(build, "stocky") or string.find(build, "power") then return 1.05 end
	if string.find(build, "lean") or string.find(build, "athletic") then return 0.96 end
	return 1
end

local function positionModifier(model: Model): number
	local position = string.upper(tostring(model:GetAttribute("position") or "CM"))
	if position == "GK" then return 0.72 end
	if position == "CB" or position == "CDM" then return 0.94 end
	if position == "LW" or position == "RW" or position == "LB" or position == "RB" then return 1.04 end
	return 1
end

function Service.new()
	return setmetatable({}, Service)
end

function Service:Step(model: Model, dt: number, state: any): (number,number)
	local staminaStat = math.clamp(tonumber(model:GetAttribute("Stamina")) or 65, 1, 99)
	local endurance=math.clamp(tonumber(model:GetAttribute("VTREndurance"))or Config.Maximum,0,Config.Maximum)
	local reserve=math.clamp(tonumber(model:GetAttribute("VTRSprintStamina"))or tonumber(model:GetAttribute("VTRStamina"))or endurance,0,endurance)
	local sprintDuration = math.max(0, tonumber(model:GetAttribute("VTRSprintDuration")) or 0)
	local controlled=state.UserControlled==true
	local sprintLocked=model:GetAttribute("VTRSprintLocked")==true and not controlled
	local sprinting = controlled and not sprintLocked and state.Sprinting == true and (tonumber(state.MoveMagnitude) or 0) > 0.1
	local speed = math.max(0, tonumber(state.CurrentSpeed) or 0)
	local gameRate=math.max(0,tonumber(state.GameRate)or 1)
	local gameMinutes=dt*gameRate/60
	local statDelta=(staminaStat-65)/34
	local enduranceModifier=statDelta>=0 and(1-statDelta*Config.HighStatEnduranceReduction)or(1+(-statDelta)*Config.LowStatEnduranceIncrease)
	endurance=math.max(0,endurance-Config.EnduranceDrainPerGameMinute*gameMinutes*enduranceModifier)
	if sprinting then
		sprintDuration += dt
		local quality=math.clamp((staminaStat-35)/64,0,1)
		local speedModifier = 0.9 + math.clamp(speed / 30, 0, 1) * 0.16
		local durationModifier = 1 + math.clamp(sprintDuration / Config.SprintDurationRampSeconds, 0, 1) * Config.SprintDurationMaxPenalty
		local possessionModifier = state.HasBall == true and 1.04 or 1
		local drain=(Config.SprintReserveDrainMax-(Config.SprintReserveDrainMax-Config.SprintReserveDrainMin)*quality)*buildModifier(model)*positionModifier(model)*speedModifier*durationModifier*possessionModifier
		reserve=math.max(0,reserve-drain*dt)
		endurance=math.max(0,endurance-Config.SprintEnduranceDrainPerRealSecond*enduranceModifier*buildModifier(model)*positionModifier(model)*durationModifier*dt)
	else
		sprintDuration = math.max(0, sprintDuration - dt * 1.8)
		local recoveryQuality = math.clamp((staminaStat - 35) / 64, 0, 1)
		local idle = speed < 5
		local recovery = idle and (Config.IdleRecoveryMin + (Config.IdleRecoveryMax - Config.IdleRecoveryMin) * recoveryQuality) or (Config.JogRecoveryMin + (Config.JogRecoveryMax - Config.JogRecoveryMin) * recoveryQuality)
		if not controlled then recovery=math.max(recovery*Config.UnusedRecoveryMultiplier,Config.IdleRecoveryMax*1.25) end
		reserve=math.min(endurance,reserve+recovery*dt)
	end
	reserve=math.min(reserve,endurance)
	if reserve<=.05 then
		sprintLocked=true
	elseif sprintLocked and reserve>=math.min(endurance,Config.ExhaustedRecoveryThreshold) then
		sprintLocked=false
	end
	model:SetAttribute("VTREndurance",endurance)
	model:SetAttribute("VTRSprintStamina",reserve)
	model:SetAttribute("VTRStamina",reserve)
	model:SetAttribute("VTRSprintDuration", sprintDuration)
	model:SetAttribute("VTRSprintLocked",sprintLocked)
	return reserve,endurance
end

return Service
