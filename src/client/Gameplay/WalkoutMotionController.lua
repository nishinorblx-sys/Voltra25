--!strict

local RunService = game:GetService("RunService")

local CelebrationPoseController = require(script.Parent.CelebrationPoseController)

local Controller = {}
Controller.__index = Controller

local MOTOR_NAMES = { "RootJoint", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip", "Neck" }

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
	return setmetatable({ Model = model, Motors = motors(model), Connection = nil, Celebration = CelebrationPoseController.new() }, Controller)
end

function Controller:Walk(from: CFrame, to: CFrame, duration: number, style: string?, onComplete: (() -> ())?)
	self:StopWalk()
	local model = self.Model
	local root = model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
	if not model or not root or not root:IsA("BasePart") then
		if onComplete then task.defer(onComplete) end
		return
	end
	local started = os.clock()
	local power = style == "powerful" and 1.22 or style == "energetic" and 1.35 or style == "calm" and 0.78 or 1
	root.Anchored = true
	model:PivotTo(from)
	self.Connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then self:StopWalk();return end
		local alpha = math.clamp((os.clock() - started) / math.max(duration, 0.05), 0, 1)
		local eased = 1 - (1 - alpha) * (1 - alpha)
		local bob = math.sin(alpha * math.pi * 8) * 0.08 * power
		model:PivotTo(from:Lerp(to, eased) * CFrame.new(0, bob, 0))
		local wave = math.sin(alpha * math.pi * 8)
		for _, motor in self.Motors do
			if motor.Name == "Left Shoulder" then motor.Transform = CFrame.Angles(math.rad(18 * wave * power), 0, math.rad(-3))
			elseif motor.Name == "Right Shoulder" then motor.Transform = CFrame.Angles(math.rad(-18 * wave * power), 0, math.rad(3))
			elseif motor.Name == "Left Hip" then motor.Transform = CFrame.Angles(math.rad(-15 * wave * power), 0, 0)
			elseif motor.Name == "Right Hip" then motor.Transform = CFrame.Angles(math.rad(15 * wave * power), 0, 0)
			elseif motor.Name == "RootJoint" then motor.Transform = CFrame.new(0, bob * 0.25, 0) * CFrame.Angles(0, math.rad(2 * wave), 0)
			elseif motor.Name == "Neck" then motor.Transform = CFrame.Angles(math.rad(-bob * 2), 0, 0) end
		end
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
	for _, motor in self.Motors do
		if motor.Parent then motor.Transform = CFrame.identity end
	end
end

function Controller:Destroy()
	self:StopWalk()
	if self.Celebration then self.Celebration:Reset(self.Model) end
end

return Controller
