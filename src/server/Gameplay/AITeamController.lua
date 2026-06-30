--!strict
local AIContextBuilder = require(script.Parent.AIContextBuilder)
local AIPhaseService = require(script.Parent.AIPhaseService)
local AIAssignmentService = require(script.Parent.AIAssignmentService)
local AIMovementService = require(script.Parent.AIMovementService)
local AIPlayerBrain = require(script.Parent.AIPlayerBrain)
local AIDebugService = require(script.Parent.AIDebugService)
local AIDifficultyService = require(script.Parent.AIDifficultyService)
local AITacticalStyleService = require(script.Parent.AITacticalStyleService)

local Service = {}
Service.__index = Service

function Service.new(teams: any, formations: any, pitchCFrame: CFrame, width: number, length: number, ball: BasePart, possession: any, ballService: any, difficultyName: string, tactics: any?, executor: any)
	local style = AITacticalStyleService.new(tactics)
	local homeStyle = AITacticalStyleService.new(tactics)
	local awayStyle = AITacticalStyleService.new(tactics)
	local difficulty = AIDifficultyService.Resolve(difficultyName, Random.new())
	return setmetatable({
		Teams = teams,
		Formations = formations,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Ball = ball,
		Possession = possession,
		BallService = ballService,
		Half = 1,
		ExternalPhase = nil,
		Style = style,
		Styles = {Home = homeStyle, Away = awayStyle},
		Difficulty = difficulty,
		Phase = AIPhaseService.new(),
		Assignments = {
			Home = AIAssignmentService.new(homeStyle),
			Away = AIAssignmentService.new(awayStyle),
		},
		Movement = AIMovementService.new(executor),
		Brain = {
			Home = AIPlayerBrain.new(ballService, homeStyle, difficulty),
			Away = AIPlayerBrain.new(ballService, awayStyle, difficulty),
		},
		Debug = AIDebugService.new(),
		Accum = {Phase = 0.08, Assignment = 0.1, OnBall = 0.08, Movement = 0.06, Debug = 0.25},
		Phases = {Home = "LooseBall", Away = "LooseBall"},
		CurrentAssignments = {Home = {}, Away = {}},
		LastContext = nil,
		WasLive = false,
	}, Service)
end

function Service:_attackSigns(): {[string]: number}
	local home = (self.Half or 1) >= 2 and 1 or -1
	return {Home = home, Away = -home}
end

function Service:SetHalf(half: number?)
	local nextHalf = half or 1
	if self.Half ~= nextHalf then
		self.CurrentAssignments = {Home = {}, Away = {}}
		self.Phases = {Home = "LooseBall", Away = "LooseBall"}
		self.Movement:Clear()
		self.Brain.Home:Clear()
		self.Brain.Away:Clear()
	end
	self.Half = nextHalf
end

function Service:SetExternalPhase(phase: string?)
	self.ExternalPhase = phase
end

function Service:UpdateTactics(side: string, tactics: any)
	local targetSide = side == "Away" and "Away" or "Home"
	local style = AITacticalStyleService.new(tactics)
	self.Styles[targetSide] = style
	self.Assignments[targetSide] = AIAssignmentService.new(style)
	self.Brain[targetSide] = AIPlayerBrain.new(self.BallService, style, self.Difficulty)
	self.CurrentAssignments[targetSide] = {}
end

function Service:_isLive(): boolean
	return self.ExternalPhase == nil or self.ExternalPhase == "Live" or self.ExternalPhase == "IN PLAY"
end

function Service:_context(): any
	return AIContextBuilder.Build(self.Teams, self.Formations, self.PitchCFrame, self.Width, self.Length, self.Ball, self.Possession, self:_attackSigns())
end

function Service:Step(dt: number)
	local live = self:_isLive()
	if not live then
		if self.WasLive then
			for _, side in ipairs({"Home", "Away"}) do
				for _, model in ipairs(self.Teams[side] or {}) do
					self.Movement.Executor:Clear(model)
				end
			end
			self.CurrentAssignments = {Home = {}, Away = {}}
			self.Brain.Home:Clear()
			self.Brain.Away:Clear()
			self.Movement:Clear()
		end
		self.WasLive = false
		return
	end
	self.WasLive = true

	local context = self:_context()
	self.LastContext = context
	for _, side in ipairs({"Home", "Away"}) do
		for _, model in ipairs(self.Teams[side] or {}) do
			if model:GetAttribute("VTRSentOff") ~= true and model:GetAttribute("VTRRedCard") ~= true then
				if model:GetAttribute("aiControlled") == true then
					if model:GetAttribute("controlledByUser") == true then model:SetAttribute("controlledByUser", false) end
					if model:GetAttribute("VTRUserId") ~= nil then model:SetAttribute("VTRUserId", nil) end
				end
				if model:GetAttribute("VTRForceIdle") == true then model:SetAttribute("VTRForceIdle", nil) end
				if model:GetAttribute("VTRFrozenIdle") == true then model:SetAttribute("VTRFrozenIdle", nil) end
				if model:GetAttribute("VTRSetPieceWall") == true then model:SetAttribute("VTRSetPieceWall", nil) end
				if model:GetAttribute("VTRPresentationState") ~= nil then model:SetAttribute("VTRPresentationState", nil) end
			end
		end
	end

	if context.LooseBall then
		self.Phases = self.Phase:Update(context, true)
		self.CurrentAssignments = {
			Home = self.Assignments.Home:BuildSide(context, "Home", "LooseBall"),
			Away = self.Assignments.Away:BuildSide(context, "Away", "LooseBall"),
		}
		self.Accum.Phase = 0
		self.Accum.Assignment = 0
	end

	self.Accum.Phase += dt
	if self.Accum.Phase >= 0.08 then
		self.Accum.Phase = 0
		self.Phases = self.Phase:Update(context, true)
	end

	self.Accum.Assignment += dt
	if self.Accum.Assignment >= 0.1 or not next(self.CurrentAssignments.Home) then
		self.Accum.Assignment = 0
		self.CurrentAssignments = {
			Home = self.Assignments.Home:BuildSide(context, "Home", self.Phases.Home or "LooseBall"),
			Away = self.Assignments.Away:BuildSide(context, "Away", self.Phases.Away or "LooseBall"),
		}
	end

	self.Accum.OnBall += dt
	if self.Accum.OnBall >= 0.08 then
		self.Accum.OnBall = 0
		self.Brain.Home:StepSide(context, self.CurrentAssignments, "Home")
		self.Brain.Away:StepSide(context, self.CurrentAssignments, "Away")
	end

	self.Accum.Movement += dt
	if self.Accum.Movement >= 0.06 then
		self.Accum.Movement = 0
		for _, side in ipairs({"Home", "Away"}) do
			for model, assignment in pairs(self.CurrentAssignments[side]) do
				local info = context.Players[model]
				if info and assignment then
					self.Movement:Apply(info, assignment, context, dt)
				end
			end
		end
	end
	self.Movement:Step(dt)

	self.Accum.Debug += dt
	if self.Accum.Debug >= 0.25 then
		self.Accum.Debug = 0
		self.Debug:Update(context, self.CurrentAssignments)
	end
end

function Service:Destroy()
	self.Debug:Destroy()
	self.Movement:Clear()
	self.Brain.Home:Clear()
	self.Brain.Away:Clear()
end

return Service
