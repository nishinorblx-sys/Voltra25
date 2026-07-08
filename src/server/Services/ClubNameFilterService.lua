--!strict
local TextService = game:GetService("TextService")

local Service = {}

local function normalize(value: string): string
	return (value:match("^%s*(.-)%s*$") or ""):gsub("%s+", " ")
end

function Service.Validate(player: Player, value: any, maximumLength: number?): (boolean, string)
	if type(value) ~= "string" then
		return false, "Club name is required."
	end
	local trimmed = normalize(value)
	local maxLength = maximumLength or 20
	if #trimmed < 3 or #trimmed > maxLength then
		return false, "Club name must be 3-"..maxLength.." characters."
	end
	if not trimmed:match("^[%w%s%-]+$") then
		return false, "Club name contains unsupported characters."
	end

	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(trimmed, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(result) ~= "string" then
		return false, "Club name filter is unavailable. Try again."
	end

	local filtered = normalize(result)
	if string.find(filtered, "#", 1, true) or string.lower(filtered) ~= string.lower(trimmed) then
		return false, "Club name was blocked by Roblox filtering."
	end

	return true, string.upper(trimmed)
end

function Service.ValidateTag(player: Player, value: any): (boolean, string)
	if type(value) ~= "string" then
		return false, "Tag is required."
	end
	local trimmed = normalize(string.upper(value))
	if not trimmed:match("^[A-Z][A-Z][A-Z]?[A-Z]?$") then
		return false, "Tag must be 2-4 uppercase letters."
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(trimmed, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(result) ~= "string" then
		return false, "Tag filter is unavailable. Try again."
	end
	local filtered = normalize(string.upper(result))
	if string.find(filtered, "#", 1, true) or filtered ~= trimmed then
		return false, "Tag not allowed."
	end
	return true, trimmed
end

return Service
