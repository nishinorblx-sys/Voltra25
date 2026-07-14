--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MatchVisualCleanupService = require(script.Parent.Parent.Services.MatchVisualCleanupService)

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

local function makeRing(options: any?, parent: Instance): Part
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
	ring.Color = options and options.RingColor or Color3.fromHex("B7FF1A")
	ring.Transparency = options and options.RingTransparency or 0.42
	ring.Parent = parent
	return ring
end

local function makeArrowPart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromHex("B7FF1A")
	part.Transparency = 1
	part.Parent = parent
	return part
end

function Indicator.new(modelGetter: () -> Model?, options: any?)
	local self = setmetatable({}, Indicator)
	self.ModelGetter = modelGetter
	self.Options = options or {}
	self.Container = Instance.new("Folder")
	self.Container.Name = "VTRControlledPlayerVisuals"
	self.Container.Parent = workspace
	MatchVisualCleanupService.RegisterTemporary(self.Container)
	if self.Options.HideTag ~= true then
		self.Tag = makeBillboard()
		self.Tag.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	self.Ring = makeRing(self.Options, self.Container)
	self.AttackArrowShaft = makeArrowPart("VTRAttackDirectionShaft", Vector3.new(.22, .07, 5.4), self.Container)
	self.AttackArrowLeft = makeArrowPart("VTRAttackDirectionLeft", Vector3.new(.22, .07, 2.25), self.Container)
	self.AttackArrowRight = makeArrowPart("VTRAttackDirectionRight", Vector3.new(.22, .07, 2.25), self.Container)
	self.Connection = RunService.RenderStepped:Connect(function()
		self:_step()
	end)
	return self
end

function Indicator:FlashSwitch(model: Model?, name: string?, position: string?, reducedMotion: boolean?)
	if model and self.ModelGetter and self.ModelGetter() ~= model then return end
	local displayName = string.upper(tostring(name or (model and model:GetAttribute("DisplayName")) or "PLAYER"))
	local displayPosition = string.upper(tostring(position or (model and model:GetAttribute("position")) or ""))
	self.SwitchText = displayPosition ~= "" and (displayName .. "  |  " .. displayPosition) or displayName
	self.SwitchFlashStartedAt = os.clock()
	self.SwitchFlashUntil = self.SwitchFlashStartedAt + (reducedMotion and .8 or 1.35)
	self.SwitchReducedMotion = reducedMotion == true
end

function Indicator:ShowAttackDirection(direction: Vector3, duration: number?, reducedMotion: boolean?)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < .05 then return end
	local model = self.ModelGetter and self.ModelGetter() or nil
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	self.AttackDirection = flat.Unit
	self.AttackDirectionStartedAt = root.Position
	self.AttackDirectionUntil = os.clock() + math.max(.5, tonumber(duration) or 6)
	self.AttackDirectionReducedMotion = reducedMotion == true
end

function Indicator:HideAttackDirection()
	self.AttackDirection = nil
	self.AttackDirectionUntil = nil
	for _, part in {self.AttackArrowShaft, self.AttackArrowLeft, self.AttackArrowRight} do
		if part then part.Transparency = 1 end
	end
end

function Indicator:_step()
	local model = self.ModelGetter and self.ModelGetter() or nil
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not model or not root or not root:IsA("BasePart") then
		if self.Tag then self.Tag.Adornee = nil end
		if self.Ring then self.Ring.Transparency = 1 end
		self:HideAttackDirection()
		return
	end
	local now = os.clock()
	if self.Tag then
		self.Tag.Adornee = root
		local text = self.Tag:FindFirstChild("Tag", true)
		if text and text:IsA("TextLabel") then
			text.Text = now < (self.SwitchFlashUntil or 0) and tostring(self.SwitchText or "YOU") or "YOU"
			text.Size = now < (self.SwitchFlashUntil or 0) and UDim2.fromOffset(122, 26) or UDim2.fromOffset(88, 26)
		end
	end
	if self.Ring then
		local baseTransparency = self.Options.RingTransparency or 0.42
		local baseSize = 5.2
		if now < (self.SwitchFlashUntil or 0) then
			local elapsed = now - (self.SwitchFlashStartedAt or now)
			local pulse = self.SwitchReducedMotion and 0 or math.max(0, 1 - elapsed / .55)
			self.Ring.Transparency = math.max(.08, baseTransparency - .24 - pulse * .1)
			baseSize += pulse * 1.8
		else
			self.Ring.Transparency = baseTransparency
		end
		self.Ring.Size = Vector3.new(.08, baseSize, baseSize)
		self.Ring.CFrame = CFrame.new(root.Position - Vector3.new(0, self.Options.FloorOffset or 2.95, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	local direction = self.AttackDirection
	if direction and self.AttackDirectionUntil and now < self.AttackDirectionUntil then
		local progressed = self.AttackDirectionStartedAt and (root.Position - self.AttackDirectionStartedAt):Dot(direction) or 0
		if progressed >= 18 then
			self:HideAttackDirection()
		else
			local floorPosition = root.Position - Vector3.new(0, self.Options.FloorOffset or 2.95, 0) + Vector3.new(0, .05, 0)
			local pulse = self.AttackDirectionReducedMotion and 0 or (math.sin(now * 5) + 1) * .08
			local center = floorPosition + direction * 8
			local tip = floorPosition + direction * 11.1
			local right = Vector3.new(direction.Z, 0, -direction.X)
			self.AttackArrowShaft.CFrame = CFrame.lookAt(center, center + direction)
			self.AttackArrowLeft.CFrame = CFrame.lookAt(tip - direction * .9 + right * .7, tip)
			self.AttackArrowRight.CFrame = CFrame.lookAt(tip - direction * .9 - right * .7, tip)
			for _, part in {self.AttackArrowShaft, self.AttackArrowLeft, self.AttackArrowRight} do
				part.Transparency = .2 + pulse
			end
		end
	elseif direction then
		self:HideAttackDirection()
	end
end

function Indicator:Destroy()
	if self.Connection then self.Connection:Disconnect() end
	if self.Tag then self.Tag:Destroy() end
	if self.Container then self.Container:Destroy() end
end

return Indicator
