--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local AnimatedNumber = require(script.Parent.AnimatedNumber)

local StatCard = {}

function StatCard.new(labelText: string, valueText: any, accent: boolean?): Frame
	local frame = Instance.new("Frame")
	frame.Name = labelText:gsub("%W", "") .. "Stat"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Size = UDim2.new(1, 0, 0.58, 0)
	value.Text = tostring(valueText)
	value.TextColor3 = accent and Theme.Colors.White or Theme.Colors.White
	value.TextSize = 24
	value.Font = Theme.Fonts.Display
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = frame
	if type(valueText) == "number" then task.defer(function() if value.Parent then AnimatedNumber.play(value, valueText) end end) end

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, 0.58)
	label.Size = UDim2.new(1, 0, 0.34, 0)
	label.Text = string.upper(labelText)
	label.TextColor3 = Theme.Colors.Muted
	label.TextSize = 9
	label.Font = Theme.Fonts.Strong
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	return frame
end

return StatCard
