--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local GameplayConfig=require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local ActionTuning=require(ReplicatedStorage.VTR.Shared.ActionTuningConfig)
local ReceiverAssistConfig=require(ReplicatedStorage.VTR.Shared.ReceiverAssistConfig)
local DefensiveSwitchConfig=require(ReplicatedStorage.VTR.Shared.DefensiveSwitchConfig)
local ReceiverSwitchResolver=require(ReplicatedStorage.VTR.Shared.ReceiverSwitchResolver)
local ShotPowerModel=require(ReplicatedStorage.VTR.Shared.ShotPowerModel)
local PassTargetingService = require(script.Parent.PassTargetingService)
local PassingService = require(script.Parent.PassingService)
local PassReceptionService = require(script.Parent.PassReceptionService)
local MovementSmoothingService = require(script.Parent.MovementSmoothingService)
local DribbleControlService = require(script.Parent.DribbleControlService)
local RunService = game:GetService("RunService")

local Service = {}
Service.__index = Service

local function root(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function validDirection(value: any): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z and value.Magnitude <= 1.1
end

local function debugEnabled(): boolean
	return workspace:GetAttribute("VTRKickoffDebug") == true and (RunService:IsStudio() or game.PrivateServerId ~= "")
end

local function debugKickoff(message: string, ...: any)
	if debugEnabled() then
		print("[VTR KICKOFF][TeamControl] " .. message, ...)
	end
end

function Service.new(remote: RemoteEvent, teams: any, ball: BasePart, possession: any, ballService: any, pitchCFrame: CFrame, width: number, length: number, animations: any?)
	local targeting = PassTargetingService.new(teams, pitchCFrame)
	local self = setmetatable({
		Remote = remote, Teams = teams, Ball = ball, Possession = possession, BallService = ballService,
		Passing = PassingService.new(ballService, targeting, remote, teams),
		Smoothing = MovementSmoothingService.new(),
		PitchCFrame = pitchCFrame, Width = width, Length = length, Animations = animations, Active = {}, PlayerSides = {}, PendingDefensiveSwitch = {}, DefensiveAutoSwitchMode = {}, LastMovementAt = {}, LastPossessionOwner = nil, ManualSwitchAwayUntil = {}, LastManualSwitchAt = {}, LastAutomaticSwitch = {}, PendingShots = {}, FixedActive = {}, LastKickSequence = {}, Telemetry = nil,
	}, Service)
	self.Reception = PassReceptionService.new(remote, teams, ball, possession, ballService, pitchCFrame, width, length)
	self.Reception:SetTeamControl(self)
	if ballService.SetPassReceptionService then ballService:SetPassReceptionService(self.Reception) end
	return self
end

function Service:SetTelemetry(callback: any)
	self.Telemetry = callback
	if self.Reception then self.Reception:SetTelemetry(callback) end
end

function Service:_emitTelemetry(player: Player, eventName: string, properties: any?)
	if self.Telemetry then self.Telemetry(player, eventName, properties or {}) end
end

local function etaBand(value: number): string
	if value == math.huge then return "unreachable" end
	if value <= .25 then return "0-.25" end
	if value <= .5 then return ".25-.5" end
	if value <= 1 then return ".5-1" end
	if value <= 2 then return "1-2" end
	return "2+"
end

local function powerBand(value: number): string
	if value < .25 then return "0-.25" end
	if value < .5 then return ".25-.5" end
	if value < .75 then return ".5-.75" end
	if value < .9 then return ".75-.9" end
	return ".9-1"
end

function Service:SetDefensiveAutoSwitch(player: Player, mode: any)
	self.DefensiveAutoSwitchMode[player] = DefensiveSwitchConfig.Normalize(mode)
	if self.DefensiveAutoSwitchMode[player] == "Manual" then self.PendingDefensiveSwitch[player] = nil end
end

function Service:SetManualReceiveOverride(player: Player, active: boolean, contractId: any?, revision: any?, clientTimestamp: any?)
	local model = self.Active[player]
	if model and self.Reception then self.Reception:SetOverride(player, model, active == true, contractId, revision, clientTimestamp) end
end

function Service:CancelReception(reason: string): boolean
	return self.Reception and self.Reception:Cancel(reason) or false
end

function Service:CancelReceptionForReceiver(receiver: Model, reason: string): boolean
	return self.Reception and self.Reception:CancelForReceiver(receiver, reason) or false
end

function Service:CancelReceptionQueuedAction(player: Player, reason: string, contractId: any?, revision: any?)
	if self.Reception then self.Reception:CancelQueuedAction(player, reason, contractId, revision) end
end

function Service:CancelAllReceptionQueuedActions(reason: string)
	if not self.Reception then return end
	for player in self.Active do self.Reception:CancelQueuedAction(player, reason) end
end

function Service:GetReceptionDiagnostics(): any
	return self.Reception and self.Reception:GetDiagnostics() or {ActiveContractCount = 0}
end

function Service:_shotAnimationName(model:Model,direction:Vector3?):string
	local modelRoot=root(model)
	if not modelRoot then return "ShootRight" end
	local velocity=Vector3.new(modelRoot.AssemblyLinearVelocity.X,0,modelRoot.AssemblyLinearVelocity.Z)
	local shot=Vector3.new((direction or Vector3.zero).X,0,(direction or Vector3.zero).Z)
	local facing=shot.Magnitude>.08 and shot.Unit or Vector3.new(modelRoot.CFrame.LookVector.X,0,modelRoot.CFrame.LookVector.Z)
	if facing.Magnitude<.05 then return "ShootRight" end
	local aimReference=facing.Unit
	local shotRight=Vector3.new(-aimReference.Z,0,aimReference.X)
	if velocity.Magnitude>1.15 then
		local movementSide=velocity.Unit:Dot(shotRight)
		if math.abs(movementSide)>.12 then
			return movementSide<0 and "ShootLeft" or "ShootRight"
		end
	end
	local bodyRight=Vector3.new(modelRoot.CFrame.RightVector.X,0,modelRoot.CFrame.RightVector.Z)
	if bodyRight.Magnitude<.05 then return "ShootRight" end
	return aimReference:Dot(bodyRight.Unit)<-0.08 and "ShootLeft" or "ShootRight"
end

function Service:_releaseShotOnMarker(model:Model,animationName:string,release:()->())
	if self.PendingShots[model] then return end
	local token=os.clock()
	self.PendingShots[model]=token
	model:SetAttribute("VTRShotAnimationPending",true)
	local function finish()
		if self.PendingShots[model]~=token then return end
		self.PendingShots[model]=nil
		if model.Parent then
			model:SetAttribute("VTRShotAnimationPending",nil)
			model:SetAttribute("VTRSuppressNextShotAnimation",true)
		end
		release()
	end
	if self.Animations and self.Animations.PlayActionWithMarker then
		self.Animations:PlayActionWithMarker(model,animationName,"Shoot",ActionTuning.Profile("Shot").ReleaseFallbackSeconds,finish)
	else
		task.delay(.18,finish)
	end
end

function Service:GetActive(player: Player): Model?
	return self.Active[player]
end

function Service:_set(player: Player, model: Model, reason: string)
	local fixed = self.FixedActive[player]
	if fixed and fixed ~= model then return end
	if (tonumber(model:GetAttribute("VTRStunnedUntil")) or 0) > os.clock() then return end
	local previous = self.Active[player]
	if previous == model then return end
	local preservedReception = reason == "Manual" and self.Reception and self.Reception.ManualSwitchToReceiver and self.Reception:ManualSwitchToReceiver(player, model) or false
	if reason == "Manual" and previous and self.Reception and not preservedReception then
		self.Reception:CancelForPlayer(player, "ManualOverride")
	end
	if previous then
		previous:SetAttribute("controlledByUser", false)
		previous:SetAttribute("aiControlled", true)
		previous:SetAttribute("VTRUserId", nil)
		previous:SetAttribute("VTRCloseControl", false)
		previous:SetAttribute("VTRManualReceiveOverride", false)
		self.Smoothing:Clear(previous)
		if self.Possession:GetOwner() == previous then self.Ball:SetAttribute("OwnerUserId", 0) end
	end
	self.Active[player] = model
	local now=os.clock()
	if reason == "Manual" then
		self.LastManualSwitchAt[player] = now
		local automatic=self.LastAutomaticSwitch[player]
		if automatic and now-(tonumber(automatic.At)or 0)<=1.25 then self:_emitTelemetry(player,"playability_automatic_switch_undone",{previousSwitchReason=tostring(automatic.Reason or"Unknown")})end
		self.LastAutomaticSwitch[player]=nil
	elseif reason=="DefensivePassThreat"or reason=="PassReceiver"or reason=="PassReceived"or reason=="AlternateReceiver"or reason=="PossessionWon"or reason=="GoalkeeperClaim"then
		self.LastAutomaticSwitch[player]={At=now,Reason=reason}
	end
	if reason=="DefensivePassThreat"then self:_emitTelemetry(player,"playability_forced_defensive_switch",{switchMode=DefensiveSwitchConfig.Normalize(self.DefensiveAutoSwitchMode[player],"Standard")})end
	local humanoid=model:FindFirstChildOfClass("Humanoid")
	local modelRoot=root(model)
	-- Cancel the final AI steering command immediately. Waiting for the next AI
	-- heartbeat made the selected footballer appear to slide/teleport before the
	-- user's first input took control.
	if humanoid then
		humanoid:Move(Vector3.zero,false)
		if modelRoot then humanoid:MoveTo(modelRoot.Position) end
	end
	model:SetAttribute("controlledByUser", true)
	model:SetAttribute("aiControlled", false)
	model:SetAttribute("VTRUserId", player.UserId)
	model:SetAttribute("VTRCloseControl", false)
	model:SetAttribute("VTRControlSwitchedAt",os.clock())
	model:SetAttribute("VTRImmediateControlUntil",os.clock()+.9)
	if model:GetAttribute("VTRManualReceiveOverride") == nil then model:SetAttribute("VTRManualReceiveOverride", false) end
	if self.Possession:GetOwner() == model and tostring(model:GetAttribute("position") or "") == "GK" then
		model:SetAttribute("VTRKeeperMustDistributeUntil", nil)
		model:SetAttribute("AIAssignment", "GoalkeeperPosition")
		model:SetAttribute("VTRNoAutoPassUntil", os.clock() + 999)
	end
	if self.Possession:GetOwner() == model then self.Ball:SetAttribute("OwnerUserId", player.UserId) end
	self.Remote:FireClient(player, {Type = "ActivePlayer", Model = model, Name = model:GetAttribute("DisplayName"), Position = model:GetAttribute("position"), Reason = reason})
end

function Service:Register(player: Player, side: string?): Model
	side=side=="Away"and"Away"or"Home";self.PlayerSides[player]=side
	local team=self.Teams[side]
	local initial = team[10]
	if not initial then
		for _, model in team do
			if tostring(model:GetAttribute("position") or "") ~= "GK" then
				initial = model
				break
			end
		end
	end
	initial = initial or team[1]
	self:_set(player, initial, "Kickoff")
	return initial
end

function Service:SetActive(player: Player, model: Model, reason: string)
	self:_set(player, model, reason)
end

function Service:CanReceptionTransfer(player: Player, receiver: Model): boolean
	if self.FixedActive[player] and self.FixedActive[player] ~= receiver then return false end
	if (tonumber(self.ManualSwitchAwayUntil[player]) or 0) > os.clock() then return false end
	if (tonumber(self.LastManualSwitchAt[player]) or 0) + 1.25 > os.clock() then return false end
	return receiver.Parent ~= nil and receiver:GetAttribute("VTRSentOff") ~= true and (tonumber(receiver:GetAttribute("VTRStunnedUntil")) or 0) <= os.clock()
end

function Service:OnReceptionCollector(player: Player, collector: Model, reason: string, _autoSwitchMode: string)
	if not self:CanReceptionTransfer(player, collector) then return end
	if self.Active[player] ~= collector then
		self:_set(player, collector, reason == "AlternateTeammateControlled" and "AlternateReceiver" or "PassReceived")
	end
end

function Service:LockActive(player: Player, model: Model, reason: string?)
	self.FixedActive[player] = model
	self:_set(player, model, reason or "FixedControl")
end

function Service:_nearestUseful(player: Player): Model?
	local current = self.Active[player]
	local owner = self.Possession:GetOwner()
	local side=self.PlayerSides[player]or"Home"
	local defending = owner == nil or owner:GetAttribute("VTRTeam") ~= side
	local currentRoot = root(current)
	local targetPosition = defending and self.Ball.Position or (currentRoot and currentRoot.Position or self.Ball.Position)
	local best: Model? = nil
	local bestDistance = math.huge
	for _, model in self.Teams[side] do
		if model ~= current then
			local modelRoot = root(model)
			if modelRoot then
				local distance = (modelRoot.Position - targetPosition).Magnitude
				if distance < bestDistance then best, bestDistance = model, distance end
			end
		end
	end
	return best
end

function Service:_closestToBall(player: Player): Model?
	local current = self.Active[player]
	local side=self.PlayerSides[player]or"Home"
	local best: Model? = nil
	local bestDistance = math.huge
	for _, model in self.Teams[side] or {} do
		if model ~= current then
			local modelRoot = root(model)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if modelRoot and humanoid and humanoid.Health > 0 and model:GetAttribute("VTRSentOff") ~= true then
				local flat = Vector3.new(modelRoot.Position.X - self.Ball.Position.X, 0, modelRoot.Position.Z - self.Ball.Position.Z)
				local distance = flat.Magnitude
				if distance < bestDistance then
					best = model
					bestDistance = distance
				end
			end
		end
	end
	return best
end

function Service:_closestTeammateToPoint(player: Player, active: Model, point: Vector3): Model?
	local side = self.PlayerSides[player] or tostring(active:GetAttribute("VTRTeam") or "Home")
	local best: Model? = nil
	local bestDistance = math.huge
	for _, teammate in self.Teams[side] or {} do
		if teammate ~= active then
			local teammateRoot = root(teammate)
			if teammateRoot then
				local flatOffset = Vector3.new(teammateRoot.Position.X - point.X, 0, teammateRoot.Position.Z - point.Z)
				local distance = flatOffset.Magnitude
				if distance < bestDistance then
					best = teammate
					bestDistance = distance
				end
			end
		end
	end
	return best
end

function Service:_queueDefensiveSwitch(attackingSide: string, passTarget: Vector3)
	local defendingSide = attackingSide == "Home" and "Away" or "Home"
	for player, active in self.Active do
		local mode = DefensiveSwitchConfig.Normalize(self.DefensiveAutoSwitchMode[player], "Standard")
		if self.PlayerSides[player] == defendingSide and not self.FixedActive[player] and mode ~= "Manual" then
			self.PendingDefensiveSwitch[player] = {
				Active = active,
				Target = passTarget,
				InitialDirection = self.Ball.AssemblyLinearVelocity,
				Started = os.clock(),
				Mode = mode,
			}
		end
	end
end

function Service:_trajectoryETA(): number?
	local active = self.BallService and self.BallService.ActiveTrajectory
	local data = active and active.Data
	if type(data) ~= "table" then return nil end
	local started = tonumber(data.StartServerTime)
	local duration = tonumber(data.Duration)
	if not started or not duration then return nil end
	return math.max(0, started + duration - workspace:GetServerTimeNow())
end

function Service:_livePassTarget(fallback: Vector3): Vector3
	local target = self.BallService and self.BallService.PassTargetPoint or self.Ball:GetAttribute("VTRPassTarget")
	return typeof(target) == "Vector3" and target or fallback
end

function Service:_selectLikelyCollector(side: string, target: Vector3): any?
	local candidates = {}
	for _, model in self.Teams[side] or {} do
		local modelRoot = root(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		table.insert(candidates, {
			Model = model,
			Key = model.Name,
			Position = modelRoot and modelRoot.Position or nil,
			Velocity = modelRoot and modelRoot.AssemblyLinearVelocity or Vector3.zero,
			Speed = humanoid and math.max(humanoid.WalkSpeed, 18) or 18,
			Valid = modelRoot ~= nil and humanoid ~= nil and humanoid.Health > 0 and model:GetAttribute("VTRSentOff") ~= true and (tonumber(model:GetAttribute("VTRStunnedUntil")) or 0) <= os.clock(),
		})
	end
	return ReceiverSwitchResolver.SelectCollector(candidates, target)
end

function Service:_stepDefensiveSwitches()
	for player, entry in self.PendingDefensiveSwitch do
		local mode = DefensiveSwitchConfig.Normalize(self.DefensiveAutoSwitchMode[player] or entry.Mode, "Standard")
		local current = self.Active[player]
		if mode == "Manual" or self.FixedActive[player] or not current or self.BallService.MotionKind ~= "Pass" or self.Possession:GetOwner() ~= nil then
			self.PendingDefensiveSwitch[player] = nil
			continue
		end
		local target = self:_livePassTarget(entry.Target)
		local best = self:_selectLikelyCollector(self.PlayerSides[player] or "Home", target)
		local bestModel = best and best.Model
		local currentRoot = root(current)
		local ballETA = ReceiverSwitchResolver.EstimateBallETA(self.Ball.Position, self.Ball.AssemblyLinearVelocity, target, self:_trajectoryETA())
		local currentETA = currentRoot and ReceiverSwitchResolver.EstimatePlayerETA(currentRoot.Position, currentRoot.AssemblyLinearVelocity, target, 20) or math.huge
		local bestETA = best and best.ContactETA or math.huge
		local tuning = DefensiveSwitchConfig.Get(mode)
		local recentManual = os.clock() - (tonumber(self.LastManualSwitchAt[player]) or -math.huge) < 2 or (tonumber(self.ManualSwitchAwayUntil[player]) or 0) > os.clock()
		local improvement = currentETA - bestETA
		local currentCanContest = currentETA <= ballETA + tuning.CurrentContestGrace
		local highConfidence = bestModel and bestModel ~= current and ballETA <= tuning.ThreatETA and improvement >= tuning.MinimumAdvantage and not currentCanContest and not recentManual
		if not highConfidence then
			if ballETA == math.huge or ballETA <= 0.05 then self.PendingDefensiveSwitch[player] = nil end
			continue
		end
		if entry.PreviewedAt == nil then
			entry.PreviewedAt = os.clock()
			entry.Recommended = bestModel
			self.Remote:FireClient(player, {Type = "DefensiveSwitchRecommendation", Model = bestModel, ETA = ballETA, Mode = mode})
			self:_emitTelemetry(player,"playability_defensive_switch_recommendation",{switchMode=mode,etaBand=etaBand(ballETA),etaAdvantageBand=etaBand(math.max(0,improvement))})
		elseif entry.Recommended == bestModel and os.clock() - entry.PreviewedAt >= tuning.PreviewSeconds then
			self.PendingDefensiveSwitch[player] = nil
			self:_set(player, bestModel, "DefensivePassThreat")
		end
	end
end

function Service:_aimPoint(active: Model, value: any, goalTarget: boolean?): Vector3?
	if typeof(value) ~= "Vector3" or value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z then return nil end
	local localPoint = self.PitchCFrame:PointToObjectSpace(value)
	if goalTarget then
		local homeRectangle = GoalModelResolver.ResolveSide("Home", self.PitchCFrame, self.Width, self.Length)
		local awayRectangle = GoalModelResolver.ResolveSide("Away", self.PitchCFrame, self.Width, self.Length)
		local homePoint = GoalModelResolver.ClampPoint(homeRectangle, value)
		local awayPoint = GoalModelResolver.ClampPoint(awayRectangle, value)
		local rectangle = (homePoint - value).Magnitude <= (awayPoint - value).Magnitude and homeRectangle or awayRectangle
		local clamped=GoalModelResolver.ClampPoint(rectangle,value);local offset=clamped-rectangle.PlanePoint;local x=math.clamp(offset:Dot(rectangle.Right),rectangle.Left+GameplayConfig.Ball.Radius*.12,rectangle.RightBound-GameplayConfig.Ball.Radius*.12);local safeBottom=math.min(rectangle.Top,rectangle.Bottom+GameplayConfig.Ball.Radius*.45);local safeTop=math.max(safeBottom,rectangle.Top-GameplayConfig.Ball.Radius*.18);local y=math.clamp(offset:Dot(rectangle.Up),safeBottom,safeTop);return GoalModelResolver.Point(rectangle,x,y)
	else
		localPoint = Vector3.new(math.clamp(localPoint.X, -self.Width / 2, self.Width / 2), 0.15, math.clamp(localPoint.Z, -self.Length / 2, self.Length / 2))
	end
	return self.PitchCFrame:PointToWorldSpace(localPoint)
end

function Service:_clampGoalkeeperBox(model: Model)
	if tostring(model:GetAttribute("position")) ~= "GK" then return end
	local modelRoot = root(model)
	if not modelRoot then return end
	local localPosition = self.PitchCFrame:PointToObjectSpace(modelRoot.Position)
	local goalSign = localPosition.Z >= 0 and 1 or -1
	local boxDepth = 142
	local zMin = goalSign > 0 and self.Length * .5 - boxDepth or -self.Length * .5 + 4
	local zMax = goalSign > 0 and self.Length * .5 - 4 or -self.Length * .5 + boxDepth
	if zMin > zMax then zMin, zMax = zMax, zMin end
	local clamped = Vector3.new(
		math.clamp(localPosition.X, -self.Width * .29, self.Width * .29),
		localPosition.Y,
		math.clamp(localPosition.Z, zMin, zMax)
	)
	if (clamped - localPosition).Magnitude > .15 then
		local world = self.PitchCFrame:PointToWorldSpace(clamped)
		local facing = Vector3.new(modelRoot.CFrame.LookVector.X, 0, modelRoot.CFrame.LookVector.Z)
		model:PivotTo(CFrame.lookAt(world, world + (facing.Magnitude > .05 and facing.Unit or self.PitchCFrame.LookVector)))
	end
end

function Service:_isShotNearGoal(active: Model, aimPoint: Vector3?): boolean
	if not aimPoint then return false end
	local side = tostring(active:GetAttribute("VTRTeam") or "Home")
	local attackSign = side == "Home" and -1 or 1
	local localPoint = self.PitchCFrame:PointToObjectSpace(aimPoint)
	return localPoint.Z * attackSign > self.Length * 0.32 and math.abs(localPoint.X) < self.Width * 0.42
end

function Service:Handle(player: Player, payload: any)
	local active = self.Active[player]
	if not active or type(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "Pass" or kind == "Shot" or kind == "Clearance" then
		local sequence = tonumber(payload.SequenceId)
		if sequence then
			local last = tonumber(self.LastKickSequence[player]) or 0
			if sequence <= last then return end
			self.LastKickSequence[player] = sequence
		end
	end
	if (kind == "Pass" or kind == "Shot" or kind == "Clearance") and active:GetAttribute("VTRGoalkeeperHolding") == true then
		if self.BallService and self.BallService.PrepareGoalkeeperBallAction then
			self.BallService:PrepareGoalkeeperBallAction(active)
		end
	end
	if (kind == "Pass" or kind == "Shot") and self.Possession:GetOwner() ~= active and self.Reception and self.Reception:QueueAction(player, active, payload) then
		return
	end
	if kind == "Move" and validDirection(payload.Direction) then
		local humanoid = active:FindFirstChildOfClass("Humanoid")
		local activeRoot = root(active)
		if humanoid and activeRoot then
			if(tonumber(active:GetAttribute("VTRStunnedUntil"))or 0)>os.clock()then humanoid:Move(Vector3.zero,false);return end
			local userDirection = Vector3.new(payload.Direction.X, 0, payload.Direction.Z)
			local magnitude = math.clamp(userDirection.Magnitude, 0, 1)
			local raw = userDirection
			local assistedMagnitude = 0
			if debugEnabled() and self.Possession:GetOwner()==active and (tonumber(active:GetAttribute("VTRKickoffReturnUntil")) or 0)>os.clock() then
				local last=tonumber(active:GetAttribute("VTRKickoffMoveDebugAt"))or 0
				if os.clock()-last>.25 then
					active:SetAttribute("VTRKickoffMoveDebugAt",os.clock())
					debugKickoff("owner move input","player",player.Name,"owner",active.Name,"magnitude",math.floor(magnitude*100)/100,"direction",raw)
				end
			end
			if self.Reception then raw, assistedMagnitude = self.Reception:HandleMovement(player, active, userDirection, payload.ReceptionContractId, payload.ReceptionRevision, payload.ReceptionClientTime) end
			local ownsBall = self.Possession:GetOwner() == active
			local sprinting = active:GetAttribute("VTRSprinting") == true
			local smoothed, penalty = self.Smoothing:Update(active, raw, ownsBall, sprinting)
			if active:GetAttribute("controlledByUser")==true then
				if not ownsBall and raw.Magnitude <= 0.05 then smoothed = Vector3.zero end
				penalty = 1
			end
			local now = os.clock()
			local dt = math.clamp(now - (self.LastMovementAt[player] or now - 0.05), 1 / 120, 0.12)
			self.LastMovementAt[player] = now
			active:SetAttribute("VTRUserMoveMagnitude", magnitude)
			active:SetAttribute("VTRAssistedMoveMagnitude", assistedMagnitude)
			active:SetAttribute("VTRActualLocomotionMagnitude", math.clamp(raw.Magnitude, 0, 1))
			active:SetAttribute("VTRMoveMagnitude", magnitude)
			if magnitude>.08 then active:SetAttribute("VTRImmediateControlUntil",os.clock()+.22)end
			active:SetAttribute("VTRTurnDot", active:GetAttribute("InputTurnDot") or 1)
			active:SetAttribute("VTRMoveDirection", smoothed.Magnitude > 0.05 and smoothed.Unit or Vector3.zero)
			active:SetAttribute("DribbleTurnPenalty", penalty)
			humanoid:Move(smoothed, false)
			DribbleControlService.Rotate(active, smoothed, ownsBall, sprinting, dt)
			self:_clampGoalkeeperBox(active)
		end
	elseif kind == "Switch" then
		if self.FixedActive[player] then return end
		local requested=typeof(payload.TargetModel)=="Instance"and payload.TargetModel:IsA("Model")and payload.TargetModel or nil;local target:Model?=nil
		if payload.ClosestToBall==true then
			target=self:_closestToBall(player)
		end
		if not target and requested and requested~=active and requested:GetAttribute("VTRTeam")==self.PlayerSides[player]then for _,teammate in self.Teams[self.PlayerSides[player]or"Home"]or{}do if teammate==requested then target=requested;break end end end
		if not target then
			local aimPoint=self:_aimPoint(active,payload.AimPosition,false)
			if aimPoint then target=self:_closestTeammateToPoint(player,active,aimPoint)end
		end
		target=target or self:_nearestUseful(player)
		if target then
			if self.Possession:GetOwner()==active and target~=active then
				active:SetAttribute("VTRNoAutoPassUntil",os.clock()+2.4)
				self.ManualSwitchAwayUntil[player]=os.clock()+2.4
			end
			self:_set(player, target, "Manual")
		end
	elseif kind == "Pass" and validDirection(payload.Direction) then
		local aimPoint = self:_aimPoint(active, payload.AimPosition, false)
		local requestedPass=ActionTuning.NormalizeAction(payload.PassType)
		local internalPass=if requestedPass=="Lob"then"Lofted"else requestedPass
		local evaluatedCharge=ActionTuning.EvaluateNormalized(requestedPass,payload.Charge)
		if payload.ManualAim==true or requestedPass=="Lob"or payload.PassType=="Manual"or payload.PassType=="ManualLobbed"then
			local activeRoot=root(active)
			local offset=activeRoot and aimPoint and(aimPoint-activeRoot.Position)or nil
			if activeRoot and aimPoint and offset and offset.Magnitude>1 then
				local receiver = self:_closestTeammateToPoint(player, active, aimPoint)
				if receiver and self.BallService and self.BallService._primePassReceiver then
					local eta = offset.Magnitude / (internalPass == "Lofted" and 58 or 72)
					self.BallService:_primePassReceiver(active, receiver, aimPoint, eta, eta + 2, internalPass)
				end
				if self.Reception then self.Reception:ConfigureNextPass(active,{Player=player,AssistanceMode="Manual",AutoSwitchMode=payload.AutoSwitch,ManualPass=true})end
				local kicked = self.BallService:Kick(active,"Pass",offset,evaluatedCharge,receiver,internalPass,offset.Magnitude,aimPoint)
				if not kicked and self.Reception then self.Reception:ClearNextPass(active) end
				if kicked then
					self:_emitTelemetry(player,"playability_pass_selection",{passFamily=requestedPass,targetChanged=false})
					self:_queueDefensiveSwitch(tostring(active:GetAttribute("VTRTeam") or self.PlayerSides[player] or "Home"), aimPoint)
				end
			end
			return
		end
		local lockedReceiver = typeof(payload.TargetModel) == "Instance" and payload.TargetModel:IsA("Model") and payload.TargetModel or nil
		local mode = ReceiverAssistConfig.Normalize(payload.AutoSwitch or payload.ReceiverAssistMode)
		local assistMode = ReceiverAssistConfig.Normalize(payload.ReceiverAssistMode or payload.ReceiverAssist)
		if self.Reception then self.Reception:ConfigureNextPass(active,{Player=player,AssistanceMode=assistMode,AutoSwitchMode=mode,ManualPass=false})end
		local receiver, receivePoint = self.Passing:Pass(active, payload.Direction, evaluatedCharge, internalPass, aimPoint, lockedReceiver)
		if not receiver and self.Reception then self.Reception:ClearNextPass(active) end
		self:_emitTelemetry(player,"playability_pass_selection",{passFamily=requestedPass,targetChanged=lockedReceiver~=nil and receiver~=lockedReceiver})
		if receiver and receivePoint then
			self:_queueDefensiveSwitch(tostring(active:GetAttribute("VTRTeam") or self.PlayerSides[player] or "Home"), receivePoint)
		end
	elseif kind == "Shot" and validDirection(payload.Direction) then
		local shotCharge=ActionTuning.EvaluateNormalized("Shot",payload.Charge)
		local overhit=ShotPowerModel.OverhitAmount(shotCharge)
		self:_emitTelemetry(player,"playability_shot_power",{shotPowerBand=powerBand(shotCharge),overhitBand=overhit<=0 and"none"or overhit<.5 and"low"or"high"})
		active:SetAttribute("VTRFreeKickCurve", tonumber(payload.FreeKickCurve) or 0)
		active:SetAttribute("VTRFreeKickLift", tonumber(payload.FreeKickLift) or 0)
		local practiceShotTarget=payload.PracticeShotTarget==true and typeof(payload.AimPosition)=="Vector3"
		local aimPoint = practiceShotTarget and payload.AimPosition or self:_aimPoint(active, payload.AimPosition, payload.GoalTarget == true)
		local activeRoot = root(active)
		local shotDirection=aimPoint and activeRoot and (aimPoint-activeRoot.Position) or payload.Direction
		local animationName=self:_shotAnimationName(active,shotDirection)
		local shotVariant=payload.ShotVariant=="Finesse"and"Finesse"or payload.ShotVariant=="LowDriven"and"LowDriven"or"Normal"
		local shotFoot=animationName=="ShootLeft"and"Left"or"Right"
		if payload.GoalTarget~=true and not practiceShotTarget and not self:_isShotNearGoal(active, aimPoint)then
			local direction = aimPoint and activeRoot and (aimPoint - activeRoot.Position) or payload.Direction
			self.BallService:LowClearance(active,direction,shotCharge)
		else
			self:_releaseShotOnMarker(active,animationName,function()
				local currentRoot=root(active)
				active:SetAttribute("VTRShotVariant",shotVariant)
				active:SetAttribute("VTRShotFoot",shotFoot)
				local released=false
				if practiceShotTarget and aimPoint and currentRoot then
					released=self.BallService:Kick(active,"Shot",aimPoint-currentRoot.Position,shotCharge,nil,nil,nil,aimPoint)
				else
					released=self.BallService:Kick(active,"Shot",aimPoint and currentRoot and(aimPoint-currentRoot.Position)or payload.Direction,shotCharge,nil,nil,nil,payload.GoalTarget==true and aimPoint or nil)
				end
				if not released then
					active:SetAttribute("VTRShotVariant",nil)
					active:SetAttribute("VTRShotFoot",nil)
				end
			end)
		end
	elseif kind=="Clearance"and validDirection(payload.Direction)then
		local side=tostring(active:GetAttribute("VTRTeam")or"Home");local sign=side=="Home"and-1 or 1;self.BallService:Clearance(active,self.PitchCFrame:VectorToWorldSpace(Vector3.new(0,0,sign)))
	elseif kind == "Skill" and validDirection(payload.Direction) then
		self.BallService:Kick(active, "Skill", payload.Direction, 0)
	elseif kind=="DribbleMove"and validDirection(payload.Direction)then
		self.BallService:SkillMove(active,payload.Direction)
	elseif kind == "Tackle" then
		self.BallService:Tackle(active,false,payload.ClientTime)
	elseif kind=="SlideTackle"then
		self.BallService:Tackle(active,true,payload.ClientTime)
	elseif kind=="Block"then
		self.BallService:SetBlock(active,payload.Active==true)
	end
end

function Service:Step(dt: number?)
	if self.Reception then self.Reception:Step(tonumber(dt) or 1 / 30) end
	self:_stepDefensiveSwitches()
	local currentOwner=self.Possession:GetOwner()
	if currentOwner~=self.LastPossessionOwner then
		self.LastPossessionOwner=currentOwner
		if currentOwner then
			-- Possession always transfers control to the actual collector before AI
			-- gets a chance to chain an automatic pass.
			if (tonumber(currentOwner:GetAttribute("VTRKickoffReturnUntil")) or 0) <= os.clock() then
				currentOwner:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.2)
			else
				currentOwner:SetAttribute("VTRNoAutoPassUntil",nil)
			end
			debugKickoff("possession changed", "owner", currentOwner.Name, "team", currentOwner:GetAttribute("VTRTeam"), "aiControlled", currentOwner:GetAttribute("aiControlled"), "controlledByUser", currentOwner:GetAttribute("controlledByUser"), "kickoffReturnUntil", currentOwner:GetAttribute("VTRKickoffReturnUntil"), "noAutoPassUntil", currentOwner:GetAttribute("VTRNoAutoPassUntil"))
			for player,active in self.Active do
				if self.FixedActive[player] then continue end
				local manuallyAway=(self.ManualSwitchAwayUntil[player]or 0)>os.clock()
				if self.PlayerSides[player]==currentOwner:GetAttribute("VTRTeam")and active~=currentOwner and (not manuallyAway or tostring(currentOwner:GetAttribute("position")or"")=="GK") then self:_set(player,currentOwner,tostring(currentOwner:GetAttribute("position")or"")=="GK" and "GoalkeeperClaim" or "PossessionWon")end
			end
		end
	end
end

function Service:Destroy(player: Player)
	local active = self.Active[player]
	if active then
		active:SetAttribute("controlledByUser", false)
		active:SetAttribute("aiControlled", true)
		self.Smoothing:Clear(active)
	end
	self.Active[player] = nil
	self.FixedActive[player] = nil
	self.PendingDefensiveSwitch[player] = nil
	self.DefensiveAutoSwitchMode[player] = nil
	if self.Reception then self.Reception:CancelForPlayer(player, "MatchInterrupted") end
	self.LastMovementAt[player] = nil
	self.ManualSwitchAwayUntil[player] = nil
	self.LastAutomaticSwitch[player] = nil
	self.LastManualSwitchAt[player] = nil
	self.PlayerSides[player] = nil
	if self.Reception and next(self.Active) == nil then
		self.Reception:Destroy()
		if self.BallService.SetPassReceptionService then self.BallService:SetPassReceptionService(nil) end
	end
end

return Service
