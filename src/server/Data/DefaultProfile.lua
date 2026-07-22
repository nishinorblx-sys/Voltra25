--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local EconomyConfig=require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local CampaignAscensionConfig=require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local PlayabilitySettingsConfig=require(ReplicatedStorage.VTR.Shared.PlayabilitySettingsConfig)
local function defaultSettings():any
	local settings=PlayabilitySettingsConfig.CopyDefaults()
	settings.ReceiverAssistMode="Newcomer"
	settings.PassReceiverAutoSwitch="Newcomer"
	settings.DefensiveAutoSwitchMode="Newcomer"
	for key,value in {TimedFinishing=true,MenuMusic=true,MotionEffects=true,InvertY=false,HighContrast=false,Crossplay=true,MasterVolume=0.8,PlayerNames="Active Only",Minimap="Medium",MinimapOrientation="Broadcast",BroadcastHeight="178",BroadcastZoom="50",CameraSpeed="1",CameraSide="Near",PauseKey="M",SkipKey="Space",TutorialComplete=false,TutorialStep=1,TutorialDevice=""}do settings[key]=value end
	return settings
end
return table.freeze({
	Version=16,SchemaVersion=16,CreatedAt=0,LastLogin=0,OnboardingCompleted=false,
	Profile={Level=1,XP=0,SelectedClub="NO CLUB",Avatar={UserId=0,HeadshotType="HeadShot",OutfitId=0}},
	Currency={Coins=EconomyConfig.StarterCoins,Bolts=EconomyConfig.StarterBolts,VoltraPoints=EconomyConfig.StarterVoltraPoints},Season={Name="SEASON 01",Level=1,XP=0,RequiredXP=1000},
	Ranked={Division="DIVISION 10",DivisionNumber=10,DivisionWins=0,ProtectedWins=0,VoltraRating=0,Rank="NEW SEASON",PlacementStatus="PLACEMENT READY",Wins=0,Draws=0,Losses=0,RP=0,RequiredRP=10,WinStreak=0,BestWinStreak=0,FlawlessRuns=0,CleanSheets=0,BestPackRating=0,History={},PlayerStats={MatchesPlayed=0,Goals=0,Assists=0,MOTM=0,AverageRating=0,HatTricks=0,PenaltiesScored=0,FreeKickGoals=0}},
	Objectives={
		{objectiveId="build_first_xi",groupId="starter_journey",sortOrder=1,title="BUILD FIRST XI",description="Fill all 11 starting squad positions",progress=0,target=11,reward={Type="XP",Amount=250},status="locked",nextObjectiveId="open_first_pack",cadence="Starter"},
		{objectiveId="open_first_pack",groupId="starter_journey",sortOrder=2,title="OPEN FIRST PACK",description="Open your first VTR player pack",progress=0,target=1,reward={Type="Coins",Amount=500},status="locked",nextObjectiveId="upgrade_squad_rating",cadence="Starter"},
		{objectiveId="upgrade_squad_rating",groupId="starter_journey",sortOrder=3,title="UPGRADE SQUAD RATING",description="Reach a squad rating of 75",progress=0,target=75,reward={Type="XP",Amount=500},status="locked",nextObjectiveId="play_first_match_placeholder",cadence="Starter"},
		{objectiveId="play_first_match_placeholder",groupId="starter_journey",sortOrder=4,title="PLAY YOUR FIRST MATCH",description="Reach the server-validated temporary match scene",progress=0,target=1,reward={Type="Pack",Amount=1,ItemId="voltage_standard"},status="locked",nextObjectiveId="claim_daily_reward",cadence="Starter"},
		{objectiveId="claim_daily_reward",groupId="starter_journey",sortOrder=5,title="CLAIM DAILY REWARD",description="Claim a reward from the daily inbox",progress=0,target=1,reward={Type="Bolts",Amount=50},status="locked",nextObjectiveId=nil,cadence="Starter"},
		{objectiveId="daily_visit_store",groupId="daily",sortOrder=1,title="EXPLORE THE STORE",description="View any store category",progress=0,target=1,reward={Type="Coins",Amount=300},status="locked",nextObjectiveId=nil,cadence="Daily"},
		{objectiveId="weekly_customize_club",groupId="weekly",sortOrder=1,title="MAKE IT YOURS",description="Equip a club kit and stadium",progress=0,target=2,reward={Type="Pack",Amount=1,ItemId="voltage_standard"},status="locked",nextObjectiveId=nil,cadence="Weekly"},
		{objectiveId="milestone_level_5",groupId="milestone",sortOrder=1,title="FIRST SURGE",description="Reach account level 5",progress=1,target=5,reward={Type="Bolts",Amount=150},status="locked",nextObjectiveId=nil,cadence="Milestone"},
	},
	RankedRewards={{Id="rookie_welcome",Title="ROOKIE WELCOME",Description="1,000 Coins",Claimed=false}},RewardsInbox={{Id="launch_welcome",Title="WELCOME TO VTR 25",Description="500 Coins + 50 Bolts",Type="Welcome",Claimed=false}},
	PackInventory={},PlayerCardInventory={},RewardTransactionLedger={},InventoryGrantLedger={},Squad={},Bench={},Reserves={},PlayerCardMeta={},Formation="4-3-3",
	CampaignProgress=CampaignAscensionConfig.CreateProgress(),
	PlayabilityProgress={Version=2,CompletedMatches=0,FirstMatchCompleted=false,FirstRewardGranted=false,FirstRewardCardInstanceId="",FirstRewardPlayerName="",SecondMatchCompleted=false,FirstWorldCupRunCompleted=false,LegacyAccessGranted=false},
	MatchStats={Overall={Played=0,Wins=0,Draws=0,Losses=0},Ranked={Played=0,Wins=0,Draws=0,Losses=0},Campaign={Played=0,Wins=0,Draws=0,Losses=0},WorldCup={Played=0,Wins=0,Draws=0,Losses=0},AppliedResults={},History={}},
	DailyLogin={WeekKey="",ClaimedDays={},TrackDay=1,LastClaimedAt=0,LastClaimedDayKey=0,LastClaimedTrackDay=0},
	WorldCup=false,WorldCupPendingMatch=nil,WorldCupHistory={},WorldCupQuests={Progress={},Claimed={}},
	RankedRun={Active=false,Results={},Wins=0,Draws=0,Losses=0,Target=7,Ended=false,RewardClaimed=false},
	UnopenedPacks={},OwnedPlayers={},
	TeamTactics={Identity="Balanced",Sliders={BuildUpSpeed=50,PassingDirectness=50,AttackingWidth=50,DefensiveWidth=50,DefensiveDepth=50,PressingIntensity=45,CounterAttackFrequency=45,OverlapFrequency=45,CrossingFrequency=45,LongShotFrequency=35,DribblingFreedom=45,RiskLevel=45}},
	PlayerInstructions={},CustomTactics={},
	SquadState={startingXI={GK=nil,LB=nil,CB1=nil,CB2=nil,RB=nil,CM1=nil,CDM=nil,CM2=nil,LW=nil,ST=nil,RW=nil},bench={slot1=nil,slot2=nil,slot3=nil,slot4=nil,slot5=nil,slot6=nil,slot7=nil},reserves={},transferList={}},Inventory={Items={}},
	ClubMembership={ClubId="",Name="NO CLUB",Abbreviation="",PrimaryColor="electric_green",SecondaryColor="pure_black",AccentColor="silver",KitStyle="Solid",BadgePreset="Modern",BadgeShape="Shield",BadgeSymbol="Lightning Bolt",BadgeColorBehavior="Tri Color",Role="FREE AGENT",Members=0,Capacity=24,Reputation="UNRANKED"},CareerSaveSlots={{Slot=1,Type="Empty"},{Slot=2,Type="Empty"},{Slot=3,Type="Empty"}},
	ProClubMembership={ClubId="",Name="NO PRO CLUB",Tag="",Role="FREE AGENT",Members=0,Capacity=24,Reputation="UNRANKED",LeagueId="",JoinPolicy="InviteOnly",MatchHistory={}},
	ProClubsPlayer={Created=false,FirstName="",LastName="",CommentaryName="",JerseyName="",JerseyNumber=9,PreferredFoot="Right",HeightCm=180,WeightKg=75,Position="ST",Level=1,XP=0,Overall=60,AttributePointsAvailable=20,SpentAttributePoints={},BuildPath="",PerkPoints=0,EquippedPerks={},UnlockedPerks={},EquippedPlaystyles={},UnlockedPlaystyles={},SignatureAbility="",Prestige=0,Appearance={},Animations={},Celebrations={},Statistics={Matches=0,Goals=0,Assists=0,AverageRating=0}},
	PlayBuilder={Archetype="Finisher",Role="CF",TraitA="Threaded",TraitB="Explosive Start",Style="Poacher+",Attributes={},Traits={},UpdatedAt=0},
	StoreOwnership={Kits={"home_kit"},Stadiums={"academy_ground"},Cosmetics={},GamePasses={}},ActiveBoosts={Coins2xUntil=0},PurchaseHistory={},StarCard={Offer=nil,RerollsToday=0,RerollDay=0},Fixtures={{Id="welcome_fixture",HomeTeam="YOUR CLUB",AwayTeam="VOLTRA ACADEMY",Competition="WELCOME SERIES",StartsAt=0,DisplayTime="SOON"},{Id="academy_preview",HomeTeam="NEON FORGE",AwayTeam="YOUR CLUB",Competition="ACADEMY PREVIEW",StartsAt=0,DisplayTime="TBD"}},
	Onboarding={Complete=false,Step=1,ClubName="",Abbreviation="",PrimaryColor="electric_green",SecondaryColor="pure_black",AccentColor="silver",KitStyle="Solid",BadgePreset="Modern",BadgeShape="Shield",BadgeSymbol="Lightning Bolt",BadgeColorBehavior="Tri Color",IdentityConfigured=false,StarterPackClaimed=false,StarterPackOpened=false,SquadFilled=false,ObjectivesActivated=false},
	Settings=defaultSettings(),OwnedCosmetics={},
	MatchSetup={MatchFormat="Standard",MatchLength=6,Difficulty="Professional",MatchType="Objective Match",HomeTeamId="",AwayTeamId="",HomeKit="Home",AwayKit="Away",StadiumId="voltra_arena",Weather="Clear",Time="Evening",Completed=false,SavedAt=0,KitConflict=false,CampaignTeamId="",CampaignTier=0,CampaignReplay=false},
	UIState={LastPage="Home",SelectedTabs={},Settings=defaultSettings(),SelectedSquad={},EquippedCosmetics={ActiveKit="home_kit",StadiumTheme="academy_ground",BootStyle="",GoalEffect="",GoalMusic="",CustomGoalMusicId="",CustomGoalMusicStart=0,Walkout="",Celebration="",ProfileFrame="",ClubBanner="",Nameplate=""},CareerSaveSelection=1},
})
