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
		Accum = {Phase = 0.05, Assignment = 0.05, OnBall = 0.04, Movement = 0.04, Debug = 0.25},
		Phases = {Home = "LooseBall", Away = "LooseBall"},
		CurrentAssignments = {Home = {}, Away = {}},
		LastContext = nil,
		WasLive = false,
		LastDebugLive = nil,
		LastDebugOwner = nil,
		PressState = {
			LastOwner = nil,
			LastOwnerSide = nil,
			Primary = {Home = nil, Away = nil},
			PrimaryOwner = {Home = nil, Away = nil},
			Shadow = {},
		},
	}, Service)
end

local function debugEnabled(): boolean
	return workspace:GetAttribute("VTRKickoffDebug") ~= false
end

local function debugKickoff(message: string, ...: any)
	if debugEnabled() then
		print("[VTR KICKOFF][AI] " .. message, ...)
	end
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

function Service:_updatePressState(context: any)
	local owner = context.Owner
	local side = context.OwnerSide
	context.DefensivePress = {Home = {}, Away = {}}
	context.PressPaused = {Home = false, Away = false}
	local now = context.Now
	for model, shadow in pairs(self.PressState.Shadow) do
		if not model.Parent or (shadow.Until or 0) <= now then
			self.PressState.Shadow[model] = nil
		end
	end
	for _, defendingSide in ipairs({"Home", "Away"}) do
		local press = context.DefensivePress[defendingSide]
		local defending = owner and side and side ~= defendingSide
		local ballPitch = context.BallTeam[defendingSide]
		local ownerInfo = owner and context.Players[owner] or nil
		local strikerInDefensiveThird = ownerInfo and ownerInfo.Role == "ST" and ownerInfo.Pitch.Z <= (742 / 3)
		local trigger = defending and (ballPitch.Z <= 192 or strikerInDefensiveThird)
		if not trigger then
			self.PressState.Primary[defendingSide] = nil
			self.PressState.PrimaryOwner[defendingSide] = nil
			continue
		end
		if not ownerInfo then
			continue
		end
		local current = self.PressState.Primary[defendingSide]
		local currentOwner = self.PressState.PrimaryOwner[defendingSide]
		if current and currentOwner and currentOwner ~= owner then
			self.PressState.Shadow[current] = {Target = currentOwner, Until = now + 1}
			current = nil
		end
		if not current or not current.Parent or current:GetAttribute("VTRSentOff") == true or current:GetAttribute("VTRRedCard") == true then
			local bestMidfielder, bestMidDistance = nil, math.huge
			local bestDefender, bestDefDistance = nil, math.huge
			for _, info in ipairs(context.Teams[defendingSide].List) do
				if info.Root and not info.IsGoalkeeper and self.PressState.Shadow[info.Model] == nil then
					local role = info.Role
					local eligibleMid = role == "CDM" or role == "CM" or role == "CAM"
					local eligibleDef = role == "Fullback" or role == "CB"
					if eligibleMid or eligibleDef then
						local delta = info.World - ownerInfo.World
						local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
						if eligibleMid and distance < bestMidDistance then
							bestMidfielder, bestMidDistance = info.Model, distance
						elseif eligibleDef and distance < bestDefDistance then
							bestDefender, bestDefDistance = info.Model, distance
						end
					end
				end
			end
			current = bestMidfielder or bestDefender
			self.PressState.Primary[defendingSide] = current
			self.PressState.PrimaryOwner[defendingSide] = owner
		end
		press.Active = current ~= nil
		press.Primary = current
		press.Owner = owner
		press.Shadow = self.PressState.Shadow
	end
end

function Service:Step(dt: number)
	local live = self:_isLive()
	if self.LastDebugLive ~= live then
		self.LastDebugLive = live
		debugKickoff("live state changed", "live", live, "externalPhase", self.ExternalPhase)
	end
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
	self:_updatePressState(context)
	self.LastContext = context
	if context.Owner ~= self.LastDebugOwner then
		self.LastDebugOwner = context.Owner
		debugKickoff("context owner changed", "owner", context.Owner and context.Owner.Name or "nil", "ownerSide", context.OwnerSide or "nil", "loose", context.LooseBall, "motion", context.MotionKind)
	end
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
	if self.Accum.Phase >= 0.05 then
		self.Accum.Phase = 0
		self.Phases = self.Phase:Update(context, true)
	end

	self.Accum.Assignment += dt
	if self.Accum.Assignment >= 0.05 or not next(self.CurrentAssignments.Home) then
		self.Accum.Assignment = 0
		self.CurrentAssignments = {
			Home = self.Assignments.Home:BuildSide(context, "Home", self.Phases.Home or "LooseBall"),
			Away = self.Assignments.Away:BuildSide(context, "Away", self.Phases.Away or "LooseBall"),
		}
		if debugEnabled() and context.Owner and (tonumber(context.Owner:GetAttribute("VTRKickoffReturnUntil")) or 0)>context.Now then
			local debugAt=tonumber(context.Owner:GetAttribute("VTRKickoffAIDebugAt"))or 0
			if context.Now-debugAt>.35 then
				context.Owner:SetAttribute("VTRKickoffAIDebugAt",context.Now)
				for model,assignment in pairs(self.CurrentAssignments[context.OwnerSide=="Home"and"Away"or"Home"])do
					if assignment.PrimaryAssignment=="PressBallCarrier"or assignment.PrimaryAssignment=="ContainBallCarrier"or assignment.PrimaryAssignment=="CoverPresser"then
						local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
						local ownerRoot=context.Owner:FindFirstChild("HumanoidRootPart")::BasePart?
						debugKickoff("defensive pressure assigned","defender",model.Name,"assignment",assignment.PrimaryAssignment,"distance",root and ownerRoot and math.floor((root.Position-ownerRoot.Position).Magnitude*10)/10 or "n/a","target",assignment.MovementTarget)
					end
				end
			end
		end
	end

	self.Accum.OnBall += dt
	if self.Accum.OnBall >= 0.04 then
		self.Accum.OnBall = 0
		self.Brain.Home:StepSide(context, self.CurrentAssignments, "Home")
		self.Brain.Away:StepSide(context, self.CurrentAssignments, "Away")
	end

	self.Accum.Movement += dt
	if self.Accum.Movement >= 0.04 then
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
