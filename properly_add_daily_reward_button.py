from pathlib import Path

root=Path.cwd()
out=root/"src/client/DailyRewardHudButton.client.lua"

code=r'''
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local ICON="rbxassetid://107242746684663"

local function clientRoot()
	local scriptRoot=script.Parent
	return scriptRoot
end

local function tryRequire(path)
	local ok,result=pcall(function()
		return require(path)
	end)
	if ok then return result end
	return nil
end

local function dailyPanelModule()
	local root=clientRoot()
	local components=root:FindFirstChild("Components")
	if components then
		local panel=components:FindFirstChild("DailyLoginRewardPanel") or components:FindFirstChild("DailyRewardPanel")
		if panel then return tryRequire(panel) end
	end
	return nil
end

local function findRemoteFunction()
	local names={
		"DailyLoginRewardFunction",
		"DailyRewardFunction",
		"DailyLoginFunction",
		"VTRDailyLoginRewardFunction",
		"DailyRewardsFunction",
	}
	for _,name in names do
		local found=ReplicatedStorage:FindFirstChild(name,true)
		if found and found:IsA("RemoteFunction") then return found end
	end
	local remotes=ReplicatedStorage:FindFirstChild("VTR")
	if remotes then
		for _,name in names do
			local found=remotes:FindFirstChild(name,true)
			if found and found:IsA("RemoteFunction") then return found end
		end
	end
	return nil
end

local function requestDaily(action,payload)
	local remote=findRemoteFunction()
	if not remote then
		return {Success=false,Message="Daily rewards service unavailable."}
	end
	local ok,result=pcall(function()
		return remote:InvokeServer(action,payload or {})
	end)
	if ok and type(result)=="table" then return result end
	ok,result=pcall(function()
		return remote:InvokeServer({Action=action,Payload=payload or {}})
	end)
	if ok and type(result)=="table" then return result end
	return {Success=false,Message="Daily rewards service unavailable."}
end

local function destroyExisting()
	local existing=playerGui:FindFirstChild("VTRDailyRewardOverlay")
	if existing then existing:Destroy() end
end

local function mk(parent,class,props)
	local obj=Instance.new(class)
	for key,value in props do obj[key]=value end
	obj.Parent=parent
	return obj
end

local function corner(parent,radius)
	local item=Instance.new("UICorner")
	item.CornerRadius=UDim.new(0,radius)
	item.Parent=parent
	return item
end

local function stroke(parent,color,transparency)
	local item=Instance.new("UIStroke")
	item.Color=color
	item.Transparency=transparency or 0
	item.Thickness=1
	item.Parent=parent
	return item
end

local function label(parent,text,pos,size,textSize,color,font)
	local item=mk(parent,"TextLabel",{
		BackgroundTransparency=1,
		Position=pos,
		Size=size,
		Text=text,
		TextColor3=color,
		TextSize=textSize,
		Font=font or Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Center,
		TextWrapped=true,
		ZIndex=205,
	})
	return item
end

local function openFallbackDailyOverlay()
	destroyExisting()
	local screen=mk(playerGui,"ScreenGui",{Name="VTRDailyRewardOverlay",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	local cover=mk(screen,"TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=.32,Size=UDim2.fromScale(1,1),ZIndex=200})
	local panel=mk(cover,"CanvasGroup",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(760,520),BackgroundColor3=Color3.fromRGB(11,14,18),BackgroundTransparency=.04,GroupTransparency=1,ZIndex=201})
	corner(panel,16)
	stroke(panel,Color3.fromRGB(86,255,151),.25)
	label(panel,"DAILY REWARDS",UDim2.fromOffset(28,22),UDim2.new(1,-110,0,36),28,Color3.fromRGB(255,255,255),Enum.Font.GothamBlack)
	label(panel,"Log in daily and claim your reward track.",UDim2.fromOffset(30,58),UDim2.new(1,-60,0,24),12,Color3.fromRGB(170,184,192),Enum.Font.GothamBold)
	local close=mk(panel,"TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-22,0,22),Size=UDim2.fromOffset(42,34),Text="X",TextColor3=Color3.fromRGB(255,255,255),TextSize=14,Font=Enum.Font.GothamBlack,BackgroundColor3=Color3.fromRGB(28,32,38),BorderSizePixel=0,ZIndex=206})
	corner(close,8)
	close.Activated:Connect(function() screen:Destroy() end)
	cover.Activated:Connect(function()
		if playerGui:FindFirstChild("VTRDailyRewardOverlay")==screen then screen:Destroy() end
	end)
	panel.Active=true

	local data=requestDaily("Get")
	local rewards=data.Rewards or data.Track or data.Data and (data.Data.Rewards or data.Data.Track) or {}
	local currentDay=tonumber(data.TrackDay or data.Day or data.Data and (data.Data.TrackDay or data.Data.Day)) or 1
	local claimed=data.ClaimedToday==true or data.Data and data.Data.ClaimedToday==true

	local grid=mk(panel,"Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(28,104),Size=UDim2.new(1,-56,0,300),ZIndex=202})
	local layout=Instance.new("UIGridLayout")
	layout.CellSize=UDim2.fromOffset(164,86)
	layout.CellPadding=UDim2.fromOffset(10,10)
	layout.SortOrder=Enum.SortOrder.LayoutOrder
	layout.Parent=grid

	local fallback={
		"1000 Coins","250 Voltra Points","Basic Goal Celebration","Basic Pack","2000 Coins","Rare Pack","75-82 OVR Random Player",
		"3000 Coins","500 Voltra Points","Epic Pack","80-84 OVR Random Player","5000 Coins","Icon Pack","83-88 OVR Random Player"
	}

	for i=1,14 do
		local reward=rewards[i]
		local name=reward and tostring(reward.Name or reward.Title or reward.DisplayName or reward.ItemId or reward.Type or fallback[i]) or fallback[i]
		local card=mk(grid,"Frame",{LayoutOrder=i,BackgroundColor3=i==currentDay and Color3.fromRGB(38,76,50) or Color3.fromRGB(22,26,32),BorderSizePixel=0,ZIndex=203})
		corner(card,10)
		stroke(card,i==currentDay and Color3.fromRGB(86,255,151) or Color3.fromRGB(70,78,88),i==currentDay and .05 or .55)
		label(card,"DAY "..i,UDim2.fromOffset(12,8),UDim2.new(1,-24,0,18),10,i==currentDay and Color3.fromRGB(86,255,151) or Color3.fromRGB(150,162,170),Enum.Font.GothamBlack)
		label(card,name,UDim2.fromOffset(12,30),UDim2.new(1,-24,0,44),12,Color3.fromRGB(255,255,255),Enum.Font.GothamBold)
	end

	local status=label(panel,claimed and "TODAY'S REWARD ALREADY CLAIMED" or "READY TO CLAIM",UDim2.fromOffset(30,420),UDim2.new(.55,0,0,34),14,claimed and Color3.fromRGB(170,184,192) or Color3.fromRGB(86,255,151),Enum.Font.GothamBlack)
	local claim=mk(panel,"TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-30,0,416),Size=UDim2.fromOffset(210,44),Text=claimed and "CLAIMED" or "CLAIM DAILY",TextColor3=claimed and Color3.fromRGB(150,160,168) or Color3.fromRGB(0,0,0),TextSize=13,Font=Enum.Font.GothamBlack,BackgroundColor3=claimed and Color3.fromRGB(45,50,58) or Color3.fromRGB(86,255,151),BorderSizePixel=0,ZIndex=206,AutoButtonColor=not claimed})
	corner(claim,10)
	claim.Activated:Connect(function()
		if claimed then return end
		local result=requestDaily("Claim")
		if result.Success==false then
			status.Text=result.Message or "CLAIM FAILED"
			status.TextColor3=Color3.fromRGB(255,93,93)
			return
		end
		claimed=true
		claim.Text="CLAIMED"
		claim.TextColor3=Color3.fromRGB(150,160,168)
		claim.BackgroundColor3=Color3.fromRGB(45,50,58)
		status.Text=result.Message or "REWARD CLAIMED"
		status.TextColor3=Color3.fromRGB(86,255,151)
	end)

	TweenService:Create(panel,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=0}):Play()
end

local function openDailyRewards()
	local panel=dailyPanelModule()
	if panel then
		local ok=pcall(function()
			if panel.Open then
				panel.Open(playerGui)
			elseif panel.Show then
				panel.Show(playerGui)
			elseif panel.new then
				panel.new(playerGui)
			elseif type(panel)=="function" then
				panel(playerGui)
			else
				error("Unsupported daily panel module")
			end
		end)
		if ok then return end
	end
	openFallbackDailyOverlay()
end

local function isSettingsButton(obj)
	if not obj:IsA("GuiObject") then return false end
	local name=string.lower(obj.Name)
	if string.find(name,"setting") or string.find(name,"gear") then return true end
	if obj:IsA("ImageButton") or obj:IsA("ImageLabel") then
		local image=string.lower(tostring(obj.Image or ""))
		if string.find(image,"setting") or string.find(image,"gear") then return true end
	end
	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		local text=string.lower(tostring(obj.Text or ""))
		if text=="settings" or text=="setting" then return true end
	end
	return false
end

local function createDailyButtonNear(settingsButton)
	if not settingsButton or not settingsButton.Parent then return false end
	local parent=settingsButton.Parent
	if parent:FindFirstChild("VTRDailyRewardButton") then return true end
	local button=Instance.new("ImageButton")
	button.Name="VTRDailyRewardButton"
	button.Image=ICON
	button.BackgroundTransparency=settingsButton.BackgroundTransparency
	button.BackgroundColor3=settingsButton.BackgroundColor3
	button.BorderSizePixel=0
	button.ScaleType=Enum.ScaleType.Fit
	button.AutoButtonColor=true
	button.ZIndex=math.max(settingsButton.ZIndex,50)
	button.AnchorPoint=settingsButton.AnchorPoint
	button.Size=settingsButton.Size
	button.Position=settingsButton.Position-UDim2.fromOffset((settingsButton.AbsoluteSize.X>0 and settingsButton.AbsoluteSize.X or 42)+8,0)
	button.Parent=parent
	local c=Instance.new("UICorner")
	c.CornerRadius=UDim.new(0,8)
	c.Parent=button
	button.Activated:Connect(openDailyRewards)
	return true
end

local function attach()
	for _,obj in playerGui:GetDescendants() do
		if isSettingsButton(obj) and createDailyButtonNear(obj) then
			return true
		end
	end
	return false
end

task.spawn(function()
	for _=1,120 do
		if attach() then return end
		task.wait(.25)
	end
	local screen=playerGui:FindFirstChildWhichIsA("ScreenGui")
	if screen and not screen:FindFirstChild("VTRDailyRewardButton") then
		local button=Instance.new("ImageButton")
		button.Name="VTRDailyRewardButton"
		button.Image=ICON
		button.BackgroundTransparency=.08
		button.BackgroundColor3=Color3.fromRGB(12,14,16)
		button.BorderSizePixel=0
		button.ScaleType=Enum.ScaleType.Fit
		button.AutoButtonColor=true
		button.ZIndex=100
		button.AnchorPoint=Vector2.new(1,0)
		button.Size=UDim2.fromOffset(42,42)
		button.Position=UDim2.new(1,-96,0,14)
		button.Parent=screen
		corner(button,8)
		button.Activated:Connect(openDailyRewards)
	end
end)

playerGui.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if isSettingsButton(obj) then createDailyButtonNear(obj) end
	end)
end)
'''

out.write_text(code.strip()+"\n",encoding="utf-8")
print("created",out.as_posix())