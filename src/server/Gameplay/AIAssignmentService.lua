--!strict
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)
local AILooseBallService = require(script.Parent.AILooseBallService)
local AIGoalkeeperService = require(script.Parent.AIGoalkeeperService)
local AIDefensiveDecisionService = require(script.Parent.AIDefensiveDecisionService)
local PenaltyBoxService = require(script.Parent.PenaltyBoxService)
local Workspace = game:GetService("Workspace")

local Service = {}
Service.__index = Service

local function asWorld(context: any, side: string, pitch: Vector3): Vector3
	return PitchConfig.TeamPitchPositionToWorld(PitchConfig.ClampInsidePitch(pitch), side, context.Options)
end

local function makeAssignment(context: any, info: any, name: string, pitch: Vector3, urgency: number, sprint: boolean?, faceWorld: Vector3?): any
	local targetWorld = asWorld(context, info.Side, pitch)
	return {
		Model = info.Model,
		Info = info,
		Role = info.Role,
		Zone = info.SpecificRole,
		Phase = "",
		PrimaryAssignment = name,
		MovementTarget = targetWorld,
		TargetWorld = targetWorld,
		TargetPitch = pitch,
		MovementUrgency = urgency,
		SprintAllowed = sprint == true,
		FaceWorld = faceWorld or context.BallWorld,
		MarkTarget = nil,
		SupportTarget = context.Owner,
	}
end

local function baseWithPhase(info: any, phase: string, ballPitch: Vector3, style: any): Vector3
	local base = info.BasePitch
	local advanceBase = math.max(base.Z, ballPitch.Z)
	if phase == "OwnPossession_BuildUp" then
		if info.Role == "CB" then
			return Vector3.new(base.X + (base.X < PitchConfig.HALF_WIDTH and -18 or 18), 3, math.max(78, ballPitch.Z - 35))
		elseif info.Role == "Fullback" then
			local width = style:Ratio("AttackingWidth")
			local wideX = base.X < PitchConfig.HALF_WIDTH and 45 + (1 - width) * 46 or 379 - (1 - width) * 46
			return Vector3.new(wideX, 3, math.max(advanceBase, ballPitch.Z + 28))
		elseif info.Role == "CDM" then
			return Vector3.new(212, 3, math.max(120, ballPitch.Z + 35))
		end
	elseif phase == "Transition_JustWonBall" then
		if info.Role == "ST" or info.Role == "Winger" then
			return Vector3.new(base.X, 3, math.min(690, math.max(base.Z, ballPitch.Z + 115)))
		end
	end
	return base
end

local function defendingBase(info: any, ballPitch: Vector3, style: any): Vector3
	local base = info.BasePitch
	local depth = style:Ratio("DefensiveDepth")
	local lineZ = AIDefensiveDecisionService.LineHeight(ballPitch, depth)
	local function behindBall(offset: number, floorZ: number, ceilingZ: number?): number
		local ceiling = ceilingZ or 520
		return math.clamp(math.min(lineZ + offset, ballPitch.Z - offset), floorZ, ceiling)
	end
	if info.Role == "CB" then
		return Vector3.new(base.X, 3, behindBall(0, 34, 285))
	elseif info.Role == "Fullback" then
		local ballSide = ballPitch.X < PitchConfig.HALF_WIDTH and "Left" or "Right"
		local ownSide = base.X < PitchConfig.HALF_WIDTH and "Left" or "Right"
		local x = ownSide == ballSide and base.X or base.X + (PitchConfig.HALF_WIDTH - base.X) * 0.4
		return Vector3.new(x, 3, behindBall(10, 42, 305))
	elseif info.Role == "CDM" then
		return Vector3.new(212, 3, behindBall(56, 86, 400))
	elseif info.Role == "CM" or info.Role == "CAM" then
		return Vector3.new(base.X + (PitchConfig.HALF_WIDTH - base.X) * 0.22, 3, behindBall(88, 120, 470))
	elseif info.Role == "Winger" then
		local defensiveWidth = style:Ratio("DefensiveWidth")
		local tuckedX = base.X + (PitchConfig.HALF_WIDTH - base.X) * (0.58 - defensiveWidth * 0.24)
		return Vector3.new(tuckedX, 3, behindBall(112, 145, 520))
	elseif info.Role == "ST" then
		return Vector3.new(base.X, 3, behindBall(145, 180, 555))
	end
	return base
end

local function shortSupportTarget(info: any, ballPitch: Vector3, style: any): Vector3
	local sideSign = info.Pitch.X >= ballPitch.X and 1 or -1
	local supportDistance = 34 + style:Ratio("SupportDistance") * 34
	if ballPitch.X < 90 then
		return Vector3.new(ballPitch.X + supportDistance, 3, ballPitch.Z + 15)
	elseif ballPitch.X > 334 then
		return Vector3.new(ballPitch.X - supportDistance, 3, ballPitch.Z + 15)
	end
	return Vector3.new(ballPitch.X + supportDistance * sideSign, 3, ballPitch.Z + 20)
end

local function onsideZ(context:any, side:string, fallback:number):number
	local line=AIContextBuilder.DefensiveLineZ(context,side)
	if line > 90 then
		return math.clamp(math.min(fallback,line-7),0,704)
	end
	return math.clamp(fallback,0,704)
end

local function wideOutletTarget(context:any, info: any, ballPitch: Vector3, style: any): Vector3
	local width = style:Ratio("AttackingWidth")
	local discipline = style:Ratio("WidthDiscipline")
	local left = info.BasePitch.X < PitchConfig.HALF_WIDTH
	local touchlineX = left and 35 or 389
	local wideX = left and 45 + (1 - width) * 55 or 379 - (1 - width) * 55
	wideX = wideX + (touchlineX - wideX) * discipline * 0.38
	return Vector3.new(wideX, 3, onsideZ(context,info.Side,math.min(690, math.max(info.Pitch.Z + 18, info.BasePitch.Z, ballPitch.Z + 40))))
end

local function runBehindTarget(context: any, info: any): Vector3
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, info.Side)
	local currentZ = math.clamp(info.Pitch.Z, 0, 704)
	local safeLine = defensiveLine > 90 and defensiveLine - 7 or 704
	local desiredZ = math.min(math.max(currentZ + 22, defensiveLine - 20), safeLine, 704)
	return Vector3.new(PitchConfig.GetLaneCenter(info.Lane), 3, math.clamp(desiredZ, 0, 704))
end

local function sideOf(infoOrPitch: any): string
	local x = if typeof(infoOrPitch) == "Vector3"
		then infoOrPitch.X
		else ((infoOrPitch.Pitch and infoOrPitch.Pitch.X) or infoOrPitch.X or PitchConfig.HALF_WIDTH)
	if x < PitchConfig.HALF_WIDTH - 35 then
		return "Left"
	elseif x > PitchConfig.HALF_WIDTH + 35 then
		return "Right"
	end
	return "Center"
end

local function sameWideSide(info: any, pitch: Vector3): boolean
	local ballSide = sideOf(pitch)
	return ballSide ~= "Center" and sideOf(info) == ballSide
end

local function ballIsWide(pitch: Vector3): boolean
	return pitch.X < 100 or pitch.X > 324
end

local function ballIsCentral(pitch: Vector3): boolean
	return pitch.X >= 145 and pitch.X <= 279
end

local function carrierFacesForward(context: any, side: string, carrier: any?): boolean
	if not carrier or not carrier.Root then
		return false
	end
	local lookProgress = PitchConfig.GetForwardProgress(carrier.World, carrier.World + carrier.Root.CFrame.LookVector * 8, side, context.Options)
	local velocity = Vector3.new(carrier.Root.AssemblyLinearVelocity.X, 0, carrier.Root.AssemblyLinearVelocity.Z)
	local velocityProgress = velocity.Magnitude > 0.5 and PitchConfig.GetForwardProgress(carrier.World, carrier.World + velocity.Unit * 8, side, context.Options) or 0
	return lookProgress > 1.2 or velocityProgress > 1.2
end

local function teammateByRoleWithBall(ownerInfo: any?, roles: {[string]: boolean}): boolean
	return ownerInfo ~= nil and roles[ownerInfo.Role] == true
end

local function carrierIsPressed(context: any, ownerInfo: any?): boolean
	if not ownerInfo then
		return false
	end
	local pressure = AIContextBuilder.Pressure(context, ownerInfo)
	return pressure.Under or pressure.Heavy or pressure.Closest <= 18
end

local function closestDefenderToCarrier(context: any, info: any, ownerInfo: any?): boolean
	if not ownerInfo or not info.Root then
		return false
	end
	local best: any? = nil
	local bestDistance = math.huge
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Root and not teammate.IsGoalkeeper then
			local distance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)
			if distance < bestDistance then
				bestDistance = distance
				best = teammate
			end
		end
	end
	return best == info
end

local function cbPressed(context: any, side: string): boolean
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Role == "CB" then
			local pressure = AIContextBuilder.Pressure(context, teammate)
			if pressure.Under or pressure.Closest <= 16 then
				return true
			end
		end
	end
	return false
end

local function nearestRoleMarked(context: any, side: string, role: string, distance: number): boolean
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Role == role then
			local _, nearest = AIContextBuilder.NearestOpponent(context, teammate)
			if nearest <= distance then
				return true
			end
		end
	end
	return false
end

local function sideLaneX(info: any, wide: boolean?): number
	local left = info.BasePitch.X < PitchConfig.HALF_WIDTH
	if wide == true then
		return left and 44 or 380
	end
	return left and 118 or 306
end

local function pivotOffset(info: any): number
	local name = tostring(info.SpecificRole or "")
	if string.find(name, "L") then
		return -34
	elseif string.find(name, "R") then
		return 34
	end
	return info.BasePitch.X < PitchConfig.HALF_WIDTH and -28 or 28
end

local function hasDoublePivot(context: any, side: string): boolean
	local count = 0
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Role == "CDM" then
			count += 1
		end
	end
	return count >= 2
end

local function strikerLineZ(context: any, side: string): number
	local highest = 570
	for _, teammate in ipairs(context.Teams[side].List) do
		if teammate.Role == "ST" then
			highest = math.max(highest, teammate.Pitch.Z, teammate.BasePitch.Z)
		end
	end
	return highest
end

local function capBehindStriker(context: any, side: string, target: Vector3, minimumGap: number?): Vector3
	local strikerZ = strikerLineZ(context, side)
	local gap = minimumGap or 45
	return Vector3.new(target.X, target.Y, math.min(target.Z, strikerZ - gap))
end

local function attackingTrailCover(context: any, info: any, ballPitch: Vector3): (string, Vector3)
	local best: any? = nil
	local bestScore = -math.huge
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and (teammate.Role == "ST" or teammate.Role == "CAM" or teammate.Role == "CM") then
			local ahead = teammate.Pitch.Z - ballPitch.Z
			local roleBonus = teammate.Role == "ST" and 38 or teammate.Role == "CAM" and 24 or 14
			local sidePenalty = math.abs(teammate.Pitch.X - info.Pitch.X) * 0.06
			local score = roleBonus + math.max(ahead, -20) * 0.18 - sidePenalty
			if teammate.Pitch.Z >= ballPitch.Z - 18 and score > bestScore then
				best = teammate
				bestScore = score
			end
		end
	end
	if best then
		local behind = best.Role == "ST" and 30 or 24
		local lateral = best.Pitch.X < PitchConfig.HALF_WIDTH and 18 or -18
		local target = Vector3.new(
			math.clamp(best.Pitch.X + lateral, 112, 312),
			3,
			math.clamp(best.Pitch.Z - behind, math.max(175, ballPitch.Z - 44), math.max(230, ballPitch.Z + 42))
		)
		return best.Role == "ST" and "TrailStrikerCover" or "TrailMidfielderCover", target
	end
	local fallbackX = PitchConfig.HALF_WIDTH + (info.BasePitch.X < PitchConfig.HALF_WIDTH and -28 or 28)
	return "TrailingPassBack", Vector3.new(fallbackX, 3, math.max(190, ballPitch.Z - 28))
end

local function cdmTarget(context: any, info: any, ballPitch: Vector3, pressed: boolean, safe: boolean): (string, Vector3, number, boolean)
	local doublePivot = hasDoublePivot(context, info.Side)
	local offset = doublePivot and pivotOffset(info) or 0
	local x = PitchConfig.HALF_WIDTH + offset
	local isBallSide = not doublePivot or (ballPitch.X < PitchConfig.HALF_WIDTH and offset < 0) or (ballPitch.X >= PitchConfig.HALF_WIDTH and offset > 0)
	if cbPressed(context, info.Side) then
		return doublePivot and "DropBesideCenterBacks" or "DropBetweenCenterBacks", Vector3.new(x, 3, 115), 0.82, false
	elseif PenaltyBoxService.IsInsideDefensiveBox(info.Side, context.BallWorld, context.Options) then
		return "ProtectBoxEdge", Vector3.new(x, 3, 118), 0.9, false
	elseif isBallSide and (pressed or ballPitch.Z >= PitchConfig.HALF_LENGTH) then
		return "BallSidePivotSupport", Vector3.new(x, 3, math.max(210, ballPitch.Z - 38)), 0.84, false
	elseif doublePivot then
		local name, target = attackingTrailCover(context, info, ballPitch)
		return name, target, 0.8, false
	elseif safe then
		return "SlightAdvanceReset", Vector3.new(x, 3, math.max(info.BasePitch.Z, ballPitch.Z - 28)), 0.76, false
	end
	return "ResetOption", Vector3.new(x, 3, math.max(120, ballPitch.Z - 48)), 0.82, false
end

local function stadiumAnalysisFolder(): Instance?
	return Workspace:FindFirstChild("VTRStadiumAnalysis", true)
end

local function defensiveBoxPart(defendingSide: string): BasePart?
	local analysis = stadiumAnalysisFolder()
	local name = defendingSide == "Home" and "HomeBox" or "AwayBox"
	local found = analysis and analysis:FindFirstChild(name, true) or Workspace:FindFirstChild(name, true)
	return found and found:IsA("BasePart") and found or nil
end

local function inFrontOfDefensiveDangerZone(context: any, defendingSide: string, attacker: any): boolean
	local box = defensiveBoxPart(defendingSide)
	if box then
		local boxLocal = context.PitchCFrame:PointToObjectSpace(box.Position)
		local threatLocal = context.PitchCFrame:PointToObjectSpace(attacker.World)
		local halfWidth = math.max(box.Size.X, box.Size.Z) * 0.5
		local halfDepth = math.min(box.Size.X, box.Size.Z) * 0.5
		local xMargin = 32
		local zMargin = 60
		local xInside = threatLocal.X >= boxLocal.X - halfWidth - xMargin and threatLocal.X <= boxLocal.X + halfWidth + xMargin
		local zInside
		if boxLocal.Z >= 0 then
			zInside = threatLocal.Z <= boxLocal.Z - halfDepth and threatLocal.Z >= boxLocal.Z - halfDepth - zMargin
		else
			zInside = threatLocal.Z >= boxLocal.Z + halfDepth and threatLocal.Z <= boxLocal.Z + halfDepth + zMargin
		end
		return xInside and zInside
	end
	local zone = PitchConfig.Zones.OwnBox
	local threatPitch = PitchConfig.WorldToTeamPitchPosition(attacker.World, defendingSide, context.Options)
	local xMargin = 24
	return threatPitch.X >= zone.XMin - xMargin
		and threatPitch.X <= zone.XMax + xMargin
		and threatPitch.Z >= zone.ZMax
		and threatPitch.Z <= zone.ZMax + 60
end

local function boxStrikerThreat(context: any, defendingSide: string): any?
	local best = nil
	local bestScore = -math.huge
	for _, attacker in ipairs(context.Teams[defendingSide == "Home" and "Away" or "Home"].List) do
		if attacker.Root and inFrontOfDefensiveDangerZone(context, defendingSide, attacker) then
			local distanceToBall = PitchConfig.GetDistanceStuds(attacker.World, context.BallWorld)
			local hasBall = context.Owner == attacker.Model
			local roleBonus = attacker.Role == "ST" and 24 or attacker.Role == "CAM" and 16 or attacker.Role == "Winger" and 8 or 0
			local score = (hasBall and 120 or 0) + roleBonus - distanceToBall
			if score > bestScore then
				best = attacker
				bestScore = score
			end
		end
	end
	return best
end

local function centerBackRankToThreat(context: any, info: any, threat: any): number
	local rank = 1
	local distance = PitchConfig.GetDistanceStuds(info.World, threat.World)
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Role == "CB" and teammate.Model ~= info.Model and teammate.Root then
			local teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, threat.World)
			if teammateDistance < distance then
				rank += 1
			end
		end
	end
	return rank
end

local function markBetweenGoalAndThreat(threatPitch: Vector3, gap: number): Vector3
	return PitchConfig.ClampInsidePitch(Vector3.new(threatPitch.X, 3, math.max(32, threatPitch.Z - gap)))
end

local function strikerThreatVeryDangerous(context: any, defendingSide: string, threat: any): boolean
	if context.Owner ~= threat.Model then
		return false
	end
	local facingGoal = carrierFacesForward(context, threat.Side, threat)
	local central = threat.Pitch.X > 120 and threat.Pitch.X < 304
	local _, nearest = AIContextBuilder.NearestOpponent(context, threat)
	return facingGoal or central or nearest > 14
end

local function defensiveCdmTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean, Model?)
	local doublePivot = hasDoublePivot(context, info.Side)
	local offset = doublePivot and pivotOffset(info) or 0
	local x = PitchConfig.HALF_WIDTH + offset
	local ballSidePivot = not doublePivot or (ballPitch.X < PitchConfig.HALF_WIDTH and offset < 0) or (ballPitch.X >= PitchConfig.HALF_WIDTH and offset > 0)
	if PenaltyBoxService.IsInsideDefensiveBox(info.Side, context.BallWorld, context.Options) then
		return "ProtectPenaltySpot", Vector3.new(x, 3, 122), 0.9, false, nil
	elseif PenaltyBoxService.IsNearDefensiveBox(info.Side, context.BallWorld, context.Options, 32) then
		return ballSidePivot and "BlockBoxEntryLane" or "ScreenCenterBacks", Vector3.new(x, 3, ballSidePivot and math.max(130, ballPitch.Z - 22) or 120), 0.86, ballSidePivot, ownerInfo and ownerInfo.Model or nil
	elseif ballIsCentral(ballPitch) and ballPitch.Z >= 170 and ballPitch.Z <= 420 and ballSidePivot then
		return "StepIntoMiddleZone", Vector3.new(x, 3, math.max(118, ballPitch.Z - 18)), 0.86, true, ownerInfo and ownerInfo.Model or nil
	end
	return "ScreenCenterBacks", Vector3.new(x, 3, math.max(112, math.min(260, ballPitch.Z - (ballSidePivot and 34 or 66)))), 0.78, false, nil
end

local function pressureRank(context: any, info: any, ownerInfo: any): number
	local rank = 1
	local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and not teammate.IsGoalkeeper then
			local teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)
			if teammateDistance < distance then
				rank += 1
			end
		end
	end
	return rank
end

local function midfieldPressRank(context: any, info: any, ownerInfo: any): number
	local rank = 1
	local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
	for _, teammate in ipairs(context.Teams[info.Side].List) do
		if teammate.Model ~= info.Model and teammate.Root and (teammate.Role == "CDM" or teammate.Role == "CM" or teammate.Role == "CAM") then
			local teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)
			if teammateDistance < distance then
				rank += 1
			end
		end
	end
	return rank
end

local function attackingRoleTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean)
	local pressed = carrierIsPressed(context, ownerInfo)
	local safe = not pressed
	local facingForward = carrierFacesForward(context, info.Side, ownerInfo)
	local ballNearAttackingBox = PenaltyBoxService.IsNearAttackingBox(info.Side, context.BallWorld, context.Options, 36)
	local ballInsideAttackingBox = PenaltyBoxService.IsInsideAttackingBox(info.Side, context.BallWorld, context.Options)
	local ballWideNearGoal = ballIsWide(ballPitch) and ballNearAttackingBox
	local defensiveLine = AIContextBuilder.DefensiveLineZ(context, info.Side)
	local highDefensiveLine = defensiveLine >= 430
	local ownerSameSideWinger = ownerInfo and ownerInfo.Role == "Winger" and sameWideSide(ownerInfo, info.BasePitch)
	local ownerFullbackOrCM = ownerInfo and (ownerInfo.Role == "Fullback" or ownerInfo.Role == "CM") and sameWideSide(info, ownerInfo.Pitch)
	local ownerCMOrCDM = teammateByRoleWithBall(ownerInfo, {CM = true, CDM = true})
	local stMarked = nearestRoleMarked(context, info.Side, "ST", 16)
	local base = info.BasePitch
	local wingerHasBallWide = ownerInfo and ownerInfo.Role == "Winger" and ballIsWide(ownerInfo.Pitch)
	local ballInAttackingHalf = ballPitch.Z >= PitchConfig.HALF_LENGTH
	local ballSide = sideOf(ballPitch)
	local infoSide = sideOf(info)
	local ballSideSupportX = ballPitch.X + (ballPitch.X < PitchConfig.HALF_WIDTH and 38 or -38)
	local farPostX = ballPitch.X < PitchConfig.HALF_WIDTH and 306 or 118

	if info.Role == "CB" then
		if pressed then
			return "ResetDrop", Vector3.new(base.X, 3, math.max(55, math.min(base.Z, ballPitch.Z - 95))), 0.78, false
		end
		if ballPitch.Z > info.Pitch.Z + 70 then
			return "StayBackCover", Vector3.new(base.X, 3, math.max(80, math.min(base.Z + 55, ballPitch.Z - 105))), 0.72, false
		end
		local step = Vector3.new(base.X, 3, math.min(base.Z + 90, ballPitch.Z + 42))
		if safe and AIContextBuilder.SpaceAt(context, info.Side, step, 22) then
			return "CarryIfFree", step, 0.84, true
		end
		return "StayBackCover", Vector3.new(base.X, 3, math.max(80, math.min(base.Z + 45, ballPitch.Z - 75))), 0.72, false
	elseif info.Role == "Fullback" then
		if wingerHasBallWide and sameWideSide(info, ballPitch) then
			return "WingerBackOption", Vector3.new(sideLaneX(info, true), 3, math.max(155, ballPitch.Z - 42)), 0.88, false
		end
		if ownerSameSideWinger then
			local oppositeSideAttacking = false
			for _, teammate in ipairs(context.Teams[info.Side].List) do
				if teammate.Role == "Fullback" and teammate.Model ~= info.Model and teammate.Pitch.Z > ballPitch.Z + 18 then
					oppositeSideAttacking = true
					break
				end
			end
			if not oppositeSideAttacking then
				return "OverlapRun", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, ballPitch.Z + 78)), 0.92, true
			end
		end
		if pressed then
			return "CoverCenterBack", Vector3.new(sideLaneX(info, false), 3, math.max(75, ballPitch.Z - 70)), 0.78, false
		end
		return "HoldFullbackLine", Vector3.new(base.X, 3, math.max(base.Z, math.min(ballPitch.Z - 28, 315))), 0.72, false
	elseif info.Role == "CDM" then
		return cdmTarget(context, info, ballPitch, pressed or wingerHasBallWide, safe)
	elseif info.Role == "CM" then
		if wingerHasBallWide and infoSide == ballSide then
			return "InsideTriangleSupport", Vector3.new(math.clamp(ballSideSupportX, 125, 299), 3, math.clamp(ballPitch.Z + 4, 440, 594)), 0.94, true
		elseif wingerHasBallWide then
			return "FarSideSwitchOption", Vector3.new(math.clamp(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.5, 145, 279), 3, math.clamp(ballPitch.Z + 16, 450, 584)), 0.86, true
		elseif ballWideNearGoal then
			return "HoldEdgeOfBox", Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.45, 3, 548), 0.8, false
		elseif pressed then
			return "ComeShort", shortSupportTarget(info, ballPitch, style), 0.86, info.Stamina > 42
		elseif facingForward then
			return "ForwardMidfieldRun", Vector3.new(PitchConfig.GetLaneCenter(info.Lane), 3, onsideZ(context, info.Side, ballPitch.Z + 78)), 0.92, true
		end
		return "MidfieldSupport", Vector3.new(base.X, 3, math.max(base.Z, ballPitch.Z + 38)), 0.82, true
	elseif info.Role == "CAM" then
		if wingerHasBallWide then
			local cutbackZ = ballInsideAttackingBox and 584 or 552
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH, 3, cutbackZ), 35)
			return "CentralCutbackOption", target, 0.92, true
		elseif ballInAttackingHalf and ballIsWide(ballPitch) then
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH + (ballPitch.X < PitchConfig.HALF_WIDTH and -24 or 24), 3, math.clamp(ballPitch.Z + 18, 470, 590)), 40)
			return "RoamForCutback", target, 0.88, true
		elseif ballInAttackingHalf and ballIsCentral(ballPitch) then
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(455, ballPitch.Z + 38))), 45)
			return "RoamBetweenLines", target, 0.86, false
		elseif ownerCMOrCDM then
			local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, ballPitch.Z + 62)), 45)
			return "BetweenDefenders", target, 0.9, true
		elseif stMarked then
			return "ComeShort", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(280, ballPitch.Z - 22)), 0.84, false
		end
		local target = capBehindStriker(context, info.Side, Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 42))), 45)
		return "BetweenLines", target, 0.82, false
	elseif info.Role == "Winger" then
		if wingerHasBallWide and ownerInfo and ownerInfo.Model ~= info.Model and not sameWideSide(info, ballPitch) then
			return "AttackBackPost", Vector3.new(farPostX, 3, math.clamp(ballPitch.Z + 28, 610, 670)), 0.96, true
		end
		if ownerFullbackOrCM and highDefensiveLine then
			return "RunBehindWide", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, ballPitch.Z + 95)), 1, true
		elseif pressed then
			return "ComeShortWide", Vector3.new(sideLaneX(info, true), 3, math.max(210, ballPitch.Z - 24)), 0.86, info.Stamina > 38
		elseif ballIsCentral(ballPitch) then
			return "StayWide", Vector3.new(sideLaneX(info, true), 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 58))), 0.86, true
		end
		local outlet = wideOutletTarget(context, info, ballPitch, style)
		return "WideOutlet", Vector3.new(outlet.X, 3, math.max(outlet.Z, ballPitch.Z + 48)), 0.86, info.Stamina > 35
	elseif info.Role == "ST" then
		if wingerHasBallWide or ballWideNearGoal then
			local nearPostX = ballPitch.X < PitchConfig.HALF_WIDTH and 176 or 248
			local strikerX = ballInsideAttackingBox and nearPostX or PitchConfig.HALF_WIDTH
			return "AttackBox", Vector3.new(strikerX, 3, math.clamp(ballPitch.Z + 30, 615, 656)), 0.96, true
		end
		local _, nearest = AIContextBuilder.NearestOpponent(context, info)
		local tightlyMarked = nearest <= 13
		if safe and facingForward then
			return "RunBehind", runBehindTarget(context, info), 1, true
		elseif tightlyMarked or not facingForward then
			return "ComeShort", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(340, ballPitch.Z - 30)), 0.84, false
		end
		return "PinCenterBacks", Vector3.new(PitchConfig.HALF_WIDTH, 3, onsideZ(context, info.Side, math.max(base.Z, ballPitch.Z + 62))), 0.88, true
	end

	return "HoldShape", baseWithPhase(info, "OwnPossession_BuildUp", ballPitch, style), 0.72, false
end

local function defensiveRoleTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean, Model?)
	local base = defendingBase(info, ballPitch, style)
	local ballSide = sideOf(ballPitch)
	local sameSide = sameWideSide(info, ballPitch)
	local ownerRole = ownerInfo and ownerInfo.Role or ""
	local ownerPitch = ballPitch
	local faceModel = ownerInfo and ownerInfo.Model or nil
	local boxThreat = boxStrikerThreat(context, info.Side)
	local ballNearDefensiveBox = PenaltyBoxService.IsNearDefensiveBox(info.Side, context.BallWorld, context.Options, 60)
	local pressPaused = context.PressPaused and context.PressPaused[info.Side] == true
	local carrierHasCarriedIntoSpace = ownerInfo and ownerInfo.Model:GetAttribute("AICarryIntoSpace") == true and (tonumber(ownerInfo.Model:GetAttribute("AICarriedFor")) or 0) >= 2
	local carrierDistance = ownerInfo and PitchConfig.GetDistanceStuds(info.World, ownerInfo.World) or math.huge
	local defensiveHalfPressure = ownerInfo ~= nil and ballPitch.Z <= PitchConfig.HALF_LENGTH
	local defensiveThirdPressure = ownerInfo ~= nil and ballPitch.Z <= PitchConfig.HALF_LENGTH
	if ownerInfo and not pressPaused and defensiveHalfPressure then
		if info.Role == "CB" and (ownerRole == "ST" or ownerRole == "CAM") and carrierDistance <= 115 then
			return "AggressiveCBPressStriker", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif info.Role == "Fullback" and (ownerRole == "Winger" or ownerRole == "LW" or ownerRole == "RW") and sameSide and carrierDistance <= 105 then
			return "AggressiveFullbackPressWinger", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif defensiveThirdPressure and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") and carrierDistance <= 110 then
			local rank = midfieldPressRank(context, info, ownerInfo)
			if rank == 1 then
				return "AggressiveMidfieldPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
			elseif rank == 2 and carrierDistance <= 105 then
				return "AggressiveMidfieldCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.94, true, faceModel
			end
		end
	end
	local defensiveThird = ownerInfo ~= nil and ballPitch.Z <= 245
	if ownerInfo and not pressPaused and defensiveThird then
		if info.Role == "CB" and (ownerRole == "ST" or ownerRole == "CAM") then
			return "AttackStrikerInDefensiveThird", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif info.Role == "Fullback" and (ownerRole == "Winger" or ownerRole == "LW" or ownerRole == "RW") and sameSide then
			return "PressWingerInDefensiveThird", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then
			local rank = midfieldPressRank(context, info, ownerInfo)
			if rank == 1 then
				return "MidfielderDefensiveThirdPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
			elseif rank == 2 then
				return "MidfielderDefensiveThirdCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.92, true, faceModel
			end
		end
	end
	if ownerInfo and not pressPaused and boxThreat and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then
		local rank = midfieldPressRank(context, info, ownerInfo)
		if rank == 1 then
			return "MidfieldBoxPress", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif rank == 2 then
			return "SecondMidfielderBoxCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.92, true, faceModel
		end
	end
	if ownerInfo and not pressPaused and not boxThreat and (info.Role == "CDM" or info.Role == "CM" or info.Role == "CAM") then
		local rank = midfieldPressRank(context, info, ownerInfo)
		local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
		if rank == 1 and distance <= 70 then
			return "MidfieldPressRotation", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif rank == 2 and distance <= 92 then
			return "SecondMidfielderCover", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.9, true, faceModel
		else
			local screenX = info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.28
			return "OrganizeMidfieldPress", Vector3.new(screenX, 3, math.clamp(ballPitch.Z + 26, 155, 430)), 0.84, true, faceModel
		end
	end
	if ownerInfo and not pressPaused and not boxThreat and carrierHasCarriedIntoSpace and closestDefenderToCarrier(context, info, ownerInfo) then
		return "CloseLongCarryGap", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
	end
	if ownerInfo and not pressPaused and not boxThreat then
		local rank = pressureRank(context, info, ownerInfo)
		local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
		if rank == 1 and distance <= 20 then
			return "PressBallCarrier", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif rank == 2 and distance <= 38 then
			return "CoverPresser", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.88, true, faceModel
		end
	end

	if info.Role == "ST" then
		if not pressPaused and ballPitch.Z >= 520 and (ownerRole == "CB" or ownerRole == "GK" or ballPitch.Z >= 610) then
			return "PressCenterBackOrKeeper", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		end
		return "BlockDefensiveMidfielder", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.clamp(ballPitch.Z + 95, 330, 560)), 0.8, false, nil
	elseif info.Role == "Winger" then
		if not pressPaused and ballSide ~= "Center" and sameSide and ballPitch.Z >= 220 then
			return "PressFullback", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.94, true, faceModel
		elseif sameSide and ballPitch.Z < 220 then
			return "TrackOverlap", Vector3.new(sideLaneX(info, true), 3, math.max(95, ballPitch.Z - 18)), 0.9, true, nil
		elseif ballPitch.Z < 170 then
			return "CounterOutlet", Vector3.new(sideLaneX(info, true), 3, 285), 0.72, false, nil
		end
		return "RecoverWideMidfield", Vector3.new(sideLaneX(info, true), 3, base.Z), 0.76, false, nil
	elseif info.Role == "CAM" then
		if not pressPaused and ballIsCentral(ballPitch) and ballPitch.Z >= 235 then
			return "PressCentralMidfield", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.9, true, faceModel
		end
		return "DropIntoMidfield", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.clamp(ballPitch.Z + 48, 250, 430)), 0.78, false, nil
	elseif info.Role == "CM" then
		if not pressPaused and ownerRole == "CM" and PitchConfig.GetDistanceStuds(info.World, ownerInfo.World) <= 44 then
			return "StepToMidfielder", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.9, true, faceModel
		elseif (ownerRole == "CAM" or ownerRole == "ST") and ballPitch.Z <= 360 then
			return "DropBetweenLines", Vector3.new(info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.3, 3, math.clamp(ballPitch.Z + 36, 165, 360)), 0.84, false, nil
		end
		return "ShiftBallSide", Vector3.new(info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.42, 3, base.Z), 0.78, false, nil
	elseif info.Role == "CDM" then
		return defensiveCdmTarget(context, info, ballPitch, ownerInfo, style)
	elseif info.Role == "Fullback" then
		if ballSide ~= "Center" and sameSide then
			if ballPitch.Z < info.Pitch.Z - 12 then
				return "RecoverRunnerBehind", Vector3.new(sideLaneX(info, true), 3, math.max(42, ballPitch.Z - 20)), 0.96, true, faceModel
			end
			local containZ = math.clamp(ownerPitch.Z - 16, 58, 320)
			local containX = sideLaneX(info, true) + (PitchConfig.HALF_WIDTH - sideLaneX(info, true)) * 0.14
			return "ShadowWingerForcePass", Vector3.new(containX, 3, containZ), 0.86, true, faceModel
		elseif ballSide ~= "Center" then
			return "TuckInside", Vector3.new(sideLaneX(info, false), 3, base.Z), 0.78, false, nil
		end
		if ownerInfo and ballSide ~= "Center" and sameSide and carrierDistance <= 95 then
			return "AggressiveFullbackStepOut", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.96, true, faceModel
		end
		return "HoldFullbackLine", base, 0.74, false, nil
	elseif info.Role == "CB" then
		if boxThreat and (ballNearDefensiveBox or context.Owner == boxThreat.Model) then
			local rank = centerBackRankToThreat(context, info, boxThreat)
			local threatPitch = PitchConfig.WorldToTeamPitchPosition(boxThreat.World, info.Side, context.Options)
			local dangerous = strikerThreatVeryDangerous(context, info.Side, boxThreat)
			if rank == 1 then
				return "MarkStriker", markBetweenGoalAndThreat(threatPitch, 7), 1, true, boxThreat.Model
			elseif dangerous then
				return "CollapseOnStriker", markBetweenGoalAndThreat(threatPitch, 14), 0.94, true, boxThreat.Model
			end
			return "ProtectGoalCenter", Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(38, threatPitch.Z - 22)), 0.86, false, boxThreat.Model
		elseif ownerRole == "ST" and ballPitch.Z <= 285 then
			return "StepToStrikerFeet", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		elseif ownerPitch.Z < info.Pitch.Z - 12 then
			return "RunBackWithAttacker", Vector3.new(info.BasePitch.X, 3, math.max(36, ownerPitch.Z - 18)), 0.96, true, faceModel
		end
		if ownerInfo and ownerRole ~= "" and ballPitch.Z <= 285 and carrierDistance <= 110 then
			return "AggressiveCBStepOut", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.96, true, faceModel
		end
		return "HoldCenterBackLine", Vector3.new(info.BasePitch.X, 3, base.Z), 0.76, false, nil
	end

	return "RecoverShape", base, 0.74, false, nil
end

local function depthStep(currentZ: number, desiredZ: number, maxStep: number): number
	local delta = math.clamp(desiredZ - currentZ, -maxStep, maxStep)
	return currentZ + delta
end

local function simpleDefensiveShapeTarget(info: any, ballPitch: Vector3, base: Vector3, style: any): Vector3
	local depth = style:Ratio("DefensiveDepth")
	local lineZ = AIDefensiveDecisionService.LineHeight(ballPitch, depth)
	if info.Role == "ST" then
		local desiredZ = math.clamp(ballPitch.Z + 95, 330, 560)
		return Vector3.new(PitchConfig.HALF_WIDTH, 3, depthStep(info.Pitch.Z, desiredZ, 28))
	elseif info.Role == "Winger" then
		local desiredZ = math.clamp(ballPitch.Z + 105, 180, 520)
		return Vector3.new(sideLaneX(info, true), 3, depthStep(info.Pitch.Z, desiredZ, 30))
	elseif info.Role == "CAM" then
		local desiredZ = math.clamp(ballPitch.Z + 58, 210, 430)
		return Vector3.new(PitchConfig.HALF_WIDTH, 3, depthStep(info.Pitch.Z, desiredZ, 26))
	elseif info.Role == "CM" then
		local desiredZ = math.clamp(lineZ + 86, 130, 405)
		return Vector3.new(info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.32, 3, depthStep(info.Pitch.Z, desiredZ, 24))
	elseif info.Role == "CDM" then
		local desiredZ = math.clamp(lineZ + 50, 88, 335)
		return Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.18, 3, depthStep(info.Pitch.Z, desiredZ, 22))
	elseif info.Role == "Fullback" then
		local tuckedX = info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.18
		local desiredZ = math.clamp(lineZ + 18, 48, 292)
		return Vector3.new(tuckedX, 3, depthStep(info.Pitch.Z, desiredZ, 22))
	elseif info.Role == "CB" then
		local desiredZ = math.clamp(lineZ, 34, 255)
		return Vector3.new(info.BasePitch.X, 3, depthStep(info.Pitch.Z, desiredZ, 20))
	end
	return base
end

local function defensiveRestBlockTarget(info: any): Vector3
	if info.Role == "ST" then
		return Vector3.new(PitchConfig.HALF_WIDTH, 3, 555)
	elseif info.Role == "Winger" then
		return Vector3.new(sideLaneX(info, true), 3, 505)
	elseif info.Role == "CAM" then
		return Vector3.new(PitchConfig.HALF_WIDTH, 3, 465)
	elseif info.Role == "CM" then
		return Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.18, 3, 390)
	elseif info.Role == "CDM" then
		return Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.2, 3, 330)
	elseif info.Role == "Fullback" then
		return Vector3.new(info.BasePitch.X + (PitchConfig.HALF_WIDTH - info.BasePitch.X) * 0.16, 3, 285)
	elseif info.Role == "CB" then
		return Vector3.new(info.BasePitch.X, 3, 245)
	end
	return info.BasePitch
end

local function simpleDefensiveRoleTarget(context: any, info: any, ballPitch: Vector3, ownerInfo: any?, style: any): (string, Vector3, number, boolean, Model?)
	local base = defendingBase(info, ballPitch, style)
	local pressState = context.DefensivePress and context.DefensivePress[info.Side] or nil
	local ownerPitch = ownerInfo and PitchConfig.WorldToTeamPitchPosition(ownerInfo.World, info.Side, context.Options) or ballPitch
	local faceModel = ownerInfo and ownerInfo.Model or nil
	local shadow = pressState and pressState.Shadow and pressState.Shadow[info.Model]
	local ballInDefensiveThird = ballPitch.Z <= PitchConfig.Zones.DefensiveThird.ZMax

	if shadow and shadow.Target and context.Players[shadow.Target] then
		local oldInfo = context.Players[shadow.Target]
		local oldPitch = PitchConfig.WorldToTeamPitchPosition(oldInfo.World, info.Side, context.Options)
		local sideOffset = info.Pitch.X < oldPitch.X and -10 or 10
		local target = Vector3.new(
			math.clamp(oldPitch.X + sideOffset, 0, PitchConfig.PITCH_WIDTH),
			3,
			math.clamp(oldPitch.Z - 8, 34, 520)
		)
		return "PostPressShadow", target, 0.86, true, oldInfo.Model
	end

	if ownerInfo and ballInDefensiveThird then
		if info.Role == "CB" and ownerInfo.Role == "ST" then
			return "CenterBackPressureStriker", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel
		end
		if info.Role == "Fullback" and ownerInfo.Role == "Winger" and sameWideSide(info, ownerPitch) then
			return "FullbackPressureWinger", AIDefensiveDecisionService.ContainTarget(ownerPitch), 0.98, true, faceModel
		end
	end

	if pressState and pressState.Active and pressState.Primary == info.Model and ownerInfo then
		local distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)
		local target = distance <= 10 and ownerPitch or AIDefensiveDecisionService.ContainTarget(ownerPitch)
		return "PrimaryPressRotation", target, 1, true, faceModel
	end

	if ballPitch.Z >= PitchConfig.PITCH_LENGTH * (2 / 3) then
		return "DefensiveRestBlock", defensiveRestBlockTarget(info), 0.72, false, nil
	end

	return "DefensiveShape", simpleDefensiveShapeTarget(info, ballPitch, base, style), 0.82, false, nil
end

function Service.new(style: any)
	return setmetatable({Style = style}, Service)
end

function Service:_assignLoose(context: any, side: string, phase: string, assignments: any)
	local chaser, cover = AILooseBallService.ChooseChasers(context, side)
	local projected = AILooseBallService.ProjectBall(context, 0.22)
	local ballPitch = context.BallTeam[side]
	for _, info in ipairs(context.Teams[side].List) do
		local assignment
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.7, false)
		elseif info == chaser then
			assignment = makeAssignment(context, info, "ChaseLooseBall", PitchConfig.WorldToTeamPitchPosition(projected, side, context.Options), 1, true)
		elseif info == cover then
			assignment = makeAssignment(context, info, "CoverLooseBall", Vector3.new(ballPitch.X, 3, math.max(35, ballPitch.Z - 34)), 0.82, true)
		elseif info.Role == "ST" or info.Role == "Winger" then
			assignment = makeAssignment(context, info, "PrepareCounter", Vector3.new(info.BasePitch.X, 3, math.min(690, math.max(info.BasePitch.Z, ballPitch.Z + 80))), 0.78, true)
		elseif PitchConfig.InZone(ballPitch, "OwnBox") and (info.Role == "CB" or info.Role == "CDM") then
			assignment = makeAssignment(context, info, "ProtectGoal", Vector3.new(info.BasePitch.X, 3, 70), 0.86, true)
		else
			assignment = makeAssignment(context, info, "RecoverShape", defendingBase(info, ballPitch, self.Style), 0.74, false)
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:_assignAttack(context: any, side: string, phase: string, assignments: any)
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	local ballPitch = context.BallTeam[side]
	local list = context.Teams[side].List

	for _, info in ipairs(list) do
		local assignment
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.62, false)
		elseif info.Model == owner then
			assignment = makeAssignment(context, info, "BallCarrierDecision", info.Pitch + Vector3.new(0, 0, 18), 1, true)
		else
			local name, target, urgency, sprint = attackingRoleTarget(context, info, ballPitch, ownerInfo, self.Style)
			if phase == "Transition_JustWonBall" and (info.Role == "ST" or info.Role == "Winger") and target.Z > ballPitch.Z then
				name = "CounterSprint"
				urgency = math.max(urgency, 0.94)
				sprint = true
			end
			assignment = makeAssignment(context, info, name, target, urgency, sprint)
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:_assignDefense(context: any, side: string, phase: string, assignments: any)
	local owner = context.Owner
	local ownerInfo = owner and context.Players[owner]
	local ballPitch = context.BallTeam[side]
	for _, info in ipairs(context.Teams[side].List) do
		local assignment
		if info.IsGoalkeeper then
			local target = PitchConfig.WorldToTeamPitchPosition(AIGoalkeeperService.PositionTarget(context, info), side, context.Options)
			assignment = makeAssignment(context, info, "GoalkeeperPosition", target, 0.72, false)
		else
			local name, target, urgency, sprint, mark = simpleDefensiveRoleTarget(context, info, ballPitch, ownerInfo, self.Style)
			assignment = makeAssignment(context, info, name, target, urgency, sprint, ownerInfo and ownerInfo.World or context.BallWorld)
			if mark then
				assignment.MarkTarget = mark
			end
		end
		assignment.Phase = phase
		assignments[info.Model] = assignment
	end
end

function Service:Build(context: any, phases: {[string]: string}): any
	local assignments: any = {Home = {}, Away = {}}
	for _, side in ipairs({"Home", "Away"}) do
		local phase = phases[side] or "LooseBall"
		assignments[side] = self:BuildSide(context, side, phase)
	end
	return assignments
end

function Service:BuildSide(context: any, side: string, phase: string): any
	local assignments = {}
	if phase == "LooseBall" then
		self:_assignLoose(context, side, phase, assignments)
	elseif context.OwnerSide == side then
		self:_assignAttack(context, side, phase, assignments)
	else
		self:_assignDefense(context, side, phase, assignments)
	end
	return assignments
end

return Service
