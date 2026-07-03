local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local RankedStatsPanelFixClient = {}

local started = false
local lastFix = 0

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function textOf(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		return tostring(obj.Text or "")
	end
	return ""
end

local function isText(obj, value)
	return lower(textOf(obj)) == lower(value)
end

local function findRankedPanel(playerGui)
	local recordLabel

	for _, obj in ipairs(playerGui:GetDescendants()) do
		if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isText(obj, "PATH RECORD") then
			recordLabel = obj
			break
		end
	end

	if not recordLabel then
		return nil
	end

	local current = recordLabel.Parent
	while current and current ~= playerGui do
		if current:IsA("Frame") or current:IsA("CanvasGroup") or current:IsA("ScrollingFrame") then
			local hasDivision = false
			for _, child in ipairs(current:GetDescendants()) do
				if (child:IsA("TextLabel") or child:IsA("TextButton")) and string.find(lower(textOf(child)), "division") then
					hasDivision = true
					break
				end
			end

			if hasDivision then
				return current
			end
		end

		current = current.Parent
	end

	return recordLabel.Parent
end

local function findLabel(root, text)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if isText(obj, text) then
				return obj
			end
		end
	end

	return nil
end

local function findRecordValue(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			local raw = tostring(obj.Text or "")
			local wins, draws, losses = string.match(raw, "(%d+)%s*W%s*/%s*(%d+)%s*D%s*/%s*(%d+)%s*L")
			if wins and draws and losses then
				return obj, wins, draws, losses
			end
		end
	end

	return nil, nil, nil, nil
end

local function makeValue(root, name)
	local label = root:FindFirstChild(name)

	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 30
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = false
	label.TextScaled = false
	label.AutomaticSize = Enum.AutomaticSize.None
	label.ZIndex = 50
	label.Parent = root

	return label
end

local function relative(root, absolute)
	return Vector2.new(absolute.X - root.AbsolutePosition.X, absolute.Y - root.AbsolutePosition.Y)
end

local function stabilizeValue(root, header, valueLabel, text, y)
	if not header or not valueLabel then
		return
	end

	local pos = relative(root, Vector2.new(header.AbsolutePosition.X, y))
	valueLabel.AnchorPoint = Vector2.new(0, 0)
	valueLabel.Position = UDim2.fromOffset(pos.X, pos.Y)
	valueLabel.Size = UDim2.fromOffset(140, 46)
	valueLabel.Text = tostring(text)
	valueLabel.Visible = true
	valueLabel.TextTransparency = 0
	valueLabel.LayoutOrder = 0
end

local function hideLooseDigits(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if obj.Name ~= "VTRStablePathWins" and obj.Name ~= "VTRStablePathLosses" then
				local clean = string.gsub(tostring(obj.Text or ""), "%s+", "")
				if string.match(clean, "^%d+$") and obj.AbsoluteSize.Y < 80 then
					local parentName = lower(obj.Parent and obj.Parent.Name or "")
					local objName = lower(obj.Name)
					if string.find(parentName, "path") or string.find(objName, "path") or string.find(parentName, "stat") or string.find(objName, "stat") then
						obj.Visible = false
						obj.TextTransparency = 1
					end
				end
			end
		elseif obj:IsA("ScrollingFrame") and obj == root then
			obj.CanvasPosition = Vector2.new(0, 0)
		end
	end
end

function RankedStatsPanelFixClient.Fix()
	local now = os.clock()
	if now - lastFix < 0.15 then
		return
	end

	lastFix = now

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local root = findRankedPanel(playerGui)
	if not root then
		return
	end

	local recordValue, wins, _, losses = findRecordValue(root)
	if not recordValue then
		return
	end

	local winsHeader = findLabel(root, "PATH WINS")
	local lossesHeader = findLabel(root, "PATH LOSSES")
	local y = recordValue.AbsolutePosition.Y

	local winsValue = makeValue(root, "VTRStablePathWins")
	local lossesValue = makeValue(root, "VTRStablePathLosses")

	stabilizeValue(root, winsHeader, winsValue, wins, y)
	stabilizeValue(root, lossesHeader, lossesValue, losses, y)
	hideLooseDigits(root)

	if root:IsA("ScrollingFrame") then
		root.CanvasPosition = Vector2.new(0, 0)
	end
end

function RankedStatsPanelFixClient.Start()
	if started then
		return
	end

	started = true

	task.defer(function()
		for _ = 1, 20 do
			RankedStatsPanelFixClient.Fix()
			task.wait(0.25)
		end
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.DescendantAdded:Connect(function()
		task.defer(RankedStatsPanelFixClient.Fix)
	end)
end

RankedStatsPanelFixClient.Start()

return RankedStatsPanelFixClient
