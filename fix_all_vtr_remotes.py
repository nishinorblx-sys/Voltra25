from pathlib import Path
import re

root = Path.cwd()
src = root / "src"

known = {
    "RequestData": "RemoteFunction",
    "UpdateData": "RemoteEvent",
    "DataUpdated": "RemoteEvent",
    "UpdateUIState": "RemoteEvent",
    "MatchSetupAction": "RemoteEvent",
    "PendingSevenWinLoginReward": "RemoteEvent",
    "ConfirmSevenWinLoginReward": "RemoteFunction",
    "ShowPackRewardAnimation": "RemoteEvent",
    "AckPackRewardAnimation": "RemoteEvent",
    "KickoffAction": "RemoteEvent",
    "SetPieceAction": "RemoteEvent",
    "PenaltyAction": "RemoteEvent",
    "GameplayAction": "RemoteEvent",
    "MatchAction": "RemoteEvent",
    "CameraAction": "RemoteEvent",
    "SoundAction": "RemoteEvent",
    "InventoryAction": "RemoteEvent",
    "PackAction": "RemoteEvent",
}

folder_groups = {
    "SevenWinLoginRewardRemotes": {
        "PendingSevenWinLoginReward": "RemoteEvent",
        "ConfirmSevenWinLoginReward": "RemoteFunction",
    },
    "PackRewardAnimationRemotes": {
        "ShowPackRewardAnimation": "RemoteEvent",
        "AckPackRewardAnimation": "RemoteEvent",
    },
}

texts = []
for path in src.rglob("*.lua"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    texts.append((path, text))

for path, text in texts:
    for match in re.finditer(r'WaitForChild\("([A-Za-z0-9_]+)"', text):
        name = match.group(1)
        window = text[max(0, match.start() - 160):match.end() + 240]
        if "Remote" in window or "Remotes" in window or name.endswith("Action") or name.endswith("Event") or name.endswith("Remote") or name in known:
            if name not in {"VTR", "Remotes", "Shared", "Services", "Components", "Gameplay", "Pages"}:
                known.setdefault(name, "RemoteEvent")

    for match in re.finditer(r'FindFirstChild\("([A-Za-z0-9_]+)"', text):
        name = match.group(1)
        window = text[max(0, match.start() - 160):match.end() + 240]
        if "Remote" in window or "Remotes" in window or name.endswith("Action") or name.endswith("Event") or name.endswith("Remote") or name in known:
            if name not in {"VTR", "Remotes", "Shared", "Services", "Components", "Gameplay", "Pages"}:
                known.setdefault(name, "RemoteEvent")

for path, text in texts:
    assigns = {}
    for match in re.finditer(r'(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*[^\n]*WaitForChild\("([A-Za-z0-9_]+)"[^\n]*\)', text):
        assigns[match.group(1)] = match.group(2)

    for var, name in assigns.items():
        if re.search(r'\b' + re.escape(var) + r'\s*:\s*InvokeServer\s*\(', text) or re.search(r'\b' + re.escape(var) + r'\.OnServerInvoke\b', text):
            known[name] = "RemoteFunction"
        elif re.search(r'\b' + re.escape(var) + r'\s*:\s*FireServer\s*\(', text) or re.search(r'\b' + re.escape(var) + r'\s*:\s*FireAllClients\s*\(', text) or re.search(r'\b' + re.escape(var) + r'\.OnClientEvent\b', text) or re.search(r'\b' + re.escape(var) + r'\.OnServerEvent\b', text):
            known.setdefault(name, "RemoteEvent")

    for match in re.finditer(r'WaitForChild\("([A-Za-z0-9_]+)"[^\n]*\)\s*:\s*WaitForChild\("([A-Za-z0-9_]+)"', text):
        folder = match.group(1)
        remote = match.group(2)
        if folder not in {"VTR", "Remotes", "Shared", "Services", "Components", "Gameplay", "Pages"}:
            folder_groups.setdefault(folder, {})
            folder_groups[folder].setdefault(remote, known.get(remote, "RemoteEvent"))

for name in list(known):
    if name.endswith("Function") or name.startswith("Request") or name.startswith("Get") or name.startswith("Fetch"):
        known[name] = "RemoteFunction"

remote_lines = []
for name in sorted(known):
    class_name = known[name]
    if class_name in {"RemoteEvent", "RemoteFunction"}:
        remote_lines.append(f'\t{name} = "{class_name}",')

group_blocks = []
for folder in sorted(folder_groups):
    children = folder_groups[folder]
    lines = [f'\t{folder} = {{']
    for name in sorted(children):
        lines.append(f'\t\t{name} = "{children[name]}",')
    lines.append("\t},")
    group_blocks.append("\n".join(lines))

service = f'''
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {{}}

local remoteList = {{
{chr(10).join(remote_lines)}
}}

local folderGroups = {{
{chr(10).join(group_blocks)}
}}

local function getRoot()
	local root = ReplicatedStorage:FindFirstChild("VTR")
	if not root then
		root = Instance.new("Folder")
		root.Name = "VTR"
		root.Parent = ReplicatedStorage
	end
	return root
end

local function getRemotes()
	local root = getRoot()
	local remotes = root:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = root
	end
	return remotes
end

local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing.ClassName == className then
			return existing
		end
		existing:Destroy()
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function attachDefaultFunction(remote)
	if not remote or not remote:IsA("RemoteFunction") then
		return
	end

	remote.OnServerInvoke = remote.OnServerInvoke or function(player, key)
		local data = {{}}

		if typeof(key) == "string" then
			data.Key = key
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			for _, value in ipairs(leaderstats:GetChildren()) do
				if value:IsA("ValueBase") then
					data[value.Name] = value.Value
				end
			end
		end

		for _, attrName in ipairs({{ "Wins", "TotalWins", "Coins", "Rank", "XP", "Level" }}) do
			local attr = player:GetAttribute(attrName)
			if attr ~= nil then
				data[attrName] = attr
			end
		end

		return data
	end
end

function VTRRemoteBootstrapService.Start()
	local remotes = getRemotes()

	for name, className in pairs(remoteList) do
		local remote = ensureRemote(remotes, name, className)
		attachDefaultFunction(remote)
	end

	for folderName, children in pairs(folderGroups) do
		local folder = remotes:FindFirstChild(folderName)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = folderName
			folder.Parent = remotes
		end

		for name, className in pairs(children) do
			local remote = ensureRemote(folder, name, className)
			attachDefaultFunction(remote)
		end
	end
end

VTRRemoteBootstrapService.Start()

return VTRRemoteBootstrapService
'''.strip()

service_path = root / "src/server/Services/VTRRemoteBootstrapService.lua"
service_path.parent.mkdir(parents=True, exist_ok=True)
service_path.write_text(service + "\n", encoding="utf-8")

runner_path = root / "src/server/VTRRemoteBootstrap.server.lua"
runner_path.write_text('require(script.Parent.Services.VTRRemoteBootstrapService)\n', encoding="utf-8")

for path in (root / "src/client").rglob("*.lua"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text

    text = re.sub(r':WaitForChild\("([A-Za-z0-9_]+)"\)', lambda m: f':WaitForChild("{m.group(1)}", 15)' if m.group(1) in known or m.group(1) == "Remotes" or m.group(1) == "VTR" else m.group(0), text)

    if text != original:
        path.write_text(text.strip() + "\n", encoding="utf-8")
        print("patched", path.relative_to(root).as_posix())

print("remotes", len(known))
print("patched src/server/Services/VTRRemoteBootstrapService.lua")
print("patched src/server/VTRRemoteBootstrap.server.lua")