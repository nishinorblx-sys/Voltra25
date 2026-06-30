--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local InputController = {}
InputController.__index = InputController

function InputController.new(actionRemote: RemoteEvent, aimProvider: () -> Vector3)
	return setmetatable({
		ActionRemote = actionRemote,
		AimProvider = aimProvider,
		Keys = {},
		ChargingSince = nil,
		Connections = {},
		ActionCallback = nil,
	}, InputController)
end

function InputController:Start()
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		local code = input.KeyCode
		if code == Enum.KeyCode.W or code == Enum.KeyCode.A or code == Enum.KeyCode.S or code == Enum.KeyCode.D then self.Keys[code] = true end
		if code == Enum.KeyCode.LeftShift or code == Enum.KeyCode.RightShift then
			self.Keys[code] = true
			self:_send({ Type = "Sprint", Active = true })
		elseif code == Enum.KeyCode.E then
			self:_send({ Type = "Tackle" })
		elseif code == Enum.KeyCode.F then
			self:_send({ Type = "SlideTackle" })
		elseif code == Enum.KeyCode.R then
			self:_send({ Type = "Block", Active = true })
		elseif code == Enum.KeyCode.C then
			self:_send({ Type = "Skill", Direction = self.AimProvider() })
		elseif code == Enum.KeyCode.Q then
			self:_send({ Type = "Switch" })
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.ChargingSince = os.clock()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_send({ Type = "Pass", Direction = self.AimProvider() })
		end
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
		local code = input.KeyCode
		if code == Enum.KeyCode.W or code == Enum.KeyCode.A or code == Enum.KeyCode.S or code == Enum.KeyCode.D then self.Keys[code] = nil end
		if code == Enum.KeyCode.LeftShift or code == Enum.KeyCode.RightShift then
			self.Keys[code] = nil
			self:_send({ Type = "Sprint", Active = false })
		elseif code == Enum.KeyCode.R then
			self:_send({ Type = "Block", Active = false })
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and self.ChargingSince then
			local charge = math.clamp((os.clock() - self.ChargingSince) / Config.Ball.MaxChargeTime, 0, 1)
			self.ChargingSince = nil
			self:_send({ Type = "Shot", Direction = self.AimProvider(), Charge = charge })
		end
	end))
end

function InputController:_send(payload: any)
	self.ActionRemote:FireServer(payload)
	if self.ActionCallback then self.ActionCallback(payload) end
end

function InputController:GetMoveVector(): Vector2
	local x = (self.Keys[Enum.KeyCode.D] and 1 or 0) - (self.Keys[Enum.KeyCode.A] and 1 or 0)
	local y = (self.Keys[Enum.KeyCode.W] and 1 or 0) - (self.Keys[Enum.KeyCode.S] and 1 or 0)
	local vector = Vector2.new(x, y)
	return if vector.Magnitude > 1 then vector.Unit else vector
end

function InputController:IsSprinting(): boolean
	return self.Keys[Enum.KeyCode.LeftShift] == true or self.Keys[Enum.KeyCode.RightShift] == true
end

function InputController:GetCharge(): number
	return if self.ChargingSince then math.clamp((os.clock() - self.ChargingSince) / Config.Ball.MaxChargeTime, 0, 1) else 0
end

function InputController:Destroy()
	for _, connection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
end

return InputController
