--!strict

local modes = table.freeze({"Newcomer", "Standard", "Manual"})

local aliases = {
	Assisted = "Newcomer",
	Instant = "Newcomer",
	Light = "Standard",
	Closest = "Standard",
	Off = "Manual",
	None = "Manual",
}

local values = table.freeze({
	Newcomer = table.freeze({PreviewSeconds = 0.12, ThreatETA = 1.05, MinimumAdvantage = 0.28, CurrentContestGrace = 0.18}),
	Standard = table.freeze({PreviewSeconds = 0.28, ThreatETA = 0.68, MinimumAdvantage = 0.52, CurrentContestGrace = 0.3}),
	Manual = table.freeze({PreviewSeconds = 0, ThreatETA = 0, MinimumAdvantage = math.huge, CurrentContestGrace = math.huge}),
})

local function normalize(value: any, fallback: string?): string
	local requested = tostring(value or "")
	local resolved = aliases[requested] or requested
	if values[resolved] then return resolved end
	local safe = aliases[tostring(fallback or "")] or tostring(fallback or "Standard")
	return values[safe] and safe or "Standard"
end

local function get(value: any): any
	return values[normalize(value)]
end

return table.freeze({
	Modes = modes,
	Values = values,
	Normalize = normalize,
	Get = get,
})
