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
	Blackout = table.freeze({ Ambient = Color3.fromRGB(4, 6, 5), LightColor = Color3.fromRGB(125, 205, 20), LightDirection = Vector3.new(-0.35, -0.75, -0.4), Light = 0.18 }),
	TunnelIgnition = table.freeze({ Ambient = Color3.fromRGB(6, 9, 7), LightColor = Color3.fromRGB(165, 255, 0), LightDirection = Vector3.new(-0.45, -0.7, -0.25), Light = 0.36 }),
	PackEntrance = table.freeze({ Ambient = Color3.fromRGB(8, 12, 9), LightColor = Color3.fromRGB(190, 235, 130), LightDirection = Vector3.new(-0.45, -0.72, -0.25), Light = 0.48 }),
	EnergyCharge = table.freeze({ Ambient = Color3.fromRGB(10, 15, 11), LightColor = Color3.fromRGB(220, 240, 215), LightDirection = Vector3.new(-0.4, -0.7, -0.3), Light = 0.58 }),
	Silhouette = table.freeze({ Ambient = Color3.fromRGB(12, 17, 13), LightColor = Color3.fromRGB(235, 240, 235), LightDirection = Vector3.new(0.1, -0.55, -0.82), Light = 0.64 }),
	Walkout = table.freeze({ Ambient = Color3.fromRGB(13, 18, 14), LightColor = Color3.fromRGB(235, 240, 235), LightDirection = Vector3.new(-0.3, -0.62, -0.45), Light = 0.7 }),
	Celebration = table.freeze({ Ambient = Color3.fromRGB(14, 20, 15), LightColor = Color3.fromRGB(235, 245, 225), LightDirection = Vector3.new(-0.28, -0.62, -0.42), Light = 0.74 }),
	RatingReveal = table.freeze({ Ambient = Color3.fromRGB(16, 22, 17), LightColor = Color3.fromRGB(235, 245, 225), LightDirection = Vector3.new(-0.3, -0.58, -0.5), Light = 0.78 }),
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
