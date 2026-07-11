from pathlib import Path
import re

path=Path("src/client/DailyRewardHudButton.client.lua")
text=path.read_text(encoding="utf-8",errors="ignore")

text=text.replace("obj:IsA(\"GuiObject\")","typeof(obj)==\"Instance\" and obj:IsA(\"GuiObject\")")
text=text.replace("obj:IsA(\"GuiButton\")","typeof(obj)==\"Instance\" and obj:IsA(\"GuiButton\")")
text=text.replace("gui:IsA(\"GuiObject\")","typeof(gui)==\"Instance\" and gui:IsA(\"GuiObject\")")

text=re.sub(
	r'''local function attach\(\)[\s\S]*?\nend\n\nlocal function createNearSettings''',
	r'''local function attach()
	for _,obj in ipairs(playerGui:GetDescendants()) do
		if typeof(obj)=="Instance" and isSettingsButton(obj) then
			if createNearSettings(obj) then return true end
		end
	end
	return false
end

local function createNearSettings''',
	text,
	count=1
)

text=re.sub(
	r'''local function attach\(\)[\s\S]*?\nend\n\ntask\.spawn''',
	r'''local function attach()
	for _,obj in ipairs(playerGui:GetDescendants()) do
		if typeof(obj)=="Instance" and isSettingsButton(obj) then
			if createNearSettings(obj) then return true end
		end
	end
	return false
end

task.spawn''',
	text,
	count=1
)

text=text.replace("for _,obj in playerGui:GetDescendants() do","for _,obj in ipairs(playerGui:GetDescendants()) do")
text=text.replace("for _,gui in playerGui:GetDescendants() do","for _,gui in ipairs(playerGui:GetDescendants()) do")

text=text.replace("if isSettingsButton(obj) then createNearSettings(obj) end","if typeof(obj)==\"Instance\" and isSettingsButton(obj) then createNearSettings(obj) end")

path.write_text(text.strip()+"\n",encoding="utf-8")
print("fixed DailyRewardHudButton attach nil call")