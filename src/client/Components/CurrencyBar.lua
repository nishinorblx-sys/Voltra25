--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local AnimatedNumber = require(script.Parent.AnimatedNumber)

local CurrencyBar = {}

function CurrencyBar.new(currencies: { any }): Frame
	local frame = Instance.new("Frame")
	frame.Name = "CurrencyBar"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(210, 44)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 18)
	layout.Parent = frame

	for _, currency in currencies do
		local holder = Instance.new("Frame")
		holder.AutomaticSize = Enum.AutomaticSize.X
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(0, 44)
		holder.Parent = frame

		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.Padding = UDim.new(0, 6)
		row.Parent = holder

		local prefix = tostring(currency.Icon or "")
		if currency.IconImage then
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Image = tostring(currency.IconImage)
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Size = UDim2.fromOffset(22, 22)
			icon.Parent = holder
			prefix = ""
		end

		local label = Instance.new("TextLabel")
		label.AutomaticSize = Enum.AutomaticSize.X
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(0, 44)
		label.Text = prefix ~= "" and (prefix .. "  " .. tostring(currency.Value)) or tostring(currency.Value)
		label.TextColor3 = currency.Color or Theme.Colors.Silver
		label.TextSize = 11
		label.Font = Theme.Fonts.Strong
		label.Parent = holder
		if type(currency.Value) == "number" then
			task.defer(function() if label.Parent then AnimatedNumber.play(label, currency.Value, { Prefix = prefix ~= "" and (prefix .. "  ") or "" }) end end)
		end
	end

	return frame
end

return CurrencyBar
