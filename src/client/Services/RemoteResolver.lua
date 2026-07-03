--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)

local Service = {}

function Service.WaitForRemote(name: string, className: string, timeout: number?): Instance?
	local remotes = ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName)
	local deadline = os.clock() + (timeout or 12)
	local remote = remotes:FindFirstChild(name)
	while os.clock() < deadline do
		if remote and remote.ClassName == className then
			return remote
		end
		if remote and remote.ClassName ~= className then
			task.wait(0.1)
		else
			remote = remotes:WaitForChild(name, 0.5)
		end
		remote = remotes:FindFirstChild(name)
	end
	warn(("[VTR REMOTE] %s expected %s but got %s"):format(name, className, remote and remote.ClassName or "nil"))
	return remote and remote.ClassName == className and remote or nil
end

function Service.WaitForFunction(name: string): RemoteFunction
	local remote = Service.WaitForRemote(name, "RemoteFunction", 12)
	assert(remote and remote:IsA("RemoteFunction"), name .. " RemoteFunction unavailable")
	return remote
end

return Service
