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
		local label = Instance.new("TextLabel")
		label.AutomaticSize = Enum.AutomaticSize.X
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(0, 44)
		label.Text = currency.Icon .. "  " .. tostring(currency.Value)
		label.TextColor3 = currency.Color or Theme.Colors.Silver
		label.TextSize = 11
		label.Font = Theme.Fonts.Strong
		label.Parent = frame
		if type(currency.Value) == "number" then
			task.defer(function() if label.Parent then AnimatedNumber.play(label, currency.Value, { Prefix = currency.Icon .. "  " }) end end)
		end
	end

	return frame
end

return CurrencyBar
