--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local RemoteResolver = require(script.Parent.RemoteResolver)
local remote = RemoteResolver.WaitForFunction(NetworkConfig.PlayerDataFunction)

local PlayerDatabaseService = {}

function PlayerDatabaseService:GetDetails(cardInstanceId: string): any
	local ok, response = pcall(function() return remote:InvokeServer("GetPlayerDetails", { cardInstanceId = cardInstanceId }) end)
	if not ok or type(response) ~= "table" then return { Success = false, Message = "Player database unavailable." } end
	return response
end
function PlayerDatabaseService:Search(filters:any,offset:number?,limit:number?):any local ok,response=pcall(function()return remote:InvokeServer("SearchPlayers",{Filters=filters,Offset=offset or 0,Limit=limit or 50})end);if not ok or type(response)~="table"then return{Success=false,Message="Player search unavailable."}end;return response end

return PlayerDatabaseService
