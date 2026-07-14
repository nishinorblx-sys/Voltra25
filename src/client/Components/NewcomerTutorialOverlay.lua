--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Button = require(script.Parent.Button)

local Tutorial = {}

local TASKS = {
	{ Page = "WorldCup", Label = "World Cup", Text = "Click World Cup. New players get a direct route: essential match preload, quick country choice, Matchday 1 reveal, pass lesson, shooting lesson, defending lesson, then free play." },
}

local function label(parent: Instance, name: string, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local result = Instance.new("TextLabel")
	result.Name = name
	result.BackgroundTransparency = 1
	result.Position = position
	result.Size = size
	result.Text = value
	result.TextColor3 = color
	result.TextSize = textSize
	result.Font = font
	result.TextWrapped = true
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.TextYAlignment = Enum.TextYAlignment.Center
	result.ZIndex = 904
	result.Parent = parent
	return result
end

local function findTarget(root: Instance, page: string, props: any?): GuiObject?
	if props and props.GetTarget then
		local ok, target = pcall(function()
			return props.GetTarget(page)
		end)
		if ok and typeof(target) == "Instance" and target:IsA("GuiObject") and target.Visible then
			return target
		end
	end
	local wanted = page .. "Nav"
	local best: GuiObject? = nil
	local bestArea = math.huge
	for _, descendant in root:GetDescendants() do
		if descendant.Name == wanted and descendant:IsA("GuiObject") and descendant.Visible then
			local size = descendant.AbsoluteSize
			local area = size.X * size.Y
			local navSized = size.X >= 48 and size.Y >= 24 and size.X <= 280 and size.Y <= 92
			if navSized and area < bestArea then
				best = descendant
				bestArea = area
			end
		end
	end
	return best
end

local function clampNumber(value: number, minValue: number, maxValue: number): number
	if maxValue < minValue then return minValue end
	return math.clamp(value, minValue, maxValue)
end

function Tutorial.show(root: Instance, props: any?)
	local old = root:FindFirstChild("NewcomerTutorialOverlay")
	if old then old:Destroy() end
	props = props or {}

	local stepIndex = math.clamp(math.floor(tonumber(props.InitialStep) or 1), 1, #TASKS)
	local currentTask = TASKS[stepIndex]
	local typingToken = 0
	local completed = false

	local overlay = Instance.new("Frame")
	overlay.Name = "NewcomerTutorialOverlay"
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Active = false
	overlay.ZIndex = 899
	overlay.Parent = root

	local panel = Instance.new("Frame")
	panel.Name = "TaskPanel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.BackgroundColor3 = Color3.fromHex("050705")
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromOffset(190, 92)
	panel.Size = UDim2.fromOffset(430, 150)
	panel.ZIndex = 903
	panel.Parent = overlay
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Theme.Colors.Electric
	panelStroke.Transparency = 0.08
	panelStroke.Thickness = 1.5
	panelStroke.Parent = panel

	local kicker = label(panel, "Kicker", "WORLD CUP ONBOARDING", UDim2.fromOffset(16, 12), UDim2.new(1, -144, 0, 16), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	local taskText = label(panel, "Task", "", UDim2.fromOffset(16, 34), UDim2.new(1, -32, 0, 72), 14, Theme.Colors.White, Theme.Fonts.Display)
	local hint = label(panel, "Hint", "Go to World Cup to start the guided first match route.", UDim2.fromOffset(16, 112), UDim2.new(1, -32, 0, 24), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	kicker.TextWrapped = false
	hint.TextWrapped = true
	taskText.TextScaled = true
	local taskTextLimit = Instance.new("UITextSizeConstraint")
	taskTextLimit.MinTextSize = 10
	taskTextLimit.MaxTextSize = 16
	taskTextLimit.Parent = taskText

	local skip = Button.new({
		Text = "SKIP GUIDE",
		Variant = "Secondary",
		Size = UDim2.fromOffset(116, 28),
		OnActivated = function()
			if completed then return end
			completed = true
			if props.OnComplete then props.OnComplete(true) end
			TweenService:Create(panel, TweenInfo.new(0.16), {BackgroundTransparency = 1}):Play()
			task.delay(0.18, function()
				if overlay.Parent then overlay:Destroy() end
			end)
		end,
	})
	skip.Position = UDim2.new(1, -128, 0, 8)
	skip.ZIndex = 905
	skip.Parent = panel

	local function saveStep()
		if props.OnStep then props.OnStep(stepIndex, "Menu") end
	end

	local function typeTask(tutorialTask: any)
		typingToken += 1
		local token = typingToken
		local value = tostring(stepIndex) .. ". " .. tostring(tutorialTask and tutorialTask.Text or "")
		taskText.Text = ""
		for index = 1, #value do
			if token ~= typingToken or not taskText.Parent then return end
			taskText.Text = string.sub(value, 1, index)
			task.wait(0.012)
		end
	end

	local function layoutPanel()
		local target = findTarget(root, currentTask.Page, props)
		local rootPos = overlay.AbsolutePosition
		local rootSize = overlay.AbsoluteSize
		local safeMargin = rootSize.X < 720 and 10 or 14
		local compactWidth = math.clamp(rootSize.X * (rootSize.X < 720 and .82 or .38), 288, 430)
		local compactHeight = rootSize.X < 720 and 174 or 150
		panel.Size = UDim2.fromOffset(compactWidth, compactHeight)
		taskText.Size = UDim2.new(1, -32, 0, compactHeight - 78)
		hint.Position = UDim2.fromOffset(16, compactHeight - 36)
		hint.Size = UDim2.new(1, -32, 0, 26)
		if not target then
			local menuStrip = math.min(210, rootSize.X * 0.46)
			local px = clampNumber(menuStrip + safeMargin, safeMargin, rootSize.X - compactWidth - safeMargin)
			local py = clampNumber(rootSize.Y * .28, compactHeight * .5 + safeMargin, rootSize.Y - compactHeight * .5 - safeMargin)
			panel.Position = UDim2.fromOffset(px, py)
			return
		end

		local pad = 8
		local pos = target.AbsolutePosition - rootPos
		local size = target.AbsoluteSize
		local x = math.max(0, pos.X - pad)
		local y = math.max(0, pos.Y - pad)
		local w = math.min(rootSize.X - x, size.X + pad * 2)
		local h = math.min(rootSize.Y - y, size.Y + pad * 2)

		local rightX = x + w + 12
		local leftX = x - compactWidth - 12
		local panelX: number
		if rightX + compactWidth <= rootSize.X - safeMargin then
			panelX = rightX
		elseif leftX >= safeMargin then
			panelX = leftX
		elseif rootSize.X < 720 then
			panelX = clampNumber((rootSize.X - compactWidth) * .5, safeMargin, rootSize.X - compactWidth - safeMargin)
		else
			panelX = clampNumber(math.max(190, rootSize.X * .18), safeMargin, rootSize.X - compactWidth - safeMargin)
		end
		local panelY = y + h * .5
		local overlapsTargetX = panelX < x + w and panelX + compactWidth > x
		if overlapsTargetX then
			local below = y + h + compactHeight * .5 + 12
			local above = y - compactHeight * .5 - 12
			if below <= rootSize.Y - safeMargin then
				panelY = below
			elseif above >= safeMargin + compactHeight * .5 then
				panelY = above
			end
		elseif y < compactHeight + safeMargin then
			panelY = y + h + compactHeight * .5 + 12
		elseif y + h + compactHeight * .5 > rootSize.Y - safeMargin then
			panelY = y - compactHeight * .5 - 12
		end
		panelY = clampNumber(panelY, compactHeight * .5 + safeMargin, rootSize.Y - compactHeight * .5 - safeMargin)
		panel.Position = UDim2.fromOffset(panelX, panelY)
	end

	local function finish()
		if completed then return end
		completed = true
		if props.OnComplete then props.OnComplete(false) end
		TweenService:Create(panel, TweenInfo.new(0.16), {BackgroundTransparency = 1}):Play()
		task.delay(0.18, function()
			if overlay.Parent then overlay:Destroy() end
		end)
	end

	local function advance()
		if completed then return end
		if stepIndex >= #TASKS then
			finish()
			return
		end
		stepIndex += 1
		currentTask = TASKS[stepIndex]
		saveStep()
		task.spawn(typeTask, currentTask)
		layoutPanel()
	end

	saveStep()
	task.spawn(typeTask, currentTask)
	layoutPanel()

	local heartbeat = RunService.Heartbeat:Connect(function()
		if completed or not overlay.Parent then return end
		layoutPanel()
		if props.GetCurrentPage and props.GetCurrentPage() == currentTask.Page then
			task.delay(0.18, function()
				if not completed and overlay.Parent and props.GetCurrentPage and props.GetCurrentPage() == currentTask.Page then
					advance()
				end
			end)
		end
	end)

	overlay.Destroying:Connect(function()
		heartbeat:Disconnect()
		if not completed and props.OnClose then
			props.OnClose(stepIndex, "Menu")
		end
	end)

	return overlay
end

return Tutorial
