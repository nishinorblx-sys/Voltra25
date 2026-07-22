--!strict

local Config = require(script.Parent.MatchMomentumConfig)

local Service = {}
Service.__index = Service

local function otherTeam(team: string): string
	return team == "Away" and "Home" or "Away"
end

local function attackSign(team: string, half: number): number
	if team == "Home" then return half >= 2 and 1 or -1 end
	return half >= 2 and -1 or 1
end

local function weightFor(eventType: string, value: number?): number
	if value ~= nil then return math.max(0, value) end
	return tonumber((Config.EventWeights :: any)[eventType]) or 0
end

function Service.new(pitchCFrame: CFrame, width: number, length: number)
	return setmetatable({
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		Events = {},
		Markers = {},
		Samples = {},
		LastSampleTime = -math.huge,
		PreviousMomentum = 0,
		LastOwner = nil,
		LastOwnerTeam = nil,
		LastBallPosition = nil,
		LastHalf = 1,
	}, Service)
end

function Service:AddEvent(team: string, eventType: string, gameSeconds: number?, value: number?)
	team = team == "Away" and "Away" or "Home"
	local at = math.max(0, tonumber(gameSeconds) or 0)
	local eventValue = weightFor(eventType, value)
	if eventValue > 0 then
		table.insert(self.Events, {
			Team = team,
			Time = at,
			Type = eventType,
			Value = eventValue,
			Major = (Config.MajorEvents :: any)[eventType] == true,
		})
	end
	local markerType = (Config.MarkerEvents :: any)[eventType]
	if markerType then
		table.insert(self.Markers, {Team = team, Time = at, Type = markerType})
	end
end

function Service:AddOpponentEvent(team: string, eventType: string, gameSeconds: number?, value: number?)
	self:AddEvent(otherTeam(team), eventType, gameSeconds, value)
end

local function pressureZone(self: any, team: string, position: Vector3?, half: number): string
	if not position then return "MidfieldPossession" end
	local localPosition = self.PitchCFrame:PointToObjectSpace(position)
	local sign = attackSign(team, half)
	local progress = math.clamp((localPosition.Z * sign) / math.max(1, self.Length) + 0.5, 0, 1)
	if progress >= 0.84 and math.abs(localPosition.X) <= self.Width * 0.27 then
		return "BoxEntry"
	end
	if progress >= 0.67 then return "FinalThirdPossession" end
	if progress >= 0.5 then return "OpponentHalfPossession" end
	if progress >= 0.28 then return "MidfieldPossession" end
	return "DefensiveThirdPossession"
end

function Service:_pressureAt(now: number): (number, number, boolean)
	local homePressure = 0
	local awayPressure = 0
	local major = false
	local window = math.max(1, Config.RollingWindowSeconds)
	for index = #self.Events, 1, -1 do
		local event = self.Events[index]
		local age = now - (tonumber(event.Time) or 0)
		if age > window then
			if index < #self.Events - 80 then break end
			continue
		end
		if age >= 0 then
			local recency = 1 - math.clamp(age / window, 0, 1)
			local weighted = (tonumber(event.Value) or 0) * (0.3 + recency * 0.7)
			if event.Team == "Away" then awayPressure += weighted else homePressure += weighted end
			major = major or event.Major == true and age <= Config.SampleMatchSeconds * 1.35
		end
	end
	return homePressure, awayPressure, major
end

function Service:_sample(now: number)
	local homePressure, awayPressure, major = self:_pressureAt(now)
	if self.LastOwnerTeam then
		local zone = pressureZone(self, self.LastOwnerTeam, self.LastBallPosition, self.LastHalf)
		local zoneValue = tonumber((Config.EventWeights :: any)[zone]) or 0
		if self.LastOwnerTeam == "Away" then awayPressure += zoneValue else homePressure += zoneValue end
	end
	local raw = math.clamp((homePressure - awayPressure) / math.max(1, Config.MaxPressure), -1, 1)
	local previousWeight = major and Config.BigEventSmoothingPrevious or Config.SmoothingPrevious
	local incomingWeight = major and Config.BigEventSmoothingIncoming or Config.SmoothingIncoming
	local smoothed = math.clamp(self.PreviousMomentum * previousWeight + raw * incomingWeight, -1, 1)
	self.PreviousMomentum = smoothed
	local sample = {
		Time = now,
		Momentum = math.floor(smoothed * 1000 + 0.5) / 1000,
		HomePressure = math.floor(homePressure * 10 + 0.5) / 10,
		AwayPressure = math.floor(awayPressure * 10 + 0.5) / 10,
	}
	table.insert(self.Samples, sample)
	while #self.Samples > Config.MaxSamples do table.remove(self.Samples, 1) end
end

function Service:Step(gameSeconds: number, owner: Model?, ballPosition: Vector3?, half: number?)
	local now = math.max(0, tonumber(gameSeconds) or 0)
	self.LastBallPosition = ballPosition
	self.LastHalf = math.max(1, math.floor(tonumber(half) or self.LastHalf or 1))
	self.LastOwner = owner
	self.LastOwnerTeam = owner and tostring(owner:GetAttribute("VTRTeam") or "Home") or nil
	if now - (tonumber(self.LastSampleTime) or -math.huge) >= Config.SampleMatchSeconds then
		self.LastSampleTime = now
		self:_sample(now)
	end
end

function Service:Serialize(maxTime: number?): any
	local endTime = math.max(1, tonumber(maxTime) or 0)
	for _, sample in self.Samples do endTime = math.max(endTime, tonumber(sample.Time) or 0) end
	local periods = {{Time = endTime * 0.5, Label = "HT"}}
	if endTime > 90 * 60 then table.insert(periods, {Time = 90 * 60, Label = "90"}) end
	return {
		Samples = table.clone(self.Samples),
		Markers = table.clone(self.Markers),
		Periods = periods,
		MaxTime = endTime,
		SampleInterval = Config.SampleMatchSeconds,
	}
end

return Service
