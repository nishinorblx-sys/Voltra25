--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)

local NotificationService = {}

function NotificationService.Start(callback: (any) -> ())
	local remote = ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.NotificationEvent) :: RemoteEvent
	return remote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Title) ~= "string" or type(payload.Message) ~= "string" then return end
		callback(payload)
	end)
end

return NotificationService
