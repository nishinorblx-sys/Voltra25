--!strict

local CurrencyService = {}
CurrencyService.__index = CurrencyService

function CurrencyService.new(profiles: any, publish: (Player, string, any) -> ())
	return setmetatable({ Profiles = profiles, Publish = publish }, CurrencyService)
end

function CurrencyService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	return { Coins = profile.Currency.Coins, Bolts = profile.Currency.Bolts, VoltraPoints = profile.Currency.VoltraPoints or 0 }
end

-- Server-only mutation API. Never connect reward amounts directly to a remote.
function CurrencyService:Add(player: Player, currency: string, amount: number): boolean
	if (currency ~= "Coins" and currency ~= "Bolts" and currency ~= "VoltraPoints") or type(amount) ~= "number" or amount % 1 ~= 0 or amount <= 0 or amount > 100000 then return false end
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false end
	profile.Currency[currency] = tonumber(profile.Currency[currency]) or 0
	profile.Currency[currency] = math.clamp(profile.Currency[currency] + amount, 0, 999999999)
	if self.Profiles.Save then self.Profiles:Save(player) end
	self.Publish(player, "Currency", self:GetClientData(player))
	return true
end

return CurrencyService
