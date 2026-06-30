--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local remote=ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.InventoryFunction)::RemoteFunction
local Service={}
function Service:Get():any for attempt=1,3 do local ok,response=pcall(function() return remote:InvokeServer("GetInventory") end);if ok and type(response)=="table" and response.Success then return response end;if attempt<3 then task.wait(.16*attempt)else return type(response)=="table" and response or {Success=false,Message="Inventory service unavailable."}end end;return {Success=false,Message="Inventory service unavailable."} end
return Service
