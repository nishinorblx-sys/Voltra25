from pathlib import Path
import re

root = Path.cwd()

safe_loader = r'''
local function vtrGetWorldCampaignWinProgress()
	local serverScriptService = game:GetService("ServerScriptService")
	local vtrServer = serverScriptService:FindFirstChild("VTRServer")
	local services = vtrServer and vtrServer:FindFirstChild("Services")
	local module = services and services:FindFirstChild("WorldCampaignWinProgressService")

	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and typeof(result) == "table" and result.TryRegisterFromArgs then
			return result
		end
	end

	return {
		TryRegisterFromArgs = function()
			return false
		end,
		RegisterWin = function()
			return false
		end,
	}
end

local VTRWorldCampaignWinProgress = vtrGetWorldCampaignWinProgress()
'''.strip()

bad_loader = re.compile(
	r'\n?local function vtrLoadWorldCampaignWinProgress\(\)[\s\S]*?local VTRWorldCampaignWinProgress = vtrLoadWorldCampaignWinProgress\(\)\n?',
	re.M
)

patched = []

for path in sorted((root / "src/server").rglob("*.lua")):
	text = path.read_text(encoding="utf-8", errors="ignore")

	if "VTRWorldCampaignWinProgress" not in text:
		continue

	original = text
	text = bad_loader.sub("\n", text)
	text = re.sub(r"local\s+VTRWorldCampaignWinProgress\s*=\s*nil\s*\n", "", text)

	if "VTRWorldCampaignWinProgress.TryRegisterFromArgs" in text and "vtrGetWorldCampaignWinProgress" not in text:
		lines = text.splitlines()
		index = 0
		while index < len(lines) and lines[index].startswith("--!"):
			index += 1
		lines.insert(index, safe_loader)
		text = "\n".join(lines) + "\n"

	text = text.replace("VTRWorldCampaignWinProgress.TryRegisterFromArgs(", "pcall(function() VTRWorldCampaignWinProgress.TryRegisterFromArgs(")
	text = re.sub(r"(pcall\(function\(\) VTRWorldCampaignWinProgress\.TryRegisterFromArgs\([^\n]*\))", r"\1 end)", text)

	if text != original:
		path.write_text(text.strip() + "\n", encoding="utf-8")
		patched.append(path.relative_to(root).as_posix())

service_path = root / "src/server/Services/WorldCampaignWinProgressService.lua"

if service_path.exists():
	text = service_path.read_text(encoding="utf-8", errors="ignore")
	text = text.replace("cachedModules = profileModules()", "cachedModules = profileModules() or {}")
	service_path.write_text(text.strip() + "\n", encoding="utf-8")

print("patched")
for item in patched:
	print(item)