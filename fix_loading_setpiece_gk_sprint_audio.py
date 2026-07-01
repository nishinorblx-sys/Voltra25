from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

ui_sound_path = Path("src/client/Services/UISoundService.lua")
ui_sound_path.write_text('''--!strict
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Service = {}

local CLICK_SOUNDS = {
	"rbxassetid://99694938057192",
	"rbxassetid://100116561106520",
}

local HOVER_SOUNDS = {
	"rbxassetid://98484565371608",
}

local TYPE_SOUND = "rbxassetid://124938422635867"
local COLOR_SOUND = "rbxassetid://109229821869092"
local TRANSITION_SOUND = "rbxassetid://136186135240645"

local lastPlayed: {[string]: number} = {}
local preloaded = false

local function preload()
	if preloaded then return end
	preloaded = true
	local sounds = {}
	for _, id in CLICK_SOUNDS do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	for _, id in HOVER_SOUNDS do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	for _, id in {TYPE_SOUND, COLOR_SOUND, TRANSITION_SOUND} do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		for _, sound in sounds do
			sound:Destroy()
		end
	end)
end

local function play(id: string, volume: number, key: string?, cooldown: number?)
	preload()
	local now = os.clock()
	if key and cooldown and (lastPlayed[key] or 0) + cooldown > now then return end
	if key then lastPlayed[key] = now end
	local sound = Instance.new("Sound")
	sound.Name = "VTRUISound"
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		if sound.Parent then sound:Destroy() end
	end)
	sound:Play()
	task.delay(5, function()
		if sound.Parent then sound:Destroy() end
	end)
end

function Service.Preload()
	preload()
end

function Service.PlayClick()
	play(CLICK_SOUNDS[math.random(1, #CLICK_SOUNDS)], 0.42, "Click", 0.035)
end

function Service.PlayHover()
	play(HOVER_SOUNDS[1], 0.2, "Hover", 0.08)
end

function Service.PlayType()
	play(TYPE_SOUND, 0.32, "Type", 0.025)
end

function Service.PlayColor()
	play(COLOR_SOUND, 0.42, "Color", 0.05)
end

function Service.PlayTransition()
	play(TRANSITION_SOUND, 0.52, "Transition", 0.02)
end

function Service.Bind(root: Instance)
	preload()
	local function bindOne(item: Instance)
		if item:GetAttribute("VTRUISoundBound") == true then return end
		if item:IsA("GuiButton") then
			item:SetAttribute("VTRUISoundBound", true)
			item.MouseEnter:Connect(function()
				Service.PlayHover()
			end)
			item.Activated:Connect(function()
				Service.PlayClick()
			end)
		elseif item:IsA("TextBox") then
			item:SetAttribute("VTRUISoundBound", true)
			local previous = item.Text
			item:GetPropertyChangedSignal("Text"):Connect(function()
				if item.Text ~= previous then
					previous = item.Text
					Service.PlayType()
				end
			end)
		end
	end
	for _, item in ipairs(root:GetDescendants()) do
		bindOne(item)
	end
	root.DescendantAdded:Connect(bindOne)
end

preload()

return Service
''', encoding="utf-8", newline="\n")

app_path = Path("src/client/App.client.lua")
app = app_path.read_text(encoding="utf-8")

if "showMatchLoadSyncCover" not in app:
    app = app.replace(
'''local FocusController = require(script.Parent.Controllers.FocusController)
local MatchGameplayController = require(script.Parent.Gameplay.GameplayController)

FocusController.new():Start(Players.LocalPlayer:WaitForChild("PlayerGui"))
MatchGameplayController.new():Start()''',
'''local FocusController = require(script.Parent.Controllers.FocusController)
local MatchGameplayController = require(script.Parent.Gameplay.GameplayController)

local function showMatchLoadSyncCover()
	local data = TeleportService:GetLocalPlayerTeleportData()
	local matchTeleport = type(data) == "table" and (data.MatchMode == "Ranked1v1" or data.MatchMode == "AICampaignSolo")
	if not matchTeleport then return nil end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRMatchLoadSyncCover")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRMatchLoadSyncCover"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5000
	gui.Parent = playerGui
	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromHex("020402")
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(.5, .5)
	title.Position = UDim2.fromScale(.5, .44)
	title.Size = UDim2.fromScale(.78, .08)
	title.Font = Theme.Fonts.Display
	title.Text = data.MatchMode == "Ranked1v1" and "SYNCING MATCH" or "LOADING AI MATCH"
	title.TextColor3 = Theme.Colors.White
	title.TextSize = 36
	title.Parent = bg
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(.5, .5)
	sub.Position = UDim2.fromScale(.5, .52)
	sub.Size = UDim2.fromScale(.78, .05)
	sub.Font = Theme.Fonts.Strong
	sub.Text = "PREPARING CINEMATIC BROADCAST"
	sub.TextColor3 = Theme.Colors.Silver
	sub.TextSize = 11
	sub.Parent = bg
	task.spawn(function()
		local started = os.clock()
		while gui.Parent and os.clock() - started < 55 do
			local prematch = playerGui:FindFirstChild("VTRPrematchBroadcast")
			if prematch then
				task.wait(.35)
				break
			end
			task.wait(.05)
		end
		if gui.Parent then
			local tween = TweenService:Create(bg, TweenInfo.new(.18), {BackgroundTransparency = 1})
			tween:Play()
			task.delay(.2, function()
				if gui.Parent then gui:Destroy() end
			end)
		end
	end)
	return gui
end

showMatchLoadSyncCover()
FocusController.new():Start(Players.LocalPlayer:WaitForChild("PlayerGui"))
MatchGameplayController.new():Start()''',
        1
    )

app = app.replace(
'''		slash.BackgroundColor3 = index % 2 == 0 and Theme.Colors.Electric or Theme.Colors.Gunmetal
		slash.BackgroundTransparency = index % 2 == 0 and 0.8 or 0.38''',
'''		slash.BackgroundColor3 = Color3.fromHex("020402")
		slash.BackgroundTransparency = 1''',
    1
)

app_path.write_text(app, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = gameplay.replace(
'''	setMenuVisible(false)
	local bootCover = Instance.new("ScreenGui")''',
'''	setMenuVisible(false)
	player:SetAttribute("VTRInMatch", true)
	local bootCover = Instance.new("ScreenGui")''',
1
)

gameplay = gameplay.replace(
'''			if player.PlayerGui:FindFirstChild("VTRPrematchBroadcast") then
				task.wait(.18)
				break
			end''',
'''			if player.PlayerGui:FindFirstChild("VTRPrematchBroadcast") then
				task.wait(.45)
				break
			end''',
1
)

gameplay = gameplay.replace(
'''slash.BackgroundColor3=Color3.fromHex("B7FF1A");slash.BorderSizePixel=0;''',
'''slash.BackgroundColor3=Color3.fromHex("020402");slash.BackgroundTransparency=1;slash.BorderSizePixel=0;'''
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

cutscene_path = Path("src/client/Gameplay/MatchCutsceneController.lua")
cutscene = cutscene_path.read_text(encoding="utf-8")

cutscene = replace_once(
    cutscene,
'''	self.HUD:SetPhase(title)
	self.HUD:Flash(title, payload.Duration or 1.6)''',
'''	self.HUD:SetPhase(title)
	if payload.Kind ~= "ThrowIn" and payload.Kind ~= "Corner" and payload.Kind ~= "GoalKick" and payload.Kind ~= "FreeKick" then
		self.HUD:Flash(title, payload.Duration or 1.6)
	end''',
    "remove set piece flash overlay"
)

cutscene_path.write_text(cutscene, encoding="utf-8", newline="\n")

camera_path = Path("src/client/Gameplay/BroadcastCameraController.lua")
camera = camera_path.read_text(encoding="utf-8")

camera = camera.replace(
'''desired = self.PitchCFrame:PointToWorldSpace(Vector3.new(panX, 255, panZ))''',
'''desired = self.PitchCFrame:PointToWorldSpace(Vector3.new(panX * .72, 205, panZ * .72))''',
1
)

camera = camera.replace(
'''self.Camera.FieldOfView += ((alpha < .427 and 68 or alpha < .853 and 63 or 50) - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.16))''',
'''self.Camera.FieldOfView += ((alpha < .427 and 68 or alpha < .853 and 63 or 43) - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.16))''',
1
)

camera = camera.replace(
'''cameraLocal=Vector3.new((BROADCAST_SIDE_OFFSET+self.SideOffset)*side,150,self.Length*.04*(1-t))''',
'''cameraLocal=Vector3.new((BROADCAST_SIDE_OFFSET+self.SideOffset)*side*.82,124,self.Length*.025*(1-t))''',
1
)

camera = camera.replace(
'''self.Camera.FieldOfView += (42 - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.2))''',
'''self.Camera.FieldOfView += (38 - self.Camera.FieldOfView) * (1 - math.exp(-dt / 0.2))''',
1
)

camera_path.write_text(camera, encoding="utf-8", newline="\n")

team_path = Path("src/server/Gameplay/TeamControlService.lua")
team = team_path.read_text(encoding="utf-8")

if "function Service:_clampGoalkeeperBox" not in team:
    team = team.replace(
'''function Service:_isShotNearGoal(active: Model, aimPoint: Vector3?): boolean''',
'''function Service:_clampGoalkeeperBox(model: Model)
	if tostring(model:GetAttribute("position")) ~= "GK" then return end
	local modelRoot = root(model)
	if not modelRoot then return end
	local localPosition = self.PitchCFrame:PointToObjectSpace(modelRoot.Position)
	local goalSign = localPosition.Z >= 0 and 1 or -1
	local boxDepth = 142
	local zMin = goalSign > 0 and self.Length * .5 - boxDepth or -self.Length * .5 + 4
	local zMax = goalSign > 0 and self.Length * .5 - 4 or -self.Length * .5 + boxDepth
	if zMin > zMax then zMin, zMax = zMax, zMin end
	local clamped = Vector3.new(
		math.clamp(localPosition.X, -self.Width * .29, self.Width * .29),
		localPosition.Y,
		math.clamp(localPosition.Z, zMin, zMax)
	)
	if (clamped - localPosition).Magnitude > .15 then
		local world = self.PitchCFrame:PointToWorldSpace(clamped)
		local facing = Vector3.new(modelRoot.CFrame.LookVector.X, 0, modelRoot.CFrame.LookVector.Z)
		model:PivotTo(CFrame.lookAt(world, world + (facing.Magnitude > .05 and facing.Unit or self.PitchCFrame.LookVector)))
	end
end

function Service:_isShotNearGoal(active: Model, aimPoint: Vector3?): boolean''',
1
    )

team = team.replace(
'''			humanoid:Move(smoothed, false)
			DribbleControlService.Rotate(active, smoothed, ownsBall, sprinting, dt)''',
'''			humanoid:Move(smoothed, false)
			DribbleControlService.Rotate(active, smoothed, ownsBall, sprinting, dt)
			self:_clampGoalkeeperBox(active)''',
1
)

team_path.write_text(team, encoding="utf-8", newline="\n")

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

gk = gk.replace(
'''local keeper=goalkeeper(self.Teams[defendingSide]);if not keeper or keeper:GetAttribute("VTRGoalkeeperSaving")==true or self.BallService.Possession:GetOwner()==keeper then return end''',
'''local keeper=goalkeeper(self.Teams[defendingSide]);if not keeper or keeper:GetAttribute("VTRGoalkeeperSaving")==true or keeper:GetAttribute("controlledByUser")==true or self.BallService.Possession:GetOwner()==keeper then return end''',
1
)

gk_path.write_text(gk, encoding="utf-8", newline="\n")

stamina_path = Path("src/server/Gameplay/StaminaService.lua")
stamina = stamina_path.read_text(encoding="utf-8")

stamina = stamina.replace(
'''	local sprintLocked=model:GetAttribute("VTRSprintLocked")==true
	local sprinting = controlled and not sprintLocked and state.Sprinting == true and (tonumber(state.MoveMagnitude) or 0) > 0.1''',
'''	local sprintLocked=model:GetAttribute("VTRSprintLocked")==true and not controlled
	local sprinting = controlled and not sprintLocked and state.Sprinting == true and (tonumber(state.MoveMagnitude) or 0) > 0.1''',
1
)

stamina = stamina.replace(
'''		if not controlled then recovery*=Config.UnusedRecoveryMultiplier end
		reserve=math.min(endurance,reserve+recovery*dt)''',
'''		if not controlled then recovery=math.max(recovery*Config.UnusedRecoveryMultiplier,Config.IdleRecoveryMax*1.25) end
		reserve=math.min(endurance,reserve+recovery*dt)''',
1
)

stamina_path.write_text(stamina, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = runtime.replace(
'''local sprintLocked=active:GetAttribute("VTRSprintLocked")==true and active:GetAttribute("controlledByUser")~=true;local sprinting=not sprintLocked and(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0)>.1 and state.Stamina>=Config.Stamina.MinimumToSprint''',
'''local sprintLocked=active:GetAttribute("VTRSprintLocked")==true and active:GetAttribute("controlledByUser")~=true;local sprinting=not sprintLocked and(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0)>.1 and state.Stamina>=math.min(1,Config.Stamina.MinimumToSprint)''',
1
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

for path in [Path("src/client/Gameplay/ReplayController.lua"), Path("src/client/Components/VoltraMatchTeleport.lua")]:
    if path.exists():
        text = path.read_text(encoding="utf-8")
        text = text.replace('slash.BackgroundColor3 = Theme.Colors.Electric', 'slash.BackgroundColor3 = Color3.fromHex("020402")\n\tslash.BackgroundTransparency = 1')
        text = text.replace('slash.BackgroundColor3=Color3.fromHex("B7FF1A")', 'slash.BackgroundColor3=Color3.fromHex("020402");slash.BackgroundTransparency=1')
        path.write_text(text, encoding="utf-8", newline="\n")

print("fixed loading cover, set piece overlay, kickoff zoom, goalkeeper control, sprint stamina, and transition audio preload")