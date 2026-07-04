--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Button=require(script.Parent.Button)
local BadgePreview=require(script.Parent.BadgePreview)
local KitPreview=require(script.Parent.KitPreview)
local MatchSetupService=require(script.Parent.Parent.Services.MatchSetupService)

local Presentation={}
local MATCHUP_PANEL_DELAY = 0.08
local function label(parent:Instance,value:string,position:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font):TextLabel local item=Instance.new("TextLabel");item.BackgroundTransparency=1;item.Position=position;item.Size=size;item.Text=value;item.TextColor3=color;item.TextSize=textSize;item.Font=font;item.TextXAlignment=Enum.TextXAlignment.Center;item.TextWrapped=true;item.ZIndex=184;item.Parent=parent;return item end
local function tweenWait(target:Instance,duration:number,properties:any)local tween=TweenService:Create(target,TweenInfo.new(duration,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),properties);tween:Play();tween.Completed:Wait()end
local function identity(team:any,kit:any):any local badge=team.BadgeIdentity or team.badgeIdentity or{};return{PrimaryColor=badge.PrimaryColor or kit.Primary or team.colors.Primary,SecondaryColor=badge.SecondaryColor or kit.Secondary or team.colors.Secondary,AccentColor=badge.AccentColor or kit.Accent or team.colors.Accent,KitStyle=kit.Style or"Solid",BadgePreset=badge.BadgePreset or team.badgePreset or"Modern",BadgeShape=badge.BadgeShape or(team.badgePreset=="GeneratedHex"and"Hex"or"Shield"),BadgeSymbol=badge.BadgeSymbol or"Volt V",BadgeColorBehavior=badge.BadgeColorBehavior or"Tri Color"}end
local function setMenuVisible(root:Frame,visible:boolean)
	for _,name in{"Sidebar","Topbar","Content"}do local item=root:FindFirstChild(name);if item and item:IsA("GuiObject")then item.Visible=visible end end
	local energy=root:FindFirstChild("BackgroundEnergy")
	if energy and energy:IsA("GuiObject")then energy.Visible=visible end
	root.BackgroundTransparency=visible and 0 or 1
end

function Presentation.play(root:Frame,setup:any,home:any,away:any,onReturn:(()->())?,notify:((string,string)->())?,watchMode:boolean?)
	local existing=root:FindFirstChild("MatchStartPresentation")
	if root:GetAttribute("VTRMatchPresentationActive")==true or existing then
		if notify then notify("Match presentation is already starting.","Info")end
		return
	end
	root:SetAttribute("VTRMatchPresentationActive",true)
	local overlay:CanvasGroup?=nil
	local function finish(showMenu:boolean)
		root:SetAttribute("VTRMatchPresentationActive",nil)
		if overlay and overlay.Parent then overlay:Destroy()end
		if showMenu then setMenuVisible(root,true)end
	end
	setMenuVisible(root,false)
	local homeKit=home.kits[setup.HomeKit]or home.kits.Home;local awayKit=away.kits[setup.AwayKit]or away.kits.Away
	overlay=Instance.new("CanvasGroup");overlay.Name="MatchStartPresentation";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=0;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.GroupTransparency=0;overlay.ZIndex=180;overlay.Active=true;overlay.Selectable=false;overlay.Parent=root
	local shield=Instance.new("TextButton");shield.Name="PresentationInputShield";shield.BackgroundTransparency=1;shield.BorderSizePixel=0;shield.Size=UDim2.fromScale(1,1);shield.Text="";shield.AutoButtonColor=false;shield.Selectable=false;shield.Modal=true;shield.Active=true;shield.ZIndex=180;shield.Parent=overlay
	local stadiumWash=Instance.new("Frame");stadiumWash.BackgroundColor3=Theme.Colors.Pitch;stadiumWash.BackgroundTransparency=.3;stadiumWash.BorderSizePixel=0;stadiumWash.Position=UDim2.fromScale(.08,.12);stadiumWash.Size=UDim2.fromScale(.84,.76);stadiumWash.ZIndex=181;stadiumWash.Parent=overlay;local washCorner=Instance.new("UICorner");washCorner.CornerRadius=UDim.new(0,14);washCorner.Parent=stadiumWash
	label(overlay,"VTR X  /  MATCHDAY",UDim2.fromScale(.1,.07),UDim2.fromScale(.8,.05),10,Theme.Colors.Electric,Theme.Fonts.Strong)
	local status=label(overlay,"MATCHUP CONFIRMED",UDim2.fromScale(.1,.14),UDim2.fromScale(.8,.07),25,Theme.Colors.White,Theme.Fonts.Display)
	local versus=label(overlay,"VS",UDim2.fromScale(.44,.36),UDim2.fromScale(.12,.1),24,Theme.Colors.Electric,Theme.Fonts.Display)
	local homeName=label(overlay,home.teamName,UDim2.fromScale(.08,.27),UDim2.fromScale(.34,.07),20,Theme.Colors.White,Theme.Fonts.Display)
	local awayName=label(overlay,away.teamName,UDim2.fromScale(.58,.27),UDim2.fromScale(.34,.07),20,Theme.Colors.White,Theme.Fonts.Display)
	local homeBadge=BadgePreview.new(overlay,identity(home,homeKit),UDim2.fromScale(.12,.18));homeBadge.AnchorPoint=Vector2.new(.5,0);homeBadge.Position=UDim2.fromScale(.25,.35);homeBadge.ZIndex=184
	local awayBadge=BadgePreview.new(overlay,identity(away,awayKit),UDim2.fromScale(.12,.18));awayBadge.AnchorPoint=Vector2.new(.5,0);awayBadge.Position=UDim2.fromScale(.75,.35);awayBadge.ZIndex=184
	local homeShirt=KitPreview.new(overlay,identity(home,homeKit),UDim2.fromScale(.13,.25));homeShirt.AnchorPoint=Vector2.new(.5,0);homeShirt.Position=UDim2.fromScale(.38,.34);homeShirt.ZIndex=183
	local awayShirt=KitPreview.new(overlay,identity(away,awayKit),UDim2.fromScale(.13,.25));awayShirt.AnchorPoint=Vector2.new(.5,0);awayShirt.Position=UDim2.fromScale(.62,.34);awayShirt.ZIndex=183
	label(overlay,string.format("OVR %d  /  ATT %d  /  MID %d  /  DEF %d",home.overall,home.attack,home.midfield,home.defense),UDim2.fromScale(.08,.57),UDim2.fromScale(.34,.04),9,Theme.Colors.Silver,Theme.Fonts.Strong)
	label(overlay,string.format("OVR %d  /  ATT %d  /  MID %d  /  DEF %d",away.overall,away.attack,away.midfield,away.defense),UDim2.fromScale(.58,.57),UDim2.fromScale(.34,.04),9,Theme.Colors.Silver,Theme.Fonts.Strong)
	local stadiumName=setup.StadiumName or string.upper(tostring(setup.StadiumId):gsub("_"," "))
	label(overlay,stadiumName.."  /  "..string.upper(setup.Weather).."  /  "..string.upper(setup.Time),UDim2.fromScale(.12,.67),UDim2.fromScale(.76,.04),10,Theme.Colors.Electric,Theme.Fonts.Strong)
	local entering=label(overlay,"ENTERING MATCH",UDim2.fromScale(.2,.75),UDim2.fromScale(.6,.055),18,Theme.Colors.White,Theme.Fonts.Display)
	local track=Instance.new("Frame");track.BackgroundColor3=Theme.Colors.Gunmetal;track.BorderSizePixel=0;track.Position=UDim2.fromScale(.25,.83);track.Size=UDim2.fromScale(.5,.008);track.ZIndex=184;track.Parent=overlay;local fill=Instance.new("Frame");fill.BackgroundColor3=Theme.Colors.Electric;fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(0,1);fill.ZIndex=185;fill.Parent=track
	task.wait(MATCHUP_PANEL_DELAY)
	TweenService:Create(fill,TweenInfo.new(.72,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.fromScale(.72,1)}):Play();task.wait(.18)
	status.Text="BUILDING MATCH RUNTIME";entering.Text="SERVER SPAWNING STADIUM, TEAMS + BALL"
	local started=watchMode and MatchSetupService:WatchMatch()or MatchSetupService:StartMatch()
	if not started.Success then status.Text="MATCH LOAD FAILED";entering.Text=started.Message or"The server could not verify the match scene.";TweenService:Create(fill,TweenInfo.new(.2),{BackgroundColor3=Theme.Colors.Danger}):Play();task.wait(1.5);finish(true);return end
	TweenService:Create(fill,TweenInfo.new(.35),{Size=UDim2.fromScale(1,1)}):Play();status.Text="MATCH SCENE READY";entering.Text="ENTERING MATCH";if started.Data.ObjectiveCompletedNow and notify then notify("Play Your First Match completed.","Reward")end;task.wait(.55)
	status.Text=watchMode and"WATCH MATCH READY"or"PLAYABLE MATCH READY";entering.Text=watchMode and"AI VS AI BROADCAST"or"TAKING CONTROL";task.wait(.9)
	tweenWait(overlay,.3,{GroupTransparency=1});finish(false)
end
return Presentation
