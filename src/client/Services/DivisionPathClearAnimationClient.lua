local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local DivisionPathClearAnimationClient = {}

local started = false
local lastSeq = -1

local function makeText(parent, name, text, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

local function burst(parent)
	for i = 1, 44 do
		local piece = Instance.new("Frame")
		piece.Name = "Burst"
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.5)
		piece.Size = UDim2.fromOffset(math.random(5, 12), math.random(16, 34))
		piece.Rotation = math.random(0, 360)
		piece.BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1)
		piece.BorderSizePixel = 0
		piece.Parent = parent

		local angle = math.rad((i / 44) * 360)
		local distance = math.random(260, 520)
		local target = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance)

		TweenService:Create(piece, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = target,
			Rotation = piece.Rotation + math.random(180, 620),
			BackgroundTransparency = 1,
		}):Play()

		task.delay(0.95, function()
			if piece.Parent then
				piece:Destroy()
			end
		end)
	end
end

function DivisionPathClearAnimationClient.Play()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("DivisionPathClearGui")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DivisionPathClearGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20000
	gui.Parent = playerGui

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(720, 280)
	card.BackgroundColor3 = Color3.fromRGB(10, 15, 22)
	card.BackgroundTransparency = 0.05
	card.Parent = shade

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 26)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(140, 255, 45)
	stroke.Parent = card

	local scale = Instance.new("UIScale")
	scale.Scale = 0.78
	scale.Parent = card

	local title = makeText(card, "Title", "DIVISION PATH CLEARED", UDim2.fromOffset(30, 34), UDim2.new(1, -60, 0, 64), 44, Color3.fromRGB(150, 255, 55))
	local sub = makeText(card, "Sub", "4 wins reached — division promoted", UDim2.fromOffset(30, 104), UDim2.new(1, -60, 0, 40), 23, Color3.fromRGB(255, 255, 255))
	local division = tonumber(localPlayer:GetAttribute("Division")) or 0
	local divText = division > 0 and "NEW DIVISION " .. tostring(division) or "NEW DIVISION"
	makeText(card, "Division", divText, UDim2.fromOffset(30, 152), UDim2.new(1, -60, 0, 54), 34, Color3.fromRGB(60, 225, 255))

	TweenService:Create(shade, TweenInfo.new(0.22), {
		BackgroundTransparency = 0.18,
	}):Play()

	TweenService:Create(scale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	burst(gui)

	task.wait(2.2)

	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.9,
	}):Play()

	TweenService:Create(shade, TweenInfo.new(0.18), {
		BackgroundTransparency = 1,
	}):Play()

	task.wait(0.2)
	gui:Destroy()
end

local function check()
	local seq = tonumber(localPlayer:GetAttribute("VTRDivisionPathClearSeq")) or 0
	local promoted = localPlayer:GetAttribute("VTRDivisionPathPromoted") == true

	if promoted and seq > lastSeq then
		lastSeq = seq
		DivisionPathClearAnimationClient.Play()
	elseif seq > lastSeq then
		lastSeq = seq
	end
end

function DivisionPathClearAnimationClient.Start()
	if started then
		return
	end

	started = true
	lastSeq = tonumber(localPlayer:GetAttribute("VTRDivisionPathClearSeq")) or 0

	localPlayer:GetAttributeChangedSignal("VTRDivisionPathClearSeq"):Connect(check)
	task.defer(check)
end

DivisionPathClearAnimationClient.Start()

return DivisionPathClearAnimationClient
