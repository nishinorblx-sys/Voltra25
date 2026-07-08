--!strict

local Config = {}

local function gamePassIcon(id: number): string
	return "rbxthumb://type=GamePass&id=" .. tostring(id) .. "&w=150&h=150"
end

local function productIcon(id: number): string
	return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150"
end

Config.GamePassOrder = {
	"vip_pass",
	"walkout_celebration_locker",
	"custom_goal_music",
	"premium_stadium",
	"premium_club",
}

Config.GamePasses = {
	vip_pass = {
		Id = "vip_pass",
		Name = "VIP PASS",
		GamePassId = 1898672212,
		Icon = gamePassIcon(1898672212),
		Description = "Permanent VIP status across Voltra with VIP chat tag, profile badge, VIP cosmetics, and small daily bonus rewards. Premium supporter flex, not pay-to-win.",
		Unlocks = {"vip_chat_tag", "vip_profile_badge", "vip_nameplate", "vip_daily_bonus", "vip_voltra_kit"},
	},
	walkout_celebration_locker = {
		Id = "walkout_celebration_locker",
		Name = "WALKOUT + CELEBRATION LOCKER",
		GamePassId = 1899206226,
		Icon = gamePassIcon(1899206226),
		Description = "Unlocks special walkout animations and goal celebration styles. Equip them before matches for intros and post-goal moments.",
		Unlocks = {"walkout_static_surging", "walkout_captain_pose", "celebration_knee_slide", "celebration_cold_pose", "celebration_team_huddle"},
	},
	custom_goal_music = {
		Id = "custom_goal_music",
		Name = "CUSTOM GOAL MUSIC",
		GamePassId = 1900070256,
		Icon = gamePassIcon(1900070256),
		Description = "Enter a Roblox audio id, choose the start second, and play your custom goal music for 8 seconds when you score.",
		Unlocks = {"goal_music_voltra_pulse", "goal_music_stadium_surge", "goal_music_night_charge"},
	},
	premium_stadium = {
		Id = "premium_stadium",
		Name = "PREMIUM STADIUM",
		GamePassId = 1898216305,
		Icon = gamePassIcon(1898216305),
		Description = "Unlocks premium club stadium customisation: pitch designs, banners, lighting, pyro, scoreboards, seat colours, and atmosphere effects.",
		Unlocks = {"premium_pitch_neon_grid", "premium_pyro_green", "premium_scoreboard_voltra", "premium_stadium_lights"},
	},
	premium_club = {
		Id = "premium_club",
		Name = "PREMIUM CLUB",
		GamePassId = 1900154242,
		Icon = gamePassIcon(1900154242),
		Description = "Unlocks deeper club identity customisation: premium badges, banners, profile frames, club colours, and nameplates.",
		Unlocks = {"premium_badge_prism", "premium_banner_afterdark", "premium_profile_frame", "premium_nameplate"},
	},
}

Config.CoinBundles = {
	coin_small = {Id = "coin_small", Name = "SMALL COIN PACK", Coins = 7500, Robux = 49, ProductId = 3608263594, Icon = productIcon(94410583783391), Description = "Entry coin bundle for packs, cards, and normal progression."},
	coin_medium = {Id = "coin_medium", Name = "MEDIUM COIN PACK", Coins = 25000, Robux = 129, ProductId = 3608263688, Icon = productIcon(120591481834509), Description = "Better value coin bundle for squad building."},
	coin_large = {Id = "coin_large", Name = "LARGE COIN PACK", Coins = 90000, Robux = 399, ProductId = 3608263787, Icon = productIcon(129062189523365), Description = "Large coin bundle for serious progression and store purchases."},
	coin_elite = {Id = "coin_elite", Name = "ELITE COIN PACK", Coins = 240000, Robux = 999, ProductId = 3608263851, Icon = productIcon(119411110235428), Description = "Best-value coin vault for premium squad building."},
}

Config.VoltraPointBundles = {
	vp_mini = {Id = "vp_mini", Name = "MINI VOLTRA POINTS", VoltraPoints = 250, Robux = 49, ProductId = 3608264133, Icon = productIcon(133957252810221), Description = "Small premium currency pack for cosmetics and rerolls."},
	vp_standard = {Id = "vp_standard", Name = "STANDARD VOLTRA POINTS", VoltraPoints = 700, Robux = 129, ProductId = 3608264367, Icon = productIcon(86533468344783), Description = "Standard Voltra Points for premium cosmetics and daily deals."},
	vp_pro = {Id = "vp_pro", Name = "PRO VOLTRA POINTS", VoltraPoints = 1800, Robux = 399, ProductId = 3608264418, Icon = productIcon(105055149566634), Description = "High-value Voltra Points bundle."},
	vp_elite = {Id = "vp_elite", Name = "ELITE VOLTRA POINTS", VoltraPoints = 5000, Robux = 999, ProductId = 3608264478, Icon = productIcon(107108325782244), Description = "Best-value Voltra Points bundle."},
}

Config.Products = {
	launch_bundle = {Id = "launch_bundle", Name = "LAUNCH BUNDLE", ProductId = 3608266186, Kind = "LaunchBundle", Icon = productIcon(105128504601325), Description = "Limited-time starter bundle with coins, Voltra Points, an exclusive launch cosmetic, and a launch pack.", Coins = 25000, VoltraPoints = 600, Packs = {"gold_pack"}, Cosmetics = {"launch_founder_badge", "launch_founder_frame"}},
	coins_2x_30m = {Id = "coins_2x_30m", Name = "2X COINS - 30 MIN", ProductId = 3608265973, Kind = "CoinBoost", Icon = productIcon(129915285716165), Description = "Doubles earned match coins for 30 minutes.", DurationSeconds = 1800, Multiplier = 2},
	coins_2x_1h = {Id = "coins_2x_1h", Name = "2X COINS - 1 HOUR", ProductId = 3608266029, Kind = "CoinBoost", Icon = productIcon(96200306538101), Description = "Doubles earned match coins for 1 hour.", DurationSeconds = 3600, Multiplier = 2},
	limited_boots = {Id = "limited_boots", Name = "LIMITED BOOTS", ProductId = 3608265863, Kind = "Cosmetic", CosmeticType = "Boot", GrantItemId = "boots_limited_green", Icon = productIcon(84685812185018), Description = "Limited one-colour boots for ranked and club matches."},
	animated_boots = {Id = "animated_boots", Name = "ANIMATED BOOTS", ProductId = 3608265788, Kind = "Cosmetic", CosmeticType = "Boot", GrantItemId = "boots_animated_trail", Icon = productIcon(120877346227330), Description = "Glow boots with a short neon trail effect."},
	premium_boots = {Id = "premium_boots", Name = "PREMIUM BOOTS", ProductId = 3608265741, Kind = "Cosmetic", CosmeticType = "Boot", GrantItemId = "boots_gradient_premium", Icon = productIcon(110003509555383), Description = "Gradient coloured premium boot style."},
	founder_kit = {Id = "founder_kit", Name = "FOUNDER KIT", ProductId = 3608265699, Kind = "Kit", GrantItemId = "founder_voltra_kit", Icon = productIcon(125747947529685), Description = "Green and white patterned Voltra founder kit."},
	limited_kit = {Id = "limited_kit", Name = "LIMITED KIT", ProductId = 3608265669, Kind = "Kit", GrantItemId = "limited_black_voltra_kit", Icon = productIcon(124047048224562), Description = "Black limited Voltra kit with electric trim."},
	animated_kit = {Id = "animated_kit", Name = "ANIMATED KIT", ProductId = 3608265610, Kind = "Kit", GrantItemId = "animated_pulse_kit", Icon = productIcon(115635095631911), Description = "Animated kit with moving Voltra pattern details."},
	premium_kit = {Id = "premium_kit", Name = "PREMIUM KIT", ProductId = 3608265565, Kind = "Kit", GrantItemId = "premium_gradient_kit", Icon = productIcon(95107931434866), Description = "Blue and red gradient premium Voltra kit."},
	goal_stadium_shake = {Id = "goal_stadium_shake", Name = "STADIUM SHAKE GOAL", ProductId = 3608265501, Kind = "Cosmetic", CosmeticType = "GoalEffect", GrantItemId = "goal_fx_stadium_shake", Icon = productIcon(96599326994832), Description = "A short stadium shake every time you score."},
	goal_golden = {Id = "goal_golden", Name = "GOLDEN GOAL", ProductId = 3608265453, Kind = "Cosmetic", CosmeticType = "GoalEffect", GrantItemId = "goal_fx_golden_explosion", Icon = productIcon(100251403800447), Description = "Gold burst goal effect using the GoldenExplosion effect asset when available."},
	goal_lightning = {Id = "goal_lightning", Name = "LIGHTNING GOAL", ProductId = 3608265402, Kind = "Cosmetic", CosmeticType = "GoalEffect", GrantItemId = "goal_fx_lightning", Icon = productIcon(71548776606024), Description = "Electric lightning burst after goals."},
	goal_fire = {Id = "goal_fire", Name = "FIRE GOAL", ProductId = 3608265340, Kind = "Cosmetic", CosmeticType = "GoalEffect", GrantItemId = "goal_fx_fire", Icon = productIcon(104220264598712), Description = "Fire burst goal effect."},
	goal_smoke = {Id = "goal_smoke", Name = "SMOKE GOAL", ProductId = 3608265250, Kind = "Cosmetic", CosmeticType = "GoalEffect", GrantItemId = "goal_fx_smoke", Icon = productIcon(73505136649449), Description = "Smoke cloud goal effect."},
	celebrations_basic = {Id = "celebrations_basic", Name = "BASIC CELEBRATIONS", ProductId = 3608265016, Kind = "CelebrationPack", Icon = productIcon(132979155569144), Description = "Rolls a basic celebration such as clap, wave, or badge point.", Pool = {"celebration_clap", "celebration_wave", "celebration_badge_point"}},
	celebrations_pro = {Id = "celebrations_pro", Name = "PRO CELEBRATIONS", ProductId = 3608265057, Kind = "CelebrationPack", Icon = productIcon(102526019881502), Description = "Rolls a pro celebration such as knee slide, sprint pose, or camera stare.", Pool = {"celebration_knee_slide", "celebration_sprint_pose", "celebration_camera_stare"}},
	celebrations_elite = {Id = "celebrations_elite", Name = "ELITE CELEBRATIONS", ProductId = 3608265113, Kind = "CelebrationPack", Icon = productIcon(102196362794768), Description = "Rolls an elite celebration such as cold pose, team huddle, or backflip style.", Pool = {"celebration_cold_pose", "celebration_team_huddle", "celebration_flip_style"}},
	celebrations_limited = {Id = "celebrations_limited", Name = "LIMITED CELEBRATIONS", ProductId = 3608265158, Kind = "CelebrationPack", Icon = productIcon(133953814358712), Description = "Rolls a limited celebration from the current Voltra event pool.", Pool = {"celebration_limited_voltage", "celebration_limited_ice", "celebration_limited_crown"}},
	daily_bundle_deal = {Id = "daily_bundle_deal", Name = "DAILY BUNDLE DEAL", ProductId = 3608264766, Kind = "DailyDeal", Icon = productIcon(70475392451415), Description = "Daily rotating spin with coins, Voltra Points, cosmetics, boosts, or small rewards."},
	star_card = {Id = "star_card", Name = "STAR CARD", ProductId = 3608264587, Kind = "StarCard", Icon = productIcon(98888362211552), Description = "Direct-purchase featured Star Card. Not random from packs."},
	star_reroll = {Id = "star_reroll", Name = "STAR REROLL", ProductId = 3608264682, Kind = "StarReroll", Icon = productIcon(130572112366046), Description = "Refreshes the current Star Card offer with daily limits."},
}

Config.ProductOrder = {
	"launch_bundle",
	"coins_2x_30m",
	"coins_2x_1h",
	"daily_bundle_deal",
	"star_card",
	"star_reroll",
}

Config.KitProductOrder = {"founder_kit", "limited_kit", "animated_kit", "premium_kit"}
Config.BootProductOrder = {"limited_boots", "animated_boots", "premium_boots"}
Config.GoalEffectProductOrder = {"goal_stadium_shake", "goal_golden", "goal_lightning", "goal_fire", "goal_smoke"}
Config.CelebrationProductOrder = {"celebrations_basic", "celebrations_pro", "celebrations_elite", "celebrations_limited"}

Config.ApprovedGoalMusic = {
	{Id = "goal_music_voltra_pulse", Name = "VOLTRA PULSE", SoundId = "rbxassetid://75642333208760"},
	{Id = "goal_music_stadium_surge", Name = "STADIUM SURGE", SoundId = "rbxassetid://114836843250240"},
	{Id = "goal_music_night_charge", Name = "NIGHT CHARGE", SoundId = "rbxassetid://78442706550929"},
}

Config.ProductById = {}
for _, product in Config.Products do
	Config.ProductById[product.ProductId] = product
end
for _, bundle in Config.CoinBundles do
	Config.ProductById[bundle.ProductId] = table.clone(bundle)
	Config.ProductById[bundle.ProductId].Kind = "CoinPack"
end
for _, bundle in Config.VoltraPointBundles do
	Config.ProductById[bundle.ProductId] = table.clone(bundle)
	Config.ProductById[bundle.ProductId].Kind = "VoltraPoints"
end

function Config.GetProductById(productId: number): any?
	return Config.ProductById[productId]
end

return table.freeze(Config)
