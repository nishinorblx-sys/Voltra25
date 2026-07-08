local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)

local PackRewardFlyinAnimation = {}

local function lowerText(obj)
	local values = { obj.Name }

	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		table.insert(values, obj.Text)
	end

	for _, value in ipairs(values) do
		local s = string.lower(tostring(value or ""))
		if s ~= "" then
			return s
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
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("GuiObject") then
			local s = lowerText(obj)
			if string.find(s, "inventory") or string.find(s, "inv") or string.find(s, "backpack") or string.find(s, "packs") then
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

local function guiPosFromAbsolute(gui, absoluteCenter)
	local root = gui.AbsolutePosition
	return UDim2.fromOffset(absoluteCenter.X - root.X, absoluteCenter.Y - root.Y)
end

local function packInfo(packName)
	local id = tostring(packName or "pack")
	local definition = Catalog.Packs and Catalog.Packs[id]
	local display = definition and definition.Name or id:gsub("_", " "):upper()
	local rarity = string.match(string.lower(id), "^(%w+)_pack") or "voltra"
	local color = Color3.fromRGB(136, 255, 72)
	if rarity == "common" then color = Color3.fromRGB(171, 255, 106)
	elseif rarity == "bronze" then color = Color3.fromRGB(205, 132, 78)
	elseif rarity == "silver" then color = Color3.fromRGB(218, 227, 232)
	elseif rarity == "gold" then color = Color3.fromRGB(255, 210, 75)
	elseif rarity == "rare" then color = Color3.fromRGB(40, 178, 255)
	elseif rarity == "elite" then color = Color3.fromRGB(178, 75, 255)
	elseif rarity == "legendary" then color = Color3.fromRGB(255, 95, 55)
	elseif rarity == "icon" or rarity == "mythic" then color = Color3.fromRGB(255, 255, 255)
	end
	return display, color, definition
end

local function makeGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("PackRewardFlyinGui")

	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "PackRewardFlyinGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15000
	gui.Parent = playerGui

	return gui
end

function PackRewardFlyinAnimation.Play(packName)
	local gui = makeGui()
	local displayName, accent, definition = packInfo(packName)

	local card = Instance.new("CanvasGroup")
	card.Name = "PackRewardPopup"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.47)
	card.Size = UDim2.fromOffset(430, 250)
	card.BackgroundColor3 = Color3.fromRGB(8, 12, 10)
	card.BackgroundTransparency = 0.02
	card.ClipsDescendants = true
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 26)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = accent
	stroke.Parent = card

	local shine = Instance.new("Frame")
	shine.Name = "PackShine"
	shine.BackgroundColor3 = accent
	shine.BackgroundTransparency = 0.86
	shine.BorderSizePixel = 0
	shine.Rotation = -18
	shine.Position = UDim2.fromOffset(250, -42)
	shine.Size = UDim2.fromOffset(94, 330)
	shine.Parent = card

	local glow = Instance.new("Frame")
	glow.Name = "RewardGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = accent
	glow.BackgroundTransparency = 0.82
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromScale(0.28, 0.52)
	glow.Size = UDim2.fromOffset(165, 165)
	glow.Parent = card
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 18)
	title.Size = UDim2.new(1, -48, 0, 28)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 19
	title.TextColor3 = accent
	title.Text = "PACK EARNED"
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = card

	local pack = Instance.new("CanvasGroup")
	pack.Name = "PackCard"
	pack.AnchorPoint = Vector2.new(0.5, 0.5)
	pack.BackgroundColor3 = Color3.fromRGB(14, 20, 18)
	pack.Position = UDim2.fromScale(0.31, 0.56)
	pack.Size = UDim2.fromOffset(128, 162)
	pack.Rotation = -5
	pack.Parent = card
	local packCorner = Instance.new("UICorner"); packCorner.CornerRadius = UDim.new(0, 14); packCorner.Parent = pack
	local packStroke = Instance.new("UIStroke"); packStroke.Color = accent; packStroke.Thickness = 2; packStroke.Transparency = 0.12; packStroke.Parent = pack
	local packBand = Instance.new("Frame")
	packBand.BackgroundColor3 = accent
	packBand.BorderSizePixel = 0
	packBand.Position = UDim2.fromScale(0, 0.68)
	packBand.Size = UDim2.fromScale(1, 0.16)
	packBand.Parent = pack
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Position = UDim2.fromScale(0, 0.15)
	mark.Size = UDim2.fromScale(1, 0.44)
	mark.Font = Enum.Font.GothamBlack
	mark.Text = "V\n25"
	mark.TextColor3 = accent
	mark.TextSize = 40
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.TextYAlignment = Enum.TextYAlignment.Center
	mark.Parent = pack

	local name = Instance.new("TextLabel")
	name.Name = "PackName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(174, 74)
	name.Size = UDim2.new(1, -202, 0, 78)
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 25
	name.TextWrapped = true
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.Text = string.upper(displayName)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = card

	local detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(176, 154)
	detail.Size = UDim2.new(1, -206, 0, 42)
	detail.Font = Enum.Font.GothamBold
	detail.TextSize = 10
	detail.TextWrapped = true
	detail.TextColor3 = Color3.fromRGB(190, 199, 190)
	detail.Text = (definition and tostring(definition.CardCount or "?") or "?") .. " PLAYER CARDS  /  SENT TO INVENTORY"
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.Parent = card

	card.Size = UDim2.fromOffset(340, 198)
	TweenService:Create(card, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(430, 250),
	}):Play()
	TweenService:Create(pack, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = 0}):Play()

	task.wait(0.42)

	local target = findInventoryTarget()
	local endPosition = UDim2.fromScale(0.91, 0.91)
	local endSize = UDim2.fromOffset(62, 42)

	if target then
		local center = target.AbsolutePosition + target.AbsoluteSize * 0.5
		endPosition = guiPosFromAbsolute(gui, center)
		endSize = UDim2.fromOffset(math.max(42, target.AbsoluteSize.X * 0.35), math.max(32, target.AbsoluteSize.Y * 0.35))
	end

	local fly = TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = endPosition,
		Size = endSize,
		BackgroundTransparency = 0.62,
		GroupTransparency = 0.25,
	})
	fly:Play()
	fly.Completed:Wait()

	local fade = TweenService:Create(card, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	fade:Play()
	fade.Completed:Wait()

	card:Destroy()
end

return PackRewardFlyinAnimation
