--!strict

local FixtureService = {}
FixtureService.__index = FixtureService

function FixtureService.new(profiles: any)
	return setmetatable({ Profiles = profiles }, FixtureService)
end

function FixtureService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	local fixtures = {}
	for _, fixture in profile.Fixtures do
		table.insert(fixtures, {
			Id = fixture.Id, HomeTeam = fixture.HomeTeam == "YOUR CLUB" and profile.Profile.SelectedClub or fixture.HomeTeam, AwayTeam = fixture.AwayTeam == "YOUR CLUB" and profile.Profile.SelectedClub or fixture.AwayTeam,
			Competition = fixture.Competition, StartsAt = fixture.StartsAt,
			DisplayTime = fixture.DisplayTime,
		})
	end
	return fixtures
end

return FixtureService
