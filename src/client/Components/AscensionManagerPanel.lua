--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TacticConfig = require(ReplicatedStorage.VTR.Shared.AITacticConfig)
local FormationConfig = require(ReplicatedStorage.VTR.Shared.FormationConfig)
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local Theme = require(script.Parent.ManagerModeTheme)
local ProgressBar = require(script.Parent.ProgressBar)

local ManagerPanel = {}
ManagerPanel.__index = ManagerPanel

local SLIDER_FIELDS = {
	{Key = "AttackingWidth", Label = "TEAM WIDTH"},
	{Key = "DefensiveDepth", Label = "LINE DEPTH"},
	{Key = "PressingIntensity", Label = "PRESSING INTENSITY"},
}

local MENTALITIES = {
	{Key = "Defend", Label = "Defensive", Mark = "D"},
	{Key = "Balanced", Label = "Balanced", Mark = "B"},
	{Key = "Attack", Label = "Attacking", Mark = "A"},
}

local QUICK_TACTICS = {
	{Key = "short_possession", Label = "Keep Possession", Mark = "KP"},
	{Key = "counter_attack", Label = "Counter Attack", Mark = "CA"},
	{Key = "high_press", Label = "High Press", Mark = "HP"},
	{Key = "protect_lead", Label = "Protect Lead", Mark = "PL"},
	{Key = "wing_overload", Label = "Wing Play", Mark = "WP"},
	{Key = "central_overload", Label = "Central Combo", Mark = "CC"},
	{Key = "vertical_combination", Label = "Direct Play", Mark = "DP"},
	{Key = "low_block_counter", Label = "Low Block", Mark = "LB"},
	{Key = "balanced_control", Label = "Balanced", Mark = "BA"},
	{Key = "all_out_attack", Label = "All Out Attack", Mark = "AO"},
}

local function makeCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent: Instance, text: string, size: UDim2, textSize: number, color: Color3, font: Enum.Font, xAlign: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = font
	label.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.ZIndex = 143
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, text: string, size: UDim2, callback: (() -> ())?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.Colors.PanelRaised
	button.BorderSizePixel = 0
	button.Size = size
	button.Text = text
	button.TextColor3 = Theme.Colors.White
	button.TextSize = 12
	button.TextWrapped = true
	button.Font = Theme.Fonts.Strong
	button.ZIndex = 144
	button.Parent = parent
	makeCorner(button, Theme.Radius.Control)
	makeStroke(button, Theme.Colors.StrokeDim, 1, .35)
	button.MouseEnter:Connect(function()
		if button.Active ~= false and button:GetAttribute("Selected") ~= true then
			TweenService:Create(button, TweenInfo.new(.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Theme.Colors.PanelSoft, TextColor3 = Theme.Colors.White}):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		if button:GetAttribute("Selected") ~= true then
			TweenService:Create(button, TweenInfo.new(.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Theme.Colors.PanelRaised, TextColor3 = Theme.Colors.White}):Play()
		end
	end)
	if callback then button.Activated:Connect(callback) end
	return button
end

local function setButtonSelected(button: TextButton, selected: boolean)
	button:SetAttribute("Selected", selected)
	button.BackgroundColor3 = selected and Theme.Colors.Accent or Theme.Colors.PanelRaised
	button.TextColor3 = selected and Theme.Colors.DarkText or Theme.Colors.White
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = selected and Theme.Colors.Accent or Theme.Colors.StrokeDim
		stroke.Transparency = selected and 0 or .35
	end
end

local function cloneSliders(source: any): any
	local output = {}
	if type(source) == "table" then
		for _, field in SLIDER_FIELDS do
			local value = tonumber(source[field.Key])
			if value then output[field.Key] = math.clamp(value, 0, 100) end
		end
	end
	return output
end

local function formationNames(): {string}
	local preferred = {"4-3-3", "4-2-3-1", "4-4-2", "3-5-2", "5-3-2", "5V5"}
	local names = {}
	for _, name in preferred do
		if FormationConfig.Formations[name] and #(FormationConfig.GetOrder(name) or {}) >= 11 then table.insert(names, name) end
	end
	for name in FormationConfig.Formations do
		if not table.find(names, name) and #(FormationConfig.GetOrder(name) or {}) >= 11 then table.insert(names, name) end
	end
	return names
end

local function normalizeMentality(value: any): string
	local text = tostring(value or "Balanced")
	if text == "Defensive" then return "Defend" end
	if text == "Attacking" then return "Attack" end
	if text == "Defend" or text == "Attack" or text == "Balanced" then return text end
	return "Balanced"
end

function ManagerPanel.new(parent: Instance, options: any): any
	local self = setmetatable({}, ManagerPanel)
	self.Options = options or {}
	self.Connections = {}
	self.Half = 1
	self.Formations = formationNames()
	self.ActiveTab = "Tactics"
	self.StylePickerOpen = false
	local startingPreset = TacticConfig.ResolveId(self.Options.InitialTacticalPreset or self.Options.InitialMentality or "Balanced")
	local startingTactics = TacticConfig.Normalize({PresetId = startingPreset})
	self.Applied = {
		TacticalPreset = startingTactics.PresetId,
		Formation = tostring(self.Options.InitialFormation or self.Formations[1] or "4-3-3"),
		Mentality = normalizeMentality(self.Options.InitialMentality),
		QuickTactic = nil,
		Sliders = cloneSliders(startingTactics.Sliders),
	}
	self.Pending = {
		TacticalPreset = self.Applied.TacticalPreset,
		Formation = self.Applied.Formation,
		Mentality = self.Applied.Mentality,
		QuickTactic = self.Applied.QuickTactic,
		Sliders = cloneSliders(self.Applied.Sliders),
	}
	self.Manager = {
		Total = 0,
		FirstHalfInteractions = 0,
		SecondHalfInteractions = 0,
		AfterHalf = false,
		CurrentMentality = self.Applied.Mentality,
		CurrentFormation = self.Applied.Formation,
		CurrentTacticalPreset = self.Applied.TacticalPreset,
		CurrentSliders = cloneSliders(self.Applied.Sliders),
	}

	local root = Instance.new("Frame")
	root.Name = "AscensionManagerPanel"
	root.AnchorPoint = Vector2.new(1, .5)
	root.BackgroundColor3 = Theme.Colors.Panel
	root.BackgroundTransparency = .03
	root.BorderSizePixel = 0
	root.Position = UDim2.new(1, -12, .5, 0)
	root.Size = UDim2.fromOffset(430, 690)
	root.ZIndex = 140
	root.Parent = parent
	makeCorner(root, Theme.Radius.Panel)
	makeStroke(root, Theme.Colors.Stroke, 1.3, .08)
	self.Root = root

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 22)
	pad.PaddingBottom = UDim.new(0, 18)
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = root

	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 78)
	header.ZIndex = 141
	header.Parent = root

	local titleA = makeLabel(header, "MANAGE ", UDim2.new(.55, 0, 0, 34), 26, Theme.Colors.White, Theme.Fonts.Display)
	titleA.Position = UDim2.fromOffset(0, 0)
	local titleB = makeLabel(header, "MATCH", UDim2.new(.45, 0, 0, 34), 26, Theme.Colors.Accent, Theme.Fonts.Display)
	titleB.Position = UDim2.new(.50, 0, 0, 0)
	local subtitle = makeLabel(header, "Adjust your team's approach in real time", UDim2.new(1, -48, 0, 24), 12, Theme.Colors.Silver, Theme.Fonts.Body)
	subtitle.Position = UDim2.fromOffset(0, 34)
	local close = makeButton(header, "II", UDim2.fromOffset(38, 38), function()
		if self.Options.OnSubstitutions then self.Options.OnSubstitutions() end
	end)
	close.Position = UDim2.new(1, -38, 0, 0)
	close.TextSize = 18

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(0, 78)
	tabs.Size = UDim2.new(1, 0, 0, 42)
	tabs.ZIndex = 142
	tabs.Parent = root
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 16)
	tabLayout.Parent = tabs
	self.TabButtons = {}
	for index, tabName in {"Tactics", "Substitutions", "Instructions", "Team"} do
		local tabButton = makeButton(tabs, tabName, UDim2.new(.25, -12, 0, 34), function() self:SetTab(tabName) end)
		tabButton.LayoutOrder = index
		tabButton.BackgroundTransparency = 1
		tabButton.TextSize = 11
		self.TabButtons[tabName] = tabButton
	end

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 124)
	body.Size = UDim2.new(1, 0, 1, -204)
	body.ClipsDescendants = true
	body.ZIndex = 142
	body.Parent = root
	self.Pages = {}
	for _, name in {"Tactics", "Substitutions", "Instructions", "Team"} do
		local page = Instance.new("ScrollingFrame")
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Size = UDim2.fromScale(1, 1)
		page.CanvasSize = UDim2.fromOffset(0, 0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = Theme.Colors.Accent
		page.Visible = name == self.ActiveTab
		page.ZIndex = 142
		page.Parent = body
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 14)
		layout.Parent = page
		self.Pages[name] = page
	end

	self:_buildTacticsPage()
	self:_buildSubstitutionsPage()
	self:_buildInstructionsPage()
	self:_buildTeamPage()
	self:_buildFooter()
	self:_connectResize()
	local finalPosition = root.Position
	root.Position = UDim2.new(1, 24, finalPosition.Y.Scale, finalPosition.Y.Offset)
	TweenService:Create(root, TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = finalPosition, BackgroundTransparency = .03}):Play()
	self:Update(self.Manager, self.Options.Objective)
	self:_refreshAll()
	task.defer(function()
		if self.Options.SelectOnOpen == true and GuiService.SelectedObject == nil then GuiService.SelectedObject = self.ApplyButton end
	end)
	return self
end

function ManagerPanel:_makeCard(parent: Instance, height: number?): Frame
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.Colors.PanelInset
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, -4, 0, height or 72)
	card.ZIndex = 143
	card.Parent = parent
	makeCorner(card, Theme.Radius.Card)
	makeStroke(card, Theme.Colors.StrokeDim, 1, .35)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card
	return card
end

function ManagerPanel:_buildTacticsPage()
	local page = self.Pages.Tactics
	local styleCard = self:_makeCard(page, 78)
	self.StyleCard = styleCard
	self.StyleName = makeLabel(styleCard, "", UDim2.new(1, -112, 0, 26), 15, Theme.Colors.White, Theme.Fonts.Strong)
	self.StyleName.Position = UDim2.fromOffset(50, 8)
	self.StyleDescription = makeLabel(styleCard, "", UDim2.new(1, -112, 0, 28), 10, Theme.Colors.Silver, Theme.Fonts.Body)
	self.StyleDescription.Position = UDim2.fromOffset(50, 34)
	local styleMark = makeLabel(styleCard, "TX", UDim2.fromOffset(38, 38), 16, Theme.Colors.Accent, Theme.Fonts.Display, Enum.TextXAlignment.Center)
	styleMark.Position = UDim2.fromOffset(0, 14)
	local change = makeButton(styleCard, "Change >", UDim2.fromOffset(90, 36), function()
		self.StylePickerOpen = not self.StylePickerOpen
		self.StyleList.Visible = self.StylePickerOpen
		self.StyleList.Size = self.StylePickerOpen and UDim2.new(1, -4, 0, 276) or UDim2.new(1, -4, 0, 0)
	end)
	change.Position = UDim2.new(1, -92, 0, 20)

	local styleList = self:_makeCard(page, 0)
	styleList.Visible = false
	styleList.ClipsDescendants = true
	self.StyleList = styleList
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = styleList
	self.StyleButtons = {}
	for index, presetId in TacticConfig.Order do
		local preset = TacticConfig.Presets[presetId]
		local item = makeButton(styleList, preset.Name, UDim2.new(1, 0, 0, 36), function()
			self.Pending.TacticalPreset = presetId
			self.Pending.QuickTactic = nil
			self:_fillPresetSliders(presetId)
			self:_markDirty()
		end)
		item.LayoutOrder = index
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.TextSize = 11
		local itemPad = Instance.new("UIPadding")
		itemPad.PaddingLeft = UDim.new(0, 12)
		itemPad.Parent = item
		self.StyleButtons[presetId] = item
	end

	local formationRow = Instance.new("Frame")
	formationRow.BackgroundTransparency = 1
	formationRow.Size = UDim2.new(1, -4, 0, 172)
	formationRow.ZIndex = 143
	formationRow.Parent = page
	makeLabel(formationRow, "FORMATION", UDim2.new(1, 0, 0, 18), 11, Theme.Colors.White, Theme.Fonts.Strong).Position = UDim2.fromOffset(0, 0)
	local previous = makeButton(formationRow, "<", UDim2.fromOffset(42, 42), function() self:_cycleFormation(-1) end)
	previous.Position = UDim2.fromOffset(86, 30)
	self.FormationLabel = makeLabel(formationRow, "", UDim2.new(1, -188, 0, 42), 16, Theme.Colors.White, Theme.Fonts.Display, Enum.TextXAlignment.Center)
	self.FormationLabel.Position = UDim2.fromOffset(136, 30)
	self.FormationLabel.BackgroundColor3 = Theme.Colors.PanelRaised
	self.FormationLabel.BackgroundTransparency = 0
	makeCorner(self.FormationLabel, Theme.Radius.Control)
	local nextButton = makeButton(formationRow, ">", UDim2.fromOffset(42, 42), function() self:_cycleFormation(1) end)
	nextButton.Position = UDim2.new(1, -42, 0, 30)
	local pitch = Instance.new("Frame")
	pitch.BackgroundColor3 = Color3.fromRGB(17, 52, 39)
	pitch.BorderSizePixel = 0
	pitch.Position = UDim2.fromOffset(0, 30)
	pitch.Size = UDim2.fromOffset(76, 126)
	pitch.ZIndex = 143
	pitch.Parent = formationRow
	makeCorner(pitch, 8)
	makeStroke(pitch, Color3.fromRGB(93, 140, 115), 1, .2)
	self.FormationPitch = pitch
	self.FormationDots = {}

	local mentalityRow = Instance.new("Frame")
	mentalityRow.BackgroundTransparency = 1
	mentalityRow.Size = UDim2.new(1, -4, 0, 78)
	mentalityRow.ZIndex = 143
	mentalityRow.Parent = page
	makeLabel(mentalityRow, "MENTALITY", UDim2.new(1, 0, 0, 18), 11, Theme.Colors.White, Theme.Fonts.Strong).Position = UDim2.fromOffset(0, 0)
	local mLayoutFrame = Instance.new("Frame")
	mLayoutFrame.BackgroundTransparency = 1
	mLayoutFrame.Position = UDim2.fromOffset(0, 28)
	mLayoutFrame.Size = UDim2.new(1, 0, 0, 46)
	mLayoutFrame.Parent = mentalityRow
	local mLayout = Instance.new("UIListLayout")
	mLayout.FillDirection = Enum.FillDirection.Horizontal
	mLayout.Padding = UDim.new(0, 10)
	mLayout.Parent = mLayoutFrame
	self.MentalityButtons = {}
	for _, item in MENTALITIES do
		local button = makeButton(mLayoutFrame, item.Mark .. "  " .. item.Label, UDim2.new(1 / 3, -7, 0, 46), function()
			self.Pending.Mentality = item.Key
			self:_markDirty()
		end)
		self.MentalityButtons[item.Key] = button
	end

	self.SliderRows = {}
	for _, field in SLIDER_FIELDS do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -4, 0, 32)
		row.ZIndex = 143
		row.Parent = page
		makeLabel(row, field.Label, UDim2.new(.40, 0, 1, 0), 11, Theme.Colors.White, Theme.Fonts.Strong).Position = UDim2.fromOffset(0, 0)
		local segments = Instance.new("Frame")
		segments.BackgroundTransparency = 1
		segments.Position = UDim2.new(.42, 0, 0, 7)
		segments.Size = UDim2.new(.58, 0, 0, 12)
		segments.ZIndex = 143
		segments.Parent = row
		local segLayout = Instance.new("UIListLayout")
		segLayout.FillDirection = Enum.FillDirection.Horizontal
		segLayout.Padding = UDim.new(0, 4)
		segLayout.Parent = segments
		local holders = {}
		for index = 1, 8 do
			local seg = makeButton(segments, "", UDim2.new(1 / 8, -4, 1, 0), function()
				self.Pending.Sliders[field.Key] = index * 12.5
				self:_markDirty()
			end)
			makeCorner(seg, 4)
			table.insert(holders, seg)
		end
		self.SliderRows[field.Key] = holders
	end

	local quick = Instance.new("Frame")
	quick.BackgroundTransparency = 1
	quick.Size = UDim2.new(1, -4, 0, 244)
	quick.ZIndex = 143
	quick.Parent = page
	makeLabel(quick, "QUICK TACTICS", UDim2.new(1, 0, 0, 18), 11, Theme.Colors.White, Theme.Fonts.Strong).Position = UDim2.fromOffset(0, 0)
	local quickGrid = Instance.new("Frame")
	quickGrid.BackgroundTransparency = 1
	quickGrid.Position = UDim2.fromOffset(0, 28)
	quickGrid.Size = UDim2.new(1, 0, 0, 212)
	quickGrid.Parent = quick
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.CellSize = UDim2.new(.5, -5, 0, 38)
	grid.Parent = quickGrid
	self.QuickButtons = {}
	for _, item in QUICK_TACTICS do
		local button = makeButton(quickGrid, item.Mark .. "  " .. item.Label, UDim2.new(.5, -5, 0, 38), function()
			self.Pending.QuickTactic = item.Key
			self.Pending.TacticalPreset = item.Key
			self:_fillPresetSliders(item.Key)
			self:_markDirty()
		end)
		button.TextSize = 11
		self.QuickButtons[item.Key] = button
	end
end

function ManagerPanel:_buildSubstitutionsPage()
	local page = self.Pages.Substitutions
	local card = self:_makeCard(page, 150)
	makeLabel(card, "SUBSTITUTIONS", UDim2.new(1, 0, 0, 24), 16, Theme.Colors.White, Theme.Fonts.Display).Position = UDim2.fromOffset(0, 0)
	makeLabel(card, "Use the live team sheet to swap bench players into the lineup. Existing stamina, lineup, and server validation stay in charge.", UDim2.new(1, 0, 0, 52), 12, Theme.Colors.Silver, Theme.Fonts.Body).Position = UDim2.fromOffset(0, 34)
	local open = makeButton(card, "OPEN TEAM SHEET", UDim2.new(1, 0, 0, 44), function()
		if self.Options.OnSubstitutions then self.Options.OnSubstitutions() end
	end)
	open.Position = UDim2.fromOffset(0, 92)
end

function ManagerPanel:_buildInstructionsPage()
	local page = self.Pages.Instructions
	local card = self:_makeCard(page, 168)
	makeLabel(card, "PLAYER INSTRUCTIONS", UDim2.new(1, 0, 0, 24), 16, Theme.Colors.White, Theme.Fonts.Display).Position = UDim2.fromOffset(0, 0)
	makeLabel(card, "Runtime tactical instructions are handled through the style, mentality, and quick tactic systems. Per-player role editing is kept out of live play until it has a server-authoritative apply path.", UDim2.new(1, 0, 0, 86), 12, Theme.Colors.Silver, Theme.Fonts.Body).Position = UDim2.fromOffset(0, 34)
	local status = makeLabel(card, "LOCKED DURING MATCH", UDim2.new(1, 0, 0, 34), 12, Theme.Colors.Warning, Theme.Fonts.Strong, Enum.TextXAlignment.Center)
	status.Position = UDim2.fromOffset(0, 118)
	status.BackgroundColor3 = Theme.Colors.PanelRaised
	status.BackgroundTransparency = 0
	makeCorner(status, Theme.Radius.Control)
end

function ManagerPanel:_buildTeamPage()
	local page = self.Pages.Team
	local card = self:_makeCard(page, 210)
	makeLabel(card, "TEAM STATE", UDim2.new(1, 0, 0, 24), 16, Theme.Colors.White, Theme.Fonts.Display).Position = UDim2.fromOffset(0, 0)
	self.TeamStyle = makeLabel(card, "", UDim2.new(1, 0, 0, 26), 12, Theme.Colors.Silver, Theme.Fonts.Body)
	self.TeamStyle.Position = UDim2.fromOffset(0, 38)
	self.TeamFormation = makeLabel(card, "", UDim2.new(1, 0, 0, 26), 12, Theme.Colors.Silver, Theme.Fonts.Body)
	self.TeamFormation.Position = UDim2.fromOffset(0, 68)
	self.TeamMentality = makeLabel(card, "", UDim2.new(1, 0, 0, 26), 12, Theme.Colors.Silver, Theme.Fonts.Body)
	self.TeamMentality.Position = UDim2.fromOffset(0, 98)
	self.TeamProgress = makeLabel(card, "", UDim2.new(1, 0, 0, 24), 12, Theme.Colors.Silver, Theme.Fonts.Body)
	self.TeamProgress.Position = UDim2.fromOffset(0, 132)
	local progress = ProgressBar.new(0)
	progress.Position = UDim2.fromOffset(0, 168)
	progress.Size = UDim2.new(1, 0, 0, 8)
	progress.ZIndex = 145
	progress.Parent = card
	self.Progress = progress
end

function ManagerPanel:_buildFooter()
	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.new(0, 0, 1, -72)
	footer.Size = UDim2.new(1, 0, 0, 72)
	footer.ZIndex = 146
	footer.Parent = self.Root
	self.DirtyLabel = makeLabel(footer, "", UDim2.new(1, 0, 0, 18), 11, Theme.Colors.Silver, Theme.Fonts.Body, Enum.TextXAlignment.Center)
	self.DirtyLabel.Position = UDim2.fromOffset(0, 0)
	self.ApplyButton = makeButton(footer, "APPLY CHANGES", UDim2.new(1, 0, 0, 48), function() self:_apply() end)
	self.ApplyButton.Position = UDim2.fromOffset(0, 24)
	self.ApplyButton.TextSize = 15
end

function ManagerPanel:_fillPresetSliders(presetId: string)
	local preset = TacticConfig.Get(presetId)
	for _, field in SLIDER_FIELDS do
		self.Pending.Sliders[field.Key] = tonumber(preset.Sliders[field.Key]) or self.Pending.Sliders[field.Key] or 50
	end
end

function ManagerPanel:_cycleFormation(delta: number)
	local index = table.find(self.Formations, self.Pending.Formation) or 1
	local nextIndex = ((index - 1 + delta) % #self.Formations) + 1
	self.Pending.Formation = self.Formations[nextIndex]
	self:_markDirty()
end

function ManagerPanel:_markDirty()
	self:_refreshAll()
end

function ManagerPanel:_isDirty(): boolean
	if self.Pending.TacticalPreset ~= self.Applied.TacticalPreset then return true end
	if self.Pending.Formation ~= self.Applied.Formation then return true end
	if self.Pending.Mentality ~= self.Applied.Mentality then return true end
	if self.Pending.QuickTactic ~= self.Applied.QuickTactic then return true end
	for _, field in SLIDER_FIELDS do
		if math.floor((tonumber(self.Pending.Sliders[field.Key]) or 0) + .5) ~= math.floor((tonumber(self.Applied.Sliders[field.Key]) or 0) + .5) then return true end
	end
	return false
end

function ManagerPanel:_apply()
	if not self:_isDirty() then return end
	if self.Options.OnApply then
		self.Options.OnApply({
			TacticalPreset = self.Pending.TacticalPreset,
			Formation = self.Pending.Formation,
			Mentality = self.Pending.Mentality,
			QuickTactic = self.Pending.QuickTactic,
			Sliders = cloneSliders(self.Pending.Sliders),
		})
	elseif self.Options.OnAction then
		self.Options.OnAction("Mentality", self.Pending.Mentality)
	end
	self.DirtyLabel.Text = "Applying..."
end

function ManagerPanel:_refreshAll()
	for tabName, button in self.TabButtons do setButtonSelected(button, tabName == self.ActiveTab) end
	local preset = TacticConfig.Get(self.Pending.TacticalPreset)
	self.StyleName.Text = preset.Name
	self.StyleDescription.Text = preset.Description
	for presetId, button in self.StyleButtons do setButtonSelected(button, presetId == self.Pending.TacticalPreset) end
	self.FormationLabel.Text = self.Pending.Formation
	self:_refreshFormation()
	for _, item in MENTALITIES do setButtonSelected(self.MentalityButtons[item.Key], item.Key == self.Pending.Mentality) end
	for _, field in SLIDER_FIELDS do
		local value = math.clamp(tonumber(self.Pending.Sliders[field.Key]) or 50, 0, 100)
		local filled = math.clamp(math.ceil(value / 12.5), 1, 8)
		for index, segment in self.SliderRows[field.Key] do
			segment.BackgroundColor3 = index <= filled and Theme.Colors.Accent or Theme.Colors.PanelRaised
		end
	end
	for _, item in QUICK_TACTICS do setButtonSelected(self.QuickButtons[item.Key], item.Key == self.Pending.QuickTactic) end
	local dirty = self:_isDirty()
	self.DirtyLabel.Text = dirty and "Pending tactical changes" or "Current plan applied"
	self.DirtyLabel.TextColor3 = dirty and Theme.Colors.Warning or Theme.Colors.Silver
	self.ApplyButton.Active = dirty
	self.ApplyButton.Selectable = dirty
	self.ApplyButton.BackgroundColor3 = dirty and Theme.Colors.Accent or Theme.Colors.PanelRaised
	self.ApplyButton.TextColor3 = dirty and Theme.Colors.DarkText or Theme.Colors.Muted
	self.TeamStyle.Text = "Style: " .. TacticConfig.Get(self.Applied.TacticalPreset).Name
	self.TeamFormation.Text = "Formation: " .. tostring(self.Applied.Formation)
	self.TeamMentality.Text = "Mentality: " .. tostring(self.Applied.Mentality)
	local total = math.max(0, math.floor(tonumber(self.Manager.Total) or 0))
	local required = math.max(1, math.floor(tonumber(Config.Manager.RequiredInteractions) or 2))
	local afterHalf = self.Manager.AfterHalf == true or (tonumber(self.Manager.SecondHalfInteractions) or 0) > 0
	self.TeamProgress.Text = "Manager objective: " .. tostring(math.min(total, required)) .. " / " .. tostring(required) .. (afterHalf and " with second-half change" or "")
	if self.Progress then ProgressBar.set(self.Progress, total / required, workspace:GetAttribute("VTRReducedMotion") ~= true) end
end

function ManagerPanel:_refreshFormation()
	for _, dot in self.FormationDots do dot:Destroy() end
	table.clear(self.FormationDots)
	for index, slot in FormationConfig.IterSlots(self.Pending.Formation) do
		local dot = Instance.new("TextLabel")
		dot.BackgroundColor3 = index == 1 and Theme.Colors.White or Theme.Colors.Accent
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(10, 10)
		dot.Position = UDim2.new(math.clamp(slot.X, .06, .94), -5, math.clamp(slot.Y, .06, .94), -5)
		dot.Text = ""
		dot.ZIndex = 145
		dot.Parent = self.FormationPitch
		makeCorner(dot, 99)
		table.insert(self.FormationDots, dot)
	end
end

function ManagerPanel:SetTab(tabName: string)
	self.ActiveTab = self.Pages[tabName] and tabName or "Tactics"
	for name, page in self.Pages do page.Visible = name == self.ActiveTab end
	self:_refreshAll()
end

function ManagerPanel:SetHalf(half: number)
	self.Half = math.max(1, math.floor(tonumber(half) or 1))
	self:_refreshAll()
end

function ManagerPanel:Update(manager: any, objective: any?)
	if type(manager) == "table" then
		self.Manager = manager
		self.Applied.Formation = tostring(manager.CurrentFormation or self.Applied.Formation)
		self.Applied.Mentality = normalizeMentality(manager.CurrentMentality or self.Applied.Mentality)
		self.Applied.TacticalPreset = TacticConfig.ResolveId(manager.CurrentTacticalPreset or manager.CurrentQuickTactic or self.Applied.TacticalPreset)
		self.Applied.QuickTactic = manager.CurrentQuickTactic
		self.Applied.Sliders = cloneSliders(manager.CurrentSliders or self.Applied.Sliders)
		self.Pending.Formation = self.Applied.Formation
		self.Pending.Mentality = self.Applied.Mentality
		self.Pending.TacticalPreset = self.Applied.TacticalPreset
		self.Pending.QuickTactic = self.Applied.QuickTactic
		self.Pending.Sliders = cloneSliders(self.Applied.Sliders)
	end
	self.Objective = objective or self.Objective
	self:_refreshAll()
end

function ManagerPanel:_connectResize()
	local function resize()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		if viewport.X < 820 then
			self.Root.AnchorPoint = Vector2.new(.5, 1)
			self.Root.Position = UDim2.new(.5, 0, 1, -10)
			self.Root.Size = UDim2.new(1, -20, 0, math.clamp(viewport.Y * .72, 430, 620))
		else
			self.Root.AnchorPoint = Vector2.new(1, .5)
			self.Root.Position = UDim2.new(1, -12, .5, 0)
			self.Root.Size = UDim2.fromOffset(math.clamp(viewport.X * .235, 380, 470), math.clamp(viewport.Y * .90, 560, viewport.Y - 24))
		end
	end
	local camera = workspace.CurrentCamera
	if camera then table.insert(self.Connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)) end
	resize()
end

function ManagerPanel:Destroy()
	for _, connection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
	if self.Root then self.Root:Destroy() end
end

return ManagerPanel
