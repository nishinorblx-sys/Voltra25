--!strict
local UserInputService = game:GetService("UserInputService")

local Service = {}

Service.DefaultBindings = table.freeze({
	PauseKey = "M",
	ManualPassKey = "LeftControl",
	LobbedPassKey = "LeftAlt",
	ThroughPassKey = "E",
	ChangePlayerKey = "Q",
	TackleKey = "E",
	SlideTackleKey = "F",
	SkipKey = "Space",
})

local gamepad = table.freeze({
	Move = "LS",
	Pass = "A",
	GroundPass = "A",
	ThroughPass = "Y",
	Lob = "X",
	ManualPass = "Y",
	Shot = "B",
	Shoot = "B",
	Switch = "L1",
	Tackle = "A",
	SlideTackle = "X",
	Block = "R1",
	Sprint = "R2",
	Pause = "MENU",
	ShootingFocus = "Y",
	Skip = "A",
})

local touch = table.freeze({
	Move = "MOVE STICK",
	Pass = "PASS",
	GroundPass = "PASS",
	ThroughPass = "THROUGH",
	Lob = "LOB",
	ManualPass = "PASS",
	Shot = "SHOOT",
	Shoot = "SHOOT",
	Switch = "SWITCH",
	Tackle = "TACKLE",
	SlideTackle = "SLIDE",
	Block = "BLOCK",
	Sprint = "SPRINT",
	Pause = "PAUSE",
	ShootingFocus = "FOCUS",
	Skip = "SKIP",
})

local keyboardBinding = table.freeze({
	ThroughPass = "ThroughPassKey",
	Lob = "LobbedPassKey",
	ManualPass = "ManualPassKey",
	Switch = "ChangePlayerKey",
	Tackle = "TackleKey",
	SlideTackle = "SlideTackleKey",
	Pause = "PauseKey",
	Skip = "SkipKey",
})

local keyNames = table.freeze({
	LeftControl = "CTRL",
	RightControl = "CTRL",
	LeftShift = "SHIFT",
	RightShift = "SHIFT",
	LeftAlt = "ALT",
	RightAlt = "ALT",
	Space = "SPACE",
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
})

local function keyText(value: any): string
	local text = tostring(value or "")
	text = string.gsub(text, "^Enum%.KeyCode%.", "")
	return keyNames[text] or string.upper(text)
end

function Service.CurrentDevice(): string
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad", 1, true) then return "Gamepad" end
	if last == Enum.UserInputType.Touch or UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "Touch" end
	return "KeyboardMouse"
end

function Service.Glyph(action: string, settings: any?, context: any?): string
	local normalized = action == "Pass" and "GroundPass" or action
	local device = Service.CurrentDevice()
	if device == "Gamepad" then return gamepad[normalized] or string.upper(normalized) end
	if device == "Touch" then
		if normalized == "ThroughPass" and type(context) == "table" and context.MobilePassContext == "Swipe" then return "PASS  +  FORWARD SWIPE" end
		return touch[normalized] or string.upper(normalized)
	end
	if normalized == "Move" then return "WASD" end
	if normalized == "GroundPass" then return "RMB" end
	if normalized == "Shot" or normalized == "Shoot" then return "LMB" end
	if normalized == "Sprint" then return "SHIFT" end
	if normalized == "Block" then return "R" end
	if normalized == "ShootingFocus" then return "1" end
	local binding = keyboardBinding[normalized]
	local defaults = Service.DefaultBindings
	local value = binding and ((type(settings) == "table" and settings[binding]) or defaults[binding]) or normalized
	local glyph = keyText(value)
	if normalized == "ThroughPass" then return glyph .. " + RMB" end
	if normalized == "Lob" or normalized == "ManualPass" then return glyph end
	return glyph
end

function Service.ControlSummary(settings: any?): string
	return table.concat({
		Service.Glyph("Move", settings) .. " MOVE",
		Service.Glyph("Sprint", settings) .. " SPRINT",
		Service.Glyph("Shot", settings) .. " SHOT",
		Service.Glyph("GroundPass", settings) .. " GROUND",
		Service.Glyph("ThroughPass", settings) .. " THROUGH",
		Service.Glyph("Lob", settings) .. " LOB",
		Service.Glyph("Switch", settings) .. " SWITCH",
	}, "   ")
end

function Service.Observe(callback: (string) -> ()): RBXScriptConnection
	local previous = Service.CurrentDevice()
	return UserInputService.LastInputTypeChanged:Connect(function()
		local current = Service.CurrentDevice()
		if current ~= previous then previous = current;callback(current) end
	end)
end

return Service
