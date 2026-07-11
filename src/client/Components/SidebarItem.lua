--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local SidebarItem = {}
SidebarItem.__index = SidebarItem

local WORLD_CUP_GOLD = Color3.fromRGB(255, 207, 64)
local WORLD_CUP_DEEP = Color3.fromRGB(49, 31, 4)
local WORLD_CUP_GLOW = Color3.fromRGB(255, 236, 142)

export type SidebarItem = typeof(setmetatable({
	Instance = nil :: TextButton?,
	Active = false,
	SetActive = nil :: any,
}, SidebarItem))

function SidebarItem.new(item: any, onActivated: (string) -> ()): SidebarItem
	local featuredWorldCup = item.Id == "WorldCup"
	local button = Instance.new("TextButton")
	button.Name = item.Id .. "Nav"
	button.AutoButtonColor = false
	button.BackgroundColor3 = featuredWorldCup and Color3.fromRGB(10, 9, 6) or Theme.Colors.Graphite
	button.BackgroundTransparency = featuredWorldCup and 0.72 or 1
	button.BorderSizePixel = 0
	button.LayoutOrder = item.Order
	button.Size = UDim2.new(1, 0, 0, 43)
	button.Text = item.Icon .. "    " .. item.Label
	button.TextColor3 = featuredWorldCup and WORLD_CUP_GOLD or Theme.Colors.Muted
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

	local featuredStroke: UIStroke? = nil
	local featuredGlow: Frame? = nil
	if featuredWorldCup then
		featuredGlow = Instance.new("Frame")
		featuredGlow.Name = "WorldCupGoldGlow"
		featuredGlow.BackgroundColor3 = WORLD_CUP_GLOW
		featuredGlow.BackgroundTransparency = 0.94
		featuredGlow.BorderSizePixel = 0
		featuredGlow.Position = UDim2.fromOffset(-3, -3)
		featuredGlow.Size = UDim2.new(1, 6, 1, 6)
		featuredGlow.ZIndex = button.ZIndex - 1
		featuredGlow.Parent = button
		local glowCorner = Instance.new("UICorner")
		glowCorner.CornerRadius = UDim.new(0, Theme.Radius.Large)
		glowCorner.Parent = featuredGlow

		featuredStroke = Instance.new("UIStroke")
		featuredStroke.Name = "WorldCupGoldStroke"
		featuredStroke.Color = WORLD_CUP_GOLD
		featuredStroke.Thickness = 1
		featuredStroke.Transparency = 0.68
		featuredStroke.Parent = button

		local shine = Instance.new("Frame")
		shine.Name = "WorldCupGoldShine"
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.BackgroundTransparency = 0.9
		shine.BorderSizePixel = 0
		shine.Position = UDim2.fromScale(-0.08, 0.5)
		shine.Rotation = 18
		shine.Size = UDim2.fromScale(0.06, 1.45)
		shine.ZIndex = button.ZIndex + 1
		shine.Parent = button

		task.spawn(function()
			while button.Parent do
				if featuredStroke then
					TweenService:Create(featuredStroke, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.38 }):Play()
				end
				if featuredGlow then
					TweenService:Create(featuredGlow, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0.88 }):Play()
				end
				TweenService:Create(shine, TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(1.08, 0.5), BackgroundTransparency = 0.86 }):Play()
				task.wait(0.9)
				if not button.Parent then break end
				if featuredStroke then
					TweenService:Create(featuredStroke, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.72 }):Play()
				end
				if featuredGlow then
					TweenService:Create(featuredGlow, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0.96 }):Play()
				end
				shine.Position = UDim2.fromScale(-0.08, 0.5)
				shine.BackgroundTransparency = 0.92
				task.wait(0.9)
			end
		end)
	end

	local self = setmetatable({ Instance = button, Active = false }, SidebarItem)
	local function visualHover(hovered: boolean)
		if self.Active then return end
		if featuredWorldCup then
			TweenService:Create(button, TweenInfo.new(Theme.Animation.Hover), {
				BackgroundTransparency = hovered and 0.18 or 0.72,
				BackgroundColor3 = hovered and Color3.fromRGB(73, 47, 6) or WORLD_CUP_DEEP,
				TextColor3 = hovered and Color3.new(1, 1, 1) or WORLD_CUP_GOLD,
			}):Play()
			TweenService:Create(scale, TweenInfo.new(Theme.Animation.Hover), { Scale = hovered and 1.025 or 1 }):Play()
			return
		end
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
	local featuredWorldCup = button.Name == "WorldCupNav"
	TweenService:Create(button, TweenInfo.new(Theme.Animation.Standard), {
		BackgroundTransparency = active and 0 or (featuredWorldCup and 0.72 or 1),
		BackgroundColor3 = active and (featuredWorldCup and WORLD_CUP_GOLD or Theme.Colors.Electric) or (featuredWorldCup and Color3.fromRGB(10, 9, 6) or Theme.Colors.Graphite),
		TextColor3 = active and Theme.Colors.Black or (featuredWorldCup and WORLD_CUP_GOLD or Theme.Colors.Muted),
	}):Play()
end

return SidebarItem
