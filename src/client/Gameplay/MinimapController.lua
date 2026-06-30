--!strict
local MinimapPitchComponent = require(script.Parent.Parent.Components.MinimapPitchComponent)

local Controller = {}
Controller.__index = Controller

local function sign(value: number): number
	return value >= 0 and 1 or -1
end

local function findGoalLocalZ(pitchCFrame: CFrame, goalName: string): number?
	local goal = workspace:FindFirstChild(goalName, true)
	if not goal then
		return nil
	end
	if goal:IsA("BasePart") then
		return pitchCFrame:PointToObjectSpace(goal.Position).Z
	end
	if goal:IsA("Model") then
		local pivot = goal:GetPivot()
		return pitchCFrame:PointToObjectSpace(pivot.Position).Z
	end
	return nil
end

function Controller.new(parent: Instance, pitchCFrame: CFrame, width: number, length: number, teams: any, ball: BasePart, mode: string?, orientation: string?, cameraSide: string?, controlledSide: string?)
	local view = MinimapPitchComponent.new(parent, mode or "Medium")
	view:SetVisible(false)
	view:SetOrientation(orientation or "Broadcast")
	local homeGoalZ = findGoalLocalZ(pitchCFrame, "HomeGoal")
	local awayGoalZ = findGoalLocalZ(pitchCFrame, "AwayGoal")
	local homeGoalSign = homeGoalZ and sign(homeGoalZ) or (awayGoalZ and -sign(awayGoalZ) or 1)
	return setmetatable({
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Teams = teams or {},
		Ball = ball,
		Mode = mode or "Medium",
		Orientation = orientation or "Broadcast",
		CameraSide = cameraSide or "Near",
		ControlledSide = controlledSide or "Home",
		HomeGoalSign = homeGoalSign,
		MatchActive = false,
		View = view,
	}, Controller)
end

function Controller:SetActive(model: Model?)
	self.Active = model
end

function Controller:SetBallCarrier(model: Model?)
	self.BallCarrier = model
end

function Controller:SetMatchActive(active: boolean)
	self.MatchActive = active
	if active then
		self.View:PlayIntro()
	else
		self.View:SetVisible(false)
	end
end

function Controller:SetMode(mode: string)
	self.Mode = mode
	self.View:SetMode(mode)
	self.View:SetVisible(self.MatchActive)
end

function Controller:_map(position: Vector3): Vector2
	local localPosition = self.PitchCFrame:PointToObjectSpace(position)
	-- Fixed TV-map orientation: Home goal is always left, Away goal is always
	-- right. Read the actual HomeGoal/AwayGoal side so authored stadiums with
	-- inverted local Z still display correctly.
	local homeGoalSign = self.HomeGoalSign or 1
	return Vector2.new(
		math.clamp(0.5 - (localPosition.Z * homeGoalSign) / self.Length, 0.025, 0.975),
		math.clamp(0.5 + localPosition.X / self.Width, 0.025, 0.975)
	)
end

function Controller:Update(dt: number)
	if not self.MatchActive or self.Mode == "Off" then
		return
	end
	for _, model in self.Teams.Home or {} do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local carrier = model == self.BallCarrier
			self.View:UpdateDot(model, self:_map(root.Position), carrier and Color3.fromHex("FFE45C") or Color3.fromHex("2D9CFF"), carrier and 9 or 6, dt)
		end
	end
	for _, model in self.Teams.Away or {} do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local carrier = model == self.BallCarrier
			self.View:UpdateDot(model, self:_map(root.Position), carrier and Color3.fromHex("FFE45C") or Color3.fromHex("FF594D"), carrier and 9 or 6, dt)
		end
	end
	if self.Ball.Parent then
		self.View:UpdateDot("Ball", self:_map(self.Ball.Position), Color3.fromHex("FFE45C"), 5, dt)
	end
end

function Controller:Destroy()
	self.View:Destroy()
end

return Controller
