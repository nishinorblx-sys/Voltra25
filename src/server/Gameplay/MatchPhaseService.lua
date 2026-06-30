--!strict
local Service = {}
Service.__index = Service

function Service.new(possession: any, ball: BasePart, pitchCFrame: CFrame, length: number)
	return setmetatable({Possession = possession, Ball = ball, PitchCFrame = pitchCFrame, Length = length, PreviousOwnerTeam = nil, TransitionUntil = 0, ExternalPhase = nil, LooseSince = nil}, Service)
end

function Service:SetExternalPhase(phase: string?)
	self.ExternalPhase = phase
end

function Service:Update(): any
	if self.ExternalPhase then
		return {Home = self.ExternalPhase, Away = self.ExternalPhase, TurnoverAt = self.TurnoverAt}
	end
	local owner = self.Possession:GetOwner()
	local ownerTeam = owner and tostring(owner:GetAttribute("VTRTeam")) or nil
	local now = os.clock()
	local ballLocal = self.PitchCFrame:PointToObjectSpace(self.Ball.Position)
	local ballSpeed = self.Ball.AssemblyLinearVelocity.Magnitude
	local zone = math.abs(ballLocal.Z) < self.Length * 0.18 and "MiddleThird" or math.abs(ballLocal.Z) < self.Length * 0.38 and "WideThird" or "FinalThird"
	if ownerTeam then
		self.LooseSince = nil
	elseif self.PreviousOwnerTeam then
		self.LooseSince = self.LooseSince or now
		if now - self.LooseSince < (ballSpeed > 20 and 1.25 or 0.7) then
			ownerTeam = self.PreviousOwnerTeam
		end
	end
	if ownerTeam and self.PreviousOwnerTeam and ownerTeam ~= self.PreviousOwnerTeam then
		self.TransitionUntil = now + 2
		self.TurnoverAt = now
	end
	if ownerTeam then
		self.PreviousOwnerTeam = ownerTeam
	end
	if now < self.TransitionUntil and ownerTeam then
		return {
			Home = ownerTeam == "Home" and "TransitionAttack" or "TransitionDefense",
			Away = ownerTeam == "Away" and "TransitionAttack" or "TransitionDefense",
			OwnerTeam = ownerTeam,
			TurnoverAt = self.TurnoverAt, BallZone = zone, BallSpeed = ballSpeed,
		}
	end
	return {
		Home = ownerTeam == "Home" and "InPossession" or "OutOfPossession",
		Away = ownerTeam == "Away" and "InPossession" or "OutOfPossession",
		OwnerTeam = ownerTeam,
		TurnoverAt = self.TurnoverAt, BallZone = zone, BallSpeed = ballSpeed,
	}
end

return Service
