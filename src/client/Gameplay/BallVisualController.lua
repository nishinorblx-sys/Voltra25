--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local BallTrajectory = require(ReplicatedStorage.VTR.Shared.BallTrajectory)

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
	local raycast=RaycastParams.new();raycast.FilterType=Enum.RaycastFilterType.Exclude;local excluded={ball,model};if ball.Parent and ball.Parent:IsA("Model")then table.insert(excluded,ball.Parent)end;if self.VisualModel then table.insert(excluded,self.VisualModel)elseif self.Visual then table.insert(excluded,self.Visual)end;raycast.FilterDescendantsInstances=excluded;self.Raycast=raycast
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
	self.TrailHeld=false;self.PassTrailUntil=os.clock()+2.35;self.TrailSequence=(self.TrailSequence or 0)+1;self.ShotTrail.Lifetime=.62;self.ShotTrail.Enabled=true
end

function Controller:HoldShotTrail()
	if not self.ShotTrail then return end
	self.TrailSequence=(self.TrailSequence or 0)+1;self.TrailHeld=true;self.ShotTrail.Enabled=true
end

function Controller:StopShotTrail()
	self.TrailHeld=false;self.PassTrailUntil=nil;self.TrailSequence=(self.TrailSequence or 0)+1
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

function Controller:StartTrajectory(data: any)
	if type(data) ~= "table" or type(data.Id) ~= "number" then return end
	self.ActiveTrajectory = data
	self.TrajectoryCorrectionUntil = os.clock() + ((Config.Ball.Flight and Config.Ball.Flight.ReconcileDuration) or 0.1)
	self.TrajectoryCorrectionFrom = self.PredictedPosition or self.Ball.Position
	self.PredictedPosition = BallTrajectory.Sample(data, math.clamp((workspace:GetServerTimeNow() - (tonumber(data.StartServerTime) or workspace:GetServerTimeNow())) / math.max(tonumber(data.Duration) or 1, 0.05), 0, 1))
	self.PredictedVelocity = BallTrajectory.Velocity(data, 0)
end

function Controller:Update(dt: number, move: Vector3, sprinting: boolean)
	local ownerName = tostring(self.Ball:GetAttribute("OwnerModel") or "")
	local owns = self.Ball:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId or ownerName == self.Model.Name
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
	local motionKind=tostring(self.Ball:GetAttribute("VTRMotionKind") or "")
	local trajectory=self.ActiveTrajectory
	if trajectory and tonumber(trajectory.Id)==tonumber(self.Ball:GetAttribute("VTRTrajectoryId")) and self.Ball:GetAttribute("VTRKinematicFlight")==true then
		local alpha=math.clamp((workspace:GetServerTimeNow()-(tonumber(trajectory.StartServerTime)or workspace:GetServerTimeNow()))/math.max(tonumber(trajectory.Duration)or 1,.05),0,1)
		local sampled=BallTrajectory.Sample(trajectory,alpha)
		local velocity=BallTrajectory.Velocity(trajectory,alpha)
		if trajectory.KickKind=="Pass"and trajectory.PassType~="Lofted"and trajectory.PassType~="ManualLobbed"then
			local hit=workspace:Raycast(sampled+Vector3.new(0,4,0),Vector3.new(0,-12,0),self.Raycast)
			if hit and hit.Normal.Y>.55 then
				local groundY=(hit.Position+hit.Normal*(self.Radius+.012)).Y
				local maxLift=trajectory.PassType=="Through"and .42 or .18
				sampled=Vector3.new(sampled.X,math.clamp(sampled.Y,groundY,groundY+maxLift),sampled.Z)
				velocity=Vector3.new(velocity.X,math.clamp(velocity.Y,-1.5,1.2),velocity.Z)
			end
		end
		local correctionUntil=tonumber(self.TrajectoryCorrectionUntil)or 0
		if correctionUntil>os.clock() and typeof(self.TrajectoryCorrectionFrom)=="Vector3"then
			local blend=1-math.clamp((correctionUntil-os.clock())/math.max((Config.Ball.Flight and Config.Ball.Flight.ReconcileDuration)or .1,.02),0,1)
			sampled=(self.TrajectoryCorrectionFrom :: Vector3):Lerp(sampled,blend)
		end
		self.PredictedPosition=sampled
		self.PredictedVelocity=velocity
		local travel=Vector3.new(sampled.X-self.LastVisualPosition.X,0,sampled.Z-self.LastVisualPosition.Z)
		self.LastVisualPosition=sampled
		if travel.Magnitude>.001 then
			local axis=Vector3.yAxis:Cross(travel.Unit)
			self.Orientation=CFrame.fromAxisAngle(axis,travel.Magnitude/self.Radius)*self.Orientation
		end
		local desired=CFrame.new(sampled)*self.Orientation.Rotation
		if self.VisualModel then self.VisualModel:PivotTo(desired)else self.Visual.CFrame=desired end
		if self.Shadow then
			local hit=workspace:Raycast(sampled+Vector3.new(0,1,0),Vector3.new(0,-30,0),self.Raycast)
			if hit then local height=math.max(0,sampled.Y-hit.Position.Y);local scale=math.clamp(1-height/18,.42,1);self.Shadow.Size=Vector3.new(.035,2.1*scale,2.1*scale);self.Shadow.CFrame=CFrame.new(hit.Position+hit.Normal*.035)*CFrame.Angles(0,0,math.pi/2);self.Shadow.Transparency=math.clamp(.56+height/38,.56,.83)else self.Shadow.Transparency=1 end
		end
		return
	elseif trajectory and (tonumber(trajectory.Id)or 0)<=(tonumber(self.Ball:GetAttribute("VTRTrajectoryId"))or 0) then
		self.ActiveTrajectory=nil
	end
	local glidingMotion=motionKind=="Dribble"
	if self.ShotTrail and self.ShotTrail.Enabled and not self.TrailHeld then
		if (motionKind=="Shot"or motionKind=="Corner")and authoritativeVelocity.Magnitude<3 then self:StopShotTrail()end
		local passTrailActive=(tonumber(self.PassTrailUntil)or 0)>os.clock()
		if (motionKind=="Pass"or motionKind=="Clearance"or passTrailActive)and authoritativeVelocity.Magnitude<2.4 then self:StopShotTrail()end
		if passTrailActive and motionKind~="Pass"and motionKind~="Clearance"and authoritativeVelocity.Magnitude>=2.4 then self.ShotTrail.Enabled=true end
	end
	local predictedPosition:Vector3=self.PredictedPosition or authoritativePosition
	local predictedVelocity:Vector3=self.PredictedVelocity or authoritativeVelocity
	local positionError=(authoritativePosition-predictedPosition).Magnitude
	local snapDistance = postGoalActive and 28 or glidingMotion and Config.Ball.DribbleHardSnapDistance or motionKind=="Shot" and 11 or 8
	if positionError > snapDistance then
		-- Set pieces and genuine corrections should snap. Ordinary replication
		-- gaps are extrapolated below instead of freezing the visible ball.
		predictedPosition=authoritativePosition
		predictedVelocity=authoritativeVelocity
	else
		local velocityRate = postGoalActive and 34 or motionKind=="Dribble" and 10 or motionKind=="Pass" and 9 or owns and 18 or 15
		local velocityAlpha=1-math.exp(-velocityRate*dt)
		local previousFlat=Vector3.new(predictedVelocity.X,0,predictedVelocity.Z)
		local currentFlat=Vector3.new(authoritativeVelocity.X,0,authoritativeVelocity.Z)
		-- Pick up bounces and ricochets immediately, while smoothing small network
		-- variations that otherwise make a decal appear to detach from the sphere.
		if not glidingMotion and (predictedVelocity.Y*authoritativeVelocity.Y<-.5 or(previousFlat.Magnitude>3 and currentFlat.Magnitude>3 and previousFlat.Unit:Dot(currentFlat.Unit)<.35))then velocityAlpha=math.max(velocityAlpha,.72)end
		predictedVelocity=predictedVelocity:Lerp(authoritativeVelocity,velocityAlpha)
		predictedPosition+=predictedVelocity*dt
		local reconcileRate=postGoalActive and 24 or motionKind=="Dribble" and 6 or motionKind=="Pass" and 5.5 or owns and 12 or(motionKind=="Shot"and 10 or 12)
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
		local lead=rootVelocity.Magnitude>6 and rootVelocity.Unit:Dot(direction)>.35 and math.clamp(rootVelocity.Magnitude*.024,0,sprinting and .55 or .32)or 0
		local distance=Config.Ball.DribbleDistance+(sprinting and .72 or .18)+lead
		local control=root.Position+direction*distance-Vector3.new(0,Config.Ball.DribbleVerticalOffset,0)
		local radius=math.max(self.Radius,Config.Ball.Radius or .1)
		local rootFlat=Vector3.new(root.Position.X,0,root.Position.Z)
		local controlFlat=Vector3.new(control.X,0,control.Z)
		local minSeparation=math.max(radius*1.28,1.55)
		if (controlFlat-rootFlat).Magnitude<minSeparation then
			controlFlat=rootFlat+direction*minSeparation
		end
		control=Vector3.new(controlFlat.X,math.min(control.Y,root.Position.Y-.72),controlFlat.Z)
		local alpha=sprinting and .86 or .78
		local ownedY=math.min(predictedPosition.Y+(control.Y-predictedPosition.Y)*alpha,root.Position.Y-.72)
		target=Vector3.new(target.X+(control.X-target.X)*alpha,ownedY,target.Z+(control.Z-target.Z)*alpha)
		if (Vector3.new(authoritativePosition.X,0,authoritativePosition.Z)-Vector3.new(control.X,0,control.Z)).Magnitude < 9 then
			self.PredictedPosition=target
		end
	end
	local groundHit=workspace:Raycast(target+Vector3.new(0,2,0),Vector3.new(0,-8,0),self.Raycast)
	if groundHit and groundHit.Normal.Y > 0.55 then
		local height=(target-groundHit.Position):Dot(groundHit.Normal)
		local desiredGroundHeight = self.Radius + 0.035
		if (glidingMotion or owns or motionKind=="Pass"or motionKind=="Clearance") and height < self.Radius + 1.45 then
			local groundTarget = groundHit.Position + groundHit.Normal * desiredGroundHeight
			local alpha = 1 - math.exp(-dt / ((motionKind == "Dribble" or owns) and 0.025 or 0.06))
			target = Vector3.new(target.X, target.Y + (groundTarget.Y - target.Y) * alpha, target.Z)
			local vertical = predictedVelocity:Dot(groundHit.Normal)
			if math.abs(vertical) < 8 then
				predictedVelocity -= groundHit.Normal * vertical
				self.PredictedVelocity = predictedVelocity
			end
			self.PredictedPosition = target
			height = (target-groundHit.Position):Dot(groundHit.Normal)
		end
		if height<self.Radius-.04 then
			target+=groundHit.Normal*(self.Radius-height+.02)
			local vertical=predictedVelocity:Dot(groundHit.Normal)
			if vertical<0 then
				predictedVelocity-=groundHit.Normal*vertical
				self.PredictedVelocity=predictedVelocity
			end
			self.PredictedPosition=target
		end
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
