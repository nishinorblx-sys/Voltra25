--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local Controller = {}
Controller.__index = Controller

local function ballModel(ball: BasePart): Model?
	return ball.Parent and ball.Parent:IsA("Model") and ball.Parent or nil
end

local function hideOriginal(ball: BasePart, hidden: boolean)
	local model = ballModel(ball)
	if model then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then descendant.LocalTransparencyModifier = hidden and 1 or 0
			elseif descendant:IsA("Decal")or descendant:IsA("Texture")then descendant.Transparency=hidden and 1 or 0 end
		end
	else
		ball.LocalTransparencyModifier = hidden and 1 or 0
		for _,child in ball:GetDescendants()do if child:IsA("Decal")or child:IsA("Texture")then child.Transparency=hidden and 1 or 0 end end
	end
end

local function showVisual(instance: Instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 0
		elseif (descendant:IsA("Decal") or descendant:IsA("Texture")) and descendant.Transparency >= 0.99 then
			descendant.Transparency = 0
		end
	end
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = 0
	end
end

function Controller.new(ball: BasePart, model: Model)
	for _, child in workspace:GetChildren() do
		if child.Name == "VTRPredictedBall" and child ~= ball and child ~= ball.Parent then
			child:Destroy()
		end
	end
	local self=setmetatable({
		Ball = ball,
		Model = model,
		Orientation = CFrame.identity,
		LastVisualPosition = ball.Position,
		PredictedPosition = ball.Position,
		PredictedVelocity = ball.AssemblyLinearVelocity,
		Radius = math.max(ball.Size.X * 0.5, 0.1),
	}, Controller)
	self:_createVisual()
	local shadow=Instance.new("Part");shadow.Name="VTRBallShadow";shadow.Shape=Enum.PartType.Cylinder;shadow.Size=Vector3.new(.035,2.1,2.1);shadow.Anchored=true;shadow.CanCollide=false;shadow.CanTouch=false;shadow.CanQuery=false;shadow.CastShadow=false;shadow.Material=Enum.Material.SmoothPlastic;shadow.Color=Color3.new(0,0,0);shadow.Transparency=.62;shadow.Parent=workspace;self.Shadow=shadow
	local raycast=RaycastParams.new();raycast.FilterType=Enum.RaycastFilterType.Exclude;local excluded={ball};if ball.Parent and ball.Parent:IsA("Model")then table.insert(excluded,ball.Parent)end;if self.VisualModel then table.insert(excluded,self.VisualModel)elseif self.Visual then table.insert(excluded,self.Visual)end;raycast.FilterDescendantsInstances=excluded;self.Raycast=raycast
	return self
end

function Controller:_createVisual()
	if self.VisualModel then
		self.VisualModel:Destroy()
		self.VisualModel = nil
	elseif self.Visual then
		self.Visual:Destroy()
		self.Visual = nil
	end
	local sourceModel = ballModel(self.Ball)
	if sourceModel then
		local clone = sourceModel:Clone()
		clone.Name = "VTRPredictedBall"
		for _, descendant in clone:GetDescendants() do if descendant:IsA("BasePart") then descendant.Anchored = true;descendant.CanCollide = false;descendant.CanQuery = false;descendant.CanTouch = false end end
		showVisual(clone)
		clone.Parent = workspace
		self.VisualModel = clone
		self.Visual = clone:FindFirstChild(self.Ball.Name, true) :: BasePart?
	else
		local visual = self.Ball:Clone()
		visual.Name = "VTRPredictedBall";visual.Anchored = true;visual.CanCollide = false;visual.CanQuery = false;visual.CanTouch = false;visual.Parent = workspace
		showVisual(visual)
		self.Visual = visual
	end
	hideOriginal(self.Ball, true)
	local trailRoot=self.Visual
	if trailRoot then
		local top=Instance.new("Attachment");top.Name="VTRShotTrailTop";top.Position=Vector3.new(0,self.Radius*.48,0);top.Parent=trailRoot
		local bottom=Instance.new("Attachment");bottom.Name="VTRShotTrailBottom";bottom.Position=Vector3.new(0,-self.Radius*.48,0);bottom.Parent=trailRoot
		local trail=Instance.new("Trail");trail.Name="VTRShotTrail";trail.Attachment0=top;trail.Attachment1=bottom;trail.Color=ColorSequence.new(Color3.fromHex("F4F5F1"),Color3.fromHex("B7FF1A"));trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(1,1)});trail.Lifetime=.18;trail.LightEmission=.75;trail.FaceCamera=true;trail.Enabled=false;trail.Parent=trailRoot;self.ShotTrail=trail
	end
end

function Controller:PlayShotTrail()
	if not self.ShotTrail then return end
	self.TrailHeld=false;self.TrailSequence=(self.TrailSequence or 0)+1;self.ShotTrail.Enabled=true
end

function Controller:PlayFlightTrail()
	if not self.ShotTrail then return end
	self.TrailHeld=false;self.TrailSequence=(self.TrailSequence or 0)+1;self.ShotTrail.Lifetime=.3;self.ShotTrail.Enabled=true
end

function Controller:HoldShotTrail()
	if not self.ShotTrail then return end
	self.TrailSequence=(self.TrailSequence or 0)+1;self.TrailHeld=true;self.ShotTrail.Enabled=true
end

function Controller:StopShotTrail()
	self.TrailHeld=false;self.TrailSequence=(self.TrailSequence or 0)+1
	if self.ShotTrail then self.ShotTrail.Lifetime=.18;self.ShotTrail.Enabled=false end
end

function Controller:SnapTo(position: Vector3?, velocity: Vector3?, lockDuration: number?)
	local target = position or self.Ball.Position
	local currentVelocity = velocity or self.Ball.AssemblyLinearVelocity
	hideOriginal(self.Ball, true)
	self.PredictedPosition = target
	self.PredictedVelocity = currentVelocity
	self.LastVisualPosition = target
	if lockDuration and lockDuration > 0 then
		self.LockedPosition = target
		self.LockedVelocity = currentVelocity
		self.LockedUntil = os.clock() + lockDuration
	end
	local desired = CFrame.new(target) * self.Orientation.Rotation
	if self.VisualModel then self.VisualModel:PivotTo(desired) elseif self.Visual then self.Visual.CFrame = desired end
	if self.Shadow then self.Shadow.Transparency = 1 end
end

function Controller:ClearLock()
	self.LockedPosition = nil
	self.LockedVelocity = nil
	self.LockedUntil = nil
end

function Controller:Update(dt: number, move: Vector3, sprinting: boolean)
	local owns = self.Ball:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
	if not self.Visual then self:_createVisual()end
	if not self.Visual then return end
	hideOriginal(self.Ball, true)
	if self.LockedUntil and os.clock() < self.LockedUntil and typeof(self.LockedPosition) == "Vector3" then
		self:SnapTo(self.LockedPosition, typeof(self.LockedVelocity) == "Vector3" and self.LockedVelocity or Vector3.zero)
		return
	elseif self.LockedUntil then
		self:ClearLock()
	end
	local root = self.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local authoritativePosition=self.Ball.Position
	local authoritativeVelocity=self.Ball.AssemblyLinearVelocity
	local postGoalActive=(tonumber(self.Ball:GetAttribute("VTRPostGoalPhysicsUntil")) or 0)>os.clock()
	if self.ShotTrail and self.ShotTrail.Enabled and not self.TrailHeld then
		local motionKind=self.Ball:GetAttribute("VTRMotionKind")
		if (motionKind=="Shot"or motionKind=="Corner")and authoritativeVelocity.Magnitude<3 then self:StopShotTrail()end
	end
	local predictedPosition:Vector3=self.PredictedPosition or authoritativePosition
	local predictedVelocity:Vector3=self.PredictedVelocity or authoritativeVelocity
	local positionError=(authoritativePosition-predictedPosition).Magnitude
	if positionError>(postGoalActive and 28 or 7) then
		-- Set pieces and genuine corrections should snap. Ordinary replication
		-- gaps are extrapolated below instead of freezing the visible ball.
		predictedPosition=authoritativePosition
		predictedVelocity=authoritativeVelocity
	else
		local velocityAlpha=1-math.exp(-(postGoalActive and 34 or owns and 32 or 24)*dt)
		local previousFlat=Vector3.new(predictedVelocity.X,0,predictedVelocity.Z)
		local currentFlat=Vector3.new(authoritativeVelocity.X,0,authoritativeVelocity.Z)
		-- Pick up bounces and ricochets immediately, while smoothing small network
		-- variations that otherwise make a decal appear to detach from the sphere.
		if predictedVelocity.Y*authoritativeVelocity.Y<-.5 or(previousFlat.Magnitude>3 and currentFlat.Magnitude>3 and previousFlat.Unit:Dot(currentFlat.Unit)<.35)then velocityAlpha=math.max(velocityAlpha,.72)end
		predictedVelocity=predictedVelocity:Lerp(authoritativeVelocity,velocityAlpha)
		predictedPosition+=predictedVelocity*dt
		local reconcileRate=postGoalActive and 24 or owns and 28 or(self.Ball:GetAttribute("VTRMotionKind")=="Shot"and 11 or 16)
		predictedPosition=predictedPosition:Lerp(authoritativePosition,1-math.exp(-reconcileRate*dt))
	end
	self.PredictedPosition=predictedPosition
	self.PredictedVelocity=predictedVelocity
	local velocity=predictedVelocity
	local target=predictedPosition
	if owns and root then
		local facing=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
		local direction=move.Magnitude>.1 and move.Unit or facing.Magnitude>.1 and facing.Unit or Vector3.zAxis
		local rootVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z)
		local lead=rootVelocity.Magnitude>6 and rootVelocity.Unit:Dot(direction)>.35 and math.clamp(rootVelocity.Magnitude*.045,0,sprinting and 1.25 or .75)or 0
		local distance=Config.Ball.DribbleDistance+(sprinting and 2.15 or .45)+lead
		local control=root.Position+direction*distance-Vector3.new(0,Config.Ball.DribbleVerticalOffset,0)
		local alpha=sprinting and .72 or .58
		target=Vector3.new(target.X+(control.X-target.X)*alpha,predictedPosition.Y,target.Z+(control.Z-target.Z)*alpha)
	end
	local travel = Vector3.new(target.X - self.LastVisualPosition.X, 0, target.Z - self.LastVisualPosition.Z)
	self.LastVisualPosition = target
	if travel.Magnitude > 0.001 then
		local axis = Vector3.yAxis:Cross(travel.Unit)
		self.Orientation = CFrame.fromAxisAngle(axis, travel.Magnitude / self.Radius) * self.Orientation
	end
	local desired = CFrame.new(target) * self.Orientation.Rotation
	-- PredictedPosition is already a continuous render-time signal. Applying a
	-- second Lerp here used to make fast shots visibly pause and then catch up.
	if self.VisualModel then self.VisualModel:PivotTo(desired) else self.Visual.CFrame=desired end
	if self.Shadow then
		local hit=workspace:Raycast(target+Vector3.new(0,1,0),Vector3.new(0,-30,0),self.Raycast)
		if hit then local height=math.max(0,target.Y-hit.Position.Y);local scale=math.clamp(1-height/18,.42,1);self.Shadow.Size=Vector3.new(.035,2.1*scale,2.1*scale);self.Shadow.CFrame=CFrame.new(hit.Position+hit.Normal*.035)*CFrame.Angles(0,0,math.pi/2);self.Shadow.Transparency=math.clamp(.56+height/38,.56,.83)else self.Shadow.Transparency=1 end
	end
end

function Controller:Destroy()
	if self.VisualModel then self.VisualModel:Destroy() elseif self.Visual then self.Visual:Destroy() end
	if self.Shadow then self.Shadow:Destroy()end
	hideOriginal(self.Ball, false)
end

return Controller
