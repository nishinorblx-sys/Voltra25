--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("VTR"):WaitForChild("Shared")
local NetworkConfig = require(Shared.NetworkConfig)
local DefaultProfile = require(script.Parent.Data.DefaultProfile)
local MockProfileStore = require(script.Parent.MockProfileStore)
local ProfileService = require(script.Parent.Services.ProfileService)
local CurrencyService = require(script.Parent.Services.CurrencyService)
local SeasonProgressService = require(script.Parent.Services.SeasonProgressService)
local RankedService = require(script.Parent.Services.RankedService)
local ObjectiveService = require(script.Parent.Services.ObjectiveService)
local FixtureService = require(script.Parent.Services.FixtureService)
local NotificationService = require(script.Parent.Services.NotificationService)
local MatchTestService = require(script.Parent.Services.MatchTestService)
local GameplayConfig = require(Shared.GameplayConfig)
local UIStateService = require(script.Parent.Services.UIStateService)
local ProgressionService = require(script.Parent.Services.ProgressionService)
local LaunchService = require(script.Parent.Services.LaunchService)
local InventoryService = require(script.Parent.Services.InventoryService)
local PackService = require(script.Parent.Services.PackService)
local RewardService = require(script.Parent.Services.RewardService)
local SquadService = require(script.Parent.Services.SquadService)
local StoreService = require(script.Parent.Services.StoreService)
local RankedProfileService = require(script.Parent.Services.RankedProfileService)
local RankedQueueService = require(script.Parent.Services.RankedQueueService)
local RankedSquadService = require(script.Parent.Services.RankedSquadService)
local CareerService = require(script.Parent.Services.CareerService)
local ClubIdentityService = require(script.Parent.Services.ClubIdentityService)
local OnboardingService = require(script.Parent.Services.OnboardingService)
local PlayerDatabaseService = require(script.Parent.Services.PlayerDatabaseService)
local MatchSetupService = require(script.Parent.Services.MatchSetupService)
local MatchRuntimeService = require(script.Parent.Gameplay.MatchRuntimeService)
local TransferMarketService=require(script.Parent.Services.TransferMarketService)

local ServerApp = {}

local function remote(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then return existing end
	if existing then existing:Destroy() end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

function ServerApp.Start()
	local vtr = ReplicatedStorage:WaitForChild("VTR")
	local remotes = vtr:FindFirstChild(NetworkConfig.FolderName) or Instance.new("Folder")
	remotes.Name = NetworkConfig.FolderName
	remotes.Parent = vtr
	local requestData = remote(remotes, "RemoteFunction", NetworkConfig.RequestFunction) :: RemoteFunction
	local dataUpdated = remote(remotes, "RemoteEvent", NetworkConfig.DataEvent) :: RemoteEvent
	local notificationRemote = remote(remotes, "RemoteEvent", NetworkConfig.NotificationEvent) :: RemoteEvent
	local uiStateRemote = remote(remotes, "RemoteEvent", NetworkConfig.UIStateEvent) :: RemoteEvent
	local progressionAction = remote(remotes, "RemoteFunction", NetworkConfig.ProgressionFunction) :: RemoteFunction
	local launchAction = remote(remotes, "RemoteFunction", NetworkConfig.LaunchFunction) :: RemoteFunction
	local squadAction = remote(remotes, "RemoteFunction", NetworkConfig.SquadFunction) :: RemoteFunction
	local playerDataAction = remote(remotes, "RemoteFunction", NetworkConfig.PlayerDataFunction) :: RemoteFunction
	local packAction = remote(remotes, "RemoteFunction", NetworkConfig.PackFunction) :: RemoteFunction
	local inventoryAction = remote(remotes, "RemoteFunction", NetworkConfig.InventoryFunction) :: RemoteFunction
	local matchAction = remote(remotes, "RemoteFunction", NetworkConfig.MatchFunction) :: RemoteFunction

	local function publish(player: Player, serviceName: string, payload: any)
		if player.Parent == Players then dataUpdated:FireClient(player, serviceName, payload) end
	end

	local notifications = NotificationService.new(notificationRemote)
	-- v4 intentionally starts every account from a fresh launch profile.
	-- v5 is an intentional launch-simulation wipe. Do not bump this again unless another full reset is desired.
	local profiles = ProfileService.new(MockProfileStore.new(DefaultProfile, "VTR25_LaunchProfiles_v5"))
	local uiState = UIStateService.new(profiles, uiStateRemote, publish)
	local inventory = InventoryService.new(profiles)
	local progression = ProgressionService.new(profiles, publish, inventory)
	local packs = PackService.new(profiles, inventory)
	local playerDatabase = PlayerDatabaseService.new(inventory)
	local matchRuntime = MatchRuntimeService.new()
	local launch = LaunchService.new(profiles, progression, publish, inventory, packs)
	local rewards = RewardService.new(profiles, inventory)
	local squad = SquadService.new(profiles, publish, progression)
	local transferMarket=TransferMarketService.new(profiles,inventory,squad)
	local store = StoreService.new(profiles, inventory)
	local rankedProfile = RankedProfileService.new(profiles, publish)
	local rankedSquads=RankedSquadService.new(profiles)
	local matchSetup = MatchSetupService.new(profiles,publish,progression,matchRuntime,rankedSquads)
	local rankedQueue = RankedQueueService.new(profiles,matchRuntime,rankedProfile,notifications,rankedSquads)
	local career = CareerService.new(profiles)
	local clubIdentity = ClubIdentityService.new(profiles)
	local onboarding = OnboardingService.new(profiles)
	local services = {
		PlayerProfile = profiles,
		Currency = CurrencyService.new(profiles, publish),
		SeasonProgress = SeasonProgressService.new(profiles, publish),
		Ranked = rankedProfile,
		Objective = ObjectiveService.new(profiles, publish),
		Fixture = FixtureService.new(profiles),
		UIState = uiState,
		Progression = progression,
		Inventory = inventory,
		Pack = packs,
		Reward = rewards,
		Squad = squad,
		TransferMarket=transferMarket,
		Store = store,
		RankedProfile = rankedProfile,
		RankedQueue = rankedQueue,
		RankedSquad = rankedSquads,
		Career = career,
		ClubIdentity = clubIdentity,
		Onboarding = onboarding,
		PlayerDatabase = playerDatabase,
		MatchSetup = matchSetup,
		MatchRuntime = matchRuntime,
	}
	profiles:Start()
	transferMarket:Start()
	uiState:Start()

	local lastRequest: { [Player]: { [string]: number } } = {}
	requestData.OnServerInvoke = function(player: Player, serviceName: any)
		if type(serviceName) ~= "string" or #serviceName > 32 or not NetworkConfig.Services[serviceName] then
			return { Success = false, Error = "INVALID_SERVICE" }
		end
		local now = os.clock()
		local playerRequests = lastRequest[player] or {}
		lastRequest[player] = playerRequests
		if playerRequests[serviceName] and now - playerRequests[serviceName] < NetworkConfig.RequestCooldown then
			return { Success = false, Error = "RATE_LIMITED" }
		end
		playerRequests[serviceName] = now
		local service = services[serviceName]
		local ok, result = pcall(function() return service:GetClientData(player) end)
		if not ok or result == nil then return { Success = false, Error = "DATA_UNAVAILABLE" } end
		return { Success = true, Data = result }
	end
	local lastProgressionAction: { [Player]: number } = {}
	progressionAction.OnServerInvoke = function(player:Player,kind:any,id:any)
		if type(kind)~="string" or (kind~="Ranked" and kind~="Objective") or type(id)~="string" or #id>64 then return {Success=false,Message="Invalid request."} end
		local now=os.clock();if now-(lastProgressionAction[player] or 0)<.5 then return {Success=false,Message="Please wait."} end;lastProgressionAction[player]=now
		local ok,success,message,data=pcall(function() local claimed,text,result=progression:Claim(player,kind,id);return claimed,text,result end)
		return {Success=ok and success,Message=ok and message or "Claim failed.",Data=ok and data or nil}
	end
	local lastLaunchAction:{[Player]:number}={}
	launchAction.OnServerInvoke=function(player:Player,action:any,payload:any)
		if type(action)~="string" or #action>32 then return {Success=false,Message="Invalid action."} end;local now=os.clock();if now-(lastLaunchAction[player] or 0)<.25 then return {Success=false,Message="Please wait."} end;lastLaunchAction[player]=now
		local ok,success,message,data=pcall(function() local accepted,text,result=launch:Handle(player,action,payload);return accepted,text,result end);return {Success=ok and success,Message=ok and message or "Action failed.",Data=ok and data or nil}
	end
	local lastSquadAction:{[Player]:number}={}
	squadAction.OnServerInvoke=function(player:Player,action:any,payload:any)
		if type(action)~="string" or #action>32 then return {Success=false,Message="Invalid squad action."} end;local now=os.clock();if action~="GetSquad" and action~="GetSquadState" and action~="GetClubPlayers" and action~="GetEligiblePlayersForSlot" and now-(lastSquadAction[player] or 0)<.12 then return {Success=false,Message="Please wait."} end;lastSquadAction[player]=now;payload=type(payload)=="table" and payload or {}
		local ok,success,message,completed,data=pcall(function()
			if action=="GetSquad" then local data=squad:GetSquad(player);return data~=nil,data and "Squad loaded." or "Squad unavailable.",false,data
			elseif action=="GetSquadState" then local data=squad:GetSquadState(player);return data~=nil,data and "Squad state loaded." or "Squad unavailable.",false,data
			elseif action=="GetClubPlayers" then local data=squad:GetClubPlayers(player);return data~=nil,data and "Club players loaded." or "Club unavailable.",false,data
			elseif action=="GetEligiblePlayersForSlot" then local data=squad:GetEligiblePlayersForSlot(player,payload.Slot);return data~=nil,data and "Players loaded." or "Invalid slot.",false,data
			elseif action=="SetSquadSlot" then local accepted,text,justCompleted=squad:SetSquadSlot(player,payload.Slot,payload.CardId);return accepted,text,justCompleted,squad:GetSquad(player)
			elseif action=="RemoveSquadSlot" then local accepted,text,justCompleted=squad:RemoveSquadSlot(player,payload.Slot);return accepted,text,justCompleted,squad:GetSquad(player)
			elseif action=="AutoBuildSquad" then local accepted,text,justCompleted=squad:AutoBuildSquad(player);return accepted,text,justCompleted,squad:GetSquad(player)
			elseif action=="ClearSquad" then local accepted,text,justCompleted=squad:ClearSquad(player);return accepted,text,justCompleted,squad:GetSquad(player)
			elseif action=="MovePlayer" then local accepted,text,justCompleted=squad:MovePlayer(player,payload.CardId,payload.DestinationType,payload.DestinationSlot);return accepted,text,justCompleted,squad:GetSquad(player)
			elseif action=="SetFormation" then local accepted,text,justCompleted=squad:SetFormation(player,payload.Formation);return accepted,text,justCompleted,squad:GetSquad(player)
			elseif action=="SetCardFlag" then local accepted,text,justCompleted=squad:SetCardFlag(player,payload.CardId,payload.Flag,payload.Value);return accepted,text,justCompleted,squad:GetSquad(player)
			elseif action=="MoveCardToStarting" then local accepted,text,data=squad:MoveCardToStarting(player,payload.CardInstanceId,payload.PositionSlot);return accepted,text,false,data
			elseif action=="MoveCardToBench" then local accepted,text,data=squad:MoveCardToBench(player,payload.CardInstanceId,payload.BenchSlot);return accepted,text,false,data
			elseif action=="MoveCardToReserves" then local accepted,text,data=squad:MoveCardToReserves(player,payload.CardInstanceId);return accepted,text,false,data
			elseif action=="SwapCards" then local accepted,text,data=squad:SwapCards(player,payload.CardInstanceIdA,payload.CardInstanceIdB);return accepted,text,false,data
			elseif action=="RemoveCardFromStarting" then local accepted,text,data=squad:RemoveCardFromStarting(player,payload.PositionSlot);return accepted,text,false,data
			elseif action=="LockCard" then local accepted,text,data=squad:LockCard(player,payload.CardInstanceId,payload.Locked);return accepted,text,false,data
			elseif action=="FavoriteCard" then local accepted,text,data=squad:FavoriteCard(player,payload.CardInstanceId,payload.Favorite);return accepted,text,false,data
			elseif action=="QuickSellCard"then local accepted,text,data=squad:QuickSellCard(player,payload.CardInstanceId);return accepted,text,false,data
			elseif action=="CreateTransferListing"then local accepted,text,data=transferMarket:CreateListing(player,payload.CardInstanceId,payload.StartPrice,payload.Duration);return accepted,text,false,data
			elseif action=="GetTransferListings"then return true,"Listings loaded.",false,transferMarket:GetListings(player)
			elseif action=="PlaceTransferBid"then local accepted,text,data=transferMarket:PlaceBid(player,payload.ListingId,payload.Amount);return accepted,text,false,data end
			return false,"Unsupported squad action.",false,nil
		end)
		if not ok then return {Success=false,Message="Squad service failed."} end;return {Success=success,Message=message,CompletedNow=completed,Data=data}
	end
	local lastPlayerData:{[Player]:number}={}
	playerDataAction.OnServerInvoke=function(player:Player,action:any,payload:any)
		if type(payload)~="table" then return {Success=false,Message="Invalid player data request."} end
		local now=os.clock();if now-(lastPlayerData[player] or 0)<.12 then return {Success=false,Message="Please wait."} end;lastPlayerData[player]=now
		if action=="SearchPlayers" then local data=playerDatabase:Search(payload.Filters,payload.Offset,payload.Limit);return {Success=true,Data=data} end
		if action=="GetValidationReport" then return {Success=true,Data=playerDatabase:GetValidationReport()} end
		if action~="GetPlayerDetails" then return {Success=false,Message="Invalid player data request."} end
		local details=playerDatabase:GetOwnedPlayerDetails(player,payload.cardInstanceId)
		return details and {Success=true,Data=details} or {Success=false,Message="Player card is not owned."}
	end
	local lastPackAction:{[Player]:number}={}
	packAction.OnServerInvoke=function(player:Player,action:any,payload:any)
		if type(action)~="string" or #action>24 then return {Success=false,Message="Invalid pack request."} end
		if action=="GetInventory" then local data=packs:GetClientData(player);return data and {Success=true,Data=data} or {Success=false,Message="Pack inventory unavailable."} end
		if action=="OpenAll" then if type(payload)~="table" or type(payload.PackId)~="string" or #payload.PackId>48 then return {Success=false,Message="Invalid pack type."} end;local now=os.clock();if now-(lastPackAction[player] or 0)<.9 then return {Success=false,Message="Pack chamber is cooling down."} end;lastPackAction[player]=now;local ok,success,result,count=pcall(function() return packs:OpenAll(player,payload.PackId) end);if not ok or not success then return {Success=false,Message=ok and result or "Open All failed."} end;local p=profiles:GetProfile(player);if p then for _,instance in result do local exists=false;for _,item in p.Inventory.Items do if item.Id==instance.cardInstanceId then exists=true;break end end;if not exists then table.insert(p.Inventory.Items,{Id=instance.cardInstanceId,Kind="PlayerCard",Quantity=1,AcquiredAt=os.time()}) end end;for _,objective in p.Objectives do if objective.objectiveId=="open_first_pack" and objective.status~="claimed" then objective.progress=1;if objective.status=="active" then objective.status="claimable" end;break end end;launch:_push(player,p) end;return {Success=true,Message=count.." packs opened.",Data=result,OpenedCount=count,Inventory=packs:GetClientData(player)} end
		if action~="OpenPack" or type(payload)~="table" or type(payload.PackInstanceId)~="string" or #payload.PackInstanceId>80 then return {Success=false,Message="Invalid pack action."} end
		local now=os.clock();if now-(lastPackAction[player] or 0)<.9 then return {Success=false,Message="Pack chamber is cooling down."} end;lastPackAction[player]=now
		local ok,success,message,data=pcall(function() return launch:Handle(player,"OpenPack",{PackInstanceId=payload.PackInstanceId}) end)
		return {Success=ok and success,Message=ok and message or "Pack opening failed.",Data=ok and data or nil,Inventory=packs:GetClientData(player)}
	end
	local lastInventoryAction:{[Player]:number}={}
	inventoryAction.OnServerInvoke=function(player:Player,action:any)
		if action~="GetInventory" then return {Success=false,Message="Invalid inventory request."} end;local now=os.clock();if now-(lastInventoryAction[player] or 0)<.15 then return {Success=false,Message="Please wait."} end;lastInventoryAction[player]=now;local data=inventory:GetClientData(player);return data and {Success=true,Data=data} or {Success=false,Message="Inventory unavailable."}
	end
	local lastMatchAction:{[Player]:number}={}
	matchAction.OnServerInvoke=function(player:Player,action:any,payload:any)
		if type(action)~="string"or#action>32 then return{Success=false,Message="Invalid match action."}end;payload=type(payload)=="table"and payload or{};local now=os.clock();if action~="GetConfig"and action~="GetRoster"and action~="GetTeams"and now-(lastMatchAction[player]or 0)<.2 then return{Success=false,Message="Please wait."}end;lastMatchAction[player]=now
		local ok,success,message,data=pcall(function()if action=="GetConfig"then local result=matchSetup:GetClientData(player);return result~=nil,result and"Match setup loaded."or"Match setup unavailable.",result elseif action=="GetRoster"then local result=matchSetup:GetRoster(player,payload.TeamId);return result~=nil,result and"Roster loaded."or"Unknown team.",result elseif action=="GetTeams"then local result=matchSetup:GetTeams(player,payload.Country,payload.League);return result~=nil,result and"Teams loaded."or"Invalid country or league.",result elseif action=="SaveSetup"then return matchSetup:Save(player,payload)elseif action=="StartMatch"then return matchSetup:StartMatch(player)elseif action=="WatchMatch"then return matchSetup:WatchMatch(player)elseif action=="JoinRankedQueue"then return rankedQueue:Join(player)elseif action=="LeaveRankedQueue"then return rankedQueue:Leave(player)elseif action=="GetRankedQueue"then return true,"Ranked queue status loaded.",rankedQueue:GetStatus(player)elseif action=="ReturnToMenu"then local result=matchSetup:ReturnToMenu(player);return result,result and"Returned to menu."or"No active match.",nil end;return false,"Unsupported match action.",nil end)
		if not ok then
			warn("[VTR MATCH ERROR] "..tostring(success))
			return{Success=false,Message=RunService:IsStudio()and("Match failed: "..tostring(success))or"Match service failed.",Data=nil}
		end
		return{Success=success,Message=message,Data=data}
	end
	Players.PlayerRemoving:Connect(function(player)rankedQueue:PlayerRemoving(player);matchSetup:ReturnToMenu(player);lastRequest[player] = nil;lastProgressionAction[player]=nil;lastLaunchAction[player]=nil;lastSquadAction[player]=nil;lastPlayerData[player]=nil;lastPackAction[player]=nil;lastInventoryAction[player]=nil;lastMatchAction[player]=nil end)

	-- Public server API for future gameplay systems. Nothing here is exposed as
	-- a client-controlled mutation remote.
	ServerApp.Services = services
	ServerApp.NotificationService = notifications
	ServerApp.LaunchService = launch
	if GameplayConfig.AutoStartTestMatch then
		local matchTestService = MatchTestService.new()
		matchTestService:Start()
		ServerApp.MatchTestService = matchTestService
	end
	task.defer(function()
		for _, player in Players:GetPlayers() do notifications:Send(player, "VTR 25", "Profile connected to Voltra services.", "Info") end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			if player.Parent == Players then notifications:Send(player, "VTR 25", "Profile connected to Voltra services.", "Info") end
		end)
	end)
end

return ServerApp
