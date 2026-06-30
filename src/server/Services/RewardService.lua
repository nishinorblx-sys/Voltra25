--!strict
local RewardService={};RewardService.__index=RewardService
function RewardService.new(profiles:any,inventory:any) return setmetatable({Profiles=profiles,Inventory=inventory},RewardService) end
function RewardService:Grant(player:Player,reward:any):boolean local p=self.Profiles:GetProfile(player);if not p or type(reward)~="table" then return false end;if reward.Type=="Coins" then p.Currency.Coins+=reward.Amount elseif reward.Type=="Bolts" then p.Currency.Bolts+=reward.Amount elseif reward.Type=="XP" then p.Season.XP+=reward.Amount elseif reward.Type=="Pack" and reward.ItemId then return self.Inventory:AddPack(player,reward.ItemId,reward.ItemId,"Reward",reward.Amount or 1) else return false end;return true end
function RewardService:ClaimInbox(player:Player,id:string):boolean local p=self.Profiles:GetProfile(player);if not p then return false end;for _,reward in p.RewardsInbox do if reward.Id==id and not reward.Claimed then reward.Claimed=true;return true end end;return false end
return RewardService
