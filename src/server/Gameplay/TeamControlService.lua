--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local GameplayConfig=require(ReplicatedStorage.VTR.Shared.GameplayConfig)
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

local function autoSwitchMode(value: any): string
	return value == "Off" and "Off" or value == "Instant" and "Instant" or "Assisted"
end

local function receiverAssistMode(value: any): string
	return value == "Off" and "Off" or value == "Assisted" and "Assisted" or "Light"
end

local function debugEnabled(): boolean
	return workspace:GetAttribute("VTRKickoffDebug") ~= false
end

local function debugKickoff(message: string, ...: any)
	if debugEnabled() then
		print("[VTR KICKOFF][TeamControl] " .. message, ...)
	end
end

function Service.new(remote: RemoteEvent, teams: any, ball: BasePart, possession: any, ballService: any, pitchCFrame: CFrame, width: number, length: number)
	local targeting = PassTargetingService.new(teams, pitchCFrame)
	return setmetatable({
		Remote = remote, Teams = teams, Ball = ball, Possession = possession, BallService = ballService,
		Passing = PassingService.new(ballService, targeting, remote, teams),
		Receiving = ReceiveBallService.new(ball, possession, remote), Smoothing = MovementSmoothingService.new(),
		PitchCFrame = pitchCFrame, Width = width, Length = length, Active = {}, PlayerSides = {}, PendingReceiver = {}, PassIntent = {}, ReceiverAssist = {}, LastMovementAt = {}, LastPossessionOwner = nil, ManualSwitchAwayUntil = {},
	}, Service)
end

function Service:_beginReceiverAssist(player: Player, model: Model, point: Vector3, mode: string)
	if mode == "Off" then return end
	model:SetAttribute("VTRReceiverAssist", mode)
	self.ReceiverAssist[player] = {Model = model, Point = point, Until = os.clock() + (mode == "Assisted" and 0.9 or 0.48)}
end

function Service:GetActive(player: Player): Model?
	return self.Active[player]
end

function Service:_set(player: Player, model: Model, reason: string)
	local previous = self.Active[player]
	if previous == model then return end
	if previous then
		previous:SetAttribute("controlledByUser", false)
		previous:SetAttribute("aiControlled", true)
		previous:SetAttribute("VTRUserId", nil)
		previous:SetAttribute("VTRCloseControl", false)
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
	if self.Possession:GetOwner() == model then self.Ball:SetAttribute("OwnerUserId", player.UserId) end
	self.Remote:FireClient(player, {Type = "ActivePlayer", Model = model, Name = model:GetAttribute("DisplayName"), Position = model:GetAttribute("position"), Reason = reason})
end

function Service:Register(player: Player, side: string?): Model
	side=side=="Away"and"Away"or"Home";self.PlayerSides[player]=side
	local team=self.Teams[side]
	local initial = team[10] or team[1]
	self:_set(player, initial, "Kickoff")
	return initial
end

function Service:SetActive(player: Player, model: Model, reason: string)
	self:_set(player, model, reason)
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

function Service:_aimPoint(active: Model, value: any, goalTarget: boolean?): Vector3?
	if typeof(value) ~= "Vector3" or value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z then return nil end
	local localPoint = self.PitchCFrame:PointToObjectSpace(value)
	if goalTarget then
		local rectangle = GoalModelResolver.Resolve(active, self.PitchCFrame, self.Width, self.Length)
		local clamped=GoalModelResolver.ClampPoint(rectangle,value);local offset=clamped-rectangle.PlanePoint;local x=math.clamp(offset:Dot(rectangle.Right),rectangle.Left,rectangle.RightBound);local safeBottom=math.min(rectangle.Top,rectangle.Bottom+GameplayConfig.Ball.Radius*.95);local safeTop=math.max(safeBottom,rectangle.Top-math.min(.8,(rectangle.Top-rectangle.Bottom)*.08));local y=math.clamp(offset:Dot(rectangle.Up),safeBottom,safeTop);return GoalModelResolver.Point(rectangle,x,y)
	else
		localPoint = Vector3.new(math.clamp(localPoint.X, -self.Width / 2, self.Width / 2), 0.15, math.clamp(localPoint.Z, -self.Length / 2, self.Length / 2))
	end
	return self.PitchCFrame:PointToWorldSpace(localPoint)
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
			if magnitude > 0.08 and self.ReceiverAssist[player] then active:SetAttribute("VTRReceiverAssist", nil);self.ReceiverAssist[player] = nil end
			local ownsBall = self.Possession:GetOwner() == active
			local sprinting = active:GetAttribute("VTRSprinting") == true
			local smoothed, penalty = self.Smoothing:Update(active, raw, ownsBall, sprinting)
			if active:GetAttribute("controlledByUser")==true then
				smoothed = magnitude > 0.05 and raw.Unit * magnitude or Vector3.zero
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
		end
	elseif kind == "Switch" then
		local requested=typeof(payload.TargetModel)=="Instance"and payload.TargetModel:IsA("Model")and payload.TargetModel or nil;local target:Model?=nil
		if requested and requested~=active and requested:GetAttribute("VTRTeam")==self.PlayerSides[player]then for _,teammate in self.Teams[self.PlayerSides[player]or"Home"]or{}do if teammate==requested then target=requested;break end end end
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
		if payload.PassType=="Manual"or payload.PassType=="ManualLobbed"then
			local activeRoot=root(active)
			local offset=activeRoot and aimPoint and(aimPoint-activeRoot.Position)or nil
			if activeRoot and aimPoint and offset and offset.Magnitude>1 then
				local target = self:_closestTeammateToPoint(player, active, aimPoint)
				local kicked = self.BallService:Kick(active,"Pass",offset,tonumber(payload.Charge)or 0,target,payload.PassType=="ManualLobbed"and"Lofted"or"Manual",offset.Magnitude,aimPoint)
				if kicked and target then
					self.Receiving:Expect(player, target, aimPoint)
					self.PassIntent[player] = {Model = target, Passer = active, Until = os.clock() + 4.2, AutoSwitch = "Instant"}
					self.Remote:FireClient(player, {Type = "SwitchTarget", Model = target, ReceivePoint = aimPoint})
					self:_set(player, target, "ManualPassTarget")
					self:_beginReceiverAssist(player, target, aimPoint, "Light")
				end
			end
			return
		end
		local lockedReceiver = typeof(payload.TargetModel) == "Instance" and payload.TargetModel:IsA("Model") and payload.TargetModel or nil
		local receiver, receivePoint = self.Passing:Pass(active, payload.Direction, tonumber(payload.Charge) or 0, payload.PassType, aimPoint, lockedReceiver)
		if receiver and receivePoint then
			local mode = autoSwitchMode(payload.AutoSwitch)
			local assistMode = receiverAssistMode(payload.ReceiverAssist)
			self.Receiving:Expect(player, receiver, receivePoint)
			self.PassIntent[player] = {Model = receiver, Passer = active, Until = os.clock() + 4.2, AutoSwitch = mode}
			self.Remote:FireClient(player, {Type = "SwitchTarget", Model = receiver, ReceivePoint = receivePoint})
			if mode == "Instant" then
				self:_set(player, receiver, "PassReceiver")
				self:_beginReceiverAssist(player, receiver, receivePoint, assistMode)
			elseif mode == "Assisted" then
				self.PendingReceiver[player] = {Model = receiver, Started = os.clock(), ReceivePoint = receivePoint, InitialDistance = math.max((self.Ball.Position - receivePoint).Magnitude, 1), AssistMode = assistMode}
			end
		end
	elseif kind == "Shot" and validDirection(payload.Direction) then
		local aimPoint = self:_aimPoint(active, payload.AimPosition, payload.GoalTarget == true)
		local activeRoot = root(active)
		if payload.GoalTarget~=true and not self:_isShotNearGoal(active, aimPoint)then
			local direction = aimPoint and activeRoot and (aimPoint - activeRoot.Position) or payload.Direction
			self.BallService:LowClearance(active,direction,payload.Charge)
		else
			self.BallService:Kick(active, "Shot", aimPoint and activeRoot and (aimPoint - activeRoot.Position) or payload.Direction, payload.Charge,nil,nil,nil,payload.GoalTarget==true and aimPoint or nil)
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
				local manuallyAway=(self.ManualSwitchAwayUntil[player]or 0)>os.clock()
				if self.PlayerSides[player]==currentOwner:GetAttribute("VTRTeam")and active~=currentOwner and not manuallyAway then self:_set(player,currentOwner,"PossessionWon")end
			end
		end
	end
	for player, intent in self.PassIntent do
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
				if intent.AutoSwitch ~= "Off" then self:_set(player, intended, "PassReceived") end
			else
				intended:SetAttribute("VTRReceiverAssist", nil)
				self.ReceiverAssist[player] = nil
				if owner:GetAttribute("VTRTeam") == self.PlayerSides[player] then
					-- A teammate collected the pass first. Continue with the collector and
					-- explicitly suppress an AI pass-back to the old intended receiver.
					owner:SetAttribute("VTRNoAutoPassUntil", os.clock() + 0.9)
					if intent.AutoSwitch ~= "Off" then self:_set(player, owner, "AlternateReceiver") end
				else
					local defender = self:_nearestUseful(player)
					if defender then self:_set(player, defender, "PassIntercepted") end
				end
			end
		end
	end
	for player, entry in self.PendingReceiver do
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
		if owner == receiver or elapsed >= 0.18 or progress >= 0.25 then
			self.PendingReceiver[player] = nil
			self:_set(player, receiver, "PassReceiver")
			self:_beginReceiverAssist(player, receiver, entry.ReceivePoint, entry.AssistMode or "Light")
		end
	end
	for player, assist in self.ReceiverAssist do
		local model: Model = assist.Model
		if self.Active[player] ~= model or not model.Parent or os.clock() >= assist.Until then
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
	self.PendingReceiver[player] = nil
	self.PassIntent[player] = nil
	self.ReceiverAssist[player] = nil
	self.LastMovementAt[player] = nil
	self.ManualSwitchAwayUntil[player] = nil
	self.PlayerSides[player] = nil
end

return Service
