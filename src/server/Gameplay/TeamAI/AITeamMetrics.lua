--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)

local Metrics = {}
Metrics.__index = Metrics

local function emptyTactical(): any
	return {
		AverageBackToMidfieldGap = 0,
		AverageMidfieldToForwardGap = 0,
		BlockWidthVariance = 0,
		TeamDepthVariance = 0,
		RequiredZoneOccupancy = 0,
		DuplicateLaneOccupation = 0,
		RestDefenseViolations = 0,
		UnsupportedAttackingRuns = 0,
		RunsWithoutPassingAccess = 0,
		AssignmentChangesPerMinute = 0,
		PressesBroken = 0,
		OpponentEntriesBetweenLines = 0,
		OpponentSuccessfulSwitches = 0,
		PlanStepsCompleted = 0,
		PlanStepsFailed = 0,
		PlanTimeouts = 0,
		SuccessfulThirdManSequences = 0,
		SuccessfulOverloadToSwitchSequences = 0,
		CounterattackProgression = 0,
		StyleDifferentiationScore = 0,
		ShapeViolations = 0,
	}
end

function Metrics.new(): any
	return setmetatable({
		WorldMs = 0,
		SpatialMs = 0,
		IntentMs = 0,
		StructureMs = 0,
		AssignmentMs = 0,
		CarrierMs = 0,
		DefenseMs = 0,
		WorstFrameMs = 0,
		Frames = 0,
		Cells = 0,
		Candidates = 0,
		Plans = {Home = 0, Away = 0},
		Tactical = {Home = emptyTactical(), Away = emptyTactical()},
		LastAssignments = {Home = {}, Away = {}},
		LastPlans = {Home = nil, Away = nil},
		LastSampleAt = 0,
	}, Metrics)
end

function Metrics:Sample(key: string, seconds: number)
	local ms = math.max(0, seconds * 1000)
	self[key] = ms
	if key ~= "WorstFrameMs" then
		self.WorstFrameMs = math.max(self.WorstFrameMs, ms)
	end
end

local function smooth(current: number, sample: number, alpha: number): number
	return current * (1 - alpha) + sample * alpha
end

local function variance(values: {number}): number
	if #values <= 1 then return 0 end
	local sum = 0
	for _, value in ipairs(values) do sum += value end
	local mean = sum / #values
	local total = 0
	for _, value in ipairs(values) do total += (value - mean) * (value - mean) end
	return total / #values
end

local function lane(position: Vector3): string
	if position.X < 145 then return "Left" end
	if position.X > 279 then return "Right" end
	return "Central"
end

local function passingAccess(context: any, side: string, assignment: any): boolean
	local owner = context.Owner
	if not owner or context.OwnerSide ~= side or not context.Players[owner] then return false end
	local carrier = context.Players[owner]
	local target = assignment.TargetWorld or assignment.MovementTarget
	if typeof(target) ~= "Vector3" then return false end
	for _, opponent in ipairs(context.Teams[carrier.OpponentSide].List) do
		if opponent.Root then
			local ap = Vector3.new(opponent.World.X - carrier.World.X, 0, opponent.World.Z - carrier.World.Z)
			local ab = Vector3.new(target.X - carrier.World.X, 0, target.Z - carrier.World.Z)
			local lengthSquared = ab:Dot(ab)
			if lengthSquared > .01 then
				local t = math.clamp(ap:Dot(ab) / lengthSquared, 0, 1)
				local closest = Vector3.new(carrier.World.X, 0, carrier.World.Z) + ab * t
				if t > .08 and t < .95 and (Vector3.new(opponent.World.X, 0, opponent.World.Z) - closest).Magnitude < 10 then
					return false
				end
			end
		end
	end
	return true
end

function Metrics:Analyze(context: any, assignmentsBySide: any)
	local now = context.Now or os.clock()
	local dt = math.max(.05, now - (self.LastSampleAt > 0 and self.LastSampleAt or now - .25))
	self.LastSampleAt = now
	for _, side in ipairs({"Home", "Away"}) do
		local tactical = self.Tactical[side]
		local assignments = assignmentsBySide[side] or {}
		local back = {}
		local mid = {}
		local forward = {}
		local widths = {}
		local depths = {}
		local laneCounts = {}
		local rest = 0
		local requiredZones = 0
		local occupiedZones = 0
		local runs = 0
		local unsupported = 0
		local noAccess = 0
		local changes = 0
		for model, assignment in pairs(assignments) do
			local slot = assignment.TacticalSlot
			local pitch = assignment.TargetPitch
			if slot and pitch then
				table.insert(widths, pitch.X)
				table.insert(depths, pitch.Z)
				local line = tostring(slot.Line or "")
				if line == "Back" or slot.RestDefense == true then table.insert(back, pitch.Z) end
				if line == "Midfield" then table.insert(mid, pitch.Z) end
				if line == "Forward" then table.insert(forward, pitch.Z) end
				local laneId = lane(pitch)
				laneCounts[laneId] = (laneCounts[laneId] or 0) + 1
				if slot.RestDefense == true then rest += 1 end
				requiredZones += 1
				local info = context.Players[model]
				if info and PitchConfig.GetDistanceStuds(info.Pitch, pitch) <= ((slot.TargetRegion and slot.TargetRegion.Radius) or 22) * 1.8 then
					occupiedZones += 1
				end
				if assignment.RunApproved == true then
					runs += 1
					if not assignment.PlayerContract or assignment.PlayerContract.ReplacementRequirement ~= "RestDefenseCoverage" then unsupported += 1 end
					if not passingAccess(context, side, assignment) then noAccess += 1 end
				end
				local previous = self.LastAssignments[side][model]
				if previous and previous ~= slot.Id then changes += 1 end
				self.LastAssignments[side][model] = slot.Id
			end
		end
		local function average(list: {number}): number
			if #list == 0 then return 0 end
			local total = 0
			for _, value in ipairs(list) do total += value end
			return total / #list
		end
		local duplicate = 0
		for _, count in pairs(laneCounts) do if count > 2 then duplicate += count - 2 end end
		local requiredRest = context.TeamBrain and context.TeamBrain[side] and tonumber(context.TeamBrain[side].RestDefense) or 2
		local plan = context.TeamPlans and context.TeamPlans[side]
		local previousPlan = self.LastPlans[side]
		if plan and previousPlan and plan.StepId ~= previousPlan.StepId then
			if tostring(plan.LastEvent or "") == "RequiredOccupationMissing" or tostring(plan.LastEvent or "") == "Turnover" then
				tactical.PlanStepsFailed += 1
			elseif tostring(plan.LastEvent or "") == "Hold" then
				tactical.PlanTimeouts += 1
			else
				tactical.PlanStepsCompleted += 1
			end
			if previousPlan.StepId == "third-man-support" and plan.StepId == "runner-behind" then tactical.SuccessfulThirdManSequences += 1 end
			if previousPlan.StepId == "far-side-switch" and (plan.StepId == "wide-triangle" or plan.StepId == "attack-space") then tactical.SuccessfulOverloadToSwitchSequences += 1 end
		end
		if plan then self.LastPlans[side] = {StepId = plan.StepId, LastEvent = plan.LastEvent} end
		tactical.AverageBackToMidfieldGap = smooth(tactical.AverageBackToMidfieldGap, math.abs(average(mid) - average(back)), .18)
		tactical.AverageMidfieldToForwardGap = smooth(tactical.AverageMidfieldToForwardGap, math.abs(average(forward) - average(mid)), .18)
		tactical.BlockWidthVariance = smooth(tactical.BlockWidthVariance, variance(widths), .18)
		tactical.TeamDepthVariance = smooth(tactical.TeamDepthVariance, variance(depths), .18)
		tactical.RequiredZoneOccupancy = smooth(tactical.RequiredZoneOccupancy, requiredZones > 0 and occupiedZones / requiredZones or 0, .18)
		tactical.DuplicateLaneOccupation = smooth(tactical.DuplicateLaneOccupation, duplicate, .18)
		tactical.RestDefenseViolations = smooth(tactical.RestDefenseViolations, rest < requiredRest and requiredRest - rest or 0, .18)
		tactical.UnsupportedAttackingRuns = smooth(tactical.UnsupportedAttackingRuns, unsupported, .18)
		tactical.RunsWithoutPassingAccess = smooth(tactical.RunsWithoutPassingAccess, noAccess, .18)
		tactical.AssignmentChangesPerMinute = smooth(tactical.AssignmentChangesPerMinute, changes / dt * 60, .12)
		tactical.ShapeViolations = smooth(tactical.ShapeViolations, duplicate + (rest < requiredRest and 1 or 0) + unsupported + noAccess, .18)
		local reaction = context.TeamReactions and context.TeamReactions[side]
		tactical.StyleDifferentiationScore = smooth(tactical.StyleDifferentiationScore, reaction and reaction.Active and reaction.Active.Blended and 1 or 0, .1)
		if context.OwnerSide == side and context.TeamStageResetUntil and (context.TeamStageResetUntil[side] or 0) > now then
			local ball = context.BallTeam[side]
			tactical.CounterattackProgression = smooth(tactical.CounterattackProgression, math.max(0, ball.Z - PitchConfig.HALF_LENGTH), .18)
		end
	end
end

function Metrics:Frame(seconds: number)
	self.Frames += 1
	self.WorstFrameMs = math.max(self.WorstFrameMs, math.max(0, seconds * 1000))
end

function Metrics:Snapshot(): any
	return {
		WorldMs = self.WorldMs,
		SpatialMs = self.SpatialMs,
		StructureMs = self.StructureMs,
		IntentMs = self.IntentMs,
		AssignmentMs = self.AssignmentMs,
		CarrierMs = self.CarrierMs,
		DefenseMs = self.DefenseMs,
		WorstFrameMs = self.WorstFrameMs,
		Frames = self.Frames,
		Cells = self.Cells,
		Candidates = self.Candidates,
		Plans = self.Plans,
		Tactical = self.Tactical,
	}
end

return Metrics
