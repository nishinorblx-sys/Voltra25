--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local PageBase = {}

function PageBase.new(name: string, canvasHeight: number?): (CanvasGroup, ScrollingFrame)
	local group = Instance.new("CanvasGroup")
	group.Name = name
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Visible = false
	group.Active = true
	group.Selectable = false

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	-- Give the scroll itself the horizontal safe area. UIPadding does not reduce
	-- the scale basis of manually positioned children, so 100%-wide panels used
	-- to begin after the left padding and then clip past the right edge.
	scroll.Position = UDim2.fromOffset(Theme.Layout.ContentPadding, 0)
	scroll.Size = UDim2.new(1, -Theme.Layout.ContentPadding * 2, 1, 0)
	scroll.CanvasSize = UDim2.fromOffset(0, canvasHeight or 760)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Active = true
	scroll.ScrollingEnabled = true
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.Colors.White
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = group

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.Layout.ContentPadding)
	padding.PaddingBottom = UDim.new(0, Theme.Layout.ContentPadding)
	padding.PaddingLeft = UDim.new(0, 0)
	padding.PaddingRight = UDim.new(0, 0)
	padding.Parent = scroll
	return group, scroll
end

function PageBase.label(text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local result = Instance.new("TextLabel")
	result.BackgroundTransparency = 1
	result.Size = UDim2.fromScale(1, 1)
	result.Text = text
	result.TextColor3 = color or Theme.Colors.White
	result.TextSize = size
	result.Font = font or Theme.Fonts.Body
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.TextYAlignment = Enum.TextYAlignment.Center
	return result
end

function PageBase.heading(parent: Instance, kicker: string, titleText: string, subtitle: string)
	local block = Instance.new("Frame")
	block.Name = "Heading"
	block.BackgroundTransparency = 1
	block.Size = UDim2.new(1, 0, 0, 86)
	block.Parent = parent
	local kick = PageBase.label(kicker, 9, Theme.Colors.White, Theme.Fonts.Strong)
	kick.Size = UDim2.new(1, 0, 0, 18)
	kick.Parent = block
	local title = PageBase.label(titleText, 30, Theme.Colors.White, Theme.Fonts.Display)
	title.Position = UDim2.fromOffset(0, 17)
	title.Size = UDim2.new(1, 0, 0, 39)
	title.Parent = block
	local sub = PageBase.label(subtitle, 10, Theme.Colors.Muted, Theme.Fonts.Body)
	sub.Position = UDim2.fromOffset(0, 59)
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.Parent = block
end

function PageBase.text(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3?, font: Enum.Font?): TextLabel
	local result = PageBase.label(text, textSize, color, font)
	result.Position = position
	result.Size = size
	result.Parent = parent
	return result
end

return PageBase
