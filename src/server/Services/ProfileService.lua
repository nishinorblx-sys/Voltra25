--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage.VTR.Shared.ProgressionConfig)
local EconomyConfig=require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local DeveloperConfig=require(ReplicatedStorage.VTR.Shared.DeveloperConfig)
local ClubIdentityConfig=require(ReplicatedStorage.VTR.Shared.ClubIdentityConfig)
local PlayBuilderConfig=require(ReplicatedStorage.VTR.Shared.PlayBuilderConfig)
local PlayabilitySettingsConfig=require(ReplicatedStorage.VTR.Shared.PlayabilitySettingsConfig)
local MatchFormatConfig=require(ReplicatedStorage.VTR.Shared.MatchFormatConfig)
local PlayerCareerConfig=require(ReplicatedStorage.VTR.Shared.PlayerCareerConfig)
local ObjectiveDefinitions=require(script.Parent.Parent.Data.Objectives)
local CardInstanceFactory=require(script.Parent.Parent.Data.CardInstanceFactory)
local PackInstanceFactory=require(script.Parent.Parent.Data.PackInstanceFactory)
local DefaultProfile=require(script.Parent.Parent.Data.DefaultProfile)
local CampaignMigration=require(script.Parent.CampaignMigration)
local ProfileService={};ProfileService.__index=ProfileService

local function copy(value:any):any if type(value)~="table" then return value end;local result={};for key,child in value do result[key]=copy(child) end;return result end

local function applyStudioDefaultTeam(profile:any,player:Player)
	if not RunService:IsStudio() then return end
	if workspace:GetAttribute("VTRStudioUseDefaultTeam")~=true then return end
	local club=profile.ClubMembership or{}
	club.ClubId=club.ClubId~=""and club.ClubId or("studio_club_"..tostring(player.UserId))
	club.Name="STUDIO UNITED"
	club.Abbreviation="VTR"
	club.Tag="VTR"
	club.PrimaryColor="electric_green"
	club.SecondaryColor="pure_black"
	club.AccentColor="silver"
	club.KitStyle=ClubIdentityConfig.ResolveStyle("Solid")
	club.BadgePreset="Modern"
	club.BadgeShape="Shield"
	club.BadgeSymbol="Lightning Bolt"
	club.BadgeColorBehavior="Tri Color"
	club.Role=club.Role~="FREE AGENT"and club.Role or"FOUNDER"
	club.Members=math.max(1,tonumber(club.Members)or 1)
	club.Capacity=tonumber(club.Capacity)or 24
	club.Reputation=club.Reputation~="UNRANKED"and club.Reputation or"ROOKIE"
	profile.ClubMembership=club
	profile.Profile.SelectedClub=club.Name
	local onboarding=profile.Onboarding or{}
	onboarding.Complete=true
	onboarding.Step=10
	onboarding.ClubName=club.Name
	onboarding.Abbreviation=club.Abbreviation
	onboarding.PrimaryColor=club.PrimaryColor
	onboarding.SecondaryColor=club.SecondaryColor
	onboarding.AccentColor=club.AccentColor
	onboarding.KitStyle=club.KitStyle
	onboarding.BadgePreset=club.BadgePreset
	onboarding.BadgeShape=club.BadgeShape
	onboarding.BadgeSymbol=club.BadgeSymbol
	onboarding.BadgeColorBehavior=club.BadgeColorBehavior
	onboarding.IdentityConfigured=true
	onboarding.StarterPackClaimed=true
	onboarding.StarterPackOpened=true
	onboarding.SquadFilled=true
	onboarding.ObjectivesActivated=true
	profile.Onboarding=onboarding
	profile.OnboardingCompleted=true
end

local function ensureList(parent:any,key:string)
	parent[key]=type(parent[key])=="table" and parent[key] or {}
	return parent[key]
end

local removedDefaultKits={starter_black_green=true,starter_silver_green=true,starter_graphite_white=true}

local function normalizeDefaultKits(profile:any)
	local kits=ensureList(profile.StoreOwnership,"Kits")
	local normalized={}
	local hasHome=false
	for _,kitId in kits do
		if kitId=="home_kit" then
			hasHome=true
			table.insert(normalized,kitId)
		elseif not removedDefaultKits[kitId] then
			table.insert(normalized,kitId)
		end
	end
	if not hasHome then table.insert(normalized,1,"home_kit") end
	profile.StoreOwnership.Kits=normalized
	local equipped=profile.UIState and profile.UIState.EquippedCosmetics
	if type(equipped)=="table" and (not equipped.ActiveKit or equipped.ActiveKit=="" or removedDefaultKits[equipped.ActiveKit]) then
		equipped.ActiveKit="home_kit"
	end
end

local function ensureMonetizationFields(profile:any)
	profile.Currency=type(profile.Currency)=="table" and profile.Currency or {}
	profile.Currency.Coins=tonumber(profile.Currency.Coins) or EconomyConfig.StarterCoins
	profile.Currency.Bolts=tonumber(profile.Currency.Bolts) or EconomyConfig.StarterBolts
	profile.Currency.VoltraPoints=tonumber(profile.Currency.VoltraPoints) or EconomyConfig.StarterVoltraPoints or 0
	profile.StoreOwnership=type(profile.StoreOwnership)=="table" and profile.StoreOwnership or {}
	ensureList(profile.StoreOwnership,"Kits")
	ensureList(profile.StoreOwnership,"Stadiums")
	ensureList(profile.StoreOwnership,"Cosmetics")
	ensureList(profile.StoreOwnership,"GamePasses")
	profile.ActiveBoosts=type(profile.ActiveBoosts)=="table" and profile.ActiveBoosts or {}
	profile.ActiveBoosts.Coins2xUntil=tonumber(profile.ActiveBoosts.Coins2xUntil) or 0
	profile.PurchaseHistory=type(profile.PurchaseHistory)=="table" and profile.PurchaseHistory or {}
	profile.StarCard=type(profile.StarCard)=="table" and profile.StarCard or {Offer=nil,RerollsToday=0,RerollDay=0}
	profile.UIState=type(profile.UIState)=="table" and profile.UIState or copy(DefaultProfile.UIState)
	profile.UIState.EquippedCosmetics=type(profile.UIState.EquippedCosmetics)=="table" and profile.UIState.EquippedCosmetics or {}
	local equipped=profile.UIState.EquippedCosmetics
	for key,value in {ActiveKit="home_kit",StadiumTheme="academy_ground",BootStyle="",GoalEffect="",GoalMusic="",CustomGoalMusicId="",CustomGoalMusicStart=0,Walkout="",Celebration="",ProfileFrame="",ClubBanner="",Nameplate=""} do
		if equipped[key]==nil then equipped[key]=value end
	end
	normalizeDefaultKits(profile)
	if table.find(profile.StoreOwnership.GamePasses,"vip_pass") and not table.find(profile.StoreOwnership.Kits,"vip_voltra_kit") then
		table.insert(profile.StoreOwnership.Kits,"vip_voltra_kit")
	end
	profile.OwnedCosmetics=type(profile.OwnedCosmetics)=="table" and profile.OwnedCosmetics or {}
	for key,value in equipped do
		if profile.OwnedCosmetics[key]==nil then profile.OwnedCosmetics[key]=value end
	end
	if equipped.ActiveKit==nil or equipped.ActiveKit=="" or removedDefaultKits[equipped.ActiveKit] then
		equipped.ActiveKit="home_kit"
	end
	if profile.OwnedCosmetics.ActiveKit==nil or profile.OwnedCosmetics.ActiveKit=="" or removedDefaultKits[profile.OwnedCosmetics.ActiveKit] then
		profile.OwnedCosmetics.ActiveKit=equipped.ActiveKit
	end
end

local migrations={
	[1]=function(p:any) p.StoreOwnership=p.StoreOwnership or {Kits={},Stadiums={},Cosmetics={}};p.Onboarding=p.Onboarding or {Complete=false,Step=1};return 2 end,
	[2]=function(p:any) if type(p.CreatedAt)~="number" or p.CreatedAt<=0 then p.CreatedAt=os.time() end;p.LastLogin=os.time();p.OnboardingCompleted=p.Onboarding and p.Onboarding.Complete or false;if not p.Squad or next(p.Squad)==nil then p.Squad=table.clone(p.UIState and p.UIState.SelectedSquad or {}) end;if not p.Settings or next(p.Settings)==nil then p.Settings=table.clone(p.UIState and p.UIState.Settings or {}) end;if not p.OwnedCosmetics or next(p.OwnedCosmetics)==nil then p.OwnedCosmetics=table.clone(p.UIState and p.UIState.EquippedCosmetics or {}) end;p.Version=3;p.SchemaVersion=3;return 3 end,
	[3]=function(p:any) p.Version=4;p.SchemaVersion=4;return 4 end,
	[4]=function(p:any) p.Version=5;p.SchemaVersion=5;return 5 end,
	[5]=function(p:any) p.Bench=p.Bench or {};p.Reserves=p.Reserves or {};p.PlayerCardMeta=p.PlayerCardMeta or {};p.Formation=p.Formation or "4-3-3";p.Version=6;p.SchemaVersion=6;return 6 end,
	[6]=function(p:any) local bench={};for index=1,7 do bench["slot"..index]=p.Bench and p.Bench[index] or nil end;p.SquadState={startingXI=table.clone(p.Squad or {}),bench=bench,reserves=table.clone(p.Reserves or {}),transferList={}};p.Version=7;p.SchemaVersion=7;return 7 end,
	[7]=function(p:any) p.Version=8;p.SchemaVersion=8;return 8 end,
	[8]=function(p:any) p.MatchSetup=p.MatchSetup or {MatchLength=6,Difficulty="Professional",MatchType="Objective Match",HomeTeamId="",AwayTeamId="",HomeKit="Home",AwayKit="Away",StadiumId="voltra_arena",Weather="Clear",Time="Evening",Completed=false,SavedAt=0,KitConflict=false};p.Version=9;p.SchemaVersion=9;return 9 end,
	[9]=function(p:any)local club=p.ClubMembership or{};local onboarding=p.Onboarding or{};onboarding.IdentityConfigured=onboarding.IdentityConfigured==true or(onboarding.PrimaryColor and onboarding.PrimaryColor~=""and onboarding.KitStyle and onboarding.KitStyle~="")or onboarding.Complete==true;for key,value in ClubIdentityConfig.Default do if club[key]==nil or club[key]==""then club[key]=value end;if onboarding[key]==nil or onboarding[key]==""then onboarding[key]=value end end;club.KitStyle=ClubIdentityConfig.ResolveStyle(club.KitStyle);onboarding.KitStyle=ClubIdentityConfig.ResolveStyle(onboarding.KitStyle);p.ClubMembership=club;p.Onboarding=onboarding;p.Version=10;p.SchemaVersion=10;return 10 end,
	[10]=function(p:any) p.Version=11;p.SchemaVersion=11;return 11 end,
	[11]=function(p:any) p.Version=12;p.SchemaVersion=12;return 12 end,
	[12]=function(p:any) ensureMonetizationFields(p);p.Version=13;p.SchemaVersion=13;return 13 end,
	[13]=function(p:any) CampaignMigration.Normalize(p);p.Version=14;p.SchemaVersion=14;return 14 end,
	[14]=function(p:any)
		p.UIState=type(p.UIState)=="table"and p.UIState or{}
		local settings,uiSettings=PlayabilitySettingsConfig.Synchronize(p.Settings,p.UIState.Settings)
		p.Settings=settings
		p.UIState.Settings=uiSettings
		p.MatchSetup=type(p.MatchSetup)=="table"and p.MatchSetup or{}
		p.MatchSetup.MatchFormat=MatchFormatConfig.Normalize(p.MatchSetup.MatchFormat or p.MatchSetup.MatchLength)
		p.PlayabilityProgress=type(p.PlayabilityProgress)=="table"and p.PlayabilityProgress or{}
		local progress=p.PlayabilityProgress
		progress.Version=2
		progress.LegacyAccessGranted=true
		progress.CompletedMatches=math.max(3,math.floor(tonumber(progress.CompletedMatches)or 0))
		progress.FirstMatchCompleted=progress.FirstMatchCompleted==true or progress.CompletedMatches>=1
		progress.SecondMatchCompleted=progress.SecondMatchCompleted==true or progress.CompletedMatches>=2
		progress.FirstRewardGranted=true
		progress.FirstRewardCardInstanceId=tostring(progress.FirstRewardCardInstanceId or"")
		progress.FirstRewardPlayerName=tostring(progress.FirstRewardPlayerName or"")
		progress.FirstWorldCupRunCompleted=true
		p.Version=15;p.SchemaVersion=15;return 15
	end,
	[15]=function(p:any)
		p.CareerSaveSlots=PlayerCareerConfig.NormalizeSlots(p.CareerSaveSlots)
		p.Version=16;p.SchemaVersion=16;return 16
	end,
}

local function normalizePackInstances(profile:any)
	local normalized={}
	for _,legacy in profile.PackInventory or {} do
		if legacy.packInstanceId or legacy.PackInstanceId then
			if PackInstanceFactory.Hydrate(legacy) then table.insert(normalized,legacy) end
		else
			local count=math.clamp(tonumber(legacy.Count or legacy.quantity) or 1,0,25)
			local packId=legacy.packId or legacy.Id
			if not PackInstanceFactory.Create(packId,"Migration") then packId=(legacy.Rarity=="Elite" and "elite_pack" or "voltage_standard") end
			for _=1,count do local instance=PackInstanceFactory.Create(packId,"Migration",os.time());if instance then table.insert(normalized,instance) end end
		end
	end
	profile.PackInventory=normalized
end

local function normalizeCardInstances(profile:any)
	local normalized={};local used={};local referenceMap={}
	for index,legacy in profile.PlayerCardInventory or {} do
		local oldId=legacy.Id or legacy.cardInstanceId;local oldName=legacy.Name or legacy.displayName
		local instance=legacy
		if not CardInstanceFactory.Hydrate(instance) then instance=CardInstanceFactory.FromLegacy(legacy,index) end
		if used[instance.cardInstanceId] then local details=CardInstanceFactory.GetDetails(instance);if details then instance=CardInstanceFactory.Create(details) end end
		instance.location=instance.location or "club";instance.Location=instance.location
		used[instance.cardInstanceId]=true;table.insert(normalized,instance)
		if oldId then referenceMap[oldId]=instance.cardInstanceId end;if oldName then referenceMap[oldName]=instance.cardInstanceId end
	end
	profile.PlayerCardInventory=normalized
	profile.Bench=profile.Bench or {};profile.Reserves=profile.Reserves or {};profile.PlayerCardMeta=profile.PlayerCardMeta or {};profile.Formation=profile.Formation or "4-3-3"
	profile.SquadState=profile.SquadState or {startingXI=table.clone(profile.Squad),bench={},reserves=table.clone(profile.Reserves),transferList={}}
	profile.SquadState.startingXI=profile.SquadState.startingXI or {};profile.SquadState.bench=profile.SquadState.bench or {};profile.SquadState.reserves=profile.SquadState.reserves or {};profile.SquadState.transferList=profile.SquadState.transferList or {}
	for slot,reference in profile.Squad or {} do if referenceMap[reference] then profile.Squad[slot]=referenceMap[reference] end end
	for slot,reference in profile.UIState.SelectedSquad or {} do if referenceMap[reference] then profile.UIState.SelectedSquad[slot]=referenceMap[reference] end end
	local state=profile.SquadState;if state then
		for slot,reference in state.startingXI or {} do if referenceMap[reference] then state.startingXI[slot]=referenceMap[reference] end end
		for slot,reference in state.bench or {} do if referenceMap[reference] then state.bench[slot]=referenceMap[reference] end end
		for index,reference in state.reserves or {} do if referenceMap[reference] then state.reserves[index]=referenceMap[reference] end end
		for index,reference in state.transferList or {} do if referenceMap[reference] then state.transferList[index]=referenceMap[reference] end end
	end
end

local function normalizeObjectives(profile:any)
	local previous={}
	for _,objective in profile.Objectives or {} do
		-- Legacy arrays may receive reconciled fields by numeric index, so the
		-- original Id must win when it exists.
		local id=objective.Id or objective.objectiveId
		if id=="starter_build_squad" then id="build_first_xi" end
		if type(id)=="string" then previous[id]=objective end
	end
	local normalized={}
	for _,definition in ObjectiveDefinitions do
		local objective=copy(definition);local old=previous[objective.objectiveId]
		if old then
			objective.progress=math.clamp(tonumber(old.progress or old.Progress) or objective.progress,0,objective.target)
			if old.Claimed then objective.status="claimed"
			elseif old.Active then objective.status=objective.progress>=objective.target and "claimable" or "active"
			elseif old.status then objective.status=old.status end
		end
		table.insert(normalized,objective)
	end
	if profile.Onboarding and profile.Onboarding.StarterPackOpened then
		for _,objective in normalized do if objective.objectiveId=="open_first_pack" then objective.progress=1;break end end
	end
	local journeyAvailable=profile.OnboardingCompleted or (profile.Onboarding and profile.Onboarding.ObjectivesActivated)
	local activateNext=journeyAvailable
	for _,objective in normalized do
		if objective.groupId=="starter_journey" then
			if objective.status=="claimed" then activateNext=true
			elseif activateNext then objective.status=objective.progress>=objective.target and "claimable" or "active";activateNext=false
			else objective.status="locked" end
		elseif journeyAvailable and objective.status=="locked" then objective.status=objective.progress>=objective.target and "claimable" or "active" end
	end
	profile.Objectives=normalized
end

local MATCH_STAT_MODES={"Overall","Ranked","Campaign","WorldCup"}
local function ensureResultBucket(bucket:any):any
	bucket=type(bucket)=="table"and bucket or{}
	bucket.Played=math.max(0,math.floor(tonumber(bucket.Played)or 0))
	bucket.Wins=math.max(0,math.floor(tonumber(bucket.Wins)or 0))
	bucket.Draws=math.max(0,math.floor(tonumber(bucket.Draws)or 0))
	bucket.Losses=math.max(0,math.floor(tonumber(bucket.Losses)or 0))
	return bucket
end

local function applyBucketBaseline(bucket:any,wins:number,draws:number,losses:number)
	wins=math.max(0,math.floor(tonumber(wins)or 0))
	draws=math.max(0,math.floor(tonumber(draws)or 0))
	losses=math.max(0,math.floor(tonumber(losses)or 0))
	bucket.Wins=math.max(bucket.Wins,wins)
	bucket.Draws=math.max(bucket.Draws,draws)
	bucket.Losses=math.max(bucket.Losses,losses)
	bucket.Played=math.max(bucket.Played,bucket.Wins+bucket.Draws+bucket.Losses)
end

local function normalizeMatchStats(profile:any):any
	profile.MatchStats=type(profile.MatchStats)=="table"and profile.MatchStats or copy(DefaultProfile.MatchStats)
	for _,mode in MATCH_STAT_MODES do
		profile.MatchStats[mode]=ensureResultBucket(profile.MatchStats[mode])
	end
	profile.MatchStats.AppliedResults=type(profile.MatchStats.AppliedResults)=="table"and profile.MatchStats.AppliedResults or{}
	profile.MatchStats.History=type(profile.MatchStats.History)=="table"and profile.MatchStats.History or{}

	local ranked=type(profile.Ranked)=="table"and profile.Ranked or{}
	applyBucketBaseline(profile.MatchStats.Ranked,ranked.Wins,ranked.Draws,ranked.Losses)
	local completed=0
	local campaign=type(profile.CampaignProgress)=="table"and profile.CampaignProgress or{}
	for _,done in type(campaign.CompletedTeams)=="table"and campaign.CompletedTeams or{}do
		if done==true then completed+=1 end
	end
	applyBucketBaseline(profile.MatchStats.Campaign,completed,0,0)
	local worldCupTitles=0
	for _,entry in type(profile.WorldCupHistory)=="table"and profile.WorldCupHistory or{}do
		if entry.Winner~=nil and entry.Country~=nil and tostring(entry.Winner)==tostring(entry.Country)then worldCupTitles+=1 end
	end
	if worldCupTitles>0 then profile.MatchStats.WorldCup.Titles=math.max(tonumber(profile.MatchStats.WorldCup.Titles)or 0,worldCupTitles)end

	local overall=profile.MatchStats.Overall
	local played,wins,draws,losses=0,0,0,0
	for _,mode in{"Ranked","Campaign","WorldCup"}do
		local bucket=profile.MatchStats[mode]
		played+=tonumber(bucket.Played)or 0
		wins+=tonumber(bucket.Wins)or 0
		draws+=tonumber(bucket.Draws)or 0
		losses+=tonumber(bucket.Losses)or 0
	end
	overall.Played=math.max(overall.Played,played)
	overall.Wins=math.max(overall.Wins,wins)
	overall.Draws=math.max(overall.Draws,draws)
	overall.Losses=math.max(overall.Losses,losses)
	return profile.MatchStats
end

function ProfileService.new(store:any) return setmetatable({Store=store},ProfileService) end
function ProfileService:_migrate(profile:any):any
	local version=math.min(profile.Version or Config.ProfileVersion,profile.SchemaVersion or Config.ProfileVersion)
	while version<Config.ProfileVersion do local migration=migrations[version];assert(migration,"Missing profile migration from version "..version);version=migration(profile) end
	profile.Version=Config.ProfileVersion;profile.SchemaVersion=Config.ProfileVersion;if type(profile.CreatedAt)~="number" or profile.CreatedAt<=0 then profile.CreatedAt=os.time() end;profile.LastLogin=os.time();profile.OnboardingCompleted=profile.Onboarding and profile.Onboarding.Complete or profile.OnboardingCompleted or false
	if profile.Ranked.Division=="UNRANKED" and profile.Ranked.Wins+profile.Ranked.Draws+profile.Ranked.Losses==0 then profile.Ranked.Division="DIVISION 10";profile.Ranked.Rank="NEW SEASON";profile.Ranked.PlacementStatus="PLACEMENT READY" end
	local ranked=profile.Ranked;ranked.DivisionNumber=math.floor(tonumber(ranked.DivisionNumber)or tonumber(string.match(tostring(ranked.Division),"%d+"))or 10);ranked.DivisionNumber=ranked.DivisionNumber<=0 and 0 or math.clamp(ranked.DivisionNumber,1,10);ranked.Division=ranked.DivisionNumber==0 and"ELITE DIVISION"or("DIVISION "..ranked.DivisionNumber);ranked.DivisionWins=tonumber(ranked.DivisionWins)or 0;ranked.ProtectedWins=tonumber(ranked.ProtectedWins)or 0;ranked.VoltraRating=tonumber(ranked.VoltraRating)or 0;ranked.WinStreak=tonumber(ranked.WinStreak)or 0;ranked.BestWinStreak=tonumber(ranked.BestWinStreak)or ranked.WinStreak;ranked.FlawlessRuns=tonumber(ranked.FlawlessRuns)or 0;ranked.CleanSheets=tonumber(ranked.CleanSheets)or 0;ranked.BestPackRating=tonumber(ranked.BestPackRating)or 0;ranked.RequiredRP=ranked.DivisionNumber==0 and 0 or 10;ranked.PlayerStats=ranked.PlayerStats or {MatchesPlayed=0,Goals=0,Assists=0,MOTM=0,AverageRating=0,HatTricks=0,PenaltiesScored=0,FreeKickGoals=0}
	profile.RankedRun=profile.RankedRun or copy(DefaultProfile.RankedRun);local run=profile.RankedRun;run.Results=type(run.Results)=="table"and run.Results or{};run.Target=math.clamp(math.floor(tonumber(run.Target)or 7),1,20);run.Wins=0;run.Draws=0;run.Losses=0;for index=#run.Results,1,-1 do local value=tostring(run.Results[index]);if value~="Win"and value~="Draw"and value~="Loss"then table.remove(run.Results,index)end end;while#run.Results>run.Target do table.remove(run.Results,1)end;for _,value in run.Results do if value=="Win"then run.Wins+=1 elseif value=="Draw"then run.Draws+=1 elseif value=="Loss"then run.Losses+=1 end end;run.Active=#run.Results>0 and #run.Results<run.Target;run.Ended=#run.Results>=run.Target;run.RewardClaimed=run.RewardClaimed==true
	normalizeMatchStats(profile)
	profile.ProClubMembership=profile.ProClubMembership or copy(DefaultProfile.ProClubMembership);profile.ProClubsPlayer=profile.ProClubsPlayer or copy(DefaultProfile.ProClubsPlayer);profile.PlayBuilder=PlayBuilderConfig.Normalize(profile.PlayBuilder or DefaultProfile.PlayBuilder,profile.Profile and profile.Profile.Level or profile.Season and profile.Season.Level or 1)
	normalizeCardInstances(profile)
	normalizePackInstances(profile)
	profile.RewardTransactionLedger=type(profile.RewardTransactionLedger)=="table"and profile.RewardTransactionLedger or{}
	profile.InventoryGrantLedger=type(profile.InventoryGrantLedger)=="table"and profile.InventoryGrantLedger or{}
	normalizeObjectives(profile)
	if not DeveloperConfig.InfiniteCoinsEveryone and (tonumber(profile.Currency.Coins) or 0) >= EconomyConfig.MaximumCoins then
		profile.Currency.Coins = EconomyConfig.StarterCoins
	end
	if (profile.ClubMembership.Abbreviation==nil or profile.ClubMembership.Abbreviation=="") and type(profile.ClubMembership.Tag)=="string" and profile.ClubMembership.Tag~="" then profile.ClubMembership.Abbreviation=string.upper(profile.ClubMembership.Tag)end;if (profile.ClubMembership.Tag==nil or profile.ClubMembership.Tag=="") and type(profile.ClubMembership.Abbreviation)=="string" and profile.ClubMembership.Abbreviation~="" then profile.ClubMembership.Tag=string.upper(profile.ClubMembership.Abbreviation)end
	for key,value in ClubIdentityConfig.Default do if profile.ClubMembership[key]==nil or profile.ClubMembership[key]==""then profile.ClubMembership[key]=value end;if profile.Onboarding[key]==nil or profile.Onboarding[key]==""then profile.Onboarding[key]=value end end
	profile.ClubMembership.KitStyle=ClubIdentityConfig.ResolveStyle(profile.ClubMembership.KitStyle);profile.Onboarding.KitStyle=ClubIdentityConfig.ResolveStyle(profile.Onboarding.KitStyle)
	profile.UIState=profile.UIState or copy(DefaultProfile.UIState);profile.UIState.Settings=profile.UIState.Settings or {};profile.Settings=profile.Settings or{};profile.Settings,profile.UIState.Settings=PlayabilitySettingsConfig.Synchronize(profile.Settings,profile.UIState.Settings);for key,value in DefaultProfile.Settings do if profile.Settings[key]==nil and profile.UIState.Settings[key]==nil then profile.Settings[key]=copy(value);profile.UIState.Settings[key]=copy(value)end end;profile.Settings,profile.UIState.Settings=PlayabilitySettingsConfig.Synchronize(profile.Settings,profile.UIState.Settings);for _,key in{"Commentary","CommentaryLanguage","CommentaryVolume"}do profile.UIState.Settings[key]=nil;profile.Settings[key]=nil end;ensureMonetizationFields(profile)
	profile.MatchSetup=type(profile.MatchSetup)=="table"and profile.MatchSetup or copy(DefaultProfile.MatchSetup);profile.MatchSetup.MatchFormat=MatchFormatConfig.Normalize(profile.MatchSetup.MatchFormat or profile.MatchSetup.MatchLength)
	profile.CareerSaveSlots=PlayerCareerConfig.NormalizeSlots(profile.CareerSaveSlots)
	profile.PlayabilityProgress=type(profile.PlayabilityProgress)=="table"and profile.PlayabilityProgress or copy(DefaultProfile.PlayabilityProgress);local playability=profile.PlayabilityProgress;local recordedMatches=math.max(0,math.floor(tonumber(profile.MatchStats and profile.MatchStats.Overall and profile.MatchStats.Overall.Played)or 0));local legacyAccess=playability.LegacyAccessGranted==true;playability.Version=2;playability.LegacyAccessGranted=legacyAccess;playability.CompletedMatches=math.max(legacyAccess and 3 or 0,recordedMatches,math.max(0,math.floor(tonumber(playability.CompletedMatches)or 0)));playability.FirstMatchCompleted=playability.FirstMatchCompleted==true or playability.CompletedMatches>=1;playability.SecondMatchCompleted=playability.SecondMatchCompleted==true or playability.CompletedMatches>=2;playability.FirstRewardGranted=playability.FirstRewardGranted==true or legacyAccess;playability.FirstRewardCardInstanceId=tostring(playability.FirstRewardCardInstanceId or"");playability.FirstRewardPlayerName=tostring(playability.FirstRewardPlayerName or"");playability.FirstWorldCupRunCompleted=playability.FirstWorldCupRunCompleted==true or legacyAccess or(type(profile.WorldCupHistory)=="table"and#profile.WorldCupHistory>0)
	if profile.Settings.TutorialComplete ~= nil then profile.UIState.Settings.TutorialComplete = profile.Settings.TutorialComplete == true end
	if tonumber(profile.Settings.TutorialStep) then profile.UIState.Settings.TutorialStep = math.clamp(math.floor(tonumber(profile.Settings.TutorialStep) or 1), 1, 20) end
	if profile.Settings.TutorialDevice ~= nil then profile.UIState.Settings.TutorialDevice = tostring(profile.Settings.TutorialDevice or ""):sub(1, 32) end
	local _,campaignChanged=CampaignMigration.Normalize(profile)
	if DeveloperConfig.InfiniteCoinsEveryone then profile.Currency.Coins=EconomyConfig.MaximumCoins end
	return profile,campaignChanged
end
function ProfileService:Start()
	local function load(player:Player)
		local ok,raw=pcall(function()return self.Store:LoadAsync(player.UserId)end)
		if not ok or type(raw)~="table"then
			warn("[VTR PROFILE] Load failed for "..player.Name..": "..tostring(raw))
			raw=copy(DefaultProfile)
			self.Store.Sessions[player.UserId]=raw
		end
		local isNew=type(raw.CreatedAt)~="number" or raw.CreatedAt<=0
		local loadedVersion=math.min(tonumber(raw.Version)or 1,tonumber(raw.SchemaVersion)or 1)
		local migrateOk,profileOrError,campaignChanged=pcall(function()return self:_migrate(raw)end)
		if not migrateOk or type(profileOrError)~="table"then
			warn("[VTR PROFILE] Migration failed for "..player.Name..": "..tostring(profileOrError))
			raw=copy(DefaultProfile)
			self.Store.Sessions[player.UserId]=raw
			isNew=true
			profileOrError,campaignChanged=self:_migrate(raw)
		end
		local profile=profileOrError
		applyStudioDefaultTeam(profile,player)
		profile.Profile.Avatar.UserId=player.UserId
		local equipped=profile.UIState and profile.UIState.EquippedCosmetics or {}
		player:SetAttribute("VTRGoalMusic",equipped.GoalMusic or "")
		player:SetAttribute("VTRCustomGoalMusicId",equipped.CustomGoalMusicId or "")
		player:SetAttribute("VTRCustomGoalMusicStart",tonumber(equipped.CustomGoalMusicStart) or 0)
		player:SetAttribute("VTRGoalEffect",equipped.GoalEffect or "")
		player:SetAttribute("VTRCelebration",equipped.Celebration or "")
		player:SetAttribute("VTRWalkout",equipped.Walkout or "")
		player:SetAttribute("VTRBootStyle",equipped.BootStyle or "")
		player:SetAttribute("VTRVIP",profile.StoreOwnership and type(profile.StoreOwnership.GamePasses)=="table" and table.find(profile.StoreOwnership.GamePasses,"vip_pass")~=nil)
		player:SetAttribute("VTRNewProfile",isNew)
		player:SetAttribute("VTRProfileReady",true)
		if loadedVersion<Config.ProfileVersion or campaignChanged==true then self.Store:SaveAsync(player.UserId,true)end
	end
	Players.PlayerAdded:Connect(load);Players.PlayerRemoving:Connect(function(player) self.Store:Release(player.UserId) end);for _,player in Players:GetPlayers() do task.spawn(load,player) end
	game:BindToClose(function() for _,player in Players:GetPlayers() do self.Store:SaveAsync(player.UserId,true) end end)
end
function ProfileService:WaitForProfile(player:Player,timeout:number?):any?
	local deadline=os.clock()+(timeout or 8)
	local profile=self:GetProfile(player)
	while not profile and player and player.Parent==Players and os.clock()<deadline do
		task.wait(.1)
		profile=self:GetProfile(player)
	end
	return profile
end
function ProfileService:GetProfile(player:Player):any?
	if not player or player.Parent~=Players then return nil end
	local profile=self.Store:Get(player.UserId)
	if profile and DeveloperConfig.InfiniteCoinsEveryone then profile.Currency.Coins=EconomyConfig.MaximumCoins end
	return profile
end
function ProfileService:ResetProfile(player:Player):any?
	if not player or player.Parent~=Players then return nil end;local profile=copy(self.Store.Template);self.Store.Sessions[player.UserId]=profile;profile=self:_migrate(profile);applyStudioDefaultTeam(profile,player);profile.Profile.Avatar.UserId=player.UserId;player:SetAttribute("VTRNewProfile",true);self.Store:SaveAsync(player.UserId,true);return profile
end
function ProfileService:Save(player:Player,force:boolean?):boolean
	if not player or player.Parent~=Players then return false end
	return self.Store:SaveAsync(player.UserId,force==true)
end
function ProfileService:RecordMatchResult(player:Player,mode:string,resultId:string,result:string,metadata:any?):boolean
	local profile=self:GetProfile(player)
	if not profile then return false end
	mode=tostring(mode or"")
	if mode~="Ranked"and mode~="Campaign"and mode~="WorldCup"then return false end
	result=tostring(result or"")
	if result=="ForfeitWin"or result=="Won"or result=="Victory"then result="Win"end
	if result=="ForfeitLoss"or result=="Lost"or result=="Defeat"then result="Loss"end
	if result=="Tie"then result="Draw"end
	if result~="Win"and result~="Draw"and result~="Loss"then return false end
	local stats=normalizeMatchStats(profile)
	resultId=tostring(resultId or"")
	if resultId==""then
		resultId=mode..":"..tostring(player.UserId)..":"..tostring(os.time())..":"..tostring((stats[mode].Played or 0)+1)
	end
	local key=mode..":"..resultId
	if stats.AppliedResults[key]==true then return false end
	stats.AppliedResults[key]=true
	for _,bucketName in{mode,"Overall"}do
		local bucket=stats[bucketName]
		bucket.Played=(tonumber(bucket.Played)or 0)+1
		if result=="Win"then bucket.Wins=(tonumber(bucket.Wins)or 0)+1 elseif result=="Draw"then bucket.Draws=(tonumber(bucket.Draws)or 0)+1 else bucket.Losses=(tonumber(bucket.Losses)or 0)+1 end
	end
	profile.PlayabilityProgress=type(profile.PlayabilityProgress)=="table"and profile.PlayabilityProgress or copy(DefaultProfile.PlayabilityProgress)
	local playability=profile.PlayabilityProgress
	playability.Version=2
	playability.CompletedMatches=math.max(tonumber(playability.CompletedMatches)or 0,tonumber(stats.Overall.Played)or 0)
	playability.FirstMatchCompleted=playability.CompletedMatches>=1
	playability.SecondMatchCompleted=playability.CompletedMatches>=2
	if mode=="Campaign"then
		profile.CampaignProgress=type(profile.CampaignProgress)=="table"and profile.CampaignProgress or{UnlockedDifficulty=1,CompletedTeams={},RewardsClaimed={}}
		profile.CampaignProgress.Wins=stats.Campaign.Wins
		profile.CampaignProgress.Draws=stats.Campaign.Draws
		profile.CampaignProgress.Losses=stats.Campaign.Losses
	elseif mode=="WorldCup"then
		stats.WorldCup.Titles=tonumber(stats.WorldCup.Titles)or 0
	end
	local history=stats.History
	table.insert(history,1,{Id=key,Mode=mode,Result=result,At=os.time(),Meta=type(metadata)=="table"and copy(metadata)or nil})
	while#history>100 do table.remove(history)end
	if self.Save then self:Save(player,true)end
	return true
end
function ProfileService:GetClientData(player:Player):any? local p=self:GetProfile(player);if not p then return nil end;return {Username=player.Name,DisplayName=player.DisplayName,Level=p.Profile.Level,XP=p.Profile.XP,SelectedClub=p.Profile.SelectedClub,ClubIdentity=table.clone(p.ClubMembership),Avatar={UserId=player.UserId,HeadshotType=p.Profile.Avatar.HeadshotType,OutfitId=p.Profile.Avatar.OutfitId}} end
function ProfileService:GetVersion():number return Config.ProfileVersion end
return ProfileService
