--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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

local PageModules = {
	Home = require(script.Parent.Parent.Pages.HomePage),
	UltimateTeam = require(script.Parent.Parent.Pages.UltimateTeamPage),
	Inventory = require(script.Parent.Parent.Pages.InventoryPage),
	Play = require(script.Parent.Parent.Pages.CampaignPage),
	Ranked = require(script.Parent.Parent.Pages.RankedPage),
	Clubs = require(script.Parent.Parent.Pages.ClubsPage),
	Career = require(script.Parent.Parent.Pages.CareerPage),
	Store = require(script.Parent.Parent.Pages.StorePage),
	Settings = require(script.Parent.Parent.Pages.SettingsPage),
}

local UIController = {}
UIController.__index = UIController

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
	notificationStack.Size = UDim2.fromOffset(310, 460)
	notificationStack.ZIndex = 50
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
	SettingsRuntimeService.Apply(data.UIState.Settings)
	MenuMusicService.Start()

	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.Scale = scale

	BackgroundEffects.new(root)

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
	local logoTitle = label("VTR 25", 21, Theme.Colors.White, Theme.Fonts.Display)
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
	local breadcrumb = label("VTR 25  /  HOME", 10, Theme.Colors.Muted, Theme.Fonts.Strong)
	breadcrumb.Position = UDim2.fromOffset(30, 0)
	breadcrumb.Size = UDim2.new(0.5, 0, 1, 0)
	breadcrumb.Parent = topbar
	local currency = CurrencyBar.new({
		{ Icon = "◈", Value = data.Currency.Coins },
		{ Icon = "ϟ", Value = data.Currency.Bolts },
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
	local settingsButton = Instance.new("TextButton")
	settingsButton.Name = "SettingsIcon"
	settingsButton.AnchorPoint = Vector2.new(1, 0.5)
	settingsButton.BackgroundColor3 = Theme.Colors.Gunmetal
	settingsButton.BorderSizePixel = 0
	settingsButton.Position = UDim2.new(1, -238, 0.5, 0)
	settingsButton.Size = UDim2.fromOffset(38, 38)
	settingsButton.Text = "SET"
	settingsButton.TextColor3 = Theme.Colors.Electric
	settingsButton.TextSize = 9
	settingsButton.Font = Theme.Fonts.Strong
	settingsButton.Parent = topbar
	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = UDim.new(0, Theme.Radius.Medium)
	settingsCorner.Parent = settingsButton
	settingsButton.Activated:Connect(function()
		if self.Navigation then self.Flow:ModeTransition("Settings", function() self.Navigation:Navigate("Settings"); UIStateService:SetLastPage("Settings") end) end
	end)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.ClipsDescendants = true
	content.Position = UDim2.fromOffset(Theme.Layout.SidebarWidth, Theme.Layout.TopbarHeight)
	content.Size = UDim2.new(1, -Theme.Layout.SidebarWidth, 1, -Theme.Layout.TopbarHeight)
	content.Parent = root
	self.Content = content

	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(data.Profile.Avatar.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and avatar.Parent then avatar.Image = image end
	end)

	local season = self:_createSeasonCard(data.Season)
	season.Position = UDim2.new(0, 14, 1, -154)
	season.Size = UDim2.new(1, -28, 0, 106)
	season.Parent = sidebar
	self.SeasonCard = season

	local navigation = NavigationController.new(breadcrumb)
	self.Navigation = navigation
	local order = {}
	for _, navData in Config.Navigation do
		table.insert(order, navData.Id)
		local item = SidebarItem.new(navData, function(id)
			self.Flow:ModeTransition(id, function() navigation:Navigate(id); UIStateService:SetLastPage(id) end)
		end)
		item.Instance.Parent = navHolder
		navigation:RegisterItem(navData.Id, item)
	end

	local context = {
		Root = root,
		Theme = Theme,
		Config = Config,
		Data = data,
		Navigate = function(id: string) self.Flow:ModeTransition(id, function() navigation:Navigate(id); UIStateService:SetLastPage(id) end) end,
		IsCurrentPage = function(id: string) return navigation.Current == id end,
		HidePage = function(id: string) navigation:HidePage(id) end,
		Toast = function(payload: any) self:_showNotification(payload) end,
		Flow = self.Flow,
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
			elseif (mode == "Store" or mode == "UltimateTeam") and action.Operation == "Select" then UIStateService:SetCosmetic(action.Key, action.Item)
			elseif mode == "Career" and action.Key == "SaveSlot" then UIStateService:SelectCareerSave(tonumber(string.match(action.Item, "%d+")) or 1) end
			return nil
		end,
	}
	self.Flow:SetPlayerDetailsHandler(context.OpenPlayerDetails)
	self.Flow:SetNavigator(context.Navigate)
	self.Flow:SetInventoryNavigator(function()context.Data.UIState.SelectedTabs.Inventory="Packs";UIStateService:SetTab("Inventory","Packs");context.Navigate("Inventory")end)
	self.Context = context
	for id, pageModule in PageModules do
		local page = pageModule.new(context)
		page.Parent = content
		navigation:RegisterPage(id, page)
	end
	navigation:FinalizeSelectionOrder(order)
	navigation:Navigate(data.UIState.LastPage or "Home")
	self:_bindDataUpdates()
	NotificationService.Start(function(payload) self:_showNotification(payload) end)

	self:_bindResponsive()
	if not data.Progression.Onboarding.Complete then
		LoadingScreen.complete(loading, function()
			self.Onboarding = OnboardingController.new(root, self.Flow, data.Progression)
			self.Onboarding:Start(function() navigation:Navigate("Home"); UIStateService:SetLastPage("Home") end)
		end)
	else LoadingScreen.complete(loading) end
end

function UIController:_replacePage(id: string)
	local oldPage = self.Navigation.Pages[id]
	local newPage = PageModules[id].new(self.Context)
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
	if oldPage then
		oldPage.Visible = false
		oldPage.Active = false
		oldPage:Destroy()
	end
	if self.Navigation and self.Navigation.SyncPageVisibility then
		self.Navigation:SyncPageVisibility()
	end
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
			{ Icon = "◈", Value = value.Coins },
			{ Icon = "ϟ", Value = value.Bolts },
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
		for _, id in {"Home","UltimateTeam","Inventory","Play","Ranked"} do self:_replacePage(id) end
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
	local visible={};for _,child in self.NotificationStack:GetChildren()do if child:IsA("CanvasGroup")and child.Name=="Notification"then table.insert(visible,child)end end;table.sort(visible,function(a,b)return a.LayoutOrder<b.LayoutOrder end);while#visible>=3 do local oldest=table.remove(visible,1);oldest:Destroy()end
	local toast = Instance.new("CanvasGroup")
	toast.Name = "Notification"
	toast.BackgroundColor3 = Theme.Colors.Graphite
	toast.BorderSizePixel = 0
	toast.Size = UDim2.fromOffset(310, 82)
	toast.GroupTransparency = 1
	toast.ZIndex = 50
	self.ToastSerial=(self.ToastSerial or 0)+1;toast.LayoutOrder=self.ToastSerial
	toast.Parent = self.NotificationStack
	local toastScale = Instance.new("UIScale")
	toastScale.Scale = 0.94
	toastScale.Parent = toast
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.Large)
	corner.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = payload.Kind == "Error" and Theme.Colors.Danger or Theme.Colors.Electric
	stroke.Thickness = 1
	stroke.Parent = toast
	local title = label(string.upper(payload.Title), 11, Theme.Colors.White, Theme.Fonts.Strong)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 24)
	title.ZIndex = 51
	title.Parent = toast
	local message = label(payload.Message, 9, Theme.Colors.Muted, Theme.Fonts.Body)
	message.Position = UDim2.fromOffset(16, 36)
	message.Size = UDim2.new(1, -32, 0, 34)
	message.TextWrapped = true
	message.ZIndex = 51
	message.Parent = toast
	TweenService:Create(toast, TweenInfo.new(Theme.Animation.Page, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), { GroupTransparency = 0 }):Play()
	TweenService:Create(toastScale, TweenInfo.new(Theme.Animation.Page, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), { Scale = 1 }):Play()
	task.delay(4, function()
		if not toast.Parent then return end
		TweenService:Create(toast, TweenInfo.new(Theme.Animation.Page), { GroupTransparency = 1 }):Play()
		TweenService:Create(toastScale, TweenInfo.new(Theme.Animation.Page), { Scale = 0.94 }):Play()
		task.delay(Theme.Animation.Page, function() toast:Destroy() end)
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
		self.NavHolder.Size = UDim2.new(1, -28, 1, -(navTop + 166))
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
