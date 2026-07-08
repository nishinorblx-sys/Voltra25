from pathlib import Path
import subprocess
import sys

root = Path.cwd()

subjects = [
	"Guard world campaign win progress calls",
	"Fix world campaign progress loader crash",
]

log = subprocess.check_output(
	["git", "log", "--format=%H%x00%s", "-n", "80"],
	cwd=root,
	text=True,
	encoding="utf-8",
	errors="ignore",
).splitlines()

hashes = []

for line in log:
	parts = line.split("\x00", 1)
	if len(parts) != 2:
		continue

	commit, title = parts
	if title.strip() in subjects:
		hashes.append(commit)

if not hashes:
	print("could not find the last 2 world campaign commits")
	subprocess.call(["git", "log", "--oneline", "-n", "20"], cwd=root)
	sys.exit(1)

for commit in hashes:
	print("reverting", commit)
	subprocess.check_call(["git", "revert", "--no-commit", commit], cwd=root)

print("reverted", len(hashes), "commits")