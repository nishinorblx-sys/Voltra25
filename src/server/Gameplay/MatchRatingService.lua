--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.VTR.Shared.MatchRatingConfig)
local Service={};Service.__index=Service
local function role(position:string):string
	position=string.upper(position)
	if position=="GK"then return"GK"end
	if position=="CB"then return"CB"end
	if position=="LB"or position=="RB"or position=="LWB"or position=="RWB"then return"FB"end
	if position=="CDM"then return"CDM"end
	if position=="CAM"then return"CAM"end
	if position=="CM"or position=="LM"or position=="RM"then return"CM"end
	if position=="LW"or position=="RW"then return"W"end
	return"ST"
end
local function rounded(value:number):number return math.floor(value*10+.5)/10 end
function Service.new(models:{Model})
	local entries={}
	for _,model in models do entries[model]={Model=model,playerId=model:GetAttribute("playerId"),cardInstanceId=model:GetAttribute("cardInstanceId"),Name=model:GetAttribute("DisplayName")or model.Name,Position=model:GetAttribute("position")or"CM",Team=model:GetAttribute("VTRTeam")or"Home",Number=model:GetAttribute("ShirtNumber")or 0,Delta=0,Events={}}end
	return setmetatable({Entries=entries},Service)
end
function Service:Record(model:Model,event:string,count:number?)
	local entry=self.Entries[model];if not entry then return end
	local amount=count or 1;entry.Events[event]=(entry.Events[event]or 0)+amount
	local weight=(Config.ByRole[role(entry.Position)]and Config.ByRole[role(entry.Position)][event])or Config.Universal[event]or 0
	entry.Delta+=weight*amount
	model:SetAttribute("VTRMatchRating",rounded(math.clamp(Config.Base+entry.Delta,Config.Minimum,Config.Maximum)))
end
function Service:Serialize(gameSeconds:number,homeScore:number,awayScore:number):any
	local result={};local best:any=nil
	for model,entry in self.Entries do
		local minutes=math.max(0,gameSeconds/60);local scale=minutes<15 and.35 or minutes<30 and.6 or minutes<60 and.85 or 1
		local events=entry.Events;local delta=entry.Delta
		local passes=(events.SuccessfulPass or 0)+(events.BadPass or 0)
		if passes>=10 then local accuracy=(events.SuccessfulPass or 0)/passes;if accuracy>=.9 then delta+=.35 elseif accuracy>=.8 then delta+=.2 elseif passes>=20 and accuracy<.65 then delta-=.25 end end
		if (events.Goal or 0)>=2 then delta+=.35 elseif (events.Shot or 0)>=5 and(events.Goal or 0)==0 then delta-=.25 end
		local defensive=(events.TackleWon or 0)+(events.Interception or 0)+(events.Block or 0)+(events.Clearance or 0);if defensive>=8 then delta+=.55 elseif defensive>=5 then delta+=.35 end
		if role(entry.Position)=="GK"and(events.Save or 0)>=5 and(entry.Team=="Home"and awayScore or homeScore)<=1 then delta+=.5 end
		if minutes>=60 and(entry.Team=="Home"and awayScore or homeScore)==0 then local clean={GK=1,CB=.7,FB=.6,CDM=.4,CM=.2,CAM=.2,W=.1,ST=.1};delta+=clean[role(entry.Position)]or 0 end
		local rating=rounded(math.clamp(Config.Base+delta*scale,Config.Minimum,Config.Maximum))
		local serialized={playerId=entry.playerId,cardInstanceId=entry.cardInstanceId,Name=entry.Name,Position=entry.Position,Team=entry.Team,Number=entry.Number,Rating=rating,Events=table.clone(events),Goals=events.Goal or 0,Assists=events.Assist or 0,DefensiveActions=defensive,Saves=events.Save or 0}
		table.insert(result,serialized)
		if not best or rating>best.Rating or rating==best.Rating and((serialized.Goals+serialized.Assists)>(best.Goals+best.Assists)or serialized.DefensiveActions>best.DefensiveActions or serialized.Saves>best.Saves)then best=serialized end
	end
	table.sort(result,function(a,b)if a.Team~=b.Team then return a.Team=="Home"end;if a.Rating~=b.Rating then return a.Rating>b.Rating end;return a.Name<b.Name end)
	return{Players=result,MOTM=best}
end
return Service
