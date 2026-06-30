--!strict
local Service = {}

function Service.AttackingWorkRate(info: any): number
	local rate = tostring(info.Stats.workRateAttack or "Medium")
	return rate == "High" and 1 or rate == "Low" and 0.35 or 0.65
end

function Service.DefensiveWorkRate(info: any): number
	local rate = tostring(info.Stats.workRateDefense or "Medium")
	return rate == "High" and 1 or rate == "Low" and 0.35 or 0.65
end

function Service.RunBehindBias(info: any): number
	local pace = tonumber(info.Stats.pace) or 60
	local attackRate = Service.AttackingWorkRate(info)
	return (pace - 55) * 0.08 + attackRate * 8
end

function Service.SupportBias(info: any): number
	local passing = tonumber(info.Stats.shortPassing) or tonumber(info.Stats.passing) or 60
	return (passing - 55) * 0.06 + Service.AttackingWorkRate(info) * 5
end

function Service.PressBias(info: any): number
	local defending = tonumber(info.Stats.defending) or 60
	local stamina = tonumber(info.Stamina) or 60
	return (defending - 55) * 0.08 + Service.DefensiveWorkRate(info) * 8 + stamina * 0.035
end

return Service
