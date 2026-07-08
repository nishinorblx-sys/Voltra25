from pathlib import Path
import re

root = Path.cwd()
path = root / "src/server/Gameplay/MatchRuntimeService.lua"

text = path.read_text(encoding="utf-8", errors="ignore")
lines = text.splitlines()

needles = [
	"POST_FINAL_WHISTLE_RESULT_DELAY",
	"FinalWhistle",
	"Final Whistle",
	"ShowResult",
	"Result",
	"MatchResult",
	"session.Ended",
	"Ended=true",
	"Ended = true",
	"HomeScore",
	"AwayScore",
	"Score",
	"WorldCup",
	"World Cup",
	"Knockout",
	"ExtraTime",
	"Penalty",
	"Shootout",
]

hits = []

for index, line in enumerate(lines, 1):
	low = line.lower()
	if any(n.lower() in low for n in needles):
		hits.append(index)

ranges = []
for hit in hits:
	start = max(1, hit - 18)
	end = min(len(lines), hit + 30)
	if ranges and start <= ranges[-1][1] + 4:
		ranges[-1] = (ranges[-1][0], max(ranges[-1][1], end))
	else:
		ranges.append((start, end))

print("MATCH RUNTIME RESULT AREAS")
print("==========================")

for start, end in ranges[:16]:
	print()
	print("LINES", start, "TO", end)
	for line_no in range(start, end + 1):
		print(str(line_no).rjust(5), lines[line_no - 1])

print()
print("FUNCTIONS NEAR RESULT LOGIC")
print("===========================")

for m in re.finditer(r"(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_:\.]*)\s*\(([^)]*)\)", text):
	name = m.group(1)
	pos_line = text[:m.start()].count("\n") + 1
	block = text[m.start():m.start() + 2200].lower()
	if any(word in block for word in ["final", "result", "ended", "full time", "worldcup", "knockout", "penalty", "shootout"]):
		print(pos_line, name + "(" + m.group(2) + ")")