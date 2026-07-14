--!strict

local modes = table.freeze({"Newcomer", "Standard", "Manual"})

local aliases = {
	Assisted = "Newcomer",
	Instant = "Newcomer",
	Full = "Newcomer",
	Light = "Standard",
	Closest = "Standard",
	Off = "Manual",
	None = "Manual",
}

local values = table.freeze({
	Newcomer = table.freeze({SwitchProgress = 0.62, SwitchElapsed = 0.55, GuidanceSeconds = 0.85, TrapRadius = 7.2, InterceptionCorrection = 0.34}),
	Standard = table.freeze({SwitchProgress = 0.78, SwitchElapsed = 0.72, GuidanceSeconds = 0.42, TrapRadius = 5.1, InterceptionCorrection = 0.12}),
	Manual = table.freeze({SwitchProgress = 2, SwitchElapsed = math.huge, GuidanceSeconds = 0, TrapRadius = 3.8, InterceptionCorrection = 0}),
})

local function normalize(value: any, fallback: string?): string
	local requested = tostring(value or "")
	local resolved = aliases[requested] or requested
	if values[resolved] ~= nil then
		return resolved
	end
	local safeFallback = aliases[tostring(fallback or "")] or tostring(fallback or "Standard")
	if values[safeFallback] ~= nil then
		return safeFallback
	end
	return "Standard"
end

local function get(value: any): any
	return values[normalize(value)]
end

return table.freeze({
	Modes = modes,
	Values = values,
	Normalize = normalize,
	Get = get,
	DecisiveInputThreshold = 0.55,
	FirstTouchMinimumSeconds = 0.2,
	FirstTouchMaximumSeconds = 0.35,
})
