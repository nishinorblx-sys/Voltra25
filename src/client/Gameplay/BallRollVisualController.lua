--!strict
local Controller = {}
Controller.__index = Controller

function Controller.new(ball: BasePart)
	return setmetatable({Ball = ball, LastPosition = ball.Position, Radius = math.max(ball.Size.X * 0.5, 0.1)}, Controller)
end

function Controller:Update(dt: number, dribbling: boolean)
	self.LastPosition = self.Ball.Position
end

function Controller:Destroy() end

return Controller
