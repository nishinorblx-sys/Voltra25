--!strict
local Controller = {}
Controller.__index = Controller

function Controller.new(ball: BasePart)
	return setmetatable({Ball = ball, LastPosition = ball.Position, Radius = math.max(ball.Size.X * 0.5, 0.1)}, Controller)
end

function Controller:Update(dt: number, dribbling: boolean)
	local delta = self.Ball.Position - self.LastPosition
	self.LastPosition = self.Ball.Position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if not dribbling or flat.Magnitude < 0.001 or dt <= 0 then return end
	local rotationAmount = flat.Magnitude / self.Radius
	local rollAxis = Vector3.yAxis:Cross(flat.Unit)
	self.Ball.AssemblyAngularVelocity = rollAxis * (rotationAmount / dt)
end

function Controller:Destroy() end

return Controller
