local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)
--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MATCHUP_PANEL_DELAY = 0.85

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local PlayerPortraitService = require(script.Parent.Parent.Services.PlayerPortraitService)

local Presentation = {}
local TOTAL_DURATION = 66.0

local function shortCode(name: string): string
	local words = string.split(string.upper(name), " ")
	if #words >= 2 then
		return string.sub(words[1], 1, 1) .. string.sub(words[2], 1, 2)
	end
	return string.sub(string.upper(name), 1, 3)
end

local function color(value: any, fallback: Color3): Color3
	return typeof(value) == "Color3" and value or fallback
end

local function badgeAccent(primary: Color3): Color3
	local bright = Color3.fromHex("F5F7F2")
	local dark = Color3.fromHex("050805")
	local brightness = primary.R + primary.G + primary.B
	return brightness > 1.65 and dark or bright
end

local function applyPresentationBadge(target: TextLabel, primary: Color3, logoText: string?)
	target.Text = ""
	target.BackgroundTransparency = 1
	target.ClipsDescendants = true
	for _, child in target:GetChildren() do
		if child.Name == "VTRPresentationBadgeArt" then child:Destroy() end
	end
	local accent = badgeAccent(primary)
	local art = Instance.new("Frame")
	art.Name = "VTRPresentationBadgeArt"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = target.ZIndex + 1
	art.Parent = target
	local outer = Instance.new("Frame")
	outer.AnchorPoint = Vector2.new(.5, .5)
	outer.Position = UDim2.fromScale(.5, .5)
	outer.Size = UDim2.fromScale(.82, .82)
	outer.BackgroundColor3 = primary
	outer.BorderSizePixel = 0
	outer.ZIndex = art.ZIndex + 1
	outer.Parent = art
	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(.22, 0)
	outerCorner.Parent = outer
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = accent
	outerStroke.Transparency = .08
	outerStroke.Thickness = 2
	outerStroke.Parent = outer
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(.5, .5)
	inner.Position = UDim2.fromScale(.5, .5)
	inner.Size = UDim2.fromScale(.68, .68)
	inner.BackgroundColor3 = Color3.fromHex("050505")
	inner.BackgroundTransparency = .04
	inner.BorderSizePixel = 0
	inner.ZIndex = outer.ZIndex + 1
	inner.Parent = outer
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(.18, 0)
	innerCorner.Parent = inner
	local stripe = Instance.new("Frame")
	stripe.AnchorPoint = Vector2.new(.5, .5)
	stripe.Position = UDim2.fromScale(.5, .5)
	stripe.Size = UDim2.fromScale(.18, 1.12)
	stripe.Rotation = -24
	stripe.BackgroundColor3 = primary:Lerp(accent, .2)
	stripe.BackgroundTransparency = .16
	stripe.BorderSizePixel = 0
	stripe.ZIndex = inner.ZIndex + 1
	stripe.Parent = inner
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Text = tostring(logoText or "V")
	mark.TextColor3 = primary
	mark.TextSize = math.max(16, math.floor(target.AbsoluteSize.Y * .34))
	mark.Font = Theme.Fonts.Display
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.TextYAlignment = Enum.TextYAlignment.Center
	mark.ZIndex = inner.ZIndex + 2
	mark.Parent = inner
end

local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, textSize: number, textColor: Color3?, font: Enum.Font?): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = pos
	item.Size = size
	item.Text = text
	item.TextColor3 = textColor or Theme.Colors.White
	item.TextSize = textSize
	item.Font = font or Theme.Fonts.Display
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.TextWrapped = true
	item.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 201
	item.Parent = parent
	return item
end

local function panel(parent: Instance, name: string, pos: UDim2, size: UDim2): CanvasGroup
	local item = Instance.new("CanvasGroup")
	item.Name = name
	item.Position = pos
	item.Size = size
	item.BackgroundColor3 = Theme.Colors.Black
	item.BackgroundTransparency = 0.1
	item.BorderSizePixel = 0
	item.GroupTransparency = 1
	item.Visible = false
	item.ZIndex = 202
	item.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Electric
	stroke.Transparency = 0.4
	stroke.Thickness = 1
	stroke.Parent = item
	return item
end

local function slideIn(item: GuiObject, pos: UDim2, from: UDim2, duration: number?)
	item.Position = from
	item.Visible = true
	TweenService:Create(item, TweenInfo.new(duration or 0.36, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), {Position = pos}):Play()
	if item:IsA("CanvasGroup") then
		TweenService:Create(item, TweenInfo.new(0.18), {GroupTransparency = 0}):Play()
	end
end

local function slideOut(item: GuiObject, to: UDim2, duration: number?)
	TweenService:Create(item, TweenInfo.new(duration or 0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = to}):Play()
	if item:IsA("CanvasGroup") then
		TweenService:Create(item, TweenInfo.new(0.18), {GroupTransparency = 1}):Play()
	end
	task.delay(duration or 0.28, function()
		if item.Parent then item.Visible = false end
	end)
end

local function sortedModels(data: any, side: string): {Model}
	local result = {}
	for _, model in data.TeamModels and data.TeamModels[side] or {} do
		if typeof(model) == "Instance" and model:IsA("Model") then
			table.insert(result, model)
		end
	end
	table.sort(result, function(a, b)
		return (tonumber(a:GetAttribute("VTRIndex")) or 99) < (tonumber(b:GetAttribute("VTRIndex")) or 99)
	end)
	return result
end

local function playerName(model: Model?): string
	return model and tostring(model:GetAttribute("DisplayName") or model.Name) or "-"
end

local function playerLine(model: Model?, fallback: number): string
	if not model then return tostring(fallback) .. "   -" end
	return string.format("%2s   %s", tostring(model:GetAttribute("ShirtNumber") or fallback), string.upper(playerName(model)))
end

local function teamSheet(data: any, side: string): string
	local lines = {}
	for index, model in sortedModels(data, side) do
		table.insert(lines, playerLine(model, index))
	end
	return table.concat(lines, "\n")
end

local function playerDataLine(entry: any, fallback: number): string
	if type(entry) ~= "table" then
		return tostring(fallback) .. "   -"
	end
	local number = entry.shirtNumber or entry.number or entry.ShirtNumber or fallback
	local name = entry.displayName or entry.shortName or entry.name or entry.Name or "PLAYER"
	return string.format("%2s   %s", tostring(number), string.upper(tostring(name)))
end

local function teamSheetFromPlayers(players: {any}, fallbackText: string): string
	if #players == 0 then return fallbackText end
	local lines = {}
	for index, entry in players do
		table.insert(lines, playerDataLine(entry, index))
		if #lines >= 11 then break end
	end
	return table.concat(lines, "\n")
end

local function benchSheet(data: any, side: string): string
	local bench = side == "Home" and data.HomeBench or data.AwayBench
	local lines = {}
	for index, entry in bench or {} do
		local number = entry.shirtNumber or entry.number or entry.ShirtNumber or (11 + index)
		local name = entry.displayName or entry.name or entry.Name or entry.playerName or "SUBSTITUTE"
		table.insert(lines, string.format("%2s   %s", tostring(number), string.upper(tostring(name))))
		if #lines >= 9 then break end
	end
	return #lines > 0 and table.concat(lines, "\n") or "12   RESERVE GK\n13   RESERVE DEF\n14   RESERVE MID\n15   RESERVE ATT"
end

local function benchSheetFromPlayers(players: {any}, fallbackText: string): string
	if #players == 0 then return fallbackText end
	local lines = {}
	for index, entry in players do
		table.insert(lines, playerDataLine(entry, index + 11))
		if #lines >= 7 then break end
	end
	return table.concat(lines, "\n")
end

local function teamLogoText(data: any, side: string, fallback: string): string
	local value = side == "Home" and data.HomeLogo or data.AwayLogo
	return tostring(value or fallback)
end

local function positionFromEntry(entry: any): string
	if type(entry) ~= "table" then return "" end
	return string.upper(tostring(entry.Position or entry.bestPosition or entry.position or entry.role or ""))
end

local function positionFromModel(model: Model?): string
	if not model then return "" end
	return string.upper(tostring(model:GetAttribute("position") or model:GetAttribute("bestPosition") or ""))
end

local function lineGroupForPosition(position: string): string
	if position == "GK" then return "GK" end
	if position == "CB" or position == "LB" or position == "RB" or position == "LWB" or position == "RWB" then return "DEF" end
	if position == "ST" or position == "CF" or position == "SS" or position == "LW" or position == "RW" then return "ATT" end
	return "MID"
end

local function roleKey(position: string): string
	if position == "GK" then return "GK" end
	if position == "LB" or position == "LWB" then return "LB" end
	if position == "RB" or position == "RWB" then return "RB" end
	if position == "CB" then return "CB" end
	if position == "CDM" then return "CDM" end
	if position == "CAM" then return "CAM" end
	if position == "CM" then return "CM" end
	if position == "LM" then return "LM" end
	if position == "RM" then return "RM" end
	if position == "LW" then return "LW" end
	if position == "RW" then return "RW" end
	if position == "ST" or position == "CF" or position == "SS" then return "ST" end
	return "OTHER"
end

local function spread(key: string, baseX: number, counts: any, seen: any): number
	seen[key] = (seen[key] or 0) + 1
	local count = counts[key] or 1
	if count <= 1 then return baseX end
	local gap = math.min(0.22, 0.68 / math.max(1, count - 1))
	return math.clamp(baseX + (seen[key] - (count + 1) / 2) * gap, 0.1, 0.9)
end

local function coordForPosition(position: string, counts: any, seen: any, index: number): Vector2
	local key = roleKey(position)
	if key == "GK" then return Vector2.new(0.50, 0.88) end
	if key == "LB" then return Vector2.new(0.18, 0.69) end
	if key == "RB" then return Vector2.new(0.82, 0.69) end
	if key == "CB" then return Vector2.new(spread("CB", 0.50, counts, seen), 0.69) end
	if key == "CDM" then return Vector2.new(spread("CDM", 0.50, counts, seen), 0.55) end
	if key == "CM" then return Vector2.new(spread("CM", 0.50, counts, seen), 0.45) end
	if key == "CAM" then return Vector2.new(spread("CAM", 0.50, counts, seen), 0.34) end
	if key == "LM" then return Vector2.new(0.18, 0.36) end
	if key == "RM" then return Vector2.new(0.82, 0.36) end
	if key == "LW" then return Vector2.new(0.18, 0.23) end
	if key == "RW" then return Vector2.new(0.82, 0.23) end
	if key == "ST" then return Vector2.new(spread("ST", 0.50, counts, seen), 0.16) end
	return Vector2.new(0.18 + ((index - 1) % 4) * 0.21, 0.28 + math.floor((index - 1) / 4) * 0.18)
end

local function formationRoleOrder(position: string): number
	local key = roleKey(position)
	local order = {
		GK = 1,
		LB = 2,
		CB = 3,
		RB = 4,
		LWB = 2,
		RWB = 4,
		CDM = 5,
		LM = 6,
		CM = 7,
		RM = 8,
		CAM = 9,
		LW = 10,
		RW = 11,
		ST = 12,
	}
	return order[key] or 20
end

local function formationGroupOrder(position: string): number
	local group = lineGroupForPosition(position)
	if group == "GK" then return 1 end
	if group == "DEF" then return 2 end
	if group == "MID" then return 3 end
	if group == "ATT" then return 4 end
	return 5
end

local function modelNameKey(model: Model?): string
	if not model then return "" end
	return string.lower(tostring(model:GetAttribute("DisplayName") or model.Name))
end

local function playerNameKey(player: any): string
	if type(player) ~= "table" then return "" end
	return string.lower(tostring(player.DisplayName or player.Name or player.name or player.playerName or ""))
end

local function formationEntries(data: any, side: string): {any}
	local models = sortedModels(data, side)
	local players = side == "Home" and (data.HomeLineup or {}) or (data.AwayLineup or {})
	local usedModels: {[Model]: boolean} = {}
	local result = {}
	for index = 1, 11 do
		local player = players[index]
		local position = positionFromEntry(player)
		local matched: Model? = nil
		local playerKey = playerNameKey(player)
		if playerKey ~= "" then
			for _, model in models do
				if not usedModels[model] and modelNameKey(model) == playerKey then
					matched = model
					break
				end
			end
		end
		if not matched then
			matched = models[index]
		end
		if matched then
			usedModels[matched] = true
		end
		if position == "" then position = positionFromModel(matched) end
		if position == "" then
			local fallback = {"GK", "LB", "CB", "CB", "RB", "CDM", "CDM", "CAM", "LM", "RM", "ST"}
			position = fallback[index] or "CM"
		end
		table.insert(result, {Model = matched, Player = player, Position = position, OriginalIndex = index})
	end
	table.sort(result, function(a, b)
		local groupA = formationGroupOrder(a.Position)
		local groupB = formationGroupOrder(b.Position)
		if groupA ~= groupB then return groupA < groupB end
		local roleA = formationRoleOrder(a.Position)
		local roleB = formationRoleOrder(b.Position)
		if roleA ~= roleB then return roleA < roleB end
		return (a.OriginalIndex or 0) < (b.OriginalIndex or 0)
	end)
	return result
end

local function entriesForGroup(data: any, side: string, groupName: string): {any}
	local result = {}
	for _, entry in formationEntries(data, side) do
		if lineGroupForPosition(entry.Position) == groupName then
			table.insert(result, entry)
		end
	end
	return result
end

local function groupRange(data: any, side: string, groupName: string, fallbackFirst: number, fallbackLast: number): (number, number)
	local entries = formationEntries(data, side)
	local first = nil
	local last = nil
	for index, entry in entries do
		if lineGroupForPosition(entry.Position) == groupName then
			first = first or index
			last = index
		end
	end
	return first or fallbackFirst, last or fallbackLast
end

local function updateFormationDots(dots: {Frame}, data: any, side: string)
	local entries = formationEntries(data, side)
	local counts = {}
	for _, entry in entries do
		local key = roleKey(entry.Position)
		counts[key] = (counts[key] or 0) + 1
	end
	local seen = {}
	for index, dot in dots do
		local entry = entries[index]
		local coord = coordForPosition(entry.Position, counts, seen, index)
		dot.Position = UDim2.fromScale(coord.X, coord.Y)
		dot:SetAttribute("VTRLineGroup", lineGroupForPosition(entry.Position))
		dot:SetAttribute("VTRPosition", entry.Position)
		dot.BackgroundColor3 = Theme.Colors.White
		dot.Size = UDim2.fromOffset(11, 11)
	end
end

local function formationDots(parent: Instance, data: any, side: string)
	local dots = {}
	for index = 1, 11 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(11, 11)
		dot.BackgroundColor3 = Theme.Colors.White
		dot.BorderSizePixel = 0
		dot.ZIndex = 207
		dot.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Colors.Electric
		stroke.Transparency = 0.55
		stroke.Thickness = 1
		stroke.Parent = dot
		table.insert(dots, dot)
	end
	updateFormationDots(dots, data, side)
	return dots
end

local function setLineHighlight(dots: {Frame}, groupName: string, first: number, last: number)
	for index, dot in dots do
		local active = dot:GetAttribute("VTRLineGroup") == groupName
		if not active and groupName == "" then
			active = index >= first and index <= last
		end
		TweenService:Create(dot, TweenInfo.new(0.22), {
			BackgroundColor3 = active and Theme.Colors.Electric or Theme.Colors.White,
			Size = active and UDim2.fromOffset(16, 16) or UDim2.fromOffset(11, 11),
		}):Play()
	end
end

local function makePitchLine(parent: Instance, pos: UDim2, size: UDim2)
	local line = Instance.new("Frame")
	line.BackgroundColor3 = Theme.Colors.White
	line.BackgroundTransparency = 0.35
	line.BorderSizePixel = 0
	line.Position = pos
	line.Size = size
	line.ZIndex = 206
	line.Parent = parent
	return line
end

local function makePitchBox(parent: Instance, pos: UDim2, size: UDim2)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Position = pos
	box.Size = size
	box.ZIndex = 206
	box.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.White
	stroke.Transparency = 0.48
	stroke.Thickness = 1
	stroke.Parent = box
	return box
end

local function setPreviewPartPhysics(inst: Instance)
	if not inst:IsA("BasePart") then return end
	inst.Anchored = true
	inst.CanCollide = false
	inst.CanTouch = false
	inst.CanQuery = false
	inst.Massless = true
end

local function colorBrightness(c: Color3): number
	return c.R * 0.2126 + c.G * 0.7152 + c.B * 0.0722
end

local function brightenCloneForPreview(clone: Model)
	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CastShadow = false
			if desc.Name == "Torso" and colorBrightness(desc.Color) < 0.08 then
				desc.Color = Color3.fromHex("1E2519")
			elseif (desc.Name == "Left Arm" or desc.Name == "Right Arm" or desc.Name == "Head") and colorBrightness(desc.Color) < 0.08 then
				desc.Color = Color3.fromHex("8B5F45")
			end
		end
	end
end

local function addPreviewKitGeometry(clone: Model)
	local torso = clone:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then return end
	local pattern = torso:FindFirstChild("VTRKitPattern")
	local root = pattern and pattern:FindFirstChildWhichIsA("Frame")
	if not root then return end
	local function frontPatch(name: string, pos: UDim2, size: UDim2, colorValue: Color3, rotation: number?)
		local patch = Instance.new("Part")
		patch.Name = "PreviewKit_" .. name
		patch.Anchored = true
		patch.CanCollide = false
		patch.CanTouch = false
		patch.CanQuery = false
		patch.CastShadow = false
		patch.Material = Enum.Material.SmoothPlastic
		patch.Color = colorValue
		patch.Size = Vector3.new(math.max(0.035, torso.Size.X * size.X.Scale), math.max(0.035, torso.Size.Y * size.Y.Scale), 0.025)
		local x = (pos.X.Scale - 0.5) * torso.Size.X
		local y = (0.5 - pos.Y.Scale) * torso.Size.Y
		patch.CFrame = torso.CFrame * CFrame.new(x, y, -torso.Size.Z * 0.5 - 0.018) * CFrame.Angles(0, 0, math.rad(rotation or 0))
		patch.Parent = clone
	end
	for _, child in root:GetChildren() do
		if child:IsA("Frame") then
			frontPatch(child.Name, child.Position, child.Size, child.BackgroundColor3, child.Rotation)
		end
	end
end

local function showPlayerPreview(viewport: ViewportFrame, model: Model?)
	viewport:ClearAllChildren()
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 27
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	if not model then return end

	local oldArchivable = {}
	oldArchivable[model] = model.Archivable
	model.Archivable = true
	for _, desc in model:GetDescendants() do
		oldArchivable[desc] = desc.Archivable
		desc.Archivable = true
	end
	local clone = model:Clone()
	for inst, value in oldArchivable do
		if inst.Parent then
			inst.Archivable = value
		end
	end
	if not clone then return end
	for _, desc in clone:GetDescendants() do
		setPreviewPartPhysics(desc)
	end
	brightenCloneForPreview(clone)
	addPreviewKitGeometry(clone)
	clone.Parent = world
	clone:PivotTo(CFrame.new(0, 0, 0))
	local center, size = clone:GetBoundingBox()
	local height = math.max(size.Y, 5)
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, height * 0.03, -7.1), center.Position + Vector3.new(0, height * 0.08, 0))
end

local function lineupData(data: any, side: string): {any}
	return side == "Home" and (data.HomeLineup or {}) or (data.AwayLineup or {})
end

local function showPlayerGroupPreview(container: Frame, models: {Model}, players: {any}, firstIndex: number, lastIndex: number)
	local function render()
		container:ClearAllChildren()
		local count = math.max(lastIndex - firstIndex + 1, 1)
		local gap = count == 1 and 0 or 0.018
		local slotWidth = count == 1 and 0.44 or (1 - gap * (count - 1)) / count
		local startX = count == 1 and 0.28 or 0
		for order = 1, count do
			local playerIndex = firstIndex + order - 1
			local model = models[playerIndex]
			local playerData = players[playerIndex]
			local slot = Instance.new("CanvasGroup")
			slot.BackgroundTransparency = 1
			local targetPosition = UDim2.fromScale(startX + (slotWidth + gap) * (order - 1), 0)
			slot.Position = UDim2.fromScale(targetPosition.X.Scale + 0.08, 0)
			slot.Size = UDim2.fromScale(slotWidth, 1)
			slot.GroupTransparency = 1
			slot.ZIndex = 207
			slot.Parent = container

			local shirtNumber = model and tostring(model:GetAttribute("ShirtNumber") or playerIndex) or tostring(playerIndex)
			local watermark = label(slot, shirtNumber, UDim2.fromScale(0, -0.04), UDim2.fromScale(1, 0.55), count == 1 and 150 or 112, Theme.Colors.White, Theme.Fonts.Display)
			watermark.TextTransparency = 0.72
			watermark.TextXAlignment = Enum.TextXAlignment.Center
			watermark.ZIndex = 207

			if playerData and playerData.appearance then
				local portrait = PlayerPortraitService.new(slot, playerData, UDim2.fromScale(1, 0.70), false)
				portrait.Position = UDim2.fromScale(0, 0.07)
				portrait.BackgroundTransparency = 1
				portrait.ZIndex = 209
			else
				local viewport = Instance.new("ViewportFrame")
				viewport.BackgroundTransparency = 1
				viewport.Position = UDim2.fromScale(0, 0.08)
				viewport.Size = UDim2.fromScale(1, 0.66)
				viewport.Ambient = Color3.fromHex("D4E4BE")
				viewport.LightColor = Color3.fromHex("F3F7EE")
				viewport.LightDirection = Vector3.new(-0.7, -1, -0.8)
				viewport.ZIndex = 209
				viewport.Parent = slot
				showPlayerPreview(viewport, model)
			end

			local numberLabel = label(slot, shirtNumber, UDim2.fromScale(0, 0.73), UDim2.fromScale(1, 0.08), count == 1 and 30 or 23, Theme.Colors.Electric, Theme.Fonts.Display)
			numberLabel.TextXAlignment = Enum.TextXAlignment.Center
			local nameLabel = label(slot, string.upper(playerName(model)), UDim2.fromScale(0.02, 0.82), UDim2.fromScale(0.96, 0.12), count == 1 and 22 or 15, Theme.Colors.White, Theme.Fonts.Strong)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Center
			task.delay((order - 1) * 0.08, function()
				if not slot.Parent then return end
				TweenService:Create(slot, TweenInfo.new(0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = targetPosition,
					GroupTransparency = 0,
				}):Play()
			end)
		end
	end

	local oldChildren = container:GetChildren()
	if #oldChildren == 0 then
		render()
		return
	end
	for _, child in oldChildren do
		if child:IsA("CanvasGroup") then
			TweenService:Create(child, TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
				Position = child.Position - UDim2.fromScale(0.06, 0),
				GroupTransparency = 1,
			}):Play()
		end
	end
	task.delay(0.15, function()
		if container.Parent then render() end
	end)
end

local function showEntryGroupPreview(container: Frame, entries: {any})
	local models = {}
	local players = {}
	for _, entry in entries do
		table.insert(models, entry.Model)
		table.insert(players, entry.Player)
	end
	showPlayerGroupPreview(container, models, players, 1, math.max(1, #entries))
end

function Presentation.Duration(): number
	return TOTAL_DURATION
end

function Presentation.Play(data: any, onComplete: (() -> ())?)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRPrematchBroadcast")
	if old then old:Destroy() end
	for _, overlayName in ipairs({"VTRMatchTeleport","VTRRankedTeleportFound","VTRRankedTeleportMatchFound","VTRMatchupConfirmed","VTRMatchupConfirm","VTRRankedReservedBoot"}) do
		local overlay = playerGui:FindFirstChild(overlayName)
		if overlay then overlay:Destroy() end
	end
	for _, overlayName in ipairs({"VTRMatchTeleport","VTRRankedTeleportFound","VTRRankedTeleportMatchFound","VTRMatchupConfirmed","VTRMatchupConfirm","VTRRankedReservedBoot"}) do
		local overlay = playerGui:FindFirstChild(overlayName)
		if overlay then overlay:Destroy() end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRPrematchBroadcast"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 92
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 200
	root.Parent = gui

	local home = tostring(data.Home or "HOME")
	local away = tostring(data.Away or "AWAY")
	local homeColor = color(data.HomeColor, Theme.Colors.Electric)
	local awayColor = color(data.AwayColor, Theme.Colors.Silver)

	local matchup = Instance.new("CanvasGroup")
	matchup.Name = "Matchup"
	matchup.Position = UDim2.fromScale(0.25, 0.16)
	matchup.Size = UDim2.fromScale(0.50, 0.48)
	matchup.BackgroundTransparency = 1
	matchup.GroupTransparency = 1
	matchup.Visible = false
	matchup.ZIndex = 202
	matchup.Parent = root
	local leftPanel = Instance.new("Frame")
	leftPanel.BackgroundColor3 = Theme.Colors.Black
	leftPanel.BorderSizePixel = 0
	leftPanel.Position = UDim2.fromScale(0.02, 0.09)
	leftPanel.Size = UDim2.fromScale(0.47, 0.78)
	leftPanel.ZIndex = 203
	leftPanel.Parent = matchup
	local rightPanel = Instance.new("Frame")
	rightPanel.BackgroundColor3 = Color3.fromHex("101510")
	rightPanel.BorderSizePixel = 0
	rightPanel.Position = UDim2.fromScale(0.52, 0.09)
	rightPanel.Size = UDim2.fromScale(0.46, 0.78)
	rightPanel.ZIndex = 203
	rightPanel.Parent = matchup
	local logoTab = label(matchup, "VTR", UDim2.fromScale(-0.04, -0.04), UDim2.fromScale(0.12, 0.14), 18, Theme.Colors.Black, Theme.Fonts.Display)
	logoTab.BackgroundColor3 = Theme.Colors.White
	logoTab.BackgroundTransparency = 0
	logoTab.TextXAlignment = Enum.TextXAlignment.Center
	logoTab.ZIndex = 205
	label(leftPanel, shortCode(home), UDim2.fromScale(0.11, 0.33), UDim2.fromScale(0.55, 0.12), 34).TextXAlignment = Enum.TextXAlignment.Left
	label(leftPanel, string.upper(home), UDim2.fromScale(0.11, 0.45), UDim2.fromScale(0.65, 0.08), 13, Theme.Colors.White, Theme.Fonts.Strong)
	label(leftPanel, "VS", UDim2.fromScale(0.11, 0.55), UDim2.fromScale(0.22, 0.08), 18, Theme.Colors.White, Theme.Fonts.Display)
	label(leftPanel, shortCode(away), UDim2.fromScale(0.11, 0.65), UDim2.fromScale(0.55, 0.12), 34).TextXAlignment = Enum.TextXAlignment.Left
	label(leftPanel, string.upper(away), UDim2.fromScale(0.11, 0.77), UDim2.fromScale(0.65, 0.08), 13, Theme.Colors.White, Theme.Fonts.Strong)
	local techStrip = label(matchup, "POWERED BY VOLTRA TECHNOLOGY", UDim2.fromScale(0.02, 0.90), UDim2.fromScale(0.47, 0.12), 15, Theme.Colors.White, Theme.Fonts.Strong)
	techStrip.BackgroundColor3 = Theme.Colors.Black
	techStrip.BackgroundTransparency = 0
	techStrip.TextXAlignment = Enum.TextXAlignment.Center
	techStrip.ZIndex = 205
	local homeBadge = label(rightPanel, tostring(data.HomeLogo or shortCode(home)), UDim2.fromScale(0.29, 0.22), UDim2.fromScale(0.42, 0.23), 24, Theme.Colors.White, Theme.Fonts.Display)
	homeBadge.BackgroundColor3 = homeColor
	homeBadge.BackgroundTransparency = 0
	homeBadge.TextXAlignment = Enum.TextXAlignment.Center
	applyPresentationBadge(homeBadge, homeColor, tostring(data.HomeLogo or "V"))
	local awayBadge = label(rightPanel, tostring(data.AwayLogo or shortCode(away)), UDim2.fromScale(0.29, 0.58), UDim2.fromScale(0.42, 0.23), 24, Theme.Colors.White, Theme.Fonts.Display)
	awayBadge.BackgroundColor3 = awayColor
	awayBadge.BackgroundTransparency = 0
	awayBadge.TextXAlignment = Enum.TextXAlignment.Center
	applyPresentationBadge(awayBadge, awayColor, tostring(data.AwayLogo or "V"))
	for _, spec in {
		{UDim2.fromScale(0.47, 0.55), UDim2.fromScale(0.08, 0.01)},
		{UDim2.fromScale(0.87, 0.55), UDim2.fromScale(0.13, 0.01)},
		{UDim2.fromScale(0.98, 0.02), UDim2.fromScale(0.04, 0.06)},
		{UDim2.fromScale(-0.02, 0.97), UDim2.fromScale(0.04, 0.06)},
	} do
		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = Theme.Colors.Electric
		accent.BorderSizePixel = 0
		accent.Position = spec[1]
		accent.Size = spec[2]
		accent.ZIndex = 206
		accent.Parent = matchup
	end
	local centerLine = Instance.new("Frame")
	centerLine.BackgroundColor3 = Theme.Colors.Electric
	centerLine.BorderSizePixel = 0
	centerLine.Position = UDim2.fromScale(0.49, 0.52)
	centerLine.Size = UDim2.fromScale(0.03, 0.012)
	centerLine.ZIndex = 206
	centerLine.Parent = matchup

	local commentators = panel(root, "Commentators", UDim2.fromScale(0.06, 0.74), UDim2.fromScale(0.34, 0.09))
	label(commentators, "MATCH COMMENTATORS", UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.26), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	label(commentators, "NISHINO     |     FOALLOW", UDim2.fromScale(0.05, 0.38), UDim2.fromScale(0.9, 0.5), 15)

	local formation = panel(root, "Formation", UDim2.fromScale(0.04, 0.13), UDim2.fromScale(0.30, 0.62))
	local formationTitle = label(formation, shortCode(home), UDim2.fromScale(0.09, 0.03), UDim2.fromScale(0.82, 0.13), 34, Theme.Colors.Electric)
	local pitch = Instance.new("Frame")
	pitch.BackgroundColor3 = Color3.fromHex("071007")
	pitch.BackgroundTransparency = 0.16
	pitch.BorderSizePixel = 0
	pitch.Position = UDim2.fromScale(0.09, 0.21)
	pitch.Size = UDim2.fromScale(0.82, 0.70)
	pitch.ZIndex = 206
	pitch.Parent = formation
	local pitchStroke = Instance.new("UIStroke")
	pitchStroke.Color = Theme.Colors.White
	pitchStroke.Transparency = 0.42
	pitchStroke.Parent = pitch
	makePitchLine(pitch, UDim2.fromScale(0.12, 0.50), UDim2.fromScale(0.76, 0.005))
	makePitchLine(pitch, UDim2.fromScale(0.12, 0.14), UDim2.fromScale(0.76, 0.005))
	makePitchLine(pitch, UDim2.fromScale(0.12, 0.86), UDim2.fromScale(0.76, 0.005))
	makePitchBox(pitch, UDim2.fromScale(0.24, 0.72), UDim2.fromScale(0.52, 0.18))
	makePitchBox(pitch, UDim2.fromScale(0.34, 0.80), UDim2.fromScale(0.32, 0.10))
	makePitchBox(pitch, UDim2.fromScale(0.24, 0.10), UDim2.fromScale(0.52, 0.18))
	local centerCircle = makePitchBox(pitch, UDim2.fromScale(0.42, 0.43), UDim2.fromScale(0.16, 0.14))
	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(1, 0)
	centerCorner.Parent = centerCircle
	local dots = formationDots(pitch, data, "Home")

	local playerCard = panel(root, "PlayerCard", UDim2.fromScale(0.37, 0.13), UDim2.fromScale(0.58, 0.62))
	playerCard.BackgroundColor3 = Color3.fromHex("0A0F08")
	local playerCardAccent = Instance.new("Frame")
	playerCardAccent.BackgroundColor3 = Theme.Colors.Electric
	playerCardAccent.BorderSizePixel = 0
	playerCardAccent.Position = UDim2.fromScale(0, 0)
	playerCardAccent.Size = UDim2.fromScale(0.012, 1)
	playerCardAccent.ZIndex = 206
	playerCardAccent.Parent = playerCard
	local introTitle = label(playerCard, "HOME GOALKEEPER", UDim2.fromScale(0.07, 0.06), UDim2.fromScale(0.42, 0.08), 13, Theme.Colors.Electric, Theme.Fonts.Strong)
	local groupPreview = Instance.new("Frame")
	groupPreview.BackgroundTransparency = 1
	groupPreview.Position = UDim2.fromScale(0.06, 0.12)
	groupPreview.Size = UDim2.fromScale(0.88, 0.82)
	groupPreview.ZIndex = 207
	groupPreview.Parent = playerCard
	showEntryGroupPreview(groupPreview, entriesForGroup(data, "Home", "GK"))

	local sheet = panel(root, "TeamSheet", UDim2.fromScale(0.09, 0.14), UDim2.fromScale(0.82, 0.68))
	sheet.BackgroundColor3 = Color3.fromHex("090B07")
	local sheetLogoPanel = Instance.new("Frame")
	sheetLogoPanel.BackgroundColor3 = Theme.Colors.Electric
	sheetLogoPanel.BorderSizePixel = 0
	sheetLogoPanel.Position = UDim2.fromScale(0, 0)
	sheetLogoPanel.Size = UDim2.fromScale(0.28, 1)
	sheetLogoPanel.ZIndex = 203
	sheetLogoPanel.Parent = sheet
	local sheetLogo = label(sheetLogoPanel, teamLogoText(data, "Home", shortCode(home)), UDim2.fromScale(0.18, 0.36), UDim2.fromScale(0.64, 0.22), 28, Theme.Colors.Black, Theme.Fonts.Display)
	sheetLogo.BackgroundColor3 = Theme.Colors.White
	sheetLogo.BackgroundTransparency = 0
	sheetLogo.TextXAlignment = Enum.TextXAlignment.Center
	applyPresentationBadge(sheetLogo, homeColor, teamLogoText(data, "Home", "V"))
	applyPresentationBadge(sheetLogo, homeColor, teamLogoText(data, "Home", "V"))
	local sheetTeamCode = label(sheetLogoPanel, shortCode(home), UDim2.fromScale(0.12, 0.08), UDim2.fromScale(0.76, 0.12), 34, Theme.Colors.Black, Theme.Fonts.Display)
	sheetTeamCode.TextXAlignment = Enum.TextXAlignment.Center
	local sheetStartTitle = label(sheet, "STARTING 11", UDim2.fromScale(0.36, 0.12), UDim2.fromScale(0.25, 0.08), 25, Theme.Colors.White, Theme.Fonts.Display)
	local sheetSubsTitle = label(sheet, "SUBS", UDim2.fromScale(0.70, 0.12), UDim2.fromScale(0.18, 0.08), 25, Theme.Colors.White, Theme.Fonts.Display)
	local sheetStartList = label(sheet, teamSheet(data, "Home"), UDim2.fromScale(0.35, 0.25), UDim2.fromScale(0.28, 0.64), 15, Theme.Colors.White, Theme.Fonts.Strong)
	local sheetSubsList = label(sheet, benchSheet(data, "Home"), UDim2.fromScale(0.70, 0.25), UDim2.fromScale(0.23, 0.64), 15, Theme.Colors.White, Theme.Fonts.Strong)
	local function updateTeamSheet(side: string)
		local teamName = side == "Home" and home or away
		local teamColor = side == "Home" and homeColor or awayColor
		sheetLogoPanel.BackgroundColor3 = teamColor
		sheetLogo.Text = teamLogoText(data, side, shortCode(teamName))
		applyPresentationBadge(sheetLogo, teamColor, teamLogoText(data, side, "V"))
		sheetTeamCode.Text = shortCode(teamName)
		sheetStartList.Text = teamSheetFromPlayers(lineupData(data, side), teamSheet(data, side))
		sheetSubsList.Text = benchSheetFromPlayers(side == "Home" and (data.HomeBench or {}) or (data.AwayBench or {}), benchSheet(data, side))
	end

	local kickoff = panel(root, "KickoffScoreboard", UDim2.fromScale(0.18, 1.04), UDim2.fromScale(0.64, 0.12))
	label(kickoff, shortCode(home) .. "   0       VTR       0   " .. shortCode(away), UDim2.fromScale(0.08, 0.16), UDim2.fromScale(0.84, 0.68), 26).TextXAlignment = Enum.TextXAlignment.Center

	task.delay(0.4, function()
		slideIn(matchup, UDim2.fromScale(0.25, 0.16), UDim2.fromScale(0.25, 1.05), 0.42)
	end)
	task.delay(4.8, function()
		slideOut(matchup, UDim2.fromScale(0.25, -0.62))
		slideIn(commentators, UDim2.fromScale(0.06, 0.74), UDim2.fromScale(-0.36, 0.74))
	end)
	task.delay(15.4, function()
		slideOut(commentators, UDim2.fromScale(-0.36, 0.74))
	end)
	task.delay(16.0, function()
		slideIn(formation, UDim2.fromScale(0.04, 0.13), UDim2.fromScale(-0.32, 0.13))
		slideIn(playerCard, UDim2.fromScale(0.37, 0.13), UDim2.fromScale(0.37, 0.86))
	end)
	local lineGroups = {
		{16.2, "HOME GOALKEEPER", "Home", 1, 1, "GK"},
		{20.1, "HOME DEFENDERS", "Home", 2, 5, "DEF"},
		{24.0, "HOME MIDFIELDERS", "Home", 6, 8, "MID"},
		{27.9, "HOME ATTACKERS", "Home", 9, 11, "ATT"},
		{36.0, "AWAY GOALKEEPER", "Away", 1, 1, "GK"},
		{39.9, "AWAY DEFENDERS", "Away", 2, 5, "DEF"},
		{43.8, "AWAY MIDFIELDERS", "Away", 6, 8, "MID"},
		{47.7, "AWAY ATTACKERS", "Away", 9, 11, "ATT"},
	}
	for _, group in lineGroups do
		task.delay(group[1], function()
			local side = group[3]
			if side == "Away" and formationTitle.Text ~= shortCode(away) then
				formationTitle.Text = shortCode(away)
				updateFormationDots(dots, data, side)
			elseif side == "Home" and formationTitle.Text ~= shortCode(home) then
				formationTitle.Text = shortCode(home)
				updateFormationDots(dots, data, side)
			end
			setLineHighlight(dots, group[6], group[4], group[5])
			introTitle.Text = group[2]
			showEntryGroupPreview(groupPreview, entriesForGroup(data, side, group[6]))
		end)
	end
	task.delay(31.0, function()
		slideOut(playerCard, UDim2.fromScale(0.37, 0.86))
		slideOut(formation, UDim2.fromScale(-0.32, 0.13))
		updateTeamSheet("Home")
		slideIn(sheet, UDim2.fromScale(0.09, 0.14), UDim2.fromScale(0.09, 1.04), 0.42)
	end)
	task.delay(35.1, function()
		slideOut(sheet, UDim2.fromScale(0.09, 1.04), 0.3)
		formationTitle.Text = shortCode(away)
		updateFormationDots(dots, data, "Away")
		slideIn(formation, UDim2.fromScale(0.04, 0.13), UDim2.fromScale(-0.32, 0.13))
		slideIn(playerCard, UDim2.fromScale(0.37, 0.13), UDim2.fromScale(0.37, 0.86))
	end)
	task.delay(51.0, function()
		slideOut(playerCard, UDim2.fromScale(0.37, 0.86))
		slideOut(formation, UDim2.fromScale(-0.32, 0.13))
		updateTeamSheet("Away")
		slideIn(sheet, UDim2.fromScale(0.09, 0.14), UDim2.fromScale(0.09, 1.04), 0.42)
	end)
	task.delay(57.0, function()
		slideOut(sheet, UDim2.fromScale(0.09, 1.04), 0.3)
	end)
	task.delay(60.0, function()
		slideIn(kickoff, UDim2.fromScale(0.18, 0.82), UDim2.fromScale(0.18, 1.04), 0.36)
	end)
	task.delay(TOTAL_DURATION - 0.35, function()
		slideOut(kickoff, UDim2.fromScale(0.18, 1.04), 0.28)
	end)
	task.delay(TOTAL_DURATION, function()
		if gui.Parent then gui:Destroy() end
		if onComplete then onComplete() end
	end)
	return gui
end

return Presentation
