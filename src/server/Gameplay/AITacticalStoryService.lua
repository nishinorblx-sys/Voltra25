--!strict

local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)

local Service = {}
Service.__index = Service

local TACTIC_BY_PRESET = {
	balanced_control = "Balanced",
	short_possession = "KeepPossession",
	vertical_combination = "DirectPlay",
	wing_overload = "WingPlay",
	central_overload = "CentralCombination",
	counter_attack = "CounterAttack",
	high_press = "HighPress",
	low_block_counter = "LowBlockCounter",
	protect_lead = "ProtectLead",
	all_out_attack = "AllOutAttack",
}

local ACTIONS = {
	MidfieldProgression = {Duration = 3, Roles = {CM = 34, CDM = 28, CAM = 24, Winger = 18, ST = 12}, Movement = "Possession"},
	WingerAttack = {Duration = 3, Roles = {Winger = 42, Fullback = 20, ST = 18, CM = 12}, Movement = "Wide"},
	DefensiveRecycling = {Duration = 3, Roles = {CB = 36, Fullback = 26, CDM = 24, GK = 12}, Movement = "Recycle"},
	StrikerLinkUp = {Duration = 3, Roles = {ST = 42, CAM = 28, Winger = 18, CM = 14}, Movement = "Link"},
	FirstForwardPass = {Duration = 2, Roles = {ST = 42, Winger = 38, CAM = 16, CM = 10}, Movement = "Counter"},
	FastWingerAttack = {Duration = 3, Roles = {Winger = 48, ST = 28, CAM = 16}, Movement = "CounterWide"},
	StrikerCounter = {Duration = 3, Roles = {ST = 50, Winger = 24, CAM = 18}, Movement = "CounterCentral"},
	SecurePossession = {Duration = 3, Roles = {CM = 28, CDM = 28, Fullback = 20, CB = 18}, Movement = "Secure"},
	PressTrigger = {Duration = 3, Roles = {CM = 28, CAM = 24, Winger = 20, ST = 18}, Movement = "Press"},
	PressRecovery = {Duration = 3, Roles = {CDM = 30, CM = 24, CB = 20, Fullback = 18}, Movement = "Recover"},
	Counterpress = {Duration = 3, Roles = {CM = 30, CAM = 24, Winger = 22, ST = 16}, Movement = "Counterpress"},
	SafePossession = {Duration = 3, Roles = {CDM = 34, CM = 28, CB = 24, Fullback = 18}, Movement = "Safe"},
	DefensiveBlock = {Duration = 3, Roles = {CB = 36, CDM = 32, Fullback = 24, CM = 18}, Movement = "Block"},
	CornerProtection = {Duration = 3, Roles = {CB = 40, CDM = 34, Fullback = 26}, Movement = "BoxProtect"},
	SafeCounter = {Duration = 3, Roles = {ST = 34, Winger = 28, CM = 16}, Movement = "SafeCounter"},
	WideBuildUp = {Duration = 3, Roles = {Fullback = 34, Winger = 32, CM = 20, CB = 14}, Movement = "WideBuild"},
	WideOverload = {Duration = 3, Roles = {Winger = 42, Fullback = 32, CM = 22, ST = 12}, Movement = "Overload"},
	CrossingAttack = {Duration = 3, Roles = {ST = 38, Winger = 34, CAM = 22, CM = 16}, Movement = "Cross"},
	CentralTriangle = {Duration = 3, Roles = {CM = 36, CAM = 32, CDM = 24, ST = 18}, Movement = "Triangle"},
	ThirdManRun = {Duration = 3, Roles = {CAM = 36, CM = 28, ST = 24, Winger = 18}, Movement = "ThirdMan"},
	StrikerWallPass = {Duration = 3, Roles = {ST = 40, CAM = 34, CM = 20, Winger = 16}, Movement = "WallPass"},
	DirectOutlet = {Duration = 3, Roles = {ST = 48, Winger = 30, CM = 18, CB = 12}, Movement = "Direct"},
	TargetStrikerReceive = {Duration = 3, Roles = {ST = 46, CAM = 28, Winger = 22}, Movement = "Target"},
	SecondBall = {Duration = 3, Roles = {CM = 34, CDM = 28, CAM = 22}, Movement = "SecondBall"},
	LowBlockShape = {Duration = 3, Roles = {CB = 36, CDM = 32, Fullback = 26, CM = 22}, Movement = "LowBlock"},
	DelayCarrier = {Duration = 3, Roles = {CB = 30, Fullback = 28, CDM = 26, CM = 18}, Movement = "Delay"},
	CounterRelease = {Duration = 3, Roles = {ST = 40, Winger = 34, CM = 16}, Movement = "Release"},
	CommitForward = {Duration = 3, Roles = {ST = 42, Winger = 36, CAM = 30, CM = 22, Fullback = 16}, Movement = "Commit"},
	FastChanceCreation = {Duration = 3, Roles = {ST = 40, Winger = 34, CAM = 28, CM = 18}, Movement = "Chance"},
	FinalPressure = {Duration = 3, Roles = {ST = 38, Winger = 32, CAM = 28, CM = 24, Fullback = 18}, Movement = "FinalPress"},
	OrganizedDefense = {Duration = 3, Roles = {CB = 36, CDM = 30, Fullback = 24, CM = 18}, Movement = "Organized"},
}

local TACTICS = {
	KeepPossession = {"MidfieldProgression", "WingerAttack", "StrikerLinkUp", "DefensiveRecycling", "SecurePossession"},
	CounterAttack = {"FirstForwardPass", "FastWingerAttack", "StrikerCounter", "SecurePossession"},
	HighPress = {"PressTrigger", "Counterpress", "PressRecovery", "OrganizedDefense", "FirstForwardPass"},
	ProtectLead = {"SafePossession", "DefensiveBlock", "CornerProtection", "SafeCounter", "DefensiveRecycling"},
	WingPlay = {"WideBuildUp", "WideOverload", "CrossingAttack", "DefensiveRecycling", "SwitchPlay"},
	CentralCombination = {"CentralTriangle", "ThirdManRun", "StrikerWallPass", "StrikerLinkUp", "MidfieldProgression"},
	DirectPlay = {"DirectOutlet", "TargetStrikerReceive", "SecondBall", "SecurePossession"},
	LowBlockCounter = {"LowBlockShape", "DelayCarrier", "CounterRelease", "FirstForwardPass", "OrganizedDefense"},
	Balanced = {"MidfieldProgression", "WingerAttack", "StrikerLinkUp", "DefensiveRecycling", "FirstForwardPass", "OrganizedDefense"},
	AllOutAttack = {"CommitForward", "FastChanceCreation", "CrossingAttack", "FinalPressure", "Counterpress"},
}

ACTIONS.SwitchPlay = {Duration = 3, Roles = {Winger = 30, Fullback = 26, CM = 22, CDM = 18}, Movement = "Switch"}

local function pressureOf(context: any, info: any?): any
	if not info then return {Closest = math.huge, Under = false, Heavy = false, Score = 0} end
	return AIContextBuilder.Pressure(context, info)
end

local function pitchThird(pitch: Vector3): string
	if pitch.Z < PitchConfig.PITCH_LENGTH / 3 then return "Defensive" end
	if pitch.Z < PitchConfig.PITCH_LENGTH * 2 / 3 then return "Middle" end
	return "Attacking"
end

local function teamTactic(style: any): string
	return TACTIC_BY_PRESET[tostring(style and style.PresetId or "")] or "Balanced"
end

local function actionDefinition(name: string): any
	return ACTIONS[name] or ACTIONS.MidfieldProgression
end

function Service.new()
	return setmetatable({State = {Home = nil, Away = nil}, LastOwner = {Home = nil, Away = nil}, LastPossessionSide = nil}, Service)
end

function Service:Reset(side: string?)
	if side then
		self.State[side] = nil
		self.LastOwner[side] = nil
	else
		self.State = {Home = nil, Away = nil}
		self.LastOwner = {Home = nil, Away = nil}
		self.LastPossessionSide = nil
	end
end

local function scoreAction(context: any, side: string, tactic: string, name: string, phase: string, ownerInfo: any?, previous: any?): number
	local ballPitch = context.BallTeam[side]
	local pressure = pressureOf(context, ownerInfo)
	local third = pitchThird(ballPitch)
	local ownerRole = ownerInfo and ownerInfo.Role or ""
	local score = 0
	if previous and previous.Action == name then score += 8 end
	if phase == "LooseBall" then
		return name == "SecondBall" and 80 or name == "Counterpress" and 70 or name == "OrganizedDefense" and 35 or -20
	end
	if context.OwnerSide ~= side then
		if tactic == "HighPress" then score += name == "PressTrigger" and 85 or name == "PressRecovery" and 38 or name == "OrganizedDefense" and 30 or 0
		elseif tactic == "LowBlockCounter" then score += name == "LowBlockShape" and 80 or name == "DelayCarrier" and 62 or name == "CounterRelease" and 18 or 0
		elseif tactic == "ProtectLead" then score += name == "DefensiveBlock" and 82 or name == "CornerProtection" and (third == "Defensive" and 72 or 20) or 0
		else score += name == "OrganizedDefense" and 54 or name == "PressRecovery" and 32 or 0 end
		return score
	end
	if pressure.Heavy then
		score += (name == "DefensiveRecycling" or name == "SecurePossession" or name == "SafePossession") and 72 or 0
	elseif pressure.Under then
		score += (name == "StrikerLinkUp" or name == "WingerAttack" or name == "SecurePossession") and 22 or 0
	end
	if tactic == "CounterAttack" and context.LastPossessionSide ~= side then score += name == "FirstForwardPass" and 86 or 0 end
	if tactic == "LowBlockCounter" and context.LastPossessionSide ~= side then score += name == "CounterRelease" and 78 or 0 end
	if tactic == "KeepPossession" then
		score += ownerRole == "Winger" and name == "WingerAttack" and 48 or ownerRole == "ST" and name == "StrikerLinkUp" and 48 or (ownerRole == "CM" or ownerRole == "CDM") and name == "MidfieldProgression" and 48 or name == "DefensiveRecycling" and third == "Defensive" and 22 or 0
	elseif tactic == "WingPlay" then
		score += ownerRole == "Winger" and name == "WideOverload" and 62 or ownerRole == "Fullback" and name == "WideBuildUp" and 48 or third == "Attacking" and name == "CrossingAttack" and 48 or 0
	elseif tactic == "CentralCombination" then
		score += (ownerRole == "CM" or ownerRole == "CAM" or ownerRole == "CDM") and name == "CentralTriangle" and 54 or ownerRole == "ST" and name == "StrikerWallPass" and 52 or name == "ThirdManRun" and third ~= "Defensive" and 30 or 0
	elseif tactic == "DirectPlay" then
		score += name == "DirectOutlet" and third ~= "Attacking" and 58 or ownerRole == "ST" and name == "TargetStrikerReceive" and 54 or name == "SecondBall" and 24 or 0
	elseif tactic == "AllOutAttack" then
		score += third == "Attacking" and name == "FastChanceCreation" and 62 or name == "CommitForward" and 50 or name == "FinalPressure" and 28 or 0
	elseif tactic == "ProtectLead" then
		score += name == "SafePossession" and 62 or name == "SafeCounter" and third ~= "Defensive" and 32 or 0
	elseif tactic == "Balanced" then
		score += ownerRole == "Winger" and name == "WingerAttack" and 38 or ownerRole == "ST" and name == "StrikerLinkUp" and 38 or third == "Defensive" and name == "DefensiveRecycling" and 34 or name == "MidfieldProgression" and 26 or 0
	end
	local def = actionDefinition(name)
	score += tonumber(def.Roles[ownerRole]) or 0
	if third == "Attacking" and (name == "CrossingAttack" or name == "FastChanceCreation" or name == "ShootingChance") then score += 24 end
	if third == "Defensive" and (name == "DefensiveRecycling" or name == "SecurePossession" or name == "DirectOutlet") then score += 18 end
	return score
end

local function chooseAction(context: any, side: string, style: any, phase: string, previous: any?): string
	local tactic = teamTactic(style)
	local ownerInfo = context.Owner and context.Players[context.Owner] or nil
	local candidates = TACTICS[tactic] or TACTICS.Balanced
	local bestName = candidates[1]
	local bestScore = -math.huge
	for _, name in ipairs(candidates) do
		local score = scoreAction(context, side, tactic, name, phase, ownerInfo, previous)
		if score > bestScore then
			bestName = name
			bestScore = score
		end
	end
	return bestName
end

function Service:UpdateSide(context: any, side: string, style: any, phase: string): any
	local now = context.Now or os.clock()
	local tactic = teamTactic(style)
	local current = self.State[side]
	local owner = context.OwnerSide == side and context.Owner or nil
	local possessionLost = current and current.OwnerSide == side and context.OwnerSide ~= side
	local ownerChanged = current and current.Owner ~= owner
	local timedOut = not current or now >= (tonumber(current.Until) or 0)
	local emergency = context.LooseBall == true or possessionLost == true or phase == "LooseBall"
	local pressure = owner and pressureOf(context, context.Players[owner]) or nil
	local immediatePressure = pressure and pressure.Heavy == true
	if not current or current.Tactic ~= tactic or emergency or ownerChanged or timedOut or immediatePressure then
		local actionName = chooseAction(context, side, style, phase, current)
		local def = actionDefinition(actionName)
		current = {
			Tactic = tactic,
			Action = actionName,
			Movement = def.Movement,
			Roles = def.Roles,
			StartedAt = now,
			Until = now + math.clamp(tonumber(def.Duration) or 3, 0.8, 3),
			Owner = owner,
			OwnerSide = context.OwnerSide,
			Phase = phase,
			Previous = current and current.Action or nil,
		}
		self.State[side] = current
	end
	return current
end

function Service:Step(context: any, styles: {[string]: any}, phases: {[string]: string}): any
	local stories = {}
	context.LastPossessionSide = self.LastPossessionSide
	for _, side in ipairs({"Home", "Away"}) do
		stories[side] = self:UpdateSide(context, side, styles[side], phases[side] or "LooseBall")
	end
	if context.OwnerSide then self.LastPossessionSide = context.OwnerSide end
	context.TeamStories = stories
	return stories
end

function Service.GetTacticName(style: any): string
	return teamTactic(style)
end

function Service.GetAction(name: string): any
	return actionDefinition(name)
end

return Service
