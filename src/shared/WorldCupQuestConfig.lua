--!strict

local Config = {}

local function quest(id: string, category: string, title: string, description: string, target: number, difficulty: number, metric: string, data: any?): any
	local rewardDifficulty = difficulty
	if type(data) == "table" and tonumber(data.RewardDifficulty) then
		rewardDifficulty = tonumber(data.RewardDifficulty) or difficulty
	elseif difficulty >= 5 and target >= 3 then
		rewardDifficulty = 6
	end
	-- Broad nation/continent title quests overlap with the main championship reward.
	-- Keep those meaningful without turning one tournament win into several Elite packs.
	if target == 1 and (metric == "titleWithNation" or metric == "continentTitle" or metric == "formerChampionTitle") then
		rewardDifficulty = math.min(rewardDifficulty, 4)
	end
	local packId = "bronze_pack"
	if rewardDifficulty >= 6 then
		packId = "champion_pack"
	elseif rewardDifficulty >= 5 then
		packId = "elite_pack"
	elseif rewardDifficulty >= 4 then
		packId = "rare_pack"
	elseif rewardDifficulty >= 3 then
		packId = "gold_pack"
	elseif rewardDifficulty >= 2 then
		packId = "silver_pack"
	end
	local definition = {
		Id = id,
		Category = category,
		Title = title,
		Description = description,
		Target = target,
		Difficulty = difficulty,
		Metric = metric,
		PackId = packId,
	}
	if type(data)=="table"then
		for key,value in data do definition[key]=value end
	end
	return table.freeze(definition)
end

Config.Quests = table.freeze({
	quest("welcome_knockouts", "Tournament Progress", "Welcome to the Knockouts", "Reach the Round of 32.", 1, 1, "bestStage"),
	quest("sweet_sixteen", "Tournament Progress", "Sweet Sixteen", "Reach the Round of 16.", 1, 2, "bestStage"),
	quest("quarterfinal_quality", "Tournament Progress", "Quarterfinal Quality", "Reach the quarterfinals.", 1, 2, "bestStage"),
	quest("final_four", "Tournament Progress", "Final Four", "Reach the semifinals.", 1, 3, "bestStage"),
	quest("one_match_away", "Tournament Progress", "One Match Away", "Reach the World Cup final.", 1, 4, "bestStage"),
	quest("world_champions", "Tournament Progress", "World Champions", "Win the World Cup.", 1, 5, "titles"),
	quest("perfect_champions", "Tournament Progress", "Perfect Champions", "Win every match in the tournament.", 1, 5, "perfectTitle"),
	quest("unbeaten_run", "Tournament Progress", "Unbeaten Run", "Win the tournament without losing a match.", 1, 5, "unbeatenTitle"),
	quest("no_extra_help", "Tournament Progress", "No Extra Help Needed", "Win the tournament without extra time or penalties.", 1, 5, "regulationTitle"),
	quest("hard_way", "Tournament Progress", "The Hard Way", "Win the tournament after playing extra time at least twice.", 2, 5, "extraTimeWinsRun"),
	quest("penalty_specialists", "Tournament Progress", "Penalty Specialists", "Win three penalty shootouts in one tournament.", 3, 5, "shootoutWinsRun"),
	quest("against_all_odds", "Tournament Progress", "Against All Odds", "Win the World Cup with one of the lowest-rated nations.", 1, 5, "underdogTitle"),
	quest("from_r32_glory", "Tournament Progress", "From R32 to Glory", "Win every knockout match from the Round of 32 onward.", 1, 5, "knockoutSweepTitle"),
	quest("third_place_pride", "Tournament Progress", "Third Place Pride", "Win the third-place playoff.", 1, 3, "unsupported"),
	quest("back_to_back_champions", "Tournament Progress", "Back-to-Back Champions", "Win consecutive World Cups with the same nation.", 2, 5, "sameNationTitles"),

	quest("first_taste_glory", "Nation Legacy", "First Taste of Glory", "Win a nation's first-ever World Cup.", 1, 5, "firstTitle"),
	quest("historic_final", "Nation Legacy", "Historic Final", "Reach a first-ever World Cup final with a nation.", 1, 4, "firstFinal"),
	quest("historic_semifinal", "Nation Legacy", "Historic Semifinal", "Reach a first-ever semifinal with a nation.", 1, 3, "firstSemi"),
	quest("best_finish_ever", "Nation Legacy", "Best Finish Ever", "Beat a nation's previous best tournament result.", 1, 4, "bestFinish"),
	quest("end_wait", "Nation Legacy", "End the Wait", "Win the World Cup with a former champion after a long title drought.", 1, 5, "formerChampionTitle"),
	quest("restore_giant", "Nation Legacy", "Restore the Giant", "Win the tournament with a nation that has previously underperformed.", 1, 5, "formerChampionTitle"),
	quest("new_power", "Nation Legacy", "New Football Power", "Reach the semifinals with a nation that has never won the tournament.", 1, 4, "nonChampionSemi"),
	quest("continental_breakthrough", "Nation Legacy", "Continental Breakthrough", "Win the World Cup with a nation from a continent that rarely wins.", 1, 5, "rareContinentTitle"),
	quest("small_nation_big_dream", "Nation Legacy", "Small Nation, Big Dream", "Reach the quarterfinals with a low-ranked nation.", 1, 4, "lowRankQuarter"),
	quest("golden_generation", "Nation Legacy", "Golden Generation", "Win the tournament with a squad built mostly around players aged 23 or younger.", 1, 5, "unsupported"),
	quest("last_dance", "Nation Legacy", "Last Dance", "Win the World Cup with a squad led by several players aged 32 or older.", 1, 5, "unsupported"),
	quest("home_champions", "Nation Legacy", "Home of Champions", "Win using only players from the nation's domestic league.", 1, 5, "unsupported"),
	quest("one_club_core", "Nation Legacy", "One-Club Core", "Win the tournament with at least five starters from the same club.", 1, 5, "unsupported"),
	quest("national_identity", "Nation Legacy", "National Identity", "Win while using the nation's traditional formation in every match.", 1, 4, "unsupported"),
	quest("new_dynasty", "Nation Legacy", "The New Dynasty", "Win three World Cups with the same nation across multiple tournaments.", 3, 5, "sameNationTitles"),

	quest("england_coming_home", "Europe", "It's Coming Home", "Win the World Cup with England.", 1, 5, "titleWithNation", {Nations={"England"}}),
	quest("germany_mannschaft_returns", "Europe", "Die Mannschaft Returns", "Win with Germany.", 1, 5, "titleWithNation", {Nations={"Germany"}}),
	quest("italy_azzurri_glory", "Europe", "Azzurri Glory", "Win with Italy.", 1, 5, "titleWithNation", {Nations={"Italy"}}),
	quest("france_les_bleus_forever", "Europe", "Les Bleus Forever", "Win with France.", 1, 5, "titleWithNation", {Nations={"France"}}),
	quest("spain_la_roja_reborn", "Europe", "La Roja Reborn", "Win with Spain.", 1, 5, "titleWithNation", {Nations={"Spain"}}),
	quest("netherlands_orange_dream", "Europe", "The Orange Dream", "Win the World Cup with the Netherlands.", 1, 5, "titleWithNation", {Nations={"Netherlands"}}),
	quest("belgium_golden_generation_fulfilled", "Europe", "Golden Generation Fulfilled", "Win with Belgium.", 1, 5, "titleWithNation", {Nations={"Belgium"}}),
	quest("viking_conquest", "Europe", "The Viking Conquest", "Reach the semifinals with Norway, Sweden, or Denmark.", 1, 4, "stageWithNation", {Nations={"Norway","Sweden","Denmark"},StageValue=3}),
	quest("eastern_revolution", "Europe", "Eastern Revolution", "Reach the semifinals with Poland, Czechia, Hungary, Romania, or Serbia.", 1, 4, "stageWithNation", {Nations={"Poland","Czechia","Hungary","Romania","Serbia"},StageValue=3}),
	quest("balkan_champions", "Europe", "Balkan Champions", "Win with Croatia or Serbia.", 1, 5, "titleWithNation", {Nations={"Croatia","Serbia"}}),

	quest("brazil_joga_bonito", "South America", "Joga Bonito", "Win with Brazil.", 1, 5, "titleWithNation", {Nations={"Brazil"}}),
	quest("argentina_albiceleste_legacy", "South America", "La Albiceleste Legacy", "Win with Argentina.", 1, 5, "titleWithNation", {Nations={"Argentina"}}),
	quest("uruguay_celeste_forever", "South America", "Celeste Forever", "Win with Uruguay.", 1, 5, "titleWithNation", {Nations={"Uruguay"}}),
	quest("andean_miracle", "South America", "Andean Miracle", "Reach the semifinals with Colombia, Ecuador, Peru, Bolivia, or Venezuela.", 1, 4, "stageWithNation", {Nations={"Colombia","Ecuador","Peru","Bolivia","Venezuela"},StageValue=3}),
	quest("colombia_coffee_kings", "South America", "Coffee Kings", "Win with Colombia.", 1, 5, "titleWithNation", {Nations={"Colombia"}}),
	quest("peru_inca_empire", "South America", "The Inca Empire", "Reach the final with Peru.", 1, 4, "stageWithNation", {Nations={"Peru"},StageValue=4}),
	quest("south_america_first_ever", "South America", "First Ever", "Win with Chile, Colombia, Peru, Ecuador, Paraguay, Bolivia, or Venezuela.", 1, 5, "firstTitleWithNation", {Nations={"Chile","Colombia","Peru","Ecuador","Paraguay","Bolivia","Venezuela"}}),

	quest("usa_stars_and_stripes", "CONCACAF", "Stars and Stripes", "Win with the United States.", 1, 5, "titleWithNation", {Nations={"United States"}}),
	quest("mexico_el_tri_triumphs", "CONCACAF", "El Tri Triumphs", "Win with Mexico.", 1, 5, "titleWithNation", {Nations={"Mexico"}}),
	quest("canada_maple_glory", "CONCACAF", "Maple Glory", "Reach the semifinals with Canada.", 1, 4, "stageWithNation", {Nations={"Canada"},StageValue=3}),
	quest("caribbean_dream", "CONCACAF", "Caribbean Dream", "Reach the quarterfinals with Jamaica, Haiti, Trinidad & Tobago, or Curacao.", 1, 4, "stageWithNation", {Nations={"Jamaica","Haiti","Trinidad & Tobago","Curacao"},StageValue=2}),
	quest("concacaf_crown", "CONCACAF", "CONCACAF Crown", "Reach the final with any CONCACAF nation.", 1, 4, "stageWithContinent", {Continent="CONCACAF",StageValue=4}),
	quest("concacaf_break_barrier", "CONCACAF", "Break the Barrier", "Win the World Cup with a CONCACAF nation.", 1, 5, "titleWithContinent", {Continent="CONCACAF"}),

	quest("senegal_lions_roar", "Africa", "Lions Roar", "Win with Senegal.", 1, 5, "titleWithNation", {Nations={"Senegal"}}),
	quest("morocco_atlas_kings", "Africa", "Atlas Kings", "Win with Morocco.", 1, 5, "titleWithNation", {Nations={"Morocco"}}),
	quest("egypt_pharaohs_rise", "Africa", "Pharaohs Rise", "Win with Egypt.", 1, 5, "titleWithNation", {Nations={"Egypt"}}),
	quest("nigeria_super_eagles_soar", "Africa", "Super Eagles Soar", "Win with Nigeria.", 1, 5, "titleWithNation", {Nations={"Nigeria"}}),
	quest("south_africa_bafana_miracle", "Africa", "Bafana Miracle", "Reach the semifinals with South Africa.", 1, 4, "stageWithNation", {Nations={"South Africa"},StageValue=3}),
	quest("african_giants", "Africa", "African Giants", "Reach the final with any African nation.", 1, 4, "stageWithContinent", {Continent="Africa",StageValue=4}),
	quest("africa_history_made_champion", "Africa", "History Made", "Become the first African World Cup champion.", 1, 5, "titleWithContinent", {Continent="Africa"}),

	quest("japan_blue_samurai", "Asia", "Blue Samurai", "Win with Japan.", 1, 5, "titleWithNation", {Nations={"Japan"}}),
	quest("south_korea_taeguk_glory", "Asia", "Taeguk Glory", "Win with South Korea.", 1, 5, "titleWithNation", {Nations={"South Korea"}}),
	quest("iran_persian_pride", "Asia", "Persian Pride", "Reach the semifinals with Iran.", 1, 4, "stageWithNation", {Nations={"Iran"},StageValue=3}),
	quest("saudi_green_falcons_fly", "Asia", "Green Falcons Fly", "Reach the quarterfinals with Saudi Arabia.", 1, 4, "stageWithNation", {Nations={"Saudi Arabia"},StageValue=2}),
	quest("asian_powerhouse", "Asia", "Asian Powerhouse", "Reach the final with any AFC nation.", 1, 4, "stageWithContinent", {Continent="Asia",StageValue=4}),
	quest("asia_breaking_new_ground", "Asia", "Breaking New Ground", "Become the first Asian World Cup winner.", 1, 5, "titleWithContinent", {Continent="Asia"}),

	quest("new_zealand_kiwi_dream", "Oceania", "Kiwi Dream", "Reach the Round of 16 with New Zealand.", 1, 3, "stageWithNation", {Nations={"New Zealand"},StageValue=1}),
	quest("new_zealand_island_miracle", "Oceania", "Island Miracle", "Reach the quarterfinals with New Zealand.", 1, 5, "stageWithNation", {Nations={"New Zealand"},StageValue=2}),
	quest("oceania_forever", "Oceania", "Oceania Forever", "Win the World Cup with an OFC nation.", 1, 5, "titleWithContinent", {Continent="Oceania"}),

	quest("european_domination_uefa_five", "Continental Challenges", "European Domination", "Eliminate 5 UEFA teams in one tournament.", 5, 5, "defeatContinentCountRun", {Continent="Europe"}),
	quest("south_american_survivor", "Continental Challenges", "South American Survivor", "Eliminate Brazil and Argentina in the same tournament.", 1, 5, "defeatNationsRun", {Nations={"Brazil","Argentina"}}),
	quest("african_revolution", "Continental Challenges", "African Revolution", "Reach consecutive semifinals with African nations.", 2, 5, "continentSemiStreak", {Continent="Africa"}),
	quest("asian_rising", "Continental Challenges", "Asian Rising", "Reach the semifinals with three different Asian nations across your career.", 3, 5, "semiNationsByContinent", {Continent="Asia"}),
	quest("global_champion_all_continents", "Continental Challenges", "Global Champion", "Win the World Cup with a nation from every continent.", 6, 5, "titleContinents"),
	quest("continental_collector_all_federations", "Continental Challenges", "Continental Collector", "Win with one UEFA, one CONMEBOL, one CAF, one AFC, one CONCACAF, and one OFC nation.", 6, 5, "titleContinents"),

	quest("rivalry_battle_of_britain", "Rivalry Achievements", "Battle of Britain", "Beat Scotland or Wales as England.", 1, 3, "rivalryWin", {Rivalries={{User="England",Opponent="Scotland"},{User="England",Opponent="Wales"}}}),
	quest("rivalry_clasico_internacional", "Rivalry Achievements", "El Clasico Internacional", "Beat Argentina as Brazil or Brazil as Argentina.", 1, 4, "rivalryWin", {Rivalries={{User="Brazil",Opponent="Argentina"},{User="Argentina",Opponent="Brazil"}}}),
	quest("rivalry_north_american_kings", "Rivalry Achievements", "North American Kings", "Beat the USA as Mexico or Mexico as the USA.", 1, 3, "rivalryWin", {Rivalries={{User="Mexico",Opponent="United States"},{User="United States",Opponent="Mexico"}}}),
	quest("rivalry_north_sea_supremacy", "Rivalry Achievements", "North Sea Supremacy", "Beat Germany as the Netherlands or vice versa.", 1, 4, "rivalryWin", {Rivalries={{User="Netherlands",Opponent="Germany"},{User="Germany",Opponent="Netherlands"}}}),
	quest("rivalry_balkan_bragging_rights", "Rivalry Achievements", "Balkan Bragging Rights", "Beat Serbia as Croatia or Croatia as Serbia.", 1, 4, "rivalryWin", {Rivalries={{User="Croatia",Opponent="Serbia"},{User="Serbia",Opponent="Croatia"}}}),
	quest("rivalry_iberian_supremacy", "Rivalry Achievements", "Iberian Supremacy", "Beat Portugal as Spain or Spain as Portugal.", 1, 4, "rivalryWin", {Rivalries={{User="Spain",Opponent="Portugal"},{User="Portugal",Opponent="Spain"}}}),
	quest("rivalry_andean_derby", "Rivalry Achievements", "Andean Derby", "Beat Chile as Peru or Peru as Chile.", 1, 3, "rivalryWin", {Rivalries={{User="Peru",Opponent="Chile"},{User="Chile",Opponent="Peru"}}}),
	quest("rivalry_maghreb_masters", "Rivalry Achievements", "Maghreb Masters", "Beat Algeria as Morocco or Morocco as Algeria.", 1, 4, "rivalryWin", {Rivalries={{User="Morocco",Opponent="Algeria"},{User="Algeria",Opponent="Morocco"}}}),

	quest("historic_three_stars", "Historic Nations", "Three Stars", "Win another World Cup with Argentina.", 1, 5, "titleWithNation", {Nations={"Argentina"}}),
	quest("historic_five_stars", "Historic Nations", "Five Stars", "Win with Brazil.", 1, 5, "titleWithNation", {Nations={"Brazil"}}),
	quest("historic_fourth_star", "Historic Nations", "The Fourth Star", "Win with Italy or Germany.", 1, 5, "titleWithNation", {Nations={"Italy","Germany"}}),
	quest("historic_back_on_top", "Historic Nations", "Back on Top", "Win with Uruguay.", 1, 5, "titleWithNation", {Nations={"Uruguay"}}),
	quest("historic_first_star", "Historic Nations", "First Star", "Win with any nation that has never won the World Cup.", 1, 5, "firstTitle"),
	quest("historic_new_world_order", "Historic Nations", "New World Order", "Reach the final with two nations that have never previously won the World Cup.", 2, 5, "finalNationsNever"),

	quest("european_kings", "Continental", "European Kings", "Win the World Cup with a European nation.", 1, 4, "continentTitle"),
	quest("south_american_supremacy", "Continental", "South American Supremacy", "Win with a South American nation.", 1, 4, "continentTitle"),
	quest("african_history", "Continental", "African History", "Reach the final with an African nation.", 1, 4, "continentFinal"),
	quest("african_champions", "Continental", "African Champions", "Win the World Cup with an African nation.", 1, 5, "continentTitle"),
	quest("asian_breakthrough", "Continental", "Asian Breakthrough", "Reach the semifinals with an Asian nation.", 1, 4, "continentSemi"),
	quest("asian_champions", "Continental", "Asian Champions", "Win the World Cup with an Asian nation.", 1, 5, "continentTitle"),
	quest("concacaf_dream", "Continental", "CONCACAF Dream", "Reach the semifinals with a North or Central American nation.", 1, 4, "continentSemi"),
	quest("oceania_miracle", "Continental", "Oceania Miracle", "Reach the quarterfinals with an Oceanian nation.", 1, 5, "continentQuarter"),
	quest("continental_sweep", "Continental", "Continental Sweep", "Defeat nations from four different continents in one tournament.", 4, 4, "continentsDefeatedRun"),
	quest("world_tour", "Continental", "World Tour", "Defeat a nation from every represented continent across multiple tournaments.", 6, 5, "continentsDefeatedCareer"),
	quest("continental_dominance", "Continental", "Continental Dominance", "Eliminate three nations from the same continent in one tournament.", 3, 4, "sameContinentEliminationsRun"),
	quest("global_champion", "Continental", "Global Champion", "Win World Cups with nations from three different continents.", 3, 5, "titleContinents"),
	quest("around_world", "Continental", "Around the World", "Reach the semifinals with a nation from every continent available in the mode.", 6, 5, "semiContinents"),

	quest("local_supremacy", "Rivalry", "Local Supremacy", "Eliminate a neighbouring nation.", 1, 3, "unsupported"),
	quest("derby_victory", "Rivalry", "Derby Victory", "Win a major international rivalry match.", 1, 3, "unsupported"),
	quest("revenge_served", "Rivalry", "Revenge Served", "Eliminate the nation that knocked you out in the previous tournament.", 1, 4, "unsupported"),
	quest("final_revenge", "Rivalry", "Final Revenge", "Beat a nation in the final after previously losing a final to them.", 1, 5, "unsupported"),
	quest("old_enemies", "Rivalry", "Old Enemies", "Defeat the same rival twice in one tournament.", 2, 4, "sameOpponentWinsRun"),
	quest("regional_kings", "Rivalry", "Regional Kings", "Defeat three nations from your own continent.", 3, 4, "ownContinentWinsRun"),
	quest("no_friendly_neighbours", "Rivalry", "No Friendly Neighbours", "Eliminate two bordering nations in one tournament.", 2, 4, "unsupported"),
	quest("hostile_territory", "Rivalry", "Hostile Territory", "Knock out the host nation.", 1, 4, "hostWin"),
	quest("silence_crowd", "Rivalry", "Silence the Crowd", "Beat the host nation by at least three goals.", 1, 4, "hostBigWin"),
	quest("champion_slayer", "Rivalry", "Champion Slayer", "Eliminate the defending champions.", 1, 4, "defendingChampionWin"),
	quest("giant_killer", "Rivalry", "Giant Killer", "Eliminate three former champions in one tournament.", 3, 5, "formerChampionWinsRun"),
	quest("ultimate_route", "Rivalry", "The Ultimate Route", "Beat the host, defending champion, and tournament favourite.", 3, 5, "ultimateRouteRun"),

	quest("r32_specialist", "Knockout", "Round of 32 Specialist", "Win five Round of 32 matches across different tournaments.", 5, 4, "r32Wins"),
	quest("no_fear", "Knockout", "No Fear", "Defeat a top-seeded nation in the Round of 32.", 1, 4, "topSeedR32Win"),
	quest("early_giant_killing", "Knockout", "Early Giant Killing", "Eliminate a former champion in the Round of 32.", 1, 4, "formerChampionR32Win"),
	quest("clinical_knockout", "Knockout", "Clinical Knockout", "Win a knockout match with three shots on target or fewer.", 1, 4, "unsupported"),
	quest("defensive_masterclass", "Knockout", "Defensive Masterclass", "Win a knockout match without allowing a shot on target.", 1, 4, "unsupported"),
	quest("comeback_qualification", "Knockout", "Comeback Qualification", "Advance after trailing by two goals.", 1, 4, "unsupported"),
	quest("last_minute_qualification", "Knockout", "Last-Minute Qualification", "Score the winning goal after the 85th minute.", 1, 4, "unsupported"),
	quest("extra_time_experts", "Knockout", "Extra-Time Experts", "Win four extra-time matches across one tournament.", 4, 5, "extraTimeWinsRun"),
	quest("shootout_nerves", "Knockout", "Shootout Nerves", "Win a shootout without missing a penalty.", 1, 4, "shootoutWinsRun"),
	quest("sudden_death_heroes", "Knockout", "Sudden Death Heroes", "Win a shootout during sudden death.", 1, 5, "unsupported"),
	quest("goalkeeper_hero", "Knockout", "Goalkeeper Hero", "Save at least three penalties in one shootout.", 1, 5, "unsupported"),
	quest("ten_man_triumph", "Knockout", "Ten-Man Triumph", "Win a knockout match after receiving a red card.", 1, 5, "unsupported"),
	quest("against_run_play", "Knockout", "Against the Run of Play", "Advance with less than 40% possession.", 1, 4, "unsupported"),
	quest("knockout_clean_sheets", "Knockout", "Knockout Clean Sheets", "Keep clean sheets in every knockout round.", 1, 5, "knockoutCleanSheetRun"),
	quest("no_second_chances", "Knockout", "No Second Chances", "Win every knockout game in regulation time.", 1, 5, "regulationKnockoutRun"),

	quest("goal_machine", "Tournament Dominance", "Goal Machine", "Score 20 goals in one tournament.", 20, 4, "goalsForRun"),
	quest("unbreakable_defence", "Tournament Dominance", "Unbreakable Defence", "Concede three goals or fewer in the entire tournament.", 1, 4, "lowConcedeRun"),
	quest("untouchable", "Tournament Dominance", "Untouchable", "Win the tournament without conceding a goal.", 1, 5, "noConcedeTitle"),
	quest("five_star_nation", "Tournament Dominance", "Five-Star Nation", "Score at least five goals in one match.", 1, 3, "fiveGoalMatch"),
	quest("consistent_threat", "Tournament Dominance", "Consistent Threat", "Score in every tournament match.", 1, 4, "scoreEveryMatchRun"),
	quest("fast_starters", "Tournament Dominance", "Fast Starters", "Score first in every match.", 1, 4, "unsupported"),
	quest("second_half_specialists", "Tournament Dominance", "Second-Half Specialists", "Score more second-half goals than every other nation.", 1, 5, "unsupported"),
	quest("late_winners", "Tournament Dominance", "Late Winners", "Score three match-winning goals after the 75th minute.", 3, 5, "unsupported"),
	quest("total_control", "Tournament Dominance", "Total Control", "Average at least 60% possession across the tournament.", 1, 4, "unsupported"),
	quest("counterattack_champions", "Tournament Dominance", "Counterattack Champions", "Win the tournament while averaging under 45% possession.", 1, 5, "unsupported"),
	quest("set_piece_nation", "Tournament Dominance", "Set-Piece Nation", "Score five set-piece goals in one tournament.", 5, 4, "unsupported"),
	quest("squad_depth", "Tournament Dominance", "Squad Depth", "Have ten different goalscorers in one tournament.", 10, 4, "unsupported"),
	quest("super_subs", "Tournament Dominance", "Super Subs", "Score five goals with substitutes.", 5, 4, "unsupported"),
	quest("captain_fantastic", "Tournament Dominance", "Captain Fantastic", "Have your captain score in three knockout rounds.", 3, 5, "unsupported"),
	quest("golden_boot_trophy", "Tournament Dominance", "Golden Boot and Trophy", "Win the World Cup and the top-scorer award.", 1, 5, "unsupported"),
	quest("complete_sweep", "Tournament Dominance", "Complete Sweep", "Win the World Cup, Golden Boot, Golden Ball, and Golden Glove.", 1, 5, "unsupported"),

	quest("one_nation_legend", "Manager Career", "One-Nation Legend", "Win three tournaments with the same nation.", 3, 5, "sameNationTitles"),
	quest("world_traveller", "Manager Career", "World Traveller", "Manage ten different nations.", 10, 4, "managedNations"),
	quest("continental_collector", "Manager Career", "Continental Collector", "Win trophies with nations from three continents.", 3, 5, "titleContinents"),
	quest("rebuilder", "Manager Career", "Rebuilder", "Take a nation from a Round of 32 exit to becoming champions.", 1, 5, "unsupported"),
	quest("instant_impact", "Manager Career", "Instant Impact", "Win the World Cup in your first tournament with a nation.", 1, 5, "instantImpact"),
	quest("second_chance", "Manager Career", "Second Chance", "Win after failing to reach the quarterfinals in the previous tournament.", 1, 5, "unsupported"),
	quest("disaster_to_glory", "Manager Career", "From Disaster to Glory", "Win the World Cup after losing your opening match.", 1, 5, "openingLossTitle"),
	quest("serial_finalist", "Manager Career", "Serial Finalist", "Reach three consecutive finals.", 3, 5, "careerFinals"),
	quest("knockout_veteran", "Manager Career", "Knockout Veteran", "Win 50 knockout matches.", 50, 5, "knockoutWins"),
	quest("century_wins", "Manager Career", "Century of Wins", "Win 100 World Cup mode matches.", 100, 5, "careerWins"),
	quest("nation_collector", "Manager Career", "Nation Collector", "Win the World Cup with five different nations.", 5, 5, "titleNations"),
	quest("ultimate_manager", "Manager Career", "Ultimate Manager", "Win with a favourite, a mid-tier nation, and an underdog.", 3, 5, "tierTitles"),
	quest("every_continent", "Manager Career", "Every Continent", "Manage at least one nation from every available continent.", 6, 5, "managedContinents"),
	quest("football_immortality", "Manager Career", "Football Immortality", "Win ten World Cups across your career.", 10, 5, "titles"),

	quest("miracle_century", "Secret", "Miracle of the Century", "Win the World Cup with the lowest-rated nation.", 1, 5, "lowestRatedTitle"),
	quest("deja_vu", "Secret", "Deja Vu", "Recreate a previous real-world World Cup final and produce the same winner.", 1, 5, "unsupported"),
	quest("history_rewritten", "Secret", "History Rewritten", "Win a historic final with the nation that originally lost it.", 1, 5, "unsupported"),
	quest("invincibles", "Secret", "The Invincibles", "Go unbeaten across three full tournaments.", 3, 5, "unbeatenTitles"),
	quest("zero_to_hero", "Secret", "Zero to Hero", "Win after finishing last in your previous tournament.", 1, 5, "unsupported"),
	quest("ultimate_redemption", "Secret", "Ultimate Redemption", "Lose a final, then win the next tournament against the same opponent.", 1, 5, "unsupported"),
	quest("impossible_treble", "Secret", "The Impossible Treble", "Beat three top-five nations in consecutive knockout rounds.", 3, 5, "topFiveKnockoutStreakRun"),
	quest("kings_chaos", "Secret", "Kings of Chaos", "Win the tournament with every knockout match decided after the 80th minute.", 1, 5, "unsupported"),
	quest("one_goal_champions", "Secret", "One-Goal Champions", "Win every knockout match by exactly one goal.", 1, 5, "oneGoalKnockoutRun"),
	quest("destiny_fulfilled", "Secret", "Destiny Fulfilled", "Win a nation's first title with a winning goal from its captain in the final.", 1, 5, "unsupported"),
})

local byId = {}
for _, definition in Config.Quests do
	byId[definition.Id] = definition
end
Config.ById = table.freeze(byId)

function Config.PackName(packId: string): string
	local names = {
		bronze_pack = "Bronze Pack",
		silver_pack = "Silver Pack",
		gold_pack = "Gold Pack",
		rare_pack = "Rare Pack",
		elite_pack = "Elite Pack",
		champion_pack = "Champion Pack",
	}
	return names[packId] or packId
end

return table.freeze(Config)
