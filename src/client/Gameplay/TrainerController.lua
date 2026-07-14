--!strict
local TrainerPromptComponent = require(script.Parent.Parent.Components.TrainerPromptComponent)
local ControlGlyphService = require(script.Parent.Parent.Services.ControlGlyphService)

local Controller = {}
Controller.__index = Controller

local PROMPTS: any = {
	Possession = {{Label = "SHOOT", Action = "Shoot", Glyph = "Shot"}, {Label = "PASS", Action = "Pass", Glyph = "GroundPass"}, {Label = "THROUGH PASS", Action = "Pass", Glyph = "ThroughPass"}, {Label = "LOB", Action = "Pass", Glyph = "Lob"}, {Label = "SPRINT", Action = "Sprint"}},
	Defending = {{Label = "SWITCH PLAYER", Action = "Switch"}, {Label = "TACKLE", Action = "Tackle"}, {Label = "SLIDE TACKLE", Action = "SlideTackle"}, {Label = "BLOCK", Action = "Block"}, {Label = "SPRINT", Action = "Sprint"}},
	Loose = {{Label = "CHASE", Action = "Move"}, {Label = "SWITCH", Action = "Switch"}, {Label = "SPRINT", Action = "Sprint"}},
}

function Controller.new(parent: Instance, ball: BasePart, mode: string?, settings: any?)
	return setmetatable({Ball = ball, Mode = mode or "Basic", Settings = settings or {}, Prompt = TrainerPromptComponent.new(parent), LastState = "", LastDevice = "", MatchActive = false, HiddenActions = {}, StateVisibleUntil = 0, Busy = false}, Controller)
end

function Controller:SetMatchActive(active: boolean)
	self.MatchActive = active
	if active and self.Mode == "WorldCupOnboarding" and not self.OnboardingStartedAt then
		self.OnboardingStartedAt = os.clock()
	end
	if not active then self.Prompt:SetVisible(false) end
end

function Controller:SetActive(model: Model?)
	self.Active = model
	self.Prompt:SetAdornee(model and model:FindFirstChild("HumanoidRootPart") :: BasePart?)
	self.LastState = ""
end

function Controller:SetMode(mode: string)
	self.Mode = mode == "Off" and "Off" or mode == "Full" and "Full" or mode == "WorldCupOnboarding" and "WorldCupOnboarding" or "Basic"
	self.OnboardingStartedAt = self.Mode == "WorldCupOnboarding" and os.clock() or nil
	self.LastState = ""
	self.LastDevice = ""
end

function Controller:SetTutorialPrompt(message:string?,action:string?,count:number?,target:number?)
	self.TutorialPrompt = {Message = tostring(message or ""), Action = tostring(action or ""), Count = tonumber(count) or 0, Target = tonumber(target) or 0}
	self.LastState = ""
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
	if self.Mode == "WorldCupOnboarding" then
		if self.TutorialPrompt then
			local message=tostring(self.TutorialPrompt.Message or "")
			local action=tostring(self.TutorialPrompt.Action or "")
			local count=tonumber(self.TutorialPrompt.Count)or 0
			local target=tonumber(self.TutorialPrompt.Target)or 0
			if action=="StartMatch"or message==""then return{}end
			local suffix=target>1 and("  "..tostring(count).."/"..tostring(target))or""
			local glyphAction = action == "Pass" and "GroundPass" or action == "Shoot" and "Shot" or action
			return{{Label=message..suffix,Key=ControlGlyphService.Glyph(glyphAction,self.Settings,{MobilePassContext="Swipe"}),Action=action}}
		end
		local elapsed = os.clock() - (self.OnboardingStartedAt or os.clock())
		if elapsed < 35 then
			if state == "Possession" then return {{Label = "PASS", Key = ControlGlyphService.Glyph("GroundPass",self.Settings), Action = "Pass"}} end
			return {}
		elseif elapsed < 70 then
			if state == "Possession" then return {{Label = "HOLD SHOOT AND RELEASE", Key = ControlGlyphService.Glyph("Shot",self.Settings), Action = "Shoot"}} end
			return {}
		elseif elapsed < 105 then
			if state == "Defending" then
				return {{Label = "TACKLE", Key = ControlGlyphService.Glyph("Tackle",self.Settings), Action = "Tackle"}, {Label = "SWITCH", Key = ControlGlyphService.Glyph("Switch",self.Settings), Action = "Switch"}, {Label = "SPRINT", Key = ControlGlyphService.Glyph("Sprint",self.Settings), Action = "Sprint"}}
			end
			return {}
		end
		return {}
	end
	for _, prompt in PROMPTS[state] or {} do
		if os.clock() >= (self.HiddenActions[prompt.Action] or 0) then
			table.insert(prompts, {Label=prompt.Label,Key=ControlGlyphService.Glyph(prompt.Glyph or prompt.Action,self.Settings,{MobilePassContext="Swipe"}),Action=prompt.Action})
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
	local promptPoint = activeRoot.Position + Vector3.new(0, 4.2, 0)
	local screenPoint, onScreen = camera:WorldToViewportPoint(promptPoint)
	if not onScreen or screenPoint.Z <= 0 then self.Prompt:SetVisible(false) return end
	local ownerName = self.Ball:GetAttribute("OwnerModel")
	local state = ownerName == self.Active.Name and "Possession" or ownerName == "" and "Loose" or "Defending"
	local device = ControlGlyphService.CurrentDevice()
	if state ~= self.LastState or device ~= self.LastDevice then
		self.LastState = state
		self.LastDevice = device
		self.StateVisibleUntil = os.clock() + 5
		self.Prompt:SetPrompts(self:_prompts(state))
	end
	local velocity = Vector3.new(activeRoot.AssemblyLinearVelocity.X, 0, activeRoot.AssemblyLinearVelocity.Z).Magnitude
	local idle = velocity < 0.65
	if os.clock() < (self.HiddenUntil or 0) or (self.Mode ~= "WorldCupOnboarding" and os.clock() > self.StateVisibleUntil and not idle) then
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
