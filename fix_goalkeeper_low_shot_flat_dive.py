powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Content -Path fix_goalkeeper_low_shot_flat_dive.py -Encoding UTF8 -Value @'
from pathlib import Path

root = Path.cwd()

service_path = root / 'src/server/Gameplay/GoalkeeperLowShotDiveService.lua'
runner_path = root / 'src/server/GoalkeeperLowShotDive.server.lua'

service_path.parent.mkdir(parents=True, exist_ok=True)

service_path.write_text(r'''
local RunService = game:GetService("RunService")

local GoalkeeperLowShotDiveService = {}

GoalkeeperLowShotDiveService.Running = false
GoalkeeperLowShotDiveService.LowShotUntil = 0
GoalkeeperLowShotDiveService.BaseY = setmetatable({}, { __mode = "k" })

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

local function isKeeperModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	local name = lower(model.Name)

	if string.find(name, "goalkeeper", 1, true) or string.find(name, "keeper", 1, true) or name == "gk" then
		return true
	end

	if model:GetAttribute("Goalkeeper") == true or model:GetAttribute("VTRGoalkeeper") == true or model:GetAttribute("IsGoalkeeper") == true then
		return true
	end

	local role = lower(model:GetAttribute("Role") or model:GetAttribute("Position") or model:GetAttribute("PrimaryPosition"))
	return role == "gk" or role == "goalkeeper"
end

local function keeperRoot(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
end

local function ballLowForKeeper(ball, root)
	if not ball or not root then
		return false
	end

	local velocity = ball.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	if horizontal < 24 then
		return false
	end

	if math.abs(velocity.Y) > 18 then
		return false
	end

	if ball.Position.Y > root.Position.Y + 4.25 then
		return false
	end

	return true
end

local function neutralizeVerticalMover(descendant)
	if descendant:IsA("BodyVelocity") then
		local velocity = descendant.Velocity
		descendant.Velocity = Vector3.new(velocity.X, 0, velocity.Z)
	elseif descendant:IsA("LinearVelocity") then
		local velocity = descendant.VectorVelocity
		descendant.VectorVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	end
end

local function flattenKeeper(self, model, humanoid, root)
	local now = os.clock()

	if not self.BaseY[model] or now - (model:GetAttribute("VTRLowDiveStartedAt") or 0) > 1.15 then
		self.BaseY[model] = root.Position.Y
		model:SetAttribute("VTRLowDiveStartedAt", now)
	end

	humanoid.Jump = false

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown then
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)

	local baseY = self.BaseY[model]
	if baseY and root.Position.Y > baseY + 0.9 then
		local cf = root.CFrame
		root.CFrame = CFrame.new(root.Position.X, baseY + 0.15, root.Position.Z) * (cf - cf.Position)
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		neutralizeVerticalMover(descendant)
	end

	model:SetAttribute("VTRLowShotFlatDive", true)
end

local function clearKeeper(self, model)
	if model then
		model:SetAttribute("VTRLowShotFlatDive", false)
		self.BaseY[model] = nil
	end
end

function GoalkeeperLowShotDiveService:Step()
	local ball = findBall()
	local now = os.clock()

	if not ball then
		return
	end

	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and isKeeperModel(model) then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = keeperRoot(model)

			if humanoid and root and ballLowForKeeper(ball, root) and (root.Position - ball.Position).Magnitude <= 70 then
				self.LowShotUntil = now + 0.85
				flattenKeeper(self, model, humanoid, root)
			elseif now > self.LowShotUntil then
				clearKeeper(self, model)
			end
		end
	end
end

function GoalkeeperLowShotDiveService:Start()
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

return GoalkeeperLowShotDiveService
'''.strip() + '\n', encoding='utf-8')

runner_path.write_text(r'''
local ServerScriptService = game:GetService("ServerScriptService")

task.defer(function()
	local vtrServer = ServerScriptService:FindFirstChild("VTRServer")
	local gameplay = vtrServer and vtrServer:FindFirstChild("Gameplay")
	local module = gameplay and gameplay:FindFirstChild("GoalkeeperLowShotDiveService")

	if module and module:IsA("ModuleScript") then
		local ok, service = pcall(require, module)
		if ok and type(service) == "table" and service.Start then
			service:Start()
		end
	end
end)
'''.strip() + '\n', encoding='utf-8')

print('created low shot flat dive patch')
'@"