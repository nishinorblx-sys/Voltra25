from pathlib import Path
import re

root = Path.cwd()

fallback_path = root / "src/shared/VTRDataDefaults.lua"
fallback_path.parent.mkdir(parents=True, exist_ok=True)
fallback_path.write_text(r'''
local VTRDataDefaults = {}

local function stat(player, name, default)
	local attr = player and player:GetAttribute(name)
	if attr ~= nil then
		return attr
	end

	local leaderstats = player and player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	if value and value:IsA("ValueBase") then
		return value.Value
	end

	return default
end

function VTRDataDefaults.ForKey(player, key)
	local wins = stat(player, "Wins", 0)
	local coins = stat(player, "Coins", 0)
	local gems = stat(player, "Gems", 0)
	local level = stat(player, "Level", 1)
	local xp = stat(player, "XP", 0)
	local rank = stat(player, "Rank", "Bronze")

	if key == "PlayerProfile" then
		return {
			UserId = player and player.UserId or 0,
			Name = player and player.Name or "",
			DisplayName = player and player.DisplayName or "",
			Wins = wins,
			Level = level,
			XP = xp,
			Rank = rank,
		}
	end

	if key == "Currency" then
		return {
			Coins = coins,
			Gems = gems,
			Cash = coins,
		}
	end

	if key == "SeasonProgress" then
		return {
			Level = level,
			XP = xp,
			Progress = 0,
			Rewards = {},
			Claimed = {},
		}
	end

	if key == "Ranked" then
		return {
			Rank = rank,
			Division = stat(player, "Division", 1),
			Rating = stat(player, "Rating", 0),
			Wins = wins,
			Losses = stat(player, "Losses", 0),
		}
	end

	if key == "Objective" then
		return {
			Daily = {},
			Weekly = {},
			Active = {},
			Completed = {},
		}
	end

	if key == "Fixture" then
		return {
			Matches = {},
			Current = nil,
			Next = nil,
		}
	end

	if key == "UIState" then
		return {
			Page = "Home",
			Modal = nil,
			Busy = false,
		}
	end

	if key == "Progression" then
		return {
			Level = level,
			XP = xp,
			NextLevelXP = 100,
			Rewards = {},
		}
	end

	return {}
end

return VTRDataDefaults
'''.strip() + "\n", encoding="utf-8")

bootstrap_path = root / "src/server/Services/VTRRemoteBootstrapService.lua"
bootstrap_path.parent.mkdir(parents=True, exist_ok=True)

bootstrap_path.write_text(r'''
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {}

local remoteList = {
	AckPackRewardAnimation = "RemoteEvent",
	CameraAction = "RemoteEvent",
	ConfirmSevenWinLoginReward = "RemoteFunction",
	DataUpdated = "RemoteEvent",
	GameplayAction = "RemoteEvent",
	InventoryAction = "RemoteEvent",
	KickoffAction = "RemoteEvent",
	MatchAction = "RemoteEvent",
	MatchSetupAction = "RemoteEvent",
	PackAction = "RemoteEvent",
	PendingSevenWinLoginReward = "RemoteEvent",
	PenaltyAction = "RemoteEvent",
	RequestData = "RemoteFunction",
	SetPieceAction = "RemoteEvent",
	ShowPackRewardAnimation = "RemoteEvent",
	SoundAction = "RemoteEvent",
	UpdateData = "RemoteEvent",
	UpdateUIState = "RemoteEvent",
}

local folderGroups = {
	PackRewardAnimationRemotes = {
		AckPackRewardAnimation = "RemoteEvent",
		ShowPackRewardAnimation = "RemoteEvent",
	},
	SevenWinLoginRewardRemotes = {
		ConfirmSevenWinLoginReward = "RemoteFunction",
		PendingSevenWinLoginReward = "RemoteEvent",
	},
}

local function getRoot()
	local rootFolder = ReplicatedStorage:FindFirstChild("VTR")
	if not rootFolder then
		rootFolder = Instance.new("Folder")
		rootFolder.Name = "VTR"
		rootFolder.Parent = ReplicatedStorage
	end
	return rootFolder
end

local function getShared()
	local rootFolder = getRoot()
	local shared = rootFolder:FindFirstChild("Shared") or ReplicatedStorage:FindFirstChild("Shared")
	if not shared then
		shared = Instance.new("Folder")
		shared.Name = "Shared"
		shared.Parent = rootFolder
	end
	return shared
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

local function defaultData(player, key)
	local defaultsModule = getShared():FindFirstChild("VTRDataDefaults")
	if defaultsModule then
		local ok, defaults = pcall(require, defaultsModule)
		if ok and defaults and typeof(defaults.ForKey) == "function" then
			return defaults.ForKey(player, key)
		end
	end

	return {}
end

local function attachDefaultFunction(remote)
	if remote and remote:IsA("RemoteFunction") then
		remote.OnServerInvoke = defaultData
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
'''.strip() + "\n", encoding="utf-8")

(root / "src/server/VTRRemoteBootstrap.server.lua").write_text('require(script.Parent.Services.VTRRemoteBootstrapService)\n', encoding="utf-8")

network_path = root / "src/client/Services/NetworkClient.lua"
if network_path.exists():
	text = network_path.read_text(encoding="utf-8", errors="ignore")

	if 'local VTRDataDefaults' not in text:
		text = text.replace(
			'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
			'local ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal VTRDataDefaults = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRDataDefaults"))',
			1
		)

	text = re.sub(
		r'warn\("VTR data request failed:\s*"\s*\.\.\s*tostring\(([^)]*)\)\)',
		r'return VTRDataDefaults.ForKey(game:GetService("Players").LocalPlayer, \1)',
		text
	)

	text = re.sub(
		r'warn\("VTR data request failed:\s*"\s*\.\.\s*([^)\n]+)\)',
		r'return VTRDataDefaults.ForKey(game:GetService("Players").LocalPlayer, \1)',
		text
	)

	text = re.sub(
		r'if\s+not\s+success\s+then\s*\n\s*return\s+nil\s*\n\s*end',
		'if not success then\n\t\treturn VTRDataDefaults.ForKey(game:GetService("Players").LocalPlayer, key)\n\tend',
		text
	)

	text = re.sub(
		r'if\s+not\s+ok\s+then\s*\n\s*return\s+nil\s*\n\s*end',
		'if not ok then\n\t\treturn VTRDataDefaults.ForKey(game:GetService("Players").LocalPlayer, key)\n\tend',
		text
	)

	text = re.sub(
		r'if\s+result\s*==\s*nil\s+then\s*\n\s*return\s+nil\s*\n\s*end',
		'if result == nil then\n\t\treturn VTRDataDefaults.ForKey(game:GetService("Players").LocalPlayer, key)\n\tend',
		text
	)

	network_path.write_text(text.strip() + "\n", encoding="utf-8")
	print("patched src/client/Services/NetworkClient.lua")

print("patched src/shared/VTRDataDefaults.lua")
print("patched src/server/Services/VTRRemoteBootstrapService.lua")
print("patched src/server/VTRRemoteBootstrap.server.lua")