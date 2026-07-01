from pathlib import Path
import json
import re
import subprocess

def run_git(args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if result.returncode == 0 and result.stdout is not None:
            return result.stdout
    except Exception:
        return ""
    return ""

def color_pair(old, new):
    return (
        ("Theme.Colors.Electric" in old and "Theme.Colors.White" in new)
        or ('Color3.fromHex("B7FF1A")' in old and 'Color3.fromHex("FFFFFF")' in new)
        or ("Color3.fromRGB(183, 255, 26)" in old and "Color3.fromRGB(255, 255, 255)" in new)
    )

def restore_ui_colors():
    paths = set()
    for args in [
        ["git", "diff", "--name-only", "--", "src/client"],
        ["git", "diff", "--name-only", "HEAD~1..HEAD", "--", "src/client"],
        ["git", "diff", "--name-only", "HEAD~2..HEAD", "--", "src/client"],
    ]:
        for line in run_git(args).splitlines():
            if line.endswith(".lua") and Path(line).exists():
                paths.add(line)

    restored = []
    for name in sorted(paths):
        path = Path(name)
        current = path.read_text(encoding="utf-8")
        original = current
        for args in [
            ["git", "diff", "-U0", "--", name],
            ["git", "diff", "-U0", "HEAD~1..HEAD", "--", name],
            ["git", "diff", "-U0", "HEAD~2..HEAD", "--", name],
        ]:
            diff = run_git(args)
            removed = []
            for line in diff.splitlines():
                if line.startswith("---") or line.startswith("+++") or line.startswith("@@"):
                    removed = []
                    continue
                if line.startswith("-"):
                    removed.append(line[1:])
                    continue
                if line.startswith("+"):
                    added = line[1:]
                    for old in removed:
                        if color_pair(old, added):
                            current = current.replace(added, old)
                    removed = []
        if current != original:
            path.write_text(current, encoding="utf-8", newline="\n")
            restored.append(name)
    return restored

restored = restore_ui_colors()

project_path = Path("default.project.json")
project = json.loads(project_path.read_text(encoding="utf-8"))
tree = project.setdefault("tree", {})
tree.setdefault("ReplicatedFirst", {})["$path"] = "src/replicatedfirst"
project_path.write_text(json.dumps(project, indent=2) + "\n", encoding="utf-8", newline="\n")

replicated_first = Path("src/replicatedfirst")
replicated_first.mkdir(parents=True, exist_ok=True)

(replicated_first / "LoadingCover.client.lua").write_text('''local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local teleportData = TeleportService:GetLocalPlayerTeleportData()
local isMatchTeleport = type(teleportData) == "table" and (teleportData.MatchMode == "Ranked1v1" or teleportData.MatchMode == "AICampaignSolo")

local old = playerGui:FindFirstChild("VTRReplicatedFirstCover")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "VTRReplicatedFirstCover"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.BackgroundColor3 = Color3.fromRGB(2, 4, 2)
bg.BorderSizePixel = 0
bg.Size = UDim2.fromScale(1, 1)
bg.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(.5, .5)
title.Position = UDim2.fromScale(.5, .43)
title.Size = UDim2.fromScale(.82, .08)
title.Font = Enum.Font.GothamBlack
title.Text = isMatchTeleport and "SYNCING MATCH" or "VOLTRA"
title.TextColor3 = Color3.fromRGB(245, 247, 242)
title.TextSize = 34
title.Parent = bg

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.AnchorPoint = Vector2.new(.5, .5)
sub.Position = UDim2.fromScale(.5, .51)
sub.Size = UDim2.fromScale(.82, .05)
sub.Font = Enum.Font.GothamBold
sub.Text = isMatchTeleport and "WAITING FOR PRESENTATION" or "LOADING"
sub.TextColor3 = Color3.fromRGB(190, 195, 186)
sub.TextSize = 11
sub.Parent = bg

local spinner = Instance.new("Frame")
spinner.BackgroundTransparency = 1
spinner.AnchorPoint = Vector2.new(.5, .5)
spinner.Position = UDim2.fromScale(.5, .61)
spinner.Size = UDim2.fromOffset(58, 58)
spinner.Parent = bg

for index = 1, 12 do
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(.5, .5)
	dot.Size = UDim2.fromOffset(7, 7)
	dot.BackgroundColor3 = Color3.fromRGB(245, 247, 242)
	dot.BackgroundTransparency = .18 + index * .045
	dot.BorderSizePixel = 0
	local angle = math.rad(index * 30)
	dot.Position = UDim2.fromScale(.5 + math.cos(angle) * .38, .5 + math.sin(angle) * .38)
	dot.Parent = spinner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
end

local spinning = true
local connection = RunService.RenderStepped:Connect(function(dt)
	if spinning and spinner.Parent then
		spinner.Rotation += dt * 210
	end
end)

local function release()
	if not gui.Parent then return end
	spinning = false
	if connection then connection:Disconnect() end
	for _, item in ipairs(bg:GetDescendants()) do
		if item:IsA("TextLabel") then
			TweenService:Create(item, TweenInfo.new(.16), {TextTransparency = 1}):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, TweenInfo.new(.16), {BackgroundTransparency = 1}):Play()
		end
	end
	TweenService:Create(bg, TweenInfo.new(.18), {BackgroundTransparency = 1}):Play()
	task.delay(.22, function()
		if gui.Parent then gui:Destroy() end
	end)
end

task.spawn(function()
	local started = os.clock()
	if isMatchTeleport then
		while gui.Parent and os.clock() - started < 70 do
			if playerGui:FindFirstChild("VTRPrematchBroadcast") or playerGui:FindFirstChild("VTRMatchBootCover") then
				task.wait(.45)
				release()
				return
			end
			task.wait(.04)
		end
	else
		while gui.Parent and os.clock() - started < 18 do
			if playerGui:FindFirstChild("VTR25") or playerGui:FindFirstChild("VTRApp") or playerGui:FindFirstChild("VTRMainMenu") then
				task.wait(.2)
				release()
				return
			end
			task.wait(.05)
		end
	end
	release()
end)
''', encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

if 'local Lighting=game:GetService("Lighting")' not in gameplay:
    gameplay = gameplay.replace(
        'local UserInputService=game:GetService("UserInputService")',
        'local UserInputService=game:GetService("UserInputService")\nlocal Lighting=game:GetService("Lighting")',
        1
    )

if "local function clearGreenScreenEffects()" not in gameplay:
    gameplay = gameplay.replace(
'''local Controller={};Controller.__index=Controller''',
'''local Controller={};Controller.__index=Controller
local function clearGreenScreenEffects()
	for _, inst in ipairs(Lighting:GetChildren()) do
		if inst:IsA("ColorCorrectionEffect") then
			local tint = inst.TintColor
			local greenTint = tint.G > tint.R + .08 and tint.G > tint.B + .08
			local named = string.find(string.lower(inst.Name), "green") or string.find(string.lower(inst.Name), "setpiece") or string.find(string.lower(inst.Name), "vtr")
			if greenTint or named then
				inst.Enabled = false
				inst.TintColor = Color3.new(1, 1, 1)
				inst.Saturation = 0
				inst.Contrast = 0
				inst.Brightness = 0
			end
		end
	end
	if Lighting.ColorShift_Top.G > Lighting.ColorShift_Top.R + .08 and Lighting.ColorShift_Top.G > Lighting.ColorShift_Top.B + .08 then
		Lighting.ColorShift_Top = Color3.new(0, 0, 0)
	end
	if Lighting.ColorShift_Bottom.G > Lighting.ColorShift_Bottom.R + .08 and Lighting.ColorShift_Bottom.G > Lighting.ColorShift_Bottom.B + .08 then
		Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	end
end''',
        1
    )

if "task.spawn(function()\n\t\twhile self.Active do\n\t\t\tclearGreenScreenEffects()" not in gameplay:
    gameplay = gameplay.replace(
'''	self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.WatchMode then self.Input:SetSuppressed(true);if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))''',
'''	self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.WatchMode then self.Input:SetSuppressed(true);if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))
	task.spawn(function()
		while self.Active do
			clearGreenScreenEffects()
			task.wait(.35)
		end
	end)''',
1
    )

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

print("fixed gameplay nil error, loading circle, and green tint cleanup")
if restored:
    print("restored UI colors:")
    for item in restored:
        print(item)