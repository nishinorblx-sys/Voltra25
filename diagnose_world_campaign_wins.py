from pathlib import Path
import re

root = Path.cwd()
src = root / "src"

targets = []

def score_file(path, text):
	low = (path.as_posix() + "\n" + text).lower()
	score = 0

	for word in ["campaign", "worldcup", "world cup", "fixture", "objective", "mission"]:
		if word in low:
			score += 10

	for word in ["win", "wins", "won", "victory", "result", "complete", "finish", "matchend", "endmatch", "award", "progress"]:
		if word in low:
			score += 5

	for word in ["profile", "data", "stats", "progression", "save", "publish", "dataupdated", "requestdata"]:
		if word in low:
			score += 3

	if "serverapp" in low:
		score -= 100

	return score

def functions(text):
	return re.findall(r"(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_:\.]*)\s*\(([^)]*)\)", text)

def lines_with(text, needles):
	out = []
	for index, line in enumerate(text.splitlines(), 1):
		low = line.lower()
		if any(n in low for n in needles):
			out.append((index, line.strip()))
	return out

for path in sorted(src.rglob("*.lua")):
	text = path.read_text(encoding="utf-8", errors="ignore")
	score = score_file(path, text)

	if score <= 10:
		continue

	funcs = functions(text)
	interesting_lines = lines_with(text, [
		"campaign",
		"worldcup",
		"world cup",
		"fixture",
		"objective",
		"mission",
		"wins",
		"won",
		"victory",
		"result",
		"complete",
		"finish",
		"award",
		"progress",
	])

	targets.append((score, path, funcs, interesting_lines[:30]))

targets.sort(reverse=True, key=lambda item: item[0])

print("TOP CANDIDATE FILES")
print("===================")

for score, path, funcs, interesting_lines in targets[:25]:
	print()
	print(path.relative_to(root).as_posix(), "score", score)

	if funcs:
		print("functions:")
		for name, args in funcs[:12]:
			print(" ", name + "(" + args + ")")

	if interesting_lines:
		print("lines:")
		for line_no, line in interesting_lines[:18]:
			print(" ", str(line_no) + ":", line)

print()
print("SEARCH THESE FIRST IN STUDIO IF NEEDED")
print("CampaignService")
print("WorldCupService")
print("FixtureService")
print("ObjectiveService")
print("MatchRuntimeService")
print("ProgressionService")
print("ProfileService")