from pathlib import Path
import re

path=Path("src/client/DailyRewardHudButton.client.lua")
text=path.read_text(encoding="utf-8",errors="ignore")

text=re.sub(
	r'''local function openDailyRewards\(\)[\s\S]*?\nend\n\nlocal function removeExtraButtons''',
	r'''local function openDailyRewards()
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

local function removeExtraButtons''',
	text,
	count=1
)

text=text.replace("pcall(function() opener:Activate() end)","")
text=text.replace("pcall(function() opener.Activated:Fire() end)","")
text=text.replace("pcall(function() opener.MouseButton1Click:Fire() end)","")
text=text.replace("opener:Activate()","")
text=text.replace("opener.Activated:Fire()","")
text=text.replace("opener.MouseButton1Click:Fire()","")
text=text.replace("button.MouseButton1Click:Connect(openDailyRewards)","")

path.write_text(text.strip()+"\n",encoding="utf-8")
print("removed invalid DailyRewardHudButton click calls")