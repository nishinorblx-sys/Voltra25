local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GoalkeeperReturnService = {}

local tracked = {}
local started = false
local tickRate = 0.25
local accumulator = 0
local indexed = false
local ballIndex = setmetatable({}, { __mode = "k" })
local keeperIndex = setmetatable({}, { __mode = "k" })
local goalIndex = setmetatable({}, { __mode = "k" })
local ensureIndexed

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function pivotPosition(inst)
	if not inst then
		return nil
	end

	if inst:IsA("BasePart") then
		return inst.Position
	end

	if inst:IsA("Model") then
		local ok, cf = pcall(function()
			return inst:GetPivot()
		end)

		if ok then
			return cf.Position
		end

		local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
		return part and part.Position or nil
	end

	return nil
end

local function isBall(inst)
	if not inst then
		return false
	end

	local n = lower(inst.Name)
	return inst:GetAttribute("IsBall") == true
		or inst:GetAttribute("VTRBall") == true
		or n == "ball"
		or string.find(n, "football") ~= nil
		or string.find(n, "soccerball") ~= nil
		or string.find(n, "matchball") ~= nil
end

local function getBall()
	ensureIndexed()
	for inst in pairs(ballIndex) do
		if inst.Parent and (inst:IsA("BasePart") or inst:IsA("Model")) and isBall(inst) then
			if inst:IsA("Model") then
				local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
				if part then
					return part
				end
			else
				return inst
			end
		end
	end

	return nil
end

local function isKeeper(model)
	if not model:IsA("Model") then
		return false
	end

	if model:GetAttribute("IsGoalkeeper") == true or model:GetAttribute("Goalkeeper") == true then
		return true
	end

	local role = lower(model:GetAttribute("Role") or model:GetAttribute("Position") or model:GetAttribute("PlayerPosition") or model:GetAttribute("VTRRole"))
	local name = lower(model.Name)

	return role == "gk"
		or string.find(role, "goalkeeper") ~= nil
		or string.find(role, "keeper") ~= nil
		or string.find(name, "goalkeeper") ~= nil
		or string.find(name, "keeper") ~= nil
		or string.find(name, " gk") ~= nil
end

local function indexInstance(inst)
	if (inst:IsA("BasePart") or inst:IsA("Model")) and isBall(inst) then
		ballIndex[inst] = true
	end
	if inst:IsA("Model") and isKeeper(inst) then
		keeperIndex[inst] = true
	end
	if string.find(lower(inst.Name), "goal") then
		goalIndex[inst] = true
	end
end

local function unindexInstance(inst)
	ballIndex[inst] = nil
	keeperIndex[inst] = nil
	goalIndex[inst] = nil
	tracked[inst] = nil
end

ensureIndexed = function()
	if indexed then
		return
	end
	indexed = true
	for _, inst in ipairs(Workspace:GetDescendants()) do
		indexInstance(inst)
	end
	Workspace.DescendantAdded:Connect(indexInstance)
	Workspace.DescendantRemoving:Connect(unindexInstance)
end

local function getKeepers()
	ensureIndexed()
	local out = {}

	for inst in pairs(keeperIndex) do
		if inst.Parent and inst:IsA("Model") and isKeeper(inst) then
			local humanoid = inst:FindFirstChildOfClass("Humanoid")
			local root = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildWhichIsA("BasePart", true)
			if humanoid and root then
				table.insert(out, {
					model = inst,
					humanoid = humanoid,
					root = root,
				})
			end
		end
	end

	return out
end

local function findGoal(side)
	ensureIndexed()
	side = lower(side)

	for inst in pairs(goalIndex) do
		local n = lower(inst.Name)
		if inst.Parent and string.find(n, "goal") and string.find(n, side) then
			local pos = pivotPosition(inst)
			if pos then
				return pos
			end
		end
	end

	return nil
end

local function getGoals()
	local home = findGoal("home")
	local away = findGoal("away")

	if home and away then
		return home, away
	end

	local goals = {}
	for inst in pairs(goalIndex) do
		if inst.Parent and string.find(lower(inst.Name), "goal") then
			local pos = pivotPosition(inst)
			if pos then
				table.insert(goals, pos)
			end
		end
	end

	if #goals >= 2 then
		table.sort(goals, function(a, b)
			return a.Z < b.Z
		end)
		return goals[1], goals[#goals]
	end

	return Vector3.new(0, 0, -180), Vector3.new(0, 0, 180)
end

local function keeperSide(model, pos, homeGoal, awayGoal)
	local side = lower(model:GetAttribute("TeamSide") or model:GetAttribute("Team") or model:GetAttribute("Side") or model:GetAttribute("Club") or "")

	if string.find(side, "home") then
		return "Home"
	end

	if string.find(side, "away") then
		return "Away"
	end

	local homeDistance = (pos - homeGoal).Magnitude
	local awayDistance = (pos - awayGoal).Magnitude
	return homeDistance <= awayDistance and "Home" or "Away"
end

local function axisData(homeGoal, awayGoal)
	local dx = math.abs(awayGoal.X - homeGoal.X)
	local dz = math.abs(awayGoal.Z - homeGoal.Z)

	if dx > dz then
		return "X", "Z"
	end

	return "Z", "X"
end

local function component(v, axis)
	return axis == "X" and v.X or v.Z
end

local function withComponents(base, mainAxis, main, lateralAxis, lateral)
	if mainAxis == "X" then
		return Vector3.new(main, base.Y, lateral)
	end

	return Vector3.new(lateral, base.Y, main)
end

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function ownBoxInfo(side, ballPos, keeperPos, homeGoal, awayGoal)
	local ownGoal = side == "Home" and homeGoal or awayGoal
	local otherGoal = side == "Home" and awayGoal or homeGoal
	local mainAxis, lateralAxis = axisData(homeGoal, awayGoal)
	local ownMain = component(ownGoal, mainAxis)
	local otherMain = component(otherGoal, mainAxis)
	local direction = otherMain >= ownMain and 1 or -1
	local ballForward = (component(ballPos, mainAxis) - ownMain) * direction
	local keeperForward = (component(keeperPos, mainAxis) - ownMain) * direction
	local lateral = component(ballPos, lateralAxis) - component(ownGoal, lateralAxis)
	local boxLength = tonumber(Workspace:GetAttribute("PenaltyBoxLength")) or 72
	local boxWidth = tonumber(Workspace:GetAttribute("PenaltyBoxWidth")) or 58
	local ballInBox = ballForward >= -4 and ballForward <= boxLength and math.abs(lateral) <= boxWidth
	local returnMain = ownMain + direction * (boxLength - 8)
	local returnLateral = component(ownGoal, lateralAxis) + clamp(lateral * 0.22, -20, 20)
	local returnPos = withComponents(ownGoal, mainAxis, returnMain, lateralAxis, returnLateral)

	return ballInBox, keeperForward, returnPos
end

local function isChasing(model)
	for _, name in ipairs({ "ChasingBall", "KeeperChasing", "Chasing", "Charging", "RobbingBall", "ClaimingBall" }) do
		if model:GetAttribute(name) == true then
			return true
		end
	end

	return false
end

local function updateKeeper(entry, ball, homeGoal, awayGoal)
	local model = entry.model
	local humanoid = entry.humanoid
	local root = entry.root

	if not model.Parent or not root.Parent or humanoid.Health <= 0 then
		tracked[model] = nil
		return
	end

	local ballPos = ball.Position
	local keeperPos = root.Position
	local side = keeperSide(model, keeperPos, homeGoal, awayGoal)
	local ballInBox, keeperForward, returnPos = ownBoxInfo(side, ballPos, keeperPos, homeGoal, awayGoal)
	local state = tracked[model] or {
		chased = false,
		lastMove = 0,
	}
	tracked[model] = state

	if ballInBox and (keeperForward > 48 or isChasing(model)) then
		state.chased = true
	end

	if not state.chased then
		return
	end

	local distanceToReturn = (keeperPos - returnPos).Magnitude

	if ballInBox then
		return
	end

	if distanceToReturn <= 9 then
		state.chased = false
		model:SetAttribute("VTRKeeperReturningToBox", false)
		return
	end

	local now = os.clock()
	if now - state.lastMove >= 0.65 then
		state.lastMove = now
		model:SetAttribute("VTRKeeperReturningToBox", true)
		humanoid:MoveTo(returnPos)
	end
end

function GoalkeeperReturnService.Step(dt)
	accumulator += dt
	if accumulator < tickRate then
		return
	end
	accumulator = 0

	local ball = getBall()
	if not ball then
		return
	end

	local homeGoal, awayGoal = getGoals()

	for _, entry in ipairs(getKeepers()) do
		updateKeeper(entry, ball, homeGoal, awayGoal)
	end
end

function GoalkeeperReturnService.Start()
	if started then
		return
	end

	started = true
	RunService.Heartbeat:Connect(GoalkeeperReturnService.Step)
end

GoalkeeperReturnService.Start()

return GoalkeeperReturnService
