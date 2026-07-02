from pathlib import Path
import re

root = Path.cwd()

module_path = root / "src/server/Gameplay/GoalShotPassThroughService.lua"
module_path.parent.mkdir(parents=True, exist_ok=True)
module_path.write_text(r'''
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
'''.strip() + "\n", encoding="utf-8")

files = [
	"src/server/Gameplay/BallService.lua",
	"src/server/Gameplay/GoalkeeperService.lua",
	"src/server/Gameplay/SetPieceService.lua",
	"src/server/Gameplay/RefereeService.lua",
]

goal_vars = {
	"isGoal",
	"didScore",
	"scored",
	"goalScored",
	"madeGoal",
	"willScore",
	"shotIsGoal",
	"resultIsGoal",
}

save_vars = {
	"willSave",
	"saved",
	"isSave",
	"wasSaved",
	"keeperSaved",
	"shotSaved",
}

def safe_ball_expr():
	return "ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall)"

def insert_require(text):
	if "VTRGoalPassThrough" in text:
		return text

	require_line = 'local VTRGoalPassThrough = require(script.Parent:WaitForChild("GoalShotPassThroughService"))\n'
	lines = text.splitlines()
	index = 0

	while index < len(lines) and lines[index].startswith("--!"):
		index += 1

	lines.insert(index, require_line.rstrip())
	return "\n".join(lines) + "\n"

def next_has_force(lines, index):
	block = "\n".join(lines[index + 1:index + 8])
	return "VTRGoalPassThrough.Force" in block or "VTRGoalPassThrough.ShouldBypass" in block or "VTRGoalPassThrough.ShouldIgnoreTouch" in block

def patch_goal_blocks(text):
	lines = text.splitlines()
	out = []

	for i, line in enumerate(lines):
		out.append(line)

		if next_has_force(lines, i):
			continue

		m = re.match(r"^(\s*)(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
		if not m:
			continue

		indent = m.group(1)
		var_name = m.group(2)
		low = line.lower()
		looks_like_roll = "vtrxgisgoal" in low or "goalpercentchance" in low or "xg" in low or "roll" in low or "goalchance" in low or "threshold" in low

		if var_name in goal_vars and looks_like_roll:
			out.append(f"{indent}if {var_name} == true then")
			out.append(f"{indent}\tVTRGoalPassThrough.Force({safe_ball_expr()}, 2.75)")
			out.append(f"{indent}end")

		if var_name in save_vars and looks_like_roll:
			out.append(f"{indent}if {var_name} == false then")
			out.append(f"{indent}\tVTRGoalPassThrough.Force({safe_ball_expr()}, 2.75)")
			out.append(f"{indent}end")

	return "\n".join(out) + "\n"

def function_args(sig):
	m = re.search(r"\((.*)\)", sig)
	if not m:
		return []

	args = []
	for raw in m.group(1).split(","):
		raw = raw.strip()
		if raw == "" or raw == "...":
			continue
		raw = raw.split(":")[0].strip()
		raw = raw.split("=")[0].strip()
		if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", raw):
			args.append(raw)
	return args

def patch_keeper_bypass(text):
	lines = text.splitlines()
	out = []

	for i, line in enumerate(lines):
		out.append(line)

		if next_has_force(lines, i):
			continue

		m = re.match(r"^(\s*)(?:local\s+)?function\s+([A-Za-z0-9_:.]+)", line)
		if not m:
			continue

		name = m.group(2).lower()
		if not any(word in name for word in ["save", "block", "touch", "intercept", "catch", "claim", "stop", "deflect", "parry"]):
			continue

		args = function_args(line)
		arg_expr = ", ".join(["self"] + args) if ":" in m.group(2) else ", ".join(args)
		if arg_expr == "":
			arg_expr = safe_ball_expr()

		indent = m.group(1) + "\t"
		out.append(f"{indent}if VTRGoalPassThrough.ShouldBypass(VTRGoalPassThrough.ResolveBall({arg_expr}) or {safe_ball_expr()}) then")
		out.append(f"{indent}\tVTRGoalPassThrough.Force(VTRGoalPassThrough.ResolveBall({arg_expr}) or {safe_ball_expr()}, 1.35)")
		out.append(f"{indent}\treturn false")
		out.append(f"{indent}end")

	return "\n".join(out) + "\n"

def patch_touched_handlers(text):
	lines = text.splitlines()
	out = []

	for i, line in enumerate(lines):
		out.append(line)

		if next_has_force(lines, i):
			continue

		m = re.search(r"\.Touched:Connect\(function\(([^)]*)\)", line)
		if not m:
			continue

		args = [x.strip().split(":")[0].strip() for x in m.group(1).split(",") if x.strip()]
		hit = args[0] if args else "hit"
		indent = re.match(r"^(\s*)", line).group(1) + "\t"
		out.append(f"{indent}if VTRGoalPassThrough.ShouldIgnoreTouch({hit}, {safe_ball_expr()}) then")
		out.append(f"{indent}\treturn")
		out.append(f"{indent}end")

	return "\n".join(out) + "\n"

for rel in files:
	path = root / rel
	if not path.exists():
		print("missing", rel)
		continue

	original = path.read_text(encoding="utf-8")
	text = original
	text = insert_require(text)
	text = patch_goal_blocks(text)
	text = patch_touched_handlers(text)

	if rel.endswith("GoalkeeperService.lua"):
		text = patch_keeper_bypass(text)

	if text != original:
		path.write_text(text, encoding="utf-8")
		print("patched", rel)
	else:
		print("unchanged", rel)