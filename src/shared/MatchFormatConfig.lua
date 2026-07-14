--!strict

local formats = table.freeze({
	Quick = table.freeze({Name = "Quick", RealSeconds = 180, HalftimeSeconds = 3, ReplaySeconds = 2.5, ReplayMaximumSeconds = 4, SetPieceSeconds = 3, FullTimeSeconds = 4, FinalChanceSeconds = 6}),
	Standard = table.freeze({Name = "Standard", RealSeconds = 300, HalftimeSeconds = 7, ReplaySeconds = 3.5, ReplayMaximumSeconds = 6, SetPieceSeconds = 4, FullTimeSeconds = 6, FinalChanceSeconds = 10}),
	Extended = table.freeze({Name = "Extended", RealSeconds = 480, HalftimeSeconds = 12, ReplaySeconds = 4, ReplayMaximumSeconds = 6, SetPieceSeconds = 5, FullTimeSeconds = 8, FinalChanceSeconds = 14}),
})

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
	Normalize = normalize,
	Get = get,
})
