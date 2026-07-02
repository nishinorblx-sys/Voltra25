--!strict
local VTRGoalPassThrough = require(script.Parent:WaitForChild("GoalShotPassThroughService"))
local function vtrXGPercent(value)
	local n = tonumber(value) or 0
	if n <= 1 then
		n = n * 100
	end
	if n < 0 then
		return 0
	end
	if n > 100 then
		return 100
	end
	return n
end

local function vtrXGIsGoal(threshold, rolled)
	return vtrXGPercent(rolled) <= vtrXGPercent(threshold)
end

local Service = {}
Service.__index = Service

function Service.new(remote: RemoteEvent, stats: any, onRestart: any, pitchCFrame: CFrame?, width: number?, length: number?)
	return setmetatable({
		Remote = remote,
		Stats = stats,
		OnRestart = onRestart,
		Fouls = {},
		Yellows = {},
		Random = Random.new(),
		PitchCFrame = pitchCFrame,
		Width = width or 0,
		Length = length or 0,
		Half = 1,
	}, Service)
end

function Service:SetHalf(half: number?)
	self.Half = half or 1
end

function Service:_penaltyBoxOwner(location: Vector3): string?
	if not self.PitchCFrame or self.Width <= 0 or self.Length <= 0 then return nil end
	local localPoint = self.PitchCFrame:PointToObjectSpace(location)
	local boxHalfWidth = math.max(46, self.Width * .30)
	local boxDepth = math.max(72, self.Length * .18)
	if math.abs(localPoint.X) > boxHalfWidth then return nil end
	local inPositiveBox = localPoint.Z >= self.Length * .5 - boxDepth
	local inNegativeBox = localPoint.Z <= -self.Length * .5 + boxDepth
	if not inPositiveBox and not inNegativeBox then return nil end
	local positiveOwner = (self.Half or 1) >= 2 and "Away" or "Home"
	local negativeOwner = (self.Half or 1) >= 2 and "Home" or "Away"
	return inPositiveBox and positiveOwner or negativeOwner
end

function Service:IsPenaltyFoul(offender: Model, victim: Model, location: Vector3): boolean
	local offenderTeam = tostring(offender:GetAttribute("VTRTeam") or "Home")
	local victimTeam = tostring(victim:GetAttribute("VTRTeam") or "")
	if victimTeam == "" or victimTeam == offenderTeam then return false end
	local boxOwner = self:_penaltyBoxOwner(location)
	return boxOwner ~= nil and boxOwner == offenderTeam
end

function Service:CallFoul(offender: Model, victim: Model, kind: string, location: Vector3, forceCard: boolean?, redChance: number?): (boolean, string?)
	local team = tostring(offender:GetAttribute("VTRTeam") or "Home")
	local victimTeam = tostring(victim:GetAttribute("VTRTeam") or "")
	local restartTeam = (victimTeam == "Home" or victimTeam == "Away") and victimTeam or (team == "Home" and "Away" or "Home")
	self.Fouls[offender] = (self.Fouls[offender] or 0) + 1
	self.Stats:Add(team, "Fouls")
	self.Stats:Event(offender, "FoulCommitted")
	self.Stats:Event(victim, "FoulWon")

	local card: string? = nil
	local secondYellow = false
	local cardChance = math.clamp((self.Fouls[offender] or 1) * .1, 0, 1)
	if forceCard or self.Random:NextNumber() < cardChance then
		if redChance and self.Random:NextNumber() < redChance then
			card = "Red"
		else
			self.Yellows[offender] = (self.Yellows[offender] or 0) + 1
			secondYellow = self.Yellows[offender] >= 2
			card = secondYellow and "Red" or "Yellow"
		end
		if card == "Red" then
			self.Stats:Add(team, "RedCards")
			self.Stats:Event(offender, "RedCard")
			offender:SetAttribute("VTRRedCard", true)
			offender:SetAttribute("VTRSentOff", true)
			offender:SetAttribute("VTRForceIdle", true)
			task.delay(secondYellow and 2.2 or 1.2, function()
				if not offender.Parent then return end
				local root = offender:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = offender:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 0
					humanoid:Move(Vector3.zero, false)
				end
				if root then
					root.Anchored = true
					offender:PivotTo(CFrame.new(0, -600, 0))
				end
			end)
		else
			self.Stats:Add(team, "YellowCards")
			self.Stats:Event(offender, "YellowCard")
			offender:SetAttribute("VTRYellowCard", true)
		end
	end

	local restartKind = self:IsPenaltyFoul(offender, victim, location) and "Penalty" or "FreeKick"
	self.Remote:FireAllClients({
		Type = "Foul",
		Actor = offender,
		Victim = victim,
		FoulKind = kind,
		Card = card,
		SecondYellow = secondYellow,
		Location = location,
		RestartKind = restartKind,
		RestartTeam = restartTeam,
		FouledPlayerName = tostring(victim:GetAttribute("DisplayName") or victim.Name),
		OffenderName = tostring(offender:GetAttribute("DisplayName") or offender.Name),
		FouledPlayer = victim,
	})
	task.defer(self.OnRestart, restartTeam, location, restartKind, victim)
	return true, card
end

function Service.Enforce(models: {Model}, pitchCFrame: CFrame, width: number, length: number)
	for _, model in models do
		if model:GetAttribute("VTRSentOff") == true then continue end
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local p = pitchCFrame:PointToObjectSpace(root.Position)
			if math.abs(p.X) > width / 2 + 8 or math.abs(p.Z) > length / 2 + 12 or p.Y < -8 then
				local safe = Vector3.new(math.clamp(p.X, -width / 2 + 3, width / 2 - 3), 3, math.clamp(p.Z, -length / 2 + 3, length / 2 - 3))
				model:PivotTo(CFrame.new(pitchCFrame:PointToWorldSpace(safe)))
			end
		end
	end
end

return Service
