--!strict

local Players = game:GetService("Players")

local PlayerProfileService = {}
PlayerProfileService.__index = PlayerProfileService

function PlayerProfileService.new(store: any)
	return setmetatable({ Store = store }, PlayerProfileService)
end

function PlayerProfileService:Start()
	local function load(player: Player)
		local profile = self.Store:LoadAsync(player.UserId)
		profile.Profile.Avatar.UserId = player.UserId
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player) self.Store:Release(player.UserId) end)
	for _, player in Players:GetPlayers() do task.spawn(load, player) end
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do self.Store:SaveAsync(player.UserId, true) end
	end)
end

function PlayerProfileService:GetProfile(player: Player): any?
	if not player or player.Parent ~= Players then return nil end
	return self.Store:Get(player.UserId)
end

function PlayerProfileService:GetClientData(player: Player): any?
	local profile = self:GetProfile(player)
	if not profile then return nil end
	return {
		Username = player.Name,
		DisplayName = player.DisplayName,
		Level = profile.Profile.Level,
		XP = profile.Profile.XP,
		SelectedClub = profile.Profile.SelectedClub,
		ClubIdentity = table.clone(profile.ClubMembership),
		Avatar = {
			UserId = player.UserId,
			HeadshotType = profile.Profile.Avatar.HeadshotType,
			OutfitId = profile.Profile.Avatar.OutfitId,
		},
	}
end

return PlayerProfileService
