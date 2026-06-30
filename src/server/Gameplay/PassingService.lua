--!strict
local Service = {}
Service.__index = Service

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function Service.new(ballService: any, targeting: any, remote: RemoteEvent, teams: any)
	return setmetatable({BallService = ballService, Targeting = targeting, Remote = remote, Teams = teams, Random = Random.new()}, Service)
end

function Service:_pressure(passer: Model): number
	local passerRoot = root(passer)
	if not passerRoot then return 1 end
	local side = tostring(passer:GetAttribute("VTRTeam") or "Home")
	local nearest = 20
	for _, opponent in self.Teams[side == "Home" and "Away" or "Home"] or {} do
		local opponentRoot = root(opponent)
		if opponentRoot then nearest = math.min(nearest, (opponentRoot.Position - passerRoot.Position).Magnitude) end
	end
	return 1 - math.clamp((nearest - 2) / 12, 0, 1)
end

function Service:_errorRadius(passer: Model, distance: number, pressure: number): number
	local passing = math.clamp(tonumber(passer:GetAttribute("PAS")) or 60, 1, 99)
	local weakFoot = math.clamp(tonumber(passer:GetAttribute("WeakFoot")) or 3, 1, 5)
	local balance = math.clamp(tonumber(passer:GetAttribute("Balance")) or 65, 1, 99)
	local base = passing >= 85 and 0.12 or passing >= 70 and 0.32 or passing >= 55 and 0.68 or 1.15
	local longError = math.max(0, distance - 35) * 0.009
	local pressureError = pressure * 2.15
	local sprintError = passer:GetAttribute("VTRSprinting") == true and 0.42 or 0
	local weakFootError = (5 - weakFoot) * 0.12
	local balanceError = (100 - balance) / 190
	return base + longError + pressureError + sprintError + weakFootError + balanceError
end

function Service:Pass(passer: Model, aimDirection: Vector3, charge: number, passType: string?, aimPosition: Vector3?, lockedReceiver: Model?): (Model?, Vector3?)
	local passerRoot = root(passer)
	if not passerRoot then return nil, nil end
	local pressure = self:_pressure(passer)
	local receiver, targetPoint, targetDistance, targetScore
	if lockedReceiver then
		receiver, targetPoint, targetDistance, targetScore = self.Targeting:ChooseReceiver(passer, lockedReceiver, charge, passType)
	elseif aimPosition then
		receiver, targetPoint, targetDistance, targetScore = self.Targeting:ChooseAtPoint(passer, aimPosition, charge, passType, pressure)
	else
		receiver, targetPoint, targetDistance, targetScore = self.Targeting:Choose(passer, aimDirection, passType, charge, pressure)
	end
	if not receiver then return nil, nil end
	local direction = flat(targetPoint - passerRoot.Position)
	if direction.Magnitude < 0.1 then return nil, nil end
	local errorRadius = self:_errorRadius(passer, targetDistance, pressure)
	if passType=="Lofted"then errorRadius*=.22 end
	local perpendicular = Vector3.new(-direction.Z, 0, direction.X).Unit
	local lateralError = self.Random:NextNumber(-errorRadius, errorRadius)
	local depthError = self.Random:NextNumber(-errorRadius * 0.3, errorRadius * 0.3)
	local adjustedPoint = targetPoint + perpendicular * lateralError + direction.Unit * depthError
	local succeeded = self.BallService:Kick(passer, "Pass", adjustedPoint - passerRoot.Position, math.clamp(charge, 0, 1), receiver, passType, targetDistance,adjustedPoint)
	if not succeeded then return nil, nil end
	self.Remote:FireAllClients({Type = "PassTarget", Model = receiver, Passer = passer, ReceivePoint = targetPoint, TargetScore = targetScore})
	return receiver, targetPoint
end

return Service
