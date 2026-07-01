from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

prompt_path = Path("src/client/Components/AIMatchModePrompt.lua")
prompt_path.parent.mkdir(parents=True, exist_ok=True)

if not prompt_path.exists():
    prompt_path.write_text('''local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Prompt = {}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function stroke(parent, color, transparency, thickness)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Transparency = transparency
	item.Thickness = thickness or 1
	item.Parent = parent
end

local function label(parent, text, position, size, textSize, color)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = text
	item.TextColor3 = color
	item.TextSize = textSize
	item.Font = Theme.Fonts.Display
	item.TextXAlignment = Enum.TextXAlignment.Center
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.ZIndex = 303
	item.Parent = parent
	return item
end

local function makeButton(parent, name, title, subtitle, position, color)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Position = position
	item.Size = UDim2.fromScale(.42, .34)
	item.BackgroundColor3 = Color3.fromHex("070A06")
	item.BackgroundTransparency = .04
	item.BorderSizePixel = 0
	item.AutoButtonColor = true
	item.Text = ""
	item.ZIndex = 304
	item.Parent = parent
	corner(item, 12)
	stroke(item, color, .12, 2)
	local glow = Instance.new("Frame")
	glow.Position = UDim2.fromScale(.06, .1)
	glow.Size = UDim2.fromScale(.88, .22)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = .06
	glow.BorderSizePixel = 0
	glow.ZIndex = 305
	glow.Parent = item
	corner(glow, 8)
	label(item, title, UDim2.fromScale(.06, .33), UDim2.fromScale(.88, .24), 20, Theme.Colors.White)
	local sub = label(item, subtitle, UDim2.fromScale(.08, .6), UDim2.fromScale(.84, .24), 10, Color3.fromHex("C9D0C3"))
	sub.Font = Theme.Fonts.Strong
	return item
end

function Prompt.Choose()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRAIMatchModePrompt")
	if old then old:Destroy() end
	local done = Instance.new("BindableEvent")
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRAIMatchModePrompt"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 430
	gui.Parent = playerGui
	local overlay = Instance.new("CanvasGroup")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromHex("030503")
	overlay.BackgroundTransparency = .08
	overlay.GroupTransparency = 1
	overlay.Active = true
	overlay.ZIndex = 300
	overlay.Parent = gui
	local panel = Instance.new("CanvasGroup")
	panel.AnchorPoint = Vector2.new(.5, .5)
	panel.Position = UDim2.fromScale(.5, .52)
	panel.Size = UDim2.fromOffset(620, 330)
	panel.BackgroundColor3 = Color3.fromHex("081008")
	panel.BackgroundTransparency = .02
	panel.BorderSizePixel = 0
	panel.GroupTransparency = 1
	panel.ZIndex = 302
	panel.Parent = overlay
	corner(panel, 18)
	stroke(panel, Theme.Colors.Electric, .18, 2)
	local scale = Instance.new("UIScale")
	scale.Scale = .86
	scale.Parent = panel
	label(panel, "AI CAMPAIGN FIXTURE", UDim2.fromScale(.12, .08), UDim2.fromScale(.76, .08), 12, Theme.Colors.Electric)
	label(panel, "CHOOSE MATCH MODE", UDim2.fromScale(.08, .16), UDim2.fromScale(.84, .15), 31, Theme.Colors.White)
	local manual = makeButton(panel, "ManualPlay", "MANUALLY PLAY", "Control your squad on the pitch", UDim2.fromScale(.06, .43), Theme.Colors.Electric)
	local manage = makeButton(panel, "ManageMatch", "MANAGE MATCH", "AI plays while you manage tactics", UDim2.fromScale(.52, .43), Color3.fromHex("D9D9D9"))
	local cancel = Instance.new("TextButton")
	cancel.Name = "Cancel"
	cancel.AnchorPoint = Vector2.new(.5, 1)
	cancel.Position = UDim2.fromScale(.5, .96)
	cancel.Size = UDim2.fromOffset(180, 30)
	cancel.BackgroundColor3 = Color3.fromHex("111611")
	cancel.BackgroundTransparency = .12
	cancel.BorderSizePixel = 0
	cancel.Text = "CANCEL"
	cancel.TextColor3 = Color3.fromHex("F5F7F2")
	cancel.TextSize = 10
	cancel.Font = Theme.Fonts.Strong
	cancel.ZIndex = 305
	cancel.Parent = panel
	corner(cancel, 8)
	stroke(cancel, Color3.fromHex("F5F7F2"), .62)
	local settled = false
	local function choose(value)
		if settled then return end
		settled = true
		TweenService:Create(panel, TweenInfo.new(.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1, Position = UDim2.fromScale(.5, .56)}):Play()
		TweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 1}):Play()
		task.delay(.2, function()
			if gui.Parent then gui:Destroy() end
			done:Fire(value)
			done:Destroy()
		end)
	end
	manual.Activated:Connect(function() choose("Manual") end)
	manage.Activated:Connect(function() choose("Manage") end)
	cancel.Activated:Connect(function() choose(nil) end)
	TweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 0}):Play()
	TweenService:Create(panel, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {GroupTransparency = 0, Position = UDim2.fromScale(.5, .5)}):Play()
	TweenService:Create(scale, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	return done.Event:Wait()
end

return Prompt
''', encoding="utf-8", newline="\n")

teleport_path = Path("src/client/Components/VoltraMatchTeleport.lua")
if not teleport_path.exists():
    teleport_path.write_text('''local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Teleport = {}

function Teleport.Run(title, callback)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRMatchTeleport")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRMatchTeleport"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 440
	gui.Parent = playerGui
	local overlay = Instance.new("CanvasGroup")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromHex("020402")
	overlay.GroupTransparency = 1
	overlay.ZIndex = 390
	overlay.Parent = gui
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(.5, .5)
	text.Position = UDim2.fromScale(.5, .47)
	text.Size = UDim2.fromScale(.8, .1)
	text.Text = string.upper(title)
	text.TextColor3 = Theme.Colors.White
	text.TextSize = 34
	text.Font = Theme.Fonts.Display
	text.ZIndex = 392
	text.Parent = overlay
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(.5, .5)
	sub.Position = UDim2.fromScale(.5, .56)
	sub.Size = UDim2.fromScale(.8, .04)
	sub.Text = "CINEMATIC MATCH LOADING"
	sub.TextColor3 = Theme.Colors.Electric
	sub.TextSize = 11
	sub.Font = Theme.Fonts.Strong
	sub.ZIndex = 392
	sub.Parent = overlay
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(.5, .5)
	bar.Position = UDim2.fromScale(.5, .62)
	bar.Size = UDim2.fromScale(.38, .008)
	bar.BackgroundColor3 = Color3.fromHex("111711")
	bar.BorderSizePixel = 0
	bar.ZIndex = 392
	bar.Parent = overlay
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Colors.Electric
	fill.BorderSizePixel = 0
	fill.ZIndex = 393
	fill.Parent = bar
	TweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 0}):Play()
	TweenService:Create(fill, TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
	task.wait(.35)
	local result = callback()
	task.wait(1.15)
	TweenService:Create(overlay, TweenInfo.new(.26), {GroupTransparency = 1}):Play()
	task.delay(.28, function()
		if gui.Parent then gui:Destroy() end
	end)
	return result
end

return Teleport
''', encoding="utf-8", newline="\n")
else:
    teleport = teleport_path.read_text(encoding="utf-8")
    teleport = teleport.replace('task.wait(.28)\n\tTweenService:Create(overlay', 'task.wait(1.15)\n\tTweenService:Create(overlay')
    teleport = teleport.replace('TELEPORTING TO VOLTRA MATCH', 'CINEMATIC MATCH LOADING')
    teleport_path.write_text(teleport, encoding="utf-8", newline="\n")

service_path = Path("src/client/Services/MatchSetupService.lua")
service = service_path.read_text(encoding="utf-8")

if "AIMatchModePrompt" not in service:
    service = service.replace(
        'local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)',
        'local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)\nlocal AIMatchModePrompt=require(script:FindFirstAncestor("VTRClient").Components.AIMatchModePrompt)\nlocal VoltraMatchTeleport=require(script:FindFirstAncestor("VTRClient").Components.VoltraMatchTeleport)',
        1
    )

if "function Service:StartCampaignMatch" not in service:
    service = service.replace(
        'function Service:LeaveRankedQueue():any return request("LeaveRankedQueue")end',
        '''function Service:StartCampaignMatch():any
	local choice=AIMatchModePrompt.Choose()
	if choice=="Manual"then
		return VoltraMatchTeleport.Run("Manual Campaign Match",function()
			return request("StartMatch",{AIMatchTeleport=true,CampaignMode="Manual"})
		end)
	elseif choice=="Manage"then
		return VoltraMatchTeleport.Run("Manage Campaign Match",function()
			return request("WatchMatch",{AIMatchTeleport=true,CampaignMode="Manage"})
		end)
	end
	return{Success=false,Message="Match cancelled."}
end
function Service:LeaveRankedQueue():any return request("LeaveRankedQueue")end''',
        1
    )

if "VoltraMatchTeleport" not in service:
    service = service.replace(
        'local AIMatchModePrompt=require(script:FindFirstAncestor("VTRClient").Components.AIMatchModePrompt)',
        'local AIMatchModePrompt=require(script:FindFirstAncestor("VTRClient").Components.AIMatchModePrompt)\nlocal VoltraMatchTeleport=require(script:FindFirstAncestor("VTRClient").Components.VoltraMatchTeleport)'
    )

service_path.write_text(service, encoding="utf-8", newline="\n")

patched_files = []

for path in Path("src/client").rglob("*.lua"):
    if path == service_path or path == prompt_path or path == teleport_path:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text
    if "CampaignTeamId" in text or "CampaignProgress" in text or "CampaignTier" in text or "campaign" in text.lower():
        text = re.sub(r'([A-Za-z_][A-Za-z0-9_\.]*):WatchMatch\(\)', r'\1:StartCampaignMatch()', text)
        text = re.sub(r'([A-Za-z_][A-Za-z0-9_\.]*):StartMatch\(\)', r'\1:StartCampaignMatch()', text)
        text = re.sub(r'([A-Za-z_][A-Za-z0-9_\.]*):WatchMatch\((\s*)\)', r'\1:StartCampaignMatch()', text)
        text = re.sub(r'([A-Za-z_][A-Za-z0-9_\.]*):StartMatch\((\s*)\)', r'\1:StartCampaignMatch()', text)
    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        patched_files.append(str(path))

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = runtime.replace(
    'if opponent and opponent.Character then local opponentRoot=opponent.Character:FindFirstChild("HumanoidRootPart")::BasePart?;if opponentRoot then opponent.Character:PivotTo(world.PitchCFrame*CFrame.new(0,-30,0));opponentRoot.Anchored=true;opponent.Character:SetAttribute("VTRParked",true)end end',
    '''local parkedReturnCFrames:any={}
	for index,participant in players do
		local character=participant.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")::BasePart?
		if character and root then
			parkedReturnCFrames[participant]=character:GetPivot()
			character:PivotTo(world.PitchCFrame*CFrame.new(index==1 and -10 or 10,-85,0))
			root.Anchored=true
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
			character:SetAttribute("VTRParked",true)
			character:SetAttribute("VTRCinematicParked",true)
		end
	end''',
    1
)

runtime = runtime.replace(
    'ReturnCFrame=CFrame.new(0,8,0)',
    'ReturnCFrame=parkedReturnCFrames[participant] or CFrame.new(0,8,0)',
    1
)

runtime = runtime.replace(
    'character:SetAttribute("VTRParked",nil);character:SetAttribute("VTRSession",nil);character:SetAttribute("VTRSprinting",nil);character:PivotTo',
    'character:SetAttribute("VTRParked",nil);character:SetAttribute("VTRCinematicParked",nil);character:SetAttribute("VTRSession",nil);character:SetAttribute("VTRSprinting",nil);character:PivotTo'
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

print("campaign fixture popup patched")
print("cinematic player parking patched")
if patched_files:
    print("campaign UI files changed:")
    for item in patched_files:
        print(item)
else:
    print("no campaign card file was auto-patched; Service:StartCampaignMatch is available for fixture buttons")