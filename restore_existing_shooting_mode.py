from pathlib import Path
import subprocess
import sys
import re

root = Path.cwd()

bad_file = root / "src/client/StudioShootingPractice.client.lua"
if bad_file.exists():
	bad_file.unlink()
	print("removed src/client/StudioShootingPractice.client.lua")

log = subprocess.check_output(
	["git", "log", "--all", "--format=%H", "--", "src"],
	cwd=root,
	text=True,
	encoding="utf-8",
	errors="ignore",
).splitlines()

seen = set()
candidates = []

for commit in log[:250]:
	try:
		files = subprocess.check_output(
			["git", "ls-tree", "-r", "--name-only", commit, "src"],
			cwd=root,
			text=True,
			encoding="utf-8",
			errors="ignore",
		).splitlines()
	except Exception:
		continue

	for file in files:
		if file in seen:
			continue

		low = file.lower()
		if not file.endswith(".lua"):
			continue

		if not any(token in low for token in ["shoot", "practice", "matchsetup", "gameplaycontroller", "campaignpage", "playpage", "uicontroller"]):
			continue

		try:
			content = subprocess.check_output(
				["git", "show", commit + ":" + file],
				cwd=root,
				text=True,
				encoding="utf-8",
				errors="ignore",
			)
		except Exception:
			continue

		content_low = content.lower()
		score = 0

		for token in ["startshootingpractice", "shootingpractice", "shooting practice", "shooting_mode", "shootingmode"]:
			if token in content_low:
				score += 25

		if "runservice:isstudio" in content_low or "isstudio()" in content_low:
			score += 25

		if "page.new" in content_low or "button.new" in content_low or "onactivated" in content_low:
			score += 10

		if "matchsetupservice" in content_low:
			score += 12

		if file.startswith("src/client/Pages/"):
			score += 18

		if file.startswith("src/client/Components/"):
			score += 10

		if file.startswith("src/client/Services/"):
			score += 8

		if score >= 45:
			seen.add(file)
			candidates.append((score, commit, file, content))

candidates.sort(reverse=True, key=lambda item: item[0])

if not candidates:
	print("could not find old shooting mode in git history")
	subprocess.call(["git", "log", "--oneline", "--all", "-n", "40"], cwd=root)
	sys.exit(1)

restored = []

for score, commit, file, content in candidates[:12]:
	if "StartShootingPractice" not in content and "ShootingPractice" not in content and "shooting practice" not in content.lower():
		continue

	path = root / file
	path.parent.mkdir(parents=True, exist_ok=True)

	if path.exists():
		current = path.read_text(encoding="utf-8", errors="ignore")
		if len(current) > len(content) * 0.85 and "StartShootingPractice" in current:
			continue

	path.write_text(content.strip() + "\n", encoding="utf-8")
	restored.append(file)
	print("restored", file, "from", commit[:8], "score", score)

ui_path = root / "src/client/Controllers/UIController.lua"
if ui_path.exists():
	text = ui_path.read_text(encoding="utf-8", errors="ignore")

	if "ShootingPractice = require" not in text and (root / "src/client/Pages/ShootingPracticePage.lua").exists():
		text = text.replace(
			"Play = require(script.Parent.Parent.Pages.CampaignPage),",
			"Play = require(script.Parent.Parent.Pages.CampaignPage),\n\tShootingPractice = require(script.Parent.Parent.Pages.ShootingPracticePage),"
		)

	ui_path.write_text(text.strip() + "\n", encoding="utf-8")

page_files = [
	root / "src/client/Pages/ShootingPracticePage.lua",
	root / "src/client/Pages/ShootingPage.lua",
	root / "src/client/Pages/PracticePage.lua",
]

for page in page_files:
	if page.exists():
		text = page.read_text(encoding="utf-8", errors="ignore")
		if "RunService:IsStudio()" not in text and "game:GetService(\"RunService\")" not in text:
			text = "local RunService = game:GetService(\"RunService\")\nif not RunService:IsStudio() then return { new = function() local f = Instance.new(\"Frame\"); f.Name = \"StudioOnlyShootingModeDisabled\"; return f end } end\n" + text
		elif "RunService:IsStudio()" not in text:
			text = text.replace("local", "local", 1)
			text = re.sub(r"(local\s+RunService\s*=\s*game:GetService\(\"RunService\"\)\s*)", r"\1\nif not RunService:IsStudio() then return { new = function() local f = Instance.new(\"Frame\"); f.Name = \"StudioOnlyShootingModeDisabled\"; return f end } end\n", text, count=1)
		page.write_text(text.strip() + "\n", encoding="utf-8")

print("restored files:")
for item in restored:
	print(item)