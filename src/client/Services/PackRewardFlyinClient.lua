local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VTRReplicated = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRReplicated", 15))

local Animation = require(script.Parent.Parent.Components.PackRewardFlyinAnimation)
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local remotes = VTRReplicated.GetRemotes():WaitForChild("PackRewardAnimationRemotes", 15)
local showRemote = remotes:WaitForChild("ShowPackRewardAnimation", 15)
local ackRemote = remotes:WaitForChild("AckPackRewardAnimation", 15)

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
		while localPlayer:GetAttribute("VTRInMatch") == true or localPlayer:GetAttribute("VTRHoldPackRewardFlyin") == true do
			task.wait(0.12)
		end
		local entry = table.remove(queue, 1)
		local dropUntil = tonumber(localPlayer:GetAttribute("VTRDropPackRewardFlyinUntil")) or 0
		if entry.pack == "starter_launch" then
			-- The founders starter pack is opened inside onboarding, so never
			-- show the "sent to inventory" fly-in for it.
		elseif dropUntil <= os.clock() then
			Animation.Play(entry.pack)
		end
		ackRemote:FireServer({ entry.id })
		task.wait(0.08)
	end

	localPlayer:SetAttribute("VTRDropPackRewardFlyinUntil", nil)
	running = false
end

showRemote.OnClientEvent:Connect(function(entries)
	push(entries)
	task.defer(drain)
end)

return true
