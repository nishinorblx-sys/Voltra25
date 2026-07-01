--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local SidebarItem = {}
SidebarItem.__index = SidebarItem

export type SidebarItem = typeof(setmetatable({
	Instance = nil :: TextButton?,
	Active = false,
	SetActive = nil :: any,
}, SidebarItem))

function SidebarItem.new(item: any, onActivated: (string) -> ()): SidebarItem
	local button = Instance.new("TextButton")
	button.Name = item.Id .. "Nav"
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.Colors.Graphite
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.LayoutOrder = item.Order
	button.Size = UDim2.new(1, 0, 0, 43)
	button.Text = item.Icon .. "    " .. item.Label
	button.TextColor3 = Theme.Colors.Muted
	button.TextSize = 10
	button.Font = Theme.Fonts.Strong
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Selectable = false

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius.Medium)
	corner.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button

	local self = setmetatable({ Instance = button, Active = false }, SidebarItem)
	local function visualHover(hovered: boolean)
		if self.Active then return end
		TweenService:Create(button, TweenInfo.new(Theme.Animation.Hover), {
			BackgroundTransparency = hovered and 0.3 or 1,
			BackgroundColor3 = Theme.Colors.Gunmetal,
			TextColor3 = hovered and Theme.Colors.White or Theme.Colors.Muted,
		}):Play()
		TweenService:Create(scale, TweenInfo.new(Theme.Animation.Hover), { Scale = hovered and 1.015 or 1 }):Play()
	end
	button.MouseEnter:Connect(function() visualHover(true) end)
	button.MouseLeave:Connect(function() visualHover(false) end)
	button.SelectionGained:Connect(function() visualHover(true) end)
	button.SelectionLost:Connect(function() visualHover(false) end)
	button.Activated:Connect(function()
		TweenService:Create(scale, TweenInfo.new(Theme.Animation.Press), { Scale = 0.96 }):Play()
		task.delay(Theme.Animation.Press, function() if button.Parent then scale.Scale = 1 end end)
		onActivated(item.Id)
	end)
	return self
end

function SidebarItem:SetActive(active: boolean)
	self.Active = active
	local button = self.Instance :: TextButton
	TweenService:Create(button, TweenInfo.new(Theme.Animation.Standard), {
		BackgroundTransparency = active and 0 or 1,
		BackgroundColor3 = active and Theme.Colors.White or Theme.Colors.Graphite,
		TextColor3 = active and Theme.Colors.Black or Theme.Colors.Muted,
	}):Play()
end

return SidebarItem
