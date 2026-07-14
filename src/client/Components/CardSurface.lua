--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CardVisualConfig = require(ReplicatedStorage.VTR.Shared.CardVisualConfig)
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local CardSurface = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

function CardSurface.apply(root: GuiObject, rarity: string?, cardType: string?, radius: number?): any
	local visual = CardVisualConfig.Get(rarity, cardType)
	root.BackgroundColor3 = visual.primaryColor
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	corner(root, radius or 8)

	local gradient = Instance.new("UIGradient")
	gradient.Name = "CardGradient"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, visual.primaryColor),
		ColorSequenceKeypoint.new(0.56, visual.secondaryColor),
		ColorSequenceKeypoint.new(1, visual.primaryColor:Lerp(Color3.new(), 0.35)),
	})
	gradient.Rotation = 125
	gradient.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Name = "RarityBorder"
	stroke.Color = visual.trimColor
	stroke.Thickness = visual.borderStyle == "Electric" and 2 or 1
	stroke.Transparency = visual.borderStyle == "Single" and 0.25 or 0.05
	stroke.Parent = root
	if visual.borderStyle == "Double" or visual.borderStyle == "Electric" then
		local inner = Instance.new("Frame")
		inner.Name = "InnerBorder"
		inner.BackgroundTransparency = 1
		inner.Position = UDim2.fromOffset(3, 3)
		inner.Size = UDim2.new(1, -6, 1, -6)
		inner.ZIndex = root.ZIndex + 1
		inner.Parent = root
		corner(inner, math.max(3, (radius or 8) - 3))
		local innerStroke = Instance.new("UIStroke")
		innerStroke.Color = visual.glowColor
		innerStroke.Thickness = 1
		innerStroke.Transparency = 0.58
		innerStroke.Parent = inner
	end

	if visual.backgroundPattern ~= "None" and visual.backgroundPattern ~= "Matte" then
		local pattern = Instance.new("Frame")
		pattern.Name = "CardPattern_" .. visual.backgroundPattern
		pattern.AnchorPoint = Vector2.new(0.5, 0.5)
		pattern.BackgroundColor3 = visual.trimColor
		pattern.BackgroundTransparency = 0.86
		pattern.BorderSizePixel = 0
		pattern.Position = UDim2.fromScale(0.76, 0.44)
		pattern.Rotation = visual.backgroundPattern == "Lightning" and -18 or 24
		pattern.Size = UDim2.fromScale(0.32, 1.4)
		pattern.ZIndex = root.ZIndex + 1
		pattern.Parent = root
	end

	if visual.shineIntensity > 0 then
		local shine = Instance.new("Frame")
		shine.Name = "CardShine"
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.BackgroundTransparency = math.clamp(0.96 - visual.shineIntensity * 0.17, 0.78, 0.96)
		shine.BorderSizePixel = 0
		shine.Position = UDim2.fromScale(-0.35, 0.5)
		shine.Rotation = 18
		shine.Size = UDim2.fromScale(0.16, 1.6)
		shine.ZIndex = root.ZIndex + 2
		shine.Parent = root
		if visual.animationStyle ~= "None" then
			local duration = visual.animationStyle == "Lightning" and 1.4 or 2.7
			local tween = TweenService:Create(shine, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.45), { Position = UDim2.fromScale(1.35, 0.5) })
			tween:Play()
		end
	end
	if visual.effectStyle and visual.effectStyle ~= "None" then
		local glow = Instance.new("Frame")
		glow.Name = "CardTypeEffect_" .. tostring(visual.effectStyle)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.BackgroundColor3 = visual.glowColor
		glow.BackgroundTransparency = 0.9
		glow.BorderSizePixel = 0
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromScale(1.06, 1.08)
		glow.ZIndex = root.ZIndex + 1
		glow.Parent = root
		corner(glow, radius or 8)
		local glowStroke = Instance.new("UIStroke")
		glowStroke.Color = visual.glowColor
		glowStroke.Thickness = visual.effectStyle == "BurningElectric" and 2 or 1
		glowStroke.Transparency = 0.62
		glowStroke.Parent = glow
		if visual.effectStyle == "BurningElectric" or visual.effectStyle == "MagentaLightning" or visual.effectStyle == "EmberVolt" then
			for index = 1, 3 do
				local bolt = Instance.new("Frame")
				bolt.Name = "EnergySlash" .. index
				bolt.AnchorPoint = Vector2.new(0.5, 0.5)
				bolt.BackgroundColor3 = index == 1 and visual.trimColor or visual.glowColor
				bolt.BackgroundTransparency = index == 1 and 0.62 or 0.76
				bolt.BorderSizePixel = 0
				bolt.Position = UDim2.fromScale(0.18 + index * 0.2, 0.2 + (index % 2) * 0.42)
				bolt.Rotation = index % 2 == 0 and -26 or 24
				bolt.Size = UDim2.fromScale(0.04, 0.62)
				bolt.ZIndex = root.ZIndex + 2
				bolt.Parent = root
				TweenService:Create(bolt, TweenInfo.new(1.1 + index * 0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.9, Position = bolt.Position + UDim2.fromScale(0.04, -0.03) }):Play()
			end
		elseif visual.effectStyle == "Starburst" or visual.effectStyle == "PrismSparks" then
			for index = 1, 4 do
				local ray = Instance.new("Frame")
				ray.Name = "StarRay" .. index
				ray.AnchorPoint = Vector2.new(0.5, 0.5)
				ray.BackgroundColor3 = visual.trimColor
				ray.BackgroundTransparency = 0.82
				ray.BorderSizePixel = 0
				ray.Position = UDim2.fromScale(0.72, 0.34)
				ray.Rotation = index * 45
				ray.Size = UDim2.fromScale(0.035, 0.58)
				ray.ZIndex = root.ZIndex + 2
				ray.Parent = root
			end
		elseif visual.effectStyle == "GoldFloodlight" then
			local beam = Instance.new("Frame")
			beam.Name = "GoldFloodlightBeam"
			beam.AnchorPoint = Vector2.new(0.5, 0.5)
			beam.BackgroundColor3 = visual.trimColor
			beam.BackgroundTransparency = 0.84
			beam.BorderSizePixel = 0
			beam.Position = UDim2.fromScale(0.62, 0.5)
			beam.Rotation = -18
			beam.Size = UDim2.fromScale(0.3, 1.4)
			beam.ZIndex = root.ZIndex + 1
			beam.Parent = root
		end
		TweenService:Create(glowStroke, TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.28 }):Play()
	end
	return visual
end

function CardSurface.decorateAscension(root: GuiObject, card: any, layout: string?)
	local meta = type(card) == "table" and (card.Meta or card) or {}
	local progression = type(meta.CampaignProgression) == "table" and meta.CampaignProgression or {}
	local variant = card.CampaignVariant or meta.CampaignVariant or progression.CampaignVariant
	if variant ~= "Ascension" then return end
	local visualTier = card.CampaignVisualTier or meta.CampaignVisualTier or progression.VisualTier
	local shade = Instance.new("Frame")
	shade.Name = "AscensionShade"
	shade.BackgroundColor3 = Theme.Colors.Graphite
	shade.BackgroundTransparency = 0.7
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = root.ZIndex + 2
	shade.Parent = root
	local shadeGradient = Instance.new("UIGradient")
	shadeGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.62, 0.58), NumberSequenceKeypoint.new(1, 0.82) })
	shadeGradient.Rotation = 115
	shadeGradient.Parent = shade
	local edge = Instance.new("Frame")
	edge.Name = "AscensionEdge"
	edge.BackgroundColor3 = Theme.Colors.Electric
	edge.BorderSizePixel = 0
	edge.Position = UDim2.fromOffset(0, 3)
	edge.Size = UDim2.new(0, visualTier == "AscendedII" and 4 or 2, 1, -6)
	edge.ZIndex = root.ZIndex + 8
	edge.Parent = root
	local border = Instance.new("UIStroke")
	border.Name = "AscensionBorder"
	border.Color = Theme.Colors.Electric
	border.Thickness = visualTier == "AscendedII" and 2.5 or 1.5
	border.Transparency = visualTier and 0.08 or 0.28
	border.Parent = root
	local tag = Instance.new("TextLabel")
	tag.Name = "AscensionLabel"
	tag.BackgroundColor3 = Theme.Colors.Black
	tag.BackgroundTransparency = 0.18
	tag.BorderSizePixel = 0
	tag.Text = "ASCENSION"
	tag.TextColor3 = visualTier == "AscendedII" and Theme.Colors.White or Theme.Colors.Electric
	tag.TextSize = layout == "Compact" and 5 or 6
	tag.Font = Theme.Fonts.Strong
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.ZIndex = root.ZIndex + 9
	if layout == "Wide" then
		tag.Position = UDim2.fromOffset(140, 94)
		tag.Size = UDim2.fromOffset(96, 12)
	elseif layout == "Horizontal" then
		tag.Position = UDim2.fromOffset(51, 54)
		tag.Size = UDim2.new(1, -59, 0, 10)
	else
		tag.Position = UDim2.fromOffset(5, 53)
		tag.Size = UDim2.new(1, -10, 0, 10)
	end
	tag.Parent = root
	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = UDim.new(0, 3)
	tagCorner.Parent = tag
	if visualTier and workspace:GetAttribute("VTRReducedMotion") ~= true then
		TweenService:Create(border, TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = visualTier == "AscendedII" and 0.34 or 0.48 }):Play()
	end
end

return CardSurface
