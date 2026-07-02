local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local SevenWinLoginRewardPanel = {}

local function makeLabel(parent, name, text, size, position, fontSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.GothamBold
	label.TextSize = fontSize
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

function SevenWinLoginRewardPanel.Show(rewards, wins, onConfirm)
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
	shade.BackgroundTransparency = 0.28
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(540, 420)
	panel.BackgroundColor3 = Color3.fromRGB(21, 27, 39)
	panel.Parent = shade

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(83, 154, 255)
	stroke.Parent = panel

	makeLabel(panel, "Title", "7 WIN LOGIN REWARD", UDim2.new(1, -48, 0, 48), UDim2.fromOffset(24, 22), 28)
	makeLabel(panel, "SubTitle", tostring(wins) .. " wins detected. You earned these packs.", UDim2.new(1, -48, 0, 34), UDim2.fromOffset(24, 68), 17)

	local list = Instance.new("ScrollingFrame")
	list.Name = "RewardList"
	list.BackgroundColor3 = Color3.fromRGB(13, 18, 28)
	list.BackgroundTransparency = 0.15
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(32, 120)
	list.Size = UDim2.new(1, -64, 1, -206)
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = panel

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 14)
	listCorner.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = list

	local counts = {}
	for _, packName in ipairs(rewards) do
		counts[packName] = (counts[packName] or 0) + 1
	end

	local names = {}
	for packName in pairs(counts) do
		table.insert(names, packName)
	end
	table.sort(names)

	for index, packName in ipairs(names) do
		local row = Instance.new("Frame")
		row.Name = packName
		row.BackgroundColor3 = Color3.fromRGB(31, 43, 65)
		row.Size = UDim2.new(1, 0, 0, 54)
		row.LayoutOrder = index
		row.Parent = list

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 12)
		rowCorner.Parent = row

		makeLabel(row, "PackName", packName, UDim2.new(1, -92, 1, 0), UDim2.fromOffset(18, 0), 18).TextXAlignment = Enum.TextXAlignment.Left
		makeLabel(row, "Count", "x" .. tostring(counts[packName]), UDim2.fromOffset(66, 1, 1, 0), UDim2.new(1, -78, 0, 0), 20)
	end

	local button = Instance.new("TextButton")
	button.Name = "ConfirmButton"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -28)
	button.Size = UDim2.fromOffset(250, 54)
	button.BackgroundColor3 = Color3.fromRGB(48, 139, 255)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 20
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = "CONFIRM"
	button.AutoButtonColor = true
	button.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 14)
	buttonCorner.Parent = button

	panel.Size = UDim2.fromOffset(500, 386)
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(540, 420),
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

return SevenWinLoginRewardPanel
