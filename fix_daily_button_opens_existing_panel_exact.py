from pathlib import Path
import re

root=Path.cwd()
panel_path=root/"src/client/Components/DailyLoginRewardPanel.lua"
button_path=root/"src/client/DailyRewardHudButton.client.lua"

if not panel_path.exists():
	raise SystemExit("Missing src/client/Components/DailyLoginRewardPanel.lua")

panel=panel_path.read_text(encoding="utf-8",errors="ignore")
print("DailyLoginRewardPanel methods found:")
for m in re.finditer(r"function\s+([A-Za-z_][A-Za-z0-9_]*)[:.]([A-Za-z_][A-Za-z0-9_]*)\s*\(",panel):
	print(" ",m.group(1)+"."+m.group(2))
for m in re.finditer(r"([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\(",panel):
	print(" ",m.group(1)+"."+m.group(2))

code=r'''
local Players=game:GetService("Players")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local ICON="rbxassetid://106068354237205"
local DailyLoginRewardPanel=require(script.Parent.Components:WaitForChild("DailyLoginRewardPanel"))

local function isDailyGui(obj)
	if typeof(obj)~="Instance" or not obj:IsA("GuiObject") then return false end
	local n=string.lower(obj.Name)
	return n:find("daily")~=nil and (n:find("reward")~=nil or n:find("login")~=nil)
end

local function dailyGuiVisible()
	for _,obj in ipairs(playerGui:GetDescendants()) do
		if isDailyGui(obj) and obj.Visible==true then
			return true
		end
	end
	return false
end

local function showExistingDailyGui()
	local shown=false
	for _,obj in ipairs(playerGui:GetDescendants()) do
		if isDailyGui(obj) then
			obj.Visible=true
			local parent=obj.Parent
			while parent and parent~=playerGui do
				if parent:IsA("GuiObject") then parent.Visible=true end
				parent=parent.Parent
			end
			shown=true
		end
	end
	return shown
end

local function dailyContext()
	return {
		Player=player,
		PlayerGui=playerGui,
		Gui=playerGui,
		Parent=playerGui,
		Root=playerGui,
		Toast=function(payload)
			local message=type(payload)=="table" and tostring(payload.Message or payload.Title or "") or tostring(payload or "")
			if message~="" then warn("[Daily Rewards] "..message) end
		end,
	}
end

local function tryPanelCall(callback)
	local before={}
	for _,obj in ipairs(playerGui:GetDescendants()) do
		before[obj]=true
	end

	local ok,result=pcall(callback)
	if not ok then return false end

	if typeof(result)=="Instance" then
		if result:IsA("ScreenGui") then
			result.Parent=playerGui
		elseif not result.Parent then
			result.Parent=playerGui
		end
	end

	if showExistingDailyGui() then return true end

	for _,obj in ipairs(playerGui:GetDescendants()) do
		if not before[obj] and isDailyGui(obj) then
			obj.Visible=true
			return true
		end
	end

	return dailyGuiVisible()
end

local function openDailyRewards()
	if showExistingDailyGui() then return end

	local context=dailyContext()
	local calls={}

	if type(DailyLoginRewardPanel)=="table" then
		for _,method in ipairs({"Open","Show","Mount","Create","Render","Display","Start","new","New"}) do
			if type(DailyLoginRewardPanel[method])=="function" then
				table.insert(calls,function() return DailyLoginRewardPanel[method](DailyLoginRewardPanel,playerGui,context) end)
				table.insert(calls,function() return DailyLoginRewardPanel[method](DailyLoginRewardPanel,context) end)
				table.insert(calls,function() return DailyLoginRewardPanel[method](playerGui,context) end)
				table.insert(calls,function() return DailyLoginRewardPanel[method](context) end)
				table.insert(calls,function() return DailyLoginRewardPanel[method]({Parent=playerGui,PlayerGui=playerGui,Context=context,Player=player}) end)
			end
		end
	elseif type(DailyLoginRewardPanel)=="function" then
		table.insert(calls,function() return DailyLoginRewardPanel(playerGui,context) end)
		table.insert(calls,function() return DailyLoginRewardPanel(context) end)
		table.insert(calls,function() return DailyLoginRewardPanel({Parent=playerGui,PlayerGui=playerGui,Context=context,Player=player}) end)
	end

	for _,call in ipairs(calls) do
		if tryPanelCall(call) then return end
	end

	warn("[Daily Rewards] DailyLoginRewardPanel exists but no open call produced a visible daily reward UI.")
end

local function isSettingsButton(obj)
	if typeof(obj)~="Instance" or not obj:IsA("GuiObject") then return false end
	local n=string.lower(obj.Name)
	if n:find("setting") or n:find("gear") then return true end
	if obj:IsA("TextButton") or obj:IsA("TextLabel") then
		local t=string.lower(tostring(obj.Text or ""))
		return t=="settings" or t=="setting"
	end
	return false
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
'''

button_path.write_text(code.strip()+"\n",encoding="utf-8")
print("rewrote DailyRewardHudButton to call existing DailyLoginRewardPanel only")