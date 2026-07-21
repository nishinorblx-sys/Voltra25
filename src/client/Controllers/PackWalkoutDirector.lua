--!strict

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PackOpeningConfig = require(ReplicatedStorage.VTR.Shared.PackOpeningConfig)
local PackWalkoutScene = require(script.Parent.Parent.Components.PackWalkoutScene)
local PackOpeningAudioService = require(script.Parent.Parent.Services.PackOpeningAudioService)

local Director = {}
Director.__index = Director

local ACTION = "VTRPackWalkoutSkip"

function Director.new(parent: Instance, props: any)
	local selection = PackOpeningConfig.SelectPresentation(props.Reveals, props)
	return setmetatable({
		Parent = parent,
		Props = props,
		Selection = selection,
		Scene = nil,
		Audio = nil,
		Connections = {},
		Tasks = {},
		Cancelled = false,
		Completed = false,
		ResultsShown = false,
		StartedAt = 0,
		SkipStartedAt = nil,
		SkipAvailableAt = 0,
		Phase = "Preparing",
	}, Director)
end

function Director:_complete()
	if self.Completed then return end
	self.Completed = true
	self:Cleanup(true)
	if self.Props.OnComplete then self.Props.OnComplete() end
end

function Director:_showResults()
	if self.ResultsShown or not self.Scene then return end
	self.ResultsShown = true
	self.Phase = "Results"
	self.Audio:Play("ResultsOpen")
	self.Scene:ShowResults(function()
		self:_complete()
	end)
end

function Director:_wait(seconds: number): boolean
	local untilTime = os.clock() + math.max(0, seconds)
	while os.clock() < untilTime do
		if self.Cancelled then return false end
		task.wait(math.min(0.05, untilTime - os.clock()))
	end
	return not self.Cancelled
end

function Director:_skip()
	if self.Completed or self.ResultsShown then return end
	self.Audio:Play("Skip")
	self.Cancelled = true
	if self.Scene then
		self.Scene:SetPhase("Results")
		self.Scene:RevealRating()
		self.Scene:RevealName()
		self.Scene:ShowRemaining()
	end
	task.defer(function()
		self.Cancelled = false
		self:_showResults()
	end)
end

function Director:_bindSkip()
	self.SkipAvailableAt = os.clock() + (tonumber(PackOpeningConfig.Input.SkipAvailableAfter) or 0.85)
	ContextActionService:BindAction(ACTION, function(_, state)
		if self.Completed or self.ResultsShown then return Enum.ContextActionResult.Sink end
		if os.clock() < self.SkipAvailableAt then return Enum.ContextActionResult.Sink end
		if state == Enum.UserInputState.Begin then
			self.SkipStartedAt = os.clock()
			task.spawn(function()
				while self.SkipStartedAt and not self.Completed and not self.ResultsShown do
					local alpha = math.clamp((os.clock() - self.SkipStartedAt) / (tonumber(PackOpeningConfig.Input.HoldToSkipSeconds) or 0.48), 0, 1)
					if self.Scene then self.Scene:SetSkipProgress(alpha) end
					if alpha >= 1 then
						self.SkipStartedAt = nil
						self:_skip()
						break
					end
					task.wait(0.04)
				end
				if self.Scene and not self.ResultsShown then self.Scene:SetSkipProgress(0) end
			end)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			self.SkipStartedAt = nil
			if self.Scene and not self.ResultsShown then self.Scene:SetSkipProgress(0) end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
end

function Director:_runPhase(phase: any): boolean
	local name = tostring(phase.Name)
	local duration = tonumber(phase.Duration) or 0
	self.Phase = name
	if self.Scene then self.Scene:SetPhase(name) end
	if name == "Preparing" then
		self.Audio:Preload()
		self.Audio:DuckMenu()
	elseif name == "TunnelIgnition" then
		self.Audio:Play("TunnelIgnition")
		if self.Scene then self.Scene:IgniteTunnel() end
	elseif name == "EnergyCharge" then
		self.Audio:Play("EnergyChargeLoop")
		if self.Scene then self.Scene:ChargePack(tonumber(self.Selection.Profile.Intensity) or 0.5) end
	elseif name == "ClueSequence" then
		local clues = self.Selection.Profile.Clues or {}
		local per = #clues > 0 and duration / #clues or duration
		for _, clue in clues do
			if self.Cancelled then return false end
			self.Audio:Play("ClueHit")
			if self.Scene then self.Scene:ShowClue(clue) end
			if not self:_wait(per) then return false end
		end
		return true
	elseif name == "PackRupture" then
		self.Audio:Stop("EnergyChargeLoop")
		self.Audio:Play("PackCrack")
		self.Audio:Play("PackBurst")
		if self.Scene then self.Scene:Rupture() end
	elseif name == "Silhouette" then
		self.Audio:Play("SilhouetteRise")
		if self.Scene then self.Scene:RevealSilhouette() end
	elseif name == "Walkout" then
		self.Audio:Play("CrowdSwell")
		local finished = false
		if self.Scene then self.Scene:StartWalkout(function() finished = true end) else finished = true end
		while not finished and not self.Cancelled do
			self.Audio:Play("Footstep")
			task.wait(0.32)
		end
		return not self.Cancelled
	elseif name == "Celebration" then
		self.Audio:Play("WalkoutImpact")
		if self.Scene then self.Scene:Celebrate() end
	elseif name == "RatingReveal" then
		self.Audio:Play("RatingTick")
		if self.Scene then self.Scene:RevealRating() end
		task.delay(math.max(0.05, duration - 0.08), function()
			if not self.Completed then self.Audio:Play("RatingFinalHit") end
		end)
	elseif name == "NameReveal" then
		self.Audio:Play("NameReveal")
		if self.Scene then self.Scene:RevealName() end
	elseif name == "RemainingCards" then
		self.Audio:Play("CardShine")
		if self.Scene then self.Scene:ShowRemaining() end
	elseif name == "Results" then
		self:_showResults()
		return false
	end
	return self:_wait(duration)
end

function Director:Play(): CanvasGroup
	local previous = self.Parent:FindFirstChild("PremiumPackOpening")
	if previous then previous:Destroy() end
	self.StartedAt = os.clock()
	self.Audio = PackOpeningAudioService.new(self.Parent, self.Selection.ReducedMotion)
	self.Scene = PackWalkoutScene.new(self.Parent, self.Props, self.Selection)
	table.insert(self.Connections, self.Scene.Overlay.Destroying:Connect(function()
		if not self.Completed then
			self:Cleanup(false)
		end
	end))
	self:_bindSkip()
	task.spawn(function()
		local ok = pcall(function()
			for _, phase in PackOpeningConfig.PhaseTimeline(self.Selection) do
				if not self:_runPhase(phase) then break end
			end
			if not self.Completed and not self.ResultsShown then self:_showResults() end
		end)
		if not ok and not self.Completed then
			self:_showResults()
		end
	end)
	return self.Scene.Overlay
end

function Director:Cleanup(destroyOverlay: boolean?)
	ContextActionService:UnbindAction(ACTION)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Connections = {}
	if self.Audio then self.Audio:Cleanup() end
	if destroyOverlay == true and self.Scene then self.Scene:Destroy() end
end

return Director
