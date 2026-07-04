--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local GameplayConfig=require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local Service = {}
Service.__index = Service

function Service.new(pitchCFrame: CFrame, width: number, length: number)
	return setmetatable({PitchCFrame = pitchCFrame, Width = width, Length = length, Cache = {}}, Service)
end

local function attackSignFor(active: Model?): number
	local side = active and tostring(active:GetAttribute("VTRTeam") or "Home") or "Home"
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	if side == "Home" then
		return half >= 2 and 1 or -1
	end
	return half >= 2 and -1 or 1
end

local function attackSignFor(active: Model?): number
	local side = active and tostring(active:GetAttribute("VTRTeam") or "Home") or "Home"
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	if side == "Home" then
		return half >= 2 and 1 or -1
	end
	return half >= 2 and -1 or 1
end

function Service:GetGoalRectangle(active: Model?, forcedGoalSign: number?): any
	if forcedGoalSign then
		local key = "sign:" .. tostring(forcedGoalSign)
		if not self.Cache[key] then
			self.Cache[key] = GoalModelResolver.ResolveByAttackSign(forcedGoalSign, self.PitchCFrame, self.Width, self.Length)
		end
		return self.Cache[key]
	end
	local side = active and tostring(active:GetAttribute("VTRTeam") or "Home") or "Home"
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local key = side .. ":" .. tostring(half)
	if not self.Cache[key] then
		self.Cache[key] = GoalModelResolver.ResolveByAttackSign(attackSignFor(active), self.PitchCFrame, self.Width, self.Length)
	end
	return self.Cache[key]
end

function Service:ProjectRay(active: Model?, rayOrigin: Vector3, rayDirection: Vector3, forcedGoalSign: number?): (boolean, Vector3?)
	return GoalModelResolver.ProjectRay(self:GetGoalRectangle(active, forcedGoalSign), rayOrigin, rayDirection)
end

function Service:ProjectRayToPlane(active: Model?, rayOrigin: Vector3, rayDirection: Vector3, forcedGoalSign: number?): (Vector3?, boolean)
	return GoalModelResolver.ProjectRayToPlane(self:GetGoalRectangle(active, forcedGoalSign), rayOrigin, rayDirection)
end

function Service:ClampPoint(active: Model?, point: Vector3, forcedGoalSign: number?): Vector3
	return GoalModelResolver.ClampPoint(self:GetGoalRectangle(active, forcedGoalSign), point)
end

function Service:ApplyShotPower(active:Model?,point:Vector3,charge:number,forcedGoalSign:number?):Vector3
	local rectangle=self:GetGoalRectangle(active,forcedGoalSign);local offset=point-rectangle.PlanePoint
	local x=math.clamp(offset:Dot(rectangle.Right),rectangle.Left,rectangle.RightBound)
	local safeBottom=math.min(rectangle.Top,rectangle.Bottom+GameplayConfig.Ball.Radius*.95)
	local baseY=math.clamp(offset:Dot(rectangle.Up),safeBottom,rectangle.Top)
	local safeTop=math.max(rectangle.Bottom,rectangle.Top-math.min(.8,(rectangle.Top-rectangle.Bottom)*.08))
	local powerAlpha=math.clamp(charge/.72,0,1)
	return GoalModelResolver.Point(rectangle,x,baseY+(safeTop-baseY)*powerAlpha)
end

return Service
