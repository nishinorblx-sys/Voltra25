from pathlib import Path
import re

root = Path.cwd()

files = [
    "src/server/Gameplay/BallService.lua",
    "src/server/Gameplay/GoalkeeperService.lua",
    "src/server/Gameplay/SetPieceService.lua",
    "src/server/Gameplay/RefereeService.lua",
]

roll_names = [
    "rolledPercent",
    "rollPercent",
    "rolledNumber",
    "rollNumber",
    "displayRoll",
    "shotRoll",
    "resultRoll",
    "randomRoll",
    "rngRoll",
    "rolled",
    "roll",
]

threshold_names = [
    "goalIfRoll",
    "goalRollThreshold",
    "goalThresholdPercent",
    "thresholdPercent",
    "displayGoalIfRoll",
    "goalChancePercent",
    "xgPercent",
    "xGPercent",
    "shotXGPercent",
    "goalChance",
    "shotXG",
    "xg",
    "xG",
]

goal_vars = [
    "isGoal",
    "didScore",
    "scored",
    "goalScored",
    "madeGoal",
    "willScore",
    "shotIsGoal",
    "resultIsGoal",
]

save_vars = [
    "willSave",
    "saved",
    "isSave",
    "wasSaved",
    "keeperSaved",
    "shotSaved",
]

helper = r'''
local function vtrXGPercent(value)
	local n = tonumber(value) or 0
	if n <= 1 then
		n = n * 100
	end
	if n < 0 then
		return 0
	end
	if n > 100 then
		return 100
	end
	return n
end

local function vtrXGIsGoal(threshold, rolled)
	return vtrXGPercent(rolled) <= vtrXGPercent(threshold)
end
'''

def read(path):
    p = root / path
    if not p.exists():
        return None
    return p.read_text(encoding="utf-8")

def write(path, text):
    p = root / path
    p.write_text(text, encoding="utf-8")

def add_helper(text):
    if "local function vtrXGIsGoal" in text:
        return text
    m = re.match(r"((?:--![^\n]*\n)+)", text)
    if m:
        return text[:m.end()] + helper.strip() + "\n\n" + text[m.end():]
    return helper.strip() + "\n\n" + text

def last_name(context, names):
    best = None
    best_pos = -1
    for name in names:
        for m in re.finditer(r"\b" + re.escape(name) + r"\b", context):
            if m.start() > best_pos:
                best = name
                best_pos = m.start()
    return best

def replacement_for_comparison(line, make_goal):
    roll_alt = "|".join(re.escape(x) for x in roll_names)
    threshold_alt = "|".join(re.escape(x) for x in threshold_names)

    def goal_expr(threshold, roll):
        expr = f"vtrXGIsGoal({threshold}, {roll})"
        if not make_goal:
            expr = "not " + expr
        return expr

    line = re.sub(
        rf"\b({roll_alt})\b\s*(?:>=|>)\s*\b({threshold_alt})\b",
        lambda m: goal_expr(m.group(2), m.group(1)),
        line,
    )
    line = re.sub(
        rf"\b({threshold_alt})\b\s*(?:<=|<)\s*\b({roll_alt})\b",
        lambda m: goal_expr(m.group(1), m.group(2)),
        line,
    )
    return line

def patch_goal_percent_function(text):
    pattern = r"local function goalPercentChance\s*\((.*?)\).*?\nend"
    repl = r'''local function goalPercentChance(service, keeper, chance, rollOverride)
	local rolled = rollOverride
	if rolled == nil then
		if service and service.Random and typeof(service.Random.NextNumber) == "function" then
			rolled = service.Random:NextNumber(0, 100)
		else
			rolled = math.random() * 100
		end
	end
	return vtrXGIsGoal(chance, rolled)
end'''
    return re.sub(pattern, repl, text, flags=re.S)

def patch_lines(text):
    lines = text.splitlines()
    out = []
    for i, line in enumerate(lines):
        original = line
        stripped = line.strip()

        lhs_goal = re.match(r"^(\s*)(local\s+)?(" + "|".join(goal_vars) + r")\s*=", line)
        lhs_save = re.match(r"^(\s*)(local\s+)?(" + "|".join(save_vars) + r")\s*=", line)

        if lhs_goal:
            line = replacement_for_comparison(line, True)
        elif lhs_save:
            line = replacement_for_comparison(line, False)

        out.append(line)

        if lhs_goal or lhs_save:
            next_text = "\n".join(lines[i + 1:i + 6])
            if "vtrXGIsGoal(" in next_text:
                continue

            context_start = max(0, i - 90)
            context = "\n".join(lines[context_start:i + 1])
            roll = last_name(context, roll_names)
            threshold = last_name(context, threshold_names)

            if roll and threshold:
                indent = lhs_goal.group(1) if lhs_goal else lhs_save.group(1)
                var_name = lhs_goal.group(3) if lhs_goal else lhs_save.group(3)
                if lhs_goal:
                    block = [
                        f"{indent}if {roll} ~= nil and {threshold} ~= nil then",
                        f"{indent}\t{var_name} = vtrXGIsGoal({threshold}, {roll})",
                        f"{indent}end",
                    ]
                else:
                    block = [
                        f"{indent}if {roll} ~= nil and {threshold} ~= nil then",
                        f"{indent}\t{var_name} = not vtrXGIsGoal({threshold}, {roll})",
                        f"{indent}end",
                    ]
                out.extend(block)

    return "\n".join(out) + "\n"

for path in files:
    text = read(path)
    if text is None:
        print("missing", path)
        continue

    original = text
    text = add_helper(text)
    text = patch_goal_percent_function(text)
    text = patch_lines(text)

    if text != original:
        write(path, text)
        print("patched", path)
    else:
        print("unchanged", path)