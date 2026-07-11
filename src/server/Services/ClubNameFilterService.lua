--!strict
local TextService = game:GetService("TextService")

local Service = {}

local BLOCKED_TAGS = {
	ASS = true,
	FAG = true,
	FUK = true,
	FUCK = true,
	KKK = true,
	NIG = true,
	NAZI = true,
	SEX = true,
	SLUT = true,
	SHIT = true,
}

local function normalize(value: string): string
	return (value:match("^%s*(.-)%s*$") or ""):gsub("%s+", " ")
end

local function filterForBroadcast(player: Player, value: string): (boolean, string)
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(value, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(result) ~= "string" then
		return false, ""
	end
	return true, normalize(result)
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

	local ok, filtered = filterForBroadcast(player, trimmed)
	if not ok then
		return false, "Club name filter is unavailable. Try again."
	end
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
	if BLOCKED_TAGS[trimmed] then
		return false, "Tag not allowed."
	end
	local ok, filtered = filterForBroadcast(player, trimmed)
	if not ok then
		return false, "Tag filter is unavailable. Try again."
	end
	filtered = string.upper(filtered)
	if string.find(filtered, "#", 1, true) or filtered ~= trimmed then
		return false, "Tag not allowed."
	end
	return true, trimmed
end

return Service
