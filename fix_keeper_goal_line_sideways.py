from pathlib import Path
import re

path=Path("src/server/Gameplay/GoalkeeperService.lua")
text=path.read_text(encoding="utf-8",errors="ignore")
original=text

if "local VTR_KEEPER_GOAL_LINE_DEPTH" not in text:
	text=text.replace(
		"local VTR_KEEPER_SIDEWAYS_ONLY=true",
		"local VTR_KEEPER_SIDEWAYS_ONLY=true\nlocal VTR_KEEPER_GOAL_LINE_DEPTH=3.2",
		1
	)

if "local function vtrKeeperGoalLineSidewaysTarget" not in text:
	insert=r'''
local function vtrKeeperGoalLineSidewaysTarget(rectangle:any, keeperRoot:BasePart, forward:Vector3, target:Vector3):Vector3
	local targetOffset=target-rectangle.PlanePoint
	local targetHorizontal=targetOffset:Dot(rectangle.Right)
	local currentOffset=keeperRoot.Position-rectangle.PlanePoint
	local currentDepth=currentOffset:Dot(forward)
	local safeDepth=math.clamp(currentDepth,saveLineOffset(rectangle,1)+.35,saveLineOffset(rectangle,1)+VTR_KEEPER_GOAL_LINE_DEPTH)
	local height=keeperRoot.Position.Y
	return GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*safeDepth
end

'''
	m=re.search(r"\nlocal function",text)
	if not m:
		raise SystemExit("helper insertion point not found")
	text=text[:m.start()]+"\n"+insert+text[m.start():]

m=re.search(r"function Service:_positionOnLine\(defendingSide:string\)[\s\S]*?\nend\n\nfunction Service:_rushCloseCarrier",text)
if not m:
	raise SystemExit("_positionOnLine block not found")

block=m.group(0)

block=re.sub(
	r"local currentDepth=\(keeperRoot\.Position-rectangle\.PlanePoint\):Dot\(forward\)\s*\n\s*local targetDepth=currentDepth\s*\n\s*local target=GoalModelResolver\.Point\(rectangle,targetHorizontal,height\)\+forward\*targetDepth",
	r'''local target=GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*(saveLineOffset(rectangle,self.Ball.Size.X*.5)+1.1)
	target=vtrKeeperGoalLineSidewaysTarget(rectangle,keeperRoot,forward,target)''',
	block,
	count=1
)

block=re.sub(
	r"local target=GoalModelResolver\.Point\(rectangle,targetHorizontal,height\)\+forward\*targetDepth",
	r'''local target=GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*targetDepth
	target=vtrKeeperGoalLineSidewaysTarget(rectangle,keeperRoot,forward,target)''',
	block,
	count=1
)

block=block.replace(
	"local flatTarget=keeperRoot.Position+rectangle.Right*((target-keeperRoot.Position):Dot(rectangle.Right))",
	"local flatTarget=Vector3.new(target.X,keeperRoot.Position.Y,target.Z)"
)

text=text[:m.start()]+block+text[m.end():]

if "vtrKeeperGoalLineSidewaysTarget(rectangle,keeperRoot,forward,target)" not in text:
	raise SystemExit("goal-line sideways target not inserted")

if text==original:
	raise SystemExit("no changes made")

path.write_text(text.strip()+"\n",encoding="utf-8")
print("keeper now shifts sideways while clamped near goal line")