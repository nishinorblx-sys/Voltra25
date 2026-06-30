--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local BackgroundEffects = {}

function BackgroundEffects.new(parent: Instance): Frame
	local holder = Instance.new("Frame")
	holder.Name = "BackgroundEnergy"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ClipsDescendants = true
	holder.Parent = parent
	local shapes = {
		{ UDim2.fromScale(0.72, 0.18), UDim2.fromScale(0.48, 0.08), -19, 0.86, 7.5 },
		{ UDim2.fromScale(0.78, 0.58), UDim2.fromScale(0.58, 0.035), -19, 0.9, 9.5 },
		{ UDim2.fromScale(0.34, 0.82), UDim2.fromScale(0.3, 0.025), 16, 0.94, 11 },
	}
	for index, info in shapes do
		local shape = Instance.new("Frame")
		shape.Name = "EnergyShape" .. index
		shape.AnchorPoint = Vector2.new(0.5, 0.5)
		shape.BackgroundColor3 = Theme.Colors.Electric
		shape.BackgroundTransparency = info[4]
		shape.BorderSizePixel = 0
		shape.Position = info[1]
		shape.Size = info[2]
		shape.Rotation = info[3]
		shape.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = shape
		local target = UDim2.new(info[1].X.Scale + 0.045, 0, info[1].Y.Scale + 0.025, 0)
		TweenService:Create(shape, TweenInfo.new(info[5], Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = target, BackgroundTransparency = math.max(0.76, info[4] - 0.045) }):Play()
	end
	return holder
end

return BackgroundEffects
