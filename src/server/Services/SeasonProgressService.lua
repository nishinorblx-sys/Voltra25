--!strict

local SeasonProgressService = {}
SeasonProgressService.__index = SeasonProgressService

function SeasonProgressService.new(profiles: any, publish: (Player, string, any) -> ())
	return setmetatable({ Profiles = profiles, Publish = publish }, SeasonProgressService)
end

function SeasonProgressService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	local season = profile.Season
	return { Name = season.Name, Level = season.Level, XP = season.XP, RequiredXP = season.RequiredXP }
end

function SeasonProgressService:AddXP(player: Player, amount: number): boolean
	if type(amount) ~= "number" or amount % 1 ~= 0 or amount <= 0 or amount > 50000 then return false end
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false end
	local season = profile.Season
	season.XP += amount
	while season.XP >= season.RequiredXP do
		season.XP -= season.RequiredXP
		season.Level += 1
		season.RequiredXP = math.floor(season.RequiredXP * 1.08)
	end
	profile.Profile.Level = season.Level
	profile.Profile.XP = season.XP
	self.Publish(player, "SeasonProgress", self:GetClientData(player))
	self.Publish(player, "PlayerProfile", self.Profiles:GetClientData(player))
	return true
end

return SeasonProgressService
