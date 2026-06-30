--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Button = require(script.Parent.Button)

local ErrorState = {}

function ErrorState.new(parent: Instance, message: string, retry: () -> ()): Frame
	local frame = Instance.new("Frame")
	frame.Name = "ErrorState"
	frame.BackgroundColor3 = Theme.Colors.Black
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 100
	frame.Parent = parent
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.fromOffset(500, 50)
	title.Text = "CONNECTION INTERRUPTED"
	title.TextColor3 = Theme.Colors.White
	title.TextSize = 25
	title.Font = Theme.Fonts.Display
	title.ZIndex = 101
	title.Parent = frame
	local copy = title:Clone()
	copy.Position = UDim2.fromScale(0.5, 0.49)
	copy.Size = UDim2.fromOffset(500, 42)
	copy.Text = message
	copy.TextColor3 = Theme.Colors.Muted
	copy.TextSize = 10
	copy.Font = Theme.Fonts.Body
	copy.TextWrapped = true
	copy.Parent = frame
	local button = Button.new({ Text = "RETRY CONNECTION", Variant = "Primary", OnActivated = retry })
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.fromScale(0.5, 0.55)
	button.ZIndex = 101
	button.Parent = frame
	return frame
end

return ErrorState
