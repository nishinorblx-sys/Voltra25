from pathlib import Path
import subprocess
import sys

root = Path.cwd()

subjects = [
	"Fix notification remote bootstrap",
	"Make shot power over ninety overhit high",
	"Fix ranked path stat scaling and claimed reset",
]

log = subprocess.check_output(
	["git", "log", "--format=%H%x00%s", "-n", "80"],
	cwd=root,
	text=True,
	encoding="utf-8",
	errors="ignore",
)

commits = {}

for line in log.splitlines():
	parts = line.split("\x00", 1)
	if len(parts) != 2:
		continue

	commit, subject = parts
	for wanted in subjects:
		if subject.strip().lower() == wanted.lower() and wanted not in commits:
			commits[wanted] = commit

missing = [subject for subject in subjects if subject not in commits]

if missing:
	print("missing commits:")
	for subject in missing:
		print(subject)
	sys.exit(1)

hashes = [commits[subject] for subject in subjects]

print("reverting:")
for subject in subjects:
	print(commits[subject], subject)

subprocess.check_call(["git", "revert", "--no-commit"] + hashes, cwd=root)
print("reverted last three Voltra patches")