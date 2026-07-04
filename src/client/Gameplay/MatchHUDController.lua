--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)
local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local BadgePreview = require(script.Parent.Parent.Components.BadgePreview)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)
local AvatarPortraitGenerator = require(script.Parent.Parent.Services.PlayerPortraitService)

local Controller = {}
Controller.__index = Controller

local function corner(parent: Instance, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number?)
	local value = Instance.new("UIStroke")
	value.Color = color
	value.Thickness = 1
	value.Transparency = transparency or 0.65
	value.Parent = parent
	return value
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Position = position
	value.Size = size
	value.Text = text
	value.TextColor3 = Theme.Colors.White
	value.TextSize = textSize
	value.Font = Theme.Fonts.Display
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 1
	value.Parent = parent
	return value
end

local function panel(parent: Instance, position: UDim2, size: UDim2): Frame
	local value = Instance.new("Frame")
	value.Position = position
	value.Size = size
	value.BackgroundColor3 = Theme.Colors.Black
	value.BackgroundTransparency = 0.12
	value.BorderSizePixel = 0
	value.Parent = parent
	corner(value, 6)
	stroke(value, Theme.Colors.Silver, 0.76)
	return value
end

local function shortCode(name: string): string
	local words = string.split(string.upper(name), " ")
	if #words >= 2 then
		return string.sub(words[1], 1, 1) .. string.sub(words[2], 1, 2)
	end
	return string.sub(string.upper(name), 1, 3)
end

local function badgeColor(value: any, fallback: Color3): Color3
	if typeof(value) == "Color3" then return value end
	if type(value) == "string" then
		local clean = string.gsub(value, "#", "")
		local ok, result = pcall(Color3.fromHex, clean)
		if ok then return result end
	end
	return fallback
end

local function teamBadgeIdentity(data: any, side: string): any
	local summary = side == "Home" and data.HomeSummary or data.AwaySummary
	local source = side == "Home" and data.HomeBadgeIdentity or data.AwayBadgeIdentity
	if type(source) ~= "table" and type(summary) == "table" then source = summary.BadgeIdentity or summary.badgeIdentity end
	source = type(source) == "table" and source or {}
	local colors = type(summary) == "table" and summary.colors or nil
	local identity = {}
	for key, value in source do
		identity[key] = value
	end
	local summaryPreset = type(summary) == "table" and (summary.BadgePreset or summary.badgePreset) or nil
	identity.PrimaryColor = identity.PrimaryColor or (colors and colors.Primary) or (side == "Home" and data.HomeColor or data.AwayColor) or "B7FF1A"
	identity.SecondaryColor = identity.SecondaryColor or (colors and colors.Secondary) or "050505"
	identity.AccentColor = identity.AccentColor or (colors and colors.Accent) or "F5F7F2"
	identity.BadgePreset = identity.BadgePreset or identity.badgePreset or summaryPreset or "Modern"
	identity.BadgeShape = identity.BadgeShape or identity.Shape or (identity.BadgePreset == "GeneratedHex" and "Hex" or "Shield")
	identity.BadgeSymbol = identity.BadgeSymbol or identity.Symbol or "Volt V"
	identity.BadgeColorBehavior = identity.BadgeColorBehavior or "Tri Color"
	return identity
end

local function renderTeamBadge(container: GuiObject, data: any, side: string, strokeLimit: number?)
	container.ClipsDescendants = true
	if container:IsA("TextLabel") or container:IsA("TextButton") then
		container.Text = ""
	end
	container.BackgroundTransparency = 1
	for _, child in container:GetChildren() do
		if child.Name == "GeneratedBadge" or child.Name == "BadgeArt" or child.Name == "VTRPresentationBadgeArt" then child:Destroy() end
	end
	local badge = BadgePreview.new(container, teamBadgeIdentity(data, side), UDim2.fromScale(1, 1))
	badge.AnchorPoint = Vector2.new(.5, .5)
	badge.Position = UDim2.fromScale(.5, .5)
	badge.ZIndex = container.ZIndex + 1
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = badge
	for _, descendant in badge:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = badge.ZIndex
		elseif strokeLimit and descendant:IsA("UIStroke") then
			descendant.Thickness = math.min(descendant.Thickness, strokeLimit)
		end
	end
	return badge
end

local function applyBadgeArt(container: GuiObject, primary: Color3, accent: Color3?)
	container.ClipsDescendants = true
	if container:IsA("TextLabel") or container:IsA("TextButton") then
		container.Text = ""
	end
	for _, child in container:GetChildren() do
		if child.Name == "BadgeArt" then child:Destroy() end
	end
	local art = Instance.new("Frame")
	art.Name = "BadgeArt"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = container.ZIndex + 1
	art.Parent = container
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
	stripe.BackgroundColor3 = accent or Color3.fromHex("F5F7F2")
	stripe.BackgroundTransparency = .05
	stripe.BorderSizePixel = 0
	stripe.ZIndex = shield.ZIndex + 1
	stripe.Parent = shield
	local cap = Instance.new("Frame")
	cap.Name = "Cap"
	cap.Position = UDim2.fromScale(.13, .08)
	cap.Size = UDim2.fromScale(.74, .22)
	cap.BackgroundColor3 = Color3.fromHex("F5F7F2")
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
	outline.Color = Color3.fromHex("F5F7F2")
	outline.Transparency = .18
	outline.Thickness = 1
	outline.Parent = shield
end

local function actionButton(parent: Instance, text: string, order: number, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = text
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 46)
	button.BackgroundColor3 = order == 1 and Theme.Colors.Electric or Color3.fromHex("07110F")
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Selectable = false
	button.SelectionImageObject = nil
	button.Text = text
	button.TextColor3 = order == 1 and Theme.Colors.Black or Theme.Colors.White
	button.TextSize = 12
	button.Font = Theme.Fonts.Display
	button.Parent = parent
	corner(button, 8)
	local line=stroke(button,order==1 and Theme.Colors.Electric or Color3.fromHex("26332E"),order==1 and .1 or .24)
	line.Thickness=order==1 and 2 or 1
	local accent=Instance.new("Frame")
	accent.Name="Accent"
	accent.Position=UDim2.fromOffset(0,0)
	accent.Size=UDim2.new(0,5,1,0)
	accent.BackgroundColor3=order==1 and Theme.Colors.Black or Theme.Colors.Electric
	accent.BackgroundTransparency=order==1 and .18 or .16
	accent.BorderSizePixel=0
	accent.ZIndex=(button.ZIndex or 1)+1
	accent.Parent=button
	corner(accent,8)
	button.Activated:Connect(callback)
	return button
end

local function goalMinute(seconds: number?, inAddedTime: boolean?, addedElapsed: number?): string
	local value = math.max(0, tonumber(seconds) or 0)
	if inAddedTime then
		local base = value >= 5400 and 90 or 45
		local added = math.max(1, math.ceil((tonumber(addedElapsed) or 0) / 60))
		return string.format("%d+%d'", base, added)
	end
	return tostring(math.max(1, math.floor(value / 60) + 1)) .. "'"
end

function Controller.new(data: any)
	local old = Players.LocalPlayer.PlayerGui:FindFirstChild("VTRMatchHUD")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRMatchHUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 80
	gui.Parent = Players.LocalPlayer.PlayerGui
	DeviceScaleService.Apply(gui)

	local topInset = GuiService:GetGuiInset()
	local board = panel(gui, UserInputService.TouchEnabled and UDim2.fromOffset(16, math.max(86, topInset.Y + 62)) or UDim2.fromOffset(18, math.max(74, topInset.Y + 54)), UDim2.fromOffset(306, 84))
	board.BackgroundTransparency = 0.12
	board.Visible = false
	local scoreScale = Instance.new("UIScale")
	scoreScale.Scale = UserInputService.TouchEnabled and 1.08 or 1.04
	scoreScale.Parent = board
	local strip: Frame? = nil
	local stripTop: TextLabel? = nil
	local stripBottom: TextLabel? = nil
	local main = Instance.new("Frame")
	main.Name = "ScoreMain"
	main.BackgroundTransparency = 1
	main.BorderSizePixel = 0
	main.Position = UDim2.fromOffset(10, 8)
	main.Size = UDim2.new(1, -20, 0, 44)
	main.ZIndex = 11
	main.Parent = board
	local clockPanel = Instance.new("Frame")
	clockPanel.Name = "ClockPanel"
	clockPanel.BackgroundTransparency = 1
	clockPanel.BorderSizePixel = 0
	clockPanel.Position = UDim2.fromOffset(10, 52)
	clockPanel.Size = UDim2.new(1, -20, 0, 24)
	clockPanel.ZIndex = 11
	clockPanel.Parent = board
	local clockAccent: Frame? = nil
	local homeCode = label(main, shortCode(data.Home), UDim2.fromOffset(0, 5), UDim2.fromOffset(58, 28), 20)
	homeCode.TextColor3 = Theme.Colors.White
	local awayCode = label(main, shortCode(data.Away), UDim2.new(1, -58, 0, 5), UDim2.fromOffset(58, 28), 20)
	awayCode.TextXAlignment = Enum.TextXAlignment.Right
	awayCode.TextColor3 = Theme.Colors.White
	local homeBadge = label(main, string.sub(tostring(data.HomeLogo or shortCode(data.Home)), 1, 2), UDim2.fromOffset(61, 4), UDim2.fromOffset(30, 30), 12)
	homeBadge.TextXAlignment = Enum.TextXAlignment.Center;homeBadge.BackgroundColor3=badgeColor(data.HomeColor,Theme.Colors.Electric);homeBadge.BackgroundTransparency=0;homeBadge.TextColor3=Theme.Colors.Black;renderTeamBadge(homeBadge,data,"Home",1)
	local awayBadge = label(main, string.sub(tostring(data.AwayLogo or shortCode(data.Away)), 1, 2), UDim2.new(1, -91, 0, 4), UDim2.fromOffset(30, 30), 12)
	awayBadge.TextXAlignment = Enum.TextXAlignment.Center;awayBadge.BackgroundColor3=badgeColor(data.AwayColor,Theme.Colors.Silver);awayBadge.BackgroundTransparency=0;awayBadge.TextColor3=Theme.Colors.Black;renderTeamBadge(awayBadge,data,"Away",1)
	local homeScoreLabel = label(main, "0", UDim2.new(.5, -44, 0, 0), UDim2.fromOffset(34, 38), 27)
	homeScoreLabel.TextXAlignment = Enum.TextXAlignment.Center
	local separator = label(main, "-", UDim2.new(.5, -8, 0, 0), UDim2.fromOffset(16, 38), 24)
	separator.TextXAlignment = Enum.TextXAlignment.Center
	separator.TextColor3 = Theme.Colors.Silver
	local awayScoreLabel = label(main, "0", UDim2.new(.5, 10, 0, 0), UDim2.fromOffset(34, 38), 27)
	awayScoreLabel.TextXAlignment = Enum.TextXAlignment.Center
	local score = label(main, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), 1)
	score.Visible = false
	local clock = label(clockPanel, "00:00", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0), 16)
	clock.TextXAlignment = Enum.TextXAlignment.Center
	clock.TextColor3 = Theme.Colors.Electric
	local possession = label(board, "", UDim2.fromOffset(84, 78), UDim2.new(1, -96, 0, 20), 12)
	possession.TextColor3 = Theme.Colors.Silver
	possession.Visible = false
	local scorerPanel = Instance.new("CanvasGroup")
	scorerPanel.Name = "KickoffScorerPanel"
	scorerPanel.BackgroundColor3 = Color3.fromHex("8E00D6")
	scorerPanel.BorderSizePixel = 0
	scorerPanel.Position = UDim2.fromOffset(156, 58)
	scorerPanel.Size = UDim2.fromOffset(64, 64)
	scorerPanel.GroupTransparency = 1
	scorerPanel.Visible = false
	scorerPanel.ZIndex = 13
	scorerPanel.Parent = gui
	local scorerPortrait = Instance.new("Frame")
	scorerPortrait.Name = "PortraitHolder"
	scorerPortrait.BackgroundTransparency = 1
	scorerPortrait.Position = UDim2.fromOffset(0, 0)
	scorerPortrait.Size = UDim2.fromOffset(64, 48)
	scorerPortrait.ClipsDescendants = true
	scorerPortrait.ZIndex = 14
	scorerPortrait.Parent = scorerPanel
	local scorerMinute = label(scorerPanel, "", UDim2.fromOffset(0, 47), UDim2.fromOffset(64, 16), 9)
	scorerMinute.TextXAlignment = Enum.TextXAlignment.Center
	scorerMinute.TextColor3 = Theme.Colors.White
	scorerMinute.ZIndex = 15
	local scorerName = label(scorerPanel, "", UDim2.fromOffset(70, 22), UDim2.fromOffset(120, 20), 9)
	scorerName.TextColor3 = Theme.Colors.White
	scorerName.Visible = false
	local phasePanel = panel(gui, UDim2.new(0.5, -95, 0, 58), UDim2.fromOffset(190, 31))
	local phase = label(phasePanel, "PRE MATCH", UDim2.fromOffset(8, 4), UDim2.new(1, -16, 1, -8), 10)
	phase.TextXAlignment = Enum.TextXAlignment.Center
	phase.TextColor3 = Theme.Colors.Electric

	local banner = label(gui, "KICK OFF", UDim2.new(0.5, -150, 0.13, 0), UDim2.fromOffset(300, 46), 21)
	banner.BackgroundColor3 = Theme.Colors.Black
	banner.BackgroundTransparency = 0.12
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.Visible = false
	corner(banner, 6)

	local activePanel = panel(gui, UDim2.new(0, 22, 1, -92), UDim2.fromOffset(270, 64))
	activePanel.Visible = false
	local controlledSide = data.ControlledSide == "Away" and "Away" or "Home"
	local opponentSide = controlledSide == "Home" and "Away" or "Home"
	local activeLogo = controlledSide == "Away" and data.AwayLogo or data.HomeLogo
	local activeTeamName = controlledSide == "Away" and data.Away or data.Home
	local activeBadge = label(activePanel,string.sub(tostring(activeLogo or shortCode(activeTeamName)),1,2),UDim2.fromOffset(8,11),UDim2.fromOffset(42,42),13)
	activeBadge.TextXAlignment=Enum.TextXAlignment.Center;activeBadge.BackgroundColor3=badgeColor(controlledSide=="Away"and data.AwayColor or data.HomeColor,Theme.Colors.Electric);activeBadge.BackgroundTransparency=0.08;activeBadge.TextColor3=Theme.Colors.Black;corner(activeBadge,21);renderTeamBadge(activeBadge,data,controlledSide,2)
	local activeName = label(activePanel, "ACTIVE PLAYER", UDim2.fromOffset(60, 34), UDim2.new(1, -70, 0, 20), 12)
	local activeState = label(activePanel, "ST  9", UDim2.fromOffset(60, 7), UDim2.new(1, -70, 0, 17), 9)
	activeState.TextColor3 = Theme.Colors.Electric
	local rating = label(activePanel, "", UDim2.new(1, -92, 0, 35), UDim2.fromOffset(80, 16), 8)
	rating.TextXAlignment = Enum.TextXAlignment.Right
	rating.TextColor3 = Theme.Colors.Silver
	local stamina = Instance.new("Frame")
	stamina.Position = UDim2.fromOffset(60, 27)
	stamina.Size = UDim2.new(1, -72, 0, 6)
	stamina.BackgroundColor3 = Theme.Colors.Gunmetal
	stamina.BorderSizePixel = 0
	stamina.Parent = activePanel
	corner(stamina, 3)
	local enduranceFill = Instance.new("Frame")
	enduranceFill.Size = UDim2.fromScale(1, 1)
	enduranceFill.BackgroundColor3 = Color3.fromHex("159BD3")
	enduranceFill.BorderSizePixel = 0
	enduranceFill.ClipsDescendants=true
	enduranceFill.Parent = stamina
	corner(enduranceFill, 3)
	local staminaFill = Instance.new("Frame")
	staminaFill.Position=UDim2.fromScale(0,.25)
	staminaFill.Size = UDim2.fromScale(1, .5)
	staminaFill.BackgroundColor3 = Theme.Colors.Electric
	staminaFill.BorderSizePixel = 0
	staminaFill.Parent = enduranceFill
	corner(staminaFill, 3)

	local targetPanel = panel(gui, UDim2.new(1, -272, 1, -92), UDim2.fromOffset(250, 64))
	targetPanel.Visible = false
	local opponentLogo = opponentSide == "Away" and data.AwayLogo or data.HomeLogo
	local opponentTeamName = opponentSide == "Away" and data.Away or data.Home
	local opponentBadge = label(targetPanel,string.sub(tostring(opponentLogo or shortCode(opponentTeamName)),1,2),UDim2.new(1,-50,0,11),UDim2.fromOffset(42,42),13)
	opponentBadge.TextXAlignment=Enum.TextXAlignment.Center;opponentBadge.BackgroundColor3=badgeColor(opponentSide=="Away"and data.AwayColor or data.HomeColor,Theme.Colors.Silver);opponentBadge.BackgroundTransparency=0.08;opponentBadge.TextColor3=Theme.Colors.Black;corner(opponentBadge,21);renderTeamBadge(opponentBadge,data,opponentSide,2)
	local targetKicker = label(targetPanel, "CB  4", UDim2.fromOffset(12, 7), UDim2.new(1, -68, 0, 15), 8)
	targetKicker.TextColor3 = Color3.fromHex("FF6975")
	local targetName = label(targetPanel, "NO TARGET", UDim2.fromOffset(12, 34), UDim2.new(1, -68, 0, 21), 12)
	local pressure = Instance.new("Frame")
	pressure.Position = UDim2.fromOffset(12, 27)
	pressure.Size = UDim2.new(1, -70, 0, 4)
	pressure.BackgroundColor3 = Theme.Colors.Gunmetal
	pressure.BorderSizePixel = 0
	pressure.Parent = targetPanel
	local pressureFill = Instance.new("Frame")
	pressureFill.Size = UDim2.fromScale(0.65, 1)
	pressureFill.BackgroundColor3 = Color3.fromHex("FF4D5A")
	pressureFill.BorderSizePixel = 0
	pressureFill.Parent = pressure

	local charge = panel(gui, UDim2.new(0, 22, 1, -24), UDim2.fromOffset(270, 18))
	charge.ZIndex = 18
	charge.Visible = false
	local chargeLabel = label(charge, "SHOT POWER", UDim2.fromOffset(7, 2), UDim2.new(1, -14, 0, 11), 7)
	chargeLabel.TextXAlignment = Enum.TextXAlignment.Center
	local chargeFill = Instance.new("Frame")
	chargeFill.Position = UDim2.new(0, 4, 1, -6)
	chargeFill.Size = UDim2.new(0, 0, 0, 4)
	chargeFill.BackgroundColor3 = Theme.Colors.Electric
	chargeFill.BorderSizePixel = 0
	chargeFill.Parent = charge
	chargeFill.ZIndex = 20
	corner(chargeFill, 4)

	local help = label(gui, "WASD MOVE   SHIFT SPRINT   LMB SHOOT   RMB PASS   ALT MANUAL LOB   CTRL MANUAL PASS   E TACKLE   F SLIDE   R BLOCK   C DRIBBLE   Q SWITCH", UDim2.new(0.5, -520, 1, -31), UDim2.fromOffset(1040, 18), 9)
	help.TextXAlignment = Enum.TextXAlignment.Center
	help.TextColor3 = Theme.Colors.Silver
	help.Visible = false
	local pauseButton = Instance.new("TextButton")
	pauseButton.Name = "PauseQueueButton"
	pauseButton.AnchorPoint = Vector2.new(1, 0)
	pauseButton.Position = UDim2.new(1, -24, 0, 60)
	pauseButton.Size = UDim2.fromOffset(176, 44)
	pauseButton.BackgroundColor3 = Color3.fromHex("07110F")
	pauseButton.BorderSizePixel = 0
	pauseButton.AutoButtonColor = false
	pauseButton.Text = data.Ranked and "BACK  /  QUEUE PAUSE" or "BACK  /  PAUSE"
	pauseButton.TextColor3 = Theme.Colors.White
	pauseButton.TextSize = 9
	pauseButton.Font = Theme.Fonts.Display
	pauseButton.ZIndex = 42
	pauseButton.Selectable = true
	pauseButton.Visible = data.WatchMode ~= true
	pauseButton.Parent = gui
	corner(pauseButton, 9)
	local pauseStroke=stroke(pauseButton,Theme.Colors.Electric,.1)
	pauseStroke.Thickness=2
	local pauseAccent=Instance.new("Frame")
	pauseAccent.Name="PauseAccent"
	pauseAccent.AnchorPoint=Vector2.new(1,.5)
	pauseAccent.Position=UDim2.new(1,-10,.5,0)
	pauseAccent.Size=UDim2.fromOffset(34,6)
	pauseAccent.BackgroundColor3=Theme.Colors.Electric
	pauseAccent.BorderSizePixel=0
	pauseAccent.ZIndex=43
	pauseAccent.Parent=pauseButton
	corner(pauseAccent,6)
	local result=setmetatable({
		Gui = gui,
		Board = board,
		Strip = strip,
		StripTop = stripTop,
		StripBottom = stripBottom,
		ScoreMain = main,
		ClockPanel = clockPanel,
		ClockAccent = clockAccent,
		ActivePanel = activePanel,
		ScorerPanel = scorerPanel,
		ScorerPortrait = scorerPortrait,
		ScorerMinute = scorerMinute,
		ScorerName = scorerName,
		HomeCodeLabel = homeCode,
		AwayCodeLabel = awayCode,
		HomeBadge = homeBadge,
		AwayBadge = awayBadge,
		Score = score,
		HomeScoreLabel = homeScoreLabel,
		AwayScoreLabel = awayScoreLabel,
		ScoreScale = scoreScale,
		Clock = clock,
		BoardPossession = possession,
		Phase = phase,
		PhasePanel = phasePanel,
		Banner = banner,
		Charge = charge,
		ChargeFill = chargeFill,
		ChargeLabel = chargeLabel,
		Fill = staminaFill,
		EnduranceFill=enduranceFill,
		ActiveName = activeName,
		ActiveState = activeState,
		Rating=rating,
		ActiveModel = nil,
		TargetPanel = targetPanel,
		TargetName = targetName,
		TargetKicker = targetKicker,
		PressureFill = pressureFill,
		Help = help,
		PauseButton = pauseButton,
		Home = data.Home,
		Away = data.Away,
		HomeColor = data.HomeColor,
		AwayColor = data.AwayColor,
		HomeLogo = data.HomeLogo,
		AwayLogo = data.AwayLogo,
		HomeSummary = data.HomeSummary,
		AwaySummary = data.AwaySummary,
		HomeBadgeIdentity = data.HomeBadgeIdentity or (data.HomeSummary and (data.HomeSummary.BadgeIdentity or data.HomeSummary.badgeIdentity)),
		AwayBadgeIdentity = data.AwayBadgeIdentity or (data.AwaySummary and (data.AwaySummary.BadgeIdentity or data.AwaySummary.badgeIdentity)),
		HomeLineup = data.HomeLineup or {},
		AwayLineup = data.AwayLineup or {},
		HomeCode = shortCode(data.Home),
		AwayCode = shortCode(data.Away),
		PitchWidth = data.PitchWidth or 80,
		PitchLength = data.PitchLength or 120,
	}, Controller)
	if pauseButton then
		pauseButton.Activated:Connect(function()
			if result.PauseButtonCallback then result.PauseButtonCallback() end
		end)
	end
	return result
end

function Controller:SetPauseButtonCallback(callback:()->())
	self.PauseButtonCallback=callback
	if self.PauseButton then self.PauseButton.Visible=true end
end

function Controller:_lineupEntryForModel(model: Model?): any?
	if not model then return nil end
	local side = tostring(model:GetAttribute("VTRTeam") or model:GetAttribute("teamSide") or "Home")
	local index = tonumber(model:GetAttribute("VTRIndex")) or tonumber(model:GetAttribute("ShirtNumber")) or 0
	local lineup = side == "Away" and self.AwayLineup or self.HomeLineup
	return lineup and lineup[index] or nil
end

function Controller:RememberGoalScorer(payload: any)
	local model = payload and payload.ScorerModel
	local side = tostring(payload and payload.Team or (model and model:GetAttribute("VTRTeam")) or "Home")
	self.LatestGoalScorer = {
		Model = typeof(model) == "Instance" and model:IsA("Model") and model or nil,
		Team = side,
		Name = tostring(payload and payload.Scorer or (model and model:GetAttribute("DisplayName")) or "SCORER"),
		Minute = goalMinute(payload and payload.GameSeconds, payload and payload.InAddedTime, payload and payload.AddedElapsed),
	}
end

function Controller:ShowKickoffScorer()
	local scorer = self.LatestGoalScorer
	if not scorer or not self.ScorerPanel then return end
	local panel = self.ScorerPanel
	local portraitHolder = self.ScorerPortrait
	if portraitHolder then
		for _, child in portraitHolder:GetChildren() do child:Destroy() end
		local entry = self:_lineupEntryForModel(scorer.Model)
		if entry and entry.appearance then
			local portrait = AvatarPortraitGenerator.new(portraitHolder, entry, UDim2.fromOffset(64, 50), false)
			portrait.Position = UDim2.fromOffset(0, -2)
			portrait.BackgroundTransparency = 1
			portrait.ZIndex = 15
		elseif scorer.Model then
			local fallback = label(portraitHolder, string.sub(scorer.Name, 1, 2), UDim2.fromOffset(0, 0), UDim2.fromOffset(64, 48), 18)
			fallback.TextXAlignment = Enum.TextXAlignment.Center
			fallback.TextYAlignment = Enum.TextYAlignment.Center
		end
	end
	self.ScorerMinute.Text = scorer.Minute
	if self.ScorerName then self.ScorerName.Text = string.upper(scorer.Name) end
	local home = scorer.Team == "Home"
	panel.BackgroundColor3 = home and Color3.fromHex("8E00D6") or Color3.fromHex("1F1648")
	panel.Position = UDim2.fromOffset(home and 156 or 156, home and 58 or 78)
	panel.GroupTransparency = 1
	panel.Visible = true
	TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(156, home and 58 or 78),
		GroupTransparency = 0,
	}):Play()
end

function Controller:HideKickoffScorer()
	if not self.ScorerPanel or not self.ScorerPanel.Visible then return end
	local panel = self.ScorerPanel
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Position = panel.Position - UDim2.fromOffset(18, 0),
		GroupTransparency = 1,
	}):Play()
	task.delay(0.2, function()
		if panel.Parent and panel.GroupTransparency >= 0.95 then
			panel.Visible = false
		end
	end)
	self.LatestGoalScorer = nil
end

function Controller:SetClock(seconds: number, home: number, away: number, addedMinutes: number?, inAddedTime: boolean?, addedElapsed: number?)
	local whole = math.max(0, math.floor(seconds))
	if inAddedTime then
		local baseMinute = seconds >= 2700 and (seconds >= 5400 and 90 or seconds < 3000 and 45 or 90) or 45
		local extra = math.max(0, math.floor(addedElapsed or 0))
		self.Clock.Text = string.format("%02d:00 +%d:%02d", baseMinute, math.floor(extra / 60), extra % 60)
	elseif (addedMinutes or 0) > 0 and (math.abs(seconds - 2700) < 2 or seconds >= 5400) then
		self.Clock.Text = string.format("%02d:00 +%d", seconds < 5400 and 45 or 90, addedMinutes)
	else
		self.Clock.Text = string.format("%02d:%02d", math.floor(whole / 60), whole % 60)
	end
	self.Score.Text = self.HomeCode .. "  " .. home .. " - " .. away .. "  " .. self.AwayCode
	if self.HomeScoreLabel then self.HomeScoreLabel.Text = tostring(home) end
	if self.AwayScoreLabel then self.AwayScoreLabel.Text = tostring(away) end
end

local function tween(instance: Instance, duration: number, props: {[string]: any}, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out)
	local created = TweenService:Create(instance, info, props)
	created:Play()
	return created
end

function Controller:PlayScoreboardIntro(force: boolean?)
	if self.ScoreboardIntroPlayed and not force then return end
	self.ScoreboardIntroPlayed = true
	local board = self.Board
	if not board then return end
	local targetPosition = board.Position
	board.Visible = true
	board.Position = targetPosition - UDim2.fromOffset(190, 0)
	board.BackgroundTransparency = 1
	self.ScoreScale.Scale = 0.98
	local textParts = {self.StripTop, self.StripBottom, self.HomeCodeLabel, self.AwayCodeLabel, self.HomeScoreLabel, self.AwayScoreLabel, self.Clock}
	for _, item in textParts do
		if item and item:IsA("TextLabel") then
			item.TextTransparency = 1
		end
	end
	for _, item in {self.HomeBadge, self.AwayBadge} do
		if item and item:IsA("TextLabel") then
			item.TextTransparency = 1
			item.BackgroundTransparency = 1
		end
	end

	local assembly = Instance.new("Folder")
	assembly.Name = "ScoreboardAssemblyFX"
	assembly.Parent = board
	local scanner = Instance.new("Frame")
	scanner.Name = "AssemblyScanner"
	scanner.BackgroundColor3 = Theme.Colors.Electric
	scanner.BackgroundTransparency = 0.08
	scanner.BorderSizePixel = 0
	scanner.Position = UDim2.fromOffset(10, 8)
	scanner.Size = UDim2.fromOffset(4, 68)
	scanner.ZIndex = 19
	scanner.Parent = assembly

	tween(board, 0.28, {Position = targetPosition, BackgroundTransparency = 0.12}, Enum.EasingStyle.Back)
	tween(scanner, 0.5, {Position = UDim2.new(1, -14, 0, 8), BackgroundTransparency = 1}, Enum.EasingStyle.Sine)
	task.delay(0.2, function()
		for _, item in textParts do
			if item and item:IsA("TextLabel") then tween(item, 0.18, {TextTransparency = 0}, Enum.EasingStyle.Quad) end
		end
		for _, item in {self.HomeBadge, self.AwayBadge} do
			if item and item:IsA("TextLabel") then tween(item, 0.18, {TextTransparency = 0, BackgroundTransparency = 0}, Enum.EasingStyle.Quad) end
		end
		tween(self.ScoreScale, 0.22, {Scale = UserInputService.TouchEnabled and 1.1 or 1.06}, Enum.EasingStyle.Back)
		task.delay(0.18, function()
			if self.ScoreScale.Parent then tween(self.ScoreScale, 0.16, {Scale = UserInputService.TouchEnabled and 1.08 or 1.04}, Enum.EasingStyle.Quad) end
		end)
	end)
	task.delay(0.62, function()
		if assembly.Parent then assembly:Destroy() end
	end)
end

function Controller:PlayPlayerPanelsIntro(force: boolean?)
	if self.PlayerPanelsIntroPlayed and not force then return end
	self.PlayerPanelsIntroPlayed = true
	local active = self.ActivePanel
	if active then
		active.Visible = true
		active.Position = UDim2.new(0, -305, 1, -92)
		active.BackgroundTransparency = 1
		local scale = active:FindFirstChild("IntroScale") :: UIScale?
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "IntroScale"
			scale.Parent = active
		end
		scale.Scale = 0.92
		tween(active, 0.36, {Position = UDim2.new(0, 22, 1, -92), BackgroundTransparency = 0.12}, Enum.EasingStyle.Back)
		tween(scale, 0.32, {Scale = 1}, Enum.EasingStyle.Back)
	end
end

function Controller:PlayMatchHudIntro(force: boolean?)
	self:PlayScoreboardIntro(force)
	task.delay(0.12, function()
		if self.Gui and self.Gui.Parent then
			self:PlayPlayerPanelsIntro(force)
		end
	end)
end

function Controller:PulseScore()
	self.ScoreScale.Scale = 1
	local grow = TweenService:Create(self.ScoreScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.1})
	grow:Play()
	grow.Completed:Once(function()
		if self.ScoreScale.Parent then
			TweenService:Create(self.ScoreScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)
end

function Controller:SetCharge(value: number, kind: string?)
	self.Charge.Visible = value > 0.01
	self.ChargeFill.Size = UDim2.new(math.clamp(value, 0, 1), 0, 0, 4)
	self.ChargeLabel.Text = kind == "Pass" and "PASS POWER" or "SHOT POWER"
	self.ChargeFill.BackgroundColor3 = kind == "Pass" and Color3.fromHex("B7FF1A") or Color3.fromHex("DFFF4A")
end

function Controller:SetClock(seconds: number, home: number?, away: number?, addedMinutes: number?, inAddedTime: boolean?, addedElapsed: number?)
	local value = math.max(0, tonumber(seconds) or 0)
	local halfBase = value >= 2700 and 45 or 0
	local minute = math.floor(value / 60)
	local second = math.floor(value % 60)
	if inAddedTime then
		local base = value >= 5400 and 90 or 45
		local added = math.max(1, math.ceil((tonumber(addedElapsed) or 0) / 60))
		self.Clock.Text = string.format("%d+%d", base, added)
	else
		self.Clock.Text = string.format("%02d:%02d", minute, second)
	end
	if not self.AddedTimeLabel and self.ClockPanel then
		local added = label(self.ClockPanel, "", UDim2.new(1, -42, 0, 0), UDim2.fromOffset(40, 18), 9)
		added.Name = "AddedTimeLabel"
		added.TextXAlignment = Enum.TextXAlignment.Center
		added.TextColor3 = Theme.Colors.Black
		added.BackgroundColor3 = Theme.Colors.Electric
		added.BackgroundTransparency = .06
		added.Visible = false
		added.ZIndex = self.Clock.ZIndex + 2
		corner(added, 3)
		self.AddedTimeLabel = added
	end
	local addedTotal = tonumber(addedMinutes) or 0
	if self.AddedTimeLabel then
		self.AddedTimeLabel.Visible = addedTotal > 0
		self.AddedTimeLabel.Text = "+" .. tostring(addedTotal)
	end
	if home ~= nil then self.HomeScoreLabel.Text = tostring(home) end
	if away ~= nil then self.AwayScoreLabel.Text = tostring(away) end
end

function Controller:SetPhase(value: string)
	local phase = string.upper(value)
	self.Phase.Text = phase
	self.PhasePanel.Visible = phase ~= "IN PLAY"
	if phase == "IN PLAY" then
		self:PlayMatchHudIntro()
	end
end

function Controller:SetActivePlayer(name: string, position: string, model: Model?)
	self.ActiveModel = model
	self.ActiveName.Text = string.upper(name)
	local number = model and tonumber(model:GetAttribute("ShirtNumber")) or 0
	self.ActiveState.Text = string.upper(position ~= "" and position or "--") .. "  " .. tostring(number)
	self:UpdateActiveRating()
end

function Controller:UpdateActiveRating()
	local model=self.ActiveModel;if not model or not self.Rating then return end
	local overall=tonumber(model:GetAttribute("overall"))or 60;local matchRating=tonumber(model:GetAttribute("VTRMatchRating"))or 6
	self.Rating.Text=string.format("OVR %d  •  %.1f",overall,matchRating)
	if model:GetAttribute("VTRYellowCard")==true then self.Rating.Text="▮  "..self.Rating.Text;self.Rating.TextColor3=Color3.fromHex("FFD83D")else self.Rating.TextColor3=Theme.Colors.Silver end
end

function Controller:SetState(_value: string)
	-- The compact EA-style panel remains dedicated to position and shirt number.
end

function Controller:SetStamina(value: number,endurance:number?)
	local reserveRatio=math.clamp(value,0,1)
	if self.EnduranceFill then
		self.EnduranceFill.Visible=false
		self.EnduranceFill.Size=UDim2.fromScale(1,1)
	end
	self.Fill.Size=UDim2.fromScale(reserveRatio,1)
end

function Controller:SetOpponent(model: Model?)
	local wasVisible = self.TargetPanel.Visible
	self.TargetPanel.Visible = model ~= nil
	if model ~= nil and not wasVisible then
		self.TargetPanel.Position = UDim2.new(1, 24, 1, -92)
		self.TargetPanel.BackgroundTransparency = 1
		tween(self.TargetPanel, 0.26, {Position = UDim2.new(1, -272, 1, -92), BackgroundTransparency = 0.12}, Enum.EasingStyle.Back)
	end
	self.TargetKicker.TextColor3 = Color3.fromHex("FF6975")
	self.PressureFill.BackgroundColor3 = Color3.fromHex("FF4D5A")
	if not model then
		self.TargetName.Text = "NO TARGET"
		self.PressureFill.Size = UDim2.fromScale(0, 1)
		return
	end
	local name = tostring(model:GetAttribute("DisplayName") or model.Name)
	local position = tostring(model:GetAttribute("position") or "")
	local number = tonumber(model:GetAttribute("ShirtNumber")) or 0
	self.TargetKicker.Text = string.upper(position ~= "" and position or "--") .. "  " .. tostring(number)
	self.TargetName.Text = string.upper(name)
	self.PressureFill.Size = UDim2.fromScale(math.clamp((tonumber(model:GetAttribute("VTRStamina")) or 100) / 100, 0, 1), 1)
end

function Controller:SetTeammate(_model: Model?)
	-- The right panel is reserved for the closest opponent.
end

function Controller:SetPossession(owner: string, active: boolean)
	self.BoardPossession.Text = active and "IN POSSESSION" or owner ~= "" and ("POS: " .. string.upper(owner)) or "LOOSE BALL"
	self.BoardPossession.TextColor3 = active and Theme.Colors.Electric or Theme.Colors.Silver
end

function Controller:Flash(message: string, duration: number?)
	self.Banner.Text = string.upper(message)
	self.Banner.Visible = true
	task.delay(duration or 1.5, function()
		if self.Banner and self.Banner.Parent then
			self.Banner.Visible = false
		end
	end)
end

function Controller:ShowFinalChance(active: boolean)
	if active == false then
		local overlay = self.FinalChanceOverlay
		self.FinalChanceOverlay = nil
		if overlay and overlay.Parent then
			TweenService:Create(overlay, TweenInfo.new(.16), {GroupTransparency = 1}):Play()
			task.delay(.18, function()
				if overlay.Parent then overlay:Destroy() end
			end)
		end
		return
	end
	if self.FinalChanceOverlay and self.FinalChanceOverlay.Parent then return end
	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "FinalChanceOverlay"
	overlay.AnchorPoint = Vector2.new(.5, .5)
	overlay.BackgroundTransparency = 1
	overlay.GroupTransparency = 1
	overlay.Position = UDim2.fromScale(.5, .34)
	overlay.Size = UDim2.fromOffset(760, 170)
	overlay.ZIndex = 88
	overlay.Parent = self.Gui
	self.FinalChanceOverlay = overlay
	local title = label(overlay, "FINAL CHANCE", UDim2.fromScale(0, .12), UDim2.fromScale(1, .46), 48)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Theme.Colors.Electric
	title.TextStrokeTransparency = .25
	title.ZIndex = 90
	local sub = label(overlay, "LAST ATTACK", UDim2.fromScale(0, .58), UDim2.fromScale(1, .20), 16)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.TextColor3 = Theme.Colors.White
	sub.TextStrokeTransparency = .35
	sub.ZIndex = 90
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(.5, 0)
	line.BackgroundColor3 = Theme.Colors.Electric
	line.BorderSizePixel = 0
	line.Position = UDim2.fromScale(.5, .84)
	line.Size = UDim2.fromScale(.62, .035)
	line.ZIndex = 89
	line.Parent = overlay
	local scale = Instance.new("UIScale")
	scale.Scale = .82
	scale.Parent = overlay
	TweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 0}):Play()
	TweenService:Create(scale, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

function Controller:ShowFoulBanner(payload:any)
	if self.FoulBanner then self.FoulBanner:Destroy();self.FoulBanner=nil end
	local overlay=Instance.new("Frame")
	overlay.Name="FoulBanner"
	overlay.AnchorPoint=Vector2.new(.5,.5)
	overlay.Position=UDim2.fromScale(.5,.40)
	overlay.Size=UDim2.new(1,0,0,128)
	overlay.BackgroundTransparency=1
	overlay.ZIndex=34
	overlay.Active=false
	overlay.Selectable=false
	overlay:SetAttribute("VTRFoulBannerVersion","clean-card-v3")
	overlay.Parent=self.Gui
	self.FoulBanner=overlay
	local hasCard=payload.Card=="Yellow"or payload.Card=="Red"
	local secondYellow=payload.SecondYellow==true
	local stripColor=Color3.fromHex("167DFF")
	if payload.Card=="Yellow"then stripColor=Color3.fromHex("FFD72E")elseif payload.Card=="Red"then stripColor=Color3.fromHex("F02C32")end
	local strip=Instance.new("Frame")
	strip.AnchorPoint=Vector2.new(.5,.5)
	strip.Position=UDim2.fromScale(.5,.58)
	strip.Size=UDim2.new(1,0,0,54)
	strip.BackgroundColor3=stripColor
	strip.BorderSizePixel=0
	strip.ZIndex=35
	strip.Parent=overlay
	local gradient=Instance.new("UIGradient")
	gradient.Color=ColorSequence.new({
		ColorSequenceKeypoint.new(0,stripColor:Lerp(Theme.Colors.Black,.32)),
		ColorSequenceKeypoint.new(.28,stripColor),
		ColorSequenceKeypoint.new(.72,stripColor),
		ColorSequenceKeypoint.new(1,stripColor:Lerp(Theme.Colors.Black,.32)),
	})
	gradient.Parent=strip
	local spray=Instance.new("Frame")
	spray.BackgroundColor3=Theme.Colors.White
	spray.BackgroundTransparency=.88
	spray.BorderSizePixel=0
	spray.Position=UDim2.new(.31,0,0,0)
	spray.Size=UDim2.new(.38,0,1,0)
	spray.ZIndex=36
	spray.Parent=strip
	local ref=Instance.new("TextLabel")
	ref.BackgroundTransparency=1
	ref.Position=UDim2.new(.14,0,-.42,0)
	ref.Size=UDim2.fromOffset(170,126)
	ref.Text="▰"
	ref.TextColor3=Theme.Colors.Black
	ref.TextTransparency=1
	ref.TextSize=120
	ref.Font=Theme.Fonts.Display
	ref.Rotation=-18
	ref.ZIndex=36
	ref.Parent=overlay
	local silhouette=Instance.new("Frame")
	silhouette.Name="RefereeSilhouette"
	silhouette.BackgroundTransparency=1
	silhouette.Visible=false
	silhouette.Position=UDim2.new(.15,0,.03,0)
	silhouette.Size=UDim2.fromOffset(150,118)
	silhouette.ZIndex=36
	silhouette.Parent=overlay
	local head=Instance.new("Frame");head.AnchorPoint=Vector2.new(.5,.5);head.Position=UDim2.fromScale(.42,.25);head.Size=UDim2.fromOffset(34,34);head.BackgroundColor3=Theme.Colors.Black;head.BackgroundTransparency=.18;head.BorderSizePixel=0;head.ZIndex=36;head.Parent=silhouette;corner(head,17)
	local body=Instance.new("Frame");body.AnchorPoint=Vector2.new(.5,.5);body.Position=UDim2.fromScale(.42,.64);body.Size=UDim2.fromOffset(50,74);body.BackgroundColor3=Theme.Colors.Black;body.BackgroundTransparency=.16;body.BorderSizePixel=0;body.Rotation=-7;body.ZIndex=36;body.Parent=silhouette;corner(body,8)
	local arm=Instance.new("Frame");arm.AnchorPoint=Vector2.new(0,.5);arm.Position=UDim2.fromScale(.55,.36);arm.Size=UDim2.fromOffset(92,15);arm.BackgroundColor3=Theme.Colors.Black;arm.BackgroundTransparency=.14;arm.BorderSizePixel=0;arm.Rotation=-35;arm.ZIndex=36;arm.Parent=silhouette;corner(arm,8)
	if hasCard then
		if secondYellow then
			local first=Instance.new("Frame");first.Name="FirstYellow";first.AnchorPoint=Vector2.new(.5,.5);first.Position=UDim2.new(.22,0,.58,0);first.Size=UDim2.fromOffset(42,58);first.BackgroundColor3=Color3.fromHex("FFD833");first.BorderSizePixel=0;first.Rotation=-13;first.ZIndex=38;first.Parent=overlay;corner(first,5)
			local second=Instance.new("Frame");second.Name="SecondYellow";second.AnchorPoint=Vector2.new(.5,.5);second.Position=UDim2.new(.275,0,.58,0);second.Size=UDim2.fromOffset(42,58);second.BackgroundColor3=Color3.fromHex("FFD833");second.BorderSizePixel=0;second.Rotation=9;second.ZIndex=38;second.Parent=overlay;corner(second,5)
			task.delay(.35,function()
				if not overlay.Parent then return end
				TweenService:Create(first,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Position=UDim2.new(.247,0,.58,0),Rotation=0,BackgroundTransparency=1}):Play()
				TweenService:Create(second,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Position=UDim2.new(.247,0,.58,0),Rotation=0,BackgroundTransparency=1}):Play()
			end)
		end
		local card=Instance.new("Frame")
		card.Name="DisciplinaryCard"
		card.AnchorPoint=Vector2.new(.5,.5)
		card.Position=UDim2.new(.255,0,.58,0)
		card.Size=UDim2.fromOffset(52,72)
		card.BackgroundColor3=payload.Card=="Red"and Color3.fromHex("F0282D")or Color3.fromHex("FFD833")
		card.BorderSizePixel=0
		card.Rotation=-9
		card.ZIndex=38
		card.Parent=overlay
		corner(card,5)
		if secondYellow then card.BackgroundTransparency=1;task.delay(.54,function()if card.Parent then card.BackgroundTransparency=0;card.BackgroundColor3=Color3.fromHex("F0282D")end end)end
		local cardStroke=Instance.new("UIStroke");cardStroke.Color=Theme.Colors.White;cardStroke.Transparency=.18;cardStroke.Thickness=2;cardStroke.Parent=card
		local shine=Instance.new("Frame");shine.BackgroundColor3=Theme.Colors.White;shine.BackgroundTransparency=.76;shine.BorderSizePixel=0;shine.Position=UDim2.fromScale(.15,.08);shine.Size=UDim2.fromScale(.24,.84);shine.Rotation=18;shine.ZIndex=39;shine.Parent=card;corner(shine,4)
	end
	local titleText = "FOUL"
	if payload.RestartKind == "Penalty" then
		titleText = "PENALTY"
	elseif payload.Card == "Yellow" then
		titleText = "YELLOW CARD"
	elseif payload.Card == "Red" then
		titleText = secondYellow and "SECOND YELLOW" or "RED CARD"
	end
	local title=label(overlay,titleText,UDim2.new(.35,0,.38,0),UDim2.new(.3,0,.32,0),34)
	title.TextXAlignment=Enum.TextXAlignment.Center
	title.TextColor3=payload.Card=="Yellow"and Theme.Colors.Black or Theme.Colors.White
	title.ZIndex=37
	local detail=label(overlay,string.upper(payload.FoulKind or "CHALLENGE"),UDim2.new(.35,0,.69,0),UDim2.new(.3,0,.18,0),10)
	detail.TextXAlignment=Enum.TextXAlignment.Center
	detail.TextColor3=payload.Card=="Yellow"and Color3.fromHex("1A1A1A")or Color3.fromHex("EAF8FF")
	detail.ZIndex=37
	local fouledName=tostring(payload.FouledPlayerName or (payload.Victim and payload.Victim:GetAttribute("DisplayName")) or "FOULED PLAYER")
	local offenderName=tostring(payload.OffenderName or (payload.Actor and payload.Actor:GetAttribute("DisplayName")) or "OPPONENT")
	local playerLine=label(overlay,string.upper(fouledName).." WINS THE FREE KICK  /  FOUL BY "..string.upper(offenderName),UDim2.new(.25,0,.84,0),UDim2.new(.5,0,.14,0),8)
	playerLine.TextXAlignment=Enum.TextXAlignment.Center
	playerLine.TextColor3=payload.Card=="Yellow"and Color3.fromHex("1A1A1A")or Color3.fromHex("EAF8FF")
	playerLine.TextTransparency=.08
	playerLine.ZIndex=37
	local scale=Instance.new("UIScale");scale.Scale=.92;scale.Parent=overlay
	TweenService:Create(scale,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	task.delay(secondYellow and 1.45 or 1.05,function()
		if self.FoulBanner==overlay then
			TweenService:Create(overlay,TweenInfo.new(.14),{BackgroundTransparency=1}):Play()
			overlay:Destroy()
			self.FoulBanner=nil
		end
	end)
end

function Controller:ShowPauseQueue(playerName:string,queued:boolean)
	if self.PauseQueueBanner then self.PauseQueueBanner:Destroy();self.PauseQueueBanner=nil end
	local box=panel(self.Gui,UDim2.new(.5,-190,0,86),UDim2.fromOffset(380,38))
	box.Name="PauseQueueBanner"
	box.ZIndex=48
	box.BackgroundTransparency=.08
	self.PauseQueueBanner=box
	local text=queued and(string.upper(playerName).." QUEUED A PAUSE")or(string.upper(playerName).." CANCELLED PAUSE QUEUE")
	if self.PauseButton then
		self.PauseButton.Text = queued and "BACK  /  CANCEL PAUSE" or "BACK  /  QUEUE PAUSE"
		self.PauseButton.BackgroundColor3 = queued and Color3.fromHex("1E2228") or Color3.fromHex("07110F")
		self.PauseButton.TextColor3 = Theme.Colors.White
	end
	local line=label(box,text,UDim2.fromOffset(12,7),UDim2.new(1,-24,1,-14),11)
	line.TextXAlignment=Enum.TextXAlignment.Center
	line.TextColor3=queued and Theme.Colors.Electric or Theme.Colors.Silver
	local scale=Instance.new("UIScale");scale.Scale=.88;scale.Parent=box
	TweenService:Create(scale,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	task.delay(queued and 2.2 or 1.25,function()
		if self.PauseQueueBanner==box then
			TweenService:Create(box,TweenInfo.new(.18),{BackgroundTransparency=1}):Play()
			box:Destroy()
			self.PauseQueueBanner=nil
		end
	end)
end

function Controller:ShowSubstitution(payload:any)
	if self.SubstitutionBanner then self.SubstitutionBanner:Destroy();self.SubstitutionBanner=nil end
	local overlay=Instance.new("Frame")
	overlay.Name="SubstitutionBanner"
	overlay.AnchorPoint=Vector2.new(.5,0)
	overlay.Position=UDim2.new(.5,0,0,88)
	overlay.Size=UDim2.fromOffset(560,92)
	overlay.BackgroundColor3=Theme.Colors.Black
	overlay.BackgroundTransparency=.1
	overlay.BorderSizePixel=0
	overlay.ZIndex=52
	overlay.Parent=self.Gui
	corner(overlay,10);stroke(overlay,Theme.Colors.Electric,.35)
	self.SubstitutionBanner=overlay
	local tag=label(overlay,"SUBSTITUTION",UDim2.fromOffset(18,9),UDim2.new(1,-36,0,16),9);tag.TextColor3=Theme.Colors.Electric;tag.TextXAlignment=Enum.TextXAlignment.Center
	local outCard=panel(overlay,UDim2.fromOffset(24,30),UDim2.fromOffset(230,46));outCard.ZIndex=53;outCard.BackgroundTransparency=.18
	local inCard=panel(overlay,UDim2.new(1,-254,0,30),UDim2.fromOffset(230,46));inCard.ZIndex=53;inCard.BackgroundTransparency=.18
	local outLabel=label(outCard,"OUT  "..string.upper(tostring(payload.Outgoing or"PLAYER")),UDim2.fromOffset(12,8),UDim2.new(1,-24,0,28),11);outLabel.TextColor3=Color3.fromHex("FF6975")
	local inLabel=label(inCard,"IN  "..string.upper(tostring(payload.Incoming or"PLAYER")),UDim2.fromOffset(12,8),UDim2.new(1,-24,0,28),11);inLabel.TextColor3=Theme.Colors.Electric
	local arrow=label(overlay,"⇄",UDim2.new(.5,-22,0,34),UDim2.fromOffset(44,38),28);arrow.TextXAlignment=Enum.TextXAlignment.Center;arrow.TextColor3=Theme.Colors.White
	local flip=Instance.new("UIScale");flip.Scale=.18;flip.Parent=arrow
	TweenService:Create(flip,TweenInfo.new(.32,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	local outScale=Instance.new("UIScale");outScale.Parent=outCard
	local inScale=Instance.new("UIScale");inScale.Scale=.75;inScale.Parent=inCard
	TweenService:Create(outScale,TweenInfo.new(.22,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Scale=.86}):Play()
	task.delay(.18,function()if inScale.Parent then TweenService:Create(inScale,TweenInfo.new(.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()end end)
	task.delay(2.35,function()
		if self.SubstitutionBanner==overlay then
			TweenService:Create(overlay,TweenInfo.new(.22),{BackgroundTransparency=1,Position=UDim2.new(.5,0,0,64)}):Play()
			overlay:Destroy()
			self.SubstitutionBanner=nil
		end
	end)
end

function Controller:ToggleHelp()
	self.Help.Visible = not self.Help.Visible
end

function Controller:ShowHalfTime(payload: any, options: any?)
	if self.HalfTimePanel then
		self.HalfTimePanel:Destroy()
	end
	options = options or {}
	local stats = payload.Stats or {}
	local entry=stats.MOTM or (stats.PlayerRatings and stats.PlayerRatings[1]) or {}
	local portraitEntry=table.clone(entry)
	for _,source in (entry.Team=="Away" and self.AwayLineup or self.HomeLineup) or{}do
		if tostring(source.playerId or source.PlayerId or"")==tostring(entry.playerId or entry.PlayerId or"")then
			for key,value in source do if portraitEntry[key]==nil then portraitEntry[key]=value end end
			portraitEntry.Number=portraitEntry.Number or source.shirtNumber or source.Number
			portraitEntry.Name=portraitEntry.Name or source.displayName or source.shortName
			break
		end
	end
	local events=entry.Events or{}
	local value=Instance.new("Frame");value.Name="HalfTimePlayerOfHalf";value.AnchorPoint=Vector2.new(.5,.5);value.Position=UDim2.fromScale(1.35,.49);value.Size=UDim2.fromScale(.78,.68);value.BackgroundTransparency=1;value.ZIndex=58;value.Parent=self.Gui
	local left=panel(value,UDim2.fromScale(0,.03),UDim2.fromScale(.56,.88));left.BackgroundColor3=Color3.fromHex("25003F");left.BackgroundTransparency=.03;left.ZIndex=59
	local right=panel(value,UDim2.fromScale(.58,0),UDim2.fromScale(.36,.94));right.BackgroundColor3=Theme.Colors.Electric;right.BackgroundTransparency=0;right.ZIndex=59
	local badge=Instance.new("Frame");badge.Position=UDim2.fromScale(-.06,-.04);badge.Size=UDim2.fromOffset(70,70);badge.BackgroundColor3=Theme.Colors.White;badge.BorderSizePixel=0;badge.ZIndex=62;badge.Parent=value;corner(badge,2)
	renderTeamBadge(badge,self,entry.Team=="Away"and"Away"or"Home",2)
	local title=label(left,options.Title or "PLAYER OF\nTHE HALF",UDim2.fromScale(.07,.06),UDim2.fromScale(.48,.15),27);title.TextColor3=Theme.Colors.White;title.TextWrapped=true
	local score=label(left,self.HomeCode.."  "..tostring(payload.Home or 0).." - "..tostring(payload.Away or 0).."  "..self.AwayCode,UDim2.fromScale(.62,.07),UDim2.fromScale(.3,.05),13);score.TextXAlignment=Enum.TextXAlignment.Right;score.TextColor3=Theme.Colors.Electric
	local pitch=Instance.new("Frame");pitch.Position=UDim2.fromScale(.12,.23);pitch.Size=UDim2.fromScale(.42,.38);pitch.BackgroundColor3=Color3.fromHex("101A14");pitch.BackgroundTransparency=.05;pitch.BorderSizePixel=0;pitch.ZIndex=61;pitch.Parent=left;stroke(pitch,Theme.Colors.White,.12)
	local function pitchLine(pos:UDim2,size:UDim2,transparency:number?)
		local line=Instance.new("Frame");line.Position=pos;line.Size=size;line.BackgroundColor3=Theme.Colors.White;line.BackgroundTransparency=transparency or .18;line.BorderSizePixel=0;line.ZIndex=67;line.Parent=pitch;return line
	end
	local function pitchBox(pos:UDim2,size:UDim2)
		local box=Instance.new("Frame");box.Position=pos;box.Size=size;box.BackgroundTransparency=1;box.BorderSizePixel=0;box.ZIndex=67;box.Parent=pitch;stroke(box,Theme.Colors.White,.18);return box
	end
	pitchLine(UDim2.fromScale(0,.5),UDim2.new(1,0,0,1),.16)
	pitchBox(UDim2.fromScale(.22,0),UDim2.fromScale(.56,.19))
	pitchBox(UDim2.fromScale(.36,0),UDim2.fromScale(.28,.08))
	pitchBox(UDim2.fromScale(.22,.81),UDim2.fromScale(.56,.19))
	pitchBox(UDim2.fromScale(.36,.92),UDim2.fromScale(.28,.08))
	local center=Instance.new("Frame");center.AnchorPoint=Vector2.new(.5,.5);center.Position=UDim2.fromScale(.5,.5);center.Size=UDim2.fromScale(.28,.16);center.BackgroundTransparency=1;center.BorderSizePixel=0;center.ZIndex=67;center.Parent=pitch;corner(center,999);stroke(center,Theme.Colors.White,.22)
	local spotA=Instance.new("Frame");spotA.AnchorPoint=Vector2.new(.5,.5);spotA.Position=UDim2.fromScale(.5,.31);spotA.Size=UDim2.fromOffset(4,4);spotA.BackgroundColor3=Theme.Colors.White;spotA.BackgroundTransparency=.1;spotA.BorderSizePixel=0;spotA.ZIndex=67;spotA.Parent=pitch;corner(spotA,4)
	local spotB=Instance.new("Frame");spotB.AnchorPoint=Vector2.new(.5,.5);spotB.Position=UDim2.fromScale(.5,.69);spotB.Size=UDim2.fromOffset(4,4);spotB.BackgroundColor3=Theme.Colors.White;spotB.BackgroundTransparency=.1;spotB.BorderSizePixel=0;spotB.ZIndex=67;spotB.Parent=pitch;corner(spotB,4)
	local heat=entry.HeatMap or{}
	local bins:{[string]:number}={}
	local maxBin=1
	for _,sample in heat do
		local x=tonumber(sample.NX)
		local z=tonumber(sample.NZ)
		if not x and sample.X then x=math.clamp((tonumber(sample.X)or 0)/424+.5,0,1)end
		if not z and sample.Z then z=math.clamp((tonumber(sample.Z)or 0)/742+.5,0,1)end
		if x and z then
			local bx=math.clamp(math.floor(x*13),0,12)
			local bz=math.clamp(math.floor(z*17),0,16)
			local key=bx..":"..bz
			bins[key]=(bins[key]or 0)+1
			maxBin=math.max(maxBin,bins[key])
		end
	end
	local heatLayer=Instance.new("Frame");heatLayer.BackgroundTransparency=1;heatLayer.BorderSizePixel=0;heatLayer.Size=UDim2.fromScale(1,1);heatLayer.ClipsDescendants=true;heatLayer.ZIndex=63;heatLayer.Parent=pitch
	local cells={}
	for key,count in bins do
		local parts=string.split(key,":")
		local bx=tonumber(parts[1])or 0
		local bz=tonumber(parts[2])or 0
		table.insert(cells,{X=(bx+.5)/13,Z=(bz+.5)/17,Count=count,Density=count/maxBin})
	end
	table.sort(cells,function(a,b)return a.Density<b.Density end)
	local function blob(x:number,z:number,size:number,color:Color3,transparency:number,zIndex:number)
		local dot=Instance.new("Frame");dot.AnchorPoint=Vector2.new(.5,.5);dot.Position=UDim2.fromScale(math.clamp(x,.02,.98),math.clamp(z,.02,.98));dot.Size=UDim2.fromOffset(size,size);dot.BackgroundColor3=color;dot.BackgroundTransparency=transparency;dot.BorderSizePixel=0;dot.ZIndex=zIndex;dot.Parent=heatLayer;corner(dot,999)
	end
	for _,cell in cells do
		local density=math.sqrt(math.clamp(cell.Density,0,1))
		local spread=54+density*48
		blob(cell.X,cell.Z,spread,Color3.fromRGB(0,66,255),.66-density*.12,63)
		blob(cell.X,cell.Z,spread*.72,Color3.fromRGB(0,230,210),.74-density*.22,64)
		if density>.28 then blob(cell.X,cell.Z,spread*.48,Color3.fromRGB(68,255,40),.78-density*.26,65)end
		if density>.5 then blob(cell.X,cell.Z,spread*.32,Color3.fromRGB(255,228,25),.75-density*.28,66)end
		if density>.72 then blob(cell.X,cell.Z,spread*.2,Color3.fromRGB(255,48,28),.72-density*.32,66)end
	end
	local defensive=(tonumber(events.TackleWon)or 0)+(tonumber(events.Interception)or 0)
	local passes=(tonumber(events.SuccessfulPass)or 0)+(tonumber(events.BadPass)or 0)
	local passAccuracy=passes>0 and math.floor((tonumber(events.SuccessfulPass)or 0)/passes*100+.5)or 0
	local xg=math.floor((tonumber(events.ExpectedGoals)or 0)*100)/100
	local rows={{"MATCH RATING",string.format("%.1f",tonumber(entry.Rating)or 6)},{"GOALS",tostring(entry.Goals or 0)},{"ASSISTS",tostring(entry.Assists or 0)},{"SHOTS ON TARGET",tostring(events.ShotOnTarget or 0)},{"XG",tostring(xg)},{"DEF CONTRIBUTIONS",tostring(defensive)},{"PASSES COMPLETED",tostring(events.SuccessfulPass or 0)},{"PASS ACCURACY",tostring(passAccuracy).."%"}}
	local statsTitle=label(left,"STATS",UDim2.fromScale(.08,.62),UDim2.fromScale(.18,.045),18);statsTitle.TextColor3=Theme.Colors.Electric
	for i,row in rows do
		local y=.665+(i-1)*.043
		local name=label(left,row[1],UDim2.fromScale(.08,y),UDim2.fromScale(.42,.038),14);name.TextColor3=Theme.Colors.White
		name.TextTruncate=Enum.TextTruncate.AtEnd
		local val=label(left,row[2],UDim2.fromScale(.43,y),UDim2.fromScale(.13,.038),16);val.TextXAlignment=Enum.TextXAlignment.Right;val.TextColor3=Theme.Colors.White
	end
	local portraitOk,portrait=pcall(function()return AvatarPortraitGenerator.new(right,portraitEntry,UDim2.fromScale(.72,.48),false)end)
	if portraitOk and portrait then portrait.AnchorPoint=Vector2.new(.5,0);portrait.Position=UDim2.fromScale(.5,.12);portrait.ZIndex=62 end
	local bigNum=label(right,tostring(entry.Number or 0),UDim2.fromScale(.56,.08),UDim2.fromScale(.38,.34),116);bigNum.TextColor3=Theme.Colors.White;bigNum.TextTransparency=.18;bigNum.TextXAlignment=Enum.TextXAlignment.Right;bigNum.ZIndex=60
	local num=label(right,tostring(entry.Number or 0),UDim2.fromScale(.08,.70),UDim2.fromScale(.84,.08),38);num.TextXAlignment=Enum.TextXAlignment.Center;num.TextColor3=Color3.fromHex("00F59B")
	local name=label(right,string.upper(tostring(entry.Name or"PLAYER")),UDim2.fromScale(.08,.80),UDim2.fromScale(.84,.09),25);name.TextXAlignment=Enum.TextXAlignment.Center
	local scale=Instance.new("UIScale");scale.Scale=.92;scale.Parent=value
	TweenService:Create(value,TweenInfo.new(.42,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.fromScale(.5,.49)}):Play()
	TweenService:Create(scale,TweenInfo.new(.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	self.HalfTimePanel = value
	task.delay(tonumber(options.Duration) or 7.2, function()
		if self.HalfTimePanel == value then
			TweenService:Create(value,TweenInfo.new(.48,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=UDim2.fromScale(-.45,.49)}):Play()
			TweenService:Create(scale,TweenInfo.new(.48,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=.94}):Play()
			task.delay(.5,function()if value.Parent then value:Destroy()end;if self.HalfTimePanel==value then self.HalfTimePanel=nil end;if options.OnComplete then options.OnComplete()end end)
		end
	end)
end

function Controller:SetPaused(paused: boolean, _cameraController: any, onReturn: () -> (), payload: any?, onForfeit: (() -> ())?)
	if not paused then
		self:ClearPause()
		return
	end
	if self.PauseOverlay then
		return
	end
	local stats=payload and payload.Stats or {}
	local lineups=payload and payload.Lineups or {}
	local benches=payload and payload.Benches or {}
	local controlledSide=tostring(payload and payload.ControlledSide or"Home")
	local overlay = Instance.new("Frame")
	overlay.Name = "PauseOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.18
	overlay.ZIndex = 90
	overlay.Active = true
	overlay.Selectable = false
	overlay.Parent = self.Gui
	local vignette=Instance.new("Frame");vignette.Size=UDim2.fromScale(.42,1);vignette.BackgroundColor3=Theme.Colors.Black;vignette.BackgroundTransparency=.02;vignette.BorderSizePixel=0;vignette.ZIndex=104;vignette.Parent=overlay
	local grad=Instance.new("UIGradient");grad.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.7,.12),NumberSequenceKeypoint.new(1,1)});grad.Parent=vignette
	local menu = Instance.new("Frame")
	menu.BackgroundTransparency=1
	menu.Position=UDim2.fromOffset(26,82)
	menu.Size=UDim2.fromOffset(300,420)
	menu.ZIndex = 106
	menu.Parent=overlay
	local halfTimeMode=payload and payload.HalfTime==true
	label(menu, halfTimeMode and "VTR 25 HALF TIME" or "VTR 25 MATCH", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), 10).TextColor3=Theme.Colors.Silver
	label(menu, halfTimeMode and "HALF TIME" or "PAUSED", UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 34), 25).TextColor3=Theme.Colors.Electric
	local pauseTimer=label(overlay,tostring(payload and payload.PauseRemaining or 60).."s",UDim2.new(.5,-110,0,34),UDim2.fromOffset(220,48),30);pauseTimer.TextXAlignment=Enum.TextXAlignment.Center;pauseTimer.TextColor3=Theme.Colors.White;pauseTimer.Name="PauseTimerLabel";pauseTimer.ZIndex=135
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 74)
	list.Size = UDim2.new(1, 0, 1, -74)
	list.ZIndex = 107
	list.Parent = menu
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local content=panel(overlay,UDim2.new(.34,0,.1,0),UDim2.new(.62,0,.78,0));content.ZIndex=96
	local contentTitle=label(content,"TEAM MANAGEMENT",UDim2.fromOffset(18,14),UDim2.new(1,-36,0,30),22);contentTitle.TextColor3=Theme.Colors.Electric
	local body=Instance.new("ScrollingFrame");body.BackgroundTransparency=1;body.BorderSizePixel=0;body.Position=UDim2.fromOffset(18,58);body.Size=UDim2.new(1,-36,1,-76);body.CanvasSize=UDim2.new();body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.ScrollBarThickness=4;body.ScrollBarImageColor3=Theme.Colors.White;body.ZIndex=97;body.Parent=content
	local bodyLayout=Instance.new("UIListLayout");bodyLayout.Padding=UDim.new(0,8);bodyLayout.Parent=body
	content.Visible=false
	local function clearBody(titleText:string)
		content.Visible=true
		contentTitle.Text=titleText
		for _,child in body:GetChildren()do if child~=bodyLayout then child:Destroy()end end
	end
	local function addRow(text:string,color:Color3?)
		local row=label(body,text,UDim2.new(),UDim2.new(1,-8,0,28),11);row.TextColor3=color or Theme.Colors.White;row.LayoutOrder=#body:GetChildren();return row
	end
	local function addPlayerMini(parent:Instance,entry:any,pos:UDim2,size:UDim2,onClick:((any)->())?,showPortrait:boolean?)
		entry=entry or{Name="EMPTY",Position="--",Overall=0,Number=0}
		local card=Instance.new("TextButton")
		card.Position=pos;card.Size=size;card.BackgroundColor3=Theme.Colors.Black;card.BackgroundTransparency=.06;card.BorderSizePixel=0;card.AutoButtonColor=false;card.Selectable=false;card.Text="";card.ZIndex=99;card.Parent=parent
		corner(card,7);local cardStroke=stroke(card,Theme.Colors.Electric,.46);cardStroke.Thickness=1.4
		local gradient=Instance.new("UIGradient");gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHex("1F2C18")),ColorSequenceKeypoint.new(.52,Theme.Colors.Black),ColorSequenceKeypoint.new(1,Color3.fromHex("161616"))});gradient.Rotation=90;gradient.Parent=card
		local portraitSize=math.max(30,math.floor(math.min(size.X.Offset,size.Y.Offset)*.42))
		if showPortrait ~= false then
			local portraitOk,portrait=pcall(function()
				return AvatarPortraitGenerator.new(card,entry,UDim2.fromOffset(portraitSize,portraitSize),false)
			end)
			if portraitOk and portrait then
				portrait.AnchorPoint=Vector2.new(.5,0)
				portrait.Position=UDim2.new(.5,0,0,17)
				portrait.ZIndex=101
			else
			local fallback=Instance.new("Frame")
			fallback.Name="FallbackPortrait"
			fallback.AnchorPoint=Vector2.new(.5,0)
			fallback.Position=UDim2.new(.5,0,0,17)
			fallback.Size=UDim2.fromOffset(portraitSize,portraitSize)
			fallback.BackgroundColor3=Color3.fromHex("22261F")
			fallback.BorderSizePixel=0
			fallback.ZIndex=101
			fallback.Parent=card
			corner(fallback,7);stroke(fallback,Theme.Colors.Electric,.35)
			local sourceName=string.upper(tostring(entry.Name or entry.displayName or entry.shortName or"VTR"))
			local initials=""
			for token in string.gmatch(sourceName,"%S+")do initials..=string.sub(token,1,1);if #initials>=2 then break end end
			local face=label(fallback,initials~=""and initials or"V",UDim2.fromScale(0,0),UDim2.fromScale(1,1),math.max(10,math.floor(portraitSize*.28)))
			face.TextXAlignment=Enum.TextXAlignment.Center
			face.TextColor3=Theme.Colors.Electric
			face.ZIndex=102
			end
		end
		local ovr=label(card,tostring(entry.Overall or entry.overall or 0),UDim2.fromOffset(7,5),UDim2.fromOffset(34,17),12);ovr.TextColor3=Theme.Colors.Electric
		local p=label(card,string.upper(tostring(entry.Position or entry.bestPosition or"--")),UDim2.new(1,-38,0,5),UDim2.fromOffset(31,15),8);p.TextXAlignment=Enum.TextXAlignment.Right;p.TextColor3=Theme.Colors.Silver
		local name=label(card,string.upper(tostring(entry.Name or entry.displayName or entry.shortName or"PLAYER")),UDim2.fromOffset(5,size.Y.Offset-29),UDim2.new(1,-10,0,15),7);name.TextXAlignment=Enum.TextXAlignment.Center;name.TextTruncate=Enum.TextTruncate.AtEnd
		local number=label(card,"#" .. tostring(entry.Number or entry.shirtNumber or 0),UDim2.fromOffset(7,size.Y.Offset-15),UDim2.new(1,-14,0,11),6);number.TextXAlignment=Enum.TextXAlignment.Center;number.TextColor3=Theme.Colors.Silver
		local stamina=tonumber(entry.Stamina or entry.stamina or 100)or 100
		local energyTrack=Instance.new("Frame");energyTrack.BackgroundColor3=Theme.Colors.Gunmetal;energyTrack.BackgroundTransparency=.1;energyTrack.BorderSizePixel=0;energyTrack.Position=UDim2.new(0,6,1,-5);energyTrack.Size=UDim2.new(1,-12,0,3);energyTrack.ZIndex=102;energyTrack.Parent=card;corner(energyTrack,2)
		local energyFill=Instance.new("Frame");energyFill.BackgroundColor3=stamina<45 and Theme.Colors.Warning or Theme.Colors.Electric;energyFill.BorderSizePixel=0;energyFill.Size=UDim2.fromScale(math.clamp(stamina/100,0,1),1);energyFill.ZIndex=103;energyFill.Parent=energyTrack;corner(energyFill,2)
		if onClick then card.Activated:Connect(function()onClick(entry)end)end
		return card
	end
	local function showManagement()
		clearBody("TEAM MANAGEMENT")
		content.Size=UDim2.new(.68,0,.84,0);content.Position=UDim2.new(.28,0,.08,0)
		local canvas=Instance.new("Frame");canvas.BackgroundTransparency=1;canvas.Size=UDim2.new(1,-8,0,560);canvas.ZIndex=98;canvas.Parent=body
		local pitch=panel(canvas,UDim2.fromOffset(0,0),UDim2.new(.62,-8,0,380));pitch.ZIndex=98;pitch.BackgroundColor3=Color3.fromHex("07130C");pitch.BackgroundTransparency=.04
		local pitchTitle=label(pitch,"SQUAD  /  FORMATION",UDim2.fromOffset(14,10),UDim2.new(1,-28,0,18),9);pitchTitle.TextColor3=Theme.Colors.Electric
		local details=panel(canvas,UDim2.new(.62,8,0,0),UDim2.new(.38,-8,0,380));details.ZIndex=98;details.BackgroundTransparency=.09
		local detailsTitle=label(details,"PLAYER INFO",UDim2.fromOffset(16,12),UDim2.new(1,-32,0,20),11);detailsTitle.TextColor3=Theme.Colors.Electric
		local detailsHolder=Instance.new("Frame");detailsHolder.BackgroundTransparency=1;detailsHolder.Position=UDim2.fromOffset(16,46);detailsHolder.Size=UDim2.new(1,-32,1,-62);detailsHolder.ZIndex=100;detailsHolder.Parent=details
		local function setDetails(entry:any?)
			for _,child in detailsHolder:GetChildren()do child:Destroy()end
			if not entry then
				local blank=label(detailsHolder,"SELECT A PLAYER",UDim2.fromScale(0,.28),UDim2.new(1,0,0,32),18);blank.TextXAlignment=Enum.TextXAlignment.Center;blank.TextColor3=Theme.Colors.Silver
				label(detailsHolder,"Click a player card on the pitch or bench to view info, rating, energy and match data.",UDim2.fromScale(0,.43),UDim2.new(1,0,0,58),9).TextXAlignment=Enum.TextXAlignment.Center
				return
			end
			label(detailsHolder,string.upper(tostring(entry.Name or entry.displayName or entry.shortName or"PLAYER")),UDim2.fromOffset(0,0),UDim2.new(1,0,0,28),18)
			label(detailsHolder,"OVR "..tostring(entry.Overall or entry.overall or 60).."   POS "..string.upper(tostring(entry.Position or entry.bestPosition or"--")).."   KIT #"..tostring(entry.Number or entry.shirtNumber or 0),UDim2.fromOffset(0,35),UDim2.new(1,0,0,18),9).TextColor3=Theme.Colors.Silver
			local energy=tonumber(entry.Stamina or entry.stamina or 100)or 100
			label(detailsHolder,"ENERGY",UDim2.fromOffset(0,78),UDim2.fromOffset(90,18),9).TextColor3=Theme.Colors.Electric
			local bar=Instance.new("Frame");bar.Position=UDim2.fromOffset(0,102);bar.Size=UDim2.new(1,0,0,8);bar.BackgroundColor3=Theme.Colors.Gunmetal;bar.BorderSizePixel=0;bar.ZIndex=101;bar.Parent=detailsHolder;corner(bar,4)
			local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(math.clamp(energy/100,0,1),1);fill.BackgroundColor3=Theme.Colors.Electric;fill.BorderSizePixel=0;fill.ZIndex=102;fill.Parent=bar;corner(fill,4)
			label(detailsHolder,"MATCH RATING  "..string.format("%.1f",tonumber(entry.Rating)or 6),UDim2.fromOffset(0,130),UDim2.new(1,0,0,22),11).TextColor3=Theme.Colors.White
			label(detailsHolder,"Actions: swap, sub and tactical instructions plug into this detail panel next.",UDim2.fromOffset(0,170),UDim2.new(1,0,0,70),9).TextColor3=Theme.Colors.Silver
		end
		setDetails(nil)
		local homeLine=lineups[controlledSide] or lineups.Home or{}
		local roleCounts:any={}
		for i,entry in homeLine do
			if i>11 then break end
			local pos=string.upper(tostring(entry.Position or entry.bestPosition or""))
			local band=(pos=="GK"and"GK")or((pos=="LB"or pos=="LWB")and"LEFTBACK")or((pos=="RB"or pos=="RWB")and"RIGHTBACK")or(pos=="CB"and"CB")or(pos=="CDM"and"CDM")or(pos=="CM"and"CM")or(pos=="CAM"and"CAM")or((pos=="LM"or pos=="LW")and"LEFTWIDE")or((pos=="RM"or pos=="RW")and"RIGHTWIDE")or((pos=="ST"or pos=="CF"or pos=="SS")and"ST")or"OTHER"
			roleCounts[band]=(roleCounts[band]or 0)+1
		end
		local roleSeen:any={}
		local function spreadX(band:string,base:number):number
			roleSeen[band]=(roleSeen[band]or 0)+1
			local count=roleCounts[band]or 1
			if count<=1 then return base end
			local gap=math.min(.22,.68/math.max(1,count-1))
			return math.clamp(base+(roleSeen[band]-(count+1)/2)*gap,.10,.90)
		end
		local function coordFor(entry:any,index:number):Vector2
			local pos=string.upper(tostring(entry.Position or entry.bestPosition or""))
			if pos=="GK"then return Vector2.new(.50,.88)end
			if pos=="LB"or pos=="LWB"then return Vector2.new(.17,.68)end
			if pos=="RB"or pos=="RWB"then return Vector2.new(.83,.68)end
			if pos=="CB"then return Vector2.new(spreadX("CB",.50),.70)end
			if pos=="CDM"then return Vector2.new(spreadX("CDM",.50),.55)end
			if pos=="CM"then return Vector2.new(spreadX("CM",.50),.44)end
			if pos=="CAM"then return Vector2.new(spreadX("CAM",.50),.34)end
			if pos=="LM"or pos=="LW"then return Vector2.new(.18,pos=="LM"and.34 or.23)end
			if pos=="RM"or pos=="RW"then return Vector2.new(.82,pos=="RM"and.34 or.23)end
			if pos=="ST"or pos=="CF"or pos=="SS"then return Vector2.new(spreadX("ST",.50),.16)end
			return Vector2.new(.18+((index-1)%4)*.21,.28+math.floor((index-1)/4)*.18)
		end
		for index,entry in homeLine do
			if index>11 then break end
			local c=coordFor(entry,index)
			addPlayerMini(pitch,entry,UDim2.new(c.X,-38,c.Y,-27),UDim2.fromOffset(76,54),setDetails)
		end
		local benchPanel=panel(canvas,UDim2.new(0,0,0,398),UDim2.new(1,0,0,132));benchPanel.ZIndex=98;benchPanel.BackgroundTransparency=.09
		label(benchPanel,"SUBSTITUTES",UDim2.fromOffset(14,8),UDim2.new(1,-28,0,18),10).TextColor3=Theme.Colors.Electric
		local bench=benches[controlledSide] or benches.Home or{}
		for i=1,math.min(7,#bench)do addPlayerMini(benchPanel,bench[i],UDim2.fromOffset(14+(i-1)*92,36),UDim2.fromOffset(84,70),setDetails)end
		if #bench==0 then label(benchPanel,"Bench data unavailable for this match snapshot.",UDim2.fromOffset(14,42),UDim2.new(1,-28,0,22),10).TextColor3=Theme.Colors.Silver end
	end
	local function showFacts()
		clearBody("MATCH FACTS")
		content.Size=UDim2.new(.62,0,.74,0);content.Position=UDim2.new(.34,0,.14,0)
		local home=stats.Home or{};local away=stats.Away or{}
		local header=Instance.new("Frame");header.BackgroundTransparency=1;header.Size=UDim2.new(1,-8,0,74);header.ZIndex=98;header.Parent=body
		local left=label(header,self.HomeCode,UDim2.new(.2,-35,0,8),UDim2.fromOffset(70,38),22);left.TextXAlignment=Enum.TextXAlignment.Center;left.BackgroundColor3=Theme.Colors.Electric;left.BackgroundTransparency=.05;left.TextColor3=Theme.Colors.Black;corner(left,19)
		local score=label(header,tostring(stats.HomeScore or payload.Home or 0).."  -  "..tostring(stats.AwayScore or payload.Away or 0),UDim2.new(.5,-75,0,8),UDim2.fromOffset(150,38),24);score.TextXAlignment=Enum.TextXAlignment.Center
		local right=label(header,self.AwayCode,UDim2.new(.8,-35,0,8),UDim2.fromOffset(70,38),22);right.TextXAlignment=Enum.TextXAlignment.Center;right.BackgroundColor3=Color3.fromHex("24C6B8");right.BackgroundTransparency=.05;right.TextColor3=Theme.Colors.Black;corner(right,19)
		local rows={{"POSSESSION",home.Possession or 0,away.Possession or 0,"%"},{"SHOTS",home.Shots or 0,away.Shots or 0,""},{"ON TARGET",home.ShotsOnTarget or 0,away.ShotsOnTarget or 0,""},{"EXPECTED GOALS",home.ExpectedGoals or 0,away.ExpectedGoals or 0,""},{"PASS ACCURACY",home.PassAccuracy or 0,away.PassAccuracy or 0,"%"},{"TACKLES",home.TacklesCompleted or 0,away.TacklesCompleted or 0,""},{"FOULS",home.Fouls or 0,away.Fouls or 0,""},{"CARDS",tostring(home.YellowCards or 0).."/"..tostring(home.RedCards or 0),tostring(away.YellowCards or 0).."/"..tostring(away.RedCards or 0),""}}
		for _,row in rows do local r=addRow(tostring(row[2])..tostring(row[4]).."          "..row[1].."          "..tostring(row[3])..tostring(row[4]),Theme.Colors.White);r.TextXAlignment=Enum.TextXAlignment.Center end
	end
	local function showPerformance()
		clearBody("PLAYER PERFORMANCE")
		content.Size=UDim2.new(.62,0,.78,0);content.Position=UDim2.new(.34,0,.12,0)
		local header=Instance.new("Frame");header.BackgroundColor3=Theme.Colors.Gunmetal;header.BackgroundTransparency=.18;header.BorderSizePixel=0;header.Size=UDim2.new(1,-8,0,42);header.ZIndex=98;header.Parent=body;corner(header,5)
		local cols={{"POS",.02,.08},{"NAME",.11,.34},{"MR",.46,.08},{"G",.56,.05},{"AST",.63,.06},{"SOT",.72,.06},{"XG",.80,.07},{"DEF",.90,.08}}
		for _,c in cols do local h=label(header,c[1],UDim2.new(c[2],0,0,10),UDim2.new(c[3],0,0,22),12);h.TextColor3=Theme.Colors.Electric end
		for _,entry in stats.PlayerRatings or{}do
			local events=entry.Events or{}
			local rowFrame=Instance.new("Frame");rowFrame.BackgroundColor3=entry.Team==controlledSide and Theme.Colors.Black or Theme.Colors.Gunmetal;rowFrame.BackgroundTransparency=entry.Team==controlledSide and .18 or .42;rowFrame.BorderSizePixel=0;rowFrame.Size=UDim2.new(1,-8,0,44);rowFrame.ZIndex=98;rowFrame.Parent=body;corner(rowFrame,5)
			local values={entry.Position or"--",string.upper(entry.Name or"PLAYER"),string.format("%.1f",entry.Rating or 6),tostring(entry.Goals or 0),tostring(entry.Assists or 0),tostring(events.ShotOnTarget or 0),tostring(math.floor((tonumber(events.ExpectedGoals)or 0)*100)/100),tostring(entry.DefensiveActions or 0)}
			for i,c in cols do local cell=label(rowFrame,values[i],UDim2.new(c[2],0,0,10),UDim2.new(c[3],0,0,24),i==2 and 12 or 13);cell.TextColor3=i==3 and Theme.Colors.Electric or Theme.Colors.White;cell.TextTruncate=Enum.TextTruncate.AtEnd end
		end
		local shotCount=(stats.ShotMap and stats.ShotMap.Home and #stats.ShotMap.Home or 0)+(stats.ShotMap and stats.ShotMap.Away and #stats.ShotMap.Away or 0)
		local passCount=(stats.PassMap and stats.PassMap.Home and #stats.PassMap.Home or 0)+(stats.PassMap and stats.PassMap.Away and #stats.PassMap.Away or 0)
		addRow("FIELD EVENTS REGISTERED: "..tostring(shotCount).." SHOTS  /  "..tostring(passCount).." COMPLETED PASSES",Theme.Colors.Electric)
		addRow("TRACKED CATEGORIES: XG, SHOT LOCATION, PASS ORIGIN, PASS DESTINATION, PASS ACCURACY, TACKLES, SAVES, FOULS, CARDS",Theme.Colors.Silver)
	end
	local function showForfeitAnimation()
		local shade=Instance.new("Frame");shade.Size=UDim2.fromScale(1,1);shade.BackgroundColor3=Theme.Colors.Black;shade.BackgroundTransparency=.1;shade.BorderSizePixel=0;shade.ZIndex=160;shade.Active=true;shade.Parent=overlay
		local box=panel(shade,UDim2.new(.5,-235,.5,-86),UDim2.fromOffset(470,172));box.ZIndex=161;box.BackgroundTransparency=.04
		local title=label(box,"FORFEIT MATCH",UDim2.fromOffset(18,20),UDim2.new(1,-36,0,34),26);title.TextXAlignment=Enum.TextXAlignment.Center;title.TextColor3=Color3.fromHex("FF6975")
		local sub=label(box,"Leaving the match awards the opponent a win. Final stats are still recorded.",UDim2.fromOffset(28,62),UDim2.new(1,-56,0,34),10);sub.TextXAlignment=Enum.TextXAlignment.Center;sub.TextColor3=Theme.Colors.Silver
		local bar=Instance.new("Frame");bar.Position=UDim2.fromOffset(44,112);bar.Size=UDim2.new(1,-88,0,8);bar.BackgroundColor3=Theme.Colors.Gunmetal;bar.BorderSizePixel=0;bar.ZIndex=162;bar.Parent=box;corner(bar,4)
		local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(0,1);fill.BackgroundColor3=Color3.fromHex("FF6975");fill.BorderSizePixel=0;fill.ZIndex=163;fill.Parent=bar;corner(fill,4)
		TweenService:Create(fill,TweenInfo.new(1.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(1,1)}):Play()
		task.delay(1.2,function()if onForfeit then onForfeit()else MatchSetupService:ReturnToMenu();onReturn()end end)
	end
	local function openTeamManagementPage()
		menu.Visible=false;content.Visible=false
		if self.TeamManagementPage then self.TeamManagementPage:Destroy();self.TeamManagementPage=nil end
		local page=Instance.new("Frame");page.Name="TeamManagementPage";page.Size=UDim2.fromScale(1,1);page.BackgroundColor3=Theme.Colors.Black;page.BackgroundTransparency=.02;page.BorderSizePixel=0;page.ZIndex=130;page.Active=true;page.Parent=overlay;self.TeamManagementPage=page
		local headerLeft=172
		local title=label(page,"TEAM MANAGEMENT",UDim2.fromOffset(headerLeft,24),UDim2.new(.45,0,0,38),28);title.TextColor3=Theme.Colors.Electric
		label(page,"SQUAD  /  TACTICS  /  ASSIGNMENTS",UDim2.fromOffset(headerLeft+2,64),UDim2.new(.5,0,0,18),10).TextColor3=Theme.Colors.Silver
		local back=actionButton(page,"‹ BACK",1,function()if self.TeamManagementPage then self.TeamManagementPage:Destroy();self.TeamManagementPage=nil end;menu.Visible=true;content.Visible=true end);back.Position=UDim2.new(1,-150,0,24);back.Size=UDim2.fromOffset(118,36);back.ZIndex=133
		back.Activated:Connect(function()content.Visible=false end)
		local dragLayer=Instance.new("Frame");dragLayer.Name="TeamManagementDragLayer";dragLayer.BackgroundTransparency=1;dragLayer.BorderSizePixel=0;dragLayer.Size=UDim2.fromScale(1,1);dragLayer.ZIndex=175;dragLayer.Parent=overlay
		page.Destroying:Connect(function()if dragLayer.Parent then dragLayer:Destroy()end end)
		local function pointerPosition(input:any?):Vector2
			local raw=input and input.Position and Vector2.new(input.Position.X,input.Position.Y) or UserInputService:GetMouseLocation()
			local inset=GuiService:GetGuiInset()
			return raw-Vector2.new(inset.X,inset.Y)
		end
		local pitch=panel(page,UDim2.fromOffset(28,100),UDim2.new(.58,-42,.62,0));pitch.ZIndex=131;pitch.BackgroundColor3=Color3.fromHex("07170B");pitch.BackgroundTransparency=.03
		local info=panel(page,UDim2.new(.60,0,0,100),UDim2.new(.37,0,.62,0));info.ZIndex=131;info.BackgroundTransparency=.07
		local benchPanel=panel(page,UDim2.new(0,28,.75,0),UDim2.new(.94,0,.18,0));benchPanel.ZIndex=131;benchPanel.BackgroundTransparency=.08
		label(pitch,"FORMATION",UDim2.fromOffset(14,12),UDim2.new(1,-28,0,20),10).TextColor3=Theme.Colors.Electric
		label(benchPanel,"SUBSTITUTES",UDim2.fromOffset(16,10),UDim2.new(1,-32,0,18),10).TextColor3=Theme.Colors.White
		local field=Instance.new("Frame");field.BackgroundTransparency=1;field.Position=UDim2.fromOffset(30,46);field.Size=UDim2.new(1,-60,1,-68);field.ZIndex=132;field.Parent=pitch;stroke(field,Theme.Colors.Silver,.82)
		local function fieldLine(pos:UDim2,size:UDim2,alpha:number?)
			local line=Instance.new("Frame");line.Position=pos;line.Size=size;line.BackgroundColor3=Theme.Colors.Silver;line.BackgroundTransparency=alpha or .82;line.BorderSizePixel=0;line.ZIndex=132;line.Parent=field;return line
		end
		local function fieldBox(pos:UDim2,size:UDim2)
			local box=Instance.new("Frame");box.Position=pos;box.Size=size;box.BackgroundTransparency=1;box.BorderSizePixel=0;box.ZIndex=132;box.Parent=field;stroke(box,Theme.Colors.Silver,.84);return box
		end
		fieldLine(UDim2.fromScale(0,.5),UDim2.new(1,0,0,2),.84)
		fieldLine(UDim2.fromScale(.33,0),UDim2.new(0,1,1,0),.93)
		fieldLine(UDim2.fromScale(.67,0),UDim2.new(0,1,1,0),.93)
		fieldBox(UDim2.fromScale(.22,0),UDim2.fromScale(.56,.18));fieldBox(UDim2.fromScale(.36,0),UDim2.fromScale(.28,.08));fieldBox(UDim2.fromScale(.22,.82),UDim2.fromScale(.56,.18));fieldBox(UDim2.fromScale(.36,.92),UDim2.fromScale(.28,.08))
		local centerCircle=Instance.new("Frame");centerCircle.AnchorPoint=Vector2.new(.5,.5);centerCircle.Position=UDim2.fromScale(.5,.5);centerCircle.Size=UDim2.fromOffset(92,92);centerCircle.BackgroundTransparency=1;centerCircle.ZIndex=132;centerCircle.Parent=field;corner(centerCircle,46);stroke(centerCircle,Theme.Colors.Silver,.84)
		local infoHolder=Instance.new("Frame");infoHolder.BackgroundTransparency=1;infoHolder.Position=UDim2.fromOffset(20,44);infoHolder.Size=UDim2.new(1,-40,1,-64);infoHolder.ZIndex=134;infoHolder.Parent=info
		label(info,"PLAYER INFO",UDim2.fromOffset(20,16),UDim2.new(1,-40,0,20),11).TextColor3=Theme.Colors.Electric
		local function setInfo(entry:any?)
			for _,child in infoHolder:GetChildren()do child:Destroy()end
			if not entry then local blank=label(infoHolder,"SELECT A PLAYER",UDim2.fromScale(0,.34),UDim2.new(1,0,0,30),18);blank.TextXAlignment=Enum.TextXAlignment.Center;blank.TextColor3=Theme.Colors.Silver;return end
			local portraitOk,portrait=pcall(function()return AvatarPortraitGenerator.new(infoHolder,entry,UDim2.fromOffset(86,86),false)end)
			if portraitOk and portrait then portrait.Position=UDim2.fromOffset(0,0);portrait.ZIndex=135 end
			label(infoHolder,string.upper(tostring(entry.Name or entry.displayName or entry.shortName or"PLAYER")),UDim2.fromOffset(100,0),UDim2.new(1,-100,0,34),22).TextTruncate=Enum.TextTruncate.AtEnd
			label(infoHolder,"OVR "..tostring(entry.Overall or entry.overall or 60).."   POS "..string.upper(tostring(entry.Position or entry.bestPosition or"--")).."   KIT #"..tostring(entry.Number or entry.shirtNumber or 0),UDim2.fromOffset(100,39),UDim2.new(1,-100,0,20),11).TextColor3=Theme.Colors.Silver
			local rating=tonumber(entry.Rating)or 6
			local energy=tonumber(entry.Stamina or entry.stamina or 100)or 100
			local ratingCard=panel(infoHolder,UDim2.fromOffset(0,104),UDim2.new(.47,-6,0,72));ratingCard.ZIndex=135;ratingCard.BackgroundTransparency=.08
			label(ratingCard,"MATCH RATING",UDim2.fromOffset(12,9),UDim2.new(1,-24,0,16),8).TextColor3=Theme.Colors.Silver
			local ratingValue=label(ratingCard,string.format("%.1f",rating),UDim2.fromOffset(12,26),UDim2.new(1,-24,0,34),27);ratingValue.TextColor3=Theme.Colors.Electric;ratingValue.TextXAlignment=Enum.TextXAlignment.Center
			local energyCard=panel(infoHolder,UDim2.new(.47,6,0,104),UDim2.new(.53,-6,0,72));energyCard.ZIndex=135;energyCard.BackgroundTransparency=.08
			label(energyCard,"ENERGY",UDim2.fromOffset(12,9),UDim2.new(1,-24,0,16),8).TextColor3=Theme.Colors.Silver
			label(energyCard,tostring(math.floor(energy+.5)).."%",UDim2.fromOffset(12,26),UDim2.new(1,-24,0,24),18).TextColor3=energy<45 and Theme.Colors.Warning or Theme.Colors.Electric
			local bar=Instance.new("Frame");bar.Position=UDim2.fromOffset(12,55);bar.Size=UDim2.new(1,-24,0,6);bar.BackgroundColor3=Theme.Colors.Gunmetal;bar.BorderSizePixel=0;bar.ZIndex=136;bar.Parent=energyCard;corner(bar,3)
			local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(math.clamp(energy/100,0,1),1);fill.BackgroundColor3=energy<45 and Theme.Colors.Warning or Theme.Colors.Electric;fill.BorderSizePixel=0;fill.ZIndex=137;fill.Parent=bar;corner(fill,3)
			local grid=Instance.new("Frame");grid.BackgroundTransparency=1;grid.Position=UDim2.fromOffset(0,192);grid.Size=UDim2.new(1,0,0,150);grid.ZIndex=135;grid.Parent=infoHolder
			local layout=Instance.new("UIGridLayout");layout.CellSize=UDim2.new(1/3,-7,0,48);layout.CellPadding=UDim2.fromOffset(10,10);layout.Parent=grid
			for _,row in ipairs({{"PAC",entry.PAC or(entry.mainStats and entry.mainStats.PAC)or 60},{"SHO",entry.SHO or(entry.mainStats and entry.mainStats.SHO)or 60},{"PAS",entry.PAS or(entry.mainStats and entry.mainStats.PAS)or 60},{"DRI",entry.DRI or(entry.mainStats and entry.mainStats.DRI)or 60},{"DEF",entry.DEF or(entry.mainStats and entry.mainStats.DEF)or 60},{"PHY",entry.PHY or(entry.mainStats and entry.mainStats.PHY)or 60}})do
				local chip=Instance.new("Frame");chip.BackgroundColor3=Theme.Colors.Black;chip.BackgroundTransparency=.2;chip.BorderSizePixel=0;chip.ZIndex=136;chip.Parent=grid;corner(chip,6);stroke(chip,Theme.Colors.Silver,.82)
				local value=label(chip,tostring(row[2]),UDim2.fromOffset(0,6),UDim2.new(1,0,0,24),18);value.TextXAlignment=Enum.TextXAlignment.Center;value.TextColor3=Theme.Colors.White
				local key=label(chip,tostring(row[1]),UDim2.fromOffset(0,29),UDim2.new(1,0,0,12),7);key.TextXAlignment=Enum.TextXAlignment.Center;key.TextColor3=Theme.Colors.Electric
			end
			label(infoHolder,"GOALS "..tostring(entry.Goals or 0).."   /   ASSISTS "..tostring(entry.Assists or 0).."   /   DEF ACTIONS "..tostring(entry.DefensiveActions or 0),UDim2.fromOffset(0,354),UDim2.new(1,0,0,22),10).TextColor3=Theme.Colors.Silver
		end
		setInfo(nil)
		local coords={Vector2.new(.50,.86),Vector2.new(.18,.68),Vector2.new(.38,.68),Vector2.new(.62,.68),Vector2.new(.82,.68),Vector2.new(.32,.47),Vector2.new(.50,.55),Vector2.new(.68,.47),Vector2.new(.18,.22),Vector2.new(.50,.16),Vector2.new(.82,.22)}
		local cards={}
		local cardEntries:any={}
		local function makeSquadCard(parent:Instance,entry:any,pos:UDim2,size:UDim2,kind:string)
			local card=addPlayerMini(parent,entry,pos,size,setInfo,true);card.ZIndex=134;table.insert(cards,card)
			cardEntries[card]=entry
			card:SetAttribute("VTRKind",kind)
			card:SetAttribute("VTRBenchIndex",tonumber(entry.BenchIndex)or 0)
			for _,descendant in card:GetDescendants()do if descendant:IsA("GuiObject")then descendant.ZIndex=135 end end
			local startPos=pos;local startParent=parent::GuiObject;local dragging=false;local dragOffset=Vector2.zero;local changedConnection:any=nil;local endedConnection:any=nil;local hoverTarget:any=nil;local hoverStroke:UIStroke?=nil
			local liftScale=Instance.new("UIScale");liftScale.Scale=1;liftScale.Parent=card
			local function clearHover()
				if hoverStroke then hoverStroke:Destroy();hoverStroke=nil end
				hoverTarget=nil
			end
			local function setHover(target:any?)
				if hoverTarget==target then return end
				clearHover()
				hoverTarget=target
				if target and target.Parent then
					hoverStroke=Instance.new("UIStroke")
					hoverStroke.Name="TeamManagementDropGlow"
					hoverStroke.Color=Theme.Colors.White
					hoverStroke.Thickness=3
					hoverStroke.Transparency=.04
					hoverStroke.Parent=target
				end
			end
			local function nearestTarget(maxDistance:number):any?
				local best=nil;local bestDist=maxDistance;local center=card.AbsolutePosition+card.AbsoluteSize/2
				for _,other in cards do if other~=card and other.Parent then local d=(other.AbsolutePosition+other.AbsoluteSize/2-center).Magnitude;if d<bestDist then best=other;bestDist=d end end end
				return best
			end
			local function disconnectDrag()
				if changedConnection then changedConnection:Disconnect();changedConnection=nil end
				if endedConnection then endedConnection:Disconnect();endedConnection=nil end
			end
			local function finishDrag()
				if not dragging then return end
				dragging=false;disconnectDrag()
				local best=hoverTarget or nearestTarget(72)
				clearHover()
				card.ZIndex=134;for _,descendant in card:GetDescendants()do if descendant:IsA("GuiObject")then descendant.ZIndex=135 end end
				TweenService:Create(liftScale,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1}):Play()
				TweenService:Create(card,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Rotation=0}):Play()
				if best then
					local sourceKind=tostring(card:GetAttribute("VTRKind")or"")
					local targetKind=tostring(best:GetAttribute("VTRKind")or"")
					if sourceKind=="Bench" and targetKind=="Lineup" and self.ManualSubstitutionCallback and entry.BenchIndex and best then
						local targetEntry=cardEntries[best]
						local outgoingModel=targetEntry and targetEntry.Model or nil
						if outgoingModel then
							self.ManualSubstitutionCallback(tonumber(entry.BenchIndex)or 0,outgoingModel,tostring(targetEntry and targetEntry.Name or "PLAYER"))
						end
					elseif sourceKind=="Lineup" and targetKind=="Lineup" and self.ManualPositionSwapCallback and best then
						local targetEntry=cardEntries[best]
						if entry.Model and targetEntry and targetEntry.Model then
							self.ManualPositionSwapCallback(entry.Model,targetEntry.Model)
						end
					end
					local sourceParent=startParent;local sourcePos=startPos;local targetParent=best.Parent;local targetPos=best.Position
					card.Parent=targetParent;card.Position=targetPos
					best.Parent=sourceParent;best.Position=sourcePos
				else
					local currentAbs=card.AbsolutePosition
					card.Parent=startParent
					card.Position=UDim2.fromOffset(currentAbs.X-startParent.AbsolutePosition.X,currentAbs.Y-startParent.AbsolutePosition.Y)
					TweenService:Create(card,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=startPos}):Play()
				end
			end
			card.InputBegan:Connect(function(input)
				if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
					disconnectDrag();clearHover();dragging=true;startPos=card.Position;startParent=card.Parent::GuiObject
					local pointer=pointerPosition(input);local abs=card.AbsolutePosition;dragOffset=pointer-abs
					card.Parent=dragLayer;card.Position=UDim2.fromOffset(abs.X-dragLayer.AbsolutePosition.X,abs.Y-dragLayer.AbsolutePosition.Y)
					setInfo(entry);card.ZIndex=180;for _,descendant in card:GetDescendants()do if descendant:IsA("GuiObject")then descendant.ZIndex=181 end end
					TweenService:Create(liftScale,TweenInfo.new(.12,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.08}):Play()
					TweenService:Create(card,TweenInfo.new(.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Rotation=kind=="Bench" and -2 or 2}):Play()
					changedConnection=UserInputService.InputChanged:Connect(function(changed)
						if not dragging or(changed.UserInputType~=Enum.UserInputType.MouseMovement and changed.UserInputType~=Enum.UserInputType.Touch)then return end
						local currentMouse=pointerPosition(changed);local rel=currentMouse-dragOffset-dragLayer.AbsolutePosition
						card.Position=UDim2.fromOffset(rel.X,rel.Y)
						setHover(nearestTarget(72))
					end)
					endedConnection=UserInputService.InputEnded:Connect(function(ended)
						if ended.UserInputType==Enum.UserInputType.MouseButton1 or ended.UserInputType==Enum.UserInputType.Touch then finishDrag()end
					end)
				end
			end)
			return card
		end
		local lineup=lineups[controlledSide] or lineups.Home or{}
		for i=1,11 do local entry=lineup[i]or{Name="EMPTY",Position="--",Overall=0,Number=0};local c=coords[i];local card=makeSquadCard(pitch,entry,UDim2.new(c.X,-48,c.Y,-38),UDim2.fromOffset(96,76),"Lineup");card.Name="TMCard_"..tostring(entry.Model or i)end
		local bench=benches[controlledSide] or benches.Home or{}
		for i=1,math.min(7,#bench)do makeSquadCard(benchPanel,bench[i],UDim2.fromOffset(18+(i-1)*116,44),UDim2.fromOffset(104,76),"Bench")end
		local hint=label(page,"Drag a bench player onto a starting XI card to make the substitution.",UDim2.new(.5,-300,.95,0),UDim2.fromOffset(600,18),9);hint.TextXAlignment=Enum.TextXAlignment.Center;hint.TextColor3=Theme.Colors.Silver
		local scale=Instance.new("UIScale");scale.Scale=.96;scale.Parent=page;TweenService:Create(scale,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1}):Play()
	end
	local function menuButton(text:string,order:number,callback:()->())
		local button=actionButton(list,text,order,callback)
		button.ZIndex=108
		button.BackgroundTransparency=order==1 and .02 or .12
		button.TextXAlignment=Enum.TextXAlignment.Left
		button.TextSize=13
		button.Size=UDim2.new(1,0,0,38)
		local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,18);pad.Parent=button
		return button
	end
	menuButton(halfTimeMode and "START SECOND HALF" or "RESUME", 1, function()self:RequestResume()end)
	menuButton("TEAM MANAGEMENT", 2, openTeamManagementPage)
	menuButton("MATCH FACTS", 3, showFacts)
	menuButton("PERFORMANCE", 4, showPerformance)
	menuButton("SETTINGS", 5, function()clearBody("SETTINGS");addRow("Match settings are coming next. This tab is intentionally safe for now.",Theme.Colors.Silver)end)
	menuButton("LEAVE MATCH", 6, showForfeitAnimation)
	self.PauseOverlay = overlay
	task.defer(function()
		if overlay.Parent and list.Parent then
			local firstButton = list:FindFirstChildWhichIsA("GuiButton")
			if firstButton then
				GuiService.SelectedObject = firstButton
			end
		end
	end)
end

function Controller:ClearPause()
	if self.TeamManagementPage then
		self.TeamManagementPage:Destroy()
		self.TeamManagementPage = nil
	end
	if self.PauseOverlay then
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.PauseOverlay) then
			GuiService.SelectedObject = nil
		end
		self.PauseOverlay:Destroy()
		self.PauseOverlay = nil
	end
end

function Controller:SetResumeCallback(callback: () -> ())
	self.ResumeCallback = callback
end

function Controller:SetManualSubstitutionCallback(callback: (number, Model, string) -> ())
	self.ManualSubstitutionCallback = callback
end

function Controller:SetManualPositionSwapCallback(callback: (Model, Model) -> ())
	self.ManualPositionSwapCallback = callback
end

function Controller:SetPauseTimer(seconds:number)
	if not self.PauseOverlay then return end
	local labelObject=self.PauseOverlay:FindFirstChild("PauseTimerLabel",true)
	if labelObject and labelObject:IsA("TextLabel")then
		labelObject.Text=tostring(math.max(0,math.floor(seconds))).."s"
		labelObject.TextColor3=seconds<=10 and Color3.fromHex("FF6975")or Theme.Colors.Silver
	end
end

function Controller:RequestResume()
	if self.ResumeCallback then
		self.ResumeCallback()
	end
end

local function showPackRewardScreen(parent: Instance, rewardData: any)
	local qty = math.max(1, tonumber(rewardData.Packs) or 1)
	local leagueClear = rewardData.LeagueClear == true or rewardData.VoltraPack == true
	local packName = leagueClear and string.upper(tostring(rewardData.BonusPack or "VOLTRA PACK")) or string.upper(tostring(rewardData.Pack or "MATCH REWARD PACK"))
	local accent = leagueClear and Theme.Colors.Warning or Theme.Colors.Electric
	local screen = Instance.new("Frame")
	screen.Name = "PostMatchPackReward"
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundColor3 = Theme.Colors.Black
	screen.BackgroundTransparency = 1
	screen.BorderSizePixel = 0
	screen.ZIndex = 190
	screen.Active = true
	screen.Parent = parent

	local title = label(screen, leagueClear and "LEAGUE CLEAR" or "PACK EARNED", UDim2.new(.25, 0, .12, 0), UDim2.new(.5, 0, 0, 40), 28)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = accent
	title.TextTransparency = 1
	title.ZIndex = 194
	local subtitle = label(screen, leagueClear and "VOLTRA PACK ADDED TO YOUR INVENTORY" or "ADDED TO YOUR INVENTORY", UDim2.new(.25, 0, .18, 0), UDim2.new(.5, 0, 0, 22), 10)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextColor3 = Theme.Colors.Silver
	subtitle.TextTransparency = 1
	subtitle.ZIndex = 194

	local glow = Instance.new("Frame")
	glow.Name = "PackGlow"
	glow.AnchorPoint = Vector2.new(.5, .5)
	glow.Position = UDim2.fromScale(.5, .45)
	glow.Size = UDim2.fromOffset(360, 230)
	glow.BackgroundColor3 = accent
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.ZIndex = 191
	glow.Parent = screen
	corner(glow, 115)

	local pack = Instance.new("Frame")
	pack.Name = "RewardPackCard"
	pack.AnchorPoint = Vector2.new(.5, .5)
	pack.Position = UDim2.fromScale(.5, .47)
	pack.Size = UDim2.fromOffset(218, 286)
	pack.BackgroundColor3 = Theme.Colors.Gunmetal
	pack.BackgroundTransparency = .02
	pack.BorderSizePixel = 0
	pack.Rotation = -4
	pack.ZIndex = 195
	pack.Parent = screen
	corner(pack, 10)
	stroke(pack, accent, .12)
	local packScale = Instance.new("UIScale")
	packScale.Scale = .28
	packScale.Parent = pack

	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = accent
	stripe.BorderSizePixel = 0
	stripe.Position = UDim2.fromOffset(0, 0)
	stripe.Size = UDim2.new(1, 0, 0, 40)
	stripe.ZIndex = 196
	stripe.Parent = pack
	corner(stripe, 10)
	local seal = label(pack, leagueClear and "LEAGUE CLEAR BONUS" or "VTR LITE", UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 20), 12)
	seal.TextXAlignment = Enum.TextXAlignment.Center
	seal.TextColor3 = Theme.Colors.Black
	seal.ZIndex = 197
	local packTitle = label(pack, packName, UDim2.fromOffset(20, 72), UDim2.new(1, -40, 0, 62), 18)
	packTitle.TextWrapped = true
	packTitle.TextXAlignment = Enum.TextXAlignment.Center
	packTitle.TextColor3 = Theme.Colors.White
	packTitle.ZIndex = 197
	local packMeta = label(pack, leagueClear and "FIRST CLEAR REWARD" or qty > 1 and ("SEALED PACK  x" .. tostring(qty)) or "SEALED PACK", UDim2.fromOffset(20, 158), UDim2.new(1, -40, 0, 22), 10)
	packMeta.TextXAlignment = Enum.TextXAlignment.Center
	packMeta.TextColor3 = accent
	packMeta.ZIndex = 197
	if leagueClear then
		local volt = label(pack, "V", UDim2.new(.5, -34, 0, 190), UDim2.fromOffset(68, 54), 42)
		volt.TextXAlignment = Enum.TextXAlignment.Center
		volt.TextColor3 = accent
		volt.ZIndex = 197
		local vault = label(pack, "VOLTRA VAULT", UDim2.fromOffset(20, 238), UDim2.new(1, -40, 0, 18), 9)
		vault.TextXAlignment = Enum.TextXAlignment.Center
		vault.TextColor3 = Theme.Colors.Silver
		vault.ZIndex = 197
	end
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = Theme.Colors.White
	shine.BackgroundTransparency = .58
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(-.4, 0, 0, 0)
	shine.Size = UDim2.new(.18, 0, 1, 0)
	shine.Rotation = 14
	shine.ZIndex = 198
	shine.Parent = pack

	local inventory = panel(screen, UDim2.new(.68, 0, .70, 0), UDim2.fromOffset(210, 58))
	inventory.Name = "InventoryTray"
	inventory.ZIndex = 193
	inventory.BackgroundTransparency = 1
	local inventoryText = label(inventory, "INVENTORY", UDim2.fromOffset(16, 9), UDim2.new(1, -32, 0, 18), 11)
	inventoryText.TextColor3 = accent
	inventoryText.TextXAlignment = Enum.TextXAlignment.Center
	local inventoryHint = label(inventory, leagueClear and "VOLTRA PACK STORED" or "PACK STORED", UDim2.fromOffset(16, 30), UDim2.new(1, -32, 0, 16), 8)
	inventoryHint.TextColor3 = Theme.Colors.Silver
	inventoryHint.TextXAlignment = Enum.TextXAlignment.Center

	TweenService:Create(screen, TweenInfo.new(.2), {BackgroundTransparency = .18}):Play()
	TweenService:Create(title, TweenInfo.new(.24), {TextTransparency = 0}):Play()
	TweenService:Create(subtitle, TweenInfo.new(.28), {TextTransparency = 0}):Play()
	TweenService:Create(glow, TweenInfo.new(.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = .76, Size = UDim2.fromOffset(460, 280)}):Play()
	TweenService:Create(packScale, TweenInfo.new(.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	TweenService:Create(pack, TweenInfo.new(.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = 0}):Play()
	TweenService:Create(shine, TweenInfo.new(.72, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1.18, 0, 0, 0), BackgroundTransparency = 1}):Play()

	for i = 1, 16 do
		local spark = Instance.new("Frame")
		spark.AnchorPoint = Vector2.new(.5, .5)
		spark.Position = UDim2.fromScale(.5, .46)
		spark.Size = UDim2.fromOffset(math.random(5, 10), math.random(12, 26))
		spark.BackgroundColor3 = i % 2 == 0 and accent or Theme.Colors.White
		spark.BackgroundTransparency = .08
		spark.BorderSizePixel = 0
		spark.Rotation = math.random(-40, 40)
		spark.ZIndex = 194
		spark.Parent = screen
		corner(spark, 2)
		local angle = (i / 16) * math.pi * 2
		local radius = math.random(95, 205)
		TweenService:Create(spark, TweenInfo.new(.72, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(.5, math.cos(angle) * radius, .46, math.sin(angle) * radius * .55), BackgroundTransparency = 1, Rotation = spark.Rotation + math.random(-120, 120)}):Play()
		task.delay(.82, function() if spark.Parent then spark:Destroy() end end)
	end

	task.delay(1.35, function()
		if not screen.Parent then return end
		TweenService:Create(pack, TweenInfo.new(.72, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {Position = UDim2.new(.68, 105, .70, 29), Size = UDim2.fromOffset(72, 94), Rotation = 8}):Play()
		TweenService:Create(packScale, TweenInfo.new(.72, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {Scale = .74}):Play()
		TweenService:Create(inventory, TweenInfo.new(.24), {BackgroundTransparency = .08}):Play()
		inventoryHint.Text = leagueClear and "RECEIVING VOLTRA PACK" or "RECEIVING PACK"
	end)

	task.delay(2.22, function()
		if not screen.Parent then return end
		TweenService:Create(pack, TweenInfo.new(.22), {BackgroundTransparency = 1}):Play()
		TweenService:Create(stripe, TweenInfo.new(.22), {BackgroundTransparency = 1}):Play()
		TweenService:Create(inventory, TweenInfo.new(.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(230, 64)}):Play()
		inventoryHint.Text = leagueClear and "VOLTRA PACK STORED" or "PACK STORED"
	end)

	task.delay(3.15, function()
		if not screen.Parent then return end
		TweenService:Create(screen, TweenInfo.new(.35), {BackgroundTransparency = 1}):Play()
		for _, child in screen:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(.25), {TextTransparency = 1}):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(.25), {BackgroundTransparency = 1}):Play()
			end
		end
		task.delay(.38, function() if screen.Parent then screen:Destroy() end end)
	end)
end


function Controller:ShowShotChance(chance:any, actor:Model?)
	if self.ShotChancePopup then
		local oldRoot = self.ShotChancePopup.Root or self.ShotChancePopup
		if oldRoot and oldRoot.Destroy then oldRoot:Destroy() end
		self.ShotChancePopup = nil
	end
	if type(chance) == "table" then
		chance = chance.XG or chance.Chance or chance.ScoringChance
	end
	local number = tonumber(chance) or 0
	if number > 1 then number /= 100 end
	number = math.clamp(number, 0, 1)
	local root = Instance.new("Frame")
	root.Name = "ShotChancePopup"
	root.AnchorPoint = Vector2.new(.5, 0)
	root.Position = UDim2.fromScale(.5, .12)
	root.Size = UDim2.fromOffset(310, 78)
	root.BackgroundColor3 = Theme.Colors.Black
	root.BackgroundTransparency = .08
	root.BorderSizePixel = 0
	root.ZIndex = 62
	root.Parent = self.Gui
	corner(root, 10)
	stroke(root, Theme.Colors.Electric, .18)
	local title = Instance.new("TextLabel")
	title.Name = "XGText"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 6)
	title.Size = UDim2.new(1, -32, 0, 32)
	title.Text = string.format("SHOT QUALITY  /  %d%%", math.floor(number*100+.5))
	title.TextColor3 = Theme.Colors.Electric
	title.TextSize = 25
	title.Font = Theme.Fonts.Display
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 63
	title.Parent = root
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(16, 36)
	subtitle.Size = UDim2.new(1, -32, 0, 18)
	subtitle.Text = "PLACEMENT / POWER / PRESSURE"
	subtitle.TextColor3 = Theme.Colors.White
	subtitle.TextSize = 9
	subtitle.Font = Theme.Fonts.Strong
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.ZIndex = 63
	subtitle.Parent = root
	local scale = Instance.new("UIScale")
	scale.Scale = .82
	scale.Parent = root
	TweenService:Create(scale, TweenInfo.new(.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	self.ShotChancePopup = {Root = root, XG = number}
	task.delay(3.2, function()
		if self.ShotChancePopup and self.ShotChancePopup.Root == root and root.Parent then
			TweenService:Create(root, TweenInfo.new(.2), {BackgroundTransparency = 1}):Play()
			for _, child in root:GetDescendants() do
				if child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(.18), {TextTransparency = 1}):Play()
				elseif child:IsA("UIStroke") then
					TweenService:Create(child, TweenInfo.new(.18), {Transparency = 1}):Play()
				end
			end
			task.delay(.22, function()
				if root.Parent then root:Destroy() end
			end)
			if self.ShotChancePopup and self.ShotChancePopup.Root == root then self.ShotChancePopup = nil end
		end
	end)
end

function Controller:ResolveShotChance(scored:boolean)
	local state = self.ShotChancePopup
	if not state then return end
	self.ShotChancePopup = nil
	local root = state.Root or state
	if not root or not root.Parent then return end
	local resultColor = scored and Theme.Colors.Electric or Color3.fromHex("FF4056")
	local title = root:FindFirstChild("XGText")
	local subtitle = root:FindFirstChild("Subtitle")
	if title and title:IsA("TextLabel") then
		title.TextColor3 = resultColor
	end
	if subtitle and subtitle:IsA("TextLabel") then
		subtitle.Text = scored and "GOAL" or "NO GOAL"
		subtitle.TextColor3 = resultColor
	end
	local line = root:FindFirstChildOfClass("UIStroke")
	if line then line.Color = resultColor end
	task.delay(1.05, function()
		if not root.Parent then return end
		TweenService:Create(root, TweenInfo.new(.18), {BackgroundTransparency = 1}):Play()
		for _, child in root:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(.18), {TextTransparency = 1}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(.18), {Transparency = 1}):Play()
			end
		end
		task.delay(.2, function()
			if root.Parent then root:Destroy() end
		end)
	end)
end


function Controller:ShowResult(payload: any, onReturn: () -> ())
	self:ClearPause()
	if self.PauseButton then
		self.PauseButton.Selectable = false
		self.PauseButton.Visible = false
	end
	local overlay = Instance.new("Frame")
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.05
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 40
	overlay.Active = true
	overlay.Selectable = false
	overlay.Parent = self.Gui
	local resultKind = tostring(payload.Result or "")
	local outcome = resultKind == "Win" and "VICTORY"
		or resultKind == "Loss" and "DEFEAT"
		or resultKind == "ForfeitWin" and "VICTORY"
		or resultKind == "ForfeitLoss" and "FORFEIT"
		or resultKind == "Draw" and "DRAW"
		or (payload.Home > payload.Away and "VICTORY" or payload.Home < payload.Away and "DEFEAT" or "DRAW")
	local won = outcome == "VICTORY"
	local rewardGlow = Instance.new("Frame")
	rewardGlow.Name = "RewardGlow"
	rewardGlow.AnchorPoint = Vector2.new(.5,.5)
	rewardGlow.Position = UDim2.fromScale(.5,.22)
	rewardGlow.Size = UDim2.fromOffset(520,160)
	rewardGlow.BackgroundColor3 = won and Theme.Colors.Electric or Theme.Colors.Gunmetal
	rewardGlow.BackgroundTransparency = won and .72 or 1
	rewardGlow.BorderSizePixel = 0
	rewardGlow.ZIndex = 41
	rewardGlow.Parent = overlay
	corner(rewardGlow,80)
	local glowScale = Instance.new("UIScale")
	glowScale.Scale = .74
	glowScale.Parent = rewardGlow
	if won then
		TweenService:Create(glowScale,TweenInfo.new(.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.12}):Play()
		TweenService:Create(rewardGlow,TweenInfo.new(.7,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=.86}):Play()
		for i=1,18 do
			local shard=Instance.new("Frame")
			shard.AnchorPoint=Vector2.new(.5,.5)
			shard.Position=UDim2.fromScale(.5,.23)
			shard.Size=UDim2.fromOffset(math.random(8,18),math.random(22,46))
			shard.BackgroundColor3=i%3==0 and Theme.Colors.White or Theme.Colors.Electric
			shard.BackgroundTransparency=.08
			shard.BorderSizePixel=0
			shard.Rotation=math.random(-24,24)
			shard.ZIndex=42
			shard.Parent=overlay
			corner(shard,3)
			local angle=(i/18)*math.pi*2
			local radius=math.random(150,330)
			TweenService:Create(shard,TweenInfo.new(.72+math.random()*0.35,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(.5,math.cos(angle)*radius,.23,math.sin(angle)*radius*.38),Rotation=shard.Rotation+math.random(-160,160),BackgroundTransparency=1}):Play()
			task.delay(1.2,function()if shard.Parent then shard:Destroy()end end)
		end
	end
	local title = label(overlay, outcome, UDim2.new(0.2, 0, 0.08, 0), UDim2.new(0.6, 0, 0, 55), 34)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = won and Theme.Colors.Electric or Theme.Colors.White
	local titleScale = Instance.new("UIScale")
	titleScale.Scale = won and .72 or 1
	titleScale.Parent = title
	if won then
		TweenService:Create(titleScale,TweenInfo.new(.44,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.18}):Play()
		task.delay(.46,function()if titleScale.Parent then TweenService:Create(titleScale,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1}):Play()end end)
	end
	local result = label(overlay, self.Home .. "   " .. payload.Home .. " - " .. payload.Away .. "   " .. self.Away, UDim2.new(0.15, 0, 0.18, 0), UDim2.new(0.7, 0, 0, 52), 23)
	result.TextXAlignment = Enum.TextXAlignment.Center
	local stats = payload.Stats or {}
	local home = stats.Home or {}
	local away = stats.Away or {}
	local motm = stats.MOTM or (stats.PlayerRatings and stats.PlayerRatings[1])
	if motm then
		local spotlight = panel(overlay, UDim2.new(.70, 0, .095, 0), UDim2.new(.20, 0, 0, 92))
		spotlight.ZIndex = 44
		spotlight.BackgroundTransparency = .12
		local teamCode = motm.Team == "Away" and self.AwayCode or self.HomeCode
		local kicker = label(spotlight, "FULL TIME PLAYER OF THE MATCH", UDim2.fromOffset(14, 9), UDim2.new(1, -28, 0, 17), 9)
		kicker.TextColor3 = Theme.Colors.Electric
		local name = label(spotlight, string.upper(tostring(motm.Name or "PLAYER")), UDim2.fromOffset(14, 30), UDim2.new(1, -28, 0, 26), 17)
		name.TextColor3 = Theme.Colors.White
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local rating = tonumber(motm.Rating) or 6
		local meta = label(spotlight, teamCode .. "  /  MR " .. string.format("%.1f", rating), UDim2.fromOffset(14, 61), UDim2.new(1, -28, 0, 20), 11)
		meta.TextColor3 = Theme.Colors.Silver
	end
	local tabs=Instance.new("Frame");tabs.Name="ResultTabs";tabs.BackgroundTransparency=1;tabs.Position=UDim2.new(.5,-210,.275,0);tabs.Size=UDim2.fromOffset(420,38);tabs.ZIndex=180;tabs.Parent=overlay;local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,10);tabLayout.Parent=tabs
	local content=panel(overlay,UDim2.new(.10,0,.33,0),UDim2.new(.80,0,.42,0));content.ZIndex=50;content.BackgroundTransparency=.11
	local function teamValue(source:any,...:string):any
		for _,key in {...} do
			local value=source[key]
			if value~=nil then return value end
		end
		return 0
	end
	local function pctText(value:any):string
		local number=tonumber(value)or 0
		return tostring(math.floor(number+.5)).."%"
	end
	local function numberText(value:any):string
		local number=tonumber(value)
		if not number then return tostring(value or 0) end
		if math.abs(number-math.floor(number))>.001 then return string.format("%.2f",number) end
		return tostring(number)
	end
	local function statRow(parent:Instance,index:number,name:string,homeValue:any,awayValue:any,formatter:((any)->string)?)
		local y=58+(index-1)*34
		local row=Instance.new("Frame");row.BackgroundColor3=index%2==0 and Theme.Colors.Gunmetal or Theme.Colors.Black;row.BackgroundTransparency=index%2==0 and .62 or .82;row.BorderSizePixel=0;row.Position=UDim2.fromOffset(0,y);row.Size=UDim2.new(1,-8,0,32);row.ZIndex=53;row.Parent=parent;corner(row,6)
		local format=formatter or numberText
		local left=label(row,format(homeValue),UDim2.new(.10,0,0,5),UDim2.new(.18,0,0,22),14);left.TextXAlignment=Enum.TextXAlignment.Center;left.TextColor3=Theme.Colors.White
		local middle=label(row,name,UDim2.new(.33,0,0,6),UDim2.new(.34,0,0,20),12);middle.TextXAlignment=Enum.TextXAlignment.Center;middle.TextColor3=Theme.Colors.Silver
		local right=label(row,format(awayValue),UDim2.new(.72,0,0,5),UDim2.new(.18,0,0,22),14);right.TextXAlignment=Enum.TextXAlignment.Center;right.TextColor3=Theme.Colors.White
	end
	local teamStats=Instance.new("ScrollingFrame");teamStats.BackgroundTransparency=1;teamStats.BorderSizePixel=0;teamStats.Position=UDim2.fromOffset(26,18);teamStats.Size=UDim2.new(1,-52,1,-34);teamStats.AutomaticCanvasSize=Enum.AutomaticSize.Y;teamStats.CanvasSize=UDim2.new();teamStats.ScrollBarThickness=3;teamStats.ScrollBarImageColor3=Theme.Colors.Electric;teamStats.ZIndex=52;teamStats.Parent=content
	local header=Instance.new("Frame");header.BackgroundTransparency=1;header.Position=UDim2.fromOffset(0,0);header.Size=UDim2.new(1,-8,0,44);header.ZIndex=53;header.Parent=teamStats
	local homeHeader=label(header,self.HomeCode,UDim2.new(.09,0,0,4),UDim2.new(.20,0,0,28),15);homeHeader.TextXAlignment=Enum.TextXAlignment.Center;homeHeader.BackgroundColor3=Theme.Colors.Electric;homeHeader.BackgroundTransparency=.06;homeHeader.TextColor3=Theme.Colors.Black;homeHeader.ZIndex=54;corner(homeHeader,14);renderTeamBadge(homeHeader,self,"Home",2)
	local titleHeader=label(header,"TEAM STATS",UDim2.new(.35,0,0,5),UDim2.new(.30,0,0,24),15);titleHeader.TextXAlignment=Enum.TextXAlignment.Center;titleHeader.TextColor3=Theme.Colors.White
	local awayHeader=label(header,self.AwayCode,UDim2.new(.71,0,0,4),UDim2.new(.20,0,0,28),15);awayHeader.TextXAlignment=Enum.TextXAlignment.Center;awayHeader.BackgroundColor3=Color3.fromHex("24C6B8");awayHeader.BackgroundTransparency=.06;awayHeader.TextColor3=Theme.Colors.Black;awayHeader.ZIndex=54;corner(awayHeader,14);renderTeamBadge(awayHeader,self,"Away",2)
	local rows={
		{"POSSESSION",teamValue(home,"Possession"),teamValue(away,"Possession"),pctText},
		{"SHOTS",teamValue(home,"Shots"),teamValue(away,"Shots")},
		{"SHOTS ON TARGET",teamValue(home,"ShotsOnTarget","OnTarget"),teamValue(away,"ShotsOnTarget","OnTarget")},
		{"SHOTS OFF TARGET",teamValue(home,"ShotsOffTarget","OffTarget"),teamValue(away,"ShotsOffTarget","OffTarget")},
		{"BLOCKED SHOTS",teamValue(home,"BlockedShots","ShotBlocks"),teamValue(away,"BlockedShots","ShotBlocks")},
		{"EXPECTED GOALS",teamValue(home,"ExpectedGoals","xG"),teamValue(away,"ExpectedGoals","xG")},
		{"PASSES ATTEMPTED",teamValue(home,"PassesAttempted","TotalPasses"),teamValue(away,"PassesAttempted","TotalPasses")},
		{"PASSES COMPLETED",teamValue(home,"PassesCompleted","CompletedPasses"),teamValue(away,"PassesCompleted","CompletedPasses")},
		{"PASS ACCURACY",teamValue(home,"PassAccuracy"),teamValue(away,"PassAccuracy"),pctText},
		{"KEY PASSES",teamValue(home,"KeyPasses"),teamValue(away,"KeyPasses")},
		{"BIG CHANCES CREATED",teamValue(home,"BigChanceCreated","BigChancesCreated"),teamValue(away,"BigChanceCreated","BigChancesCreated")},
		{"CROSSES",teamValue(home,"Crosses"),teamValue(away,"Crosses")},
		{"CROSSES COMPLETED",teamValue(home,"CompletedCrosses"),teamValue(away,"CompletedCrosses")},
		{"DRIBBLES COMPLETED",teamValue(home,"DribblesCompleted","SuccessfulDribbles"),teamValue(away,"DribblesCompleted","SuccessfulDribbles")},
		{"DRIBBLE ACCURACY",teamValue(home,"DribbleAccuracy"),teamValue(away,"DribbleAccuracy"),pctText},
		{"TACKLES ATTEMPTED",teamValue(home,"TacklesAttempted"),teamValue(away,"TacklesAttempted")},
		{"TACKLES COMPLETED",teamValue(home,"TacklesCompleted"),teamValue(away,"TacklesCompleted")},
		{"INTERCEPTIONS",teamValue(home,"Interceptions"),teamValue(away,"Interceptions")},
		{"CLEARANCES",teamValue(home,"Clearances"),teamValue(away,"Clearances")},
		{"ERRORS",teamValue(home,"Errors"),teamValue(away,"Errors")},
		{"SAVES",teamValue(home,"Saves"),teamValue(away,"Saves")},
		{"CORNERS",teamValue(home,"Corners"),teamValue(away,"Corners")},
		{"FOULS",teamValue(home,"Fouls"),teamValue(away,"Fouls")},
		{"OFFSIDES",teamValue(home,"Offsides"),teamValue(away,"Offsides")},
		{"YELLOW CARDS",teamValue(home,"YellowCards"),teamValue(away,"YellowCards")},
		{"RED CARDS",teamValue(home,"RedCards"),teamValue(away,"RedCards")},
		{"DISTANCE COVERED",teamValue(home,"DistanceCovered"),teamValue(away,"DistanceCovered")},
		{"SPRINTS",teamValue(home,"Sprints"),teamValue(away,"Sprints")},
	}
	for index,row in rows do statRow(teamStats,index,row[1],row[2],row[3],row[4]) end
	local ratings=Instance.new("ScrollingFrame");ratings.BackgroundTransparency=1;ratings.BorderSizePixel=0;ratings.Position=UDim2.fromOffset(18,14);ratings.Size=UDim2.new(1,-36,1,-28);ratings.CanvasSize=UDim2.fromOffset(1320,820);ratings.ScrollBarThickness=5;ratings.ScrollingDirection=Enum.ScrollingDirection.XY;ratings.ScrollBarImageColor3=Theme.Colors.Electric;ratings.Visible=false;ratings.ZIndex=52;ratings.Parent=content
	local function eventValue(entry:any,key:string):number local events=entry.Events or{};return tonumber(events[key])or 0 end
	local function pct(done:number,total:number):string return tostring(done).."/"..tostring(total).." "..(total>0 and tostring(math.floor(done/total*100+.5)).."%"or"0%")end
	local columns={{"TEAM",0,54},{"POS",58,42},{"PLAYER",104,210},{"MR",318,44},{"KP",366,40},{"BC",410,40},{"SOT",454,44},{"SH",502,42},{"DRB",548,72},{"PASS",624,88},{"CROSS",716,80},{"INT",802,44},{"BLK",850,44},{"ERR",898,44}}
	local function headerRow(y:number,title:string,team:string)
		local sep=Instance.new("Frame");sep.Position=UDim2.fromOffset(0,y);sep.Size=UDim2.fromOffset(960,38);sep.BackgroundColor3=team=="Home"and Theme.Colors.Electric or Color3.fromHex("24C6B8");sep.BackgroundTransparency=.08;sep.BorderSizePixel=0;sep.ZIndex=53;sep.Parent=ratings;corner(sep,6)
		local badge=label(sep,team=="Home"and self.HomeCode or self.AwayCode,UDim2.fromOffset(10,6),UDim2.fromOffset(46,24),12);badge.TextXAlignment=Enum.TextXAlignment.Center;badge.TextColor3=Theme.Colors.Black;renderTeamBadge(badge,self,team,1)
		local titleLabel=label(sep,title,UDim2.fromOffset(66,6),UDim2.fromOffset(250,24),14);titleLabel.TextColor3=Theme.Colors.Black
		for _,c in columns do if c[1]~="TEAM"then local h=label(sep,c[1],UDim2.fromOffset(c[2],7),UDim2.fromOffset(c[3],22),12);h.TextXAlignment=Enum.TextXAlignment.Center;h.TextColor3=Theme.Colors.Black end end
	end
	local function playerRow(entry:any,y:number)
		local events=entry.Events or{}
		local passDone=eventValue(entry,"SuccessfulPass");local passBad=eventValue(entry,"BadPass");local passAttempts=passDone+passBad+eventValue(entry,"PassAttempt")
		if passAttempts<passDone+passBad then passAttempts=passDone+passBad end
		local drbDone=eventValue(entry,"SuccessfulDribble");local drbBad=eventValue(entry,"FailedDribble")
		local crossDone=eventValue(entry,"CrossCompleted");local crossAttempts=crossDone+eventValue(entry,"CrossAttempt")
		local values={
			entry.Team=="Home"and self.HomeCode or self.AwayCode,
			tostring(entry.Position or"--"),
			string.upper(tostring(entry.Name or"PLAYER")),
			string.format("%.1f",tonumber(entry.Rating)or 6),
			tostring(eventValue(entry,"KeyPass")),
			tostring(eventValue(entry,"BigChanceCreated")),
			tostring(eventValue(entry,"ShotOnTarget")),
			tostring(eventValue(entry,"Shot")),
			pct(drbDone,drbDone+drbBad),
			pct(passDone,passAttempts),
			tostring(crossDone).."/"..tostring(crossAttempts),
			tostring(eventValue(entry,"Interception")),
			tostring(eventValue(entry,"Block")),
			tostring(eventValue(entry,"ErrorLeadingToGoal")+eventValue(entry,"Error")),
		}
		local row=Instance.new("Frame");row.Position=UDim2.fromOffset(0,y);row.Size=UDim2.fromOffset(960,40);row.BackgroundColor3=Theme.Colors.Black;row.BackgroundTransparency=.38;row.BorderSizePixel=0;row.ZIndex=53;row.Parent=ratings;corner(row,5)
		local motm=stats.MOTM and stats.MOTM.playerId==entry.playerId
		for i,c in columns do local cell=label(row,(motm and i==3 and"* "or"")..values[i],UDim2.fromOffset(c[2],8),UDim2.fromOffset(c[3],24),i==3 and 13 or 12);cell.TextXAlignment=i==3 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center;cell.TextTruncate=Enum.TextTruncate.AtEnd;cell.TextColor3=motm and Theme.Colors.Electric or entry.Team=="Home"and Theme.Colors.White or Theme.Colors.Silver end
	end
	local y=0
	for _,team in{"Home","Away"}do
		headerRow(y,team=="Home"and"HOME TEAM"or"AWAY TEAM",team);y+=44
		for _,entry in stats.PlayerRatings or{}do if entry.Team==team then playerRow(entry,y);y+=44 end end
		y+=16
	end
	ratings.CanvasSize=UDim2.fromOffset(980,math.max(520,y+20))
	local teamButton=actionButton(tabs,"TEAM STATS",1,function()teamStats.Visible=true;ratings.Visible=false end);teamButton.Size=UDim2.fromOffset(205,38);teamButton.ZIndex=182
	local ratingButton=actionButton(tabs,"MATCH RATINGS",2,function()teamStats.Visible=false;ratings.Visible=true end);ratingButton.Size=UDim2.fromOffset(205,38);ratingButton.ZIndex=182
	for _,tab in tabs:GetDescendants()do if tab:IsA("GuiObject")then tab.ZIndex=182 end end
	if payload.Reward then
		local reward=panel(overlay,UDim2.new(.5,-150,.775,0),UDim2.fromOffset(300,44));reward.ZIndex=70
		local rewardScale=Instance.new("UIScale");rewardScale.Scale=.4;rewardScale.Parent=reward
		local rewardText=label(reward,"*  "..string.upper(payload.Reward.Title).."   +"..tostring(payload.Reward.Coins or 0).." COINS   +"..tostring(payload.Reward.XP or 0).." XP",UDim2.fromOffset(8,7),UDim2.new(1,-16,0,22),9);rewardText.TextColor3=Theme.Colors.Electric;rewardText.TextXAlignment=Enum.TextXAlignment.Center
		TweenService:Create(rewardScale,TweenInfo.new(.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	end
	local returning = false
	local button: TextButton?
	button = actionButton(overlay, "RETURN TO MENU", 1, function()
		if not button then return end
		if returning then return end
		returning = true
		button.Text = payload.Ranked and "RETURNING..." or "LOADING MENU..."
		button.AutoButtonColor = false
		button.Active = false
		task.spawn(function()
			local response = MatchSetupService:ReturnToMenu()
			if payload.Ranked then
				if type(response) == "table" and response.Success == false then
					returning = false
					button.Active = true
					button.Text = "RETURN FAILED - TRY AGAIN"
				else
					button.Text = "TELEPORTING TO MENU..."
				end
				return
			end
			onReturn()
		end)
	end)
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.fromScale(0.5, 0.90)
	button.Size = UDim2.fromOffset(230, 48)
	button.ZIndex = 72
	button.Selectable = true
	button.SelectionOrder = 10
	teamButton.Selectable = true
	teamButton.SelectionOrder = 1
	ratingButton.Selectable = true
	ratingButton.SelectionOrder = 2
	teamButton.NextSelectionRight = ratingButton
	teamButton.NextSelectionDown = button
	ratingButton.NextSelectionLeft = teamButton
	ratingButton.NextSelectionDown = button
	button.NextSelectionUp = teamButton
	button.NextSelectionLeft = teamButton
	button.NextSelectionRight = ratingButton
	task.defer(function()
		if button and button.Parent then
			GuiService.SelectedObject = button
		end
	end)
end

function Controller:Destroy()
	if self.Gui then
		self.Gui:Destroy()
	end
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

return Controller
