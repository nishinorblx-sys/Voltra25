--!strict
local Service={};Service.__index=Service
local function checkpointCount(division:number):number return math.clamp(division+1,2,10)end
local function protectedThreshold(progress:number,division:number):number
	local count=checkpointCount(division);local protected=0
	for index=1,count do local threshold=math.floor(index*10/(count+1)+.5);if progress>=threshold then protected=math.max(protected,threshold)end end
	return math.min(protected,9)
end
function Service.new(profiles:any,publish:(Player,string,any)->())return setmetatable({Profiles=profiles,Publish=publish},Service)end
function Service:GetClientData(player:Player):any?
	local p=self.Profiles:GetProfile(player);if not p then return nil end;local r=p.Ranked
	return{Division=r.Division,DivisionNumber=r.DivisionNumber,DivisionWins=r.DivisionWins,ProtectedWins=r.ProtectedWins,CheckpointCount=r.DivisionNumber==0 and 0 or checkpointCount(r.DivisionNumber),VoltraRating=r.VoltraRating,Rank=r.Rank,PlacementStatus=r.PlacementStatus,Wins=r.Wins,Draws=r.Draws,Losses=r.Losses,RP=r.DivisionNumber==0 and r.VoltraRating or r.DivisionWins,RequiredRP=r.DivisionNumber==0 and 0 or 10,WinStreak=r.WinStreak,History=r.History,PlayerStats=r.PlayerStats}
end
function Service:RecordServerResult(player:Player,result:string,_legacyDelta:number,opponent:string,score:string,matchStats:any?):boolean
	if result=="ForfeitWin"then result="Win"elseif result=="ForfeitLoss"then result="Loss"end;if result~="Win"and result~="Draw"and result~="Loss"then return false end;local p=self.Profiles:GetProfile(player);if not p then return false end;local r=p.Ranked;local delta=0
	if (result=="Win" or result=="ForfeitWin")then r.Wins+=1;r.WinStreak+=1 elseif result=="Draw"then r.Draws+=1;r.WinStreak=0 else r.Losses+=1;r.WinStreak=0 end
	if r.DivisionNumber==0 then
		local tier=math.max(0,math.floor((r.VoltraRating-1000)/100));delta=(result=="Win" or result=="ForfeitWin")and math.max(8,30-tier*2)or (result=="Loss" or result=="ForfeitLoss")and-math.min(45,10+tier*2)or 0;r.VoltraRating=math.max(0,r.VoltraRating+delta);r.RP=r.VoltraRating;r.Division="VOLTRA DIVISION";r.Rank=tostring(r.VoltraRating).." RATING"
	else
		if (result=="Win" or result=="ForfeitWin")then r.DivisionWins=math.min(10,r.DivisionWins+1);delta=1;r.ProtectedWins=math.max(r.ProtectedWins,protectedThreshold(r.DivisionWins,r.DivisionNumber))elseif (result=="Loss" or result=="ForfeitLoss")then local old=r.DivisionWins;r.DivisionWins=math.max(r.ProtectedWins,r.DivisionWins-1);delta=r.DivisionWins-old end
		if r.DivisionWins>=10 then r.DivisionNumber-=1;r.DivisionWins=0;r.ProtectedWins=0;if r.DivisionNumber<=0 then r.DivisionNumber=0;r.VoltraRating=1000;r.RP=1000;r.Division="VOLTRA DIVISION";r.Rank="1000 RATING"else r.Division="DIVISION "..r.DivisionNumber;r.Rank="PROMOTED";r.RP=0 end else r.RP=r.DivisionWins;r.Division="DIVISION "..r.DivisionNumber;r.Rank="STEP "..r.DivisionWins.." / 10"end
	end
	local playerStats=r.PlayerStats;playerStats.MatchesPlayed+=1
	if matchStats and matchStats.PlayerRating then local previous=playerStats.AverageRating or 0;playerStats.AverageRating=math.floor(((previous*(playerStats.MatchesPlayed-1)+matchStats.PlayerRating)/playerStats.MatchesPlayed)*10+.5)/10;playerStats.Goals+=(matchStats.Match and matchStats.Match.Goals or 0);if matchStats.MOTM and matchStats.MOTM.Team==matchStats.Team then playerStats.MOTM+=1 end;local assists=0;for _,entry in matchStats.Full and matchStats.Full.PlayerRatings or{}do if entry.Team==matchStats.Team then assists+=entry.Assists or 0;if(entry.Goals or 0)>=3 then playerStats.HatTricks+=1 end end end;playerStats.Assists+=assists end
	table.insert(r.History,1,{Result=result,Opponent=string.sub(opponent,1,32),Score=string.sub(score,1,12),RPDelta=delta,At=os.time(),Stats=matchStats});while#r.History>20 do table.remove(r.History)end;self.Publish(player,"Ranked",self:GetClientData(player));return true
end
return Service
