from pathlib import Path
import re

root = Path.cwd()

bootstrap = root / "src/server/Services/VTRRemoteBootstrapService.lua"
bootstrap.parent.mkdir(parents=True, exist_ok=True)

if bootstrap.exists():
	text = bootstrap.read_text(encoding="utf-8", errors="ignore")
else:
	text = r'''
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {}

local remoteList = {}

local function getRoot()
	local rootFolder = ReplicatedStorage:FindFirstChild("VTR")
	if not rootFolder then
		rootFolder = Instance.new("Folder")
		rootFolder.Name = "VTR"
		rootFolder.Parent = ReplicatedStorage
	end
	return rootFolder
end

local function getRemotes()
	local rootFolder = getRoot()
	local remotes = rootFolder:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = rootFolder
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
end

VTRRemoteBootstrapService.Start()

return VTRRemoteBootstrapService
'''

if "Notification" not in text:
	text = re.sub(
		r"(local\s+remoteList\s*=\s*{)",
		'\\1\n\tNotification = "RemoteEvent",',
		text,
		count=1
	)

bootstrap.write_text(text.strip() + "\n", encoding="utf-8")

runner = root / "src/server/VTRRemoteBootstrap.server.lua"
runner.write_text('require(script.Parent.Services.VTRRemoteBootstrapService)\n', encoding="utf-8")

client = root / "src/client/Services/NotificationService.lua"
if client.exists():
	text = client.read_text(encoding="utf-8", errors="ignore")
	original = text

	if "local function vtrGetNotificationRemote()" not in text:
		helper = r'''
local function vtrGetNotificationRemote()
	local vtr = ReplicatedStorage:FindFirstChild("VTR") or ReplicatedStorage:WaitForChild("VTR", 10)
	local remotes = vtr and (vtr:FindFirstChild("Remotes") or vtr:WaitForChild("Remotes", 10))
	local remote = remotes and (remotes:FindFirstChild("Notification") or remotes:WaitForChild("Notification", 10))

	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	local dummy = script:FindFirstChild("VTRLocalNotification")
	if not dummy then
		dummy = Instance.new("RemoteEvent")
		dummy.Name = "VTRLocalNotification"
		dummy.Parent = script
	end

	return dummy
end
'''
		if 'local ReplicatedStorage = game:GetService("ReplicatedStorage")' in text:
			text = text.replace(
				'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
				'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n' + helper.strip(),
				1
			)
		else:
			text = 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n' + helper.strip() + "\n" + text

	text = re.sub(
		r'local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*[^\n]*WaitForChild\("Notification"(?:,\s*\d+)?\)[^\n]*',
		r'local \1 = vtrGetNotificationRemote()',
		text
	)

	text = text.replace(
		'ReplicatedStorage:WaitForChild("VTR"):WaitForChild("Remotes"):WaitForChild("Notification")',
		'vtrGetNotificationRemote()'
	)

	text = text.replace(
		'ReplicatedStorage:WaitForChild("VTR", 15):WaitForChild("Remotes", 15):WaitForChild("Notification", 15)',
		'vtrGetNotificationRemote()'
	)

	text = text.replace(
		'ReplicatedStorage.VTR.Remotes:WaitForChild("Notification")',
		'vtrGetNotificationRemote()'
	)

	text = text.replace(
		'ReplicatedStorage.VTR.Remotes:WaitForChild("Notification", 15)',
		'vtrGetNotificationRemote()'
	)

	if text != original:
		client.write_text(text.strip() + "\n", encoding="utf-8")
		print("patched src/client/Services/NotificationService.lua")

print("patched src/server/Services/VTRRemoteBootstrapService.lua")
print("patched src/server/VTRRemoteBootstrap.server.lua")