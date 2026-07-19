--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)
local AIStyleProfileService = require(script.Parent.AIStyleProfileService)

local Observer = {}
Observer.__index = Observer

local function zero(keys: {string}): {[string]: number}
	local result = {}
	for _, key in ipairs(keys) do result[key] = 0 end
	return result
end

local function blendInto(current: {[string]: number}, sample: {[string]: number}, alpha: number, keys: {string})
	for _, key in ipairs(keys) do
		current[key] = (current[key] or 0) * (1 - alpha) + (sample[key] or 0) * alpha
	end
end

local function normalize(map: {[string]: number}, keys: {string}): {[string]: number}
	local total = 0
	local result = {}
	for _, key in ipairs(keys) do
		local value = math.max(0, tonumber(map[key]) or 0)
		result[key] = value
		total += value
	end
	if total <= 0 then
		result[keys[1]] = 1
		return result
	end
	for _, key in ipairs(keys) do result[key] = result[key] / total end
	return result
end

local function leading(map: {[string]: number}): (string, number)
	return AIStyleProfileService.Leading(map)
end

local function countNear(context: any, side: string, origin: Vector3, radius: number): number
	local count = 0
	for _, info in ipairs(context.Teams[side].List) do
		if info.Root and PitchConfig.GetDistanceStuds(info.World, origin) <= radius then
			count += 1
		end
	end
	return count
end

local function teamStats(context: any, side: string): any
	local ball = context.BallTeam[side]
	local total = 0
	local wide = 0
	local central = 0
	local high = 0
	local forward = 0
	local rest = 0
	local exchanges = 0
	for _, info in ipairs(context.Teams[side].List) do
		if info.Root then
			total += 1
			if info.Pitch.X < 105 or info.Pitch.X > 319 then wide += 1 end
			if info.Pitch.X >= 150 and info.Pitch.X <= 274 then central += 1 end
			if info.Pitch.Z >= ball.Z + 42 then forward += 1 end
			if info.Pitch.Z >= 510 then high += 1 end
			if info.Pitch.Z <= ball.Z - 62 then rest += 1 end
			local slotId = tostring(info.Model:GetAttribute("AITacticalSlot") or "")
			local baseSlot = tostring(info.SpecificRole or "")
			if slotId ~= "" and baseSlot ~= "" and not string.find(string.lower(slotId), string.lower(baseSlot), 1, true) then exchanges += 1 end
		end
	end
	return {
		Total = math.max(1, total),
		Wide = wide,
		Central = central,
		High = high,
		Forward = forward,
		Rest = rest,
		WidthRatio = wide / math.max(1, total),
		CentralRatio = central / math.max(1, total),
		ForwardRatio = forward / math.max(1, total),
		RestRatio = rest / math.max(1, total),
		ExchangeRatio = exchanges / math.max(1, total),
		NearBall = countNear(context, side, context.BallWorld, 78),
	}
end

local function attackSample(context: any, side: string, state: any): {[string]: number}
	local stats = teamStats(context, side)
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	local previousOwner = state.LastOwner
	local forwardAction = 0
	local progression = 0
	local longPass = 0
	local centralPass = 0
	local widePass = 0
	if ownerInfo and previousOwner and previousOwner ~= owner and state.LastOwnerInfo then
		local from = state.LastOwnerInfo.Pitch
		local to = ownerInfo.Pitch
		progression = math.max(0, to.Z - from.Z) / 120
		local distance = PitchConfig.GetDistanceStuds(from, to)
		longPass = distance > 72 and 1 or 0
		centralPass = to.X >= 150 and to.X <= 274 and 1 or 0
		widePass = to.X < 105 or to.X > 319 and 1 or 0
		forwardAction = progression > .12 and 1 or 0
	end
	local regainAge = context.OwnerSide == side and math.max(0, (context.Now or os.clock()) - (state.PossessionStartedAt or context.Now or os.clock())) or 8
	local quickForward = forwardAction == 1 and regainAge <= 2 and 1 or 0
	local crossRate = context.Ball and (context.Ball:GetAttribute("VTRCrossActive") == true or context.Ball:GetAttribute("VTRCutbackActive") == true) and 1 or 0
	return normalize({
		PositionalControl = (1 - longPass) * .16 + (1 - quickForward) * .12 + math.max(0, 1 - stats.ForwardRatio) * .1,
		VerticalCombination = centralPass * .22 + progression * .2 + stats.CentralRatio * .13,
		DirectAssault = longPass * .28 + progression * .26 + quickForward * .18 + stats.ForwardRatio * .12,
		WideOverload = stats.WidthRatio * .28 + widePass * .18 + crossRate * .24,
		CentralDomination = stats.CentralRatio * .32 + centralPass * .18,
		CounterattackingTrap = quickForward * .26 + stats.RestRatio * .18 + progression * .12,
		HighPressSwarm = context.BallTeam[side].Z >= 520 and stats.NearBall >= 3 and .35 or 0,
		LowBlockFortress = stats.RestRatio * .25 + (context.BallTeam[side].Z < 260 and .16 or 0),
		FluidRotation = stats.ExchangeRatio * .34 + stats.CentralRatio * .08,
		AdaptiveController = .12 + math.min(.2, math.abs(stats.WidthRatio - stats.CentralRatio)),
	}, AIStyleProfileService.AttackKeys)
end

local function defenseSample(context: any, observingSide: string, defendingSide: string): {[string]: number}
	local stats = teamStats(context, defendingSide)
	local ball = context.BallTeam[defendingSide]
	local deepest = PitchConfig.PITCH_LENGTH
	local highest = 0
	local left = PitchConfig.PITCH_WIDTH
	local right = 0
	local behindBall = 0
	local pressers = 0
	local centralScreens = 0
	local farPost = 0
	for _, info in ipairs(context.Teams[defendingSide].List) do
		if info.Root then
			deepest = math.min(deepest, info.Pitch.Z)
			highest = math.max(highest, info.Pitch.Z)
			left = math.min(left, info.Pitch.X)
			right = math.max(right, info.Pitch.X)
			if info.Pitch.Z <= ball.Z then behindBall += 1 end
			if PitchConfig.GetDistanceStuds(info.World, context.BallWorld) <= 42 then pressers += 1 end
			if info.Pitch.X >= 150 and info.Pitch.X <= 274 and info.Pitch.Z <= ball.Z + 20 then centralScreens += 1 end
			if info.Pitch.Z <= 135 and (info.Pitch.X < 135 or info.Pitch.X > 289) then farPost += 1 end
		end
	end
	local total = stats.Total
	local lineHeight = math.clamp(highest / PitchConfig.PITCH_LENGTH, 0, 1)
	local depth = math.clamp((highest - deepest) / 260, 0, 1)
	local width = math.clamp((right - left) / PitchConfig.PITCH_WIDTH, 0, 1)
	local behindRatio = behindBall / total
	local centralProtection = math.clamp(centralScreens / 3, 0, 1)
	local pressure = math.clamp(pressers / 4, 0, 1)
	local ballSideShift = stats.NearBall / total
	local concededWide = width < .52 and 1 or 0
	return normalize({
		StructuredContainment = behindRatio * .2 + (1 - pressure) * .12 + depth * .08,
		LaneDisruption = centralProtection * .24 + pressure * .12,
		DepthProtection = (1 - lineHeight) * .24 + behindRatio * .16,
		FlankIsolation = ballSideShift * .22 + width * .12,
		CentralLock = centralProtection * .32 + (1 - width) * .14,
		BaitAndCollapse = (1 - pressure) * .18 + behindRatio * .18 + lineHeight * .08,
		CollectiveHunt = pressure * .4 + lineHeight * .22,
		BoxProtection = (1 - lineHeight) * .22 + farPost * .12 + behindRatio * .16,
		DynamicCoverage = depth * .14 + ballSideShift * .12 + stats.ExchangeRatio * .22,
		TacticalCounterSystem = .12 + concededWide * .08,
	}, AIStyleProfileService.DefenseKeys)
end

local function applyHysteresis(state: any, kind: string, confidence: {[string]: number}, now: number, emergency: boolean?)
	local labelField = kind .. "Identity"
	local pendingField = kind .. "Pending"
	local pendingAtField = kind .. "PendingAt"
	local current = tostring(state[labelField] or "")
	local top, topScore = leading(confidence)
	if current == "" then
		state[labelField] = top
		state[pendingField] = nil
		return
	end
	if top == current then
		state[pendingField] = nil
		return
	end
	local currentScore = tonumber(confidence[current]) or 0
	local threshold = kind == "Attack" and .22 or .2
	local margin = kind == "Attack" and .08 or .07
	if emergency == true or topScore >= threshold and topScore >= currentScore + margin then
		if state[pendingField] ~= top then
			state[pendingField] = top
			state[pendingAtField] = now
		elseif now - (tonumber(state[pendingAtField]) or now) >= 1.15 then
			state[labelField] = top
			state[pendingField] = nil
		end
	else
		state[pendingField] = nil
	end
end

function Observer.new(styles: any?): any
	local self = setmetatable({States = {Home = nil, Away = nil}}, Observer)
	for _, side in ipairs({"Home", "Away"}) do
		local blend = styles and AIStyleProfileService.Blends(styles[side]) or nil
		self.States[side] = {
			AttackConfidence = blend and table.clone(blend.Attack) or zero(AIStyleProfileService.AttackKeys),
			DefenseConfidence = blend and table.clone(blend.Defense) or zero(AIStyleProfileService.DefenseKeys),
			AttackIdentity = blend and select(1, leading(blend.Attack)) or "PositionalControl",
			DefenseIdentity = blend and select(1, leading(blend.Defense)) or "StructuredContainment",
			LastOwner = nil,
			LastOwnerInfo = nil,
			PossessionStartedAt = 0,
		}
	end
	return self
end

function Observer:UpdateStyles(styles: any)
	for _, side in ipairs({"Home", "Away"}) do
		local blend = AIStyleProfileService.Blends(styles[side])
		local state = self.States[side]
		blendInto(state.AttackConfidence, blend.Attack, .08, AIStyleProfileService.AttackKeys)
		blendInto(state.DefenseConfidence, blend.Defense, .08, AIStyleProfileService.DefenseKeys)
	end
end

function Observer:Observe(context: any, styles: any): any
	local now = context.Now or os.clock()
	for _, side in ipairs({"Home", "Away"}) do
		local state = self.States[side]
		if context.OwnerSide == side and state.PossessionSide ~= side then
			state.PossessionStartedAt = now
		end
		local blend = styles and AIStyleProfileService.Blends(styles[side]) or nil
		if context.OwnerSide == side then
			local sample = attackSample(context, side, state)
			if blend then blendInto(sample, blend.Attack, .08, AIStyleProfileService.AttackKeys) end
			blendInto(state.AttackConfidence, sample, .18, AIStyleProfileService.AttackKeys)
			applyHysteresis(state, "Attack", state.AttackConfidence, now, sample.DirectAssault and sample.DirectAssault > .5)
		else
			local sample = defenseSample(context, side == "Home" and "Away" or "Home", side)
			if blend then blendInto(sample, blend.Defense, .08, AIStyleProfileService.DefenseKeys) end
			blendInto(state.DefenseConfidence, sample, .18, AIStyleProfileService.DefenseKeys)
			applyHysteresis(state, "Defense", state.DefenseConfidence, now, sample.CollectiveHunt and sample.CollectiveHunt > .52)
		end
		state.PossessionSide = context.OwnerSide
		state.LastOwner = context.Owner
		state.LastOwnerInfo = context.Owner and context.Players[context.Owner] or nil
	end
	context.OpponentObservation = {
		Home = self:ForSide("Home"),
		Away = self:ForSide("Away"),
	}
	return context.OpponentObservation
end

function Observer:ForSide(side: string): any
	local opponent = side == "Home" and "Away" or "Home"
	local state = self.States[opponent]
	return {
		OpponentAttackConfidence = table.clone(state.AttackConfidence),
		OpponentDefenseConfidence = table.clone(state.DefenseConfidence),
		OpponentAttackIdentity = state.AttackIdentity,
		OpponentDefenseIdentity = state.DefenseIdentity,
		ObservedSide = opponent,
	}
end

function Observer:Reset(side: string?)
	if side then
		self.States[side] = {
			AttackConfidence = zero(AIStyleProfileService.AttackKeys),
			DefenseConfidence = zero(AIStyleProfileService.DefenseKeys),
			AttackIdentity = "PositionalControl",
			DefenseIdentity = "StructuredContainment",
			LastOwner = nil,
			LastOwnerInfo = nil,
			PossessionStartedAt = 0,
		}
	else
		self.States = {Home = nil, Away = nil}
		for _, target in ipairs({"Home", "Away"}) do self:Reset(target) end
	end
end

return Observer
