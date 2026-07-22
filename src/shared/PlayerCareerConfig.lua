--!strict

local Config = {}

Config.Enabled = true
Config.SchemaVersion = 1
Config.MaxLedgerEntries = 160
Config.Positions = table.freeze({"GK","RB","RWB","CB","LB","LWB","CDM","CM","CAM","RM","LM","RW","LW","CF","ST"})
Config.Nationalities = table.freeze({"Voltra","England","France","Spain","Germany","Italy","Portugal","Netherlands","Brazil","Argentina","United States","Canada","Japan","Korea","Nigeria","Ghana","Morocco","Senegal"})
Config.Feet = table.freeze({"Right","Left"})
Config.Builds = table.freeze({"Lean","Balanced","Powerful","Compact","Tall"})
Config.PersonalityTones = table.freeze({"Team First","Calm","Ambitious","Honest","Defiant"})
Config.CameraPresets = table.freeze({"Pro","Pro Wide","Tactical Player Lock","Accessibility Follow","Goalkeeper Pro"})
Config.SquadRoles = table.freeze({"Trialist","Academy Prospect","Development Player","Rotation Option","First-Team Player","Important Player","Key Player","Team Leader","Captain"})
Config.DevelopmentChannels = table.freeze({"Pace","Power","Endurance","Agility","Ball Control","Dribbling","Short Passing","Long Passing","Vision","Finishing","Shot Technique","Aerial","Defensive Awareness","Tackling","Goalkeeping","Composure","Positioning","Leadership"})
Config.AttributeKeys = table.freeze({"Pace","Acceleration","Strength","Stamina","Agility","Balance","BallControl","Dribbling","ShortPassing","LongPassing","Vision","Finishing","ShotPower","Aerial","DefensiveAwareness","Tackling","Goalkeeping","Composure","Positioning","Leadership"})

Config.OverallWeights = table.freeze({
	GK = {Goalkeeping=.42,Positioning=.13,Composure=.12,LongPassing=.08,Vision=.06,Aerial=.08,Strength=.05,Agility=.06},
	CB = {DefensiveAwareness=.22,Tackling=.18,Strength=.12,Aerial=.12,Positioning=.12,Composure=.08,ShortPassing=.07,Pace=.05,LongPassing=.04},
	LB = {Pace=.13,Stamina=.11,Tackling=.14,DefensiveAwareness=.15,ShortPassing=.09,Dribbling=.08,Aerial=.04,Positioning=.1,Agility=.08,Vision=.08},
	RB = {Pace=.13,Stamina=.11,Tackling=.14,DefensiveAwareness=.15,ShortPassing=.09,Dribbling=.08,Aerial=.04,Positioning=.1,Agility=.08,Vision=.08},
	LWB = {Pace=.14,Stamina=.13,Tackling=.11,DefensiveAwareness=.1,ShortPassing=.1,Dribbling=.1,LongPassing=.07,Positioning=.1,Agility=.08,Vision=.07},
	RWB = {Pace=.14,Stamina=.13,Tackling=.11,DefensiveAwareness=.1,ShortPassing=.1,Dribbling=.1,LongPassing=.07,Positioning=.1,Agility=.08,Vision=.07},
	CDM = {DefensiveAwareness=.16,Tackling=.14,ShortPassing=.13,LongPassing=.1,Vision=.1,Positioning=.14,Stamina=.08,Composure=.09,Strength=.06},
	CM = {ShortPassing=.16,Vision=.13,Positioning=.12,Stamina=.11,BallControl=.11,LongPassing=.1,Composure=.09,Tackling=.08,Dribbling=.06,Pace=.04},
	CAM = {Vision=.18,ShortPassing=.14,BallControl=.13,Dribbling=.12,Positioning=.1,Finishing=.09,Composure=.09,Agility=.08,LongPassing=.07},
	LM = {Pace=.14,Dribbling=.14,BallControl=.11,ShortPassing=.1,Vision=.09,Stamina=.1,Positioning=.09,Finishing=.07,Agility=.09,LongPassing=.07},
	RM = {Pace=.14,Dribbling=.14,BallControl=.11,ShortPassing=.1,Vision=.09,Stamina=.1,Positioning=.09,Finishing=.07,Agility=.09,LongPassing=.07},
	LW = {Pace=.15,Dribbling=.16,BallControl=.12,Finishing=.1,Positioning=.1,ShotPower=.07,ShortPassing=.09,Vision=.09,Agility=.12},
	RW = {Pace=.15,Dribbling=.16,BallControl=.12,Finishing=.1,Positioning=.1,ShotPower=.07,ShortPassing=.09,Vision=.09,Agility=.12},
	CF = {Finishing=.15,Positioning=.14,BallControl=.12,ShortPassing=.1,Vision=.1,Dribbling=.1,Composure=.1,ShotPower=.09,Pace=.06,Strength=.04},
	ST = {Finishing=.19,Positioning=.15,ShotPower=.11,Composure=.11,Pace=.09,Strength=.08,Aerial=.08,BallControl=.08,Dribbling=.06,ShortPassing=.05},
})

Config.Archetypes = table.freeze({
	{Id="reflex_guardian",Name="Reflex Guardian",Group="Goalkeepers",Eligible={"GK"},Branches={"Close-Range Specialist","Penalty Reader","Cross Defender"},Strengths={"Reflex saves","Shot handling","Composure"},Weaknesses={"Long distribution","High sweeping"},Perks={"Snap Set","Crowd Claim","Ice Hands"},Tags={"keeper","line","reaction"},MaxPerkSlots=3},
	{Id="sweeper_keeper",Name="Sweeper Keeper",Group="Goalkeepers",Eligible={"GK"},Branches={"Front-Foot Sweeper","Long Distributor","Cross Commander"},Strengths={"Sweeping","Distribution","Range"},Weaknesses={"Close reactions","Conservative shape"},Perks={"Early Step","Outlet Launch","High Command"},Tags={"keeper","sweep","buildout"},MaxPerkSlots=3},
	{Id="lockdown_centre_back",Name="Lockdown Centre-Back",Group="Defenders",Eligible={"CB"},Branches={"Duel Stopper","Line Marshal","Aerial Wall"},Strengths={"Tackling","Aerial duels","Defensive awareness"},Weaknesses={"Dribbling","Attacking output"},Perks={"Body Check","Line Hold","First Contact"},Tags={"defender","duel","line"},MaxPerkSlots=3},
	{Id="ball_playing_defender",Name="Ball-Playing Defender",Group="Defenders",Eligible={"CB","LB","RB"},Branches={"Press Breaker","Diagonal Passer","Carry Out"},Strengths={"Passing","Composure","Progression"},Weaknesses={"Recovery speed","Aerial dominance"},Perks={"Split Pass","Calm Touch","Step Carry"},Tags={"defender","buildout","passing"},MaxPerkSlots=3},
	{Id="relentless_fullback",Name="Relentless Fullback",Group="Defenders",Eligible={"LB","RB","LWB","RWB"},Branches={"Overlapping Runner","Inverted Support","Defensive Runner"},Strengths={"Stamina","Recovery runs","Wide support"},Weaknesses={"Central creativity","Finishing"},Perks={"Second Wind","Overlap Cue","Track Back"},Tags={"wide","runner","defender"},MaxPerkSlots=3},
	{Id="holding_anchor",Name="Holding Anchor",Group="Midfielders",Eligible={"CDM","CM"},Branches={"Screen Holder","Ball Winner","Simple Distributor"},Strengths={"Screening","Tackling","Positioning"},Weaknesses={"Final-third output","Sprint pace"},Perks={"Cover Shadow","Clean Bite","Safe Outlet"},Tags={"midfield","screen","discipline"},MaxPerkSlots=3},
	{Id="box_to_box_engine",Name="Box-to-Box Engine",Group="Midfielders",Eligible={"CM","CDM","CAM"},Branches={"Late Runner","Recovery Runner","Tempo Support"},Strengths={"Endurance","Transitions","Support play"},Weaknesses={"Elite creativity","Aerial duels"},Perks={"Late Arrive","Recover Burst","Two-Way Motor"},Tags={"midfield","runner","transition"},MaxPerkSlots=4},
	{Id="deep_controller",Name="Deep Controller",Group="Midfielders",Eligible={"CDM","CM"},Branches={"Press Resistant","Long Distributor","Tempo Dictator"},Strengths={"Vision","Long passing","Composure"},Weaknesses={"Sprints","Box finishing"},Perks={"Switchboard","Shoulder Scan","Tempo Lock"},Tags={"midfield","controller","passing"},MaxPerkSlots=4},
	{Id="advanced_creator",Name="Advanced Creator",Group="Midfielders",Eligible={"CAM","CM","RW","LW"},Branches={"Half-Space Creator","Final Passer","Free Roamer"},Strengths={"Vision","Chance creation","First touch"},Weaknesses={"Defensive duels","Aerial play"},Perks={"Final Thread","Soft Pocket","Reverse Pass"},Tags={"creator","attack","between_lines"},MaxPerkSlots=4},
	{Id="wide_dribbler",Name="Wide Dribbler",Group="Attackers",Eligible={"LW","RW","LM","RM"},Branches={"Touchline Isolator","Cutback Maker","Change-of-Pace"},Strengths={"Dribbling","Agility","Wide chance creation"},Weaknesses={"Aerial","Defensive discipline"},Perks={"Snap Touch","Wide Burst","Cutback Eye"},Tags={"wide","dribble","attack"},MaxPerkSlots=4},
	{Id="inside_forward",Name="Inside Forward",Group="Attackers",Eligible={"LW","RW","CF","ST"},Branches={"Far-Post Runner","Weak-Foot Finisher","Inside Channel"},Strengths={"Finishing","Runs","Shot technique"},Weaknesses={"Defensive cover","Hold-up play"},Perks={"Back-Post Step","Angle Finish","Blindside Run"},Tags={"attack","inside","finisher"},MaxPerkSlots=4},
	{Id="pressing_striker",Name="Pressing Striker",Group="Attackers",Eligible={"ST","CF"},Branches={"First Press","Link Runner","Chaos Finisher"},Strengths={"Pressing","Stamina","Team play"},Weaknesses={"Long shots","Aerial dominance"},Perks={"Press Trigger","Wall Pass","Loose-Ball Pounce"},Tags={"attack","press","striker"},MaxPerkSlots=4},
	{Id="complete_finisher",Name="Complete Finisher",Group="Attackers",Eligible={"ST","CF"},Branches={"Penalty-Box Hunter","Link Forward","Channel Runner"},Strengths={"Finishing","Positioning","Composure"},Weaknesses={"Defensive work","Deep creativity"},Perks={"Box Sense","One-Touch Set","Channel Strike"},Tags={"attack","finisher","box"},MaxPerkSlots=4},
})

Config.Origins = table.freeze({
	academy_graduate={Name="Academy Graduate",Age={17,20},Overall={58,64},Potential={78,90},ClubState="Academy",Trust=36,Role="Academy Prospect",Morale=62,Reputation=18,StoryArc="senior_debut"},
	released_prospect={Name="Released Prospect",Age={18,22},Overall={56,62},Potential={72,86},ClubState="Trial",Trust=24,Role="Trialist",Morale=48,Reputation=8,StoryArc="fight_for_place"},
	street_technician={Name="Street Technician",Age={17,21},Overall={57,65},Potential={76,89},ClubState="Shortlist",Trust=28,Role="Development Player",Morale=66,Reputation=22,StoryArc="tactical_mismatch"},
	late_bloomer={Name="Late Bloomer",Age={22,26},Overall={61,67},Potential={72,82},ClubState="FreeAgent",Trust=32,Role="Rotation Option",Morale=58,Reputation=14,StoryArc="breakthrough_season"},
	keepers_road={Name="Keeper's Road",Age={17,23},Overall={57,65},Potential={76,88},ClubState="Academy",Trust=30,Role="Development Player",Morale=60,Reputation=12,StoryArc="keeper_competition",Position="GK"},
	legacy_pressure={Name="Legacy Pressure",Age={17,20},Overall={62,68},Potential={82,92},ClubState="Prospect",Trust=30,Role="Development Player",Morale=55,Reputation=34,StoryArc="derby_pressure"},
	custom_journey={Name="Custom Journey",Age={17,28},Overall={56,70},Potential={72,90},ClubState="Custom",Trust=34,Role="Development Player",Morale=60,Reputation=16,StoryArc="custom_path"},
})

Config.TrainingDrills = table.freeze({
	adaptive_replay_lab={Name="Adaptive Replay Lab",Channels={"Composure","Positioning","Vision"},Family="Technical"},
	film_room={Name="Film Room",Channels={"Vision","Positioning","Leadership"},Family="Tactical"},
	scan_and_receive={Name="Scan and Receive",Channels={"Ball Control","Short Passing","Composure"},Family="Technical"},
	shadow_runs={Name="Shadow Runs",Channels={"Positioning","Pace","Endurance"},Family="Physical"},
	constraint_rondo={Name="Constraint Rondo",Channels={"Short Passing","Vision","Ball Control"},Family="Creative"},
	finishing_pressure={Name="Finishing Under Pressure",Channels={"Finishing","Shot Technique","Composure"},Family="Technical"},
	passing_lane_lab={Name="Passing-Lane Lab",Channels={"Short Passing","Long Passing","Vision"},Family="Creative"},
	pressing_triggers={Name="Pressing Triggers",Channels={"Endurance","Positioning","Tackling"},Family="Defensive"},
	defensive_shape={Name="Defensive Shape",Channels={"Defensive Awareness","Tackling","Positioning"},Family="Defensive"},
	set_piece_lab={Name="Set-Piece Lab",Channels={"Aerial","Shot Technique","Long Passing"},Family="Tactical"},
	goalkeeper_command={Name="Goalkeeper Command",Channels={"Goalkeeping","Aerial","Composure"},Family="Goalkeeping"},
	recovery_rehab={Name="Recovery and Rehabilitation",Channels={"Endurance","Agility","Composure"},Family="Recovery"},
	small_sided_intelligence={Name="Small-Sided Intelligence",Channels={"Vision","Dribbling","Short Passing"},Family="Leadership"},
})

Config.StoryArcs = table.freeze({"senior_debut","fight_for_place","breakthrough_season","form_slump","mentor_relationship","teammate_rivalry","loan_journey","transfer_saga","contract_dispute","tactical_mismatch","injury_comeback","captaincy_path","derby_pressure","cup_run","international_callup","major_final","manager_change","position_reinvention"})
Config.InterviewTones = Config.PersonalityTones

local function contains(list: any, value: string): boolean
	for _, item in list do if item == value then return true end end
	return false
end

local function cleanText(value: any, maxLength: number, fallback: string): string
	local text = tostring(value or fallback)
	text = string.gsub(text, "[%c]", "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	text = string.gsub(text, "%s%s+", " ")
	if text == "" then text = fallback end
	return string.sub(text, 1, maxLength)
end

local function clampInt(value: any, minValue: number, maxValue: number, fallback: number): number
	local number = tonumber(value)
	if number ~= number or number == math.huge or number == -math.huge then number = fallback end
	return math.clamp(math.floor(number or fallback), minValue, maxValue)
end

function Config.IsPosition(value: any): boolean
	return type(value) == "string" and contains(Config.Positions, value)
end

function Config.ResolveArchetype(id: any): any?
	local key = tostring(id or "")
	for _, archetype in Config.Archetypes do if archetype.Id == key then return archetype end end
	return nil
end

function Config.DefaultArchetypeForPosition(position: string): string
	if position == "GK" then return "reflex_guardian" end
	if position == "CB" then return "lockdown_centre_back" end
	if position == "LB" or position == "RB" or position == "LWB" or position == "RWB" then return "relentless_fullback" end
	if position == "CDM" then return "holding_anchor" end
	if position == "CM" then return "box_to_box_engine" end
	if position == "CAM" then return "advanced_creator" end
	if position == "LW" or position == "RW" or position == "LM" or position == "RM" then return "wide_dribbler" end
	return "complete_finisher"
end

function Config.ArchetypeEligible(archetypeId: string, position: string): boolean
	local archetype = Config.ResolveArchetype(archetypeId)
	return archetype ~= nil and contains(archetype.Eligible, position)
end

function Config.PositionOverall(position: string, attributes: any): number
	local weights = Config.OverallWeights[position] or Config.OverallWeights.ST
	local total = 0
	local weightTotal = 0
	for key, weight in weights do
		total += math.clamp(tonumber(attributes and attributes[key]) or 50, 1, 99) * weight
		weightTotal += weight
	end
	return math.clamp(math.floor(total / math.max(0.001, weightTotal) + 0.5), 1, 99)
end

function Config.AttributeCost(value: number, age: number): number
	local rating = math.clamp(value, 1, 99)
	local agePenalty = age >= 30 and 1.25 or age <= 21 and 0.88 or 1
	return math.floor((18 + rating * 0.9 + math.max(0, rating - 75) ^ 1.32) * agePenalty + 0.5)
end

function Config.AgeDevelopmentMultiplier(age: number, channel: string): number
	if age <= 20 then return 1.18 end
	if age <= 24 then return 1.08 end
	if age <= 29 then return 0.92 end
	if channel == "Composure" or channel == "Positioning" or channel == "Leadership" or channel == "Vision" then return 0.86 end
	return 0.55
end

function Config.BaseAttributes(position: string, overall: number, archetypeId: string, heightCm: number, weightKg: number): any
	local attributes = {}
	for _, key in Config.AttributeKeys do attributes[key] = overall end
	local weights = Config.OverallWeights[position] or Config.OverallWeights.ST
	for key, weight in weights do attributes[key] = math.clamp(overall + math.floor(weight * 28 + 0.5), 1, 99) end
	local tall = math.clamp((heightCm - 180) / 18, -1, 1)
	local heavy = math.clamp((weightKg - 75) / 18, -1, 1)
	attributes.Aerial = math.clamp(attributes.Aerial + tall * 5 + heavy * 2, 1, 99)
	attributes.Strength = math.clamp(attributes.Strength + heavy * 5 + tall * 2, 1, 99)
	attributes.Agility = math.clamp(attributes.Agility - tall * 3 - heavy * 2, 1, 99)
	attributes.Acceleration = math.clamp(attributes.Acceleration - tall * 2 - heavy * 2, 1, 99)
	local archetype = Config.ResolveArchetype(archetypeId)
	if archetype then
		for _, strength in archetype.Strengths do
			local key = string.gsub(strength, "%s", "")
			if attributes[key] then attributes[key] = math.clamp(attributes[key] + 2, 1, 99) end
		end
	end
	return attributes
end

function Config.NormalizeCreation(payload: any): (boolean, any, string?)
	if type(payload) ~= "table" then return false, nil, "Invalid career creation." end
	local position = tostring(payload.PrimaryPosition or payload.Position or "ST")
	if not Config.IsPosition(position) then return false, nil, "Choose a supported position." end
	local originId = tostring(payload.OriginId or "academy_graduate")
	local origin = Config.Origins[originId]
	if not origin then return false, nil, "Choose a supported origin." end
	if origin.Position and origin.Position ~= position then return false, nil, "That origin is only available for goalkeepers." end
	local archetypeId = tostring(payload.ArchetypeId or Config.DefaultArchetypeForPosition(position))
	if not Config.ArchetypeEligible(archetypeId, position) then archetypeId = Config.DefaultArchetypeForPosition(position) end
	local archetype = Config.ResolveArchetype(archetypeId)
	local ageMin, ageMax = origin.Age[1], origin.Age[2]
	local age = clampInt(payload.Age or payload.StartingAge, ageMin, ageMax, ageMin)
	local currentYear = tonumber(os.date("!*t").year) or 2026
	local height = clampInt(payload.HeightCm, 160, 205, position == "GK" and 190 or 180)
	local weight = clampInt(payload.WeightKg, 55, 105, position == "GK" and 84 or 75)
	local foot = tostring(payload.PreferredFoot or "Right")
	if not contains(Config.Feet, foot) then foot = "Right" end
	local secondaryFoot = clampInt(payload.SecondaryFoot, 1, 5, foot == "Right" and 3 or 2)
	local first = cleanText(payload.FirstName, 18, "Rin")
	local last = cleanText(payload.LastName, 18, "Vale")
	local short = cleanText(payload.ShortName or payload.DisplayName, 20, first.." "..last)
	local shirtName = string.upper(cleanText(payload.ShirtName, 14, last))
	local nationality = cleanText(payload.Nationality, 24, "Voltra")
	if not contains(Config.Nationalities, nationality) then nationality = "Voltra" end
	local build = tostring(payload.BodyBuild or "Balanced")
	if not contains(Config.Builds, build) then build = "Balanced" end
	local tone = tostring(payload.PersonalityTone or "Team First")
	if not contains(Config.PersonalityTones, tone) then tone = "Team First" end
	local camera = tostring(payload.CameraPreference or (position == "GK" and "Goalkeeper Pro" or "Pro"))
	if not contains(Config.CameraPresets, camera) then camera = position == "GK" and "Goalkeeper Pro" or "Pro" end
	local overall = clampInt(payload.StartingOverall, origin.Overall[1], origin.Overall[2], math.floor((origin.Overall[1] + origin.Overall[2]) / 2))
	local now = os.time()
	return true, {
		Identity = {
			FirstName = first,
			LastName = last,
			DisplayName = short,
			Nationality = nationality,
			BirthYear = currentYear - age,
			StartingAge = age,
			ShirtName = shirtName,
			ShirtNumber = clampInt(payload.ShirtNumber, 1, 99, position == "GK" and 1 or 9),
			PreferredFoot = foot,
			SecondaryFoot = secondaryFoot,
			HeightCm = height,
			WeightKg = weight,
			BodyBuild = build,
			Appearance = type(payload.Appearance) == "table" and payload.Appearance or {},
			Celebration = cleanText(payload.Celebration, 32, "Voltra Point"),
			PersonalityTone = tone,
			CameraPreference = camera,
			PrimaryPosition = position,
			SecondaryPositions = {},
		},
		Origin = {OriginId = originId, StoryArc = origin.StoryArc, Flags = {[origin.StoryArc] = true}, CompletedStages = {}},
		Archetype = {ArchetypeId = archetypeId, SpecializationId = archetype and archetype.Branches[1] or "", UnlockedPerks = {}, EquippedPerks = {}, Progress = 0},
		StartingOverall = overall,
		Potential = clampInt(payload.Potential, origin.Potential[1], origin.Potential[2], origin.Potential[1]),
		CreatedAt = now,
		UpdatedAt = now,
	}, nil
end

function Config.DefaultManagerSlot(slotNumber: number?): any
	local now = os.time()
	return {Slot = slotNumber or 1, Type = "Manager", SchemaVersion = 1, Name = "MORGAN VALE", Season = "2026/27", Club = "NO CLUB", Rating = 50, Stats = {Played = 0, Wins = 0, Draws = 0, Losses = 0}, CreatedAt = now, UpdatedAt = now}
end

function Config.BuildPlayerCareer(slotNumber: number, creation: any): any
	local origin = Config.Origins[creation.Origin.OriginId]
	local attributes = Config.BaseAttributes(creation.Identity.PrimaryPosition, creation.StartingOverall, creation.Archetype.ArchetypeId, creation.Identity.HeightCm, creation.Identity.WeightKg)
	local overall = Config.PositionOverall(creation.Identity.PrimaryPosition, attributes)
	local now = os.time()
	return {
		Slot = slotNumber,
		Type = "Player",
		SchemaVersion = Config.SchemaVersion,
		CareerId = "pc_"..tostring(slotNumber).."_"..tostring(now).."_"..tostring(math.floor((os.clock() % 1) * 100000)),
		Revision = 1,
		CreatedAt = creation.CreatedAt or now,
		UpdatedAt = now,
		Status = "Active",
		Name = creation.Identity.DisplayName,
		Season = "2026/27",
		Overall = overall,
		Club = origin.ClubState == "FreeAgent" and "FREE AGENT" or "VOLTRA ACADEMY",
		Identity = creation.Identity,
		Origin = creation.Origin,
		Archetype = creation.Archetype,
		Development = {Attributes = attributes, DisplayedOverall = overall, PositionOveralls = {[creation.Identity.PrimaryPosition] = overall}, Potential = creation.Potential, XP = {}, WeeklyCaps = {}, Conversion = {}, History = {}},
		Condition = {Fitness = 92, Fatigue = 8, Workload = 12, Sharpness = 58, Form = 50, Morale = origin.Morale, InjuryRisk = 8, Injury = nil, Suspension = nil},
		ClubState = {ClubId = "voltra_academy", ManagerId = "mgr_foundation", SquadRole = origin.Role, ManagerTrust = origin.Trust, TacticalFit = 58, ShirtNumber = creation.Identity.ShirtNumber, Captaincy = 0, Hierarchy = {}},
		Contract = {ClubId = "voltra_academy", StartDate = "2026-07-01", EndDate = "2028-06-30", SquadRole = origin.Role, WageBand = "Prospect", Objectives = {}, PromiseState = {}, Negotiation = {State = "None"}},
		Calendar = {CurrentDate = "2026-07-01", SeasonId = "2026", Fixtures = {}, CompletedFixtureIds = {}, Standings = {}, CupState = {}, NextActivity = "training_week_1"},
		Training = {WeeklyPlan = {}, CompletedSessionIds = {}, DrillMastery = {}, ActiveSession = nil},
		Relationships = {Manager = origin.Trust, Coach = 50, Captain = 48, Mentor = 40, RivalTeammate = 35, CloseTeammate = 45, Agent = 50, Supporters = origin.Reputation, Media = origin.Reputation},
		Story = {ActiveArcs = {[origin.StoryArc] = {Stage = 1, StartedAt = now}}, CompletedNodes = {}, Cooldowns = {}, Flags = creation.Origin.Flags, Inbox = {}, SocialFeed = {}, PendingInterview = nil},
		Agent = {Preferences = {PlayingTimePriority = 60, DevelopmentPriority = 70, TacticalStyle = "Flexible", LoanPreference = "Open"}, Interest = {}, Requests = {}, Offers = {}, Negotiations = {}},
		Statistics = {CurrentSeason = {Appearances = 0, Starts = 0, Minutes = 0, Goals = 0, Assists = 0, AverageRating = 6}, Career = {Appearances = 0, Starts = 0, Minutes = 0, Goals = 0, Assists = 0, AverageRating = 6}, RecentMatches = {}, Records = {}, Awards = {}},
		MatchState = {PendingFixture = nil, PendingMatchToken = nil, LaunchState = "None", ReturnState = nil, LastConsumedResult = nil, PlayerLockState = "Spectating"},
		Ledgers = {ProcessedOperationIds = {}, ProcessedTrainingSessions = {}, ProcessedMatchResultIds = {}, ProcessedStoryChoiceIds = {}, GrantedRewardIds = {}},
		Settings = {MatchExperience = "Full Match", SimulationPreference = "Balanced", Camera = creation.Identity.CameraPreference, CoachHUD = true, Difficulty = "Professional", Realism = {StrictPlayerLock = true}},
		Stats = {Appearances = 0, Goals = 0, Assists = 0},
	}
end

function Config.ClientSummary(slot: any): any
	if type(slot) ~= "table" then return {Type = "Empty"} end
	if slot.Type ~= "Player" then return table.clone(slot) end
	return {
		Slot = slot.Slot,
		Type = "Player",
		SchemaVersion = slot.SchemaVersion,
		CareerId = slot.CareerId,
		Revision = slot.Revision,
		Name = slot.Name,
		Season = slot.Season,
		Overall = slot.Overall,
		Club = slot.Club,
		Position = slot.Identity and slot.Identity.PrimaryPosition or "ST",
		Age = slot.Identity and ((tonumber(os.date("!*t").year) or 2026) - (tonumber(slot.Identity.BirthYear) or 2008)) or 18,
		Archetype = slot.Archetype and slot.Archetype.ArchetypeId or "",
		Origin = slot.Origin and slot.Origin.OriginId or "",
		Condition = table.clone(slot.Condition or {}),
		ClubState = table.clone(slot.ClubState or {}),
		Contract = table.clone(slot.Contract or {}),
		Calendar = {CurrentDate = slot.Calendar and slot.Calendar.CurrentDate or "2026-07-01", NextActivity = slot.Calendar and slot.Calendar.NextActivity or ""},
		Training = table.clone(slot.Training or {}),
		Story = {ActiveArcs = table.clone(slot.Story and slot.Story.ActiveArcs or {}), Inbox = table.clone(slot.Story and slot.Story.Inbox or {}), SocialFeed = table.clone(slot.Story and slot.Story.SocialFeed or {})},
		Agent = table.clone(slot.Agent or {}),
		Statistics = table.clone(slot.Statistics or {}),
		Settings = table.clone(slot.Settings or {}),
		UpdatedAt = slot.UpdatedAt,
	}
end

function Config.NormalizeSlot(slot: any, slotNumber: number): any
	if type(slot) ~= "table" then return {Slot = slotNumber, Type = "Empty"} end
	if slot.Type == "Empty" then return {Slot = slotNumber, Type = "Empty"} end
	if slot.Type == "Manager" then
		slot.Slot = slotNumber
		slot.Type = "Manager"
		slot.Name = cleanText(slot.Name, 32, "MORGAN VALE")
		slot.Season = cleanText(slot.Season, 16, "2026/27")
		slot.Club = cleanText(slot.Club, 32, "NO CLUB")
		slot.Rating = clampInt(slot.Rating, 1, 99, 50)
		slot.Stats = type(slot.Stats) == "table" and slot.Stats or {Played = 0, Wins = 0, Draws = 0, Losses = 0}
		return slot
	end
	local identity = type(slot.Identity) == "table" and slot.Identity or {}
	local payload = {
		FirstName = identity.FirstName or string.match(tostring(slot.Name or ""), "^(%S+)") or "Rin",
		LastName = identity.LastName or string.match(tostring(slot.Name or ""), "%s(.+)$") or "Vale",
		DisplayName = slot.Name or identity.DisplayName,
		Nationality = identity.Nationality,
		Age = identity.StartingAge or 18,
		PrimaryPosition = identity.PrimaryPosition or slot.Position or "ST",
		OriginId = slot.Origin and slot.Origin.OriginId or "academy_graduate",
		ArchetypeId = slot.Archetype and slot.Archetype.ArchetypeId or nil,
		HeightCm = identity.HeightCm,
		WeightKg = identity.WeightKg,
		PreferredFoot = identity.PreferredFoot,
		ShirtName = identity.ShirtName,
		ShirtNumber = identity.ShirtNumber,
	}
	local ok, creation = Config.NormalizeCreation(payload)
	local normalized = ok and Config.BuildPlayerCareer(slotNumber, creation) or {Slot = slotNumber, Type = "Empty", Quarantined = true}
	if normalized.Type == "Player" then
		normalized.CareerId = tostring(slot.CareerId or normalized.CareerId)
		normalized.Revision = clampInt(slot.Revision, 1, 100000000, 1)
		normalized.CreatedAt = tonumber(slot.CreatedAt) or normalized.CreatedAt
		normalized.UpdatedAt = tonumber(slot.UpdatedAt) or normalized.UpdatedAt
		normalized.Season = cleanText(slot.Season, 16, normalized.Season)
		normalized.Club = cleanText(slot.Club, 32, normalized.Club)
		if type(slot.Development) == "table" and type(slot.Development.Attributes) == "table" then normalized.Development.Attributes = slot.Development.Attributes end
		normalized.Overall = Config.PositionOverall(normalized.Identity.PrimaryPosition, normalized.Development.Attributes)
		normalized.Development.DisplayedOverall = normalized.Overall
		for _, key in {"Condition","ClubState","Contract","Calendar","Training","Relationships","Story","Agent","Statistics","MatchState","Ledgers","Settings","Stats"} do
			if type(slot[key]) == "table" then normalized[key] = slot[key] end
		end
		normalized.SchemaVersion = Config.SchemaVersion
	end
	return normalized
end

function Config.NormalizeSlots(slots: any): any
	local result = {}
	for index = 1, 3 do result[index] = Config.NormalizeSlot(type(slots) == "table" and slots[index] or nil, index) end
	return result
end

return table.freeze(Config)
