--!strict

local formats = table.freeze({
	Quick = table.freeze({Name = "Quick", RealSeconds = 180, HalftimeSeconds = 3, ExtraTimeSeconds = 75, ExtraTimeMidpointBreakSeconds = 5, ReplaySeconds = 3, ReplayMaximumSeconds = 6, SetPieceSeconds = 3.5, SetPieceDecisionSeconds = 3.5, SetPieceCameraTransitionSeconds = .48, FinalWhistleFreezeSeconds = 1.1, PostMatchSummarySeconds = 2.2, ResultsVisibleSeconds = 4, NextMatchInputSeconds = 8, FullTimeSeconds = 4, FinalChanceSeconds = 6}),
	Standard = table.freeze({Name = "Standard", RealSeconds = 300, HalftimeSeconds = 7, ExtraTimeSeconds = 120, ExtraTimeMidpointBreakSeconds = 7, ReplaySeconds = 3.5, ReplayMaximumSeconds = 6, SetPieceSeconds = 4, SetPieceDecisionSeconds = 4, SetPieceCameraTransitionSeconds = .5, FinalWhistleFreezeSeconds = 1.25, PostMatchSummarySeconds = 2.4, ResultsVisibleSeconds = 4, NextMatchInputSeconds = 8, FullTimeSeconds = 4, FinalChanceSeconds = 10}),
	Extended = table.freeze({Name = "Extended", RealSeconds = 480, HalftimeSeconds = 12, ExtraTimeSeconds = 180, ExtraTimeMidpointBreakSeconds = 11, ReplaySeconds = 4, ReplayMaximumSeconds = 6, SetPieceSeconds = 5, SetPieceDecisionSeconds = 5, SetPieceCameraTransitionSeconds = .55, FinalWhistleFreezeSeconds = 1.35, PostMatchSummarySeconds = 2.6, ResultsVisibleSeconds = 4, NextMatchInputSeconds = 8, FullTimeSeconds = 4, FinalChanceSeconds = 14}),
})

local ranked = table.freeze({Name = "Ranked", ExtraTimeSeconds = 120, ExtraTimeMidpointBreakSeconds = 7, ReplaySeconds = 3.5, ReplayMaximumSeconds = 6, SetPieceDecisionSeconds = 4, SetPieceCameraTransitionSeconds = .5, FinalWhistleFreezeSeconds = 1.25, PostMatchSummarySeconds = 2.4, ResultsVisibleSeconds = 4, NextMatchInputSeconds = 8})

local aliases = {
	Short = "Quick",
	Normal = "Standard",
	Full = "Extended",
	Long = "Extended",
}

local function normalize(value: any): string
	if type(value) == "number" then
		if value <= 4 then
			return "Quick"
		elseif value <= 6 then
			return "Standard"
		end
		return "Extended"
	end
	local text = tostring(value or "")
	local resolved = aliases[text] or text
	if formats[resolved] ~= nil then
		return resolved
	end
	local numeric = tonumber(text)
	if numeric ~= nil then
		return normalize(numeric)
	end
	return "Standard"
end

local function get(value: any): any
	return formats[normalize(value)]
end

return table.freeze({
	Names = table.freeze({"Quick", "Standard", "Extended"}),
	Formats = formats,
	Ranked = ranked,
	Normalize = normalize,
	Get = get,
})
