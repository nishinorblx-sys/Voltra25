--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local VTRReplicated = require((ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")):WaitForChild("VTRReplicated", 15))
local Config = require(VTRReplicated.WaitForSharedModule("DailyLoginRewardConfig"))
local Overlay = require(script.Parent.Parent.Components.DailyLoginRewardOverlay)

local remotes = VTRReplicated.GetRemotes():WaitForChild(Config.RemoteFolderName)
local pendingRemote = remotes:WaitForChild(Config.PendingRemoteName)
local claimRemote = remotes:WaitForChild(Config.ClaimRemoteName)

local started = false
local showing = false
local Client = {}

local function suppressDailyLogin(): boolean
	local player = game:GetService("Players").LocalPlayer
	if player and player:GetAttribute("VTRDailyLoginSuppressed") == true then return true end
	local data = TeleportService:GetLocalPlayerTeleportData()
	if type(data) ~= "table" then return false end
	return data.MatchMode == "Ranked1v1" or data.MatchMode == "AICampaignSolo" or data.MatchMode == "WorldCupSolo" or data.WorldCup == true
end

function Client.Start()
	if started then return end
	started = true
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("VTROpenDailyLoginReward")
	if existing then existing:Destroy() end
	local bindable = Instance.new("BindableEvent")
	bindable.Name = "VTROpenDailyLoginReward"
	bindable.Parent = playerGui
	bindable.Event:Connect(function()
		Client.Open()
	end)
	pendingRemote.OnClientEvent:Connect(function(payload)
		if suppressDailyLogin() then return end
		if type(payload) ~= "table" or type(payload.Rewards) ~= "table" then return end
		if payload.Claimable ~= true then return end
		Client.ShowPayload(payload)
	end)
end

function Client.ShowPayload(payload: any)
	if showing then return end
	showing = true
	Overlay.Show(payload, function()
		local ok, result = pcall(function()
			return claimRemote:InvokeServer()
		end)
		return ok and result or {Success = false, Message = "Claim failed."}
	end)
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	task.spawn(function()
		while playerGui:FindFirstChild("VTRDailyLoginOverlay") do
			task.wait(0.2)
		end
		showing = false
	end)
end

function Client.Open()
	if suppressDailyLogin() then return end
	local ok, result = pcall(function()
		return claimRemote:InvokeServer("Peek")
	end)
	if not ok or type(result) ~= "table" or result.Success ~= true or type(result.Data) ~= "table" then
		warn("[Daily Rewards] Could not load daily reward status.")
		return
	end
	Client.ShowPayload(result.Data)
end

Client.Start()

return Client
