from pathlib import Path
import re

root = Path.cwd()

def read(path):
    p = root / path
    if not p.exists():
        return None
    return p.read_text(encoding="utf-8", errors="ignore")

def write(path, text):
    p = root / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text.strip() + "\n", encoding="utf-8")

def balance_line(line):
    if "InvokeServer" not in line and "FireServer" not in line:
        return line

    count = 0
    for ch in line:
        if ch == "(":
            count += 1
        elif ch == ")":
            count -= 1

    while count < 0:
        idx = line.rfind(")")
        if idx == -1:
            break
        line = line[:idx] + line[idx + 1:]
        count += 1

    return line

def undo_bad_safe_calls(text):
    text = re.sub(r"\(([A-Za-z_][A-Za-z0-9_]*)\s+and\s+\1:InvokeServer\(", r"\1:InvokeServer(", text)
    text = re.sub(r"\(([A-Za-z_][A-Za-z0-9_]*)\s+and\s+\1:FireServer\(", r"\1:FireServer(", text)
    text = re.sub(r"\(([A-Za-z_][A-Za-z0-9_]*)\s+and\s+\1:OnServerInvoke", r"\1.OnServerInvoke", text)
    return "\n".join(balance_line(line) for line in text.splitlines()) + "\n"

def patch_network_client(text):
    text = undo_bad_safe_calls(text)

    if "local function vtrWaitNetworkRemote" not in text:
        helper = r'''
local function vtrWaitNetworkRemote(name, className)
	local vtr = ReplicatedStorage:FindFirstChild("VTR") or ReplicatedStorage:WaitForChild("VTR", 10)
	local remotes = vtr and (vtr:FindFirstChild("Remotes") or vtr:WaitForChild("Remotes", 10))
	local remote = remotes and (remotes:FindFirstChild(name) or remotes:WaitForChild(name, 10))

	if remote and remote.ClassName == className then
		return remote
	end

	warn(name .. " remote missing")
	return nil
end
'''
        text = text.replace(
            'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
            'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n' + helper.strip(),
            1
        )

    text = re.sub(
        r'local\s+RequestData\s*=\s*.*RequestData.*',
        'local RequestData = vtrWaitNetworkRemote("RequestData", "RemoteFunction")',
        text
    )

    text = re.sub(
        r'local\s+DataUpdated\s*=\s*.*DataUpdated.*',
        'local DataUpdated = vtrWaitNetworkRemote("DataUpdated", "RemoteEvent")',
        text
    )

    text = re.sub(
        r'ReplicatedStorage:WaitForChild\("VTR"[^\n]*:WaitForChild\("RequestData"[^\n]*\)',
        'vtrWaitNetworkRemote("RequestData", "RemoteFunction")',
        text
    )

    text = re.sub(
        r'ReplicatedStorage:WaitForChild\("VTR"[^\n]*:WaitForChild\("DataUpdated"[^\n]*\)',
        'vtrWaitNetworkRemote("DataUpdated", "RemoteEvent")',
        text
    )

    text = undo_bad_safe_calls(text)
    return text

def patch_bootstrap(text):
    if "local remoteList" not in text:
        text = r'''
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {}

local remoteList = {}

local folderGroups = {}

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
	if existing and existing.ClassName == className then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

function VTRRemoteBootstrapService.Start()
	local remotes = getRemotes()

	for name, className in pairs(remoteList) do
		ensureRemote(remotes, name, className)
	end

	for folderName, children in pairs(folderGroups) do
		local folder = remotes:FindFirstChild(folderName)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = folderName
			folder.Parent = remotes
		end

		for name, className in pairs(children) do
			ensureRemote(folder, name, className)
		end
	end
end

VTRRemoteBootstrapService.Start()

return VTRRemoteBootstrapService
'''

    needed = {
        "RequestData": "RemoteFunction",
        "DataUpdated": "RemoteEvent",
        "UpdateData": "RemoteEvent",
        "MatchSetupAction": "RemoteEvent",
        "PendingSevenWinLoginReward": "RemoteEvent",
        "ConfirmSevenWinLoginReward": "RemoteFunction",
        "ShowPackRewardAnimation": "RemoteEvent",
        "AckPackRewardAnimation": "RemoteEvent",
    }

    for name, class_name in needed.items():
        if name not in text:
            text = re.sub(
                r"(local\s+remoteList\s*=\s*{)",
                "\\1\n\t" + name + ' = "' + class_name + '",',
                text,
                count=1
            )

    if "attachDefaultHandlers" not in text:
        attach = r'''
local function attachDefaultHandlers()
	local remotes = getRemotes()
	local requestData = remotes:FindFirstChild("RequestData")

	if requestData and requestData:IsA("RemoteFunction") then
		requestData.OnServerInvoke = function(player, key)
			local data = {}

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

			for _, attrName in ipairs({ "Wins", "TotalWins", "Coins", "Rank", "XP", "Level" }) do
				local attr = player:GetAttribute(attrName)
				if attr ~= nil then
					data[attrName] = attr
				end
			end

			return data
		end
	end
end
'''
        text = text.replace(
            "VTRRemoteBootstrapService.Start()\n\nreturn VTRRemoteBootstrapService",
            "VTRRemoteBootstrapService.Start()\n" + attach.strip() + "\nattachDefaultHandlers()\n\nreturn VTRRemoteBootstrapService"
        )

    return undo_bad_safe_calls(text)

network_path = "src/client/Services/NetworkClient.lua"
network = read(network_path)
if network is not None:
    write(network_path, patch_network_client(network))
    print("patched", network_path)

bootstrap_path = "src/server/Services/VTRRemoteBootstrapService.lua"
bootstrap = read(bootstrap_path) or ""
write(bootstrap_path, patch_bootstrap(bootstrap))
write("src/server/VTRRemoteBootstrap.server.lua", 'require(script.Parent.Services.VTRRemoteBootstrapService)\n')

for path in (root / "src/client").rglob("*.lua"):
    rel = path.relative_to(root).as_posix()
    if rel == network_path:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    new = undo_bad_safe_calls(text)
    if new != text:
        path.write_text(new.strip() + "\n", encoding="utf-8")
        print("patched", rel)

print("done")