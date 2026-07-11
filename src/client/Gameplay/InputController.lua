--!strict
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local VoltraLiteMobileControls = require(script:FindFirstAncestor("VTRClient").Components.VoltraLiteMobileControls)
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)

local Controller = {}
Controller.__index = Controller

local function keyFromSetting(value:any,fallback:Enum.KeyCode):Enum.KeyCode
	if typeof(value)=="EnumItem" and value.EnumType==Enum.KeyCode then return value end
	if type(value)~="string"or value==""then return fallback end
	local map={Ctrl=Enum.KeyCode.LeftControl,Control=Enum.KeyCode.LeftControl,Alt=Enum.KeyCode.LeftAlt,Shift=Enum.KeyCode.LeftShift,MouseRight=Enum.KeyCode.Unknown}
	local mapped=map[value]
	if mapped then return mapped end
	local ok,key=pcall(function()return Enum.KeyCode[value]end)
	return ok and key or fallback
end

local function down(keys:{[Enum.KeyCode]:boolean},key:Enum.KeyCode):boolean
	return key~=Enum.KeyCode.Unknown and keys[key]==true
end

function Controller.new(remote: RemoteEvent, aim: (string?,number?) -> any)
	return setmetatable({Remote = remote, Aim = aim, Keys = {}, Charge = nil, PendingAction = nil, Connections = {}, AutoSwitch = "Assisted", ReceiverAssist = "Light", FreeKickCurve = 0, FreeKickLift = 0, LastFreeKickAt = 0, ManualPassKey = Enum.KeyCode.LeftControl, LobbedPassKey = Enum.KeyCode.LeftAlt, ChangePlayerKey = Enum.KeyCode.Q, TackleKey = Enum.KeyCode.E, SlideTackleKey = Enum.KeyCode.F, GamepadMove = Vector2.zero, GamepadAim = Vector2.zero, Defending = false, HasBall = false, ReceivingPass = false, SprintToggle = false, ShootingOnly = false, ActionLockedUntil = 0, IgnoredActionKeys = {}, ShotMode = "Normal", LastActionSent = {}}, Controller)
end

function Controller:SetShotModeChanged(callback:any)
	self.ShotModeChanged=callback
	if callback then callback(self.ShotMode)end
end

function Controller:SetShotMode(mode:string)
	mode=mode=="Finesse"and"Finesse"or mode=="LowDriven"and"LowDriven"or"Normal"
	if self.ShotMode==mode then return end
	self.ShotMode=mode
	if self.ShotModeChanged then self.ShotModeChanged(mode)end
end

function Controller:SetAutoSwitch(mode: string?)
	self.AutoSwitch = mode == "Off" and "Off" or mode == "Instant" and "Instant" or "Assisted"
end

function Controller:SetManualPassAutoSwitch(mode: string?)
	self.ManualPassAutoSwitch = mode == "Off" and "Off" or "Closest"
end

function Controller:SetReceiverAssist(mode: string?)
	self.ReceiverAssist = mode == "Off" and "Off" or mode == "Assisted" and "Assisted" or "Light"
end

function Controller:SetControlsSettings(settings:any)
	settings=settings or{}
	self.ManualPassKey=keyFromSetting(settings.ManualPassKey or settings.ManualPassModifier or settings.ManualPass,Enum.KeyCode.LeftControl)
	self.LobbedPassKey=keyFromSetting(settings.LobbedPassKey or settings.LobPassKey or settings.LobbedPass,Enum.KeyCode.LeftAlt)
	self.ChangePlayerKey=keyFromSetting(settings.ChangePlayerKey or settings.SwitchPlayerKey or settings.SwitchKey,Enum.KeyCode.Q)
	self.TackleKey=keyFromSetting(settings.TackleKey,Enum.KeyCode.E)
	self.SlideTackleKey=keyFromSetting(settings.SlideTackleKey or settings.SlideKey,Enum.KeyCode.F)
	self:SetManualPassAutoSwitch(settings.ManualPassAutoSwitch or "Closest")
end

function Controller:SetSuppressed(suppressed:boolean)
	self.Suppressed=suppressed
	if suppressed then
		self.Charge=nil
	else
		for _,key in {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl} do
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
	self.Charge = nil
	self.PendingAction = nil
	table.clear(self.IgnoredActionKeys)
	for _, key in {Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY} do
		if UserInputService:IsKeyDown(key) then
			self.IgnoredActionKeys[key] = true
		end
	end
end

function Controller:SetShootingOnly(active:boolean)
	self.ShootingOnly = active == true
	if self.ShootingOnly then
		if self.Charge and self.Charge.Kind ~= "Shot" then self.Charge = nil end
		self.PendingAction = nil
		self.SprintToggle = false
		table.clear(self.Keys)
		if self.MobileControls and self.MobileControls.SetShootingOnly then
			self.MobileControls:SetShootingOnly(true)
		end
	elseif self.MobileControls and self.MobileControls.SetShootingOnly then
		self.MobileControls:SetShootingOnly(false)
	end
end

function Controller:ActionsLocked(): boolean
	return os.clock() < (self.ActionLockedUntil or 0)
end

function Controller:_aim(kind: string,charge:number?): any
	local value = self.Aim(kind,charge)
	if type(value) == "table" then
		return value
	end
	return {Direction = value}
end

function Controller:_chargeStart(kind: string, options: any?)
	if self:ActionsLocked() then return end
	if self.ShootingOnly and kind ~= "Shot" then return end
	if not self.Charge then
		self.Charge = {Kind = kind, Started = os.clock(), Options = options or {}}
	end
end

function Controller:_passKeyMode(key: Enum.KeyCode): string?
	if key == self.ManualPassKey or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then
		return "Manual"
	end

	if key == self.LobbedPassKey or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt then
		return "ManualLobbed"
	end

	return nil
end

function Controller:_chargeEnd(kind: string)
	if self:ActionsLocked() then self.Charge = nil;return end
	local current = self.Charge
	if not current or current.Kind ~= kind then
		return
	end
	local charge = math.clamp((os.clock() - current.Started) / (Config.Ball.MaxChargeTime / 3), 0, 1)
	self.Charge = nil
	local options = current.Options or {}
	local aimKind = options.AimKind or kind
	local aim = self:_aim(aimKind,charge)
	if kind == "Shot" then
		if aim.PenaltyDefense == true then
			self:_commitAction({Type = "PenaltyGuess", AimPosition = aim.Position, PenaltySlot = aim.PenaltySlot})
			return
		end
		if options.ClearanceIfFar and aim.GoalTarget ~= true then
			self:_commitAction({Type = "Clearance", Direction = aim.Direction, Charge = charge})
			return
		end
		self:_commitAction({Type = "Shot", Direction = aim.Direction, AimPosition = aim.Position, GoalTarget = aim.GoalTarget, Charge = charge, FreeKickCurve = aim.FreeKickCurve, FreeKickLift = aim.FreeKickLift, PenaltySlot = aim.PenaltySlot, ShotVariant = self.ShotMode})
	else
		local altDown = down(self.Keys,self.LobbedPassKey) or self.Keys[Enum.KeyCode.RightAlt] == true
		local ctrlDown = down(self.Keys,self.ManualPassKey) or self.Keys[Enum.KeyCode.RightControl] == true
		local manualLobbed = altDown
		local manual = ctrlDown and not manualLobbed
		local lofted = false
		local through=not manualLobbed and not manual and not lofted and self.Keys[Enum.KeyCode.W] == true and charge >= 0.18
		local mobileMode = self:MobilePassMode()
		local forcedMode = options.PassMode
		if forcedMode == "Manual" and self.Keys[Enum.KeyCode.ButtonR1] == true then
			forcedMode = "ManualLobbed"
		end
		local passType=forcedMode or mobileMode or manualLobbed and"ManualLobbed"or manual and"Manual"or lofted and"Lofted"or through and"Through"or"Ground"
		local isMobile = self.MobileControls ~= nil
		local isManual = passType == "Manual" or passType == "ManualLobbed" or manual or manualLobbed or self:MobileManualAim("Pass")
		local autoSwitch = isMobile and "Instant" or (isManual and (self.ManualPassAutoSwitch or "Off") or self.AutoSwitch)
		local receiverAssist = isMobile and "Assisted" or (isManual and "Off" or self.ReceiverAssist)
		self:_commitAction({Type = "Pass", Direction = aim.Direction, AimPosition = aim.Position, TargetModel = isManual and nil or aim.TargetModel, Charge = charge, PassType = passType, AutoSwitch = autoSwitch, ReceiverAssist = receiverAssist})
	end
end

function Controller:_commitAction(payload: any)
	if self:ActionsLocked() then return end
	if self.ShootingOnly and payload.Type ~= "Shot" and payload.Type ~= "PenaltyGuess" then return end
	local actionType = tostring(payload.Type or "")
	if actionType == "Pass" or actionType == "Shot" or actionType == "Clearance" then
		local now = os.clock()
		local last = tonumber(self.LastActionSent[actionType]) or 0
		if now - last < 0.08 then
			return
		end
		self.LastActionSent[actionType] = now
	end
	if self.HasBall then
		self.Remote:FireServer(payload)
	elseif self.ReceivingPass then
		self.PendingAction = {Payload = payload, CreatedAt = os.clock()}
	end
end

function Controller:SetActionContext(hasBall: boolean, receivingPass: boolean)
	self.HasBall = hasBall == true
	self.ReceivingPass = receivingPass == true
	if self.HasBall and self.PendingAction then
		local pending = self.PendingAction
		self.PendingAction = nil
		self.Remote:FireServer(pending.Payload)
	elseif not self.ReceivingPass and self.PendingAction then
		self.PendingAction = nil
	elseif self.PendingAction and os.clock() - (self.PendingAction.CreatedAt or 0) > 4.5 then
		self.PendingAction = nil
	end
end

function Controller:_stickVector(input: InputObject): Vector2
	local raw = Vector2.new(input.Position.X, input.Position.Y)
	return raw.Magnitude > 0.14 and raw or Vector2.zero
end

function Controller:ToggleSprint()
	self.SprintToggle = not self.SprintToggle
	self.Remote:FireServer({Type = "Sprint", Active = self.SprintToggle})
end

function Controller:_switchPlayer()
	local aim=self:_aim("Switch")
	local gamepad=UserInputService:GetLastInputType().Name:find("Gamepad")~=nil
	local closestToBall=UserInputService.TouchEnabled or gamepad
	self.Remote:FireServer({Type = "Switch",TargetModel=closestToBall and nil or aim.TargetModel,AimPosition=aim.Position,ClosestToBall=closestToBall})
end


function Controller:Start()
	if UserInputService.TouchEnabled then
		self.MobileControls = VoltraLiteMobileControls.new(self)
	end
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		local isMouseAction = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
		if self.Suppressed or (processed and not isMouseAction) then
			return
		end
		if isMouseAction and UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if self.IgnoredActionKeys[key] then
			return
		end
		if self.ShootingOnly then
			if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D then
				self.Keys[key] = true
			elseif key==Enum.KeyCode.Z then
				self:SetShotMode("Normal")
			elseif key==Enum.KeyCode.X then
				self:SetShotMode("Finesse")
			elseif key==Enum.KeyCode.C then
				self:SetShotMode("LowDriven")
			elseif key == Enum.KeyCode.ButtonB then
				self:_chargeStart("Shot", {AimKind = "GamepadShot"})
			elseif key == Enum.KeyCode.ButtonR2 then
				self:ToggleSprint()
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:_chargeStart("Shot")
			end
			return
		end
		if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D
			or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift
			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl
			or key == self.ManualPassKey or key == self.LobbedPassKey then
			self.Keys[key] = true
			local passMode = self:_passKeyMode(key)
			if passMode and not self.Defending then
				self:_chargeStart("Pass", {PassMode = passMode, StartedByKey = key})
			end
		elseif key == self.TackleKey then
			self.Remote:FireServer({Type = "Tackle"})
		elseif key==self.SlideTackleKey then
			self.Remote:FireServer({Type="SlideTackle"})
		elseif key==Enum.KeyCode.Z then
			self:SetShotMode("Normal")
		elseif key==Enum.KeyCode.X then
			self:SetShotMode("Finesse")
		elseif key==Enum.KeyCode.C then
			if self.HasBall then self:SetShotMode("LowDriven")else local aim=self:_aim("Skill");self.Remote:FireServer({Type="DribbleMove",Direction=aim.Direction})end
		elseif key==Enum.KeyCode.R then
			self.Remote:FireServer({Type="Block",Active=true})
		elseif key == self.ChangePlayerKey then
			self:_switchPlayer()
		elseif key == Enum.KeyCode.ButtonA then
			if self.Defending then self.Remote:FireServer({Type = "Tackle"}) else self:_chargeStart("Pass") end
		elseif key == Enum.KeyCode.ButtonB then
			if not self.Defending then
				if self.DirectFreeKick then
					self:_chargeStart("Shot")
				else
					self:_chargeStart("Shot", {AimKind = "GamepadShot", ClearanceIfFar = true})
				end
			end
		elseif key == Enum.KeyCode.ButtonX then
			if self.Defending then self.Remote:FireServer({Type = "SlideTackle"}) else self:_chargeStart("Pass", {PassMode = "Lofted"}) end
		elseif key == Enum.KeyCode.ButtonY then
			if not self.Defending then self:_chargeStart("Pass", {PassMode = "Manual"}) end
		elseif key == Enum.KeyCode.ButtonL1 then
			self:_switchPlayer()
		elseif key == Enum.KeyCode.ButtonL2 then
			self.Keys[key] = true
			self.Remote:FireServer({Type = "ReceiverAssistOverride", Active = true})
		elseif key == Enum.KeyCode.ButtonR1 then
			self.Keys[key] = true
		elseif key == Enum.KeyCode.ButtonR2 then
			self:ToggleSprint()
		elseif key == Enum.KeyCode.L then
			self.Remote:FireServer({Type = "DebugFreeKick"})
		elseif key == Enum.KeyCode.K then
			self.Remote:FireServer({Type = "DebugPenaltyAttack"})
		elseif key == Enum.KeyCode.O then
			self.Remote:FireServer({Type = "DebugPenaltyDefense"})
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_chargeStart("Shot")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_chargeStart("Pass")
		end
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
		if self.Suppressed then return end
		local isMouseAction = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
		if isMouseAction and UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if self.IgnoredActionKeys[key] then
			self.IgnoredActionKeys[key] = nil
			return
		end
		if self.ShootingOnly then
			if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D then
				self.Keys[key] = nil
			elseif key == Enum.KeyCode.ButtonB then
				self:_chargeEnd("Shot")
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:_chargeEnd("Shot")
			end
			return
		end
		if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D
			or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift
			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl
			or key == self.ManualPassKey or key == self.LobbedPassKey then
			local current = self.Charge
			local startedByKey = current and current.Kind == "Pass" and current.Options and current.Options.StartedByKey == key
			if startedByKey then
				self:_chargeEnd("Pass")
			end
			self.Keys[key] = nil
		elseif key == Enum.KeyCode.ButtonA then
			if not self.Defending then self:_chargeEnd("Pass") end
		elseif key == Enum.KeyCode.ButtonB then
			if not self.Defending then self:_chargeEnd("Shot") end
		elseif key == Enum.KeyCode.ButtonX then
			if not self.Defending then self:_chargeEnd("Pass") end
		elseif key == Enum.KeyCode.ButtonY then
			if not self.Defending then self:_chargeEnd("Pass") end
		elseif key == Enum.KeyCode.ButtonL2 then
			self.Keys[key] = nil
			self.Remote:FireServer({Type = "ReceiverAssistOverride", Active = false})
		elseif key == Enum.KeyCode.ButtonR1 then
			self.Keys[key] = nil
		elseif key==Enum.KeyCode.R then
			self.Remote:FireServer({Type="Block",Active=false})
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_chargeEnd("Shot")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_chargeEnd("Pass")
		end
	end))
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input, processed)
		if self.Suppressed then return end
		if processed and input.KeyCode ~= Enum.KeyCode.Thumbstick1 and input.KeyCode ~= Enum.KeyCode.Thumbstick2 then return end
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			self.GamepadMove = self:_stickVector(input)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			self.GamepadAim = self:_stickVector(input)
		end
	end))
end

function Controller:Move(): Vector2
	local keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
	if keyboard.Magnitude > 1 then
		keyboard = keyboard.Unit
	end
	local mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
	if keyboard.Magnitude > 0.05 then
		return keyboard
	end
	if self.GamepadMove.Magnitude > 0.05 then
		return self.GamepadMove
	end
	return mobile
end


function Controller:MobileAimVector(kind: string?): Vector2?
	if (kind == "Shot" or kind == "GamepadShot" or kind == "Switch") and self.GamepadAim.Magnitude > 0.08 then
		return self.GamepadAim
	end
	local mobile = self.MobileControls and self.MobileControls:AimVector(kind) or nil
	if mobile and mobile.Magnitude > 0.08 then
		return mobile
	end
	if self.GamepadMove.Magnitude > 0.08 then
		return self.GamepadMove
	end
	return nil
end

function Controller:CurveAimVector(): Vector2
	if self.GamepadAim.Magnitude > 0.08 then
		return self.GamepadAim
	end
	return Vector2.zero
end

function Controller:MobileManualAim(kind: string?): boolean
	return self.MobileControls and self.MobileControls:IsManualAim(kind) or false
end

function Controller:MobilePassMode(): string?
	return self.MobileControls and self.MobileControls:ConsumePassMode() or nil
end

function Controller:SetMobileDefending(defending: boolean)
	self.Defending = defending == true
	if self.MobileControls and self.MobileControls.SetDefending then
		self.MobileControls:SetDefending(defending)
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
	return true
end

function Controller:ChargeValue(): number
	return self.Charge and math.clamp((os.clock() - self.Charge.Started) / (Config.Ball.MaxChargeTime / 3), 0, 1) or 0
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
	if self.SprintToggle then
		self.Remote:FireServer({Type = "Sprint", Active = false})
		self.SprintToggle = false
	end
	if self.Keys[Enum.KeyCode.ButtonL2] then
		self.Remote:FireServer({Type = "ReceiverAssistOverride", Active = false})
		self.Keys[Enum.KeyCode.ButtonL2] = nil
	end
	if self.MobileControls then self.MobileControls:Destroy();self.MobileControls=nil end
	self.PendingAction = nil
	if self.TouchGui then self.TouchGui:Destroy();self.TouchGui=nil end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return Controller
