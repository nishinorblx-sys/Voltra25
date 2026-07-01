from pathlib import Path
import re

def replace_regex(text, pattern, replacement, label):
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count == 0:
        print("skipped", label)
        return text
    return new_text

setpiece_path = Path("src/server/Gameplay/SetPieceService.lua")
text = setpiece_path.read_text(encoding="utf-8")

new_corner_helpers = '''local function cornerAttr(model:Model,key:string,fallback:number):number
\treturn tonumber(model:GetAttribute(key)) or fallback
end

local function cornerAerialScore(model:Model):number
\tlocal overall=cornerAttr(model,"overall",60)
\tlocal heading=tonumber(model:GetAttribute("HeadingAccuracy")) or tonumber(model:GetAttribute("Heading")) or tonumber(model:GetAttribute("Finishing")) or overall
\tlocal jumping=tonumber(model:GetAttribute("Jumping")) or tonumber(model:GetAttribute("PHY")) or overall
\tlocal strength=tonumber(model:GetAttribute("Strength")) or tonumber(model:GetAttribute("PHY")) or overall
\tlocal height=tonumber(model:GetAttribute("Height")) or 70
\treturn overall*.18+heading*.36+jumping*.18+strength*.12+math.clamp(height-66,0,16)*1.2
end

local function nearestCornerDefenderDistance(data:any,teams:any,receiver:Model):number
\tlocal receiverRoot=root(receiver)
\tif not receiverRoot then return 0 end
\tlocal best=math.huge
\tfor _,defender in teams[data.DefendingTeam] or {} do
\t\tif not isKeeper(defender) and defender:GetAttribute("VTRSentOff")~=true then
\t\t\tlocal defenderRoot=root(defender)
\t\t\tif defenderRoot then
\t\t\t\tbest=math.min(best,(Vector3.new(defenderRoot.Position.X-receiverRoot.Position.X,0,defenderRoot.Position.Z-receiverRoot.Position.Z)).Magnitude)
\t\t\tend
\t\tend
\tend
\treturn best
end

local function cornerLanding(data:any,receiver:Model,role:string): (Vector3,string,number)
\tlocal goalSign=tonumber(data.GoalSign)or 1
\tlocal cornerSign=tonumber(data.CornerSign)or 1
\tlocal length=tonumber(data.Length)or 704
\tlocal x=0
\tlocal z=goalSign*(length*.5-18)
\tlocal delivery="Cross"
\tlocal power=.64
\tif role=="NearPost" then
\t\tx=cornerSign*5
\t\tz=goalSign*(length*.5-8)
\t\tdelivery="Driven"
\t\tpower=.74
\telseif role=="FarPost" then
\t\tx=-cornerSign*11
\t\tz=goalSign*(length*.5-11)
\t\tdelivery="Lob"
\t\tpower=.7
\telseif role=="PenaltySpot" then
\t\tx=0
\t\tz=goalSign*(length*.5-18)
\t\tdelivery="Cross"
\t\tpower=.66
\telse
\t\tx=-cornerSign*4
\t\tz=goalSign*(length*.5-25)
\t\tdelivery="Cross"
\t\tpower=.62
\tend
\tlocal planned=data.PitchCFrame:PointToWorldSpace(Vector3.new(x,.15,z))
\tlocal receiverRoot=root(receiver)
\tif receiverRoot then
\t\tlocal velocity=Vector3.new(receiverRoot.AssemblyLinearVelocity.X,0,receiverRoot.AssemblyLinearVelocity.Z)
\t\tlocal lead=velocity.Magnitude>1.5 and velocity.Unit*math.clamp(velocity.Magnitude*.28,3,12) or Vector3.zero
\t\tplanned=planned:Lerp(receiverRoot.Position+lead,.32)
\tend
\treturn planned,delivery,power
end

local function cornerDeliveryPlan(data:any,teams:any,restartTeam:string): any
\tlocal best:Model?=nil
\tlocal bestScore=-math.huge
\tlocal bestRole="PenaltySpot"
\tfor _,candidate in teams[restartTeam] or {} do
\t\tif candidate~=data.Taker and not isKeeper(candidate) and candidate:GetAttribute("VTRSentOff")~=true then
\t\t\tlocal candidateRoot=root(candidate)
\t\t\tif candidateRoot then
\t\t\t\tlocal localPosition=data.PitchCFrame:PointToObjectSpace(candidateRoot.Position)
\t\t\t\tlocal role=tostring(candidate:GetAttribute("VTRCornerRole") or "")
\t\t\t\tlocal position=tostring(candidate:GetAttribute("position") or "")
\t\t\t\tlocal inBox=math.abs(localPosition.X)<=data.Width*.42 and (tonumber(data.GoalSign)or 1)>0 and localPosition.Z>=data.Length*.5-125 or math.abs(localPosition.X)<=data.Width*.42 and localPosition.Z<=-data.Length*.5+125
\t\t\t\tif inBox and role~="ShortOption" then
\t\t\t\t\tlocal score=cornerAerialScore(candidate)
\t\t\t\t\tscore+=role=="NearPost" and 20 or role=="FarPost" and 20 or role=="PenaltySpot" and 16 or role=="Rebound" and 4 or 0
\t\t\t\t\tscore+=position=="ST" and 24 or position=="CB" and 22 or position=="CAM" and 12 or position=="CM" and 8 or 0
\t\t\t\t\tscore+=math.clamp(nearestCornerDefenderDistance(data,teams,candidate),0,22)*1.45
\t\t\t\t\tscore-=math.abs(localPosition.X)*.025
\t\t\t\t\tif score>bestScore then
\t\t\t\t\t\tbest=candidate
\t\t\t\t\t\tbestScore=score
\t\t\t\t\t\tbestRole=role~="" and role or "PenaltySpot"
\t\t\t\t\tend
\t\t\t\tend
\t\t\tend
\t\tend
\tend
\tif best then
\t\tlocal target,delivery,power=cornerLanding(data,best,bestRole)
\t\treturn{Receiver=best,Target=target,Delivery=delivery,Power=power,Role=bestRole}
\tend
\tlocal goalSign=tonumber(data.GoalSign)or 1
\treturn{Receiver=nil,Target=data.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,goalSign*((tonumber(data.Length)or 704)*.5-18))),Delivery="Cross",Power=.62,Role="PenaltySpot"}
end

'''

text = replace_regex(
    text,
    r'local function cornerDangerReceiver\(data:any,teams:any,restartTeam:string\): Model\?.*?end\s*\n\s*function Service:_releaseCorner',
    new_corner_helpers + "\nfunction Service:_releaseCorner",
    "corner helper replacement"
)

text = replace_regex(
    text,
    r'\tif delivery~="Short"then.*?\n\tend\n\tlocal takerRoot=',
    '''\tlocal plannedReceiver:Model?=nil
\tif delivery~="Short"then
\t\tlocal plan=cornerDeliveryPlan(active.Data,self.Teams,active.Data.Team or active.Data.RestartTeam or tostring(active.Data.Taker:GetAttribute("VTRTeam") or "Home"))
\t\tplannedReceiver=plan.Receiver
\t\ttarget=plan.Target
\t\tdelivery=plan.Delivery
\t\tpower=plan.Power
\t\tactive.Data.CornerReceiver=plannedReceiver
\t\tactive.Data.CornerPlanRole=plan.Role
\tend
\tlocal takerRoot=''',
    "corner release plan"
)

text = text.replace(
    'local kicked=self.BallService:CornerKick(active.Data.Taker,target,delivery,power,delivery=="Short"and active.Data.ShortOption or nil)',
    'local kicked=self.BallService:CornerKick(active.Data.Taker,target,delivery,power,delivery=="Short"and active.Data.ShortOption or plannedReceiver)',
    1
)

text = text.replace(
    'else task.delay(1.25,function()if self.ActiveCorner and self.ActiveCorner.Sequence==sequence then local target=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,data.GoalSign*(self.World.Length*.5-58)));self:_releaseCorner(player,{Delivery="Lob",Power=.65,Target=target,ServerAI=true})end end)end',
    'else task.delay(1.25,function()if self.ActiveCorner and self.ActiveCorner.Sequence==sequence then local target=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,data.GoalSign*(self.World.Length*.5-18)));self:_releaseCorner(player,{Delivery="Cross",Power=.65,Target=target,ServerAI=true})end end)end',
    1
)

setpiece_path.write_text(text, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = ball.replace(
    'self:_touch(model);self.MotionKind="Corner";self.MotionStarted=os.clock();self.Ball:SetAttribute("VTRMotionKind","Corner");self.Ball:SetAttribute("VTRLastCornerTeam",tostring(model:GetAttribute("VTRTeam")or"Home"));self.Ball:SetAttribute("VTRCornerTakenAt",os.clock());self.Ball:SetAttribute("VTRCornerEnteredBox",false)',
    'local cornerTeam=tostring(model:GetAttribute("VTRTeam")or"Home");self:_touch(model);self.MotionKind="Corner";self.MotionStarted=os.clock();self.Ball:SetAttribute("VTRMotionKind","Corner");self.Ball:SetAttribute("VTRLastCornerTeam",cornerTeam);self.Ball:SetAttribute("VTRCornerTakenAt",os.clock());self.Ball:SetAttribute("VTRCornerEnteredBox",false);self.Ball:SetAttribute("VTRPassTarget",target);self.Ball:SetAttribute("VTRPassTeam",cornerTeam);self.Ball:SetAttribute("VTRPassReceiver",receiver and receiver.Name or nil);self.Ball:SetAttribute("VTRPassStartedAt",os.clock())',
    1
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

context_path = Path("src/server/Gameplay/AIContextBuilder.lua")
context = context_path.read_text(encoding="utf-8")

context = context.replace(
    'and motionKind == "Pass"',
    'and (motionKind == "Pass" or motionKind == "Corner")',
    1
)

context_path.write_text(context, encoding="utf-8", newline="\n")

print("updated smarter corners")
