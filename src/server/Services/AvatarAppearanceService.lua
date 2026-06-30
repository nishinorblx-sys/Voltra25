--!strict
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local AppearanceTypes=require(game:GetService("ReplicatedStorage").VTR.Shared.AppearanceTypes)
local Service={}
function Service.Get(playerId:string):any?local player=PlayerDatabase.Get(playerId);return player and table.clone(player.appearance)or nil end
function Service.Validate(playerId:string):boolean local appearance=Service.Get(playerId);if not appearance then return false end;for _,field in AppearanceTypes.Required do if not AppearanceTypes.Allowed[field][appearance[field]]then return false end end;return true end
return Service
