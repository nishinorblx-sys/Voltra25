--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Indicator = {}
Indicator.__index = Indicator

local function makeBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "VTRControlledPlayerTag"
	gui.Size = UDim2.fromOffset(112, 46)
	gui.StudsOffset = Vector3.new(0, 4.15, 0)
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
	text.Size = UDim2.fromOffset(78, 23)
	text.Text = "YOU"
	text.TextColor3 = Color3.fromHex("F5F7F2")
	text.TextSize = 12
	text.Font = Enum.Font.GothamBlack
	text.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("F5F7F2")
	stroke.Transparency = 0.18
	stroke.Thickness = 1.25
	stroke.Parent = text
	local point = Instance.new("TextLabel")
	point.BackgroundTransparency = 1
	point.AnchorPoint = Vector2.new(0.5, 0)
	point.Position = UDim2.fromScale(0.5, 0.46)
	point.Size = UDim2.fromOffset(28, 18)
	point.Text = "▼"
	point.TextColor3 = Color3.fromHex("F5F7F2")
	point.TextSize = 17
	point.Font = Enum.Font.GothamBlack
	point.Parent = holder
	return gui
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
		return
	end
	self.Tag.Adornee = root
end

function Indicator:Destroy()
	if self.Connection then self.Connection:Disconnect() end
	if self.Tag then self.Tag:Destroy() end
end

return Indicator
