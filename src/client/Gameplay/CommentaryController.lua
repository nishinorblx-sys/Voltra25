--!strict

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.VTR.Shared.CommentaryConfig)
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Controller = {}
Controller.__index = Controller

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function normalizeAssetId(value: any): string
	local id = tostring(value or "")
	if id == "" then return "" end
	if string.find(id, "rbxassetid://") == 1 then return id end
	if tonumber(id) then return "rbxassetid://" .. id end
	return id
end

function Controller.new(gui: ScreenGui): any
	local root = Instance.new("Frame")
	root.Name = "CommentarySubtitles"
	root.AnchorPoint = Vector2.new(.5, 1)
	root.BackgroundColor3 = Theme.Colors.Black
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Position = UDim2.new(.5, 0, 1, -88)
	root.Size = UDim2.fromOffset(560, 54)
	root.Visible = false
	root.ZIndex = 170
	root.Parent = gui
	corner(root, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Electric
	stroke.Transparency = .55
	stroke.Parent = root
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(18, 7)
	text.Size = UDim2.new(1, -36, 1, -14)
	text.Text = ""
	text.TextColor3 = Theme.Colors.White
	text.TextSize = 14
	text.TextWrapped = true
	text.Font = Theme.Fonts.Strong
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.ZIndex = 171
	text.Parent = root
	return setmetatable({Gui = gui, Root = root, Text = text, Last = {}, Random = Random.new()}, Controller)
end

function Controller:_show(text: string, duration: number)
	local root = self.Root :: Frame
	local label = self.Text :: TextLabel
	root.Visible = true
	label.Text = text
	root.BackgroundTransparency = .16
	label.TextTransparency = 0
	TweenService:Create(root, TweenInfo.new(.12), {BackgroundTransparency = .16}):Play()
	task.delay(duration, function()
		if not root.Parent or label.Text ~= text then return end
		TweenService:Create(root, TweenInfo.new(.22), {BackgroundTransparency = 1}):Play()
		TweenService:Create(label, TweenInfo.new(.18), {TextTransparency = 1}):Play()
		task.delay(.22, function()
			if root.Parent and label.Text == text then root.Visible = false end
		end)
	end)
end

function Controller:Say(action: string, context: any?)
	local spec = Config.Actions[action]
	if not spec then return end
	local now = os.clock()
	local cooldown = tonumber(spec.Cooldown) or 6
	if now - (self.Last[action] or 0) < cooldown then return end
	local lines = spec.Lines
	if type(lines) ~= "table" or #lines == 0 then return end
	self.Last[action] = now
	local line = lines[self.Random:NextInteger(1, #lines)]
	local text = tostring(line.Text or "")
	if context and context.PlayerName then
		text = string.gsub(text, "{player}", tostring(context.PlayerName))
	end
	if context and context.Team then
		text = string.gsub(text, "{team}", tostring(context.Team))
	end
	if text ~= "" then
		self:_show(text, math.clamp(#text / 18, 2.2, 5))
	end
	local assetId = normalizeAssetId(line.SoundId)
	if assetId ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "VTRCommentaryLine"
		sound.SoundId = assetId
		sound.Volume = tonumber(line.Volume) or 1
		sound:SetAttribute("VTRBaseVolume", sound.Volume)
		sound:SetAttribute("VTRCommentary", true)
		sound.Parent = SoundService
		local master = tonumber(SoundService:GetAttribute("VTRMasterVolume")) or 1
		local commentary = tonumber(SoundService:GetAttribute("VTRCommentaryVolume")) or 1
		sound.Volume *= master * commentary
		sound:Play()
		Debris:AddItem(sound, math.max(8, tonumber(line.Duration) or 8))
	elseif not self.WarnedMissingAudio then
		self.WarnedMissingAudio = true
		warn("[VTR Commentary] Commentary text is firing, but no SoundId is set. Upload generated/commentary_audio WAV files to Roblox and paste the asset ids into CommentaryConfig.lua.")
	end
end

local CommentaryLines = {
	MatchStart = {
		"The match is underway!",
		"And we are off! Both teams looking ready for battle.",
		"The whistle goes, and the game begins.",
		"Kickoff! Let’s see who takes control early."
	},

	Goal = {
		"GOOOAL! {PlayerName} puts it away for {Team}!",
		"What a finish from {PlayerName}! {Team} have their goal!",
		"It’s in! {PlayerName} delivers the breakthrough for {Team}!",
		"{Team} strike! {PlayerName} sends it into the back of the net!",
		"Clinical from {PlayerName}! {Team} celebrate a massive goal!",
		"No doubt about that one! {PlayerName} finishes brilliantly for {Team}!",
		"{PlayerName} makes it count! {Team} are on the scoresheet!",
		"A huge moment! {PlayerName} finds the net for {Team}!"
	},

	Corner = {
		"Corner kick coming up. A chance to put pressure on the box.",
		"{Team} win a corner and bodies are moving forward.",
		"Danger here from the corner.",
		"The ball goes behind, and it will be a corner."
	},

	FreeKick = {
		"Free kick awarded. This could be dangerous.",
		"A set piece chance now.",
		"The referee gives the free kick.",
		"A good opportunity from this dead-ball situation."
	},

	Offside = {
		"Offside.",
		"The flag is up. Offside.",
		"Offside called by the assistant.",
		"The attack stops for offside."
	},

	Penalty = {
		"Penalty! A massive chance from the spot!",
		"The referee points to the spot!",
		"This could be a huge turning point. Penalty given!",
		"All eyes on the penalty taker now."
	},

	HalfTime = {
		"That is halftime. Plenty to talk about after that first half.",
		"The whistle goes for halftime.",
		"Halfway through, and this match is still very much alive.",
		"The players head in for the break."
	},

	MatchEnded = {
		"Full time! The match comes to an end.",
		"The final whistle goes!",
		"That is it. What a contest.",
		"Full time, and the result is sealed."
	},

	PossessionWon = {
		"{PlayerName} wins it back nicely.",
		"Good work from {PlayerName} to regain possession.",
		"{PlayerName} steps in and takes control.",
		"Possession recovered by {PlayerName}."
	},

	Shot = {
		"{PlayerName} takes the shot!",
		"{PlayerName} lets it fly!",
		"An effort on goal from {PlayerName}!",
		"{PlayerName} goes for it!",
		"Shot away from {PlayerName}!"
	},

	Tackle = {
		"Strong tackle from {PlayerName}!",
		"{PlayerName} times the challenge well.",
		"Brilliant defending by {PlayerName}.",
		"{PlayerName} steps in with a clean tackle."
	},

	ShotBlocked = {
		"Blocked by {PlayerName}!",
		"{PlayerName} gets in the way of the shot.",
		"Important block from {PlayerName}!",
		"{PlayerName} throws himself in front of it."
	},

	ShotSaved = {
		"Saved by {PlayerName}!",
		"{PlayerName} keeps it out!",
		"Great stop from {PlayerName}!",
		"{PlayerName} reacts well and makes the save!"
	}
}

local CommentaryCooldowns = {
	MatchStart = 1,
	Goal = 0,
	Corner = 2,
	FreeKick = 2,
	Offside = 1.2,
	Penalty = 0,
	HalfTime = 1,
	MatchEnded = 1,
	PossessionWon = 2.5,
	Shot = 1.25,
	Tackle = 1.5,
	ShotBlocked = 1.25,
	ShotSaved = 1
}

local function getName(value)
	if type(value) == "string" and value ~= "" then
		return value
	end

	if value and value.GetAttribute then
		local displayName = value:GetAttribute("DisplayName")
		if displayName and displayName ~= "" then
			return displayName
		end
	end

	if value and value.Name and value.Name ~= "" then
		return value.Name
	end

	return "the player"
end

local function getTeam(value)
	if type(value) == "string" and value ~= "" then
		return value
	end

	if value and value.Name and value.Name ~= "" then
		return value.Name
	end

	return "the team"
end

function Controller:FormatCommentary(text: string, data: any)
	data = data or {}

	return string.gsub(text, "{(.-)}", function(key)
		local value = data[key]
		if value == nil or value == "" then
			if key == "PlayerName" then
				return "the player"
			end

			if key == "Team" then
				return "the team"
			end

			return ""
		end

		return tostring(value)
	end)
end

function Controller:GetCommentaryLine(key: string)
	local lines = CommentaryLines[key]

	if not lines or #lines == 0 then
		return key
	end

	self.LastCommentaryIndexes = self.LastCommentaryIndexes or {}

	local index = math.random(1, #lines)

	if #lines > 1 then
		while index == self.LastCommentaryIndexes[key] do
			index = math.random(1, #lines)
		end
	end

	self.LastCommentaryIndexes[key] = index

	return lines[index]
end

function Controller:Say(key: string, data: any)
	self.LastCommentaryAt = self.LastCommentaryAt or {}

	local now = os.clock()
	local cooldown = CommentaryCooldowns[key] or 1
	local lastTime = self.LastCommentaryAt[key] or 0

	if now - lastTime < cooldown then
		return
	end

	self.LastCommentaryAt[key] = now

	local template = self:GetCommentaryLine(key)
	local message = self:FormatCommentary(template, data)

	if message ~= "" then
		self:_show(message, math.clamp(#message / 18, 2.2, 5))
	end

	if self.CommentaryLabel then
		self.CommentaryLabel.Text = message
	end

	if self.CommentaryText then
		self.CommentaryText.Text = message
	end

	if self.CommentaryEvent then
		self.CommentaryEvent:Fire(message)
	end
end

function Controller:HandleState(payload: any)
	if type(payload) ~= "table" then
		return
	end

	local kind = payload.Type

	if kind == "MatchStarted" then
		self:Say("MatchStart")

	elseif kind == "Goal" then
		self:Say("Goal", {
			Team = getTeam(payload.Team),
			PlayerName = getName(payload.Scorer or payload.Actor)
		})

	elseif kind == "SetPiece" then
		local setPieceKind = tostring(payload.Kind or "")

		if setPieceKind == "Penalty" then
			self:Say("Penalty", {
				Team = getTeam(payload.Team),
				PlayerName = getName(payload.Actor)
			})
		elseif setPieceKind == "Offside" then
			self:Say("Offside", {
				Team = getTeam(payload.Team),
				PlayerName = getName(payload.Actor)
			})
		elseif setPieceKind == "FreeKick" then
			self:Say("FreeKick", {
				Team = getTeam(payload.Team),
				PlayerName = getName(payload.Actor)
			})
		elseif setPieceKind == "Corner" or setPieceKind == "CornerKick" then
			self:Say("Corner", {
				Team = getTeam(payload.Team),
				PlayerName = getName(payload.Actor)
			})
		else
			self:Say("FreeKick", {
				Team = getTeam(payload.Team),
				PlayerName = getName(payload.Actor)
			})
		end

	elseif kind == "CornerKick" then
		self:Say("Corner", {
			Team = getTeam(payload.Team),
			PlayerName = getName(payload.Actor)
		})

	elseif kind == "HalfTime" then
		self:Say("HalfTime")

	elseif kind == "MatchEnded" then
		self:Say("MatchEnded")

	elseif kind == "PossessionContext" and payload.Owner and payload.Owner ~= "" then
		local reason = tostring(payload.Reason or "")
		if reason == "Turnover" or reason == "LooseRecovery" then
			self:Say("PossessionWon", {
				PlayerName = getName(payload.Owner)
			})
		end

	elseif kind == "Possession" and payload.Owner and payload.Owner ~= "" then

	elseif kind == "Shot" then
		self:Say("Shot", {
			PlayerName = getName(payload.Actor)
		})

	elseif kind == "Tackle" or kind == "SlideTackle" then
		self:Say("Tackle", {
			PlayerName = getName(payload.Actor)
		})

	elseif kind == "Block" then
		self:Say("ShotBlocked", {
			PlayerName = getName(payload.Actor)
		})

	elseif kind == "Save" or kind == "GoalkeeperSave" then
		self:Say("ShotSaved", {
			PlayerName = getName(payload.Actor)
		})

	elseif kind == "BallAction" or kind == "Action" then
		local action = tostring(payload.Action or payload.Kind or "")

		if action == "Shot" then
			self:Say("Shot", {
				PlayerName = getName(payload.Actor)
			})
		elseif action == "Tackle" or action == "SlideTackle" then
			self:Say("Tackle", {
				PlayerName = getName(payload.Actor)
			})
		elseif action == "Block" then
			self:Say("ShotBlocked", {
				PlayerName = getName(payload.Actor)
			})
		elseif action == "Save" or action == "GoalkeeperSave" then
			self:Say("ShotSaved", {
				PlayerName = getName(payload.Actor)
			})
		end
	end
end

function Controller:Destroy()
	if self.Root then
		self.Root:Destroy()
	end
end

return Controller
