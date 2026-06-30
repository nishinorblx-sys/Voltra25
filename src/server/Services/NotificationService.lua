--!strict

local NotificationService = {}
NotificationService.__index = NotificationService

function NotificationService.new(remote: RemoteEvent)
	return setmetatable({ Remote = remote }, NotificationService)
end

function NotificationService:Send(player: Player, title: string, message: string, kind: string?)
	if not player or type(title) ~= "string" or type(message) ~= "string" then return end
	self.Remote:FireClient(player, {
		Title = string.sub(title, 1, 40),
		Message = string.sub(message, 1, 160),
		Kind = if kind == "Error" or kind == "Reward" then kind else "Info",
	})
end

return NotificationService
