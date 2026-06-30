local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.VTR25.Theme)
local C = Theme.Colors

local Components = {}

local function make(className, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	return instance
end

Components.make = make

function Components.corner(radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius.Medium) })
end

function Components.stroke(color, transparency, thickness)
	return make("UIStroke", {
		Color = color or C.Border,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Components.padding(all)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all),
	})
end

function Components.label(text, size, color, font)
	return make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color or C.White,
		TextSize = size or 14,
		Font = font or Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
end

function Components.button(text, variant)
	local primary = variant == "Primary"
	local button = make("TextButton", {
		Name = text:gsub("%s", "") .. "Button",
		AutoButtonColor = false,
		BackgroundColor3 = primary and C.Electric or C.Gunmetal,
		Size = UDim2.fromOffset(primary and 176 or 144, 46),
		Text = string.upper(text),
		TextColor3 = primary and C.Black or C.White,
		TextSize = 12,
		Font = Theme.Fonts.Strong,
		BorderSizePixel = 0,
	}, { Components.corner(5), Components.stroke(primary and C.Electric or C.Border, primary and 0.3 or 0, 1) })

	local base = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(Theme.Motion.Fast), {
			BackgroundColor3 = primary and C.Neon or Color3.fromHex("282B24"),
			Size = UDim2.fromOffset((primary and 176 or 144) + 4, 48),
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(Theme.Motion.Fast), {
			BackgroundColor3 = base,
			Size = UDim2.fromOffset(primary and 176 or 144, 46),
		}):Play()
	end)
	return button
end

function Components.chip(text, active)
	return make("TextLabel", {
		BackgroundColor3 = active and C.Electric or C.Gunmetal,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		Text = "  " .. string.upper(text) .. "  ",
		TextColor3 = active and C.Black or C.Silver,
		TextSize = 10,
		Font = Theme.Fonts.Strong,
	}, { Components.corner(4), Components.stroke(active and C.Electric or C.Border, 0, 1) })
end

function Components.progress(value, color)
	local fill = make("Frame", {
		Name = "Fill", BackgroundColor3 = color or C.Electric,
		Size = UDim2.fromScale(math.clamp(value, 0, 1), 1), BorderSizePixel = 0,
	}, { Components.corner(3) })
	return make("Frame", {
		Name = "Progress", BackgroundColor3 = Color3.fromHex("2B2E29"),
		Size = UDim2.new(1, 0, 0, 6), BorderSizePixel = 0,
	}, { Components.corner(3), fill })
end

function Components.panel(name)
	return make("Frame", {
		Name = name or "Panel", BackgroundColor3 = C.Graphite,
		BorderSizePixel = 0, ClipsDescendants = true,
	}, { Components.corner(Theme.Radius.Large), Components.stroke(C.Border, 0.12, 1) })
end

function Components.stat(label, value, accent)
	local frame = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local valueLabel = Components.label(value, 24, accent and C.Electric or C.White, Theme.Fonts.Display)
	valueLabel.Size = UDim2.new(1, 0, 0.55, 0)
	local nameLabel = Components.label(string.upper(label), 9, C.Muted, Theme.Fonts.Strong)
	nameLabel.Position = UDim2.fromScale(0, 0.56)
	nameLabel.Size = UDim2.new(1, 0, 0.35, 0)
	valueLabel.Parent = frame
	nameLabel.Parent = frame
	return frame
end

function Components.playerCard(data)
	local card = make("Frame", {
		Name = "PlayerCard", BackgroundColor3 = Color3.fromHex("171A15"),
		Size = UDim2.fromOffset(218, 290), BorderSizePixel = 0, ClipsDescendants = true,
	}, { Components.corner(12), Components.stroke(C.Electric, 0.15, 2) })

	local glow = make("Frame", {
		BackgroundColor3 = C.Electric, BackgroundTransparency = 0.7,
		Position = UDim2.fromScale(0.46, -0.25), Size = UDim2.fromScale(0.85, 0.85),
		Rotation = 35, BorderSizePixel = 0,
	}, { Components.corner(100) })
	glow.Parent = card

	local rating = Components.label(tostring(data.rating), 38, C.Electric, Theme.Fonts.Display)
	rating.Position = UDim2.fromOffset(18, 17); rating.Size = UDim2.fromOffset(66, 46); rating.Parent = card
	local pos = Components.label(data.position, 12, C.White, Theme.Fonts.Strong)
	pos.Position = UDim2.fromOffset(21, 57); pos.Size = UDim2.fromOffset(60, 20); pos.Parent = card

	local silhouette = make("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(68, 48), Size = UDim2.fromOffset(142, 148),
		Text = "V", TextColor3 = C.Silver, TextTransparency = 0.08,
		TextSize = 132, Font = Theme.Fonts.Display,
	})
	silhouette.Parent = card

	local slash = make("Frame", {
		BackgroundColor3 = C.Electric, Position = UDim2.new(0, -20, 0, 185),
		Size = UDim2.new(1, 40, 0, 3), Rotation = -4, BorderSizePixel = 0,
	}); slash.Parent = card
	local playerName = Components.label(string.upper(data.name), 19, C.White, Theme.Fonts.Display)
	playerName.Position = UDim2.fromOffset(18, 196); playerName.Size = UDim2.new(1, -36, 0, 28); playerName.Parent = card
	local club = Components.label(data.club .. "  •  " .. data.nation, 9, C.Muted, Theme.Fonts.Strong)
	club.Position = UDim2.fromOffset(18, 225); club.Size = UDim2.new(1, -36, 0, 18); club.Parent = card

	local stats = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 252), Size = UDim2.new(1, -36, 0, 25) })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, Padding = UDim.new(0, 13) }).Parent = stats
	for _, stat in ipairs(data.stats) do
		local text = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 24), Text = stat[1] .. "\n" .. stat[2], TextColor3 = C.Silver, TextSize = 9, Font = Theme.Fonts.Strong })
		text.Parent = stats
	end
	stats.Parent = card
	return card
end

function Components.matchRow(home, away, time, status)
	local row = make("Frame", { BackgroundColor3 = C.Gunmetal, Size = UDim2.new(1, 0, 0, 60), BorderSizePixel = 0 }, { Components.corner(6) })
	local teams = Components.label(home .. "  VS  " .. away, 12, C.White, Theme.Fonts.Strong)
	teams.Position = UDim2.fromOffset(16, 6); teams.Size = UDim2.new(0.65, 0, 0, 26); teams.Parent = row
	local sub = Components.label(status, 9, C.Muted, Theme.Fonts.Body)
	sub.Position = UDim2.fromOffset(16, 31); sub.Size = UDim2.new(0.65, 0, 0, 18); sub.Parent = row
	local clock = Components.label(time, 12, C.Electric, Theme.Fonts.Strong)
	clock.Position = UDim2.new(0.7, 0, 0, 0); clock.Size = UDim2.new(0.25, 0, 1, 0); clock.TextXAlignment = Enum.TextXAlignment.Right; clock.Parent = row
	return row
end

return Components
