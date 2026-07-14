--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PassErrorResolver = require(ReplicatedStorage.VTR.Shared.PassErrorResolver)
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

function Service:_pressure(passer: Model): (number, Vector3)
	local passerRoot = root(passer)
	if not passerRoot then return 1, Vector3.zero end
	local side = tostring(passer:GetAttribute("VTRTeam") or "Home")
	local nearest = 20
	local pressureDirection = Vector3.zero
	for _, opponent in self.Teams[side == "Home" and "Away" or "Home"] or {} do
		local opponentRoot = root(opponent)
		if opponentRoot then
			local offset = flat(opponentRoot.Position - passerRoot.Position)
			if offset.Magnitude < nearest then nearest = offset.Magnitude;pressureDirection = offset.Magnitude > 0.05 and offset.Unit or Vector3.zero end
		end
	end
	return 1 - math.clamp((nearest - 2) / 12, 0, 1), pressureDirection
end

function Service:_errorProfile(passer: Model, targetPoint: Vector3, distance: number, pressure: number, pressureDirection: Vector3, passType: string?): any
	local passerRoot = root(passer)
	if not passerRoot then return PassErrorResolver.Resolve({Distance=distance,Pressure=pressure,PassFamily=passType}) end
	local direction = flat(targetPoint - passerRoot.Position)
	local fallback = flat(passerRoot.CFrame.LookVector)
	fallback = fallback.Magnitude > 0.05 and fallback.Unit or Vector3.zAxis
	direction = direction.Magnitude > 0.05 and direction.Unit or fallback
	local facing = flat(passerRoot.CFrame.LookVector)
	facing = facing.Magnitude > 0.05 and facing.Unit or direction
	local right = flat(passerRoot.CFrame.RightVector)
	right = right.Magnitude > 0.05 and right.Unit or Vector3.xAxis
	local bodyDot = math.clamp(facing:Dot(direction), -1, 1)
	return PassErrorResolver.Resolve({
		Passing = passer:GetAttribute("PAS"),
		WeakFoot = passer:GetAttribute("WeakFoot"),
		Balance = passer:GetAttribute("Balance"),
		Distance = distance,
		Pressure = pressure,
		PressureFromKickingSide = pressureDirection.Magnitude > 0.05 and math.max(0, pressureDirection:Dot(right)) or 0,
		Sprinting = passer:GetAttribute("VTRSprinting") == true,
		MovementSpeed = flat(passerRoot.AssemblyLinearVelocity).Magnitude,
		BodyDot = bodyDot,
		TurnAngle = math.acos(bodyDot),
		TargetLateral = direction:Dot(right),
		PreferredFoot = passer:GetAttribute("PreferredFoot"),
		SelectedFoot = passer:GetAttribute("VTRPassFoot"),
		PassFamily = passType or "Ground",
	})
end

function Service:Pass(passer: Model, aimDirection: Vector3, charge: number, passType: string?, aimPosition: Vector3?, lockedReceiver: Model?): (Model?, Vector3?)
	local passerRoot = root(passer)
	if not passerRoot then return nil, nil end
	local pressure, pressureDirection = self:_pressure(passer)
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
	local errorProfile = self:_errorProfile(passer, targetPoint, targetDistance, pressure, pressureDirection, passType)
	local errorRadius = errorProfile.Radius
	local perpendicular = Vector3.new(-direction.Z, 0, direction.X).Unit
	local lateralError = self.Random:NextNumber(-errorRadius, errorRadius)
	local depthError = self.Random:NextNumber(-errorRadius * 0.3, errorRadius * 0.3)
	local adjustedPoint = targetPoint + perpendicular * lateralError + direction.Unit * depthError
	passer:SetAttribute("VTRPassFoot", errorProfile.KickingFoot)
	local succeeded = self.BallService:Kick(passer, "Pass", adjustedPoint - passerRoot.Position, math.clamp(charge, 0, 1), receiver, passType, targetDistance,adjustedPoint)
	passer:SetAttribute("VTRPassFoot", nil)
	if not succeeded then return nil, nil end
	self.Remote:FireAllClients({Type = "PassTarget", Model = receiver, Passer = passer, ReceivePoint = targetPoint, TargetScore = targetScore})
	return receiver, targetPoint
end

return Service
