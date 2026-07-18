--!strict
local PitchConfig = require(script.Parent.PitchConfig)

local Coordinator = {}
Coordinator.__index = Coordinator

local runTypes = {
	RunBehind = "RunBehind", RiskOffsideRun = "RunBehind", RunBehindWide = "RunBehind", OverlapRun = "Overlap", UnderlapRun = "Underlap", ForwardMidfieldRun = "ThirdMan", WideOutlet = "WideOutlet", AttackBox = "BoxRun", AttackBackPost = "FarPost", CounterSprint = "CounterRun", RecoveryRun = "RecoveryRun", ChaseLooseBall = "RecoveryRun",
}

local function laneFor(assignment: any): string
	local x = assignment.TargetPitch and assignment.TargetPitch.X or PitchConfig.HALF_WIDTH
	if x < 85 then return "LeftWide" elseif x < 175 then return "LeftHalfSpace" elseif x <= 249 then return "Center" elseif x <= 339 then return "RightHalfSpace" end
	return "RightWide"
end

function Coordinator.new(style: any)
	return setmetatable({Style = style, Tickets = {}, Sequence = 0}, Coordinator)
end

function Coordinator:Coordinate(context: any, side: string, assignments: any): any
	local now = context.Now or os.clock()
	local proposals = {}
	for model, assignment in assignments do
		local runType = runTypes[assignment.PrimaryAssignment]
		if runType then
			local info = context.Players[model]
			local energy = tonumber(model:GetAttribute("VTRSprintEnergy")) or 100
			local priority = math.clamp(tonumber(assignment.MovementUrgency) or 0, 0, 1) * 100 + energy * 0.08
			table.insert(proposals, {Model = model, Assignment = assignment, RunType = runType, Lane = laneFor(assignment), Priority = priority, Energy = energy, Info = info})
		end
	end
	table.sort(proposals, function(a, b) if a.Priority == b.Priority then return a.Model.Name < b.Model.Name end;return a.Priority > b.Priority end)
	local budget = math.max(1, tonumber(self.Style.MaxMajorRuns) or 2)
	local laneUse = {}
	local approved = 0
	local overload = self.Style.PresetId == "wing_overload" or self.Style.PresetId == "central_overload" or self.Style.PresetId == "all_out_attack"
	local defendersHeld, midfieldersHeld = 0, 0
	for _, info in ipairs(context.Teams[side].List) do
		local proposal = nil
		for _, item in proposals do if item.Model == info.Model then proposal = item;break end end
		if not proposal then
			if info.Role == "CB" or info.Role == "Fullback" then defendersHeld += 1 end
			if info.Role == "CDM" or info.Role == "CM" then midfieldersHeld += 1 end
		end
	end
	for _, proposal in proposals do
		local assignment = proposal.Assignment
		local existing = self.Tickets[proposal.Model]
		local committed = existing and existing.ExpiresAt > now and existing.Assignment == assignment.PrimaryAssignment
		local laneAvailable = not laneUse[proposal.Lane] or overload
		local restSafe = defendersHeld >= 2 and midfieldersHeld >= 1 or proposal.RunType == "RecoveryRun"
		local accept = committed or approved < budget and laneAvailable and restSafe and proposal.Energy >= 15
		if accept then
			if not committed then
				self.Sequence += 1
				existing = {Id = side .. ":" .. tostring(self.Sequence), Assignment = assignment.PrimaryAssignment, StartedAt = now, ExpiresAt = now + math.clamp(1.2 + assignment.MovementUrgency, 1.2, 2.5), Lane = proposal.Lane}
				self.Tickets[proposal.Model] = existing
			end
			assignment.RunTicketId = existing.Id
			assignment.RunType = proposal.RunType
			assignment.RunLane = proposal.Lane
			assignment.RunApproved = true
			laneUse[proposal.Lane] = true
			approved += 1
		else
			assignment.SprintAllowed = false
			assignment.RunApproved = false
			assignment.RunRejection = not restSafe and "RestDefense" or not laneAvailable and "LaneReserved" or approved >= budget and "RunBudget" or "Energy"
		end
	end
	for model, ticket in self.Tickets do if not model.Parent or ticket.ExpiresAt <= now and not assignments[model] then self.Tickets[model] = nil end end
	return assignments
end

function Coordinator:Clear() table.clear(self.Tickets) end

return Coordinator
