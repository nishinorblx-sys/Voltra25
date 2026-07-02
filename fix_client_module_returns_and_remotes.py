from pathlib import Path
import re

root = Path.cwd()

def p(path):
    return root / path

def read(path):
    f = p(path)
    if not f.exists():
        return None
    return f.read_text(encoding="utf-8")

def write(path, text):
    f = p(path)
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text.strip() + "\n", encoding="utf-8")

write("src/shared/VTRReplicated.lua", r'''
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRReplicated = {}

local function child(parent, name)
	if parent then
		return parent:FindFirstChild(name)
	end
	return nil
end

function VTRReplicated.GetRoot()
	return child(ReplicatedStorage, "VTR") or ReplicatedStorage
end

function VTRReplicated.GetShared()
	local root = VTRReplicated.GetRoot()
	return child(root, "Shared") or child(ReplicatedStorage, "Shared") or root
end

function VTRReplicated.GetRemotes()
	local root = VTRReplicated.GetRoot()
	local remotes = child(root, "Remotes") or child(ReplicatedStorage, "Remotes")

	if not remotes and root then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = root
	end

	return remotes
end

function VTRReplicated.GetOrCreateRemoteFolder(name)
	local remotes = VTRReplicated.GetRemotes()
	local folder = remotes:FindFirstChild(name)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = remotes
	end

	return folder
end

function VTRReplicated.WaitForSharedModule(name)
	local shared = VTRReplicated.GetShared()
	return shared:WaitForChild(name)
end

return VTRReplicated
''')

def patch_config_require(text):
    text = text.replace(
        'local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")\nlocal Config = require(sharedFolder and sharedFolder:WaitForChild("SevenWinLoginRewardConfig") or ReplicatedStorage:WaitForChild("SevenWinLoginRewardConfig"))',
        'local VTRReplicated = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRReplicated"))\nlocal Config = require(VTRReplicated.WaitForSharedModule("SevenWinLoginRewardConfig"))'
    )
    text = text.replace(
        'local Config = require(sharedFolder and sharedFolder:WaitForChild("SevenWinLoginRewardConfig") or ReplicatedStorage:WaitForChild("SevenWinLoginRewardConfig"))',
        'local VTRReplicated = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRReplicated"))\nlocal Config = require(VTRReplicated.WaitForSharedModule("SevenWinLoginRewardConfig"))'
    )
    text = text.replace('local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")\n', '')
    return text

def patch_reward_remotes(text):
    if "VTRReplicated.GetOrCreateRemoteFolder" not in text:
        text = text.replace(
            'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
            'local ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal VTRReplicated = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRReplicated"))',
            1
        )

    text = re.sub(
        r'local folder = ReplicatedStorage:FindFirstChild\("PackRewardAnimationRemotes"\)\s*if not folder then\s*folder = Instance\.new\("Folder"\)\s*folder\.Name = "PackRewardAnimationRemotes"\s*folder\.Parent = ReplicatedStorage\s*end',
        'local folder = VTRReplicated.GetOrCreateRemoteFolder("PackRewardAnimationRemotes")',
        text,
        flags=re.S
    )

    text = text.replace(
        'local remotes = ReplicatedStorage:WaitForChild("PackRewardAnimationRemotes")',
        'local remotes = VTRReplicated.GetRemotes():WaitForChild("PackRewardAnimationRemotes")'
    )

    return text

def patch_seven_remotes_server(text):
    text = patch_config_require(text)

    if "VTRReplicated.GetOrCreateRemoteFolder" not in text:
        text = text.replace(
            'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
            'local ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal VTRReplicated = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRReplicated"))',
            1
        )

    text = re.sub(
        r'local remotes = ReplicatedStorage:FindFirstChild\(Config\.RemoteFolderName\)\s*if not remotes then\s*remotes = Instance\.new\("Folder"\)\s*remotes\.Name = Config\.RemoteFolderName\s*remotes\.Parent = ReplicatedStorage\s*end',
        'local remotes = VTRReplicated.GetOrCreateRemoteFolder(Config.RemoteFolderName)',
        text,
        flags=re.S
    )

    return text

def patch_seven_remotes_client(text):
    text = patch_config_require(text)
    text = text.replace(
        'local remotes = ReplicatedStorage:WaitForChild(Config.RemoteFolderName)',
        'local remotes = VTRReplicated.GetRemotes():WaitForChild(Config.RemoteFolderName)'
    )
    return text

def ensure_return(path, fallback):
    text = read(path)
    if text is None:
        return

    if re.search(r"\nreturn\s+", text) or re.match(r"\s*return\s+", text):
        return

    write(path, text.rstrip() + "\n\nreturn " + fallback + "\n")

def patch_file(path, fn):
    text = read(path)
    if text is None:
        print("missing", path)
        return

    new = fn(text)
    if new != text:
        write(path, new)
        print("patched", path)
    else:
        print("unchanged", path)

patch_file("src/server/Services/PendingPackAnimationService.lua", patch_reward_remotes)
patch_file("src/client/Services/PackRewardFlyinClient.lua", patch_reward_remotes)
patch_file("src/server/Services/SevenWinLoginRewardService.lua", patch_seven_remotes_server)
patch_file("src/client/Services/SevenWinLoginRewardClient.lua", patch_seven_remotes_client)

ensure_return("src/client/PackRewardFlyin.client.lua", "true")
ensure_return("src/client/PackRewardFlyin.lua", "true")
ensure_return("src/client/SevenWinLoginReward.client.lua", "true")
ensure_return("src/client/SevenWinLoginReward.lua", "true")
ensure_return("src/client/Services/PackRewardFlyinClient.lua", "true")

print("patched module returns")