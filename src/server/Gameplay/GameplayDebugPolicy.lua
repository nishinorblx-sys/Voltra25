--!strict

local Policy = {}

function Policy.CanUse(actionType: string, context: any): (boolean, string)
	context = type(context) == "table" and context or {}
	if context.OptIn ~= true then return false, "DISABLED" end
	if context.Authorized ~= true then return false, "UNAUTHORIZED" end
	if context.IsStudio ~= true and context.IsPrivateServer ~= true then return false, "PUBLIC_SERVER" end
	if context.Ranked == true then return false, "RANKED" end
	if context.WorldCup == true then return false, "WORLD_CUP" end
	if actionType == "ShootingPracticeTuning" and context.ShootingPractice ~= true then return false, "WRONG_CONTEXT" end
	if context.RateReady ~= true then return false, "RATE_LIMITED" end
	return true, "OK"
end

return table.freeze(Policy)
