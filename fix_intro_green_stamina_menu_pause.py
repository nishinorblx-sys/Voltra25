from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

presentation_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
presentation = presentation_path.read_text(encoding="utf-8")

if "VTRIntroAudio" not in presentation:
    presentation = presentation.replace(
'''local STARTING_XI_SOUND_ONE = "rbxassetid://111250989374137"
local STARTING_XI_SOUND_TWO = "rbxassetid://76843129252399"''',
'''local STARTING_XI_SOUNDS = {
	"rbxassetid://111250989374137",
	"rbxassetid://76843129252399",
	"rbxassetid://99361731737732",
}
local introSound: Sound? = nil'''
    )

    presentation = re.sub(
r'''local function playPresentationSound\(soundId: string, volume: number\?\)
.*?
end''',
'''local function playPresentationSound(soundId: string, volume: number?)
	if introSound and introSound.Parent then return end
	local sound = Instance.new("Sound")
	sound.Name = "VTRIntroAudio"
	sound.SoundId = soundId
	sound.Volume = volume or .62
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	introSound = sound
	sound:Play()
end

local function stopPresentationSound()
	if introSound then
		introSound:Stop()
		introSound:Destroy()
		introSound = nil
	end
end''',
presentation,
count=1,
flags=re.S
    )

presentation = re.sub(
r'''playPresentationSound\(STARTING_XI_SOUND_ONE,\s*\.66\)''',
'''playPresentationSound(STARTING_XI_SOUNDS[math.random(1,#STARTING_XI_SOUNDS)],.66)''',
presentation
)

presentation = re.sub(
r'''playPresentationSound\(STARTING_XI_SOUND_TWO,\s*\.66\)''',
'''playPresentationSound(STARTING_XI_SOUNDS[math.random(1,#STARTING_XI_SOUNDS)],.66)''',
presentation
)

presentation = presentation.replace(
'''		if gui.Parent then gui:Destroy() end
		if onComplete then onComplete() end''',
'''		stopPresentationSound()
		if gui.Parent then gui:Destroy() end
		if onComplete then onComplete() end''',
1
)

presentation_path.write_text(presentation, encoding="utf-8", newline="\n")

cutscene_path = Path("src/client/Gameplay/MatchCutsceneController.lua")
cutscene = cutscene_path.read_text(encoding="utf-8")

cutscene = cutscene.replace(
'''	if gui then gui:Destroy() end''',
'''	if PrematchBroadcastPresentation.StopAudio then
		PrematchBroadcastPresentation.StopAudio()
	end
	if gui then gui:Destroy() end''',
1
)

cutscene_path.write_text(cutscene, encoding="utf-8", newline="\n")

presentation = presentation_path.read_text(encoding="utf-8")
if "Presentation.StopAudio" not in presentation:
    presentation = presentation.replace(
'''return Presentation''',
'''function Presentation.StopAudio()
	stopPresentationSound()
end

return Presentation'''
    )
presentation_path.write_text(presentation, encoding="utf-8", newline="\n")

stamina_path = Path("src/server/Gameplay/StaminaService.lua")
stamina = stamina_path.read_text(encoding="utf-8")

stamina = re.sub(
r'''function Service:Step\(model: Model, dt: number, state: any\): \(number,number\)
.*?
end''',
'''function Service:Step(model: Model, dt: number, state: any): (number,number)
	local staminaStat = math.clamp(tonumber(model:GetAttribute("Stamina")) or 65, 1, 99)
	local reserve = math.clamp(tonumber(model:GetAttribute("VTRSprintStamina")) or tonumber(model:GetAttribute("VTRStamina")) or Config.Maximum, 0, Config.Maximum)
	local sprintDuration = math.max(0, tonumber(model:GetAttribute("VTRSprintDuration")) or 0)
	local controlled = state.UserControlled == true
	local sprintLocked = model:GetAttribute("VTRSprintLocked") == true and not controlled
	local sprinting = controlled and not sprintLocked and state.Sprinting == true and (tonumber(state.MoveMagnitude) or 0) > 0.1
	local speed = math.max(0, tonumber(state.CurrentSpeed) or 0)
	local quality = math.clamp((staminaStat - 35) / 64, 0, 1)
	local endurance = Config.Maximum

	if sprinting then
		sprintDuration += dt
		local speedModifier = 0.9 + math.clamp(speed / 30, 0, 1) * 0.16
		local durationModifier = 1 + math.clamp(sprintDuration / Config.SprintDurationRampSeconds, 0, 1) * Config.SprintDurationMaxPenalty
		local possessionModifier = state.HasBall == true and 1.04 or 1
		local drain = (Config.SprintReserveDrainMax - (Config.SprintReserveDrainMax - Config.SprintReserveDrainMin) * quality) * buildModifier(model) * positionModifier(model) * speedModifier * durationModifier * possessionModifier
		reserve = math.max(0, reserve - drain * dt)
	else
		sprintDuration = math.max(0, sprintDuration - dt * 2.1)
		local idle = speed < 5
		local recovery = idle and (Config.IdleRecoveryMin + (Config.IdleRecoveryMax - Config.IdleRecoveryMin) * quality) or (Config.JogRecoveryMin + (Config.JogRecoveryMax - Config.JogRecoveryMin) * quality)
		if not controlled then
			recovery = math.max(recovery * Config.UnusedRecoveryMultiplier, Config.IdleRecoveryMax * 1.35)
		end
		reserve = math.min(Config.Maximum, reserve + recovery * dt)
	end

	if reserve <= .05 then
		sprintLocked = true
	elseif sprintLocked and reserve >= Config.ExhaustedRecoveryThreshold then
		sprintLocked = false
	end

	model:SetAttribute("VTREndurance", Config.Maximum)
	model:SetAttribute("VTRSprintStamina", reserve)
	model:SetAttribute("VTRStamina", reserve)
	model:SetAttribute("VTRSprintDuration", sprintDuration)
	model:SetAttribute("VTRSprintLocked", sprintLocked)
	return reserve, Config.Maximum
end''',
stamina,
count=1,
flags=re.S
)

stamina_path.write_text(stamina, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = runtime.replace(
'''		if not session.Running then continue end
		session.Accumulator+=dt;session.Clock:Step(dt)''',
'''		if session.Paused or session.ManualPaused then
			continue
		end
		if not session.Running then continue end
		session.Accumulator+=dt;session.Clock:Step(dt)''',
1
)

runtime = runtime.replace(
'''			if requester and session.PauseSecondsByPlayer and (session.PauseSecondsByPlayer[requester] or 0)<=0 then self:_resumePause(session)end''',
'''			if requester and session.PauseSecondsByPlayer and (session.PauseSecondsByPlayer[requester] or 0)<=0 then self:_resumePause(session)end'''
)

runtime = re.sub(
r'''function Service:_pause\(session:any,.*?end''',
'''function Service:_pause(session:any, requester:Player?)
	session.ManualPaused = true
	session.Paused = true
	if session.World and session.World.Ball then
		session.World.Ball:SetAttribute("VTRPauseSavedVelocity", session.World.Ball.AssemblyLinearVelocity)
		session.World.Ball:SetAttribute("VTRPauseSavedAngularVelocity", session.World.Ball.AssemblyAngularVelocity)
		session.World.Ball.Anchored = true
	end
	for _, model in session.Models or {} do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			model:SetAttribute("VTRPauseSavedVelocity", root.AssemblyLinearVelocity)
			model:SetAttribute("VTRPauseSavedAngularVelocity", root.AssemblyAngularVelocity)
			root.Anchored = true
		end
	end
	broadcast(self.State, session, {Type="Pause", Active=true, Requester=requester})
end''',
runtime,
count=1,
flags=re.S
)

runtime = re.sub(
r'''function Service:_resumePause\(session:any\)
.*?
end''',
'''function Service:_resumePause(session:any)
	session.ManualPaused = false
	session.Paused = false
	if session.World and session.World.Ball then
		local velocity = session.World.Ball:GetAttribute("VTRPauseSavedVelocity")
		local angular = session.World.Ball:GetAttribute("VTRPauseSavedAngularVelocity")
		session.World.Ball.Anchored = false
		if typeof(velocity) == "Vector3" then session.World.Ball.AssemblyLinearVelocity = velocity end
		if typeof(angular) == "Vector3" then session.World.Ball.AssemblyAngularVelocity = angular end
	end
	for _, model in session.Models or {} do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local velocity = model:GetAttribute("VTRPauseSavedVelocity")
			local angular = model:GetAttribute("VTRPauseSavedAngularVelocity")
			root.Anchored = false
			if typeof(velocity) == "Vector3" then root.AssemblyLinearVelocity = velocity end
			if typeof(angular) == "Vector3" then root.AssemblyAngularVelocity = angular end
		end
	end
	broadcast(self.State, session, {Type="Pause", Active=false})
end''',
runtime,
count=1,
flags=re.S
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = gameplay.replace(
'''local UserInputService=game:GetService("UserInputService")''',
'''local UserInputService=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")''',
1
)

if "clearGreenScreenEffects" not in gameplay:
    gameplay = gameplay.replace(
'''local Controller={}
Controller.__index=Controller''',
'''local Controller={}
Controller.__index=Controller

local function clearGreenScreenEffects()
	for _, inst in ipairs(Lighting:GetChildren()) do
		if inst:IsA("ColorCorrectionEffect") or inst:IsA("BlurEffect") or inst:IsA("BloomEffect") or inst:IsA("SunRaysEffect") then
			if string.find(string.lower(inst.Name), "green") or string.find(string.lower(inst.Name), "vtr") or inst:IsA("ColorCorrectionEffect") then
				inst.Enabled = false
				if inst:IsA("ColorCorrectionEffect") then
					inst.TintColor = Color3.new(1,1,1)
					inst.Saturation = 0
					inst.Contrast = 0
					inst.Brightness = 0
				end
			end
		end
	end
	Lighting.ColorShift_Top = Color3.new(0,0,0)
	Lighting.ColorShift_Bottom = Color3.new(0,0,0)
end'''
    )

gameplay = gameplay.replace(
'''function Controller:_activate(data:any)''',
'''function Controller:_activate(data:any)
	clearGreenScreenEffects()''',
1
)

gameplay = gameplay.replace(
'''setMenuVisible(true)''',
'''setMenuVisible(true)
	clearGreenScreenEffects()'''
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

app_path = Path("src/client/App.client.lua")
app = app_path.read_text(encoding="utf-8")

if "forceMenuVisible" not in app:
    app = app.replace(
'''local MatchGameplayController = require(script.Parent.Gameplay.GameplayController)''',
'''local MatchGameplayController = require(script.Parent.Gameplay.GameplayController)

local function forceMenuVisible()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and (gui.Name == "VTRApp" or gui.Name == "VTRMainMenu" or string.find(gui.Name, "Menu")) then
			gui.Enabled = true
		end
	end
end'''
    )

app = app.replace(
'''	local UIController = require(script.Parent.Controllers.UIController)
	UIController.new():Start()''',
'''	local UIController = require(script.Parent.Controllers.UIController)
	UIController.new():Start()
	forceMenuVisible()''',
1
)

app_path.write_text(app, encoding="utf-8", newline="\n")

for path in Path("src/client").rglob("*.lua"):
    text = path.read_text(encoding="utf-8")
    original = text
    text = text.replace("Color3.fromHex(\"B7FF1A\")", "Color3.fromHex(\"FFFFFF\")")
    text = text.replace("Color3.fromRGB(183, 255, 26)", "Color3.fromRGB(255, 255, 255)")
    text = text.replace("Theme.Colors.Electric", "Theme.Colors.White")
    if text != original and path.name not in {"Theme.lua"}:
        path.write_text(text, encoding="utf-8", newline="\n")

print("fixed intro audio stop, green tint, stamina reserve, menu return, match ending, and pause freeze")