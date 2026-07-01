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
	if attackDirection.Magnitude < .1 then attackDirection = Vector3.zAxis end
	attackDirection = attackDirection.Unit
	local right = self.PitchCFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z)
	right = right.Magnitude > .1 and right.Unit or Vector3.xAxis
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local speed = velocity.Magnitude
	local forwardSpeed = velocity:Dot(attackDirection)
	local backRun = math.clamp(-forwardSpeed, 0, 28)
	local ballOffset = Vector3.new(self.Ball.Position.X - root.Position.X, 0, self.Ball.Position.Z - root.Position.Z)
	local ballForward = math.clamp(ballOffset:Dot(attackDirection), 8, 62)
	local ballSide = math.clamp(ballOffset:Dot(right), -24, 24)
	local distance = math.clamp(34 + speed * .13 + backRun * .72, 34, 56)
	local height = math.clamp(12.5 + speed * .035 + backRun * .06, 12.5, 18)
	local desired = root.Position - attackDirection * distance + right * math.clamp(ballSide * .08, -2.5, 2.5) + Vector3.new(0, height, 0)
	local target = root.Position + attackDirection * math.clamp(24 + ballForward * .24, 22, 38) + right * math.clamp(ballSide * .38, -9, 9) + Vector3.new(0, 4.7, 0)
	local alpha = 1 - math.exp(-dt / .085)
	local position = self.Camera.CFrame.Position:Lerp(desired, alpha)
	self.Camera.CFrame = CFrame.lookAt(position, target, self.PitchCFrame.UpVector)
	local fov = math.clamp(54 + speed * .035 + backRun * .06, 54, 60)
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / .14))
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

print("fixed pro camera attack-direction lock")