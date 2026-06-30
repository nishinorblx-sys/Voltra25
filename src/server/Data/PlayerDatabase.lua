--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Source=require(ReplicatedStorage.VTR.Data.VTRPlayers)
local RarityConfig=require(ReplicatedStorage.VTR.Shared.RarityConfig)
local AppearanceTypes=require(ReplicatedStorage.VTR.Shared.AppearanceTypes)
local CardTypes=require(ReplicatedStorage.VTR.Shared.CardTypes)

local players=Source.LoadAll();local byId={};local pools={};local indexes={country={},club={},position={},rarity={}}
local function add(index:any,key:string,player:any)index[key]=index[key]or{};table.insert(index[key],player)end
for _,player in players do byId[player.playerId]=player;pools[player.rarity]=pools[player.rarity]or{};table.insert(pools[player.rarity],player);add(indexes.country,string.lower(player.country),player);add(indexes.club,string.lower(player.club),player);add(indexes.rarity,string.lower(player.rarity),player);for _,position in player.positions do add(indexes.position,string.lower(position),player)end end
-- Compatibility aliases only select CSV definitions; they never change CSV rarity metadata.
pools.Starter=pools.Bronze;pools.Common=pools.Bronze;pools.Mythic=pools.Mythic or pools.Icon or pools.Legendary

local Database={Count=#players,Players=players,ById=byId,Pools=pools,Indexes=indexes,Source=Source.Source}
function Database.Get(playerId:string):any?return byId[playerId]end
function Database.Search(filters:any,offset:number?,limit:number?):any
	filters=type(filters)=="table"and filters or{};offset=math.max(0,offset or 0);limit=math.clamp(limit or 50,1,100)
	local candidates=players;local position=type(filters.position)=="string"and string.lower(filters.position)or nil;local rarity=type(filters.rarity)=="string"and string.lower(filters.rarity)or nil;local country=type(filters.country)=="string"and string.lower(filters.country)or nil;local club=type(filters.club)=="string"and string.lower(filters.club)or nil
	if position and position~=""and indexes.position[position]then candidates=indexes.position[position]elseif rarity and rarity~=""and indexes.rarity[rarity]then candidates=indexes.rarity[rarity]elseif country and country~=""and indexes.country[country]then candidates=indexes.country[country]elseif club and club~=""and indexes.club[club]then candidates=indexes.club[club]end
	local name=type(filters.name)=="string"and string.lower(filters.name)or"";local minimum=tonumber(filters.minimumOverall)or 0;local maximum=tonumber(filters.maximumOverall)or 99;local matches={}
	for _,player in candidates do if player.overall>=minimum and player.overall<=maximum and(name==""or string.find(string.lower(player.displayName),name,1,true))and(not country or country==""or string.lower(player.country)==country)and(not club or club==""or string.lower(player.club)==club)and(not rarity or rarity==""or string.lower(player.rarity)==rarity)and(not position or position==""or table.find(player.positions,string.upper(position)))then table.insert(matches,player)end end
	local sort=filters.sort or"overall";table.sort(matches,function(a,b)if sort=="name"then return a.displayName<b.displayName elseif sort=="potential"then return a.potential>b.potential elseif sort=="value"then return a.value>b.value else return a.overall>b.overall end end)
	local page={};for index=offset+1,math.min(#matches,offset+limit)do table.insert(page,matches[index])end;return{Total=#matches,Offset=offset,Limit=limit,Players=page}
end
function Database.Validate():any
	local errors={};local seen={};local valid=0;for _,player in players do local ok=true;if seen[player.playerId]then ok=false;table.insert(errors,"duplicate playerId "..player.playerId)else seen[player.playerId]=true end;if type(player.portraitSeed)~="number"then ok=false;table.insert(errors,"missing portraitSeed "..player.playerId)end;if not RarityConfig.Valid[player.rarity]then ok=false;table.insert(errors,"invalid rarity "..player.playerId)end;if not table.find(CardTypes.CardTypes,player.cardType)then ok=false;table.insert(errors,"invalid cardType "..player.playerId)end;if type(player.appearance.specialPortrait)~="boolean"then ok=false;table.insert(errors,"invalid specialPortrait "..player.playerId)end;for _,field in AppearanceTypes.Required do local allowed=AppearanceTypes.Allowed[field];if not allowed or not allowed[player.appearance[field]]then ok=false;table.insert(errors,"invalid "..field.." "..player.playerId);break end end;if ok then valid+=1 end;if #errors>=100 then break end end;return{Source=Source.Source,Total=#players,Valid=valid,Errors=errors,ErrorCount=#errors,ShardCount=Source.ShardCount}
end
return table.freeze(Database)
