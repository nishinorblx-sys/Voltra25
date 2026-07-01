--!strict
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local VoltraLiteMobileControls = require(script:FindFirstAncestor("VTRClient").Components.VoltraLiteMobileControls)
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)

local Controller = {}
Controller.__index = Controller

function Controller.new(remote: RemoteEvent, aim: (string?,number?) -> any)
	return setmetatable({Remote = remote, Aim = aim, Keys = {}, Charge = nil, Connections = {}, AutoSwitch = "Assisted", ReceiverAssist = "Light", FreeKickCurve = 0, FreeKickLift = 0, LastFreeKickAt = 0}, Controller)
end

function Controller:SetAutoSwitch(mode: string?)
	self.AutoSwitch = mode == "Off" and "Off" or mode == "Instant" and "Instant" or "Assisted"
end

function Controller:SetReceiverAssist(mode: string?)
	self.ReceiverAssist = mode == "Off" and "Off" or mode == "Assisted" and "Assisted" or "Light"
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
end

function Controller:_aim(kind: string,charge:number?): any
	local value = self.Aim(kind,charge)
	if type(value) == "table" then
		return value
	end
	return {Direction = value}
end

function Controller:_chargeStart(kind: string)
	if not self.Charge then
		self.Charge = {Kind = kind, Started = os.clock()}
	end
end

function Controller:_chargeEnd(kind: string)
	local current = self.Charge
	if not current or current.Kind ~= kind then
		return
	end
	local charge = math.clamp((os.clock() - current.Started) / (Config.Ball.MaxChargeTime / 3), 0, 1)
	self.Charge = nil
	local aim = self:_aim(kind,charge)
	if kind == "Shot" then
		self.Remote:FireServer({Type = "Shot", Direction = aim.Direction, AimPosition = aim.Position, GoalTarget = aim.GoalTarget, Charge = charge, FreeKickCurve = aim.FreeKickCurve, FreeKickLift = aim.FreeKickLift, PenaltySlot = aim.PenaltySlot})
	else
		local altDown = self.Keys[Enum.KeyCode.LeftAlt] == true or self.Keys[Enum.KeyCode.RightAlt] == true
		local ctrlDown = self.Keys[Enum.KeyCode.LeftControl] == true or self.Keys[Enum.KeyCode.RightControl] == true
		local manualLobbed = altDown and ctrlDown
		local manual = ctrlDown and not manualLobbed
		local lofted = altDown and not ctrlDown
		local through=not manualLobbed and not manual and not lofted and self.Keys[Enum.KeyCode.W] == true and charge >= 0.18
		local passType=manualLobbed and"ManualLobbed"or manual and"Manual"or lofted and"Lofted"or through and"Through"or"Ground"
		local isManual = manual or manualLobbed
		self.Remote:FireServer({Type = "Pass", Direction = aim.Direction, AimPosition = aim.Position, TargetModel = isManual and nil or aim.TargetModel, Charge = charge, PassType = passType, AutoSwitch = isManual and"Off"or self.AutoSwitch, ReceiverAssist = isManual and"Off"or self.ReceiverAssist})
	end
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
		if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D
			or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift
			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then
			self.Keys[key] = true
		elseif key == Enum.KeyCode.E then
			self.Remote:FireServer({Type = "Tackle"})
		elseif key==Enum.KeyCode.F then
			self.Remote:FireServer({Type="SlideTackle"})
		elseif key==Enum.KeyCode.C then
			local aim=self:_aim("Skill");self.Remote:FireServer({Type="DribbleMove",Direction=aim.Direction})
		elseif key==Enum.KeyCode.R then
			self.Remote:FireServer({Type="Block",Active=true})
		elseif key == Enum.KeyCode.Q then
			local aim=self:_aim("Switch");self.Remote:FireServer({Type = "Switch",TargetModel=aim.TargetModel,AimPosition=aim.Position})
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
		if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D
			or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift
			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then
			self.Keys[key] = nil
		elseif key==Enum.KeyCode.R then
			self.Remote:FireServer({Type="Block",Active=false})
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_chargeEnd("Shot")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_chargeEnd("Pass")
		end
	end))
end

function Controller:Move(): Vector2
	local keyboard = Vector2.new((self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0), (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0))
	if keyboard.Magnitude > 1 then
		keyboard = keyboard.Unit
	end
	local mobile = self.MobileControls and self.MobileControls:MoveVector() or Vector2.zero
	return keyboard.Magnitude > 0.05 and keyboard or mobile
end

function Controller:Sprinting(): boolean
	return self.Keys[Enum.KeyCode.LeftShift] == true or self.Keys[Enum.KeyCode.RightShift] == true
end

function Controller:ChargeValue(): number
	return self.Charge and math.clamp((os.clock() - self.Charge.Started) / (Config.Ball.MaxChargeTime / 3), 0, 1) or 0
end

function Controller:ChargeKind(): string
	return self.Charge and self.Charge.Kind or ""
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
	self.FreeKickCurve = math.clamp((self.FreeKickCurve or 0) + curveInput * curveRate * dt, -curveClamp, curveClamp)
	self.FreeKickLift = math.clamp((self.FreeKickLift or 0) + liftInput * liftRate * dt, -liftClamp, liftClamp)
	return self.FreeKickCurve, self.FreeKickLift
end

function Controller:Destroy()
	if self.MobileControls then self.MobileControls:Destroy();self.MobileControls=nil end
	if self.TouchGui then self.TouchGui:Destroy();self.TouchGui=nil end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return Controller
