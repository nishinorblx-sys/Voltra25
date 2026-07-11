from pathlib import Path
import re
import subprocess

root=Path.cwd()
client=root/"src/client"
button_path=client/"DailyRewardHudButton.client.lua"

print("CURRENT DAILY PANEL REFERENCES")
print("="*90)

refs=[]
for path in sorted(client.rglob("*.lua")):
	if path==button_path:
		continue
	text=path.read_text(encoding="utf-8",errors="ignore")
	if "DailyLoginRewardPanel" in text or "SevenWinLoginRewardPanel" in text or "DailyRewardPanel" in text:
		for i,line in enumerate(text.splitlines(),1):
			if "DailyLoginRewardPanel" in line or "SevenWinLoginRewardPanel" in line or "DailyRewardPanel" in line or "OnClientEvent" in line or "PlayerAdded" in line:
				print(f"{path.relative_to(root).as_posix()}:{i}: {line.rstrip()}")
		refs.append(path)

print()
print("HISTORY DAILY PANEL REFERENCES")
print("="*90)
hist=subprocess.run(["git","log","--all","--format=%h %s","-G","DailyLoginRewardPanel|SevenWinLoginRewardPanel|DailyRewardPanel","--","src/client"],capture_output=True,text=True)
print(hist.stdout)

if not refs:
	raise SystemExit("No existing daily reward panel client reference found")

target=None
target_function=None
target_args=None
target_pos=None

decl_pattern=re.compile(r'(local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\))')

for path in refs:
	text=path.read_text(encoding="utf-8",errors="ignore")
	for keyword in ["DailyLoginRewardPanel","DailyRewardPanel","SevenWinLoginRewardPanel"]:
		idx=text.find(keyword)
		while idx!=-1:
			prefix=text[:idx]
			decls=list(decl_pattern.finditer(prefix))
			if decls:
				decl=decls[-1]
				name=decl.group(2)
				args=decl.group(3)
				window=text[decl.start():min(len(text),idx+2600)]
				score=0
				for term in ["OnClientEvent","FireClient","Flush","Queue","Show","Open","Panel","Reward","Claim"]:
					if term.lower() in window.lower():
						score+=1
				if target is None or score>=2:
					target=path
					target_function=name
					target_args=args
					target_pos=decl.start()
					break
			idx=text.find(keyword,idx+1)
		if target:
			break
	if target:
		break

if not target:
	raise SystemExit("Could not find the local function that opens the existing daily panel")

print("PATCHING EXISTING JOIN PANEL OPENER")
print(target.relative_to(root).as_posix(), target_function, target_args)

text=target.read_text(encoding="utf-8",errors="ignore")

if "game:GetService(\"Players\")" not in text:
	text='local Players=game:GetService("Players")\n'+text

if "vtrDailyRewardLastArgs" not in text:
	func_decl=re.search(rf'local\s+function\s+{re.escape(target_function)}\s*\(([^)]*)\)',text)
	if not func_decl:
		raise SystemExit("target function moved during patch")
	args=func_decl.group(1)
	names=[]
	for raw in args.split(","):
		item=raw.strip()
		if not item:
			continue
		if item=="...":
			names.append("...")
			continue
		item=item.split(":")[0].strip()
		item=item.split("=")[0].strip()
		if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$",item):
			names.append(item)
	pack="table.pack("+",".join(names)+")"
	insert="\nlocal vtrDailyRewardLastArgs=nil\n"
	text=text[:func_decl.start()]+insert+text[func_decl.start():]
	func_decl=re.search(rf'local\s+function\s+{re.escape(target_function)}\s*\(([^)]*)\)',text)
	line_end=text.find("\n",func_decl.end())
	text=text[:line_end+1]+"\tvtrDailyRewardLastArgs="+pack+"\n"+text[line_end+1:]

if "VTROpenExistingDailyReward" not in text:
	registry=f'''
local function vtrOpenExistingDailyRewardPanel()
	if vtrDailyRewardLastArgs then
		return {target_function}(table.unpack(vtrDailyRewardLastArgs,1,vtrDailyRewardLastArgs.n))
	end
	return {target_function}()
end

task.defer(function()
	local player=Players.LocalPlayer
	if not player then return end
	local playerGui=player:WaitForChild("PlayerGui")
	local existing=playerGui:FindFirstChild("VTROpenExistingDailyReward")
	if existing then existing:Destroy() end
	local bindable=Instance.new("BindableEvent")
	bindable.Name="VTROpenExistingDailyReward"
	bindable.Parent=playerGui
	bindable.Event:Connect(function()
		vtrOpenExistingDailyRewardPanel()
	end)
end)

'''
	ret=text.rfind("\nreturn ")
	if ret!=-1:
		text=text[:ret]+registry+text[ret:]
	else:
		text=text.strip()+"\n\n"+registry

target.write_text(text.strip()+"\n",encoding="utf-8")

button_code=r'''
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
	local bindable=playerGui:FindFirstChild("VTROpenExistingDailyReward",true)
	if bindable and bindable:IsA("BindableEvent") then
		bindable:Fire()
		return
	end
	warn("[Daily Rewards] Existing join popup opener is not ready yet.")
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

button_path.write_text(button_code.strip()+"\n",encoding="utf-8")
print("patched button route to real existing join popup")
print("button",button_path.relative_to(root).as_posix())
print("opener",target.relative_to(root).as_posix())