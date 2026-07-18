--!strict

local Service = {}

local function read(model: Model, names: {string}, fallback: number): number
	for _, name in ipairs(names) do
		local value = tonumber(model:GetAttribute(name))
		if value then
			return math.clamp(value, 1, 99)
		end
	end
	return math.clamp(fallback, 1, 99)
end

local function blend(items: {{number}}): number
	local total = 0
	local weight = 0
	for _, item in ipairs(items) do
		local value = tonumber(item[1]) or 60
		local itemWeight = tonumber(item[2]) or 1
		total += value * itemWeight
		weight += itemWeight
	end
	return math.clamp(weight > 0 and total / weight or 60, 1, 99)
end

local function quality(value: number): number
	local alpha = math.clamp((value - 45) / 54, 0, 1)
	return math.clamp(alpha * alpha * (3 - 2 * alpha), 0, 1)
end

local function delayMultiplier(value: number): number
	return 1.14 - quality(value) * 0.36
end

function Service.Read(model: Model, names: {string}, fallback: number): number
	return read(model, names, fallback)
end

function Service.Profile(model: Model): any
	local overall = read(model, {"overall", "OVR"}, 60)
	local pace = read(model, {"PAC", "Pace", "SprintSpeed", "Acceleration"}, overall)
	local acceleration = read(model, {"Acceleration", "PAC", "Pace"}, pace)
	local sprintSpeed = read(model, {"SprintSpeed", "PAC", "Pace"}, pace)
	local shooting = read(model, {"SHO", "Shooting"}, overall)
	local finishing = read(model, {"Finishing", "SHO", "Shooting"}, shooting)
	local shotPower = read(model, {"ShotPower", "SHO", "Shooting"}, shooting)
	local longShots = read(model, {"LongShots", "SHO", "Shooting"}, shooting)
	local volleys = read(model, {"Volleys", "SHO", "Shooting"}, shooting)
	local passing = read(model, {"PAS", "Passing"}, overall)
	local shortPassing = read(model, {"ShortPassing", "PAS", "Passing"}, passing)
	local longPassing = read(model, {"LongPassing", "PAS", "Passing"}, passing)
	local vision = read(model, {"Vision", "PAS", "Passing"}, passing)
	local crossing = read(model, {"Crossing", "PAS", "Passing"}, passing)
	local curve = read(model, {"Curve", "PAS", "Passing"}, passing)
	local dribbling = read(model, {"DRI", "Dribbling"}, overall)
	local ballControl = read(model, {"BallControl", "DRI", "Dribbling"}, dribbling)
	local agility = read(model, {"Agility", "DRI", "Dribbling"}, dribbling)
	local balance = read(model, {"Balance", "DRI", "Dribbling"}, dribbling)
	local reactions = read(model, {"Reactions", "overall", "OVR"}, overall)
	local defending = read(model, {"DEF", "Defending"}, overall)
	local defensiveAwareness = read(model, {"DefensiveAwareness", "DEF", "Defending"}, defending)
	local standingTackle = read(model, {"StandingTackle", "DEF", "Defending"}, defending)
	local slidingTackle = read(model, {"SlidingTackle", "DEF", "Defending"}, defending)
	local interceptions = read(model, {"Interceptions", "DEF", "Defending"}, defending)
	local physical = read(model, {"PHY", "Physical"}, overall)
	local strength = read(model, {"Strength", "PHY", "Physical"}, physical)
	local stamina = read(model, {"Stamina", "PHY", "Physical"}, physical)
	local aggression = read(model, {"Aggression", "PHY", "Physical"}, physical)
	local jumping = read(model, {"Jumping", "PHY", "Physical"}, physical)
	local headingAccuracy = read(model, {"HeadingAccuracy", "SHO", "Shooting"}, shooting)
	local attackingPosition = read(model, {"AttackingPosition", "Positioning", "SHO", "Shooting"}, shooting)
	local composure = read(model, {"Composure", "overall", "OVR"}, overall)
	local currentStamina = math.clamp(tonumber(model:GetAttribute("VTRSprintStamina")) or tonumber(model:GetAttribute("VTRStamina")) or 100, 0, 100)
	local passVision = blend({{shortPassing, .32}, {longPassing, .24}, {vision, .32}, {composure, .12}})
	local reception = blend({{ballControl, .34}, {reactions, .25}, {agility, .18}, {composure, .15}, {balance, .08}})
	local interceptionSkill = blend({{interceptions, .4}, {defensiveAwareness, .3}, {reactions, .16}, {pace, .14}})
	local tackleSkill = blend({{standingTackle, .42}, {defensiveAwareness, .24}, {strength, .16}, {aggression, .1}, {slidingTackle, .08}})
	local shootingIQ = blend({{finishing, .32}, {shotPower, .17}, {longShots, .15}, {attackingPosition, .18}, {composure, .18}})
	local movementIQ = blend({{attackingPosition, .22}, {defensiveAwareness, .18}, {reactions, .24}, {stamina, .14}, {pace, .12}, {composure, .1}})
	return {
		overall = overall,
		pace = pace,
		acceleration = acceleration,
		sprintSpeed = sprintSpeed,
		shooting = shooting,
		finishing = finishing,
		shotPower = shotPower,
		longShots = longShots,
		volleys = volleys,
		passing = passing,
		shortPassing = shortPassing,
		longPassing = longPassing,
		vision = vision,
		crossing = crossing,
		curve = curve,
		dribbling = dribbling,
		ballControl = ballControl,
		agility = agility,
		balance = balance,
		reactions = reactions,
		defending = defending,
		defensiveAwareness = defensiveAwareness,
		standingTackle = standingTackle,
		slidingTackle = slidingTackle,
		interceptions = interceptions,
		physical = physical,
		strength = strength,
		stamina = stamina,
		aggression = aggression,
		jumping = jumping,
		headingAccuracy = headingAccuracy,
		attackingPosition = attackingPosition,
		composure = composure,
		currentStamina = currentStamina,
		weakFoot = math.clamp(tonumber(model:GetAttribute("WeakFoot")) or 3, 1, 5),
		skillMoves = math.clamp(tonumber(model:GetAttribute("SkillMoves")) or 3, 1, 5),
		workRateAttack = tostring(model:GetAttribute("WorkRateAttack") or "Medium"),
		workRateDefense = tostring(model:GetAttribute("WorkRateDefense") or "Medium"),
		preferredFoot = tostring(model:GetAttribute("PreferredFoot") or "Right"),
		height = tonumber(model:GetAttribute("Height")) or 70,
		decisionDelayMultiplier = delayMultiplier(blend({{reactions, .36}, {composure, .34}, {vision, .3}})),
		passVision = passVision,
		passQuality = blend({{shortPassing, .35}, {vision, .25}, {longPassing, .18}, {composure, .14}, {curve, .08}}),
		reception = reception,
		interceptionSkill = interceptionSkill,
		tackleSkill = tackleSkill,
		shootingIQ = shootingIQ,
		movementIQ = movementIQ,
		pressingIQ = blend({{defensiveAwareness, .28}, {stamina, .24}, {aggression, .18}, {pace, .16}, {reactions, .14}}),
		keeperSkill = blend({{read(model, {"GKDiving"}, overall), .2}, {read(model, {"GKHandling"}, overall), .2}, {read(model, {"GKKicking"}, overall), .15}, {read(model, {"GKPositioning"}, overall), .22}, {read(model, {"GKReflexes"}, overall), .23}}),
	}
end

return Service
