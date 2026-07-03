--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local RemoteResolver=require(script.Parent.RemoteResolver)
local remote=RemoteResolver.WaitForFunction(NetworkConfig.LaunchFunction)
local Service={}
function Service:Request(action:string,payload:any?):any local ok,response=pcall(function() return remote:InvokeServer(action,payload or {}) end);if not ok or type(response)~="table" then return {Success=false,Message="Launch service unavailable."} end;return response end
return Service
