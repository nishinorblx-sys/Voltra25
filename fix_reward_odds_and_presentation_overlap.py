from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

reward_path = Path("src/server/Services/RankedWinPackReward.lua")
reward = reward_path.read_text(encoding="utf-8")

reward = re.sub(
    r'local Packs = \{.*?\}\n\nlocal Fallbacks',
'''local Packs = {
	{PackId = "bronze_pack", Name = "Voltra Spark Pack", Rarity = "Common", Weight = 800},
	{PackId = "silver_pack", Name = "Street Pulse Pack", Rarity = "Rare", Weight = 90},
	{PackId = "gold_pack", Name = "Neon Tactics Pack", Rarity = "Rare", Weight = 50},
	{PackId = "elite_pack", Name = "Elite Matchday Pack", Rarity = "Epic", Weight = 35},
	{PackId = "champion_pack", Name = "Voltra Vault Pack", Rarity = "Epic", Weight = 18},
	{PackId = "hero_pack", Name = "Ranked Champion Pack", Rarity = "Mythic", Weight = 6},
	{PackId = "voltra_pack", Name = "Icon Voltage Pack", Rarity = "Mythic", Weight = 1},
}

local Fallbacks''',
    reward,
    count=1,
    flags=re.S
)

reward_path.write_text(reward, encoding="utf-8", newline="\n")

roulette_path = Path("src/client/Components/VoltraPackRoulette.lua")
if roulette_path.exists():
    roulette = roulette_path.read_text(encoding="utf-8")
    roulette = re.sub(
        r'local PACKS = \{.*?\}\n\nlocal function label',
'''local PACKS = {
	{Name = "Voltra Spark Pack", Rarity = "Common", Color = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("050505"), Weight = 800},
	{Name = "Street Pulse Pack", Rarity = "Rare", Color = Color3.fromHex("1FA2FF"), Accent = Color3.fromHex("F5F7F2"), Weight = 90},
	{Name = "Neon Tactics Pack", Rarity = "Rare", Color = Color3.fromHex("24C6B8"), Accent = Color3.fromHex("050505"), Weight = 50},
	{Name = "Elite Matchday Pack", Rarity = "Epic", Color = Color3.fromHex("8E00D6"), Accent = Color3.fromHex("F5F7F2"), Weight = 35},
	{Name = "Voltra Vault Pack", Rarity = "Epic", Color = Color3.fromHex("FFCB45"), Accent = Color3.fromHex("111111"), Weight = 18},
	{Name = "Ranked Champion Pack", Rarity = "Mythic", Color = Color3.fromHex("FF477E"), Accent = Color3.fromHex("F5F7F2"), Weight = 6},
	{Name = "Icon Voltage Pack", Rarity = "Mythic", Color = Color3.fromHex("D9D9D9"), Accent = Color3.fromHex("7D2CFF"), Weight = 1},
}

local function weightedPack(): any
	local total = 0
	for _, pack in PACKS do
		total += pack.Weight or 1
	end
	local roll = math.random() * total
	local cursor = 0
	for _, pack in PACKS do
		cursor += pack.Weight or 1
		if roll <= cursor then return pack end
	end
	return PACKS[1]
end

local function label''',
        roulette,
        count=1,
        flags=re.S
    )

    roulette = re.sub(
        r'local function rewardPack\(payload: any\): any.*?end\n\nlocal function makePackCard',
'''local function rewardPack(payload: any): any
	local reward = payload and payload.Reward or {}
	local ranked = payload and payload.RankedWinPack or {}
	local wanted = reward.PackName or reward.Pack or reward.packName or ranked.PackName
	if wanted then
		for _, pack in PACKS do
			if string.upper(pack.Name) == string.upper(tostring(wanted)) then return pack end
		end
		return {Name = tostring(wanted), Rarity = tostring(reward.Rarity or ranked.Rarity or "Common"), Color = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("050505"), Weight = 1}
	end
	return weightedPack()
end

local function makePackCard''',
        roulette,
        count=1,
        flags=re.S
    )

    roulette_path.write_text(roulette, encoding="utf-8", newline="\n")

prematch_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
prematch = prematch_path.read_text(encoding="utf-8")

badge_helper = '''local function badgeAccent(primary: Color3): Color3
	local bright = Color3.fromHex("F5F7F2")
	local dark = Color3.fromHex("050805")
	local brightness = primary.R + primary.G + primary.B
	return brightness > 1.65 and dark or bright
end

local function applyPresentationBadge(target: TextLabel, primary: Color3, logoText: string?)
	target.Text = ""
	target.BackgroundTransparency = 1
	target.ClipsDescendants = true
	for _, child in target:GetChildren() do
		if child.Name == "VTRPresentationBadgeArt" then child:Destroy() end
	end
	local accent = badgeAccent(primary)
	local art = Instance.new("Frame")
	art.Name = "VTRPresentationBadgeArt"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = target.ZIndex + 1
	art.Parent = target
	local outer = Instance.new("Frame")
	outer.AnchorPoint = Vector2.new(.5, .5)
	outer.Position = UDim2.fromScale(.5, .5)
	outer.Size = UDim2.fromScale(.82, .82)
	outer.BackgroundColor3 = primary
	outer.BorderSizePixel = 0
	outer.ZIndex = art.ZIndex + 1
	outer.Parent = art
	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(.22, 0)
	outerCorner.Parent = outer
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = accent
	outerStroke.Transparency = .08
	outerStroke.Thickness = 2
	outerStroke.Parent = outer
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(.5, .5)
	inner.Position = UDim2.fromScale(.5, .5)
	inner.Size = UDim2.fromScale(.68, .68)
	inner.BackgroundColor3 = Color3.fromHex("050505")
	inner.BackgroundTransparency = .04
	inner.BorderSizePixel = 0
	inner.ZIndex = outer.ZIndex + 1
	inner.Parent = outer
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(.18, 0)
	innerCorner.Parent = inner
	local stripe = Instance.new("Frame")
	stripe.AnchorPoint = Vector2.new(.5, .5)
	stripe.Position = UDim2.fromScale(.5, .5)
	stripe.Size = UDim2.fromScale(.18, 1.12)
	stripe.Rotation = -24
	stripe.BackgroundColor3 = primary:Lerp(accent, .2)
	stripe.BackgroundTransparency = .16
	stripe.BorderSizePixel = 0
	stripe.ZIndex = inner.ZIndex + 1
	stripe.Parent = inner
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Text = tostring(logoText or "V")
	mark.TextColor3 = primary
	mark.TextSize = math.max(16, math.floor(target.AbsoluteSize.Y * .34))
	mark.Font = Theme.Fonts.Display
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.TextYAlignment = Enum.TextYAlignment.Center
	mark.ZIndex = inner.ZIndex + 2
	mark.Parent = inner
end

'''

if "local function applyPresentationBadge" not in prematch:
    prematch = prematch.replace(
'''local function color(value: any, fallback: Color3): Color3
	return typeof(value) == "Color3" and value or fallback
end

local function label''',
'''local function color(value: any, fallback: Color3): Color3
	return typeof(value) == "Color3" and value or fallback
end

''' + badge_helper + '''local function label''',
        1
    )

prematch = replace_once(
    prematch,
'''	local old = playerGui:FindFirstChild("VTRPrematchBroadcast")
	if old then old:Destroy() end''',
'''	local old = playerGui:FindFirstChild("VTRPrematchBroadcast")
	if old then old:Destroy() end
	for _, overlayName in ipairs({"VTRMatchTeleport","VTRRankedTeleportFound","VTRRankedTeleportMatchFound","VTRMatchupConfirmed","VTRMatchupConfirm","VTRRankedReservedBoot"}) do
		local overlay = playerGui:FindFirstChild(overlayName)
		if overlay then overlay:Destroy() end
	end''',
    "destroy old transition overlays"
)

prematch = replace_once(
    prematch,
'''	local homeBadge = label(rightPanel, tostring(data.HomeLogo or shortCode(home)), UDim2.fromScale(0.29, 0.22), UDim2.fromScale(0.42, 0.23), 24, Theme.Colors.White, Theme.Fonts.Display)
	homeBadge.BackgroundColor3 = homeColor
	homeBadge.BackgroundTransparency = 0
	homeBadge.TextXAlignment = Enum.TextXAlignment.Center
	local awayBadge = label(rightPanel, tostring(data.AwayLogo or shortCode(away)), UDim2.fromScale(0.29, 0.58), UDim2.fromScale(0.42, 0.23), 24, Theme.Colors.White, Theme.Fonts.Display)
	awayBadge.BackgroundColor3 = awayColor
	awayBadge.BackgroundTransparency = 0
	awayBadge.TextXAlignment = Enum.TextXAlignment.Center''',
'''	local homeBadge = label(rightPanel, tostring(data.HomeLogo or shortCode(home)), UDim2.fromScale(0.29, 0.22), UDim2.fromScale(0.42, 0.23), 24, Theme.Colors.White, Theme.Fonts.Display)
	homeBadge.BackgroundColor3 = homeColor
	homeBadge.BackgroundTransparency = 0
	homeBadge.TextXAlignment = Enum.TextXAlignment.Center
	applyPresentationBadge(homeBadge, homeColor, tostring(data.HomeLogo or "V"))
	local awayBadge = label(rightPanel, tostring(data.AwayLogo or shortCode(away)), UDim2.fromScale(0.29, 0.58), UDim2.fromScale(0.42, 0.23), 24, Theme.Colors.White, Theme.Fonts.Display)
	awayBadge.BackgroundColor3 = awayColor
	awayBadge.BackgroundTransparency = 0
	awayBadge.TextXAlignment = Enum.TextXAlignment.Center
	applyPresentationBadge(awayBadge, awayColor, tostring(data.AwayLogo or "V"))''',
    "matchup badge art"
)

prematch = replace_once(
    prematch,
'''	local sheetLogo = label(sheetLogoPanel, teamLogoText(data, "Home", shortCode(home)), UDim2.fromScale(0.18, 0.36), UDim2.fromScale(0.64, 0.22), 28, Theme.Colors.Black, Theme.Fonts.Display)
	sheetLogo.BackgroundColor3 = Theme.Colors.White
	sheetLogo.BackgroundTransparency = 0
	sheetLogo.TextXAlignment = Enum.TextXAlignment.Center''',
'''	local sheetLogo = label(sheetLogoPanel, teamLogoText(data, "Home", shortCode(home)), UDim2.fromScale(0.18, 0.36), UDim2.fromScale(0.64, 0.22), 28, Theme.Colors.Black, Theme.Fonts.Display)
	sheetLogo.BackgroundColor3 = Theme.Colors.White
	sheetLogo.BackgroundTransparency = 0
	sheetLogo.TextXAlignment = Enum.TextXAlignment.Center
	applyPresentationBadge(sheetLogo, homeColor, teamLogoText(data, "Home", "V"))''',
    "sheet home badge"
)

prematch = replace_once(
    prematch,
'''		sheetLogoPanel.BackgroundColor3 = teamColor
		sheetLogo.Text = teamLogoText(data, side, shortCode(teamName))
		sheetTeamCode.Text = shortCode(teamName)''',
'''		sheetLogoPanel.BackgroundColor3 = teamColor
		sheetLogo.Text = teamLogoText(data, side, shortCode(teamName))
		applyPresentationBadge(sheetLogo, teamColor, teamLogoText(data, side, "V"))
		sheetTeamCode.Text = shortCode(teamName)''',
    "sheet update badge"
)

prematch_path.write_text(prematch, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = replace_once(
    gameplay,
'''	setMenuVisible(false)
	self.Active=true;self.Ball=ball;self.TeamModels=data.TeamModels;self.ControlledSide=data.ControlledSide or"Home";self.WatchMode=data.WatchMode==true;self.Paused=false;self.Ranked=data.Ranked==true;self.MatchInPlay=false;self.PrematchActive=true;self.PrematchSkipRequested=false;self.TacticalMode=false;self.TacticalPanelOpen=true;GuiService.SelectedObject=nil;local playerModule=require(player.PlayerScripts:WaitForChild("PlayerModule"));self.Controls=playerModule:GetControls();self.Controls:Disable();self.HUD=MatchHUDController.new(data);self.Commentary=CommentaryController.new(self.HUD.Gui);self.Camera=BroadcastCameraController.new(data.PitchCFrame,data.PitchWidth,data.PitchLength,ball,active);self.MouseAim=MouseAimController.new(workspace.CurrentCamera,data.PitchCFrame,data.PitchWidth,data.PitchLength);self.Input=InputController.new(self.Action,function(kind,charge)return self:_aimPayload(kind,charge)end);self.InputLock=MatchInputLockController.new(self.Action);self.TeamControl=TeamControlController.new(self.Action,self.Camera,self.HUD,active);self.BallRoll=BallRollVisualController.new(ball);self:_createTacticalPanel()''',
'''	setMenuVisible(false)
	local bootCover = Instance.new("ScreenGui")
	bootCover.Name = "VTRMatchBootCover"
	bootCover.IgnoreGuiInset = true
	bootCover.ResetOnSpawn = false
	bootCover.DisplayOrder = 980
	bootCover.Parent = player:WaitForChild("PlayerGui")
	local bootFrame = Instance.new("Frame")
	bootFrame.BackgroundColor3 = Color3.fromHex("020402")
	bootFrame.BorderSizePixel = 0
	bootFrame.Size = UDim2.fromScale(1, 1)
	bootFrame.Parent = bootCover
	task.delay(1.2, function()
		if bootCover.Parent then bootCover:Destroy() end
	end)
	self.Active=true;self.Ball=ball;self.TeamModels=data.TeamModels;self.ControlledSide=data.ControlledSide or"Home";self.WatchMode=data.WatchMode==true;self.Paused=false;self.Ranked=data.Ranked==true;self.MatchInPlay=false;self.PrematchActive=true;self.PrematchSkipRequested=false;self.TacticalMode=false;self.TacticalPanelOpen=true;GuiService.SelectedObject=nil;local playerModule=require(player.PlayerScripts:WaitForChild("PlayerModule"));self.Controls=playerModule:GetControls();self.Controls:Disable();self.HUD=MatchHUDController.new(data);self.Commentary=CommentaryController.new(self.HUD.Gui);self.Camera=BroadcastCameraController.new(data.PitchCFrame,data.PitchWidth,data.PitchLength,ball,active);self.MouseAim=MouseAimController.new(workspace.CurrentCamera,data.PitchCFrame,data.PitchWidth,data.PitchLength);self.Input=InputController.new(self.Action,function(kind,charge)return self:_aimPayload(kind,charge)end);self.InputLock=MatchInputLockController.new(self.Action);self.TeamControl=TeamControlController.new(self.Action,self.Camera,self.HUD,active);self.BallRoll=BallRollVisualController.new(ball);self:_createTacticalPanel()''',
    "boot cover"
)

gameplay = replace_once(
    gameplay,
'''	if not self.ControlledIndicator then self.ControlledIndicator=VoltraControlledPlayerIndicator.new(function() return self.ActiveModel end) end''',
'''	if self.WatchMode then
		if self.ControlledIndicator then self.ControlledIndicator:Destroy();self.ControlledIndicator=nil end
	elseif not self.ControlledIndicator then
		self.ControlledIndicator=VoltraControlledPlayerIndicator.new(function() return self.ActiveModel end)
	end''',
    "no you in watch mode"
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

teleport_path = Path("src/client/Components/VoltraMatchTeleport.lua")
teleport = teleport_path.read_text(encoding="utf-8")

teleport = re.sub(
    r'function Teleport\.Run\(title: string, callback: \(\) -> any\): any.*?end\n\nreturn Teleport',
'''function Teleport.Run(title: string, callback: () -> any): any
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("VTRMatchTeleport")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRMatchTeleport"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 960
	gui.Parent = playerGui
	local overlay = Instance.new("CanvasGroup")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromHex("020402")
	overlay.BackgroundTransparency = 0
	overlay.GroupTransparency = 0
	overlay.Active = true
	overlay.ZIndex = 960
	overlay.Parent = gui
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(.5, .5)
	text.Position = UDim2.fromScale(.5, .45)
	text.Size = UDim2.fromScale(.82, .1)
	text.Text = string.upper(title)
	text.TextColor3 = Theme.Colors.White
	text.TextSize = 34
	text.Font = Theme.Fonts.Display
	text.ZIndex = 962
	text.Parent = overlay
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(.5, .5)
	sub.Position = UDim2.fromScale(.5, .54)
	sub.Size = UDim2.fromScale(.8, .04)
	sub.Text = "CINEMATIC MATCH LOADING"
	sub.TextColor3 = Theme.Colors.Electric
	sub.TextSize = 11
	sub.Font = Theme.Fonts.Strong
	sub.ZIndex = 962
	sub.Parent = overlay
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(.5, .5)
	bar.Position = UDim2.fromScale(.5, .61)
	bar.Size = UDim2.fromScale(.38, .008)
	bar.BackgroundColor3 = Color3.fromHex("111711")
	bar.BorderSizePixel = 0
	bar.ZIndex = 962
	bar.Parent = overlay
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Colors.Electric
	fill.BorderSizePixel = 0
	fill.ZIndex = 963
	fill.Parent = bar
	TweenService:Create(fill, TweenInfo.new(.95, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
	task.wait(.12)
	local result = callback()
	local started = os.clock()
	repeat
		if playerGui:FindFirstChild("VTRPrematchBroadcast") then break end
		task.wait(.05)
	until os.clock() - started > 2.2
	if gui.Parent then
		TweenService:Create(overlay, TweenInfo.new(.12), {GroupTransparency = 1}):Play()
		task.delay(.14, function()
			if gui.Parent then gui:Destroy() end
		end)
	end
	return result
end

return Teleport''',
    teleport,
    count=1,
    flags=re.S
)

teleport_path.write_text(teleport, encoding="utf-8", newline="\n")

for path in Path("src/client").rglob("*.lua"):
    if path in {prematch_path, gameplay_path, teleport_path, roulette_path}:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    if "MATCHUP CONFIRMED" not in text and "ENTERING MATCH" not in text:
        continue
    original = text
    text = re.sub(r'(\.DisplayOrder\s*=\s*)\d+', r'\g<1>950', text)
    text = re.sub(r'(BackgroundTransparency\s*=\s*)0\.\d+', r'\g<1>0', text, count=1)
    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print("tightened matchup overlay", path)

print("fixed ranked pack odds, manager YOU tag, prematch badges, boot cover, and overlap handoff")