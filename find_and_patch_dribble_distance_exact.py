from pathlib import Path
import re

path=Path("src/server/Gameplay/BallService.lua")
text=path.read_text(encoding="utf-8",errors="ignore")
original=text

print("DRIBBLE / WELD / BALL POSITION LINES")
print("="*90)
lines=text.splitlines()
for i,line in enumerate(lines,1):
	low=line.lower()
	if any(x in low for x in ["dribble","weld","motor6d","ballsocket","alignposition","linearvelocity","assemblylinearvelocity","cframe","targetatfeet","feet"]):
		print(f"{i}: {line}")

def add_constants(src):
	if "VTR_CLOSE_DRIBBLE_DISTANCE" in src:
		return src
	anchor="local BallService={};BallService.__index=BallService"
	if anchor not in src:
		anchor="local BallService = {}; BallService.__index = BallService"
	if anchor in src:
		return src.replace(anchor,anchor+"\nlocal VTR_CLOSE_DRIBBLE_DISTANCE=0.92\nlocal VTR_DRIBBLE_TOUCH_INTERVAL=.5\nlocal VTR_DRIBBLE_TOUCH_IMPULSE=2.1",1)
	return "local VTR_CLOSE_DRIBBLE_DISTANCE=0.92\nlocal VTR_DRIBBLE_TOUCH_INTERVAL=.5\nlocal VTR_DRIBBLE_TOUCH_IMPULSE=2.1\n"+src

text=add_constants(text)

if "local function vtrDribbleTouchImpulse" not in text:
	insert=r'''
local function vtrDribbleTouchImpulse(ball:BasePart, carrier:Model?, carrierRoot:BasePart?)
	if not ball or not carrier or not carrierRoot then return end
	local move=tonumber(carrier:GetAttribute("VTRMoveMagnitude"))or 0
	if move<.12 then return end
	local now=os.clock()
	local last=tonumber(carrier:GetAttribute("VTRLastDribbleTouchImpulse"))or 0
	if now-last<VTR_DRIBBLE_TOUCH_INTERVAL then return end
	carrier:SetAttribute("VTRLastDribbleTouchImpulse",now)
	local side=tonumber(carrierRoot:GetAttribute("VTRDribbleTouchSide"))or 1
	side=side<0 and 1 or -1
	carrierRoot:SetAttribute("VTRDribbleTouchSide",side)
	local forward=Vector3.new(carrierRoot.CFrame.LookVector.X,0,carrierRoot.CFrame.LookVector.Z)
	if forward.Magnitude<.05 then forward=Vector3.zAxis end
	forward=forward.Unit
	local right=Vector3.new(carrierRoot.CFrame.RightVector.X,0,carrierRoot.CFrame.RightVector.Z)
	if right.Magnitude<.05 then right=Vector3.xAxis end
	right=right.Unit
	local pulse=(forward*.86+right*(side*.14))
	if pulse.Magnitude<.05 then return end
	pulse=pulse.Unit*VTR_DRIBBLE_TOUCH_IMPULSE
	local velocity=ball.AssemblyLinearVelocity
	ball.AssemblyLinearVelocity=Vector3.new(velocity.X+pulse.X,velocity.Y,velocity.Z+pulse.Z)
	ball:SetAttribute("VTRDribbleTouchImpulseAt",now)
end

'''
	m=re.search(r"\nlocal function",text)
	if not m:
		m=re.search(r"\nfunction BallService",text)
	if not m:
		raise SystemExit("Could not find helper insertion point")
	text=text[:m.start()]+"\n"+insert+text[m.start():]

changed_distance=False

patterns=[
	r"(root\.Position\s*\+\s*(?:forward|facing|direction)\s*\*\s*\(?\s*radius\s*\+\s*)[0-9.]+(\s*\)?)",
	r"(root\.Position\s*\+\s*(?:forward|facing|direction)\s*\*\s*)[0-9.]+",
	r"((?:target|desired|position|dribbleTarget)\s*=\s*[^;\n]*(?:forward|facing|direction)\s*\*\s*\(?\s*(?:radius\s*\+\s*)?)[0-9.]+(\s*\)?)",
	r"((?:AlignPosition|alignPosition|positioner|attachment|target)[A-Za-z0-9_\.]*\.Position\s*=\s*[^;\n]*(?:forward|facing|direction)\s*\*\s*\(?\s*(?:radius\s*\+\s*)?)[0-9.]+(\s*\)?)",
	r"((?:DribbleDistance|dribbleDistance|BallDistance|ballDistance|CarryDistance|carryDistance)\s*=\s*)[0-9.]+",
]

for pattern in patterns:
	def repl(m):
		global changed_distance
		changed_distance=True
		if len(m.groups())>=2:
			return m.group(1)+"VTR_CLOSE_DRIBBLE_DISTANCE"+m.group(2)
		return m.group(1)+"VTR_CLOSE_DRIBBLE_DISTANCE"
	text=re.sub(pattern,repl,text)

text=text.replace("radius+VTR_CLOSE_DRIBBLE_DISTANCE","radius+VTR_CLOSE_DRIBBLE_DISTANCE")
text=text.replace("radius + VTR_CLOSE_DRIBBLE_DISTANCE","radius+VTR_CLOSE_DRIBBLE_DISTANCE")

changed_pulse=False
step=re.search(r"function BallService:Step\([^\n]*\)[\s\S]*?\nend",text)
if step and "vtrDribbleTouchImpulse(" not in step.group(0):
	block=step.group(0)
	lines=block.splitlines()
	new=[]
	for line in lines:
		new.append(line)
		low=line.lower()
		if not changed_pulse and ("keepdribbletargetatfeet" in low or "dribbletarget" in low or "vtrdribble" in low) and ("root" in block and ("owner" in block or "carrier" in block)):
			owner="owner" if "owner" in block else "carrier"
			new.append(f"\t\tvtrDribbleTouchImpulse(self.Ball,{owner},root)")
			changed_pulse=True
	newblock="\n".join(new)
	text=text[:step.start()]+newblock+text[step.end():]

if not changed_pulse:
	for fn in re.finditer(r"function BallService:[A-Za-z0-9_]+\([^\n]*\)[\s\S]*?\nend",text):
		block=fn.group(0)
		low=block.lower()
		if "dribble" in low and "root" in low and ("owner" in low or "carrier" in low) and "vtrDribbleTouchImpulse(" not in block:
			owner="owner" if "owner" in block else "carrier"
			lines=block.splitlines()
			new=[]
			for line in lines:
				new.append(line)
				if not changed_pulse and ("cframe" in line.lower() or "assemblylinearvelocity" in line.lower() or "alignposition" in line.lower()):
					new.append(f"\t\tvtrDribbleTouchImpulse(self.Ball,{owner},root)")
					changed_pulse=True
			newblock="\n".join(new)
			text=text[:fn.start()]+newblock+text[fn.end():]
			break

if text==original:
	raise SystemExit("No changes made. Paste the printed DRIBBLE / WELD / BALL POSITION LINES output.")

path.write_text(text.strip()+"\n",encoding="utf-8")
print()
print("PATCHED:", path)
print("changed_distance", changed_distance)
print("changed_pulse", changed_pulse)
print("VTR_CLOSE_DRIBBLE_DISTANCE=0.92")