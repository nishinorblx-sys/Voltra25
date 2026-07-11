from pathlib import Path
import re

root=Path.cwd()
targets=[
	root/"src/client/Gameplay/BroadcastCameraController.lua",
	root/"src/client/Gameplay/GameplayController.lua",
	root/"src/client/Gameplay/MatchCameraController.lua",
	root/"src/client/Gameplay/CameraController.lua",
]

existing=[p for p in targets if p.exists()]
if not existing:
	existing=list((root/"src/client").rglob("*Camera*.lua"))

print("CAMERA IMPULSE REFERENCES")
for path in existing:
	text=path.read_text(encoding="utf-8",errors="ignore")
	for i,line in enumerate(text.splitlines(),1):
		low=line.lower()
		if "impulse" in low or "shake" in low or "velocity" in low or "assemblylinearvelocity" in low or "ball" in low:
			print(f"{path.relative_to(root).as_posix()}:{i}: {line.rstrip()}")

changed=[]

for path in existing:
	text=path.read_text(encoding="utf-8",errors="ignore")
	original=text

	if "VTRCameraIgnoreDribbleImpulse" not in text:
		insert=r'''
local function VTRCameraIgnoreDribbleImpulse(ball:BasePart?):boolean
	if not ball then return false end
	local dribblePulseAt=tonumber(ball:GetAttribute("VTRDribbleTouchImpulseAt") or ball:GetAttribute("VTRDribbleTouchPulseAt") or ball:GetAttribute("VTRDribbleVisualImpulseAt")) or 0
	if dribblePulseAt>0 and os.clock()-dribblePulseAt<0.7 then
		return true
	end
	local motion=tostring(ball:GetAttribute("VTRMotionKind") or "")
	if motion=="Dribble" or motion=="Carried" or motion=="Carry" then
		return true
	end
	local owner=ball:GetAttribute("OwnerModel") or ball:GetAttribute("OwnerUserId")
	if owner~=nil then
		return true
	end
	return false
end

'''
		m=re.search(r"\nlocal function\s+",text)
		if m:
			text=text[:m.start()]+"\n"+insert+text[m.start():]
		else:
			text=insert+"\n"+text

	text=re.sub(
		r"(if\s+[^\n]*(?:impulse|shake|Shake|cameraShake|CameraShake)[^\n]*then)",
		r"if VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true)) then return end\n\t\1",
		text,
		flags=re.IGNORECASE
	)

	text=re.sub(
		r"(\w+\s*:\s*(?:Shake|Impulse|AddImpulse|AddShake|CameraImpulse)\s*\()",
		r"(not VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true))) and \1",
		text
	)

	text=text.replace(
		"(not VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true))) and self.Camera:Shake(",
		"if not VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true)) then self.Camera:Shake("
	)

	text=text.replace(
		"(not VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true))) and self.Camera:AddShake(",
		"if not VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true)) then self.Camera:AddShake("
	)

	text=re.sub(
		r"(local\s+\w+\s*=\s*[^;\n]*(?:AssemblyLinearVelocity|Velocity)\.Magnitude[^\n]*)",
		r"\1\n\tif VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true)) then return end",
		text
	)

	if text!=original:
		path.write_text(text.strip()+"\n",encoding="utf-8")
		changed.append(path)

if not changed:
	raise SystemExit("No camera impulse code patched. Paste the CAMERA IMPULSE REFERENCES output.")

print("patched:")
for path in changed:
	print(path.relative_to(root).as_posix())