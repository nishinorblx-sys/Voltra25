--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)

local Service = {}

function Service.WaitForRemote(name: string, className: string, timeout: number?): Instance?
	local vtr = ReplicatedStorage:WaitForChild("VTR", timeout or 12)
	local remotes = vtr and vtr:FindFirstChild(NetworkConfig.FolderName) or nil
	local legacyRemotes = className == "RemoteEvent" and ReplicatedStorage:FindFirstChild(NetworkConfig.FolderName) or nil
	local deadline = os.clock() + (timeout or 12)
	local remote = (remotes and remotes:FindFirstChild(name)) or (legacyRemotes and legacyRemotes:FindFirstChild(name))
	while os.clock() < deadline do
		if remote and remote.ClassName == className then
			return remote
		end
		if not remotes and vtr then
			remotes = vtr:FindFirstChild(NetworkConfig.FolderName)
		end
		if className == "RemoteEvent" then
			legacyRemotes = legacyRemotes or ReplicatedStorage:FindFirstChild(NetworkConfig.FolderName)
		end
		if remote and remote.ClassName ~= className then
			task.wait(0.1)
		else
			if remotes then
				remote = remotes:FindFirstChild(name) or remotes:WaitForChild(name, 0.5)
			end
			if not remote and legacyRemotes then
				remote = legacyRemotes:FindFirstChild(name) or legacyRemotes:WaitForChild(name, 0.5)
			end
		end
		remote = (remotes and remotes:FindFirstChild(name)) or (legacyRemotes and legacyRemotes:FindFirstChild(name))
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
