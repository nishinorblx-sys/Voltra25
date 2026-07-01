--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Panel = {}

export type Props = { Name: string?, Size: UDim2?, Position: UDim2?, Color: Color3?, ClipsDescendants: boolean? }

function Panel.new(props: Props?): Frame
	props = props or {}
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.BackgroundColor3 = props.Color or Theme.Colors.Graphite
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.ClipsDescendants = if props.ClipsDescendants == nil then true else props.ClipsDescendants
	frame.Active = true
	frame.Selectable = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.Large)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Border
	stroke.Transparency = 0.12
	stroke.Thickness = 1
	stroke.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.975
	scale.Parent = frame
	frame.BackgroundTransparency = 1
	task.defer(function()
		if not frame.Parent then return end
		TweenService:Create(scale, TweenInfo.new(Theme.Animation.Page, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), { Scale = 1 }):Play()
		TweenService:Create(frame, TweenInfo.new(Theme.Animation.Page), { BackgroundTransparency = 0.04 }):Play()
	end)
	local function glow(active: boolean)
		TweenService:Create(stroke, TweenInfo.new(Theme.Animation.Hover), {
			Color = active and Theme.Colors.White or Theme.Colors.Border,
			Transparency = active and 0.45 or 0.12,
		}):Play()
	end
	frame.MouseEnter:Connect(function() glow(true) end)
	frame.MouseLeave:Connect(function() glow(false) end)

	return frame
end

return Panel
