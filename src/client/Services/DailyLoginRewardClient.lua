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
local Client = {}

local function suppressDailyLogin(): boolean
	local data = TeleportService:GetLocalPlayerTeleportData()
	if type(data) ~= "table" then return false end
	return data.MatchMode == "Ranked1v1" or data.MatchMode == "AICampaignSolo" or data.MatchMode == "WorldCupSolo" or data.WorldCup == true
end

local function showPayload(payload: any)
	if suppressDailyLogin() then return end
	if type(payload) ~= "table" or type(payload.Rewards) ~= "table" then return end
	Overlay.Show(payload, function()
		local ok, result = pcall(function()
			return claimRemote:InvokeServer()
		end)
		return ok and result or {Success = false, Message = "Claim failed."}
	end)
end

function Client.Open()
	local ok, result = pcall(function()
		return claimRemote:InvokeServer("Peek")
	end)
	if not ok or type(result) ~= "table" or type(result.Data) ~= "table" then
		warn("[Daily Rewards] Unable to load daily reward status.")
		return
	end
	showPayload(result.Data)
end

function Client.Start()
	if started then return end
	started = true
	pendingRemote.OnClientEvent:Connect(function(payload)
		if payload.Claimable ~= true then return end
		showPayload(payload)
	end)
end

Client.Start()

return Client
