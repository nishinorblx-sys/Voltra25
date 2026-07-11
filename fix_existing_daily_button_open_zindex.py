from pathlib import Path
import re

root=Path.cwd()
button=root/"src/client/DailyRewardHudButton.client.lua"

code=r'''
local Players=game:GetService("Players")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local ICON="rbxassetid://106068354237205"

local function clientRoot()
	return script.Parent
end

local function requireExistingDailyModule()
	local root=clientRoot()
	local paths={
		root:FindFirstChild("Components") and root.Components:FindFirstChild("DailyLoginRewardPanel"),
		root:FindFirstChild("Components") and root.Components:FindFirstChild("DailyRewardPanel"),
		root:FindFirstChild("Components") and root.Components:FindFirstChild("SevenWinLoginRewardPanel"),
		root:FindFirstChild("Pages") and root.Pages:FindFirstChild("DailyLoginRewardPage"),
		root:FindFirstChild("Pages") and root.Pages:FindFirstChild("DailyRewardPage"),
		root:FindFirstChild("Pages") and root.Pages:FindFirstChild("DailyRewardsPage"),
	}
	for _,module in paths do
		if module and module:IsA("ModuleScript") then
			local ok,result=pcall(require,module)
			if ok and result then
				return result,module.Name
			end
		end
	end
	return nil,nil
end

local function openExistingDailyRewards()
	for _,gui in playerGui:GetDescendants() do
		if gui:IsA("GuiObject") then
			local n=string.lower(gui.Name)
			if n=="dailyloginrewardpanel" or n=="dailyrewardpanel" or n=="dailyloginrewardpage" or n=="dailyrewardpage" or n=="dailyrewards" or n=="sevenwinloginrewardpanel" then
				gui.Visible=true
				return true
			end
		end
	end

	local module,moduleName=requireExistingDailyModule()
	if not module then
		warn("[Daily Rewards] No existing daily reward module found.")
		return false
	end

	local context={
		Player=player,
		PlayerGui=playerGui,
		Gui=playerGui,
		Root=playerGui,
		Parent=playerGui,
		Toast=function(payload)
			local message=type(payload)=="table" and tostring(payload.Message or payload.Title or "") or tostring(payload or "")
			if message~="" then warn("[Daily Rewards] "..message) end
		end,
	}

	local parent=playerGui
	local calls={}

	if type(module)=="function" then
		table.insert(calls,function() return module(context) end)
		table.insert(calls,function() return module(parent,context) end)
		table.insert(calls,function() return module({Parent=parent,Context=context,PlayerGui=playerGui,Player=player}) end)
	end

	if type(module)=="table" then
		for _,name in {"Open","Show","Mount","Render","Create","new","New","Start","Init"} do
			if type(module[name])=="function" then
				table.insert(calls,function() return module[name](context) end)
				table.insert(calls,function() return module[name](parent,context) end)
				table.insert(calls,function() return module[name](module,context) end)
				table.insert(calls,function() return module[name](module,parent,context) end)
				table.insert(calls,function() return module[name]({Parent=parent,Context=context,PlayerGui=playerGui,Player=player}) end)
			end
		end
	end

	for _,call in calls do
		local ok,result=pcall(call)
		if ok then
			if typeof(result)=="Instance" then
				if result:IsA("ScreenGui") then
					result.Parent=playerGui
				elseif not result.Parent then
					result.Parent=playerGui
				end
				return true
			end
			return true
		end
	end

	warn("[Daily Rewards] Existing module found but did not open: "..tostring(moduleName))
	return false
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

local function connectButton(button)
	if button:GetAttribute("VTRDailyRewardConnected")==true then return end
	button:SetAttribute("VTRDailyRewardConnected",true)
	button.Activated:Connect(openExistingDailyRewards)
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

button.write_text(code.strip()+"\n",encoding="utf-8")

for path in (root/"src/client").rglob("*.lua"):
	text=path.read_text(encoding="utf-8",errors="ignore")
	original=text
	text=text.replace("ZIndex=999999","ZIndex=1")
	text=text.replace("ZIndex=999","ZIndex=1")
	text=text.replace("ZIndex=100","ZIndex=1")
	text=text.replace("DisplayOrder=999999","DisplayOrder=1")
	text=re.sub(r'button\.ZIndex\s*=\s*math\.max\([^\n]*\)',"button.ZIndex=1",text)
	text=re.sub(r'\.ZIndex\s*=\s*math\.max\([^,\n]+,\s*999\)',".ZIndex=1",text)
	if text!=original:
		path.write_text(text.strip()+"\n",encoding="utf-8")
		print("cleaned zindex",path.as_posix())

print("patched daily reward button to use existing panel and zindex 1")