--!strict

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local GOLD = "#FFD43B"

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	if message.TextSource then
		local sender = Players:GetPlayerByUserId(message.TextSource.UserId)
		if sender and sender:GetAttribute("VTRVIP") == true then
			properties.PrefixText = string.format("<font color='%s'>[VIP]</font> %s", GOLD, message.PrefixText or "")
		end
	end
	return properties
end
