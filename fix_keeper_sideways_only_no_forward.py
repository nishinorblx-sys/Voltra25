from pathlib import Path
import re

path=Path("src/server/Gameplay/GoalkeeperService.lua")
text=path.read_text(encoding="utf-8",errors="ignore")
original=text

if "local VTR_KEEPER_SIDEWAYS_ONLY" not in text:
	text=text.replace(
		"local Service={};Service.__index=Service",
		"local Service={};Service.__index=Service\nlocal VTR_KEEPER_SIDEWAYS_ONLY=true",
		1
	)

if "local function vtrKeeperSidewaysOnlyTarget" not in text:
	insert=r'''
local function vtrKeeperSidewaysOnlyTarget(keeperRoot:BasePart, rectangle:any, forward:Vector3, target:Vector3):Vector3
	if not VTR_KEEPER_SIDEWAYS_ONLY then return target end
	local currentOffset=keeperRoot.Position-rectangle.PlanePoint
	local targetOffset=target-rectangle.PlanePoint
	local currentDepth=currentOffset:Dot(forward)
	local targetHorizontal=targetOffset:Dot(rectangle.Right)
	local height=target.Y
	return GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*currentDepth
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

if "vtrKeeperSidewaysOnlyTarget" not in block:
	block=re.sub(
		r"(local target=GoalModelResolver\.Point\(rectangle,[^\n]*\)\+forward\*[^\n]*\n)",
		r"\1\ttarget=vtrKeeperSidewaysOnlyTarget(keeperRoot,rectangle,forward,target)\n",
		block,
		count=1
	)
	block=block.replace(
		"local flatTarget=Vector3.new(target.X,keeperRoot.Position.Y,target.Z)",
		"local flatTarget=Vector3.new(target.X,keeperRoot.Position.Y,target.Z)"
	)

text=text[:m.start()]+block+text[m.end():]

m=re.search(r"function Service:_rushCloseCarrier\(defendingSide:string\): boolean[\s\S]*?\nend",text)
if m:
	block=m.group(0)
	if "VTRKeeperUserControlledRush" not in block:
		block=block.replace(
			"local keeper=goalkeeper(self.Teams[defendingSide])",
			"local keeper=goalkeeper(self.Teams[defendingSide])",
			1
		)
		block=block.replace(
			"if not keeper then return false end",
			"if not keeper then return false end\n\tif keeper:GetAttribute(\"controlledByUser\")~=true then return false end",
			1
		)
	text=text[:m.start()]+block+text[m.end():]

m=re.search(r"function Service:_positionOnLine\(defendingSide:string\)[\s\S]*?\nend\n\nfunction Service:_rushCloseCarrier",text)
if m:
	block=m.group(0)
	block=re.sub(
		r"local targetDepth=lineDepth[\s\S]*?local target=GoalModelResolver\.Point\(rectangle,targetHorizontal,height\)\+forward\*targetDepth",
		r'''local currentDepth=(keeperRoot.Position-rectangle.PlanePoint):Dot(forward)
	local targetDepth=currentDepth
	local target=GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*targetDepth''',
		block,
		count=1
	)
	block=block.replace(
		"local flatTarget=Vector3.new(target.X,keeperRoot.Position.Y,target.Z)",
		"local flatTarget=keeperRoot.Position+rectangle.Right*((target-keeperRoot.Position):Dot(rectangle.Right))"
	)
	text=text[:m.start()]+block+text[m.end():]

if text==original:
	raise SystemExit("no changes made")

if "targetDepth=lineDepth+(boxEdgeDepth-lineDepth)" in text:
	raise SystemExit("forward movement depth still exists in _positionOnLine")

path.write_text(text.strip()+"\n",encoding="utf-8")
print("keeper positioning limited to sideways only unless user controlled")