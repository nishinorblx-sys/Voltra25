--!strict
local TweenService = game:GetService("TweenService")

local Component = {}
Component.__index = Component

local SIZES = {Small = Vector2.new(176, 102), Medium = Vector2.new(240, 139)}

local function line(parent: Instance, position: UDim2, size: UDim2)
	local value = Instance.new("Frame")
	value.Position = position
	value.Size = size
	value.BackgroundColor3 = Color3.fromHex("D9D9D9")
	value.BackgroundTransparency = 0.62
	value.BorderSizePixel = 0
	value.Parent = parent
	return value
end

function Component.new(parent: Instance, mode: string?)
	local root = Instance.new("Frame")
	root.Name = "VTRMinimap"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -24)
	root.BackgroundColor3 = Color3.fromHex("071109")
	root.BackgroundTransparency = 0.45
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.ZIndex = 8
	root.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = root
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromHex("D9D9D9")
	outline.Transparency = 0.86
	outline.Thickness = 1
	outline.Parent = root
	local pitch = Instance.new("Frame")
	pitch.Name = "Pitch"
	pitch.Position = UDim2.fromOffset(7, 7)
	pitch.Size = UDim2.new(1, -14, 1, -14)
	pitch.BackgroundColor3 = Color3.fromHex("123A19")
	pitch.BackgroundTransparency = 0.45
	pitch.BorderSizePixel = 0
	pitch.ZIndex = 9
	pitch.ClipsDescendants = true
	pitch.Parent = root
	local midfieldLine = line(pitch, UDim2.new(0.5, 0, 0, 0), UDim2.new(0, 1, 1, 0))
	midfieldLine.ZIndex = 10
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.fromScale(0.19, 0.32)
	circle.BackgroundTransparency = 1
	circle.ZIndex = 10
	circle.Parent = pitch
	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(1, 0)
	circleCorner.Parent = circle
	local circleStroke = Instance.new("UIStroke")
	circleStroke.Color = Color3.fromHex("D9D9D9")
	circleStroke.Transparency = 0.72
	circleStroke.Thickness = 1
	circleStroke.Parent = circle
	local areas = {}
	for _, x in {0, 1} do
		local area = Instance.new("Frame")
		area.AnchorPoint = Vector2.new(x, 0.5)
		area.Position = UDim2.fromScale(x, 0.5)
		area.Size = UDim2.fromScale(0.18, 0.48)
		area.BackgroundTransparency = 1
		area.ZIndex = 10
		area.Parent = pitch
		local areaStroke = Instance.new("UIStroke")
		areaStroke.Color = Color3.fromHex("D9D9D9")
		areaStroke.Transparency = 0.74
		areaStroke.Thickness = 1
		areaStroke.Parent = area
		table.insert(areas, area)
	end
	local self = setmetatable({Root = root, Scale = scale, Pitch = pitch, MidfieldLine = midfieldLine, Circle = circle, Areas = areas, Dots = {}, Positions = {}, IntroPlayed = false}, Component)
	self:SetMode(mode or "Medium")
	self.Root.Visible = false
	return self
end

function Component:SetOrientation(orientation: string)
	self.Orientation = orientation
	-- Both modes remain horizontal; Attacking Direction fixes the user's
	-- attacking side while Broadcast mirrors with the selected camera stand.
	self.MidfieldLine.Position = UDim2.new(0.5, 0, 0, 0)
	self.MidfieldLine.Size = UDim2.new(0, 1, 1, 0)
	self.Circle.Size = UDim2.fromScale(0.16, 0.28)
	for index, area in self.Areas do
		local x = index == 1 and 0 or 1
		area.AnchorPoint = Vector2.new(x, 0.5)
		area.Position = UDim2.fromScale(x, 0.5)
		area.Size = UDim2.fromScale(0.18, 0.48)
	end
end

function Component:SetMode(mode: string)
	local size = SIZES[mode] or SIZES.Medium
	self.Root.Size = UDim2.fromOffset(size.X, size.Y)
	self.Root.Visible = mode ~= "Off"
	self.Mode = mode
end

function Component:SetVisible(visible: boolean)
	self.Root.Visible = visible and self.Mode ~= "Off"
end

function Component:PlayIntro(force: boolean?)
	if self.Mode == "Off" then return end
	if self.IntroPlayed and not force then
		self:SetVisible(true)
		return
	end
	self.IntroPlayed = true
	local targetPosition = UDim2.new(0.5, 0, 1, -24)
	self.Root.Visible = true
	self.Root.Position = UDim2.new(0.5, 0, 1, 38)
	self.Root.BackgroundTransparency = 1
	self.Scale.Scale = 0.72
	for _, dot in self.Dots do
		dot.BackgroundTransparency = 1
	end
	TweenService:Create(self.Root, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = targetPosition, BackgroundTransparency = 0.45}):Play()
	TweenService:Create(self.Scale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	task.delay(0.16, function()
		if not self.Root.Parent then return end
		for _, dot in self.Dots do
			TweenService:Create(dot, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
		end
	end)
end

function Component:UpdateDot(key: any, normalized: Vector2, color: Color3, size: number, dt: number)
	local dot = self.Dots[key]
	if not dot then
		dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BorderSizePixel = 0
		dot.ZIndex = 12
		dot.BackgroundTransparency = self.IntroPlayed and 0 or 1
		dot.Parent = self.Pitch
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		self.Dots[key] = dot
		self.Positions[key] = normalized
	end
	local previous = self.Positions[key] or normalized
	local alpha = 1 - math.exp(-dt / 0.065)
	local smooth = previous:Lerp(normalized, alpha)
	self.Positions[key] = smooth
	dot.Position = UDim2.fromScale(smooth.X, smooth.Y)
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = color
end

function Component:Destroy()
	self.Root:Destroy()
end

return Component
