from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

sound_service_path = Path("src/client/Services/UISoundService.lua")
sound_service_path.write_text('''--!strict
local SoundService = game:GetService("SoundService")

local Service = {}

local CLICK_SOUNDS = {
	"rbxassetid://99694938057192",
	"rbxassetid://100116561106520",
}

local HOVER_SOUNDS = {
	"rbxassetid://114921985760826",
	"rbxassetid://98484565371608",
}

local TYPE_SOUND = "rbxassetid://124938422635867"
local COLOR_SOUND = "rbxassetid://109229821869092"
local TRANSITION_SOUND = "rbxassetid://136186135240645"

local lastPlayed: {[string]: number} = {}

local function play(id: string, volume: number, key: string?, cooldown: number?)
	local now = os.clock()
	if key and cooldown and (lastPlayed[key] or 0) + cooldown > now then return end
	if key then lastPlayed[key] = now end
	local sound = Instance.new("Sound")
	sound.Name = "VTRUISound"
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		if sound.Parent then sound:Destroy() end
	end)
	sound:Play()
	task.delay(5, function()
		if sound.Parent then sound:Destroy() end
	end)
end

function Service.PlayClick()
	play(CLICK_SOUNDS[math.random(1, #CLICK_SOUNDS)], 0.42, "Click", 0.035)
end

function Service.PlayHover()
	play(HOVER_SOUNDS[math.random(1, #HOVER_SOUNDS)], 0.2, "Hover", 0.08)
end

function Service.PlayType()
	play(TYPE_SOUND, 0.32, "Type", 0.025)
end

function Service.PlayColor()
	play(COLOR_SOUND, 0.42, "Color", 0.05)
end

function Service.PlayTransition()
	play(TRANSITION_SOUND, 0.48, "Transition", 0.18)
end

return Service
''', encoding="utf-8", newline="\n")

button_path = Path("src/client/Components/Button.lua")
button = button_path.read_text(encoding="utf-8")

if "UISoundService" not in button:
    button = button.replace(
        'local Theme = require(ReplicatedStorage.VTR.Shared.Theme)',
        'local Theme = require(ReplicatedStorage.VTR.Shared.Theme)\nlocal UISoundService = require(script.Parent.Parent.Services.UISoundService)',
        1
    )

button = replace_once(
    button,
'''	local function focus()
		local isPrimary = instance:GetAttribute("VTRPrimary") == true
		tween(1.035, isPrimary and C.Neon or C.Raised)
	end''',
'''	local function focus()
		UISoundService.PlayHover()
		local isPrimary = instance:GetAttribute("VTRPrimary") == true
		tween(1.035, isPrimary and C.Neon or C.Raised)
	end''',
    "button hover sound"
)

button = replace_once(
    button,
'''	instance.Activated:Connect(function()
		TweenService:Create(scale, TweenInfo.new(Theme.Animation.Press), { Scale = 0.94 }):Play()''',
'''	instance.Activated:Connect(function()
		UISoundService.PlayClick()
		TweenService:Create(scale, TweenInfo.new(Theme.Animation.Press), { Scale = 0.94 }):Play()''',
    "button click sound"
)

button_path.write_text(button, encoding="utf-8", newline="\n")

flow_path = Path("src/client/Controllers/FlowController.lua")
flow = flow_path.read_text(encoding="utf-8")

if "UISoundService" not in flow:
    flow = flow.replace(
        'local Button=require(script.Parent.Parent.Components.Button)',
        'local Button=require(script.Parent.Parent.Components.Button)\nlocal UISoundService=require(script.Parent.Parent.Services.UISoundService)',
        1
    )

flow = replace_once(
    flow,
'''function FlowController:ModeTransition(title:string,callback:()->(),compact:boolean?)
	if self.Busy then return end;self.Busy=true''',
'''function FlowController:ModeTransition(title:string,callback:()->(),compact:boolean?)
	if self.Busy then return end;self.Busy=true;UISoundService.PlayTransition()''',
    "transition sound"
)

flow_path.write_text(flow, encoding="utf-8", newline="\n")

state_path = Path("src/client/Services/UIStateService.lua")
state = state_path.read_text(encoding="utf-8")

if "UISoundService" not in state:
    state = state.replace(
        'local base=require(script.Parent.ServiceClient).create("UIState")',
        'local base=require(script.Parent.ServiceClient).create("UIState")\nlocal UISoundService=require(script.Parent.UISoundService)',
        1
    )

state = state.replace(
    'function Service:SetCosmetic(slot:string,item:string) remote:FireServer({Type="Cosmetic",Slot=slot,Item=item}) end',
    'function Service:SetCosmetic(slot:string,item:string) UISoundService.PlayColor();remote:FireServer({Type="Cosmetic",Slot=slot,Item=item}) end',
    1
)

state = state.replace(
    'function Service:SetSetting(key:string,value:any) remote:FireServer({Type="Setting",Key=key,Value=value}) end',
    '''function Service:SetSetting(key:string,value:any)
	if string.find(string.lower(tostring(key)), "color") or string.find(string.lower(tostring(key)), "kit") then
		UISoundService.PlayColor()
	end
	remote:FireServer({Type="Setting",Key=key,Value=value})
end''',
    1
)

state_path.write_text(state, encoding="utf-8", newline="\n")

settings_path = Path("src/client/Pages/SettingsPage.lua")
settings = settings_path.read_text(encoding="utf-8")

if "UISoundService" not in settings:
    settings = settings.replace(
        'local SettingsRuntimeService = require(script.Parent.Parent.Services.SettingsRuntimeService)',
        'local SettingsRuntimeService = require(script.Parent.Parent.Services.SettingsRuntimeService)\nlocal UISoundService = require(script.Parent.Parent.Services.UISoundService)',
        1
    )

if "KEY_DEFAULTS" not in settings:
    settings = settings.replace(
        'local NUMBER_NAMES = {Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9"}',
        '''local NUMBER_NAMES = {Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9"}
local KEY_DEFAULTS = {
	PauseKey = "M",
	ManualPassKey = "LeftControl",
	LobbedPassKey = "LeftAlt",
	ChangePlayerKey = "Q",
	TackleKey = "E",
	SlideTackleKey = "F",
	SkipKey = "Space",
}''',
        1
    )

settings = settings.replace(
    'local current = tostring(settings(context)[key] or (key == "SkipKey" and "Space" or "M"))',
    'local current = tostring(settings(context)[key] or KEY_DEFAULTS[key] or "M")',
    1
)

settings = re.sub(
    r'''		local connection: RBXScriptConnection\?
		connection = UserInputService.InputBegan:Connect\(function\(input, processed\)
			if not waiting or processed then return end
			local name = input.KeyCode.Name
			local displayed = NUMBER_NAMES\[name\] or name
			if #name == 1 or NUMBER_NAMES\[name\] then
				waiting = false
				button.Text = displayed
				commit\(context, key, displayed\)
				if connection then connection:Disconnect\(\) end
			elseif name == "Space" then
				waiting = false
				button.Text = "SPACE"
				commit\(context, key, "Space"\)
				if connection then connection:Disconnect\(\) end
			end
		end\)''',
'''		local connection: RBXScriptConnection?
		connection = UserInputService.InputBegan:Connect(function(input, processed)
			if not waiting or processed then return end
			local name = input.KeyCode.Name
			if name == "Unknown" then return end
			local displayed = NUMBER_NAMES[name] or name
			waiting = false
			button.Text = string.upper(displayed)
			UISoundService.PlayType()
			commit(context, key, displayed)
			if context.RefreshSettings then context.RefreshSettings(key) end
			if connection then connection:Disconnect() end
		end)''',
    settings,
    count=1,
    flags=re.S
)

settings = re.sub(
    r'''	if active == "Controls" then
		local box = panel\(scroll, "Controls", UDim2.fromOffset\(0, 154\), UDim2.new\(1, 0, 0, 220\)\)
		keybind\(box, context, "PauseKey".*?
	elseif active == "Audio" then''',
'''	if active == "Controls" then
		local box = panel(scroll, "Controls", UDim2.fromOffset(0, 154), UDim2.new(1, 0, 0, 610))
		local controls = {
			{Key = "PauseKey", Title = "PAUSE", Subtitle = "Open or close the pause menu."},
			{Key = "ManualPassKey", Title = "MANUAL PASS MODIFIER", Subtitle = "Hold this with right click / pass to aim manual pass."},
			{Key = "LobbedPassKey", Title = "LOBBED PASS MODIFIER", Subtitle = "Hold this with pass for lobbed passes. Combine with manual modifier for manual lobbed pass."},
			{Key = "ChangePlayerKey", Title = "CHANGE PLAYER", Subtitle = "Switch to the best nearby teammate or defender."},
			{Key = "TackleKey", Title = "TACKLE", Subtitle = "Standing tackle / defensive challenge."},
			{Key = "SlideTackleKey", Title = "SLIDE TACKLE", Subtitle = "Slide tackle input."},
			{Key = "SkipKey", Title = "SKIP", Subtitle = "Prematch and replay skip is Space.", Editable = false},
		}
		for index, item in ipairs(controls) do
			keybind(box, context, item.Key, item.Title, item.Subtitle, 52 + (index - 1) * 74, item.Editable ~= false)
		end
	elseif active == "Audio" then''',
    settings,
    count=1,
    flags=re.S
)

settings = settings.replace(
    'local group, scroll = PageBase.new("Settings", 560)',
    'local group, scroll = PageBase.new("Settings", 860)',
    1
)

settings_path.write_text(settings, encoding="utf-8", newline="\n")

print("fixed controls settings list and added UI sounds")