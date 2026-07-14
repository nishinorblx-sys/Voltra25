--!strict

local Resolver = {}

local familyScale = {
	Ground = 1,
	BackPass = 0.92,
	Through = 1.14,
	Lofted = 1.2,
	Manual = 1.08,
	ManualLobbed = 1.24,
}

local function foot(value: any): string?
	local normalized = string.lower(tostring(value or ""))
	if normalized == "left" or normalized == "l" then return "Left" end
	if normalized == "right" or normalized == "r" then return "Right" end
	return nil
end

function Resolver.SelectKickingFoot(input: any): string
	local preferred = foot(input.PreferredFoot) or "Right"
	local explicit = foot(input.SelectedFoot)
	if explicit then return explicit end
	local lateral = math.clamp(tonumber(input.TargetLateral) or 0, -1, 1)
	local bodyDot = math.clamp(tonumber(input.BodyDot) or 1, -1, 1)
	if bodyDot < -0.1 and math.abs(lateral) > 0.28 then return lateral < 0 and "Left" or "Right" end
	return preferred
end

function Resolver.Resolve(input: any): any
	local passing = math.clamp(tonumber(input.Passing) or 60, 1, 99)
	local weakFoot = math.clamp(tonumber(input.WeakFoot) or 3, 1, 5)
	local balance = math.clamp(tonumber(input.Balance) or 65, 1, 99)
	local distance = math.max(0, tonumber(input.Distance) or 0)
	local pressure = math.clamp(tonumber(input.Pressure) or 0, 0, 1)
	local bodyDot = math.clamp(tonumber(input.BodyDot) or 1, -1, 1)
	local turnAngle = math.clamp(tonumber(input.TurnAngle) or math.acos(bodyDot), 0, math.pi)
	local movementSpeed = math.max(0, tonumber(input.MovementSpeed) or 0)
	local preferred = foot(input.PreferredFoot) or "Right"
	local kickingFoot = Resolver.SelectKickingFoot(input)
	local accuracy = passing / 99
	local base = 1.05 * (1 - accuracy) ^ 1.45 + 0.045
	local longError = math.max(0, distance - 35) * (0.012 * (1 - accuracy) + 0.0025)
	local pressureError = pressure * (1.45 - accuracy * 0.62)
	local movementError = math.clamp(movementSpeed / 26, 0, 1) * (0.24 - accuracy * 0.1)
	local sprintError = input.Sprinting == true and (0.23 - accuracy * 0.1) or 0
	local weakFootError = kickingFoot ~= preferred and (5 - weakFoot) * 0.12 or 0
	local balanceError = (100 - balance) / 290
	local bodyError = math.clamp(turnAngle / math.pi, 0, 1) * (0.55 - accuracy * 0.22)
	local pressureSide = math.clamp(tonumber(input.PressureFromKickingSide) or 0, 0, 1) * 0.18
	local scale = familyScale[tostring(input.PassFamily or "Ground")] or 1.08
	return {
		Radius = (base + longError + pressureError + movementError + sprintError + weakFootError + balanceError + bodyError + pressureSide) * scale,
		KickingFoot = kickingFoot,
		PreferredFoot = preferred,
		WeakFootApplied = kickingFoot ~= preferred,
		FamilyScale = scale,
	}
end

return table.freeze(Resolver)
