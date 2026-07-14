--!strict
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraRelativeMovement = require(script.Parent.CameraRelativeMovement)
local DeviceGameplayConfig = require(ReplicatedStorage.VTR.Shared.DeviceGameplayConfig)
local Controller = {}
Controller.__index = Controller

local BROADCAST_ZOOM_MULTIPLIER = 0.68
local BROADCAST_HEIGHT = 178 * BROADCAST_ZOOM_MULTIPLIER
local BROADCAST_SIDE_OFFSET = 222 * BROADCAST_ZOOM_MULTIPLIER
local BROADCAST_FOV = 34
-- Tune this while testing with the Workspace attribute
-- VTRBallDistanceZoomMultiplier. Higher values react more strongly.
local BALL_DISTANCE_ZOOM_MULTIPLIER = 0.05
local BALL_LOOK_SMOOTHING = 0.072
local BALL_LOOK_MAX_SPEED = 1500
local BALL_LOOK_MAX_LAG = 8.5
local BALL_TRACKING_SMOOTHING = 0.088
local BALL_FOCUS_MAX_SPEED = 215
local BALL_FOCUS_HELD_MAX_SPEED = 82
local PRESETS = {
	Broadcast = {Height = 112, Side = 250, Fov = 43, Smooth = 0.18},
	WideBroadcast = {Height = 112, Side = 250, Fov = 43, Smooth = 0.18},
	["Wide Broadcast"] = {Height = 112, Side = 250, Fov = 43, Smooth = 0.18},
	Tactical = {Height = 112, Side = 250, Fov = 43, Smooth = 0.18},
	Pro = {Height = 16, Side = 34, Fov = 55, Smooth = 0.075},
}

local CAMERA_ALIASES = {
	["Broadcast"] = "Tactical",
	["WideBroadcast"] = "Tactical",
	["Wide Broadcast"] = "Tactical",
	["CloseBroadcast"] = "Tactical",
	["Close Broadcast"] = "Tactical",
	["End to End"] = "Tactical",
	["Co-op"] = "Tactical",
}

local ZOOM_MODES = {
	Close = {Height = -10, Side = -12, Fov = -2},
	Moderate = {Height = -4, Side = -5, Fov = 0},
	Default = {Height = -4, Side = -5, Fov = 0},
	Wide = {Height = 0, Side = 0, Fov = 0},
	["Tactical Wide"] = {Height = 18, Side = 18, Fov = 4},
}
local DEFAULT_SAFE_SCREEN_FRAME = table.freeze({Left = .12, Right = .12, Top = .1, Bottom = .15})

local function activeRoot(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function modelRootByName(name: string, cache: {[string]: Model}): BasePart?
	return activeRoot(cache[name])
end

local function ballFocusPosition(ball: BasePart, active: Model?, cache: {[string]: Model}): Vector3
	if ball:GetAttribute("VTRGoalkeeperHeld") == true then
		local ownerName = tostring(ball:GetAttribute("OwnerModel") or "")
		local root = active and active.Name == ownerName and activeRoot(active) or modelRootByName(ownerName, cache)
		if root then
			return root.Position + Vector3.new(0, 2.8, 0)
		end
	end
	local ownerName = tostring(ball:GetAttribute("OwnerModel") or "")
	if ownerName ~= "" then
		local root = active and active.Name == ownerName and activeRoot(active) or modelRootByName(ownerName, cache)
		if root then
			local movement = root.Parent and root.Parent:GetAttribute("VTRMoveDirection")
			local direction = typeof(movement) == "Vector3" and movement.Magnitude > 0.1 and Vector3.new(movement.X, 0, movement.Z) or Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if direction.Magnitude < 0.05 then
				direction = Vector3.zAxis
			else
				direction = direction.Unit
			end
			local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			local lead = math.clamp(speed * 0.028, 0, 1.15)
			return root.Position + direction * (5.25 + lead) + Vector3.new(0, -1.2, 0)
		end
	end
	return ball.Position
end

local function predictedBallPosition(ball: BasePart): Vector3?
	if ball:GetAttribute("VTRGoalkeeperHeld") == true then return nil end
	local visual = workspace:FindFirstChild("VTRPredictedBall")
	if not visual then return nil end
	if visual:IsA("BasePart") then
		return visual.Position
	end
	if visual:IsA("Model") then
		local ballPart = visual:FindFirstChild(ball.Name, true)
		if ballPart and ballPart:IsA("BasePart") then
			return ballPart.Position
		end
		local primary = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
		return primary and primary.Position or visual:GetPivot().Position
	end
	return nil
end

local function cameraBallFocusPosition(ball: BasePart, active: Model?, cache: {[string]: Model}): Vector3
	local predicted = predictedBallPosition(ball)
	if predicted then
		return predicted
	end
	return ballFocusPosition(ball, active, cache)
end

local function vectorAttribute(part: BasePart, name: string): Vector3?
	local value = part:GetAttribute(name)
	return typeof(value) == "Vector3" and value or nil
end

local function markerCFrame(name: string): CFrame?
	local marker = workspace:FindFirstChild(name) or workspace:FindFirstChild(name, true)
	if not marker then return nil end
	if marker:IsA("BasePart") then return marker.CFrame end
	if marker:IsA("Model") then return marker:GetPivot() end
	if marker:IsA("Attachment") then return marker.WorldCFrame end
	return nil
end

local function presentationGroupCenter(states: {[string]: boolean}, models: {Model}): Vector3?
	local total = Vector3.zero
	local count = 0
	for _, inst in models do
		if not inst.Parent then continue end
		local state = inst:GetAttribute("VTRPresentationState")
		if type(state) ~= "string" or not states[state] then continue end
		local root = inst:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			total += root.Position
			count += 1
		end
	end
	return count > 0 and total / count or nil
end

local function softLimit(value: number, limit: number, softness: number): number
	limit = math.max(0.01, math.abs(limit))
	softness = math.clamp(math.abs(softness), 0.01, limit * 0.85)
	local sign = value < 0 and -1 or 1
	local absolute = math.abs(value)
	local inner = limit - softness
	if absolute <= inner then
		return value
	end
	local over = absolute - inner
	return sign * (inner + softness * (1 - math.exp(-over / softness)))
end

local function scaleCameraDistance(pitchCFrame: CFrame, cameraWorld: Vector3, targetWorld: Vector3, distanceScale: number?): Vector3
	local targetLocal = pitchCFrame:PointToObjectSpace(targetWorld)
	local cameraLocal = pitchCFrame:PointToObjectSpace(cameraWorld)
	local closeLocal = targetLocal + (cameraLocal - targetLocal) * (distanceScale or 1)
	closeLocal = Vector3.new(closeLocal.X, math.max(closeLocal.Y, targetLocal.Y + 16), closeLocal.Z)
	return pitchCFrame:PointToWorldSpace(closeLocal)
end

local function shouldIgnoreCameraHit(instance: Instance): boolean
	if not instance:IsA("BasePart") then
		return true
	end
	if instance.CanQuery == false or instance.Transparency >= 0.92 or instance.LocalTransparencyModifier >= 0.92 then
		return true
	end
	local name = string.lower(instance.Name)
	if string.find(name, "pitch", 1, true) or string.find(name, "line", 1, true) or string.find(name, "net", 1, true) then
		return true
	end
	local model = instance:FindFirstAncestorWhichIsA("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function defaultDeviceProfile(): any
	if UserInputService.TouchEnabled then
		return DeviceGameplayConfig.Camera.Mobile
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return DeviceGameplayConfig.Camera.Gamepad
	end
	return DeviceGameplayConfig.Camera.Desktop
end

local function attackingGoalSign(active: Model?, half: number): number
	local side = tostring(active and active:GetAttribute("VTRTeam") or "Home")
	return side == "Home" and (half >= 2 and 1 or -1) or (half >= 2 and -1 or 1)
end

local function goalkeeperRootForSide(side: string, models: {Model}): BasePart?
	for _, inst in models do
		if inst.Parent and inst:GetAttribute("VTRTeam") == side and inst:GetAttribute("position") == "GK" then
			local root = activeRoot(inst)
			if root then
				return root
			end
		end
	end
	return nil
end

function Controller.new(pitchCFrame: CFrame, width: number, length: number, ball: BasePart, active: Model)
	local cameraPoint=workspace:FindFirstChild("BroadcastCameraPoint",true)
	if cameraPoint and not cameraPoint:IsA("BasePart")then cameraPoint=nil end
	local camera = workspace.CurrentCamera
	local profile = defaultDeviceProfile()
	local obstructionParams = RaycastParams.new()
	obstructionParams.FilterType = Enum.RaycastFilterType.Exclude
	obstructionParams.IgnoreWater = true
	local activeHeight = 6
	local ok, size = pcall(function()
		return active:GetExtentsSize()
	end)
	if ok and typeof(size) == "Vector3" then
		activeHeight = math.clamp(size.Y, 4.5, 9)
	end
	local modelCache: {[string]: Model} = {}
	local matchModels: {Model} = {}
	local world = ball.Parent
	if world then
		for _, instance in world:GetDescendants() do
			if instance:IsA("Model") and activeRoot(instance) then
				modelCache[instance.Name] = instance
				table.insert(matchModels, instance)
			end
		end
	end
	local self = setmetatable({
		Camera = camera,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Ball = ball,
		Active = active,
		ModelCache = modelCache,
		MatchModels = matchModels,
		Mode = "Tactical",
		SideSign = 1,
		HeightOffset = 0,
		ZoomOffset = 0,
		SideOffset = 0,
		WheelZoom = 0,
		InputConnections = {},
		SpeedScale = 1,
		LastMove = pitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, -1)),
		SmoothedTarget = Vector3.zero,
		SmoothedLookTarget = nil,
		SmoothedPresentationTarget = nil,
		GoalTimer = 0,
		CameraPoint = cameraPoint,
		BallDistanceZoomMultiplier = BALL_DISTANCE_ZOOM_MULTIPLIER,
		ReferenceBallDistance = nil,
		SafeBallPosition = ball.Position,
		ClientCameraBall = nil,
		ClientBallVelocity = Vector3.zero,
		LastClientBallPosition = ball.Position,
		TacticalView = false,
		TacticalCFrame = nil,
		TacticalFocusLocal = Vector3.zero,
		TacticalYaw = 0,
		TacticalHeight = math.max(length * 0.82, 150),
		TacticalDistance = math.max(width * 0.28, 110),
		ShootingFocus = false,
		ForcedShootingGoalSign = nil,
		ShootingFocusCameraPosition = nil,
		ShootingFocusCameraTarget = nil,
		FreeKickPan = Vector2.zero,
		FreeKickPanTarget = Vector2.zero,
		DeviceProfile = profile,
		UseDeviceProfile = true,
		BaseFieldOfView = profile.FieldOfView,
		ProfileHeight = profile.Height,
		ProfileSideDistance = profile.SideDistance,
		ZoomMinimum = profile.ZoomMinimum,
		ZoomMaximum = profile.ZoomMaximum,
		SwitchBlendDuration = profile.SwitchBlendSeconds or DeviceGameplayConfig.Camera.SwitchBlendSeconds,
		SafeScreenFrame = profile.SafeScreenFrame,
		ControlledPlayerMinimumApparentSize = profile.ControlledPlayerMinimumApparentSize,
		ActiveHeight = activeHeight,
		ObstructionParams = obstructionParams,
		ObstructionExclusions = {},
		ObstructionFraction = 1,
		ObstructionInterval = 1 / 25,
		LastObstructionAt = -math.huge,
		LastObstructionTarget = nil,
		LastObstructionCamera = nil,
		ProThreatInterval = 0.1,
		LastProThreatAt = -math.huge,
		ProBehindPoint = nil,
		ProBehindScore = math.huge,
		ReducedMotion = workspace:GetAttribute("VTRReducedMotion") == true,
		PreparedReception = nil,
		PreparedReceptionPoint = nil,
		PreparedReceptionETA = nil,
		PreparedReceptionUntil = nil,
	}, Controller)
	self:_refreshObstructionExclusions()
	return self
end

function Controller:_refreshObstructionExclusions()
	local excluded = self.ObstructionExclusions
	table.clear(excluded)
	if self.Active then table.insert(excluded, self.Active) end
	if self.Ball then table.insert(excluded, self.Ball) end
	if self.Ball and self.Ball.Parent and self.Ball.Parent:IsA("Model") then
		table.insert(excluded, self.Ball.Parent)
	end
	if self.Camera then table.insert(excluded, self.Camera) end
	self.ObstructionParams.FilterDescendantsInstances = excluded
	self.LastObstructionAt = -math.huge
end

function Controller:_wheelZoom(): number
	return math.clamp(tonumber(self.WheelZoom) or 0, tonumber(self.ZoomMinimum) or -5, tonumber(self.ZoomMaximum) or 7)
end

function Controller:_baseFov(preset: any): number
	if self.UseDeviceProfile ~= false then
		return tonumber(self.BaseFieldOfView) or tonumber(preset and preset.Fov) or 62
	end
	return tonumber(preset and preset.Fov) or 62
end

function Controller:_baseHeight(preset: any): number
	if self.UseDeviceProfile ~= false then
		return tonumber(self.ProfileHeight) or tonumber(preset and preset.Height) or 112
	end
	return tonumber(preset and preset.Height) or 112
end

function Controller:_baseSideDistance(preset: any): number
	if self.UseDeviceProfile ~= false then
		return tonumber(self.ProfileSideDistance) or tonumber(preset and preset.Side) or 250
	end
	return tonumber(preset and preset.Side) or 250
end

function Controller:_clearCameraObstruction(targetWorld: Vector3, cameraWorld: Vector3): Vector3
	local offset = cameraWorld - targetWorld
	local distance = offset.Magnitude
	if distance < 8 then
		self.ObstructionFraction = 1
		return cameraWorld
	end
	local now = os.clock()
	local majorChange = self.LastObstructionTarget == nil
		or (targetWorld - self.LastObstructionTarget).Magnitude > 18
		or self.LastObstructionCamera == nil
		or (cameraWorld - self.LastObstructionCamera).Magnitude > 22
	if not majorChange and now - self.LastObstructionAt < self.ObstructionInterval then
		return targetWorld + offset * self.ObstructionFraction
	end
	self.LastObstructionAt = now
	self.LastObstructionTarget = targetWorld
	self.LastObstructionCamera = cameraWorld
	local direction = offset.Unit
	local origin = targetWorld
	local remaining = distance
	local traversed = 0
	local resolvedFraction = 1
	for _ = 1, 3 do
		local hit = workspace:Raycast(origin, direction * remaining, self.ObstructionParams)
		if not hit then
			resolvedFraction = 1
			break
		end
		if not shouldIgnoreCameraHit(hit.Instance) then
			local clearDistance = math.clamp(traversed + hit.Distance - 4, math.min(18, distance), distance)
			resolvedFraction = clearDistance / distance
			break
		end
		local advance = math.min(remaining, hit.Distance + 0.45)
		traversed += advance
		remaining -= advance
		if remaining <= 0.5 then
			resolvedFraction = 1
			break
		end
		origin += direction * advance
	end
	if resolvedFraction > self.ObstructionFraction and not majorChange then
		self.ObstructionFraction += (resolvedFraction - self.ObstructionFraction) * 0.28
	else
		self.ObstructionFraction = resolvedFraction
	end
	return targetWorld + offset * self.ObstructionFraction
end

function Controller:_applySwitchBlend()
	local from = self.SwitchBlendFromCFrame
	if not from then return end
	local duration = self.ReducedMotion and 0 or math.clamp(tonumber(self.SwitchBlendDuration) or 0.16, 0.12, 0.2)
	if duration <= 0 then
		self.SwitchBlendFromCFrame = nil
		self.SwitchBlendFromFov = nil
		return
	end
	local alpha = math.clamp((os.clock() - (self.SwitchBlendStartedAt or 0)) / duration, 0, 1)
	local eased = alpha * alpha * (3 - 2 * alpha)
	self.Camera.CFrame = from:Lerp(self.Camera.CFrame, eased)
	if self.SwitchBlendFromFov then
		self.Camera.FieldOfView = self.SwitchBlendFromFov + (self.Camera.FieldOfView - self.SwitchBlendFromFov) * eased
	end
	if alpha >= 1 then
		self.SwitchBlendFromCFrame = nil
		self.SwitchBlendFromFov = nil
	end
end

function Controller:_updateProThreat(root: BasePart, attackDirection: Vector3, right: Vector3)
	local now = os.clock()
	local moved = self.LastProThreatRootPosition == nil or (root.Position - self.LastProThreatRootPosition).Magnitude > 16
	if not moved and now - self.LastProThreatAt < self.ProThreatInterval then return end
	self.LastProThreatAt = now
	self.LastProThreatRootPosition = root.Position
	local behindPoint: Vector3? = nil
	local behindScore = math.huge
	for _, model in self.MatchModels do
		if model.Parent and model ~= self.Active then
			local modelRoot = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if modelRoot and modelRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local offset = Vector3.new(modelRoot.Position.X - root.Position.X, 0, modelRoot.Position.Z - root.Position.Z)
				local behind = -offset:Dot(attackDirection)
				local sideAmount = math.abs(offset:Dot(right))
				if behind > 4 and behind < 82 and sideAmount < 48 then
					local score = behind + sideAmount * 0.35
					if score < behindScore then
						behindScore = score
						behindPoint = modelRoot.Position + Vector3.new(0, 2.6, 0)
					end
				end
			end
		end
	end
	self.ProBehindPoint = behindPoint
	self.ProBehindScore = behindScore
end

function Controller:Start()
	if self.Mode == "Roblox" then
		self:_useRobloxCamera()
		return
	end
	self.Camera.CameraType = Enum.CameraType.Scriptable
	local startingPreset = PRESETS[self.Mode] or PRESETS.Tactical
	self.Camera.FieldOfView = self:_baseFov(startingPreset)
	table.insert(self.InputConnections, UserInputService.InputChanged:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() then return end
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		self.WheelZoom = math.clamp((self.WheelZoom or 0) - input.Position.Z, self.ZoomMinimum, self.ZoomMaximum)
	end))
	table.insert(self.InputConnections, UserInputService.InputBegan:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() then return end
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			self.WheelZoom = 0
			self.ReferenceBallDistance = nil
			local preset = PRESETS[self.Mode] or PRESETS.Tactical or PRESETS.Broadcast
			self.Camera.FieldOfView = self:_baseFov(preset) + self.ZoomOffset
		end
	end))
	local root = activeRoot(self.Active)
	local presentationCenter = presentationGroupCenter({WalkForward = true, LineupIdle = true, KickoffReady = true}, self.MatchModels)
	local initial = presentationCenter or self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 8, 0))
	if not presentationCenter and root then
		local localRoot = self.PitchCFrame:PointToObjectSpace(root.Position)
		if math.abs(localRoot.X) <= self.Width * 0.75 and math.abs(localRoot.Z) <= self.Length * 0.75 then
			initial = root.Position
		end
	end
	self.SmoothedTarget = self.PitchCFrame:PointToObjectSpace(initial)
	self.SmoothedLookTarget = self.Ball.Position
	self.SafeBallPosition = self.Ball.Position
	self.Camera.CFrame = CFrame.lookAt(self.PitchCFrame:PointToWorldSpace(Vector3.new(self.Width*.92,240,self.Length*.38)), self.PitchCFrame:PointToWorldSpace(Vector3.new(0,8,0)), self.PitchCFrame.UpVector)
	self.ReferenceBallDistance=(self.Camera.CFrame.Position-self.Ball.Position).Magnitude
	if workspace:GetAttribute("VTRKickoffDebug") == true and (RunService:IsStudio() or game.PrivateServerId ~= "") then
		print("[VTR KICKOFF][Camera] broadcast camera started", "mode", self.Mode, "initial", initial, "ball", self.Ball.Position, "cameraType", self.Camera.CameraType.Name)
	end
end

function Controller:_ensureClientCameraBall(): BasePart?
	if self.ClientCameraBall and self.ClientCameraBall.Parent then
		return self.ClientCameraBall
	end
	if not self.Ball or not self.Ball.Parent then
		return nil
	end
	local proxy = Instance.new("Part")
	proxy.Name = "VTRClientCameraBall"
	proxy.Shape = Enum.PartType.Ball
	proxy.Size = self.Ball.Size * 1.04
	proxy.Anchored = true
	proxy.CanCollide = false
	proxy.CanTouch = false
	proxy.CanQuery = false
	proxy.CastShadow = false
	proxy.Massless = true
	proxy.Material = Enum.Material.SmoothPlastic
	proxy.Color = Color3.fromRGB(90, 205, 255)
	proxy.Transparency = workspace:GetAttribute("VTRShowClientCameraBall") == true and 0.35 or 1
	proxy.CFrame = CFrame.new(self.SafeBallPosition or self.Ball.Position)
	proxy.Parent = workspace
	self.ClientCameraBall = proxy
	self.LastClientBallPosition = proxy.Position
	return proxy
end

function Controller:_updateClientCameraBall(position: Vector3, dt: number)
	local proxy = self:_ensureClientCameraBall()
	if not proxy then return end
	local previous = self.LastClientBallPosition or proxy.Position
	proxy.Transparency = workspace:GetAttribute("VTRShowClientCameraBall") == true and 0.35 or 1
	proxy.Size = self.Ball and self.Ball.Parent and self.Ball.Size * 1.04 or proxy.Size
	proxy.CFrame = CFrame.new(position)
	self.ClientBallVelocity = dt > 0 and (position - previous) / dt or Vector3.zero
	self.LastClientBallPosition = position
end

function Controller:_safeBallFocusPosition(rawPosition: Vector3, dt: number, goalkeeperTransition: boolean): Vector3
	local fallback = self.SafeBallPosition or rawPosition
	if rawPosition.X ~= rawPosition.X or rawPosition.Y ~= rawPosition.Y or rawPosition.Z ~= rawPosition.Z then
		self:_updateClientCameraBall(fallback, dt)
		return fallback
	end
	if not self.SafeBallPosition then
		self.SafeBallPosition = rawPosition
		self:_updateClientCameraBall(rawPosition, dt)
		return rawPosition
	end
	local rawLocal = self.PitchCFrame:PointToObjectSpace(rawPosition)
	local floorFocusY = math.max((self.Ball and self.Ball.Size.Y * 0.5 or 1) + 2.05, 3.2)
	if rawLocal.Y < floorFocusY + 0.45 then
		rawPosition = self.PitchCFrame:PointToWorldSpace(Vector3.new(rawLocal.X, floorFocusY, rawLocal.Z))
	else
		rawPosition = self.PitchCFrame:PointToWorldSpace(Vector3.new(rawLocal.X, math.clamp(rawLocal.Y, floorFocusY, 18), rawLocal.Z))
	end
	local cameraProxySmooth = math.clamp(tonumber(workspace:GetAttribute("VTRClientCameraBallSmoothing")) or 0.105, 0.055, 0.32)
	local cameraProxyLag = math.clamp(tonumber(workspace:GetAttribute("VTRClientCameraBallMaxLag")) or 8.5, 2, 24)
	local maxSpeed = goalkeeperTransition and BALL_FOCUS_HELD_MAX_SPEED or (tonumber(workspace:GetAttribute("VTRClientCameraBallMaxSpeed")) or 175)
	local maxStep = math.max(4, maxSpeed * math.max(dt, 1 / 120))
	local delta = rawPosition - self.SafeBallPosition
	local target = rawPosition
	if delta.Magnitude > maxStep then
		target = self.SafeBallPosition + delta.Unit * maxStep
	end
	if delta.Magnitude > cameraProxyLag then
		self.SafeBallPosition = rawPosition - delta.Unit * cameraProxyLag
		delta = rawPosition - self.SafeBallPosition
	end
	local safeLocal = self.PitchCFrame:PointToObjectSpace(self.SafeBallPosition)
	local targetLocal = self.PitchCFrame:PointToObjectSpace(target)
	local verticalTarget = targetLocal.Y
	local verticalAlpha = 1 - math.exp(-dt / (goalkeeperTransition and 0.58 or 0.52))
	target = self.PitchCFrame:PointToWorldSpace(Vector3.new(targetLocal.X, safeLocal.Y + (verticalTarget - safeLocal.Y) * verticalAlpha, targetLocal.Z))
	local smooth = goalkeeperTransition and math.max(cameraProxySmooth, 0.22) or cameraProxySmooth
	self.SafeBallPosition = self.SafeBallPosition:Lerp(target, 1 - math.exp(-dt / smooth))
	self:_updateClientCameraBall(self.SafeBallPosition, dt)
	return self.SafeBallPosition
end

function Controller:SetMode(mode: string)
	if self.ForcedMode and (self.ForcedMode == "Roblox" or self.ForcedMode == "PlayThirdPerson" or PRESETS[self.ForcedMode]) then
		mode = self.ForcedMode
	end
	mode = CAMERA_ALIASES[mode] or mode
	if mode == "Roblox" then
		self.Mode = mode
		self:_useRobloxCamera()
		return
	end
	if mode == "PlayThirdPerson" then
		self.Mode = mode
		self.Camera.CameraType = Enum.CameraType.Scriptable
		return
	end
	if PRESETS[mode] then
		self.Mode = mode
	end
end

function Controller:PrepareReception(model: Model, point: Vector3?, eta: number?)
	if not model or not model.Parent then return end
	self.PreparedReception = model
	self.PreparedReceptionPoint = typeof(point) == "Vector3" and point or nil
	self.PreparedReceptionETA = math.max(0, tonumber(eta) or 1)
	self.PreparedReceptionUntil = os.clock() + math.max(1, (self.PreparedReceptionETA or 1) + 0.8)
end

function Controller:UpdateReceptionPreparation(model: Model, point: Vector3?, eta: number?)
	if self.PreparedReception ~= model then return end
	if typeof(point) == "Vector3" then self.PreparedReceptionPoint = point end
	local numericETA = tonumber(eta)
	if numericETA then self.PreparedReceptionETA = math.max(0, numericETA) end
	self.PreparedReceptionUntil = os.clock() + math.max(0.8, (self.PreparedReceptionETA or 0) + 0.55)
end

function Controller:CancelReceptionPreparation(model: Model?)
	if model and self.PreparedReception ~= model then return end
	self.PreparedReception = nil
	self.PreparedReceptionPoint = nil
	self.PreparedReceptionETA = nil
	self.PreparedReceptionUntil = nil
end

function Controller:_receptionFocus(rawPosition: Vector3): Vector3
	local model = self.PreparedReception
	if not model or not model.Parent or (tonumber(self.PreparedReceptionUntil) or 0) <= os.clock() then
		self:CancelReceptionPreparation()
		return rawPosition
	end
	local modelRoot = activeRoot(model)
	local point = typeof(self.PreparedReceptionPoint) == "Vector3" and self.PreparedReceptionPoint or (modelRoot and modelRoot.Position or nil)
	if not point then return rawPosition end
	local eta = math.max(0, tonumber(self.PreparedReceptionETA) or 1)
	local progress = 1 - math.clamp(eta / 1.05, 0, 1)
	local blend = self.ReducedMotion and 0.08 or 0.1 + progress * 0.2
	return rawPosition:Lerp(point + Vector3.new(0, 2.2, 0), blend)
end

function Controller:ApplySettings(settings: any, deviceProfile: any?)
	local profile = deviceProfile
	if not profile and settings.CameraPreset == "Auto" then
		profile = defaultDeviceProfile()
	end
	self.UseDeviceProfile = profile ~= nil
	self.DeviceProfile = profile
	if profile then
		self.BaseFieldOfView = tonumber(profile.FieldOfView) or self.BaseFieldOfView
		self.ProfileHeight = tonumber(profile.Height) or self.ProfileHeight
		self.ProfileSideDistance = tonumber(profile.SideDistance) or self.ProfileSideDistance
		self.ZoomMinimum = tonumber(profile.ZoomMinimum) or -5
		self.ZoomMaximum = tonumber(profile.ZoomMaximum) or 7
		self.SwitchBlendDuration = tonumber(profile.SwitchBlendSeconds) or DeviceGameplayConfig.Camera.SwitchBlendSeconds
		self.SafeScreenFrame = profile.SafeScreenFrame
		self.ControlledPlayerMinimumApparentSize = tonumber(profile.ControlledPlayerMinimumApparentSize) or 0.06
	else
		self.ZoomMinimum = -5
		self.ZoomMaximum = 7
		self.SwitchBlendDuration = DeviceGameplayConfig.Camera.SwitchBlendSeconds
		self.SafeScreenFrame = nil
		self.ControlledPlayerMinimumApparentSize = 0.055
	end
	self.ReducedMotion = settings.ReducedMotion == true or workspace:GetAttribute("VTRReducedMotion") == true
	self.WheelZoom = math.clamp(tonumber(self.WheelZoom) or 0, self.ZoomMinimum, self.ZoomMaximum)
	if self.Mode == "Roblox" then
		self:_useRobloxCamera()
		return
	end
	if self.Mode == "PlayThirdPerson" then
		self.Camera.CameraType = Enum.CameraType.Scriptable
		self.Camera.FieldOfView = self:_baseFov(PRESETS.Pro)
		return
	end
	local height = tonumber(settings.BroadcastHeight)
	local zoom = tonumber(settings.BroadcastZoom)
	local speed = tonumber(settings.CameraSpeed)
	local zoomMode = ZOOM_MODES[settings.CameraZoomMode or "Wide"] or ZOOM_MODES.Wide
	self.HeightOffset = zoomMode.Height + (height and height >= 150 and math.clamp(height - 178, -25, 30) or 0)
	self.SideOffset = zoomMode.Side
	self.ZoomOffset = zoomMode.Fov + (zoom and zoom >= 45 and math.clamp(zoom - 50, -4, 5) or 0)
	self.SpeedScale = speed and math.clamp(speed, 0.65, 1.5) or 1
	self.SideSign = settings.CameraSide == "Far" and -1 or 1
end

function Controller:SetTacticalView(active: boolean)
	self.TacticalView = active == true
	if self.TacticalView then
		self.ShootingFocus = false
		self.TacticalFocusLocal = self.TacticalFocusLocal or Vector3.zero
		self.TacticalYaw = self.TacticalYaw or 0
		self.TacticalHeight = self.TacticalHeight or math.max(self.Length * 0.82, 150)
		self.TacticalDistance = self.TacticalDistance or math.max(self.Width * 0.28, 110)
		self.Camera.CameraType = Enum.CameraType.Scriptable
		self.Camera.FieldOfView = 58
	else
		self.TacticalCFrame = nil
	end
end

function Controller:SetShootingFocus(active: boolean): boolean
	self.ShootingFocus = active == true
	if self.ShootingFocus then
		self.TacticalView = false
		self.TacticalCFrame = nil
		self.ShootingFocusCameraPosition = nil
		self.ShootingFocusCameraTarget = nil
	end
	return self.ShootingFocus
end

function Controller:SetForcedShootingGoalSign(goalSign: number?)
	self.ForcedShootingGoalSign = tonumber(goalSign)
end

function Controller:ToggleShootingFocus(): boolean
	return self:SetShootingFocus(not self.ShootingFocus)
end

function Controller:_updateTactical(dt: number)
	local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 310 or 170
	local rotateSpeed = 1.15
	local zoomSpeed = 310
	local moveX = 0
	local moveZ = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then moveX -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then moveX += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then moveZ -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then moveZ += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) then self.TacticalYaw += rotateSpeed * dt end
	if UserInputService:IsKeyDown(Enum.KeyCode.E) then self.TacticalYaw -= rotateSpeed * dt end
	if UserInputService:IsKeyDown(Enum.KeyCode.R) then self.TacticalHeight -= zoomSpeed * dt end
	if UserInputService:IsKeyDown(Enum.KeyCode.F) then self.TacticalHeight += zoomSpeed * dt end
	self.TacticalHeight = math.clamp(self.TacticalHeight, math.max(145, self.Length * 0.24), math.max(210, self.Length * 0.92))
	local yaw = self.TacticalYaw or 0
	if moveX ~= 0 or moveZ ~= 0 then
		local input = Vector3.new(moveX, 0, moveZ)
		if input.Magnitude > 1 then input = input.Unit end
		local rotated = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(input)
		local focus = self.TacticalFocusLocal or Vector3.zero
		focus += rotated * speed * dt
		self.TacticalFocusLocal = Vector3.new(
			math.clamp(focus.X, -self.Width * 0.5, self.Width * 0.5),
			0,
			math.clamp(focus.Z, -self.Length * 0.5, self.Length * 0.5)
		)
	end
	local focusLocal = self.TacticalFocusLocal or Vector3.zero
	local wheelZoom = self:_wheelZoom()
	local orbit = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(self.Width * 0.10, 0, (self.TacticalDistance or math.max(self.Width * 0.28, 110)) + wheelZoom * 12))
	local positionLocal = focusLocal + Vector3.new(orbit.X, math.clamp(self.TacticalHeight + wheelZoom * 7, math.max(90, self.Length * 0.18), math.max(240, self.Length)), orbit.Z)
	local focus = self.PitchCFrame:PointToWorldSpace(focusLocal + Vector3.new(0, 4, 0))
	local position = self.PitchCFrame:PointToWorldSpace(positionLocal)
	self.TacticalCFrame = CFrame.lookAt(position, focus, self.PitchCFrame.UpVector)
	self.Camera.CFrame = self.Camera.CFrame:Lerp(self.TacticalCFrame, 1 - math.exp(-10 * dt))
	self.Camera.FieldOfView += (math.clamp(58 + wheelZoom * 0.9, 46, 66) - self.Camera.FieldOfView) * (1 - math.exp(-7 * dt))
end

function Controller:_updatePro(dt: number, root: BasePart)
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local attackSign = attackingGoalSign(self.Active, half)
	local ownerName = tostring(self.Ball:GetAttribute("OwnerModel") or "")
	local hasBall = ownerName == self.Active.Name
	if hasBall then
		self.ProViewSign = attackSign
	elseif ownerName ~= "" then
		self.ProViewSign = -attackSign
	end
	local viewSign = self.ProViewSign or attackSign
	local attackDirection = self.PitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, viewSign))
	attackDirection = Vector3.new(attackDirection.X, 0, attackDirection.Z)
	attackDirection = attackDirection.Magnitude > .1 and attackDirection.Unit or Vector3.zAxis

	local right = self.PitchCFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z)
	right = right.Magnitude > .1 and right.Unit or Vector3.xAxis

	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local speed = velocity.Magnitude
	local forwardSpeed = velocity:Dot(attackDirection)
	local backRun = math.clamp(-forwardSpeed, 0, 40)
	local goalkeeperTransition = self.Ball:GetAttribute("VTRGoalkeeperHeld") == true
	local ballPosition = self:_safeBallFocusPosition(self:_receptionFocus(cameraBallFocusPosition(self.Ball, self.Active, self.ModelCache)), dt, goalkeeperTransition)

	local ballOffset = Vector3.new(ballPosition.X - root.Position.X, 0, ballPosition.Z - root.Position.Z)
	local ballForward = ballOffset:Dot(attackDirection)
	local ballSide = ballOffset:Dot(right)

	local goalCenter = self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 4.8, viewSign * self.Length * .5))
	local goalDistance = Vector3.new(goalCenter.X - root.Position.X, 0, goalCenter.Z - root.Position.Z).Magnitude
	local goalBlend = math.clamp((170 - goalDistance) / 170, 0, 1)
	self:_updateProThreat(root, attackDirection, right)
	local behindPoint = self.ProBehindPoint
	local behindScore = self.ProBehindScore
	local preset = PRESETS.Pro
	local wheelZoom = self:_wheelZoom()
	local profileDistance = math.max(34, self:_baseSideDistance(preset) + self.SideOffset + wheelZoom * 5)
	local profileHeight = math.max(15, self:_baseHeight(preset) + self.HeightOffset + wheelZoom * 1.5)
	local baseFov = self:_baseFov(preset)
	local baseDistance = profileDistance + speed * .12 + backRun * .62
	if behindPoint then
		baseDistance = math.max(baseDistance, math.clamp(behindScore + 50, profileDistance, 142))
	end
	local distance = math.clamp(baseDistance, math.max(34, profileDistance * .82), math.max(142, profileDistance * 2.5))
	local height = math.clamp(profileHeight + speed * .04 + backRun * .1 + (behindPoint and 3 or 0), 15, 72)
	local fov = math.clamp(baseFov + speed * .012 + backRun * .035 + (behindPoint and 1.5 or 0) + wheelZoom * .55, baseFov - 4, math.min(86, baseFov + 11))
	if ballOffset.Magnitude < 64 and not behindPoint then
		local minimumSize = math.clamp(tonumber(self.ControlledPlayerMinimumApparentSize) or .06, .045, .1)
		local readableDistance = self.ActiveHeight / math.max(2 * minimumSize * math.tan(math.rad(fov) * .5), .01)
		local horizontalLimit = math.sqrt(math.max(readableDistance * readableDistance - height * height, 34 * 34))
		distance = math.min(distance, horizontalLimit)
	end

	local localRoot = self.PitchCFrame:PointToObjectSpace(root.Position)
	local goalSidePull = math.clamp(-localRoot.X * goalBlend * .05, -7, 7)
	local desiredSide = math.clamp(ballSide * .15, -10, 10) + goalSidePull
	local target = root.Position
		+ attackDirection * math.clamp(58 + math.clamp(ballForward, -8, 120) * .18, 50, 88)
		+ right * math.clamp(ballSide * .28, -14, 14)
		+ Vector3.new(0, 6.5, 0)

	if ballForward > 0 and ballOffset.Magnitude < 72 then
		target = target:Lerp(ballPosition + Vector3.new(0, 3.4, 0), .26)
	end

	if goalBlend > 0 then
		target = target:Lerp(goalCenter, goalBlend * .28)
		desiredSide += goalSidePull * .8
	end

	local viewport = self.Camera.ViewportSize
	local aspect = viewport.Y > 0 and viewport.X / viewport.Y or 16 / 9

	local checkPoints: {Vector3} = {
		ballPosition + Vector3.new(0, 1.7, 0),
		root.Position + Vector3.new(0, self.ActiveHeight * .55, 0),
		root.Position - Vector3.new(0, self.ActiveHeight * .42, 0),
	}
	if behindPoint then
		table.insert(checkPoints, behindPoint)
	end

	local function contains(frame: CFrame, checkFov: number, point: Vector3): boolean
		local localPoint = frame:PointToObjectSpace(point)
		if localPoint.Z >= -4 then return false end
		local depth = -localPoint.Z
		local halfV = math.tan(math.rad(checkFov) * .5) * depth
		local halfH = halfV * aspect
		local safe = self.SafeScreenFrame or DEFAULT_SAFE_SCREEN_FRAME
		local x = localPoint.X / math.max(halfH, .01)
		local y = localPoint.Y / math.max(halfV, .01)
		return x >= -1 + 2 * safe.Left and x <= 1 - 2 * safe.Right and y <= 1 - 2 * safe.Top and y >= -1 + 2 * safe.Bottom
	end

	for _ = 1, 3 do
		local desired = root.Position - attackDirection * distance + right * desiredSide + Vector3.new(0, height, 0)
		local frame = CFrame.lookAt(desired, target, self.PitchCFrame.UpVector)
		local allVisible = true
		for _, point in ipairs(checkPoints) do
			if not contains(frame, fov, point) then
				allVisible = false
				break
			end
		end
		if allVisible then break end
		distance = math.min(distance + math.max(9, profileDistance * .16), math.max(174, profileDistance * 2.7))
		height = math.min(height + 2.8, 82)
		fov = math.min(fov + 1.6, math.min(88, baseFov + 12))
		target = target:Lerp(ballPosition + Vector3.new(0, 3.6, 0), .12)
	end

	local desired = root.Position - attackDirection * distance + right * desiredSide + Vector3.new(0, height, 0)

	self.ProCameraPosition = self.ProCameraPosition and self.ProCameraPosition:Lerp(desired, 1 - math.exp(-dt / .26)) or desired
	self.ProCameraTarget = self.ProCameraTarget and self.ProCameraTarget:Lerp(target, 1 - math.exp(-dt / .24)) or target

	local cameraPosition = self:_clearCameraObstruction(self.ProCameraTarget, self.ProCameraPosition)
	self.Camera.CFrame = CFrame.lookAt(cameraPosition, self.ProCameraTarget, self.PitchCFrame.UpVector)
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / .28))
end

function Controller:_updatePlayThirdPerson(dt: number, root: BasePart)
	local ownerName = tostring(self.Ball:GetAttribute("OwnerModel") or "")
	local hasBall = self.Active and ownerName == self.Active.Name
	local attackSign = attackingGoalSign(self.Active, tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1)
	local ballPosition = self:_receptionFocus(cameraBallFocusPosition(self.Ball, self.Active, self.ModelCache))
	local goalTarget = self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 5.5, attackSign * self.Length * .5))
	local target = hasBall and goalTarget or (ballPosition + Vector3.new(0, 2.4, 0))
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flat.Magnitude < 4 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if flat.Magnitude < .1 then
		flat = self.PitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, attackSign))
		flat = Vector3.new(flat.X, 0, flat.Z)
	end
	local lookDirection = flat.Unit
	local right = Vector3.new(self.PitchCFrame.RightVector.X, 0, self.PitchCFrame.RightVector.Z)
	right = right.Magnitude > .1 and right.Unit or Vector3.xAxis
	local wheelZoom = self:_wheelZoom()
	local distance = math.clamp(self:_baseSideDistance(PRESETS.Pro) + self.SideOffset + wheelZoom * 6, 14, 90)
	local height = math.clamp(self:_baseHeight(PRESETS.Pro) + self.HeightOffset + wheelZoom * 1.4, 7, 30)
	local focus = root.Position:Lerp(target, hasBall and .28 or .18) + Vector3.new(0, 4.2, 0)
	local sideOffset = math.clamp(flat:Dot(right) * .06, -5, 5)
	local desired = root.Position - lookDirection * distance + right * sideOffset + Vector3.new(0, height, 0)
	desired = self:_clearCameraObstruction(focus, desired)
	self.PlayCameraPosition = self.PlayCameraPosition and self.PlayCameraPosition:Lerp(desired, 1 - math.exp(-dt / .16)) or desired
	self.PlayCameraTarget = self.PlayCameraTarget and self.PlayCameraTarget:Lerp(focus, 1 - math.exp(-dt / .12)) or focus
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Camera.CFrame = CFrame.lookAt(self.PlayCameraPosition, self.PlayCameraTarget, self.PitchCFrame.UpVector)
	local baseFov = self:_baseFov(PRESETS.Pro)
	self.Camera.FieldOfView += (math.clamp(baseFov + wheelZoom * .9, baseFov - 10, math.min(88, baseFov + 8)) - self.Camera.FieldOfView) * (1 - math.exp(-dt / .18))
end

function Controller:_updateShootingFocus(dt: number, root: BasePart)
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local attackSign = tonumber(self.ForcedShootingGoalSign) or attackingGoalSign(self.Active, half)
	local attackDirection = self.PitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, attackSign))
	attackDirection = Vector3.new(attackDirection.X, 0, attackDirection.Z)
	attackDirection = attackDirection.Magnitude > .1 and attackDirection.Unit or Vector3.zAxis
	local right = self.PitchCFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z)
	right = right.Magnitude > .1 and right.Unit or Vector3.xAxis

	local side = tostring(self.Active and self.Active:GetAttribute("VTRTeam") or "Home")
	local defendingSide = side == "Home" and "Away" or "Home"
	local keeperRoot = goalkeeperRootForSide(defendingSide, self.MatchModels)
	local rawBallPosition = self:_receptionFocus(cameraBallFocusPosition(self.Ball, self.Active, self.ModelCache))
	local goalkeeperTransition = self.Ball:GetAttribute("VTRGoalkeeperHeld") == true
	local ballPosition = self:_safeBallFocusPosition(rawBallPosition, dt, goalkeeperTransition)
	local goalCenter = self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 5.4, attackSign * self.Length * .5))
	local flatGoalDelta = Vector3.new(goalCenter.X - ballPosition.X, 0, goalCenter.Z - ballPosition.Z)
	local boxPressure = math.clamp((190 - flatGoalDelta.Magnitude) / 190, 0, 1)
	local localRoot = self.PitchCFrame:PointToObjectSpace(root.Position)
	local sidePull = math.clamp(-localRoot.X * .045, -9, 9)
	local target = ballPosition:Lerp(goalCenter, .52 + boxPressure * .1) + Vector3.new(0, 2.6, 0)
	if keeperRoot then
		target = target:Lerp(keeperRoot.Position + Vector3.new(0, 3.2, 0), .22 + boxPressure * .14)
	end
	local desired = root.Position - attackDirection * (58 - boxPressure * 10) + right * sidePull + Vector3.new(0, 18 + boxPressure * 7, 0)
	desired = self:_clearCameraObstruction(target, desired)
	self.ShootingFocusCameraPosition = self.ShootingFocusCameraPosition and self.ShootingFocusCameraPosition:Lerp(desired, 1 - math.exp(-dt / .15)) or desired
	self.ShootingFocusCameraTarget = self.ShootingFocusCameraTarget and self.ShootingFocusCameraTarget:Lerp(target, 1 - math.exp(-dt / .12)) or target
	self.Camera.CFrame = CFrame.lookAt(self.ShootingFocusCameraPosition, self.ShootingFocusCameraTarget, self.PitchCFrame.UpVector)
	self.Camera.FieldOfView += ((44 - boxPressure * 5) - self.Camera.FieldOfView) * (1 - math.exp(-dt / .16))
end

function Controller:CycleMode(): string
	local order = {"Tactical", "Pro"}
	self.Mode = order[(table.find(order, self.Mode) or 1) % #order + 1]
	return self.Mode
end

function Controller:SetActive(model: Model)
	if self.Active == model then return end
	if self.Active and self.Camera.CameraType == Enum.CameraType.Scriptable and not self.ReducedMotion then
		self.SwitchBlendFromCFrame = self.Camera.CFrame
		self.SwitchBlendFromFov = self.Camera.FieldOfView
		self.SwitchBlendStartedAt = os.clock()
	end
	self.Active = model
	if self.ModelCache[model.Name]~=model then self.ModelCache[model.Name]=model;table.insert(self.MatchModels,model)end
	local ok, size = pcall(function()
		return model:GetExtentsSize()
	end)
	if ok and typeof(size) == "Vector3" then
		self.ActiveHeight = math.clamp(size.Y, 4.5, 9)
	end
	self.LastProThreatAt = -math.huge
	self.ProBehindPoint = nil
	self.ProBehindScore = math.huge
	self.PlayCameraPosition = nil
	self.PlayCameraTarget = nil
	self:_refreshObstructionExclusions()
	if self.Mode == "Roblox" then
		self:_useRobloxCamera()
	end
end

function Controller:_useRobloxCamera()
	local humanoid = self.Active and self.Active:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self.Camera.CameraSubject = humanoid
	end
	local player = Players.LocalPlayer
	if player then
		player.CameraMinZoomDistance = 2
		player.CameraMaxZoomDistance = 48
	end
	self.Camera.CameraType = Enum.CameraType.Custom
	self.Camera.FieldOfView = 70
end

function Controller:Movement(input: Vector2): Vector3
	local worldDirection = CameraRelativeMovement.GetMoveDirection(self.Camera, input)
	self.CurrentMove = worldDirection
	if worldDirection.Magnitude > 0.1 then
		self.LastMove = worldDirection.Unit
	end
	local root = activeRoot(self.Active)
	if root then
		CameraRelativeMovement.UpdateDebug(root.Position - Vector3.new(0, 2.7, 0), self.Camera, worldDirection)
	end
	return worldDirection
end

function Controller:Aim(kind: string?): Vector3
	local root = activeRoot(self.Active)
	local currentMove = self.CurrentMove or Vector3.zero
	if kind == "Shot" and root then
		local side = tostring(self.Active:GetAttribute("VTRTeam") or "Home")
		local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
		local attackSign = side == "Home" and (half >= 2 and 1 or -1) or (half >= 2 and -1 or 1)
		local goal = self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 2, attackSign * self.Length / 2))
		local goalDirection = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
		goalDirection = goalDirection.Magnitude > .05 and goalDirection.Unit or self.LastMove
		if currentMove.Magnitude > 0.1 then
			return (goalDirection * 0.82 + currentMove.Unit * 0.18).Unit
		end
		return goalDirection
	end
	if currentMove.Magnitude > 0.1 then
		return currentMove.Unit
	end
	if root then
		local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if facing.Magnitude > 0.1 then
			return facing.Unit
		end
	end
	return self.LastMove.Magnitude > 0.1 and self.LastMove or CameraRelativeMovement.GetMoveDirection(self.Camera, Vector2.new(0, 1))
end

function Controller:BeginCutscene(kind: string, location: Vector3, duration: number, goalPosition: Vector3?)
	self.CutsceneStartCFrame = self.Camera.CFrame
	self.CutsceneStartFOV = self.Camera.FieldOfView
	self.CutsceneKind = kind
	self.CutsceneLocation = location
	self.CutsceneGoalPosition = goalPosition
	self.CutsceneStartedAt = os.clock()
	self.CutsceneUntil = os.clock() + math.clamp(duration, 1, 3)
	if kind == "FreeKick" or kind == "Penalty" then
		self.CutsceneUntil = os.clock() + math.clamp(duration, 1, 60)
	end
	if kind == "FreeKick" then
		self.FreeKickPan = Vector2.zero
		self.FreeKickPanTarget = Vector2.zero
	end
end

function Controller:ApplyFreeKickPan(input: Vector2?, dt: number)
	local vector = input or Vector2.zero
	if vector.Magnitude > 1 then vector = vector.Unit end
	local strength = math.clamp(tonumber(workspace:GetAttribute("VTRFreeKickCameraPanStrength")) or 1, 0, 2)
	local rate = math.clamp(tonumber(workspace:GetAttribute("VTRFreeKickCameraPanRate")) or 1.7, 0.2, 4)
	local currentTarget = self.FreeKickPanTarget or Vector2.zero
	local target = Vector2.new(math.clamp(currentTarget.X + vector.X * rate * strength * dt, -1, 1), math.clamp(currentTarget.Y + vector.Y * rate * strength * dt, -0.65, 0.75))
	if vector.Magnitude <= 0.02 then
		target = currentTarget:Lerp(Vector2.zero, 1 - math.exp(-dt / 1.3))
	end
	self.FreeKickPanTarget = target
	self.FreeKickPan = (self.FreeKickPan or Vector2.zero):Lerp(target, 1 - math.exp(-dt / 0.12))
end

function Controller:BeginStadiumIntro(duration: number?)
	self.CutsceneKind = "StadiumIntro"
	self.CutsceneLocation = self.PitchCFrame.Position
	self.CutsceneGoalPosition = nil
	self.CutsceneStartedAt = os.clock()
	self.CutsceneUntil = os.clock() + math.clamp(duration or 4.6, 2.5, 45)
end

function Controller:BeginHalfTimeWide(duration: number?)
	self.CutsceneKind = "HalfTime"
	self.CutsceneLocation = self.PitchCFrame.Position
	self.CutsceneGoalPosition = nil
	self.CutsceneStartedAt = os.clock()
	self.CutsceneUntil = os.clock() + math.clamp(duration or 30, 6, 35)
end

function Controller:BeginGoalCelebration(location: Vector3, lookAt: Vector3?, duration: number?)
	self.CutsceneStartCFrame = self.Camera.CFrame
	self.CutsceneStartFOV = self.Camera.FieldOfView
	self.CutsceneKind = "GoalCelebration"
	self.CutsceneLocation = location
	self.CutsceneGoalPosition = lookAt
	self.CutsceneStartedAt = os.clock()
	self.CutsceneUntil = os.clock() + math.clamp(duration or 3, 1.2, 8)
	self.CutsceneHardLock = true
	self.ShootingFocus = false
end

function Controller:EndCutscene(force: boolean?)
	if self.CutsceneHardLock and force ~= true then
		return
	end
	self.CutsceneUntil = nil
	self.CutsceneKind = nil
	self.CutsceneLocation = nil
	self.CutsceneGoalPosition = nil
	self.CutsceneStartedAt = nil
	self.CutsceneStartCFrame = nil
	self.CutsceneStartFOV = nil
	self.CutsceneHardLock = nil
end

function Controller:ReturnToLive()
	if self.CutsceneHardLock then
		return
	end
	self:EndCutscene(true)
	if self.Mode == "Roblox" then
		self:_useRobloxCamera()
		return
	end
	if self.Mode == "PlayThirdPerson" then
		self.Camera.CameraType = Enum.CameraType.Scriptable
		return
	end
	self.SmoothedPresentationTarget = nil
	local focus = self.Ball and self.Ball.Parent and cameraBallFocusPosition(self.Ball, self.Active, self.ModelCache) or self.PitchCFrame.Position
	self.SafeBallPosition = focus
	self.SmoothedTarget = self.PitchCFrame:PointToObjectSpace(focus)
	self.SmoothedLookTarget = focus
	self:_updateClientCameraBall(focus, 1 / 60)
	local preset = PRESETS[self.Mode] or PRESETS.Tactical or PRESETS.Broadcast
	local frame = self:_desiredFrame(preset, focus, 0, 0)
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Camera.CFrame = frame
	self.Camera.FieldOfView = self:_baseFov(preset)
end

function Controller:_desiredFrame(preset: any, targetWorld: Vector3, dynamicZoom: number, longitudinalVelocity: number): CFrame
	if self.Mode == "Pro" then
		local root = activeRoot(self.Active)
		if root then
			local wheelZoom = self:_wheelZoom()
			local side = tostring(self.Active:GetAttribute("VTRTeam") or "Home")
			local goalZ = side == "Home" and -self.Length * 0.5 or self.Length * 0.5
			local localRoot = self.PitchCFrame:PointToObjectSpace(root.Position)
			local lookLocal = Vector3.new(math.clamp(localRoot.X * 0.35, -self.Width * 0.18, self.Width * 0.18), 4.5, goalZ * 0.72)
			local forward = self.PitchCFrame:VectorToObjectSpace(root.CFrame.LookVector)
			local flatForward = Vector3.new(forward.X, 0, forward.Z)
			if flatForward.Magnitude < .1 then flatForward = Vector3.new(0, 0, side == "Home" and -1 or 1) end
			local cameraLocal = localRoot - flatForward.Unit * (self:_baseSideDistance(preset) + self.SideOffset + wheelZoom * 4.2) + Vector3.new(0, self:_baseHeight(preset) + self.HeightOffset + wheelZoom * 2.8, 0)
			local cameraWorld = self.PitchCFrame:PointToWorldSpace(cameraLocal)
			local lookWorld = self.PitchCFrame:PointToWorldSpace(lookLocal)
			return CFrame.lookAt(cameraWorld, lookWorld, self.PitchCFrame.UpVector)
		end
	end
	if self.Mode == "Tactical" or self.Mode == "WideBroadcast" or self.Mode == "Broadcast" then
		local wheelZoom = self:_wheelZoom()
		local ballLocal = self.PitchCFrame:PointToObjectSpace(targetWorld)
		local side = (self:_baseSideDistance(preset) + self.SideOffset + wheelZoom * 8) * self.SideSign
		local cameraX = side + math.clamp(self.SmoothedTarget.X * 0.06, -self.Width * 0.035, self.Width * 0.035)
		local cameraZ = softLimit(self.SmoothedTarget.Z * 0.86 - longitudinalVelocity * 0.035, self.Length * 0.48, self.Length * 0.075)
		local cameraLocal = Vector3.new(cameraX, math.clamp(self:_baseHeight(preset) + self.HeightOffset + wheelZoom * 4.5 + dynamicZoom * 0.1, 82, 164), cameraZ)
		local focusLocal = Vector3.new(
			softLimit(ballLocal.X * 0.18, self.Width * 0.12, self.Width * 0.03),
			5.8,
			softLimit(ballLocal.Z, self.Length * 0.48, self.Length * 0.075)
		)
		local cameraWorld = self.PitchCFrame:PointToWorldSpace(cameraLocal)
		local focusWorld = self.PitchCFrame:PointToWorldSpace(focusLocal)
		return CFrame.lookAt(cameraWorld, focusWorld, self.PitchCFrame.UpVector)
	end
	if self.CameraPoint and self.CameraPoint.Parent then
		local anchorLocal=self.PitchCFrame:PointToObjectSpace(self.CameraPoint.Position)
		-- The stadium marker owns height and distance from the touchline. The
		-- camera tracks play only along the stand, then tilts toward the ball.
		local trackZ = self.SmoothedTarget.Z + anchorLocal.Z * 0.08 - longitudinalVelocity * 0.035
		local cameraZ=math.clamp(trackZ,-self.Length*.49,self.Length*.49)
		local cameraWorld=self.PitchCFrame:PointToWorldSpace(Vector3.new(anchorLocal.X,anchorLocal.Y,cameraZ))
		return CFrame.lookAt(scaleCameraDistance(self.PitchCFrame,cameraWorld,targetWorld,preset.DistanceScale),targetWorld)
	end
	local wheelZoom = self:_wheelZoom()
	local height = math.clamp(self:_baseHeight(preset) + self.HeightOffset + wheelZoom * 8 + dynamicZoom * 0.45, 72, 240)
	local side = math.clamp(self:_baseSideDistance(preset) + self.SideOffset + wheelZoom * 14 + dynamicZoom * 1.2, 92, 295) * self.SideSign
	local cameraX = side + self.SmoothedTarget.X * 0.38
	local cameraZ = self.SmoothedTarget.Z * 0.92 - longitudinalVelocity * 0.05
	local cameraLocal = Vector3.new(cameraX, height, math.clamp(cameraZ, -self.Length * 0.43, self.Length * 0.43))
	local cameraWorld = self.PitchCFrame:PointToWorldSpace(cameraLocal)
	return CFrame.lookAt(scaleCameraDistance(self.PitchCFrame,cameraWorld,targetWorld,preset.DistanceScale), targetWorld)
end

function Controller:_nearbyTacticalShapeLocal(ballLocal: Vector3, attackSign: number, team: string): Vector3?
	local total = Vector3.zero
	local weight = 0
	for _, inst in self.MatchModels do
		if not inst.Parent then continue end
		local root = activeRoot(inst)
		if not root then continue end
		local localPosition = self.PitchCFrame:PointToObjectSpace(root.Position)
		local dx = math.abs(localPosition.X - ballLocal.X)
		local dz = math.abs(localPosition.Z - ballLocal.Z)
		if dx > self.Width * 0.52 or dz > self.Length * 0.38 then continue end
		local sameTeam = tostring(inst:GetAttribute("VTRTeam") or "") == team
		local ahead = (localPosition.Z - ballLocal.Z) * attackSign
		local laneWeight = 0
		if sameTeam and ahead > -12 then
			laneWeight = math.clamp(1 - math.abs(ahead - 28) / 70, 0.12, 0.72)
		elseif not sameTeam and ahead > -8 and ahead < 70 then
			laneWeight = math.clamp(1 - math.abs(ahead - 24) / 62, 0.08, 0.42)
		end
		if laneWeight > 0 then
			total += localPosition * laneWeight
			weight += laneWeight
		end
	end
	return weight > 0 and total / weight or nil
end

function Controller:_updateTacticalLive(dt: number, root: BasePart, preset: any)
	local goalkeeperHeld = self.Ball:GetAttribute("VTRGoalkeeperHeld") == true
	local goalkeeperReleaseUntil = tonumber(self.Ball:GetAttribute("VTRGoalkeeperReleaseCameraUntil")) or 0
	if goalkeeperHeld then
		self.WasGoalkeeperHeld = true
	elseif self.WasGoalkeeperHeld then
		self.WasGoalkeeperHeld = false
		self.GoalkeeperReleaseCameraUntil = os.clock() + 0.75
	end
	local goalkeeperTransition = goalkeeperHeld or goalkeeperReleaseUntil > os.clock() or (tonumber(self.GoalkeeperReleaseCameraUntil) or 0) > os.clock()
	local ballPosition = self:_safeBallFocusPosition(self:_receptionFocus(cameraBallFocusPosition(self.Ball, self.Active, self.ModelCache)), dt, goalkeeperTransition)
	local ballLocal = self.PitchCFrame:PointToObjectSpace(ballPosition)
	local ownerName = tostring(self.Ball:GetAttribute("OwnerModel") or "")
	local ownerModel = ownerName ~= "" and self.ModelCache[ownerName] or nil
	local phaseModel = ownerModel or self.Active
	local team = tostring(phaseModel and phaseModel:GetAttribute("VTRTeam") or self.Active:GetAttribute("VTRTeam") or "Home")
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local attackSign = attackingGoalSign(phaseModel or self.Active, half)
	local rawBallVelocity = (self.ClientBallVelocity and self.ClientBallVelocity.Magnitude > 0.01) and self.ClientBallVelocity or self.Ball.AssemblyLinearVelocity
	local safeBallVelocity = rawBallVelocity.Magnitude > 230 and rawBallVelocity.Unit * 230 or rawBallVelocity
	local velocityLocal = self.PitchCFrame:VectorToObjectSpace(safeBallVelocity)
	local speed = Vector3.new(safeBallVelocity.X, 0, safeBallVelocity.Z).Magnitude
	local motionKind = tostring(self.Ball:GetAttribute("VTRMotionKind") or "")
	local passTarget = self.Ball:GetAttribute("VTRLobPassActive") == true and vectorAttribute(self.Ball, "VTRLobTarget") or vectorAttribute(self.Ball, "VTRPassTarget")
	local shotTarget = vectorAttribute(self.Ball, "VTRShotTarget")
	local targetAttr = (motionKind == "Shot" and shotTarget) or passTarget
	local targetLocal = targetAttr and self.PitchCFrame:PointToObjectSpace(targetAttr) or nil
	local progress = math.clamp((ballLocal.Z * attackSign + self.Length * 0.5) / math.max(self.Length, 1), 0, 1)
	local finalThird = math.clamp((progress - 0.62) / 0.28, 0, 1)
	local midfield = 1 - math.clamp(math.abs(progress - 0.5) / 0.24, 0, 1)
	local wide = math.clamp((math.abs(ballLocal.X) - self.Width * 0.26) / math.max(self.Width * 0.19, 1), 0, 1)
	local sideRelative = math.clamp((ballLocal.X * self.SideSign) / math.max(self.Width * 0.5, 1), -1, 1)
	local nearWide = wide * math.clamp(sideRelative, 0, 1)
	local farWide = wide * math.clamp(-sideRelative, 0, 1)
	local velocityLook = Vector3.new(
		math.clamp(velocityLocal.X * 0.16, -18, 18),
		0,
		math.clamp(velocityLocal.Z * 0.18, -26, 26)
	)
	local attackBias = Vector3.new(0, 0, attackSign * (24 + midfield * 10 - finalThird * 7))
	local desiredLocal = ballLocal + attackBias + velocityLook
	if targetLocal then
		local passBias = motionKind == "Shot" and 0.46 or self.Ball:GetAttribute("VTRLobPassActive") == true and 0.58 or 0.52
		desiredLocal = desiredLocal:Lerp(targetLocal + Vector3.new(0, 0, attackSign * 8), passBias)
	end
	local shapeLocal = self:_nearbyTacticalShapeLocal(ballLocal, attackSign, team)
	if shapeLocal then
		desiredLocal = desiredLocal:Lerp(shapeLocal + Vector3.new(0, 0, attackSign * 12), 0.18)
	end
	if wide > 0 then
		local centralBoxX = math.clamp(ballLocal.X * 0.18, -self.Width * 0.12, self.Width * 0.12)
		desiredLocal = Vector3.new(
			desiredLocal.X + (centralBoxX - desiredLocal.X) * (0.56 * wide),
			desiredLocal.Y,
			desiredLocal.Z + attackSign * 10 * wide
		)
	end
	desiredLocal = Vector3.new(
		softLimit(desiredLocal.X, self.Width * 0.36, self.Width * 0.09),
		5.6,
		softLimit(desiredLocal.Z, self.Length * 0.45, self.Length * 0.08)
	)
	local trackingSmooth = math.clamp(tonumber(workspace:GetAttribute("VTRTacticalTrackingSmoothing")) or (0.25 / self.SpeedScale), 0.11, 0.55)
	if targetLocal or speed > 55 then trackingSmooth *= 0.78 end
	if wide > 0 then trackingSmooth = math.max(trackingSmooth, 0.23 + wide * 0.1) end
	if goalkeeperTransition then trackingSmooth = math.max(trackingSmooth, 0.2) end
	local alpha = 1 - math.exp(-dt / trackingSmooth)
	self.SmoothedTarget = self.SmoothedTarget and self.SmoothedTarget:Lerp(desiredLocal, alpha) or desiredLocal
	local focusLocal = Vector3.new(self.SmoothedTarget.X, 5.8, self.SmoothedTarget.Z)
	local wheelZoom = self:_wheelZoom()
	local userHeight = self.HeightOffset
	local userSide = self.SideOffset
	local baseHeight = self:_baseHeight(preset) + userHeight + wheelZoom * 6
	local baseSide = (self:_baseSideDistance(preset) + userSide + wheelZoom * 10) * self.SideSign
	local slightZoomIn = finalThird * 9
	local transitionZoomOut = ((targetLocal and 1 or 0) * 9) + math.clamp(speed / 70, 0, 1) * 7 + midfield * 7
	local wideZoomOut = nearWide * 42 + farWide * 8
	local height = math.clamp(baseHeight + transitionZoomOut * 0.45 + nearWide * 7 + farWide * 1.5 - slightZoomIn * 0.45, 86, 168)
	local side = math.clamp(math.abs(baseSide) + transitionZoomOut * 0.5 + wideZoomOut - slightZoomIn * 0.18, 220, 360) * (baseSide < 0 and -1 or 1)
	local diagonalX = self.SmoothedTarget.X * 0.025
	local cameraZ = softLimit(self.SmoothedTarget.Z - velocityLocal.Z * 0.025, self.Length * 0.47, self.Length * 0.08)
	local cameraLocal = Vector3.new(side + diagonalX, height, cameraZ)
	local focusWorld = self.PitchCFrame:PointToWorldSpace(focusLocal)
	local cameraWorld = self.PitchCFrame:PointToWorldSpace(cameraLocal)
	cameraWorld = focusWorld + (cameraWorld - focusWorld) * (1.0 + nearWide * 0.2 - farWide * 0.08)
	local desiredCFrame = CFrame.lookAt(cameraWorld, focusWorld, self.PitchCFrame.UpVector)
	local cameraSmooth = math.clamp(tonumber(workspace:GetAttribute("VTRTacticalCameraSmoothing")) or (0.24 / self.SpeedScale), 0.12, 0.48)
	if targetLocal or speed > 60 then cameraSmooth *= 0.84 end
	if wide > 0 then cameraSmooth = math.max(cameraSmooth, 0.24 + wide * 0.08) end
	if goalkeeperTransition then cameraSmooth = math.max(cameraSmooth, 0.2) end
	local cameraAlpha = 1 - math.exp(-dt / cameraSmooth)
	local cameraPosition = self.Camera.CFrame.Position:Lerp(desiredCFrame.Position, cameraAlpha)
	cameraPosition = self:_clearCameraObstruction(focusWorld, cameraPosition)
	self.Camera.CFrame = CFrame.lookAt(cameraPosition, focusWorld, self.PitchCFrame.UpVector)
	local fovBase = tonumber(workspace:GetAttribute("VTRTacticalFOV")) or self:_baseFov(preset)
	local fov = math.clamp(fovBase + self.ZoomOffset + wheelZoom * 0.65 + transitionZoomOut * 0.045 + nearWide * 0.9 - farWide * 1.8 - finalThird * 0.7, math.max(26, fovBase - 9), math.min(88, fovBase + 7))
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.22))
end

function Controller:_updateCutscene(dt: number): boolean
	local expired = self.CutsceneUntil and os.clock() >= self.CutsceneUntil
	if not self.CutsceneUntil or (expired and not self.CutsceneHardLock) then
		self.CutsceneUntil = nil
		self.CutsceneKind = nil
		self.CutsceneLocation = nil
		self.CutsceneGoalPosition = nil
		self.CutsceneStartCFrame = nil
		self.CutsceneStartFOV = nil
		self.CutsceneHardLock = nil
		self.SmoothedLookTarget = self.Ball and self.Ball.Parent and self.Ball.Position or self.PitchCFrame.Position
		self.SafeBallPosition = self.SmoothedLookTarget
		return false
	end
	local focus = self.CutsceneLocation or self.Ball.Position
	local localFocus = self.PitchCFrame:PointToObjectSpace(focus)
	local kind = self.CutsceneKind
	if kind == "StadiumIntro" then
		local started = self.CutsceneStartedAt or os.clock()
		local total = math.max(0.1, (self.CutsceneUntil or os.clock()) - started)
		local alpha = math.clamp((os.clock() - started) / total, 0, 1)
		local function smooth(t:number):number
			return t*t*(3-2*t)
		end
		local function between(a:number,b:number):number
			return smooth(math.clamp((alpha-a)/(b-a),0,1))
		end
		local authored = workspace:FindFirstChild("StadiumIntroCamera", true) or workspace:FindFirstChild("StadiumCamera", true)
		if authored and authored:IsA("BasePart") and total <= 8.5 then
			local cameraWorld = authored.Position
			local target = self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 7, 0))
			self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(cameraWorld, target), 1 - math.exp(-dt / 0.16))
		else
			local tunnel = markerCFrame("Tunnel")
			local anthem = markerCFrame("AnthemPoint")
			if tunnel and anthem and alpha >= .06 then
				local desired: Vector3
				local target: Vector3
				local tunnelToAnthem = anthem.Position - tunnel.Position
				local forward = tunnelToAnthem.Magnitude > .1 and tunnelToAnthem.Unit or self.PitchCFrame.LookVector
				local right = forward:Cross(Vector3.yAxis)
				if right.Magnitude < .1 then right = self.PitchCFrame.RightVector else right = right.Unit end
				local lineupCenter = presentationGroupCenter({LineupIdle = true}, self.MatchModels)
				local kickoffCenter = presentationGroupCenter({KickoffReady = true}, self.MatchModels)
				local walkingCenter = presentationGroupCenter({WalkForward = true, TunnelIdle = true}, self.MatchModels)
				if walkingCenter then
					self.SmoothedPresentationTarget = self.SmoothedPresentationTarget and self.SmoothedPresentationTarget:Lerp(walkingCenter, 1 - math.exp(-dt / 0.34)) or walkingCenter
				elseif lineupCenter or kickoffCenter then
					self.SmoothedPresentationTarget = self.SmoothedPresentationTarget and self.SmoothedPresentationTarget:Lerp(lineupCenter or kickoffCenter :: Vector3, 1 - math.exp(-dt / 0.2)) or (lineupCenter or kickoffCenter)
				end
				if alpha < .123 then
					local t = between(.06, .123)
					target = tunnel.Position + forward * (4 + 9 * t) + Vector3.new(0, 4.5, 0)
					desired = tunnel.Position + right * (9 + 3 * t) + forward * (18 + 4 * t) + Vector3.new(0, 7.5, 0)
				elseif not lineupCenter and not kickoffCenter and alpha < .427 then
					local t = between(.123, .427)
					local track = tunnel.Position:Lerp(anthem.Position, .10 + .52 * t)
					local walkoutCamera = markerCFrame("WalkoutPosition")
					target = track + Vector3.new(0, 5.4, 0)
					desired = walkoutCamera and walkoutCamera.Position or track + right * (34 - 8 * t) + forward * (78 - 14 * t) + Vector3.new(0, 20 + 4 * t, 0)
				elseif not kickoffCenter and alpha < .853 then
					local t = between(.427, .853)
					local center = lineupCenter or anthem.Position
					local orbit = (-.35 + t * .82) * math.pi
					target = center + Vector3.new(0, 5.6, 0)
					desired = center + right * (math.cos(orbit) * 58) + forward * (math.sin(orbit) * 35 - 20) + Vector3.new(0, 24 + math.sin(t * math.pi) * 7, 0)
				else
					local t = between(.853, 1)
					local panX = (-self.Width * .42 + self.Width * .84 * t) * self.SideSign
					local panZ = self.Length * (.18 - .32 * t)
					target = self.PitchCFrame.Position + Vector3.new(0, 6, 0)
					desired = self.PitchCFrame:PointToWorldSpace(Vector3.new(panX * .72, 205, panZ * .72))
				end
				local cameraSmoothing = if not lineupCenter and not kickoffCenter and alpha < .427 then 0.08 else 0.13
				self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, target), 1 - math.exp(-dt / cameraSmoothing))
				self.Camera.FieldOfView += ((alpha < .427 and 68 or alpha < .853 and 63 or 43) - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.16))
				return true
			end
			local side = self.SideSign
			local cameraLocal:Vector3
			local targetLocal:Vector3
			if alpha < .14 then
				local t=between(0,.14)
				cameraLocal=Vector3.new(self.Width*.95*side,86,self.Length*(.72-.24*t))
				targetLocal=Vector3.new(0,12,self.Length*(.18-.18*t))
			elseif alpha < .30 then
				local t=between(.14,.30)
				cameraLocal=Vector3.new(0,8,-self.Length*.54+self.Length*.18*t)
				targetLocal=Vector3.new(0,6,-self.Length*.5+self.Length*.2*t)
			elseif alpha < .50 then
				local t=between(.30,.50)
				local z=-self.Length*.34+self.Length*.3*t
				cameraLocal=Vector3.new(0,7,z-18)
				targetLocal=Vector3.new(0,5,z)
			elseif alpha < .62 then
				local t=between(.50,.62)
				cameraLocal=Vector3.new(self.Width*.35*side,18+36*t,-self.Length*.08+10*t)
				targetLocal=Vector3.new(0,5,0)
			elseif alpha < .88 then
				local t=between(.62,.88)
				local angle=(-.65+t*1.3)*math.pi
				local radius=self.Width*.78
				cameraLocal=Vector3.new(math.sin(angle)*radius,44,math.cos(angle)*radius*.55)
				targetLocal=Vector3.new(0,5,0)
			else
				local t=between(.88,1)
				cameraLocal=Vector3.new((BROADCAST_SIDE_OFFSET+self.SideOffset)*side*.82,124,self.Length*.025*(1-t))
				targetLocal=Vector3.new(0,3,0)
			end
			local desired = self.PitchCFrame:PointToWorldSpace(cameraLocal)
			local target = self.PitchCFrame:PointToWorldSpace(targetLocal)
			self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, target), 1 - math.exp(-dt / 0.18))
		end
		self.Camera.FieldOfView += (38 - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.2))
		return true
	end
	if kind == "HalfTime" then
		local started = self.CutsceneStartedAt or os.clock()
		local total = math.max(0.1, (self.CutsceneUntil or os.clock()) - started)
		local alpha = math.clamp((os.clock() - started) / total, 0, 1)
		local side = self.SideSign
		local sweep = math.sin(alpha * math.pi * .72) * self.Width * .06
		local cameraLocal = Vector3.new(self.Width * (.74 * side) + sweep, 132, -self.Length * .28 + self.Length * .12 * alpha)
		local targetLocal = Vector3.new(0, 4.5, -self.Length * .02 + self.Length * .04 * alpha)
		local desired = self.PitchCFrame:PointToWorldSpace(cameraLocal)
		local target = self.PitchCFrame:PointToWorldSpace(targetLocal)
		self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, target), 1 - math.exp(-dt / 0.18))
		self.Camera.FieldOfView += (50 - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.22))
		return true
	end
	if kind == "GoalCelebration" then
		local xSide = localFocus.X >= 0 and 1 or -1
		local zSide = localFocus.Z >= 0 and 1 or -1
		local target = self.CutsceneGoalPosition or (focus + self.PitchCFrame.UpVector * 3.2)
		local desired = focus + self.PitchCFrame.RightVector * (xSide * 20) - self.PitchCFrame.LookVector * (zSide * 26) + self.PitchCFrame.UpVector * 7.5
		self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, target, self.PitchCFrame.UpVector), 1 - math.exp(-dt / 0.1))
		self.Camera.FieldOfView += (39 - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.16))
		return true
	end
	if kind == "FreeKick" or kind == "Penalty" then
		local started = self.CutsceneStartedAt or os.clock()
		local elapsed = os.clock() - started
		local goalLocal = self.CutsceneGoalPosition and self.PitchCFrame:PointToObjectSpace(self.CutsceneGoalPosition)
		local goalZ = goalLocal and goalLocal.Z or ((self.Active and tostring(self.Active:GetAttribute("VTRTeam") or "Home") or "Home") == "Home" and -self.Length * 0.5 or self.Length * 0.5)
		local toGoalSign = goalZ >= localFocus.Z and 1 or -1
		local behind = kind == "Penalty" and 34 or 44
		local height = kind == "Penalty" and 13 or 18
		local pan = kind == "FreeKick" and (self.FreeKickPan or Vector2.zero) or Vector2.zero
		local sidePan = pan.X * self.Width * 0.34
		local heightPan = pan.Y * 10
		local targetSidePan = pan.X * self.Width * 0.18
		local cameraLocal = Vector3.new(localFocus.X + sidePan, localFocus.Y + height + heightPan, localFocus.Z - toGoalSign * behind)
		local targetLocal = Vector3.new(targetSidePan, localFocus.Y + (kind == "Penalty" and 3.3 or 5.5) + heightPan * 0.22, goalZ)
		local desired = self.PitchCFrame:PointToWorldSpace(cameraLocal)
		local target = self.PitchCFrame:PointToWorldSpace(targetLocal)
		local desiredFrame = CFrame.lookAt(desired, target)
		local desiredFov = kind == "Penalty" and 42 or 47
		local panDuration = math.clamp(tonumber(workspace:GetAttribute("VTRSetPieceCameraPanTime")) or 0.5, 0.25, 0.6)
		if elapsed < panDuration and self.CutsceneStartCFrame then
			local alpha = math.clamp(elapsed / panDuration, 0, 1)
			local eased = alpha * alpha * (3 - 2 * alpha)
			self.Camera.CFrame = self.CutsceneStartCFrame:Lerp(desiredFrame, eased)
			self.Camera.FieldOfView = (self.CutsceneStartFOV or self.Camera.FieldOfView) + (desiredFov - (self.CutsceneStartFOV or self.Camera.FieldOfView)) * eased
		else
			self.Camera.CFrame = self.Camera.CFrame:Lerp(desiredFrame, 1 - math.exp(-dt / 0.18))
			self.Camera.FieldOfView += (desiredFov - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.2))
		end
		return true
	end
	local offset = kind == "Corner" and Vector3.new(localFocus.X > 0 and -38 or 38, 30, localFocus.Z > 0 and -25 or 25)
		or kind == "GoalKick" and Vector3.new(0, 34, localFocus.Z > 0 and 45 or -45)
		or Vector3.new(65 * self.SideSign, 62, 30)
	local desired = self.PitchCFrame:PointToWorldSpace(localFocus + offset)
	self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, focus), 1 - math.exp(-dt / 0.14))
	self.Camera.FieldOfView += (44 - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.16))
	return true
end

function Controller:Update(dt: number)
	if self.Mode == "Roblox" then
		self:_useRobloxCamera()
		return
	end
	if self:_updateCutscene(dt) then
		self:_applySwitchBlend()
		return
	end
	if self.TacticalView then
		self:_updateTactical(dt)
		self:_applySwitchBlend()
		return
	end
	local root = activeRoot(self.Active)
	if not root or not self.Ball.Parent then
		return
	end
	if self.ShootingFocus then
		self:_updateShootingFocus(dt, root)
		self:_applySwitchBlend()
		return
	end
	if self.Mode == "PlayThirdPerson" then
		self:_updatePlayThirdPerson(dt, root)
		self:_applySwitchBlend()
		return
	end
	if self.Mode == "Pro" then
		self:_updatePro(dt, root)
		self:_applySwitchBlend()
		return
	end
	local preset = PRESETS[self.Mode]
	if self.Mode == "Tactical" or self.Mode == "WideBroadcast" or self.Mode == "Broadcast" then
		self:_updateTacticalLive(dt, root, preset)
		self:_applySwitchBlend()
		return
	end
	local goalkeeperHeld = self.Ball:GetAttribute("VTRGoalkeeperHeld") == true
	local goalkeeperReleaseUntil = tonumber(self.Ball:GetAttribute("VTRGoalkeeperReleaseCameraUntil")) or 0
	if goalkeeperHeld then
		self.WasGoalkeeperHeld = true
	elseif self.WasGoalkeeperHeld then
		self.WasGoalkeeperHeld = false
		self.GoalkeeperReleaseCameraUntil = os.clock() + 0.75
	end
	local goalkeeperTransition = goalkeeperHeld or goalkeeperReleaseUntil > os.clock() or (tonumber(self.GoalkeeperReleaseCameraUntil) or 0) > os.clock()
	local ballPosition = self:_safeBallFocusPosition(self:_receptionFocus(cameraBallFocusPosition(self.Ball, self.Active, self.ModelCache)), dt, goalkeeperTransition)
	if not self.SmoothedLookTarget then
		self.SmoothedLookTarget = ballPosition
	end
	local lookSmoothing = math.clamp(tonumber(workspace:GetAttribute("VTRCameraLookSmoothing")) or BALL_LOOK_SMOOTHING, 0.018, 0.8)
	local maxLookSpeed = math.clamp(tonumber(workspace:GetAttribute("VTRCameraMaxLookSpeed")) or BALL_LOOK_MAX_SPEED, 120, 2400)
	local maxLookLag = math.clamp(tonumber(workspace:GetAttribute("VTRCameraMaxLookLag")) or BALL_LOOK_MAX_LAG, 0.5, 35)
	if goalkeeperTransition then
		lookSmoothing = math.max(lookSmoothing, 0.18)
		maxLookSpeed = math.min(maxLookSpeed, 520)
		maxLookLag = math.max(maxLookLag, 9)
	end
	local lookAlpha = 1 - math.exp(-dt / lookSmoothing)
	local lookDelta = ballPosition - self.SmoothedLookTarget
	if lookDelta.Magnitude > maxLookLag then
		self.SmoothedLookTarget = ballPosition - lookDelta.Unit * maxLookLag
		lookDelta = ballPosition - self.SmoothedLookTarget
	end
	local maxStep = maxLookSpeed * dt
	if lookDelta.Magnitude > maxStep and maxStep > 0 then
		local cappedTarget = self.SmoothedLookTarget + lookDelta.Unit * maxStep
		self.SmoothedLookTarget = self.SmoothedLookTarget:Lerp(cappedTarget, lookAlpha)
	else
		self.SmoothedLookTarget = self.SmoothedLookTarget:Lerp(ballPosition, lookAlpha)
	end
	local activePosition = root.Position
	local ballLocal = self.PitchCFrame:PointToObjectSpace(ballPosition)
	-- The broadcast rig may translate smoothly, but it always looks directly at
	-- the ball. This keeps the ball centered instead of allowing the old
	-- player/goal weighting to pull play toward one side of the screen.
	local desiredLocal = self.PitchCFrame:PointToObjectSpace(ballPosition)
	desiredLocal = Vector3.new(
		softLimit(desiredLocal.X, self.Width * 0.44, self.Width * 0.075),
		2,
		softLimit(desiredLocal.Z, self.Length * 0.46, self.Length * 0.075)
	)
	local trackingSmooth = math.clamp(tonumber(workspace:GetAttribute("VTRCameraTrackingSmoothing")) or BALL_TRACKING_SMOOTHING, 0.04, 0.5)
	local targetSmooth = math.max(0.048, trackingSmooth / self.SpeedScale)
	if goalkeeperTransition then
		targetSmooth = math.max(targetSmooth, 0.16)
	end
	local targetAlphaX = 1 - math.exp(-dt / math.max(targetSmooth, 0.075))
	local targetAlphaZ = 1 - math.exp(-dt / targetSmooth)
	local edgeX = math.clamp((math.abs(desiredLocal.X) / math.max(self.Width * 0.44, 1) - 0.78) / 0.22, 0, 1)
	local edgeZ = math.clamp((math.abs(desiredLocal.Z) / math.max(self.Length * 0.46, 1) - 0.78) / 0.22, 0, 1)
	targetAlphaX *= 1 - edgeX * 0.28
	targetAlphaZ *= 1 - edgeZ * 0.34
	self.SmoothedTarget = Vector3.new(
		self.SmoothedTarget.X + (desiredLocal.X - self.SmoothedTarget.X) * targetAlphaX,
		2,
		self.SmoothedTarget.Z + (desiredLocal.Z - self.SmoothedTarget.Z) * targetAlphaZ
	)
	local targetWorld = self.SmoothedLookTarget
	local separation = (activePosition - ballPosition).Magnitude
	local rawBallVelocity = (self.ClientBallVelocity and self.ClientBallVelocity.Magnitude > 0.01) and self.ClientBallVelocity or self.Ball.AssemblyLinearVelocity
	local safeBallVelocity = rawBallVelocity.Magnitude > 215 and rawBallVelocity.Unit * 215 or rawBallVelocity
	local ballSpeed = safeBallVelocity.Magnitude
	local counterAttack = math.abs(ballLocal.Z) > self.Length * 0.26 and ballSpeed > 35
	local dynamicZoom = math.clamp(separation * 0.08 + ballSpeed * 0.09 + (counterAttack and 8 or 0), 0, 24)
	local closeDribble = self.Ball:GetAttribute("OwnerModel") == self.Active.Name and separation < 6
	if closeDribble then
		dynamicZoom = math.max(0, dynamicZoom - 4)
	end
	if self.GoalTimer > 0 then
		self.GoalTimer = math.max(0, self.GoalTimer - dt)
		dynamicZoom = 18
	end
	local velocityLocal = self.PitchCFrame:VectorToObjectSpace(safeBallVelocity)
	local desiredFrame = self:_desiredFrame(preset, targetWorld, dynamicZoom, velocityLocal.Z)
	local cameraPositionSmooth = math.clamp(tonumber(workspace:GetAttribute("VTRCameraPositionSmoothing")) or math.max(0.058, preset.Smooth * 0.5 / self.SpeedScale), 0.045, 0.45)
	if goalkeeperTransition then
		cameraPositionSmooth = math.max(cameraPositionSmooth, 0.14)
	end
	local cameraAlpha = 1 - math.exp(-dt / cameraPositionSmooth)
	local cameraPosition=self.Camera.CFrame.Position:Lerp(desiredFrame.Position,cameraAlpha)
	cameraPosition = self:_clearCameraObstruction(targetWorld, cameraPosition)
	self.Camera.CFrame=CFrame.lookAt(cameraPosition,targetWorld,self.PitchCFrame.UpVector)
	local screenPoint,onScreen = self.Camera:WorldToViewportPoint(ballPosition)
	local viewport = self.Camera.ViewportSize
	local offCenter = onScreen and viewport.X > 0 and viewport.Y > 0 and math.max(math.abs(screenPoint.X / viewport.X - 0.5), math.abs(screenPoint.Y / viewport.Y - 0.5)) or 1
	local allowedOffCenter = 0.34
	if not onScreen or screenPoint.Z <= 0 or offCenter > allowedOffCenter then
		self.SmoothedLookTarget = self.SmoothedLookTarget:Lerp(ballPosition, 0.72)
		targetWorld = self.SmoothedLookTarget
		self.Camera.CFrame = CFrame.lookAt(cameraPosition, targetWorld, self.PitchCFrame.UpVector)
	end
	local penaltyBox = math.abs(ballLocal.Z) > self.Length * 0.35
	local ballCameraDistance=(desiredFrame.Position-targetWorld).Magnitude
	if not self.ReferenceBallDistance then self.ReferenceBallDistance=ballCameraDistance end
	local runtimeMultiplier=tonumber(workspace:GetAttribute("VTRBallDistanceZoomMultiplier"))or self.BallDistanceZoomMultiplier
	local distanceZoom=-(ballCameraDistance-self.ReferenceBallDistance)*math.clamp(runtimeMultiplier,0,.3)
	local baseFov=tonumber(workspace:GetAttribute("VTRBroadcastFOV"))or self:_baseFov(preset)
	local wheelZoom = self:_wheelZoom()
	local fov = math.clamp(baseFov + self.ZoomOffset + wheelZoom * 0.75 + dynamicZoom * 0.08 + distanceZoom - (penaltyBox and 1.2 or 0), math.max(26, baseFov - 12), math.min(88, baseFov + 8))
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.18))
	self:_applySwitchBlend()
end

function Controller:GoalCinematic()
	self.GoalTimer = 2.2
end

function Controller:Destroy()
	self:CancelReceptionPreparation()
	CameraRelativeMovement.ClearDebug()
	for _, connection in self.InputConnections or {} do
		connection:Disconnect()
	end
	table.clear(self.InputConnections)
	if self.ClientCameraBall then
		self.ClientCameraBall:Destroy()
		self.ClientCameraBall = nil
	end
	self.Camera.CameraType = Enum.CameraType.Custom
	self.Camera.FieldOfView = 70
end

return Controller
