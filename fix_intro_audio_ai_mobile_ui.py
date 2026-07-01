from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

presentation_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
presentation = presentation_path.read_text(encoding="utf-8")

presentation = replace_once(
presentation,
'''local STARTING_XI_SOUND_ONE = "rbxassetid://111250989374137"
local STARTING_XI_SOUND_TWO = "rbxassetid://76843129252399"''',
'''local STARTING_XI_SOUND_ONE = "rbxassetid://111250989374137"
local STARTING_XI_SOUND_TWO = "rbxassetid://76843129252399"
local INTRO_BACKGROUND_SOUND = "rbxassetid://127074097075829"
local INTRO_TRACKS = {
	"rbxassetid://103355995717599",
	"rbxassetid://104511486039648",
	"rbxassetid://111700713857834",
}
local activeIntroSounds = {}''',
"intro constants"
)

presentation = replace_once(
presentation,
'''local function playPresentationSound(soundId: string, volume: number?)
	local sound = Instance.new("Sound")
	sound.Name = "VTRStartingXIAudio"
	sound.SoundId = soundId
	sound.Volume = volume or .62
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		if sound.Parent then sound:Destroy() end
	end)
	sound:Play()
	task.delay(8, function()
		if sound.Parent then sound:Destroy() end
	end)
end''',
'''local function playPresentationSound(soundId: string, volume: number?, looped: boolean?)
	local sound = Instance.new("Sound")
	sound.Name = "VTRPresentationAudio"
	sound.SoundId = soundId
	sound.Volume = volume or .62
	sound.Looped = looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	if not sound.Looped then
		sound.Ended:Connect(function()
			if sound.Parent then sound:Destroy() end
		end)
	end
	sound:Play()
	if not sound.Looped then
		task.delay(14, function()
			if sound.Parent then sound:Destroy() end
		end)
	end
	return sound
end

local function stopIntroAudio()
	for _, sound in activeIntroSounds do
		if sound and sound.Parent then sound:Destroy() end
	end
	table.clear(activeIntroSounds)
end

function Presentation.StopAudio()
	stopIntroAudio()
end

local function startIntroAudio(gui: ScreenGui)
	stopIntroAudio()
	table.insert(activeIntroSounds, playPresentationSound(INTRO_BACKGROUND_SOUND, .34, true))
	table.insert(activeIntroSounds, playPresentationSound(INTRO_TRACKS[math.random(1, #INTRO_TRACKS)], .58, false))
	gui.Destroying:Connect(stopIntroAudio)
end''',
"intro audio funcs"
)

presentation = replace_once(
presentation,
'''	gui.DisplayOrder = 92
	gui.Parent = playerGui

	local root = Instance.new("Frame")''',
'''	gui.DisplayOrder = 92
	gui.Parent = playerGui
	startIntroAudio(gui)

	local root = Instance.new("Frame")''',
"start intro audio"
)

presentation = replace_once(
presentation,
'''	task.delay(TOTAL_DURATION, function()
		if gui.Parent then gui:Destroy() end
		if onComplete then onComplete() end
	end)''',
'''	task.delay(TOTAL_DURATION, function()
		stopIntroAudio()
		if gui.Parent then gui:Destroy() end
		if onComplete then onComplete() end
	end)''',
"stop intro audio complete"
)

presentation_path.write_text(presentation, encoding="utf-8", newline="\n")

cutscene_path = Path("src/client/Gameplay/MatchCutsceneController.lua")
cutscene = cutscene_path.read_text(encoding="utf-8")

cutscene = replace_once(
cutscene,
'''function Controller:SkipStadiumIntro()
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")''',
'''function Controller:SkipStadiumIntro()
	if PrematchBroadcastPresentation.StopAudio then
		PrematchBroadcastPresentation.StopAudio()
	end
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")''',
"skip stops intro audio"
)

cutscene_path.write_text(cutscene, encoding="utf-8", newline="\n")

app_path = Path("src/client/App.client.lua")
app = app_path.read_text(encoding="utf-8")

app = app.replace(
'''local reservedRankedBoot = type(teleportData) == "table" and teleportData.MatchMode == "Ranked1v1"''',
'''local reservedRankedBoot = type(teleportData) == "table" and (teleportData.MatchMode == "Ranked1v1" or teleportData.MatchMode == "AICampaignSolo")''',
1
)

app = app.replace(
'''	title.Text = "RANKED 1V1 SERVER"''',
'''	title.Text = teleportData.MatchMode == "AICampaignSolo" and "AI CAMPAIGN MATCH" or "RANKED 1V1 SERVER"''',
1
)

app = app.replace(
'''	sub.Text = "SYNCING BOTH TEAMS  /  LOADING RESERVED MATCH"''',
'''	sub.Text = teleportData.MatchMode == "AICampaignSolo" and "LOADING DIRECTLY INTO THE INTRO" or "SYNCING BOTH TEAMS  /  LOADING RESERVED MATCH"''',
1
)

app_path.write_text(app, encoding="utf-8", newline="\n")

setup_path = Path("src/server/Services/MatchSetupService.lua")
setup = setup_path.read_text(encoding="utf-8")

setup = replace_once(
setup,
'''	options:SetTeleportData({MatchMode="AICampaignSolo",Action=action,ReturnPlaceId=game.PlaceId,Setup=setupSnapshot})''',
'''	options:SetTeleportData({MatchMode="AICampaignSolo",Action=action,ReturnPlaceId=game.PlaceId,Setup=setupSnapshot,AutoStart=true,DirectIntro=true,Campaign=true})''',
"ai campaign teleport flags"
)

setup = setup.replace(
'''					if ok then
						player:SetAttribute("VTRAICampaignAutoStarting",false)
						return
					end''',
'''					if ok then
						player:SetAttribute("VTRAICampaignAutoStarting",false)
						player:SetAttribute("VTRAICampaignDirectIntro",true)
						return
					end''',
1
)

setup_path.write_text(setup, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = replace_once(
gameplay,
'''self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.WatchMode then self.Input:SetSuppressed(true)end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))''',
'''self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.WatchMode then self.Input:SetSuppressed(true);if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))''',
"remove mobile controls in watch mode"
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

hud_path = Path("src/client/Gameplay/MatchHUDController.lua")
hud = hud_path.read_text(encoding="utf-8")

hud = replace_once(
hud,
'''	local board = panel(gui, UDim2.fromOffset(18, 58), UDim2.fromOffset(132, 56))''',
'''	local board = panel(gui, UserInputService.TouchEnabled and UDim2.fromOffset(16, 86) or UDim2.fromOffset(18, 58), UDim2.fromOffset(132, 56))''',
"mobile scoreboard position"
)

hud = replace_once(
hud,
'''	local scoreScale = Instance.new("UIScale")
	scoreScale.Parent = board''',
'''	local scoreScale = Instance.new("UIScale")
	scoreScale.Scale = UserInputService.TouchEnabled and 1.22 or 1
	scoreScale.Parent = board''',
"mobile scoreboard scale"
)

hud_path.write_text(hud, encoding="utf-8", newline="\n")

ui_path = Path("src/client/Controllers/UIController.lua")
ui = ui_path.read_text(encoding="utf-8")

if 'local UserInputService = game:GetService("UserInputService")' not in ui:
    ui = ui.replace(
        'local TweenService = game:GetService("TweenService")',
        'local TweenService = game:GetService("TweenService")\nlocal UserInputService = game:GetService("UserInputService")',
        1
    )

ui = replace_once(
ui,
'''		local scaleValue = math.clamp(math.min(widthFit, heightFit), Theme.Layout.MinimumScale, Theme.Layout.MaximumScale)''',
'''		local scaleValue = math.clamp(math.min(widthFit, heightFit), Theme.Layout.MinimumScale, Theme.Layout.MaximumScale)
		if UserInputService.TouchEnabled then
			scaleValue = math.clamp(scaleValue * 1.2, Theme.Layout.MinimumScale, Theme.Layout.MaximumScale * 1.2)
		end''',
"mobile menu scale"
)

ui_path.write_text(ui, encoding="utf-8", newline="\n")

print("added intro audio, direct AI campaign boot, mobile watch cleanup, bigger mobile scoreboard, and larger mobile menu scale")