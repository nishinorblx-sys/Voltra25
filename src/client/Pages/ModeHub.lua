--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local EmptyState = require(script.Parent.Parent.Components.EmptyState)
local PageBase = require(script.Parent.PageBase)
local AvatarPortraitGenerator = require(script.Parent.Parent.Services.PlayerPortraitService)

local ModeHub = {}

function ModeHub.new(context: any, service: any): CanvasGroup
	local spec = service:GetSpec()
	local state = service:GetState()
	service:Hydrate(context.Data.UIState, context.Data.Progression)
	local group, scroll = PageBase.new(spec.Id, 720)
	PageBase.heading(scroll, spec.Kicker, spec.Title, spec.Subtitle)
	local activeTab = spec.Tabs[1]
	local navigationTabs=spec.Tabs
	if spec.Id=="Career"and context.Data.Progression and context.Data.Progression.CareerSaveSlots then local hasSave=false;for _,save in context.Data.Progression.CareerSaveSlots do if save.Type~="Empty"then hasSave=true;break end end;if not hasSave then navigationTabs={spec.Tabs[1]}end end
	if state.SelectedTab then for _, savedTab in spec.Tabs do if savedTab.Id == state.SelectedTab then activeTab = savedTab; break end end end
	local tabButtons = {}
	local body: Frame? = nil

	local breadcrumb = PageBase.text(scroll, "", UDim2.fromOffset(0, 78), UDim2.new(0.7, 0, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "HubTabs"
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.Position = UDim2.fromOffset(0, 102)
	tabs.Size = UDim2.new(1, -244, 0, 46)
	tabs.Active = true
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabs.CanvasSize = UDim2.new()
	tabs.ClipsDescendants = true
	tabs.ScrollingDirection = Enum.ScrollingDirection.X
	tabs.ScrollingEnabled = true
	tabs.ScrollBarImageColor3 = Theme.Colors.Electric
	tabs.ScrollBarImageTransparency = 0.15
	tabs.ScrollBarThickness = 4
	tabs.Parent = scroll
	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 8)
	tabsLayout.Parent = tabs

	local render: () -> ()
	local setTab: (string) -> ()

	local function getMaxTabScroll(): number
		return math.max(0, tabs.AbsoluteCanvasSize.X - tabs.AbsoluteSize.X)
	end

	local function scrollTabs(delta: number)
		local maxX = getMaxTabScroll()
		if maxX <= 0 then return end
		tabs.CanvasPosition = Vector2.new(math.clamp(tabs.CanvasPosition.X + delta, 0, maxX), 0)
	end

	local function revealActiveTab()
		local button = tabButtons[activeTab.Id]
		if not button then return end
		task.defer(function()
			if not button.Parent or not tabs.Parent then return end
			local maxX = getMaxTabScroll()
			if maxX <= 0 then
				tabs.CanvasPosition = Vector2.zero
				return
			end
			local tabLeft = button.AbsolutePosition.X - tabs.AbsolutePosition.X + tabs.CanvasPosition.X
			local tabRight = tabLeft + button.AbsoluteSize.X
			local viewLeft = tabs.CanvasPosition.X
			local viewRight = viewLeft + tabs.AbsoluteSize.X
			if tabLeft < viewLeft then
				tabs.CanvasPosition = Vector2.new(math.clamp(tabLeft - 8, 0, maxX), 0)
			elseif tabRight > viewRight then
				tabs.CanvasPosition = Vector2.new(math.clamp(tabRight - tabs.AbsoluteSize.X + 8, 0, maxX), 0)
			end
		end)
	end

	tabs.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		scrollTabs(-input.Position.Z * 96)
	end)

	local tabLeft = Button.new({ Text = "<", Variant = "Secondary", Size = UDim2.fromOffset(40, 40), OnActivated = function()
		scrollTabs(-180)
	end })
	tabLeft.Position = UDim2.new(1, -236, 0, 102)
	tabLeft.Parent = scroll

	local tabRight = Button.new({ Text = ">", Variant = "Secondary", Size = UDim2.fromOffset(40, 40), OnActivated = function()
		scrollTabs(180)
	end })
	tabRight.Position = UDim2.new(1, -188, 0, 102)
	tabRight.Parent = scroll

	setTab = function(tabId: string)
		for _, tab in spec.Tabs do if tab.Id == tabId then activeTab = tab; break end end
		state.SelectedTab = activeTab.Id
		context.StateService:SetTab(spec.Id, activeTab.Id)
		render()
		revealActiveTab()
	end

	render = function()
		if body then body:Destroy() end
		body = Instance.new("Frame")
		body.Name = activeTab.Id .. "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(0, 160)
		body.Size = UDim2.new(1, 0, 0, 500)
		body.Parent = scroll
		breadcrumb.Text = "VTR X  /  " .. string.upper(spec.Title) .. "  /  " .. activeTab.Label
		for id, button in tabButtons do
			Button.setPrimary(button, id == activeTab.Id)
		end
		revealActiveTab()
		PageBase.text(body, service:GetSummary(), UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
		PageBase.text(body, activeTab.Description, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 28), 11, Theme.Colors.Silver, Theme.Fonts.Strong)
		local gridY = 54
		if spec.Id == "Ranked" and activeTab.Id == "Division" then
			local ranked = (context.Data.Progression and context.Data.Progression.Ranked) or context.Data.Ranked or {}
			local run = (context.Data.Progression and context.Data.Progression.RankedRun) or ranked.RankedRun or ranked.Run or {}
			local results = type(run.Results) == "table" and run.Results or {}
			local games = math.clamp(#results, 0, 7)
			local wins = 0
			local draws = 0
			local losses = 0
			for _, result in results do
				if result == "Win" then wins += 1 elseif result == "Draw" then draws += 1 elseif result == "Loss" then losses += 1 end
			end
			local track = Panel.new({Name="RivalsReloadedProgress",Size=UDim2.new(1,0,0,92)})
			track.Position = UDim2.fromOffset(0, 52)
			track.Parent = body
			PageBase.text(track, tostring(ranked.Division or "DIVISION 10"), UDim2.fromOffset(18, 12), UDim2.new(.32, 0, 0, 28), 18, Theme.Colors.White, Theme.Fonts.Display)
			PageBase.text(track, "7-GAME PATH  "..tostring(games).." / 7  -  "..tostring(wins).."W "..tostring(draws).."D "..tostring(losses).."L", UDim2.fromOffset(18, 44), UDim2.new(.3, 0, 0, 20), 10, Theme.Colors.Electric, Theme.Fonts.Strong)
			local bar = Instance.new("Frame");bar.Position=UDim2.new(.34,0,.5,-5);bar.Size=UDim2.new(.62,-24,0,10);bar.BackgroundColor3=Color3.fromHex("2B3128");bar.BorderSizePixel=0;bar.Parent=track;local bc=Instance.new("UICorner");bc.CornerRadius=UDim.new(1,0);bc.Parent=bar
			local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(games/7,1);fill.BackgroundColor3=Theme.Colors.Electric;fill.BorderSizePixel=0;fill.Parent=bar;local fc=bc:Clone();fc.Parent=fill
			for step=1,7 do
				local result=results[step]
				local color=result=="Win"and Theme.Colors.Electric or result=="Loss"and Theme.Colors.Danger or result=="Draw"and Color3.fromHex("2F6BFF") or Color3.fromHex("111111")
				local dot=Instance.new("Frame");dot.AnchorPoint=Vector2.new(.5,.5);dot.Position=UDim2.fromScale((step-1)/6,.5);dot.Size=UDim2.fromOffset(14,14);dot.BackgroundColor3=color;dot.BorderSizePixel=0;dot.Parent=bar;local dc=Instance.new("UICorner");dc.CornerRadius=UDim.new(1,0);dc.Parent=dot;local ds=Instance.new("UIStroke");ds.Thickness=1;ds.Color=result and color or Theme.Colors.Electric;ds.Transparency=result and .05 or .58;ds.Parent=dot
			end
			gridY = 160
		end
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.fromOffset(0, gridY)
		grid.Size = UDim2.new(1, 0, 0, 418)
		grid.Parent = body
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.333, -11, 0, 198)
		layout.CellPadding = UDim2.fromOffset(16, 16)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		if #activeTab.Cards == 0 then EmptyState.new("NOTHING HERE YET", "Content will appear when data is available.", "◇").Parent = grid end
		for index, cardData in activeTab.Cards do
			local card = Panel.new({ Name = cardData.Id or cardData.Title })
			card.LayoutOrder = index
			card.Parent = grid
			if cardData.Empty then
				local empty = EmptyState.new(cardData.Title, cardData.Subtitle, "◇")
				empty.Position = UDim2.fromOffset(8, 6)
				empty.Size = UDim2.new(1, -16, 0, 122)
				empty.Parent = card
			else
				if cardData.PlayerData then
					local portrait = AvatarPortraitGenerator.new(card, cardData.PlayerData, UDim2.fromOffset(58, 68), false)
					portrait.Position = UDim2.new(1, -76, 0, 12)
				elseif cardData.Icon then
					local icon = Instance.new("ImageLabel")
					icon.Name = "ItemIcon"
					icon.BackgroundColor3 = Theme.Colors.Black
					icon.BackgroundTransparency = 0.08
					icon.BorderSizePixel = 0
					icon.Image = tostring(cardData.Icon)
					icon.Position = UDim2.new(1, -82, 0, 16)
					icon.ScaleType = Enum.ScaleType.Fit
					icon.Size = UDim2.fromOffset(58, 58)
					icon.ZIndex = 3
					icon.Parent = card
					local iconCorner = Instance.new("UICorner")
					iconCorner.CornerRadius = UDim.new(0, 8)
					iconCorner.Parent = icon
					local iconStroke = Instance.new("UIStroke")
					iconStroke.Color = cardData.Accent and Theme.Colors.Electric or Theme.Colors.Muted
					iconStroke.Transparency = cardData.Accent and 0.1 or 0.55
					iconStroke.Thickness = 1
					iconStroke.Parent = icon
				end
				local textInset = (cardData.PlayerData or cardData.Icon) and -104 or -36
				PageBase.text(card, cardData.Accent and "FEATURED" or activeTab.Label, UDim2.fromOffset(18, 14), UDim2.new(1, textInset, 0, 18), 8, cardData.Accent and Theme.Colors.Electric or Theme.Colors.Muted, Theme.Fonts.Strong)
				local titleLabel = PageBase.text(card, cardData.Title, UDim2.fromOffset(18, 39), UDim2.new(1, textInset, 0, 30), 17, Theme.Colors.White, Theme.Fonts.Display)
				local subtitleLabel = PageBase.text(card, cardData.Subtitle, UDim2.fromOffset(18, 72), UDim2.new(1, textInset, 0, 25), 10, Theme.Colors.Silver, Theme.Fonts.Strong)
				local metaLabel = PageBase.text(card, cardData.Meta, UDim2.fromOffset(18, 100), UDim2.new(1, -36, 0, 22), 8, Theme.Colors.Muted, Theme.Fonts.Body)
				if spec.Id == "Store" then
					titleLabel.TextScaled = true
					titleLabel.TextWrapped = true
					local titleLimit = Instance.new("UITextSizeConstraint")
					titleLimit.MinTextSize = 10
					titleLimit.MaxTextSize = 17
					titleLimit.Parent = titleLabel
					subtitleLabel.TextScaled = true
					local subLimit = Instance.new("UITextSizeConstraint")
					subLimit.MinTextSize = 8
					subLimit.MaxTextSize = 10
					subLimit.Parent = subtitleLabel
					metaLabel.Size = UDim2.new(1, -36, 0, 42)
					metaLabel.TextWrapped = true
					metaLabel.TextScaled = true
					metaLabel.TextYAlignment = Enum.TextYAlignment.Top
					local metaLimit = Instance.new("UITextSizeConstraint")
					metaLimit.MinTextSize = 7
					metaLimit.MaxTextSize = 9
					metaLimit.Parent = metaLabel
				end
			end
			local action = table.clone(cardData.Action)
			action.Detail = cardData.Detail
			if action.Operation == "EquipToggle" and state.Equipped[action.Slot] == action.Item then action.Label = "REMOVE CARD" end
			if action.Operation == "Purchase" and action.ItemType ~= "Pack" and state.Owned[action.Item] then action.Label = "OWNED"; action.Confirm = false end
			if action.Operation == "Claim" and state.Claimed[action.Item] then action.Label = "CLAIMED"; action.Confirm = false end
			if action.Operation == "Select" and (state.Selections[action.Key] == action.Item or state.Equipped[action.Key] == action.Item or state.Values[action.Key] == action.Item) then action.Label = (spec.Id == "Store" or spec.Id == "UltimateTeam") and "EQUIPPED" or "SELECTED" end
			local actionButton = Button.new({ Text = action.Label, Variant = cardData.Accent and "Primary" or "Secondary", Size = UDim2.new(1, -36, 0, 40), OnActivated = function()
				context.Flow:Handle(cardData, action, function()
					local persisted = context.Persist(spec.Id, action, state)
					if type(persisted) == "table" then
						if not persisted.Success then return persisted.Message or "Action rejected by server." end
						service:Perform(action)
						if action.AfterTab then task.defer(function() setTab(action.AfterTab) end) end
						return persisted
					end
					local message = service:Perform(action)
					if action.AfterTab then task.defer(function() setTab(action.AfterTab) end) end
					return persisted or message
				end, render, setTab)
			end })
			actionButton.Position = UDim2.new(0, 18, 1, -54)
			actionButton.Parent = card
		end
	end

	for index, tab in navigationTabs do
		local button = Button.new({ Text = tab.Label, Variant = index == 1 and "Primary" or "Secondary", Size = UDim2.fromOffset(128, 40), OnActivated = function()
			if activeTab.Id == tab.Id then return end
			context.Flow:ModeTransition(tab.Label,function() setTab(tab.Id) end,true)
		end })
		button.LayoutOrder = index
		button.Parent = tabs
		tabButtons[tab.Id] = button
	end
	for index, tab in navigationTabs do
		local current = tabButtons[tab.Id]
		current.NextSelectionLeft = tabButtons[(navigationTabs[index - 1] or navigationTabs[#navigationTabs]).Id]
		current.NextSelectionRight = tabButtons[(navigationTabs[index + 1] or navigationTabs[1]).Id]
	end
	local back = Button.new({ Text = "‹ BACK", Variant = "Secondary", Size = UDim2.fromOffset(132, 40), OnActivated = function()
		if activeTab ~= spec.Tabs[1] then context.Flow:ModeTransition(spec.Tabs[1].Label, function() setTab(spec.Tabs[1].Id) end, true) else context.Navigate("Home") end
	end })
	back.Position = UDim2.new(1, -132, 0, 102)
	back.Parent = scroll
	render()
	return group
end

return ModeHub
