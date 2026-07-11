from pathlib import Path
import re

path=Path("src/server/Gameplay/GoalkeeperService.lua")
text=path.read_text(encoding="utf-8",errors="ignore")

text=re.sub(
	r'''local function vtrKeeperGoalLineSidewaysTarget\(rectangle:any, keeperRoot:BasePart, forward:Vector3, target:Vector3\):Vector3[\s\S]*?\nend\n''',
	r'''local function vtrKeeperGoalLineSidewaysTarget(rectangle:any, keeperRoot:BasePart, forward:Vector3, target:Vector3):Vector3
	local targetOffset=target-rectangle.PlanePoint
	local targetHorizontal=targetOffset:Dot(rectangle.Right)
	local safeDepth=3.2
	if typeof(saveLineOffset)=="function" then
		safeDepth=saveLineOffset(rectangle,1)+3.2
	end
	local height=keeperRoot.Position.Y
	return GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*safeDepth
end
''',
	text,
	count=1
)

text=text.replace(
	"local target=GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*(saveLineOffset(rectangle,self.Ball.Size.X*.5)+1.1)",
	"local target=GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*3.2"
)

path.write_text(text.strip()+"\n",encoding="utf-8")
print("fixed goalkeeper nil call in goal-line helper")