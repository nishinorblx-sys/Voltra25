from pathlib import Path
import re

root = Path.cwd()

def write(path, text):
    p = root / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text.strip() + "\n", encoding="utf-8")

def read(path):
    p = root / path
    if not p.exists():
        return None
    return p.read_text(encoding="utf-8")

def save(path, text):
    p = root / path
    p.write_text(text.strip() + "\n", encoding="utf-8")

write("src/server/Services/VTRRemoteBootstrapService.lua", r'''
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {}

local remoteList = {
	MatchSetupAction = "RemoteEvent",
	PendingSevenWinLoginReward = "RemoteEvent",
	ConfirmSevenWinLoginReward = "RemoteFunction",
	ShowPackRewardAnimation = "RemoteEvent",
	AckPackRewardAnimation = "RemoteEvent",
}

local folderGroups = {
	SevenWinLoginRewardRemotes = {
		PendingSevenWinLoginReward = "RemoteEvent",
		ConfirmSevenWinLoginReward = "RemoteFunction",
	},
	PackRewardAnimationRemotes = {
		ShowPackRewardAnimation = "RemoteEvent",
		AckPackRewardAnimation = "RemoteEvent",
	},
}

local function getRoot()
	local root = ReplicatedStorage:FindFirstChild("VTR")
	if not root then
		root = Instance.new("Folder")
		root.Name = "VTR"
		root.Parent = ReplicatedStorage
	end
	return root
end

local function getRemotes()
	local root = getRoot()
	local remotes = root:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = root
	end
	return remotes
end

local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

function VTRRemoteBootstrapService.Start()
	local remotes = getRemotes()

	for name, className in pairs(remoteList) do
		ensureRemote(remotes, name, className)
	end

	for folderName, children in pairs(folderGroups) do
		local folder = remotes:FindFirstChild(folderName)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = folderName
			folder.Parent = remotes
		end

		for name, className in pairs(children) do
			ensureRemote(folder, name, className)
		end
	end
end

VTRRemoteBootstrapService.Start()

return VTRRemoteBootstrapService
''')

write("src/server/VTRRemoteBootstrap.server.lua", r'''
require(script.Parent.Services.VTRRemoteBootstrapService)
''')

write("src/server/Gameplay/GoalkeeperReturnService.lua", r'''
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GoalkeeperReturnService = {}

local tracked = {}
local started = false
local tickRate = 0.25
local accumulator = 0

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
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if (inst:IsA("BasePart") or inst:IsA("Model")) and isBall(inst) then
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

local function getKeepers()
	local out = {}

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and isKeeper(inst) then
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
	side = lower(side)

	for _, inst in ipairs(Workspace:GetDescendants()) do
		local n = lower(inst.Name)
		if string.find(n, "goal") and string.find(n, side) then
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
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if string.find(lower(inst.Name), "goal") then
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
''')

write("src/server/GoalkeeperReturn.server.lua", r'''
require(script.Parent.Gameplay.GoalkeeperReturnService)
''')

path = "src/client/Services/MatchSetupService.lua"
text = read(path)

if text is not None:
    original = text

    if "local function vtrWaitForMatchSetupAction" not in text:
        anchor = 'local ReplicatedStorage = game:GetService("ReplicatedStorage")'
        helper = r'''
local function vtrWaitForMatchSetupAction()
	local vtr = ReplicatedStorage:WaitForChild("VTR", 10) or ReplicatedStorage:FindFirstChild("VTR")
	local remotes = vtr and (vtr:FindFirstChild("Remotes") or vtr:WaitForChild("Remotes", 10))
	local remote = remotes and (remotes:FindFirstChild("MatchSetupAction") or remotes:WaitForChild("MatchSetupAction", 10))

	if remote then
		return remote
	end

	local fallbackRemotes = ReplicatedStorage:FindFirstChild("Remotes")
	remote = fallbackRemotes and fallbackRemotes:FindFirstChild("MatchSetupAction")

	if remote then
		return remote
	end

	warn("MatchSetupAction remote missing")
	return nil
end
'''
        if anchor in text:
            text = text.replace(anchor, anchor + "\n" + helper.strip(), 1)
        else:
            text = helper.strip() + "\n" + text

    patterns = [
        r'local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*ReplicatedStorage:WaitForChild\("VTR"\):WaitForChild\("Remotes"\):WaitForChild\("MatchSetupAction"\)',
        r'local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*ReplicatedStorage\.VTR\.Remotes:WaitForChild\("MatchSetupAction"\)',
        r'local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*ReplicatedStorage[^\n]*MatchSetupAction[^\n]*',
    ]

    replaced = False
    for pattern in patterns:
        def repl(match):
            global replaced
            replaced = True
            return "local " + match.group(1) + " = vtrWaitForMatchSetupAction()"
        text = re.sub(pattern, repl, text)

    text = re.sub(
        r'([A-Za-z_][A-Za-z0-9_]*):FireServer\(',
        r'if \1 then \1:FireServer(',
        text
    )

    text = text.replace("))\nend", ")) end\nend")

    if text != original:
        save(path, text)
        print("patched", path)
    else:
        print("unchanged", path)
else:
    print("missing", path)