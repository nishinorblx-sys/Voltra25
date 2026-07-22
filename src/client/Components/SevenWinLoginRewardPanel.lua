local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)
local localPlayer = Players.LocalPlayer

local SevenWinLoginRewardPanel = {}

local GREEN = Color3.fromRGB(145, 255, 42)
local CYAN = Color3.fromRGB(40, 231, 255)
local WHITE = Color3.fromRGB(247, 250, 255)
local MUTED = Color3.fromRGB(164, 176, 184)
local PANEL = Color3.fromRGB(5, 9, 15)
local CARD_DARK = Color3.fromRGB(8, 13, 18)
local ROULETTE_POOL = {
	"BRONZE PACK",
	"SILVER PACK",
	"GOLD PACK",
	"RARE PACK",
	"ELITE PACK",
	"LEGENDARY PACK",
	"MYTHIC PACK",
}

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

local function textLabel(parent, name, text, position, size, textSize, color, font, zIndex)
	return create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Font = font or Enum.Font.GothamBlack,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = color or WHITE,
		TextSize = textSize,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = zIndex or 12,
	}, parent)
end

local function cleanName(value)
	return tostring(value or "PACK"):gsub("_", " "):upper()
end

local function definitionByName(name)
	local target = string.lower(tostring(name or ""))
	for id, definition in Catalog.Packs do
		if string.lower(tostring(definition.Name or "")) == target then
			return id, definition
		end
	end
	return nil, nil
end

local function normalizeReward(reward)
	local id
	local name
	local instanceId

	if typeof(reward) == "table" then
		id = reward.PackId or reward.packId or reward.Id or reward.id or reward.Pack
		name = reward.Name or reward.name or reward.PackName or reward.packName
		instanceId = reward.PackInstanceId or reward.packInstanceId
	else
		id = reward
	end

	local definition = type(id) == "string" and Catalog.Packs[id] or nil
	if not definition and name then
		local foundId, foundDefinition = definitionByName(name)
		id = foundId or id
		definition = foundDefinition
	end

	name = name or (definition and definition.Name) or id or "PACK"

	return {
		Id = tostring(id or name),
		Name = tostring(name),
		InstanceId = instanceId,
	}
end

local function compactRewards(rewards)
	local out = {}
	for _, reward in ipairs(rewards or {}) do
		table.insert(out, normalizeReward(reward))
	end
	return out
end

local function packDefinition(item)
	local definition = Catalog.Packs[item.Id]
	if definition then
		return definition
	end

	local foundId, foundDefinition = definitionByName(item.Name)
	if foundDefinition then
		item.Id = foundId
		return foundDefinition
	end

	return nil
end

local function packAccent(item, definition)
	local id = string.lower(tostring(item.Id or item.Name or ""))
	if string.find(id, "mythic") then
		return Color3.fromRGB(255, 255, 255), Color3.fromRGB(185, 72, 255), Color3.fromRGB(20, 12, 29)
	elseif string.find(id, "legendary") then
		return Color3.fromRGB(255, 95, 55), Color3.fromRGB(255, 206, 82), Color3.fromRGB(28, 12, 8)
	elseif string.find(id, "elite") then
		return Color3.fromRGB(183, 74, 255), Color3.fromRGB(44, 226, 255), Color3.fromRGB(18, 9, 30)
	elseif string.find(id, "rare") then
		return Color3.fromRGB(33, 178, 255), Color3.fromRGB(145, 255, 42), Color3.fromRGB(7, 18, 30)
	elseif string.find(id, "gold") then
		return Color3.fromRGB(255, 210, 75), Color3.fromRGB(255, 245, 188), Color3.fromRGB(27, 20, 5)
	elseif string.find(id, "silver") then
		return Color3.fromRGB(218, 228, 236), Color3.fromRGB(95, 224, 255), Color3.fromRGB(17, 22, 25)
	elseif string.find(id, "bronze") then
		return Color3.fromRGB(205, 132, 78), Color3.fromRGB(255, 212, 135), Color3.fromRGB(28, 16, 9)
	elseif definition and definition.GuaranteedMinRarity == "Rare" then
		return Color3.fromRGB(33, 178, 255), GREEN, Color3.fromRGB(7, 18, 30)
	end

	return GREEN, CYAN, CARD_DARK
end

local function setZIndexRecursive(root, amount)
	if root:IsA("GuiObject") then
		root.ZIndex += amount
	end
	for _, child in root:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex += amount
		end
	end
end

local function lowerText(obj)
	local values = { obj.Name }
	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		table.insert(values, obj.Text)
	end
	for _, value in values do
		local text = string.lower(tostring(value or ""))
		if text ~= "" then
			return text
		end
	end
	return ""
end

local function findInventoryTarget()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local best
	for _, obj in playerGui:GetDescendants() do
		if obj:IsA("GuiObject") then
			local text = lowerText(obj)
			if string.find(text, "inventory") or string.find(text, "packs") then
				if obj.Visible and obj.AbsoluteSize.X > 8 and obj.AbsoluteSize.Y > 8 then
					best = obj
					if obj:IsA("GuiButton") then
						return obj
					end
				end
			end
		end
	end

	return best
end

local function packCard(parent, item, index)
	local definition = packDefinition(item)
	local accent, secondary, base = packAccent(item, definition)
	local cardCount = definition and tonumber(definition.CardCount) or nil
	local guarantee = definition and definition.GuaranteedMinRarity or "Reward"
	local displayName = cleanName(item.Name)

	local card = create("CanvasGroup", {
		Name = "PackCard_" .. tostring(index),
		BackgroundColor3 = base,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = index,
		Size = UDim2.fromOffset(136, 194),
		ZIndex = 14,
	}, parent)
	corner(card, 16)
	stroke(card, accent, 2.2, 0.02)
	gradient(card, base, Color3.fromRGB(4, 8, 13), 18)
	create("UIScale", {
		Name = "CardScale",
		Scale = 1,
	}, card)

	local leftTrim = create("Frame", {
		Name = "LeftTrim",
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 5, 1, 0),
		ZIndex = 15,
	}, card)
	gradient(leftTrim, accent, secondary, 90)

	local foil = create("Frame", {
		Name = "Foil",
		BackgroundColor3 = secondary,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(84, -34),
		Rotation = -18,
		Size = UDim2.fromOffset(42, 260),
		ZIndex = 15,
	}, card)
	gradient(foil, secondary, accent, 90)

	create("Frame", {
		Name = "TopRail",
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 5),
		ZIndex = 18,
	}, card)

	local count = textLabel(card, "CardCount", cardCount and tostring(cardCount) or "VTR", UDim2.fromOffset(12, 12), UDim2.fromOffset(56, 30), 24, WHITE, nil, 24)
	count.TextWrapped = false
	count.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	count.TextStrokeTransparency = 0.45

	local packType = textLabel(card, "Type", cardCount and "CARDS" or "PACK", UDim2.fromOffset(13, 41), UDim2.fromOffset(68, 17), 10, WHITE, Enum.Font.GothamBold, 24)
	packType.TextWrapped = false

	local mark = textLabel(card, "Mark", "V", UDim2.fromOffset(0, 54), UDim2.new(1, 0, 0, 72), 54, accent, nil, 22)
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	mark.TextStrokeTransparency = 0.5

	local badge = create("Frame", {
		Name = "Badge",
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 126),
		Size = UDim2.new(1, -24, 0, 24),
		ZIndex = 24,
	}, card)
	corner(badge, 7)
	local badgeText = textLabel(badge, "Label", tostring(guarantee):upper(), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, Color3.fromRGB(3, 8, 10), Enum.Font.GothamBlack, 25)
	badgeText.TextXAlignment = Enum.TextXAlignment.Center
	badgeText.TextWrapped = false

	local namePlate = create("Frame", {
		Name = "NamePlate",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 1, -40),
		Size = UDim2.new(1, -16, 0, 30),
		ZIndex = 24,
	}, card)
	corner(namePlate, 8)
	stroke(namePlate, accent, 1, 0.48)

	local name = textLabel(namePlate, "Name", displayName, UDim2.fromOffset(7, 0), UDim2.new(1, -14, 1, 0), 13, WHITE, Enum.Font.GothamBlack, 25)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextScaled = true
	name.TextWrapped = true
	create("UITextSizeConstraint", {
		MaxTextSize = 13,
		MinTextSize = 8,
	}, name)

	local cover = create("CanvasGroup", {
		Name = "RouletteCover",
		BackgroundColor3 = Color3.fromRGB(2, 6, 9),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 32,
	}, card)
	corner(cover, 16)
	stroke(cover, accent, 1.8, 0.08)
	gradient(cover, Color3.fromRGB(3, 8, 12), Color3.fromRGB(10, 18, 23), 0)

	local scan = create("Frame", {
		Name = "Scan",
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-10, 78),
		Size = UDim2.new(1, 20, 0, 34),
		ZIndex = 33,
	}, cover)
	corner(scan, 8)
	gradient(scan, accent, secondary, 0)

	local rolling = textLabel(cover, "RollingName", "LOCKED", UDim2.fromOffset(10, 36), UDim2.new(1, -20, 0, 86), 18, WHITE, Enum.Font.GothamBlack, 34)
	rolling.TextXAlignment = Enum.TextXAlignment.Center
	rolling.TextScaled = true
	create("UITextSizeConstraint", {
		MaxTextSize = 18,
		MinTextSize = 9,
	}, rolling)

	local rollingSub = textLabel(cover, "RollingSub", "REWARD PACK", UDim2.new(0, 10, 1, -44), UDim2.new(1, -20, 0, 24), 10, accent, Enum.Font.GothamBold, 34)
	rollingSub.TextXAlignment = Enum.TextXAlignment.Center
	rollingSub.TextWrapped = false

	card:SetAttribute("DisplayName", displayName)
	card.GroupTransparency = 1

	return card
end

local function revealCards(cards, status, button)
	button.Visible = false
	status.Text = "ROLLING REWARD PACKS"

	for index, card in ipairs(cards) do
		if not card.Parent then
			continue
		end

		local cover = card:FindFirstChild("RouletteCover")
		local rolling = cover and cover:FindFirstChild("RollingName")
		local scan = cover and cover:FindFirstChild("Scan")
		local displayName = tostring(card:GetAttribute("DisplayName") or "PACK")
		status.Text = "ROLLING PACK " .. tostring(index) .. " / " .. tostring(#cards)

		card.Rotation = -2
		TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			GroupTransparency = 0,
			Rotation = 0,
		}):Play()

		if rolling and rolling:IsA("TextLabel") then
			for spin = 1, 10 do
				rolling.Text = spin == 10 and displayName or ROULETTE_POOL[((spin + index * 2) % #ROULETTE_POOL) + 1]
				if scan and scan:IsA("GuiObject") then
					scan.Position = UDim2.fromOffset(-10, 44 + (spin % 4) * 24)
					TweenService:Create(scan, TweenInfo.new(0.055, Enum.EasingStyle.Linear), {
						Position = UDim2.fromOffset(-10, 54 + (spin % 4) * 24),
					}):Play()
				end
				task.wait(math.min(0.035 + spin * 0.012, 0.11))
			end
		end

		if cover and cover:IsA("CanvasGroup") then
			TweenService:Create(cover, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				GroupTransparency = 1,
			}):Play()
			task.delay(0.2, function()
				if cover.Parent then
					cover:Destroy()
				end
			end)
		end

		local cardScale = card:FindFirstChild("CardScale")
		if cardScale and cardScale:IsA("UIScale") then
			TweenService:Create(cardScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1.06,
			}):Play()
		end
		task.wait(0.1)
		if cardScale and cardScale.Parent then
			TweenService:Create(cardScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		task.wait(0.14)
	end

	status.Text = "UNOPENED PACKS READY FOR INVENTORY"
	button.Visible = true
	button.Active = true
end


local vtrDailyRewardLastArgs=nil
local function flyCardsToInventory(shade, cards)
	vtrDailyRewardLastArgs=table.pack(shade,cards)
	local target = findInventoryTarget()
	local shadeOrigin = shade.AbsolutePosition
	local endCenter = Vector2.new(shade.AbsoluteSize.X - 78, shade.AbsoluteSize.Y - 78)
	if target then
		endCenter = target.AbsolutePosition + target.AbsoluteSize * 0.5 - shadeOrigin
	end

	for index, card in ipairs(cards) do
		if card.Parent then
			local center = card.AbsolutePosition + card.AbsoluteSize * 0.5 - shadeOrigin
			local clone = card:Clone()
			clone.AnchorPoint = Vector2.new(0.5, 0.5)
			clone.LayoutOrder = 0
			clone.Position = UDim2.fromOffset(center.X, center.Y)
			clone.Size = UDim2.fromOffset(card.AbsoluteSize.X, card.AbsoluteSize.Y)
			clone.Parent = shade
			setZIndexRecursive(clone, 70)
			local scale = create("UIScale", {
				Scale = 1,
			}, clone)
			card.Visible = false

			task.delay((index - 1) * 0.035, function()
				if not clone.Parent then
					return
				end

				TweenService:Create(clone, TweenInfo.new(0.52, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
					GroupTransparency = 0.18,
					Position = UDim2.fromOffset(endCenter.X, endCenter.Y),
					Rotation = 8 + index * 2,
				}):Play()
				TweenService:Create(scale, TweenInfo.new(0.52, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
					Scale = 0.32,
				}):Play()
				task.delay(0.48, function()
					if clone.Parent then
						TweenService:Create(clone, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							GroupTransparency = 1,
						}):Play()
					end
				end)
				task.delay(0.68, function()
					if clone.Parent then
						clone:Destroy()
					end
				end)
			end)
		end
	end
end

function SevenWinLoginRewardPanel.Show(rewards, wins, onConfirm)
	rewards = compactRewards(rewards)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("SevenWinLoginRewardGui")
	if old then
		old:Destroy()
	end

	local gui = create("ScreenGui", {
		Name = "SevenWinLoginRewardGui",
		DisplayOrder = 10000,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
	}, playerGui)

	local shade = create("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	gradient(shade, Color3.fromRGB(2, 6, 11), Color3.fromRGB(4, 20, 20), 22)

	local panel = create("Frame", {
		Name = "KeepItemsPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 456),
	}, shade)
	create("UISizeConstraint", {
		MaxSize = Vector2.new(1120, 470),
		MinSize = Vector2.new(560, 430),
	}, panel)
	corner(panel, 16)
	stroke(panel, CYAN, 2, 0.08)
	gradient(panel, Color3.fromRGB(8, 13, 22), Color3.fromRGB(3, 7, 11), 15)

	for i = 1, 9 do
		local slash = create("Frame", {
			Name = "VoltraSlash",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = i % 2 == 0 and CYAN or GREEN,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Position = UDim2.new(0.64 + i * 0.045, 0, 0.44, 0),
			Rotation = 18,
			Size = UDim2.fromOffset(34, 620),
			ZIndex = 4,
		}, panel)
		TweenService:Create(slash, TweenInfo.new(1.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.96,
			Position = UDim2.new(0.67 + i * 0.045, 0, 0.44, 0),
		}):Play()
	end

	local title = textLabel(panel, "Title", "Keep Items", UDim2.fromOffset(22, 18), UDim2.new(0.55, -24, 0, 38), 28, WHITE)
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local kicker = textLabel(panel, "Kicker", "RANKED PATH REWARD", UDim2.fromOffset(24, 58), UDim2.new(0.55, -26, 0, 20), 10, GREEN, Enum.Font.GothamBold)
	kicker.TextWrapped = false
	kicker.TextTruncate = Enum.TextTruncate.AtEnd

	local total = textLabel(panel, "Total", tostring(#rewards) .. " Items", UDim2.new(0.62, 0, 0, 18), UDim2.new(0.38, -24, 0, 38), 28, WHITE)
	total.TextXAlignment = Enum.TextXAlignment.Right
	total.TextWrapped = false
	total.TextTruncate = Enum.TextTruncate.AtEnd

	local sub = textLabel(panel, "SubTitle", tostring(#rewards) .. " New Items | " .. tostring(math.max(0, wins)) .. " Win Reward Packs", UDim2.new(0.38, 0, 0, 58), UDim2.new(0.62, -24, 0, 24), 14, WHITE, Enum.Font.GothamBold)
	sub.TextXAlignment = Enum.TextXAlignment.Right
	sub.TextWrapped = false
	sub.TextTruncate = Enum.TextTruncate.AtEnd

	local rail = create("Frame", {
		Name = "TopRail",
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 88),
		Size = UDim2.new(1, -40, 0, 3),
		ZIndex = 12,
	}, panel)
	gradient(rail, GREEN, CYAN, 0)

	local scroller = create("ScrollingFrame", {
		Name = "Items",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Position = UDim2.fromOffset(20, 104),
		ScrollBarImageColor3 = Color3.fromRGB(190, 202, 210),
		ScrollBarThickness = 5,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Size = UDim2.new(1, -40, 0, 212),
		ZIndex = 13,
	}, panel)

	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, scroller)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 8),
	}, scroller)

	local cards = {}
	for index, reward in ipairs(rewards) do
		table.insert(cards, packCard(scroller, reward, index))
	end

	local divider = create("Frame", {
		Name = "Divider",
		BackgroundColor3 = Color3.fromRGB(28, 43, 48),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 1, -132),
		Size = UDim2.new(1, -40, 0, 1),
		ZIndex = 12,
	}, panel)
	gradient(divider, CYAN, GREEN, 0)

	local status = textLabel(panel, "Status", "UNOPENED PACKS READY FOR INVENTORY", UDim2.new(0, 24, 1, -112), UDim2.new(1, -48, 0, 22), 11, MUTED, Enum.Font.GothamBold)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextWrapped = false

	local button = create("TextButton", {
		Name = "ConfirmButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Active = false,
		AutoButtonColor = false,
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(280, 56),
		Text = "SEND TO INVENTORY",
		TextColor3 = Color3.fromRGB(2, 8, 5),
		TextSize = 20,
		ZIndex = 18,
	}, panel)
	corner(button, 16)
	stroke(button, Color3.fromRGB(218, 255, 176), 1, 0.24)
	button.Visible = false

	local scale = create("UIScale", {
		Scale = 0.94,
	}, panel)
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	button.MouseEnter:Connect(function()
		if button.Active then
			TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = Color3.fromRGB(178, 255, 73),
			}):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		if button.Active then
			TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = GREEN,
			}):Play()
		end
	end)

	task.spawn(function()
		revealCards(cards, status, button)
	end)

	local busy = false
	button.MouseButton1Click:Connect(function()
		if busy then
			return
		end

		busy = true
		button.Active = false
		button.Text = "SENDING..."
		status.Text = "MOVING PACKS TO INVENTORY"

		local ok = true
		if onConfirm then
			ok = onConfirm()
		end

		if ok then
			button.Text = "SENT"
			status.Text = "PACKS SENT TO INVENTORY"
			flyCardsToInventory(shade, cards)
			task.delay(0.78, function()
				if panel.Parent then
					TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						BackgroundTransparency = 1,
					}):Play()
				end
				TweenService:Create(shade, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
				}):Play()
			end)
			task.delay(1.02, function()
				if gui.Parent then
					gui:Destroy()
				end
			end)
		else
			button.Active = true
			button.Text = "TRY AGAIN"
			status.Text = "INVENTORY SEND FAILED"
			busy = false
		end
	end)
end

local function vtrOpenExistingDailyRewardPanel()
	if vtrDailyRewardLastArgs then
		return flyCardsToInventory(table.unpack(vtrDailyRewardLastArgs,1,vtrDailyRewardLastArgs.n))
	end
	return flyCardsToInventory()
end

task.defer(function()
	local player=Players.LocalPlayer
	if not player then return end
	local playerGui=player:WaitForChild("PlayerGui")
	local existing=playerGui:FindFirstChild("VTROpenExistingDailyReward")
	if existing then existing:Destroy() end
	local bindable=Instance.new("BindableEvent")
	bindable.Name="VTROpenExistingDailyReward"
	bindable.Parent=playerGui
	bindable.Event:Connect(function()
		vtrOpenExistingDailyRewardPanel()
	end)
end)


return SevenWinLoginRewardPanel
