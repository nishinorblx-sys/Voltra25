from pathlib import Path
import re

root=Path.cwd()

print("DAILY REWARD JOIN OPEN PATH")
print("="*80)

hits=[]
for path in sorted((root/"src/client").rglob("*.lua")):
	text=path.read_text(encoding="utf-8",errors="ignore")
	low=text.lower()
	if "daily" in low and ("reward" in low or "login" in low):
		for i,line in enumerate(text.splitlines(),1):
			l=line.lower()
			if "daily" in l or "loginreward" in l or "show" in l or "open" in l or "claim" in l:
				hits.append((path,i,line.rstrip()))

for path,i,line in hits:
	print(f"{path.relative_to(root).as_posix()}:{i}: {line}")

candidates=[]
for path in sorted((root/"src/client").rglob("*.lua")):
	text=path.read_text(encoding="utf-8",errors="ignore")
	low=text.lower()
	if ("dailyloginrewardpanel" in low or "dailyreward" in low) and ("playeradded" in low or "flush" in low or "show" in low or "open" in low or "fireclient" in low or "onclientevent" in low):
		candidates.append(path)

if not candidates:
	raise SystemExit("No existing daily reward join popup code found. Paste the output above.")

target=None
for path in candidates:
	name=path.as_posix().lower()
	if "client" in name and ("daily" in name or "login" in name or "reward" in name):
		target=path
		break
target=target or candidates[0]

print()
print("USING EXISTING JOIN POPUP SCRIPT:",target.relative_to(root).as_posix())

button=Path("src/client/DailyRewardHudButton.client.lua")
if not button.exists():
	raise SystemExit("DailyRewardHudButton.client.lua missing")

button_text=button.read_text(encoding="utf-8",errors="ignore")

button_text=re.sub(
	r"local function openDailyRewards\(\)[\s\S]*?\nend\n\nlocal function removeExtraButtons",
	r'''local function openDailyRewards()
	local bindable=playerGui:FindFirstChild("VTROpenExistingDailyReward",true)
	if bindable and bindable:IsA("BindableEvent") then
		bindable:Fire()
		return
	end

	local root=script.Parent
	for _,module in {
		root:FindFirstChild("DailyLoginReward.client"),
		root:FindFirstChild("DailyReward.client"),
		root:FindFirstChild("Services") and root.Services:FindFirstChild("DailyLoginRewardClient"),
		root:FindFirstChild("Services") and root.Services:FindFirstChild("DailyRewardClient"),
	} do
		if module and module:IsA("ModuleScript") then
			local ok,result=pcall(require,module)
			if ok and result then
				for _,method in {"Open","Show","Flush","Prompt","Start"} do
					if type(result)=="table" and type(result[method])=="function" then
						local worked=pcall(function()
							result[method]()
						end)
						if worked then return end
						worked=pcall(function()
							result[method](playerGui)
						end)
						if worked then return end
					end
				end
			end
		end
	end

	warn("[Daily Rewards] Existing join-popup opener was not registered.")
end

local function removeExtraButtons''',
	button_text,
	count=1
)

button.write_text(button_text.strip()+"\n",encoding="utf-8")

join_text=target.read_text(encoding="utf-8",errors="ignore")
original=join_text

if "VTROpenExistingDailyReward" not in join_text:
	if "local Players" not in join_text:
		join_text='local Players=game:GetService("Players")\n'+join_text

	insert=r'''
local function vtrDailyRewardPlayerGui()
	local player=Players.LocalPlayer
	return player and player:WaitForChild("PlayerGui")
end

local function vtrRegisterDailyRewardOpen(openCallback)
	local playerGui=vtrDailyRewardPlayerGui()
	if not playerGui then return end
	local existing=playerGui:FindFirstChild("VTROpenExistingDailyReward")
	if existing then existing:Destroy() end
	local bindable=Instance.new("BindableEvent")
	bindable.Name="VTROpenExistingDailyReward"
	bindable.Parent=playerGui
	bindable.Event:Connect(function()
		openCallback()
	end)
end

'''

	m=re.search(r"\nlocal function\s+",join_text)
	if not m:
		m=re.search(r"\nfunction\s+",join_text)
	if m:
		join_text=join_text[:m.start()]+"\n"+insert+join_text[m.start():]
	else:
		join_text=insert+"\n"+join_text

possible_openers=[
	"showDailyReward",
	"showDailyRewards",
	"openDailyReward",
	"openDailyRewards",
	"showPanel",
	"openPanel",
	"renderPanel",
	"mountPanel",
	"show",
	"open",
]

registered=False
for name in possible_openers:
	if re.search(rf"local function {name}\s*\(",join_text) or re.search(rf"function [A-Za-z_][A-Za-z0-9_:.]*{name}\s*\(",join_text):
		call=f"\nvtrRegisterDailyRewardOpen(function(){name}()end)\n"
		if call.strip() not in join_text:
			idx=join_text.rfind("return ")
			if idx!=-1:
				join_text=join_text[:idx]+call+join_text[idx:]
			else:
				join_text+="\n"+call
		registered=True
		break

if not registered:
	panel_call=None
	for pattern in [
		r"(DailyLoginRewardPanel\.[A-Za-z_][A-Za-z0-9_]*\([^)]*\))",
		r"(DailyRewardPanel\.[A-Za-z_][A-Za-z0-9_]*\([^)]*\))",
	]:
		m=re.search(pattern,join_text)
		if m:
			panel_call=m.group(1)
			break
	if panel_call:
		call=f"\nvtrRegisterDailyRewardOpen(function(){panel_call}end)\n"
		idx=join_text.rfind("return ")
		if idx!=-1:
			join_text=join_text[:idx]+call+join_text[idx:]
		else:
			join_text+="\n"+call
		registered=True

if not registered:
	raise SystemExit("Found daily script but could not identify join popup function. Paste output above.")

if join_text!=original:
	target.write_text(join_text.strip()+"\n",encoding="utf-8")

print("patched button:",button.as_posix())
print("patched opener:",target.as_posix())