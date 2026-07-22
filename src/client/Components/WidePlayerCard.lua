--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local CardSurface = require(script.Parent.CardSurface)
local AvatarPortraitGenerator = require(script.Parent.Parent.Services.PlayerPortraitService)

local WidePlayerCard = {}

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
	item.ZIndex = (parent :: GuiObject).ZIndex + 5
	item.Parent = parent
	return item
end

function WidePlayerCard.new(props: any): TextButton
	local card = props.Card
	local root = Instance.new("TextButton")
	root.Name = "WideCard_" .. tostring(card.cardInstanceId or card.Id or card.playerId)
	root.AutoButtonColor = false
	root.Text = ""
	root.Size = props.Size or UDim2.fromOffset(390, 112)
	root.ZIndex = props.ZIndex or ((props.Parent:IsA("GuiObject") and (props.Parent :: GuiObject).ZIndex or 1) + 1)
	root.Selectable = false
	root.Parent = props.Parent
	local visual = CardSurface.apply(root, card.Rarity or card.rarity, card.CardType or card.cardType, 9)
	CardSurface.decorateAscension(root, card, "Wide")

	local portrait = AvatarPortraitGenerator.new(root, card, UDim2.fromOffset(82, 92), false)
	portrait.Position = UDim2.fromOffset(8, 10)
	portrait.ZIndex = root.ZIndex + 3
	portrait.BackgroundTransparency = 1
	label(root, tostring(card.Rating or card.overall), UDim2.fromOffset(98, 9), UDim2.fromOffset(36, 25), 20, Theme.Colors.White, Theme.Fonts.Display)
	label(root, card.Position or card.bestPosition, UDim2.fromOffset(101, 36), UDim2.fromOffset(32, 18), 9, visual.trimColor, Theme.Fonts.Strong)
	local name = label(root, card.Name or card.displayName, UDim2.fromOffset(140, 10), UDim2.new(1, -292, 0, 24), 13, Theme.Colors.White, Theme.Fonts.Display)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local club = card.Club or card.fictionalClub or "VTR FREE AGENT"
	local nation = card.Nation or card.nationality or "VTR REGION"
	label(root, club, UDim2.fromOffset(140, 37), UDim2.new(1, -292, 0, 15), 7, Theme.Colors.Silver, Theme.Fonts.Strong).TextTruncate = Enum.TextTruncate.AtEnd
	label(root, nation, UDim2.fromOffset(140, 54), UDim2.new(1, -292, 0, 15), 7, Theme.Colors.Muted, Theme.Fonts.Strong).TextTruncate = Enum.TextTruncate.AtEnd
	label(root, string.upper(card.Rarity or card.rarity or "COMMON"), UDim2.fromOffset(140, 78), UDim2.fromOffset(70, 16), 7, visual.trimColor, Theme.Fonts.Strong)
	label(root, string.upper(card.CardType or card.cardType or "BASE"), UDim2.fromOffset(210, 78), UDim2.fromOffset(82, 16), 7, Theme.Colors.White, Theme.Fonts.Strong).TextTruncate = Enum.TextTruncate.AtEnd

	local stats = card.MainStats or card.mainStats or { PAC = 0, SHO = 0, PAS = 0, DRI = 0, DEF = 0, PHY = 0 }
	local details = card.DetailedStats or card.detailedStats or card
	local isGoalkeeper = string.upper(tostring(card.Position or card.bestPosition or "")) == "GK"
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = UDim2.new(1, -142, 0, 9)
	holder.Size = UDim2.fromOffset(132, 94)
	holder.ZIndex = root.ZIndex + 4
	holder.Parent = root
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(42, 42)
	grid.CellPadding = UDim2.fromOffset(2, 4)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.Parent = holder
	local displayStats = isGoalkeeper and {
		{Key="gkDiving", Label="DIV", Value=details.gkDiving or details.GKDiving or 0},
		{Key="gkHandling", Label="HAN", Value=details.gkHandling or details.GKHandling or 0},
		{Key="gkKicking", Label="KIC", Value=details.gkKicking or details.GKKicking or 0},
		{Key="gkPositioning", Label="POS", Value=details.gkPositioning or details.GKPositioning or 0},
		{Key="gkReflexes", Label="REF", Value=details.gkReflexes or details.GKReflexes or 0},
	} or {
		{Key="PAC", Label="PAC", Value=stats.PAC or 0},
		{Key="SHO", Label="SHO", Value=stats.SHO or 0},
		{Key="PAS", Label="PAS", Value=stats.PAS or 0},
		{Key="DRI", Label="DRI", Value=stats.DRI or 0},
		{Key="DEF", Label="DEF", Value=stats.DEF or 0},
		{Key="PHY", Label="PHY", Value=stats.PHY or 0},
	}
	for _, item in displayStats do
		local stat = Instance.new("Frame")
		stat.BackgroundTransparency = 1
		stat.ZIndex = root.ZIndex + 5
		stat.Parent = holder
		local value = label(stat, tostring(item.Value or 0), UDim2.new(), UDim2.new(1, 0, 0, 23), 13, visual.glowColor, Theme.Fonts.Display)
		value.TextXAlignment = Enum.TextXAlignment.Center
		local keyLabel = label(stat, item.Label, UDim2.fromOffset(0, 23), UDim2.new(1, 0, 0, 12), 6, Theme.Colors.Muted, Theme.Fonts.Strong)
		keyLabel.TextXAlignment = Enum.TextXAlignment.Center
	end
	local meta = props.Meta or card.Meta or {}
	if meta.LoanMatchesRemaining then label(root,"LOAN  "..meta.LoanMatchesRemaining.." MATCHES",UDim2.fromOffset(210,78),UDim2.fromOffset(100,16),7,Theme.Colors.Warning,Theme.Fonts.Strong)end
	if meta.Favorite then label(root, utf8.char(9733), UDim2.fromOffset(97, 61), UDim2.fromOffset(18, 18), 10, Theme.Colors.Warning, Theme.Fonts.Strong) end
	if meta.Locked then label(root, "LOCK", UDim2.fromOffset(98, 83), UDim2.fromOffset(38, 14), 6, Theme.Colors.Electric, Theme.Fonts.Strong) end
	if props.Selected then
		local selected = label(root, utf8.char(10003), UDim2.new(1, -28, 0, 5), UDim2.fromOffset(18, 18), 10, Theme.Colors.Black, Theme.Fonts.Strong)
		selected.BackgroundColor3 = Theme.Colors.Electric; selected.BackgroundTransparency = 0; selected.TextXAlignment = Enum.TextXAlignment.Center; selected.TextYAlignment = Enum.TextYAlignment.Center
		local selectedCorner = Instance.new("UICorner"); selectedCorner.CornerRadius = UDim.new(1, 0); selectedCorner.Parent = selected
	end
	if props.OnActivated then root.Activated:Connect(props.OnActivated) end
	return root
end

return WidePlayerCard
