from pathlib import Path
import re

path = Path("src/server/Gameplay/GoalkeeperService.lua")
text = path.read_text(encoding="utf-8", errors="ignore")

text = text.replace(
r'''	local scale = math.clamp(dropGap * (1.35 + urgency * 2.4) * (0.55 + phase), 0, 9.5)

	save.LowDive = true
	save.NoJump = true
	save.Target = predicted
	save.SavePoint = predicted
	save.Keeper:SetAttribute("VTRLowShotFlatDive", true)
	save.Keeper:SetAttribute("VTRFallingLowShotDive", true)
	save.Keeper:SetAttribute("VTRKeeperNoJumpDive", true)
	save.Keeper:SetAttribute("VTRDynamicFallAssist", scale)

	return math.min(currentHeight - floorHeight, scale)''',
r'''	local desired = math.min(currentHeight - floorHeight, math.clamp(dropGap * (1.35 + urgency * 2.4) * (0.55 + phase), 0, 9.5))
	local now = os.clock()
	local lastAt = tonumber(save.DynamicFallAssistAt) or now
	local deltaTime = math.clamp(now - lastAt, 1 / 240, 1 / 20)
	local previous = tonumber(save.DynamicFallAssist) or 0
	local blend = math.clamp(deltaTime * (11 + urgency * 18), 0.08, 0.42)
	local assist = previous + (desired - previous) * blend

	save.DynamicFallAssist = assist
	save.DynamicFallAssistAt = now
	save.LowDive = true
	save.NoJump = true
	save.Target = predicted
	save.SavePoint = predicted
	save.Keeper:SetAttribute("VTRLowShotFlatDive", true)
	save.Keeper:SetAttribute("VTRFallingLowShotDive", true)
	save.Keeper:SetAttribute("VTRKeeperNoJumpDive", true)
	save.Keeper:SetAttribute("VTRDynamicFallAssist", assist)

	return assist'''
)

text = re.sub(
r'''local function goalkeeperDiveAnimationName\(save: any\): string[\s\S]*?\nend\n\nfunction Service:_continueDiveAftermath''',
r'''local function goalkeeperDiveAnimationName(save: any): string
	local keeper = save and save.Keeper
	local target = save and (save.Target or save.SavePoint or save.Point or save.DiveAim)
	local keeperRoot = keeper and keeper:FindFirstChild("HumanoidRootPart")

	local low = save and (save.LowDive == true or save.NoJump == true)
	if keeper and (keeper:GetAttribute("VTRLowShotFlatDive") == true or keeper:GetAttribute("VTRFallingLowShotDive") == true or keeper:GetAttribute("VTRKeeperNoJumpDive") == true) then
		low = true
	end

	if low then
		local lateral = 0
		if typeof(target) == "Vector3" and keeperRoot then
			lateral = target.X - keeperRoot.Position.X
		end

		if lateral < -0.75 then
			return "GoalkeeperDiveLowLeft"
		end

		if lateral > 0.75 then
			return "GoalkeeperDiveLowRight"
		end

		return "GoalkeeperDive"
	end

	local posePlan = save and save.DivePosePlan
	if posePlan and posePlan.PoseKind == "LowDive" then
		local rectangle = save.Rectangle
		local right = rectangle and rectangle.Right
		local startPosition = save.StartPosition
		local targetPosition = save.RootTarget or save.DiveAim or save.Target

		if typeof(right) == "Vector3" and typeof(startPosition) == "Vector3" and typeof(targetPosition) == "Vector3" then
			local lateral = (targetPosition - startPosition):Dot(right)
			if lateral < -0.75 then
				return "GoalkeeperDiveLowLeft"
			end
			if lateral > 0.75 then
				return "GoalkeeperDiveLowRight"
			end
		end
	end

	return "GoalkeeperDive"
end

function Service:_continueDiveAftermath''',
text,
count=1
)

if "function Service:_vtrSmoothSwitchLowDiveAnimation" not in text:
	insert = r'''
function Service:_vtrSmoothSwitchLowDiveAnimation(save:any)
	if not save or not save.Keeper or save.Keeper:GetAttribute("VTRFallingLowShotDive") ~= true then
		return
	end

	local keeper = save.Keeper
	local target = save.Target or save.SavePoint or save.DiveAim
	local keeperRoot = root(keeper)
	local lateral = 0

	if typeof(target) == "Vector3" and keeperRoot then
		lateral = target.X - keeperRoot.Position.X
	end

	local animationName = "GoalkeeperDive"
	if lateral < -0.75 then
		animationName = "GoalkeeperDiveLowLeft"
	elseif lateral > 0.75 then
		animationName = "GoalkeeperDiveLowRight"
	end

	if keeper:GetAttribute("VTRCurrentDiveAnimation") == animationName then
		return
	end

	keeper:SetAttribute("VTRCurrentDiveAnimation", animationName)
	keeper:SetAttribute("VTRKeeperDiveAnimationLocked", nil)

	if self.Animations then
		self.Animations:StopAction(keeper, 0.16)
		task.delay(0.05, function()
			if keeper.Parent and keeper:GetAttribute("VTRGoalkeeperSaving") == true then
				self.Animations:PlayAction(keeper, animationName)
				keeper:SetAttribute("VTRKeeperDiveAnimationLocked", true)
			end
		end)
	end
end

'''
	m = re.search(r"\nfunction Service:Step\(dt:number\?\)", text)
	if not m:
		raise SystemExit("Step not found")
	text = text[:m.start()] + "\n" + insert + text[m.start():]

text = text.replace(
	"save.Keeper:SetAttribute(\"VTRKeeperDiveAnimationLocked\",true)\n\t\t\t\tself.Animations:PlayAction(save.Keeper,goalkeeperDiveAnimationName(save))",
	"save.Keeper:SetAttribute(\"VTRKeeperDiveAnimationLocked\",true)\n\t\t\t\tlocal diveAnimationName=goalkeeperDiveAnimationName(save)\n\t\t\t\tsave.Keeper:SetAttribute(\"VTRCurrentDiveAnimation\",diveAnimationName)\n\t\t\t\tself.Animations:PlayAction(save.Keeper,diveAnimationName)"
)

text = text.replace(
	"liftKeeperAboveFloor(save.Keeper,upAxis,self.PitchCFrame.Position:Dot(upAxis)+.58,.08)\n\tend",
	"liftKeeperAboveFloor(save.Keeper,upAxis,self.PitchCFrame.Position:Dot(upAxis)+.58,.08)\n\t\tself:_vtrSmoothSwitchLowDiveAnimation(save)\n\tend",
	1
)

text = text.replace(
	'keeper:SetAttribute("VTRKeeperLowDiveSwitched", true)',
	'keeper:SetAttribute("VTRKeeperLowDiveSwitched", true)'
)

text = re.sub(
	r'''local animationName = "GoalkeeperDiveLow"\n\s*if lateral < -0\.75 then\n\s*animationName = "GoalkeeperDiveLowLeft"\n\s*elseif lateral > 0\.75 then\n\s*animationName = "GoalkeeperDiveLowRight"\n\s*end''',
r'''local animationName = "GoalkeeperDive"
				if lateral < -0.75 then
					animationName = "GoalkeeperDiveLowLeft"
				elseif lateral > 0.75 then
					animationName = "GoalkeeperDiveLowRight"
				end''',
text
)

path.write_text(text.strip() + "\n", encoding="utf-8")
print("patched smooth low dive transition and animation selection")