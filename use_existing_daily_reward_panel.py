from pathlib import Path
import re

root=Path.cwd()

for path in (root/"src/client").rglob("*.lua"):
	text=path.read_text(encoding="utf-8",errors="ignore")
	original=text
	text=re.sub(r'\nlocal function openFallbackDailyOverlay\([\s\S]*?\nend\n(?=\nlocal function openDailyRewards)',"\n",text)
	text=re.sub(r'\nlocal REWARDS=\{[\s\S]*?\n\}\n(?=\nlocal function remoteFunction)',"\n",text)
	text=re.sub(r'\nlocal function remoteFunction\([\s\S]*?\nend\n(?=\nlocal function request)',"\n",text)
	text=re.sub(r'\nlocal function request\(action,payload\)[\s\S]*?\nend\n(?=\nlocal function mk)',"\n",text)
	text=re.sub(r'\nlocal function mk\(parent,class,props\)[\s\S]*?\nend\n(?=\nlocal function corner)',"\n",text)
	text=re.sub(r'\nlocal function clearOverlay\([\s\S]*?\nend\n(?=\nlocal function openDailyRewards)',"\n",text)
	if text!=original:
		path.write_text(text.strip()+"\n",encoding="utf-8")
		print("removed generated overlay code from",path.as_posix())

button_path=root/"src/client/DailyRewardHudButton.client.lua"
panel_path=root/"src/client/Components/DailyLoginRewardPanel.lua"

if not panel_path.exists():
	raise SystemExit("Existing DailyLoginRewardPanel.lua not found")

panel=panel_path.read_text(encoding="utf-8",errors="ignore")
methods=[]
for m in re.finditer(r'function\s+[A-Za-z_][A-Za-z0-9_]*[:\.]([A-Za-z_][A-Za-z0-9_]*)\s*\(',panel):
	methods.append(m.group(1))
for m in re.finditer(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\(',panel):
	methods.append(m.group(1))
print("existing panel methods:",sorted(set(methods)))

code=r'''
local Players=game:GetService("Players")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local ICON="rbxassetid://106068354237205"

local DailyLoginRewardPanel=require(script.Parent.Components:WaitForChild("DailyLoginRewardPanel"))

local function callExistingDailyPanel()
	local context={
		Player=player,
		PlayerGui=playerGui,
		Gui=playerGui,
		Parent=playerGui,
		Toast=function(payload)
			local message=type(payload)=="table" and tostring(payload.Message or payload.Title or "") or tostring(payload or "")
			if message~="" then warn("[Daily Rewards] "..message) end
		end,
	}

	for _,name in {"Open","Show","Mount","Create","Render","Display","Start","new"} do
		if type(DailyLoginRewardPanel)=="table" and type(DailyLoginRewardPanel[name])=="function" then
			for _,args in {
				{DailyLoginRewardPanel,playerGui,context},
				{DailyLoginRewardPanel,context},
				{DailyLoginRewardPanel,playerGui},
				{playerGui,context},
				{context},
				{playerGui},
			} do
				local ok=pcall(function()
					DailyLoginRewardPanel[name](table.unpack(args))
				end)
				if ok then return true end
			end
		end
	end

	if type(DailyLoginRewardPanel)=="function" then
		for _,args in {
			{playerGui,context},
			{context},
			{playerGui},
		} do
			local ok=pcall(function()
				DailyLoginRewardPanel(table.unpack(args))
			end)
			if ok then return true end
		end
	end

	for _,gui in playerGui:GetDescendants() do
		if gui:IsA("GuiObject") then
			local n=string.lower(gui.Name)
			if n=="dailyloginrewardpanel" or n=="dailyrewardpanel" or n=="dailyrewards" or n=="dailyrewardpage" then
				gui.Visible=true
				return true
			end
		end
	end

	warn("[Daily Rewards] Existing panel module loaded but no supported open method worked.")
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

local function connect(button)
	if button:GetAttribute("VTRDailyRewardConnected")==true then return end
	button:SetAttribute("VTRDailyRewardConnected",true)
	button.Activated:Connect(callExistingDailyPanel)
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
	button.ZIndex=math.max(settingsButton.ZIndex+1,999)
	button.Visible=true
	connect(button)
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

button_path.write_text(code.strip()+"\n",encoding="utf-8")
print("rewrote",button_path.as_posix(),"to use existing DailyLoginRewardPanel only")