--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local Service = {}
Service.__index = Service

function Service.new(ball: BasePart, pitchCFrame: CFrame, width: number, length: number, ballService: any, onRestart: (string, string, Vector3) -> ())
	return setmetatable({Ball = ball, PitchCFrame = pitchCFrame, Width = width, Length = length, BallService = ballService, OnRestart = onRestart, Locked = false,Pending=nil}, Service)
end

function Service:Reset()
	self.Locked = false
	self.Pending=nil
end

function Service:GetLastExit(): any
	return self.LastExit
end

function Service:Step()
	if self.Locked then
		if self.Pending and os.clock()>=self.Pending.At then local pending=self.Pending;self.Pending=nil;self.OnRestart(pending.Kind,pending.Team,pending.Location)end
		return
	end
	local localPosition = self.PitchCFrame:PointToObjectSpace(self.Ball.Position)
	local outsideSide = math.abs(localPosition.X) > self.Width / 2
	local outsideGoalLine = math.abs(localPosition.Z) > self.Length / 2
	if not outsideSide and not outsideGoalLine then
		return
	end
	self.Locked = true
	local lastTeam = self.BallService:GetLastTouchTeam()
	local velocity = self.Ball.AssemblyLinearVelocity
	self.LastExit = {Location = self.Ball.Position, Direction = velocity.Magnitude > 0.1 and velocity.Unit or Vector3.zero, LastTouchTeam = lastTeam, LastTouchPlayer = self.BallService:GetLastTouchPlayer()}
	local restartTeam = lastTeam == "Home" and "Away" or "Home"
	if outsideSide and math.abs(localPosition.Z) <= self.Length / 2 + 5 then
		self.Pending={Kind="ThrowIn",Team=restartTeam,Location=self.Ball.Position,At=os.clock()+2}
		return
	end
	local insideGoal = math.abs(localPosition.X) <= math.min(Config.Pitch.GoalWidth, self.Width * 0.28) / 2 and localPosition.Y <= Config.Pitch.GoalHeight
	if insideGoal then
		self.Locked = false
		return
	end
	local attacking = localPosition.Z < 0 and "Home" or "Away"
	local defending = attacking == "Home" and "Away" or "Home"
	if lastTeam == defending then
		self.Pending={Kind="Corner",Team=attacking,Location=self.Ball.Position,At=os.clock()+2}
	else
		self.Pending={Kind="GoalKick",Team=defending,Location=self.Ball.Position,At=os.clock()+2}
	end
end

return Service
