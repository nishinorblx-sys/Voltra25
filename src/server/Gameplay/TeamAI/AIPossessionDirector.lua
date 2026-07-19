--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)
local AITacticalContract = require(script.Parent.AITacticalContract)

local Director = {}
Director.__index = Director

local ROUTES: {[string]: {any}} = {
	PositionalControl = {
		{Id = "reset", PreferredReceiver = "goalkeeper-outlet", Required = {"goalkeeper-outlet", "rest-defense"}, Next = "triangle", Fallback = "reset", PassBias = "SecureFreePlayer"},
		{Id = "triangle", PreferredReceiver = "ball-side-pivot", Required = {"ball-side-pivot", "left-support", "right-support"}, Next = "free-player", Fallback = "reset", PassBias = "ShortTriangle"},
		{Id = "free-player", PreferredReceiver = "between-lines-receiver", Required = {"between-lines-receiver"}, Next = "switch-ready", Fallback = "triangle", PassBias = "FindFreePlayer"},
		{Id = "switch-ready", PreferredReceiver = "far-side-width", Required = {"far-side-width", "rest-defense"}, Next = "progress", Fallback = "free-player", PassBias = "Switch"},
		{Id = "progress", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "triangle", Fallback = "reset", PassBias = "Progress"},
	},
	VerticalCombination = {
		{Id = "bounce-pass", PreferredReceiver = "checking-striker", Required = {"checking-striker", "ball-side-pivot"}, Next = "line-breaking-receiver", Fallback = "bounce-pass", PassBias = "Bounce", Runs = {"checking-striker"}},
		{Id = "line-breaking-receiver", PreferredReceiver = "between-lines-receiver", Required = {"between-lines-receiver"}, Next = "third-man-support", Fallback = "bounce-pass", PassBias = "LineBreak"},
		{Id = "third-man-support", PreferredReceiver = "second-ball-midfielder", Required = {"second-ball-midfielder"}, Next = "runner-behind", Fallback = "line-breaking-receiver", PassBias = "ThirdMan", Runs = {"second-ball-midfielder"}},
		{Id = "runner-behind", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "finish-or-recycle", Fallback = "third-man-support", PassBias = "Through", Runs = {"central-forward"}},
		{Id = "finish-or-recycle", PreferredReceiver = "central-forward", Required = {"rest-defense"}, Next = "bounce-pass", Fallback = "bounce-pass", PassBias = "FinishOrRecycle"},
	},
	DirectAssault = {
		{Id = "early-forward-release", PreferredReceiver = "central-forward", Required = {"central-forward", "rest-defense"}, Next = "depth-runner", Fallback = "second-ball-structure", PassBias = "ForwardEarly", Runs = {"central-forward"}},
		{Id = "depth-runner", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "second-ball-structure", Fallback = "early-forward-release", PassBias = "LoftedOrThrough", Runs = {"central-forward", "left-width"}},
		{Id = "second-ball-structure", PreferredReceiver = "second-ball-midfielder", Required = {"second-ball-midfielder", "rest-defense"}, Next = "finish", Fallback = "early-forward-release", PassBias = "SecondBall"},
		{Id = "finish", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "early-forward-release", Fallback = "second-ball-structure", PassBias = "Finish"},
	},
	WideOverload = {
		{Id = "wide-triangle", PreferredReceiver = "ball-side-width", Required = {"ball-side-width", "ball-side-pivot", "left-support"}, Next = "overlap-underlap", Fallback = "far-side-switch", PassBias = "WideTriangle"},
		{Id = "overlap-underlap", PreferredReceiver = "ball-side-width", Required = {"ball-side-width"}, Next = "entry", Fallback = "far-side-switch", PassBias = "WideCombination", Runs = {"overlap", "underlap"}},
		{Id = "entry", PreferredReceiver = "ball-side-width", Required = {"ball-side-width", "box-edge-protection"}, Next = "cutback", Fallback = "far-side-switch", PassBias = "BylineOrHalfSpace", Runs = {"cutback-arrival"}},
		{Id = "cutback", PreferredReceiver = "second-ball-midfielder", Required = {"second-ball-midfielder"}, Next = "wide-triangle", Fallback = "far-side-switch", PassBias = "Cutback", Runs = {"near-post", "far-post"}},
		{Id = "far-side-switch", PreferredReceiver = "far-side-width", Required = {"far-side-width", "rest-defense"}, Next = "wide-triangle", Fallback = "wide-triangle", PassBias = "FarSideSwitch"},
	},
	CentralDomination = {
		{Id = "central-support", PreferredReceiver = "ball-side-pivot", Required = {"ball-side-pivot", "far-side-pivot"}, Next = "wall-pass", Fallback = "central-support", PassBias = "CentralCombination"},
		{Id = "wall-pass", PreferredReceiver = "checking-striker", Required = {"checking-striker", "between-lines-receiver"}, Next = "between-lines-occupation", Fallback = "central-support", PassBias = "WallPass"},
		{Id = "between-lines-occupation", PreferredReceiver = "between-lines-receiver", Required = {"between-lines-receiver"}, Next = "through-ball", Fallback = "wall-pass", PassBias = "BetweenLines"},
		{Id = "through-ball", PreferredReceiver = "central-forward", Required = {"central-forward", "rest-defense"}, Next = "counterpress-protection", Fallback = "between-lines-occupation", PassBias = "Through", Runs = {"central-forward"}},
		{Id = "counterpress-protection", PreferredReceiver = "second-ball-midfielder", Required = {"second-ball-midfielder", "rest-defense"}, Next = "central-support", Fallback = "central-support", PassBias = "Secure"},
	},
	CounterattackingTrap = {
		{Id = "secure-bait", PreferredReceiver = "rest-defense", Required = {"rest-defense"}, Next = "regain", Fallback = "secure-bait", PassBias = "SecureBait"},
		{Id = "regain", PreferredReceiver = "ball-side-pivot", Required = {"ball-side-pivot"}, Next = "first-forward-action", Fallback = "secure-bait", PassBias = "Regain"},
		{Id = "first-forward-action", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "counter-lanes", Fallback = "restore-structure", PassBias = "ForwardFirst", Runs = {"counter-lane"}},
		{Id = "counter-lanes", PreferredReceiver = "left-width", Required = {"left-width", "right-width"}, Next = "second-wave", Fallback = "restore-structure", PassBias = "CounterLane", Runs = {"counter-lane", "second-wave"}},
		{Id = "second-wave", PreferredReceiver = "second-ball-midfielder", Required = {"second-ball-midfielder"}, Next = "restore-structure", Fallback = "restore-structure", PassBias = "SecondWave"},
		{Id = "restore-structure", PreferredReceiver = "ball-side-pivot", Required = {"rest-defense"}, Next = "secure-bait", Fallback = "secure-bait", PassBias = "Restore"},
	},
	HighPressSwarm = {
		{Id = "high-recovery", PreferredReceiver = "ball-side-pivot", Required = {"ball-side-pivot"}, Next = "short-field-chance", Fallback = "counterpress-rest-defense", PassBias = "HighRecovery"},
		{Id = "short-field-chance", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "box-occupation", Fallback = "counterpress-rest-defense", PassBias = "FastChance", Runs = {"near-post", "far-post"}},
		{Id = "box-occupation", PreferredReceiver = "central-forward", Required = {"central-forward", "second-ball-midfielder"}, Next = "counterpress-rest-defense", Fallback = "counterpress-rest-defense", PassBias = "Box"},
		{Id = "counterpress-rest-defense", PreferredReceiver = "rest-defense", Required = {"rest-defense", "second-ball-midfielder"}, Next = "high-recovery", Fallback = "high-recovery", PassBias = "CounterpressRest"},
	},
	LowBlockFortress = {
		{Id = "secure-clearance-outlet", PreferredReceiver = "central-forward", Required = {"rest-defense", "central-forward"}, Next = "controlled-counter", Fallback = "restore-block", PassBias = "SecureClear"},
		{Id = "controlled-counter", PreferredReceiver = "checking-striker", Required = {"checking-striker"}, Next = "second-runner", Fallback = "restore-block", PassBias = "ControlledCounter", Runs = {"checking-striker"}},
		{Id = "second-runner", PreferredReceiver = "left-width", Required = {"left-width", "right-width"}, Next = "restore-block", Fallback = "restore-block", PassBias = "SecondRunner", Runs = {"second-wave"}},
		{Id = "restore-block", PreferredReceiver = "rest-defense", Required = {"rest-defense"}, Next = "secure-clearance-outlet", Fallback = "secure-clearance-outlet", PassBias = "RestoreBlock"},
	},
	FluidRotation = {
		{Id = "rotate-zone", PreferredReceiver = "ball-side-pivot", Required = {"ball-side-pivot"}, Next = "replace-vacated-function", Fallback = "restore-balance", PassBias = "Rotate", Runs = {"third-man"}},
		{Id = "replace-vacated-function", PreferredReceiver = "far-side-pivot", Required = {"far-side-pivot"}, Next = "displace-defender", Fallback = "restore-balance", PassBias = "Replace"},
		{Id = "displace-defender", PreferredReceiver = "between-lines-receiver", Required = {"between-lines-receiver"}, Next = "progress", Fallback = "restore-balance", PassBias = "Displace", Runs = {"underlap"}},
		{Id = "progress", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "restore-balance", Fallback = "restore-balance", PassBias = "Progress"},
		{Id = "restore-balance", PreferredReceiver = "ball-side-pivot", Required = {"rest-defense"}, Next = "rotate-zone", Fallback = "rotate-zone", PassBias = "RestoreBalance"},
	},
	AdaptiveController = {
		{Id = "evaluate-space", PreferredReceiver = "ball-side-pivot", Required = {"rest-defense"}, Next = "choose-route", Fallback = "protect-rest-defense", PassBias = "Evaluate"},
		{Id = "choose-route", PreferredReceiver = "between-lines-receiver", Required = {"between-lines-receiver"}, Next = "commit-route", Fallback = "protect-rest-defense", PassBias = "BestAvailable"},
		{Id = "commit-route", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "protect-rest-defense", Fallback = "protect-rest-defense", PassBias = "Commit", Runs = {"central-forward"}},
		{Id = "protect-rest-defense", PreferredReceiver = "rest-defense", Required = {"rest-defense"}, Next = "evaluate-space", Fallback = "evaluate-space", PassBias = "ProtectRest"},
	},
	SwitchPlay = {
		{Id = "secure", PreferredReceiver = "ball-side-pivot", Required = {"rest-defense", "ball-side-pivot"}, Next = "far-side-switch", Fallback = "secure", PassBias = "Secure"},
		{Id = "far-side-switch", PreferredReceiver = "far-side-width", Required = {"far-side-width", "rest-defense"}, Next = "attack-space", Fallback = "secure", PassBias = "FarSideSwitch"},
		{Id = "attack-space", PreferredReceiver = "central-forward", Required = {"central-forward"}, Next = "secure", Fallback = "secure", PassBias = "Progress"},
	},
}

local FALLBACK = ROUTES.PositionalControl

function Director.new(): any
	return setmetatable({Plans = {Home = nil, Away = nil}}, Director)
end

local function routeFor(identity: string, corridor: string, intentName: string, reaction: any?): {any}
	if reaction then
		if (tonumber(reaction.SwitchPreference) or 0) > .18 then return ROUTES.WideOverload end
		if (tonumber(reaction.CloseEscapeSupport) or 0) > .18 and (tonumber(reaction.DirectOutlet) or 0) > .18 then return ROUTES.VerticalCombination end
		if (tonumber(reaction.CutbackPreference) or 0) > .18 or (tonumber(reaction.BoxEdgeOccupation) or 0) > .18 then return ROUTES.WideOverload end
		if (tonumber(reaction.AttackingWidth) or 0) > .22 and (tonumber(reaction.OutsideInside) or 0) > .1 then return ROUTES.WideOverload end
		if (tonumber(reaction.MixedRoutes) or 0) > .16 then return ROUTES.AdaptiveController end
	end
	if identity ~= "" and ROUTES[identity] then return ROUTES[identity] end
	if intentName == "SwitchPlay" then return ROUTES.SwitchPlay end
	if corridor == "Wide" then return ROUTES.WideOverload end
	if corridor == "Central" then return ROUTES.CentralDomination end
	if intentName == "CounterAttack" or intentName == "DirectRelease" then return ROUTES.DirectAssault end
	return FALLBACK
end

local function stepIndex(route: {any}, id: string?): number
	for index, step in ipairs(route) do
		if step.Id == id then return index end
	end
	return 1
end

local function hasOccupation(context: any, side: string, functionId: string): boolean
	local structures = context.TeamStructures and context.TeamStructures[side]
	if type(structures) == "table" then
		for _, slot in ipairs(structures) do
			if slot.Id == functionId or slot.Function == functionId or slot.ContinuityKey == functionId then
				return true
			end
		end
	end
	local assignments = context.PreviousAssignments and context.PreviousAssignments[side]
	if type(assignments) == "table" then
		for _, assignment in pairs(assignments) do
			local slot = assignment.TacticalSlot
			if slot and (slot.Id == functionId or slot.Function == functionId or slot.ContinuityKey == functionId) then
				return true
			end
		end
	end
	return false
end

local function occupationReady(context: any, side: string, stepDef: any): boolean
	for _, required in ipairs(stepDef.Required or {}) do
		if not hasOccupation(context, side, required) then
			return false
		end
	end
	return true
end

local function ballZone(context: any, side: string): string
	local ball = context.BallTeam[side]
	if ball.Z >= 610 then return "Box" end
	if ball.Z >= 520 then return "FinalThird" end
	if ball.Z >= 360 then return "Progression" end
	if ball.Z <= 170 then return "Build" end
	return "Middle"
end

local function carrierPressure(context: any, side: string): boolean
	local owner = context.Owner
	if not owner or context.OwnerSide ~= side then return false end
	local carrier = context.Players and context.Players[owner]
	if not carrier then return false end
	local closest = math.huge
	for _, opponent in ipairs(context.Teams[carrier.OpponentSide].List) do
		if opponent.Root then
			closest = math.min(closest, PitchConfig.GetDistanceStuds(carrier.World, opponent.World))
		end
	end
	return closest <= 16
end

local function completedPassEvent(context: any, side: string, current: any): boolean
	local owner = context.Owner
	if not owner or context.OwnerSide ~= side then return false end
	if current.LastOwner == nil then return false end
	if current.LastOwner ~= owner and current.LastOwnerSide == side then
		return true
	end
	local receivedAt = tonumber(owner:GetAttribute("AILastPassReceivedAt")) or 0
	return receivedAt > (current.LastEventAt or current.StartedAt or 0)
end

local function farSideReached(context: any, side: string, current: any): boolean
	local owner = context.Owner
	if not owner or context.OwnerSide ~= side then return false end
	local info = context.Players and context.Players[owner]
	if not info then return false end
	local startBallX = tonumber(current.StepStartedBallX) or PitchConfig.HALF_WIDTH
	return math.abs(info.Pitch.X - startBallX) >= 150 and (info.Pitch.X < 105 or info.Pitch.X > 319)
end

local function runnerCrossed(context: any, side: string): boolean
	local assignments = context.PreviousAssignments and context.PreviousAssignments[side]
	if type(assignments) ~= "table" then return false end
	for model, assignment in pairs(assignments) do
		if assignment.RunApproved == true and assignment.RunContract then
			local info = context.Players and context.Players[model]
			if info and info.Pitch.Z >= 560 then
				return true
			end
		end
	end
	return false
end

local function overloadBlocked(context: any, side: string): boolean
	if not carrierPressure(context, side) then return false end
	local ball = context.BallTeam[side]
	local ballSideCount = 0
	for _, opponent in ipairs(context.Teams[side == "Home" and "Away" or "Home"].List) do
		local opponentPitch = PitchConfig.WorldToTeamPitchPosition(opponent.World, side, context.Options)
		if opponent.Root and math.abs(opponentPitch.X - ball.X) <= 85 and math.abs(opponentPitch.Z - ball.Z) <= 85 then
			ballSideCount += 1
		end
	end
	return ballSideCount >= 3
end

local function eventFor(context: any, side: string, current: any, stepDef: any): string
	if context.OwnerSide and context.OwnerSide ~= side then return "Turnover" end
	if context.LooseBall then return "Turnover" end
	if not occupationReady(context, side, stepDef) then return "RequiredOccupationMissing" end
	if overloadBlocked(context, side) and (stepDef.Id == "wide-triangle" or stepDef.Id == "overlap-underlap" or stepDef.Id == "entry") then return "OverloadBlocked" end
	if completedPassEvent(context, side, current) then return "CompletedPass" end
	if farSideReached(context, side, current) and (stepDef.Id == "switch-ready" or stepDef.Id == "far-side-switch") then return "FarSideReached" end
	if runnerCrossed(context, side) then return "RunnerThreshold" end
	local zone = ballZone(context, side)
	if zone == "FinalThird" or zone == "Box" then return "ZoneEntry" end
	if carrierPressure(context, side) then return "CarrierPressure" end
	local maxHold = tonumber(stepDef.MaximumHold) or 1.6
	if (context.Now or os.clock()) - (current.StepStartedAt or current.StartedAt or 0) >= maxHold and (stepDef.Id == "commit-route" or stepDef.Id == "protect-rest-defense") then
		return "CommitWindowComplete"
	end
	return "Hold"
end

local function nextStepId(stepDef: any, eventName: string): string
	if eventName == "Turnover" or eventName == "RequiredOccupationMissing" then
		return tostring(stepDef.Fallback or stepDef.Id)
	end
	if eventName == "OverloadBlocked" then
		return "far-side-switch"
	end
	if eventName == "CarrierPressure" and (stepDef.Id == "reset" or stepDef.Id == "secure-bait") then
		return tostring(stepDef.Next or stepDef.Id)
	end
	if eventName == "CompletedPass" or eventName == "ZoneEntry" or eventName == "RunnerThreshold" or eventName == "FarSideReached" or eventName == "CommitWindowComplete" then
		return tostring(stepDef.Next or stepDef.Id)
	end
	return tostring(stepDef.Id)
end

local function planStep(stepDef: any, intentName: string): any
	return AITacticalContract.PlanStep({
		Id = stepDef.Id,
		EntryConditions = stepDef.Entry or {intentName},
		RequiredOccupations = stepDef.Required or {},
		PreferredReceiver = stepDef.PreferredReceiver,
		MinimumHold = stepDef.MinimumHold or .18,
		MaximumHold = stepDef.MaximumHold or 1.7,
		CompletionConditions = stepDef.Completion or {"CompletedPass", "ZoneEntry", "RunnerThreshold"},
		FailureConditions = stepDef.Failure or {"Turnover", "RequiredOccupationMissing", "CarrierPressure"},
		NextStep = stepDef.Next,
		FallbackStep = stepDef.Fallback,
		PassBias = stepDef.PassBias or "Balanced",
		RunRequests = stepDef.Runs or {},
	})
end

local function applySequenceRules(step: any, rules: any): any
	if type(rules) ~= "table" then return step end
	local nextStep = table.clone(step)
	if rules.NextStep then nextStep.NextStep = rules.NextStep end
	if rules.FallbackStep then nextStep.FallbackStep = rules.FallbackStep end
	if rules.PreferredReceiver then nextStep.PreferredReceiver = rules.PreferredReceiver end
	if rules.RequiredOccupations then
		nextStep.RequiredOccupations = {}
		for key in pairs(rules.RequiredOccupations) do table.insert(nextStep.RequiredOccupations, key) end
	end
	if rules.RunRequests then
		nextStep.RunRequests = table.clone(nextStep.RunRequests or {})
		for key in pairs(rules.RunRequests) do table.insert(nextStep.RunRequests, key) end
	end
	return AITacticalContract.PlanStep(nextStep)
end

function Director:Update(context: any, side: string, intent: any, spatial: any, memory: any): any
	local now = context.Now or os.clock()
	local intentName = tostring(intent and intent.Intent or "")
	local teamBrain = context.TeamBrain and context.TeamBrain[side]
	local identity = tostring(teamBrain and teamBrain.AttackingIdentity or "")
	local corridor = tostring(teamBrain and teamBrain.AttackCorridor or "")
	local reaction = context.TeamReactions and context.TeamReactions[side] and context.TeamReactions[side].AgainstOpponentDefense
	local route = routeFor(identity, corridor, intentName, reaction)
	local current = self.Plans[side]
	if not current or current.Intent ~= intentName or current.TeamIdentity ~= identity then
		local first = route[1]
		current = {
			Intent = intentName,
			TeamIdentity = identity,
			AttackCorridor = corridor,
			StartedAt = now,
			StepStartedAt = now,
			LastEventAt = now,
			Step = 1,
			Route = {},
			StepId = first.Id,
			Owner = context.Owner,
			LastOwner = context.Owner,
			LastOwnerSide = context.OwnerSide,
			StepStartedBallX = context.BallTeam[side].X,
			Events = {},
		}
	end
	local index = stepIndex(route, current.StepId)
	local stepDef = route[index]
	local eventName = eventFor(context, side, current, stepDef)
	local nextId = nextStepId(stepDef, eventName)
	if nextId ~= stepDef.Id then
		local nextIndex = stepIndex(route, nextId)
		local nextDef = route[nextIndex]
		table.insert(current.Events, {At = now, Event = eventName, From = stepDef.Id, To = nextDef.Id})
		current.Step = nextIndex
		current.StepId = nextDef.Id
		current.StepStartedAt = now
		current.StepStartedBallX = context.BallTeam[side].X
		current.LastEventAt = now
		stepDef = nextDef
		eventName = "EnteredStep"
	else
		current.Step = index
	end
	current.Route = {}
	for _, item in ipairs(route) do table.insert(current.Route, item.Id) end
	current.Owner = context.Owner
	current.LastOwner = context.Owner
	current.LastOwnerSide = context.OwnerSide
	current.LastEvent = eventName
	current.ExpiresAt = now + 8
	current.PlanStep = applySequenceRules(planStep(stepDef, intentName), context.RuleEffects and context.RuleEffects[side] and context.RuleEffects[side].Sequence)
	self.Plans[side] = current
	if memory then memory:RememberPlan(side, current) end
	return current
end

function Director:Reset(side: string?)
	if side then self.Plans[side] = nil else self.Plans = {Home = nil, Away = nil} end
end

return Director
