--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local PageBase = require(script.Parent.PageBase)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local ProgressBar = require(script.Parent.Parent.Components.ProgressBar)
local BadgePreview = require(script.Parent.Parent.Components.BadgePreview)
local CompactPlayerCard = require(script.Parent.Parent.Components.CompactPlayerCard)
local DefaultCampaignService: any? = nil

local Page = {}

local TABS = { "Season", "Project", "Scouting", "Facilities", "History", "Mastery" }

local function label(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3?, font: Enum.Font?): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = value
	item.TextColor3 = color or Theme.Colors.White
	item.TextSize = textSize
	item.Font = font or Theme.Fonts.Body
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.Parent = parent
	return item
end

local function wrap(item: TextLabel): TextLabel
	item.TextWrapped = true
	item.TextYAlignment = Enum.TextYAlignment.Top
	return item
end

local function corner(parent: Instance, radius: number?)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or Theme.Radius.Medium)
	item.Parent = parent
end

local function divider(parent: Instance, y: number)
	local line = Instance.new("Frame")
	line.BackgroundColor3 = Theme.Colors.Border
	line.BorderSizePixel = 0
	line.Position = UDim2.fromOffset(18, y)
	line.Size = UDim2.new(1, -36, 0, 1)
	line.Parent = parent
end

local function commas(value: any): string
	local source = tostring(math.floor(tonumber(value) or 0))
	local result = source
	while true do
		local changed
		result, changed = string.gsub(result, "^(-?%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then break end
	end
	return result
end

local function resultColor(value: any): Color3
	return value == "Win" and Theme.Colors.Electric or value == "Loss" and Theme.Colors.Danger or Theme.Colors.Warning
end

local function resultLetter(value: any): string
	return value == "Win" and "W" or value == "Loss" and "L" or value == "Draw" and "D" or "-"
end

local function dateText(timestamp: any): string
	local value = tonumber(timestamp) or 0
	return value > 0 and os.date("!%Y-%m-%d", value) or "--"
end

local function masteryRewardText(reward: any): string
	if type(reward) ~= "table" then return "CONTROLLED WEEKLY REWARD" end
	local parts = {}
	if (tonumber(reward.Coins) or 0) > 0 then table.insert(parts, commas(reward.Coins) .. " COINS") end
	if (tonumber(reward.ProjectXP) or 0) > 0 then table.insert(parts, "+" .. tostring(reward.ProjectXP) .. " PROJECT XP") end
	if (tonumber(reward.FacilityPoints) or 0) > 0 then table.insert(parts, "+" .. tostring(reward.FacilityPoints) .. " FACILITY PT") end
	if reward.ItemId then table.insert(parts, string.upper(tostring(reward.ItemId):gsub("_", " "))) end
	if reward.CosmeticId then table.insert(parts, "EXCLUSIVE COSMETIC") end
	return #parts > 0 and table.concat(parts, "  /  ") or "CONTROLLED WEEKLY REWARD"
end

local function panel(parent: Instance, name: string, titleText: string, kicker: string, height: number): Frame
	local item = Panel.new({ Name = name, Size = UDim2.new(1, 0, 0, height) })
	item.Parent = parent
	label(item, kicker, UDim2.fromOffset(18, 12), UDim2.new(1, -36, 0, 15), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	label(item, titleText, UDim2.fromOffset(18, 30), UDim2.new(1, -36, 0, 27), 17, Theme.Colors.White, Theme.Fonts.Display)
	return item
end

local function stateDivision(state: any): any?
	local id = state.ActiveSeason and state.ActiveSeason.DivisionId or state.CurrentDivision and state.CurrentDivision.Id
	for _, division in state.Divisions or {} do
		if division.Id == id then return division end
	end
	return state.Divisions and state.Divisions[1] or nil
end

local function fixtureTitle(fixture: any): string
	if not fixture then return "NO FIXTURE READY" end
	if fixture.IsPromotionFinal then return "PROMOTION FINAL" end
	if fixture.IsRecovery then return "RECOVERY FIXTURE " .. tostring(fixture.Index) end
	if fixture.IsPlacement then return "PLACEMENT FIXTURE" end
	return "LEAGUE FIXTURE " .. tostring(fixture.Index)
end

local function presentationCopy(item: any): (string, string)
	local kind = tostring(item.Type or "ASCENSION UPDATE")
	local data = type(item.Data) == "table" and item.Data or item
	if kind == "Placement" then return "PLACEMENT COMPLETE", tostring(data.Reason or "Your starting division is ready.") end
	if kind == "Promotion" then return "DIVISION PROMOTED", data.FirstPromotion and "A new division, badge, and Facility Point are ready." or "Repeat-promotion progress has been added." end
	if kind == "FacilityUpgrade" then return tostring(item.FacilityName or "FACILITY UPGRADED"), tostring(item.Text or "The new facility effect is active.") end
	if kind == "StarMilestone" then return tostring(data.Stars or "") .. " STAR REWARD", "Your season milestone reward was granted to the club." end
	return string.upper(kind), "Your Ascension state has been updated."
end

function Page.new(context: any): CanvasGroup
	local campaignService = context.CampaignService
	if not campaignService then
		DefaultCampaignService = DefaultCampaignService or require(script.Parent.Parent.Services.CampaignService)
		campaignService = DefaultCampaignService
	end
	local group, scroll = PageBase.new("Campaign", 960)
	group:SetAttribute("VTRPageCleanup", true)
	local cleanupEvent = Instance.new("BindableEvent")
	cleanupEvent.Name = "Cleanup"
	cleanupEvent.Parent = group

	local alive = true
	local state: any? = nil
	local masteryData: any? = nil
	local selectedTab = "Season"
	local busy = false
	local busyText = ""
	local loadError: string? = nil
	local modalState: any? = nil
	local modalPreviousSelection: GuiObject? = nil
	local render: () -> ()
	local connections: { RBXScriptConnection } = {}

	local content = Instance.new("Frame")
	content.Name = "AscensionContent"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Parent = scroll
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 12)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content

	local function toast(message: string, kind: string?)
		context.Toast({ Title = "VOLTRA ASCENSION", Message = message, Kind = kind or "Info" })
	end

	local function isMobile(): boolean
		local width = tonumber(context.ViewportWidth) or scroll.AbsoluteSize.X
		return width > 0 and width < 720
	end

	local function setModal(nextState: any)
		if not modalState then
			local selected = GuiService.SelectedObject
			modalPreviousSelection = if selected and selected:IsDescendantOf(group) then selected else nil
		end
		modalState = nextState
	end

	local function clearModal()
		local previousSelection = modalPreviousSelection
		modalState = nil
		modalPreviousSelection = nil
		local existing = group:FindFirstChild("AscensionModal")
		if existing then existing:Destroy() end
		GuiService.SelectedObject = nil
		task.defer(function()
			if alive and previousSelection and previousSelection.Parent and previousSelection:IsDescendantOf(group) and previousSelection.Selectable then
				GuiService.SelectedObject = previousSelection
			end
		end)
	end

	local function actionButton(parent: Instance, textValue: string, variant: string, size: UDim2, callback: (() -> ())?, disabled: boolean?): TextButton
		local item = Button.new({
			Text = textValue,
			Variant = variant,
			Size = size,
			OnActivated = function()
				if busy or disabled or not callback then return end
				callback()
			end,
		})
		item.Selectable = not disabled
		item.Active = not disabled
		if disabled then item.TextTransparency = 0.45 end
		item.Parent = parent
		return item
	end

	local function refreshState(silent: boolean?)
		if busy or not alive then return end
		busy = true
		busyText = "LOADING ASCENSION"
		loadError = nil
		render()
		task.spawn(function()
			local response = campaignService:GetState()
			if not alive then return end
			busy = false
			if response.Success and type(response.Data) == "table" then
				state = response.Data
				loadError = nil
				if not state.AscensionChampion and selectedTab == "Mastery" then selectedTab = "Season" end
				if not modalState then
					for _, item in state.PendingPresentation or {} do
						if item.Type ~= "ProjectUpgrade" and item.Type ~= "PromotionChoice" then setModal({ Kind = "Presentation", Item = item }) break end
					end
				end
			elseif not silent then
				loadError = response.Message or "Ascension state is unavailable."
			end
			render()
		end)
	end

	local function perform(titleText: string, callback: () -> any, after: ((any) -> ())?)
		if busy or not alive then return end
		busy = true
		busyText = titleText
		loadError = nil
		render()
		task.spawn(function()
			local response = callback()
			if not alive then return end
			if response.Success then
				toast(response.Message or titleText .. " complete.", "Reward")
				local refreshed = campaignService:GetState()
				if refreshed.Success and type(refreshed.Data) == "table" then state = refreshed.Data end
				loadError = nil
			else
				loadError = response.Message or "That Ascension action could not be completed."
				toast(loadError, "Error")
			end
			busy = false
			if response.Success and after then after(response) end
			render()
		end)
	end

	local function openProjectPicker()
		if busy then return end
		busy = true
		busyText = "FINDING ELIGIBLE PROJECTS"
		render()
		task.spawn(function()
			local response = campaignService:GetEligibleProjects()
			if not alive then return end
			busy = false
			if response.Success then
				setModal({ Kind = "ProjectPicker", Players = response.Data or {} })
			else
				loadError = response.Message or "Eligible Club Projects could not be loaded."
				toast(loadError, "Error")
			end
			render()
		end)
	end

	local function openProjectUpgrade()
		local pending = state and state.ActiveProject and state.ActiveProject.PendingUpgradeChoice
		if pending then setModal({ Kind = "ProjectUpgrade", Choice = pending }) render() end
	end

	local function openPromotionChoice()
		local choice = state and state.ActiveSeason and state.ActiveSeason.PendingPromotionChoice
		if choice and choice.Claimed ~= true then setModal({ Kind = "PromotionChoice", Choice = choice }) render() end
	end

	local function loadMastery()
		if busy then return end
		busy = true
		busyText = "LOADING MASTERY"
		render()
		task.spawn(function()
			local response = campaignService:GetMastery()
			if not alive then return end
			busy = false
			if response.Success then masteryData = response.Data else loadError = response.Message toast(loadError, "Error") end
			render()
		end)
	end

	local function primaryAction(): any
		if not state then return { Label = "RETRY", Callback = function() refreshState() end } end
		if state.SquadReady ~= true then return { Label = "EDIT SQUAD", Callback = function() context.Navigate("UltimateTeam") end } end
		if state.HasPendingMatch then return { Label = "RESUME MATCH", Callback = function() perform("RESUMING MATCH", function() return campaignService:ResumeMatch() end, nil) end } end
		if state.Placement.Completed ~= true then return { Label = "PLAY PLACEMENT", Callback = function() perform("STARTING PLACEMENT", function() return campaignService:StartPlacement() end, nil) end } end
		local season = state.ActiveSeason
		if not season then return { Label = "START FIRST SEASON", Callback = function() perform("STARTING SEASON", function() return campaignService:StartSeason() end, nil) end } end
		if season.PendingProjectUpgrade then return { Label = "CHOOSE PROJECT UPGRADE", Callback = openProjectUpgrade } end
		if season.PendingPromotionChoice and season.PendingPromotionChoice.Claimed ~= true then return { Label = "CHOOSE YOUR SIGNING", Callback = openPromotionChoice } end
		if season.Status == "Promoted" then return { Label = "START NEXT DIVISION", Callback = function() perform("STARTING NEXT DIVISION", function() return campaignService:StartSeason() end, nil) end } end
		if season.Status == "Failed" then return { Label = "START NEW SEASON", Callback = function() perform("STARTING NEW SEASON", function() return campaignService:StartSeason() end, nil) end } end
		if not season.ScoutingFocus then return { Label = "CHOOSE SCOUTING FOCUS", Callback = function() selectedTab = "Scouting" render() end } end
		if not season.ProjectDecision then return { Label = "SELECT CLUB PROJECT", Callback = openProjectPicker } end
		local fixture = state.CurrentFixture
		if not fixture then return { Label = "REFRESH FIXTURE", Callback = function() refreshState() end } end
		local textValue = fixture.IsPromotionFinal and "PLAY PROMOTION FINAL" or fixture.IsRecovery and "PLAY RECOVERY MATCH" or "PLAY MATCH"
		return { Label = textValue, Callback = function() perform("STARTING MATCH", function() return campaignService:StartFixture("Manual") end, nil) end }
	end

	local function secondaryAction(): any?
		if not state or state.SquadReady ~= true or state.HasPendingMatch or state.Placement.Completed ~= true then return nil end
		local season = state.ActiveSeason
		if not season or not season.ScoutingFocus or not season.ProjectDecision or season.PendingProjectUpgrade or season.Status == "Promoted" or season.Status == "Failed" then return nil end
		if season.PendingPromotionChoice and season.PendingPromotionChoice.Claimed ~= true then return nil end
		if not state.CurrentFixture then return nil end
		return { Label = "MANAGE MATCH", Callback = function() perform("STARTING MANAGER MODE", function() return campaignService:StartFixture("Manage") end, nil) end }
	end

	local function renderHeading(parent: Instance)
		local block = Instance.new("Frame")
		block.Name = "Heading"
		block.BackgroundTransparency = 1
		block.Size = UDim2.new(1, 0, 0, isMobile() and 146 or 116)
		block.Parent = parent
		label(block, "BUILD YOUR CLUB", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 16), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
		label(block, "VOLTRA ASCENSION", UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 38), isMobile() and 24 or 30, Theme.Colors.White, Theme.Fonts.Display)
		local subtitle = label(block, "Earn promotion, develop a Club Project, and scout the signing your squad needs.", UDim2.fromOffset(0, 61), UDim2.new(1, 0, 0, isMobile() and 34 or 18), 9, Theme.Colors.Silver, Theme.Fonts.Body)
		subtitle.TextWrapped = true
		subtitle.TextYAlignment = Enum.TextYAlignment.Top
		local promise = label(block, "EARN PROMOTION. DEVELOP A FAVORITE PLAYER. BUILD A CLUB WORTH TAKING INTO RANKED.", UDim2.fromOffset(0, isMobile() and 101 or 84), UDim2.new(1, 0, 0, isMobile() and 38 or 20), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
		promise.TextWrapped = true
		promise.TextYAlignment = Enum.TextYAlignment.Top
	end

	local function renderTabs(parent: Instance)
		local holder = Instance.new("ScrollingFrame")
		holder.Name = "Tabs"
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Size = UDim2.new(1, 0, 0, 44)
		holder.AutomaticCanvasSize = Enum.AutomaticSize.X
		holder.CanvasSize = UDim2.new()
		holder.ScrollingDirection = Enum.ScrollingDirection.X
		holder.ScrollBarThickness = 0
		holder.Parent = parent
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 7)
		layout.Parent = holder
		for _, tab in TABS do
			if tab == "Mastery" and state and state.AscensionChampion ~= true then continue end
			local tabButton = actionButton(holder, string.upper(tab), tab == selectedTab and "Primary" or "Secondary", UDim2.fromOffset(tab == "Facilities" and 116 or 100, 40), function()
				selectedTab = tab
				if tab == "Mastery" and not masteryData then loadMastery() else render() end
			end)
			tabButton.LayoutOrder = table.find(TABS, tab) or 1
		end
	end

	local function renderError(parent: Instance)
		if not loadError then return end
		local item = Instance.new("Frame")
		item.Name = "RecoverableError"
		item.BackgroundColor3 = Theme.Colors.Danger
		item.BackgroundTransparency = 0.86
		item.BorderSizePixel = 0
		item.Size = UDim2.new(1, 0, 0, 54)
		item.Parent = parent
		corner(item)
		local errorText = label(item, loadError, UDim2.fromOffset(16, 0), UDim2.new(1, -142, 1, 0), 9, Theme.Colors.White, Theme.Fonts.Strong)
		errorText.TextWrapped = true
		local retry = actionButton(item, "RETRY", "Secondary", UDim2.fromOffset(104, 34), function() refreshState() end)
		retry.Position = UDim2.new(1, -116, 0.5, -17)
	end

	local function renderHero(parent: Instance)
		local mobile = isMobile()
		local hero = Panel.new({ Name = "SeasonHero", Size = UDim2.new(1, 0, 0, mobile and 318 or 232) })
		hero.Parent = parent
		local division = stateDivision(state)
		local accent = division and division.Accent or Theme.Colors.Electric
		local rail = Instance.new("Frame")
		rail.BackgroundColor3 = accent
		rail.BorderSizePixel = 0
		rail.Size = UDim2.new(0, 5, 1, 0)
		rail.Parent = hero
		local squad = state.Squad
		if squad and type(squad.BadgeIdentity) == "table" then
			local badge = BadgePreview.new(hero, squad.BadgeIdentity, UDim2.fromOffset(mobile and 66 or 82, mobile and 66 or 82))
			badge.Position = UDim2.fromOffset(20, 26)
			badge.ZIndex = hero.ZIndex + 3
		else
			local badge = label(hero, squad and tostring(squad.Badge or "VTR") or "VTR", UDim2.fromOffset(20, 26), UDim2.fromOffset(mobile and 66 or 82, mobile and 66 or 82), 17, Theme.Colors.Black, Theme.Fonts.Display)
			badge.BackgroundColor3 = accent
			badge.BackgroundTransparency = 0
			badge.TextXAlignment = Enum.TextXAlignment.Center
			corner(badge, Theme.Radius.Large)
		end
		local textX = mobile and 100 or 122
		label(hero, division and division.Name or "PLACEMENT", UDim2.fromOffset(textX, 24), UDim2.new(1, -textX - 20, 0, 18), 9, accent, Theme.Fonts.Strong)
		local clubName = squad and squad.ClubName or "ULTIMATE TEAM REQUIRED"
		local club = label(hero, string.upper(clubName), UDim2.fromOffset(textX, 45), UDim2.new(1, -textX - 24, 0, 34), mobile and 19 or 25, Theme.Colors.White, Theme.Fonts.Display)
		club.TextTruncate = Enum.TextTruncate.AtEnd
		local season = state.ActiveSeason
		local status = if state.SquadReady ~= true then "SQUAD NOT READY" elseif state.Placement.Completed ~= true then "PLACEMENT REQUIRED" elseif season then string.upper(tostring(season.Status)) else "READY FOR FIRST SEASON"
		label(hero, status, UDim2.fromOffset(textX, 80), UDim2.new(1, -textX - 24, 0, 18), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
		local metricsY = mobile and 122 or 116
		local metrics = {
			{ "TEAM OVR", squad and squad.Overall or 0 },
			{ "CHEMISTRY", squad and squad.Chemistry or 0 },
			{ "POINTS", season and season.Points or 0 },
			{ "STARS", season and season.Stars or 0 },
		}
		for index, metric in metrics do
			local width = mobile and 0.5 or 0.145
			local column = mobile and ((index - 1) % 2) or (index - 1)
			local row = mobile and math.floor((index - 1) / 2) or 0
			local xScale = mobile and column * 0.5 or column * 0.155
			local box = Instance.new("Frame")
			box.BackgroundColor3 = Theme.Colors.Gunmetal
			box.BackgroundTransparency = 0.16
			box.BorderSizePixel = 0
			box.Position = UDim2.new(xScale, 20 + column * 4, 0, metricsY + row * 58)
			box.Size = UDim2.new(width, mobile and -26 or -8, 0, 50)
			box.Parent = hero
			corner(box, Theme.Radius.Small)
			label(box, metric[1], UDim2.fromOffset(10, 5), UDim2.new(1, -20, 0, 14), 7, Theme.Colors.Muted, Theme.Fonts.Strong)
			label(box, tostring(metric[2]), UDim2.fromOffset(10, 20), UDim2.new(1, -20, 0, 24), 18, Theme.Colors.White, Theme.Fonts.Display)
		end
		local primary = primaryAction()
		local secondary = secondaryAction()
		if not mobile then
			local primaryButton = actionButton(hero, busy and busyText or primary.Label, "Primary", UDim2.fromOffset(196, 44), primary.Callback, primary.Disabled or busy)
			primaryButton.Position = UDim2.new(1, -216, 0, 122)
			if secondary then
				local secondaryButton = actionButton(hero, secondary.Label, "Secondary", UDim2.fromOffset(196, 40), secondary.Callback, busy)
				secondaryButton.Position = UDim2.new(1, -216, 0, 174)
			end
		else
			label(hero, state.SquadMessage or Config.UI.Subtitle, UDim2.fromOffset(20, 246), UDim2.new(1, -40, 0, 54), 9, state.SquadReady and Theme.Colors.Muted or Theme.Colors.Danger, Theme.Fonts.Body).TextWrapped = true
		end
	end

	local function renderFixtureCard(parent: Instance, fixture: any, height: number)
		local item = panel(parent, "NextFixture", fixture and string.upper(tostring(fixture.OpponentTeamName)) or "FIXTURE UNAVAILABLE", fixtureTitle(fixture), height)
		if not fixture then
			wrap(label(item, "Refresh Ascension state to recover the next persisted fixture.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 42), 9, Theme.Colors.Muted, Theme.Fonts.Body))
			return
		end
		label(item, "OVR " .. tostring(fixture.OpponentOverall or "--") .. "  /  " .. string.upper(tostring(fixture.OpponentCountry or "--")), UDim2.fromOffset(18, 66), UDim2.new(1, -36, 0, 18), 9, Theme.Colors.Silver, Theme.Fonts.Strong)
		label(item, string.upper(tostring(fixture.TacticLabel or "BALANCED RIVAL")), UDim2.fromOffset(18, 88), UDim2.new(1, -36, 0, 18), 9, Theme.Colors.Electric, Theme.Fonts.Strong)
		wrap(label(item, fixture.ObjectiveTitle .. "  /  " .. fixture.ObjectiveDescription, UDim2.fromOffset(18, 116), UDim2.new(1, -36, 0, 52), 9, Theme.Colors.White, Theme.Fonts.Body))
		if fixture.Formation then label(item, "FORMATION  " .. fixture.Formation, UDim2.fromOffset(18, height - 51), UDim2.new(0.45, 0, 0, 18), 8, Theme.Colors.Silver, Theme.Fonts.Strong) end
		if fixture.StarPlayerName then
			local star = label(item, "STAR  " .. string.upper(tostring(fixture.StarPlayerName)), UDim2.new(0.45, 0, 0, height - 51), UDim2.new(0.55, -18, 0, 18), 8, Theme.Colors.Warning, Theme.Fonts.Strong)
			star.TextXAlignment = Enum.TextXAlignment.Right
		end
	end

	local function renderProjectCompact(parent: Instance, height: number)
		local project = state.ActiveProject
		local item = panel(parent, "ProjectCompact", project and project.PlayerName or "NO CLUB PROJECT", "CLUB PROJECT", height)
		if project and state.ActiveProjectCard then
			local card = CompactPlayerCard.new({ Parent = item, Card = state.ActiveProjectCard, Horizontal = true, Size = UDim2.fromOffset(172, 76) })
			card.Position = UDim2.fromOffset(18, 67)
			local nextMilestone = nil
			for _, milestone in Config.Project.Milestones do if (tonumber(project.XP) or 0) < milestone then nextMilestone = milestone break end end
			label(item, tostring(project.XP or 0) .. " PROJECT XP", UDim2.fromOffset(204, 72), UDim2.new(1, -222, 0, 21), 13, Theme.Colors.Electric, Theme.Fonts.Display)
			label(item, nextMilestone and "NEXT NODE  " .. nextMilestone .. " XP" or "PATH COMPLETE", UDim2.fromOffset(204, 98), UDim2.new(1, -222, 0, 18), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
			local progress = ProgressBar.new(nextMilestone and math.clamp((tonumber(project.XP) or 0) / nextMilestone, 0, 1) or 1)
			progress.Position = UDim2.fromOffset(204, 125)
			progress.Size = UDim2.new(1, -222, 0, 6)
			progress.Parent = item
			label(item, project.VisualTier and string.upper(project.VisualTier) or "DEVELOPING", UDim2.fromOffset(204, 141), UDim2.new(1, -222, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
		else
			wrap(label(item, Config.UI.ProjectSkip, UDim2.fromOffset(18, 70), UDim2.new(1, -36, 0, 56), 9, Theme.Colors.Muted, Theme.Fonts.Body))
			local choose = actionButton(item, "SELECT PROJECT", "Secondary", UDim2.fromOffset(156, 38), openProjectPicker, busy)
			choose.Position = UDim2.fromOffset(18, height - 56)
		end
	end

	local function renderStarTrack(parent: Instance)
		local season = state.ActiveSeason
		local item = panel(parent, "StarTrack", "24-STAR SEASON TRACK", "AUTOMATIC REWARDS", isMobile() and 258 or 158)
		local stars = season and tonumber(season.Stars) or 0
		local division = stateDivision(state)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset(18, 68)
		holder.Size = UDim2.new(1, -36, 0, isMobile() and 170 or 70)
		holder.Parent = item
		local milestones = {}
		for _, target in Config.StarMilestoneOrder do
			local definition = Config.StarMilestones[target]
			local rewardText = if target == 4 then commas(division and division.StarCoins or 0) .. " COINS" elseif target == 8 then "TRAINING ITEM" elseif target == 12 then string.upper(tostring(division and division.PackId or "PACK")):gsub("_", " ") elseif target == 16 then "2 PROJECT XP" elseif target == 20 then "SCOUTING +1" else "PERFECT SEASON"
			table.insert(milestones, { Target = target, Reward = rewardText, Definition = definition })
		end
		for index, milestone in milestones do
			local mobile = isMobile()
			local col = mobile and ((index - 1) % 2) or (index - 1)
			local row = mobile and math.floor((index - 1) / 2) or 0
			local width = mobile and 0.5 or 1 / 6
			local node = Instance.new("Frame")
			node.BackgroundColor3 = stars >= milestone.Target and Theme.Colors.Electric or Theme.Colors.Gunmetal
			node.BackgroundTransparency = stars >= milestone.Target and 0.08 or 0.18
			node.BorderSizePixel = 0
			node.Position = UDim2.new(col * width, col * 3, 0, row * 58)
			node.Size = UDim2.new(width, -6, 0, 50)
			node.Parent = holder
			corner(node, Theme.Radius.Small)
			label(node, tostring(milestone.Target) .. " STARS", UDim2.fromOffset(8, 5), UDim2.new(1, -16, 0, 14), 7, stars >= milestone.Target and Theme.Colors.Black or Theme.Colors.Silver, Theme.Fonts.Strong)
			local reward = label(node, milestone.Reward, UDim2.fromOffset(8, 20), UDim2.new(1, -16, 0, 23), 7, stars >= milestone.Target and Theme.Colors.Black or Theme.Colors.White, Theme.Fonts.Strong)
			reward.TextWrapped = true
		end
	end

	local function renderLeagueTable(parent: Instance, height: number)
		local season = state.ActiveSeason
		local item = panel(parent, "LeagueTable", "SEASON POSITION", "LEAGUE TABLE", height)
		if not season then
			wrap(label(item, "Start a season to establish your promotion record.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 46), 9, Theme.Colors.Muted, Theme.Fonts.Body))
			return
		end
		label(item, "CLUB", UDim2.fromOffset(18, 68), UDim2.new(0.48, 0, 0, 18), 7, Theme.Colors.Muted, Theme.Fonts.Strong)
		local header = label(item, "P     W     D     L     GD", UDim2.new(0.5, 0, 0, 68), UDim2.new(0.5, -18, 0, 18), 7, Theme.Colors.Muted, Theme.Fonts.Strong)
		header.TextXAlignment = Enum.TextXAlignment.Right
		divider(item, 91)
		label(item, string.upper(state.Squad and state.Squad.ClubName or "YOUR CLUB"), UDim2.fromOffset(18, 103), UDim2.new(0.48, 0, 0, 24), 11, Theme.Colors.White, Theme.Fonts.Display).TextTruncate = Enum.TextTruncate.AtEnd
		local gd = (tonumber(season.GoalsFor) or 0) - (tonumber(season.GoalsAgainst) or 0)
		local row = label(item, tostring(season.Points) .. "     " .. tostring(season.Wins) .. "     " .. tostring(season.Draws) .. "     " .. tostring(season.Losses) .. "     " .. (gd >= 0 and "+" or "") .. tostring(gd), UDim2.new(0.5, 0, 0, 103), UDim2.new(0.5, -18, 0, 24), 10, Theme.Colors.Electric, Theme.Fonts.Strong)
		row.TextXAlignment = Enum.TextXAlignment.Right
		local threshold = Config.PromotionThreshold
		label(item, tostring(math.max(0, threshold - (tonumber(season.Points) or 0))) .. " POINTS TO PROMOTION QUALIFICATION", UDim2.fromOffset(18, 145), UDim2.new(1, -36, 0, 18), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
		local bar = ProgressBar.new(math.clamp((tonumber(season.Points) or 0) / threshold, 0, 1))
		bar.Position = UDim2.fromOffset(18, 173)
		bar.Size = UDim2.new(1, -36, 0, 7)
		bar.Parent = item
	end

	local function renderFixtureList(parent: Instance, height: number)
		local item = panel(parent, "FixtureList", "UPCOMING FIXTURES", "SEASON SCHEDULE", height)
		local season = state.ActiveSeason
		local fixtures = {}
		for _, fixture in season and season.LeagueFixtures or {} do table.insert(fixtures, fixture) end
		for _, fixture in season and season.RecoveryFixtures or {} do table.insert(fixtures, fixture) end
		if season and season.PromotionFinal then table.insert(fixtures, season.PromotionFinal) end
		if #fixtures == 0 then
			wrap(label(item, "Your persisted schedule appears when the season starts.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 42), 9, Theme.Colors.Muted, Theme.Fonts.Body))
			return
		end
		local y = 65
		for _, fixture in fixtures do
			if y > height - 35 then break end
			local mark = resultLetter(fixture.Result)
			local marker = label(item, mark, UDim2.fromOffset(18, y), UDim2.fromOffset(25, 25), 9, fixture.Played and resultColor(fixture.Result) or Theme.Colors.Muted, Theme.Fonts.Display)
			marker.BackgroundColor3 = Theme.Colors.Gunmetal
			marker.BackgroundTransparency = 0.08
			marker.TextXAlignment = Enum.TextXAlignment.Center
			corner(marker, Theme.Radius.Small)
			local opponent = label(item, string.upper(tostring(fixture.OpponentTeamName)), UDim2.fromOffset(54, y), UDim2.new(1, -145, 0, 25), 9, fixture.Played and Theme.Colors.Silver or Theme.Colors.White, Theme.Fonts.Strong)
			opponent.TextTruncate = Enum.TextTruncate.AtEnd
			local meta = fixture.IsPromotionFinal and "FINAL" or fixture.IsRecovery and "RECOVERY" or "MD " .. tostring(fixture.Index)
			local right = label(item, meta, UDim2.new(1, -91, 0, y), UDim2.fromOffset(73, 25), 7, fixture.IsPromotionFinal and Theme.Colors.Warning or Theme.Colors.Muted, Theme.Fonts.Strong)
			right.TextXAlignment = Enum.TextXAlignment.Right
			y += 30
		end
	end

	local function renderScoutingReport(parent: Instance, height: number)
		local fixture = state.CurrentFixture
		local scouting = fixture and fixture.OpponentScouting or nil
		local item = panel(parent, "ScoutingReport", fixture and tostring(scouting and scouting.Name or fixture.TacticLabel or "OPPONENT REPORT") or "NO REPORT READY", "SCOUTING REPORT", height)
		if not fixture then return end
		local y = 70
		local entries = {
			{ "FORMATION", fixture.Formation or "UPGRADE TACTICAL LAB TO REVEAL" },
			{ "TACTIC", scouting and (scouting.Name .. " / " .. scouting.Risk .. " RISK / " .. scouting.StaminaDemand .. " ENERGY") or "UPGRADE TACTICAL LAB TO REVEAL" },
			{ "WEAKNESS", scouting and table.concat(scouting.Weaknesses or {}, "; ") or fixture.Weakness or "UPGRADE TACTICAL LAB TO REVEAL" },
			{ "COUNTER PLAN", fixture.CounterTactic or "TACTICAL LAB LEVEL 3" },
		}
		for _, entry in entries do
			label(item, entry[1], UDim2.fromOffset(18, y), UDim2.fromOffset(94, 18), 7, Theme.Colors.Muted, Theme.Fonts.Strong)
			local value = label(item, tostring(entry[2]), UDim2.fromOffset(116, y), UDim2.new(1, -134, 0, 34), 8, Theme.Colors.White, Theme.Fonts.Body)
			value.TextWrapped = true
			value.TextYAlignment = Enum.TextYAlignment.Top
			y += 38
		end
		if fixture.CounterTactic and not fixture.CounterPlanApplied then
			local apply = actionButton(item, "APPLY COUNTER PLAN", "Secondary", UDim2.fromOffset(184, 36), function() perform("APPLYING COUNTER PLAN", function() return campaignService:ApplyCounterPlan() end, nil) end, busy)
			apply.Position = UDim2.fromOffset(18, height - 49)
		elseif fixture.CounterPlanApplied then
			label(item, "COUNTER PLAN ACTIVE FOR THIS FIXTURE", UDim2.fromOffset(18, height - 43), UDim2.new(1, -36, 0, 24), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
		end
	end

	local function splitRow(parent: Instance, leftHeight: number, rightHeight: number, leftRender: (Instance, number) -> (), rightRender: (Instance, number) -> ())
		local mobile = isMobile()
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, mobile and leftHeight + rightHeight + 12 or math.max(leftHeight, rightHeight))
		row.Parent = parent
		local left = Instance.new("Frame")
		left.BackgroundTransparency = 1
		left.Size = mobile and UDim2.new(1, 0, 0, leftHeight) or UDim2.new(0.64, -6, 0, leftHeight)
		left.Parent = row
		local right = Instance.new("Frame")
		right.BackgroundTransparency = 1
		right.Position = mobile and UDim2.fromOffset(0, leftHeight + 12) or UDim2.new(0.64, 6, 0, 0)
		right.Size = mobile and UDim2.new(1, 0, 0, rightHeight) or UDim2.new(0.36, -6, 0, rightHeight)
		right.Parent = row
		leftRender(left, leftHeight)
		rightRender(right, rightHeight)
	end

	local function renderSeason(parent: Instance)
		renderHero(parent)
		local fixtureHeight = isMobile() and 222 or 210
		splitRow(parent, fixtureHeight, fixtureHeight, function(holder, height) renderFixtureCard(holder, state.CurrentFixture, height) end, function(holder, height) renderProjectCompact(holder, height) end)
		renderStarTrack(parent)
		splitRow(parent, 220, 280, function(holder, height) renderLeagueTable(holder, height) end, function(holder, height) renderFixtureList(holder, height) end)
		renderScoutingReport(parent, 258)
	end

	local function renderProject(parent: Instance)
		local project = state.ActiveProject
		local item = panel(parent, "ProjectDetail", project and project.PlayerName or "SELECT A CLUB PROJECT", "PERMANENT PLAYER DEVELOPMENT", project and 250 or 220)
		if project and state.ActiveProjectCard then
			local card = CompactPlayerCard.new({ Parent = item, Card = state.ActiveProjectCard, Horizontal = true, Size = UDim2.fromOffset(190, 82) })
			card.Position = UDim2.fromOffset(18, 68)
			label(item, "BASE ID  " .. tostring(project.BasePlayerId), UDim2.fromOffset(224, 72), UDim2.new(1, -242, 0, 18), 7, Theme.Colors.Muted, Theme.Fonts.Strong)
			label(item, tostring(project.XP) .. " XP  /  +" .. tostring(project.OVRBoost or 0) .. " OVR", UDim2.fromOffset(224, 96), UDim2.new(1, -242, 0, 26), 16, Theme.Colors.Electric, Theme.Fonts.Display)
			label(item, tostring(#(project.AppliedNodeIds or {})) .. " NODES APPLIED  /  " .. tostring(project.SeasonsCompleted or 0) .. " SEASONS", UDim2.fromOffset(224, 128), UDim2.new(1, -242, 0, 18), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
			if project.PendingUpgradeChoice then
				local choose = actionButton(item, "CHOOSE UPGRADE", "Primary", UDim2.fromOffset(164, 38), openProjectUpgrade, busy)
				choose.Position = UDim2.fromOffset(224, 166)
			end
			local retire = actionButton(item, "RETIRE PROJECT", "Secondary", UDim2.fromOffset(154, 36), function() perform("RETIRING PROJECT", function() return campaignService:RetireProject() end, nil) end, busy)
			retire.Position = UDim2.fromOffset(18, 188)
		else
			wrap(label(item, "Choose an owned base card at 82 OVR or lower. Match participation and objectives earn permanent, capped upgrades.", UDim2.fromOffset(18, 70), UDim2.new(1, -36, 0, 50), 9, Theme.Colors.Muted, Theme.Fonts.Body))
			label(item, tostring(state.CampaignTrainingTokens or 0) .. " BANKED PROJECT XP  /  APPLIES ON SELECTION", UDim2.fromOffset(18, 124), UDim2.new(1, -36, 0, 20), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
			local choose = actionButton(item, "VIEW ELIGIBLE PLAYERS", "Primary", UDim2.fromOffset(210, 40), openProjectPicker, busy)
			choose.Position = UDim2.fromOffset(18, 158)
		end
		local path = panel(parent, "ProjectPath", "PROJECT MILESTONE PATH", "3 / 7 / 12 / 18 / 26 XP", isMobile() and 340 or 186)
		for index, milestone in Config.Project.Milestones do
			local completed = project and table.find(project.AppliedNodeIds or {}, "milestone:" .. milestone) ~= nil
			local mobile = isMobile()
			local col = mobile and ((index - 1) % 2) or (index - 1)
			local row = mobile and math.floor((index - 1) / 2) or 0
			local width = mobile and 0.5 or 0.2
			local node = Instance.new("Frame")
			node.BackgroundColor3 = completed and Theme.Colors.Electric or Theme.Colors.Gunmetal
			node.BackgroundTransparency = completed and 0.08 or 0.12
			node.BorderSizePixel = 0
			node.Position = UDim2.new(col * width, 18 + col * 4, 0, 72 + row * 76)
			node.Size = UDim2.new(width, -26, 0, 64)
			node.Parent = path
			corner(node)
			label(node, tostring(milestone) .. " XP", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 20), 11, completed and Theme.Colors.Black or Theme.Colors.White, Theme.Fonts.Display)
			local reward = milestone == 3 and "ATTRIBUTES" or milestone == 7 and "PLAYSTYLE" or milestone == 12 and "DEVELOPMENT" or milestone == 18 and "ASCENDED I" or "ASCENDED II"
			label(node, reward, UDim2.fromOffset(10, 32), UDim2.new(1, -20, 0, 18), 7, completed and Theme.Colors.Black or Theme.Colors.Silver, Theme.Fonts.Strong)
		end
		local history = panel(parent, "ProjectHistory", "PROJECT GRADUATES", "CLUB HISTORY", math.max(120, 74 + math.min(5, #(state.ProjectHistory or {})) * 42))
		if #(state.ProjectHistory or {}) == 0 then
			label(history, "No retired Club Projects yet.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 25), 9, Theme.Colors.Muted, Theme.Fonts.Body)
		else
			local y = 68
			for index, entry in state.ProjectHistory do
				if index > 5 then break end
				label(history, string.upper(tostring(entry.PlayerName or entry.BasePlayerId)), UDim2.fromOffset(18, y), UDim2.new(0.6, 0, 0, 24), 9, Theme.Colors.White, Theme.Fonts.Strong)
				local value = label(history, tostring(entry.XP or 0) .. " XP  /  " .. tostring(#(entry.AppliedNodeIds or {})) .. " NODES", UDim2.new(0.6, 0, 0, y), UDim2.new(0.4, -18, 0, 24), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
				value.TextXAlignment = Enum.TextXAlignment.Right
				y += 40
			end
		end
	end

	local function renderScouting(parent: Instance)
		local season = state.ActiveSeason
		local focus = season and season.ScoutingFocus
		local locked = season and season.ScoutingLocked == true
		local item = panel(parent, "ScoutingFocus", focus and string.upper(focus) or "CHOOSE A SCOUTING FOCUS", locked and "LOCKED FOR THIS SEASON" or "PRESEASON DECISION", isMobile() and 410 or 245)
		wrap(label(item, "Promotion shortlists target the position group your Ultimate Team needs. The focus locks at the first league fixture.", UDim2.fromOffset(18, 66), UDim2.new(1, -36, 0, 42), 9, Theme.Colors.Muted, Theme.Fonts.Body))
		local columns = isMobile() and 2 or 3
		for index, focusName in state.ScoutingFocuses or {} do
			local col = (index - 1) % columns
			local row = math.floor((index - 1) / columns)
			local choice = actionButton(item, string.upper(focusName), focusName == focus and "Primary" or "Secondary", UDim2.new(1 / columns, -24, 0, 40), function() perform("SELECTING FOCUS", function() return campaignService:ChooseScoutingFocus(focusName) end, nil) end, locked or not season or season.Status ~= "Preseason")
			choice.Position = UDim2.new(col / columns, 18 + col * 6, 0, 120 + row * 50)
		end
		local division = stateDivision(state)
		local preview = panel(parent, "ScoutingPreview", "PROMOTION SIGNING", "TARGETED REWARD", 185)
		label(preview, string.upper(focus or "ANY POSITION"), UDim2.fromOffset(18, 70), UDim2.new(0.48, 0, 0, 25), 14, Theme.Colors.White, Theme.Fonts.Display)
		local scoutingLevel = 0
		for _, facility in state.Facilities or {} do if facility.Id == "scouting" then scoutingLevel = facility.Level break end end
		local rangeText = scoutingLevel >= 1 and tostring(division and division.ScoutingMin or "--") .. "-" .. tostring(division and division.ScoutingMax or "--") .. " OVR" or "OVR RANGE HIDDEN"
		label(preview, rangeText, UDim2.fromOffset(18, 102), UDim2.new(0.48, 0, 0, 22), 10, Theme.Colors.Electric, Theme.Fonts.Strong)
		local baseChoices = tonumber(division and division.ScoutingChoices) or 3
		label(preview, tostring(math.min(5, baseChoices + (scoutingLevel >= 2 and 1 or 0))) .. " SHORTLIST OPTIONS", UDim2.fromOffset(18, 130), UDim2.new(0.48, 0, 0, 18), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
		local tokens = division and state.RepeatPromotionTokens[division.Id] or 0
		local tokenText = label(preview, tostring(tokens or 0) .. " / 3 REPEAT TOKENS", UDim2.new(0.52, 0, 0, 86), UDim2.new(0.48, -18, 0, 24), 11, Theme.Colors.Warning, Theme.Fonts.Strong)
		tokenText.TextXAlignment = Enum.TextXAlignment.Right
		local choice = season and season.PendingPromotionChoice
		if choice and choice.Claimed ~= true then
			local open = actionButton(preview, "VIEW SHORTLIST", "Primary", UDim2.fromOffset(166, 38), openPromotionChoice, busy)
			open.Position = UDim2.new(1, -184, 0, 125)
		end
	end

	local function renderFacilities(parent: Instance)
		local summary = panel(parent, "FacilitySummary", commas(state.FacilityPoints) .. " FACILITY POINTS", "CLUB INFRASTRUCTURE", 126)
		wrap(label(summary, "First promotions, first perfect seasons, Masters, and selected Mastery rewards fund permanent club upgrades.", UDim2.fromOffset(18, 70), UDim2.new(1, -36, 0, 38), 9, Theme.Colors.Muted, Theme.Fonts.Body))
		for _, facility in state.Facilities or {} do
			local item = panel(parent, "Facility_" .. facility.Id, facility.Name, "LEVEL " .. tostring(facility.Level) .. " / 3", 170)
			label(item, facility.CurrentText, UDim2.fromOffset(18, 69), UDim2.new(1, -36, 0, 28), 9, facility.Level > 0 and Theme.Colors.Electric or Theme.Colors.Muted, Theme.Fonts.Strong).TextWrapped = true
			if facility.NextText then
				wrap(label(item, "NEXT  " .. facility.NextText, UDim2.fromOffset(18, 101), UDim2.new(1, -230, 0, 48), 8, Theme.Colors.Silver, Theme.Fonts.Body))
				local upgrade = actionButton(item, "UPGRADE  " .. tostring(facility.NextCost) .. " PT", "Primary", UDim2.fromOffset(180, 40), function() perform("UPGRADING FACILITY", function() return campaignService:UpgradeFacility(facility.Id) end, nil) end, busy or (tonumber(state.FacilityPoints) or 0) < (tonumber(facility.NextCost) or 99))
				upgrade.Position = UDim2.new(1, -198, 0, 108)
			else
				label(item, "MAXIMUM LEVEL", UDim2.new(1, -198, 0, 112), UDim2.fromOffset(180, 34), 9, Theme.Colors.Electric, Theme.Fonts.Strong).TextXAlignment = Enum.TextXAlignment.Right
			end
			local levels = Instance.new("Frame")
			levels.BackgroundTransparency = 1
			levels.Position = UDim2.new(1, -145, 0, 18)
			levels.Size = UDim2.fromOffset(127, 28)
			levels.Parent = item
			for index = 1, 3 do
				local pip = Instance.new("Frame")
				pip.BackgroundColor3 = index <= facility.Level and Theme.Colors.Electric or Theme.Colors.Gunmetal
				pip.BorderSizePixel = 0
				pip.Position = UDim2.fromOffset((index - 1) * 43, 7)
				pip.Size = UDim2.fromOffset(35, 8)
				pip.Parent = levels
				corner(pip, 2)
			end
		end
	end

	local function renderHistory(parent: Instance)
		local records = panel(parent, "DivisionRecords", "DIVISION RECORDS", "CAREER TOTALS", math.max(160, 72 + #(state.Divisions or {}) * 40))
		local y = 67
		for _, division in state.Divisions or {} do
			local record = state.DivisionRecords[division.Id] or {}
			label(records, division.Name, UDim2.fromOffset(18, y), UDim2.new(0.46, 0, 0, 26), 9, division.Accent or Theme.Colors.White, Theme.Fonts.Strong)
			local summary = tostring(record.Promotions or 0) .. " PROMOTIONS  /  " .. tostring(record.PerfectSeasons or 0) .. " PERFECT  /  BEST " .. tostring(record.BestPoints or 0) .. " PTS"
			local right = label(records, summary, UDim2.new(0.46, 0, 0, y), UDim2.new(0.54, -18, 0, 26), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
			right.TextXAlignment = Enum.TextXAlignment.Right
			y += 40
		end
		local history = state.History or {}
		local item = panel(parent, "SeasonHistory", "LAST 20 SEASONS", "ASCENSION ARCHIVE", math.max(142, 74 + math.min(20, #history) * 56))
		if #history == 0 then
			label(item, "Completed seasons and preserved legacy progress will appear here.", UDim2.fromOffset(18, 74), UDim2.new(1, -36, 0, 26), 9, Theme.Colors.Muted, Theme.Fonts.Body)
		else
			local rowY = 66
			for index, entry in history do
				if index > 20 then break end
				local titleText = entry.Type == "LegacyMigration" and "ASCENSION LEGACY" or string.upper(tostring(entry.DivisionName or entry.DivisionId or "SEASON"))
				label(item, titleText, UDim2.fromOffset(18, rowY), UDim2.new(0.4, 0, 0, 24), 9, Theme.Colors.White, Theme.Fonts.Strong)
				label(item, dateText(entry.CompletedAt), UDim2.fromOffset(18, rowY + 22), UDim2.new(0.25, 0, 0, 16), 7, Theme.Colors.Muted, Theme.Fonts.Strong)
				local summary = entry.Type == "LegacyMigration" and "LEGACY TIER " .. tostring(entry.LegacyTier or 0) .. "  /  +" .. tostring(entry.FacilityPoints or 0) .. " FACILITY PT" or tostring(entry.Wins or 0) .. "W " .. tostring(entry.Draws or 0) .. "D " .. tostring(entry.Losses or 0) .. "L  /  " .. tostring(entry.Points or 0) .. " PTS  /  " .. tostring(entry.Stars or 0) .. " STARS"
				local right = label(item, summary, UDim2.new(0.4, 0, 0, rowY), UDim2.new(0.6, -18, 0, 38), 8, entry.Promoted and Theme.Colors.Electric or Theme.Colors.Silver, Theme.Fonts.Strong)
				right.TextXAlignment = Enum.TextXAlignment.Right
				right.TextWrapped = true
				rowY += 56
			end
		end
		local graduates = state.ProjectHistory or {}
		local projectHistory = panel(parent, "HistoryProjects", "CLUB PROJECT GRADUATES", "PERMANENT DEVELOPMENT", math.max(120, 72 + math.min(10, #graduates) * 44))
		if #graduates == 0 then
			wrap(label(projectHistory, "Retired Club Projects and their permanent progression will appear here.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 30), 9, Theme.Colors.Muted, Theme.Fonts.Body))
		else
			local rowY = 66
			for index, entry in graduates do
				if index > 10 then break end
				label(projectHistory, string.upper(tostring(entry.PlayerName or entry.BasePlayerId or "PROJECT PLAYER")), UDim2.fromOffset(18, rowY), UDim2.new(0.52, 0, 0, 24), 9, Theme.Colors.White, Theme.Fonts.Strong)
				local summary = "+" .. tostring(entry.OVRBoost or 0) .. " OVR  /  " .. tostring(#(entry.AppliedNodeIds or {})) .. " NODES  /  " .. tostring(entry.SeasonsCompleted or 0) .. " SEASONS"
				local right = label(projectHistory, summary, UDim2.new(0.52, 0, 0, rowY), UDim2.new(0.48, -18, 0, 24), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
				right.TextXAlignment = Enum.TextXAlignment.Right
				right.TextTruncate = Enum.TextTruncate.AtEnd
				rowY += 44
			end
		end
		local signings = {}
		for _, entry in history do if type(entry.ScoutingReward) == "table" then table.insert(signings, { Division = entry.DivisionName or entry.DivisionId, Player = entry.ScoutingReward }) end end
		local signingHistory = panel(parent, "HistorySignings", "SELECTED PROMOTION SIGNINGS", "TARGETED SCOUTING", math.max(120, 72 + math.min(10, #signings) * 44))
		if #signings == 0 then
			wrap(label(signingHistory, "Promotion signings claimed from scouting shortlists will appear here.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 30), 9, Theme.Colors.Muted, Theme.Fonts.Body))
		else
			local rowY = 66
			for index, signing in signings do
				if index > 10 then break end
				local playerData = signing.Player
				label(signingHistory, string.upper(tostring(playerData.displayName or playerData.Name or playerData.playerId)), UDim2.fromOffset(18, rowY), UDim2.new(0.52, 0, 0, 24), 9, Theme.Colors.White, Theme.Fonts.Strong)
				local summary = tostring(playerData.overall or playerData.Rating or 0) .. " OVR  /  " .. tostring(playerData.bestPosition or playerData.Position or "--") .. "  /  " .. string.upper(tostring(signing.Division or "ASCENSION"))
				local right = label(signingHistory, summary, UDim2.new(0.52, 0, 0, rowY), UDim2.new(0.48, -18, 0, 24), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
				right.TextXAlignment = Enum.TextXAlignment.Right
				right.TextTruncate = Enum.TextTruncate.AtEnd
				rowY += 44
			end
		end
		local trophyRows = {}
		for _, division in state.Divisions or {} do
			local record = state.DivisionRecords[division.Id] or {}
			if (tonumber(record.Titles) or 0) > 0 or (tonumber(record.PerfectSeasons) or 0) > 0 or record.LegacyCleared == true then table.insert(trophyRows, { Division = division, Record = record }) end
		end
		local trophies = panel(parent, "HistoryTrophies", "TROPHIES & BADGES", state.AscensionChampion and "ASCENSION CHAMPION" or "CLUB HONORS", math.max(120, 72 + math.max(1, #trophyRows) * 42))
		if #trophyRows == 0 then
			wrap(label(trophies, "Promotions, perfect seasons, and preserved legacy clears unlock club honors.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 30), 9, Theme.Colors.Muted, Theme.Fonts.Body))
		else
			local rowY = 66
			for _, item in trophyRows do
				label(trophies, item.Division.Name, UDim2.fromOffset(18, rowY), UDim2.new(0.5, 0, 0, 24), 9, item.Division.Accent or Theme.Colors.White, Theme.Fonts.Strong)
				local summary = tostring(item.Record.Titles or 0) .. " TITLES  /  " .. tostring(item.Record.PerfectSeasons or 0) .. " PERFECT"
				if item.Record.LegacyCleared == true then summary ..= "  /  LEGACY" end
				local right = label(trophies, summary, UDim2.new(0.5, 0, 0, rowY), UDim2.new(0.5, -18, 0, 24), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
				right.TextXAlignment = Enum.TextXAlignment.Right
				right.TextTruncate = Enum.TextTruncate.AtEnd
				rowY += 42
			end
		end
	end

	local function renderMastery(parent: Instance)
		if state.AscensionChampion ~= true then
			local locked = panel(parent, "MasteryLocked", "WIN VOLTRA MASTERS", "MASTERY LOCKED", 150)
			wrap(label(locked, "Your first Masters promotion unlocks deterministic weekly three-match contracts.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 44), 9, Theme.Colors.Muted, Theme.Fonts.Body))
			return
		end
		if not masteryData then
			local loading = panel(parent, "MasteryLoad", "MASTERY CONTRACTS", "WEEKLY CHALLENGE", 150)
			local load = actionButton(loading, "LOAD CONTRACTS", "Primary", UDim2.fromOffset(178, 40), loadMastery, busy)
			load.Position = UDim2.fromOffset(18, 82)
			return
		end
		local resetText = math.max(0, (tonumber(masteryData.ResetsAt) or os.time()) - os.time())
		local header = panel(parent, "MasteryHeader", masteryData.Active and "ACTIVE CONTRACT" or "CHOOSE THIS WEEK'S CONTRACT", "RESETS IN " .. tostring(math.floor(resetText / 86400)) .. "D " .. tostring(math.floor(resetText % 86400 / 3600)) .. "H", 145)
		if masteryData.Active then
			local definition = Config.MasteryContracts[masteryData.Active.ContractId]
			label(header, definition and definition.Name or masteryData.Active.ContractId, UDim2.fromOffset(18, 72), UDim2.new(0.55, 0, 0, 24), 13, Theme.Colors.White, Theme.Fonts.Display)
			local masteryStatus = masteryData.Active.Completed and (masteryData.Active.Succeeded and "CONTRACT COMPLETE" or "CONTRACT ENDED") or tostring(math.max(0, (masteryData.Active.CurrentIndex or 1) - 1)) .. " / 3 FIXTURES"
			label(header, masteryStatus, UDim2.fromOffset(18, 101), UDim2.new(0.55, 0, 0, 18), 8, masteryData.Active.Succeeded and Theme.Colors.Electric or Theme.Colors.Silver, Theme.Fonts.Strong)
			if not masteryData.Active.Completed then
				local play = actionButton(header, "PLAY MASTERY", "Primary", UDim2.fromOffset(170, 40), function() perform("STARTING MASTERY", function() return campaignService:StartMasteryFixture("Manual") end, nil) end, busy)
				play.Position = UDim2.new(1, -188, 0, 82)
			end
		end
		for _, definition in masteryData.Definitions or state.MasteryDefinitions or {} do
			local mobile = isMobile()
			local item = panel(parent, "Mastery_" .. definition.Id, definition.Name, "THREE-MATCH CONTRACT", mobile and 220 or 174)
			wrap(label(item, definition.Description, UDim2.fromOffset(18, 70), UDim2.new(1, mobile and -36 or -230, 0, 52), 9, Theme.Colors.Silver, Theme.Fonts.Body))
			local reward = label(item, masteryRewardText(definition.Reward), UDim2.fromOffset(18, mobile and 126 or 132), UDim2.new(1, mobile and -36 or -230, 0, 22), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
			reward.TextWrapped = true
			if not masteryData.Active then
				local start = actionButton(item, "START CONTRACT", "Primary", mobile and UDim2.new(1, -36, 0, 40) or UDim2.fromOffset(176, 40), function() perform("STARTING MASTERY CONTRACT", function() return campaignService:StartMastery(definition.Id) end, function() masteryData = nil end) end, busy)
				start.Position = mobile and UDim2.fromOffset(18, 166) or UDim2.new(1, -194, 0, 96)
			end
		end
	end

	local function renderStickyAction()
		local existing = group:FindFirstChild("AscensionStickyAction")
		if existing then existing:Destroy() end
		if not isMobile() or not state then
			scroll.Size = UDim2.new(1, -Theme.Layout.ContentPadding * 2, 1, 0)
			return
		end
		scroll.Size = UDim2.new(1, -Theme.Layout.ContentPadding * 2, 1, -68)
		local tray = Instance.new("Frame")
		tray.Name = "AscensionStickyAction"
		tray.BackgroundColor3 = Theme.Colors.Black
		tray.BackgroundTransparency = 0.04
		tray.BorderSizePixel = 0
		tray.Position = UDim2.new(0, 0, 1, -68)
		tray.Size = UDim2.new(1, 0, 0, 68)
		tray.ZIndex = 90
		tray.Parent = group
		local line = Instance.new("UIStroke")
		line.Color = Theme.Colors.Border
		line.Thickness = 1
		line.Parent = tray
		local primary = primaryAction()
		local secondary = secondaryAction()
		local primaryWidth = secondary and 0.58 or 1
		local play = actionButton(tray, busy and busyText or primary.Label, "Primary", UDim2.new(primaryWidth, -18, 0, 46), primary.Callback, primary.Disabled or busy)
		play.Position = UDim2.fromOffset(12, 11)
		play.ZIndex = 91
		if secondary then
			local manage = actionButton(tray, secondary.Label, "Secondary", UDim2.new(0.42, -18, 0, 46), secondary.Callback, busy)
			manage.Position = UDim2.new(0.58, 6, 0, 11)
			manage.ZIndex = 91
		end
	end

	local function renderModal()
		local existing = group:FindFirstChild("AscensionModal")
		if existing then existing:Destroy() end
		if not modalState then return end
		local mobile = isMobile()
		local overlay = Instance.new("Frame")
		overlay.Name = "AscensionModal"
		overlay.BackgroundColor3 = Theme.Colors.Black
		overlay.BackgroundTransparency = 0.12
		overlay.BorderSizePixel = 0
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.Active = true
		overlay.ZIndex = 200
		overlay.Parent = group
		local shell = Panel.new({ Name = "ModalShell", Size = mobile and UDim2.new(1, -24, 1, -48) or UDim2.fromOffset(720, 520) })
		shell.AnchorPoint = Vector2.new(0.5, 0.5)
		shell.Position = UDim2.fromScale(0.5, 0.5)
		shell.ZIndex = 201
		shell.Parent = overlay
		for _, descendant in shell:GetDescendants() do if descendant:IsA("GuiObject") then descendant.ZIndex = 202 end end
		local kind = modalState.Kind
		local titleText = kind == "ProjectPicker" and "SELECT CLUB PROJECT" or kind == "ProjectUpgrade" and "CHOOSE PROJECT UPGRADE" or kind == "PromotionChoice" and "CHOOSE YOUR SIGNING" or "ASCENSION UPDATE"
		local kickerText = kind == "ProjectPicker" and "PRESEASON" or kind == "ProjectUpgrade" and "PERMANENT DEVELOPMENT" or kind == "PromotionChoice" and "PROMOTION REWARD" or "CLUB PROGRESS"
		if kind == "Presentation" then
			titleText = presentationCopy(modalState.Item)
			kickerText = "CLUB PROGRESS"
		end
		label(shell, kickerText, UDim2.fromOffset(22, 16), UDim2.new(1, -80, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong).ZIndex = 203
		label(shell, titleText, UDim2.fromOffset(22, 38), UDim2.new(1, -80, 0, 34), mobile and 19 or 23, Theme.Colors.White, Theme.Fonts.Display).ZIndex = 203
		local close = actionButton(shell, "X", "Secondary", UDim2.fromOffset(42, 38), function() clearModal() render() end)
		close.Position = UDim2.new(1, -56, 0, 16)
		close.ZIndex = 204
		local body = Instance.new("ScrollingFrame")
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.Position = UDim2.fromOffset(22, 84)
		body.Size = UDim2.new(1, -44, 1, -106)
		body.AutomaticCanvasSize = Enum.AutomaticSize.Y
		body.CanvasSize = UDim2.new()
		body.ScrollBarThickness = 3
		body.ScrollBarImageColor3 = Theme.Colors.Electric
		body.ZIndex = 203
		body.Parent = shell
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 9)
		layout.Parent = body
		local firstAction: TextButton? = nil
		local function modalAction(button: TextButton): TextButton
			if not firstAction and button.Selectable then firstAction = button end
			return button
		end
		if kind == "ProjectPicker" then
			local players = modalState.Players or {}
			if #players == 0 then
				local empty = label(body, "NO ELIGIBLE PROJECT CARDS\nOwned base cards must be 82 OVR or lower and cannot be temporary or top-end specials.", UDim2.new(), UDim2.new(1, -8, 0, 80), 10, Theme.Colors.Muted, Theme.Fonts.Body)
				empty.TextWrapped = true
			else
				for _, cardData in players do
					local row = Instance.new("Frame")
					row.BackgroundColor3 = Theme.Colors.Gunmetal
					row.BackgroundTransparency = 0.16
					row.BorderSizePixel = 0
					row.Size = UDim2.new(1, -8, 0, 82)
					row.ZIndex = 203
					row.Parent = body
					corner(row)
					local card = CompactPlayerCard.new({ Parent = row, Card = { Id = cardData.CardInstanceId, playerId = cardData.PlayerId, Name = cardData.Name, displayName = cardData.Name, Rating = cardData.Overall, overall = cardData.Overall, Position = cardData.Position, bestPosition = cardData.Position, Rarity = cardData.Rarity, CardType = cardData.CardType, portraitSeed = cardData.portraitSeed, appearance = cardData.appearance }, Horizontal = true, Size = UDim2.fromOffset(178, 68) })
					card.Position = UDim2.fromOffset(7, 7)
					card.ZIndex = 204
					local selectButton = modalAction(actionButton(row, "SELECT", "Primary", UDim2.fromOffset(132, 38), function() clearModal() perform("SELECTING PROJECT", function() return campaignService:SelectProject(cardData.CardInstanceId) end, nil) end, busy))
					selectButton.Position = UDim2.new(1, -146, 0.5, -19)
					selectButton.ZIndex = 204
				end
			end
			local skip = modalAction(actionButton(body, "PLAY WITHOUT PROJECT", "Secondary", UDim2.new(1, -8, 0, 44), function() clearModal() perform("SKIPPING CLUB PROJECT", function() return campaignService:SkipProject() end, nil) end, busy))
			skip.ZIndex = 204
		elseif kind == "ProjectUpgrade" then
			local choice = modalState.Choice
			for _, option in choice.Options or {} do
				local row = Instance.new("Frame")
				row.BackgroundColor3 = Theme.Colors.Gunmetal
				row.BackgroundTransparency = 0.12
				row.BorderSizePixel = 0
				row.Size = UDim2.new(1, -8, 0, 76)
				row.ZIndex = 203
				row.Parent = body
				corner(row)
				label(row, option.Name, UDim2.fromOffset(16, 10), UDim2.new(1, -176, 0, 24), 11, Theme.Colors.White, Theme.Fonts.Display).ZIndex = 204
				label(row, string.upper(tostring(option.Kind)), UDim2.fromOffset(16, 38), UDim2.new(1, -176, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong).ZIndex = 204
				local choose = modalAction(actionButton(row, "APPLY", "Primary", UDim2.fromOffset(130, 38), function() clearModal() perform("APPLYING PROJECT UPGRADE", function() return campaignService:ChooseProjectUpgrade(option.Id) end, nil) end, busy))
				choose.Position = UDim2.new(1, -144, 0.5, -19)
				choose.ZIndex = 204
			end
		elseif kind == "PromotionChoice" then
			local choice = modalState.Choice
			label(body, string.upper(tostring(choice.Focus or "ANY POSITION")) .. "  /  " .. tostring(choice.MinimumOverall) .. "-" .. tostring(choice.MaximumOverall) .. " OVR", UDim2.new(), UDim2.new(1, -8, 0, 26), 10, Theme.Colors.Electric, Theme.Fonts.Strong).ZIndex = 204
			for _, cardData in choice.Options or {} do
				local row = Instance.new("Frame")
				row.BackgroundColor3 = Theme.Colors.Gunmetal
				row.BackgroundTransparency = 0.12
				row.BorderSizePixel = 0
				row.Size = UDim2.new(1, -8, 0, 86)
				row.ZIndex = 203
				row.Parent = body
				corner(row)
				local card = CompactPlayerCard.new({ Parent = row, Card = cardData, Horizontal = true, Size = UDim2.fromOffset(186, 72) })
				card.Position = UDim2.fromOffset(7, 7)
				card.ZIndex = 204
				label(row, string.upper(tostring(cardData.country or "")), UDim2.fromOffset(210, 13), UDim2.new(1, -370, 0, 20), 8, Theme.Colors.Silver, Theme.Fonts.Strong).ZIndex = 204
				local choose = modalAction(actionButton(row, "SIGN PLAYER", "Primary", UDim2.fromOffset(144, 40), function() clearModal() perform("SIGNING PLAYER", function() return campaignService:ChoosePromotionPlayer(cardData.playerId) end, nil) end, busy))
				choose.Position = UDim2.new(1, -158, 0.5, -20)
				choose.ZIndex = 204
			end
			if choice.RerollAvailable then
				local reroll = modalAction(actionButton(body, "REROLL SHORTLIST", "Secondary", UDim2.new(1, -8, 0, 44), function() clearModal() perform("REROLLING SHORTLIST", function() return campaignService:RerollPromotionChoice() end, function() openPromotionChoice() end) end, busy))
				reroll.ZIndex = 204
			end
		else
			local titleCopy, description = presentationCopy(modalState.Item)
			local message = label(body, description, UDim2.new(), UDim2.new(1, -8, 0, 110), 11, Theme.Colors.Silver, Theme.Fonts.Body)
			message.TextWrapped = true
			message.TextYAlignment = Enum.TextYAlignment.Top
			message.ZIndex = 204
			local acknowledge = modalAction(actionButton(body, "CONTINUE", "Primary", UDim2.new(1, -8, 0, 46), function()
				local item = modalState.Item
				clearModal()
				perform("ACKNOWLEDGING " .. titleCopy, function() return campaignService:AcknowledgePresentation(item.Id) end, nil)
			end, busy))
			acknowledge.ZIndex = 204
		end
		local focusTarget = firstAction or close
		task.defer(function()
			if alive and modalState and focusTarget.Parent and focusTarget:IsDescendantOf(overlay) and focusTarget.Selectable then
				GuiService.SelectedObject = focusTarget
			end
		end)
	end

	render = function()
		if not alive then return end
		for _, child in content:GetChildren() do if child ~= contentLayout then child:Destroy() end end
		renderHeading(content)
		if state then renderTabs(content) end
		renderError(content)
		if not state then
			local status = panel(content, "LoadState", busy and busyText or "ASCENSION UNAVAILABLE", "SERVER STATE", 180)
			wrap(label(status, loadError or "Loading your saved season, squad readiness, Project, scouting, facilities, and history.", UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 52), 9, Theme.Colors.Muted, Theme.Fonts.Body))
			if not busy then
				local retry = actionButton(status, "RETRY", "Primary", UDim2.fromOffset(140, 40), function() refreshState() end)
				retry.Position = UDim2.fromOffset(18, 128)
			end
		else
			if selectedTab == "Season" then renderSeason(content)
			elseif selectedTab == "Project" then renderProject(content)
			elseif selectedTab == "Scouting" then renderScouting(content)
			elseif selectedTab == "Facilities" then renderFacilities(content)
			elseif selectedTab == "History" then renderHistory(content)
			else renderMastery(content) end
		end
		renderStickyAction()
		renderModal()
	end

	local lastWidth = 0
	table.insert(connections, scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local width = math.floor(scroll.AbsoluteSize.X)
		if width <= 0 or math.abs(width - lastWidth) < 12 then return end
		local crossed = (lastWidth < 720) ~= (width < 720) or (lastWidth < 1000) ~= (width < 1000)
		lastWidth = width
		if crossed then task.defer(render) end
	end))
	cleanupEvent.Event:Connect(function()
		clearModal()
	end)
	table.insert(connections, group.Destroying:Connect(function()
		alive = false
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
	end))

	task.defer(function()
		lastWidth = math.floor(scroll.AbsoluteSize.X)
		render()
		refreshState(true)
	end)
	return group
end

return Page
