--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}
Service.__index = Service

function Service.new()
	return setmetatable({LastOwnerSide = nil, ChangedAt = 0, Phases = {Home = "LooseBall", Away = "LooseBall"}}, Service)
end

local function possessionPhase(ballPitch: Vector3): string
	if ballPitch.Z < 247 then
		return "OwnPossession_BuildUp"
	elseif ballPitch.Z < 495 then
		return "OwnPossession_Middle"
	elseif (ballPitch.X < 90 or ballPitch.X > 334) then
		return "OwnPossession_WideAttack"
	end
	return "OwnPossession_FinalThird"
end

local function defendingPhase(opponentBallPitch: Vector3): string
	if opponentBallPitch.Z < 247 then
		return "OpponentPossession_HighPress"
	elseif opponentBallPitch.Z < 495 then
		return "OpponentPossession_MidBlock"
	elseif opponentBallPitch.Z < 610 then
		return "OpponentPossession_LowBlock"
	end
	return "OpponentPossession_BoxDefense"
end

function Service:Update(context: any, live: boolean): {[string]: string}
	local now = context.Now or os.clock()
	if not live then
		self.Phases.Home = "SetPiece"
		self.Phases.Away = "SetPiece"
		return self.Phases
	end

	local ownerSide = context.OwnerSide
	if ownerSide ~= self.LastOwnerSide then
		self.LastOwnerSide = ownerSide
		self.ChangedAt = now
	end

	for _, side in ipairs({"Home", "Away"}) do
		if context.LooseBall then
			self.Phases[side] = "LooseBall"
		elseif ownerSide == side then
			if now - self.ChangedAt <= 3 then
				self.Phases[side] = "Transition_JustWonBall"
			else
				self.Phases[side] = possessionPhase(context.BallTeam[side])
			end
		elseif ownerSide ~= nil then
			if now - self.ChangedAt <= 3 then
				self.Phases[side] = "Transition_JustLostBall"
			else
				local opponentSide = side == "Home" and "Away" or "Home"
				self.Phases[side] = defendingPhase(context.BallTeam[opponentSide])
			end
		else
			self.Phases[side] = "LooseBall"
		end
	end
	return self.Phases
end

function Service:Get(side: string): string
	return self.Phases[side] or "LooseBall"
end

return Service
