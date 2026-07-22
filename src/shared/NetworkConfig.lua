--!strict

local NetworkConfig = {
	FolderName = "Remotes",
	RequestFunction = "RequestData",
	DataEvent = "DataUpdated",
	NotificationEvent = "Notification",
	UIStateEvent = "UpdateUIState",
	ProgressionFunction = "ProgressionAction",
	LaunchFunction = "LaunchAction",
	SquadFunction = "SquadAction",
	PlayerDataFunction = "PlayerDataAction",
	PackFunction = "PackAction",
	InventoryFunction = "InventoryAction",
	MatchFunction = "MatchSetupAction",
	CareerFunction = "CareerAction",
	DeveloperFunction = "DeveloperAction",
	RequestCooldown = 0.15,
	Services = table.freeze({
		PlayerProfile = true,
		Currency = true,
		SeasonProgress = true,
		Ranked = true,
		Objective = true,
		Fixture = true,
		UIState = true,
		Progression = true,
		Career = true,
	}),
}

return table.freeze(NetworkConfig)
