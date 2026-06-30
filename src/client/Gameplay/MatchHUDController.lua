--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
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

local function actionButton(parent: Instance, text: string, order: number, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = text
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 42)
	button.BackgroundColor3 = order == 1 and Theme.Colors.Electric or Theme.Colors.Gunmetal
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Selectable = false
	button.SelectionImageObject = nil
	button.Text = text
	button.TextColor3 = order == 1 and Theme.Colors.Black or Theme.Colors.White
	button.TextSize = 12
	button.Font = Theme.Fonts.Display
	button.Parent = parent
	corner(button, 5)
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

	local board = panel(gui, UDim2.fromOffset(18, 58), UDim2.fromOffset(132, 56))
	board.BackgroundTransparency = 0.02
	board.Visible = false
	local boardCorner = board:FindFirstChildOfClass("UICorner")
	if boardCorner then boardCorner:Destroy() end
	local boardStroke = board:FindFirstChildOfClass("UIStroke")
	if boardStroke then boardStroke.Transparency = 0.88 end
	local scoreScale = Instance.new("UIScale")
	scoreScale.Parent = board
	local strip = Instance.new("Frame")
	strip.Name = "BroadcastStrip"
	strip.BackgroundColor3 = Theme.Colors.Electric
	strip.BorderSizePixel = 0
	strip.Position = UDim2.fromOffset(0, 0)
	strip.Size = UDim2.fromOffset(25, 56)
	strip.ZIndex = 11
	strip.Parent = board
	local stripTop = label(strip, "V", UDim2.fromOffset(0, 4), UDim2.new(1, 0, 0, 22), 15)
	stripTop.TextXAlignment = Enum.TextXAlignment.Center;stripTop.TextColor3 = Theme.Colors.Black
	local stripBottom = label(strip, "V", UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 22), 15)
	stripBottom.TextXAlignment = Enum.TextXAlignment.Center;stripBottom.TextColor3 = Theme.Colors.Black
	local main = Instance.new("Frame")
	main.Name = "BroadcastScoreMain"
	main.BackgroundColor3 = Theme.Colors.Black
	main.BorderSizePixel = 0
	main.Position = UDim2.fromOffset(25, 0)
	main.Size = UDim2.fromOffset(107, 38)
	main.ZIndex = 11
	main.Parent = board
	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Theme.Colors.Electric
	mainStroke.Transparency = 0.58
	mainStroke.Thickness = 1
	mainStroke.Parent = main
	local clockPanel = Instance.new("Frame")
	clockPanel.Name = "BroadcastClockPanel"
	clockPanel.BackgroundColor3 = Theme.Colors.White
	clockPanel.BorderSizePixel = 0
	clockPanel.Position = UDim2.fromOffset(25, 38)
	clockPanel.Size = UDim2.fromOffset(107, 18)
	clockPanel.ZIndex = 11
	clockPanel.Parent = board
	local clockAccent = Instance.new("Frame")
	clockAccent.BackgroundColor3 = Theme.Colors.Electric
	clockAccent.BorderSizePixel = 0
	clockAccent.Position = UDim2.new(1, -18, 0, 0)
	clockAccent.Size = UDim2.fromOffset(18, 18)
	clockAccent.ZIndex = 12
	clockAccent.Parent = clockPanel
	local homeCode = label(main, shortCode(data.Home), UDim2.fromOffset(5, 0), UDim2.fromOffset(34, 18), 12)
	homeCode.TextColor3 = Theme.Colors.White
	local awayCode = label(main, shortCode(data.Away), UDim2.fromOffset(5, 19), UDim2.fromOffset(34, 18), 12)
	awayCode.TextColor3 = Theme.Colors.White
	local homeBadge = label(main, string.sub(tostring(data.HomeLogo or shortCode(data.Home)), 1, 2), UDim2.fromOffset(41, 3), UDim2.fromOffset(14, 11), 6)
	homeBadge.TextXAlignment = Enum.TextXAlignment.Center;homeBadge.BackgroundColor3=badgeColor(data.HomeColor,Theme.Colors.Electric);homeBadge.BackgroundTransparency=0;homeBadge.TextColor3=Theme.Colors.Black
	local awayBadge = label(main, string.sub(tostring(data.AwayLogo or shortCode(data.Away)), 1, 2), UDim2.fromOffset(41, 22), UDim2.fromOffset(14, 11), 6)
	awayBadge.TextXAlignment = Enum.TextXAlignment.Center;awayBadge.BackgroundColor3=badgeColor(data.AwayColor,Theme.Colors.Silver);awayBadge.BackgroundTransparency=0;awayBadge.TextColor3=Theme.Colors.Black
	local homeScoreLabel = label(main, "0", UDim2.fromOffset(86, 0), UDim2.fromOffset(18, 18), 12)
	homeScoreLabel.TextXAlignment = Enum.TextXAlignment.Center
	local awayScoreLabel = label(main, "0", UDim2.fromOffset(86, 19), UDim2.fromOffset(18, 18), 12)
	awayScoreLabel.TextXAlignment = Enum.TextXAlignment.Center
	local score = label(main, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), 1)
	score.Visible = false
	local clock = label(clockPanel, "00:00", UDim2.fromOffset(5, 0), UDim2.new(1, -10, 1, 0), 10)
	clock.TextXAlignment = Enum.TextXAlignment.Left
	clock.TextColor3 = Theme.Colors.Black
	local possession = label(board, "", UDim2.fromOffset(42, 54), UDim2.new(1, -48, 0, 16), 9)
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
	local activeBadge = label(activePanel,string.sub(tostring(data.HomeLogo or shortCode(data.Home)),1,2),UDim2.fromOffset(8,11),UDim2.fromOffset(42,42),13)
	activeBadge.TextXAlignment=Enum.TextXAlignment.Center;activeBadge.BackgroundColor3=badgeColor(data.HomeColor,Theme.Colors.Electric);activeBadge.BackgroundTransparency=0.08;activeBadge.TextColor3=Theme.Colors.Black;corner(activeBadge,21)
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
	local opponentBadge = label(targetPanel,string.sub(tostring(data.AwayLogo or shortCode(data.Away)),1,2),UDim2.new(1,-50,0,11),UDim2.fromOffset(42,42),13)
	opponentBadge.TextXAlignment=Enum.TextXAlignment.Center;opponentBadge.BackgroundColor3=badgeColor(data.AwayColor,Theme.Colors.Silver);opponentBadge.BackgroundTransparency=0.08;opponentBadge.TextColor3=Theme.Colors.Black;corner(opponentBadge,21)
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

	local help = label(gui, "WASD MOVE   SHIFT SPRINT   LMB SHOOT   RMB PASS   ALT+RMB LOB   CTRL+RMB MANUAL   ALT+CTRL+RMB MANUAL LOB   E TACKLE   F SLIDE   R BLOCK   C DRIBBLE   Q SWITCH", UDim2.new(0.5, -520, 1, -31), UDim2.fromOffset(1040, 18), 9)
	help.TextXAlignment = Enum.TextXAlignment.Center
	help.TextColor3 = Theme.Colors.Silver
	help.Visible = false
	local testCorner=Instance.new("TextButton");testCorner.Name="TestCorner";testCorner.AnchorPoint=Vector2.new(1,0);testCorner.Position=UDim2.new(1,-18,0,18);testCorner.Size=UDim2.fromOffset(126,32);testCorner.BackgroundColor3=Theme.Colors.Gunmetal;testCorner.BackgroundTransparency=.08;testCorner.BorderSizePixel=0;testCorner.AutoButtonColor=false;testCorner.Selectable=false;testCorner.Text="TEST CORNER";testCorner.TextColor3=Theme.Colors.Electric;testCorner.TextSize=10;testCorner.Font=Theme.Fonts.Display;testCorner.ZIndex=12;testCorner.Parent=gui;corner(testCorner,5);stroke(testCorner,Theme.Colors.Electric,.45)

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
		Home = data.Home,
		Away = data.Away,
		HomeLineup = data.HomeLineup or {},
		AwayLineup = data.AwayLineup or {},
		HomeCode = shortCode(data.Home),
		AwayCode = shortCode(data.Away),
		PitchWidth = data.PitchWidth or 80,
		PitchLength = data.PitchLength or 120,
		TestCorner=testCorner,
	}, Controller)
	testCorner.Activated:Connect(function()if result.CornerTestCallback then result.CornerTestCallback();result:Flash("Loading test corner",.7)end end)
	return result
end

function Controller:SetCornerTestCallback(callback:()->())self.CornerTestCallback=callback end
function Controller:SetPauseButtonCallback(callback:()->())self.PauseButtonCallback=callback end

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
	board.Visible = true
	board.Position = UDim2.fromOffset(-150, 58)
	board.BackgroundTransparency = 1
	self.ScoreScale.Scale = 0.96

	local strip = self.Strip
	local main = self.ScoreMain
	local clockPanel = self.ClockPanel
	local clockAccent = self.ClockAccent
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
	if strip then strip.Size = UDim2.fromOffset(0, 56); strip.BackgroundColor3 = Theme.Colors.White end
	if main then main.Size = UDim2.fromOffset(0, 38); main.BackgroundTransparency = 1 end
	if clockPanel then clockPanel.Size = UDim2.fromOffset(0, 18); clockPanel.BackgroundTransparency = 1 end
	if clockAccent then clockAccent.Size = UDim2.fromOffset(0, 18); clockAccent.BackgroundTransparency = 1 end

	local assembly = Instance.new("Folder")
	assembly.Name = "ScoreboardAssemblyFX"
	assembly.Parent = board
	for index = 1, 3 do
		local rail = Instance.new("Frame")
		rail.Name = "AssemblyRail" .. index
		rail.BackgroundColor3 = index == 2 and Theme.Colors.White or Theme.Colors.Electric
		rail.BackgroundTransparency = 0.15
		rail.BorderSizePixel = 0
		rail.Position = UDim2.fromOffset(8 + index * 22, index == 2 and -7 or 61)
		rail.Size = UDim2.fromOffset(20, 2)
		rail.ZIndex = 18
		rail.Parent = assembly
		tween(rail, 0.34 + index * 0.05, {Position = UDim2.fromOffset(12 + index * 28, index == 2 and 26 or 28), BackgroundTransparency = 1}, Enum.EasingStyle.Quad)
	end
	local scanner = Instance.new("Frame")
	scanner.Name = "AssemblyScanner"
	scanner.BackgroundColor3 = Theme.Colors.Electric
	scanner.BackgroundTransparency = 0.05
	scanner.BorderSizePixel = 0
	scanner.Position = UDim2.fromOffset(-8, 0)
	scanner.Size = UDim2.fromOffset(4, 56)
	scanner.ZIndex = 19
	scanner.Parent = assembly

	tween(board, 0.28, {Position = UDim2.fromOffset(18, 58), BackgroundTransparency = 0.02}, Enum.EasingStyle.Back)
	task.delay(0.08, function()
		if strip then tween(strip, 0.2, {Size = UDim2.fromOffset(25, 56), BackgroundColor3 = Theme.Colors.Electric}, Enum.EasingStyle.Back) end
	end)
	task.delay(0.18, function()
		if main then tween(main, 0.32, {Size = UDim2.fromOffset(107, 38), BackgroundTransparency = 0}, Enum.EasingStyle.Quart) end
		tween(scanner, 0.48, {Position = UDim2.fromOffset(136, 0), BackgroundTransparency = 0.82}, Enum.EasingStyle.Sine)
	end)
	task.delay(0.34, function()
		if clockPanel then tween(clockPanel, 0.25, {Size = UDim2.fromOffset(107, 18), BackgroundTransparency = 0}, Enum.EasingStyle.Quart) end
		if clockAccent then tween(clockAccent, 0.22, {Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0}, Enum.EasingStyle.Back) end
	end)
	task.delay(0.48, function()
		for _, item in textParts do
			if item and item:IsA("TextLabel") then tween(item, 0.18, {TextTransparency = 0}, Enum.EasingStyle.Quad) end
		end
		for _, item in {self.HomeBadge, self.AwayBadge} do
			if item and item:IsA("TextLabel") then tween(item, 0.18, {TextTransparency = 0, BackgroundTransparency = 0}, Enum.EasingStyle.Quad) end
		end
		tween(self.ScoreScale, 0.22, {Scale = 1.05}, Enum.EasingStyle.Back)
		task.delay(0.18, function()
			if self.ScoreScale.Parent then tween(self.ScoreScale, 0.16, {Scale = 1}, Enum.EasingStyle.Quad) end
		end)
	end)
	task.delay(0.82, function()
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
	local enduranceRatio=math.clamp(endurance or 1,0,1);local reserveRatio=math.clamp(value,0,enduranceRatio)
	self.EnduranceFill.Size=UDim2.fromScale(enduranceRatio,1)
	self.Fill.Size=UDim2.fromScale(enduranceRatio>.001 and reserveRatio/enduranceRatio or 0,.5)
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

function Controller:ShowSubSuggestion(data:any,respond:(boolean)->())
	if self.SubSuggestion then self.SubSuggestion:Destroy()end
	local box=panel(self.Gui,UDim2.new(1,-318,.48,-70),UDim2.fromOffset(294,140));box.ZIndex=26;self.SubSuggestion=box
	local title=label(box,"QUICK SUB  /  "..tostring(data.Role),UDim2.fromOffset(14,10),UDim2.new(1,-28,0,20),10);title.TextColor3=Theme.Colors.Electric
	label(box,string.upper(tostring(data.Outgoing)).."  →  "..string.upper(tostring(data.Incoming)),UDim2.fromOffset(14,34),UDim2.new(1,-28,0,34),11)
	label(box,"INCOMING OVR "..tostring(data.IncomingOverall).."  /  CURRENT ENDURANCE "..tostring(data.Endurance).."%",UDim2.fromOffset(14,66),UDim2.new(1,-28,0,18),7).TextColor3=Theme.Colors.Silver
	local accept=actionButton(box,"SUB NOW",1,function()if box.Parent then box:Destroy()end;self.SubSuggestion=nil;respond(true)end);accept.Position=UDim2.fromOffset(14,96);accept.Size=UDim2.fromOffset(128,32);accept.ZIndex=27
	local skip=actionButton(box,"SKIP",2,function()if box.Parent then box:Destroy()end;self.SubSuggestion=nil;respond(false)end);skip.Position=UDim2.fromOffset(152,96);skip.Size=UDim2.fromOffset(128,32);skip.ZIndex=27
end

function Controller:ShowPauseQueue(playerName:string,queued:boolean)
	if self.PauseQueueBanner then self.PauseQueueBanner:Destroy();self.PauseQueueBanner=nil end
	local box=panel(self.Gui,UDim2.new(.5,-190,0,86),UDim2.fromOffset(380,38))
	box.Name="PauseQueueBanner"
	box.ZIndex=48
	box.BackgroundTransparency=.08
	self.PauseQueueBanner=box
	local text=queued and(string.upper(playerName).." QUEUED A PAUSE")or(string.upper(playerName).." CANCELLED PAUSE QUEUE")
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

function Controller:ShowHalfTime(payload: any)
	if self.HalfTimePanel then
		self.HalfTimePanel:Destroy()
	end
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
	label(badge,entry.Team=="Away"and self.AwayCode or self.HomeCode,UDim2.fromScale(0,0),UDim2.fromScale(1,1),16).TextXAlignment=Enum.TextXAlignment.Center
	local title=label(left,"PLAYER OF\nTHE HALF",UDim2.fromScale(.07,.06),UDim2.fromScale(.48,.15),27);title.TextColor3=Theme.Colors.White;title.TextWrapped=true
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
	local xg=math.floor((tonumber(events.ExpectedGoals)or 0)*100+.5)/100
	local rows={{"MATCH RATING",string.format("%.1f",tonumber(entry.Rating)or 6)},{"GOALS",tostring(entry.Goals or 0)},{"ASSISTS",tostring(entry.Assists or 0)},{"SHOTS ON TARGET",tostring(events.ShotOnTarget or 0)},{"XG",tostring(xg)},{"DEFENSIVE CONTRIBUTIONS",tostring(defensive)},{"PASSES COMPLETED",tostring(events.SuccessfulPass or 0)},{"PASS ACCURACY",tostring(passAccuracy).."%"}}
	local statsTitle=label(left,"STATS",UDim2.fromScale(.08,.63),UDim2.fromScale(.18,.04),13);statsTitle.TextColor3=Theme.Colors.Electric
	for i,row in rows do
		local y=.68+(i-1)*.035
		local name=label(left,row[1],UDim2.fromScale(.08,y),UDim2.fromScale(.48,.03),10);name.TextColor3=Theme.Colors.White
		local val=label(left,row[2],UDim2.fromScale(.44,y),UDim2.fromScale(.12,.03),10);val.TextXAlignment=Enum.TextXAlignment.Right;val.TextColor3=Theme.Colors.White
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
	task.delay(7.2, function()
		if self.HalfTimePanel == value then
			TweenService:Create(value,TweenInfo.new(.48,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=UDim2.fromScale(-.45,.49)}):Play()
			TweenService:Create(scale,TweenInfo.new(.48,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Scale=.94}):Play()
			task.delay(.5,function()if value.Parent then value:Destroy()end;if self.HalfTimePanel==value then self.HalfTimePanel=nil end end)
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
	local pauseTimer=label(overlay,tostring(payload and payload.PauseRemaining or 60).."s",UDim2.new(.5,-110,0,34),UDim2.fromOffset(220,48),30);pauseTimer.TextXAlignment=Enum.TextXAlignment.Center;pauseTimer.TextColor3=Theme.Colors.Electric;pauseTimer.Name="PauseTimerLabel";pauseTimer.ZIndex=135
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
	local body=Instance.new("ScrollingFrame");body.BackgroundTransparency=1;body.BorderSizePixel=0;body.Position=UDim2.fromOffset(18,58);body.Size=UDim2.new(1,-36,1,-76);body.CanvasSize=UDim2.new();body.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.ScrollBarThickness=4;body.ScrollBarImageColor3=Theme.Colors.Electric;body.ZIndex=97;body.Parent=content
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
		card.Position=pos;card.Size=size;card.BackgroundColor3=Theme.Colors.Black;card.BackgroundTransparency=.1;card.BorderSizePixel=0;card.AutoButtonColor=false;card.Selectable=false;card.Text="";card.ZIndex=99;card.Parent=parent
		corner(card,6);stroke(card,Theme.Colors.Electric,.58)
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
		local ovr=label(card,tostring(entry.Overall or entry.overall or 0),UDim2.fromOffset(7,5),UDim2.fromOffset(32,15),10);ovr.TextColor3=Theme.Colors.Electric
		local p=label(card,string.upper(tostring(entry.Position or entry.bestPosition or"--")),UDim2.new(1,-38,0,5),UDim2.fromOffset(31,15),8);p.TextXAlignment=Enum.TextXAlignment.Right;p.TextColor3=Theme.Colors.Silver
		local name=label(card,string.upper(tostring(entry.Name or entry.displayName or entry.shortName or"PLAYER")),UDim2.fromOffset(5,size.Y.Offset-29),UDim2.new(1,-10,0,15),7);name.TextXAlignment=Enum.TextXAlignment.Center;name.TextTruncate=Enum.TextTruncate.AtEnd
		local number=label(card,"#" .. tostring(entry.Number or entry.shirtNumber or 0),UDim2.fromOffset(7,size.Y.Offset-15),UDim2.new(1,-14,0,11),6);number.TextXAlignment=Enum.TextXAlignment.Center;number.TextColor3=Theme.Colors.Silver
		if onClick then card.Activated:Connect(function()onClick(entry)end)end
		return card
	end
	local function showManagement()
		clearBody("TEAM MANAGEMENT")
		content.Size=UDim2.new(.68,0,.84,0);content.Position=UDim2.new(.28,0,.08,0)
		local canvas=Instance.new("Frame");canvas.BackgroundTransparency=1;canvas.Size=UDim2.new(1,-8,0,560);canvas.ZIndex=98;canvas.Parent=body
		local pitch=panel(canvas,UDim2.fromOffset(0,0),UDim2.new(.62,-8,0,380));pitch.ZIndex=98;pitch.BackgroundColor3=Color3.fromHex("07130C");pitch.BackgroundTransparency=.04
		local pitchTitle=label(pitch,"SQUAD  /  FORMATION 4-3-3",UDim2.fromOffset(14,10),UDim2.new(1,-28,0,18),9);pitchTitle.TextColor3=Theme.Colors.Electric
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
		local coords={GK=Vector2.new(.50,.86),LB=Vector2.new(.18,.68),CB=Vector2.new(.38,.68),CB2=Vector2.new(.62,.68),RB=Vector2.new(.82,.68),CDM=Vector2.new(.50,.52),CM=Vector2.new(.32,.43),CM2=Vector2.new(.68,.43),LW=Vector2.new(.18,.22),ST=Vector2.new(.50,.16),RW=Vector2.new(.82,.22)}
		local used:any={}
		local function coordFor(entry:any,index:number):Vector2
			local pos=string.upper(tostring(entry.Position or""))
			if pos=="CB"and used.CB then pos="CB2"end
			if pos=="CM"and used.CM then pos="CM2"end
			used[pos]=true
			return coords[pos]or Vector2.new(.18+((index-1)%4)*.21,.28+math.floor((index-1)/4)*.18)
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
		local header=Instance.new("Frame");header.BackgroundColor3=Theme.Colors.Gunmetal;header.BackgroundTransparency=.18;header.BorderSizePixel=0;header.Size=UDim2.new(1,-8,0,30);header.ZIndex=98;header.Parent=body;corner(header,5)
		local cols={{"POS",.02,.08},{"NAME",.11,.34},{"MR",.46,.08},{"G",.56,.05},{"AST",.63,.06},{"SOT",.72,.06},{"XG",.80,.07},{"DEF",.90,.08}}
		for _,c in cols do local h=label(header,c[1],UDim2.new(c[2],0,0,7),UDim2.new(c[3],0,0,16),8);h.TextColor3=Theme.Colors.Electric end
		for _,entry in stats.PlayerRatings or{}do
			local events=entry.Events or{}
			local rowFrame=Instance.new("Frame");rowFrame.BackgroundColor3=entry.Team==controlledSide and Theme.Colors.Black or Theme.Colors.Gunmetal;rowFrame.BackgroundTransparency=entry.Team==controlledSide and .18 or .42;rowFrame.BorderSizePixel=0;rowFrame.Size=UDim2.new(1,-8,0,32);rowFrame.ZIndex=98;rowFrame.Parent=body;corner(rowFrame,5)
			local values={entry.Position or"--",string.upper(entry.Name or"PLAYER"),string.format("%.1f",entry.Rating or 6),tostring(entry.Goals or 0),tostring(entry.Assists or 0),tostring(events.ShotOnTarget or 0),tostring(events.ExpectedGoals or 0),tostring(entry.DefensiveActions or 0)}
			for i,c in cols do local cell=label(rowFrame,values[i],UDim2.new(c[2],0,0,8),UDim2.new(c[3],0,0,16),8);cell.TextColor3=i==3 and Theme.Colors.Electric or Theme.Colors.White end
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
		local title=label(page,"TEAM MANAGEMENT",UDim2.fromOffset(28,24),UDim2.new(.45,0,0,38),28);title.TextColor3=Theme.Colors.Electric
		label(page,"SQUAD  /  TACTICS  /  ASSIGNMENTS",UDim2.fromOffset(30,64),UDim2.new(.5,0,0,18),10).TextColor3=Theme.Colors.Silver
		local back=actionButton(page,"‹ BACK",1,function()if self.TeamManagementPage then self.TeamManagementPage:Destroy();self.TeamManagementPage=nil end;menu.Visible=true;content.Visible=true end);back.Position=UDim2.new(1,-150,0,24);back.Size=UDim2.fromOffset(118,36);back.ZIndex=133
		back.Activated:Connect(function()content.Visible=false end)
		local pitch=panel(page,UDim2.fromOffset(28,100),UDim2.new(.58,-42,.62,0));pitch.ZIndex=131;pitch.BackgroundColor3=Color3.fromHex("07170B");pitch.BackgroundTransparency=.03
		local info=panel(page,UDim2.new(.60,0,0,100),UDim2.new(.37,0,.62,0));info.ZIndex=131;info.BackgroundTransparency=.07
		local benchPanel=panel(page,UDim2.new(0,28,.75,0),UDim2.new(.94,0,.18,0));benchPanel.ZIndex=131;benchPanel.BackgroundTransparency=.08
		label(pitch,"4-3-3",UDim2.fromOffset(14,12),UDim2.new(1,-28,0,20),10).TextColor3=Theme.Colors.Electric
		label(benchPanel,"SUBSTITUTES",UDim2.fromOffset(16,10),UDim2.new(1,-32,0,18),10).TextColor3=Theme.Colors.Electric
		local infoHolder=Instance.new("Frame");infoHolder.BackgroundTransparency=1;infoHolder.Position=UDim2.fromOffset(20,44);infoHolder.Size=UDim2.new(1,-40,1,-64);infoHolder.ZIndex=134;infoHolder.Parent=info
		label(info,"PLAYER INFO",UDim2.fromOffset(20,16),UDim2.new(1,-40,0,20),11).TextColor3=Theme.Colors.Electric
		local function setInfo(entry:any?)
			for _,child in infoHolder:GetChildren()do child:Destroy()end
			if not entry then local blank=label(infoHolder,"SELECT A PLAYER",UDim2.fromScale(0,.34),UDim2.new(1,0,0,30),18);blank.TextXAlignment=Enum.TextXAlignment.Center;blank.TextColor3=Theme.Colors.Silver;return end
			local portraitOk,portrait=pcall(function()return AvatarPortraitGenerator.new(infoHolder,entry,UDim2.fromOffset(86,86),false)end)
			if portraitOk and portrait then portrait.Position=UDim2.fromOffset(0,0);portrait.ZIndex=135 end
			label(infoHolder,string.upper(tostring(entry.Name or entry.displayName or entry.shortName or"PLAYER")),UDim2.fromOffset(100,2),UDim2.new(1,-100,0,30),20)
			label(infoHolder,"OVR "..tostring(entry.Overall or entry.overall or 60).."   POS "..string.upper(tostring(entry.Position or entry.bestPosition or"--")).."   KIT #"..tostring(entry.Number or entry.shirtNumber or 0),UDim2.fromOffset(100,40),UDim2.new(1,-100,0,18),10).TextColor3=Theme.Colors.Silver
			for i,row in ipairs({{"Energy",entry.Stamina or entry.stamina or 100},{"Match Rating",entry.Rating or 6},{"PAC",entry.PAC or(entry.mainStats and entry.mainStats.PAC)or 60},{"SHO",entry.SHO or(entry.mainStats and entry.mainStats.SHO)or 60},{"PAS",entry.PAS or(entry.mainStats and entry.mainStats.PAS)or 60},{"DRI",entry.DRI or(entry.mainStats and entry.mainStats.DRI)or 60},{"DEF",entry.DEF or(entry.mainStats and entry.mainStats.DEF)or 60},{"PHY",entry.PHY or(entry.mainStats and entry.mainStats.PHY)or 60},{"Goals",entry.Goals or 0},{"Assists",entry.Assists or 0},{"Defensive Actions",entry.DefensiveActions or 0}})do label(infoHolder,string.upper(row[1]).."   "..tostring(row[2]),UDim2.fromOffset(0,96+i*22),UDim2.new(1,0,0,18),9).TextColor3=i==1 and Theme.Colors.Electric or Theme.Colors.White end
		end
		setInfo(nil)
		local coords={Vector2.new(.50,.86),Vector2.new(.18,.68),Vector2.new(.38,.68),Vector2.new(.62,.68),Vector2.new(.82,.68),Vector2.new(.32,.47),Vector2.new(.50,.55),Vector2.new(.68,.47),Vector2.new(.18,.22),Vector2.new(.50,.16),Vector2.new(.82,.22)}
		local cards={}
		local cardEntries:any={}
		local function makeSquadCard(parent:Instance,entry:any,pos:UDim2,size:UDim2,kind:string)
			local card=addPlayerMini(parent,entry,pos,size,setInfo,kind~="Lineup");card.ZIndex=134;table.insert(cards,card)
			cardEntries[card]=entry
			card:SetAttribute("VTRKind",kind)
			card:SetAttribute("VTRBenchIndex",tonumber(entry.BenchIndex)or 0)
			for _,descendant in card:GetDescendants()do if descendant:IsA("GuiObject")then descendant.ZIndex=135 end end
			local startPos=pos;local dragging=false;local dragOffset=Vector2.zero
			card.InputBegan:Connect(function(input)
				if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true;startPos=card.Position;local mouse=UserInputService:GetMouseLocation();local abs=card.AbsolutePosition;dragOffset=Vector2.new(mouse.X-abs.X,mouse.Y-abs.Y);setInfo(entry);card.ZIndex=150 end
			end)
			card.InputChanged:Connect(function(input)
				if dragging and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then local currentParent=card.Parent::GuiObject;local mouse=UserInputService:GetMouseLocation();local rel=Vector2.new(mouse.X-dragOffset.X-currentParent.AbsolutePosition.X,mouse.Y-dragOffset.Y-currentParent.AbsolutePosition.Y);card.Position=UDim2.fromOffset(rel.X,rel.Y)end
			end)
			card.InputEnded:Connect(function(input)
				if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
					dragging=false;card.ZIndex=134
					local best=nil;local bestDist=55;local center=card.AbsolutePosition+card.AbsoluteSize/2
					for _,other in cards do if other~=card then local d=(other.AbsolutePosition+other.AbsoluteSize/2-center).Magnitude;if d<bestDist then best=other;bestDist=d end end end
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
						local sourceParent=card.Parent;local sourcePos=startPos;local targetParent=best.Parent;local targetPos=best.Position
						card.Parent=targetParent;card.Position=targetPos
						best.Parent=sourceParent;best.Position=sourcePos
					else card.Position=startPos end
				end
			end)
			return card
		end
		local lineup=lineups[controlledSide] or lineups.Home or{}
		for i=1,11 do local entry=lineup[i]or{Name="EMPTY",Position="--",Overall=0,Number=0};local c=coords[i];local card=makeSquadCard(pitch,entry,UDim2.new(c.X,-45,c.Y,-34),UDim2.fromOffset(90,68),"Lineup");card.Name="TMCard_"..tostring(entry.Model or i)end
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
end

function Controller:ClearPause()
	if self.TeamManagementPage then
		self.TeamManagementPage:Destroy()
		self.TeamManagementPage = nil
	end
	if self.PauseOverlay then
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

function Controller:ShowResult(payload: any, onReturn: () -> ())
	self:ClearPause()
	local overlay = Instance.new("Frame")
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.05
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 40
	overlay.Active = true
	overlay.Selectable = false
	overlay.Parent = self.Gui
	local outcome = payload.Home > payload.Away and "VICTORY" or payload.Home < payload.Away and "DEFEAT" or "DRAW"
	local title = label(overlay, outcome, UDim2.new(0.2, 0, 0.08, 0), UDim2.new(0.6, 0, 0, 55), 34)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Theme.Colors.Electric
	local result = label(overlay, self.Home .. "   " .. payload.Home .. " - " .. payload.Away .. "   " .. self.Away, UDim2.new(0.15, 0, 0.18, 0), UDim2.new(0.7, 0, 0, 52), 23)
	result.TextXAlignment = Enum.TextXAlignment.Center
	local stats = payload.Stats or {}
	local home = stats.Home or {}
	local away = stats.Away or {}
	local tabs=Instance.new("Frame");tabs.Name="ResultTabs";tabs.BackgroundTransparency=1;tabs.Position=UDim2.new(.5,-210,.285,0);tabs.Size=UDim2.fromOffset(420,38);tabs.ZIndex=180;tabs.Parent=overlay;local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,10);tabLayout.Parent=tabs
	local content=panel(overlay,UDim2.new(.10,0,.345,0),UDim2.new(.80,0,.46,0));content.ZIndex=50;content.BackgroundTransparency=.11
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
		local y=56+(index-1)*30
		local row=Instance.new("Frame");row.BackgroundColor3=index%2==0 and Theme.Colors.Gunmetal or Theme.Colors.Black;row.BackgroundTransparency=index%2==0 and .62 or .82;row.BorderSizePixel=0;row.Position=UDim2.fromOffset(0,y);row.Size=UDim2.new(1,-8,0,28);row.ZIndex=53;row.Parent=parent;corner(row,6)
		local format=formatter or numberText
		local left=label(row,format(homeValue),UDim2.new(.10,0,0,6),UDim2.new(.18,0,0,16),10);left.TextXAlignment=Enum.TextXAlignment.Center;left.TextColor3=Theme.Colors.White
		local middle=label(row,name,UDim2.new(.33,0,0,6),UDim2.new(.34,0,0,16),9);middle.TextXAlignment=Enum.TextXAlignment.Center;middle.TextColor3=Theme.Colors.Silver
		local right=label(row,format(awayValue),UDim2.new(.72,0,0,6),UDim2.new(.18,0,0,16),10);right.TextXAlignment=Enum.TextXAlignment.Center;right.TextColor3=Theme.Colors.White
	end
	local teamStats=Instance.new("ScrollingFrame");teamStats.BackgroundTransparency=1;teamStats.BorderSizePixel=0;teamStats.Position=UDim2.fromOffset(26,18);teamStats.Size=UDim2.new(1,-52,1,-34);teamStats.AutomaticCanvasSize=Enum.AutomaticSize.Y;teamStats.CanvasSize=UDim2.new();teamStats.ScrollBarThickness=3;teamStats.ScrollBarImageColor3=Theme.Colors.Electric;teamStats.ZIndex=52;teamStats.Parent=content
	local header=Instance.new("Frame");header.BackgroundTransparency=1;header.Position=UDim2.fromOffset(0,0);header.Size=UDim2.new(1,-8,0,44);header.ZIndex=53;header.Parent=teamStats
	local homeHeader=label(header,self.HomeCode,UDim2.new(.09,0,0,4),UDim2.new(.20,0,0,28),15);homeHeader.TextXAlignment=Enum.TextXAlignment.Center;homeHeader.BackgroundColor3=Theme.Colors.Electric;homeHeader.BackgroundTransparency=.06;homeHeader.TextColor3=Theme.Colors.Black;homeHeader.ZIndex=54;corner(homeHeader,14)
	local titleHeader=label(header,"TEAM STATS",UDim2.new(.35,0,0,7),UDim2.new(.30,0,0,22),13);titleHeader.TextXAlignment=Enum.TextXAlignment.Center;titleHeader.TextColor3=Theme.Colors.Electric
	local awayHeader=label(header,self.AwayCode,UDim2.new(.71,0,0,4),UDim2.new(.20,0,0,28),15);awayHeader.TextXAlignment=Enum.TextXAlignment.Center;awayHeader.BackgroundColor3=Color3.fromHex("24C6B8");awayHeader.BackgroundTransparency=.06;awayHeader.TextColor3=Theme.Colors.Black;awayHeader.ZIndex=54;corner(awayHeader,14)
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
		local sep=Instance.new("Frame");sep.Position=UDim2.fromOffset(0,y);sep.Size=UDim2.fromOffset(960,34);sep.BackgroundColor3=team=="Home"and Theme.Colors.Electric or Color3.fromHex("24C6B8");sep.BackgroundTransparency=.08;sep.BorderSizePixel=0;sep.ZIndex=53;sep.Parent=ratings;corner(sep,6)
		local badge=label(sep,team=="Home"and self.HomeCode or self.AwayCode,UDim2.fromOffset(10,6),UDim2.fromOffset(46,20),10);badge.TextXAlignment=Enum.TextXAlignment.Center;badge.TextColor3=Theme.Colors.Black
		local titleLabel=label(sep,title,UDim2.fromOffset(66,6),UDim2.fromOffset(250,20),11);titleLabel.TextColor3=Theme.Colors.Black
		for _,c in columns do if c[1]~="TEAM"then local h=label(sep,c[1],UDim2.fromOffset(c[2],7),UDim2.fromOffset(c[3],18),8);h.TextXAlignment=Enum.TextXAlignment.Center;h.TextColor3=Theme.Colors.Black end end
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
		local row=Instance.new("Frame");row.Position=UDim2.fromOffset(0,y);row.Size=UDim2.fromOffset(960,30);row.BackgroundColor3=Theme.Colors.Black;row.BackgroundTransparency=.38;row.BorderSizePixel=0;row.ZIndex=53;row.Parent=ratings;corner(row,5)
		local motm=stats.MOTM and stats.MOTM.playerId==entry.playerId
		for i,c in columns do local cell=label(row,(motm and i==3 and"★ "or"")..values[i],UDim2.fromOffset(c[2],7),UDim2.fromOffset(c[3],16),i==3 and 8 or 7);cell.TextXAlignment=i==3 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center;cell.TextTruncate=Enum.TextTruncate.AtEnd;cell.TextColor3=motm and Theme.Colors.Electric or entry.Team=="Home"and Theme.Colors.White or Theme.Colors.Silver end
	end
	local y=0
	for _,team in{"Home","Away"}do
		headerRow(y,team=="Home"and"HOME TEAM"or"AWAY TEAM",team);y+=40
		for _,entry in stats.PlayerRatings or{}do if entry.Team==team then playerRow(entry,y);y+=34 end end
		y+=16
	end
	ratings.CanvasSize=UDim2.fromOffset(980,math.max(520,y+20))
	local teamButton=actionButton(tabs,"TEAM STATS",1,function()teamStats.Visible=true;ratings.Visible=false end);teamButton.Size=UDim2.fromOffset(205,38);teamButton.ZIndex=182
	local ratingButton=actionButton(tabs,"MATCH RATINGS",2,function()teamStats.Visible=false;ratings.Visible=true end);ratingButton.Size=UDim2.fromOffset(205,38);ratingButton.ZIndex=182
	for _,tab in tabs:GetDescendants()do if tab:IsA("GuiObject")then tab.ZIndex=182 end end
	if payload.Reward then local reward=panel(overlay,UDim2.new(.5,-150,.79,0),UDim2.fromOffset(300,48));reward.ZIndex=43;local rewardScale=Instance.new("UIScale");rewardScale.Scale=.4;rewardScale.Parent=reward;local rewardText=label(reward,"★  "..string.upper(payload.Reward.Title).."   +"..payload.Reward.Coins.." COINS   +"..payload.Reward.XP.." XP",UDim2.fromOffset(8,7),UDim2.new(1,-16,1,-14),9);rewardText.TextColor3=Theme.Colors.Electric;rewardText.TextXAlignment=Enum.TextXAlignment.Center;TweenService:Create(rewardScale,TweenInfo.new(.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()end
	local button = actionButton(overlay, "RETURN TO MENU", 1, function()
		MatchSetupService:ReturnToMenu()
		onReturn()
	end)
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.fromScale(0.5, 0.84)
	button.Size = UDim2.fromOffset(230, 48)
	button.ZIndex = 42
end

function Controller:Destroy()
	if self.Gui then
		self.Gui:Destroy()
	end
end

return Controller
