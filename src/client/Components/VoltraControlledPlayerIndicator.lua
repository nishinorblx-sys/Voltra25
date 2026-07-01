--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Indicator = {}
Indicator.__index = Indicator

local function makeRing(): Part
	local part = Instance.new("Part")
	part.Name = "VTRControlledPlayerRing"
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromHex("FFFFFF")
	part.Transparency = 0.14
	part.Size = Vector3.new(0.18, 4.8, 4.8)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function makeBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "VTRControlledPlayerTag"
	gui.Size = UDim2.fromOffset(120, 42)
	gui.StudsOffset = Vector3.new(0, 4.25, 0)
	gui.AlwaysOnTop = true
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "Tag"
	text.BackgroundTransparency = 0.12
	text.BackgroundColor3 = Color3.fromHex("060906")
	text.BorderSizePixel = 0
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.fromScale(0.5, 0)
	text.Size = UDim2.fromOffset(84, 24)
	text.Text = "YOU"
	text.TextColor3 = Color3.fromHex("F5F7F2")
	text.TextSize = 12
	text.Font = Enum.Font.GothamBlack
	text.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("FFFFFF")
	stroke.Transparency = 0.08
	stroke.Thickness = 1.6
	stroke.Parent = text
	local point = Instance.new("TextLabel")
	point.BackgroundTransparency = 1
	point.AnchorPoint = Vector2.new(0.5, 0)
	point.Position = UDim2.fromScale(0.5, 0.48)
	point.Size = UDim2.fromOffset(30, 18)
	point.Text = "▼"
	point.TextColor3 = Color3.fromHex("FFFFFF")
	point.TextSize = 18
	point.Font = Enum.Font.GothamBlack
	point.Parent = holder
	return gui
end

function Indicator.new(modelGetter: () -> Model?)
	local self = setmetatable({}, Indicator)
	self.ModelGetter = modelGetter
	self.Ring = makeRing()
	self.Ring.Parent = workspace
	self.Highlight = Instance.new("Highlight")
	self.Highlight.Name = "VTRControlledPlayerHighlight"
	self.Highlight.FillColor = Color3.fromHex("FFFFFF")
	self.Highlight.FillTransparency = 0.78
	self.Highlight.OutlineColor = Color3.fromHex("F5F7F2")
	self.Highlight.OutlineTransparency = 0.08
	self.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	self.Highlight.Parent = workspace
	self.Tag = makeBillboard()
	self.Tag.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Connection = RunService.RenderStepped:Connect(function()
		self:_step()
	end)
	return self
end

function Indicator:_step()
	local model = self.ModelGetter and self.ModelGetter() or nil
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not model or not root or not root:IsA("BasePart") then
		self.Ring.Transparency = 1
		self.Highlight.Adornee = nil
		self.Tag.Adornee = nil
		return
	end
	self.Ring.Transparency = 0.14
	self.Ring.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.75, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	self.Highlight.Adornee = model
	self.Tag.Adornee = root
end

function Indicator:Destroy()
	if self.Connection then self.Connection:Disconnect() end
	if self.Ring then self.Ring:Destroy() end
	if self.Highlight then self.Highlight:Destroy() end
	if self.Tag then self.Tag:Destroy() end
end

return Indicator
