from pathlib import Path
import re

root = Path.cwd()

shared = root / "src/shared/ShotPowerModel.lua"
shared.parent.mkdir(parents=True, exist_ok=True)

shared.write_text(r'''
local ShotPowerModel = {}

ShotPowerModel.AccurateMax = 89
ShotPowerModel.OverhitStart = 90
ShotPowerModel.MaxPercent = 100

local function numberValue(value)
	local n = tonumber(value)
	if not n then
		return nil
	end
	return n
end

function ShotPowerModel.ToPercent(power)
	local n = numberValue(power)
	if not n then
		return 0
	end

	if n <= 1.25 then
		return math.clamp(n * 100, 0, 100)
	end

	return math.clamp(n, 0, 100)
end

function ShotPowerModel.ScaleInputPower(power)
	local n = numberValue(power)
	if not n then
		return power
	end

	local percent = ShotPowerModel.ToPercent(n)
	local scaled = math.clamp(percent / ShotPowerModel.AccurateMax, 0, 1)

	if n <= 1.25 then
		return scaled
	end

	return scaled * 100
end

function ShotPowerModel.IsOverhit(power)
	return ShotPowerModel.ToPercent(power) > ShotPowerModel.OverhitStart
end

function ShotPowerModel.OverhitAmount(power)
	local percent = ShotPowerModel.ToPercent(power)

	if percent <= ShotPowerModel.OverhitStart then
		return 0
	end

	return math.clamp((percent - ShotPowerModel.OverhitStart) / (ShotPowerModel.MaxPercent - ShotPowerModel.OverhitStart), 0, 1)
end

function ShotPowerModel.HighLift(power)
	local amount = ShotPowerModel.OverhitAmount(power)

	if amount <= 0 then
		return 0
	end

	return 55 + amount * amount * 145
end

function ShotPowerModel.ApplyToVelocity(velocity, power)
	if typeof(velocity) ~= "Vector3" then
		return velocity
	end

	local lift = ShotPowerModel.HighLift(power)

	if lift <= 0 then
		return velocity
	end

	return Vector3.new(velocity.X, math.max(velocity.Y, 0) + lift, velocity.Z)
end

function ShotPowerModel.ApplyToTarget(origin, target, power)
	if typeof(target) ~= "Vector3" then
		return target
	end

	local lift = ShotPowerModel.HighLift(power)

	if lift <= 0 then
		return target
	end

	return target + Vector3.new(0, lift * 0.7, 0)
end

function ShotPowerModel.ApplyToArcHeight(arcHeight, power)
	local lift = ShotPowerModel.HighLift(power)

	if lift <= 0 then
		return arcHeight
	end

	return (tonumber(arcHeight) or 0) + lift * 0.55
end

return ShotPowerModel
'''.strip() + "\n", encoding="utf-8")

files = [
	"src/server/Gameplay/BallService.lua",
	"src/server/Gameplay/SetPieceService.lua",
	"src/client/Gameplay/PenaltyAimController.lua",
	"src/client/Gameplay/GameplayController.lua",
]

power_names = [
	"power",
	"Power",
	"shotPower",
	"kickPower",
	"chargePower",
	"rawPower",
	"inputPower",
]

target_names = [
	"target",
	"shotTarget",
	"aimTarget",
	"finalTarget",
	"goalTarget",
	"previewTarget",
]

power_expr = "vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power"

loader = r'''
local function vtrLoadShotPowerModel()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local vtr = ReplicatedStorage:FindFirstChild("VTR")
	local shared = (vtr and vtr:FindFirstChild("Shared")) or ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage
	return require(shared:WaitForChild("ShotPowerModel"))
end

local VTRShotPowerModel = vtrLoadShotPowerModel()
'''

def insert_loader(text):
	if "VTRShotPowerModel" in text:
		return text

	lines = text.splitlines()
	index = 0

	while index < len(lines) and lines[index].startswith("--!"):
		index += 1

	lines.insert(index, loader.strip())
	return "\n".join(lines) + "\n"

def clean_next_has(lines, i, phrase):
	return phrase in "\n".join(lines[i + 1:i + 5])

def patch_function_params(lines):
	out = []

	for i, line in enumerate(lines):
		out.append(line)

		if clean_next_has(lines, i, "ScaleInputPower"):
			continue

		m = re.match(r"^(\s*)(?:local\s+)?function\s+[A-Za-z0-9_:\.]+\s*\((.*)\)\s*$", line)
		if not m:
			continue

		params = m.group(2)
		names = []
		for raw in params.split(","):
			name = raw.strip().split(":")[0].strip()
			if name in power_names:
				names.append(name)

		if not names:
			continue

		indent = m.group(1) + "\t"
		first = names[0]
		out.append(f"{indent}local vtrRawShotPower = {first}")
		for name in names:
			out.append(f"{indent}{name} = VTRShotPowerModel.ScaleInputPower({name})")

	return out

def patch_assignments(lines):
	out = []

	for i, line in enumerate(lines):
		out.append(line)

		if "VTRShotPowerModel" in line:
			continue

		if clean_next_has(lines, i, "ScaleInputPower"):
			continue

		m = re.match(r"^(\s*)(local\s+)?(" + "|".join(power_names) + r")(\s*:[^=]+)?\s*=\s*(.+)$", line)
		if not m:
			continue

		indent = m.group(1)
		name = m.group(3)
		out.append(f"{indent}local vtrRawShotPower = {name}")
		out.append(f"{indent}{name} = VTRShotPowerModel.ScaleInputPower({name})")

	return out

def wrap_assignment(line, field):
	if "VTRShotPowerModel.ApplyToVelocity" in line:
		return line

	m = re.match(r"^(\s*[^=\n]*" + re.escape(field) + r"\s*=\s*)(.+)$", line)
	if not m:
		return line

	expr = m.group(2).strip()
	if expr.endswith(","):
		expr = expr[:-1].strip()
		return f"{m.group(1)}VTRShotPowerModel.ApplyToVelocity({expr}, {power_expr}),"

	return f"{m.group(1)}VTRShotPowerModel.ApplyToVelocity({expr}, {power_expr})"

def patch_velocity(lines):
	out = []

	for line in lines:
		new = line

		for field in [
			"AssemblyLinearVelocity",
			"VectorVelocity",
			"Velocity",
		]:
			if field in new and "=" in new and "VTRShotPowerModel" not in new:
				new = wrap_assignment(new, field)

		if ":ApplyImpulse(" in new and "VTRShotPowerModel.ApplyToVelocity" not in new:
			new = re.sub(
				r":ApplyImpulse\((.*)\)",
				lambda m: ":ApplyImpulse(VTRShotPowerModel.ApplyToVelocity(" + m.group(1).strip() + ", " + power_expr + "))",
				new
			)

		out.append(new)

	return out

def patch_targets(lines):
	out = []

	for i, line in enumerate(lines):
		out.append(line)

		if "VTRShotPowerModel" in line:
			continue

		if clean_next_has(lines, i, "ApplyToTarget"):
			continue

		m = re.match(r"^(\s*)(local\s+)?(" + "|".join(target_names) + r")(\s*:[^=]+)?\s*=\s*(.+)$", line)
		if not m:
			continue

		indent = m.group(1)
		name = m.group(3)
		out.append(f"{indent}if typeof({name}) == \"Vector3\" then")
		out.append(f"{indent}\t{name} = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, {name}, {power_expr})")
		out.append(f"{indent}end")

	return out

def patch_arc(lines):
	out = []

	for i, line in enumerate(lines):
		out.append(line)

		if "VTRShotPowerModel" in line:
			continue

		if clean_next_has(lines, i, "ApplyToArcHeight"):
			continue

		m = re.match(r"^(\s*)(local\s+)?(arcHeight|height|lobHeight|curveHeight)(\s*:[^=]+)?\s*=\s*(.+)$", line)
		if not m:
			continue

		indent = m.group(1)
		name = m.group(3)
		out.append(f"{indent}{name} = VTRShotPowerModel.ApplyToArcHeight({name}, {power_expr})")

	return out

def patch_text(text):
	text = insert_loader(text)
	lines = text.splitlines()
	lines = patch_function_params(lines)
	lines = patch_assignments(lines)
	lines = patch_targets(lines)
	lines = patch_arc(lines)
	lines = patch_velocity(lines)
	return "\n".join(lines) + "\n"

for rel in files:
	path = root / rel
	if not path.exists():
		print("missing", rel)
		continue

	text = path.read_text(encoding="utf-8", errors="ignore")
	new = patch_text(text)

	if new != text:
		path.write_text(new.strip() + "\n", encoding="utf-8")
		print("patched", rel)
	else:
		print("unchanged", rel)

print("patched src/shared/ShotPowerModel.lua")