local Players=game:GetService("Players")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local ICON="rbxassetid://106068354237205"

local function isOurButton(obj)
	return obj.Name=="VTRDailyRewardButton" or obj.Name=="VTRDailyRewardTopButton"
end

local function isSettingsButton(obj)
	if not obj:IsA("GuiObject") then return false end
	local n=string.lower(obj.Name)
	if string.find(n,"setting") or string.find(n,"gear") then return true end
	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		local t=string.lower(tostring(obj.Text or ""))
		return t=="settings" or t=="setting"
	end
	return false
end

local function isExistingDailyOpener(obj)
	if isOurButton(obj) or not obj:IsA("GuiButton") then return false end
	local n=string.lower(obj.Name)
	local t=""
	if obj:IsA("TextButton") then t=string.lower(tostring(obj.Text or "")) end
	local image=""
	if obj:IsA("ImageButton") then image=string.lower(tostring(obj.Image or "")) end
	local hit=string.find(n,"daily") or string.find(n,"loginreward") or string.find(n,"dailyreward") or string.find(t,"daily") or string.find(t,"reward")
	if not hit then return false end
	if string.find(n,"close") or string.find(n,"claim") or string.find(t,"claim") or string.find(t,"close") then return false end
	return true
end

local function isExistingDailyPage(obj)
	if not obj:IsA("GuiObject") or isOurButton(obj) then return false end
	local n=string.lower(obj.Name)
	return n=="dailyrewardpage" or n=="dailyreward" or n=="dailyrewards" or n=="dailyloginrewardpage" or n=="dailyloginrewardpanel" or n=="dailyrewardpanel"
end

local function findExistingDailyOpener()
	local best=nil
	for _,obj in playerGui:GetDescendants() do
		if isExistingDailyOpener(obj) then
			if obj.Visible then return obj end
			best=best or obj
		end
	end
	return best
end

local function showExistingDailyPage()
	for _,obj in playerGui:GetDescendants() do
		if isExistingDailyPage(obj) then
			obj.Visible=true
			local current=obj.Parent
			while current and current~=playerGui do
				if current:IsA("GuiObject") then current.Visible=true end
				current=current.Parent
			end
			return true
		end
	end
	return false
end

local function openDailyRewards()
	local bindable=playerGui:FindFirstChild("VTROpenExistingDailyReward",true)
	if bindable and bindable:IsA("BindableEvent") then
		bindable:Fire()
		return
	end

	for _,gui in playerGui:GetDescendants() do
		if gui:IsA("GuiObject") then
			local n=string.lower(gui.Name)
			if n=="dailyloginrewardpanel" or n=="dailyrewardpanel" or n=="dailyloginrewardpage" or n=="dailyrewardpage" or n=="dailyrewards" or n=="sevenwinloginrewardpanel" then
				gui.Visible=true
				local parent=gui.Parent
				while parent and parent~=playerGui do
					if parent:IsA("GuiObject") then parent.Visible=true end
					parent=parent.Parent
				end
				return
			end
		end
	end

	warn("[Daily Rewards] Existing daily reward page/opener was not found.")
end

local function removeExtraButtons(keep)
	for _,obj in playerGui:GetDescendants() do
		if obj~=keep and isOurButton(obj) then obj:Destroy() end
	end
end

local function connectButton(button)
	if button:GetAttribute("VTRDailyRewardConnected")==true then return end
	button:SetAttribute("VTRDailyRewardConnected",true)
	button.Activated:Connect(openDailyRewards)
end

local function createNearSettings(settingsButton)
	if not settingsButton or not settingsButton.Parent then return false end
	local parent=settingsButton.Parent
	local button=parent:FindFirstChild("VTRDailyRewardButton")
	if not button then
		button=Instance.new("ImageButton")
		button.Name="VTRDailyRewardButton"
		button.Parent=parent
		local corner=Instance.new("UICorner")
		corner.CornerRadius=UDim.new(0,8)
		corner.Parent=button
	end
	button.Image=ICON
	button.BackgroundTransparency=settingsButton.BackgroundTransparency
	button.BackgroundColor3=settingsButton.BackgroundColor3
	button.BorderSizePixel=0
	button.ScaleType=Enum.ScaleType.Fit
	button.AutoButtonColor=true
	button.AnchorPoint=settingsButton.AnchorPoint
	button.Size=settingsButton.Size
	button.Position=settingsButton.Position-UDim2.fromOffset((settingsButton.AbsoluteSize.X>0 and settingsButton.AbsoluteSize.X or 42)+8,0)
	button.ZIndex=1
	button.Visible=true
	connectButton(button)
	removeExtraButtons(button)
	return true
end

local function attach()
	for _,obj in playerGui:GetDescendants() do
		if isSettingsButton(obj) then
			if createNearSettings(obj) then return true end
		end
	end
	
vtrRegisterDailyRewardOpen(function()openDailyRewards()end)
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
		if isSettingsButton(obj) then createNearSettings(obj) end
	end)
end)
