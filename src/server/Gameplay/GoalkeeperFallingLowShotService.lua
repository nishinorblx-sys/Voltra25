local RunService = game:GetService("RunService")

local Service = {}

Service.Running = false
Service.BaseY = setmetatable({}, { __mode = "k" })
Service.ActiveUntil = setmetatable({}, { __mode = "k" })

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

local function predictedHeightAtKeeper(ball, root)
	local velocity = ball.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude

	if speed < 24 then
		return nil
	end

	local offset = root.Position - ball.Position
	local along = offset:Dot(flat.Unit)

	if along < -6 or along > 95 then
		return nil
	end

	local timeToKeeper = along / speed

	if timeToKeeper < 0 or timeToKeeper > 1.6 then
		return nil
	end

	return ball.Position.Y + velocity.Y * timeToKeeper + 0.5 * workspace.Gravity * -1 * timeToKeeper * timeToKeeper, timeToKeeper, along, velocity
end

local function isFallingLowShot(ball, root)
	local height, timeToKeeper, distance, velocity = predictedHeightAtKeeper(ball, root)

	if not height then
		return false
	end

	if velocity.Y > 8 then
		return false
	end

	if ball.Position.Y < root.Position.Y + 3 and velocity.Y > -4 then
		return false
	end

	if height > root.Position.Y + 3.15 then
		return false
	end

	if distance < 18 and ball.Position.Y <= root.Position.Y + 3.25 then
		return false
	end

	return true
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

local function flatten(self, model, humanoid, root)
	local now = os.clock()

	if not self.BaseY[model] then
		self.BaseY[model] = root.Position.Y
	end

	self.ActiveUntil[model] = now + 0.55
	model:SetAttribute("VTRFallingLowShotDive", true)
	model:SetAttribute("VTRLowShotFlatDive", true)

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
	if baseY and root.Position.Y > baseY + 0.55 then
		local cf = root.CFrame
		root.CFrame = CFrame.new(root.Position.X, baseY + 0.08, root.Position.Z) * (cf - cf.Position)
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		zeroVerticalMover(descendant)
	end
end

local function clear(self, model)
	if os.clock() < (self.ActiveUntil[model] or 0) then
		return
	end

	model:SetAttribute("VTRFallingLowShotDive", false)
	model:SetAttribute("VTRLowShotFlatDive", false)
	self.BaseY[model] = nil
	self.ActiveUntil[model] = nil
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
				if isFallingLowShot(ball, root) and (root.Position - ball.Position).Magnitude <= 95 then
					flatten(self, model, humanoid, root)
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
