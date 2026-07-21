--!strict

local Contract = {}

local function arrayFrom(value: any): {any}
	if type(value) == "table" then
		return table.clone(value)
	end
	if value == nil then
		return {}
	end
	return {value}
end

local function mapFrom(value: any): {[string]: boolean}
	local result = {}
	if type(value) == "table" then
		for key, child in pairs(value) do
			if type(key) == "string" and child == true then
				result[key] = true
			elseif type(child) == "string" then
				result[child] = true
			end
		end
	elseif type(value) == "string" then
		result[value] = true
	end
	return result
end

local function inferLane(pitch: Vector3?): string
	if not pitch then
		return "Central"
	end
	if pitch.X < 145 then
		return "Left"
	end
	if pitch.X > 279 then
		return "Right"
	end
	return "Central"
end

local function inferLine(roleFamily: string?, pitch: Vector3?): string
	if roleFamily == "GK" then
		return "Goalkeeper"
	end
	if roleFamily == "CB" or roleFamily == "Fullback" then
		return "Back"
	end
	if roleFamily == "ST" or (pitch and pitch.Z >= 560) then
		return "Forward"
	end
	return "Midfield"
end

local function defaultActions(actionProfile: string, restDefense: boolean): {string}
	if restDefense then
		return {"Receive", "Pass", "Tackle", "Cover"}
	end
	if actionProfile == "Goalkeeper" then
		return {"Receive", "Pass", "Clear"}
	end
	if actionProfile == "RestDefender" then
		return {"Receive", "Pass", "Tackle", "Cover"}
	end
	if actionProfile == "BuildUpDefender" then
		return {"Receive", "Pass", "Carry", "Dribble", "Cover"}
	end
	if actionProfile == "Pivot" then
		return {"Receive", "Pass", "Carry", "Dribble", "Press", "Tackle", "Cover"}
	end
	if actionProfile == "SupportMidfielder" then
		return {"Receive", "Pass", "Carry", "Dribble", "Shoot", "Press", "Run"}
	end
	if actionProfile == "Creator" then
		return {"Receive", "Pass", "Carry", "Dribble", "Shoot", "Press"}
	end
	if actionProfile == "Winger" then
		return {"Receive", "Pass", "Carry", "Dribble", "Cross", "Shoot", "Press", "Run"}
	end
	if actionProfile == "Forward" then
		return {"Receive", "Pass", "Carry", "Dribble", "Shoot", "Press", "Run"}
	end
	if actionProfile == "Presser" then
		return {"Press", "Tackle", "Cover", "Receive", "Pass"}
	end
	return {"Receive", "Pass", "Carry", "Dribble", "Cover", "Press"}
end

function Contract.Region(center: Vector3, radius: number?, lane: string?, line: string?): any
	return {
		Center = center,
		Radius = radius or 18,
		Lane = lane or inferLane(center),
		Line = line or inferLine(nil, center),
	}
end

function Contract.Slot(raw: any): any
	local targetPitch = raw.TargetPitch or raw.TargetRegion and raw.TargetRegion.Center or Vector3.new(212, 3, 352)
	local roleFamily = tostring(raw.RoleFamily or raw.Function or "")
	local line = raw.Line or inferLine(roleFamily, targetPitch)
	local lane = raw.Lane or inferLane(targetPitch)
	local functionName = tostring(raw.Function or raw.Id or "Slot")
	local actionProfile = tostring(raw.ActionProfile or "")
	if actionProfile == "" then
		if raw.RestDefense == true then
			actionProfile = "RestDefender"
		elseif roleFamily == "GK" or line == "Goalkeeper" then
			actionProfile = "Goalkeeper"
		elseif roleFamily == "Winger" or roleFamily == "Wingback" then
			actionProfile = "Winger"
		elseif roleFamily == "ST" or line == "Forward" then
			actionProfile = "Forward"
		elseif roleFamily == "CAM" then
			actionProfile = "Creator"
		elseif roleFamily == "CM" then
			actionProfile = "SupportMidfielder"
		elseif roleFamily == "CDM" then
			actionProfile = "Pivot"
		elseif roleFamily == "CB" or roleFamily == "Fullback" then
			actionProfile = "BuildUpDefender"
		else
			actionProfile = "SupportMidfielder"
		end
	end
	local restDefense = raw.RestDefense == true
	local targetRegion = raw.TargetRegion or Contract.Region(targetPitch, raw.RegionRadius, lane, line)
	local allowedActions = arrayFrom(raw.AllowedActions)
	if #allowedActions == 0 then
		allowedActions = defaultActions(actionProfile, restDefense)
	end
	local slot = table.clone(raw)
	slot.Id = tostring(raw.Id or functionName)
	slot.Function = functionName
	slot.ActionProfile = actionProfile
	slot.RoleFamily = raw.RoleFamily
	slot.AllowedRoles = arrayFrom(raw.AllowedRoles or raw.RoleFamily)
	slot.PreferredRoles = arrayFrom(raw.PreferredRoles or raw.RoleFamily)
	slot.TargetPitch = targetPitch
	slot.TargetRegion = targetRegion
	slot.Lane = lane
	slot.Line = line
	slot.Priority = tonumber(raw.Priority) or 0
	slot.RestDefense = restDefense
	slot.LockedModel = raw.LockedModel
	slot.ContinuityKey = tostring(raw.ContinuityKey or raw.Id or functionName)
	slot.SprintAllowed = raw.SprintAllowed == true
	slot.AllowedActions = allowedActions
	slot.CoverRequirement = raw.CoverRequirement
	return slot
end

function Contract.PlanStep(raw: any): any
	local step = table.clone(raw or {})
	step.Id = tostring(step.Id or "step")
	step.EntryConditions = arrayFrom(step.EntryConditions)
	step.RequiredOccupations = arrayFrom(step.RequiredOccupations)
	step.PreferredReceiver = step.PreferredReceiver
	step.MinimumHold = tonumber(step.MinimumHold) or 0.18
	step.MaximumHold = math.max(step.MinimumHold, tonumber(step.MaximumHold) or 1.8)
	step.CompletionConditions = arrayFrom(step.CompletionConditions)
	step.FailureConditions = arrayFrom(step.FailureConditions)
	step.NextStep = step.NextStep
	step.FallbackStep = step.FallbackStep
	step.PassBias = step.PassBias or "Balanced"
	step.RunRequests = arrayFrom(step.RunRequests)
	return step
end

function Contract.Run(raw: any): any
	local run = table.clone(raw or {})
	run.Id = tostring(run.Id or "run")
	run.Kind = tostring(run.Kind or "SupportRun")
	run.Runner = run.Runner
	run.TargetRegion = run.TargetRegion
	run.Trigger = run.Trigger or "TeamPlan"
	run.StartTime = tonumber(run.StartTime) or os.clock()
	run.Expiry = tonumber(run.Expiry) or run.StartTime + 2.6
	run.CancelConditions = arrayFrom(run.CancelConditions)
	run.VacatedSlot = run.VacatedSlot
	run.ReplacementSlot = run.ReplacementSlot
	return run
end

function Contract.Player(raw: any): any
	local player = table.clone(raw or {})
	player.SlotId = tostring(player.SlotId or "")
	player.TargetRegion = player.TargetRegion
	player.PreferredTarget = player.PreferredTarget
	player.AllowedActions = arrayFrom(player.AllowedActions)
	player.ForbiddenActions = arrayFrom(player.ForbiddenActions)
	player.PlanStep = player.PlanStep
	player.RunContract = player.RunContract
	player.MarkTarget = player.MarkTarget
	player.CoverTarget = player.CoverTarget
	player.MinimumHoldUntil = tonumber(player.MinimumHoldUntil) or 0
	player.AbortConditions = arrayFrom(player.AbortConditions)
	player.ReplacementRequirement = player.ReplacementRequirement
	player._AllowedActionMap = mapFrom(player.AllowedActions)
	player._ForbiddenActionMap = mapFrom(player.ForbiddenActions)
	return player
end

function Contract.ActionForbidden(contract: any, action: string): boolean
	if type(contract) ~= "table" then
		return false
	end
	local forbidden = contract._ForbiddenActionMap or mapFrom(contract.ForbiddenActions)
	return forbidden[action] == true
end

function Contract.ActionAllowed(contract: any, action: string): boolean
	if type(contract) ~= "table" then
		return true
	end
	if Contract.ActionForbidden(contract, action) then
		return false
	end
	local allowed = contract._AllowedActionMap or mapFrom(contract.AllowedActions)
	local hasAny = false
	for _ in pairs(allowed) do
		hasAny = true
		break
	end
	return not hasAny or allowed[action] == true
end

return Contract
