from pathlib import Path
import re

sound_path = Path("src/client/Services/UISoundService.lua")
sound = sound_path.read_text(encoding="utf-8")

sound = re.sub(
r'''local lastPlayed: \{\[string\]: number\} = \{\}''',
'''local lastPlayed: {[string]: number} = {}
local activeTransitionSounds: {Sound} = {}''',
sound,
count=1
)

sound = re.sub(
r'''local function play\(id: string, volume: number, key: string\?, cooldown: number\?\)
.*?
end''',
'''local function play(id: string, volume: number, key: string?, cooldown: number?): Sound?
	preload()
	local now = os.clock()
	if key and cooldown and (lastPlayed[key] or 0) + cooldown > now then return nil end
	if key then lastPlayed[key] = now end
	local sound = Instance.new("Sound")
	sound.Name = "VTRUISound"
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		for index, item in ipairs(activeTransitionSounds) do
			if item == sound then
				table.remove(activeTransitionSounds, index)
				break
			end
		end
		if sound.Parent then sound:Destroy() end
	end)
	sound:Play()
	task.delay(8, function()
		if sound.Parent then sound:Destroy() end
	end)
	return sound
end''',
sound,
count=1,
flags=re.S
)

sound = re.sub(
r'''function Service.PlayTransition\(\)
	play\(TRANSITION_SOUND, 0\.52, "Transition", 0\.02\)
end''',
'''function Service.PlayTransition()
	local sound = play(TRANSITION_SOUND, 0.52, "Transition", 0.02)
	if sound then
		table.insert(activeTransitionSounds, sound)
	end
end

function Service.StopTransitions()
	for _, sound in ipairs(activeTransitionSounds) do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	table.clear(activeTransitionSounds)
end''',
sound,
count=1
)

if "function Service.StopTransitions()" not in sound:
    sound = sound.replace(
'''function Service.Bind(root: Instance)''',
'''function Service.StopTransitions()
	for _, sound in ipairs(activeTransitionSounds) do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	table.clear(activeTransitionSounds)
end

function Service.Bind(root: Instance)''',
1
    )

sound_path.write_text(sound, encoding="utf-8", newline="\n")

prematch_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
prematch = prematch_path.read_text(encoding="utf-8")

if 'local UISoundService = require(script.Parent.Parent.Services.UISoundService)' not in prematch:
    prematch = prematch.replace(
        'local PlayerPortraitService = require(script.Parent.Parent.Services.PlayerPortraitService)',
        'local PlayerPortraitService = require(script.Parent.Parent.Services.PlayerPortraitService)\nlocal UISoundService = require(script.Parent.Parent.Services.UISoundService)',
        1
    )

prematch = re.sub(
r'''function Presentation.StopAudio\(\)
\s*stopIntroAudio\(\)
end''',
'''function Presentation.StopAudio()
	if UISoundService.StopTransitions then
		UISoundService.StopTransitions()
	end
	stopIntroAudio()
end''',
prematch,
count=1
)

prematch_path.write_text(prematch, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

if 'local UISoundService=require(script.Parent.Parent.Services.UISoundService)' not in gameplay:
    gameplay = gameplay.replace(
        'local UIStateService=require(script.Parent.Parent.Services.UIStateService)',
        'local UIStateService=require(script.Parent.Parent.Services.UIStateService)\nlocal UISoundService=require(script.Parent.Parent.Services.UISoundService)',
        1
    )

gameplay = gameplay.replace(
'''elseif payload.Type=="PrematchSkip"then self.PrematchActive=false;self.PrematchSkipRequested=true;if self.Cutscenes then self.Cutscenes:SkipStadiumIntro()end;self:_playPrematchSkipTransition()''',
'''elseif payload.Type=="PrematchSkip"then self.PrematchActive=false;self.PrematchSkipRequested=true;if UISoundService.StopTransitions then UISoundService.StopTransitions()end;if self.Cutscenes then self.Cutscenes:SkipStadiumIntro()end;self:_playPrematchSkipTransition()''',
1
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

print("transition sounds now stop when intro is skipped")