--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local ClubIdentityConfig=require(ReplicatedStorage.VTR.Shared.ClubIdentityConfig)
local FormationConfig=require(ReplicatedStorage.VTR.Shared.FormationConfig)
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local CardProgressionResolver=require(ReplicatedStorage.VTR.Shared.CardProgressionResolver)

local Service={}
Service.__index=Service
local ORDER=FormationConfig.Order
local ATTACK={LW=true,RW=true,ST=true,CF=true,LM=true,RM=true}
local MIDFIELD={CM=true,CDM=true,CAM=true,LM=true,RM=true}
local DEFENSE={GK=true,LB=true,RB=true,CB=true,LWB=true,RWB=true}
local POSITION_ALIASES={
	["LEFT WING"]="LW",["RIGHT WING"]="RW",["STRIKER"]="ST",["CENTRE FORWARD"]="CF",["CENTER FORWARD"]="CF",
	["LEFT MIDFIELD"]="LM",["RIGHT MIDFIELD"]="RM",["CENTRE MIDFIELD"]="CM",["CENTER MIDFIELD"]="CM",
	["DEFENSIVE MIDFIELD"]="CDM",["ATTACKING MIDFIELD"]="CAM",["LEFT BACK"]="LB",["RIGHT BACK"]="RB",
	["CENTRE BACK"]="CB",["CENTER BACK"]="CB",["GOALKEEPER"]="GK",
}

local function findCard(profile:any,reference:any):any?
	if type(reference)~="string"then return nil end
	for _,card in profile.PlayerCardInventory or{}do if card.Id==reference or card.cardInstanceId==reference then return card end end
	return nil
end

local function matchdayIdentity(card:any):string
	if not card then return "" end
	local name=string.lower(tostring(card.displayName or card.Name or card.shortName or card.ShortName or "")):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
	if name~=""then return "name:"..name end
	local playerId=tostring(card.BasePlayerId or card.basePlayerId or card.playerId or card.PlayerId or "")
	if playerId~=""then
		for _,suffix in{"_team_of_the_week","_rising_star","_voltra_hero","_champion","_event","_limited","_spark","_electrum","_hero","_storm","_mythic"}do
			if string.sub(playerId,-#suffix)==suffix then return string.sub(playerId,1,#playerId-#suffix)end
		end
		return playerId
	end
	return tostring(card.Id or card.cardInstanceId or "")
end

local function matchPlayer(card:any,meta:any?):any?
	local definition=PlayerDatabase.Get(card.playerId or card.PlayerId or"");if not definition then return nil end
	local result=table.clone(definition);result.appearance=table.clone(definition.appearance or card.appearance or{});result.mainStats=table.clone(definition.mainStats or{});result.detailedStats=table.clone(definition.detailedStats or{});result.cardInstanceId=card.cardInstanceId or card.Id;result.Id=result.cardInstanceId;result.PlayerId=definition.playerId;result.Rating=definition.overall;result.MainStats=table.clone(result.mainStats);return CardProgressionResolver.Resolve(result,meta)
end

local function average(players:{any},group:any?):number
	local total,count=0,0;for _,player in players do local position=tostring(player.PositionSlot or player.SquadSlot or player.ExpectedPosition or player.bestPosition or player.Position or""):upper();position=POSITION_ALIASES[position]or position;if not group or group[position]==true then total+=tonumber(player.overall)or 0;count+=1 end end;return count>0 and math.floor(total/count+.5)or 0
end

local function identityTeam(player:Player,profile:any,starting:{any}):any
	local identity=profile.ClubMembership or{};local primary=ClubIdentityConfig.ResolveColor(identity.PrimaryColor);local secondary=ClubIdentityConfig.ResolveColor(identity.SecondaryColor);local accent=ClubIdentityConfig.ResolveColor(identity.AccentColor);local name=identity.Name;if type(name)~="string"or name==""or name=="NO CLUB"then name=string.upper(player.DisplayName).." XI"end;local abbreviation=identity.Abbreviation;if type(abbreviation)~="string"or#abbreviation<2 then abbreviation=string.upper(string.sub(name:gsub("[^%a]",""),1,3))end;if abbreviation==""then abbreviation="VTR"end
	local equipped=profile.UIState and profile.UIState.EquippedCosmetics or{};local activeKit=nil;for _,kit in Catalog.Kits do if kit.Id==equipped.ActiveKit then activeKit=kit;break end end
	local style=ClubIdentityConfig.ResolveStyle(identity.KitStyle);local bootStyle=tostring(equipped.BootStyle or"");local home={Name="Home",Primary=primary,Secondary=secondary,Accent=accent,Style=style,NumberColor=accent,BootStyle=bootStyle};local away={Name="Away",Primary=secondary,Secondary=primary,Accent=accent,Style=style,NumberColor=accent,BootStyle=bootStyle};local third={Name="Third",Primary=accent,Secondary=primary,Accent=secondary,Style="Solid",NumberColor=secondary,BootStyle=bootStyle}
	if activeKit then home={Name=activeKit.Name or"Home",Primary=activeKit.Primary or primary,Secondary=activeKit.Secondary or secondary,Accent=activeKit.Accent or accent,Style=activeKit.Style or style,NumberColor=activeKit.NumberColor or activeKit.Accent or accent,Animated=activeKit.Animated==true,BootStyle=bootStyle};away={Name=(activeKit.Name or"Away").." AWAY",Primary=activeKit.Secondary or secondary,Secondary=activeKit.Primary or primary,Accent=activeKit.Accent or accent,Style=activeKit.Style or style,NumberColor=activeKit.NumberColor or activeKit.Accent or accent,Animated=activeKit.Animated==true,BootStyle=bootStyle};third={Name=(activeKit.Name or"Third").." THIRD",Primary=activeKit.Accent or accent,Secondary=activeKit.Primary or primary,Accent=activeKit.Secondary or secondary,Style=activeKit.Style or"Solid",NumberColor=activeKit.NumberColor or secondary,Animated=activeKit.Animated==true,BootStyle=bootStyle}end
	local sorted=table.clone(starting);table.sort(sorted,function(a,b)return(a.overall or 0)>(b.overall or 0)end)
	local badgeIdentity={PrimaryColor=primary,SecondaryColor=secondary,AccentColor=accent,BadgePreset=identity.BadgePreset or"Modern",BadgeShape=identity.BadgeShape or"Shield",BadgeSymbol=identity.BadgeSymbol or"Lightning Bolt",BadgeColorBehavior=identity.BadgeColorBehavior or"Tri Color"}
	return{teamId="ultimate_team_"..player.UserId,teamName=name,country="VTR UNIVERSE",league="RANKED ULTIMATE TEAM",overall=average(starting),attack=average(starting,ATTACK),midfield=average(starting,MIDFIELD),defense=average(starting,DEFENSE),formation=profile.Formation or"4-3-3",badgePreset=identity.BadgeShape or identity.BadgePreset or"Shield",logo=string.upper(abbreviation),colors={Primary=primary,Secondary=secondary,Accent=accent},BadgeIdentity=badgeIdentity,badgeIdentity=badgeIdentity,kits={Home=home,Away=away,Third=third},starPlayers={sorted[1],sorted[2],sorted[3]},generated=false}
end

function Service.new(profiles:any)return setmetatable({Profiles=profiles},Service)end

function Service:GetRoster(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local squad=profile.Squad or{};if next(squad)==nil and profile.SquadState and profile.SquadState.startingXI then squad=profile.SquadState.startingXI end;local starting={};local used:any={};local usedPlayers:any={}
	local formationName=profile.Formation or"4-3-3";local shape=FormationConfig.Formations[formationName]or FormationConfig.Formations["4-3-3"]or{}
	for _,slot in ORDER do local card=findCard(profile,squad[slot]);if not card then return false,"Your Ultimate Team Starting XI must have all 11 positions filled.",nil end;local instanceId=card.cardInstanceId or card.Id;local playerId=matchdayIdentity(card);local meta=profile.PlayerCardMeta and profile.PlayerCardMeta[instanceId];if meta and meta.Loan==true and(tonumber(meta.LoanMatchesRemaining)or 0)<=0 then return false,card.Name.." has no loan matches remaining.",nil end;if used[instanceId]then return false,"Your Ultimate Team lineup contains a duplicate card.",nil end;if usedPlayers[playerId]then return false,"You cannot use repeat players in the Starting XI or bench.",nil end;used[instanceId]=true;usedPlayers[playerId]=true;local playerData=matchPlayer(card,meta);if not playerData then return false,"A player in your Starting XI could not be loaded.",nil end;local slotDefinition=shape[slot];playerData.FormationSlot=slot;playerData.PositionSlot=slot;playerData.SquadSlot=slot;if slotDefinition then playerData.FormationCoordinate={X=slotDefinition.X,Y=slotDefinition.Y};playerData.FormationLabel=slotDefinition.Label;playerData.ExpectedPosition=slotDefinition.Expected end;table.insert(starting,playerData)end
	local bench={};for index=1,7 do local reference=profile.Bench and profile.Bench[index]or nil;if not reference and profile.SquadState and profile.SquadState.bench then reference=profile.SquadState.bench["slot"..index]end;local card=findCard(profile,reference);if card then local playerId=matchdayIdentity(card);if usedPlayers[playerId]then return false,"You cannot use repeat players in the Starting XI or bench.",nil end;usedPlayers[playerId]=true;local playerData=matchPlayer(card,profile.PlayerCardMeta and profile.PlayerCardMeta[card.cardInstanceId or card.Id]);if playerData then table.insert(bench,playerData)end end end
	local reserves={};for _,reference in profile.Reserves or{}do local card=findCard(profile,reference);local playerData=card and matchPlayer(card,profile.PlayerCardMeta and profile.PlayerCardMeta[card.cardInstanceId or card.Id])or nil;if playerData then table.insert(reserves,playerData)end end
	local team=identityTeam(player,profile,starting);local best={};for index=1,math.min(3,#team.starPlayers)do local star=team.starPlayers[index];table.insert(best,{playerId=star.playerId,displayName=star.displayName,shortName=star.shortName,overall=star.overall,bestPosition=star.bestPosition})end
	return true,"Ultimate Team lineup ready.",{Team=team,StartingXI=starting,Bench=bench,Reserves=reserves,Formation=team.formation,BestPlayers=best}
end

function Service:ConsumeLoans(player:Player)
	local profile=self.Profiles:GetProfile(player);if not profile then return end;for _,reference in profile.Squad or{}do local card=findCard(profile,reference);local id=card and(card.cardInstanceId or card.Id);local meta=id and profile.PlayerCardMeta and profile.PlayerCardMeta[id];if meta and meta.Loan==true then meta.LoanMatchesRemaining=math.max(0,(tonumber(meta.LoanMatchesRemaining)or 0)-1)end end
end

return Service
