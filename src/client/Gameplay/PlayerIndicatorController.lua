--!strict
local Players = game:GetService("Players")

local Controller = {}
Controller.__index = Controller

local COLORS = {
	ActiveUser = Color3.fromHex("B7FF1A"),
	NextSwitch = Color3.fromHex("78A832"),
	OpponentTarget = Color3.fromHex("FF4D5A"),
	PassTarget = Color3.fromHex("B7FF1A"),
	BallCarrier = Color3.fromHex("FFFFFF"),
	OffsideWarning = Color3.fromHex("FFB020"),
}

local function rootOf(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function makeRing(): Part
	local ring = Instance.new("Part")
	ring.Name = "VTRActiveIndicator"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, 4.25, 4.25)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = COLORS.ActiveUser
	ring.Transparency = 0.36
	ring.Parent = workspace
	return ring
end

local function makeMarker(kind: string, color: Color3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "VTR" .. kind
	gui.Size = UDim2.fromOffset(28, 24)
	gui.StudsOffsetWorldSpace = kind == "PassTarget" and Vector3.new(0, 4.1, 0) or kind == "BallCarrier" and Vector3.new(0, 4.65, 0) or Vector3.new(0, 3.9, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Text = kind == "BallCarrier" and utf8.char(9679) or utf8.char(9660)
	arrow.TextColor3 = color
	arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
	arrow.TextStrokeTransparency = 0.25
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	if kind == "NextSwitch" or kind == "PassTarget" then
		gui.Size = UDim2.fromOffset(20, 17)
	end
	arrow.Parent = gui
	gui.Parent = workspace.CurrentCamera
	return gui
end

local function makeYellowCardMarker(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "VTRYellowCardIcon"
	gui.Size = UDim2.fromOffset(30, 38)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.85, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 1000
	gui.Enabled = false
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(.5, .5)
	card.Position = UDim2.fromScale(.5, .5)
	card.Size = UDim2.fromScale(.62, .82)
	card.BackgroundColor3 = Color3.fromHex("FFD83D")
	card.BorderSizePixel = 0
	card.Rotation = -8
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = .35
	stroke.Thickness = 1
	stroke.Parent = card
	local y = Instance.new("TextLabel")
	y.Name = "Y"
	y.BackgroundTransparency = 1
	y.Size = UDim2.fromScale(1, 1)
	y.Text = "Y"
	y.TextColor3 = Color3.fromRGB(20, 20, 12)
	y.TextScaled = true
	y.TextStrokeTransparency = 1
	y.Font = Enum.Font.GothamBlack
	y.Parent = card
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	gui.Parent = playerGui or workspace.CurrentCamera
	return gui
end

function Controller.new(teamModels: any, ball: BasePart, hud: any, namesMode: string?)
	local markers = {}
	for kind, color in COLORS do
		markers[kind] = makeMarker(kind, color)
	end
	local self = setmetatable({
		Ball = ball,
		HUD = hud,
		Teams = teamModels or {},
		Markers = markers,
		Ring = makeRing(),
		TargetRing = makeRing(),
		YellowCards = {},
		NamesMode = namesMode or "Active Only",
		Clock = 0,
		Pulse = 0,
	}, Controller)
	self.TargetRing.Name = "VTRPassTargetRing"
	self.TargetRing.Size = Vector3.new(0.06, 3.2, 3.2)
	self.TargetRing.Transparency = 1
	return self
end

function Controller:_setMarker(kind: string, model: Model?)
	local marker = self.Markers[kind]
	marker.Adornee = rootOf(model)
	marker.Enabled = marker.Adornee ~= nil
end

function Controller:SetActive(model: Model?)
	self.Active = model
	self:_setMarker("ActiveUser", nil)
	self:_refreshNames()
end

function Controller:SetNextSwitch(model: Model?)
	self.NextSwitch = model
	self:_setMarker("NextSwitch", nil)
	self:_refreshNames()
end

function Controller:SetOpponentTarget(model: Model?)
	self.OpponentTarget = model
	self:_setMarker("OpponentTarget", nil)
	if self.HUD then
		self.HUD:SetOpponent(model)
	end
end

function Controller:SetPassTarget(model: Model?, fallback: boolean?)
	self.PassTarget = model
	self:_setMarker("PassTarget", nil)
	local color = fallback and Color3.fromHex("FFB020") or COLORS.PassTarget
	self.TargetRing.Color = color
	local arrow = self.Markers.PassTarget:FindFirstChild("Arrow") :: TextLabel?
	if arrow then arrow.TextColor3 = color end
	if model and self.HUD then
		self.HUD:SetTeammate(model)
	end
	self:_refreshNames()
end

function Controller:SetAimDirection(direction: Vector3)
	self.AimDirection = direction
end

function Controller:SetBallCarrier(model: Model?)
	self.BallCarrier = model
	self:_setMarker("BallCarrier", model)
	self:_refreshNames()
end

function Controller:SetNamesMode(mode: string)
	if mode ~= "Off" and mode ~= "Active Only" and mode ~= "All" then
		mode = "Active Only"
	end
	self.NamesMode = mode
	self:_refreshNames()
end

function Controller:_refreshNames()
	-- Player identity belongs in the match HUD, never over the field models.
end

function Controller:_refreshYellowCards()
	for _, sideList in self.Teams do
		if type(sideList) ~= "table" then continue end
		for _, model in sideList do
			local marker = self.YellowCards[model]
			local hasYellow = model.Parent ~= nil and model:GetAttribute("VTRYellowCard") == true and model:GetAttribute("VTRSentOff") ~= true and model:GetAttribute("VTRRedCard") ~= true
			if hasYellow then
				if not marker then
					marker = makeYellowCardMarker()
					self.YellowCards[model] = marker
				end
				marker.Adornee = rootOf(model)
				marker.Enabled = marker.Adornee ~= nil
				local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
				if playerGui and marker.Parent ~= playerGui then
					marker.Parent = playerGui
				end
			elseif marker then
				marker:Destroy()
				self.YellowCards[model] = nil
			end
		end
	end
end

function Controller:_nearest(side: string, point: Vector3, exclude: Model?): Model?
	local best: Model? = nil
	local distance = math.huge
	local list = self.Teams[side]
	if type(list) ~= "table" then
		return nil
	end
	for _, model in list do
		if model ~= exclude then
			local root = rootOf(model)
			if root then
				local value = (root.Position - point).Magnitude
				if value < distance then
					distance = value
					best = model
				end
			end
		end
	end
	return best
end

function Controller:_passTarget(side: string, origin: Vector3): Model?
	local direction = self.AimDirection
	local list = self.Teams[side]
	if not direction or direction.Magnitude < 0.1 or type(list) ~= "table" then
		return nil
	end
	local best: Model? = nil
	local bestScore = -math.huge
	for _, model in list do
		if model ~= self.Active then
			local root = rootOf(model)
			if root then
				local offset = root.Position - origin
				local distance = offset.Magnitude
				if distance > 2 and distance < 75 then
					local score = offset.Unit:Dot(direction.Unit) * 2 - distance / 90
					if score > bestScore then
						bestScore = score
						best = model
					end
				end
			end
		end
	end
	return bestScore > 0.15 and best or nil
end

function Controller:Update(dt: number)
	self.Pulse += dt
	local activeRoot = rootOf(self.Active)
	if activeRoot then
		self.Ring.CFrame = CFrame.new(activeRoot.Position - Vector3.new(0, 2.85, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	self.Ring.Transparency = 1
	self.TargetRing.Transparency = 1
	self.Clock += dt
	if self.Clock < 0.16 then
		return
	end
	self.Clock = 0
	self:_refreshYellowCards()
	self:SetNextSwitch(nil)
	self:SetOpponentTarget(nil)
	self:SetPassTarget(nil)
end

function Controller:Destroy()
	if self.Ring then
		self.Ring:Destroy()
	end
	if self.TargetRing then self.TargetRing:Destroy() end
	for _, marker in self.Markers do
		marker:Destroy()
	end
	for _, marker in self.YellowCards do
		marker:Destroy()
	end
end

return Controller
