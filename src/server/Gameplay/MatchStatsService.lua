--!strict
local MatchRatingService=require(script.Parent.MatchRatingService)
local Service={};Service.__index=Service
local KEYS={"Possession","Shots","ShotsOnTarget","Goals","ExpectedGoals","Passes","CompletedPasses","Tackles","CompletedTackles","Interceptions","Saves","Corners","Fouls","Offsides","YellowCards","RedCards","CornersIntoBox","CornerReachedTeammate","CornerGoals","Blocks","Clearances","Crosses","CompletedCrosses","Dribbles","CompletedDribbles","KeyPasses","BigChancesCreated","Errors"}
local function bucket():any local value={};for _,key in KEYS do value[key]=0 end;return value end
local function distanceChance(distance:number):number
	if distance<=70 then return .95-(distance/70)*.06 end
	if distance<=160 then return .89-((distance-70)/90)*.69 end
	if distance<=190 then return .2-((distance-160)/30)*.19 end
	return .01
end
function Service.new(models:{Model},pitchCFrame:CFrame,width:number,length:number)
	return setmetatable({Home=bucket(),Away=bucket(),Goals={},PassMap={Home={},Away={}},ShotMap={Home={},Away={}},PositionMap={},PitchCFrame=pitchCFrame,Width=width,Length=length,Ratings=MatchRatingService.new(models),LastGameSeconds=0,PositionAccumulator=0},Service)
end
function Service:Add(team:string,key:string,amount:number?)local target=self[team];if target and target[key]~=nil then target[key]+=(amount or 1)end end
function Service:Event(model:Model,event:string,amount:number?)local team=tostring(model:GetAttribute("VTRTeam")or"Home");if event=="Block"then self:Add(team,"Blocks",amount)elseif event=="Clearance"then self:Add(team,"Clearances",amount)elseif event=="SuccessfulDribble"then self:Add(team,"CompletedDribbles",amount);self:Add(team,"Dribbles",amount)elseif event=="FailedDribble"then self:Add(team,"Dribbles",amount)elseif event=="KeyPass"then self:Add(team,"KeyPasses",amount)elseif event=="BigChanceCreated"then self:Add(team,"BigChancesCreated",amount)elseif event=="Error"or event=="ErrorLeadingToGoal"then self:Add(team,"Errors",amount)end;self.Ratings:Record(model,event,amount)end
function Service:RecordPassAttempt(model:Model)self:Add(tostring(model:GetAttribute("VTRTeam")or"Home"),"Passes");self:Event(model,"PassAttempt")end
function Service:RecordPassCompleted(model:Model,receiver:Model?,startPoint:Vector3?,endPoint:Vector3?)
	local team=tostring(model:GetAttribute("VTRTeam")or"Home");self:Add(team,"CompletedPasses");self:Event(model,"SuccessfulPass")
	self.LastCompletedPass={Passer=model,Receiver=receiver,At=os.clock(),Team=team}
	if receiver then self:Event(receiver,"PossessionWon")end
	if startPoint and endPoint then
		local side=team=="Home"and-1 or 1;local a=self.PitchCFrame:PointToObjectSpace(startPoint);local b=self.PitchCFrame:PointToObjectSpace(endPoint)
		table.insert(self.PassMap[team],{From={X=a.X,Z=a.Z},To={X=b.X,Z=b.Z},Passer=model:GetAttribute("DisplayName"),Receiver=receiver and receiver:GetAttribute("DisplayName")or nil,Completed=true})
		if(b.Z-a.Z)*side>=self.Length*.1 then self:Event(model,"ProgressivePass")end
	end
end
function Service:RecordPassFailed(model:Model,interceptor:Model?)self:Event(model,"BadPass");self:Event(model,"PossessionLost");if interceptor then self:Add(tostring(interceptor:GetAttribute("VTRTeam")or"Home"),"Interceptions");self:Event(interceptor,"Interception")end end
function Service:CalculateXG(model:Model,position:Vector3,pressure:number?,shotType:string?):number
	local team=tostring(model:GetAttribute("VTRTeam")or"Home");local localPosition=self.PitchCFrame:PointToObjectSpace(position);local goalZ=team=="Home"and-self.Length*.5 or self.Length*.5;local depth=math.abs(goalZ-localPosition.Z);local wide=math.abs(localPosition.X);local distance=math.sqrt(depth*depth+(wide*.58)*(wide*.58));local base=distanceChance(distance)
	if shotType=="Penalty"then base=.76 end
	if shotType~="Penalty" and distance<=70 then return .95 end
	local widePenalty=math.clamp((wide-18)/math.max(1,self.Width*.32),0,.62)
	base*=1-widePenalty
	base-=math.clamp(pressure or 0,0,1)*.15;if model:GetAttribute("VTRSprinting")==true then base-=.05 end
	return math.clamp(base,.01,.95)
end
function Service:RecordShot(model:Model,onTarget:boolean,xg:number)
	local team=tostring(model:GetAttribute("VTRTeam")or"Home");self:Add(team,"Shots");self:Add(team,"ExpectedGoals",xg);self:Event(model,"Shot");self.Ratings:Record(model,"ExpectedGoals",xg);if onTarget then self:Add(team,"ShotsOnTarget");self:Event(model,"ShotOnTarget")else self:Event(model,"ShotOffTarget")end;if xg>=.3 then model:SetAttribute("VTRLastBigChance",true)end
	local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
	if root then local p=self.PitchCFrame:PointToObjectSpace(root.Position);table.insert(self.ShotMap[team],{From={X=p.X,Z=p.Z},Shooter=model:GetAttribute("DisplayName"),OnTarget=onTarget,XG=math.floor(xg*100)/100})end
	local pass=self.LastCompletedPass;if pass and pass.Receiver==model and pass.Team==team and os.clock()-pass.At<=5 then self:Event(pass.Passer,"KeyPass");self:Event(pass.Passer,"ChanceCreated");if xg>=.3 then self:Event(pass.Passer,"BigChanceCreated")end;self.PendingAssist={Passer=pass.Passer,Scorer=model,At=os.clock(),Team=team}end
end
function Service:RecordTackle(model:Model,success:boolean) local team=tostring(model:GetAttribute("VTRTeam")or"Home");self:Add(team,"Tackles");if success then self:Add(team,"CompletedTackles");self:Event(model,"TackleWon")else self:Event(model,"TackleFailed")end end
function Service:RecordSave(model:Model,xg:number?)local team=tostring(model:GetAttribute("VTRTeam")or"Home");self:Add(team,"Saves");self:Event(model,"Save");if(xg or 0)>=.3 then self:Event(model,"DifficultSave")end end
function Service:RecordPositions(models:{Model},dt:number)
	self.PositionAccumulator+=dt
	if self.PositionAccumulator<.65 then return end
	self.PositionAccumulator=0
	for _,model in models do
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if not root then continue end
		local localPosition=self.PitchCFrame:PointToObjectSpace(root.Position)
		local key=tostring(model:GetAttribute("playerId")or model.Name)
		local samples=self.PositionMap[key]
		if not samples then samples={};self.PositionMap[key]=samples end
		local normalizedX=math.clamp(localPosition.X/math.max(1,self.Width)+.5,0,1)
		local normalizedZ=math.clamp(localPosition.Z/math.max(1,self.Length)+.5,0,1)
		local sample={
			X=math.floor(localPosition.X*10+.5)/10,
			Z=math.floor(localPosition.Z*10+.5)/10,
			NX=math.floor(normalizedX*1000+.5)/1000,
			NZ=math.floor(normalizedZ*1000+.5)/1000,
		}
		if #samples<180 then table.insert(samples,sample)else samples[(math.floor(os.clock()*10)%#samples)+1]=sample end
	end
end
function Service:Goal(team:string,scorer:any?,ownGoal:boolean?,gameSeconds:number?)
	self:Add(team,"Goals");local name=typeof(scorer)=="Instance"and scorer:GetAttribute("DisplayName")or scorer or"Unknown";local assist=nil;local pending=self.PendingAssist;if not ownGoal and pending and pending.Scorer==scorer and pending.Team==team and os.clock()-pending.At<=10 then assist=pending.Passer:GetAttribute("DisplayName");self:Event(pending.Passer,"Assist")end;table.insert(self.Goals,{Team=team,Scorer=name,Assist=assist,At=os.clock(),GameSeconds=gameSeconds or self.LastGameSeconds or 0,OwnGoal=ownGoal==true});if typeof(scorer)=="Instance"then self:Event(scorer,ownGoal and"OwnGoal"or"Goal")end;self.PendingAssist=nil
end
function Service:Serialize(homeScore:number,awayScore:number,gameSeconds:number?):any
	gameSeconds=gameSeconds or self.LastGameSeconds;self.LastGameSeconds=gameSeconds
	local total=math.max(.01,self.Home.Possession+self.Away.Possession)
	local function team(v:any)local attempts=math.max(1,v.Passes);local dribbles=math.max(1,v.Dribbles);return{Possession=math.floor(v.Possession/total*100+.5),Shots=v.Shots,ShotsOnTarget=v.ShotsOnTarget,ShotsOffTarget=math.max(0,v.Shots-v.ShotsOnTarget),Goals=v.Goals,ExpectedGoals=math.floor(v.ExpectedGoals*100)/100,PassesAttempted=v.Passes,PassesCompleted=v.CompletedPasses,PassAccuracy=math.floor(v.CompletedPasses/attempts*100+.5),TacklesAttempted=v.Tackles,TacklesCompleted=v.CompletedTackles,Interceptions=v.Interceptions,Saves=v.Saves,Corners=v.Corners,Fouls=v.Fouls,Offsides=v.Offsides,YellowCards=v.YellowCards,RedCards=v.RedCards,CornersIntoBox=v.CornersIntoBox,CornerReachedTeammate=v.CornerReachedTeammate,CornerGoals=v.CornerGoals,BlockedShots=v.Blocks,Blocks=v.Blocks,Clearances=v.Clearances,Crosses=v.Crosses,CompletedCrosses=v.CompletedCrosses,Dribbles=v.Dribbles,DribblesCompleted=v.CompletedDribbles,DribbleAccuracy=math.floor(v.CompletedDribbles/dribbles*100+.5),KeyPasses=v.KeyPasses,BigChanceCreated=v.BigChancesCreated,Errors=v.Errors}end
	local ratings=self.Ratings:Serialize(gameSeconds,homeScore,awayScore)
	for _,entry in ratings.Players do local key=tostring(entry.playerId or"");if key~=""and self.PositionMap[key]then entry.HeatMap=self.PositionMap[key]end end
	return{HomeScore=homeScore,AwayScore=awayScore,Home=team(self.Home),Away=team(self.Away),Goals=self.Goals,Assists={},PassMap=self.PassMap,ShotMap=self.ShotMap,PlayerRatings=ratings.Players,MOTM=ratings.MOTM,PlayerRating=ratings.MOTM and ratings.MOTM.Rating or 6}
end
return Service
