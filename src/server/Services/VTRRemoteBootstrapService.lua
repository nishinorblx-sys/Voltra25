local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {}

local remoteList = {
	MatchSetupAction = "RemoteEvent",
	PendingSevenWinLoginReward = "RemoteEvent",
	ConfirmSevenWinLoginReward = "RemoteFunction",
	ShowPackRewardAnimation = "RemoteEvent",
	AckPackRewardAnimation = "RemoteEvent",
}

local folderGroups = {
	SevenWinLoginRewardRemotes = {
		PendingSevenWinLoginReward = "RemoteEvent",
		ConfirmSevenWinLoginReward = "RemoteFunction",
	},
	PackRewardAnimationRemotes = {
		ShowPackRewardAnimation = "RemoteEvent",
		AckPackRewardAnimation = "RemoteEvent",
	},
}

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
