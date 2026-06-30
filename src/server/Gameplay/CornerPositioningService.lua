--!strict
local Service={}

local function root(model:Model):BasePart?return model:FindFirstChild("HumanoidRootPart")::BasePart? end
local function world(frame:CFrame,x:number,z:number):Vector3 return frame:PointToWorldSpace(Vector3.new(x,3,z))end
local function move(model:Model,position:Vector3,lookAt:Vector3)
	model:PivotTo(CFrame.lookAt(position,Vector3.new(lookAt.X,position.Y,lookAt.Z)))
	local humanoid=model:FindFirstChildOfClass("Humanoid");if humanoid then humanoid:Move(Vector3.zero,false)end
	local modelRoot=root(model);if modelRoot then modelRoot.AssemblyLinearVelocity=Vector3.zero;modelRoot.AssemblyAngularVelocity=Vector3.zero end
end

local function clearCornerState(model:Model)
	model:SetAttribute("VTRCornerRole",nil)
	model:SetAttribute("VTRForceIdle",nil)
end

local function chooseTaker(team:{Model}):Model
	local best=team[9]or team[11]or team[2]or team[1];local score=-math.huge
	for _,model in team do
		if model:GetAttribute("position")~="GK"then local value=(tonumber(model:GetAttribute("PAS"))or 60)+(tonumber(model:GetAttribute("Curve"))or 60)*.55;if value>score then best=model;score=value end end
	end
	return best
end

function Service.Position(teams:any,restartTeam:string,location:Vector3,pitchCFrame:CFrame,width:number,length:number,ballRadius:number):any
	local localExit=pitchCFrame:PointToObjectSpace(location);local cornerSign=localExit.X>=0 and 1 or-1;local goalSign=localExit.Z>=0 and 1 or-1
	local cornerX=cornerSign*(width*.5-1.1);local cornerZ=goalSign*(length*.5-1.1);local spot=world(pitchCFrame,cornerX,cornerZ)
	for _,side in teams do for _,model in side do clearCornerState(model)end end
	local taker=chooseTaker(teams[restartTeam]);move(taker,world(pitchCFrame,cornerX-cornerSign*3.4,cornerZ-goalSign*2.2),world(pitchCFrame,0,cornerZ-goalSign*14));taker:SetAttribute("VTRForceIdle",true)
	local takerHumanoid=taker:FindFirstChildOfClass("Humanoid");if takerHumanoid then takerHumanoid:Move(Vector3.zero,false);takerHumanoid.WalkSpeed=0 end
	local takerRoot=root(taker);if takerRoot then takerRoot.AssemblyLinearVelocity=Vector3.zero;takerRoot.AssemblyAngularVelocity=Vector3.zero;takerRoot.Anchored=true end
	local attackers={};for _,model in teams[restartTeam]do if model~=taker then table.insert(attackers,model)end end
	local attackTargets={
		Vector2.new(cornerSign*5,goalSign*(length*.5-8)),Vector2.new(0,goalSign*(length*.5-16)),Vector2.new(-cornerSign*7,goalSign*(length*.5-10)),
		Vector2.new(cornerSign*15,goalSign*(length*.5-20)),Vector2.new(cornerSign*22,goalSign*(length*.5-31)),Vector2.new(-cornerSign*18,goalSign*(length*.5-29)),
	}
	for index,model in attackers do local point=attackTargets[index]or Vector2.new(((index%3)-1)*18,goalSign*(length*.5-43-index));move(model,world(pitchCFrame,point.X,point.Y),spot);model:SetAttribute("VTRCornerRole",index==1 and"NearPost"or index==2 and"PenaltySpot"or index==3 and"FarPost"or index==5 and"ShortOption"or"Rebound")end
	local defending=restartTeam=="Home"and"Away"or"Home";local defenders=teams[defending]
	for index,model in defenders do
		local position:string=tostring(model:GetAttribute("position")or"")
		if position=="GK"then move(model,world(pitchCFrame,0,goalSign*(length*.5-3.2)),world(pitchCFrame,cornerX*.25,cornerZ-goalSign*14))
		else local marked=attackTargets[math.clamp(index-1,1,#attackTargets)];local x=marked and marked.X-cornerSign*(index%2==0 and 1.8 or-1.8)or((index%4)-1.5)*7;local z=marked and marked.Y-goalSign*2.2 or goalSign*(length*.5-22-index);if index==3 then x=cornerSign*19;z=goalSign*(length*.5-26)end;move(model,world(pitchCFrame,x,z),spot);model:SetAttribute("VTRCornerRole",index<=2 and"ZonalSixYard"or index==3 and"ShortCover"or"Marker")end
	end
	return{Taker=taker,Spot=spot,BallPosition=spot+pitchCFrame.UpVector*(ballRadius+.08),CornerSign=cornerSign,GoalSign=goalSign,RestartTeam=restartTeam,DefendingTeam=defending,Attackers=attackers,Defenders=defenders,ShortOption=attackers[5]or attackers[1]}
end

function Service.ActivateRuns(data:any,target:Vector3)
	local now=os.clock()
	local frame=data.PitchCFrame or CFrame.identity
	for index,model in data.Attackers do local offset=((index%3)-1)*3.5;model:SetAttribute("VTRCornerRunTarget",target+frame.RightVector*offset+frame.LookVector*(index%2==0 and 2.5 or-2.5));model:SetAttribute("VTRCornerRunUntil",now+1.55)end
	for index,model in data.Defenders do if model:GetAttribute("position")~="GK"then local attacker=data.Attackers[math.clamp(index-1,1,#data.Attackers)];local attackerRoot=attacker and root(attacker);if attackerRoot then model:SetAttribute("VTRCornerRunTarget",attackerRoot.Position);model:SetAttribute("VTRCornerRunUntil",now+1.4)end end end
end

return Service
