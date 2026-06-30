--!strict

local RankedService = {}
RankedService.__index = RankedService

function RankedService.new(profiles: any, publish: (Player, string, any) -> ())
	return setmetatable({ Profiles = profiles, Publish = publish }, RankedService)
end

function RankedService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	local ranked = profile.Ranked
	return {
		Division = ranked.Division, Rank = ranked.Rank,
		Wins = ranked.Wins, Draws = ranked.Draws, Losses = ranked.Losses,
		RP = ranked.RP, RequiredRP = ranked.RequiredRP, WinStreak = ranked.WinStreak,
	}
end

-- Match results must only be supplied by trusted server match code.
function RankedService:RecordResult(player: Player, result: string, rpDelta: number): boolean
	if (result ~= "Win" and result ~= "Draw" and result ~= "Loss") or type(rpDelta) ~= "number" or rpDelta % 1 ~= 0 or math.abs(rpDelta) > 250 then return false end
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false end
	local ranked = profile.Ranked
	if result == "Win" then ranked.Wins += 1; ranked.WinStreak += 1 elseif result == "Draw" then ranked.Draws += 1; ranked.WinStreak = 0 else ranked.Losses += 1; ranked.WinStreak = 0 end
	ranked.RP = math.clamp(ranked.RP + rpDelta, 0, 999999)
	self.Publish(player, "Ranked", self:GetClientData(player))
	return true
end

return RankedService
