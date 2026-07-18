--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ActionTuning = require(ReplicatedStorage.VTR.Shared.ActionTuningConfig)
local ReceiverAssistConfig = require(ReplicatedStorage.VTR.Shared.ReceiverAssistConfig)
local VoltraLiteMobileControls = require(script:FindFirstAncestor("VTRClient").Components.VoltraLiteMobileControls)

local Controller = {}
Controller.__index = Controller

local movementKeys = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
}

local modifierKeys = {
	[Enum.KeyCode.LeftAlt] = true,
	[Enum.KeyCode.RightAlt] = true,
	[Enum.KeyCode.LeftControl] = true,
	[Enum.KeyCode.RightControl] = true,
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.RightShift] = true,
}

local function keyFromSetting(value: any, fallback: Enum.KeyCode): Enum.KeyCode
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		return value
	end
	if type(value) ~= "string" or value == "" then
		return fallback
	end
	local aliases = {Ctrl = Enum.KeyCode.LeftControl, Control = Enum.KeyCode.LeftControl, Alt = Enum.KeyCode.LeftAlt, Shift = Enum.KeyCode.LeftShift}
	if aliases[value] then
		return aliases[value]
	end
	local ok, key = pcall(function()
		return Enum.KeyCode[value]
	end)
	return if ok then key else fallback
end

local function keyDown(keys: {[Enum.KeyCode]: boolean}, left: Enum.KeyCode, right: Enum.KeyCode): boolean
	return keys[left] == true or keys[right] == true
end

local function matchesBindingKey(key: Enum.KeyCode, binding: Enum.KeyCode, left: Enum.KeyCode, right: Enum.KeyCode): boolean
	if binding == left or binding == right then
		return key == left or key == right
	end
	return key == binding
end

function Controller.new(remote: RemoteEvent, aim: (string?, number?) -> any)
	return setmetatable({
		Remote = remote,
		Aim = aim,
		Keys = {},
		Charge = nil,
		PendingAction = nil,
		Connections = {},
		AutoSwitch = "Standard",
		ManualPassAutoSwitch = "Manual",
		ReceiverAssist = "Standard",
		FreeKickCurve = 0,
		FreeKickLift = 0,
		LastFreeKickAt = 0,
		ManualPassKey = Enum.KeyCode.LeftControl,
		LobbedPassKey = Enum.KeyCode.LeftAlt,
		ThroughPassKey = Enum.KeyCode.E,
		ChangePlayerKey = Enum.KeyCode.Q,
		TackleKey = Enum.KeyCode.E,
		SlideTackleKey = Enum.KeyCode.F,
		GamepadMove = Vector2.zero,
		GamepadAim = Vector2.zero,
		Defending = false,
		HasBall = false,
		ReceivingPass = false,
		ReceiveArrivalSeconds = nil,
		SprintRequested = false,
		SprintAllowed = false,
		SprintActual = false,
		SprintToggle = false,
		SprintKeepaliveAt = 0,
		ShootingOnly = false,
		ActionLockedUntil = 0,
		IgnoredActionKeys = {},
		ShotMode = "Normal",
		LastActionSent = {},
		KickSequence = 0,
		ActionContextToken = 0,
		ActionModel = nil,
		ReceptionContractId = nil,
		ReceptionRevision = nil,
	}, Controller)
end

function Controller:_receptionIdentity(): (number?, number?)
	local model = self.ActionModel
	local contractId = tonumber(self.ReceptionContractId) or (model and tonumber(model:GetAttribute("VTRReceptionContractId")))
	local revision = tonumber(self.ReceptionRevision) or (model and tonumber(model:GetAttribute("VTRReceptionRevision")))
	if not contractId or not revision then return nil, nil end
	return math.floor(contractId), math.floor(revision)
end

function Controller:_stampReception(payload: any): boolean
	local contractId, revision = self:_receptionIdentity()
	if not contractId or not revision then return false end
	payload.ReceptionContractId = contractId
	payload.ReceptionRevision = revision
	payload.ReceptionClientTime = workspace:GetServerTimeNow()
	return true
end

function Controller:SetShotModeChanged(callback: any)
	self.ShotModeChanged = callback
	if callback then
		callback(self.ShotMode)
	end
end

function Controller:SetShotMode(mode: string)
	mode = if mode == "Finesse" then "Finesse" elseif mode == "LowDriven" then "LowDriven" else "Normal"
	if self.ShotMode == mode then
		return
	end
	self.ShotMode = mode
	if self.ShotModeChanged then
		self.ShotModeChanged(mode)
	end
end

function Controller:SetAutoSwitch(mode: string?)
	self.AutoSwitch = ReceiverAssistConfig.Normalize(mode)
end

function Controller:SetManualPassAutoSwitch(mode: string?)
	self.ManualPassAutoSwitch = ReceiverAssistConfig.Normalize(mode, "Manual")
end

function Controller:SetReceiverAssist(mode: string?)
	self.ReceiverAssist = ReceiverAssistConfig.Normalize(mode)
end

function Controller:SetControlsSettings(settings: any)
	settings = settings or {}
	self.ManualPassKey = keyFromSetting(settings.ManualPassKey or settings.ManualPassModifier or settings.ManualPass, Enum.KeyCode.LeftControl)
	self.LobbedPassKey = keyFromSetting(settings.LobbedPassKey or settings.LobPassKey or settings.LobbedPass, Enum.KeyCode.LeftAlt)
	self.ThroughPassKey = keyFromSetting(settings.ThroughPassKey, Enum.KeyCode.E)
	self.ChangePlayerKey = keyFromSetting(settings.ChangePlayerKey or settings.SwitchPlayerKey or settings.SwitchKey, Enum.KeyCode.Q)
	self.TackleKey = keyFromSetting(settings.TackleKey, Enum.KeyCode.E)
	self.SlideTackleKey = keyFromSetting(settings.SlideTackleKey or settings.SlideKey, Enum.KeyCode.F)
	self:SetAutoSwitch(settings.PassReceiverAutoSwitch or settings.ReceiverAssistMode)
	self:SetManualPassAutoSwitch(settings.ManualPassAutoSwitch)
	self:SetReceiverAssist(settings.ReceiverAssistMode or settings.ReceiverAssist)
	self.MobileSprintMode = settings.MobileSprintMode == "Hold" and "Hold" or "Toggle"
	self.MobileControlHandedness = settings.MobileControlHandedness == "Left" and "Left" or "Right"
	if self.MobileControls then
		self.MobileControls:SetPreferences(self.MobileSprintMode, self.MobileControlHandedness)
	end
end

function Controller:_cancelPending(reason: string, report: boolean?)
	local pending = self.PendingAction
	if not pending then
		return
	end
	self.PendingAction = nil
	if report ~= false then
		local payload = {Type = "ActionQueueCancelled", Reason = string.sub(reason, 1, 32)}
		if pending.SentForReception == true then
			payload.ReceptionContractId = pending.ContractId
			payload.ReceptionRevision = pending.Revision
			payload.ReceptionClientTime = workspace:GetServerTimeNow()
		end
		self.Remote:FireServer(payload)
	end
end

function Controller:CancelPossessionActions(reason: string, report: boolean?)
	local charge = self.Charge
	local pending = self.PendingAction
	self.Charge = nil
	self.PendingAction = nil
	if self.MobileControls and self.MobileControls.CancelChargedAction then
		self.MobileControls:CancelChargedAction(reason)
	end
	if self.CancellationCallback then
		self.CancellationCallback(reason)
	end
	if report ~= false and (charge or pending) then
		local actionFamily = charge and tostring(charge.Kind or "") or tostring(pending and pending.Payload and pending.Payload.ActionFamily or "")
		local payload = {Type = "ActionQueueCancelled", Reason = string.sub(reason, 1, 32), ActionFamily = actionFamily}
		if pending and pending.SentForReception == true then
			payload.ReceptionContractId = pending.ContractId
			payload.ReceptionRevision = pending.Revision
			payload.ReceptionClientTime = workspace:GetServerTimeNow()
		end
		self.Remote:FireServer(payload)
	end
end

function Controller:ResolveReception(contractId: any, revision: any, cancelled: boolean?)
	local pending = self.PendingAction
	if pending and tonumber(pending.ContractId) == tonumber(contractId) and tonumber(pending.Revision) == tonumber(revision) then self.PendingAction = nil end
	if cancelled == true and self.Charge then self.Charge = nil end
	if tonumber(self.ReceptionContractId) == tonumber(contractId) then
		self.ReceptionContractId = nil
		self.ReceptionRevision = nil
	end
end

function Controller:ClearReceptionQueuedAction(contractId: any, revision: any)
	local pending = self.PendingAction
	if pending and tonumber(pending.ContractId) == tonumber(contractId) and tonumber(pending.Revision) == tonumber(revision) then self.PendingAction = nil end
end

function Controller:SetCancellationCallback(callback: any)
	self.CancellationCallback = callback
end

function Controller:SetActiveModel(model: Model?)
	if self.ActionModel == model then
		return
	end
	self:CancelPossessionActions("active_player_changed")
	self.ActionContextToken += 1
	self.ActionModel = model
end

function Controller:SetMatchContext(pitchCFrame: CFrame?)
	self.PitchCFrame = pitchCFrame
end

function Controller:IsForwardPassSwipe(delta: Vector2): boolean
	if typeof(delta) ~= "Vector2" or delta.Magnitude < 1 then return false end
	local camera = workspace.CurrentCamera
	local model = self.ActionModel
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root or typeof(self.PitchCFrame) ~= "CFrame" then return -delta.Y > math.abs(delta.X) * 0.7 end
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local team = tostring(model:GetAttribute("VTRTeam") or "Home")
	local attackSign = team == "Home" and (half >= 2 and 1 or -1) or (half >= 2 and -1 or 1)
	local attackDirection = self.PitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, attackSign))
	local origin = camera:WorldToViewportPoint(root.Position)
	local destination = camera:WorldToViewportPoint(root.Position + attackDirection * 24)
	local projected = Vector2.new(destination.X - origin.X, destination.Y - origin.Y)
	if projected.Magnitude < 4 then return -delta.Y > math.abs(delta.X) * 0.7 end
	return delta.Unit:Dot(projected.Unit) >= 0.55
end

function Controller:SetSuppressed(suppressed: boolean)
	self.Suppressed = suppressed == true
	if self.Suppressed then
		self:CancelPossessionActions("suppressed")
		self:SetSprintRequested(false)
	else
		for key in movementKeys do
			self.Keys[key] = UserInputService:IsKeyDown(key) or nil
		end
		for key in modifierKeys do
			self.Keys[key] = UserInputService:IsKeyDown(key) or nil
		end
	end
end

function Controller:ResetFreeKickModifiers()
	self.FreeKickCurve = 0
	self.FreeKickLift = 0
	self.LastFreeKickAt = os.clock()
	self.DirectFreeKick = true
end

function Controller:LockActions(duration: number?)
	self.ActionLockedUntil = math.max(self.ActionLockedUntil or 0, os.clock() + math.max(0, duration or 0))
	self:CancelPossessionActions("action_locked")
	self:SetSprintRequested(false)
	table.clear(self.IgnoredActionKeys)
	for _, key in {Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY} do
		if UserInputService:IsKeyDown(key) then
			self.IgnoredActionKeys[key] = true
		end
	end
end

function Controller:SetShootingOnly(active: boolean)
	self.ShootingOnly = active == true
	if self.ShootingOnly then
		self:CancelPossessionActions("shooting_only")
		self:SetSprintRequested(false)
		table.clear(self.Keys)
	end
	if self.MobileControls then
		self.MobileControls:SetShootingOnly(self.ShootingOnly)
	end
end

function Controller:ActionsLocked(): boolean
	return os.clock() < (self.ActionLockedUntil or 0)
end

function Controller:_aim(kind: string, charge: number?): any
	local value = self.Aim(kind, charge)
	if type(value) == "table" then
		return value
	end
	return {Direction = value}
end

function Controller:_chargeStart(kind: string, options: any?, mobileToken: number?): boolean
	if self:ActionsLocked() or self.Suppressed then
		return false
	end
	if self.ShootingOnly and kind ~= "Shot" then
		return false
	end
	if not self.Charge then
		self.Charge = {Kind = kind, Started = os.clock(), Options = options or {}, ContextToken = self.ActionContextToken, Model = self.ActionModel, MobileToken = mobileToken}
		return true
	end
	return false
end

function Controller:_chargeAction(charge: any): string
	if charge.Kind == "Shot" then
		return "Shot"
	end
	return ActionTuning.NormalizeAction(charge.Options and charge.Options.PassMode or "Ground")
end

function Controller:_chargeScalar(charge: any): number
	return ActionTuning.NormalizedCharge(self:_chargeAction(charge), os.clock() - charge.Started)
end

function Controller:_selectedDesktopPass(): (string, boolean)
	local alt = keyDown(self.Keys, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt)
	local control = keyDown(self.Keys, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)
	local through = self.Keys[self.ThroughPassKey] == true
	if alt then
		return "Lob", control
	end
	if through then
		return "Through", false
	end
	return "Ground", control
end

function Controller:_chargeEnd(kind: string, mobileToken: number?)
	local current = self.Charge
	if not current or current.Kind ~= kind or (mobileToken ~= nil and current.MobileToken ~= mobileToken) then
		return
	end
	self.Charge = nil
	if current.ContextToken ~= self.ActionContextToken or current.Model ~= self.ActionModel then
		self.Remote:FireServer({Type = "ActionQueueCancelled", Reason = "context_changed", ActionFamily = kind})
		return
	end
	if self:ActionsLocked() or self.Suppressed then
		return
	end
	local options = current.Options or {}
	local normalized = self:_chargeScalar(current)
	local aim = self:_aim(options.AimKind or kind, normalized)
	if kind == "Shot" then
		if aim.PenaltyDefense == true then
			self:_commitAction({Type = "PenaltyGuess", AimPosition = aim.Position, PenaltySlot = aim.PenaltySlot,PenaltyAttempt=aim.PenaltyAttempt})
			return
		end
		if options.ClearanceIfFar and aim.GoalTarget ~= true then
			self:_commitAction({Type = "Clearance", Direction = aim.Direction, Charge = normalized, ActionFamily = "Clearance"})
			return
		end
		self:_commitAction({Type = "Shot", Direction = aim.Direction, AimPosition = aim.Position, GoalTarget = aim.GoalTarget, Charge = normalized, FreeKickCurve = aim.FreeKickCurve, FreeKickLift = aim.FreeKickLift, CurveAxis = math.clamp(tonumber(aim.FreeKickCurve) or 0, -1, 1), PenaltySlot = aim.PenaltySlot,PenaltyAttempt=aim.PenaltyAttempt, ShotVariant = self.ShotMode, ActionFamily = "Shot"})
		return
	end
	local mobileMode = self:MobilePassMode()
	local passType = ActionTuning.NormalizeAction(mobileMode or options.PassMode or "Ground")
	local manualAim = options.ManualAim == true or passType == "Lob" or self:MobileManualAim("Pass")
	local autoSwitch = if manualAim then self.ManualPassAutoSwitch else self.AutoSwitch
	local receiverAssist = if manualAim then "Manual" else self.ReceiverAssist
	self:_commitAction({Type = "Pass", Direction = aim.Direction, AimPosition = aim.Position, TargetModel = if manualAim then nil else aim.TargetModel, Charge = normalized, PassType = passType, AutoSwitch = autoSwitch, ReceiverAssistMode = receiverAssist, ReceiverAssist = receiverAssist, ManualAim = manualAim, CurveAxis = 0, ActionFamily = passType})
end

function Controller:_commitAction(payload: any)
	if self:ActionsLocked() or self.Suppressed then
		return
	end
	if self.ShootingOnly and payload.Type ~= "Shot" and payload.Type ~= "PenaltyGuess" then
		return
	end
	local actionType = tostring(payload.Type or "")
	local needsPossession = actionType == "Pass" or actionType == "Shot" or actionType == "Clearance"
	if needsPossession then
		local now = os.clock()
		local last = tonumber(self.LastActionSent[actionType]) or 0
		if now - last < 0.08 then
			return
		end
		self.LastActionSent[actionType] = now
		self.KickSequence += 1
		payload.SequenceId = self.KickSequence
		payload.ClientTime = now
		if self.HasBall then
			self.Remote:FireServer(payload)
		elseif self.ReceivingPass and (actionType == "Pass" or actionType == "Shot") and self:_stampReception(payload) then
			local duration = if self.ReceiveArrivalSeconds and self.ReceiveArrivalSeconds <= ActionTuning.QueueImminentArrivalSeconds then ActionTuning.QueueImminentSeconds else ActionTuning.QueueNormalSeconds
			self.PendingAction = {Payload = payload, CreatedAt = now, ExpiresAt = now + duration, ContextToken = self.ActionContextToken, Model = self.ActionModel, SentForReception = true, ContractId = payload.ReceptionContractId, Revision = payload.ReceptionRevision}
			self.Remote:FireServer(payload)
		end
		return
	end
	self.Remote:FireServer(payload)
end

function Controller:_sendDefensiveAction(actionType:string)
	self.Remote:FireServer({Type=actionType,ClientTime=workspace:GetServerTimeNow()})
end

function Controller:SetActionContext(hasBall: boolean, receivingPass: boolean, context: any?)
	local hadBall = self.HasBall
	local wasReceiving = self.ReceivingPass
	local contextModel = type(context) == "table" and context.ActiveModel or nil
	if contextModel and contextModel ~= self.ActionModel then
		self:SetActiveModel(contextModel)
	end
	self.HasBall = hasBall == true
	self.ReceivingPass = receivingPass == true
	if self.MobileControls and self.MobileControls.SetReceivingPass then self.MobileControls:SetReceivingPass(self.ReceivingPass) end
	self.ReceiveArrivalSeconds = type(context) == "table" and math.max(0, tonumber(context.ArrivalSeconds) or math.huge) or nil
	self.ReceptionContractId = type(context) == "table" and tonumber(context.ReceptionContractId) or nil
	self.ReceptionRevision = type(context) == "table" and tonumber(context.ReceptionRevision) or nil
	if self.HasBall and self.PendingAction then
		local pending = self.PendingAction
		self.PendingAction = nil
		if pending.SentForReception ~= true and os.clock() <= (tonumber(pending.ExpiresAt) or 0) and pending.ContextToken == self.ActionContextToken and pending.Model == self.ActionModel then
			self.Remote:FireServer(pending.Payload)
		end
	elseif self.PendingAction and os.clock() > (tonumber(self.PendingAction.ExpiresAt) or 0) then
		self:_cancelPending("expired")
	elseif self.PendingAction and wasReceiving and not self.ReceivingPass and not self.HasBall then
		self:_cancelPending("possession_lost")
	elseif self.PendingAction and hadBall and not self.HasBall and not self.ReceivingPass then
		self:_cancelPending("opponent_collected")
	end
	if self.Charge and ((hadBall and not self.HasBall) or (wasReceiving and not self.ReceivingPass and not self.HasBall)) then
		self:CancelPossessionActions(if hadBall then "possession_lost" else "receive_cancelled")
	end
end

function Controller:IsActionQueued(): boolean
	return self.PendingAction ~= nil and os.clock() <= (tonumber(self.PendingAction.ExpiresAt) or 0)
end

function Controller:_stickVector(input: InputObject): Vector2
	local raw = Vector2.new(input.Position.X, input.Position.Y)
	return if raw.Magnitude > 0.14 then raw else Vector2.zero
end

function Controller:SetSprintAllowed(allowed: boolean)
	self.SprintAllowed = allowed == true
	if not self.SprintAllowed then
		self:SetSprintRequested(false)
	else
		self.SprintActual = self.SprintRequested
	end
	if self.MobileControls then
		self.MobileControls:SetSprintState(self.SprintRequested, self.SprintActual, self.SprintAllowed, false)
	end
end

function Controller:SetSprintActual(actual: boolean, exhausted: boolean?)
	self.SprintActual = actual == true and self.SprintAllowed
	if self.MobileControls then
		self.MobileControls:SetSprintState(self.SprintRequested, self.SprintActual, self.SprintAllowed, exhausted == true)
	end
end

function Controller:SetSprintRequested(active: boolean)
	active = active == true and self.SprintAllowed and not self.ShootingOnly and not self.Suppressed
	if self.SprintRequested == active then
		return
	end
	self.SprintRequested = active
	self.SprintToggle = active
	self.SprintActual = active and self.SprintAllowed
	self.SprintKeepaliveAt = os.clock()
	self.Remote:FireServer({Type = "Sprint", Active = active})
	if self.MobileControls then
		self.MobileControls:SetSprintState(self.SprintRequested, self.SprintActual, self.SprintAllowed, false)
	end
end

function Controller:SetSprint(active: boolean)
	self:SetSprintRequested(active)
end

function Controller:ToggleSprint()
	self:SetSprintRequested(not self.SprintRequested)
end

function Controller:_switchPlayer()
	self:CancelPossessionActions("player_switch")
	local aim = self:_aim("Switch")
	local gamepad = string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
	local closestToBall = UserInputService.TouchEnabled or gamepad
	self.Remote:FireServer({Type = "Switch", TargetModel = if closestToBall then nil else aim.TargetModel, AimPosition = aim.Position, ClosestToBall = closestToBall})
end

function Controller:BeginMobileAction(kind: string, options: any?, token: number?): boolean
	return self:_chargeStart(kind, options, token)
end

function Controller:EndMobileAction(kind: string, token: number?)
	self:_chargeEnd(kind, token)
end

function Controller:CancelMobileAction(kind: string, token: number?, reason: string?)
	if self.Charge and self.Charge.Kind == kind and (token == nil or self.Charge.MobileToken == token) then
		self.Charge = nil
		self.Remote:FireServer({Type = "MobileActionCancelled", ActionFamily = kind, Reason = string.sub(reason or "touch_cancelled", 1, 32)})
	end
end

function Controller:RejectMobileCharge(kind: string)
	self.Remote:FireServer({Type = "MobileChargeConflictRejected", ActionFamily = string.sub(kind, 1, 24)})
end

function Controller:TriggerMobileAction(action: string)
	if action == "Switch" then
		self:_switchPlayer()
	elseif action == "Tackle" then
		self:_sendDefensiveAction("Tackle")
	elseif action == "SlideTackle" then
		self:_sendDefensiveAction("SlideTackle")
	elseif action == "Block" then
		self.Remote:FireServer({Type = "Block", Active = true})
	elseif action == "BlockEnd" then
		self.Remote:FireServer({Type = "Block", Active = false})
	elseif action == "Skill" then
		local aim = self:_aim("Skill")
		self.Remote:FireServer({Type = "DribbleMove", Direction = aim.Direction})
	end
end

function Controller:Start()
	if UserInputService.TouchEnabled then
		self.MobileControls = VoltraLiteMobileControls.new(self)
		self.MobileControls:SetPreferences(self.MobileSprintMode or "Toggle", self.MobileControlHandedness or "Right")
	end
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		local mouseAction = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
		if self.Suppressed or (processed and not mouseAction) or (mouseAction and UserInputService:GetFocusedTextBox() ~= nil) then
			return
		end
		local key = input.KeyCode
		if self.IgnoredActionKeys[key] then
			return
		end
		if movementKeys[key] or modifierKeys[key] or key == self.ManualPassKey or key == self.LobbedPassKey or key == self.ThroughPassKey then
			self.Keys[key] = true
		end
		if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
			self:SetSprintRequested(true)
			return
		end
		if self.ShootingOnly then
			if key == Enum.KeyCode.Z then self:SetShotMode("Normal") elseif key == Enum.KeyCode.X then self:SetShotMode("Finesse") elseif key == Enum.KeyCode.C then self:SetShotMode("LowDriven") elseif key == Enum.KeyCode.ButtonB then self:_chargeStart("Shot", {AimKind = "GamepadShot"}) elseif key == Enum.KeyCode.ButtonR2 then self:SetSprintRequested(true) elseif input.UserInputType == Enum.UserInputType.MouseButton1 then self:_chargeStart("Shot") end
			return
		end
		if key == self.TackleKey and self.Defending then
			self:_sendDefensiveAction("Tackle")
		elseif key == self.SlideTackleKey then
			self:_sendDefensiveAction("SlideTackle")
		elseif not self.Defending and matchesBindingKey(key, self.ManualPassKey, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl) then
			self:_chargeStart("Pass", {PassMode = "Ground", ManualAim = true, TriggerKey = key})
		elseif not self.Defending and matchesBindingKey(key, self.LobbedPassKey, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt) then
			self:_chargeStart("Pass", {PassMode = "Lob", ManualAim = true, TriggerKey = key})
		elseif key == Enum.KeyCode.Z then
			self:SetShotMode("Normal")
		elseif key == Enum.KeyCode.X and not self.Defending then
			self:SetShotMode("Finesse")
		elseif key == Enum.KeyCode.C then
			if self.HasBall then self:SetShotMode("LowDriven") else self:TriggerMobileAction("Skill") end
		elseif key == Enum.KeyCode.R and self.Defending then
			self.Remote:FireServer({Type = "Block", Active = true})
		elseif key == self.ChangePlayerKey then
			self:_switchPlayer()
		elseif key == Enum.KeyCode.ButtonA then
			if self.Defending then self:_sendDefensiveAction("Tackle") else self:_chargeStart("Pass", {PassMode = "Ground"}) end
		elseif key == Enum.KeyCode.ButtonB and not self.Defending then
			self:_chargeStart("Shot", {AimKind = "GamepadShot", ClearanceIfFar = not self.DirectFreeKick})
		elseif key == Enum.KeyCode.ButtonX then
			if self.Defending then self:_sendDefensiveAction("SlideTackle") else self:_chargeStart("Pass", {PassMode = "Lob"}) end
		elseif key == Enum.KeyCode.ButtonY and not self.Defending then
			self:_chargeStart("Pass", {PassMode = "Through"})
		elseif key == Enum.KeyCode.ButtonL1 then
			self:_switchPlayer()
		elseif key == Enum.KeyCode.ButtonL2 then
			self.Keys[key] = true
		elseif key == Enum.KeyCode.ButtonR2 then
			self:SetSprintRequested(true)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_chargeStart("Shot")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			local passMode, manualAim = self:_selectedDesktopPass()
			self:_chargeStart("Pass", {PassMode = passMode, ManualAim = manualAim, TriggerInput = "MouseButton2"})
		end
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
		local key = input.KeyCode
		if self.IgnoredActionKeys[key] then
			self.IgnoredActionKeys[key] = nil
			return
		end
		if movementKeys[key] or modifierKeys[key] or key == self.ManualPassKey or key == self.LobbedPassKey or key == self.ThroughPassKey then
			self.Keys[key] = nil
		end
		if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift or key == Enum.KeyCode.ButtonR2 then
			self:SetSprintRequested(false)
		end
		if self.Suppressed then
			return
		end
		if self.ShootingOnly then
			if self.Charge and self.Charge.Kind == "Shot" and (key == Enum.KeyCode.ButtonB or input.UserInputType == Enum.UserInputType.MouseButton1) then self:_chargeEnd("Shot") end
			return
		end
		local chargeOptions = self.Charge and self.Charge.Options or nil
		if self.Charge and self.Charge.Kind == "Pass" and chargeOptions and chargeOptions.TriggerKey == key then
			self:_chargeEnd("Pass")
		elseif key == Enum.KeyCode.ButtonA and self.Charge and self.Charge.Kind == "Pass" then
			self:_chargeEnd("Pass")
		elseif key == Enum.KeyCode.ButtonB and self.Charge and self.Charge.Kind == "Shot" then
			self:_chargeEnd("Shot")
		elseif (key == Enum.KeyCode.ButtonX or key == Enum.KeyCode.ButtonY) and self.Charge and self.Charge.Kind == "Pass" then
			self:_chargeEnd("Pass")
		elseif key == Enum.KeyCode.ButtonL2 then
			self.Keys[key] = nil
		elseif key == Enum.KeyCode.R then
			self.Remote:FireServer({Type = "Block", Active = false})
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and self.Charge and self.Charge.Kind == "Shot" then
			self:_chargeEnd("Shot")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and self.Charge and self.Charge.Kind == "Pass" and chargeOptions and chargeOptions.TriggerInput == "MouseButton2" then
			self:_chargeEnd("Pass")
		end
	end))
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input, processed)
		if self.Suppressed or (processed and input.KeyCode ~= Enum.KeyCode.Thumbstick1 and input.KeyCode ~= Enum.KeyCode.Thumbstick2) then
			return
		end
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			self.GamepadMove = self:_stickVector(input)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			self.GamepadAim = self:_stickVector(input)
		end
	end))
	table.insert(self.Connections, UserInputService.WindowFocusReleased:Connect(function()
		self:SetSprintRequested(false)
		self:CancelPossessionActions("focus_lost")
	end))
	table.insert(self.Connections, UserInputService.TextBoxFocused:Connect(function()
		self:SetSprintRequested(false)
	end))
	table.insert(self.Connections, RunService.Heartbeat:Connect(function()
		if self.SprintRequested and self.SprintAllowed and os.clock() - self.SprintKeepaliveAt >= 0.75 then
			self.SprintKeepaliveAt = os.clock()
			self.Remote:FireServer({Type = "Sprint", Active = true, Keepalive = true})
		end
		if self.PendingAction and os.clock() > (tonumber(self.PendingAction.ExpiresAt) or 0) then
			self:_cancelPending("expired")
		end
	end))
end

function Controller:Move(): Vector2
	local keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
	if keyboard.Magnitude > 1 then
		keyboard = keyboard.Unit
	end
	if keyboard.Magnitude > 0.05 then
		return keyboard
	end
	if self.GamepadMove.Magnitude > 0.05 then
		return self.GamepadMove
	end
	return if self.MobileControls then self.MobileControls:MoveVector() else Vector2.zero
end

function Controller:MobileAimVector(kind: string?): Vector2?
	if (kind == "Shot" or kind == "GamepadShot" or kind == "Switch") and self.GamepadAim.Magnitude > 0.08 then
		return self.GamepadAim
	end
	local mobile = if self.MobileControls then self.MobileControls:AimVector(kind) else nil
	if mobile and mobile.Magnitude > 0.08 then
		return mobile
	end
	if self.GamepadMove.Magnitude > 0.08 then
		return self.GamepadMove
	end
	return nil
end

function Controller:CurveAimVector(): Vector2
	return if self.GamepadAim.Magnitude > 0.08 then self.GamepadAim else Vector2.zero
end

function Controller:MobileManualAim(kind: string?): boolean
	return self.MobileControls ~= nil and self.MobileControls:IsManualAim(kind)
end

function Controller:MobilePassMode(): string?
	return if self.MobileControls then self.MobileControls:ConsumePassMode() else nil
end

function Controller:SetMobileDefending(defending: boolean)
	local value = defending == true
	if self.Defending ~= value and self.Charge then
		self:CancelPossessionActions("action_context_changed")
	end
	self.Defending = value
	if self.MobileControls then
		self.MobileControls:SetDefending(self.Defending)
	end
end

function Controller:SetDirectFreeKick(active: boolean)
	if active then
		self:ResetFreeKickModifiers()
	else
		self.DirectFreeKick = false
	end
end

function Controller:Sprinting(): boolean
	return self.SprintRequested and self.SprintAllowed and self.SprintActual
end

function Controller:ChargeValue(): number
	return if self.Charge then self:_chargeScalar(self.Charge) else 0
end

function Controller:ChargeKind(): string
	return self.Charge and self.Charge.Kind or (self.PendingAction and tostring(self.PendingAction.Payload and self.PendingAction.Payload.Type or "") or "")
end

function Controller:FreeKickModifiers(): (number, number)
	local curveClamp = math.clamp(tonumber(workspace:GetAttribute("VTRFreeKickCurveClamp")) or 1, 0, 2.5)
	local liftClamp = math.clamp(tonumber(workspace:GetAttribute("VTRFreeKickLiftClamp")) or 1, 0, 2.5)
	local now = os.clock()
	local dt = math.clamp(now - (self.LastFreeKickAt > 0 and self.LastFreeKickAt or now), 0, 0.08)
	self.LastFreeKickAt = now
	local curveRate = tonumber(workspace:GetAttribute("VTRFreeKickCurveRate")) or 0.72
	local liftRate = tonumber(workspace:GetAttribute("VTRFreeKickLiftRate")) or 0.72
	local curveInput = (self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0)
	local liftInput = (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0)
	local joystick = self:CurveAimVector()
	curveInput = math.clamp(curveInput + joystick.X, -1, 1)
	liftInput = math.clamp(liftInput + joystick.Y, -1, 1)
	self.FreeKickCurve = math.clamp((self.FreeKickCurve or 0) + curveInput * curveRate * dt, -curveClamp, curveClamp)
	self.FreeKickLift = math.clamp((self.FreeKickLift or 0) + liftInput * liftRate * dt, -liftClamp, liftClamp)
	return self.FreeKickCurve, self.FreeKickLift
end

function Controller:Destroy()
	self:CancelPossessionActions("destroyed", false)
	self:SetSprintRequested(false)
	if self.MobileControls then
		self.MobileControls:Destroy()
		self.MobileControls = nil
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return Controller
