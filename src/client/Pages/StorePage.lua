--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Button = require(script.Parent.Parent.Components.Button)
local PageBase = require(script.Parent.PageBase)
local StoreData = require(script.Parent.Parent.Services.StoreData)

local Page = {}

local C = Theme.Colors

local PackColors = {
	Common = Color3.fromHex("7CFF1D"),
	Bronze = Color3.fromHex("FF8A18"),
	Silver = Color3.fromHex("E8ECEF"),
	Gold = Color3.fromHex("FFE600"),
	Rare = Color3.fromHex("9B31FF"),
	Elite = Color3.fromHex("26A8FF"),
	Legendary = Color3.fromHex("FF3FD5"),
	Icon = Color3.fromHex("FFF1B0"),
	Mythic = Color3.fromHex("7CFF1D"),
}

local TabIcons = {
	Packs = "BOX",
	Boosts = "BOLT",
	Celebrations = "SUN",
	Club = "SHD",
	Coins = "COIN",
	VoltraPoints = "VP",
	Kits = "KIT",
	Boots = "BT",
	GoalEffects = "FX",
	Passes = "PASS",
}

local StoreTabOrder = {
	"Packs",
	"Boosts",
	"Celebrations",
	"Club",
	"Coins",
	"VoltraPoints",
	"GoalEffects",
	"Kits",
	"Boots",
	"Passes",
}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number?, thickness: number?)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Transparency = transparency or 0.35
	item.Thickness = thickness or 1
	item.Parent = parent
	return item
end

local function gradient(parent: Instance, colors: {Color3}, rotation: number?)
	local item = Instance.new("UIGradient")
	local points = {}
	for index, color in ipairs(colors) do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color))
	end
	item.Color = ColorSequence.new(points)
	item.Rotation = rotation or 0
	item.Parent = parent
	return item
end

local function text(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font or Theme.Fonts.Body
	label.Text = value
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function panel(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3?, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color or Color3.fromHex("090B08")
	frame.BackgroundTransparency = transparency or 0.08
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.Parent = parent
	corner(frame, 8)
	stroke(frame, C.Border, 0.26, 1)
	return frame
end

local function currencyFrom(context: any): any
	local progressionCurrency = context.Data and context.Data.Progression and context.Data.Progression.Currency
	return progressionCurrency or context.Data and context.Data.Currency or {}
end

local function formatNumber(value: any): string
	local textValue = tostring(math.floor(tonumber(value) or 0))
	repeat
		local nextValue, substitutions = textValue:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		textValue = nextValue
	until substitutions == 0
	return textValue
end

local function findTab(spec: any, id: string): any?
	for _, tab in ipairs(spec.Tabs) do
		if tab.Id == id then
			return tab
		end
	end
	return nil
end

local function orderedTabs(spec: any): {any}
	local result = {}
	for _, id in ipairs(StoreTabOrder) do
		local tab = findTab(spec, id)
		if tab then
			table.insert(result, tab)
		end
	end
	for _, tab in ipairs(spec.Tabs) do
		local exists = false
		for _, current in ipairs(result) do
			if current.Id == tab.Id then
				exists = true
				break
			end
		end
		if not exists then
			table.insert(result, tab)
		end
	end
	return result
end

local function packAccent(cardData: any): Color3
	local source = string.upper(tostring(cardData.Title or cardData.Subtitle or cardData.Meta or ""))
	for name, color in pairs(PackColors) do
		if string.find(source, string.upper(name), 1, true) then
			return color
		end
	end
	return cardData.Accent and C.Electric or C.Silver
end

local function drawPack(parent: Instance, accent: Color3)
	local art = Instance.new("Frame")
	art.Name = "PackArt"
	art.BackgroundColor3 = Color3.fromHex("050605")
	art.BackgroundTransparency = 0.04
	art.BorderSizePixel = 0
	art.Position = UDim2.fromOffset(28, 46)
	art.Size = UDim2.new(1, -56, 0, 190)
	art.Parent = parent
	corner(art, 8)
	stroke(art, accent, 0.35, 1)
	gradient(art, {Color3.fromHex("050605"), accent:Lerp(Color3.new(0, 0, 0), 0.52), Color3.fromHex("050605")}, 18)

	local glow = Instance.new("Frame")
	glow.Name = "PackGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = accent
	glow.BackgroundTransparency = 0.78
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromScale(0.5, 0.62)
	glow.Rotation = -10
	glow.Size = UDim2.fromScale(1.02, 0.28)
	glow.Parent = art

	local pack = Instance.new("Frame")
	pack.Name = "PackShape"
	pack.AnchorPoint = Vector2.new(0.5, 0.5)
	pack.BackgroundColor3 = Color3.fromHex("11130F")
	pack.BorderSizePixel = 0
	pack.Position = UDim2.fromScale(0.5, 0.54)
	pack.Rotation = -7
	pack.Size = UDim2.fromOffset(112, 144)
	pack.Parent = art
	corner(pack, 6)
	stroke(pack, accent, 0.06, 2)
	gradient(pack, {accent:Lerp(Color3.new(0, 0, 0), 0.76), Color3.fromHex("050505"), accent:Lerp(Color3.new(1, 1, 1), 0.18)}, 70)

	local badge = text(pack, "VTR", UDim2.fromScale(0, 0.36), UDim2.fromScale(1, 0.26), 28, C.Electric, Theme.Fonts.Display)
	badge.TextXAlignment = Enum.TextXAlignment.Center

	for index = 1, 8 do
		local shard = Instance.new("Frame")
		shard.Name = "EnergyShard"
		shard.AnchorPoint = Vector2.new(0.5, 0.5)
		shard.BackgroundColor3 = accent
		shard.BackgroundTransparency = 0.38 + index * 0.04
		shard.BorderSizePixel = 0
		shard.Position = UDim2.fromScale(0.16 + (index % 4) * 0.22, 0.12 + math.floor(index / 4) * 0.68)
		shard.Rotation = -30 + index * 13
		shard.Size = UDim2.fromOffset(3, 34 + (index % 3) * 12)
		shard.Parent = art
	end
end

local function infoCard(parent: Instance, xScale: number, widthScale: number, title: string, body: string, icon: string)
	local card = panel(parent, title:gsub("%W", "") .. "Info", UDim2.new(xScale, 0, 0, 0), UDim2.new(widthScale, -12, 1, 0), Color3.fromHex("0B1008"), 0.06)
	text(card, icon, UDim2.fromOffset(18, 18), UDim2.fromOffset(62, 52), 34, C.Electric, Theme.Fonts.Display).TextXAlignment = Enum.TextXAlignment.Center
	text(card, title, UDim2.fromOffset(88, 18), UDim2.new(1, -108, 0, 22), 15, C.White, Theme.Fonts.Display)
	local bodyLabel = text(card, body, UDim2.fromOffset(88, 44), UDim2.new(1, -108, 0, 42), 12, C.Silver, Theme.Fonts.Body)
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	return card
end

function Page.new(context: any): Frame
	local service = StoreData
	local spec = service:GetSpec()
	local state = service:GetState()
	service:Hydrate(context.Data.UIState, context.Data.Progression)

	local group, scroll = PageBase.new("Store", 980)
	scroll.BackgroundColor3 = C.Black
	scroll.BackgroundTransparency = 0

	local tabs = orderedTabs(spec)
	local activeTab = findTab(spec, state.SelectedTab or "Packs") or findTab(spec, "Packs") or tabs[1]
	local tabButtons: {[string]: TextButton} = {}
	local body: Frame? = nil

	local hero = panel(scroll, "StoreHero", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 222), Color3.fromHex("050704"), 0.02)
	hero.ClipsDescendants = true
	gradient(hero, {Color3.fromHex("030403"), Color3.fromHex("0B1707"), Color3.fromHex("030403")}, 8)
	for index = 1, 18 do
		local shard = Instance.new("Frame")
		shard.Name = "HeroEnergy"
		shard.BackgroundColor3 = index % 3 == 0 and C.Electric or C.Neon
		shard.BackgroundTransparency = 0.62 + (index % 4) * 0.06
		shard.BorderSizePixel = 0
		shard.Position = UDim2.fromScale(0.14 + (index * 0.047) % 0.82, 0.06 + (index * 0.13) % 0.78)
		shard.Rotation = -35
		shard.Size = UDim2.fromOffset(4, 92 + (index % 5) * 18)
		shard.Parent = hero
	end
	local ghost = text(hero, "VTR", UDim2.new(0.42, 0, 0, 4), UDim2.new(0.34, 0, 0, 170), 92, C.Electric, Theme.Fonts.Display)
	ghost.TextTransparency = 0.68
	ghost.TextXAlignment = Enum.TextXAlignment.Center
	text(hero, spec.Kicker, UDim2.fromOffset(24, 34), UDim2.new(1, -48, 0, 22), 13, C.Electric, Theme.Fonts.Strong)
	text(hero, spec.Title, UDim2.fromOffset(22, 60), UDim2.new(0.54, 0, 0, 54), 42, C.White, Theme.Fonts.Display)
	local subtitle = text(hero, spec.Subtitle, UDim2.fromOffset(24, 118), UDim2.new(0.56, 0, 0, 42), 13, C.Silver, Theme.Fonts.Body)
	subtitle.TextWrapped = true
	text(hero, "VTR X  /  STORE  /  MARKET", UDim2.fromOffset(24, 164), UDim2.new(0.6, 0, 0, 18), 11, C.Muted, Theme.Fonts.Strong)

	local tabRail = panel(scroll, "StoreTabRail", UDim2.fromOffset(0, 240), UDim2.new(1, 0, 0, 64), Color3.fromHex("070807"), 0.04)
	local tabScroller = Instance.new("ScrollingFrame")
	tabScroller.Name = "StoreTabs"
	tabScroller.BackgroundTransparency = 1
	tabScroller.BorderSizePixel = 0
	tabScroller.Position = UDim2.fromOffset(0, 0)
	tabScroller.Size = UDim2.new(1, -112, 1, 0)
	tabScroller.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabScroller.CanvasSize = UDim2.new()
	tabScroller.ScrollBarThickness = 0
	tabScroller.ScrollingDirection = Enum.ScrollingDirection.X
	tabScroller.Parent = tabRail
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabScroller

	local tabBack = Button.new({Text = "<", Variant = "Secondary", Size = UDim2.fromOffset(44, 44), OnActivated = function()
		tabScroller.CanvasPosition = Vector2.new(math.max(0, tabScroller.CanvasPosition.X - 180), 0)
	end})
	tabBack.Position = UDim2.new(1, -98, 0, 10)
	tabBack.Parent = tabRail
	local tabNext = Button.new({Text = ">", Variant = "Secondary", Size = UDim2.fromOffset(44, 44), OnActivated = function()
		local maxX = math.max(0, tabScroller.AbsoluteCanvasSize.X - tabScroller.AbsoluteSize.X)
		tabScroller.CanvasPosition = Vector2.new(math.min(maxX, tabScroller.CanvasPosition.X + 180), 0)
	end})
	tabNext.Position = UDim2.new(1, -50, 0, 10)
	tabNext.Parent = tabRail

	local balances = panel(scroll, "BalanceRail", UDim2.fromOffset(0, 318), UDim2.new(1, 0, 0, 46), Color3.fromHex("080A07"), 0.08)
	local currency = currencyFrom(context)
	text(balances, "C  " .. formatNumber(currency.Coins), UDim2.fromOffset(24, 0), UDim2.fromOffset(160, 46), 13, C.White, Theme.Fonts.Strong)
	text(balances, "VP  " .. formatNumber(currency.VoltraPoints), UDim2.fromOffset(196, 0), UDim2.fromOffset(160, 46), 13, C.White, Theme.Fonts.Strong)
	text(balances, "B  " .. formatNumber(currency.Bolts), UDim2.fromOffset(368, 0), UDim2.fromOffset(160, 46), 13, C.White, Theme.Fonts.Strong)
	local drop = Button.new({Text = "% DROP RATES", Variant = "Secondary", Size = UDim2.fromOffset(138, 34), OnActivated = function()
		context.Flow:ComingSoon("DROP RATES", "Pack odds and rarity tables are shown on each pack preview.")
	end})
	drop.Position = UDim2.new(1, -154, 0, 6)
	drop.Parent = balances

	local function setActiveButton(id: string)
		for tabId, button in pairs(tabButtons) do
			Button.setPrimary(button, tabId == id)
		end
	end

	local function render() end

	local function setTab(id: string)
		local nextTab = findTab(spec, id)
		if not nextTab then return end
		activeTab = nextTab
		state.SelectedTab = id
		context.StateService:SetTab(spec.Id, id)
		render()
	end

	for index, tab in ipairs(tabs) do
		local button = Button.new({Text = (TabIcons[tab.Id] or "*") .. "  " .. tab.Label, Variant = tab.Id == activeTab.Id and "Primary" or "Secondary", Size = UDim2.fromOffset(tab.Id == "VoltraPoints" and 188 or 152, 64), OnActivated = function()
			if activeTab.Id == tab.Id then return end
			context.Flow:ModeTransition(tab.Label, function()
				setTab(tab.Id)
			end, true)
		end})
		button.LayoutOrder = index
		button.Parent = tabScroller
		tabButtons[tab.Id] = button
	end

	render = function()
		if body then body:Destroy() end
		setActiveButton(activeTab.Id)
		body = Instance.new("Frame")
		body.Name = "StoreBody"
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(0, 386)
		body.Size = UDim2.new(1, 0, 0, 560)
		body.Parent = scroll

		local cards = activeTab.Cards or {}
		local grid = Instance.new("ScrollingFrame")
		grid.Name = "ProductGrid"
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.Size = UDim2.new(1, 0, 0, activeTab.Id == "Packs" and 350 or 250)
		grid.AutomaticCanvasSize = Enum.AutomaticSize.X
		grid.CanvasSize = UDim2.new()
		grid.ScrollingDirection = Enum.ScrollingDirection.X
		grid.ScrollBarImageColor3 = C.Electric
		grid.ScrollBarImageTransparency = 0.18
		grid.ScrollBarThickness = 4
		grid.Parent = body
		local layout = Instance.new("UIGridLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.CellPadding = UDim2.fromOffset(16, 16)
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.FillDirectionMaxCells = math.max(1, #cards)
		layout.CellSize = activeTab.Id == "Packs" and UDim2.fromOffset(198, 320) or UDim2.fromOffset(252, 218)
		layout.Parent = grid

		if #cards == 0 then
			local empty = panel(grid, "EmptyStoreState", UDim2.new(), UDim2.new(1, 0, 0, 180), Color3.fromHex("090B08"), 0.06)
			text(empty, "COMING SOON", UDim2.fromOffset(18, 26), UDim2.new(1, -36, 0, 32), 24, C.White, Theme.Fonts.Display)
			text(empty, activeTab.Description, UDim2.fromOffset(18, 66), UDim2.new(1, -36, 0, 48), 13, C.Silver, Theme.Fonts.Body).TextWrapped = true
		end

		for index, cardData in ipairs(cards) do
			local accent = activeTab.Id == "Packs" and packAccent(cardData) or (cardData.Accent and C.Electric or C.Silver)
			local card = panel(grid, tostring(cardData.Id or cardData.Title), UDim2.new(), UDim2.new(1, 0, 1, 0), Color3.fromHex("090B08"), 0.04)
			card.LayoutOrder = index
			stroke(card, accent, activeTab.Id == "Packs" and 0.18 or 0.42, activeTab.Id == "Packs" and 1.5 or 1)
			if activeTab.Id == "Packs" then
				text(card, "●  " .. string.upper((cardData.Title or "PACK"):gsub(" PACK", "")), UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 20), 11, accent, Theme.Fonts.Strong)
				drawPack(card, accent)
				text(card, string.upper(cardData.Title), UDim2.fromOffset(18, 242), UDim2.new(1, -36, 0, 26), 17, C.White, Theme.Fonts.Display)
				text(card, tostring(cardData.Subtitle), UDim2.fromOffset(18, 270), UDim2.new(1, -36, 0, 18), 11, C.Silver, Theme.Fonts.Strong)
			else
				local iconText = text(card, TabIcons[activeTab.Id] or "V", UDim2.fromOffset(18, 18), UDim2.fromOffset(56, 56), 22, accent, Theme.Fonts.Display)
				iconText.TextXAlignment = Enum.TextXAlignment.Center
				text(card, activeTab.Label, UDim2.fromOffset(86, 16), UDim2.new(1, -104, 0, 18), 11, accent, Theme.Fonts.Strong)
				local titleLabel = text(card, string.upper(cardData.Title), UDim2.fromOffset(18, 78), UDim2.new(1, -36, 0, 28), 18, C.White, Theme.Fonts.Display)
				titleLabel.TextWrapped = true
				text(card, tostring(cardData.Subtitle), UDim2.fromOffset(18, 112), UDim2.new(1, -36, 0, 22), 12, C.Silver, Theme.Fonts.Strong)
				local detail = text(card, tostring(cardData.Meta), UDim2.fromOffset(18, 136), UDim2.new(1, -36, 0, 30), 11, C.Muted, Theme.Fonts.Body)
				detail.TextWrapped = true
			end

			local action = table.clone(cardData.Action or {})
			action.Detail = cardData.Detail
			if action.Operation == "Purchase" and action.ItemType ~= "Pack" and state.Owned[action.Item] then
				action.Label = "OWNED"
				action.Confirm = false
			end
			if action.Operation == "Select" and (state.Selections[action.Key] == action.Item or state.Equipped[action.Key] == action.Item) then
				action.Label = "EQUIPPED"
			end
			local price = activeTab.Id == "Packs" and tostring(cardData.Meta or action.Label or "BUY") or tostring(action.Label or "VIEW")
			local actionButton = Button.new({Text = price, Variant = "Primary", Size = UDim2.new(1, -36, 0, 44), OnActivated = function()
				context.Flow:Handle(cardData, action, function()
					local persisted = context.Persist(spec.Id, action, state)
					if type(persisted) == "table" then
						if not persisted.Success then return persisted.Message or "Action unavailable right now." end
						service:Perform(action)
						return persisted
					end
					return persisted or service:Perform(action)
				end, render, setTab)
			end})
			actionButton.Position = UDim2.new(0, 18, 1, -58)
			actionButton.Parent = card
		end

		local info = Instance.new("Frame")
		info.Name = "StoreInfoRail"
		info.BackgroundTransparency = 1
		info.Position = UDim2.fromOffset(0, activeTab.Id == "Packs" and 374 or 256)
		info.Size = UDim2.new(1, 0, 0, 110)
		info.Parent = body
		infoCard(info, 0, 0.25, "SMART ODDS", "Higher rarity packs have better odds for top players.", "^")
		infoCard(info, 0.25, 0.25, "SEALED PACKS", "Every pack contains sealed, tradable rewards.", "#")
		infoCard(info, 0.5, 0.25, "BEST PLAYER", "Your best pull this season: 95 OVR", "95")
		infoCard(info, 0.75, 0.25, "LIMITED TIME", "Special packs and offers refresh every week.", "T")
	end

	render()
	return group
end

return Page
