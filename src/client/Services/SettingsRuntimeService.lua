--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Service = {}
local blurGuardBound = false

local function volume(value: any, fallback: number): number
	if type(value) == "number" then
		return math.clamp(value, 0, 1)
	end
	if type(value) == "string" then
		local numeric = tonumber(value:match("%d+"))
		if numeric then
			return math.clamp(numeric / 100, 0, 1)
		end
	end
	return fallback
end

local function menuSound(sound: Sound): boolean
	local name = string.lower(sound.Name)
	return string.find(name, "menu") ~= nil or string.find(name, "music") ~= nil or sound:GetAttribute("VTRMenuMusic") == true
end

local function highContrastEffect(): ColorCorrectionEffect
	local existing = Lighting:FindFirstChild("VTRHighContrast")
	if existing and existing:IsA("ColorCorrectionEffect") then
		return existing
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "VTRHighContrast"
	effect.Parent = Lighting
	return effect
end

local function disableSoftFocusEffects()
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
			effect.Enabled = false
		end
	end
	if blurGuardBound then return end
	blurGuardBound = true
	Lighting.ChildAdded:Connect(function(effect)
		if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
			effect.Enabled = false
		end
	end)
end

local function applySound(sound: Sound, master: number, menuEnabled: boolean)
	local base = sound:GetAttribute("VTRBaseVolume")
	if type(base) ~= "number" then
		base = sound.Volume
		sound:SetAttribute("VTRBaseVolume", base)
	end
	if menuSound(sound) then
		sound.Volume = menuEnabled and base * master or 0
	else
		sound.Volume = base * master
	end
end

local function applySounds(root: Instance, master: number, menuEnabled: boolean)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Sound") then
			applySound(descendant, master, menuEnabled)
		end
	end
end

function Service.Apply(settings: any)
	settings = type(settings) == "table" and settings or {}
	disableSoftFocusEffects()
	local master = volume(settings.MasterVolume, 0.8)
	SoundService:SetAttribute("VTRMasterVolume", master)
	workspace:SetAttribute("VTRReducedMotion", settings.ReducedMotion == true)
	workspace:SetAttribute("VTRHighContrast", settings.HighContrast == true)
	workspace:SetAttribute("VTRMenuMusic", settings.MenuMusic ~= false)
	workspace:SetAttribute("VTRPauseKey", tostring(settings.PauseKey or "M"))
	workspace:SetAttribute("VTRSkipKey", tostring(settings.SkipKey or "Space"))
	local contrast = highContrastEffect()
	if settings.HighContrast == true then
		contrast.Enabled = true
		contrast.Contrast = 0.22
		contrast.Saturation = -0.08
		contrast.Brightness = 0.02
	else
		contrast.Enabled = false
	end
	local menuEnabled = settings.MenuMusic ~= false
	applySounds(SoundService, master, menuEnabled)
	applySounds(workspace, master, menuEnabled)
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		applySounds(playerGui, master, menuEnabled)
	end
end

return Service
