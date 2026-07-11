from pathlib import Path
import re

path=Path("src/server/Gameplay/BallService.lua")
text=path.read_text(encoding="utf-8",errors="ignore")

if "local VTR_DRIBBLE_FEET_DISTANCE" not in text:
	text=text.replace(
		"local BallService={};BallService.__index=BallService",
		"local BallService={};BallService.__index=BallService\nlocal VTR_DRIBBLE_FEET_DISTANCE=1.55\nlocal VTR_DRIBBLE_VISUAL_IMPULSE_INTERVAL=.5\nlocal VTR_DRIBBLE_VISUAL_IMPULSE_STRENGTH=4.75"
	)

text=re.sub(
	r"local function keepDribbleTargetAtFeet\([\s\S]*?\nend",
	r'''local function keepDribbleTargetAtFeet(root:BasePart, ball:BasePart, forward:Vector3?):Vector3
	local facing=forward
	if not facing or facing.Magnitude<.05 then
		facing=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
	end
	if facing.Magnitude<.05 then facing=Vector3.zAxis end
	facing=facing.Unit
	local right=Vector3.new(root.CFrame.RightVector.X,0,root.CFrame.RightVector.Z)
	if right.Magnitude<.05 then right=Vector3.xAxis end
	right=right.Unit
	local side=root:GetAttribute("VTRDribbleFootSide")
	if side==nil then side=1 end
	side=side==-1 and -1 or 1
	root:SetAttribute("VTRDribbleFootSide",side)
	local radius=math.max(ball.Size.X,ball.Size.Z)*.5
	return root.Position+facing*(radius+VTR_DRIBBLE_FEET_DISTANCE)+right*(side*.34)+Vector3.new(0,-1.92,0)
end''',
	text,
	count=1
)

if "function BallService:_vtrDribbleVisualImpulse" not in text:
	insert=r'''
function BallService:_vtrDribbleVisualImpulse(owner:Model, root:BasePart, dt:number)
	if not owner or not root or not self.Ball then return end
	if self.Possession:GetOwner()~=owner then return end
	local moveMagnitude=tonumber(owner:GetAttribute("VTRMoveMagnitude"))or 0
	if moveMagnitude<.12 then return end
	local now=os.clock()
	local last=tonumber(owner:GetAttribute("VTRLastDribbleVisualImpulse"))or 0
	if now-last<VTR_DRIBBLE_VISUAL_IMPULSE_INTERVAL then return end
	owner:SetAttribute("VTRLastDribbleVisualImpulse",now)
	local side=tonumber(root:GetAttribute("VTRDribbleFootSide"))or 1
	side=side==-1 and 1 or -1
	root:SetAttribute("VTRDribbleFootSide",side)
	local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
	if forward.Magnitude<.05 then forward=Vector3.zAxis end
	forward=forward.Unit
	local right=Vector3.new(root.CFrame.RightVector.X,0,root.CFrame.RightVector.Z)
	if right.Magnitude<.05 then right=Vector3.xAxis end
	right=right.Unit
	local impulse=(forward*.58+right*(side*.42)).Unit*VTR_DRIBBLE_VISUAL_IMPULSE_STRENGTH
	self.Ball.AssemblyLinearVelocity+=Vector3.new(impulse.X,0,impulse.Z)
	self.Ball:SetAttribute("VTRDribbleVisualImpulseAt",now)
	self.Ball:SetAttribute("VTRDribbleVisualImpulseSide",side)
end

'''
	m=re.search(r"\nfunction BallService:Step",text)
	if not m:
		raise SystemExit("BallService:Step not found")
	text=text[:m.start()]+"\n"+insert+text[m.start():]

replacements=[
	("radius+2.15","radius+VTR_DRIBBLE_FEET_DISTANCE"),
	("radius+2.05","radius+VTR_DRIBBLE_FEET_DISTANCE"),
	("radius+1.95","radius+VTR_DRIBBLE_FEET_DISTANCE"),
	("radius+1.85","radius+VTR_DRIBBLE_FEET_DISTANCE"),
	("radius + 2.15","radius+VTR_DRIBBLE_FEET_DISTANCE"),
	("radius + 2.05","radius+VTR_DRIBBLE_FEET_DISTANCE"),
	("radius + 1.95","radius+VTR_DRIBBLE_FEET_DISTANCE"),
	("radius + 1.85","radius+VTR_DRIBBLE_FEET_DISTANCE"),
]
for a,b in replacements:
	text=text.replace(a,b)

step_patterns=[
	r"(self\.Ball\.AssemblyLinearVelocity\s*=\s*[^\n]*\n)",
	r"(self\.Ball\.CFrame\s*=\s*[^\n]*\n)",
]
if "_vtrDribbleVisualImpulse(owner,root,dt)" not in text:
	m=re.search(r"function BallService:Step\(dt:number\?[\s\S]*?\nend",text)
	if m:
		block=m.group(0)
		changed=block
		for pattern in step_patterns:
			ms=list(re.finditer(pattern,changed))
			if ms:
				last=ms[-1]
				changed=changed[:last.end()]+"\t\tself:_vtrDribbleVisualImpulse(owner,root,dt or 1/60)\n"+changed[last.end():]
				break
		if changed==block:
			changed=changed.replace("\nend","\n\tlocal owner=self.Possession:GetOwner()\n\tlocal root=owner and owner:FindFirstChild(\"HumanoidRootPart\")\n\tif owner and root then self:_vtrDribbleVisualImpulse(owner,root,dt or 1/60)end\nend",1)
		text=text[:m.start()]+changed+text[m.end():]

path.write_text(text.strip()+"\n",encoding="utf-8")
print("patched closer dribble ball and visual impulse")