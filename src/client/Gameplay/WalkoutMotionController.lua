--!strict

local RunService = game:GetService("RunService")

local CelebrationPoseController = require(script.Parent.CelebrationPoseController)

local Controller = {}
Controller.__index = Controller

local MOTOR_NAMES = { "RootJoint", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip", "Neck" }
local WALKOUT_ANIMATION_ID = "rbxassetid://84979937639755"

local function motors(model: Model): {Motor6D}
	local result = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and table.find(MOTOR_NAMES, descendant.Name) then
			table.insert(result, descendant)
		end
	end
	return result
end

function Controller.new(model: Model)
	return setmetatable({ Model = model, Motors = motors(model), Connection = nil, WalkTrack = nil, Celebration = CelebrationPoseController.new() }, Controller)
end

function Controller:_playWalkAnimation(): boolean
	local model = self.Model
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = WALKOUT_ANIMATION_ID
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok or not track then return false end
	self.WalkTrack = track
	track.Priority = Enum.AnimationPriority.Movement
	track.Looped = true
	track:Play(0.12, 1, 1)
	return true
end

function Controller:Walk(from: CFrame, to: CFrame, duration: number, style: string?, onStep: ((number, CFrame) -> ())?, onComplete: (() -> ())?)
	self:StopWalk()
	local model = self.Model
	local root = model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
	if not model or not root or not root:IsA("BasePart") then
		if onComplete then task.defer(onComplete) end
		return
	end
	local started = os.clock()
	local power = style == "powerful" and 1.22 or style == "energetic" and 1.35 or style == "calm" and 0.78 or 1
	local stride = 9
	local animatedWalk = self:_playWalkAnimation()
	root.Anchored = true
	model:PivotTo(from)
	self.Connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then self:StopWalk();return end
		local alpha = math.clamp((os.clock() - started) / math.max(duration, 0.05), 0, 1)
		local eased = 1 - (1 - alpha) * (1 - alpha)
		local wave = math.sin(alpha * math.pi * stride)
		local counter = math.cos(alpha * math.pi * stride)
		local bob = math.max(0, math.sin(alpha * math.pi * stride * 2)) * 0.06 * power
		local pivot = from:Lerp(to, eased) * CFrame.new(0, bob, 0)
		model:PivotTo(pivot)
		if not animatedWalk then
			for _, motor in self.Motors do
				if motor.Name == "Left Shoulder" then motor.Transform = CFrame.Angles(math.rad(24 * wave * power), 0, math.rad(-5 - 2 * counter))
				elseif motor.Name == "Right Shoulder" then motor.Transform = CFrame.Angles(math.rad(-24 * wave * power), 0, math.rad(5 + 2 * counter))
				elseif motor.Name == "Left Hip" then motor.Transform = CFrame.Angles(math.rad(-23 * wave * power), 0, math.rad(2 * counter))
				elseif motor.Name == "Right Hip" then motor.Transform = CFrame.Angles(math.rad(23 * wave * power), 0, math.rad(-2 * counter))
				elseif motor.Name == "RootJoint" then motor.Transform = CFrame.new(0, bob * 0.18, 0) * CFrame.Angles(math.rad(2.5), math.rad(3.8 * wave), math.rad(1.5 * counter))
				elseif motor.Name == "Neck" then motor.Transform = CFrame.Angles(math.rad(-2.5), math.rad(-1.4 * wave), 0) end
			end
		end
		if onStep then onStep(alpha, pivot) end
		if alpha >= 1 then
			self:StopWalk()
			model:PivotTo(to)
			if onComplete then onComplete() end
		end
	end)
end

function Controller:Celebrate(style: string?, duration: number?)
	if not self.Model or not self.Model.Parent then return end
	local celebration = style or tostring(self.Model:GetAttribute("CelebrationStyle") or "FistPump")
	self.Celebration:Play(self.Model, celebration, nil, { AnchorRoot = true, MinDuration = duration or 0.7 })
end

function Controller:StopWalk()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	if self.WalkTrack then
		pcall(function() self.WalkTrack:Stop(0.12) end)
		pcall(function() self.WalkTrack:Destroy() end)
		self.WalkTrack = nil
	end
	for _, motor in self.Motors do
		if motor.Parent then motor.Transform = CFrame.identity end
	end
end

function Controller:Destroy()
	self:StopWalk()
	if self.Celebration then self.Celebration:Reset(self.Model) end
end

return Controller
