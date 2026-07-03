--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VTRDataDefaults = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRDataDefaults"))
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local RemoteResolver = require(script.Parent.RemoteResolver)

local remotes = ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName)
local requestData = RemoteResolver.WaitForFunction(NetworkConfig.RequestFunction)
local dataUpdated = remotes:WaitForChild(NetworkConfig.DataEvent) :: RemoteEvent

local STARTUP_TIMEOUT = 18
local RETRY_BASE = 0.25
local Player = game:GetService("Players").LocalPlayer

local NetworkClient = { Cache = {}, Listeners = {}, LastError = {} }

dataUpdated.OnClientEvent:Connect(function(serviceName: any, payload: any)
	if type(serviceName) ~= "string" or not NetworkConfig.Services[serviceName] or type(payload) ~= "table" then return end
	NetworkClient.Cache[serviceName] = payload
	for _, callback in NetworkClient.Listeners[serviceName] or {} do task.spawn(callback, payload) end
end)

function NetworkClient:Request(serviceName: string): any?
	if not NetworkConfig.Services[serviceName] then return nil end
	local deadline = os.clock() + STARTUP_TIMEOUT
	local attempt = 0
	local lastError = nil
	while os.clock() < deadline do
		attempt += 1
		local ok, response = pcall(function() return requestData:InvokeServer(serviceName) end)
		if ok and type(response) == "table" and response.Success and type(response.Data) == "table" then
			self.Cache[serviceName] = response.Data
			self.LastError[serviceName] = nil
			return response.Data
		end
		if ok and type(response) == "table" then
			lastError = response.Error or response.Message or "REQUEST_FAILED"
		elseif not ok then
			lastError = response
		else
			lastError = "BAD_RESPONSE"
		end
		if self.Cache[serviceName] then return self.Cache[serviceName] end
		task.wait(math.min(RETRY_BASE * attempt, 1.25))
	end
	self.LastError[serviceName] = lastError
	warn(("VTR data request still unavailable: %s (%s)"):format(serviceName, tostring(lastError)))
	local fallback = VTRDataDefaults.ForKey(Player, serviceName)
	self.Cache[serviceName] = fallback
	return fallback
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
