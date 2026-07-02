local Workspace = game:GetService("Workspace")

local GoalShotPassThroughService = {}

local function clockNow()
	return os.clock()
end

local function lowerName(inst)
	return string.lower(inst and inst.Name or "")
end

local function isBallInstance(inst)
	if not inst or not inst:IsA("Instance") then
		return false
	end

	local name = lowerName(inst)
	return inst:GetAttribute("IsBall") == true
		or inst:GetAttribute("VTRBall") == true
		or name == "ball"
		or string.find(name, "football") ~= nil
		or string.find(name, "soccerball") ~= nil
		or string.find(name, "matchball") ~= nil
end

function GoalShotPassThroughService.ResolveBall(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)

		if typeof(value) == "Instance" then
			if value:IsA("BasePart") and isBallInstance(value) then
				return value
			end

			if value:IsA("Model") and isBallInstance(value) then
				local primary = value.PrimaryPart or value:FindFirstChildWhichIsA("BasePart", true)
				return primary or value
			end
		elseif typeof(value) == "table" then
			local keys = { "Ball", "ball", "BallPart", "ballPart", "CurrentBall", "currentBall", "MatchBall", "matchBall" }
			for _, key in ipairs(keys) do
				local found = GoalShotPassThroughService.ResolveBall(value[key])
				if found then
					return found
				end
			end
		end
	end

	local direct = Workspace:FindFirstChild("Ball", true)
		or Workspace:FindFirstChild("Football", true)
		or Workspace:FindFirstChild("SoccerBall", true)
		or Workspace:FindFirstChild("MatchBall", true)

	if direct then
		return GoalShotPassThroughService.ResolveBall(direct)
	end

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if (inst:IsA("BasePart") or inst:IsA("Model")) and isBallInstance(inst) then
			return GoalShotPassThroughService.ResolveBall(inst)
		end
	end

	return nil
end

local function isGoalkeeperModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if model:GetAttribute("IsGoalkeeper") == true or model:GetAttribute("Goalkeeper") == true then
		return true
	end

	local role = tostring(model:GetAttribute("Role") or model:GetAttribute("Position") or model:GetAttribute("PlayerPosition") or model:GetAttribute("VTRRole") or "")
	role = string.lower(role)

	if string.find(role, "goalkeeper") or role == "gk" or string.find(role, "keeper") then
		return true
	end

	local name = lowerName(model)
	return string.find(name, "goalkeeper") ~= nil or string.find(name, "keeper") ~= nil or string.find(name, "gk") ~= nil
end

local function setPartPassThrough(part, duration)
	if not part or not part:IsA("BasePart") then
		return
	end

	local untilClock = clockNow() + duration
	part:SetAttribute("VTRGoalPassThroughUntil", untilClock)

	if part:GetAttribute("VTRGoalPassOldSet") ~= true then
		part:SetAttribute("VTRGoalPassOldSet", true)
		part:SetAttribute("VTRGoalPassOldCanCollide", part.CanCollide)
	end

	part.CanCollide = false

	task.delay(duration + 0.05, function()
		if not part.Parent then
			return
		end

		if tonumber(part:GetAttribute("VTRGoalPassThroughUntil")) and tonumber(part:GetAttribute("VTRGoalPassThroughUntil")) > clockNow() then
			return
		end

		local old = part:GetAttribute("VTRGoalPassOldCanCollide")
		if typeof(old) == "boolean" then
			part.CanCollide = old
		end

		part:SetAttribute("VTRGoalPassOldSet", nil)
		part:SetAttribute("VTRGoalPassOldCanCollide", nil)
		part:SetAttribute("VTRGoalPassThroughUntil", nil)
	end)
end

local function markInstance(inst, duration)
	if not inst or not inst:IsA("Instance") then
		return
	end

	local untilClock = clockNow() + duration
	inst:SetAttribute("VTRForceGoalThroughKeeper", true)
	inst:SetAttribute("VTRForceGoalThroughKeeperUntil", untilClock)

	if inst:IsA("BasePart") then
		setPartPassThrough(inst, duration)
	end

	for _, child in ipairs(inst:GetDescendants()) do
		if child:IsA("BasePart") then
			setPartPassThrough(child, duration)
		end
	end

	task.delay(duration + 0.05, function()
		if not inst.Parent then
			return
		end

		if tonumber(inst:GetAttribute("VTRForceGoalThroughKeeperUntil")) and tonumber(inst:GetAttribute("VTRForceGoalThroughKeeperUntil")) > clockNow() then
			return
		end

		inst:SetAttribute("VTRForceGoalThroughKeeper", nil)
		inst:SetAttribute("VTRForceGoalThroughKeeperUntil", nil)
	end)
end

local function ghostGoalkeepers(duration)
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and isGoalkeeperModel(inst) then
			for _, child in ipairs(inst:GetDescendants()) do
				if child:IsA("BasePart") then
					setPartPassThrough(child, duration)
				end
			end
		end
	end
end

function GoalShotPassThroughService.Force(ball, duration)
	duration = tonumber(duration) or 2.5

	local resolved = GoalShotPassThroughService.ResolveBall(ball)
	if resolved then
		markInstance(resolved, duration)
		local model = resolved:FindFirstAncestorOfClass("Model")
		if model and isBallInstance(model) then
			markInstance(model, duration)
		end
	end

	ghostGoalkeepers(duration)
end

function GoalShotPassThroughService.ShouldBypass(ball)
	local resolved = GoalShotPassThroughService.ResolveBall(ball)
	if not resolved then
		return false
	end

	local untilClock = tonumber(resolved:GetAttribute("VTRForceGoalThroughKeeperUntil")) or 0
	if resolved:GetAttribute("VTRForceGoalThroughKeeper") == true and untilClock > clockNow() then
		return true
	end

	local model = resolved:FindFirstAncestorOfClass("Model")
	if model then
		local modelUntil = tonumber(model:GetAttribute("VTRForceGoalThroughKeeperUntil")) or 0
		return model:GetAttribute("VTRForceGoalThroughKeeper") == true and modelUntil > clockNow()
	end

	return false
end

function GoalShotPassThroughService.ShouldIgnoreTouch(hit, ball)
	if not GoalShotPassThroughService.ShouldBypass(ball) then
		return false
	end

	local model = hit and hit:FindFirstAncestorOfClass("Model")
	if isGoalkeeperModel(model) then
		GoalShotPassThroughService.Force(ball, 1.25)
		return true
	end

	return false
end

return GoalShotPassThroughService
