local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.VTR25.Theme)
local UI = require(script.Parent.Components)
local C = Theme.Colors

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("VTR25")
if old then old:Destroy() end

local gui = UI.make("ScreenGui", {
	Name = "VTR25", IgnoreGuiInset = true, ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 20,
})
gui.Parent = playerGui

local root = UI.make("Frame", { Name = "Root", BackgroundColor3 = C.Black, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 })
root.Parent = gui

-- A restrained animated energy field keeps the black background alive.
local energy = UI.make("Frame", {
	Name = "Energy", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.38),
	Size = UDim2.fromScale(0.52, 0.06), BackgroundColor3 = C.Electric,
	BackgroundTransparency = 0.83, Rotation = -19, BorderSizePixel = 0,
}, { UI.corner(100) })
energy.Parent = root

local sidebar = UI.make("Frame", { Name = "Sidebar", BackgroundColor3 = C.Graphite, Size = UDim2.new(0, 220, 1, 0), BorderSizePixel = 0 })
sidebar.Parent = root
UI.make("UIStroke", { Color = C.Border, Transparency = 0.25, Thickness = 1 }).Parent = sidebar

local logo = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 22), Size = UDim2.new(1, -48, 0, 70) })
logo.Parent = sidebar
local logoMark = UI.make("TextLabel", { BackgroundColor3 = C.Electric, Size = UDim2.fromOffset(42, 42), Text = "V", TextColor3 = C.Black, TextSize = 27, Font = Theme.Fonts.Display, Rotation = -4 }, { UI.corner(5) })
logoMark.Parent = logo
local logoText = UI.label("VTR 25", 22, C.White, Theme.Fonts.Display); logoText.Position = UDim2.fromOffset(54, 0); logoText.Size = UDim2.new(1, -54, 0, 30); logoText.Parent = logo
local logoSub = UI.label("VOLTRA FOOTBALL", 8, C.Electric, Theme.Fonts.Strong); logoSub.Position = UDim2.fromOffset(55, 29); logoSub.Size = UDim2.new(1, -55, 0, 18); logoSub.Parent = logo

local navHolder = UI.make("Frame", { Name = "Navigation", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 112), Size = UDim2.new(1, -28, 0, 310) })
navHolder.Parent = sidebar
UI.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = navHolder

local pageNames = { "HOME", "ULTIMATE TEAM", "PLAY", "RANKED" }
local pageIcons = { "⌂", "⬡", "▶", "▲" }
local navButtons = {}
local pages = {}
local selected = "HOME"

for index, name in ipairs(pageNames) do
	local nav = UI.make("TextButton", {
		Name = name, BackgroundColor3 = name == selected and C.Electric or C.Graphite,
		BackgroundTransparency = name == selected and 0 or 1, Size = UDim2.new(1, 0, 0, 48),
		Text = pageIcons[index] .. "    " .. name, TextColor3 = name == selected and C.Black or C.Muted,
		TextSize = 11, Font = Theme.Fonts.Strong, TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false, BorderSizePixel = 0,
	}, { UI.corner(5), UI.make("UIPadding", { PaddingLeft = UDim.new(0, 16) }) })
	nav.LayoutOrder = index
	nav.Parent = navHolder
	navButtons[name] = nav
end

local season = UI.panel("SeasonCard")
season.Position = UDim2.new(0, 14, 1, -160); season.Size = UDim2.new(1, -28, 0, 102); season.Parent = sidebar
local seasonTag = UI.label("SEASON 04", 9, C.Electric, Theme.Fonts.Strong); seasonTag.Position = UDim2.fromOffset(14, 10); seasonTag.Size = UDim2.new(1, -28, 0, 20); seasonTag.Parent = season
local seasonLevel = UI.label("LVL 37", 19, C.White, Theme.Fonts.Display); seasonLevel.Position = UDim2.fromOffset(14, 31); seasonLevel.Size = UDim2.new(1, -28, 0, 25); seasonLevel.Parent = season
local seasonProgress = UI.progress(0.68); seasonProgress.Position = UDim2.fromOffset(14, 66); seasonProgress.Size = UDim2.new(1, -28, 0, 5); seasonProgress.Parent = season
local seasonXp = UI.label("6,840 / 10,000 XP", 8, C.Muted, Theme.Fonts.Body); seasonXp.Position = UDim2.fromOffset(14, 75); seasonXp.Size = UDim2.new(1, -28, 0, 18); seasonXp.Parent = season

local topbar = UI.make("Frame", { Name = "Topbar", BackgroundColor3 = C.Black, BackgroundTransparency = 0.08, Position = UDim2.fromOffset(220, 0), Size = UDim2.new(1, -220, 0, 78), BorderSizePixel = 0 })
topbar.Parent = root
local crumb = UI.label("VTR 25  /  " .. selected, 10, C.Muted, Theme.Fonts.Strong); crumb.Position = UDim2.fromOffset(30, 0); crumb.Size = UDim2.new(0.5, 0, 1, 0); crumb.Parent = topbar
local currency = UI.label("◈  12,480     ⚡  850", 11, C.Silver, Theme.Fonts.Strong); currency.Position = UDim2.new(1, -315, 0, 0); currency.Size = UDim2.fromOffset(180, 78); currency.TextXAlignment = Enum.TextXAlignment.Right; currency.Parent = topbar
local profile = UI.make("Frame", { BackgroundColor3 = C.Gunmetal, Position = UDim2.new(1, -116, 0, 17), Size = UDim2.fromOffset(96, 44), BorderSizePixel = 0 }, { UI.corner(6), UI.stroke(C.Border, 0, 1) })
profile.Parent = topbar
local avatar = UI.make("TextLabel", { BackgroundColor3 = C.Electric, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(32, 32), Text = "10", TextColor3 = C.Black, TextSize = 11, Font = Theme.Fonts.Display }, { UI.corner(16) }); avatar.Parent = profile
local profileName = UI.label("VOLT_X", 9, C.White, Theme.Fonts.Strong); profileName.Position = UDim2.fromOffset(45, 4); profileName.Size = UDim2.fromOffset(48, 22); profileName.Parent = profile
local online = UI.label("● ONLINE", 7, C.Electric, Theme.Fonts.Strong); online.Position = UDim2.fromOffset(45, 22); online.Size = UDim2.fromOffset(48, 16); online.Parent = profile

local content = UI.make("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(220, 78), Size = UDim2.new(1, -220, 1, -78), ClipsDescendants = true })
content.Parent = root

local function page(title)
	local scroll = UI.make("ScrollingFrame", {
		Name = title, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 780), AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.Electric, BorderSizePixel = 0,
		Visible = false,
	})
	UI.padding(30).Parent = scroll
	scroll.Parent = content
	pages[title] = scroll
	return scroll
end

local function heading(parent, kicker, title, subtitle)
	local block = UI.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 86) })
	local kick = UI.label(kicker, 9, C.Electric, Theme.Fonts.Strong); kick.Size = UDim2.new(1, 0, 0, 18); kick.Parent = block
	local h = UI.label(title, 30, C.White, Theme.Fonts.Display); h.Position = UDim2.fromOffset(0, 17); h.Size = UDim2.new(1, 0, 0, 39); h.Parent = block
	local sub = UI.label(subtitle, 10, C.Muted, Theme.Fonts.Body); sub.Position = UDim2.fromOffset(0, 59); sub.Size = UDim2.new(1, 0, 0, 20); sub.Parent = block
	block.Parent = parent
	return block
end

-- HOME
local home = page("HOME")
heading(home, "THE PITCH IS YOURS", "WELCOME BACK, VOLT_X", "Build your club. Master the meta. Own the division.")

local hero = UI.panel("Hero")
hero.Position = UDim2.fromOffset(0, 96); hero.Size = UDim2.new(0.64, -8, 0, 290); hero.Parent = home
local heroWash = UI.make("Frame", { BackgroundColor3 = C.Electric, BackgroundTransparency = 0.88, Position = UDim2.fromScale(0.56, -0.45), Size = UDim2.fromScale(0.65, 1.7), Rotation = 22, BorderSizePixel = 0 }); heroWash.Parent = hero
local heroTag = UI.make("TextLabel", { BackgroundColor3 = C.Electric, Position = UDim2.fromOffset(24, 24), Size = UDim2.fromOffset(112, 25), Text = "FEATURED MODE", TextColor3 = C.Black, TextSize = 8, Font = Theme.Fonts.Strong }, { UI.corner(3) }); heroTag.Parent = hero
local heroTitle = UI.label("RIVALS\nRELOADED", 35, C.White, Theme.Fonts.Display); heroTitle.Position = UDim2.fromOffset(24, 60); heroTitle.Size = UDim2.new(0.58, 0, 0, 92); heroTitle.TextYAlignment = Enum.TextYAlignment.Top; heroTitle.Parent = hero
local heroCopy = UI.label("Rise through 10 divisions. Weekly rewards scale with your performance.", 10, C.Silver, Theme.Fonts.Body); heroCopy.Position = UDim2.fromOffset(24, 158); heroCopy.Size = UDim2.new(0.55, 0, 0, 42); heroCopy.TextWrapped = true; heroCopy.TextYAlignment = Enum.TextYAlignment.Top; heroCopy.Parent = hero
local heroButton = UI.button("Enter Rivals", "Primary"); heroButton.Position = UDim2.fromOffset(24, 220); heroButton.Parent = hero
local bolt = UI.make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(1, -235, 0, 20), Size = UDim2.fromOffset(205, 250), Text = "ϟ", TextColor3 = C.Electric, TextTransparency = 0.06, TextSize = 230, Font = Theme.Fonts.Display, Rotation = 8 }); bolt.Parent = hero

local form = UI.panel("CurrentForm")
form.Position = UDim2.new(0.64, 8, 0, 96); form.Size = UDim2.new(0.36, -8, 0, 290); form.Parent = home
local formTitle = UI.label("CURRENT FORM", 10, C.Muted, Theme.Fonts.Strong); formTitle.Position = UDim2.fromOffset(20, 16); formTitle.Size = UDim2.new(1, -40, 0, 26); formTitle.Parent = form
local division = UI.label("DIVISION 3", 24, C.White, Theme.Fonts.Display); division.Position = UDim2.fromOffset(20, 48); division.Size = UDim2.new(1, -40, 0, 35); division.Parent = form
local rank = UI.label("RANK II", 10, C.Electric, Theme.Fonts.Strong); rank.Position = UDim2.fromOffset(20, 84); rank.Size = UDim2.new(1, -40, 0, 20); rank.Parent = form
local record = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 126), Size = UDim2.new(1, -40, 0, 52) }); record.Parent = form
UI.make("UIGridLayout", { CellSize = UDim2.new(0.33, -6, 1, 0), CellPadding = UDim2.fromOffset(6, 0) }).Parent = record
UI.stat("Wins", "18", true).Parent = record; UI.stat("Draws", "04").Parent = record; UI.stat("Losses", "07").Parent = record
local rankBar = UI.progress(0.74); rankBar.Position = UDim2.fromOffset(20, 198); rankBar.Size = UDim2.new(1, -40, 0, 7); rankBar.Parent = form
local points = UI.label("1,482 / 1,600 RP", 9, C.Muted, Theme.Fonts.Strong); points.Position = UDim2.fromOffset(20, 213); points.Size = UDim2.new(1, -40, 0, 20); points.Parent = form
local streak = UI.label("⚡  4 MATCH WIN STREAK", 10, C.Electric, Theme.Fonts.Strong); streak.Position = UDim2.fromOffset(20, 246); streak.Size = UDim2.new(1, -40, 0, 24); streak.Parent = form

local objective = UI.panel("Objective")
objective.Position = UDim2.fromOffset(0, 402); objective.Size = UDim2.new(0.48, -8, 0, 146); objective.Parent = home
local objectiveTag = UI.label("DAILY OBJECTIVE", 9, C.Electric, Theme.Fonts.Strong); objectiveTag.Position = UDim2.fromOffset(18, 13); objectiveTag.Size = UDim2.new(1, -36, 0, 21); objectiveTag.Parent = objective
local objectiveTitle = UI.label("MIDFIELD MAESTRO", 16, C.White, Theme.Fonts.Display); objectiveTitle.Position = UDim2.fromOffset(18, 38); objectiveTitle.Size = UDim2.new(1, -36, 0, 24); objectiveTitle.Parent = objective
local objectiveCopy = UI.label("Complete 15 successful through balls", 9, C.Muted, Theme.Fonts.Body); objectiveCopy.Position = UDim2.fromOffset(18, 66); objectiveCopy.Size = UDim2.new(1, -36, 0, 18); objectiveCopy.Parent = objective
local objectiveBar = UI.progress(0.73); objectiveBar.Position = UDim2.fromOffset(18, 99); objectiveBar.Size = UDim2.new(1, -100, 0, 6); objectiveBar.Parent = objective
local objectiveCount = UI.label("11 / 15", 9, C.Silver, Theme.Fonts.Strong); objectiveCount.Position = UDim2.new(1, -72, 0, 89); objectiveCount.Size = UDim2.fromOffset(54, 25); objectiveCount.TextXAlignment = Enum.TextXAlignment.Right; objectiveCount.Parent = objective
local reward = UI.label("REWARD  +750 XP", 8, C.Electric, Theme.Fonts.Strong); reward.Position = UDim2.fromOffset(18, 115); reward.Size = UDim2.new(1, -36, 0, 18); reward.Parent = objective

local fixtures = UI.panel("Fixtures")
fixtures.Position = UDim2.new(0.48, 8, 0, 402); fixtures.Size = UDim2.new(0.52, -8, 0, 250); fixtures.Parent = home
local fixtureTitle = UI.label("UPCOMING FIXTURES", 10, C.White, Theme.Fonts.Strong); fixtureTitle.Position = UDim2.fromOffset(18, 10); fixtureTitle.Size = UDim2.new(1, -36, 0, 28); fixtureTitle.Parent = fixtures
local fixtureList = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -28, 1, -58) }); fixtureList.Parent = fixtures
UI.make("UIListLayout", { Padding = UDim.new(0, 8) }).Parent = fixtureList
UI.matchRow("VOLTRA FC", "NIGHT CITY", "20:30", "RIVALS • DIVISION 3").Parent = fixtureList
UI.matchRow("ZERO XI", "VOLTRA FC", "SAT", "CHAMPIONS QUALIFIER").Parent = fixtureList

-- ULTIMATE TEAM
local squad = page("ULTIMATE TEAM")
heading(squad, "VOLTRA ULTIMATE TEAM", "ACTIVE SQUAD", "Chemistry, tactics and raw quality — engineered to win.")
local formation = UI.panel("Formation")
formation.Position = UDim2.fromOffset(0, 96); formation.Size = UDim2.new(0.66, -8, 0, 530); formation.BackgroundColor3 = C.Pitch; formation.Parent = squad
local pitchLine = UI.make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 28), Size = UDim2.new(1, -56, 1, -56) }, { UI.corner(8), UI.stroke(Color3.fromHex("52634A"), 0.2, 2) }); pitchLine.Parent = formation
local midline = UI.make("Frame", { BackgroundColor3 = Color3.fromHex("52634A"), BackgroundTransparency = 0.25, Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0 }); midline.Parent = pitchLine
local circle = UI.make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(108, 108) }, { UI.corner(54), UI.stroke(Color3.fromHex("52634A"), 0.25, 2) }); circle.Parent = pitchLine
local positions = {
	{.5,.10,"92","ST"}, {.25,.28,"89","LW"}, {.75,.28,"90","RW"},
	{.5,.35,"91","CAM"}, {.30,.53,"88","CM"}, {.70,.53,"87","CM"},
	{.16,.72,"86","LB"}, {.39,.75,"89","CB"}, {.61,.75,"88","CB"}, {.84,.72,"87","RB"}, {.5,.91,"90","GK"},
}
for _, p in ipairs(positions) do
	local node = UI.make("Frame", { AnchorPoint = Vector2.new(.5,.5), Position = UDim2.fromScale(p[1],p[2]), Size = UDim2.fromOffset(50,58), BackgroundColor3 = C.Gunmetal, BorderSizePixel = 0 }, { UI.corner(6), UI.stroke(C.Electric, .3, 1) })
	local score = UI.label(p[3], 16, C.Electric, Theme.Fonts.Display); score.Size = UDim2.new(1,0,.58,0); score.TextXAlignment = Enum.TextXAlignment.Center; score.Parent = node
	local role = UI.label(p[4], 8, C.Silver, Theme.Fonts.Strong); role.Position = UDim2.fromScale(0,.57); role.Size = UDim2.new(1,0,.3,0); role.TextXAlignment = Enum.TextXAlignment.Center; role.Parent = node
	node.Parent = pitchLine
end
local squadMeta = UI.panel("SquadMeta")
squadMeta.Position = UDim2.new(.66,8,0,96); squadMeta.Size = UDim2.new(.34,-8,0,220); squadMeta.Parent = squad
local squadName = UI.label("VOLTAGE XI", 21, C.White, Theme.Fonts.Display); squadName.Position = UDim2.fromOffset(18,18); squadName.Size = UDim2.new(1,-36,0,30); squadName.Parent = squadMeta
local formationName = UI.label("4-2-1-3  •  CUSTOM TACTIC", 9, C.Muted, Theme.Fonts.Strong); formationName.Position = UDim2.fromOffset(18,48); formationName.Size = UDim2.new(1,-36,0,20); formationName.Parent = squadMeta
local metaStats = UI.make("Frame", { BackgroundTransparency=1, Position=UDim2.fromOffset(18,86), Size=UDim2.new(1,-36,0,54) }); metaStats.Parent=squadMeta
UI.make("UIGridLayout", { CellSize=UDim2.new(.5,-4,1,0), CellPadding=UDim2.fromOffset(8,0) }).Parent=metaStats
UI.stat("Squad rating","89",true).Parent=metaStats; UI.stat("Chemistry","32/33").Parent=metaStats
local manage = UI.button("Manage Squad","Primary"); manage.Position=UDim2.fromOffset(18,158); manage.Parent=squadMeta
local featuredCard = UI.playerCard({ rating=92, position="ST", name="M. VOLT", club="VTR ELITE", nation="FR", stats={{"PAC","96"},{"SHO","93"},{"DRI","91"},{"PHY","86"}} })
featuredCard.Position = UDim2.new(.66,8,0,336); featuredCard.Size=UDim2.new(.34,-8,0,290); featuredCard.Parent=squad

-- PLAY
local play = page("PLAY")
heading(play, "CHOOSE YOUR BATTLE", "PLAY FOOTBALL", "Distinct modes. One standard: domination.")
local modes = {
	{"RANKED RIVALS","Climb divisions in competitive online play.","01","PRIMARY"},
	{"VOLTRA CHAMPIONS","Qualify, compete, and claim elite rewards.","02","WEEKEND"},
	{"STREET 5V5","Fast football. Small pitch. Maximum expression.","03","CASUAL"},
	{"TRAINING LAB","Master mechanics and rehearse set pieces.","04","SOLO"},
}
local modesGrid = UI.make("Frame", { BackgroundTransparency=1, Position=UDim2.fromOffset(0,96), Size=UDim2.new(1,0,0,510) }); modesGrid.Parent=play
UI.make("UIGridLayout", { CellSize=UDim2.new(.5,-8,.5,-8), CellPadding=UDim2.fromOffset(16,16), SortOrder=Enum.SortOrder.LayoutOrder }).Parent=modesGrid
for i, mode in ipairs(modes) do
	local tile=UI.panel(mode[1]); tile.LayoutOrder=i; tile.Parent=modesGrid
	local number=UI.label(mode[3],52,C.Electric,Theme.Fonts.Display); number.Position=UDim2.new(1,-105,0,14); number.Size=UDim2.fromOffset(80,70); number.TextXAlignment=Enum.TextXAlignment.Right; number.TextTransparency=.15; number.Parent=tile
	local tag=UI.label(mode[4],8,C.Electric,Theme.Fonts.Strong); tag.Position=UDim2.fromOffset(22,20); tag.Size=UDim2.new(1,-44,0,20); tag.Parent=tile
	local title=UI.label(mode[1],20,C.White,Theme.Fonts.Display); title.Position=UDim2.fromOffset(22,69); title.Size=UDim2.new(1,-44,0,30); title.Parent=tile
	local desc=UI.label(mode[2],10,C.Muted,Theme.Fonts.Body); desc.Position=UDim2.fromOffset(22,105); desc.Size=UDim2.new(1,-44,0,38); desc.TextWrapped=true; desc.TextYAlignment=Enum.TextYAlignment.Top; desc.Parent=tile
	local enter=UI.button(i==1 and "Find Match" or "Explore",i==1 and "Primary" or "Secondary"); enter.Position=UDim2.fromOffset(22,166); enter.Parent=tile
end

-- RANKED
local ranked = page("RANKED")
heading(ranked, "COMPETITIVE HQ", "RANKED SEASON 04", "Every match matters. Your rating tells the story.")
local rankHero=UI.panel("RankHero"); rankHero.Position=UDim2.fromOffset(0,96); rankHero.Size=UDim2.new(.58,-8,0,310); rankHero.Parent=ranked
local emblem=UI.make("TextLabel", { BackgroundTransparency=1, Position=UDim2.fromOffset(22,22), Size=UDim2.fromOffset(170,180), Text="⬡", TextColor3=C.Electric, TextSize=155, Font=Theme.Fonts.Display }); emblem.Parent=rankHero
local rankCopy=UI.make("Frame", { BackgroundTransparency=1, Position=UDim2.fromOffset(208,34), Size=UDim2.new(1,-230,0,175) }); rankCopy.Parent=rankHero
local label=UI.label("CURRENT DIVISION",9,C.Muted,Theme.Fonts.Strong); label.Size=UDim2.new(1,0,0,20); label.Parent=rankCopy
local value=UI.label("DIVISION 3",28,C.White,Theme.Fonts.Display); value.Position=UDim2.fromOffset(0,26); value.Size=UDim2.new(1,0,0,40); value.Parent=rankCopy
local rpi=UI.label("1,482 RATING POINTS",10,C.Electric,Theme.Fonts.Strong); rpi.Position=UDim2.fromOffset(0,71); rpi.Size=UDim2.new(1,0,0,22); rpi.Parent=rankCopy
local rb=UI.progress(.74); rb.Position=UDim2.fromOffset(0,112); rb.Parent=rankCopy
local nextRank=UI.label("118 RP TO DIVISION 2",8,C.Muted,Theme.Fonts.Strong); nextRank.Position=UDim2.fromOffset(0,126); nextRank.Size=UDim2.new(1,0,0,18); nextRank.Parent=rankCopy
local queue=UI.button("Queue Ranked","Primary"); queue.Position=UDim2.fromOffset(22,238); queue.Parent=rankHero
local seasonRecord=UI.panel("SeasonRecord"); seasonRecord.Position=UDim2.new(.58,8,0,96); seasonRecord.Size=UDim2.new(.42,-8,0,310); seasonRecord.Parent=ranked
local srTitle=UI.label("SEASON RECORD",10,C.Muted,Theme.Fonts.Strong); srTitle.Position=UDim2.fromOffset(20,16); srTitle.Size=UDim2.new(1,-40,0,25); srTitle.Parent=seasonRecord
local bigRecord=UI.label("18 — 4 — 7",28,C.White,Theme.Fonts.Display); bigRecord.Position=UDim2.fromOffset(20,49); bigRecord.Size=UDim2.new(1,-40,0,42); bigRecord.Parent=seasonRecord
local wdl=UI.label("WINS             DRAWS           LOSSES",8,C.Muted,Theme.Fonts.Strong); wdl.Position=UDim2.fromOffset(20,90); wdl.Size=UDim2.new(1,-40,0,22); wdl.Parent=seasonRecord
local divider=UI.make("Frame",{BackgroundColor3=C.Border,Position=UDim2.fromOffset(20,130),Size=UDim2.new(1,-40,0,1),BorderSizePixel=0});divider.Parent=seasonRecord
local metrics={{"WIN RATE","62%"},{"GOALS / MATCH","2.4"},{"CLEAN SHEETS","09"}}
for i,m in ipairs(metrics) do local s=UI.stat(m[1],m[2],i==1);s.Position=UDim2.new(0,20,0,140+(i-1)*48);s.Size=UDim2.new(1,-40,0,42);s.Parent=seasonRecord end
local leaderboard=UI.panel("Leaderboard"); leaderboard.Position=UDim2.fromOffset(0,422); leaderboard.Size=UDim2.new(1,0,0,220); leaderboard.Parent=ranked
local lbTitle=UI.label("FRIENDS LEADERBOARD",10,C.White,Theme.Fonts.Strong); lbTitle.Position=UDim2.fromOffset(18,12); lbTitle.Size=UDim2.new(1,-36,0,28); lbTitle.Parent=leaderboard
local rows={{"01","NOVA_7","2,104"},{"02","KRYPTIC","1,822"},{"03","VOLT_X","1,482"}}
for i,row in ipairs(rows) do
	local bg=UI.make("Frame",{BackgroundColor3=i==3 and Color3.fromHex("22291A") or C.Gunmetal,Position=UDim2.fromOffset(14,45+(i-1)*53),Size=UDim2.new(1,-28,0,45),BorderSizePixel=0},{UI.corner(5)});bg.Parent=leaderboard
	local rankL=UI.label(row[1],11,i==3 and C.Electric or C.Muted,Theme.Fonts.Strong);rankL.Position=UDim2.fromOffset(14,0);rankL.Size=UDim2.fromOffset(40,45);rankL.Parent=bg
	local nameL=UI.label(row[2],11,C.White,Theme.Fonts.Strong);nameL.Position=UDim2.fromOffset(60,0);nameL.Size=UDim2.new(.6,0,1,0);nameL.Parent=bg
	local scoreL=UI.label(row[3].." RP",10,i==3 and C.Electric or C.Silver,Theme.Fonts.Strong);scoreL.Position=UDim2.new(1,-130,0,0);scoreL.Size=UDim2.fromOffset(112,45);scoreL.TextXAlignment=Enum.TextXAlignment.Right;scoreL.Parent=bg
end

local bottomNav = UI.make("Frame", { Name="BottomNav", BackgroundColor3=C.Graphite, AnchorPoint=Vector2.new(0,1), Position=UDim2.fromScale(0,1), Size=UDim2.new(1,0,0,70), Visible=false, BorderSizePixel=0 }); bottomNav.Parent=root
UI.make("UIGridLayout", { CellSize=UDim2.new(.25,0,1,0) }).Parent=bottomNav

local function showPage(name)
	selected=name
	crumb.Text="VTR 25  /  "..name
	for pageName, pageFrame in pairs(pages) do
		pageFrame.Visible=pageName==name
	end
	for navName, button in pairs(navButtons) do
		local active=navName==name
		TweenService:Create(button,TweenInfo.new(Theme.Motion.Standard),{BackgroundTransparency=active and 0 or 1,BackgroundColor3=active and C.Electric or C.Graphite,TextColor3=active and C.Black or C.Muted}):Play()
	end
end

for name,button in pairs(navButtons) do button.Activated:Connect(function() showPage(name) end) end
for i,name in ipairs(pageNames) do
	local b=UI.make("TextButton",{Name=name,BackgroundTransparency=1,Text=pageIcons[i].."\n"..name,TextColor3=C.Silver,TextSize=8,Font=Theme.Fonts.Strong,AutoButtonColor=false});b.Parent=bottomNav
	b.Activated:Connect(function() showPage(name) end)
end

local scale = UI.make("UIScale", { Scale=1 }); scale.Parent=root
local camera=workspace.CurrentCamera
local function resize()
	local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
	local compact=viewport.X<Theme.Breakpoints.Compact
	sidebar.Visible=not compact
	topbar.Position=compact and UDim2.fromOffset(0,0) or UDim2.fromOffset(220,0)
	topbar.Size=compact and UDim2.new(1,0,0,68) or UDim2.new(1,-220,0,78)
	content.Position=compact and UDim2.fromOffset(0,68) or UDim2.fromOffset(220,78)
	content.Size=compact and UDim2.new(1,0,1,-138) or UDim2.new(1,-220,1,-78)
	bottomNav.Visible=compact
	crumb.Position=UDim2.fromOffset(compact and 16 or 30,0)
	currency.Visible=not compact
	profile.Position=UDim2.new(1,-116,0,compact and 12 or 17)
	for _,p in pairs(pages) do
		local pad=p:FindFirstChildOfClass("UIPadding")
		if pad then local amount=compact and 16 or 30;pad.PaddingTop=UDim.new(0,amount);pad.PaddingBottom=UDim.new(0,amount);pad.PaddingLeft=UDim.new(0,amount);pad.PaddingRight=UDim.new(0,amount) end
	end
	if compact then
		scale.Scale=math.clamp(viewport.X/520,.72,1)
		root.Size=UDim2.fromScale(1/scale.Scale,1/scale.Scale)
	else scale.Scale=1;root.Size=UDim2.fromScale(1,1) end
end

if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
resize()
showPage("HOME")

local t=0
RunService.RenderStepped:Connect(function(dt)
	t+=dt
	energy.Position=UDim2.fromScale(.78+math.sin(t*.35)*.03,.38+math.cos(t*.28)*.02)
	energy.BackgroundTransparency=.84+math.sin(t*1.2)*.035
end)

root.BackgroundTransparency=1
TweenService:Create(root,TweenInfo.new(.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
