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
	local firstMatchAssistance = math.clamp(tonumber(context.FirstMatchAssistance) or 0, 0, 1)
	local distance = PitchConfig.GetDistanceStuds(defender.World, carrier.World)
	if distance > 11.25 - firstMatchAssistance * 3.75 then
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
	local insideBox = PitchConfig.InZone(defender.Pitch, "OwnBox")
	local lowStamina = (defender.Stamina or 60) < 25
	local foulRisk = (fromBehind and 0.45 or 0.08) + (insideBox and 0.22 or 0) + (lowStamina and 0.14 or 0) + (1 - style:Risk()) * 0.08 - (defender.Stats.defending or 60) / 420
	local slide = firstMatchAssistance < .2 and distance > 7.5 and not insideBox and style:Risk() > 0.65 and defender.Stats.standingTackle > 70
	return foulRisk < 0.28 - firstMatchAssistance * .1, slide
end

return Service
