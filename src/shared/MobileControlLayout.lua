--!strict

local MobileControlLayout = {}

local function insetValue(insets: any, key: string): number
	return math.max(0, tonumber(type(insets) == "table" and insets[key]) or 0)
end

local function centerFromNearEdge(edge: number, size: number, inward: number): number
	return edge + inward * size * .5
end

function MobileControlLayout.Resolve(viewport: Vector2, insets: any, handedness: string?): any
	local width = math.max(280, tonumber(viewport.X) or 1280)
	local height = math.max(320, tonumber(viewport.Y) or 720)
	local left = insetValue(insets, "Left")
	local top = insetValue(insets, "Top")
	local right = insetValue(insets, "Right")
	local bottom = insetValue(insets, "Bottom")
	local shortSide = math.min(width, height)
	local density = math.clamp(shortSide / 720, .82, 1.08)
	local normal = math.clamp(math.floor(62 * density + .5), 56, 68)
	local primary = math.clamp(math.floor(68 * density + .5), 64, 74)
	local gap = math.clamp(math.floor(11 * density + .5), 10, 14)
	local margin = math.clamp(math.floor(16 * density + .5), 12, 20)
	local joystick = math.clamp(math.floor(shortSide * .22 + .5), 132, 170)
	local knob = math.clamp(math.floor(joystick * .4 + .5), 52, 68)
	local bottomEdge = math.max(top + primary * 2 + gap + margin, height - bottom - margin)
	local yBottom = bottomEdge - primary * .5
	local yTop = yBottom - primary * .5 - gap - primary * .5
	local actionOnLeft = handedness == "Left"
	local actionEdge = if actionOnLeft then left + margin else width - right - margin
	local actionInward = if actionOnLeft then 1 else -1
	local xPrimary = centerFromNearEdge(actionEdge, primary, actionInward)
	local xSecondary = xPrimary
	local xInner = xPrimary + actionInward * (primary * .5 + gap + normal * .5)
	local joystickEdge = if actionOnLeft then width - right - margin else left + margin
	local joystickInward = if actionOnLeft then -1 else 1
	local xJoystick = centerFromNearEdge(joystickEdge, joystick, joystickInward)
	local yJoystick = math.min(height - bottom - margin - joystick * .5, yBottom)
	return {
		Viewport = Vector2.new(width, height),
		Insets = {Left = left, Top = top, Right = right, Bottom = bottom},
		Scale = density,
		Gap = gap,
		NormalSize = normal,
		PrimarySize = primary,
		JoystickSize = joystick,
		KnobSize = knob,
		Joystick = Vector2.new(xJoystick, yJoystick),
		Primary = Vector2.new(xPrimary, yBottom),
		Secondary = Vector2.new(xSecondary, yTop),
		Sprint = Vector2.new(xInner, yBottom),
		Context = Vector2.new(xInner, yTop),
	}
end

return table.freeze(MobileControlLayout)
