--!strict
local VTRGoalPassThrough = require(script.Parent:WaitForChild("GoalShotPassThroughService"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoalModelResolver = require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}
Service.__index = Service

local DIVE_LEAD_TIME = 0.08
local EMERGENCY_SAVE_TIME = 0.025
local CATCH_RADIUS = 2.35
local DEFAULT_DIVE_SPEED = 21
local MAX_RATED_DIVE_SPEED_MULTIPLIER = 1.27
local DIVE_JUMP_HEIGHT = 0.72
local DIVE_FALL_THROUGH = 1.08
local DIVE_STRETCH_COMPLETE = 0.52
local DIVE_LAND_HOLD = 0.34
local DIVE_RECOVER = 0.72
local DIVE_RETURN_HOME = 0.28
local SAFE_ROOT_HEIGHT = 3.05
local MIN_VISUAL_DIVE_TIME = 0.34
local AI_KEEPER_DISTRIBUTION_DELAY = 0.65
local AI_KEEPER_DISTRIBUTION_WINDOW = 3.8
local AI_KEEPER_HOLD_FAILSAFE = 5.2
local KEEPER_AGGRESSIVE_POSITION_DISTANCE = 160
local KEEPER_LATERAL_REACT_DISTANCE = 160

local function root(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function goalkeeper(team: {Model}): Model?
	for _, model in team do
		if model:GetAttribute("position") == "GK" then return model end
	end
	return team[1]
end

local function userControlledKeeper(keeper: Model): boolean
	return keeper:GetAttribute("controlledByUser") == true or keeper:GetAttribute("VTRUserControlled") == true
end

local function insideGoal(rectangle: any, point: Vector3, radius: number): boolean
	local offset = point - rectangle.PlanePoint
	local horizontal = offset:Dot(rectangle.Right)
	local vertical = offset:Dot(rectangle.Up)
	return horizontal >= rectangle.Left + radius * 0.35
		and horizontal <= rectangle.RightBound - radius * 0.35
		and vertical >= rectangle.Bottom + radius * 0.2
		and vertical <= rectangle.Top - radius * 0.35
end

local function saveLineOffset(rectangle:any,ballRadius:number):number
	if VTRGoalPassThrough.ShouldBypass(VTRGoalPassThrough.ResolveBall(rectangle, ballRadius) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall)) then
		VTRGoalPassThrough.Force(VTRGoalPassThrough.ResolveBall(rectangle, ballRadius) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 1.35)
		return 2
	end
	local hitbox=rectangle.Hitbox
	if hitbox and hitbox.Parent then
		local size=hitbox.Size;local frame=hitbox.CFrame;local normal=rectangle.Normal
		local depth=(math.abs(frame.RightVector:Dot(normal))*size.X+math.abs(frame.UpVector:Dot(normal))*size.Y+math.abs(frame.LookVector:Dot(normal))*size.Z)*.5
		return depth+2
	end
	return 2
end

local function fieldDirection(rectangle:any,pitchCFrame:CFrame):Vector3
	local center=GoalModelResolver.Point(rectangle,(rectangle.Left+rectangle.RightBound)*.5,(rectangle.Bottom+rectangle.Top)*.5)
	local direction=pitchCFrame.Position-center
	direction-=pitchCFrame.UpVector*direction:Dot(pitchCFrame.UpVector)
	return direction.Magnitude>.1 and direction.Unit or-rectangle.Normal
end

local function keeperRating(keeper:Model):number
	local overall=tonumber(keeper:GetAttribute("overall"))or 65
	local diving=tonumber(keeper:GetAttribute("gkDiving"))or tonumber(keeper:GetAttribute("GKDIV"))or overall
	local reflexes=tonumber(keeper:GetAttribute("gkReflexes"))or tonumber(keeper:GetAttribute("GKREF"))or overall
	local handling=tonumber(keeper:GetAttribute("gkHandling"))or tonumber(keeper:GetAttribute("GKHAN"))or overall
	return math.clamp((overall*.35+diving*.25+reflexes*.3+handling*.1)*1.05,1,99)
end

local function boostedKeeperStat(keeper:Model, primary:string, fallback:string, rating:number):number
	local raw = tonumber(keeper:GetAttribute(primary)) or tonumber(keeper:GetAttribute(fallback))
	return raw and math.clamp(raw * 1.05, 1, 99) or rating
end

local function reflexDiveSpeed(reflexes:number):number
	local alpha = math.clamp((reflexes - 27) / (99 - 27), 0, 1)
	return 16 + (DEFAULT_DIVE_SPEED * MAX_RATED_DIVE_SPEED_MULTIPLIER - 16) * alpha
end

local function smoothStep(alpha:number):number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function finiteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteVector3(value: any): boolean
	return typeof(value) == "Vector3" and finiteNumber(value.X) and finiteNumber(value.Y) and finiteNumber(value.Z)
end

local DivePoseRigCache = setmetatable({}, {__mode = "k"})

local function findDiveMotor(model: Model, names: {string}): Motor6D?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			for _, name in names do
				if descendant.Name == name then
					return descendant
				end
			end
		end
	end
	return nil
end

local function divePoseRig(model: Model): any?
	local cached = DivePoseRigCache[model]
	if cached then
		return cached
	end
	local joints = {
		Root = findDiveMotor(model, {"RootJoint", "Root"}),
		Neck = findDiveMotor(model, {"Neck"}),
		LeftShoulder = findDiveMotor(model, {"Left Shoulder", "LeftShoulder"}),
		RightShoulder = findDiveMotor(model, {"Right Shoulder", "RightShoulder"}),
		LeftHip = findDiveMotor(model, {"Left Hip", "LeftHip"}),
		RightHip = findDiveMotor(model, {"Right Hip", "RightHip"}),
	}
	for _, joint in pairs(joints) do
		if not joint then
			return nil
		end
	end
	local baseC0 = {}
	for name, joint in pairs(joints) do
		baseC0[name] = joint.C0
	end
	cached = {Joints = joints, BaseC0 = baseC0}
	DivePoseRigCache[model] = cached
	return cached
end

local function clearKeeperDivePose(model: Model?)
	if not model then return end
	local rig = DivePoseRigCache[model] or divePoseRig(model)
	if not rig then return end
	for name, joint in pairs(rig.Joints) do
		joint.Transform = CFrame.new()
		if rig.BaseC0[name] then
			joint.C0 = rig.BaseC0[name]
		end
	end
end

local function blendKeeperDivePoseToBase(model: Model?, alpha: number)
	if not model then return end
	local rig = DivePoseRigCache[model] or divePoseRig(model)
	if not rig then return end
	alpha = math.clamp(alpha, 0, 1)
	for name, joint in pairs(rig.Joints) do
		joint.Transform = CFrame.new()
		local base = rig.BaseC0[name]
		if base then
			joint.C0 = joint.C0:Lerp(base, alpha)
		end
	end
end

local function classifyDivePose(rectangle: any, target: Vector3): (string, number, number)
	local offset = target - rectangle.PlanePoint
	local width = math.max(0.1, rectangle.RightBound - rectangle.Left)
	local height = math.max(0.1, rectangle.Top - rectangle.Bottom)
	local horizontal = offset:Dot(rectangle.Right)
	local vertical = offset:Dot(rectangle.Up)
	local center = (rectangle.Left + rectangle.RightBound) * 0.5
	local xNorm = math.clamp((horizontal - center) / (width * 0.5), -1, 1)
	local yNorm = math.clamp((vertical - rectangle.Bottom) / height, 0, 1)
	local absX = math.abs(xNorm)
	if absX < 0.18 and yNorm < 0.38 then
		return "CenterLow", xNorm, yNorm
	elseif absX < 0.18 then
		return "CenterBlock", xNorm, yNorm
	elseif yNorm < 0.28 then
		return "LowDive", xNorm, yNorm
	elseif yNorm > 0.72 and absX > 0.55 then
		return "TopCorner", xNorm, yNorm
	elseif yNorm > 0.62 then
		return "HighDive", xNorm, yNorm
	end
	return "MidDive", xNorm, yNorm
end

local function makeDivePosePlan(rectangle: any, target: Vector3, startPosition: Vector3?, lateralAxis: Vector3): any
	local poseKind, xNorm, yNorm = classifyDivePose(rectangle, target)
	local side = xNorm >= 0 and 1 or -1
	if math.abs(xNorm) < 0.08 and startPosition then
		local lateral = (target - startPosition):Dot(lateralAxis)
		if math.abs(lateral) > 0.2 then
			side = lateral >= 0 and 1 or -1
		end
	end
	local absX = math.abs(xNorm)
	local twoHandChance = math.clamp(0.28 + (1 - absX) * 0.34 + (1 - yNorm) * 0.18, 0.22, 0.7)
	local handStyle = twoHandChance >= 0.46 and "TwoHand" or "OneHand"
	if poseKind == "TopCorner" or poseKind == "HighDive" then
		handStyle = "TwoHand"
	end
	return {
		Side = side,
		PoseKind = poseKind,
		XNorm = xNorm,
		YNorm = yNorm,
		HandStyle = handStyle,
	}
end

local function isOverheadDivePose(plan: any): boolean
	return plan.PoseKind == "TopCorner" or plan.PoseKind == "HighDive" or (plan.PoseKind == "MidDive" and (tonumber(plan.YNorm) or 0) >= 0.42)
end

local function setShoulders(rig: any, leftOffset: CFrame, rightOffset: CFrame, alpha: number)
	alpha = math.clamp(alpha, 0, 1)
	local joints = rig.Joints
	local baseC0 = rig.BaseC0
	joints.LeftShoulder.C0 = baseC0.LeftShoulder:Lerp(baseC0.LeftShoulder * leftOffset, alpha)
	joints.RightShoulder.C0 = baseC0.RightShoulder:Lerp(baseC0.RightShoulder * rightOffset, alpha)
end

local function applyLowDiveArms(rig: any, alpha: number, side: number, twoHanded: boolean)
	if twoHanded then
		setShoulders(
			rig,
			CFrame.Angles(math.rad(20), math.rad(-2 * side), math.rad(-142)),
			CFrame.Angles(math.rad(20), math.rad(2 * side), math.rad(142)),
			alpha
		)
	elseif side < 0 then
		setShoulders(
			rig,
			CFrame.Angles(math.rad(18), math.rad(-3), math.rad(-154)),
			CFrame.Angles(math.rad(12), math.rad(5), math.rad(86)),
			alpha
		)
	else
		setShoulders(
			rig,
			CFrame.Angles(math.rad(12), math.rad(-5), math.rad(-86)),
			CFrame.Angles(math.rad(18), math.rad(3), math.rad(154)),
			alpha
		)
	end
end

local function applyMidDiveArms(rig: any, alpha: number, side: number, twoHanded: boolean)
	if twoHanded then
		setShoulders(
			rig,
			CFrame.Angles(math.rad(-56), math.rad(-4 * side), math.rad(-88)),
			CFrame.Angles(math.rad(-58), math.rad(4 * side), math.rad(88)),
			alpha
		)
	elseif side < 0 then
		setShoulders(
			rig,
			CFrame.Angles(math.rad(-66), math.rad(-5), math.rad(-106)),
			CFrame.Angles(math.rad(-30), math.rad(7), math.rad(54)),
			alpha
		)
	else
		setShoulders(
			rig,
			CFrame.Angles(math.rad(-30), math.rad(-7), math.rad(-54)),
			CFrame.Angles(math.rad(-66), math.rad(5), math.rad(106)),
			alpha
		)
	end
end

local function highCornerOffsets(side: number, twoHanded: boolean, floorAdjust: number?): (CFrame, CFrame)
	local adjust = math.clamp(floorAdjust or 0, 0, 1)
	if twoHanded then
		-- R6 shoulders have rotated base C0s, so these overhead targets are
		-- calibrated per shoulder instead of using generic local X/Z guesses.
		return
			CFrame.Angles(math.rad(-91 + adjust * 17), math.rad(-4 * side), math.rad(-42 + adjust * 10)),
			CFrame.Angles(math.rad(-92 + adjust * 17), math.rad(4 * side), math.rad(42 - adjust * 10))
	end
	if side < 0 then
		return
			CFrame.Angles(math.rad(-96 + adjust * 15), math.rad(-6), math.rad(-52 + adjust * 10)),
			CFrame.Angles(math.rad(-76 + adjust * 15), math.rad(6), math.rad(34 - adjust * 7))
	end
	return
		CFrame.Angles(math.rad(-76 + adjust * 15), math.rad(-6), math.rad(-34 + adjust * 7)),
		CFrame.Angles(math.rad(-96 + adjust * 15), math.rad(6), math.rad(52 - adjust * 10))
end

local function applyHighCornerArms(rig: any, alpha: number, side: number, twoHanded: boolean)
	local leftOffset, rightOffset = highCornerOffsets(side, twoHanded, 0)
	setShoulders(rig, leftOffset, rightOffset, alpha)
end

local function applyLandingArms(rig: any, alpha: number, side: number, poseKind: string, twoHanded: boolean, floorAdjust: number?)
	if poseKind == "TopCorner" or poseKind == "HighDive" then
		local leftOffset, rightOffset = highCornerOffsets(side, twoHanded, floorAdjust or 0.45)
		setShoulders(rig, leftOffset, rightOffset, alpha)
	elseif poseKind == "MidDive" then
		local adjust = math.clamp(floorAdjust or 0, 0, 1)
		if twoHanded then
			setShoulders(
				rig,
				CFrame.Angles(math.rad(-42 + adjust * 16), math.rad(-3 * side), math.rad(-72 + adjust * 12)),
				CFrame.Angles(math.rad(-44 + adjust * 16), math.rad(3 * side), math.rad(72 - adjust * 12)),
				alpha
			)
		elseif side < 0 then
			setShoulders(
				rig,
				CFrame.Angles(math.rad(-50 + adjust * 14), math.rad(-4), math.rad(-86 + adjust * 12)),
				CFrame.Angles(math.rad(-18 + adjust * 10), math.rad(5), math.rad(34 - adjust * 8)),
				alpha
			)
		else
			setShoulders(
				rig,
				CFrame.Angles(math.rad(-18 + adjust * 10), math.rad(-5), math.rad(-34 + adjust * 8)),
				CFrame.Angles(math.rad(-50 + adjust * 14), math.rad(4), math.rad(86 - adjust * 12)),
				alpha
			)
		end
	elseif poseKind == "LowDive" then
		applyLowDiveArms(rig, alpha, side, twoHanded)
	end
end

local function partMinAlong(part: BasePart, axis: Vector3): number
	local frame = part.CFrame
	local size = part.Size
	local radius =
		math.abs(frame.RightVector:Dot(axis)) * size.X * 0.5
		+ math.abs(frame.UpVector:Dot(axis)) * size.Y * 0.5
		+ math.abs(frame.LookVector:Dot(axis)) * size.Z * 0.5
	return frame.Position:Dot(axis) - radius
end

local function liftKeeperAboveFloor(model: Model, upAxis: Vector3, floorHeight: number, clearance: number?)
	local minimum = math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			minimum = math.min(minimum, partMinAlong(descendant, upAxis))
		end
	end
	if minimum == math.huge then return end
	local lift = floorHeight + (clearance or 0.08) - minimum
	if lift > 0.01 then
		model:PivotTo(model:GetPivot() + upAxis * lift)
	end
end

local function setKeeperDivePose(model: Model, alpha: number, plan: any)
	local rig = divePoseRig(model)
	if not rig then return end
	alpha = math.clamp(alpha, 0, 1)
	local joints = rig.Joints
	local baseC0 = rig.BaseC0
	for _, joint in pairs(joints) do
		joint.Transform = CFrame.new()
	end
	local side = plan.Side == 0 and 1 or plan.Side
	local rollSide = -side
	local poseKind = plan.PoseKind
	local twoHanded = plan.HandStyle == "TwoHand"
	local overheadDive = isOverheadDivePose(plan)
	local high = math.clamp((plan.YNorm - 0.45) / 0.55, 0, 1)
	local low = math.clamp((0.42 - plan.YNorm) / 0.42, 0, 1)
	local wide = math.clamp(math.abs(plan.XNorm), 0, 1)
	local reach = math.clamp(wide * 0.72 + high * 0.46 + 0.18, 0, 1)
	local rootPitch = -8 - 12 * low + 12 * high
	local rootRoll = (48 + 50 * wide + 14 * high - 10 * low) * rollSide
	local rootYaw = 10 * side * wide
	if plan.WorldTilted == true then
		rootPitch *= 0.38
		rootRoll *= overheadDive and 0.12 or 0.35
		rootYaw *= 0.2
	end
	local neckPitch = 5 + 12 * high - 8 * low
	local neckRoll = -rootRoll * 0.2
	local neckYaw = 12 * side * wide
	local leadArmZ = 136 + 48 * reach + 18 * high - 18 * low
	local trailArmZ = 78 + 28 * reach - 8 * low
	local leadArmX = -26 - 52 * high + 28 * low
	local trailArmX = -2 - 26 * high + 12 * low
	local leftArmZ = -trailArmZ
	local rightArmZ = trailArmZ
	local leftArmX = trailArmX
	local rightArmX = trailArmX
	local leftLegX = 8 + 18 * low - 16 * high
	local rightLegX = -8 - 16 * low - 6 * high
	local leftLegZ = 28 * rollSide + 22 * wide * rollSide
	local rightLegZ = -18 * rollSide - 12 * wide * rollSide
	if side < 0 then
		leftArmZ = -leadArmZ
		leftArmX = leadArmX
	else
		rightArmZ = leadArmZ
		rightArmX = leadArmX
	end
	if twoHanded and poseKind ~= "CenterBlock" and poseKind ~= "CenterLow" then
		local twoHandX = leadArmX + (trailArmX - leadArmX) * 0.25
		local twoHandZ = leadArmZ - 8
		leftArmX = twoHandX
		rightArmX = twoHandX
		leftArmZ = -twoHandZ
		rightArmZ = twoHandZ
	end
	if poseKind == "CenterBlock" then
		rootPitch = -4 + 8 * high
		rootRoll = 0
		rootYaw = 0
		leftArmZ = -122
		rightArmZ = 122
		leftArmX = -34 - 22 * high
		rightArmX = leftArmX
		leftLegX = 12
		rightLegX = -12
		leftLegZ = -10
		rightLegZ = 10
	elseif poseKind == "CenterLow" then
		rootPitch = -38
		rootRoll = 0
		rootYaw = 0
		leftArmZ = -66
		rightArmZ = 66
		leftArmX = 46
		rightArmX = 46
		leftLegX = 48
		rightLegX = 48
		leftLegZ = -24
		rightLegZ = 24
	elseif poseKind == "LowDive" then
		rootPitch = -24
		rootRoll = 72 * rollSide
		leadArmX = 18
		trailArmX = 14
		leadArmZ = 138
		trailArmZ = 66
		if side < 0 then
			leftArmX = leadArmX
			leftArmZ = -leadArmZ
			rightArmX = trailArmX
			rightArmZ = trailArmZ
		else
			rightArmX = leadArmX
			rightArmZ = leadArmZ
			leftArmX = trailArmX
			leftArmZ = -trailArmZ
		end
		if twoHanded then
			leftArmX = 18
			rightArmX = 18
			leftArmZ = -126
			rightArmZ = 126
		end
		if side < 0 then
			leftLegX = -14
			rightLegX = 46
			leftLegZ = 66 * rollSide
			rightLegZ = -38 * rollSide
		else
			rightLegX = -14
			leftLegX = 46
			leftLegZ = 38 * rollSide
			rightLegZ = -66 * rollSide
		end
	elseif overheadDive then
		rootPitch = -24
		rootRoll = 28 * rollSide
		rootYaw = 4 * side
		neckPitch = 12
		neckYaw = 5 * side
		if side < 0 then
			leftLegX = -18 - 8 * high
			rightLegX = 34 + 8 * high
			leftLegZ = 44 * rollSide
			rightLegZ = -30 * rollSide
		else
			rightLegX = -18 - 8 * high
			leftLegX = 34 + 8 * high
			leftLegZ = 30 * rollSide
			rightLegZ = -44 * rollSide
		end
	end
	joints.Root.C0 = baseC0.Root * CFrame.Angles(math.rad(rootPitch) * alpha, math.rad(rootYaw) * alpha, math.rad(rootRoll) * alpha)
	joints.Neck.C0 = baseC0.Neck * CFrame.Angles(math.rad(neckPitch) * alpha, math.rad(neckYaw) * alpha, math.rad(neckRoll) * alpha)
	if poseKind == "LowDive" then
		applyLowDiveArms(rig, alpha, side, twoHanded)
	elseif overheadDive then
		if poseKind == "MidDive" then
			applyMidDiveArms(rig, alpha, side, twoHanded)
		else
			applyHighCornerArms(rig, alpha, side, twoHanded)
		end
	else
		joints.LeftShoulder.C0 = baseC0.LeftShoulder * CFrame.Angles(math.rad(leftArmX) * alpha, 0, math.rad(leftArmZ) * alpha)
		joints.RightShoulder.C0 = baseC0.RightShoulder * CFrame.Angles(math.rad(rightArmX) * alpha, 0, math.rad(rightArmZ) * alpha)
	end
	joints.LeftHip.C0 = baseC0.LeftHip * CFrame.Angles(math.rad(leftLegX) * alpha, 0, math.rad(leftLegZ) * alpha)
	joints.RightHip.C0 = baseC0.RightHip * CFrame.Angles(math.rad(rightLegX) * alpha, 0, math.rad(rightLegZ) * alpha)
end

local function setKeeperLandingPose(model: Model, plan: any, phaseAlpha: number?)
	local rig = divePoseRig(model)
	if not rig then return end
	local joints = rig.Joints
	local baseC0 = rig.BaseC0
	for _, joint in pairs(joints) do
		joint.Transform = CFrame.new()
	end
	local side = plan.Side == 0 and 1 or plan.Side
	local rollSide = -side
	phaseAlpha = math.clamp(phaseAlpha or 1, 0, 1)
	local high = math.clamp((plan.YNorm - 0.45) / 0.55, 0, 1)
	local low = math.clamp((0.42 - plan.YNorm) / 0.42, 0, 1)
	local overheadDive = isOverheadDivePose(plan)
	local groundRoll = (78 - 12 * low + 6 * high) * rollSide
	local groundPitch = -8 - 14 * low + 6 * high
	if plan.WorldTilted == true then
		groundRoll *= 0.18
		groundPitch *= 0.55
	end
	local shoulderX = 18 + 22 * low - 18 * high
	setKeeperDivePose(model, 1, plan)
	if overheadDive then
		local impact = smoothStep(phaseAlpha)
		local settle = math.clamp((phaseAlpha - 0.35) / 0.65, 0, 1)
		local floorAdjust = math.clamp((phaseAlpha - 0.62) / 0.38, 0, 1)
		local rootRoll = (58 + 16 * impact) * rollSide
		local rootPitch = (-18 + 16 * impact) - 6 * settle
		local rootYaw = 12 * side * impact
		if plan.WorldTilted == true then
			rootRoll *= 0.18
			rootPitch *= 0.55
			rootYaw *= 0.45
		end
		joints.Root.C0 = baseC0.Root * CFrame.Angles(math.rad(rootPitch), math.rad(rootYaw), math.rad(rootRoll))
		joints.Neck.C0 = baseC0.Neck * CFrame.Angles(math.rad(8 + 10 * settle), math.rad(8 * side), math.rad(-rootRoll * 0.12))
		applyLandingArms(rig, 1, side, plan.PoseKind, plan.HandStyle == "TwoHand", floorAdjust * 0.55)
		if side < 0 then
			joints.LeftHip.C0 = baseC0.LeftHip * CFrame.Angles(math.rad(-8 + 16 * settle), 0, math.rad(48 * rollSide))
			joints.RightHip.C0 = baseC0.RightHip * CFrame.Angles(math.rad(34 + 10 * settle), 0, math.rad(-34 * rollSide))
		else
			joints.LeftHip.C0 = baseC0.LeftHip * CFrame.Angles(math.rad(34 + 10 * settle), 0, math.rad(34 * rollSide))
			joints.RightHip.C0 = baseC0.RightHip * CFrame.Angles(math.rad(-8 + 16 * settle), 0, math.rad(-48 * rollSide))
		end
		return
	end
	joints.Root.C0 = baseC0.Root * CFrame.Angles(math.rad(groundPitch), 0, math.rad(groundRoll))
	joints.Neck.C0 = baseC0.Neck * CFrame.Angles(math.rad(8), math.rad(10 * side), math.rad(-groundRoll * 0.16))
	if plan.PoseKind == "LowDive" then
		applyLandingArms(rig, 1, side, plan.PoseKind, plan.HandStyle == "TwoHand", 0.25)
	elseif plan.HandStyle == "TwoHand" then
		joints.LeftShoulder.C0 = baseC0.LeftShoulder * CFrame.Angles(math.rad(shoulderX), 0, math.rad(-118))
		joints.RightShoulder.C0 = baseC0.RightShoulder * CFrame.Angles(math.rad(shoulderX), 0, math.rad(118))
	elseif side < 0 then
		joints.LeftShoulder.C0 = baseC0.LeftShoulder * CFrame.Angles(math.rad(shoulderX - 8), 0, math.rad(-142))
		joints.RightShoulder.C0 = baseC0.RightShoulder * CFrame.Angles(math.rad(shoulderX + 18), 0, math.rad(72))
	else
		joints.RightShoulder.C0 = baseC0.RightShoulder * CFrame.Angles(math.rad(shoulderX - 8), 0, math.rad(142))
		joints.LeftShoulder.C0 = baseC0.LeftShoulder * CFrame.Angles(math.rad(shoulderX + 18), 0, math.rad(-72))
	end
	if side < 0 then
		joints.LeftHip.C0 = baseC0.LeftHip * CFrame.Angles(math.rad(8 + 38 * low), 0, math.rad(46 * rollSide))
		joints.RightHip.C0 = baseC0.RightHip * CFrame.Angles(math.rad(44 + 20 * low), 0, math.rad(-30 * rollSide))
	else
		joints.LeftHip.C0 = baseC0.LeftHip * CFrame.Angles(math.rad(44 + 20 * low), 0, math.rad(30 * rollSide))
		joints.RightHip.C0 = baseC0.RightHip * CFrame.Angles(math.rad(8 + 38 * low), 0, math.rad(-46 * rollSide))
	end
end

local function inGoalkeeperBox(service:any,rectangle:any,point:Vector3):boolean
	local forward=fieldDirection(rectangle,service.PitchCFrame)
	local offset=point-rectangle.PlanePoint
	local depth=offset:Dot(forward)
	local horizontal=offset:Dot(rectangle.Right)
	local margin=18
	return depth>=0 and depth<=36 and horizontal>=rectangle.Left-margin and horizontal<=rectangle.RightBound+margin
end

local function clampKeeperHoldArea(service:any, keeper:Model, keeperRoot:BasePart): boolean
	local localPosition = service.PitchCFrame:PointToObjectSpace(keeperRoot.Position)
	local goalSign = localPosition.Z >= 0 and 1 or -1
	local boxDepth = 142
	local zMin = goalSign > 0 and service.Length * .5 - boxDepth or -service.Length * .5 + 4
	local zMax = goalSign > 0 and service.Length * .5 - 4 or -service.Length * .5 + boxDepth
	if zMin > zMax then zMin, zMax = zMax, zMin end
	local clamped = Vector3.new(
		math.clamp(localPosition.X, -service.Width * .29, service.Width * .29),
		math.max(localPosition.Y, SAFE_ROOT_HEIGHT),
		math.clamp(localPosition.Z, zMin, zMax)
	)
	if (clamped - localPosition).Magnitude <= .08 then
		return false
	end
	local world = service.PitchCFrame:PointToWorldSpace(clamped)
	local facing = Vector3.new(keeperRoot.CFrame.LookVector.X, 0, keeperRoot.CFrame.LookVector.Z)
	keeper:PivotTo(CFrame.lookAt(world, world + (facing.Magnitude > .05 and facing.Unit or service.PitchCFrame.LookVector), service.PitchCFrame.UpVector))
	keeperRoot = root(keeper) or keeperRoot
	keeperRoot.AssemblyLinearVelocity = Vector3.zero
	keeperRoot.AssemblyAngularVelocity = Vector3.zero
	keeperRoot.Anchored = false
	return true
end

local function secureHeldBall(ball: BasePart, keeper: Model)
	local existing = ball:FindFirstChild("VTRGoalkeeperCatchWeld")
	if ball:GetAttribute("VTRGoalkeeperHeld") ~= true then
		if existing then existing:Destroy() end
		keeper:SetAttribute("VTRGoalkeeperHolding", nil)
		keeper:SetAttribute("VTRGoalkeeperHoldingSince", nil)
		return
	end
	local keeperRoot = root(keeper)
	local torso = keeper:FindFirstChild("Torso") :: BasePart?
	local catchPart = torso or keeperRoot
	if not catchPart or (keeperRoot and keeperRoot.Anchored == true) then return end
	if existing then
		if existing:IsA("WeldConstraint") and existing.Part0 == ball and existing.Part1 == catchPart then
			ball.CanCollide = false
			ball.CanTouch = false
			ball.Massless = true
			pcall(function() ball:SetNetworkOwner(nil) end)
			return
		end
		existing:Destroy()
	end
	ball.Anchored = false
	ball.CanCollide = false
	ball.CanTouch = false
	ball.Massless = true
	pcall(function() ball:SetNetworkOwner(nil) end)
	ball.CFrame = CFrame.new(catchPart.Position + catchPart.CFrame.LookVector * 1.05 + Vector3.new(0, 0.18, 0))
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	local weld = Instance.new("WeldConstraint")
	weld.Name = "VTRGoalkeeperCatchWeld"
	weld.Part0 = ball
	weld.Part1 = catchPart
	weld.Parent = ball
end

function Service:_beginAIGoalkeeperDistribution(keeper: Model, side: string?, duration: number?)
	if userControlledKeeper(keeper) then return end
	local teamSide = tostring(side or keeper:GetAttribute("VTRTeam") or "")
	if teamSide ~= "Home" and teamSide ~= "Away" then return end
	local now = os.clock()
	local window = duration or AI_KEEPER_DISTRIBUTION_WINDOW
	if self.AI and self.AI.BeginGoalkeeperDistribution then
		self.AI:BeginGoalkeeperDistribution(keeper, teamSide, window)
	end
	keeper:SetAttribute("VTRNoAutoPassUntil", now + AI_KEEPER_DISTRIBUTION_DELAY)
	keeper:SetAttribute("VTRKeeperMustDistributeUntil", now + window)
	keeper:SetAttribute("AIAssignment", "GoalkeeperDistribution")
end

function Service:_keeperSafety(defendingSide: string)
	local keeper = goalkeeper(self.Teams[defendingSide])
	local keeperRoot = keeper and root(keeper)
	if not keeper or not keeperRoot then return end
	local activeSaveKeeper = self.ActiveSave and self.ActiveSave.Keeper == keeper
	if activeSaveKeeper then return end
	if keeperRoot.Anchored then
		keeperRoot.Anchored = false
		keeperRoot.AssemblyLinearVelocity = Vector3.zero
		keeperRoot.AssemblyAngularVelocity = Vector3.zero
	end
	local attackingSide = self:_scoringSideForDefendedGoal(defendingSide)
	local rectangle = GoalModelResolver.ResolveSide(attackingSide, self.PitchCFrame, self.Width, self.Length)
	local localRoot = self.PitchCFrame:PointToObjectSpace(keeperRoot.Position)
	local userControlled = userControlledKeeper(keeper)
	if keeper:GetAttribute("VTRGoalkeeperHolding") == true and userControlled then
		local keeperSpeed = keeperRoot.AssemblyLinearVelocity.Magnitude
		if localRoot.Y > SAFE_ROOT_HEIGHT + 75 or keeperSpeed > 135 then
			self.BallService:ReleaseGoalkeeperHold(keeper)
			keeper:SetAttribute("VTRGoalkeeperSaving", false)
			keeper:SetAttribute("VTRGoalkeeperState", "Recovered")
			keeperRoot.AssemblyLinearVelocity = Vector3.zero
			keeperRoot.AssemblyAngularVelocity = Vector3.zero
			clampKeeperHoldArea(self, keeper, keeperRoot)
			return
		end
		if localRoot.Y > SAFE_ROOT_HEIGHT + 45 or keeperSpeed > 95 then
			keeperRoot.AssemblyLinearVelocity = Vector3.zero
			keeperRoot.AssemblyAngularVelocity = Vector3.zero
		end
		clampKeeperHoldArea(self, keeper, keeperRoot)
		keeper:SetAttribute("VTRGoalkeeperSaving", false)
		keeper:SetAttribute("VTRGoalkeeperState", "Held")
		secureHeldBall(self.Ball, keeper)
		return
	end
	local unsafeHold = keeper:GetAttribute("VTRGoalkeeperHolding") == true and (localRoot.Y > SAFE_ROOT_HEIGHT + 45 or not inGoalkeeperBox(self, rectangle, keeperRoot.Position) or keeperRoot.AssemblyLinearVelocity.Magnitude > 95)
	if unsafeHold then
		self.BallService:ReleaseGoalkeeperHold(keeper)
		keeper:SetAttribute("VTRGoalkeeperSaving", false)
		keeper:SetAttribute("VTRGoalkeeperState", "Recovered")
		keeper:SetAttribute("AIAssignment", "GoalkeeperPosition")
		keeper:SetAttribute("VTRNoAutoPassUntil", os.clock() + 1.6)
		keeperRoot.AssemblyLinearVelocity = Vector3.zero
		keeperRoot.AssemblyAngularVelocity = Vector3.zero
	elseif keeper:GetAttribute("VTRGoalkeeperHolding") == true then
		secureHeldBall(self.Ball, keeper)
		local now = os.clock()
		local holdingSince = tonumber(keeper:GetAttribute("VTRGoalkeeperHoldingSince")) or now
		local heldFor = now - holdingSince
		local mustDistributeUntil = tonumber(keeper:GetAttribute("VTRKeeperMustDistributeUntil")) or 0
		if heldFor >= 0.9 and (keeper:GetAttribute("AIAssignment") ~= "GoalkeeperDistribution" or mustDistributeUntil <= now) then
			self:_beginAIGoalkeeperDistribution(keeper, defendingSide, AI_KEEPER_DISTRIBUTION_WINDOW)
		end
		if heldFor >= AI_KEEPER_HOLD_FAILSAFE then
			local forward = fieldDirection(rectangle, self.PitchCFrame)
			self.BallService:ReleaseGoalkeeperHold(keeper)
			keeper:SetAttribute("VTRGoalkeeperSaving", false)
			keeper:SetAttribute("VTRGoalkeeperState", "Distributed")
			keeper:SetAttribute("AIAssignment", "GoalkeeperDistribution")
			keeper:SetAttribute("VTRNoAutoPassUntil", nil)
			keeperRoot.AssemblyLinearVelocity = Vector3.zero
			keeperRoot.AssemblyAngularVelocity = Vector3.zero
			self.BallService:Clearance(keeper, forward)
		end
	end
end

function Service:_boxClear(save:any,keeper:Model):boolean
	local rectangle=save.Rectangle
	for _,side in{"Home","Away"}do
		for _,model in self.Teams[side]or{}do
			if model~=keeper then
				local modelRoot=root(model)
				if modelRoot and inGoalkeeperBox(self,rectangle,modelRoot.Position)then
					return false
				end
			end
		end
	end
	return true
end

function Service:_monitorControlledHold(keeper:Model,rectangle:any,defendingSide:string)
	if not userControlledKeeper(keeper) then
		self:_beginAIGoalkeeperDistribution(keeper,defendingSide,AI_KEEPER_DISTRIBUTION_WINDOW)
		return
	end
	task.spawn(function()
		local started=os.clock()
		while keeper.Parent and keeper:GetAttribute("VTRGoalkeeperHolding")==true do
			local keeperRoot=root(keeper)
			if not keeperRoot then return end
			local localRoot = self.PitchCFrame:PointToObjectSpace(keeperRoot.Position)
			if keeperRoot.Anchored then
				keeperRoot.Anchored = false
				keeperRoot.AssemblyLinearVelocity = Vector3.zero
				keeperRoot.AssemblyAngularVelocity = Vector3.zero
				keeper:SetAttribute("VTRGoalkeeperSaving",false)
				keeper:SetAttribute("VTRGoalkeeperState","Held")
			end
			local keeperSpeed = keeperRoot.AssemblyLinearVelocity.Magnitude
			if localRoot.Y > SAFE_ROOT_HEIGHT + 75 or keeperSpeed > 135 then
				self.BallService:ReleaseGoalkeeperHold(keeper)
				keeperRoot.AssemblyLinearVelocity = Vector3.zero
				keeperRoot.AssemblyAngularVelocity = Vector3.zero
				clampKeeperHoldArea(self,keeper,keeperRoot)
				break
			end
			if localRoot.Y > SAFE_ROOT_HEIGHT + 45 or keeperSpeed > 95 then
				keeperRoot.AssemblyLinearVelocity = Vector3.zero
				keeperRoot.AssemblyAngularVelocity = Vector3.zero
				clampKeeperHoldArea(self,keeper,keeperRoot)
			elseif not inGoalkeeperBox(self,rectangle,keeperRoot.Position)then
				clampKeeperHoldArea(self,keeper,keeperRoot)
			end
			secureHeldBall(self.Ball,keeper)
			if os.clock()-started>=7 then
				started = os.clock()
				keeper:SetAttribute("VTRGoalkeeperSaving",false)
				keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+999)
				keeper:SetAttribute("VTRGoalkeeperState","Held")
			end
			task.wait(.1)
		end
	end)
end

local function shotPlanNumber(plan: any, key: string, fallback: number): number
	if type(plan) ~= "table" then return fallback end
	local value = tonumber(plan[key])
	return value ~= nil and value or fallback
end

local function keeperReachRootTarget(rectangle: any, target: Vector3, forward: Vector3, keeperRoot: BasePart): Vector3
	local goalHeight = rectangle.Top - rectangle.Bottom
	local verticalPadding = math.min(3.15, goalHeight * 0.36)
	local widthPadding = math.min(1.35, (rectangle.RightBound - rectangle.Left) * 0.16)
	local rootTarget = target - rectangle.Up * 1.05
	local offset = rootTarget - rectangle.PlanePoint
	local horizontal = offset:Dot(rectangle.Right)
	local vertical = offset:Dot(rectangle.Up)
	local clampedHorizontal = math.clamp(horizontal, rectangle.Left + widthPadding, rectangle.RightBound - widthPadding)
	local clampedVertical = math.clamp(vertical, rectangle.Bottom + verticalPadding, rectangle.Top - verticalPadding)
	rootTarget += rectangle.Right * (clampedHorizontal - horizontal) + rectangle.Up * (clampedVertical - vertical)
	local desiredDepth = (target - rectangle.PlanePoint):Dot(forward)
	local currentDepth = (rootTarget - rectangle.PlanePoint):Dot(forward)
	rootTarget += forward * (desiredDepth - currentDepth)
	local keeperDepth = (keeperRoot.Position - rectangle.PlanePoint):Dot(forward)
	local rootDepth = (rootTarget - rectangle.PlanePoint):Dot(forward)
	return rootTarget + forward * (keeperDepth - rootDepth)
end

local function vtrKeeperShouldStayLow(keeper, keeperRoot, target, shotPlan)
	if keeper and (keeper:GetAttribute("VTRLowShotFlatDive") == true or keeper:GetAttribute("VTRFallingLowShotDive") == true) then
		return true
	end

	if typeof(target) ~= "Vector3" or not keeperRoot then
		return false
	end

	local rootY = keeperRoot.Position.Y
	local targetY = target.Y
	local predictedY = tonumber(keeper and keeper:GetAttribute("VTRLongShotTargetY"))

	if predictedY then
		targetY = math.min(targetY, predictedY)
	end

	if targetY <= rootY + 3.25 then
		return true
	end

	if shotPlan and tonumber(shotPlan.TargetY) and tonumber(shotPlan.TargetY) <= rootY + 3.25 then
		return true
	end

	return false
end

local function physicalSaveDecision(service, keeper, rectangle, target, timeToGoal, shotPlan)
	

	local keeperRootForLow = root(keeper)
	local stayLowDive = vtrKeeperShouldStayLow(keeper, keeperRootForLow, target, shotPlan)
	if stayLowDive then
		keeper:SetAttribute("VTRLowShotFlatDive", true)
		keeper:SetAttribute("VTRKeeperNoJumpDive", true)
	end
local predictedX = tonumber(keeper:GetAttribute("VTRLongShotTargetX"))
	local predictedY = tonumber(keeper:GetAttribute("VTRLongShotTargetY"))
	local predictedZ = tonumber(keeper:GetAttribute("VTRLongShotTargetZ"))
	if predictedX and predictedY and os.clock() < (tonumber(keeper:GetAttribute("VTRLongShotUntil")) or 0) then
		target = Vector3.new(predictedX, predictedY, predictedZ or target.Z)
	end
	local keeperRoot = root(keeper)
	if not keeperRoot then
		return {WillSave = false, SavePercent = 0, Source = "NoKeeperRoot"}
	end
	local forward = fieldDirection(rectangle, service.PitchCFrame)
	local upAxis = service.PitchCFrame.UpVector
	local rootTarget = keeperReachRootTarget(rectangle, target, forward, keeperRoot)
	local delta = rootTarget - keeperRoot.Position
	local lateral = math.abs(delta:Dot(rectangle.Right))
	local rise = math.max(0, delta:Dot(upAxis))
	local rating = keeperRating(keeper)
	local reflexes = tonumber(keeper:GetAttribute("gkReflexes")) or tonumber(keeper:GetAttribute("GKREF")) or rating
	local diving = tonumber(keeper:GetAttribute("gkDiving")) or tonumber(keeper:GetAttribute("GKDIV")) or rating
	local handling = boostedKeeperStat(keeper, "gkHandling", "GKHAN", rating)
	local shotSpeed = shotPlanNumber(shotPlan, "Speed", service.Ball.AssemblyLinearVelocity.Magnitude)
	local shotCharge = shotPlanNumber(shotPlan, "Charge", 0.68)
	local fullPower = math.clamp((shotCharge - 0.74) / 0.26, 0, 1)
	local powerQuality = shotPlanNumber(shotPlan, "PowerQuality", 0.72)
	local reactionQuickness = math.clamp(tonumber(keeper:GetAttribute("VTRPracticeKeeperReaction")) or 1, 0.05, 2.2)
	local diveScale = math.clamp(tonumber(keeper:GetAttribute("VTRPracticeKeeperDiveSpeed")) or 1, 0.05, 2.2)
	local reachScale = math.clamp(tonumber(keeper:GetAttribute("VTRPracticeKeeperReach")) or 1, 0.05, 2.2)
	local handlingScale = math.clamp(tonumber(keeper:GetAttribute("VTRPracticeKeeperHandling")) or 1, 0.05, 2.2)
	local saveBias = math.clamp(tonumber(keeper:GetAttribute("VTRPracticeKeeperSaveBias")) or 1, 0.05, 2.2)
	local reaction = math.clamp(0.11 / reactionQuickness, 0.02, 0.9)
	local lateralDelta = delta:Dot(rectangle.Right)
	local lateralVelocity = keeperRoot.AssemblyLinearVelocity:Dot(rectangle.Right)
	local wrongFooted = math.abs(lateralDelta) > 2.5 and lateralVelocity * lateralDelta < -4
	if wrongFooted then
		reaction += 0.18
	end
	local available = math.max(0, timeToGoal - reaction - DIVE_LEAD_TIME)
	local diveSpeed = reflexDiveSpeed(math.max(diving, reflexes)) * diveScale
	local ballRadius = service.Ball.Size.X * 0.5
	local keeperReach = math.clamp((5.7 + (handling - 60) * 0.018) * handlingScale * reachScale * math.clamp(saveBias, 0.65, 1.35), 3, 14)
	local distanceToCover = Vector2.new(lateral, rise).Magnitude
	local canReach = distanceToCover <= keeperReach + ballRadius and distanceToCover <= diveSpeed * available + ballRadius
	local required = distanceToCover / math.max(1, diveSpeed)
	local saveMargin = math.min(keeperReach + ballRadius - distanceToCover, diveSpeed * available + ballRadius - distanceToCover)
	return {
		WillSave = canReach,
		SavePercent = math.clamp(50 + saveMargin * 12, 0, 100),
		Source = canReach and "ReachHitboxPlanned" or (wrongFooted and "WrongFooted" or "OutOfReach"),
		RootTarget = rootTarget,
		Reaction = reaction,
		Required = required,
		Available = available,
		WrongFooted = wrongFooted,
		DiveSpeed = diveSpeed,
		ReachHitbox = keeperReach,
		ContactRadius = ballRadius + 1.2,
	}
end

function Service.new(ball: BasePart, teams: any, pitchCFrame: CFrame, width: number, length: number, ballService: any, animations: any, remote: RemoteEvent,aiService:any?)
	local self=setmetatable({
		Ball = ball,
		Teams = teams,
		PitchCFrame = pitchCFrame,
		Width = width,
		Length = length,
		BallService = ballService,
		Animations = animations,
		Remote = remote,
		ObservedShot = 0,
		ActiveSave = nil,
		MissedShots = {},
		LineFacing = {},
		GoalChanceBank = {},
		Random = Random.new(),
		AI=aiService,
		Half=1,
	}, Service)
	for _,side in{"Home","Away"}do local keeper=goalkeeper(teams[side]);if keeper then keeper:SetAttribute("VTRGoalkeeperLineManaged",true)end end
	return self
end



function Service:_vtrFallingShotPointAtKeeper(keeperRoot: BasePart): Vector3?
	local ball = self.Ball
	if not ball or not ball.Parent then
		return nil
	end

	local velocity = ball.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if flatVelocity.Magnitude < 8 then
		return nil
	end

	local toKeeper = keeperRoot.Position - ball.Position
	local flatToKeeper = Vector3.new(toKeeper.X, 0, toKeeper.Z)
	local along = flatToKeeper:Dot(flatVelocity.Unit)
	if along < -3 or along > 40 then
		return nil
	end

	local time = math.clamp(along / math.max(flatVelocity.Magnitude, 1), 0, 1.15)
	local y = ball.Position.Y + velocity.Y * time - 0.5 * workspace.Gravity * time * time
	local x = ball.Position.X + velocity.X * time
	local z = ball.Position.Z + velocity.Z * time

	return Vector3.new(x, y, z)
end

function Service:_vtrAdjustDiveFallToTrajectory(save: any, dt: number)
	if not save or not save.Keeper then
		return
	end

	local keeper = save.Keeper
	local keeperRoot = root(keeper)
	if not keeperRoot then
		return
	end

	local predicted = self:_vtrFallingShotPointAtKeeper(keeperRoot)
	if not predicted then
		return
	end

	local belowKeeper = predicted.Y <= keeperRoot.Position.Y + 2.75
	local ballDropping = self.Ball.AssemblyLinearVelocity.Y <= 2
	local ballClose = (Vector3.new(self.Ball.Position.X, 0, self.Ball.Position.Z) - Vector3.new(keeperRoot.Position.X, 0, keeperRoot.Position.Z)).Magnitude <= 30

	if not belowKeeper or not ballDropping or not ballClose then
		return
	end

	keeper:SetAttribute("VTRLowShotFlatDive", true)
	keeper:SetAttribute("VTRFallingLowShotDive", true)
	keeper:SetAttribute("VTRKeeperNoJumpDive", true)
	save.LowDive = true
	save.NoJump = true
	save.Target = predicted
	save.SavePoint = predicted

	local lateral = predicted.X - keeperRoot.Position.X
	local downward = math.clamp((keeperRoot.Position.Y + 2.75 - predicted.Y) * 18, 18, 62)
	local lateralVelocity = math.clamp(lateral * 10, -42, 42)
	local current = keeperRoot.AssemblyLinearVelocity

	keeperRoot.AssemblyLinearVelocity = Vector3.new(lateralVelocity, -downward, current.Z * 0.12)

	keeper:SetAttribute("VTRKeeperLowDiveSwitched", true)
end


function Service:_vtrStepRollingLowDiveSwitch()
	local ball = self.Ball
	if not ball or not ball.Parent then
		return
	end

	local velocity = ball.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if flatSpeed < 10 then
		return
	end

	for _, side in {"Home", "Away"} do
		local keeper = self.Teams and self.Teams[side] and goalkeeper(self.Teams[side])
		local keeperRoot = keeper and root(keeper)
		if keeper and keeperRoot and (keeper:GetAttribute("VTRGoalkeeperSaving") == true or keeper:GetAttribute("VTRGoalkeeperState") == "Diving" or keeper:GetAttribute("VTRKeeperDiveAnimationLocked") == true) then
			local ballBelowDive = ball.Position.Y <= keeperRoot.Position.Y + 2.85
			local rollingOrDropping = math.abs(velocity.Y) <= 8 or velocity.Y < -2
			local closeEnough = (Vector3.new(ball.Position.X, 0, ball.Position.Z) - Vector3.new(keeperRoot.Position.X, 0, keeperRoot.Position.Z)).Magnitude <= 28

			if ballBelowDive and rollingOrDropping and closeEnough then
				keeper:SetAttribute("VTRLowShotFlatDive", true)
				keeper:SetAttribute("VTRFallingLowShotDive", true)
				keeper:SetAttribute("VTRKeeperNoJumpDive", true)
				keeper:SetAttribute("VTRKeeperDiveAnimationLocked", nil)
				keeper:SetAttribute("VTRGoalkeeperState", "Diving")

				local lateral = ball.Position.X - keeperRoot.Position.X
				local animationName = "GoalkeeperDive"
				if lateral < -0.75 then
					animationName = "GoalkeeperDiveLowLeft"
				elseif lateral > 0.75 then
					animationName = "GoalkeeperDiveLowRight"
				end

				if self.Animations then
					self:_vtrPlayTemporaryDiveAnimation(keeper, animationName, 1.0)
				end

				local current = keeperRoot.AssemblyLinearVelocity
				local lateralVelocity = math.clamp(lateral * 8, -36, 36)
				keeperRoot.AssemblyLinearVelocity = Vector3.new(lateralVelocity, math.min(current.Y, 0), current.Z * 0.2)
			end
		end
	end
end


function Service:SetHalf(half:number?)
	local nextHalf=half or 1
	if self.Half~=nextHalf then
		self:Reset()
	end
	self.Half=nextHalf
end

function Service:_scoringSideForDefendedGoal(defendingSide:string):string
	if (self.Half or 1)>=2 then
		return defendingSide
	end
	return defendingSide=="Home"and"Away"or"Home"
end

function Service:_physicalScoringSide(attackingSide:string):string
	if (self.Half or 1)>=2 then
		return attackingSide=="Home"and"Away"or"Home"
	end
	return attackingSide
end

function Service:_prediction(attackingSide: string,gravityOverride:number?): (any?, Vector3?, number?)
	local rectangle = GoalModelResolver.ResolveSide(self:_physicalScoringSide(attackingSide), self.PitchCFrame, self.Width, self.Length)
	local position = self.Ball.Position
	local velocity = self.Ball.AssemblyLinearVelocity
	local forward=fieldDirection(rectangle,self.PitchCFrame)
	local lineOffset=saveLineOffset(rectangle,self.Ball.Size.X*.5)
	local linePoint=rectangle.PlanePoint+forward*lineOffset
	local towardSpeed=velocity:Dot(forward)
	if towardSpeed>=-.05 then return nil,nil,nil end
	local time=(linePoint-position):Dot(forward)/towardSpeed
	if time <= 0 or time > 3.5 then return nil, nil, nil end
	local shotPlan=self.BallService.ShotPlan
	local planGravity=shotPlan and tonumber(shotPlan.EffectiveGravity)or nil
	local gravity=typeof(gravityOverride)=="number"and gravityOverride or planGravity or workspace.Gravity
	local target=position+velocity*time-self.PitchCFrame.UpVector*(.5*gravity*time*time)
	local goalPlaneTarget=target-forward*lineOffset
	if not insideGoal(rectangle,goalPlaneTarget,self.Ball.Size.X*.5)then return nil,nil,nil end
	local clamped=GoalModelResolver.ClampPoint(rectangle,goalPlaneTarget)+forward*lineOffset
	self.Ball:SetAttribute("VTRPredictedGoalImpact",clamped)
	self.Ball:SetAttribute("VTRPredictedGoalImpactTime",time)
	return rectangle,clamped,time
end

function Service:_begin(attackingSide: string, shotId: number)
	local defendingSide = attackingSide == "Home" and "Away" or "Home"
	local keeper = goalkeeper(self.Teams[defendingSide])
	local rectangle, target, time = self:_prediction(attackingSide)
	if not keeper or not rectangle or not target or not time then return end
	local shotPlan=self.BallService and self.BallService.ShotPlan
	local penaltySlot=shotPlan and shotPlan.PenaltySlot
	local keeperGuess=keeper:GetAttribute("VTRPenaltyGuessSlot")
	local penaltyDuel=type(penaltySlot)=="string"and penaltySlot~=""and type(keeperGuess)=="string"and keeperGuess~=""
	local evaluation=physicalSaveDecision(self,keeper,rectangle,target,time,shotPlan)
	local willSave=evaluation.WillSave==true
	if penaltyDuel then
		willSave=keeperGuess==penaltySlot
		keeper:SetAttribute("VTRLastSaveChance",willSave and 100 or 0)
	else
		keeper:SetAttribute("VTRLastSaveChance",math.floor((evaluation.SavePercent or 0)+.5))
	end
	if willSave == false then
		VTRGoalPassThrough.Force(self.Ball, 2.75)
	end
	keeper:SetAttribute("VTRGoalkeeperSaving", true)
	keeper:SetAttribute("VTRSaveTarget", target)
	keeper:SetAttribute("VTRGoalkeeperState", "Tracking")
	keeper:SetAttribute("VTRShotWillScore", not willSave)
	keeper:SetAttribute("VTRShotOutcomeSource", penaltyDuel and "PenaltyRead" or evaluation.Source or "PhysicalReach")
	self.Ball:SetAttribute("VTRGoalkeeperTracking", keeper.Name)
	local keeperRoot = root(keeper)
	local humanoid = keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.AutoRotate = false end
	local practiceDiveScale=math.clamp(tonumber(keeper:GetAttribute("VTRPracticeKeeperDiveSpeed"))or 1,.05,2.2)
	local missSeverity=willSave and 0 or math.clamp((tonumber(evaluation.Required)or 0)-(tonumber(evaluation.Available)or 0),.08,1.8)
	local missDelay=willSave and 0 or math.clamp(.2+missSeverity*.42,.2,.95)
	local baseDiveLead=DIVE_LEAD_TIME
	local baseLaunchAllowance=0.12
	if not willSave then
		baseDiveLead=math.max(.05,baseDiveLead-missDelay*.52)
		baseLaunchAllowance=math.max(.004,baseLaunchAllowance*.38)
	end
	self.ActiveSave = {
		ShotId = shotId,
		AttackingSide = attackingSide,
		DefendingSide = defendingSide,
		Keeper = keeper,
		Rectangle = rectangle,
		Target = target,
		LockedTarget = target,
		PlannedRootTarget = evaluation.RootTarget,
		PenaltyDiveTarget = nil,
		WillSave = willSave,
		DivePlayed = false,
		StartY = keeperRoot and keeperRoot.Position.Y or self.PitchCFrame.Position.Y + 3,
		Launched = false,
		DiveLeadTime = baseDiveLead,
		LaunchAllowance = baseLaunchAllowance,
		ReactionDelay = math.max(0,tonumber(evaluation.Reaction)or 0),
		ReactionReadyAt = shotId + math.max(0,tonumber(evaluation.Reaction)or 0),
		MissSeverity = missSeverity,
		MissDelay = missDelay,
		MissReachRatio = willSave and 1 or math.clamp(.9-missSeverity*.34,.42,.82),
		MissOffsetSign = self.Random:NextNumber()<.5 and-1 or 1,
		EffectiveGravity=(self.BallService.ShotPlan and tonumber(self.BallService.ShotPlan.EffectiveGravity))or workspace.Gravity,
		ReachEvaluation=evaluation,
		Ball=self.Ball,
		DiveSpeed=tonumber(evaluation.DiveSpeed)or DEFAULT_DIVE_SPEED,
		ReachHitbox=tonumber(evaluation.ReachHitbox)or 5.7,
		ContactRadius=tonumber(evaluation.ContactRadius)or (self.Ball.Size.X*.5+1.2),
	}
	if penaltyDuel then
		local guessPoint=keeper:GetAttribute("VTRPenaltyGuessPoint")
		if typeof(guessPoint)=="Vector3" then target=guessPoint end
		if typeof(guessPoint)=="Vector3"then self.ActiveSave.PenaltyDiveTarget=guessPoint end
	end
end

function Service:_miss(save:any)
	if save and save.Keeper then self:_vtrStopLowDiveOverride(save.Keeper) end
	local keeper:Model=save.Keeper
	if save.Launched and save.Rectangle and save.Target then
		if save.AftermathStarted then return end
		save.Finished=true
		save.FinishTime=os.clock()
		keeper:SetAttribute("VTRGoalkeeperSaving",true)
		keeper:SetAttribute("VTRSaveTarget",nil)
		keeper:SetAttribute("VTRGoalkeeperState","Beaten")
		keeper:SetAttribute("VTRShotWillScore",nil)
		keeper:SetAttribute("VTRShotOutcomeSource",nil)
		keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.2)
		self.Ball:SetAttribute("VTRGoalkeeperTracking",nil)
		self.Remote:FireAllClients({Type="GoalkeeperMiss",Model=keeper,Name=keeper:GetAttribute("DisplayName")})
		self:_continueDiveAftermath(save,"Miss",false)
		return
	end
	local keeperRoot=root(keeper)
	if keeperRoot then
		local localRoot=self.PitchCFrame:PointToObjectSpace(keeperRoot.Position)
		if localRoot.Y<SAFE_ROOT_HEIGHT then keeperRoot.CFrame=keeperRoot.CFrame+self.PitchCFrame.UpVector*(SAFE_ROOT_HEIGHT-localRoot.Y)end
		keeperRoot.AssemblyLinearVelocity=Vector3.zero
		keeperRoot.AssemblyAngularVelocity=Vector3.zero
		keeperRoot.Anchored=false
	end
	if save.DiveAlign then save.DiveAlign:Destroy();save.DiveAlign=nil end
	if save.DiveVelocity then save.DiveVelocity:Destroy();save.DiveVelocity=nil end
	if save.DiveAttachment then save.DiveAttachment:Destroy();save.DiveAttachment=nil end
	clearKeeperDivePose(keeper)
	keeper:SetAttribute("VTRKeeperDiveAnimationLocked",nil)
	local humanoid=keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand=false
		humanoid.AutoRotate=true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	local facing=self.LineFacing[keeper];if facing then facing.Align.Enabled=true end
	keeper:SetAttribute("VTRGoalkeeperSaving",false)
	keeper:SetAttribute("VTRSaveTarget",nil)
	keeper:SetAttribute("VTRGoalkeeperState","Beaten")
	keeper:SetAttribute("VTRShotWillScore",nil)
	keeper:SetAttribute("VTRShotOutcomeSource",nil)
	keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.2)
	self.Ball:SetAttribute("VTRGoalkeeperTracking",nil)
	self.Animations:StopAction(keeper,.12)
	self.Remote:FireAllClients({Type="GoalkeeperMiss",Model=keeper,Name=keeper:GetAttribute("DisplayName")})
	self.ActiveSave=nil
end

function Service:_finish(save: any)
	if save and save.Keeper then self:_vtrStopLowDiveOverride(save.Keeper) end
	if save and save.WillSave==false then
		self:_miss(save)
		return
	end
	if save.AftermathStarted then return end
	save.Saved=true
	save.Finished=true
	save.FinishTime=os.clock()
	local keeper: Model = save.Keeper
	local keeperRoot = root(keeper)
	if not keeperRoot then self.ActiveSave = nil return end
	local localRoot=self.PitchCFrame:PointToObjectSpace(keeperRoot.Position);if localRoot.Y<SAFE_ROOT_HEIGHT then keeperRoot.CFrame=keeperRoot.CFrame+self.PitchCFrame.UpVector*(SAFE_ROOT_HEIGHT-localRoot.Y)end
	keeperRoot.Anchored=true
	if save.DiveAlign then save.DiveAlign:Destroy();save.DiveAlign=nil end
	if save.DiveVelocity then save.DiveVelocity:Destroy();save.DiveVelocity=nil end
	if save.DiveAttachment then save.DiveAttachment:Destroy();save.DiveAttachment=nil end
	keeperRoot.AssemblyLinearVelocity=Vector3.zero;keeperRoot.AssemblyAngularVelocity=Vector3.zero
	self.BallService:GoalkeeperSave(keeper, save.Target)
	local parriedSave = self.Ball:GetAttribute("VTRGoalkeeperHeld") ~= true
	self.Ball:SetAttribute("VTRPenaltyShotActive",nil)
	self.BallService.Stats:RecordSave(keeper,self.BallService.LastShotXG)
	if self.BallService.LastShooter and(self.BallService.LastShotXG or 0)>=.3 then self.BallService.Stats:Event(self.BallService.LastShooter,"BigChanceMissed")end
	keeper:SetAttribute("VTRSaveTarget", nil)
	keeper:SetAttribute("VTRGoalkeeperState", "Saved")
	keeper:SetAttribute("VTRShotWillScore",nil)
	keeper:SetAttribute("VTRShotOutcomeSource",nil)
	self.Ball:SetAttribute("VTRGoalkeeperTracking", nil)
	keeper:SetAttribute("VTRNoAutoPassUntil", os.clock() + (userControlledKeeper(keeper) and 999 or 1))
	self.Remote:FireAllClients({Type = "GoalkeeperSave", Model = keeper, Name = keeper:GetAttribute("DisplayName")})
	self:_continueDiveAftermath(save,parriedSave and"Parried"or"Held",parriedSave)
end

local function boundedRootTarget(rectangle:any,target:Vector3,forward:Vector3):(Vector3,number,number)
	local goalHeight=rectangle.Top-rectangle.Bottom
	local verticalPadding=math.min(3.15,goalHeight*.36)
	local widthPadding=math.min(1.35,(rectangle.RightBound-rectangle.Left)*.16)
	local targetOffset=target-rectangle.PlanePoint
	local targetHeight=targetOffset:Dot(rectangle.Up)
	local heightRatio=math.clamp((targetHeight-rectangle.Bottom)/math.max(.1,goalHeight),0,1)
	local handReach=1.78-heightRatio*.42
	local rootTarget=target-rectangle.Up*handReach
	local offset=rootTarget-rectangle.PlanePoint
	local horizontal=offset:Dot(rectangle.Right)
	local vertical=offset:Dot(rectangle.Up)
	local clampedHorizontal=math.clamp(horizontal,rectangle.Left+widthPadding,rectangle.RightBound-widthPadding)
	local clampedVertical=math.clamp(vertical,rectangle.Bottom+verticalPadding,rectangle.Top-verticalPadding)
	rootTarget+=rectangle.Right*(clampedHorizontal-horizontal)+rectangle.Up*(clampedVertical-vertical)
	return rootTarget,widthPadding,verticalPadding
end

local function missedRootTarget(save:any,keeperRoot:BasePart,rootTarget:Vector3,rectangle:any,lateralAxis:Vector3,upAxis:Vector3,forward:Vector3):Vector3
	if save.MissRootTarget then return save.MissRootTarget end
	local severity=math.clamp(tonumber(save.MissSeverity)or .4,.08,1.8)
	local reach=math.clamp(tonumber(save.MissReachRatio)or .72,.35,.88)
	local start=keeperRoot.Position
	local miss=start:Lerp(rootTarget,reach)
	local actualLateral=(rootTarget-start):Dot(lateralAxis)
	local sideSign=if actualLateral>=0 then 1 else -1
	local sideNudge=lateralAxis*(sideSign*math.clamp(math.abs(actualLateral)*.08+severity*.28,0,.9))
	if save.CenteredDive then
		sideNudge=Vector3.zero
	end
	local lowNudge=-upAxis*math.clamp(.35+severity*.55,.35,1.45)
	miss+=sideNudge+lowNudge
	local keeperDepth=(keeperRoot.Position-rectangle.PlanePoint):Dot(forward)
	local missDepth=(miss-rectangle.PlanePoint):Dot(forward)
	miss+=forward*(keeperDepth-missDepth)
	local vertical=(miss-rectangle.PlanePoint):Dot(upAxis)
	local minimum=rectangle.Bottom+0.65
	if vertical<minimum then miss+=upAxis*(minimum-vertical)end
	save.MissRootTarget=miss
	save.MissAim=miss+upAxis*1.05
	return miss
end

function Service:_faceBall(keeper:Model,rectangle:any)
	local keeperRoot=root(keeper);if not keeperRoot then return end
	local state=self.LineFacing[keeper]
	if not state then
		local attachment=Instance.new("Attachment");attachment.Name="VTRKeeperFacingAttachment";attachment.Parent=keeperRoot
		local align=Instance.new("AlignOrientation");align.Name="VTRKeeperFacing";align.Mode=Enum.OrientationAlignmentMode.OneAttachment;align.Attachment0=attachment;align.MaxTorque=350000;align.MaxAngularVelocity=12;align.Responsiveness=14;align.RigidityEnabled=false;align.Parent=keeperRoot
		state={Attachment=attachment,Align=align};self.LineFacing[keeper]=state
	end
	local baseForward=fieldDirection(rectangle,self.PitchCFrame)
	state.Align.CFrame=CFrame.lookAt(Vector3.zero,baseForward,rectangle.Up).Rotation
	state.Align.Enabled=true
end

function Service:_positionOnLine(defendingSide:string)
	local keeper=goalkeeper(self.Teams[defendingSide]);if not keeper or keeper:GetAttribute("VTRGoalkeeperSaving")==true or keeper:GetAttribute("controlledByUser")==true or self.BallService.Possession:GetOwner()==keeper then return end
	local keeperRoot=root(keeper)
	if not keeperRoot then return end

	local attackingSide=self:_scoringSideForDefendedGoal(defendingSide)
	local rectangle=GoalModelResolver.ResolveSide(attackingSide,self.PitchCFrame,self.Width,self.Length)
	local width=rectangle.RightBound-rectangle.Left
	local center=(rectangle.Left+rectangle.RightBound)*.5
	local owner=self.BallService.Possession:GetOwner()
	local ownerRoot=owner and root(owner)
	local opposingCarrier=owner and ownerRoot and owner:GetAttribute("VTRTeam")~=defendingSide
	local carrierDistance=opposingCarrier and (ownerRoot.Position-keeperRoot.Position).Magnitude or math.huge
	local pressureAlpha=opposingCarrier and math.clamp((KEEPER_LATERAL_REACT_DISTANCE-carrierDistance)/KEEPER_LATERAL_REACT_DISTANCE,0,1) or 0
	local ballOffset=self.Ball.Position-rectangle.PlanePoint
	local ballHorizontal=ballOffset:Dot(rectangle.Right)
	local currentOffset=keeperRoot.Position-rectangle.PlanePoint
	local currentHorizontal=currentOffset:Dot(rectangle.Right)
	local targetHorizontal=currentHorizontal

	if opposingCarrier and carrierDistance <= KEEPER_LATERAL_REACT_DISTANCE then
		targetHorizontal=center+(ballHorizontal-center)*(.32+.42*pressureAlpha)
	elseif not opposingCarrier then
		targetHorizontal=center+(ballHorizontal-center)*.34
	end

	targetHorizontal=math.clamp(targetHorizontal,rectangle.Left+width*.08,rectangle.RightBound-width*.08)

	local forward=fieldDirection(rectangle,self.PitchCFrame)
	local height=rectangle.Bottom+math.min(2.75,(rectangle.Top-rectangle.Bottom)*.42)
	local lineDepth=saveLineOffset(rectangle,self.Ball.Size.X*.5)+1.1
	local boxEdgeDepth=132
	local targetDepth=lineDepth

	if opposingCarrier and carrierDistance <= KEEPER_LATERAL_REACT_DISTANCE then
		targetDepth=lineDepth+(boxEdgeDepth-lineDepth)*pressureAlpha
	elseif not opposingCarrier and owner and owner:GetAttribute("VTRTeam")==defendingSide and ownerRoot then
		local ownerPitch=PitchConfig.WorldToTeamPitchPosition(ownerRoot.Position,defendingSide,{PitchCFrame=self.PitchCFrame,Width=self.Width,Length=self.Length})
		if ownerPitch and ownerPitch.Z>PitchConfig.PITCH_LENGTH*.5 then
			local advance=math.clamp((ownerPitch.Z-PitchConfig.PITCH_LENGTH*.5)/(PitchConfig.PITCH_LENGTH*.5),0,1)
			targetDepth=lineDepth+(boxEdgeDepth-lineDepth)*advance
		end
	end

	local target=GoalModelResolver.Point(rectangle,targetHorizontal,height)+forward*targetDepth
	local humanoid=keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self:_faceBall(keeper,rectangle)
		humanoid.AutoRotate=false
		local flatTarget=Vector3.new(target.X,keeperRoot.Position.Y,target.Z)
		local distanceToMove=(Vector3.new(flatTarget.X,0,flatTarget.Z)-Vector3.new(keeperRoot.Position.X,0,keeperRoot.Position.Z)).Magnitude

		if opposingCarrier and carrierDistance > KEEPER_LATERAL_REACT_DISTANCE then
			humanoid.WalkSpeed=0
			humanoid:Move(Vector3.zero,false)
			keeper:SetAttribute("VTRGoalLineTarget",Vector3.new(keeperRoot.Position.X,keeperRoot.Position.Y,keeperRoot.Position.Z))
			keeper:SetAttribute("VTRKeeperPositionHold",true)
			keeper:SetAttribute("VTRKeeperCarrierDistance",math.floor(carrierDistance+.5))
			keeper:SetAttribute("VTRKeeperPositionPressure",0)
			return
		end

		local maxSpeed=opposingCarrier and (7+pressureAlpha*8) or 11
		if distanceToMove < .75 then
			humanoid:Move(Vector3.zero,false)
		else
			humanoid.WalkSpeed=math.max(humanoid.WalkSpeed,maxSpeed)
			humanoid:MoveTo(flatTarget)
		end

		keeper:SetAttribute("VTRGoalLineTarget",flatTarget)
		keeper:SetAttribute("VTRKeeperPositionHold",nil)
		keeper:SetAttribute("VTRKeeperCarrierDistance",carrierDistance<math.huge and math.floor(carrierDistance+.5) or nil)
		keeper:SetAttribute("VTRKeeperPositionPressure",pressureAlpha)
	end
end

function Service:_rushCloseCarrier(defendingSide:string): boolean
	local keeper=goalkeeper(self.Teams[defendingSide])
	local keeperRoot=keeper and root(keeper)
	if not keeper or not keeperRoot or keeper:GetAttribute("VTRGoalkeeperSaving")==true or self.BallService.Possession:GetOwner()==keeper then return false end
	local carrier=self.BallService.Possession:GetOwner()
	local carrierRoot=carrier and root(carrier)
	if not carrier or not carrierRoot or carrier:GetAttribute("VTRTeam")==defendingSide then return false end
	local attackingSide=self:_scoringSideForDefendedGoal(defendingSide)
	local rectangle=GoalModelResolver.ResolveSide(attackingSide,self.PitchCFrame,self.Width,self.Length)
	local goalCenter=GoalModelResolver.Point(rectangle,(rectangle.Left+rectangle.RightBound)*.5,rectangle.Bottom+2.6)
	local carrierGoalDistance=Vector3.new(carrierRoot.Position.X-goalCenter.X,0,carrierRoot.Position.Z-goalCenter.Z).Magnitude
	if keeperDistance>KEEPER_LATERAL_REACT_DISTANCE or carrierGoalDistance>50 then return false end
	local keeperDistance=(keeperRoot.Position-carrierRoot.Position).Magnitude
	local humanoid=keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self:_faceBall(keeper,rectangle)
		humanoid.AutoRotate=false
		local closeIn=math.clamp((50-keeperDistance)/50,0,1)
		humanoid.WalkSpeed=math.max(humanoid.WalkSpeed,10+closeIn*7)
		humanoid:MoveTo(Vector3.new(carrierRoot.Position.X,keeperRoot.Position.Y,carrierRoot.Position.Z))
		keeper:SetAttribute("VTRGoalkeeperState","ClosingDown")
		return true
	end
	return false
end

function Service:_interceptGoalBoundPass(defendingSide:string): boolean
	if VTRGoalPassThrough.ShouldBypass(VTRGoalPassThrough.ResolveBall(self, defendingSide) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall)) then
		VTRGoalPassThrough.Force(VTRGoalPassThrough.ResolveBall(self, defendingSide) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 1.35)
		return false
	end
	if self.BallService.MotionKind~="Pass" then return false end
	local keeper=goalkeeper(self.Teams[defendingSide])
	local keeperRoot=keeper and root(keeper)
	if not keeper or not keeperRoot or keeper:GetAttribute("VTRGoalkeeperSaving")==true or self.BallService.Possession:GetOwner()==keeper then return false end
	local attackingSide=self:_scoringSideForDefendedGoal(defendingSide)
	local rectangle=GoalModelResolver.ResolveSide(attackingSide,self.PitchCFrame,self.Width,self.Length)
	local forward=fieldDirection(rectangle,self.PitchCFrame)
	local velocity=self.Ball.AssemblyLinearVelocity
	local towardSpeed=velocity:Dot(forward)
	if towardSpeed>=-1 then return false end
	local linePoint=rectangle.PlanePoint+forward*saveLineOffset(rectangle,self.Ball.Size.X*.5)
	local time=(linePoint-self.Ball.Position):Dot(forward)/towardSpeed
	if time<=0 or time>2.6 then return false end
	local projected=self.Ball.Position+velocity*time
	local goalPlaneTarget=projected-forward*saveLineOffset(rectangle,self.Ball.Size.X*.5)
	local offset=goalPlaneTarget-rectangle.PlanePoint
	local horizontal=offset:Dot(rectangle.Right)
	local vertical=offset:Dot(rectangle.Up)
	local danger=horizontal>=rectangle.Left-9 and horizontal<=rectangle.RightBound+9 and vertical>=rectangle.Bottom-.5 and vertical<=rectangle.Top+4
	local passTarget=self.Ball:GetAttribute("VTRPassTarget")
	if not danger and typeof(passTarget)=="Vector3"then
		local targetOffset=(passTarget::Vector3)-rectangle.PlanePoint
		local targetDepth=targetOffset:Dot(forward)
		local targetHorizontal=targetOffset:Dot(rectangle.Right)
		danger=targetDepth<=38 and targetHorizontal>=rectangle.Left-13 and targetHorizontal<=rectangle.RightBound+13
	end
	if not danger then return false end
	local humanoid=keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local target=Vector3.new(projected.X,keeperRoot.Position.Y,projected.Z)
		self:_faceBall(keeper,rectangle)
		humanoid.AutoRotate=false
		humanoid.WalkSpeed=math.max(humanoid.WalkSpeed,17)
		humanoid:MoveTo(target)
		keeper:SetAttribute("VTRGoalkeeperState","CuttingPass")
		return true
	end
	return false
end

local function orientDive(save:any,rectangle:any,keeperRoot:BasePart,rootTarget:Vector3,lateralAxis:Vector3,upAxis:Vector3,forward:Vector3)
	local delta=rootTarget-keeperRoot.Position
	local lateral=delta:Dot(lateralAxis)
	local vertical=math.max(.35,delta:Dot(upAxis))
	local diveDirection=(lateralAxis*lateral+upAxis*vertical).Unit
	local back=-forward
	local right=diveDirection:Cross(back)
	if right.Magnitude<.01 then right=rectangle.Right else right=right.Unit end
	local attachment=Instance.new("Attachment");attachment.Name="VTRKeeperDiveAttachment";attachment.Parent=keeperRoot
	local align=Instance.new("AlignOrientation");align.Name="VTRKeeperDiveOrientation";align.Mode=Enum.OrientationAlignmentMode.OneAttachment;align.Attachment0=attachment;align.MaxTorque=10000000;align.MaxAngularVelocity=60;align.Responsiveness=40;align.RigidityEnabled=false;align.CFrame=CFrame.fromMatrix(Vector3.zero,right,diveDirection,back).Rotation;align.Parent=keeperRoot
	save.DiveAttachment=attachment;save.DiveAlign=align
end

local function diveCatchFrame(position:Vector3,lookVector:Vector3,upAxis:Vector3,fallbackForward:Vector3):CFrame
	if VTRGoalPassThrough.ShouldBypass(VTRGoalPassThrough.ResolveBall(position, lookVector, upAxis, fallbackForward) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall)) then
		VTRGoalPassThrough.Force(VTRGoalPassThrough.ResolveBall(position, lookVector, upAxis, fallbackForward) or ball or Ball or currentBall or matchBall or shotBall or self and (self.Ball or self.ball or self.BallPart or self.ballPart or self.CurrentBall or self.currentBall or self.MatchBall or self.matchBall), 1.35)
	end
	local forward=fallbackForward.Magnitude>.05 and fallbackForward.Unit or Vector3.zAxis
	local aim=lookVector.Magnitude>.05 and lookVector.Unit or forward
	local lateral=aim-forward*aim:Dot(forward)-upAxis*aim:Dot(upAxis)
	local lift=math.abs(aim:Dot(upAxis))
	if lateral.Magnitude<.35 and lift>.55 then
		local bodyLook=forward-upAxis*forward:Dot(upAxis)
		bodyLook=bodyLook.Magnitude>.05 and bodyLook.Unit or forward
		return CFrame.lookAt(position,position+bodyLook,upAxis)
	end
	if lateral.Magnitude<.05 then
		lateral=upAxis:Cross(forward)
	end
	if lateral.Magnitude<.05 then
		lateral=Vector3.xAxis
	end
	local lateralDirection=lateral.Unit
	local bodyUp=(lateralDirection+upAxis*math.clamp(.3+lift*.18,.3,.48)).Unit
	local bodyLook=forward
	bodyLook-=bodyUp*bodyLook:Dot(bodyUp)
	if bodyLook.Magnitude<.05 then
		bodyLook=forward-bodyUp*forward:Dot(bodyUp)
	end
	if bodyLook.Magnitude<.05 then
		bodyLook=bodyUp:Cross(upAxis)
	end
	bodyLook=bodyLook.Magnitude>.05 and bodyLook.Unit or forward
	return CFrame.lookAt(position,position+bodyLook,bodyUp)
end

local function prototypeLandingPosition(save:any,target:Vector3,upAxis:Vector3,forward:Vector3,lateralAxis:Vector3):Vector3
	local startPosition:Vector3=save.StartPosition or target
	local side=((target-startPosition):Dot(lateralAxis)>=0)and 1 or-1
	local travel=math.abs((target-startPosition):Dot(lateralAxis))
	local carry=math.clamp(1.65+travel*.16,1.65,4.25)
	local landing=target+lateralAxis*side*carry-forward*.12
	local floorHeight=tonumber(save.DiveFloorHeight)or(startPosition:Dot(upAxis))
	return landing+upAxis*(floorHeight-landing:Dot(upAxis))
end


local function vtrDiveBallDropAssist(save:any, ball:BasePart?, keeperRoot:BasePart?, upAxis:Vector3, floorHeight:number, currentHeight:number, elapsed:number, interceptTime:number):number
	if not save or not ball or not ball.Parent or not keeperRoot then
		return 0
	end

	if save.Launched ~= true then
		return 0
	end

	local velocity = ball.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if flatVelocity.Magnitude < 8 then
		return 0
	end

	local toKeeper = keeperRoot.Position - ball.Position
	local flatToKeeper = Vector3.new(toKeeper.X, 0, toKeeper.Z)
	local along = flatToKeeper:Dot(flatVelocity.Unit)
	if along < -5 or along > 46 then
		return 0
	end

	local time = math.clamp(along / math.max(flatVelocity.Magnitude, 1), 0, 1.1)
	local predicted = ball.Position + velocity * time - upAxis * (0.5 * workspace.Gravity * time * time)
	local ballHeight = predicted:Dot(upAxis)
	local rootHeight = keeperRoot.Position:Dot(upAxis)
	local dropGap = rootHeight + 2.45 - ballHeight
	local dropping = velocity:Dot(upAxis) <= 3

	if dropGap <= 0 or not dropping then
		return 0
	end

	local urgency = math.clamp((1.05 - time) / 1.05, 0, 1)
	local phase = math.clamp(elapsed / math.max(interceptTime, 0.08), 0, 1)
	local desired = math.min(currentHeight - floorHeight, math.clamp(dropGap * (1.35 + urgency * 2.4) * (0.55 + phase), 0, 9.5))
	local now = os.clock()
	local lastAt = tonumber(save.DynamicFallAssistAt) or now
	local deltaTime = math.clamp(now - lastAt, 1 / 240, 1 / 20)
	local previous = tonumber(save.DynamicFallAssist) or 0
	local blend = math.clamp(deltaTime * (5.5 + urgency * 9), 0.045, 0.22)
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

	return assist
end


local function prototypeDiveFlightPosition(save:any,elapsed:number,upAxis:Vector3,forward:Vector3,lateralAxis:Vector3):(Vector3,number,boolean)
	local startPosition:Vector3=save.StartPosition
	local target:Vector3=save.RootTarget
	local keeperRoot=save.Keeper and root(save.Keeper)
	local interceptTime=math.max(.1,tonumber(save.DiveDuration)or.35)
	local totalFlight=interceptTime+DIVE_FALL_THROUGH
	local alpha=math.clamp(elapsed/totalFlight,0,1)
	local landing=prototypeLandingPosition(save,target,upAxis,forward,lateralAxis)
	local floorHeight=landing:Dot(upAxis)
	local maxHeight=floorHeight+10
	if not finiteNumber(maxHeight) or maxHeight < floorHeight then
		maxHeight = floorHeight + 11
	end
	local function bounded(position:Vector3, landed:boolean):(Vector3,number,boolean)
		if not isFiniteVector3(position) then
			position=landing
			landed=true
			alpha=1
		end
		local currentHeight=position:Dot(upAxis)
		local clampedHeight=math.clamp(currentHeight,floorHeight,maxHeight)
		if clampedHeight~=currentHeight then
			position+=upAxis*(clampedHeight-currentHeight)
		end
		return position,alpha,landed
	end
	if save.LandedAt then
		alpha=1
		return bounded(save.LandedPosition or landing,true)
	end
	if alpha>=1 then
		save.LandedPosition=landing
		return bounded(landing,true)
	end
	if elapsed<=interceptTime then
		local phase=math.clamp(elapsed/interceptTime,0,1)
		local glide=smoothStep(phase)
		local base=startPosition:Lerp(target,glide)
		local startHeight=startPosition:Dot(upAxis)
		local targetHeight=target:Dot(upAxis)
		local arc=math.sin(math.pi*phase)*DIVE_JUMP_HEIGHT
		local height=math.max(floorHeight,startHeight+(targetHeight-startHeight)*glide+arc)
		height-=vtrDiveBallDropAssist(save, workspace:FindFirstChild("Ball", true) or save.Ball, keeperRoot, upAxis, floorHeight, height, elapsed, interceptTime)
		height=math.max(floorHeight,height)
		return bounded(base+upAxis*(height-base:Dot(upAxis)),false)
	end
	local fallAlpha=math.clamp((elapsed-interceptTime)/DIVE_FALL_THROUGH,0,1)
	local glide=smoothStep(fallAlpha)
	local base=target:Lerp(landing,glide)
	local targetHeight=target:Dot(upAxis)
	local height=math.max(floorHeight,targetHeight+(floorHeight-targetHeight)*glide)
	height-=vtrDiveBallDropAssist(save, workspace:FindFirstChild("Ball", true) or save.Ball, keeperRoot, upAxis, floorHeight, height, elapsed, interceptTime)
	height=math.max(floorHeight,height)
	return bounded(base+upAxis*(height-base:Dot(upAxis)),false)
end

local function keeperDiveRootFrame(position: Vector3, forward: Vector3, upAxis: Vector3, lateralAxis: Vector3?, rollAlpha: number?): CFrame
	local look = forward - upAxis * forward:Dot(upAxis)
	if look.Magnitude < 0.05 then
		look = Vector3.zAxis
	end
	if not isFiniteVector3(position) then
		position = Vector3.zero
	end
	local up = upAxis
	local roll = math.clamp(tonumber(rollAlpha)or 0,0,1)
	if lateralAxis and lateralAxis.Magnitude>.05 and roll>.001 then
		local lateral = lateralAxis - upAxis * lateralAxis:Dot(upAxis)
		if lateral.Magnitude>.05 then
			up = (upAxis:Lerp(lateral.Unit, roll)).Unit
		end
	end
	return CFrame.lookAt(position, position + look.Unit, up)
end

local function goalkeeperDiveAnimationName(save: any): string
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

function Service:_continueDiveAftermath(save:any,outcome:string,parriedSave:boolean?)
	if save and save.Keeper and (outcome=="Held" or outcome=="Parried" or outcome=="Miss") then self:_vtrStopLowDiveOverride(save.Keeper) end
	if not save or save.AftermathStarted then return end
	save.AftermathStarted=true
	save.FinishTime=os.clock()
	save.DiveState="Falling"
	local keeper:Model=save.Keeper
	task.spawn(function()
		if not keeper or not keeper.Parent then return end
		local keeperRoot=root(keeper)
		local rectangle=save.Rectangle
		if not keeperRoot or not rectangle then return end
		local humanoid=keeper:FindFirstChildOfClass("Humanoid")
		local forward=fieldDirection(rectangle,self.PitchCFrame)
		local upAxis=self.PitchCFrame.UpVector
		local lateralAxis=save.LateralAxis or rectangle.Right
		if lateralAxis.Magnitude<.05 then lateralAxis=self.PitchCFrame.RightVector end
		lateralAxis=lateralAxis.Unit
		save.DiveFloorHeight=save.DiveFloorHeight or (self.PitchCFrame.Position:Dot(upAxis)+SAFE_ROOT_HEIGHT+.25)
		keeperRoot.Anchored=true
		if humanoid then
			humanoid.PlatformStand=true
			humanoid.AutoRotate=false
			humanoid:Move(Vector3.zero,false)
		end
		if save.DiveAlign then save.DiveAlign:Destroy();save.DiveAlign=nil end
		if save.DiveVelocity then save.DiveVelocity:Destroy();save.DiveVelocity=nil end
		if save.DiveAttachment then save.DiveAttachment:Destroy();save.DiveAttachment=nil end
		local posePlan=save.DivePosePlan or makeDivePosePlan(rectangle,save.DiveAim or save.Target or keeperRoot.Position,save.StartPosition or keeperRoot.Position,lateralAxis)
		posePlan.WorldTilted=true
		save.DivePosePlan=posePlan
		local startedAt=tonumber(save.DiveStartedAt)or os.clock()
		local interceptTime=math.max(.1,tonumber(save.DiveDuration)or .35)
		local totalFlight=interceptTime+DIVE_FALL_THROUGH
		while keeper.Parent do
			if save.LandedAt then break end
			local elapsed=os.clock()-startedAt
			if elapsed>=totalFlight then break end
			save.DiveState="Falling"
			keeper:SetAttribute("VTRGoalkeeperState","Falling")
			local position,progress=prototypeDiveFlightPosition(save,elapsed,upAxis,forward,lateralAxis)
			if not isFiniteVector3(position) then break end
			local roll=save.CenteredDive and 0 or math.sin(math.pi*math.clamp(progress,0,1))*.92
		if save.LowDive==true or save.NoJump==true then
			local sidewaysUntil=tonumber(save.Keeper and save.Keeper:GetAttribute("VTRLowDiveSidewaysUntil"))or 0
			if os.clock()<sidewaysUntil then roll=1 else roll=math.max(roll,.72)end
		end
		if save.LowDive==true or save.NoJump==true then
			local sidewaysUntil=tonumber(save.Keeper and save.Keeper:GetAttribute("VTRLowDiveSidewaysUntil"))or 0
			if os.clock()<sidewaysUntil then roll=1 else roll=math.max(roll,.72)end
		end
			keeper:PivotTo(keeperDiveRootFrame(position,forward,upAxis,lateralAxis,roll))
			liftKeeperAboveFloor(keeper,upAxis,self.PitchCFrame.Position:Dot(upAxis)+.58,.08)
			if outcome=="Held" then secureHeldBall(self.Ball,keeper)end
			task.wait()
		end
		if not keeper.Parent then return end
		local finalPosition=prototypeDiveFlightPosition(save,totalFlight,upAxis,forward,lateralAxis)
		if not isFiniteVector3(finalPosition) then
			finalPosition=save.LandedPosition or prototypeLandingPosition(save,save.RootTarget or keeperRoot.Position,upAxis,forward,lateralAxis)
		end
		save.LandedPosition=finalPosition
		save.LandedAt=os.clock()
		keeper:PivotTo(keeperDiveRootFrame(finalPosition,forward,upAxis,lateralAxis,0))
		save.DiveState="Landed"
		keeper:SetAttribute("VTRGoalkeeperState",outcome=="Miss"and"Beaten"or"Landing")
		liftKeeperAboveFloor(keeper,upAxis,self.PitchCFrame.Position:Dot(upAxis)+.58,.08)
		local holdUntil=os.clock()+DIVE_LAND_HOLD
		while keeper.Parent and os.clock()<holdUntil do
			keeper:PivotTo(keeperDiveRootFrame(save.LandedPosition or finalPosition,forward,upAxis,lateralAxis,0))
			if outcome=="Held" then secureHeldBall(self.Ball,keeper)end
			task.wait()
		end
		if not keeper.Parent then return end
		keeper:SetAttribute("VTRKeeperDiveAnimationLocked",nil)
		if self.Animations then self.Animations:StopAction(keeper,.18)end
		save.DiveState="Recovering"
		keeper:SetAttribute("VTRGoalkeeperState","Recovering")
		local recoverStarted=os.clock()
		while keeper.Parent do
			local alpha=math.clamp((os.clock()-recoverStarted)/DIVE_RECOVER,0,1)
			if outcome=="Held" then secureHeldBall(self.Ball,keeper)end
			if alpha>=1 then break end
			task.wait()
		end
		save.DiveState="ReturnHome"
		task.wait(DIVE_RETURN_HOME)
		clearKeeperDivePose(keeper)
		keeperRoot=root(keeper)
		if keeperRoot then
			keeperRoot.Anchored=false
			keeperRoot.AssemblyLinearVelocity=Vector3.zero
			keeperRoot.AssemblyAngularVelocity=Vector3.zero
		end
		if humanoid then
			humanoid.PlatformStand=false
			humanoid.AutoRotate=true
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		local facing=self.LineFacing[keeper];if facing then facing.Align.Enabled=true end
		keeper:SetAttribute("VTRGoalkeeperSaving",false)
		if outcome=="Held" and self.Ball:GetAttribute("VTRGoalkeeperHeld")==true then
			secureHeldBall(self.Ball,keeper)
			if userControlledKeeper(keeper) then
				keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+999)
				keeper:SetAttribute("VTRKeeperMustDistributeUntil",nil)
				keeper:SetAttribute("AIAssignment","GoalkeeperPosition")
				self:_monitorControlledHold(keeper,rectangle,save.DefendingSide)
			else
				self:_beginAIGoalkeeperDistribution(keeper,save.DefendingSide,AI_KEEPER_DISTRIBUTION_WINDOW)
			end
			keeper:SetAttribute("VTRGoalkeeperState","Held")
		elseif outcome=="Parried" or parriedSave then
			keeper:SetAttribute("VTRGoalkeeperState","Parried")
			keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+.8)
		elseif outcome=="Miss" then
			keeper:SetAttribute("VTRGoalkeeperState","Beaten")
			keeper:SetAttribute("VTRNoAutoPassUntil",os.clock()+1.2)
		else
			keeper:SetAttribute("VTRGoalkeeperState","Recovered")
		end
		if self.ActiveSave==save then self.ActiveSave=nil end
	end)
end

function Service:FinishActiveDiveAfterGoal()
	local save=self.ActiveSave
	if not save or save.AftermathStarted or not save.Launched or not save.Rectangle or not save.Target then return end
	save.Finished=true
	save.FinishTime=os.clock()
	local keeper:Model=save.Keeper
	if keeper and keeper.Parent then
		keeper:SetAttribute("VTRGoalkeeperSaving",true)
		keeper:SetAttribute("VTRGoalkeeperState","Falling")
		keeper:SetAttribute("VTRKeeperDiveAnimationLocked",true)
	end
	self:_continueDiveAftermath(save,"Miss",false)
end

local function createLateralDrive(save:any,keeperRoot:BasePart,lateralAxis:Vector3,lateralSpeed:number)
	local attachment=save.DiveAttachment
	if not attachment then attachment=Instance.new("Attachment");attachment.Name="VTRKeeperDiveAttachment";attachment.Parent=keeperRoot;save.DiveAttachment=attachment end
	local drive=Instance.new("LinearVelocity");drive.Name="VTRKeeperLateralDive";drive.Attachment0=attachment;drive.RelativeTo=Enum.ActuatorRelativeTo.World;drive.VelocityConstraintMode=Enum.VelocityConstraintMode.Line;drive.LineDirection=lateralAxis;drive.LineVelocity=lateralSpeed;drive.ForceLimitsEnabled=false;drive.Parent=keeperRoot
	save.DiveVelocity=drive
end

local function liveReachHitboxTouched(service:any,save:any,target:Vector3):boolean
	if save.WillSave~=true then return false end
	local radius=math.max(0.1,tonumber(save.ContactRadius)or(service.Ball.Size.X*.5+1.2))
	local distance=(service.Ball.Position-target).Magnitude
	save.Keeper:SetAttribute("VTRLiveSaveHitboxRadius",radius)
	save.Keeper:SetAttribute("VTRLiveSaveHitboxDistance",math.floor(distance*100)/100)
	return distance<=radius
end





function Service:_vtrPlayTemporaryDiveAnimation(keeper:Model, animationName:string, duration:number?)
	if not keeper or not keeper.Parent or not self.Animations then
		return
	end

	local playDuration = tonumber(duration) or 1.0
	local token = tostring(os.clock()) .. animationName

	keeper:SetAttribute("VTRCurrentDiveAnimation", animationName)
	keeper:SetAttribute("VTRLowDiveAnimationToken", token)
	keeper:SetAttribute("VTRLowDiveSidewaysUntil", os.clock() + playDuration)
	keeper:SetAttribute("VTRKeeperDiveAnimationLocked", nil)

	self.Animations:StopAction(keeper, 0.04)

	task.delay(0.03, function()
		if keeper.Parent and keeper:GetAttribute("VTRLowDiveAnimationToken") == token then
			keeper:SetAttribute("VTRKeeperDiveAnimationLocked", true)
			self.Animations:PlayAction(keeper, animationName)
		end
	end)

	task.delay(playDuration, function()
		if keeper.Parent and keeper:GetAttribute("VTRLowDiveAnimationToken") == token then
			keeper:SetAttribute("VTRKeeperDiveAnimationLocked", nil)
			self.Animations:StopAction(keeper, 0.12)
			keeper:SetAttribute("VTRCurrentDiveAnimation", nil)
			keeper:SetAttribute("VTRLowDiveAnimationToken", nil)
			keeper:SetAttribute("VTRLowDiveSidewaysUntil", nil)
		end
	end)
end

function Service:_vtrStopLowDiveOverride(keeper:Model?)
	if not keeper or not keeper.Parent or not self.Animations then
		return
	end

	if keeper:GetAttribute("VTRLowDiveAnimationToken") ~= nil or keeper:GetAttribute("VTRCurrentDiveAnimation") == "GoalkeeperDiveLowLeft" or keeper:GetAttribute("VTRCurrentDiveAnimation") == "GoalkeeperDiveLowRight" then
		keeper:SetAttribute("VTRKeeperDiveAnimationLocked", nil)
		self.Animations:StopAction(keeper, 0.12)
		keeper:SetAttribute("VTRCurrentDiveAnimation", nil)
		keeper:SetAttribute("VTRLowDiveAnimationToken", nil)
		keeper:SetAttribute("VTRLowDiveSidewaysUntil", nil)
	end
end


function Service:Step(dt:number?)
	
	self:_vtrStepRollingLowDiveSwitch()
	dt=math.clamp(dt or 1/60,1/240,.1)
	local shotId = self.BallService.MotionKind == "Shot" and self.BallService.MotionStarted or 0
	if shotId ~= 0 and shotId ~= self.ObservedShot then
		self.ObservedShot = shotId
	end
	if shotId ~= 0 and not self.ActiveSave then
		local attackingSide = self.BallService:GetLastTouchTeam()
		if attackingSide == "Home" or attackingSide == "Away" then self:_begin(attackingSide, shotId) end
	end
	local save = self.ActiveSave
	if not save then
		self:_keeperSafety("Home");self:_keeperSafety("Away")
		self:_positionOnLine("Home")
		self:_positionOnLine("Away")
		return
	end
	if save.DiveState=="Falling" or save.DiveState=="Landed" or save.DiveState=="Recovering" or save.DiveState=="ReturnHome" then
		return
	end
	if self.BallService.MotionKind ~= "Shot" or self.BallService.MotionStarted ~= save.ShotId then
		local keepFailedVisual = save.WillSave == false and save.Rectangle ~= nil and save.Target ~= nil and (not save.Launched or os.clock() - (save.DiveStartedAt or os.clock()) < MIN_VISUAL_DIVE_TIME + 0.38)
		if keepFailedVisual then
			save.ShotExpired = true
		else
		save.Keeper:SetAttribute("VTRGoalkeeperSaving", false)
		save.Keeper:SetAttribute("VTRSaveTarget", nil)
		save.Keeper:SetAttribute("VTRGoalkeeperState", "Idle")
		save.Keeper:SetAttribute("VTRShotWillScore", nil)
		save.Keeper:SetAttribute("VTRShotOutcomeSource", nil)
		if save.DiveAlign then save.DiveAlign:Destroy()end;if save.DiveVelocity then save.DiveVelocity:Destroy()end;if save.DiveAttachment then save.DiveAttachment:Destroy()end
		clearKeeperDivePose(save.Keeper)
		save.Keeper:SetAttribute("VTRKeeperDiveAnimationLocked",nil)
		local cancelledFacing=self.LineFacing[save.Keeper];if cancelledFacing then cancelledFacing.Align.Enabled=true end
		local cancelledRoot=root(save.Keeper);if cancelledRoot then cancelledRoot.Anchored=false end
		local cancelledHumanoid=save.Keeper:FindFirstChildOfClass("Humanoid");if cancelledHumanoid then cancelledHumanoid.PlatformStand=false;cancelledHumanoid.AutoRotate=true end
		self.Ball:SetAttribute("VTRGoalkeeperTracking", nil)
		self.ActiveSave = nil
		return
		end
	end
	local rectangle, target, time = self:_prediction(save.AttackingSide,save.EffectiveGravity)
	if not rectangle or not target or not time then
		if save.WillSave==false and not save.Launched and save.Rectangle and save.Target then
			rectangle=save.Rectangle
			target=save.Target
			time=EMERGENCY_SAVE_TIME
		elseif save.Launched then
			if save.Target and liveReachHitboxTouched(self,save,save.Target) then
				self:_finish(save)
			else
				self:_miss(save)
			end
		else
			if save.WillSave==false and os.clock()-(tonumber(save.ShotId)or os.clock())>.95 then self:_miss(save)end
		end
		if not rectangle or not target or not time then return end
	end
	save.Rectangle = rectangle
	if not save.Launched and save.WillSave~=false then
		save.LockedTarget=target
		save.PlannedRootTarget=nil
	end
	if save.PenaltyDiveTarget then
		target=save.PenaltyDiveTarget
	elseif save.LockedTarget then
		target=save.LockedTarget
	end
	save.Target = target
	local keeperRoot = root(save.Keeper)
	local humanoid = save.Keeper:FindFirstChildOfClass("Humanoid")
	if not keeperRoot or not humanoid then self.ActiveSave = nil return end
	local forward=fieldDirection(rectangle,self.PitchCFrame)
	local rootTarget,widthPadding,verticalPadding=boundedRootTarget(rectangle,target,forward)
	local upAxis=self.PitchCFrame.UpVector
	local desiredDepth=(target-rectangle.PlanePoint):Dot(forward)
	local currentDepth=(rootTarget-rectangle.PlanePoint):Dot(forward)
	rootTarget+=forward*(desiredDepth-currentDepth)
	local keeperDepth=(keeperRoot.Position-rectangle.PlanePoint):Dot(forward)
	local rootDepth=(rootTarget-rectangle.PlanePoint):Dot(forward)
	rootTarget+=forward*(keeperDepth-rootDepth)
	if save.PlannedRootTarget and save.WillSave~=false then
		rootTarget=save.PlannedRootTarget
	end
	local toEndpoint=rootTarget-keeperRoot.Position
	local sideVector=toEndpoint-forward*toEndpoint:Dot(forward)-upAxis*toEndpoint:Dot(upAxis)
	local fallbackAxis=rectangle.Right.Magnitude>.05 and rectangle.Right or self.PitchCFrame.RightVector
	local verticalReach=math.max(0,toEndpoint:Dot(upAxis))
	local centeredDive=sideVector.Magnitude<1.15 and verticalReach>.55
	local candidateAxis=sideVector.Magnitude>.35 and sideVector.Unit or fallbackAxis
	local lateralAxis=save.LateralAxis or candidateAxis
	save.CenteredDive=save.CenteredDive or centeredDive
	local diveAim=target
	if save.WillSave==false then
		rootTarget=missedRootTarget(save,keeperRoot,rootTarget,rectangle,lateralAxis,upAxis,forward)
		diveAim=save.MissAim or(rootTarget+upAxis*1.05)
	end
	if save.Launched and save.RootTarget then rootTarget=save.RootTarget end
	local travel=math.abs((rootTarget-keeperRoot.Position):Dot(lateralAxis))
	local rise=math.max(0,(rootTarget-keeperRoot.Position):Dot(upAxis))
	local catchScale=math.clamp(tonumber(save.Keeper:GetAttribute("VTRPracticeKeeperHandling"))or 1,.05,2.2)
	local diveSpeed=math.max(1,tonumber(save.DiveSpeed)or DEFAULT_DIVE_SPEED)
	local distanceToCover=Vector2.new(travel,rise).Magnitude
	local requiredTime=math.clamp(distanceToCover/diveSpeed,.12,3.0)
	local reactionReady=os.clock()>=(tonumber(save.ReactionReadyAt)or 0)
	local forceLateDive=save.WillSave==false and (save.ShotExpired==true or time<=EMERGENCY_SAVE_TIME or os.clock()-(tonumber(save.ShotId)or os.clock())>math.max(.3,tonumber(save.ReactionDelay)or 0))
	if not save.Launched then
		local lateral=(rootTarget-keeperRoot.Position):Dot(lateralAxis)
		if reactionReady and math.abs(lateral)>8 and time>requiredTime+.62 then
			humanoid.WalkSpeed=1.15
			humanoid:MoveTo(keeperRoot.Position+lateralAxis*math.clamp(lateral,-.6,.6))
		end
	end
	if not save.Launched and (reactionReady or forceLateDive) then
		save.Launched=true
		save.DivePlayed=true
		save.Keeper:SetAttribute("VTRGoalkeeperState","Diving")
		humanoid:Move(Vector3.zero,false)
		humanoid.PlatformStand=true
		local flightTime=math.max(.12,requiredTime)
		if save.WillSave==false then flightTime=math.clamp(requiredTime+(tonumber(save.MissDelay)or .35),forceLateDive and .42 or .35,1.45)end
		save.DiveStartedAt=os.clock()
		save.DiveDuration=flightTime
		save.InitialInterceptTime=save.WillSave==false and math.max(forceLateDive and flightTime*.62 or time+(tonumber(save.MissDelay)or .35),.01)or math.max(flightTime,.01)
		save.Progress=0
		save.StartPosition=keeperRoot.Position
		save.RootTarget=rootTarget
		save.DiveFloorHeight=self.PitchCFrame.Position:Dot(upAxis)+SAFE_ROOT_HEIGHT+.25
		save.DiveLook=(rootTarget-keeperRoot.Position)
		save.DiveAim=diveAim
		save.FixedDiveDepth=(keeperRoot.Position-rectangle.PlanePoint):Dot(forward)
		save.LateralAxis=candidateAxis
		save.CenteredDive=centeredDive
		save.DivePosePlan=makeDivePosePlan(rectangle,diveAim,save.StartPosition,lateralAxis)
		save.DivePosePlan.WorldTilted=true
		lateralAxis=candidateAxis
		local facing=self.LineFacing[save.Keeper];if facing then facing.Align.Enabled=false end
		local delta=rootTarget-keeperRoot.Position
		local lateralDistance=delta:Dot(lateralAxis)
		local startVertical=(save.StartPosition-rectangle.PlanePoint):Dot(upAxis)
		local endVertical=(rootTarget-rectangle.PlanePoint):Dot(upAxis)
		local control=save.StartPosition:Lerp(rootTarget,.48)
		local controlVertical=(control-rectangle.PlanePoint):Dot(upAxis)
		local lowTargetBeforeLaunch=(target-rectangle.PlanePoint):Dot(upAxis)<=rectangle.Bottom+3.25 or save.LowDive==true or save.NoJump==true
		if lowTargetBeforeLaunch then
			save.LowDive=true
			save.NoJump=true
			save.Keeper:SetAttribute("VTRLowShotFlatDive",true)
			save.Keeper:SetAttribute("VTRFallingLowShotDive",true)
			save.Keeper:SetAttribute("VTRKeeperNoJumpDive",true)
		end
		local jumpHeight=lowTargetBeforeLaunch and 0.08 or DIVE_JUMP_HEIGHT
		save.ApexPosition=control+upAxis*(math.max(startVertical,endVertical)+jumpHeight-controlVertical)
		keeperRoot.Anchored=true
		save.Keeper:SetAttribute("VTRForceIdle",nil)
		if self.Animations then
			local diveAnimationName=goalkeeperDiveAnimationName(save)
			if diveAnimationName=="GoalkeeperDiveLowLeft" or diveAnimationName=="GoalkeeperDiveLowRight" then
				self:_vtrPlayTemporaryDiveAnimation(save.Keeper,diveAnimationName,1.0)
			else
				save.Keeper:SetAttribute("VTRCurrentDiveAnimation",diveAnimationName)
				save.Keeper:SetAttribute("VTRKeeperDiveAnimationLocked",true)
				self.Animations:PlayAction(save.Keeper,diveAnimationName)
			end
		end
		save.Keeper:SetAttribute("VTRDiveLateralDistance",lateralDistance)
		save.Keeper:SetAttribute("VTRDiveLateralSpeed",math.abs(lateralDistance)/flightTime)
		save.Keeper:SetAttribute("VTRDiveTarget",rootTarget)
		save.Keeper:SetAttribute("VTRDiveAim",diveAim)
		save.Keeper:SetAttribute("VTRDiveLaunchTime",time)
		save.Keeper:SetAttribute("VTRDiveAxis",lateralAxis)
		save.Ball=self.Ball
		save.Keeper:SetAttribute("VTRSavePredictedHeight",(target-rectangle.PlanePoint):Dot(upAxis))
	end
	if save.Launched then
		local elapsed=os.clock()-(save.DiveStartedAt or os.clock())
		local position,progress=prototypeDiveFlightPosition(save,elapsed,upAxis,forward,lateralAxis)
		if not isFiniteVector3(position) then
			self:_miss(save)
			return
		end
		save.Progress=progress
		local roll=save.CenteredDive and 0 or math.sin(math.pi*math.clamp(progress,0,1))*.92
		if save.LowDive==true or save.NoJump==true then
			local sidewaysUntil=tonumber(save.Keeper and save.Keeper:GetAttribute("VTRLowDiveSidewaysUntil"))or 0
			if os.clock()<sidewaysUntil then roll=1 else roll=math.max(roll,.72)end
		end
		if save.LowDive==true or save.NoJump==true then
			local sidewaysUntil=tonumber(save.Keeper and save.Keeper:GetAttribute("VTRLowDiveSidewaysUntil"))or 0
			if os.clock()<sidewaysUntil then roll=1 else roll=math.max(roll,.72)end
		end
		local desiredFrame=keeperDiveRootFrame(position,forward,upAxis,lateralAxis,roll)
		save.Keeper:SetAttribute("VTRSidewaysDive",not save.CenteredDive)
		save.Keeper:SetAttribute("VTRDiveBodyAngle",math.floor(math.deg(math.acos(math.clamp(desiredFrame.UpVector:Dot(upAxis),-1,1)))+.5))
		save.Keeper:PivotTo(desiredFrame)
		local posePlan=save.DivePosePlan or makeDivePosePlan(rectangle,diveAim,save.StartPosition,lateralAxis)
		posePlan.WorldTilted=true
		save.DivePosePlan=posePlan
		liftKeeperAboveFloor(save.Keeper,upAxis,self.PitchCFrame.Position:Dot(upAxis)+.58,.08)
	end
	if save.Launched and save.WillSave==false and ((save.Progress or 0)>=.94 or time<=EMERGENCY_SAVE_TIME) and os.clock()-(save.DiveStartedAt or os.clock())>=math.clamp(.58+(tonumber(save.MissDelay)or .35)*.25,.58,.86) then
		self:_miss(save)
		return
	end
	if save.WillSave~=false and save.Launched and liveReachHitboxTouched(self,save,save.LockedTarget or target) then
		self:_finish(save)
		return
	end
	if save.WillSave~=false and save.Launched and ((save.Progress or 0)>=.995 or time<=EMERGENCY_SAVE_TIME) then
		self:_miss(save)
	end
end

function Service:Reset()
	if self.ActiveSave and self.ActiveSave.Keeper.Parent then
		self.ActiveSave.Keeper:SetAttribute("VTRGoalkeeperSaving", false)
		self.ActiveSave.Keeper:SetAttribute("VTRSaveTarget", nil)
		self.ActiveSave.Keeper:SetAttribute("VTRGoalkeeperState", "Idle")
		self.ActiveSave.Keeper:SetAttribute("VTRShotWillScore", nil)
		self.ActiveSave.Keeper:SetAttribute("VTRShotOutcomeSource", nil)
		local resetRoot=root(self.ActiveSave.Keeper);if resetRoot then resetRoot.Anchored=false end
		if self.ActiveSave.DiveAlign then self.ActiveSave.DiveAlign:Destroy()end;if self.ActiveSave.DiveVelocity then self.ActiveSave.DiveVelocity:Destroy()end;if self.ActiveSave.DiveAttachment then self.ActiveSave.DiveAttachment:Destroy()end
		clearKeeperDivePose(self.ActiveSave.Keeper)
		self.ActiveSave.Keeper:SetAttribute("VTRKeeperDiveAnimationLocked",nil)
		local resetFacing=self.LineFacing[self.ActiveSave.Keeper];if resetFacing then resetFacing.Align.Enabled=true end
		local resetHumanoid=self.ActiveSave.Keeper:FindFirstChildOfClass("Humanoid");if resetHumanoid then resetHumanoid.PlatformStand=false;resetHumanoid.AutoRotate=true end
	end
	for _,side in{"Home","Away"}do local keeper=goalkeeper(self.Teams[side]);if keeper then self.BallService:ReleaseGoalkeeperHold(keeper)end end
	self.Ball:SetAttribute("VTRGoalkeeperTracking", nil)
	self.ActiveSave = nil
end

return Service
