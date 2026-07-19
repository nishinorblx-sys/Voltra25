--!strict

local PitchConfig = require(script.Parent.Parent.PitchConfig)

local Solver = {}

local function roleCost(info: any, family: string): number
	if family == "GK" then return info.IsGoalkeeper and -80 or 200 end
	if info.Role == family then return -35 end
	if family == "CB" and (info.Role == "Fullback" or info.Role == "CDM") then return -10 end
	if family == "CM" and (info.Role == "CDM" or info.Role == "CAM") then return -12 end
	if family == "Winger" and (info.Role == "Fullback" or info.Role == "CAM") then return -6 end
	if family == "ST" and (info.Role == "Winger" or info.Role == "CAM") then return -8 end
	return 20
end

function Solver.Assign(context: any, side: string, slots: {any}): any
	local assignments = {}
	local used = {}
	table.sort(slots, function(a, b) return (a.Priority or 0) > (b.Priority or 0) end)
	for _, slot in ipairs(slots) do
		local best = nil
		local bestScore = math.huge
		for _, info in ipairs(context.Teams[side].List) do
			if info.Root and not used[info.Model] and info.IsUserControlled ~= true then
				local distance = PitchConfig.GetDistanceStuds(info.Pitch, slot.TargetPitch)
				local stamina = math.clamp(tonumber(info.Stamina) or tonumber(info.Model:GetAttribute("VTRSprintEnergy")) or 75, 0, 100)
				local score = distance + roleCost(info, slot.RoleFamily) - stamina * .04
				if score < bestScore then
					best = info
					bestScore = score
				end
			end
		end
		if best then
			used[best.Model] = true
			local targetWorld = PitchConfig.TeamPitchPositionToWorld(slot.TargetPitch, side, context.Options)
			assignments[best.Model] = {
				Model = best.Model,
				Info = best,
				Role = best.Role,
				Phase = context.OwnerSide == side and "TeamPossession" or "TeamDefense",
				PrimaryAssignment = slot.Id,
				MovementTarget = targetWorld,
				TargetWorld = targetWorld,
				TargetPitch = slot.TargetPitch,
				MovementUrgency = slot.SprintAllowed and .94 or .72,
				SprintAllowed = slot.SprintAllowed,
				FaceWorld = context.BallWorld,
				SupportTarget = context.Owner,
				TacticalSlot = slot,
			}
			best.Model:SetAttribute("AITacticalSlot", slot.Id)
			best.Model:SetAttribute("AIRestDefense", slot.RestDefense)
		end
	end
	return assignments
end

return Solver
