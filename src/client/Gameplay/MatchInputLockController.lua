--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controller = {}
Controller.__index = Controller

local RENDER_STEP = "VTRMatchMouseFreedom"

function Controller.new(_remote: RemoteEvent)
	return setmetatable({Active = false, InputEnabled = true}, Controller)
end

function Controller:Start(lockMouse: boolean?)
	if self.Active then
		return
	end
	self.Active = true
	self.LockMouse = lockMouse == true
	self.PreviousMouseBehavior = UserInputService.MouseBehavior
	self.PreviousMouseIcon = UserInputService.MouseIconEnabled
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Input.Value + 1, function()
		if self.Active then
			UserInputService.MouseBehavior = if self.LockMouse then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = not self.LockMouse
		end
	end)
end

function Controller:SetSprintEnabled(enabled: boolean)
	self.InputEnabled = enabled == true
end

function Controller:Destroy()
	if not self.Active then
		return
	end
	self.Active = false
	RunService:UnbindFromRenderStep(RENDER_STEP)
	UserInputService.MouseBehavior = self.PreviousMouseBehavior or Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = self.PreviousMouseIcon ~= false
end

return Controller
