--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local CardVisualConfig = require(ReplicatedStorage.VTR.Shared.CardVisualConfig)
local PackOpeningConfig = require(ReplicatedStorage.VTR.Shared.PackOpeningConfig)
local WalkoutPresentationConfig = require(ReplicatedStorage.VTR.Shared.WalkoutPresentationConfig)
local WorldCupConfig = require(ReplicatedStorage.VTR.Shared.WorldCupConfig)
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local CardSurface = require(script.Parent.CardSurface)
local WidePlayerCard = require(script.Parent.WidePlayerCard)
local Button = require(script.Parent.Button)
local AvatarPortraitGenerator = require(script.Parent.Parent.Services.AvatarPortraitGenerator)
local WalkoutMotionController = require(script.Parent.Parent.Gameplay.WalkoutMotionController)

local Scene = {}
Scene.__index = Scene
local CAMERA_BIND_PREFIX = "VTRPackWalkoutCamera_"

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function text(parent: Instance, name: string, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font, z: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = value
	item.TextColor3 = color
	item.TextSize = textSize
	item.Font = font
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.TextWrapped = true
	item.ZIndex = z
	item.Parent = parent
	return item
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, role: string?): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.CanCollide = false
	item.CastShadow = role == "Structural" or role == "Floor"
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function structuralPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return part(parent, name, size, cframe, color, material, "Structural")
end

local function floorPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return part(parent, name, size, cframe, color, material, "Floor")
end

local function trimPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	return part(parent, name, size, cframe, color, material, "Trim")
end

local function rating(card: any): number
	return math.floor(tonumber(card and (card.Rating or card.overall or card.Overall)) or 0)
end

local function playerName(card: any): string
	return tostring(card and (card.Name or card.displayName or card.DisplayName) or "VTR PLAYER")
end

local function playerRarity(card: any): string
	return tostring(card and (card.Rarity or card.rarity) or "Starter")
end

local function playerType(card: any): string
	return tostring(card and (card.CardType or card.cardType or "Base") or "Base")
end

local function bright(color: Color3, alpha: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), math.clamp(alpha, 0, 1))
end

local function paletteColor(palette: any, key: string, fallback: Color3): Color3
	local value = palette and palette[key]
	if typeof(value) == "Color3" then return value end
	return fallback
end

local function cardColor(card: any, key: string, fallback: Color3): Color3
	local raw = card and (card[key] or card[string.lower(key)] or card["Club" .. key])
	if typeof(raw) == "Color3" then return raw end
	if type(raw) == "string" and #raw >= 6 then
		local ok, color = pcall(function() return Color3.fromHex(raw:gsub("#", "")) end)
		if ok then return color end
	end
	return fallback
end

local function currentCamera(): Camera
	local camera = workspace.CurrentCamera
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = workspace
		workspace.CurrentCamera = camera
	end
	return camera
end

local function lightingGet(property: string, fallback: any): any
	local ok, value = pcall(function() return (Lighting :: any)[property] end)
	return ok and value or fallback
end

local function lightingSet(property: string, value: any)
	pcall(function() (Lighting :: any)[property] = value end)
end

local function hideLocalCharacter(): { any }
	local player = Players.LocalPlayer
	local character = player and player.Character
	local hidden = {}
	if not character then return hidden end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(hidden, { Object = descendant, LocalTransparencyModifier = descendant.LocalTransparencyModifier })
			descendant.LocalTransparencyModifier = 1
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			table.insert(hidden, { Object = descendant, Transparency = descendant.Transparency })
			descendant.Transparency = 1
		end
	end
	return hidden
end

local function restoreLocalCharacter(hidden: { any }?)
	if not hidden then return end
	for _, item in hidden do
		local object = item.Object
		if typeof(object) == "Instance" and object.Parent then
			if object:IsA("BasePart") then
				object.LocalTransparencyModifier = tonumber(item.LocalTransparencyModifier) or 0
			elseif object:IsA("Decal") or object:IsA("Texture") then
				object.Transparency = tonumber(item.Transparency) or 0
			end
		end
	end
end

local function hideUnderlyingGui(parent: Instance, overlay: Instance): { any }
	local hidden = {}
	if parent:IsA("GuiObject") then
		table.insert(hidden, { Object = parent, Visible = parent.Visible })
		parent.Visible = false
	end
	local overlayParent = overlay.Parent
	if overlayParent then
		for _, child in overlayParent:GetChildren() do
			if child ~= overlay and child:IsA("GuiObject") then
				local alreadyHidden = false
				for _, item in hidden do
					if item.Object == child then alreadyHidden = true;break end
				end
				if alreadyHidden then continue end
				table.insert(hidden, { Object = child, Visible = child.Visible })
				child.Visible = false
			end
		end
	end
	for _, child in parent:GetChildren() do
		if child ~= overlay and child:IsA("GuiObject") and child.Visible then
			table.insert(hidden, { Object = child, Visible = child.Visible })
			child.Visible = false
		end
	end
	return hidden
end

local function normalizeWalkoutRig(model: Model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local rigParts = { [root] = true }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			if descendant.Part0 then rigParts[descendant.Part0] = true end
			if descendant.Part1 then rigParts[descendant.Part1] = true end
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CastShadow = descendant.Name ~= "HumanoidRootPart"
			if descendant.Name == "HumanoidRootPart" then
				descendant.Transparency = WalkoutPresentationConfig.Scene.HumanoidRootTransparency
			end
		end
	end
	for _ = 1, 4 do
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 then
				descendant.Transform = CFrame.identity
				descendant.Part1.CFrame = descendant.Part0.CFrame * descendant.C0 * descendant.C1:Inverse()
			end
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			if not rigParts[descendant] then
				local closest: BasePart? = nil
				local closestDistance = math.huge
				for rigPart in rigParts do
					if typeof(rigPart) == "Instance" and rigPart:IsA("BasePart") and rigPart ~= descendant then
						local distance = (rigPart.Position - descendant.Position).Magnitude
						if distance < closestDistance then
							closest = rigPart
							closestDistance = distance
						end
					end
				end
				if closest then
					local weld = Instance.new("WeldConstraint")
					weld.Name = "WalkoutAttachmentWeld"
					weld.Part0 = closest
					weld.Part1 = descendant
					weld.Parent = descendant
				end
			end
		end
	end
end

function Scene.new(parent: Instance, props: any, selection: any)
	local best = selection.BestCard
	local rarity = playerRarity(best)
	local cardType = playerType(best)
	local visual = CardVisualConfig.Get(rarity, cardType)
	local overlayParent = parent:FindFirstAncestorOfClass("ScreenGui") or parent
	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "PremiumPackOpening"
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 100
	overlay.Active = true
	overlay.Selectable = false
	overlay.Parent = overlayParent
	local shield = Instance.new("TextButton")
	shield.Name = "ModalShield"
	shield.BackgroundTransparency = 1
	shield.BorderSizePixel = 0
	shield.Text = ""
	shield.Modal = true
	shield.AutoButtonColor = false
	shield.Size = UDim2.fromScale(1, 1)
	shield.ZIndex = 101
	shield.Parent = overlay
	local stage = Instance.new("Frame")
	stage.Name = "VoltagePresentationArea"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.BackgroundColor3 = Theme.Colors.Black
	stage.BackgroundTransparency = 1
	stage.BorderSizePixel = 0
	stage.ClipsDescendants = true
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromScale(1, 1)
	stage.ZIndex = 102
	stage.Parent = overlay
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 16 / 9
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = stage
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(1920, 1080)
	maxSize.MinSize = Vector2.new(320, 180)
	maxSize.Parent = stage
	local world = Instance.new("Folder")
	world.Name = "VTRPackWalkoutWorld"
	world.Parent = workspace
	local camera = currentCamera()
	local previousCamera = {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		FieldOfView = camera.FieldOfView,
	}
	local previousLighting = {
		Technology = lightingGet("Technology", nil),
		Ambient = lightingGet("Ambient", Color3.fromRGB(0, 0, 0)),
		OutdoorAmbient = lightingGet("OutdoorAmbient", Color3.fromRGB(0, 0, 0)),
		Brightness = lightingGet("Brightness", 2),
		ColorShift_Top = lightingGet("ColorShift_Top", Color3.fromRGB(0, 0, 0)),
		ColorShift_Bottom = lightingGet("ColorShift_Bottom", Color3.fromRGB(0, 0, 0)),
		ClockTime = lightingGet("ClockTime", 14),
		ExposureCompensation = lightingGet("ExposureCompensation", 0),
		EnvironmentDiffuseScale = lightingGet("EnvironmentDiffuseScale", 0),
		EnvironmentSpecularScale = lightingGet("EnvironmentSpecularScale", 0),
		FogEnd = lightingGet("FogEnd", 100000),
		FogStart = lightingGet("FogStart", 0),
		FogColor = lightingGet("FogColor", Color3.fromRGB(192, 192, 192)),
	}
	local globalLighting = WalkoutPresentationConfig.GlobalLighting
	lightingSet("Technology", Enum.Technology.Future)
	lightingSet("Brightness", globalLighting.Brightness)
	lightingSet("Ambient", globalLighting.Ambient)
	lightingSet("OutdoorAmbient", globalLighting.OutdoorAmbient)
	lightingSet("EnvironmentDiffuseScale", globalLighting.EnvironmentDiffuseScale)
	lightingSet("EnvironmentSpecularScale", globalLighting.EnvironmentSpecularScale)
	lightingSet("ExposureCompensation", globalLighting.ExposureCompensation)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "VTRWalkoutBloom"
	bloom.Intensity = globalLighting.BloomIntensity
	bloom.Size = globalLighting.BloomSize
	bloom.Threshold = globalLighting.BloomThreshold
	bloom.Parent = Lighting
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "VTRWalkoutColorCorrection"
	colorCorrection.Brightness = globalLighting.ColorCorrectionBrightness
	colorCorrection.Contrast = globalLighting.ColorCorrectionContrast
	colorCorrection.Saturation = globalLighting.ColorCorrectionSaturation
	colorCorrection.TintColor = Color3.fromRGB(225, 240, 220)
	colorCorrection.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "VTRWalkoutAtmosphere"
	atmosphere.Density = globalLighting.AtmosphereDensity
	atmosphere.Offset = 0.08
	atmosphere.Color = Color3.fromRGB(30, 42, 25)
	atmosphere.Decay = Color3.fromRGB(5, 8, 5)
	atmosphere.Glare = 0.05
	atmosphere.Haze = globalLighting.AtmosphereHaze
	atmosphere.Parent = Lighting
	local cameraBindName = CAMERA_BIND_PREFIX .. tostring(os.clock()):gsub("%.", "_")
	local cameraCFrameValue = Instance.new("CFrameValue")
	cameraCFrameValue.Name = "WalkoutCameraCFrame"
	local startShot = WalkoutPresentationConfig.Shots.Start
	cameraCFrameValue.Value = CFrame.lookAt(startShot.Position, startShot.Target)
	cameraCFrameValue.Parent = world
	local cameraFOVValue = Instance.new("NumberValue")
	cameraFOVValue.Name = "WalkoutCameraFOV"
	cameraFOVValue.Value = startShot.FOV
	cameraFOVValue.Parent = world
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cameraCFrameValue.Value
	camera.FieldOfView = cameraFOVValue.Value
	local self = setmetatable({
		Overlay = overlay,
		Stage = stage,
		World = world,
		Camera = camera,
		CameraBindName = cameraBindName,
		CameraCFrameValue = cameraCFrameValue,
		CameraFOVValue = cameraFOVValue,
		PreviousCamera = previousCamera,
		PreviousLighting = previousLighting,
		WalkoutPostEffects = { bloom, colorCorrection, atmosphere },
		HiddenGui = nil,
		HiddenCharacter = nil,
		WorldSceneActive = true,
		Props = props,
		Selection = selection,
		Best = best,
		Visual = visual,
		Palette = PackOpeningConfig.PaletteForCard(best),
		PremiumEffects = selection.Profile and selection.Profile.Walkout == true and rating(best) >= PackOpeningConfig.PremiumWalkoutMinimumRating,
		SuperEffects = rating(best) >= PackOpeningConfig.SuperWalkoutMinimumRating or tostring(cardType) == "Mythic" or tostring(cardType) == "Storm",
		Nodes = {},
		RunwayNodes = {},
		OverheadNodes = {},
		LightningNodes = {},
		SparkNodes = {},
		ConfettiNodes = {},
		SmokeNodes = {},
		PyroNodes = {},
		Tweens = {},
		Connections = {},
		Motion = nil,
		OnResultsContinue = nil,
		Destroyed = false,
	}, Scene)
	RunService:BindToRenderStep(cameraBindName, Enum.RenderPriority.Camera.Value + 100, function()
		local activeCamera = currentCamera()
		activeCamera.CameraType = Enum.CameraType.Scriptable
		activeCamera.CFrame = cameraCFrameValue.Value
		activeCamera.FieldOfView = cameraFOVValue.Value
		self.Camera = activeCamera
	end)
	self:_buildTunnel()
	self:_buildOverlays()
	self:_buildPack()
	if selection.Profile and selection.Profile.AvatarPhase == true then
		self:_buildAvatar()
	end
	self.HiddenGui = hideUnderlyingGui(parent, overlay)
	self.HiddenCharacter = hideLocalCharacter()
	TweenService:Create(overlay, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
	return self
end

function Scene:_trackTween(tween: Tween)
	table.insert(self.Tweens, tween)
	tween:Play()
	return tween
end

function Scene:_trackConnection(connection: RBXScriptConnection)
	table.insert(self.Connections, connection)
	return connection
end

function Scene:_cameraTo(position: Vector3, target: Vector3, fov: number, duration: number)
	if self.CameraCFrameValue and self.CameraFOVValue then
		self:_trackTween(TweenService:Create(self.CameraCFrameValue, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = CFrame.lookAt(position, target) }))
		self:_trackTween(TweenService:Create(self.CameraFOVValue, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = fov }))
	else
		self:_trackTween(TweenService:Create(self.Camera, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(position, target), FieldOfView = fov }))
	end
end

function Scene:_cameraShot(name: string, durationOverride: number?)
	local shot = WalkoutPresentationConfig.Shots[name]
	if not shot then return end
	self:_cameraTo(shot.Position, shot.Target, shot.FOV, durationOverride or shot.Duration or 0.45)
end

function Scene:_tweenModelPivot(model: Model, target: CFrame, info: TweenInfo)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Parent = model
	self:_trackConnection(value.Changed:Connect(function(nextPivot)
		if model.Parent then model:PivotTo(nextPivot) end
	end))
	local tween = self:_trackTween(TweenService:Create(value, info, { Value = target }))
	tween.Completed:Once(function()
		if value.Parent then value:Destroy() end
	end)
	return tween
end

function Scene:_setGuiBolt(segment: Frame, a: Vector2, b: Vector2, color: Color3, thickness: number)
	local mid = (a + b) * 0.5
	local delta = b - a
	segment.Position = UDim2.fromScale(mid.X, mid.Y)
	segment.Size = UDim2.fromOffset(thickness, math.max(12, delta.Magnitude * math.min(self.Stage.AbsoluteSize.X, self.Stage.AbsoluteSize.Y)))
	segment.Rotation = math.deg(math.atan2(delta.Y, delta.X)) - 90
	segment.BackgroundColor3 = color
	segment.BackgroundTransparency = 0
end

function Scene:_pulseLightning(points: {Vector2}, strength: number, hold: number?)
	if self.Selection.ReducedMotion and strength < 0.95 then return end
	local count = math.min(#self.LightningNodes, math.max(0, #points - 1))
	for index = 1, count do
		local segment = self.LightningNodes[index]
		local accent = paletteColor(self.Palette, "Accent", self.Visual.glowColor)
		local secondary = paletteColor(self.Palette, "Secondary", WalkoutPresentationConfig.Colors.Voltra)
		self:_setGuiBolt(segment, points[index], points[index + 1], index % 2 == 0 and accent or bright(secondary, 0.2), 2 + strength * 4)
		self:_trackTween(TweenService:Create(segment, TweenInfo.new(hold or 0.22), { BackgroundTransparency = 1 }))
	end
end

function Scene:_burstSparks(center: Vector2, radius: number, strength: number)
	local limit = self.Selection.ReducedMotion and 8 or #self.SparkNodes
	for index = 1, limit do
		local spark = self.SparkNodes[index]
		local angle = index * 2.399
		local distance = radius * (0.35 + (index % 7) / 7) * strength
		spark.Position = UDim2.fromScale(center.X, center.Y)
		spark.BackgroundTransparency = 0
		self:_trackTween(TweenService:Create(spark, TweenInfo.new(0.28 + (index % 5) * 0.035, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(center.X + math.cos(angle) * distance, center.Y + math.sin(angle) * distance),
			BackgroundTransparency = 1,
		}))
	end
end

function Scene:PulseLightning(strength: number, origin: Vector2?, target: Vector2?)
	local a = origin or Vector2.new(0.34, 0.3)
	local b = target or Vector2.new(0.52, 0.48)
	local points = { a }
	for index = 1, 4 do
		local t = index / 5
		local p = a:Lerp(b, t)
		table.insert(points, p + Vector2.new(((index % 2) * 2 - 1) * 0.025 * strength, (index % 3 - 1) * 0.025 * strength))
	end
	table.insert(points, b)
	self:_pulseLightning(points, strength)
end

function Scene:BurstAroundPack(strength: number)
	self:PulseLightning(strength, Vector2.new(0.38, 0.32), Vector2.new(0.55, 0.55))
	self:PulseLightning(strength, Vector2.new(0.62, 0.33), Vector2.new(0.46, 0.58))
	self:_burstSparks(Vector2.new(0.5, 0.49), 0.18, strength)
end

function Scene:BurstBehindPlayer(strength: number)
	self:PulseLightning(strength, Vector2.new(0.41, 0.18), Vector2.new(0.55, 0.62))
	self:PulseLightning(strength, Vector2.new(0.58, 0.2), Vector2.new(0.45, 0.62))
	self:_burstSparks(Vector2.new(0.5, 0.42), 0.12, strength)
end

function Scene:PulseRunway(strength: number)
	self:PulseLightning(strength, Vector2.new(0.42, 0.72), Vector2.new(0.58, 0.7))
	self:_burstSparks(Vector2.new(0.5, 0.72), 0.1, strength)
end

function Scene:FirePyro(strength: number)
	if not self.PremiumEffects or PackOpeningConfig.PremiumPyroEnabled ~= true then return end
	local accent = paletteColor(self.Palette, "Accent", self.Visual.glowColor)
	local secondary = paletteColor(self.Palette, "Secondary", Color3.new(1, 1, 1))
	for index, node in self.PyroNodes do
		if node.Parent then
			node.Color = index % 2 == 0 and accent or secondary
			node.Size = Vector3.new(0.18, 0.2, 0.18)
			node.Transparency = 0.1
			self:_trackTween(TweenService:Create(node, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.28, 4.6 + strength * 2.4, 0.28), Transparency = 0.28 }))
			task.delay(0.2, function()
				if node.Parent then self:_trackTween(TweenService:Create(node, TweenInfo.new(0.34, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Size = Vector3.new(0.16, 0.35, 0.16), Transparency = 1 })) end
			end)
		end
	end
end

function Scene:DriftSmoke(strength: number)
	if not self.PremiumEffects or PackOpeningConfig.PremiumSmokeEnabled ~= true then return end
	for index, haze in self.SmokeNodes do
		if haze.Parent then
			haze.Transparency = 0.86
			self:_trackTween(TweenService:Create(haze, TweenInfo.new(1.6 + index * 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				CFrame = haze.CFrame * CFrame.new((index % 2 == 0 and 1 or -1) * strength * 0.9, 0, strength * 1.6),
				Transparency = 0.94,
			}))
		end
	end
end

function Scene:ReleaseConfetti(strength: number)
	if not self.PremiumEffects or PackOpeningConfig.PremiumConfettiEnabled ~= true then return end
	local count = self.SuperEffects and #self.ConfettiNodes or math.min(#self.ConfettiNodes, 18)
	for index = 1, count do
		local confetti = self.ConfettiNodes[index]
		local x = 0.22 + ((index * 37) % 58) / 100
		local drift = ((index % 5) - 2) * 0.028 * strength
		confetti.Position = UDim2.fromScale(x, -0.03)
		confetti.BackgroundTransparency = 0
		confetti.Rotation = index * 27
		self:_trackTween(TweenService:Create(confetti, TweenInfo.new(1.15 + (index % 6) * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(x + drift, 0.58 + ((index * 19) % 32) / 100),
			Rotation = confetti.Rotation + 180 + index * 9,
			BackgroundTransparency = 1,
		}))
	end
end

function Scene:RatingImpact(strength: number)
	self:PulseLightning(strength, Vector2.new(0.48, 0.22), Vector2.new(0.82, 0.5))
	self:_burstSparks(Vector2.new(0.78, 0.5), 0.16, strength)
	local limit = tonumber(self.Selection.Profile.FlashLimit) or 0.2
	self.Flash.BackgroundColor3 = bright(paletteColor(self.Palette, "Accent", self.Visual.glowColor), 0.35)
	self.Flash.BackgroundTransparency = 1 - math.min(limit, 0.18 + strength * 0.08)
	self:_trackTween(TweenService:Create(self.Flash, TweenInfo.new(0.26), { BackgroundTransparency = 1 }))
	if self.HeroCardStroke then
		self.HeroCardStroke.Color = paletteColor(self.Palette, "Accent", self.Visual.glowColor)
		self:_trackTween(TweenService:Create(self.HeroCardStroke, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 0.04 }))
		task.delay(0.24, function()
			if self.HeroCardStroke and self.HeroCardStroke.Parent then self:_trackTween(TweenService:Create(self.HeroCardStroke, TweenInfo.new(0.32), { Transparency = 0.42 })) end
		end)
	end
end

function Scene:SetLightingPhase(name: string)
	local phase = WalkoutPresentationConfig.LightingPhases[name] or WalkoutPresentationConfig.LightingPhases.TunnelIgnition
	local voltra = WalkoutPresentationConfig.Colors.Voltra
	self:_trackTween(TweenService:Create(Lighting, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Ambient = phase.Ambient,
		OutdoorAmbient = phase.Ambient:Lerp(Color3.fromRGB(2, 3, 2), 0.62),
		Brightness = self.PremiumEffects and 1.18 or 1.02,
		ColorShift_Top = phase.LightColor:Lerp(voltra, self.PremiumEffects and 0.08 or 0.04),
		ColorShift_Bottom = Color3.fromRGB(5, 8, 6),
		ExposureCompensation = self.PremiumEffects and -0.3 or -0.4,
		FogColor = Color3.fromRGB(5, 9, 6),
		FogStart = 22,
		FogEnd = 135,
	}))
	for _, bank in self.OverheadNodes do
		if bank.Parent then self:_trackTween(TweenService:Create(bank, TweenInfo.new(0.28), { Transparency = 0.78 - math.clamp(phase.Light, 0, 1) * 0.34 })) end
	end
end

function Scene:Blackout()
	self:SetLightingPhase(self.Selection.ReducedMotion and "RatingReveal" or "Blackout")
	for _, node in self.RunwayNodes do
		if node.Parent then node.Transparency = 0.58 end
	end
	if self.Selection.ReducedMotion then
		if self.Pack then self.Pack:PivotTo(CFrame.new(WalkoutPresentationConfig.PackEntrance().Finish)) end
		for _, node in self.Nodes do if node.Parent then node.Transparency = 0.2 end end
		for _, node in self.RunwayNodes do if node.Parent then node.Transparency = 0.14 end end
	end
end

function Scene:EnterPack()
	if not self.Pack then return end
	self:SetLightingPhase("PackEntrance")
	local entrance = WalkoutPresentationConfig.PackEntrance()
	self:_tweenModelPivot(self.Pack, CFrame.new(entrance.Finish), TweenInfo.new(0.52, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
	if self.PackPedestal then
		self:_trackTween(TweenService:Create(self.PackPedestal, TweenInfo.new(0.42), { Transparency = 0.24 }))
	end
	self:_cameraShot("PackEntrance")
	self:PulseRunway(0.7)
end

function Scene:HideCluePanel()
	if self.CluePanel and self.CluePanel.Parent then
		self:_trackTween(TweenService:Create(self.CluePanel, TweenInfo.new(0.16), { GroupTransparency = 1 }))
	end
end

function Scene:SetHeroLighting()
	self:SetLightingPhase("RatingReveal")
	self:RatingImpact(0.8)
	self:DriftSmoke(0.65)
	self:ReleaseConfetti(self.SuperEffects and 1.15 or 0.85)
end

function Scene:_buildTunnel()
	local main = Color3.fromRGB(165, 255, 0)
	local soft = Color3.fromRGB(125, 205, 20)
	local white = Color3.fromRGB(235, 240, 235)
	local wall = Color3.fromRGB(9, 11, 10)
	local panel = Color3.fromRGB(17, 20, 18)
	local metal = Color3.fromRGB(38, 43, 39)
	local floor = Color3.fromRGB(12, 14, 13)
	local portalX = tonumber(WalkoutPresentationConfig.Scene.PortalX) or 0
	local function folder(parent: Instance, name: string): Folder
		local item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
		return item
	end
	local room = folder(self.World, "WalkoutRoom")
	local architecture = folder(room, "Architecture")
	local floorFolder = folder(architecture, "Floor")
	local leftWall = folder(architecture, "LeftWall")
	local rightWall = folder(architecture, "RightWall")
	local ceiling = folder(architecture, "Ceiling")
	local revealDoor = folder(architecture, "RevealDoor")
	local podiumFolder = folder(room, "Podium")
	local branding = folder(room, "Branding")
	local lightingFolder = folder(room, "Lighting")
	local staticLights = folder(lightingFolder, "StaticLights")
	local revealLights = folder(lightingFolder, "RevealLights")
	local effects = folder(room, "Effects")
	local smokeFolder = folder(effects, "Smoke")
	local beamFolder = folder(effects, "Beams")
	local particleFolder = folder(effects, "Particles")
	local animationGroups = folder(room, "AnimationGroups")
	folder(animationGroups, "FloorSequence")
	folder(animationGroups, "WallSequence")
	folder(animationGroups, "DoorSequence")
	folder(animationGroups, "PodiumSequence")
	local function make(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, transparency: number?, reflectance: number?): Part
		local isNeon = material == Enum.Material.Neon
		local isEffect = name:find("Particle") ~= nil or name:find("Smoke") ~= nil or name:find("Pyro") ~= nil or name:find("Beam") ~= nil
		local isFloor = parent == floorFolder or name:find("Floor") ~= nil or name:find("Walkway") ~= nil or name:find("Platform") ~= nil
		local item = isFloor and floorPart(parent, name, size, cframe, color, material)
			or isNeon and trimPart(parent, name, size, cframe, color, material)
			or isEffect and trimPart(parent, name, size, cframe, color, material)
			or structuralPart(parent, name, size, cframe, color, material)
		item.Transparency = transparency or 0
		item.Reflectance = reflectance or 0
		return item
	end
	local function addSurfaceLight(parent: BasePart, face: Enum.NormalId, color: Color3, brightness: number, range: number, angle: number?)
		local light = Instance.new("SurfaceLight")
		pcall(function() light.Face = face end)
		pcall(function() light.Color = color end)
		pcall(function() light.Brightness = brightness end)
		pcall(function() light.Range = range end)
		pcall(function() (light :: any).Angle = angle or 95 end)
		pcall(function() light.Shadows = true end)
		light.Parent = parent
		return light
	end
	local function addSpot(parent: BasePart, face: Enum.NormalId, color: Color3, brightness: number, range: number, angle: number)
		local light = Instance.new("SpotLight")
		pcall(function() light.Face = face end)
		pcall(function() light.Color = color end)
		pcall(function() light.Brightness = brightness end)
		pcall(function() light.Range = range end)
		pcall(function() light.Angle = angle end)
		pcall(function() light.Shadows = true end)
		light.Parent = parent
		return light
	end
	local runwayY = WalkoutPresentationConfig.Scene.RunwayY
	local surfaceY = WalkoutPresentationConfig.SurfaceY("Runway")
	make(floorFolder, "DarkReflectiveWalkway", Vector3.new(48, 0.28, 110), CFrame.new(0, runwayY, -4), floor, Enum.Material.SmoothPlastic, 0, 0.2)
	make(floorFolder, "CenterWalkingLane", Vector3.new(15.5, 0.035, 94), CFrame.new(0, surfaceY + 0.02, -3), Color3.fromRGB(18, 21, 19), Enum.Material.Metal, 0.03, 0.32)
	for index = 1, 11 do
		local z = -44 + index * 8
		make(floorFolder, "FloorPanelSeam" .. index, Vector3.new(43, 0.04, 0.06), CFrame.new(0, surfaceY + 0.04, z), metal, Enum.Material.Metal, 0.35, 0.08)
	end
	for index, z in {-43, -33, -23, -13, -3, 7, 17, 27} do
		for _, side in {-1, 1} do
			local strip = make(floorFolder, "BrokenLimeGuide" .. index .. (side < 0 and "L" or "R"), Vector3.new(0.16, 0.07, 4.5), CFrame.new(side * 5.65, surfaceY + 0.06, z), main, Enum.Material.Neon, 0.48)
			table.insert(self.RunwayNodes, strip)
		end
	end
	make(floorFolder, "ForegroundVTRLogoA", Vector3.new(5.2, 0.08, 0.55), CFrame.new(-1.6, surfaceY + 0.075, -29) * CFrame.Angles(0, math.rad(-16), 0), main, Enum.Material.Neon, 0.55)
	make(floorFolder, "ForegroundVTRLogoB", Vector3.new(5.2, 0.08, 0.55), CFrame.new(1.6, surfaceY + 0.075, -29) * CFrame.Angles(0, math.rad(16), 0), main, Enum.Material.Neon, 0.55)
	local stageBase = make(floorFolder, "RaisedCentralPlatform", Vector3.new(18, 0.45, 10), CFrame.new(0, WalkoutPresentationConfig.Scene.StageY, 13), Color3.fromRGB(18, 21, 19), Enum.Material.Metal, 0, 0.24)
	make(floorFolder, "PlatformWhiteFrontLip", Vector3.new(16.5, 0.08, 0.12), CFrame.new(0, WalkoutPresentationConfig.SurfaceY("Stage") + 0.05, 8.1), white, Enum.Material.Neon, 0.55)
	make(floorFolder, "PlatformLimeRearLip", Vector3.new(13, 0.08, 0.14), CFrame.new(0, WalkoutPresentationConfig.SurfaceY("Stage") + 0.06, 17.2), main, Enum.Material.Neon, 0.5)
	addSurfaceLight(stageBase, Enum.NormalId.Top, soft, 0.25, 8)
	for _, side in {-1, 1} do
		local wallFolder = side < 0 and leftWall or rightWall
		make(wallFolder, "OuterTunnelWall", Vector3.new(0.55, 30, 110), CFrame.new(side * 24, 12.6, -4), wall, Enum.Material.SmoothPlastic)
		make(wallFolder, "LowerWallRail", Vector3.new(0.8, 1.2, 108), CFrame.new(side * 23.42, -0.6, -4), metal, Enum.Material.Metal)
		for section = 1, 6 do
			local z = -42 + section * 14
			make(wallFolder, "RecessedPanel" .. section, Vector3.new(0.28, 16.5, 8.6), CFrame.new(side * 23.05, 6.7, z), panel, Enum.Material.Metal, 0.04, 0.06)
			make(wallFolder, "PanelFrameTop" .. section, Vector3.new(0.38, 0.18, 8.9), CFrame.new(side * 22.86, 15.05, z), metal, Enum.Material.Metal)
			make(wallFolder, "PanelFrameBottom" .. section, Vector3.new(0.38, 0.18, 8.9), CFrame.new(side * 22.86, -1.45, z), metal, Enum.Material.Metal)
			local strip = make(wallFolder, "VerticalLimeStrip" .. section, Vector3.new(0.12, 9.2, 0.2), CFrame.new(side * 22.7, 5.3, z - 2.9), main, Enum.Material.Neon, 0.5)
			addSurfaceLight(strip, side < 0 and Enum.NormalId.Right or Enum.NormalId.Left, soft, 0.38, 8)
			table.insert(self.Nodes, strip)
			for dot = 1, 3 do
				make(wallFolder, "Perforation" .. section .. "_" .. dot, Vector3.new(0.08, 0.08, 0.08), CFrame.new(side * 22.66, 10.2 - dot * 1.05, z + 2.9), dot % 2 == 0 and soft or metal, dot % 2 == 0 and Enum.Material.Neon or Enum.Material.Metal, dot % 2 == 0 and 0.72 or 0.12)
			end
			for chevron = 1, 2 do
				local y = 8.7 - chevron * 1.05
				make(wallFolder, "VTRChevronA" .. section .. "_" .. chevron, Vector3.new(0.12, 0.85, 0.12), CFrame.new(side * 22.58, y, z + 1.4) * CFrame.Angles(0, 0, math.rad(side * 34)), main, Enum.Material.Neon, 0.38)
				make(wallFolder, "VTRChevronB" .. section .. "_" .. chevron, Vector3.new(0.12, 0.85, 0.12), CFrame.new(side * 22.58, y, z + 1.78) * CFrame.Angles(0, 0, math.rad(side * -34)), main, Enum.Material.Neon, 0.38)
			end
		end
	end
	make(ceiling, "BlackCeilingPanel", Vector3.new(48, 0.55, 110), CFrame.new(0, 27.8, -4), Color3.fromRGB(5, 7, 6), Enum.Material.SmoothPlastic)
	for index, z in {-42, -30, -18, -6, 6, 18, 30} do
		make(ceiling, "CrossBeam" .. index, Vector3.new(48, 1.1, 0.85), CFrame.new(0, 26.7, z), Color3.fromRGB(16, 18, 16), Enum.Material.Metal)
		local whiteBar = make(ceiling, "NarrowWhiteCeilingLight" .. index, Vector3.new(8, 0.12, 0.18), CFrame.new(0, 26.05, z + 1.9), white, Enum.Material.Neon, 0.58)
		addSurfaceLight(whiteBar, Enum.NormalId.Bottom, white, 0.34, 9)
		table.insert(self.OverheadNodes, whiteBar)
	end
	for _, side in {-1, 1} do
		local spotMount = make(staticLights, "FrontSoftSpotMount" .. (side < 0 and "L" or "R"), Vector3.new(0.7, 0.7, 0.7), CFrame.new(side * 16.5, 25.3, -35) * CFrame.Angles(math.rad(-38), math.rad(side * 18), 0), metal, Enum.Material.Metal)
		addSpot(spotMount, Enum.NormalId.Front, Color3.fromRGB(190, 230, 120), 0.75, 36, 30)
	end
	make(revealDoor, "BackWallGraphite", Vector3.new(48, 30, 0.9), CFrame.new(0, 12.7, 51), wall, Enum.Material.SmoothPlastic)
	local doorCore = make(revealDoor, "RecessedDarkDoorCore", Vector3.new(20, 18, 0.18), CFrame.new(portalX, 8.1, WalkoutPresentationConfig.Scene.PortalZ + 0.14), Color3.fromRGB(4, 6, 5), Enum.Material.Glass, 0.1, 0.18)
	local portalGlow = make(revealDoor, "PlayerPortalGlow", Vector3.new(19.2, 17.1, 0.16), CFrame.new(portalX, 8.1, WalkoutPresentationConfig.Scene.PortalZ + 0.22), soft, Enum.Material.Neon, 0.78)
	self.PortalGlow = portalGlow
	local portalCore = make(revealDoor, "PlayerPortalCore", Vector3.new(15.6, 13.7, 0.12), CFrame.new(portalX, 8.1, WalkoutPresentationConfig.Scene.PortalZ + 0.08), Color3.fromRGB(80, 120, 55), Enum.Material.Glass, 0.72, 0.14)
	local portalWhite = make(revealDoor, "PortalWhiteBacklight", Vector3.new(9.5, 9.2, 0.1), CFrame.new(portalX, 8.1, WalkoutPresentationConfig.Scene.PortalZ + 0.02), white, Enum.Material.Neon, 0.9)
	addSurfaceLight(portalWhite, Enum.NormalId.Front, white, 0.9, 14)
	local portalTop = make(revealDoor, "DoorThinLimeTop", Vector3.new(20.5, 0.16, 0.2), CFrame.new(portalX, 17.25, WalkoutPresentationConfig.Scene.PortalZ - 0.22), main, Enum.Material.Neon, 0.28)
	local portalBottom = make(revealDoor, "DoorThinLimeBottom", Vector3.new(20.5, 0.16, 0.2), CFrame.new(portalX, -1.05, WalkoutPresentationConfig.Scene.PortalZ - 0.22), main, Enum.Material.Neon, 0.34)
	local portalLeft = make(revealDoor, "DoorThinLimeLeft", Vector3.new(0.16, 18.2, 0.2), CFrame.new(portalX - 10.25, 8.1, WalkoutPresentationConfig.Scene.PortalZ - 0.22), main, Enum.Material.Neon, 0.28)
	local portalRight = make(revealDoor, "DoorThinLimeRight", Vector3.new(0.16, 18.2, 0.2), CFrame.new(portalX + 10.25, 8.1, WalkoutPresentationConfig.Scene.PortalZ - 0.22), main, Enum.Material.Neon, 0.28)
	make(revealDoor, "DoorOuterFrameTop", Vector3.new(23.4, 1.1, 0.65), CFrame.new(portalX, 18.05, WalkoutPresentationConfig.Scene.PortalZ - 0.28), Color3.fromRGB(6, 7, 6), Enum.Material.Metal)
	make(revealDoor, "DoorOuterFrameBottom", Vector3.new(23.4, 1.1, 0.65), CFrame.new(portalX, -1.8, WalkoutPresentationConfig.Scene.PortalZ - 0.28), Color3.fromRGB(6, 7, 6), Enum.Material.Metal)
	make(revealDoor, "DoorOuterFrameLeft", Vector3.new(1.1, 20.3, 0.65), CFrame.new(portalX - 11.7, 8.1, WalkoutPresentationConfig.Scene.PortalZ - 0.28), Color3.fromRGB(6, 7, 6), Enum.Material.Metal)
	make(revealDoor, "DoorOuterFrameRight", Vector3.new(1.1, 20.3, 0.65), CFrame.new(portalX + 11.7, 8.1, WalkoutPresentationConfig.Scene.PortalZ - 0.28), Color3.fromRGB(6, 7, 6), Enum.Material.Metal)
	make(revealDoor, "DoorWhiteInnerTop", Vector3.new(15, 0.1, 0.16), CFrame.new(portalX, 16.25, WalkoutPresentationConfig.Scene.PortalZ - 0.38), white, Enum.Material.Neon, 0.58)
	self.PortalNodes = { portalGlow, portalCore, portalWhite, portalTop, portalBottom, portalLeft, portalRight }
	local headerPanel = make(branding, "IntegratedHeaderPanel", Vector3.new(25.5, 4.8, 0.38), CFrame.new(portalX, 21.7, WalkoutPresentationConfig.Scene.PortalZ - 0.6), Color3.fromRGB(7, 9, 8), Enum.Material.Metal)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "HeroHoldHeaderGui"
	surfaceGui.Adornee = headerPanel
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(900, 300)
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = headerPanel
	local logo = text(surfaceGui, "VTRLogo", "VTR", UDim2.fromScale(0.36, 0.02), UDim2.fromScale(0.28, 0.32), 74, main, Theme.Fonts.Display, 1)
	logo.TextXAlignment = Enum.TextXAlignment.Center
	local hero = text(surfaceGui, "HeroHoldTitle", "HERO HOLD", UDim2.fromScale(0.32, 0.36), UDim2.fromScale(0.36, 0.22), 38, white, Theme.Fonts.Display, 1)
	hero.TextXAlignment = Enum.TextXAlignment.Center
	local barFrame = Instance.new("Frame")
	barFrame.Name = "RevealProgressBar"
	barFrame.BackgroundColor3 = main
	barFrame.BackgroundTransparency = 0.22
	barFrame.BorderSizePixel = 0
	barFrame.Position = UDim2.fromScale(0.33, 0.74)
	barFrame.Size = UDim2.fromScale(0.34, 0.035)
	barFrame.Parent = surfaceGui
	make(podiumFolder, "PodiumBase", Vector3.new(12, 1.5, 7), CFrame.new(0, 0.05, 18.5), Color3.fromRGB(8, 10, 9), Enum.Material.Metal, 0, 0.2)
	make(podiumFolder, "PodiumBaseTop", Vector3.new(13.3, 0.35, 8.2), CFrame.new(0, 1.02, 18.5), Color3.fromRGB(30, 34, 31), Enum.Material.Metal, 0.02, 0.26)
	make(podiumFolder, "MainPedestal", Vector3.new(7, 8, 4), CFrame.new(0, 5.1, 18.5), Color3.fromRGB(9, 11, 10), Enum.Material.Metal, 0, 0.18)
	make(podiumFolder, "PedestalInset", Vector3.new(5.5, 5.8, 0.18), CFrame.new(0, 5.45, 16.4), Color3.fromRGB(15, 18, 16), Enum.Material.SmoothPlastic)
	make(podiumFolder, "PedestalFrontVTRMarkA", Vector3.new(2.9, 0.18, 0.16), CFrame.new(-0.65, 5.3, 16.25) * CFrame.Angles(0, 0, math.rad(38)), main, Enum.Material.Neon, 0.28)
	make(podiumFolder, "PedestalFrontVTRMarkB", Vector3.new(2.9, 0.18, 0.16), CFrame.new(0.65, 5.3, 16.25) * CFrame.Angles(0, 0, math.rad(-38)), main, Enum.Material.Neon, 0.28)
	for _, side in {-1, 1} do
		local edge = make(podiumFolder, "PodiumLimeEdge" .. (side < 0 and "L" or "R"), Vector3.new(0.16, 8.2, 0.16), CFrame.new(side * 3.62, 5.1, 16.38), main, Enum.Material.Neon, 0.38)
		table.insert(self.Nodes, edge)
		local pyro = make(particleFolder, "PyroFountain" .. (side < 0 and "L" or "R"), Vector3.new(0.18, 0.2, 0.18), CFrame.new(side * 7.2, WalkoutPresentationConfig.SurfaceY("Stage") + 0.15, 16), soft, Enum.Material.Neon, 1)
		table.insert(self.PyroNodes, pyro)
	end
	for index = 1, 5 do
		local haze = make(smokeFolder, "ControlledDoorSmoke" .. index, Vector3.new(4 + index * 0.4, 0.05, 1.4), CFrame.new((index - 3) * 2.7 + portalX, WalkoutPresentationConfig.SurfaceY("Runway") + 0.08, 27 + index * 0.45), soft, Enum.Material.Neon, 0.96)
		table.insert(self.SmokeNodes, haze)
	end
	for _, side in {-1, 1} do
		local emitterPart = make(particleFolder, "FaintWallParticles" .. (side < 0 and "L" or "R"), Vector3.new(0.2, 0.2, 0.2), CFrame.new(side * 22.4, 9, 4), main, Enum.Material.Neon, 1)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(main, soft)
		emitter.LightEmission = 0.18
		emitter.Rate = 3
		emitter.Lifetime = NumberRange.new(2.2, 4.8)
		emitter.Speed = NumberRange.new(0.1, 0.4)
		emitter.SpreadAngle = Vector2.new(18, 18)
		emitter.Size = NumberSequence.new(0.08, 0.02)
		emitter.Transparency = NumberSequence.new(0.55, 1)
		emitter.Parent = emitterPart
	end
	for _, side in {-1, 1} do
		local beamPart = make(beamFolder, "ControlledGreenBeam" .. (side < 0 and "L" or "R"), Vector3.new(0.22, 0.22, 0.22), CFrame.new(side * 10, 24.2, 30), main, Enum.Material.Neon, 1)
		addSpot(beamPart, Enum.NormalId.Bottom, soft, 0.9, 30, 20)
		table.insert(self.OverheadNodes, beamPart)
	end
	if RunService:IsStudio() then
		local budget = PackOpeningConfig.EffectBudget
		local parts = 0
		local lights = 0
		for _, descendant in room:GetDescendants() do
			if descendant:IsA("BasePart") then parts += 1 end
			if descendant:IsA("Light") then lights += 1 end
		end
		if parts > (tonumber(budget.Max3DParts) or math.huge) then warn(("[PackWalkout] room part budget exceeded: %d"):format(parts)) end
		if lights > (tonumber(budget.MaxLightBars) or math.huge) then warn(("[PackWalkout] room light budget exceeded: %d"):format(lights)) end
		if #self.SparkNodes > (tonumber(budget.MaxSparkNodes) or math.huge) then warn(("[PackWalkout] spark budget exceeded: %d"):format(#self.SparkNodes)) end
	end
end

function Scene:_buildOverlays()
	local visual = self.Visual
	if self.PremiumEffects then
		local bloom = Instance.new("Frame")
		bloom.Name = "PremiumBloomWash"
		bloom.BackgroundColor3 = paletteColor(self.Palette, "Main", WalkoutPresentationConfig.Colors.Voltra)
		bloom.BackgroundTransparency = 0.9
		bloom.BorderSizePixel = 0
		bloom.Size = UDim2.fromScale(1, 1)
		bloom.ZIndex = 111
		bloom.Parent = self.Stage
		local bloomGradient = Instance.new("UIGradient")
		bloomGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, paletteColor(self.Palette, "Main", WalkoutPresentationConfig.Colors.Voltra)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFFFFF")),
			ColorSequenceKeypoint.new(1, paletteColor(self.Palette, "Accent", visual.glowColor)),
		})
		bloomGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.76),
			NumberSequenceKeypoint.new(0.5, 0.94),
			NumberSequenceKeypoint.new(1, 0.78),
		})
		bloomGradient.Rotation = 24
		bloomGradient.Parent = bloom
		local brand = text(self.Stage, "ReferenceVTRBrand", "VTR", UDim2.fromScale(0.285, 0.09), UDim2.fromScale(0.18, 0.07), 34, paletteColor(self.Palette, "Main", WalkoutPresentationConfig.Colors.Voltra), Theme.Fonts.Display, 124)
		brand.TextXAlignment = Enum.TextXAlignment.Center
		brand.TextStrokeColor3 = Color3.fromHex("101A08")
		brand.TextStrokeTransparency = 0.2
		local hero = text(self.Stage, "ReferenceHeroHold", "HERO HOLD", UDim2.fromScale(0.255, 0.157), UDim2.fromScale(0.24, 0.05), 22, Theme.Colors.White, Theme.Fonts.Display, 124)
		hero.TextXAlignment = Enum.TextXAlignment.Center
		hero.TextStrokeColor3 = Color3.fromHex("101A08")
		hero.TextStrokeTransparency = 0.18
	end
	local vignette = Instance.new("Frame")
	vignette.BackgroundColor3 = Color3.fromHex("000000")
	vignette.BackgroundTransparency = WalkoutPresentationConfig.Scene.VignetteTransparency
	vignette.BorderSizePixel = 0
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.ZIndex = 112
	vignette.Parent = self.Stage
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, self.PremiumEffects and 0.68 or 0.42),
		NumberSequenceKeypoint.new(0.5, WalkoutPresentationConfig.Scene.VignetteCenterTransparency),
		NumberSequenceKeypoint.new(1, self.PremiumEffects and 0.66 or 0.38),
	})
	gradient.Parent = vignette
	self.LightningLayer = Instance.new("Frame")
	self.LightningLayer.Name = "LightningLayer"
	self.LightningLayer.BackgroundTransparency = 1
	self.LightningLayer.Size = UDim2.fromScale(1, 1)
	self.LightningLayer.ZIndex = 118
	self.LightningLayer.Parent = self.Stage
	for index = 1, 18 do
		local bolt = Instance.new("Frame")
		bolt.Name = "LightningSegment" .. index
		bolt.AnchorPoint = Vector2.new(0.5, 0.5)
		bolt.BackgroundColor3 = index % 3 == 0 and paletteColor(self.Palette, "Main", WalkoutPresentationConfig.Colors.Voltra) or paletteColor(self.Palette, "Accent", visual.glowColor)
		bolt.BackgroundTransparency = 1
		bolt.BorderSizePixel = 0
		bolt.Size = UDim2.fromOffset(4, 24)
		bolt.ZIndex = 119
		bolt.Parent = self.LightningLayer
		table.insert(self.LightningNodes, bolt)
	end
	for index = 1, PackOpeningConfig.EffectBudget.MaxSparkNodes do
		local spark = Instance.new("Frame")
		spark.Name = "Spark" .. index
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.BackgroundColor3 = index % 3 == 0 and paletteColor(self.Palette, "Secondary", Color3.new(1, 1, 1)) or index % 2 == 0 and paletteColor(self.Palette, "Main", WalkoutPresentationConfig.Colors.Voltra) or bright(paletteColor(self.Palette, "Accent", visual.glowColor), 0.25)
		spark.BackgroundTransparency = 1
		spark.BorderSizePixel = 0
		spark.Size = UDim2.fromOffset(3, 3)
		spark.ZIndex = 121
		spark.Parent = self.LightningLayer
		corner(spark, 3)
		table.insert(self.SparkNodes, spark)
	end
	if self.PremiumEffects and PackOpeningConfig.PremiumConfettiEnabled then
		for index = 1, self.SuperEffects and 54 or 36 do
			local confetti = Instance.new("Frame")
			confetti.Name = "PremiumConfetti" .. index
			confetti.AnchorPoint = Vector2.new(0.5, 0.5)
			confetti.BackgroundColor3 = index % 4 == 0 and paletteColor(self.Palette, "Secondary", Color3.new(1, 1, 1)) or index % 3 == 0 and paletteColor(self.Palette, "Accent", visual.glowColor) or paletteColor(self.Palette, "Main", WalkoutPresentationConfig.Colors.Voltra)
			confetti.BackgroundTransparency = 1
			confetti.BorderSizePixel = 0
			confetti.Position = UDim2.fromScale(0.5, -0.04)
			confetti.Rotation = index * 21
			confetti.Size = UDim2.fromOffset(index % 2 == 0 and 9 or 5, index % 2 == 0 and 4 or 8)
			confetti.ZIndex = 122
			confetti.Parent = self.LightningLayer
			table.insert(self.ConfettiNodes, confetti)
		end
	end
	self.Status = text(self.Stage, "Status", "VTR VOLTAGE WALKOUT", UDim2.fromScale(0.05, 0.045), UDim2.fromScale(0.9, 0.035), 12, Theme.Colors.Electric, Theme.Fonts.Strong, 120)
	self.Status.TextXAlignment = Enum.TextXAlignment.Center
	self.CluePanel = Instance.new("CanvasGroup")
	self.CluePanel.Name = "CluePanel"
	self.CluePanel.AnchorPoint = Vector2.new(0, 0.5)
	self.CluePanel.BackgroundColor3 = Color3.fromHex("050805")
	self.CluePanel.BackgroundTransparency = 0.22
	self.CluePanel.GroupTransparency = 1
	self.CluePanel.BorderSizePixel = 0
	self.CluePanel.Position = UDim2.fromScale(WalkoutPresentationConfig.Scene.CluePanelX, WalkoutPresentationConfig.Scene.CluePanelY)
	self.CluePanel.Size = UDim2.fromScale(WalkoutPresentationConfig.Scene.CluePanelWidth, WalkoutPresentationConfig.Scene.CluePanelHeight)
	self.CluePanel.ZIndex = 125
	self.CluePanel.Parent = self.Stage
	corner(self.CluePanel, 8)
	local clueStroke = Instance.new("UIStroke")
	clueStroke.Color = visual.glowColor
	clueStroke.Transparency = 0.25
	clueStroke.Parent = self.CluePanel
	self.ClueTitle = text(self.CluePanel, "ClueTitle", "SIGNAL LOCK", UDim2.fromScale(0.08, 0.06), UDim2.fromScale(0.84, 0.14), 11, visual.glowColor, Theme.Fonts.Display, 126)
	self.ClueValue = text(self.CluePanel, "ClueValue", "--", UDim2.fromScale(0.08, 0.24), UDim2.fromScale(0.84, 0.38), 24, Theme.Colors.White, Theme.Fonts.Display, 126)
	self.ClueValue.TextXAlignment = Enum.TextXAlignment.Center
	self.ClueFlag = Instance.new("ImageLabel")
	self.ClueFlag.Name = "ClueFlag"
	self.ClueFlag.BackgroundTransparency = 1
	self.ClueFlag.Image = ""
	self.ClueFlag.Position = UDim2.fromScale(0.19, 0.2)
	self.ClueFlag.Size = UDim2.fromScale(0.62, 0.42)
	self.ClueFlag.ScaleType = Enum.ScaleType.Fit
	self.ClueFlag.Visible = false
	self.ClueFlag.ZIndex = 126
	self.ClueFlag.Parent = self.CluePanel
	self.ClueMeta = text(self.CluePanel, "ClueMeta", "REVEAL DATA", UDim2.fromScale(0.08, 0.7), UDim2.fromScale(0.84, 0.2), 8, Theme.Colors.Muted, Theme.Fonts.Strong, 126)
	self.ClueMeta.TextXAlignment = Enum.TextXAlignment.Center
	self.Flash = Instance.new("Frame")
	self.Flash.BackgroundColor3 = visual.glowColor
	self.Flash.BackgroundTransparency = 1
	self.Flash.BorderSizePixel = 0
	self.Flash.Size = UDim2.fromScale(1, 1)
	self.Flash.ZIndex = 180
	self.Flash.Parent = self.Stage
	self.Skip = text(self.Stage, "SkipPrompt", "HOLD SPACE / ENTER / A / CLICK TO SKIP", UDim2.fromScale(0.62, 0.91), UDim2.fromScale(0.33, 0.045), 11, Theme.Colors.Muted, Theme.Fonts.Strong, 150)
	self.Skip.TextXAlignment = Enum.TextXAlignment.Right
	self.Skip.TextTransparency = 1
	local vip = false
	for _, card in self.Selection.Reveals do if card.VTRVipPackBoost == true then vip = true;break end end
	if vip then
		self.VipBadge = text(self.Stage, "VipBoost", "VIP BOOST ACTIVE", UDim2.fromScale(0.055, 0.11), UDim2.fromScale(0.22, 0.04), 11, Color3.fromHex("FFD43B"), Theme.Fonts.Display, 126)
	end
end

function Scene:_buildPack()
	local visual = self.Visual
	local definition = self.Props.PackDefinition or (self.Props.PackId and Catalog.Packs[self.Props.PackId]) or nil
	local name = tostring(definition and definition.Name or self.Props.Title or "VTR PLAYER PACK")
	local pack = Instance.new("Model")
	pack.Name = "VoltageCapsule"
	pack.Parent = self.World
	local entrance = WalkoutPresentationConfig.PackEntrance()
	local base = CFrame.new(entrance.Start)
	local body = structuralPart(pack, "CapsuleBody", Vector3.new(4.3, 6.2, 0.55), base, Color3.fromRGB(9, 11, 10), Enum.Material.Metal)
	body.Reflectance = 0.18
	local left = structuralPart(pack, "CapsuleLeftHalf", Vector3.new(2.1, 6.25, 0.62), base * CFrame.new(-1.08, 0, 0.08), Color3.fromRGB(18, 21, 19), Enum.Material.Metal)
	left.Reflectance = 0.14
	local right = structuralPart(pack, "CapsuleRightHalf", Vector3.new(2.1, 6.25, 0.62), base * CFrame.new(1.08, 0, 0.08), Color3.fromRGB(18, 21, 19), Enum.Material.Metal)
	right.Reflectance = 0.14
	local core = trimPart(pack, "CapsuleCore", Vector3.new(2.1, 4.45, 0.16), base * CFrame.new(0, 0, -0.34), Color3.fromRGB(125, 205, 20), Enum.Material.Glass)
	core.Transparency = 0.58
	core.Reflectance = 0.22
	local trim = trimPart(pack, "CapsuleTrim", Vector3.new(4.8, 0.18, 0.42), base * CFrame.new(0, 1.72, -0.28), Color3.fromRGB(165, 255, 0), Enum.Material.Neon)
	trim.Transparency = 0.35
	local lowerTrim = trimPart(pack, "CapsuleLowerTrim", Vector3.new(4.8, 0.16, 0.42), base * CFrame.new(0, -1.72, -0.28), Color3.fromRGB(165, 255, 0), Enum.Material.Neon)
	lowerTrim.Transparency = 0.42
	local mark = trimPart(pack, "V25Mark", Vector3.new(1.25, 1.25, 0.18), base * CFrame.new(0, 0.1, -0.48), WalkoutPresentationConfig.Colors.Voltra, Enum.Material.Neon)
	mark.Transparency = 0.24
	local pedestal = structuralPart(self.World, "PackPedestal", Vector3.new(5.8, 0.55, 3.2), CFrame.new(0, -1.5, entrance.Finish.Z), Color3.fromRGB(16, 19, 17), Enum.Material.Metal)
	pedestal.Reflectance = 0.2
	pack.PrimaryPart = body
	self.Pack = pack
	self.PackBody = body
	self.PackLeft = left
	self.PackRight = right
	self.PackTrim = trim
	self.PackCore = core
	self.PackLowerTrim = lowerTrim
	self.PackMark = mark
	self.PackPedestal = pedestal
	self.PackName = name
end

function Scene:_applyWalkoutPalette(model: Model)
	local shirt = cardColor(self.Best, "PrimaryColor", Color3.fromHex("252B27"))
	local trim = cardColor(self.Best, "AccentColor", self.Visual.glowColor)
	local shorts = cardColor(self.Best, "SecondaryColor", Color3.fromHex("DDE6D8"))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local lower = string.lower(descendant.Name)
			if descendant.Name == "HumanoidRootPart" then
				descendant.Transparency = WalkoutPresentationConfig.Scene.HumanoidRootTransparency
			elseif lower:find("torso") then
				descendant.Color = shirt:Lerp(Color3.fromHex("303832"), 0.35)
			elseif lower:find("leg") then
				descendant.Color = shorts:Lerp(Color3.fromHex("101410"), 0.18)
			elseif lower:find("arm") then
				descendant.Color = descendant.Color:Lerp(trim, 0.08)
			elseif lower:find("foot") or lower:find("boot") then
				descendant.Color = trim
			end
		end
	end
end

function Scene:_alignedAvatarCFrame(position: Vector3, lookAt: Vector3, surface: string): CFrame
	if not self.Avatar then return CFrame.lookAt(position, lookAt) end
	local desired = CFrame.lookAt(position, lookAt)
	self.Avatar:PivotTo(desired)
	local box, size = self.Avatar:GetBoundingBox()
	local bottom = box.Position.Y - size.Y * 0.5
	local lift = WalkoutPresentationConfig.SurfaceY(surface) - bottom
	return desired + Vector3.new(0, lift, 0)
end

function Scene:_setAvatarVisualState(state: string)
	if not self.Avatar then return end
	for _, descendant in self.Avatar:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
			descendant.CanCollide = false
			descendant.LocalTransparencyModifier = 0
			descendant.CastShadow = descendant.Name ~= "HumanoidRootPart"
			if descendant.Name == "HumanoidRootPart" then
				descendant.Transparency = WalkoutPresentationConfig.Scene.HumanoidRootTransparency
			elseif state == "Hidden" then
				descendant.Transparency = WalkoutPresentationConfig.Scene.HiddenTransparency
			elseif state == "Silhouette" then
				descendant.Transparency = WalkoutPresentationConfig.Scene.SilhouetteTransparency
			else
				descendant.Transparency = WalkoutPresentationConfig.Scene.NormalVisibleTransparency
			end
		end
	end
end

function Scene:_attachAvatarLighting(model: Model)
	if self.AvatarLightRig then return end
	local rig = Instance.new("Folder")
	rig.Name = "WalkoutAvatarLightRig"
	rig.Parent = self.World
	self.AvatarLightRig = rig
	local function spot(name: string, position: Vector3, target: Vector3, color: Color3, brightness: number, range: number, angle: number)
		local mount = trimPart(rig, name .. "Mount", Vector3.new(0.35, 0.35, 0.35), CFrame.lookAt(position, target), color, Enum.Material.SmoothPlastic)
		mount.Transparency = 1
		local light = Instance.new("SpotLight")
		light.Name = name
		light.Face = Enum.NormalId.Front
		light.Color = color
		light.Brightness = brightness
		light.Range = range
		light.Angle = angle
		light.Shadows = true
		light.Parent = mount
	end
	local accent = paletteColor(self.Palette, "Main", WalkoutPresentationConfig.Colors.Voltra)
	spot("WarmKeySpot", Vector3.new(-7.5, 9.2, 0.5), Vector3.new(0, 2.6, WalkoutPresentationConfig.Scene.HeroZ), Color3.fromRGB(255, 238, 200), 2.2, 26, 34)
	spot("NeutralFillSpot", Vector3.new(8.5, 7.2, -5.5), Vector3.new(0, 2.5, WalkoutPresentationConfig.Scene.HeroZ), Color3.fromRGB(215, 225, 220), 0.75, 24, 42)
	spot("LimeRimSpot", Vector3.new(5.4, 8.3, 19), Vector3.new(0, 2.65, WalkoutPresentationConfig.Scene.HeroZ), accent, 1.15, 28, 28)
	spot("PortalBacklight", Vector3.new(0, 9.5, 31.4), Vector3.new(0, 2.6, 12), Color3.fromRGB(235, 245, 225), 1.35, 32, 36)
	local highlight = Instance.new("Highlight")
	highlight.Name = "WalkoutAvatarReadability"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 244, 215)
	highlight.FillTransparency = 0.9
	highlight.OutlineColor = Color3.fromRGB(165, 255, 0)
	highlight.OutlineTransparency = 0.86
	highlight.Parent = model
end

function Scene:_buildAvatar()
	local ok, model = pcall(function() return AvatarPortraitGenerator.CloneModel(self.Best) end)
	if not ok or not model then
		self.AvatarFailed = true
		return
	end
	model.Parent = self.World
	self.Avatar = model
	normalizeWalkoutRig(model)
	self:_applyWalkoutPalette(model)
	self:_attachAvatarLighting(model)
	local portalX = tonumber(WalkoutPresentationConfig.Scene.PortalX) or 0
	local start = self:_alignedAvatarCFrame(Vector3.new(portalX, 0, WalkoutPresentationConfig.Scene.PortalZ - 0.6), Vector3.new(-1, 0, 8), "Runway")
	self.AvatarStart = start
	self.AvatarEnd = self:_alignedAvatarCFrame(Vector3.new(WalkoutPresentationConfig.Scene.HeroPlayerX, 0, WalkoutPresentationConfig.Scene.HeroZ), Vector3.new(8, 1.4, -8), "Stage")
	model:PivotTo(start)
	self:_setAvatarVisualState("Hidden")
	self.Motion = WalkoutMotionController.new(model)
end

function Scene:SetPhase(name: string)
	self.Status.Text = string.upper(name:gsub("(%l)(%u)", "%1 %2"))
end

function Scene:IgniteTunnel()
	self:SetLightingPhase("TunnelIgnition")
	for index, node in self.Nodes do
		if node:IsA("BasePart") then
			task.delay(index * 0.035, function()
				if node.Parent then self:_trackTween(TweenService:Create(node, TweenInfo.new(0.18), { Transparency = 0.12 })) end
			end)
		end
	end
	for index, node in self.RunwayNodes do
		task.delay(index * 0.045, function()
			if node.Parent then self:_trackTween(TweenService:Create(node, TweenInfo.new(0.2), { Transparency = 0.12 })) end
		end)
	end
	self:PulseLightning(0.45, Vector2.new(0.28, 0.38), Vector2.new(0.72, 0.36))
	self:DriftSmoke(0.35)
	self:_cameraShot("Charge")
end

function Scene:ChargePack(intensity: number)
	self:SetLightingPhase("EnergyCharge")
	if self.Pack then
		local base = self.Pack:GetPivot()
		local started = os.clock()
		if self.ChargeConnection then self.ChargeConnection:Disconnect() end
		local connection = RunService.RenderStepped:Connect(function()
			if not self.Pack or not self.Pack.Parent then return end
			local t = os.clock() - started
			local lift = math.sin(t * 5.4) * (0.28 + intensity * 0.16)
			local yaw = math.sin(t * 3.6) * math.rad(4 + intensity * 2)
			self.Pack:PivotTo(base * CFrame.new(0, lift, 0) * CFrame.Angles(0, yaw, 0))
		end)
		self.ChargeConnection = connection
		self:_trackConnection(connection)
	end
	self:BurstAroundPack(0.45 + intensity * 0.35)
	if self.PremiumEffects then
		self:PulseLightning(0.62 + intensity * 0.2, Vector2.new(0.34, 0.16), Vector2.new(0.68, 0.58))
		self:DriftSmoke(0.45 + intensity * 0.2)
	end
end

function Scene:ShowClue(kind: string)
	local card = self.Best
	local value = playerRarity(card)
	if kind == "Nationality" then value = tostring(card.Nation or card.nationality or card.Country or card.country or "VTR REGION")
	elseif kind == "Position" then value = tostring(card.Position or card.bestPosition or "--")
	elseif kind == "Club" then value = tostring(card.Club or card.fictionalClub or "VTR FREE AGENT") end
	self.ClueTitle.Text = string.upper(kind)
	local flagAsset = kind == "Nationality" and WorldCupConfig.Flag(value) or ""
	if self.ClueFlag then
		self.ClueFlag.Image = flagAsset
		self.ClueFlag.Visible = flagAsset ~= ""
	end
	self.ClueValue.Visible = flagAsset == ""
	self.ClueValue.Text = flagAsset ~= "" and "" or string.upper(value)
	self.ClueMeta.Text = flagAsset ~= "" and "FLAG SIGNAL FOUND" or "SIGNAL FOUND"
	self.CluePanel.GroupTransparency = 1
	self:_trackTween(TweenService:Create(self.CluePanel, TweenInfo.new(0.16), { GroupTransparency = 0 }))
	self:_burstSparks(Vector2.new(0.2, 0.56), 0.045, 0.45)
end

function Scene:Rupture()
	self:HideCluePanel()
	if self.ChargeConnection then self.ChargeConnection:Disconnect();self.ChargeConnection = nil end
	local limit = tonumber(self.Selection.Profile.FlashLimit) or 0.2
	if self.PackLeft then self:_trackTween(TweenService:Create(self.PackLeft, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = self.PackLeft.CFrame * CFrame.new(-4, 1.1, 0) * CFrame.Angles(0, 0, math.rad(-16)), Transparency = 1 })) end
	if self.PackRight then self:_trackTween(TweenService:Create(self.PackRight, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = self.PackRight.CFrame * CFrame.new(4, 1.1, 0) * CFrame.Angles(0, 0, math.rad(16)), Transparency = 1 })) end
	if self.PackBody then self:_trackTween(TweenService:Create(self.PackBody, TweenInfo.new(0.18), { Transparency = 1 })) end
	if self.PackTrim then self:_trackTween(TweenService:Create(self.PackTrim, TweenInfo.new(0.2), { Transparency = 1 })) end
	if self.PackCore then self:_trackTween(TweenService:Create(self.PackCore, TweenInfo.new(0.18), { Transparency = 1 })) end
	if self.PackLowerTrim then self:_trackTween(TweenService:Create(self.PackLowerTrim, TweenInfo.new(0.18), { Transparency = 1 })) end
	if self.PackMark then self:_trackTween(TweenService:Create(self.PackMark, TweenInfo.new(0.18), { Transparency = 1 })) end
	self:_cameraShot("Rupture")
	self.Flash.BackgroundTransparency = 1 - limit
	self:_trackTween(TweenService:Create(self.Flash, TweenInfo.new(0.32), { BackgroundTransparency = 1 }))
	self:BurstAroundPack(1)
	self:FirePyro(self.SuperEffects and 1.2 or 0.85)
end

function Scene:RevealSilhouette()
	if not self.Avatar then return end
	self:SetLightingPhase("Silhouette")
	self:_setAvatarVisualState("Silhouette")
	local portalX = tonumber(WalkoutPresentationConfig.Scene.PortalX) or 0
	local shot = WalkoutPresentationConfig.Shots.Silhouette
	self:_cameraTo(shot.Position, Vector3.new(portalX, 2.5, WalkoutPresentationConfig.Scene.PortalZ), shot.FOV, shot.Duration)
	self:BurstBehindPlayer(0.72)
end

function Scene:StartWalkout(onComplete: (() -> ())?)
	if not self.Avatar or not self.Motion then
		if onComplete then task.defer(onComplete) end
		return
	end
	self:SetLightingPhase("Walkout")
	self:_applyWalkoutPalette(self.Avatar)
	self:_setAvatarVisualState("Walkout")
	local portalX = tonumber(WalkoutPresentationConfig.Scene.PortalX) or 0
	local from = self.AvatarStart or self:_alignedAvatarCFrame(Vector3.new(portalX, 0, WalkoutPresentationConfig.Scene.PortalZ), Vector3.new(-1, 0, 8), "Runway")
	local to = self.AvatarEnd or self:_alignedAvatarCFrame(Vector3.new(WalkoutPresentationConfig.Scene.HeroPlayerX, 0, WalkoutPresentationConfig.Scene.HeroZ), Vector3.new(8, 1.4, -8), "Stage")
	self:_cameraShot("WalkStart", 0.18)
	self.Motion:Walk(from, to, tonumber(self.Selection.Profile.WalkDuration) or 1.7, tostring(self.Best.WalkStyle or self.Best.walkStyle or ""), function(alpha: number, pivot: CFrame)
		local chest = pivot.Position + Vector3.new(0, 2.55, 0)
		local cameraPos = chest + Vector3.new(3.2 - alpha * 1.4, 1.15, -13.2 + alpha * 2.4)
		local cameraCFrame = CFrame.lookAt(cameraPos, chest)
		local fieldOfView = 36 - alpha * 4
		if self.CameraCFrameValue and self.CameraFOVValue then
			self.CameraCFrameValue.Value = cameraCFrame
			self.CameraFOVValue.Value = fieldOfView
		else
			self.Camera.CFrame = cameraCFrame
			self.Camera.FieldOfView = fieldOfView
		end
		self:PulseRunway(0.28)
		if self.OnWalkoutStep then self.OnWalkoutStep(alpha, pivot) end
	end, onComplete)
end

function Scene:OrbitPlayer(turns: number, duration: number, onComplete: (() -> ())?)
	if not self.Avatar then
		if onComplete then task.defer(onComplete) end
		return
	end
	self:SetLightingPhase("Celebration")
	self:_setAvatarVisualState("Walkout")
	local totalDuration = math.max(0.8, tonumber(duration) or 3.1)
	if self.OrbitConnection then self.OrbitConnection:Disconnect();self.OrbitConnection = nil end
	if self.Selection.ReducedMotion then
		self:_cameraShot("Hero", math.min(totalDuration, 0.9))
		task.delay(math.min(totalDuration, 0.95), function()
			if self.WorldSceneActive and onComplete then onComplete() end
		end)
		return
	end
	local low = WalkoutPresentationConfig.Shots.CelebrationLow
	local side = WalkoutPresentationConfig.Shots.CelebrationSide
	local hero = WalkoutPresentationConfig.Shots.Hero
	local shotOne = math.max(0.55, totalDuration * 0.34)
	local shotTwo = math.max(0.55, totalDuration * 0.38)
	local shotThree = math.max(0.45, totalDuration - shotOne - shotTwo)
	self:_cameraTo(low.Position, low.Target, low.FOV, shotOne)
	task.delay(shotOne, function()
		if not self.WorldSceneActive then return end
		self:_cameraTo(side.Position, side.Target, side.FOV, shotTwo)
	end)
	task.delay(shotOne + shotTwo, function()
		if not self.WorldSceneActive then return end
		self:_cameraTo(hero.Position, hero.Target, hero.FOV, shotThree)
	end)
	task.delay(totalDuration, function()
		if self.WorldSceneActive and onComplete then onComplete() end
	end)
end

function Scene:Celebrate()
	if self.Motion then
		self.Motion:Celebrate(tostring(self.Best.CelebrationStyle or self.Best.celebrationStyle or "PowerStance"), 0.8)
	end
	self:SetLightingPhase("Celebration")
	self:PulseRunway(0.8)
	self:FirePyro(self.SuperEffects and 1.1 or 0.75)
	self:ReleaseConfetti(self.SuperEffects and 1.25 or 0.9)
end

function Scene:_ensureHeroCard()
	if self.HeroCard then return end
	local frame = Instance.new("CanvasGroup")
	frame.Name = "HeroCard"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = self.Visual.primaryColor
	frame.GroupTransparency = 1
	frame.Position = UDim2.fromScale(0.5, 0.52)
	frame.Rotation = 0
	frame.Size = UDim2.fromScale(self.PremiumEffects and 0.36 or 0.29, self.PremiumEffects and 0.8 or 0.66)
	frame.ZIndex = 130
	frame.Parent = self.Stage
	self.HeroCardCenterPosition = frame.Position
	self.HeroCardCenterSize = frame.Size
	self.HeroCardSidePosition = UDim2.fromScale(0.86, 0.54)
	self.HeroCardSideSize = UDim2.fromScale(self.PremiumEffects and 0.23 or 0.2, self.PremiumEffects and 0.62 or 0.5)
	CardSurface.apply(frame, playerRarity(self.Best), playerType(self.Best), 10)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			if child.Name:find("CardTypeEffect") or child.Name == "CardShine" or child.Name:find("EnergySlash") or child.Name:find("StarRay") or child.Name == "GoldFloodlightBeam" then
				child.ZIndex = 132
				child.BackgroundTransparency = math.max(child.BackgroundTransparency, 0.78)
			elseif child.Name == "CardPattern_Lightning" or child.Name:find("CardPattern") then
				child.ZIndex = 131
				child.BackgroundTransparency = math.max(child.BackgroundTransparency, 0.84)
			end
		end
	end
	if self.PremiumEffects then
		local faceLight = Instance.new("Frame")
		faceLight.Name = "HeroCardFaceLight"
		faceLight.BackgroundColor3 = paletteColor(self.Palette, "Secondary", Color3.new(1, 1, 1))
		faceLight.BackgroundTransparency = 0.24
		faceLight.BorderSizePixel = 0
		faceLight.Position = UDim2.fromScale(0.04, 0.04)
		faceLight.Size = UDim2.fromScale(0.92, 0.92)
		faceLight.ZIndex = 133
		faceLight.Parent = frame
		corner(faceLight, 10)
		local faceGradient = Instance.new("UIGradient")
		faceGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, paletteColor(self.Palette, "Accent", self.Visual.glowColor)),
			ColorSequenceKeypoint.new(0.54, Color3.fromHex("FFFBE0")),
			ColorSequenceKeypoint.new(1, paletteColor(self.Palette, "Main", WalkoutPresentationConfig.Colors.Voltra)),
		})
		faceGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.58, 0.22),
			NumberSequenceKeypoint.new(1, 0.08),
		})
		faceGradient.Rotation = 28
		faceGradient.Parent = faceLight
	end
	local heroStroke = Instance.new("UIStroke")
	heroStroke.Name = "HeroCardRevealPulse"
	heroStroke.Color = paletteColor(self.Palette, "Accent", self.Visual.glowColor)
	heroStroke.Thickness = self.SuperEffects and 6 or 4
	heroStroke.Transparency = 0.42
	heroStroke.Parent = frame
	self.HeroCardStroke = heroStroke
	local aura = Instance.new("Frame")
	aura.Name = "HeroCardAura"
	aura.AnchorPoint = Vector2.new(0.5, 0.5)
	aura.BackgroundColor3 = paletteColor(self.Palette, "Accent", self.Visual.glowColor)
	aura.BackgroundTransparency = 0.94
	aura.BorderSizePixel = 0
	aura.Position = UDim2.fromScale(0.5, 0.5)
	aura.Size = UDim2.fromScale(1.14, 1.08)
	aura.ZIndex = 128
	aura.Parent = frame
	corner(aura, 14)
	self:_trackTween(TweenService:Create(aura, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.97, Size = UDim2.fromScale(1.2, 1.12) }))
	text(frame, "OVRLabel", "OVR", UDim2.fromScale(0.08, 0.07), UDim2.fromScale(0.28, 0.08), 16, Theme.Colors.White, Theme.Fonts.Display, 150)
	self.RatingLabel = text(frame, "Rating", "--", UDim2.fromScale(0.08, 0.14), UDim2.fromScale(0.42, 0.18), 58, Theme.Colors.White, Theme.Fonts.Display, 150)
	self.RatingLabel.TextXAlignment = Enum.TextXAlignment.Center
	text(frame, "Position", tostring(self.Best.Position or self.Best.bestPosition or "--"), UDim2.fromScale(0.52, 0.17), UDim2.fromScale(0.34, 0.1), 22, Theme.Colors.White, Theme.Fonts.Display, 150).TextXAlignment = Enum.TextXAlignment.Center
	local country = tostring(self.Best.Nation or self.Best.nationality or self.Best.Country or "")
	local flagAsset = WorldCupConfig.Flag(country)
	if flagAsset ~= "" then
		local flag = Instance.new("ImageLabel")
		flag.Name = "NationFlag"
		flag.BackgroundTransparency = 1
		flag.Image = flagAsset
		flag.Position = UDim2.fromScale(0.18, 0.27)
		flag.Size = UDim2.fromScale(0.18, 0.08)
		flag.ScaleType = Enum.ScaleType.Fit
		flag.ZIndex = 151
		flag.Parent = frame
	end
	local portraitSlot = Instance.new("Frame")
	portraitSlot.BackgroundTransparency = 1
	portraitSlot.Position = UDim2.fromScale(0.1, 0.35)
	portraitSlot.Size = UDim2.fromScale(0.8, 0.34)
	portraitSlot.ZIndex = 148
	portraitSlot.Parent = frame
	local ok = pcall(function()
		local portrait = AvatarPortraitGenerator.new(portraitSlot, self.Best, UDim2.fromScale(1, 1), false)
		portrait.ZIndex = 149
		portrait.BackgroundTransparency = 1
	end)
	if not ok then
		text(portraitSlot, "PortraitFallback", "PLAYER", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20, Theme.Colors.White, Theme.Fonts.Display, 149).TextXAlignment = Enum.TextXAlignment.Center
	end
	self.NameLabel = text(frame, "PlayerName", playerName(self.Best), UDim2.fromScale(0.08, 0.72), UDim2.fromScale(0.84, 0.12), 20, Theme.Colors.White, Theme.Fonts.Display, 150)
	self.NameLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.NameLabel.TextTransparency = 1
	text(frame, "Meta", string.upper(playerRarity(self.Best) .. " / " .. playerType(self.Best)), UDim2.fromScale(0.08, 0.86), UDim2.fromScale(0.84, 0.07), 10, Theme.Colors.White, Theme.Fonts.Strong, 150).TextXAlignment = Enum.TextXAlignment.Center
	self.HeroCard = frame
end

function Scene:RevealRating()
	self:_ensureHeroCard()
	self:SetLightingPhase("RatingReveal")
	self.HeroCard.Position = self.HeroCardCenterPosition or UDim2.fromScale(0.5, 0.52)
	self.HeroCard.Size = self.HeroCardCenterSize or self.HeroCard.Size
	self.HeroCard.Rotation = 0
	self:_trackTween(TweenService:Create(self.HeroCard, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { GroupTransparency = 0 }))
	self:RatingImpact(0.7)
	local final = rating(self.Best)
	local start = math.max(1, final - math.clamp(final >= 90 and 8 or 5, 3, 8))
	local steps = math.max(1, final - start)
	for index = 0, steps do
		task.delay(index * 0.075 + (index > steps - 3 and 0.08 or 0), function()
			if self.RatingLabel and self.RatingLabel.Parent then self.RatingLabel.Text = tostring(start + index) end
		end)
	end
end

function Scene:RevealName()
	self:_ensureHeroCard()
	if self.NameLabel then
		self.NameLabel.TextTransparency = 1
		self:_trackTween(TweenService:Create(self.NameLabel, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0 }))
	end
	task.delay(1.25, function()
		if self.HeroCard and self.HeroCard.Parent then
			self:_trackTween(TweenService:Create(self.HeroCard, TweenInfo.new(0.78, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
				Position = self.HeroCardSidePosition or UDim2.fromScale(0.86, 0.54),
				Size = self.HeroCardSideSize or self.HeroCard.Size,
				Rotation = -1,
			}))
		end
	end)
end

function Scene:ShowRemaining()
	local remaining = math.max(0, #self.Selection.Reveals - 1)
	if remaining <= 0 then return end
	local label = text(self.Stage, "RemainingCards", "+" .. tostring(remaining) .. " MORE SECURED IN CLUB", UDim2.fromScale(0.36, 0.86), UDim2.fromScale(0.32, 0.04), 12, Theme.Colors.Electric, Theme.Fonts.Strong, 145)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTransparency = 1
	self:_trackTween(TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }))
end

function Scene:ShowResults(onContinue: () -> ())
	for _, child in self.Stage:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	self:_restoreWorldScene()
	self:_restoreUnderlyingGui()
	self:_restoreCharacter()
	self.Stage.BackgroundTransparency = 1
	self.Stage.BackgroundColor3 = Color3.fromHex("050805")
	local panel = Instance.new("Frame")
	panel.Name = "PackContents"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromHex("050805")
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.82, 0.82)
	panel.ZIndex = 130
	panel.Parent = self.Stage
	corner(panel, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = self.Visual.glowColor
	stroke.Transparency = 0.24
	stroke.Parent = panel
	text(panel, "Title", string.upper(tostring(self.Props.Title or "PACK")) .. " / PACK CONTENTS", UDim2.fromScale(0.035, 0.025), UDim2.fromScale(0.93, 0.07), 24, Theme.Colors.White, Theme.Fonts.Display, 132)
	text(panel, "Secured", "HIGHEST RATED FIRST / SECURED IN CLUB", UDim2.fromScale(0.035, 0.09), UDim2.fromScale(0.93, 0.035), 10, Theme.Colors.Electric, Theme.Fonts.Strong, 132)
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromScale(0.035, 0.15)
	list.Size = UDim2.fromScale(0.93, 0.7)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = self.Visual.glowColor
	list.ZIndex = 132
	list.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -8, 0, 112)
	grid.CellPadding = UDim2.fromOffset(12, 10)
	grid.Parent = list
	local renderLimit = math.min(#self.Selection.Reveals, 24)
	for index = 1, renderLimit do
		local card = self.Selection.Reveals[index]
		local wrapper = Instance.new("Frame")
		wrapper.BackgroundTransparency = 1
		wrapper.LayoutOrder = index
		wrapper.ZIndex = 133
		wrapper.Parent = list
		WidePlayerCard.new({ Parent = wrapper, Card = card, Size = UDim2.fromScale(1, 1), ZIndex = 133, OnActivated = function()
			if self.Props.OnViewPlayer then self.Props.OnViewPlayer(card.cardInstanceId or card.Id) end
		end })
	end
	if #self.Selection.Reveals > renderLimit then
		text(panel, "More", "+" .. tostring(#self.Selection.Reveals - renderLimit) .. " MORE CARDS SECURED", UDim2.fromScale(0.38, 0.88), UDim2.fromScale(0.24, 0.035), 10, Theme.Colors.Electric, Theme.Fonts.Strong, 132).TextXAlignment = Enum.TextXAlignment.Center
	end
	local view = Button.new({ Text = "VIEW BEST PLAYER", Variant = "Secondary", Size = UDim2.fromOffset(185, 40), OnActivated = function()
		if self.Props.OnViewPlayer and self.Best then self.Props.OnViewPlayer(self.Best.cardInstanceId or self.Best.Id) end
	end })
	view.AnchorPoint = Vector2.new(1, 1)
	view.Position = UDim2.new(1, -218, 1, -22)
	view.ZIndex = 134
	view.Parent = panel
	local continue = Button.new({ Text = "CONTINUE", Variant = "Primary", Size = UDim2.fromOffset(170, 40), OnActivated = onContinue })
	continue.AnchorPoint = Vector2.new(1, 1)
	continue.Position = UDim2.new(1, -28, 1, -22)
	continue.ZIndex = 134
	continue.Parent = panel
end

function Scene:SetSkipProgress(alpha: number)
	if self.Skip then
		self.Skip.TextTransparency = 0
		self.Skip.Text = alpha > 0 and ("SKIPPING " .. tostring(math.floor(alpha * 100)) .. "%") or "HOLD SPACE / ENTER / A / CLICK TO SKIP"
	end
end

function Scene:_restoreWorldScene()
	if self.WorldSceneActive ~= true then return end
	self.WorldSceneActive = false
	if self.CameraBindName then
		pcall(function() RunService:UnbindFromRenderStep(self.CameraBindName) end)
		self.CameraBindName = nil
	end
	if self.Motion then self.Motion:Destroy();self.Motion = nil end
	if self.ChargeConnection then self.ChargeConnection:Disconnect();self.ChargeConnection = nil end
	if self.World and self.World.Parent then self.World:Destroy() end
	local camera = currentCamera()
	local previousCamera = self.PreviousCamera
	if camera and previousCamera then
		camera.CameraType = previousCamera.CameraType or Enum.CameraType.Custom
		camera.CameraSubject = previousCamera.CameraSubject
		camera.CFrame = previousCamera.CFrame or camera.CFrame
		camera.FieldOfView = previousCamera.FieldOfView or camera.FieldOfView
	end
	local previousLighting = self.PreviousLighting
	if previousLighting then
		if previousLighting.Technology ~= nil then lightingSet("Technology", previousLighting.Technology) end
		lightingSet("Ambient", previousLighting.Ambient)
		lightingSet("OutdoorAmbient", previousLighting.OutdoorAmbient)
		lightingSet("Brightness", previousLighting.Brightness)
		lightingSet("ColorShift_Top", previousLighting.ColorShift_Top)
		lightingSet("ColorShift_Bottom", previousLighting.ColorShift_Bottom)
		lightingSet("ClockTime", previousLighting.ClockTime)
		lightingSet("ExposureCompensation", previousLighting.ExposureCompensation)
		lightingSet("EnvironmentDiffuseScale", previousLighting.EnvironmentDiffuseScale)
		lightingSet("EnvironmentSpecularScale", previousLighting.EnvironmentSpecularScale)
		lightingSet("FogEnd", previousLighting.FogEnd)
		lightingSet("FogStart", previousLighting.FogStart)
		lightingSet("FogColor", previousLighting.FogColor)
	end
	for _, effect in self.WalkoutPostEffects or {} do
		if typeof(effect) == "Instance" and effect.Parent then effect:Destroy() end
	end
	self.WalkoutPostEffects = nil
end

function Scene:_restoreUnderlyingGui()
	if not self.HiddenGui then return end
	for _, item in self.HiddenGui do
		local object = item.Object
		if typeof(object) == "Instance" and object.Parent and object:IsA("GuiObject") then
			object.Visible = item.Visible ~= false
		end
	end
	self.HiddenGui = nil
end

function Scene:_restoreCharacter()
	if not self.HiddenCharacter then return end
	restoreLocalCharacter(self.HiddenCharacter)
	self.HiddenCharacter = nil
end

function Scene:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	for _, tween in self.Tweens do pcall(function() tween:Cancel() end) end
	self.Tweens = {}
	for _, connection in self.Connections do pcall(function() connection:Disconnect() end) end
	self.Connections = {}
	if self.ChargeConnection then self.ChargeConnection:Disconnect();self.ChargeConnection = nil end
	self:_restoreWorldScene()
	self:_restoreUnderlyingGui()
	self:_restoreCharacter()
	if self.Overlay and self.Overlay.Parent then self.Overlay:Destroy() end
end

return Scene
