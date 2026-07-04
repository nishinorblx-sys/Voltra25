--!strict
local Controller = {}
Controller.__index = Controller

function Controller.new(camera: Camera,ball:BasePart?)
	local anchor = Instance.new("Part")
	anchor.Name = "VTRGoalReticle"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(42, 42)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "VTRGoalReticleTarget"
	targetAttachment.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Name = "VTRKeeperDiveArrow"
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(Color3.fromHex("B7FF1A"))
	beam.Transparency = NumberSequence.new(0.08, 0.18)
	beam.Width0 = 0.36
	beam.Width1 = 0.08
	beam.FaceCamera = true
	beam.Enabled = false
	beam.Parent = anchor
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.fromScale(0.72, 0.72)
	circle.BackgroundTransparency = 1
	circle.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("B7FF1A")
	stroke.Thickness = 2
	stroke.Transparency = 0.12
	stroke.Parent = circle
	local glow = Instance.new("UIStroke")
	glow.Color = Color3.fromHex("B7FF1A")
	glow.Thickness = 5
	glow.Transparency = 0.72
	glow.Parent = circle
	for _, rotation in {0, 90} do
		local cross = Instance.new("Frame")
		cross.AnchorPoint = Vector2.new(0.5, 0.5)
		cross.Position = UDim2.fromScale(0.5, 0.5)
		cross.Size = UDim2.fromScale(0.48, 0.07)
		cross.Rotation = rotation
		cross.BackgroundColor3 = Color3.fromHex("B7FF1A")
		cross.BorderSizePixel = 0
		cross.Parent = gui
	end
	return setmetatable({Camera = camera,Ball=ball, Anchor = anchor, Gui = gui, Beam = beam, MatchActive = false, Mode = "Shot"}, Controller)
end

function Controller:SetMatchActive(active: boolean)
	self.MatchActive = active
	if not active then self.Gui.Enabled = false;if self.Beam then self.Beam.Enabled = false end end
end

function Controller:SetMode(mode: string?)
	self.Mode = mode == "PenaltyDefense" and "PenaltyDefense" or "Shot"
	if self.Mode ~= "PenaltyDefense" and self.Beam then self.Beam.Enabled = false end
end

function Controller:SetDefenseSource(model: Model?)
	if self.SourceAttachment then self.SourceAttachment:Destroy();self.SourceAttachment=nil end
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "VTRKeeperDiveArrowSource"
		attachment.Position = Vector3.new(0, 1.1, 0)
		attachment.Parent = root
		self.SourceAttachment = attachment
		if self.Beam then self.Beam.Attachment0 = attachment end
	end
end

function Controller:Lock(point:Vector3)
	self.LockedPoint=point;self.Gui.Enabled=true;self.Anchor.Position=point
end

function Controller:Unlock()
	self.LockedPoint=nil;self.Gui.Enabled=false
end

function Controller:Update(hasBall: boolean, shootingContext: boolean, aimingAtGoal: boolean, goalPoint: Vector3?)
	if self.LockedPoint and self.Ball and self.Ball:GetAttribute("VTRMotionKind")=="Shot"and self.Ball.AssemblyLinearVelocity.Magnitude<3 then self:Unlock()end
	local displayPoint=self.LockedPoint or (hasBall and aimingAtGoal and goalPoint or nil)
	local visible=self.MatchActive and displayPoint~=nil and(self.LockedPoint~=nil or hasBall and aimingAtGoal and goalPoint~=nil)
	self.Gui.Enabled = visible
	if self.Beam then self.Beam.Enabled = visible and self.Mode == "PenaltyDefense" and self.SourceAttachment ~= nil end
	if visible then
		self.Anchor.Position=displayPoint::Vector3
		local distance=(self.Camera.CFrame.Position-(displayPoint::Vector3)).Magnitude
		local diameter=self.Ball and self.Ball.Size.X or 2.3
		local pixels=diameter*self.Camera.ViewportSize.Y/(2*math.max(distance,1)*math.tan(math.rad(self.Camera.FieldOfView)*.5))
		local size = math.floor(math.clamp(pixels,8,28)+.5)
		self.Gui.Size = UDim2.fromOffset(size, size)
	end
end

function Controller:Destroy()
	if self.SourceAttachment then self.SourceAttachment:Destroy();self.SourceAttachment=nil end
	self.Anchor:Destroy()
end

return Controller
