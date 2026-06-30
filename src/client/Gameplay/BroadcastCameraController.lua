--!strict
local UserInputService = game:GetService("UserInputService")
local CameraRelativeMovement = require(script.Parent.CameraRelativeMovement)
local Controller = {}
Controller.__index = Controller

local BROADCAST_ZOOM_MULTIPLIER = 0.8
local BROADCAST_HEIGHT = 178 * BROADCAST_ZOOM_MULTIPLIER
local BROADCAST_SIDE_OFFSET = 222 * BROADCAST_ZOOM_MULTIPLIER
local BROADCAST_FOV = 37
-- Tune this while testing with the Workspace attribute
-- VTRBallDistanceZoomMultiplier. Higher values react more strongly.
local BALL_DISTANCE_ZOOM_MULTIPLIER = 0.12
local BALL_LOOK_SMOOTHING = 0.07
local BALL_LOOK_MAX_SPEED = 1200
local BALL_LOOK_MAX_LAG = 5.5
local BALL_TRACKING_SMOOTHING = 0.08
local GOAL_LOOK_START_FRACTION = 0.42
local GOAL_LOOK_FULL_FRACTION = 0.18
local GOAL_LOOK_MAX_BLEND = 0.44

local PRESETS = {
	Broadcast = {Height = 128, Side = 160, Fov = 37, Smooth = 0.11},
	["Wide Broadcast"] = {Height = BROADCAST_HEIGHT, Side = BROADCAST_SIDE_OFFSET, Fov = BROADCAST_FOV, Smooth = 0.12},
	["Co-op"] = {Height = BROADCAST_HEIGHT, Side = BROADCAST_SIDE_OFFSET, Fov = BROADCAST_FOV, Smooth = 0.12},
	Tactical = {Height = 208, Side = 252, Fov = 53, Smooth = 0.14},
	Pro = {Height = 115, Side = 145, Fov = 34, Smooth = 0.10},
}

local ZOOM_MODES = {
	Close = {Height = -18, Side = -18, Fov = -2},
	Default = {Height = -8, Side = -8, Fov = 0},
	Wide = {Height = 0, Side = 0, Fov = 0},
	["Tactical Wide"] = {Height = 16, Side = 20, Fov = 3},
}

local function activeRoot(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function markerCFrame(name: string): CFrame?
	local marker = workspace:FindFirstChild(name) or workspace:FindFirstChild(name, true)
	if not marker then return nil end
	if marker:IsA("BasePart") then return marker.CFrame end
	if marker:IsA("Model") then return marker:GetPivot() end
	if marker:IsA("Attachment") then return marker.WorldCFrame end
	return nil
end

local function presentationGroupCenter(states: {[string]: boolean}): Vector3?
	local total = Vector3.zero
	local count = 0
	for _, inst in workspace:GetDescendants() do
		if not inst:IsA("Model") then continue end
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

local function smoothStep(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

function Controller.new(pitchCFrame: CFrame, width: number, length: number, ball: BasePart, active: Model)
	local cameraPoint=workspace:FindFirstChild("BroadcastCameraPoint",true)
	if cameraPoint and not cameraPoint:IsA("BasePart")then cameraPoint=nil end
	return setmetatable({
		Camera = workspace.CurrentCamera,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Ball = ball,
		Active = active,
		Mode = "Wide Broadcast",
		SideSign = 1,
		HeightOffset = 0,
		ZoomOffset = 0,
		SideOffset = 0,
		SpeedScale = 1,
		LastMove = pitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, -1)),
		SmoothedTarget = Vector3.zero,
		SmoothedLookTarget = nil,
		SmoothedPresentationTarget = nil,
		GoalTimer = 0,
		CameraPoint = cameraPoint,
		BallDistanceZoomMultiplier = BALL_DISTANCE_ZOOM_MULTIPLIER,
		ReferenceBallDistance = nil,
		TacticalView = false,
		TacticalCFrame = nil,
		TacticalFocusLocal = Vector3.zero,
		TacticalYaw = 0,
		TacticalHeight = math.max(length * 0.82, 150),
		TacticalDistance = math.max(width * 0.28, 110),
	}, Controller)
end

function Controller:Start()
	self.Camera.CameraType = Enum.CameraType.Scriptable
	self.Camera.FieldOfView = PRESETS[self.Mode].Fov
	local root = activeRoot(self.Active)
	local presentationCenter = presentationGroupCenter({WalkForward = true, LineupIdle = true, KickoffReady = true})
	local initial = presentationCenter or self.Ball.Position
	if not presentationCenter and root then
		local localRoot = self.PitchCFrame:PointToObjectSpace(root.Position)
		if math.abs(localRoot.X) <= self.Width * 0.75 and math.abs(localRoot.Z) <= self.Length * 0.75 then
			initial = root.Position
		end
	end
	self.SmoothedTarget = self.PitchCFrame:PointToObjectSpace(initial)
	self.SmoothedLookTarget = self.Ball.Position
	self.Camera.CFrame = self:_desiredFrame(PRESETS[self.Mode], initial, 0, 0)
	self.ReferenceBallDistance=(self.Camera.CFrame.Position-self.Ball.Position).Magnitude
	if workspace:GetAttribute("VTRKickoffDebug") ~= false then
		print("[VTR KICKOFF][Camera] broadcast camera started", "mode", self.Mode, "initial", initial, "ball", self.Ball.Position, "cameraType", self.Camera.CameraType.Name)
	end
end

function Controller:SetMode(mode: string)
	if PRESETS[mode] then
		self.Mode = mode
	end
end

function Controller:ApplySettings(settings: any)
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
	local orbit = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(self.Width * 0.10, 0, self.TacticalDistance or math.max(self.Width * 0.28, 110)))
	local positionLocal = focusLocal + Vector3.new(orbit.X, self.TacticalHeight, orbit.Z)
	local focus = self.PitchCFrame:PointToWorldSpace(focusLocal + Vector3.new(0, 4, 0))
	local position = self.PitchCFrame:PointToWorldSpace(positionLocal)
	self.TacticalCFrame = CFrame.lookAt(position, focus, self.PitchCFrame.UpVector)
	self.Camera.CFrame = self.Camera.CFrame:Lerp(self.TacticalCFrame, 1 - math.exp(-10 * dt))
	self.Camera.FieldOfView += (58 - self.Camera.FieldOfView) * (1 - math.exp(-7 * dt))
end

function Controller:CycleMode(): string
	local order = {"Broadcast", "Wide Broadcast", "Tactical", "Pro"}
	self.Mode = order[(table.find(order, self.Mode) or 1) % #order + 1]
	return self.Mode
end

function Controller:SetActive(model: Model)
	self.Active = model
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
		local goalZ = side == "Home" and -self.Length / 2 or self.Length / 2
		local goal = self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 2, goalZ))
		local goalDirection = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z).Unit
		if currentMove.Magnitude > 0.1 then
			return (goalDirection * 0.76 + currentMove.Unit * 0.24).Unit
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
	self.CutsceneKind = kind
	self.CutsceneLocation = location
	self.CutsceneGoalPosition = goalPosition
	self.CutsceneStartedAt = os.clock()
	self.CutsceneUntil = os.clock() + math.clamp(duration, 1, 3)
	if kind == "FreeKick" or kind == "Penalty" then
		self.CutsceneUntil = os.clock() + math.clamp(duration, 1, 60)
	end
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

function Controller:EndCutscene()
	self.CutsceneUntil = nil
	self.CutsceneKind = nil
	self.CutsceneLocation = nil
	self.CutsceneGoalPosition = nil
	self.CutsceneStartedAt = nil
end

function Controller:_desiredFrame(preset: any, targetWorld: Vector3, dynamicZoom: number, longitudinalVelocity: number): CFrame
	if self.CameraPoint and self.CameraPoint.Parent then
		local anchorLocal=self.PitchCFrame:PointToObjectSpace(self.CameraPoint.Position)
		-- The stadium marker owns height and distance from the touchline. The
		-- camera tracks play only along the stand, then tilts toward the ball.
		local trackZ = self.SmoothedTarget.Z + anchorLocal.Z * 0.08 - longitudinalVelocity * 0.035
		local cameraZ=math.clamp(trackZ,-self.Length*.49,self.Length*.49)
		local cameraWorld=self.PitchCFrame:PointToWorldSpace(Vector3.new(anchorLocal.X,anchorLocal.Y,cameraZ))
		return CFrame.lookAt(cameraWorld,targetWorld)
	end
	local height = math.clamp(preset.Height + self.HeightOffset + dynamicZoom * 0.45, 108, 220)
	local side = math.clamp(preset.Side + self.SideOffset + dynamicZoom * 1.2, 132, 260) * self.SideSign
	local cameraX = side + self.SmoothedTarget.X * 0.38
	local cameraZ = self.SmoothedTarget.Z * 0.92 - longitudinalVelocity * 0.05
	local cameraLocal = Vector3.new(cameraX, height, math.clamp(cameraZ, -self.Length * 0.43, self.Length * 0.43))
	local cameraWorld = self.PitchCFrame:PointToWorldSpace(cameraLocal)
	return CFrame.lookAt(cameraWorld, targetWorld)
end

function Controller:_updateCutscene(dt: number): boolean
	if not self.CutsceneUntil or os.clock() >= self.CutsceneUntil then
		self.CutsceneUntil = nil
		self.CutsceneKind = nil
		self.CutsceneLocation = nil
		self.CutsceneGoalPosition = nil
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
				local lineupCenter = presentationGroupCenter({LineupIdle = true})
				local kickoffCenter = presentationGroupCenter({KickoffReady = true})
				local walkingCenter = presentationGroupCenter({WalkForward = true, TunnelIdle = true})
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
					desired = self.PitchCFrame:PointToWorldSpace(Vector3.new(panX, 255, panZ))
				end
				local cameraSmoothing = if not lineupCenter and not kickoffCenter and alpha < .427 then 0.08 else 0.13
				self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, target), 1 - math.exp(-dt / cameraSmoothing))
				self.Camera.FieldOfView += ((alpha < .427 and 68 or alpha < .853 and 63 or 50) - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.16))
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
				cameraLocal=Vector3.new((BROADCAST_SIDE_OFFSET+self.SideOffset)*side,150,self.Length*.04*(1-t))
				targetLocal=Vector3.new(0,3,0)
			end
			local desired = self.PitchCFrame:PointToWorldSpace(cameraLocal)
			local target = self.PitchCFrame:PointToWorldSpace(targetLocal)
			self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, target), 1 - math.exp(-dt / 0.18))
		end
		self.Camera.FieldOfView += (42 - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.2))
		return true
	end
	if kind == "HalfTime" then
		local started = self.CutsceneStartedAt or os.clock()
		local total = math.max(0.1, (self.CutsceneUntil or os.clock()) - started)
		local alpha = math.clamp((os.clock() - started) / total, 0, 1)
		local side = self.SideSign
		local sweep = math.sin(alpha * math.pi * .72) * self.Width * .08
		local cameraLocal = Vector3.new(self.Width * (.92 * side) + sweep, 245, -self.Length * .42 + self.Length * .18 * alpha)
		local targetLocal = Vector3.new(0, 12, -self.Length * .04 + self.Length * .08 * alpha)
		local desired = self.PitchCFrame:PointToWorldSpace(cameraLocal)
		local target = self.PitchCFrame:PointToWorldSpace(targetLocal)
		self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, target), 1 - math.exp(-dt / 0.18))
		self.Camera.FieldOfView += (50 - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.22))
		return true
	end
	if kind == "FreeKick" or kind == "Penalty" then
		local goalLocal = self.CutsceneGoalPosition and self.PitchCFrame:PointToObjectSpace(self.CutsceneGoalPosition)
		local goalZ = goalLocal and goalLocal.Z or ((self.Active and tostring(self.Active:GetAttribute("VTRTeam") or "Home") or "Home") == "Home" and -self.Length * 0.5 or self.Length * 0.5)
		local toGoalSign = goalZ >= localFocus.Z and 1 or -1
		local behind = kind == "Penalty" and 34 or 44
		local height = kind == "Penalty" and 13 or 18
		local cameraLocal = Vector3.new(localFocus.X, localFocus.Y + height, localFocus.Z - toGoalSign * behind)
		local targetLocal = Vector3.new(0, localFocus.Y + (kind == "Penalty" and 3.3 or 5.5), goalZ)
		local desired = self.PitchCFrame:PointToWorldSpace(cameraLocal)
		local target = self.PitchCFrame:PointToWorldSpace(targetLocal)
		self.Camera.CFrame = self.Camera.CFrame:Lerp(CFrame.lookAt(desired, target), 1 - math.exp(-dt / 0.12))
		self.Camera.FieldOfView += ((kind == "Penalty" and 42 or 47) - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.16))
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
	if self.TacticalView then
		self:_updateTactical(dt)
		return
	end
	local root = activeRoot(self.Active)
	if not root or not self.Ball.Parent or self:_updateCutscene(dt) then
		return
	end
	local preset = PRESETS[self.Mode]
	local ballPosition = self.Ball.Position
	if not self.SmoothedLookTarget then
		self.SmoothedLookTarget = ballPosition
	end
	local lookSmoothing = math.clamp(tonumber(workspace:GetAttribute("VTRCameraLookSmoothing")) or BALL_LOOK_SMOOTHING, 0.02, 0.8)
	local maxLookSpeed = math.clamp(tonumber(workspace:GetAttribute("VTRCameraMaxLookSpeed")) or BALL_LOOK_MAX_SPEED, 120, 2400)
	local maxLookLag = math.clamp(tonumber(workspace:GetAttribute("VTRCameraMaxLookLag")) or BALL_LOOK_MAX_LAG, 0.5, 35)
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
	desiredLocal = Vector3.new(math.clamp(desiredLocal.X, -self.Width * 0.44, self.Width * 0.44), 2, math.clamp(desiredLocal.Z, -self.Length * 0.46, self.Length * 0.46))
	local trackingSmooth = math.clamp(tonumber(workspace:GetAttribute("VTRCameraTrackingSmoothing")) or BALL_TRACKING_SMOOTHING, 0.035, 0.5)
	local targetSmooth = math.max(0.045, trackingSmooth / self.SpeedScale)
	local targetAlpha = 1 - math.exp(-dt / targetSmooth)
	self.SmoothedTarget = Vector3.new(
		self.SmoothedTarget.X + (desiredLocal.X - self.SmoothedTarget.X) * targetAlpha,
		2,
		self.SmoothedTarget.Z + (desiredLocal.Z - self.SmoothedTarget.Z) * targetAlpha
	)
	local side = tostring(self.Active:GetAttribute("VTRTeam") or "Home")
	local attackingGoalZ = side == "Home" and -self.Length * 0.5 or self.Length * 0.5
	local distanceToGoal = math.abs(attackingGoalZ - ballLocal.Z)
	local goalLookStart = self.Length * math.clamp(tonumber(workspace:GetAttribute("VTRGoalLookStartFraction")) or GOAL_LOOK_START_FRACTION, 0.22, 0.55)
	local goalLookFull = self.Length * math.clamp(tonumber(workspace:GetAttribute("VTRGoalLookFullFraction")) or GOAL_LOOK_FULL_FRACTION, 0.08, 0.32)
	local goalBlendMax = math.clamp(tonumber(workspace:GetAttribute("VTRGoalLookMaxBlend")) or GOAL_LOOK_MAX_BLEND, 0, 0.68)
	local goalBias = 0
	if goalLookStart > goalLookFull then
		goalBias = smoothStep((goalLookStart - distanceToGoal) / (goalLookStart - goalLookFull)) * goalBlendMax
	end
	local goalLookLocal = Vector3.new(math.clamp(ballLocal.X * 0.42, -self.Width * 0.18, self.Width * 0.18), 2.5, attackingGoalZ)
	local targetWorld = goalBias > 0 and self.PitchCFrame:PointToWorldSpace(ballLocal:Lerp(goalLookLocal, goalBias)) or self.SmoothedLookTarget
	local separation = (activePosition - ballPosition).Magnitude
	local ballSpeed = self.Ball.AssemblyLinearVelocity.Magnitude
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
	local velocityLocal = self.PitchCFrame:VectorToObjectSpace(self.Ball.AssemblyLinearVelocity)
	local desiredFrame = self:_desiredFrame(preset, targetWorld, dynamicZoom, velocityLocal.Z)
	local cameraPositionSmooth = math.clamp(tonumber(workspace:GetAttribute("VTRCameraPositionSmoothing")) or math.max(0.055, preset.Smooth * 0.62 / self.SpeedScale), 0.035, 0.45)
	local cameraAlpha = 1 - math.exp(-dt / cameraPositionSmooth)
	local cameraPosition=self.Camera.CFrame.Position:Lerp(desiredFrame.Position,cameraAlpha)
	self.Camera.CFrame=CFrame.lookAt(cameraPosition,targetWorld,self.PitchCFrame.UpVector)
	local screenPoint,onScreen = self.Camera:WorldToViewportPoint(ballPosition)
	local viewport = self.Camera.ViewportSize
	local offCenter = onScreen and viewport.X > 0 and viewport.Y > 0 and math.max(math.abs(screenPoint.X / viewport.X - 0.5), math.abs(screenPoint.Y / viewport.Y - 0.5)) or 1
	local allowedOffCenter = 0.34 + goalBias * 0.18
	if not onScreen or screenPoint.Z <= 0 or offCenter > allowedOffCenter then
		self.SmoothedLookTarget = self.SmoothedLookTarget:Lerp(ballPosition, 0.72)
		targetWorld = goalBias > 0 and self.PitchCFrame:PointToWorldSpace(ballLocal:Lerp(goalLookLocal, goalBias * 0.55)) or self.SmoothedLookTarget
		self.Camera.CFrame = CFrame.lookAt(cameraPosition, targetWorld, self.PitchCFrame.UpVector)
	end
	local penaltyBox = math.abs(ballLocal.Z) > self.Length * 0.35
	local ballCameraDistance=(desiredFrame.Position-targetWorld).Magnitude
	if not self.ReferenceBallDistance then self.ReferenceBallDistance=ballCameraDistance end
	local runtimeMultiplier=tonumber(workspace:GetAttribute("VTRBallDistanceZoomMultiplier"))or self.BallDistanceZoomMultiplier
	local distanceZoom=-(ballCameraDistance-self.ReferenceBallDistance)*math.clamp(runtimeMultiplier,0,.3)
	local baseFov=tonumber(workspace:GetAttribute("VTRBroadcastFOV"))or preset.Fov
	local fov = math.clamp(baseFov + self.ZoomOffset + dynamicZoom * 0.08 + distanceZoom - (penaltyBox and 1.2 or 0), 28, 52)
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.18))
end

function Controller:GoalCinematic()
	self.GoalTimer = 2.2
end

function Controller:Destroy()
	CameraRelativeMovement.ClearDebug()
	self.Camera.CameraType = Enum.CameraType.Custom
	self.Camera.FieldOfView = 70
end

return Controller
