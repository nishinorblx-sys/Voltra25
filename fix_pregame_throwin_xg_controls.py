from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

goalkeeper = Path("src/server/Gameplay/GoalkeeperService.lua")
text = goalkeeper.read_text(encoding="utf-8")

text = re.sub(
r'''local function saveProbability\(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number\?,shooter:Model\?\):number
.*?
end''',
'''local function saveProbability(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number?,shooter:Model?):number
	local rating=keeperRating(keeper)
	local shooterStat=shooterRating(shooter)
	local shooterRoot=root(shooter)
	local goalChance=tonumber(xg)
	if goalChance==nil or goalChance<=0 then
		local distance=160
		if shooterRoot then
			local goalCenter=GoalModelResolver.Point(rectangle,(rectangle.Left+rectangle.RightBound)*.5,(rectangle.Bottom+rectangle.Top)*.5)
			distance=Vector3.new(shooterRoot.Position.X-goalCenter.X,0,shooterRoot.Position.Z-goalCenter.Z).Magnitude
		end
		if distance<=70 then
			goalChance=1
		elseif distance>=190 then
			goalChance=.01
		elseif distance>=160 then
			goalChance=.01+(190-distance)/30*.29
		else
			goalChance=.30+(160-distance)/90*.70
		end
	end
	local statBias=math.clamp((shooterStat-rating)/320,-.05,.05)
	goalChance=math.clamp(goalChance+statBias,.01,.99)
	if shooter then
		shooter:SetAttribute("VTRShotXG",goalChance)
		shooter:SetAttribute("VTRShotSaveChance",1-goalChance)
	end
	return 1-goalChance
end''',
text,
count=1,
flags=re.S
)

goalkeeper.write_text(text, encoding="utf-8", newline="\n")

formation = Path("src/server/Gameplay/FormationPositionService.lua")
text = formation.read_text(encoding="utf-8")

text = text.replace("for index = 1, math.min(4, #options) do", "for index = 1, math.min(2, #options) do")
text = text.replace("for index = 1, math.min(4, #options) do", "for index = 1, math.min(2, #options) do")
text = text.replace("local marker = markers[index + 4] or markers[index]", "local marker = markers[index + 2] or markers[index]")
text = text.replace("local marker = markers[index + 4] or markers[index]", "local marker = markers[index + 2] or markers[index]")
text = text.replace(
'''			local lane = ((index - 1) % 5 - 2) * width * 0.17
			local depth = math.clamp(z + ownSign * (28 + math.floor((index - 1) / 4) * 22), -length / 2 + 16, length / 2 - 16)''',
'''			local lane = ((index - 1) % 5 - 2) * width * 0.16
			local depth = math.clamp(z + ownSign * (46 + math.floor((index - 1) / 4) * 28), -length / 2 + 28, length / 2 - 28)'''
)

formation.write_text(text, encoding="utf-8", newline="\n")

gameplay = Path("src/client/Gameplay/GameplayController.lua")
text = gameplay.read_text(encoding="utf-8")

text = text.replace(
'''	bootCover.DisplayOrder = 980''',
'''	bootCover.DisplayOrder = 2200'''
)

text = re.sub(
r'''	task.delay\(1\.2, function\(\)
		if bootCover.Parent then bootCover:Destroy\(\) end
	end\)''',
'''	task.spawn(function()
		local started=os.clock()
		while bootCover.Parent and os.clock()-started<8 do
			if player.PlayerGui:FindFirstChild("VTRPrematchBroadcast") then
				task.wait(.18)
				break
			end
			task.wait(.05)
		end
		if bootCover.Parent then bootCover:Destroy() end
	end)''',
text,
count=1
)

text = text.replace(
'''self.Input:SetAutoSwitch(UserInputService.TouchEnabled and "Instant" or settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(UserInputService.TouchEnabled and "Assisted" or settings.ReceiverAssist or "Light");''',
'''self.Input:SetAutoSwitch(UserInputService.TouchEnabled and "Instant" or settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(UserInputService.TouchEnabled and "Assisted" or settings.ReceiverAssist or "Light");if self.Input.SetControlsSettings then self.Input:SetControlsSettings(settings)end;'''
)

text = text.replace(
'''self.Camera:Start();self.Cutscenes:StadiumIntro(data);''',
'''self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);'''
)

text = text.replace(
'''slash.BackgroundColor3=Color3.fromHex("B7FF1A");slash.BorderSizePixel=0;''',
'''slash.BackgroundColor3=Color3.new(0,0,0);slash.BackgroundTransparency=1;slash.BorderSizePixel=0;'''
)

text = re.sub(
r'''	if kind=="Shot"then
		local pitch=self.Camera and self.Camera.PitchCFrame
		local width=self.Camera and self.Camera.Width or 424
		local length=self.Camera and self.Camera.Length or 742
		if pitch then
			local goalA=pitch:PointToWorldSpace\(Vector3.new\(0,3,-length\*.5\)\)
			local goalB=pitch:PointToWorldSpace\(Vector3.new\(0,3,length\*.5\)\)
			local toA=Vector3.new\(goalA.X-root.Position.X,0,goalA.Z-root.Position.Z\)
			local toB=Vector3.new\(goalB.X-root.Position.X,0,goalB.Z-root.Position.Z\)
			local dotA=toA.Magnitude>1 and direction:Dot\(toA.Unit\)or-1
			local dotB=toB.Magnitude>1 and direction:Dot\(toB.Unit\)or-1
			local chosen=dotA>dotB and goalA or goalB
			local chosenDot=math.max\(dotA,dotB\)
			local chosenDistance=Vector3.new\(chosen.X-root.Position.X,0,chosen.Z-root.Position.Z\).Magnitude
			if chosenDistance<=172 and chosenDot>-0.08 then
				local localGoal=pitch:PointToObjectSpace\(chosen\)
				local side=direction:Dot\(pitch.RightVector\)>=0 and 1 or -1
				local high=\(\(math.floor\(os.clock\(\)\*10\)\+math.floor\(root.Position.X\)\)%2\)==0
				position=pitch:PointToWorldSpace\(Vector3.new\(side\*11,high and 6.2 or 2.45,localGoal.Z\)\)
				goalTarget=true
			else
				position=root.Position\+direction\*\(90\+amount\*80\)
				goalTarget=false
			end
		end
	end''',
'''	if kind=="Shot"then
		local pitch=self.Camera and self.Camera.PitchCFrame
		local length=self.Camera and self.Camera.Length or 742
		if pitch then
			local half=tonumber(workspace:GetAttribute("VTRMatchHalf"))or 1
			local team=tostring(self.ActiveModel and self.ActiveModel:GetAttribute("VTRTeam")or"Home")
			local attackSign=(team=="Home"and(half>=2 and 1 or-1)or(half>=2 and-1 or 1))
			local chosen=pitch:PointToWorldSpace(Vector3.new(0,3,attackSign*length*.5))
			local toGoal=Vector3.new(chosen.X-root.Position.X,0,chosen.Z-root.Position.Z)
			local chosenDot=toGoal.Magnitude>1 and direction:Dot(toGoal.Unit)or-1
			local chosenDistance=toGoal.Magnitude
			if chosenDistance<=178 and chosenDot>-0.12 then
				local side=direction:Dot(pitch.RightVector)>=0 and 1 or -1
				local high=((math.floor(os.clock()*10)+math.floor(root.Position.X))%2)==0
				position=pitch:PointToWorldSpace(Vector3.new(side*11,high and 6.2 or 2.45,attackSign*length*.5))
				goalTarget=true
			else
				position=root.Position+direction*(90+amount*80)
				goalTarget=false
			end
		end
	end''',
text,
count=1,
flags=re.S
)

text = text.replace(
'''elseif payload.Type=="Clock"then self.Stamina=tonumber(payload.Stamina)or self.Stamina;self.Endurance=tonumber(payload.Endurance)or self.Endurance;''',
'''elseif payload.Type=="Clock"then workspace:SetAttribute("VTRMatchHalf",tonumber(payload.Half)or ((tonumber(payload.GameSeconds)or 0)>=2700 and 2 or 1));self.Stamina=tonumber(payload.Stamina)or self.Stamina;self.Endurance=tonumber(payload.Endurance)or self.Endurance;'''
)

gameplay.write_text(text, encoding="utf-8", newline="\n")

goal_service = Path("src/client/Gameplay/GoalAimPlaneService.lua")
text = goal_service.read_text(encoding="utf-8")

text = re.sub(
r'''function Service:GetGoalRectangle\(active: Model\?\): any
.*?
end

function Service:ProjectRay''',
'''local function attackSignFor(active: Model?): number
	local side = active and tostring(active:GetAttribute("VTRTeam") or "Home") or "Home"
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	if side == "Home" then
		return half >= 2 and 1 or -1
	end
	return half >= 2 and -1 or 1
end

function Service:GetGoalRectangle(active: Model?): any
	local side = active and tostring(active:GetAttribute("VTRTeam") or "Home") or "Home"
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local key = side .. ":" .. tostring(half)
	if not self.Cache[key] then
		self.Cache[key] = GoalModelResolver.ResolveByAttackSign(attackSignFor(active), self.PitchCFrame, self.Width, self.Length)
	end
	return self.Cache[key]
end

function Service:ProjectRay''',
text,
count=1,
flags=re.S
)

goal_service.write_text(text, encoding="utf-8", newline="\n")

camera = Path("src/client/Gameplay/BroadcastCameraController.lua")
text = camera.read_text(encoding="utf-8")

text = replace_once(
text,
'''	local root = activeRoot(self.Active)
	local presentationCenter = presentationGroupCenter({WalkForward = true, LineupIdle = true, KickoffReady = true})
	local initial = presentationCenter or self.Ball.Position''',
'''	local root = activeRoot(self.Active)
	local presentationCenter = presentationGroupCenter({WalkForward = true, LineupIdle = true, KickoffReady = true})
	local initial = presentationCenter or self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 8, 0))''',
"stadium initial target"
)

text = replace_once(
text,
'''	self.Camera.CFrame = self:_desiredFrame(PRESETS[self.Mode], initial, 0, 0)''',
'''	self.Camera.CFrame = CFrame.lookAt(self.PitchCFrame:PointToWorldSpace(Vector3.new(self.Width*.92,240,self.Length*.38)), self.PitchCFrame:PointToWorldSpace(Vector3.new(0,8,0)), self.PitchCFrame.UpVector)''',
"instant stadium camera"
)

text = re.sub(
r'''function Controller:Aim\(kind: string\?\): Vector3
.*?
end

function Controller:BeginCutscene''',
'''function Controller:Aim(kind: string?): Vector3
	local root = activeRoot(self.Active)
	local currentMove = self.CurrentMove or Vector3.zero
	if kind == "Shot" and root then
		local side = tostring(self.Active:GetAttribute("VTRTeam") or "Home")
		local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
		local attackSign = side == "Home" and (half >= 2 and 1 or -1) or (half >= 2 and -1 or 1)
		local goal = self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 2, attackSign * self.Length / 2))
		local goalDirection = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
		goalDirection = goalDirection.Magnitude > .05 and goalDirection.Unit or self.LastMove
		if currentMove.Magnitude > 0.1 then
			return (goalDirection * 0.82 + currentMove.Unit * 0.18).Unit
		end
		return goalDirection
	end
	if currentMove.Magnitude > 0.1 then
		return currentMove.Unit
	end
	if root then
		local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if facing.Magnitude > 0.1 then
			return facing.Unit
		end
	end
	return self.LastMove.Magnitude > 0.1 and self.LastMove or CameraRelativeMovement.GetMoveDirection(self.Camera, Vector2.new(0, 1))
end

function Controller:BeginCutscene''',
text,
count=1,
flags=re.S
)

camera.write_text(text, encoding="utf-8", newline="\n")

replay = Path("src/client/Gameplay/ReplayController.lua")
text = replay.read_text(encoding="utf-8")

text = text.replace("FrameFrequency = 2,", "FrameFrequency = 12,")
text = text.replace(
'''slash.BackgroundColor3 = Theme.Colors.Electric''',
'''slash.BackgroundColor3 = Theme.Colors.Black
	slash.BackgroundTransparency = 1'''
)

text = re.sub(
r'''function Controller:_updateShotReplayCamera\(timeNow: number, shotTime: number\)
.*?
end

function Controller:_startCinematicReplay''',
'''function Controller:_updateShotReplayCamera(timeNow: number, shotTime: number)
	local viewport = self.Replay and self.Replay.ViewportFrame
	if not viewport then return end
	local camera = self.ReplayCamera or self:_makeReplayCamera(viewport)
	local shooterRoot = self:_cloneFor(rootPart(self.LastShotActor))
	local ballClone = self:_cloneFor(self.Ball)
	if not shooterRoot or not shooterRoot:IsA("BasePart") or not ballClone or not ballClone:IsA("BasePart") then return end
	local shooterPos = shooterRoot.Position
	local ballPos = ballClone.Position
	if not self.ReplayShotDirection then
		local fallbackLook = Vector3.new(shooterRoot.CFrame.LookVector.X, 0, shooterRoot.CFrame.LookVector.Z)
		local shotVector = Vector3.new(ballPos.X - shooterPos.X, 0, ballPos.Z - shooterPos.Z)
		self.ReplayShotDirection = shotVector.Magnitude > 0.08 and shotVector.Unit or (fallbackLook.Magnitude > 0.08 and fallbackLook.Unit or Vector3.zAxis)
		self.ReplayShotSide = Vector3.new(-self.ReplayShotDirection.Z, 0, self.ReplayShotDirection.X)
		if self.ReplayShotSide.Magnitude < .05 then self.ReplayShotSide = Vector3.xAxis else self.ReplayShotSide = self.ReplayShotSide.Unit end
		self.ReplayCameraPosition = nil
		self.ReplayCameraTarget = nil
		self.ReplayCameraLastTime = nil
	end
	local shotDir = self.ReplayShotDirection
	local sideDir = self.ReplayShotSide
	local up = Vector3.yAxis
	local setupStart = shotTime - 1.85
	local strikeMoment = shotTime + 0.05
	local desiredPosition: Vector3
	local desiredTarget: Vector3
	local desiredFov: number
	if timeNow <= strikeMoment then
		local alpha = math.clamp((timeNow - setupStart) / math.max(0.01, strikeMoment - setupStart), 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		desiredTarget = shooterPos:Lerp(ballPos, 0.38) + up * (5.4 + eased * 1.2)
		desiredPosition = desiredTarget - shotDir * (76 - eased * 8) + sideDir * (-12 + eased * 16) + up * (29 + eased * 2)
		desiredFov = 53 - eased * 2
	else
		local alpha = math.clamp((timeNow - shotTime) / 3.0, 0, 1)
		local eased = 1 - (1 - alpha) * (1 - alpha)
		desiredTarget = shooterPos:Lerp(ballPos, 0.50 + eased * 0.20) + up * (5.8 + eased * 1.6)
		desiredPosition = shooterPos - shotDir * (72 - eased * 8) + sideDir * 8 + up * (32 + eased * 2)
		desiredFov = 51 + eased * 2
	end
	local dt = math.clamp(timeNow - (self.ReplayCameraLastTime or timeNow), 0, 0.08)
	self.ReplayCameraLastTime = timeNow
	local blend = 1 - math.exp(-dt * 8)
	if not self.ReplayCameraPosition then
		self.ReplayCameraPosition = desiredPosition
		self.ReplayCameraTarget = desiredTarget
	else
		self.ReplayCameraPosition = self.ReplayCameraPosition:Lerp(desiredPosition, blend)
		self.ReplayCameraTarget = self.ReplayCameraTarget:Lerp(desiredTarget, blend)
	end
	camera.FieldOfView = desiredFov
	camera.CFrame = CFrame.lookAt(self.ReplayCameraPosition, self.ReplayCameraTarget)
	viewport.CurrentCamera = camera
end

function Controller:_startCinematicReplay''',
text,
count=1,
flags=re.S
)

text = replace_once(
text,
'''	replay.CustomEvents.ReplayStarted:Fire()
	local currentTime = startTime''',
'''	replay.CustomEvents.ReplayStarted:Fire()
	self.ReplayShotDirection=nil
	self.ReplayShotSide=nil
	self.ReplayCameraPosition=nil
	self.ReplayCameraTarget=nil
	self.ReplayCameraLastTime=nil
	local currentTime = startTime''',
"replay camera reset"
)

replay.write_text(text, encoding="utf-8", newline="\n")

input_path = Path("src/client/Gameplay/InputController.lua")
text = input_path.read_text(encoding="utf-8")

if "local function keyFromSetting" not in text:
    text = text.replace(
'''local Controller = {}
Controller.__index = Controller''',
'''local Controller = {}
Controller.__index = Controller

local function keyFromSetting(value:any,fallback:Enum.KeyCode):Enum.KeyCode
	if typeof(value)=="EnumItem" and value.EnumType==Enum.KeyCode then return value end
	if type(value)~="string"or value==""then return fallback end
	local map={Ctrl=Enum.KeyCode.LeftControl,Control=Enum.KeyCode.LeftControl,Alt=Enum.KeyCode.LeftAlt,Shift=Enum.KeyCode.LeftShift,MouseRight=Enum.KeyCode.Unknown}
	local mapped=map[value]
	if mapped then return mapped end
	local ok,key=pcall(function()return Enum.KeyCode[value]end)
	return ok and key or fallback
end

local function down(keys:{[Enum.KeyCode]:boolean},key:Enum.KeyCode):boolean
	return key~=Enum.KeyCode.Unknown and keys[key]==true
end'''
)

text = text.replace(
'''return setmetatable({Remote = remote, Aim = aim, Keys = {}, Charge = nil, Connections = {}, AutoSwitch = "Assisted", ReceiverAssist = "Light", FreeKickCurve = 0, FreeKickLift = 0, LastFreeKickAt = 0}, Controller)''',
'''return setmetatable({Remote = remote, Aim = aim, Keys = {}, Charge = nil, Connections = {}, AutoSwitch = "Assisted", ReceiverAssist = "Light", FreeKickCurve = 0, FreeKickLift = 0, LastFreeKickAt = 0, ManualPassKey = Enum.KeyCode.LeftControl, LobbedPassKey = Enum.KeyCode.LeftAlt, ChangePlayerKey = Enum.KeyCode.Q, TackleKey = Enum.KeyCode.E, SlideTackleKey = Enum.KeyCode.F}, Controller)'''
)

if "function Controller:SetControlsSettings" not in text:
    text = text.replace(
'''function Controller:SetReceiverAssist(mode: string?)
	self.ReceiverAssist = mode == "Off" and "Off" or mode == "Assisted" and "Assisted" or "Light"
end''',
'''function Controller:SetReceiverAssist(mode: string?)
	self.ReceiverAssist = mode == "Off" and "Off" or mode == "Assisted" and "Assisted" or "Light"
end

function Controller:SetControlsSettings(settings:any)
	settings=settings or{}
	self.ManualPassKey=keyFromSetting(settings.ManualPassKey or settings.ManualPassModifier or settings.ManualPass,Enum.KeyCode.LeftControl)
	self.LobbedPassKey=keyFromSetting(settings.LobbedPassKey or settings.LobPassKey or settings.LobbedPass,Enum.KeyCode.LeftAlt)
	self.ChangePlayerKey=keyFromSetting(settings.ChangePlayerKey or settings.SwitchPlayerKey or settings.SwitchKey,Enum.KeyCode.Q)
	self.TackleKey=keyFromSetting(settings.TackleKey,Enum.KeyCode.E)
	self.SlideTackleKey=keyFromSetting(settings.SlideTackleKey or settings.SlideKey,Enum.KeyCode.F)
end'''
)

text = text.replace(
'''		local altDown = self.Keys[Enum.KeyCode.LeftAlt] == true or self.Keys[Enum.KeyCode.RightAlt] == true
		local ctrlDown = self.Keys[Enum.KeyCode.LeftControl] == true or self.Keys[Enum.KeyCode.RightControl] == true
		local manualLobbed = altDown and ctrlDown
		local manual = ctrlDown and not manualLobbed
		local lofted = altDown and not ctrlDown''',
'''		local altDown = down(self.Keys,self.LobbedPassKey) or self.Keys[Enum.KeyCode.RightAlt] == true
		local ctrlDown = down(self.Keys,self.ManualPassKey) or self.Keys[Enum.KeyCode.RightControl] == true
		local manualLobbed = altDown and ctrlDown
		local manual = ctrlDown and not manualLobbed
		local lofted = altDown and not ctrlDown'''
)

text = text.replace(
'''		elseif key == Enum.KeyCode.E then
			self.Remote:FireServer({Type = "Tackle"})
		elseif key==Enum.KeyCode.F then
			self.Remote:FireServer({Type="SlideTackle"})
		elseif key==Enum.KeyCode.C then''',
'''		elseif key == self.TackleKey then
			self.Remote:FireServer({Type = "Tackle"})
		elseif key==self.SlideTackleKey then
			self.Remote:FireServer({Type="SlideTackle"})
		elseif key==Enum.KeyCode.C then'''
)

text = text.replace(
'''		elseif key == Enum.KeyCode.Q then
			local aim=self:_aim("Switch");self.Remote:FireServer({Type = "Switch",TargetModel=aim.TargetModel,AimPosition=aim.Position})''',
'''		elseif key == self.ChangePlayerKey then
			local aim=self:_aim("Switch");self.Remote:FireServer({Type = "Switch",TargetModel=aim.TargetModel,AimPosition=aim.Position})'''
)

text = text.replace(
'''			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then''',
'''			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl
			or key == self.ManualPassKey or key == self.LobbedPassKey then'''
)

text = text.replace(
'''			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then''',
'''			or key == Enum.KeyCode.LeftAlt or key == Enum.KeyCode.RightAlt
			or key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl
			or key == self.ManualPassKey or key == self.LobbedPassKey then''',
1
)

input_path.write_text(text, encoding="utf-8", newline="\n")

for path in Path("src/client").rglob("*.lua"):
    if path == input_path:
        continue
    source = path.read_text(encoding="utf-8", errors="ignore")
    if "PauseKey" not in source or "ManualPassKey" in source:
        continue
    updated = source
    updated = updated.replace('"PauseKey"', '"PauseKey", "ManualPassKey", "LobbedPassKey", "ChangePlayerKey", "TackleKey", "SlideTackleKey"', 1)
    updated = updated.replace("PauseKey =", 'ManualPassKey = "LeftControl", LobbedPassKey = "LeftAlt", ChangePlayerKey = "Q", TackleKey = "E", SlideTackleKey = "F", PauseKey =', 1)
    updated = updated.replace("PauseKey=", 'ManualPassKey="LeftControl",LobbedPassKey="LeftAlt",ChangePlayerKey="Q",TackleKey="E",SlideTackleKey="F",PauseKey=', 1)
    if updated != source:
        path.write_text(updated, encoding="utf-8", newline="\n")
        print("patched control settings UI/defaults", path)

print("patched pregame camera cover, compact throw-ins, corrected xG save math, removed green set-piece transition, stabilized replays, and added customizable control keybind support")