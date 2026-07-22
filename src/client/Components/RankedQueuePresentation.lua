--!strict
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Button=require(script.Parent.Button)
local BadgePreview=require(script.Parent.BadgePreview)
local MatchSetupService=require(script.Parent.Parent.Services.MatchSetupService)

local Presentation={}
local OVERLAY_NAME="VTRRankedQueuePresentation"

local function text(parent:Instance,value:string,position:UDim2,size:UDim2,font:Enum.Font,textSize:number,color:Color3,z:number):TextLabel
	local item=Instance.new("TextLabel");item.BackgroundTransparency=1;item.Position=position;item.Size=size;item.Text=value;item.TextColor3=color;item.TextSize=textSize;item.Font=font;item.TextXAlignment=Enum.TextXAlignment.Center;item.TextYAlignment=Enum.TextYAlignment.Center;item.ZIndex=z;item.Parent=parent;return item
end

local function destroyExisting(root:Instance)
	local old=root:FindFirstChild(OVERLAY_NAME);if old then old:Destroy()end
end

local function matchFoundKey(data:any):string
	if type(data)~="table"then return "" end
	local id=data.MatchSessionId or data.MatchId or data.WorldName or data.Opponent or ""
	local side=data.ControlledSide or ""
	return tostring(id).."|"..tostring(side)
end

local function assetImage(value:any):string?
	local textValue=tostring(value or"")
	if textValue==""then return nil end
	if string.match(textValue,"^rbxassetid://")then return textValue end
	if tonumber(textValue)then return"rbxassetid://"..textValue end
	return nil
end

local function renderBadge(container:GuiObject,summary:any,strokeLimit:number?)
	if container:IsA("TextLabel")or container:IsA("TextButton")then container.Text=""end
	container.BackgroundTransparency=1
	container.ClipsDescendants=true
	for _,child in container:GetChildren()do if child.Name=="GeneratedBadge"or child.Name=="RankedBadgeImage"then child:Destroy()end end
	local image=type(summary)=="table"and assetImage(summary.FlagImage or summary.flagImage or summary.BadgeImage or summary.badgeImage or summary.LogoImage or summary.logoImage or summary.logo)or nil
	if image then
		local badgeImage=Instance.new("ImageLabel")
		badgeImage.Name="RankedBadgeImage"
		badgeImage.BackgroundTransparency=1
		badgeImage.Image=image
		badgeImage.ScaleType=Enum.ScaleType.Fit
		badgeImage.Size=UDim2.fromScale(1,1)
		badgeImage.ZIndex=container.ZIndex+1
		badgeImage.Parent=container
		return
	end
	local identity=type(summary)=="table"and(summary.BadgeIdentity or summary.badgeIdentity)or nil
	local colors=type(summary)=="table"and summary.colors or nil
	identity=type(identity)=="table"and identity or{
		PrimaryColor=colors and colors.Primary or"B7FF1A",
		SecondaryColor=colors and colors.Secondary or"050505",
		AccentColor=colors and colors.Accent or"F5F7F2",
		BadgePreset="Modern",
		BadgeShape=type(summary)=="table"and summary.badgePreset=="GeneratedHex"and"Hex"or"Shield",
		BadgeSymbol="Lightning Bolt",
		BadgeColorBehavior="Tri Color",
	}
	local badge=BadgePreview.new(container,identity,UDim2.fromScale(1,1));badge.Position=UDim2.fromScale(0,0);badge.ZIndex=container.ZIndex+1
	for _,descendant in badge:GetDescendants()do
		if descendant:IsA("GuiObject")then descendant.ZIndex=badge.ZIndex elseif strokeLimit and descendant:IsA("UIStroke")then descendant.Thickness=math.min(descendant.Thickness,strokeLimit)end
	end
end

local function base(root:Instance):Frame
	destroyExisting(root)
	local overlay=Instance.new("Frame");overlay.Name=OVERLAY_NAME;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=0;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=240;overlay.Parent=root
	local wash=Instance.new("Frame");wash.BackgroundColor3=Color3.fromHex("0A1607");wash.BackgroundTransparency=.12;wash.BorderSizePixel=0;wash.Position=UDim2.fromScale(.06,.08);wash.Size=UDim2.fromScale(.88,.84);wash.ZIndex=241;wash.Parent=overlay
	local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Electric;stroke.Transparency=.72;stroke.Thickness=1;stroke.Parent=wash
	for index=1,4 do local slash=Instance.new("Frame");slash.BackgroundColor3=index%2==0 and Theme.Colors.White or Theme.Colors.Gunmetal;slash.BackgroundTransparency=index%2==0 and .84 or .35;slash.BorderSizePixel=0;slash.AnchorPoint=Vector2.new(.5,.5);slash.Position=UDim2.fromScale(.14+index*.2,.5);slash.Size=UDim2.fromScale(.06,1.35);slash.Rotation=24;slash.ZIndex=242;slash.Parent=overlay end
	text(overlay,"VTR 25  /  RANKED",UDim2.fromScale(.08,.09),UDim2.fromScale(.84,.04),Theme.Fonts.Strong,10,Theme.Colors.White,245)
	return overlay
end

function Presentation.Cancel(root:Instance)
	local overlay=root:FindFirstChild(OVERLAY_NAME);if overlay and overlay:IsA("Frame")then TweenService:Create(overlay,TweenInfo.new(.22),{BackgroundTransparency=1}):Play();task.delay(.23,function()if overlay.Parent then overlay:Destroy()end end)end
end

function Presentation.StartSearching(root:Instance)
	local overlay=base(root);overlay.BackgroundTransparency=1;TweenService:Create(overlay,TweenInfo.new(.28),{BackgroundTransparency=0}):Play()
	local title=text(overlay,"SEARCHING FOR OPPONENT",UDim2.fromScale(.15,.25),UDim2.fromScale(.7,.09),Theme.Fonts.Display,30,Theme.Colors.White,246)
	local subtitle=text(overlay,"GLOBAL WATCH QUEUE",UDim2.fromScale(.2,.345),UDim2.fromScale(.6,.035),Theme.Fonts.Strong,9,Theme.Colors.Muted,246)
	local scanner=Instance.new("Frame");scanner.AnchorPoint=Vector2.new(.5,.5);scanner.BackgroundColor3=Theme.Colors.Electric;scanner.BorderSizePixel=0;scanner.Position=UDim2.fromScale(.5,.47);scanner.Size=UDim2.fromOffset(250,2);scanner.ZIndex=246;scanner.Parent=overlay
	local glow=Instance.new("UIStroke");glow.Color=Theme.Colors.White;glow.Thickness=5;glow.Transparency=.65;glow.Parent=scanner
	local core=Instance.new("Frame");core.AnchorPoint=Vector2.new(.5,.5);core.BackgroundColor3=Theme.Colors.Black;core.BorderSizePixel=0;core.Position=UDim2.fromScale(.5,.47);core.Size=UDim2.fromOffset(74,74);core.Rotation=45;core.ZIndex=247;core.Parent=overlay;local coreStroke=Instance.new("UIStroke");coreStroke.Color=Theme.Colors.White;coreStroke.Thickness=2;coreStroke.Parent=core
	local mark=text(core,"V",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Theme.Fonts.Display,32,Theme.Colors.White,248);mark.Rotation=-45
	local elapsed=text(overlay,"00:00",UDim2.fromScale(.4,.565),UDim2.fromScale(.2,.05),Theme.Fonts.Display,18,Theme.Colors.White,246)
	local status=text(overlay,"SCANNING FOR A RANKED WATCH OPPONENT",UDim2.fromScale(.22,.625),UDim2.fromScale(.56,.04),Theme.Fonts.Strong,8,Theme.Colors.Muted,246)
	local cancel=Button.new({Text="CANCEL SEARCH",Variant="Secondary",Size=UDim2.fromOffset(190,42),OnActivated=function()local result=MatchSetupService:LeaveRankedQueue();if result.Success then Presentation.Cancel(root)else status.Text=result.Message or"Unable to cancel search.";status.TextColor3=Color3.fromHex("FF655E")end end});cancel.AnchorPoint=Vector2.new(.5,.5);cancel.Position=UDim2.fromScale(.5,.74);cancel.ZIndex=247;cancel.Parent=overlay
	TweenService:Create(scanner,TweenInfo.new(.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Size=UDim2.fromOffset(520,2),BackgroundTransparency=.25}):Play();TweenService:Create(core,TweenInfo.new(1.1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Rotation=225}):Play();TweenService:Create(title,TweenInfo.new(.85,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{TextColor3=Theme.Colors.Electric}):Play()
	local started=os.clock();local connection:RBXScriptConnection?;connection=RunService.RenderStepped:Connect(function()if not overlay.Parent then if connection then connection:Disconnect()end;return end;local seconds=math.floor(os.clock()-started);elapsed.Text=string.format("%02d:%02d",math.floor(seconds/60),seconds%60);subtitle.Text="GLOBAL WATCH QUEUE  /  "..string.rep(".",seconds%4+1)end)
end

local function teamPanel(overlay:Frame,summary:any,side:string,controlledSide:string):Frame
	local panel=Instance.new("Frame");panel.Name=side.."Team";panel.BackgroundColor3=Theme.Colors.Graphite;panel.BackgroundTransparency=.06;panel.BorderSizePixel=0;panel.Size=UDim2.fromScale(.34,.46);panel.Position=side=="Home"and UDim2.fromScale(.1,.29)or UDim2.fromScale(.56,.29);panel.ZIndex=246;panel.Parent=overlay
	local stroke=Instance.new("UIStroke");stroke.Color=side=="Home"and Theme.Colors.Electric or Color3.fromHex("D9D9D9");stroke.Transparency=.35;stroke.Thickness=1;stroke.Parent=panel
	text(panel,side==controlledSide and"YOUR TEAM"or"OPPONENT",UDim2.fromScale(.08,.015),UDim2.fromScale(.84,.05),Theme.Fonts.Strong,8,side==controlledSide and Theme.Colors.White or Theme.Colors.Muted,247)
	local badge=Instance.new("TextLabel");badge.AnchorPoint=Vector2.new(.5,0);badge.BackgroundColor3=side=="Home"and Theme.Colors.White or Theme.Colors.Silver;badge.BorderSizePixel=0;badge.Position=UDim2.fromScale(.5,.08);badge.Size=UDim2.fromOffset(74,74);badge.Text=summary.logo or"V";badge.TextColor3=Theme.Colors.Black;badge.TextSize=25;badge.Font=Theme.Fonts.Display;badge.ZIndex=247;badge.Parent=panel;local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=badge
	renderBadge(badge,summary,2)
	text(panel,string.upper(summary.teamName or side),UDim2.fromScale(.06,.34),UDim2.fromScale(.88,.1),Theme.Fonts.Display,20,Theme.Colors.White,247)
	text(panel,(summary.country or"VTR").."  /  "..(summary.league or"RANKED"),UDim2.fromScale(.06,.45),UDim2.fromScale(.88,.06),Theme.Fonts.Strong,8,Theme.Colors.Muted,247)
	local overall=text(panel,tostring(summary.overall or 0),UDim2.fromScale(.32,.54),UDim2.fromScale(.36,.16),Theme.Fonts.Display,42,Theme.Colors.Electric,247)
	overall.TextXAlignment=Enum.TextXAlignment.Center
	overall:SetAttribute("VTRKeepLineupNumberStack", true)
	text(panel,"TEAM OVERALL",UDim2.fromScale(.25,.695),UDim2.fromScale(.5,.05),Theme.Fonts.Strong,8,Theme.Colors.Muted,247)
	local function stat(label:string,value:any,x:number)
		local statFrame=Instance.new("Frame");statFrame.BackgroundTransparency=1;statFrame.Position=UDim2.fromScale(x,.79);statFrame.Size=UDim2.fromScale(.22,.09);statFrame.ZIndex=247;statFrame.Parent=panel
		text(statFrame,label,UDim2.fromScale(0,0),UDim2.fromScale(1,.42),Theme.Fonts.Strong,8,Theme.Colors.Muted,248)
		local valueLabel=text(statFrame,tostring(value or 0),UDim2.fromScale(0,.36),UDim2.fromScale(1,.58),Theme.Fonts.Display,18,Theme.Colors.Silver,248)
		valueLabel:SetAttribute("VTRKeepLineupNumberStack", true)
	end
	stat("ATT",summary.attack,.11);stat("MID",summary.midfield,.39);stat("DEF",summary.defense,.67)
	return panel
end

function Presentation.ShowMatchFound(root:Instance,data:any,onComplete:()->())
	local key=matchFoundKey(data)
	local existing=root:FindFirstChild(OVERLAY_NAME)
	if existing and existing:IsA("Frame")and existing:GetAttribute("VTRMatchFoundActive")==true then
		local completeAt=tonumber(existing:GetAttribute("VTRMatchFoundCompleteAt"))or(os.clock()+.2)
		task.delay(math.max(.05,completeAt-os.clock()),function()if onComplete then onComplete()end end)
		return
	end
	if existing and existing:IsA("Frame")and existing:GetAttribute("VTRMatchFoundKey")==key then
		local completeAt=tonumber(existing:GetAttribute("VTRMatchFoundCompleteAt"))or(os.clock()+.2)
		task.delay(math.max(.05,completeAt-os.clock()),function()if onComplete then onComplete()end end)
		return
	end
	local overlay=existing and existing:IsA("Frame")and existing or base(root)
	overlay:SetAttribute("VTRMatchFoundKey",key)
	overlay:SetAttribute("VTRMatchFoundActive",true)
	overlay:SetAttribute("VTRMatchFoundCompleteAt",os.clock()+3.95)
	for _,child in overlay:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
	overlay.BackgroundTransparency=0;overlay.BackgroundColor3=Theme.Colors.Black
	text(overlay,"OPPONENT FOUND",UDim2.fromScale(.15,.08),UDim2.fromScale(.7,.07),Theme.Fonts.Display,29,Theme.Colors.Electric,246)
	text(overlay,"RANKED WATCH VS WATCH  /  SYNCHRONIZING MATCH",UDim2.fromScale(.2,.15),UDim2.fromScale(.6,.035),Theme.Fonts.Strong,9,Theme.Colors.Muted,246)
	local controlled=data.ControlledSide or"Home";local home=teamPanel(overlay,data.HomeSummary or{teamName=data.Home,logo=data.HomeLogo},"Home",controlled);local away=teamPanel(overlay,data.AwaySummary or{teamName=data.Away,logo=data.AwayLogo},"Away",controlled)
	local vs=text(overlay,"VS",UDim2.fromScale(.44,.42),UDim2.fromScale(.12,.12),Theme.Fonts.Display,31,Theme.Colors.Electric,248);vs.TextTransparency=1
	task.delay(.18,function()if vs.Parent then TweenService:Create(vs,TweenInfo.new(.25),{TextTransparency=0}):Play()end end)
	local opponent=text(overlay,"OPPONENT  /  "..string.upper(data.Opponent or"CHALLENGER"),UDim2.fromScale(.25,.82),UDim2.fromScale(.5,.05),Theme.Fonts.Strong,10,Theme.Colors.White,247);opponent.TextTransparency=1;task.delay(.75,function()if opponent.Parent then TweenService:Create(opponent,TweenInfo.new(.3),{TextTransparency=0}):Play()end end)
	task.delay(3.4,function()if not overlay.Parent then return end;overlay:SetAttribute("VTRMatchFoundActive",false);local fade=TweenService:Create(overlay,TweenInfo.new(.45),{BackgroundTransparency=1});fade.Completed:Once(function()if overlay.Parent then overlay:Destroy()end;onComplete()end);fade:Play()end)
end

return Presentation
