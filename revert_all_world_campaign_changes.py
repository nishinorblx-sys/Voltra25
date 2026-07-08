from pathlib import Path
import subprocess
import sys

root = Path.cwd()

subjects = [
	"Guard world campaign win progress calls",
	"Fix world campaign progress loader crash",
	"Register campaign and world cup wins",
]

subprocess.call(["git", "revert", "--abort"], cwd=root)

log = subprocess.check_output(
	["git", "log", "--format=%H%x00%s", "-n", "120"],
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
	print("could not find world campaign commits")
	subprocess.call(["git", "log", "--oneline", "-n", "40"], cwd=root)
	sys.exit(1)

for commit in hashes:
	print("reverting", commit)
	subprocess.check_call(["git", "revert", "--no-commit", commit], cwd=root)

paths = [
	root / "src/server/Services/WorldCampaignWinProgressService.lua",
	root / "src/server/WorldCampaignWinProgress.server.lua",
]

for path in paths:
	if path.exists():
		path.unlink()
		print("removed", path.relative_to(root).as_posix())

for path in sorted((root / "src/server").rglob("*.lua")):
	text = path.read_text(encoding="utf-8", errors="ignore")
	original = text

	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result, request)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data, result)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload, data)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player, payload)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, player)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(player, payload, data, result, request)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(player, payload, data, result)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(player, payload, data)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(player, payload)", "")
	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(player)", "")

	text = text.replace("pcall(function()  end)", "")
	text = text.replace("pcall(function() end)", "")

	if text != original:
		path.write_text(text.strip() + "\n", encoding="utf-8")
		print("cleaned", path.relative_to(root).as_posix())

print("reverted all world campaign win patch changes")