from pathlib import Path
import subprocess
import sys

root = Path.cwd()

subjects = [
	"Fix ranked path stat scaling and claimed reset",
	"Force ranked path UI and claim reset fix",
	"Apply ranked path UI fix directly",
]

log = subprocess.check_output(
	["git", "log", "--format=%H%x00%s", "-n", "120"],
	cwd=root,
	text=True,
	encoding="utf-8",
	errors="ignore",
)

found = {}

for line in log.splitlines():
	parts = line.split("\x00", 1)
	if len(parts) != 2:
		continue

	commit, subject = parts
	for wanted in subjects:
		if subject.strip().lower() == wanted.lower() and wanted not in found:
			found[wanted] = commit

missing = [subject for subject in subjects if subject not in found]

if missing:
	print("missing commits:")
	for subject in missing:
		print(subject)
	sys.exit(1)

hashes = [found[subject] for subject in subjects]

print("reverting:")
for subject in subjects:
	print(found[subject], subject)

subprocess.check_call(["git", "revert", "--no-commit"] + hashes, cwd=root)

print("reverted the three ranked path patches before the ball power change")