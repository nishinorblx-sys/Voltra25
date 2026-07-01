--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}
Service.__index = Service

local DIVE_LEAD_TIME = 0.72
local EMERGENCY_SAVE_TIME = 0.025
local CATCH_RADIUS = 3.55
local MAX_DIVE_SPEED = 58
local SAFE_ROOT_HEIGHT = 3.05

local function root(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function goalkeeper(team: {Model}): Model?
	for _, model in team do
		if model:GetAttribute("position") == "GK" then return model end
	end
	return team[1]
end

local function insideGoal(rectangle: any, point: Vector3, radius: number): boolean
	local offset = point - rectangle.PlanePoint
	local horizontal = offset:Dot(rectangle.Right)
	local vertical = offset:Dot(rectangle.Up)
	return horizontal >= rectangle.Left + radius * 0.35
		and horizontal <= rectangle.RightBound - radius * 0.35
		and vertical >= rectangle.Bottom + radius * 0.2
		and vertical <= rectangle.Top - radius * 0.35
end

local function saveLineOffset(rectangle:any,ballRadius:number):number
	local hitbox=rectangle.Hitbox
	if hitbox and hitbox.Parent then
		local size=hitbox.Size;local frame=hitbox.CFrame;local normal=rectangle.Normal
		local depth=(math.abs(frame.RightVector:Dot(normal))*size.X+math.abs(frame.UpVector:Dot(normal))*size.Y+math.abs(frame.LookVector:Dot(normal))*size.Z)*.5
		-- Rectangle plane is at the hitbox center. Stand 1.5 studs beyond its
		-- field-facing surface, independent of ball size.
		return depth+2
	end
	return 2
end

local function fieldDirection(rectangle:any,pitchCFrame:CFrame):Vector3
	local center=GoalModelResolver.Point(rectangle,(rectangle.Left+rectangle.RightBound)*.5,(rectangle.Bottom+rectangle.Top)*.5)
	local direction=pitchCFrame.Position-center
	direction-=pitchCFrame.UpVector*direction:Dot(pitchCFrame.UpVector)
	return direction.Magnitude>.1 and direction.Unit or-rectangle.Normal
end

local function keeperRating(keeper:Model):number
	local overall=tonumber(keeper:GetAttribute("overall"))or 65
	local diving=tonumber(keeper:GetAttribute("gkDiving"))or tonumber(keeper:GetAttribute("GKDIV"))or overall
	local reflexes=tonumber(keeper:GetAttribute("gkReflexes"))or tonumber(keeper:GetAttribute("GKREF"))or overall
	local handling=tonumber(keeper:GetAttribute("gkHandling"))or tonumber(keeper:GetAttribute("GKHAN"))or overall
	return math.clamp(overall*.35+diving*.25+reflexes*.3+handling*.1,1,99)
end

local function inGoalkeeperBox(service:any,rectangle:any,point:Vector3):boolean
	local forward=fieldDirection(rectangle,service.PitchCFrame)
	local offset=point-rectangle.PlanePoint
	local depth=offset:Dot(forward)
	local horizontal=offset:Dot(rectangle.Right)
	local margin=18
	return depth>=0 and depth<=36 and horizontal>=rectangle.Left-margin and horizontal<=rectangle.RightBound+margin
end

function Service:_boxClear(save:any,keeper:Model):boolean
	local rectangle=save.Rectangle
	for _,side in{"Home","Away"}do
		for _,model in self.Teams[side]or{}do
			if model~=keeper then
				local modelRoot=root(model)
				if modelRoot and inGoalkeeperBox(self,rectangle,modelRoot.Position)then
					return false
				end
			end
		end
	end
	return true
end

function Service:_monitorControlledHold(keeper:Model,rectangle:any,defendingSide:string)
	task.spawn(function()
		local started=os.clock()
		while keeper.Parent and keeper:GetAttribute("VTRGoalkeeperHolding")==true do
			local keeperRoot=root(keeper)
			if not keeperRoot then return end
			if not inGoalkeeperBox(self,rectangle,keeperRoot.Position)then
				self.BallService:ReleaseGoalkeeperHold(keeper)
				keeper:SetAttribute("VTRGoalkeeperSaving",false)
				keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+.7)
				keeper:SetAttribute("VTRGoalkeeperState","Dribbling")
				return
			end
			if os.clock()-started>=7 then
				self.BallService:ReleaseGoalkeeperHold(keeper)
				keeper:SetAttribute("VTRGoalkeeperSaving",false)
				keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+.7)
				keeper:SetAttribute("VTRGoalkeeperState","Clearing")
				local center=self.PitchCFrame.Position
				local offset=center-keeperRoot.Position
				if offset.Magnitude>1 then
					self.BallService:Kick(keeper,"Pass",offset,1,nil,"Lofted",offset.Magnitude,center)
				end
				return
			end
			task.wait(.1)
		end
	end)
end

local function distanceGoalChance(distance: number): number
	if distance <= 70 then
		return 1
	elseif distance <= 160 then
		return 1 - ((distance - 70) / 90) * 0.7
	elseif distance <= 190 then
		return 0.3 - ((distance - 160) / 30) * 0.29
	end
	return 0.01
end

local function shooterRating(shooter: Model?): number
	if not shooter then
		return 65
	end
	local overall = tonumber(shooter:GetAttribute("overall")) or tonumber(shooter:GetAttribute("OVR")) or 65
	local shooting = tonumber(shooter:GetAttribute("SHO")) or tonumber(shooter:GetAttribute("Shooting")) or overall
	local finishing = tonumber(shooter:GetAttribute("Finishing")) or shooting
	local shotPower = tonumber(shooter:GetAttribute("ShotPower")) or shooting
	return math.clamp(shooting * 0.42 + finishing * 0.42 + shotPower * 0.16, 1, 99)
end

local function saveProbability(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number?,shooter:Model?):number
	local shooterRoot = root(shooter)
	if shooter and (tonumber(shooter:GetAttribute("VTRFreeKickGoalChanceUntil")) or 0) >= os.clock() then
		local goalChance = math.clamp(tonumber(shooter:GetAttribute("VTRFreeKickGoalChance")) or .3, .01, .99)
		if shooterRoot then
			shooter:SetAttribute("VTRShotDistanceGoalChance", goalChance)
			shooter:SetAttribute("VTRShotDistancePercent", math.floor(goalChance * 100 + .5))
		end
		keeper:SetAttribute("VTRDistanceGoalChance", math.floor(goalChance * 100 + .5))
		return 1 - goalChance
	end
	local distance = 190
	if shooterRoot then
		local goalCenter = GoalModelResolver.Point(rectangle, (rectangle.Left + rectangle.RightBound) * 0.5, (rectangle.Bottom + rectangle.Top) * 0.5)
		local targetDistance = Vector3.new(shooterRoot.Position.X - target.X, 0, shooterRoot.Position.Z - target.Z).Magnitude
		local goalDistance = Vector3.new(shooterRoot.Position.X - goalCenter.X, 0, shooterRoot.Position.Z - goalCenter.Z).Magnitude
		distance = math.min(targetDistance, goalDistance)
		shooter:SetAttribute("VTRShotDistanceGoalChance", distanceGoalChance(distance))
		shooter:SetAttribute("VTRShotDistanceStuds", distance)
		shooter:SetAttribute("VTRShotDistancePercent", math.floor(distanceGoalChance(distance) * 100 + 0.5))
	end
	local goalChance = distanceGoalChance(distance)
	keeper:SetAttribute("VTRDistanceGoalChance", math.floor(goalChance * 100 + 0.5))
	keeper:SetAttribute("VTRDistanceShotStuds", distance)
	return 1 - goalChance
end

function Service.new(ball: BasePart, teams: any, pitchCFrame: CFrame, width: number, length: number, ballService: any, animations: any, remote: RemoteEvent,aiService:any?)
	local self=setmetatable({
		Ball = ball,
		Teams = teams,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		BallService = ballService,
		Animations = animations,
		Remote = remote,
		ObservedShot = 0,
		ActiveSave = nil,
		MissedShots = {},
		Random = Random.new(),
		LineFacing = {},
		AI=aiService,
		Half=1,
	}, Service)
	for _,side in{"Home","Away"}do local keeper=goalkeeper(teams[side]);if keeper then keeper:SetAttribute("VTRGoalkeeperLineManaged",true)end end
	return self
end

function Service:SetHalf(half:number?)
	local nextHalf=half or 1
	if self.Half~=nextHalf then
		self:Reset()
	end
	self.Half=nextHalf
end

function Service:_scoringSideForDefendedGoal(defendingSide:string):string
	if (self.Half or 1)>=2 then
		return defendingSide
	end
	return defendingSide=="Home"and"Away"or"Home"
end

function Service:_physicalScoringSide(attackingSide:string):string
	if (self.Half or 1)>=2 then
		return attackingSide=="Home"and"Away"or"Home"
	end
	return attackingSide
end

function Service:_prediction(attackingSide: string,gravityOverride:number?): (any?, Vector3?, number?)
	local rectangle = GoalModelResolver.ResolveSide(self:_physicalScoringSide(attackingSide), self.PitchCFrame, self.Width, self.Length)
	local position = self.Ball.Position
	local velocity = self.Ball.AssemblyLinearVelocity
	local forward=fieldDirection(rectangle,self.PitchCFrame)
	local lineOffset=saveLineOffset(rectangle,self.Ball.Size.X*.5)
	local linePoint=rectangle.PlanePoint+forward*lineOffset
	local towardSpeed=velocity:Dot(forward)
	if towardSpeed>=-.05 then return nil,nil,nil end
	local time=(linePoint-position):Dot(forward)/towardSpeed
	if time <= 0 or time > 3.5 then return nil, nil, nil end
	local shotPlan=self.BallService.ShotPlan
	local gravity=gravityOverride or(shotPlan and tonumber(shotPlan.EffectiveGravity))or workspace.Gravity
	local target=position+velocity*time-self.PitchCFrame.UpVector*(.5*gravity*time*time)
	local goalPlaneTarget=target-forward*lineOffset
	if not insideGoal(rectangle,goalPlaneTarget,self.Ball.Size.X*.5)then return nil,nil,nil end
	return rectangle,GoalModelResolver.ClampPoint(rectangle,goalPlaneTarget)+forward*lineOffset,time
end

function Service:_begin(attackingSide: string, shotId: number)
	local defendingSide = attackingSide == "Home" and "Away" or "Home"
	local keeper = goalkeeper(self.Teams[defendingSide])
	local rectangle, target, time = self:_prediction(attackingSide)
	if not keeper or not rectangle or not target or not time then return end
	local chance=saveProbability(keeper,rectangle,target,time,self.BallService.LastShotXG,self.BallService.LastShooter)
	keeper:SetAttribute("VTRLastSaveChance",math.floor(chance*100+.5))
	local willSave=self.Random:NextNumber()<=chance
	local shotPlan=self.BallService.ShotPlan
	local penaltySlot=shotPlan and shotPlan.PenaltySlot
	if penaltySlot then
		local guessedSlot=tostring(keeper:GetAttribute("VTRPenaltyGuessSlot")or"")
		willSave=guessedSlot==penaltySlot and shotPlan.PenaltyMissHigh~=true
		local guessPoint=keeper:GetAttribute("VTRPenaltyGuessPoint")
		if not willSave and typeof(guessPoint)=="Vector3"then
			target=GoalModelResolver.ClampPoint(rectangle,guessPoint)+fieldDirection(rectangle,self.PitchCFrame)*2
		end
		keeper:SetAttribute("VTRLastSaveChance",willSave and 100 or 0)
	end
	keeper:SetAttribute("VTRGoalkeeperSaving", true)
	keeper:SetAttribute("VTRSaveTarget", target)
	keeper:SetAttribute("VTRGoalkeeperState", willSave and "Tracking" or "DivingNoSave")
	self.Ball:SetAttribute("VTRGoalkeeperTracking", keeper.Name)
	local keeperRoot = root(keeper)
	local humanoid = keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.AutoRotate = false end
	self.ActiveSave = {
		ShotId = shotId,
		AttackingSide = attackingSide,
		DefendingSide = defendingSide,
		Keeper = keeper,
		Rectangle = rectangle,
		Target = target,
		PenaltyDiveTarget = penaltySlot and target or nil,
		WillSave = willSave,
		DivePlayed = false,
		StartY = keeperRoot and keeperRoot.Position.Y or self.PitchCFrame.Position.Y + 3,
		Launched = false,
		EffectiveGravity=(self.BallService.ShotPlan and tonumber(self.BallService.ShotPlan.EffectiveGravity))or workspace.Gravity,
	}
end

function Service:_miss(save:any)
	local keeper:Model=save.Keeper
	local keeperRoot=root(keeper)
	if keeperRoot then
		local localRoot=self.PitchCFrame:PointToObjectSpace(keeperRoot.Position)
		if localRoot.Y<SAFE_ROOT_HEIGHT then keeperRoot.CFrame=keeperRoot.CFrame+self.PitchCFrame.UpVector*(SAFE_ROOT_HEIGHT-localRoot.Y)end
		keeperRoot.AssemblyLinearVelocity=Vector3.zero
		keeperRoot.AssemblyAngularVelocity=Vector3.zero
		keeperRoot.Anchored=false
	end
	if save.DiveAlign then save.DiveAlign:Destroy();save.DiveAlign=nil end
	if save.DiveVelocity then save.DiveVelocity:Destroy();save.DiveVelocity=nil end
	if save.DiveAttachment then save.DiveAttachment:Destroy();save.DiveAttachment=nil end
	local humanoid=keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand=false
		humanoid.AutoRotate=true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	local facing=self.LineFacing[keeper];if facing then facing.Align.Enabled=true end
	keeper:SetAttribute("VTRGoalkeeperSaving",false)
	keeper:SetAttribute("VTRSaveTarget",nil)
	keeper:SetAttribute("VTRGoalkeeperState","Beaten")
	keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.2)
	self.Ball:SetAttribute("VTRGoalkeeperTracking",nil)
	self.Animations:StopAction(keeper,.12)
	self.Remote:FireAllClients({Type="GoalkeeperMiss",Model=keeper,Name=keeper:GetAttribute("DisplayName")})
	self.ActiveSave=nil
end

function Service:_finish(save: any)
	local keeper: Model = save.Keeper
	local keeperRoot = root(keeper)
	if not keeperRoot then self.ActiveSave = nil return end
	local localRoot=self.PitchCFrame:PointToObjectSpace(keeperRoot.Position);if localRoot.Y<SAFE_ROOT_HEIGHT then keeperRoot.CFrame=keeperRoot.CFrame+self.PitchCFrame.UpVector*(SAFE_ROOT_HEIGHT-localRoot.Y)end
	-- Keep the save deterministic through contact. Letting a PlatformStand R6 rig
	-- become physical at the peak allowed limbs and the welded ball to catapult
	-- the goalkeeper through the pitch.
	keeperRoot.Anchored=true
	if save.DiveAlign then save.DiveAlign:Destroy();save.DiveAlign=nil end
	if save.DiveVelocity then save.DiveVelocity:Destroy();save.DiveVelocity=nil end
	if save.DiveAttachment then save.DiveAttachment:Destroy();save.DiveAttachment=nil end
	keeperRoot.AssemblyLinearVelocity=Vector3.zero;keeperRoot.AssemblyAngularVelocity=Vector3.zero
	self.BallService:GoalkeeperSave(keeper, save.Target)
	self.Ball:SetAttribute("VTRPenaltyShotActive",nil)
	self.BallService.Stats:RecordSave(keeper,self.BallService.LastShotXG)
	if self.BallService.LastShooter and(self.BallService.LastShotXG or 0)>=.3 then self.BallService.Stats:Event(self.BallService.LastShooter,"BigChanceMissed")end
	local userControlled=keeper:GetAttribute("controlledByUser")==true or keeper:GetAttribute("VTRUserControlled")==true
	if self.AI and not userControlled then self.AI:BeginGoalkeeperDistribution(keeper,save.DefendingSide,5.5)end
	keeper:SetAttribute("VTRSaveTarget", nil)
	keeper:SetAttribute("VTRGoalkeeperState", "Saved")
	self.Ball:SetAttribute("VTRGoalkeeperTracking", nil)
	keeper:SetAttribute("VTRNoAutoPassUntil", os.clock() + 2.4)
	self.Remote:FireAllClients({Type = "GoalkeeperSave", Model = keeper, Name = keeper:GetAttribute("DisplayName")})
	local rectangle = save.Rectangle
	task.spawn(function()
		if not keeper.Parent then return end
		local humanoid=keeper:FindFirstChildOfClass("Humanoid")
		local fallRoot=root(keeper);if not fallRoot then return end
		local fallStart=fallRoot.CFrame
		local startLocal=self.PitchCFrame:PointToObjectSpace(fallStart.Position)
		local landingWorld=self.PitchCFrame:PointToWorldSpace(Vector3.new(startLocal.X,SAFE_ROOT_HEIGHT,startLocal.Z))
		local fallStarted=os.clock();local fallDuration=.38
		repeat
			task.wait()
			fallRoot=root(keeper);if not fallRoot then return end
			local alpha=math.clamp((os.clock()-fallStarted)/fallDuration,0,1)
			local eased=1-(1-alpha)^2
			local position=fallStart.Position:Lerp(landingWorld,eased)
			keeper:PivotTo(CFrame.new(position)*fallStart.Rotation)
		until os.clock()-fallStarted>=fallDuration
		if not keeper.Parent then return end
		local currentRoot = root(keeper)
		local forward=fieldDirection(rectangle,self.PitchCFrame)
		if currentRoot then
			keeper:PivotTo(CFrame.lookAt(landingWorld,landingWorld+forward,self.PitchCFrame.UpVector))
			currentRoot=root(keeper);if currentRoot then currentRoot.AssemblyLinearVelocity=Vector3.zero;currentRoot.AssemblyAngularVelocity=Vector3.zero;currentRoot.Anchored=false end
		end
		self.Animations:StopAction(keeper,.1)
		if humanoid then humanoid.PlatformStand=false;humanoid.AutoRotate=true;humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)end
		if save.DiveAlign then save.DiveAlign:Destroy()end
		if save.DiveVelocity then save.DiveVelocity:Destroy()end
		if save.DiveAttachment then save.DiveAttachment:Destroy()end
		local facing=self.LineFacing[keeper];if facing then facing.Align.Enabled=true end
		-- Recover to the safe line, then carry the caught ball several studs into
		-- the field before detaching it for manual distribution.
		currentRoot=root(keeper)
		if currentRoot then
			currentRoot.AssemblyLinearVelocity=Vector3.zero
			currentRoot.AssemblyAngularVelocity=Vector3.zero
		end
		if userControlled then
			keeper:SetAttribute("VTRGoalkeeperState","Held")
			keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+999)
			if currentRoot then currentRoot.AssemblyLinearVelocity=Vector3.zero;currentRoot.AssemblyAngularVelocity=Vector3.zero end
			self:_monitorControlledHold(keeper,rectangle,save.DefendingSide)
			return
		end
		local waitStarted=os.clock()
		while keeper.Parent and keeper:GetAttribute("VTRGoalkeeperHolding")==true and not self:_boxClear(save,keeper) and os.clock()-waitStarted<4.5 do
			task.wait(.12)
		end
		self.BallService:ReleaseGoalkeeperHold(keeper)
		keeper:SetAttribute("VTRGoalkeeperSaving",false)
		keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+.1)
		keeper:SetAttribute("VTRGoalkeeperState", "Distributing")
		currentRoot=root(keeper)
		local receiver:Model?=nil;local bestScore=math.huge
		if currentRoot then
			for _,teammate in self.Teams[save.DefendingSide]do
				local teammateRoot=teammate~=keeper and root(teammate)or nil
				if teammateRoot then local distance=(teammateRoot.Position-currentRoot.Position).Magnitude;local score=math.abs(distance-34);if score<bestScore then receiver=teammate;bestScore=score end end
			end
		end
		local receiverRoot=receiver and root(receiver)
		if currentRoot and receiver and receiverRoot then
			local distance=(receiverRoot.Position-currentRoot.Position).Magnitude
			self.BallService:Kick(keeper,"Pass",receiverRoot.Position-currentRoot.Position,math.clamp(distance/90,.2,.58),receiver,"Ground",distance)
		end
		keeper:SetAttribute("VTRGoalkeeperState", "Distributed")
	end)
	self.ActiveSave = nil
end

local function boundedRootTarget(rectangle:any,target:Vector3,forward:Vector3):(Vector3,number,number)
	local goalHeight=rectangle.Top-rectangle.Bottom
	local verticalPadding=math.min(3.15,goalHeight*.36)
	local widthPadding=math.min(1.35,(rectangle.RightBound-rectangle.Left)*.16)
	local rootTarget=target-rectangle.Up*1.05
	local offset=rootTarget-rectangle.PlanePoint
	local horizontal=offset:Dot(rectangle.Right)
	local vertical=offset:Dot(rectangle.Up)
	local clampedHorizontal=math.clamp(horizontal,rectangle.Left+widthPadding,rectangle.RightBound-widthPadding)
	local clampedVertical=math.clamp(vertical,rectangle.Bottom+verticalPadding,rectangle.Top-verticalPadding)
	rootTarget+=rectangle.Right*(clampedHorizontal-horizontal)+rectangle.Up*(clampedVertical-vertical)
	return rootTarget,widthPadding,verticalPadding
end

function Service:_faceBall(keeper:Model,rectangle:any)
	local keeperRoot=root(keeper);if not keeperRoot then return end
	local state=self.LineFacing[keeper]
	if not state then
		local attachment=Instance.new("Attachment");attachment.Name="VTRKeeperFacingAttachment";attachment.Parent=keeperRoot
		local align=Instance.new("AlignOrientation");align.Name="VTRKeeperFacing";align.Mode=Enum.OrientationAlignmentMode.OneAttachment;align.Attachment0=attachment;align.MaxTorque=350000;align.MaxAngularVelocity=12;align.Responsiveness=14;align.RigidityEnabled=false;align.Parent=keeperRoot
		state={Attachment=attachment,Align=align};self.LineFacing[keeper]=state
	end
	local baseForward=fieldDirection(rectangle,self.PitchCFrame)
	state.Align.CFrame=CFrame.lookAt(Vector3.zero,baseForward,rectangle.Up).Rotation
	state.Align.Enabled=true
end

function Service:_positionOnLine(defendingSide:string)
	local keeper=goalkeeper(self.Teams[defendingSide]);if not keeper or keeper:GetAttribute("VTRGoalkeeperSaving")==true or self.BallService.Possession:GetOwner()==keeper then return end
	local attackingSide=self:_scoringSideForDefendedGoal(defendingSide)
	local rectangle=GoalModelResolver.ResolveSide(attackingSide,self.PitchCFrame,self.Width,self.Length)
	local width=rectangle.RightBound-rectangle.Left
	local center=(rectangle.Left+rectangle.RightBound)*.5
	local ballOffset=self.Ball.Position-rectangle.PlanePoint
	local ballHorizontal=ballOffset:Dot(rectangle.Right)
	local horizontal=math.clamp(center+(ballHorizontal-center)*.58,rectangle.Left+width*.12,rectangle.RightBound-width*.12)
	local height=rectangle.Bottom+math.min(2.75,(rectangle.Top-rectangle.Bottom)*.42)
	local forward=fieldDirection(rectangle,self.PitchCFrame)
	local ballDepth=math.max(0,ballOffset:Dot(forward))
	local aggressiveDepth=math.clamp(ballDepth*.16,saveLineOffset(rectangle,self.Ball.Size.X*.5),24)
	local target=GoalModelResolver.Point(rectangle,horizontal,height)+forward*aggressiveDepth
	local targetOffset=target-rectangle.PlanePoint
	local targetDepth=math.clamp(targetOffset:Dot(forward),1.8,35)
	local targetHorizontal=math.clamp(targetOffset:Dot(rectangle.Right),rectangle.Left-15,rectangle.RightBound+15)
	target=GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*targetDepth
	local keeperRoot=root(keeper);local humanoid=keeper:FindFirstChildOfClass("Humanoid")
	if keeperRoot and humanoid then
		self:_faceBall(keeper,rectangle)
		humanoid.AutoRotate=false
		local flatTarget=Vector3.new(target.X,keeperRoot.Position.Y,target.Z)
		humanoid.WalkSpeed=math.max(humanoid.WalkSpeed,13)
		humanoid:MoveTo(flatTarget)
		keeper:SetAttribute("VTRGoalLineTarget",flatTarget)
	end
end

local function orientDive(save:any,rectangle:any,keeperRoot:BasePart,rootTarget:Vector3,lateralAxis:Vector3,upAxis:Vector3,forward:Vector3)
	local delta=rootTarget-keeperRoot.Position
	local lateral=delta:Dot(lateralAxis)
	local vertical=math.max(.35,delta:Dot(upAxis))
	local diveDirection=(lateralAxis*lateral+upAxis*vertical).Unit
	local back=-forward
	local right=diveDirection:Cross(back)
	if right.Magnitude<.01 then right=rectangle.Right else right=right.Unit end
	local attachment=Instance.new("Attachment");attachment.Name="VTRKeeperDiveAttachment";attachment.Parent=keeperRoot
	local align=Instance.new("AlignOrientation");align.Name="VTRKeeperDiveOrientation";align.Mode=Enum.OrientationAlignmentMode.OneAttachment;align.Attachment0=attachment;align.MaxTorque=10000000;align.MaxAngularVelocity=60;align.Responsiveness=40;align.RigidityEnabled=false;align.CFrame=CFrame.fromMatrix(Vector3.zero,right,diveDirection,back).Rotation;align.Parent=keeperRoot
	save.DiveAttachment=attachment;save.DiveAlign=align
end

local function diveCatchFrame(position:Vector3,lookVector:Vector3,upAxis:Vector3,fallbackForward:Vector3):CFrame
	local look=lookVector.Magnitude>.05 and lookVector.Unit or fallbackForward
	local right=look:Cross(upAxis)
	if right.Magnitude<.05 then
		right=Vector3.new(look.Z,0,-look.X)
	end
	right=right.Magnitude>.05 and right.Unit or Vector3.xAxis
	local up=right:Cross(look)
	up=up.Magnitude>.05 and up.Unit or upAxis
	return CFrame.fromMatrix(position,right,up,-look)
end

local function createLateralDrive(save:any,keeperRoot:BasePart,lateralAxis:Vector3,lateralSpeed:number)
	local attachment=save.DiveAttachment
	if not attachment then attachment=Instance.new("Attachment");attachment.Name="VTRKeeperDiveAttachment";attachment.Parent=keeperRoot;save.DiveAttachment=attachment end
	local drive=Instance.new("LinearVelocity");drive.Name="VTRKeeperLateralDive";drive.Attachment0=attachment;drive.RelativeTo=Enum.ActuatorRelativeTo.World;drive.VelocityConstraintMode=Enum.VelocityConstraintMode.Line;drive.LineDirection=lateralAxis;drive.LineVelocity=lateralSpeed;drive.ForceLimitsEnabled=false;drive.Parent=keeperRoot
	save.DiveVelocity=drive
end

function Service:Step(dt:number?)
	dt=math.clamp(dt or 1/60,1/240,.1)
	local shotId = self.BallService.MotionKind == "Shot" and self.BallService.MotionStarted or 0
	if shotId ~= 0 and shotId ~= self.ObservedShot then
		self.ObservedShot = shotId
	end
	if shotId ~= 0 and not self.ActiveSave then
		local attackingSide = self.BallService:GetLastTouchTeam()
		if attackingSide == "Home" or attackingSide == "Away" then self:_begin(attackingSide, shotId) end
	end
	local save = self.ActiveSave
	if not save then self:_positionOnLine("Home");self:_positionOnLine("Away");return end
	if self.BallService.MotionKind ~= "Shot" or self.BallService.MotionStarted ~= save.ShotId then
		save.Keeper:SetAttribute("VTRGoalkeeperSaving", false)
		save.Keeper:SetAttribute("VTRSaveTarget", nil)
		save.Keeper:SetAttribute("VTRGoalkeeperState", "Idle")
		if save.DiveAlign then save.DiveAlign:Destroy()end;if save.DiveVelocity then save.DiveVelocity:Destroy()end;if save.DiveAttachment then save.DiveAttachment:Destroy()end
		local cancelledFacing=self.LineFacing[save.Keeper];if cancelledFacing then cancelledFacing.Align.Enabled=true end
		local cancelledRoot=root(save.Keeper);if cancelledRoot then cancelledRoot.Anchored=false end
		local cancelledHumanoid=save.Keeper:FindFirstChildOfClass("Humanoid");if cancelledHumanoid then cancelledHumanoid.PlatformStand=false;cancelledHumanoid.AutoRotate=true end
		self.Ball:SetAttribute("VTRGoalkeeperTracking", nil)
		self.ActiveSave = nil
		return
	end
	local rectangle, target, time = self:_prediction(save.AttackingSide,save.EffectiveGravity)
	if not rectangle or not target or not time then
		if save.Launched then
			if save.WillSave ~= false then
				local keeperRoot = root(save.Keeper)
				if keeperRoot and (self.Ball.Position - keeperRoot.Position).Magnitude <= CATCH_RADIUS + 1.25 then
					self:_finish(save)
				else
					self:_miss(save)
				end
			else
				self:_miss(save)
			end
		end
		return
	end
	save.Rectangle = rectangle
	if save.PenaltyDiveTarget then
		target=save.PenaltyDiveTarget
	end
	save.Target = target
	local keeperRoot = root(save.Keeper)
	local humanoid = save.Keeper:FindFirstChildOfClass("Humanoid")
	if not keeperRoot or not humanoid then self.ActiveSave = nil return end
	local forward=fieldDirection(rectangle,self.PitchCFrame)
	local rootTarget,widthPadding,verticalPadding=boundedRootTarget(rectangle,target,forward)
	local upAxis=self.PitchCFrame.UpVector
	local desiredDepth=(target-rectangle.PlanePoint):Dot(forward)
	local currentDepth=(rootTarget-rectangle.PlanePoint):Dot(forward)
	rootTarget+=forward*(desiredDepth-currentDepth)
	local keeperDepth=(keeperRoot.Position-rectangle.PlanePoint):Dot(forward)
	local rootDepth=(rootTarget-rectangle.PlanePoint):Dot(forward)
	rootTarget+=forward*(keeperDepth-rootDepth)
	local toEndpoint=rootTarget-keeperRoot.Position
	local sideVector=toEndpoint-forward*toEndpoint:Dot(forward)-upAxis*toEndpoint:Dot(upAxis)
	local fallbackAxis=self.PitchCFrame.RightVector
	local candidateAxis=sideVector.Magnitude>.05 and sideVector.Unit or fallbackAxis
	local lateralAxis=save.LateralAxis or candidateAxis
	if save.Launched and save.RootTarget then
		local correction=1-math.exp(-(time<.12 and 80 or 20)*dt)
		save.RootTarget=save.RootTarget:Lerp(rootTarget,correction)
		rootTarget=save.RootTarget
		local endVertical=(rootTarget-rectangle.PlanePoint):Dot(upAxis)
		local control=save.StartPosition:Lerp(rootTarget,.48)
		local controlVertical=(control-rectangle.PlanePoint):Dot(upAxis)
		local startVertical=(save.StartPosition-rectangle.PlanePoint):Dot(upAxis)
		local jumpHeight=math.max(4, math.abs(endVertical-startVertical)*0.55+2.5)
		save.ApexPosition=control+upAxis*(math.max(startVertical,endVertical)+jumpHeight-controlVertical)
	end
	local travel=math.abs((rootTarget-keeperRoot.Position):Dot(lateralAxis))
	local rise=math.max(0,(rootTarget-keeperRoot.Position):Dot(upAxis))
	local requiredTime=math.clamp(math.max(travel/MAX_DIVE_SPEED,math.sqrt(2*rise/math.max(workspace.Gravity,1))),.22,1.05)
	if not save.Launched then
		-- Difficult corners get a measured pre-dive shuffle along the goal line.
		-- Depth and height stay fixed, so the keeper never backs into the net.
		local lateral=(rootTarget-keeperRoot.Position):Dot(lateralAxis)
		if math.abs(lateral)>8 and time>requiredTime+.62 then
			humanoid.WalkSpeed=1.15
			humanoid:MoveTo(keeperRoot.Position+lateralAxis*math.clamp(lateral,-.6,.6))
		end
	end
	if not save.Launched and time<=math.min(DIVE_LEAD_TIME,requiredTime+.12)then
		save.Launched=true
		save.DivePlayed=true
		save.Keeper:SetAttribute("VTRGoalkeeperState","Diving")
		humanoid:Move(Vector3.zero,false)
		humanoid.PlatformStand=true
		-- Close-range attempts use their real remaining time instead of the old
		-- 0.18 second minimum, allowing an immediate reflex dive.
		local flightTime=math.clamp(time,.09,.92)
		save.DiveStartedAt=os.clock()
		save.DiveDuration=flightTime
		save.InitialInterceptTime=math.max(time,.01)
		save.Progress=0
		save.StartPosition=keeperRoot.Position
		save.RootTarget=rootTarget
		save.DiveLook=(rootTarget-keeperRoot.Position)
		save.DiveAim=target
		save.FixedDiveDepth=(keeperRoot.Position-rectangle.PlanePoint):Dot(forward)
		save.LateralAxis=candidateAxis
		lateralAxis=candidateAxis
		local facing=self.LineFacing[save.Keeper];if facing then facing.Align.Enabled=false end
		local delta=rootTarget-keeperRoot.Position
		local lateralDistance=delta:Dot(lateralAxis)
		local startVertical=(save.StartPosition-rectangle.PlanePoint):Dot(upAxis)
		local endVertical=(rootTarget-rectangle.PlanePoint):Dot(upAxis)
		local control=save.StartPosition:Lerp(rootTarget,.48)
		local controlVertical=(control-rectangle.PlanePoint):Dot(upAxis)
		local jumpHeight=math.max(4, math.abs(endVertical-startVertical)*0.55+2.5)
		save.ApexPosition=control+upAxis*(math.max(startVertical,endVertical)+jumpHeight-controlVertical)
		keeperRoot.Anchored=true
		self.Animations:PlayActionTimed(save.Keeper,"GoalkeeperDive",math.max(.22,flightTime+.04))
		save.Keeper:SetAttribute("VTRDiveLateralDistance",lateralDistance)
		save.Keeper:SetAttribute("VTRDiveLateralSpeed",math.abs(lateralDistance)/flightTime)
		save.Keeper:SetAttribute("VTRDiveTarget",rootTarget)
		save.Keeper:SetAttribute("VTRDiveAim",target)
		save.Keeper:SetAttribute("VTRDiveLaunchTime",time)
		save.Keeper:SetAttribute("VTRDiveAxis",lateralAxis)
		save.Keeper:SetAttribute("VTRSavePredictedHeight",(target-rectangle.PlanePoint):Dot(upAxis))
	end
	if save.Launched then
		local startPosition:Vector3=save.StartPosition
		local apexPosition:Vector3=save.ApexPosition
		local endPosition:Vector3=save.RootTarget
		local arrivalProgress=math.clamp(1-time/math.max(save.InitialInterceptTime,.01),0,1)
		local elapsedProgress=math.clamp((os.clock()-(save.DiveStartedAt or os.clock()))/math.max(save.DiveDuration or .35,.05),0,1)
		local desiredProgress=math.max(arrivalProgress,elapsedProgress)
		save.Progress=math.max(save.Progress or 0,desiredProgress)
		local progress=math.clamp(save.Progress,0,1)
		local inverse=1-progress
		local position=startPosition*(inverse*inverse)+apexPosition*(2*inverse*progress)+endPosition*(progress*progress)
		local tangent=(apexPosition-startPosition)*(2*inverse)+(endPosition-apexPosition)*(2*progress)
		local diveLook=save.DiveLook or (endPosition-startPosition)
		local liveAim=target-position
		local blend=liveAim.Magnitude>.05 and diveLook:Lerp(liveAim,.35) or diveLook
		local desiredFrame=diveCatchFrame(position,blend,upAxis,forward)
		save.Keeper:PivotTo(desiredFrame)
		self.Animations:SyncActionToArrival(save.Keeper,"GoalkeeperDive",time)
	end
	if save.Launched and save.WillSave==false and ((save.Progress or 0)>=.985 or time<=EMERGENCY_SAVE_TIME) then
		self:_miss(save)
		return
	end
	local ballDistance=(self.Ball.Position-keeperRoot.Position).Magnitude
	local endpointDistance=(keeperRoot.Position-rootTarget).Magnitude
	if save.WillSave~=false and save.Launched and ballDistance<=CATCH_RADIUS and endpointDistance<=3.5 then self:_finish(save)
	elseif save.WillSave~=false and save.Launched and time<=EMERGENCY_SAVE_TIME and ballDistance<=4.5 and endpointDistance<=4.5 then self:_finish(save)end
end

function Service:Reset()
	if self.ActiveSave and self.ActiveSave.Keeper.Parent then
		self.ActiveSave.Keeper:SetAttribute("VTRGoalkeeperSaving", false)
		self.ActiveSave.Keeper:SetAttribute("VTRSaveTarget", nil)
		self.ActiveSave.Keeper:SetAttribute("VTRGoalkeeperState", "Idle")
		local resetRoot=root(self.ActiveSave.Keeper);if resetRoot then resetRoot.Anchored=false end
		if self.ActiveSave.DiveAlign then self.ActiveSave.DiveAlign:Destroy()end;if self.ActiveSave.DiveVelocity then self.ActiveSave.DiveVelocity:Destroy()end;if self.ActiveSave.DiveAttachment then self.ActiveSave.DiveAttachment:Destroy()end
		local resetFacing=self.LineFacing[self.ActiveSave.Keeper];if resetFacing then resetFacing.Align.Enabled=true end
		local resetHumanoid=self.ActiveSave.Keeper:FindFirstChildOfClass("Humanoid");if resetHumanoid then resetHumanoid.PlatformStand=false;resetHumanoid.AutoRotate=true end
	end
	for _,side in{"Home","Away"}do local keeper=goalkeeper(self.Teams[side]);if keeper then self.BallService:ReleaseGoalkeeperHold(keeper)end end
	self.Ball:SetAttribute("VTRGoalkeeperTracking", nil)
	self.ActiveSave = nil
end

return Service
