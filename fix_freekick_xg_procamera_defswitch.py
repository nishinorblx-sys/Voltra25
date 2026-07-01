from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = re.sub(
r'''local function distanceGoalChance\(distance: number\): number
.*?
end''',
'''local function distanceGoalChance(distance: number): number
	local chance
	if distance <= 70 then
		chance = .95
	elseif distance <= 160 then
		chance = .95 - ((distance - 70) / 90) * 0.67
	elseif distance <= 190 then
		chance = 0.28 - ((distance - 160) / 30) * 0.265
	else
		chance = 0.01
	end
	return math.clamp(chance, 0.01, 0.95)
end''',
ball,
count=1,
flags=re.S
)

ball = replace_once(
ball,
'''			local solved=FreeKickTrajectory.Compute(origin,targetPoint,curve,lift)
			model:SetAttribute("VTRFreeKickTarget",targetPoint)
			model:SetAttribute("VTRFreeKickFlightTime",solved.FlightTime)
			model:SetAttribute("VTRFreeKickEffectiveGravity",solved.Gravity)
			model:SetAttribute("VTRFreeKickTrajectoryActive",true)
			return solved.InitialVelocity''',
'''			local solved=FreeKickTrajectory.Compute(origin,targetPoint,curve,lift)
			self.PendingFreeKickTrajectory = {
				Target = targetPoint,
				Lateral = solved.Lateral,
				Strength = solved.Strength,
				FlightTime = solved.FlightTime,
				Gravity = solved.Gravity,
			}
			model:SetAttribute("VTRFreeKickTarget",targetPoint)
			model:SetAttribute("VTRFreeKickFlightTime",solved.FlightTime)
			model:SetAttribute("VTRFreeKickEffectiveGravity",solved.Gravity)
			model:SetAttribute("VTRFreeKickTrajectoryActive",true)
			return solved.InitialVelocity''',
"store free kick trajectory"
)

ball = replace_once(
ball,
'''		self.ShotPlan=targetPoint and{Target=targetPoint,Started=os.clock(),EffectiveGravity=effectiveShotGravity,PenaltySlot=penaltySlot~=""and penaltySlot or nil,PenaltyMissHigh=model:GetAttribute("VTRPenaltyMissHigh")==true}or nil''',
'''		self.ShotPlan=targetPoint and{Target=targetPoint,Started=os.clock(),EffectiveGravity=effectiveShotGravity,PenaltySlot=penaltySlot~=""and penaltySlot or nil,PenaltyMissHigh=model:GetAttribute("VTRPenaltyMissHigh")==true}or nil
		if freeKickTrajectory and self.ShotPlan and self.PendingFreeKickTrajectory then
			self.ShotPlan.FreeKickTrajectory = self.PendingFreeKickTrajectory
			self.ShotPlan.EffectiveGravity = self.PendingFreeKickTrajectory.Gravity or effectiveShotGravity
			self.ShotPlan.Target = self.PendingFreeKickTrajectory.Target or targetPoint
		end
		self.PendingFreeKickTrajectory = nil''',
"apply free kick trajectory plan"
)

ball = replace_once(
ball,
'''		if (tonumber(model:GetAttribute("VTRFreeKickGoalChanceUntil")) or 0) >= os.clock() then
			shotChance = math.clamp(tonumber(model:GetAttribute("VTRFreeKickGoalChance")) or .3, .01, .99)
		end''',
'''		if (tonumber(model:GetAttribute("VTRFreeKickGoalChanceUntil")) or 0) >= os.clock() then
			shotChance = math.clamp(tonumber(model:GetAttribute("VTRFreeKickGoalChance")) or .3, .01, .95)
		end
		shotChance = math.clamp(shotChance, .01, .95)''',
"cap xg"
)

ball = replace_once(
ball,
'''		local goalRoll=targetPoint and (shotChance>=.999 or self.Random:NextNumber()<=shotChance) or false
		if targetPoint and not goalRoll then''',
'''		local goalRoll=targetPoint and (self.Random:NextNumber()<=shotChance) or false
		if targetPoint and not goalRoll and not freeKickTrajectory then''',
"free kick no forced miss"
)

ball = replace_once(
ball,
'''		elseif targetPoint and shotChance>=.999 then
			self.ShotPlan={Target=intendedGoal,Started=os.clock(),EffectiveGravity=tonumber(model:GetAttribute("VTRFreeKickEffectiveGravity")) or TARGETED_SHOT_GRAVITY,GuaranteedGoal=true}
		end''',
'''		elseif targetPoint and shotChance>=.95 and not freeKickTrajectory then
			self.ShotPlan={Target=intendedGoal,Started=os.clock(),EffectiveGravity=tonumber(model:GetAttribute("VTRFreeKickEffectiveGravity")) or TARGETED_SHOT_GRAVITY}
		end''',
"remove guaranteed goal"
)

ball = replace_once(
ball,
'''	if shotPlan and os.clock()-shotPlan.Started<2.5 then
		velocity+=Vector3.yAxis*math.max(0,workspace.Gravity-shotPlan.EffectiveGravity)*dt''',
'''	if shotPlan and os.clock()-shotPlan.Started<2.5 then
		velocity+=Vector3.yAxis*math.max(0,workspace.Gravity-shotPlan.EffectiveGravity)*dt
		if shotPlan.FreeKickTrajectory then
			velocity += shotPlan.FreeKickTrajectory.Lateral * shotPlan.FreeKickTrajectory.Strength * dt
		end''',
"free kick lateral acceleration"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

camera_path = Path("src/client/Gameplay/BroadcastCameraController.lua")
camera = camera_path.read_text(encoding="utf-8")

pro_function = '''function Controller:_updatePro(dt: number, root: BasePart)
	local side = tostring(self.Active and self.Active:GetAttribute("VTRTeam") or "Home")
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local attackSign = side == "Home" and (half >= 2 and 1 or -1) or (half >= 2 and -1 or 1)
	local attackDirection = self.PitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, attackSign))
	attackDirection = Vector3.new(attackDirection.X, 0, attackDirection.Z)
	attackDirection = attackDirection.Magnitude > .1 and attackDirection.Unit or Vector3.zAxis
	local right = self.PitchCFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z)
	right = right.Magnitude > .1 and right.Unit or Vector3.xAxis
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local speed = velocity.Magnitude
	local forwardSpeed = velocity:Dot(attackDirection)
	local backRun = math.clamp(-forwardSpeed, 0, 38)
	local ballOffset = Vector3.new(self.Ball.Position.X - root.Position.X, 0, self.Ball.Position.Z - root.Position.Z)
	local ballForward = ballOffset:Dot(attackDirection)
	local ballSide = ballOffset:Dot(right)
	local distance = math.clamp(76 + speed * .18 + backRun * 1.1, 74, 132)
	local height = math.clamp(32 + speed * .055 + backRun * .14, 30, 58)
	local target = root.Position + attackDirection * math.clamp(54 + math.clamp(ballForward, -8, 110) * .22, 48, 86) + right * math.clamp(ballSide * .34, -16, 16) + Vector3.new(0, 6.4, 0)
	if ballForward > 0 and ballOffset.Magnitude < 70 then
		target = target:Lerp(self.Ball.Position + Vector3.new(0, 3.4, 0), .32)
	end
	local fov = math.clamp(47 + speed * .035 + backRun * .075, 47, 55)
	local viewport = self.Camera.ViewportSize
	local aspect = viewport.Y > 0 and viewport.X / viewport.Y or 16 / 9
	local function contains(frame: CFrame, checkFov: number): boolean
		local localPoint = frame:PointToObjectSpace(self.Ball.Position + Vector3.new(0, 1.6, 0))
		if localPoint.Z >= -4 then return false end
		local depth = -localPoint.Z
		local halfV = math.tan(math.rad(checkFov) * .5) * depth
		local halfH = halfV * aspect
		return math.abs(localPoint.X) <= halfH * .78 and math.abs(localPoint.Y) <= halfV * .72
	end
	for _ = 1, 12 do
		local desired = root.Position - attackDirection * distance + right * math.clamp(ballSide * .16, -10, 10) + Vector3.new(0, height, 0)
		local frame = CFrame.lookAt(desired, target, self.PitchCFrame.UpVector)
		if contains(frame, fov) then break end
		distance = math.min(distance + 14, 228)
		height = math.min(height + 3.2, 92)
		fov = math.min(fov + 1.4, 68)
		target = target:Lerp(self.Ball.Position + Vector3.new(0, 3.5, 0), .18)
	end
	local desired = root.Position - attackDirection * distance + right * math.clamp(ballSide * .16, -10, 10) + Vector3.new(0, height, 0)
	self.ProCameraPosition = self.ProCameraPosition and self.ProCameraPosition:Lerp(desired, 1 - math.exp(-dt / .18)) or desired
	self.ProCameraTarget = self.ProCameraTarget and self.ProCameraTarget:Lerp(target, 1 - math.exp(-dt / .13)) or target
	self.Camera.CFrame = CFrame.lookAt(self.ProCameraPosition, self.ProCameraTarget, self.PitchCFrame.UpVector)
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / .18))
end'''

camera, count = re.subn(
	r'''function Controller:_updatePro\(dt: number, root: BasePart\)
.*?
end

function Controller:CycleMode''',
	pro_function + "\n\nfunction Controller:CycleMode",
	camera,
	count=1,
	flags=re.S
)

if count != 1:
	raise SystemExit("Could not replace _updatePro.")

camera_path.write_text(camera, encoding="utf-8", newline="\n")

team_path = Path("src/server/Gameplay/TeamControlService.lua")
team = team_path.read_text(encoding="utf-8")

if "function Service:_switchDefenseToPassTarget" not in team:
    team = team.replace(
'''function Service:_aimPoint(active: Model, value: any, goalTarget: boolean?): Vector3?''',
'''function Service:_switchDefenseToPassTarget(attackingSide: string, passTarget: Vector3)
	local defendingSide = attackingSide == "Home" and "Away" or "Home"
	local best: Model? = nil
	local bestDistance = math.huge
	for _, candidate in self.Teams[defendingSide] or {} do
		local candidateRoot = root(candidate)
		local humanoid = candidate:FindFirstChildOfClass("Humanoid")
		if candidateRoot and humanoid and humanoid.Health > 0 and candidate:GetAttribute("VTRSentOff") ~= true then
			local distance = (candidateRoot.Position - passTarget).Magnitude
			if distance < bestDistance then
				best = candidate
				bestDistance = distance
			end
		end
	end
	if not best then return end
	for player, active in self.Active do
		if self.PlayerSides[player] == defendingSide and active ~= best then
			self:_set(player, best, "PassDefense")
		end
	end
end

function Service:_aimPoint(active: Model, value: any, goalTarget: boolean?): Vector3?''',
1
    )

team = replace_once(
team,
'''				local kicked = self.BallService:Kick(active,"Pass",offset,tonumber(payload.Charge)or 0,target,payload.PassType=="ManualLobbed"and"Lofted"or"Manual",offset.Magnitude,aimPoint)
				if kicked and target then''',
'''				local kicked = self.BallService:Kick(active,"Pass",offset,tonumber(payload.Charge)or 0,target,payload.PassType=="ManualLobbed"and"Lofted"or"Manual",offset.Magnitude,aimPoint)
				if kicked then self:_switchDefenseToPassTarget(tostring(active:GetAttribute("VTRTeam") or self.PlayerSides[player] or "Home"), aimPoint) end
				if kicked and target then''',
"manual pass defense switch"
)

team = replace_once(
team,
'''		if receiver and receivePoint then
			local mode = autoSwitchMode(payload.AutoSwitch)''',
'''		if receiver and receivePoint then
			self:_switchDefenseToPassTarget(tostring(active:GetAttribute("VTRTeam") or self.PlayerSides[player] or "Home"), receivePoint)
			local mode = autoSwitchMode(payload.AutoSwitch)''',
"auto pass defense switch"
)

team_path.write_text(team, encoding="utf-8", newline="\n")

print("fixed exact direct free kick trajectory, capped xG to 0.95, pro camera ball containment zoom, and defensive pass switching")