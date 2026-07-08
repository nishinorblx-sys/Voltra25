local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VTR = ReplicatedStorage:WaitForChild("VTR", 15)
local Shared = VTR:WaitForChild("Shared")
local ClubIdentityConfig = require(Shared:WaitForChild("ClubIdentityConfig"))

local KitPreview = {}

local function toColor3(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end

	if type(value) == "string" then
		local hex = string.gsub(value, "#", "")
		if string.match(hex, "^%x%x%x%x%x%x$") then
			return Color3.fromRGB(
				tonumber(string.sub(hex, 1, 2), 16),
				tonumber(string.sub(hex, 3, 4), 16),
				tonumber(string.sub(hex, 5, 6), 16)
			)
		end
	end

	if type(value) == "table" then
		local nestedColor = value.Color or value.color or value.Color3 or value.Hex or value.hex
		if nestedColor ~= nil and nestedColor ~= value then
			return toColor3(nestedColor, fallback)
		end

		local red = value.R or value.r or value[1]
		local green = value.G or value.g or value[2]
		local blue = value.B or value.b or value[3]
		if type(red) == "number" and type(green) == "number" and type(blue) == "number" then
			if red <= 1 and green <= 1 and blue <= 1 then
				return Color3.new(red, green, blue)
			end
			return Color3.fromRGB(red, green, blue)
		end
	end

	return fallback
end

local function resolveColor(value, fallback)
	local succeeded, resolved = pcall(ClubIdentityConfig.ResolveColor, value)
	if not succeeded then
		resolved = value
	end
	return toColor3(resolved, toColor3(value, fallback))
end

local function frame(parent, name, position, size, color, zIndex)
	local object = Instance.new("Frame")
	object.Name = name
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = position
	object.Size = size
	object.BackgroundColor3 = color
	object.BorderSizePixel = 0
	object.ZIndex = zIndex or 1
	object.Parent = parent
	return object
end

local function rounded(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

local function addRotatedBand(parent, color, position, size, rotation, zIndex)
	local band = frame(parent, "PatternBand", position, size, color, zIndex)
	band.Rotation = rotation
	return band
end

local function addKitText(parent, name, textValue, position, size, color, textSize, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = textValue
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.ZIndex = zIndex or 8
	label.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize
	constraint.MinTextSize = 4
	constraint.Parent = label
	return label
end

local function addVoltraMarks(torso, accent, showWordmark)
	addKitText(torso, "VoltraBolt", "V", UDim2.fromScale(0.79, 0.18), UDim2.fromScale(0.14, 0.14), accent, 22, 8)
	addKitText(torso, "VoltraSpark", "Z", UDim2.fromScale(0.21, 0.20), UDim2.fromScale(0.10, 0.10), accent, 14, 8)
	if showWordmark then
		addKitText(torso, "VoltraWordmark", "VOLTRA", UDim2.fromScale(0.5, 0.37), UDim2.fromScale(0.52, 0.11), accent, 16, 8)
	end
end

local function addTorsoPattern(torso, style, primary, secondary, accent)
	-- Every pattern object is deliberately parented to this clipped torso mask.
	if style == "Vertical Stripes" then
		for index = 1, 5 do
			local stripe = frame(torso, "Stripe", UDim2.fromScale((index - 0.5) / 5, 0.5), UDim2.fromScale(0.1, 1.1), secondary, 3)
			stripe.BackgroundTransparency = index % 2 == 0 and 0.18 or 0
		end
	elseif style == "Horizontal Stripes" or style == "Hoops" then
		for index = 1, 5 do
			frame(torso, "Hoop", UDim2.fromScale(0.5, index / 6), UDim2.fromScale(1.1, 0.1), secondary, 3)
		end
	elseif style == "Diagonal Sash" then
		addRotatedBand(torso, secondary, UDim2.fromScale(0.43, 0.53), UDim2.fromScale(0.13, 0.98), -32, 3)
		addRotatedBand(torso, accent, UDim2.fromScale(0.46, 0.53), UDim2.fromScale(0.025, 0.98), -32, 4)
		addRotatedBand(torso, secondary, UDim2.fromScale(0.60, 0.55), UDim2.fromScale(0.022, 0.9), -32, 4)
	elseif style == "Split" then
		frame(torso, "SplitHalf", UDim2.fromScale(0.75, 0.5), UDim2.fromScale(0.5, 1.05), secondary, 3)
	elseif style == "Lightning Trim" then
		-- A connected bolt silhouette, kept narrow and controlled inside the chest.
		addRotatedBand(torso, accent, UDim2.fromScale(0.34, 0.24), UDim2.fromScale(0.055, 0.5), 28, 4)
		addRotatedBand(torso, accent, UDim2.fromScale(0.48, 0.48), UDim2.fromScale(0.055, 0.42), -38, 4)
		addRotatedBand(torso, accent, UDim2.fromScale(0.39, 0.72), UDim2.fromScale(0.055, 0.44), 30, 4)
	elseif style == "Volt Pattern" then
		for index = 0, 3 do
			addRotatedBand(torso, index % 2 == 0 and secondary or accent, UDim2.fromScale(0.2 + index * 0.2, 0.5), UDim2.fromScale(0.032, 0.95), index % 2 == 0 and 21 or -21, 3)
		end
		frame(torso, "VoltCore", UDim2.fromScale(0.5, 0.54), UDim2.fromScale(0.74, 0.055), accent, 4)
	elseif style == "Checker Accent" then
		local rows, columns = 6, 5
		for row = 1, rows do
			for column = 1, columns do
				if (row + column) % 2 == 0 then
					frame(torso, "Check", UDim2.fromScale((column - 0.5) / columns, (row - 0.5) / rows), UDim2.fromScale(1 / columns + 0.01, 1 / rows + 0.01), secondary, 3)
				end
			end
		end
	elseif style == "Chevron" then
		addRotatedBand(torso, secondary, UDim2.fromScale(0.39, 0.5), UDim2.fromScale(0.075, 1.0), -43, 3)
		addRotatedBand(torso, secondary, UDim2.fromScale(0.61, 0.5), UDim2.fromScale(0.075, 1.0), 43, 3)
		addRotatedBand(torso, accent, UDim2.fromScale(0.39, 0.55), UDim2.fromScale(0.024, 0.86), -43, 4)
		addRotatedBand(torso, accent, UDim2.fromScale(0.61, 0.55), UDim2.fromScale(0.024, 0.86), 43, 4)
	elseif style == "Racing Stripe" then
		frame(torso, "CenterStripe", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.16, 1.08), secondary, 3)
		frame(torso, "LeftPin", UDim2.fromScale(0.39, 0.5), UDim2.fromScale(0.025, 1.08), accent, 4)
		frame(torso, "RightPin", UDim2.fromScale(0.61, 0.5), UDim2.fromScale(0.025, 1.08), accent, 4)
	elseif style == "Volt Halves" then
		frame(torso, "HalfPanel", UDim2.fromScale(0.25, 0.5), UDim2.fromScale(0.5, 1.08), secondary, 3)
		addRotatedBand(torso, accent, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.032, 0.96), -18, 4)
		addRotatedBand(torso, accent, UDim2.fromScale(0.58, 0.45), UDim2.fromScale(0.035, 0.52), 35, 4)
	elseif style == "Voltra Founder" then
		addRotatedBand(torso, Color3.fromRGB(18, 18, 18), UDim2.fromScale(0.34, 0.36), UDim2.fromScale(0.055, 0.72), -48, 3)
		addRotatedBand(torso, Color3.fromRGB(18, 18, 18), UDim2.fromScale(0.66, 0.36), UDim2.fromScale(0.055, 0.72), 48, 3)
		addRotatedBand(torso, Color3.fromRGB(35, 35, 35), UDim2.fromScale(0.37, 0.48), UDim2.fromScale(0.045, 0.66), -48, 4)
		addRotatedBand(torso, Color3.fromRGB(35, 35, 35), UDim2.fromScale(0.63, 0.48), UDim2.fromScale(0.045, 0.66), 48, 4)
		addRotatedBand(torso, accent, UDim2.fromScale(0.18, 0.56), UDim2.fromScale(0.025, 0.72), 0, 5)
		addRotatedBand(torso, accent, UDim2.fromScale(0.82, 0.56), UDim2.fromScale(0.025, 0.72), 0, 5)
		frame(torso, "FounderLowerTrim", UDim2.fromScale(0.5, 0.92), UDim2.fromScale(1.05, 0.055), accent, 5)
		addVoltraMarks(torso, accent, true)
	elseif style == "Voltra Limited" then
		addRotatedBand(torso, Color3.fromRGB(15, 15, 15), UDim2.fromScale(0.47, 0.58), UDim2.fromScale(0.028, 0.98), -26, 3)
		addRotatedBand(torso, Color3.fromRGB(20, 20, 20), UDim2.fromScale(0.57, 0.54), UDim2.fromScale(0.022, 0.9), -26, 3)
		addRotatedBand(torso, accent, UDim2.fromScale(0.16, 0.56), UDim2.fromScale(0.022, 0.72), 0, 5)
		addRotatedBand(torso, accent, UDim2.fromScale(0.84, 0.56), UDim2.fromScale(0.022, 0.72), 0, 5)
		frame(torso, "LimitedBottomTrim", UDim2.fromScale(0.5, 0.93), UDim2.fromScale(1.05, 0.045), accent, 5)
		addVoltraMarks(torso, accent, false)
	elseif style == "Voltra Lightning" then
		for index = 0, 4 do
			local y = 0.18 + index * 0.17
			addRotatedBand(torso, Color3.fromRGB(22, 22, 22), UDim2.fromScale(0.5, y), UDim2.fromScale(0.028, 1.18), -64, 3)
			addRotatedBand(torso, accent, UDim2.fromScale(0.32 + (index % 2) * 0.22, y + 0.04), UDim2.fromScale(0.026, 0.72), -42 + index * 8, 5)
		end
		addRotatedBand(torso, accent, UDim2.fromScale(0.48, 0.55), UDim2.fromScale(0.055, 1.24), -36, 6)
		addRotatedBand(torso, Color3.fromRGB(230, 255, 120), UDim2.fromScale(0.48, 0.55), UDim2.fromScale(0.018, 1.20), -36, 7)
		addVoltraMarks(torso, accent, false)
	elseif style == "Voltra Gradient" then
		torso.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(3, 3, 3)),
			ColorSequenceKeypoint.new(0.42, Color3.fromRGB(10, 12, 8)),
			ColorSequenceKeypoint.new(0.72, Color3.fromRGB(45, 64, 18)),
			ColorSequenceKeypoint.new(1, accent),
		})
		gradient.Rotation = 90
		gradient.Parent = torso
		local lowerBloom = frame(torso, "GradientLowerBloom", UDim2.fromScale(0.5, 0.78), UDim2.fromScale(1.15, 0.42), accent, 3)
		lowerBloom.BackgroundTransparency = 0.34
		local bloomGradient = Instance.new("UIGradient")
		bloomGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		bloomGradient.Rotation = 90
		bloomGradient.Parent = lowerBloom
		for index = 1, 6 do
			addRotatedBand(torso, Color3.fromRGB(30, 38, 22), UDim2.fromScale(index / 7, 0.62), UDim2.fromScale(0.012, 0.95), -18, 4).BackgroundTransparency = 0.35
		end
		addRotatedBand(torso, accent, UDim2.fromScale(0.16, 0.58), UDim2.fromScale(0.022, 0.74), 0, 5)
		addRotatedBand(torso, accent, UDim2.fromScale(0.84, 0.58), UDim2.fromScale(0.022, 0.74), 0, 5)
		local hem = frame(torso, "GradientBottomGlow", UDim2.fromScale(0.5, 0.92), UDim2.fromScale(1.1, 0.08), accent, 5)
		hem.BackgroundTransparency = 0.08
		addVoltraMarks(torso, accent, false)
	end
end

local function addSleeve(parent, name, position, rotation, primary, secondary, accent, style)
	local sleeve = frame(parent, name, position, UDim2.fromScale(0.25, 0.23), style == "Voltra Gradient" and secondary or primary, 2)
	sleeve.Rotation = rotation
	sleeve.ClipsDescendants = true
	rounded(sleeve, 5)

	-- Sleeve trim is separate from chest artwork and follows the sleeve container.
	if style == "Lightning Trim" or style == "Volt Pattern" or style == "Volt Halves" or string.sub(style, 1, 6) == "Voltra" then
		frame(sleeve, "SleeveTrim", UDim2.fromScale(0.5, 0.82), UDim2.fromScale(1.1, 0.16), accent, 3)
	elseif style == "Vertical Stripes" or style == "Hoops" or style == "Horizontal Stripes" or style == "Racing Stripe" or style == "Chevron" then
		frame(sleeve, "SleeveTrim", UDim2.fromScale(0.5, 0.82), UDim2.fromScale(1.1, 0.13), secondary, 3)
	end
	return sleeve
end

local function addAnimatedLightningOverlay(parent, accent)
	local overlay = Instance.new("Frame")
	overlay.Name = "AnimatedLightningOverlay"
	overlay.AnchorPoint = Vector2.new(0.5, 0)
	overlay.BackgroundTransparency = 1
	overlay.ClipsDescendants = false
	overlay.Position = UDim2.fromScale(0.5, 0.03)
	overlay.Size = UDim2.fromScale(0.72, 0.48)
	overlay.ZIndex = 18
	overlay.Parent = parent

	local function bolt(name, position, size, rotation, transparency)
		local part = frame(overlay, name, position, size, accent, 19)
		part.BackgroundTransparency = transparency or 0.05
		part.Rotation = rotation
		return part
	end

	local bolts = {
		bolt("BoltMainGlow", UDim2.fromScale(0.50, 0.55), UDim2.fromScale(0.075, 1.34), -35, 0.18),
		bolt("BoltMainCore", UDim2.fromScale(0.50, 0.55), UDim2.fromScale(0.024, 1.28), -35, 0),
		bolt("BoltTopFork", UDim2.fromScale(0.31, 0.28), UDim2.fromScale(0.032, 0.62), -64, 0.04),
		bolt("BoltLowerFork", UDim2.fromScale(0.68, 0.76), UDim2.fromScale(0.032, 0.62), -66, 0.04),
	}

	task.spawn(function()
		local index = 0
		while overlay.Parent do
			index += 1
			for order, boltPart in bolts do
				boltPart.BackgroundTransparency = order == 1 and 0.36 or 0.18
				local xOffset = (index % 2 == 0 and 0.02 or -0.02) + order * 0.003
				local target = {
					Position = boltPart.Position + UDim2.fromScale(xOffset, 0),
					BackgroundTransparency = order == 1 and 0.08 or 0,
				}
				TweenService:Create(boltPart, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), target):Play()
			end
			task.wait(0.38)
			for order, boltPart in bolts do
				TweenService:Create(boltPart, TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Position = order <= 2 and UDim2.fromScale(0.50, 0.55) or order == 3 and UDim2.fromScale(0.31, 0.28) or UDim2.fromScale(0.68, 0.76),
					BackgroundTransparency = order == 1 and 0.22 or 0.08,
				}):Play()
			end
			task.wait(0.5)
		end
	end)
end

function KitPreview.new(parent, identity, size)
	identity = identity or {}
	local primary = resolveColor(identity.PrimaryColor or identity.primaryColor, Color3.fromRGB(183, 255, 26))
	local secondary = resolveColor(identity.SecondaryColor or identity.secondaryColor, Color3.fromRGB(17, 17, 17))
	local accent = resolveColor(identity.AccentColor or identity.accentColor, Color3.fromRGB(217, 217, 217))
	local style = identity.KitStyle or identity.kitStyle or "Solid"

	local root = Instance.new("Frame")
	root.Name = "KitPreview"
	root.Size = size or UDim2.fromOffset(220, 260)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = parent

	local kit = Instance.new("Frame")
	kit.Name = "GarmentArea"
	kit.AnchorPoint = Vector2.new(0.5, 0)
	kit.Position = UDim2.fromScale(0.5, 0.025)
	kit.Size = UDim2.fromScale(0.88, 0.94)
	kit.BackgroundTransparency = 1
	kit.Parent = root

	addSleeve(kit, "LeftSleeve", UDim2.fromScale(0.19, 0.20), -18, primary, secondary, accent, style)
	addSleeve(kit, "RightSleeve", UDim2.fromScale(0.81, 0.20), 18, primary, secondary, accent, style)

	local torso = frame(kit, "ShirtBodyMask", UDim2.fromScale(0.5, 0.29), UDim2.fromScale(0.56, 0.43), primary, 2)
	torso.ClipsDescendants = true
	rounded(torso, 7)
	addTorsoPattern(torso, style, primary, secondary, accent)
	if style == "Voltra Lightning" then
		addAnimatedLightningOverlay(kit, accent)
	end

	local collar = frame(kit, "Collar", UDim2.fromScale(0.5, 0.095), UDim2.fromScale(0.17, 0.055), secondary, 6)
	rounded(collar, 10)
	local collarInset = frame(collar, "Inset", UDim2.fromScale(0.5, 0.6), UDim2.fromScale(0.58, 0.7), Color3.fromRGB(12, 12, 12), 7)
	rounded(collarInset, 8)

	-- The lower kit occupies its own rail so it cannot collide with external labels.
	local shorts = frame(kit, "Shorts", UDim2.fromScale(0.5, 0.61), UDim2.fromScale(0.42, 0.20), secondary, 2)
	shorts.ClipsDescendants = true
	rounded(shorts, 5)
	frame(shorts, "ShortsTrim", UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.9, 0.08), accent, 3)

	local leftSock = frame(kit, "LeftSock", UDim2.fromScale(0.405, 0.82), UDim2.fromScale(0.13, 0.23), primary, 2)
	local rightSock = frame(kit, "RightSock", UDim2.fromScale(0.595, 0.82), UDim2.fromScale(0.13, 0.23), primary, 2)
	rounded(leftSock, 4)
	rounded(rightSock, 4)
	frame(leftSock, "SockTrim", UDim2.fromScale(0.5, 0.13), UDim2.fromScale(1, 0.1), accent, 3)
	frame(rightSock, "SockTrim", UDim2.fromScale(0.5, 0.13), UDim2.fromScale(1, 0.1), accent, 3)

	return root
end

return KitPreview
