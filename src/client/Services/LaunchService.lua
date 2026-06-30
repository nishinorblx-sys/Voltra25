--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local remote=ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.LaunchFunction)::RemoteFunction
local Service={}
function Service:Request(action:string,payload:any?):any local ok,response=pcall(function() return remote:InvokeServer(action,payload or {}) end);if not ok or type(response)~="table" then return {Success=false,Message="Launch service unavailable."} end;return response end
return Service
