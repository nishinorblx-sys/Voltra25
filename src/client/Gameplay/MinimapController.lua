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
		World = ball and ball.Parent or nil,
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
	local homeGoalSign = self.HomeGoalSign or 1
	local x = math.clamp(0.5 - (localPosition.Z * homeGoalSign) / self.Length, 0.025, 0.975)
	local y = math.clamp(0.5 + localPosition.X / self.Width, 0.025, 0.975)
	if self.Orientation == "Attacking Direction" and self.ControlledSide == "Away" then
		x = 1 - x
	elseif self.Orientation == "Broadcast" and self.CameraSide == "Far" then
		y = 1 - y
	end
	return Vector2.new(
		math.clamp(x, 0.025, 0.975),
		math.clamp(y, 0.025, 0.975)
	)
end

local function addModel(result: {Model}, seen: {[Instance]: boolean}, model: any, side: string)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or seen[model] then
		return
	end
	local team = tostring(model:GetAttribute("VTRTeam") or model:GetAttribute("teamSide") or "")
	if team ~= side then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	seen[model] = true
	table.insert(result, model)
end

function Controller:_modelsForSide(side: string): {Model}
	local result = {}
	local seen: {[Instance]: boolean} = {}
	for _, model in self.Teams[side] or {} do
		addModel(result, seen, model, side)
	end
	local world = self.World
	if (not world or not world.Parent) and self.Ball then
		world = self.Ball.Parent
		self.World = world
	end
	if world then
		for _, descendant in world:GetDescendants() do
			addModel(result, seen, descendant, side)
		end
	end
	return result
end

function Controller:Update(dt: number)
	if not self.MatchActive or self.Mode == "Off" then
		return
	end
	local seen: {[any]: boolean} = {}
	for _, model in self:_modelsForSide("Home") do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local carrier = model == self.BallCarrier
			self.View:UpdateDot(model, self:_map(root.Position), carrier and Color3.fromHex("FFE45C") or Color3.fromHex("2D9CFF"), carrier and 9 or 6, dt)
			seen[model] = true
		end
	end
	for _, model in self:_modelsForSide("Away") do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local carrier = model == self.BallCarrier
			self.View:UpdateDot(model, self:_map(root.Position), carrier and Color3.fromHex("FFE45C") or Color3.fromHex("FF594D"), carrier and 9 or 6, dt)
			seen[model] = true
		end
	end
	if self.Ball.Parent then
		self.View:UpdateDot("Ball", self:_map(self.Ball.Position), Color3.fromHex("FFE45C"), 5, dt)
		seen.Ball = true
	end
	self.View:HideExcept(seen)
end

function Controller:Destroy()
	self.View:Destroy()
end

return Controller
