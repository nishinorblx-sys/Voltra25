--!strict
local VTRGoalPassThrough = require(script.Parent:WaitForChild("GoalShotPassThroughService"))
local function vtrXGPercent(value)
	local n = tonumber(value) or 0
	if n <= 1 then
		n = n * 100
	end
	if n < 0 then
		return 0
	end
	if n > 100 then
		return 100
	end
	return n
end

local function vtrXGIsGoal(threshold, rolled)
	return vtrXGPercent(rolled) <= vtrXGPercent(threshold)
end

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
	if VTRGoalPassThrough.ShouldBypass(VTRGoalPassThrough.ResolveBall(rectangle, ballRadius) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall)) then
		VTRGoalPassThrough.Force(VTRGoalPassThrough.ResolveBall(rectangle, ballRadius) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 1.35)
		return false
	end
	local hitbox=rectangle.Hitbox
	if hitbox and hitbox.Parent then
		local size=hitbox.Size;local frame=hitbox.CFrame;local normal=rectangle.Normal
		local depth=(math.abs(frame.RightVector:Dot(normal))*size.X+math.abs(frame.UpVector:Dot(normal))*size.Y+math.abs(frame.LookVector:Dot(normal))*size.Z)*.5
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

local function clampKeeperHoldArea(service:any, keeper:Model, keeperRoot:BasePart): boolean
	local localPosition = service.PitchCFrame:PointToObjectSpace(keeperRoot.Position)
	local goalSign = localPosition.Z >= 0 and 1 or -1
	local boxDepth = 142
	local zMin = goalSign > 0 and service.Length * .5 - boxDepth or -service.Length * .5 + 4
	local zMax = goalSign > 0 and service.Length * .5 - 4 or -service.Length * .5 + boxDepth
	if zMin > zMax then zMin, zMax = zMax, zMin end
	local clamped = Vector3.new(
		math.clamp(localPosition.X, -service.Width * .29, service.Width * .29),
		math.max(localPosition.Y, SAFE_ROOT_HEIGHT),
		math.clamp(localPosition.Z, zMin, zMax)
	)
	if (clamped - localPosition).Magnitude <= .08 then
		return false
	end
	local world = service.PitchCFrame:PointToWorldSpace(clamped)
	local facing = Vector3.new(keeperRoot.CFrame.LookVector.X, 0, keeperRoot.CFrame.LookVector.Z)
	keeper:PivotTo(CFrame.lookAt(world, world + (facing.Magnitude > .05 and facing.Unit or service.PitchCFrame.LookVector), service.PitchCFrame.UpVector))
	keeperRoot = root(keeper) or keeperRoot
	keeperRoot.AssemblyLinearVelocity = Vector3.zero
	keeperRoot.AssemblyAngularVelocity = Vector3.zero
	keeperRoot.Anchored = false
	return true
end

local function secureHeldBall(ball: BasePart, keeper: Model)
	if ball:GetAttribute("VTRGoalkeeperHeld") ~= true then return end
	if ball:FindFirstChild("VTRGoalkeeperCatchWeld") then return end
	local keeperRoot = root(keeper)
	local torso = keeper:FindFirstChild("Torso") :: BasePart?
	local catchPart = torso or keeperRoot
	if not catchPart or (keeperRoot and keeperRoot.Anchored == true) then return end
	ball.Anchored = false
	ball.CFrame = CFrame.new(catchPart.Position + catchPart.CFrame.LookVector * 1.05 + Vector3.new(0, 0.18, 0))
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	local weld = Instance.new("WeldConstraint")
	weld.Name = "VTRGoalkeeperCatchWeld"
	weld.Part0 = ball
	weld.Part1 = catchPart
	weld.Parent = ball
end

function Service:_keeperSafety(defendingSide: string)
	local keeper = goalkeeper(self.Teams[defendingSide])
	local keeperRoot = keeper and root(keeper)
	if not keeper or not keeperRoot then return end
	local activeSaveKeeper = self.ActiveSave and self.ActiveSave.Keeper == keeper
	if activeSaveKeeper then return end
	if keeperRoot.Anchored then
		keeperRoot.Anchored = false
		keeperRoot.AssemblyLinearVelocity = Vector3.zero
		keeperRoot.AssemblyAngularVelocity = Vector3.zero
	end
	local attackingSide = self:_scoringSideForDefendedGoal(defendingSide)
	local rectangle = GoalModelResolver.ResolveSide(attackingSide, self.PitchCFrame, self.Width, self.Length)
	local localRoot = self.PitchCFrame:PointToObjectSpace(keeperRoot.Position)
	local userControlled = keeper:GetAttribute("controlledByUser") == true or keeper:GetAttribute("VTRUserControlled") == true
	if keeper:GetAttribute("VTRGoalkeeperHolding") == true and userControlled then
		if localRoot.Y > SAFE_ROOT_HEIGHT + 45 or keeperRoot.AssemblyLinearVelocity.Magnitude > 95 then
			keeperRoot.AssemblyLinearVelocity = Vector3.zero
			keeperRoot.AssemblyAngularVelocity = Vector3.zero
		end
		clampKeeperHoldArea(self, keeper, keeperRoot)
		keeper:SetAttribute("VTRGoalkeeperSaving", false)
		keeper:SetAttribute("VTRGoalkeeperState", "Held")
		secureHeldBall(self.Ball, keeper)
		return
	end
	local unsafeHold = keeper:GetAttribute("VTRGoalkeeperHolding") == true and (localRoot.Y > SAFE_ROOT_HEIGHT + 45 or not inGoalkeeperBox(self, rectangle, keeperRoot.Position) or keeperRoot.AssemblyLinearVelocity.Magnitude > 95)
	if unsafeHold then
		self.BallService:ReleaseGoalkeeperHold(keeper)
		keeper:SetAttribute("VTRGoalkeeperSaving", false)
		keeper:SetAttribute("VTRGoalkeeperState", "Recovered")
		keeper:SetAttribute("AIAssignment", "GoalkeeperPosition")
		keeper:SetAttribute("VTRNoAutoPassUntil", os.clock() + 1.6)
		keeperRoot.AssemblyLinearVelocity = Vector3.zero
		keeperRoot.AssemblyAngularVelocity = Vector3.zero
	elseif keeper:GetAttribute("VTRGoalkeeperHolding") == true then
		secureHeldBall(self.Ball, keeper)
	end
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
			local localRoot = self.PitchCFrame:PointToObjectSpace(keeperRoot.Position)
			if keeperRoot.Anchored then
				keeperRoot.Anchored = false
				keeperRoot.AssemblyLinearVelocity = Vector3.zero
				keeperRoot.AssemblyAngularVelocity = Vector3.zero
				keeper:SetAttribute("VTRGoalkeeperSaving",false)
				keeper:SetAttribute("VTRGoalkeeperState","Held")
			end
			if localRoot.Y > SAFE_ROOT_HEIGHT + 45 or keeperRoot.AssemblyLinearVelocity.Magnitude > 95 then
				keeperRoot.AssemblyLinearVelocity = Vector3.zero
				keeperRoot.AssemblyAngularVelocity = Vector3.zero
				clampKeeperHoldArea(self,keeper,keeperRoot)
			elseif not inGoalkeeperBox(self,rectangle,keeperRoot.Position)then
				clampKeeperHoldArea(self,keeper,keeperRoot)
			end
			secureHeldBall(self.Ball,keeper)
			if os.clock()-started>=7 then
				started = os.clock()
				keeper:SetAttribute("VTRGoalkeeperSaving",false)
				keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+999)
				keeper:SetAttribute("VTRGoalkeeperState","Held")
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

local function saveProbability(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number?,shooter:Model?):(number,number)
	if VTRGoalPassThrough.ShouldBypass(VTRGoalPassThrough.ResolveBall(keeper, rectangle, target, time, xg, shooter, number) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall)) then
		VTRGoalPassThrough.Force(VTRGoalPassThrough.ResolveBall(keeper, rectangle, target, time, xg, shooter, number) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 1.35)
		return false
	end
	local shooterRoot=root(shooter)
	local goalChance=tonumber(xg)
	if goalChance==nil then
		local distance=160
		if shooterRoot then
			local goalCenter=GoalModelResolver.Point(rectangle,(rectangle.Left+rectangle.RightBound)*.5,(rectangle.Bottom+rectangle.Top)*.5)
			distance=Vector3.new(shooterRoot.Position.X-goalCenter.X,0,shooterRoot.Position.Z-goalCenter.Z).Magnitude
		end
		goalChance=distanceGoalChance(distance)
	end
	goalChance=math.clamp(goalChance,0,1)
	local saveChance=math.clamp(1-goalChance,0,1)
	if shooter then
		shooter:SetAttribute("VTRShotXG",goalChance)
		shooter:SetAttribute("VTRShotSaveChance",saveChance)
	end
	return saveChance,goalChance
end

local function goalPercentChance(service, keeper, chance, rollOverride)
	local rolled = rollOverride
	if rolled == nil then
		if service and service.Random and typeof(service.Random.NextNumber) == "function" then
			rolled = service.Random:NextNumber(0, 100)
		else
			rolled = math.random() * 100
		end
	end
	return vtrXGIsGoal(chance, rolled)
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
		LineFacing = {},
		GoalChanceBank = {},
		Random = Random.new(),
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
	local chance,goalChance=saveProbability(keeper,rectangle,target,time,self.BallService.LastGoalChance or self.BallService.LastShotChance,self.BallService.LastShooter)
	keeper:SetAttribute("VTRLastSaveChance",math.floor((chance or 0)*100+.5))
	local willSave=false
	if rolled ~= nil and goalChance ~= nil then
		willSave = not vtrXGIsGoal(goalChance, rolled)
		if willSave == false then
			VTRGoalPassThrough.Force(ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 2.75)
		end
	end
	local shotPlan=self.BallService and self.BallService.ShotPlan
	local penaltySlot=shotPlan and shotPlan.PenaltySlot
	local keeperGuess=keeper:GetAttribute("VTRPenaltyGuessSlot")
	local penaltyDuel=type(penaltySlot)=="string"and penaltySlot~=""and type(keeperGuess)=="string"and keeperGuess~=""
	if penaltyDuel then
		willSave=keeperGuess==penaltySlot
		if rolled ~= nil and goalChance ~= nil then
			willSave = not vtrXGIsGoal(goalChance, rolled)
			if willSave == false then
				VTRGoalPassThrough.Force(ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 2.75)
			end
		end
		keeper:SetAttribute("VTRLastSaveChance",willSave and 100 or 0)
	elseif shotPlan and shotPlan.GuaranteedGoal==true then
		willSave=false
		if rolled ~= nil and goalChance ~= nil then
			willSave = not vtrXGIsGoal(goalChance, rolled)
			if willSave == false then
				VTRGoalPassThrough.Force(ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 2.75)
			end
		end
		keeper:SetAttribute("VTRLastSaveChance",0)
	elseif shotPlan and shotPlan.ForcedMiss==true then
		willSave=true
		if rolled ~= nil and goalChance ~= nil then
			willSave = not vtrXGIsGoal(goalChance, rolled)
			if willSave == false then
				VTRGoalPassThrough.Force(ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 2.75)
			end
		end
		keeper:SetAttribute("VTRLastSaveChance",100)
	else
		willSave=not goalPercentChance(self,keeper,goalChance)
		if willSave == false then
			VTRGoalPassThrough.Force(ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 2.75)
		end
		if rolled ~= nil and goalChance ~= nil then
			willSave = not vtrXGIsGoal(goalChance, rolled)
			if willSave == false then
				VTRGoalPassThrough.Force(ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 2.75)
			end
		end
	end
	keeper:SetAttribute("VTRGoalkeeperSaving", true)
	keeper:SetAttribute("VTRSaveTarget", target)
	keeper:SetAttribute("VTRGoalkeeperState", "Tracking")
	keeper:SetAttribute("VTRShotWillScore", not willSave)
	keeper:SetAttribute("VTRShotOutcomeSource", shotPlan and shotPlan.GuaranteedGoal == true and "XGScore" or shotPlan and shotPlan.ForcedMiss == true and "XGSave" or "XGRoll")
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
		PenaltyDiveTarget = nil,
		WillSave = willSave,
		DivePlayed = false,
		StartY = keeperRoot and keeperRoot.Position.Y or self.PitchCFrame.Position.Y + 3,
		Launched = false,
		EffectiveGravity=(self.BallService.ShotPlan and tonumber(self.BallService.ShotPlan.EffectiveGravity))or workspace.Gravity,
	}
	if penaltyDuel then
		local guessPoint=keeper:GetAttribute("VTRPenaltyGuessPoint")
		if typeof(guessPoint)=="Vector3"then self.ActiveSave.PenaltyDiveTarget=guessPoint end
	end
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
	keeper:SetAttribute("VTRShotWillScore",nil)
	keeper:SetAttribute("VTRShotOutcomeSource",nil)
	keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.2)
	self.Ball:SetAttribute("VTRGoalkeeperTracking",nil)
	self.Animations:StopAction(keeper,.12)
	self.Remote:FireAllClients({Type="GoalkeeperMiss",Model=keeper,Name=keeper:GetAttribute("DisplayName")})
	self.ActiveSave=nil
end

function Service:_finish(save: any)
	if save and save.WillSave==false then
		self:_miss(save)
		return
	end
	local keeper: Model = save.Keeper
	local keeperRoot = root(keeper)
	if not keeperRoot then self.ActiveSave = nil return end
	local localRoot=self.PitchCFrame:PointToObjectSpace(keeperRoot.Position);if localRoot.Y<SAFE_ROOT_HEIGHT then keeperRoot.CFrame=keeperRoot.CFrame+self.PitchCFrame.UpVector*(SAFE_ROOT_HEIGHT-localRoot.Y)end
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
	keeper:SetAttribute("VTRShotWillScore",nil)
	keeper:SetAttribute("VTRShotOutcomeSource",nil)
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
		secureHeldBall(self.Ball, keeper)
		self.Animations:StopAction(keeper,.1)
		if humanoid then humanoid.PlatformStand=false;humanoid.AutoRotate=true;humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)end
		if save.DiveAlign then save.DiveAlign:Destroy()end
		if save.DiveVelocity then save.DiveVelocity:Destroy()end
		if save.DiveAttachment then save.DiveAttachment:Destroy()end
		local facing=self.LineFacing[keeper];if facing then facing.Align.Enabled=true end
		currentRoot=root(keeper)
		if currentRoot then
			currentRoot.AssemblyLinearVelocity=Vector3.zero
			currentRoot.AssemblyAngularVelocity=Vector3.zero
		end
		if userControlled then
			keeper:SetAttribute("VTRGoalkeeperSaving",false)
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
		keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.4)
		keeper:SetAttribute("AIAssignment","GoalkeeperPosition")
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
	local keeper=goalkeeper(self.Teams[defendingSide]);if not keeper or keeper:GetAttribute("VTRGoalkeeperSaving")==true or keeper:GetAttribute("controlledByUser")==true or self.BallService.Possession:GetOwner()==keeper then return end
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

function Service:_rushCloseCarrier(defendingSide:string): boolean
	local keeper=goalkeeper(self.Teams[defendingSide])
	local keeperRoot=keeper and root(keeper)
	if not keeper or not keeperRoot or keeper:GetAttribute("VTRGoalkeeperSaving")==true or self.BallService.Possession:GetOwner()==keeper then return false end
	local carrier=self.BallService.Possession:GetOwner()
	local carrierRoot=carrier and root(carrier)
	if not carrier or not carrierRoot or carrier:GetAttribute("VTRTeam")==defendingSide then return false end
	local attackingSide=self:_scoringSideForDefendedGoal(defendingSide)
	local rectangle=GoalModelResolver.ResolveSide(attackingSide,self.PitchCFrame,self.Width,self.Length)
	local goalCenter=GoalModelResolver.Point(rectangle,(rectangle.Left+rectangle.RightBound)*.5,rectangle.Bottom+2.6)
	local carrierGoalDistance=Vector3.new(carrierRoot.Position.X-goalCenter.X,0,carrierRoot.Position.Z-goalCenter.Z).Magnitude
	if carrierGoalDistance>50 then return false end
	local keeperDistance=(keeperRoot.Position-carrierRoot.Position).Magnitude
	if keeperDistance<=8.5 or (keeperDistance<=11 and (self.Ball.Position-keeperRoot.Position).Magnitude<=9.5) then
		self.BallService:GoalkeeperClaim(keeper)
		keeper:SetAttribute("VTRGoalkeeperState","Smothered")
		keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.6)
		return true
	end
	local humanoid=keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self:_faceBall(keeper,rectangle)
		humanoid.AutoRotate=false
		humanoid.WalkSpeed=math.max(humanoid.WalkSpeed,18)
		humanoid:MoveTo(Vector3.new(carrierRoot.Position.X,keeperRoot.Position.Y,carrierRoot.Position.Z))
		keeper:SetAttribute("VTRGoalkeeperState","Rushing")
		return true
	end
	return false
end

function Service:_interceptGoalBoundPass(defendingSide:string): boolean
	if VTRGoalPassThrough.ShouldBypass(VTRGoalPassThrough.ResolveBall(self, defendingSide) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall)) then
		VTRGoalPassThrough.Force(VTRGoalPassThrough.ResolveBall(self, defendingSide) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 1.35)
		return false
	end
	if self.BallService.MotionKind~="Pass" then return false end
	local keeper=goalkeeper(self.Teams[defendingSide])
	local keeperRoot=keeper and root(keeper)
	if not keeper or not keeperRoot or keeper:GetAttribute("VTRGoalkeeperSaving")==true or self.BallService.Possession:GetOwner()==keeper then return false end
	local attackingSide=self:_scoringSideForDefendedGoal(defendingSide)
	local rectangle=GoalModelResolver.ResolveSide(attackingSide,self.PitchCFrame,self.Width,self.Length)
	local forward=fieldDirection(rectangle,self.PitchCFrame)
	local velocity=self.Ball.AssemblyLinearVelocity
	local towardSpeed=velocity:Dot(forward)
	if towardSpeed>=-1 then return false end
	local linePoint=rectangle.PlanePoint+forward*saveLineOffset(rectangle,self.Ball.Size.X*.5)
	local time=(linePoint-self.Ball.Position):Dot(forward)/towardSpeed
	if time<=0 or time>2.6 then return false end
	local projected=self.Ball.Position+velocity*time
	local goalPlaneTarget=projected-forward*saveLineOffset(rectangle,self.Ball.Size.X*.5)
	local offset=goalPlaneTarget-rectangle.PlanePoint
	local horizontal=offset:Dot(rectangle.Right)
	local vertical=offset:Dot(rectangle.Up)
	local danger=horizontal>=rectangle.Left-9 and horizontal<=rectangle.RightBound+9 and vertical>=rectangle.Bottom-.5 and vertical<=rectangle.Top+4
	local passTarget=self.Ball:GetAttribute("VTRPassTarget")
	if not danger and typeof(passTarget)=="Vector3"then
		local targetOffset=(passTarget::Vector3)-rectangle.PlanePoint
		local targetDepth=targetOffset:Dot(forward)
		local targetHorizontal=targetOffset:Dot(rectangle.Right)
		danger=targetDepth<=38 and targetHorizontal>=rectangle.Left-13 and targetHorizontal<=rectangle.RightBound+13
	end
	if not danger then return false end
	local claimDistance=math.min((keeperRoot.Position-self.Ball.Position).Magnitude,(keeperRoot.Position-projected).Magnitude)
	if claimDistance<=9.5 or time<=.18 then
		self.BallService:GoalkeeperClaim(keeper)
		keeper:SetAttribute("VTRGoalkeeperState","CollectedPass")
		keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.4)
		return true
	end
	local humanoid=keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local target=Vector3.new(projected.X,keeperRoot.Position.Y,projected.Z)
		self:_faceBall(keeper,rectangle)
		humanoid.AutoRotate=false
		humanoid.WalkSpeed=math.max(humanoid.WalkSpeed,17)
		humanoid:MoveTo(target)
		keeper:SetAttribute("VTRGoalkeeperState","CuttingPass")
		return true
	end
	return false
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
	if VTRGoalPassThrough.ShouldBypass(VTRGoalPassThrough.ResolveBall(position, lookVector, upAxis, fallbackForward) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall)) then
		VTRGoalPassThrough.Force(VTRGoalPassThrough.ResolveBall(position, lookVector, upAxis, fallbackForward) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 1.35)
		return false
	end
	local forward=fallbackForward.Magnitude>.05 and fallbackForward.Unit or Vector3.zAxis
	local aim=lookVector.Magnitude>.05 and lookVector.Unit or forward
	local lateral=aim-forward*aim:Dot(forward)-upAxis*aim:Dot(upAxis)
	if lateral.Magnitude<.05 then
		lateral=upAxis:Cross(forward)
	end
	if lateral.Magnitude<.05 then
		lateral=Vector3.xAxis
	end
	local lateralDirection=lateral.Unit
	local lift=math.abs(aim:Dot(upAxis))
	local bodyUp=(lateralDirection+upAxis*math.clamp(.08+lift*.18,.08,.26)).Unit
	local bodyLook=(forward*.74+aim*.26)
	bodyLook-=bodyUp*bodyLook:Dot(bodyUp)
	if bodyLook.Magnitude<.05 then
		bodyLook=forward-bodyUp*forward:Dot(bodyUp)
	end
	if bodyLook.Magnitude<.05 then
		bodyLook=bodyUp:Cross(upAxis)
	end
	bodyLook=bodyLook.Magnitude>.05 and bodyLook.Unit or forward
	return CFrame.lookAt(position,position+bodyLook,bodyUp)
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
	if not save then
		self:_keeperSafety("Home");self:_keeperSafety("Away")
		local homeBusy=self:_rushCloseCarrier("Home") or self:_interceptGoalBoundPass("Home")
		local awayBusy=self:_rushCloseCarrier("Away") or self:_interceptGoalBoundPass("Away")
		if not homeBusy then self:_positionOnLine("Home")end
		if not awayBusy then self:_positionOnLine("Away")end
		return
	end
	if self.BallService.MotionKind ~= "Shot" or self.BallService.MotionStarted ~= save.ShotId then
		save.Keeper:SetAttribute("VTRGoalkeeperSaving", false)
		save.Keeper:SetAttribute("VTRSaveTarget", nil)
		save.Keeper:SetAttribute("VTRGoalkeeperState", "Idle")
		save.Keeper:SetAttribute("VTRShotWillScore", nil)
		save.Keeper:SetAttribute("VTRShotOutcomeSource", nil)
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
				self:_finish(save)
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
		save.Keeper:SetAttribute("VTRForceIdle",nil)
		if self.Animations then
			self.Animations:StopAction(save.Keeper,.02)
			self.Animations:PlayActionTimed(save.Keeper,"GoalkeeperDive",math.max(.34,flightTime+.14))
		end
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
		save.Keeper:SetAttribute("VTRSidewaysDive",true)
		save.Keeper:SetAttribute("VTRDiveBodyAngle",math.floor(math.deg(math.acos(math.clamp(desiredFrame.UpVector:Dot(upAxis),-1,1)))+.5))
		save.Keeper:PivotTo(desiredFrame)
		self.Animations:SyncActionToArrival(save.Keeper,"GoalkeeperDive",time)
	end
	if save.Launched and save.WillSave==false and ((save.Progress or 0)>=.985 or time<=EMERGENCY_SAVE_TIME) then
		self:_miss(save)
		return
	end
	local ballDistance=(self.Ball.Position-keeperRoot.Position).Magnitude
	local endpointDistance=(keeperRoot.Position-rootTarget).Magnitude
	if save.WillSave~=false and save.Launched and (ballDistance<=CATCH_RADIUS or endpointDistance<=3.5 or (save.Progress or 0)>=.985 or time<=EMERGENCY_SAVE_TIME) then
		self:_finish(save)
	end
end

function Service:Reset()
	if self.ActiveSave and self.ActiveSave.Keeper.Parent then
		self.ActiveSave.Keeper:SetAttribute("VTRGoalkeeperSaving", false)
		self.ActiveSave.Keeper:SetAttribute("VTRSaveTarget", nil)
		self.ActiveSave.Keeper:SetAttribute("VTRGoalkeeperState", "Idle")
		self.ActiveSave.Keeper:SetAttribute("VTRShotWillScore", nil)
		self.ActiveSave.Keeper:SetAttribute("VTRShotOutcomeSource", nil)
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
