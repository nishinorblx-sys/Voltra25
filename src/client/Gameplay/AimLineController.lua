--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FreeKickTrajectory = require(ReplicatedStorage.VTR.Shared.FreeKickTrajectory)

local Controller = {}
Controller.__index = Controller

local function node(name: string): (Part, Attachment)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.15
	part.Parent = workspace
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	return part, attachment
end

function Controller.new(teams: any, ball: BasePart)
	local startPart, startAttachment = node("VTRAimStart")
	local endPart, endAttachment = node("VTRAimEnd")
	local beam = Instance.new("Beam")
	beam.Name = "VTRAimLine"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Color = ColorSequence.new(Color3.fromHex("B7FF1A"))
	beam.LightEmission = 0.75
	beam.FaceCamera = true
	beam.Width0 = 0.075
	beam.Width1 = 0.04
	beam.Transparency = NumberSequence.new(0.45)
	beam.Enabled = false
	beam.Parent = startPart
	local marker = Instance.new("Part")
	marker.Name = "VTROpenSpaceAim"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.045, 0.82, 0.82)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromHex("B7FF1A")
	marker.Transparency = 0.3
	marker.Parent = workspace
	local trajectoryParts = {}
	for index = 1, 14 do
		local dot = Instance.new("Part")
		dot.Name = "VTRFreeKickTrajectory_" .. index
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * (index == 14 and 0.42 or 0.26)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanTouch = false
		dot.CanQuery = false
		dot.CastShadow = false
		dot.Material = Enum.Material.Neon
		dot.Color = Color3.fromHex("91F7FF")
		dot.Transparency = 1
		dot.Parent = workspace
		trajectoryParts[index] = dot
	end
	return setmetatable({Teams = teams or {}, Ball = ball, StartPart = startPart, EndPart = endPart, Beam = beam, Marker = marker, TrajectoryParts = trajectoryParts, MatchActive = false, SmoothEnd = endPart.Position}, Controller)
end

function Controller:SetActive(model: Model?)
	self.Active = model
end

function Controller:SetMatchActive(active: boolean)
	self.MatchActive = active
	if not active then
		self.Beam.Enabled = false
		self.Marker.Transparency = 1
		for _, dot in self.TrajectoryParts do
			dot.Transparency = 1
		end
	end
end

function Controller:_updateFreeKickTrajectory(startPosition: Vector3, target: Vector3, charge: number, enabled: boolean, curve: number?, lift: number?)
	if not enabled then
		for _, dot in self.TrajectoryParts do dot.Transparency = 1 end
		return
	end
	local flatDistance = Vector3.new(target.X - startPosition.X, 0, target.Z - startPosition.Z).Magnitude
	local solved = FreeKickTrajectory.Compute(startPosition, target, curve, lift)
	for index, dot in self.TrajectoryParts do
		local alpha = index / #self.TrajectoryParts
		dot.Position = FreeKickTrajectory.PointAt(startPosition, solved, alpha) + Vector3.new(0, 0.35, 0)
		dot.Transparency = math.clamp(0.18 + alpha * 0.32, 0.18, 0.62)
		dot.Size = Vector3.one * (index == #self.TrajectoryParts and 0.46 or 0.22 + alpha * 0.06)
	end
end

function Controller:_nearestTeammate(point: Vector3, charge: number): Model?
	if not self.Active then
		return nil
	end
	local side = tostring(self.Active:GetAttribute("VTRTeam") or "Home")
	local activeRoot = self.Active:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not activeRoot then return nil end
	local candidates = {}
	for _, teammate in self.Teams[side] or {} do
		if teammate ~= self.Active then
			local teammateRoot = teammate:FindFirstChild("HumanoidRootPart") :: BasePart?
			if teammateRoot then
				local passDistance = (teammateRoot.Position - activeRoot.Position).Magnitude
				local aimGap = (teammateRoot.Position - point).Magnitude
				if passDistance > 0.5 then
					table.insert(candidates, {Model = teammate, MouseDistance = aimGap, PassDistance = passDistance})
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		if math.abs(a.MouseDistance - b.MouseDistance) > 0.05 then return a.MouseDistance < b.MouseDistance end
		return a.PassDistance < b.PassDistance
	end)
	self.LastTargetBlocked = false
	return candidates[1] and candidates[1].Model or nil
end

function Controller:IsTargetFallback(): boolean
	return self.LastTargetBlocked == true
end

function Controller:Update(dt: number, aimPosition: Vector3, hasBall: boolean, chargeKind: string, charge: number, aimingAtGoal: boolean, freeKickCurve: number?, freeKickLift: number?, setPieceMode: string?, shotOnTarget:boolean?): Model?
	if not self.MatchActive or not self.Active or not hasBall then
		self.Beam.Enabled = false
		self.Marker.Transparency = 1
		return nil
	end
	local activeRoot = self.Active:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not activeRoot then
		return nil
	end
	-- The beam communicates raw mouse intent; the separate receiver marker
	-- communicates the teammate that RMB will actually target.
	local teammate = self:_nearestTeammate(aimPosition, charge)
	local target = aimPosition
	local lineStart = activeRoot.Position
	self.SmoothEnd = target
	self.StartPart.Position = lineStart
	self.EndPart.Position = target
	local distance = (self.EndPart.Position - self.StartPart.Position).Magnitude
	local idleTransparency = chargeKind == "" and 0.62 or 0.2
	local isShotLine = chargeKind == "Shot" or setPieceMode == "Penalty" or setPieceMode == "PenaltyDefense" or setPieceMode == "DirectShotFreeKick" or shotOnTarget ~= nil
	if isShotLine then
		local color = shotOnTarget == false and Color3.fromHex("FF384F") or Color3.fromHex("32FF6A")
		self.Beam.Color = ColorSequence.new(color)
		self.Marker.Color = color
		self.Beam.Width0 = shotOnTarget == false and 0.3 or 0.34
		self.Beam.Width1 = shotOnTarget == false and 0.22 or 0.25
	else
		self.Beam.Color = ColorSequence.new(Color3.fromHex("B7FF1A"))
		self.Marker.Color = Color3.fromHex("B7FF1A")
		self.Beam.Width0 = chargeKind == "" and 0.12 or 0.18
		self.Beam.Width1 = chargeKind == "" and 0.085 or 0.13
	end
	self.Beam.Transparency = NumberSequence.new(math.clamp(idleTransparency + distance / 450, 0.18, 0.76))
	self.Beam.Enabled = true
	self.Marker.Transparency = (aimingAtGoal or isShotLine) and 1 or 0.3
	self.Marker.CFrame = CFrame.new(target) * CFrame.Angles(0, 0, math.pi / 2)
	local setPieceReady = tostring(self.Ball:GetAttribute("VTRSetPieceReady") or "")
	local isDirectShotPreview = setPieceMode == "DirectShotFreeKick" or (setPieceReady == "FreeKick" and chargeKind == "Shot")
	self:_updateFreeKickTrajectory(self.Ball.Position, target, charge, isDirectShotPreview, freeKickCurve, freeKickLift)
	return teammate
end

function Controller:Destroy()
	self.StartPart:Destroy()
	self.EndPart:Destroy()
	self.Marker:Destroy()
	for _, dot in self.TrajectoryParts do dot:Destroy() end
end

return Controller
