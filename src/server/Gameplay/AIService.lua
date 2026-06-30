--!strict
local AIMovementExecutor = require(script.Parent.AIMovementExecutor)
local AITeamController = require(script.Parent.AITeamController)

local Service = {}
Service.__index = Service

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
	self.Distribution = {Keeper = keeper, Side = side, Until = os.clock() + (duration or 3.5)}
	keeper:SetAttribute("VTRNoAutoPassUntil", os.clock() + 0.65)
	keeper:SetAttribute("AIAssignment", "GoalkeeperDistribution")
end

function Service:SetExternalPhase(phase: string?)
	self.Controller:SetExternalPhase(phase)
end

function Service:SetHalf(half: number?)
	self.Controller:SetHalf(half)
end

function Service:UpdateTactics(side: string, tactics: any)
	self.Controller:UpdateTactics(side, tactics)
end

function Service:Step(dt: number)
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
