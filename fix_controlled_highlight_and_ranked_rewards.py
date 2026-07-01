from pathlib import Path
import re

indicator_path = Path("src/client/Components/VoltraControlledPlayerIndicator.lua")
indicator_path.write_text('''--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Indicator = {}
Indicator.__index = Indicator

local function makeBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "VTRControlledPlayerTag"
	gui.Size = UDim2.fromOffset(112, 46)
	gui.StudsOffset = Vector3.new(0, 4.15, 0)
	gui.AlwaysOnTop = true
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "Tag"
	text.BackgroundTransparency = 0.12
	text.BackgroundColor3 = Color3.fromHex("060906")
	text.BorderSizePixel = 0
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.fromScale(0.5, 0)
	text.Size = UDim2.fromOffset(78, 23)
	text.Text = "YOU"
	text.TextColor3 = Color3.fromHex("F5F7F2")
	text.TextSize = 12
	text.Font = Enum.Font.GothamBlack
	text.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("F5F7F2")
	stroke.Transparency = 0.18
	stroke.Thickness = 1.25
	stroke.Parent = text
	local point = Instance.new("TextLabel")
	point.BackgroundTransparency = 1
	point.AnchorPoint = Vector2.new(0.5, 0)
	point.Position = UDim2.fromScale(0.5, 0.46)
	point.Size = UDim2.fromOffset(28, 18)
	point.Text = "▼"
	point.TextColor3 = Color3.fromHex("F5F7F2")
	point.TextSize = 17
	point.Font = Enum.Font.GothamBlack
	point.Parent = holder
	return gui
end

function Indicator.new(modelGetter: () -> Model?)
	local self = setmetatable({}, Indicator)
	self.ModelGetter = modelGetter
	for _, item in ipairs(workspace:GetDescendants()) do
		if item.Name == "VTRControlledPlayerHighlight" or item.Name == "VTRControlledPlayerRing" then
			item:Destroy()
		end
	end
	self.Tag = makeBillboard()
	self.Tag.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Connection = RunService.RenderStepped:Connect(function()
		self:_step()
	end)
	return self
end

function Indicator:_step()
	local model = self.ModelGetter and self.ModelGetter() or nil
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not model or not root or not root:IsA("BasePart") then
		self.Tag.Adornee = nil
		return
	end
	self.Tag.Adornee = root
end

function Indicator:Destroy()
	if self.Connection then self.Connection:Disconnect() end
	if self.Tag then self.Tag:Destroy() end
end

return Indicator
''', encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

if "VTRControlledPlayerHighlight" not in gameplay:
	gameplay = gameplay.replace(
'''local function clearGreenScreenEffects()''',
'''local function clearGreenScreenEffects()
	for _, item in ipairs(workspace:GetDescendants()) do
		if item.Name == "VTRControlledPlayerHighlight" or item.Name == "VTRControlledPlayerRing" then
			item:Destroy()
		end
	end''',
1
	)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

ranked_pack_path = Path("src/server/Services/RankedWinPackReward.lua")
ranked_pack_path.write_text('''--!strict
local PackInstanceFactory = require(script.Parent.Parent.Data.PackInstanceFactory)

local Service = {}

local Packs = {
	{PackId = "bronze_pack", Name = "Voltra Spark Pack", Rarity = "Common", Weight = 800},
	{PackId = "silver_pack", Name = "Street Pulse Pack", Rarity = "Rare", Weight = 90},
	{PackId = "gold_pack", Name = "Neon Tactics Pack", Rarity = "Rare", Weight = 50},
	{PackId = "elite_pack", Name = "Elite Matchday Pack", Rarity = "Epic", Weight = 35},
	{PackId = "champion_pack", Name = "Voltra Vault Pack", Rarity = "Epic", Weight = 18},
	{PackId = "hero_pack", Name = "Ranked Champion Pack", Rarity = "Mythic", Weight = 6},
	{PackId = "voltra_pack", Name = "Icon Voltage Pack", Rarity = "Mythic", Weight = 1},
}

local Fallbacks = {"voltra_pack", "hero_pack", "champion_pack", "elite_pack", "gold_pack", "silver_pack", "bronze_pack"}

function Service.Roll(): any
	local total = 0
	for _, pack in Packs do
		total += pack.Weight
	end
	local roll = math.random() * total
	local cursor = 0
	for _, pack in Packs do
		cursor += pack.Weight
		if roll <= cursor then
			return table.clone(pack)
		end
	end
	return table.clone(Packs[1])
end

local function directAddPack(progression: any, player: Player, packId: string): any?
	local profile = progression and progression.Profiles and progression.Profiles:GetProfile(player)
	if not profile then return nil end
	profile.PackInventory = profile.PackInventory or {}
	local instance = PackInstanceFactory.Create(packId, "RankedWin")
	if not instance then return nil end
	table.insert(profile.PackInventory, instance)
	return instance
end

local function publishAll(progression: any, publish: ((Player, string, any) -> ())?, player: Player)
	if not publish or not progression then return end
	if progression.GetClientData then
		pcall(function()
			publish(player, "Progression", progression:GetClientData(player))
		end)
	end
	if progression.Inventory and progression.Inventory.GetClientData then
		pcall(function()
			publish(player, "Inventory", progression.Inventory:GetClientData(player))
		end)
	end
end

function Service.Grant(progression: any, player: Player, publish: ((Player, string, any) -> ())?): any
	local pack = Service.Roll()
	local granted = false
	local grantedId = pack.PackId
	local grantedInstance = nil
	if progression and progression.Inventory and progression.Inventory.AddPack then
		local attempts = {pack.PackId}
		for _, fallback in Fallbacks do
			if fallback ~= pack.PackId then
				table.insert(attempts, fallback)
			end
		end
		for _, packId in attempts do
			local ok, result = pcall(function()
				return progression.Inventory:AddPack(player, packId, packId, "RankedWin", 1)
			end)
			if ok and result then
				granted = true
				grantedId = packId
				if type(result) == "table" then
					grantedInstance = result[1]
				end
				break
			end
		end
	end
	if not granted then
		grantedInstance = directAddPack(progression, player, pack.PackId)
		if grantedInstance then
			granted = true
			grantedId = pack.PackId
		end
	end
	publishAll(progression, publish, player)
	return {
		Title = "RANKED WIN REWARD",
		Coins = 0,
		XP = 0,
		Pack = pack.Name,
		PackName = pack.Name,
		PackId = grantedId,
		PackInstanceId = grantedInstance and (grantedInstance.packInstanceId or grantedInstance.PackInstanceId) or nil,
		Rarity = pack.Rarity,
		Packs = granted and 1 or 0,
		PackGranted = granted,
		InventoryStored = granted,
		Source = "RankedWin",
	}
end

return Service
''', encoding="utf-8", newline="\n")

ranked_profile_path = Path("src/server/Services/RankedProfileService.lua")
ranked_profile = ranked_profile_path.read_text(encoding="utf-8")

ranked_profile = ranked_profile.replace(
'''function Service:RecordServerResult(player:Player,result:string,_legacyDelta:number,opponent:string,score:string,matchStats:any?):boolean
	if result=="ForfeitWin"then result="Win"elseif result=="ForfeitLoss"then result="Loss"end;if result~="Win"and result~="Draw"and result~="Loss"then return false end;local p=self.Profiles:GetProfile(player);if not p then return false end;local r=p.Ranked;local delta=0''',
'''function Service:RecordServerResult(player:Player,result:string,_legacyDelta:number,opponent:string,score:string,matchStats:any?):boolean
	if result=="ForfeitWin"then result="Win"elseif result=="ForfeitLoss"then result="Loss"end;if result~="Win"and result~="Draw"and result~="Loss"then return false end;local p=self.Profiles:GetProfile(player);if not p then return false end;p.Ranked=p.Ranked or{};local r=p.Ranked;r.Wins=tonumber(r.Wins)or 0;r.Draws=tonumber(r.Draws)or 0;r.Losses=tonumber(r.Losses)or 0;r.DivisionWins=tonumber(r.DivisionWins)or 0;r.ProtectedWins=tonumber(r.ProtectedWins)or 0;r.DivisionNumber=tonumber(r.DivisionNumber)or 7;r.VoltraRating=tonumber(r.VoltraRating)or 1000;r.WinStreak=tonumber(r.WinStreak)or 0;r.History=r.History or{};r.PlayerStats=r.PlayerStats or{MatchesPlayed=0,AverageRating=0,Goals=0,Assists=0,MOTM=0,HatTricks=0};local delta=0''',
1
)

ranked_profile_path.write_text(ranked_profile, encoding="utf-8", newline="\n")

ranked_queue_path = Path("src/server/Services/RankedQueueService.lua")
ranked_queue = ranked_queue_path.read_text(encoding="utf-8")

ranked_queue = ranked_queue.replace(
'''	self:_startGlobalPoll()
	return self''',
'''	self:_startGlobalPoll()
	self:_startRankedTeleportWatcher()
	return self''',
1
)

if "function Service:_startRankedTeleportWatcher()" not in ranked_queue:
	ranked_queue = ranked_queue.replace(
'''function Service:_startGlobalPoll()''',
'''function Service:_rankedTeleportData(player: Player): any?
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if type(teleportData) == "table" and teleportData.MatchMode == "Ranked1v1" then
		return teleportData
	end
	return nil
end

function Service:_tryStartTeleportRanked()
	if self.RankedTeleportStarted then return end
	local found = {}
	for _, player in Players:GetPlayers() do
		local data = self:_rankedTeleportData(player)
		if data then
			found[player] = data
		end
	end
	local homePlayer = nil
	local awayPlayer = nil
	local data = nil
	for player, teleportData in found do
		local homeId = tonumber(teleportData.HomeUserId)
		local awayId = tonumber(teleportData.AwayUserId)
		if player.UserId == homeId then homePlayer = player end
		if player.UserId == awayId then awayPlayer = player end
		data = teleportData
	end
	if not homePlayer or not awayPlayer or not data then return end
	if not homePlayer.Character or not awayPlayer.Character then return end
	if not homePlayer.Character:FindFirstChildOfClass("Humanoid") or not awayPlayer.Character:FindFirstChildOfClass("Humanoid") then return end
	local homeProfile = self.Profiles:GetProfile(homePlayer)
	local awayProfile = self.Profiles:GetProfile(awayPlayer)
	if not homeProfile or not awayProfile then return end
	local homeReady, homeMessage, homeRoster = self.RankedSquads:GetRoster(homePlayer)
	local awayReady, awayMessage, awayRoster = self.RankedSquads:GetRoster(awayPlayer)
	if not homeReady or not awayReady or not homeRoster or not awayRoster then
		self.Notifications:Send(homePlayer, "RANKED MATCH", homeMessage or "Home roster unavailable.", "Error")
		self.Notifications:Send(awayPlayer, "RANKED MATCH", awayMessage or "Away roster unavailable.", "Error")
		return
	end
	self.RankedTeleportStarted = true
	local homeSetup = self:BuildRankedSetup(homePlayer, homeProfile, homeRoster)
	local awaySetup = self:BuildRankedSetup(awayPlayer, awayProfile, awayRoster)
	local success, message = self.Runtime:StartRankedMatch(homePlayer, awayPlayer, homeSetup, awaySetup, homeRoster, awayRoster)
	if not success then
		self.RankedTeleportStarted = false
		self.Notifications:Send(homePlayer, "MATCH FAILED", message, "Error")
		self.Notifications:Send(awayPlayer, "MATCH FAILED", message, "Error")
		return
	end
	self.RankedSquads:ConsumeLoans(homePlayer)
	self.RankedSquads:ConsumeLoans(awayPlayer)
	local session = self.Runtime:GetSession(homePlayer)
	if session then
		session.PrivateRankedMatch = true
		session.ReturnPlaceId = tonumber(data.ReturnPlaceId) or tonumber(data.PlaceId) or game.PlaceId
		self:_attachResultHandlers(session, homePlayer, awayPlayer)
	end
end

function Service:_startRankedTeleportWatcher()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if self:_rankedTeleportData(player) then
					self:_tryStartTeleportRanked()
					break
				end
			end
			task.wait(.35)
		end
	end)
end

function Service:_startGlobalPoll()''',
1
	)

ranked_queue = ranked_queue.replace(
'''		if ended.RankedResultsRecorded==true then return end
		ended.RankedResultsRecorded=true
		self.RankedProfiles:RecordServerResult(home, homeResult, rpFor(homeResult), away.Name, score, personal("Home"))
		self.RankedProfiles:RecordServerResult(away, awayResult, rpFor(awayResult), home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), personal("Away"))''',
'''		if ended.RankedResultsRecorded==true then return end
		ended.RankedResultsRecorded=true
		self.RankedProfiles:RecordServerResult(home, homeResult, rpFor(homeResult), away.Name, score, personal("Home"))
		self.RankedProfiles:RecordServerResult(away, awayResult, rpFor(awayResult), home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), personal("Away"))
		if homeResult=="Win" or homeResult=="ForfeitWin" then session.RankedWinPackGrant(session,home) end
		if awayResult=="Win" or awayResult=="ForfeitWin" then session.RankedWinPackGrant(session,away) end''',
1
)

ranked_queue = ranked_queue.replace(
'''			if self.Publish and self.RankedProfiles.GetClientData then
				pcall(function()self.Publish(home,"Ranked",self.RankedProfiles:GetClientData(home))end)
				pcall(function()self.Publish(away,"Ranked",self.RankedProfiles:GetClientData(away))end)
			end''',
'''			if self.Publish and self.RankedProfiles.GetClientData then
				pcall(function()self.Publish(home,"Ranked",self.RankedProfiles:GetClientData(home))end)
				pcall(function()self.Publish(away,"Ranked",self.RankedProfiles:GetClientData(away))end)
			end
			if self.Publish and self.Progression then
				if self.Progression.GetClientData then
					pcall(function()self.Publish(home,"Progression",self.Progression:GetClientData(home))end)
					pcall(function()self.Publish(away,"Progression",self.Progression:GetClientData(away))end)
				end
				if self.Progression.Inventory and self.Progression.Inventory.GetClientData then
					pcall(function()self.Publish(home,"Inventory",self.Progression.Inventory:GetClientData(home))end)
					pcall(function()self.Publish(away,"Inventory",self.Progression.Inventory:GetClientData(away))end)
				end
			end''',
1
)

ranked_queue_path.write_text(ranked_queue, encoding="utf-8", newline="\n")

print("fixed controlled player workspace highlight and forced ranked rewards/inventory publishing")