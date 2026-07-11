from pathlib import Path
import re

root=Path.cwd()
icon_id="rbxassetid://107242746684663"

targets=[
	root/"src/client/Controllers/FlowController.lua",
	root/"src/client/Pages/HomePage.lua",
	root/"src/client/Components/TopBar.lua",
	root/"src/client/Components/NavigationBar.lua",
	root/"src/client/AppController.lua",
	root/"src/client/MainController.lua",
]

existing=[p for p in targets if p.exists()]
if not existing:
	existing=list((root/"src/client").rglob("*.lua"))

chosen=None
for path in existing:
	text=path.read_text(encoding="utf-8",errors="ignore")
	low=text.lower()
	if ("settings" in low or "setting" in low) and ("imagebutton" in low or "textbutton" in low) and ("daily" not in path.name.lower()):
		chosen=path
		break

if not chosen:
	raise SystemExit("Could not find the top bar/settings button script. Run a search for Settings icon file.")

text=chosen.read_text(encoding="utf-8",errors="ignore")
original=text

if "VTRDailyRewardTopButton" not in text:
	if "DailyLoginRewardPanel" not in text:
		require_line='local DailyLoginRewardPanel=require(script.Parent.Parent.Components:WaitForChild("DailyLoginRewardPanel"))\n'
		if "Components" in chosen.as_posix() and "Pages" not in chosen.as_posix():
			require_line='local DailyLoginRewardPanel=require(script.Parent:WaitForChild("DailyLoginRewardPanel"))\n'
		elif "Pages" in chosen.as_posix():
			require_line='local DailyLoginRewardPanel=require(script.Parent.Parent.Components:WaitForChild("DailyLoginRewardPanel"))\n'
		elif "Controllers" in chosen.as_posix():
			require_line='local DailyLoginRewardPanel=require(script.Parent.Parent.Components:WaitForChild("DailyLoginRewardPanel"))\n'
		m=re.search(r"local\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*require[^\n]*\n",text)
		if m:
			text=text[:m.end()]+require_line+text[m.end():]
		else:
			text=require_line+text

	helper=r'''
local function vtrOpenDailyRewardOverlay(context:any?, parent:Instance?)
	local targetParent=parent
	if not targetParent and context then
		targetParent=context.Gui or context.ScreenGui or context.RootGui or context.Parent
	end
	if not targetParent then
		local player=game:GetService("Players").LocalPlayer
		targetParent=player and player:FindFirstChildOfClass("PlayerGui")
	end
	if DailyLoginRewardPanel and DailyLoginRewardPanel.Open then
		DailyLoginRewardPanel.Open(targetParent,context)
	elseif DailyLoginRewardPanel and DailyLoginRewardPanel.new then
		DailyLoginRewardPanel.new(targetParent,context)
	elseif type(DailyLoginRewardPanel)=="function" then
		DailyLoginRewardPanel(targetParent,context)
	end
end

local function vtrCreateDailyRewardTopButton(parent:Instance, settingsButton:GuiObject?, context:any?)
	if not parent or parent:FindFirstChild("VTRDailyRewardTopButton") then return end
	local button=Instance.new("ImageButton")
	button.Name="VTRDailyRewardTopButton"
	button.BackgroundTransparency=settingsButton and settingsButton.BackgroundTransparency or 1
	button.BackgroundColor3=settingsButton and settingsButton.BackgroundColor3 or Color3.fromRGB(12,14,16)
	button.BorderSizePixel=0
	button.Image="rbxassetid://107242746684663"
	button.ScaleType=Enum.ScaleType.Fit
	button.AutoButtonColor=true
	button.ZIndex=settingsButton and settingsButton.ZIndex or 50
	button.Size=settingsButton and settingsButton.Size or UDim2.fromOffset(40,40)
	button.AnchorPoint=settingsButton and settingsButton.AnchorPoint or Vector2.new(1,0)
	if settingsButton then
		button.Position=settingsButton.Position-UDim2.fromOffset((settingsButton.AbsoluteSize.X>0 and settingsButton.AbsoluteSize.X or 40)+8,0)
	else
		button.Position=UDim2.new(1,-96,0,12)
	end
	button.Parent=parent
	button.Activated:Connect(function()
		vtrOpenDailyRewardOverlay(context,parent)
	end)
end

'''
	m=re.search(r"\nfunction\s+",text)
	if m:
		text=text[:m.start()]+helper+text[m.start():]
	else:
		text=helper+text

	settings_names=["SettingsButton","Settings","SettingsIcon","SettingsToggle","SettingsGear"]
	inserted=False
	for name in settings_names:
		pattern=rf'((local\s+{name}\s*=\s*Instance\.new\("[^"]+"\)[\s\S]*?{name}\.Parent\s*=\s*([A-Za-z_][A-Za-z0-9_]*)))'
		m=re.search(pattern,text)
		if m:
			parent=m.group(3)
			text=text[:m.end()]+f'\nvtrCreateDailyRewardTopButton({parent},{name},context)\n'+text[m.end():]
			inserted=True
			break

	if not inserted:
		pattern=r'((local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*Instance\.new\("ImageButton"\)[\s\S]{0,1600}?\.Image\s*=[^\n]*(?:settings|gear)[^\n]*[\s\S]{0,1600?\3\.Parent\s*=\s*([A-Za-z_][A-Za-z0-9_]*)))'
		m=re.search(pattern,text,re.IGNORECASE)
		if m:
			button=m.group(3)
			parent=m.group(4)
			text=text[:m.end()]+f'\nvtrCreateDailyRewardTopButton({parent},{button},context)\n'+text[m.end():]
			inserted=True

	if not inserted:
		text=text.replace(
			"return group",
			"local settingsButton=group:FindFirstChild(\"Settings\",true)or group:FindFirstChild(\"SettingsButton\",true)or group:FindFirstChild(\"SettingsIcon\",true)\nvtrCreateDailyRewardTopButton(group,settingsButton,context)\nreturn group",
			1
		)
		inserted="VTRDailyRewardTopButton(group" in text

	if not inserted:
		raise SystemExit("Could not safely insert beside settings button in "+chosen.as_posix())

chosen.write_text(text.strip()+"\n",encoding="utf-8")
print("patched",chosen.as_posix())