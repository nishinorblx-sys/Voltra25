--!strict

local Config = {}

Config.CoachMessages = table.freeze({
	"Hold the assigned channel and let the ball arrive to you.",
	"Your recovery runs are helping the shape. Keep the spacing honest.",
	"Scan earlier before receiving. The next pass is there before the first touch.",
	"Protect possession for the next phase. We do not need the forced ball.",
	"When the fullback goes, cover the inside lane first.",
	"Attack the back post if the winger isolates wide.",
	"Press on the backwards pass, then screen the return lane.",
	"Stay connected to midfield during long defensive spells.",
	"Use the safe outlet when pressure arrives from your blind side.",
	"Slow the tempo until the team resets around you.",
})

Config.AgentMessages = table.freeze({
	"Clubs are tracking minutes, role fit and trend line more than one highlight.",
	"Your next contract case is stronger if the training week stays consistent.",
	"There is interest, but your camp should not force a move before the window.",
	"A loan could help if selection stalls for football reasons.",
	"The manager meeting is worth using when the role expectation is unclear.",
})

Config.SocialTemplates = table.freeze({
	"Supporters noticed the work rate today.",
	"Good academy minutes are starting to matter.",
	"The staff keep mentioning tactical fit.",
	"Training reports have been quietly positive.",
	"The next few fixtures could change the role conversation.",
})

Config.Events = table.freeze({
	{Id="senior_debut_1",Arc="senior_debut",Category="Milestone",Priority=80,Choices={{Id="team_first",Tone="Team First"},{Id="calm",Tone="Calm"},{Id="ambitious",Tone="Ambitious"}}},
	{Id="fight_for_place_1",Arc="fight_for_place",Category="Selection",Priority=70,Choices={{Id="ask_plan",Tone="Honest"},{Id="prove_it",Tone="Defiant"}}},
	{Id="mentor_relationship_1",Arc="mentor_relationship",Category="Relationship",Priority=55,Choices={{Id="learn",Tone="Calm"},{Id="lead",Tone="Ambitious"}}},
	{Id="transfer_saga_1",Arc="transfer_saga",Category="Agent",Priority=60,Choices={{Id="stay_open",Tone="Calm"},{Id="push_move",Tone="Ambitious"}}},
	{Id="injury_comeback_1",Arc="injury_comeback",Category="Condition",Priority=75,Choices={{Id="rehab",Tone="Team First"},{Id="rush",Tone="Defiant"}}},
})

return table.freeze(Config)
