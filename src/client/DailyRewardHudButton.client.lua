local Players=game:GetService("Players")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local ICON="rbxassetid://107242746684663"

local function openDailyRewards()
	local app=playerGui:FindFirstChild("VTRApp",true) or playerGui:FindFirstChild("App",true) or playerGui:FindFirstChild("Main",true)
	local opened=false

	if _G.VTRNavigate then
		local ok=pcall(function()_G.VTRNavigate("DailyRewards")end)
		opened=opened or ok
	end

	if _G.VTROpenPage then
		local ok=pcall(function()_G.VTROpenPage("DailyRewards")end)
		opened=opened or ok
	end

	for _,gui in playerGui:GetDescendants() do
		if gui:IsA("GuiObject") then
			local name=string.lower(gui.Name)
			if name=="dailyreward" or name=="dailyrewards" or name=="dailyloginreward" or name=="dailyloginrewardpage" or name=="dailyrewardpage" then
				gui.Visible=true
				opened=true
			end
		end
	end

	if opened then return end

	local clientRoot=script.Parent
	local candidates={
		clientRoot:FindFirstChild("Pages") and clientRoot.Pages:FindFirstChild("DailyRewardsPage"),
		clientRoot:FindFirstChild("Pages") and clientRoot.Pages:FindFirstChild("DailyRewardPage"),
		clientRoot:FindFirstChild("Pages") and clientRoot.Pages:FindFirstChild("DailyLoginRewardPage"),
		clientRoot:FindFirstChild("Components") and clientRoot.Components:FindFirstChild("DailyLoginRewardPanel"),
		clientRoot:FindFirstChild("Components") and clientRoot.Components:FindFirstChild("DailyRewardPanel"),
	}

	for _,module in candidates do
		if module then
			local ok,result=pcall(require,module)
			if ok and result then
				local made=false
				for _,method in {"Open","Show","new","Create","Render"} do
					if type(result)=="table" and type(result[method])=="function" then
						local worked=pcall(function()
							result[method](playerGui,{Player=player,PlayerGui=playerGui,Root=app})
						end)
						if worked then made=true end
					end
				end
				if not made and type(result)=="function" then
					local worked=pcall(function()
						result(playerGui,{Player=player,PlayerGui=playerGui,Root=app})
					end)
					if worked then made=true end
				end
				if made then return end
			end
		end
	end

	local existing=playerGui:FindFirstChild("VTRDailyRewardPageMissing")
	if existing then existing:Destroy() end
	local screen=Instance.new("ScreenGui")
	screen.Name="VTRDailyRewardPageMissing"
	screen.ResetOnSpawn=false
	screen.IgnoreGuiInset=true
	screen.Parent=playerGui
	local close=Instance.new("TextButton")
	close.Text="DAILY REWARDS PAGE NOT FOUND"
	close.TextColor3=Color3.fromRGB(255,255,255)
	close.TextSize=18
	close.Font=Enum.Font.GothamBlack
	close.BackgroundColor3=Color3.fromRGB(12,14,18)
	close.Size=UDim2.fromScale(1,1)
	close.Parent=screen
	close.Activated:Connect(function()screen:Destroy()end)
end

local function isOldDailyButton(obj)
	return obj.Name=="VTRDailyRewardTopButton" or obj.Name=="VTRDailyRewardButton"
end

local function removeDuplicates(keep)
	for _,obj in playerGui:GetDescendants() do
		if obj~=keep and isOldDailyButton(obj) then
			obj:Destroy()
		end
	end
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

local function createButton(settingsButton)
	if not settingsButton or not settingsButton.Parent then return false end
	local parent=settingsButton.Parent
	local button=parent:FindFirstChild("VTRDailyRewardButton")
	if not button then
		button=Instance.new("ImageButton")
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
		button.Parent=parent
		local corner=Instance.new("UICorner")
		corner.CornerRadius=UDim.new(0,8)
		corner.Parent=button
		button.Activated:Connect(openDailyRewards)
	end
	button.Position=settingsButton.Position-UDim2.fromOffset((settingsButton.AbsoluteSize.X>0 and settingsButton.AbsoluteSize.X or 42)+8,0)
	removeDuplicates(button)
	return true
end

local function attach()
	for _,obj in playerGui:GetDescendants() do
		if isSettingsButton(obj) and createButton(obj) then
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
end)

playerGui.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if isOldDailyButton(obj) then
			removeDuplicates(obj)
		elseif isSettingsButton(obj) then
			createButton(obj)
		end
	end)
end)
