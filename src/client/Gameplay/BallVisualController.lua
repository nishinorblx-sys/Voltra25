--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local BallTrajectory = require(ReplicatedStorage.VTR.Shared.BallTrajectory)
local DribbleTargetResolver = require(ReplicatedStorage.VTR.Shared.DribbleTargetResolver)
local MatchVisualCleanupService = require(script.Parent.Parent.Services.MatchVisualCleanupService)

local Controller = {}
Controller.__index = Controller

local function ballModel(ball: BasePart): Model?
	local parent = ball.Parent
	if not parent or not parent:IsA("Model") then return nil end
	if parent.Name == "VTRBallModel" or parent.PrimaryPart == ball or tostring(ball:GetAttribute("BallTemplateModel") or "") == parent.Name then
		return parent
	end
	return nil
end

local function isEnabledVisual(instance: Instance): boolean
	return instance:IsA("Trail") or instance:IsA("Beam") or instance:IsA("ParticleEmitter") or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles") or instance:IsA("SurfaceGui") or instance:IsA("BillboardGui")
end

local function isApprovedVisualDescendant(instance: Instance): boolean
	return instance:IsA("DataModelMesh") or instance:IsA("Decal") or instance:IsA("Texture") or instance:IsA("SurfaceAppearance") or instance:IsA("Attachment")
		or instance:IsA("Folder")
		or instance:IsA("Configuration")
end

local function cloneVisualPart(source: BasePart): BasePart?
	local ok, clone = pcall(function()
		return source:Clone()
	end)
	if not ok or not clone or not clone:IsA("BasePart") then return nil end
	for _, descendant in clone:GetDescendants() do
		if descendant.Parent and (descendant:IsA("BasePart") or not isApprovedVisualDescendant(descendant)) then
			descendant:Destroy()
		end
	end
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.CastShadow = source.CastShadow
	clone.LocalTransparencyModifier = source.LocalTransparencyModifier
	return clone
end

function Controller:_captureOriginal(instance: Instance)
	if self.OriginalStateByInstance[instance] then return end
	local state: any = {Instance = instance}
	if instance:IsA("BasePart") then
		state.Kind = "BasePart"
		state.Transparency = instance.Transparency
		state.LocalTransparencyModifier = instance.LocalTransparencyModifier
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		state.Kind = "Surface"
		state.Transparency = instance.Transparency
	elseif isEnabledVisual(instance) then
		state.Kind = "Enabled"
		state.Enabled = (instance :: any).Enabled
	else
		return
	end
	self.OriginalStateByInstance[instance] = state
	table.insert(self.OriginalStates, state)
end

function Controller:_hideOriginalState(state: any)
	local instance = state.Instance
	if not instance or (instance ~= self.Ball and instance.Parent == nil) then return end
	if state.Kind == "BasePart" then
		instance.LocalTransparencyModifier = 1
	elseif state.Kind == "Surface" then
		instance.Transparency = 1
	elseif state.Kind == "Enabled" then
		instance.Enabled = false
	end
end

function Controller:_hideOriginal()
	for _, state in self.OriginalStates do
		self:_hideOriginalState(state)
	end
end

function Controller:_restoreOriginal()
	for _, state in self.OriginalStates do
		local instance = state.Instance
		if not instance or (instance ~= self.Ball and instance.Parent == nil) then continue end
		if state.Kind == "BasePart" then
			instance.Transparency = state.Transparency
			instance.LocalTransparencyModifier = state.LocalTransparencyModifier
		elseif state.Kind == "Surface" then
			instance.Transparency = state.Transparency
		elseif state.Kind == "Enabled" then
			instance.Enabled = state.Enabled
		end
	end
end

function Controller:_captureOriginalTree(root: Instance)
	self:_captureOriginal(root)
	for _, descendant in root:GetDescendants() do
		self:_captureOriginal(descendant)
	end
end

function Controller:_refreshRaycastExclusions()
	if not self.Raycast then return end
	local excluded: {Instance} = {self.Ball, self.Model}
	for _, candidate in workspace:GetDescendants() do
		if candidate:IsA("Model") and candidate ~= self.Model and candidate:GetAttribute("VTRTeam") ~= nil and candidate:FindFirstChildOfClass("Humanoid") then
			table.insert(excluded, candidate)
		end
	end
	local sourceModel = ballModel(self.Ball)
	if sourceModel then table.insert(excluded, sourceModel) end
	if self.VisualModel then
		table.insert(excluded, self.VisualModel)
	elseif self.Visual then
		table.insert(excluded, self.Visual)
	end
	if self.Shadow then table.insert(excluded, self.Shadow) end
	self.Raycast.FilterDescendantsInstances = excluded
end

function Controller.new(ball: BasePart, model: Model)
	local raycast = RaycastParams.new()
	raycast.FilterType = Enum.RaycastFilterType.Exclude
	raycast.IgnoreWater = true
	local sourceRoot = ballModel(ball) or ball
	local self=setmetatable({
		Ball = ball,
		Model = model,
		OriginalRoot = sourceRoot,
		OriginalStates = {},
		OriginalStateByInstance = {},
		Orientation = CFrame.identity,
		LastVisualPosition = ball.Position,
		PredictedPosition = ball.Position,
		PredictedVelocity = ball.AssemblyLinearVelocity,
		Radius = math.max(ball.Size.X * 0.5, 0.1),
		Raycast = raycast,
	}, Controller)
	self:_captureOriginalTree(sourceRoot)
	self:_createVisual()
	local shadow=Instance.new("Part");shadow.Name="VTRBallShadow";shadow.Shape=Enum.PartType.Cylinder;shadow.Size=Vector3.new(.035,2.1,2.1);shadow.Anchored=true;shadow.CanCollide=false;shadow.CanTouch=false;shadow.CanQuery=false;shadow.CastShadow=false;shadow.Material=Enum.Material.SmoothPlastic;shadow.Color=Color3.new(0,0,0);shadow.Transparency=.62;shadow.Parent=workspace;MatchVisualCleanupService.RegisterTemporary(shadow);self.Shadow=shadow
	self:_refreshRaycastExclusions()
	self.DescendantAddedConnection = sourceRoot.DescendantAdded:Connect(function(descendant)
		if self.Destroyed then return end
		local additions = {descendant}
		for _, child in descendant:GetDescendants() do table.insert(additions, child) end
		for _, addition in additions do
			self:_captureOriginal(addition)
			local state = self.OriginalStateByInstance[addition]
			if state then self:_hideOriginalState(state) end
		end
	end)
	return self
end

function Controller:_createVisual()
	self:_restoreOriginal()
	self.ShotTrail = nil
	if self.VisualModel then
		self.VisualModel:Destroy()
		self.VisualModel = nil
	elseif self.Visual then
		self.Visual:Destroy()
		self.Visual = nil
	end
	local sourceModel = ballModel(self.Ball)
	if sourceModel then
		local proxy = Instance.new("Model")
		proxy.Name = "VTRPredictedBall"
		local visualRoot: BasePart? = nil
		for _, descendant in sourceModel:GetDescendants() do
			if not descendant:IsA("BasePart") then continue end
			local visualPart = cloneVisualPart(descendant)
			if not visualPart then continue end
			visualPart.CFrame = descendant.CFrame
			visualPart.Parent = proxy
			if descendant == self.Ball then visualRoot = visualPart end
		end
		if not visualRoot then
			proxy:Destroy()
			return
		end
		proxy.PrimaryPart = visualRoot
		proxy.Parent = workspace
		MatchVisualCleanupService.RegisterTemporary(proxy)
		self.VisualModel = proxy
		self.Visual = visualRoot
	else
		local visual = cloneVisualPart(self.Ball)
		if not visual then return end
		visual.Name = "VTRPredictedBall"
		visual.Parent = workspace
		MatchVisualCleanupService.RegisterTemporary(visual)
		self.Visual = visual
	end
	self:_hideOriginal()
	self:_refreshRaycastExclusions()
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

function Controller:_sampleGround(position: Vector3, startHeight: number, depth: number): RaycastResult?
	return workspace:Raycast(position + Vector3.new(0, startHeight, 0), Vector3.new(0, -depth, 0), self.Raycast)
end

function Controller:_updateShadow(position: Vector3, groundHit: RaycastResult?)
	if not self.Shadow then return end
	local hit = groundHit
	if not hit or hit.Normal.Y <= .35 then
		hit = self:_sampleGround(position, 1, 30)
	end
	if not hit then
		self.Shadow.Transparency = 1
		return
	end
	local height = math.max(0, position.Y - hit.Position.Y)
	local scale = math.clamp(1 - height / 18, .42, 1)
	self.Shadow.Size = Vector3.new(.035, 2.1 * scale, 2.1 * scale)
	self.Shadow.CFrame = CFrame.new(hit.Position + hit.Normal * .035) * CFrame.Angles(0, 0, math.pi / 2)
	self.Shadow.Transparency = math.clamp(.56 + height / 38, .56, .83)
end

function Controller:Update(dt: number, move: Vector3, sprinting: boolean)
	local ownerName = tostring(self.Ball:GetAttribute("OwnerModel") or "")
	local owns = self.Ball:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId or ownerName == self.Model.Name
	if not self.Visual or not self.Visual.Parent then self:_createVisual()end
	if not self.Visual then return end
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
		local groundHit: RaycastResult? = nil
		if trajectory.KickKind=="Pass"and trajectory.PassType~="Lofted"and trajectory.PassType~="ManualLobbed"then
			local hit=self:_sampleGround(sampled,4,12)
			groundHit=hit
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
		self:_updateShadow(sampled,groundHit)
		return
	elseif trajectory and (tonumber(trajectory.Id)or 0)<=(tonumber(self.Ball:GetAttribute("VTRTrajectoryId"))or 0) then
		self.ActiveTrajectory=nil
	end
	local glidingMotion=motionKind=="Dribble"
	if self.ShotTrail and self.ShotTrail.Enabled and not self.TrailHeld then
		if motionKind~="Shot"and motionKind~="Pass"then self:StopShotTrail()end
		if motionKind=="Shot"and authoritativeVelocity.Magnitude<3 then self:StopShotTrail()end
		local passTrailActive=(tonumber(self.PassTrailUntil)or 0)>os.clock()
		if (motionKind=="Pass"or passTrailActive)and authoritativeVelocity.Magnitude<2.4 then self:StopShotTrail()end
	end
	local predictedPosition:Vector3=self.PredictedPosition or authoritativePosition
	local predictedVelocity:Vector3=self.PredictedVelocity or authoritativeVelocity
	local positionError=(authoritativePosition-predictedPosition).Magnitude
	local ranked=self.Model:GetAttribute("VTRRankedMatch")==true
	local snapDistance = postGoalActive and 28 or glidingMotion and(ranked and math.max(9,Config.Ball.DribbleHardSnapDistance)or Config.Ball.DribbleHardSnapDistance)or motionKind=="Shot" and 11 or 8
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
		local reconcileRate=postGoalActive and 24 or motionKind=="Dribble"and(ranked and(owns and 5.5 or 4.5)or 6)or motionKind=="Pass" and 5.5 or owns and 12 or(motionKind=="Shot"and 10 or 12)
		predictedPosition=predictedPosition:Lerp(authoritativePosition,1-math.exp(-reconcileRate*dt))
	end
	self.PredictedPosition=predictedPosition
	self.PredictedVelocity=predictedVelocity
	local velocity=predictedVelocity
	local target=predictedPosition
	if owns and root then
		local facing=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
		local rootVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z)
		local touchStarted = tonumber(self.Ball:GetAttribute("VTRDribbleTouchStartedAt")) or workspace:GetServerTimeNow()
		local touchDuration = math.max(tonumber(self.Ball:GetAttribute("VTRDribbleTouchDuration")) or 0.4, 0.05)
		local touchPhase = math.clamp((workspace:GetServerTimeNow() - touchStarted) / touchDuration, 0, 1)
		local targetData = DribbleTargetResolver.Resolve({
			RootPosition = root.Position,
			RootLookVector = facing,
			MoveVector = move,
			HorizontalVelocity = rootVelocity,
			Sprinting = sprinting,
			CloseControl = self.Model:GetAttribute("VTRCloseControl") == true,
			BallControl = tonumber(self.Model:GetAttribute("BallControl")) or tonumber(self.Model:GetAttribute("DRI")) or 60,
			TurnDot = move.Magnitude > 0.08 and facing.Magnitude > 0.05 and move.Unit:Dot(facing.Unit) or 1,
			TouchPhase = touchPhase,
			BallRadius = math.max(self.Radius, Config.Ball.Radius or 0.1),
			VerticalOffset = Config.Ball.DribbleVerticalOffset,
			ActionLocked = (tonumber(self.Model:GetAttribute("VTRActionLockedUntil")) or 0) > os.clock(),
		})
		local control = targetData.PredictedVisualTarget
		local alpha = 1 - math.exp(-targetData.CorrectionStrength * dt)
		target = predictedPosition:Lerp(control, alpha)
		self.VisualTarget = target
		if (Vector3.new(authoritativePosition.X,0,authoritativePosition.Z)-Vector3.new(control.X,0,control.Z)).Magnitude < targetData.HardRecoveryDistance then
			self.PredictedPosition=target
		end
	elseif glidingMotion then
		local serverTarget = self.Ball:GetAttribute("VTRDribbleServerTarget")
		if typeof(serverTarget) == "Vector3" then
			local alpha = 1 - math.exp(-14 * dt)
			target = target:Lerp(serverTarget, alpha)
			self.PredictedPosition = target
		end
		self.VisualTarget = target
	else
		self.VisualTarget = target
	end
	local groundHit=self:_sampleGround(target,2,8)
	if groundHit and groundHit.Normal.Y > 0.55 then
		local height=(target-groundHit.Position):Dot(groundHit.Normal)
		local desiredGroundHeight = self.Radius + 0.035
		if glidingMotion or ((owns or motionKind=="Pass"or motionKind=="Clearance") and height < self.Radius + 1.45) then
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
	self:_updateShadow(target,groundHit)
end

function Controller:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	if self.DescendantAddedConnection then self.DescendantAddedConnection:Disconnect();self.DescendantAddedConnection=nil end
	if self.VisualModel then self.VisualModel:Destroy() elseif self.Visual then self.Visual:Destroy() end
	if self.Shadow then self.Shadow:Destroy()end
	self.VisualModel=nil;self.Visual=nil;self.Shadow=nil;self.ShotTrail=nil
	self:_restoreOriginal()
	table.clear(self.OriginalStates)
	table.clear(self.OriginalStateByInstance)
end

function Controller:GetFocusPosition(): Vector3
	return self.VisualTarget or self.PredictedPosition or self.Ball.Position
end

return Controller
