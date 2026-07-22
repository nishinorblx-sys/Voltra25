--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Graph = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1
	s.Transparency = transparency or 0.7
	s.Parent = parent
end

local function label(parent: Instance, value: string, pos: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = pos
	text.Size = size
	text.Text = value
	text.TextColor3 = color
	text.TextSize = textSize
	text.Font = Theme.Fonts.Strong
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 2 or 2
	text.Parent = parent
	return text
end

local function markerGlyph(kind: string): string
	if kind == "Goal" then return "o" end
	if kind == "YellowCard" then return "" end
	if kind == "RedCard" then return "" end
	if kind == "Penalty" then return "P" end
	if kind == "Substitution" then return "S" end
	return ""
end

function Graph.Render(parent: Instance, data: any, options: any?)
	options = options or {}
	for _, child in parent:GetChildren() do child:Destroy() end
	local samples = type(data) == "table" and type(data.Samples) == "table" and data.Samples or {}
	local markers = type(data) == "table" and type(data.Markers) == "table" and data.Markers or {}
	local periods = type(data) == "table" and type(data.Periods) == "table" and data.Periods or {}
	local maxTime = math.max(1, tonumber(data and data.MaxTime) or 90 * 60)
	local homeColor = options.HomeColor or Theme.Colors.Electric
	local awayColor = options.AwayColor or Color3.fromHex("24C6B8")

	local title = tostring(options.Title or "ATTACK MOMENTUM")
	label(parent, title, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), 10, Theme.Colors.Silver)

	local graph = Instance.new("Frame")
	graph.Name = "MomentumGraph"
	graph.BackgroundColor3 = Color3.fromRGB(4, 7, 8)
	graph.BackgroundTransparency = 0.04
	graph.BorderSizePixel = 0
	graph.Position = UDim2.fromOffset(0, 22)
	graph.Size = UDim2.new(1, 0, 1, -22)
	graph.ClipsDescendants = true
	graph.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 1
	graph.Parent = parent
	corner(graph, 6)
	stroke(graph, Theme.Colors.Silver, 0.82)

	local homeArea = Instance.new("Frame")
	homeArea.Name = "HomeArea"
	homeArea.BackgroundColor3 = homeColor
	homeArea.BackgroundTransparency = 0.9
	homeArea.BorderSizePixel = 0
	homeArea.Size = UDim2.fromScale(1, 0.5)
	homeArea.ZIndex = graph.ZIndex + 1
	homeArea.Parent = graph

	local awayArea = Instance.new("Frame")
	awayArea.Name = "AwayArea"
	awayArea.BackgroundColor3 = awayColor
	awayArea.BackgroundTransparency = 0.86
	awayArea.BorderSizePixel = 0
	awayArea.Position = UDim2.fromScale(0, 0.5)
	awayArea.Size = UDim2.fromScale(1, 0.5)
	awayArea.ZIndex = graph.ZIndex + 1
	awayArea.Parent = graph

	local center = Instance.new("Frame")
	center.Name = "CenterLine"
	center.AnchorPoint = Vector2.new(0, 0.5)
	center.BackgroundColor3 = Theme.Colors.White
	center.BackgroundTransparency = 0.35
	center.BorderSizePixel = 0
	center.Position = UDim2.fromScale(0, 0.5)
	center.Size = UDim2.new(1, 0, 0, 1)
	center.ZIndex = graph.ZIndex + 5
	center.Parent = graph

	for _, period in periods do
		local t = math.clamp((tonumber(period.Time) or 0) / maxTime, 0, 1)
		local line = Instance.new("Frame")
		line.Name = "PeriodDivider"
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.BackgroundColor3 = Theme.Colors.White
		line.BackgroundTransparency = 0.45
		line.BorderSizePixel = 0
		line.Position = UDim2.fromScale(t, 0)
		line.Size = UDim2.new(0, 1, 1, 0)
		line.ZIndex = graph.ZIndex + 7
		line.Parent = graph
	end

	local count = math.max(1, #samples)
	local widthScale = math.min(0.012, 0.88 / count)
	for index, sample in ipairs(samples) do
		local momentum = math.clamp(tonumber(sample.Momentum) or 0, -1, 1)
		local x = math.clamp((tonumber(sample.Time) or index) / maxTime, 0, 1)
		local height = math.max(0.018, math.abs(momentum) * 0.46)
		local bar = Instance.new("Frame")
		bar.Name = "MomentumBar"
		bar.AnchorPoint = momentum >= 0 and Vector2.new(0.5, 1) or Vector2.new(0.5, 0)
		bar.BackgroundColor3 = momentum >= 0 and homeColor or awayColor
		bar.BackgroundTransparency = 0.06
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromScale(x, 0.5)
		bar.Size = UDim2.fromScale(widthScale, 0.001)
		bar.ZIndex = graph.ZIndex + 10
		bar.Parent = graph
		TweenService:Create(bar, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(widthScale, height)}):Play()
	end

	for _, event in markers do
		local x = math.clamp((tonumber(event.Time) or 0) / maxTime, 0, 1)
		local team = tostring(event.Team or "Home")
		local kind = tostring(event.Type or "")
		local marker = Instance.new("Frame")
		marker.Name = "EventMarker"
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.BackgroundColor3 = kind == "YellowCard" and Theme.Colors.Warning or kind == "RedCard" and Theme.Colors.Danger or Theme.Colors.White
		marker.BorderSizePixel = 0
		marker.Position = UDim2.fromScale(x, team == "Away" and 0.84 or 0.16)
		marker.Size = kind == "Goal" and UDim2.fromOffset(9, 9) or UDim2.fromOffset(7, 11)
		marker.ZIndex = graph.ZIndex + 18
		marker.Parent = graph
		corner(marker, kind == "Goal" and 20 or 1)
		local glyph = markerGlyph(kind)
		if glyph ~= "" then
			local g = label(marker, glyph, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 7, Theme.Colors.Black)
			g.TextXAlignment = Enum.TextXAlignment.Center
			g.ZIndex = marker.ZIndex + 1
		end
	end
end

return Graph
