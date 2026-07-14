--!strict

local function entry(runtime: {[string]: number}, execution: {[string]: number}): {[string]: number}
	local value = table.clone(runtime)
	for key, amount in execution do value[key] = amount end
	return table.freeze(value)
end

local definitions = table.freeze({
	["Kickabout"] = entry({DecisionMin=.55,DecisionMax=.85,Mistake=.36,Discipline=.28,PassRisk=.18,ShotSelect=.26,Press=.25,Stamina=.66},{Reaction=.65,Positioning=.32,PassAccuracy=.48,ShotAccuracy=.38,Tackle=.24,Aggression=.24}),
	["Street Level"] = entry({DecisionMin=.48,DecisionMax=.72,Mistake=.28,Discipline=.38,PassRisk=.24,ShotSelect=.35,Press=.35,Stamina=.72},{Reaction=.5,Positioning=.45,PassAccuracy=.58,ShotAccuracy=.48,Tackle=.35,Aggression=.35}),
	["Sunday League"] = entry({DecisionMin=.44,DecisionMax=.68,Mistake=.23,Discipline=.44,PassRisk=.29,ShotSelect=.41,Press=.4,Stamina=.75},{Reaction=.45,Positioning=.52,PassAccuracy=.63,ShotAccuracy=.53,Tackle=.41,Aggression=.41}),
	["Local League"] = entry({DecisionMin=.4,DecisionMax=.65,Mistake=.2,Discipline=.5,PassRisk=.34,ShotSelect=.46,Press=.44,Stamina=.78},{Reaction=.4,Positioning=.58,PassAccuracy=.68,ShotAccuracy=.58,Tackle=.48,Aggression=.48}),
	["City Division"] = entry({DecisionMin=.34,DecisionMax=.58,Mistake=.17,Discipline=.56,PassRisk=.41,ShotSelect=.52,Press=.5,Stamina=.81},{Reaction=.36,Positioning=.65,PassAccuracy=.73,ShotAccuracy=.63,Tackle=.55,Aggression=.55}),
	["Regional Pro"] = entry({DecisionMin=.28,DecisionMax=.5,Mistake=.14,Discipline=.62,PassRisk=.48,ShotSelect=.58,Press=.56,Stamina=.84},{Reaction=.32,Positioning=.72,PassAccuracy=.78,ShotAccuracy=.68,Tackle=.62,Aggression=.62}),
	["Premier Standard"] = entry({DecisionMin=.26,DecisionMax=.46,Mistake=.12,Discipline=.68,PassRisk=.54,ShotSelect=.64,Press=.62,Stamina=.87},{Reaction=.29,Positioning=.79,PassAccuracy=.83,ShotAccuracy=.74,Tackle=.68,Aggression=.68}),
	["National Class"] = entry({DecisionMin=.23,DecisionMax=.42,Mistake=.1,Discipline=.74,PassRisk=.6,ShotSelect=.7,Press=.68,Stamina=.9},{Reaction=.26,Positioning=.83,PassAccuracy=.86,ShotAccuracy=.78,Tackle=.73,Aggression=.73}),
	["Continental Elite"] = entry({DecisionMin=.2,DecisionMax=.38,Mistake=.07,Discipline=.82,PassRisk=.7,ShotSelect=.78,Press=.76,Stamina=.95},{Reaction=.22,Positioning=.9,PassAccuracy=.9,ShotAccuracy=.84,Tackle=.8,Aggression=.82}),
	["World Class"] = entry({DecisionMin=.19,DecisionMax=.34,Mistake=.055,Discipline=.86,PassRisk=.8,ShotSelect=.84,Press=.82,Stamina=.98},{Reaction=.2,Positioning=.92,PassAccuracy=.91,ShotAccuracy=.86,Tackle=.82,Aggression=.84}),
	["Voltra Masters"] = entry({DecisionMin=.18,DecisionMax=.3,Mistake=.045,Discipline=.91,PassRisk=.87,ShotSelect=.9,Press=.88,Stamina=1},{Reaction=.19,Positioning=.96,PassAccuracy=.94,ShotAccuracy=.9,Tackle=.86,Aggression=.88}),
	["Ultimate"] = entry({DecisionMin=.18,DecisionMax=.28,Mistake=.035,Discipline=.94,PassRisk=.91,ShotSelect=.93,Press=.91,Stamina=1},{Reaction=.18,Positioning=.98,PassAccuracy=.95,ShotAccuracy=.92,Tackle=.89,Aggression=.91}),
})

local aliases = table.freeze({
	Beginner = "Kickabout",
	Amateur = "Street Level",
	["Semi Pro"] = "Local League",
	Professional = "Regional Pro",
	Legendary = "Voltra Masters",
	Ultimate = "Ultimate",
})

local function resolveName(name: string?): string
	local requested = tostring(name or "")
	local canonical = aliases[requested] or requested
	return definitions[canonical] and canonical or "Regional Pro"
end

return table.freeze({
	Definitions = definitions,
	Aliases = aliases,
	MenuNames = table.freeze({"Beginner","Amateur","Semi Pro","Professional","World Class","Legendary","Ultimate"}),
	RuntimeNames = table.freeze({"Kickabout","Street Level","Sunday League","Local League","City Division","Regional Pro","Premier Standard","National Class","Continental Elite","World Class","Voltra Masters","Ultimate"}),
	Default = "Regional Pro",
	ResolveName = resolveName,
	FirstMatch = table.freeze({PassiveGuidedPossessions=2,StandingTackleLockedUntilPrompt=true,MaximumOneTouchTempo=.65,CleanShotKeeperScale=.68,RestoreSeconds=90}),
})
