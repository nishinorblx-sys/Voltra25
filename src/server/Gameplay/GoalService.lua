--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)

local Service = {}
Service.__index = Service

local function isNetPart(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if string.find(string.lower(current.Name), "net", 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function disableGoalCollision(instance: Instance?)
	if not instance then return end
	if instance:IsA("BasePart") and not isNetPart(instance) then
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = true
	end
	for _,descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") and not isNetPart(descendant) then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = true
		end
	end
end

local function createVolume(parent: Instance, team: string, rectangle: any): BasePart
	local width = rectangle.RightBound - rectangle.Left
	local height = rectangle.Top - rectangle.Bottom
	local center = rectangle.PlanePoint + rectangle.Right * (rectangle.Left + width * 0.5) + rectangle.Up * (rectangle.Bottom + height * 0.5) + rectangle.Normal
	local volume = Instance.new("Part")
	volume.Name = team .. "GoalLineVolume"
	volume.Size = Vector3.new(width, height, 2)
	volume.CFrame = CFrame.fromMatrix(center, rectangle.Right, rectangle.Up, rectangle.Normal)
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanTouch = false
	volume.CanQuery = true
	volume.Transparency = 1
	volume.Parent = parent
	return volume
end

local function createNetBackstop(parent: Instance, team: string, rectangle: any): BasePart
	local width = math.max(1, rectangle.RightBound - rectangle.Left)
	local height = math.max(1, rectangle.Top - rectangle.Bottom)
	local center = rectangle.PlanePoint
		+ rectangle.Right * (rectangle.Left + width * 0.5)
		+ rectangle.Up * (rectangle.Bottom + height * 0.5)
		+ rectangle.Normal * 5.5
	local backstop = Instance.new("Part")
	backstop.Name = team .. "GoalNetBackstop"
	backstop.Size = Vector3.new(width + 5, height + 4, 8)
	backstop.CFrame = CFrame.fromMatrix(center, rectangle.Right, rectangle.Up, rectangle.Normal)
	backstop.Anchored = true
	backstop.CanCollide = true
	backstop.CanTouch = true
	backstop.CanQuery = true
	backstop.Transparency = 1
	backstop.CollisionGroup = "GoalNet"
	backstop.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.78, 0.18, 1, 1)
	backstop.Parent = parent
	return backstop
end

function Service.new(ball: BasePart, pitchCFrame: CFrame, width: number, length: number, onGoal: (string) -> ())
	disableGoalCollision(workspace:FindFirstChild("HomeGoal", true))
	disableGoalCollision(workspace:FindFirstChild("AwayGoal", true))
	local goals = {
		{Team = "Home", Hitbox=GoalModelResolver.GetHitboxForSide("Home"), Rectangle = GoalModelResolver.ResolveSide("Home", pitchCFrame, width, length)},
		{Team = "Away", Hitbox=GoalModelResolver.GetHitboxForSide("Away"), Rectangle = GoalModelResolver.ResolveSide("Away", pitchCFrame, width, length)},
	}
	for _, goal in goals do
		disableGoalCollision(goal.Hitbox)
	end
	local volumeParent = ball:FindFirstAncestorWhichIsA("Folder") or ball.Parent
	for _, goal in goals do
		goal.Volume = createVolume(volumeParent, goal.Team, goal.Rectangle)
		goal.NetBackstop = createNetBackstop(volumeParent, goal.Team, goal.Rectangle)
		goal.WasInside=false
	end
	return setmetatable({Ball = ball, OnGoal = onGoal, Locked = false, Goals = goals, PreviousBallPosition = ball.Position, PreviousStepClock = os.clock(), PreviousBallVelocity = ball.AssemblyLinearVelocity}, Service)
end

function Service:_entryVelocity(previous: Vector3, current: Vector3, now: number): Vector3
	local currentVelocity = self.Ball.AssemblyLinearVelocity
	local previousVelocity = self.PreviousBallVelocity or Vector3.zero
	local dt = math.max(now - (self.PreviousStepClock or now), 1 / 240)
	local inferredVelocity = (current - previous) / dt
	local best = currentVelocity
	if previousVelocity.Magnitude > best.Magnitude then best = previousVelocity end
	if inferredVelocity.Magnitude > best.Magnitude then best = inferredVelocity end
	if best.Magnitude > 220 then best = best.Unit * 220 end
	return best
end

function Service:_denyNonShotGoal(goal: any, current: Vector3): boolean
	local kind = tostring(self.Ball:GetAttribute("VTRMotionKind") or "")
	if kind == "Shot" or kind == "Corner" or self.Ball:GetAttribute("VTRPenaltyShotActive") == true then
		return false
	end
	if kind == "Pass" or kind == "Clearance" or kind == "Dribble" then
		local safe = self.PreviousBallPosition
		if typeof(safe) ~= "Vector3" then safe = current end
		self.Ball.CFrame = CFrame.new(safe)
		self.Ball.AssemblyLinearVelocity = Vector3.zero
		self.Ball.AssemblyAngularVelocity = Vector3.zero
		self.Ball:SetAttribute("VTRDeniedNonShotGoalAt", os.clock())
		self.PreviousBallPosition = safe
		self.PreviousStepClock = os.clock()
		self.PreviousBallVelocity = Vector3.zero
		for _, item in self.Goals do item.WasInside = false end
		return true
	end
	return false
end

function Service:_recordGoalEntry(goal: any, previous: Vector3, current: Vector3, now: number)
	local entryVelocity = self:_entryVelocity(previous, current, now)
	local rectangle = goal.Rectangle
	local offset = current - rectangle.PlanePoint
	local horizontal = math.clamp(offset:Dot(rectangle.Right), rectangle.Left, rectangle.RightBound)
	local vertical = math.clamp(offset:Dot(rectangle.Up), rectangle.Bottom, rectangle.Top)
	local netEntryPosition = rectangle.PlanePoint + rectangle.Right * horizontal + rectangle.Up * vertical + rectangle.Normal * 1.2
	self.Ball:SetAttribute("VTRGoalEntryVelocity", entryVelocity)
	self.Ball:SetAttribute("VTRGoalEntryAngularVelocity", self.Ball.AssemblyAngularVelocity)
	self.Ball:SetAttribute("VTRGoalEntryPosition", netEntryPosition)
	self.Ball:SetAttribute("VTRGoalEntryNormal", rectangle.Normal)
	self.Ball.Anchored = false
	self.Locked = true
	self.PreviousBallPosition = current
	self.PreviousStepClock = now
	self.PreviousBallVelocity = self.Ball.AssemblyLinearVelocity
	self.OnGoal(goal.Team)
end

function Service:Step()
	if self.Locked then return end
	local now = os.clock()
	if self.Ball:GetAttribute("VTRGoalkeeperHeld")==true then
		self.PreviousBallPosition=self.Ball.Position
		self.PreviousStepClock=now
		self.PreviousBallVelocity=self.Ball.AssemblyLinearVelocity
		for _,goal in self.Goals do goal.WasInside=false end
		return
	end
	local previous = self.PreviousBallPosition
	local current = self.Ball.Position
	local radius = self.Ball.Size.X * 0.5
	for _, goal in self.Goals do
		if goal.Hitbox and goal.Hitbox.Parent then
			local localBall=goal.Hitbox.CFrame:PointToObjectSpace(current);local half=goal.Hitbox.Size*.5
			local inside=math.abs(localBall.X)<=math.max(.1,half.X-radius*.55)and math.abs(localBall.Y)<=math.max(.1,half.Y-radius*.55)and math.abs(localBall.Z)<=half.Z+radius
			if inside and not goal.WasInside then goal.WasInside=true;if self:_denyNonShotGoal(goal,current) then return end;self:_recordGoalEntry(goal, previous, current, now);return end
			goal.WasInside=inside
			continue
		end
		local rectangle = goal.Rectangle
		local previousDistance = (previous - rectangle.PlanePoint):Dot(rectangle.Normal)
		local currentDistance = (current - rectangle.PlanePoint):Dot(rectangle.Normal)
		if previousDistance < radius and currentDistance >= radius then
			local denominator = currentDistance - previousDistance
			local alpha = denominator > 0.0001 and math.clamp((radius - previousDistance) / denominator, 0, 1) or 1
			local crossing = previous:Lerp(current, alpha)
			local offset = crossing - rectangle.PlanePoint
			local horizontal = offset:Dot(rectangle.Right)
			local vertical = offset:Dot(rectangle.Up)
			local fullyInside = horizontal >= rectangle.Left + radius and horizontal <= rectangle.RightBound - radius and vertical >= rectangle.Bottom + radius * 0.72 and vertical <= rectangle.Top - radius
			if fullyInside then
				if self:_denyNonShotGoal(goal,crossing) then return end
				self:_recordGoalEntry(goal, previous, current, now)
				return
			end
		end
	end
	self.PreviousBallPosition = current
	self.PreviousStepClock = now
	self.PreviousBallVelocity = self.Ball.AssemblyLinearVelocity
end

function Service:Unlock()
	self.Locked = false
	for _,goal in self.Goals do goal.WasInside=false end
	self.PreviousBallPosition = self.Ball.Position
	self.PreviousStepClock = os.clock()
	self.PreviousBallVelocity = self.Ball.AssemblyLinearVelocity
	self.Ball:SetAttribute("VTRGoalEntryVelocity", nil)
	self.Ball:SetAttribute("VTRGoalEntryAngularVelocity", nil)
	self.Ball:SetAttribute("VTRGoalEntryPosition", nil)
	self.Ball:SetAttribute("VTRGoalEntryNormal", nil)
end

return Service
