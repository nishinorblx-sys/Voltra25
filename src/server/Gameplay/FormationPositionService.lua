--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spacing = require(ReplicatedStorage.VTR.Shared.SetPieceSpacingConfig)

local Service = {}

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isKeeper(model: Model): boolean
	return tostring(model:GetAttribute("position") or "") == "GK"
end

local function move(model: Model, position: Vector3, lookAt: Vector3)
	model:PivotTo(CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local modelRoot = root(model)
	if humanoid then humanoid:Move(Vector3.zero, false) end
	if modelRoot then modelRoot.AssemblyLinearVelocity = Vector3.zero; modelRoot.AssemblyAngularVelocity = Vector3.zero end
end

local function world(pitchCFrame: CFrame, x: number, z: number): Vector3
	return pitchCFrame:PointToWorldSpace(Vector3.new(x, 3, z))
end

function Service.Kickoff(teams: any, formation: any, pitchCFrame: CFrame): Model
	for _, side in {"Home", "Away"} do
		local sign = side == "Home" and 1 or -1
		local sideFormation = formation[side] or formation
		for index, model in teams[side] do
			local point = sideFormation[index] or Vector2.zero
			local position = world(pitchCFrame, point.X, point.Y * sign)
			move(model, position, world(pitchCFrame, point.X, point.Y * sign - sign * 10))
		end
	end
	return teams.Home[10] or teams.Home[1]
end

function Service.ThrowIn(teams: any, restartTeam: string, location: Vector3, pitchCFrame: CFrame, width: number, length: number): Model
	local localExit = pitchCFrame:PointToObjectSpace(location)
	local touchSign = localExit.X >= 0 and 1 or -1
	local x = touchSign * (width / 2 - 1.2)
	local z = math.clamp(localExit.Z, -length / 2 + 8, length / 2 - 8)
	local spot = world(pitchCFrame, x, z)
	local taker = nil
	local nearest = math.huge
	for _, model in teams[restartTeam] do
		local modelRoot = root(model)
		if modelRoot and not isKeeper(model) and (modelRoot.Position - spot).Magnitude < nearest then
			nearest = (modelRoot.Position - spot).Magnitude
			taker = model
		end
	end
	taker = taker or teams[restartTeam][2] or teams[restartTeam][1]
	move(taker, spot, world(pitchCFrame, 0, z))
	local opponent = restartTeam == "Home" and "Away" or "Home"
	local options = {}
	for _, model in teams[restartTeam] do
		if model ~= taker and not isKeeper(model) and root(model) then
			table.insert(options, model)
		end
	end
	table.sort(options, function(a, b) return ((root(a) :: BasePart).Position - spot).Magnitude < ((root(b) :: BasePart).Position - spot).Magnitude end)
	local markers = {}
	for _, model in teams[opponent] do
		if not isKeeper(model) and root(model) then
			table.insert(markers, model)
		end
	end
	for index = 1, math.min(2, #options) do
		local option = options[index]
		local optionPosition = world(pitchCFrame, x - touchSign * (index == 1 and 13 or index == 2 and 20 or 26), z + (index == 1 and 0 or index == 2 and -17 or index == 3 and 18 or 36))
		move(option, optionPosition, spot)
		local marker = markers[index + 2] or markers[index]
		if marker then
			move(marker, world(pitchCFrame, x - touchSign * (index == 1 and 18 or index == 2 and 25 or 30), z + (index == 1 and 2 or index == 2 and -14 or index == 3 and 15 or 32)), optionPosition)
		end
	end
	local protected: {[Model]: boolean} = {[taker] = true}
	for _, side in {"Home", "Away"} do
		for _, model in teams[side] do
			if isKeeper(model) then
				protected[model] = true
				model:SetAttribute("VTRThrowInKeeperProtected", true)
			end
		end
	end
	for index = 1, math.min(2, #options) do
		protected[options[index]] = true
		local marker = markers[index + 2] or markers[index]
		if marker then
			protected[marker] = true
		end
	end
	for _, side in {restartTeam, opponent} do
		local ownSign = side == "Home" and 1 or -1
		for index, model in teams[side] do
			if protected[model] or isKeeper(model) then continue end
			local lane = ((index - 1) % 5 - 2) * width * 0.16
			local depth = math.clamp(z + ownSign * (46 + math.floor((index - 1) / 4) * 28), -length / 2 + 28, length / 2 - 28)
			local fromRestart = Vector2.new(lane - x, depth - z)
			if fromRestart.Magnitude < Spacing.ThrowIn.Radius + 4 then
				local direction = fromRestart.Magnitude > 0.1 and fromRestart.Unit or Vector2.new(-touchSign, 0)
				lane, depth = x + direction.X * (Spacing.ThrowIn.Radius + 4), z + direction.Y * (Spacing.ThrowIn.Radius + 4)
			end
			move(model, world(pitchCFrame, lane, depth), spot)
		end
	end
	return taker
end

function Service.GoalKick(teams: any, formation: any, restartTeam: string, location: Vector3, pitchCFrame: CFrame, width: number, length: number): Model
	local localExit = pitchCFrame:PointToObjectSpace(location)
	local goalSign = localExit.Z >= 0 and 1 or -1
	local ballX = math.clamp(localExit.X, -8, 8)
	local ballZ = goalSign * (length / 2 - 8)
	local spot = world(pitchCFrame, ballX, ballZ + goalSign * 2.4)
	local ballSpot = world(pitchCFrame, ballX, ballZ)
	local goalkeeper = teams[restartTeam][1]
	move(goalkeeper, spot, world(pitchCFrame, 0, 0))
	local restartFormation = formation and (formation[restartTeam] or formation) or {}
	for index = 2, #teams[restartTeam] do
		local point = restartFormation[index] or Vector2.new(((index - 1) % 5 - 2) * width * 0.16, 0)
		local targetZ: number
		if index >= 6 then
			targetZ = goalSign * math.clamp(math.abs(point.Y) * 0.14 + (index >= 9 and 18 or 8), 12, 58)
		else
			targetZ = goalSign * math.clamp(math.abs(point.Y), 84, length / 2 - 150)
		end
		move(teams[restartTeam][index], world(pitchCFrame, point.X, targetZ), ballSpot)
	end
	local opponent = restartTeam == "Home" and "Away" or "Home"
	local opponentFormation = formation and (formation[opponent] or formation) or {}
	for index, model in teams[opponent] do
		local point = opponentFormation[index] or Vector2.new(((index - 1) % 5 - 2) * width * 0.16, 0)
		local normalZ = -goalSign * math.abs(point.Y)
		local targetZ = index >= 6 and -goalSign * math.clamp(math.abs(point.Y) * 0.12 + (index >= 9 and 28 or 14), 18, 70) or math.clamp(normalZ, -length / 2 + 150, length / 2 - 150)
		move(model, world(pitchCFrame, point.X, targetZ), ballSpot)
	end
	return goalkeeper
end

function Service.Corner(teams: any, restartTeam: string, location: Vector3, pitchCFrame: CFrame, width: number, length: number): Model
	local localExit = pitchCFrame:PointToObjectSpace(location)
	local cornerX = localExit.X >= 0 and width / 2 - 1 or -width / 2 + 1
	local cornerZ = localExit.Z >= 0 and length / 2 - 1 or -length / 2 + 1
	local goalSign = cornerZ >= 0 and 1 or -1
	local spot = world(pitchCFrame, cornerX, cornerZ)
	local taker = teams[restartTeam][9] or teams[restartTeam][10] or teams[restartTeam][2]
	move(taker, spot, world(pitchCFrame, 0, cornerZ * 0.82))
	local attackers = {}
	for _, model in teams[restartTeam] do if model ~= taker then table.insert(attackers, model) end end
	for index, model in attackers do
		if index <= Spacing.Corner.AttackersInBox then
			move(model, world(pitchCFrame, (index - 3) * 7, cornerZ - goalSign * (8 + (index % 2) * 7)), spot)
		elseif index <= Spacing.Corner.AttackersInBox + Spacing.Corner.EdgePlayers then
			move(model, world(pitchCFrame, (index % 2 == 0 and -1 or 1) * 20, cornerZ - goalSign * 28), spot)
		else
			move(model, world(pitchCFrame, (index - 8) * 18, cornerZ - goalSign * 48), spot)
		end
	end
	local defending = restartTeam == "Home" and "Away" or "Home"
	for index, model in teams[defending] do
		if index <= Spacing.Corner.DefendersInBox then
			move(model, world(pitchCFrame, (index - 3.5) * 6, cornerZ - goalSign * (6 + (index % 2) * 6)), spot)
		elseif index <= Spacing.Corner.DefendersInBox + 1 then
			move(model, world(pitchCFrame, 0, cornerZ - goalSign * 31), spot)
		else
			move(model, world(pitchCFrame, (index - 8) * 17, cornerZ - goalSign * 52), spot)
		end
	end
	return taker
end

return Service
