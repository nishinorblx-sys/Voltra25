--!strict
local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local CardVisualConfig = require(ReplicatedStorage.VTR.Shared.CardVisualConfig)
local WorldCupConfig = require(ReplicatedStorage.VTR.Shared.WorldCupConfig)
local CardSurface = require(script.Parent.CardSurface)
local WidePlayerCard = require(script.Parent.WidePlayerCard)
local Button = require(script.Parent.Button)
local Panel = require(script.Parent.Panel)
local AvatarPortraitGenerator = require(script.Parent.Parent.Services.PlayerPortraitService)

local PackOpeningSequence = {}

local rarityRank = {
	Starter = 1,
	Common = 2,
	Bronze = 3,
	Silver = 4,
	Gold = 5,
	Rare = 6,
	Elite = 7,
	Legendary = 8,
	Icon = 9,
	Mythic = 10,
}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function label(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font, z: number?): TextLabel
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
	item.TextWrapped = true
	item.ZIndex = z or 113
	item.Parent = parent
	return item
end

local function tweenWait(instance: Instance, info: TweenInfo, goal: any)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	tween.Completed:Wait()
end

local function sound(parent: Instance, name: string): Sound
	local item = Instance.new("Sound")
	item.Name = name
	item.SoundId = ""
	item.Volume = 0.55
	item.Parent = parent
	return item
end

local function playPlaceholder(item: Sound)
	if item.SoundId ~= "" then item:Play() end
end

local function sortedReveals(reveals: any): { any }
	local result = {}
	for _, card in reveals or {} do table.insert(result, card) end
	table.sort(result, function(a, b)
		local ar = a.Rating or a.overall or 0
		local br = b.Rating or b.overall or 0
		if ar == br then
			return (rarityRank[a.Rarity or a.rarity] or 0) > (rarityRank[b.Rarity or b.rarity] or 0)
		end
		return ar > br
	end)
	return result
end

local function stadium(parent: Instance)
	local vignette = Instance.new("Frame")
	vignette.BackgroundColor3 = Color3.fromHex("020302")
	vignette.BorderSizePixel = 0
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.ZIndex = 101
	vignette.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromHex("071006"), Color3.fromHex("010201"))
	gradient.Rotation = 90
	gradient.Parent = vignette
	for index = 1, 5 do
		local stand = Instance.new("Frame")
		stand.BackgroundColor3 = index % 2 == 0 and Color3.fromHex("101510") or Color3.fromHex("080B08")
		stand.BackgroundTransparency = 0.2
		stand.BorderSizePixel = 0
		stand.Position = UDim2.fromScale(0, 0.57 + (index - 1) * 0.055)
		stand.Size = UDim2.fromScale(1, 0.056)
		stand.ZIndex = 102
		stand.Parent = parent
	end
	for _, x in { 0.08, 0.23, 0.77, 0.92 } do
		local light = Instance.new("Frame")
		light.AnchorPoint = Vector2.new(0.5, 0)
		light.BackgroundColor3 = Theme.Colors.White
		light.BackgroundTransparency = 0.82
		light.BorderSizePixel = 0
		light.Position = UDim2.fromScale(x, 0.05)
		light.Rotation = x < 0.5 and 16 or -16
		light.Size = UDim2.fromScale(0.018, 0.46)
		light.ZIndex = 102
		light.Parent = parent
		local beam = Instance.new("UIGradient")
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = light
	end
	local pitch = Instance.new("Frame")
	pitch.BackgroundColor3 = Color3.fromHex("101C0C")
	pitch.BackgroundTransparency = 0.32
	pitch.BorderSizePixel = 0
	pitch.Position = UDim2.fromScale(0, 0.82)
	pitch.Size = UDim2.fromScale(1, 0.18)
	pitch.ZIndex = 102
	pitch.Parent = parent
end

local function showResults(overlay: CanvasGroup, title: string, reveals: { any }, props: any)
	for _, child in overlay:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.05
	local panel = Panel.new({ Name = "PackContents", Size = UDim2.fromOffset(970, 590), ClipsDescendants = true })
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.ZIndex = 106
	panel.Parent = overlay
	label(panel, string.upper(title) .. "  /  PACK CONTENTS", UDim2.fromOffset(26, 14), UDim2.new(1, -52, 0, 38), 23, Theme.Colors.White, Theme.Fonts.Display, 108)
	label(panel, "HIGHEST RATED FIRST  •  ALL ITEMS ARE NOW SECURED IN YOUR CLUB", UDim2.fromOffset(26, 51), UDim2.new(1, -52, 0, 20), 8, Theme.Colors.Electric, Theme.Fonts.Strong, 108)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(26, 84)
	list.Size = UDim2.new(1, -52, 1, -158)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = Theme.Colors.Electric
	list.ZIndex = 107
	list.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -7, 0, 112)
	grid.CellPadding = UDim2.fromOffset(12, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	local resultNodes = {}
	local renderLimit = math.min(#reveals, 24)
	for index = 1, renderLimit do
		local card = reveals[index]
		local wrapper = Instance.new("CanvasGroup")
		wrapper.Name = "Result_" .. index
		wrapper.BackgroundTransparency = 1
		wrapper.Size = UDim2.new(1, 0, 1, 0)
		wrapper.LayoutOrder = index
		wrapper.ZIndex = 108
		wrapper.Parent = list
		WidePlayerCard.new({
			Parent = wrapper,
			Card = card,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 108,
			OnActivated = function()
				if props.OnViewPlayer then props.OnViewPlayer(card.cardInstanceId or card.Id) end
			end,
		})
		table.insert(resultNodes, wrapper)
	end
	if #reveals > renderLimit then
		label(panel, "+" .. (#reveals - renderLimit) .. " MORE CARDS SECURED IN PLAYERS", UDim2.fromOffset(430, 542), UDim2.fromOffset(230, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong, 108)
	end
	local secured = false
	local function secure(animated: boolean)
		if secured then return end
		secured = true
		for index, node in resultNodes do
			if animated then
				task.delay((index - 1) * 0.025, function()
					if node.Parent then
						TweenService:Create(node, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							GroupTransparency = 1,
							Position = UDim2.fromOffset(0, -12),
						}):Play()
						task.delay(0.2, function()
							if node.Parent then node:Destroy() end
						end)
					end
				end)
			else
				node:Destroy()
			end
		end
		if props.Toast then props.Toast("All pack items sent to your Club.", "Reward") end
	end
	local send = Button.new({ Text = "SEND ALL TO CLUB", Variant = "Primary", Size = UDim2.fromOffset(180, 40), OnActivated = function() secure(true) end })
	send.Position = UDim2.fromOffset(26, 536)
	send.ZIndex = 108
	send.Parent = panel
	local quick = Button.new({ Text = "QUICK SELL DUPLICATES", Variant = "Secondary", Size = UDim2.fromOffset(205, 40), OnActivated = function()
		if props.Toast then props.Toast("Duplicate quick sell is coming soon.", "Info") end
	end })
	quick.Position = UDim2.fromOffset(214, 536)
	quick.ZIndex = 108
	quick.Parent = panel
	local view = Button.new({ Text = "VIEW BEST PLAYER", Variant = "Secondary", Size = UDim2.fromOffset(180, 40), OnActivated = function()
		local best = reveals[1]
		if best and props.OnViewPlayer then props.OnViewPlayer(best.cardInstanceId or best.Id) end
	end })
	view.Position = UDim2.new(1, -388, 0, 536)
	view.ZIndex = 108
	view.Parent = panel
	local continue = Button.new({ Text = "CONTINUE", Variant = "Primary", Size = UDim2.fromOffset(170, 40), OnActivated = function()
		secure(false)
		overlay:Destroy()
		if props.OnComplete then props.OnComplete() end
	end })
	continue.Position = UDim2.new(1, -196, 0, 536)
	continue.ZIndex = 108
	continue.Parent = panel
end

function PackOpeningSequence.play(parent: Instance, props: any): CanvasGroup
	local previous = parent:FindFirstChild("PremiumPackOpening")
	if previous then previous:Destroy() end
	local reveals = sortedReveals(props.Reveals)
	local best = reveals[1]
	if not best then error("PackOpeningSequence requires at least one reveal") end
	local packRating = math.floor(tonumber(best.Rating or best.overall) or 0)

	local rarity = best.Rarity or best.rarity or "Starter"
	local cardType = best.CardType or best.cardType or "Base"
	local visual = CardVisualConfig.Get(rarity, cardType)
	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "PremiumPackOpening"
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 100
	overlay.Parent = parent

	stadium(overlay)
	local buildSound = sound(overlay, "EnergyBuildSound")
	local lightningSound = sound(overlay, "LightningPulseSound")
	local burstSound = sound(overlay, "PackBurstSound")
	local revealSound = sound(overlay, "PlayerRevealSound")
	label(overlay, "VTR 25  /  SEALED PACK", UDim2.fromScale(0.05, 0.055), UDim2.fromScale(0.9, 0.04), 9, Theme.Colors.Muted, Theme.Fonts.Strong, 112).TextXAlignment = Enum.TextXAlignment.Center
	local packRatingBanner = label(overlay, "PACK RATING  --", UDim2.fromScale(0.67, 0.105), UDim2.fromScale(0.26, 0.05), 18, Theme.Colors.White, Theme.Fonts.Display, 112)
	packRatingBanner.TextXAlignment = Enum.TextXAlignment.Right
	packRatingBanner.TextTransparency = .18
	local status = label(overlay, "INITIALIZING VOLTRA CHAMBER", UDim2.fromScale(0.25, 0.9), UDim2.fromScale(0.5, 0.04), 9, Theme.Colors.Electric, Theme.Fonts.Strong, 112)
	status.TextXAlignment = Enum.TextXAlignment.Center
	local vipBoost = false
	for _, card in reveals do
		if card.VTRVipPackBoost == true then vipBoost = true;break end
	end
	if vipBoost then
		local vip = Instance.new("Frame")
		vip.Name = "VIPPackBoostBanner"
		vip.AnchorPoint = Vector2.new(.5,0)
		vip.BackgroundColor3 = Color3.fromHex("1C1403")
		vip.BackgroundTransparency = .08
		vip.BorderSizePixel = 0
		vip.Position = UDim2.fromScale(.5,.13)
		vip.Size = UDim2.fromScale(.46,.07)
		vip.ZIndex = 116
		vip.Parent = overlay
		corner(vip,10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromHex("FFD43B")
		stroke.Thickness = 2
		stroke.Transparency = .1
		stroke.Parent = vip
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.fromHex("2E2108"), Color3.fromHex("050505"))
		gradient.Rotation = 0
		gradient.Parent = vip
		local vipText = label(vip, "VIP BOOST ACTIVE  /  +10% BETTER PACK ODDS", UDim2.fromScale(.05,.08), UDim2.fromScale(.9,.84), 15, Color3.fromHex("FFD43B"), Theme.Fonts.Display, 117)
		vipText.TextXAlignment = Enum.TextXAlignment.Center
	end

	local energy = Instance.new("Frame")
	energy.Name = "EnergyCore"
	energy.AnchorPoint = Vector2.new(0.5, 0.5)
	energy.BackgroundTransparency = 1
	energy.Position = UDim2.fromScale(0.5, 0.48)
	energy.Size = UDim2.fromOffset(360, 360)
	energy.ZIndex = 105
	energy.Parent = overlay
	corner(energy, 180)
	for index = 1, 3 do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.BackgroundTransparency = 1
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(0.58 + index * 0.13, 0.58 + index * 0.13)
		ring.ZIndex = 105
		ring.Parent = energy
		corner(ring, 180)
		local ringStroke = Instance.new("UIStroke")
		ringStroke.Color = visual.glowColor
		ringStroke.Thickness = 4 - index
		ringStroke.Transparency = 0.78
		ringStroke.Parent = ring
		local scale = Instance.new("UIScale")
		scale.Scale = 0.72
		scale.Parent = ring
		TweenService:Create(scale, TweenInfo.new(0.72 + index * 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, index * 0.08), { Scale = 1.08 }):Play()
	end
	for index = 1, 6 do
		local bolt = Instance.new("Frame")
		bolt.Name = "LightningBolt"
		bolt.AnchorPoint = Vector2.new(0.5, 0.5)
		bolt.BackgroundColor3 = visual.glowColor
		bolt.BackgroundTransparency = 1
		bolt.BorderSizePixel = 0
		bolt.Position = UDim2.fromScale(0.5, 0.5)
		bolt.Rotation = (index - 1) * 60 + 18
		bolt.Size = UDim2.fromOffset(3, 280)
		bolt.ZIndex = 106
		bolt.Parent = energy
	end

	local pack = Instance.new("CanvasGroup")
	pack.Name = "PackObject"
	pack.AnchorPoint = Vector2.new(0.5, 0.5)
	pack.Position = UDim2.fromScale(0.5, 0.48)
	pack.Size = UDim2.fromOffset(210, 286)
	pack.Rotation = -4
	pack.GroupTransparency = 1
	pack.ZIndex = 108
	pack.Parent = overlay
	CardSurface.apply(pack, rarity, cardType, 14)
	label(pack, "V\n25", UDim2.fromScale(0, 0.18), UDim2.fromScale(1, 0.4), 64, visual.glowColor, Theme.Fonts.Display, 111).TextXAlignment = Enum.TextXAlignment.Center
	local packName = label(pack, string.upper(props.Title or "VTR PLAYER PACK"), UDim2.fromScale(0.08, 0.69), UDim2.fromScale(0.84, 0.12), 10, Theme.Colors.White, Theme.Fonts.Strong, 111)
	packName.TextXAlignment = Enum.TextXAlignment.Center
	local packScale = Instance.new("UIScale")
	packScale.Scale = 0.58
	packScale.Parent = pack
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = visual.glowColor
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 120
	flash.Parent = overlay

	task.spawn(function()
		local ok, problem = pcall(function()
			tweenWait(overlay, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })
			playPlaceholder(buildSound)
			status.Text = "NEON ENERGY BUILDING"
			packRatingBanner.Text = "PACK RATING  " .. tostring(packRating) .. " OVR"
			TweenService:Create(pack, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { GroupTransparency = 0, Rotation = 0 }):Play()
			tweenWait(packScale, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			task.wait(0.35)
			status.Text = "PACK SIGNATURE LOCKED"
			tweenWait(packRatingBanner, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0 })
			for index = 1, 7 do
				local direction = index % 2 == 0 and 1 or -1
				tweenWait(pack, TweenInfo.new(0.055, Enum.EasingStyle.Linear), { Rotation = direction * (1.2 + index * 0.18), Position = UDim2.new(0.5, direction * 2, 0.48, 0) })
			end
			TweenService:Create(pack, TweenInfo.new(0.12), { Rotation = 0, Position = UDim2.fromScale(0.5, 0.48) }):Play()
			playPlaceholder(lightningSound)
			status.Text = "LIGHTNING PULSE"
			for _, bolt in energy:GetChildren() do
				if bolt.Name == "LightningBolt" then
					TweenService:Create(bolt, TweenInfo.new(0.1), { BackgroundTransparency = 0.12 }):Play()
					task.delay(0.13, function()
						if bolt.Parent then TweenService:Create(bolt, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play() end
					end)
				end
			end
			tweenWait(flash, TweenInfo.new(0.1), { BackgroundTransparency = 0.18 })
			TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.2)
			playPlaceholder(burstSound)
			status.Text = "PACK OPEN"
			TweenService:Create(packScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 1.5 }):Play()
			tweenWait(pack, TweenInfo.new(0.28), { GroupTransparency = 1, Rotation = 9 })
			energy.Visible = false

			local hero = Instance.new("CanvasGroup")
			hero.Name = "WalkoutReveal"
			hero.AnchorPoint = Vector2.new(0.5, 0.5)
			hero.Position = UDim2.fromScale(0.5, 0.5)
			hero.Size = UDim2.fromOffset(760, 430)
			hero.GroupTransparency = 1
			hero.ZIndex = 110
			hero.Parent = overlay
			CardSurface.apply(hero, rarity, cardType, 16)
			local brightWash = Instance.new("Frame")
			brightWash.BackgroundColor3 = Theme.Colors.White
			brightWash.BackgroundTransparency = 0.97
			brightWash.BorderSizePixel = 0
			brightWash.Size = UDim2.fromScale(1, 1)
			brightWash.ZIndex = 111
			brightWash.Parent = hero
			corner(brightWash, 16)
			local kicker = label(hero, "HIGHEST RATED REVEAL", UDim2.fromOffset(28, 18), UDim2.new(1, -56, 0, 25), 13, visual.glowColor, Theme.Fonts.Display, 160)
			kicker.TextXAlignment = Enum.TextXAlignment.Center
			kicker.TextTransparency = 1
			local facts = Instance.new("Frame")
			facts.BackgroundTransparency = 1
			facts.Position = UDim2.fromOffset(34, 68)
			facts.Size = UDim2.fromOffset(320, 292)
			facts.ZIndex = 128
			facts.Parent = hero
			local factLayout = Instance.new("UIListLayout")
			factLayout.Padding = UDim.new(0, 8)
			factLayout.Parent = facts
			local factData = {
				{ "RARITY", string.upper(rarity), visual.trimColor },
				{ "POSITION", tostring(best.Position or best.bestPosition or "--"), Color3.fromHex("080A08") },
				{ "NATIONALITY", tostring(best.Nation or best.nationality or "VTR REGION"), Color3.fromHex("080A08") },
				{ "CLUB", tostring(best.Club or best.fictionalClub or "VTR FREE AGENT"), Color3.fromHex("080A08") },
			}
			local factRows = {}
			for _, fact in factData do
				local row = Instance.new("Frame")
				row.BackgroundColor3 = Color3.fromHex("FFF9FF")
				row.BackgroundTransparency = 1
				row.BorderSizePixel = 0
				row.Size = UDim2.new(1, 0, 0, 62)
				row.ZIndex = 150
				row.Parent = facts
				corner(row, 8)
				local rowStroke = Instance.new("UIStroke")
				rowStroke.Color = visual.glowColor
				rowStroke.Transparency = 0.28
				rowStroke.Thickness = 1.25
				rowStroke.Parent = row
				local caption = label(row, fact[1], UDim2.fromOffset(18, 8), UDim2.fromOffset(125, 18), 10, Color3.fromHex("51207F"), Theme.Fonts.Strong, 162)
				caption.TextTransparency = 1
				local value = label(row, tostring(fact[2] or "--"), UDim2.fromOffset(18, 26), UDim2.new(1, -36, 0, 28), 18, fact[3], Theme.Fonts.Display, 162)
				value.TextXAlignment = Enum.TextXAlignment.Right
				value.TextTruncate = Enum.TextTruncate.AtEnd
				value.TextTransparency = 1
				local flagImage: ImageLabel? = nil
				if fact[1] == "NATIONALITY" then
					local flagAsset = WorldCupConfig.Flag(tostring(fact[2] or ""))
					if flagAsset ~= "" then
						flagImage = Instance.new("ImageLabel")
						flagImage.BackgroundColor3 = Color3.fromHex("E8E4F2")
						flagImage.BackgroundTransparency = 0
						flagImage.BorderSizePixel = 0
						flagImage.Image = flagAsset
						flagImage.ImageTransparency = 1
						flagImage.Position = UDim2.fromOffset(18, 28)
						flagImage.ScaleType = Enum.ScaleType.Crop
						flagImage.Size = UDim2.fromOffset(40, 24)
						flagImage.ZIndex = 162
						flagImage.Parent = row
						corner(flagImage, 4)
						value.Position = UDim2.fromOffset(66, 26)
						value.Size = UDim2.new(1, -82, 0, 28)
						value.TextXAlignment = Enum.TextXAlignment.Left
					end
				end
				table.insert(factRows, {
					Row = row,
					Caption = caption,
					Value = value,
					Flag = flagImage,
				})
			end
			local divider = Instance.new("Frame")
			divider.BackgroundColor3 = visual.glowColor
			divider.BackgroundTransparency = 0.2
			divider.BorderSizePixel = 0
			divider.Position = UDim2.fromOffset(384, 72)
			divider.Size = UDim2.fromOffset(2, 290)
			divider.ZIndex = 127
			divider.Parent = hero
			local ovrText = label(hero, "OVR", UDim2.fromOffset(478, 54), UDim2.fromOffset(140, 28), 16, visual.glowColor, Theme.Fonts.Display, 160)
			ovrText.TextXAlignment = Enum.TextXAlignment.Center
			ovrText.TextTransparency = 1
			local rating = label(hero, tostring(best.Rating or best.overall or "--"), UDim2.fromOffset(440, 80), UDim2.fromOffset(220, 92), 76, Theme.Colors.White, Theme.Fonts.Display, 160)
			rating.TextXAlignment = Enum.TextXAlignment.Center
			rating.TextTransparency = 1
			local ratingStroke = Instance.new("UIStroke")
			ratingStroke.Color = visual.glowColor
			ratingStroke.Thickness = 3
			ratingStroke.Transparency = 0.16
			ratingStroke.Parent = rating
			local portraitFrame = Instance.new("CanvasGroup")
			portraitFrame.Name = "PlayerRevealFrame"
			portraitFrame.BackgroundColor3 = Color3.fromHex("F6F1FF")
			portraitFrame.BackgroundTransparency = 0.1
			portraitFrame.Position = UDim2.fromOffset(430, 170)
			portraitFrame.Size = UDim2.fromOffset(260, 172)
			portraitFrame.GroupTransparency = 1
			portraitFrame.ZIndex = 113
			portraitFrame.Parent = hero
			corner(portraitFrame, 14)
			local portraitStroke = Instance.new("UIStroke")
			portraitStroke.Color = visual.glowColor
			portraitStroke.Thickness = 2
			portraitStroke.Transparency = 0.12
			portraitStroke.Parent = portraitFrame
			local portraitGlow = Instance.new("Frame")
			portraitGlow.BackgroundColor3 = visual.glowColor
			portraitGlow.BackgroundTransparency = 0.82
			portraitGlow.BorderSizePixel = 0
			portraitGlow.Position = UDim2.fromScale(0, 0.63)
			portraitGlow.Size = UDim2.fromScale(1, 0.22)
			portraitGlow.ZIndex = 113
			portraitGlow.Parent = portraitFrame
			local portrait = AvatarPortraitGenerator.new(portraitFrame, best, UDim2.fromScale(0.96, 0.96), false)
			portrait.Position = UDim2.fromScale(0.02, 0.02)
			portrait.ZIndex = 116
			portrait.Visible = false
			local playerName = label(hero, tostring(best.Name or best.displayName or "VTR PLAYER"), UDim2.fromOffset(402, 352), UDim2.fromOffset(318, 46), 22, Theme.Colors.White, Theme.Fonts.Display, 160)
			playerName.TextXAlignment = Enum.TextXAlignment.Center
			playerName.TextTransparency = 1
			tweenWait(hero, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { GroupTransparency = 0 })
			TweenService:Create(kicker, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
			for index, item in factRows do
				status.Text = ({ "RARITY DETECTED", "POSITION LOCKED", "NATIONALITY CONFIRMED", "CLUB SIGNAL FOUND" })[index]
				playPlaceholder(revealSound)
				TweenService:Create(item.Caption, TweenInfo.new(0.14), { TextTransparency = 0 }):Play()
				TweenService:Create(item.Value, TweenInfo.new(0.14), { TextTransparency = 0 }):Play()
				if item.Flag then
					TweenService:Create(item.Flag, TweenInfo.new(0.14), { ImageTransparency = 0 }):Play()
				end
				tweenWait(item.Row, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.02 })
				task.wait(0.11)
			end
			status.Text = "RATING VERIFIED"
			packRatingBanner.Text = "PACK RATING  " .. tostring(packRating) .. " OVR"
			playPlaceholder(revealSound)
			TweenService:Create(ovrText, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
			tweenWait(rating, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0 })
			task.wait(0.22)
			status.Text = "PLAYER REVEALED"
			portrait.Visible = true
			TweenService:Create(portraitFrame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
			TweenService:Create(playerName, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
			local portraitScale = Instance.new("UIScale")
			portraitScale.Scale = 0.74
			portraitScale.Parent = portrait
			tweenWait(portraitScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			task.wait(1.2)
			tweenWait(hero, TweenInfo.new(0.25), { GroupTransparency = 1 })
			if overlay.Parent then showResults(overlay, props.Title or "VTR PACK", reveals, props) end
		end)
		if not ok then
			warn("[VTR PACK OPENING] " .. tostring(problem))
			local fallbackOk, fallbackProblem = pcall(function()
				if overlay.Parent then showResults(overlay, props.Title or "VTR PACK", reveals, props) end
			end)
			if not fallbackOk then
				warn("[VTR PACK OPENING FALLBACK] " .. tostring(fallbackProblem))
				if overlay.Parent then overlay:Destroy() end
				if props.OnComplete then props.OnComplete() end
			end
		end
	end)
	return overlay
end

local function vtrFindRouletteGuiObjects(root)
	local scroller
	local container

	if typeof(root) ~= "Instance" then
		return nil, nil
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ScrollingFrame") then
			local n = string.lower(obj.Name)
			if string.find(n, "roulette") or string.find(n, "spin") or string.find(n, "reward") or string.find(n, "pack") then
				scroller = obj
				break
			end
			scroller = scroller or obj
		end
	end

	if scroller then
		for _, obj in ipairs(scroller:GetDescendants()) do
			if obj:IsA("GuiObject") then
				local hasPack = obj:GetAttribute("PackId") or obj:GetAttribute("PackName")
				local n = string.lower(obj.Name)
				if hasPack or string.find(n, "pack") or string.find(n, "card") or string.find(n, "item") then
					container = obj.Parent
					break
				end
			end
		end
	end

	return scroller, container
end

local function vtrForceRouletteWinningCenter(root, winningPack, winningIndex)
	if not winningPack then
		return
	end

	task.defer(function()
		local scroller, container = vtrFindRouletteGuiObjects(root)
		if scroller and container then
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
			task.wait(0.05)
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
		end
	end)
end

return PackOpeningSequence
