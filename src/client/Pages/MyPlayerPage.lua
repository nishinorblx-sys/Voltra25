--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local PlayBuilderConfig = require(ReplicatedStorage.VTR.Shared.PlayBuilderConfig)
local PageBase = require(script.Parent.PageBase)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)

local Page = {}

local TIER_COLORS = {
	[0] = Color3.fromHex("3A4050"),
	[1] = Color3.fromHex("B87333"),
	[2] = Color3.fromHex("C8D2E2"),
	[3] = Color3.fromHex("FFD24A"),
}
local VOLTRA_GREEN = Color3.fromHex("B7FF1A")

local function text(parent: Instance, value: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Text = value
	label.TextColor3 = color or Theme.Colors.White or Color3.new(1, 1, 1)
	label.TextSize = textSize
	label.Font = font
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function toast(context: any, message: string, kind: string?)
	if context and context.Toast then
		context.Toast({Title = "MY PLAYER", Message = message, Kind = kind or "Info"})
	end
end

local function buttonBase(parent: Instance, name: string, pos: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromHex("101522")
	button.BorderSizePixel = 0
	button.Position = pos
	button.Size = size
	button.Font = Theme.Fonts.Strong
	button.TextColor3 = Theme.Colors.White
	button.TextSize = 13
	button.Text = ""
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("273043")
	stroke.Transparency = .18
	stroke.Parent = button
	return button
end

local function makePreview(parent: Instance): (TextLabel, TextLabel)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "MyPlayerViewport"
	viewport.BackgroundColor3 = Color3.fromHex("070A12")
	viewport.BorderSizePixel = 0
	viewport.Position = UDim2.fromOffset(12, 48)
	viewport.Size = UDim2.new(1, -24, 0, 198)
	viewport.Ambient = Color3.fromRGB(135, 120, 190)
	viewport.LightColor = Color3.fromRGB(235, 235, 255)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent
	Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 8)

	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0, 2.4, 7), Vector3.new(0, 1.8, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local ovr = text(parent, "OVR 70", UDim2.fromOffset(12, 256), UDim2.new(1, -24, 0, 42), 30, Theme.Colors.Electric, Theme.Fonts.Display)
	ovr.TextXAlignment = Enum.TextXAlignment.Center
	local name = text(parent, "MY PLAYER", UDim2.fromOffset(12, 298), UDim2.new(1, -24, 0, 24), 13, Theme.Colors.White, Theme.Fonts.Display)
	name.TextXAlignment = Enum.TextXAlignment.Center

	task.spawn(function()
		local okPreview, previewErr = pcall(function()
			local userId = Players.LocalPlayer.UserId
			local ok, description = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(userId)
			end)
			local rig: Model?
			if ok and description then
				local createdOk, created = pcall(function()
					return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
				end)
				if createdOk and created then
					rig = created
				end
			end
			if not rig then
				rig = Instance.new("Model")
				rig.Name = "PreviewFallback"
				local part = Instance.new("Part")
				part.Name = "HumanoidRootPart"
				part.Anchored = true
				part.CanCollide = false
				part.Transparency = 1
				part.Size = Vector3.new(2, 2, 1)
				part.Parent = rig
				rig.PrimaryPart = part
			end
			rig.Name = "MyPlayerRig"
			pcall(function()
				rig:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0))
			end)
			rig.Parent = world
			for _, descendant in rig:GetDescendants() do
				if descendant:IsA("BasePart") and descendant.Name ~= "Head" then
					descendant.Color = descendant.Name == "Torso" and Color3.fromHex("16101F") or Color3.fromHex("080A0F")
					descendant.Material = Enum.Material.SmoothPlastic
				end
			end
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
				animator.Parent = humanoid
				local animation = Instance.new("Animation")
				animation.AnimationId = "rbxassetid://180435571"
				local loadedOk, track = pcall(function()
					return animator:LoadAnimation(animation)
				end)
				if loadedOk and track then
					track.Looped = true
					pcall(function()
						track:Play(.15)
					end)
				end
			end
			local rotationConnection: RBXScriptConnection?
			rotationConnection = RunService.RenderStepped:Connect(function()
				if not viewport.Parent or not rig or not rig.Parent then
					if rotationConnection then rotationConnection:Disconnect() end
					return
				end
				pcall(function()
					rig:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180 + math.sin(os.clock() * .7) * 7), 0))
				end)
			end)
		end)
		if not okPreview then
			warn("[VTR MY PLAYER] Preview failed: "..tostring(previewErr))
		end
	end)

	return ovr, name
end

function Page.new(context: any): Frame
	local group, scroll = PageBase.new("MyPlayer", 960)
	PageBase.heading(scroll, "PLAY MODE", "MY PLAYER", "Build your Voltra footballer for 3v3, 4v4, and 5v5.")

	local builder = PlayBuilderConfig.Normalize(nil)
	local response = MatchSetupService:GetPlayBuilder()
	if type(response) == "table" and response.Success and type(response.Data) == "table" then
		builder = PlayBuilderConfig.Normalize(response.Data, response.Data.Level)
	end

	local panel = Panel.new({Name = "MyPlayerBuilder", Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 820)})
	panel.Parent = scroll
	text(panel, "PLAYER BUILDER", UDim2.fromOffset(20, 14), UDim2.new(.35, 0, 0, 32), 24, Theme.Colors.White, Theme.Fonts.Display)
	local summary = text(panel, "LEVEL 1  |  0 ATTRIBUTE POINTS  |  0 TRAIT POINTS", UDim2.new(1, -360, 0, 18), UDim2.fromOffset(336, 24), 12, Theme.Colors.Silver, Theme.Fonts.Strong)
	summary.TextXAlignment = Enum.TextXAlignment.Right

	local archetypes = Instance.new("Frame")
	archetypes.BackgroundTransparency = 1
	archetypes.Position = UDim2.fromOffset(20, 66)
	archetypes.Size = UDim2.new(.23, -16, 0, 470)
	archetypes.Parent = panel
	text(archetypes, "ARCHETYPE", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 22), 10, Theme.Colors.White, Theme.Fonts.Strong)

	local statBox = Instance.new("Frame")
	statBox.BackgroundColor3 = Color3.fromHex("090D16")
	statBox.BackgroundTransparency = .05
	statBox.BorderSizePixel = 0
	statBox.Position = UDim2.new(.24, 0, 0, 66)
	statBox.Size = UDim2.new(.36, -8, 0, 470)
	statBox.Parent = panel
	Instance.new("UICorner", statBox).CornerRadius = UDim.new(0, 7)
	text(statBox, "ATTRIBUTES", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 24), 13, Theme.Colors.White, Theme.Fonts.Display)
	local pointLabel = text(statBox, "0 AVAILABLE", UDim2.new(1, -128, 0, 13), UDim2.fromOffset(112, 18), 10, Theme.Colors.Electric, Theme.Fonts.Strong)
	pointLabel.TextXAlignment = Enum.TextXAlignment.Right

	local traits = Instance.new("Frame")
	traits.BackgroundColor3 = Color3.fromHex("090D16")
	traits.BackgroundTransparency = .05
	traits.BorderSizePixel = 0
	traits.Position = UDim2.new(.60, 0, 0, 66)
	traits.Size = UDim2.new(.23, -8, 0, 470)
	traits.Parent = panel
	Instance.new("UICorner", traits).CornerRadius = UDim.new(0, 7)
	text(traits, "TRAITS", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 13, Theme.Colors.White, Theme.Fonts.Display)
	local traitPointLabel = text(traits, "0 AVAILABLE", UDim2.new(1, -118, 0, 13), UDim2.fromOffset(104, 18), 10, Theme.Colors.Electric, Theme.Fonts.Strong)
	traitPointLabel.TextXAlignment = Enum.TextXAlignment.Right

	local preview = Instance.new("Frame")
	preview.BackgroundColor3 = Color3.fromHex("080B14")
	preview.BorderSizePixel = 0
	preview.Position = UDim2.new(.83, 0, 0, 66)
	preview.Size = UDim2.new(.17, -20, 0, 470)
	preview.Parent = panel
	Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 7)
	local previewStroke = Instance.new("UIStroke")
	previewStroke.Color = Theme.Colors.Electric
	previewStroke.Transparency = .35
	previewStroke.Parent = preview
	text(preview, "MY PLAYER", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 24), 13, Theme.Colors.White, Theme.Fonts.Display)
	local ovr, previewName = makePreview(preview)

	local rows: {[string]: any} = {}
	local saving = false
	local function saveBuilder()
		if saving then return end
		saving = true
		local result = MatchSetupService:SavePlayBuilder(builder)
		saving = false
		if type(result) == "table" then
			if result.Success and type(result.Data) == "table" then
				builder = PlayBuilderConfig.Normalize(result.Data, result.Data.Level)
			else
				toast(context, result.Message or "Could not update My Player.", "Error")
			end
		end
	end

	local function statRow(entry: any, y: number)
		local labelText = tostring(entry.Label)
		local key = tostring(entry.Key)
		text(statBox, labelText, UDim2.fromOffset(16, y), UDim2.fromOffset(96, 18), 9, Theme.Colors.Silver, Theme.Fonts.Strong)
		local back = Instance.new("Frame")
		back.BackgroundColor3 = Theme.Colors.Gunmetal
		back.BorderSizePixel = 0
		back.Position = UDim2.fromOffset(112, y + 5)
		back.Size = UDim2.new(1, -188, 0, 8)
		back.Parent = statBox
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = Color3.fromHex(tostring(entry.Color))
		fill.BorderSizePixel = 0
		fill.Parent = back
		local value = text(statBox, "70", UDim2.new(1, -70, 0, y - 2), UDim2.fromOffset(28, 20), 10, Theme.Colors.White, Theme.Fonts.Strong)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local plus = Button.new({Text = "+", Variant = "Secondary", Size = UDim2.fromOffset(26, 22)})
		plus.Position = UDim2.new(1, -34, 0, y - 3)
		plus.Parent = statBox
		plus.Activated:Connect(function()
			builder = PlayBuilderConfig.Normalize(builder, builder.Level)
			if (tonumber(builder.AttributePointsAvailable) or 0) <= 0 then
				toast(context, "No attribute points available.", "Info")
				return
			end
			builder.Attributes = builder.Attributes or {}
			builder.Attributes[key] = (tonumber(builder.Attributes[key]) or 0) + 1
			saveBuilder()
			if rows.__render then rows.__render() end
		end)
		rows[key] = {Fill = fill, Value = value, Plus = plus}
	end

	for index, entry in PlayBuilderConfig.AttributeOrder do
		statRow(entry, 46 + (index - 1) * 34)
	end

	local archetypeButtons: {[string]: TextButton} = {}
	local archetypeTitles: {[string]: TextLabel} = {}
	local archetypeSubtitles: {[string]: TextLabel} = {}
	local archetypeFocus: {[string]: TextLabel} = {}
	for index, id in PlayBuilderConfig.Order do
		local data = PlayBuilderConfig.Archetypes[id]
		local button = buttonBase(archetypes, id, UDim2.fromOffset(0, 30 + (index - 1) * 84), UDim2.new(1, 0, 0, 76))
		button.Text = ""
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextSize = 14
		button.TextColor3 = Color3.fromHex(data.Color)
		archetypeTitles[id] = text(button, data.Title, UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 18), 13, Color3.fromHex(data.Color), Theme.Fonts.Display)
		archetypeSubtitles[id] = text(button, data.Tagline, UDim2.fromOffset(12, 29), UDim2.new(1, -24, 0, 16), 9, Theme.Colors.Silver, Theme.Fonts.Strong)
		archetypeFocus[id] = text(button, data.Focus, UDim2.fromOffset(12, 49), UDim2.new(1, -24, 0, 16), 8, Theme.Colors.Muted, Theme.Fonts.Body)
		archetypeButtons[id] = button
		button.Activated:Connect(function()
			builder.Archetype = id
			saveBuilder()
			if rows.__render then rows.__render() end
		end)
	end

	local traitButtons: {[string]: TextButton} = {}
	local traitTitles: {[string]: TextLabel} = {}
	local traitDescriptions: {[string]: TextLabel} = {}
	for index, id in PlayBuilderConfig.TraitOrder do
		local data = PlayBuilderConfig.Traits[id]
		local y = 42 + (index - 1) * 58
		local traitButton = buttonBase(traits, id, UDim2.fromOffset(14, y), UDim2.new(1, -28, 0, 52))
		traitButton.Text = ""
		traitButton.TextXAlignment = Enum.TextXAlignment.Left
		traitButton.TextSize = 11
		traitTitles[id] = text(traitButton, data.Title, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 14), 10, Theme.Colors.White, Theme.Fonts.Display)
		local desc = text(traitButton, data.Description, UDim2.fromOffset(12, 22), UDim2.new(1, -24, 0, 24), 7, Color3.fromHex("E7ECF8"), Theme.Fonts.Body)
		desc.TextYAlignment = Enum.TextYAlignment.Top
		traitDescriptions[id] = desc
		traitButtons[id] = traitButton
		traitButton.Activated:Connect(function()
			builder = PlayBuilderConfig.Normalize(builder, builder.Level)
			local current = tonumber(builder.Traits and builder.Traits[id]) or 0
			if current >= 3 then
				toast(context, "That trait is already gold.", "Info")
				return
			end
			if (tonumber(builder.TraitPointsAvailable) or 0) <= 0 then
				toast(context, "No trait points available.", "Info")
				return
			end
			builder.Traits = builder.Traits or {}
			builder.Traits[id] = current + 1
			saveBuilder()
			if rows.__render then rows.__render() end
		end)
	end

	local milestones = Instance.new("Frame")
	milestones.BackgroundColor3 = Color3.fromHex("090D16")
	milestones.BackgroundTransparency = .05
	milestones.BorderSizePixel = 0
	milestones.Position = UDim2.fromOffset(20, 560)
	milestones.Size = UDim2.new(1, -40, 0, 150)
	milestones.Parent = panel
	Instance.new("UICorner", milestones).CornerRadius = UDim.new(0, 7)
	text(milestones, "PROGRESSION", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 22), 13, Theme.Colors.White, Theme.Fonts.Display)
	text(milestones, "Level up to earn points and unlock stronger PLAY builds.", UDim2.fromOffset(16, 32), UDim2.new(1, -32, 0, 18), 9, Theme.Colors.Muted, Theme.Fonts.Body)
	local rail = Instance.new("Frame")
	rail.Name = "MilestoneRail"
	rail.BackgroundColor3 = Color3.fromHex("323947")
	rail.BorderSizePixel = 0
	rail.Position = UDim2.fromOffset(38, 72)
	rail.Size = UDim2.new(1, -76, 0, 2)
	rail.Parent = milestones
	local railFill = Instance.new("Frame")
	railFill.Name = "MilestoneRailFill"
	railFill.BackgroundColor3 = Theme.Colors.Electric
	railFill.BorderSizePixel = 0
	railFill.Size = UDim2.fromScale(0, 1)
	railFill.Parent = rail
	local milestoneNodes = {}
	local function milestoneX(index: number): number
		local count = math.max(1, #PlayBuilderConfig.Milestones)
		if count <= 1 then return .5 end
		return .03 + ((index - 1) / (count - 1)) * .94
	end
	for index, milestone in PlayBuilderConfig.Milestones do
		local xScale = milestoneX(index)
		local node = Instance.new("Frame")
		node.BackgroundColor3 = Color3.fromHex("0D121C")
		node.BorderSizePixel = 0
		node.Position = UDim2.new(xScale, -18, 0, 54)
		node.Size = UDim2.fromOffset(36, 36)
		node.Parent = milestones
		Instance.new("UICorner", node).CornerRadius = UDim.new(1, 0)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Colors.Electric
		stroke.Transparency = .55
		stroke.Parent = node
		local lvl = text(node, "LVL " .. tostring(milestone.Level), UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 16), 8, Theme.Colors.White, Theme.Fonts.Display)
		lvl.TextXAlignment = Enum.TextXAlignment.Center
		local rewardWidth = 120
		local rewardOffset = -60
		if index == 1 then
			rewardWidth = 96
			rewardOffset = -30
		elseif index == #PlayBuilderConfig.Milestones then
			rewardWidth = 96
			rewardOffset = -66
		end
		local reward = text(milestones, milestone.Reward, UDim2.new(xScale, rewardOffset, 0, 102), UDim2.fromOffset(rewardWidth, 18), 8, Theme.Colors.Muted, Theme.Fonts.Body)
		reward.TextXAlignment = Enum.TextXAlignment.Center
		local hereOffset = -62
		local hereWidth = 124
		if index == 1 then
			hereOffset = -30
			hereWidth = 96
		elseif index == #PlayBuilderConfig.Milestones then
			hereOffset = -82
			hereWidth = 112
		end
		local here = text(milestones, "YOU ARE HERE", UDim2.new(xScale, hereOffset, 0, 120), UDim2.fromOffset(hereWidth, 16), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
		here.TextXAlignment = Enum.TextXAlignment.Center
		here.Visible = false
		local check = text(milestones, "✓", UDim2.new(xScale, -10, 0, 95), UDim2.fromOffset(20, 16), 12, VOLTRA_GREEN, Theme.Fonts.Strong)
		check.TextXAlignment = Enum.TextXAlignment.Center
		check.Visible = false
		table.insert(milestoneNodes, {Frame = node, Stroke = stroke, Reward = reward, Here = here, Check = check})
	end

	local function render()
		builder = PlayBuilderConfig.Normalize(builder, builder.Level)
		local archetype = PlayBuilderConfig.Archetypes[builder.Archetype]
		local stats = PlayBuilderConfig.StatsFor(builder)
		local accent = Color3.fromHex(archetype.Color)
		previewStroke.Color = accent
		ovr.Text = "OVR " .. tostring(stats.overall)
		previewName.Text = string.upper(archetype.Title)
		summary.Text = "LEVEL " .. tostring(builder.Level) .. "  |  " .. tostring(builder.AttributePointsAvailable) .. " ATTRIBUTE POINTS  |  " .. tostring(builder.TraitPointsAvailable) .. " TRAIT POINTS"
		pointLabel.Text = tostring(builder.AttributePointsAvailable) .. " AVAILABLE"
		traitPointLabel.Text = tostring(builder.TraitPointsAvailable) .. " AVAILABLE"
		for id, button in archetypeButtons do
			local selected = id == builder.Archetype
			button.BackgroundColor3 = selected and Color3.fromHex("161E2B") or Color3.fromHex("101522")
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = selected and accent or Color3.fromHex("273043")
				stroke.Transparency = selected and .05 or .18
			end
		end
		for _, entry in PlayBuilderConfig.AttributeOrder do
			local key = tostring(entry.Key)
			local row = rows[key]
			if row then
				local value = tonumber(stats[key]) or 70
				row.Fill.Size = UDim2.fromScale(math.clamp(value / 99, 0, 1), 1)
				row.Value.Text = tostring(value)
				row.Plus.Active = (tonumber(builder.AttributePointsAvailable) or 0) > 0 and value < 99
				row.Plus.AutoButtonColor = row.Plus.Active
				row.Plus.TextTransparency = row.Plus.Active and 0 or .55
			end
		end
		for id, traitButton in traitButtons do
			local level = tonumber(builder.Traits and builder.Traits[id]) or 0
			local data = PlayBuilderConfig.Traits[id]
			traitButton.Text = ""
			traitButton.BackgroundColor3 = TIER_COLORS[level] or TIER_COLORS[0]
			if traitTitles[id] then
				traitTitles[id].Text = string.upper(data.Title) .. "  " .. string.rep("I", level) .. string.rep("-", 3 - level)
				traitTitles[id].TextColor3 = level == 0 and Theme.Colors.White or Color3.fromHex("101010")
			end
			if traitDescriptions[id] then
				traitDescriptions[id].TextColor3 = level == 0 and Color3.fromHex("E7ECF8") or Color3.fromHex("151515")
			end
			local stroke = traitButton:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = level > 0 and TIER_COLORS[level] or Color3.fromHex("273043")
				stroke.Transparency = level > 0 and .05 or .18
			end
		end
		for index, milestone in PlayBuilderConfig.Milestones do
			local node = milestoneNodes[index]
			local unlocked = (tonumber(builder.Level) or 1) >= milestone.Level
			if node then
				local currentLevel = tonumber(builder.Level) or 1
				local nextMilestone = PlayBuilderConfig.Milestones[index + 1]
				local current = currentLevel >= milestone.Level and (not nextMilestone or currentLevel < nextMilestone.Level)
				node.Frame.BackgroundColor3 = current and Color3.fromHex("211438") or unlocked and Color3.fromHex("102116") or Color3.fromHex("0D121C")
				node.Stroke.Color = current and Color3.fromHex("A943FF") or unlocked and VOLTRA_GREEN or Theme.Colors.Silver
				node.Stroke.Thickness = current and 2 or 1
				node.Stroke.Transparency = current and .02 or unlocked and .08 or .45
				node.Reward.TextColor3 = current and Theme.Colors.Electric or Theme.Colors.Muted
				node.Here.Visible = current
				node.Check.Visible = unlocked and not current
			end
		end
		local currentLevel = tonumber(builder.Level) or 1
		local firstLevel = PlayBuilderConfig.Milestones[1].Level
		local lastLevel = PlayBuilderConfig.Milestones[#PlayBuilderConfig.Milestones].Level
		local progress = math.clamp((currentLevel - firstLevel) / math.max(1, lastLevel - firstLevel), 0, 1)
		railFill.Size = UDim2.fromScale(progress, 1)
	end
	rows.__render = render

	render()
	return group
end

return Page
