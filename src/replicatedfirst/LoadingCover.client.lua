local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local teleportData = TeleportService:GetLocalPlayerTeleportData()
local isMatchTeleport = type(teleportData) == "table" and (teleportData.MatchMode == "Ranked1v1" or teleportData.MatchMode == "AICampaignSolo")

local old = playerGui:FindFirstChild("VTRReplicatedFirstCover")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "VTRReplicatedFirstCover"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.BackgroundColor3 = Color3.fromRGB(2, 4, 2)
bg.BorderSizePixel = 0
bg.Size = UDim2.fromScale(1, 1)
bg.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(.5, .5)
title.Position = UDim2.fromScale(.5, .43)
title.Size = UDim2.fromScale(.82, .08)
title.Font = Enum.Font.GothamBlack
title.Text = isMatchTeleport and "SYNCING MATCH" or "VOLTRA"
title.TextColor3 = Color3.fromRGB(245, 247, 242)
title.TextSize = 34
title.Parent = bg

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.AnchorPoint = Vector2.new(.5, .5)
sub.Position = UDim2.fromScale(.5, .51)
sub.Size = UDim2.fromScale(.82, .05)
sub.Font = Enum.Font.GothamBold
sub.Text = isMatchTeleport and "WAITING FOR PRESENTATION" or "LOADING"
sub.TextColor3 = Color3.fromRGB(190, 195, 186)
sub.TextSize = 11
sub.Parent = bg

local spinner = Instance.new("Frame")
spinner.BackgroundTransparency = 1
spinner.AnchorPoint = Vector2.new(.5, .5)
spinner.Position = UDim2.fromScale(.5, .61)
spinner.Size = UDim2.fromOffset(58, 58)
spinner.Parent = bg

for index = 1, 12 do
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(.5, .5)
	dot.Size = UDim2.fromOffset(7, 7)
	dot.BackgroundColor3 = Color3.fromRGB(245, 247, 242)
	dot.BackgroundTransparency = .18 + index * .045
	dot.BorderSizePixel = 0
	local angle = math.rad(index * 30)
	dot.Position = UDim2.fromScale(.5 + math.cos(angle) * .38, .5 + math.sin(angle) * .38)
	dot.Parent = spinner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
end

local spinning = true
local connection = RunService.RenderStepped:Connect(function(dt)
	if spinning and spinner.Parent then
		spinner.Rotation += dt * 210
	end
end)

local function release()
	if not gui.Parent then return end
	spinning = false
	if connection then connection:Disconnect() end
	for _, item in ipairs(bg:GetDescendants()) do
		if item:IsA("TextLabel") then
			TweenService:Create(item, TweenInfo.new(.16), {TextTransparency = 1}):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, TweenInfo.new(.16), {BackgroundTransparency = 1}):Play()
		end
	end
	TweenService:Create(bg, TweenInfo.new(.18), {BackgroundTransparency = 1}):Play()
	task.delay(.22, function()
		if gui.Parent then gui:Destroy() end
	end)
end

task.spawn(function()
	local started = os.clock()
	if isMatchTeleport then
		while gui.Parent and os.clock() - started < 70 do
			if playerGui:FindFirstChild("VTRPrematchBroadcast") or playerGui:FindFirstChild("VTRMatchBootCover") then
				task.wait(.45)
				release()
				return
			end
			task.wait(.04)
		end
	else
		while gui.Parent and os.clock() - started < 18 do
			if playerGui:FindFirstChild("VTR25") or playerGui:FindFirstChild("VTRApp") or playerGui:FindFirstChild("VTRMainMenu") then
				task.wait(.2)
				release()
				return
			end
			task.wait(.05)
		end
	end
	release()
end)
