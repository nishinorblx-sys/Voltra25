--!strict
local FormationService = require(script.Parent.FormationService)
local ZonalDefendingService = require(script.Parent.ZonalDefendingService)
local AttackingShapeService = require(script.Parent.AttackingShapeService)
local TransitionService = require(script.Parent.TransitionService)
local PlayerSpacingService = require(script.Parent.PlayerSpacingService)
local SupportOptionService = require(script.Parent.SupportOptionService)

local Service = {}
Service.__index = Service

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nearestOpponent(model: Model, opponents: {Model}): Model?
	local modelRoot = root(model)
	if not modelRoot then
		return nil
	end
	local nearest: Model? = nil
	local best = math.huge
	for _, opponent in opponents do
		local opponentRoot = root(opponent)
		if opponentRoot then
			local distance = (opponentRoot.Position - modelRoot.Position).Magnitude
			if distance < best then
				best = distance
				nearest = opponent
			end
		end
	end
	return nearest
end

function Service.new(teams: any, formations: any, pitchCFrame: CFrame, width: number, length: number, ball: BasePart, possession: any, tuning: any)
	return setmetatable({Teams = teams, Formations = formations, PitchCFrame = pitchCFrame, Width = width, Length = length, Ball = ball, Possession = possession, Tuning = tuning, Half = 1}, Service)
end

function Service:SetHalf(half: number?)
	self.Half = half or 1
end

function Service:_attackSign(side: string): number
	local sign = side == "Home" and -1 or 1
	return (self.Half or 1) >= 2 and -sign or sign
end

function Service:_formationWorldPosition(formationName: string, index: number, side: string): Vector3
	local slot = FormationService.GetAssignment(formationName, index)
	local attackSign = self:_attackSign(side)
	local ownSign = -attackSign
	return self.PitchCFrame:PointToWorldSpace(Vector3.new(slot.X * self.Width * 0.46, 3, math.abs(slot.Z * self.Length * 0.48) * ownSign))
end

function Service:_pressOrder(side: string, team: {Model}): {Model}
	local candidates = {}
	local owner = self.Possession:GetOwner()
	local ownerRoot = owner and root(owner)
	local ownerHasSpace = true
	if ownerRoot and owner:GetAttribute("VTRTeam") ~= side then
		ownerHasSpace = true
		for _, model in team do
			local modelRoot = root(model)
			if modelRoot and (modelRoot.Position - ownerRoot.Position).Magnitude < 12 then
				ownerHasSpace = false
				break
			end
		end
	end
	for _, model in team do
		local assignment = FormationService.GetAssignment(model:GetAttribute("VTRFormation") or "4-3-3", model:GetAttribute("VTRIndex") or 1)
		local modelRoot = root(model)
		if assignment.Role ~= "GK" and modelRoot and model:GetAttribute("controlledByUser") ~= true then
			local distance = (modelRoot.Position - self.Ball.Position).Magnitude
			local base = self:_formationWorldPosition(model:GetAttribute("VTRFormation") or "4-3-3", model:GetAttribute("VTRIndex") or 1, side)
			local fromBase = (Vector3.new(modelRoot.Position.X,0,modelRoot.Position.Z)-Vector3.new(base.X,0,base.Z)).Magnitude
			local abandonsLine = assignment.Role == "CB" and (distance > 15 or fromBase > 20)
			local abandonsWideZone = assignment.Role == "Fullback" and (distance > 34 or fromBase > 30)
			if not abandonsLine and not abandonsWideZone then
				local score = distance + fromBase * 0.35 + (ownerHasSpace and 0 or 12)
				table.insert(candidates, {Model = model, Distance = score})
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	local result = {}
	local maxPressers = ownerHasSpace and 2 or 1
	for index = 1, math.min(maxPressers, #candidates) do
		result[index] = candidates[index].Model
	end
	return result
end

function Service:_supportRoles(team: {Model}, owner: Model?): {[Model]: string}
	local result = {}
	if not owner then
		return result
	end
	local ownerRoot = root(owner)
	local nearby = {}
	for _, model in team do
		if model ~= owner then
			local modelRoot = root(model)
			local role = FormationService.GetAssignment(model:GetAttribute("VTRFormation") or "4-3-3", model:GetAttribute("VTRIndex") or 1).Role
			if modelRoot and ownerRoot and role ~= "GK" then
				table.insert(nearby, {Model = model, Distance = (modelRoot.Position - ownerRoot.Position).Magnitude})
			end
		end
	end
	table.sort(nearby, function(a, b)
		return a.Distance < b.Distance
	end)
	if nearby[1] then
		result[nearby[1].Model] = "ShortSupport"
	end
	if nearby[2] then
		result[nearby[2].Model] = "ForwardRun"
	end
	for _, model in team do
		if not result[model] then
			local role = FormationService.GetAssignment(model:GetAttribute("VTRFormation") or "4-3-3", model:GetAttribute("VTRIndex") or 1).Role
			if role == "Winger" then result[model] = "HoldWidth"
			elseif role == "Fullback" then result[model] = "Overlap"
			elseif role == "CB" then result[model] = "BackPass"
			elseif role == "CDM" then result[model] = "Recycle"
			else result[model] = "SupportShape" end
		end
	end
	return result
end

function Service:Build(side: string, phase: string): {[Model]: any}
	local team = self.Teams[side]
	local opponents = self.Teams[side == "Home" and "Away" or "Home"]
	local formationName = self.Formations[side] or "4-3-3"
	local owner = self.Possession:GetOwner()
	local pressOrder = self:_pressOrder(side, team)
	local supportOwner = owner and owner:GetAttribute("VTRTeam") == side and owner or nil
	local supportRoles = SupportOptionService.Assign(team, supportOwner, formationName, self.PitchCFrame, self.Tuning.Positioning, opponents)
	local assignments = {}
	local context = {
		Side = side, PitchCFrame = self.PitchCFrame, Width = self.Width, Length = self.Length,
		Ball = self.Ball, Possession = self.Possession, Opponents = opponents, Compactness = 0.55 + self.Tuning.Positioning * 0.4,
		Half = self.Half, AttackSign = self:_attackSign(side),
	}
	for index, model in team do
		local slot = FormationService.GetAssignment(formationName, index)
		local base = self:_formationWorldPosition(formationName, index, side)
		local defending = phase == "OutOfPossession" or phase == "TransitionDefense"
		local press = defending and (model == pressOrder[1] and "Primary" or model == pressOrder[2] and "Secondary" or model == pressOrder[3] and "LaneBlocker" or "Hold") or "Hold"
		local assignment = {
			Model = model, BasePosition = base, Zone = slot.Name, Role = slot.Role, Phase = phase,
			PressAssignment = press, MarkTarget = nearestOpponent(model, opponents), SupportTarget = owner,
			SupportRole = supportRoles[model], Urgency = press == "Primary" and 1 or press == "Secondary" and 0.76 or phase == "TransitionDefense" and 0.68 or 0.42,
		}
		if phase == "InPossession" or phase == "TransitionAttack" then
			local runUrgency = {ThroughRun = 0.94, WideRun = 0.76, Overlap = 0.84, DiagonalSupport = 0.76, ShortSupport = 0.7, FarPostRun = 0.86, BoxRun = 0.9, RecycleOption = 0.5, HoldWidth = 0.48}
			assignment.Urgency = (runUrgency[assignment.SupportRole] or 0.48) * (0.72 + self.Tuning.Positioning * 0.28)
		end
		local target: Vector3
		local behavior: string
		if phase == "InPossession" or phase == "TransitionAttack" then
			target, behavior = AttackingShapeService.Calculate(context, assignment)
		else
			target, behavior = ZonalDefendingService.Calculate(context, assignment)
		end
		target, behavior = TransitionService.Apply(context, assignment, target)
		assignment.MovementTarget = target
		assignment.Behavior = behavior
		assignments[model] = assignment
	end
	local assignedTargets = {}
	local ballLocal = self.PitchCFrame:PointToObjectSpace(self.Ball.Position)
	local attackSign = self:_attackSign(side)
	local finalThird = ballLocal.Z * attackSign > self.Length * 0.2
	local attacking = phase == "InPossession" or phase == "TransitionAttack"
	local spacing = attacking and (finalThird and 12 or 22) or 20
	local supportRoot = supportOwner and root(supportOwner)
	local nearOptions = 0
	for _, model in team do
		local assignment = assignments[model]
		if attacking and supportRoot and model ~= supportOwner then
			local offset = assignment.MovementTarget - supportRoot.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			if flatOffset.Magnitude < 25 then
				local closeRole = assignment.SupportRole == "ShortSupport" or assignment.SupportRole == "DiagonalSupport"
				if closeRole then nearOptions += 1 end
				if (not closeRole or nearOptions > 2) and flatOffset.Magnitude > 0.1 then assignment.MovementTarget = supportRoot.Position + flatOffset.Unit * 29 end
			end
		end
		local roleSpacing = spacing
		if not finalThird then
			if assignment.Role == "CM" or assignment.Role == "CAM" or assignment.Role == "CDM" then roleSpacing = 24 + self.Tuning.Positioning * 8
			elseif assignment.Role == "ST" or assignment.Role == "Winger" then roleSpacing = attacking and (26 + self.Tuning.Positioning * 10) or (24 + self.Tuning.Positioning * 5)
			elseif assignment.Role == "CB" or assignment.Role == "Fullback" then roleSpacing = 18 + self.Tuning.Positioning * 10 end
		end
		assignment.MovementTarget = PlayerSpacingService.Apply(model, assignment.MovementTarget, assignedTargets, roleSpacing)
		local localTarget = self.PitchCFrame:PointToObjectSpace(assignment.MovementTarget)
		if attacking and (assignment.Role=="Winger" or assignment.Role=="Fullback") then
			local width=tonumber(self.Tuning.AttackingWidth) or .5
			local minimumWide=self.Width*(assignment.Role=="Winger" and .34 or .29)
			local sideSign=localTarget.X>=0 and 1 or -1
			local wideX=sideSign*math.max(math.abs(localTarget.X),minimumWide)
			localTarget=Vector3.new(localTarget.X+(wideX-localTarget.X)*math.clamp(width,.15,1),localTarget.Y,localTarget.Z)
		end
		assignment.MovementTarget = self.PitchCFrame:PointToWorldSpace(Vector3.new(math.clamp(localTarget.X, -self.Width * 0.47, self.Width * 0.47), 3, math.clamp(localTarget.Z, -self.Length * 0.47, self.Length * 0.47)))
		assignedTargets[model] = assignment.MovementTarget
		model:SetAttribute("TacticalRole", assignment.Role)
		model:SetAttribute("TacticalZone", assignment.Zone)
		model:SetAttribute("TeamPhase", assignment.Phase)
		model:SetAttribute("BaseFormationPosition", assignment.BasePosition)
		model:SetAttribute("PressAssignment", assignment.PressAssignment)
		model:SetAttribute("SupportRole", assignment.SupportRole or "None")
		model:SetAttribute("AttackAssignment", assignment.SupportRole or "None")
		model:SetAttribute("PassingLaneScore", assignment.PassingLaneScore or 0)
		model:SetAttribute("SupportTarget", assignment.SupportTarget and assignment.SupportTarget.Name or "")
		model:SetAttribute("Urgency", assignment.Urgency)
		model:SetAttribute("MarkTarget", assignment.MarkTarget and assignment.MarkTarget.Name or "")
		model:SetAttribute("MovementTarget", assignment.MovementTarget)
		local laneLocal = self.PitchCFrame:PointToObjectSpace(assignment.MovementTarget)
		local laneRatio = laneLocal.X / math.max(self.Width * 0.5, 1)
		model:SetAttribute("AttackingLane", laneRatio < -0.62 and "LeftWide" or laneRatio < -0.18 and "LeftHalfSpace" or laneRatio <= 0.18 and "Center" or laneRatio <= 0.62 and "RightHalfSpace" or "RightWide")
	end
	return assignments
end

return Service
