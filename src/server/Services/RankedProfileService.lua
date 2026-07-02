--!strict
local Service={};Service.__index=Service
local function checkpointCount(division:number):number return math.clamp(division+1,2,10)end
local function protectedThreshold(progress:number,division:number):number
	local count=checkpointCount(division);local protected=0
	for index=1,count do local threshold=math.floor(index*10/(count+1)+.5);if progress>=threshold then protected=math.max(protected,threshold)end end
	return math.min(protected,9)
end
local TEAM_STAT_KEYS={"Possession","Shots","ShotsOnTarget","ShotsOffTarget","BlockedShots","ExpectedGoals","PassesAttempted","PassesCompleted","PassAccuracy","KeyPasses","BigChanceCreated","BigChancesCreated","Crosses","CompletedCrosses","DribblesCompleted","DribbleAccuracy","TacklesAttempted","TacklesCompleted","Interceptions","Clearances","Errors","Saves","Corners","Fouls","Offsides","YellowCards","RedCards","Goals"}
local function pick(source:any,keys:{string}):any local result={};if type(source)~="table"then return result end;for _,key in keys do local value=source[key];if type(value)=="number"or type(value)=="string"or type(value)=="boolean"then result[key]=value end end;return result end
local function compactReward(reward:any):any? if type(reward)~="table"then return nil end;return pick(reward,{"Title","Coins","XP","Pack","PackId","PackInstanceId","Packs"})end
local function compactGoals(goals:any):any local result={};if type(goals)~="table"then return result end;for index,goal in goals do if index>24 then break end;table.insert(result,{Team=goal.Team,Scorer=goal.Scorer,Assist=goal.Assist,GameSeconds=goal.GameSeconds,OwnGoal=goal.OwnGoal})end;return result end
local function compactRatings(ratings:any):any local result={};if type(ratings)~="table"then return result end;for index,entry in ratings do if index>32 then break end;table.insert(result,{Team=entry.Team,Name=entry.Name,Position=entry.Position,Rating=entry.Rating,Goals=entry.Goals,Assists=entry.Assists,Events=pick(entry.Events or{},{"Goal","Assist","ShotOnTarget","KeyPass","BigChanceCreated","SuccessfulPass","BadPass"})})end;return result end
local function compactMotm(motm:any):any if type(motm)~="table"then return nil end;return{Team=motm.Team,Name=motm.Name,Position=motm.Position,Rating=motm.Rating,Goals=motm.Goals,Assists=motm.Assists}end
local function compactHistoryStats(stats:any):any
	if type(stats)~="table"then return stats end
	local full=type(stats.Full)=="table"and stats.Full or{}
	return{ResultId=stats.ResultId,PlayerRating=stats.PlayerRating,Team=stats.Team,Reward=compactReward(stats.Reward),Match=pick(stats.Match or{},TEAM_STAT_KEYS),MOTM=compactMotm(stats.MOTM or full.MOTM),Full={HomeScore=full.HomeScore,AwayScore=full.AwayScore,Home=pick(full.Home or{},TEAM_STAT_KEYS),Away=pick(full.Away or{},TEAM_STAT_KEYS),Goals=compactGoals(full.Goals),PlayerRatings=compactRatings(full.PlayerRatings),MOTM=compactMotm(full.MOTM)}}
end
local function normalizeRun(run:any):any
	run=type(run)=="table"and run or{}
	local results=type(run.Results)=="table"and run.Results or{}
	local target=math.clamp(math.floor(tonumber(run.Target)or 7),1,20)
	local normalized={Active=false,Results={},Wins=0,Draws=0,Losses=0,Target=target,Ended=false,RewardClaimed=run.RewardClaimed==true}
	for _,value in results do
		local result=tostring(value)
		if result=="Win"or result=="Draw"or result=="Loss"then table.insert(normalized.Results,result)end
	end
	while#normalized.Results>target do table.remove(normalized.Results,1)end
	for _,result in normalized.Results do
		if result=="Win"then normalized.Wins+=1 elseif result=="Draw"then normalized.Draws+=1 elseif result=="Loss"then normalized.Losses+=1 end
	end
	normalized.Active=#normalized.Results>0 and #normalized.Results<target
	normalized.Ended=#normalized.Results>=target
	return normalized
end
local function appendRunResult(profile:any,result:string):any
	local run=normalizeRun(profile.RankedRun)
	if#run.Results>=run.Target then
		run.Results={}
		run.Wins=0
		run.Draws=0
		run.Losses=0
		run.Ended=false
		run.RewardClaimed=false
	end
	table.insert(run.Results,result)
	run=normalizeRun(run)
	profile.RankedRun=run
	return run
end
function Service.new(profiles:any,publish:(Player,string,any)->())return setmetatable({Profiles=profiles,Publish=publish},Service)end
function Service:GetClientData(player:Player):any?
	local p=self.Profiles:GetProfile(player);if not p then return nil end;local r=p.Ranked
	local run=normalizeRun(p.RankedRun);p.RankedRun=run
	return{Division=r.Division,DivisionNumber=r.DivisionNumber,DivisionWins=r.DivisionWins,ProtectedWins=r.ProtectedWins,CheckpointCount=r.DivisionNumber==0 and 0 or checkpointCount(r.DivisionNumber),VoltraRating=r.VoltraRating,Rank=r.Rank,PlacementStatus=r.PlacementStatus,Wins=r.Wins,Draws=r.Draws,Losses=r.Losses,RP=r.DivisionNumber==0 and r.VoltraRating or r.DivisionWins,RequiredRP=r.DivisionNumber==0 and 0 or 10,WinStreak=r.WinStreak,History=r.History,PlayerStats=r.PlayerStats,RankedRun=run,Run=run}
end
function Service:RecordServerResult(player:Player,result:string,_legacyDelta:number,opponent:string,score:string,matchStats:any?):boolean
	if result=="ForfeitWin"then result="Win"elseif result=="ForfeitLoss"then result="Loss"end;if result~="Win"and result~="Draw"and result~="Loss"then return false end;local p=self.Profiles:GetProfile(player);if not p then return false end;p.Ranked=p.Ranked or{};local r=p.Ranked;r.Wins=tonumber(r.Wins)or 0;r.Draws=tonumber(r.Draws)or 0;r.Losses=tonumber(r.Losses)or 0;r.DivisionWins=tonumber(r.DivisionWins)or 0;r.ProtectedWins=tonumber(r.ProtectedWins)or 0;r.DivisionNumber=tonumber(r.DivisionNumber)or 7;r.VoltraRating=tonumber(r.VoltraRating)or 1000;r.WinStreak=tonumber(r.WinStreak)or 0;r.History=r.History or{};r.PlayerStats=r.PlayerStats or{MatchesPlayed=0,AverageRating=0,Goals=0,Assists=0,MOTM=0,HatTricks=0};local resultId=type(matchStats)=="table"and tostring(matchStats.ResultId or "")or"";if resultId~=""then for _,entry in r.History do if tostring(entry.Id or "")==resultId then self.Publish(player,"Ranked",self:GetClientData(player));return false end end end;local delta=0
	appendRunResult(p,result)
	if (result=="Win" or result=="ForfeitWin")then r.Wins+=1;r.WinStreak+=1 elseif result=="Draw"then r.Draws+=1;r.WinStreak=0 else r.Losses+=1;r.WinStreak=0 end
	if r.DivisionNumber==0 then
		local tier=math.max(0,math.floor((r.VoltraRating-1000)/100));delta=(result=="Win" or result=="ForfeitWin")and math.max(8,30-tier*2)or (result=="Loss" or result=="ForfeitLoss")and-math.min(45,10+tier*2)or 0;r.VoltraRating=math.max(0,r.VoltraRating+delta);r.RP=r.VoltraRating;r.Division="VOLTRA DIVISION";r.Rank=tostring(r.VoltraRating).." RATING"
	else
		if (result=="Win" or result=="ForfeitWin")then r.DivisionWins=math.min(10,r.DivisionWins+1);delta=1;r.ProtectedWins=math.max(r.ProtectedWins,protectedThreshold(r.DivisionWins,r.DivisionNumber))elseif (result=="Loss" or result=="ForfeitLoss")then local old=r.DivisionWins;r.DivisionWins=math.max(r.ProtectedWins,r.DivisionWins-1);delta=r.DivisionWins-old end
		if r.DivisionWins>=10 then r.DivisionNumber-=1;r.DivisionWins=0;r.ProtectedWins=0;if r.DivisionNumber<=0 then r.DivisionNumber=0;r.VoltraRating=1000;r.RP=1000;r.Division="VOLTRA DIVISION";r.Rank="1000 RATING"else r.Division="DIVISION "..r.DivisionNumber;r.Rank="PROMOTED";r.RP=0 end else r.RP=r.DivisionWins;r.Division="DIVISION "..r.DivisionNumber;r.Rank="STEP "..r.DivisionWins.." / 10"end
	end
	local playerStats=r.PlayerStats;playerStats.MatchesPlayed+=1
	if matchStats and matchStats.PlayerRating then local previous=playerStats.AverageRating or 0;playerStats.AverageRating=math.floor(((previous*(playerStats.MatchesPlayed-1)+matchStats.PlayerRating)/playerStats.MatchesPlayed)*10+.5)/10;playerStats.Goals+=(matchStats.Match and matchStats.Match.Goals or 0);if matchStats.MOTM and matchStats.MOTM.Team==matchStats.Team then playerStats.MOTM+=1 end;local assists=0;for _,entry in matchStats.Full and matchStats.Full.PlayerRatings or{}do if entry.Team==matchStats.Team then assists+=entry.Assists or 0;if(entry.Goals or 0)>=3 then playerStats.HatTricks+=1 end end end;playerStats.Assists+=assists end
	table.insert(r.History,1,{Id=resultId~=""and resultId or nil,Result=result,Opponent=string.sub(opponent,1,32),Score=string.sub(score,1,12),RPDelta=delta,At=os.time(),Reward=compactReward(matchStats and matchStats.Reward),Stats=compactHistoryStats(matchStats)});while#r.History>20 do table.remove(r.History)end;self.Publish(player,"Ranked",self:GetClientData(player));return true
end
function Service:AttachHistoryReward(player:Player,resultId:string,reward:any):boolean
	local p=self.Profiles:GetProfile(player);if not p or not p.Ranked or type(p.Ranked.History)~="table"then return false end
	local compact=compactReward(reward);if not compact then return false end
	for _,entry in p.Ranked.History do
		if tostring(entry.Id or "")==tostring(resultId or "")then
			entry.Reward=compact
			entry.Stats=type(entry.Stats)=="table"and entry.Stats or{}
			entry.Stats.Reward=compact
			self.Publish(player,"Ranked",self:GetClientData(player))
			return true
		end
	end
	return false
end
return Service
