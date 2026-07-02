from pathlib import Path
import re

root = Path.cwd()

bootstrap = root / "src/server/Services/VTRRemoteBootstrapService.lua"
bootstrap.parent.mkdir(parents=True, exist_ok=True)

if bootstrap.exists():
    text = bootstrap.read_text(encoding="utf-8")
else:
    text = ""

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
'''.strip()

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
            r"(local remoteList\s*=\s*{)",
            "\\1\n\t" + name + ' = "' + class_name + '",',
            text,
            count=1
        )

if "RequestData.OnServerInvoke" not in text:
    insert = r'''
local function attachDefaultHandlers()
	local remotes = getRemotes()
	local requestData = remotes:FindFirstChild("RequestData")

	if requestData and requestData:IsA("RemoteFunction") and requestData.OnServerInvoke == nil then
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
        "VTRRemoteBootstrapService.Start()\n" + insert.strip() + "\nattachDefaultHandlers()\n\nreturn VTRRemoteBootstrapService"
    )

bootstrap.write_text(text.strip() + "\n", encoding="utf-8")

runner = root / "src/server/VTRRemoteBootstrap.server.lua"
runner.write_text('require(script.Parent.Services.VTRRemoteBootstrapService)\n', encoding="utf-8")

network = root / "src/client/Services/NetworkClient.lua"

if network.exists():
    text = network.read_text(encoding="utf-8")

    if "local function vtrWaitNetworkRemote" not in text:
        helper = r'''
local function vtrWaitNetworkRemote(name, className)
	local vtr = ReplicatedStorage:WaitForChild("VTR", 10) or ReplicatedStorage:FindFirstChild("VTR")
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
        r'ReplicatedStorage:WaitForChild\("VTR"\):WaitForChild\("Remotes"\):WaitForChild\("RequestData"\)',
        'vtrWaitNetworkRemote("RequestData", "RemoteFunction")',
        text
    )

    text = re.sub(
        r'ReplicatedStorage\.VTR\.Remotes:WaitForChild\("RequestData"\)',
        'vtrWaitNetworkRemote("RequestData", "RemoteFunction")',
        text
    )

    text = re.sub(
        r'ReplicatedStorage:WaitForChild\("VTR"\):WaitForChild\("Remotes"\):WaitForChild\("DataUpdated"\)',
        'vtrWaitNetworkRemote("DataUpdated", "RemoteEvent")',
        text
    )

    text = re.sub(
        r'ReplicatedStorage\.VTR\.Remotes:WaitForChild\("DataUpdated"\)',
        'vtrWaitNetworkRemote("DataUpdated", "RemoteEvent")',
        text
    )

    text = re.sub(
        r'([A-Za-z_][A-Za-z0-9_]*)\:InvokeServer\(',
        r'(\1 and \1:InvokeServer(',
        text
    )

    text = text.replace("))", ")))", 1) if "(RequestData and RequestData:InvokeServer(" in text and "))))" not in text else text

    text = text.replace("((RequestData and RequestData:InvokeServer(", "(RequestData and RequestData:InvokeServer(")
    text = text.replace("((DataUpdated and DataUpdated:InvokeServer(", "(DataUpdated and DataUpdated:InvokeServer(")

    network.write_text(text.strip() + "\n", encoding="utf-8")

for path in (root / "src/client").rglob("*.lua"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text

    text = text.replace(
        'ReplicatedStorage.VTR.Remotes:WaitForChild("RequestData")',
        '(ReplicatedStorage:WaitForChild("VTR", 10) and ReplicatedStorage.VTR:WaitForChild("Remotes", 10) and ReplicatedStorage.VTR.Remotes:WaitForChild("RequestData", 10))'
    )

    text = text.replace(
        'ReplicatedStorage.VTR.Remotes:WaitForChild("DataUpdated")',
        '(ReplicatedStorage:WaitForChild("VTR", 10) and ReplicatedStorage.VTR:WaitForChild("Remotes", 10) and ReplicatedStorage.VTR.Remotes:WaitForChild("DataUpdated", 10))'
    )

    text = text.replace(
        ':WaitForChild("RequestData")',
        ':WaitForChild("RequestData", 10)'
    )

    text = text.replace(
        ':WaitForChild("DataUpdated")',
        ':WaitForChild("DataUpdated", 10)'
    )

    if text != original:
        path.write_text(text.strip() + "\n", encoding="utf-8")
        print("patched", path.relative_to(root).as_posix())

print("patched src/server/Services/VTRRemoteBootstrapService.lua")
print("patched src/server/VTRRemoteBootstrap.server.lua")