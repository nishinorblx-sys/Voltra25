from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

def regex_once(text, pattern, new, label):
    next_text, count = re.subn(pattern, new, text, count=1, flags=re.S)
    if count == 0:
        print("skipped", label)
        return text
    return next_text

curve_path = Path("src/server/Gameplay/BallCurveService.lua")
curve = curve_path.read_text(encoding="utf-8")

if "function Service:StartPass" not in curve:
    curve = curve.replace(
        "function Service:StartShot(model:Model,direction:Vector3,flightTime:number):Vector3",
        '''function Service:StartPass(model:Model,direction:Vector3,speed:number,distance:number,lofted:boolean?,flightTime:number?):Vector3
\tlocal flatDirection=Vector3.new(direction.X,0,direction.Z)
\tif flatDirection.Magnitude<.1 then return Vector3.zero end
\tlocal passing=math.clamp(tonumber(model:GetAttribute("PAS"))or 60,1,99)
\tlocal curveStat=math.clamp(tonumber(model:GetAttribute("Curve"))or passing,1,99)
\tlocal footSign=model:GetAttribute("PreferredFoot")=="Left"and-1 or 1
\tlocal lateral=flatDirection.Unit:Cross(Vector3.yAxis)*footSign
\tlocal duration=math.clamp(flightTime or distance/math.max(speed,1),lofted and .7 or .22,lofted and 2.45 or 1.05)
\tlocal base=lofted and 5.2 or 3.2
\tlocal strength=(base+curveStat*.045+math.clamp(distance,0,120)/120*(lofted and 3.2 or 2.1))*(1.1-passing/900)
\tlocal decay=lofted and .46 or .82
\tself.Active={Lateral=lateral,Strength=strength,Remaining=duration,Decay=decay}
\tlocal displacement=strength/decay*duration-strength/(decay*decay)*(1-math.exp(-decay*duration))
\tself.Ball.AssemblyAngularVelocity+=Vector3.new(0,footSign*strength*(lofted and 1.8 or 1.45),0)
\treturn -lateral*(displacement/duration)
end

function Service:StartShot(model:Model,direction:Vector3,flightTime:number):Vector3''',
        1
    )

curve_path.write_text(curve, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = replace_once(
    ball,
    '''\t\tif passType=="Lofted"then
\t\t\tlocal destination=targetPoint or(modelRoot and modelRoot.Position+direction)or(self.Ball.Position+direction)
\t\t\tdestination=Vector3.new(destination.X,self.Ball.Position.Y,destination.Z)
\t\t\tlocal effectiveGravity=72;local preferredSpeed=52+amount*30+math.clamp(distance/10,0,18)
\t\t\tvelocity=ballisticVelocity(self.Ball.Position,destination,preferredSpeed,effectiveGravity)or(direction.Unit*finalSpeed+Vector3.yAxis*32)
\t\t\tlocal horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z);local flightTime=distance/math.max(horizontalVelocity.Magnitude,1)
\t\t\tself.PendingCurve=nil;self.PassTargetPoint=destination;self.PassPlan={Target=destination,Distance=math.max(distance,1),InitialSpeed=horizontalVelocity.Magnitude,ArrivalRatio=1,Started=os.clock(),Lofted=true,EffectiveGravity=effectiveGravity,FlightTime=flightTime}
\t\t\tself.Ball:SetAttribute("VTRLobTarget", destination)
\t\t\tself.Ball:SetAttribute("VTRLobPassActive", true)
\t\telse
\t\t\tlocal passAmount=passType=="Through"and math.min(amount,.46)or amount
\t\t\tlocal lift=PassingPower.LiftForDistance(distance,passAmount,false)
\t\t\tvelocity = (flat(direction) + Vector3.new(0,lift,0)).Unit * finalSpeed
\t\t\tself.PendingCurve=passType=="Manual"and nil or{Model = model, Direction = direction, Speed = finalSpeed, Distance = distance}
\t\t\tself.PassTargetPoint=modelRoot and(modelRoot.Position+direction)or nil
\t\t\tself.PassPlan=self.PassTargetPoint and{Target=self.PassTargetPoint,Distance=math.max(distance,1),InitialSpeed=finalSpeed,ArrivalRatio=PassingPower.ArrivalSpeedRatio(passAmount),Started=os.clock()}or nil
\t\t\tif self.PassTargetPoint then self.Ball:SetAttribute("VTRPassTarget", self.PassTargetPoint) end
\t\t\tself.Ball:SetAttribute("VTRLobTarget", nil)
\t\t\tself.Ball:SetAttribute("VTRLobPassActive", nil)
\t\tend''',
    '''\t\tif passType=="Lofted"then
\t\t\tlocal destination=targetPoint or(modelRoot and modelRoot.Position+direction)or(self.Ball.Position+direction)
\t\t\tdestination=Vector3.new(destination.X,self.Ball.Position.Y,destination.Z)
\t\t\tlocal effectiveGravity=72;local preferredSpeed=52+amount*30+math.clamp(distance/10,0,18)
\t\t\tvelocity=ballisticVelocity(self.Ball.Position,destination,preferredSpeed,effectiveGravity)or(direction.Unit*finalSpeed+Vector3.yAxis*32)
\t\t\tlocal horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z);local flightTime=distance/math.max(horizontalVelocity.Magnitude,1)
\t\t\tvelocity+=self.Curve:StartPass(model,destination-self.Ball.Position,horizontalVelocity.Magnitude,distance,true,flightTime)
\t\t\tself.PassCurveStarted=true
\t\t\tself.PendingCurve=nil;self.PassTargetPoint=destination;self.PassPlan={Target=destination,Distance=math.max(distance,1),InitialSpeed=horizontalVelocity.Magnitude,ArrivalRatio=1,Started=os.clock(),Lofted=true,EffectiveGravity=effectiveGravity,FlightTime=flightTime}
\t\t\tself.Ball:SetAttribute("VTRLobTarget", destination)
\t\t\tself.Ball:SetAttribute("VTRLobPassActive", true)
\t\telse
\t\t\tlocal passAmount=passType=="Through"and math.min(amount,.46)or amount
\t\t\tlocal lift=PassingPower.LiftForDistance(distance,passAmount,false)
\t\t\tlocal destination=targetPoint or(modelRoot and(modelRoot.Position+direction))or(self.Ball.Position+direction)
\t\t\tlocal groundDirection=destination-self.Ball.Position
\t\t\tvelocity = (flat(groundDirection) + Vector3.new(0,lift,0)).Unit * finalSpeed
\t\t\tlocal groundFlightTime=distance/math.max(finalSpeed,1)
\t\t\tvelocity+=self.Curve:StartPass(model,groundDirection,finalSpeed,distance,false,groundFlightTime)
\t\t\tself.PassCurveStarted=true
\t\t\tself.PendingCurve=nil
\t\t\tself.PassTargetPoint=destination
\t\t\tself.PassPlan=self.PassTargetPoint and{Target=self.PassTargetPoint,Distance=math.max(distance,1),InitialSpeed=finalSpeed,ArrivalRatio=PassingPower.ArrivalSpeedRatio(passAmount),Started=os.clock()}or nil
\t\t\tif self.PassTargetPoint then self.Ball:SetAttribute("VTRPassTarget", self.PassTargetPoint) end
\t\t\tself.Ball:SetAttribute("VTRLobTarget", nil)
\t\t\tself.Ball:SetAttribute("VTRLobPassActive", nil)
\t\tend''',
    "pass curve branches"
)

ball = replace_once(
    ball,
    'if kind == "Pass" and self.PendingCurve then self.Curve:Start(self.PendingCurve.Model,self.PendingCurve.Direction,self.PendingCurve.Speed,self.PendingCurve.Distance);self.PendingCurve=nil elseif kind=="Pass"or kind~="Shot"then self.Curve:Stop()end',
    'if kind == "Pass" and self.PendingCurve then self.Curve:Start(self.PendingCurve.Model,self.PendingCurve.Direction,self.PendingCurve.Speed,self.PendingCurve.Distance);self.PendingCurve=nil elseif not (kind=="Pass" and self.PassCurveStarted==true) and (kind=="Pass"or kind~="Shot")then self.Curve:Stop()end;self.PassCurveStarted=nil',
    "preserve compensated pass curve"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

brain_path = Path("src/server/Gameplay/AIPlayerBrain.lua")
brain = brain_path.read_text(encoding="utf-8")

if "local function cutPassCoursePoint" not in brain:
    brain = brain.replace(
        "local function chooseBoxCross(context: any, carrier: any): any?",
        '''local function cutPassCoursePoint(context: any, receiverInfo: any, requestedTarget: Vector3): Vector3
\tlocal velocity=flat(context.BallVelocity or Vector3.zero)
\tlocal ball=context.BallWorld
\tif velocity.Magnitude<2 then
\t\treturn requestedTarget
\tend
\tlocal direction=velocity.Unit
\tlocal toTarget=flat(requestedTarget-ball)
\tlocal remaining=toTarget.Magnitude
\tif remaining<3 then
\t\treturn requestedTarget
\tend
\tlocal cutDistance=math.clamp(remaining*.9,5,58)
\tif remaining<18 then
\t\tcutDistance=math.max(remaining*.58,3.5)
\tend
\tlocal cut=ball+direction*cutDistance
\tlocal receiverToCut=PitchConfig.GetDistanceStuds(receiverInfo.World,cut)
\tlocal receiverToTarget=PitchConfig.GetDistanceStuds(receiverInfo.World,requestedTarget)
\tif receiverToCut>receiverToTarget+26 and remaining>22 then
\t\tcut=ball+direction*math.clamp(remaining*.72,5,42)
\tend
\treturn Vector3.new(cut.X,receiverInfo.World.Y,cut.Z)
end

local function chooseBoxCross(context: any, carrier: any): any?''',
        1
    )

brain = replace_once(
    brain,
    '''\t\t\telseif typeof(receiveTarget) == "Vector3" and not info.IsUserControlled then
\t\t\t\tlocal target = predictReceivePoint(context, info, receiveTarget)
\t\t\t\tlocal assignment = assignmentsBySide[side][info.Model]
\t\t\t\tif assignment then
\t\t\t\t\tassignment.PrimaryAssignment = "ReceivePass"
\t\t\t\t\tassignment.TargetWorld = target
\t\t\t\t\tassignment.MovementTarget = target
\t\t\t\t\tassignment.MovementUrgency = 1
\t\t\t\t\tassignment.SprintAllowed = true
\t\t\t\t\tassignment.FaceWorld = context.BallWorld
\t\t\t\t\tinfo.Model:SetAttribute("VTRReceiveIntercept", target)
\t\t\t\t\tinfo.Model:SetAttribute("VTRReceiveBallSpeed", flat(context.BallVelocity or Vector3.zero).Magnitude)
\t\t\t\t\tinfo.Model:SetAttribute("VTRReceiveDistance", PitchConfig.GetDistanceStuds(info.World, target))
\t\t\t\tend
\t\t\tend''',
    '''\t\t\telseif typeof(receiveTarget) == "Vector3" and not info.IsUserControlled then
\t\t\t\tlocal passKind=tostring(info.Model:GetAttribute("AIDebugPassKind") or "")
\t\t\t\tlocal lobbed=passKind=="Lofted" or passKind=="FarPostCross" or (context.Ball and context.Ball:GetAttribute("VTRLobPassActive")==true)
\t\t\t\tlocal target = lobbed and predictReceivePoint(context, info, receiveTarget) or cutPassCoursePoint(context, info, receiveTarget)
\t\t\t\tlocal assignment = assignmentsBySide[side][info.Model]
\t\t\t\tif assignment then
\t\t\t\t\tassignment.PrimaryAssignment = lobbed and "WaitForLobbedPass" or "CutPassCourse"
\t\t\t\t\tassignment.TargetWorld = target
\t\t\t\t\tassignment.MovementTarget = target
\t\t\t\t\tassignment.MovementUrgency = lobbed and .92 or 1
\t\t\t\t\tassignment.SprintAllowed = not lobbed or PitchConfig.GetDistanceStuds(info.World,target)>10
\t\t\t\t\tassignment.FaceWorld = context.BallWorld
\t\t\t\t\tinfo.Model:SetAttribute("VTRReceiveIntercept", target)
\t\t\t\t\tinfo.Model:SetAttribute("VTRReceiveMode", lobbed and "WaitLob" or "CutCourse")
\t\t\t\t\tinfo.Model:SetAttribute("VTRReceiveBallSpeed", flat(context.BallVelocity or Vector3.zero).Magnitude)
\t\t\t\t\tinfo.Model:SetAttribute("VTRReceiveDistance", PitchConfig.GetDistanceStuds(info.World, target))
\t\t\t\tend
\t\t\tend''',
    "receiver cut course override"
)

brain_path.write_text(brain, encoding="utf-8", newline="\n")

shoot_path = Path("src/server/Gameplay/AIShootingDecisionService.lua")
shoot = shoot_path.read_text(encoding="utf-8")

new_goal = '''local function goalTarget(context: any, shooter: any): Vector3
\tlocal attackSign = context.AttackSigns and context.AttackSigns[shooter.Side] or PitchConfig.GetAttackDirection(shooter.Side, context.Options)
\tlocal rectangle = GoalModelResolver.ResolveByAttackSign(attackSign, context.PitchCFrame, context.Width, context.Length)
\tlocal goalPitch = Vector3.new(PitchConfig.HALF_WIDTH, 3, PitchConfig.PITCH_LENGTH)
\tlocal center = PitchConfig.TeamPitchPositionToWorld(goalPitch, shooter.Side, context.Options)
\tlocal distance = PitchConfig.GetDistanceStuds(shooter.World, center)
\tlocal pressure = AIContextBuilder.Pressure(context, shooter)
\tlocal leftOpen = laneOpenTo(context, shooter, 180)
\tlocal rightOpen = laneOpenTo(context, shooter, 244)
\tlocal width = math.max(1, rectangle.RightBound - rectangle.Left)
\tlocal height = math.max(1, rectangle.Top - rectangle.Bottom)
\tlocal edgeInset = math.clamp(width * (0.06 + pressure.Score * 0.018), 0.18, width * 0.13)
\tlocal leftX = rectangle.Left + edgeInset
\tlocal rightX = rectangle.RightBound - edgeInset
\tlocal sideBias = shooter.Pitch.X < PitchConfig.HALF_WIDTH and rightX or leftX
\tif leftOpen ~= rightOpen then
\t\tsideBias = leftOpen and leftX or rightX
\telseif math.floor((context.Now or os.clock()) * 10 + #shooter.Model.Name) % 2 == 0 then
\t\tsideBias = leftX
\telse
\t\tsideBias = rightX
\tend
\tlocal highEdge = rectangle.Top - height * math.clamp(0.08 + pressure.Score * 0.03, 0.08, 0.18)
\tlocal lowEdge = rectangle.Bottom + height * math.clamp(0.16 + math.clamp((90 - distance) / 160, 0, .08), 0.16, 0.24)
\tlocal vertical
\tif distance < 62 then
\t\tvertical = lowEdge
\telseif pressure.Heavy then
\t\tvertical = highEdge
\telseif math.floor((context.Now or os.clock()) * 7 + shooter.Stats.shooting) % 2 == 0 then
\t\tvertical = highEdge
\telse
\t\tvertical = lowEdge
\tend
\treturn GoalModelResolver.Point(rectangle, sideBias, vertical)
end'''

shoot = regex_once(
    shoot,
    r'local function goalTarget\(context: any, shooter: any\): Vector3.*?end\n\nlaneOpenTo',
    new_goal + "\n\nlaneOpenTo",
    "corner edge shot target"
)

shoot_path.write_text(shoot, encoding="utf-8", newline="\n")

print("updated receive course cutting, pass curve, lob curve, and corner shot targets")