from pathlib import Path

crowd_path = Path("src/client/Gameplay/CrowdAmbienceController.lua")
crowd_path.write_text('''--!strict
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Controller = {}
Controller.__index = Controller

local CROWD_ID = "rbxassetid://114836843250240"

function Controller.new()
	local self = setmetatable({}, Controller)
	local sound = Instance.new("Sound")
	sound.Name = "VTRStadiumCrowdAmbience"
	sound.SoundId = CROWD_ID
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	self.Sound = sound
	self.TargetVolume = 0.32
	return self
end

function Controller:Start()
	if not self.Sound then return end
	if not self.Sound.IsPlaying then
		self.Sound:Play()
	end
	TweenService:Create(self.Sound, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Volume = self.TargetVolume}):Play()
end

function Controller:SetMatchActive(active: boolean)
	if not self.Sound then return end
	local target = active and self.TargetVolume or 0.16
	if not self.Sound.IsPlaying then
		self.Sound:Play()
	end
	TweenService:Create(self.Sound, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Volume = target}):Play()
end

function Controller:Boost(seconds: number?)
	if not self.Sound then return end
	if not self.Sound.IsPlaying then
		self.Sound:Play()
	end
	TweenService:Create(self.Sound, TweenInfo.new(0.18), {Volume = 0.48}):Play()
	task.delay(seconds or 2.2, function()
		if self.Sound and self.Sound.Parent then
			TweenService:Create(self.Sound, TweenInfo.new(0.9), {Volume = self.TargetVolume}):Play()
		end
	end)
end

function Controller:Stop()
	if not self.Sound then return end
	local sound = self.Sound
	TweenService:Create(sound, TweenInfo.new(0.55), {Volume = 0}):Play()
	task.delay(0.62, function()
		if sound.Parent then
			sound:Stop()
		end
	end)
end

function Controller:Destroy()
	if self.Sound then
		self.Sound:Destroy()
		self.Sound = nil
	end
end

return Controller
''', encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
text = gameplay_path.read_text(encoding="utf-8")

if "CrowdAmbienceController" not in text:
    text = text.replace(
        'local CommentaryController=require(script.Parent.CommentaryController)',
        'local CommentaryController=require(script.Parent.CommentaryController)\nlocal CrowdAmbienceController=require(script.Parent.CrowdAmbienceController)',
        1
    )

if "self.CrowdAmbience=CrowdAmbienceController.new()" not in text:
    text = text.replace(
        'self.Commentary=CommentaryController.new(self.HUD.Gui);self.Camera=BroadcastCameraController.new',
        'self.Commentary=CommentaryController.new(self.HUD.Gui);self.CrowdAmbience=CrowdAmbienceController.new();self.CrowdAmbience:Start();self.Camera=BroadcastCameraController.new',
        1
    )

text = text.replace(
    'self.MatchInPlay=payload.Phase=="IN PLAY";if self.Trainer then',
    'self.MatchInPlay=payload.Phase=="IN PLAY";if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;if self.Trainer then',
    1
)

text = text.replace(
    'elseif payload.Type=="Goal"then if self.HUD then self.HUD:ResolveShotChance(true)end;',
    'elseif payload.Type=="Goal"then if self.CrowdAmbience then self.CrowdAmbience:Boost(3.2)end;if self.HUD then self.HUD:ResolveShotChance(true)end;',
    1
)

text = text.replace(
    'elseif payload.Type=="Shot"then if self.ReplayController then',
    'elseif payload.Type=="Shot"then if self.CrowdAmbience then self.CrowdAmbience:Boost(0.9)end;if self.ReplayController then',
    1
)

text = text.replace(
    'if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end\n\t\tfor _,controller in self.AnimationCache or{}do controller:Destroy()end;',
    'if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end\n\t\tif self.CrowdAmbience then self.CrowdAmbience:Destroy();self.CrowdAmbience=nil end\n\t\tfor _,controller in self.AnimationCache or{}do controller:Destroy()end;',
    1
)

text = text.replace(
    'if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end;if self.Commentary then',
    'if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end;if self.CrowdAmbience then self.CrowdAmbience:Destroy();self.CrowdAmbience=nil end;if self.Commentary then',
    1
)

gameplay_path.write_text(text, encoding="utf-8", newline="\n")

print("added stadium crowd ambience")