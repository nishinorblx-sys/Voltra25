--!strict
local PitchConfig: any = {}

PitchConfig.PITCH_LENGTH = 742
PitchConfig.PITCH_WIDTH = 424
PitchConfig.HALF_LENGTH = 371
PitchConfig.HALF_WIDTH = 212
PitchConfig.CENTER = Vector3.new(0, 0, 0)
PitchConfig.HOME_ATTACK_DIRECTION = 1
PitchConfig.AWAY_ATTACK_DIRECTION = -1

PitchConfig.Lanes = table.freeze({
	LeftWide = {Min = 0, Max = 76, Center = 38},
	LeftHalfSpace = {Min = 76, Max = 170, Center = 123},
	Center = {Min = 170, Max = 254, Center = 212},
	RightHalfSpace = {Min = 254, Max = 348, Center = 301},
	RightWide = {Min = 348, Max = 424, Center = 386},
})

PitchConfig.Zones = table.freeze({
	DefensiveThird = {ZMin = 0, ZMax = 247},
	MiddleThird = {ZMin = 247, ZMax = 495},
	FinalThird = {ZMin = 495, ZMax = 742},
	OpponentBox = {XMin = 106, XMax = 318, ZMin = 610, ZMax = 742},
	OwnBox = {XMin = 106, XMax = 318, ZMin = 0, ZMax = 132},
	WideCrossZoneLeft = {XMin = 0, XMax = 90, ZMin = 520, ZMax = 710},
	WideCrossZoneRight = {XMin = 334, XMax = 424, ZMin = 520, ZMax = 710},
	CentralShootingZone = {XMin = 130, XMax = 294, ZMin = 560, ZMax = 742},
	EdgeOfBoxZone = {XMin = 105, XMax = 319, ZMin = 520, ZMax = 610},
})

export type PitchOptions = {
	PitchCFrame: CFrame?,
	Width: number?,
	Length: number?,
	AttackSign: number?,
	AttackSigns: {[string]: number}?,
}

local function optionCFrame(options: PitchOptions?): CFrame
	return options and options.PitchCFrame or CFrame.new(PitchConfig.CENTER)
end

local function optionWidth(options: PitchOptions?): number
	return math.max(1, options and options.Width or PitchConfig.PITCH_WIDTH)
end

local function optionLength(options: PitchOptions?): number
	return math.max(1, options and options.Length or PitchConfig.PITCH_LENGTH)
end

function PitchConfig.GetAttackDirection(teamId: string, options: PitchOptions?): number
	if options then
		if options.AttackSign then
			return options.AttackSign >= 0 and 1 or -1
		end
		if options.AttackSigns and options.AttackSigns[teamId] then
			return options.AttackSigns[teamId] >= 0 and 1 or -1
		end
	end
	return teamId == "Home" and PitchConfig.HOME_ATTACK_DIRECTION or PitchConfig.AWAY_ATTACK_DIRECTION
end

function PitchConfig.WorldToTeamPitchPosition(worldPosition: Vector3, teamId: string, options: PitchOptions?): Vector3
	local pitchCFrame = optionCFrame(options)
	local width = optionWidth(options)
	local length = optionLength(options)
	local attackSign = PitchConfig.GetAttackDirection(teamId, options)
	local localPosition = pitchCFrame:PointToObjectSpace(worldPosition)
	local pitchX = (localPosition.X / (width * 0.5)) * PitchConfig.HALF_WIDTH + PitchConfig.HALF_WIDTH
	local pitchZ = (localPosition.Z * attackSign / (length * 0.5)) * PitchConfig.HALF_LENGTH + PitchConfig.HALF_LENGTH
	return Vector3.new(math.clamp(pitchX, 0, PitchConfig.PITCH_WIDTH), worldPosition.Y, math.clamp(pitchZ, 0, PitchConfig.PITCH_LENGTH))
end

function PitchConfig.TeamPitchPositionToWorld(teamPitchPosition: Vector3, teamId: string, options: PitchOptions?): Vector3
	local pitchCFrame = optionCFrame(options)
	local width = optionWidth(options)
	local length = optionLength(options)
	local attackSign = PitchConfig.GetAttackDirection(teamId, options)
	local localX = ((teamPitchPosition.X - PitchConfig.HALF_WIDTH) / PitchConfig.HALF_WIDTH) * (width * 0.5)
	local localZ = ((teamPitchPosition.Z - PitchConfig.HALF_LENGTH) / PitchConfig.HALF_LENGTH) * (length * 0.5) * attackSign
	return pitchCFrame:PointToWorldSpace(Vector3.new(localX, teamPitchPosition.Y, localZ))
end

function PitchConfig.WorldToCanonicalPitchPosition(worldPosition: Vector3, options: PitchOptions?): Vector3
	local pitchCFrame = optionCFrame(options)
	local width = optionWidth(options)
	local length = optionLength(options)
	local localPosition = pitchCFrame:PointToObjectSpace(worldPosition)
	local pitchX = (localPosition.X / (width * 0.5)) * PitchConfig.HALF_WIDTH + PitchConfig.HALF_WIDTH
	local pitchZ = (localPosition.Z / (length * 0.5)) * PitchConfig.HALF_LENGTH + PitchConfig.HALF_LENGTH
	return Vector3.new(math.clamp(pitchX, 0, PitchConfig.PITCH_WIDTH), worldPosition.Y, math.clamp(pitchZ, 0, PitchConfig.PITCH_LENGTH))
end

function PitchConfig.CanonicalPitchPositionToWorld(canonicalPitchPosition: Vector3, options: PitchOptions?): Vector3
	local pitchCFrame = optionCFrame(options)
	local width = optionWidth(options)
	local length = optionLength(options)
	local localX = ((canonicalPitchPosition.X - PitchConfig.HALF_WIDTH) / PitchConfig.HALF_WIDTH) * (width * 0.5)
	local localZ = ((canonicalPitchPosition.Z - PitchConfig.HALF_LENGTH) / PitchConfig.HALF_LENGTH) * (length * 0.5)
	return pitchCFrame:PointToWorldSpace(Vector3.new(localX, canonicalPitchPosition.Y, localZ))
end

function PitchConfig.TeamPitchToCanonicalPitchPosition(teamPitchPosition: Vector3, teamId: string, options: PitchOptions?): Vector3
	local attackSign = PitchConfig.GetAttackDirection(teamId, options)
	local z = attackSign >= 0 and teamPitchPosition.Z or PitchConfig.PITCH_LENGTH - teamPitchPosition.Z
	return Vector3.new(teamPitchPosition.X, teamPitchPosition.Y, math.clamp(z, 0, PitchConfig.PITCH_LENGTH))
end

function PitchConfig.CanonicalPitchToTeamPitchPosition(canonicalPitchPosition: Vector3, teamId: string, options: PitchOptions?): Vector3
	local attackSign = PitchConfig.GetAttackDirection(teamId, options)
	local z = attackSign >= 0 and canonicalPitchPosition.Z or PitchConfig.PITCH_LENGTH - canonicalPitchPosition.Z
	return Vector3.new(canonicalPitchPosition.X, canonicalPitchPosition.Y, math.clamp(z, 0, PitchConfig.PITCH_LENGTH))
end

function PitchConfig.GetDistanceStuds(a: Vector3, b: Vector3): number
	local delta = a - b
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

function PitchConfig.GetForwardProgress(fromPosition: Vector3, toPosition: Vector3, teamId: string, options: PitchOptions?): number
	local fromPitch = PitchConfig.WorldToTeamPitchPosition(fromPosition, teamId, options)
	local toPitch = PitchConfig.WorldToTeamPitchPosition(toPosition, teamId, options)
	return toPitch.Z - fromPitch.Z
end

function PitchConfig.GetBallSide(ballPosition: Vector3, teamId: string?, options: PitchOptions?): string
	local pitchPosition = teamId and PitchConfig.WorldToTeamPitchPosition(ballPosition, teamId, options) or ballPosition
	if pitchPosition.X < 90 then
		return "Left"
	elseif pitchPosition.X > 334 then
		return "Right"
	end
	return "Center"
end

function PitchConfig.ClampInsidePitch(position: Vector3): Vector3
	return Vector3.new(math.clamp(position.X, 0, PitchConfig.PITCH_WIDTH), position.Y, math.clamp(position.Z, 0, PitchConfig.PITCH_LENGTH))
end

function PitchConfig.GetLane(position: Vector3): string
	local x = position.X
	for name, lane in pairs(PitchConfig.Lanes) do
		if x >= lane.Min and x <= lane.Max then
			return name
		end
	end
	return "Center"
end

function PitchConfig.GetLaneCenter(laneName: string): number
	local lane = PitchConfig.Lanes[laneName]
	return lane and lane.Center or PitchConfig.HALF_WIDTH
end

function PitchConfig.InZone(position: Vector3, zoneName: string): boolean
	local zone = PitchConfig.Zones[zoneName]
	if not zone then
		return false
	end
	if zone.XMin and (position.X < zone.XMin or position.X > zone.XMax) then
		return false
	end
	if zone.ZMin and (position.Z < zone.ZMin or position.Z > zone.ZMax) then
		return false
	end
	return true
end

return PitchConfig
