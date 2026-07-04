--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Replay = require(ReplicatedStorage.VTR.Shared.Replay)
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Controller = {}
Controller.__index = Controller

local REPLAY_SECONDS = 10
local BUFFER_SECONDS = 12
local POST_GOAL_RECORD_SECONDS = 1
local GOAL_REPLAY_COOLDOWN = 1.25
local SET_PIECE_REPLAY_GRACE = 0.25
local SHOT_PRE_ROLL = 2.25
local SHOT_POST_ROLL = 3.75
local SHOT_SLOW_WINDOW = 1
local SHOT_SLOW_SCALE = 0.34
local STATIC_PADDING = 90
local MAX_STATIC_PARTS = 1200
local SET_PIECE_KINDS = {
	FreeKick = true,
	Penalty = true,
	Corner = true,
	GoalKick = true,
	ThrowIn = true,
}

local function isDescendantOfAny(instance: Instance, containers: {Instance}): boolean
	for _, container in containers do
		if instance == container or instance:IsDescendantOf(container) then
			return true
		end
	end
	return false
end

local function collectTeamModels(teamModels: any): {Instance}
	local active: {Instance} = {}
	for _, sideModels in teamModels or {} do
		for _, model in sideModels do
			if typeof(model) == "Instance" and model:IsA("Model") then
				table.insert(active, model)
			end
		end
	end
	return active
end

local function addStaticPart(static: {Instance}, seen: {[Instance]: boolean}, part: BasePart, activeModels: {Instance}, ball: BasePart?)
	if seen[part] or part == ball or isDescendantOfAny(part, activeModels) then return end
	seen[part] = true
	table.insert(static, part)
end

local function isNearPitch(part: BasePart, pitchCFrame: CFrame?, width: number?, length: number?): boolean
	if not pitchCFrame or not width or not length then return false end
	local localPosition = pitchCFrame:PointToObjectSpace(part.Position)
	return math.abs(localPosition.X) <= width * 0.5 + STATIC_PADDING
		and math.abs(localPosition.Z) <= length * 0.5 + STATIC_PADDING
		and localPosition.Y >= -12
		and localPosition.Y <= 95
end

local function collectStaticParts(world: Instance?, activeModels: {Instance}, ball: BasePart?, pitchCFrame: CFrame?, width: number?, length: number?): {Instance}
	local static: {Instance} = {}
	local seen: {[Instance]: boolean} = {}
	if world then
		for _, descendant in world:GetDescendants() do
			if descendant:IsA("BasePart") then
				addStaticPart(static, seen, descendant, activeModels, ball)
			end
		end
	end
	for _, descendant in workspace:GetDescendants() do
		if #static >= MAX_STATIC_PARTS then break end
		if descendant:IsA("BasePart") and descendant.Transparency < 1 and isNearPitch(descendant, pitchCFrame, width, length) then
			addStaticPart(static, seen, descendant, activeModels, ball)
		end
	end
	return static
end

function Controller.new(data: any, ball: BasePart)
	local self: any = setmetatable({}, Controller)
	self.Player = Players.LocalPlayer
	self.Ball = ball
	self.World = workspace:FindFirstChild(tostring(data.WorldName or ""))
	self.ActiveModels = collectTeamModels(data.TeamModels)
	local ballContainer = ball.Parent and ball.Parent:IsA("Model") and ball.Parent or ball
	table.insert(self.ActiveModels, ballContainer)
	if workspace.CurrentCamera then
		table.insert(self.ActiveModels, workspace.CurrentCamera)
	end
	self.StaticModels = collectStaticParts(self.World, self.ActiveModels, ball, data.PitchCFrame, data.PitchWidth, data.PitchLength)
	self.LastGoalReplayAt = 0
	self:_startRecording()
	return self
end

function Controller:_startRecording()
	if self.Replay then
		self.Replay:Destroy()
	end
	self.Replay = Replay.New({
		FrameFrequency = 12,
		Rounding = 3,
		MaxReplayTime = BUFFER_SECONDS,
	}, self.ActiveModels, self.StaticModels)
	self.Replay:StartRecording()
end

function Controller:MarkSetPieceStarted(kind: string?)
	if not kind or not SET_PIECE_KINDS[kind] then return end
	local replay = self.Replay
	if not replay or not replay.Recording then return end
	self.LastSetPieceReplayTime = replay.ReplayTime
	self.LastSetPieceKind = kind
end

function Controller:MarkShot(actor: Model?)
	local replay = self.Replay
	if not replay or not replay.Recording then return end
	self.LastShotReplayTime = replay.ReplayTime
	self.LastShotActor = actor
end

local function rootPart(model: Model?): BasePart?
	if not model then return nil end
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Controller:_cloneFor(original: Instance?): Instance?
	if not original or not self.Replay then return nil end
	for index, source in self.Replay.ActiveParts do
		if source == original then
			return self.Replay.ActiveClones[index]
		end
	end
	return nil
end

function Controller:_makeReplayCamera(viewport: ViewportFrame): Camera
	local camera = Instance.new("Camera")
	camera.Name = "VTRCinematicReplayCamera"
	camera.FieldOfView = 52
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	self.ReplayCamera = camera
	return camera
end

function Controller:_updateShotReplayCamera(timeNow: number, shotTime: number)
	local viewport = self.Replay and self.Replay.ViewportFrame
	if not viewport then return end
	local camera = self.ReplayCamera or self:_makeReplayCamera(viewport)
	local shooterRoot = self:_cloneFor(rootPart(self.LastShotActor))
	local ballClone = self:_cloneFor(self.Ball)
	if not shooterRoot or not shooterRoot:IsA("BasePart") or not ballClone or not ballClone:IsA("BasePart") then return end
	local shooterPos = shooterRoot.Position
	local ballPos = ballClone.Position
	if not self.ReplayShotDirection then
		local fallbackLook = Vector3.new(shooterRoot.CFrame.LookVector.X, 0, shooterRoot.CFrame.LookVector.Z)
		local shotVector = Vector3.new(ballPos.X - shooterPos.X, 0, ballPos.Z - shooterPos.Z)
		self.ReplayShotDirection = shotVector.Magnitude > 0.08 and shotVector.Unit or (fallbackLook.Magnitude > 0.08 and fallbackLook.Unit or Vector3.zAxis)
		self.ReplayShotSide = Vector3.new(-self.ReplayShotDirection.Z, 0, self.ReplayShotDirection.X)
		if self.ReplayShotSide.Magnitude < .05 then self.ReplayShotSide = Vector3.xAxis else self.ReplayShotSide = self.ReplayShotSide.Unit end
		self.ReplayCameraPosition = nil
		self.ReplayCameraTarget = nil
		self.ReplayCameraLastTime = nil
	end
	local shotDir = self.ReplayShotDirection
	local sideDir = self.ReplayShotSide
	local up = Vector3.yAxis
	local setupStart = shotTime - 1.85
	local strikeMoment = shotTime + 0.05
	local desiredPosition: Vector3
	local desiredTarget: Vector3
	local desiredFov: number
	if timeNow <= strikeMoment then
		local alpha = math.clamp((timeNow - setupStart) / math.max(0.01, strikeMoment - setupStart), 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		desiredTarget = shooterPos:Lerp(ballPos, 0.38) + up * (5.4 + eased * 1.2)
		desiredPosition = desiredTarget - shotDir * (76 - eased * 8) + sideDir * (-12 + eased * 16) + up * (29 + eased * 2)
		desiredFov = 53 - eased * 2
	else
		local alpha = math.clamp((timeNow - shotTime) / 3.0, 0, 1)
		local eased = 1 - (1 - alpha) * (1 - alpha)
		desiredTarget = shooterPos:Lerp(ballPos, 0.50 + eased * 0.20) + up * (5.8 + eased * 1.6)
		desiredPosition = shooterPos - shotDir * (72 - eased * 8) + sideDir * 8 + up * (32 + eased * 2)
		desiredFov = 51 + eased * 2
	end
	local dt = math.clamp(timeNow - (self.ReplayCameraLastTime or timeNow), 0, 0.08)
	self.ReplayCameraLastTime = timeNow
	local blend = 1 - math.exp(-dt * 8)
	if not self.ReplayCameraPosition then
		self.ReplayCameraPosition = desiredPosition
		self.ReplayCameraTarget = desiredTarget
	else
		self.ReplayCameraPosition = self.ReplayCameraPosition:Lerp(desiredPosition, blend)
		self.ReplayCameraTarget = self.ReplayCameraTarget:Lerp(desiredTarget, blend)
	end
	camera.FieldOfView = desiredFov
	camera.CFrame = CFrame.lookAt(self.ReplayCameraPosition, self.ReplayCameraTarget)
	viewport.CurrentCamera = camera
end

function Controller:_startCinematicReplay(replay: any, startTime: number, endTime: number, shotTime: number, finish: () -> ())
	if replay.Playing or replay.Recording or replay.ReplayFrameCount <= 0 then return end
	if not replay.ReplayVisible then replay:ShowReplay(true) end
	replay.Playing = true
	replay.CustomEvents.ReplayStarted:Fire()
	self.ReplayShotDirection=nil
	self.ReplayShotSide=nil
	self.ReplayCameraPosition=nil
	self.ReplayCameraTarget=nil
	self.ReplayCameraLastTime=nil
	local currentTime = startTime
	local connection: RBXScriptConnection?
	connection = RunService.RenderStepped:Connect(function(dt)
		local distanceFromShot = math.abs(currentTime - shotTime)
		local scale = distanceFromShot <= SHOT_SLOW_WINDOW and SHOT_SLOW_SCALE or 1
		currentTime += dt * scale
		if currentTime < endTime then
			replay:GoToTime(currentTime, true)
			self:_updateShotReplayCamera(currentTime, shotTime)
		else
			replay:GoToTime(endTime, true)
			self:_updateShotReplayCamera(endTime, shotTime)
			if connection then connection:Disconnect() end
			replay.Playing = false
			replay.CustomEvents.ReplayEnded:Fire()
			finish()
		end
	end)
	table.insert(replay.Connections, connection)
end

function Controller:_makeOverlay()
	local old = self.Player.PlayerGui:FindFirstChild("VTRInstantReplay")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRInstantReplay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 95
	gui.Parent = self.Player.PlayerGui

	local shade = Instance.new("Frame")
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0.08
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(28, 24)
	label.Size = UDim2.fromOffset(280, 34)
	label.Font = Enum.Font.GothamBlack
	label.Text = "INSTANT REPLAY"
	label.TextColor3 = Color3.fromRGB(183, 255, 26)
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = gui

	self.Overlay = gui
	return gui
end

function Controller:_addSkipButton(gui: ScreenGui, requestSkip: () -> ()): RBXScriptConnection
	local button = Instance.new("TextButton")
	button.Name = "SkipReplayButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.BackgroundColor3 = Color3.fromRGB(13, 18, 16)
	button.BackgroundTransparency = 0.04
	button.BorderSizePixel = 0
	button.Position = UDim2.new(1, -28, 1, -28)
	button.Size = UDim2.fromOffset(176, 44)
	button.AutoButtonColor = true
	button.Font = Theme.Fonts.Display
	button.Text = "SKIP REPLAY"
	button.TextColor3 = Theme.Colors.White
	button.TextSize = 14
	button.TextStrokeTransparency = 1
	button.ZIndex = 120
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Electric
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = button

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.new(1, -30, 1, -78)
	hint.Size = UDim2.fromOffset(250, 24)
	hint.Font = Theme.Fonts.Strong
	hint.Text = "A / TAP"
	hint.TextColor3 = Theme.Colors.Electric
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.TextStrokeTransparency = 1
	hint.ZIndex = 120
	hint.Parent = gui

	return button.Activated:Connect(requestSkip)
end

function Controller:_playSkipTransition(done: () -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRReplaySkipTransition"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 110
	gui.Parent = self.Player.PlayerGui
	local overlay = Instance.new("CanvasGroup")
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 110
	overlay.Parent = gui
	local slash = Instance.new("Frame")
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.BackgroundColor3 = Theme.Colors.Black
	slash.BackgroundTransparency = 1
	slash.BorderSizePixel = 0
	slash.Position = UDim2.fromScale(-0.25, 0.5)
	slash.Rotation = -16
	slash.Size = UDim2.fromScale(0.55, 1.7)
	slash.ZIndex = 111
	slash.Parent = overlay
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(700, 80)
	label.Text = "GOAL"
	label.TextColor3 = Theme.Colors.White
	label.TextSize = 34
	label.Font = Theme.Fonts.Display
	label.ZIndex = 112
	label.Parent = overlay
	TweenService:Create(overlay, TweenInfo.new(0.16), {GroupTransparency = 0}):Play()
	TweenService:Create(slash, TweenInfo.new(0.36, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), {Position = UDim2.fromScale(1.22, 0.5)}):Play()
	task.delay(0.18, done)
	task.delay(0.42, function()
		if not overlay.Parent then return end
		TweenService:Create(overlay, TweenInfo.new(0.16), {GroupTransparency = 1}):Play()
		task.delay(0.17, function()
			if gui.Parent then gui:Destroy() end
		end)
	end)
end

function Controller:PlayGoalReplay(onFinished: (() -> ())?)
	local replay = self.Replay
	if not replay or replay.Playing or not replay.Recording or replay.ReplayFrameCount < 2 then
		if onFinished then onFinished() end
		return false
	end
	local now = os.clock()
	if now - self.LastGoalReplayAt < GOAL_REPLAY_COOLDOWN then
		if onFinished then onFinished() end
		return false
	end
	self.LastGoalReplayAt = now

	task.delay(POST_GOAL_RECORD_SECONDS, function()
		if self.Destroyed or self.Replay ~= replay or not replay.Recording then
			if onFinished then onFinished() end
			return
		end
		replay:StopRecording()
		local finalTime = replay.Frames[replay.ReplayFrameCount].Time
		local shotTime = tonumber(self.LastShotReplayTime)
		local hasShotCinematic = shotTime ~= nil and shotTime >= replay.Frames[1].Time and shotTime <= finalTime and finalTime - (shotTime :: number) <= SHOT_PRE_ROLL + SHOT_POST_ROLL + 1.25
		local startTime = hasShotCinematic and math.max(replay.Frames[1].Time, (shotTime :: number) - SHOT_PRE_ROLL) or math.max(replay.Frames[1].Time, finalTime - REPLAY_SECONDS)
		local endTime = hasShotCinematic and math.min(finalTime, (shotTime :: number) + SHOT_POST_ROLL) or finalTime
		local setPieceStart = tonumber(self.LastSetPieceReplayTime)
		if setPieceStart and finalTime - setPieceStart <= REPLAY_SECONDS + POST_GOAL_RECORD_SECONDS + SET_PIECE_REPLAY_GRACE then
			startTime = math.max(replay.Frames[1].Time, math.min(startTime, setPieceStart))
		end
		local gui = self:_makeOverlay()
		replay:CreateViewport(gui)
		replay:ShowReplay(true)
		replay:GoToTime(startTime, true)

		local finished = false
		local skipped = false
		local endedConnection: RBXScriptConnection?
		local skipConnection: RBXScriptConnection?
		local skipButtonConnection: RBXScriptConnection?
		local function requestSkip()
			if finished or skipped or not replay.Playing then return end
			skipped = true
			replay:StopReplay()
		end
		local function finish()
			if finished then return end
			finished = true
			if endedConnection then endedConnection:Disconnect() end
			if skipConnection then skipConnection:Disconnect() end
			if skipButtonConnection then skipButtonConnection:Disconnect() end
			replay:HideReplay()
			if self.Overlay then
				self.Overlay:Destroy()
				self.Overlay = nil
			end
			if not self.Destroyed then
				self:_startRecording()
			end
			if onFinished then
				if skipped and not self.Destroyed then
					self:_playSkipTransition(onFinished)
				else
					onFinished()
				end
			end
		end
		endedConnection = replay.ReplayEnded:Connect(finish)
		skipButtonConnection = self:_addSkipButton(gui, requestSkip)
		skipConnection = UserInputService.InputBegan:Connect(function(input, processed)
			local tap = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
			local controllerSkip = input.KeyCode == Enum.KeyCode.ButtonA
			local keyboardSkip = input.KeyCode == Enum.KeyCode.Space
			if processed and not (tap or controllerSkip) then return end
			if tap or controllerSkip or keyboardSkip then
				requestSkip()
			end
		end)
		if hasShotCinematic then
			self:_startCinematicReplay(replay,startTime,endTime,shotTime :: number,finish)
		else
			replay:StartReplay(1)
		end
	end)
	return true
end

function Controller:PlayShotReplay()
	self:PlayGoalReplay()
end

function Controller:Destroy()
	self.Destroyed = true
	if self.Replay then
		self.Replay:Destroy()
		self.Replay = nil
	end
	if self.Overlay then
		self.Overlay:Destroy()
		self.Overlay = nil
	end
end

return Controller
