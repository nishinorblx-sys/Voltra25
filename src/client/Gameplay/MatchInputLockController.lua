--!strict
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controller = {}
Controller.__index = Controller

local ACTION = "VTRMatchSprintAndShiftLock"
local RENDER_STEP = "VTRMatchMouseFreedom"

function Controller.new(remote: RemoteEvent)
	return setmetatable({Remote = remote, Sprinting = false, Active = false, SprintEnabled = true}, Controller)
end

function Controller:_setSprint(active: boolean)
	if self.Sprinting == active then
		return
	end
	self.Sprinting = active
	self.Remote:FireServer({Type = "Sprint", Active = active})
	self.Remote:FireServer({Type = "ReceiverAssistOverride", Active = active})
end

function Controller:Start(lockMouse: boolean?)
	if self.Active then
		return
	end
	self.Active = true
	self.LockMouse = lockMouse == true
	self.PreviousMouseBehavior = UserInputService.MouseBehavior
	self.PreviousMouseIcon = UserInputService.MouseIconEnabled
	UserInputService.MouseBehavior = self.LockMouse and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not self.LockMouse
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin and self.SprintEnabled then
			self:_setSprint(not self.Sprinting)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Input.Value + 1, function()
		if self.Active then
			UserInputService.MouseBehavior = self.LockMouse and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = not self.LockMouse
		end
	end)
end

function Controller:SetSprintEnabled(enabled: boolean)
	self.SprintEnabled = enabled
	if not enabled then
		self:_setSprint(false)
	end
end

function Controller:Destroy()
	if not self.Active then
		return
	end
	self:_setSprint(false)
	self.Active = false
	ContextActionService:UnbindAction(ACTION)
	RunService:UnbindFromRenderStep(RENDER_STEP)
	UserInputService.MouseBehavior = self.PreviousMouseBehavior or Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = self.PreviousMouseIcon ~= false
end

return Controller
