--!strict
local Service = {}
Service.__index = Service

local STOPPAGE_MINUTES = {Goal = 0.95, Foul = 0.65, Corner = 0.25, GoalKick = 0.18, ThrowIn = 0.14, FreeKick = 0.28, Penalty = 0.55, Injury = 1.0, Substitution = 0.55}

function Service.new(realDuration: number)
	return setmetatable({RealDuration = realDuration, HalfRealDuration = realDuration / 2, Half = 1, HalfElapsed = 0, AddedMinutes = nil, Stoppages = {0, 0}}, Service)
end

function Service:Record(kind: string)
	self.Stoppages[self.Half] += STOPPAGE_MINUTES[kind] or 0
end

function Service:_calculateAdded(): number
	if self.AddedMinutes ~= nil then return self.AddedMinutes end
	local raw = self.Stoppages[self.Half]
	self.AddedMinutes = raw <= 0.05 and 0 or math.clamp(math.floor(raw + 0.65), 1, 5)
	return self.AddedMinutes
end

function Service:Step(dt: number)
	self.HalfElapsed += dt * 1.6
	if self.HalfElapsed >= self.HalfRealDuration then self:_calculateAdded() end
end

function Service:_rate(): number
	return 2700 / self.HalfRealDuration
end

function Service:GetRate():number return self:_rate()end

function Service:_addedRealDuration(): number
	return self:_calculateAdded() * 60 / self:_rate()
end

function Service:IsHalfComplete(): boolean
	if self.HalfElapsed < self.HalfRealDuration then return false end
	return self.HalfElapsed >= self.HalfRealDuration + self:_addedRealDuration()
end

function Service:ShouldHalfTime(): boolean
	return self.Half == 1 and self:IsHalfComplete()
end

function Service:ShouldEndMatch(): boolean
	return self.Half == 2 and self:IsHalfComplete()
end

function Service:StartSecondHalf()
	self.Half = 2
	self.HalfElapsed = 0
	self.AddedMinutes = nil
end

function Service:Payload(): any
	local nominal = math.min(self.HalfElapsed, self.HalfRealDuration) * self:_rate()
	local base = self.Half == 1 and 0 or 2700
	local addedElapsed = math.max(0, self.HalfElapsed - self.HalfRealDuration) * self:_rate()
	return {
		GameSeconds = base + nominal + addedElapsed,
		Half = self.Half,
		AddedMinutes = self.HalfElapsed >= self.HalfRealDuration and self:_calculateAdded() or 0,
		InAddedTime = self.HalfElapsed > self.HalfRealDuration,
		AddedElapsed = addedElapsed,
	}
end

return Service
