--!strict

local Plan = {}
local PitchConfig = require(script.Parent.Parent.PitchConfig)

local function dutyHold(duty: string): number
	if duty == "PrimaryPress" then return .72 end
	if duty == "CoverPress" then return .9 end
	if duty == "MidfieldPressSupport" then return .95 end
	if duty == "PivotLaneBlock" or duty == "CentralLaneBlock" then return 1.15 end
	if duty == "CutbackProtect" or duty == "FarPostProtect" then return 1.55 end
	return 1.05
end

local function nearestOpponent(context: any, side: string, predicate: ((any) -> boolean)?): any?
	local opponentSide = side == "Home" and "Away" or "Home"
	local ball = context.BallTeam[side]
	local best = nil
	local bestScore = math.huge
	for _, info in ipairs(((context.Teams or {})[opponentSide] or {}).List or {}) do
		if info.Root and (not predicate or predicate(info)) then
			local inFrame = PitchConfig.WorldToTeamPitchPosition(info.World, side, context.Options)
			local distance = PitchConfig.GetDistanceStuds(inFrame, ball)
			local centralBonus = math.abs(inFrame.X - PitchConfig.HALF_WIDTH) < 72 and -12 or 0
			local score = distance + centralBonus
			if score < bestScore then
				best = {Info = info, Pitch = inFrame, World = info.World}
				bestScore = score
			end
		end
	end
	return best
end

local function assignmentDistance(context: any, model: Model, targetPitch: Vector3): number
	local info = context.Players and context.Players[model]
	if not info then return math.huge end
	local pitch = info.Pitch
	return PitchConfig.GetDistanceStuds(pitch, targetPitch)
end

local function pickAssigned(context: any, assignments: any, targetPitch: Vector3, used: {[Model]: boolean}, predicate: (any, any) -> boolean): Model?
	local best = nil
	local bestScore = math.huge
	for model, assignment in pairs(assignments) do
		if not used[model] then
			local info = context.Players and context.Players[model]
			if info and info.Root and predicate(info, assignment) then
				local score = assignmentDistance(context, model, targetPitch)
				if score < bestScore then
					best = model
					bestScore = score
				end
			end
		end
	end
	if best then used[best] = true end
	return best
end

local function setPitchTarget(context: any, side: string, assignment: any, pitch: Vector3, primary: string, urgency: number, sprint: boolean)
	local target = PitchConfig.ClampInsidePitch(pitch)
	assignment.PrimaryAssignment = primary
	assignment.TargetPitch = target
	assignment.TargetWorld = PitchConfig.TeamPitchPositionToWorld(target, side, context.Options)
	assignment.MovementTarget = assignment.TargetWorld
	assignment.MovementUrgency = urgency
	assignment.SprintAllowed = sprint
end

function Plan.Apply(context: any, side: string, assignments: any, intent: any, block: any, dutyState: any?)
	local primaryUsed = false
	local now = context.Now or os.clock()
	local carrier = context.Owner and context.Players[context.Owner]
	local carrierPitch = carrier and PitchConfig.WorldToTeamPitchPosition(carrier.World, side, context.Options) or context.BallTeam[side]
	local nearestMidfielder = nearestOpponent(context, side, function(info: any): boolean
		return info.Role == "CM" or info.Role == "CDM" or info.Role == "CAM"
	end)
	local nearestForwardOutlet = nearestOpponent(context, side, function(info: any): boolean
		return info.Role == "ST" or info.Role == "Winger" or info.Role == "CAM"
	end)
	local highPress = tostring(intent and intent.Intent or "") == "HighPress"
	for model, assignment in pairs(assignments) do
		local slot = assignment.TacticalSlot
		if slot and slot.Id == "primary-presser" and not primaryUsed then
			primaryUsed = true
			assignment.PrimaryAssignment = "PressBallCarrier"
			assignment.MovementUrgency = 1
			assignment.SprintAllowed = true
			if block and carrier then
				local target = slot.TargetPitch
				local force = tostring(block.ForceDirection or "")
				if force == "TouchlineLeft" then
					target = Vector3.new(math.max(28, carrierPitch.X - 10), 3, math.max(28, carrierPitch.Z - 2))
				elseif force == "TouchlineRight" then
					target = Vector3.new(math.min(396, carrierPitch.X + 10), 3, math.max(28, carrierPitch.Z - 2))
				else
					target = Vector3.new(carrierPitch.X, 3, math.max(28, carrierPitch.Z - 8))
				end
				assignment.TargetPitch = target
				assignment.TargetWorld = context.Options and PitchConfig.TeamPitchPositionToWorld(target, side, context.Options) or assignment.TargetWorld
				assignment.MovementTarget = assignment.TargetWorld
				assignment.FaceWorld = carrier.World
			end
			model:SetAttribute("AIChosenPressRole", "Carrier")
			model:SetAttribute("AIPressTarget", assignment.TargetWorld)
			model:SetAttribute("AIPressLayer", "Primary")
		elseif slot and slot.Id == "cover-presser" then
			local outlet = carrierPitch.Z <= PitchConfig.HALF_LENGTH and nearestMidfielder or nearestForwardOutlet or nearestMidfielder
			if outlet then
				local target = Vector3.new((outlet.Pitch.X + PitchConfig.HALF_WIDTH) * .5, 3, math.max(34, outlet.Pitch.Z - 10))
				assignment.TargetPitch = PitchConfig.ClampInsidePitch(target)
				assignment.TargetWorld = PitchConfig.TeamPitchPositionToWorld(assignment.TargetPitch, side, context.Options)
				assignment.MovementTarget = assignment.TargetWorld
				assignment.FaceWorld = outlet.World
			end
			assignment.PrimaryAssignment = carrierPitch.Z <= PitchConfig.HALF_LENGTH and "PressNextReceiver" or "CoverPresser"
			assignment.MovementUrgency = highPress and .96 or .88
			assignment.SprintAllowed = highPress or (outlet and PitchConfig.GetDistanceStuds((context.Players[model] and context.Players[model].Pitch) or assignment.TargetPitch, assignment.TargetPitch) > 14) or false
			model:SetAttribute("AIChosenPressRole", "CentralOutlet")
			model:SetAttribute("AIPressTarget", assignment.TargetWorld)
			model:SetAttribute("AIPressLayer", "Cover")
		elseif slot and slot.Id == "midfield-press-support" then
			local outlet = nearestMidfielder or nearestForwardOutlet
			if outlet then
				local x = outlet.Pitch.X + (PitchConfig.HALF_WIDTH - outlet.Pitch.X) * .35
				local z = math.max(48, math.min(outlet.Pitch.Z - 16, carrierPitch.Z - 8))
				assignment.TargetPitch = PitchConfig.ClampInsidePitch(Vector3.new(x, 3, z))
				assignment.TargetWorld = PitchConfig.TeamPitchPositionToWorld(assignment.TargetPitch, side, context.Options)
				assignment.MovementTarget = assignment.TargetWorld
				assignment.FaceWorld = outlet.World
			end
			assignment.PrimaryAssignment = "MidfieldPressSupport"
			assignment.MovementUrgency = highPress and .94 or .84
			assignment.SprintAllowed = highPress
			model:SetAttribute("AIChosenPressRole", "MidfieldSupport")
			model:SetAttribute("AIPressTarget", assignment.TargetWorld)
			model:SetAttribute("AIPressLayer", "Support")
		elseif slot and (slot.Id == "central-lane-block" or slot.Id == "pivot-lane-blocker" or slot.Id == "cam-feet-lane-blocker") then
			local outlet = nearestForwardOutlet or nearestMidfielder
			if outlet then
				local midpoint = carrierPitch:Lerp(outlet.Pitch, .48)
				assignment.TargetPitch = PitchConfig.ClampInsidePitch(Vector3.new(midpoint.X, 3, math.max(54, midpoint.Z - 4)))
				assignment.TargetWorld = PitchConfig.TeamPitchPositionToWorld(assignment.TargetPitch, side, context.Options)
				assignment.MovementTarget = assignment.TargetWorld
				assignment.FaceWorld = carrier and carrier.World or outlet.World
			end
			assignment.PrimaryAssignment = "PivotLaneBlocker"
			assignment.MovementUrgency = highPress and .86 or .78
			assignment.SprintAllowed = false
			model:SetAttribute("AIChosenPressRole", "PivotScreen")
			model:SetAttribute("AIPressTarget", assignment.TargetWorld)
			model:SetAttribute("AIPressLayer", "Screen")
		elseif slot and (slot.Id == "left-center-back" or slot.Id == "right-center-back" or slot.Id == "left-fullback-zone" or slot.Id == "right-fullback-zone") then
			assignment.PrimaryAssignment = "HoldBackLineZone"
			assignment.MovementUrgency = .72
			assignment.SprintAllowed = false
		elseif slot and (slot.Id == "cutback-protector" or slot.Id == "far-post-protector") then
			assignment.PrimaryAssignment = slot.Id == "cutback-protector" and "ProtectCutbackZone" or "ProtectFarPost"
			assignment.MovementUrgency = .76
			assignment.SprintAllowed = false
		end
		if dutyState and slot then
			local duty = dutyState[model]
			local dutyType = tostring(slot.DefensiveDuty or slot.Id)
			if not duty or duty.DutyType ~= dutyType or now >= (duty.ExpiresAt or 0) then
				duty = {DutyId = dutyType .. ":" .. tostring(math.floor(now * 10)), DutyType = dutyType, StartedAt = now, MinimumHoldUntil = now + dutyHold(dutyType), ExpiresAt = now + dutyHold(dutyType) + .7, Target = assignment.TargetWorld, BlockedLane = block and block.BlockedLane or nil, ForceDirection = block and block.ForceDirection or nil}
				dutyState[model] = duty
			elseif now < (duty.MinimumHoldUntil or 0) and typeof(duty.Target) == "Vector3" then
				assignment.TargetWorld = duty.Target
				assignment.MovementTarget = duty.Target
			else
				duty.Target = assignment.TargetWorld
				duty.BlockedLane = block and block.BlockedLane or duty.BlockedLane
				duty.ForceDirection = block and block.ForceDirection or duty.ForceDirection
			end
			model:SetAttribute("AIDefensiveDutyId", duty.DutyId)
			model:SetAttribute("AIDefensiveDuty", duty.DutyType)
			model:SetAttribute("AIDefensiveForceDirection", duty.ForceDirection)
			model:SetAttribute("AIDefensiveBlockedLane", duty.BlockedLane)
		end
		model:SetAttribute("TeamDefensiveIntent", tostring(intent and intent.Intent or ""))
		if block then
			model:SetAttribute("AIDefensiveBlockWidth", block.BlockWidth)
			model:SetAttribute("AIDefensiveBackLineZ", block.BackLineZ)
			model:SetAttribute("AIDefensiveMidLineZ", block.MidfieldLineZ)
		end
	end
	if block and carrier then
		local centralCarrier = math.abs(carrierPitch.X - PitchConfig.HALF_WIDTH) <= 70
		local closestPresser = math.huge
		for model, assignment in pairs(assignments) do
			local primary = tostring(assignment.PrimaryAssignment or "")
			if primary == "PressBallCarrier" or primary == "ContainBallCarrier" or primary == "CarrierBreachPress" then
				closestPresser = math.min(closestPresser, assignmentDistance(context, model, carrierPitch))
			end
		end
		local breachedForward = carrierPitch.Z < (tonumber(block.ForwardLineZ) or PitchConfig.PITCH_LENGTH) - 10
		local breachedMidfield = carrierPitch.Z < (tonumber(block.MidfieldLineZ) or PitchConfig.HALF_LENGTH) - 8
		local betweenLines = carrierPitch.Z > (tonumber(block.BackLineZ) or 0) + 8 and carrierPitch.Z < (tonumber(block.MidfieldLineZ) or PitchConfig.HALF_LENGTH) - 6
		local unpressedCentral = centralCarrier and closestPresser > (breachedMidfield and 38 or 32)
		local breach = breachedForward or breachedMidfield or betweenLines or unpressedCentral
		if breach then
			local used: {[Model]: boolean} = {}
			local contain = pickAssigned(context, assignments, carrierPitch, used, function(info: any)
				return info.Role == "CM" or info.Role == "CDM" or info.Role == "CAM" or info.Role == "Fullback" or info.Role == "CB"
			end)
			local cover = pickAssigned(context, assignments, carrierPitch, used, function(info: any)
				return info.Role == "CB" or info.Role == "Fullback" or info.Role == "CDM" or info.Role == "CM"
			end)
			local deep = pickAssigned(context, assignments, Vector3.new(carrierPitch.X < PitchConfig.HALF_WIDTH and 310 or 114, 3, math.max(42, carrierPitch.Z - 42)), used, function(info: any)
				return info.Role == "CB"
			end)
			local screen = pickAssigned(context, assignments, Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(48, carrierPitch.Z - 20)), used, function(info: any)
				return info.Role == "CDM" or info.Role == "CM"
			end)
			if contain and assignments[contain] then
				local x = carrierPitch.X + (PitchConfig.HALF_WIDTH - carrierPitch.X) * .28
				setPitchTarget(context, side, assignments[contain], Vector3.new(x, 3, math.max(28, carrierPitch.Z - (breachedMidfield and 8 or 4))), breachedMidfield and "CarrierBreachPress" or "ContainBallCarrier", 1, true)
				contain:SetAttribute("AIDefensiveBreachRole", "Contain")
				contain:SetAttribute("AIBreachCarrierZ", carrierPitch.Z)
			end
			if cover and assignments[cover] then
				setPitchTarget(context, side, assignments[cover], Vector3.new(carrierPitch.X + (carrierPitch.X < PitchConfig.HALF_WIDTH and 28 or -28), 3, math.max(35, carrierPitch.Z - 22)), "CoverStep", .92, breachedMidfield)
				cover:SetAttribute("AIDefensiveBreachRole", "CoverStep")
			end
			if deep and assignments[deep] then
				setPitchTarget(context, side, assignments[deep], Vector3.new(carrierPitch.X < PitchConfig.HALF_WIDTH and 292 or 132, 3, math.max(28, carrierPitch.Z - 54)), "DeepCover", .84, false)
				deep:SetAttribute("AIDefensiveBreachRole", "DeepCover")
			end
			if screen and assignments[screen] then
				setPitchTarget(context, side, assignments[screen], Vector3.new(PitchConfig.HALF_WIDTH, 3, math.max(38, carrierPitch.Z - 24)), "ProtectCentralReturnLane", .86, false)
				screen:SetAttribute("AIDefensiveBreachRole", "CentralReturnLane")
			end
		end
	end
end

function Plan.ApplyIncomingPass(context: any, side: string, assignments: any, dutyState: any?)
	if context.PassInFlight ~= true then return end
	local target = nil
	local receiver = nil
	for _, info in ipairs(context.Teams[side == "Home" and "Away" or "Home"].List) do
		local receive = info.Model:GetAttribute("VTRReceiveIntercept") or info.Model:GetAttribute("VTRReceiveTarget")
		local untilTime = tonumber(info.Model:GetAttribute("VTRReceiveUntil")) or 0
		if typeof(receive) == "Vector3" and untilTime >= (context.Now or os.clock()) then
			target = receive
			receiver = info
			break
		end
	end
	if typeof(target) ~= "Vector3" then
		target = context.BallWorld
	end
	local receiverPathWorld = receiver and (receiver.World:Lerp(target, .62)) or target
	local receiverTargetPitch = PitchConfig.WorldToTeamPitchPosition(receiverPathWorld, side, context.Options)
	local blockPitch = receiver and Vector3.new((receiverTargetPitch.X + PitchConfig.HALF_WIDTH) * .5, 3, math.max(70, receiverTargetPitch.Z - 34)) or PitchConfig.WorldToTeamPitchPosition(target, side, context.Options)
	local blockWorld = PitchConfig.TeamPitchPositionToWorld(blockPitch, side, context.Options)
	local used: {[Model]: boolean} = {}
	local function choose(targetWorld: Vector3, predicate: ((any) -> boolean)?): (Model?, number)
		local bestModel = nil
		local bestDistance = math.huge
		for model in pairs(assignments) do
			local info = context.Players[model]
			if info and info.Root and info.IsUserControlled ~= true and used[model] ~= true and (not predicate or predicate(info)) then
				local distance = PitchConfig.GetDistanceStuds(info.World, targetWorld)
				if distance < bestDistance then
					bestModel = model
					bestDistance = distance
				end
			end
		end
		if bestModel then used[bestModel] = true end
		return bestModel, bestDistance
	end
	local bestAttacker, bestAttackDistance = choose(target, function(info: any): boolean
		return info.Role == "CM" or info.Role == "CDM" or info.Role == "Fullback" or info.Role == "CB"
	end)
	local bestTracker = receiver and choose(receiverPathWorld, nil) or nil
	local bestBlocker = receiver and choose(blockWorld, nil) or nil
	local bestCover = choose(PitchConfig.TeamPitchPositionToWorld(Vector3.new(PitchConfig.HALF_WIDTH, 3, 62), side, context.Options), function(info: any): boolean
		return info.Role == "CB" or info.Role == "Fullback" or info.Role == "CDM"
	end)
	for model, assignment in pairs(assignments) do
		local info = context.Players[model]
		if info and info.Root then
			if model == bestAttacker then
				assignment.PrimaryAssignment = "AttackPassTrajectory"
				assignment.TargetWorld = target
				assignment.MovementTarget = target
				assignment.MovementUrgency = 1
				assignment.SprintAllowed = bestAttackDistance > 18
			elseif model == bestTracker and receiver then
				assignment.PrimaryAssignment = "TrackIncomingReceiver"
				assignment.TargetWorld = receiverPathWorld
				assignment.MovementTarget = receiverPathWorld
				assignment.MovementUrgency = .9
				assignment.SprintAllowed = false
			elseif model == bestBlocker and receiver then
				assignment.PrimaryAssignment = "BlockReturnPass"
				assignment.TargetWorld = blockWorld
				assignment.MovementTarget = blockWorld
				assignment.MovementUrgency = .82
				assignment.SprintAllowed = false
			elseif model == bestCover then
				local coverWorld = PitchConfig.TeamPitchPositionToWorld(Vector3.new(PitchConfig.HALF_WIDTH, 3, 62), side, context.Options)
				assignment.PrimaryAssignment = "PreserveDeepestCover"
				assignment.TargetWorld = coverWorld
				assignment.MovementTarget = coverWorld
				assignment.MovementUrgency = .7
				assignment.SprintAllowed = false
			end
			if model == bestAttacker or model == bestTracker or model == bestBlocker or model == bestCover then
				model:SetAttribute("AIIncomingPassDuty", assignment.PrimaryAssignment)
				if dutyState then
					dutyState[model] = {DutyId = assignment.PrimaryAssignment .. ":" .. tostring(math.floor((context.Now or os.clock()) * 10)), DutyType = assignment.PrimaryAssignment, StartedAt = context.Now or os.clock(), MinimumHoldUntil = (context.Now or os.clock()) + .58, ExpiresAt = (context.Now or os.clock()) + 1.05, Target = assignment.TargetWorld}
				end
			else
				model:SetAttribute("AIIncomingPassDuty", nil)
			end
		end
	end
end

return Plan
