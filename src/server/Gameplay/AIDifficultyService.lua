--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DifficultyConfig = require(ReplicatedStorage.VTR.Shared.DifficultyConfig)

local Service = {}

function Service.Resolve(name: string?, random: Random?): any
	local canonical = DifficultyConfig.ResolveName(name)
	local resolved: any = table.clone(DifficultyConfig.Definitions[canonical])
	resolved.Name = canonical
	resolved.Random = random or Random.new()
	return resolved
end

function Service.NextDecisionDelay(difficulty: any): number
	local random = difficulty.Random or Random.new()
	return math.max(.18, random:NextNumber(difficulty.DecisionMin or .25, difficulty.DecisionMax or .45))
end

function Service.ApplyMistake(value: number, difficulty: any, scale: number?): number
	local mistake = (difficulty.Mistake or 0) * math.max(0, scale or 0)
	if mistake <= 0 then return value end
	local random = difficulty.Random or Random.new()
	return value + random:NextNumber(-mistake, mistake)
end

function Service.FirstMatchBlend(restoreStartedAt: number?, now: number?): number
	if restoreStartedAt == nil then return 1 end
	local duration = math.max(1, tonumber(DifficultyConfig.FirstMatch.RestoreSeconds) or 90)
	return 1 - math.clamp(((tonumber(now) or os.clock()) - restoreStartedAt) / duration, 0, 1)
end

function Service.FirstMatchPassTempoCap(blend: number): number
	local minimum = math.clamp(tonumber(DifficultyConfig.FirstMatch.MaximumOneTouchTempo) or .65, 0, 1)
	return minimum + (1 - minimum) * (1 - math.clamp(blend, 0, 1))
end

return Service
