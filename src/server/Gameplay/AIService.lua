--!strict
local AIMovementExecutor = require(script.Parent.AIMovementExecutor)
local AITeamController = require(script.Parent.AITeamController)

local Service = {}
Service.__index = Service
local GOALKEEPER_DISTRIBUTION_DELAY = 0.65

function Service.new(teams: any, formation: any, pitchCFrame: CFrame, width: number, length: number, difficulty: string, ball: BasePart, possession: any, ballService: any, tactics: any?)
	local formations = formation and formation.Names or {Home = "4-3-3", Away = "4-3-3"}
	local executor = AIMovementExecutor.new()
	local controller = AITeamController.new(teams, formations, pitchCFrame, width, length, ball, possession, ballService, difficulty, tactics, executor)
	return setmetatable({
		Teams = teams,
		Formations = formations,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Ball = ball,
		Possession = possession,
		BallService = ballService,
		Executor = executor,
		Controller = controller,
		Distribution = nil,
	}, Service)
end

function Service:BeginGoalkeeperDistribution(keeper: Model, side: string, duration: number?)
	local now = os.clock()
	local window = duration or 3.5
	self.Distribution = {Keeper = keeper, Side = side, Until = now + window}
	keeper:SetAttribute("VTRNoAutoPassUntil", now + GOALKEEPER_DISTRIBUTION_DELAY)
	keeper:SetAttribute("VTRKeeperMustDistributeUntil", now + window)
	keeper:SetAttribute("AIAssignment", "GoalkeeperDistribution")
end

function Service:SetExternalPhase(phase: string?)
	self.Controller:SetExternalPhase(phase)
end

function Service:SetManualTackleSides(sides: {[string]: boolean}?)
	if self.Controller and self.Controller.SetManualTackleSides then
		self.Controller:SetManualTackleSides(sides)
	end
end

function Service:SetFirstMatchAssistance(active: boolean)
	self.Controller:SetFirstMatchAssistance(active)
end

function Service:BeginFirstMatchRestoration()
	self.Controller:BeginFirstMatchRestoration()
end

function Service:SetDisabled(disabled: boolean)
	self.Disabled = disabled == true
	if self.Disabled then
		self.Distribution = nil
		self.Controller:SetExternalPhase("FULL TIME")
		self.Controller:Step(0)
	end
end

function Service:SetHalf(half: number?)
	self.Controller:SetHalf(half)
end

function Service:UpdateTactics(side: string, tactics: any)
	self.Controller:UpdateTactics(side, tactics)
end

function Service:ResetFootballer(model: Model)
	self.Controller:ResetFootballer(model)
end

function Service:Step(dt: number)
	if self.Disabled then return end
	if self.Distribution and os.clock() >= self.Distribution.Until then
		self.Distribution = nil
	end
	self.Controller:Step(dt)
end

function Service:Destroy()
	self.Controller:Destroy()
	self.Executor:Destroy()
	self.Distribution = nil
end

return Service
