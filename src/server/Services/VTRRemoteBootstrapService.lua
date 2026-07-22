local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {}

local remoteList = {
	Notification = "RemoteEvent",
	AckPackRewardAnimation = "RemoteEvent",
	CameraAction = "RemoteEvent",
	ConfirmSevenWinLoginReward = "RemoteFunction",
	ClaimDailyLoginReward = "RemoteFunction",
	DataUpdated = "RemoteEvent",
	DeveloperAction = "RemoteFunction",
	CareerAction = "RemoteFunction",
	GameplayAction = "RemoteEvent",
	InventoryAction = "RemoteFunction",
	KickoffAction = "RemoteEvent",
	LaunchAction = "RemoteFunction",
	MatchAction = "RemoteEvent",
	MatchSetupAction = "RemoteFunction",
	PackAction = "RemoteFunction",
	PlayerDataAction = "RemoteFunction",
	PendingSevenWinLoginReward = "RemoteEvent",
	PendingDailyLoginReward = "RemoteEvent",
	PenaltyAction = "RemoteEvent",
	ProgressionAction = "RemoteFunction",
	RankedMatchFound = "RemoteEvent",
	RequestData = "RemoteFunction",
	SquadAction = "RemoteFunction",
	SetPieceAction = "RemoteEvent",
	ShowPackRewardAnimation = "RemoteEvent",
	SoundAction = "RemoteEvent",
	UpdateData = "RemoteEvent",
	UpdateUIState = "RemoteEvent",
}

local gameplayRemoteList = {
	GameplayAction = "RemoteEvent",
	GameplayState = "RemoteEvent",
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
	DailyLoginRewardRemotes = {
		ClaimDailyLoginReward = "RemoteFunction",
		PendingDailyLoginReward = "RemoteEvent",
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
	local rootFolder = getRoot()
	local gameplayRemotes = rootFolder:FindFirstChild("GameplayRemotes")
	if not gameplayRemotes then
		gameplayRemotes = Instance.new("Folder")
		gameplayRemotes.Name = "GameplayRemotes"
		gameplayRemotes.Parent = rootFolder
	end

	for name, className in pairs(remoteList) do
		ensureRemote(remotes, name, className)
		if className == "RemoteEvent" then
			ensureRemote(legacyRemotes, name, className)
		end
	end

	for name, className in pairs(gameplayRemoteList) do
		ensureRemote(gameplayRemotes, name, className)
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
