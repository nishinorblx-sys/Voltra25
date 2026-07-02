local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local PackRewardFlyinAnimation = {}

local function lowerText(obj)
	local values = { obj.Name }

	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		table.insert(values, obj.Text)
	end

	for _, value in ipairs(values) do
		local s = string.lower(tostring(value or ""))
		if s ~= "" then
			return s
		end
	end

	return ""
end

local function findInventoryTarget()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local best
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("GuiObject") then
			local s = lowerText(obj)
			if string.find(s, "inventory") or string.find(s, "inv") or string.find(s, "backpack") or string.find(s, "packs") then
				if obj.Visible and obj.AbsoluteSize.X > 8 and obj.AbsoluteSize.Y > 8 then
					best = obj
					if obj:IsA("GuiButton") then
						return obj
					end
				end
			end
		end
	end

	return best
end

local function guiPosFromAbsolute(gui, absoluteCenter)
	local root = gui.AbsolutePosition
	return UDim2.fromOffset(absoluteCenter.X - root.X, absoluteCenter.Y - root.Y)
end

local function makeGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("PackRewardFlyinGui")

	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "PackRewardFlyinGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15000
	gui.Parent = playerGui

	return gui
end

function PackRewardFlyinAnimation.Play(packName)
	local gui = makeGui()

	local card = Instance.new("Frame")
	card.Name = "PackRewardPopup"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.47)
	card.Size = UDim2.fromOffset(310, 190)
	card.BackgroundColor3 = Color3.fromRGB(20, 25, 38)
	card.BackgroundTransparency = 0.02
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(136, 255, 72)
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 16)
	title.Size = UDim2.new(1, -32, 0, 30)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(136, 255, 72)
	title.Text = "PACK EARNED"
	title.Parent = card

	local pack = Instance.new("TextLabel")
	pack.Name = "PackName"
	pack.BackgroundColor3 = Color3.fromRGB(33, 42, 61)
	pack.Position = UDim2.fromOffset(28, 62)
	pack.Size = UDim2.new(1, -56, 0, 86)
	pack.Font = Enum.Font.GothamBlack
	pack.TextSize = 26
	pack.TextWrapped = true
	pack.TextColor3 = Color3.fromRGB(255, 255, 255)
	pack.Text = tostring(packName)
	pack.Parent = card

	local packCorner = Instance.new("UICorner")
	packCorner.CornerRadius = UDim.new(0, 16)
	packCorner.Parent = pack

	card.Size = UDim2.fromOffset(250, 150)
	TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(310, 190),
	}):Play()

	task.wait(1.05)

	local target = findInventoryTarget()
	local endPosition = UDim2.fromScale(0.91, 0.91)
	local endSize = UDim2.fromOffset(62, 42)

	if target then
		local center = target.AbsolutePosition + target.AbsoluteSize * 0.5
		endPosition = guiPosFromAbsolute(gui, center)
		endSize = UDim2.fromOffset(math.max(42, target.AbsoluteSize.X * 0.35), math.max(32, target.AbsoluteSize.Y * 0.35))
	end

	local fly = TweenService:Create(card, TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = endPosition,
		Size = endSize,
		BackgroundTransparency = 0.45,
	})
	fly:Play()
	fly.Completed:Wait()

	local fade = TweenService:Create(card, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	fade:Play()
	fade.Completed:Wait()

	card:Destroy()
end

return PackRewardFlyinAnimation
