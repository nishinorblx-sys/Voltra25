from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

def regex_once(text, pattern, new, label):
    next_text, count = re.subn(pattern, new, text, count=1, flags=re.S)
    if count == 0:
        print("skipped", label)
        return text
    return next_text

roulette_path = Path("src/client/Components/VoltraPackRoulette.lua")
roulette_path.parent.mkdir(parents=True, exist_ok=True)
roulette_path.write_text('''--!strict
local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").VTR.Shared.Theme)

local Presentation = {}

local PACKS = {
\t{Name = "Voltra Spark Pack", Rarity = "Common", Color = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("050505")},
\t{Name = "Street Pulse Pack", Rarity = "Rare", Color = Color3.fromHex("1FA2FF"), Accent = Color3.fromHex("F5F7F2")},
\t{Name = "Neon Tactics Pack", Rarity = "Rare", Color = Color3.fromHex("24C6B8"), Accent = Color3.fromHex("050505")},
\t{Name = "Elite Matchday Pack", Rarity = "Epic", Color = Color3.fromHex("8E00D6"), Accent = Color3.fromHex("F5F7F2")},
\t{Name = "Voltra Vault Pack", Rarity = "Epic", Color = Color3.fromHex("FFCB45"), Accent = Color3.fromHex("111111")},
\t{Name = "Ranked Champion Pack", Rarity = "Mythic", Color = Color3.fromHex("FF477E"), Accent = Color3.fromHex("F5F7F2")},
\t{Name = "Icon Voltage Pack", Rarity = "Mythic", Color = Color3.fromHex("D9D9D9"), Accent = Color3.fromHex("7D2CFF")},
}

local function label(parent: Instance, value: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, z: number): TextLabel
\tlocal item = Instance.new("TextLabel")
\titem.BackgroundTransparency = 1
\titem.Position = pos
\titem.Size = size
\titem.Text = value
\titem.TextColor3 = color
\titem.TextSize = textSize
\titem.Font = Theme.Fonts.Display
\titem.TextXAlignment = Enum.TextXAlignment.Center
\titem.TextYAlignment = Enum.TextYAlignment.Center
\titem.ZIndex = z
\titem.Parent = parent
\treturn item
end

local function corner(parent: Instance, radius: number)
\tlocal value = Instance.new("UICorner")
\tvalue.CornerRadius = UDim.new(0, radius)
\tvalue.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number)
\tlocal value = Instance.new("UIStroke")
\tvalue.Color = color
\tvalue.Thickness = thickness
\tvalue.Transparency = transparency
\tvalue.Parent = parent
end

local function rewardPack(payload: any): any
\tlocal reward = payload and payload.Reward or {}
\tlocal ranked = payload and payload.RankedWinPack or {}
\tlocal wanted = reward.PackName or reward.Pack or reward.packName or ranked.PackName
\tif wanted then
\t\tfor _, pack in PACKS do
\t\t\tif string.upper(pack.Name) == string.upper(tostring(wanted)) then return pack end
\t\tend
\t\treturn {Name = tostring(wanted), Rarity = tostring(reward.Rarity or ranked.Rarity or "Mythic"), Color = Color3.fromHex("B7FF1A"), Accent = Color3.fromHex("050505")}
\tend
\tlocal roll = math.random()
\tif roll > .92 then return PACKS[math.random(6, 7)] end
\tif roll > .72 then return PACKS[math.random(4, 5)] end
\tif roll > .34 then return PACKS[math.random(2, 3)] end
\treturn PACKS[1]
end

local function makePackCard(parent: Instance, pack: any, size: UDim2, z: number): Frame
\tlocal card = Instance.new("Frame")
\tcard.Size = size
\tcard.BackgroundColor3 = Color3.fromHex("080808")
\tcard.BorderSizePixel = 0
\tcard.ZIndex = z
\tcard.Parent = parent
\tcorner(card, 10)
\tstroke(card, pack.Color, 2, .18)
\tlocal glow = Instance.new("Frame")
\tglow.Position = UDim2.fromScale(.08, .08)
\tglow.Size = UDim2.fromScale(.84, .46)
\tglow.BackgroundColor3 = pack.Color
\tglow.BackgroundTransparency = .16
\tglow.BorderSizePixel = 0
\tglow.ZIndex = z + 1
\tglow.Parent = card
\tcorner(glow, 12)
\tlocal icon = label(glow, "V", UDim2.fromScale(0, .02), UDim2.fromScale(1, .76), 44, pack.Accent, z + 2)
\ticon.TextTransparency = .06
\tlocal shardA = Instance.new("Frame")
\tshardA.AnchorPoint = Vector2.new(.5, .5)
\tshardA.Position = UDim2.fromScale(.34, .47)
\tshardA.Size = UDim2.fromScale(.18, .82)
\tshardA.Rotation = -28
\tshardA.BackgroundColor3 = pack.Accent
\tshardA.BackgroundTransparency = .18
\tshardA.BorderSizePixel = 0
\tshardA.ZIndex = z + 2
\tshardA.Parent = glow
\tcorner(shardA, 5)
\tlocal shardB = shardA:Clone()
\tshardB.Position = UDim2.fromScale(.66, .47)
\tshardB.Rotation = 28
\tshardB.Parent = glow
\tlocal name = label(card, string.upper(pack.Name), UDim2.fromScale(.08, .58), UDim2.fromScale(.84, .16), 13, Theme.Colors.White, z + 2)
\tname.TextWrapped = true
\tlocal rarity = label(card, string.upper(pack.Rarity), UDim2.fromScale(.08, .78), UDim2.fromScale(.84, .08), 8, pack.Color, z + 2)
\tlocal strip = Instance.new("Frame")
\tstrip.Position = UDim2.fromScale(0, .92)
\tstrip.Size = UDim2.fromScale(1, .08)
\tstrip.BackgroundColor3 = pack.Color
\tstrip.BorderSizePixel = 0
\tstrip.ZIndex = z + 1
\tstrip.Parent = card
\treturn card
end

function Presentation.Play(gui: ScreenGui, payload: any, onComplete: () -> ())
\tif not gui or not gui.Parent then
\t\tonComplete()
\t\treturn
\tend
\tlocal chosen = rewardPack(payload)
\tlocal old = gui:FindFirstChild("VoltraPackRoulette")
\tif old then old:Destroy() end
\tlocal overlay = Instance.new("CanvasGroup")
\toverlay.Name = "VoltraPackRoulette"
\toverlay.Size = UDim2.fromScale(1, 1)
\toverlay.BackgroundColor3 = Theme.Colors.Black
\toverlay.BackgroundTransparency = .02
\toverlay.BorderSizePixel = 0
\toverlay.GroupTransparency = 1
\toverlay.ZIndex = 520
\toverlay.Active = true
\toverlay.Parent = gui
\tTweenService:Create(overlay, TweenInfo.new(.28), {GroupTransparency = 0}):Play()
\tlabel(overlay, "RANKED WIN REWARD", UDim2.fromScale(.18, .07), UDim2.fromScale(.64, .05), 13, Theme.Colors.Electric, 522)
\tlabel(overlay, "VOLTRA PACK ROULETTE", UDim2.fromScale(.14, .12), UDim2.fromScale(.72, .08), 38, Theme.Colors.White, 522)
\tlocal rail = Instance.new("Frame")
\trail.AnchorPoint = Vector2.new(.5, .5)
\trail.Position = UDim2.fromScale(.5, .43)
\trail.Size = UDim2.fromScale(.86, .26)
\trail.BackgroundColor3 = Color3.fromHex("080D07")
\trail.BackgroundTransparency = .04
\trail.BorderSizePixel = 0
\trail.ClipsDescendants = true
\trail.ZIndex = 522
\trail.Parent = overlay
\tcorner(rail, 14)
\tstroke(rail, Theme.Colors.Electric, 2, .28)
\tlocal topArrow = label(overlay, "▼", UDim2.fromScale(.475, .245), UDim2.fromScale(.05, .05), 34, Theme.Colors.Electric, 530)
\tlocal bottomArrow = label(overlay, "▲", UDim2.fromScale(.475, .575), UDim2.fromScale(.05, .05), 34, Theme.Colors.Electric, 530)
\tlocal strip = Instance.new("Frame")
\tstrip.BackgroundTransparency = 1
\tstrip.Position = UDim2.fromOffset(0, 0)
\tstrip.Size = UDim2.fromOffset(5200, 160)
\tstrip.ZIndex = 523
\tstrip.Parent = rail
\tlocal layout = Instance.new("UIListLayout")
\tlayout.FillDirection = Enum.FillDirection.Horizontal
\tlayout.Padding = UDim.new(0, 12)
\tlayout.SortOrder = Enum.SortOrder.LayoutOrder
\tlayout.Parent = strip
\tlocal stopIndex = 28
\tlocal cardWidth = 138
\tlocal total = 38
\tfor i = 1, total do
\t\tlocal pack = i == stopIndex and chosen or PACKS[math.random(1, #PACKS)]
\t\tlocal holder = Instance.new("Frame")
\t\tholder.BackgroundTransparency = 1
\t\tholder.Size = UDim2.fromOffset(cardWidth, 154)
\t\tholder.LayoutOrder = i
\t\tholder.ZIndex = 523
\t\tholder.Parent = strip
\t\tmakePackCard(holder, pack, UDim2.fromScale(1, 1), 524)
\tend
\tlocal sparkLine = Instance.new("Frame")
\tsparkLine.AnchorPoint = Vector2.new(.5, .5)
\tsparkLine.Position = UDim2.fromScale(.5, .43)
\tsparkLine.Size = UDim2.fromScale(.02, .28)
\tsparkLine.BackgroundColor3 = Theme.Colors.Electric
\tsparkLine.BackgroundTransparency = .3
\tsparkLine.BorderSizePixel = 0
\tsparkLine.ZIndex = 531
\tsparkLine.Parent = overlay
\tTweenService:Create(sparkLine, TweenInfo.new(.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = .02, Size = UDim2.fromScale(.027, .30)}):Play()
\ttask.wait()
\tlocal railWidth = rail.AbsoluteSize.X
\tlocal targetX = railWidth * .5 - ((stopIndex - 1) * (cardWidth + 12) + cardWidth * .5)
\tstrip.Position = UDim2.fromOffset(railWidth * .5 + 120, 8)
\tTweenService:Create(strip, TweenInfo.new(4.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(targetX, 8)}):Play()
\ttask.delay(4.55, function()
\t\tif not overlay.Parent then return end
\t\tlocal reveal = Instance.new("CanvasGroup")
\t\treveal.AnchorPoint = Vector2.new(.5, .5)
\t\treveal.Position = UDim2.fromScale(.5, .48)
\t\treveal.Size = UDim2.fromOffset(310, 400)
\t\treveal.BackgroundTransparency = 1
\t\treveal.GroupTransparency = 1
\t\treveal.ZIndex = 540
\t\treveal.Parent = overlay
\t\tmakePackCard(reveal, chosen, UDim2.fromScale(1, 1), 541)
\t\tlocal scale = Instance.new("UIScale")
\t\tscale.Scale = .22
\t\tscale.Parent = reveal
\t\tTweenService:Create(reveal, TweenInfo.new(.16), {GroupTransparency = 0}):Play()
\t\tTweenService:Create(scale, TweenInfo.new(.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
\t\tfor i = 1, 24 do
\t\t\tlocal spark = Instance.new("Frame")
\t\t\tspark.AnchorPoint = Vector2.new(.5, .5)
\t\t\tspark.Position = UDim2.fromScale(.5, .48)
\t\t\tspark.Size = UDim2.fromOffset(math.random(5, 13), math.random(20, 52))
\t\t\tspark.BackgroundColor3 = i % 3 == 0 and Theme.Colors.White or chosen.Color
\t\t\tspark.BackgroundTransparency = .04
\t\t\tspark.BorderSizePixel = 0
\t\t\tspark.Rotation = math.random(-30, 30)
\t\t\tspark.ZIndex = 539
\t\t\tspark.Parent = overlay
\t\t\tcorner(spark, 3)
\t\t\tlocal angle = (i / 24) * math.pi * 2
\t\t\tlocal radius = math.random(150, 360)
\t\t\tTweenService:Create(spark, TweenInfo.new(.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(.5, math.cos(angle) * radius, .48, math.sin(angle) * radius * .55), BackgroundTransparency = 1, Rotation = spark.Rotation + math.random(-180, 180)}):Play()
\t\t\ttask.delay(1, function() if spark.Parent then spark:Destroy() end end)
\t\tend
\t\tlabel(overlay, "PACK SECURED", UDim2.fromScale(.2, .80), UDim2.fromScale(.6, .05), 22, chosen.Color, 545)
\tend)
\ttask.delay(7.15, function()
\t\tif not overlay.Parent then
\t\t\tonComplete()
\t\t\treturn
\t\tend
\t\tTweenService:Create(overlay, TweenInfo.new(.35), {GroupTransparency = 1}):Play()
\t\ttask.delay(.38, function()
\t\t\tif overlay.Parent then overlay:Destroy() end
\t\t\tonComplete()
\t\tend)
\tend)
end

return Presentation
''', encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

if 'VoltraPackRoulette' not in gameplay:
    gameplay = gameplay.replace(
        'local RankedQueuePresentation=require(script.Parent.Parent.Components.RankedQueuePresentation)',
        'local RankedQueuePresentation=require(script.Parent.Parent.Components.RankedQueuePresentation)\nlocal VoltraPackRoulette=require(script.Parent.Parent.Components.VoltraPackRoulette)',
        1
    )

gameplay = replace_once(
    gameplay,
    'self.HUD:ShowResult(payload,function()self:_cleanup(true)end)',
    '''local function showResult()
\t\t\tself.HUD:ShowResult(payload,function()self:_cleanup(true)end)
\t\tend
\t\tlocal rankedWin = payload.Ranked == true and (payload.Result == "Win" or payload.Result == "ForfeitWin")
\t\tif rankedWin and self.HUD and self.HUD.Gui then
\t\t\tVoltraPackRoulette.Play(self.HUD.Gui,payload,showResult)
\t\telse
\t\t\tshowResult()
\t\tend''',
    "ranked pack roulette before result"
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = regex_once(
    runtime,
    r'if session\.PrivateRankedMatch and session\.ReturnPlaceId then\s+self\.PostMatchReturns\[participant\]=\{PlaceId=session\.ReturnPlaceId\}\s+end',
    '''if session.PrivateRankedMatch and session.ReturnPlaceId and session.ForfeitBy ~= participant.UserId then
\t\t\t\tself.PostMatchReturns[participant]={PlaceId=session.ReturnPlaceId,IssuedAt=os.clock()}
\t\t\telseif self.PostMatchReturns then
\t\t\t\tself.PostMatchReturns[participant]=nil
\t\t\tend
\t\t\tif session.Ranked then
\t\t\t\tparticipant:SetAttribute("VTRRankedMatchEnding",true)
\t\t\t\tparticipant:SetAttribute("VTRRankedQueueLockedUntil",os.clock()+10)
\t\t\tend''',
    "safe post match ranked return"
)

runtime = replace_once(
    runtime,
    'local pendingReturn=self.PostMatchReturns and self.PostMatchReturns[player]\n\tif pendingReturn then\n\t\tself.PostMatchReturns[player]=nil\n\t\tlocal ok,err=pcall(function()',
    '''local pendingReturn=self.PostMatchReturns and self.PostMatchReturns[player]
\tif pendingReturn then
\t\tself.PostMatchReturns[player]=nil
\t\tif player:GetAttribute("VTRRankedTeleporting")==true then return true end
\t\tplayer:SetAttribute("VTRRankedTeleporting",true)
\t\tlocal ok,err=pcall(function()''',
    "ranked return teleport guard start"
)

runtime = replace_once(
    runtime,
    '''\t\tif not ok then warn("[VTR RANKED RETURN] "..tostring(err))end
\t\treturn ok''',
    '''\t\tif not ok then
\t\t\tplayer:SetAttribute("VTRRankedTeleporting",nil)
\t\t\twarn("[VTR RANKED RETURN] "..tostring(err))
\t\tend
\t\treturn ok''',
    "ranked return teleport guard failure"
)

runtime = replace_once(
    runtime,
    '''function Service:PlayerRemoving(player:Player)
\tlocal session=self.Sessions[player]''',
    '''function Service:PlayerRemoving(player:Player)
\tif self.PostMatchReturns then self.PostMatchReturns[player]=nil end
\tplayer:SetAttribute("VTRRankedTeleporting",nil)
\tplayer:SetAttribute("VTRRankedQueueLockedUntil",os.clock()+10)
\tlocal session=self.Sessions[player]''',
    "clear ranked return on leaving player"
)

runtime = replace_once(
    runtime,
    'local rewards=session.OnBeforeResult and session.OnBeforeResult(session)or{}',
    '''local rewards=session.OnBeforeResult and session.OnBeforeResult(session)or{}
\t\tlocal rankedPackChoices={
\t\t\t{Name="Voltra Spark Pack",Rarity="Common"},
\t\t\t{Name="Street Pulse Pack",Rarity="Rare"},
\t\t\t{Name="Neon Tactics Pack",Rarity="Rare"},
\t\t\t{Name="Elite Matchday Pack",Rarity="Epic"},
\t\t\t{Name="Voltra Vault Pack",Rarity="Epic"},
\t\t\t{Name="Ranked Champion Pack",Rarity="Mythic"},
\t\t\t{Name="Icon Voltage Pack",Rarity="Mythic"},
\t\t}''',
    "ranked pack choices"
)

runtime = replace_once(
    runtime,
    'self.State:FireClient(participant,{Type="MatchEnded",Ranked=session.Ranked,LocalSide=side,Result=result,Forfeit=session.ForfeitBy~=nil,Home=homeScore,Away=awayScore,Stats=resultStats,Reward=rewards and rewards[participant.UserId]or nil})',
    '''local rewardPayload=rewards and rewards[participant.UserId]or nil
\t\t\t\tlocal rankedWin=session.Ranked==true and(result=="Win"or result=="ForfeitWin")
\t\t\t\tif rankedWin then
\t\t\t\t\trewardPayload=rewardPayload or{}
\t\t\t\t\trewardPayload.PackChoices=rewardPayload.PackChoices or rankedPackChoices
\t\t\t\t\trewardPayload.PackName=rewardPayload.PackName or rewardPayload.Pack or"Ranked Champion Pack"
\t\t\t\t\trewardPayload.Rarity=rewardPayload.Rarity or"Mythic"
\t\t\t\tend
\t\t\t\tself.State:FireClient(participant,{Type="MatchEnded",Ranked=session.Ranked,LocalSide=side,Result=result,Forfeit=session.ForfeitBy~=nil,Home=homeScore,Away=awayScore,Stats=resultStats,Reward=rewardPayload,RankedWinPack=rankedWin and rewardPayload or nil})''',
    "ranked win reward payload"
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

setup_path = Path("src/client/Services/MatchSetupService.lua")
if setup_path.exists():
    setup = setup_path.read_text(encoding="utf-8")
    if 'local Players=game:GetService("Players")' not in setup:
        setup = setup.replace('local ReplicatedStorage=game:GetService("ReplicatedStorage")', 'local ReplicatedStorage=game:GetService("ReplicatedStorage")\nlocal Players=game:GetService("Players")', 1)
    setup = replace_once(
        setup,
        'function Service:JoinRankedQueue():any return request("JoinRankedQueue",{DeviceType=deviceType()})end',
        '''function Service:JoinRankedQueue():any
\tlocal player=Players.LocalPlayer
\tif player and (player:GetAttribute("VTRInMatch")==true or (tonumber(player:GetAttribute("VTRRankedQueueLockedUntil"))or 0)>os.clock()) then
\t\treturn{Success=false,Message="Finish the current ranked match first."}
\tend
\treturn request("JoinRankedQueue",{DeviceType=deviceType()})
end''',
        "client ranked queue guard"
    )
    setup_path.write_text(setup, encoding="utf-8", newline="\n")

server_queue_patched = False
for path in Path("src/server").rglob("*.lua"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    if "JoinRankedQueue" not in text or "VTRRankedQueueLockedUntil" in text:
        continue
    original = text
    text = re.sub(
        r'(if\s+action\s*==\s*"JoinRankedQueue"\s*then\s*)',
        r'''\1
\t\tif player:GetAttribute("VTRInMatch")==true or (tonumber(player:GetAttribute("VTRRankedQueueLockedUntil"))or 0)>os.clock() then
\t\t\treturn{Success=false,Message="Finish the current ranked match first."}
\t\tend
''',
        text,
        count=1
    )
    text = re.sub(
        r'(function\s+[^\n]*JoinRankedQueue[^\n]*\n)',
        r'''\1\tif player and (player:GetAttribute("VTRInMatch")==true or (tonumber(player:GetAttribute("VTRRankedQueueLockedUntil"))or 0)>os.clock()) then
\t\treturn{Success=false,Message="Finish the current ranked match first."}
\tend
''',
        text,
        count=1
    )
    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print("patched ranked queue guard", path)
        server_queue_patched = True

print("patched ranked forfeit return safety and Voltra pack roulette")
if not server_queue_patched:
    print("server queue guard was not found by pattern; client guard and match runtime guard were applied")