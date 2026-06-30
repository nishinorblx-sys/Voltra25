--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local AnimationConfig = require(ReplicatedStorage.VTR.Shared.AnimationConfig)
local NeededAnimationsReport = require(ReplicatedStorage.VTR.Shared.NeededAnimationsReport)

local Controller = {}
Controller.__index = Controller
Controller.AnimationIds = AnimationConfig

local MOVEMENT = {Idle = true, Walk = true, Jog = true, Sprint = true, Dribble = true, Jockey = true, GoalkeeperIdle = true, GoalkeeperMove = true, Turn = true}
local ACTION = {ReceiveBall = true, Receive = true, Pass = true, Shoot = true, Tackle = true, SlideTackle=true,DribbleMove1=true,DribbleMove4=true, Header = true, GoalkeeperDive = true, Celebrate = true, GoalCelebration = true}
local reportPrinted = false
local preloadedIds = {}

local function printReport()
	if reportPrinted then return end
	reportPrinted = true
	warn("[VTR NeededAnimationsReport] Additional animations recommended:")
	for index, item in NeededAnimationsReport do warn(string.format("  %02d. %s", index, item)) end
end

function Controller.new(model: Model)
	printReport()
	if model:GetAttribute("VTRServerAnimations") == true then
		return setmetatable({Animator=nil,Tracks={},Animations={},CurrentMovement=nil,CurrentAction=nil,ServerDriven=true},Controller)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if humanoid and not animator then
		animator = humanoid:WaitForChild("Animator", 2) :: Animator?
	end
	if humanoid and not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
		warn("[VTR ANIMATION] Server Animator was missing for " .. model.Name .. "; using client fallback")
	end
	local self = setmetatable({Animator = animator, Tracks = {}, Animations = {}, CurrentMovement = nil, CurrentAction = nil}, Controller)
	if animator then
		for name, id in AnimationConfig do
			local animation = Instance.new("Animation")
			animation.Name = "VTR_" .. name
			animation.AnimationId = id
			self.Animations[name] = animation
			if not preloadedIds[id] then
				preloadedIds[id] = true
				pcall(function() ContentProvider:PreloadAsync({animation}) end)
			end
			local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
			if ok and track then
				if ACTION[name] then track.Priority = Enum.AnimationPriority.Action elseif name == "Idle" or name == "GoalkeeperIdle" then track.Priority = Enum.AnimationPriority.Idle else track.Priority = Enum.AnimationPriority.Movement end
				track.Looped = MOVEMENT[name] == true
				self.Tracks[name] = track
			else
				warn(string.format("[VTR ANIMATION] Failed to load %s (%s) on %s: %s", name, id, model.Name, tostring(track)))
			end
		end
	else
		warn("[VTR ANIMATION] No Humanoid/Animator available for " .. model.Name)
	end
	return self
end

function Controller:Play(name: string)
	if self.ServerDriven then return end
	local track = self.Tracks[name]
	if not track then return end
	if MOVEMENT[name] then
		if self.CurrentMovement == track and track.IsPlaying then return end
		if self.CurrentMovement and self.CurrentMovement.IsPlaying then self.CurrentMovement:Stop(0.14) end
		self.CurrentMovement = track
		track:Play(0.14)
	elseif ACTION[name] then
		if self.CurrentAction and self.CurrentAction.IsPlaying and self.CurrentAction ~= track then self.CurrentAction:Stop(0.08) end
		self.CurrentAction = track
		if track.IsPlaying then track:Stop(0.03) end
		track:Play(0.08)
		track:AdjustSpeed(name=="Tackle"and 2 or 1)
	else
		track:Play(0.12)
	end
end

function Controller:Deactivate()
	if self.ServerDriven then return end
	if self.CurrentMovement and self.CurrentMovement.IsPlaying then self.CurrentMovement:Stop(0.12) end
	if self.CurrentAction and self.CurrentAction.IsPlaying then self.CurrentAction:Stop(0.08) end
	self.CurrentMovement = nil;self.CurrentAction = nil
end

function Controller:Destroy()
	for _, track in self.Tracks do track:Stop(0.1);track:Destroy() end
	for _, animation in self.Animations do animation:Destroy() end
	table.clear(self.Tracks)
	table.clear(self.Animations)
end

return Controller
