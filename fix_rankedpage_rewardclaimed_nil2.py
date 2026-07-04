from pathlib import Path
import re

root = Path.cwd()
path = root / "src/client/Pages/RankedPage.lua"

text = path.read_text(encoding="utf-8", errors="ignore")
original = text

helper = r'''
local function vtrRewardClaimed(value)
	if typeof(value) ~= "table" then
		return {}
	end

	if typeof(value.RewardClaimed) ~= "table" then
		value.RewardClaimed = {}
	end

	return value.RewardClaimed
end

local function vtrRankedSafe(value)
	if typeof(value) ~= "table" then
		value = {}
	end

	if typeof(value.RewardClaimed) ~= "table" then
		value.RewardClaimed = {}
	end

	if typeof(value.Rewards) ~= "table" then
		value.Rewards = {}
	end

	if typeof(value.Rank) ~= "string" then
		value.Rank = tostring(value.Rank or "Bronze")
	end

	value.Division = tonumber(value.Division) or 1
	value.Rating = tonumber(value.Rating) or 0
	value.Wins = tonumber(value.Wins) or 0
	value.Losses = tonumber(value.Losses) or 0

	return value
end
'''

if "local function vtrRewardClaimed" not in text:
    insert_at = 0
    matches = list(re.finditer(r"\nlocal\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*.*require\(.*\)", text))
    if matches:
        insert_at = matches[-1].end()
    else:
        m = re.search(r"\nlocal\s+[A-Za-z_][A-Za-z0-9_]*\s*=", text)
        insert_at = m.end() if m else 0

    text = text[:insert_at] + "\n" + helper.strip() + "\n" + text[insert_at:]

lines = text.splitlines()
out = []

for line in lines:
    if ".RewardClaimed" in line and "vtrRewardClaimed(" not in line and not re.search(r"\.RewardClaimed\s*=", line):
        line = re.sub(r"([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\.RewardClaimed", r"vtrRewardClaimed(\1)", line)

    out.append(line)

text = "\n".join(out) + "\n"

text = re.sub(
    r"(local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*[^\n]*(?:RequestData|GetData|FetchData|InvokeServer)\([^\n]*[\"']Ranked[\"'][^\n]*\))",
    r"\1\n\t\2 = vtrRankedSafe(\2)",
    text
)

text = re.sub(
    r"(\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*[^\n]*(?:RequestData|GetData|FetchData|InvokeServer)\([^\n]*[\"']Ranked[\"'][^\n]*\))",
    r"\1\n\t\2 = vtrRankedSafe(\2)",
    text
)

text = text.replace("vtrRankedSafe(vtrRankedSafe(", "vtrRankedSafe(")
text = text.replace("))\n\t", ")\n\t", 1) if "vtrRankedSafe(" in text and "vtrRankedSafe(vtrRankedSafe(" in text else text

path.write_text(text.strip() + "\n", encoding="utf-8")

print("patched src/client/Pages/RankedPage.lua")