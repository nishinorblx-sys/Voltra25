--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FreeKickTrajectory = require(ReplicatedStorage.VTR.Shared.FreeKickTrajectory)

local Service = {}
Service.__index = Service

function Service.new(ball: BasePart)
	return setmetatable({Ball = ball, Active = nil}, Service)
end

function Service:Start(model: Model, direction: Vector3, speed: number, distance: number)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then return end
	local passing = math.clamp(tonumber(model:GetAttribute("PAS")) or 60, 1, 99)
	local curve = math.clamp(tonumber(model:GetAttribute("Curve")) or passing, 1, 99)
	local footSign = model:GetAttribute("PreferredFoot") == "Left" and -1 or 1
	local lateral = flat.Unit:Cross(Vector3.yAxis) * footSign
	local strength = (0.45 + math.clamp(distance, 0, 110) / 110 * 1.45) * (0.72 + curve / 180) * (1.12 - passing / 650)
	self.Active = {Lateral = lateral, Strength = strength, Remaining = math.clamp(distance / math.max(speed, 1) * 0.72, 0.18, 0.9),Decay=1.4}
	self.Ball.AssemblyAngularVelocity += Vector3.new(0, footSign * strength * 1.8, 0)
end

function Service:StartShot(model:Model,direction:Vector3,flightTime:number):Vector3
	local flat=Vector3.new(direction.X,0,direction.Z);if flat.Magnitude<.1 then return Vector3.zero end
	local curve=math.clamp(tonumber(model:GetAttribute("Curve"))or tonumber(model:GetAttribute("SHO"))or 60,1,99)
	local userCurve=tonumber(model:GetAttribute("VTRFreeKickCurve"))
	local footSign=model:GetAttribute("PreferredFoot")=="Left"and-1 or 1
	if userCurve and math.abs(userCurve)>.01 then
		local target=model:GetAttribute("VTRFreeKickTarget")
		local solved=typeof(target)=="Vector3" and FreeKickTrajectory.Compute(self.Ball.Position,target,userCurve,(tonumber(model:GetAttribute("VTRFreeKickLift"))or 0)*0.5) or nil
		if solved then
			self.Active={Lateral=solved.Lateral,Strength=solved.Strength,Remaining=solved.FlightTime,Decay=0}
			self.Ball.AssemblyAngularVelocity+=Vector3.new(0,(userCurve>=0 and -1 or 1)*math.max(solved.Strength,1)*1.6,0)
			return solved.Compensation
		end
	end
	local lateral=flat.Unit:Cross(Vector3.yAxis)*footSign;local duration=math.clamp(flightTime,.28,1.35);local strength=(7+curve*.085)*(userCurve and math.clamp(math.abs(userCurve),0,2.5) or 1);local decay=.9
	self.Active={Lateral=lateral,Strength=strength,Remaining=duration,Decay=decay}
	local displacement=strength/decay*duration-strength/(decay*decay)*(1-math.exp(-decay*duration))
	self.Ball.AssemblyAngularVelocity+=Vector3.new(0,footSign*strength*2.4,0)
	return -lateral*(displacement/duration)
end

function Service:Stop()
	self.Active = nil
end

function Service:Step(dt: number)
	local active = self.Active
	if not active then return end
	active.Remaining -= dt
	if active.Remaining <= 0 then self.Active = nil;return end
	local velocity = self.Ball.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontal.Magnitude < 4 then self.Active = nil;return end
	self.Ball.AssemblyLinearVelocity = velocity + active.Lateral * active.Strength * dt
	if (active.Decay or 1.4)>0 then active.Strength *= math.exp(-dt * (active.Decay or 1.4))end
end

return Service
