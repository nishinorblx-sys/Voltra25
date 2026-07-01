from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

goal_path = Path("src/client/Gameplay/GoalAimPlaneService.lua")
text = goal_path.read_text(encoding="utf-8")

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

goal_path.write_text(text, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
text = gameplay_path.read_text(encoding="utf-8")

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
			if chosenDistance<=172 and chosenDot>-0.08 then
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
'''elseif payload.Type=="Clock"then self.Stamina=tonumber(payload.Stamina)or self.Stamina;self.Endurance=tonumber(payload.Endurance)or self.Endurance;self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:UpdateActiveRating()''',
'''elseif payload.Type=="Clock"then workspace:SetAttribute("VTRMatchHalf",tonumber(payload.Half)or 1);self.Stamina=tonumber(payload.Stamina)or self.Stamina;self.Endurance=tonumber(payload.Endurance)or self.Endurance;self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:UpdateActiveRating()'''
)

text = text.replace(
'''slash.BackgroundColor3=Color3.fromHex("B7FF1A");slash.BorderSizePixel=0;''',
'''slash.BackgroundColor3=Color3.new(0,0,0);slash.BackgroundTransparency=1;slash.BorderSizePixel=0;'''
)

gameplay_path.write_text(text, encoding="utf-8", newline="\n")

team_path = Path("src/server/Gameplay/TeamControlService.lua")
text = team_path.read_text(encoding="utf-8")

text = replace_once(
text,
'''		local rectangle = GoalModelResolver.Resolve(active, self.PitchCFrame, self.Width, self.Length)
		local clamped=GoalModelResolver.ClampPoint(rectangle,value);local offset=clamped-rectangle.PlanePoint;local x=math.clamp(offset:Dot(rectangle.Right),rectangle.Left,rectangle.RightBound);local safeBottom=math.min(rectangle.Top,rectangle.Bottom+GameplayConfig.Ball.Radius*.95);local safeTop=math.max(safeBottom,rectangle.Top-math.min(.8,(rectangle.Top-rectangle.Bottom)*.08));local y=math.clamp(offset:Dot(rectangle.Up),safeBottom,safeTop);return GoalModelResolver.Point(rectangle,x,y)''',
'''		local homeRectangle = GoalModelResolver.ResolveSide("Home", self.PitchCFrame, self.Width, self.Length)
		local awayRectangle = GoalModelResolver.ResolveSide("Away", self.PitchCFrame, self.Width, self.Length)
		local homePoint = GoalModelResolver.ClampPoint(homeRectangle, value)
		local awayPoint = GoalModelResolver.ClampPoint(awayRectangle, value)
		local rectangle = (homePoint - value).Magnitude <= (awayPoint - value).Magnitude and homeRectangle or awayRectangle
		local clamped=GoalModelResolver.ClampPoint(rectangle,value);local offset=clamped-rectangle.PlanePoint;local x=math.clamp(offset:Dot(rectangle.Right),rectangle.Left,rectangle.RightBound);local safeBottom=math.min(rectangle.Top,rectangle.Bottom+GameplayConfig.Ball.Radius*.95);local safeTop=math.max(safeBottom,rectangle.Top-math.min(.8,(rectangle.Top-rectangle.Bottom)*.08));local y=math.clamp(offset:Dot(rectangle.Up),safeBottom,safeTop);return GoalModelResolver.Point(rectangle,x,y)''',
"server half goal clamp"
)

team_path.write_text(text, encoding="utf-8", newline="\n")

replay_path = Path("src/client/Gameplay/ReplayController.lua")
text = replay_path.read_text(encoding="utf-8")

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
		self.ReplayShotSide = Vector3.new(-self.ReplayShotDirection.Z, 0, self.ReplayShotDirection.X).Unit
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
	local alpha = 1 - math.exp(-dt * 9)
	if not self.ReplayCameraPosition then
		self.ReplayCameraPosition = desiredPosition
		self.ReplayCameraTarget = desiredTarget
	else
		self.ReplayCameraPosition = self.ReplayCameraPosition:Lerp(desiredPosition, alpha)
		self.ReplayCameraTarget = self.ReplayCameraTarget:Lerp(desiredTarget, alpha)
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
"reset replay camera smoothing"
)

text = text.replace(
'''slash.BackgroundColor3 = Theme.Colors.Electric''',
'''slash.BackgroundColor3 = Theme.Colors.Black
	slash.BackgroundTransparency = 1'''
)

replay_path.write_text(text, encoding="utf-8", newline="\n")

roulette_path = Path("src/client/Components/VoltraPackRoulette.lua")
text = roulette_path.read_text(encoding="utf-8")

text = replace_once(
text,
'''	overlay.Active = true
	overlay.Parent = gui
	TweenService:Create(overlay, TweenInfo.new(.28), {GroupTransparency = 0}):Play()
	label(overlay, "RANKED WIN REWARD", UDim2.fromScale(.18, .07), UDim2.fromScale(.64, .05), 13, Theme.Colors.Electric, 522)
	label(overlay, "VOLTRA PACK ROULETTE", UDim2.fromScale(.14, .12), UDim2.fromScale(.72, .08), 38, Theme.Colors.White, 522)''',
'''	overlay.Active = true
	overlay.Parent = gui
	local blocker = Instance.new("TextButton")
	blocker.Name = "RouletteInputBlocker"
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.ZIndex = 521
	blocker.Active = true
	blocker.AutoButtonColor = false
	pcall(function() blocker.Modal = true end)
	blocker.Parent = overlay
	TweenService:Create(overlay, TweenInfo.new(.28), {GroupTransparency = 0}):Play()
	label(overlay, "YOU WON THE GAME", UDim2.fromScale(.12, .18), UDim2.fromScale(.76, .08), 42, Theme.Colors.Electric, 522)
	label(overlay, "RANKED VICTORY REWARD LOCKED", UDim2.fromScale(.18, .27), UDim2.fromScale(.64, .05), 13, Theme.Colors.White, 522)
	task.wait(1.35)
	if not overlay.Parent then return end
	label(overlay, "RANKED WIN REWARD", UDim2.fromScale(.18, .07), UDim2.fromScale(.64, .05), 13, Theme.Colors.Electric, 522)
	label(overlay, "VOLTRA PACK ROULETTE", UDim2.fromScale(.14, .12), UDim2.fromScale(.72, .08), 38, Theme.Colors.White, 522)''',
"victory before roulette"
)

roulette_path.write_text(text, encoding="utf-8", newline="\n")

print("patched half-time goal aiming, freekick goal clamp, replay camera smoothing, green transition overlay removal, and victory-before-roulette lock")