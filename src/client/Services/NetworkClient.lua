--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VTRDataDefaults = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRDataDefaults"))
local function vtrWaitNetworkRemote(name, className)
	local vtr = ReplicatedStorage:WaitForChild("VTR", 10) or ReplicatedStorage:FindFirstChild("VTR")
	local remotes = vtr and (vtr:FindFirstChild("Remotes") or vtr:WaitForChild("Remotes", 10))
	local remote = remotes and (remotes:FindFirstChild(name) or remotes:WaitForChild(name, 10))

	if remote and remote.ClassName == className then
		return remote
	end

	warn(name .. " remote missing")
	return nil
end
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)

local remotes = ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName)
local requestData = remotes:WaitForChild(NetworkConfig.RequestFunction) :: RemoteFunction
local dataUpdated = remotes:WaitForChild(NetworkConfig.DataEvent) :: RemoteEvent

local NetworkClient = { Cache = {}, Listeners = {} }

dataUpdated.OnClientEvent:Connect(function(serviceName: any, payload: any)
	if type(serviceName) ~= "string" or not NetworkConfig.Services[serviceName] or type(payload) ~= "table" then return end
	NetworkClient.Cache[serviceName] = payload
	for _, callback in NetworkClient.Listeners[serviceName] or {} do task.spawn(callback, payload) end
end)

function NetworkClient:Request(serviceName: string): any?
	if not NetworkConfig.Services[serviceName] then return nil end
	for attempt = 1, 3 do
		local ok, response = pcall(function() return requestData:InvokeServer(serviceName) end)
		if ok and type(response) == "table" and response.Success and type(response.Data) == "table" then
			self.Cache[serviceName] = response.Data
			return response.Data
		end
		if attempt < 3 then task.wait(0.2 * attempt) end
	end
	warn("VTR data request failed:", serviceName)
	return self.Cache[serviceName]
end

function NetworkClient:Observe(serviceName: string, callback: (any) -> ()): () -> ()
	self.Listeners[serviceName] = self.Listeners[serviceName] or {}
	table.insert(self.Listeners[serviceName], callback)
	local connected = true
	return function()
		if not connected then return end
		connected = false
		local listeners = self.Listeners[serviceName]
		local index = table.find(listeners, callback)
		if index then table.remove(listeners, index) end
	end
end

return NetworkClient
