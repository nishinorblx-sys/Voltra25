from pathlib import Path
import subprocess
import sys

root = Path.cwd()

target_subject = "Make shot power over ninety overhit high"

log = subprocess.check_output(
	["git", "log", "--format=%H%x00%P%x00%s", "-n", "200"],
	cwd=root,
	text=True,
	encoding="utf-8",
	errors="ignore",
)

target = None
parent = None

for line in log.splitlines():
	parts = line.split("\x00")
	if len(parts) < 3:
		continue

	commit = parts[0]
	parents = parts[1].split()
	subject = parts[2].strip()

	if subject.lower() == target_subject.lower():
		target = commit
		parent = parents[0] if parents else None
		break

if not target or not parent:
	print("could not find shot power commit")
	sys.exit(1)

paths = [
	"src/client",
	"src/server",
	"src/shared",
]

print("shot power commit:", target)
print("restoring scripts from before it:", parent)

subprocess.check_call(["git", "restore", "--source", parent, "--"] + paths, cwd=root)

for path in paths:
	print("restored", path)

print("done")