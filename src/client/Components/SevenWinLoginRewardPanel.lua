local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local SevenWinLoginRewardPanel = {}

local function textLabel(parent, name, text, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.TextSize = textSize
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

local function packCard(parent, packName, index)
	local card = Instance.new("Frame")
	card.Name = "PackCard_" .. tostring(index)
	card.BackgroundColor3 = Color3.fromRGB(232, 224, 196)
	card.Size = UDim2.fromOffset(132, 176)
	card.LayoutOrder = index
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(170, 255, 65)
	stroke.Parent = card

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BackgroundColor3 = Color3.fromRGB(135, 255, 230)
	glow.BackgroundTransparency = 0.72
	glow.Position = UDim2.fromOffset(8, 8)
	glow.Size = UDim2.new(1, -16, 1, -16)
	glow.Parent = card

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 12)
	glowCorner.Parent = glow

	local rating = textLabel(card, "Rating", "95", UDim2.fromOffset(10, 10), UDim2.fromOffset(48, 30), 24, Color3.fromRGB(18, 18, 18))
	rating.TextXAlignment = Enum.TextXAlignment.Left

	local pos = textLabel(card, "Position", "PACK", UDim2.fromOffset(10, 40), UDim2.fromOffset(70, 18), 11, Color3.fromRGB(18, 18, 18))
	pos.Font = Enum.Font.GothamBold

	local name = textLabel(card, "Name", tostring(packName), UDim2.new(0, 8, 1, -52), UDim2.new(1, -16, 0, 40), 13, Color3.fromRGB(18, 18, 18))
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Center

	return card
end

local function compactRewards(rewards)
	local out = {}
	for _, packName in ipairs(rewards) do
		table.insert(out, tostring(packName))
	end
	return out
end

function SevenWinLoginRewardPanel.Show(rewards, wins, onConfirm)
	rewards = compactRewards(rewards)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("SevenWinLoginRewardGui")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SevenWinLoginRewardGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10000
	gui.Parent = playerGui

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0.2
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "KeepItemsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.86, 0, 0, 430)
	panel.BackgroundColor3 = Color3.fromRGB(12, 15, 23)
	panel.BackgroundTransparency = 0.04
	panel.Parent = shade

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(60, 235, 255)
	stroke.Parent = panel

	textLabel(panel, "Title", "Keep Items", UDim2.fromOffset(24, 16), UDim2.fromOffset(360, 42), 30)
	local total = textLabel(panel, "Total", tostring(#rewards) .. " Items", UDim2.new(1, -230, 0, 16), UDim2.fromOffset(200, 42), 28)
	total.TextXAlignment = Enum.TextXAlignment.Right

	local sub = textLabel(panel, "SubTitle", tostring(#rewards) .. " New Items | " .. tostring(math.max(0, wins)) .. " Win Reward Packs", UDim2.new(1, -620, 0, 58), UDim2.fromOffset(580, 28), 15)
	sub.TextXAlignment = Enum.TextXAlignment.Right
	sub.Font = Enum.Font.GothamBold

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Items"
	scroller.BackgroundTransparency = 1
	scroller.Position = UDim2.fromOffset(22, 100)
	scroller.Size = UDim2.new(1, -44, 0, 215)
	scroller.ScrollBarThickness = 6
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroller.CanvasSize = UDim2.fromScale(0, 0)
	scroller.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = scroller

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = scroller

	for index, packName in ipairs(rewards) do
		packCard(scroller, packName, index)
	end

	local button = Instance.new("TextButton")
	button.Name = "ConfirmButton"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -24)
	button.Size = UDim2.fromOffset(260, 56)
	button.BackgroundColor3 = Color3.fromRGB(120, 255, 65)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 22
	button.TextColor3 = Color3.fromRGB(10, 15, 10)
	button.Text = "CONFIRM"
	button.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 16)
	buttonCorner.Parent = button

	panel.Size = UDim2.new(0.8, 0, 0, 390)
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.86, 0, 0, 430),
	}):Play()

	local busy = false
	button.MouseButton1Click:Connect(function()
		if busy then
			return
		end

		busy = true
		button.Text = "SENDING..."
		local ok = onConfirm()

		if ok then
			gui:Destroy()
		else
			button.Text = "TRY AGAIN"
			busy = false
		end
	end)
end

return SevenWinLoginRewardPanel
