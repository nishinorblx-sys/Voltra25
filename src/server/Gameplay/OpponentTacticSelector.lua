--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AITacticConfig = require(ReplicatedStorage.VTR.Shared.AITacticConfig)

local Selector = {}

local identityMap = {
	high_press = "high_press", low_block = "low_block_counter", counter_attack = "counter_attack", wing_play = "wing_overload", possession = "short_possession", direct_long_ball = "vertical_combination", balanced_rival = "balanced_control", promotion_boss = "high_press",
}

local function rosterPreset(roster: any): string
	local formation = tostring(roster and roster.Formation or roster and roster.Team and roster.Team.formation or "")
	if formation:sub(1, 1) == "5" then return "low_block_counter" end
	local wide, paceTotal, paceCount = 0, 0, 0
	for _, player in ipairs(roster and roster.StartingXI or {}) do
		local position = tostring(player.position or player.bestPosition or "")
		if position == "LW" or position == "RW" or position == "LM" or position == "RM" then wide += 1 end
		local pace = tonumber(player.pace or player.PAC)
		if pace then paceTotal += pace;paceCount += 1 end
	end
	if wide >= 2 then return "wing_overload" end
	if paceCount > 0 and paceTotal / paceCount >= 76 then return "counter_attack" end
	if formation == "4-2-3-1" then return "central_overload" end
	return "balanced_control"
end

function Selector.Resolve(input: any): any
	local source = type(input) == "table" and input or {}
	local override = source.FixtureOverride or source.Override
	if type(override) == "table" then return AITacticConfig.Normalize(override) end
	local fixture = type(source.Fixture) == "table" and source.Fixture or {}
	local fixtureId = identityMap[tostring(fixture.TacticIdentity or "")]
	if fixtureId then return AITacticConfig.Normalize({PresetId = fixtureId, Sliders = fixture.TacticModifiers}) end
	local metadata = type(source.TeamMetadata) == "table" and source.TeamMetadata or {}
	local metadataId = metadata.TacticPresetId or metadata.TacticPreset or metadata.Tactics
	if metadataId then return AITacticConfig.Normalize({PresetId = metadataId, Sliders = metadata.TacticModifiers}) end
	return AITacticConfig.Normalize({PresetId = rosterPreset(source.Roster)})
end

function Selector.Scout(input: any): any
	local tactics = Selector.Resolve(input)
	local preset = AITacticConfig.Get(tactics.PresetId)
	return {PresetId = preset.Id, Name = preset.Name, Description = preset.Description, Risk = preset.Risk, StaminaDemand = preset.StaminaDemand, InPossessionShape = preset.InPossessionShape, OutOfPossessionShape = preset.OutOfPossessionShape, RestDefenseShape = preset.RestDefenseShape, Strengths = table.clone(preset.Strengths), Weaknesses = table.clone(preset.Weaknesses), MaxMajorRuns = preset.MaxMajorRuns, MaxPressers = preset.MaxPressers}
end

return table.freeze(Selector)
