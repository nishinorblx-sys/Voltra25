--!strict

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PackOpeningConfig = require(ReplicatedStorage.VTR.Shared.PackOpeningConfig)
local MenuMusicService = require(script.Parent.MenuMusicService)

local Service = {}
Service.__index = Service

function Service.new(parent: Instance, reducedMotion: boolean?)
	local group = Instance.new("SoundGroup")
	group.Name = "PackOpeningSoundGroup"
	group.Parent = SoundService
	local self = setmetatable({ Parent = parent, Group = group, Sounds = {}, DuckToken = nil, ReducedMotion = reducedMotion == true }, Service)
	return self
end

function Service:Preload()
	local preload = {}
	for name, spec in PackOpeningConfig.Audio do
		local id = tostring(spec.Id or "")
		if id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = id
			sound.Volume = math.clamp(tonumber(spec.Volume) or 0.4, 0, 1)
			sound.Looped = spec.Looped == true
			sound.SoundGroup = self.Group
			sound.Parent = self.Parent
			self.Sounds[name] = sound
			table.insert(preload, sound)
		end
	end
	if #preload > 0 then
		pcall(function() ContentProvider:PreloadAsync(preload) end)
	end
end

function Service:DuckMenu()
	if self.DuckToken then return end
	self.DuckToken = MenuMusicService.PushDuck("PackOpening", self.ReducedMotion and 0.18 or 0.12, 0.25)
end

function Service:Play(name: string, options: any?)
	local sound = self.Sounds[name]
	if sound and sound.Parent then
		pcall(function()
			local variation = tonumber(options and options.PitchVariation) or 0
			if variation > 0 then
				sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * variation
			else
				sound.PlaybackSpeed = 1
			end
			sound.TimePosition = 0
			sound:Play()
		end)
	end
end

function Service:Stop(name: string)
	local sound = self.Sounds[name]
	if sound and sound.Parent then sound:Stop() end
end

function Service:Cleanup()
	for _, sound in self.Sounds do
		if sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	self.Sounds = {}
	if self.DuckToken then
		MenuMusicService.PopDuck(self.DuckToken, 0.65)
		self.DuckToken = nil
	end
	if self.Group and self.Group.Parent then self.Group:Destroy() end
end

return Service
