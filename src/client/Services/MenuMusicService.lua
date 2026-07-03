--!strict

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Service = {}

local TRACKS = {
	{ Id = "rbxassetid://83633898068243", Name = "Voltra Nights" },
	{ Id = "rbxassetid://114891248304666", Name = "One More Match" },
	{ Id = "rbxassetid://115828647468752", Name = "Under The Lights" },
	{ Id = "rbxassetid://72374290326335", Name = "Midnight Kickoff" },
	{ Id = "rbxassetid://119993567315423", Name = "Golden Touch" },
	{ Id = "rbxassetid://97523201747265", Name = "Voltra Glow" },
	{ Id = "rbxassetid://107374838002886", Name = "Dreaming" },
	{ Id = "rbxassetid://136016304335574", Name = "One More Game" },
	{ Id = "rbxassetid://92636118699011", Name = "Samba Step" },
	{ Id = "rbxassetid://122644560428857", Name = "Really Run It Back" },
	{ Id = "rbxassetid://103003932274027", Name = "Run It Back" },
}

local FADE_TIME = 2.25
local BASE_VOLUME = 0.38
local LOGO_IMAGE = "rbxassetid://102592555926321"

local started = false
local generation = 0
local deck: {{Id: string, Name: string}} = {}
local activeSound: Sound? = nil
local lastTrack: {Id: string, Name: string}? = nil
local logoGeneration = 0
local widgetMinimized = false
local widgetButton: ImageButton? = nil
local widgetLogo: ImageLabel? = nil
local widgetTrackLabel: TextLabel? = nil
local widgetStatusLabel: TextLabel? = nil

local function menuEnabled(): boolean
	return workspace:GetAttribute("VTRMenuMusic") ~= false
end

local function masterVolume(): number
	return math.clamp(tonumber(SoundService:GetAttribute("VTRMasterVolume")) or 0.8, 0, 1)
end

local function shuffleTracks()
	deck = table.clone(TRACKS)
	for index = #deck, 2, -1 do
		local swap = math.random(1, index)
		deck[index], deck[swap] = deck[swap], deck[index]
	end
	if lastTrack and #deck > 1 and deck[1].Id == lastTrack.Id then
		deck[1], deck[#deck] = deck[#deck], deck[1]
	end
end

local function nextTrack(): {Id: string, Name: string}
	if #deck == 0 then
		shuffleTracks()
	end
	local track = table.remove(deck, 1)
	lastTrack = track
	return track
end

local function trackName(track: any): string
	if type(track) == "table" and type(track.Name) == "string" then
		return track.Name
	end
	local id = type(track) == "table" and track.Id or track
	if type(id) == "string" then
		for _, item in TRACKS do
			if item.Id == id then
				return item.Name
			end
		end
	end
	return "Unknown Track"
end

local function makeSound(track: {Id: string, Name: string}): Sound
	local sound = Instance.new("Sound")
	sound.Name = "VTRMenuMusic"
	sound.SoundId = track.Id
	sound.Volume = 0
	sound.Looped = false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound:SetAttribute("VTRMenuMusic", true)
	sound:SetAttribute("VTRBaseVolume", BASE_VOLUME)
	sound.Parent = SoundService
	return sound
end

local function tweenVolume(sound: Sound, volume: number, duration: number)
	if not sound.Parent then return end
	TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = volume }):Play()
end

local function getLogoGui(): ScreenGui?
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return nil end
	local existing = playerGui:FindFirstChild("VTRMenuMusicNowPlaying")
	if existing and existing:IsA("ScreenGui") then return existing end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRMenuMusicNowPlaying"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 95
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end

local function renderWidget(track: any?)
	local button = widgetButton
	if not button then return end
	local minimized = widgetMinimized
	local size = minimized and UDim2.fromOffset(58, 58) or UDim2.fromOffset(224, 66)
	local transparency = minimized and 0.16 or 0.08
	TweenService:Create(button, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = size,
		BackgroundTransparency = transparency,
	}):Play()
	for _, child in button:GetChildren() do
		if child:IsA("TextLabel") then
			child.Visible = not minimized
		end
	end
	if widgetTrackLabel and track then
		widgetTrackLabel.Text = trackName(track)
	end
	if widgetStatusLabel then
		widgetStatusLabel.Text = minimized and "" or "NOW PLAYING"
	end
	if widgetLogo then
		widgetLogo.Position = minimized and UDim2.fromOffset(7, 7) or UDim2.fromOffset(10, 9)
		widgetLogo.Size = minimized and UDim2.fromOffset(44, 44) or UDim2.fromOffset(48, 48)
	end
end

local function ensureWidget(track: any?): ImageButton?
	local gui = getLogoGui()
	if not gui then return nil end
	if widgetButton and widgetButton.Parent then
		renderWidget(track)
		return widgetButton
	end
	local button = Instance.new("ImageButton")
	button.Name = "MusicWidget"
	button.AnchorPoint = Vector2.new(1, 1)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromHex("070807")
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.Image = ""
	button.ImageTransparency = 1
	button.Position = UDim2.new(1, -24, 1, -24)
	button.Size = UDim2.fromOffset(224, 66)
	button.ZIndex = 96
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("B7FF1A")
	stroke.Thickness = 1.4
	stroke.Transparency = 0.22
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new()
	padding.PaddingRight = UDim.new()
	padding.PaddingTop = UDim.new()
	padding.PaddingBottom = UDim.new()
	padding.Parent = button
	local scale = Instance.new("UIScale")
	scale.Name = "PulseScale"
	scale.Scale = 1
	scale.Parent = button
	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.BackgroundTransparency = 1
	logo.Image = LOGO_IMAGE
	logo.Position = UDim2.fromOffset(10, 9)
	logo.Size = UDim2.fromOffset(48, 48)
	logo.ScaleType = Enum.ScaleType.Fit
	logo.ZIndex = 97
	logo.Parent = button
	local logoCorner = Instance.new("UICorner")
	logoCorner.CornerRadius = UDim.new(0, 9)
	logoCorner.Parent = logo
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(64, 9)
	status.Size = UDim2.new(1, -72, 0, 16)
	status.Font = Enum.Font.GothamBold
	status.Text = "NOW PLAYING"
	status.TextColor3 = Color3.fromHex("B7FF1A")
	status.TextSize = 8
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.ZIndex = 97
	status.Parent = button
	local trackLabel = Instance.new("TextLabel")
	trackLabel.Name = "Track"
	trackLabel.BackgroundTransparency = 1
	trackLabel.Position = UDim2.fromOffset(64, 27)
	trackLabel.Size = UDim2.new(1, -72, 0, 22)
	trackLabel.Font = Enum.Font.GothamBlack
	trackLabel.Text = track and trackName(track) or "Unknown Track"
	trackLabel.TextColor3 = Color3.fromHex("F5F7F2")
	trackLabel.TextSize = 15
	trackLabel.TextTruncate = Enum.TextTruncate.AtEnd
	trackLabel.TextXAlignment = Enum.TextXAlignment.Left
	trackLabel.ZIndex = 97
	trackLabel.Parent = button
	button.Activated:Connect(function()
		widgetMinimized = not widgetMinimized
		renderWidget(lastTrack)
	end)
	widgetButton = button
	widgetLogo = logo
	widgetTrackLabel = trackLabel
	widgetStatusLabel = status
	renderWidget(track)
	return button
end

local function playWidgetAnimation(track: {Id: string, Name: string})
	logoGeneration += 1
	local current = logoGeneration
	local button = ensureWidget(track)
	if not button then return end
	local scale = button:FindFirstChild("PulseScale")
	if not scale or not scale:IsA("UIScale") then
		return
	end
	scale.Scale = 0.92
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 }):Play()
	task.delay(0.72, function()
		if current ~= logoGeneration or not scale.Parent then return end
		TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

local function destroyAfterFade(sound: Sound)
	tweenVolume(sound, 0, FADE_TIME)
	task.delay(FADE_TIME + 0.1, function()
		if sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end)
end

local function playNext(myGeneration: number)
	if myGeneration ~= generation then return end
	if not menuEnabled() then
		task.delay(0.5, function()
			playNext(myGeneration)
		end)
		return
	end

	local previous = activeSound
	local track = nextTrack()
	local sound = makeSound(track)
	activeSound = sound
	sound:Play()
	playWidgetAnimation(track)
	tweenVolume(sound, BASE_VOLUME * masterVolume(), FADE_TIME)
	if previous and previous.Parent then
		destroyAfterFade(previous)
	end

	local advanced = false
	local function advance()
		if advanced then return end
		advanced = true
		if sound.Parent then
			destroyAfterFade(sound)
		end
		if activeSound == sound then
			activeSound = nil
		end
		task.delay(FADE_TIME, function()
			playNext(myGeneration)
		end)
	end

	sound.Ended:Once(advance)
	task.spawn(function()
		while myGeneration == generation and sound.Parent and sound.IsPlaying do
			if menuEnabled() then
				tweenVolume(sound, BASE_VOLUME * masterVolume(), 0.35)
			else
				tweenVolume(sound, 0, 0.35)
			end
			task.wait(0.5)
		end
	end)
end

function Service.Start()
	if started then return end
	started = true
	generation += 1
	shuffleTracks()
	task.spawn(function()
		local preload = {}
		for _, track in TRACKS do
			local sound = Instance.new("Sound")
			sound.SoundId = track.Id
			table.insert(preload, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
		for _, sound in preload do
			sound:Destroy()
		end
	end)
	playNext(generation)
end

function Service.Stop()
	if not started then return end
	started = false
	generation += 1
	if activeSound and activeSound.Parent then
		destroyAfterFade(activeSound)
	end
	activeSound = nil
end

return Service
