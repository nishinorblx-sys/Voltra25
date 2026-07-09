--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Overlay = {}

local ELECTRIC = Theme.Colors.Electric
local WHITE = Theme.Colors.White
local BLACK = Color3.fromRGB(2, 4, 5)
local PANEL = Color3.fromRGB(5, 8, 9)
local RAISED = Color3.fromRGB(17, 23, 18)
local CYAN = Color3.fromRGB(42, 222, 255)
local AMBER = Color3.fromRGB(255, 204, 64)

local function corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, keys: {ColorSequenceKeypoint}, rotation: number): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation
	g.Parent = parent
	return g
end

local function text(parent: Instance, value: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font, z: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Text = value
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = font
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.ZIndex = z or 70
	label.Parent = parent
	return label
end

local function fmt(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
end

local function withCommas(value: any): string
	local textValue = tostring(math.floor(tonumber(value) or 0))
	repeat
		local nextValue, count = textValue:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		textValue = nextValue
	until count == 0
	return textValue
end

local function rewardColor(reward: any): Color3
	local id = string.lower(tostring(reward.ItemId or reward.Label or ""))
	if reward.Type == "Coins" then return AMBER end
	if reward.Type == "Bolts" or reward.Type == "VoltraPoints" then return CYAN end
	if string.find(id, "voltra") then return Color3.fromRGB(34, 255, 142) end
	if string.find(id, "elite") then return Color3.fromRGB(189, 86, 255) end
	if string.find(id, "rare") then return Color3.fromRGB(38, 185, 255) end
	if string.find(id, "gold") then return Color3.fromRGB(255, 214, 73) end
	if string.find(id, "silver") then return Color3.fromRGB(214, 230, 237) end
	if string.find(id, "bronze") then return Color3.fromRGB(215, 134, 77) end
	return ELECTRIC
end

local function rewardGlyph(reward: any): string
	if reward.Type == "Coins" then return "C" end
	if reward.Type == "Bolts" then return "B" end
	if reward.Type == "VoltraPoints" then return "VP" end
	if reward.Type == "RandomPlayer" then return "OVR" end
	if reward.Type == "Celebration" then return "FX" end
	return "PACK"
end

local function rewardAmount(reward: any): string
	if reward.Type == "Coins" or reward.Type == "Bolts" or reward.Type == "VoltraPoints" then
		return withCommas(reward.Amount)
	end
	return string.upper(tostring(reward.Short or reward.Label or "PACK"))
end

local function todayReward(payload: any): any
	for _, reward in ipairs(payload.Rewards or {}) do
		if reward.Today == true then return reward end
	end
	return (payload.Rewards or {})[tonumber(payload.Day) or 1]
end

local function makeLine(parent: Instance, pos: UDim2, size: UDim2, color: Color3, transparency: number, rotation: number?)
	local line = Instance.new("Frame")
	line.BackgroundColor3 = color
	line.BackgroundTransparency = transparency
	line.BorderSizePixel = 0
	line.Position = pos
	line.Rotation = rotation or 0
	line.Size = size
	line.ZIndex = 61
	line.Parent = parent
	return line
end

local function rewardTile(parent: Instance, reward: any, index: number): Frame
	local claimed = reward.Claimed == true
	local today = reward.Today == true
	local color = rewardColor(reward)

	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = claimed and Color3.fromRGB(18, 24, 19) or Color3.fromRGB(24, 29, 24)
	tile.BorderSizePixel = 0
	tile.LayoutOrder = index
	tile.Size = UDim2.fromOffset(today and 148 or 134, today and 156 or 144)
	tile.ZIndex = 72
	tile.Parent = parent
	corner(tile, 7)
	local tileStroke = stroke(tile, today and ELECTRIC or color, today and 2.4 or 1.2, today and 0 or 0.42)

	gradient(tile, {
		ColorSequenceKeypoint.new(0, claimed and Color3.fromRGB(20, 27, 20) or Color3.fromRGB(34, 40, 32)),
		ColorSequenceKeypoint.new(0.58, Color3.fromRGB(12, 16, 14)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 4, 5)),
	}, 90)

	local top = Instance.new("Frame")
	top.BackgroundColor3 = today and ELECTRIC or color
	top.BackgroundTransparency = claimed and 0.45 or 0
	top.BorderSizePixel = 0
	top.Size = UDim2.new(1, 0, 0, 4)
	top.ZIndex = 73
	top.Parent = tile

	local day = text(tile, string.format("%02d", index), UDim2.fromOffset(11, 10), UDim2.fromOffset(48, 24), 20, today and ELECTRIC or WHITE, Theme.Fonts.Display, 74)
	day.TextWrapped = false
	local status = text(tile, claimed and "CLAIMED" or today and "TODAY" or "LOCKED", UDim2.new(1, -68, 0, 11), UDim2.fromOffset(58, 16), 8, claimed and Color3.fromRGB(150, 170, 150) or color, Theme.Fonts.Strong, 74)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.TextWrapped = false

	local icon = Instance.new("Frame")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundColor3 = color
	icon.BackgroundTransparency = claimed and 0.42 or 0
	icon.BorderSizePixel = 0
	icon.Position = UDim2.fromScale(0.5, 0.48)
	icon.Size = UDim2.fromOffset(reward.Type == "Pack" and 66 or 56, reward.Type == "Pack" and 56 or 56)
	icon.ZIndex = 75
	icon.Parent = tile
	corner(icon, reward.Type == "Pack" and 8 or 100)
	stroke(icon, WHITE, 1, reward.Type == "Pack" and 0.7 or 0.9)
	local glyph = text(icon, rewardGlyph(reward), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), reward.Type == "Pack" and 13 or 26, BLACK, Theme.Fonts.Display, 76)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	glyph.TextWrapped = false

	local label = text(tile, string.upper(tostring(reward.Label or reward.Type or "REWARD")), UDim2.fromOffset(10, 96), UDim2.new(1, -20, 0, 18), 9, WHITE, Theme.Fonts.Strong, 75)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = false
	local amount = text(tile, rewardAmount(reward), UDim2.fromOffset(10, 116), UDim2.new(1, -20, 0, 22), 13, color, Theme.Fonts.Display, 75)
	amount.TextXAlignment = Enum.TextXAlignment.Center
	amount.TextWrapped = false

	if today then
		local pulse = tileStroke
		task.spawn(function()
			while tile.Parent do
				TweenService:Create(pulse, TweenInfo.new(0.72, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.34}):Play()
				task.wait(0.72)
				if not tile.Parent then break end
				TweenService:Create(pulse, TweenInfo.new(0.72, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0}):Play()
				task.wait(0.72)
			end
		end)
	end

	return tile
end

function Overlay.Show(payload: any, claim: () -> any)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRDailyLoginOverlay")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRDailyLoginOverlay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1005
	gui.Parent = playerGui

	local shade = Instance.new("TextButton")
	shade.BackgroundColor3 = BLACK
	shade.BackgroundTransparency = 0.1
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.AutoButtonColor = false
	shade.Modal = true
	shade.Selectable = false
	shade.Text = ""
	shade.ZIndex = 50
	shade.Parent = gui

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local designWidth = 1120
	local designHeight = 620
	local modalScale = math.clamp(math.min((viewport.X * 0.86) / designWidth, (viewport.Y * 0.82) / designHeight), 0.74, 1)

	local panel = Instance.new("CanvasGroup")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.GroupTransparency = 1
	panel.Position = UDim2.fromScale(0.5, 0.48)
	panel.Size = UDim2.fromOffset(designWidth, designHeight)
	panel.ZIndex = 60
	panel.Parent = shade
	corner(panel, 12)
	local outerStroke = stroke(panel, ELECTRIC, 1.6, 0.04)
	gradient(panel, {
		ColorSequenceKeypoint.new(0, Color3.fromRGB(3, 5, 6)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(9, 14, 12)),
		ColorSequenceKeypoint.new(0.72, Color3.fromRGB(10, 30, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(1, 7, 9)),
	}, 20)

	local scale = Instance.new("UIScale")
	scale.Scale = modalScale * 0.94
	scale.Parent = panel

	local accentBack = Instance.new("Frame")
	accentBack.BackgroundColor3 = Color3.fromRGB(11, 255, 83)
	accentBack.BackgroundTransparency = 0.9
	accentBack.BorderSizePixel = 0
	accentBack.Position = UDim2.new(0.64, 0, -0.16, 0)
	accentBack.Rotation = 16
	accentBack.Size = UDim2.fromOffset(150, 760)
	accentBack.ZIndex = 61
	accentBack.Parent = panel

	for i = 1, 9 do
		makeLine(panel, UDim2.new(0, -30 + i * 112, 0, 20 + (i % 3) * 34), UDim2.fromOffset(1, 590), i % 2 == 0 and ELECTRIC or CYAN, 0.9, -28)
	end
	for i = 1, 4 do
		makeLine(panel, UDim2.new(0, 28, 0, 326 + i * 30), UDim2.new(1, -56, 0, 1), ELECTRIC, 0.9, 0)
	end

	local scan = Instance.new("Frame")
	scan.BackgroundColor3 = ELECTRIC
	scan.BackgroundTransparency = 0.86
	scan.BorderSizePixel = 0
	scan.Position = UDim2.new(-0.2, 0, 0, 0)
	scan.Rotation = 14
	scan.Size = UDim2.fromOffset(72, 760)
	scan.ZIndex = 64
	scan.Parent = panel
	task.spawn(function()
		while scan.Parent do
			scan.Position = UDim2.new(-0.2, 0, -0.1, 0)
			TweenService:Create(scan, TweenInfo.new(2.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1.08, 0, -0.1, 0)}):Play()
			task.wait(3.4)
		end
	end)

	local kicker = text(panel, "VOLTRA DAILY DROP", UDim2.fromOffset(50, 36), UDim2.fromOffset(320, 22), 11, ELECTRIC, Theme.Fonts.Strong, 70)
	kicker.TextWrapped = false
	text(panel, "DAILY LOGIN", UDim2.fromOffset(48, 66), UDim2.fromOffset(500, 60), 43, WHITE, Theme.Fonts.Display, 70).TextWrapped = false
	text(panel, tostring(payload.WeekName or "Weekly Login"), UDim2.fromOffset(52, 126), UDim2.fromOffset(430, 22), 13, CYAN, Theme.Fonts.Strong, 70).TextWrapped = false
	text(panel, tostring(payload.Subtitle or "Claim your daily reward."), UDim2.fromOffset(52, 154), UDim2.fromOffset(520, 24), 11, Color3.fromRGB(215, 224, 216), Theme.Fonts.Body, 70)

	local timerBand = Instance.new("Frame")
	timerBand.BackgroundColor3 = Color3.fromRGB(3, 8, 9)
	timerBand.BackgroundTransparency = 0.08
	timerBand.BorderSizePixel = 0
	timerBand.Position = UDim2.fromOffset(50, 192)
	timerBand.Size = UDim2.fromOffset(430, 38)
	timerBand.ZIndex = 69
	timerBand.Parent = panel
	corner(timerBand, 6)
	stroke(timerBand, CYAN, 1, 0.55)
	local resetTargetUnix = os.time() + math.max(0, math.floor(tonumber(payload.SecondsUntilReset) or 0))
	local resetLabel = text(timerBand, "RESET  /  " .. fmt(math.max(0, resetTargetUnix - os.time())), UDim2.fromOffset(14, 0), UDim2.new(0.52, -14, 1, 0), 12, CYAN, Theme.Fonts.Display, 70)
	resetLabel.TextWrapped = false
	local remain = text(timerBand, "DAY " .. tostring(payload.Day or 1) .. " / " .. tostring(payload.TrackLength or #(payload.Rewards or {})), UDim2.new(0.53, 0, 0, 0), UDim2.new(0.47, -14, 1, 0), 11, WHITE, Theme.Fonts.Strong, 70)
	remain.TextXAlignment = Enum.TextXAlignment.Right
	remain.TextWrapped = false
	task.spawn(function()
		local lastShown = -1
		while gui.Parent and resetLabel.Parent do
			local remaining = math.max(0, resetTargetUnix - os.time())
			if remaining ~= lastShown then
				lastShown = remaining
				resetLabel.Text = remaining > 0 and ("RESET  /  " .. fmt(remaining)) or "RESET  /  READY"
			end
			task.wait(0.5)
		end
	end)

	local today = todayReward(payload) or {}
	local todayColor = rewardColor(today)
	local hero = Instance.new("Frame")
	hero.BackgroundColor3 = RAISED
	hero.BorderSizePixel = 0
	hero.Position = UDim2.new(1, -390, 0, 42)
	hero.Size = UDim2.fromOffset(340, 220)
	hero.ZIndex = 68
	hero.Parent = panel
	corner(hero, 10)
	stroke(hero, todayColor, 1.6, 0.05)
	gradient(hero, {
		ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 18, 14)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(5, 8, 8)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 44, 21)),
	}, -20)
	text(hero, "TODAY'S DROP", UDim2.fromOffset(18, 12), UDim2.new(1, -36, 0, 18), 9, ELECTRIC, Theme.Fonts.Strong, 72).TextWrapped = false
	text(hero, string.upper(tostring(today.Label or today.Type or "REWARD")), UDim2.fromOffset(18, 34), UDim2.new(1, -36, 0, 32), 22, WHITE, Theme.Fonts.Display, 72).TextWrapped = false
	text(hero, rewardAmount(today), UDim2.fromOffset(18, 68), UDim2.new(1, -36, 0, 34), 24, todayColor, Theme.Fonts.Display, 72).TextWrapped = false
	text(hero, payload.Claimable and "READY TO CLAIM" or "SECURED FOR TODAY", UDim2.fromOffset(18, 115), UDim2.new(1, -36, 0, 22), 11, payload.Claimable and ELECTRIC or Color3.fromRGB(166, 185, 164), Theme.Fonts.Strong, 72).TextWrapped = false

	local heroIcon = Instance.new("Frame")
	heroIcon.AnchorPoint = Vector2.new(1, 1)
	heroIcon.BackgroundColor3 = todayColor
	heroIcon.BorderSizePixel = 0
	heroIcon.Position = UDim2.new(1, -20, 1, -18)
	heroIcon.Size = UDim2.fromOffset(today.Type == "Pack" and 86 or 74, 74)
	heroIcon.ZIndex = 73
	heroIcon.Parent = hero
	corner(heroIcon, today.Type == "Pack" and 12 or 100)
	local heroGlyph = text(heroIcon, rewardGlyph(today), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), today.Type == "Pack" and 16 or 34, BLACK, Theme.Fonts.Display, 74)
	heroGlyph.TextXAlignment = Enum.TextXAlignment.Center
	heroGlyph.TextWrapped = false

	local rewardRow = Instance.new("ScrollingFrame")
	rewardRow.BackgroundColor3 = Color3.fromRGB(1, 4, 5)
	rewardRow.BackgroundTransparency = 0.18
	rewardRow.BorderSizePixel = 0
	rewardRow.Position = UDim2.fromOffset(50, 318)
	rewardRow.Size = UDim2.new(1, -100, 0, 178)
	rewardRow.CanvasSize = UDim2.fromOffset(0, 0)
	rewardRow.ScrollBarImageColor3 = ELECTRIC
	rewardRow.ScrollBarThickness = 5
	rewardRow.ScrollingDirection = Enum.ScrollingDirection.X
	rewardRow.VerticalScrollBarInset = Enum.ScrollBarInset.None
	rewardRow.ZIndex = 71
	rewardRow.Parent = panel
	corner(rewardRow, 10)
	stroke(rewardRow, ELECTRIC, 1, 0.74)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = rewardRow
	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingLeft = UDim.new(0, 14)
	rowPadding.PaddingRight = UDim.new(0, 18)
	rowPadding.Parent = rewardRow
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		rewardRow.CanvasSize = UDim2.fromOffset(math.max(rewardRow.AbsoluteSize.X + 1, layout.AbsoluteContentSize.X + 36), 0)
	end)

	local cards = {}
	for index, reward in ipairs(payload.Rewards or {}) do
		table.insert(cards, rewardTile(rewardRow, reward, index))
	end

	local claimButton = Instance.new("TextButton")
	claimButton.AutoButtonColor = false
	claimButton.BackgroundColor3 = payload.Claimable == true and ELECTRIC or Color3.fromRGB(54, 63, 54)
	claimButton.BorderSizePixel = 0
	claimButton.Position = UDim2.new(0.5, -200, 1, -72)
	claimButton.Size = UDim2.fromOffset(400, 42)
	claimButton.Text = payload.Claimable == true and "CLAIM DAILY DROP" or "CLAIMED TODAY"
	claimButton.TextColor3 = BLACK
	claimButton.TextSize = 15
	claimButton.Font = Theme.Fonts.Display
	claimButton.ZIndex = 80
	claimButton.Parent = panel
	corner(claimButton, 100)
	stroke(claimButton, WHITE, 1, 0.85)

	local close = Instance.new("TextButton")
	close.AutoButtonColor = false
	close.BackgroundColor3 = Color3.fromRGB(10, 14, 12)
	close.BackgroundTransparency = 0.1
	close.BorderSizePixel = 0
	close.Position = UDim2.new(1, -46, 0, 18)
	close.Size = UDim2.fromOffset(30, 30)
	close.Text = "X"
	close.TextColor3 = WHITE
	close.TextSize = 16
	close.Font = Theme.Fonts.Display
	close.ZIndex = 82
	close.Parent = panel
	corner(close, 100)
	stroke(close, WHITE, 1, 0.72)

	local closed = false
	local function destroy()
		if closed then return end
		closed = true
		TweenService:Create(scale, TweenInfo.new(0.16), {Scale = modalScale * 0.96}):Play()
		TweenService:Create(panel, TweenInfo.new(0.16), {GroupTransparency = 1, Position = UDim2.fromScale(0.5, 0.46)}):Play()
		TweenService:Create(shade, TweenInfo.new(0.16), {BackgroundTransparency = 1}):Play()
		task.delay(0.18, function() if gui.Parent then gui:Destroy() end end)
	end

	close.Activated:Connect(destroy)
	claimButton.Activated:Connect(function()
		if payload.Claimable ~= true then destroy(); return end
		claimButton.Text = "CLAIMING..."
		local result = claim()
		if type(result) == "table" and result.Success == true then
			payload = result.Data or payload
			claimButton.Text = "DROP SECURED"
			claimButton.BackgroundColor3 = Color3.fromRGB(72, 90, 68)
			TweenService:Create(heroIcon, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(96, 84)}):Play()
			task.delay(0.8, destroy)
		else
			claimButton.Text = "TRY AGAIN"
			task.delay(1, function()
				if claimButton.Parent then claimButton.Text = "CLAIM DAILY DROP" end
			end)
		end
	end)

	TweenService:Create(scale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = modalScale}):Play()
	TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5)}):Play()
	TweenService:Create(outerStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.32}):Play()

	for index, card in ipairs(cards) do
		local cardScale = Instance.new("UIScale")
		cardScale.Scale = 0.84
		cardScale.Parent = card
		card.BackgroundTransparency = 1
		task.delay(index * 0.045, function()
			if card.Parent then
				TweenService:Create(card, TweenInfo.new(0.18), {BackgroundTransparency = 0}):Play()
				TweenService:Create(cardScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
			end
		end)
	end
end

return Overlay
