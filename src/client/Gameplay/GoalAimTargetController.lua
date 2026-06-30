--!strict
local Controller = {}
Controller.__index = Controller

function Controller.new()
	local anchor = Instance.new("Part")
	anchor.Name = "VTRGoalAimTarget"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(26, 26)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.fromOffset(20, 20)
	circle.BackgroundTransparency = 1
	circle.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("B7FF1A")
	stroke.Thickness = 2
	stroke.Transparency = 0.18
	stroke.Parent = circle
	for _, rotation in {0, 90} do
		local cross = Instance.new("Frame")
		cross.AnchorPoint = Vector2.new(0.5, 0.5)
		cross.Position = UDim2.fromScale(0.5, 0.5)
		cross.Size = UDim2.fromOffset(12, 2)
		cross.Rotation = rotation
		cross.BackgroundColor3 = Color3.fromHex("B7FF1A")
		cross.BackgroundTransparency = 0.12
		cross.BorderSizePixel = 0
		cross.Parent = gui
	end
	return setmetatable({Anchor = anchor, Gui = gui, MatchActive = false}, Controller)
end

function Controller:SetMatchActive(active: boolean)
	self.MatchActive = active
	if not active then
		self.Gui.Enabled = false
	end
end

function Controller:Update(hasBall: boolean, aimingAtGoal: boolean, goalPoint: Vector3?)
	local visible = self.MatchActive and hasBall and aimingAtGoal and goalPoint ~= nil
	self.Gui.Enabled = visible
	if visible then
		self.Anchor.Position = goalPoint :: Vector3
	end
end

function Controller:Destroy()
	self.Anchor:Destroy()
end

return Controller
