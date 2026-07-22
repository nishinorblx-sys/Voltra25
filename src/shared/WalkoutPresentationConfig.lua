--!strict

local Config = {}

Config.Colors = table.freeze({
	ViewportBackground = Color3.fromHex("061006"),
	Runway = Color3.fromHex("0D180B"),
	TunnelWall = Color3.fromHex("071207"),
	BackWall = Color3.fromHex("0A1408"),
	WarmKey = Color3.fromHex("F2FFE0"),
	Voltra = Color3.fromHex("98FF00"),
})

Config.Scene = table.freeze({
	RunwayY = -2.2,
	RunwayHeight = 0.18,
	StageY = -1.92,
	StageHeight = 0.35,
	PortalZ = 30,
	PortalX = 0,
	HeroZ = 9.8,
	HeroPlayerX = 0,
	CardScreenCenterX = 0.78,
	CluePanelX = 0.055,
	CluePanelY = 0.54,
	CluePanelWidth = 0.225,
	CluePanelHeight = 0.285,
	VignetteTransparency = 0.42,
	VignetteCenterTransparency = 0.985,
	NormalVisibleTransparency = 0,
	SilhouetteTransparency = 0,
	HiddenTransparency = 1,
	HumanoidRootTransparency = 1,
})

Config.LightingPhases = table.freeze({
	Blackout = table.freeze({ Ambient = Color3.fromRGB(3, 5, 4), LightColor = Color3.fromRGB(95, 165, 12), LightDirection = Vector3.new(-0.35, -0.75, -0.4), Light = 0.12 }),
	TunnelIgnition = table.freeze({ Ambient = Color3.fromRGB(5, 7, 6), LightColor = Color3.fromRGB(135, 220, 16), LightDirection = Vector3.new(-0.45, -0.7, -0.25), Light = 0.22 }),
	PackEntrance = table.freeze({ Ambient = Color3.fromRGB(6, 9, 7), LightColor = Color3.fromRGB(165, 210, 85), LightDirection = Vector3.new(-0.45, -0.72, -0.25), Light = 0.32 }),
	EnergyCharge = table.freeze({ Ambient = Color3.fromRGB(7, 10, 8), LightColor = Color3.fromRGB(205, 225, 195), LightDirection = Vector3.new(-0.4, -0.7, -0.3), Light = 0.42 }),
	Silhouette = table.freeze({ Ambient = Color3.fromRGB(8, 12, 9), LightColor = Color3.fromRGB(225, 235, 220), LightDirection = Vector3.new(0.1, -0.55, -0.82), Light = 0.5 }),
	Walkout = table.freeze({ Ambient = Color3.fromRGB(9, 13, 10), LightColor = Color3.fromRGB(235, 240, 228), LightDirection = Vector3.new(-0.3, -0.62, -0.45), Light = 0.56 }),
	Celebration = table.freeze({ Ambient = Color3.fromRGB(10, 14, 11), LightColor = Color3.fromRGB(235, 242, 225), LightDirection = Vector3.new(-0.28, -0.62, -0.42), Light = 0.62 }),
	RatingReveal = table.freeze({ Ambient = Color3.fromRGB(11, 16, 12), LightColor = Color3.fromRGB(235, 242, 225), LightDirection = Vector3.new(-0.3, -0.58, -0.5), Light = 0.66 }),
})

Config.GlobalLighting = table.freeze({
	Brightness = 1.08,
	Ambient = Color3.fromRGB(5, 7, 6),
	OutdoorAmbient = Color3.fromRGB(1, 2, 1),
	EnvironmentDiffuseScale = 0.18,
	EnvironmentSpecularScale = 0.46,
	ExposureCompensation = -0.38,
	BloomIntensity = 0.2,
	BloomSize = 22,
	BloomThreshold = 1.85,
	ColorCorrectionBrightness = -0.05,
	ColorCorrectionContrast = 0.2,
	ColorCorrectionSaturation = -0.08,
	AtmosphereDensity = 0.08,
	AtmosphereHaze = 0.28,
})

Config.Shots = table.freeze({
	Start = table.freeze({ Position = Vector3.new(0, 4.6, -35), Target = Vector3.new(0, 2.8, 0), FOV = 44, Duration = 0.35 }),
	Tunnel = table.freeze({ Position = Vector3.new(0, 4.1, -29), Target = Vector3.new(0, 2.55, 9), FOV = 42, Duration = 0.62 }),
	PackEntrance = table.freeze({ Position = Vector3.new(0, 4.2, -25), Target = Vector3.new(0, 2.2, -1), FOV = 39, Duration = 0.48 }),
	Charge = table.freeze({ Position = Vector3.new(0, 4.1, -23), Target = Vector3.new(0, 2.5, 0), FOV = 40, Duration = 0.62 }),
	Rupture = table.freeze({ Position = Vector3.new(0, 4.05, -20), Target = Vector3.new(0, 2.55, 2), FOV = 37, Duration = 0.24 }),
	Silhouette = table.freeze({ Position = Vector3.new(0.5, 3.7, 13.4), Target = Vector3.new(0, 2.5, 30), FOV = 37, Duration = 0.45 }),
	WalkStart = table.freeze({ Position = Vector3.new(3.8, 3.75, 16), Target = Vector3.new(0, 2.6, 26), FOV = 36, Duration = 0.35 }),
	WalkMid = table.freeze({ Position = Vector3.new(2.6, 3.75, 3.5), Target = Vector3.new(0, 2.6, 13), FOV = 34, Duration = 0.4 }),
	WalkEnd = table.freeze({ Position = Vector3.new(2, 3.75, -1.8), Target = Vector3.new(0, 2.55, 10), FOV = 32, Duration = 0.4 }),
	CelebrationLow = table.freeze({ Position = Vector3.new(-5.8, 2.45, -1.4), Target = Vector3.new(0, 2.35, 10), FOV = 31, Duration = 1.05 }),
	CelebrationSide = table.freeze({ Position = Vector3.new(7.2, 3.2, 1.4), Target = Vector3.new(0, 2.4, 10), FOV = 31, Duration = 1.25 }),
	Hero = table.freeze({ Position = Vector3.new(4.9, 3.15, -3.1), Target = Vector3.new(0, 2.35, 10), FOV = 30, Duration = 0.82 }),
	Card = table.freeze({ Position = Vector3.new(8.5, 3.2, -14), Target = Vector3.new(1.2, 2.35, 10), FOV = 30, Duration = 0.55 }),
	ResultsTransition = table.freeze({ Position = Vector3.new(0, 4.4, -22), Target = Vector3.new(0, 2.6, 10), FOV = 39, Duration = 0.38 }),
})

Config.LightStations = table.freeze({ -18, -10, -2, 6, 14, 22 })
Config.RunwaySegments = table.freeze({ -18, -8, 2, 12, 22 })

function Config.SurfaceY(surface: string): number
	if surface == "Stage" then return Config.Scene.StageY + Config.Scene.StageHeight * 0.5 end
	return Config.Scene.RunwayY + Config.Scene.RunwayHeight * 0.5
end

function Config.CluePanelBounds(): any
	local scene = Config.Scene
	return { X = scene.CluePanelX, Y = scene.CluePanelY, Width = scene.CluePanelWidth, Height = scene.CluePanelHeight }
end

function Config.HeroLayout(): any
	return { PlayerScreenCenterX = 0.44, CardScreenCenterX = Config.Scene.CardScreenCenterX, CardMinClearance = 0.22 }
end

function Config.PairedLightStationCount(): (number, number)
	return #Config.LightStations, #Config.LightStations
end

function Config.LineBandForNormalVignette(): any
	return { EdgeTransparency = Config.Scene.VignetteTransparency, CenterTransparency = Config.Scene.VignetteCenterTransparency }
end

function Config.PackEntrance(startZ: number?, endZ: number?): any
	local start = tonumber(startZ) or 24
	local finish = tonumber(endZ) or -1
	return { Start = Vector3.new(0, 1.25, start), Finish = Vector3.new(0, 1.25, finish), TravelDistance = math.abs(start - finish) }
end

return table.freeze(Config)
