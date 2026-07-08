from pathlib import Path

root = Path.cwd()

service_path = root / "src/server/Gameplay/GoalkeeperFallingLowShotService.lua"
runner_path = root / "src/server/GoalkeeperFallingLowShot.server.lua"

service_path.parent.mkdir(parents=True, exist_ok=True)

service_path.write_text(r'''
local RunService = game:GetService("RunService")

local Service = {}

Service.Running = false
Service.BaseY = setmetatable({}, { __mode = "k" })
Service.ActiveUntil = setmetatable({}, { __mode = "k" })
Service.LastTarget = setmetatable({}, { __mode = "k" })

local GOAL_HALF_WIDTH = 18
local CROSSBAR_HEIGHT = 12
local LONG_SHOT_MIN_DISTANCE = 58
local LONG_SHOT_MIN_TIME = 0.55
local MAX_PREDICT_TIME = 2.85
local FLAT_DIVE_WINDOW = 0.72
local KEEPER_MOVE_SPEED = 34

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function isBall(part)
	if not part or not part:IsA("BasePart") then
		return false
	end

	local name = lower(part.Name)
	return name == "ball" or name == "matchball" or name == "soccerball" or part:GetAttribute("VTRBall") == true or part:GetAttribute("IsBall") == true
end

local function findBall()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if isBall(descendant) then
			return descendant
		end
	end

	return nil
end

local function isKeeper(model)
	if not model or not model:IsA("Model") then
		return false
	end

	local name = lower(model.Name)

	if name == "gk" or string.find(name, "keeper", 1, true) or string.find(name, "goalkeeper", 1, true) then
		return true
	end

	if model:GetAttribute("Goalkeeper") == true or model:GetAttribute("VTRGoalkeeper") == true or model:GetAttribute("IsGoalkeeper") == true then
		return true
	end

	local role = lower(model:GetAttribute("Role") or model:GetAttribute("Position") or model:GetAttribute("PrimaryPosition"))
	return role == "gk" or role == "goalkeeper"
end

local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
end

local function zeroVerticalMover(item)
	if item:IsA("BodyVelocity") then
		local v = item.Velocity
		item.Velocity = Vector3.new(v.X, 0, v.Z)
	elseif item:IsA("LinearVelocity") then
		local v = item.VectorVelocity
		item.VectorVelocity = Vector3.new(v.X, 0, v.Z)
	elseif item:IsA("VectorForce") then
		local f = item.Force
		if math.abs(f.Y) > 0 then
			item.Force = Vector3.new(f.X, 0, f.Z)
		end
	end
end

local function predictCrossing(ball, root)
	local p = ball.Position
	local v = ball.AssemblyLinearVelocity
	local planeZ = root.Position.Z
	local vz = v.Z

	if math.abs(vz) < 1 then
		return nil
	end

	local t = (planeZ - p.Z) / vz

	if t < 0.08 or t > MAX_PREDICT_TIME then
		return nil
	end

	local y = p.Y + v.Y * t - 0.5 * workspace.Gravity * t * t
	local x = p.X + v.X * t
	local z = planeZ
	local distance = (Vector3.new(p.X, root.Position.Y, p.Z) - Vector3.new(root.Position.X, root.Position.Y, root.Position.Z)).Magnitude
	local falling = v.Y < 6 or y < p.Y - 1.5
	local highThenDrops = p.Y > root.Position.Y + 6 and y <= root.Position.Y + CROSSBAR_HEIGHT
	local longShot = distance >= LONG_SHOT_MIN_DISTANCE or t >= LONG_SHOT_MIN_TIME
	local onGoal = math.abs(x - root.Position.X) <= GOAL_HALF_WIDTH + 6 and y >= root.Position.Y - 2 and y <= root.Position.Y + CROSSBAR_HEIGHT + 2

	if not falling or not longShot or not onGoal then
		return nil
	end

	return {
		Time = t,
		Point = Vector3.new(x, y, z),
		Distance = distance,
		Velocity = v,
		HighThenDrops = highThenDrops,
		LowAtGoal = y <= root.Position.Y + 4.25,
	}
end

local function applyKeeperMove(self, model, humanoid, root, prediction)
	local point = prediction.Point
	local now = os.clock()

	self.LastTarget[model] = point
	model:SetAttribute("VTRLongShotPredicted", true)
	model:SetAttribute("VTRLongShotTimeToGoal", prediction.Time)
	model:SetAttribute("VTRLongShotTargetX", point.X)
	model:SetAttribute("VTRLongShotTargetY", point.Y)
	model:SetAttribute("VTRLongShotFalling", true)

	local dx = math.clamp(point.X - root.Position.X, -GOAL_HALF_WIDTH, GOAL_HALF_WIDTH)
	local absDx = math.abs(dx)

	if absDx > 0.65 and prediction.Time > 0.2 then
		local speed = math.clamp(absDx / math.max(prediction.Time, 0.28), 8, KEEPER_MOVE_SPEED)
		local vx = math.sign(dx) * speed
		local current = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(vx, math.min(current.Y, 0), current.Z * 0.35)

		pcall(function()
			humanoid:MoveTo(Vector3.new(root.Position.X + dx, root.Position.Y, root.Position.Z))
		end)
	end

	if prediction.LowAtGoal or prediction.Time <= FLAT_DIVE_WINDOW then
		if not self.BaseY[model] then
			self.BaseY[model] = root.Position.Y
		end

		self.ActiveUntil[model] = now + 0.65
		model:SetAttribute("VTRFallingLowShotDive", true)
		model:SetAttribute("VTRLowShotFlatDive", true)

		humanoid.Jump = false

		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown then
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			end)
		end

		local current = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(current.X, 0, current.Z)

		local baseY = self.BaseY[model]
		if baseY and root.Position.Y > baseY + 0.55 then
			local cf = root.CFrame
			root.CFrame = CFrame.new(root.Position.X, baseY + 0.08, root.Position.Z) * (cf - cf.Position)
		end

		for _, descendant in ipairs(model:GetDescendants()) do
			zeroVerticalMover(descendant)
		end
	end
end

local function clear(self, model)
	if os.clock() < (self.ActiveUntil[model] or 0) then
		return
	end

	model:SetAttribute("VTRLongShotPredicted", false)
	model:SetAttribute("VTRFallingLowShotDive", false)
	model:SetAttribute("VTRLowShotFlatDive", false)
	self.BaseY[model] = nil
	self.ActiveUntil[model] = nil
	self.LastTarget[model] = nil
end

function Service:Step()
	local ball = findBall()
	if not ball then
		return
	end

	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and isKeeper(model) then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = rootOf(model)

			if humanoid and root then
				local prediction = predictCrossing(ball, root)

				if prediction then
					applyKeeperMove(self, model, humanoid, root, prediction)
				else
					clear(self, model)
				end
			end
		end
	end
end

function Service:Start()
	if self.Running then
		return
	end

	self.Running = true

	RunService.Heartbeat:Connect(function()
		if self.Running then
			self:Step()
		end
	end)
end

return Service
'''.strip() + "\n", encoding="utf-8")

runner_path.write_text(r'''
local ServerScriptService = game:GetService("ServerScriptService")

task.defer(function()
	local vtrServer = ServerScriptService:FindFirstChild("VTRServer")
	local gameplay = vtrServer and vtrServer:FindFirstChild("Gameplay")
	local module = gameplay and gameplay:FindFirstChild("GoalkeeperFallingLowShotService")

	if module and module:IsA("ModuleScript") then
		local ok, service = pcall(require, module)
		if ok and type(service) == "table" and service.Start then
			service:Start()
		end
	end
end)
'''.strip() + "\n", encoding="utf-8")

old_runner = root / "src/server/GoalkeeperLowShotDive.server.lua"
old_service = root / "src/server/Gameplay/GoalkeeperLowShotDiveService.lua"

if old_runner.exists():
	old_runner.unlink()

if old_service.exists():
	old_service.unlink()

print("updated long falling shot goalkeeper prediction")