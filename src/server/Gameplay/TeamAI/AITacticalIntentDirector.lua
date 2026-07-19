--!strict

local Director = {}
Director.__index = Director

local PitchConfig = require(script.Parent.Parent.PitchConfig)

local MIN_COMMIT = .55
local HIGH_PRESS_COMMIT = 1.05

function Director.new(): any
	return setmetatable({State = {Home = nil, Away = nil}, ResetPress = {Home = nil, Away = nil}}, Director)
end

local function ownerRole(context: any): string
	local owner = context.Owner
	local info = owner and context.Players and context.Players[owner]
	return tostring(info and info.Role or "")
end

local function resetReceiver(context: any, side: string, targetPitch: Vector3?): any?
	if typeof(targetPitch) ~= "Vector3" then
		return nil
	end
	local opponentSide = side == "Home" and "Away" or "Home"
	local best = nil
	local bestDistance = math.huge
	for _, info in ipairs(((context.Teams or {})[opponentSide] or {}).List or {}) do
		if info.Root then
			local pitch = PitchConfig.WorldToTeamPitchPosition(info.World, side, context.Options)
			local roleBonus = (info.Role == "GK" or info.Role == "CB") and -24 or info.Role == "Fullback" and -10 or 0
			local distance = PitchConfig.GetDistanceStuds(pitch, targetPitch)
			local score = distance + roleBonus
			if score < bestDistance then
				best = {Info = info, Pitch = pitch, World = info.World}
				bestDistance = score
			end
		end
	end
	return best
end

local function enoughBehindBall(context: any, side: string, ball: Vector3): boolean
	local count = 0
	for _, info in ipairs(((context.Teams or {})[side] or {}).List or {}) do
		if info.Root and info.Pitch.Z <= ball.Z - 16 then
			count += 1
		end
	end
	return count >= 5
end

local function resetPressCandidate(context: any, side: string, style: any, previous: any?): any?
	local now = context.Now or os.clock()
	local ball = context.BallTeam[side]
	local press = style and style:Ratio("PressingIntensity") or .5
	local depth = style and style:Ratio("DefensiveDepth") or .5
	if depth < .34 or press < .38 then
		return nil
	end
	local targetPitch = context.PassTargetTeam and context.PassTargetTeam[side]
	if context.PassInFlight == true and typeof(targetPitch) == "Vector3" and targetPitch.Z < (context.BallTeam[side].Z - 80) and context.BallTeam[side].Z >= 420 then
		return nil
	end
	local receiver = resetReceiver(context, side, targetPitch)
	local receiverRole = tostring(receiver and receiver.Info and receiver.Info.Role or "")
	local backwardPass = context.PassInFlight == true and typeof(targetPitch) == "Vector3" and targetPitch.Z >= ball.Z + 18 and targetPitch.Z >= 500
	local backwardToBuildup = backwardPass and (receiverRole == "GK" or receiverRole == "CB" or receiverRole == "Fullback" or receiver == nil)
	local carrierRole = ownerRole(context)
	local carrierInBuildup = context.OwnerSide ~= side and ball.Z >= 500 and (carrierRole == "GK" or carrierRole == "CB" or carrierRole == "Fullback")
	local locked = previous and now <= (tonumber(previous.ExpiresAt) or 0) and ball.Z >= 495
	local confidence = (backwardToBuildup and .78 or 0) + (carrierInBuildup and .2 or 0) + (enoughBehindBall(context, side, ball) and .12 or 0) + press * .18 + depth * .1
	if not backwardToBuildup and not carrierInBuildup and not locked then
		return nil
	end
	if confidence < .62 and not locked then
		return nil
	end
	local receiverName = receiver and receiver.Info and receiver.Info.Model and receiver.Info.Model.Name or ""
	return {
		StartedAt = previous and previous.StartedAt or now,
		ExpiresAt = now + math.clamp(1.55 + press * 1.35 + depth * .65, 1.5, 3),
		Receiver = receiver and receiver.Info and receiver.Info.Model or nil,
		ReceiverName = receiverName,
		TargetPitch = typeof(targetPitch) == "Vector3" and targetPitch or ball,
		PassDirection = backwardPass and "Backward" or "BuildupCarrier",
		Confidence = math.clamp(confidence, 0, 1),
		State = locked and "LockedAtHalfway" or "ResetPressDetected",
	}
end

local function possessionIntent(context: any, side: string, style: any, spatial: any): string
	local ball = context.BallTeam[side]
	local stage = ball.Z < 185 and "BuildOut" or ball.Z < 360 and "Consolidate" or ball.Z < 560 and "Progress" or "CreateChance"
	local pressure = context.DefensivePress and context.DefensivePress[side == "Home" and "Away" or "Home"]
	local direct = style and style:Ratio("PassingDirectness") or .5
	local counter = style and style:Ratio("CounterAttackFrequency") or .45
	local width = style and style:Ratio("AttackingWidth") or .5
	if context.OwnerSide == side and context.Now - (tonumber(context.Owner and context.Owner:GetAttribute("VTRReceivedAt")) or context.Now) < 2.8 and counter > .72 then
		return "CounterAttack"
	end
	if ball.Z < 235 and pressure and pressure.Active then
		return "EscapePressure"
	end
	if stage == "BuildOut" and direct < .68 then
		return pressure and pressure.Active and "AttractPress" or "BuildOut"
	end
	if stage == "Progress" and width > .7 then
		return "OverloadWide"
	end
	if stage == "Progress" and direct > .72 then
		return "DirectRelease"
	end
	if stage == "CreateChance" and spatial and spatial:BestCell(side, 540, true) then
		return "SwitchPlay"
	end
	return stage
end

local function defenseIntent(context: any, side: string, style: any): string
	local ball = context.BallTeam[side]
	local press = style and style:Ratio("PressingIntensity") or .5
	local depth = style and style:Ratio("DefensiveDepth") or .5
	local trigger = style and style:Ratio("PressTriggerDistance") or .5
	local counter = style and style:Ratio("CounterPress") or .5
	if context.LooseBall then return "AttackLooseBall" end
	if ball.Z < 185 then return "ProtectBox" end
	local targetPitch = context.PassTargetTeam and context.PassTargetTeam[side]
	if context.PassInFlight == true and typeof(targetPitch) == "Vector3" and targetPitch.Z < ball.Z - 80 and ball.Z >= 420 then
		return "PressBroken"
	end
	if depth < .34 then return "LowBlock" end
	local reset = context.OpponentResetPress and context.OpponentResetPress[side]
	if reset and reset.Active == true then
		return "OpponentResetPress"
	end
	local pressCommit = press * .72 + trigger * .28
	local backwardBuildPass = context.PassInFlight == true and typeof(targetPitch) == "Vector3" and targetPitch.Z >= ball.Z - 8 and targetPitch.Z >= 500
	if (ball.Z >= 520 or backwardBuildPass) and pressCommit >= .56 then return "HighPressCompression" end
	if ball.Z >= 470 and press >= .58 then return "HighPressBuildUp" end
	if ball.Z >= PitchConfig.HALF_LENGTH and pressCommit >= .68 then return "HighPressLocked" end
	if ball.Z >= 250 and counter >= .58 and press >= .54 then return "Counterpress" end
	return "MidBlock"
end

function Director:Update(context: any, styles: any, spatial: any, memory: any): any
	local now = context.Now or os.clock()
	local result = {}
	for _, side in ipairs({"Home", "Away"}) do
		local previous = self.State[side]
		local nextIntent
		if context.OwnerSide == side then
			nextIntent = possessionIntent(context, side, styles[side], spatial)
			self.ResetPress[side] = nil
		elseif context.LooseBall then
			nextIntent = "AttackLooseBall"
		else
			local reset = resetPressCandidate(context, side, styles[side], self.ResetPress[side])
			if reset then
				self.ResetPress[side] = reset
				context.OpponentResetPress = context.OpponentResetPress or {}
				context.OpponentResetPress[side] = {
					Active = true,
					StartedAt = reset.StartedAt,
					ExpiresAt = reset.ExpiresAt,
					Receiver = reset.Receiver,
					ReceiverName = reset.ReceiverName,
					TargetPitch = reset.TargetPitch,
					PassDirection = reset.PassDirection,
					Confidence = reset.Confidence,
					State = reset.State,
				}
			else
				self.ResetPress[side] = nil
				if context.OpponentResetPress then
					context.OpponentResetPress[side] = nil
				end
			end
			nextIntent = defenseIntent(context, side, styles[side])
		end
		local previousIntent = tostring(previous and previous.Intent or "")
		if (previousIntent:find("HighPress") or previousIntent == "OpponentResetPress") and nextIntent == "MidBlock" and context.BallTeam[side].Z >= 470 then
			nextIntent = "HighPressCompression"
		end
		local minimumCommit = previous and (previousIntent:find("HighPress") or previousIntent == "OpponentResetPress") and HIGH_PRESS_COMMIT or MIN_COMMIT
		if previous and previous.Intent ~= nextIntent and nextIntent ~= "OpponentResetPress" and now - previous.StartedAt < minimumCommit then
			nextIntent = previous.Intent
		end
		local state = previous and previous.Intent == nextIntent and previous or {Intent = nextIntent, StartedAt = now, Reason = context.MatchState}
		state.UpdatedAt = now
		self.State[side] = state
		result[side] = state
		if memory then memory:CommitIntent(side, nextIntent, now) end
	end
	context.TeamIntent = result
	return result
end

function Director:Reset(side: string?)
	if side then
		self.State[side] = nil
		self.ResetPress[side] = nil
	else
		self.State = {Home = nil, Away = nil}
		self.ResetPress = {Home = nil, Away = nil}
	end
end

return Director
