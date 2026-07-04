local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	end
end

local function addSleeve(parent, name, position, rotation, primary, secondary, accent, style)
	local sleeve = frame(parent, name, position, UDim2.fromScale(0.25, 0.23), primary, 2)
	sleeve.Rotation = rotation
	sleeve.ClipsDescendants = true
	rounded(sleeve, 5)

	-- Sleeve trim is separate from chest artwork and follows the sleeve container.
	if style == "Lightning Trim" or style == "Volt Pattern" or style == "Volt Halves" then
		frame(sleeve, "SleeveTrim", UDim2.fromScale(0.5, 0.82), UDim2.fromScale(1.1, 0.16), accent, 3)
	elseif style == "Vertical Stripes" or style == "Hoops" or style == "Horizontal Stripes" or style == "Racing Stripe" or style == "Chevron" then
		frame(sleeve, "SleeveTrim", UDim2.fromScale(0.5, 0.82), UDim2.fromScale(1.1, 0.13), secondary, 3)
	end
	return sleeve
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
