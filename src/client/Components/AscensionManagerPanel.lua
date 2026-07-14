--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local Button = require(script.Parent.Button)
local ProgressBar = require(script.Parent.ProgressBar)

local ManagerPanel = {}
ManagerPanel.__index = ManagerPanel

local function corner(parent: Instance, radius: number?)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or Theme.Radius.Medium)
	item.Parent = parent
end

local function label(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = value
	item.TextColor3 = color
	item.TextSize = textSize
	item.Font = font
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.ZIndex = 143
	item.Parent = parent
	return item
end

local function enabled(button: TextButton, value: boolean)
	button.Active = value
	button.Selectable = value
	button.TextTransparency = value and 0 or 0.55
	button.BackgroundTransparency = value and 0 or 0.35
end

function ManagerPanel.new(parent: Instance, options: any): any
	local self = setmetatable({}, ManagerPanel)
	self.Options = options
	self.Manager = {
		Total = 0,
		FirstHalfInteractions = 0,
		SecondHalfInteractions = 0,
		AfterHalf = false,
		CurrentMentality = tostring(options.InitialMentality or "Balanced"),
		CurrentFormation = tostring(options.InitialFormation or "4-3-3"),
	}
	self.Half = 1
	self.LastRequestAt = 0
	self.Connections = {}

	local root = Instance.new("Frame")
	root.Name = "AscensionManagerPanel"
	root.AnchorPoint = Vector2.new(1, 0.5)
	root.BackgroundColor3 = Theme.Colors.Graphite
	root.BackgroundTransparency = 0.04
	root.BorderSizePixel = 0
	root.Position = UDim2.new(1, -18, 0.5, 20)
	root.Size = UDim2.fromOffset(344, 500)
	root.ZIndex = 140
	root.Parent = parent
	corner(root, Theme.Radius.Large)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Border
	stroke.Thickness = 1
	stroke.Transparency = 0.08
	stroke.Parent = root
	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = Theme.Colors.Electric
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(1, 0, 0, 3)
	accent.ZIndex = 141
	accent.Parent = root
	corner(accent, Theme.Radius.Small)

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, 3)
	body.Size = UDim2.new(1, 0, 1, -3)
	body.CanvasSize = UDim2.fromOffset(0, 486)
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = Theme.Colors.Electric
	body.ZIndex = 142
	body.Parent = root

	label(body, "VOLTRA ASCENSION", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 17), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	label(body, "MANAGER MODE", UDim2.fromOffset(16, 28), UDim2.new(1, -32, 0, 28), 20, Theme.Colors.White, Theme.Fonts.Display)
	local objective = label(body, tostring(options.Objective or Config.UI.ManagerPassive), UDim2.fromOffset(16, 59), UDim2.new(1, -32, 0, 38), 9, Theme.Colors.Silver, Theme.Fonts.Body)
	objective.TextWrapped = true
	self.Objective = objective

	local progressTitle = label(body, "ACTIVE MANAGEMENT", UDim2.fromOffset(16, 104), UDim2.new(1, -32, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	local progressValue = label(body, "0 / " .. tostring(Config.Manager.RequiredInteractions), UDim2.new(1, -102, 0, 104), UDim2.fromOffset(86, 18), 9, Theme.Colors.White, Theme.Fonts.Strong)
	progressValue.TextXAlignment = Enum.TextXAlignment.Right
	self.ProgressTitle = progressTitle
	self.ProgressValue = progressValue
	local progress = ProgressBar.new(0)
	progress.Position = UDim2.fromOffset(16, 126)
	progress.Size = UDim2.new(1, -32, 0, 6)
	progress.ZIndex = 143
	progress.Parent = body
	self.Progress = progress
	local halfRequirement = label(body, "SECOND-HALF CHANGE REQUIRED", UDim2.fromOffset(16, 138), UDim2.new(1, -32, 0, 18), 8, Theme.Colors.Warning, Theme.Fonts.Strong)
	self.HalfRequirement = halfRequirement

	label(body, "MENTALITY", UDim2.fromOffset(16, 166), UDim2.new(1, -32, 0, 17), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	local mentalityHolder = Instance.new("Frame")
	mentalityHolder.BackgroundTransparency = 1
	mentalityHolder.Position = UDim2.fromOffset(16, 188)
	mentalityHolder.Size = UDim2.new(1, -32, 0, 80)
	mentalityHolder.ZIndex = 143
	mentalityHolder.Parent = body
	local mentalityGrid = Instance.new("UIGridLayout")
	mentalityGrid.CellPadding = UDim2.fromOffset(6, 6)
	mentalityGrid.CellSize = UDim2.new(1 / 3, -4, 0, 36)
	mentalityGrid.FillDirectionMaxCells = 3
	mentalityGrid.SortOrder = Enum.SortOrder.LayoutOrder
	mentalityGrid.Parent = mentalityHolder
	self.MentalityButtons = {}

	local function request(action: string, value: string?)
		local now = os.clock()
		if now - self.LastRequestAt < 0.45 then return end
		self.LastRequestAt = now
		if self.Options.OnAction then self.Options.OnAction(action, value) end
	end

	for index, mentality in Config.Manager.Mentalities do
		local button = Button.new({
			Text = mentality,
			Variant = "Secondary",
			Size = UDim2.fromScale(1, 1),
			OnActivated = function() request("Mentality", mentality) end,
		})
		button.LayoutOrder = index
		button.Selectable = true
		button.SelectionOrder = 10 + index
		button.TextSize = 8
		button.ZIndex = 144
		button.Parent = mentalityHolder
		self.MentalityButtons[mentality] = button
	end

	label(body, "FORMATION", UDim2.fromOffset(16, 282), UDim2.new(1, -32, 0, 17), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	local previous = Button.new({ Text = "<", Variant = "Secondary", Size = UDim2.fromOffset(44, 40), OnActivated = function()
		local current = table.find(Config.Manager.Formations, tostring(self.Manager.CurrentFormation)) or 1
		local index = current - 1
		if index < 1 then index = #Config.Manager.Formations end
		request("Formation", Config.Manager.Formations[index])
	end })
	previous.Position = UDim2.fromOffset(16, 304)
	previous.Selectable = true
	previous.SelectionOrder = 30
	previous.ZIndex = 144
	previous.Parent = body
	local formationValue = label(body, tostring(self.Manager.CurrentFormation), UDim2.fromOffset(66, 304), UDim2.new(1, -132, 0, 40), 15, Theme.Colors.White, Theme.Fonts.Display)
	formationValue.BackgroundColor3 = Theme.Colors.Gunmetal
	formationValue.BackgroundTransparency = 0
	formationValue.TextXAlignment = Enum.TextXAlignment.Center
	corner(formationValue)
	self.FormationValue = formationValue
	local nextButton = Button.new({ Text = ">", Variant = "Secondary", Size = UDim2.fromOffset(44, 40), OnActivated = function()
		local current = table.find(Config.Manager.Formations, tostring(self.Manager.CurrentFormation)) or 1
		request("Formation", Config.Manager.Formations[current % #Config.Manager.Formations + 1])
	end })
	nextButton.Position = UDim2.new(1, -60, 0, 304)
	nextButton.Selectable = true
	nextButton.SelectionOrder = 31
	nextButton.ZIndex = 144
	nextButton.Parent = body

	local halftime = Button.new({ Text = "HALF-TIME INSTRUCTION", Variant = "Secondary", Size = UDim2.new(1, -32, 0, 42), OnActivated = function()
		request("HalftimeInstruction", tostring(self.Manager.CurrentMentality or "Balanced"))
	end })
	halftime.Position = UDim2.fromOffset(16, 360)
	halftime.Selectable = false
	halftime.SelectionOrder = 40
	halftime.ZIndex = 144
	halftime.Parent = body
	self.HalftimeButton = halftime

	local substitutions = Button.new({ Text = "SUBSTITUTIONS", Variant = "Primary", Size = UDim2.new(1, -32, 0, 44), OnActivated = function()
		if self.Options.OnSubstitutions then self.Options.OnSubstitutions() end
	end })
	substitutions.Position = UDim2.fromOffset(16, 412)
	substitutions.Selectable = true
	substitutions.SelectionOrder = 41
	substitutions.ZIndex = 144
	substitutions.Parent = body
	self.SubstitutionsButton = substitutions

	previous.NextSelectionRight = nextButton
	nextButton.NextSelectionLeft = previous
	previous.NextSelectionDown = halftime
	nextButton.NextSelectionDown = halftime
	halftime.NextSelectionUp = previous
	halftime.NextSelectionDown = substitutions
	substitutions.NextSelectionUp = halftime

	local function resize()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		if viewport.X < 720 then
			root.AnchorPoint = Vector2.new(0.5, 1)
			root.Position = UDim2.new(0.5, 0, 1, -12)
			root.Size = UDim2.new(1, -24, 0, math.min(330, math.max(270, viewport.Y * 0.48)))
		else
			root.AnchorPoint = Vector2.new(1, 0.5)
			root.Position = UDim2.new(1, -18, 0.5, 20)
			root.Size = UDim2.fromOffset(344, math.min(500, math.max(390, viewport.Y - 150)))
		end
	end
	local camera = workspace.CurrentCamera
	if camera then table.insert(self.Connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)) end
	self.Root = root
	resize()
	self:Update(self.Manager, options.Objective)
	task.defer(function()
		local first = self.MentalityButtons[tostring(self.Manager.CurrentMentality)] or self.MentalityButtons.Balanced
		if first and first.Parent and GuiService.SelectedObject == nil and options.SelectOnOpen == true then GuiService.SelectedObject = first end
	end)
	return self
end

function ManagerPanel:SetHalf(half: number)
	self.Half = math.max(1, math.floor(tonumber(half) or 1))
	self:Update(self.Manager, nil)
end

function ManagerPanel:Update(manager: any, objective: any?)
	if type(manager) == "table" then self.Manager = manager end
	if objective ~= nil and self.Objective then self.Objective.Text = tostring(objective) end
	local total = math.max(0, math.floor(tonumber(self.Manager.Total) or 0))
	local required = math.max(1, math.floor(tonumber(Config.Manager.RequiredInteractions) or 2))
	ProgressBar.set(self.Progress, total / required, workspace:GetAttribute("VTRReducedMotion") ~= true)
	self.ProgressValue.Text = tostring(math.min(total, required)) .. " / " .. tostring(required)
	local afterHalf = self.Manager.AfterHalf == true or (tonumber(self.Manager.SecondHalfInteractions) or 0) > 0
	self.HalfRequirement.Text = afterHalf and "SECOND-HALF CHANGE COMPLETE" or "SECOND-HALF CHANGE REQUIRED"
	self.HalfRequirement.TextColor3 = afterHalf and Theme.Colors.Electric or Theme.Colors.Warning
	for mentality, button in self.MentalityButtons do Button.setPrimary(button, mentality == tostring(self.Manager.CurrentMentality)) end
	self.FormationValue.Text = tostring(self.Manager.CurrentFormation or "4-3-3")
	local halftimeAvailable = self.Half >= 2 and self.Manager.HalftimeInstructionApplied ~= true
	enabled(self.HalftimeButton, halftimeAvailable)
	self.HalftimeButton.Text = self.Manager.HalftimeInstructionApplied == true and "HALF-TIME INSTRUCTION APPLIED" or self.Half < 2 and "AVAILABLE AT HALF-TIME" or "APPLY HALF-TIME INSTRUCTION"
	if total >= required and afterHalf then
		self.ProgressTitle.Text = "FULL MANAGER ELIGIBILITY"
		self.ProgressTitle.TextColor3 = Theme.Colors.Electric
	else
		self.ProgressTitle.Text = "ACTIVE MANAGEMENT"
		self.ProgressTitle.TextColor3 = Theme.Colors.Muted
	end
end

function ManagerPanel:Destroy()
	for _, connection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
	if self.Root then self.Root:Destroy() end
end

return ManagerPanel
