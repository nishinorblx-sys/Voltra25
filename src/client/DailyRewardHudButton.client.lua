local Players=game:GetService("Players")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local ICON="rbxassetid://106068354237205"

local function openDailyRewards()
	local opened=false

	if _G.VTRNavigate then
		opened=pcall(function()_G.VTRNavigate("DailyRewards")end) or opened
	end

	if _G.VTROpenPage then
		opened=pcall(function()_G.VTROpenPage("DailyRewards")end) or opened
	end

	for _,gui in playerGui:GetDescendants() do
		if gui:IsA("GuiObject") then
			local n=string.lower(gui.Name)
			if n=="dailyreward" or n=="dailyrewards" or n=="dailyrewardpage" or n=="dailyloginreward" or n=="dailyloginrewardpage" then
				gui.Visible=true
				opened=true
			end
		end
	end

	local root=script.Parent
	local pages=root:FindFirstChild("Pages")
	local components=root:FindFirstChild("Components")
	local modules={
		pages and pages:FindFirstChild("DailyRewardsPage"),
		pages and pages:FindFirstChild("DailyRewardPage"),
		pages and pages:FindFirstChild("DailyLoginRewardPage"),
		components and components:FindFirstChild("DailyLoginRewardPanel"),
		components and components:FindFirstChild("DailyRewardPanel"),
	}

	for _,module in modules do
		if module then
			local ok,result=pcall(require,module)
			if ok and result then
				for _,method in {"Open","Show","new","Create","Render"} do
					if type(result)=="table" and type(result[method])=="function" then
						local worked=pcall(function()
							result[method](playerGui,{Player=player,PlayerGui=playerGui})
						end)
						if worked then return end
					end
				end
				if type(result)=="function" then
					local worked=pcall(function()
						result(playerGui,{Player=player,PlayerGui=playerGui})
					end)
					if worked then return end
				end
			end
		end
	end

	if opened then return end
end

local function isSettingsButton(obj)
	if not obj:IsA("GuiObject") then return false end
	local n=string.lower(obj.Name)
	if string.find(n,"setting") or string.find(n,"gear") then return true end
	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		local t=string.lower(tostring(obj.Text or ""))
		if t=="settings" or t=="setting" then return true end
	end
	return false
end

local function removeExtraButtons(keep)
	for _,obj in playerGui:GetDescendants() do
		if obj~=keep and (obj.Name=="VTRDailyRewardButton" or obj.Name=="VTRDailyRewardTopButton") then
			obj:Destroy()
		end
	end
end

local function topScreenGui()
	local gui=playerGui:FindFirstChild("VTRDailyRewardHud")
	if gui then return gui end

	gui=Instance.new("ScreenGui")
	gui.Name="VTRDailyRewardHud"
	gui.ResetOnSpawn=false
	gui.IgnoreGuiInset=true
	gui.DisplayOrder=999999
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	gui.Parent=playerGui
	return gui
end

local function createFallbackButton()
	local gui=topScreenGui()
	local button=gui:FindFirstChild("VTRDailyRewardButton")
	if not button then
		button=Instance.new("ImageButton")
		button.Name="VTRDailyRewardButton"
		button.Image=ICON
		button.BackgroundColor3=Color3.fromRGB(12,14,18)
		button.BackgroundTransparency=.08
		button.BorderSizePixel=0
		button.ScaleType=Enum.ScaleType.Fit
		button.AutoButtonColor=true
		button.AnchorPoint=Vector2.new(1,0)
		button.Size=UDim2.fromOffset(42,42)
		button.Position=UDim2.new(1,-96,0,14)
		button.ZIndex=999999
		button.Parent=gui
		local corner=Instance.new("UICorner")
		corner.CornerRadius=UDim.new(0,8)
		corner.Parent=button
		button.Activated:Connect(openDailyRewards)
	end
	button.Visible=true
	removeExtraButtons(button)
	return button
end

local function createNearSettings(settingsButton)
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
		button.AnchorPoint=settingsButton.AnchorPoint
		button.Size=settingsButton.Size
		button.ZIndex=math.max(settingsButton.ZIndex+1,999)
		button.Parent=parent
		local corner=Instance.new("UICorner")
		corner.CornerRadius=UDim.new(0,8)
		corner.Parent=button
		button.Activated:Connect(openDailyRewards)
	end
	button.Image=ICON
	button.Visible=true
	button.Position=settingsButton.Position-UDim2.fromOffset((settingsButton.AbsoluteSize.X>0 and settingsButton.AbsoluteSize.X or 42)+8,0)
	removeExtraButtons(button)
	local fallback=playerGui:FindFirstChild("VTRDailyRewardHud")
	if fallback then fallback:Destroy() end
	return true
end

local function attach()
	for _,obj in playerGui:GetDescendants() do
		if isSettingsButton(obj) then
			if createNearSettings(obj) then return true end
		end
	end
	createFallbackButton()
	return false
end

task.spawn(function()
	while true do
		attach()
		task.wait(1)
	end
end)

playerGui.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if isSettingsButton(obj) then
			createNearSettings(obj)
		end
	end)
end)
