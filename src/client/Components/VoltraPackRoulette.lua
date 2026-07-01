--!strict
local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").VTR.Shared.Theme)

local Presentation = {}

local PACKS = {
	{Name = "Voltra Spark Pack", Rarity = "Common", Color = Color3.fromHex("FFFFFF"), Accent = Color3.fromHex("050505"), Weight = 800},
	{Name = "Street Pulse Pack", Rarity = "Rare", Color = Color3.fromHex("1FA2FF"), Accent = Color3.fromHex("F5F7F2"), Weight = 90},
	{Name = "Neon Tactics Pack", Rarity = "Rare", Color = Color3.fromHex("24C6B8"), Accent = Color3.fromHex("050505"), Weight = 50},
	{Name = "Elite Matchday Pack", Rarity = "Epic", Color = Color3.fromHex("8E00D6"), Accent = Color3.fromHex("F5F7F2"), Weight = 35},
	{Name = "Voltra Vault Pack", Rarity = "Epic", Color = Color3.fromHex("FFCB45"), Accent = Color3.fromHex("111111"), Weight = 18},
	{Name = "Ranked Champion Pack", Rarity = "Mythic", Color = Color3.fromHex("FF477E"), Accent = Color3.fromHex("F5F7F2"), Weight = 6},
	{Name = "Icon Voltage Pack", Rarity = "Mythic", Color = Color3.fromHex("D9D9D9"), Accent = Color3.fromHex("7D2CFF"), Weight = 1},
}

local function weightedPack(): any
	local total = 0
	for _, pack in PACKS do
		total += pack.Weight or 1
	end
	local roll = math.random() * total
	local cursor = 0
	for _, pack in PACKS do
		cursor += pack.Weight or 1
		if roll <= cursor then return pack end
	end
	return PACKS[1]
end

local function label(parent: Instance, value: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, z: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = pos
	item.Size = size
	item.Text = value
	item.TextColor3 = color
	item.TextSize = textSize
	item.Font = Theme.Fonts.Display
	item.TextXAlignment = Enum.TextXAlignment.Center
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.ZIndex = z
	item.Parent = parent
	return item
end

local function corner(parent: Instance, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number)
	local value = Instance.new("UIStroke")
	value.Color = color
	value.Thickness = thickness
	value.Transparency = transparency
	value.Parent = parent
end

local function rewardPack(payload: any): any
	local reward = payload and payload.Reward or {}
	local ranked = payload and payload.RankedWinPack or {}
	local wanted = reward.PackName or reward.Pack or reward.packName or ranked.PackName
	if wanted then
		for _, pack in PACKS do
			if string.upper(pack.Name) == string.upper(tostring(wanted)) then return pack end
		end
		return {Name = tostring(wanted), Rarity = tostring(reward.Rarity or ranked.Rarity or "Common"), Color = Color3.fromHex("FFFFFF"), Accent = Color3.fromHex("050505"), Weight = 1}
	end
	return weightedPack()
end

local function makePackCard(parent: Instance, pack: any, size: UDim2, z: number): Frame
	local card = Instance.new("Frame")
	card.Size = size
	card.BackgroundColor3 = Color3.fromHex("080808")
	card.BorderSizePixel = 0
	card.ZIndex = z
	card.Parent = parent
	corner(card, 10)
	stroke(card, pack.Color, 2, .18)
	local glow = Instance.new("Frame")
	glow.Position = UDim2.fromScale(.08, .08)
	glow.Size = UDim2.fromScale(.84, .46)
	glow.BackgroundColor3 = pack.Color
	glow.BackgroundTransparency = .16
	glow.BorderSizePixel = 0
	glow.ZIndex = z + 1
	glow.Parent = card
	corner(glow, 12)
	local icon = label(glow, "V", UDim2.fromScale(0, .02), UDim2.fromScale(1, .76), 44, pack.Accent, z + 2)
	icon.TextTransparency = .06
	local shardA = Instance.new("Frame")
	shardA.AnchorPoint = Vector2.new(.5, .5)
	shardA.Position = UDim2.fromScale(.34, .47)
	shardA.Size = UDim2.fromScale(.18, .82)
	shardA.Rotation = -28
	shardA.BackgroundColor3 = pack.Accent
	shardA.BackgroundTransparency = .18
	shardA.BorderSizePixel = 0
	shardA.ZIndex = z + 2
	shardA.Parent = glow
	corner(shardA, 5)
	local shardB = shardA:Clone()
	shardB.Position = UDim2.fromScale(.66, .47)
	shardB.Rotation = 28
	shardB.Parent = glow
	local name = label(card, string.upper(pack.Name), UDim2.fromScale(.08, .58), UDim2.fromScale(.84, .16), 13, Theme.Colors.White, z + 2)
	name.TextWrapped = true
	local rarity = label(card, string.upper(pack.Rarity), UDim2.fromScale(.08, .78), UDim2.fromScale(.84, .08), 8, pack.Color, z + 2)
	local strip = Instance.new("Frame")
	strip.Position = UDim2.fromScale(0, .92)
	strip.Size = UDim2.fromScale(1, .08)
	strip.BackgroundColor3 = pack.Color
	strip.BorderSizePixel = 0
	strip.ZIndex = z + 1
	strip.Parent = card
	return card
end

function Presentation.Play(gui: ScreenGui, payload: any, onComplete: () -> ())
	if not gui or not gui.Parent then
		onComplete()
		return
	end
	local chosen = rewardPack(payload)
	local old = gui:FindFirstChild("VoltraPackRoulette")
	if old then old:Destroy() end
	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "VoltraPackRoulette"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = .02
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 1
	overlay.ZIndex = 520
	overlay.Active = true
	overlay.Parent = gui
	local blocker = Instance.new("TextButton")
	blocker.Name = "RouletteInputBlocker"
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.ZIndex = 521
	blocker.Active = true
	blocker.AutoButtonColor = false
	pcall(function() blocker.Modal = true end)
	blocker.Parent = overlay
	TweenService:Create(overlay, TweenInfo.new(.28), {GroupTransparency = 0}):Play()
	label(overlay, "YOU WON THE GAME", UDim2.fromScale(.12, .18), UDim2.fromScale(.76, .08), 42, Theme.Colors.White, 522)
	label(overlay, "RANKED VICTORY REWARD LOCKED", UDim2.fromScale(.18, .27), UDim2.fromScale(.64, .05), 13, Theme.Colors.White, 522)
	task.wait(1.35)
	if not overlay.Parent then return end
	label(overlay, "RANKED WIN REWARD", UDim2.fromScale(.18, .07), UDim2.fromScale(.64, .05), 13, Theme.Colors.White, 522)
	label(overlay, "VOLTRA PACK ROULETTE", UDim2.fromScale(.14, .12), UDim2.fromScale(.72, .08), 38, Theme.Colors.White, 522)
	local rail = Instance.new("Frame")
	rail.AnchorPoint = Vector2.new(.5, .5)
	rail.Position = UDim2.fromScale(.5, .43)
	rail.Size = UDim2.fromScale(.86, .26)
	rail.BackgroundColor3 = Color3.fromHex("080D07")
	rail.BackgroundTransparency = .04
	rail.BorderSizePixel = 0
	rail.ClipsDescendants = true
	rail.ZIndex = 522
	rail.Parent = overlay
	corner(rail, 14)
	stroke(rail, Theme.Colors.White, 2, .28)
	local topArrow = label(overlay, "▼", UDim2.fromScale(.475, .245), UDim2.fromScale(.05, .05), 34, Theme.Colors.White, 530)
	local bottomArrow = label(overlay, "▲", UDim2.fromScale(.475, .575), UDim2.fromScale(.05, .05), 34, Theme.Colors.White, 530)
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(0, 0)
	strip.Size = UDim2.fromOffset(5200, 160)
	strip.ZIndex = 523
	strip.Parent = rail
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip
	local stopIndex = 28
	local cardWidth = 138
	local total = 38
	for i = 1, total do
		local pack = i == stopIndex and chosen or PACKS[math.random(1, #PACKS)]
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(cardWidth, 154)
		holder.LayoutOrder = i
		holder.ZIndex = 523
		holder.Parent = strip
		makePackCard(holder, pack, UDim2.fromScale(1, 1), 524)
	end
	local sparkLine = Instance.new("Frame")
	sparkLine.AnchorPoint = Vector2.new(.5, .5)
	sparkLine.Position = UDim2.fromScale(.5, .43)
	sparkLine.Size = UDim2.fromScale(.02, .28)
	sparkLine.BackgroundColor3 = Theme.Colors.White
	sparkLine.BackgroundTransparency = .3
	sparkLine.BorderSizePixel = 0
	sparkLine.ZIndex = 531
	sparkLine.Parent = overlay
	TweenService:Create(sparkLine, TweenInfo.new(.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = .02, Size = UDim2.fromScale(.027, .30)}):Play()
	task.wait()
	local railWidth = rail.AbsoluteSize.X
	local targetX = railWidth * .5 - ((stopIndex - 1) * (cardWidth + 12) + cardWidth * .5)
	strip.Position = UDim2.fromOffset(railWidth * .5 + 120, 8)
	TweenService:Create(strip, TweenInfo.new(4.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(targetX, 8)}):Play()
	task.delay(4.55, function()
		if not overlay.Parent then return end
		local reveal = Instance.new("CanvasGroup")
		reveal.AnchorPoint = Vector2.new(.5, .5)
		reveal.Position = UDim2.fromScale(.5, .48)
		reveal.Size = UDim2.fromOffset(310, 400)
		reveal.BackgroundTransparency = 1
		reveal.GroupTransparency = 1
		reveal.ZIndex = 540
		reveal.Parent = overlay
		makePackCard(reveal, chosen, UDim2.fromScale(1, 1), 541)
		local scale = Instance.new("UIScale")
		scale.Scale = .22
		scale.Parent = reveal
		TweenService:Create(reveal, TweenInfo.new(.16), {GroupTransparency = 0}):Play()
		TweenService:Create(scale, TweenInfo.new(.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		for i = 1, 24 do
			local spark = Instance.new("Frame")
			spark.AnchorPoint = Vector2.new(.5, .5)
			spark.Position = UDim2.fromScale(.5, .48)
			spark.Size = UDim2.fromOffset(math.random(5, 13), math.random(20, 52))
			spark.BackgroundColor3 = i % 3 == 0 and Theme.Colors.White or chosen.Color
			spark.BackgroundTransparency = .04
			spark.BorderSizePixel = 0
			spark.Rotation = math.random(-30, 30)
			spark.ZIndex = 539
			spark.Parent = overlay
			corner(spark, 3)
			local angle = (i / 24) * math.pi * 2
			local radius = math.random(150, 360)
			TweenService:Create(spark, TweenInfo.new(.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(.5, math.cos(angle) * radius, .48, math.sin(angle) * radius * .55), BackgroundTransparency = 1, Rotation = spark.Rotation + math.random(-180, 180)}):Play()
			task.delay(1, function() if spark.Parent then spark:Destroy() end end)
		end
		label(overlay, "PACK SECURED", UDim2.fromScale(.2, .80), UDim2.fromScale(.6, .05), 22, chosen.Color, 545)
	end)
	task.delay(7.15, function()
		if not overlay.Parent then
			onComplete()
			return
		end
		TweenService:Create(overlay, TweenInfo.new(.35), {GroupTransparency = 1}):Play()
		task.delay(.38, function()
			if overlay.Parent then overlay:Destroy() end
			onComplete()
		end)
	end)
end

return Presentation
