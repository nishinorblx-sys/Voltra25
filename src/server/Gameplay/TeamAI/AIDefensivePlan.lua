--!strict

local Plan = {}
local PitchConfig = require(script.Parent.Parent.PitchConfig)

local function dutyHold(duty: string): number
	if duty == "PrimaryPress" then return .72 end
	if duty == "CoverPress" then return .9 end
	if duty == "PivotLaneBlock" or duty == "CentralLaneBlock" then return 1.15 end
	if duty == "CutbackProtect" or duty == "FarPostProtect" then return 1.55 end
	return 1.05
end

function Plan.Apply(context: any, side: string, assignments: any, intent: any, block: any, dutyState: any?)
	local primaryUsed = false
	local now = context.Now or os.clock()
	for model, assignment in pairs(assignments) do
		local slot = assignment.TacticalSlot
		if slot and slot.Id == "primary-presser" and not primaryUsed then
			primaryUsed = true
			assignment.PrimaryAssignment = "PressBallCarrier"
			assignment.MovementUrgency = 1
			assignment.SprintAllowed = true
			if block and context.Owner and context.Players[context.Owner] then
				local carrier = context.Players[context.Owner]
				local target = slot.TargetPitch
				local force = tostring(block.ForceDirection or "")
				if force == "TouchlineLeft" then
					target = Vector3.new(math.max(28, carrier.Pitch.X - 9), 3, carrier.Pitch.Z + 8)
				elseif force == "TouchlineRight" then
					target = Vector3.new(math.min(396, carrier.Pitch.X + 9), 3, carrier.Pitch.Z + 8)
				else
					target = Vector3.new(carrier.Pitch.X, 3, carrier.Pitch.Z + 16)
				end
				assignment.TargetPitch = target
				assignment.TargetWorld = context.Options and PitchConfig.TeamPitchPositionToWorld(target, side, context.Options) or assignment.TargetWorld
				assignment.MovementTarget = assignment.TargetWorld
			end
		elseif slot and slot.Id == "cover-presser" then
			assignment.PrimaryAssignment = "CoverPresser"
			assignment.MovementUrgency = .88
			assignment.SprintAllowed = tostring(intent and intent.Intent or "") == "HighPress"
		elseif slot and (slot.Id == "central-lane-block" or slot.Id == "pivot-lane-blocker" or slot.Id == "cam-feet-lane-blocker") then
			assignment.PrimaryAssignment = "BlockPassingLane"
			assignment.MovementUrgency = .78
			assignment.SprintAllowed = false
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
	local bestAttacker = nil
	local bestTracker = nil
	local bestBlocker = nil
	local bestAttackDistance = math.huge
	local bestTrackDistance = math.huge
	local bestBlockDistance = math.huge
	for model, assignment in pairs(assignments) do
		local info = context.Players[model]
		if info and info.Root and info.IsUserControlled ~= true then
			local distance = PitchConfig.GetDistanceStuds(info.World, target)
			if (info.Role == "CM" or info.Role == "CDM" or info.Role == "Fullback" or info.Role == "CB") and distance < bestAttackDistance then
				bestAttacker = model
				bestAttackDistance = distance
			end
			if receiver then
				local receiverDistance = PitchConfig.GetDistanceStuds(info.World, receiver.World)
				if receiverDistance < bestTrackDistance then
					bestTracker = model
					bestTrackDistance = receiverDistance
				end
			end
			local blockTarget = receiver and Vector3.new((receiver.Pitch.X + PitchConfig.HALF_WIDTH) * .5, 3, math.max(70, receiver.Pitch.Z - 34)) or target
			local blockDistance = PitchConfig.GetDistanceStuds(info.Pitch, blockTarget)
			if blockDistance < bestBlockDistance then
				bestBlocker = model
				bestBlockDistance = blockDistance
			end
		end
	end
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
				assignment.TargetWorld = receiver.World
				assignment.MovementTarget = receiver.World
				assignment.MovementUrgency = .9
				assignment.SprintAllowed = false
			elseif model == bestBlocker and receiver then
				local blockPitch = Vector3.new((receiver.Pitch.X + PitchConfig.HALF_WIDTH) * .5, 3, math.max(70, receiver.Pitch.Z - 34))
				local blockWorld = PitchConfig.TeamPitchPositionToWorld(blockPitch, side, context.Options)
				assignment.PrimaryAssignment = "BlockReturnPass"
				assignment.TargetWorld = blockWorld
				assignment.MovementTarget = blockWorld
				assignment.MovementUrgency = .82
				assignment.SprintAllowed = false
			end
			if model == bestAttacker or model == bestTracker or model == bestBlocker then
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
