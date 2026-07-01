--!strict
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Service = {}

local CLICK_SOUNDS = {
	"rbxassetid://99694938057192",
	"rbxassetid://100116561106520",
}

local HOVER_SOUNDS = {
	"rbxassetid://98484565371608",
}

local TYPE_SOUND = "rbxassetid://124938422635867"
local COLOR_SOUND = "rbxassetid://109229821869092"
local TRANSITION_SOUND = "rbxassetid://136186135240645"

local lastPlayed: {[string]: number} = {}
local preloaded = false

local function preload()
	if preloaded then return end
	preloaded = true
	local sounds = {}
	for _, id in CLICK_SOUNDS do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	for _, id in HOVER_SOUNDS do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	for _, id in {TYPE_SOUND, COLOR_SOUND, TRANSITION_SOUND} do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(sounds, sound)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		for _, sound in sounds do
			sound:Destroy()
		end
	end)
end

local function play(id: string, volume: number, key: string?, cooldown: number?)
	preload()
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

function Service.Preload()
	preload()
end

function Service.PlayClick()
	play(CLICK_SOUNDS[math.random(1, #CLICK_SOUNDS)], 0.42, "Click", 0.035)
end

function Service.PlayHover()
	play(HOVER_SOUNDS[1], 0.2, "Hover", 0.08)
end

function Service.PlayType()
	play(TYPE_SOUND, 0.32, "Type", 0.025)
end

function Service.PlayColor()
	play(COLOR_SOUND, 0.42, "Color", 0.05)
end

function Service.PlayTransition()
	play(TRANSITION_SOUND, 0.52, "Transition", 0.02)
end

function Service.Bind(root: Instance)
	preload()
	local function bindOne(item: Instance)
		if item:GetAttribute("VTRUISoundBound") == true then return end
		if item:IsA("GuiButton") then
			item:SetAttribute("VTRUISoundBound", true)
			item.MouseEnter:Connect(function()
				Service.PlayHover()
			end)
			item.Activated:Connect(function()
				Service.PlayClick()
			end)
		elseif item:IsA("TextBox") then
			item:SetAttribute("VTRUISoundBound", true)
			local previous = item.Text
			item:GetPropertyChangedSignal("Text"):Connect(function()
				if item.Text ~= previous then
					previous = item.Text
					Service.PlayType()
				end
			end)
		end
	end
	for _, item in ipairs(root:GetDescendants()) do
		bindOne(item)
	end
	root.DescendantAdded:Connect(bindOne)
end

preload()

return Service
