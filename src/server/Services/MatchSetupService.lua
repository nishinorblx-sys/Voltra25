local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))
local MATCHUP_PANEL_DELAY = 0.85
--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local MarketplaceService=game:GetService("MarketplaceService")
local RunService=game:GetService("RunService")
local TeleportService=game:GetService("TeleportService")
local MatchConfig=require(ReplicatedStorage.VTR.Shared.MatchConfig)
local VTRLiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local WorldCupConfig=require(ReplicatedStorage.VTR.Shared.WorldCupConfig)
local WorldCupQuestConfig=require(ReplicatedStorage.VTR.Shared.WorldCupQuestConfig)
local FormationConfig=require(ReplicatedStorage.VTR.Shared.FormationConfig)
local TeamDatabase=require(script.Parent.Parent.Data.TeamDatabase)
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local ObjectiveService=require(script.Parent.ObjectiveService)
local Service={};Service.__index=Service


local function contains(list:any,value:any):boolean return table.find(list,value)~=nil end
local function packIdFor(id:string?):string return Catalog.Packs[id or""] and (id :: string) or"bronze_pack"end
local function stadium(id:string):any?for _,item in MatchConfig.Stadiums do if item.Id==id then return item end end;return nil end
local function kit(team:any,name:string):any?return team and team.kits[name]or nil end
local function colorDistance(first:string,second:string):number local a,b=Color3.fromHex(first),Color3.fromHex(second);return math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B)end
local function colorToHex(color:any,fallback:string):string
	if typeof(color)=="Color3"then
		return string.format("%02X%02X%02X",math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5))
	end
	if type(color)=="string"and color~=""then return color:gsub("#","")end
	return fallback
end
local CONTINENTS={
	Europe={["England"]=true,["France"]=true,["Spain"]=true,["Germany"]=true,["Italy"]=true,["Portugal"]=true,["Netherlands"]=true,["Belgium"]=true,["Croatia"]=true,["Switzerland"]=true,["Denmark"]=true,["Austria"]=true,["Sweden"]=true,["Turkey"]=true,["Ukraine"]=true,["Serbia"]=true,["Wales"]=true,["Poland"]=true,["Hungary"]=true,["Russia"]=true,["Norway"]=true,["Czech Republic"]=true,["Scotland"]=true,["Slovakia"]=true,["Greece"]=true,["Romania"]=true,["Slovenia"]=true,["Ireland"]=true,["Finland"]=true,["Bosnia and Herzegovina"]=true,["Albania"]=true,["North Macedonia"]=true,["Georgia"]=true,["Montenegro"]=true,["Iceland"]=true,["Luxembourg"]=true,["Armenia"]=true,["Belarus"]=true,["Kosovo"]=true,["Estonia"]=true,["Latvia"]=true,["Lithuania"]=true,["Cyprus"]=true,["Moldova"]=true,["Malta"]=true,["Andorra"]=true,["Liechtenstein"]=true,["San Marino"]=true,["Monaco"]=true,["Vatican City"]=true,["Bulgaria"]=true},
	["South America"]={["Argentina"]=true,["Brazil"]=true,["Uruguay"]=true,["Colombia"]=true,["Ecuador"]=true,["Venezuela"]=true,["Paraguay"]=true,["Bolivia"]=true,["Chile"]=true,["Peru"]=true,["Suriname"]=true,["Guyana"]=true},
	Africa={["Morocco"]=true,["Senegal"]=true,["Egypt"]=true,["Nigeria"]=true,["Algeria"]=true,["Tunisia"]=true,["Ivory Coast"]=true,["Cameroon"]=true,["Mali"]=true,["South Africa"]=true,["Burkina Faso"]=true,["Democratic Republic of the Congo"]=true,["Ghana"]=true,["Cabo Verde"]=true,["Uganda"]=true,["Guinea"]=true,["Equatorial Guinea"]=true,["Zambia"]=true,["Benin"]=true,["Libya"]=true,["Angola"]=true,["Kenya"]=true,["Mozambique"]=true,["Madagascar"]=true,["Mauritania"]=true,["Guinea-Bissau"]=true,["Namibia"]=true,["Comoros"]=true,["Tanzania"]=true,["Sierra Leone"]=true,["Zimbabwe"]=true,["Malawi"]=true,["Gambia"]=true,["Republic of the Congo"]=true,["Sudan"]=true,["Rwanda"]=true,["Niger"]=true,["Niamey"]=true,["Liberia"]=true,["Ethiopia"]=true,["Burundi"]=true,["Botswana"]=true,["Eswatini"]=true,["Lesotho"]=true,["South Sudan"]=true,["Central African Republic"]=true,["Chad"]=true,["Mauritius"]=true,["Seychelles"]=true,["Djibouti"]=true,["Eritrea"]=true,["Somalia"]=true,["Togo"]=true,["Gabon"]=true},
	Asia={["Japan"]=true,["Iran"]=true,["South Korea"]=true,["Saudi Arabia"]=true,["Iraq"]=true,["Qatar"]=true,["Uzbekistan"]=true,["United Arab Emirates"]=true,["Jordan"]=true,["Bahrain"]=true,["China"]=true,["Oman"]=true,["Syria"]=true,["Palestine"]=true,["Thailand"]=true,["Kuwait"]=true,["Vietnam"]=true,["Lebanon"]=true,["Tajikistan"]=true,["Kyrgyzstan"]=true,["Kazakhstan"]=true,["India"]=true,["Indonesia"]=true,["Malaysia"]=true,["Philippines"]=true,["Singapore"]=true,["Turkmenistan"]=true,["Maldives"]=true,["Pakistan"]=true,["Myanmar"]=true,["Yemen"]=true,["Taiwan"]=true,["Cambodia"]=true,["Laos"]=true,["Nepal"]=true,["Bangladesh"]=true,["Sri Lanka"]=true,["Mongolia"]=true,["Brunei"]=true,["Timor-Leste"]=true,["Bhutan"]=true,["North Korea"]=true},
	CONCACAF={["Mexico"]=true,["United States"]=true,["Canada"]=true,["Panama"]=true,["Costa Rica"]=true,["Jamaica"]=true,["Honduras"]=true,["El Salvador"]=true,["Haiti"]=true,["Trinidad and Tobago"]=true,["Guatemala"]=true,["Nicaragua"]=true,["Dominican Republic"]=true,["Cuba"]=true,["Bahamas"]=true,["Barbados"]=true,["Belize"]=true,["Antigua and Barbuda"]=true,["Dominica"]=true,["Grenada"]=true,["Saint Lucia"]=true,["Saint Kitts and Nevis"]=true,["Saint Vincent and the Grenadines"]=true,["Puerto Rico"]=true},
	Oceania={["Australia"]=true,["New Zealand"]=true,["Papua New Guinea"]=true,["Fiji"]=true,["Solomon Islands"]=true,["Vanuatu"]=true,["Samoa"]=true,["Tonga"]=true,["Kiribati"]=true,["Tuvalu"]=true,["Nauru"]=true,["Micronesia"]=true,["Marshall Islands"]=true,["Palau"]=true},
}
local FORMER_CHAMPIONS={Argentina=true,Brazil=true,France=true,England=true,Germany=true,Italy=true,Spain=true,Uruguay=true}
local HOST_NATION="United States"
local DEFENDING_CHAMPION="Argentina"
local function continentOf(country:string):string
	for continent,set in CONTINENTS do if set[country]then return continent end end
	return"Other"
end
local function questProfile(profile:any):any
	profile.WorldCupQuests=type(profile.WorldCupQuests)=="table"and profile.WorldCupQuests or{Progress={},Claimed={}}
	profile.WorldCupQuests.Progress=type(profile.WorldCupQuests.Progress)=="table"and profile.WorldCupQuests.Progress or{}
	profile.WorldCupQuests.Claimed=type(profile.WorldCupQuests.Claimed)=="table"and profile.WorldCupQuests.Claimed or{}
	profile.WorldCupQuests.Career=type(profile.WorldCupQuests.Career)=="table"and profile.WorldCupQuests.Career or{ManagedNations={},ManagedContinents={},TitleNations={},TitleContinents={},SemiContinents={},ContinentsDefeated={}}
	for _,key in{"ManagedNations","ManagedContinents","TitleNations","TitleContinents","SemiContinents","ContinentsDefeated","NationTitles","TierTitles","SemiNationsByContinent","FinalNationsNever"}do
		profile.WorldCupQuests.Career[key]=type(profile.WorldCupQuests.Career[key])=="table"and profile.WorldCupQuests.Career[key]or{}
	end
	return profile.WorldCupQuests
end
local COUNTRY_ALIASES={Czechia="Czech Republic",["Trinidad & Tobago"]="Trinidad and Tobago",["Curaçao"]="Curacao",Curacao="Curacao",USA="United States",US="United States"}
local function canonicalCountry(country:any):string return COUNTRY_ALIASES[tostring(country or"")]or tostring(country or"")end
local function listHas(list:any,value:any):boolean
	local target=canonicalCountry(value)
	for _,candidate in type(list)=="table"and list or{}do if canonicalCountry(candidate)==target then return true end end
	return false
end
local function continentHas(list:any,value:string):boolean
	for _,candidate in type(list)=="table"and list or{}do if tostring(candidate)==value then return true end end
	return false
end
local function questContinent(title:any):string?
	local lower=string.lower(tostring(title or""))
	if string.find(lower,"european",1,true)then return"Europe"end
	if string.find(lower,"south american",1,true)then return"South America"end
	if string.find(lower,"african",1,true)then return"Africa"end
	if string.find(lower,"asian",1,true)then return"Asia"end
	if string.find(lower,"concacaf",1,true)or string.find(lower,"north or central american",1,true)then return"CONCACAF"end
	if string.find(lower,"oceanian",1,true)then return"Oceania"end
	return nil
end
function Service.new(profiles:any,publish:(Player,string,any)->(),progression:any,runtime:any,rankedSquads:any?)
	local self=setmetatable({Profiles=profiles,Publish=publish,Progression=progression,Runtime=runtime,RankedSquads=rankedSquads,SoloTeleportConnections={},WorldCupTeleportLocks={},WorldCupStartLocks={}},Service)
	task.defer(function()
		for _,player in Players:GetPlayers()do self:HandleSoloCampaignTeleport(player)end
		table.insert(self.SoloTeleportConnections,Players.PlayerAdded:Connect(function(player)task.defer(function()self:HandleSoloCampaignTeleport(player)end)end))
	end)
	return self
end
function Service:_ensure(profile:any):any local setup=profile.MatchSetup;if not setup or not TeamDatabase.Get(setup.HomeTeamId)or not TeamDatabase.Get(setup.AwayTeamId)or(setup.HomeTeamId==setup.AwayTeamId and setup.MatchType~="Friendly")then local home,away=TeamDatabase.Teams[1],TeamDatabase.Teams[2];setup={MatchLength=6,Difficulty="Professional",MatchType="Objective Match",HomeTeamId=home.teamId,AwayTeamId=away.teamId,HomeKit="Home",AwayKit="Away",StadiumId="voltra_arena",Weather="Clear",Time="Evening",Completed=false,SavedAt=0,KitConflict=false,CampaignTeamId="",CampaignTier=0,CampaignReplay=false};profile.MatchSetup=setup end;setup.CampaignTeamId=setup.CampaignTeamId or"";setup.CampaignTier=tonumber(setup.CampaignTier)or 0;setup.CampaignReplay=setup.CampaignReplay==true;return setup end
function Service:_validate(setup:any):(boolean,string)
	if not contains(MatchConfig.MatchLengths,setup.MatchLength)then return false,"Invalid match length."end;if not contains(MatchConfig.Difficulties,setup.Difficulty)then return false,"Invalid difficulty."end;if not contains(MatchConfig.MatchTypes,setup.MatchType)then return false,"Invalid match type."end;if not contains(MatchConfig.Weather,setup.Weather)or not contains(MatchConfig.Times,setup.Time)then return false,"Invalid presentation settings."end
	local home,away=TeamDatabase.Get(setup.HomeTeamId),TeamDatabase.Get(setup.AwayTeamId);if not home or not away then return false,"Select two valid teams."end;if home.teamId==away.teamId and setup.MatchType~="Friendly"then return false,"Mirror matches are only available in Friendly mode."end;if not kit(home,setup.HomeKit)or not kit(away,setup.AwayKit)then return false,"Invalid kit selection."end;local venue=stadium(setup.StadiumId);if not venue or not contains(venue.WeatherSupport,setup.Weather)then return false,"Selected stadium does not support this weather."end;return true,"Match setup valid."
end
function Service:_isCampaignMatch(setup:any):boolean
	return type(setup)=="table" and type(setup.CampaignTeamId)=="string" and setup.CampaignTeamId~=""
end

function Service:_worldCupMatchFixtureFromEnded(state:any,ended:any):any?
	local pending=ended and ended.WorldCupPendingMatch or state.PendingMatch
	local snapshot=type(pending)=="table"and pending or ended and ended.WorldCupFixtureSnapshot
	local fixture=type(snapshot)=="table"and snapshot or state.NextFixture
	if type(fixture)~="table"then return nil end
	if state.Stage=="Group"then
		self:_worldCupEnsureFixtureDays(state)
		local groupName=tostring(fixture.Group or state.UserGroup or"")
		local matchday=tonumber(fixture.Matchday)
		for _,candidate in ipairs(state.Fixtures and state.Fixtures[groupName]or{})do
			if candidate.Home==fixture.Home and candidate.Away==fixture.Away and (not matchday or tonumber(candidate.Matchday)==matchday)then
				return candidate
			end
		end
	elseif state.Knockout and type(state.Knockout.Fixtures)=="table"then
		local round=tonumber(fixture.Round)or tonumber(state.Knockout.Round)
		for _,candidate in ipairs(state.Knockout.Fixtures)do
			if candidate.Home==fixture.Home and candidate.Away==fixture.Away and (not round or tonumber(candidate.Round)==round)then
				return candidate
			end
		end
	end
	return self:_worldCupCanonicalFixture(state,fixture)
end

function Service:_worldCupPendingMatchId(player:Player,state:any,fixture:any):string
	local parts={
		tostring(player and player.UserId or 0),
		tostring(state and state.CreatedAt or 0),
		tostring(fixture and fixture.Home or ""),
		tostring(fixture and fixture.Away or ""),
		tostring(fixture and (fixture.Group or fixture.Round or "") or ""),
		tostring(fixture and (fixture.Matchday or "") or ""),
		tostring(os.time()),
	}
	return table.concat(parts,"|")
end

function Service:_worldCupStorePendingMatch(player:Player,profile:any,state:any,fixture:any,opponent:string):any?
	if type(profile)~="table"or type(state)~="table"or type(fixture)~="table"then return nil end
	local pending={
		Id=self:_worldCupPendingMatchId(player,state,fixture),
		Home=fixture.Home,
		Away=fixture.Away,
		Group=fixture.Group,
		Matchday=fixture.Matchday,
		Round=fixture.Round,
		Stage=state.Stage,
		SelectedCountry=state.SelectedCountry,
		Opponent=opponent,
		RuntimeHomeIsSelected=true,
		StartedAt=os.time(),
	}
	profile.WorldCupPendingMatch=pending
	state.PendingMatch=pending
	state.PendingMatchId=pending.Id
	if self.Profiles.Save then self.Profiles:Save(player,true)end
	player:SetAttribute("VTRWorldCupPendingId",pending.Id)
	return pending
end

function Service:_worldCupReadEndedScore(ended:any):(number?,number?)
	local home=tonumber(ended and ended.World and ended.World.HomeScore and ended.World.HomeScore.Value)or tonumber(ended and(ended.HomeScore or ended.homeScore or ended.HomeGoals or ended.homeGoals or ended.Home or ended.home))
	local away=tonumber(ended and ended.World and ended.World.AwayScore and ended.World.AwayScore.Value)or tonumber(ended and(ended.AwayScore or ended.awayScore or ended.AwayGoals or ended.awayGoals or ended.Away or ended.away))
	return home,away
end

function Service:_commitWorldCupPlayedMatch(player:Player,ended:any):boolean
	ended=type(ended)=="table"and ended or{}
	if ended.WorldCupResultCommitted==true then return false end
	local current=self.Profiles:GetProfile(player);if not current or type(current.WorldCup)~="table"then return false end
	local pending=type(ended.WorldCupPendingMatch)=="table"and ended.WorldCupPendingMatch or type(current.WorldCupPendingMatch)=="table"and current.WorldCupPendingMatch or type(current.WorldCup.PendingMatch)=="table"and current.WorldCup.PendingMatch or nil
	if pending then ended.WorldCupPendingMatch=pending end
	local currentFixture=self:_worldCupMatchFixtureFromEnded(current.WorldCup,ended)
	if type(currentFixture)~="table"then return false end
	local fixtureKey=tostring(currentFixture.Home or"").."|"..tostring(currentFixture.Away or"").."|"..tostring(currentFixture.Group or current.WorldCup.UserGroup or"").."|"..tostring(currentFixture.Matchday or currentFixture.Round or current.WorldCup.Stage or"")
	local resultKey=tostring(pending and pending.Id or fixtureKey)
	current.WorldCup.ResultLedger=type(current.WorldCup.ResultLedger)=="table"and current.WorldCup.ResultLedger or{}
	if current.WorldCup.ResultLedger[resultKey]==true or(currentFixture.UserPlayedResultKey==resultKey and currentFixture.Played==true)or currentFixture.Played==true then
		current.WorldCup.NextFixture=currentFixture
		if current.WorldCup.Stage=="Group"then
			self:_worldCupRepairGroupNextFixture(current.WorldCup)
		else
			self:_worldCupPrepareNextKnockout(current.WorldCup)
		end
		current.WorldCupPendingMatch=nil
		current.WorldCup.PendingMatch=nil
		current.WorldCup.PendingMatchId=nil
		ended.WorldCupResultCommitted=true
		player:SetAttribute("VTRWorldCupPendingId",nil)
		if self.Profiles.Save then self.Profiles:Save(player,true)end
		if self.Publish then self.Publish(player,"WorldCup",current.WorldCup)end
		return false
	end
	local selectedCountry=tostring((pending and pending.SelectedCountry)or current.WorldCup.SelectedCountry or"")
	local readHomeScore,readAwayScore=self:_worldCupReadEndedScore(ended)
	if readHomeScore==nil or readAwayScore==nil then return false end
	current.WorldCup.NextFixture=currentFixture
	local userGoalsFor,userGoalsAgainst=readHomeScore,readAwayScore
	local homeScore,awayScore=readHomeScore,readAwayScore
	if pending and pending.RuntimeHomeIsSelected~=false then
		if currentFixture.Home==selectedCountry then
			homeScore=userGoalsFor
			awayScore=userGoalsAgainst
		else
			homeScore=userGoalsAgainst
			awayScore=userGoalsFor
		end
	elseif currentFixture.Home~=selectedCountry then
		homeScore=readAwayScore
		awayScore=readHomeScore
	end
	currentFixture.UserPlayedResultKey=resultKey
	current.WorldCup.ResultLedger[resultKey]=true
	current.WorldCup.PlayedMatches=(tonumber(current.WorldCup.PlayedMatches)or 0)+1
	current.WorldCup.UserGoalsFor=(tonumber(current.WorldCup.UserGoalsFor)or 0)+userGoalsFor
	current.WorldCup.UserGoalsAgainst=(tonumber(current.WorldCup.UserGoalsAgainst)or 0)+userGoalsAgainst
	local userResult=(homeScore==awayScore and"Draw")or(currentFixture.Home==selectedCountry and(homeScore>awayScore and"Win"or"Loss")or(awayScore>homeScore and"Win"or"Loss"))
	if self.Profiles.RecordMatchResult then
		self.Profiles:RecordMatchResult(player,"WorldCup",resultKey,userResult,{Country=selectedCountry,Opponent=tostring(pending and pending.Opponent or""),Stage=current.WorldCup.Stage,Score=tostring(userGoalsFor).."-"..tostring(userGoalsAgainst)})
	end
	self:_worldCupAdvanceAfterMatch(current.WorldCup,homeScore,awayScore)
	current.WorldCupPendingMatch=nil
	current.WorldCup.PendingMatch=nil
	current.WorldCup.PendingMatchId=nil
	self:_archiveWorldCup(current)
	if self.Profiles.Save then self.Profiles:Save(player,true)end
	self.Publish(player,"Progression",self.Progression:GetClientData(player))
	self.Publish(player,"WorldCup",current.WorldCup)
	player:SetAttribute("VTRLastWorldCupCommittedAt",os.time())
	player:SetAttribute("VTRLastWorldCupCommittedScore",tostring(readHomeScore).."-"..tostring(readAwayScore))
	player:SetAttribute("VTRWorldCupPendingId",nil)
	if self._clearWorldCupRuntimeResult then self:_clearWorldCupRuntimeResult(player)end
	ended.WorldCupResultCommitted=true
	return true
end

function Service:_grantWorldCupMatchReward(player:Player,ended:any):any?
	if ended.WorldCupRewardGranted==true then return ended.WorldCupRewardPayload end
	local homeScore=tonumber(ended and ended.World and ended.World.HomeScore and ended.World.HomeScore.Value)or 0
	local awayScore=tonumber(ended and ended.World and ended.World.AwayScore and ended.World.AwayScore.Value)or 0
	local won=homeScore>awayScore
	local drew=homeScore==awayScore
	local payload={
		Title=won and"WORLD CUP WIN"or drew and"WORLD CUP DRAW"or"WORLD CUP MATCH",
		Coins=won and 900 or drew and 550 or 400,
		XP=won and 160 or drew and 110 or 80,
	}
	local reward=self.Progression and self.Progression.GrantMatchRewards and self.Progression:GrantMatchRewards(player,payload)or payload
	ended.WorldCupRewardGranted=true
	ended.WorldCupRewardPayload=reward
	player:SetAttribute("VTRLastWorldCupRewardAt",os.time())
	return reward
end

function Service:_clearWorldCupRuntimeResult(player:Player)
	player:SetAttribute("VTRWorldCupResultPending",nil)
	player:SetAttribute("VTRWorldCupResultHomeScore",nil)
	player:SetAttribute("VTRWorldCupResultAwayScore",nil)
	player:SetAttribute("VTRWorldCupResultPendingId",nil)
	player:SetAttribute("VTRWorldCupResultAt",nil)
end

function Service:_consumeWorldCupRuntimeResult(player:Player,profile:any?):boolean
	if player:GetAttribute("VTRWorldCupResultPending")~=true then return false end
	local current=profile or self.Profiles:GetProfile(player)
	if not current or type(current.WorldCup)~="table"then return false end
	local homeScore=tonumber(player:GetAttribute("VTRWorldCupResultHomeScore"))
	local awayScore=tonumber(player:GetAttribute("VTRWorldCupResultAwayScore"))
	if homeScore==nil or awayScore==nil then return false end
	local pending=type(current.WorldCupPendingMatch)=="table"and current.WorldCupPendingMatch or type(current.WorldCup.PendingMatch)=="table"and current.WorldCup.PendingMatch or nil
	local ended={
		HomeScore=homeScore,
		AwayScore=awayScore,
		WorldCupPendingMatch=pending,
		WorldCupFixtureSnapshot=pending or current.WorldCup.NextFixture,
	}
	local committed=self:_commitWorldCupPlayedMatch(player,ended)
	if committed or ended.WorldCupResultCommitted==true then
		self:_clearWorldCupRuntimeResult(player)
	end
	return committed
end

function Service:_commitCampaignWin(player:Player,teamId:string,tierIndex:number,replay:boolean?):any?
	if replay==true or type(teamId)~="string"or teamId==""then return nil end
	local current=self.Profiles:GetProfile(player);if not current then return nil end
	local tier=VTRLiteConfig.CampaignDifficulties[math.clamp(tonumber(tierIndex)or 1,1,#VTRLiteConfig.CampaignDifficulties)]
	local progress=current.CampaignProgress or{UnlockedDifficulty=1,CompletedTeams={},RewardsClaimed={}};current.CampaignProgress=progress;progress.CompletedTeams=progress.CompletedTeams or{};progress.RewardsClaimed=progress.RewardsClaimed or{}
	local alreadyCompleted=progress.CompletedTeams[teamId]==true
	local rewardKey="campaign_"..tostring(teamId)
	local packsGranted=0
	local packId=packIdFor(tier and tier.PackId or"bronze_pack")
	if not alreadyCompleted and progress.RewardsClaimed[rewardKey]~=true then
		progress.RewardsClaimed[rewardKey]=true
		if self.Progression and self.Progression.Inventory and self.Progression.Inventory:AddPack(player,packId,packId,"Campaign",1)then packsGranted+=1 end
		if player and typeof(player)=="Instance"and player:IsA("Player")then VTRPendingPackAnimation.Queue(player,packId)end
	end
	progress.CompletedTeams[teamId]=true
	local cleared=0;local tierId=tier and tier.Id or"";for completedId,done in progress.CompletedTeams do if done and string.find(tostring(completedId),tierId,1,true)then cleared+=1 end end
	if cleared>=5 and math.clamp(tonumber(tierIndex)or 1,1,#VTRLiteConfig.CampaignDifficulties)>=(tonumber(progress.UnlockedDifficulty)or 1)then progress.UnlockedDifficulty=math.min(#VTRLiteConfig.CampaignDifficulties,(tonumber(tierIndex)or 1)+1)end
	local firstTierClear=cleared>=5
	local tierClearKey="campaign_tier_clear_"..tostring(tierId)
	local bonusGranted=false
	local bonusPackId=packIdFor(tier and tier.TierClearPackId or"voltra_pack")
	local bonusPackName=tier and tier.TierClearReward or"Voltra Pack"
	if firstTierClear and progress.RewardsClaimed[tierClearKey]~=true then
		progress.RewardsClaimed[tierClearKey]=true
		if self.Progression and self.Progression.Inventory and self.Progression.Inventory:AddPack(player,bonusPackId,bonusPackName,"CampaignTierClear",1)then packsGranted+=1;bonusGranted=true end
		if player and typeof(player)=="Instance"and player:IsA("Player")then VTRPendingPackAnimation.Queue(player,bonusPackId)end
	end
	if self.Profiles.Save then self.Profiles:Save(player,true)end
	self.Publish(player,"Progression",self.Progression:GetClientData(player))
	if alreadyCompleted and packsGranted<=0 then return nil end
	return{Title=firstTierClear and"CAMPAIGN TIER CLEAR"or"CAMPAIGN CLEAR",Coins=0,XP=0,Pack=(tier and tier.Reward or"Campaign Pack")..(bonusGranted and(" + "..bonusPackName)or""),BonusPack=bonusGranted and string.upper(bonusPackName)or nil,VoltraPack=bonusPackId=="voltra_pack",LeagueClear=bonusGranted,PackId=packId,BonusPackId=bonusGranted and bonusPackId or nil,Packs=packsGranted}
end

function Service:_returnedMatchIsWin(ended:any,setup:any):boolean
	if type(ended)=="table" then
		local result=tostring(ended.Result or ended.result or ended.Outcome or ended.outcome or ended.MatchResult or ended.matchResult or "")
		if result=="Win" or result=="Won" or result=="Victory" or result=="ForfeitWin" then
			return true
		end

		local home=tonumber(ended.HomeScore or ended.homeScore or ended.HomeGoals or ended.homeGoals or ended.Home or ended.home)
		local away=tonumber(ended.AwayScore or ended.awayScore or ended.AwayGoals or ended.awayGoals or ended.Away or ended.away)
		local side=tostring(ended.PlayerSide or ended.playerSide or ended.UserSide or ended.userSide or setup.PlayerSide or setup.UserSide or "Home")

		if home and away then
			if side=="Away" then
				return away>home
			end

			return home>away
		end
	end

	return false
end

function Service:_campaignResultFromScores(home:number?,away:number?,side:string?):string?
	if home==nil or away==nil then return nil end
	side=tostring(side or"Home")
	if home==away then return"Draw"end
	if side=="Away"then return away>home and"Win"or"Loss"end
	return home>away and"Win"or"Loss"
end

function Service:_recordCampaignMatchResult(player:Player,setup:any,ended:any,result:string?):boolean
	if not self.Profiles or not self.Profiles.RecordMatchResult or not self:_isCampaignMatch(setup)then return false end
	local home=tonumber(ended and ended.World and ended.World.HomeScore and ended.World.HomeScore.Value)or tonumber(ended and(ended.HomeScore or ended.homeScore or ended.HomeGoals or ended.homeGoals or ended.Home or ended.home))
	local away=tonumber(ended and ended.World and ended.World.AwayScore and ended.World.AwayScore.Value)or tonumber(ended and(ended.AwayScore or ended.awayScore or ended.AwayGoals or ended.awayGoals or ended.Away or ended.away))
	local side=tostring(ended and(ended.PlayerSide or ended.playerSide or ended.UserSide or ended.userSide)or setup.PlayerSide or setup.UserSide or"Home")
	result=result or self:_campaignResultFromScores(home,away,side)
	if not result then return false end
	local resultId=tostring(ended and(ended.ResultId or ended.MatchId)or setup.ResultId or setup.MatchId or "")
	if resultId==""then
		resultId=table.concat({tostring(player.UserId),tostring(setup.CampaignTeamId or""),tostring(setup.CampaignTier or 1),tostring(setup.SavedAt or 0),tostring(home or""),tostring(away or"")},"|")
	end
	return self.Profiles:RecordMatchResult(player,"Campaign",resultId,result,{TeamId=setup.CampaignTeamId,Tier=setup.CampaignTier,Score=tostring(home or 0).."-"..tostring(away or 0)})
end

function Service:_commitReturnedSoloMatch(player:Player,profile:any):boolean
	if not player or not profile then
		return false
	end

	local setup=profile.MatchSetup
	if type(setup)~="table" then
		return false
	end

	local ended=setup.EndedMatch or setup.CompletedMatch or setup.MatchResult or setup.ResultPayload or setup.LastResult or setup

	if setup.Completed~=true and setup.ResultCommitted~=false and type(setup.EndedMatch)~="table" and type(setup.CompletedMatch)~="table" and type(setup.MatchResult)~="table" and type(setup.ResultPayload)~="table" then
		return false
	end

	local changed=false
	local matchType=tostring(setup.MatchType or setup.MatchMode or setup.Mode or setup.Type or "")
	local teleportMode=tostring(setup.TeleportMatchMode or setup.ReturnMatchMode or "")

	if type(profile.WorldCupPendingMatch)=="table"then ended.WorldCupPendingMatch=ended.WorldCupPendingMatch or profile.WorldCupPendingMatch end
	if setup.WorldCup==true or type(profile.WorldCupPendingMatch)=="table"or matchType=="WorldCup" or matchType=="World Cup" or teleportMode=="WorldCupSolo" or matchType=="WorldCupSolo" then
		changed=self:_commitWorldCupPlayedMatch(player,ended) or changed
	end

	if self:_isCampaignMatch(setup) then
		local resultChanged=self:_recordCampaignMatchResult(player,setup,ended,nil)
		changed=resultChanged or changed
	end

	if self:_isCampaignMatch(setup) and self:_returnedMatchIsWin(ended,setup) then
		changed=self:_commitCampaignWin(player,tostring(setup.CampaignTeamId or ""),tonumber(setup.CampaignTier) or 1,setup.CampaignReplay==true) or changed
	end

	if changed then
		setup.Completed=false
		setup.ResultCommitted=true
		setup.EndedMatch=nil
		setup.CompletedMatch=nil
		setup.MatchResult=nil
		setup.ResultPayload=nil
		setup.LastResult=nil
		setup.SavedAt=os.time()

		if self.Publish then
			pcall(function()
				local vtrProgressionData=self.Progression and self.Progression.GetClientData and self.Progression:GetClientData(player) or nil;if vtrProgressionData then self.Publish(player,"Progression",vtrProgressionData) end
			end)
			pcall(function()
				self.Publish(player,"MatchSetup",setup)
			end)
			pcall(function()
				self.Publish(player,"WorldCup",profile.WorldCup)
			end)
		end
	end

	return changed
end


local function clonePracticePlayer(player:any):any?
	if type(player)~="table"then return nil end
	local copy=table.clone(player)
	if type(player.appearance)=="table"then copy.appearance=table.clone(player.appearance)end
	if type(player.mainStats)=="table"then copy.mainStats=table.clone(player.mainStats)end
	if type(player.detailedStats)=="table"then copy.detailedStats=table.clone(player.detailedStats)end
	if type(player.positions)=="table"then copy.positions=table.clone(player.positions)end
	return copy
end

local function playerHasPosition(player:any,position:string):boolean
	if type(player)~="table"then return false end
	if player.bestPosition==position or player.Position==position or player.PositionSlot==position or player.FormationSlot==position or player.SquadSlot==position then return true end
	local positions=type(player.positions)=="table"and player.positions or{}
	return table.find(positions,position)~=nil
end

local function choosePracticeStriker(roster:any):any?
	local starting=type(roster)=="table"and type(roster.StartingXI)=="table"and roster.StartingXI or{}
	for _,candidate in starting do if candidate and(candidate.PositionSlot=="ST"or candidate.FormationSlot=="ST"or candidate.SquadSlot=="ST")then return clonePracticePlayer(candidate)end end
	for _,candidate in starting do if playerHasPosition(candidate,"ST")then return clonePracticePlayer(candidate)end end
	for _,candidate in starting do if candidate and not playerHasPosition(candidate,"GK")then return clonePracticePlayer(candidate)end end
	return nil
end

local function choosePracticeShooter(roster:any,payload:any):any?
	local starting=type(roster)=="table"and type(roster.StartingXI)=="table"and roster.StartingXI or{}
	local requestedId=type(payload)=="table"and tostring(payload.CardInstanceId or payload.CardId or"")or""
	local requestedSlot=type(payload)=="table"and tostring(payload.PositionSlot or payload.SquadSlot or"")or""
	if requestedId~=""or requestedSlot~=""then
		for _,candidate in starting do
			if candidate then
				local candidateId=tostring(candidate.cardInstanceId or candidate.CardInstanceId or candidate.Id or"")
				local candidateSlot=tostring(candidate.SquadSlot or candidate.PositionSlot or candidate.FormationSlot or"")
				if (requestedId~=""and candidateId==requestedId)or(requestedSlot~=""and candidateSlot==requestedSlot)then
					return clonePracticePlayer(candidate)
				end
			end
		end
	end
	return choosePracticeStriker(roster)
end

local function choosePracticeKeeper(roster:any):any?
	local starting=type(roster)=="table"and type(roster.StartingXI)=="table"and roster.StartingXI or{}
	local bench=type(roster)=="table"and type(roster.Bench)=="table"and roster.Bench or{}
	for _,candidate in starting do if playerHasPosition(candidate,"GK")then return clonePracticePlayer(candidate)end end
	for _,candidate in bench do if playerHasPosition(candidate,"GK")then return clonePracticePlayer(candidate)end end
	return nil
end

local function practiceBest(player:any):any
	return player and{{playerId=player.playerId,displayName=player.displayName,shortName=player.shortName,overall=player.overall,bestPosition=player.bestPosition}}or{}
end

local copyDeep: (any) -> any

local function practiceRosterFrom(sourceRoster:any, playerData:any, suffix:string, role:string):any
	local sourceTeam=type(sourceRoster)=="table"and type(sourceRoster.Team)=="table"and sourceRoster.Team or TeamDatabase.Teams[1]
	local team=copyDeep(sourceTeam)
	team.teamId=tostring(team.teamId or"practice").."_"..suffix
	team.teamName=role=="Keeper"and"Practice Keeper"or"Practice Shooter"
	team.logo=role=="Keeper"and"GK"or"ST"
	team.overall=tonumber(playerData and playerData.overall)or tonumber(team.overall)or 75
	team.attack=team.overall
	team.midfield=team.overall
	team.defense=team.overall
	team.formation="4-3-3"
	team.kits=team.kits or sourceTeam.kits or TeamDatabase.Teams[1].kits
	local player=clonePracticePlayer(playerData)or clonePracticePlayer((sourceRoster.StartingXI or{})[1])or{}
	player.FormationSlot=role=="Keeper"and"GK"or"ST"
	player.PositionSlot=role=="Keeper"and"GK"or"ST"
	player.SquadSlot=role=="Keeper"and"GK"or"ST"
	player.bestPosition=role=="Keeper"and"GK"or(player.bestPosition or"ST")
	player.Position=player.bestPosition
	return{Team=team,StartingXI={player},Bench={},Reserves={},Formation="4-3-3",BestPlayers=practiceBest(player)}
end

function copyDeep(value:any):any
	if type(value)~="table"then return value end
	local result={}
	for key,child in value do result[key]=copyDeep(child)end
	return result
end

local function wcCode(country:string):string return string.upper(string.sub(country:gsub("[^%a]",""),1,3))end
local function normalizeCountryName(country:string):string return string.lower((country or""):gsub("&","and"):gsub("[^%w]+"," "):gsub("^%s+",""):gsub("%s+$",""))end

local WORLD_CUP_COUNTRY_ALIASES:{[string]:{string}}={
	["United States"]={"USA","United States of America","US"},
	["Ireland"]={"Republic of Ireland"},
	["South Korea"]={"Korea Republic","Republic of Korea"},
	["North Korea"]={"Korea DPR","DPR Korea"},
	["Saudi Arabia"]={"Saudi"},
	["Czech Republic"]={"Czechia"},
	["Ivory Coast"]={"Cote d'Ivoire","Cote d Ivoire"},
	["DR Congo"]={"Congo DR","Democratic Republic of Congo"},
	["Cape Verde"]={"Cabo Verde"},
	["United Arab Emirates"]={"UAE"},
}

local WORLD_CUP_FORMATION="4-3-3"
local WORLD_CUP_ROSTER_SLOTS={
	{Slot="GK",Positions={"GK"}},{Slot="LB",Positions={"LB","LWB","CB"}},{Slot="CB1",Positions={"CB"}},{Slot="CB2",Positions={"CB"}},{Slot="RB",Positions={"RB","RWB","CB"}},
	{Slot="CDM",Positions={"CDM","CM"}},{Slot="CM1",Positions={"CM","CAM","CDM"}},{Slot="CM2",Positions={"CM","CAM","CDM"}},
	{Slot="LW",Positions={"LW","LM","ST"}},{Slot="ST",Positions={"ST","CF"}},{Slot="RW",Positions={"RW","RM","ST"}},
}
local WORLD_CUP_BENCH_POSITIONS={{"GK"},{"CB","LB","RB"},{"CM","CDM","CAM"},{"LW","RW","LM","RM"},{"ST","CF"},{"CM","CAM"},{"CB","CDM"}}
local WORLD_CUP_PALETTE={
	{"B7FF1A","071008","F5F7F2"},{"245BFF","F5F7F2","FFCB45"},{"D91E36","F5F7F2","111111"},{"17C3B2","111111","F5F7F2"},
	{"F5D547","192A56","F5F7F2"},{"E8E8E8","111111","B7FF1A"},{"111111","F5F7F2","B7FF1A"},{"B51E31","FFFFFF","193B8F"},
}

local function slug(value:string):string
	local result=string.lower(value):gsub("[^%w]+","_"):gsub("^_+",""):gsub("_+$","")
	return result~=""and result or"world"
end

local function countrySeed(country:string):number
	local seed=0
	for index=1,#country do seed=(seed*31+string.byte(country,index))%1000000 end
	return seed
end

local function clonePlayer(player:any):any
	local result=table.clone(player)
	result.appearance=table.clone(player.appearance or{})
	result.mainStats=table.clone(player.mainStats or{})
	result.detailedStats=table.clone(player.detailedStats or{})
	result.positions=table.clone(player.positions or{})
	return result
end

local worldCupShardPool:{[string]:{any}}={}
for _,player in PlayerDatabase.Players do
	local key=normalizeCountryName(tostring(player.country or player.nationality or""))
	if key~=""then
		worldCupShardPool[key]=worldCupShardPool[key]or{}
		table.insert(worldCupShardPool[key],player)
	end
end

local function worldCupCandidates(country:string):{any}
	local result={}
	local seen:{[string]:boolean}={}
	local function collect(name:string)
		local pool=worldCupShardPool[normalizeCountryName(name)]
		if not pool then return end
		for _,player in pool do
			local playerId=tostring(player.playerId or"")
			if playerId~=""and not seen[playerId]then
				seen[playerId]=true
				local copy=clonePlayer(player)
				copy.NationalSourceCountry=copy.country
				copy.country=country
				table.insert(result,copy)
			end
		end
	end
	collect(country)
	for _,alias in WORLD_CUP_COUNTRY_ALIASES[country]or{}do collect(alias)end
	table.sort(result,function(a,b)if(a.overall or 0)==(b.overall or 0)then return tostring(a.playerId)<tostring(b.playerId)end;return(a.overall or 0)>(b.overall or 0)end)
	return result
end

local function hasAnyPosition(player:any,positions:{string}):boolean
	if type(player)~="table"then return false end
	for _,position in positions do
		if player.bestPosition==position or table.find(player.positions or{},position)then return true end
	end
	return false
end

local function averagePlayers(players:{any},predicate:((any)->boolean)?):number
	local total,count=0,0
	for _,player in players do
		if not predicate or predicate(player)then total+=tonumber(player.overall)or 75;count+=1 end
	end
	return count>0 and math.floor(total/count+.5)or 75
end

local function worldCupPrimaryPosition(player:any):string
	if type(player)~="table"then return ""end
	local position=tostring(player.bestPosition or player.Position or player.PositionSlot or player.FormationSlot or player.SquadSlot or"")
	if position=="CB1"or position=="CB2"then return"CB"end
	if position=="CM1"or position=="CM2"then return"CM"end
	return position
end

local function worldCupScorerWeight(player:any):number
	local position=worldCupPrimaryPosition(player)
	local base=({
		ST=14,CF=13,LW=10,RW=10,
		CAM=8,CM=6,LM=6,RM=6,
		CDM=2.5,LWB=1.4,RWB=1.4,LB=1.1,RB=1.1,CB=.8,GK=.03,
	})[position]or 2
	local stats=type(player)=="table"and type(player.mainStats)=="table"and player.mainStats or{}
	local details=type(player)=="table"and type(player.detailedStats)=="table"and player.detailedStats or{}
	local shooting=tonumber(stats.SHO or details.finishing or player.finishing or player.overall)or 75
	local overall=tonumber(player and player.overall)or 75
	local quality=math.clamp(((shooting-70)*.018)+((overall-75)*.01),-.35,.55)
	return math.max(.02,base*(1+quality))
end

local function worldCupWeightedPlayer(players:{any},random:Random,exclude:any?):any?
	local total=0
	for _,player in ipairs(players or{})do
		if player and player~=exclude then total+=worldCupScorerWeight(player)end
	end
	if total<=0 then return nil end
	local roll=random:NextNumber()*total
	for _,player in ipairs(players or{})do
		if player and player~=exclude then
			roll-=worldCupScorerWeight(player)
			if roll<=0 then return player end
		end
	end
	for _,player in ipairs(players or{})do if player and player~=exclude then return player end end
	return nil
end

local function compactRosterPlayer(player:any):any
	return {
		playerId=player.playerId,displayName=player.displayName,shortName=player.shortName,overall=player.overall,bestPosition=player.bestPosition,positions=table.clone(player.positions or{}),
		rarity=player.rarity,cardType=player.cardType,country=player.country,club=player.club,portraitSeed=player.portraitSeed,appearance=table.clone(player.appearance or{}),
		mainStats=table.clone(player.mainStats or{}),detailedStats=table.clone(player.detailedStats or{}),preferredFoot=player.preferredFoot,weakFoot=player.weakFoot,skillMoves=player.skillMoves,
		shotPower=player.shotPower or(player.detailedStats and player.detailedStats.shotPower),longShots=player.longShots or(player.detailedStats and player.detailedStats.longShots),
		finishing=player.finishing or(player.detailedStats and player.detailedStats.finishing),curve=player.curve or(player.detailedStats and player.detailedStats.curve),
		ballControl=player.ballControl or(player.detailedStats and player.detailedStats.ballControl),dribbling=player.dribbling or(player.detailedStats and player.detailedStats.dribbling),
	}
end

local function generatedNationalPlayer(country:string,slot:string,index:number):any
	local seed=countrySeed(country)+index*97+#slot*17
	local random=Random.new(seed)
	local base=PlayerDatabase.Players[(seed%#PlayerDatabase.Players)+1] or PlayerDatabase.Players[1]
	local position=slot=="CB1"and"CB"or slot=="CB2"and"CB"or slot=="CM1"and"CM"or slot=="CM2"and"CM"or slot
	local overall=random:NextInteger(75,85)
	local pac=math.clamp(overall+random:NextInteger(-7,7),45,92)
	local sho=position=="GK"and random:NextInteger(25,45)or math.clamp(overall+random:NextInteger(-8,8),45,90)
	local pas=math.clamp(overall+random:NextInteger(-6,8),45,90)
	local dri=math.clamp(overall+random:NextInteger(-7,7),45,90)
	local def=(position=="ST"or position=="LW"or position=="RW")and math.clamp(overall-random:NextInteger(10,22),35,82)or math.clamp(overall+random:NextInteger(-5,9),45,90)
	local phy=math.clamp(overall+random:NextInteger(-8,8),45,92)
	if position=="GK"then def=math.clamp(overall+random:NextInteger(-4,8),70,90);phy=math.clamp(overall+random:NextInteger(-4,8),70,90)end
	local first={"Alex","Mateo","Nico","Leo","Santi","Kai","Milan","Tomas","Rafa","Noah","Ilyas","Andre","Luca","Dario","Jonas","Emil","Yuri","Adrian","Felix","Mika","Omar","Thiago","Renan","Ari","Kofi","Miro","Enzo","Samir","Elias","Pablo","Joao","Hugo"}
	local last={"Silva","Costa","Diallo","Marin","Novak","Khan","Rossi","Mendez","Okoro","Hassan","Petrov","Reyes","Bento","Mensah","Ibrahim","Santos","Moreira","Kovacs","N'Diaye","Rahman","Adebayo","Vargas","Pereira","Moreno","Keller","Barros","Serrano","Menson","Duarte","Ferreira","Nolan","Kamara"}
	local code=wcCode(country)
	local firstName=first[random:NextInteger(1,#first)]
	local lastName=last[random:NextInteger(1,#last)]
	local displayName=firstName.." "..code.." "..lastName
	return{
		playerId="wcgen_"..slug(country).."_"..index,displayName=displayName,shortName=code.." "..lastName,
		country=country,club=country.." National Team",league="World Cup",positions={position},bestPosition=position,overall=overall,potential=overall,rarity="Gold",cardType="Base",
		portraitSeed=seed,appearance=table.clone(base and base.appearance or{}),preferredFoot=random:NextNumber()<.22 and"Left"or"Right",weakFoot=random:NextInteger(2,4),skillMoves=random:NextInteger(2,4),
		mainStats={PAC=pac,SHO=sho,PAS=pas,DRI=dri,DEF=def,PHY=phy},
		detailedStats={shotPower=math.clamp(sho+random:NextInteger(-4,8),35,92),longShots=math.clamp(sho+random:NextInteger(-7,7),35,90),finishing=math.clamp(sho+random:NextInteger(-6,8),35,92),curve=math.clamp(pas+random:NextInteger(-8,8),35,90),ballControl=math.clamp(dri+random:NextInteger(-5,8),45,92),dribbling=math.clamp(dri+random:NextInteger(-5,8),45,92),stamina=math.clamp(phy+random:NextInteger(-5,10),55,94)},
	}
end

local nationalRosterCache:{[string]:any}={}
local nationalRosterCacheVersion=tostring(PlayerDatabase.Source or"players")..":"..tostring(PlayerDatabase.Count or 0)
local function buildWorldCupNationalRoster(country:string):any
	local cacheKey=country.."|"..nationalRosterCacheVersion
	if nationalRosterCache[cacheKey]then return copyDeep(nationalRosterCache[cacheKey])end
	local candidates=worldCupCandidates(country)
	local used:any={};local arranged={};local generatedCount=0
	local function take(positions:{string},slot:string):any
		local chosen=nil
		for _,player in candidates do if not used[player.playerId]and hasAnyPosition(player,positions)then chosen=player;break end end
		if not chosen then for _,player in candidates do if not used[player.playerId]then chosen=player;break end end end
		if not chosen then generatedCount+=1;chosen=generatedNationalPlayer(country,slot,#arranged+1)end
		used[chosen.playerId]=true
		return compactRosterPlayer(chosen)
	end
	for _,plan in WORLD_CUP_ROSTER_SLOTS do
		local player=take(plan.Positions,plan.Slot)
		local slotDefinition=FormationConfig.Formations[WORLD_CUP_FORMATION][plan.Slot]
		player.FormationSlot=plan.Slot;player.PositionSlot=plan.Slot;player.SquadSlot=plan.Slot
		if slotDefinition then player.FormationCoordinate={X=slotDefinition.X,Y=slotDefinition.Y};player.FormationLabel=slotDefinition.Label;player.ExpectedPosition=slotDefinition.Expected end
		table.insert(arranged,player)
	end
	for index,positions in WORLD_CUP_BENCH_POSITIONS do
		local player=take(positions,"BENCH"..index)
		player.SquadSlot="BENCH"..index
		table.insert(arranged,player)
	end
	local starting,bench={},{}
	for index,player in arranged do if index<=11 then table.insert(starting,player)else table.insert(bench,player)end end
	local forwards={ST=true,CF=true,LW=true,RW=true,LM=true,RM=true};local mids={CM=true,CDM=true,CAM=true,LM=true,RM=true};local defenders={GK=true,CB=true,LB=true,RB=true,LWB=true,RWB=true}
	local palette=WORLD_CUP_PALETTE[(countrySeed(country)%#WORLD_CUP_PALETTE)+1]
	local configuredColors=WorldCupConfig.KitColors and WorldCupConfig.KitColors[country]or nil
	local colors={
		colorToHex(configuredColors and configuredColors.Primary,palette[1]),
		colorToHex(configuredColors and configuredColors.Secondary,palette[2]),
		colorToHex(configuredColors and(configuredColors.Accent or configuredColors.Tertiary),palette[3]),
	}
	local code=wcCode(country)
	local team={teamId="world_cup_"..slug(country),teamName=country,country=country,league="World Cup",overall=averagePlayers(starting),attack=averagePlayers(starting,function(p)return forwards[p.bestPosition]==true end),midfield=averagePlayers(starting,function(p)return mids[p.bestPosition]==true end),defense=averagePlayers(starting,function(p)return defenders[p.bestPosition]==true end),formation=WORLD_CUP_FORMATION,badgePreset="NationalFlag",logo=code,FlagImage=WorldCupConfig.Flag(country),flagImage=WorldCupConfig.Flag(country),colors={Primary=colors[1],Secondary=colors[2],Accent=colors[3]},kits={Home={Name="Home",Primary=colors[1],Secondary=colors[2],Accent=colors[3],Style="Vertical Stripes",NumberColor=colors[3]},Away={Name="Away",Primary=colors[2],Secondary=colors[3],Accent=colors[1],Style="Solid",NumberColor=colors[1]},Third={Name="Third",Primary=colors[3],Secondary=colors[1],Accent=colors[2],Style="Diagonal Sash",NumberColor=colors[2]}},generated=true,WorldCupNation=true,RosterSource="VTRPlayers",RosterSourceCount=#candidates,GeneratedPlayers=generatedCount}
	team.starPlayers={starting[1],starting[2],starting[3]}
	local best={}
	for index=1,math.min(3,#team.starPlayers)do local star=team.starPlayers[index];table.insert(best,{playerId=star.playerId,displayName=star.displayName,shortName=star.shortName,overall=star.overall,bestPosition=star.bestPosition})end
	local roster={Team=team,StartingXI=starting,Bench=bench,Reserves={},Formation=WORLD_CUP_FORMATION,BestPlayers=best}
	nationalRosterCache[cacheKey]=copyDeep(roster)
	return copyDeep(roster)
end

local function stageValue(state:any):number
	if type(state)~="table"then return 0 end
	if state.Stage=="Champion"then return 5 end
	if state.Stage=="Knockout"then return math.clamp(tonumber(state.Knockout and state.Knockout.Round)or 1,1,4)end
	if state.Stage=="Eliminated"and state.Knockout then return math.clamp(tonumber(state.Knockout.Round)or 1,1,4)end
	return 0
end

local function userFixtureStats(state:any):any
	local selected=tostring(state and state.SelectedCountry or"")
	local stats={Wins=0,Losses=0,KnockoutWins=0,GoalsFor=tonumber(state and state.UserGoalsFor)or 0,GoalsAgainst=tonumber(state and state.UserGoalsAgainst)or 0,FiveGoalMatch=false,ExtraTimeWins=0,ShootoutWins=0,KnockoutCleanSheets=true,RegulationKnockout=true,OneGoalKnockout=true,ContinentsDefeated={},ContinentsDefeatedCounts={},DefeatedNations={},SameOpponentWins={},OwnContinentWins=0,FormerChampionWins=0,TopFiveKnockoutStreak=0,MaxTopFiveKnockoutStreak=0,HostWin=false,HostBigWin=false,DefendingChampionWin=false,TopSeedR32Win=false,FormerChampionR32Win=false}
	local ownContinent=continentOf(selected)
	local function visit(fixture:any)
		if type(fixture)~="table"or fixture.Played~=true or(fixture.Home~=selected and fixture.Away~=selected)then return end
		local homeGoals=tonumber(fixture.HomeGoals)or 0;local awayGoals=tonumber(fixture.AwayGoals)or 0
		local forGoals=fixture.Home==selected and homeGoals or awayGoals;local againstGoals=fixture.Home==selected and awayGoals or homeGoals
		local opponent=fixture.Home==selected and tostring(fixture.Away or"")or tostring(fixture.Home or"")
		local winner=tostring(fixture.Winner or(homeGoals>awayGoals and fixture.Home or awayGoals>homeGoals and fixture.Away or""))
		local won=winner==selected or(winner==""and forGoals>againstGoals)
		if won then stats.Wins+=1 else stats.Losses+=1 end
		stats.FiveGoalMatch=stats.FiveGoalMatch or forGoals>=5
		if won then
			local opponentContinent=continentOf(opponent)
			stats.ContinentsDefeated[opponentContinent]=true
			stats.ContinentsDefeatedCounts[opponentContinent]=(tonumber(stats.ContinentsDefeatedCounts[opponentContinent])or 0)+1
			stats.DefeatedNations[opponent]=true
			stats.SameOpponentWins[opponent]=(tonumber(stats.SameOpponentWins[opponent])or 0)+1
			if opponentContinent==ownContinent then stats.OwnContinentWins+=1 end
		end
		local round=tonumber(fixture.Round)or 0
		if round>0 then
			if won then
				stats.KnockoutWins+=1
				if fixture.ExtraTime==true then stats.ExtraTimeWins+=1 end
				if fixture.Penalties==true then stats.ShootoutWins+=1 end
				if opponent==HOST_NATION then stats.HostWin=true;if forGoals-againstGoals>=3 then stats.HostBigWin=true end end
				if opponent==DEFENDING_CHAMPION then stats.DefendingChampionWin=true end
				if FORMER_CHAMPIONS[opponent]then stats.FormerChampionWins+=1 end
				if round==1 and WorldCupConfig.Ranking(opponent)<=8 then stats.TopSeedR32Win=true end
				if round==1 and FORMER_CHAMPIONS[opponent]then stats.FormerChampionR32Win=true end
				if WorldCupConfig.Ranking(opponent)<=5 then stats.TopFiveKnockoutStreak+=1;stats.MaxTopFiveKnockoutStreak=math.max(stats.MaxTopFiveKnockoutStreak,stats.TopFiveKnockoutStreak)else stats.TopFiveKnockoutStreak=0 end
			else stats.TopFiveKnockoutStreak=0 end
			if againstGoals>0 then stats.KnockoutCleanSheets=false end
			if fixture.ExtraTime==true or fixture.Penalties==true then stats.RegulationKnockout=false end
			if math.abs(forGoals-againstGoals)~=1 then stats.OneGoalKnockout=false end
		end
	end
	for _,fixtures in state and state.Fixtures or{}do for _,fixture in fixtures do visit(fixture)end end
	for _,round in state and state.Knockout and state.Knockout.History or{}do for _,fixture in round.Fixtures or{}do visit(fixture)end end
	for _,fixture in state and state.Knockout and state.Knockout.Fixtures or{}do visit(fixture)end
	if stats.KnockoutWins<=0 then stats.KnockoutCleanSheets=false;stats.RegulationKnockout=false;stats.OneGoalKnockout=false end
	return stats
end

function Service:_worldCupQuestValue(profile:any,definition:any):number
	local state=type(profile.WorldCup)=="table"and profile.WorldCup or nil
	local quests=questProfile(profile);local career=quests.Career;local metric=tostring(definition.Metric or"")
	local stats=state and userFixtureStats(state)or userFixtureStats(nil)
	local titleWon=state and state.Stage=="Champion"and state.WorldCupWinner==state.SelectedCountry
	local selected=tostring(state and state.SelectedCountry or"")
	local selectedContinent=continentOf(selected)
	local requiredStage=tonumber(definition.StageValue)or 0
	if metric=="bestStage"then local required=definition.Id=="quarterfinal_quality"and 2 or definition.Id=="final_four"and 3 or definition.Id=="one_match_away"and 4 or definition.Id=="world_champions"and 5 or 1;return stageValue(state)>=required and 1 or 0
	elseif metric=="titleWithNation"then return titleWon and listHas(definition.Nations,selected) and 1 or 0
	elseif metric=="stageWithNation"then return stageValue(state)>=requiredStage and listHas(definition.Nations,selected) and 1 or 0
	elseif metric=="titleWithContinent"then return titleWon and(continentHas(definition.Continents,selectedContinent)or tostring(definition.Continent or"")==selectedContinent)and 1 or 0
	elseif metric=="stageWithContinent"then return stageValue(state)>=requiredStage and(continentHas(definition.Continents,selectedContinent)or tostring(definition.Continent or"")==selectedContinent)and 1 or 0
	elseif metric=="firstTitleWithNation"then return titleWon and listHas(definition.Nations,selected) and not FORMER_CHAMPIONS[selected]and 1 or 0
	elseif metric=="rivalryWin"then
		for _,pair in type(definition.Rivalries)=="table"and definition.Rivalries or{}do
			local user=canonicalCountry(pair.User or pair[1])
			local opponent=canonicalCountry(pair.Opponent or pair[2])
			if selected==user and stats.DefeatedNations[opponent]==true then return 1 end
		end
		return 0
	elseif metric=="defeatNationsRun"then
		for _,country in type(definition.Nations)=="table"and definition.Nations or{}do if stats.DefeatedNations[canonicalCountry(country)]~=true then return 0 end end
		return 1
	elseif metric=="defeatContinentCountRun"then return tonumber(stats.ContinentsDefeatedCounts[tostring(definition.Continent or"")])or 0
	elseif metric=="goalsForRun"then return stats.GoalsFor
	elseif metric=="fiveGoalMatch"then return stats.FiveGoalMatch and 1 or 0
	elseif metric=="lowConcedeRun"then return titleWon and stats.GoalsAgainst<=3 and 1 or 0
	elseif metric=="noConcedeTitle"then return titleWon and stats.GoalsAgainst<=0 and 1 or 0
	elseif metric=="scoreEveryMatchRun"then return titleWon and stats.GoalsFor>=(tonumber(state.PlayedMatches)or 0)+(tonumber(state.SimulatedMatches)or 0) and 1 or 0
	elseif metric=="extraTimeWinsRun"then return stats.ExtraTimeWins
	elseif metric=="shootoutWinsRun"then return stats.ShootoutWins
	elseif metric=="continentsDefeatedRun"then local n=0;for _ in stats.ContinentsDefeated do n+=1 end;return n
	elseif metric=="sameContinentEliminationsRun"or metric=="ownContinentWinsRun"then return stats.OwnContinentWins
	elseif metric=="sameOpponentWinsRun"then local best=0;for _,count in stats.SameOpponentWins do best=math.max(best,tonumber(count)or 0)end;return best
	elseif metric=="formerChampionWinsRun"then return stats.FormerChampionWins
	elseif metric=="hostWin"then return stats.HostWin and 1 or 0
	elseif metric=="hostBigWin"then return stats.HostBigWin and 1 or 0
	elseif metric=="defendingChampionWin"then return stats.DefendingChampionWin and 1 or 0
	elseif metric=="ultimateRouteRun"then return(stats.HostWin and 1 or 0)+(stats.DefendingChampionWin and 1 or 0)+(stats.TopSeedR32Win and 1 or 0)
	elseif metric=="r32Wins"then return tonumber(career.R32Wins)or 0
	elseif metric=="topSeedR32Win"then return stats.TopSeedR32Win and 1 or 0
	elseif metric=="formerChampionR32Win"then return stats.FormerChampionR32Win and 1 or 0
	elseif metric=="knockoutCleanSheetRun"then return titleWon and stats.KnockoutCleanSheets and 1 or 0
	elseif metric=="regulationKnockoutRun"or metric=="regulationTitle"then return titleWon and stats.RegulationKnockout and 1 or 0
	elseif metric=="knockoutSweepTitle"then return titleWon and stats.KnockoutWins>=4 and 1 or 0
	elseif metric=="oneGoalKnockoutRun"then return titleWon and stats.OneGoalKnockout and 1 or 0
	elseif metric=="topFiveKnockoutStreakRun"then return stats.MaxTopFiveKnockoutStreak
	elseif metric=="titles"then return tonumber(career.Titles)or 0
	elseif metric=="perfectTitle"or metric=="unbeatenTitle"then return titleWon and stats.Losses<=0 and 1 or 0
	elseif metric=="unbeatenTitles"then return tonumber(career.UnbeatenTitles)or 0
	elseif metric=="underdogTitle"then return titleWon and WorldCupConfig.Ranking(selected)>=120 and 1 or 0
	elseif metric=="lowestRatedTitle"then return titleWon and WorldCupConfig.Ranking(selected)>=200 and 1 or 0
	elseif metric=="firstTitle"or metric=="firstFinal"or metric=="firstSemi"or metric=="bestFinish"or metric=="instantImpact"then return titleWon and 1 or 0
	elseif metric=="openingLossTitle"then return titleWon and state.OpeningLoss==true and 1 or 0
	elseif metric=="formerChampionTitle"then return titleWon and FORMER_CHAMPIONS[selected]and 1 or 0
	elseif metric=="nonChampionSemi"then return stageValue(state)>=3 and not FORMER_CHAMPIONS[selected]and 1 or 0
	elseif metric=="rareContinentTitle"then return titleWon and continentOf(selected)~="Europe"and continentOf(selected)~="South America"and 1 or 0
	elseif metric=="lowRankQuarter"then return stageValue(state)>=2 and WorldCupConfig.Ranking(selected)>=80 and 1 or 0
	elseif metric=="sameNationTitles"then local best=0;for _,count in career.NationTitles or{}do best=math.max(best,tonumber(count)or 0)end;return best
	elseif metric=="continentTitle"then return titleWon and questContinent(definition.Title)==continentOf(selected) and 1 or 0
	elseif metric=="continentFinal"then return stageValue(state)>=4 and questContinent(definition.Title)==continentOf(selected) and 1 or 0
	elseif metric=="continentSemi"then return stageValue(state)>=3 and questContinent(definition.Title)==continentOf(selected) and 1 or 0
	elseif metric=="continentQuarter"then return stageValue(state)>=2 and questContinent(definition.Title)==continentOf(selected) and 1 or 0
	elseif metric=="continentsDefeatedCareer"then local n=0;for _ in career.ContinentsDefeated or{}do n+=1 end;return n
	elseif metric=="titleContinents"then local n=0;for _ in career.TitleContinents or{}do n+=1 end;return n
	elseif metric=="semiContinents"then local n=0;for _ in career.SemiContinents or{}do n+=1 end;return n
	elseif metric=="semiNationsByContinent"then local n=0;local bucket=career.SemiNationsByContinent and career.SemiNationsByContinent[tostring(definition.Continent or"")]or{};for _ in bucket do n+=1 end;return n
	elseif metric=="continentSemiStreak"then return tonumber(career.SemiContinentStreaks and career.SemiContinentStreaks[tostring(definition.Continent or"")])or 0
	elseif metric=="finalNationsNever"then local n=0;for _ in career.FinalNationsNever or{}do n+=1 end;return n
	elseif metric=="managedNations"then local n=0;for _ in career.ManagedNations or{}do n+=1 end;return n
	elseif metric=="managedContinents"then local n=0;for _ in career.ManagedContinents or{}do n+=1 end;return n
	elseif metric=="titleNations"then local n=0;for _ in career.TitleNations or{}do n+=1 end;return n
	elseif metric=="tierTitles"then local n=0;for _ in career.TierTitles or{}do n+=1 end;return n
	elseif metric=="careerFinals"then return tonumber(career.Finals)or 0
	elseif metric=="knockoutWins"then return tonumber(career.KnockoutWins)or 0
	elseif metric=="careerWins"then return tonumber(career.Wins)or 0 end
	return tonumber(quests.Progress[definition.Id])or 0
end

function Service:_refreshWorldCupQuests(profile:any)
	local quests=questProfile(profile)
	for _,definition in WorldCupQuestConfig.Quests do
		local current=tonumber(quests.Progress[definition.Id])or 0
		local value=math.clamp(math.floor(tonumber(self:_worldCupQuestValue(profile,definition))or 0),0,tonumber(definition.Target)or 1)
		if value>current then quests.Progress[definition.Id]=value end
	end
end

function Service:_worldCupQuestPublic(profile:any):any
	self:_refreshWorldCupQuests(profile)
	local quests=questProfile(profile)
	local list={}
	for _,definition in WorldCupQuestConfig.Quests do
		table.insert(list,{Id=definition.Id,Category=definition.Category,Title=definition.Title,Description=definition.Description,Target=definition.Target,Progress=math.min(tonumber(quests.Progress[definition.Id])or 0,tonumber(definition.Target)or 1),Claimed=quests.Claimed[definition.Id]==true,PackId=definition.PackId,PackName=WorldCupQuestConfig.PackName(definition.PackId),Difficulty=definition.Difficulty})
	end
	return list
end

function Service:_worldCupTitleCounts(profile:any):any
	local counts={}
	local quests=questProfile(profile)
	local career=quests.Career
	for country,count in career.NationTitles or{}do
		local titleCount=math.max(0,math.floor(tonumber(count)or 0))
		if titleCount>0 then counts[tostring(country)]=titleCount end
	end
	for _,entry in type(profile.WorldCupHistory)=="table"and profile.WorldCupHistory or{}do
		local country=tostring(entry.Country or"")
		if country~=""and entry.Stage=="Champion"and entry.Winner==country and counts[country]==nil then
			counts[country]=1
		end
	end
	return counts
end

function Service:_recordWorldCupQuestCareer(profile:any,state:any)
	local quests=questProfile(profile)
	local career=quests.Career
	if type(state)~="table"or state.QuestCareerRecorded==true then return end
	local selected=tostring(state.SelectedCountry or"")
	local stats=userFixtureStats(state)
	career.ManagedNations[selected]=true
	career.ManagedContinents[continentOf(selected)]=true
	career.Wins=(tonumber(career.Wins)or 0)+stats.Wins
	career.KnockoutWins=(tonumber(career.KnockoutWins)or 0)+stats.KnockoutWins
	if stats.KnockoutWins>0 then career.R32Wins=(tonumber(career.R32Wins)or 0)+(stats.KnockoutWins>0 and 1 or 0)end
	for continent in stats.ContinentsDefeated do career.ContinentsDefeated[continent]=true end
	if stageValue(state)>=3 then
		local continent=continentOf(selected)
		career.SemiContinents[continent]=true
		career.SemiNationsByContinent[continent]=type(career.SemiNationsByContinent[continent])=="table"and career.SemiNationsByContinent[continent]or{}
		career.SemiNationsByContinent[continent][selected]=true
		career.SemiContinentStreaks=type(career.SemiContinentStreaks)=="table"and career.SemiContinentStreaks or{}
		local streak=(career.LastSemiContinent==continent and(tonumber(career.CurrentSemiContinentStreak)or 0)or 0)+1
		career.LastSemiContinent=continent
		career.CurrentSemiContinentStreak=streak
		career.SemiContinentStreaks[continent]=math.max(tonumber(career.SemiContinentStreaks[continent])or 0,streak)
	else
		career.LastSemiContinent=nil
		career.CurrentSemiContinentStreak=0
	end
	if stageValue(state)>=4 then
		career.Finals=(tonumber(career.Finals)or 0)+1
		if not FORMER_CHAMPIONS[selected]then career.FinalNationsNever[selected]=true end
	end
	if state.Stage=="Champion"and state.WorldCupWinner==selected then
		career.Titles=(tonumber(career.Titles)or 0)+1
		career.TitleNations[selected]=true
		career.TitleContinents[continentOf(selected)]=true
		career.NationTitles=type(career.NationTitles)=="table"and career.NationTitles or{}
		career.NationTitles[selected]=(tonumber(career.NationTitles[selected])or 0)+1
		local rank=WorldCupConfig.Ranking(selected)
		local tier=rank<=16 and"Favourite"or rank<=80 and"MidTier"or"Underdog"
		career.TierTitles=type(career.TierTitles)=="table"and career.TierTitles or{}
		career.TierTitles[tier]=true
		if stats.Losses<=0 then career.UnbeatenTitles=(tonumber(career.UnbeatenTitles)or 0)+1 end
	end
	state.QuestCareerRecorded=true
	self:_refreshWorldCupQuests(profile)
end

function Service:_worldCupPublic(profile:any):any
	local state=type(profile.WorldCup)=="table"and profile.WorldCup or nil
	return{State=state and copyDeep(state)or nil,History=type(profile.WorldCupHistory)=="table"and copyDeep(profile.WorldCupHistory)or{},Countries=WorldCupConfig.Countries,Flags=WorldCupConfig.Flags,Quests=self:_worldCupQuestPublic(profile),TitleCounts=self:_worldCupTitleCounts(profile)}
end

function Service:GetWorldCup(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	self:_consumeWorldCupRuntimeResult(player,profile)
	if type(profile.WorldCup)=="table"then self:_worldCupEnsureTeamRanks(profile.WorldCup);self:_worldCupRepairGroupNextFixture(profile.WorldCup)end
	return true,"World Cup loaded.",self:_worldCupPublic(profile)
end

function Service:_worldCupEnsureStanding(state:any,country:string)
	state.Standings=state.Standings or{}
	state.Standings[country]=state.Standings[country]or{P=0,W=0,D=0,L=0,GF=0,GA=0,GD=0,PTS=0}
	return state.Standings[country]
end

function Service:_worldCupRecord(state:any,home:string,away:string,homeGoals:number,awayGoals:number)
	local hs=self:_worldCupEnsureStanding(state,home);local as=self:_worldCupEnsureStanding(state,away)
	hs.P+=1;as.P+=1;hs.GF+=homeGoals;hs.GA+=awayGoals;as.GF+=awayGoals;as.GA+=homeGoals;hs.GD=hs.GF-hs.GA;as.GD=as.GF-as.GA
	if homeGoals>awayGoals then hs.W+=1;as.L+=1;hs.PTS+=3 elseif awayGoals>homeGoals then as.W+=1;hs.L+=1;as.PTS+=3 else hs.D+=1;as.D+=1;hs.PTS+=1;as.PTS+=1 end
end

function Service:_worldCupEnsureTeamRanks(state:any)
	if type(state)~="table"then return end
	state.TeamRank=type(state.TeamRank)=="table"and state.TeamRank or{}
	local teams={}
	for country,overall in state.TeamOverall or{}do table.insert(teams,{Country=country,Overall=tonumber(overall)or 76})end
	table.sort(teams,function(a,b)if a.Overall==b.Overall then return a.Country<b.Country end;return a.Overall>b.Overall end)
	for index,entry in ipairs(teams)do state.TeamRank[entry.Country]=index end
end

local WORLD_CUP_STORY_TITLES={"Shock Result","Late Winner","Defensive Masterclass","Comeback Victory","Goalless Battle","High-Scoring Thriller","Early Goal Decides It","Missed Chances","Penalty Drama","Red Card Turns the Match","Goalkeeper Heroics","VAR Controversy","Total Domination","Tactical Battle","Group Stage Chaos","Captain's Night","Set Piece Edge","Counterattack Clinic","Midfield Control","Qualification Twist"}
local WORLD_CUP_STORY_DESCRIPTIONS={
	["Shock Result"]={
		"{winner} stunned {loser} with a performance full of confidence, discipline, and sharp counterattacks. {loser} had more of the ball, but {winner} defended with patience and waited for the perfect moment to strike.",
		"{loser} looked comfortable early on, but the match slowly slipped away as {winner} grew into the game. A fearless second-half push gave {winner} the breakthrough and left {loser} chasing shadows.",
		"{winner} produced one of the biggest surprises of the group stage, refusing to panic under pressure and punishing {loser} when the chance arrived. By full time, the stadium knew it had witnessed a massive upset.",
		"{loser} entered the match as favorites, but {winner} played with no fear. Every tackle, clearance, and counterattack carried belief, and the final result completely changed the mood of the group.",
		"{winner} shocked {loser} by turning a difficult match into a famous victory. {loser} pushed hard late, but {winner} stayed compact and protected the lead with heroic defending.",
	},
	["Late Winner"]={
		"The match looked destined for a draw until {winner} found one final burst of energy. In the {minute}th minute, a loose ball inside the box became the decisive moment, giving {winner} a dramatic {scoreA}-{scoreB} win over {loser}.",
		"{loser} defended bravely for most of the match, but the pressure finally became too much. {winner} kept attacking until the final whistle and were rewarded with a late winner that sent their fans wild.",
		"Both teams traded momentum throughout the match, but {winner} saved their best moment for the end. A late attack broke through {loser}'s tired defense and turned one point into three.",
		"{winner} looked frustrated for long stretches, with {loser} blocking shots and slowing the tempo. But one late move changed everything, giving {winner} a victory that could prove crucial.",
		"Just when {loser} seemed ready to escape with a draw, {winner} struck in the closing minutes. The goal changed the entire story of the game and left {loser} devastated at full time.",
	},
	["Defensive Masterclass"]={
		"{winner} built their victory on organization and patience, allowing {loser} to have possession but denying them clear chances. Every cross was cleared, every run was tracked, and the clean defensive shape carried {winner} to the result.",
		"{loser} spent much of the match searching for space, but {winner} never gave them enough room to breathe. The back line stayed calm under pressure and turned the game into a test of discipline.",
		"{winner} did not need to dominate the ball to control the match. Their defensive structure frustrated {loser}, and once the lead arrived, they protected it with total focus.",
		"{loser} attacked in waves, especially late in the match, but {winner} refused to break. The goalkeeper and defenders combined for a gritty performance that made the result feel earned.",
		"{winner} turned the match into a battle of patience, defending deep and forcing {loser} into difficult shots. It was not flashy, but it was effective, and it gave {winner} a valuable win.",
	},
	["Comeback Victory"]={
		"{loser} started stronger and looked ready to control the match, but {winner} refused to collapse after falling behind. A change in tempo after halftime transformed the game and helped {winner} complete a brilliant comeback.",
		"The match began badly for {winner}, with {loser} taking advantage of early pressure. But instead of losing confidence, {winner} became more aggressive, turned the midfield battle around, and finished the match on top.",
		"{winner} had to suffer before celebrating. After conceding first, they slowly rebuilt their rhythm, found an equalizer, and then pushed forward again to steal a memorable victory.",
		"{loser} will regret not killing the game when they had control. {winner} survived the difficult spell, grew stronger with every attack, and eventually flipped the entire result.",
		"{winner} showed character in a match that could have fallen apart early. The response after going behind was immediate and brave, turning pressure into momentum and momentum into victory.",
	},
	["Goalless Battle"]={
		"{teamA} and {teamB} fought through a tense 0-0 draw where defenses controlled the story. Both teams had moments of pressure, but neither found the final pass or finish needed to break the match open.",
		"The match was full of effort but short on clear chances, as {teamA} and {teamB} cancelled each other out in midfield. Every promising attack was quickly closed down before it could become dangerous.",
		"{teamA} tried to stretch the game wide while {teamB} stayed compact and waited for counters. In the end, both sides protected the point and left the pitch knowing they could have done more.",
		"Neither goalkeeper was beaten in a cautious but intense group-stage meeting. {teamA} and {teamB} both had spells of control, but the final touch was missing all match.",
		"It was a tactical stalemate from start to finish. {teamA} and {teamB} defended with discipline, limited mistakes, and accepted a result that keeps the group picture uncertain.",
	},
	["High-Scoring Thriller"]={
		"{winner} and {loser} produced a wild match full of chances, mistakes, and momentum swings. Every time one side looked ready to take control, the other answered back, but {winner} had the final word.",
		"{winner} survived a chaotic attacking battle where neither defense looked comfortable. {loser} created plenty of danger, but {winner} were sharper in the decisive moments and claimed the win.",
		"The match exploded early and never slowed down. {winner} pushed forward with confidence, {loser} responded with pressure of their own, and the scoreboard kept changing until the final stages.",
		"{loser} refused to go away, making {winner} fight for every goal and every clearance. In the end, {winner}'s attacking quality made the difference in a breathless {scoreA}-{scoreB} result.",
		"Fans were given one of the most entertaining matches of the group stage. {winner} and {loser} both attacked with urgency, but {winner} stayed calmer when the match became chaotic.",
	},
	["Early Goal Decides It"]={
		"{winner} struck early and forced {loser} to chase the match almost from the beginning. After the opening goal, {winner} dropped into a disciplined shape and made every minute difficult for {loser}.",
		"The decisive moment arrived before the match had time to settle. {winner} scored in the {minute}th minute, then protected the lead with patience, structure, and sharp defensive reactions.",
		"{loser} were punished for a slow start, conceding early and spending the rest of the game searching for a response. {winner} managed the advantage well and never allowed the match to fully escape their control.",
		"{winner} made their first big chance count, and that changed the entire rhythm of the game. {loser} had possession afterward, but the early goal gave {winner} something to defend.",
		"A fast start gave {winner} the perfect platform. Once ahead, they slowed the tempo, frustrated {loser}, and turned one early strike into a massive result.",
	},
	["Missed Chances"]={
		"{loser} will feel they let the match slip away after creating enough chances to get a result. {winner} were not always dominant, but they were ruthless when their opportunity came.",
		"{winner} survived several dangerous moments before taking control of the result. {loser} had the shots, the pressure, and the openings, but poor finishing turned the match against them.",
		"{loser} started brightly and caused problems throughout the first half, but every missed chance made the pressure heavier. {winner} stayed patient and eventually punished them.",
		"This was a match of regret for {loser}. They moved the ball well and found promising positions, but {winner} defended the key moments and made better use of fewer chances.",
		"{winner} claimed the result because they were more efficient in front of goal. {loser} had enough moments to change the story, but hesitation and missed finishes proved costly.",
	},
	["Penalty Drama"]={
		"The match turned on a penalty decision that changed everything. {winner} stayed calm from the spot, while {loser} struggled to recover from the frustration of the call.",
		"{loser} were furious after the referee pointed to the spot, but {winner} kept their focus and used the moment to take control. From there, the game became emotional and tense.",
		"{winner} earned a crucial penalty after sustained pressure inside the box. The finish gave them the lead, and the rest of the match became a test of nerves.",
		"A penalty became the defining moment of a tight match. {winner} converted when it mattered, then defended with discipline as {loser} pushed desperately for a response.",
		"{loser} had chances to recover after the penalty, but the goal shifted momentum heavily toward {winner}. The match became heated, physical, and full of late drama.",
	},
	["Red Card Turns the Match"]={
		"The game changed completely after {loser} were reduced to ten men. {winner} immediately pushed higher, controlled more of the ball, and eventually found the space needed to win.",
		"{loser} were competitive until the red card disrupted their shape. From that moment on, {winner} stretched the pitch, forced mistakes, and turned the advantage into a decisive result.",
		"{winner} stayed calm after a heated moment changed the match. With an extra player, they moved the ball patiently and waited for {loser}'s tired defense to open.",
		"{loser} fought bravely despite playing with ten men, but the pressure became too much. {winner} kept attacking the gaps and finally made the numerical advantage count.",
		"A sending off became the turning point in a physical group-stage battle. {winner} handled the chaos better, while {loser} lost their rhythm and eventually the match.",
	},
	["Goalkeeper Heroics"]={
		"{winner} owed a huge part of the result to their goalkeeper, who produced save after save under pressure. {loser} created enough danger to score, but every big moment was denied.",
		"{loser} pushed hard throughout the match and forced {winner} deep for long spells. The difference was the goalkeeper, whose reflexes protected the lead when the match looked ready to turn.",
		"{winner} did not always look comfortable, but their goalkeeper gave them belief. A series of crucial saves kept {loser} frustrated and allowed {winner} to escape with the result.",
		"The match became a showcase for {winner}'s goalkeeper. Crosses, long shots, and close-range chances all came toward the net, but nothing was allowed through.",
		"{loser} kept knocking on the door, especially late, but {winner}'s goalkeeper refused to let the match change. It was a performance that turned pressure into victory.",
	},
	["VAR Controversy"]={
		"VAR became the biggest talking point of the match, with a crucial review shifting momentum toward {winner}. {loser} never fully recovered from the decision and spent the rest of the game chasing frustration.",
		"{winner} benefited from a long VAR check that changed the rhythm of the match. The delay added tension, and once play resumed, {winner} handled the moment better than {loser}.",
		"{loser} thought they had found a way back into the game, only for VAR to erase the moment. {winner} used the reprieve to regroup and protect the result.",
		"A controversial review left {loser} furious and gave {winner} the emotional edge. From that point on, every challenge and every attack carried extra tension.",
		"Technology took center stage in a match already full of pressure. {winner} stayed composed through the VAR drama, while {loser} lost focus at the worst possible time.",
	},
	["Total Domination"]={
		"{winner} controlled the match from the opening minutes and never allowed {loser} to settle. The passing was sharp, the pressing was aggressive, and the final result reflected a complete performance.",
		"{loser} spent most of the match pinned back as {winner} attacked in waves. Every loose ball seemed to fall to {winner}, who turned pressure into a convincing result.",
		"{winner} looked stronger in every area of the pitch, winning midfield battles and creating chances with ease. {loser} could not find a way to slow the game down.",
		"This was a statement performance from {winner}. They controlled possession, created the better chances, and defended calmly whenever {loser} tried to respond.",
		"{winner} made the match feel one-sided through speed, confidence, and constant pressure. {loser} were forced to defend for long stretches and rarely looked comfortable.",
	},
	["Tactical Battle"]={
		"{winner} won a match defined by patience and tactical discipline. They denied {loser} space in central areas, forced the game wide, and waited for the right moment to attack.",
		"Both teams started cautiously, trying to control the rhythm rather than take risks. {winner} eventually found the better adjustments, using smarter movement and better timing to break through.",
		"{loser} struggled to solve {winner}'s structure, especially after halftime. The match was tight, but {winner}'s substitutions and shape changes made the difference.",
		"{winner} did not win through chaos or luck, but through a clear plan. They slowed {loser}'s strongest attacks, controlled transitions, and managed the match intelligently.",
		"The game felt like a chess match for long stretches. {winner} made fewer mistakes, chose the right moments to press, and turned tactical control into victory.",
	},
	["Group Stage Chaos"]={
		"The result completely changed the group picture, giving {winner} a massive boost while leaving {loser} under pressure. What looked like a predictable match became one of the key turning points of the round.",
		"{winner}'s victory threw the standings wide open and made every remaining match feel more dangerous. {loser} now have to recover quickly after dropping important points.",
		"This match added another layer of chaos to the group stage. {winner} took advantage of the moment, while {loser} now face a much harder path forward.",
		"The final whistle sparked huge celebrations for {winner}, not just because of the win but because of what it means for qualification. {loser} leave with serious questions to answer.",
		"A single result changed everything in the group. {winner} are suddenly alive with momentum, while {loser} must now depend on a strong response in the next match.",
	},
	["Captain's Night"]={"{winner}'s leaders shaped the match with calm decisions and timely pressure. {loser} tried to drag the game into chaos, but {winner} kept returning to their structure and finished the key moments better.","The captain's influence was visible in every difficult spell. {winner} stayed organized, kept communicating, and made {loser} work for every yard of space."},
	["Set Piece Edge"]={"{winner} found their advantage from dead-ball situations, where every delivery created panic for {loser}. The match was tight in open play, but set pieces gave {winner} the separation they needed.","The difference came from details. {winner} attacked corners and free kicks with more belief, while {loser} struggled to clear the first contact."},
	["Counterattack Clinic"]={"{loser} pushed numbers forward, but {winner} were ruthless in transition. Every turnover felt dangerous, and the winning moments came from speed into open grass.","This was a counterattacking lesson from {winner}. {loser} controlled territory, but one loose pass after another gave {winner} the spaces they wanted."},
	["Midfield Control"]={"{winner} took command of the midfield and slowly squeezed the match away from {loser}. The result came from pressure, second balls, and the patience to wait for a clean opening.","The middle of the pitch decided everything. {winner} won the duels that mattered and kept {loser} from building any real rhythm."},
	["Qualification Twist"]={"{winner} changed the qualification picture with a result that will echo into the next gameday. {loser} now have less margin for error, and the group suddenly feels wide open.","The table shifted hard after this one. {winner} turned a single match into a major tournament swing, while {loser} left knowing the next game is now massive."},
}
local WORLD_CUP_STORY_OPENERS={
	"{winner} played with control and belief, turning a dangerous fixture against {loser} into a result that changes the tone of the group.",
	"{loser} had long spells where the match felt within reach, but {winner} were sharper in the moments that decided the score.",
	"The match swung through pressure, nerves, and missed chances before {winner} found the edge that separated the teams.",
	"{winner} looked prepared for the occasion, defending the key spaces and punishing {loser} when the game opened up.",
	"{loser} pushed hard after falling behind, but {winner} managed the tempo well and kept enough composure to see it through.",
	"This was not just about the scoreline. {winner} won the small battles, recovered loose balls, and made {loser} chase the match.",
	"{winner} grew stronger as the minutes passed, while {loser} struggled to turn possession into the kind of chances that change games.",
	"The result gives {winner} a major lift, especially because {loser} never looked comfortable once the match became stretched.",
}
local WORLD_CUP_DRAW_OPENERS={
	"{teamA} and {teamB} split the points after a tense match where both sides had chances to take control.",
	"The group picture remains wide open after {teamA} and {teamB} cancelled each other out in a disciplined draw.",
	"Neither side could find the final touch, leaving {teamA} and {teamB} with a point each and plenty to think about.",
	"{teamA} had spells of pressure, {teamB} had moments on the break, but the match ended with nothing between them.",
}
local WORLD_CUP_STORY_DETAILS={
	"Rankings framed the entire night: {rankLine}. That context made every goal feel heavier.",
	"The decisive spell arrived around the {minute}th minute, when one attack shifted the match and forced the other side to chase.",
	"Supporters will remember the pressure late on, but the real story was how well the result was protected after the breakthrough.",
	"The table impact is immediate, with three points changing the pressure around the next gameday.",
	"Both managers will look at the middle third as the key area, because second balls and transitions shaped the rhythm.",
	"The final whistle felt bigger than a normal group match because qualification paths are now moving fast.",
	"The scoreline says {score}, but the match had more tension than the numbers alone show.",
	"It was a game of control versus risk, and the side that handled the risk better got the reward.",
}
local function wcFill(template:string,values:any):string
	return (template:gsub("{([%w_]+)}",function(key)return tostring(values[key]or"")end))
end

function Service:_worldCupNewsEntry(state:any,fixture:any):any
	self:_worldCupEnsureTeamRanks(state)
	local home=tostring(fixture.Home or"")
	local away=tostring(fixture.Away or"")
	local hg=tonumber(fixture.HomeGoals)or 0
	local ag=tonumber(fixture.AwayGoals)or 0
	local winner=hg>ag and home or ag>hg and away or nil
	local loser=winner==home and away or winner==away and home or nil
	local minute=5+(((tonumber(state.SimIndex)or 1)*17+#home*3+#away*5)%82)
	local day=tonumber(fixture.Matchday)or tonumber(state.GroupMatchIndex)or 1
	local homeRank=tonumber(state.TeamRank and state.TeamRank[home])or 32
	local awayRank=tonumber(state.TeamRank and state.TeamRank[away])or 32
	local values={teamA=home,teamB=away,minute=minute,score=tostring(hg).."-"..tostring(ag),scoreA=tostring(math.max(hg,ag)),scoreB=tostring(math.min(hg,ag))}
	if winner then
		local winnerRank=tonumber(state.TeamRank and state.TeamRank[winner])or 32
		local loserRank=tonumber(state.TeamRank and state.TeamRank[loser])or 32
		local rankDiff=winnerRank-loserRank
		local upset=rankDiff>=7
		values.winner=winner;values.loser=loser;values.rankLine=string.format("%s ranked #%d, %s ranked #%d",winner,winnerRank,loser,loserRank)
		local seed=(tonumber(state.SimIndex)or 1)+#winner*11+#loser*7+day*23
		local title=upset and"Shock Result"or WORLD_CUP_STORY_TITLES[(seed%#WORLD_CUP_STORY_TITLES)+1]
		local descriptions=WORLD_CUP_STORY_DESCRIPTIONS[title]or WORLD_CUP_STORY_OPENERS
		local narrative=descriptions[(seed%#descriptions)+1]
		local summary=wcFill(narrative.." "..WORLD_CUP_STORY_DETAILS[((seed*3)%#WORLD_CUP_STORY_DETAILS)+1],values)
		local headline=string.format("GAMEDAY %d  /  %s defeat %s %d-%d%s  /  #%d vs #%d  /  winner at '%d",day,winner,loser,math.max(hg,ag),math.min(hg,ag),upset and" in a shock result"or"",winnerRank,loserRank,minute)
		return{Headline=headline,Title=title,Description=summary,Summary=summary,Matchday=day,Home=home,Away=away,HomeGoals=hg,AwayGoals=ag,Winner=winner,Loser=loser,Minute=minute,WinnerRank=winnerRank,LoserRank=loserRank,RankDiff=rankDiff,Upset=upset}
	end
	values.rankLine=string.format("%s ranked #%d, %s ranked #%d",home,homeRank,away,awayRank)
	local seed=(tonumber(state.SimIndex)or 1)+#home*5+#away*13+day*19
	local title=hg==0 and"Goalless Battle"or"Tense Draw"
	local descriptions=hg==0 and(WORLD_CUP_STORY_DESCRIPTIONS["Goalless Battle"]or WORLD_CUP_DRAW_OPENERS)or WORLD_CUP_DRAW_OPENERS
	local summary=wcFill(descriptions[(seed%#descriptions)+1].." "..WORLD_CUP_STORY_DETAILS[((seed*5)%#WORLD_CUP_STORY_DETAILS)+1],values)
	return{Headline=string.format("GAMEDAY %d  /  %s and %s draw %d-%d  /  #%d vs #%d",day,home,away,hg,ag,homeRank,awayRank),Title=title,Description=summary,Summary=summary,Matchday=day,Home=home,Away=away,HomeGoals=hg,AwayGoals=ag,Minute=minute,HomeRank=homeRank,AwayRank=awayRank}
end

function Service:_worldCupAddNews(state:any,fixture:any)
	state.News=type(state.News)=="table"and state.News or{}
	table.insert(state.News,1,self:_worldCupNewsEntry(state,fixture))
	while #state.News>18 do table.remove(state.News)end
end

function Service:_worldCupRankGroup(state:any,groupName:string):{string}
	local group=state.Groups and state.Groups[groupName]or{};local ranked=table.clone(group)
	table.sort(ranked,function(a,b)
		local sa=self:_worldCupEnsureStanding(state,a);local sb=self:_worldCupEnsureStanding(state,b)
		if sa.PTS~=sb.PTS then return sa.PTS>sb.PTS end
		if sa.GD~=sb.GD then return sa.GD>sb.GD end
		if sa.GF~=sb.GF then return sa.GF>sb.GF end
		return a<b
	end)
	return ranked
end

function Service:_worldCupSimScore(state:any,home:string,away:string):(number,number)
	self:_worldCupEnsureTeamRanks(state)
	local random=Random.new((tonumber(state.Seed)or 1)+#tostring(home)*13+#tostring(away)*31+(tonumber(state.SimIndex)or 0)*97)
	state.SimIndex=(tonumber(state.SimIndex)or 0)+1
	local homeO=(state.TeamOverall and state.TeamOverall[home]) or 76;local awayO=(state.TeamOverall and state.TeamOverall[away]) or 76
	local homeRank=tonumber(state.TeamRank and state.TeamRank[home])or 24
	local awayRank=tonumber(state.TeamRank and state.TeamRank[away])or 24
	local overallEdge=(homeO-awayO)/16
	local rankEdge=(awayRank-homeRank)/18
	local upsetSwing=random:NextNumber(-1.15,1.15)
	local tempo=random:NextNumber(.15,1.05)
	local h=math.clamp(math.floor(random:NextNumber(0,2.45)+tempo+overallEdge+rankEdge+upsetSwing*.45),0,5)
	local a=math.clamp(math.floor(random:NextNumber(0,2.45)+tempo-overallEdge-rankEdge-upsetSwing*.45),0,5)
	if random:NextNumber()<.1 then
		if h>a then a=math.min(5,a+1)elseif a>h then h=math.min(5,h+1)end
	end
	return h,a
end

function Service:_worldCupResolveKnockoutTie(state:any,fixture:any,homeGoals:number,awayGoals:number):any
	if homeGoals~=awayGoals then
		return{HomeGoals=homeGoals,AwayGoals=awayGoals,Winner=homeGoals>awayGoals and fixture.Home or fixture.Away,ExtraTime=false,Penalties=false,ExtraHomeGoals=0,ExtraAwayGoals=0,Shootout=nil}
	end
	local home=tostring(fixture.Home or"")
	local away=tostring(fixture.Away or"")
	local random=Random.new((tonumber(state.Seed)or 1)+#home*211+#away*307+(tonumber(state.SimIndex)or 1)*401+homeGoals*23)
	local homeO=(state.TeamOverall and state.TeamOverall[home])or 76
	local awayO=(state.TeamOverall and state.TeamOverall[away])or 76
	local homeRank=tonumber(state.TeamRank and state.TeamRank[home])or 24
	local awayRank=tonumber(state.TeamRank and state.TeamRank[away])or 24
	local edge=(homeO-awayO)/18+(awayRank-homeRank)/24
	local extraHome=0
	local extraAway=0
	if random:NextNumber()<.58 then
		if random:NextNumber()+edge*.16>=.5 then extraHome=1 else extraAway=1 end
		if random:NextNumber()<.12 then
			if extraHome>extraAway then extraAway+=1 else extraHome+=1 end
		end
	end
	local finalHome=homeGoals+extraHome
	local finalAway=awayGoals+extraAway
	if finalHome~=finalAway then
		return{HomeGoals=finalHome,AwayGoals=finalAway,Winner=finalHome>finalAway and home or away,ExtraTime=true,Penalties=false,ExtraHomeGoals=extraHome,ExtraAwayGoals=extraAway,Shootout=nil}
	end
	local homePens=0
	local awayPens=0
	local rounds={}
	for round=1,5 do
		local homeScore=random:NextNumber()<math.clamp(.74+edge*.035,.58,.88)
		local awayScore=random:NextNumber()<math.clamp(.74-edge*.035,.58,.88)
		if homeScore then homePens+=1 end
		if awayScore then awayPens+=1 end
		table.insert(rounds,{Round=round,HomeScored=homeScore,AwayScored=awayScore,HomeScore=homePens,AwayScore=awayPens})
	end
	local round=5
	while homePens==awayPens and round<10 do
		round+=1
		local homeScore=random:NextNumber()<math.clamp(.72+edge*.035,.55,.88)
		local awayScore=random:NextNumber()<math.clamp(.72-edge*.035,.55,.88)
		if homeScore then homePens+=1 end
		if awayScore then awayPens+=1 end
		table.insert(rounds,{Round=round,HomeScored=homeScore,AwayScored=awayScore,HomeScore=homePens,AwayScore=awayPens})
	end
	if homePens==awayPens then
		if edge>=0 then homePens+=1 else awayPens+=1 end
		table.insert(rounds,{Round=round+1,HomeScored=edge>=0,AwayScored=edge<0,HomeScore=homePens,AwayScore=awayPens})
	end
	return{HomeGoals=finalHome,AwayGoals=finalAway,Winner=homePens>awayPens and home or away,ExtraTime=true,Penalties=true,ExtraHomeGoals=extraHome,ExtraAwayGoals=extraAway,Shootout={HomePens=homePens,AwayPens=awayPens,Rounds=rounds,Winner=homePens>awayPens and home or away}}
end

function Service:_worldCupGoalEvents(state:any,home:string,away:string,homeGoals:number,awayGoals:number,extra:any?):{any}
	local function attackers(country:string):{any}
		local roster=buildWorldCupNationalRoster(country)
		local players={}
		for _,player in ipairs(roster.StartingXI or{})do
			if player and player.bestPosition~="GK"then table.insert(players,player)end
		end
		if #players==0 then players=roster.BestPlayers or{}end
		return players
	end
	local homePlayers=attackers(home)
	local awayPlayers=attackers(away)
	local random=Random.new((tonumber(state.Seed)or 1)+#home*41+#away*59+(tonumber(state.SimIndex)or 1)*131+homeGoals*17+awayGoals*23)
	local events={}
	local usedMinutes:{[number]:boolean}={}
	local function playerName(player:any):string
		return tostring(player and(player.shortName or player.displayName or player.playerId)or"SCORER")
	end
	local function uniqueGoalMinute(preferred:number):number
		local maxGoalMinute=preferred>90 and 120 or 90
		local minute=math.clamp(math.floor(preferred),2,maxGoalMinute)
		if not usedMinutes[minute]then usedMinutes[minute]=true;return minute end
		for offset=1,16 do
			local later=math.clamp(minute+offset,2,maxGoalMinute)
			if not usedMinutes[later]then usedMinutes[later]=true;return later end
			local earlier=math.clamp(minute-offset,2,maxGoalMinute)
			if not usedMinutes[earlier]then usedMinutes[earlier]=true;return earlier end
		end
		for fallback=2,maxGoalMinute do
			if not usedMinutes[fallback]then usedMinutes[fallback]=true;return fallback end
		end
		return minute
	end
	local function addGoals(team:string,side:string,count:number,players:{any},base:number,spread:number)
		for index=1,count do
			local lateBoost=random:NextNumber()<.28
			local preferred=lateBoost and random:NextInteger(80,90) or(base+index*math.floor(spread/(count+1))+random:NextInteger(-4,5))
			local minute=uniqueGoalMinute(preferred)
			local scorer=worldCupWeightedPlayer(players,random)
			local assister=nil
			if #players>1 and random:NextNumber()<.68 then
				for _=1,6 do
					local candidate=worldCupWeightedPlayer(players,random,scorer)
					if candidate~=scorer then assister=candidate;break end
				end
			end
			table.insert(events,{Team=team,Side=side,Minute=minute,Scorer=playerName(scorer),Assister=assister and playerName(assister)or nil})
		end
	end
	addGoals(home,"Home",homeGoals,homePlayers,7,76)
	addGoals(away,"Away",awayGoals,awayPlayers,9,74)
	if type(extra)=="table"then
		local extraHome=math.max(0,math.floor(tonumber(extra.Home)or 0))
		local extraAway=math.max(0,math.floor(tonumber(extra.Away)or 0))
		for index=1,extraHome do
			local minute=uniqueGoalMinute(random:NextInteger(index==1 and 95 or 108,119))
			local scorer=worldCupWeightedPlayer(homePlayers,random)
			table.insert(events,{Team=home,Side="Home",Minute=minute,Scorer=playerName(scorer),Assister=nil,ExtraTime=true})
		end
		for index=1,extraAway do
			local minute=uniqueGoalMinute(random:NextInteger(index==1 and 96 or 109,120))
			local scorer=worldCupWeightedPlayer(awayPlayers,random)
			table.insert(events,{Team=away,Side="Away",Minute=minute,Scorer=playerName(scorer),Assister=nil,ExtraTime=true})
		end
	end
	table.sort(events,function(a,b)if a.Minute==b.Minute then return tostring(a.Team)<tostring(b.Team)end;return a.Minute<b.Minute end)
	return events
end

function Service:_worldCupTrackMatchLeaders(state:any,fixture:any,events:{any})
	if type(state)~="table"or type(fixture)~="table"or fixture.LeadersTracked==true then return end
	state.Leaderboards=type(state.Leaderboards)=="table"and state.Leaderboards or{Goals={},Assists={},MOTM={}}
	local boards=state.Leaderboards
	boards.Goals=type(boards.Goals)=="table"and boards.Goals or{}
	boards.Assists=type(boards.Assists)=="table"and boards.Assists or{}
	boards.MOTM=type(boards.MOTM)=="table"and boards.MOTM or{}
	local function add(board:any,name:string,team:string,amount:number)
		if name==""then return end
		local key=team.."|"..name
		local entry=board[key]or{Name=name,Team=team,Count=0}
		entry.Count=(tonumber(entry.Count)or 0)+amount
		board[key]=entry
	end
	local bestGoal=nil
	for _,event in ipairs(events or{})do
		local team=tostring(event.Team or"")
		local scorer=tostring(event.Scorer or"")
		local assister=tostring(event.Assister or"")
		if scorer~=""then add(boards.Goals,scorer,team,1);bestGoal=bestGoal or event end
		if assister~=""then add(boards.Assists,assister,team,1)end
	end
	local motmName=""
	local motmTeam=""
	if bestGoal then
		motmName=tostring(bestGoal.Scorer or"")
		motmTeam=tostring(bestGoal.Team or"")
	else
		local winner=tostring(fixture.Winner or((tonumber(fixture.HomeGoals)or 0)>=(tonumber(fixture.AwayGoals)or 0)and fixture.Home or fixture.Away)or"")
		local roster=buildWorldCupNationalRoster(winner)
		local player=(roster.BestPlayers and roster.BestPlayers[1])or(roster.StartingXI and roster.StartingXI[1])
		motmName=tostring(player and(player.shortName or player.displayName)or(winner.." CAPTAIN"))
		motmTeam=winner
	end
	add(boards.MOTM,motmName,motmTeam,1)
	fixture.GoalEvents=events
	fixture.LeadersTracked=true
end

function Service:_worldCupSimFixture(state:any,fixture:any)
	if fixture.Played then return end
	local hg,ag=self:_worldCupSimScore(state,fixture.Home,fixture.Away)
	fixture.HomeGoals=hg;fixture.AwayGoals=ag;fixture.Played=true;fixture.Simulated=true
	fixture.GoalEvents=self:_worldCupGoalEvents(state,fixture.Home,fixture.Away,hg,ag)
	self:_worldCupTrackMatchLeaders(state,fixture,fixture.GoalEvents)
	self:_worldCupRecord(state,fixture.Home,fixture.Away,hg,ag)
	self:_worldCupAddNews(state,fixture)
end

function Service:_worldCupEnsureFixtureDays(state:any)
	local roundPairs={{{1,2},{3,4}},{{1,3},{2,4}},{{1,4},{2,3}}}
	for groupName,group in state.Groups or{}do
		local fixtures=state.Fixtures and state.Fixtures[groupName]or{}
		for day,pairs in ipairs(roundPairs)do
			for _,pair in ipairs(pairs)do
				local home=group[pair[1]]
				local away=group[pair[2]]
				for _,fixture in ipairs(fixtures)do
					if fixture.Home==home and fixture.Away==away then
						fixture.Matchday=fixture.Matchday or day
					end
				end
			end
		end
	end
end

function Service:_worldCupCanonicalFixture(state:any,fixture:any):any
	if type(state)~="table"or type(fixture)~="table"then return fixture end
	local function syncPlayed(candidate:any)
		if type(candidate)~="table"then return end
		if fixture.Played==true and candidate.Played~=true then
			candidate.HomeGoals=fixture.HomeGoals
			candidate.AwayGoals=fixture.AwayGoals
			candidate.Played=true
			candidate.UserPlayed=fixture.UserPlayed
			candidate.Simulated=fixture.Simulated
			candidate.Winner=fixture.Winner
		end
	end
	if state.Stage=="Group"then
		self:_worldCupEnsureFixtureDays(state)
		local groupName=tostring(fixture.Group or state.UserGroup or"")
		local fixtures=state.Fixtures and state.Fixtures[groupName]or{}
		local matchday=tonumber(fixture.Matchday)
		for _,candidate in ipairs(fixtures)do
			if candidate.Home==fixture.Home and candidate.Away==fixture.Away and (not matchday or tonumber(candidate.Matchday)==matchday)then
				syncPlayed(candidate)
				return candidate
			end
		end
	elseif state.Knockout and type(state.Knockout.Fixtures)=="table"then
		local round=tonumber(fixture.Round)or tonumber(state.Knockout.Round)
		for _,candidate in ipairs(state.Knockout.Fixtures)do
			if candidate.Home==fixture.Home and candidate.Away==fixture.Away and (not round or tonumber(candidate.Round)==round)then
				syncPlayed(candidate)
				return candidate
			end
		end
	end
	return fixture
end

function Service:_worldCupRepairGroupNextFixture(state:any)
	if type(state)~="table"or state.Stage~="Group"then return end
	self:_worldCupEnsureTeamRanks(state)
	self:_worldCupEnsureFixtureDays(state)
	local selected=tostring(state.SelectedCountry or"")
	local groupName=tostring(state.UserGroup or"")
	local fixtures=state.Fixtures and state.Fixtures[groupName]or{}
	if type(state.NextFixture)=="table"then
		state.NextFixture=self:_worldCupCanonicalFixture(state,state.NextFixture)
	end
	local playedOpponents={}
	for _,fixture in ipairs(fixtures)do
		if fixture.UserFixture and fixture.Played then
			local opponent=fixture.Home==selected and fixture.Away or fixture.Home
			playedOpponents[opponent]=true
		end
	end
	if type(state.NextFixture)=="table"and state.NextFixture.UserFixture and not state.NextFixture.Played then
		local opponent=state.NextFixture.Home==selected and state.NextFixture.Away or state.NextFixture.Home
		if not playedOpponents[opponent] then return end
	end
	for day=1,3 do
		for _,fixture in ipairs(fixtures)do
			if fixture.UserFixture and not fixture.Played and tonumber(fixture.Matchday)==day then
				local opponent=fixture.Home==selected and fixture.Away or fixture.Home
				if not playedOpponents[opponent] then state.NextFixture=fixture;state.GroupMatchIndex=day;return end
			end
		end
	end
	for _,groupFixtures in state.Fixtures or{}do
		for _,fixture in ipairs(groupFixtures)do
			if not fixture.Played then self:_worldCupSimFixture(state,fixture)end
		end
	end
	local ranked=self:_worldCupRankGroup(state,groupName)
	state.GroupRank=table.find(ranked,selected)or 4
	if state.GroupRank<=2 then
		self:_worldCupBuildKnockout(state)
	else
		state.Stage="Eliminated"
		state.NextFixture=nil
	end
end

function Service:_worldCupBuildKnockout(state:any)
	local qualifiers={}
	for _,groupName in WorldCupConfig.GroupNames do local ranked=self:_worldCupRankGroup(state,groupName);qualifiers[groupName]={ranked[1],ranked[2]}end
	local function seed(group:string,rank:number):string return qualifiers[group] and qualifiers[group][rank] or state.SelectedCountry end
	state.Knockout={Round=1,Fixtures={
		{Home=seed("A",1),Away=seed("B",2),Round=1},{Home=seed("C",1),Away=seed("D",2),Round=1},{Home=seed("E",1),Away=seed("F",2),Round=1},{Home=seed("G",1),Away=seed("H",2),Round=1},
		{Home=seed("B",1),Away=seed("A",2),Round=1},{Home=seed("D",1),Away=seed("C",2),Round=1},{Home=seed("F",1),Away=seed("E",2),Round=1},{Home=seed("H",1),Away=seed("G",2),Round=1},
	},History={}}
	state.Stage="Knockout"
	self:_worldCupPrepareNextKnockout(state)
end

function Service:_worldCupPrepareNextKnockout(state:any)
	local selected=state.SelectedCountry
	local fixtures=state.Knockout and state.Knockout.Fixtures or{}
	for _,fixture in fixtures do
		if not fixture.Played and(fixture.Home==selected or fixture.Away==selected)then state.NextFixture=fixture;return end
	end
	local winners={}
	for _,fixture in fixtures do
		if not fixture.Played then
			local hg,ag=self:_worldCupSimScore(state,fixture.Home,fixture.Away)
			local resolution=self:_worldCupResolveKnockoutTie(state,fixture,hg,ag)
			fixture.RegulationHomeGoals=hg;fixture.RegulationAwayGoals=ag;fixture.HomeGoals=resolution.HomeGoals;fixture.AwayGoals=resolution.AwayGoals;fixture.Played=true;fixture.Simulated=true;fixture.Winner=resolution.Winner;fixture.ExtraTime=resolution.ExtraTime;fixture.Penalties=resolution.Penalties;fixture.Shootout=resolution.Shootout
			fixture.GoalEvents=self:_worldCupGoalEvents(state,fixture.Home,fixture.Away,hg,ag,{Home=resolution.ExtraHomeGoals,Away=resolution.ExtraAwayGoals})
			self:_worldCupTrackMatchLeaders(state,fixture,fixture.GoalEvents)
		end
		table.insert(winners,fixture.Winner)
	end
	local round=tonumber(state.Knockout.Round)or 1
	if not table.find(winners,selected)then state.Stage="Eliminated";state.NextFixture=nil;return end
	if round>=4 then state.Stage="Champion";state.WorldCupWinner=selected;state.NextFixture=nil;return end
	local nextFixtures={}
	for index=1,#winners,2 do table.insert(nextFixtures,{Home=winners[index],Away=winners[index+1],Round=round+1})end
	table.insert(state.Knockout.History,{Round=round,Fixtures=fixtures})
	state.Knockout.Round=round+1;state.Knockout.Fixtures=nextFixtures
	self:_worldCupPrepareNextKnockout(state)
end

function Service:_worldCupSimulateKnockoutToChampion(state:any):string?
	if not state.Knockout then self:_worldCupBuildKnockout(state)end
	local knockout=state.Knockout
	if not knockout then return nil end
	knockout.History=type(knockout.History)=="table"and knockout.History or{}
	local round=tonumber(knockout.Round)or 1
	local fixtures=knockout.Fixtures or{}
	while round<=4 and #fixtures>0 do
		local winners={}
		for _,fixture in ipairs(fixtures)do
			if not fixture.Played then
				local hg,ag=self:_worldCupSimScore(state,fixture.Home,fixture.Away)
				local resolution=self:_worldCupResolveKnockoutTie(state,fixture,hg,ag)
				fixture.RegulationHomeGoals=hg;fixture.RegulationAwayGoals=ag;fixture.HomeGoals=resolution.HomeGoals;fixture.AwayGoals=resolution.AwayGoals;fixture.Played=true;fixture.Simulated=true;fixture.Winner=resolution.Winner;fixture.ExtraTime=resolution.ExtraTime;fixture.Penalties=resolution.Penalties;fixture.Shootout=resolution.Shootout
				fixture.GoalEvents=self:_worldCupGoalEvents(state,fixture.Home,fixture.Away,hg,ag,{Home=resolution.ExtraHomeGoals,Away=resolution.ExtraAwayGoals})
				self:_worldCupTrackMatchLeaders(state,fixture,fixture.GoalEvents)
			end
			table.insert(winners,fixture.Winner)
		end
		if round>=4 then
			knockout.Round=4
			knockout.Fixtures=fixtures
			state.WorldCupWinner=winners[1]
			state.RestSimulated=true
			return winners[1]
		end
		table.insert(knockout.History, {Round=round,Fixtures=fixtures})
		local nextFixtures={}
		for index=1,#winners,2 do table.insert(nextFixtures,{Home=winners[index],Away=winners[index+1],Round=round+1})end
		round+=1
		knockout.Round=round
		knockout.Fixtures=nextFixtures
		fixtures=nextFixtures
	end
	state.RestSimulated=true
	return state.WorldCupWinner
end

function Service:_worldCupAdvanceAfterMatch(state:any,homeGoals:number,awayGoals:number)
	local fixture=state.NextFixture;if type(fixture)~="table"then return end
	fixture=self:_worldCupCanonicalFixture(state,fixture)
	state.NextFixture=fixture
	if fixture.Played==true then
		if state.Stage=="Group"then
			self:_worldCupRepairGroupNextFixture(state)
		else
			self:_worldCupPrepareNextKnockout(state)
		end
		return
	end
	fixture.HomeGoals=homeGoals;fixture.AwayGoals=awayGoals;fixture.Played=true;fixture.UserPlayed=true
	if type(fixture.GoalEvents)~="table"then fixture.GoalEvents=self:_worldCupGoalEvents(state,fixture.Home,fixture.Away,homeGoals,awayGoals)end
	self:_worldCupTrackMatchLeaders(state,fixture,fixture.GoalEvents)
	if state.Stage=="Group"then
		self:_worldCupEnsureFixtureDays(state)
		self:_worldCupRecord(state,fixture.Home,fixture.Away,homeGoals,awayGoals)
		self:_worldCupAddNews(state,fixture)
		local groupFixtures=state.Fixtures and state.Fixtures[fixture.Group]or{}
		local currentDay=tonumber(fixture.Matchday)or tonumber(state.GroupMatchIndex)or 1
		for _,fixtures in state.Fixtures or{}do
			for _,other in fixtures do
				if not other.UserFixture and tonumber(other.Matchday)==currentDay then self:_worldCupSimFixture(state,other)end
			end
		end
		state.GroupMatchIndex=currentDay+1
		local selected=state.SelectedCountry;local nextFixture=nil
		for day=currentDay+1,3 do
			for _,other in groupFixtures do if other.UserFixture and not other.Played and tonumber(other.Matchday)==day then nextFixture=other;break end end
			if nextFixture then break end
		end
		if not nextFixture then for _,other in groupFixtures do if other.UserFixture and not other.Played then nextFixture=other;break end end end
		if nextFixture then state.NextFixture=nextFixture;return end
		local ranked=self:_worldCupRankGroup(state,fixture.Group)
		state.GroupRank=table.find(ranked,selected)or 4
		if state.GroupRank<=2 then self:_worldCupBuildKnockout(state)else state.Stage="Eliminated";state.NextFixture=nil end
	else
		local selected=state.SelectedCountry
		local resolvedWinner=type(fixture.Winner)=="string"and fixture.Winner or nil
		local userWon=resolvedWinner and resolvedWinner==selected or (fixture.Home==selected and homeGoals>awayGoals)or(fixture.Away==selected and awayGoals>homeGoals)or homeGoals==awayGoals
		fixture.Winner=resolvedWinner or(userWon and selected or(fixture.Home==selected and fixture.Away or fixture.Home))
		if not userWon then state.Stage="Eliminated";state.NextFixture=nil;return end
		self:_worldCupPrepareNextKnockout(state)
	end
end

function Service:_worldCupStageLabel(state:any):string
	if not state then return "NOT STARTED"end
	if state.Stage=="Champion"then return "CHAMPIONS"end
	if state.Stage=="Eliminated"then
		if tonumber(state.GroupRank)and state.GroupRank>2 then return "GROUP STAGE"end
		local round=state.Knockout and tonumber(state.Knockout.Round)or 1
		return WorldCupConfig.KnockoutRounds[round]or"KNOCKOUTS"
	end
	return tostring(state.Stage or"IN PROGRESS")
end

function Service:_worldCupRewardForState(state:any):any
	local reached=self:_worldCupStageLabel(state)
	local simulated=math.max(0,math.floor(tonumber(state.SimulatedMatches)or 0))
	local played=math.max(0,math.floor(tonumber(state.PlayedMatches)or 0))
	local goalsFor=math.max(0,math.floor(tonumber(state.UserGoalsFor)or 0))
	local goalsAgainst=math.max(0,math.floor(tonumber(state.UserGoalsAgainst)or 0))
	local tiers={
		{PackId="bronze_pack",Name="Bronze Pack"},
		{PackId="silver_pack",Name="Silver Pack"},
		{PackId="gold_pack",Name="Gold Pack"},
		{PackId="rare_pack",Name="Rare Pack"},
		{PackId="elite_pack",Name="Elite Pack"},
		{PackId="legendary_pack",Name="Legendary Pack"},
		{PackId="icon_pack",Name="Icon Pack"},
		{PackId="mythic_pack",Name="Mythic Pack"},
	}
	local baseTier=2
	if reached=="GROUP STAGE"then baseTier=2
	elseif reached=="Round of 16"then baseTier=3
	elseif reached=="Quarter Final"then baseTier=4
	elseif reached=="Semi Final"then baseTier=5
	elseif reached=="Final"then baseTier=6
	elseif reached=="CHAMPIONS"then baseTier=7 end
	local playBonus=math.floor(played/2)
	local simPenalty=math.floor((simulated+1)/2)
	if played>=3 then playBonus+=1 end
	if played>=5 then playBonus+=1 end
	if simulated==0 and played>0 then playBonus+=1 end
	local tierIndex=math.clamp(baseTier+playBonus-simPenalty,1,#tiers)
	local primary=tiers[tierIndex]
	local packs={{PackId=primary.PackId,Name=primary.Name,Quantity=1}}
	if reached=="CHAMPIONS"then
		packs={{PackId="icon_pack",Name="Icon Pack",Quantity=1}}
		if played>=4 then
			table.insert(packs,{PackId=played>=6 and"mythic_pack"or"voltra_pack",Name=played>=6 and"Mythic Pack"or"Voltra Pack",Quantity=1})
		elseif simulated<=2 then
			table.insert(packs,{PackId="voltra_pack",Name="Voltra Pack",Quantity=1})
		else
			table.insert(packs,{PackId="elite_pack",Name="Elite Pack",Quantity=1})
		end
	elseif played>=4 and simulated<=1 and tierIndex<#tiers then
		local bonus=tiers[math.min(#tiers,tierIndex+1)]
		table.insert(packs,{PackId=bonus.PackId,Name=bonus.Name,Quantity=1})
	end
	local playLine=played>simulated and"Manual matches boosted your reward tier."or simulated>played and"Simulated matches reduced the final pack tier."or"Played and simulated matches were balanced in the reward score."
	local analysis=string.format("Reached %s with %d played match%s and %d simulated match%s. %s Your run finished with %d goal%s scored and %d conceded.",reached,played,played==1 and""or"es",simulated,simulated==1 and""or"es",playLine,goalsFor,goalsFor==1 and""or"s",goalsAgainst)
	return{Id="wc_"..tostring(state.CreatedAt or os.time()),Reached=reached,Packs=packs,Analysis=analysis,SimulatedMatches=simulated,PlayedMatches=played,GoalsFor=goalsFor,GoalsAgainst=goalsAgainst,RewardTier=tierIndex,PlayedBonus=playBonus,SimulationPenalty=simPenalty}
end

function Service:_archiveWorldCup(profile:any)
	local state=type(profile.WorldCup)=="table"and profile.WorldCup or nil
	if not state or state.Archived==true then return end
	if state.Stage~="Champion"and state.Stage~="Eliminated"then return end
	profile.WorldCupHistory=type(profile.WorldCupHistory)=="table"and profile.WorldCupHistory or{}
	self:_recordWorldCupQuestCareer(profile,state)
	state.Archived=true
	state.PendingRewards=state.PendingRewards or self:_worldCupRewardForState(state)
	table.insert(profile.WorldCupHistory,1,{Country=state.SelectedCountry,Code=state.SelectedCode,Reached=self:_worldCupStageLabel(state),Stage=state.Stage,GroupRank=state.GroupRank,Winner=state.WorldCupWinner,FinishedAt=os.time(),Rewards=state.PendingRewards})
	while #profile.WorldCupHistory>8 do table.remove(profile.WorldCupHistory)end
end

function Service:ClaimWorldCupRewards(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	self:_consumeWorldCupRuntimeResult(player,profile)
	local state=type(profile.WorldCup)=="table"and profile.WorldCup or nil
	if not state or (state.Stage~="Champion"and state.Stage~="Eliminated")then return false,"Finish a World Cup run first.",self:_worldCupPublic(profile)end
	local reward=state.PendingRewards or self:_worldCupRewardForState(state)
	if state.RewardsClaimed==true then return false,"World Cup rewards already claimed.",self:_worldCupPublic(profile)end
	local granted={}
	for _,pack in ipairs(reward.Packs or{})do
		local packId=tostring(pack.PackId or"")
		local quantity=math.clamp(math.floor(tonumber(pack.Quantity)or 1),1,5)
		if self.Progression and self.Progression.Inventory and packId~=""then
			local ok,instances=self.Progression.Inventory:AddPack(player,packId,tostring(pack.Name or packId),"WorldCup",quantity)
			if ok then table.insert(granted,{PackId=packId,Name=pack.Name or packId,Quantity=quantity,Instances=instances})end
		end
	end
	state.PendingRewards=reward
	state.RewardsClaimed=true
	if self.Profiles.Save then self.Profiles:Save(player,true)end
	return true,"World Cup rewards claimed.",{WorldCup=self:_worldCupPublic(profile),Reward=reward,Granted=granted}
end

function Service:ClaimWorldCupQuest(player:Player,questId:string):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local definition=WorldCupQuestConfig.ById[tostring(questId or"")]
	if not definition then return false,"Unknown World Cup quest.",self:_worldCupPublic(profile)end
	self:_refreshWorldCupQuests(profile)
	local quests=questProfile(profile)
	if quests.Claimed[definition.Id]==true then return false,"Quest reward already claimed.",self:_worldCupPublic(profile)end
	local progress=tonumber(quests.Progress[definition.Id])or 0
	local target=tonumber(definition.Target)or 1
	if progress<target then return false,"Quest is not complete yet.",self:_worldCupPublic(profile)end
	local packId=tostring(definition.PackId or"bronze_pack")
	local granted=nil
	if self.Progression and self.Progression.Inventory then
		local ok,instances=self.Progression.Inventory:AddPack(player,packId,WorldCupQuestConfig.PackName(packId),"WorldCupQuest",1)
		if ok then granted={PackId=packId,Name=WorldCupQuestConfig.PackName(packId),Quantity=1,Instances=instances};VTRPendingPackAnimation.Queue(player,packId)end
	end
	quests.Claimed[definition.Id]=true
	if self.Profiles.Save then self.Profiles:Save(player,true)end
	self.Publish(player,"Progression",self.Progression:GetClientData(player))
	return true,"World Cup quest reward claimed.",{WorldCup=self:_worldCupPublic(profile),QuestId=definition.Id,Granted=granted}
end

function Service:BeginWorldCup(player:Player,country:string):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	if type(country)~="string"or not table.find(WorldCupConfig.Countries,country)then return false,"Choose a valid World Cup nation.",nil end
	local random=Random.new(os.time()+player.UserId)
	local ranked=table.clone(WorldCupConfig.Countries)
	table.sort(ranked,function(a:string,b:string)
		local ar=WorldCupConfig.Ranking(a)
		local br=WorldCupConfig.Ranking(b)
		if ar~=br then return ar<br end
		return a<b
	end)
	local countries={}
	local included:{[string]:boolean}={}
	for _,rankedCountry in ipairs(ranked)do
		if #countries>=13 then break end
		if table.find(WorldCupConfig.Countries,rankedCountry)then
			table.insert(countries,rankedCountry)
			included[rankedCountry]=true
		end
	end
	if not included[country]then
		table.insert(countries,country)
		included[country]=true
	end
	local pool={}
	for _,candidate in ipairs(WorldCupConfig.Countries)do
		if not included[candidate]then table.insert(pool,candidate)end
	end
	for index=#pool,2,-1 do local swap=random:NextInteger(1,index);pool[index],pool[swap]=pool[swap],pool[index]end
	for _,candidate in ipairs(pool)do
		if #countries>=32 then break end
		table.insert(countries,candidate)
		included[candidate]=true
	end
	for index=#countries,2,-1 do
		local swap=random:NextInteger(1,index)
		countries[index],countries[swap]=countries[swap],countries[index]
	end
	local state={Active=true,SelectedCountry=country,SelectedCode=wcCode(country),Seed=os.time()+player.UserId,Stage="Group",Groups={},Fixtures={},Standings={},TeamIds={},TeamOverall={},GroupMatchIndex=1,CreatedAt=os.time(),SimIndex=0}
	for index,groupName in WorldCupConfig.GroupNames do state.Groups[groupName]={};state.Fixtures[groupName]={};for slot=1,4 do local teamCountry=countries[(index-1)*4+slot];local roster=buildWorldCupNationalRoster(teamCountry);table.insert(state.Groups[groupName],teamCountry);state.TeamIds[teamCountry]=roster.Team.teamId;state.TeamOverall[teamCountry]=tonumber(roster.Team.overall)or 76;self:_worldCupEnsureStanding(state,teamCountry)end end
	self:_worldCupEnsureTeamRanks(state)
	for groupName,group in state.Groups do
		local rounds={{{1,2},{3,4}},{{1,3},{2,4}},{{1,4},{2,3}}}
		for matchday,pairs in ipairs(rounds)do
			for _,pair in ipairs(pairs)do local fixture={Group=groupName,Matchday=matchday,Home=group[pair[1]],Away=group[pair[2]],Played=false,UserFixture=group[pair[1]]==country or group[pair[2]]==country};table.insert(state.Fixtures[groupName],fixture)end
		end
	end
	for groupName,group in state.Groups do if table.find(group,country)then state.UserGroup=groupName;for _,fixture in state.Fixtures[groupName]do if fixture.UserFixture then state.NextFixture=fixture;break end end end end
	profile.WorldCup=state;profile.WorldCupPendingMatch=nil;player:SetAttribute("VTRWorldCupPendingId",nil);if self.Profiles.Save then self.Profiles:Save(player,true)end
	return true,"World Cup groups created.",self:_worldCupPublic(profile)
end

function Service:ResetWorldCup(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	profile.WorldCup=nil;profile.WorldCupPendingMatch=nil;if self.Profiles.Save then self.Profiles:Save(player,true)end
	player:SetAttribute("VTRWorldCupPendingId",nil)
	return true,"World Cup reset.",self:_worldCupPublic(profile)
end

function Service:EndWorldCup(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	self:_consumeWorldCupRuntimeResult(player,profile)
	self:_archiveWorldCup(profile)
	profile.WorldCup=nil;profile.WorldCupPendingMatch=nil;if self.Profiles.Save then self.Profiles:Save(player,true)end
	player:SetAttribute("VTRWorldCupPendingId",nil)
	return true,"World Cup ended.",self:_worldCupPublic(profile)
end

function Service:_teleportWorldCupMatch(player:Player):(boolean,string,any?)
	if RunService:IsStudio() or game.PrivateServerId~="" or player:GetAttribute("VTRWorldCupSoloServer")==true then return false,"",nil end
	local lockedUntil=tonumber(self.WorldCupTeleportLocks[player])or 0
	if lockedUntil>os.clock() then return true,"World Cup match already queued.",{Teleporting=true,WorldCup=true,AlreadyQueued=true}end
	self.WorldCupTeleportLocks[player]=os.clock()+18
	local code=nil
	local ok,err=pcall(function()code=TeleportService:ReserveServer(game.PlaceId)end)
	if not ok or not code then self.WorldCupTeleportLocks[player]=nil;return false,"Could not reserve a World Cup match server.",nil end
	local options=Instance.new("TeleportOptions")
	options.ReservedServerAccessCode=code
	options:SetTeleportData({MatchMode="WorldCupSolo",ReturnPlaceId=game.PlaceId,AutoStart=true,DirectIntro=true,WorldCup=true})
	local sent,teleportErr=pcall(function()TeleportService:TeleportAsync(game.PlaceId,{player},options)end)
	if not sent then self.WorldCupTeleportLocks[player]=nil;return false,tostring(teleportErr),nil end
	return true,"World Cup match queued.",{Teleporting=true,WorldCup=true}
end

function Service:_teleportSoloCampaign(player:Player,action:string):(boolean,string,any?)
	if RunService:IsStudio() or game.PrivateServerId~="" or player:GetAttribute("VTRAICampaignSoloServer")==true then return false,"",nil end
	local code=nil
	local ok,err=pcall(function()code=TeleportService:ReserveServer(game.PlaceId)end)
	if not ok or not code then return false,"Could not reserve a solo campaign server.",nil end
	local options=Instance.new("TeleportOptions")
	options.ReservedServerAccessCode=code
	local profile=self.Profiles:GetProfile(player)
	local setupSnapshot=profile and profile.MatchSetup and table.clone(profile.MatchSetup) or nil
	options:SetTeleportData({MatchMode="AICampaignSolo",Action=action,ReturnPlaceId=game.PlaceId,Setup=setupSnapshot,AutoStart=true,DirectIntro=true,Campaign=true})
	local sent,teleportErr=pcall(function()TeleportService:TeleportAsync(game.PlaceId,{player},options)end)
	if not sent then return false,tostring(teleportErr),nil end
	return true,"Teleporting to solo campaign server.",{Teleporting=true,SoloCampaign=true,Action=action}
end

function Service:_tagSoloCampaignSession(player:Player,session:any?)
	if not session or player:GetAttribute("VTRAICampaignSoloServer")~=true then return end
	session.PrivateAICampaignMatch=true
	session.PrivateWorldCupMatch=player:GetAttribute("VTRWorldCupSoloServer")==true
	session.ReturnPlaceId=tonumber(player:GetAttribute("VTRAICampaignReturnPlaceId")) or game.PlaceId
end

function Service:HandleSoloCampaignTeleport(player:Player):boolean
	local joinData=player:GetJoinData()
	local teleportData=joinData and joinData.TeleportData
	if type(teleportData)~="table" or(teleportData.MatchMode~="AICampaignSolo"and teleportData.MatchMode~="WorldCupSolo")then return false end
	local worldCupSolo=teleportData.MatchMode=="WorldCupSolo"
	player:SetAttribute("VTRAICampaignSoloServer",true)
	player:SetAttribute("VTRWorldCupSoloServer",worldCupSolo)
	player:SetAttribute("VTRAICampaignAutoStarting",true)
	player:SetAttribute("VTRAICampaignReturnPlaceId",tonumber(teleportData.ReturnPlaceId) or game.PlaceId)
	task.spawn(function()
		local started=os.clock()
		local action=tostring(teleportData.Action or "Manual")
		while player.Parent==Players and os.clock()-started<45 do
			local profile=self.Profiles:GetProfile(player)
			if profile then
				if type(teleportData.Setup)=="table" then
					profile.MatchSetup=table.clone(teleportData.Setup)
					profile.MatchSetup.Completed=true
				end
				local character=player.Character
				if character and character:FindFirstChildOfClass("Humanoid") then
					local ok,message,data
					if worldCupSolo then
						if player:GetAttribute("VTRWorldCupMatchStarting")==true or player:GetAttribute("VTRWorldCupMatchStarted")==true then
							player:SetAttribute("VTRAICampaignAutoStarting",false)
							player:SetAttribute("VTRAICampaignDirectIntro",true)
							return
						end
						ok,message,data=self:StartWorldCupMatch(player)
					elseif action=="Manage" then
						ok,message,data=self:WatchMatch(player)
					else
						ok,message,data=self:StartMatch(player)
					end
					if ok then
						player:SetAttribute("VTRAICampaignAutoStarting",false)
						player:SetAttribute("VTRAICampaignDirectIntro",true)
						return
					end
				end
			end
			task.wait(.35)
		end
		player:SetAttribute("VTRAICampaignAutoStarting",false)
	end)
	return true
end

function Service:GetClientData(player:Player):any?local profile=self.Profiles:GetProfile(player);if not profile then return nil end;local setup=self:_ensure(profile);local home,away=TeamDatabase.Get(setup.HomeTeamId),TeamDatabase.Get(setup.AwayTeamId);return{Setup=table.clone(setup),Teams={TeamDatabase.Summary(home),TeamDatabase.Summary(away)},Countries=TeamDatabase.GetCountries(),TeamCount=TeamDatabase.Count,Stadiums=MatchConfig.Stadiums,Options={MatchLengths=MatchConfig.MatchLengths,Difficulties=MatchConfig.Difficulties,MatchTypes=MatchConfig.MatchTypes,Weather=MatchConfig.Weather,Times=MatchConfig.Times,KitTypes=MatchConfig.KitTypes}}end
function Service:GetRoster(_player:Player,teamId:string):any?return TeamDatabase.GetRoster(teamId)end
function Service:GetTeams(_player:Player,country:any,league:any):any?if type(country)~="string"or#country>50 or type(league)~="string"or#league>60 then return nil end;return TeamDatabase.GetSummaries(country,league)end
function Service:Save(player:Player,payload:any):(boolean,string,any?)local profile=self.Profiles:GetProfile(player);if not profile or type(payload)~="table"then return false,"Profile unavailable.",nil end;local nextSetup=table.clone(self:_ensure(profile));for key,value in payload do if nextSetup[key]~=nil then nextSetup[key]=value end end;local valid,message=self:_validate(nextSetup);if not valid then return false,message,nil end;nextSetup.Completed=true;nextSetup.SavedAt=os.time();local home,away=TeamDatabase.Get(nextSetup.HomeTeamId),TeamDatabase.Get(nextSetup.AwayTeamId);nextSetup.KitConflict=colorDistance(home.kits[nextSetup.HomeKit].Primary,away.kits[nextSetup.AwayKit].Primary)<.35;profile.MatchSetup=nextSetup;if self.Profiles.Save then self.Profiles:Save(player)end;return true,"Match settings saved.",table.clone(nextSetup)end
function Service:StartMatch(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	if self:_isCampaignMatch(setup) and player:GetAttribute("VTRAICampaignSoloServer")~=true then
		local teleporting,teleportMessage,teleportData=self:_teleportSoloCampaign(player,"Manual")
		if teleporting then return true,teleportMessage,teleportData end
	end
	local homeRoster=nil
	local launchSetup=setup
	if self.RankedSquads then
		local ready,rosterMessage,roster=self.RankedSquads:GetRoster(player)
		if not ready then return false,rosterMessage,nil end
		homeRoster=roster
		launchSetup=table.clone(setup)
		launchSetup.HomeTeamId=roster.Team.teamId
		launchSetup.HomeKit="Home"
	end
	local success,text,data=self.Runtime:StartMatch(player,launchSetup,nil,nil,homeRoster,nil);if not success then return false,text,nil end;if data then data.AIMatchTeleport=true;data.MatchLaunchType="Manual"end
	local session=self.Runtime:GetSession(player);if session then
		self:_tagSoloCampaignSession(player,session)
		local campaignTeamId=tostring(launchSetup.CampaignTeamId or"")
		local campaignTier=math.clamp(tonumber(launchSetup.CampaignTier)or 1,1,#VTRLiteConfig.CampaignDifficulties)
		local campaignReplay=launchSetup.CampaignReplay==true
		session.OnBeforeResult=function(ended:any)
			local homeScore=ended.World.HomeScore.Value
			local awayScore=ended.World.AwayScore.Value
			local homeWon=homeScore>awayScore
			local drew=homeScore==awayScore
			ended.MatchId=ended.MatchId or session.MatchId
			self:_recordCampaignMatchResult(player,launchSetup,ended,homeWon and"Win"or drew and"Draw"or"Loss")
			local coins=650+(homeWon and 650 or drew and 300 or 150)
			local xp=110+(homeWon and 90 or drew and 45 or 20)
			local reward=self.Progression:GrantMatchRewards(player,{Title=homeWon and"VICTORY REWARD"or drew and"DRAW REWARD"or"MATCH REWARD",Coins=coins,XP=xp})
			if homeWon and campaignTeamId~="" then
				local campaignReward=self:_commitCampaignWin(player,campaignTeamId,campaignTier,campaignReplay)
				if campaignReward then
					reward=reward or{}
					for key,value in campaignReward do reward[key]=value end
				end
			end
			return reward and{[player.UserId]=reward}or{}
		end
		session.OnCompleted=function(ended:any)
			local serialized=ended.Stats:Serialize(ended.World.HomeScore.Value,ended.World.AwayScore.Value,ended.Clock:Payload().GameSeconds)
			self.Progression:UpdateObjectivesFromMatch(player,serialized.Home)
		end
	end
	local completed=false;for _,objective in profile.Objectives do if objective.objectiveId=="play_first_match_placeholder"and objective.status~="claimed"then completed=objective.progress<objective.target;objective.progress=1;if objective.status=="active"then objective.status="claimable"end;break end end
	self.Publish(player,"Objective",ObjectiveService.Serialize(profile.Objectives));self.Publish(player,"Progression",self.Progression:GetClientData(player));data.ObjectiveCompletedNow=completed;return true,text,data
end

function Service:StartShootingPractice(player:Player,payload:any?):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local setup=table.clone(self:_ensure(profile))
	local baseRoster:any=nil
	if self.RankedSquads then
		local ready,message,roster=self.RankedSquads:GetRoster(player)
		if not ready then return false,message,nil end
		baseRoster=roster
	end
	baseRoster=baseRoster or TeamDatabase.GetRoster(setup.HomeTeamId)
	if not baseRoster then return false,"Your practice roster is unavailable.",nil end
	local shooter=choosePracticeShooter(baseRoster,payload)
	if not shooter then return false,"Put a striker or outfield player in your Starting XI first.",nil end
	local keeper=choosePracticeKeeper(baseRoster)
	if not keeper then
		local fallback=TeamDatabase.GetRoster(setup.AwayTeamId)
		keeper=fallback and choosePracticeKeeper(fallback)or nil
	end
	if not keeper then return false,"Add a goalkeeper to your squad before starting shooting practice.",nil end
	local homeRoster=practiceRosterFrom(baseRoster,shooter,"shooter","Shooter")
	local awayRoster=practiceRosterFrom(baseRoster,keeper,"keeper","Keeper")
	setup.ShootingPractice=true
	setup.MatchType="Friendly"
	setup.Completed=true
	setup.HomeTeamId=homeRoster.Team.teamId
	setup.AwayTeamId=awayRoster.Team.teamId
	setup.HomeKit="Home"
	setup.AwayKit="Away"
	setup.CampaignTeamId=""
	setup.CampaignReplay=false
	local success,text,data=self.Runtime:StartMatch(player,setup,nil,nil,homeRoster,awayRoster)
	if not success then return false,text,nil end
	if data then data.AIMatchTeleport=true;data.MatchLaunchType="ShootingPractice";data.PracticeMode=true;data.ObjectiveCompletedNow=false end
	return true,text,data
end

function Service:StartWorldCupMatch(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	self:_consumeWorldCupRuntimeResult(player,profile)
	local state=type(profile.WorldCup)=="table"and profile.WorldCup or nil
	if state then self:_worldCupRepairGroupNextFixture(state)end
	if not state or not state.NextFixture then return false,"Start a World Cup and create the groups first.",nil end
	if player:GetAttribute("VTRWorldCupSoloServer")~=true then
		if self.Profiles.Save then self.Profiles:Save(player,true)end
		local teleporting,teleportMessage,teleportData=self:_teleportWorldCupMatch(player)
		if teleporting then return true,teleportMessage,teleportData end
	end
	local currentSession=self.Runtime and self.Runtime.GetSession and self.Runtime:GetSession(player)or nil
	if currentSession and not currentSession.Ended and currentSession.Setup and currentSession.Setup.WorldCup==true then
		player:SetAttribute("VTRWorldCupMatchStarted",true)
		return true,"World Cup match already loaded.",{AIMatchTeleport=true,MatchLaunchType="WorldCup",WorldCup=true,ObjectiveCompletedNow=false,AlreadyStarted=true}
	end
	local lockedUntil=tonumber(self.WorldCupStartLocks[player])or 0
	if lockedUntil>os.clock() or player:GetAttribute("VTRWorldCupMatchStarting")==true then
		return true,"World Cup match already starting.",{AIMatchTeleport=true,MatchLaunchType="WorldCup",WorldCup=true,ObjectiveCompletedNow=false,AlreadyStarting=true}
	end
	self.WorldCupStartLocks[player]=os.clock()+12
	player:SetAttribute("VTRWorldCupMatchStarting",true)
	local setup=table.clone(self:_ensure(profile));local fixture=state.NextFixture
	local selected=tostring(state.SelectedCountry or"");local opponent=fixture.Home==selected and fixture.Away or fixture.Home
	local homeRoster=buildWorldCupNationalRoster(selected);local awayRoster=buildWorldCupNationalRoster(opponent)
	setup.HomeTeamId=homeRoster.Team.teamId;setup.HomeKit="Home";setup.AwayTeamId=awayRoster.Team.teamId;setup.AwayKit="Away";setup.MatchType="Objective Match";setup.Difficulty="Professional";setup.Completed=true;setup.CampaignTeamId="";setup.WorldCup=true;setup.WorldCupOpponent=opponent;setup.WorldCupStage=state.Stage;setup.WorldCupGroup=state.Stage=="Group";setup.WorldCupKnockout=state.Stage=="Knockout"
	local pending=self:_worldCupStorePendingMatch(player,profile,state,fixture,opponent)
	if pending then setup.WorldCupPendingMatchId=pending.Id end
	local success,text,data=self.Runtime:StartMatch(player,setup,nil,nil,homeRoster,awayRoster);if not success then profile.WorldCupPendingMatch=nil;if state then state.PendingMatch=nil;state.PendingMatchId=nil end;if self.Profiles.Save then self.Profiles:Save(player,true)end;self.WorldCupStartLocks[player]=nil;player:SetAttribute("VTRWorldCupPendingId",nil);player:SetAttribute("VTRWorldCupMatchStarting",nil);return false,text,nil end
	self.WorldCupStartLocks[player]=nil
	player:SetAttribute("VTRWorldCupMatchStarting",nil)
	player:SetAttribute("VTRWorldCupMatchStarted",true)
	if data then data.AIMatchTeleport=true;data.MatchLaunchType="WorldCup";data.WorldCup=true;data.ObjectiveCompletedNow=false end
	local session=self.Runtime:GetSession(player)
	if session then
		self:_tagSoloCampaignSession(player,session)
		session.WorldCupPendingMatch=pending
		session.WorldCupFixtureSnapshot=pending or{Home=fixture.Home,Away=fixture.Away,Group=fixture.Group,Matchday=fixture.Matchday,Round=fixture.Round,Stage=state.Stage}
		session.OnWorldCupCompleted=function(ended:any)
			ended.WorldCupPendingMatch=ended.WorldCupPendingMatch or session.WorldCupPendingMatch
			ended.WorldCupFixtureSnapshot=ended.WorldCupFixtureSnapshot or session.WorldCupFixtureSnapshot
			local committed=self:_commitWorldCupPlayedMatch(player,ended)
			if not committed then
				warn("[VTR WORLDCUP RESULT] result hook did not commit",player.Name,tostring(fixture.Home),tostring(fixture.Away),ended.World and ended.World.HomeScore and ended.World.HomeScore.Value,ended.World and ended.World.AwayScore and ended.World.AwayScore.Value)
			end
		end
		session.OnBeforeResult=function(ended:any)
			ended.WorldCupPendingMatch=ended.WorldCupPendingMatch or session.WorldCupPendingMatch
			ended.WorldCupFixtureSnapshot=ended.WorldCupFixtureSnapshot or session.WorldCupFixtureSnapshot
			self:_commitWorldCupPlayedMatch(player,ended)
			local reward=self:_grantWorldCupMatchReward(player,ended)
			return reward and{[player.UserId]=reward}or{}
		end
		session.OnCompleted=function(ended:any)
			ended.WorldCupPendingMatch=ended.WorldCupPendingMatch or session.WorldCupPendingMatch
			ended.WorldCupFixtureSnapshot=ended.WorldCupFixtureSnapshot or session.WorldCupFixtureSnapshot
			self:_commitWorldCupPlayedMatch(player,ended)
		end
	end
	return true,"World Cup match loaded.",data
end

function Service:SimulateWorldCupMatch(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local state=type(profile.WorldCup)=="table"and profile.WorldCup or nil
	if state then self:_worldCupRepairGroupNextFixture(state)end
	if not state or not state.NextFixture then return false,"No World Cup match is ready to simulate.",nil end
	if state.Stage=="Champion"or state.Stage=="Eliminated"then return false,"This World Cup run is already complete.",self:_worldCupPublic(profile)end
	local fixture=state.NextFixture
	local home=tostring(fixture.Home or"")
	local away=tostring(fixture.Away or"")
	local label=state.Stage=="Knockout"and tostring(WorldCupConfig.KnockoutRounds[state.Knockout and state.Knockout.Round or 1]or"KNOCKOUT")or("GAMEDAY "..tostring(fixture.Matchday or state.GroupMatchIndex or 1))
	local regulationHome,regulationAway=self:_worldCupSimScore(state,home,away)
	local homeGoals,awayGoals=regulationHome,regulationAway
	local resolution=nil
	if state.Stage=="Knockout"then
		resolution=self:_worldCupResolveKnockoutTie(state,fixture,regulationHome,regulationAway)
		homeGoals=resolution.HomeGoals
		awayGoals=resolution.AwayGoals
		fixture.RegulationHomeGoals=regulationHome
		fixture.RegulationAwayGoals=regulationAway
		fixture.ExtraTime=resolution.ExtraTime
		fixture.Penalties=resolution.Penalties
		fixture.Shootout=resolution.Shootout
		fixture.Winner=resolution.Winner
	end
	local extraGoals=resolution and {Home=resolution.ExtraHomeGoals,Away=resolution.ExtraAwayGoals}or nil
	local events=self:_worldCupGoalEvents(state,home,away,regulationHome,regulationAway,extraGoals)
	fixture.GoalEvents=events
	state.SimulatedMatches=(tonumber(state.SimulatedMatches)or 0)+1
	local selected=tostring(state.SelectedCountry or"")
	if home==selected then
		state.UserGoalsFor=(tonumber(state.UserGoalsFor)or 0)+homeGoals
		state.UserGoalsAgainst=(tonumber(state.UserGoalsAgainst)or 0)+awayGoals
	elseif away==selected then
		state.UserGoalsFor=(tonumber(state.UserGoalsFor)or 0)+awayGoals
		state.UserGoalsAgainst=(tonumber(state.UserGoalsAgainst)or 0)+homeGoals
	end
	if self.Profiles.RecordMatchResult and (home==selected or away==selected)then
		local userGoalsFor=home==selected and homeGoals or awayGoals
		local userGoalsAgainst=home==selected and awayGoals or homeGoals
		local userResult=homeGoals==awayGoals and"Draw"or(home==selected and(homeGoals>awayGoals and"Win"or"Loss")or(awayGoals>homeGoals and"Win"or"Loss"))
		local resultId=table.concat({tostring(state.CreatedAt or 0),home,away,tostring(fixture.Group or""),tostring(fixture.Matchday or fixture.Round or""),tostring(state.SimulatedMatches or 0)},"|")
		self.Profiles:RecordMatchResult(player,"WorldCup",resultId,userResult,{Country=selected,Opponent=home==selected and away or home,Stage=state.Stage,Score=tostring(userGoalsFor).."-"..tostring(userGoalsAgainst),Simulated=true})
	end
	self:_worldCupAdvanceAfterMatch(state,homeGoals,awayGoals)
	self:_archiveWorldCup(profile)
	if self.Profiles.Save then self.Profiles:Save(player,true)end
	local winner=resolution and resolution.Winner or homeGoals>awayGoals and home or awayGoals>homeGoals and away or"DRAW"
	return true,string.format("%s %d - %d %s",home,homeGoals,awayGoals,away),{WorldCup=self:_worldCupPublic(profile),Score={Home=home,Away=away,HomeGoals=homeGoals,AwayGoals=awayGoals,RegulationHomeGoals=regulationHome,RegulationAwayGoals=regulationAway,Winner=winner,Events=events,MatchLabel=label,ExtraTime=resolution and resolution.ExtraTime or false,Penalties=resolution and resolution.Penalties or false,Shootout=resolution and resolution.Shootout or nil}}
end

function Service:SimulateRestOfWorldCup(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local state=type(profile.WorldCup)=="table"and profile.WorldCup or nil
	if not state then return false,"Start a World Cup first.",nil end
	if state.Stage~="Eliminated"then return false,"You can simulate the rest after you are eliminated.",self:_worldCupPublic(profile)end
	if state.RestSimulated==true and state.WorldCupWinner then return true,"World Cup already simulated.",{WorldCup=self:_worldCupPublic(profile),Winner=state.WorldCupWinner}end
	self:_worldCupEnsureTeamRanks(state)
	local winner=self:_worldCupSimulateKnockoutToChampion(state)
	state.Stage="Eliminated"
	state.NextFixture=nil
	if self.Profiles.Save then self.Profiles:Save(player,true)end
	return true,string.format("%s win the World Cup.",tostring(winner or"Unknown")),{WorldCup=self:_worldCupPublic(profile),Winner=winner}
end

function Service:WatchMatch(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	if self:_isCampaignMatch(setup) and player:GetAttribute("VTRAICampaignSoloServer")~=true then
		local teleporting,teleportMessage,teleportData=self:_teleportSoloCampaign(player,"Manage")
		if teleporting then return true,teleportMessage,teleportData end
	end
	local watchSetup=table.clone(setup);watchSetup.WatchMode=true;watchSetup.TeamTactics=profile.TeamTactics
	local homeRoster=nil
	if self.RankedSquads then
		local ready,text,roster=self.RankedSquads:GetRoster(player)
		if not ready then return false,text,nil end
		homeRoster=roster
		watchSetup.HomeTeamId=roster.Team.teamId
		watchSetup.HomeKit="Home"
	end
	local success,text,data=self.Runtime:StartMatch(player,watchSetup,nil,nil,homeRoster,nil);if not success then return false,text,nil end;if data then data.AIMatchTeleport=true;data.MatchLaunchType="Manage"end
	local session=self.Runtime:GetSession(player)
	self:_tagSoloCampaignSession(player,session)
	if session and type(watchSetup.CampaignTeamId)=="string" and watchSetup.CampaignTeamId~="" then
		local teamId=watchSetup.CampaignTeamId
		local tierIndex=math.clamp(tonumber(watchSetup.CampaignTier)or 1,1,#VTRLiteConfig.CampaignDifficulties)
		local replay=watchSetup.CampaignReplay==true
		session.OnBeforeResult=function(ended:any)
			ended.MatchId=ended.MatchId or session.MatchId
			self:_recordCampaignMatchResult(player,watchSetup,ended,ended.World.HomeScore.Value>ended.World.AwayScore.Value and"Win"or ended.World.HomeScore.Value==ended.World.AwayScore.Value and"Draw"or"Loss")
			if ended.World.HomeScore.Value<=ended.World.AwayScore.Value or replay then return{}end
			local reward=self:_commitCampaignWin(player,teamId,tierIndex,replay)
			return reward and{[player.UserId]=reward}or{}
		end
		session.OnCompleted=function(ended:any)
			ended.MatchId=ended.MatchId or session.MatchId
			self:_recordCampaignMatchResult(player,watchSetup,ended,ended.World.HomeScore.Value>ended.World.AwayScore.Value and"Win"or ended.World.HomeScore.Value==ended.World.AwayScore.Value and"Draw"or"Loss")
			if ended.World.HomeScore.Value>ended.World.AwayScore.Value then self:_commitCampaignWin(player,teamId,tierIndex,replay)end
		end
	end
	if data then data.ObjectiveCompletedNow=false;data.WatchMode=true end
	return true,"AI vs AI match loaded.",data
end
function Service:ReturnToMenu(player:Player):boolean
	local profile=self.Profiles:GetProfile(player)
	if profile then self:_consumeWorldCupRuntimeResult(player,profile)end
	self.WorldCupTeleportLocks[player]=nil
	self.WorldCupStartLocks[player]=nil
	player:SetAttribute("VTRWorldCupMatchStarting",nil)
	player:SetAttribute("VTRWorldCupMatchStarted",nil)
	return self.Runtime:ReturnToMenu(player)
end
return Service
