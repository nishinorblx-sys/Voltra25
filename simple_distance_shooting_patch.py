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

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

if "local function distanceGoalChance" not in gk:
    gk = gk.replace(
        '''local function shooterRating(shooter: Model?): number''',
        '''local function distanceGoalChance(distance: number): number
\tif distance <= 70 then
\t\treturn 1
\telseif distance <= 160 then
\t\treturn 1 - ((distance - 70) / 90) * 0.7
\telseif distance <= 190 then
\t\treturn 0.3 - ((distance - 160) / 30) * 0.29
\tend
\treturn 0.01
end

local function shooterRating(shooter: Model?): number''',
        1
    )

gk = regex_once(
    gk,
    r'local function saveProbability\(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number\?,shooter:Model\?\):number.*?end\n\nfunction Service.new',
    '''local function saveProbability(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number?,shooter:Model?):number
\tlocal shooterRoot = root(shooter)
\tlocal distance = 190
\tif shooterRoot then
\t\tlocal goalCenter = GoalModelResolver.Point(rectangle, (rectangle.Left + rectangle.RightBound) * 0.5, (rectangle.Bottom + rectangle.Top) * 0.5)
\t\tlocal targetDistance = Vector3.new(shooterRoot.Position.X - target.X, 0, shooterRoot.Position.Z - target.Z).Magnitude
\t\tlocal goalDistance = Vector3.new(shooterRoot.Position.X - goalCenter.X, 0, shooterRoot.Position.Z - goalCenter.Z).Magnitude
\t\tdistance = math.min(targetDistance, goalDistance)
\t\tshooter:SetAttribute("VTRShotDistanceGoalChance", distanceGoalChance(distance))
\t\tshooter:SetAttribute("VTRShotDistanceStuds", distance)
\t\tshooter:SetAttribute("VTRShotDistancePercent", math.floor(distanceGoalChance(distance) * 100 + 0.5))
\tend
\tlocal goalChance = distanceGoalChance(distance)
\tkeeper:SetAttribute("VTRDistanceGoalChance", math.floor(goalChance * 100 + 0.5))
\tkeeper:SetAttribute("VTRDistanceShotStuds", distance)
\treturn 1 - goalChance
end

function Service.new''',
    "distance save probability"
)

gk = replace_once(
    gk,
    'keeper:SetAttribute("VTRGoalkeeperState", willSave and "Tracking" or "Desperate")',
    'keeper:SetAttribute("VTRGoalkeeperState", willSave and "Tracking" or "DivingNoSave")',
    "always dive state"
)

old_recovery = '''\t\tlocal recoveryStarted=os.clock()
\t\trepeat
\t\t\tcurrentRoot=root(keeper);if not currentRoot then break end
\t\t\tlocal desiredDepth=saveLineOffset(rectangle,self.Ball.Size.X*.5)
\t\t\tlocal depth=(currentRoot.Position-rectangle.PlanePoint):Dot(forward)
\t\t\tif depth>=desiredDepth-.15 then break end
\t\t\tif humanoid then humanoid.WalkSpeed=10;humanoid:MoveTo(currentRoot.Position+forward*math.min(desiredDepth-depth,8))end
\t\t\ttask.wait(.05)
\t\tuntil os.clock()-recoveryStarted>1.4
\t\tcurrentRoot=root(keeper)
\t\tif currentRoot and humanoid then
\t\t\tlocal carryTarget=currentRoot.Position+fieldDirection(rectangle,self.PitchCFrame)*5
\t\t\thumanoid.WalkSpeed=9
\t\t\thumanoid:MoveTo(carryTarget)
\t\t\tlocal carryStarted=os.clock()
\t\t\trepeat task.wait(.05);currentRoot=root(keeper)until not currentRoot or(currentRoot.Position-carryTarget).Magnitude<1.25 or os.clock()-carryStarted>1.15
\t\tend'''

new_recovery = '''\t\tcurrentRoot=root(keeper)
\t\tif currentRoot then
\t\t\tcurrentRoot.AssemblyLinearVelocity=Vector3.zero
\t\t\tcurrentRoot.AssemblyAngularVelocity=Vector3.zero
\t\tend'''

gk = replace_once(gk, old_recovery, new_recovery, "distribute from save spot")

gk_path.write_text(gk, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

if "local function distanceGoalChance" not in ball:
    ball = ball.replace(
        '''function Service:_shotVelocity(model: Model, direction: Vector3, charge: number, targetPoint:Vector3?): Vector3''',
        '''local function distanceGoalChance(distance: number): number
\tif distance <= 70 then
\t\treturn 1
\telseif distance <= 160 then
\t\treturn 1 - ((distance - 70) / 90) * 0.7
\telseif distance <= 190 then
\t\treturn 0.3 - ((distance - 160) / 30) * 0.29
\tend
\treturn 0.01
end

function Service:_shotVelocity(model: Model, direction: Vector3, charge: number, targetPoint:Vector3?): Vector3''',
        1
    )

ball = regex_once(
    ball,
    r'\t\tlocal shotRoot=self:_root\(model\)\n\t\tlocal xg=self\.Stats:CalculateXG\(model,shotRoot and shotRoot\.Position or self\.Ball\.Position,self:_pressure\(model\),nil\).*?\n\t\tself\.LastShotXG=xg;self\.LastShooter=model;self\.Stats:RecordShot\(model,targetPoint~=nil,xg\)',
    '''\t\tlocal shotRoot=self:_root(model)
\t\tlocal xg=self.Stats:CalculateXG(model,shotRoot and shotRoot.Position or self.Ball.Position,self:_pressure(model),nil)
\t\tlocal shotDistance = 190
\t\tif shotRoot and targetPoint then
\t\t\tshotDistance = Vector3.new(shotRoot.Position.X - targetPoint.X, 0, shotRoot.Position.Z - targetPoint.Z).Magnitude
\t\telseif shotRoot then
\t\t\tshotDistance = direction.Magnitude
\t\tend
\t\tlocal shotChance = distanceGoalChance(shotDistance)
\t\tmodel:SetAttribute("VTRLastShotScoringChance",shotChance)
\t\tmodel:SetAttribute("VTRLastShotScoringPercent",math.floor(shotChance*100+.5))
\t\tmodel:SetAttribute("VTRShotDistanceStuds",shotDistance)
\t\tself.LastShotChance=shotChance
\t\tself.LastShotChancePercent=math.floor(shotChance*100+.5)
\t\tself.LastShotXG=xg;self.LastShooter=model;self.Stats:RecordShot(model,targetPoint~=nil,xg)''',
    "distance shot chance popup"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

shoot_path = Path("src/server/Gameplay/AIShootingDecisionService.lua")
shoot = shoot_path.read_text(encoding="utf-8")

new_goal_target = '''local function goalTarget(context: any, shooter: any): Vector3
\tlocal attackSign = context.AttackSigns and context.AttackSigns[shooter.Side] or PitchConfig.GetAttackDirection(shooter.Side, context.Options)
\tlocal rectangle = GoalModelResolver.ResolveByAttackSign(attackSign, context.PitchCFrame, context.Width, context.Length)
\tlocal leftOpen = laneOpenTo(context, shooter, 180)
\tlocal rightOpen = laneOpenTo(context, shooter, 244)
\tlocal width = math.max(1, rectangle.RightBound - rectangle.Left)
\tlocal height = math.max(1, rectangle.Top - rectangle.Bottom)
\tlocal cornerInset = math.clamp(width * 0.07, 0.18, width * 0.12)
\tlocal leftX = rectangle.Left + cornerInset
\tlocal rightX = rectangle.RightBound - cornerInset
\tlocal sideBias = shooter.Pitch.X < PitchConfig.HALF_WIDTH and rightX or leftX
\tif leftOpen ~= rightOpen then
\t\tsideBias = leftOpen and leftX or rightX
\telseif math.floor((context.Now or os.clock()) * 10 + #shooter.Model.Name) % 2 == 0 then
\t\tsideBias = leftX
\telse
\t\tsideBias = rightX
\tend
\tlocal topCorner = rectangle.Top - height * 0.1
\tlocal bottomCorner = rectangle.Bottom + height * 0.18
\tlocal vertical = bottomCorner
\tif math.floor((context.Now or os.clock()) * 7 + shooter.Stats.shooting + math.floor(shooter.Pitch.X)) % 2 == 0 then
\t\tvertical = topCorner
\tend
\treturn GoalModelResolver.Point(rectangle, sideBias, vertical)
end'''

shoot = regex_once(
    shoot,
    r'local function goalTarget\(context: any, shooter: any\): Vector3.*?end\n\nlaneOpenTo',
    new_goal_target + "\n\nlaneOpenTo",
    "corner only shot targets"
)

shoot_path.write_text(shoot, encoding="utf-8", newline="\n")

print("simplified shooting to distance percentage, corner targets, and save spot distribution")