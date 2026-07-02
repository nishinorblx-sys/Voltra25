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

local function attachDefaultFunction(remote)
	if remote and remote:IsA("RemoteFunction") then
		pcall(function()
			remote.OnServerInvoke = defaultData
		end)
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
