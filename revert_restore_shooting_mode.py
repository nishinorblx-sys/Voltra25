from pathlib import Path
import subprocess
import sys

root = Path.cwd()
subject = "Restore existing Studio shooting mode"

log = subprocess.check_output(
	["git", "log", "--format=%H%x00%s", "-n", "80"],
	cwd=root,
	text=True,
	encoding="utf-8",
	errors="ignore",
).splitlines()

target = None

for line in log:
	parts = line.split("\x00", 1)
	if len(parts) == 2 and parts[1].strip() == subject:
		target = parts[0]
		break

if not target:
	print("could not find commit:", subject)
	subprocess.call(["git", "log", "--oneline", "-n", "25"], cwd=root)
	sys.exit(1)

subprocess.call(["git", "revert", "--abort"], cwd=root)
subprocess.check_call(["git", "revert", "--no-commit", target], cwd=root)

print("reverted", target)