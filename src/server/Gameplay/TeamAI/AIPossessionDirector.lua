--!strict

local Director = {}
Director.__index = Director

function Director.new(): any
	return setmetatable({Plans = {Home = nil, Away = nil}}, Director)
end

function Director:Update(context: any, side: string, intent: any, spatial: any, memory: any): any
	local current = self.Plans[side]
	local now = context.Now or os.clock()
	local intentName = tostring(intent and intent.Intent or "")
	local teamBrain = context.TeamBrain and context.TeamBrain[side]
	local identity = tostring(teamBrain and teamBrain.AttackingIdentity or "")
	local corridor = tostring(teamBrain and teamBrain.AttackCorridor or "")
	if current and current.Intent == intentName and now < current.ExpiresAt then
		return current
	end
	local route = {}
	if identity == "PositionalControl" then
		route = {"reset", "triangle", "free-player", "switch-ready"}
	elseif identity == "VerticalCombination" then
		route = {"bounce", "line-break", "third-man", "runner"}
	elseif identity == "DirectAssault" then
		route = {"early-forward", "runner", "second-ball", "finish"}
	elseif identity == "WideOverload" or corridor == "Wide" then
		route = {"wide-triangle", "overlap", "cutback", "far-switch"}
	elseif identity == "CentralDomination" or corridor == "Central" then
		route = {"central-support", "wall-pass", "through-ball", "counterpress"}
	elseif identity == "CounterattackingTrap" then
		route = {"bait", "first-forward", "counter-lane", "second-wave"}
	elseif identity == "HighPressSwarm" then
		route = {"recover-high", "fast-chance", "box-run"}
	elseif identity == "LowBlockFortress" then
		route = {"secure-clear", "controlled-counter", "restore-shape"}
	elseif identity == "FluidRotation" then
		route = {"rotate-zone", "replace-space", "displace-defender", "progress"}
	elseif identity == "AdaptiveController" then
		route = {"read-space", "best-corridor", "commit-runners", "protect-rest"}
	elseif intentName == "AttractPress" or intentName == "BuildOut" then
		route = {"reset", "pivot", "free-player"}
	elseif intentName == "EscapePressure" then
		route = {"bounce", "switch", "consolidate"}
	elseif intentName == "SwitchPlay" then
		route = {"secure", "far-side-switch", "attack-space"}
	elseif intentName == "CounterAttack" or intentName == "DirectRelease" then
		route = {"runner", "line-break", "finish"}
	elseif intentName == "CreateChance" then
		route = {"overload", "cutback", "shot"}
	else
		route = {"support", "progress", "consolidate"}
	end
	local plan = {Intent = intentName, TeamIdentity = identity, AttackCorridor = corridor, StartedAt = now, ExpiresAt = now + 3.2, Step = 1, Route = route, Owner = context.Owner}
	self.Plans[side] = plan
	if memory then memory:RememberPlan(side, plan) end
	return plan
end

function Director:Reset(side: string?)
	if side then self.Plans[side] = nil else self.Plans = {Home = nil, Away = nil} end
end

return Director
