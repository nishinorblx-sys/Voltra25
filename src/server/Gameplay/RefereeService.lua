--!strict
local Service={};Service.__index=Service
function Service.new(remote:RemoteEvent,stats:any,onRestart:any,pitchCFrame:CFrame?,width:number?,length:number?)
	return setmetatable({Remote=remote,Stats=stats,OnRestart=onRestart,Fouls={},Yellows={},Random=Random.new(),PitchCFrame=pitchCFrame,Width=width or 0,Length=length or 0,Half=1},Service)
end
function Service:SetHalf(half:number?)self.Half=half or 1 end
function Service:_penaltyBoxOwner(location:Vector3):string?
	if not self.PitchCFrame or self.Width<=0 or self.Length<=0 then return nil end
	local localPoint=self.PitchCFrame:PointToObjectSpace(location)
	local inWidth=math.abs(localPoint.X)<=22
	if not inWidth then return nil end
	local nearPositive=math.abs((self.Length*.5)-localPoint.Z)<=18
	local nearNegative=math.abs((-self.Length*.5)-localPoint.Z)<=18
	if not nearPositive and not nearNegative then return nil end
	local positiveOwner=(self.Half or 1)>=2 and "Away" or "Home"
	local negativeOwner=(self.Half or 1)>=2 and "Home" or "Away"
	return nearPositive and positiveOwner or negativeOwner
end
function Service:CallFoul(offender:Model,victim:Model,kind:string,location:Vector3,forceCard:boolean?,redChance:number?):(boolean,string?)
	local team=tostring(offender:GetAttribute("VTRTeam")or"Home");local restartTeam=team=="Home"and"Away"or"Home"
	self.Fouls[offender]=(self.Fouls[offender]or 0)+1;self.Stats:Add(team,"Fouls");self.Stats:Event(offender,"FoulCommitted");self.Stats:Event(victim,"FoulWon")
	local card:string?=nil;local secondYellow=false;local cardChance=math.clamp((self.Fouls[offender]or 1)*.1,0,1)
	if forceCard or self.Random:NextNumber()<cardChance then
		if redChance and self.Random:NextNumber()<redChance then card="Red"else self.Yellows[offender]=(self.Yellows[offender]or 0)+1;secondYellow=self.Yellows[offender]>=2;card=secondYellow and"Red"or"Yellow"end
		if card=="Red"then
			self.Stats:Add(team,"RedCards");self.Stats:Event(offender,"RedCard");offender:SetAttribute("VTRRedCard",true);offender:SetAttribute("VTRSentOff",true);offender:SetAttribute("VTRForceIdle",true)
			task.delay(secondYellow and 2.2 or 1.2,function()
				if not offender.Parent then return end
				local root=offender:FindFirstChild("HumanoidRootPart")::BasePart?
				local humanoid=offender:FindFirstChildOfClass("Humanoid")
				if humanoid then humanoid.WalkSpeed=0;humanoid:Move(Vector3.zero,false)end
				if root then root.Anchored=true;offender:PivotTo(CFrame.new(0,-600,0))end
			end)
		else
			self.Stats:Add(team,"YellowCards");self.Stats:Event(offender,"YellowCard");offender:SetAttribute("VTRYellowCard",true)
		end
	end
	local victimTeam=tostring(victim:GetAttribute("VTRTeam")or restartTeam)
	local boxOwner=self:_penaltyBoxOwner(location)
	local restartKind=(boxOwner~=nil and boxOwner==team and victimTeam==restartTeam)and"Penalty"or"FreeKick"
	self.Remote:FireAllClients({
		Type="Foul",
		Actor=offender,
		Victim=victim,
		FoulKind=kind,
		Card=card,
		SecondYellow=secondYellow,
		Location=location,
		RestartKind=restartKind,
		FouledPlayerName=tostring(victim:GetAttribute("DisplayName") or victim.Name),
		OffenderName=tostring(offender:GetAttribute("DisplayName") or offender.Name),
		FouledPlayer=victim,
	})
	task.defer(self.OnRestart,restartTeam,location,restartKind,victim)
	return true,card
end
function Service.Enforce(models:{Model},pitchCFrame:CFrame,width:number,length:number)
	for _,model in models do if model:GetAttribute("VTRSentOff")==true then continue end;local root=model:FindFirstChild("HumanoidRootPart")::BasePart?;if root then local p=pitchCFrame:PointToObjectSpace(root.Position);if math.abs(p.X)>width/2+8 or math.abs(p.Z)>length/2+12 or p.Y< -8 then local safe=Vector3.new(math.clamp(p.X,-width/2+3,width/2-3),3,math.clamp(p.Z,-length/2+3,length/2-3));model:PivotTo(CFrame.new(pitchCFrame:PointToWorldSpace(safe)))end end end
end
return Service
