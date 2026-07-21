--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local CardVisualConfig = require(ReplicatedStorage.VTR.Shared.CardVisualConfig)
local PackOpeningConfig = require(ReplicatedStorage.VTR.Shared.PackOpeningConfig)
local WorldCupConfig = require(ReplicatedStorage.VTR.Shared.WorldCupConfig)
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local CardSurface = require(script.Parent.CardSurface)
local WidePlayerCard = require(script.Parent.WidePlayerCard)
local Button = require(script.Parent.Button)
local AvatarPortraitGenerator = require(script.Parent.Parent.Services.AvatarPortraitGenerator)
local WalkoutMotionController = require(script.Parent.Parent.Gameplay.WalkoutMotionController)

local Scene = {}
Scene.__index = Scene

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

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.CanCollide = false
	item.CastShadow = false
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
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

function Scene.new(parent: Instance, props: any, selection: any)
	local best = selection.BestCard
	local rarity = playerRarity(best)
	local cardType = playerType(best)
	local visual = CardVisualConfig.Get(rarity, cardType)
	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "PremiumPackOpening"
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 100
	overlay.Active = true
	overlay.Selectable = false
	overlay.Parent = parent
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
	stage.BackgroundColor3 = Color3.fromHex("020302")
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
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "VoltageTunnelViewport"
	viewport.BackgroundColor3 = Color3.fromHex("020302")
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromHex("2A3427")
	viewport.LightColor = visual.glowColor
	viewport.LightDirection = Vector3.new(-0.45, -0.75, -0.25)
	viewport.ZIndex = 103
	viewport.Parent = stage
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(PackOpeningConfig.CameraKeyframes.Start.Position, PackOpeningConfig.CameraKeyframes.Start.Target)
	camera.FieldOfView = PackOpeningConfig.CameraKeyframes.Start.FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local self = setmetatable({
		Overlay = overlay,
		Stage = stage,
		Viewport = viewport,
		World = world,
		Camera = camera,
		Props = props,
		Selection = selection,
		Best = best,
		Visual = visual,
		Nodes = {},
		Tweens = {},
		Motion = nil,
		OnResultsContinue = nil,
	}, Scene)
	self:_buildTunnel()
	self:_buildOverlays()
	self:_buildPack()
	self:_buildAvatar()
	TweenService:Create(overlay, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
	return self
end

function Scene:_trackTween(tween: Tween)
	table.insert(self.Tweens, tween)
	tween:Play()
	return tween
end

function Scene:_buildTunnel()
	local visual = self.Visual
	part(self.World, "ReflectiveRunway", Vector3.new(22, 0.18, 58), CFrame.new(0, -2.2, 4), Color3.fromHex("050805"), Enum.Material.SmoothPlastic)
	part(self.World, "BackVoltageWall", Vector3.new(26, 14, 0.5), CFrame.new(0, 4, 34), Color3.fromHex("060806"), Enum.Material.SmoothPlastic)
	part(self.World, "LeftTunnelWall", Vector3.new(0.45, 12, 58), CFrame.new(-12, 3.4, 4), Color3.fromHex("080B08"), Enum.Material.SmoothPlastic)
	part(self.World, "RightTunnelWall", Vector3.new(0.45, 12, 58), CFrame.new(12, 3.4, 4), Color3.fromHex("080B08"), Enum.Material.SmoothPlastic)
	part(self.World, "StagePlate", Vector3.new(11, 0.35, 7), CFrame.new(0, -1.92, 11), visual.primaryColor:Lerp(Color3.fromHex("050505"), 0.45), Enum.Material.SmoothPlastic)
	local mark = part(self.World, "VTRMark", Vector3.new(8, 4.2, 0.22), CFrame.new(0, 4.4, 33.55), visual.trimColor, Enum.Material.Neon)
	mark.Transparency = 0.48
	for index = 1, PackOpeningConfig.EffectBudget.MaxLightBars do
		local z = -18 + index * 4
		local side = index % 2 == 0 and -1 or 1
		local bar = part(self.World, "LEDBar" .. index, Vector3.new(0.22, 4.8, 0.22), CFrame.new(10.7 * side, 2.2, z), visual.glowColor, Enum.Material.Neon)
		bar.Transparency = 0.82
		table.insert(self.Nodes, bar)
	end
	for index = 1, 2 do
		local bank = part(self.World, "OverheadLight" .. index, Vector3.new(8.5, 0.2, 0.6), CFrame.new(0, 8.8, -6 + index * 16), index == 1 and Color3.fromHex("B7FF1A") or visual.glowColor, Enum.Material.Neon)
		bank.Transparency = 0.72
	end
end

function Scene:_buildOverlays()
	local visual = self.Visual
	local vignette = Instance.new("Frame")
	vignette.BackgroundColor3 = Color3.fromHex("000000")
	vignette.BackgroundTransparency = 0.35
	vignette.BorderSizePixel = 0
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.ZIndex = 112
	vignette.Parent = self.Stage
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.75),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	gradient.Parent = vignette
	self.Status = text(self.Stage, "Status", "VTR VOLTAGE WALKOUT", UDim2.fromScale(0.05, 0.045), UDim2.fromScale(0.9, 0.035), 12, Theme.Colors.Electric, Theme.Fonts.Strong, 120)
	self.Status.TextXAlignment = Enum.TextXAlignment.Center
	self.CluePanel = Instance.new("CanvasGroup")
	self.CluePanel.Name = "CluePanel"
	self.CluePanel.AnchorPoint = Vector2.new(0, 0.5)
	self.CluePanel.BackgroundColor3 = Color3.fromHex("050805")
	self.CluePanel.BackgroundTransparency = 0.08
	self.CluePanel.GroupTransparency = 1
	self.CluePanel.BorderSizePixel = 0
	self.CluePanel.Position = UDim2.fromScale(0.055, 0.48)
	self.CluePanel.Size = UDim2.fromScale(0.28, 0.42)
	self.CluePanel.ZIndex = 125
	self.CluePanel.Parent = self.Stage
	corner(self.CluePanel, 8)
	local clueStroke = Instance.new("UIStroke")
	clueStroke.Color = visual.glowColor
	clueStroke.Transparency = 0.25
	clueStroke.Parent = self.CluePanel
	self.ClueTitle = text(self.CluePanel, "ClueTitle", "SIGNAL LOCK", UDim2.fromScale(0.08, 0.05), UDim2.fromScale(0.84, 0.14), 13, visual.glowColor, Theme.Fonts.Display, 126)
	self.ClueValue = text(self.CluePanel, "ClueValue", "--", UDim2.fromScale(0.08, 0.24), UDim2.fromScale(0.84, 0.42), 30, Theme.Colors.White, Theme.Fonts.Display, 126)
	self.ClueValue.TextXAlignment = Enum.TextXAlignment.Center
	self.ClueMeta = text(self.CluePanel, "ClueMeta", "SERVER REVEAL DATA", UDim2.fromScale(0.08, 0.72), UDim2.fromScale(0.84, 0.18), 10, Theme.Colors.Muted, Theme.Fonts.Strong, 126)
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
	local body = part(pack, "CapsuleBody", Vector3.new(4.3, 6.2, 0.55), CFrame.new(0, 2.1, -1), visual.primaryColor, Enum.Material.SmoothPlastic)
	local left = part(pack, "CapsuleLeftHalf", Vector3.new(2.1, 6.25, 0.62), CFrame.new(-1.08, 2.1, -0.92), visual.secondaryColor, Enum.Material.SmoothPlastic)
	local right = part(pack, "CapsuleRightHalf", Vector3.new(2.1, 6.25, 0.62), CFrame.new(1.08, 2.1, -0.92), visual.secondaryColor, Enum.Material.SmoothPlastic)
	local trim = part(pack, "CapsuleTrim", Vector3.new(4.6, 0.28, 0.68), CFrame.new(0, 3.8, -1.27), visual.trimColor, Enum.Material.Neon)
	local pedestal = part(self.World, "PackPedestal", Vector3.new(5.6, 0.55, 3.2), CFrame.new(0, -1.5, -1), visual.trimColor, Enum.Material.Neon)
	pedestal.Transparency = 0.42
	pack.PrimaryPart = body
	self.Pack = pack
	self.PackLeft = left
	self.PackRight = right
	self.PackTrim = trim
	self.PackName = name
end

function Scene:_buildAvatar()
	local ok, model = pcall(function() return AvatarPortraitGenerator.CloneModel(self.Best) end)
	if not ok or not model then
		self.AvatarFailed = true
		return
	end
	model.Parent = self.World
	if model.PrimaryPart then
		model:PivotTo(CFrame.lookAt(Vector3.new(0, -0.35, 28), Vector3.new(0, -0.35, 10)))
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Transparency = math.max(descendant.Transparency, 0.92)
		end
	end
	self.Avatar = model
	self.Motion = WalkoutMotionController.new(model)
end

function Scene:SetPhase(name: string)
	self.Status.Text = string.upper(name:gsub("(%l)(%u)", "%1 %2"))
end

function Scene:IgniteTunnel()
	for index, node in self.Nodes do
		if node:IsA("BasePart") then
			task.delay(index * 0.035, function()
				if node.Parent then self:_trackTween(TweenService:Create(node, TweenInfo.new(0.18), { Transparency = 0.12 })) end
			end)
		end
	end
	local key = PackOpeningConfig.CameraKeyframes.Charge
	self:_trackTween(TweenService:Create(self.Camera, TweenInfo.new(0.62, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(key.Position, key.Target), FieldOfView = key.FOV }))
end

function Scene:ChargePack(intensity: number)
	if self.Pack and self.Pack.PrimaryPart then
		self:_trackTween(TweenService:Create(self.Pack.PrimaryPart, TweenInfo.new(0.68, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = self.Pack.PrimaryPart.CFrame * CFrame.new(0, 0.35 + intensity * 0.2, 0) * CFrame.Angles(0, math.rad(5), 0) }))
	end
end

function Scene:ShowClue(kind: string)
	local card = self.Best
	local value = playerRarity(card)
	if kind == "Nationality" then value = tostring(card.Nation or card.nationality or "VTR REGION")
	elseif kind == "Position" then value = tostring(card.Position or card.bestPosition or "--")
	elseif kind == "Club" then value = tostring(card.Club or card.fictionalClub or "VTR FREE AGENT") end
	self.ClueTitle.Text = string.upper(kind)
	self.ClueValue.Text = string.upper(value)
	self.ClueMeta.Text = kind == "Nationality" and WorldCupConfig.Flag(value) ~= "" and "FLAG SIGNAL FOUND" or "AUTHENTICATED"
	self.CluePanel.GroupTransparency = 1
	self:_trackTween(TweenService:Create(self.CluePanel, TweenInfo.new(0.16), { GroupTransparency = 0 }))
end

function Scene:Rupture()
	local limit = tonumber(self.Selection.Profile.FlashLimit) or 0.2
	if self.PackLeft then self:_trackTween(TweenService:Create(self.PackLeft, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = self.PackLeft.CFrame * CFrame.new(-4, 1.1, 0) * CFrame.Angles(0, 0, math.rad(-16)), Transparency = 1 })) end
	if self.PackRight then self:_trackTween(TweenService:Create(self.PackRight, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = self.PackRight.CFrame * CFrame.new(4, 1.1, 0) * CFrame.Angles(0, 0, math.rad(16)), Transparency = 1 })) end
	if self.PackTrim then self:_trackTween(TweenService:Create(self.PackTrim, TweenInfo.new(0.2), { Transparency = 1 })) end
	self.Flash.BackgroundTransparency = 1 - limit
	self:_trackTween(TweenService:Create(self.Flash, TweenInfo.new(0.32), { BackgroundTransparency = 1 }))
end

function Scene:RevealSilhouette()
	if not self.Avatar then return end
	for _, descendant in self.Avatar:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.Transparency = math.min(descendant.Transparency, 0.78)
			self:_trackTween(TweenService:Create(descendant, TweenInfo.new(0.35), { Transparency = 0.36 }))
		end
	end
	local key = PackOpeningConfig.CameraKeyframes.Walkout
	self:_trackTween(TweenService:Create(self.Camera, TweenInfo.new(0.45), { CFrame = CFrame.lookAt(key.Position, key.Target), FieldOfView = key.FOV }))
end

function Scene:StartWalkout(onComplete: (() -> ())?)
	if not self.Avatar or not self.Motion or self.Selection.ReducedMotion then
		if onComplete then task.defer(onComplete) end
		return
	end
	for _, descendant in self.Avatar:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.Transparency = 0
		end
	end
	local from = CFrame.lookAt(Vector3.new(0, -0.35, 27), Vector3.new(0, -0.35, 8))
	local to = CFrame.lookAt(Vector3.new(0, -0.35, 9.8), Vector3.new(6, 1.4, -9))
	self.Motion:Walk(from, to, tonumber(self.Selection.Profile.WalkDuration) or 1.7, tostring(self.Best.WalkStyle or self.Best.walkStyle or ""), onComplete)
end

function Scene:Celebrate()
	if self.Motion then
		self.Motion:Celebrate(tostring(self.Best.CelebrationStyle or self.Best.celebrationStyle or "PowerStance"), 0.8)
	end
	local key = PackOpeningConfig.CameraKeyframes.Hero
	self:_trackTween(TweenService:Create(self.Camera, TweenInfo.new(0.35), { CFrame = CFrame.lookAt(key.Position, key.Target), FieldOfView = key.FOV }))
end

function Scene:_ensureHeroCard()
	if self.HeroCard then return end
	local frame = Instance.new("CanvasGroup")
	frame.Name = "HeroCard"
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.BackgroundColor3 = self.Visual.primaryColor
	frame.GroupTransparency = 1
	frame.Position = UDim2.fromScale(0.91, 0.52)
	frame.Size = UDim2.fromScale(0.25, 0.62)
	frame.ZIndex = 130
	frame.Parent = self.Stage
	CardSurface.apply(frame, playerRarity(self.Best), playerType(self.Best), 10)
	text(frame, "OVRLabel", "OVR", UDim2.fromScale(0.08, 0.07), UDim2.fromScale(0.28, 0.08), 16, self.Visual.glowColor, Theme.Fonts.Display, 135)
	self.RatingLabel = text(frame, "Rating", "--", UDim2.fromScale(0.08, 0.14), UDim2.fromScale(0.42, 0.18), 58, Theme.Colors.White, Theme.Fonts.Display, 135)
	self.RatingLabel.TextXAlignment = Enum.TextXAlignment.Center
	text(frame, "Position", tostring(self.Best.Position or self.Best.bestPosition or "--"), UDim2.fromScale(0.52, 0.17), UDim2.fromScale(0.34, 0.1), 22, Theme.Colors.White, Theme.Fonts.Display, 135).TextXAlignment = Enum.TextXAlignment.Center
	local portraitSlot = Instance.new("Frame")
	portraitSlot.BackgroundTransparency = 1
	portraitSlot.Position = UDim2.fromScale(0.1, 0.35)
	portraitSlot.Size = UDim2.fromScale(0.8, 0.34)
	portraitSlot.ZIndex = 133
	portraitSlot.Parent = frame
	local ok = pcall(function()
		local portrait = AvatarPortraitGenerator.new(portraitSlot, self.Best, UDim2.fromScale(1, 1), false)
		portrait.ZIndex = 134
	end)
	if not ok then
		text(portraitSlot, "PortraitFallback", "PLAYER", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20, Theme.Colors.White, Theme.Fonts.Display, 134).TextXAlignment = Enum.TextXAlignment.Center
	end
	self.NameLabel = text(frame, "PlayerName", playerName(self.Best), UDim2.fromScale(0.08, 0.72), UDim2.fromScale(0.84, 0.12), 20, Theme.Colors.White, Theme.Fonts.Display, 135)
	self.NameLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.NameLabel.TextTransparency = 1
	text(frame, "Meta", string.upper(playerRarity(self.Best) .. " / " .. playerType(self.Best)), UDim2.fromScale(0.08, 0.86), UDim2.fromScale(0.84, 0.07), 10, self.Visual.glowColor, Theme.Fonts.Strong, 135).TextXAlignment = Enum.TextXAlignment.Center
	self.HeroCard = frame
end

function Scene:RevealRating()
	self:_ensureHeroCard()
	self:_trackTween(TweenService:Create(self.HeroCard, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { GroupTransparency = 0 }))
	local final = rating(self.Best)
	local start = math.max(1, final - math.clamp(final >= 90 and 8 or 5, 3, 8))
	local steps = math.max(1, final - start)
	for index = 0, steps do
		task.delay(index * 0.035 + (index > steps - 3 and 0.04 or 0), function()
			if self.RatingLabel and self.RatingLabel.Parent then self.RatingLabel.Text = tostring(start + index) end
		end)
	end
end

function Scene:RevealName()
	self:_ensureHeroCard()
	if self.NameLabel then
		self.NameLabel.TextTransparency = 1
		self:_trackTween(TweenService:Create(self.NameLabel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0 }))
	end
	local key = PackOpeningConfig.CameraKeyframes.Card
	self:_trackTween(TweenService:Create(self.Camera, TweenInfo.new(0.32), { CFrame = CFrame.lookAt(key.Position, key.Target), FieldOfView = key.FOV }))
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
		if child ~= self.Viewport and child:IsA("GuiObject") then child:Destroy() end
	end
	self.Viewport.Visible = false
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

function Scene:Destroy()
	for _, tween in self.Tweens do pcall(function() tween:Cancel() end) end
	if self.Motion then self.Motion:Destroy() end
	if self.Overlay and self.Overlay.Parent then self.Overlay:Destroy() end
end

return Scene
