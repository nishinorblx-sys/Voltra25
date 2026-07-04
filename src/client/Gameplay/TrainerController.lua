--!strict
local UserInputService = game:GetService("UserInputService")
local TrainerPromptComponent = require(script.Parent.Parent.Components.TrainerPromptComponent)

local Controller = {}
Controller.__index = Controller

local PROMPTS = {
	KeyboardMouse = {
		Possession = {{Label = "SHOOT", Key = "LMB", Action = "Shoot"}, {Label = "PASS", Key = "RMB", Action = "Pass"}, {Label = "MANUAL LOB", Key = "ALT", Action = "Lob"}, {Label = "MANUAL PASS", Key = "CTRL", Action = "Manual"}, {Label = "DRIBBLE", Key = "C", Action = "Dribble"}},
		Defending = {{Label = "SWITCH PLAYER", Key = "Q", Action = "Switch"}, {Label = "TACKLE", Key = "E", Action = "Tackle"}, {Label = "SLIDE TACKLE", Key = "F", Action = "SlideTackle"}, {Label = "BLOCK", Key = "R", Action = "Block"}},
		Loose = {{Label = "CHASE", Key = "WASD", Action = "Move"}, {Label = "SWITCH", Key = "Q", Action = "Switch"}},
	},
	Gamepad = {
		Possession = {{Label = "PASS", Key = "A", Action = "Pass"}, {Label = "SHOOT", Key = "B", Action = "Shoot"}, {Label = "LOBBED PASS", Key = "X", Action = "Lob"}, {Label = "MANUAL PASS", Key = "Y", Action = "Manual"}, {Label = "SPRINT LOCK", Key = "R2", Action = "Sprint"}},
		Defending = {{Label = "SWITCH PLAYER", Key = "L1", Action = "Switch"}, {Label = "STAND TACKLE", Key = "A", Action = "Tackle"}, {Label = "SLIDE TACKLE", Key = "X", Action = "SlideTackle"}, {Label = "SPRINT LOCK", Key = "R2", Action = "Sprint"}},
		Loose = {{Label = "CHASE", Key = "LS", Action = "Move"}, {Label = "SWITCH", Key = "L1", Action = "Switch"}, {Label = "SPRINT LOCK", Key = "R2", Action = "Sprint"}},
	},
}

local function currentDevice(): string
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

function Controller.new(parent: Instance, ball: BasePart, mode: string?)
	return setmetatable({Ball = ball, Mode = mode or "Basic", Prompt = TrainerPromptComponent.new(parent), LastState = "", LastDevice = "", MatchActive = false, HiddenActions = {}, StateVisibleUntil = 0, Busy = false}, Controller)
end

function Controller:SetMatchActive(active: boolean)
	self.MatchActive = active
	if not active then self.Prompt:SetVisible(false) end
end

function Controller:SetActive(model: Model?)
	self.Active = model
	self.Prompt:SetAdornee(model and model:FindFirstChild("HumanoidRootPart") :: BasePart?)
	self.LastState = ""
end

function Controller:SetMode(mode: string)
	self.Mode = mode == "Off" and "Off" or mode == "Full" and "Full" or "Basic"
	self.LastState = ""
	self.LastDevice = ""
end

function Controller:SetBusy(busy: boolean)
	self.Busy = busy
	if busy then self.Prompt:SetVisible(false) end
end

function Controller:NotifyAction(action: string?)
	if action then self.HiddenActions[action] = os.clock() + 30 end
	self.HiddenUntil = os.clock() + 2.4
	self.Prompt:SetVisible(false)
end

function Controller:_prompts(state: string): {{Label: string, Key: string}}
	local prompts = {}
	local device = currentDevice()
	local promptSet = PROMPTS[device] or PROMPTS.KeyboardMouse
	for _, prompt in promptSet[state] do
		if os.clock() >= (self.HiddenActions[prompt.Action] or 0) then
			table.insert(prompts, prompt)
			if #prompts >= 5 then break end
		end
	end
	return prompts
end

function Controller:Update()
	if self.Mode == "Off" or not self.Active or not self.MatchActive or self.Busy then
		self.Prompt:SetVisible(false)
		return
	end
	local activeRoot = self.Active:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not activeRoot or not camera then self.Prompt:SetVisible(false) return end
	local sidePoint = activeRoot.Position + camera.CFrame.RightVector * 4 + Vector3.new(0, 3.2, 0)
	local screenPoint, onScreen = camera:WorldToViewportPoint(sidePoint)
	if not onScreen or screenPoint.Z <= 0 then self.Prompt:SetVisible(false) return end
	local ownerName = self.Ball:GetAttribute("OwnerModel")
	local state = ownerName == self.Active.Name and "Possession" or ownerName == "" and "Loose" or "Defending"
	local device = currentDevice()
	if state ~= self.LastState or device ~= self.LastDevice then
		self.LastState = state
		self.LastDevice = device
		self.StateVisibleUntil = os.clock() + 5
		self.Prompt:SetPrompts(self:_prompts(state))
	end
	local velocity = Vector3.new(activeRoot.AssemblyLinearVelocity.X, 0, activeRoot.AssemblyLinearVelocity.Z).Magnitude
	local idle = velocity < 0.65
	if os.clock() < (self.HiddenUntil or 0) or (os.clock() > self.StateVisibleUntil and not idle) then
		self.Prompt:SetVisible(false)
		return
	end
	self.Prompt:SetScreenPosition(Vector2.new(screenPoint.X, screenPoint.Y), camera.ViewportSize)
	local prompts = self:_prompts(state)
	self.Prompt:SetPrompts(prompts)
	self.Prompt:SetVisible(#prompts > 0)
end

function Controller:Destroy()
	self.Prompt:Destroy()
end

return Controller
