--!strict

local RunService = game:GetService("RunService")

local Remotes = {
	FolderName = "GameplayRemotes",
	ActionName = "GameplayAction",
	StateName = "GameplayState",
}

local function root(): Instance
	return script.Parent.Parent
end

function Remotes.Create(): (RemoteEvent, RemoteEvent)
	assert(RunService:IsServer(), "Remotes.Create is server-only")
	local folder = root():FindFirstChild(Remotes.FolderName) or Instance.new("Folder")
	folder.Name = Remotes.FolderName
	folder.Parent = root()
	local function event(name: string): RemoteEvent
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then return existing end
		if existing then existing:Destroy() end
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		return created
	end
	return event(Remotes.ActionName), event(Remotes.StateName)
end

function Remotes.Wait(): (RemoteEvent, RemoteEvent)
	local folder = root():WaitForChild(Remotes.FolderName)
	return folder:WaitForChild(Remotes.ActionName) :: RemoteEvent, folder:WaitForChild(Remotes.StateName) :: RemoteEvent
end

return table.freeze(Remotes)
