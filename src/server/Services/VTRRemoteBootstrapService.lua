local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {}

local remoteList = {
	Notification = "RemoteEvent",
	AckPackRewardAnimation = "RemoteEvent",
	CameraAction = "RemoteEvent",
	ConfirmSevenWinLoginReward = "RemoteFunction",
	DataUpdated = "RemoteEvent",
	GameplayAction = "RemoteEvent",
	InventoryAction = "RemoteFunction",
	KickoffAction = "RemoteEvent",
	MatchAction = "RemoteEvent",
	MatchSetupAction = "RemoteFunction",
	PackAction = "RemoteFunction",
	PendingSevenWinLoginReward = "RemoteEvent",
	PenaltyAction = "RemoteEvent",
	RankedMatchFound = "RemoteEvent",
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

local function getLegacyRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
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
	local legacyRemotes = getLegacyRemotes()

	for name, className in pairs(remoteList) do
		ensureRemote(remotes, name, className)
		if className == "RemoteEvent" then
			ensureRemote(legacyRemotes, name, className)
		end
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
