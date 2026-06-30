--!strict

-- Add or replace lines here. Roblox cannot generate arbitrary TTS audio at
-- runtime, so put the spoken text here and paste the uploaded audio asset id in
-- SoundId when you have the voice clip.
local Config = {}

Config.Actions = table.freeze({
	MatchStart = {
		Cooldown = 18,
		Lines = {
			{Text = "And we are underway.", SoundId = ""},
			{Text = "The match begins, and both teams settle into shape.", SoundId = ""},
		},
	},
	Goal = {
		Cooldown = 6,
		Lines = {
			{Text = "Goal! A huge finish.", SoundId = ""},
			{Text = "That one is in, and the stadium erupts.", SoundId = ""},
		},
	},
	Shot = {
		Cooldown = 7,
		Lines = {
			{Text = "He takes the shot.", SoundId = ""},
			{Text = "The chance opens up, and he lets it fly.", SoundId = ""},
		},
	},
	ShotSaved = {
		Cooldown = 8,
		Lines = {
			{Text = "The keeper makes the save.", SoundId = ""},
			{Text = "Denied by the goalkeeper.", SoundId = ""},
		},
	},
	ShotBlocked = {
		Cooldown = 8,
		Lines = {
			{Text = "The defender gets in the way.", SoundId = ""},
			{Text = "Blocked before it can trouble the keeper.", SoundId = ""},
		},
	},
	Tackle = {
		Cooldown = 7,
		Lines = {
			{Text = "Strong challenge there.", SoundId = ""},
			{Text = "He steps in and wins the duel.", SoundId = ""},
		},
	},
	PossessionWon = {
		Cooldown = 8,
		Lines = {
			{Text = "Possession changes hands.", SoundId = ""},
			{Text = "They win it back and look to build.", SoundId = ""},
		},
	},
	Corner = {
		Cooldown = 10,
		Lines = {
			{Text = "Corner kick, a chance to load the box.", SoundId = ""},
			{Text = "They will send bodies forward for this corner.", SoundId = ""},
		},
	},
	FreeKick = {
		Cooldown = 10,
		Lines = {
			{Text = "Free kick in a useful position.", SoundId = ""},
			{Text = "The referee gives the foul, and they can deliver now.", SoundId = ""},
		},
	},
	Penalty = {
		Cooldown = 10,
		Lines = {
			{Text = "Penalty awarded.", SoundId = ""},
			{Text = "A massive moment from the spot.", SoundId = ""},
		},
	},
	HalfTime = {
		Cooldown = 20,
		Lines = {
			{Text = "That is half time.", SoundId = ""},
			{Text = "The whistle goes, and the teams head in.", SoundId = ""},
		},
	},
	MatchEnded = {
		Cooldown = 20,
		Lines = {
			{Text = "Full time, and the match is complete.", SoundId = ""},
			{Text = "The final whistle confirms the result.", SoundId = ""},
		},
	},
})

return table.freeze(Config)
