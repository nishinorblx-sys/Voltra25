from pathlib import Path
import re

path=Path("src/server/Gameplay/BallService.lua")
text=path.read_text(encoding="utf-8",errors="ignore")

original=text

for bad in [
	"local VTR_DRIBBLE_FEET_DISTANCE=1.55",
	"local VTR_DRIBBLE_VISUAL_IMPULSE_INTERVAL=.5",
	"local VTR_DRIBBLE_VISUAL_IMPULSE_STRENGTH=4.75",
	"local DRIBBLE_FEET_DISTANCE=1.28",
	"local DRIBBLE_SIDE_TOUCH_OFFSET=.22",
	"local DRIBBLE_TOUCH_INTERVAL=.5",
	"local DRIBBLE_TOUCH_PULSE_SPEED=2.85",
]:
	text=text.replace("\n"+bad,"")

text=re.sub(r"\nfunction BallService:_vtrDribbleVisualImpulse\([\s\S]*?\nend\n","",text)
text=re.sub(r"\nfunction BallService:_vtrApplyDribbleTouchPulse\([\s\S]*?\nend\n","",text)
text=re.sub(r"\n\s*self:_vtrDribbleVisualImpulse\([^\n]*\)","",text)
text=re.sub(r"\n\s*self:_vtrApplyDribbleTouchPulse\([^\n]*\)","",text)

if "local DRIBBLE_BALL_DISTANCE" not in text:
	text=text.replace(
		"local BallService={};BallService.__index=BallService",
		"local BallService={};BallService.__index=BallService\nlocal DRIBBLE_BALL_DISTANCE=1.05\nlocal DRIBBLE_BALL_SIDE_OFFSET=.16\nlocal DRIBBLE_BALL_HEIGHT_OFFSET=-1.86\nlocal DRIBBLE_TOUCH_INTERVAL=.5\nlocal DRIBBLE_TOUCH_SPEED=2.35",
		1
	)

m=re.search(r"local function keepDribbleTargetAtFeet\([\s\S]*?\nend",text)
if not m:
	raise SystemExit("keepDribbleTargetAtFeet not found")

new_func=r'''local function keepDribbleTargetAtFeet(root:BasePart, ball:BasePart, forward:Vector3?):Vector3
	local facing=forward
	if not facing or facing.Magnitude<.05 then
		facing=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
	end
	if facing.Magnitude<.05 then facing=Vector3.zAxis end
	facing=facing.Unit

	local right=Vector3.new(root.CFrame.RightVector.X,0,root.CFrame.RightVector.Z)
	if right.Magnitude<.05 then right=Vector3.xAxis end
	right=right.Unit

	local side=tonumber(root:GetAttribute("VTRDribbleFootSide"))or 1
	side=side<0 and -1 or 1

	local radius=math.max(ball.Size.X,ball.Size.Z)*.5
	return root.Position+facing*(radius+DRIBBLE_BALL_DISTANCE)+right*(side*DRIBBLE_BALL_SIDE_OFFSET)+Vector3.new(0,DRIBBLE_BALL_HEIGHT_OFFSET,0)
end'''

text=text[:m.start()]+new_func+text[m.end():]

if "local function applyDribbleTouchPulse" not in text:
	insert=r'''
local function applyDribbleTouchPulse(ball:BasePart, owner:Model, root:BasePart)
	local moveMagnitude=tonumber(owner:GetAttribute("VTRMoveMagnitude"))or 0
	if moveMagnitude<.12 then return end

	local now=os.clock()
	local last=tonumber(owner:GetAttribute("VTRLastDribbleTouchPulse"))or 0
	if now-last<DRIBBLE_TOUCH_INTERVAL then return end
	owner:SetAttribute("VTRLastDribbleTouchPulse",now)

	local side=tonumber(root:GetAttribute("VTRDribbleFootSide"))or 1
	side=side<0 and 1 or -1
	root:SetAttribute("VTRDribbleFootSide",side)

	local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
	if forward.Magnitude<.05 then forward=Vector3.zAxis end
	forward=forward.Unit

	local right=Vector3.new(root.CFrame.RightVector.X,0,root.CFrame.RightVector.Z)
	if right.Magnitude<.05 then right=Vector3.xAxis end
	right=right.Unit

	local pulse=(forward*.78+right*(side*.22))
	if pulse.Magnitude<.05 then return end
	pulse=pulse.Unit*DRIBBLE_TOUCH_SPEED

	local velocity=ball.AssemblyLinearVelocity
	ball.AssemblyLinearVelocity=Vector3.new(velocity.X+pulse.X,velocity.Y,velocity.Z+pulse.Z)
	ball:SetAttribute("VTRDribbleTouchPulseAt",now)
	ball:SetAttribute("VTRDribbleFootSide",side)
end

'''
	text=text[:m.start()]+insert+text[m.start():]

matches=list(re.finditer(r"keepDribbleTargetAtFeet\(([^)]*)\)",text))
if not matches:
	raise SystemExit("no keepDribbleTargetAtFeet calls found")

patched_call=False
for match in matches:
	line_start=text.rfind("\n",0,match.start())+1
	line_end=text.find("\n",match.end())
	if line_end==-1:
		line_end=len(text)
	line=text[line_start:line_end]
	if "applyDribbleTouchPulse" in text[line_end:line_end+160]:
		patched_call=True
		break
	if "root" in line and ("owner" in text[max(0,line_start-900):line_start] or "carrier" in text[max(0,line_start-900):line_start]):
		owner_name="owner"
		window=text[max(0,line_start-900):line_start+900]
		if "carrier" in window and "owner" not in window:
			owner_name="carrier"
		insert_at=line_end
		text=text[:insert_at]+f"\n\t\tapplyDribbleTouchPulse(self.Ball,{owner_name},root)"+text[insert_at:]
		patched_call=True
		break

if not patched_call:
	for match in matches:
		print("CALL",text[:match.start()].count("\n")+1,text[text.rfind("\n",0,match.start())+1:text.find("\n",match.end())])
	raise SystemExit("could not safely attach pulse to dribble block")

text=re.sub(r"radius\s*\+\s*VTR_DRIBBLE_FEET_DISTANCE","radius+DRIBBLE_BALL_DISTANCE",text)
text=re.sub(r"radius\s*\+\s*DRIBBLE_FEET_DISTANCE","radius+DRIBBLE_BALL_DISTANCE",text)
text=re.sub(r"radius\s*\+\s*2\.\d+","radius+DRIBBLE_BALL_DISTANCE",text)
text=re.sub(r"radius\s*\+\s*1\.\d+","radius+DRIBBLE_BALL_DISTANCE",text)

if text==original:
	raise SystemExit("no changes made")

if "DRIBBLE_BALL_DISTANCE=1.05" not in text:
	raise SystemExit("distance constant missing")

if "applyDribbleTouchPulse(self.Ball" not in text:
	raise SystemExit("touch pulse was not inserted into dribble block")

path.write_text(text.strip()+"\n",encoding="utf-8")
print("changed actual BallService dribble target distance and .5s touch pulse")