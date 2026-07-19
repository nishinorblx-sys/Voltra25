--!strict

local Metrics = {}
Metrics.__index = Metrics

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
	}, Metrics)
end

function Metrics:Sample(key: string, seconds: number)
	local ms = math.max(0, seconds * 1000)
	self[key] = ms
	if key ~= "WorstFrameMs" then
		self.WorstFrameMs = math.max(self.WorstFrameMs, ms)
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
		IntentMs = self.IntentMs,
		StructureMs = self.StructureMs,
		AssignmentMs = self.AssignmentMs,
		CarrierMs = self.CarrierMs,
		DefenseMs = self.DefenseMs,
		WorstFrameMs = self.WorstFrameMs,
		Frames = self.Frames,
		Cells = self.Cells,
		Candidates = self.Candidates,
		Plans = self.Plans,
	}
end

return Metrics
