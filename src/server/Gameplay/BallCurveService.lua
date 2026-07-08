--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FreeKickTrajectory = require(ReplicatedStorage.VTR.Shared.FreeKickTrajectory)
local Physics = require(ReplicatedStorage.VTR.Shared.BallPhysicsConfig)

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

function Service:StartPass(model:Model,direction:Vector3,speed:number,distance:number,lofted:boolean?,flightTime:number?):Vector3
	local flatDirection=Vector3.new(direction.X,0,direction.Z)
	if flatDirection.Magnitude<.1 then return Vector3.zero end
	local passing=math.clamp(tonumber(model:GetAttribute("PAS"))or 60,1,99)
	local curveStat=math.clamp(tonumber(model:GetAttribute("Curve"))or passing,1,99)
	local footSign=model:GetAttribute("PreferredFoot")=="Left"and-1 or 1
	local lateral=flatDirection.Unit:Cross(Vector3.yAxis)*footSign
	local duration=math.clamp(flightTime or distance/math.max(speed,1),lofted and .7 or .22,lofted and 2.45 or 1.05)
	local base=lofted and 5.2 or 3.2
	local strength=(base+curveStat*.045+math.clamp(distance,0,120)/120*(lofted and 3.2 or 2.1))*(1.1-passing/900)
	local decay=lofted and .46 or .82
	self.Active={Lateral=lateral,Strength=strength,Remaining=duration,Decay=decay}
	local displacement=strength/decay*duration-strength/(decay*decay)*(1-math.exp(-decay*duration))
	self.Ball.AssemblyAngularVelocity+=Vector3.new(0,footSign*strength*(lofted and 1.8 or 1.45),0)
	return -lateral*(displacement/duration)
end

function Service:StartShot(model:Model,direction:Vector3,flightTime:number,targetPoint:Vector3?):Vector3
	local flat=Vector3.new(direction.X,0,direction.Z);if flat.Magnitude<.1 then return Vector3.zero end
	local curve=math.clamp(tonumber(model:GetAttribute("Curve"))or tonumber(model:GetAttribute("SHO"))or 60,1,99)
	local userCurve=tonumber(model:GetAttribute("VTRFreeKickCurve"))
	local footSign=model:GetAttribute("PreferredFoot")=="Left"and-1 or 1
	local shotFoot=tostring(model:GetAttribute("VTRShotFoot")or"")
	if shotFoot=="Left"then footSign=-1 elseif shotFoot=="Right"then footSign=1 end
	local finesse=model:GetAttribute("VTRFinesseShot")==true
	local practiceFinesseCurve=math.clamp(tonumber(model:GetAttribute("VTRPracticeFinesseCurve"))or 0,0,100)/100
	if userCurve and math.abs(userCurve)>.01 then
		local target=model:GetAttribute("VTRFreeKickTarget")
		local solved=typeof(target)=="Vector3" and FreeKickTrajectory.Compute(self.Ball.Position,target,userCurve,(tonumber(model:GetAttribute("VTRFreeKickLift"))or 0)*0.5) or nil
		if solved then
			self.Active={Lateral=solved.Lateral,Strength=solved.Strength,Remaining=solved.FlightTime,Decay=0}
			self.Ball.AssemblyAngularVelocity+=Vector3.new(0,(userCurve>=0 and -1 or 1)*math.max(solved.Strength,1)*1.6,0)
			return solved.Compensation
		end
	end
	local lateral=flat.Unit:Cross(Vector3.yAxis)*(finesse and -footSign or footSign);local duration=math.clamp(flightTime,.28,1.35);local strength=(7+curve*.085)*(userCurve and math.clamp(math.abs(userCurve),0,2.5) or 1);local decay=.9
	if finesse then strength*=3.65*(1+practiceFinesseCurve*4.5);duration=math.clamp(duration*(1.48+practiceFinesseCurve*.42),.7,2.6);decay=math.max(.14,.24-practiceFinesseCurve*.1)end
	local horizontalSpeed=Vector3.new(self.Ball.AssemblyLinearVelocity.X,0,self.Ball.AssemblyLinearVelocity.Z).Magnitude
	local guided=finesse and practiceFinesseCurve>.01
	local displacement=strength/decay*duration-strength/(decay*decay)*(1-math.exp(-decay*duration))
	local compensation=-lateral*(displacement/duration)
	if guided then
		local curveMultiplier=1+practiceFinesseCurve*9
		local bendMagnitude=(28+practiceFinesseCurve*118)*curveMultiplier
		local earlyMagnitude=(12+practiceFinesseCurve*46)*curveMultiplier
		local bendAverage=bendMagnitude*(.62*2/math.pi+1/2.35)
		local earlyAverage=earlyMagnitude/3
		local lateralBias=-(bendAverage-earlyAverage)
		compensation=lateral*lateralBias
		local target=typeof(targetPoint)=="Vector3" and targetPoint or nil
		local targetFlat=target and Vector3.new(target.X,self.Ball.Position.Y,target.Z) or nil
		local startFlat=Vector3.new(self.Ball.Position.X,self.Ball.Position.Y,self.Ball.Position.Z)
		local distance=targetFlat and Vector3.new(targetFlat.X-startFlat.X,0,targetFlat.Z-startFlat.Z).Magnitude or 0
		local requestedAmplitude=math.clamp(6+distance*.045,8,18)*curveMultiplier
		local reachableAmplitude=math.max(8,Physics.MAX_BALL_SPEED*duration*.19)
		local pathAmplitude=targetFlat and math.min(requestedAmplitude,reachableAmplitude) or nil
		self.Active={Lateral=lateral,Strength=strength,Remaining=duration,Decay=decay,Guided=guided,Age=0,Duration=duration,Forward=flat.Unit,BaseSpeed=horizontalSpeed,PracticeCurve=practiceFinesseCurve,LateralBias=lateralBias,BendMagnitude=bendMagnitude,EarlyMagnitude=earlyMagnitude,Start=startFlat,Target=targetFlat,PathAmplitude=pathAmplitude}
	else
		self.Active={Lateral=lateral,Strength=strength,Remaining=duration,Decay=decay}
	end
	self.Ball.AssemblyAngularVelocity+=Vector3.new(0,(finesse and -footSign or footSign)*strength*(finesse and 4.4 or 2.4),0)
	return compensation
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
	if active.Guided then
		active.Age=(active.Age or 0)+dt
		local duration=math.max(active.Duration or .8,.08)
		local u=math.clamp((active.Age or 0)/duration,0,1)
		local forward=active.Forward or horizontal.Unit
		local baseSpeed=math.max(active.BaseSpeed or 0,horizontal:Dot(forward),horizontal.Magnitude*.85,35)
		active.BaseSpeed=baseSpeed
		local curve=math.clamp(active.PracticeCurve or 0,0,1)
		local curveMultiplier=1+curve*9
		local bendMagnitude=active.BendMagnitude or (28+curve*118)*curveMultiplier
		local earlyMagnitude=active.EarlyMagnitude or (12+curve*46)*curveMultiplier
		local bendSpeed=bendMagnitude*(math.sin(math.pi*u)*.62+u^1.35)
		local earlyOut=(1-u)^2*earlyMagnitude
		local guidedHorizontal=forward*baseSpeed+(active.Lateral or Vector3.xAxis)*((active.LateralBias or 0)+bendSpeed-earlyOut)
		if active.Start and active.Target and active.PathAmplitude then
			local nextU=math.clamp(u+dt/duration,0,1)
			local start=active.Start
			local target=active.Target
			local basePoint=start:Lerp(target,nextU)
			local offset=math.sin(math.pi*nextU)*(active.PathAmplitude or 0)
			local desiredPoint=basePoint+(active.Lateral or Vector3.xAxis)*offset
			local currentFlat=Vector3.new(self.Ball.Position.X,start.Y,self.Ball.Position.Z)
			local desiredVelocity=(desiredPoint-currentFlat)/math.max(dt,1/240)
			local desiredHorizontal=Vector3.new(desiredVelocity.X,0,desiredVelocity.Z)
			if desiredHorizontal.Magnitude>1 then guidedHorizontal=desiredHorizontal end
		end
		local maxSpeed=math.max(baseSpeed*6,baseSpeed+math.abs(active.LateralBias or 0)+bendMagnitude+earlyMagnitude+40)
		if guidedHorizontal.Magnitude>maxSpeed then guidedHorizontal=guidedHorizontal.Unit*maxSpeed end
		self.Ball.AssemblyLinearVelocity=Vector3.new(guidedHorizontal.X,velocity.Y,guidedHorizontal.Z)
		self.Ball.AssemblyAngularVelocity+=Vector3.new(0,(bendSpeed-earlyOut)*.55,0)
		return
	end
	self.Ball.AssemblyLinearVelocity = velocity + active.Lateral * active.Strength * dt
	if (active.Decay or 1.4)>0 then active.Strength *= math.exp(-dt * (active.Decay or 1.4))end
end

return Service
