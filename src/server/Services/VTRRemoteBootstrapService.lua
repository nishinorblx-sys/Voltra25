local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRRemoteBootstrapService = {}

local remoteList = {
	AckPackRewardAnimation = "RemoteEvent",
	Away = "RemoteEvent",
	CameraAction = "RemoteEvent",
	ConfirmSevenWinLoginReward = "RemoteFunction",
	DataUpdated = "RemoteEvent",
	GameplayAction = "RemoteEvent",
	Home = "RemoteEvent",
	HumanoidRootPart = "RemoteEvent",
	InventoryAction = "RemoteEvent",
	KickoffAction = "RemoteEvent",
	MatchAction = "RemoteEvent",
	MatchSetupAction = "RemoteFunction",
	PackAction = "RemoteEvent",
	PackRewardAnimationRemotes = "RemoteEvent",
	PenaltyAction = "RemoteEvent",
	PendingSevenWinLoginReward = "RemoteEvent",
	PlayerModule = "RemoteEvent",
	PlayerScripts = "RemoteEvent",
	RankedMatchFound = "RemoteEvent",
	RequestData = "RemoteFunction",
	Score = "RemoteEvent",
	SetPieceAction = "RemoteEvent",
	ShowPackRewardAnimation = "RemoteEvent",
	SoundAction = "RemoteEvent",
	UpdateData = "RemoteEvent",
	UpdateUIState = "RemoteEvent",
	VTRReplicated = "RemoteEvent",
	VTRTestMatch = "RemoteEvent",
	leaderstats = "RemoteEvent",
}

local folderGroups = {
	Client = {
		PackRouletteAlignmentService = "RemoteEvent",
	},
	PackRewardAnimationRemotes = {
		AckPackRewardAnimation = "RemoteEvent",
		ShowPackRewardAnimation = "RemoteEvent",
	},
	PlayerScripts = {
		PlayerModule = "RemoteEvent",
	},
	SevenWinLoginRewardRemotes = {
		ConfirmSevenWinLoginReward = "RemoteFunction",
		PendingSevenWinLoginReward = "RemoteEvent",
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
