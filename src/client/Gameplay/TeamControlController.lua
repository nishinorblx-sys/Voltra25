--!strict
local Controller = {}
Controller.__index = Controller

function Controller.new(remote: RemoteEvent, camera: any, hud: any, active: Model)
	return setmetatable({
		Remote = remote,
		Camera = camera,
		HUD = hud,
		Active = active,
		MoveClock = 0,
	}, Controller)
end

function Controller:SetActive(model: Model, name: string?, position: string?)
	self.Active = model
	self.Camera:SetActive(model)
	self.HUD:SetActivePlayer(name or model:GetAttribute("DisplayName") or "PLAYER", position or model:GetAttribute("position") or "", model)
end

function Controller:SetSwitchTarget(_model: Model?)
	-- Visual switch targeting is owned by PlayerIndicatorController.
end

function Controller:Update(dt: number, input: Vector2)
	self.MoveClock += dt
	if self.MoveClock >= 0.033 then
		self.MoveClock = 0
		self.Remote:FireServer({Type = "Move", Direction = self.Camera:Movement(input)})
	end
end

function Controller:Destroy()
end

return Controller
