--!strict
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CelebrationPoseConfig = require(ReplicatedStorage.VTR.Shared.CelebrationPoseConfig)

local Controller = {}
Controller.__index = Controller

local MOTOR_KEYS = {
	RootJoint = "RootJoint",
	Neck = "Neck",
	RightShoulder = "Right Shoulder",
	LeftShoulder = "Left Shoulder",
	RightHip = "Right Hip",
	LeftHip = "Left Hip",
}

local RESET_TIME = 0.28

local function findMotor(model: Model, motorName: string): Motor6D?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name == motorName then
			return descendant
		end
	end
	return nil
end

local function collectMotors(model: Model): {[string]: Motor6D}
	local motors = {}
	for key, motorName in MOTOR_KEYS do
		local motor = findMotor(model, motorName)
		if motor then
			motors[key] = motor
		end
	end
	return motors
end

local function tweenMotor(motor: Motor6D, duration: number, target: CFrame)
	local tween = TweenService:Create(
		motor,
		TweenInfo.new(math.max(0.01, duration), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Transform = target }
	)
	tween:Play()
	return tween
end

local function rootTarget(base: CFrame, frame: {[string]: any}): CFrame
	local yaw = math.rad(tonumber(frame.RootYaw) or 0)
	local pitch = math.rad(tonumber(frame.RootPitch) or 0)
	local yOffset = tonumber(frame.RootYOffset) or 0
	local xOffset = tonumber(frame.RootXOffset) or 0
	return base * CFrame.new(xOffset, yOffset, 0) * CFrame.Angles(pitch, yaw, 0)
end

local function pauseAnimatorTracks(model: Model): {AnimationTrack}
	local paused = {}
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return paused end
	for _, track in animator:GetPlayingAnimationTracks() do
		table.insert(paused, track)
		track:AdjustWeight(0, 0)
		track:AdjustSpeed(0)
		track:Stop(0)
	end
	return paused
end

local function suppressAnimatorTracks(model: Model): RBXScriptConnection?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	return RunService.RenderStepped:Connect(function()
		if not model.Parent or not animator.Parent then return end
		for _, track in animator:GetPlayingAnimationTracks() do
			track:AdjustWeight(0, 0)
			track:AdjustSpeed(0)
			track:Stop(0)
		end
	end)
end

local function resumeAnimatorTracks(tracks: {AnimationTrack})
	for _, track in tracks do
		if track.IsPlaying then
			track:AdjustSpeed(1)
			track:AdjustWeight(1, 0.16)
		end
	end
end

local function freezeRootForCelebration(root: BasePart?): (() -> ())?
	if not root or not root.Parent then return nil end
	local wasAnchored = root.Anchored
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	return function()
		if not root.Parent then return end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = wasAnchored
	end
end

function Controller.new()
	return setmetatable({ Token = 0 }, Controller)
end

function Controller:Reset(model: Model?)
	self.Token += 1
	if not model then return end
	for _, motor in collectMotors(model) do
		motor.Transform = CFrame.new()
	end
end

function Controller:Play(model: Model?, celebrationId: string?, onComplete: (() -> ())?, options: any?): number
	if not model or not model.Parent then
		if onComplete then task.defer(onComplete) end
		return 0
	end

	self.Token += 1
	local token = self.Token
	local celebration = CelebrationPoseConfig.Resolve(celebrationId)
	local keyframes = celebration and celebration.Keyframes
	if type(keyframes) ~= "table" or #keyframes == 0 then
		if onComplete then task.defer(onComplete) end
		return 0
	end

	local motors = collectMotors(model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootBase = root and root.CFrame or nil
	local duration = tonumber(celebration.Duration) or tonumber(keyframes[#keyframes].Time) or 1.2
	local minimumDuration = math.max(duration, tonumber(options and options.MinDuration) or 0)
	local forceLoop = options and options.ForceLoop == true
	local pausedTracks = pauseAnimatorTracks(model)
	local suppressConnection = suppressAnimatorTracks(model)
	local releaseRoot = options and options.AnchorRoot == true and freezeRootForCelebration(root) or nil
	model:SetAttribute("VTRCelebratingLocal", true)
	local cleaned = false
	local function cleanup()
		if cleaned then return end
		cleaned = true
		if suppressConnection then suppressConnection:Disconnect() end
		if releaseRoot then releaseRoot();releaseRoot=nil end
		if model.Parent then model:SetAttribute("VTRCelebratingLocal", nil) end
		resumeAnimatorTracks(pausedTracks)
	end

	task.spawn(function()
		for _, motor in motors do
			motor.Transform = CFrame.new()
		end

		local started = os.clock()
		repeat
			local previousTime = 0
			for index, frame in keyframes do
				if token ~= self.Token or not model.Parent then
					cleanup()
					return
				end
				local frameTime = tonumber(frame.Time) or previousTime
				local segment = index == 1 and 0.01 or math.max(0.01, frameTime - previousTime)
				previousTime = frameTime
				if minimumDuration > 0 then
					local remaining = minimumDuration - (os.clock() - started)
					if remaining <= 0 then
						break
					end
					segment = math.min(segment, math.max(0.01, remaining))
				end

				for key, motor in motors do
					local target = frame[key]
					if typeof(target) == "CFrame" then
						tweenMotor(motor, segment, target)
					end
				end

				if root and rootBase and root.Parent and (frame.RootYaw ~= nil or frame.RootPitch ~= nil or frame.RootYOffset ~= nil or frame.RootXOffset ~= nil) then
					local targetCFrame = rootTarget(rootBase, frame)
					TweenService:Create(
						root,
						TweenInfo.new(segment, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ CFrame = targetCFrame }
					):Play()
				end

				task.wait(segment)
			end
		until token ~= self.Token or not model.Parent or not forceLoop or os.clock() - started >= minimumDuration

		if token ~= self.Token or not model.Parent then
			cleanup()
			return
		end
		for _, motor in motors do
			tweenMotor(motor, RESET_TIME, CFrame.new())
		end
		if root and rootBase and root.Parent then
			TweenService:Create(
				root,
				TweenInfo.new(RESET_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ CFrame = rootBase }
			):Play()
		end
		task.wait(RESET_TIME)
		if token ~= self.Token or not model.Parent then
			cleanup()
			return
		end
		for _, motor in motors do
			motor.Transform = CFrame.new()
		end
		cleanup()
		if onComplete then onComplete() end
	end)

	return math.max(duration, minimumDuration) + RESET_TIME
end

local function attackSignFor(team: string?, half: number): number
	local homeSign = half == 2 and 1 or -1
	return team == "Away" and -homeSign or homeSign
end

function Controller:PlayGoalPresentation(model: Model?, celebrationId: string?, options: any?, onComplete: (() -> ())?): number
	if not model or not model.Parent then
		if onComplete then task.defer(onComplete) end
		return 0
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return self:Play(model, celebrationId, onComplete)
	end

	self.Token += 1
	local token = self.Token
	local pitchCFrame = options and options.PitchCFrame or CFrame.new()
	local width = tonumber(options and options.Width) or 76
	local length = tonumber(options and options.Length) or 742
	local team = tostring(options and options.Team or model:GetAttribute("VTRTeam") or "Home")
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local sign = attackSignFor(team, half)
	local rootLocal = pitchCFrame:PointToObjectSpace(root.Position)
	local cornerX = rootLocal.X >= 0 and width * 0.46 or -width * 0.46
	local cornerLocal = Vector3.new(cornerX, math.max(3, rootLocal.Y), sign * length * 0.46)
	local cornerWorld = pitchCFrame:PointToWorldSpace(cornerLocal)
	local xSide = cornerLocal.X >= 0 and 1 or -1
	local zSide = cornerLocal.Z >= 0 and 1 or -1
	local cameraWorld = cornerWorld + pitchCFrame.RightVector * (xSide * 20) - pitchCFrame.LookVector * (zSide * 26) + pitchCFrame.UpVector * 7.5
	local lookWorld = cornerWorld + pitchCFrame.UpVector * 3.2
	local flatCamera = Vector3.new(cameraWorld.X, cornerWorld.Y, cameraWorld.Z)
	local runTarget = CFrame.lookAt(cornerWorld, flatCamera)
	local panTime = 0.55
	local celebrationSeconds = 5
	model:SetAttribute("VTRCelebratingLocal", true)
	if options and options.CameraController and options.CameraController.BeginGoalCelebration then
		options.CameraController:BeginGoalCelebration(cornerWorld, lookWorld, panTime + celebrationSeconds + RESET_TIME + 0.25)
	end

	task.spawn(function()
		root.CFrame = runTarget

		local started = os.clock()
		while os.clock() - started < panTime do
			if token ~= self.Token or not model.Parent then
				if model.Parent then model:SetAttribute("VTRCelebratingLocal", nil) end
				return
			end
			task.wait()
		end
		if token ~= self.Token or not model.Parent then
			if model.Parent then model:SetAttribute("VTRCelebratingLocal", nil) end
			return
		end
		self:Play(model, celebrationId, function()
			if onComplete then task.delay(0.05, onComplete) end
		end, {MinDuration = celebrationSeconds, ForceLoop = true, AnchorRoot = true})
	end)

	return panTime + celebrationSeconds + RESET_TIME
end

return Controller
