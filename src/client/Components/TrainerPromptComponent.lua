--!strict
local TweenService = game:GetService("TweenService")

local Component = {}
Component.__index = Component

function Component.new(parent: Instance)
	local group = Instance.new("CanvasGroup")
	group.Name = "VTRTrainerPrompt"
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Size = UDim2.fromOffset(178, 108)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Visible = false
	group.ZIndex = 15
	group.Parent = parent
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.Parent = group
	return setmetatable({Group = group, Visible = false}, Component)
end

function Component:SetAdornee(_part: BasePart?) end

function Component:SetScreenPosition(screenPoint: Vector2, viewport: Vector2)
	local desired = screenPoint + Vector2.new(82, -18)
	desired = Vector2.new(math.clamp(desired.X, 90, viewport.X - 90), math.clamp(desired.Y, 36, viewport.Y - 36))
	self.Group.Position = UDim2.fromOffset(desired.X, desired.Y)
end

function Component:SetPrompts(prompts: {{Label: string, Key: string}})
	local signatures = {}
	for _, prompt in prompts do table.insert(signatures, prompt.Key .. ":" .. prompt.Label) end
	local signature = table.concat(signatures, "|")
	if self.Signature == signature then return end
	self.Signature = signature
	for _, child in self.Group:GetChildren() do if child:IsA("Frame") then child:Destroy() end end
	for index, prompt in prompts do
		if index > 5 then break end
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, 17)
		row.BackgroundTransparency = 1
		row.ZIndex = 15
		row.Parent = self.Group
		local key = Instance.new("TextLabel")
		key.Size = UDim2.fromOffset(39, 17)
		key.BackgroundColor3 = Color3.fromHex("050505")
		key.BackgroundTransparency = 0.72
		key.Text = prompt.Key
		key.TextColor3 = Color3.fromHex("B7FF1A")
		key.TextSize = 8
		key.Font = Enum.Font.GothamBlack
		key.ZIndex = 16
		key.Parent = row
		if #prompt.Key > 4 then
			key.Size = UDim2.fromOffset(64, 17)
		end
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = key
		local text = Instance.new("TextLabel")
		local keyWidth = key.Size.X.Offset
		text.Position = UDim2.fromOffset(keyWidth + 6, 0)
		text.Size = UDim2.new(1, -(keyWidth + 6), 1, 0)
		text.BackgroundTransparency = 1
		text.Text = prompt.Label
		text.TextColor3 = Color3.fromHex("F4F5F1")
		text.TextStrokeColor3 = Color3.fromHex("050505")
		text.TextStrokeTransparency = 0.75
		text.TextSize = 9
		text.Font = Enum.Font.GothamBold
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.ZIndex = 16
		text.Parent = row
	end
	self.Group.Size = UDim2.fromOffset(178, math.max(24, math.min(5, #prompts) * 21))
end

function Component:SetVisible(visible: boolean)
	if self.Visible == visible then return end
	self.Visible = visible
	if self.Tween then self.Tween:Cancel() end
	if visible then self.Group.Visible = true end
	self.Tween = TweenService:Create(self.Group, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = visible and 0.6 or 1})
	self.Tween:Play()
	if not visible then task.delay(0.18, function() if not self.Visible and self.Group.Parent then self.Group.Visible = false end end) end
end

function Component:Destroy()
	if self.Tween then self.Tween:Cancel() end
	self.Group:Destroy()
end

return Component
