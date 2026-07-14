--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local GameplayConfig=require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local ActionTuning=require(ReplicatedStorage.VTR.Shared.ActionTuningConfig)
local ReceiverAssistConfig=require(ReplicatedStorage.VTR.Shared.ReceiverAssistConfig)
local PassTargetingService = require(script.Parent.PassTargetingService)
local PassingService = require(script.Parent.PassingService)
local ReceiveBallService = require(script.Parent.ReceiveBallService)
local MovementSmoothingService = require(script.Parent.MovementSmoothingService)
local DribbleControlService = require(script.Parent.DribbleControlService)

local Service = {}
Service.__index = Service

local function root(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function validDirection(value: any): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z and value.Magnitude <= 1.1
end

local function debugEnabled(): boolean
	return workspace:GetAttribute("VTRKickoffDebug") ~= false
end

local function debugKickoff(message: string, ...: any)
	if debugEnabled() then
		print("[VTR KICKOFF][TeamControl] " .. message, ...)
	end
end

function Service.new(remote: RemoteEvent, teams: any, ball: BasePart, possession: any, ballService: any, pitchCFrame: CFrame, width: number, length: number, animations: any?)
	local targeting = PassTargetingService.new(teams, pitchCFrame)
	return setmetatable({
		Remote = remote, Teams = teams, Ball = ball, Possession = possession, BallService = ballService,
		Passing = PassingService.new(ballService, targeting, remote, teams),
		Receiving = ReceiveBallService.new(ball, possession, remote), Smoothing = MovementSmoothingService.new(),
		PitchCFrame = pitchCFrame, Width = width, Length = length, Animations = animations, Active = {}, PlayerSides = {}, PendingReceiver = {}, PassIntent = {}, ReceiverAssist = {}, ManualReceiveOverride = {}, LastMovementAt = {}, LastPossessionOwner = nil, ManualSwitchAwayUntil = {}, PendingShots = {}, FixedActive = {}, LastKickSequence = {},
	}, Service)
end

function Service:_beginReceiverAssist(player: Player, model: Model, point: Vector3, mode: string)
	mode=ReceiverAssistConfig.Normalize(mode)
	if mode == "Manual" then return end
	if self.ManualReceiveOverride[player] == true then return end
	model:SetAttribute("VTRReceiverAssist", mode)
	self.ReceiverAssist[player] = {Model = model, Point = point, Until = os.clock() + ReceiverAssistConfig.Get(mode).GuidanceSeconds}
end

function Service:SetManualReceiveOverride(player: Player, active: boolean)
	self.ManualReceiveOverride[player] = active == true or nil
	local model = self.Active[player]
	if model and model.Parent then
		model:SetAttribute("VTRManualReceiveOverride", active == true)
		if active == true then
			model:SetAttribute("VTRReceiverAssist", nil)
			self.ReceiverAssist[player] = nil
		end
	end
	local intent = self.PassIntent[player]
	if intent and intent.Model and intent.Model.Parent then
		intent.Model:SetAttribute("VTRManualReceiveOverride", active == true)
		if active == true then
			intent.Model:SetAttribute("VTRReceiverAssist", nil)
		end
	end
	local pending = self.PendingReceiver[player]
	if pending and pending.Model and pending.Model.Parent then
		pending.Model:SetAttribute("VTRManualReceiveOverride", active == true)
	end
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
	model:SetAttribute("VTRManualReceiveOverride", self.ManualReceiveOverride[player] == true)
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

function Service:_switchDefenseToPassTarget(attackingSide: string, passTarget: Vector3)
	local defendingSide = attackingSide == "Home" and "Away" or "Home"
	local best: Model? = nil
	local bestDistance = math.huge
	for _, candidate in self.Teams[defendingSide] or {} do
		local candidateRoot = root(candidate)
		local humanoid = candidate:FindFirstChildOfClass("Humanoid")
		if candidateRoot and humanoid and humanoid.Health > 0 and candidate:GetAttribute("VTRSentOff") ~= true then
			local distance = (candidateRoot.Position - passTarget).Magnitude
			if distance < bestDistance then
				best = candidate
				bestDistance = distance
			end
		end
	end
	if not best then return end
	for player, active in self.Active do
		if self.PlayerSides[player] == defendingSide and active ~= best then
			self:_set(player, best, "PassDefense")
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
	if kind == "Move" and validDirection(payload.Direction) then
		local humanoid = active:FindFirstChildOfClass("Humanoid")
		local activeRoot = root(active)
		if humanoid and activeRoot then
			if(tonumber(active:GetAttribute("VTRStunnedUntil"))or 0)>os.clock()then humanoid:Move(Vector3.zero,false);return end
			local raw = Vector3.new(payload.Direction.X, 0, payload.Direction.Z)
			local magnitude = math.clamp(raw.Magnitude, 0, 1)
			if debugEnabled() and self.Possession:GetOwner()==active and (tonumber(active:GetAttribute("VTRKickoffReturnUntil")) or 0)>os.clock() then
				local last=tonumber(active:GetAttribute("VTRKickoffMoveDebugAt"))or 0
				if os.clock()-last>.25 then
					active:SetAttribute("VTRKickoffMoveDebugAt",os.clock())
					debugKickoff("owner move input","player",player.Name,"owner",active.Name,"magnitude",math.floor(magnitude*100)/100,"direction",raw)
				end
			end
			if self.ManualReceiveOverride[player] == true and self.ReceiverAssist[player] then active:SetAttribute("VTRReceiverAssist", nil);self.ReceiverAssist[player] = nil end
			local receiveAssist = self.ReceiverAssist[player]
			if receiveAssist and receiveAssist.Model == active and os.clock() < receiveAssist.Until then
				if magnitude>.55 then
					active:SetAttribute("VTRReceiverAssist", nil)
					self.ReceiverAssist[player] = nil
				else
				active:SetAttribute("VTRMoveMagnitude", math.max(magnitude, 0.85))
				active:SetAttribute("VTRMoveDirection", validDirection(payload.Direction) and Vector3.new(payload.Direction.X, 0, payload.Direction.Z) or Vector3.zero)
				humanoid:MoveTo(Vector3.new(receiveAssist.Point.X, activeRoot.Position.Y, receiveAssist.Point.Z))
				return
				end
			end
			local ownsBall = self.Possession:GetOwner() == active
			local sprinting = active:GetAttribute("VTRSprinting") == true
			local smoothed, penalty = self.Smoothing:Update(active, raw, ownsBall, sprinting)
			if active:GetAttribute("controlledByUser")==true then
				if not ownsBall and magnitude <= 0.05 then smoothed = Vector3.zero end
				penalty = 1
			end
			local now = os.clock()
			local dt = math.clamp(now - (self.LastMovementAt[player] or now - 0.05), 1 / 120, 0.12)
			self.LastMovementAt[player] = now
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
		if payload.ManualAim==true or payload.PassType=="Manual"or payload.PassType=="ManualLobbed"then
			local activeRoot=root(active)
			local offset=activeRoot and aimPoint and(aimPoint-activeRoot.Position)or nil
			if activeRoot and aimPoint and offset and offset.Magnitude>1 then
				local kicked = self.BallService:Kick(active,"Pass",offset,evaluatedCharge,nil,internalPass,offset.Magnitude,aimPoint)
				if kicked then
					self:_switchDefenseToPassTarget(tostring(active:GetAttribute("VTRTeam") or self.PlayerSides[player] or "Home"), aimPoint)
					local switchMode=ReceiverAssistConfig.Normalize(payload.AutoSwitch,"Manual")
					if not self.FixedActive[player] and switchMode ~= "Manual" then
						local receiver = self:_closestTeammateToPoint(player, active, aimPoint)
						local receiverRoot = root(receiver)
						if receiver and receiverRoot and (receiverRoot.Position - aimPoint).Magnitude <= 42 then
							receiver:SetAttribute("VTRReceiverAssistMode","Manual")
							self.Receiving:Expect(player, receiver, receiverRoot.Position)
							self.PassIntent[player] = {Model = receiver, Passer = active, Until = os.clock() + 4.2, AutoSwitch = switchMode}
							self.Remote:FireClient(player, {Type = "SwitchTarget", Model = receiver, ReceivePoint = receiverRoot.Position})
							self.PendingReceiver[player] = {Model = receiver, Started = os.clock(), ReceivePoint = receiverRoot.Position, InitialDistance = math.max((self.Ball.Position - receiverRoot.Position).Magnitude, 1), AssistMode = "Manual", AutoSwitch = switchMode}
						end
					end
				end
			end
			return
		end
		local lockedReceiver = typeof(payload.TargetModel) == "Instance" and payload.TargetModel:IsA("Model") and payload.TargetModel or nil
		local receiver, receivePoint = self.Passing:Pass(active, payload.Direction, evaluatedCharge, internalPass, aimPoint, lockedReceiver)
		if receiver and receivePoint then
			self:_switchDefenseToPassTarget(tostring(active:GetAttribute("VTRTeam") or self.PlayerSides[player] or "Home"), receivePoint)
			if not self.FixedActive[player] then
				local mode = ReceiverAssistConfig.Normalize(payload.AutoSwitch or payload.ReceiverAssistMode)
				local assistMode = ReceiverAssistConfig.Normalize(payload.ReceiverAssistMode or payload.ReceiverAssist)
				receiver:SetAttribute("VTRReceiverAssistMode",assistMode)
				self.Receiving:Expect(player, receiver, receivePoint)
				self.PassIntent[player] = {Model = receiver, Passer = active, Until = os.clock() + 4.2, AutoSwitch = mode}
				self.Remote:FireClient(player, {Type = "SwitchTarget", Model = receiver, ReceivePoint = receivePoint})
				if mode ~= "Manual" then
					self.PendingReceiver[player] = {Model = receiver, Started = os.clock(), ReceivePoint = receivePoint, InitialDistance = math.max((self.Ball.Position - receivePoint).Magnitude, 1), AssistMode = assistMode, AutoSwitch = mode}
				end
			end
		end
	elseif kind == "Shot" and validDirection(payload.Direction) then
		local shotCharge=ActionTuning.EvaluateNormalized("Shot",payload.Charge)
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
		self.BallService:Tackle(active)
	elseif kind=="SlideTackle"then
		self.BallService:Tackle(active,true)
	elseif kind=="Block"then
		self.BallService:SetBlock(active,payload.Active==true)
	end
end

function Service:Step()
	self.Receiving:Step()
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
	for player, intent in self.PassIntent do
		if self.FixedActive[player] then
			self.Receiving:Cancel(player)
			self.PendingReceiver[player] = nil
			self.PassIntent[player] = nil
			continue
		end
		local intended: Model = intent.Model
		local owner = self.Possession:GetOwner()
		if not intended.Parent or os.clock() >= intent.Until then
			self.Receiving:Cancel(player)
			self.PassIntent[player] = nil
		elseif owner ~= nil and owner ~= intent.Passer then
			self.Receiving:Cancel(player)
			self.PendingReceiver[player] = nil
			self.PassIntent[player] = nil
			if owner == intended then
				if intent.AutoSwitch ~= "Manual" then self:_set(player, intended, "PassReceived") end
			else
				intended:SetAttribute("VTRReceiverAssist", nil)
				self.ReceiverAssist[player] = nil
				if owner:GetAttribute("VTRTeam") == self.PlayerSides[player] then
					-- A teammate collected the pass first. Continue with the collector and
					-- explicitly suppress an AI pass-back to the old intended receiver.
					owner:SetAttribute("VTRNoAutoPassUntil", os.clock() + 0.9)
					if intent.AutoSwitch ~= "Manual" then self:_set(player, owner, "AlternateReceiver") end
				else
					local defender = self:_nearestUseful(player)
					if defender then self:_set(player, defender, "PassIntercepted") end
				end
			end
			intended:SetAttribute("VTRReceiverAssistMode",nil)
		end
	end
	for player, entry in self.PendingReceiver do
		if self.FixedActive[player] then self.PendingReceiver[player] = nil continue end
		local receiver: Model = entry.Model
		if not receiver.Parent then self.PendingReceiver[player] = nil continue end
		local owner = self.Possession:GetOwner()
		if owner and owner:GetAttribute("VTRTeam") ~= self.PlayerSides[player] then
			self.PendingReceiver[player] = nil
			local defender = self:_nearestUseful(player)
			if defender then self:_set(player, defender, "PassIntercepted") end
			continue
		end
		local remaining = (self.Ball.Position - entry.ReceivePoint).Magnitude
		local progress = 1 - math.clamp(remaining / entry.InitialDistance, 0, 1)
		local elapsed = os.clock() - entry.Started
		local mode=ReceiverAssistConfig.Normalize(entry.AutoSwitch)
		if mode=="Manual"then self.PendingReceiver[player]=nil continue end
		local tuning=ReceiverAssistConfig.Get(mode)
		local progressThreshold=tuning.SwitchProgress
		local elapsedThreshold=tuning.SwitchElapsed
		if owner == receiver or elapsed >= elapsedThreshold or progress >= progressThreshold then
			self.PendingReceiver[player] = nil
			self:_set(player, receiver, "PassReceiver")
			self:_beginReceiverAssist(player, receiver, entry.ReceivePoint, entry.AssistMode or "Light")
		end
	end
	for player, assist in self.ReceiverAssist do
		local model: Model = assist.Model
		if self.ManualReceiveOverride[player] == true or self.Active[player] ~= model or not model.Parent or os.clock() >= assist.Until then
			if model.Parent then model:SetAttribute("VTRReceiverAssist", nil) end
			self.ReceiverAssist[player] = nil
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local modelRoot = root(model)
		if humanoid and modelRoot then humanoid:MoveTo(Vector3.new(assist.Point.X, modelRoot.Position.Y, assist.Point.Z)) end
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
	self.PendingReceiver[player] = nil
	self.PassIntent[player] = nil
	self.ReceiverAssist[player] = nil
	self.ManualReceiveOverride[player] = nil
	self.LastMovementAt[player] = nil
	self.ManualSwitchAwayUntil[player] = nil
	self.PlayerSides[player] = nil
end

return Service
