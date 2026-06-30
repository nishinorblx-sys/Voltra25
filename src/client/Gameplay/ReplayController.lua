--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
		FrameFrequency = 2,
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
	slash.BackgroundColor3 = Theme.Colors.Electric
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
		local startTime = math.max(replay.Frames[1].Time, finalTime - REPLAY_SECONDS)
		local setPieceStart = tonumber(self.LastSetPieceReplayTime)
		if setPieceStart and finalTime - setPieceStart <= REPLAY_SECONDS + POST_GOAL_RECORD_SECONDS + SET_PIECE_REPLAY_GRACE then
			startTime = math.max(startTime, setPieceStart)
		end
		local gui = self:_makeOverlay()
		replay:CreateViewport(gui)
		replay:ShowReplay(true)
		replay:GoToTime(startTime, true)

		local finished = false
		local skipped = false
		local endedConnection: RBXScriptConnection?
		local skipConnection: RBXScriptConnection?
		local function finish()
			if finished then return end
			finished = true
			if endedConnection then endedConnection:Disconnect() end
			if skipConnection then skipConnection:Disconnect() end
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
		skipConnection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.KeyCode == Enum.KeyCode.Space and replay.Playing then
				skipped = true
				replay:StopReplay()
			end
		end)
		replay:StartReplay(1)
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
