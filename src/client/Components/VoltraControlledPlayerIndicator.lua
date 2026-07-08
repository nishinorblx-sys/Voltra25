--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Indicator = {}
Indicator.__index = Indicator

local function makeBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "VTRControlledPlayerTag"
	gui.Size = UDim2.fromOffset(130, 54)
	gui.StudsOffset = Vector3.new(0, 4.75, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 1000
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "Tag"
	text.BackgroundTransparency = 0.42
	text.BackgroundColor3 = Color3.fromHex("060906")
	text.BorderSizePixel = 0
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.fromScale(0.5, 0)
	text.Size = UDim2.fromOffset(88, 26)
	text.Text = "YOU"
	text.TextColor3 = Color3.fromHex("F5F7F2")
	text.TextSize = 14
	text.Font = Enum.Font.GothamBlack
	text.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("B7FF1A")
	stroke.Transparency = 0.45
	stroke.Thickness = 1.75
	stroke.Parent = text
	local point = Instance.new("TextLabel")
	point.BackgroundTransparency = 1
	point.AnchorPoint = Vector2.new(0.5, 0)
	point.Position = UDim2.fromScale(0.5, 0.5)
	point.Size = UDim2.fromOffset(28, 18)
	point.Text = "V"
	point.TextColor3 = Color3.fromHex("B7FF1A")
	point.TextSize = 19
	point.Font = Enum.Font.GothamBlack
	point.Parent = holder
	return gui
end

local function makeRing(): Part
	local ring = Instance.new("Part")
	ring.Name = "VTRControlledPlayerRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, 5.2, 5.2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromHex("B7FF1A")
	ring.Transparency = 0.42
	ring.Parent = workspace
	return ring
end

function Indicator.new(modelGetter: () -> Model?)
	local self = setmetatable({}, Indicator)
	self.ModelGetter = modelGetter
	for _, item in ipairs(workspace:GetDescendants()) do
		if item.Name == "VTRControlledPlayerHighlight" or item.Name == "VTRControlledPlayerRing" then
			item:Destroy()
		end
	end
	self.Tag = makeBillboard()
	self.Tag.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Ring = makeRing()
	self.Connection = RunService.RenderStepped:Connect(function()
		self:_step()
	end)
	return self
end

function Indicator:_step()
	local model = self.ModelGetter and self.ModelGetter() or nil
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not model or not root or not root:IsA("BasePart") then
		self.Tag.Adornee = nil
		if self.Ring then self.Ring.Transparency = 1 end
		return
	end
	self.Tag.Adornee = root
	if self.Ring then
		self.Ring.Transparency = 0.42
		self.Ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.85, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

function Indicator:Destroy()
	if self.Connection then self.Connection:Disconnect() end
	if self.Tag then self.Tag:Destroy() end
	if self.Ring then self.Ring:Destroy() end
end

return Indicator
