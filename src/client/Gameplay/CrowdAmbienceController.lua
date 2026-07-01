--!strict
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
