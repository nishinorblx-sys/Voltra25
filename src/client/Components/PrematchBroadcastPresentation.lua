--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local MATCHUP_PANEL_DELAY = 0.85

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local BadgePreview = require(script.Parent.BadgePreview)
local PlayerPortraitService = require(script.Parent.Parent.Services.PlayerPortraitService)
local UISoundService = require(script.Parent.Parent.Services.UISoundService)
local Remotes = require(ReplicatedStorage.VTR.Shared.Remotes)
local FormationConfig = require(ReplicatedStorage.VTR.Shared.FormationConfig)
local CardVisualConfig = require(ReplicatedStorage.VTR.Shared.CardVisualConfig)
local MatchExperienceConfig = require(ReplicatedStorage.VTR.Shared.MatchExperienceConfig)
local MatchPresentationService = require(script:FindFirstAncestor("VTRClient").Services.MatchPresentationService)

local Presentation = {}
local TOTAL_DURATION = 66.0
local STARTING_XI_SOUNDS = {
	"rbxassetid://99361731737732",
}
local introSound: Sound? = nil
local INTRO_BACKGROUND_SOUND = "rbxassetid://127074097075829"
local activeIntroSounds = {}

local function playPresentationSound(soundId: string, volume: number?, looped: boolean?)
	local sound = Instance.new("Sound")
	sound.Name = "VTRPresentationAudio"
	sound.SoundId = soundId
	sound.Volume = volume or .62
	sound.Looped = looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		if sound.Parent then sound:Destroy() end
	end)
	sound:Play()
	return sound
end

local function stopIntroAudio()
	for _, sound in activeIntroSounds do
		if sound and sound.Parent then sound:Destroy() end
	end
	table.clear(activeIntroSounds)
end

function Presentation.StopAudio()
	if UISoundService.StopTransitions then
		UISoundService.StopTransitions()
	end
	stopIntroAudio()
end

local function startIntroAudio(gui: ScreenGui)
	stopIntroAudio()
	table.insert(activeIntroSounds, playPresentationSound(INTRO_BACKGROUND_SOUND, .34, true))
end

local function shortCode(name: string): string
	local words = string.split(string.upper(name), " ")
	if #words >= 2 then
		return string.sub(words[1], 1, 1) .. string.sub(words[2], 1, 2)
	end
	return string.sub(string.upper(name), 1, 3)
end

local function color(value: any, fallback: Color3): Color3
	if typeof(value) == "Color3" then return value end
	if type(value) == "string" then
		local clean = string.gsub(value, "#", "")
		local ok, result = pcall(Color3.fromHex, clean)
		if ok then return result end
	end
	return fallback
end

local function badgeAccent(primary: Color3): Color3
	local bright = Color3.fromHex("F5F7F2")
	local dark = Color3.fromHex("050805")
	local brightness = primary.R + primary.G + primary.B
	return brightness > 1.65 and dark or bright
end

local function teamBadgeIdentity(data: any, side: string): any
	local summary = side == "Home" and data.HomeSummary or data.AwaySummary
	local source = side == "Home" and data.HomeBadgeIdentity or data.AwayBadgeIdentity
	if type(source) ~= "table" and type(summary) == "table" then source = summary.BadgeIdentity or summary.badgeIdentity end
	source = type(source) == "table" and source or {}
	local colors = type(summary) == "table" and summary.colors or nil
	local primary = source.PrimaryColor or (colors and colors.Primary) or (side == "Home" and data.HomeColor or data.AwayColor) or "B7FF1A"
	local secondary = source.SecondaryColor or (colors and colors.Secondary) or "050505"
	local accent = source.AccentColor or (colors and colors.Accent) or "F5F7F2"
	return {
		PrimaryColor = primary,
		SecondaryColor = secondary,
		AccentColor = accent,
		BadgePreset = source.BadgePreset or "Modern",
		BadgeShape = source.BadgeShape or source.Shape or "Shield",
		BadgeSymbol = source.BadgeSymbol or source.Symbol or "Lightning Bolt",
		BadgeColorBehavior = source.BadgeColorBehavior or "Tri Color",
	}
end

local function assetImage(value: any): string?
	local textValue = tostring(value or "")
	if textValue == "" then return nil end
	if string.match(textValue, "^rbxassetid://") then return textValue end
	if tonumber(textValue) then return "rbxassetid://" .. textValue end
	return nil
end

local function teamBadgeImage(data: any, side: string): string?
	local direct = side == "Home" and data.HomeFlagImage or data.AwayFlagImage
	local image = assetImage(direct)
	if image then return image end
	local summary = side == "Home" and data.HomeSummary or data.AwaySummary
	if type(summary) == "table" then
		image = assetImage(summary.FlagImage or summary.flagImage or summary.BadgeImage or summary.badgeImage or summary.LogoImage or summary.logoImage)
		if image then return image end
	end
	local logo = side == "Home" and data.HomeLogo or data.AwayLogo
	return assetImage(logo)
end

local function syncBadgeZ(root: Instance, zIndex: number, strokeLimit: number?)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = zIndex
		elseif strokeLimit and descendant:IsA("UIStroke") then
			descendant.Thickness = math.min(descendant.Thickness, strokeLimit)
		end
	end
end

local function applyPresentationBadge(target: TextLabel, primary: Color3, logoText: string?, identity: any?, strokeLimit: number?, imageId: string?)
	target.Text = ""
	target.BackgroundTransparency = 1
	target.ClipsDescendants = true
	for _, child in target:GetChildren() do
		if child.Name == "VTRPresentationBadgeArt" or child.Name == "VTRPresentationBadgeImage" or child.Name == "BadgeArt" or child.Name == "GeneratedBadge" then child:Destroy() end
	end
	if imageId and imageId ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "VTRPresentationBadgeImage"
		image.BackgroundTransparency = 1
		image.Image = imageId
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		image.ZIndex = target.ZIndex + 1
		image.Parent = target
		return
	end
	if type(identity) == "table" then
		local badge = BadgePreview.new(target, identity, UDim2.fromScale(1, 1))
		badge.Name = "VTRPresentationBadgeArt"
		badge.Position = UDim2.fromScale(0, 0)
		badge.ZIndex = target.ZIndex + 1
		syncBadgeZ(badge, badge.ZIndex, strokeLimit)
		return
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
	local logoValue = tostring(logoText or "")
	local imageId = ""
	if string.match(logoValue, "^rbxassetid://") then
		imageId = logoValue
	elseif tonumber(logoValue) then
		imageId = "rbxassetid://" .. logoValue
	end
	if imageId ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "LogoImage"
		image.BackgroundTransparency = 1
		image.Image = imageId
		image.ScaleType = Enum.ScaleType.Fit
		image.Position = UDim2.fromScale(.16, .17)
		image.Size = UDim2.fromScale(.68, .66)
		image.ZIndex = shield.ZIndex + 4
		image.Parent = shield
	else
		local mark = Instance.new("TextLabel")
		mark.Name = "LogoText"
		mark.BackgroundTransparency = 1
		mark.Text = logoValue ~= "" and string.sub(string.upper(logoValue), 1, 4) or "VTR"
		mark.TextColor3 = accent
		mark.TextSize = 22
		mark.Font = Enum.Font.GothamBlack
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextYAlignment = Enum.TextYAlignment.Center
		mark.Position = UDim2.fromScale(.12, .22)
		mark.Size = UDim2.fromScale(.76, .52)
		mark.ZIndex = shield.ZIndex + 4
		mark.Parent = shield
	end
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
	if position == "LAM" then return "LW" end
	if position == "RAM" then return "RW" end
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

local function modelPlayerIdKey(model: Model?): string
	if not model then return "" end
	return string.lower(tostring(model:GetAttribute("playerId") or model:GetAttribute("cardInstanceId") or ""))
end

local function playerIdKey(player: any): string
	if type(player) ~= "table" then return "" end
	return string.lower(tostring(player.playerId or player.PlayerId or player.cardInstanceId or player.CardInstanceId or player.Id or ""))
end

local function playerNumberFromEntry(player: any, fallback: number): any
	if type(player) ~= "table" then return fallback end
	return player.shirtNumber or player.number or player.ShirtNumber or player.Number or fallback
end

local function playerFromModel(model: Model?, fallbackIndex: number, side: string): any
	if not model then
		return {displayName = "PLAYER", shortName = "PLAYER", overall = 0, bestPosition = "CM", shirtNumber = fallbackIndex, Side = side}
	end
	return {
		playerId = model:GetAttribute("playerId"),
		cardInstanceId = model:GetAttribute("cardInstanceId"),
		displayName = model:GetAttribute("DisplayName") or model.Name,
		shortName = model:GetAttribute("DisplayName") or model.Name,
		overall = model:GetAttribute("overall"),
		bestPosition = model:GetAttribute("position") or model:GetAttribute("bestPosition") or model:GetAttribute("Role") or model:GetAttribute("VTRRole"),
		Position = model:GetAttribute("position") or model:GetAttribute("bestPosition") or model:GetAttribute("Role") or model:GetAttribute("VTRRole"),
		shirtNumber = model:GetAttribute("ShirtNumber") or fallbackIndex,
		number = model:GetAttribute("ShirtNumber") or fallbackIndex,
		rarity = model:GetAttribute("rarity") or model:GetAttribute("Rarity") or "Common",
		cardType = model:GetAttribute("cardType") or model:GetAttribute("CardType") or "Base",
		Side = side,
	}
end

local function completePlayerData(player: any, model: Model?, fallbackIndex: number, side: string): any
	local fallback = playerFromModel(model, fallbackIndex, side)
	if type(player) ~= "table" then
		return fallback
	end
	local result = table.clone(player)
	result.playerId = result.playerId or result.PlayerId or fallback.playerId
	result.cardInstanceId = result.cardInstanceId or result.CardInstanceId or fallback.cardInstanceId
	result.displayName = result.displayName or result.DisplayName or result.Name or result.name or result.playerName or fallback.displayName
	result.shortName = result.shortName or result.ShortName or result.displayName
	result.overall = result.overall or result.Overall or result.Rating or result.rating or fallback.overall
	result.bestPosition = result.bestPosition or result.BestPosition or result.Position or result.position or fallback.bestPosition
	result.Position = result.Position or result.position or result.bestPosition
	result.shirtNumber = playerNumberFromEntry(result, fallbackIndex)
	result.number = result.number or result.shirtNumber
	result.rarity = result.rarity or result.Rarity or fallback.rarity
	result.cardType = result.cardType or result.CardType or fallback.cardType
	result.Side = result.Side or result.side or side
	return result
end

local function entryMatchesModel(player: any, model: Model?): boolean
	if not model or type(player) ~= "table" then return false end
	local playerId = playerIdKey(player)
	if playerId ~= "" and playerId == modelPlayerIdKey(model) then return true end
	local playerKey = playerNameKey(player)
	return playerKey ~= "" and playerKey == modelNameKey(model)
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
		if type(player) == "table" then
			for _, model in ipairs(models) do
				if not usedModels[model] and entryMatchesModel(player, model) then
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
		player = completePlayerData(player, matched, index, side)
		if position == "" then position = positionFromEntry(player) end
		if position == "" then position = positionFromModel(matched) end
		if position == "" then
			local fallback = {"GK", "LB", "CB", "CB", "RB", "CDM", "CM", "CAM", "LM", "RM", "ST"}
			position = fallback[index] or "CM"
		end
		table.insert(result, {Model = matched, Player = player, Position = position, OriginalIndex = index, Side = side})
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

local function formationDefinition(name: string): any?
	local clean = string.upper(tostring(name or ""))
	clean = string.gsub(clean, "%s+", "")
	return FormationConfig.Formations[clean]
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

local function entryForSlot(entriesByIndex: any, entriesBySlot: any, slotName: string, fallbackIndex: number): any
	return entriesBySlot[slotName] or entriesByIndex[fallbackIndex] or {Position = slotName, OriginalIndex = fallbackIndex}
end

local function slotRowsFromFormation(data: any, side: string): {any}?
	local name = formationText(data, side)
	local formation = formationDefinition(name)
	local specRows = formationSpecRows(name)
	if not formation or not specRows then return nil end
	local entriesByIndex = {}
	local entriesBySlot = {}
	for _, entry in ipairs(formationEntries(data, side)) do
		entriesByIndex[entry.OriginalIndex or 0] = entry
		local player = entry.Player or {}
		local slotName = player.FormationSlot or player.PositionSlot or player.SquadSlot
		if type(slotName) == "string" and slotName ~= "" then
			entriesBySlot[slotName] = entry
		end
	end
	local usedSlots = {}
	local rows = {}
	for _, spec in ipairs(specRows) do
		local rowSlots = {}
		for index, slotName in ipairs(FormationConfig.Order) do
			local definition = formation[slotName]
			local label = definition and tostring(definition.Label or definition.Expected or slotName) or slotName
			if definition and not usedSlots[slotName] and rowAccepts(spec.Name, label) and #rowSlots < spec.Count then
				usedSlots[slotName] = true
				local entry = entryForSlot(entriesByIndex, entriesBySlot, slotName, index)
				entry.Position = tostring(type(entry.Position) == "string" and entry.Position ~= "" and entry.Position or label)
				table.insert(rowSlots, {Entry = entry, X = definition.X, Y = definition.Y, Slot = slotName, Label = label})
			end
		end
		table.sort(rowSlots, function(a, b)
			if a.X ~= b.X then return a.X < b.X end
			return tostring(a.Slot) < tostring(b.Slot)
		end)
		table.insert(rows, {Name = spec.Name, Slots = rowSlots, Y = spec.Y})
	end
	return rows
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
	local slotRows = slotRowsFromFormation(data, side)
	if slotRows then
		return slotRows
	end
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

local function entriesForGroup(data: any, side: string, groupName: string): {any}
	local rows = buildDotRows(data, side)
	local result = {}
	for _, row in ipairs(rows) do
		local rowGroup = row.Name == "FWD" and "ATT" or row.Name == "GK" and "GK" or row.Name == "DEF" and "DEF" or "MID"
		if rowGroup == groupName then
			if row.Slots then
				for _, slot in ipairs(row.Slots) do
					table.insert(result, slot.Entry)
				end
			else
				for _, entry in ipairs(row.Entries or {}) do
					table.insert(result, entry)
				end
			end
		end
	end
	return result
end

local function updateFormationDots(dots: {Frame}, data: any, side: string)
	local rows = buildDotRows(data, side)
	local dotIndex = 1
	for _, row in ipairs(rows) do
		local rowGroup = row.Name == "FWD" and "ATT" or row.Name == "GK" and "GK" or row.Name == "DEF" and "DEF" or "MID"
		local slots = row.Slots
		if slots then
			for _, slot in ipairs(slots) do
				local dot = dots[dotIndex]
				if dot then
					local entry = slot.Entry or {}
					dot.Position = UDim2.fromScale(slot.X, slot.Y)
					dot:SetAttribute("VTRLineGroup", rowGroup)
					dot:SetAttribute("VTRPosition", tostring(slot.Label or entry.Position or slot.Slot))
					dot:SetAttribute("VTRShapeRow", row.Name)
					dot.BackgroundColor3 = Theme.Colors.White
					dot.Size = UDim2.fromOffset(11, 11)
					dot.Visible = true
				end
				dotIndex += 1
			end
			continue
		end
		local count = #row.Entries
		for rowIndex, entry in ipairs(row.Entries or {}) do
			local dot = dots[dotIndex]
			if dot then
				dot.Position = UDim2.fromScale(xFor(row.Name, rowIndex, count), row.Y)
				dot:SetAttribute("VTRLineGroup", rowGroup)
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
	stroke.Color = Theme.Colors.Electric
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

local function addPreviewKitGeometry(clone: Model, kit: any?)
	local torso = clone:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then return end
	local existingPattern = torso:FindFirstChild("VTRKitPattern")
	if existingPattern then
		kit = nil
	end
	local function clampScale(value: number, minimum: number, maximum: number): number
		return math.clamp(value, minimum, maximum)
	end
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
		local widthScale = clampScale(size.X.Scale, 0.02, 0.98)
		local heightScale = clampScale(size.Y.Scale, 0.02, 0.98)
		local xScale = clampScale(pos.X.Scale, widthScale * 0.5, 1 - widthScale * 0.5)
		local yScale = clampScale(pos.Y.Scale, heightScale * 0.5, 1 - heightScale * 0.5)
		patch.Size = Vector3.new(math.max(0.035, torso.Size.X * widthScale), math.max(0.035, torso.Size.Y * heightScale), 0.018)
		local x = (xScale - 0.5) * torso.Size.X
		local y = (0.5 - yScale) * torso.Size.Y
		patch.CFrame = torso.CFrame * CFrame.new(x, y, -torso.Size.Z * 0.5 - 0.012) * CFrame.Angles(0, 0, math.rad(rotation or 0))
		patch.Parent = clone
	end
	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") and string.sub(desc.Name, 1, 11) == "PreviewKit_" then
			desc:Destroy()
		elseif type(kit) == "table" and desc:IsA("SurfaceGui") and (desc.Name == "VTRKitPattern" or desc.Name == "BackPrint" or desc.Name == "ChestBadge") then
			desc:Destroy()
		elseif type(kit) == "table" and desc:IsA("BasePart") and desc.Name == "ChestBadgePlate" then
			desc:Destroy()
		end
	end
	if type(kit) == "table" then
		local primary = color(kit.Primary or kit.primaryColor or kit.PrimaryColor, Color3.fromHex("B7FF1A"))
		local secondary = color(kit.Secondary or kit.secondaryColor or kit.SecondaryColor, Color3.fromHex("111111"))
		local accent = color(kit.Accent or kit.accentColor or kit.AccentColor, Color3.fromHex("D9D9D9"))
		local style = tostring(kit.Style or kit.KitStyle or kit.kitStyle or "Solid")
		torso.Color = primary
		for _, name in {"Left Arm", "Right Arm"} do local part = clone:FindFirstChild(name); if part and part:IsA("BasePart") then part.Color = primary end end
		for _, name in {"Left Leg", "Right Leg"} do local part = clone:FindFirstChild(name); if part and part:IsA("BasePart") then part.Color = secondary end end
		if style == "Vertical Stripes" then
			for index = 1, 5 do if index % 2 == 0 then frontPatch("Stripe", UDim2.fromScale((index - .5) / 5, .5), UDim2.fromScale(.18, .92), secondary, 0) end end
		elseif style == "Horizontal Stripes" or style == "Hoops" then
			for index = 1, 5 do frontPatch("Hoop", UDim2.fromScale(.5, index / 6), UDim2.fromScale(.92, .08), secondary, 0) end
		elseif style == "Diagonal Sash" then
			frontPatch("Sash", UDim2.fromScale(.5, .5), UDim2.fromScale(.16, .96), secondary, -34)
			frontPatch("SashAccent", UDim2.fromScale(.55, .5), UDim2.fromScale(.032, .92), accent, -34)
		elseif style == "Split" then
			frontPatch("Split", UDim2.fromScale(.75, .5), UDim2.fromScale(.5, 1), secondary, 0)
		elseif style == "Lightning Trim" then
			frontPatch("Bolt1", UDim2.fromScale(.4, .3), UDim2.fromScale(.08, .55), accent, 25)
			frontPatch("Bolt2", UDim2.fromScale(.52, .62), UDim2.fromScale(.08, .55), accent, -28)
		elseif style == "Volt Pattern" then
			for index = 1, 3 do frontPatch("Volt", UDim2.fromScale(.25 * index, .5), UDim2.fromScale(.05, .94), index == 2 and accent or secondary, index % 2 == 0 and -22 or 22) end
		elseif style == "Checker Accent" then
			for y = 1, 5 do for x = 1, 4 do if (x + y) % 2 == 0 then frontPatch("Check", UDim2.fromScale((x - .5) / 4, (y - .5) / 5), UDim2.fromScale(.25, .2), secondary, 0) end end end
		elseif style == "Chevron" then
			frontPatch("ChevronLeft", UDim2.fromScale(.39, .5), UDim2.fromScale(.075, 1), secondary, -43)
			frontPatch("ChevronRight", UDim2.fromScale(.61, .5), UDim2.fromScale(.075, 1), secondary, 43)
			frontPatch("ChevronAccentLeft", UDim2.fromScale(.39, .55), UDim2.fromScale(.024, .86), accent, -43)
			frontPatch("ChevronAccentRight", UDim2.fromScale(.61, .55), UDim2.fromScale(.024, .86), accent, 43)
		elseif style == "Racing Stripe" then
			frontPatch("CenterStripe", UDim2.fromScale(.5, .5), UDim2.fromScale(.16, .94), secondary, 0)
			frontPatch("LeftPin", UDim2.fromScale(.39, .5), UDim2.fromScale(.025, .94), accent, 0)
			frontPatch("RightPin", UDim2.fromScale(.61, .5), UDim2.fromScale(.025, .94), accent, 0)
		elseif style == "Volt Halves" then
			frontPatch("HalfPanel", UDim2.fromScale(.25, .5), UDim2.fromScale(.5, .96), secondary, 0)
			frontPatch("HalfSlash", UDim2.fromScale(.5, .5), UDim2.fromScale(.032, .96), accent, -18)
		elseif style == "Voltra Founder" then
			frontPatch("FounderChevronLeft", UDim2.fromScale(.34, .36), UDim2.fromScale(.055, .72), Color3.fromRGB(18, 18, 18), -48)
			frontPatch("FounderChevronRight", UDim2.fromScale(.66, .36), UDim2.fromScale(.055, .72), Color3.fromRGB(18, 18, 18), 48)
			frontPatch("FounderCoreLeft", UDim2.fromScale(.37, .48), UDim2.fromScale(.045, .66), Color3.fromRGB(35, 35, 35), -48)
			frontPatch("FounderCoreRight", UDim2.fromScale(.63, .48), UDim2.fromScale(.045, .66), Color3.fromRGB(35, 35, 35), 48)
			frontPatch("FounderSideLeft", UDim2.fromScale(.18, .56), UDim2.fromScale(.025, .72), accent, 0)
			frontPatch("FounderSideRight", UDim2.fromScale(.82, .56), UDim2.fromScale(.025, .72), accent, 0)
			frontPatch("FounderHem", UDim2.fromScale(.5, .92), UDim2.fromScale(.94, .055), accent, 0)
		elseif style == "Voltra Limited" then
			frontPatch("LimitedTextureA", UDim2.fromScale(.47, .58), UDim2.fromScale(.028, .92), Color3.fromRGB(15, 15, 15), -26)
			frontPatch("LimitedTextureB", UDim2.fromScale(.57, .54), UDim2.fromScale(.022, .86), Color3.fromRGB(20, 20, 20), -26)
			frontPatch("LimitedSideLeft", UDim2.fromScale(.16, .56), UDim2.fromScale(.022, .72), accent, 0)
			frontPatch("LimitedSideRight", UDim2.fromScale(.84, .56), UDim2.fromScale(.022, .72), accent, 0)
			frontPatch("LimitedHem", UDim2.fromScale(.5, .93), UDim2.fromScale(.94, .045), accent, 0)
		elseif style == "Voltra Lightning" then
			for index = 0, 4 do
				local y = .18 + index * .17
				frontPatch("DarkCrack", UDim2.fromScale(.5, y), UDim2.fromScale(.028, .92), Color3.fromRGB(22, 22, 22), -64)
				frontPatch("LightningCrack", UDim2.fromScale(.32 + (index % 2) * .22, y + .04), UDim2.fromScale(.026, .62), accent, -42 + index * 8)
			end
			frontPatch("MainLightning", UDim2.fromScale(.48, .55), UDim2.fromScale(.055, .96), accent, -36)
			frontPatch("LightningCore", UDim2.fromScale(.48, .55), UDim2.fromScale(.018, .92), Color3.fromRGB(230, 255, 120), -36)
		elseif style == "Voltra Gradient" then
			for index = 1, 6 do
				frontPatch("GradientTexture", UDim2.fromScale(index / 7, .62), UDim2.fromScale(.012, .88), Color3.fromRGB(18, 18, 18), -18)
			end
			frontPatch("GradientGlow", UDim2.fromScale(.5, .78), UDim2.fromScale(.9, .34), secondary, 0)
			frontPatch("GradientSideLeft", UDim2.fromScale(.16, .58), UDim2.fromScale(.022, .74), accent, 0)
			frontPatch("GradientSideRight", UDim2.fromScale(.84, .58), UDim2.fromScale(.022, .74), accent, 0)
			frontPatch("GradientBottomGlow", UDim2.fromScale(.5, .91), UDim2.fromScale(.94, .08), accent, 0)
		end
		return
	end
	local pattern = torso:FindFirstChild("VTRKitPattern")
	local root = pattern and pattern:FindFirstChildWhichIsA("Frame")
	if not root then return end
	for _, child in root:GetChildren() do
		if child:IsA("Frame") then
			frontPatch(child.Name, child.Position, child.Size, child.BackgroundColor3, child.Rotation)
		end
	end
end

local function addPreviewFaceGeometry(clone: Model)
	local head = clone:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	for _, child in clone:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 12) == "PreviewFace_" then child:Destroy() end
	end
	local faceGui = head:FindFirstChild("VTRFace")
	local canvas = faceGui and faceGui:FindFirstChildWhichIsA("Frame")
	local function plate(name: string, pos: UDim2, size: UDim2, colorValue: Color3, rotation: number?, transparency: number?)
		local part = Instance.new("Part")
		part.Name = "PreviewFace_" .. name
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = colorValue
		part.Transparency = transparency or 0
		part.Size = Vector3.new(math.max(0.035, head.Size.X * math.clamp(size.X.Scale, 0.015, 0.7)), math.max(0.02, head.Size.Y * math.clamp(size.Y.Scale, 0.012, 0.24)), 0.018)
		local x = (math.clamp(pos.X.Scale, 0.08, 0.92) - 0.5) * head.Size.X
		local y = (0.5 - math.clamp(pos.Y.Scale, 0.08, 0.92)) * head.Size.Y
		part.CFrame = head.CFrame * CFrame.new(x, y, -head.Size.Z * 0.5 - 0.014) * CFrame.Angles(0, 0, math.rad(rotation or 0))
		part.Parent = clone
	end
	if canvas then
		for _, item in canvas:GetChildren() do
			if item:IsA("Frame") then
				plate(item.Name, item.Position, item.Size, item.BackgroundColor3, item.Rotation, item.BackgroundTransparency)
			end
		end
		return
	end
	local ink = Color3.fromRGB(20, 18, 17)
	plate("LeftEye", UDim2.fromScale(.35, .42), UDim2.fromScale(.11, .06), ink)
	plate("RightEye", UDim2.fromScale(.65, .42), UDim2.fromScale(.11, .06), ink)
	plate("Mouth", UDim2.fromScale(.5, .72), UDim2.fromScale(.24, .035), Color3.fromRGB(91, 39, 38))
end

local function showPlayerPreview(viewport: ViewportFrame, model: Model?, kit: any?)
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
	addPreviewKitGeometry(clone, kit)
	addPreviewFaceGeometry(clone)
	clone.Parent = world
	clone:PivotTo(CFrame.new(0, 0, 0))
	local center, size = clone:GetBoundingBox()
	local height = math.max(size.Y, 5)
	camera.FieldOfView = 36
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, height * 0.12, -12), center.Position + Vector3.new(0, -height * 0.03, 0))
end

local function lineupData(data: any, side: string): {any}
	return side == "Home" and (data.HomeLineup or {}) or (data.AwayLineup or {})
end

local function kitForEntry(data: any, entry: any): any?
	local player = entry and entry.Player
	local model = entry and entry.Model
	if type(player) == "table" then
		local playerKit = player.KitData or player.kitData or player.Kit or player.kit or player.TeamKit or player.teamKit
		if type(playerKit) == "table" then return playerKit end
	end
	local entryKit = entry and (entry.KitData or entry.kitData or entry.Kit or entry.kit)
	if type(entryKit) == "table" then return entryKit end
	local playerSide = type(player) == "table" and (player.Side or player.side or player.TeamSide or player.teamSide or player.VTRTeam) or nil
	local modelSide = model and (model:GetAttribute("teamSide") or model:GetAttribute("VTRTeam"))
	local side = tostring((entry and entry.Side) or playerSide or modelSide or "Home")
	local directKit = side == "Away" and data.AwayKitData or data.HomeKitData
	if type(directKit) == "table" then return directKit end
	local summary = side == "Away" and data.AwaySummary or data.HomeSummary
	if type(summary) == "table" then
		local summaryKit = side == "Away" and (summary.AwayKitData or summary.awayKitData) or (summary.HomeKitData or summary.homeKitData)
		if type(summaryKit) == "table" then return summaryKit end
		local kits = summary.kits or summary.Kits
		if type(kits) == "table" then
			local named = side == "Away" and (kits.Away or kits.away) or (kits.Home or kits.home)
			if type(named) == "table" then return named end
		end
	end
	return nil
end

local function playerOverall(playerData: any, model: Model?, fallback: number?): number
	local value = type(playerData) == "table" and (playerData.overall or playerData.Overall or playerData.Rating or playerData.rating) or nil
	value = value or (model and model:GetAttribute("overall")) or fallback or 0
	return math.clamp(math.floor((tonumber(value) or 0) + 0.5), 0, 99)
end

local function playerRarityColor(playerData: any): Color3
	if type(playerData) ~= "table" then
		return Theme.Colors.Electric
	end
	local rarity = tostring(playerData.rarity or playerData.Rarity or "Common")
	local cardType = tostring(playerData.cardType or playerData.CardType or "Base")
	local visual = CardVisualConfig.Get(rarity, cardType)
	return visual and (visual.trimColor or visual.primaryColor) or Theme.Colors.Electric
end

local function showPlayerGroupPreview(container: Frame, models: {Model}, players: {any}, kits: {any}, firstIndex: number, lastIndex: number)
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
			local kit = kits[playerIndex]
			local slot = Instance.new("CanvasGroup")
			slot.BackgroundColor3 = Color3.fromHex("070A06")
			slot.BackgroundTransparency = 0.18
			local targetPosition = UDim2.fromScale(startX + (slotWidth + gap) * (order - 1), 0)
			slot.Position = UDim2.fromScale(targetPosition.X.Scale + 0.08, 0)
			slot.Size = UDim2.fromScale(slotWidth, 1)
			slot.GroupTransparency = 1
			slot.ZIndex = 207
			slot.Parent = container
			local slotCorner = Instance.new("UICorner")
			slotCorner.CornerRadius = UDim.new(0, 8)
			slotCorner.Parent = slot
			local slotStroke = Instance.new("UIStroke")
			slotStroke.Color = playerRarityColor(playerData)
			slotStroke.Transparency = 0.18
			slotStroke.Thickness = count == 1 and 2 or 1.25
			slotStroke.Parent = slot

			local shirtNumber = model and tostring(model:GetAttribute("ShirtNumber") or playerIndex) or tostring(playerIndex)
			local overallValue = playerOverall(playerData, model, 0)
			local overallBadge = Instance.new("Frame")
			overallBadge.Name = "LineupOverallBadge"
			overallBadge.BackgroundColor3 = slotStroke.Color
			overallBadge.BackgroundTransparency = 0.03
			overallBadge.BorderSizePixel = 0
			overallBadge.Position = UDim2.fromOffset(8, 8)
			overallBadge.Size = count == 1 and UDim2.fromOffset(54, 34) or UDim2.fromOffset(42, 28)
			overallBadge.ZIndex = 214
			overallBadge.Parent = slot
			local overallCorner = Instance.new("UICorner")
			overallCorner.CornerRadius = UDim.new(0, 6)
			overallCorner.Parent = overallBadge
			local overallText = Instance.new("TextLabel")
			overallText.Name = "OverallValue"
			overallText.BackgroundTransparency = 1
			overallText.AnchorPoint = Vector2.new(0, 0)
			overallText.Position = UDim2.fromOffset(0, 1)
			overallText.Size = UDim2.new(1, 0, 0, count == 1 and 21 or 17)
			overallText.Text = tostring(overallValue)
			overallText.TextColor3 = Theme.Colors.Black
			overallText.TextSize = count == 1 and 20 or 14
			overallText.TextWrapped = false
			overallText.TextScaled = false
			overallText.Font = Theme.Fonts.Display
			overallText.TextXAlignment = Enum.TextXAlignment.Center
			overallText.TextYAlignment = Enum.TextYAlignment.Center
			overallText.ZIndex = 215
			overallText:SetAttribute("VTRKeepLineupNumberStack", true)
			overallText.Parent = overallBadge
			local overallSub = Instance.new("TextLabel")
			overallSub.Name = "OverallCaption"
			overallSub.BackgroundTransparency = 1
			overallSub.AnchorPoint = Vector2.new(0, 0)
			overallSub.Position = UDim2.new(0, 0, 1, count == 1 and -13 or -11)
			overallSub.Size = UDim2.new(1, 0, 0, count == 1 and 11 or 9)
			overallSub.Text = "OVR"
			overallSub.TextColor3 = Theme.Colors.Black
			overallSub.TextSize = count == 1 and 8 or 6
			overallSub.TextWrapped = false
			overallSub.TextScaled = false
			overallSub.Font = Theme.Fonts.Strong
			overallSub.TextXAlignment = Enum.TextXAlignment.Center
			overallSub.TextYAlignment = Enum.TextYAlignment.Center
			overallSub.ZIndex = 215
			overallSub:SetAttribute("VTRKeepLineupNumberStack", true)
			overallSub.Parent = overallBadge
			local watermark = label(slot, shirtNumber, UDim2.fromScale(0, -0.04), UDim2.fromScale(1, 0.55), count == 1 and 150 or 112, Theme.Colors.White, Theme.Fonts.Display)
			watermark.Name = "LineupKitWatermark"
			watermark:SetAttribute("VTRKeepLineupNumberStack", true)
			watermark.TextTransparency = 0.72
			watermark.TextXAlignment = Enum.TextXAlignment.Center
			watermark.ZIndex = 207

			if model then
				local viewport = Instance.new("ViewportFrame")
				viewport.BackgroundTransparency = 1
				viewport.Position = UDim2.fromScale(0.03, 0.07)
				viewport.Size = UDim2.fromScale(0.94, 0.68)
				viewport.Ambient = Color3.fromHex("D4E4BE")
				viewport.LightColor = Color3.fromHex("F3F7EE")
				viewport.LightDirection = Vector3.new(-0.7, -1, -0.8)
				viewport.ZIndex = 209
				viewport.Parent = slot
				showPlayerPreview(viewport, model, kit)
			elseif playerData and playerData.appearance then
				local portrait = PlayerPortraitService.new(slot, playerData, UDim2.fromScale(1, 0.70), false)
				portrait.Position = UDim2.fromScale(0, 0.07)
				portrait.BackgroundTransparency = 1
				portrait.ZIndex = 209
			end

			local displayName = model and playerName(model) or (playerData and tostring(playerData.displayName or playerData.shortName or playerData.name or playerData.Name or "PLAYER")) or "PLAYER"
			local nameLabel = label(slot, string.upper(displayName), UDim2.fromScale(0.02, 0.78), UDim2.fromScale(0.96, 0.10), count == 1 and 22 or 15, Theme.Colors.White, Theme.Fonts.Strong)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Center
			local numberLabel = label(slot, shirtNumber, UDim2.fromScale(0, 0.885), UDim2.fromScale(1, 0.065), count == 1 and 24 or 17, Theme.Colors.Electric, Theme.Fonts.Display)
			numberLabel.Name = "LineupKitNumber"
			numberLabel:SetAttribute("VTRKeepLineupNumberStack", true)
			numberLabel.TextXAlignment = Enum.TextXAlignment.Center
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

local function showEntryGroupPreview(container: Frame, data: any, entries: {any})
	local models = {}
	local players = {}
	local kits = {}
	for _, entry in entries do
		table.insert(models, entry.Model)
		table.insert(players, entry.Player)
		table.insert(kits, kitForEntry(data, entry))
	end
	showPlayerGroupPreview(container, models, players, kits, 1, math.max(1, #entries))
end

function Presentation.Duration(profile: any?): number
	return tonumber(MatchExperienceConfig.Get(profile).Duration) or 8
end

function Presentation.Play(data: any, onComplete: (() -> ())?)
	local profile = MatchExperienceConfig.Normalize(data and data.PresentationProfile)
	local presentation = MatchExperienceConfig.Get(profile)
	local presentationDuration = math.max(1, tonumber(data and data.PresentationDuration) or tonumber(presentation.Duration) or 8)
	if profile == "Acquisition" then
		local createdAt = tonumber(Players.LocalPlayer:GetAttribute("VTRPresentationOverlayCreatedAt")) or os.clock()
		presentationDuration = math.clamp(presentationDuration - math.max(0, os.clock() - createdAt), 0.65, presentationDuration)
	end
	local gui, host, shouldStart = MatchPresentationService.PrepareRuntime(data, profile)
	if not shouldStart then return gui end
	startIntroAudio(gui)
	local cancelled = false
	local skipUnlockAt = os.clock() + math.max(0, tonumber(data.PrematchSkipDelay) or tonumber(presentation.SkipLock) or 0)
	gui.Destroying:Connect(function()
		cancelled = true
		Presentation.StopAudio()
	end)
	local timelineScale = profile == "Broadcast" and presentationDuration / TOTAL_DURATION or 1
	local function schedule(delaySeconds: number, callback: () -> ())
		task.delay(math.max(0, delaySeconds * timelineScale), function()
			if cancelled or not gui.Parent then return end
			callback()
		end)
	end

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 200
	root.Parent = host
	local actionRemote: RemoteEvent? = nil
	local skipSent = false
	local skipButtons: {TextButton} = {}
	local function skipText(): string
		local remaining = math.ceil(skipUnlockAt - os.clock())
		if remaining > 0 then
			return "SKIP IN " .. tostring(remaining)
		end
		return UserInputService.TouchEnabled and "SKIP" or "SPACE TO SKIP"
	end
	local function updateSkipButtons()
		local text = skipSent and "SKIP 1/2" or skipText()
		for _, button in skipButtons do
			if button.Parent then
				button.Text = text
				button.AutoButtonColor = os.clock() >= skipUnlockAt and not skipSent
				button.TextTransparency = os.clock() < skipUnlockAt and 0.18 or 0
			end
		end
	end
	local function requestSkip(button: GuiButton?)
		if skipSent then return end
		if os.clock() < skipUnlockAt then
			updateSkipButtons()
			return
		end
		skipSent = true
		if not actionRemote then
			pcall(function()
				actionRemote = select(1, Remotes.Wait())
			end)
		end
		if actionRemote then
			actionRemote:FireServer({Type = "PrematchSkip"})
		end
		if button then
			button.Text = "SKIP 1/2"
		end
		updateSkipButtons()
	end
	task.spawn(function()
		pcall(function()
			actionRemote = select(1, Remotes.Wait())
		end)
	end)
	if not UserInputService.TouchEnabled then
		local skipHint = Instance.new("TextButton")
		skipHint.Name = "KeyboardSkipIntroHint"
		skipHint.AnchorPoint = Vector2.new(1, 0)
		skipHint.Position = UDim2.new(1, -18, 0, 18)
		skipHint.Size = UDim2.fromOffset(190, 42)
		skipHint.BackgroundColor3 = Theme.Colors.Black
		skipHint.BackgroundTransparency = .12
		skipHint.BorderSizePixel = 0
		skipHint.AutoButtonColor = false
		skipHint.Text = "SPACE TO SKIP"
		skipHint.TextColor3 = Theme.Colors.White
		skipHint.TextSize = 14
		skipHint.Font = Theme.Fonts.Body
		skipHint.ZIndex = 260
		skipHint.Parent = root
		table.insert(skipButtons, skipHint)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = skipHint
		skipHint.Activated:Connect(function()
			requestSkip(skipHint)
		end)
	end
	if UserInputService.TouchEnabled then
		local skip = Instance.new("TextButton")
		skip.Name = "MobileSkipIntro"
		skip.AnchorPoint = Vector2.new(1, 0)
		skip.Position = UDim2.new(1, -18, 0, 18)
		skip.Size = UDim2.fromOffset(128, 42)
		skip.BackgroundColor3 = Theme.Colors.Black
		skip.BackgroundTransparency = .12
		skip.BorderSizePixel = 0
		skip.AutoButtonColor = false
		skip.Text = "SKIP"
		skip.TextColor3 = Theme.Colors.White
		skip.TextSize = 14
		skip.Font = Theme.Fonts.Body
		skip.ZIndex = 260
		skip.Parent = root
		table.insert(skipButtons, skip)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = skip
		skip.Activated:Connect(function()
			requestSkip(skip)
		end)
	end
	updateSkipButtons()
	task.spawn(function()
		while not cancelled and gui.Parent and not skipSent and os.clock()<skipUnlockAt do
			updateSkipButtons()
			task.wait(.25)
		end
		if not cancelled and gui.Parent then updateSkipButtons()end
	end)

	local home = tostring(data.Home or "HOME")
	local away = tostring(data.Away or "AWAY")
	local homeColor = color(data.HomeColor, Theme.Colors.Electric)
	local awayColor = color(data.AwayColor, Theme.Colors.Silver)
	local setup = type(data.Setup) == "table" and data.Setup or {}
	if profile ~= "Broadcast" then
		local shade = Instance.new("Frame")
		shade.BackgroundColor3 = Theme.Colors.Black
		shade.BackgroundTransparency = profile == "Acquisition" and .32 or .2
		shade.BorderSizePixel = 0
		shade.Size = UDim2.fromScale(1, 1)
		shade.ZIndex = 201
		shade.Parent = root
		local card = Instance.new("CanvasGroup")
		card.Name = "MatchPresentationCard"
		card.AnchorPoint = Vector2.new(.5, .5)
		card.Position = UDim2.fromScale(.5, .5)
		card.Size = UDim2.fromScale(.72, .42)
		card.BackgroundColor3 = Theme.Colors.Black
		card.BackgroundTransparency = .06
		card.BorderSizePixel = 0
		card.GroupTransparency = 1
		card.ZIndex = 204
		card.Parent = root
		local constraint = Instance.new("UISizeConstraint")
		constraint.MinSize = Vector2.new(310, 210)
		constraint.MaxSize = Vector2.new(920, 440)
		constraint.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Colors.Electric
		stroke.Thickness = 1
		stroke.Transparency = .24
		stroke.Parent = card
		local rail = Instance.new("Frame")
		rail.BackgroundColor3 = Theme.Colors.Electric
		rail.BorderSizePixel = 0
		rail.Size = UDim2.new(1, 0, 0, 4)
		rail.ZIndex = 205
		rail.Parent = card
		local title = label(card, profile == "Acquisition" and "YOUR FIRST MATCH" or "MATCHDAY", UDim2.fromScale(.08, .06), UDim2.fromScale(.84, .12), 15, Theme.Colors.Electric, Theme.Fonts.Strong)
		title.TextXAlignment = Enum.TextXAlignment.Center
		local homeBadge = label(card, tostring(data.HomeLogo or shortCode(home)), UDim2.fromScale(.08, .25), UDim2.fromScale(.18, .28), 26, Theme.Colors.White, Theme.Fonts.Display)
		homeBadge.BackgroundColor3 = homeColor
		homeBadge.BackgroundTransparency = 0
		homeBadge.TextXAlignment = Enum.TextXAlignment.Center
		applyPresentationBadge(homeBadge, homeColor, tostring(data.HomeLogo or "V"), teamBadgeIdentity(data, "Home"), 3, teamBadgeImage(data, "Home"))
		local awayBadge = label(card, tostring(data.AwayLogo or shortCode(away)), UDim2.fromScale(.74, .25), UDim2.fromScale(.18, .28), 26, Theme.Colors.White, Theme.Fonts.Display)
		awayBadge.BackgroundColor3 = awayColor
		awayBadge.BackgroundTransparency = 0
		awayBadge.TextXAlignment = Enum.TextXAlignment.Center
		applyPresentationBadge(awayBadge, awayColor, tostring(data.AwayLogo or "V"), teamBadgeIdentity(data, "Away"), 3, teamBadgeImage(data, "Away"))
		local homeName = label(card, string.upper(home), UDim2.fromScale(.03, .58), UDim2.fromScale(.3, .12), 19, Theme.Colors.White, Theme.Fonts.Display)
		homeName.TextXAlignment = Enum.TextXAlignment.Center
		local awayName = label(card, string.upper(away), UDim2.fromScale(.67, .58), UDim2.fromScale(.3, .12), 19, Theme.Colors.White, Theme.Fonts.Display)
		awayName.TextXAlignment = Enum.TextXAlignment.Center
		local versus = label(card, "VS", UDim2.fromScale(.42, .34), UDim2.fromScale(.16, .18), 30, Theme.Colors.Electric, Theme.Fonts.Display)
		versus.TextXAlignment = Enum.TextXAlignment.Center
		local meta = label(card, profile == "Acquisition" and "READY TO PLAY" or string.upper(tostring(setup.StadiumName or setup.StadiumId or "VOLTRA ARENA")), UDim2.fromScale(.15, .78), UDim2.fromScale(.7, .1), 12, Theme.Colors.Silver, Theme.Fonts.Strong)
		meta.TextXAlignment = Enum.TextXAlignment.Center
		TweenService:Create(card, TweenInfo.new(.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
		schedule(presentationDuration - .3, function()
			TweenService:Create(card, TweenInfo.new(.25), {GroupTransparency = 1}):Play()
		end)
		schedule(presentationDuration, function()
			Presentation.StopAudio()
			MatchPresentationService.Complete(false)
			if onComplete then onComplete() end
		end)
		return gui
	end
	local stadiumLevel = setup.CampaignAscension == true and math.clamp(math.floor(tonumber(setup.StadiumAscensionLevel) or 0), 0, 3) or 0
	if stadiumLevel >= 1 then
		local touch = UserInputService.TouchEnabled
		local ascensionBanner = Instance.new("CanvasGroup")
		ascensionBanner.Name = "AscensionBanner"
		ascensionBanner.AnchorPoint = touch and Vector2.zero or Vector2.new(0.5, 0)
		ascensionBanner.Position = touch and UDim2.fromOffset(12, 70) or UDim2.fromScale(0.5, 0.035)
		ascensionBanner.Size = touch and UDim2.new(1, -164, 0, 58) or UDim2.new(0.48, 0, 0, 62)
		ascensionBanner.BackgroundColor3 = Theme.Colors.Black
		ascensionBanner.BackgroundTransparency = 0.08
		ascensionBanner.BorderSizePixel = 0
		ascensionBanner.GroupTransparency = workspace:GetAttribute("VTRReducedMotion") == true and 0 or 1
		ascensionBanner.ZIndex = 244
		ascensionBanner.Parent = root
		local bannerStroke = Instance.new("UIStroke")
		bannerStroke.Color = stadiumLevel >= 2 and homeColor or Theme.Colors.Electric
		bannerStroke.Thickness = stadiumLevel >= 3 and 2 or 1
		bannerStroke.Transparency = 0.12
		bannerStroke.Parent = ascensionBanner
		local bannerTitle = setup.AscensionPromotionFinal == true and stadiumLevel >= 3 and "ASCENSION  |  PROMOTION FINAL" or "VOLTRA ASCENSION"
		local banner = label(ascensionBanner, bannerTitle, UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.92, 0.45), touch and 12 or 18, Theme.Colors.White, Theme.Fonts.Display)
		banner.TextXAlignment = Enum.TextXAlignment.Center
		local bannerMeta = label(ascensionBanner, "STADIUM LEVEL " .. tostring(stadiumLevel) .. "  |  " .. string.upper(tostring(setup.AscensionObjective or "CLUB DEVELOPMENT")), UDim2.fromScale(0.04, 0.51), UDim2.fromScale(0.92, 0.37), touch and 7 or 9, stadiumLevel >= 3 and Color3.fromHex("F2C94C") or Theme.Colors.Electric, Theme.Fonts.Strong)
		bannerMeta.TextXAlignment = Enum.TextXAlignment.Center
		if workspace:GetAttribute("VTRReducedMotion") ~= true then
			TweenService:Create(ascensionBanner, TweenInfo.new(0.24, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), {GroupTransparency = 0}):Play()
			schedule(4.35, function() TweenService:Create(ascensionBanner, TweenInfo.new(0.2), {GroupTransparency = 1}):Play() end)
		else
			schedule(4.35, function() ascensionBanner.Visible = false end)
		end
	end

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
	applyPresentationBadge(homeBadge, homeColor, tostring(data.HomeLogo or "V"), teamBadgeIdentity(data, "Home"), 3, teamBadgeImage(data, "Home"))
	local awayBadge = label(rightPanel, tostring(data.AwayLogo or shortCode(away)), UDim2.fromScale(0.29, 0.58), UDim2.fromScale(0.42, 0.23), 24, Theme.Colors.White, Theme.Fonts.Display)
	awayBadge.BackgroundColor3 = awayColor
	awayBadge.BackgroundTransparency = 0
	awayBadge.TextXAlignment = Enum.TextXAlignment.Center
	applyPresentationBadge(awayBadge, awayColor, tostring(data.AwayLogo or "V"), teamBadgeIdentity(data, "Away"), 3, teamBadgeImage(data, "Away"))
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
	showEntryGroupPreview(groupPreview, data, entriesForGroup(data, "Home", "GK"))

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
	applyPresentationBadge(sheetLogo, homeColor, teamLogoText(data, "Home", "V"), teamBadgeIdentity(data, "Home"), 3, teamBadgeImage(data, "Home"))
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
		applyPresentationBadge(sheetLogo, teamColor, teamLogoText(data, side, "V"), teamBadgeIdentity(data, side), 3, teamBadgeImage(data, side))
		sheetTeamCode.Text = shortCode(teamName)
		sheetStartList.Text = teamSheetFromPlayers(lineupData(data, side), teamSheet(data, side))
		sheetSubsList.Text = benchSheetFromPlayers(side == "Home" and (data.HomeBench or {}) or (data.AwayBench or {}), benchSheet(data, side))
	end

	local kickoff = panel(root, "KickoffScoreboard", UDim2.fromScale(0.18, 1.04), UDim2.fromScale(0.64, 0.12))
	local kickoffHomeBadge = label(kickoff, "", UDim2.fromScale(0.04, 0.17), UDim2.fromScale(0.08, 0.66), 12, Theme.Colors.White, Theme.Fonts.Display)
	applyPresentationBadge(kickoffHomeBadge, homeColor, teamLogoText(data, "Home", "V"), teamBadgeIdentity(data, "Home"), 2, teamBadgeImage(data, "Home"))
	local kickoffAwayBadge = label(kickoff, "", UDim2.fromScale(0.88, 0.17), UDim2.fromScale(0.08, 0.66), 12, Theme.Colors.White, Theme.Fonts.Display)
	applyPresentationBadge(kickoffAwayBadge, awayColor, teamLogoText(data, "Away", "V"), teamBadgeIdentity(data, "Away"), 2, teamBadgeImage(data, "Away"))
	label(kickoff, shortCode(home) .. "   0       VTR       0   " .. shortCode(away), UDim2.fromScale(0.13, 0.16), UDim2.fromScale(0.74, 0.68), 26).TextXAlignment = Enum.TextXAlignment.Center

	schedule(0.4, function()
		slideIn(matchup, UDim2.fromScale(0.25, 0.16), UDim2.fromScale(0.25, 1.05), 0.42)
	end)
	schedule(4.8, function()
		slideOut(matchup, UDim2.fromScale(0.25, -0.62))
		slideIn(commentators, UDim2.fromScale(0.06, 0.74), UDim2.fromScale(-0.36, 0.74))
	end)
	schedule(15.4, function()
		slideOut(commentators, UDim2.fromScale(-0.36, 0.74))
	end)
	schedule(16.0, function()
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
		schedule(group[1], function()
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
			showEntryGroupPreview(groupPreview, data, entriesForGroup(data, side, group[6]))
		end)
	end
	schedule(31.0, function()
		playPresentationSound(STARTING_XI_SOUNDS[math.random(1,#STARTING_XI_SOUNDS)],.66)
		slideOut(playerCard, UDim2.fromScale(0.37, 0.86))
		slideOut(formation, UDim2.fromScale(-0.32, 0.13))
		updateTeamSheet("Home")
		slideIn(sheet, UDim2.fromScale(0.09, 0.14), UDim2.fromScale(0.09, 1.04), 0.42)
	end)
	schedule(35.1, function()
		slideOut(sheet, UDim2.fromScale(0.09, 1.04), 0.3)
		formationTitle.Text = shortCode(away)
		updateFormationDots(dots, data, "Away")
		slideIn(formation, UDim2.fromScale(0.04, 0.13), UDim2.fromScale(-0.32, 0.13))
		slideIn(playerCard, UDim2.fromScale(0.37, 0.13), UDim2.fromScale(0.37, 0.86))
	end)
	schedule(51.0, function()
		playPresentationSound(STARTING_XI_SOUNDS[math.random(1,#STARTING_XI_SOUNDS)],.66)
		slideOut(playerCard, UDim2.fromScale(0.37, 0.86))
		slideOut(formation, UDim2.fromScale(-0.32, 0.13))
		updateTeamSheet("Away")
		slideIn(sheet, UDim2.fromScale(0.09, 0.14), UDim2.fromScale(0.09, 1.04), 0.42)
	end)
	schedule(57.0, function()
		slideOut(sheet, UDim2.fromScale(0.09, 1.04), 0.3)
	end)
	schedule(60.0, function()
		slideIn(kickoff, UDim2.fromScale(0.18, 0.82), UDim2.fromScale(0.18, 1.04), 0.36)
	end)
	schedule(TOTAL_DURATION - 0.35, function()
		slideOut(kickoff, UDim2.fromScale(0.18, 1.04), 0.28)
	end)
	schedule(TOTAL_DURATION, function()
		Presentation.StopAudio()
		MatchPresentationService.Complete(false)
		if onComplete then onComplete() end
	end)
	return gui
end

return Presentation
