--!strict
local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").VTR.Shared.Theme)
local Catalog = require(game:GetService("ReplicatedStorage").VTR.Shared.Catalog)

local Presentation = {}

local PACK_COLORS = {
	Common = Color3.fromHex("B7FF1A"),
	Bronze = Color3.fromHex("C7834A"),
	Silver = Color3.fromHex("D9D9D9"),
	Gold = Color3.fromHex("FFCB45"),
	Rare = Color3.fromHex("1FA2FF"),
	Elite = Color3.fromHex("8E00D6"),
	Legendary = Color3.fromHex("FF477E"),
	Icon = Color3.fromHex("F5F7F2"),
	Mythic = Color3.fromHex("24C6B8"),
}

local PACK_WEIGHTS = {
	common_pack = 260,
	bronze_pack = 190,
	silver_pack = 150,
	gold_pack = 115,
	rare_pack = 84,
	elite_pack = 62,
	rising_star_pack = 48,
	totw_pack = 40,
	voltra_pack = 32,
	event_pack = 26,
	hero_pack = 18,
	champion_pack = 13,
	legendary_pack = 8,
	icon_pack = 4,
	limited_pack = 3,
	mythic_storm_pack = 2,
	mythic_pack = 1,
}

local function packRarity(definition: any): string
	local odds = definition and definition.Odds or {}
	if (tonumber(odds.Mythic) or 0) > 0 then return "Mythic" end
	if (tonumber(odds.Icon) or 0) > 0 then return "Icon" end
	if (tonumber(odds.Legendary) or 0) > 0 then return "Legendary" end
	if (tonumber(odds.Elite) or 0) > 0 then return "Elite" end
	if (tonumber(odds.Rare) or 0) > 0 then return "Rare" end
	if (tonumber(odds.Gold) or 0) > 0 then return "Gold" end
	if (tonumber(odds.Silver) or 0) > 0 then return "Silver" end
	return "Common"
end

local function decoratePack(pack: any): any
	local rarity = tostring(pack.Rarity or "Common")
	pack.Color = pack.Color or PACK_COLORS[rarity] or Theme.Colors.Electric
	pack.Accent = pack.Accent or (rarity == "Icon" and Color3.fromHex("050505") or Color3.fromHex("050505"))
	return pack
end

local function catalogPack(id: string): any?
	local definition = Catalog.Packs[id]
	if not definition then return nil end
	return decoratePack({
		PackId = id,
		Name = definition.Name,
		Rarity = packRarity(definition),
		Weight = PACK_WEIGHTS[id] or math.max(1, math.floor(100000 / math.max(tonumber(definition.PriceCoins) or 10000, 1))),
	})
end

local function storePacks(payload: any?): {any}
	local result = {}
	local seen = {}
	local choices = payload and payload.Reward and payload.Reward.PackChoices or payload and payload.RankedWinPack and payload.RankedWinPack.PackChoices or nil
	if type(choices) == "table" then
		for _, choice in choices do
			local id = tostring(choice.PackId or choice.Id or "")
			local pack = id ~= "" and catalogPack(id) or nil
			if not pack and choice.Name then
				pack = decoratePack({PackId = id, Name = tostring(choice.Name), Rarity = tostring(choice.Rarity or "Common"), Weight = PACK_WEIGHTS[id] or 1})
			end
			if pack and not seen[pack.PackId ~= "" and pack.PackId or pack.Name] then
				seen[pack.PackId ~= "" and pack.PackId or pack.Name] = true
				table.insert(result, pack)
			end
		end
	end
	for id, definition in Catalog.Packs do
		if definition.PriceCoins and definition.PriceCoins > 0 and not string.find(id, "starter", 1, true) and id ~= "voltage_standard" and id ~= "elite_electrum" and not seen[id] then
			seen[id] = true
			table.insert(result, catalogPack(id))
		end
	end
	table.sort(result, function(a, b) return tostring(a.PackId or a.Name) < tostring(b.PackId or b.Name) end)
	return result
end

local function weightedPack(packs: {any}): any
	local total = 0
	for _, pack in packs do
		total += pack.Weight or 1
	end
	local roll = math.random() * total
	local cursor = 0
	for _, pack in packs do
		cursor += pack.Weight or 1
		if roll <= cursor then return pack end
	end
	return packs[1]
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
	local packs = storePacks(payload)
	local wantedId = tostring(reward.PackId or ranked.PackId or "")
	if wantedId ~= "" then
		for _, pack in packs do
			if tostring(pack.PackId or "") == wantedId then return pack end
		end
		local fromCatalog = catalogPack(wantedId)
		if fromCatalog then return fromCatalog end
	end
	local wanted = reward.PackName or reward.Pack or reward.packName or ranked.PackName
	if wanted then
		for _, pack in packs do
			if string.upper(pack.Name) == string.upper(tostring(wanted)) then return pack end
		end
		return decoratePack({Name = tostring(wanted), Rarity = tostring(reward.Rarity or ranked.Rarity or "Common"), Weight = 1})
	end
	return weightedPack(packs)
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
	local packs = storePacks(payload)
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
	label(overlay, "YOU WON THE GAME", UDim2.fromScale(.12, .18), UDim2.fromScale(.76, .08), 42, Theme.Colors.Electric, 522)
	label(overlay, "RANKED VICTORY REWARD LOCKED", UDim2.fromScale(.18, .27), UDim2.fromScale(.64, .05), 13, Theme.Colors.White, 522)
	task.wait(1.35)
	if not overlay.Parent then return end
	label(overlay, "RANKED WIN REWARD", UDim2.fromScale(.18, .07), UDim2.fromScale(.64, .05), 13, Theme.Colors.Electric, 522)
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
	stroke(rail, Theme.Colors.Electric, 2, .28)
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
		local pack = i == stopIndex and chosen or packs[math.random(1, #packs)]
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
	sparkLine.BackgroundColor3 = Theme.Colors.Electric
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
