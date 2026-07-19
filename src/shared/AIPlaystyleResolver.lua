--!strict

local AITacticConfig = require(script.Parent.AITacticConfig)
local AIBehaviorTuningConfig = require(script.Parent.AIBehaviorTuningConfig)
local AIPlaystyleConfig = require(script.Parent.AIPlaystyleConfig)

local Resolver = {}

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end

local function findPublished(repository: any, id: string, version: any): any?
	local published = repository and repository.Published
	if type(published) ~= "table" then return nil end
	local family = published[id]
	if type(family) ~= "table" then return nil end
	if version ~= nil and family[tostring(version)] then return family[tostring(version)] end
	local bestVersion = 0
	local best = nil
	for key, item in pairs(family) do
		local numeric = tonumber(key) or 0
		if numeric > bestVersion then
			bestVersion = numeric
			best = item
		end
	end
	return best
end

function Resolver.ResolvePlaystyle(ref: any, repository: any?): any
	if type(ref) == "table" and ref.Tactics then
		return AIPlaystyleConfig.Normalize(ref)
	end
	local id = type(ref) == "table" and tostring(ref.PlaystyleId or ref.Id or ref.PresetId or "") or tostring(ref or "")
	local version = type(ref) == "table" and ref.Version or nil
	if id ~= "" then
		local published = findPublished(repository, id, version)
		if published then return AIPlaystyleConfig.Normalize(published) end
		if repository and type(repository.Drafts) == "table" and repository.Drafts[id] then return AIPlaystyleConfig.Normalize(repository.Drafts[id]) end
	end
	local builtIn = AIPlaystyleConfig.ResolveBuiltIn(id)
	return builtIn or AIPlaystyleConfig.ResolveBuiltIn("balanced_control")
end

function Resolver.ResolveTactics(ref: any, repository: any?, context: any?): any
	local playstyle = Resolver.ResolvePlaystyle(ref, repository)
	local tactics = AITacticConfig.Normalize(playstyle.Tactics)
	local base = AITacticConfig.Get(tactics.PresetId).Sliders
	if type(context) == "table" then
		local resolved = AIBehaviorTuningConfig.Resolve(base, tactics, context)
		for key, value in pairs(resolved) do tactics.Sliders[key] = value end
	else
		local profile = AIBehaviorTuningConfig.NormalizeProfile(tactics, base)
		tactics.GlobalOverrides = profile.GlobalOverrides
		tactics.PhaseOverrides = profile.PhaseOverrides
		tactics.RoleOverrides = profile.RoleOverrides
		tactics.MatchStateOverrides = profile.MatchStateOverrides
		tactics.ExecutionOverrides = profile.ExecutionOverrides
	end
	tactics.PlaystyleId = playstyle.PlaystyleId
	tactics.PlaystyleVersion = playstyle.Version
	tactics.PlaystyleName = playstyle.Name
	tactics.PlaystyleStatus = playstyle.Status
	tactics.PassRules = clone(playstyle.PassRules)
	tactics.PositioningRules = clone(playstyle.PositioningRules)
	tactics.PressRules = clone(playstyle.PressRules)
	tactics.RoleInstructions = clone(playstyle.RoleInstructions)
	tactics.SequenceRules = clone(playstyle.SequenceRules)
	tactics.MetricsTargets = clone(playstyle.MetricsTargets)
	return tactics
end

function Resolver.Assignments(repository: any?): any
	local assignments = repository and repository.Assignments
	return type(assignments) == "table" and clone(assignments) or {Home = {PlaystyleId = "balanced_control", Version = 1}, Away = {PlaystyleId = "balanced_control", Version = 1}}
end

function Resolver.ResolveSide(side: string, repository: any?, fallback: any?): any
	local assignments = Resolver.Assignments(repository)
	local ref = assignments[side == "Away" and "Away" or "Home"] or fallback or {PlaystyleId = "balanced_control", Version = 1}
	return Resolver.ResolveTactics(ref, repository)
end

return table.freeze(Resolver)
