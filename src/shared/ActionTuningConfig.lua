--!strict

export type ActionProfile = {
	FullChargeSeconds: number,
	TapOutput: number,
	CommonOutput: number,
	MaximumOutput: number,
	SweetStart: number,
	SweetEnd: number,
	ReleaseFallbackSeconds: number,
}

local profiles: {[string]: ActionProfile} = {
	Ground = {FullChargeSeconds = 0.65, TapOutput = 0.24, CommonOutput = 0.72, MaximumOutput = 1, SweetStart = 0.3, SweetEnd = 0.82, ReleaseFallbackSeconds = 0.16},
	Through = {FullChargeSeconds = 0.75, TapOutput = 0.28, CommonOutput = 0.76, MaximumOutput = 1, SweetStart = 0.32, SweetEnd = 0.82, ReleaseFallbackSeconds = 0.17},
	Lob = {FullChargeSeconds = 0.84, TapOutput = 0.22, CommonOutput = 0.74, MaximumOutput = 1, SweetStart = 0.34, SweetEnd = 0.84, ReleaseFallbackSeconds = 0.19},
	Shot = {FullChargeSeconds = 0.92, TapOutput = 0.2, CommonOutput = 0.78, MaximumOutput = 1, SweetStart = 0.34, SweetEnd = 0.82, ReleaseFallbackSeconds = 0.18},
	Clearance = {FullChargeSeconds = 0.65, TapOutput = 0.3, CommonOutput = 0.8, MaximumOutput = 1, SweetStart = 0.28, SweetEnd = 0.8, ReleaseFallbackSeconds = 0.15},
}

local aliases = {
	Pass = "Ground",
	GroundPass = "Ground",
	Manual = "Ground",
	ManualGround = "Ground",
	ThroughPass = "Through",
	Lofted = "Lob",
	Cross = "Lob",
	LobPass = "Lob",
	Shoot = "Shot",
}

local function normalizeAction(action: any): string
	local value = tostring(action or "Ground")
	local normalized = aliases[value] or value
	if profiles[normalized] == nil then
		return "Ground"
	end
	return normalized
end

local function profile(action: any): ActionProfile
	return profiles[normalizeAction(action)]
end

local function normalizedCharge(action: any, heldSeconds: any): number
	local duration = math.max(0, tonumber(heldSeconds) or 0)
	return math.clamp(duration / profile(action).FullChargeSeconds, 0, 1)
end

local function evaluateNormalized(action: any, normalized: any): number
	local value = math.clamp(tonumber(normalized) or 0, 0, 1)
	local selected = profile(action)
	if value <= 0.14 then
		local alpha = (value / 0.14) ^ 0.58
		return selected.TapOutput + (0.4 - selected.TapOutput) * alpha
	end
	if value <= 0.86 then
		local alpha = ((value - 0.14) / 0.72) ^ 1.08
		return 0.4 + (selected.CommonOutput - 0.4) * alpha
	end
	local alpha = ((value - 0.86) / 0.14) ^ 1.7
	return selected.CommonOutput + (selected.MaximumOutput - selected.CommonOutput) * alpha
end

return table.freeze({
	Profiles = table.freeze(profiles),
	QueueNormalSeconds = 0.35,
	QueueImminentSeconds = 0.58,
	QueueImminentArrivalSeconds = 0.7,
	MobileDeadZonePixels = 11,
	MobileMaximumDragPixels = 132,
	MobilePassSwipePixels = 54,
	NormalizeAction = normalizeAction,
	Profile = profile,
	NormalizedCharge = normalizedCharge,
	EvaluateNormalized = evaluateNormalized,
})
