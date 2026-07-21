--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Service.CanTackle(context: any, defender: any, carrier: any, style: any): (boolean, boolean)
	if not defender.Root or not carrier.Root then
		return false, false
	end
	local now = context.Now or os.clock()
	if defender.Model and (tonumber(defender.Model:GetAttribute("VTRStunnedUntil")) or 0) > now then
		return false, false
	end
	if defender.Model and (tonumber(defender.Model:GetAttribute("VTRCannotRecoverBallUntil")) or 0) > now then
		return false, false
	end
	if carrier.Model and tostring(carrier.Model:GetAttribute("position") or "") == "GK" and (tonumber(carrier.Model:GetAttribute("VTRGoalkeeperTackleImmuneUntil")) or 0) > now then
		return false, false
	end
	local firstMatchAssistance = math.clamp(tonumber(context.FirstMatchAssistance) or 0, 0, 1)
	local distance = PitchConfig.GetDistanceStuds(defender.World, carrier.World)
	local assignmentName = tostring(defender.Model and (defender.Model:GetAttribute("currentAssignment") or defender.Model:GetAttribute("AITacticalSlot")) or "")
	local carrierPitchForDefender = PitchConfig.WorldToTeamPitchPosition(carrier.World, defender.Side, context.Options)
	local centralDanger = math.abs(carrierPitchForDefender.X - PitchConfig.HALF_WIDTH) <= 70 and carrierPitchForDefender.Z <= PitchConfig.HALF_LENGTH
	local aggression = style and style.Ratio and style:Ratio("TackleAggression") or .5
	local slideFrequency = math.clamp(tonumber(style and style.MetricsTargets and style.MetricsTargets.SlideTackleFrequency) or 50, 0, 100) / 100
	local engagement = 8.6 - firstMatchAssistance * 3.25
	if assignmentName == "CarrierBreachPress" or assignmentName == "ContainBallCarrier" or assignmentName == "CoverStep" then
		engagement = centralDanger and 13.5 or 10.8
	elseif assignmentName == "PressBallCarrier" or assignmentName == "PressNextReceiver" or assignmentName == "MidfieldPressSupport" then
		engagement = 10.4
	elseif centralDanger then
		engagement = 12.2
	end
	engagement += math.clamp(aggression - .5, -.5, .5) * 3
	if distance > engagement then
		return false, false
	end
	local toCarrier = flat(carrier.World - defender.World)
	local facing = flat(defender.Root.CFrame.LookVector)
	local closingVelocity = flat(defender.Root.AssemblyLinearVelocity)
	local movingIntoCarrier = closingVelocity.Magnitude > 2 and toCarrier.Magnitude > 0.01 and closingVelocity.Unit:Dot(toCarrier.Unit) > 0.18
	local facingCarrier = facing.Magnitude > 0.01 and toCarrier.Magnitude > 0.01 and facing.Unit:Dot(toCarrier.Unit) > -0.12
	if not facingCarrier then
		return movingIntoCarrier and distance <= 7.8, false
	end
	local ballPast = flat(context.BallWorld - defender.World).Magnitude > flat(carrier.World - defender.World).Magnitude + 4
	if ballPast then
		return false, false
	end
	local carrierFacing = flat(carrier.Root.CFrame.LookVector)
	local toDefender = flat(defender.World - carrier.World)
	local fromBehind = carrierFacing.Magnitude > 0.01 and toDefender.Magnitude > 0.01 and carrierFacing.Unit:Dot(toDefender.Unit) < -0.35
	local tackleLaneDot = carrierFacing.Magnitude > 0.01 and toDefender.Magnitude > 0.01 and carrierFacing.Unit:Dot(toDefender.Unit) or 0
	local inFrontOfCarrier = tackleLaneDot >= 0.08
	if not inFrontOfCarrier then
		defender.Model:SetAttribute("AITackleDeniedReason", fromBehind and "BehindCarrier" or "NotGoalSideFront")
		return false, false
	end
	local insideBox = PitchConfig.InZone(defender.Pitch, "OwnBox")
	local coverBehind = false
	for _, teammate in ipairs(context.Teams[defender.Side].List) do
		if teammate.Model ~= defender.Model and teammate.Root and (teammate.Role == "CB" or teammate.Role == "Fullback" or teammate.Role == "CDM") then
			if teammate.Pitch.Z < defender.Pitch.Z - 8 and math.abs(teammate.Pitch.X - defender.Pitch.X) < 90 then
				coverBehind = true
				break
			end
		end
	end
	local lowStamina = (defender.Stamina or 60) < 25
	local tackleSkill = defender.Stats.tackleSkill or defender.Stats.defending or 60
	local bypassRisk = centralDanger and distance <= 18 and not coverBehind and 0.18 or 0
	local foulRisk = (fromBehind and 0.45 or 0.08) + (insideBox and 0.22 or 0) + (lowStamina and 0.14 or 0) + (1 - style:Risk()) * 0.08 - tackleSkill / 420 - bypassRisk - (coverBehind and 0.08 or 0)
	local slide = firstMatchAssistance < .2 and distance > 8.8 and not insideBox and style:Risk() > 0.78 - slideFrequency * .18 and aggression > .68 - slideFrequency * .16 and coverBehind and (defender.Stats.standingTackle > 74 or tackleSkill > 78)
	defender.Model:SetAttribute("AITackleDeniedReason", nil)
	return foulRisk < 0.2 + aggression * .08 - firstMatchAssistance * .1, slide
end

return Service
