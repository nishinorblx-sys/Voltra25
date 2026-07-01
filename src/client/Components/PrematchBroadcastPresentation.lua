local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)
--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local MATCHUP_PANEL_DELAY = 0.85

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local PlayerPortraitService = require(script.Parent.Parent.Services.PlayerPortraitService)

local Presentation = {}
local TOTAL_DURATION = 66.0
local STARTING_XI_SOUND_ONE = "rbxassetid://111250989374137"
local STARTING_XI_SOUND_TWO = "rbxassetid://76843129252399"

local function playPresentationSound(soundId: string, volume: number?)
	local sound = Instance.new("Sound")
	sound.Name = "VTRStartingXIAudio"
	sound.SoundId = soundId
	sound.Volume = volume or .62
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		if sound.Parent then sound:Destroy() end
	end)
	sound:Play()
	task.delay(8, function()
		if sound.Parent then sound:Destroy() end
	end)
end

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
		if child.Name == "VTRPresentationBadgeArt" or child.Name == "BadgeArt" then child:Destroy() end
	end
	local accent = Color3.fromHex("F5F7F2")
	local art = Instance.new("Frame")
	art.Name = "VTRPresentationBadgeArt"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = target.ZIndex + 1
	art.Parent = target
	local shield = Instance.new("Frame")
	shield.Name = "Shield"
	shield.AnchorPoint = Vector2.new(.5, .5)
	shield.Position = UDim2.fromScale(.5, .5)
	shield.Size = UDim2.fromScale(.74, .82)
	shield.BackgroundColor3 = primary
	shield.BorderSizePixel = 0
	shield.ZIndex = art.ZIndex + 1
	shield.Parent = art
	local shieldCorner = Instance.new("UICorner")
	shieldCorner.CornerRadius = UDim.new(.18, 0)
	shieldCorner.Parent = shield
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.AnchorPoint = Vector2.new(.5, .5)
	stripe.Position = UDim2.fromScale(.5, .5)
	stripe.Size = UDim2.fromScale(.28, 1.12)
	stripe.Rotation = -18
	stripe.BackgroundColor3 = accent
	stripe.BackgroundTransparency = .05
	stripe.BorderSizePixel = 0
	stripe.ZIndex = shield.ZIndex + 1
	stripe.Parent = shield
	local cap = Instance.new("Frame")
	cap.Name = "Cap"
	cap.Position = UDim2.fromScale(.13, .08)
	cap.Size = UDim2.fromScale(.74, .22)
	cap.BackgroundColor3 = accent
	cap.BackgroundTransparency = .08
	cap.BorderSizePixel = 0
	cap.ZIndex = shield.ZIndex + 2
	cap.Parent = shield
	local point = Instance.new("Frame")
	point.Name = "Point"
	point.AnchorPoint = Vector2.new(.5, 1)
	point.Position = UDim2.fromScale(.5, 1.06)
	point.Size = UDim2.fromScale(.42, .28)
	point.Rotation = 45
	point.BackgroundColor3 = primary:Lerp(Color3.fromHex("050505"), .24)
	point.BorderSizePixel = 0
	point.ZIndex = shield.ZIndex
	point.Parent = shield
	local outline = Instance.new("UIStroke")
	outline.Color = accent
	outline.Transparency = .18
	outline.Thickness = 1
	outline.Parent = shield
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

local function cleanPosition(value: any): string
	local position = string.upper(tostring(value or ""))
	position = string.gsub(position, "%s+", "")
	if position == "GOALKEEPER" then return "GK" end
	if position == "FULLBACK" then return "FB" end
	if position == "LEFTBACK" then return "LB" end
	if position == "RIGHTBACK" then return "RB" end
	if position == "CENTREBACK" or position == "CENTERBACK" then return "CB" end
	if position == "DEFENSIVEMID" or position == "DEFENSIVEMIDFIELDER" then return "CDM" end
	if position == "ATTACKINGMID" or position == "ATTACKINGMIDFIELDER" then return "CAM" end
	if position == "LEFTMID" then return "LM" end
	if position == "RIGHTMID" then return "RM" end
	if position == "LEFTWING" then return "LW" end
	if position == "RIGHTWING" then return "RW" end
	if position == "STRIKER" or position == "FORWARD" then return "ST" end
	return position
end

local function positionFromEntry(entry: any): string
	if type(entry) ~= "table" then return "" end
	return cleanPosition(entry.Position or entry.position or entry.bestPosition or entry.BestPosition or entry.Pos or entry.pos or entry.Role or entry.role)
end

local function positionFromModel(model: Model?): string
	if not model then return "" end
	return cleanPosition(model:GetAttribute("position") or model:GetAttribute("bestPosition") or model:GetAttribute("Role") or model:GetAttribute("VTRRole"))
end

local function roleKey(position: string): string
	position = cleanPosition(position)
	if position == "GK" then return "GK" end
	if position == "LB" or position == "LWB" then return "LB" end
	if position == "RB" or position == "RWB" then return "RB" end
	if position == "CB" or position == "LCB" or position == "RCB" then return "CB" end
	if position == "CDM" or position == "DM" then return "CDM" end
	if position == "CAM" or position == "AM" then return "CAM" end
	if position == "CM" or position == "LCM" or position == "RCM" then return "CM" end
	if position == "LM" then return "LM" end
	if position == "RM" then return "RM" end
	if position == "LW" then return "LW" end
	if position == "RW" then return "RW" end
	if position == "ST" or position == "CF" or position == "SS" then return "ST" end
	if position == "WINGER" then return "WINGER" end
	if position == "FB" then return "FB" end
	return "OTHER"
end

local function lineGroupForPosition(position: string): string
	local key = roleKey(position)
	if key == "GK" then return "GK" end
	if key == "LB" or key == "RB" or key == "CB" or key == "FB" then return "DEF" end
	if key == "ST" then return "ATT" end
	return "MID"
end

local function formationRoleOrder(position: string): number
	local key = roleKey(position)
	local order = {
		GK = 1,
		LB = 2,
		FB = 3,
		CB = 4,
		RB = 5,
		CDM = 6,
		LM = 7,
		CM = 8,
		RM = 9,
		CAM = 10,
		LW = 11,
		WINGER = 12,
		RW = 13,
		ST = 14,
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
	return string.lower(tostring(player.DisplayName or player.displayName or player.Name or player.name or player.playerName or player.shortName or ""))
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
			for _, model in ipairs(models) do
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
			local fallback = {"GK", "LB", "CB", "CB", "RB", "CDM", "CM", "CAM", "LM", "RM", "ST"}
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
	for _, entry in ipairs(formationEntries(data, side)) do
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
	for index, entry in ipairs(entries) do
		if lineGroupForPosition(entry.Position) == groupName then
			first = first or index
			last = index
		end
	end
	return first or fallbackFirst, last or fallbackLast
end

local function formationText(data: any, side: string): string
	local sideSetup = side == "Home" and data.HomeSetup or data.AwaySetup
	local function valid(value: any): string?
		if type(value) == "string" and value ~= "" then return value end
		return nil
	end
	return valid(side == "Home" and data.HomeFormation or data.AwayFormation)
		or valid(side == "Home" and data.HomeFormationName or data.AwayFormationName)
		or valid(sideSetup and sideSetup.Formation)
		or valid(sideSetup and sideSetup.formation)
		or valid(data.Formation)
		or valid(data.FormationName)
		or ""
end

local function formationSpecRows(name: string): {any}?
	local clean = string.upper(tostring(name or ""))
	clean = string.gsub(clean, "%s+", "")
	if string.find(clean, "4%-2%-3%-1") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 4, Y = .70},
			{Name = "DM", Count = 2, Y = .58},
			{Name = "AM", Count = 3, Y = .38},
			{Name = "FWD", Count = 1, Y = .17},
		}
	elseif string.find(clean, "4%-3%-3") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 4, Y = .70},
			{Name = "MID", Count = 3, Y = .50},
			{Name = "FWD", Count = 3, Y = .20},
		}
	elseif string.find(clean, "4%-4%-2") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 4, Y = .70},
			{Name = "MID", Count = 4, Y = .47},
			{Name = "FWD", Count = 2, Y = .20},
		}
	elseif string.find(clean, "3%-5%-2") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 3, Y = .70},
			{Name = "MID", Count = 5, Y = .47},
			{Name = "FWD", Count = 2, Y = .20},
		}
	elseif string.find(clean, "5%-3%-2") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 5, Y = .70},
			{Name = "MID", Count = 3, Y = .47},
			{Name = "FWD", Count = 2, Y = .20},
		}
	elseif string.find(clean, "3%-4%-3") then
		return {
			{Name = "GK", Count = 1, Y = .88},
			{Name = "DEF", Count = 3, Y = .70},
			{Name = "MID", Count = 4, Y = .48},
			{Name = "FWD", Count = 3, Y = .20},
		}
	end
	return nil
end

local function rowAccepts(rowName: string, position: string): boolean
	local key = roleKey(position)
	if rowName == "GK" then return key == "GK" end
	if rowName == "DEF" then return key == "LB" or key == "RB" or key == "CB" or key == "FB" end
	if rowName == "DM" then return key == "CDM" or key == "CM" end
	if rowName == "AM" then return key == "CAM" or key == "LM" or key == "RM" or key == "LW" or key == "RW" or key == "WINGER" end
	if rowName == "MID" then return key == "CDM" or key == "CM" or key == "CAM" or key == "LM" or key == "RM" end
	if rowName == "FWD" then return key == "ST" or key == "LW" or key == "RW" or key == "WINGER" end
	return false
end

local function horizontalOrder(rowName: string, entry: any): number
	local key = roleKey(entry.Position)
	if rowName == "DEF" then
		if key == "LB" then return 1 end
		if key == "FB" then return 2 end
		if key == "CB" then return 3 + (entry.OriginalIndex or 0) * .01 end
		if key == "RB" then return 8 end
	elseif rowName == "AM" or rowName == "MID" then
		if key == "LM" or key == "LW" then return 1 end
		if key == "CDM" then return 2 end
		if key == "CM" then return 3 end
		if key == "CAM" then return 4 end
		if key == "WINGER" then return 5 + (entry.OriginalIndex or 0) * .01 end
		if key == "RM" or key == "RW" then return 8 end
	elseif rowName == "DM" then
		if key == "CDM" then return 2 + (entry.OriginalIndex or 0) * .01 end
		if key == "CM" then return 3 + (entry.OriginalIndex or 0) * .01 end
	elseif rowName == "FWD" then
		if key == "LW" then return 1 end
		if key == "ST" then return 4 + (entry.OriginalIndex or 0) * .01 end
		if key == "RW" then return 8 end
	end
	return 5 + (entry.OriginalIndex or 0) * .01
end

local function sortRow(rowName: string, row: {any})
	table.sort(row, function(a, b)
		local ax = horizontalOrder(rowName, a)
		local bx = horizontalOrder(rowName, b)
		if ax ~= bx then return ax < bx end
		return (a.OriginalIndex or 0) < (b.OriginalIndex or 0)
	end)
end

local function xFor(rowName: string, index: number, count: number): number
	if count <= 1 then return .50 end
	if rowName == "DEF" and count == 4 then
		local values = {.18, .39, .61, .82}
		return values[index] or .50
	elseif rowName == "DEF" and count == 5 then
		local values = {.12, .30, .50, .70, .88}
		return values[index] or .50
	elseif rowName == "DEF" and count == 3 then
		local values = {.28, .50, .72}
		return values[index] or .50
	elseif rowName == "DM" and count == 2 then
		local values = {.38, .62}
		return values[index] or .50
	elseif rowName == "AM" and count == 3 then
		local values = {.20, .50, .80}
		return values[index] or .50
	elseif rowName == "FWD" and count == 3 then
		local values = {.22, .50, .78}
		return values[index] or .50
	elseif rowName == "FWD" and count == 2 then
		local values = {.40, .60}
		return values[index] or .50
	end
	return .16 + (index - 1) * (.68 / math.max(1, count - 1))
end

local function takeRow(entries: {any}, used: any, rowName: string, count: number, y: number): any
	local row = {}
	for _, entry in ipairs(entries) do
		if not used[entry] and rowAccepts(rowName, entry.Position) and #row < count then
			used[entry] = true
			table.insert(row, entry)
		end
	end
	for _, entry in ipairs(entries) do
		if not used[entry] and #row < count then
			used[entry] = true
			table.insert(row, entry)
		end
	end
	sortRow(rowName, row)
	return {Name = rowName, Entries = row, Y = y}
end

local function dynamicRows(entries: {any}): {any}
	local rowsByName = {GK = {}, DEF = {}, DM = {}, MID = {}, AM = {}, FWD = {}}
	local hasAM = false
	for _, entry in ipairs(entries) do
		local key = roleKey(entry.Position)
		if key == "CAM" or key == "LM" or key == "RM" or key == "LW" or key == "RW" or key == "WINGER" then
			hasAM = true
		end
	end
	for _, entry in ipairs(entries) do
		local key = roleKey(entry.Position)
		local rowName = "MID"
		if key == "GK" then
			rowName = "GK"
		elseif key == "LB" or key == "RB" or key == "CB" or key == "FB" then
			rowName = "DEF"
		elseif key == "ST" then
			rowName = "FWD"
		elseif key == "CAM" or key == "LM" or key == "RM" or key == "LW" or key == "RW" or key == "WINGER" then
			rowName = "AM"
		elseif key == "CDM" or (key == "CM" and hasAM) then
			rowName = "DM"
		end
		table.insert(rowsByName[rowName], entry)
	end
	local output = {}
	local order = {
		{Name = "GK", Y = .88},
		{Name = "DEF", Y = .70},
		{Name = "DM", Y = .58},
		{Name = "MID", Y = .48},
		{Name = "AM", Y = .38},
		{Name = "FWD", Y = .17},
	}
	for _, spec in ipairs(order) do
		local row = rowsByName[spec.Name]
		if row and #row > 0 then
			sortRow(spec.Name, row)
			table.insert(output, {Name = spec.Name, Entries = row, Y = spec.Y})
		end
	end
	return output
end

local function buildDotRows(data: any, side: string): {any}
	local entries = formationEntries(data, side)
	local specRows = formationSpecRows(formationText(data, side))
	if not specRows then
		return dynamicRows(entries)
	end
	local used = {}
	local rows = {}
	for _, spec in ipairs(specRows) do
		table.insert(rows, takeRow(entries, used, spec.Name, spec.Count, spec.Y))
	end
	for _, entry in ipairs(entries) do
		if not used[entry] then
			local key = roleKey(entry.Position)
			local rowName = key == "ST" and "FWD" or lineGroupForPosition(entry.Position) == "DEF" and "DEF" or "MID"
			table.insert(rows, {Name = rowName, Entries = {entry}, Y = rowName == "FWD" and .17 or rowName == "DEF" and .70 or .48})
		end
	end
	return rows
end

local function updateFormationDots(dots: {Frame}, data: any, side: string)
	local rows = buildDotRows(data, side)
	local dotIndex = 1
	for _, row in ipairs(rows) do
		local count = #row.Entries
		for rowIndex, entry in ipairs(row.Entries) do
			local dot = dots[dotIndex]
			if dot then
				dot.Position = UDim2.fromScale(xFor(row.Name, rowIndex, count), row.Y)
				dot:SetAttribute("VTRLineGroup", lineGroupForPosition(entry.Position))
				dot:SetAttribute("VTRPosition", entry.Position)
				dot:SetAttribute("VTRShapeRow", row.Name)
				dot.BackgroundColor3 = Theme.Colors.White
				dot.Size = UDim2.fromOffset(11, 11)
				dot.Visible = true
			end
			dotIndex += 1
		end
	end
	for index = dotIndex, #dots do
		dots[index].Visible = false
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
		playPresentationSound(STARTING_XI_SOUND_ONE,.66)
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
		playPresentationSound(STARTING_XI_SOUND_TWO,.66)
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
