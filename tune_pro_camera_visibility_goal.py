from pathlib import Path
import re

path = Path("src/client/Gameplay/BroadcastCameraController.lua")
text = path.read_text(encoding="utf-8")

new_function = '''function Controller:_updatePro(dt: number, root: BasePart)
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
	local backRun = math.clamp(-forwardSpeed, 0, 40)

	local ballOffset = Vector3.new(self.Ball.Position.X - root.Position.X, 0, self.Ball.Position.Z - root.Position.Z)
	local ballForward = ballOffset:Dot(attackDirection)
	local ballSide = ballOffset:Dot(right)

	local goalCenter = self.PitchCFrame:PointToWorldSpace(Vector3.new(0, 4.8, attackSign * self.Length * .5))
	local goalDistance = Vector3.new(goalCenter.X - root.Position.X, 0, goalCenter.Z - root.Position.Z).Magnitude
	local goalBlend = math.clamp((170 - goalDistance) / 170, 0, 1)

	local behindPoint: Vector3? = nil
	local behindScore = math.huge
	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and model ~= self.Active then
			local modelRoot = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if modelRoot and modelRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local offset = Vector3.new(modelRoot.Position.X - root.Position.X, 0, modelRoot.Position.Z - root.Position.Z)
				local behind = -offset:Dot(attackDirection)
				local sideAmount = math.abs(offset:Dot(right))
				if behind > 4 and behind < 82 and sideAmount < 48 then
					local score = behind + sideAmount * .35
					if score < behindScore then
						behindScore = score
						behindPoint = modelRoot.Position + Vector3.new(0, 2.6, 0)
					end
				end
			end
		end
	end

	local baseDistance = 82 + speed * .18 + backRun * 1.2
	if behindPoint then
		baseDistance = math.max(baseDistance, math.clamp(behindScore + 64, 96, 150))
	end

	local distance = math.clamp(baseDistance, 80, 150)
	local height = math.clamp(34 + speed * .055 + backRun * .14 + (behindPoint and 4 or 0), 32, 64)
	local fov = math.clamp(47 + speed * .03 + backRun * .07 + (behindPoint and 2 or 0), 47, 58)

	local goalSidePull = math.clamp(-root.Position:Dot(right) * goalBlend * .05, -7, 7)
	local desiredSide = math.clamp(ballSide * .15, -10, 10) + goalSidePull
	local target = root.Position
		+ attackDirection * math.clamp(58 + math.clamp(ballForward, -8, 120) * .18, 50, 88)
		+ right * math.clamp(ballSide * .28, -14, 14)
		+ Vector3.new(0, 6.5, 0)

	if ballForward > 0 and ballOffset.Magnitude < 72 then
		target = target:Lerp(self.Ball.Position + Vector3.new(0, 3.4, 0), .26)
	end

	if goalBlend > 0 then
		target = target:Lerp(goalCenter, goalBlend * .28)
		desiredSide += goalSidePull * .8
	end

	local viewport = self.Camera.ViewportSize
	local aspect = viewport.Y > 0 and viewport.X / viewport.Y or 16 / 9

	local checkPoints = {
		self.Ball.Position + Vector3.new(0, 1.7, 0),
		root.Position + Vector3.new(0, 3.2, 0),
	}
	if behindPoint then
		table.insert(checkPoints, behindPoint)
	end

	local function contains(frame: CFrame, checkFov: number, point: Vector3): boolean
		local localPoint = frame:PointToObjectSpace(point)
		if localPoint.Z >= -4 then return false end
		local depth = -localPoint.Z
		local halfV = math.tan(math.rad(checkFov) * .5) * depth
		local halfH = halfV * aspect
		return math.abs(localPoint.X) <= halfH * .76 and math.abs(localPoint.Y) <= halfV * .72
	end

	for _ = 1, 16 do
		local desired = root.Position - attackDirection * distance + right * desiredSide + Vector3.new(0, height, 0)
		local frame = CFrame.lookAt(desired, target, self.PitchCFrame.UpVector)
		local allVisible = true
		for _, point in ipairs(checkPoints) do
			if not contains(frame, fov, point) then
				allVisible = false
				break
			end
		end
		if allVisible then break end
		distance = math.min(distance + 16, 260)
		height = math.min(height + 3.4, 104)
		fov = math.min(fov + 1.2, 70)
		target = target:Lerp(self.Ball.Position + Vector3.new(0, 3.6, 0), .12)
	end

	local desired = root.Position - attackDirection * distance + right * desiredSide + Vector3.new(0, height, 0)

	self.ProCameraPosition = self.ProCameraPosition and self.ProCameraPosition:Lerp(desired, 1 - math.exp(-dt / .26)) or desired
	self.ProCameraTarget = self.ProCameraTarget and self.ProCameraTarget:Lerp(target, 1 - math.exp(-dt / .24)) or target

	self.Camera.CFrame = CFrame.lookAt(self.ProCameraPosition, self.ProCameraTarget, self.PitchCFrame.UpVector)
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / .28))
end'''

text, count = re.subn(
	r'''function Controller:_updatePro\(dt: number, root: BasePart\)
.*?
end

function Controller:CycleMode''',
	new_function + "\n\nfunction Controller:CycleMode",
	text,
	count=1,
	flags=re.S
)

if count != 1:
	raise SystemExit("Could not find _updatePro in BroadcastCameraController.lua")

path.write_text(text, encoding="utf-8", newline="\n")

print("tuned pro camera visibility, smoother tracking, behind-player zoom, and goal approach view")