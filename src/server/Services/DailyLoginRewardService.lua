--!strict
local function vtrGetWorldCampaignWinProgress()
	local serverScriptService = game:GetService("ServerScriptService")
	local vtrServer = serverScriptService:FindFirstChild("VTRServer")
	local services = vtrServer and vtrServer:FindFirstChild("Services")
	local module = services and services:FindFirstChild("WorldCampaignWinProgressService")

	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and typeof(result) == "table" and result.TryRegisterFromArgs then
			return result
		end
	end

	return {
		TryRegisterFromArgs = function()
			return false
		end,
		RegisterWin = function()
			return false
		end,
	}
end

local VTRWorldCampaignWinProgress = vtrGetWorldCampaignWinProgress()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.VTR.Shared.DailyLoginRewardConfig)
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local EconomyConfig = require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))

local Service = {}
Service.__index = Service

local function ensureRemotes()
	local vtr = ReplicatedStorage:FindFirstChild("VTR") or Instance.new("Folder")
	vtr.Name = "VTR"
	vtr.Parent = ReplicatedStorage
	local remotesRoot = vtr:FindFirstChild("Remotes") or Instance.new("Folder")
	remotesRoot.Name = "Remotes"
	remotesRoot.Parent = vtr
	local folder = remotesRoot:FindFirstChild(Config.RemoteFolderName) or Instance.new("Folder")
	folder.Name = Config.RemoteFolderName
	folder.Parent = remotesRoot
	local pending = folder:FindFirstChild(Config.PendingRemoteName) or Instance.new("RemoteEvent")
	pending.Name = Config.PendingRemoteName
	pending.Parent = folder
	local claim = folder:FindFirstChild(Config.ClaimRemoteName) or Instance.new("RemoteFunction")
	claim.Name = Config.ClaimRemoteName
	claim.Parent = folder
	return pending :: RemoteEvent, claim :: RemoteFunction
end

local pendingRemote, claimRemote = ensureRemotes()

local function ensureState(profile: any, now: number): any
	profile.DailyLogin = type(profile.DailyLogin) == "table" and profile.DailyLogin or {}
	local state = profile.DailyLogin
	local weekKey = Config.WeekKey(now)
	if state.WeekKey ~= weekKey then
		state.WeekKey = weekKey
	end
	if state.TrackDay == nil then
		state.ClaimedDays = {}
		state.LastClaimedAt = 0
		state.LastClaimedDayKey = 0
		state.LastClaimedTrackDay = 0
	end
	state.ClaimedDays = type(state.ClaimedDays) == "table" and state.ClaimedDays or {}
	state.TrackDay = math.clamp(math.floor(tonumber(state.TrackDay) or 1), 1, Config.TrackLength)
	state.LastClaimedAt = math.max(0, math.floor(tonumber(state.LastClaimedAt) or 0))
	state.LastClaimedDayKey = math.floor(tonumber(state.LastClaimedDayKey) or 0)
	state.LastClaimedTrackDay = math.floor(tonumber(state.LastClaimedTrackDay) or 0)
	return state
end

local function currentDayKey(now: number): number
	return Config.DayIndex(now)
end

local function displayDayForState(state: any, now: number, maxDay: number): (number, boolean)
	local todayKey = currentDayKey(now)
	local claimedToday = state.LastClaimedDayKey == todayKey
	if claimedToday and state.LastClaimedTrackDay > 0 then
		return math.clamp(state.LastClaimedTrackDay, 1, maxDay), true
	end
	return math.clamp(math.floor(tonumber(state.TrackDay) or 1), 1, maxDay), false
end

local function rewardCopy(reward: any): any
	local result = table.clone(reward)
	if result.Type == "Pack" then
		local definition = Catalog.Packs[tostring(result.ItemId or "")]
		if definition then
			result.Label = result.Label or definition.Name
			result.PackName = definition.Name
			result.CardCount = definition.CardCount
			result.GuaranteedMinRarity = definition.GuaranteedMinRarity
		end
	end
	return result
end

local function hasVip(profile: any): boolean
	local ownership = profile and profile.StoreOwnership
	return type(ownership) == "table" and type(ownership.GamePasses) == "table" and table.find(ownership.GamePasses, "vip_pass") ~= nil
end

function Service.new(profiles: any, inventory: any, publish: (Player, string, any) -> ())
	return setmetatable({Profiles = profiles, Inventory = inventory, Publish = publish, Started = false, Busy = {}}, Service)
end

function Service:_payload(player: Player, profile: any): any
	local now = os.time()
	local state = ensureState(profile, now)
	local week = Config.WeekDefinition(now)
	local maxDay = math.max(1, #week.Rewards)
	local day, claimedToday = displayDayForState(state, now, maxDay)
	local rewards = {}
	for index, reward in ipairs(week.Rewards) do
		local copy = rewardCopy(reward)
		copy.Day = index
		copy.Claimed = state.ClaimedDays[tostring(index)] == true
		copy.Today = index == day
		table.insert(rewards, copy)
	end
	return {
		WeekKey = state.WeekKey,
		WeekName = week.Name,
		Subtitle = week.Subtitle,
		Day = day,
		TrackLength = maxDay,
		ClaimedToday = claimedToday,
		Rewards = rewards,
		Claimable = claimedToday ~= true and state.ClaimedDays[tostring(day)] ~= true,
		Completed = day >= maxDay and (claimedToday == true or state.ClaimedDays[tostring(maxDay)] == true),
		SecondsUntilReset = Config.SecondsUntilNextDay(now),
		SecondsUntilWeekEnd = Config.SecondsUntilWeekEnd(now),
	}
end

function Service:_push(player: Player, profile: any)
	if self.Publish then
		self.Publish(player, "Currency", {Coins = profile.Currency.Coins, Bolts = profile.Currency.Bolts, VoltraPoints = profile.Currency.VoltraPoints or 0})
		if self.Inventory and self.Inventory.GetClientData then
			self.Publish(player, "Inventory", self.Inventory:GetClientData(player))
		end
	end
end

function Service:_grant(player: Player, profile: any, reward: any, vip: boolean?): (boolean, string, any?)
	pcall(function() VTRWorldCampaignWinProgress.TryRegisterFromArgs(self, string) end)
	if reward.Type == "Coins" then
		local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0)) * (vip and 2 or 1)
		if amount <= 0 then return false, "Invalid coin reward.", nil end
		profile.Currency.Coins = math.min(EconomyConfig.MaximumCoins, (tonumber(profile.Currency.Coins) or 0) + amount)
		return true, "+" .. tostring(amount) .. " coins claimed." .. (vip and " VIP 2x daily bonus applied." or ""), {Type = "Coins", Amount = amount, Vip2x = vip == true}
	elseif reward.Type == "Bolts" then
		local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0)) * (vip and 2 or 1)
		if amount <= 0 then return false, "Invalid bolts reward.", nil end
		profile.Currency.Bolts = math.min(EconomyConfig.MaximumBolts, (tonumber(profile.Currency.Bolts) or 0) + amount)
		return true, "+" .. tostring(amount) .. " bolts claimed." .. (vip and " VIP 2x daily bonus applied." or ""), {Type = "Bolts", Amount = amount, Vip2x = vip == true}
	elseif reward.Type == "Pack" then
		local packId = tostring(reward.ItemId or "")
		local definition = Catalog.Packs[packId]
		if not definition then return false, "Unknown pack reward.", nil end
		local count = vip and 2 or 1
		local ok, packs = self.Inventory:AddPack(player, packId, definition.Name, "DailyLogin", count)
		if not ok then return false, "Pack grant failed.", nil end
		VTRPendingPackAnimation.Queue(player, packId)
		return true, definition.Name .. " claimed." .. (vip and " VIP 2x daily bonus granted an extra pack." or ""), {Type = "Pack", ItemId = packId, Pack = packs and packs[1], Packs = packs, Amount = count, Vip2x = vip == true}
	end
	return false, "Unsupported reward.", nil
end

function Service:Claim(player: Player): any
	if self.Busy[player] then return {Success = false, Message = "Daily reward is already processing."} end
	self.Busy[player] = true
	local ok, response = pcall(function()
		local profile = self.Profiles:GetProfile(player)
		if not profile then return {Success = false, Message = "Profile unavailable."} end
		local now = os.time()
		local state = ensureState(profile, now)
		local todayKey = currentDayKey(now)
		if state.LastClaimedDayKey == todayKey then
			return {Success = false, Message = "Today's login reward is already claimed.", Data = self:_payload(player, profile)}
		end
		local week = Config.WeekDefinition(now)
		local day = math.clamp(math.floor(tonumber(state.TrackDay) or 1), 1, math.max(1, #week.Rewards))
		local key = tostring(day)
		if state.ClaimedDays[key] == true then
			return {Success = false, Message = "This login track is complete.", Data = self:_payload(player, profile)}
		end
		local reward = week.Rewards[day]
		if not reward then return {Success = false, Message = "Daily reward unavailable."} end
		local vip = hasVip(profile)
		local granted, message, grantData = self:_grant(player, profile, reward, vip)
		if not granted then return {Success = false, Message = message} end
		state.ClaimedDays[key] = true
		state.LastClaimedTrackDay = day
		state.LastClaimedDayKey = todayKey
		state.LastClaimedAt = now
		state.TrackDay = math.clamp(day + 1, 1, math.max(1, #week.Rewards))
		for _, objective in profile.Objectives or {} do
			if objective.objectiveId == "claim_daily_reward" and objective.status ~= "claimed" then
				objective.progress = 1
				if objective.status == "active" then objective.status = "claimable" end
			end
		end
		if self.Profiles.Save then self.Profiles:Save(player) end
		self:_push(player, profile)
		return {Success = true, Message = message, Grant = grantData, Data = self:_payload(player, profile)}
	end)
	self.Busy[player] = nil
	if not ok then
		warn("[VTR DAILY LOGIN] Claim failed: " .. tostring(response))
		return {Success = false, Message = "Daily login claim failed."}
	end
	return response
end

function Service:Show(player: Player)
	task.spawn(function()
		if self.Profiles.WaitForProfile then self.Profiles:WaitForProfile(player, 8) end
		local profile = self.Profiles:GetProfile(player)
		if not profile or player.Parent ~= Players then return end
		local joinData = player:GetJoinData()
		local teleportData = joinData and joinData.TeleportData
		if type(teleportData) == "table" and (teleportData.MatchMode == "Ranked1v1" or teleportData.MatchMode == "AICampaignSolo" or teleportData.MatchMode == "WorldCupSolo" or teleportData.WorldCup == true) then
			return
		end
		task.wait(1.15)
		if player.Parent == Players then
			local payload = self:_payload(player, profile)
			if payload.Claimable == true then
				pendingRemote:FireClient(player, payload)
			end
		end
	end)
end

function Service:Start()
	if self.Started then return end
	self.Started = true
	claimRemote.OnServerInvoke = function(player: Player)
		return self:Claim(player)
	end
	for _, player in Players:GetPlayers() do
		self:Show(player)
	end
	Players.PlayerAdded:Connect(function(player)
		self:Show(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Busy[player] = nil
	end)
end

return Service
