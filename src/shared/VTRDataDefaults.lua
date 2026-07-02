local VTRDataDefaults = {}

local function stat(player, name, default)
	local attr = player and player:GetAttribute(name)
	if attr ~= nil then
		return attr
	end

	local leaderstats = player and player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	if value and value:IsA("ValueBase") then
		return value.Value
	end

	return default
end

function VTRDataDefaults.ForKey(player, key)
	local wins = stat(player, "Wins", 0)
	local coins = stat(player, "Coins", 0)
	local gems = stat(player, "Gems", 0)
	local level = stat(player, "Level", 1)
	local xp = stat(player, "XP", 0)
	local rank = stat(player, "Rank", "Bronze")

	if key == "PlayerProfile" then
		return {
			UserId = player and player.UserId or 0,
			Name = player and player.Name or "",
			DisplayName = player and player.DisplayName or "",
			Wins = wins,
			Level = level,
			XP = xp,
			Rank = rank,
		}
	end

	if key == "Currency" then
		return {
			Coins = coins,
			Gems = gems,
			Cash = coins,
		}
	end

	if key == "SeasonProgress" then
		return {
			Level = level,
			XP = xp,
			Progress = 0,
			Rewards = {},
			Claimed = {},
		}
	end

	if key == "Ranked" then
		return {
			Rank = rank,
			Division = stat(player, "Division", 1),
			Rating = stat(player, "Rating", 0),
			Wins = wins,
			Losses = stat(player, "Losses", 0),
		}
	end

	if key == "Objective" then
		return {
			Daily = {},
			Weekly = {},
			Active = {},
			Completed = {},
		}
	end

	if key == "Fixture" then
		return {
			Matches = {},
			Current = nil,
			Next = nil,
		}
	end

	if key == "UIState" then
		return {
			Page = "Home",
			Modal = nil,
			Busy = false,
		}
	end

	if key == "Progression" then
		return {
			Level = level,
			XP = xp,
			NextLevelXP = 100,
			Rewards = {},
		}
	end

	return {}
end

return VTRDataDefaults
