--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local RemoteResolver = require(script.Parent.RemoteResolver)
local NetworkClient = require(script.Parent.NetworkClient)

local remote = RemoteResolver.WaitForFunction(NetworkConfig.CareerFunction)

local Service = {}

function Service.Action(action: string, payload: any?): any
	local ok, response = pcall(function() return remote:InvokeServer(action, type(payload) == "table" and payload or {}) end)
	if ok and type(response) == "table" then
		if response.Success == true and type(response.Data) == "table" and (action == "GetCareerHub" or action == "GetCareer") then
			NetworkClient.Cache.Career = response.Data
		end
		return response
	end
	return {Success = false, Message = "Career unavailable right now."}
end

function Service.GetHub(): any
	local cached = NetworkClient.Cache.Career
	if type(cached) == "table" then return cached end
	local response = Service.Action("GetCareerHub", {})
	if response.Success == true and type(response.Data) == "table" then return response.Data end
	return NetworkClient:Request("Career")
end

return Service
