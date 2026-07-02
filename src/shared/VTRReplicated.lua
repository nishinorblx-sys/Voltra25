local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VTRReplicated = {}

local function child(parent, name)
	if parent then
		return parent:FindFirstChild(name)
	end
	return nil
end

function VTRReplicated.GetRoot()
	return child(ReplicatedStorage, "VTR") or ReplicatedStorage
end

function VTRReplicated.GetShared()
	local root = VTRReplicated.GetRoot()
	return child(root, "Shared") or child(ReplicatedStorage, "Shared") or root
end

function VTRReplicated.GetRemotes()
	local root = VTRReplicated.GetRoot()
	local remotes = child(root, "Remotes") or child(ReplicatedStorage, "Remotes")

	if not remotes and root then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = root
	end

	return remotes
end

function VTRReplicated.GetOrCreateRemoteFolder(name)
	local remotes = VTRReplicated.GetRemotes()
	local folder = remotes:FindFirstChild(name)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = remotes
	end

	return folder
end

function VTRReplicated.WaitForSharedModule(name)
	local shared = VTRReplicated.GetShared()
	return shared:WaitForChild(name)
end

return VTRReplicated
