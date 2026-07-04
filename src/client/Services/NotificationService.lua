--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function vtrGetNotificationRemote()
	local vtr = ReplicatedStorage:FindFirstChild("VTR") or ReplicatedStorage:WaitForChild("VTR", 10)
	local remotes = vtr and (vtr:FindFirstChild("Remotes") or vtr:WaitForChild("Remotes", 10))
	local remote = vtrGetNotificationRemote()

	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	local dummy = script:FindFirstChild("VTRLocalNotification")
	if not dummy then
		dummy = Instance.new("RemoteEvent")
		dummy.Name = "VTRLocalNotification"
		dummy.Parent = script
	end

	return dummy
end
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)

local NotificationService = {}
local connection: RBXScriptConnection? = nil
local handler: ((any) -> ())? = nil
local backlog = {}

local function valid(payload: any): boolean
	return type(payload) == "table" and type(payload.Title) == "string" and type(payload.Message) == "string"
end

local function dispatch(payload: any)
	if not valid(payload) then return end
	if handler then
		handler(payload)
	elseif #backlog < 8 then
		table.insert(backlog, payload)
	end
end

function NotificationService.Start(callback: ((any) -> ())?)
	if callback then
		handler = callback
		for _, payload in backlog do
			handler(payload)
		end
		table.clear(backlog)
	end
	if connection then
		return connection
	end
	local remote = ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.NotificationEvent) :: RemoteEvent
	connection = remote.OnClientEvent:Connect(dispatch)
	return connection
end

function NotificationService.SetHandler(callback: ((any) -> ())?)
	handler = callback
	if handler then
		for _, payload in backlog do
			handler(payload)
		end
		table.clear(backlog)
	end
end

return NotificationService
