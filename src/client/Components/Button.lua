--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local UISoundService = require(script.Parent.Parent.Services.UISoundService)
local C = Theme.Colors

local Button = {}

export type Props = {
	Text: string,
	Variant: string?,
	Size: UDim2?,
	OnActivated: (() -> ())?,
}

function Button.new(props: Props): TextButton
	local primary = props.Variant == "Primary"
	local danger = props.Variant == "Danger"
	local instance = Instance.new("TextButton")
	instance.Name = props.Text:gsub("%W", "") .. "Button"
	instance.AutoButtonColor = false
	instance.BackgroundColor3 = primary and C.Electric or danger and C.Danger or C.Gunmetal
	instance.BorderSizePixel = 0
	instance.Size = props.Size or UDim2.fromOffset(primary and 176 or 144, 46)
	instance.Text = string.upper(props.Text)
	instance.TextColor3 = primary and C.Black or C.White
	instance.TextSize = 12
	instance.Font = Theme.Fonts.Strong
	instance.Selectable = false
	instance:SetAttribute("VTRPrimary", primary)
	instance:SetAttribute("VTRDanger", danger)
	instance:SetAttribute("VTRUISoundBound", true)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.Medium)
	corner.Parent = instance

	local stroke = Instance.new("UIStroke")
	stroke.Color = primary and C.Electric or danger and C.Danger or C.Border
	stroke.Transparency = primary and 0.3 or danger and 0.18 or 0
	stroke.Thickness = 1
	stroke.Parent = instance

	local scale = Instance.new("UIScale")
	scale.Parent = instance
	local scaleTween: Tween?
	local colorTween: Tween?

	local function tween(scaleValue: number, color: Color3)
		if scaleTween then scaleTween:Cancel() end
		if colorTween then colorTween:Cancel() end
		scaleTween = TweenService:Create(scale, TweenInfo.new(Theme.Animation.Hover, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), { Scale = scaleValue })
		colorTween = TweenService:Create(instance, TweenInfo.new(Theme.Animation.Hover), { BackgroundColor3 = color })
		scaleTween:Play()
		colorTween:Play()
	end

	local function focus()
		UISoundService.PlayHover()
		local isPrimary = instance:GetAttribute("VTRPrimary") == true
		local isDanger = instance:GetAttribute("VTRDanger") == true
		tween(1.035, isPrimary and C.Neon or isDanger and Color3.fromHex("FF6975") or C.Raised)
	end
	local function unfocus()
		local isPrimary = instance:GetAttribute("VTRPrimary") == true
		local isDanger = instance:GetAttribute("VTRDanger") == true
		tween(1, isPrimary and C.Electric or isDanger and C.Danger or C.Gunmetal)
		instance.TextColor3 = isPrimary and C.Black or C.White
	end
	instance.MouseEnter:Connect(focus)
	instance.MouseLeave:Connect(unfocus)
	instance.SelectionGained:Connect(focus)
	instance.SelectionLost:Connect(unfocus)
	instance.MouseButton1Down:Connect(function() tween(0.96, primary and C.Neon or danger and Color3.fromHex("D92E3D") or C.Raised) end)
	instance.MouseButton1Up:Connect(focus)
	instance.Activated:Connect(function()
		UISoundService.PlayClick()
		if scaleTween then scaleTween:Cancel() end
		scaleTween = TweenService:Create(scale, TweenInfo.new(Theme.Animation.Press), { Scale = 0.94 })
		scaleTween:Play()
		task.delay(Theme.Animation.Press, function()
			if instance.Parent then TweenService:Create(scale, TweenInfo.new(Theme.Animation.Hover), { Scale = 1.035 }):Play() end
		end)
		if props.OnActivated then props.OnActivated() end
	end)

	return instance
end

function Button.setPrimary(instance: TextButton, primary: boolean)
	instance:SetAttribute("VTRPrimary", primary)
	TweenService:Create(instance, TweenInfo.new(Theme.Animation.Standard), {
		BackgroundColor3 = primary and C.Electric or C.Gunmetal,
		TextColor3 = primary and C.Black or C.White,
	}):Play()
end

return Button
