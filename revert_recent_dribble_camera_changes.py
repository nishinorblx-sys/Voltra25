import subprocess
from pathlib import Path

messages=[
	"Ignore dribble impulses in camera",
	"Remove dribble impulse and tighten ball spacing",
	"Tighten dribble ball spacing",
	"Move dribble ball closer to feet",
	"Tune dribble ball touch spacing",
	"Tighten dribble ball and add visual impulse",
]

log=subprocess.run(["git","log","--format=%H%x09%s","-n","60"],capture_output=True,text=True,check=True).stdout
found=[]

for line in log.splitlines():
	if "\t" not in line:
		continue
	sha,subject=line.split("\t",1)
	if subject.strip() in messages:
		found.append((sha,subject.strip()))

for sha,subject in found:
	print("reverting",sha,subject)
	subprocess.run(["git","revert","--no-edit",sha],check=True)

if not found:
	print("no matching commits found")