--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local CardSurface = require(script.Parent.CardSurface)
local AvatarPortraitGenerator = require(script.Parent.Parent.Services.PlayerPortraitService)

local CompactPlayerCard = {}

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

function CompactPlayerCard.new(props: any): TextButton
	local card = props.Card
	local horizontal = props.Horizontal == true
	local root = Instance.new("TextButton")
	root.Name = "CardRoot"
	root.AutoButtonColor = false
	root.Text = ""
	root.Size = props.Size or (horizontal and UDim2.fromOffset(150, 68) or UDim2.fromOffset(76, 94))
	root.ZIndex = props.ZIndex or 1
	root.Selectable = false
	root.Parent = props.Parent
	local visual = CardSurface.apply(root, card.Rarity or card.rarity, card.CardType or card.cardType, 7)

	if horizontal then
		local portrait = AvatarPortraitGenerator.new(root, card, UDim2.fromOffset(38, 38), false)
		portrait.Position = UDim2.fromOffset(7, 16)
		portrait.ZIndex = root.ZIndex + 3
		label(root, tostring(card.Rating or card.overall), UDim2.fromOffset(51, 5), UDim2.fromOffset(30, 18), 12, Theme.Colors.White, Theme.Fonts.Display)
		local position = label(root, card.Position or card.bestPosition, UDim2.new(1, -42, 0, 6), UDim2.fromOffset(34, 16), 8, visual.trimColor, Theme.Fonts.Strong)
		position.TextXAlignment = Enum.TextXAlignment.Right
		local shortName = string.match(card.Name or card.displayName, "([^%s]+)$") or (card.Name or card.displayName)
		local name = label(root, shortName, UDim2.fromOffset(51, 25), UDim2.new(1, -58, 0, 17), 9, Theme.Colors.White, Theme.Fonts.Strong)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		label(root, string.upper(card.Rarity or card.rarity or "COMMON") .. " / " .. string.upper(card.CardType or card.cardType or "BASE"), UDim2.fromOffset(51, 43), UDim2.new(1, -58, 0, 13), 6, visual.trimColor, Theme.Fonts.Strong).TextTruncate = Enum.TextTruncate.AtEnd
	else
		local portrait = AvatarPortraitGenerator.new(root, card, UDim2.new(1, -14, 0, 44), false)
		portrait.Position = UDim2.fromOffset(7, 20)
		portrait.ZIndex = root.ZIndex + 3
		label(root, tostring(card.Rating or card.overall), UDim2.fromOffset(6, 2), UDim2.fromOffset(28, 17), 11, Theme.Colors.White, Theme.Fonts.Display)
		local position = label(root, card.Position or card.bestPosition, UDim2.new(1, -34, 0, 3), UDim2.fromOffset(28, 16), 8, visual.trimColor, Theme.Fonts.Strong)
		position.TextXAlignment = Enum.TextXAlignment.Right
		local name = label(root, card.Name or card.displayName, UDim2.fromOffset(4, 65), UDim2.new(1, -8, 0, 13), 7, Theme.Colors.White, Theme.Fonts.Strong)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local stats = card.MainStats or card.mainStats
		if stats then
			local details = card.DetailedStats or card.detailedStats or card
			local isGoalkeeper = string.upper(tostring(card.Position or card.bestPosition or "")) == "GK"
			local statLine = if isGoalkeeper
				then string.format(
					"%02d %02d %02d %02d %02d",
					details.gkDiving or details.GKDiving or 0,
					details.gkHandling or details.GKHandling or 0,
					details.gkKicking or details.GKKicking or 0,
					details.gkPositioning or details.GKPositioning or 0,
					details.gkReflexes or details.GKReflexes or 0
				)
				else string.format("%02d %02d %02d  %02d %02d %02d", stats.PAC or 0, stats.SHO or 0, stats.PAS or 0, stats.DRI or 0, stats.DEF or 0, stats.PHY or 0)
			local statLabel = label(root, statLine, UDim2.fromOffset(3, 78), UDim2.new(1, -6, 0, 9), 5, Theme.Colors.Silver, Enum.Font.Code)
			statLabel.TextXAlignment = Enum.TextXAlignment.Center
		end
	end

	local meta = props.Meta or card.Meta or {}
	if meta.LoanMatchesRemaining then label(root,"LOAN "..meta.LoanMatchesRemaining,UDim2.new(0,4,1,-18),UDim2.fromOffset(horizontal and 48 or 42,12),6,Theme.Colors.Warning,Theme.Fonts.Strong)end
	if meta.Favorite then label(root, utf8.char(9733), UDim2.fromOffset(3, horizontal and 2 or 49), UDim2.fromOffset(14, 14), 8, Theme.Colors.Warning, Theme.Fonts.Strong) end
	if meta.Locked then label(root, "L", UDim2.fromOffset(horizontal and 35 or 4, horizontal and 2 or 49), UDim2.fromOffset(14, 14), 6, Theme.Colors.White, Theme.Fonts.Strong) end
	if props.Selected then
		local check = label(root, utf8.char(10003), UDim2.new(1, -20, 1, -20), UDim2.fromOffset(16, 16), 9, Theme.Colors.Black, Theme.Fonts.Strong)
		check.BackgroundColor3 = Theme.Colors.White
		check.BackgroundTransparency = 0
		check.TextXAlignment = Enum.TextXAlignment.Center
		check.TextYAlignment = Enum.TextYAlignment.Center
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = check
	end
	if props.ChemistryColor then
		local line = Instance.new("Frame")
		line.BackgroundColor3 = props.ChemistryColor
		line.BorderSizePixel = 0
		line.Position = UDim2.new(0, 9, 1, -4)
		line.Size = UDim2.new(1, -18, 0, 2)
		line.ZIndex = root.ZIndex + 6
		line.Parent = root
	end
	return root
end

return CompactPlayerCard
