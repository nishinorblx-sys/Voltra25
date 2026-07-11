from pathlib import Path
import re

root = Path.cwd()
targets = [
	root / "src/client/Pages/WorldCupPage.lua",
	root / "src/client/Controllers/WorldCupController.lua",
	root / "src/client/Components/WorldCupSimulation.lua",
	root / "src/client/Components/WorldCupMatchSimulator.lua",
]

existing = [p for p in targets if p.exists()]
if not existing:
	raise SystemExit("No World Cup client scripts found")

matches = []
for path in existing:
	text = path.read_text(encoding="utf-8", errors="ignore")
	for i, line in enumerate(text.splitlines(), 1):
		low = line.lower()
		if "2x" in low or "x2" in low or "speed" in low or "simulation" in low:
			matches.append((path, i, line))

print("WORLD CUP 2X / SPEED REFERENCES")
for path, line, value in matches:
	print(f"{path.relative_to(root).as_posix()}:{line}: {value}")

worldcup = root / "src/client/Pages/WorldCupPage.lua"
if not worldcup.exists():
	raise SystemExit("WorldCupPage.lua missing")

text = worldcup.read_text(encoding="utf-8", errors="ignore")
original = text

if "MarketplaceService" not in text:
	if 'local Players=game:GetService("Players")' in text:
		text = text.replace(
			'local Players=game:GetService("Players")',
			'local Players=game:GetService("Players")\nlocal MarketplaceService=game:GetService("MarketplaceService")',
			1
		)
	elif 'local Players = game:GetService("Players")' in text:
		text = text.replace(
			'local Players = game:GetService("Players")',
			'local Players = game:GetService("Players")\nlocal MarketplaceService = game:GetService("MarketplaceService")',
			1
		)
	else:
		text = 'local Players=game:GetService("Players")\nlocal MarketplaceService=game:GetService("MarketplaceService")\n' + text

if "WORLD_CUP_2X_GAMEPASS_ID" not in text:
	first_local = re.search(r"\nlocal\s+", text)
	pos = first_local.start() if first_local else 0
	text = text[:pos] + "\nlocal WORLD_CUP_2X_GAMEPASS_ID=1906308331\n" + text[pos:]

if "local function vtrOwnsWorldCup2xPass" not in text:
	helper = r'''
local function vtrOwnsWorldCup2xPass(context:any):boolean
	local player=Players.LocalPlayer
	if player:GetAttribute("VTRWorldCup2xSpeedPass")==true then
		return true
	end

	local ownership=context and context.Data and context.Data.StoreOwnership
	local passes=ownership and ownership.GamePasses
	if type(passes)=="table" then
		for _,pass in passes do
			if tostring(pass)=="1906308331" or tostring(pass)=="world_cup_2x_speed" or tostring(pass)=="2x_speed" then
				player:SetAttribute("VTRWorldCup2xSpeedPass",true)
				return true
			end
		end
	end

	local ok,owned=pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId,WORLD_CUP_2X_GAMEPASS_ID)
	end)

	if ok and owned==true then
		player:SetAttribute("VTRWorldCup2xSpeedPass",true)
		return true
	end

	return false
end

local function vtrRequireWorldCup2xPass(context:any):boolean
	if vtrOwnsWorldCup2xPass(context) then
		return true
	end

	pcall(function()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer,WORLD_CUP_2X_GAMEPASS_ID)
	end)

	if context and context.Toast then
		context.Toast({Title="WORLD CUP",Message="2x simulation speed requires the 2x Speed pass.",Kind="Info"})
	end

	return false
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player,gamePassId,purchased)
	if player==Players.LocalPlayer and gamePassId==WORLD_CUP_2X_GAMEPASS_ID and purchased then
		player:SetAttribute("VTRWorldCup2xSpeedPass",true)
	end
end)

'''
	m = re.search(r"\nlocal function\s+", text)
	if not m:
		raise SystemExit("Could not find safe helper insertion point in WorldCupPage.lua")
	text = text[:m.start()] + "\n" + helper + text[m.start():]

patched = text

button_patterns = [
	r'(Text\s*=\s*"2X"[\s\S]{0,500}?OnActivated\s*=\s*function\s*\(\))',
	r'(Text\s*=\s*"2x"[\s\S]{0,500}?OnActivated\s*=\s*function\s*\(\))',
	r'(Text\s*=\s*"x2"[\s\S]{0,500}?OnActivated\s*=\s*function\s*\(\))',
	r'(Text\s*=\s*"X2"[\s\S]{0,500}?OnActivated\s*=\s*function\s*\(\))',
]

changed_button = False
for pattern in button_patterns:
	def repl(match):
		global changed_button
		block = match.group(1)
		if "vtrRequireWorldCup2xPass(context)" in block:
			return block
		changed_button = True
		return block + "if not vtrRequireWorldCup2xPass(context)then return end;"
	patched = re.sub(pattern, repl, patched, count=1)

if not changed_button:
	lines = patched.splitlines()
	out = []
	found = False
	window = []
	for line in lines:
		low = line.lower()
		if ("2x" in low or "x2" in low) and "onactivated=function" in low and "vtrRequireWorldCup2xPass" not in line:
			line = line.replace("OnActivated=function()", "OnActivated=function()if not vtrRequireWorldCup2xPass(context)then return end;")
			line = line.replace("OnActivated = function()", "OnActivated = function()if not vtrRequireWorldCup2xPass(context)then return end;")
			found = True
		out.append(line)
	patched = "\n".join(out)
	changed_button = found

patched = patched.replace(
	"if not vtrRequireWorldCup2xPass(context)then return end;if not vtrRequireWorldCup2xPass(context)then return end;",
	"if not vtrRequireWorldCup2xPass(context)then return end;"
)

if not changed_button:
	raise SystemExit("ABORTED: Did not find the actual World Cup 2x button. Paste the WORLD CUP 2X / SPEED REFERENCES output.")

if patched == original:
	raise SystemExit("No changes made")

backup = worldcup.with_suffix(".lua.vtr_2x_backup")
backup.write_text(original, encoding="utf-8")
worldcup.write_text(patched.strip() + "\n", encoding="utf-8")

print("patched only:", worldcup.relative_to(root).as_posix())
print("backup:", backup.relative_to(root).as_posix())
print("gamepass:", 1906308331)