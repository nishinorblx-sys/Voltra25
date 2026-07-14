--!strict

local MatchFormatConfig = require(script.Parent.MatchFormatConfig)
local ReceiverAssistConfig = require(script.Parent.ReceiverAssistConfig)
local DefensiveSwitchConfig = require(script.Parent.DefensiveSwitchConfig)

local defaults = table.freeze({
	MatchFormat = "Standard",
	CameraPreset = "Auto",
	CameraZoomMode = "Moderate",
	ReceiverAssistMode = "Standard",
	PassReceiverAutoSwitch = "Standard",
	DefensiveAutoSwitchMode = "Standard",
	ManualPassAutoSwitch = "Manual",
	MobileSprintMode = "Toggle",
	MobileControlHandedness = "Right",
	Trainer = "Basic",
	ReducedMotion = false,
	PerformanceMode = false,
	ImmersivePresentation = false,
})

local cameraAliases = {
	Broadcast = "Tactical",
	WideBroadcast = "Tactical",
	["Wide Broadcast"] = "Tactical",
	CloseBroadcast = "Tactical",
	["Close Broadcast"] = "Tactical",
	["End to End"] = "Tactical",
	PlayThirdPerson = "Pro",
}

local validCamera = {Auto = true, Tactical = true, Pro = true, Roblox = true}
local validZoom = {Close = true, Moderate = true, Wide = true}
local validSprint = {Toggle = true, Hold = true}
local validHand = {Right = true, Left = true}

local function copyDefaults(): {[string]: any}
	local result = {}
	for key, value in defaults do
		result[key] = value
	end
	return result
end

local function normalize(source: any): {[string]: any}
	local input = if type(source) == "table" then source else {}
	local result = table.clone(input)
	result.MatchFormat = MatchFormatConfig.Normalize(input.MatchFormat or input.MatchLength)
	local camera = cameraAliases[tostring(input.CameraPreset or "")] or tostring(input.CameraPreset or defaults.CameraPreset)
	result.CameraPreset = if validCamera[camera] then camera else defaults.CameraPreset
	local zoom = tostring(input.CameraZoomMode or defaults.CameraZoomMode)
	result.CameraZoomMode = if validZoom[zoom] then zoom else defaults.CameraZoomMode
	result.ReceiverAssistMode = ReceiverAssistConfig.Normalize(input.ReceiverAssistMode or input.ReceiverAssist or input.PassReceiverAutoSwitch, defaults.ReceiverAssistMode)
	result.PassReceiverAutoSwitch = ReceiverAssistConfig.Normalize(input.PassReceiverAutoSwitch or result.ReceiverAssistMode, result.ReceiverAssistMode)
	result.DefensiveAutoSwitchMode = DefensiveSwitchConfig.Normalize(input.DefensiveAutoSwitchMode or input.DefensiveAutoSwitch, defaults.DefensiveAutoSwitchMode)
	result.ManualPassAutoSwitch = ReceiverAssistConfig.Normalize(input.ManualPassAutoSwitch, defaults.ManualPassAutoSwitch)
	local mobileSprint = tostring(input.MobileSprintMode or input.SprintMode or "")
	if mobileSprint == "" and input.SprintToggle == false then
		mobileSprint = "Hold"
	end
	result.MobileSprintMode = if validSprint[mobileSprint] then mobileSprint else defaults.MobileSprintMode
	local handedness = tostring(input.MobileControlHandedness or input.MobileLayout or defaults.MobileControlHandedness)
	result.MobileControlHandedness = if validHand[handedness] then handedness else defaults.MobileControlHandedness
	result.Trainer = tostring(input.Trainer or defaults.Trainer)
	result.ReducedMotion = input.ReducedMotion == true
	result.PerformanceMode = input.PerformanceMode == true
	result.ImmersivePresentation = input.ImmersivePresentation == true
	result.ReceiverAssist = nil
	result.DefensiveAutoSwitch = nil
	result.SprintToggle = nil
	result.SprintMode = nil
	result.MobileLayout = nil
	result.StaminaMode = nil
	result.EnduranceMode = nil
	return result
end

local function synchronize(profileSettings: any, uiSettings: any): ({[string]: any}, {[string]: any})
	local primary = if type(profileSettings) == "table" then profileSettings else {}
	local secondary = if type(uiSettings) == "table" then uiSettings else {}
	local merged = table.clone(secondary)
	for key, value in primary do
		merged[key] = value
	end
	local normalized = normalize(merged)
	return table.clone(normalized), table.clone(normalized)
end

return table.freeze({
	Defaults = defaults,
	CopyDefaults = copyDefaults,
	Normalize = normalize,
	Synchronize = synchronize,
})
