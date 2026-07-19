local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))
local MATCHUP_PANEL_DELAY = 0.85
--!strict

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local MarketplaceService=game:GetService("MarketplaceService")
local SoundService=game:GetService("SoundService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Panel=require(script.Parent.Parent.Components.Panel)
local Button=require(script.Parent.Parent.Components.Button)
local PageBase=require(script.Parent.PageBase)
local SquadService=require(script.Parent.Parent.Services.SquadService)
local ProgressionService=require(script.Parent.Parent.Services.ProgressionService)
local BadgePreview=require(script.Parent.Parent.Components.BadgePreview)
local PlayerDatabaseService=require(script.Parent.Parent.Services.PlayerDatabaseService)
local AvatarPortraitGenerator=require(script.Parent.Parent.Services.PlayerPortraitService)
local DragController=require(script.Parent.Parent.Controllers.DragController)
local CompactPlayerCard=require(script.Parent.Parent.Components.CompactPlayerCard)
local WidePlayerCard=require(script.Parent.Parent.Components.WidePlayerCard)
local KitPreview=require(script.Parent.Parent.Components.KitPreview)
local ClubIdentityEditor=require(script.Parent.Parent.Components.ClubIdentityEditor)
local CelebrationPoseController=require(script.Parent.Parent.Gameplay.CelebrationPoseController)
local PackService=require(script.Parent.Parent.Services.PackService)
local LaunchService=require(script.Parent.Parent.Services.LaunchService)
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local MonetizationConfig=require(ReplicatedStorage.VTR.Shared.MonetizationConfig)
local Modal=require(script.Parent.Parent.Components.Modal)
local FormationConfig=require(ReplicatedStorage.VTR.Shared.FormationConfig)
local LiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local AIBehaviorTuningConfig=require(ReplicatedStorage.VTR.Shared.AIBehaviorTuningConfig)
local QuickSellValueConfig=require(ReplicatedStorage.VTR.Shared.QuickSellValueConfig)
local PlayabilityUnlockConfig=require(ReplicatedStorage.VTR.Shared.PlayabilityUnlockConfig)
local AIMovementProfileConfig=require(ReplicatedStorage.VTR.Shared.AIMovementProfileConfig)

local UltimateTeamPage={}
local TABS={"Starting XI","Bench","Reserves","Club","Customize"}
local POSITIONS={"ALL","GK","LB","CB","RB","CDM","CM","CAM","LW","ST","RW"}
local RARITIES={"ALL","STARTER","COMMON","BRONZE","SILVER","GOLD","RARE","ELITE","LEGENDARY","ICON","MYTHIC"}
local RARITY_RANK={COMMON=1,STARTER=2,BRONZE=3,SILVER=4,GOLD=5,RARE=6,ELITE=7,LEGENDARY=8,ICON=9,MYTHIC=10}
local TACTIC_PRESETS=LiteConfig.TacticPresetOrder
local FORMATION_DOTS={
	["4-3-3"]={{.5,.9},{.18,.68},{.38,.7},{.62,.7},{.82,.68},{.28,.48},{.5,.52},{.72,.48},{.2,.24},{.5,.18},{.8,.24}},
	["4-2-3-1"]={{.5,.9},{.18,.68},{.38,.7},{.62,.7},{.82,.68},{.38,.52},{.62,.52},{.24,.32},{.5,.3},{.76,.32},{.5,.15}},
	["4-4-2"]={{.5,.9},{.18,.68},{.38,.7},{.62,.7},{.82,.68},{.2,.45},{.4,.48},{.6,.48},{.8,.45},{.38,.18},{.62,.18}},
	["3-5-2"]={{.5,.9},{.28,.7},{.5,.72},{.72,.7},{.12,.48},{.34,.5},{.5,.46},{.66,.5},{.88,.48},{.38,.18},{.62,.18}},
	["5-3-2"]={{.5,.9},{.12,.68},{.32,.72},{.5,.74},{.68,.72},{.88,.68},{.3,.45},{.5,.48},{.7,.45},{.38,.18},{.62,.18}},
}

local function text(parent:Instance,value:string,position:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font):TextLabel
	local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=position;label.Size=size;label.Text=value;label.TextColor3=color;label.TextSize=textSize;label.Font=font;label.TextXAlignment=Enum.TextXAlignment.Left;label.Parent=parent;return label
end
local function corner(parent:Instance,radius:number) local value=Instance.new("UICorner");value.CornerRadius=UDim.new(0,radius);value.Parent=parent end
local function rosterMeta(snapshot:any,card:any):any return snapshot.CardMeta and snapshot.CardMeta[card.Id] or card.Meta or {} end
local function indexOrDefault(list:{string},value:any,defaultIndex:number):number local numeric=tonumber(value);if numeric and list[numeric]then return numeric end;for index,item in list do if item==value then return index end end;return defaultIndex end

local function bootPalette(bootStyle:string):(Color3,Color3,Enum.Material)
	if bootStyle=="boots_limited_green"then return Color3.fromHex("B7FF1A"),Color3.fromHex("071007"),Enum.Material.Neon end
	if bootStyle=="boots_animated_trail"then return Color3.fromHex("1DDCFF"),Color3.fromHex("071016"),Enum.Material.Neon end
	if bootStyle=="boots_gradient_premium"then return Color3.fromHex("FF2E4F"),Color3.fromHex("B7FF1A"),Enum.Material.SmoothPlastic end
	return Theme.Colors.Electric,Color3.fromHex("050505"),Enum.Material.SmoothPlastic
end

local function ownsPass(ownership:any,id:string):boolean
	return type(ownership)=="table" and type(ownership.GamePasses)=="table" and table.find(ownership.GamePasses,id)~=nil
end

local function normalizeSoundAssetId(value:any):string
	local digits=string.match(tostring(value or ""),"(%d+)")
	if not digits then return "" end
	return "rbxassetid://"..digits
end

local function goalEffectPreviewColor(effectId:string):Color3
	if effectId=="goal_fx_golden_explosion"then return Color3.fromHex("FFD64A")end
	if effectId=="goal_fx_fire"then return Color3.fromHex("FF602A")end
	if effectId=="goal_fx_smoke"then return Color3.fromHex("B7BDB4")end
	if effectId=="goal_fx_lightning"then return Color3.fromHex("54E8FF")end
	return Theme.Colors.Electric
end

local function previewGoalEffect(parent:GuiObject,effectId:string,effectName:string)
	local old=parent:FindFirstChild("GoalEffectPreviewBurst")
	if old then old:Destroy()end
	local color=goalEffectPreviewColor(effectId)
	if effectId=="goal_fx_stadium_shake"then
		local original=parent.Position
		local flash=Instance.new("Frame")
		flash.Name="GoalEffectPreviewBurst"
		flash.BackgroundColor3=Theme.Colors.Electric
		flash.BackgroundTransparency=.78
		flash.BorderSizePixel=0
		flash.Size=UDim2.fromScale(1,1)
		flash.ZIndex=92
		flash.Parent=parent
		corner(flash,8)
		TweenService:Create(flash,TweenInfo.new(.52,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1}):Play()
		task.delay(.56,function()if flash.Parent then flash:Destroy()end end)
		task.spawn(function()
			for _=1,18 do
				if not parent.Parent then break end
				parent.Position=original+UDim2.fromOffset(math.random(-16,16),math.random(-10,10))
				task.wait(.02)
			end
			if parent.Parent then parent.Position=original end
		end)
		return
	end
	local burst=Instance.new("Frame")
	burst.Name="GoalEffectPreviewBurst"
	burst.BackgroundColor3=Color3.fromHex("050505")
	burst.BackgroundTransparency=.08
	burst.BorderSizePixel=0
	burst.Position=UDim2.fromOffset(18,46)
	burst.Size=UDim2.new(1,-36,0,132)
	burst.ClipsDescendants=true
	burst.ZIndex=90
	burst.Parent=parent
	corner(burst,10)
	local stroke=Instance.new("UIStroke")
	stroke.Color=color
	stroke.Thickness=2
	stroke.Transparency=.08
	stroke.Parent=burst
	text(burst,string.upper(effectName),UDim2.fromOffset(12,10),UDim2.new(1,-24,0,18),8,color,Theme.Fonts.Strong).ZIndex=91
	local core=Instance.new("Frame")
	core.AnchorPoint=Vector2.new(.5,.5)
	core.BackgroundColor3=color
	core.BackgroundTransparency=.05
	core.BorderSizePixel=0
	core.Position=UDim2.fromScale(.5,.56)
	core.Size=UDim2.fromOffset(28,28)
	core.ZIndex=92
	core.Parent=burst
	corner(core,100)
	for index=1,14 do
		local particle=Instance.new("Frame")
		particle.AnchorPoint=Vector2.new(.5,.5)
		particle.BackgroundColor3=color
		particle.BackgroundTransparency=.06
		particle.BorderSizePixel=0
		particle.Position=UDim2.fromScale(.5,.56)
		particle.Size=UDim2.fromOffset(index%3==0 and 7 or 4,index%3==0 and 24 or 18)
		particle.Rotation=(index/14)*360
		particle.ZIndex=92
		particle.Parent=burst
		corner(particle,4)
		local angle=(index/14)*math.pi*2
		local distance=math.random(42,92)
		local target=UDim2.new(.5,math.cos(angle)*distance,.56,math.sin(angle)*distance)
		TweenService:Create(particle,TweenInfo.new(.62,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=target,BackgroundTransparency=1,Size=UDim2.fromOffset(2,8)}):Play()
	end
	local ring=Instance.new("Frame")
	ring.AnchorPoint=Vector2.new(.5,.5)
	ring.BackgroundTransparency=1
	ring.BorderSizePixel=0
	ring.Position=UDim2.fromScale(.5,.56)
	ring.Size=UDim2.fromOffset(24,24)
	ring.ZIndex=91
	ring.Parent=burst
	corner(ring,100)
	local ringStroke=Instance.new("UIStroke")
	ringStroke.Color=color
	ringStroke.Thickness=3
	ringStroke.Transparency=.05
	ringStroke.Parent=ring
	TweenService:Create(core,TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(54,54),BackgroundTransparency=.28}):Play()
	TweenService:Create(ring,TweenInfo.new(.68,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(168,168)}):Play()
	TweenService:Create(ringStroke,TweenInfo.new(.68),{Transparency=1}):Play()
	task.delay(.72,function()
		if burst.Parent then
			TweenService:Create(burst,TweenInfo.new(.18),{BackgroundTransparency=1}):Play()
			task.delay(.2,function()if burst.Parent then burst:Destroy()end end)
		end
	end)
end

local function makeBootPart(name:string,size:Vector3,cframe:CFrame,color:Color3,material:Enum.Material,parent:Instance):Part
	local part=Instance.new("Part")
	part.Name=name
	part.Anchored=true
	part.CanCollide=false
	part.CanTouch=false
	part.CanQuery=false
	part.CastShadow=false
	part.Material=material
	part.Color=color
	part.Size=size
	part.CFrame=cframe
	part.Parent=parent
	return part
end

local function addPreviewBoot(model:Model,offsetX:number,bootStyle:string)
	local primary,secondary,material=bootPalette(bootStyle)
	local base=CFrame.new(offsetX,0,0)
	local shoe=makeBootPart("BootBody",Vector3.new(.58,.22,1.06),base*CFrame.new(0,0,0),primary,material,model)
	makeBootPart("BootToe",Vector3.new(.62,.18,.42),base*CFrame.new(0,-.01,-.54),primary,material,model)
	makeBootPart("BootCollar",Vector3.new(.50,.14,.32),base*CFrame.new(0,.17,.28),secondary,Enum.Material.SmoothPlastic,model)
	makeBootPart("BootSole",Vector3.new(.64,.06,1.12),base*CFrame.new(0,-.14,0),secondary,Enum.Material.SmoothPlastic,model)
	if bootStyle=="boots_gradient_premium"then
		makeBootPart("BootGradientToe",Vector3.new(.64,.19,.45),base*CFrame.new(0,0,-.55),secondary,Enum.Material.Neon,model).Transparency=.08
	elseif bootStyle=="boots_animated_trail"then
		local glow=makeBootPart("BootGlow",Vector3.new(.68,.04,1.18),base*CFrame.new(0,.16,0),primary,Enum.Material.Neon,model)
		glow.Transparency=.35
	end
	shoe:SetAttribute("VTRBootPreview",true)
end

local function createBootViewport(parent:Instance,bootStyle:string,position:UDim2,size:UDim2,zIndex:number):ViewportFrame
	local viewport=Instance.new("ViewportFrame")
	viewport.Name="BootViewport"
	viewport.BackgroundColor3=Color3.fromHex("050805")
	viewport.BackgroundTransparency=0
	viewport.BorderSizePixel=0
	viewport.Position=position
	viewport.Size=size
	viewport.Ambient=Color3.fromRGB(120,150,130)
	viewport.LightColor=Color3.fromRGB(230,255,210)
	viewport.LightDirection=Vector3.new(-1,-1,-.6)
	viewport.ZIndex=zIndex
	viewport.Parent=parent
	corner(viewport,10)
	local stroke=Instance.new("UIStroke")
	stroke.Color=Theme.Colors.Electric
	stroke.Transparency=.55
	stroke.Thickness=1
	stroke.Parent=viewport
	local camera=Instance.new("Camera")
	camera.CFrame=CFrame.new(0,1.15,4.4)*CFrame.Angles(math.rad(-12),0,0)
	camera.Parent=viewport
	viewport.CurrentCamera=camera
	local world=Instance.new("WorldModel")
	world.Parent=viewport
	local model=Instance.new("Model")
	model.Name="SpinningBoots"
	model.Parent=world
	addPreviewBoot(model,-.42,bootStyle)
	addPreviewBoot(model,.42,bootStyle)
	local pivot=CFrame.new(0,0,0)
	model:PivotTo(pivot*CFrame.Angles(0,math.rad(-18),0))
	local started=os.clock()
	local connection:RBXScriptConnection?
	connection=RunService.RenderStepped:Connect(function()
		if not viewport.Parent then
			if connection then connection:Disconnect()end
			return
		end
		local t=os.clock()-started
		model:PivotTo(pivot*CFrame.Angles(math.rad(math.sin(t*1.4)*4),t*.9,0))
	end)
	return viewport
end

local function r6Part(name:string,size:Vector3,color:Color3,parent:Instance):Part
	local part=Instance.new("Part")
	part.Name=name
	part.Anchored=false
	part.CanCollide=false
	part.CanTouch=false
	part.CanQuery=false
	part.CastShadow=false
	part.Material=Enum.Material.SmoothPlastic
	part.Color=color
	part.Size=size
	part.Parent=parent
	return part
end

local function motor(parent:Instance,name:string,part0:BasePart,part1:BasePart,c0:CFrame,c1:CFrame)
	local joint=Instance.new("Motor6D")
	joint.Name=name
	joint.Part0=part0
	joint.Part1=part1
	joint.C0=c0
	joint.C1=c1
	joint.Parent=parent
	return joint
end

local function createCelebrationViewport(parent:Instance,celebrationId:string,position:UDim2,size:UDim2,zIndex:number):ViewportFrame
	local viewport=Instance.new("ViewportFrame")
	viewport.Name="CelebrationViewport"
	viewport.BackgroundColor3=Color3.fromHex("050805")
	viewport.BackgroundTransparency=0
	viewport.BorderSizePixel=0
	viewport.Position=position
	viewport.Size=size
	viewport.Ambient=Color3.fromRGB(135,155,135)
	viewport.LightColor=Color3.fromRGB(240,255,220)
	viewport.LightDirection=Vector3.new(-.8,-1,-.6)
	viewport.ZIndex=zIndex
	viewport.Parent=parent
	corner(viewport,10)
	local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Electric;stroke.Transparency=.5;stroke.Thickness=1;stroke.Parent=viewport
	local camera=Instance.new("Camera");camera.CFrame=CFrame.lookAt(Vector3.new(0,2.15,-7.0),Vector3.new(0,2.25,0));camera.Parent=viewport;viewport.CurrentCamera=camera
	local world=Instance.new("WorldModel")
	world.Name="CelebrationPreviewWorld"
	world.Parent=viewport
	local rig=Instance.new("Model");rig.Name="CelebrationPreviewR6";rig.Parent=world
	local root=r6Part("HumanoidRootPart",Vector3.new(2,2,1),Color3.fromRGB(45,45,45),rig);root.Transparency=1;root.Anchored=true
	local torso=r6Part("Torso",Vector3.new(2,2,1),Theme.Colors.Electric,rig)
	local head=r6Part("Head",Vector3.new(2,1,1),Color3.fromRGB(178,123,72),rig)
	local rightArm=r6Part("Right Arm",Vector3.new(1,2,1),Color3.fromRGB(178,123,72),rig)
	local leftArm=r6Part("Left Arm",Vector3.new(1,2,1),Color3.fromRGB(178,123,72),rig)
	local rightLeg=r6Part("Right Leg",Vector3.new(1,2,1),Color3.fromRGB(12,15,12),rig)
	local leftLeg=r6Part("Left Leg",Vector3.new(1,2,1),Color3.fromRGB(12,15,12),rig)
	local humanoid=Instance.new("Humanoid")
	humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent=rig
	Instance.new("Animator").Parent=humanoid
	root.CFrame=CFrame.new(0,2.8,0);torso.CFrame=root.CFrame;head.CFrame=root.CFrame*CFrame.new(0,1.5,0);rightArm.CFrame=root.CFrame*CFrame.new(1.5,0,0);leftArm.CFrame=root.CFrame*CFrame.new(-1.5,0,0);rightLeg.CFrame=root.CFrame*CFrame.new(.5,-2,0);leftLeg.CFrame=root.CFrame*CFrame.new(-.5,-2,0)
	motor(root,"RootJoint",root,torso,CFrame.new(),CFrame.new())
	motor(torso,"Neck",torso,head,CFrame.new(0,1,0),CFrame.new(0,-.5,0))
	motor(torso,"Right Shoulder",torso,rightArm,CFrame.new(1,0.5,0),CFrame.new(-.5,0.5,0))
	motor(torso,"Left Shoulder",torso,leftArm,CFrame.new(-1,0.5,0),CFrame.new(.5,0.5,0))
	motor(torso,"Right Hip",torso,rightLeg,CFrame.new(.5,-1,0),CFrame.new(0,1,0))
	motor(torso,"Left Hip",torso,leftLeg,CFrame.new(-.5,-1,0),CFrame.new(0,1,0))
	rig.PrimaryPart=root
	rig:PivotTo(CFrame.new(0,2.1,0))
	local controller=CelebrationPoseController.new()
	task.spawn(function()
		controller:Play(rig,celebrationId,nil,{MinDuration=3600,ForceLoop=true})
		while viewport.Parent and rig.Parent do
			task.wait(.25)
		end
		controller:Reset(rig)
	end)
	return viewport
end

function UltimateTeamPage.new(context:any):CanvasGroup
	local group,scroll=PageBase.new("UltimateTeam",930)
	PageBase.heading(scroll,"VOLTRA ULTIMATE TEAM","SQUAD BUILDER","Build, move and manage the complete matchday roster.")
	local response=SquadService:GetSquad();local snapshot=response.Success and response.Data or {Slots={},SlotOrder={},Bench={},Reserves={},Club={},Rating=0,Chemistry=0,Filled=0,Formation="4-3-3",FormationOptions={"4-3-3"},CardMeta={}}
	local function lineupComplete(data:any):boolean
		if type(data)~="table"then return false end
		if data.IsComplete~=nil then return data.IsComplete==true end
		local benchFilled=0;for index=1,7 do if data.Bench and data.Bench[index]and data.Bench[index].Card then benchFilled+=1 end end
		return math.floor(tonumber(data.Filled)or 0)>=11 and benchFilled==7
	end
	local chemistryUnlocked=PlayabilityUnlockConfig.FeatureUnlocked(context.Data.Progression,"Chemistry")
	local packsUnlocked=PlayabilityUnlockConfig.FeatureUnlocked(context.Data.Progression,"Packs")
	local tactics=LiteConfig.DefaultTactics()
	for key,value in context.Data.Progression.TeamTactics or{}do tactics[key]=value end
	tactics.Sliders=tactics.Sliders or LiteConfig.DefaultTactics().Sliders
	context.SquadBuilderTrayState=context.SquadBuilderTrayState or {}
	local trayState=context.SquadBuilderTrayState
	trayState.ScrollByTab=trayState.ScrollByTab or {}
	local selectedCard:any?=nil;local selectedDetails:any?=nil;local pendingCardId:string?=nil;local tapMoveEnabled=false;local activeTab=table.find(TABS,trayState.ActiveTab) and trayState.ActiveTab or "Bench";local searchText=tostring(trayState.SearchText or "");local positionIndex=indexOrDefault(POSITIONS,trayState.PositionIndex or trayState.Position,1);local rarityIndex=indexOrDefault(RARITIES,trayState.RarityIndex or trayState.Rarity,1);local sortHigh=trayState.SortHigh~=false;local compareCard:any?=nil
	local targets={}
	local pitchNodes={}
	local lineupWarning=text(scroll,"INCOMPLETE LINEUP AND BENCH",UDim2.fromOffset(0,70),UDim2.new(1,0,0,20),10,Theme.Colors.Danger,Theme.Fonts.Strong)
	local function syncLineupWarning()local incomplete=not lineupComplete(snapshot);lineupWarning.Visible=incomplete;if context.SetSquadIncomplete then context.SetSquadIncomplete(incomplete)end end

	local summary=Panel.new({Name="TeamSummary",Position=UDim2.fromOffset(0,96),Size=UDim2.new(.19,-8,0,558)});summary.Parent=scroll
	local pitch=Panel.new({Name="FormationPitch",Position=UDim2.new(.19,8,0,96),Size=UDim2.new(.55,-16,0,558),Color=Theme.Colors.Pitch,ClipsDescendants=true});pitch.Parent=scroll
	local preview=Panel.new({Name="PlayerPreview",Position=UDim2.new(.74,8,0,96),Size=UDim2.new(.26,-8,0,558)});preview.Parent=scroll
	local tray=Panel.new({Name="RosterTray",Position=UDim2.fromOffset(0,670),Size=UDim2.new(1,0,0,230),ClipsDescendants=true});tray.Parent=scroll

	-- Clean pitch markings sit behind fixed formation slots.
	local field=Instance.new("Frame");field.BackgroundTransparency=1;field.Position=UDim2.fromOffset(18,18);field.Size=UDim2.new(1,-36,1,-36);field.Parent=pitch
	local fieldStroke=Instance.new("UIStroke");fieldStroke.Color=Color3.fromHex("52634A");fieldStroke.Thickness=2;fieldStroke.Transparency=.18;fieldStroke.Parent=field
	local half=Instance.new("Frame");half.BackgroundColor3=Color3.fromHex("52634A");half.BackgroundTransparency=.22;half.BorderSizePixel=0;half.Position=UDim2.fromScale(0,.5);half.Size=UDim2.new(1,0,0,2);half.Parent=field
	local circle=Instance.new("Frame");circle.AnchorPoint=Vector2.new(.5,.5);circle.BackgroundTransparency=1;circle.Position=UDim2.fromScale(.5,.5);circle.Size=UDim2.fromOffset(94,94);circle.Parent=field;corner(circle,47);local circleStroke=Instance.new("UIStroke");circleStroke.Color=Color3.fromHex("52634A");circleStroke.Thickness=2;circleStroke.Transparency=.2;circleStroke.Parent=circle
	local cardsLayer=Instance.new("Frame");cardsLayer.BackgroundTransparency=1;cardsLayer.Size=UDim2.fromScale(1,1);cardsLayer.Parent=field

	local teamContent=Instance.new("Frame");teamContent.BackgroundTransparency=1;teamContent.Position=UDim2.fromOffset(14,12);teamContent.Size=UDim2.new(1,-28,1,-24);teamContent.Parent=summary
	local previewContent=Instance.new("Frame");previewContent.BackgroundTransparency=1;previewContent.Position=UDim2.fromOffset(14,12);previewContent.Size=UDim2.new(1,-28,1,-24);previewContent.Parent=preview
	local tabBar=Instance.new("Frame");tabBar.BackgroundTransparency=1;tabBar.Position=UDim2.fromOffset(12,10);tabBar.Size=UDim2.new(1,-24,0,34);tabBar.Parent=tray
	local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,7);tabLayout.Parent=tabBar
	local trayContent=Instance.new("Frame");trayContent.BackgroundTransparency=1;trayContent.Position=UDim2.fromOffset(12,52);trayContent.Size=UDim2.new(1,-24,1,-62);trayContent.Parent=tray
	local tabButtons={}

	local renderAll:()->();local renderTray:()->();local renderPitch:()->();local renderSummary:()->();local renderPreview:()->();local repositionPitchOnly:()->();local selectCard:(any)->();local requestMove:(string,string,any?)->();local openCardMenu:(any)->();local destinationTap:(any?,string,any?)->();local openCustomizeHub:()->()
	local function toast(message:string,kind:string?) context.Toast({Title="SQUAD BUILDER",Message=message,Kind=kind or "Info"}) end
	local function saveTrayState()
		trayState.ActiveTab=activeTab
		trayState.SearchText=searchText
		trayState.PositionIndex=positionIndex
		trayState.Position=POSITIONS[positionIndex]
		trayState.RarityIndex=rarityIndex
		trayState.Rarity=RARITIES[rarityIndex]
		trayState.SortHigh=sortHigh
	end
	local function resetActiveTrayScroll() trayState.ScrollByTab[activeTab]=0;trayState.SkipNextScrollRemember=true end
	local function apply(result:any)
		if not result.Success then toast(result.Message or "Roster action rejected.","Error");return end
		saveTrayState()
		snapshot=result.Data or snapshot;syncLineupWarning();toast(result.Message or "Squad saved.");if result.CompletedNow then toast("BUILD FIRST XI COMPLETE - reward ready.","Reward") end;renderAll()
	end
	requestMove=function(cardId:string,destinationType:string,destinationSlot:any?) saveTrayState();apply(SquadService:MovePlayer(cardId,destinationType,destinationSlot)) end
	local formationSaveToken=0
	local formationOpen=false
	local function applyFormationLocally(name:string)
		local formation=FormationConfig.Formations[name]
		if not formation then return end
		snapshot.Formation=name
		snapshot.FormationOptions=snapshot.FormationOptions or {"4-3-3","4-4-2","4-2-3-1","3-5-2","5-3-2"}
		for slot,data in snapshot.Slots or {} do
			local definition=formation[slot]
			if definition then
				data.Coordinate=Vector2.new(definition.X,definition.Y)
				data.Label=definition.Label
				data.Expected=definition.Expected
				if data.Card then
					local position=tostring(data.Card.Position or data.Card.bestPosition or "")
					data.OutOfPosition=position~="" and definition.Expected~="" and position~=definition.Expected and not string.find(definition.Expected,position,1,true)
				end
			end
		end
	end
	local function setFormationInstant(name:string)
		if name==snapshot.Formation then formationOpen=false;renderSummary();return end
		formationSaveToken+=1
		local token=formationSaveToken
		formationOpen=false
		applyFormationLocally(name)
		renderSummary()
		repositionPitchOnly()
		task.spawn(function()
			local result=SquadService:SetFormation(name)
			if token~=formationSaveToken then return end
			if result.Success then
				if result.Data then
					snapshot=result.Data
					renderSummary()
					repositionPitchOnly()
					if selectedCard then renderPreview()end
				end
			else
				toast(result.Message or "Formation change rejected.","Error")
				local refresh=SquadService:GetSquad()
				if refresh.Success and token==formationSaveToken then snapshot=refresh.Data;renderAll()end
			end
		end)
	end

	local function registerTarget(instance:GuiObject,kind:string,slot:any?) table.insert(targets,{Instance=instance,Kind=kind,Slot=slot}) end
	local function targetAt(screenPosition:Vector2):any?
		local best=nil;local bestArea=math.huge
		for _,target in targets do local instance=target.Instance;if instance.Parent and instance.Visible then local p,s=instance.AbsolutePosition,instance.AbsoluteSize;if screenPosition.X>=p.X and screenPosition.X<=p.X+s.X and screenPosition.Y>=p.Y and screenPosition.Y<=p.Y+s.Y then local area=s.X*s.Y;if area<bestArea then best=target;bestArea=area end end end end
		return best
	end
	local activeDropGlow:UIStroke?=nil
	local function setDropGlow(destination:any?)
		if activeDropGlow then activeDropGlow:Destroy();activeDropGlow=nil end
		if not destination or not destination.Instance or not destination.Instance.Parent then return end
		activeDropGlow=Instance.new("UIStroke")
		activeDropGlow.Name="ActiveDropGlow"
		activeDropGlow.Color=Theme.Colors.White
		activeDropGlow.Thickness=2
		activeDropGlow.Transparency=.05
		activeDropGlow.Parent=destination.Instance
	end
	local dragController=DragController.new(group,{Threshold=3,AllowTouchDrag=true,HitTest=targetAt,OnDragStart=function(card:any) pendingCardId=card.Id;tapMoveEnabled=false end,OnHover=function(destination:any?) setDropGlow(destination) end,OnDrop=function(card:any,destination:any) setDropGlow(nil);pendingCardId=nil;tapMoveEnabled=false;requestMove(card.Id,destination.Kind,destination.Slot) end,OnCancel=function() setDropGlow(nil);pendingCardId=nil;tapMoveEnabled=false;toast("Move cancelled - the complete card returned to its original location.") end,OnDragEnd=function() setDropGlow(nil) end})
	group.Destroying:Connect(function() dragController:Destroy() end)
	local function addDrag(button:GuiButton,card:any,kind:string,slot:any?) dragController:Attach(button,card,function() destinationTap(card,kind,slot) end) end
	destinationTap=function(card:any?,kind:string,slot:any?)
		if tapMoveEnabled and pendingCardId and (not card or card.Id~=pendingCardId) then local id=pendingCardId;context.Flow:Confirmation("CONFIRM PLAYER MOVE","Move the selected player to this "..kind.." destination?","MOVE PLAYER",function() pendingCardId=nil;tapMoveEnabled=false;requestMove(id,kind,slot) end);return end
		if card then openCardMenu(card) end
	end

	repositionPitchOnly=function()
		local preservedTargets={}
		for _,target in targets do
			if target.Kind~="StartingXI" then table.insert(preservedTargets,target) end
		end
		targets=preservedTargets
		for _,slot in snapshot.SlotOrder or{}do
			local data=snapshot.Slots[slot]
			local node=pitchNodes[slot]
			if node and node.Parent and data then
				node.Position=UDim2.fromScale(data.Coordinate.X,data.Coordinate.Y)
				registerTarget(node,"StartingXI",slot)
				if not data.Card then
					local label=node:FindFirstChildWhichIsA("TextLabel")
					if label then label.Text="+\n"..(data.Label or tostring(slot))end
				end
			end
		end
	end

	local function makeCard(parent:Instance,card:any?,size:UDim2,kind:string,slot:any?,compact:boolean?):TextButton
		local selected=card~=nil and selectedCard~=nil and selectedCard.Id==card.Id
		local button:TextButton
		if card then
			local outOfPosition=kind=="StartingXI" and snapshot.Slots[slot] and snapshot.Slots[slot].OutOfPosition
			button=CompactPlayerCard.new({Parent=parent,Card=card,Size=size,Horizontal=compact==true,Selected=selected,Meta=rosterMeta(snapshot,card),ChemistryColor=compact and nil or (outOfPosition and Theme.Colors.Warning or Theme.Colors.Electric)})
			button.Name="Card_"..card.Id;addDrag(button,card,kind,slot)
		else
			button=Instance.new("TextButton");button.Name=kind.."Empty";button.AutoButtonColor=false;button.BackgroundColor3=Color3.fromHex("13200F");button.BackgroundTransparency=.28;button.BorderSizePixel=0;button.Size=size;button.Text="";button.Selectable=false;button.Parent=parent;corner(button,7)
			local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Border;stroke.Thickness=1;stroke.Transparency=.2;stroke.Parent=button
			local label=kind=="StartingXI" and (snapshot.Slots[slot] and snapshot.Slots[slot].Label or tostring(slot)) or kind=="Bench" and ("B"..slot) or "+";local empty=text(button,"+\n"..label,UDim2.new(),UDim2.fromScale(1,1),compact and 9 or 11,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center;empty.TextYAlignment=Enum.TextYAlignment.Center
		end
		button.AnchorPoint=compact and Vector2.zero or Vector2.new(.5,.5)
		if pendingCardId and (kind=="StartingXI" or kind=="Bench" or kind=="Reserves") then local targetGlow=Instance.new("UIStroke");targetGlow.Name="MoveDestinationGlow";targetGlow.Color=Theme.Colors.Electric;targetGlow.Thickness=1;targetGlow.Transparency=.38;targetGlow.Parent=button end
		if not card then button.Activated:Connect(function() destinationTap(nil,kind,slot) end) end;registerTarget(button,kind,slot);return button
	end

	local function closeMenu(menu:Instance) menu:Destroy() end
	local function movementProfileMenu(card:any,slot:string)
		local existing=group:FindFirstChild("MovementProfileOverlay");if existing then existing:Destroy()end
		local overlay=Instance.new("TextButton");overlay.Name="MovementProfileOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.2;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=70;overlay.Parent=group
		local menu=Panel.new({Name="MovementProfiles",Size=UDim2.fromScale(.9,.88),ClipsDescendants=false});menu.AnchorPoint=Vector2.new(.5,.5);menu.Position=UDim2.fromScale(.5,.5);menu.ZIndex=71;menu.Parent=overlay
		local menuConstraint=Instance.new("UISizeConstraint");menuConstraint.MinSize=Vector2.new(300,300);menuConstraint.MaxSize=Vector2.new(390,548);menuConstraint.Parent=menu
		text(menu,"AI MOVEMENT PROFILE",UDim2.fromOffset(20,16),UDim2.new(1,-40,0,22),10,Theme.Colors.Electric,Theme.Fonts.Strong)
		text(menu,string.upper(card.Name).."  /  "..string.upper(snapshot.Slots[slot].Label or slot),UDim2.fromOffset(20,40),UDim2.new(1,-40,0,24),14,Theme.Colors.White,Theme.Fonts.Display).TextTruncate=Enum.TextTruncate.AtEnd
		local holder=Instance.new("ScrollingFrame");holder.BackgroundTransparency=1;holder.BorderSizePixel=0;holder.Position=UDim2.fromOffset(18,78);holder.Size=UDim2.new(1,-36,1,-96);holder.AutomaticCanvasSize=Enum.AutomaticSize.Y;holder.CanvasSize=UDim2.new();holder.ScrollBarThickness=4;holder.ScrollBarImageColor3=Theme.Colors.Electric;holder.ZIndex=72;holder.Parent=menu
		local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,5);layout.Parent=holder
		local selected=tostring(snapshot.Slots[slot].MovementProfile or AIMovementProfileConfig.Default)
		for _,profileId in AIMovementProfileConfig.Order do
			local definition=AIMovementProfileConfig.Profiles[profileId]
			local row=Button.new({Text="",Variant=profileId==selected and"Primary"or"Secondary",Size=UDim2.new(1,0,0,52),OnActivated=function()closeMenu(overlay);apply(SquadService:SetMovementProfile(slot,profileId))end});row.ZIndex=73;row.Parent=holder
			local name=text(row,definition.Name,UDim2.fromOffset(12,6),UDim2.new(1,-24,0,16),9,profileId==selected and Theme.Colors.Black or Theme.Colors.White,Theme.Fonts.Strong);name.ZIndex=74
			local description=text(row,definition.Description,UDim2.fromOffset(12,24),UDim2.new(1,-24,0,20),7,profileId==selected and Theme.Colors.Black or Theme.Colors.Silver,Theme.Fonts.Strong);description.ZIndex=74;description.TextWrapped=true;description.TextYAlignment=Enum.TextYAlignment.Top
		end
		overlay.Activated:Connect(function()closeMenu(overlay)end)
	end
	local function actionMenu()
		if not selectedCard then return end;local card=selectedCard;local meta=rosterMeta(snapshot,card)
		local campaignProtected=card.CampaignBound==true or card.QuickSellBlocked==true or meta.CampaignBound==true or meta.CampaignProjectActive==true
		local campaignProtectionMessage=meta.CampaignProjectActive==true and "Retire this Club Project before changing its protected status."or"Campaign reward players are account-bound."
		local existing=group:FindFirstChild("PlayerActionOverlay")
		if existing then existing:Destroy() end
		local overlay=Instance.new("TextButton");overlay.Name="PlayerActionOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.3;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=60;overlay.Parent=group
		local menu=Panel.new({Name="PlayerActions",Size=UDim2.fromOffset(310,540),ClipsDescendants=false});menu.AnchorPoint=Vector2.new(.5,.5);menu.Position=UDim2.fromScale(.5,.5);menu.ZIndex=61;menu.Parent=overlay
		text(menu,"PLAYER ACTIONS",UDim2.fromOffset(20,16),UDim2.new(1,-40,0,24),9,Theme.Colors.Electric,Theme.Fonts.Strong);text(menu,card.Rating.."  "..card.Name.."  /  "..card.Position,UDim2.fromOffset(20,41),UDim2.new(1,-40,0,30),15,Theme.Colors.White,Theme.Fonts.Display)
		local holder=Instance.new("Frame");holder.BackgroundTransparency=1;holder.Position=UDim2.fromOffset(18,82);holder.Size=UDim2.new(1,-36,1,-100);holder.ZIndex=62;holder.Parent=menu;local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,5);layout.Parent=holder
		local function item(label:string,callback:()->()) local action=Button.new({Text=label,Variant="Secondary",Size=UDim2.new(1,0,0,35),OnActivated=function() closeMenu(overlay);callback() end});action.ZIndex=63;action.Parent=holder end
		item("VIEW DETAILS",function() context.OpenPlayerDetails(card.Id) end)
		item("COMPARE PLAYER",function() compareCard=card;toast("Select another player to compare against "..card.Name..".") end)
		item("MOVE PLAYER",function() pendingCardId=card.Id;tapMoveEnabled=UserInputService:GetLastInputType()==Enum.UserInputType.Touch;if tapMoveEnabled then toast("Tap a highlighted destination, then confirm the move.") else toast("Valid destinations are highlighted. Drag the card to move it.") end;renderAll() end)
		local movementSlot=nil;for slot,data in snapshot.Slots do if data.Card and data.Card.Id==card.Id then movementSlot=slot;break end end
		if movementSlot then item("AI MOVEMENT PROFILE",function()movementProfileMenu(card,movementSlot)end)end
		item("SEND TO BENCH",function() local destination=1;for index=1,7 do if not snapshot.Bench[index] or not snapshot.Bench[index].Card then destination=index;break end end;requestMove(card.Id,"Bench",destination) end)
		item("SEND TO RESERVES",function() requestMove(card.Id,"Reserves",nil) end)
		item("REMOVE FROM SQUAD",function() requestMove(card.Id,"Club",nil) end)
		item(campaignProtected and"PROTECTED"or"QUICK SELL",function()if campaignProtected then toast(campaignProtectionMessage,"Error")elseif meta.Locked then toast("Unlock this player before quick selling.","Error")elseif meta.Loan==true then toast("Loan players cannot be quick sold.","Error")elseif meta.Favorite==true then toast("Unfavorite this player before quick selling.","Error")else local value=QuickSellValueConfig.Value(card,meta);context.Flow:Confirmation("QUICK SELL "..string.upper(card.Name),"This permanently removes the card for "..value.." coins.","QUICK SELL",function()apply(SquadService:QuickSellCard(card.Id))end)end end)
		item(meta.Locked and "UNLOCK PLAYER" or "LOCK PLAYER",function() apply(SquadService:SetCardFlag(card.Id,"Locked",not meta.Locked)) end)
		item(meta.Favorite and "REMOVE FAVORITE" or "FAVORITE PLAYER",function() apply(SquadService:SetCardFlag(card.Id,"Favorite",not meta.Favorite)) end)
		overlay.Activated:Connect(function() closeMenu(overlay) end)
	end

	selectCard=function(card:any)
		if compareCard and compareCard.Id~=card.Id then toast(card.Name.." is "..math.abs(card.Rating-compareCard.Rating).." OVR "..(card.Rating>=compareCard.Rating and "higher" or "lower").." than "..compareCard.Name..".");compareCard=nil end
		selectedCard=card;selectedDetails=nil;local details=PlayerDatabaseService:GetDetails(card.Id);if details.Success then selectedDetails=details.Data end;renderAll()
	end
	openCardMenu=function(card:any) pendingCardId=nil;tapMoveEnabled=false;selectCard(card);task.defer(actionMenu) end

	renderSummary=function()
		for _,child in teamContent:GetChildren() do child:Destroy() end
		local command=Instance.new("Frame");command.BackgroundColor3=Theme.Colors.Gunmetal;command.BackgroundTransparency=.18;command.BorderSizePixel=0;command.Position=UDim2.fromOffset(0,0);command.Size=UDim2.new(1,0,0,136);command.Parent=teamContent;corner(command,8);local commandStroke=Instance.new("UIStroke");commandStroke.Color=Theme.Colors.Electric;commandStroke.Thickness=1;commandStroke.Transparency=.58;commandStroke.Parent=command
		text(command,"CLUB COMMAND",UDim2.fromOffset(12,8),UDim2.new(1,-24,0,16),7,Theme.Colors.Electric,Theme.Fonts.Strong)
		text(command,string.upper(snapshot.TeamName or "YOUR CLUB"),UDim2.fromOffset(12,25),UDim2.new(1,-70,0,28),13,Theme.Colors.White,Theme.Fonts.Display).TextTruncate=Enum.TextTruncate.AtEnd
		if snapshot.ClubIdentity then local badge=BadgePreview.new(command,snapshot.ClubIdentity,UDim2.fromOffset(44,44));badge.AnchorPoint=Vector2.new(1,0);badge.Position=UDim2.new(1,-10,0,12);badge.ZIndex=4 end
		local filled=tonumber(snapshot.Filled)or 0
		if filled<=0 then for _,slot in snapshot.SlotOrder or{}do if snapshot.Slots[slot] and snapshot.Slots[slot].Card then filled+=1 end end end
		local rating=tonumber(snapshot.Rating)or 0
		local chemistry=tonumber(snapshot.Chemistry)or 0
		text(command,tostring(rating),UDim2.fromOffset(12,60),UDim2.fromOffset(58,36),28,Theme.Colors.Electric,Theme.Fonts.Display)
		text(command,"OVR",UDim2.fromOffset(66,70),UDim2.fromOffset(36,16),8,Theme.Colors.Muted,Theme.Fonts.Strong)
		text(command,chemistryUnlocked and tostring(chemistry).."/33"or"LOCKED",UDim2.fromOffset(104,66),UDim2.new(1,-116,0,24),17,chemistryUnlocked and Theme.Colors.White or Theme.Colors.Muted,Theme.Fonts.Display)
		text(command,chemistryUnlocked and"CHEMISTRY"or"AFTER MATCH 3",UDim2.fromOffset(106,92),UDim2.new(1,-118,0,14),7,Theme.Colors.Muted,Theme.Fonts.Strong)
		local function meter(labelValue:string,ratio:number,y:number,color:Color3)
			text(command,labelValue,UDim2.fromOffset(12,y),UDim2.new(1,-24,0,13),7,Theme.Colors.Silver,Theme.Fonts.Strong)
			local bar=Instance.new("Frame");bar.BackgroundColor3=Theme.Colors.Black;bar.BackgroundTransparency=.18;bar.BorderSizePixel=0;bar.Position=UDim2.fromOffset(12,y+16);bar.Size=UDim2.new(1,-24,0,5);bar.Parent=command;corner(bar,3)
			local fill=Instance.new("Frame");fill.BackgroundColor3=color;fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(math.clamp(ratio,0,1),1);fill.Parent=bar;corner(fill,3)
		end
		meter("MATCHDAY XI  "..tostring(math.min(filled,11)).." / 11",math.min(filled,11)/11,108,filled>=11 and Theme.Colors.Electric or Theme.Colors.Warning)
		text(teamContent,"FORMATION",UDim2.fromOffset(0,154),UDim2.new(1,0,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong)
		local formation=Button.new({Text=snapshot.Formation.."  V",Variant="Secondary",Size=UDim2.new(1,0,0,34),OnActivated=function() formationOpen=not formationOpen;renderSummary() end});formation.Position=UDim2.fromOffset(0,176);formation.Parent=teamContent
		local nextY=218;if formationOpen then for _,name in snapshot.FormationOptions do local option=Button.new({Text=name,Variant=name==snapshot.Formation and "Primary" or "Secondary",Size=UDim2.new(1,0,0,28),OnActivated=function() setFormationInstant(name) end});option.Position=UDim2.fromOffset(0,nextY);option.Parent=teamContent;nextY+=31 end end
		local objective=snapshot.Objective;if not formationOpen then local objectiveY=232;text(teamContent,"STARTER OBJECTIVE",UDim2.fromOffset(0,objectiveY),UDim2.new(1,0,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong);text(teamContent,objective and (objective.title.."\n"..objective.progress.." / "..objective.target) or "JOURNEY COMPLETE",UDim2.fromOffset(0,objectiveY+20),UDim2.new(1,0,0,43),8,Theme.Colors.Silver,Theme.Fonts.Strong);if objective and (objective.status=="claimable" or objective.status=="completed") then local claim=Button.new({Text="CLAIM REWARD",Variant="Primary",Size=UDim2.new(1,0,0,32),OnActivated=function() local result=ProgressionService:Claim("Objective",objective.objectiveId);if result.Success then toast(result.Message or "Reward claimed.","Reward");local refresh=SquadService:GetSquad();if refresh.Success then snapshot=refresh.Data;renderAll() end else toast(result.Message or "Claim failed.","Error") end end});claim.Position=UDim2.fromOffset(0,302);claim.Parent=teamContent end end
		local auto=Button.new({Text="AUTO BUILD",Variant="Primary",Size=UDim2.new(1,0,0,36),OnActivated=function() apply(SquadService:AutoBuildSquad()) end});auto.Position=UDim2.new(0,0,1,-120);auto.Parent=teamContent
		local clear=Button.new({Text="CLEAR XI",Variant="Secondary",Size=UDim2.new(1,0,0,36),OnActivated=function() context.Flow:Confirmation("CLEAR STARTING XI","Move all starters to reserves?","CLEAR XI",function() apply(SquadService:ClearSquad()) end) end});clear.Position=UDim2.new(0,0,1,-78);clear.Parent=teamContent
		text(teamContent,"SAVED  "..os.date("!%H:%M:%S",snapshot.SavedAt or os.time()),UDim2.new(0,0,1,-28),UDim2.new(1,0,0,20),7,Theme.Colors.Electric,Theme.Fonts.Strong)
	end

	renderPitch=function()
		targets={};pitchNodes={};for _,child in cardsLayer:GetChildren() do child:Destroy() end
		for _,slot in snapshot.SlotOrder or {} do local data=snapshot.Slots[slot];local card=data and data.Card;local node=makeCard(cardsLayer,card,UDim2.fromOffset(76,94),"StartingXI",slot,false);node.Position=UDim2.fromScale(data.Coordinate.X,data.Coordinate.Y);pitchNodes[slot]=node end
	end

	renderPreview=function()
		for _,child in previewContent:GetChildren() do child:Destroy() end
		if not selectedCard then text(previewContent,"SELECT A PLAYER",UDim2.fromOffset(0,210),UDim2.new(1,0,0,30),15,Theme.Colors.Muted,Theme.Fonts.Display).TextXAlignment=Enum.TextXAlignment.Center;return end
		local card=selectedCard;local portrait=AvatarPortraitGenerator.new(previewContent,card,UDim2.new(1,0,0,156),false);portrait.Position=UDim2.fromOffset(0,0)
		text(previewContent,card.Rating.."  "..card.Position,UDim2.fromOffset(10,10),UDim2.new(1,-20,0,27),18,Theme.Colors.White,Theme.Fonts.Display).ZIndex=4;text(previewContent,card.Name,UDim2.fromOffset(0,164),UDim2.new(1,0,0,28),14,Theme.Colors.White,Theme.Fonts.Display)
		local stats=selectedDetails and selectedDetails.mainStats or {PAC="-",SHO="-",PAS="-",DRI="-",DEF="-",PHY="-"};local details=selectedDetails and (selectedDetails.detailedStats or selectedDetails.DetailedStats) or {};local isGoalkeeper=string.upper(tostring(card.Position or card.bestPosition or ""))=="GK";local statHolder=Instance.new("Frame");statHolder.BackgroundTransparency=1;statHolder.Position=UDim2.fromOffset(0,202);statHolder.Size=UDim2.new(1,0,0,94);statHolder.Parent=previewContent;local grid=Instance.new("UIGridLayout");grid.CellSize=UDim2.new(1/3,-5,0,43);grid.CellPadding=UDim2.fromOffset(6,6);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=statHolder;local displayStats=isGoalkeeper and {{Key="gkDiving",Label="DIV",Value=details.gkDiving or details.GKDiving or 0},{Key="gkHandling",Label="HAN",Value=details.gkHandling or details.GKHandling or 0},{Key="gkKicking",Label="KIC",Value=details.gkKicking or details.GKKicking or 0},{Key="gkPositioning",Label="POS",Value=details.gkPositioning or details.GKPositioning or 0},{Key="gkReflexes",Label="REF",Value=details.gkReflexes or details.GKReflexes or 0}} or {{Key="PAC",Label="PAC",Value=stats.PAC},{Key="SHO",Label="SHO",Value=stats.SHO},{Key="PAS",Label="PAS",Value=stats.PAS},{Key="DRI",Label="DRI",Value=stats.DRI},{Key="DEF",Label="DEF",Value=stats.DEF},{Key="PHY",Label="PHY",Value=stats.PHY}};for index,item in displayStats do local chip=Panel.new({Name=item.Label});chip.LayoutOrder=index;chip.Parent=statHolder;text(chip,tostring(item.Value or "-"),UDim2.fromOffset(0,4),UDim2.new(1,0,0,20),13,Theme.Colors.Electric,Theme.Fonts.Display).TextXAlignment=Enum.TextXAlignment.Center;text(chip,item.Label,UDim2.fromOffset(0,24),UDim2.new(1,0,0,14),7,Theme.Colors.Muted,Theme.Fonts.Strong).TextXAlignment=Enum.TextXAlignment.Center end
		local location,locationSlot="Club",nil;for _,clubCard in snapshot.Club do if clubCard.Id==card.Id then location=clubCard.RosterLocation;locationSlot=clubCard.RosterSlot;break end end;local impact=location=="StartingXI" and snapshot.Slots[locationSlot] and snapshot.Slots[locationSlot].OutOfPosition and "OUT OF POSITION  /  -2 BASE CHEM" or location=="StartingXI" and "NATURAL ROLE  /  +2 BASE CHEM" or "NOT IN STARTING XI";text(previewContent,chemistryUnlocked and"CHEMISTRY IMPACT"or"CHEMISTRY LOCKED",UDim2.fromOffset(0,318),UDim2.new(1,0,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong);text(previewContent,chemistryUnlocked and impact or"COMPLETE INTRO MATCH 3",UDim2.fromOffset(0,338),UDim2.new(1,0,0,32),8,chemistryUnlocked and location=="StartingXI" and Theme.Colors.White or Theme.Colors.Silver,Theme.Fonts.Strong)
		local actions=Button.new({Text="PLAYER ACTIONS",Variant="Primary",Size=UDim2.new(1,0,0,40),OnActivated=actionMenu});actions.Position=UDim2.new(0,0,1,-50);actions.Parent=previewContent
	end

	renderTray=function()
		local scrollKey=activeTab
		local previousList=trayContent:FindFirstChild("RosterTrayList")
		if previousList and previousList:IsA("ScrollingFrame") and not trayState.SkipNextScrollRemember then trayState.ScrollByTab[tostring(trayState.RenderedTab or activeTab)]=previousList.CanvasPosition.X end
		trayState.SkipNextScrollRemember=nil
		saveTrayState()
		for _,child in trayContent:GetChildren() do child:Destroy() end;for name,button in tabButtons do Button.setPrimary(button,name==activeTab) end
		local controlsHeight=activeTab=="Club" and 36 or 0
		if activeTab=="Club" then
			local search=Instance.new("TextBox");search.BackgroundColor3=Theme.Colors.Gunmetal;search.BorderSizePixel=0;search.Position=UDim2.fromOffset(0,0);search.Size=UDim2.new(.42,-6,0,32);search.PlaceholderText="SEARCH CLUB PLAYERS";search.Text=searchText;search.TextColor3=Theme.Colors.White;search.PlaceholderColor3=Theme.Colors.Muted;search.TextSize=9;search.Font=Theme.Fonts.Strong;search.ClearTextOnFocus=false;search.Parent=trayContent;corner(search,5);search.FocusLost:Connect(function() searchText=search.Text;resetActiveTrayScroll();saveTrayState();renderTray() end)
			local pos=Button.new({Text="POS: "..POSITIONS[positionIndex],Variant="Secondary",Size=UDim2.new(.18,-4,0,32),OnActivated=function() positionIndex=positionIndex%#POSITIONS+1;resetActiveTrayScroll();saveTrayState();renderTray() end});pos.Position=UDim2.new(.42,4,0,0);pos.Parent=trayContent
			local rarity=Button.new({Text="RARITY: "..RARITIES[rarityIndex],Variant="Secondary",Size=UDim2.new(.22,-4,0,32),OnActivated=function() rarityIndex=rarityIndex%#RARITIES+1;resetActiveTrayScroll();saveTrayState();renderTray() end});rarity.Position=UDim2.new(.60,6,0,0);rarity.Parent=trayContent
			local sort=Button.new({Text=sortHigh and "OVR HIGH" or "OVR LOW",Variant="Secondary",Size=UDim2.new(.18,-4,0,32),OnActivated=function() sortHigh=not sortHigh;resetActiveTrayScroll();saveTrayState();renderTray() end});sort.Position=UDim2.new(.82,8,0,0);sort.Parent=trayContent
		end
		local list=Instance.new("ScrollingFrame");list.Name="RosterTrayList";list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(0,controlsHeight+6);list.Size=UDim2.new(1,0,1,-controlsHeight-6);list.CanvasSize=UDim2.new();list.ScrollingDirection=Enum.ScrollingDirection.X;list.ScrollingEnabled=true;list.Active=true;list.Selectable=false;list.ElasticBehavior=Enum.ElasticBehavior.WhenScrollable;list.ScrollBarThickness=5;list.ScrollBarImageColor3=Theme.Colors.Electric;list.Parent=trayContent;local layout=Instance.new("UIListLayout");layout.FillDirection=Enum.FillDirection.Horizontal;layout.Padding=UDim.new(0,8);layout.Parent=list
		local function updateCanvas()if not list.Parent then return end;list.CanvasSize=UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X+8,list.AbsoluteSize.X),0)end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas);list:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)
		list:GetPropertyChangedSignal("CanvasPosition"):Connect(function() if list.Parent then trayState.ScrollByTab[scrollKey]=list.CanvasPosition.X end end)
		list.InputChanged:Connect(function(input)if input.UserInputType~=Enum.UserInputType.MouseWheel then return end;local maxX=math.max(0,list.AbsoluteCanvasSize.X-list.AbsoluteWindowSize.X);list.CanvasPosition=Vector2.new(math.clamp(list.CanvasPosition.X-input.Position.Z*72,0,maxX),0)end)
		local entries={};if activeTab=="Bench" then for index=1,7 do table.insert(entries,{Card=snapshot.Bench[index] and snapshot.Bench[index].Card or nil,Kind="Bench",Slot=index}) end elseif activeTab=="Reserves" then for index,card in snapshot.Reserves do table.insert(entries,{Card=card,Kind="Reserves",Slot=index}) end elseif activeTab=="Starting XI" then for _,slot in snapshot.SlotOrder do table.insert(entries,{Card=snapshot.Slots[slot].Card,Kind="StartingXI",Slot=slot}) end elseif activeTab=="Customize" then table.insert(entries,{Card=nil,Kind="Customize",Slot=nil}) else for _,card in snapshot.Club do local match=(POSITIONS[positionIndex]=="ALL" or card.Position==POSITIONS[positionIndex]) and (RARITIES[rarityIndex]=="ALL" or string.upper(card.Rarity)==RARITIES[rarityIndex]) and (searchText=="" or string.find(string.lower(card.Name),string.lower(searchText),1,true));if match then table.insert(entries,{Card=card,Kind="Club",Slot=nil}) end end;table.sort(entries,function(a,b)
			local ratingA=tonumber(a.Card and a.Card.Rating)or 0;local ratingB=tonumber(b.Card and b.Card.Rating)or 0
			if ratingA~=ratingB then if sortHigh then return ratingA>ratingB else return ratingA<ratingB end end
			local rarityA=RARITY_RANK[string.upper(tostring(a.Card and a.Card.Rarity or ""))] or 0;local rarityB=RARITY_RANK[string.upper(tostring(b.Card and b.Card.Rarity or ""))] or 0
			if rarityA~=rarityB then return sortHigh and rarityA>rarityB or rarityA<rarityB end
			local nameA=string.lower(tostring(a.Card and a.Card.Name or""));local nameB=string.lower(tostring(b.Card and b.Card.Name or""))
			if nameA~=nameB then return nameA<nameB end
			local idA=tostring(a.Card and(a.Card.Id or a.Card.cardInstanceId)or"");local idB=tostring(b.Card and(b.Card.Id or b.Card.cardInstanceId)or"")
			return idA<idB
		end) end
		for order,entry in entries do
			if activeTab=="Customize" then
				local open=Button.new({Text="OPEN CUSTOMIZE LOCKER",Variant="Primary",Size=UDim2.fromOffset(260,68),OnActivated=openCustomizeHub})
				open.LayoutOrder=order
				open.Parent=list
				continue
			end
			local card:TextButton
			if activeTab=="Club" and entry.Card then card=WidePlayerCard.new({Parent=list,Card=entry.Card,Size=UDim2.fromOffset(390,112),Selected=selectedCard and selectedCard.Id==entry.Card.Id,Meta=rosterMeta(snapshot,entry.Card)});addDrag(card,entry.Card,entry.Kind,entry.Slot);registerTarget(card,entry.Kind,entry.Slot)
			else card=makeCard(list,entry.Card,UDim2.fromOffset(150,68),entry.Kind,entry.Slot,true) end
			card.LayoutOrder=order
		end
		if activeTab=="Reserves" then registerTarget(list,"Reserves",nil) elseif activeTab=="Club" then registerTarget(list,"Club",nil) end
		task.defer(function()
			updateCanvas()
			if list.Parent then
				local maxX=math.max(0,list.AbsoluteCanvasSize.X-list.AbsoluteWindowSize.X)
				local remembered=tonumber(trayState.ScrollByTab[scrollKey]) or 0
				list.CanvasPosition=Vector2.new(math.clamp(remembered,0,maxX),0)
			end
		end)
		trayState.RenderedTab=activeTab
	end

	renderAll=function()
		if selectedCard then local replacement=nil;for _,card in snapshot.Club do if card.Id==selectedCard.Id then replacement=card;break end end;selectedCard=replacement end
		syncLineupWarning()
		renderSummary();renderPitch();renderPreview();renderTray()
	end

	local shortcutOverlayNames={"PackHubOverlay","ObjectivesHubOverlay","TacticsHubOverlay","CustomizeHubOverlay","PlayerActionOverlay","ModalOverlay"}
	local function clearShortcutOverlays(exceptName:string?)
		for _,name in shortcutOverlayNames do
			if name~=exceptName then
				local existing=group:FindFirstChild(name)
				if existing then existing:Destroy() end
			end
		end
	end

	local openPackHub:(()->())
	openPackHub=function()
		clearShortcutOverlays("PackHubOverlay")
		local existing=group:FindFirstChild("PackHubOverlay")
		if existing then existing:Destroy() end
		local response=PackService:GetInventory();if not response.Success then toast(response.Message or "Pack inventory unavailable.","Error");return end
		local packData=response.Data or {Packs={},History={}};local selectedTab="My Packs";local packTabs={"My Packs","Store Packs","Pack Odds","History"};local storeOrder={"starter_pack","bronze_pack","silver_pack","gold_pack","elite_pack","voltra_pack"}
		local overlay=Instance.new("TextButton");overlay.Name="PackHubOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.12;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=70;overlay.Parent=group
		local hub=Panel.new({Name="PackHub",Size=UDim2.fromOffset(900,580),ClipsDescendants=true});hub.AnchorPoint=Vector2.new(.5,.5);hub.Position=UDim2.fromScale(.5,.5);hub.ZIndex=71;hub.Parent=overlay
		text(hub,"ULTIMATE TEAM PACKS",UDim2.fromOffset(24,16),UDim2.new(1,-150,0,34),21,Theme.Colors.White,Theme.Fonts.Display).ZIndex=73
		text(hub,"UNOPENED INVENTORY  /  STORE  /  TRANSPARENT ODDS  /  OPEN HISTORY",UDim2.fromOffset(24,50),UDim2.new(1,-48,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=73
		local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(96,34),OnActivated=function() overlay:Destroy() end});close.Position=UDim2.new(1,-120,0,20);close.ZIndex=74;close.Parent=hub
		local tabBar=Instance.new("Frame");tabBar.BackgroundTransparency=1;tabBar.Position=UDim2.fromOffset(24,78);tabBar.Size=UDim2.new(1,-48,0,36);tabBar.ZIndex=73;tabBar.Parent=hub;local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,8);tabLayout.Parent=tabBar
		local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(24,124);body.Size=UDim2.new(1,-48,1,-148);body.ZIndex=72;body.Parent=hub
		local tabButtons={};local renderTab:()->()
		local function oddsFor(definition:any):string local values={};for _,rarity in {"Starter","Common","Bronze","Silver","Gold","Rare","Elite","Legendary","Icon","Mythic"} do local chance=definition.Odds and definition.Odds[rarity];if chance and chance>0 then table.insert(values,string.format("%s %.2g%%",string.upper(rarity),chance)) end end;return table.concat(values,"   ")..(definition.GuaranteedMinRarity and ("   /   GUARANTEED "..string.upper(definition.GuaranteedMinRarity).."+") or "") end
		local function refreshData() local fresh=PackService:GetInventory();if fresh.Success then packData=fresh.Data end end
		local function openOwned(pack:any)
			local oddsText=oddsFor(pack);context.Flow:PackPreview({Title=pack.name,Subtitle=pack.CardCount.." PLAYER CARDS",Detail=(pack.description or "VTR player pack").."\n\n"..oddsText},{Label="OPEN PACK"},function()
				local opened=PackService:Open(pack.packInstanceId);if not opened.Success then toast(opened.Message or "Pack opening failed.","Error");return end
				overlay:Destroy();local revealData=opened.Data and (opened.Data.Reveals or opened.Data) or opened.Data;context.Flow:PackOpening(pack.name,function() local refreshed=SquadService:GetSquad();if refreshed.Success then snapshot=refreshed.Data;renderAll() end;toast("Pack contents secured in your Club.","Reward") end,revealData)
			end)
		end
		local function offerOpenNow(delivered:any)
			context.Flow:OfferPackDelivery(delivered,function()toast("Pack contents secured in your Club.","Reward")end,function()overlay:Destroy()end)
		end
		renderTab=function()
			for _,child in body:GetChildren() do child:Destroy() end;for name,button in tabButtons do Button.setPrimary(button,name==selectedTab) end
			local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Size=UDim2.fromScale(1,1);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.ScrollBarThickness=3;list.ScrollBarImageColor3=Theme.Colors.Electric;list.ZIndex=73;list.Parent=body;local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,9);layout.Parent=list
			local function row(titleValue:string,subtitle:string,meta:string,buttonText:string?,callback:(()->())?) local item=Panel.new({Name=titleValue,Size=UDim2.new(1,-6,0,92)});item.ZIndex=74;item.Parent=list;text(item,titleValue,UDim2.fromOffset(18,10),UDim2.new(1,-230,0,24),14,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75;text(item,subtitle,UDim2.fromOffset(18,37),UDim2.new(1,-230,0,17),8,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=75;text(item,meta,UDim2.fromOffset(18,58),UDim2.new(1,-230,0,18),7,Theme.Colors.Muted,Theme.Fonts.Body).ZIndex=75;if buttonText and callback then local action=Button.new({Text=buttonText,Variant="Primary",Size=UDim2.fromOffset(170,38),OnActivated=callback});action.Position=UDim2.new(1,-190,.5,-19);action.ZIndex=75;action.Parent=item end end
			if selectedTab=="My Packs" then local packs=packData.Packs or {};if #packs==0 then local empty=text(list,"NO UNOPENED PACKS\n\nPurchase a pack in Store Packs or earn one from objectives.",UDim2.fromOffset(0,140),UDim2.new(1,0,0,90),13,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center else for _,pack in packs do row(pack.name,pack.CardCount.." PLAYERS  /  UNOPENED",pack.description or "VTR player pack","OPEN PACK",function() openOwned(pack) end) end end
			elseif selectedTab=="Store Packs" then for _,id in storeOrder do local definition=Catalog.Packs[id];row(definition.Name,definition.CardCount.." PLAYER CARDS",oddsFor(definition).."  /  ◈ "..definition.PriceCoins,"BUY PACK",function() context.Flow:Confirmation("BUY "..definition.Name,"The server will validate your coins and deliver a unique unopened pack instance.","BUY PACK",function() local purchased=LaunchService:Request("Purchase",{ItemType="Pack",Id=id});if not purchased.Success then toast(purchased.Message or "Purchase failed.","Error");return end;toast("Pack added to inventory.","Reward");refreshData();renderTab();if purchased.Data and purchased.Data.Pack then offerOpenNow(purchased.Data.Pack) end end) end) end
			elseif selectedTab=="Pack Odds" then for _,id in storeOrder do local definition=Catalog.Packs[id];row(definition.Name,definition.Description,oddsFor(definition),nil,nil) end
			else local history=packData.History or {};if #history==0 then local empty=text(list,"NO PACK HISTORY\n\nYour opened packs and best pulls will appear here.",UDim2.fromOffset(0,140),UDim2.new(1,0,0,90),13,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center else for _,entry in history do local best=entry.bestPull;local bestText=best and (best.rating.." "..best.position.."  "..best.name.."  /  "..string.upper(best.rarity)) or "BEST PULL UNAVAILABLE";row(entry.name,"OPENED  "..os.date("!%Y-%m-%d  %H:%M",entry.openedAt or 0),bestText,best and "VIEW PLAYER" or nil,best and function() context.OpenPlayerDetails(best.cardInstanceId) end or nil) end end end
		end
		for _,name in packTabs do local tab=Button.new({Text=string.upper(name),Variant=name==selectedTab and "Primary" or "Secondary",Size=UDim2.fromOffset(160,34),OnActivated=function() selectedTab=name;renderTab() end});tab.ZIndex=74;tab.Parent=tabBar;tabButtons[name]=tab end;renderTab()
	end

	local function openObjectivesHub()
		clearShortcutOverlays("ObjectivesHubOverlay")
		local existing=group:FindFirstChild("ObjectivesHubOverlay")
		if existing then existing:Destroy() end
		local progression=ProgressionService:Get()or context.Data.Progression;local selectedGroup="starter_journey";local groups={{"starter_journey","STARTER"},{"daily","DAILY"},{"weekly","WEEKLY"},{"milestone","MILESTONES"},{"loan_trials","LOAN PLAYERS"}}
		local overlay=Instance.new("TextButton");overlay.Name="ObjectivesHubOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.12;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=70;overlay.Parent=group
		local hub=Panel.new({Name="ObjectivesHub",Size=UDim2.fromOffset(900,580),ClipsDescendants=true});hub.AnchorPoint=Vector2.new(.5,.5);hub.Position=UDim2.fromScale(.5,.5);hub.ZIndex=71;hub.Parent=overlay
		text(hub,"OBJECTIVES",UDim2.fromOffset(24,16),UDim2.new(1,-150,0,34),22,Theme.Colors.White,Theme.Fonts.Display).ZIndex=73;text(hub,"LIVE SERVER PROGRESS  /  REWARDS  /  LIMITED LOAN PLAYERS",UDim2.fromOffset(24,50),UDim2.new(1,-48,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=73
		local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(96,34),OnActivated=function()overlay:Destroy()end});close.Position=UDim2.new(1,-120,0,20);close.ZIndex=74;close.Parent=hub
		local tabBar=Instance.new("Frame");tabBar.BackgroundTransparency=1;tabBar.Position=UDim2.fromOffset(24,78);tabBar.Size=UDim2.new(1,-48,0,36);tabBar.ZIndex=73;tabBar.Parent=hub;local tabLayout=Instance.new("UIListLayout");tabLayout.FillDirection=Enum.FillDirection.Horizontal;tabLayout.Padding=UDim.new(0,7);tabLayout.Parent=tabBar
		local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(24,124);body.Size=UDim2.new(1,-48,1,-148);body.ZIndex=72;body.Parent=hub;local buttons={};local renderObjectives:()->()
		renderObjectives=function()
			for _,child in body:GetChildren()do child:Destroy()end;for id,button in buttons do Button.setPrimary(button,id==selectedGroup)end
			local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Size=UDim2.fromScale(1,1);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.ScrollBarThickness=3;list.ScrollBarImageColor3=Theme.Colors.Electric;list.ZIndex=73;list.Parent=body;local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,9);layout.Parent=list
			local count=0;for _,objective in progression.Objectives or{}do if objective.groupId==selectedGroup then count+=1;local row=Panel.new({Name=objective.objectiveId,Size=UDim2.new(1,-6,0,102)});row.ZIndex=74;row.Parent=list;text(row,objective.title,UDim2.fromOffset(18,10),UDim2.new(1,-230,0,24),14,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75;text(row,objective.description,UDim2.fromOffset(18,37),UDim2.new(1,-230,0,17),8,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=75;local reward=objective.reward or{};text(row,string.upper(objective.status).."  /  "..objective.progress.." / "..objective.target.."  /  REWARD "..(reward.Amount or 1).." "..(reward.Type or"ITEM"),UDim2.fromOffset(18,62),UDim2.new(1,-230,0,18),8,objective.status=="claimable"and Theme.Colors.White or Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=75
				if objective.status=="claimable"then local claim=Button.new({Text="CLAIM REWARD",Variant="Primary",Size=UDim2.fromOffset(170,38),OnActivated=function()local result=ProgressionService:Claim("Objective",objective.objectiveId);if result.Success then toast(result.Message or"Reward claimed.","Reward");progression=ProgressionService:Get()or progression;renderObjectives()else toast(result.Message or"Claim rejected.","Error")end end});claim.Position=UDim2.new(1,-190,.5,-19);claim.ZIndex=76;claim.Parent=row end
			end end
			if count==0 then local empty=text(list,"NO OBJECTIVES IN THIS GROUP",UDim2.fromOffset(0,140),UDim2.new(1,0,0,40),14,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center end
		end
		for _,entry in groups do local id,labelValue=entry[1],entry[2];local tab=Button.new({Text=labelValue,Variant=id==selectedGroup and"Primary"or"Secondary",Size=UDim2.fromOffset(145,34),OnActivated=function()selectedGroup=id;renderObjectives()end});tab.ZIndex=74;tab.Parent=tabBar;buttons[id]=tab end;renderObjectives()
	end

	local function openTacticsHub()
		clearShortcutOverlays("TacticsHubOverlay")
		local existing=group:FindFirstChild("TacticsHubOverlay")
		if existing then existing:Destroy() end
		local overlay=Instance.new("TextButton");overlay.Name="TacticsHubOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.1;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=70;overlay.Parent=group
		local hub=Panel.new({Name="TacticsHub",Size=UDim2.fromOffset(1120,650),ClipsDescendants=true});hub.AnchorPoint=Vector2.new(.5,.5);hub.Position=UDim2.fromScale(.5,.5);hub.ZIndex=71;hub.Parent=overlay
		text(hub,"TACTICS",UDim2.fromOffset(24,16),UDim2.new(1,-150,0,34),22,Theme.Colors.White,Theme.Fonts.Display).ZIndex=73
		text(hub,"SQUAD FORMATION  /  AI IDENTITY  /  MATCH BEHAVIOR",UDim2.fromOffset(24,50),UDim2.new(1,-48,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=73
		local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(96,34),OnActivated=function()overlay:Destroy()end});close.Position=UDim2.new(1,-120,0,20);close.ZIndex=74;close.Parent=hub
		local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(24,88);body.Size=UDim2.new(1,-48,1,-112);body.ZIndex=72;body.Parent=hub
		local pitch=Panel.new({Name="TacticsPitch",Position=UDim2.fromOffset(0,0),Size=UDim2.new(.32,-8,1,0),Color=Theme.Colors.Pitch,ClipsDescendants=true});pitch.ZIndex=73;pitch.Parent=body
		local controls=Panel.new({Name="TacticsControls",Position=UDim2.new(.32,8,0,0),Size=UDim2.new(.68,-8,1,0),ClipsDescendants=true});controls.ZIndex=73;controls.Parent=body
		local labResponse=LaunchService:Request("GetAIBehaviorLabState",{})
		local labState=labResponse.Success and labResponse.Data or nil
		local developerLab=labState and labState.DeveloperAllowed==true
		local labMode=false
		local metadata=labState and labState.Metadata or AIBehaviorTuningConfig.ClientMetadata(false)
		if labState and labState.TeamTactics then tactics=labState.TeamTactics end
		local settingById:any={}
		for _,meta in metadata.Settings or{}do settingById[meta.Id]=meta end
		local function currentSettingValue(name:string,meta:any):number
			local overrides=type(tactics.GlobalOverrides)=="table"and tactics.GlobalOverrides or{}
			local sliders=type(tactics.Sliders)=="table"and tactics.Sliders or{}
			local value=tonumber(overrides[name])or tonumber(sliders[name])or tonumber(meta and meta.Default)or 50
			local min=tonumber(meta and meta.Min)or 0
			local max=tonumber(meta and meta.Max)or 100
			return math.clamp(value,min,max)
		end
		local function setSettingValue(name:string,meta:any,nextValue:number)
			tactics.Sliders=tactics.Sliders or{}
			tactics.GlobalOverrides=tactics.GlobalOverrides or{}
			local min=tonumber(meta and meta.Min)or 0
			local max=tonumber(meta and meta.Max)or 100
			local step=tonumber(meta and meta.Step)or 1
			local value=math.clamp(math.round(nextValue/step)*step,min,max)
			tactics.GlobalOverrides[name]=value
			if tactics.Sliders[name]~=nil and min==0 and max==100 then tactics.Sliders[name]=value end
			tactics.Custom=true
		end
		local function saveTactics():boolean
			local result=LaunchService:Request("SaveTeamTactics",tactics)
			if not result.Success then toast(result.Message or"Could not save AI tactics.","Error");return false end
			if result.Data and result.Data.TeamTactics then tactics=result.Data.TeamTactics end
			toast(result.Message or"AI tactics saved.","Reward")
			return true
		end
		local function renderHub()
			for _,child in pitch:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
			for _,child in controls:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
			text(pitch,string.upper(snapshot.Formation or"4-3-3"),UDim2.fromOffset(20,18),UDim2.new(1,-40,0,36),24,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75
			text(pitch,"CLICK A PLAYER TO SET AI MOVEMENT",UDim2.fromOffset(22,55),UDim2.new(1,-44,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=75
			local field=Instance.new("Frame");field.BackgroundTransparency=1;field.Position=UDim2.fromOffset(42,92);field.Size=UDim2.new(1,-84,1,-132);field.ZIndex=74;field.Parent=pitch
			local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Border;stroke.Thickness=2;stroke.Transparency=.18;stroke.Parent=field
			local half=Instance.new("Frame");half.BackgroundColor3=Theme.Colors.Border;half.BackgroundTransparency=.28;half.BorderSizePixel=0;half.Position=UDim2.fromScale(0,.5);half.Size=UDim2.new(1,0,0,2);half.ZIndex=75;half.Parent=field
			local dots=FORMATION_DOTS[snapshot.Formation or"4-3-3"] or FORMATION_DOTS["4-3-3"]
			for index,dot in dots do
				local slot=snapshot.SlotOrder and snapshot.SlotOrder[index]
				local slotData=slot and snapshot.Slots[slot]
				local card=slotData and slotData.Card
				local node=Instance.new("TextButton");node.AnchorPoint=Vector2.new(.5,.5);node.Position=UDim2.fromScale(dot[1],dot[2]);node.Size=UDim2.fromOffset(index==1 and 28 or 24,index==1 and 28 or 24);node.BackgroundColor3=index==1 and Theme.Colors.Electric or card and Theme.Colors.White or Theme.Colors.Gunmetal;node.BorderSizePixel=0;node.AutoButtonColor=false;node.Text=slotData and tostring(slotData.Label or slot)or"";node.TextColor3=index==1 and Theme.Colors.Black or card and Theme.Colors.Black or Theme.Colors.Muted;node.TextSize=6;node.Font=Theme.Fonts.Strong;node.ZIndex=76;node.Parent=field
				local round=Instance.new("UICorner");round.CornerRadius=UDim.new(1,0);round.Parent=node
				if card and slot then node.Activated:Connect(function()movementProfileMenu(card,slot)end)end
			end
			text(controls,"FORMATION",UDim2.fromOffset(22,18),UDim2.new(1,-44,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=75
			local formationRow=Instance.new("Frame");formationRow.BackgroundTransparency=1;formationRow.Position=UDim2.fromOffset(22,42);formationRow.Size=UDim2.new(1,-44,0,82);formationRow.ZIndex=74;formationRow.Parent=controls
			local formationGrid=Instance.new("UIGridLayout");formationGrid.CellSize=UDim2.new(.25,-7,0,34);formationGrid.CellPadding=UDim2.fromOffset(9,9);formationGrid.Parent=formationRow
			for _,name in snapshot.FormationOptions or{"4-3-3","4-4-2","4-2-3-1","3-5-2","5-3-2"}do
				local option=Button.new({Text=name,Variant=name==snapshot.Formation and"Primary"or"Secondary",Size=UDim2.new(1,0,1,0),OnActivated=function()setFormationInstant(name);task.defer(renderHub)end});option.ZIndex=76;option.Parent=formationRow
			end
			text(controls,"AI IDENTITY",UDim2.fromOffset(22,142),UDim2.new(1,-44,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=75
			local presetRow=Instance.new("Frame");presetRow.BackgroundTransparency=1;presetRow.Position=UDim2.fromOffset(22,166);presetRow.Size=UDim2.new(1,-44,0,164);presetRow.ZIndex=74;presetRow.Parent=controls
			local presetGrid=Instance.new("UIGridLayout");presetGrid.CellSize=UDim2.new(1/3,-8,0,34);presetGrid.CellPadding=UDim2.fromOffset(10,9);presetGrid.Parent=presetRow
			for _,presetId in TACTIC_PRESETS do
				local preset=LiteConfig.TacticPresets[presetId]
				local option=Button.new({Text=string.upper(preset.Name),Variant=tactics.PresetId==presetId and"Primary"or"Secondary",Size=UDim2.new(1,0,1,0),OnActivated=function()
					tactics=LiteConfig.NormalizeTactics({PresetId=presetId})
					if labMode then tactics.GlobalOverrides={}end
					renderHub()
				end});option.ZIndex=76;option.Parent=presetRow
			end
			text(controls,labMode and"AI BEHAVIOR LAB"or"BEHAVIOR SETTINGS",UDim2.fromOffset(22,348),UDim2.new(1,-44,0,18),8,Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=75
			if developerLab then
				local labToggle=Button.new({Text=labMode and"STANDARD"or"AI LAB",Variant=labMode and"Primary"or"Secondary",Size=UDim2.fromOffset(104,30),OnActivated=function()labMode=not labMode;renderHub()end});labToggle.Position=UDim2.new(1,-126,0,338);labToggle.ZIndex=77;labToggle.Parent=controls
			end
			local sliderList=Instance.new("ScrollingFrame");sliderList.BackgroundTransparency=1;sliderList.BorderSizePixel=0;sliderList.Position=UDim2.fromOffset(22,374);sliderList.Size=UDim2.new(1,-44,1,-434);sliderList.AutomaticCanvasSize=Enum.AutomaticSize.Y;sliderList.CanvasSize=UDim2.new();sliderList.ScrollBarThickness=4;sliderList.ScrollBarImageColor3=Theme.Colors.Electric;sliderList.ZIndex=74;sliderList.Parent=controls
			local categories:any=labMode and{}or{
				{"BUILD UP",{"BuildUpSpeed","PassTempo","PassingDirectness","SupportDistance","ForwardPassPriority","BackPassSafety","SwitchPlayFrequency","ThroughBallFrequency","PassRisk","OneTouchPassing","FirstTouchDirectness","ReceiverTrapAggression"}},
				{"ATTACK",{"AttackingWidth","WidthDiscipline","RunsInBehind","OverlapFrequency","UnderlapFrequency","FullbackAttack","MidfieldRotation","BoxRuns","CrossingFrequency","CutbackFrequency","FinalThirdPatience","ShotPatience","LongShotFrequency","DribblingFreedom","CreativeFreedom","CounterAttackFrequency"}},
				{"DEFENSE",{"DefensiveWidth","DefensiveDepth","DefensiveLineStepUp","PressingIntensity","PressTriggerDistance","CounterPress","TackleAggression","InterceptionRisk","MarkingTightness","LaneBlocking","BackLineCompactness","BoxProtection","ZoneDiscipline","LooseBallAggression","RecoveryRuns","SprintConservation","StaminaPressLimit"}},
				{"GOALKEEPER + SET PIECES",{"KeeperAggression","KeeperDistributionRisk","ShortGKDistribution","LongGKDistribution","FreeKickShortPass","FreeKickLongPass","CornerNearPost","CornerFarPost","SetPiecePatience","ClearanceHeight","RiskLevel"}},
			}
			if labMode then
				local grouped:any={}
				for _,meta in metadata.Settings or{}do grouped[meta.Category]=grouped[meta.Category]or{};table.insert(grouped[meta.Category],meta.Id)end
				for _,categoryName in metadata.Categories or{}do if grouped[categoryName]then table.insert(categories,{string.upper(categoryName),grouped[categoryName]})end end
			end
			local y=0
			local function drawSlider(name:string,row:number,column:number)
				local meta=settingById[name] or {Min=0,Max=100,Step=5,Unit="%",Label=name,LowLabel="LOW",HighLabel="HIGH",Systems={}}
				local value=currentSettingValue(name,meta)
				local xScale=column==1 and 0 or .5
				local xPad=column==1 and 0 or 10
				local rowFrame=Instance.new("Frame");rowFrame.BackgroundTransparency=1;rowFrame.Position=UDim2.new(xScale,xPad,0,row);rowFrame.Size=UDim2.new(.5,-10,0,34);rowFrame.ZIndex=75;rowFrame.Parent=sliderList
				text(rowFrame,string.upper(tostring(meta.Label or name)),UDim2.fromOffset(0,0),UDim2.new(1,-92,0,16),7,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=76
				local bar=Instance.new("Frame");bar.BackgroundColor3=Theme.Colors.Gunmetal;bar.BorderSizePixel=0;bar.Position=UDim2.new(0,0,0,22);bar.Size=UDim2.new(1,-104,0,7);bar.ZIndex=76;bar.Parent=rowFrame
				local min=tonumber(meta.Min)or 0;local max=tonumber(meta.Max)or 100;local step=tonumber(meta.Step)or 1;local alpha=max>min and(value-min)/(max-min)or 0
				local fill=Instance.new("Frame");fill.BackgroundColor3=Theme.Colors.Electric;fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(math.clamp(alpha,0,1),1);fill.ZIndex=77;fill.Parent=bar
				local minus=Button.new({Text="-",Variant="Secondary",Size=UDim2.fromOffset(24,23),OnActivated=function()setSettingValue(name,meta,value-step);renderHub()end});minus.Position=UDim2.new(1,-98,0,9);minus.ZIndex=77;minus.Parent=rowFrame
				local display=math.abs(value-math.floor(value))<.001 and tostring(value)or string.format("%.2f",value)
				local valueText=text(rowFrame,display..tostring(meta.Unit=="%"and""or" "..tostring(meta.Unit or"")),UDim2.new(1,-72,0,10),UDim2.fromOffset(40,20),8,Theme.Colors.Electric,Theme.Fonts.Display);valueText.TextXAlignment=Enum.TextXAlignment.Center;valueText.ZIndex=77
				local plus=Button.new({Text="+",Variant="Secondary",Size=UDim2.fromOffset(24,23),OnActivated=function()setSettingValue(name,meta,value+step);renderHub()end});plus.Position=UDim2.new(1,-26,0,9);plus.ZIndex=77;plus.Parent=rowFrame
			end
			for _,category in categories do
				text(sliderList,category[1],UDim2.fromOffset(0,y),UDim2.new(1,0,0,18),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=76
				y+=24
				for index,name in category[2]do
					local row=y+math.floor((index-1)/2)*40
					drawSlider(name,row,((index-1)%2)+1)
				end
				y+=math.ceil(#category[2]/2)*40+16
			end
			local bottomPad=Instance.new("Frame");bottomPad.BackgroundTransparency=1;bottomPad.Position=UDim2.fromOffset(0,y);bottomPad.Size=UDim2.new(1,0,0,8);bottomPad.Parent=sliderList
			local save=Button.new({Text="SAVE TACTICS",Variant="Primary",Size=UDim2.fromOffset(180,40),OnActivated=saveTactics});save.Position=UDim2.new(1,-202,1,-58);save.ZIndex=76;save.Parent=controls
			if developerLab and labMode then
				local saveProfile=Button.new({Text="SAVE AI PROFILE",Variant="Secondary",Size=UDim2.fromOffset(166,40),OnActivated=function()
					local result=LaunchService:Request("SaveAIBehaviorProfile",{Name="Lab Profile",Tactics=tactics})
					toast(result.Message or(result.Success and"AI profile saved."or"AI profile failed."),result.Success and"Reward"or"Error")
				end});saveProfile.Position=UDim2.new(1,-382,1,-58);saveProfile.ZIndex=76;saveProfile.Parent=controls
				local applyLive=Button.new({Text="APPLY LIVE",Variant="Secondary",Size=UDim2.fromOffset(140,40),OnActivated=function()
					local result=LaunchService:Request("ApplyAIBehaviorLive",{Side="Home",Tactics=tactics})
					toast(result.Message or(result.Success and"Applied live."or"Live apply failed."),result.Success and"Reward"or"Error")
				end});applyLive.Position=UDim2.new(1,-536,1,-58);applyLive.ZIndex=76;applyLive.Parent=controls
			end
		end
		renderHub()
	end

	openCustomizeHub=function()
		clearShortcutOverlays("CustomizeHubOverlay")
		local existing=group:FindFirstChild("CustomizeHubOverlay")
		if existing then existing:Destroy() end
		local progression=context.Data.Progression or {}
		local ownership=progression.StoreOwnership or {}
		local equipped=context.Data.UIState.EquippedCosmetics or {}
		ownership.Kits=type(ownership.Kits)=="table" and ownership.Kits or {}
		if not table.find(ownership.Kits,"home_kit") then table.insert(ownership.Kits,1,"home_kit") end
		if equipped.ActiveKit==nil or equipped.ActiveKit=="" then equipped.ActiveKit="home_kit" end
		context.Data.UIState.EquippedCosmetics=equipped
		local function has(list:any,id:string):boolean return type(list)=="table" and table.find(list,id)~=nil end
		local productIconByGrant={}
		for _,product in MonetizationConfig.Products do
			if product.GrantItemId and product.Icon then productIconByGrant[product.GrantItemId]=product.Icon end
		end
		local function kitIdentity(kit:any):any
			if kit and kit.Id=="home_kit" then
				local club=progression.ClubMembership or {}
				return {
					PrimaryColor=club.PrimaryColor or kit.Primary or"F5F7F2",
					SecondaryColor=club.SecondaryColor or kit.Secondary or"050505",
					AccentColor=club.AccentColor or kit.Accent or"B7FF1A",
					KitStyle=club.KitStyle or kit.Style or"Home",
				}
			end
			return {
				PrimaryColor=kit and kit.Primary or"F5F7F2",
				SecondaryColor=kit and kit.Secondary or"050505",
				AccentColor=kit and(kit.Accent or kit.Secondary)or"B7FF1A",
				KitStyle=kit and kit.Style or"Solid",
			}
		end
		local categories={
			{Id="Kits",Label="KITS",Slot="ActiveKit"},
			{Id="Boots",Label="BOOTS",Slot="BootStyle"},
			{Id="GoalEffects",Label="GOAL FX",Slot="GoalEffect"},
			{Id="Celebrations",Label="CELEBRATIONS",Slot="Celebration"},
			{Id="Walkouts",Label="WALKOUTS",Slot="Walkout"},
			{Id="GoalMusic",Label="GOAL MUSIC",Slot="GoalMusic"},
			{Id="Stadiums",Label="STADIUM",Slot="StadiumTheme"},
		}
		if ownsPass(ownership,"premium_club") then
			table.insert(categories,{Id="Club",Label="CLUB",Slot="ProfileFrame"})
		else
			table.insert(categories,{Id="Club",Label="CLUB STYLE",Slot="ProfileFrame"})
		end
		local selectedCategory=categories[1]
		local selectedItem:any?=nil
		local activePreviewSound:Sound?=nil
		local function stopGoalMusicPreview()
			if activePreviewSound then
				activePreviewSound:Stop()
				activePreviewSound:Destroy()
				activePreviewSound=nil
			end
		end
		local function playGoalMusicPreview(soundId:string,startSecond:number)
			stopGoalMusicPreview()
			local normalized=normalizeSoundAssetId(soundId)
			if normalized=="" then toast("Enter a valid Roblox sound id.","Warning");return end
			local sound=Instance.new("Sound")
			sound.Name="VTRGoalMusicCustomizePreview"
			sound.SoundId=normalized
			sound.Volume=.7
			sound.Parent=SoundService
			activePreviewSound=sound
			local started=false
			local function start()
				if started or not sound.Parent then return end
				started=true
				pcall(function()sound.TimePosition=math.max(0,startSecond)end)
				sound:Play()
				task.delay(8,function()
					if activePreviewSound==sound then stopGoalMusicPreview()elseif sound.Parent then sound:Destroy()end
				end)
			end
			if sound.IsLoaded then start()else sound.Loaded:Once(start);sound:Play();sound:Pause();task.delay(3,function()if activePreviewSound==sound and not started then start()end end)end
		end
		local overlay=Instance.new("TextButton");overlay.Name="CustomizeHubOverlay";overlay.AutoButtonColor=false;overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.08;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.Text="";overlay.ZIndex=70;overlay.Parent=group
		local hub=Panel.new({Name="CustomizeHub",Size=UDim2.new(1,-140,1,-120),ClipsDescendants=true});hub.AnchorPoint=Vector2.new(.5,.5);hub.Position=UDim2.fromScale(.5,.5);hub.ZIndex=71;hub.Parent=overlay
		local hubConstraint=Instance.new("UISizeConstraint");hubConstraint.MaxSize=Vector2.new(820,500);hubConstraint.MinSize=Vector2.new(320,390);hubConstraint.Parent=hub
		text(hub,"CUSTOMIZE",UDim2.fromOffset(22,14),UDim2.new(1,-140,0,32),21,Theme.Colors.White,Theme.Fonts.Display).ZIndex=73
		text(hub,"OWNED STORE COSMETICS  /  PREVIEW  /  EQUIP  /  MANAGE",UDim2.fromOffset(22,46),UDim2.new(1,-44,0,16),7,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=73
		local close=Button.new({Text="CLOSE",Variant="Secondary",Size=UDim2.fromOffset(86,30),OnActivated=function()stopGoalMusicPreview();overlay:Destroy()end});close.Position=UDim2.new(1,-108,0,18);close.ZIndex=74;close.Parent=hub
		local categoryRail=Panel.new({Name="CustomizeCategories",Position=UDim2.fromOffset(24,88),Size=UDim2.fromOffset(190,510),ClipsDescendants=true});categoryRail.ZIndex=73;categoryRail.Parent=hub
		local itemList=Panel.new({Name="CustomizeItems",Position=UDim2.fromOffset(230,88),Size=UDim2.new(1,-550,0,510),ClipsDescendants=true});itemList.ZIndex=73;itemList.Parent=hub
		local previewPanel=Panel.new({Name="CustomizePreview",Position=UDim2.new(1,-304,0,88),Size=UDim2.fromOffset(280,510),ClipsDescendants=true});previewPanel.ZIndex=73;previewPanel.Parent=hub
		local categoryButtons={}
		local renderHub:()->()
		local categoryHorizontal=false
		local itemColumns=2
		local previewCompact=false
		local function layoutCustomize()
			local width=math.max(hub.AbsoluteSize.X,320)
			local height=math.max(hub.AbsoluteSize.Y,420)
			if width<620 then
				categoryHorizontal=true;itemColumns=1;previewCompact=true
				categoryRail.Position=UDim2.fromOffset(14,76);categoryRail.Size=UDim2.new(1,-28,0,50)
				previewPanel.Position=UDim2.fromOffset(14,136);previewPanel.Size=UDim2.new(1,-28,0,math.max(160,math.floor(height*.31)))
				itemList.Position=UDim2.fromOffset(14,previewPanel.Position.Y.Offset+previewPanel.Size.Y.Offset+8);itemList.Size=UDim2.new(1,-28,1,-itemList.Position.Y.Offset-14)
			elseif width<900 then
				categoryHorizontal=true;itemColumns=1;previewCompact=false
				categoryRail.Position=UDim2.fromOffset(20,76);categoryRail.Size=UDim2.new(1,-40,0,50)
				itemList.Position=UDim2.fromOffset(20,136);itemList.Size=UDim2.new(.6,-12,1,-152)
				previewPanel.Position=UDim2.new(.6,8,0,136);previewPanel.Size=UDim2.new(.4,-28,1,-152)
			else
				categoryHorizontal=false;itemColumns=2;previewCompact=false
				categoryRail.Position=UDim2.fromOffset(22,76);categoryRail.Size=UDim2.fromOffset(138,height-104)
				itemList.Position=UDim2.fromOffset(172,76);itemList.Size=UDim2.new(1,-394,1,-104)
				previewPanel.Position=UDim2.new(1,-212,0,76);previewPanel.Size=UDim2.fromOffset(190,height-104)
			end
		end
		local function itemsFor(category:any):{any}
			local items={}
			if category.Id=="Kits" then
				for _,kit in Catalog.Kits do if has(ownership.Kits,kit.Id) then table.insert(items,{Id=kit.Id,Name=kit.Name,Subtitle=kit.Animated and"ANIMATED MATCH KIT"or"OWNED MATCH KIT",Detail=kit.Style or kit.Description or"Kit owned from Store.",Icon=productIconByGrant[kit.Id],Kit=kit,KitIdentity=kitIdentity(kit),Slot=category.Slot}) end end
			elseif category.Id=="Stadiums" then
				for _,stadium in Catalog.Stadiums do if has(ownership.Stadiums,stadium.Id) then table.insert(items,{Id=stadium.Id,Name=stadium.Name,Subtitle=stadium.Premium and"PREMIUM STADIUM"or"OWNED STADIUM",Detail="Stadium presentation option.",Slot=category.Slot}) end end
			else
				if category.Id=="Club" and ownsPass(ownership,"premium_club") then
					table.insert(items,{Id="premium_club_badge_studio",Name="CLUB BADGE STUDIO",Subtitle="PREMIUM CLUB GAMEPASS",Detail="Modify your club badge with premium shapes, presets, symbols, and colors. This updates ranked, campaign, and World Cup presentations.",Slot="ProfileFrame",PremiumClubEditor=true})
				end
				if category.Id=="GoalMusic" and ownsPass(ownership,"custom_goal_music") then
					table.insert(items,{Id="custom_goal_music_editor",Name="CUSTOM GOAL MUSIC",Subtitle="GAMEPASS CUSTOM TRACK",Detail="Paste a Roblox sound id, choose the start second, test it, then save. It plays for 8 seconds after you score.",Slot="GoalMusic",CustomGoalMusic=true})
				end
				for _,cosmetic in Catalog.Cosmetics do
					local cosmeticType=tostring(cosmetic.Type or "")
					local slot=nil
					if category.Id=="Boots" and cosmeticType=="Boot" then slot="BootStyle"
					elseif category.Id=="GoalEffects" and cosmeticType=="GoalEffect" then slot="GoalEffect"
					elseif category.Id=="Celebrations" and cosmeticType=="Celebration" then slot="Celebration"
					elseif category.Id=="Walkouts" and cosmeticType=="Walkout" then slot="Walkout"
					elseif category.Id=="GoalMusic" and cosmeticType=="GoalMusic" then slot="GoalMusic"
					elseif category.Id=="Club" and (cosmeticType=="ProfileFrame" or cosmeticType=="Crest" or cosmeticType=="Banner" or cosmeticType=="Nameplate") then slot=cosmeticType=="Banner" and"ClubBanner"or cosmeticType=="Nameplate"and"Nameplate"or cosmeticType=="Crest"and"Crest"or"ProfileFrame" end
					if slot and has(ownership.Cosmetics,cosmetic.Id) then table.insert(items,{Id=cosmetic.Id,Name=cosmetic.Name,Subtitle="OWNED "..string.upper(cosmeticType),Detail=cosmetic.SoundId and"Approved goal music track."or(cosmeticType=="Boot" and"Equipped boots appear on your players' feet in ranked matches."or"Store cosmetic owned by your club."),Icon=productIconByGrant[cosmetic.Id],Slot=slot,BootStyle=cosmeticType=="Boot"and cosmetic.Id or nil}) end
				end
			end
			table.sort(items,function(a,b)return tostring(a.Name)<tostring(b.Name)end)
			return items
		end
		local function equipItem(item:any)
			equipped[item.Slot]=item.Id
			context.Data.UIState.EquippedCosmetics=equipped
			context.StateService:SetCosmetic(item.Slot,item.Id)
			toast(item.Name.." equipped.","Reward")
			renderHub()
		end
		local function unequipSlot(slot:string)
			if slot=="ActiveKit" then
				equipped.ActiveKit=equipped.ActiveKit~="" and equipped.ActiveKit or "home_kit"
				context.Data.UIState.EquippedCosmetics=equipped
				if equipped.ActiveKit=="home_kit" then context.StateService:SetCosmetic("ActiveKit","home_kit") end
				toast("A match kit must stay equipped.")
				renderHub()
				return
			end
			equipped[slot]=""
			context.Data.UIState.EquippedCosmetics=equipped
			if context.StateService.ClearCosmetic then context.StateService:ClearCosmetic(slot) end
			toast("Cosmetic slot cleared.")
			renderHub()
		end
		renderHub=function()
			layoutCustomize()
			for _,child in categoryRail:GetChildren()do child:Destroy()end
			for _,child in itemList:GetChildren()do child:Destroy()end
			for _,child in previewPanel:GetChildren()do child:Destroy()end
			local categoryScroll=Instance.new("ScrollingFrame");categoryScroll.BackgroundTransparency=1;categoryScroll.BorderSizePixel=0;categoryScroll.Position=UDim2.fromOffset(8,8);categoryScroll.Size=UDim2.new(1,-16,1,-16);categoryScroll.CanvasSize=UDim2.new();categoryScroll.ScrollBarThickness=3;categoryScroll.ScrollBarImageColor3=Theme.Colors.Electric;categoryScroll.ZIndex=74;categoryScroll.Parent=categoryRail
			categoryScroll.ScrollingDirection=categoryHorizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
			categoryScroll.AutomaticCanvasSize=categoryHorizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
			local railLayout=Instance.new("UIListLayout");railLayout.Padding=UDim.new(0,7);railLayout.FillDirection=categoryHorizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical;railLayout.SortOrder=Enum.SortOrder.LayoutOrder;railLayout.Parent=categoryScroll
			for _,category in categories do
				local buttonSize=categoryHorizontal and UDim2.fromOffset(116,34) or UDim2.new(1,-4,0,34)
				local button=Button.new({Text=category.Label,Variant=category.Id==selectedCategory.Id and"Primary"or"Secondary",Size=buttonSize,OnActivated=function()selectedCategory=category;selectedItem=nil;renderHub()end});button.ZIndex=75;button.Parent=categoryScroll;categoryButtons[category.Id]=button
			end
			local items=itemsFor(selectedCategory)
			local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(14,14);list.Size=UDim2.new(1,-28,1,-28);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.ScrollBarThickness=4;list.ScrollBarImageColor3=Theme.Colors.Electric;list.ZIndex=74;list.Parent=itemList
			local grid=Instance.new("UIGridLayout");grid.CellSize=itemColumns==1 and UDim2.new(1,-6,0,104) or UDim2.new(.5,-8,0,104);grid.CellPadding=UDim2.fromOffset(8,8);grid.SortOrder=Enum.SortOrder.LayoutOrder;grid.Parent=list
			if #items==0 then local empty=text(list,"NO OWNED ITEMS\n\nBuy cosmetics in the Store and they will appear here.",UDim2.fromOffset(0,150),UDim2.new(1,0,0,88),15,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center end
			for index,item in items do
				local equippedNow=item.CustomGoalMusic and tostring(equipped.CustomGoalMusicId or "")~="" or equipped[item.Slot]==item.Id
				local lockedEquipped=equippedNow and item.Slot=="ActiveKit"
				local card=Panel.new({Name=item.Id,Size=UDim2.new(1,0,1,0)});card.LayoutOrder=index;card.ZIndex=75;card.Parent=list
				if equippedNow then local stroke=Instance.new("UIStroke");stroke.Color=Theme.Colors.Electric;stroke.Thickness=2;stroke.Transparency=.05;stroke.Parent=card end
				if item.Icon then local icon=Instance.new("ImageLabel");icon.BackgroundTransparency=.12;icon.BackgroundColor3=Theme.Colors.Black;icon.BorderSizePixel=0;icon.Image=item.Icon;icon.ScaleType=Enum.ScaleType.Fit;icon.Position=UDim2.new(1,-72,0,12);icon.Size=UDim2.fromOffset(56,56);icon.ZIndex=76;icon.Parent=card;corner(icon,7)end
				text(card,equippedNow and"EQUIPPED"or"OWNED",UDim2.fromOffset(14,10),UDim2.new(1,-92,0,16),7,equippedNow and Theme.Colors.Electric or Theme.Colors.Muted,Theme.Fonts.Strong).ZIndex=76
				text(card,item.Name,UDim2.fromOffset(14,28),UDim2.new(1,-92,0,24),11,Theme.Colors.White,Theme.Fonts.Display).ZIndex=76
				text(card,item.Subtitle,UDim2.fromOffset(14,54),UDim2.new(1,-92,0,16),7,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=76
				local preview=Button.new({Text="PREVIEW",Variant="Secondary",Size=UDim2.fromOffset(82,26),OnActivated=function()
					selectedItem=item
					renderHub()
					if item.Slot=="GoalEffect"then
						task.defer(function()
							if previewPanel.Parent then previewGoalEffect(previewPanel,item.Id,item.Name)end
						end)
					end
				end});preview.Position=UDim2.fromOffset(14,74);preview.ZIndex=77;preview.Parent=card
				local action=Button.new({Text=item.PremiumClubEditor and"OPEN"or(item.CustomGoalMusic and"CONFIG"or(lockedEquipped and"EQUIPPED"or(equippedNow and"UNEQUIP"or"EQUIP"))),Variant=equippedNow and"Secondary"or"Primary",Size=UDim2.fromOffset(82,26),OnActivated=function()selectedItem=item;if item.PremiumClubEditor then renderHub()elseif item.CustomGoalMusic then renderHub()elseif lockedEquipped then toast("A match kit must stay equipped.")elseif equippedNow then unequipSlot(item.Slot)else equipItem(item)end end});action.Position=UDim2.new(1,-96,1,-30);action.ZIndex=77;action.Parent=card
			end
			local shown=selectedItem or items[1]
			text(previewPanel,"PREVIEW",UDim2.fromOffset(18,16),UDim2.new(1,-36,0,20),8,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=75
			if shown then
				if shown.KitIdentity then
					local kitHeight=previewCompact and 128 or 148
					local kitFrame=Panel.new({Name="KitVisualPreview",Position=UDim2.fromOffset(18,46),Size=UDim2.new(1,-36,0,kitHeight),ClipsDescendants=true})
					kitFrame.ZIndex=75
					kitFrame.Parent=previewPanel
					local kit=KitPreview.new(kitFrame,shown.KitIdentity,UDim2.new(1,-20,1,-16))
					kit.Position=UDim2.fromOffset(10,8)
					kit.ZIndex=76
					for _,descendant in kit:GetDescendants()do if descendant:IsA("GuiObject")then descendant.ZIndex=math.max(descendant.ZIndex,76)end end
				elseif shown.BootStyle then
					local bootHeight=previewCompact and 112 or 142
					createBootViewport(previewPanel,shown.BootStyle,UDim2.fromOffset(18,46),UDim2.new(1,-36,0,bootHeight),75)
				elseif shown.Slot=="Celebration" then
					local celebrationHeight=previewCompact and 128 or 154
					createCelebrationViewport(previewPanel,shown.Id,UDim2.fromOffset(18,46),UDim2.new(1,-36,0,celebrationHeight),75)
				elseif shown.Icon then local iconSize=previewCompact and 104 or 132;local icon=Instance.new("ImageLabel");icon.BackgroundColor3=Theme.Colors.Black;icon.BackgroundTransparency=.08;icon.BorderSizePixel=0;icon.Image=shown.Icon;icon.ScaleType=Enum.ScaleType.Fit;icon.Position=UDim2.new(.5,-iconSize/2,0,52);icon.Size=UDim2.fromOffset(iconSize,iconSize);icon.ZIndex=75;icon.Parent=previewPanel;corner(icon,10) end
				local textTop=previewCompact and 184 or 210
				if shown.PremiumClubEditor then
					textTop=52
					local club=progression.ClubMembership or {}
					local badgeHolder=Panel.new({Name="PremiumClubBadgePreview",Position=UDim2.fromOffset(18,textTop),Size=UDim2.new(1,-36,0,138),ClipsDescendants=true})
					badgeHolder.ZIndex=75
					badgeHolder.Parent=previewPanel
					local badge=BadgePreview.new(badgeHolder,club,UDim2.fromOffset(96,96))
					badge.AnchorPoint=Vector2.new(.5,.5)
					badge.Position=UDim2.fromScale(.5,.48)
					badge.ZIndex=76
					text(previewPanel,"PREMIUM CLUB",UDim2.fromOffset(18,textTop+154),UDim2.new(1,-36,0,28),15,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75
					text(previewPanel,"Open the badge studio to change shapes, marks, borders, colors, and premium badge styles.",UDim2.fromOffset(18,textTop+188),UDim2.new(1,-36,0,64),8,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=75
					local open=Button.new({Text="OPEN BADGE STUDIO",Variant="Primary",Size=UDim2.new(1,-36,0,42),OnActivated=function()
						ClubIdentityEditor.open(overlay,progression.ClubMembership or {},{SaveLabel="SAVE PREMIUM CLUB",OnSave=function(state:any)
							local response=LaunchService:Request("SaveClubIdentity",state)
							if not response.Success then toast(response.Message or"Club badge could not be saved.","Error");return false end
							for key,value in state do progression.ClubMembership[key]=value end
							context.Data.Progression.ClubMembership=progression.ClubMembership
							if context.Data.PlayerProfile then context.Data.PlayerProfile.ClubIdentity=progression.ClubMembership end
							toast("Premium club badge saved.","Reward")
							renderHub()
							return true
						end})
					end});open.Position=UDim2.new(0,18,1,-58);open.ZIndex=76;open.Parent=previewPanel
				elseif shown.CustomGoalMusic then
					textTop=52
					text(previewPanel,shown.Name,UDim2.fromOffset(18,textTop),UDim2.new(1,-36,0,28),15,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75
					text(previewPanel,"PLAYS FOR 8 SECONDS AFTER YOUR GOAL",UDim2.fromOffset(18,textTop+30),UDim2.new(1,-36,0,18),7,Theme.Colors.Electric,Theme.Fonts.Strong).ZIndex=75
					local idBox=Instance.new("TextBox");idBox.Name="GoalMusicIdInput";idBox.BackgroundColor3=Theme.Colors.Black;idBox.BackgroundTransparency=.1;idBox.BorderSizePixel=0;idBox.ClearTextOnFocus=false;idBox.PlaceholderText="Sound ID";idBox.Text=tostring(equipped.CustomGoalMusicId or ""):gsub("rbxassetid://","");idBox.TextColor3=Theme.Colors.White;idBox.PlaceholderColor3=Theme.Colors.Muted;idBox.TextSize=12;idBox.Font=Theme.Fonts.Strong;idBox.Position=UDim2.fromOffset(18,textTop+66);idBox.Size=UDim2.new(1,-36,0,34);idBox.ZIndex=76;idBox.Parent=previewPanel;corner(idBox,7)
					local startBox=Instance.new("TextBox");startBox.Name="GoalMusicStartInput";startBox.BackgroundColor3=Theme.Colors.Black;startBox.BackgroundTransparency=.1;startBox.BorderSizePixel=0;startBox.ClearTextOnFocus=false;startBox.PlaceholderText="Start second";startBox.Text=tostring(tonumber(equipped.CustomGoalMusicStart)or 0);startBox.TextColor3=Theme.Colors.White;startBox.PlaceholderColor3=Theme.Colors.Muted;startBox.TextSize=12;startBox.Font=Theme.Fonts.Strong;startBox.Position=UDim2.fromOffset(18,textTop+108);startBox.Size=UDim2.new(1,-36,0,34);startBox.ZIndex=76;startBox.Parent=previewPanel;corner(startBox,7)
					local status=text(previewPanel,"Paste a Roblox audio id, then find it.",UDim2.fromOffset(18,textTop+150),UDim2.new(1,-36,0,44),8,Theme.Colors.Silver,Theme.Fonts.Strong);status.TextWrapped=true;status.ZIndex=76
					local found=false
					local function currentSoundId():string return normalizeSoundAssetId(idBox.Text)end
					local find=Button.new({Text="FIND SOUND",Variant="Secondary",Size=UDim2.new(1,-36,0,34),OnActivated=function()
						local normalized=currentSoundId()
						if normalized==""then found=false;status.Text="Enter a valid numeric Roblox sound id.";status.TextColor3=Color3.fromHex("FF5F70");return end
						status.Text="Checking sound..."
						local assetNumber=tonumber(normalized:match("(%d+)"))
						local ok,info=pcall(function()return MarketplaceService:GetProductInfo(assetNumber or 0,Enum.InfoType.Asset)end)
						if ok and type(info)=="table"then
							found=true
							status.Text="Found: "..tostring(info.Name or"Roblox audio")
							status.TextColor3=Theme.Colors.Electric
						else
							found=false
							status.Text="Could not find that sound. Check the id or permissions."
							status.TextColor3=Color3.fromHex("FF5F70")
						end
					end});find.Position=UDim2.new(0,18,1,-150);find.ZIndex=76;find.Parent=previewPanel
					local play=Button.new({Text="PLAY TEST",Variant="Secondary",Size=UDim2.new(1,-36,0,34),OnActivated=function()
						local normalized=currentSoundId()
						if normalized==""then status.Text="Enter a valid sound id first.";status.TextColor3=Color3.fromHex("FF5F70");return end
						playGoalMusicPreview(normalized,tonumber(startBox.Text)or 0)
					end});play.Position=UDim2.new(0,18,1,-108);play.ZIndex=76;play.Parent=previewPanel
					local save=Button.new({Text="SAVE GOAL MUSIC",Variant="Primary",Size=UDim2.new(1,-36,0,42),OnActivated=function()
						local normalized=currentSoundId()
						if normalized==""then status.Text="Enter a valid sound id.";status.TextColor3=Color3.fromHex("FF5F70");return end
						local start=math.clamp(tonumber(startBox.Text)or 0,0,600)
						equipped.CustomGoalMusicId=normalized
						equipped.CustomGoalMusicStart=start
						context.Data.UIState.EquippedCosmetics=equipped
						if context.StateService.SetCustomGoalMusic then context.StateService:SetCustomGoalMusic(normalized,start)end
						status.Text="Saved. This will play when you score."
						status.TextColor3=Theme.Colors.Electric
						toast("Custom goal music saved.","Reward")
					end});save.Position=UDim2.new(0,18,1,-58);save.ZIndex=76;save.Parent=previewPanel
				else
					text(previewPanel,shown.Name,UDim2.fromOffset(18,textTop),UDim2.new(1,-36,0,previewCompact and 38 or 44),previewCompact and 14 or 15,Theme.Colors.White,Theme.Fonts.Display).ZIndex=75
					text(previewPanel,shown.Detail or shown.Subtitle,UDim2.fromOffset(18,textTop+(previewCompact and 44 or 50)),UDim2.new(1,-36,0,previewCompact and 44 or 64),previewCompact and 8 or 8,Theme.Colors.Silver,Theme.Fonts.Strong).ZIndex=75
					local current=equipped[shown.Slot]==shown.Id
					local lockedCurrent=current and shown.Slot=="ActiveKit"
					if shown.Slot=="GoalEffect"then
						local test=Button.new({Text="PREVIEW EFFECT",Variant="Secondary",Size=UDim2.new(1,-36,0,34),OnActivated=function()previewGoalEffect(previewPanel,shown.Id,shown.Name)end})
						test.Position=UDim2.new(0,18,1,-150);test.ZIndex=76;test.Parent=previewPanel
					end
					local action=Button.new({Text=lockedCurrent and"EQUIPPED"or(current and"UNEQUIP"or"EQUIP NOW"),Variant=current and"Secondary"or"Primary",Size=UDim2.new(1,-36,0,42),OnActivated=function()if lockedCurrent then toast("A match kit must stay equipped.")elseif current then unequipSlot(shown.Slot)else equipItem(shown)end end});action.Position=UDim2.new(0,18,1,-108);action.ZIndex=76;action.Parent=previewPanel
					if shown.Slot~="ActiveKit" then local clear=Button.new({Text="CLEAR SLOT",Variant="Secondary",Size=UDim2.new(1,-36,0,36),OnActivated=function()unequipSlot(shown.Slot)end});clear.Position=UDim2.new(0,18,1,-58);clear.ZIndex=76;clear.Parent=previewPanel end
				end
			else
				local empty=text(previewPanel,"SELECT AN ITEM",UDim2.fromOffset(0,230),UDim2.new(1,0,0,34),15,Theme.Colors.Muted,Theme.Fonts.Display);empty.TextXAlignment=Enum.TextXAlignment.Center;empty.ZIndex=75
			end
		end
		local resizeQueued=false
		hub:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if resizeQueued then return end
			resizeQueued=true
			task.defer(function()
				resizeQueued=false
				if hub.Parent then renderHub()end
			end)
		end)
		renderHub()
	end

	for _,name in TABS do local tab=Button.new({Text=string.upper(name),Variant=name==activeTab and "Primary" or "Secondary",Size=UDim2.fromOffset(126,32),OnActivated=function() activeTab=name;saveTrayState();renderTray();if name=="Customize"then openCustomizeHub()end end});tab.Parent=tabBar;tabButtons[name]=tab end
	local shortcuts=Instance.new("Frame");shortcuts.BackgroundTransparency=1;shortcuts.Position=UDim2.new(1,-736,0,18);shortcuts.Size=UDim2.fromOffset(736,34);shortcuts.Parent=scroll;local shortcutLayout=Instance.new("UIListLayout");shortcutLayout.FillDirection=Enum.FillDirection.Horizontal;shortcutLayout.Padding=UDim.new(0,6);shortcutLayout.Parent=shortcuts
	local squadShortcut=Button.new({Text="SQUAD BUILDER",Variant="Primary",Size=UDim2.fromOffset(116,34),OnActivated=function()toast("Squad Builder is active.")end});squadShortcut.Parent=shortcuts
	if packsUnlocked then local packsButton=Button.new({Text="PACKS",Variant="Secondary",Size=UDim2.fromOffset(116,34),OnActivated=openPackHub});packsButton.Parent=shortcuts end
	local navigatingToPlayers=false
	local playersButton=Button.new({Text="PLAYER INVENTORY",Variant="Secondary",Size=UDim2.fromOffset(132,34),OnActivated=function()
		if navigatingToPlayers or(context.Flow and context.Flow.Busy)then return end
		navigatingToPlayers=true;clearShortcutOverlays()
		context.Data.UIState.SelectedTabs.Inventory="Players";context.StateService:SetTab("Inventory","Players")
		if context.IsCurrentPage and context.IsCurrentPage("Inventory")then navigatingToPlayers=false;return end
		context.Navigate("Inventory");task.delay(.65,function()navigatingToPlayers=false end)
	end});playersButton.Parent=shortcuts
	local objectivesButton=Button.new({Text="OBJECTIVES",Variant="Secondary",Size=UDim2.fromOffset(116,34),OnActivated=openObjectivesHub});objectivesButton.Parent=shortcuts
	local tacticsButton=Button.new({Text="TACTICS",Variant="Secondary",Size=UDim2.fromOffset(104,34),OnActivated=openTacticsHub});tacticsButton.Parent=shortcuts
	local customizeButton=Button.new({Text="CUSTOMIZE",Variant="Secondary",Size=UDim2.fromOffset(116,34),OnActivated=function()activeTab="Customize";saveTrayState();renderTray();openCustomizeHub()end});customizeButton.Parent=shortcuts
	renderAll()
	return group
end

local function vtrFindRouletteGuiObjects(root)
	local scroller
	local container

	if typeof(root) ~= "Instance" then
		return nil, nil
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ScrollingFrame") then
			local n = string.lower(obj.Name)
			if string.find(n, "roulette") or string.find(n, "spin") or string.find(n, "reward") or string.find(n, "pack") then
				scroller = obj
				break
			end
			scroller = scroller or obj
		end
	end

	if scroller then
		for _, obj in ipairs(scroller:GetDescendants()) do
			if obj:IsA("GuiObject") then
				local hasPack = obj:GetAttribute("PackId") or obj:GetAttribute("PackName")
				local n = string.lower(obj.Name)
				if hasPack or string.find(n, "pack") or string.find(n, "card") or string.find(n, "item") then
					container = obj.Parent
					break
				end
			end
		end
	end

	return scroller, container
end

local function vtrForceRouletteWinningCenter(root, winningPack, winningIndex)
	if not winningPack then
		return
	end

	task.defer(function()
		local scroller, container = vtrFindRouletteGuiObjects(root)
		if scroller and container then
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
			task.wait(0.05)
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
		end
	end)
end

return UltimateTeamPage
