--!strict
-- Authoritative API generated from VTRPlayers_With_Special_Versions.csv.

local VTRPlayers = { Count = 18411, ShardCount = 74, ChunkSize = 250, Source = "VTRPlayers_With_Special_Versions.csv" }
local decodedCache: { [number]: { any } } = {}
local idCache: { [string]: any } = {}

local function split(value: string): { string }
	local result={};for item in string.gmatch(value or "","[^,]+") do local clean=string.match(item,"^%s*(.-)%s*$");if clean and clean~="" then table.insert(result,clean) end end;return result
end

local function decode(row: { any }): any
	local appearance={skinTone=row[26],faceShape=row[27],eyeType=row[28],eyebrowType=row[29],noseType=row[30],mouthType=row[31],hairStyle=row[32],hairColor=row[33],facialHair=row[34],facialHairColor=row[35],bodyBuild=row[36],heightClass=row[37],portraitExpression=row[38],specialPortrait=row[39],accessoryType=row[40],accessoryColor=row[41],avatarVersion=row[42],cardPose=row[43],celebrationStyle=row[44],walkStyle=row[45]}
	local main={PAC=row[46],SHO=row[47],PAS=row[48],DRI=row[49],DEF=row[50],PHY=row[51]}
	local details={acceleration=row[52],sprintSpeed=row[53],finishing=row[54],shotPower=row[55],longShots=row[56],volleys=row[57],penalties=row[58],shortPassing=row[59],longPassing=row[60],vision=row[61],crossing=row[62],curve=row[63],fkAccuracy=row[64],dribbling=row[65],ballControl=row[66],agility=row[67],balance=row[68],reactions=row[69],defensiveAwareness=row[70],standingTackle=row[71],slidingTackle=row[72],interceptions=row[73],strength=row[74],stamina=row[75],aggression=row[76],jumping=row[77],headingAccuracy=row[78],attackingPosition=row[79],composure=row[80],gkDiving=row[81],gkHandling=row[82],gkKicking=row[83],gkPositioning=row[84],gkReflexes=row[85]}
	local rarity=row[19];local player={playerId=row[1],displayName=row[2],shortName=row[3],country=row[4],club=row[5],league=row[6],positions=split(row[7]),bestPosition=row[8],overall=row[9],potential=row[10],value=row[11],wage=row[12],releaseClause=row[13],preferredFoot=row[14],weakFoot=row[15],skillMoves=row[16],bodyType=row[17],specialties=split(row[18]),rarity=rarity,cardType=row[20],portraitSeed=row[21],age=row[22],heightCm=row[23],weightKg=row[24],birthDate=row[25],appearance=appearance,portrait=appearance,pose={cardPose=row[43],celebrationStyle=row[44],walkStyle=row[45]},mainStats=main,detailedStats=details}
	-- Compatibility names are aliases of CSV fields, never regenerated values.
	player.fictionalClub=player.club;player.nationality=player.country;player.playStyles=player.specialties;player.accelerationType=appearance.heightClass;player.workRates={Attack="N/A",Defense="N/A"};player.reputation=rarity=="Icon" and 5 or rarity=="Legendary" and 4 or rarity=="Elite" and 3 or rarity=="Rare" and 2 or 1
	return player
end

function VTRPlayers.GetShard(index: number): { any }
	assert(index>=1 and index<=VTRPlayers.ShardCount,"Invalid VTR player shard")
	if decodedCache[index] then return decodedCache[index] end
	if index%4==1 then task.wait() end
	local module=script.Parent.Players:FindFirstChild(string.format("Shard%03d",index));assert(module and module:IsA("ModuleScript"),"Missing VTR player shard "..index)
	local result={};for _,row in require(module) do local player=decode(row);table.insert(result,player);idCache[player.playerId]=player end;decodedCache[index]=result;return result
end

function VTRPlayers.Get(playerId: string): any?
	if idCache[playerId] then return idCache[playerId] end
	for index=1,VTRPlayers.ShardCount do for _,player in VTRPlayers.GetShard(index) do if player.playerId==playerId then return player end end end;return nil
end

function VTRPlayers.LoadAll(): { any }
	local result=table.create(VTRPlayers.Count);for index=1,VTRPlayers.ShardCount do for _,player in VTRPlayers.GetShard(index) do table.insert(result,player) end;if index%4==0 then task.wait() end end;return result
end

function VTRPlayers.Iterate(callback: (any)->()) for index=1,VTRPlayers.ShardCount do for _,player in VTRPlayers.GetShard(index) do callback(player) end;if index%4==0 then task.wait() end end end
return table.freeze(VTRPlayers)
