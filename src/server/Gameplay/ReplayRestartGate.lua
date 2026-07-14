--!strict

local Gate = {}
Gate.__index = Gate

function Gate.new(replayId: number, participants: {Instance})
	local required: {[Instance]: boolean} = {}
	for _, participant in participants do
		required[participant] = true
	end
	return setmetatable({
		ReplayId = replayId,
		Required = required,
		Finished = {} :: {[Instance]: boolean},
	}, Gate)
end

function Gate:Acknowledge(participant: Instance, replayId: number): boolean
	if replayId ~= self.ReplayId or self.Required[participant] ~= true then
		return false
	end
	self.Finished[participant] = true
	return true
end

function Gate:IsComplete(isActive: ((Instance) -> boolean)?): boolean
	for participant in self.Required do
		if (not isActive or isActive(participant)) and self.Finished[participant] ~= true then
			return false
		end
	end
	return true
end

function Gate:PendingCount(isActive: ((Instance) -> boolean)?): number
	local count = 0
	for participant in self.Required do
		if (not isActive or isActive(participant)) and self.Finished[participant] ~= true then
			count += 1
		end
	end
	return count
end

return Gate
