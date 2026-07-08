from pathlib import Path
import re

root = Path.cwd()

loader_pattern = re.compile(
	r'\n?local function vtrLoadWorldCampaignWinProgress\(\)[\s\S]*?local VTRWorldCampaignWinProgress = vtrLoadWorldCampaignWinProgress\(\)\n?',
	re.M
)

removed = []

for path in sorted((root / "src/server").rglob("*.lua")):
	text = path.read_text(encoding="utf-8", errors="ignore")
	new_text = loader_pattern.sub("\n", text)

	if new_text != text:
		path.write_text(new_text.strip() + "\n", encoding="utf-8")
		removed.append(path.relative_to(root).as_posix())

service_path = root / "src/server/Services/WorldCampaignWinProgressService.lua"

if service_path.exists():
	text = service_path.read_text(encoding="utf-8", errors="ignore")
	text = text.replace('return require(game:GetService("ServerScriptService"):WaitForChild("VTRServer"):WaitForChild("Services"):WaitForChild("WorldCampaignWinProgressService"))', 'return nil')
	service_path.write_text(text.strip() + "\n", encoding="utf-8")

runner_path = root / "src/server/WorldCampaignWinProgress.server.lua"
runner_path.write_text(r'''
local ServerScriptService = game:GetService("ServerScriptService")

task.defer(function()
	local vtrServer = ServerScriptService:FindFirstChild("VTRServer")
	local services = vtrServer and vtrServer:FindFirstChild("Services")

	if not services then
		return
	end

	local module = services:FindFirstChild("WorldCampaignWinProgressService")
	if not module then
		return
	end

	pcall(require, module)
end)
'''.strip() + "\n", encoding="utf-8")

print("removed bad loader from")
for item in removed:
	print(item)

print("added src/server/WorldCampaignWinProgress.server.lua")