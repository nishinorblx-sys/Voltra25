--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local RadarChart = {}

local STAT_ORDER = { "PAC", "SHO", "PAS", "DRI", "DEF", "PHY" }
local MAX_RADIUS = 3.5
local RING_LEVELS = { 20, 40, 60, 80, 100 }

local function dimensions(size: any): (UDim2, number)
	if type(size) == "number" then return UDim2.fromOffset(size, size), size end
	if typeof(size) == "Vector2" then return UDim2.fromOffset(size.X, size.Y), math.min(size.X, size.Y) end
	if typeof(size) == "UDim2" then
		local pixels = math.min(size.X.Offset, size.Y.Offset)
		return size, pixels > 0 and pixels or 240
	end
	return UDim2.fromOffset(240, 240), 240
end

local function axisDirection(index: number): Vector3
	-- World Y points upward. Subtracting 60 degrees produces clockwise order:
	-- PAC, SHO, PAS, DRI, DEF, PHY.
	local angle = math.rad(90 - (index - 1) * 60)
	return Vector3.new(math.cos(angle), math.sin(angle), 0)
end

local function flatPart(parent: Instance, name: string, color: Color3, transparency: number): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CastShadow = false
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.Color = color
	wedge.Transparency = transparency
	wedge.Parent = parent
	return wedge
end

-- Creates one exact filled triangle from two right-triangle wedge prisms.
-- All points must share the same Z plane.
local function triangle(parent: Instance, first: Vector3, second: Vector3, third: Vector3, color: Color3, transparency: number, name: string)
	local a, b, c = first, second, third
	local ab = b - a
	local ac = c - a
	local bc = c - b
	local abLength = ab:Dot(ab)
	local acLength = ac:Dot(ac)
	local bcLength = bc:Dot(bc)
	if abLength > acLength and abLength > bcLength then
		c, a = a, c
	elseif acLength > abLength and acLength > bcLength then
		a, b = b, a
	end
	ab = b - a
	ac = c - a
	bc = c - b
	if bc.Magnitude < 0.001 then return end
	local depthAxis = ac:Cross(ab).Unit
	local edgeAxis = bc.Unit
	local heightAxis = edgeAxis:Cross(depthAxis).Unit
	local height = math.abs(ab:Dot(heightAxis))
	local firstBase = math.abs(ab:Dot(edgeAxis))
	local secondBase = math.abs(ac:Dot(edgeAxis))
	local thickness = 0.025

	local firstWedge = flatPart(parent, name .. "A", color, transparency)
	firstWedge.Size = Vector3.new(thickness, math.max(height, 0.001), math.max(firstBase, 0.001))
	firstWedge.CFrame = CFrame.fromMatrix((a + b) / 2, depthAxis, heightAxis, edgeAxis)

	local secondWedge = flatPart(parent, name .. "B", color, transparency)
	secondWedge.Size = Vector3.new(thickness, math.max(height, 0.001), math.max(secondBase, 0.001))
	secondWedge.CFrame = CFrame.fromMatrix((a + c) / 2, -depthAxis, heightAxis, -edgeAxis)
end

local function polygonFill(parent: Instance, points: { Vector3 }, color: Color3, transparency: number, z: number, name: string)
	local center = Vector3.new(0, 0, z)
	for index = 1, 6 do
		local first = Vector3.new(points[index].X, points[index].Y, z)
		local second = Vector3.new(points[index % 6 + 1].X, points[index % 6 + 1].Y, z)
		triangle(parent, center, first, second, color, transparency, name .. index)
	end
end

local function closedEdge(parent: Instance, first: Vector3, second: Vector3, color: Color3, width: number, z: number, name: string)
	local a = Vector3.new(first.X, first.Y, z)
	local b = Vector3.new(second.X, second.Y, z)
	local direction = b - a
	if direction.Magnitude < 0.001 then return end
	local unit = direction.Unit
	local depthAxis = Vector3.zAxis
	local widthAxis = depthAxis:Cross(unit)
	local edge = Instance.new("Part")
	edge.Name = name
	edge.Anchored = true
	edge.CanCollide = false
	edge.CastShadow = false
	edge.Material = Enum.Material.SmoothPlastic
	edge.Color = color
	edge.Size = Vector3.new(0.035, direction.Magnitude, width)
	edge.CFrame = CFrame.fromMatrix((a + b) / 2, depthAxis, unit, widthAxis)
	edge.Parent = parent
end

local function hexPoints(radius: number): { Vector3 }
	local points = {}
	for index = 1, 6 do points[index] = axisDirection(index) * radius end
	return points
end

local function label(parent: Instance, key: string, value: number, position: Vector2, pixels: number)
	local item = Instance.new("TextLabel")
	item.Name = key .. "Label"
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.BackgroundColor3 = Theme.Colors.Black
	item.BackgroundTransparency = 0.28
	item.BorderSizePixel = 0
	item.Position = UDim2.fromOffset(position.X, position.Y)
	item.Size = UDim2.fromOffset(pixels * 0.25, pixels * 0.105)
	item.Text = key .. "  " .. value
	item.TextColor3 = Theme.Colors.White
	item.TextSize = math.max(8, math.floor(pixels * 0.04))
	item.Font = Theme.Fonts.Strong
	item.ZIndex = 8
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = item
end

function RadarChart.new(parent: Instance, stats: any, size: any): Frame
	local chartSize, pixels = dimensions(size)
	local chart = Instance.new("Frame")
	chart.Name = "RadarChart"
	chart.BackgroundTransparency = 1
	chart.Size = chartSize
	chart.ClipsDescendants = false
	chart.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = chart

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "HexagonViewport"
	viewport.BackgroundColor3 = Color3.fromHex("101210")
	viewport.BackgroundTransparency = 0.08
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.new(1, 1, 1)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.ZIndex = 1
	viewport.Parent = chart
	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0, 8)
	viewportCorner.Parent = viewport
	local world = Instance.new("WorldModel")
	world.Parent = viewport

	-- Nested solid hexagons provide subtle dark ring fills. Larger rings are
	-- farther from the camera, so every level remains visible and deterministic.
	local ringColors = { "141714", "171B16", "1A1F19", "1D231C", "20281F" }
	for reverseIndex = #RING_LEVELS, 1, -1 do
		local level = RING_LEVELS[reverseIndex]
		local points = hexPoints(MAX_RADIUS * level / 100)
		polygonFill(world, points, Color3.fromHex(ringColors[reverseIndex]), 0.08, -0.12 - reverseIndex * 0.01, "RingFill" .. level)
	end
	for ringIndex, level in RING_LEVELS do
		local points = hexPoints(MAX_RADIUS * level / 100)
		for index = 1, 6 do
			closedEdge(world, points[index], points[index % 6 + 1], ringIndex == #RING_LEVELS and Theme.Colors.Silver or Color3.fromHex("687064"), ringIndex == #RING_LEVELS and 0.045 or 0.025, -0.04 + ringIndex * 0.002, "ClosedRing" .. level .. "Edge" .. index)
		end
	end

	local statPoints = {}
	for index, key in STAT_ORDER do
		local value = math.clamp(math.floor(tonumber(stats[key]) or 0), 0, 100)
		statPoints[index] = axisDirection(index) * (value / 100 * MAX_RADIUS)
	end
	polygonFill(world, statPoints, Theme.Colors.Electric, 0.42, 0.06, "PlayerStatFill")
	for index = 1, 6 do
		closedEdge(world, statPoints[index], statPoints[index % 6 + 1], Theme.Colors.White, 0.055, 0.13, "PlayerOutline" .. index)
		local point = Instance.new("Part")
		point.Name = "StatPoint" .. STAT_ORDER[index]
		point.Anchored = true
		point.CanCollide = false
		point.CastShadow = false
		point.Shape = Enum.PartType.Ball
		point.Material = Enum.Material.Neon
		point.Color = Theme.Colors.Electric
		point.Size = Vector3.new(0.17, 0.17, 0.17)
		point.Position = Vector3.new(statPoints[index].X, statPoints[index].Y, 0.23)
		point.Parent = world
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 14), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local screenCenter = Vector2.new(pixels / 2, pixels / 2)
	local labelRadius = pixels * 0.44
	for index, key in STAT_ORDER do
		local direction = axisDirection(index)
		local screenPosition = screenCenter + Vector2.new(direction.X, -direction.Y) * labelRadius
		label(chart, key, math.clamp(math.floor(tonumber(stats[key]) or 0), 0, 100), screenPosition, pixels)
	end
	return chart
end

return RadarChart
