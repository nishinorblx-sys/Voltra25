--!strict

local Config = require(script.Parent.CampaignAscensionConfig)

local Resolver = {}

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[copy(key)] = copy(child) end
	return result
end

local function number(value: any, fallback: number): number
	return tonumber(value) or fallback
end

local function addClamped(target: any, boosts: any)
	if type(boosts) ~= "table" then return end
	for key, amount in boosts do target[key] = math.clamp(number(target[key], 1) + number(amount, 0), 1, 99) end
end

local function appendUnique(target: any, values: any)
	if type(values) ~= "table" then return end
	for _, value in values do
		if type(value) == "string" and value ~= "" and not table.find(target, value) then table.insert(target, value) end
	end
end

function Resolver.Resolve(card: any, meta: any?): any
	local resolved = copy(type(card) == "table" and card or {})
	meta = type(meta) == "table" and meta or {}
	local progression = type(meta.CampaignProgression) == "table" and meta.CampaignProgression or {}
	local baseOverall = number(resolved.BaseOverall or resolved.BaseRating or resolved.overall or resolved.Rating, 1)
	local boost = math.clamp(math.floor(number(progression.OverallBoost, 0)), 0, Config.Project.MaximumOverallBoost)
	local effective = math.min(Config.Project.MaximumEffectiveOverall, baseOverall + boost)
	resolved.BaseOverall = baseOverall
	resolved.BaseRating = baseOverall
	resolved.CampaignOverallBoost = effective - baseOverall
	resolved.overall = effective
	resolved.Rating = effective

	local main = copy(resolved.BaseMainStats or resolved.mainStats or resolved.MainStats or {})
	resolved.BaseMainStats = copy(main)
	addClamped(main, progression.MainStatBoosts)
	resolved.mainStats = main
	resolved.MainStats = copy(main)
	for key, value in main do resolved[key] = value end

	local detailed = copy(resolved.BaseDetailedStats or resolved.detailedStats or resolved.DetailedStats or {})
	resolved.BaseDetailedStats = copy(detailed)
	addClamped(detailed, progression.DetailedStatBoosts)
	resolved.detailedStats = detailed
	resolved.DetailedStats = copy(detailed)

	local positions = copy(resolved.BasePositions or resolved.positions or {})
	if #positions == 0 and type(resolved.bestPosition or resolved.Position) == "string" then table.insert(positions, resolved.bestPosition or resolved.Position) end
	resolved.BasePositions = copy(positions)
	appendUnique(positions, progression.AddedPositions)
	resolved.positions = positions

	local baseWeakFoot = math.clamp(math.floor(number(resolved.BaseWeakFoot or resolved.weakFoot or resolved.WeakFoot, 1)), 1, 5)
	local baseSkillMoves = math.clamp(math.floor(number(resolved.BaseSkillMoves or resolved.skillMoves or resolved.SkillMoves, 1)), 1, 5)
	resolved.BaseWeakFoot = baseWeakFoot
	resolved.BaseSkillMoves = baseSkillMoves
	resolved.weakFoot = math.clamp(baseWeakFoot + math.floor(number(progression.WeakFootBoost, 0)), 1, 5)
	resolved.WeakFoot = resolved.weakFoot
	resolved.skillMoves = math.clamp(baseSkillMoves + math.floor(number(progression.SkillMovesBoost, 0)), 1, 5)
	resolved.SkillMoves = resolved.skillMoves

	local playStyles = copy(resolved.BasePlayStyles or resolved.playStyles or resolved.PlayStyles or {})
	resolved.BasePlayStyles = copy(playStyles)
	appendUnique(playStyles, progression.PlayStyles)
	resolved.playStyles = playStyles
	resolved.PlayStyles = copy(playStyles)

	local bound = meta.CampaignBound == true or meta.CampaignReward == true or progression.CampaignBound == true
	resolved.CampaignVariant = meta.CampaignVariant or progression.CampaignVariant or (bound and "Ascension" or nil)
	resolved.CampaignVisualTier = progression.VisualTier or meta.CampaignVisualTier
	resolved.CampaignBound = bound
	resolved.QuickSellBlocked = meta.QuickSellBlocked == true or bound
	resolved.TransferBlocked = meta.TransferBlocked == true or bound
	resolved.AcquisitionSource = meta.AcquisitionSource
	resolved.CampaignDivisionId = meta.CampaignDivisionId
	resolved.CampaignSeasonId = meta.CampaignSeasonId
	resolved.Meta = copy(meta)
	resolved.Meta.CampaignBound = bound
	resolved.Meta.CampaignVariant = resolved.CampaignVariant
	resolved.Meta.CampaignVisualTier = resolved.CampaignVisualTier
	return resolved
end

function Resolver.IsBound(meta: any?): boolean
	if type(meta) ~= "table" then return false end
	local progression = type(meta.CampaignProgression) == "table" and meta.CampaignProgression or {}
	return meta.CampaignBound == true or meta.CampaignReward == true or meta.QuickSellBlocked == true or meta.TransferBlocked == true or progression.CampaignBound == true
end

return table.freeze(Resolver)
