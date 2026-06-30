--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local ClubIdentityConfig=require(ReplicatedStorage.VTR.Shared.ClubIdentityConfig)

local Service={}
Service.__index=Service
local ORDER={"GK","LB","CB1","CB2","RB","CM1","CDM","CM2","LW","ST","RW"}
local ATTACK={LW=true,RW=true,ST=true,CF=true,LM=true,RM=true}
local MIDFIELD={CM=true,CDM=true,CAM=true,LM=true,RM=true}
local DEFENSE={GK=true,LB=true,RB=true,CB=true,LWB=true,RWB=true}

local function findCard(profile:any,reference:any):any?
	if type(reference)~="string"then return nil end
	for _,card in profile.PlayerCardInventory or{}do if card.Id==reference or card.cardInstanceId==reference then return card end end
	return nil
end

local function matchPlayer(card:any):any?
	local definition=PlayerDatabase.Get(card.playerId or card.PlayerId or"");if not definition then return nil end
	local result=table.clone(definition);result.appearance=table.clone(definition.appearance or card.appearance or{});result.mainStats=table.clone(card.mainStats or card.MainStats or definition.mainStats or{});result.cardInstanceId=card.cardInstanceId or card.Id;result.overall=tonumber(card.overall or card.Rating)or definition.overall;result.rarity=card.rarity or card.Rarity or definition.rarity;result.cardType=card.cardType or card.CardType or definition.cardType;return result
end

local function average(players:{any},group:any?):number
	local total,count=0,0;for _,player in players do if not group or group[player.bestPosition]==true then total+=tonumber(player.overall)or 0;count+=1 end end;return count>0 and math.floor(total/count+.5)or 0
end

local function identityTeam(player:Player,profile:any,starting:{any}):any
	local identity=profile.ClubMembership or{};local primary=ClubIdentityConfig.ResolveColor(identity.PrimaryColor);local secondary=ClubIdentityConfig.ResolveColor(identity.SecondaryColor);local accent=ClubIdentityConfig.ResolveColor(identity.AccentColor);local name=identity.Name;if type(name)~="string"or name==""or name=="NO CLUB"then name=string.upper(player.DisplayName).." XI"end;local abbreviation=identity.Abbreviation;if type(abbreviation)~="string"or#abbreviation<2 then abbreviation=string.upper(string.sub(name:gsub("[^%a]",""),1,3))end;if abbreviation==""then abbreviation="VTR"end
	local style=ClubIdentityConfig.ResolveStyle(identity.KitStyle);local home={Name="Home",Primary=primary,Secondary=secondary,Accent=accent,Style=style,NumberColor=accent};local away={Name="Away",Primary=secondary,Secondary=primary,Accent=accent,Style=style,NumberColor=accent};local third={Name="Third",Primary=accent,Secondary=primary,Accent=secondary,Style="Solid",NumberColor=secondary}
	local sorted=table.clone(starting);table.sort(sorted,function(a,b)return(a.overall or 0)>(b.overall or 0)end)
	return{teamId="ultimate_team_"..player.UserId,teamName=name,country="VTR UNIVERSE",league="RANKED ULTIMATE TEAM",overall=average(starting),attack=average(starting,ATTACK),midfield=average(starting,MIDFIELD),defense=average(starting,DEFENSE),formation=profile.Formation or"4-3-3",badgePreset=identity.BadgeShape or identity.BadgePreset or"Shield",logo=string.upper(abbreviation),colors={Primary=primary,Secondary=secondary,Accent=accent},kits={Home=home,Away=away,Third=third},starPlayers={sorted[1],sorted[2],sorted[3]},generated=false}
end

function Service.new(profiles:any)return setmetatable({Profiles=profiles},Service)end

function Service:GetRoster(player:Player):(boolean,string,any?)
	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end
	local squad=profile.Squad or{};if next(squad)==nil and profile.SquadState and profile.SquadState.startingXI then squad=profile.SquadState.startingXI end;local starting={};local used:any={};local usedPlayers:any={}
	for _,slot in ORDER do local card=findCard(profile,squad[slot]);if not card then return false,"Your Ultimate Team Starting XI must have all 11 positions filled.",nil end;local instanceId=card.cardInstanceId or card.Id;local playerId=card.playerId or card.PlayerId or instanceId;local meta=profile.PlayerCardMeta and profile.PlayerCardMeta[instanceId];if meta and meta.Loan==true and(tonumber(meta.LoanMatchesRemaining)or 0)<=0 then return false,card.Name.." has no loan matches remaining.",nil end;if used[instanceId]then return false,"Your Ultimate Team lineup contains a duplicate card.",nil end;if usedPlayers[playerId]then return false,"You cannot use repeat players in the Starting XI or bench.",nil end;used[instanceId]=true;usedPlayers[playerId]=true;local playerData=matchPlayer(card);if not playerData then return false,"A player in your Starting XI could not be loaded.",nil end;table.insert(starting,playerData)end
	local bench={};for index=1,7 do local reference=profile.Bench and profile.Bench[index]or nil;if not reference and profile.SquadState and profile.SquadState.bench then reference=profile.SquadState.bench["slot"..index]end;local card=findCard(profile,reference);if card then local instanceId=card.cardInstanceId or card.Id;local playerId=card.playerId or card.PlayerId or instanceId;if usedPlayers[playerId]then return false,"You cannot use repeat players in the Starting XI or bench.",nil end;usedPlayers[playerId]=true;local playerData=matchPlayer(card);if playerData then table.insert(bench,playerData)end end end
	local reserves={};for _,reference in profile.Reserves or{}do local card=findCard(profile,reference);local playerData=card and matchPlayer(card)or nil;if playerData then table.insert(reserves,playerData)end end
	local team=identityTeam(player,profile,starting);local best={};for index=1,math.min(3,#team.starPlayers)do local star=team.starPlayers[index];table.insert(best,{playerId=star.playerId,displayName=star.displayName,shortName=star.shortName,overall=star.overall,bestPosition=star.bestPosition})end
	return true,"Ultimate Team lineup ready.",{Team=team,StartingXI=starting,Bench=bench,Reserves=reserves,Formation=team.formation,BestPlayers=best}
end

function Service:ConsumeLoans(player:Player)
	local profile=self.Profiles:GetProfile(player);if not profile then return end;for _,reference in profile.Squad or{}do local card=findCard(profile,reference);local id=card and(card.cardInstanceId or card.Id);local meta=id and profile.PlayerCardMeta and profile.PlayerCardMeta[id];if meta and meta.Loan==true then meta.LoanMatchesRemaining=math.max(0,(tonumber(meta.LoanMatchesRemaining)or 0)-1)end end
end

return Service
