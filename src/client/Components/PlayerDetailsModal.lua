--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Button = require(script.Parent.Button)
local Panel = require(script.Parent.Panel)
local RadarChart = require(script.Parent.RadarChart)
local AvatarPortraitGenerator = require(script.Parent.Parent.Services.PlayerPortraitService)

local PlayerDetailsModal = {}

local GROUPS = {
	{ "PACE", { "sprintSpeed", "acceleration" } },
	{ "SHOOTING", { "finishing", "headingAccuracy", "volleys", "shotPower", "longShots", "penalties" } },
	{ "PASSING", { "crossing", "shortPassing", "curve", "fkAccuracy", "longPassing", "vision" } },
	{ "DRIBBLING", { "dribbling", "ballControl", "balance", "composure", "attackingPosition" } },
	{ "DEFENSE", { "defensiveAwareness", "standingTackle", "interceptions", "slidingTackle" } },
	{ "PHYSICAL", { "agility", "reactions", "jumping", "stamina", "strength", "aggression" } },
	{ "GOALKEEPING", { "gkDiving", "gkHandling", "gkKicking", "gkPositioning", "gkReflexes" } },
}
local MAIN_ORDER = { "PAC", "SHO", "PAS", "DRI", "DEF", "PHY" }
local GK_MAIN_ORDER = {
	{ Key = "gkDiving", Label = "DIV" },
	{ Key = "gkHandling", Label = "HAN" },
	{ Key = "gkKicking", Label = "KIC" },
	{ Key = "gkPositioning", Label = "POS" },
	{ Key = "gkReflexes", Label = "REF" },
}

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = text
	item.TextColor3 = color
	item.TextSize = textSize
	item.Font = font
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

local function statColor(value: number): Color3
	if value < 55 then return Color3.fromHex("E84A55") end
	if value < 70 then return Color3.fromHex("F08A3C") end
	if value < 82 then return Color3.fromHex("E9D94E") end
	return Color3.fromHex("59D66F")
end

local function compactMoney(value:any):string
	local amount=tonumber(value)or 0
	local absolute=math.abs(amount)
	if absolute>=1000000000 then return string.format("%.1f BIL",amount/1000000000):gsub("%.0 BIL"," BIL")end
	if absolute>=1000000 then return string.format("%.1f MIL",amount/1000000):gsub("%.0 MIL"," MIL")end
	if absolute>=1000 then return string.format("%.1f K",amount/1000):gsub("%.0 K"," K")end
	return tostring(math.floor(amount+.5))
end

local function readable(key: string): string
	return string.upper((key:gsub("(%l)(%u)", "%1 %2"):gsub("^gk ", "GK ")))
end

local function statGroup(parent: Instance, title: string, keys: { string }, stats: any, order: number)
	local group = Panel.new({ Name = title, Size = UDim2.new(0.5, -7, 0, 32 + #keys * 26) })
	group.LayoutOrder = order
	group.Parent = parent
	label(group, title, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 9, Theme.Colors.Electric, Theme.Fonts.Strong)
	for index, key in keys do
		local value = stats[key] or 0
		label(group, readable(key), UDim2.fromOffset(12, 27 + (index - 1) * 26), UDim2.new(1, -64, 0, 22), 8, Theme.Colors.Silver, Theme.Fonts.Body)
		local chip = label(group, tostring(value), UDim2.new(1, -48, 0, 27 + (index - 1) * 26), UDim2.fromOffset(36, 20), 9, Theme.Colors.Black, Theme.Fonts.Strong)
		chip.BackgroundColor3 = statColor(value)
		chip.BackgroundTransparency = 0
		chip.TextXAlignment = Enum.TextXAlignment.Center
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 4); corner.Parent = chip
	end
end

function PlayerDetailsModal.open(root: Frame, data: any)
	local existing = root:FindFirstChild("PlayerDetailsModal")
	if existing then
		existing:Destroy()
	end
	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "PlayerDetailsModal"
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.12
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 140
	overlay.Active = true
	overlay.Selectable = false
	overlay.Parent = root
	local shield=Instance.new("TextButton")
	shield.Name="PlayerDetailsInputShield"
	shield.BackgroundTransparency=1
	shield.BorderSizePixel=0
	shield.Size=UDim2.fromScale(1,1)
	shield.Text=""
	shield.AutoButtonColor=false
	shield.Selectable=false
	shield.Modal=true
	shield.Active=true
	shield.ZIndex=140
	shield.Parent=overlay

	local modal = Panel.new({ Name = "PlayerDetails", Size = UDim2.fromOffset(1040, 620), ClipsDescendants = false })
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.ZIndex = 141
	modal.Parent = overlay
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(1040, 620)
	constraint.MinSize = Vector2.new(760, 520)
	constraint.Parent = modal

	local function close()
		overlay:Destroy()
		GuiService.SelectedObject = nil
	end

	label(modal, "VTR PLAYER DATABASE  /  " .. string.upper(data.rarity), UDim2.fromOffset(24, 14), UDim2.new(1, -180, 0, 20), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	label(modal, data.displayName, UDim2.fromOffset(24, 34), UDim2.new(1, -180, 0, 38), 26, Theme.Colors.White, Theme.Fonts.Display)
	label(modal, data.nationality .. "  /  " .. data.fictionalClub .. "  /  " .. table.concat(data.positions, " "), UDim2.fromOffset(24, 70), UDim2.new(1, -180, 0, 22), 9, Theme.Colors.Silver, Theme.Fonts.Strong)
	local closeButton = Button.new({ Text = "CLOSE", Variant = "Secondary", Size = UDim2.fromOffset(120, 38), OnActivated = close })
	closeButton.Position = UDim2.new(1, -144, 0, 24)
	closeButton.ZIndex = 143
	closeButton.Parent = modal

	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromOffset(24, 104)
	left.Size = UDim2.fromOffset(300, 492)
	left.ZIndex = 142
	left.Parent = modal
	local portrait = AvatarPortraitGenerator.new(left, data, UDim2.fromOffset(300, 150), false)
	portrait.Position = UDim2.fromOffset(0, 0)
	label(left, data.overall .. " OVR", UDim2.fromOffset(16, 10), UDim2.fromOffset(100, 34), 22, Theme.Colors.White, Theme.Fonts.Display)
	label(left, data.potential .. " POT", UDim2.new(1, -116, 0, 10), UDim2.fromOffset(100, 34), 16, Theme.Colors.Electric, Theme.Fonts.Display).TextXAlignment = Enum.TextXAlignment.Right
	label(left, data.age .. " YEARS  /  " .. data.heightCm .. " CM  /  " .. data.weightKg .. " KG  /  " .. string.upper(data.preferredFoot), UDim2.fromOffset(0, 160), UDim2.new(1, 0, 0, 24), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	local radarFrame = RadarChart.new(left, data.mainStats, Vector2.new(240, 240))
	radarFrame.Position = UDim2.fromOffset(28, 184)
	label(left, "POSITION MAP  /  FUTURE TACTICAL VIEW", UDim2.fromOffset(0, 430), UDim2.new(1, 0, 0, 22), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	label(left, "BEST: " .. data.bestPosition .. "    WORK RATES: " .. data.workRates.Attack .. "/" .. data.workRates.Defense, UDim2.fromOffset(0, 452), UDim2.new(1, 0, 0, 22), 8, Theme.Colors.Silver, Theme.Fonts.Body)

	local right = Instance.new("ScrollingFrame")
	right.BackgroundTransparency = 1
	right.BorderSizePixel = 0
	right.Position = UDim2.fromOffset(342, 104)
	right.Size = UDim2.new(1, -366, 1, -128)
	right.AutomaticCanvasSize = Enum.AutomaticSize.Y
	right.CanvasSize = UDim2.new()
	right.ScrollBarThickness = 3
	right.ScrollBarImageColor3 = Theme.Colors.Electric
	right.ZIndex = 142
	right.Parent = modal
	local profileMeta = Instance.new("Frame")
	profileMeta.BackgroundTransparency = 1
	profileMeta.Size = UDim2.new(1, -8, 0, 48)
	profileMeta.LayoutOrder = 1
	profileMeta.Parent = right
	label(profileMeta, "VALUE  " .. compactMoney(data.value) .. "  /  WAGE  " .. compactMoney(data.wage) .. "  /  DOB  " .. data.birthDate .. "  /  " .. data.skillMoves .. "* SKILLS  /  " .. data.weakFoot .. "* WEAK FOOT", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 20), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
	label(profileMeta, "BODY  " .. string.upper(data.bodyType) .. "  /  ACCELERATION  " .. string.upper(data.accelerationType) .. "  /  STYLES  " .. table.concat(data.playStyles, ", "), UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 20), 8, Theme.Colors.Muted, Theme.Fonts.Body)
	local mainHolder = Instance.new("Frame")
	mainHolder.BackgroundTransparency = 1
	mainHolder.Size = UDim2.new(1, -8, 0, 62)
	mainHolder.LayoutOrder = 2
	mainHolder.Parent = right
	local mainLayout = Instance.new("UIGridLayout")
	local isGoalkeeper = string.upper(tostring(data.bestPosition or data.Position or "")) == "GK"
	mainLayout.CellSize = UDim2.new(1 / (isGoalkeeper and 5 or 6), -7, 0, 58)
	mainLayout.CellPadding = UDim2.fromOffset(7, 0)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.Parent = mainHolder
	if isGoalkeeper then
		for index, item in GK_MAIN_ORDER do
			local value = (data.detailedStats and data.detailedStats[item.Key]) or data[item.Key] or 0
			local chip = Panel.new({ Name = item.Label })
			chip.LayoutOrder = index
			chip.Parent = mainHolder
			label(chip, tostring(value), UDim2.fromOffset(0, 7), UDim2.new(1, 0, 0, 28), 19, statColor(value), Theme.Fonts.Display).TextXAlignment = Enum.TextXAlignment.Center
			label(chip, item.Label, UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong).TextXAlignment = Enum.TextXAlignment.Center
		end
	else
	for index, key in MAIN_ORDER do
		local value = data.mainStats[key]
		local chip = Panel.new({ Name = key })
		chip.LayoutOrder = index
		chip.Parent = mainHolder
		label(chip, tostring(value), UDim2.fromOffset(0, 7), UDim2.new(1, 0, 0, 28), 19, statColor(value), Theme.Fonts.Display).TextXAlignment = Enum.TextXAlignment.Center
		label(chip, key, UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong).TextXAlignment = Enum.TextXAlignment.Center
	end
	end
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -8, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.LayoutOrder = 3
	content.Parent = right
	local contentLayout = Instance.new("UIGridLayout")
	contentLayout.CellSize = UDim2.new(0.5, -7, 0, 190)
	contentLayout.CellPadding = UDim2.fromOffset(10, 10)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content
	for index, group in GROUPS do statGroup(content, group[1] :: string, group[2] :: { string }, data.detailedStats, index) end
	local rootLayout = Instance.new("UIListLayout")
	rootLayout.Padding = UDim.new(0, 12)
	rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rootLayout.Parent = right
	task.defer(function() GuiService.SelectedObject = nil end)
end

return PlayerDetailsModal
