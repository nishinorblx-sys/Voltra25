--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local remote = ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.PackFunction) :: RemoteFunction

local PackService = {}

local function request(action: string, payload: any?): any
	local ok, response = pcall(function() return remote:InvokeServer(action, payload or {}) end)
	if not ok or type(response) ~= "table" then return { Success = false, Message = "Pack service unavailable." } end
	return response
end

function PackService:GetInventory(): any return request("GetInventory") end
function PackService:Open(packInstanceId: string): any return request("OpenPack", { PackInstanceId = packInstanceId }) end
function PackService:OpenAll(packId: string): any return request("OpenAll", { PackId = packId }) end

return PackService
