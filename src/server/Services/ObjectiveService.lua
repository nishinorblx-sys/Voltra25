--!strict

local ObjectiveService = {}
ObjectiveService.__index = ObjectiveService

local function clientRecord(objective: any): any
	local claimed = objective.status == "claimed"
	return {
		objectiveId = objective.objectiveId,
		groupId = objective.groupId,
		title = objective.title,
		description = objective.description,
		progress = objective.progress,
		target = objective.target,
		reward = table.clone(objective.reward),
		status = objective.status,
		nextObjectiveId = objective.nextObjectiveId,
		sortOrder = objective.sortOrder,
		-- Compatibility aliases used by the existing dashboard cards.
		Id = objective.objectiveId,
		Title = objective.title,
		Description = objective.description,
		Progress = objective.progress,
		Target = objective.target,
		Reward = table.clone(objective.reward),
		Cadence = objective.cadence,
		Claimed = claimed,
		Active = objective.status ~= "locked" and not claimed,
	}
end

function ObjectiveService.Serialize(objectives: any): any
	local result = {}
	for _, objective in objectives do table.insert(result, clientRecord(objective)) end
	local groupPriority = { starter_journey = 1, daily = 2, weekly = 3, milestone = 4 }
	table.sort(result, function(first, second)
		if first.groupId == second.groupId then return first.sortOrder < second.sortOrder end
		return (groupPriority[first.groupId] or 99) < (groupPriority[second.groupId] or 99)
	end)
	return result
end

function ObjectiveService.new(profiles: any, publish: (Player, string, any) -> ())
	return setmetatable({ Profiles = profiles, Publish = publish }, ObjectiveService)
end

function ObjectiveService:GetClientData(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	return profile and ObjectiveService.Serialize(profile.Objectives) or nil
end

function ObjectiveService:Increment(player: Player, objectiveId: string, amount: number): boolean
	if type(objectiveId) ~= "string" or #objectiveId > 64 or type(amount) ~= "number" or amount % 1 ~= 0 or amount <= 0 or amount > 100 then return false end
	local profile = self.Profiles:GetProfile(player)
	if not profile then return false end
	for _, objective in profile.Objectives do
		if objective.objectiveId == objectiveId and objective.status ~= "claimed" then
			objective.progress = math.min(objective.target, objective.progress + amount)
			if objective.status == "active" and objective.progress >= objective.target then objective.status = "claimable" end
			self.Publish(player, "Objective", self:GetClientData(player))
			return true
		end
	end
	return false
end

return ObjectiveService
