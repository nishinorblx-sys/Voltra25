from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

team_path = Path("src/server/Gameplay/TeamControlService.lua")
team = team_path.read_text(encoding="utf-8")

team = replace_once(
team,
'''	elseif kind == "Shot" and validDirection(payload.Direction) then
		local aimPoint = self:_aimPoint(active, payload.AimPosition, payload.GoalTarget == true)
		local activeRoot = root(active)''',
'''	elseif kind == "Shot" and validDirection(payload.Direction) then
		active:SetAttribute("VTRFreeKickCurve", tonumber(payload.FreeKickCurve) or 0)
		active:SetAttribute("VTRFreeKickLift", tonumber(payload.FreeKickLift) or 0)
		local aimPoint = self:_aimPoint(active, payload.AimPosition, payload.GoalTarget == true)
		local activeRoot = root(active)''',
"free kick attrs"
)

team_path.write_text(team, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = replace_once(
ball,
'''			local solved=FreeKickTrajectory.Compute(origin,targetPoint,curve,lift)
			model:SetAttribute("VTRFreeKickTarget",targetPoint)
			model:SetAttribute("VTRFreeKickFlightTime",solved.FlightTime)
			return solved.BaseVelocity''',
'''			local solved=FreeKickTrajectory.Compute(origin,targetPoint,curve,lift)
			model:SetAttribute("VTRFreeKickTarget",targetPoint)
			model:SetAttribute("VTRFreeKickFlightTime",solved.FlightTime)
			model:SetAttribute("VTRFreeKickEffectiveGravity",solved.Gravity)
			model:SetAttribute("VTRFreeKickTrajectoryActive",true)
			return solved.InitialVelocity''',
"free kick exact preview velocity"
)

ball = replace_once(
ball,
'''		self.ShotPlan=targetPoint and{Target=targetPoint,Started=os.clock(),EffectiveGravity=TARGETED_SHOT_GRAVITY,PenaltySlot=penaltySlot~=""and penaltySlot or nil,PenaltyMissHigh=model:GetAttribute("VTRPenaltyMissHigh")==true}or nil
		local horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z);local horizontalDistance=targetPoint and Vector3.new(targetPoint.X-self.Ball.Position.X,0,targetPoint.Z-self.Ball.Position.Z).Magnitude or 65;local flightTime=tonumber(model:GetAttribute("VTRFreeKickFlightTime")) or horizontalDistance/math.max(horizontalVelocity.Magnitude,1)
		velocity+=self.Curve:StartShot(model,direction,flightTime)''',
'''		local freeKickTrajectory=model:GetAttribute("VTRFreeKickTrajectoryActive")==true
		local effectiveShotGravity=tonumber(model:GetAttribute("VTRFreeKickEffectiveGravity")) or TARGETED_SHOT_GRAVITY
		self.ShotPlan=targetPoint and{Target=targetPoint,Started=os.clock(),EffectiveGravity=effectiveShotGravity,PenaltySlot=penaltySlot~=""and penaltySlot or nil,PenaltyMissHigh=model:GetAttribute("VTRPenaltyMissHigh")==true}or nil
		local horizontalVelocity=Vector3.new(velocity.X,0,velocity.Z);local horizontalDistance=targetPoint and Vector3.new(targetPoint.X-self.Ball.Position.X,0,targetPoint.Z-self.Ball.Position.Z).Magnitude or 65;local flightTime=tonumber(model:GetAttribute("VTRFreeKickFlightTime")) or horizontalDistance/math.max(horizontalVelocity.Magnitude,1)
		if not freeKickTrajectory then
			velocity+=self.Curve:StartShot(model,direction,flightTime)
		else
			self.Curve:Stop()
		end
		model:SetAttribute("VTRFreeKickTrajectoryActive",nil)
		model:SetAttribute("VTRFreeKickEffectiveGravity",nil)''',
"free kick no double curve"
)

ball = replace_once(
ball,
'''		self.LastShooter=model
		self.Stats:RecordShot(model,targetPoint~=nil,shotChance)''',
'''		local intendedGoal=targetPoint
		local goalRoll=targetPoint and (shotChance>=.999 or self.Random:NextNumber()<=shotChance) or false
		if targetPoint and not goalRoll then
			local sideSign=self.Random:NextNumber()<.5 and -1 or 1
			local highMiss=self.Random:NextNumber()<.34
			local missTarget=targetPoint + self.Ball.CFrame.RightVector * sideSign * self.Random:NextNumber(16,28) + Vector3.yAxis * (highMiss and self.Random:NextNumber(5,10) or self.Random:NextNumber(-.5,2.5))
			if model:GetAttribute("VTRSetPieceTaker")==true and tostring(model:GetAttribute("VTRSetPieceKind") or "")=="FreeKick" then
				local curve=math.clamp(tonumber(model:GetAttribute("VTRFreeKickCurve")) or 0,-2.5,2.5)
				local lift=math.clamp(tonumber(model:GetAttribute("VTRFreeKickLift")) or 0,-2.5,2.5)*0.5
				local solved=FreeKickTrajectory.Compute(self.Ball.Position,missTarget,curve,lift)
				velocity=solved.InitialVelocity
				self.ShotPlan={Target=missTarget,Started=os.clock(),EffectiveGravity=solved.Gravity,ForcedMiss=true}
			else
				local solved=ballisticVelocity(self.Ball.Position,missTarget,math.max(72,horizontalVelocity.Magnitude),TARGETED_SHOT_GRAVITY)
				if solved then velocity=solved end
				self.ShotPlan={Target=missTarget,Started=os.clock(),EffectiveGravity=TARGETED_SHOT_GRAVITY,ForcedMiss=true}
			end
			targetPoint=missTarget
		elseif targetPoint and shotChance>=.999 then
			self.ShotPlan={Target=intendedGoal,Started=os.clock(),EffectiveGravity=tonumber(model:GetAttribute("VTRFreeKickEffectiveGravity")) or TARGETED_SHOT_GRAVITY,GuaranteedGoal=true}
		end
		self.LastShooter=model
		self.Stats:RecordShot(model,targetPoint~=nil,shotChance)''',
"xg decides shot result"
)

ball = re.sub(
r'''function Service:Tackle\(model: Model,slide:boolean\?\): boolean
.*?
end

function Service:_applyLoosePhysics''',
'''function Service:Tackle(model: Model,slide:boolean?): boolean
	if not self:_allowed(model, "Tackle") then
		return false
	end
	local action=slide and"SlideTackle"or"Tackle"
	if self.Animations then self.Animations:PlayAction(model,action)end
	local owner = self.Possession:GetOwner()
	local modelRoot = self:_root(model)
	local ownerRoot = owner and self:_root(owner)
	if not owner or owner == model or not modelRoot or not ownerRoot then
		return false
	end
	local rootDistance=(modelRoot.Position-ownerRoot.Position).Magnitude
	local ballDistance=(modelRoot.Position-self.Ball.Position).Magnitude
	local ownerSpeed=Vector3.new(ownerRoot.AssemblyLinearVelocity.X,0,ownerRoot.AssemblyLinearVelocity.Z).Magnitude
	local range=(Config.Ball.TackleRange or 7)+(slide and 2.4 or 2.1)+(ownerSpeed<2 and 2.2 or 0)
	if rootDistance>range and ballDistance>range+1.8 then
		return false
	end
	local ownerFacing=flat(ownerRoot.CFrame.LookVector)
	local toTackler=flat(modelRoot.Position-ownerRoot.Position)
	local angleDot=ownerFacing:Dot(toTackler)
	local approach=angleDot>.35 and"Front"or angleDot<-.35 and"Behind"or"Side"
	local now=os.clock()
	local duringSkill=(tonumber(owner:GetAttribute("VTRDribbleMoveUntil"))or 0)>now
	local vulnerable=(tonumber(owner:GetAttribute("VTRPostSkillVulnerableUntil"))or 0)>now and not duringSkill
	local foulChance=approach=="Behind"and.8 or approach=="Side"and.4 or 0
	local forceCard=false
	local redChance:number?=nil
	if slide then
		foulChance=approach=="Behind"and 1 or approach=="Side"and.4 or.12
		if duringSkill then foulChance=1 end
		if approach=="Behind"then forceCard=true;redChance=.5 end
	end
	if vulnerable and approach~="Behind"then foulChance=0 end
	if foulChance>0 and self.Random:NextNumber()<foulChance and self.Referee then
		self.Stats:RecordTackle(model,false)
		self.Referee:CallFoul(model,owner,slide and"Slide Tackle"or"Standing Tackle",ownerRoot.Position,forceCard,redChance)
		return false
	end
	local tackleStat=math.clamp(tonumber(model:GetAttribute(slide and"SlidingTackle"or"StandingTackle"))or tonumber(model:GetAttribute("DEF"))or 55,1,99)
	local dribbling=math.clamp(tonumber(owner:GetAttribute("Dribbling"))or tonumber(owner:GetAttribute("DRI"))or 55,1,99)
	local disparity=dribbling-tackleStat
	local chance=disparity<=10 and 1 or disparity<=30 and(1-(disparity-10)/20*.5)or 0
	if ownerSpeed<2 then chance=math.max(chance,.92)end
	if ballDistance<=range*.72 then chance=math.max(chance,.96)end
	if duringSkill then chance=.1 elseif vulnerable and approach~="Behind"then chance=1 end
	if self.Random:NextNumber() > chance then
		self.Stats:RecordTackle(model,false)
		self.Possession:Block(model, 0.35)
		return false
	end
	self.Stats:RecordTackle(model,true)
	self.Stats:Event(owner,"PossessionLost")
	self:_touch(model)
	self.MotionKind = "Tackle"
	self.MotionStarted = os.clock()
	self.Possession:ForcePickup(model)
	model:SetAttribute("VTRNoAutoPassUntil",now+1)
	self.Possession:Block(owner,slide and 1.5 or 1.0)
	owner:SetAttribute("VTRStunnedUntil",now+(slide and 1.5 or 1.0))
	owner:SetAttribute("VTRCannotRecoverBallUntil",now+(slide and 1.5 or 1.0))
	local ownerHumanoid=owner:FindFirstChildOfClass("Humanoid")
	if ownerHumanoid then ownerHumanoid:Move(Vector3.zero,false)end
	self.Remote:FireAllClients({Type = slide and"SlideTackle"or"Tackle", Actor = model,Victim=owner})
	return true
end

function Service:_applyLoosePhysics''',
ball,
count=1,
flags=re.S
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

gk = replace_once(
gk,
'''	local willSave=false
	if chance<=0 then
		willSave=false
	elseif chance>=1 then
		willSave=true
	else
		willSave=self.Random:NextNumber()<=chance
	end''',
'''	local willSave=false
	local shotPlan=self.BallService and self.BallService.ShotPlan
	if shotPlan and shotPlan.GuaranteedGoal==true then
		willSave=false
	elseif shotPlan and shotPlan.ForcedMiss==true then
		willSave=true
	elseif chance<=0 then
		willSave=false
	elseif chance>=1 then
		willSave=true
	else
		willSave=self.Random:NextNumber()<=chance
	end''',
"keeper respects xg decision"
)

gk_path.write_text(gk, encoding="utf-8", newline="\n")

cutscene_path = Path("src/client/Gameplay/MatchCutsceneController.lua")
cutscene = cutscene_path.read_text(encoding="utf-8")

cutscene = replace_once(
cutscene,
'''function Controller:Play(payload: any)
	local title = TITLES[payload.Kind] or tostring(payload.Kind or "RESTART")
	self.HUD:SetPhase(title)''',
'''function Controller:Play(payload: any)
	local title = TITLES[payload.Kind] or tostring(payload.Kind or "RESTART")
	if payload.Kind ~= "FreeKick" and payload.Kind ~= "Penalty" and self.Camera and self.Camera.EndCutscene then
		self.Camera:EndCutscene()
	end
	self.HUD:SetPhase(title)''',
"end freekick camera on other set pieces"
)

cutscene_path.write_text(cutscene, encoding="utf-8", newline="\n")

print("fixed free kick trajectory, xg result control, out-of-bounds camera reset, and standing tackle range")