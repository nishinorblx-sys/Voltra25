--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local GameplayConfig=require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local Service = {}
Service.__index = Service

function Service.new(pitchCFrame: CFrame, width: number, length: number)
	return setmetatable({PitchCFrame = pitchCFrame, Width = width, Length = length, Cache = {}}, Service)
end

function Service:GetGoalRectangle(active: Model?): any
	local side = active and tostring(active:GetAttribute("VTRTeam") or "Home") or "Home"
	if not self.Cache[side] then
		self.Cache[side] = GoalModelResolver.Resolve(active, self.PitchCFrame, self.Width, self.Length)
		if workspace:GetAttribute("GameplayDebug") == true or workspace:GetAttribute("VTRGameplayDebug") == true then
			local rectangle = self.Cache[side]
			local width = rectangle.RightBound - rectangle.Left
			local height = rectangle.Top - rectangle.Bottom
			local center = rectangle.PlanePoint + rectangle.Right * (rectangle.Left + width * 0.5) + rectangle.Up * (rectangle.Bottom + height * 0.5)
			local outline = Instance.new("Part")
			outline.Name = "VTRGoalPlaneDebug_" .. side
			outline.Anchored = true; outline.CanCollide = false; outline.CanTouch = false; outline.CanQuery = false
			outline.Material = Enum.Material.Neon; outline.Color = Color3.fromHex("B7FF1A"); outline.Transparency = 0.78
			outline.Size = Vector3.new(width, height, 0.08)
			outline.CFrame = CFrame.fromMatrix(center, rectangle.Right, rectangle.Up, rectangle.Normal)
			outline.Parent = workspace
		end
	end
	return self.Cache[side]
end

function Service:ProjectRay(active: Model?, rayOrigin: Vector3, rayDirection: Vector3): (boolean, Vector3?)
	return GoalModelResolver.ProjectRay(self:GetGoalRectangle(active), rayOrigin, rayDirection)
end

function Service:ClampPoint(active: Model?, point: Vector3): Vector3
	return GoalModelResolver.ClampPoint(self:GetGoalRectangle(active), point)
end

function Service:ApplyShotPower(active:Model?,point:Vector3,charge:number):Vector3
	local rectangle=self:GetGoalRectangle(active);local offset=point-rectangle.PlanePoint
	local x=math.clamp(offset:Dot(rectangle.Right),rectangle.Left,rectangle.RightBound)
	local safeBottom=math.min(rectangle.Top,rectangle.Bottom+GameplayConfig.Ball.Radius*.95)
	local baseY=math.clamp(offset:Dot(rectangle.Up),safeBottom,rectangle.Top)
	local safeTop=math.max(rectangle.Bottom,rectangle.Top-math.min(.8,(rectangle.Top-rectangle.Bottom)*.08))
	local powerAlpha=math.clamp(charge/.72,0,1)
	return GoalModelResolver.Point(rectangle,x,baseY+(safeTop-baseY)*powerAlpha)
end

return Service
