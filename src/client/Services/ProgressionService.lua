--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local base=require(script.Parent.ServiceClient).create("Progression")
local RemoteResolver=require(script.Parent.RemoteResolver)
local claimRemote=RemoteResolver.WaitForFunction(NetworkConfig.ProgressionFunction)
local Service={}
function Service:Get() return base:Get() end
function Service:Observe(callback:(any)->()) return base:Observe(callback) end
function Service:Claim(kind:string,id:string):any
	local ok,response=pcall(function() return claimRemote:InvokeServer(kind,id) end)
	if not ok or type(response)~="table" then return {Success=false,Message="Claim service unavailable."} end
	return response
end
return Service
