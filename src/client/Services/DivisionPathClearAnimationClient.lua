local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local DivisionPathClearAnimationClient = {}

local started = false
local lastSeq = -1

local VOLTRA_GREEN = Color3.fromRGB(144, 255, 40)
local VOLTRA_CYAN = Color3.fromRGB(38, 232, 255)
local VOLTRA_BLUE = Color3.fromRGB(18, 84, 116)
local PANEL = Color3.fromRGB(5, 10, 15)
local PANEL_2 = Color3.fromRGB(10, 18, 24)
local WHITE = Color3.fromRGB(246, 250, 255)
local MUTED = Color3.fromRGB(168, 181, 188)

local function create(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius),
	}, parent)
end

local function stroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
	}, parent)
end

local function gradient(parent, color0, color1, rotation)
	return create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color0),
			ColorSequenceKeypoint.new(1, color1),
		}),
		Rotation = rotation or 0,
	}, parent)
end

local function makeText(parent, name, text, position, size, textSize, color, zIndex)
	local label = create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextColor3 = color,
		TextSize = textSize,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.6,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = zIndex or 10,
	}, parent)
	return label
end

local function makeChip(parent, text, color, width)
	local chip = create("Frame", {
		Name = text:gsub("%W", "") .. "Chip",
		BackgroundColor3 = Color3.fromRGB(8, 16, 20),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width or 158, 36),
		ZIndex = 16,
	}, parent)
	corner(chip, 10)
	stroke(chip, color, 1.4, 0.18)
	gradient(chip, Color3.fromRGB(12, 24, 26), Color3.fromRGB(4, 9, 13), 0)

	local label = makeText(chip, "Label", text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 13, WHITE, 17)
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.TextWrapped = false

	return chip, label
end

local function reveal(guiObject, delayTime, tweenTime)
	task.delay(delayTime or 0, function()
		if guiObject.Parent then
			TweenService:Create(guiObject, TweenInfo.new(tweenTime or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			}):Play()
		end
	end)
end

local function revealFrame(guiObject, delayTime, transparency)
	task.delay(delayTime or 0, function()
		if guiObject.Parent then
			TweenService:Create(guiObject, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = transparency or 0,
			}):Play()
		end
	end)
end

local function addMovingStripes(parent)
	local colors = { VOLTRA_GREEN, VOLTRA_CYAN, VOLTRA_BLUE }
	for index = 1, 15 do
		local startX = -0.28 + (index % 6) * 0.22
		local y = 0.08 + ((index * 37) % 82) / 100
		local stripe = create("Frame", {
			Name = "VoltraMotionStripe",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = colors[(index % #colors) + 1],
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(startX, y),
			Rotation = -18,
			Size = UDim2.new(0.46, 0, 0, 16 + (index % 4) * 7),
			ZIndex = 2,
		}, parent)
		gradient(stripe, Color3.fromRGB(4, 10, 14), colors[(index % #colors) + 1], 0)
		TweenService:Create(stripe, TweenInfo.new(2.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(startX + 0.23, y),
			BackgroundTransparency = 1,
		}):Play()
	end
end

local function electricBurst(parent)
	local palette = { VOLTRA_GREEN, VOLTRA_CYAN, WHITE }
	for i = 1, 58 do
		local color = palette[(i % #palette) + 1]
		local shard = create("Frame", {
			Name = "VoltShard",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = math.random(-42, 42),
			Size = UDim2.fromOffset(math.random(5, 15), math.random(34, 92)),
			ZIndex = 9,
		}, parent)
		corner(shard, 2)

		local angle = math.rad((i / 58) * 360 + math.random(-11, 11))
		local distance = math.random(300, 690)
		local target = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance)

		TweenService:Create(shard, TweenInfo.new(0.84, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
			Position = target,
			Rotation = shard.Rotation + math.random(220, 720),
			Size = UDim2.fromOffset(2, 12),
		}):Play()

		task.delay(0.9, function()
			if shard.Parent then
				shard:Destroy()
			end
		end)
	end
end

local function pulseStroke(uiStroke)
	task.spawn(function()
		for _ = 1, 4 do
			if not uiStroke.Parent then
				return
			end
			TweenService:Create(uiStroke, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0,
			}):Play()
			task.wait(0.14)
			if not uiStroke.Parent then
				return
			end
			TweenService:Create(uiStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0.36,
			}):Play()
			task.wait(0.18)
		end
	end)
end

function DivisionPathClearAnimationClient.Play()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("DivisionPathClearGui")
	if old then
		old:Destroy()
	end

	local wins = math.max(4, math.floor(tonumber(localPlayer:GetAttribute("VTRDivisionPathClearedWins")) or 4))
	local losses = math.max(0, math.floor(tonumber(localPlayer:GetAttribute("VTRDivisionPathClearedLosses")) or 0))
	local division = tonumber(localPlayer:GetAttribute("Division")) or 0
	local divisionText = division > 0 and ("NEW DIVISION " .. tostring(division)) or "ELITE DIVISION"

	local gui = create("ScreenGui", {
		Name = "DivisionPathClearGui",
		DisplayOrder = 20000,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
	}, playerGui)

	local shade = create("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, gui)
	gradient(shade, Color3.fromRGB(1, 4, 7), Color3.fromRGB(4, 19, 17), 25)

	addMovingStripes(shade)

	for i = 1, 8 do
		local line = create("Frame", {
			Name = "Scanline",
			BackgroundColor3 = i % 2 == 0 and VOLTRA_CYAN or VOLTRA_GREEN,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, i / 9),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 3,
		}, shade)
		TweenService:Create(line, TweenInfo.new(1.4 + i * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end

	local glow = create("Frame", {
		Name = "OuterNeonFrame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(9, 18, 23),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.76, 0, 0, 360),
		ZIndex = 8,
	}, shade)
	corner(glow, 30)
	local glowStroke = stroke(glow, VOLTRA_GREEN, 5, 0.2)
	create("UISizeConstraint", {
		MaxSize = Vector2.new(940, 390),
		MinSize = Vector2.new(640, 320),
	}, glow)

	local card = create("Frame", {
		Name = "VoltraClearCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -14, 1, -14),
		ZIndex = 10,
	}, glow)
	corner(card, 24)
	stroke(card, VOLTRA_CYAN, 1.2, 0.38)
	gradient(card, PANEL_2, Color3.fromRGB(4, 8, 12), 15)

	local scale = create("UIScale", {
		Scale = 0.78,
	}, glow)

	for i = 1, 7 do
		local slash = create("Frame", {
			Name = "CardSlash",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = i % 2 == 0 and VOLTRA_CYAN or VOLTRA_GREEN,
			BackgroundTransparency = 0.83,
			BorderSizePixel = 0,
			Position = UDim2.new(0.66 + i * 0.065, 0, 0.5, 0),
			Rotation = 18,
			Size = UDim2.fromOffset(46, 520),
			ZIndex = 11,
		}, card)
		TweenService:Create(slash, TweenInfo.new(1.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.95,
			Position = UDim2.new(0.7 + i * 0.065, 0, 0.5, 0),
		}):Play()
	end

	local topRail = create("Frame", {
		Name = "TopChargeRail",
		BackgroundColor3 = VOLTRA_GREEN,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(34, 24),
		Size = UDim2.new(1, -68, 0, 3),
		ZIndex = 15,
	}, card)
	gradient(topRail, VOLTRA_GREEN, VOLTRA_CYAN, 0)
	revealFrame(topRail, 0.1, 0.06)

	local kicker = makeText(card, "Kicker", "VOLTRA RANKED SYSTEM", UDim2.fromOffset(42, 28), UDim2.new(1, -84, 0, 24), 13, VOLTRA_CYAN, 15)
	kicker.Font = Enum.Font.GothamBold
	kicker.TextWrapped = false

	local title = makeText(card, "Title", "DIVISION PATH CLEARED", UDim2.fromOffset(34, 58), UDim2.new(1, -68, 0, 58), 43, VOLTRA_GREEN, 15)
	title.TextStrokeTransparency = 0.3
	gradient(title, VOLTRA_GREEN, VOLTRA_CYAN, 0)

	local sub = makeText(card, "Sub", tostring(wins) .. " wins locked - division promoted", UDim2.fromOffset(56, 118), UDim2.new(1, -112, 0, 34), 22, WHITE, 15)
	sub.Font = Enum.Font.GothamBold
	sub.TextStrokeTransparency = 0.72

	local divisionLabel = makeText(card, "Division", divisionText, UDim2.fromOffset(38, 154), UDim2.new(1, -76, 0, 54), 36, VOLTRA_CYAN, 15)
	divisionLabel.TextStrokeTransparency = 0.28

	local ready = makeText(card, "ClaimReady", "PATH REWARDS ONLINE - CLAIM PACKS NEXT", UDim2.fromOffset(46, 204), UDim2.new(1, -92, 0, 24), 15, MUTED, 15)
	ready.Font = Enum.Font.GothamBold
	ready.TextStrokeTransparency = 1
	ready.TextWrapped = false

	local row = create("Frame", {
		Name = "StatusChips",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 46, 1, -68),
		Size = UDim2.new(1, -92, 0, 38),
		ZIndex = 16,
	}, card)
	local layout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)
	layout.Parent = row

	local _, winsLabel = makeChip(row, tostring(wins) .. " WINS", VOLTRA_GREEN, 126)
	local _, lossesLabel = makeChip(row, tostring(losses) .. " LOSSES", Color3.fromRGB(255, 79, 97), 132)
	local _, promotedLabel = makeChip(row, "PROMOTED", VOLTRA_CYAN, 142)
	local _, claimLabel = makeChip(row, "CLAIM READY", WHITE, 150)

	local railTrack = create("Frame", {
		Name = "ChargeTrack",
		BackgroundColor3 = Color3.fromRGB(18, 30, 28),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(0, 46, 1, -18),
		Size = UDim2.new(1, -92, 0, 4),
		ZIndex = 16,
	}, card)
	corner(railTrack, 2)
	local railFill = create("Frame", {
		Name = "ChargeFill",
		BackgroundColor3 = VOLTRA_GREEN,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 17,
	}, railTrack)
	gradient(railFill, VOLTRA_GREEN, VOLTRA_CYAN, 0)

	TweenService:Create(shade, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.14,
	}):Play()
	TweenService:Create(glow, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.56,
	}):Play()
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	pulseStroke(glowStroke)
	electricBurst(gui)

	reveal(kicker, 0.05, 0.14)
	reveal(title, 0.12, 0.18)
	reveal(sub, 0.22, 0.16)
	reveal(divisionLabel, 0.32, 0.18)
	reveal(ready, 0.42, 0.16)
	reveal(winsLabel, 0.5, 0.12)
	reveal(lossesLabel, 0.54, 0.12)
	reveal(promotedLabel, 0.58, 0.12)
	reveal(claimLabel, 0.62, 0.12)

	TweenService:Create(railFill, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, 1),
	}):Play()

	task.wait(2.85)

	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.92,
	}):Play()
	TweenService:Create(glow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(shade, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()

	task.wait(0.22)
	if gui.Parent then
		gui:Destroy()
	end
end

local function check()
	local seq = tonumber(localPlayer:GetAttribute("VTRDivisionPathClearSeq")) or 0
	local promoted = localPlayer:GetAttribute("VTRDivisionPathPromoted") == true

	if promoted and seq > lastSeq then
		lastSeq = seq
		DivisionPathClearAnimationClient.Play()
	elseif seq > lastSeq then
		lastSeq = seq
	end
end

function DivisionPathClearAnimationClient.Start()
	if started then
		return
	end

	started = true
	lastSeq = tonumber(localPlayer:GetAttribute("VTRDivisionPathClearSeq")) or 0

	localPlayer:GetAttributeChangedSignal("VTRDivisionPathClearSeq"):Connect(check)
	task.defer(check)
end

DivisionPathClearAnimationClient.Start()

return DivisionPathClearAnimationClient
