--!strict
local PrematchBroadcastPresentation = require(script.Parent.Parent.Components.PrematchBroadcastPresentation)
local MatchPresentationService = require(script.Parent.Parent.Services.MatchPresentationService)
local MatchExperienceConfig = require(game:GetService("ReplicatedStorage").VTR.Shared.MatchExperienceConfig)

local Controller = {}
Controller.__index = Controller

local TITLES = {ThrowIn = "THROW IN", Corner = "CORNER", GoalKick = "GOAL KICK", Kickoff = "KICK OFF", FreeKick = "FREE KICK", Penalty = "PENALTY"}

function Controller.new(camera: any, hud: any)
	return setmetatable({Camera = camera, HUD = hud}, Controller)
end

function Controller:Play(payload: any)
	local title = TITLES[payload.Kind] or tostring(payload.Kind or "RESTART")
	if payload.Kind ~= "FreeKick" and payload.Kind ~= "Penalty" and self.Camera and self.Camera.EndCutscene then
		self.Camera:EndCutscene()
	end
	self.HUD:SetPhase(title)
	if payload.Kind ~= "ThrowIn" and payload.Kind ~= "Corner" and payload.Kind ~= "GoalKick" and payload.Kind ~= "FreeKick" then
		self.HUD:Flash(title, payload.Duration or 1.6)
	end
	if payload.Cutscene == false then
		return
	end
	local duration = (payload.Kind == "FreeKick" or payload.Kind == "Penalty") and 45 or (payload.Duration or 1.6)
	self.Camera:BeginCutscene(payload.Kind, payload.Location, duration, payload.GoalPosition)
end

function Controller:StadiumIntro(payload: any?, onComplete: (() -> ())?)
	self.HUD:SetPhase("MATCHDAY")
	if self.HUD.Gui then
		self.HUD.Gui.Enabled = false
	end
	local profile = MatchExperienceConfig.Normalize(payload and payload.PresentationProfile)
	if profile ~= "Acquisition" then self.Camera:BeginStadiumIntro(PrematchBroadcastPresentation.Duration(profile)) end
	if payload then
		PrematchBroadcastPresentation.Play(payload, function()
			if self.HUD then
				if self.HUD.Gui then
					self.HUD.Gui.Enabled = true
				end
				self.HUD:SetPhase("")
			end
			if onComplete then onComplete() end
		end)
	end
end

function Controller:SkipStadiumIntro()
	if PrematchBroadcastPresentation.StopAudio then
		PrematchBroadcastPresentation.StopAudio()
	end
	MatchPresentationService.Complete(true)
	if self.Camera and self.Camera.EndCutscene then
		self.Camera:EndCutscene()
	end
	if self.HUD then
		if self.HUD.Gui then
			self.HUD.Gui.Enabled = true
		end
		self.HUD:SetPhase("")
	end
end

function Controller:Goal(payload: any)
	self.HUD:SetPhase("GOAL")
	self.HUD:Flash(tostring(payload.Team) .. " GOAL", 1.4)
	self.HUD:PulseScore()
	if payload.Penalty == true then
		task.delay(1, function()
			if self.Camera and self.Camera.EndCutscene then
				self.Camera:EndCutscene()
			end
		end)
		return
	end
	self.Camera:GoalCinematic()
end

function Controller:HalfTime(payload: any)
	self.HUD:SetPhase("HALF TIME")
	if self.Camera and self.Camera.BeginHalfTimeWide then
		self.Camera:BeginHalfTimeWide(math.max(2, tonumber(payload.PauseRemaining) or 7))
	end
	self.HUD:ShowHalfTime(payload)
end

function Controller:Destroy()
	self:SkipStadiumIntro()
end

return Controller
