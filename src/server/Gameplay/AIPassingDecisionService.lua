--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)

local Service = {}

local function passType(fromZ: number, toZ: number): string
	local dz = toZ - fromZ
	if dz >= 25 then
		return "Forward"
	elseif dz <= -20 then
		return "Back"
	end
	return "Side"
end

local function passTarget(context: any, passer: any, receiver: any, kind: string): Vector3
	if kind == "Through" then
		local defensiveLine = AIContextBuilder.DefensiveLineZ(context, passer.Side)
		local laneX = receiver.Pitch.X
		local receiverLead = math.clamp(receiver.Pitch.Z - passer.Pitch.Z, 12, 42) * 0.22
		local lineLead = math.clamp(defensiveLine - receiver.Pitch.Z, -12, 28) * 0.16
		local targetZ = receiver.Pitch.Z + math.clamp(5 + receiverLead + lineLead, 5, 16)
		local targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(laneX, 3, math.clamp(targetZ, 0, 704)))
		return PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)
	end
	local forwardLead = math.clamp(receiver.Pitch.Z - passer.Pitch.Z, -8, 28) * 0.14
	local targetPitch = PitchConfig.ClampInsidePitch(Vector3.new(receiver.Pitch.X, 3, receiver.Pitch.Z + math.max(2, forwardLead)))
	local target = PitchConfig.TeamPitchPositionToWorld(targetPitch, passer.Side, context.Options)
	return Vector3.new(target.X, receiver.World.Y, target.Z)
end

function Service.ScoreReceiver(context: any, passer: any, receiver: any, style: any, difficulty: any): any
	local distance = PitchConfig.GetDistanceStuds(passer.World, receiver.World)
	if distance < 7 or distance > 135 then
		return nil
	end

	local open, veryOpen, tight = AIContextBuilder.IsOpen(context, receiver)
	local kind = passType(passer.Pitch.Z, receiver.Pitch.Z)
	local forwardGain = receiver.Pitch.Z - passer.Pitch.Z
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, passer.Side)
	if defensiveLine > 90 and forwardGain > 1 and receiver.Pitch.Z > defensiveLine - 3 then
		return nil
	end
	local dangerous = receiver.Pitch.Z > 495 or PitchConfig.InZone(receiver.Pitch, "OpponentBox") or math.abs(742 - receiver.Pitch.Z) < 35
	local directness = style:Directness()
	local risk = style:Risk()
	local forwardPriority = style:Ratio("ForwardPassPriority")
	local backPassSafety = style:Ratio("BackPassSafety")
	local throughFrequency = style:Ratio("ThroughBallFrequency")
	local passRisk = style:Ratio("PassRisk")
	local targetKind = "Ground"
	if dangerous and forwardGain > 35 and directness + risk + throughFrequency > 1.15 then
		targetKind = "Through"
	elseif distance > 62 and forwardGain > 12 and directness + style:Ratio("FreeKickLongPass") + style:Ratio("SwitchPlayFrequency") > 1.18 then
		targetKind = "Lofted"
	end
	local target = passTarget(context, passer, receiver, targetKind)
	local groundLaneClear = AIContextBuilder.PassingLaneClear(context, passer, target, targetKind == "Through" and "Driven" or "Ground")
	if targetKind == "Ground" and not groundLaneClear and distance > 48 and forwardGain > 6 and directness + passRisk > 0.85 then
		targetKind = "Lofted"
		target = passTarget(context, passer, receiver, targetKind)
	end
	local laneClear = targetKind == "Lofted" and AIContextBuilder.PassingLaneClear(context, passer, target, "Lobbed") or AIContextBuilder.PassingLaneClear(context, passer, target, targetKind == "Through" and "Driven" or "Ground")
	local pressure = AIContextBuilder.Pressure(context, receiver)
	local safe = (open or veryOpen) and laneClear and distance < 115 and not (pressure.Under and kind == "Back")

	local score = 0
	score += (veryOpen and 24 or open and 14 or tight and -20 or 0)
	score += laneClear and 26 or -34
	score += kind == "Forward" and (18 + directness * 18 + forwardPriority * 18) or kind == "Side" and (12 - directness * 2) or (5 + backPassSafety * 16 - directness * 16)
	score += targetKind == "Through" and throughFrequency * 18 or targetKind == "Lofted" and (directness * 10 + style:Ratio("FreeKickLongPass") * 8) or 0
	score += dangerous and (10 + risk * 10 + passRisk * 10) or 0
	score -= math.abs(distance - (directness > 0.55 and 48 or 28)) * 0.22
	score += (receiver.Stats.overall or 60) * 0.08 + (receiver.Stats.pace or 60) * 0.05
	score -= pressure.Score * 18
	score += difficulty.PassRisk * 10
	if not safe and math.max(risk, passRisk) < 0.45 then
		score -= 18
	end
	if not laneClear then
		score -= 38
	end

	return {
		Receiver = receiver,
		Score = score,
		Kind = kind,
		PassKind = targetKind,
		Target = target,
		Distance = distance,
		LaneClear = laneClear,
		Safe = safe,
		ForwardGain = forwardGain,
	}
end

function Service.Choose(context: any, passer: any, style: any, difficulty: any, forcedSafe: boolean?): any?
	local best = nil
	local bestSafe = nil
	local fallback = nil
	for _, receiver in ipairs(context.Teams[passer.Side].List) do
		if receiver.Model ~= passer.Model and receiver.Root and not receiver.IsGoalkeeper then
			local scored = Service.ScoreReceiver(context, passer, receiver, style, difficulty)
			if scored then
				if scored.LaneClear and scored.Score > -4 and (not fallback or scored.Score > fallback.Score) then
					fallback = scored
				end
				if scored.Safe and (not bestSafe or scored.Score > bestSafe.Score) then
					bestSafe = scored
				end
				if scored.LaneClear and scored.Score > 2 and (not forcedSafe or scored.Safe) and (not best or scored.Score > best.Score) then
					best = scored
				end
			end
		end
	end
	return best or bestSafe or fallback
end

return Service
