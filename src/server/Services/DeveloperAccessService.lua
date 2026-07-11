--!strict
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.VTR.Shared.DeveloperConfig)

local Service={}

function Service.IsAuthorized(player:Player):boolean
	if Config.AllowEveryone==true then return true end
	if RunService:IsStudio()then return true end
	if game.CreatorType==Enum.CreatorType.User and player.UserId==game.CreatorId then return true end
	if game.CreatorType==Enum.CreatorType.Group then local ok,rank=pcall(player.GetRankInGroup,player,game.CreatorId);if ok and rank==255 then return true end end
	return table.find(Config.UserIds,player.UserId)~=nil
end

function Service.IsOwner(player:Player):boolean
	if RunService:IsStudio()then return true end
	if game.CreatorType==Enum.CreatorType.User and player.UserId==game.CreatorId then return true end
	if game.CreatorType==Enum.CreatorType.Group then local ok,rank=pcall(player.GetRankInGroup,player,game.CreatorId);if ok and rank==255 then return true end end
	return table.find(Config.UserIds,player.UserId)~=nil
end

function Service.IsStudio():boolean return RunService:IsStudio()end

return Service
