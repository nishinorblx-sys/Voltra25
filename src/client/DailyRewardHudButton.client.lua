local Players=game:GetService("Players")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local ICON="rbxassetid://106068354237205"

local function isSettingsButton(obj)
	if typeof(obj)~="Instance" or not obj:IsA("GuiObject") then return false end
	local name=string.lower(obj.Name)
	if string.find(name,"setting") or string.find(name,"gear") then return true end
	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		local text=string.lower(tostring(obj.Text or ""))
		if text=="settings" or text=="setting" then return true end
	end
	return false
end

local function openDailyRewards()
	local bindable=playerGui:FindFirstChild("VTROpenDailyLoginReward",true)
	if not bindable then
		local deadline=os.clock()+3
		while not bindable and os.clock()<deadline do
			task.wait(0.1)
			bindable=playerGui:FindFirstChild("VTROpenDailyLoginReward",true)
		end
	end
	if bindable and bindable:IsA("BindableEvent") then
		bindable:Fire()
		return
	end
	warn("[Daily Rewards] Daily login reward opener is not ready yet.")
end

local function removeExtraButtons(keep)
	for _,obj in ipairs(playerGui:GetDescendants()) do
		if obj~=keep and (obj.Name=="VTRDailyRewardButton" or obj.Name=="VTRDailyRewardTopButton") then
			obj:Destroy()
		end
	end
end

local function connectButton(button)
	if button:GetAttribute("VTRDailyRewardConnected")==true then return end
	button:SetAttribute("VTRDailyRewardConnected",true)
	button.Activated:Connect(openDailyRewards)
end

local function capButtonSize(button)
	local constraint=button:FindFirstChild("VTRDailyRewardSizeCap")
	if not constraint then
		constraint=Instance.new("UISizeConstraint")
		constraint.Name="VTRDailyRewardSizeCap"
		constraint.Parent=button
	end
	constraint.MinSize=Vector2.new(32,32)
	constraint.MaxSize=Vector2.new(46,46)
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
	capButtonSize(button)
	button.Position=settingsButton.Position-UDim2.fromOffset((settingsButton.AbsoluteSize.X>0 and settingsButton.AbsoluteSize.X or 42)+8,0)
	button.ZIndex=1
	button.Visible=true
	connectButton(button)
	removeExtraButtons(button)
	return true
end

local function attach()
	for _,obj in ipairs(playerGui:GetDescendants()) do
		if isSettingsButton(obj) then
			if createNearSettings(obj) then return true end
		end
	end
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
