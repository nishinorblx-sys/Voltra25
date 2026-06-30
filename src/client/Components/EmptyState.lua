--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local EmptyState = {}

function EmptyState.new(titleText: string, descriptionText: string, iconText: string?): Frame
	local frame = Instance.new("Frame")
	frame.Name = "EmptyState"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame
	for index, data in {
		{ iconText or "◇", 28, Theme.Colors.Electric, Theme.Fonts.Display },
		{ string.upper(titleText), 11, Theme.Colors.White, Theme.Fonts.Strong },
		{ descriptionText, 9, Theme.Colors.Muted, Theme.Fonts.Body },
	} do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = index
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -24, 0, index == 1 and 34 or 20)
		label.Text = data[1]
		label.TextColor3 = data[3]
		label.TextSize = data[2]
		label.Font = data[4]
		label.TextWrapped = true
		label.Parent = frame
	end
	return frame
end

return EmptyState
