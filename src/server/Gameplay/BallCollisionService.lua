--!strict
local PhysicsService = game:GetService("PhysicsService")

local Service = {}
local GROUPS = {"Players", "Ball", "ScoredBall", "Pitch", "Goal", "GoalNet", "Stadium"}

local function isGoalDetector(instance: Instance): boolean
	local name = string.lower(instance.Name)
	return instance:GetAttribute("VTRGoalDetector") == true
		or instance.Name == "HomeGoal"
		or instance.Name == "AwayGoal"
		or string.find(name, "goaldetector", 1, true) ~= nil
		or string.find(name, "goalhitbox", 1, true) ~= nil
		or string.find(name, "goallinevolume", 1, true) ~= nil
end

local function configureGoalDetector(part: BasePart)
	part:SetAttribute("VTRGoalDetector", true)
	part.CollisionGroup = "Goal"
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
end

local function register(name: string)
	pcall(function() PhysicsService:RegisterCollisionGroup(name) end)
end

function Service.Configure()
	for _, name in GROUPS do register(name) end
	PhysicsService:CollisionGroupSetCollidable("Ball", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Ball", "Pitch", true)
	PhysicsService:CollisionGroupSetCollidable("Ball", "Goal", true)
	PhysicsService:CollisionGroupSetCollidable("Ball", "GoalNet", true)
	PhysicsService:CollisionGroupSetCollidable("Ball", "Stadium", true)
	PhysicsService:CollisionGroupSetCollidable("ScoredBall", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("ScoredBall", "Pitch", true)
	PhysicsService:CollisionGroupSetCollidable("ScoredBall", "Goal", false)
	PhysicsService:CollisionGroupSetCollidable("ScoredBall", "GoalNet", true)
	PhysicsService:CollisionGroupSetCollidable("ScoredBall", "Stadium", true)
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Pitch", true)
	PhysicsService:CollisionGroupSetCollidable("Players", "Stadium", true)
end

function Service.ApplyBall(ball: BasePart)
	Service.Configure()
	ball.CollisionGroup = "Ball"
	ball.CanCollide = true
	ball.CanTouch = true
	ball.CanQuery = true
	local model = ball.Parent
	if model and model:IsA("Model") then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= ball then descendant.CollisionGroup = "Ball";descendant.CanCollide = false;descendant.CanTouch = false;descendant.CanQuery = false end
		end
	end
end

function Service.ApplyScoredBall(ball: BasePart)
	Service.Configure()
	ball.CollisionGroup = "ScoredBall"
	ball.CanCollide = true
	ball.CanTouch = true
	ball.CanQuery = true
	local model = ball.Parent
	if model and model:IsA("Model") then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "ScoredBall"
				if descendant == ball then
					descendant.CanCollide = true
					descendant.CanTouch = true
					descendant.CanQuery = true
				end
			end
		end
	end
end

function Service.ApplyPlayers(models: {Model})
	Service.Configure()
	for _, model in models do
		for _, descendant in model:GetDescendants() do if descendant:IsA("BasePart") then descendant.CollisionGroup = "Players" end end
	end
end

function Service.ApplyWorld(folder: Instance)
	Service.Configure()
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			local name = string.lower(descendant.Name)
			descendant.CollisionGroup = string.find(name, "goal", 1, true) and "Goal" or (string.find(name, "pitch", 1, true) or string.find(name, "field", 1, true)) and "Pitch" or "Stadium"
			if isGoalDetector(descendant) then
				configureGoalDetector(descendant)
				continue
			end
			if descendant.Name == "Pitch" or descendant.Name == "PitchSurface" then
				descendant.CanCollide = true
				descendant.CanTouch = true
				descendant.CanQuery = true
			end
			if descendant.Name == "HomeGoal" or descendant.Name == "AwayGoal" then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = true
			end
		end
	end
	for _, goalName in {"HomeGoal", "AwayGoal"} do
		local goal = workspace:FindFirstChild(goalName, true)
		if goal and goal:IsA("BasePart") then
			configureGoalDetector(goal)
		end
	end
end

function Service.ApplyGoalNets()
	Service.Configure()
	local found = false
	local names = {HomeNet = true, AwayNet = true, Net = true}
	for _, item in workspace:GetDescendants() do
		local lowerName = string.lower(item.Name)
		if not isGoalDetector(item) and (names[item.Name] or string.find(lowerName, "net", 1, true)) then
			if item:IsA("BasePart") then
				found = true
				item.CollisionGroup = "GoalNet"
				item.CanCollide = true
				item.CanTouch = true
				item.CanQuery = true
				item.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.78, 0.12, 1, 1)
			end
			for _, part in item:GetDescendants() do
				if part:IsA("BasePart") then
					if isGoalDetector(part) then
						configureGoalDetector(part)
						continue
					end
					found = true
					part.CollisionGroup = "GoalNet"
					part.CanCollide = true
					part.CanTouch = true
					part.CanQuery = true
					part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.78, 0.12, 1, 1)
				end
			end
		end
	end
	if not found then
		warn("[VTR GOAL NET] Missing Workspace.Net/HomeNet/AwayNet; scored shots cannot rebound from the net.")
	end
end

return Service
