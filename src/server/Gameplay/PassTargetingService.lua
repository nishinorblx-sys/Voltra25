--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Power = require(ReplicatedStorage.VTR.Shared.PassingPowerConfig)
local PassInterceptService = require(script.Parent.PassInterceptService)

local Service = {}
Service.__index = Service

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function distanceToSegment(point: Vector3, from: Vector3, to: Vector3): number
	local segment = flat(to - from)
	if segment.Magnitude < 0.01 then
		return flat(point - from).Magnitude
	end
	local alpha = math.clamp(flat(point - from):Dot(segment) / segment:Dot(segment), 0, 1)
	return flat(point - (from + segment * alpha)).Magnitude
end

function Service.new(teams: any, pitchCFrame: CFrame)
	return setmetatable({Teams = teams, PitchCFrame = pitchCFrame, VelocitySamples = {}}, Service)
end

function Service:_pressure(model: Model, opponents: {Model}): number
	local modelRoot = root(model)
	if not modelRoot then return 1 end
	local nearest = 20
	for _, opponent in opponents do
		local opponentRoot = root(opponent)
		if opponentRoot then nearest = math.min(nearest, (opponentRoot.Position - modelRoot.Position).Magnitude) end
	end
	return 1 - math.clamp((nearest - 2) / 12, 0, 1)
end

function Service:_laneScore(from: Vector3, to: Vector3, opponents: {Model}): number
	local nearest = 16
	for _, opponent in opponents do
		local opponentRoot = root(opponent)
		if opponentRoot then nearest = math.min(nearest, distanceToSegment(opponentRoot.Position, from, to)) end
	end
	return math.clamp((nearest - 1.5) / 9, 0, 1)
end

function Service:_receivePoint(passerPosition: Vector3, candidate: Model, passType: string?, charge: number): Vector3
	local candidateRoot = root(candidate) :: BasePart
	local side = tostring(candidate:GetAttribute("VTRTeam") or "Home")
	local opponents = self.Teams[side == "Home" and "Away" or "Home"] or {}
	local velocity = flat(candidateRoot.AssemblyLinearVelocity)
	if velocity.Magnitude > 21 then velocity = velocity.Unit * 21 end
	local now = os.clock()
	local previous = self.VelocitySamples[candidate]
	local acceleration = Vector3.zero
	if previous and now - previous.At >= 0.04 then acceleration = (velocity - previous.Velocity) / math.max(now - previous.At, 0.04) end
	if not previous or now - previous.At >= 0.04 then self.VelocitySamples[candidate] = {Velocity = velocity, At = now} end
	if acceleration.Magnitude > 18 then acceleration = acceleration.Unit * 18 end
	local attackSign = side == "Home" and -1 or 1
	local attackDirection = flat(self.PitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, attackSign)))
	attackDirection = attackDirection.Magnitude > 0.05 and attackDirection.Unit or Vector3.zAxis
	local forwardSpace = 30
	for _, opponent in opponents do
		local opponentRoot = root(opponent)
		if opponentRoot then
			local ahead = flat(opponentRoot.Position - candidateRoot.Position):Dot(attackDirection)
			if ahead > 0 then forwardSpace = math.min(forwardSpace, ahead) end
		end
	end
	local predicted = candidateRoot.Position
	for _ = 1, 2 do
		local distance = flat(predicted - passerPosition).Magnitude
		local speed = PassInterceptService.RequiredInitialSpeed(distance, charge)
		local travelTime = math.clamp(distance / math.max(speed, 1), 0.08, 1.35)
		if velocity.Magnitude < 1.25 then
			local stationaryLead = passType == "Through" and attackDirection * math.min(2.5, forwardSpace * 0.12 * math.clamp(charge + 0.25, 0.25, 1)) or Vector3.zero
			predicted = candidateRoot.Position + stationaryLead
		else
			local leadTime = travelTime * (passType == "Through" and 0.86 or 0.52)
			local lead = velocity * leadTime + acceleration * (0.5 * leadTime * leadTime)
			local maximumLead = passType == "Through" and math.clamp(4 + forwardSpace * 0.48, 5, 20) or 12
			if lead.Magnitude > maximumLead then lead = lead.Unit * maximumLead end
			predicted = candidateRoot.Position + lead
		end
	end
	local lead = predicted - candidateRoot.Position
	local passerToReceiver = flat(candidateRoot.Position - passerPosition)
	if passType ~= "Through" and passerToReceiver.Magnitude > 0.1 and lead:Dot(passerToReceiver.Unit) < -3 then
		lead -= passerToReceiver.Unit * lead:Dot(passerToReceiver.Unit)
	end
	return candidateRoot.Position + lead
end

function Service:ChooseAtPoint(passer: Model, aimPosition: Vector3, charge: number, passType: string?, passerPressure: number?): (Model?, Vector3, number, number)
	local passerRoot = root(passer)
	if not passerRoot then return nil, aimPosition, 0, 0 end
	local side = tostring(passer:GetAttribute("VTRTeam") or "Home")
	local teammates = self.Teams[side] or {}
	local opponents = self.Teams[side == "Home" and "Away" or "Home"] or {}
	local aimDirection = flat(aimPosition - passerRoot.Position)
	if aimDirection.Magnitude < 0.1 then aimDirection = flat(passerRoot.CFrame.LookVector) end
	aimDirection = aimDirection.Unit
	local passerLocal = self.PitchCFrame:PointToObjectSpace(passerRoot.Position)
	local attackSign = side == "Home" and -1 or 1
	local candidates = {}
	for _, candidate in teammates do
		if candidate ~= passer then
			local candidateRoot = root(candidate)
			if candidateRoot then
				local predicted = self:_receivePoint(passerRoot.Position, candidate, passType, charge)
				local aimGap = flat(candidateRoot.Position - aimPosition).Magnitude
				local offset = flat(predicted - passerRoot.Position)
				local distance = offset.Magnitude
				if distance > 0.5 then
					local alignment = math.clamp((aimDirection:Dot(offset.Unit) + 1) * 0.5, 0, 1)
					local openness = 1 - self:_pressure(candidate, opponents)
					local lane = self:_laneScore(passerRoot.Position, predicted, opponents)
					local candidateLocal = self.PitchCFrame:PointToObjectSpace(predicted)
					local forward = math.clamp((candidateLocal.Z - passerLocal.Z) * attackSign / 50, -0.5, 1)
					local movement = flat(candidateRoot.AssemblyLinearVelocity)
					local runAlignment = movement.Magnitude > 1 and math.clamp((movement.Unit:Dot(offset.Unit) + 1) * 0.5, 0, 1) or 0.5
					local tactical = openness * 0.45 + forward * 0.3 + runAlignment * 0.15 + alignment * 0.1
					table.insert(candidates, {Model = candidate, Point = predicted, MouseDistance = aimGap, Lane = lane, PassDistance = distance, Tactical = tactical})
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		if math.abs(a.MouseDistance - b.MouseDistance) > 0.05 then return a.MouseDistance < b.MouseDistance end
		if math.abs(a.PassDistance - b.PassDistance) > 0.25 then return a.PassDistance < b.PassDistance end
		return a.Tactical > b.Tactical
	end)
	local chosen = candidates[1]
	if chosen then return chosen.Model, chosen.Point, chosen.PassDistance, -chosen.MouseDistance end
	local fallback: Model? = nil
	local fallbackDistance = math.huge
	for _, candidate in teammates do
		if candidate ~= passer then
			local candidateRoot = root(candidate)
			local humanoid = candidate:FindFirstChildOfClass("Humanoid")
			if candidateRoot and humanoid and humanoid.Health > 0 and candidate:GetAttribute("VTRSentOff") ~= true then
				local distance = flat(candidateRoot.Position - aimPosition).Magnitude
				if distance < fallbackDistance then
					fallback = candidate
					fallbackDistance = distance
				end
			end
		end
	end
	if fallback then
		local passDistance = flat(aimPosition - passerRoot.Position).Magnitude
		return fallback, aimPosition, passDistance, -fallbackDistance
	end
	return nil, aimPosition, 0, -math.huge
end

function Service:ChooseReceiver(passer: Model, receiver: Model, charge: number, passType: string?): (Model?, Vector3, number, number)
	local passerRoot = root(passer)
	if not passerRoot or receiver == passer or receiver:GetAttribute("VTRTeam") ~= passer:GetAttribute("VTRTeam") then return nil, passerRoot and passerRoot.Position or Vector3.zero, 0, -math.huge end
	local valid = false
	for _, teammate in self.Teams[tostring(passer:GetAttribute("VTRTeam") or "Home")] or {} do if teammate == receiver then valid = true break end end
	local receiverRoot = valid and root(receiver) or nil
	if not receiverRoot then return nil, passerRoot.Position, 0, -math.huge end
	local point = self:_receivePoint(passerRoot.Position, receiver, passType, charge)
	return receiver, point, flat(point - passerRoot.Position).Magnitude, math.huge
end

function Service:Choose(passer: Model, aimDirection: Vector3, passType: string?, charge: number?, pressure: number?): (Model?, Vector3, number, number)
	local passerRoot = root(passer)
	if not passerRoot then return nil, aimDirection, 0, 0 end
	local direction = flat(aimDirection)
	if direction.Magnitude < 0.1 then direction = flat(passerRoot.CFrame.LookVector) end
	local distance = passType == "Through" and 45 or 28
	return self:ChooseAtPoint(passer, passerRoot.Position + direction.Unit * distance, charge or 0, passType, pressure)
end

return Service
