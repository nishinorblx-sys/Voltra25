--!nonstrict
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Replay = {}
Replay.__index = Replay

local DEFAULTS = {
	FrameFrequency = 2,
	ReplayLocation = workspace,
	Rounding = 3,
	MaxReplayTime = math.huge,
}

local function round(value: number, digits: number): number
	local factor = 10 ^ digits
	return math.round(value * factor) / factor
end

local function roundCFrame(value: CFrame, digits: number): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
	return CFrame.new(
		round(x, digits), round(y, digits), round(z, digits),
		round(r00, digits), round(r01, digits), round(r02, digits),
		round(r10, digits), round(r11, digits), round(r12, digits),
		round(r20, digits), round(r21, digits), round(r22, digits)
	)
end

local function roundColor(value: Color3, digits: number): Color3
	return Color3.new(round(value.R, digits), round(value.G, digits), round(value.B, digits))
end

local function normalize(settings: {[string]: any}?): {[string]: any}
	local result = table.clone(DEFAULTS)
	for key, value in settings or {} do
		result[key] = value
	end
	return result
end

local function ghost(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.Massless = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
		instance.LocalTransparencyModifier = 0
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.LocalTransparencyModifier = 0
		end
	end
end

local function stateOf(instance: Instance, rounding: number): {[string]: any}
	if instance:IsA("BasePart") then
		return {
			CFrame = roundCFrame(instance.CFrame, rounding),
			Color = roundColor(instance.Color, rounding),
			Transparency = round(instance.Transparency, rounding),
			NotDestroyed = instance:IsDescendantOf(game),
		}
	elseif instance:IsA("Camera") then
		return {
			CFrame = roundCFrame(instance.CFrame, rounding),
			FieldOfView = round(instance.FieldOfView, rounding),
			NotDestroyed = instance:IsDescendantOf(game),
		}
	end
	return {NotDestroyed = instance:IsDescendantOf(game)}
end

local function collectRecordable(instance: Instance, ignored: {Instance}, output: {Instance})
	if table.find(ignored, instance) then return end
	if instance:IsA("BasePart") or instance:IsA("Camera") then
		table.insert(output, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if not table.find(ignored, descendant) and (descendant:IsA("BasePart") or descendant:IsA("Camera")) then
			table.insert(output, descendant)
		end
	end
end

local function formatTime(time: number): string
	local minutes = math.floor(time / 60)
	local seconds = math.floor(time - minutes * 60)
	return tostring(minutes) .. ":" .. (seconds < 10 and "0" or "") .. tostring(seconds)
end

function Replay.New(settings: {[string]: any}?, activeModels: {Instance}, staticModels: {Instance}?, ignoredModels: {Instance}?)
	local self = setmetatable({}, Replay)
	self.Settings = normalize(settings)
	self.ActiveModels = activeModels or {}
	self.StaticModels = staticModels or {}
	self.IgnoredModels = ignoredModels or {}
	self.Frames = {}
	self.ActiveParts = {}
	self.ActiveClones = {}
	self.StaticClones = {}
	self.Connections = {}
	self.ViewportFrameConnections = {}
	self.CustomEvents = {}
	for _, name in {"RecordingStarted", "RecordingEnded", "ReplayShown", "ReplayHidden", "ReplayStarted", "ReplayEnded", "ReplayFrameChanged"} do
		local event = Instance.new("BindableEvent")
		self.CustomEvents[name] = event
		self[name] = event.Event
	end
	self.Recording = false
	self.Playing = false
	self.ReplayVisible = false
	self.ReplayTime = 0
	self.ReplayFrame = 0
	self.ReplayT = 0
	self.ReplayFrameCount = 0
	return self
end

function Replay:_disconnectRecording()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

function Replay:_snapshot(time: number)
	local frame = {Time = round(time, self.Settings.Rounding), States = {}}
	for index, instance in self.ActiveParts do
		frame.States[index] = stateOf(instance, self.Settings.Rounding)
	end
	table.insert(self.Frames, frame)
	self.ReplayFrameCount = #self.Frames
	self.ReplayTime = frame.Time
	local maxTime = self.Settings.MaxReplayTime
	while maxTime < math.huge and #self.Frames > 2 and frame.Time - self.Frames[1].Time > maxTime do
		table.remove(self.Frames, 1)
	end
	self.ReplayFrameCount = #self.Frames
end

function Replay:StartRecording()
	if self.Recording or self.Playing then return end
	self:Clear()
	self.Recording = true
	self.ActiveParts = {}
	for _, instance in self.ActiveModels do
		if instance and instance.Parent then
			collectRecordable(instance, self.IgnoredModels, self.ActiveParts)
		end
	end
	self.ActiveClones = {}
	for index, instance in self.ActiveParts do
		instance.Archivable = true
		local clone = instance:Clone()
		clone.Name = instance.Name .. "_Replay"
		ghost(clone)
		self.ActiveClones[index] = clone
	end
	self.StaticClones = {}
	for _, instance in self.StaticModels do
		if instance and instance.Parent then
			instance.Archivable = true
			local clone = instance:Clone()
			ghost(clone)
			table.insert(self.StaticClones, clone)
		end
	end
	local started = os.clock()
	local counter = self.Settings.FrameFrequency
	self:_snapshot(0)
	table.insert(self.Connections, RunService.RenderStepped:Connect(function()
		counter -= 1
		if counter > 0 then return end
		counter = self.Settings.FrameFrequency
		self:_snapshot(os.clock() - started)
	end))
	self.CustomEvents.RecordingStarted:Fire()
end

function Replay:StopRecording()
	if not self.Recording then return end
	self:_disconnectRecording()
	self.Recording = false
	self.ReplayFrame = 1
	self.CustomEvents.RecordingEnded:Fire()
end

function Replay:UpdateReplayLocation(location: Instance?)
	if location then
		self.Settings.ReplayLocation = location
	end
	if self.ReplayVisible then
		self:ShowReplay(true)
	end
end

function Replay:ShowReplay(override: boolean?)
	if not override and (self.Recording or self.ReplayVisible) then return end
	for _, clone in self.StaticClones do
		clone.Parent = self.Settings.ReplayLocation
	end
	for _, clone in self.ActiveClones do
		clone.Parent = self.Settings.ReplayLocation
	end
	self.ReplayVisible = true
	self.CustomEvents.ReplayShown:Fire()
end

function Replay:HideReplay()
	if self.Playing or not self.ReplayVisible then return end
	for _, clone in self.StaticClones do
		clone.Parent = nil
	end
	for _, clone in self.ActiveClones do
		clone.Parent = nil
	end
	self.ReplayVisible = false
	self.CustomEvents.ReplayHidden:Fire()
end

function Replay:GoToFrame(frame: number, t: number, override: boolean?)
	if not override and (self.Recording or not self.ReplayVisible) then return end
	frame = math.clamp(frame, 1, math.max(1, self.ReplayFrameCount))
	local current = self.Frames[frame]
	local nextFrame = self.Frames[math.min(frame + 1, self.ReplayFrameCount)]
	if not current then return end
	for index, clone in self.ActiveClones do
		local state = current.States[index]
		local nextState = nextFrame and nextFrame.States[index]
		if not state then continue end
		if state.NotDestroyed == false then
			clone.Parent = nil
			continue
		elseif not clone.Parent then
			clone.Parent = self.Settings.ReplayLocation
		end
		if clone:IsA("BasePart") then
			local cframe = state.CFrame
			local transparency = state.Transparency
			local color = state.Color
			if nextState and t > 0 then
				if nextState.CFrame then cframe = cframe:Lerp(nextState.CFrame, t) end
				if nextState.Transparency then transparency = transparency + (nextState.Transparency - transparency) * t end
				if nextState.Color then color = color:Lerp(nextState.Color, t) end
			end
			clone.CFrame = cframe
			clone.Transparency = transparency
			clone.Color = color
		elseif clone:IsA("Camera") then
			local cframe = state.CFrame
			local fov = state.FieldOfView
			if nextState and t > 0 then
				if nextState.CFrame then cframe = cframe:Lerp(nextState.CFrame, t) end
				if nextState.FieldOfView then fov = fov + (nextState.FieldOfView - fov) * t end
			end
			clone.CFrame = cframe
			clone.FieldOfView = fov
			if self.ViewportFrame then
				self.ViewportFrame.CurrentCamera = clone
			end
		end
	end
	local nextTime = nextFrame and nextFrame.Time or current.Time
	self.ReplayTime = current.Time + (nextTime - current.Time) * t
	self.ReplayFrame = frame
	self.ReplayT = t
	self.CustomEvents.ReplayFrameChanged:Fire()
end

function Replay:GoToTime(time: number, override: boolean?)
	if self.ReplayFrameCount <= 0 then return end
	local firstTime = self.Frames[1].Time
	local lastTime = self.Frames[self.ReplayFrameCount].Time
	time = math.clamp(time, firstTime, lastTime)
	local frame = 1
	for index = 1, self.ReplayFrameCount do
		if self.Frames[index].Time <= time then
			frame = index
		else
			break
		end
	end
	local nextFrame = self.Frames[math.min(frame + 1, self.ReplayFrameCount)]
	local current = self.Frames[frame]
	local gap = nextFrame.Time - current.Time
	local t = gap > 0 and math.clamp((time - current.Time) / gap, 0, 1) or 0
	self:GoToFrame(frame, t, override)
end

function Replay:StartReplay(timescale: number)
	if self.Playing or self.Recording or self.ReplayFrameCount <= 0 then return end
	if not self.ReplayVisible then self:ShowReplay(true) end
	self.Playing = true
	self.CustomEvents.ReplayStarted:Fire()
	local currentTime = self.ReplayTime
	local endTime = self.Frames[self.ReplayFrameCount].Time
	self.Connections[1] = RunService.RenderStepped:Connect(function(dt)
		currentTime += dt * (timescale or 1)
		if currentTime < endTime then
			self:GoToTime(currentTime, true)
		else
			self:GoToTime(endTime, true)
			self:StopReplay()
		end
	end)
end

function Replay:StopReplay()
	if not self.Playing then return end
	self:_disconnectRecording()
	self.Playing = false
	self.CustomEvents.ReplayEnded:Fire()
end

function Replay:CreateViewport(parent: Instance): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ReplayViewport"
	viewport.BackgroundColor3 = Color3.fromRGB(5, 7, 8)
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(110, 110, 110)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -0.7, -0.5)
	viewport.Parent = parent
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		local skyClone = sky:Clone()
		skyClone.Name = "ReplaySky"
		pcall(function()
			skyClone.Parent = viewport
		end)
		if not skyClone.Parent then
			skyClone:Destroy()
		end
	end
	local world = Instance.new("WorldModel")
	world.Name = "ReplayWorld"
	world.Parent = viewport
	self.ViewportFrame = viewport
	self:UpdateReplayLocation(world)
	local bar = Instance.new("Frame")
	bar.Name = "ReplayTimeline"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundColor3 = Color3.fromRGB(245, 247, 242)
	bar.BackgroundTransparency = 0.72
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromScale(0.5, 0.955)
	bar.Size = UDim2.fromScale(0.42, 0.006)
	bar.Parent = viewport
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(183, 255, 26)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	local time = Instance.new("TextLabel")
	time.Name = "Time"
	time.AnchorPoint = Vector2.new(0.5, 1)
	time.BackgroundTransparency = 1
	time.Position = UDim2.fromScale(0.5, 0.94)
	time.Size = UDim2.fromOffset(220, 22)
	time.Font = Enum.Font.GothamBold
	time.TextColor3 = Color3.fromRGB(245, 247, 242)
	time.TextSize = 12
	time.Parent = viewport
	table.insert(self.ViewportFrameConnections, self.ReplayFrameChanged:Connect(function()
		local firstTime = self.Frames[1] and self.Frames[1].Time or 0
		local lastTime = self.Frames[self.ReplayFrameCount] and self.Frames[self.ReplayFrameCount].Time or 0
		local span = math.max(lastTime - firstTime, 0.001)
		fill.Size = UDim2.fromScale(math.clamp((self.ReplayTime - firstTime) / span, 0, 1), 1)
		time.Text = formatTime(math.max(0, self.ReplayTime - firstTime)) .. " / " .. formatTime(span)
	end))
	return viewport
end

function Replay:Clear()
	if self.ReplayVisible then
		self.ReplayVisible = false
	end
	self:_disconnectRecording()
	for _, clone in self.ActiveClones do
		clone:Destroy()
	end
	for _, clone in self.StaticClones do
		clone:Destroy()
	end
	self.Frames = {}
	self.ActiveParts = {}
	self.ActiveClones = {}
	self.StaticClones = {}
	self.ReplayTime = 0
	self.ReplayFrame = 0
	self.ReplayT = 0
	self.ReplayFrameCount = 0
	self.Recording = false
	self.Playing = false
end

function Replay:Destroy()
	self:Clear()
	for _, connection in self.ViewportFrameConnections do
		connection:Disconnect()
	end
	for _, event in self.CustomEvents do
		event:Destroy()
	end
	table.clear(self)
end

return Replay
