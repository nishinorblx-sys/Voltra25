--!strict

local Memory = {}
Memory.__index = Memory

function Memory.new(): any
	return setmetatable({
		RecentOwners = {},
		RecentLanes = {Home = {}, Away = {}},
		RecentPlans = {Home = {}, Away = {}},
		RecentPasses = {Home = {}, Away = {}},
		LastIntent = {Home = nil, Away = nil},
		LastIntentAt = {Home = 0, Away = 0},
		LastPossessionSide = nil,
		PossessionStartedAt = 0,
		StageResetUntil = {Home = 0, Away = 0},
	}, Memory)
end

function Memory:Reset(side: string?)
	if side then
		self.RecentLanes[side] = {}
		self.RecentPlans[side] = {}
		self.RecentPasses[side] = {}
		self.LastIntent[side] = nil
		self.LastIntentAt[side] = 0
		self.StageResetUntil[side] = 0
		return
	end
	table.clear(self.RecentOwners)
	self.RecentLanes = {Home = {}, Away = {}}
	self.RecentPlans = {Home = {}, Away = {}}
	self.RecentPasses = {Home = {}, Away = {}}
	self.LastIntent = {Home = nil, Away = nil}
	self.LastIntentAt = {Home = 0, Away = 0}
	self.LastPossessionSide = nil
	self.PossessionStartedAt = 0
	self.StageResetUntil = {Home = 0, Away = 0}
end

function Memory:ObservePossession(side: string?, owner: Model?, now: number): boolean
	local changed = side ~= self.LastPossessionSide
	if side ~= self.LastPossessionSide then
		self.LastPossessionSide = side
		self.PossessionStartedAt = now
		if side == "Home" or side == "Away" then
			self.StageResetUntil[side] = now + 3.5
		end
	end
	if owner then
		table.insert(self.RecentOwners, 1, owner)
		while #self.RecentOwners > 8 do table.remove(self.RecentOwners) end
	end
	return changed
end

function Memory:CommitIntent(side: string, intent: string, now: number)
	if self.LastIntent[side] ~= intent then
		self.LastIntent[side] = intent
		self.LastIntentAt[side] = now
	end
end

function Memory:RememberPlan(side: string, plan: any)
	local list = self.RecentPlans[side]
	table.insert(list, 1, plan)
	while #list > 6 do table.remove(list) end
end

function Memory:RememberPass(side: string, passerRole: string, receiverRole: string, receiver: Model?, lane: string?, z: number?, now: number, passer: Model?)
	local list = self.RecentPasses[side]
	if not list then return end
	table.insert(list, 1, {PasserRole = passerRole, ReceiverRole = receiverRole, Passer = passer, Receiver = receiver, Lane = lane, Z = z or 0, At = now})
	while #list > 10 do table.remove(list) end
end

function Memory:RecentPassPenalty(side: string, passerRole: string, receiverRole: string, receiver: Model?, lane: string?, z: number?, planStep: string?): number
	local list = self.RecentPasses[side]
	if not list then return 0 end
	local last = list[1]
	if not last then return 0 end
	local penalty = 0
	local forwardRoles = {ST = true, Winger = true}
	if forwardRoles[passerRole] and forwardRoles[receiverRole] and forwardRoles[tostring(last.PasserRole)] and forwardRoles[tostring(last.ReceiverRole)] then
		penalty += 42
	end
	if lane and last.Lane == lane and math.abs((z or 0) - (tonumber(last.Z) or 0)) < 34 then
		penalty += 24
	end
	if receiver and last.Receiver == receiver and tostring(planStep or "") ~= "bounce-pass" and tostring(planStep or "") ~= "wall-pass" then
		penalty += 36
	end
	return penalty
end

return Memory
