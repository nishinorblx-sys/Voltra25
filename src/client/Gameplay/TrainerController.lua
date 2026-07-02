--!strict
local TrainerPromptComponent = require(script.Parent.Parent.Components.TrainerPromptComponent)

local Controller = {}
Controller.__index = Controller

local PROMPTS = {
	Possession = {{Label = "SHOOT", Key = "LMB"}, {Label = "PASS", Key = "RMB"}, {Label = "LOBBED PASS", Key = "ALT+RMB"}, {Label = "MANUAL PASS", Key = "CTRL+RMB"}, {Label = "DRIBBLE", Key = "C"}},
	Defending = {{Label = "SWITCH PLAYER", Key = "Q"}, {Label = "TACKLE", Key = "E"}, {Label = "SLIDE TACKLE", Key = "F"}, {Label = "BLOCK", Key = "R"}},
	Loose = {{Label = "CHASE", Key = "WASD"}, {Label = "SWITCH", Key = "Q"}},
}

function Controller.new(parent: Instance, ball: BasePart, mode: string?)
	return setmetatable({Ball = ball, Mode = mode or "Basic", Prompt = TrainerPromptComponent.new(parent), LastState = "", MatchActive = false, HiddenKeys = {}, StateVisibleUntil = 0, Busy = false}, Controller)
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
end

function Controller:SetBusy(busy: boolean)
	self.Busy = busy
	if busy then self.Prompt:SetVisible(false) end
end

function Controller:NotifyAction(action: string?)
	local key = action == "Pass" and "RMB" or action == "Shoot" and "LMB" or action == "Tackle" and "E" or action == "SlideTackle" and "F" or action == "Block" and "R" or nil
	if key then self.HiddenKeys[key] = os.clock() + 30 end
	self.HiddenUntil = os.clock() + 2.4
	self.Prompt:SetVisible(false)
end

function Controller:_prompts(state: string): {{Label: string, Key: string}}
	local prompts = {}
	for _, prompt in PROMPTS[state] do
		if os.clock() >= (self.HiddenKeys[prompt.Key] or 0) then
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
	if state ~= self.LastState then
		self.LastState = state
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
