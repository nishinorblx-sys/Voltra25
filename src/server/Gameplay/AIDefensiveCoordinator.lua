--!strict

local Coordinator = {}
Coordinator.__index = Coordinator

local pressureNames = {
	PressBallCarrier = true, ContainBallCarrier = true, CloseLongCarryGap = true, PrimaryPressRotation = true, AggressiveCBPressStriker = true, AggressiveFullbackPressWinger = true, AggressiveMidfieldPress = true, AggressiveCBStepOut = true, AggressiveFullbackStepOut = true, MidfielderPressureMidfielder = true, EarlyCBPressPassTarget = true, EarlyFullbackPressPassTarget = true, EarlyMidfielderPressPassTarget = true, EarlyClosePassTargetPressure = true,
}

function Coordinator.new(style: any)
	return setmetatable({Style = style, Duties = {}}, Coordinator)
end

function Coordinator:Coordinate(context: any, side: string, assignments: any): any
	local owner = context.Owner and context.Players[context.Owner] or nil
	local candidates = {}
	if owner then
		for model, assignment in assignments do
			local info = context.Players[model]
			if info and not info.IsGoalkeeper then
				local distance = (info.World - owner.World).Magnitude
				local roleBias = (info.Role == "CM" or info.Role == "CDM" or info.Role == "CAM") and -8 or info.Role == "Fullback" and -3 or info.Role == "CB" and 6 or 0
				table.insert(candidates, {Model = model, Assignment = assignment, Info = info, Score = distance + roleBias - (tonumber(assignment.PressPriority) or 0)})
			end
		end
	end
	table.sort(candidates, function(a, b) if a.Score == b.Score then return a.Model.Name < b.Model.Name end;return a.Score < b.Score end)
	local pressBudget = math.max(1, tonumber(self.Style.MaxPressers) or 2)
	local primary, cover = candidates[1], pressBudget >= 2 and candidates[2] or nil
	local cbStep = nil
	for _, item in candidates do
		local assignment = item.Assignment
		local duty = "RestBlock"
		if item == primary then duty = "PrimaryPresser"
		elseif item == cover then duty = "CoverPresser"
		elseif item.Info.Role == "CDM" then duty = "CentralLaneBlocker"
		elseif item.Info.Role == "CB" and not cbStep then duty = "BoxCenterProtector";cbStep = item
		elseif item.Info.Role == "CB" then duty = "PenaltySpotProtector"
		elseif item.Info.Role == "Fullback" and item.Info.Pitch.X < 212 then duty = "CutbackProtector"
		elseif item.Info.Role == "Fullback" then duty = "FarPostProtector"
		elseif item.Info.Role == "ST" then duty = "CounterOutlet" end
		assignment.DefensiveDuty = duty
		self.Duties[item.Model] = duty
		if pressureNames[assignment.PrimaryAssignment] and item ~= primary and item ~= cover then assignment.SprintAllowed = false end
		if item == primary then assignment.SprintAllowed = true
		elseif item == cover then assignment.SprintAllowed = false end
	end
	return assignments
end

function Coordinator:Clear() table.clear(self.Duties) end

return Coordinator
