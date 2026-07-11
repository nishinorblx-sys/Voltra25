from pathlib import Path
import re

path=Path("src/server/Gameplay/BallService.lua")
text=path.read_text(encoding="utf-8",errors="ignore")

text=re.sub(r"\nlocal VTR_DRIBBLE_TOUCH_INTERVAL[^\n]*","",text)
text=re.sub(r"\nlocal VTR_DRIBBLE_TOUCH_IMPULSE[^\n]*","",text)
text=re.sub(r"\nlocal DRIBBLE_TOUCH_INTERVAL[^\n]*","",text)
text=re.sub(r"\nlocal DRIBBLE_TOUCH_PULSE_SPEED[^\n]*","",text)
text=re.sub(r"\nlocal VTR_DRIBBLE_VISUAL_IMPULSE_INTERVAL[^\n]*","",text)
text=re.sub(r"\nlocal VTR_DRIBBLE_VISUAL_IMPULSE_STRENGTH[^\n]*","",text)

text=re.sub(r"\nlocal function vtrDribbleTouchImpulse\([\s\S]*?\nend\n","",text)
text=re.sub(r"\nlocal function applyDribbleTouchPulse\([\s\S]*?\nend\n","",text)
text=re.sub(r"\nfunction BallService:_vtrApplyDribbleTouchPulse\([\s\S]*?\nend\n","",text)
text=re.sub(r"\nfunction BallService:_vtrDribbleVisualImpulse\([\s\S]*?\nend\n","",text)

text=re.sub(r"\n\s*vtrDribbleTouchImpulse\([^\n]*\)","",text)
text=re.sub(r"\n\s*applyDribbleTouchPulse\([^\n]*\)","",text)
text=re.sub(r"\n\s*self:_vtrApplyDribbleTouchPulse\([^\n]*\)","",text)
text=re.sub(r"\n\s*self:_vtrDribbleVisualImpulse\([^\n]*\)","",text)

if "local VTR_CLOSE_DRIBBLE_DISTANCE" in text:
	text=re.sub(r"local VTR_CLOSE_DRIBBLE_DISTANCE\s*=\s*[0-9.]+","local VTR_CLOSE_DRIBBLE_DISTANCE=0.62",text)
elif "local DRIBBLE_BALL_DISTANCE" in text:
	text=re.sub(r"local DRIBBLE_BALL_DISTANCE\s*=\s*[0-9.]+","local DRIBBLE_BALL_DISTANCE=0.62",text)
else:
	text=text.replace(
		"local BallService={};BallService.__index=BallService",
		"local BallService={};BallService.__index=BallService\nlocal VTR_CLOSE_DRIBBLE_DISTANCE=0.62",
		1
	)

text=re.sub(r"local DRIBBLE_FEET_DISTANCE\s*=\s*[0-9.]+","local DRIBBLE_FEET_DISTANCE=0.62",text)
text=re.sub(r"local VTR_DRIBBLE_FEET_DISTANCE\s*=\s*[0-9.]+","local VTR_DRIBBLE_FEET_DISTANCE=0.62",text)

text=re.sub(r"radius\s*\+\s*VTR_CLOSE_DRIBBLE_DISTANCE","radius+VTR_CLOSE_DRIBBLE_DISTANCE",text)
text=re.sub(r"radius\s*\+\s*DRIBBLE_BALL_DISTANCE","radius+VTR_CLOSE_DRIBBLE_DISTANCE",text)
text=re.sub(r"radius\s*\+\s*DRIBBLE_FEET_DISTANCE","radius+VTR_CLOSE_DRIBBLE_DISTANCE",text)
text=re.sub(r"radius\s*\+\s*VTR_DRIBBLE_FEET_DISTANCE","radius+VTR_CLOSE_DRIBBLE_DISTANCE",text)

text=re.sub(r"radius\s*\+\s*2\.[0-9]+","radius+VTR_CLOSE_DRIBBLE_DISTANCE",text)
text=re.sub(r"radius\s*\+\s*1\.[0-9]+","radius+VTR_CLOSE_DRIBBLE_DISTANCE",text)
text=re.sub(r"radius\s*\+\s*0\.[0-9]+","radius+VTR_CLOSE_DRIBBLE_DISTANCE",text)

if "VTR_DRIBBLE_TOUCH_IMPULSE" in text or "vtrDribbleTouchImpulse" in text or "DRIBBLE_TOUCH_PULSE_SPEED" in text or "ApplyDribbleTouchPulse" in text:
	raise SystemExit("impulse code still remains")

path.write_text(text.strip()+"\n",encoding="utf-8")
print("removed dribble impulse and set ball spacing closer")