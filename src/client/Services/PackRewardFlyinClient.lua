local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VTRReplicated = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRReplicated"))

local Animation = require(script.Parent.Parent.Components.PackRewardFlyinAnimation)

local remotes = VTRReplicated.GetRemotes():WaitForChild("PackRewardAnimationRemotes")
local showRemote = remotes:WaitForChild("ShowPackRewardAnimation")
local ackRemote = remotes:WaitForChild("AckPackRewardAnimation")

local running = false
local queue = {}

local function push(entries)
	if typeof(entries) ~= "table" then
		return
	end

	for _, entry in ipairs(entries) do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and typeof(entry.pack) == "string" then
			table.insert(queue, entry)
		end
	end
end

local function drain()
	if running then
		return
	end

	running = true

	while #queue > 0 do
		local entry = table.remove(queue, 1)
		Animation.Play(entry.pack)
		ackRemote:FireServer({ entry.id })
		task.wait(0.18)
	end

	running = false
end

showRemote.OnClientEvent:Connect(function(entries)
	push(entries)
	task.defer(drain)
end)

return true
