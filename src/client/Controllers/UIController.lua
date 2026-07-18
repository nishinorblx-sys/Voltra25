--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Config = require(ReplicatedStorage.VTR.Shared.UIConfig)
local NavigationController = require(script.Parent.NavigationController)
local SidebarItem = require(script.Parent.Parent.Components.SidebarItem)
local ProgressBar = require(script.Parent.Parent.Components.ProgressBar)
local CurrencyBar = require(script.Parent.Parent.Components.CurrencyBar)
local PlayerProfileService = require(script.Parent.Parent.Services.PlayerProfileService)
local CurrencyService = require(script.Parent.Parent.Services.CurrencyService)
local SeasonProgressService = require(script.Parent.Parent.Services.SeasonProgressService)
local RankedService = require(script.Parent.Parent.Services.RankedService)
local ObjectiveService = require(script.Parent.Parent.Services.ObjectiveService)
local FixtureService = require(script.Parent.Parent.Services.FixtureService)
local NotificationService = require(script.Parent.Parent.Services.NotificationService)
local UIStateService = require(script.Parent.Parent.Services.UIStateService)
local ProgressionService = require(script.Parent.Parent.Services.ProgressionService)
local LaunchService = require(script.Parent.Parent.Services.LaunchService)
local PlayerDatabaseService = require(script.Parent.Parent.Services.PlayerDatabaseService)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)
local SettingsRuntimeService = require(script.Parent.Parent.Services.SettingsRuntimeService)
local UISoundService = require(script.Parent.Parent.Services.UISoundService)
local MenuMusicService = require(script.Parent.Parent.Services.MenuMusicService)
local PlayerDetailsModal = require(script.Parent.Parent.Components.PlayerDetailsModal)
local FlowController = require(script.Parent.FlowController)
local LoadingScreen = require(script.Parent.Parent.Components.LoadingScreen)
local ErrorState = require(script.Parent.Parent.Components.ErrorState)
local BackgroundEffects = require(script.Parent.Parent.Components.BackgroundEffects)
local AnimatedNumber = require(script.Parent.Parent.Components.AnimatedNumber)
local SplashScreen = require(script.Parent.Parent.Components.SplashScreen)
local OnboardingController = require(script.Parent.OnboardingController)
local NewcomerTutorialOverlay = require(script.Parent.Parent.Components.NewcomerTutorialOverlay)
local PlayabilityUnlockConfig = require(ReplicatedStorage.VTR.Shared.PlayabilityUnlockConfig)
local COINS_ICON = "rbxassetid://93869095461582"

local PageModules = {
	Home = require(script.Parent.Parent.Pages.HomePage),
	UltimateTeam = require(script.Parent.Parent.Pages.UltimateTeamPage),
	WorldCup = require(script.Parent.Parent.Pages.WorldCupPage),
	Inventory = require(script.Parent.Parent.Pages.InventoryPage),
	Campaign = require(script.Parent.Parent.Pages.CampaignPage),
	MyPlayer = require(script.Parent.Parent.Pages.MyPlayerPage),
	FiveVFive = require(script.Parent.Parent.Pages.FiveVFivePage),
	Ranked = require(script.Parent.Parent.Pages.RankedPage),
	Clubs = require(script.Parent.Parent.Pages.ClubsPage),
	Career = require(script.Parent.Parent.Pages.CareerPage),
	Store = require(script.Parent.Parent.Pages.StorePage),
	Settings = require(script.Parent.Parent.Pages.SettingsPage),
}

local UIController = {}
UIController.__index = UIController

local function normalizeRoute(id: string): string
	return id == "Play" and "Campaign" or id
end

local function progressionRouteUnlocked(progression: any, id: string): boolean
	return PlayabilityUnlockConfig.RouteUnlocked(progression, id)
end

local function label(text: string, size: number, color: Color3, font: Enum.Font): TextLabel
	local result = Instance.new("TextLabel")
	result.BackgroundTransparency = 1
	result.Size = UDim2.fromScale(1, 1)
	result.Text = text
	result.TextColor3 = color
	result.TextSize = size
	result.Font = font
	result.TextXAlignment = Enum.TextXAlignment.Left
	return result
end

local function formatNumber(value: number): string
	local formatted = tostring(math.floor(value))
	repeat
		local nextValue, substitutions = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = nextValue
	until substitutions == 0
	return formatted
end

local function crispScale(value: number): number
	local step = 0.125
	return math.max(Theme.Layout.MinimumScale, math.floor(value / step + 1e-6) * step)
end

function UIController.new()
	return setmetatable({}, UIController)
end

function UIController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild("VTR25")
	if previous then previous:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VTR25"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundColor3 = Theme.Colors.Black
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Active = true
	root.Selectable = false
	root.Parent = gui
	UISoundService.Bind(root)
	self.Root = root
	local splash = SplashScreen.new(root)
	task.wait(0.85)
	SplashScreen.complete(splash)
	task.wait(0.2)
	local notificationStack = Instance.new("Frame")
	notificationStack.Name = "NotificationStack"
	notificationStack.AnchorPoint = Vector2.new(1, 0)
	notificationStack.BackgroundTransparency = 1
	notificationStack.Position = UDim2.new(1, -20, 0, 92)
	notificationStack.Size = UDim2.fromOffset(340, 460)
	notificationStack.ZIndex = 900
	notificationStack.Parent = root
	local notificationLayout = Instance.new("UIListLayout")
	notificationLayout.Padding = UDim.new(0, 10)
	notificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	notificationLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notificationLayout.Parent = notificationStack
	self.NotificationStack = notificationStack
	self.Flow = FlowController.new(root, function(payload: any) self:_showNotification(payload) end)
	local loading = LoadingScreen.new(root)
	task.wait()

	local data = {
		Profile = PlayerProfileService:Get(),
		Currency = CurrencyService:Get(),
		Season = SeasonProgressService:Get(),
		Ranked = RankedService:Get(),
		Objectives = ObjectiveService:Get(),
		Fixtures = FixtureService:Get(),
		UIState = UIStateService:Get(),
		Progression = ProgressionService:Get(),
	}
	if not (data.Profile and data.Currency and data.Season and data.Ranked and data.Objectives and data.Fixtures and data.UIState and data.Progression) then
		loading:Destroy()
		ErrorState.new(root, "We couldn't load your Voltra profile. Check the server connection and try again.", function()
			if gui.Parent then gui:Destroy() end
			self:Start()
		end)
		return
	end
	self.Data = data
	local needsWorldCupOnboarding = data.Progression and data.Progression.Onboarding and data.Progression.Onboarding.Complete ~= true
	if needsWorldCupOnboarding then
		root.BackgroundTransparency = 1
		Players.LocalPlayer:SetAttribute("VTRDailyLoginSuppressed", true)
		Players.LocalPlayer:SetAttribute("VTRForceWorldCupOnboardingRoute", true)
	end
	SettingsRuntimeService.Apply(data.UIState.Settings)
	if needsWorldCupOnboarding then
		MenuMusicService.Stop()
	else
		MenuMusicService.Start()
	end

	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Scale = scale

	local backgroundEnergy = BackgroundEffects.new(root)
	backgroundEnergy.Visible = not needsWorldCupOnboarding

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundColor3 = Theme.Colors.Graphite
	sidebar.BorderSizePixel = 0
	sidebar.Size = UDim2.new(0, Theme.Layout.SidebarWidth, 1, 0)
	sidebar.Parent = root
	self.Sidebar = sidebar

	local logo = Instance.new("Frame")
	logo.Name = "Logo"
	logo.BackgroundTransparency = 1
	logo.Position = UDim2.fromOffset(24, 16)
	logo.Size = UDim2.new(1, -48, 0, 60)
	logo.Parent = sidebar
	self.Logo = logo
	local mark = label("V", 27, Theme.Colors.Black, Theme.Fonts.Display)
	mark.BackgroundColor3 = Theme.Colors.Electric
	mark.BackgroundTransparency = 0
	mark.Size = UDim2.fromOffset(42, 42)
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.Rotation = -4
	mark.Parent = logo
	local markCorner = Instance.new("UICorner")
	markCorner.CornerRadius = UDim.new(0, Theme.Radius.Medium)
	markCorner.Parent = mark
	local markGlow = Instance.new("UIStroke")
	markGlow.Color = Theme.Colors.Electric
	markGlow.Thickness = 2
	markGlow.Transparency = 0.8
	markGlow.Parent = mark
	TweenService:Create(markGlow, TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.2, Thickness = 4 }):Play()
	local logoTitle = label("VTR X", 21, Theme.Colors.White, Theme.Fonts.Display)
	logoTitle.Position = UDim2.fromOffset(54, 0)
	logoTitle.Size = UDim2.new(1, -54, 0, 29)
	logoTitle.Parent = logo
	local logoSub = label("VOLTRA FOOTBALL", 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	logoSub.Position = UDim2.fromOffset(55, 28)
	logoSub.Size = UDim2.new(1, -55, 0, 17)
	logoSub.Parent = logo

	local navHolder = Instance.new("ScrollingFrame")
	navHolder.Name = "Navigation"
	navHolder.BackgroundTransparency = 1
	navHolder.BorderSizePixel = 0
	navHolder.Position = UDim2.fromOffset(14, 84)
	navHolder.Size = UDim2.new(1, -28, 1, -250)
	navHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	navHolder.CanvasSize = UDim2.new()
	navHolder.CanvasPosition = Vector2.zero
	navHolder.ScrollBarThickness = 0
	navHolder.ScrollingDirection = Enum.ScrollingDirection.Y
	navHolder.ElasticBehavior = Enum.ElasticBehavior.Never
	navHolder.VerticalScrollBarInset = Enum.ScrollBarInset.None
	navHolder.Active = true
	navHolder.Selectable = false
	navHolder.ScrollingEnabled = true
	navHolder.Parent = sidebar
	self.NavHolder = navHolder
	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 5)
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	navLayout.Parent = navHolder

	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.BackgroundColor3 = Theme.Colors.Black
	topbar.BackgroundTransparency = 0.08
	topbar.BorderSizePixel = 0
	topbar.Position = UDim2.fromOffset(Theme.Layout.SidebarWidth, 0)
	topbar.Size = UDim2.new(1, -Theme.Layout.SidebarWidth, 0, Theme.Layout.TopbarHeight)
	topbar.Parent = root
	self.Topbar = topbar
	local breadcrumb = label("VTR X  /  HOME", 10, Theme.Colors.Muted, Theme.Fonts.Strong)
	breadcrumb.Position = UDim2.fromOffset(30, 0)
	breadcrumb.Size = UDim2.new(0.5, 0, 1, 0)
	breadcrumb.Parent = topbar
	local currency = CurrencyBar.new({
		{ Icon = "C", IconImage = COINS_ICON, Value = data.Currency.Coins },
		{ Icon = "VP", Value = data.Currency.VoltraPoints or 0 },
	})
	currency.AnchorPoint = Vector2.new(1, 0.5)
	currency.Position = UDim2.new(1, -132, 0.5, 0)
	currency.Parent = topbar
	self.Currency = currency
	local profile = Instance.new("Frame")
	profile.BackgroundColor3 = Theme.Colors.Gunmetal
	profile.BorderSizePixel = 0
	profile.Position = UDim2.new(1, -116, 0, 17)
	profile.Size = UDim2.fromOffset(96, 44)
	profile.Parent = topbar
	local profileCorner = Instance.new("UICorner")
	profileCorner.CornerRadius = UDim.new(0, Theme.Radius.Medium)
	profileCorner.Parent = profile
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 0
	avatar.BackgroundColor3 = Theme.Colors.Electric
	avatar.Position = UDim2.fromOffset(6, 6)
	avatar.Size = UDim2.fromOffset(32, 32)
	avatar.Parent = profile
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatar
	local profileName = label(string.upper(data.Profile.Username), 9, Theme.Colors.White, Theme.Fonts.Strong)
	profileName.Position = UDim2.fromOffset(44, 4)
	profileName.Size = UDim2.fromOffset(48, 21)
	profileName.Parent = profile
	self.ProfileName = profileName
	self.Avatar = avatar
	local status = label("● ONLINE", 7, Theme.Colors.Electric, Theme.Fonts.Strong)
	status.Position = UDim2.fromOffset(44, 22)
	status.Size = UDim2.fromOffset(50, 16)
	status.Parent = profile
	local settingsButton = Instance.new("ImageButton")
	settingsButton.Name = "SettingsIcon"
	settingsButton.AnchorPoint = Vector2.new(1, 0.5)
	settingsButton.BackgroundColor3 = Theme.Colors.Gunmetal
	settingsButton.BorderSizePixel = 0
	settingsButton.Image = ""
	settingsButton.Position = UDim2.new(1, -238, 0.5, 0)
	settingsButton.Size = UDim2.fromOffset(38, 38)
	settingsButton.Parent = topbar
	local settingsGear = Instance.new("ImageLabel")
	settingsGear.Name = "Gear"
	settingsGear.AnchorPoint = Vector2.new(.5, .5)
	settingsGear.BackgroundTransparency = 1
	settingsGear.Image = "rbxassetid://83473210181192"
	settingsGear.ImageColor3 = Theme.Colors.Electric
	settingsGear.Position = UDim2.fromScale(.5, .5)
	settingsGear.ScaleType = Enum.ScaleType.Fit
	settingsGear.Size = UDim2.fromOffset(24, 24)
	settingsGear.Parent = settingsButton
	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = UDim.new(0, Theme.Radius.Medium)
	settingsCorner.Parent = settingsButton
	settingsButton.Activated:Connect(function()
		if not self.Navigation then return end
		if self.Navigation.Current == "Settings" then return end
		self.Flow:ModeTransition("Settings", function() self.Navigation:Navigate("Settings"); UIStateService:SetLastPage("Settings") end)
	end)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.ClipsDescendants = true
	content.Position = UDim2.fromOffset(Theme.Layout.SidebarWidth, Theme.Layout.TopbarHeight)
	content.Size = UDim2.new(1, -Theme.Layout.SidebarWidth, 1, -Theme.Layout.TopbarHeight)
	content.Parent = root
	self.Content = content
	local onboardingChrome = { sidebar, topbar, content }
	local function setOnboardingChromeVisible(visible: boolean)
		root.BackgroundTransparency = visible and 0 or 1
		if backgroundEnergy and backgroundEnergy.Parent then
			backgroundEnergy.Visible = visible
		end
		if visible then
			MenuMusicService.Start()
		else
			MenuMusicService.Stop()
		end
		for _, object in ipairs(onboardingChrome) do
			if object and object.Parent then
				object.Visible = visible
				object:SetAttribute("VTRHiddenForWorldCupOnboarding", visible and nil or true)
			end
		end
	end
	if needsWorldCupOnboarding then
		setOnboardingChromeVisible(false)
	end

	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(data.Profile.Avatar.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and avatar.Parent then avatar.Image = image end
	end)

	local season = self:_createSeasonCard(data.Season)
	season.Position = UDim2.new(0, 14, 1, -238)
	season.Size = UDim2.new(1, -28, 0, 106)
	season.Parent = sidebar
	self.SeasonCard = season

	local navigation = NavigationController.new(breadcrumb)
	self.Navigation = navigation
	local order = {}
	for _, navData in Config.Navigation do
		local item = SidebarItem.new(navData, function(id)
			if not progressionRouteUnlocked(self.Data and self.Data.Progression, id) then
				self:_showNotification({Title = "KEEP PLAYING", Message = PlayabilityUnlockConfig.RouteRequirement(id), Kind = "Info"})
				return
			end
			self.Flow:ModeTransition(id, function() navigation:Navigate(id); UIStateService:SetLastPage(id) end)
		end)
		item.Instance.Parent = navHolder
		navigation:RegisterItem(navData.Id, item)
		local unlocked = progressionRouteUnlocked(data.Progression, navData.Id)
		item.Instance.Visible = unlocked
		item.Instance.Selectable = unlocked
		if unlocked then table.insert(order, navData.Id) end
	end

	local context = {
		Root = root,
		Theme = Theme,
		Config = Config,
		Data = data,
		Navigate = function(id: string)
			local route = normalizeRoute(id)
			if not progressionRouteUnlocked(self.Data and self.Data.Progression, route) then
				self:_showNotification({Title = "KEEP PLAYING", Message = PlayabilityUnlockConfig.RouteRequirement(route), Kind = "Info"})
				return
			end
			self.Flow:ModeTransition(route, function() navigation:Navigate(route); UIStateService:SetLastPage(route) end)
		end,
		IsCurrentPage = function(id: string) return navigation.Current == id end,
		HidePage = function(id: string) navigation:HidePage(id) end,
		SetSquadIncomplete = function(incomplete:boolean) self:_setSquadIncomplete(incomplete) end,
		Toast = function(payload: any) self:_showNotification(payload) end,
		Flow = self.Flow,
		RevealOnboardingMenu = function()
			setOnboardingChromeVisible(true)
		end,
		HideMenuForMatch = function()
			MenuMusicService.Stop()
			if gui.Parent then
				gui.Enabled = false
			end
		end,
		OpenPlayerDetails = function(cardInstanceId: string)
			local result = PlayerDatabaseService:GetDetails(cardInstanceId)
			if not result.Success then self:_showNotification({ Title = "PLAYER DATABASE", Message = result.Message or "Player details unavailable.", Kind = "Error" }); return end
			PlayerDetailsModal.open(root, result.Data)
		end,
		StateService = UIStateService,
		Persist = function(mode: string, action: any, state: any)
			if mode=="Ranked"and action.Operation=="RankedQueue"then return MatchSetupService:JoinRankedQueue()
			elseif mode=="Ranked"and action.Operation=="RankedQueueCancel"then return MatchSetupService:LeaveRankedQueue()
			elseif action.ServerAction == "DeveloperGrantCoins" or action.ServerAction == "DeveloperResetProfile" then return LaunchService:Request(action.ServerAction,{})
			elseif action.ServerAction == "BuyCoins" and action.ServerId then return LaunchService:Request("BuyCoins",{Id=action.ServerId})
			elseif action.Operation == "Claim" and action.ServerId then return ProgressionService:Claim(action.ServerKind, action.ServerId)
			elseif action.ServerAction == "OpenPack" and action.ServerId then return LaunchService:Request("OpenPack",{PackInstanceId=action.ServerId})
			elseif action.Operation == "Purchase" and action.ServerId then return LaunchService:Request("Purchase",{ItemType=action.ItemType,Id=action.ServerId,Quantity=action.Quantity or 1})
			elseif mode == "Career" and action.Operation == "Create" and (action.Key == "PlayerCareer" or action.Key == "ManagerCareer") then return LaunchService:Request("CreateCareer",{Type=action.Key == "PlayerCareer" and "Player" or "Manager"})
			elseif mode == "Clubs" and action.Operation == "Create" and action.Key == "ClubCreated" then return LaunchService:Request("CreateClub",action.FormValues or {})
			elseif action.Operation == "EquipToggle" then UIStateService:SetSquad(action.Slot, state.Equipped[action.Slot])
			elseif mode == "Settings" and action.Operation == "Toggle" then UIStateService:SetSetting(action.Key, state.Values[action.Key])
			elseif mode == "Settings" and action.Operation == "Select" then UIStateService:SetSetting(action.Key, state.Selections[action.Key])
			elseif mode == "Settings" and action.Operation == "ShowTutorial" then self:_showNewcomerTutorialIfNeeded(true)
			elseif (mode == "Store" or mode == "UltimateTeam") and action.Operation == "Select" then UIStateService:SetCosmetic(action.Key, action.Item)
			elseif mode == "Career" and action.Key == "SaveSlot" then UIStateService:SelectCareerSave(tonumber(string.match(action.Item, "%d+")) or 1) end
			return nil
		end,
	}
	self.Flow:SetPlayerDetailsHandler(context.OpenPlayerDetails)
	self.Flow:SetNavigator(context.Navigate)
	self.Flow:SetInventoryNavigator(function()
		local tab = PlayabilityUnlockConfig.FeatureUnlocked(context.Data.Progression, "Packs") and "Packs" or "Players"
		context.Data.UIState.SelectedTabs.Inventory=tab;UIStateService:SetTab("Inventory",tab);context.Navigate("Inventory")
	end)
	self.Context = context
	for id, pageModule in PageModules do
		local page = pageModule.new(context)
		page.Parent = content
		navigation:RegisterPage(id, page)
	end
	navigation:FinalizeSelectionOrder(order)
	local lastPage = tostring(data.UIState.LastPage or "Home")
	lastPage = normalizeRoute(lastPage)
	if lastPage == "Shooting" or not PageModules[lastPage] then lastPage = "Home" end
	if not progressionRouteUnlocked(data.Progression, lastPage) then lastPage = "Home" end
	if needsWorldCupOnboarding then
		lastPage="WorldCup"
	end
	navigation:Navigate(lastPage)
	self:_bindDataUpdates()
	NotificationService.Start(function(payload) self:_showNotification(payload) end)

	self:_bindResponsive()
	local function maybeShowTutorial()
		self:_showNewcomerTutorialIfNeeded()
	end
	if needsWorldCupOnboarding then
		LoadingScreen.complete(loading, function()
			task.spawn(function()MatchSetupService:ReportPlayability("FirstMenuVisible",{route="WorldCup"})end)
			if not RunService:IsStudio() and Players.LocalPlayer:GetAttribute("VTRWorldCupSoloServer") ~= true then
				local result = MatchSetupService:PrepareWorldCupTutorial()
				if result and result.Success and result.Data and result.Data.Teleporting == true then
					return
				end
			end
			navigation:Navigate("WorldCup")
			UIStateService:SetLastPage("WorldCup")
		end)
	else
		LoadingScreen.complete(loading, function()
			task.spawn(function()
				MatchSetupService:ReportPlayability("FirstMenuVisible",{route=tostring(navigation.Current or"Home")})
				local joinData=Players.LocalPlayer:GetJoinData()
				if type(joinData.TeleportData)=="table"then MatchSetupService:ReportPlayability("DestinationJoined",{route=tostring(navigation.Current or"Home")})end
			end)
			task.delay(0.35, maybeShowTutorial)
		end)
	end
end

function UIController:_showNewcomerTutorialIfNeeded(force: boolean?)
	if self.TutorialShowing then return end
	local settings = self.Data and self.Data.UIState and self.Data.UIState.Settings or {}
	local initialStep = math.max(1, math.floor(tonumber(settings.TutorialStep) or 1))
	if force == true and settings.TutorialComplete == true then
		initialStep = 1
		if self.Data and self.Data.UIState and self.Data.UIState.Settings then
			self.Data.UIState.Settings.TutorialComplete = false
			self.Data.UIState.Settings.TutorialStep = 1
			self.Data.UIState.Settings.TutorialDevice = ""
		end
		UIStateService:SetTutorialProgress(1, "", false)
	end
	if force ~= true then
		local isNew = Players.LocalPlayer:GetAttribute("VTRNewProfile") == true
		local onboardingComplete = self.Data and self.Data.Progression and self.Data.Progression.Onboarding and self.Data.Progression.Onboarding.Complete == true
		local tutorialStarted = initialStep > 1 or tostring(settings.TutorialDevice or "") ~= ""
		if settings.TutorialComplete == true or not onboardingComplete or (not isNew and not tutorialStarted) then
			return
		end
	end
	local function persistTutorial(step: number, device: string, complete: boolean)
		local savedStep = complete and 1 or math.max(1, math.floor(tonumber(step) or 1))
		if self.Data and self.Data.UIState and self.Data.UIState.Settings then
			self.Data.UIState.Settings.TutorialComplete = complete
			self.Data.UIState.Settings.TutorialStep = savedStep
			self.Data.UIState.Settings.TutorialDevice = tostring(device or "")
		end
		UIStateService:SetTutorialProgress(savedStep, tostring(device or ""), complete)
	end
	self.TutorialShowing = true
	NewcomerTutorialOverlay.show(self.Root, {
		InitialStep = initialStep,
		GetCurrentPage = function()
			return self.Navigation and self.Navigation.Current or nil
		end,
		GetTarget = function(id: string)
			local item = self.Navigation and self.Navigation.Items and self.Navigation.Items[id]
			return item and item.Instance or nil
		end,
		Navigate = function(id: string)
			if self.Context and self.Context.Navigate then
				self.Context.Navigate(id)
			end
		end,
		OnStep = function(step: number, device: string)
			persistTutorial(step, device, false)
		end,
		OnClose = function(step: number, device: string)
			self.TutorialShowing = false
			persistTutorial(step, device, false)
		end,
		OnComplete = function()
			self.TutorialShowing = false
			persistTutorial(1, "", true)
		end,
	})
end

function UIController:_replacePage(id: string)
	self.PageReplaceTokens = self.PageReplaceTokens or {}
	self.PageReplaceTokens[id] = (self.PageReplaceTokens[id] or 0) + 1
	local token = self.PageReplaceTokens[id]
	local oldPage = self.Navigation.Pages[id]
	if oldPage then
		local cleanup = oldPage:FindFirstChild("Cleanup")
		if cleanup and cleanup:IsA("BindableEvent") then cleanup:Fire() end
		oldPage.Visible = false
		oldPage.Active = false
		oldPage:Destroy()
	end
	self.Navigation.Pages[id] = nil
	for _, child in self.Content:GetChildren() do
		if child:IsA("CanvasGroup") and child.Name == id then
			local cleanup = child:FindFirstChild("Cleanup")
			if cleanup and cleanup:IsA("BindableEvent") then cleanup:Fire() end
			child.Visible = false
			child.Active = false
			child:Destroy()
		end
	end
	local newPage = PageModules[id].new(self.Context)
	if self.PageReplaceTokens[id] ~= token then
		newPage:Destroy()
		return
	end
	newPage.Visible = self.Navigation.Current == id
	newPage.Active = newPage.Visible
	newPage.Parent = self.Content
	self.Navigation.Pages[id] = newPage
	if self.Navigation.Current == id then
		newPage.Visible = true
		newPage.Active = true
		newPage.GroupTransparency = 0
		newPage.Position = UDim2.fromOffset(0, 0)
	end
	if self.Navigation and self.Navigation.SyncPageVisibility then
		self.Navigation:SyncPageVisibility()
	end
end

function UIController:_syncProgressionNavigation()
	if not self.Navigation then return end
	local order = {}
	for _, navData in Config.Navigation do
		local item = self.Navigation.Items[navData.Id]
		local unlocked = progressionRouteUnlocked(self.Data and self.Data.Progression, navData.Id)
		if item and item.Instance then
			item.Instance.Visible = unlocked
			item.Instance.Selectable = unlocked
		end
		if unlocked then table.insert(order, navData.Id) end
	end
	self.Navigation:FinalizeSelectionOrder(order)
	if self.Navigation.Current and not progressionRouteUnlocked(self.Data and self.Data.Progression, self.Navigation.Current) then
		self.Navigation:Navigate("Home")
		UIStateService:SetLastPage("Home")
	end
end

function UIController:_setSquadIncomplete(incomplete:boolean)
	local item=self.Navigation and self.Navigation.Items and self.Navigation.Items.UltimateTeam
	if item and item.SetWarning then item:SetWarning(incomplete==true)end
end

function UIController:_bindDataUpdates()
	PlayerProfileService:Observe(function(value)
		self.Data.Profile = value
		self.ProfileName.Text = string.upper(value.Username)
		for _, id in { "Home" } do self:_replacePage(id) end
	end)
	CurrencyService:Observe(function(value)
		self.Data.Currency = value
		local replacement = CurrencyBar.new({
			{ Icon = "C", IconImage = COINS_ICON, Value = value.Coins },
			{ Icon = "VP", Value = value.VoltraPoints or 0 },
		})
		replacement.AnchorPoint = self.Currency.AnchorPoint
		replacement.Position = self.Currency.Position
		replacement.Visible = self.Currency.Visible
		replacement.Parent = self.Topbar
		self.Currency:Destroy()
		self.Currency = replacement
	end)
	SeasonProgressService:Observe(function(value)
		self.Data.Season = value
		local replacement = self:_createSeasonCard(value)
		replacement.Position = self.SeasonCard.Position
		replacement.Size = self.SeasonCard.Size
		replacement.Parent = self.Sidebar
		self.SeasonCard:Destroy()
		self.SeasonCard = replacement
	end)
	RankedService:Observe(function(value)
		self.Data.Ranked = value
		self:_replacePage("Home")
		self:_replacePage("Ranked")
	end)
	ObjectiveService:Observe(function(value)
		self.Data.Objectives = value
		self:_replacePage("Home")
	end)
	FixtureService:Observe(function(value)
		self.Data.Fixtures = value
		self:_replacePage("Home")
	end)
	UIStateService:Observe(function(value)
		self.Data.UIState = value
		SettingsRuntimeService.Apply(value.Settings)
		for _, id in {"Inventory","Settings"} do self:_replacePage(id) end
	end)
	ProgressionService:Observe(function(value)
		self.Data.Progression = value
		self:_syncProgressionNavigation()
		for _, id in {"Home","UltimateTeam","Inventory","Campaign","Ranked","Store","Settings"} do self:_replacePage(id) end
	end)
end

function UIController:_createSeasonCard(seasonData: any): Frame
	local panel = Instance.new("Frame")
	panel.Name = "SeasonProgress"
	panel.BackgroundColor3 = Theme.Colors.Graphite
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.Large)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Border
	stroke.Parent = panel
	local tag = label(seasonData.Name, 9, Theme.Colors.Electric, Theme.Fonts.Strong)
	tag.Position = UDim2.fromOffset(14, 10)
	tag.Size = UDim2.new(1, -28, 0, 20)
	tag.Parent = panel
	local level = label("LVL " .. seasonData.Level, 19, Theme.Colors.White, Theme.Fonts.Display)
	level.Position = UDim2.fromOffset(14, 31)
	level.Size = UDim2.new(1, -28, 0, 25)
	level.Parent = panel
	task.defer(function() if level.Parent then AnimatedNumber.play(level, seasonData.Level, { Prefix = "LVL " }) end end)
	local progress = ProgressBar.new(seasonData.XP / seasonData.RequiredXP)
	progress.Position = UDim2.fromOffset(14, 67)
	progress.Size = UDim2.new(1, -28, 0, 5)
	progress.Parent = panel
	local xp = label(formatNumber(seasonData.XP) .. " / " .. formatNumber(seasonData.RequiredXP) .. " XP", 8, Theme.Colors.Muted, Theme.Fonts.Body)
	xp.Position = UDim2.fromOffset(14, 77)
	xp.Size = UDim2.new(1, -28, 0, 18)
	xp.Parent = panel
	task.defer(function()
		if xp.Parent then AnimatedNumber.play(xp, seasonData.XP, { Suffix = " / " .. formatNumber(seasonData.RequiredXP) .. " XP" }) end
	end)
	return panel
end

function UIController:_showNotification(payload: any)
	local visible={};for _,child in self.NotificationStack:GetChildren()do if child:IsA("GuiObject")and child.Name=="Notification"then table.insert(visible,child)end end;table.sort(visible,function(a,b)return a.LayoutOrder<b.LayoutOrder end);while#visible>=3 do local oldest=table.remove(visible,1);oldest:Destroy()end
	local kind = tostring(payload.Kind or "Info")
	local accent = (kind == "Error" and Theme.Colors.Danger) or (kind == "Warning" and Theme.Colors.Warning) or Theme.Colors.Electric
	local baseZ = 900
	local toast = Instance.new("Frame")
	toast.Name = "Notification"
	toast.BackgroundColor3 = Color3.fromRGB(4, 6, 8)
	toast.BackgroundTransparency = 0.03
	toast.BorderSizePixel = 0
	toast.Size = UDim2.fromOffset(332, 92)
	toast.ZIndex = baseZ
	self.ToastSerial=(self.ToastSerial or 0)+1;toast.LayoutOrder=self.ToastSerial
	toast.Parent = self.NotificationStack
	local toastScale = Instance.new("UIScale")
	toastScale.Scale = 0.94
	toastScale.Parent = toast
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.Large)
	corner.Parent = toast
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 26, 20)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(8, 11, 12)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 3, 4)),
	})
	gradient.Rotation = 18
	gradient.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Transparency = 0.08
	stroke.Thickness = 1.25
	stroke.Parent = toast
	local rail = Instance.new("Frame")
	rail.Name = "AccentRail"
	rail.BackgroundColor3 = accent
	rail.BorderSizePixel = 0
	rail.Position = UDim2.fromOffset(0, 0)
	rail.Size = UDim2.new(0, 5, 1, 0)
	rail.ZIndex = baseZ + 1
	rail.Parent = toast
	local railCorner = Instance.new("UICorner")
	railCorner.CornerRadius = UDim.new(0, Theme.Radius.Large)
	railCorner.Parent = rail
	local icon = label(kind == "Error" and "!" or kind == "Warning" and "!" or kind == "Reward" and "+" or "i", 15, kind == "Reward" and Theme.Colors.Black or Theme.Colors.White, Theme.Fonts.Strong)
	icon.BackgroundColor3 = accent
	icon.BackgroundTransparency = kind == "Reward" and 0 or 0.12
	icon.Position = UDim2.fromOffset(17, 15)
	icon.Size = UDim2.fromOffset(28, 28)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.TextYAlignment = Enum.TextYAlignment.Center
	icon.ZIndex = baseZ + 4
	icon.Parent = toast
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = icon
	local textPlate = Instance.new("Frame")
	textPlate.Name = "TextPlate"
	textPlate.BackgroundColor3 = Color3.fromHex("05070D")
	textPlate.BackgroundTransparency = 0
	textPlate.BorderSizePixel = 0
	textPlate.Position = UDim2.fromOffset(52, 10)
	textPlate.Size = UDim2.new(1, -62, 0, 66)
	textPlate.ZIndex = baseZ + 2
	textPlate.Parent = toast
	local textPlateCorner = Instance.new("UICorner")
	textPlateCorner.CornerRadius = UDim.new(0, 9)
	textPlateCorner.Parent = textPlate
	local title = label(string.upper(payload.Title), 13, Color3.new(1, 1, 1), Theme.Fonts.Display)
	title.Position = UDim2.fromOffset(60, 14)
	title.Size = UDim2.new(1, -78, 0, 24)
	title.TextTransparency = 0
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.ZIndex = baseZ + 20
	title.Parent = toast
	local message = label(payload.Message, 12, Color3.new(1, 1, 1), Theme.Fonts.Strong)
	message.Position = UDim2.fromOffset(60, 41)
	message.Size = UDim2.new(1, -78, 0, 30)
	message.TextWrapped = true
	message.TextTransparency = 0
	message.TextStrokeColor3 = Color3.new(0, 0, 0)
	message.TextStrokeTransparency = 0.08
	message.ZIndex = baseZ + 20
	message.Parent = toast
	local timer = Instance.new("Frame")
	timer.Name = "LifeBar"
	timer.BackgroundColor3 = accent
	timer.BorderSizePixel = 0
	timer.Position = UDim2.new(0, 56, 1, -10)
	timer.Size = UDim2.new(1, -74, 0, 2)
	timer.ZIndex = baseZ + 4
	timer.Parent = toast
	TweenService:Create(toastScale, TweenInfo.new(Theme.Animation.Page, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), { Scale = 1 }):Play()
	TweenService:Create(timer, TweenInfo.new(4, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
	task.delay(4, function()
		if not toast.Parent then return end
		TweenService:Create(toast, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
		for _, child in toast:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.16), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.16), { Transparency = 1 }):Play()
			end
		end
		TweenService:Create(toastScale, TweenInfo.new(Theme.Animation.Page), { Scale = 0.94 }):Play()
		task.delay(0.16, function() toast:Destroy() end)
	end)
end

function UIController:_bindResponsive()
	local cameraConnection: RBXScriptConnection? = nil
	local function resize()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local compact = viewport.X < Theme.Layout.CompactBreakpoint
		local safeTop = math.max(46, GuiService.TopbarInset.Height)
		local widthFit = viewport.X / Theme.Layout.DesignWidth
		local heightFit = viewport.Y / Theme.Layout.DesignHeight
		-- Fit the complete design viewport on both axes. Individual long pages
		-- remain scrollable instead of forcing the application outside the screen.
		local scaleValue = math.clamp(math.min(widthFit, heightFit), Theme.Layout.MinimumScale, Theme.Layout.MaximumScale)
		if UserInputService.TouchEnabled then
			scaleValue = math.clamp(scaleValue * 1.2, Theme.Layout.MinimumScale, Theme.Layout.MaximumScale * 1.2)
		end
		scaleValue = crispScale(scaleValue)
		local sidebarWidth = compact and Theme.Layout.CompactSidebarWidth or Theme.Layout.SidebarWidth
		self.Scale.Scale = scaleValue
		self.Root.Size = UDim2.fromScale(1 / scaleValue, 1 / scaleValue)
		self.Root:SetAttribute("VTRScale", scaleValue)
		self.Root:SetAttribute("VTRCompact", compact)
		self.Root:SetAttribute("VTRLogicalWidth", viewport.X / scaleValue)
		self.Root:SetAttribute("VTRLogicalHeight", viewport.Y / scaleValue)
		self.Sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
		self.Topbar.Position = UDim2.fromOffset(sidebarWidth, 0)
		self.Topbar.Size = UDim2.new(1, -sidebarWidth, 0, Theme.Layout.TopbarHeight)
		self.Content.Position = UDim2.fromOffset(sidebarWidth, Theme.Layout.TopbarHeight)
		self.Content.Size = UDim2.new(1, -sidebarWidth, 1, -Theme.Layout.TopbarHeight)
		local logoTop = 14 + safeTop / scaleValue
		local navTop = logoTop + 68
		self.Logo.Position = UDim2.fromOffset(24, logoTop)
		self.NavHolder.Position = UDim2.fromOffset(14, navTop)
		self.NavHolder.Size = UDim2.new(1, -28, 1, -(navTop + 250))
		self.Currency.Visible = not compact
	end
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect();cameraConnection=nil end
		local camera=workspace.CurrentCamera
		if camera then cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
		resize()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(resize)
	bindCamera()
end

return UIController
