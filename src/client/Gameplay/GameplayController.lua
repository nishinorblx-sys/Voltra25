--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local LiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local DeviceGameplayConfig=require(ReplicatedStorage.VTR.Shared.DeviceGameplayConfig)
local PlayabilitySettingsConfig=require(ReplicatedStorage.VTR.Shared.PlayabilitySettingsConfig)
local Remotes=require(ReplicatedStorage.VTR.Shared.Remotes)
local InputController=require(script.Parent.InputController)
local BroadcastCameraController=require(script.Parent.BroadcastCameraController)
local TeamControlController=require(script.Parent.TeamControlController)
local AnimationController=require(script.Parent.AnimationController)
local BallVisualController=require(script.Parent.BallVisualController)
local BallRollVisualController=require(script.Parent.BallRollVisualController)
local MatchHUDController=require(script.Parent.MatchHUDController)
local PlayerIndicatorController=require(script.Parent.PlayerIndicatorController)
local TrainerController=require(script.Parent.TrainerController)
local MatchCutsceneController=require(script.Parent.MatchCutsceneController)
local MinimapController=require(script.Parent.MinimapController)
local MatchInputLockController=require(script.Parent.MatchInputLockController)
local MouseAimController=require(script.Parent.MouseAimController)
local AimLineController=require(script.Parent.AimLineController)
local GoalReticleController=require(script.Parent.GoalReticleController)
local MatchLifecycleController=require(script.Parent.MatchLifecycleController)
local CornerCameraController=require(script.Parent.CornerCameraController)
local CornerAimController=require(script.Parent.CornerAimController)
local BallFlightMarkerController=require(script.Parent.BallFlightMarkerController)
local ReplayController=require(script.Parent.ReplayController)
local CrowdAmbienceController=require(script.Parent.CrowdAmbienceController)
local MatchSoundController=require(script.Parent.MatchSoundController)
local CelebrationPoseController=require(script.Parent.CelebrationPoseController)
local VoltraControlledPlayerIndicator=require(script.Parent.Parent.Components.VoltraControlledPlayerIndicator)
local VoltraPackRoulette=require(script.Parent.Parent.Components.VoltraPackRoulette)
local AscensionManagerPanel=require(script.Parent.Parent.Components.AscensionManagerPanel)
local UIStateService=require(script.Parent.Parent.Services.UIStateService)
local UISoundService=require(script.Parent.Parent.Services.UISoundService)
local MatchVisualCleanupService=require(script.Parent.Parent.Services.MatchVisualCleanupService)
local MatchPresentationService=require(script.Parent.Parent.Services.MatchPresentationService)
local ControlGlyphService=require(script.Parent.Parent.Services.ControlGlyphService)
local PenaltyConfig=require(ReplicatedStorage.VTR.Shared.PenaltyConfig)
local GoalModelResolver=require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local Controller={};Controller.__index=Controller
local PAUSE_ACTION="VTRMatchControllerBackPause"
local ACTION_CANCEL_STATES={Goal="goal",Foul="foul",Offside="offside",HalfTime="halftime",MatchEnded="full_time",SetPiece="set_piece",PresentationStart="cutscene",TutorialRestart="tutorial_restart",TutorialStage="tutorial_stage"}
local function kickoffDebugEnabled():boolean return workspace:GetAttribute("VTRKickoffDebug")==true and(RunService:IsStudio()or game.PrivateServerId~="")end
local function matchStartKey(payload:any):string
	if type(payload)~="table"then return "" end
	local id=payload.MatchSessionId or payload.WorldName or ""
	local side=payload.ControlledSide or ""
	return tostring(id).."|"..tostring(side)
end
local function goalPointFromStick(pitchCFrame:CFrame,width:number,length:number,goalSign:number,vector:Vector2?,fallback:Vector3?):Vector3
	local rectangle=GoalModelResolver.ResolveByAttackSign(goalSign,pitchCFrame,width,length)
	local goalWidth=math.max(1,rectangle.RightBound-rectangle.Left)
	local goalHeight=math.max(1,rectangle.Top-rectangle.Bottom)
	local xAlpha=.5
	local yAlpha=.28
	if fallback then
		local offset=fallback-rectangle.PlanePoint
		xAlpha=math.clamp((offset:Dot(rectangle.Right)-rectangle.Left)/goalWidth,.04,.96)
		yAlpha=math.clamp((offset:Dot(rectangle.Up)-rectangle.Bottom)/goalHeight,.08,.94)
	end
	if vector and vector.Magnitude>.08 then
		local screenX=math.clamp(vector.X,-1,1)*(goalSign<0 and 1 or-1)
		xAlpha=math.clamp(.5+screenX*.46,.04,.96)
		yAlpha=math.clamp(.52+math.clamp(vector.Y,-1,1)*.42,.08,.94)
	end
	return GoalModelResolver.Point(rectangle,rectangle.Left+goalWidth*xAlpha,rectangle.Bottom+goalHeight*yAlpha)
end
local function penaltySlotFromVector(vector:Vector2?,fallback:string?,goalSign:number,defending:boolean?):string
	local current=PenaltyConfig.NormalizeSlot(fallback)or"MIDDLE"
	if not vector or vector.Magnitude<=.08 then return current end
	local x=math.clamp(vector.X,-1,1)*(defending and 1 or(goalSign<0 and 1 or-1))
	if math.abs(x)<.34 then return"MIDDLE"end
	return(x<0 and"LEFT"or"RIGHT").."_"..(vector.Y>=0 and"UP"or"DOWN")
end
local function celebrationGoalMinute(seconds:any,inAddedTime:any,addedElapsed:any):string
	local value=math.max(0,tonumber(seconds)or 0)
	if inAddedTime==true then
		local base=value>=5400 and 90 or 45
		local added=math.max(1,math.ceil((tonumber(addedElapsed)or 0)/60))
		return string.format("%d+%d'",base,added)
	end
	return tostring(math.max(1,math.floor(value/60)+1)).."'"
end
local KEEPER_TUNING={{Key="Reaction",Label="Reaction Speed",Min=.05,Max=1.75,Default=1},{Key="DiveSpeed",Label="Dive Speed",Min=.05,Max=1.65,Default=1},{Key="Reach",Label="Reach",Min=.05,Max=1.65,Default=1},{Key="Handling",Label="Handling",Min=.05,Max=1.65,Default=1},{Key="SaveBias",Label="Save Bias",Min=.05,Max=1.65,Default=1}}
local SHOOTING_TUNING={{Key="Speed",Label="Shot Speed",Min=.55,Max=1.55,Default=1},{Key="Accuracy",Label="Accuracy",Min=.55,Max=1.55,Default=1},{Key="Lift",Label="Lift",Min=.55,Max=1.55,Default=1.2},{Key="Curve",Label="Curve",Min=.55,Max=1.55,Default=1},{Key="FinesseCurve",Label="Finesse Curve",Min=0,Max=100,Default=0,Format="Percent"},{Key="Power",Label="Power Scale",Min=.55,Max=1.55,Default=1}}
local function formatSliderValue(value:number,spec:any?):string return spec and spec.Format=="Percent"and tostring(math.floor(value+.5))or string.format("%.2fx",value)end
local PRACTICE_KEEPER_BASELINE={Reaction=1.75,DiveSpeed=1.15,Reach=1.65,Handling=1.65,SaveBias=1}
local function formatPracticeDefaults(tuning:any):string
	local keeper=tuning and tuning.Keeper or{}
	local shooting=tuning and tuning.Shooting or{}
	local function n(value:any):string return string.format("%.3g",tonumber(value)or 0)end
	local keeperParts={};for _,spec in KEEPER_TUNING do table.insert(keeperParts,spec.Key.."="..n(keeper[spec.Key]or spec.Default))end
	local scaledParts={};for _,spec in KEEPER_TUNING do local base=PRACTICE_KEEPER_BASELINE[spec.Key]or 1;table.insert(scaledParts,spec.Key.."="..n(math.clamp((tonumber(keeper[spec.Key])or spec.Default)*base,.05,2.2)))end
	local shootingParts={};for _,spec in SHOOTING_TUNING do table.insert(shootingParts,spec.Key.."="..n(shooting[spec.Key]or spec.Default))end
	return "Practice defaults: Keeper={"..table.concat(keeperParts,",").."} Shooting={"..table.concat(shootingParts,",").."} ScaledKeeper={"..table.concat(scaledParts,",").."}"
end
local function setMenuVisible(visible:boolean)
	local gui=Players.LocalPlayer.PlayerGui:FindFirstChild("VTR25")
	if gui and gui:IsA("ScreenGui") then gui.Enabled=true end
	local root=gui and gui:FindFirstChild("Root")
	if not root or not root:IsA("Frame")then return end
	root.Visible=true
	root.BackgroundTransparency=visible and 0 or 1
	local energy=root:FindFirstChild("BackgroundEnergy")
	if energy and energy:IsA("GuiObject")then energy.Visible=visible end
	for _,name in{"Sidebar","Topbar","Content"}do
		local item=root:FindFirstChild(name)
		if item and item:IsA("GuiObject")then item.Visible=visible end
	end
end
local TACTIC_DEBUG_GROUPS:{[string]:string}={
	AttackingWidth="Width",DefensiveWidth="Width",WidthDiscipline="Width",
	DefensiveDepth="Depth",BackLineCompactness="Depth",DefensiveLineStepUp="Depth",
	PressingIntensity="Press",PressTriggerDistance="Press",CounterPress="Press",TackleAggression="Press",
	PassingDirectness="Passing",PassTempo="Passing",ForwardPassPriority="Passing",BackPassSafety="Passing",SwitchPlayFrequency="Passing",ThroughBallFrequency="Passing",PassRisk="Passing",OneTouchPassing="Passing",
	RunsInBehind="Runs",OverlapFrequency="Runs",UnderlapFrequency="Runs",FullbackAttack="Runs",BoxRuns="Runs",CounterAttackFrequency="Runs",
	SupportDistance="Shape",BuildUpSpeed="Shape",RecoveryRuns="Shape",ZoneDiscipline="Shape",LaneBlocking="Shape",MarkingTightness="Shape",
	KeeperAggression="Keeper",KeeperDistributionRisk="Keeper",ShortGKDistribution="Keeper",LongGKDistribution="Keeper",
}
local TACTIC_FORMATIONS={"4-3-3","4-2-3-1","4-4-2","4-1-2-1-2","4-5-1","3-4-3","4-3-2-1","3-5-2","5-3-2"}
local TACTIC_LAB_SLIDERS={}
local TACTIC_IDENTITIES={{Id="basic_possession",Label="Slow Build Up",PresetId="balanced_control",Name="SAFE Possession"},{Id="quick_passing",Label="Tiki-Taka",PresetId="short_possession",Name="Quick Passing"}}
local TACTIC_BEHAVIOR_CONTROLS={
	{Key="DefensiveLineReach",Label="DEFENSIVE LINE REACH",Group="Depth",Low="Halfway cap",High="Higher step limit"},
	{Key="FirstTimePassing",Label="FIRST TIME PASSING",Group="Passing",Low="Control first",High="One-touch"},
	{Key="LongBalls",Label="LONG BALLS",Group="Passing",Low="Short first",High="Furthest open"},
	{Key="Aggression",Label="AGGRESSION",Group="Press",Low="Delay tackles",High="Attempt tackles"},
	{Key="Character",Label="CHARACTER",Group="Press",Low="Stay upright",High="More slides"},
	{Key="ShotRate",Label="SHOT RATE",Group="Shape",Low="Work chance",High="Shoot earlier"},
}
local function setSimpleTacticControl(tactics:any,key:string,value:number)
	tactics.Sliders=tactics.Sliders or{}
	tactics.MetricsTargets=tactics.MetricsTargets or{}
	value=math.clamp(value,0,100)
	if key=="DefensiveLineReach"then
		tactics.Sliders.DefensiveLineStepUp=value
		tactics.Sliders.DefensiveDepth=math.clamp(42+value*.36,0,100)
	elseif key=="FirstTimePassing"then
		tactics.Sliders.OneTouchPassing=value
		tactics.Sliders.FirstTouchDirectness=math.clamp(42+value*.58,0,100)
		tactics.Sliders.ReceiverTrapAggression=math.clamp(70-value*.6,0,100)
		tactics.MetricsTargets.FirstTimePassChance=value
	elseif key=="LongBalls"then
		tactics.Sliders.LobPassBias=value
		tactics.Sliders.FreeKickLongPass=value
		tactics.Sliders.LongGKDistribution=value
		tactics.Sliders.ThroughBallFrequency=math.clamp(34+value*.5,0,100)
		tactics.Sliders.PassingDirectness=math.clamp(28+value*.58,0,100)
	elseif key=="Aggression"then
		tactics.Sliders.TackleAggression=value
		tactics.Sliders.PressTriggerDistance=math.clamp(32+value*.52,0,100)
		tactics.Sliders.PressingIntensity=math.clamp(36+value*.48,0,100)
	elseif key=="Character"then
		tactics.Sliders.RiskLevel=math.clamp(28+value*.64,0,100)
		tactics.Sliders.TackleAggression=math.max(tonumber(tactics.Sliders.TackleAggression)or 50,math.clamp(24+value*.62,0,100))
		tactics.MetricsTargets.SlideTackleFrequency=value
	elseif key=="ShotRate"then
		tactics.Sliders.LongShotFrequency=value
		tactics.Sliders.ShotPatience=math.clamp(100-value,0,100)
		tactics.Sliders.RiskLevel=math.max(tonumber(tactics.Sliders.RiskLevel)or 50,math.clamp(30+value*.55,0,100))
	end
end
local function simpleTacticValue(tactics:any,key:string):number
	local sliders=tactics and tactics.Sliders or{}
	local metrics=tactics and tactics.MetricsTargets or{}
	if key=="DefensiveLineReach"then return tonumber(sliders.DefensiveLineStepUp)or 50 end
	if key=="FirstTimePassing"then return tonumber(metrics.FirstTimePassChance)or tonumber(sliders.OneTouchPassing)or 50 end
	if key=="LongBalls"then return tonumber(sliders.LobPassBias)or tonumber(sliders.FreeKickLongPass)or 50 end
	if key=="Aggression"then return tonumber(sliders.TackleAggression)or 50 end
	if key=="Character"then return tonumber(metrics.SlideTackleFrequency)or math.clamp(((tonumber(sliders.RiskLevel)or 50)-28)/.64,0,100) end
	if key=="ShotRate"then return tonumber(sliders.LongShotFrequency)or math.clamp(100-(tonumber(sliders.ShotPatience)or 50),0,100) end
	return 50
end
local function applyTacticIdentity(tactics:any,index:number)
	local identity=TACTIC_IDENTITIES[((index-1)%#TACTIC_IDENTITIES)+1]
	tactics.PresetId=identity.PresetId
	tactics.PlaystyleId=identity.Id
	tactics.PlaystyleName=identity.Name
	tactics.MetricsTargets=tactics.MetricsTargets or{}
	tactics.MetricsTargets.QuickPassing=identity.Id=="quick_passing"and 1 or 0
	tactics.MetricsTargets.BoxEdgeRetreatLimit=identity.Id=="basic_possession"and 132 or nil
	if identity.Id=="quick_passing"then
		tactics.Sliders.BuildUpSpeed=72;tactics.Sliders.PassTempo=92;tactics.Sliders.SupportDistance=28;tactics.Sliders.PassingDirectness=44
		setSimpleTacticControl(tactics,"FirstTimePassing",math.max(simpleTacticValue(tactics,"FirstTimePassing"),100))
	else
		tactics.Sliders.BuildUpSpeed=48;tactics.Sliders.PassTempo=66;tactics.Sliders.SupportDistance=34;tactics.Sliders.PassingDirectness=32
		setSimpleTacticControl(tactics,"FirstTimePassing",math.min(simpleTacticValue(tactics,"FirstTimePassing"),28))
	end
end
local function currentTacticIdentityIndex(tactics:any):number
	local id=tostring(tactics and (tactics.PlaystyleId or tactics.PlaystyleName or tactics.PresetId)or"")
	return(id=="quick_passing"or id=="Quick Passing"or id=="short_possession")and 2 or 1
end
local function keyCodeFromSetting(value:any,fallback:Enum.KeyCode):Enum.KeyCode
	if type(value)~="string"then return fallback end
	local numberMap={[ "0" ]=Enum.KeyCode.Zero,[ "1" ]=Enum.KeyCode.One,[ "2" ]=Enum.KeyCode.Two,[ "3" ]=Enum.KeyCode.Three,[ "4" ]=Enum.KeyCode.Four,[ "5" ]=Enum.KeyCode.Five,[ "6" ]=Enum.KeyCode.Six,[ "7" ]=Enum.KeyCode.Seven,[ "8" ]=Enum.KeyCode.Eight,[ "9" ]=Enum.KeyCode.Nine}
	if numberMap[value]then return numberMap[value]end
	local ok,key=pcall(function()return Enum.KeyCode[value]end)
	return ok and key or fallback
end
local function defaultTacticalDebugOptions():any
	return{Width=true,Depth=true,Press=true,Passing=true,Runs=true,Shape=true,Keeper=true}
end
local function planBand(value:any,low:string,mid:string,high:string):string
	local n=tonumber(value)or 50
	if n>=67 then return high elseif n<=33 then return low end
	return mid
end
local function gameplanSummary(tactics:any):string
	local identity=TACTIC_IDENTITIES[currentTacticIdentityIndex(tactics)]
	local reach=math.floor(simpleTacticValue(tactics,"DefensiveLineReach")*.32+4+.5)
	return "FORMATION: "..tostring(tactics and tactics.Formation or"4-3-3").."  /  AI IDENTITY: "..identity.Label.." ("..identity.Name..")\nDEFENSIVE LINE REACH: +"..tostring(reach).." studs past halfway  /  FIRST TIME: "..tostring(math.floor(simpleTacticValue(tactics,"FirstTimePassing")+.5)).."%  /  LONG BALLS: "..tostring(math.floor(simpleTacticValue(tactics,"LongBalls")+.5)).."%\nAGGRESSION: "..tostring(math.floor(simpleTacticValue(tactics,"Aggression")+.5)).."%  /  CHARACTER: "..tostring(math.floor(simpleTacticValue(tactics,"Character")+.5)).."% slides  /  SHOT RATE: "..tostring(math.floor(simpleTacticValue(tactics,"ShotRate")+.5)).."%"
end
local function compactActionName(value:any):string
	local text=tostring(value or"")
	if text==""then return"Observe"end
	text=text:gsub("(%l)(%u)","%1 %2"):gsub("_"," ")
	return text
end
function Controller.new()return setmetatable({Active=false,Stamina=Config.Stamina.Maximum,Endurance=Config.Stamina.Maximum,TacticalMode=false,TacticalPanelOpen=true,TacticalSide="Home",TacticalDebugOptions=defaultTacticalDebugOptions(),RuntimeTactics={Home=LiteConfig.DefaultTactics(),Away=LiteConfig.DefaultTactics()}},Controller)end
function Controller:Start()local action,state=Remotes.Wait();self.Action=action;self.State=state;if self.StateConnection then self.StateConnection:Disconnect()end;self.StateConnection=state.OnClientEvent:Connect(function(payload)self:_state(payload)end)end
function Controller:_trackConnection(connection:RBXScriptConnection,category:string?):RBXScriptConnection
	if self.Lifecycle then return self.Lifecycle:TrackConnection(connection,category)end
	return connection
end
function Controller:_trackTemporary(instance:Instance):Instance
	if self.Lifecycle then return self.Lifecycle:TrackTemporary(instance)end
	return instance
end
function Controller:_spawnMatchTask(callback:any):thread
	if self.Lifecycle then return self.Lifecycle:Spawn(callback)::thread end
	return task.defer(function()callback(function()return not self.Active end)end)
end
function Controller:_delayMatchTask(seconds:number,callback:()->()):thread
	if self.Lifecycle then return self.Lifecycle:Delay(seconds,callback)::thread end
	return task.delay(math.max(0,seconds),callback)
end
function Controller:_hideGoalCelebrationOverlay()
	if self.GoalCelebrationOverlay then
		self.GoalCelebrationOverlay:Destroy()
		self.GoalCelebrationOverlay=nil
	end
end
function Controller:_showGoalCelebrationOverlay(payload:any)
	self:_hideGoalCelebrationOverlay()
	local playerGui=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local scorerModel=payload and payload.ScorerModel
	local scorer=tostring(payload and payload.Scorer or (scorerModel and scorerModel:GetAttribute("DisplayName")) or "SCORER")
	local team=tostring(payload and (payload.TeamName or payload.ClubName or payload.Team) or (scorerModel and (scorerModel:GetAttribute("Club") or scorerModel:GetAttribute("VTRTeam"))) or "TEAM")
	local minute=celebrationGoalMinute(payload and payload.GameSeconds,payload and payload.InAddedTime,payload and payload.AddedElapsed)
	local gui=Instance.new("ScreenGui")
	gui.Name="VTRGoalCelebrationOverlay"
	gui.IgnoreGuiInset=true
	gui.ResetOnSpawn=false
	gui.DisplayOrder=138
	gui.Parent=playerGui
	self:_trackTemporary(gui)
	DeviceScaleService.Apply(gui)
	self.GoalCelebrationOverlay=gui
	local card=Instance.new("Frame")
	card.Name="GoalCard"
	card.AnchorPoint=Vector2.new(.5,1)
	card.Position=UDim2.new(.5,0,1,150)
	card.Size=UDim2.new(0,560,0,118)
	card.BackgroundColor3=Color3.fromRGB(5,7,6)
	card.BackgroundTransparency=.18
	card.BorderSizePixel=0
	card.Parent=gui
	Instance.new("UICorner",card).CornerRadius=UDim.new(0,14)
	local stroke=Instance.new("UIStroke")
	stroke.Color=Color3.fromRGB(183,255,26)
	stroke.Transparency=.08
	stroke.Thickness=2
	stroke.Parent=card
	local glow=Instance.new("Frame")
	glow.Name="Glow"
	glow.Position=UDim2.fromOffset(0,0)
	glow.Size=UDim2.new(0,8,1,0)
	glow.BackgroundColor3=Color3.fromRGB(183,255,26)
	glow.BorderSizePixel=0
	glow.Parent=card
	Instance.new("UICorner",glow).CornerRadius=UDim.new(0,14)
	local goal=Instance.new("TextLabel")
	goal.BackgroundTransparency=1
	goal.Position=UDim2.fromOffset(26,13)
	goal.Size=UDim2.new(0,178,0,50)
	goal.Font=Enum.Font.GothamBlack
	goal.Text="GOAL"
	goal.TextColor3=Color3.fromRGB(183,255,26)
	goal.TextSize=42
	goal.TextXAlignment=Enum.TextXAlignment.Left
	goal.ZIndex=4
	goal.Parent=card
	local scorerLabel=Instance.new("TextLabel")
	scorerLabel.BackgroundTransparency=1
	scorerLabel.Position=UDim2.fromOffset(214,20)
	scorerLabel.Size=UDim2.new(1,-238,0,38)
	scorerLabel.Font=Enum.Font.GothamBlack
	scorerLabel.Text=string.upper(scorer)
	scorerLabel.TextColor3=Color3.new(1,1,1)
	scorerLabel.TextScaled=true
	scorerLabel.TextXAlignment=Enum.TextXAlignment.Left
	scorerLabel.ZIndex=4
	scorerLabel.Parent=card
	local scorerLimit=Instance.new("UITextSizeConstraint")
	scorerLimit.MaxTextSize=28
	scorerLimit.MinTextSize=12
	scorerLimit.Parent=scorerLabel
	local meta=Instance.new("TextLabel")
	meta.BackgroundTransparency=1
	meta.Position=UDim2.fromOffset(216,61)
	meta.Size=UDim2.new(1,-240,0,28)
	meta.Font=Enum.Font.GothamBold
	meta.Text=string.upper(minute.."  /  "..team)
	meta.TextColor3=Color3.fromRGB(220,226,216)
	meta.TextSize=15
	meta.TextXAlignment=Enum.TextXAlignment.Left
	meta.ZIndex=4
	meta.Parent=card
	local bottom=Instance.new("Frame")
	bottom.AnchorPoint=Vector2.new(0,1)
	bottom.Position=UDim2.new(0,26,1,-16)
	bottom.Size=UDim2.new(1,-52,0,4)
	bottom.BackgroundColor3=Color3.fromRGB(183,255,26)
	bottom.BackgroundTransparency=.18
	bottom.BorderSizePixel=0
	bottom.Parent=card
	Instance.new("UICorner",bottom).CornerRadius=UDim.new(1,0)
	TweenService:Create(card,TweenInfo.new(.34,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(.5,0,1,-32)}):Play()
	self:_spawnMatchTask(function(isCancelled)
		while gui.Parent and not isCancelled() do
			TweenService:Create(glow,TweenInfo.new(.42,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=.45}):Play()
			task.wait(.42)
			if not gui.Parent or isCancelled() then break end
			TweenService:Create(glow,TweenInfo.new(.42,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0}):Play()
			task.wait(.42)
		end
	end)
end
local GOAL_EFFECT_ATTACHMENTS={
	goal_fx_golden_explosion="GoldenExplosion",
	goal_fx_smoke="SmokeExplosion",
	goal_fx_fire="FireAttachment",
	goal_fx_lightning="LightningExplosion",
}
local function findReplicatedAsset(name:string):Instance?
	local roots={ReplicatedStorage:FindFirstChild("Assets"),ReplicatedStorage:FindFirstChild("VTR") and ReplicatedStorage.VTR:FindFirstChild("Assets"),ReplicatedStorage}
	for _,root in roots do
		if root then
			local direct=root:FindFirstChild(name)
			if direct then return direct end
			local nested=root:FindFirstChild(name,true)
			if nested then return nested end
		end
	end
	return nil
end
local function emitAttachmentParticles(attachment:Attachment)
	for _,descendant in attachment:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local amount=tonumber(descendant:GetAttribute("EmitCount")) or tonumber(descendant:GetAttribute("BurstCount")) or math.max(12,math.floor((tonumber(descendant.Rate)or 20)*.8))
			descendant.Enabled=false
			descendant:Emit(math.clamp(amount,1,250))
		elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
			descendant.Enabled=true
		end
	end
end
function Controller:_shakeGoalScreen(duration:number?,strength:number?)
	local camera=workspace.CurrentCamera
	if not camera then return 0 end
	local shakeDuration=duration or .72
	local power=strength or 1
	local started=os.clock()
	local name="VTRGoalEffectScreenShake"
	local function update(_dt:number)
		local alpha=math.clamp((os.clock()-started)/shakeDuration,0,1)
		if alpha>=1 then if self.Lifecycle then self.Lifecycle:UnbindRenderStep(name)else RunService:UnbindFromRenderStep(name)end;return end
		local fade=(1-alpha)^2
		local t=os.clock()*58
		local x=(math.noise(t,0,0)-.5)*1.6*power*fade
		local y=(math.noise(0,t,0)-.5)*1.25*power*fade
		local roll=(math.noise(0,0,t)-.5)*math.rad(1.7)*power*fade
		camera.CFrame=camera.CFrame*CFrame.new(x,y,0)*CFrame.Angles(0,0,roll)
	end
	if self.Lifecycle then self.Lifecycle:BindRenderStep(name,Enum.RenderPriority.Camera.Value+20,update)else RunService:UnbindFromRenderStep(name);RunService:BindToRenderStep(name,Enum.RenderPriority.Camera.Value+20,update)end
	return shakeDuration
end
function Controller:_spawnGoalAttachmentEffect(effectId:string,position:Vector3):number
	local assetName=GOAL_EFFECT_ATTACHMENTS[effectId]
	if not assetName then return 0 end
	local asset=findReplicatedAsset(assetName)
	if not asset then return 0 end
	local holder=Instance.new("Part")
	holder.Name="VTRGoalEffect_"..assetName
	holder.Anchored=true
	holder.CanCollide=false
	holder.CanTouch=false
	holder.CanQuery=false
	holder.Transparency=1
	holder.Size=Vector3.new(.5,.5,.5)
	holder.CFrame=CFrame.new(position)
	holder.Parent=workspace
	self:_trackTemporary(holder)
	local attachment:Attachment?
	if asset:IsA("Attachment") then
		attachment=asset:Clone()
		attachment.Parent=holder
	else
		local clone=asset:Clone()
		clone.Parent=holder
		attachment=clone:IsA("Attachment") and clone or clone:FindFirstChildWhichIsA("Attachment",true)
	end
	if attachment then emitAttachmentParticles(attachment)end
	Debris:AddItem(holder,4)
	return .9
end
function Controller:_spawnFallbackGoalBurst(position:Vector3,color:Color3):number
	local holder=Instance.new("Part")
	holder.Name="VTRGoalEffectFallback"
	holder.Anchored=true
	holder.CanCollide=false
	holder.CanTouch=false
	holder.CanQuery=false
	holder.Transparency=1
	holder.Size=Vector3.new(.5,.5,.5)
	holder.CFrame=CFrame.new(position)
	holder.Parent=workspace
	self:_trackTemporary(holder)
	local attachment=Instance.new("Attachment")
	attachment.Parent=holder
	local emitter=Instance.new("ParticleEmitter")
	emitter.Color=ColorSequence.new(color,Color3.new(1,1,1))
	emitter.LightEmission=.75
	emitter.Lifetime=NumberRange.new(.35,.8)
	emitter.Speed=NumberRange.new(18,36)
	emitter.SpreadAngle=Vector2.new(180,180)
	emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.45,1.4),NumberSequenceKeypoint.new(1,0)})
	emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate=0
	emitter.Parent=attachment
	emitter:Emit(80)
	Debris:AddItem(holder,2.5)
	return .65
end
function Controller:_playGoalEffect(payload:any,onComplete:(()->())?)
	local effectId=tostring(payload and payload.GoalEffectId or "")
	if effectId=="" then if onComplete then onComplete()end;return 0 end
	local position=(self.Ball and self.Ball.Parent and self.Ball.Position) or (payload and payload.ScorerModel and payload.ScorerModel:FindFirstChild("HumanoidRootPart") and payload.ScorerModel.HumanoidRootPart.Position) or Vector3.zero
	if self.Camera and self.Camera.PitchCFrame then
		local scoringTeam=tostring(payload and payload.Team or "Home")
		local attackSign=scoringTeam=="Home" and -1 or 1
		local rectangle=GoalModelResolver.ResolveByAttackSign(attackSign,self.Camera.PitchCFrame,self.Camera.Width or 76,self.Camera.Length or 742)
		position=GoalModelResolver.Point(rectangle,(rectangle.Left+rectangle.RightBound)*.5,(rectangle.Bottom+rectangle.Top)*.5)-rectangle.Normal*.85
	end
	local duration=0
	if effectId=="goal_fx_stadium_shake" then
		duration=self:_shakeGoalScreen(1.18,3.15)
	elseif GOAL_EFFECT_ATTACHMENTS[effectId] then
		duration=self:_spawnGoalAttachmentEffect(effectId,position)
	else
		duration=self:_spawnFallbackGoalBurst(position,Color3.fromRGB(183,255,26))
	end
	if onComplete then self:_delayMatchTask(math.max(.05,duration),onComplete)end
	return duration
end
function Controller:_bindFootballer(model:Model,name:string?,position:string?)
	if self.Input and self.Input.SetActiveModel then self.Input:SetActiveModel(model)end
	if self.Animation then self.Animation:Deactivate()end;if self.Visual then self.Visual:Destroy()end;self.AnimationCache=self.AnimationCache or{};self.Animation=self.AnimationCache[model];if not self.Animation then self.Animation=AnimationController.new(model);self.AnimationCache[model]=self.Animation end
	self.ActiveModel=model
	if not self.Ball or not self.Camera or not self.TeamControl or not self.Indicators or not self.Minimap or not self.MouseAim or not self.AimLine then
		return
	end
	self.Visual=BallVisualController.new(self.Ball,model);self.Camera:SetActive(model);self.TeamControl:SetActive(model,name,position);self.Indicators:SetActive(model);if self.Trainer and(self.WorldCupOnboardingTrainer or not UserInputService.TouchEnabled)then self.Trainer:SetActive(model)end;self.Minimap:SetActive(model);self.MouseAim:SetActive(model);self.AimLine:SetActive(model)
	if self.ControlledIndicator and self.ControlledIndicator.FlashSwitch then self.ControlledIndicator:FlashSwitch(model,name,position,self.PlayabilitySettings and self.PlayabilitySettings.ReducedMotion==true)end
	self.Stamina=tonumber(model:GetAttribute("VTRSprintEnergy"))or tonumber(model:GetAttribute("VTRSprintStamina"))or tonumber(model:GetAttribute("VTRStamina"))or Config.Stamina.Maximum;self.Endurance=self.Stamina;if self.HUD then self.HUD:SetStamina(self.Stamina/Config.Stamina.Maximum)end
	if self.PendingTutorialStage and self.WorldCupOnboardingTrainer then
		local queued=self.PendingTutorialStage
		self.PendingTutorialStage=nil
		self:_delayMatchTask(0,function()
			if self.Active then self:_state(queued)end
		end)
	end
end

function Controller:_refreshActiveStamina()
	local model=self.ActiveModel
	if not model then return end
	self.Stamina=tonumber(model:GetAttribute("VTRSprintEnergy"))or tonumber(model:GetAttribute("VTRSprintStamina"))or tonumber(model:GetAttribute("VTRStamina"))or self.Stamina or Config.Stamina.Maximum
	self.Endurance=tonumber(model:GetAttribute("VTREndurance"))or tonumber(model:GetAttribute("VTRSprintStamina"))or Config.Stamina.Maximum
end

function Controller:_showFreshAttackDirection(half: number)
	if self.FirstSession ~= true or not self.ControlledIndicator or not self.ControlledIndicator.ShowAttackDirection then return end
	half = math.max(1, math.floor(tonumber(half) or 1))
	if self.LastAttackDirectionHalf == half then return end
	local pitchCFrame = self.MatchData and self.MatchData.PitchCFrame
	if typeof(pitchCFrame) ~= "CFrame" then return end
	local side = tostring(self.ControlledSide or "Home")
	local sign = side == "Home" and (half >= 2 and 1 or -1) or (half >= 2 and -1 or 1)
	local direction = pitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, sign))
	self.LastAttackDirectionHalf = half
	self.ControlledIndicator:ShowAttackDirection(direction, 6, self.PlayabilitySettings and self.PlayabilitySettings.ReducedMotion == true)
end

function Controller:_ensureControlledSideActive()
	if self.WatchMode or not self.TeamModels then return end
	if self.ActiveModel and tostring(self.ActiveModel:GetAttribute("VTRTeam")or"")==tostring(self.ControlledSide or"")then return end
	for _,model in self.TeamModels[tostring(self.ControlledSide or"Home")]or{}do
		if model and model.Parent and model:GetAttribute("VTRFiveVFiveAIKeeper")~=true then self:_bindFootballer(model,model:GetAttribute("DisplayName"),model:GetAttribute("position"));return end
	end
end
function Controller:_reticleSwitchTarget(point:Vector3?):Model?
	if not point or not self.ActiveModel or not self.TeamModels then return nil end
	local side=tostring(self.ActiveModel:GetAttribute("VTRTeam")or"Home");local best:Model?=nil;local bestDistance=math.huge
	for _,teammate in self.TeamModels[side]or{}do if teammate~=self.ActiveModel then local teammateRoot=teammate:FindFirstChild("HumanoidRootPart")::BasePart?;if teammateRoot then local distance=Vector3.new(teammateRoot.Position.X-point.X,0,teammateRoot.Position.Z-point.Z).Magnitude;if distance<bestDistance then best=teammate;bestDistance=distance end end end end
	return best
end

function Controller:_useStickShotAim():boolean
	local last=UserInputService:GetLastInputType()
	return UserInputService.TouchEnabled or tostring(last):find("Gamepad")~=nil
end

function Controller:_stickGoalShotPayload(root:BasePart,kind:string?,charge:number?):any?
	if not self.Camera or not self.Camera.PitchCFrame then return nil end
	local vector=self.Input and self.Input:MobileAimVector(kind or"Shot")or nil
	local goalSign=self:_practiceGoalSign()
	local current=nil
	if vector and vector.Magnitude>.08 then
		current=vector
	end
	local position=goalPointFromStick(self.Camera.PitchCFrame,self.Camera.Width or 76,self.Camera.Length or 742,goalSign,current,self.GamepadShotAimPoint or self.PracticeAimPoint)
	self.GamepadShotAimPoint=position
	if self.PracticeMode then
		self.PracticeAimPoint=position
		self.PracticeShotOnTarget=true
	end
	local offset=position-root.Position
	local direction=offset.Magnitude>.01 and offset.Unit or self.Camera:Aim("Shot")
	if self.GoalTarget then self.GoalTarget:Lock(position)end
	return{Direction=direction,Position=position,GoalTarget=true,TargetModel=nil}
end

function Controller:_mobileAimPayload(kind:string?,charge:number?,root:BasePart):any?
	if not self.Input or not self.Input.MobileAimVector then return nil end
	local vector=self.Input:MobileAimVector(kind)
	if (kind=="Shot"or kind=="GamepadShot") and (self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense") and self.Camera and self.Camera.PitchCFrame then
		if not vector or vector.Magnitude<=.08 then return nil end
		local goalSign=tonumber(self.Ball:GetAttribute("VTRPenaltyGoalSign"))or self.SetPieceGoalSign or(self.ControlledSide=="Home"and-1 or 1)
		if self.SetPieceMode=="PenaltyDefense"and workspace.CurrentCamera then
			local rectangle=GoalModelResolver.ResolveByAttackSign(goalSign,self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length)
			local orientation=workspace.CurrentCamera.CFrame.RightVector:Dot(rectangle.Right)>=0 and 1 or-1
			vector=Vector2.new(vector.X*orientation,vector.Y)
		end
		self.PenaltyAimSlot=penaltySlotFromVector(vector,self.PenaltyAimSlot,goalSign,self.SetPieceMode=="PenaltyDefense")
		local position=PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,self.PenaltyAimSlot,self.Camera.Width)
		self.PenaltyAimPoint=position
		local direction=(position-root.Position).Magnitude>.01 and(position-root.Position).Unit or self.Camera:Aim("Shot")
		return{Direction=direction,Position=position,GoalTarget=true,TargetModel=nil,PenaltySlot=self.PenaltyAimSlot,PenaltyDefense=self.SetPieceMode=="PenaltyDefense",PenaltyAttempt=self.PenaltyAttempt}
	end
	if (kind=="Shot"or kind=="GamepadShot") and self.SetPieceMode=="DirectShotFreeKick" and self.Camera and self.Camera.PitchCFrame then
		if (not vector or vector.Magnitude <= 0.08) and UserInputService.MouseEnabled then
			return nil
		end
		local goalSign=self.SetPieceGoalSign or(tostring(self.ActiveModel and self.ActiveModel:GetAttribute("VTRTeam")or"Home")=="Home"and-1 or 1)
		local current=self.FreeKickAimVector or Vector2.new(0,.22)
		if vector and vector.Magnitude>0.08 then
			current=Vector2.new(math.clamp(vector.X,-1,1),math.clamp(vector.Y,-1,1))
			self.FreeKickAimVector=current
		end
		local position=goalPointFromStick(self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length,goalSign,current,nil)
		local direction=(position-root.Position).Magnitude>.01 and(position-root.Position).Unit or self.Camera:Aim("Shot")
		return{Direction=direction,Position=position,GoalTarget=true,TargetModel=nil}
	end
	if not vector or vector.Magnitude<=0.08 then return nil end
	local isShotKind=kind=="Shot"or kind=="GamepadShot"
	local camera=workspace.CurrentCamera
	if not camera then return nil end
	local look=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
	local right=Vector3.new(camera.CFrame.RightVector.X,0,camera.CFrame.RightVector.Z)
	if look.Magnitude<0.01 then look=Vector3.new(0,0,-1)end
	if right.Magnitude<0.01 then right=Vector3.new(1,0,0)end
	look=look.Unit;right=right.Unit
	local direction=right*vector.X+look*vector.Y
	if direction.Magnitude<0.01 then return nil end
	direction=direction.Unit
	local amount=math.clamp(charge or 0,0,1)
	local distance=28+amount*156
	if isShotKind then distance=92+amount*90 end
	local position=root.Position+direction*distance
	local goalTarget=false
	if isShotKind then
		local pitch=self.Camera and self.Camera.PitchCFrame
		local length=self.Camera and self.Camera.Length or 742
		if pitch then
			local half=tonumber(workspace:GetAttribute("VTRMatchHalf"))or 1
			local team=tostring(self.ActiveModel and self.ActiveModel:GetAttribute("VTRTeam")or"Home")
			local attackSign=(team=="Home"and(half>=2 and 1 or-1)or(half>=2 and-1 or 1))
			local chosen=pitch:PointToWorldSpace(Vector3.new(0,3,attackSign*length*.5))
			local toGoal=Vector3.new(chosen.X-root.Position.X,0,chosen.Z-root.Position.Z)
			local chosenDot=toGoal.Magnitude>1 and direction:Dot(toGoal.Unit)or-1
			local chosenDistance=toGoal.Magnitude
			if chosenDistance<=200 and chosenDot>-0.08 then
				position=goalPointFromStick(pitch,self.Camera.Width or 76,length,attackSign,vector,self.GamepadShotAimPoint)
				self.GamepadShotAimPoint=position
				goalTarget=true
			else
				position=root.Position+direction*(90+amount*80)
				goalTarget=false
			end
		end
	end
	return{Direction=direction,Position=position,GoalTarget=goalTarget,TargetModel=(kind=="Pass"or kind=="Switch")and self:_reticleSwitchTarget(position)or nil}
end
function Controller:_aimPayload(kind:string?,shotCharge:number?):any
	local root=self.ActiveModel and self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?
	if root then
		local mobile=self:_mobileAimPayload(kind or "",shotCharge or 0,root)
		if mobile then
			if mobile.GoalTarget and mobile.Position and self.GoalTarget then self.GoalTarget:Lock(mobile.Position)end
			return mobile
		end
	end
	if root and (kind=="Shot"or kind=="GamepadShot") and self:_useStickShotAim() then
		local stickPayload=self:_stickGoalShotPayload(root,kind,shotCharge)
		if stickPayload then return stickPayload end
	end
	if root and kind=="GamepadShot"then
		local pitch=self.Camera and self.Camera.PitchCFrame
		local length=self.Camera and self.Camera.Length or 742
		if pitch then
			local half=tonumber(workspace:GetAttribute("VTRMatchHalf"))or 1
			local team=tostring(self.ActiveModel and self.ActiveModel:GetAttribute("VTRTeam")or"Home")
			local attackSign=(team=="Home"and(half>=2 and 1 or-1)or(half>=2 and-1 or 1))
			local goalCenter=pitch:PointToWorldSpace(Vector3.new(0,3,attackSign*length*.5))
			local goalDirection=Vector3.new(goalCenter.X-root.Position.X,0,goalCenter.Z-root.Position.Z)
			local runner=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z)
			if runner.Magnitude<1 then runner=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)end
			local side=runner.Magnitude>.05 and runner.Unit:Dot(pitch.RightVector)>=0 and 1 or -1
			local high=goalDirection.Magnitude>.05 and runner.Magnitude>.05 and runner.Unit:Dot(goalDirection.Unit)>0.55
			local target=pitch:PointToWorldSpace(Vector3.new(side*11,high and 6.2 or 2.45,attackSign*length*.5))
			local offset=Vector3.new(target.X-root.Position.X,0,target.Z-root.Position.Z)
			local direction=offset.Magnitude>.01 and offset.Unit or self.Camera:Aim("Shot")
			local goalTarget=offset.Magnitude<=200
			if goalTarget and self.GoalTarget then self.GoalTarget:Lock(target)end
			return{Direction=direction,Position=target,GoalTarget=goalTarget,TargetModel=nil}
		end
	end
	local position=self.MouseAim:GetAimWorldPosition();local switchTarget=kind=="Switch"and self:_reticleSwitchTarget(position)or nil
	if not root then return{Direction=self.Camera:Aim(kind),Position=position,GoalTarget=false,TargetModel=switchTarget or(kind=="Pass"and self.LockedPassTarget or nil)}end
	local goalTarget=kind=="Shot"and self.MouseAim:IsAimingAtGoal();position=goalTarget and self.MouseAim:GetGoalAimPoint(shotCharge or 0)or position
	if (self.PracticeMode or self.TutorialShootingMode==true) and kind=="Shot"then local practiceTarget,practiceOnTarget=self:_practiceGoalPoint(shotCharge or 0);if practiceTarget then position=practiceTarget;goalTarget=practiceOnTarget==true end end
	if kind=="Shot"and self.SetPieceMode=="DirectShotFreeKick"and self.SetPieceGoalSign and position and self.Camera and self.Camera.PitchCFrame then
		local rectangle=GoalModelResolver.ResolveByAttackSign(self.SetPieceGoalSign,self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length)
		position=GoalModelResolver.ClampPoint(rectangle,position)
		goalTarget=true
	end
	local penaltySlot=nil
	if kind=="Shot" and (self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense") then
		local goalSign=tonumber(self.Ball:GetAttribute("VTRPenaltyGoalSign"))or self.SetPieceGoalSign or(self.ControlledSide=="Home"and-1 or 1)
		local rectangle=GoalModelResolver.ResolveByAttackSign(goalSign,self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length)
		local mousePenaltyPoint=nil
		if self.MouseAim and self.MouseAim.GetGoalPlaneAimPoint then
			mousePenaltyPoint=select(1,self.MouseAim:GetGoalPlaneAimPoint(0))
		end
		position=(mousePenaltyPoint and GoalModelResolver.ClampPoint(rectangle,mousePenaltyPoint)) or (position and GoalModelResolver.ClampPoint(rectangle,position)) or self.PenaltyAimPoint or PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,self.PenaltyAimSlot or"MIDDLE",self.Camera.Width)
		penaltySlot=PenaltyConfig.NormalizeSlot(PenaltyConfig.SlotFromGoalPoint(self.Camera.PitchCFrame,self.Camera.Length,goalSign,position,self.Camera.Width))or PenaltyConfig.NormalizeSlot(self.PenaltyAimSlot)or"MIDDLE"
		position=PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,penaltySlot,self.Camera.Width)
		self.PenaltyAimSlot=penaltySlot
		self.PenaltyAimPoint=position;goalTarget=true
	end
	if goalTarget and position and self.GoalTarget then self.GoalTarget:Lock(position)end;local offset=position and(position-root.Position)or Vector3.zero;local direction=offset.Magnitude>.01 and offset.Unit or self.MouseAim:GetAimDirectionFromPlayer(root.Position);local freeKickCurve,freeKickLift=0,0;if kind=="Shot"and self.SetPieceMode=="DirectShotFreeKick"and self.Input and self.Input.FreeKickModifiers then freeKickCurve,freeKickLift=self.Input:FreeKickModifiers()end;return{Direction=direction,Position=position,GoalTarget=goalTarget,TargetModel=switchTarget or(kind=="Pass"and self.LockedPassTarget or nil),FreeKickCurve=freeKickCurve,FreeKickLift=freeKickLift,PenaltySlot=penaltySlot,PenaltyDefense=self.SetPieceMode=="PenaltyDefense",PenaltyAttempt=self.PenaltyAttempt}
end
function Controller:_playPrematchSkipTransition()
	local gui=Instance.new("ScreenGui");gui.Name="VTRPrematchSkipTransition";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=112;gui.Parent=Players.LocalPlayer.PlayerGui
	self:_trackTemporary(gui)
	DeviceScaleService.Apply(gui)
	local overlay=Instance.new("CanvasGroup");overlay.BackgroundColor3=Color3.new(0,0,0);overlay.BorderSizePixel=0;overlay.GroupTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=112;overlay.Parent=gui
	local slash=Instance.new("Frame");slash.AnchorPoint=Vector2.new(.5,.5);slash.BackgroundColor3=Color3.new(0,0,0);slash.BackgroundTransparency=1;slash.BorderSizePixel=0;slash.Position=UDim2.fromScale(-.25,.5);slash.Rotation=-16;slash.Size=UDim2.fromScale(.55,1.7);slash.ZIndex=113;slash.Parent=overlay
	local TweenService=game:GetService("TweenService")
	TweenService:Create(overlay,TweenInfo.new(.16),{GroupTransparency=0}):Play()
	TweenService:Create(slash,TweenInfo.new(.36,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.fromScale(1.22,.5)}):Play()
	self:_delayMatchTask(.42,function()if not gui.Parent then return end;TweenService:Create(overlay,TweenInfo.new(.16),{GroupTransparency=1}):Play();self:_delayMatchTask(.18,function()if gui.Parent then gui:Destroy()end end)end)
end
function Controller:_setPrematchSkipProgress(readyCount:number?,totalCount:number?)
	local playerGui=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui=playerGui and playerGui:FindFirstChild("VTRPrematchBroadcast")
	if not gui then return end
	local total=math.max(1,math.floor(tonumber(totalCount)or 2))
	local count=math.clamp(math.floor(tonumber(readyCount)or 0),0,total)
	local text=string.format("SKIP %d/%d",count,total)
	local keyboard=gui:FindFirstChild("KeyboardSkipIntroHint",true)
	if keyboard and (keyboard:IsA("TextLabel") or keyboard:IsA("TextButton"))then keyboard.Text=text end
	local mobile=gui:FindFirstChild("MobileSkipIntro",true)
	if mobile and mobile:IsA("TextButton")then mobile.Text=text end
end
function Controller:_practiceGoalSign():number
	if self.TutorialShootingMode==true and tonumber(self.TutorialGoalSign)then return tonumber(self.TutorialGoalSign) :: number end
	local half=tonumber(workspace:GetAttribute("VTRMatchHalf"))or 1
	local team=tostring(self.ActiveModel and self.ActiveModel:GetAttribute("VTRTeam")or"Home")
	return team=="Home"and(half>=2 and 1 or-1)or(half>=2 and-1 or 1)
end
function Controller:_practiceGoalPoint(charge:number?):(Vector3?, boolean)
	if not self.Camera or not self.Camera.PitchCFrame then return nil,false end
	if self:_useStickShotAim() then
		local vector=self.Input and self.Input:MobileAimVector("Shot")or nil
		local point=goalPointFromStick(self.Camera.PitchCFrame,self.Camera.Width or 76,self.Camera.Length or 742,self:_practiceGoalSign(),vector,self.PracticeAimPoint or self.GamepadShotAimPoint)
		self.PracticeAimPoint=point
		self.GamepadShotAimPoint=point
		self.PracticeShotOnTarget=true
		return point,true
	end
	if self.MouseAim and self.MouseAim.GetGoalPlaneAimPoint then
		local point,onTarget=self.MouseAim:GetGoalPlaneAimPoint(charge or 0)
		if point then
			self.PracticeAimPoint=point
			self.PracticeShotOnTarget=onTarget==true
			return point,onTarget==true
		end
	end
	local goalPoint=self.MouseAim and self.MouseAim:GetGoalAimPoint(charge or 0)or nil
	if goalPoint then self.PracticeAimPoint=goalPoint;self.PracticeShotOnTarget=true;return goalPoint,true end
	local point=goalPointFromStick(self.Camera.PitchCFrame,self.Camera.Width or 76,self.Camera.Length or 742,self:_practiceGoalSign(),nil,self.PracticeAimPoint)
	self.PracticeAimPoint=point
	self.PracticeShotOnTarget=true
	return point,true
end
function Controller:_playPracticeResetTransition(result:string)
	local gui=Instance.new("ScreenGui");gui.Name="VTRPracticeResetTransition";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=126;gui.Parent=Players.LocalPlayer.PlayerGui;DeviceScaleService.Apply(gui)
	self:_trackTemporary(gui)
	local TweenService=game:GetService("TweenService")
	local overlay=Instance.new("CanvasGroup");overlay.BackgroundColor3=Color3.new(0,0,0);overlay.BorderSizePixel=0;overlay.GroupTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=126;overlay.Parent=gui
	local flash=Instance.new("Frame");flash.AnchorPoint=Vector2.new(.5,.5);flash.BackgroundColor3=Color3.fromHex("B7FF1A");flash.BorderSizePixel=0;flash.Position=UDim2.fromScale(.5,.5);flash.Rotation=-14;flash.Size=UDim2.fromScale(.18,1.35);flash.ZIndex=127;flash.Parent=overlay
	local text=Instance.new("TextLabel");text.BackgroundTransparency=1;text.AnchorPoint=Vector2.new(.5,.5);text.Position=UDim2.fromScale(.5,.5);text.Size=UDim2.fromOffset(380,74);text.Text=string.upper(result);text.TextColor3=Color3.fromHex("B7FF1A");text.TextSize=34;text.Font=Enum.Font.GothamBlack;text.ZIndex=128;text.Parent=overlay
	TweenService:Create(overlay,TweenInfo.new(.1),{GroupTransparency=.08}):Play()
	TweenService:Create(flash,TweenInfo.new(.32,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.fromScale(1.24,.5),Size=UDim2.fromScale(.34,1.6)}):Play()
	self:_delayMatchTask(.38,function()if not gui.Parent then return end;TweenService:Create(overlay,TweenInfo.new(.14),{GroupTransparency=1}):Play();self:_delayMatchTask(.16,function()if gui.Parent then gui:Destroy()end end)end)
end
function Controller:_hideTutorialStartButton()
	if self.TutorialStartGui then self.TutorialStartGui:Destroy();self.TutorialStartGui=nil end
end
function Controller:_setTutorialHudOnly(active:boolean)
	if not self.HUD or not self.HUD.Gui then return end
	self.TutorialHudOnly=active
	if active then
		self.TutorialHiddenGuiVisibility=self.TutorialHiddenGuiVisibility or{}
		for _,child in self.HUD.Gui:GetChildren()do
			if child:IsA("GuiObject")and child.Name~="WorldCupTutorialOverlay"and child.Name~="VTRTrainerPrompt"then
				if self.TutorialHiddenGuiVisibility[child]==nil then self.TutorialHiddenGuiVisibility[child]=child.Visible end
				child.Visible=false
			end
		end
	else
		for child,visible in self.TutorialHiddenGuiVisibility or{}do
			if child and child.Parent and child:IsA("GuiObject")then child.Visible=visible==true end
		end
		self.TutorialHiddenGuiVisibility=nil
	end
	local tutorialAim=self.WorldCupOnboardingTrainer==true and self.TutorialAcknowledged==true and self.TutorialInputBlocked~=true
	if self.Minimap then self.Minimap:SetMatchActive(not active and self.MatchInPlay and self.WatchMode~=true)end
	if self.AimLine then self.AimLine:SetMatchActive((not active or tutorialAim) and self.MatchInPlay and self.WatchMode~=true)end
	if self.GoalTarget then self.GoalTarget:SetMatchActive((not active or tutorialAim) and self.MatchInPlay and self.WatchMode~=true)end
end
function Controller:_setTutorialInputBlocked(blocked:boolean)
	self.TutorialInputBlocked=blocked==true
	if self.Input then
		self.Input:SetSuppressed(self.WatchMode==true or self.TutorialInputBlocked==true)
		if self.Input.MobileControls and self.Input.MobileControls.SetVisible then
			self.Input.MobileControls:SetVisible(self.MatchInPlay and self.WatchMode~=true and self.TutorialInputBlocked~=true)
		end
	end
end
function Controller:_tutorialInputLabel(action:any):string
	local actionName=tostring(action or"")
	if actionName==""then return""end
	local glyphAction=actionName=="Pass"and"GroundPass"or actionName=="Shoot"and"Shot"or actionName
	return ControlGlyphService.Glyph(glyphAction,self.PlayabilitySettings,{MobilePassContext="Swipe"})
end
function Controller:_setTutorialOverlayCompact(compact:boolean)
	local overlay=self.TutorialOverlay
	local panel=overlay and overlay:FindFirstChild("Panel")
	if not overlay or not panel or not panel:IsA("GuiObject")then return end
	overlay.Active=not compact
	overlay.BackgroundTransparency=compact and 1 or .24
	panel.AnchorPoint=Vector2.new(.5,compact and 0 or .5)
	panel.Position=compact and UDim2.fromScale(.5,.035)or UDim2.fromScale(.5,.5)
	panel.Size=compact and UDim2.fromOffset(520,70)or UDim2.fromOffset(560,190)
	local title=panel:FindFirstChild("Title")
	local body=panel:FindFirstChild("Body")
	local key=panel:FindFirstChild("Key")
	local ok=panel:FindFirstChild("Ok")
	local progress=panel:FindFirstChild("Progress")
	if title and title:IsA("TextLabel")then title.Visible=not compact end
	if body and body:IsA("TextLabel")then
		body.Position=compact and UDim2.fromOffset(18,13)or UDim2.fromOffset(24,58)
		body.Size=compact and UDim2.new(1,-210,0,24)or UDim2.new(1,-48,0,58)
		body.TextSize=compact and 17 or 27
		body.TextXAlignment=compact and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	end
	if key and key:IsA("TextLabel")then
		key.AnchorPoint=compact and Vector2.new(1,.5)or Vector2.new(.5,1)
		key.Position=compact and UDim2.new(1,-18,.5,0)or UDim2.new(.5,0,1,-24)
		key.Size=compact and UDim2.fromOffset(155,34)or UDim2.fromOffset(180,38)
		key.TextSize=compact and 14 or 16
	end
	if ok and ok:IsA("GuiObject")then ok.Visible=not compact end
	if progress and progress:IsA("GuiObject")then
		progress.Visible=compact
		progress.Position=compact and UDim2.fromOffset(18,47)or UDim2.fromOffset(24,122)
		progress.Size=compact and UDim2.new(1,-210,0,7)or UDim2.new(1,-48,0,9)
	end
end
function Controller:_setTutorialProgress(count:any,target:any)
	local overlay=self.TutorialOverlay
	local panel=overlay and overlay:FindFirstChild("Panel")
	local progress=panel and panel:FindFirstChild("Progress")
	local fill=progress and progress:FindFirstChild("Fill")
	local c=math.clamp(tonumber(count)or 0,0,tonumber(target)or 0)
	local t=math.max(1,tonumber(target)or 1)
	if fill and fill:IsA("GuiObject")then
		TweenService:Create(fill,TweenInfo.new(.22,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.fromScale(math.clamp(c/t,0,1),1)}):Play()
	end
end
function Controller:_showTutorialStepComplete(titleText:string?)
	if not self.HUD or not self.HUD.Gui then return end
	local old=self.HUD.Gui:FindFirstChild("TutorialStepComplete")
	if old then old:Destroy()end
	local title=string.upper(titleText or"STEP COMPLETE")
	local subtitle=title=="STEP 2 COMPLETE"and"SHOOTING DRILL CLEARED"or(title=="STEP 3 COMPLETE"and"DEFENDING DRILL CLEARED"or"PASSING DRILL CLEARED")
	local group=Instance.new("CanvasGroup");group.Name="TutorialStepComplete";group.BackgroundTransparency=1;group.GroupTransparency=1;group.Size=UDim2.fromScale(1,1);group.ZIndex=240;group.Parent=self.HUD.Gui;self:_trackTemporary(group)
	local burst=Instance.new("Frame");burst.AnchorPoint=Vector2.new(.5,.5);burst.BackgroundColor3=Color3.fromHex("B7FF1A");burst.BackgroundTransparency=.18;burst.BorderSizePixel=0;burst.Position=UDim2.fromScale(.5,.5);burst.Size=UDim2.fromOffset(0,5);burst.ZIndex=241;burst.Parent=group
	local burstCorner=Instance.new("UICorner");burstCorner.CornerRadius=UDim.new(1,0);burstCorner.Parent=burst
	local label=Instance.new("TextLabel");label.AnchorPoint=Vector2.new(.5,.5);label.BackgroundTransparency=1;label.Position=UDim2.fromScale(.5,.5);label.Size=UDim2.fromOffset(620,90);label.Text=title;label.TextColor3=Color3.fromHex("FFFFFF");label.TextStrokeColor3=Color3.fromHex("000000");label.TextStrokeTransparency=.18;label.TextSize=38;label.Font=Enum.Font.GothamBlack;label.ZIndex=242;label.Parent=group
	local sub=Instance.new("TextLabel");sub.AnchorPoint=Vector2.new(.5,.5);sub.BackgroundTransparency=1;sub.Position=UDim2.fromScale(.5,.57);sub.Size=UDim2.fromOffset(440,28);sub.Text=subtitle;sub.TextColor3=Color3.fromHex("B7FF1A");sub.TextSize=14;sub.Font=Enum.Font.GothamBlack;sub.ZIndex=242;sub.Parent=group
	TweenService:Create(group,TweenInfo.new(.16),{GroupTransparency=0}):Play()
	TweenService:Create(burst,TweenInfo.new(.36,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(840,5),BackgroundTransparency=.32}):Play()
	self:_delayMatchTask(1.22,function()
		if group.Parent then TweenService:Create(group,TweenInfo.new(.24),{GroupTransparency=1}):Play();self:_delayMatchTask(.26,function()if group.Parent then group:Destroy()end end)end
	end)
end

function Controller:_playTutorialStepTransition(titleText:string?)
	self:_showTutorialStepComplete(titleText)
	if not self.HUD or not self.HUD.Gui then return end
	local old=self.HUD.Gui:FindFirstChild("TutorialStageFade")
	if old then old:Destroy()end
	local fade=Instance.new("Frame");fade.Name="TutorialStageFade";fade.BackgroundColor3=Color3.new(0,0,0);fade.BackgroundTransparency=1;fade.BorderSizePixel=0;fade.Size=UDim2.fromScale(1,1);fade.ZIndex=260;fade.Parent=self.HUD.Gui;self:_trackTemporary(fade)
	self:_delayMatchTask(1.05,function()
		if not fade.Parent then return end
		TweenService:Create(fade,TweenInfo.new(.26,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
		self:_delayMatchTask(.48,function()
			if not fade.Parent then return end
			TweenService:Create(fade,TweenInfo.new(.34,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1}):Play()
			self:_delayMatchTask(.36,function()if fade.Parent then fade:Destroy()end end)
		end)
	end)
end
function Controller:_hideTutorialPassPointer()
	if self.TutorialPassPointerStep then self.TutorialPassPointerStep:Disconnect();self.TutorialPassPointerStep=nil end
	if self.TutorialPassPointer then self.TutorialPassPointer:Destroy();self.TutorialPassPointer=nil end
	if self.TutorialPassPointers then
		for _,gui in self.TutorialPassPointers do
			if gui and gui.Parent then gui:Destroy()end
		end
		self.TutorialPassPointers=nil
	end
	self.TutorialPassPointerTarget=nil
end
function Controller:_hideTutorialMovementLane()
	if self.TutorialMovementLaneStep then self.TutorialMovementLaneStep:Disconnect();self.TutorialMovementLaneStep=nil end
	if self.TutorialMovementLane then self.TutorialMovementLane:Destroy();self.TutorialMovementLane=nil end
	if self.TutorialMovementLaneEnd then self.TutorialMovementLaneEnd:Destroy();self.TutorialMovementLaneEnd=nil end
	if self.TutorialMovementRouteFolder then self.TutorialMovementRouteFolder:Destroy();self.TutorialMovementRouteFolder=nil end
	if self.TutorialStaminaGui then self.TutorialStaminaGui:Destroy();self.TutorialStaminaGui=nil end
	self.TutorialMovementLaneTarget=nil
	self.TutorialMovementRoutePoints=nil
	self.TutorialMovementCurrentPoint=nil
	self.TutorialMovementHelpLevel=nil
	self.TutorialCameraNudgeTarget=nil
	self.TutorialCameraNudgeUntil=nil
end
function Controller:_showTutorialMovementLane(target:Vector3?,helpLevel:any,routePoints:any?,currentPoint:any?,showStamina:boolean?)
	if typeof(target)~="Vector3"then self:_hideTutorialMovementLane();return end
	self.TutorialMovementLaneTarget=target
	self.TutorialMovementRoutePoints=type(routePoints)=="table"and routePoints or self.TutorialMovementRoutePoints
	self.TutorialMovementCurrentPoint=math.max(1,math.floor(tonumber(currentPoint)or tonumber(self.TutorialMovementCurrentPoint)or 1))
	self.TutorialMovementHelpLevel=tonumber(helpLevel)or 0
	if not self.TutorialMovementRouteFolder then
		local folder=Instance.new("Folder");folder.Name="VTRTutorialMovementRoute";folder.Parent=workspace;self:_trackTemporary(folder);self.TutorialMovementRouteFolder=folder
	end
	if self.TutorialMovementRouteFolder and type(self.TutorialMovementRoutePoints)=="table"then
		self.TutorialMovementRouteFolder:ClearAllChildren()
		for index,point in self.TutorialMovementRoutePoints do
			if typeof(point)=="Vector3"then
				local current=self.TutorialMovementCurrentPoint or 1
				local active=index==current
				local marker=Instance.new("Part");marker.Name="Point"..tostring(index);marker.Anchored=true;marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false;marker.Material=Enum.Material.Neon;marker.Color=Color3.fromHex("B7FF1A");marker.Transparency=index<current and .82 or(active and .22 or .58);marker.Shape=Enum.PartType.Cylinder;marker.Size=Vector3.new(.14,active and 10 or 6,active and 10 or 6);marker.CFrame=CFrame.new(point+Vector3.new(0,.12,0))*CFrame.Angles(0,0,math.rad(90));marker.Parent=self.TutorialMovementRouteFolder
			end
		end
	end
	if showStamina==true and self.ActiveModel then
		local root=self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?
		if root and not self.TutorialStaminaGui then
			local gui=Instance.new("BillboardGui");gui.Name="VTRTutorialStaminaBar";gui.AlwaysOnTop=true;gui.Size=UDim2.fromOffset(78,6);gui.StudsOffset=Vector3.new(0,4.85,0);gui.Adornee=root;gui.Parent=root;self:_trackTemporary(gui);self.TutorialStaminaGui=gui
			local back=Instance.new("Frame");back.Name="Back";back.BackgroundColor3=Color3.fromHex("061006");back.BackgroundTransparency=.18;back.BorderSizePixel=0;back.Size=UDim2.fromScale(1,1);back.Parent=gui
			local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,2);corner.Parent=back
			local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("B7FF1A");stroke.Transparency=.22;stroke.Thickness=1;stroke.Parent=back
			local fill=Instance.new("Frame");fill.Name="Fill";fill.BackgroundColor3=Color3.fromHex("B7FF1A");fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(.8,1);fill.Parent=back
			local fillCorner=Instance.new("UICorner");fillCorner.CornerRadius=UDim.new(0,2);fillCorner.Parent=fill
		end
	end
	if not self.TutorialMovementLane or not self.TutorialMovementLane.Parent then
		local lane=Instance.new("Part");lane.Name="VTRTutorialMovementLane";lane.Anchored=true;lane.CanCollide=false;lane.CanTouch=false;lane.CanQuery=false;lane.Material=Enum.Material.Neon;lane.Color=Color3.fromHex("B7FF1A");lane.Transparency=.66;lane.Size=Vector3.new(1.15,.05,18);lane.Parent=workspace;self:_trackTemporary(lane);self.TutorialMovementLane=lane
		local endpoint=Instance.new("Part");endpoint.Name="VTRTutorialMovementLaneEnd";endpoint.Anchored=true;endpoint.CanCollide=false;endpoint.CanTouch=false;endpoint.CanQuery=false;endpoint.Material=Enum.Material.Neon;endpoint.Color=Color3.fromHex("B7FF1A");endpoint.Transparency=.48;endpoint.Shape=Enum.PartType.Cylinder;endpoint.Size=Vector3.new(.1,4.4,4.4);endpoint.Parent=workspace;self:_trackTemporary(endpoint);self.TutorialMovementLaneEnd=endpoint
	end
	if (tonumber(helpLevel)or 0)>0 and self.Input and self.Input.MobileControls and self.Input.MobileControls.PulseMovement then
		self.Input.MobileControls:PulseMovement((tonumber(helpLevel)or 0)+1)
	end
	if (tonumber(helpLevel)or 0)>=2 then
		self.TutorialCameraNudgeTarget=target
		self.TutorialCameraNudgeUntil=os.clock()+2.5
	end
	if not self.TutorialMovementLaneStep then
		self.TutorialMovementLaneStep=self:_trackConnection(RunService.RenderStepped:Connect(function()
			local lane=self.TutorialMovementLane
			local endpoint=self.TutorialMovementLaneEnd
			local active=self.ActiveModel
			local root=active and active:FindFirstChild("HumanoidRootPart")::BasePart?
			local targetPoint=self.TutorialMovementLaneTarget
			if not lane or not lane.Parent or typeof(targetPoint)~="Vector3"or not root then self:_hideTutorialMovementLane();return end
			local start=Vector3.new(root.Position.X,root.Position.Y-2.86,root.Position.Z)
			local finish=Vector3.new(targetPoint.X,start.Y,targetPoint.Z)
			local delta=finish-start
			local length=math.max(delta.Magnitude,1)
			local help=tonumber(self.TutorialMovementHelpLevel)or 0
			local pulse=(math.sin(os.clock()*5.6)+1)*.5
			lane.Size=Vector3.new(1.05+help*.35,.05,length)
			lane.Transparency=math.clamp(.72-help*.12-pulse*.06,.34,.78)
			lane.CFrame=CFrame.lookAt(start+delta*.5,finish)
			if endpoint then
				endpoint.Transparency=math.clamp(.5-help*.16-pulse*.1,.16,.62)
				endpoint.CFrame=CFrame.new(finish+Vector3.new(0,.08,0))*CFrame.Angles(0,0,math.rad(90))
			end
			if self.TutorialStaminaGui then
				local back=self.TutorialStaminaGui:FindFirstChild("Back")
				local fill=back and back:FindFirstChild("Fill")
				if fill and fill:IsA("GuiObject")then fill.Size=UDim2.fromScale(math.clamp((self.Stamina or 100)/(Config.Stamina.Maximum or 100),0,1)*.8,1)end
			end
		end),"State")
	end
end
function Controller:_applyTutorialCameraNudge(dt:number)
	local target=self.TutorialCameraNudgeTarget
	if typeof(target)~="Vector3"or (tonumber(self.TutorialCameraNudgeUntil)or 0)<os.clock()then return end
	local camera=workspace.CurrentCamera
	if not camera then return end
	local desired=CFrame.lookAt(camera.CFrame.Position,target+Vector3.new(0,3.4,0),Vector3.yAxis)
	camera.CFrame=camera.CFrame:Lerp(desired,math.clamp(dt*1.6,0,.12))
end
function Controller:_showTutorialPassPointer(model:Model?)
	if not model or not model.Parent then self:_hideTutorialPassPointer();return end
	if self.TutorialPassPointerTarget==model and self.TutorialPassPointer then return end
	self:_hideTutorialPassPointer()
	local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
	if not root then return end
	local gui=Instance.new("BillboardGui");gui.Name="VTRTutorialPassPointer";gui.AlwaysOnTop=true;gui.Size=UDim2.fromOffset(118,62);gui.StudsOffset=Vector3.new(0,6.2,0);gui.Adornee=root;gui.Parent=root;self:_trackTemporary(gui)
	local label=Instance.new("TextLabel");label.AnchorPoint=Vector2.new(.5,.5);label.BackgroundColor3=Color3.fromHex("B7FF1A");label.BorderSizePixel=0;label.Position=UDim2.fromScale(.5,.32);label.Size=UDim2.fromOffset(86,28);label.Text="PASS!";label.TextColor3=Color3.fromHex("050505");label.TextSize=16;label.Font=Enum.Font.GothamBlack;label.ZIndex=2;label.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=label
	local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("FFFFFF");stroke.Thickness=2;stroke.Transparency=.08;stroke.Parent=label
	local arrow=Instance.new("TextLabel");arrow.AnchorPoint=Vector2.new(.5,.5);arrow.BackgroundTransparency=1;arrow.Position=UDim2.fromScale(.5,.76);arrow.Size=UDim2.fromOffset(60,30);arrow.Text="▼";arrow.TextColor3=Color3.fromHex("B7FF1A");arrow.TextStrokeColor3=Color3.fromHex("050505");arrow.TextStrokeTransparency=.15;arrow.TextSize=28;arrow.Font=Enum.Font.GothamBlack;arrow.ZIndex=2;arrow.Parent=gui
	self.TutorialPassPointer=gui
	self.TutorialPassPointerTarget=model
	local started=os.clock()
	self.TutorialPassPointerStep=self:_trackConnection(RunService.RenderStepped:Connect(function()
		if not gui.Parent or not model.Parent then self:_hideTutorialPassPointer();return end
		local pulse=(math.sin((os.clock()-started)*7)+1)*.5
		gui.StudsOffset=Vector3.new(0,6.1+pulse*.55,0)
		label.Rotation=math.sin((os.clock()-started)*5)*2.5
	end),"State")
end
function Controller:_showTutorialPassPointers(models:any)
	local targets={}
	if typeof(models)=="Instance"then
		table.insert(targets,models)
	elseif type(models)=="table"then
		for _,model in models do
			if typeof(model)=="Instance"and model:IsA("Model")and model.Parent then table.insert(targets,model)end
		end
	end
	if #targets<=0 then self:_hideTutorialPassPointer();return end
	self:_hideTutorialPassPointer()
	self.TutorialPassPointers={}
	for _,model in targets do
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if root then
			local gui=Instance.new("BillboardGui");gui.Name="VTRTutorialPassPointer";gui.AlwaysOnTop=true;gui.Size=UDim2.fromOffset(118,62);gui.StudsOffset=Vector3.new(0,6.2,0);gui.Adornee=root;gui.Parent=root;self:_trackTemporary(gui)
			local label=Instance.new("TextLabel");label.Name="PassLabel";label.AnchorPoint=Vector2.new(.5,.5);label.BackgroundColor3=Color3.fromHex("B7FF1A");label.BorderSizePixel=0;label.Position=UDim2.fromScale(.5,.32);label.Size=UDim2.fromOffset(86,28);label.Text="PASS!";label.TextColor3=Color3.fromHex("050505");label.TextSize=16;label.Font=Enum.Font.GothamBlack;label.ZIndex=2;label.Parent=gui
			local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=label
			local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("FFFFFF");stroke.Thickness=2;stroke.Transparency=.08;stroke.Parent=label
			local arrow=Instance.new("TextLabel");arrow.AnchorPoint=Vector2.new(.5,.5);arrow.BackgroundTransparency=1;arrow.Position=UDim2.fromScale(.5,.76);arrow.Size=UDim2.fromOffset(60,30);arrow.Text="v";arrow.TextColor3=Color3.fromHex("B7FF1A");arrow.TextStrokeColor3=Color3.fromHex("050505");arrow.TextStrokeTransparency=.15;arrow.TextSize=28;arrow.Font=Enum.Font.GothamBlack;arrow.ZIndex=2;arrow.Parent=gui
			table.insert(self.TutorialPassPointers,gui)
		end
	end
	if #self.TutorialPassPointers<=0 then return end
	self.TutorialPassPointer=self.TutorialPassPointers[1]
	self.TutorialPassPointerTarget=targets[1]
	local started=os.clock()
	self.TutorialPassPointerStep=self:_trackConnection(RunService.RenderStepped:Connect(function()
		if not self.TutorialPassPointers or #self.TutorialPassPointers<=0 then self:_hideTutorialPassPointer();return end
		local pulse=(math.sin((os.clock()-started)*7)+1)*.5
		for _,gui in self.TutorialPassPointers do
			if not gui.Parent then self:_hideTutorialPassPointer();return end
			gui.StudsOffset=Vector3.new(0,6.1+pulse*.55,0)
			local label=gui:FindFirstChild("PassLabel")
			if label and label:IsA("GuiObject")then label.Rotation=math.sin((os.clock()-started)*5)*2.5 end
		end
	end),"State")
end
function Controller:_showTutorialOverlay(message:any,action:any,count:any,target:any,requiresOk:boolean?)
	if not self.HUD or not self.HUD.Gui then return end
	self.TutorialOverlayPrompt={message,action,count,target,requiresOk}
	if not self.ControlGlyphConnection then
		self.ControlGlyphConnection=self:_trackConnection(ControlGlyphService.Observe(function()
			local prompt=self.TutorialOverlayPrompt
			if prompt and self.Active then self:_showTutorialOverlay(prompt[1],prompt[2],prompt[3],prompt[4],prompt[5])end
		end),"State")
	end
	local text=string.upper(tostring(message or""))
	local actionText=self:_tutorialInputLabel(action)
	local c=tonumber(count)or 0
	local t=tonumber(target)or 0
	local overlay=self.TutorialOverlay
	if not overlay or not overlay.Parent then
		overlay=Instance.new("CanvasGroup");overlay.Name="WorldCupTutorialOverlay";overlay.BackgroundColor3=Color3.fromHex("000000");overlay.BackgroundTransparency=.24;overlay.BorderSizePixel=0;overlay.GroupTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=220;overlay.Parent=self.HUD.Gui;self:_trackTemporary(overlay);self.TutorialOverlay=overlay
		local vignette=Instance.new("Frame");vignette.Name="Panel";vignette.AnchorPoint=Vector2.new(.5,.5);vignette.BackgroundColor3=Color3.fromHex("050505");vignette.BackgroundTransparency=.08;vignette.BorderSizePixel=0;vignette.Position=UDim2.fromScale(.5,.5);vignette.Size=UDim2.fromOffset(560,190);vignette.ZIndex=221;vignette.Parent=overlay
		local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=vignette
		local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("B7FF1A");stroke.Thickness=2;stroke.Transparency=.18;stroke.Parent=vignette
		local title=Instance.new("TextLabel");title.Name="Title";title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(24,22);title.Size=UDim2.new(1,-48,0,26);title.Text="WORLD CUP TRAINING";title.TextColor3=Color3.fromHex("B7FF1A");title.TextSize=13;title.Font=Enum.Font.GothamBlack;title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=222;title.Parent=vignette
		local body=Instance.new("TextLabel");body.Name="Body";body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(24,58);body.Size=UDim2.new(1,-48,0,58);body.TextColor3=Color3.fromHex("FFFFFF");body.TextSize=27;body.Font=Enum.Font.GothamBlack;body.TextWrapped=true;body.ZIndex=222;body.Parent=vignette
		local key=Instance.new("TextLabel");key.Name="Key";key.AnchorPoint=Vector2.new(.5,1);key.BackgroundColor3=Color3.fromHex("B7FF1A");key.BorderSizePixel=0;key.Position=UDim2.new(.5,0,1,-24);key.Size=UDim2.fromOffset(180,38);key.TextColor3=Color3.fromHex("050505");key.TextSize=16;key.Font=Enum.Font.GothamBlack;key.ZIndex=222;key.Parent=vignette
		local keyCorner=Instance.new("UICorner");keyCorner.CornerRadius=UDim.new(1,0);keyCorner.Parent=key
		local progress=Instance.new("Frame");progress.Name="Progress";progress.BackgroundColor3=Color3.fromHex("182112");progress.BorderSizePixel=0;progress.Position=UDim2.fromOffset(24,122);progress.Size=UDim2.new(1,-48,0,9);progress.ZIndex=222;progress.Parent=vignette
		local progressCorner=Instance.new("UICorner");progressCorner.CornerRadius=UDim.new(1,0);progressCorner.Parent=progress
		local fill=Instance.new("Frame");fill.Name="Fill";fill.BackgroundColor3=Color3.fromHex("B7FF1A");fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(0,1);fill.ZIndex=223;fill.Parent=progress
		local fillCorner=Instance.new("UICorner");fillCorner.CornerRadius=UDim.new(1,0);fillCorner.Parent=fill
		local ok=Instance.new("TextButton");ok.Name="Ok";ok.AnchorPoint=Vector2.new(.5,1);ok.BackgroundColor3=Color3.fromHex("FFFFFF");ok.BorderSizePixel=0;ok.Position=UDim2.new(.5,0,1,-24);ok.Size=UDim2.fromOffset(170,42);ok.Text="OK";ok.TextColor3=Color3.fromHex("050505");ok.TextSize=17;ok.Font=Enum.Font.GothamBlack;ok.ZIndex=223;ok.Parent=vignette
		local okCorner=Instance.new("UICorner");okCorner.CornerRadius=UDim.new(1,0);okCorner.Parent=ok
		self:_trackConnection(ok.Activated:Connect(function()
			self.TutorialAcknowledged=true
			self:_setTutorialInputBlocked(false)
			self:_setTutorialOverlayCompact(true)
			if self.AimLine then self.AimLine:SetMatchActive(self.MatchInPlay and self.WatchMode~=true)end
			if self.GoalTarget then self.GoalTarget:SetMatchActive(self.MatchInPlay and self.WatchMode~=true)end
			if self.Action then self.Action:FireServer({Type="TutorialReady"})end
		end),"Input")
	end
	local panel=overlay:FindFirstChild("Panel")
	local body=panel and panel:FindFirstChild("Body")
	local key=panel and panel:FindFirstChild("Key")
	local ok=panel and panel:FindFirstChild("Ok")
	if body and body:IsA("TextLabel")then body.Text=text end
	if key and key:IsA("TextLabel")then
		local suffix=t>1 and("  "..tostring(c).."/"..tostring(t))or""
		key.Text=actionText~=""and(actionText..suffix)or suffix
		key.Visible=key.Text~=""
	end
	local needsOk=requiresOk==true and self.TutorialAcknowledged~=true
	if ok and ok:IsA("GuiObject")then ok.Visible=needsOk end
	if key and key:IsA("GuiObject")then key.Visible=not needsOk and key.Visible end
	overlay.Visible=true
	TweenService:Create(overlay,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=0}):Play()
	self:_setTutorialHudOnly(true)
	self:_setTutorialOverlayCompact(not needsOk)
	self:_setTutorialProgress(c,t)
	self:_setTutorialInputBlocked(needsOk)
end
function Controller:_hideTutorialOverlay()
	if self.TutorialOverlay then self.TutorialOverlay:Destroy();self.TutorialOverlay=nil end
	self.TutorialOverlayPrompt=nil
	self:_hideTutorialPassPointer()
	self:_hideTutorialMovementLane()
	self.TutorialAcknowledged=nil
	self:_setTutorialInputBlocked(false)
	self:_setTutorialHudOnly(false)
end
function Controller:_ensurePracticeTuning()
	if self.PracticeTuning then return end
	local keeper={};for _,spec in KEEPER_TUNING do keeper[spec.Key]=spec.Default end
	local shooting={};for _,spec in SHOOTING_TUNING do shooting[spec.Key]=spec.Default end
	self.PracticeTuning={Keeper=keeper,Shooting=shooting}
end
function Controller:_emitPracticeTuning(force:boolean?)
	if not self.MatchData or self.MatchData.DeveloperAccess~=true then return end
	if not self.PracticeMode or not self.Action then return end
	self:_ensurePracticeTuning()
	self.PracticeTuningSeq=(self.PracticeTuningSeq or 0)+1
	local seq=self.PracticeTuningSeq
	self:_delayMatchTask(force and 0 or .05,function()
		if not self.Active or not self.PracticeMode or seq~=self.PracticeTuningSeq then return end
		self.Action:FireServer({Type="ShootingPracticeTuning",Tuning=self.PracticeTuning})
	end)
end
function Controller:_requestPracticeReset()
	if not self.Active or not self.PracticeMode or not self.Action then return end
	self:_ensurePracticeTuning()
	self:_playPracticeResetTransition("RESET")
	self.Action:FireServer({Type="ShootingPracticeReset",Tuning=self.PracticeTuning})
end
function Controller:_addPracticeSlider(parent:Instance,spec:any,values:any,layoutOrder:number)
	local row=Instance.new("Frame");row.Name=spec.Key.."Slider";row.BackgroundTransparency=1;row.LayoutOrder=layoutOrder;row.Size=UDim2.new(1,0,0,52);row.Parent=parent
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(0,0);title.Size=UDim2.new(.66,0,0,20);title.Text=string.upper(spec.Label);title.TextColor3=Color3.fromHex("D9D9D9");title.TextSize=12;title.Font=Enum.Font.GothamBold;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=row
	local valueLabel=Instance.new("TextLabel");valueLabel.BackgroundTransparency=1;valueLabel.Position=UDim2.new(.66,0,0,0);valueLabel.Size=UDim2.new(.34,0,0,20);valueLabel.TextColor3=Color3.fromHex("B7FF1A");valueLabel.TextSize=12;valueLabel.Font=Enum.Font.GothamBlack;valueLabel.TextXAlignment=Enum.TextXAlignment.Right;valueLabel.Parent=row
	local track=Instance.new("Frame");track.BackgroundColor3=Color3.fromHex("1F271F");track.BorderSizePixel=0;track.Position=UDim2.fromOffset(0,31);track.Size=UDim2.new(1,0,0,10);track.Parent=row
	local fill=Instance.new("Frame");fill.BackgroundColor3=Color3.fromHex("B7FF1A");fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(.5,1);fill.Parent=track
	local knob=Instance.new("Frame");knob.AnchorPoint=Vector2.new(.5,.5);knob.BackgroundColor3=Color3.fromHex("FFFFFF");knob.BorderSizePixel=0;knob.Position=UDim2.fromScale(.5,.5);knob.Size=UDim2.fromOffset(20,20);knob.Parent=track
	for _,item in{track,fill,knob}do local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=item end
	local function setValue(value:number,send:boolean?)
		value=math.clamp(value,spec.Min,spec.Max);values[spec.Key]=value
		local alpha=(value-spec.Min)/(spec.Max-spec.Min)
		fill.Size=UDim2.fromScale(alpha,1);knob.Position=UDim2.fromScale(alpha,.5);valueLabel.Text=formatSliderValue(value,spec)
		if send then self:_emitPracticeTuning(false)end
	end
	local function setFromX(x:number,send:boolean?)
		local alpha=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
		setValue(spec.Min+(spec.Max-spec.Min)*alpha,send)
	end
	local dragging=false
	table.insert(self.PracticeTuningConnections,self:_trackConnection(track.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true;setFromX(input.Position.X,true)end end),"Input"))
	table.insert(self.PracticeTuningConnections,self:_trackConnection(knob.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true;setFromX(input.Position.X,true)end end),"Input"))
	table.insert(self.PracticeTuningConnections,self:_trackConnection(UserInputService.InputChanged:Connect(function(input)if dragging and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then setFromX(input.Position.X,true)end end),"Input"))
	table.insert(self.PracticeTuningConnections,self:_trackConnection(UserInputService.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end),"Input"))
	setValue(values[spec.Key]or spec.Default,false)
end
function Controller:_createPracticeTuningPanel()
	if not self.MatchData or self.MatchData.DeveloperAccess~=true then return end
	if self.PracticeTuningGui then return end
	self:_ensurePracticeTuning()
	self.PracticeTuningConnections={}
	local gui=Instance.new("ScreenGui");gui.Name="VTRShootingPracticeTuning";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=119;gui.Parent=Players.LocalPlayer.PlayerGui;self:_trackTemporary(gui);DeviceScaleService.Apply(gui)
	local panel=Instance.new("Frame");panel.Name="Panel";panel.AnchorPoint=Vector2.new(1,.5);panel.BackgroundColor3=Color3.fromHex("050705");panel.BackgroundTransparency=.04;panel.BorderSizePixel=0;panel.Position=UDim2.new(1,-18,.5,0);panel.Size=UDim2.fromOffset(340,680);panel.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=panel
	local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("B7FF1A");stroke.Transparency=.38;stroke.Thickness=1;stroke.Parent=panel
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(18,14);title.Size=UDim2.new(1,-36,0,28);title.Text="PRACTICE TUNING";title.TextColor3=Color3.fromHex("FFFFFF");title.TextSize=22;title.Font=Enum.Font.GothamBlack;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=panel
	local sub=Instance.new("TextLabel");sub.BackgroundTransparency=1;sub.Position=UDim2.fromOffset(18,45);sub.Size=UDim2.new(1,-36,0,18);sub.Text="LIVE GOALKEEPER + SHOOTING SLIDERS";sub.TextColor3=Color3.fromHex("B7FF1A");sub.TextSize=11;sub.Font=Enum.Font.GothamBold;sub.TextXAlignment=Enum.TextXAlignment.Left;sub.Parent=panel
	local reset=Instance.new("TextButton");reset.Name="ResetShot";reset.BackgroundColor3=Color3.fromHex("B7FF1A");reset.BorderSizePixel=0;reset.Position=UDim2.fromOffset(18,73);reset.Size=UDim2.new(.5,-24,0,34);reset.Text="RESET SHOT";reset.TextColor3=Color3.fromHex("050705");reset.TextSize=14;reset.Font=Enum.Font.GothamBlack;reset.AutoButtonColor=true;reset.Parent=panel
	local resetCorner=Instance.new("UICorner");resetCorner.CornerRadius=UDim.new(0,6);resetCorner.Parent=reset
	table.insert(self.PracticeTuningConnections,self:_trackConnection(reset.Activated:Connect(function()self:_requestPracticeReset()end),"Input"))
	local output=Instance.new("TextButton");output.Name="OutputDefaults";output.BackgroundColor3=Color3.fromHex("1F271F");output.BorderSizePixel=0;output.Position=UDim2.new(.5,6,0,73);output.Size=UDim2.new(.5,-24,0,34);output.Text="OUTPUT";output.TextColor3=Color3.fromHex("B7FF1A");output.TextSize=14;output.Font=Enum.Font.GothamBlack;output.AutoButtonColor=true;output.Parent=panel
	local outputCorner=Instance.new("UICorner");outputCorner.CornerRadius=UDim.new(0,6);outputCorner.Parent=output
	local outputStroke=Instance.new("UIStroke");outputStroke.Color=Color3.fromHex("B7FF1A");outputStroke.Transparency=.45;outputStroke.Thickness=1;outputStroke.Parent=output
	local outputBox=Instance.new("TextBox");outputBox.Name="DefaultsOutput";outputBox.BackgroundColor3=Color3.fromHex("080A08");outputBox.BackgroundTransparency=.08;outputBox.BorderSizePixel=0;outputBox.ClearTextOnFocus=false;outputBox.MultiLine=true;outputBox.TextEditable=false;outputBox.TextWrapped=true;outputBox.TextXAlignment=Enum.TextXAlignment.Left;outputBox.TextYAlignment=Enum.TextYAlignment.Top;outputBox.Position=UDim2.fromOffset(18,115);outputBox.Size=UDim2.new(1,-36,0,58);outputBox.Text="OUTPUT CURRENT DEFAULTS HERE";outputBox.TextColor3=Color3.fromHex("D9D9D9");outputBox.TextSize=10;outputBox.Font=Enum.Font.Code;outputBox.Parent=panel
	local outputBoxCorner=Instance.new("UICorner");outputBoxCorner.CornerRadius=UDim.new(0,6);outputBoxCorner.Parent=outputBox
	table.insert(self.PracticeTuningConnections,self:_trackConnection(output.Activated:Connect(function()
		local text=formatPracticeDefaults(self.PracticeTuning)
		outputBox.Text=text
		print("[VTR SHOOTING PRACTICE DEFAULTS] "..text)
		if self.HUD then self.HUD:Flash("DEFAULTS OUTPUT",.75)end
	end),"Input"))
	local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(18,185);list.Size=UDim2.new(1,-36,1,-203);list.CanvasSize=UDim2.fromOffset(0,0);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.ScrollingDirection=Enum.ScrollingDirection.Y;list.ScrollBarThickness=5;list.ScrollBarImageColor3=Color3.fromHex("B7FF1A");list.Parent=panel
	local layout=Instance.new("UIListLayout");layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Padding=UDim.new(0,6);layout.Parent=list
	local keeperHeader=Instance.new("TextLabel");keeperHeader.BackgroundTransparency=1;keeperHeader.LayoutOrder=1;keeperHeader.Size=UDim2.new(1,0,0,21);keeperHeader.Text="GOALKEEPER";keeperHeader.TextColor3=Color3.fromHex("B7FF1A");keeperHeader.TextSize=13;keeperHeader.Font=Enum.Font.GothamBlack;keeperHeader.TextXAlignment=Enum.TextXAlignment.Left;keeperHeader.Parent=list
	for index,spec in KEEPER_TUNING do self:_addPracticeSlider(list,spec,self.PracticeTuning.Keeper,1+index)end
	local shootingHeader=Instance.new("TextLabel");shootingHeader.BackgroundTransparency=1;shootingHeader.LayoutOrder=8;shootingHeader.Size=UDim2.new(1,0,0,21);shootingHeader.Text="SHOOTING";shootingHeader.TextColor3=Color3.fromHex("B7FF1A");shootingHeader.TextSize=13;shootingHeader.Font=Enum.Font.GothamBlack;shootingHeader.TextXAlignment=Enum.TextXAlignment.Left;shootingHeader.Parent=list
	for index,spec in SHOOTING_TUNING do self:_addPracticeSlider(list,spec,self.PracticeTuning.Shooting,8+index)end
	self.PracticeTuningGui=gui
	self:_emitPracticeTuning(true)
end
function Controller:_destroyPracticeTuningPanel()
	if self.PracticeTuningConnections then for _,connection in self.PracticeTuningConnections do connection:Disconnect()end end
	self.PracticeTuningConnections=nil
	if self.PracticeTuningGui then self.PracticeTuningGui:Destroy();self.PracticeTuningGui=nil end
end
function Controller:_formatRuntimeTactics():string
	local function sideBlock(side:string):string
		local tactics=self.RuntimeTactics[side];local parts={}
		for _,spec in TACTIC_BEHAVIOR_CONTROLS do table.insert(parts,spec.Key.."="..tostring(math.floor(simpleTacticValue(tactics,spec.Key)+.5)))end
		return side.."={Formation=\""..tostring(tactics.Formation or"4-3-3").."\",Playstyle=\""..TACTIC_IDENTITIES[currentTacticIdentityIndex(tactics)].Label.."\",Settings={"..table.concat(parts,",").."}}"
	end
	return"RuntimeAITactics={"..sideBlock("Home")..","..sideBlock("Away").."}"
end
function Controller:_sendRuntimeTactics(side:string)
	if not self.TacticalDebugOptions or next(self.TacticalDebugOptions)==nil then self.TacticalDebugOptions=defaultTacticalDebugOptions()end
	if self.Action then self.Action:FireServer({Type="AITacticsDebug",Side=side,Tactics=self.RuntimeTactics[side],Debug=self.TacticalDebugOptions})end
end
function Controller:_findTeamModelByName(side:string,name:string):Model?
	if name==""or not self.TeamModels then return nil end
	for _,model in self.TeamModels[side]or{}do
		if model.Name==name or tostring(model:GetAttribute("DisplayName")or"")==name then return model end
	end
	for _,team in self.TeamModels do
		for _,model in team do
			if (model.Name==name or tostring(model:GetAttribute("DisplayName")or"")==name)and tostring(model:GetAttribute("VTRTeam")or"")==side then return model end
		end
	end
	return nil
end
function Controller:_teamModelsForSide(side:string):{Model}
	return self.TeamModels and self.TeamModels[side]or{}
end
function Controller:_teamDefensiveGameplanText(side:string):string
	local ownerSide=self.Ball and tostring(self.Ball:GetAttribute("VTRPossessionTeam")or"")or""
	local intent,phase,lineState="", "", ""
	local pressers,restDefense=0,0
	local layers={}
	for _,model in self:_teamModelsForSide(side)do
		intent=intent~=""and intent or tostring(model:GetAttribute("TeamDefensiveIntent")or"")
		phase=phase~=""and phase or tostring(model:GetAttribute("AIPressPhase")or model:GetAttribute("AIHighPressPhase")or"")
		lineState=lineState~=""and lineState or tostring(model:GetAttribute("AIDefensiveLineState")or"")
		pressers=math.max(pressers,tonumber(model:GetAttribute("AIPressersActive"))or 0)
		if model:GetAttribute("AIRestDefense")==true then restDefense+=1 end
		local layer=tostring(model:GetAttribute("AIPressLayer")or"")
		if layer~=""then layers[layer]=true end
	end
	local layerText={}
	for layer in pairs(layers)do table.insert(layerText,compactActionName(layer))end
	table.sort(layerText)
	if ownerSide==side then
		local rest=restDefense>0 and tostring(restDefense).." rest defenders"or"rest defense ready"
		return side.." Defense: Rest Shape, "..rest.." protecting counters while attack builds"
	end
	if intent==""then intent="Hold Shape"end
	if phase==""then phase="Observe"end
	if lineState==""then lineState="Compact Lines"end
	local laneText=#layerText>0 and table.concat(layerText,"/")or"carrier plus outlet lanes"
	return side.." Defense: "..compactActionName(intent)..", "..compactActionName(phase)..", "..tostring(pressers).." pressers covering "..laneText.." / "..compactActionName(lineState)
end
function Controller:_teamActionText(side:string):string
	local ownerName=self.Ball and tostring(self.Ball:GetAttribute("OwnerModel")or"")or""
	local ownerSide=self.Ball and tostring(self.Ball:GetAttribute("VTRPossessionTeam")or"")or""
	local owner=self:_findTeamModelByName(side,ownerName)
	if ownerSide==""and owner then ownerSide=tostring(owner:GetAttribute("VTRTeam")or"")end
	if owner then
		local action=compactActionName(owner:GetAttribute("AITeamAction")or owner:GetAttribute("currentAssignment")or owner:GetAttribute("AIAssignment"))
		local assignment=compactActionName(owner:GetAttribute("currentAssignment")or owner:GetAttribute("AIAssignment")or owner:GetAttribute("SupportRole")or owner:GetAttribute("AITacticalSlot")or owner:GetAttribute("AITeamContractPlanStep"))
		local reason=tostring(owner:GetAttribute("AITeamActionReason")or"")
		if reason==""then
			if owner:GetAttribute("AIForcePassPressure10")==true then reason="Close pressure inside 10 studs"
			elseif owner:GetAttribute("AIForwardSpace")==true then reason="Forward space is open"
			elseif owner:GetAttribute("AIForcedSafe")==true then reason="Safe option preferred by pressure/risk"
			elseif owner:GetAttribute("AIShotGood")==true then reason="Shot quality is available"
			else reason="Carrier is following current team assignment"end
		end
		return side..": "..action..", "..reason.."  /  Assignment: "..assignment
	end
	if ownerName~=""and ownerSide==side then
		return side..": In Possession, "..ownerName.." has the ball  /  Assignment: Tracking Carrier"
	elseif ownerName~=""and ownerSide~=""then
		return side..": Defending, opponent ball carrier has possession"
	end
	local motionKind=self.Ball and tostring(self.Ball:GetAttribute("VTRMotionKind")or"")or""
	local passReceiver=tostring(self.Ball and self.Ball:GetAttribute("VTRPassReceiver")or"")
	local passTeam=tostring(self.Ball and self.Ball:GetAttribute("VTRPassTeam")or"")
	local passTarget=self.Ball and self.Ball:GetAttribute("VTRPassTarget")or nil
	if motionKind=="Pass"and(passReceiver~=""or typeof(passTarget)=="Vector3")then
		if passTeam==side or passTeam==""then
			local targetName=passReceiver~=""and passReceiver or"nearest receiver"
			local receiver=self:_findTeamModelByName(side,passReceiver)
			local assignment=receiver and compactActionName(receiver:GetAttribute("currentAssignment")or receiver:GetAttribute("AIAssignment")or receiver:GetAttribute("SupportRole")or"ReceivePass")or"ReceivePass"
			return side..": Pass In Flight, Target "..targetName.." is adjusting to receive  /  Assignment: "..assignment
		end
		return side..": Defending Pass, opponent target "..(passReceiver~=""and passReceiver or"receiver").." is being pressed"
	end
	if ownerName==""then
		return side..": Loose Ball, nearest eligible players are reacting"
	end
	return side..": Tracking Possession, "..ownerName.." has the ball"
end
function Controller:_updateTacticalActionLabels(force:boolean?)
	if not self.TacticalActionLabels and not self.DefaultActionLabels then return end
	local now=os.clock()
	if force~=true and now-(tonumber(self.TacticalActionLabelAt)or 0)<.12 then return end
	self.TacticalActionLabelAt=now
	for _,side in{"Home","Away"}do
		local text=self:_teamActionText(side)
		local tacticalLabel=self.TacticalActionLabels and self.TacticalActionLabels[side]
		if tacticalLabel and tacticalLabel.Parent then
			tacticalLabel.Text=text
		end
		local defaultLabel=self.DefaultActionLabels and self.DefaultActionLabels[side]
		if defaultLabel and defaultLabel.Parent then
			defaultLabel.Text=text
		end
		local defenseText=self:_teamDefensiveGameplanText(side)
		local tacticalDefenseLabel=self.TacticalDefenseLabels and self.TacticalDefenseLabels[side]
		if tacticalDefenseLabel and tacticalDefenseLabel.Parent then
			tacticalDefenseLabel.Text=defenseText
		end
		local defaultDefenseLabel=self.DefaultDefenseLabels and self.DefaultDefenseLabels[side]
		if defaultDefenseLabel and defaultDefenseLabel.Parent then
			defaultDefenseLabel.Text=defenseText
		end
	end
end
function Controller:_teamModelsForSide(side:string): {Model}
	local teams=self.TeamModels
	if type(teams)~="table"then return{}end
	local direct=teams[side]
	if type(direct)=="table"then return direct end
	local found={}
	for _,group in teams do
		if type(group)=="table"then
			for _,model in group do
				if typeof(model)=="Instance"and model:IsA("Model")and tostring(model:GetAttribute("VTRTeam")or"")==side then
					table.insert(found,model)
				end
			end
		end
	end
	return found
end
function Controller:_sideForPlayerName(name:string): string?
	if name==""then return nil end
	for _,side in{"Home","Away"}do
		for _,model in self:_teamModelsForSide(side)do
			if model.Name==name then return side end
		end
	end
	return nil
end
function Controller:_analysisLine(side:string): string
	local models=self:_teamModelsForSide(side)
	local ownerName=tostring(self.Ball and self.Ball:GetAttribute("OwnerModel")or"")
	local ownerSide=self:_sideForPlayerName(ownerName)
	local motionKind=tostring(self.Ball and self.Ball:GetAttribute("VTRMotionKind")or"")
	local passTeam=tostring(self.Ball and self.Ball:GetAttribute("VTRPassTeam")or"")
	local passReceiver=tostring(self.Ball and self.Ball:GetAttribute("VTRPassReceiver")or"")
	local throughCount=0
	local receiveCount=0
	local pressCount=0
	local restCount=0
	local slotCounts={}
	for _,model in models do
		if model:GetAttribute("VTRThroughSpacePass")==true then throughCount+=1 end
		if model:GetAttribute("VTRReceivePassFamily")~=nil or model:GetAttribute("VTRReceiveTarget")~=nil then receiveCount+=1 end
		local assignment=tostring(model:GetAttribute("currentAssignment")or model:GetAttribute("AIAssignment")or"")
		if string.find(string.lower(assignment),"press",1,true)then pressCount+=1 end
		if model:GetAttribute("AIRestDefense")==true or string.find(string.lower(assignment),"rest",1,true)then restCount+=1 end
		local slot=tostring(model:GetAttribute("AITacticalSlot")or model:GetAttribute("SupportRole")or model:GetAttribute("position")or"")
		if slot~=""then slotCounts[slot]=(slotCounts[slot]or 0)+1 end
	end
	local strongestSlot,slotTotal="",0
	for slot,total in slotCounts do
		if total>slotTotal then strongestSlot,slotTotal=slot,total end
	end
	local teamState
	if motionKind=="Pass"and(passTeam==side or passTeam=="")and passReceiver~=""then
		teamState="pass target "..passReceiver
	elseif ownerSide==side then
		teamState="in possession"
	elseif ownerSide and ownerSide~=side then
		teamState="defending block"
	elseif motionKind=="Shot"then
		teamState="shot reaction"
	else
		teamState="loose ball race"
	end
	return string.format("%s  |  recv %d  through %d  press %d  rest %d  lane %s",teamState,receiveCount,throughCount,pressCount,restCount,strongestSlot~=""and strongestSlot or"balanced")
end
function Controller:_createAnalysisBoard()
	if not self.HUD or not self.HUD.Gui then return end
	local old=self.HUD.Gui:FindFirstChild("AIAnalysisBoard");if old then old:Destroy()end
	local board=Instance.new("Frame");board.Name="AIAnalysisBoard";board.AnchorPoint=Vector2.new(1,.5);board.BackgroundColor3=Color3.fromHex("050907");board.BackgroundTransparency=.08;board.BorderSizePixel=0;board.Position=UDim2.new(1,-18,.5,10);board.Size=UDim2.fromOffset(340,292);board.ZIndex=172;board.Parent=self.HUD.Gui;self:_trackTemporary(board);self.AnalysisBoard=board
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=board
	local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("55E6FF");stroke.Thickness=1;stroke.Transparency=.24;stroke.Parent=board
	local glow=Instance.new("UIStroke");glow.Color=Color3.fromHex("B7FF1A");glow.Thickness=3;glow.Transparency=.82;glow.Parent=board
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(16,12);title.Size=UDim2.new(1,-32,0,26);title.Text="ANALYSIS BOARD";title.TextColor3=Color3.fromHex("EFFFFF");title.TextSize=18;title.Font=Enum.Font.GothamBlack;title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=173;title.Parent=board
	local subtitle=Instance.new("TextLabel");subtitle.BackgroundTransparency=1;subtitle.Position=UDim2.fromOffset(16,39);subtitle.Size=UDim2.new(1,-32,0,18);subtitle.Text="live team shape, pass routes, pressure";subtitle.TextColor3=Color3.fromHex("8FEAFF");subtitle.TextSize=10;subtitle.Font=Enum.Font.GothamBold;subtitle.TextXAlignment=Enum.TextXAlignment.Left;subtitle.ZIndex=173;subtitle.Parent=board
	self.AnalysisLabels={}
	local rows={{"Ball","Ball"},{"Home","Home"},{"Away","Away"},{"Press","Press"},{"Lines","Lines"},{"Through","Through"}}
	for index,row in ipairs(rows)do
		local y=66+(index-1)*34
		local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(16,y);label.Size=UDim2.fromOffset(68,24);label.Text=string.upper(row[1]);label.TextColor3=Color3.fromHex("B7FF1A");label.TextSize=10;label.Font=Enum.Font.GothamBlack;label.TextXAlignment=Enum.TextXAlignment.Left;label.ZIndex=173;label.Parent=board
		local value=Instance.new("TextLabel");value.BackgroundColor3=Color3.fromHex("101612");value.BackgroundTransparency=.18;value.BorderSizePixel=0;value.Position=UDim2.fromOffset(86,y-2);value.Size=UDim2.new(1,-102,0,28);value.Text="reading...";value.TextColor3=Color3.fromHex("F6FFF8");value.TextSize=10;value.Font=Enum.Font.Code;value.TextXAlignment=Enum.TextXAlignment.Left;value.TextTruncate=Enum.TextTruncate.AtEnd;value.ZIndex=173;value.Parent=board;self.AnalysisLabels[row[2]]=value
		local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,8);pad.Parent=value
	end
	self:_updateAnalysisBoard(true)
end
function Controller:_updateAnalysisBoard(force:boolean?)
	if not self.AnalysisLabels then return end
	local now=os.clock()
	if force~=true and now-(tonumber(self.AnalysisBoardUpdatedAt)or 0)<.18 then return end
	self.AnalysisBoardUpdatedAt=now
	local ownerName=tostring(self.Ball and self.Ball:GetAttribute("OwnerModel")or"")
	local motionKind=tostring(self.Ball and self.Ball:GetAttribute("VTRMotionKind")or"")
	local passReceiver=tostring(self.Ball and self.Ball:GetAttribute("VTRPassReceiver")or"")
	local passTeam=tostring(self.Ball and self.Ball:GetAttribute("VTRPassTeam")or"")
	local ballText=ownerName~=""and("owned by "..ownerName)or(motionKind=="Pass"and passReceiver~=""and("pass "..passTeam.." -> "..passReceiver)or(motionKind~=""and motionKind or"free"))
	local homeLineGap=tonumber(workspace:GetAttribute("VTRAIMetricHomeBackMidGap")or workspace:GetAttribute("VTRHomeBackMidGap")or 0)or 0
	local awayLineGap=tonumber(workspace:GetAttribute("VTRAIMetricAwayBackMidGap")or workspace:GetAttribute("VTRAwayBackMidGap")or 0)or 0
	local homeWidth=tonumber(workspace:GetAttribute("VTRAIMetricHomeBlockWidthVariance")or workspace:GetAttribute("VTRHomeBlockWidthVariance")or 0)or 0
	local awayWidth=tonumber(workspace:GetAttribute("VTRAIMetricAwayBlockWidthVariance")or workspace:GetAttribute("VTRAwayBlockWidthVariance")or 0)or 0
	local throughText=passReceiver~=""and("route locked to "..passReceiver)or"scan forward runners"
	for _,side in{"Home","Away"}do
		for _,model in self:_teamModelsForSide(side)do
			if model:GetAttribute("VTRThroughSpacePass")==true then
				throughText=side.." through space +"..tostring(math.floor(tonumber(model:GetAttribute("VTRThroughSpaceAhead"))or 0)).." studs"
				break
			end
		end
	end
	if self.AnalysisLabels.Ball then self.AnalysisLabels.Ball.Text=ballText end
	if self.AnalysisLabels.Home then self.AnalysisLabels.Home.Text=self:_analysisLine("Home")end
	if self.AnalysisLabels.Away then self.AnalysisLabels.Away.Text=self:_analysisLine("Away")end
	if self.AnalysisLabels.Press then self.AnalysisLabels.Press.Text="1-2 pressers, lanes stay covered"end
	if self.AnalysisLabels.Lines then self.AnalysisLabels.Lines.Text=string.format("gaps H %.0f / A %.0f  width %.0f / %.0f",homeLineGap,awayLineGap,homeWidth,awayWidth)end
	if self.AnalysisLabels.Through then self.AnalysisLabels.Through.Text=throughText end
end
function Controller:_createDefaultActionReadout()
	if not self.HUD or not self.HUD.Gui then return end
	local old=self.HUD.Gui:FindFirstChild("AIDefaultActionReadout");if old then old:Destroy()end
	local box=Instance.new("Frame");box.Name="AIDefaultActionReadout";box.AnchorPoint=Vector2.new(.5,0);box.BackgroundColor3=Color3.fromHex("050805");box.BackgroundTransparency=.1;box.BorderSizePixel=0;box.Position=UDim2.new(.5,0,0,106);box.Size=UDim2.fromOffset(1060,120);box.ZIndex=170;box.Parent=self.HUD.Gui;self:_trackTemporary(box)
	local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("B7FF1A");stroke.Thickness=1;stroke.Transparency=.35;stroke.Parent=box
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(14,6);title.Size=UDim2.new(1,-28,0,18);title.Text="TEAM ACTION";title.TextColor3=Color3.fromHex("B7FF1A");title.TextSize=12;title.Font=Enum.Font.GothamBlack;title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=171;title.Parent=box
	self.DefaultActionLabels={}
	self.DefaultDefenseLabels={}
	for index,side in{"Home","Away"}do
		local actionRow=Instance.new("TextLabel");actionRow.BackgroundTransparency=1;actionRow.Position=UDim2.fromOffset(14,25+(index-1)*45);actionRow.Size=UDim2.new(1,-28,0,20);actionRow.Text=side..": Observe, waiting for match state";actionRow.TextColor3=side=="Home"and Color3.fromHex("64A7FF")or Color3.fromHex("FF594D");actionRow.TextSize=13;actionRow.Font=Enum.Font.Code;actionRow.TextXAlignment=Enum.TextXAlignment.Left;actionRow.TextTruncate=Enum.TextTruncate.AtEnd;actionRow.ZIndex=171;actionRow.Parent=box;self.DefaultActionLabels[side]=actionRow
		local defenseRow=Instance.new("TextLabel");defenseRow.BackgroundTransparency=1;defenseRow.Position=UDim2.fromOffset(14,45+(index-1)*45);defenseRow.Size=UDim2.new(1,-28,0,20);defenseRow.Text=side.." Defense: Observe";defenseRow.TextColor3=Color3.fromHex("CFE8C0");defenseRow.TextSize=12;defenseRow.Font=Enum.Font.Code;defenseRow.TextXAlignment=Enum.TextXAlignment.Left;defenseRow.TextTruncate=Enum.TextTruncate.AtEnd;defenseRow.ZIndex=171;defenseRow.Parent=box;self.DefaultDefenseLabels[side]=defenseRow
	end
	self:_updateTacticalActionLabels(true)
end
function Controller:_toggleTacticalMode()
	return
end
function Controller:_createTacticalPanel()
	if not self.HUD or not self.HUD.Gui then return end
	local old=self.HUD.Gui:FindFirstChild("AITacticalTuner");if old then old:Destroy()end
	local overlay=Instance.new("Frame");overlay.Name="AITacticalTuner";overlay.BackgroundTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.Visible=self.TacticalMode==true;overlay.ZIndex=180;overlay.Parent=self.HUD.Gui;self:_trackTemporary(overlay);self.TacticalOverlay=overlay
	local hint=Instance.new("TextLabel");hint.BackgroundColor3=Color3.fromHex("0A0D08");hint.BackgroundTransparency=.12;hint.BorderSizePixel=0;hint.Position=UDim2.fromOffset(18,72);hint.Size=UDim2.fromOffset(620,34);hint.Text="AI BEHAVIOR LAB  /  8 TOGGLE  /  WASD PAN  /  R-F ZOOM";hint.TextColor3=Color3.fromHex("B7FF1A");hint.TextSize=13;hint.Font=Enum.Font.GothamBlack;hint.TextXAlignment=Enum.TextXAlignment.Left;hint.ZIndex=181;hint.Parent=overlay;local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,14);pad.Parent=hint
	local toggle=Instance.new("TextButton");toggle.AnchorPoint=Vector2.new(1,0);toggle.BackgroundColor3=Color3.fromHex("FFFFFF");toggle.BorderSizePixel=0;toggle.Position=UDim2.new(1,-18,0,72);toggle.Size=UDim2.fromOffset(118,34);toggle.Text=self.TacticalPanelOpen and"HIDE"or"SHOW";toggle.TextColor3=Color3.fromHex("111111");toggle.TextSize=13;toggle.Font=Enum.Font.GothamBlack;toggle.ZIndex=184;toggle.Parent=overlay
	local panel=Instance.new("Frame");panel.AnchorPoint=Vector2.new(1,.5);panel.BackgroundColor3=Color3.fromHex("070A06");panel.BackgroundTransparency=.06;panel.BorderSizePixel=0;panel.Position=UDim2.new(1,-18,.5,20);panel.Size=UDim2.new(.54,0,.9,0);panel.Visible=self.TacticalPanelOpen==true;panel.ZIndex=182;panel.Parent=overlay;self.TacticalPanel=panel;local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("FFFFFF");stroke.Thickness=1;stroke.Transparency=.25;stroke.Parent=panel
	self:_trackConnection(toggle.Activated:Connect(function()self.TacticalPanelOpen=not self.TacticalPanelOpen;panel.Visible=self.TacticalPanelOpen;toggle.Text=self.TacticalPanelOpen and"HIDE"or"SHOW"end),"Input")
	self:_renderTacticalPanel()
end
function Controller:_renderTacticalPanel()
	local panel=self.TacticalPanel;if not panel then return end
	for _,child in panel:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(22,16);title.Size=UDim2.new(1,-44,0,30);title.Text="LIVE AI";title.TextColor3=Color3.new(1,1,1);title.TextSize=24;title.Font=Enum.Font.GothamBlack;title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=183;title.Parent=panel
	local status=Instance.new("TextLabel");status.BackgroundTransparency=1;status.Position=UDim2.fromOffset(22,48);status.Size=UDim2.new(1,-44,0,20);status.Text=self.TacticalSide.." SELECTED";status.TextColor3=Color3.fromHex("B7FF1A");status.TextSize=11;status.Font=Enum.Font.GothamBold;status.TextXAlignment=Enum.TextXAlignment.Left;status.ZIndex=183;status.Parent=panel;self.TacticalStatus=status
	for index,side in ipairs({"Home","Away"})do local tab=Instance.new("TextButton");tab.BackgroundColor3=side==self.TacticalSide and Color3.fromHex("FFFFFF")or Color3.fromHex("1B2118");tab.BorderSizePixel=0;tab.Position=UDim2.fromOffset(22+(index-1)*118,78);tab.Size=UDim2.fromOffset(108,34);tab.Text=string.upper(side);tab.TextColor3=side==self.TacticalSide and Color3.fromHex("111111")or Color3.fromHex("F5F7F2");tab.TextSize=13;tab.Font=Enum.Font.GothamBlack;tab.ZIndex=184;tab.Parent=panel;self:_trackConnection(tab.Activated:Connect(function()self.TacticalSide=side;self:_renderTacticalPanel()end),"Input")end
	local output=Instance.new("TextButton");output.BackgroundColor3=Color3.fromHex("2A351F");output.BorderSizePixel=0;output.Position=UDim2.new(1,-132,0,78);output.Size=UDim2.fromOffset(110,34);output.Text="OUTPUT";output.TextColor3=Color3.fromHex("FFFFFF");output.TextSize=13;output.Font=Enum.Font.GothamBlack;output.ZIndex=184;output.Parent=panel
	local box=Instance.new("TextBox");box.BackgroundColor3=Color3.fromHex("10140E");box.BackgroundTransparency=.1;box.BorderSizePixel=0;box.ClearTextOnFocus=false;box.MultiLine=true;box.Position=UDim2.fromOffset(22,124);box.Size=UDim2.new(1,-44,0,58);box.Text=gameplanSummary(self.RuntimeTactics[self.TacticalSide]);box.TextColor3=Color3.fromHex("D9D9D9");box.TextSize=10;box.Font=Enum.Font.Code;box.TextXAlignment=Enum.TextXAlignment.Left;box.TextYAlignment=Enum.TextYAlignment.Top;box.ZIndex=184;box.Parent=panel;self.TacticalOutput=box
	self:_trackConnection(output.Activated:Connect(function()local text=self:_formatRuntimeTactics();print("[VTR AI TUNER] "..text);box.Text=text;status.Text="OUTPUT PRINTED BELOW"end),"Input")
	local actionBox=Instance.new("Frame");actionBox.BackgroundColor3=Color3.fromHex("10140E");actionBox.BackgroundTransparency=.08;actionBox.BorderSizePixel=0;actionBox.Position=UDim2.fromOffset(22,194);actionBox.Size=UDim2.new(1,-44,0,104);actionBox.ZIndex=184;actionBox.Parent=panel
	local actionStroke=Instance.new("UIStroke");actionStroke.Color=Color3.fromHex("B7FF1A");actionStroke.Thickness=1;actionStroke.Transparency=.55;actionStroke.Parent=actionBox
	self.TacticalActionLabels={}
	self.TacticalDefenseLabels={}
	for index,side in{"Home","Away"}do
		local row=Instance.new("TextLabel");row.BackgroundTransparency=1;row.Position=UDim2.fromOffset(12,6+(index-1)*48);row.Size=UDim2.new(1,-24,0,21);row.Text=side..": Observe, waiting for match state";row.TextColor3=side=="Home"and Color3.fromHex("64A7FF")or Color3.fromHex("FF594D");row.TextSize=11;row.Font=Enum.Font.Code;row.TextXAlignment=Enum.TextXAlignment.Left;row.TextTruncate=Enum.TextTruncate.AtEnd;row.ZIndex=185;row.Parent=actionBox;self.TacticalActionLabels[side]=row
		local defense=Instance.new("TextLabel");defense.BackgroundTransparency=1;defense.Position=UDim2.fromOffset(12,27+(index-1)*48);defense.Size=UDim2.new(1,-24,0,21);defense.Text=side.." Defense: Observe";defense.TextColor3=Color3.fromHex("CFE8C0");defense.TextSize=10;defense.Font=Enum.Font.Code;defense.TextXAlignment=Enum.TextXAlignment.Left;defense.TextTruncate=Enum.TextTruncate.AtEnd;defense.ZIndex=185;defense.Parent=actionBox;self.TacticalDefenseLabels[side]=defense
	end
	self:_updateTacticalActionLabels(true)
	local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(22,312);list.Size=UDim2.new(1,-44,1,-330);list.CanvasSize=UDim2.new();list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.ScrollBarThickness=8;list.ScrollBarImageColor3=Color3.fromHex("B7FF1A");list.ZIndex=183;list.Parent=panel
	do
		local y=0
		local function header(title:string)
			local item=Instance.new("TextLabel");item.BackgroundTransparency=1;item.Position=UDim2.fromOffset(0,y);item.Size=UDim2.new(1,-10,0,22);item.Text=title;item.TextColor3=Color3.fromHex("B7FF1A");item.TextSize=11;item.Font=Enum.Font.GothamBlack;item.TextXAlignment=Enum.TextXAlignment.Left;item.ZIndex=185;item.Parent=list;y+=26
		end
		local function cycleRow(labelText:string,valueText:string,onPrev:()->(),onNext:()->())
			local row=Instance.new("Frame");row.BackgroundTransparency=1;row.Position=UDim2.fromOffset(0,y);row.Size=UDim2.new(1,-10,0,50);row.ZIndex=184;row.Parent=list
			local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(0,4);label.Size=UDim2.new(.36,0,0,20);label.Text=labelText;label.TextColor3=Color3.fromHex("E8E8E8");label.TextSize=12;label.Font=Enum.Font.GothamBold;label.TextXAlignment=Enum.TextXAlignment.Left;label.ZIndex=185;label.Parent=row
			local value=Instance.new("TextLabel");value.BackgroundColor3=Color3.fromHex("10140E");value.BackgroundTransparency=.05;value.BorderSizePixel=0;value.Position=UDim2.new(.36,8,0,4);value.Size=UDim2.new(1,-174,0,34);value.Text=valueText;value.TextColor3=Color3.fromHex("FFFFFF");value.TextSize=13;value.Font=Enum.Font.GothamBlack;value.TextXAlignment=Enum.TextXAlignment.Center;value.ZIndex=185;value.Parent=row
			local prev=Instance.new("TextButton");prev.BackgroundColor3=Color3.fromHex("1B2118");prev.BorderSizePixel=0;prev.Position=UDim2.new(1,-104,0,6);prev.Size=UDim2.fromOffset(42,30);prev.Text="<";prev.TextColor3=Color3.new(1,1,1);prev.TextSize=18;prev.Font=Enum.Font.GothamBlack;prev.ZIndex=186;prev.Parent=row;self:_trackConnection(prev.Activated:Connect(onPrev),"Input")
			local next=Instance.new("TextButton");next.BackgroundColor3=Color3.fromHex("1B2118");next.BorderSizePixel=0;next.Position=UDim2.new(1,-50,0,6);next.Size=UDim2.fromOffset(42,30);next.Text=">";next.TextColor3=Color3.new(1,1,1);next.TextSize=18;next.Font=Enum.Font.GothamBlack;next.ZIndex=186;next.Parent=row;self:_trackConnection(next.Activated:Connect(onNext),"Input")
			y+=54
		end
		local tactics=self.RuntimeTactics[self.TacticalSide];tactics.Sliders=tactics.Sliders or{};tactics.MetricsTargets=tactics.MetricsTargets or{}
		header("TACTICS")
		local formationIndex=table.find(TACTIC_FORMATIONS,tostring(tactics.Formation or""))or 1
		cycleRow("FORMATION",TACTIC_FORMATIONS[formationIndex],function()tactics.Formation=TACTIC_FORMATIONS[((formationIndex-2)%#TACTIC_FORMATIONS)+1];self:_sendRuntimeTactics(self.TacticalSide);self:_renderTacticalPanel()end,function()tactics.Formation=TACTIC_FORMATIONS[(formationIndex%#TACTIC_FORMATIONS)+1];self:_sendRuntimeTactics(self.TacticalSide);self:_renderTacticalPanel()end)
		local identityIndex=currentTacticIdentityIndex(tactics)
		local identity=TACTIC_IDENTITIES[identityIndex]
		cycleRow("AI IDENTITY",identity.Label.." ("..identity.Name..")",function()applyTacticIdentity(tactics,identityIndex-1);self:_sendRuntimeTactics(self.TacticalSide);self:_renderTacticalPanel()end,function()applyTacticIdentity(tactics,identityIndex+1);self:_sendRuntimeTactics(self.TacticalSide);self:_renderTacticalPanel()end)
		header("BEHAVIOUR SETTINGS")
		for _,spec in TACTIC_BEHAVIOR_CONTROLS do
			local value=math.floor(simpleTacticValue(tactics,spec.Key)+.5)
			local row=Instance.new("Frame");row.BackgroundTransparency=1;row.Position=UDim2.fromOffset(0,y);row.Size=UDim2.new(1,-10,0,spec.Key=="DefensiveLineReach"and 68 or 52);row.ZIndex=184;row.Parent=list
			local group=spec.Group or"Shape"
			local check=Instance.new("TextButton");check.BackgroundColor3=self.TacticalDebugOptions[group]and Color3.fromHex("B7FF1A")or Color3.fromHex("171D14");check.BorderSizePixel=0;check.Position=UDim2.fromOffset(0,11);check.Size=UDim2.fromOffset(44,30);check.Text=self.TacticalDebugOptions[group]and"ON"or"";check.TextColor3=Color3.fromHex("111111");check.TextSize=12;check.Font=Enum.Font.GothamBlack;check.ZIndex=186;check.Parent=row
			local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(56,3);label.Size=UDim2.new(1,-238,0,20);label.Text=spec.Label;label.TextColor3=Color3.fromHex("E8E8E8");label.TextSize=12;label.Font=Enum.Font.GothamBold;label.TextXAlignment=Enum.TextXAlignment.Left;label.ZIndex=185;label.Parent=row
			local sub=Instance.new("TextLabel");sub.BackgroundTransparency=1;sub.Position=UDim2.fromOffset(56,25);sub.Size=UDim2.fromOffset(172,16);sub.Text=spec.Low.." / "..spec.High;sub.TextColor3=Color3.fromHex("7F8D73");sub.TextSize=9;sub.Font=Enum.Font.GothamBold;sub.TextXAlignment=Enum.TextXAlignment.Left;sub.ZIndex=185;sub.Parent=row
			local bar=Instance.new("Frame");bar.BackgroundColor3=Color3.fromHex("20251C");bar.BorderSizePixel=0;bar.Position=UDim2.fromOffset(226,31);bar.Size=UDim2.new(1,-416,0,8);bar.ZIndex=185;bar.Parent=row;local fill=Instance.new("Frame");fill.BackgroundColor3=Color3.fromHex("B7FF1A");fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(value/100,1);fill.ZIndex=186;fill.Parent=bar
			if spec.Key=="DefensiveLineReach"then local reach=math.floor(value*.32+4+.5);local line=Instance.new("Frame");line.BackgroundColor3=Color3.fromHex("2A351F");line.BorderSizePixel=0;line.Position=UDim2.fromOffset(226,48);line.Size=UDim2.new(1,-416,0,8);line.ZIndex=185;line.Parent=row;local half=Instance.new("Frame");half.BackgroundColor3=Color3.fromHex("FFFFFF");half.BorderSizePixel=0;half.Position=UDim2.fromScale(.5,0);half.Size=UDim2.fromOffset(2,8);half.ZIndex=186;half.Parent=line;local reachFill=Instance.new("Frame");reachFill.BackgroundColor3=Color3.fromHex("64A7FF");reachFill.BorderSizePixel=0;reachFill.Position=UDim2.fromScale(.5,0);reachFill.Size=UDim2.fromScale(math.clamp(reach/36,.02,.5),1);reachFill.ZIndex=186;reachFill.Parent=line;sub.Text="Halfway +"..tostring(reach).." studs max line reach"end
			local number=Instance.new("TextLabel");number.BackgroundTransparency=1;number.Position=UDim2.new(1,-154,0,11);number.Size=UDim2.fromOffset(44,30);number.Text=tostring(value);number.TextColor3=Color3.fromHex("FFFFFF");number.TextSize=14;number.Font=Enum.Font.GothamBlack;number.ZIndex=186;number.Parent=row
			local function bump(amount:number)
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)then amount*=2 end
				local nextValue=math.clamp(simpleTacticValue(tactics,spec.Key)+amount,0,100)
				setSimpleTacticControl(tactics,spec.Key,nextValue)
				number.Text=tostring(math.floor(nextValue+.5));fill.Size=UDim2.fromScale(nextValue/100,1)
				if self.TacticalOutput then self.TacticalOutput.Text=gameplanSummary(tactics)end
				self:_sendRuntimeTactics(self.TacticalSide)
				if self.TacticalStatus then self.TacticalStatus.Text=spec.Label.." = "..tostring(math.floor(nextValue+.5))end
				if spec.Key=="DefensiveLineReach"then self:_renderTacticalPanel()end
			end
			local minus=Instance.new("TextButton");minus.BackgroundColor3=Color3.fromHex("1B2118");minus.BorderSizePixel=0;minus.Position=UDim2.new(1,-104,0,11);minus.Size=UDim2.fromOffset(42,30);minus.Text="-";minus.TextColor3=Color3.new(1,1,1);minus.TextSize=18;minus.Font=Enum.Font.GothamBlack;minus.ZIndex=186;minus.Parent=row;self:_trackConnection(minus.Activated:Connect(function()bump(-5)end),"Input")
			local plus=Instance.new("TextButton");plus.BackgroundColor3=Color3.fromHex("1B2118");plus.BorderSizePixel=0;plus.Position=UDim2.new(1,-50,0,11);plus.Size=UDim2.fromOffset(42,30);plus.Text="+";plus.TextColor3=Color3.new(1,1,1);plus.TextSize=18;plus.Font=Enum.Font.GothamBlack;plus.ZIndex=186;plus.Parent=row;self:_trackConnection(plus.Activated:Connect(function()bump(5)end),"Input")
			self:_trackConnection(check.Activated:Connect(function()self.TacticalDebugOptions[group]=true;self:_sendRuntimeTactics(self.TacticalSide);self:_renderTacticalPanel()end),"Input")
			y+=spec.Key=="DefensiveLineReach"and 72 or 56
		end
		return
	end
	local y=0
	local sectionFor={BuildUpSpeed="ATTACK",PassTempo="ATTACK",PassingDirectness="ATTACK",RunsInBehind="ATTACK",PressingIntensity="DEFENSE",DefensiveDepth="DEFENSE",BackLineCompactness="DEFENSE",LaneBlocking="DEFENSE",SupportDistance="POSITIONING",WidthDiscipline="POSITIONING"}
	local lastSection=""
	for _,name in TACTIC_LAB_SLIDERS do
		local section=sectionFor[name]or"TACTICS"
		if section~=lastSection then
			local header=Instance.new("TextLabel");header.BackgroundTransparency=1;header.Position=UDim2.fromOffset(0,y);header.Size=UDim2.new(1,-10,0,22);header.Text=section;header.TextColor3=Color3.fromHex("B7FF1A");header.TextSize=11;header.Font=Enum.Font.GothamBlack;header.TextXAlignment=Enum.TextXAlignment.Left;header.ZIndex=185;header.Parent=list
			y+=26
			lastSection=section
		end
		local tactics=self.RuntimeTactics[self.TacticalSide];tactics.Sliders[name]=tonumber(tactics.Sliders[name])or 50;local value=math.floor(tactics.Sliders[name])
		local row=Instance.new("Frame");row.BackgroundTransparency=1;row.Position=UDim2.fromOffset(0,y);row.Size=UDim2.new(1,-10,0,52);row.ZIndex=184;row.Parent=list
		local group=TACTIC_DEBUG_GROUPS[name]or"Shape"
		local check=Instance.new("TextButton");check.BackgroundColor3=self.TacticalDebugOptions[group]and Color3.fromHex("B7FF1A")or Color3.fromHex("171D14");check.BorderSizePixel=0;check.Position=UDim2.fromOffset(0,5);check.Size=UDim2.fromOffset(22,20);check.Text=self.TacticalDebugOptions[group]and"✓"or"";check.TextColor3=Color3.fromHex("111111");check.TextSize=13;check.Font=Enum.Font.GothamBlack;check.ZIndex=186;check.Parent=row
		check.Position=UDim2.fromOffset(0,11);check.Size=UDim2.fromOffset(44,30);check.Text=self.TacticalDebugOptions[group]and"ON"or"";check.TextSize=12
		local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(56,3);label.Size=UDim2.new(1,-238,0,20);label.Text=string.upper(name:gsub("(%u)"," %1"));label.TextColor3=Color3.fromHex("E8E8E8");label.TextSize=12;label.Font=Enum.Font.GothamBold;label.TextXAlignment=Enum.TextXAlignment.Left;label.ZIndex=185;label.Parent=row
		local groupLabel=Instance.new("TextLabel");groupLabel.BackgroundTransparency=1;groupLabel.Position=UDim2.fromOffset(56,25);groupLabel.Size=UDim2.fromOffset(92,16);groupLabel.Text=string.upper(group);groupLabel.TextColor3=Color3.fromHex("7F8D73");groupLabel.TextSize=9;groupLabel.Font=Enum.Font.GothamBold;groupLabel.TextXAlignment=Enum.TextXAlignment.Left;groupLabel.ZIndex=185;groupLabel.Parent=row
		local bar=Instance.new("Frame");bar.BackgroundColor3=Color3.fromHex("20251C");bar.BorderSizePixel=0;bar.Position=UDim2.fromOffset(158,31);bar.Size=UDim2.new(1,-348,0,8);bar.ZIndex=185;bar.Parent=row;local fill=Instance.new("Frame");fill.BackgroundColor3=Color3.fromHex("B7FF1A");fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(value/100,1);fill.ZIndex=186;fill.Parent=bar
		local number=Instance.new("TextLabel");number.BackgroundTransparency=1;number.Position=UDim2.new(1,-154,0,11);number.Size=UDim2.fromOffset(44,30);number.Text=tostring(value);number.TextColor3=Color3.fromHex("FFFFFF");number.TextSize=14;number.Font=Enum.Font.GothamBlack;number.ZIndex=186;number.Parent=row
		local function bump(amount:number)
			local current=tonumber(tactics.Sliders[name])or 50
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)then amount*=2 end
			local nextValue=math.clamp(current+amount,0,100)
			tactics.Sliders[name]=nextValue
			number.Text=tostring(math.floor(nextValue))
			fill.Size=UDim2.fromScale(nextValue/100,1)
			if self.TacticalOutput then self.TacticalOutput.Text=gameplanSummary(tactics)end
			self:_sendRuntimeTactics(self.TacticalSide)
			if self.TacticalStatus then self.TacticalStatus.Text=string.upper(name).." = "..tostring(math.floor(nextValue))end
		end
		local minus=Instance.new("TextButton");minus.BackgroundColor3=Color3.fromHex("1B2118");minus.BorderSizePixel=0;minus.Position=UDim2.new(1,-104,0,11);minus.Size=UDim2.fromOffset(42,30);minus.Text="-";minus.TextColor3=Color3.new(1,1,1);minus.TextSize=18;minus.Font=Enum.Font.GothamBlack;minus.ZIndex=186;minus.Parent=row;self:_trackConnection(minus.Activated:Connect(function()bump(-5)end),"Input")
		local plus=Instance.new("TextButton");plus.BackgroundColor3=Color3.fromHex("1B2118");plus.BorderSizePixel=0;plus.Position=UDim2.new(1,-50,0,11);plus.Size=UDim2.fromOffset(42,30);plus.Text="+";plus.TextColor3=Color3.new(1,1,1);plus.TextSize=18;plus.Font=Enum.Font.GothamBlack;plus.ZIndex=186;plus.Parent=row;self:_trackConnection(plus.Activated:Connect(function()bump(5)end),"Input")
		self:_trackConnection(check.Activated:Connect(function()
			self.TacticalDebugOptions[group]=true
			self:_sendRuntimeTactics(self.TacticalSide)
			self:_renderTacticalPanel()
		end),"Input")
		y+=56
	end
end
function Controller:_activate(data:any)
	MatchVisualCleanupService.Apply(workspace:FindFirstChild(tostring(data.WorldName or"")))
	local activationKey=matchStartKey(data)
	if self.Active and self.MatchStartKey==activationKey then
		if self.ActivatingMatchKey==activationKey then self.ActivatingMatchKey=nil end
		return
	end
	if self.MatchActivationRunningKey==activationKey then return end
	self.MatchActivationRunningKey=activationKey
	self.ActivatingMatchKey=activationKey
	if self.Active then self:_cleanup(false);self.MatchActivationRunningKey=activationKey;self.ActivatingMatchKey=activationKey end;local player=Players.LocalPlayer;local ball=data.Ball;local active=data.ActivePlayer
	local started=os.clock()
	while os.clock()-started<8 and (not ball or not ball.Parent or not active or not active.Parent)do
		local world=workspace:FindFirstChild(tostring(data.WorldName or ""))
		if not ball or not ball.Parent then ball=world and world:FindFirstChild(Config.Ball.Name,true)or data.Ball end
		if not active or not active.Parent then active=data.ActivePlayer end
		if (not active or not active.Parent)and world and type(data.ActivePlayerName)=="string"then
			local found=world:FindFirstChild(data.ActivePlayerName,true)
			if found and found:IsA("Model")then active=found end
		end
		task.wait(.1)
	end
	if not ball or not ball.Parent or not active or not active.Parent then if self.ActivatingMatchKey==activationKey then self.ActivatingMatchKey=nil end;if self.MatchActivationRunningKey==activationKey then self.MatchActivationRunningKey=nil end;return end
	setMenuVisible(false)
	player:SetAttribute("VTRInMatch", true)
	if self.Lifecycle then self.Lifecycle:Destroy()end
	self.Lifecycle=MatchLifecycleController.new("VTRMatchGameplay")
	local bootCover = Instance.new("ScreenGui")
	bootCover.Name = "VTRMatchBootCover"
	bootCover.IgnoreGuiInset = true
	bootCover.ResetOnSpawn = false
	bootCover.DisplayOrder = 2200
	bootCover.Parent = player:WaitForChild("PlayerGui")
	self:_trackTemporary(bootCover)
	local bootFrame = Instance.new("Frame")
	bootFrame.BackgroundColor3 = Color3.fromHex("020402")
	bootFrame.BorderSizePixel = 0
	bootFrame.Size = UDim2.fromScale(1, 1)
	bootFrame.Parent = bootCover
	self:_spawnMatchTask(function(isCancelled)
		if data.PracticeMode==true or data.NoPrematch==true then
			task.wait(.25)
			if not isCancelled() and bootCover.Parent then bootCover:Destroy()end
			return
		end
		local started=os.clock()
		while not isCancelled() and bootCover.Parent and os.clock()-started<8 do
			if player.PlayerGui:FindFirstChild("VTRPrematchBroadcast") then
				task.wait(.45)
				break
			end
			task.wait(.05)
		end
		if not isCancelled() and bootCover.Parent then bootCover:Destroy() end
	end)
	self.Active=true;self.MatchStartKey=activationKey;self.MatchData=data;self.PresentationStarted=false;self.PresentationReadySent=false;self.ActivatingMatchKey=nil;self.MatchActivationRunningKey=nil;self.Ball=ball;self.TeamModels=data.TeamModels;self.ControlledSide=data.ControlledSide or"Home";self.WatchMode=data.WatchMode==true;self.PracticeMode=data.PracticeMode==true;local noPrematch=data.NoPrematch==true;self.Paused=false;self.Ranked=data.Ranked==true;self.MatchInPlay=self.PracticeMode or noPrematch;self.PrematchActive=not self.PracticeMode and not noPrematch;self.PrematchSkipRequested=noPrematch;self.PrematchSkipUnlockAt=os.clock()+math.max(0,tonumber(data.PrematchSkipDelay)or 0);self.TacticalMode=false;self.TacticalPanelOpen=true;self.PlayabilityPerformanceStartedAt=os.clock();self.PlayabilityFrameCount=0;self.PlayabilityMaxBallDivergence=0;self.PlayabilityPerformanceSent=false;GuiService.SelectedObject=nil;local playerModule=require(player.PlayerScripts:WaitForChild("PlayerModule", 15));self.Controls=playerModule:GetControls();self.Controls:Disable();self.HUD=MatchHUDController.new(data);local completedMatches=math.max(0,math.floor(tonumber(data.Setup and data.Setup.PlayabilityCompletedMatches)or 0));self.FirstSession=self.WatchMode~=true and data.Setup and data.Setup.PlayabilityLegacyAccess~=true and(data.PresentationProfile=="Acquisition"or completedMatches<3);self.LastAttackDirectionHalf=nil;if self.HUD and self.HUD.SetSecondHalfResetCallback then self.HUD:SetSecondHalfResetCallback(function()if self.Action then self.Action:FireServer({Type="SecondHalfWatchdogReset"})end;if self.Camera and self.Camera.ReturnToLive then self.Camera:ReturnToLive()elseif self.Camera and self.Camera.EndCutscene then self.Camera:EndCutscene()end;if self.HUD then self.HUD:Flash("RESETTING SECOND HALF",1.0)end end)end;self.Commentary=nil;self.Celebrations=CelebrationPoseController.new();self.CrowdAmbience=CrowdAmbienceController.new();self.CrowdAmbience:Start();self.MatchSounds=MatchSoundController.new(ball,data.TeamModels);self.MatchSounds:Start();self.Camera=BroadcastCameraController.new(data.PitchCFrame,data.PitchWidth,data.PitchLength,ball,active);self.Camera.ForcedMode=data.ForceCameraMode;self.MouseAim=MouseAimController.new(workspace.CurrentCamera,data.PitchCFrame,data.PitchWidth,data.PitchLength);self.Input=InputController.new(self.Action,function(kind,charge)return self:_aimPayload(kind,charge)end);self.Input:SetMatchContext(data.PitchCFrame);self.InputLock=MatchInputLockController.new(self.Action);self.TeamControl=TeamControlController.new(self.Action,self.Camera,self.HUD,active);self.BallRoll=BallRollVisualController.new(ball)
	self.Input:SetCancellationCallback(function()self.LockedPassTarget=nil;self.GamepadShotAimPoint=nil;if self.GoalTarget then self.GoalTarget:Unlock()end end)
	self.WorldCupOnboardingTrainer=data.Setup and data.Setup.WorldCupOnboarding==true or false
	self.HUD:SetPauseButtonCallback(function()self:_setPaused(true)end)
	if data.Setup and data.Setup.CampaignAscension==true and self.WatchMode then
		local initialTactics=type(data.Setup.TeamTactics)=="table"and data.Setup.TeamTactics or{}
		self.AscensionManagerPanel=AscensionManagerPanel.new(self.HUD.Gui,{
			Objective=data.Setup.AscensionObjective,
			InitialMentality=initialTactics.Identity or"Balanced",
			InitialTacticalPreset=initialTactics.PresetId,
			InitialFormation=data.HomeFormation or data.Setup.HomeFormation or"4-3-3",
			TeamModels=data.TeamModels,
			SelectOnOpen=UserInputService.GamepadEnabled,
			OnAction=function(action:string,value:string?)
				if self.Action then self.Action:FireServer({Type="CampaignManagerAction",Action=action,Value=value})end
			end,
			OnApply=function(changes:any)
				if self.Action then self.Action:FireServer({Type="CampaignManagerApply",Changes=changes})end
			end,
			OnSubstitutions=function()self:_setPaused(true)end,
			OnClose=function()
				if self.AscensionManagerPanel then self.AscensionManagerPanel:Destroy();self.AscensionManagerPanel=nil end
			end,
		})
	end
	if self.WatchMode then
		if self.ControlledIndicator then self.ControlledIndicator:Destroy();self.ControlledIndicator=nil end
	elseif not self.ControlledIndicator then
		self.ControlledIndicator=VoltraControlledPlayerIndicator.new(function()
			if self.WatchMode or not self.MatchInPlay or self.PrematchActive then return nil end
			if self.ActiveModel and tostring(self.ActiveModel:GetAttribute("VTRTeam")or"")~=tostring(self.ControlledSide or"")then return nil end
			return self.ActiveModel
		end,self.WorldCupOnboardingTrainer and{HideTag=true,RingColor=Color3.fromHex("19A7FF"),RingTransparency=.18,FloorOffset=2.95}or nil)
	end
	self.HUD:SetManualSubstitutionCallback(function(benchIndex:number,outgoingModel:Model,outgoingName:string)
		self.Action:FireServer({Type="ManualSubstitution",BenchIndex=benchIndex,OutgoingModel=outgoingModel,OutgoingName=outgoingName})
	end)
	self.HUD:SetManualPositionSwapCallback(function(modelA:Model,modelB:Model)
		self.Action:FireServer({Type="ManualPositionSwap",ModelA=modelA,ModelB=modelB})
	end)
	local uiState=UIStateService:Get();local settings=PlayabilitySettingsConfig.Normalize(uiState and uiState.Settings or{});settings.ManualPassKey=settings.ManualPassKey or"LeftControl";settings.LobbedPassKey=settings.LobbedPassKey or"LeftAlt";settings.ChangePlayerKey=settings.ChangePlayerKey or"Q";settings.TackleKey=settings.TackleKey or"E";settings.SlideTackleKey=settings.SlideTackleKey or"F";self.PlayabilitySettings=settings;if self.HUD and self.HUD.ApplyDeviceProfile then self.HUD:ApplyDeviceProfile(settings)end;self.PauseKey=keyCodeFromSetting(settings.PauseKey,Enum.KeyCode.M);self.Input:SetAutoSwitch(settings.PassReceiverAutoSwitch);self.Input:SetManualPassAutoSwitch(settings.ManualPassAutoSwitch);self.Input:SetReceiverAssist(settings.ReceiverAssistMode);if self.Input.SetControlsSettings then self.Input:SetControlsSettings(settings)end;if self.Input.SetShotModeChanged then self.Input:SetShotModeChanged(function(mode)if self.HUD and self.HUD.SetShotMode then self.HUD:SetShotMode(mode)end end)end;self.Indicators=PlayerIndicatorController.new(data.TeamModels,ball,self.HUD,"Off",self.ControlledSide);local tutorialMatch=data.Setup and data.Setup.WorldCupOnboarding==true;local trainerMode=tutorialMatch and UserInputService.TouchEnabled and"Off"or tutorialMatch and"WorldCupOnboarding"or settings.Trainer or"Basic";self.Trainer=TrainerController.new(self.HUD.Gui,ball,trainerMode,settings);self.Minimap=MinimapController.new(self.HUD.Gui,data.PitchCFrame,data.PitchWidth,data.PitchLength,data.TeamModels,ball,settings.Minimap or"Medium",settings.MinimapOrientation or"Broadcast",settings.CameraSide or"Near",self.ControlledSide);self.AimLine=AimLineController.new(data.TeamModels,ball);self.GoalTarget=GoalReticleController.new(workspace.CurrentCamera,ball);self.FlightMarker=BallFlightMarkerController.new(ball);self.Cutscenes=MatchCutsceneController.new(self.Camera,self.HUD);local deviceDefaults=UserInputService.TouchEnabled and DeviceGameplayConfig.Camera.Mobile or(UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and DeviceGameplayConfig.Camera.Gamepad or DeviceGameplayConfig.Camera.Desktop);local automaticCamera=settings.CameraPreset=="Auto";local cameraMode=data.ForceCameraMode or(automaticCamera and deviceDefaults.Preset or settings.CameraPreset);if automaticCamera then settings.CameraZoomMode=deviceDefaults.ZoomMode end;self.Camera:SetMode(cameraMode);self.Camera:ApplySettings(settings,automaticCamera and deviceDefaults or nil);if self.PracticeMode and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true);if data.DeveloperAccess==true then self:_createPracticeTuningPanel()end end
	if self.HUD and self.HUD.TouchFirstSession and self.Minimap then self.Minimap:SetMode("Off")end
	self.AnimationCache={};for _,side in data.TeamModels do for _,footballer in side do self.AnimationCache[footballer]=AnimationController.new(footballer)end end
	if self.ReplayController then self.ReplayController:Destroy()end;self.ReplayController=ReplayController.new(data,ball)
	if data.DeveloperAccess==true then self.RuntimeTactics={Home=LiteConfig.DefaultTactics(),Away=LiteConfig.DefaultTactics()};self.RuntimeTactics.Home.Formation=data.HomeFormation or"4-3-3";self.RuntimeTactics.Away.Formation=data.AwayFormation or"4-3-3";applyTacticIdentity(self.RuntimeTactics.Home,1);applyTacticIdentity(self.RuntimeTactics.Away,1);self:_createAnalysisBoard();self:_sendRuntimeTactics("Home");self:_sendRuntimeTactics("Away")end
	self.HUD:SetResumeCallback(function()self:_setPaused(false)end)
	self.Lifecycle:BindActionAtPriority(PAUSE_ACTION,function(_,state)if state==Enum.UserInputState.Begin and self.Active then self:_setPaused(not self.Paused)end;return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+200,Enum.KeyCode.ButtonSelect,Enum.KeyCode.ButtonStart)
	self.PauseConnection=self:_trackConnection(UserInputService.InputBegan:Connect(function(input,processed)
		if not self.Active then return end
		if input.KeyCode==(self.PauseKey or Enum.KeyCode.M) then self:_setPaused(not self.Paused);return end
		if input.KeyCode==Enum.KeyCode.One and not processed and self.Camera and self.Camera.ToggleShootingFocus and self.MatchInPlay and not self.Paused and self.WatchMode~=true then
			local enabled:boolean
			if self.WorldCupOnboardingTrainer and self.Camera.SetShootingFocus then
				enabled=self.Camera:SetShootingFocus(true)
			else
				enabled=self.Camera:ToggleShootingFocus()
			end
			if self.HUD then self.HUD:Flash(enabled and"SHOOTING FOCUS CAMERA"or"WIDE BROADCAST CAMERA",.75)end
			if self.WorldCupOnboardingTrainer and self.Action then self.Action:FireServer({Type="ShootingFocus"})end
			return
		end
		if (input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.ButtonA) and self.PrematchActive and not self.PrematchSkipRequested then local remaining=math.ceil((tonumber(self.PrematchSkipUnlockAt)or 0)-os.clock());if remaining>0 then if self.HUD then self.HUD:Flash("SKIP IN "..tostring(remaining),.55)end;return end;self.PrematchSkipRequested=true;self.Action:FireServer({Type="PrematchSkip"});self:_setPrematchSkipProgress(1,self.Ranked and 2 or 1);if self.HUD then self.HUD:Flash(self.Ranked and"SKIP QUEUED"or"SKIPPING INTRO",.9)end;return end
	end),"Input")
	self.FreeKickTouchPanVector=Vector2.zero;self.FreeKickTouchPanInput=nil;self.FreeKickTouchPanLast=nil;self.FreeKickTouchConnections={}
	table.insert(self.FreeKickTouchConnections,self:_trackConnection(UserInputService.TouchStarted:Connect(function(input,processed)
		if processed or self.SetPieceMode~="DirectShotFreeKick"or self.WatchMode==true then return end
		if self.FreeKickTouchPanInput~=nil then return end
		local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
		local pos=Vector2.new(input.Position.X,input.Position.Y)
		if pos.X<viewport.X*.28 or (pos.X>viewport.X*.72 and pos.Y>viewport.Y*.58)then return end
		self.FreeKickTouchPanInput=input
		self.FreeKickTouchPanLast=pos
		self.FreeKickTouchPanVector=Vector2.zero
	end),"Input"))
	table.insert(self.FreeKickTouchConnections,self:_trackConnection(UserInputService.TouchMoved:Connect(function(input,processed)
		if input~=self.FreeKickTouchPanInput then return end
		local pos=Vector2.new(input.Position.X,input.Position.Y)
		local last=self.FreeKickTouchPanLast or pos
		local delta=pos-last
		self.FreeKickTouchPanLast=pos
		self.FreeKickTouchPanVector=Vector2.new(math.clamp(delta.X/42,-1,1),math.clamp(-delta.Y/42,-1,1))
	end),"Input"))
	table.insert(self.FreeKickTouchConnections,self:_trackConnection(UserInputService.TouchEnded:Connect(function(input,processed)
		if input~=self.FreeKickTouchPanInput then return end
		self.FreeKickTouchPanInput=nil
		self.FreeKickTouchPanLast=nil
		self.FreeKickTouchPanVector=Vector2.zero
	end),"Input"))
	self.Camera:Start();self.InputLock:Start(false);self.Input:Start();self.Input:SetSprintAllowed(false);self.Input:SetSuppressed(not self.PracticeMode or self.WatchMode==true);if self.Input and self.Input.SetShootingOnly then self.Input:SetShootingOnly(self.PracticeMode)end;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.PracticeMode and self.WatchMode~=true)end;if self.WatchMode then if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"));if self.PracticeMode then self.Input:SetSuppressed(self.WatchMode==true);self.Input:SetSprintAllowed(self.WatchMode~=true);if self.GoalTarget then self.GoalTarget:SetMode("Shot");self.GoalTarget:SetDefenseSource(nil);self.GoalTarget:SetMatchActive(self.WatchMode~=true);local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end end;if self.HUD then self.HUD:SetPhase("SHOOTING PRACTICE")end;if data.DeveloperAccess==true then self:_emitPracticeTuning(true)end end
	self:_spawnMatchTask(function(isCancelled)
		local deadline=os.clock()+6
		while not isCancelled() and self.Active and player:GetAttribute("VTREssentialMatchReady")==false and os.clock()<deadline do task.wait(.03)end
		if not isCancelled() and self.Active and self.MatchStartKey==activationKey and self.Action then local device=UserInputService.TouchEnabled and"Touch"or(UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and"Gamepad"or"KeyboardMouse");self.Action:FireServer({Type="ClientReady",MatchSessionId=data.MatchSessionId or data.WorldName,Device=device,ReceiverAssistMode=settings.ReceiverAssistMode,DefensiveAutoSwitchMode=settings.DefensiveAutoSwitchMode,CameraPreset=cameraMode,PresentationLayerCount=tonumber(Players.LocalPlayer:GetAttribute("VTRPresentationLayerCount"))or 0})end
	end)
	self.Lifecycle:BindRenderStep("VTRMatchGameplay",Enum.RenderPriority.Camera.Value+1,function(dt)self:_update(dt)end)
end
function Controller:_setPaused(paused:boolean)
	if not self.Active then return end
	if not paused and self.HalfTimePauseActive then self.Action:FireServer({Type="HalfTimeResume"});return end
	if paused and self.Paused then return end
	if not paused and not self.Paused then self.Action:FireServer({Type="Pause",Active=false});return end
	self.Action:FireServer({Type="Pause",Active=paused})
end
function Controller:_updateTeamAnimations()
	for model,controller in self.AnimationCache or{}do
		if model==self.ActiveModel or not model.Parent then continue end
		local modelRoot=model:FindFirstChild("HumanoidRootPart")::BasePart?;if not modelRoot then continue end
		if model:GetAttribute("VTRCelebrating")==true or model:GetAttribute("VTRCelebratingLocal")==true then continue end
		local goalkeeper=model:GetAttribute("position")=="GK"
		if model:GetAttribute("VTRForceIdle")==true then controller:Play(goalkeeper and"GoalkeeperIdle"or"Idle");continue end
		local speed=Vector3.new(modelRoot.AssemblyLinearVelocity.X,0,modelRoot.AssemblyLinearVelocity.Z).Magnitude;local hasBall=self.Ball:GetAttribute("OwnerModel")==model.Name
		if speed>.65 then controller:Play(goalkeeper and"GoalkeeperMove"or(hasBall and"Dribble"or(model:GetAttribute("VTRSprinting")==true and"Sprint"or"Jog")))else controller:Play(goalkeeper and"GoalkeeperIdle"or"Idle")end
	end
end
function Controller:_resetCameraWatchdog()
	self.CameraWatchdog=nil
end
function Controller:_resetSecondHalfWatchdog()
	self.SecondHalfWatchdog=nil
end
function Controller:_startSecondHalfWatchdog()
	local camera=workspace.CurrentCamera
	self.SecondHalfWatchdog={
		StillFor=0,
		LastGameSeconds=tonumber(self.MatchGameSeconds)or 2700,
		LiveAdvanced=0,
		LastCameraPosition=camera and camera.CFrame.Position or Vector3.zero,
		LastLookVector=camera and camera.CFrame.LookVector or Vector3.zAxis,
		Requested=false,
	}
end
function Controller:_updateSecondHalfWatchdog(dt:number)
	local watchdog=self.SecondHalfWatchdog
	if not watchdog then return end
	local gameSeconds=tonumber(self.MatchGameSeconds)or tonumber(watchdog.LastGameSeconds)or 0
	local lastGameSeconds=tonumber(watchdog.LastGameSeconds)or gameSeconds
	local gameAdvanced=gameSeconds>lastGameSeconds
	if gameAdvanced then
		watchdog.LiveAdvanced=(tonumber(watchdog.LiveAdvanced)or 0)+math.max(0,gameSeconds-lastGameSeconds)
	end
	if watchdog.Requested==true or not self.Active or (tonumber(workspace:GetAttribute("VTRMatchHalf"))or 1)~=2 or ((tonumber(watchdog.LiveAdvanced)or 0)>=300 and gameSeconds>3000) then
		self:_resetSecondHalfWatchdog()
		return
	end
	local camera=workspace.CurrentCamera
	if not camera then return end
	local cameraFrame=camera.CFrame
	local cameraMoved=(cameraFrame.Position-(watchdog.LastCameraPosition or cameraFrame.Position)).Magnitude
	local lookMoved=(cameraFrame.LookVector-(watchdog.LastLookVector or cameraFrame.LookVector)).Magnitude
	if self.Paused or self.HalfTimePauseActive then
		watchdog.StillFor=0
	elseif cameraMoved<0.05 and lookMoved<0.0025 then
		watchdog.StillFor=(tonumber(watchdog.StillFor)or 0)+dt
	else
		watchdog.StillFor=0
	end
	if (tonumber(watchdog.StillFor)or 0)>=10 then
		watchdog.Requested=true
		if self.Camera and self.Camera.ReturnToLive then
			self.Camera:ReturnToLive()
		elseif self.Camera and self.Camera.EndCutscene then
			self.Camera:EndCutscene()
		end
		if self.Action then
			self.Action:FireServer({Type="SecondHalfWatchdogReset"})
		end
		if self.HUD then self.HUD:Flash("RESETTING SECOND HALF",1.0)end
	end
	watchdog.LastGameSeconds=gameSeconds
	watchdog.LastCameraPosition=cameraFrame.Position
	watchdog.LastLookVector=cameraFrame.LookVector
end
function Controller:_freeKickCameraPanInput(dt:number):Vector2
	if self.SetPieceMode~="DirectShotFreeKick"or self.WatchMode==true or self.Paused==true or self.PrematchActive==true then
		self.FreeKickTouchPanVector=Vector2.zero
		return Vector2.zero
	end
	local vector=Vector2.zero
	if self.Input and self.Input.GamepadAim and self.Input.GamepadAim.Magnitude>.08 then
		vector+=self.Input.GamepadAim
	end
	if UserInputService.TouchEnabled then
		vector+=self.FreeKickTouchPanVector or Vector2.zero
	elseif UserInputService.MouseEnabled and not UserInputService:GetFocusedTextBox()then
		local camera=workspace.CurrentCamera
		local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
		local mouse=UserInputService:GetMouseLocation()
		local margin=math.clamp(math.min(viewport.X,viewport.Y)*.08,34,84)
		local x=0
		local y=0
		if mouse.X<=margin then x=-(1-mouse.X/margin)elseif mouse.X>=viewport.X-margin then x=(mouse.X-(viewport.X-margin))/margin end
		if mouse.Y<=margin then y=(1-mouse.Y/margin)elseif mouse.Y>=viewport.Y-margin then y=-(mouse.Y-(viewport.Y-margin))/margin end
		vector+=Vector2.new(math.clamp(x,-1,1),math.clamp(y,-1,1))
	end
	if vector.Magnitude>1 then vector=vector.Unit end
	return vector
end
function Controller:_updateCameraWatchdog(dt:number)
	if not self.Active or not self.MatchInPlay or self.Paused or self.PrematchActive or self.HalfTimePauseActive or self.CornerCamera or not self.Ball or not self.Ball.Parent then
		self:_resetCameraWatchdog()
		return
	end
	local camera=workspace.CurrentCamera
	if not camera then
		self:_resetCameraWatchdog()
		return
	end
	local now=os.clock()
	local ballPosition=self.Ball.Position
	local cameraFrame=camera.CFrame
	local watchdog=self.CameraWatchdog
	if not watchdog then
		self.CameraWatchdog={
			FrozenFor=0,
			LastBallPosition=ballPosition,
			LastCameraPosition=cameraFrame.Position,
			LastLookVector=cameraFrame.LookVector,
			LastResetAt=0,
		}
		return
	end
	local ballVelocity=self.Ball.AssemblyLinearVelocity
	local ballMoved=(ballPosition-watchdog.LastBallPosition).Magnitude
	local ballIsMoving=ballVelocity.Magnitude>9 or ballMoved>2.5
	local cameraMoved=(cameraFrame.Position-watchdog.LastCameraPosition).Magnitude
	local lookMoved=(cameraFrame.LookVector-watchdog.LastLookVector).Magnitude
	local cameraFrozen=cameraMoved<0.035 and lookMoved<0.0025
	if ballIsMoving and cameraFrozen then
		watchdog.FrozenFor=(watchdog.FrozenFor or 0)+dt
	else
		watchdog.FrozenFor=0
	end
	if watchdog.FrozenFor>1.15 and now-(watchdog.LastResetAt or 0)>2.5 then
		watchdog.FrozenFor=0
		watchdog.LastResetAt=now
		if self.Camera and self.Camera.ReturnToLive then
			self.Camera:ReturnToLive()
		elseif self.Camera and self.Camera.EndCutscene then
			self.Camera:EndCutscene()
		end
	end
	watchdog.LastBallPosition=ballPosition
	watchdog.LastCameraPosition=camera.CFrame.Position
	watchdog.LastLookVector=camera.CFrame.LookVector
end
function Controller:_update(dt:number)
	if not self.Active or not self.ActiveModel or not self.ActiveModel.Parent then return end
	self.PlayabilityFrameCount=(tonumber(self.PlayabilityFrameCount)or 0)+1
	local sampleStarted=tonumber(self.PlayabilityPerformanceStartedAt)or os.clock()
	local predicted=self.Visual and self.Visual.PredictedPosition
	if typeof(predicted)=="Vector3"and self.Ball then self.PlayabilityMaxBallDivergence=math.max(tonumber(self.PlayabilityMaxBallDivergence)or 0,(predicted-self.Ball.Position).Magnitude)end
	local sampleDuration=os.clock()-sampleStarted
	if self.PlayabilityPerformanceSent~=true and sampleDuration>=5 and self.Action then
		self.PlayabilityPerformanceSent=true
		self.Action:FireServer({Type="ClientPerformance",MatchSessionId=self.MatchData and(self.MatchData.MatchSessionId or self.MatchData.WorldName),AverageFPS=math.clamp((tonumber(self.PlayabilityFrameCount)or 0)/math.max(sampleDuration,.1),1,240),MaxBallDivergence=math.clamp(tonumber(self.PlayabilityMaxBallDivergence)or 0,0,500)})
	end
	if self.Camera and self.Camera.ApplyFreeKickPan then
		self.Camera:ApplyFreeKickPan(self:_freeKickCameraPanInput(dt),dt)
	end
	self.Camera:Update(dt)
	self:_applyTutorialCameraNudge(dt)
	self:_updateCameraWatchdog(dt)
	self:_updateSecondHalfWatchdog(dt)
	if self.CornerAim then
		self.CornerAim:Update()
		self.CornerCamera:SetTarget(self.CornerAim:GetTarget())
		self.CornerCamera:Update(dt)
		return
	end
	if self.MouseAim.SetForcedGoalSign then
		local forcedGoalSign=nil
		if self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense"then
			forcedGoalSign=tonumber(self.Ball:GetAttribute("VTRPenaltyGoalSign"))or self.SetPieceGoalSign
		elseif self.SetPieceMode=="DirectShotFreeKick"then
			forcedGoalSign=self.SetPieceGoalSign
		elseif self.TutorialShootingMode==true then
			forcedGoalSign=tonumber(self.TutorialGoalSign)
		end
		self.MouseAim:SetForcedGoalSign(forcedGoalSign)
		if self.Camera and self.Camera.SetForcedShootingGoalSign then
			self.Camera:SetForcedShootingGoalSign(forcedGoalSign)
		end
	end
	self.MouseAim:Update()
	local root=self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?
	local ownerName=tostring(self.Ball:GetAttribute("OwnerModel")or"")
	local attackingSetPiece=self.SetPieceKind=="FreeKick"or self.SetPieceMode=="DirectShotFreeKick"or self.SetPieceKind=="Penalty"or self.SetPieceKind=="ThrowIn"or self.SetPieceMode=="ThrowIn"or self.SetPieceKind=="GoalKick"or self.SetPieceMode=="GoalKick"
	local hasBall=ownerName==self.ActiveModel.Name or self.SetPieceMode=="PenaltyDefense"or attackingSetPiece
	local receptionContractId=tonumber(self.ActiveModel:GetAttribute("VTRReceptionContractId"))
	local receptionRevision=tonumber(self.ActiveModel:GetAttribute("VTRReceptionRevision"))
	local receptionPhase=tostring(self.ActiveModel:GetAttribute("VTRReceptionPhase")or"")
	local receivingPass=not hasBall and receptionContractId~=nil and receptionRevision~=nil and self.ActiveModel:GetAttribute("VTRPreparingReceive")==true and receptionPhase~="Completed"and receptionPhase~="Cancelled"
	local receiveArrival=receivingPass and math.max(0,tonumber(self.ActiveModel:GetAttribute("VTRReceiveBallETA"))or math.huge)or nil
	if self.Input and self.Input.SetActionContext then self.Input:SetActionContext(hasBall,receivingPass,{ActiveModel=self.ActiveModel,ArrivalSeconds=receiveArrival,ReceptionContractId=receptionContractId,ReceptionRevision=receptionRevision})end
	if self.Input and self.Input.SetMobileDefending then self.Input:SetMobileDefending(not(hasBall or receivingPass or attackingSetPiece))end
	if self.HUD and self.HUD.SetActionQueued and self.Input then self.HUD:SetActionQueued(self.Input:IsActionQueued())end
	local charge=self.Input:ChargeValue()
	local chargeKind=self.Input:ChargeKind()
	local aimingAtGoal=self.MouseAim:IsAimingAtGoal()
	local goalPoint=self.MouseAim:GetGoalAimPoint(chargeKind=="Shot"and charge or 0)
	local aimPosition=aimingAtGoal and goalPoint or self.MouseAim:GetAimWorldPosition()
	local shotOnTarget:boolean?=aimingAtGoal
	if (self.PracticeMode or self.TutorialShootingMode==true) and root and hasBall then
		local practiceTarget,practiceOnTarget=self:_practiceGoalPoint(chargeKind=="Shot"and charge or 0)
		if practiceTarget then goalPoint=practiceTarget;aimPosition=practiceTarget;aimingAtGoal=practiceOnTarget==true;shotOnTarget=practiceOnTarget==true end
	end
	local previewKind=(self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense"or self.SetPieceMode=="DirectShotFreeKick")and"Shot"or(chargeKind~=""and chargeKind or"Pass")
	local mobilePreview=root and self:_mobileAimPayload(previewKind,charge,root)or nil
	if mobilePreview then
		aimPosition=mobilePreview.Position
		aimingAtGoal=mobilePreview.GoalTarget
		shotOnTarget=mobilePreview.GoalTarget==true
	end
	if (self.PracticeMode or self.TutorialShootingMode==true) and root and hasBall and not aimingAtGoal then
		local practiceTarget,practiceOnTarget=self:_practiceGoalPoint(chargeKind=="Shot"and charge or 0)
		if practiceTarget then goalPoint=practiceTarget;aimPosition=practiceTarget;aimingAtGoal=practiceOnTarget==true;shotOnTarget=practiceOnTarget==true end
	end
	if self.SetPieceMode=="DirectShotFreeKick"and self.SetPieceGoalSign and aimPosition and self.Camera and self.Camera.PitchCFrame then
		local rectangle=GoalModelResolver.ResolveByAttackSign(self.SetPieceGoalSign,self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length)
		aimPosition=GoalModelResolver.ClampPoint(rectangle,aimPosition)
		aimingAtGoal=true
		shotOnTarget=true
	end
	if (self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense")then
		local goalSign=tonumber(self.Ball:GetAttribute("VTRPenaltyGoalSign"))or self.SetPieceGoalSign or(self.ControlledSide=="Home"and-1 or 1)
		local rectangle=GoalModelResolver.ResolveByAttackSign(goalSign,self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length)
		local stickVector=self.Input and self.Input.MobileAimVector and self.Input:MobileAimVector("Shot") or nil
		local slot=stickVector and stickVector.Magnitude>.08 and penaltySlotFromVector(stickVector,self.PenaltyAimSlot,goalSign) or nil
		local mousePenaltyPoint=nil
		if not slot and self.MouseAim and self.MouseAim.GetGoalPlaneAimPoint then
			mousePenaltyPoint=select(1,self.MouseAim:GetGoalPlaneAimPoint(0))
		end
		aimPosition=(mousePenaltyPoint and GoalModelResolver.ClampPoint(rectangle,mousePenaltyPoint)) or (slot and self.PenaltyAimPoint) or (aimPosition and GoalModelResolver.ClampPoint(rectangle,aimPosition)) or self.PenaltyAimPoint or PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,self.PenaltyAimSlot or"MIDDLE",self.Camera.Width)
		slot=PenaltyConfig.NormalizeSlot(slot)or PenaltyConfig.NormalizeSlot(PenaltyConfig.SlotFromGoalPoint(self.Camera.PitchCFrame,self.Camera.Length,goalSign,aimPosition,self.Camera.Width))or PenaltyConfig.NormalizeSlot(self.PenaltyAimSlot)or"MIDDLE"
		aimPosition=PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,slot,self.Camera.Width)
		self.PenaltyAimSlot=slot
		self.PenaltyAimPoint=aimPosition
		aimingAtGoal=true
		shotOnTarget=true
	end
	local aimDirection=root and aimPosition and(aimPosition-root.Position).Magnitude>.01 and(aimPosition-root.Position).Unit or root and self.MouseAim:GetAimDirectionFromPlayer(root.Position)or self.Camera:Aim()
	self.Indicators:SetAimDirection(aimDirection)
	self.Indicators:Update(dt)
	local freeKickCurve,freeKickLift=0,0
	if self.SetPieceMode=="DirectShotFreeKick"and self.Input and self.Input.FreeKickModifiers then freeKickCurve,freeKickLift=self.Input:FreeKickModifiers()end
	local shotLineContext=self.PracticeMode or chargeKind=="Shot"or self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense"or self.SetPieceMode=="DirectShotFreeKick"
	local lineShotOnTarget:boolean?=nil
	if shotLineContext then lineShotOnTarget=shotOnTarget==true end
	local preview=self.AimLine:Update(dt,aimPosition,hasBall or receivingPass,chargeKind,charge,aimingAtGoal,freeKickCurve,freeKickLift,self.SetPieceMode,lineShotOnTarget)
	self.LockedPassTarget=preview
	if not self.ReceptionState then self.Indicators:SetPassTarget(preview,self.AimLine:IsTargetFallback())end
	local tutorialShooting=self.TutorialShootingMode==true
	local shotReticleContext=self.PracticeMode or tutorialShooting or aimingAtGoal or self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense"or self.SetPieceMode=="DirectShotFreeKick"
	if (self.PracticeMode or tutorialShooting) and hasBall and aimPosition and self.GoalTarget then
		self.GoalTarget:Lock(aimPosition)
	end
	self.GoalTarget:Update(hasBall,shotReticleContext,aimingAtGoal or self.PracticeMode or tutorialShooting,aimPosition)
	if self.Trainer and(self.WorldCupOnboardingTrainer or not UserInputService.TouchEnabled)then
		self.Trainer:SetBusy(chargeKind~=""or self.ActiveModel:GetAttribute("VTRSprinting")==true)
		self.Trainer:Update()
	end
	self.Minimap:Update(dt)
	self:_updateAnalysisBoard(false)
	if self.Paused then return end
	if not self.MatchInPlay and self.ActiveModel:GetAttribute("VTRForceIdle")==true then
		self.Animation:Play(self.ActiveModel:GetAttribute("position")=="GK"and"GoalkeeperIdle"or"Idle")
		self:_updateTeamAnimations()
		if self.Visual then self.Visual:Update(dt,Vector3.zero,false)end
		if self.BallRoll then self.BallRoll:Update(dt,hasBall)end
		if self.FlightMarker then self.FlightMarker:Update(dt)end
		self.HUD:SetCharge(charge,chargeKind)
		return
	end
	local input=self.WatchMode and Vector2.zero or self.Input:Move();if not self.WatchMode then self.TeamControl:Update(dt,input)end;local movement=self.Camera:Movement(input);local sprinting=self.ActiveModel:GetAttribute("VTRSprinting")==true;self.Visual:Update(dt,movement,sprinting);self.BallRoll:Update(dt,hasBall);if self.FlightMarker then self.FlightMarker:Update(dt)end;if not(self.ActiveModel:GetAttribute("VTRCelebrating")==true or self.ActiveModel:GetAttribute("VTRCelebratingLocal")==true)then if root and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>.6 then self.Animation:Play(hasBall and"Dribble"or(sprinting and"Sprint"or"Jog"))else self.Animation:Play("Idle")end end;self:_updateTeamAnimations();self:_refreshActiveStamina();self.HUD:SetStamina(self.Stamina/Config.Stamina.Maximum);self.HUD:SetCharge(charge,chargeKind);local owner=self.Ball:GetAttribute("OwnerModel");local motionKind=tostring(self.Ball:GetAttribute("VTRMotionKind")or"");local passReceiver=tostring(self.Ball:GetAttribute("VTRPassReceiver")or"");local passTarget=self.Ball:GetAttribute("VTRPassTarget");local passInFlight=motionKind=="Pass"and(passReceiver~=""or typeof(passTarget)=="Vector3");self.HUD:SetState(self.WatchMode and"WATCHING AI VS AI"or(owner==self.ActiveModel.Name and(sprinting and"Sprinting"or"Dribbling")or owner==""and(passInFlight and"Pass In Flight"or"Loose Ball")or"Defending"))
end
function Controller:_flushReplayPayloads()
	local pending=self.ReplayQueuedPayloads or{}
	local clock=self.ReplayQueuedClock
	self.ReplayQueuedPayloads={}
	self.ReplayQueuedClock=nil
	self.ReplayBlocking=false
	if clock and self.Active then self:_state(clock)end
	for _,queued in pending do
		if not self.Active then break end
		self:_state(queued)
	end
end

function Controller:_setReceptionState(payload:any,retargeted:boolean?)
	local model=payload.Model
	if not model or typeof(model)~="Instance"or not model:IsA("Model")then return end
	local contractId=tonumber(payload.ContractId)
	local revision=tonumber(payload.Revision)
	if not contractId or not revision then return end
	local current=self.ReceptionState
	if current and tonumber(current.ContractId)~=contractId and retargeted~=true then return end
	local state=current and tonumber(current.ContractId)==contractId and current or{}
	if tonumber(state.Revision)and revision<(tonumber(state.Revision)or 0)then return end
	state.ContractId=contractId
	state.Revision=revision
	state.Model=model
	state.Phase=tostring(payload.Phase or state.Phase or"Committed")
	state.ReceivePoint=typeof(payload.ReceivePoint)=="Vector3"and payload.ReceivePoint or state.ReceivePoint
	state.BallETA=math.max(0,tonumber(payload.BallETA)or tonumber(state.BallETA)or math.huge)
	state.Contested=payload.Contested==true
	if payload.Type=="ReceptionCameraPrepare"then state.CameraPrepared=true end
	self.ReceptionState=state
	local imminent=state.CameraPrepared==true or state.Phase=="ControlPrepared"or state.BallETA<=.75
	if self.Indicators and self.Indicators.SetReceptionTarget then self.Indicators:SetReceptionTarget(model,imminent,state.Contested,self.PlayabilitySettings and self.PlayabilitySettings.ReducedMotion==true)end
	if state.CameraPrepared and self.Camera and self.Camera.UpdateReceptionPreparation then self.Camera:UpdateReceptionPreparation(model,state.ReceivePoint,state.BallETA)end
end

function Controller:_prepareReception(payload:any)
	self:_setReceptionState(payload)
	local state=self.ReceptionState
	if not state or tonumber(state.ContractId)~=tonumber(payload.ContractId)then return end
	state.CameraPrepared=true
	if self.Camera and self.Camera.PrepareReception then self.Camera:PrepareReception(state.Model,state.ReceivePoint,state.BallETA)end
	if self.Indicators and self.Indicators.SetReceptionTarget then self.Indicators:SetReceptionTarget(state.Model,true,state.Contested,self.PlayabilitySettings and self.PlayabilitySettings.ReducedMotion==true)end
end

function Controller:_finishReception(payload:any,cancelled:boolean)
	local state=self.ReceptionState
	if state and tonumber(payload.ContractId)and tonumber(state.ContractId)~=tonumber(payload.ContractId)then return end
	if state and tonumber(payload.Revision)and tonumber(state.Revision)and tonumber(payload.Revision)<tonumber(state.Revision)then return end
	local model=state and state.Model or payload.Model
	if self.Indicators and self.Indicators.ClearReceptionTarget then self.Indicators:ClearReceptionTarget(model)end
	if self.Camera and self.Camera.CancelReceptionPreparation then self.Camera:CancelReceptionPreparation(model)end
	if self.Input and self.Input.ResolveReception then self.Input:ResolveReception(payload.ContractId,payload.Revision,cancelled)end
	if self.HUD and self.HUD.SetActionQueued then self.HUD:SetActionQueued(false)end
	self.ReceptionState=nil
end
function Controller:_finishGoalPresentation(payload:any)
	if not self.Active then return end
	if payload.Type=="Phase"and(payload.Phase=="IN PLAY"or payload.Phase=="SHOOTING PRACTICE")then MatchPresentationService.Complete(false)end
	local cancelReason=ACTION_CANCEL_STATES[payload.Type]
	if payload.Type=="PauseState"and payload.Paused==true then cancelReason="pause"elseif payload.Type=="Phase"and payload.Phase~="IN PLAY"and payload.Phase~="SHOOTING PRACTICE"then cancelReason="phase_change"end
	if cancelReason and self.Input and self.Input.CancelPossessionActions then self.Input:CancelPossessionActions(cancelReason)end
	if self.Action then self.Action:FireServer({Type="ReplayFinished",ReplayId=payload.ReplayId})end
	self.Cutscenes:Goal(payload)
	self:_flushReplayPayloads()
end
function Controller:_state(payload:any)
	if type(payload)~="table"then return end
	if self.Commentary then self.Commentary:HandleState(payload)end
	if payload.Type=="MatchStarted"then
		local key=matchStartKey(payload)
		if (self.Active and self.MatchStartKey==key)or self.ActivatingMatchKey==key or self.MatchActivationRunningKey==key then
			if kickoffDebugEnabled()then print("[VTR KICKOFF][Client] duplicate MatchStarted ignored",key)end
			return
		end
		self.ActivatingMatchKey=key
		local function activateOnce()
			if self.Active and self.MatchStartKey==key then return end
			if self.ActivatingMatchKey~=key then return end
			self:_activate(payload)
		end
		if kickoffDebugEnabled()then print("[VTR KICKOFF][Client] MatchStarted received; activating match camera", "ranked", payload.Ranked==true, "active", payload.ActivePlayer and payload.ActivePlayer.Name or "nil")end
		task.defer(activateOnce)
		return
	end
	if not self.Active then return end
	if payload.Type=="AITacticsDebugApplied"and type(payload.Tactics)=="table"then
		local side=payload.Side=="Away"and"Away"or"Home"
		self.RuntimeTactics[side]=payload.Tactics
		if self.TacticalStatus then self.TacticalStatus.Text=side.." APPLIED"end
		return
	end
	if payload.Type=="CampaignManagerState"then
		if self.AscensionManagerPanel then self.AscensionManagerPanel:Update(payload.Manager,payload.Objective)end
		return
	end
	if payload.Type=="PresentationStart"then
		if self.PresentationStarted then return end
		self.PresentationStarted=true
		self.PrematchActive=true
		self.PrematchSkipRequested=false
		self.PrematchSkipUnlockAt=os.clock()+math.max(0,tonumber(payload.PrematchSkipDelay)or 0)
		if self.Input then self.Input:SetSuppressed(true);self.Input:SetSprintAllowed(false)end
		if self.Cutscenes then
			self.Cutscenes:StadiumIntro(payload,function()
				if not self.Active or self.PresentationReadySent or not self.Action then return end
				self.PresentationReadySent=true
				self.Action:FireServer({Type="PresentationReady",MatchSessionId=payload.MatchSessionId or payload.WorldName})
			end)
		end
		return
	end
	if self.ReplayBlocking and payload.Type~="Goal"and payload.Type~="MatchEnded"then
		if payload.Type=="Clock"then
			self.ReplayQueuedClock=payload
		else
			self.ReplayQueuedPayloads=self.ReplayQueuedPayloads or{}
			table.insert(self.ReplayQueuedPayloads,payload)
		end
		return
	end
	if self.Input then
		if payload.Type=="SetPiece"or payload.Type=="HalfTime"or payload.Type=="Goal"or payload.Type=="MatchEnded"then
			self.Input:SetSprintAllowed(false)
		elseif payload.Type=="Phase"then
			self.Input:SetSprintAllowed((payload.Phase=="IN PLAY"or payload.Phase=="SHOOTING PRACTICE")and self.Paused~=true and self.WatchMode~=true)
		elseif payload.Type=="Clock"then
			self.Input:SetSprintActual(payload.SprintActual==true,payload.SprintLocked==true)
		end
	end
	if payload.Type=="ReceptionStarted"then self:_setReceptionState(payload)
	elseif payload.Type=="ReceptionUpdated"then self:_setReceptionState(payload)
	elseif payload.Type=="ReceptionRetargeted"then self:_setReceptionState(payload,true)
	elseif payload.Type=="ReceptionCameraPrepare"then self:_prepareReception(payload)
	elseif payload.Type=="ReceptionControlTransfer"then self:_setReceptionState(payload);if self.Camera and self.Camera.CancelReceptionPreparation then self.Camera:CancelReceptionPreparation(payload.Model)end;if self.Indicators and self.Indicators.SetReceptionTarget then self.Indicators:SetReceptionTarget(payload.Model,true,self.ReceptionState and self.ReceptionState.Contested,self.PlayabilitySettings and self.PlayabilitySettings.ReducedMotion==true)end
	elseif payload.Type=="ReceptionQueuedAction"then if payload.Action==nil and self.Input and self.Input.ClearReceptionQueuedAction then self.Input:ClearReceptionQueuedAction(payload.ContractId,payload.Revision)end;if self.HUD and self.HUD.SetActionQueued then self.HUD:SetActionQueued(payload.Action~=nil)end
	elseif payload.Type=="ReceptionContact"then self:_setReceptionState(payload);local receiveController=self.AnimationCache and self.AnimationCache[payload.Model];if receiveController then receiveController:Play(payload.ContactKind=="Header"and"Header"or"Receive")end
	elseif payload.Type=="ReceptionCompleted"then self:_finishReception(payload,false)
	elseif payload.Type=="ReceptionCancelled"then self:_finishReception(payload,true)
	elseif payload.Type=="FirstTouch"then local touchController=self.AnimationCache and self.AnimationCache[payload.Actor];if touchController and payload.Actor==self.ActiveModel then touchController:Play(payload.ContactKind=="Header"and"Header"or"Receive")end;if self.WorldCupOnboardingTrainer and self.HUD then local outcome=tostring(payload.Outcome or"");if outcome=="FirstTimePass"then self.HUD:Flash("FIRST-TIME PASS",.55)elseif outcome=="FirstTimeShot"then self.HUD:Flash("FIRST-TIME SHOT",.55)elseif outcome~=""then self.HUD:Flash("CONTROLLED TOUCH",.45)end end
	elseif payload.Type=="ActivePlayer"and payload.Model and payload.Model:IsA("Model")then if payload.Reason=="KickoffReceiver"and self.Input then self.Input:SetSuppressed(self.WatchMode==true)end;if kickoffDebugEnabled()then print("[VTR KICKOFF][Client] ActivePlayer",payload.Model.Name,"reason",payload.Reason or"","inputSuppressed",self.Input and self.Input.Suppressed)end;self:_bindFootballer(payload.Model,payload.Name,payload.Position);if payload.Reason=="PenaltyDefense"then self.SetPieceMode="PenaltyDefense";self.SetPieceGoalSign=tonumber(payload.GoalSign)or tonumber(self.Ball and self.Ball:GetAttribute("VTRPenaltyGoalSign"))or self.SetPieceGoalSign;self.MatchInPlay=false;if typeof(payload.PenaltyLocation)=="Vector3"and self.Camera and self.Camera.BeginCutscene then self.Camera:BeginCutscene("Penalty",payload.PenaltyLocation,45,typeof(payload.GoalPosition)=="Vector3"and payload.GoalPosition or nil)end;if self.AimLine then self.AimLine:SetMatchActive(true)end;if self.GoalTarget then self.GoalTarget:SetMatchActive(true);self.GoalTarget:SetMode("PenaltyDefense");self.GoalTarget:SetDefenseSource(payload.Model)end end
	elseif payload.Type=="PauseQueued"then self.HUD:ShowPauseQueue(Players.LocalPlayer.Name,true)
	elseif payload.Type=="PauseQueue"then self.HUD:ShowPauseQueue(tostring(payload.PlayerName or"PLAYER"),payload.Queued==true)
	elseif payload.Type=="PauseState"then payload.ControlledSide=self.ControlledSide;self.Paused=payload.Paused==true;if self.InputLock then self.InputLock:SetSprintEnabled(not self.Paused)end;if self.Input then self.Input:SetSprintAllowed(not self.Paused and self.MatchInPlay==true)end;local visible=not self.Paused and self.MatchInPlay==true;if self.Trainer then self.Trainer:SetMatchActive((self.WorldCupOnboardingTrainer or not UserInputService.TouchEnabled)and visible)end;if self.Minimap then self.Minimap:SetMatchActive(visible)end;if self.AimLine then self.AimLine:SetMatchActive(visible)end;if self.GoalTarget then self.GoalTarget:SetMatchActive(visible)end;if self.HUD then self.HUD:SetPaused(self.Paused,self.Camera,function()self:_cleanup(true)end,payload,function()self.Action:FireServer({Type="Forfeit"})end)end
	elseif payload.Type=="PauseTimer"then self.HUD:SetPauseTimer(payload.Remaining or 0)
	elseif payload.Type=="PauseResumeVote"then if payload.Ready~=true then self.HUD:Flash(tostring(payload.PlayerName or"PLAYER").." READY TO RESUME",1.0)end
	elseif payload.Type=="PrematchSkipLocked"then self.PrematchSkipRequested=false;if self.HUD then self.HUD:Flash("SKIP IN "..tostring(math.max(1,math.floor(tonumber(payload.Remaining)or 1))),.7)end
	elseif payload.Type=="PrematchSkipQueued"then self:_setPrematchSkipProgress(payload.ReadyCount,payload.TotalCount);if self.HUD then local total=math.max(1,math.floor(tonumber(payload.TotalCount)or 2));local count=math.clamp(math.floor(tonumber(payload.ReadyCount)or 1),0,total);self.HUD:Flash(payload.Ready and"INTRO SKIPPED"or(string.format("SKIP %d/%d",count,total)),1.0)end
	elseif payload.Type=="PrematchSkip"then self.PrematchActive=false;self.PrematchSkipRequested=true;if self.Input then self.Input:SetSprintAllowed(false)end;if UISoundService.StopTransitions then UISoundService.StopTransitions()end;if self.Cutscenes then self.Cutscenes:SkipStadiumIntro()end;self:_playPrematchSkipTransition()
	elseif payload.Type=="PrematchCancelled"then self.PrematchActive=false;self.PrematchSkipRequested=true;if self.Input then self.Input:SetSprintAllowed(false)end;if UISoundService.StopTransitions then UISoundService.StopTransitions()end;if self.Cutscenes then self.Cutscenes:SkipStadiumIntro()end;if self.HUD then self.HUD:Flash("MATCH ENDED",.8)end
	elseif payload.Type=="TutorialStage"then
		if self.WorldCupOnboardingTrainer and (not self.ActiveModel or not self.ActiveModel.Parent)then self.PendingTutorialStage=payload;return end
		local message=tostring(payload.Message or"")
		local action=tostring(payload.Action or"")
		if self.Input then self.Input:SetSuppressed(self.WatchMode==true);self.Input:SetSprintAllowed(self.WatchMode~=true and(action=="Sprint"or action=="Move"))end
		if self.Trainer and self.Trainer.SetTutorialPrompt then self.Trainer:SetTutorialPrompt(payload.Message,payload.Action,payload.Count,payload.Target)end
		if action=="Move"or action=="Sprint"then
			self:_hideTutorialPassPointer()
			self:_showTutorialMovementLane(payload.LaneTarget, payload.HelpLevel, payload.RoutePoints, payload.CurrentPoint, action=="Sprint")
		elseif action=="Pass"and type(payload.TargetModels)=="table"then
			self:_hideTutorialMovementLane()
			self:_showTutorialPassPointers(payload.TargetModels)
		elseif action=="Pass"and payload.TargetModel and payload.TargetModel:IsA("Model")then
			self:_hideTutorialMovementLane()
			self:_showTutorialPassPointer(payload.TargetModel)
		elseif string.find(message,"COMPLETE",1,true)then
			self:_hideTutorialPassPointer()
			self:_hideTutorialMovementLane()
		elseif action~="Move"then
			self:_hideTutorialMovementLane()
		end
		if self.WorldCupOnboardingTrainer and action=="Shoot"then
			self.TutorialShootingMode=true
			self.TutorialGoalSign=tonumber(payload.GoalSign)or -1
			if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true)end
			if self.GoalTarget then
				self.GoalTarget:SetMode("Shot")
				self.GoalTarget:SetDefenseSource(nil)
				self.GoalTarget:SetMatchActive(self.WatchMode~=true)
				local target=self:_practiceGoalPoint(0)
				if target then self.GoalTarget:Lock(target)end
			end
		elseif self.WorldCupOnboardingTrainer and action~="ShootingFocus"then
			self.TutorialShootingMode=false
			self.TutorialGoalSign=nil
			if self.GoalTarget and not self.PracticeMode then self.GoalTarget:Unlock()end
			if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(false)end
		end
		if message==""and action==""then
			self:_hideTutorialStartButton()
			self:_hideTutorialOverlay()
		elseif message=="SECOND HALF KICKOFF"then
			self.TutorialShootingMode=false
			self.TutorialGoalSign=nil
			self:_hideTutorialStartButton()
			self:_hideTutorialOverlay()
		else
			self:_hideTutorialStartButton()
			self:_showTutorialOverlay(payload.Message,payload.Action,payload.Count,payload.Target,payload.RequiresOk==true)
			if message=="PASSING COMPLETE"then
				self:_playTutorialStepTransition("STEP 1 COMPLETE")
			elseif message=="SHOOTING COMPLETE"then
				self:_playTutorialStepTransition("STEP 2 COMPLETE")
			elseif message=="DEFENDING COMPLETE"then
				self:_playTutorialStepTransition("STEP 3 COMPLETE")
			end
		end
	elseif payload.Type=="TutorialRestart"then self:_playPracticeResetTransition("RESTART")
	elseif payload.Type=="PlayabilityDiagnostics"then if self.HUD and self.HUD.SetPlayabilityDiagnostics then self.HUD:SetPlayabilityDiagnostics(tonumber(payload.ControlSeconds)or 0,payload.Summary)end
	elseif payload.Type=="PracticeReset"then self.PracticeMode=true;self.PrematchActive=false;self.MatchInPlay=true;self.Paused=false;self:_createPracticeTuningPanel();if payload.Shooter and payload.Shooter:IsA("Model")then self:_bindFootballer(payload.Shooter,payload.Shooter:GetAttribute("DisplayName"),payload.Shooter:GetAttribute("position"))end;if self.Input then if self.Input.SetShootingOnly then self.Input:SetShootingOnly(true)end;self.Input:SetSuppressed(false);self.Input:SetSprintAllowed(self.WatchMode~=true);if self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.WatchMode~=true)end end;if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(true)end;if self.MatchSounds then self.MatchSounds:SetMatchActive(true)end;if self.Trainer then self.Trainer:SetMatchActive((self.WorldCupOnboardingTrainer or not UserInputService.TouchEnabled)and self.WatchMode~=true)end;if self.Minimap then self.Minimap:SetMatchActive(true)end;if self.AimLine then self.AimLine:SetMatchActive(self.WatchMode~=true)end;if self.GoalTarget then self.GoalTarget:SetMode("Shot");self.GoalTarget:SetDefenseSource(nil);self.GoalTarget:SetMatchActive(self.WatchMode~=true);local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end end;if self.HUD then self.HUD:SetPhase("SHOOTING PRACTICE");if payload.Reason=="START"then self.HUD:Flash("SHOOTING PRACTICE",.9)end end;self:_emitPracticeTuning(true)
	elseif payload.Type=="PracticeShotResult"then local result=tostring(payload.Result or"MISS");self:_playPracticeResetTransition(result);if self.HUD then self.HUD:ResolveShotChance(result=="GOAL");self.HUD:Flash(result=="GOAL"and"GOAL"or result=="SAVE"and"SAVED"or"MISS",.85)end;if self.MatchSounds and result=="GOAL"and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end;if self.Visual then if result=="GOAL"then self.Visual:HoldShotTrail()else self.Visual:StopShotTrail()end end;if self.GoalTarget then self.GoalTarget:Unlock()end
	elseif payload.Type=="BallTrajectory"then if self.Visual and self.Visual.StartTrajectory then self.Visual:StartTrajectory(payload.Trajectory)end
	elseif payload.Type=="SwitchTarget"then self.TeamControl:SetSwitchTarget(payload.Model);self.Indicators:SetNextSwitch(payload.Model)
	elseif payload.Type=="Possession"then if self.HUD then self.HUD:SetPossession(payload.Owner or"",payload.OwnerUserId==Players.LocalPlayer.UserId)end;if self.Indicators then self.Indicators:SetBallCarrier(payload.Model)end;if self.Minimap then self.Minimap:SetBallCarrier(payload.Model)end;if payload.Model then if self.Visual and self.Ball and tostring(self.Ball:GetAttribute("VTRMotionKind")or"")~="Pass"then self.Visual:StopShotTrail()end;if self.GoalTarget then if (self.PracticeMode or self.TutorialShootingMode==true) and payload.Model==self.ActiveModel then local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end else self.GoalTarget:Unlock()end end end
	elseif payload.Type=="PassTarget"then self.Indicators:SetPassTarget(payload.Model)
	elseif payload.Type=="SetPiece"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted(payload.ActualKind or payload.Kind)end;local userRestart=payload.UserControlled==true and payload.WatchOnly~=true;if not userRestart then self:_ensureControlledSideActive()end;if self.Input and payload.Kind~="Corner" then self.Input:SetSuppressed(self.WatchMode==true or not userRestart)end;if self.Input and self.Input.SetDirectFreeKick then self.Input:SetDirectFreeKick(userRestart and payload.Mode=="DirectShotFreeKick")elseif self.Input and self.Input.ResetFreeKickModifiers and payload.Mode=="DirectShotFreeKick"then self.Input:ResetFreeKickModifiers()end;local actualKind=payload.ActualKind or payload.Kind;if userRestart and self.Input and self.Input.LockActions and (actualKind=="FreeKick"or actualKind=="Penalty"or actualKind=="ThrowIn"or actualKind=="GoalKick")then self.Input:LockActions(2)end;self.SetPieceGoalSign=userRestart and payload.GoalSign or nil;if userRestart and payload.Mode=="LongFreeKick"and self.Camera and self.Camera.ReturnToLive then self.Camera:ReturnToLive();self.SetPieceForcedShootingFocus=nil end;self.PenaltyAimSlot=userRestart and actualKind=="Penalty"and"MIDDLE"or self.PenaltyAimSlot;self.PenaltyAimPoint=userRestart and actualKind=="Penalty"and nil or self.PenaltyAimPoint;self.GamepadShotAimPoint=nil;self.FreeKickAimVector=userRestart and payload.Mode=="DirectShotFreeKick"and Vector2.new(0,.22)or self.FreeKickAimVector;local mobileRestart=(actualKind=="FreeKick"or actualKind=="ThrowIn"or actualKind=="Penalty"or actualKind=="GoalKick")and userRestart;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(mobileRestart and self.WatchMode~=true)end;self.MatchInPlay=false;self.SetPieceMode=userRestart and payload.Mode or nil;self.SetPieceKind=userRestart and actualKind or nil;if payload.Kind=="Offside"and self.HUD then self.HUD:Flash("OFFSIDE",1.05)end;if userRestart and payload.Taker and payload.Taker:IsA("Model")then self:_bindFootballer(payload.Taker,payload.Taker:GetAttribute("DisplayName"),payload.Taker:GetAttribute("position"))end;if self.Visual then self.Visual:ClearLock();self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Trainer then self.Trainer:SetMatchActive(false)end;if self.Minimap then self.Minimap:SetMatchActive(true)end;local aimingRestart=mobileRestart and self.WatchMode~=true;if self.AimLine then self.AimLine:SetMatchActive(aimingRestart)end;if self.GoalTarget then self.GoalTarget:SetMatchActive(aimingRestart)end;if actualKind=="Kickoff"then self.PendingKickoffSound=true;self.PendingFoulRestartWhistle=false;if self.Camera and self.Camera.ReturnToLive then self.Camera:ReturnToLive()end else self.PendingKickoffSound=false end;if self.FoulRestartWhistlePending and (actualKind=="FreeKick"or actualKind=="Penalty")then self.PendingFoulRestartWhistle=true;self.FoulRestartWhistlePending=false elseif actualKind~="FreeKick"and actualKind~="Penalty"then self.FoulRestartWhistlePending=false end;if payload.Kind=="Kickoff"and self.HUD then self.HUD:PlayMatchHudIntro();self.HUD:ShowKickoffScorer()end;if self.Cutscenes then self.Cutscenes:Play(payload)end
	elseif payload.Type=="CornerMode"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted("Corner")end;self.Input:SetSuppressed(true);local takerAnimation=self.AnimationCache and self.AnimationCache[payload.Taker];if takerAnimation then takerAnimation:Play("Idle")end;if self.CornerAim then self.CornerAim:Destroy()end;if self.CornerCamera then self.CornerCamera:Destroy()end;self.CornerCamera=CornerCameraController.new(payload);self.CornerAim=CornerAimController.new(payload,self.Action,self.HUD);self.HUD:SetPhase("CORNER KICK")
	elseif payload.Type=="CornerReleased"then self.Input:SetSuppressed(false);if self.CornerAim then self.CornerAim:Destroy();self.CornerAim=nil end;if self.CornerCamera then self.CornerCamera:Destroy();self.CornerCamera=nil end;self.HUD:Flash(string.upper(payload.Delivery or"CROSS"),.7)
	elseif payload.Type=="Phase"then self.PrematchActive=false;if self.Input then if self.Input.SetShootingOnly then self.Input:SetShootingOnly(payload.Phase=="SHOOTING PRACTICE")end;self.Input:SetSuppressed(self.WatchMode==true);if self.Input.SetDirectFreeKick then self.Input:SetDirectFreeKick(false)end end;if kickoffDebugEnabled()then print("[VTR KICKOFF][Client] Phase",payload.Phase or"nil","active",self.ActiveModel and self.ActiveModel.Name or"nil","inputSuppressed",self.Input and self.Input.Suppressed)end;if self.Camera and payload.HoldCutscene~=true then if payload.Phase=="IN PLAY"and self.Camera.ReturnToLive then self.Camera:ReturnToLive()elseif self.Camera.EndCutscene then self.Camera:EndCutscene()end end;if self.SetPieceForcedShootingFocus and payload.Phase~="SHOOTING PRACTICE"and self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(false);self.SetPieceForcedShootingFocus=nil end;if self.Visual then self.Visual:ClearLock()end;self.SetPieceMode=nil;self.SetPieceKind=nil;self.SetPieceGoalSign=nil;self.PenaltyAimSlot=nil;self.PenaltyAimPoint=nil;self.GamepadShotAimPoint=nil;self.MatchInPlay=payload.Phase=="IN PLAY"or payload.Phase=="SHOOTING PRACTICE";if payload.Phase=="SHOOTING PRACTICE"then self.PracticeMode=true;self:_createPracticeTuningPanel();if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true)end end;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.MatchInPlay and self.WatchMode~=true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;if self.MatchSounds then self.MatchSounds:SetMatchActive(self.MatchInPlay)end;if self.Trainer then self.Trainer:SetMatchActive((self.WorldCupOnboardingTrainer or not UserInputService.TouchEnabled)and self.MatchInPlay and self.WatchMode~=true)end;if self.Minimap then self.Minimap:SetMatchActive(self.MatchInPlay)end;if self.AimLine then self.AimLine:SetMatchActive(self.MatchInPlay and self.WatchMode~=true)end;if self.GoalTarget then self.GoalTarget:SetMode("Shot");self.GoalTarget:SetDefenseSource(nil);self.GoalTarget:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);if self.PracticeMode and self.MatchInPlay then local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end end end;if self.HUD then self.HUD:SetPhase(payload.Phase or"IN PLAY")end;if self.MatchInPlay then self:_showFreshAttackDirection(tonumber(workspace:GetAttribute("VTRMatchHalf"))or 1)end
	elseif payload.Type=="HalfTime"then self:_resetSecondHalfWatchdog();if self.AscensionManagerPanel then self.AscensionManagerPanel:SetHalf(2)end;if self.HUD and self.HUD.SetSecondHalfResetVisible then self.HUD:SetSecondHalfResetVisible(false)end;self.MatchInPlay=false;self.HalfTimePauseActive=true;self.Paused=true;if self.Trainer then self.Trainer:SetMatchActive(false)end;if self.Minimap then self.Minimap:SetMatchActive(false)end;if self.AimLine then self.AimLine:SetMatchActive(false)end;if self.GoalTarget then self.GoalTarget:SetMatchActive(false)end;if self.Cutscenes then self.Cutscenes:HalfTime(payload,function()if self.Active and self.HalfTimePauseActive then self.Action:FireServer({Type="HalfTimePresentationReady"})end end)end;payload.ControlledSide=self.ControlledSide;self:_delayMatchTask(12,function()if self.Active and self.HalfTimePauseActive and self.HUD then self.HUD:SetPaused(true,self.Camera,function()self:_cleanup(true)end,payload,function()self.Action:FireServer({Type="Forfeit"})end)end end)
	elseif payload.Type=="HalfTimeTimer"then if self.HUD then self.HUD:SetPauseTimer(payload.Remaining or 0)end
	elseif payload.Type=="HalfTimeResumeVote"then if self.HUD and payload.Ready~=true then self.HUD:Flash(tostring(payload.PlayerName or"PLAYER").." READY FOR SECOND HALF",1.0)end
	elseif payload.Type=="HalfTimeResume"then self.HalfTimePauseActive=false;self.Paused=false;self:_startSecondHalfWatchdog();if self.Camera and self.Camera.ReturnToLive then self.Camera:ReturnToLive()elseif self.Camera and self.Camera.EndCutscene then self.Camera:EndCutscene()end;if self.HUD then self.HUD:ClearPause();if self.HUD.SetSecondHalfResetVisible then self.HUD:SetSecondHalfResetVisible(true)end end;self:_showFreshAttackDirection(2)
	elseif payload.Type=="Pass"then if self.MatchSounds then if self.PendingKickoffSound then self.PendingKickoffSound=false;self.PendingFoulRestartWhistle=false;self.MatchSounds:PlayKickoff()else self.PendingFoulRestartWhistle=false;self.MatchSounds:PlayKick()end end;if self.HUD then self.HUD:HideKickoffScorer()end;local trailMode=tostring(self.PlayabilitySettings and self.PlayabilitySettings.PassTrailVisibility or"UserOnly");local showTrail=trailMode=="All"or trailMode=="UserOnly"and(tonumber(payload.ActorUserId)==Players.LocalPlayer.UserId or payload.Actor==self.ActiveModel);if self.Visual then self.Visual:ClearLock();self.Visual:SnapTo(self.Ball.Position,self.Ball.AssemblyLinearVelocity);if showTrail then self.Visual:PlayFlightTrail()else self.Visual:StopShotTrail()end end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if payload.Actor==self.ActiveModel and self.Trainer and(self.WorldCupOnboardingTrainer or not UserInputService.TouchEnabled)then self.Trainer:NotifyAction("Pass")end
	elseif payload.Type=="CornerKick"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if self.Visual then self.Visual:StopShotTrail()end
	elseif payload.Type=="Shot"then self.PendingKickoffSound=false;if self.MatchSounds then self.PendingFoulRestartWhistle=false;self.MatchSounds:PlayKick()end;if (self.SetPieceKind=="FreeKick"or self.SetPieceKind=="Penalty") and self.Camera and self.Camera.EndCutscene then self:_delayMatchTask(self.SetPieceKind=="Penalty"and 1.15 or .35,function()if self.Camera then self.Camera:EndCutscene()end end)end;if self.CrowdAmbience then self.CrowdAmbience:Boost(0.9)end;if self.ReplayController then self.ReplayController:MarkShot(payload.Actor)end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if self.HUD then self.HUD:ShowShotChance({XG=payload.ShotQuality or payload.ShotXG or payload.ScoringChance or payload.ScoringChancePercent},payload.Actor)end;if payload.Actor==self.ActiveModel and self.Trainer and(self.WorldCupOnboardingTrainer or not UserInputService.TouchEnabled)then self.Trainer:NotifyAction("Shoot")end
	elseif payload.Type=="ReceiveBall"and payload.Model==self.ActiveModel then self.Animation:Play("Receive")
	elseif payload.Type=="Tackle"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Tackle")end;if payload.Actor==self.ActiveModel and self.Trainer and(self.WorldCupOnboardingTrainer or not UserInputService.TouchEnabled)then self.Trainer:NotifyAction("Tackle")end
	elseif payload.Type=="SlideTackle"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("SlideTackle")end;self.HUD:Flash("SLIDE TACKLE",.55)
	elseif payload.Type=="DribbleMove"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play(payload.Animation or"DribbleMove1")end
	elseif payload.Type=="Block"then if self.HUD then self.HUD:ResolveShotChance(false)end;self.HUD:Flash("SHOT BLOCKED",.6)
	elseif payload.Type=="Clearance"then self.PendingKickoffSound=false;self.PendingFoulRestartWhistle=false;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if payload.Actor==self.ActiveModel and payload.Actor:GetAttribute("position")~="GK"then self.HUD:Flash("BALL CLEARED",.55)end
	elseif payload.Type=="Foul"then self.FoulRestartWhistlePending=true;self.HUD:ShowFoulBanner(payload)
	elseif payload.Type=="Offside"then self.HUD:Flash("OFFSIDE",1.1)
	elseif payload.Type=="Substitution"then self.HUD:ShowSubstitution(payload)
	elseif payload.Type=="GoalkeeperSave"then if self.HUD then self.HUD:ResolveShotChance(false)end;if self.Visual then self.Visual:StopShotTrail();self.Visual:SnapTo(self.Ball.Position,Vector3.zero,.18);self:_delayMatchTask(.08,function()if self.Visual and self.Ball then self.Visual:SnapTo(self.Ball.Position,Vector3.zero,.14)end end)end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Camera and self.Camera.EndCutscene then self:_delayMatchTask(self.SetPieceKind=="Penalty"and .65 or 1.5,function()if self.Camera then self.Camera:EndCutscene()end end)end;self.HUD:Flash("GREAT SAVE",.9)
	elseif payload.Type=="GoalkeeperClaim"then if self.Visual then self.Visual:StopShotTrail();self.Visual:SnapTo(self.Ball.Position,Vector3.zero,.18);self:_delayMatchTask(.08,function()if self.Visual and self.Ball then self.Visual:SnapTo(self.Ball.Position,Vector3.zero,.14)end end)end;if self.GoalTarget then self.GoalTarget:Unlock()end
	elseif payload.Type=="GoalkeeperMiss"then if self.Camera and self.Camera.EndCutscene then self:_delayMatchTask(self.SetPieceKind=="Penalty"and .65 or 1.0,function()if self.Camera then self.Camera:EndCutscene()end end)end
	elseif payload.Type=="Clock"then workspace:SetAttribute("VTRMatchHalf",tonumber(payload.Half)or 1);self.MatchGameSeconds=tonumber(payload.GameSeconds)or self.MatchGameSeconds;if self.AscensionManagerPanel then self.AscensionManagerPanel:SetHalf(tonumber(payload.Half)or 1)end;if tonumber(payload.Half)~=2 then self:_resetSecondHalfWatchdog()end;if self.HUD and self.HUD.SetSecondHalfResetVisible then self.HUD:SetSecondHalfResetVisible((tonumber(payload.Half)or 1)==2 and (tonumber(payload.GameSeconds)or 0)<=3000 and self.HalfTimePauseActive~=true)end;self.Stamina=tonumber(payload.Stamina)or self.Stamina;self.Endurance=tonumber(payload.Endurance)or self.Endurance;self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:UpdateActiveRating()
	elseif payload.Type=="Kickoff"then if self.Visual then self.Visual:StopShotTrail()end;self.HUD:Flash("Kick Off",1)
	elseif payload.Type=="GoalSoundPreview"then if self.MatchSounds and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end
	elseif payload.Type=="GoalSoundPreview"then if self.MatchSounds and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end
	elseif payload.Type=="Goal"then if self.ReplayController and self.ReplayController.SealGoalClip then self.ReplayController:SealGoalClip()end;if self.MatchSounds then self.MatchSounds:PlayGoal(payload.GoalMusicId,payload.GoalMusicStart)end;if self.CrowdAmbience then self.CrowdAmbience:Boost(3.2)end;if self.HUD then self.HUD:ResolveShotChance(true)end;self.MatchInPlay=false;if self.Visual then self.Visual:ClearLock();self.Visual:HoldShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Trainer then self.Trainer:SetMatchActive(false)end;if self.Minimap then self.Minimap:SetMatchActive(false)end;if self.AimLine then self.AimLine:SetMatchActive(false)end;if self.GoalTarget then self.GoalTarget:SetMatchActive(false)end;if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(false)end;if self.HUD then self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:RememberGoalScorer(payload)end;self.ReplayBlocking=true;self.ReplayQueuedPayloads={};self.ReplayQueuedClock=nil;local function playReplay()if not self.Active then return end;self:_hideGoalCelebrationOverlay();if self.Camera and self.Camera.EndCutscene then self.Camera:EndCutscene(true)end;if self.ReplayController then self.ReplayController:PlayGoalReplay(function()self:_finishGoalPresentation(payload)end)else self:_finishGoalPresentation(payload)end end;local function playCelebration()if not self.Active then return end;self:_showGoalCelebrationOverlay(payload);local celebrationId=tostring(payload.CelebrationId or"");if self.Celebrations and payload.ScorerModel and celebrationId~="" then local scorerAnimation=self.AnimationCache and self.AnimationCache[payload.ScorerModel];if scorerAnimation and scorerAnimation.Deactivate then scorerAnimation:Deactivate()end;self.Celebrations:PlayGoalPresentation(payload.ScorerModel,celebrationId,{PitchCFrame=self.Camera and self.Camera.PitchCFrame or CFrame.new(),Width=self.Camera and self.Camera.Width or 76,Length=self.Camera and self.Camera.Length or 742,Team=payload.Team,CameraController=self.Camera,LiveCharacter=true},playReplay)else playReplay()end end;self:_playGoalEffect(payload,playCelebration)
	elseif payload.Type=="FinalChance"then if self.HUD then self.HUD:ShowFinalChance(payload.Active~=false)end
	elseif payload.Type=="Info"then if payload.Important==true then self.HUD:Flash(payload.Message,1.3)end
	elseif payload.Type=="PenaltyShootout"then self.PenaltyAttempt=payload.Phase=="ATTEMPT"and tonumber(payload.Attempt)or nil;if self.HUD and self.HUD.ShowPenaltyShootout then self.HUD:ShowPenaltyShootout(payload)end
	elseif payload.Type=="MatchEnded"then
		if self.AscensionManagerPanel then self.AscensionManagerPanel:Destroy();self.AscensionManagerPanel=nil end
		self.PrematchActive=false
		self.PrematchSkipRequested=true
		self.ReplayBlocking=false
		self.ReplayQueuedPayloads=nil
		self.ReplayQueuedClock=nil
		if self.Cutscenes then self.Cutscenes:SkipStadiumIntro()end
		self:_hideGoalCelebrationOverlay()
		self:_hideTutorialStartButton()
		self:_hideTutorialOverlay()
		if self.MatchSounds then self.MatchSounds:PlayFinalWhistle()end
		if self.Lifecycle then self.Lifecycle:UnbindRenderStep("VTRMatchGameplay")else RunService:UnbindFromRenderStep("VTRMatchGameplay")end
		self:_destroyPracticeTuningPanel()
		if self.HUD then self.HUD:ClearPause();self.HUD:ShowFinalChance(false);if self.HUD.SetSecondHalfResetVisible then self.HUD:SetSecondHalfResetVisible(false)end end
		self.Input:Destroy();self.Input=nil
		self.InputLock:Destroy();self.InputLock=nil
		if self.Camera then self.Camera:SetTacticalView(false);if self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(false)end;self.Camera:SetMode("Broadcast");pcall(function()self.Camera:Update(1/60)end)end
		self.Visual:Destroy();self.Visual=nil
		self.BallRoll:Destroy();self.BallRoll=nil
		if self.FlightMarker then self.FlightMarker:Destroy();self.FlightMarker=nil end
		if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end
		if self.MatchSounds then self.MatchSounds:Destroy();self.MatchSounds=nil end
		if self.CrowdAmbience then self.CrowdAmbience:Destroy();self.CrowdAmbience=nil end
		for _,controller in self.AnimationCache or{}do controller:Destroy()end;self.AnimationCache={};self.Animation=nil
		self.TeamControl:Destroy();self.TeamControl=nil
		self.Indicators:Destroy();self.Indicators=nil
		self.Trainer:Destroy();self.Trainer=nil
		self.Minimap:Destroy();self.Minimap=nil
		self.AimLine:Destroy();self.AimLine=nil
		self.GoalTarget:Destroy();self.GoalTarget=nil
		self.Cutscenes:Destroy();self.Cutscenes=nil
		for _,connection in self.FreeKickTouchConnections or{}do connection:Disconnect()end;self.FreeKickTouchConnections=nil;self.FreeKickTouchPanInput=nil;self.FreeKickTouchPanLast=nil;self.FreeKickTouchPanVector=nil
		if self.Lifecycle then self.Lifecycle:UnbindAction(PAUSE_ACTION)else ContextActionService:UnbindAction(PAUSE_ACTION)end
		if self.PauseConnection then self.PauseConnection:Disconnect();self.PauseConnection=nil end
		local function showResult()
			self.HUD:ShowResult(payload,function()self:_cleanup(true)end)
		end
		local function showRewardsThenResult()
			local rankedWin = payload.Ranked == true and (payload.Result == "Win" or payload.Result == "ForfeitWin")
			if rankedWin and type(payload.RankedWinPack)=="table" and self.HUD and self.HUD.Gui then
				VoltraPackRoulette.Play(self.HUD.Gui,payload,showResult)
			else
				showResult()
			end
		end
		self:_delayMatchTask(math.max(0,tonumber(payload.ResultDelay)or 2),function()
			if not self.HUD then return end
			if self.HUD and payload.Stats then
				self.HUD:ShowHalfTime(payload,{Title="PLAYER OF\nTHE GAME",Duration=math.clamp(tonumber(payload.PostMatchSummarySeconds)or 2.4,1.5,3),OnComplete=showRewardsThenResult})
			else
				showRewardsThenResult()
			end
		end)
	end
end
function Controller:_destroyLifecycle()
	local lifecycle=self.Lifecycle
	if not lifecycle then return end
	local before,after=lifecycle:Destroy()
	self.Lifecycle=nil
	self.ControlGlyphConnection=nil
	self.PauseConnection=nil
	self.FreeKickTouchConnections=nil
	if self.Action then
		self.Action:FireServer({Type="ClientLifecycleDiagnostics",MatchSessionId=self.MatchData and(self.MatchData.MatchSessionId or self.MatchData.WorldName),Before=before,After=after})
	end
end
function Controller:_cleanup(restoreMenu:boolean)
	self:_destroyLifecycle()
	if self.AscensionManagerPanel then self.AscensionManagerPanel:Destroy();self.AscensionManagerPanel=nil end
	RunService:UnbindFromRenderStep("VTRMatchGameplay");ContextActionService:UnbindAction(PAUSE_ACTION);self.FreeKickTouchPanInput=nil;self.FreeKickTouchPanLast=nil;self.FreeKickTouchPanVector=nil;self.TutorialShootingMode=false;self.TutorialGoalSign=nil;self:_hideGoalCelebrationOverlay();self:_hideTutorialStartButton();self:_hideTutorialOverlay();self:_destroyPracticeTuningPanel();if self.CornerAim then self.CornerAim:Destroy();self.CornerAim=nil end;if self.CornerCamera then self.CornerCamera:Destroy();self.CornerCamera=nil end;if self.Input then self.Input:Destroy()end;if self.InputLock then self.InputLock:Destroy()end;if self.Camera then self.Camera:Destroy()end;if self.Visual then self.Visual:Destroy()end;if self.BallRoll then self.BallRoll:Destroy()end;if self.FlightMarker then self.FlightMarker:Destroy();self.FlightMarker=nil end;if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end;if self.MatchSounds then self.MatchSounds:Destroy();self.MatchSounds=nil end;if self.CrowdAmbience then self.CrowdAmbience:Destroy();self.CrowdAmbience=nil end;if self.Commentary then self.Commentary:Destroy();self.Commentary=nil end;for _,controller in self.AnimationCache or{}do controller:Destroy()end;self.AnimationCache={};self.Animation=nil;if self.TeamControl then self.TeamControl:Destroy()end;if self.Indicators then self.Indicators:Destroy()end;if self.Trainer then self.Trainer:Destroy()end;if self.Minimap then self.Minimap:Destroy()end;if self.AimLine then self.AimLine:Destroy()end;if self.GoalTarget then self.GoalTarget:Destroy()end;if self.Cutscenes then self.Cutscenes:Destroy()end;if self.HUD then self.HUD:Destroy()end;if self.Controls then self.Controls:Enable()end;self.Active=false;self.MatchStartKey=nil;self.ActivatingMatchKey=nil;self.MatchActivationRunningKey=nil
	if restoreMenu then
		Players.LocalPlayer:SetAttribute("VTRInMatch",false)
		setMenuVisible(true)
		MatchVisualCleanupService.Apply(nil)
	end
end
function Controller:Destroy()
	if self.Active then self:_cleanup(false)else self:_destroyLifecycle()end
	if self.StateConnection then self.StateConnection:Disconnect();self.StateConnection=nil end
end
return Controller

