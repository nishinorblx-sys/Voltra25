--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local GameplayConfig = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local FocusController = require(script.Parent.Controllers.FocusController)
local MatchGameplayController = require(script.Parent.Gameplay.GameplayController)

local function forceMenuVisible()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and (gui.Name == "VTRApp" or gui.Name == "VTRMainMenu" or string.find(gui.Name, "Menu")) then
			gui.Enabled = true
		end
	end
end

local function showMatchLoadSyncCover()
	local data = TeleportService:GetLocalPlayerTeleportData()
	local matchTeleport = type(data) == "table" and (data.MatchMode == "Ranked1v1" or data.MatchMode == "AICampaignSolo")
	if not matchTeleport then return nil end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRMatchLoadSyncCover")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRMatchLoadSyncCover"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5000
	gui.Parent = playerGui
	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromHex("020402")
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(.5, .5)
	title.Position = UDim2.fromScale(.5, .44)
	title.Size = UDim2.fromScale(.78, .08)
	title.Font = Theme.Fonts.Display
	title.Text = data.MatchMode == "Ranked1v1" and "SYNCING MATCH" or "LOADING AI MATCH"
	title.TextColor3 = Theme.Colors.Electric
	title.TextSize = 36
	title.Parent = bg
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(.5, .5)
	sub.Position = UDim2.fromScale(.5, .52)
	sub.Size = UDim2.fromScale(.78, .05)
	sub.Font = Theme.Fonts.Strong
	sub.Text = "PREPARING CINEMATIC BROADCAST"
	sub.TextColor3 = Theme.Colors.Silver
	sub.TextSize = 11
	sub.Parent = bg
	task.spawn(function()
		local started = os.clock()
		while gui.Parent and os.clock() - started < 55 do
			local prematch = playerGui:FindFirstChild("VTRPrematchBroadcast")
			if prematch then
				task.wait(.35)
				break
			end
			task.wait(.05)
		end
		if gui.Parent then
			local tween = TweenService:Create(bg, TweenInfo.new(.18), {BackgroundTransparency = 1})
			tween:Play()
			task.delay(.2, function()
				if gui.Parent then gui:Destroy() end
			end)
		end
	end)
	return gui
end

showMatchLoadSyncCover()
FocusController.new():Start(Players.LocalPlayer:WaitForChild("PlayerGui"))
MatchGameplayController.new():Start()

local function showRankedMatchFoundTeleport(data:any)
	local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
	local old=playerGui:FindFirstChild("VTRRankedTeleportFound")
	if old then old:Destroy()end
	local gui=Instance.new("ScreenGui")
	gui.Name="VTRRankedTeleportFound"
	gui.IgnoreGuiInset=true
	gui.ResetOnSpawn=false
	gui.DisplayOrder=500
	gui.Parent=playerGui
	local overlay=Instance.new("CanvasGroup")
	overlay.Size=UDim2.fromScale(1,1)
	overlay.BackgroundColor3=Theme.Colors.Black
	overlay.GroupTransparency=1
	overlay.ZIndex=500
	overlay.Parent=gui
	local title=Instance.new("TextLabel")
	title.BackgroundTransparency=1
	title.AnchorPoint=Vector2.new(.5,.5)
	title.Position=UDim2.fromScale(.5,.3)
	title.Size=UDim2.fromScale(.86,.1)
	title.Font=Theme.Fonts.Display
	title.Text="MATCH FOUND"
	title.TextColor3=Theme.Colors.Electric
	title.TextSize=46
	title.ZIndex=505
	title.Parent=overlay
	local sub=Instance.new("TextLabel")
	sub.BackgroundTransparency=1
	sub.AnchorPoint=Vector2.new(.5,.5)
	sub.Position=UDim2.fromScale(.5,.39)
	sub.Size=UDim2.fromScale(.8,.05)
	sub.Font=Theme.Fonts.Strong
	sub.Text="RANKED 1V1  /  VOLTRA SERVER LOCKED"
	sub.TextColor3=Theme.Colors.White
	sub.TextSize=12
	sub.ZIndex=505
	sub.Parent=overlay
	local vs=Instance.new("TextLabel")
	vs.BackgroundTransparency=1
	vs.AnchorPoint=Vector2.new(.5,.5)
	vs.Position=UDim2.fromScale(.5,.55)
	vs.Size=UDim2.fromScale(.82,.1)
	vs.Font=Theme.Fonts.Display
	vs.Text=string.upper(tostring(data.HomeTeamName or data.HomeName or"HOME")).."   VS   "..string.upper(tostring(data.AwayTeamName or data.AwayName or"AWAY"))
	vs.TextColor3=Theme.Colors.White
	vs.TextSize=28
	vs.ZIndex=505
	vs.Parent=overlay
	local core=Instance.new("Frame")
	core.AnchorPoint=Vector2.new(.5,.5)
	core.Position=UDim2.fromScale(.5,.55)
	core.Size=UDim2.fromOffset(28,28)
	core.BackgroundColor3=Theme.Colors.Electric
	core.BorderSizePixel=0
	core.Rotation=45
	core.ZIndex=504
	core.Parent=overlay
	local coreStroke=Instance.new("UIStroke")
	coreStroke.Color=Theme.Colors.White
	coreStroke.Thickness=2
	coreStroke.Transparency=.1
	coreStroke.Parent=core
	for index=1,28 do
		local ray=Instance.new("Frame")
		ray.AnchorPoint=Vector2.new(.5,.5)
		ray.Position=UDim2.fromScale(.5,.55)
		ray.Size=UDim2.fromOffset(math.random(8,22),math.random(80,180))
		ray.BackgroundColor3=index%3==0 and Theme.Colors.White or Theme.Colors.Electric
		ray.BackgroundTransparency=.22
		ray.BorderSizePixel=0
		ray.Rotation=(360/28)*index
		ray.ZIndex=502
		ray.Parent=overlay
		TweenService:Create(ray,TweenInfo.new(.78,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(.5,math.cos(math.rad(ray.Rotation))*math.random(180,470),.55,math.sin(math.rad(ray.Rotation))*math.random(80,260)),BackgroundTransparency=1,Size=UDim2.fromOffset(2,18)}):Play()
	end
	TweenService:Create(overlay,TweenInfo.new(.18),{GroupTransparency=0}):Play()
	TweenService:Create(core,TweenInfo.new(.8,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(190,190),BackgroundTransparency=.88,Rotation=405}):Play()
	task.delay(2.8,function()
		if overlay.Parent then TweenService:Create(overlay,TweenInfo.new(.28),{GroupTransparency=1}):Play()end
		task.delay(.3,function()if gui.Parent then gui:Destroy()end end)
	end)
end

task.defer(function()
	local remotes=ReplicatedStorage:WaitForChild("Remotes",10)
	local rankedFound=remotes and remotes:WaitForChild("RankedMatchFound",10)
	if rankedFound and rankedFound:IsA("RemoteEvent")then
		rankedFound.OnClientEvent:Connect(showRankedMatchFoundTeleport)
	end
end)

local teleportData = TeleportService:GetLocalPlayerTeleportData()
local reservedRankedBoot = type(teleportData) == "table" and (teleportData.MatchMode == "Ranked1v1" or teleportData.MatchMode == "AICampaignSolo")

local function showReservedRankedBoot()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRRankedReservedBoot")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRRankedReservedBoot"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 150
	gui.Parent = playerGui
	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Theme.Colors.Black
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui
	for index = 1, 4 do
		local slash = Instance.new("Frame")
		slash.BackgroundColor3 = Color3.fromHex("020402")
		slash.BackgroundTransparency = 1
		slash.BorderSizePixel = 0
		slash.AnchorPoint = Vector2.new(0.5, 0.5)
		slash.Position = UDim2.fromScale(0.16 + index * 0.18, 0.5)
		slash.Size = UDim2.fromScale(0.055, 1.35)
		slash.Rotation = 24
		slash.Parent = bg
	end
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.43)
	title.Size = UDim2.fromScale(0.78, 0.08)
	title.Font = Theme.Fonts.Display
	title.Text = teleportData.MatchMode == "AICampaignSolo" and "AI CAMPAIGN MATCH" or "RANKED 1V1 SERVER"
	title.TextColor3 = Theme.Colors.Electric
	title.TextSize = 32
	title.Parent = bg
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.fromScale(0.5, 0.51)
	sub.Size = UDim2.fromScale(0.78, 0.05)
	sub.Font = Theme.Fonts.Strong
	sub.Text = teleportData.MatchMode == "AICampaignSolo" and "LOADING DIRECTLY INTO THE INTRO" or "SYNCING BOTH TEAMS  /  LOADING RESERVED MATCH"
	sub.TextColor3 = Theme.Colors.Silver
	sub.TextSize = 10
	sub.Parent = bg
	Players.LocalPlayer:GetAttributeChangedSignal("VTRInMatch"):Connect(function()
		if Players.LocalPlayer:GetAttribute("VTRInMatch") == true then
			task.delay(1.2, function()
				if gui.Parent then gui:Destroy() end
			end)
		end
	end)
	return gui
end

if GameplayConfig.AutoStartTestMatch then
	local GameplayController = require(script.Parent.Controllers.GameplayController)
	GameplayController.new():Start()
elseif reservedRankedBoot then
	showMatchLoadSyncCover()
	showReservedRankedBoot()
else
	local UIController = require(script.Parent.Controllers.UIController)
	UIController.new():Start()
	forceMenuVisible()
end
