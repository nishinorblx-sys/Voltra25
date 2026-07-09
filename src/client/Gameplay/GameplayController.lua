--!strict

local function VTRCameraIgnoreDribbleImpulse(ball:BasePart?):boolean
	if not ball then return false end
	local dribblePulseAt=tonumber(ball:GetAttribute("VTRDribbleTouchImpulseAt") or ball:GetAttribute("VTRDribbleTouchPulseAt") or ball:GetAttribute("VTRDribbleVisualImpulseAt")) or 0
	if dribblePulseAt>0 and os.clock()-dribblePulseAt<0.7 then
		return true
	end
	local motion=tostring(ball:GetAttribute("VTRMotionKind") or "")
	if motion=="Dribble" or motion=="Carried" or motion=="Carry" then
		return true
	end
	local owner=ball:GetAttribute("OwnerModel") or ball:GetAttribute("OwnerUserId")
	if owner~=nil then
		return true
	end
	return false
end


local function vtrLoadShotPowerModel()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local vtr = ReplicatedStorage:FindFirstChild("VTR")
	local shared = (vtr and vtr:FindFirstChild("Shared")) or ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage
	return require(shared:WaitForChild("ShotPowerModel"))
end

local VTRShotPowerModel = vtrLoadShotPowerModel()
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)
local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local Lighting=game:GetService("Lighting")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local LiteConfig=require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
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
local CornerCameraController=require(script.Parent.CornerCameraController)
local CornerAimController=require(script.Parent.CornerAimController)
local BallFlightMarkerController=require(script.Parent.BallFlightMarkerController)
local ReplayController=require(script.Parent.ReplayController)
local CrowdAmbienceController=require(script.Parent.CrowdAmbienceController)
local MatchSoundController=require(script.Parent.MatchSoundController)
local CelebrationPoseController=require(script.Parent.CelebrationPoseController)
local VoltraControlledPlayerIndicator=require(script.Parent.Parent.Components.VoltraControlledPlayerIndicator)
local VoltraPackRoulette=require(script.Parent.Parent.Components.VoltraPackRoulette)
local UIStateService=require(script.Parent.Parent.Services.UIStateService)
local UISoundService=require(script.Parent.Parent.Services.UISoundService)
local PenaltyConfig=require(ReplicatedStorage.VTR.Shared.PenaltyConfig)
local GoalModelResolver=require(ReplicatedStorage.VTR.Shared.GoalModelResolver)
local Controller={};Controller.__index=Controller
local PAUSE_ACTION="VTRMatchControllerBackPause"
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
local function penaltySlotFromVector(vector:Vector2?,fallback:string?,goalSign:number):string
	local current=PenaltyConfig.NormalizeSlot(fallback)or"MIDDLE"
	if not vector or vector.Magnitude<=.08 then return current end
	local x=math.clamp(vector.X,-1,1)*(goalSign<0 and 1 or-1)
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
local function clearGreenScreenEffects()
	for _, item in ipairs(workspace:GetDescendants()) do
		if item.Name == "VTRControlledPlayerHighlight" or item.Name == "VTRControlledPlayerRing" then
			item:Destroy()
		end
	end
	for _, inst in ipairs(Lighting:GetChildren()) do
		if inst:IsA("ColorCorrectionEffect") then
			local tint = inst.TintColor
			local greenTint = tint.G > tint.R + .08 and tint.G > tint.B + .08
			local named = string.find(string.lower(inst.Name), "green") or string.find(string.lower(inst.Name), "setpiece") or string.find(string.lower(inst.Name), "vtr")
			if greenTint or named then
				inst.Enabled = false
				inst.TintColor = Color3.new(1, 1, 1)
				inst.Saturation = 0
				inst.Contrast = 0
				inst.Brightness = 0
			end
		end
	end
	if Lighting.ColorShift_Top.G > Lighting.ColorShift_Top.R + .08 and Lighting.ColorShift_Top.G > Lighting.ColorShift_Top.B + .08 then
		Lighting.ColorShift_Top = Color3.new(0, 0, 0)
	end
	if Lighting.ColorShift_Bottom.G > Lighting.ColorShift_Bottom.R + .08 and Lighting.ColorShift_Bottom.G > Lighting.ColorShift_Bottom.B + .08 then
		Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	end
end
local function clearGreenScreenEffects()
	local function cleanContainer(container: Instance)
		for _, inst in ipairs(container:GetDescendants()) do
			if inst:IsA("ColorCorrectionEffect") then
				inst.Enabled = false
				inst.TintColor = Color3.new(1,1,1)
				inst.Saturation = 0
				inst.Contrast = 0
				inst.Brightness = 0
			elseif inst:IsA("Atmosphere") then
				local color = inst.Color
				local decay = inst.Decay
				if color.G > color.R + .06 and color.G > color.B + .06 then
					inst.Color = Color3.fromRGB(198, 198, 198)
				end
				if decay.G > decay.R + .06 and decay.G > decay.B + .06 then
					inst.Decay = Color3.fromRGB(106, 112, 120)
				end
			end
		end
	end
	cleanContainer(Lighting)
	if workspace.CurrentCamera then cleanContainer(workspace.CurrentCamera) end
	Lighting.ColorShift_Top = Color3.new(0,0,0)
	Lighting.ColorShift_Bottom = Color3.new(0,0,0)
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
		for _, item in ipairs(playerGui:GetDescendants()) do
			if item:IsA("GuiObject") then
				local color = item.BackgroundColor3
				local huge = item.AbsoluteSize.X >= screenSize.X * .72 and item.AbsoluteSize.Y >= screenSize.Y * .72
				local green = color.G > color.R + .08 and color.G > color.B + .08
				if huge and green and item.BackgroundTransparency < 1 then
					item.BackgroundTransparency = 1
					item.Visible = false
				end
			end
		end
	end
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
local function keyCodeFromSetting(value:any,fallback:Enum.KeyCode):Enum.KeyCode
	if type(value)~="string"then return fallback end
	local numberMap={[ "0" ]=Enum.KeyCode.Zero,[ "1" ]=Enum.KeyCode.One,[ "2" ]=Enum.KeyCode.Two,[ "3" ]=Enum.KeyCode.Three,[ "4" ]=Enum.KeyCode.Four,[ "5" ]=Enum.KeyCode.Five,[ "6" ]=Enum.KeyCode.Six,[ "7" ]=Enum.KeyCode.Seven,[ "8" ]=Enum.KeyCode.Eight,[ "9" ]=Enum.KeyCode.Nine}
	if numberMap[value]then return numberMap[value]end
	local ok,key=pcall(function()return Enum.KeyCode[value]end)
	return ok and key or fallback
end
function Controller.new()return setmetatable({Active=false,Stamina=Config.Stamina.Maximum,Endurance=Config.Stamina.Maximum,TacticalMode=false,TacticalPanelOpen=true,TacticalSide="Home",TacticalDebugOptions={},RuntimeTactics={Home=LiteConfig.DefaultTactics(),Away=LiteConfig.DefaultTactics()}},Controller)end
function Controller:Start()local action,state=Remotes.Wait();self.Action=action;self.State=state;state.OnClientEvent:Connect(function(payload)self:_state(payload)end)end
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
	task.spawn(function()
		while gui.Parent do
			TweenService:Create(glow,TweenInfo.new(.42,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=.45}):Play()
			task.wait(.42)
			if not gui.Parent then break end
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
	RunService:UnbindFromRenderStep(name)
	RunService:BindToRenderStep(name,Enum.RenderPriority.Camera.Value+20,function()
		local alpha=math.clamp((os.clock()-started)/shakeDuration,0,1)
		if alpha>=1 then RunService:UnbindFromRenderStep(name);return end
		local fade=(1-alpha)^2
		local t=os.clock()*58
		local x=(math.noise(t,0,0)-.5)*1.6*power*fade
		local y=(math.noise(0,t,0)-.5)*1.25*power*fade
		local roll=(math.noise(0,0,t)-.5)*math.rad(1.7)*power*fade
		camera.CFrame=camera.CFrame*CFrame.new(x,y,0)*CFrame.Angles(0,0,roll)
	end)
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
	if VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true)) then return end
	if effectId=="goal_fx_stadium_shake" then
		duration=self:_shakeGoalScreen(1.18,3.15)
	elseif GOAL_EFFECT_ATTACHMENTS[effectId] then
		duration=self:_spawnGoalAttachmentEffect(effectId,position)
	else
		duration=self:_spawnFallbackGoalBurst(position,Color3.fromRGB(183,255,26))
	end
	if onComplete then task.delay(math.max(.05,duration),onComplete)end
	return duration
end
function Controller:_bindFootballer(model:Model,name:string?,position:string?)
	if self.Animation then self.Animation:Deactivate()end;if self.Visual then self.Visual:Destroy()end;self.AnimationCache=self.AnimationCache or{};self.Animation=self.AnimationCache[model];if not self.Animation then self.Animation=AnimationController.new(model);self.AnimationCache[model]=self.Animation end
	self.ActiveModel=model;self.Visual=BallVisualController.new(self.Ball,model);self.Camera:SetActive(model);self.TeamControl:SetActive(model,name,position);self.Indicators:SetActive(model);if self.Trainer and not UserInputService.TouchEnabled then self.Trainer:SetActive(model)end;self.Minimap:SetActive(model);self.MouseAim:SetActive(model);self.AimLine:SetActive(model)
	self.Stamina=tonumber(model:GetAttribute("VTRSprintStamina"))or tonumber(model:GetAttribute("VTRStamina"))or Config.Stamina.Maximum;self.Endurance=tonumber(model:GetAttribute("VTREndurance"))or Config.Stamina.Maximum;if self.HUD then self.HUD:SetStamina(self.Stamina/Config.Stamina.Maximum,self.Endurance/Config.Stamina.Maximum)end
end
function Controller:_ensureControlledSideActive()
	if self.WatchMode or not self.TeamModels then return end
	if self.ActiveModel and tostring(self.ActiveModel:GetAttribute("VTRTeam")or"")==tostring(self.ControlledSide or"")then return end
	for _,model in self.TeamModels[tostring(self.ControlledSide or"Home")]or{}do
		if model and model.Parent then self:_bindFootballer(model,model:GetAttribute("DisplayName"),model:GetAttribute("position"));return end
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
		self.PenaltyAimSlot=penaltySlotFromVector(vector,self.PenaltyAimSlot,goalSign)
		local position=PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,self.PenaltyAimSlot,self.Camera.Width)
		self.PenaltyAimPoint=position
		local direction=(position-root.Position).Magnitude>.01 and(position-root.Position).Unit or self.Camera:Aim("Shot")
		return{Direction=direction,Position=position,GoalTarget=true,TargetModel=nil,PenaltySlot=self.PenaltyAimSlot,PenaltyDefense=self.SetPieceMode=="PenaltyDefense"}
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
	if typeof(goalTarget) == "Vector3" then
		goalTarget = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, goalTarget, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	end
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
				if typeof(goalTarget) == "Vector3" then
					goalTarget = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, goalTarget, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
				end
			else
				position=root.Position+direction*(90+amount*80)
				goalTarget=false
				if typeof(goalTarget) == "Vector3" then
					goalTarget = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, goalTarget, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
				end
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
			if typeof(target) == "Vector3" then
				target = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, target, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
			end
			local offset=Vector3.new(target.X-root.Position.X,0,target.Z-root.Position.Z)
			local direction=offset.Magnitude>.01 and offset.Unit or self.Camera:Aim("Shot")
			local goalTarget=offset.Magnitude<=200
			if typeof(goalTarget) == "Vector3" then
				goalTarget = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, goalTarget, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
			end
			if goalTarget and self.GoalTarget then self.GoalTarget:Lock(target)end
			return{Direction=direction,Position=target,GoalTarget=goalTarget,TargetModel=nil}
		end
	end
	local position=self.MouseAim:GetAimWorldPosition();local switchTarget=kind=="Switch"and self:_reticleSwitchTarget(position)or nil
	if not root then return{Direction=self.Camera:Aim(kind),Position=position,GoalTarget=false,TargetModel=switchTarget or(kind=="Pass"and self.LockedPassTarget or nil)}end
	local goalTarget=kind=="Shot"and self.MouseAim:IsAimingAtGoal();position=goalTarget and self.MouseAim:GetGoalAimPoint(shotCharge or 0)or position
	if typeof(goalTarget) == "Vector3" then
		goalTarget = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, goalTarget, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
	end
	if self.PracticeMode and kind=="Shot"then local practiceTarget,practiceOnTarget=self:_practiceGoalPoint(shotCharge or 0);if practiceTarget then position=practiceTarget;goalTarget=practiceOnTarget==true end end
	if kind=="Shot"and self.SetPieceMode=="DirectShotFreeKick"and self.SetPieceGoalSign and position and self.Camera and self.Camera.PitchCFrame then
		local rectangle=GoalModelResolver.ResolveByAttackSign(self.SetPieceGoalSign,self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length)
		position=GoalModelResolver.ClampPoint(rectangle,position)
		goalTarget=true
		if typeof(goalTarget) == "Vector3" then
			goalTarget = VTRShotPowerModel.ApplyToTarget(ball and ball.Position or origin or startPosition or shotOrigin or shooterPosition or Vector3.zero, goalTarget, vtrRawShotPower or rawPower or shotPower or kickPower or chargePower or inputPower or power or Power)
		end
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
	if goalTarget and position and self.GoalTarget then self.GoalTarget:Lock(position)end;local offset=position and(position-root.Position)or Vector3.zero;local direction=offset.Magnitude>.01 and offset.Unit or self.MouseAim:GetAimDirectionFromPlayer(root.Position);local freeKickCurve,freeKickLift=0,0;if kind=="Shot"and self.SetPieceMode=="DirectShotFreeKick"and self.Input and self.Input.FreeKickModifiers then freeKickCurve,freeKickLift=self.Input:FreeKickModifiers()end;return{Direction=direction,Position=position,GoalTarget=goalTarget,TargetModel=switchTarget or(kind=="Pass"and self.LockedPassTarget or nil),FreeKickCurve=freeKickCurve,FreeKickLift=freeKickLift,PenaltySlot=penaltySlot,PenaltyDefense=self.SetPieceMode=="PenaltyDefense"}
end
function Controller:_playPrematchSkipTransition()
	local gui=Instance.new("ScreenGui");gui.Name="VTRPrematchSkipTransition";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=112;gui.Parent=Players.LocalPlayer.PlayerGui
	DeviceScaleService.Apply(gui)
	local overlay=Instance.new("CanvasGroup");overlay.BackgroundColor3=Color3.new(0,0,0);overlay.BorderSizePixel=0;overlay.GroupTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=112;overlay.Parent=gui
	local slash=Instance.new("Frame");slash.AnchorPoint=Vector2.new(.5,.5);slash.BackgroundColor3=Color3.new(0,0,0);slash.BackgroundTransparency=1;slash.BorderSizePixel=0;slash.Position=UDim2.fromScale(-.25,.5);slash.Rotation=-16;slash.Size=UDim2.fromScale(.55,1.7);slash.ZIndex=113;slash.Parent=overlay
	local TweenService=game:GetService("TweenService")
	TweenService:Create(overlay,TweenInfo.new(.16),{GroupTransparency=0}):Play()
	TweenService:Create(slash,TweenInfo.new(.36,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.fromScale(1.22,.5)}):Play()
	task.delay(.42,function()if not gui.Parent then return end;TweenService:Create(overlay,TweenInfo.new(.16),{GroupTransparency=1}):Play();task.delay(.18,function()if gui.Parent then gui:Destroy()end end)end)
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
	local TweenService=game:GetService("TweenService")
	local overlay=Instance.new("CanvasGroup");overlay.BackgroundColor3=Color3.new(0,0,0);overlay.BorderSizePixel=0;overlay.GroupTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=126;overlay.Parent=gui
	local flash=Instance.new("Frame");flash.AnchorPoint=Vector2.new(.5,.5);flash.BackgroundColor3=Color3.fromHex("B7FF1A");flash.BorderSizePixel=0;flash.Position=UDim2.fromScale(.5,.5);flash.Rotation=-14;flash.Size=UDim2.fromScale(.18,1.35);flash.ZIndex=127;flash.Parent=overlay
	local text=Instance.new("TextLabel");text.BackgroundTransparency=1;text.AnchorPoint=Vector2.new(.5,.5);text.Position=UDim2.fromScale(.5,.5);text.Size=UDim2.fromOffset(380,74);text.Text=string.upper(result);text.TextColor3=Color3.fromHex("B7FF1A");text.TextSize=34;text.Font=Enum.Font.GothamBlack;text.ZIndex=128;text.Parent=overlay
	TweenService:Create(overlay,TweenInfo.new(.1),{GroupTransparency=.08}):Play()
	TweenService:Create(flash,TweenInfo.new(.32,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.fromScale(1.24,.5),Size=UDim2.fromScale(.34,1.6)}):Play()
	task.delay(.38,function()if not gui.Parent then return end;TweenService:Create(overlay,TweenInfo.new(.14),{GroupTransparency=1}):Play();task.delay(.16,function()if gui.Parent then gui:Destroy()end end)end)
end
function Controller:_ensurePracticeTuning()
	if self.PracticeTuning then return end
	local keeper={};for _,spec in KEEPER_TUNING do keeper[spec.Key]=spec.Default end
	local shooting={};for _,spec in SHOOTING_TUNING do shooting[spec.Key]=spec.Default end
	self.PracticeTuning={Keeper=keeper,Shooting=shooting}
end
function Controller:_emitPracticeTuning(force:boolean?)
	if not self.PracticeMode or not self.Action then return end
	self:_ensurePracticeTuning()
	self.PracticeTuningSeq=(self.PracticeTuningSeq or 0)+1
	local seq=self.PracticeTuningSeq
	task.delay(force and 0 or .05,function()
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
	table.insert(self.PracticeTuningConnections,track.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true;setFromX(input.Position.X,true)end end))
	table.insert(self.PracticeTuningConnections,knob.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true;setFromX(input.Position.X,true)end end))
	table.insert(self.PracticeTuningConnections,UserInputService.InputChanged:Connect(function(input)if dragging and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then setFromX(input.Position.X,true)end end))
	table.insert(self.PracticeTuningConnections,UserInputService.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end))
	setValue(values[spec.Key]or spec.Default,false)
end
function Controller:_createPracticeTuningPanel()
	if self.PracticeTuningGui then return end
	self:_ensurePracticeTuning()
	self.PracticeTuningConnections={}
	local gui=Instance.new("ScreenGui");gui.Name="VTRShootingPracticeTuning";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=119;gui.Parent=Players.LocalPlayer.PlayerGui;DeviceScaleService.Apply(gui)
	local panel=Instance.new("Frame");panel.Name="Panel";panel.AnchorPoint=Vector2.new(1,.5);panel.BackgroundColor3=Color3.fromHex("050705");panel.BackgroundTransparency=.04;panel.BorderSizePixel=0;panel.Position=UDim2.new(1,-18,.5,0);panel.Size=UDim2.fromOffset(340,680);panel.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=panel
	local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("B7FF1A");stroke.Transparency=.38;stroke.Thickness=1;stroke.Parent=panel
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(18,14);title.Size=UDim2.new(1,-36,0,28);title.Text="PRACTICE TUNING";title.TextColor3=Color3.fromHex("FFFFFF");title.TextSize=22;title.Font=Enum.Font.GothamBlack;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=panel
	local sub=Instance.new("TextLabel");sub.BackgroundTransparency=1;sub.Position=UDim2.fromOffset(18,45);sub.Size=UDim2.new(1,-36,0,18);sub.Text="LIVE GOALKEEPER + SHOOTING SLIDERS";sub.TextColor3=Color3.fromHex("B7FF1A");sub.TextSize=11;sub.Font=Enum.Font.GothamBold;sub.TextXAlignment=Enum.TextXAlignment.Left;sub.Parent=panel
	local reset=Instance.new("TextButton");reset.Name="ResetShot";reset.BackgroundColor3=Color3.fromHex("B7FF1A");reset.BorderSizePixel=0;reset.Position=UDim2.fromOffset(18,73);reset.Size=UDim2.new(.5,-24,0,34);reset.Text="RESET SHOT";reset.TextColor3=Color3.fromHex("050705");reset.TextSize=14;reset.Font=Enum.Font.GothamBlack;reset.AutoButtonColor=true;reset.Parent=panel
	local resetCorner=Instance.new("UICorner");resetCorner.CornerRadius=UDim.new(0,6);resetCorner.Parent=reset
	table.insert(self.PracticeTuningConnections,reset.Activated:Connect(function()self:_requestPracticeReset()end))
	local output=Instance.new("TextButton");output.Name="OutputDefaults";output.BackgroundColor3=Color3.fromHex("1F271F");output.BorderSizePixel=0;output.Position=UDim2.new(.5,6,0,73);output.Size=UDim2.new(.5,-24,0,34);output.Text="OUTPUT";output.TextColor3=Color3.fromHex("B7FF1A");output.TextSize=14;output.Font=Enum.Font.GothamBlack;output.AutoButtonColor=true;output.Parent=panel
	local outputCorner=Instance.new("UICorner");outputCorner.CornerRadius=UDim.new(0,6);outputCorner.Parent=output
	local outputStroke=Instance.new("UIStroke");outputStroke.Color=Color3.fromHex("B7FF1A");outputStroke.Transparency=.45;outputStroke.Thickness=1;outputStroke.Parent=output
	local outputBox=Instance.new("TextBox");outputBox.Name="DefaultsOutput";outputBox.BackgroundColor3=Color3.fromHex("080A08");outputBox.BackgroundTransparency=.08;outputBox.BorderSizePixel=0;outputBox.ClearTextOnFocus=false;outputBox.MultiLine=true;outputBox.TextEditable=false;outputBox.TextWrapped=true;outputBox.TextXAlignment=Enum.TextXAlignment.Left;outputBox.TextYAlignment=Enum.TextYAlignment.Top;outputBox.Position=UDim2.fromOffset(18,115);outputBox.Size=UDim2.new(1,-36,0,58);outputBox.Text="OUTPUT CURRENT DEFAULTS HERE";outputBox.TextColor3=Color3.fromHex("D9D9D9");outputBox.TextSize=10;outputBox.Font=Enum.Font.Code;outputBox.Parent=panel
	local outputBoxCorner=Instance.new("UICorner");outputBoxCorner.CornerRadius=UDim.new(0,6);outputBoxCorner.Parent=outputBox
	table.insert(self.PracticeTuningConnections,output.Activated:Connect(function()
		local text=formatPracticeDefaults(self.PracticeTuning)
		outputBox.Text=text
		print("[VTR SHOOTING PRACTICE DEFAULTS] "..text)
		if self.HUD then self.HUD:Flash("DEFAULTS OUTPUT",.75)end
	end))
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
		for _,name in LiteConfig.TacticSliderNames do table.insert(parts,name.."="..tostring(math.floor(tonumber(tactics.Sliders[name])or 50)))end
		return side.."={Identity=\""..tostring(tactics.Identity or"Balanced").."\",Sliders={"..table.concat(parts,",").."}}"
	end
	return"RuntimeAITactics={"..sideBlock("Home")..","..sideBlock("Away").."}"
end
function Controller:_sendRuntimeTactics(side:string)
	if self.Action then self.Action:FireServer({Type="AITacticsDebug",Side=side,Tactics=self.RuntimeTactics[side],Debug=self.TacticalDebugOptions})end
end
function Controller:_toggleTacticalMode()
	self.TacticalMode=not self.TacticalMode
	if self.TacticalOverlay then self.TacticalOverlay.Visible=self.TacticalMode end
	if self.Camera and self.Camera.SetTacticalView then self.Camera:SetTacticalView(self.TacticalMode)end
	if not self.TacticalMode then
		self.TacticalDebugOptions={}
		self:_sendRuntimeTactics(self.TacticalSide)
	end
end
function Controller:_createTacticalPanel()
	if not self.HUD or not self.HUD.Gui then return end
	local old=self.HUD.Gui:FindFirstChild("AITacticalTuner");if old then old:Destroy()end
	local overlay=Instance.new("Frame");overlay.Name="AITacticalTuner";overlay.BackgroundTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.Visible=false;overlay.ZIndex=180;overlay.Parent=self.HUD.Gui;self.TacticalOverlay=overlay
	local hint=Instance.new("TextLabel");hint.BackgroundColor3=Color3.fromHex("0A0D08");hint.BackgroundTransparency=.12;hint.BorderSizePixel=0;hint.Position=UDim2.fromOffset(18,104);hint.Size=UDim2.fromOffset(300,28);hint.Text="AI TUNER  /  6 EXIT";hint.TextColor3=Color3.fromHex("B7FF1A");hint.TextSize=10;hint.Font=Enum.Font.GothamBlack;hint.TextXAlignment=Enum.TextXAlignment.Left;hint.ZIndex=181;hint.Parent=overlay;local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,12);pad.Parent=hint
	local toggle=Instance.new("TextButton");toggle.AnchorPoint=Vector2.new(1,0);toggle.BackgroundColor3=Color3.fromHex("FFFFFF");toggle.BorderSizePixel=0;toggle.Position=UDim2.new(1,-18,0,104);toggle.Size=UDim2.fromOffset(92,28);toggle.Text="HIDE";toggle.TextColor3=Color3.fromHex("111111");toggle.TextSize=10;toggle.Font=Enum.Font.GothamBlack;toggle.ZIndex=184;toggle.Parent=overlay
	local panel=Instance.new("Frame");panel.AnchorPoint=Vector2.new(1,.5);panel.BackgroundColor3=Color3.fromHex("070A06");panel.BackgroundTransparency=.06;panel.BorderSizePixel=0;panel.Position=UDim2.new(1,-18,.5,16);panel.Size=UDim2.fromOffset(330,500);panel.ZIndex=182;panel.Parent=overlay;self.TacticalPanel=panel;local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("FFFFFF");stroke.Thickness=1;stroke.Transparency=.25;stroke.Parent=panel
	toggle.Activated:Connect(function()self.TacticalPanelOpen=not self.TacticalPanelOpen;panel.Visible=self.TacticalPanelOpen;toggle.Text=self.TacticalPanelOpen and"HIDE"or"SHOW"end)
	self:_renderTacticalPanel()
end
function Controller:_renderTacticalPanel()
	local panel=self.TacticalPanel;if not panel then return end
	for _,child in panel:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(14,10);title.Size=UDim2.new(1,-28,0,22);title.Text="LIVE AI";title.TextColor3=Color3.new(1,1,1);title.TextSize=15;title.Font=Enum.Font.GothamBlack;title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=183;title.Parent=panel
	local status=Instance.new("TextLabel");status.BackgroundTransparency=1;status.Position=UDim2.fromOffset(14,32);status.Size=UDim2.new(1,-28,0,16);status.Text=self.TacticalSide.." SELECTED";status.TextColor3=Color3.fromHex("B7FF1A");status.TextSize=8;status.Font=Enum.Font.GothamBold;status.TextXAlignment=Enum.TextXAlignment.Left;status.ZIndex=183;status.Parent=panel;self.TacticalStatus=status
	for index,side in ipairs({"Home","Away"})do local tab=Instance.new("TextButton");tab.BackgroundColor3=side==self.TacticalSide and Color3.fromHex("FFFFFF")or Color3.fromHex("1B2118");tab.BorderSizePixel=0;tab.Position=UDim2.fromOffset(14+(index-1)*82,56);tab.Size=UDim2.fromOffset(76,26);tab.Text=string.upper(side);tab.TextColor3=side==self.TacticalSide and Color3.fromHex("111111")or Color3.fromHex("F5F7F2");tab.TextSize=10;tab.Font=Enum.Font.GothamBlack;tab.ZIndex=184;tab.Parent=panel;tab.Activated:Connect(function()self.TacticalSide=side;self:_renderTacticalPanel()end)end
	local output=Instance.new("TextButton");output.BackgroundColor3=Color3.fromHex("2A351F");output.BorderSizePixel=0;output.Position=UDim2.new(1,-100,0,56);output.Size=UDim2.fromOffset(86,26);output.Text="OUTPUT";output.TextColor3=Color3.fromHex("FFFFFF");output.TextSize=10;output.Font=Enum.Font.GothamBlack;output.ZIndex=184;output.Parent=panel
	local box=Instance.new("TextBox");box.BackgroundColor3=Color3.fromHex("10140E");box.BackgroundTransparency=.1;box.BorderSizePixel=0;box.ClearTextOnFocus=false;box.MultiLine=true;box.Position=UDim2.fromOffset(14,90);box.Size=UDim2.new(1,-28,0,42);box.Text="OUTPUT copies current values here.";box.TextColor3=Color3.fromHex("D9D9D9");box.TextSize=7;box.Font=Enum.Font.Code;box.TextXAlignment=Enum.TextXAlignment.Left;box.TextYAlignment=Enum.TextYAlignment.Top;box.ZIndex=184;box.Parent=panel;self.TacticalOutput=box
	output.Activated:Connect(function()local text=self:_formatRuntimeTactics();print("[VTR AI TUNER] "..text);box.Text=text;status.Text="OUTPUT PRINTED BELOW"end)
	local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(14,142);list.Size=UDim2.new(1,-28,1,-154);list.CanvasSize=UDim2.new();list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.ScrollBarThickness=3;list.ScrollBarImageColor3=Color3.fromHex("B7FF1A");list.ZIndex=183;list.Parent=panel
	local y=0
	for _,name in LiteConfig.TacticSliderNames do
		local tactics=self.RuntimeTactics[self.TacticalSide];tactics.Sliders[name]=tonumber(tactics.Sliders[name])or 50;local value=math.floor(tactics.Sliders[name])
		local row=Instance.new("Frame");row.BackgroundTransparency=1;row.Position=UDim2.fromOffset(0,y);row.Size=UDim2.new(1,-4,0,30);row.ZIndex=184;row.Parent=list
		local group=TACTIC_DEBUG_GROUPS[name]or"Shape"
		local check=Instance.new("TextButton");check.BackgroundColor3=self.TacticalDebugOptions[group]and Color3.fromHex("B7FF1A")or Color3.fromHex("171D14");check.BorderSizePixel=0;check.Position=UDim2.fromOffset(0,5);check.Size=UDim2.fromOffset(22,20);check.Text=self.TacticalDebugOptions[group]and"✓"or"";check.TextColor3=Color3.fromHex("111111");check.TextSize=13;check.Font=Enum.Font.GothamBlack;check.ZIndex=186;check.Parent=row
		local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(28,0);label.Size=UDim2.new(1,-142,0,14);label.Text=string.upper(name:gsub("(%u)"," %1"));label.TextColor3=Color3.fromHex("E8E8E8");label.TextSize=7;label.Font=Enum.Font.GothamBold;label.TextXAlignment=Enum.TextXAlignment.Left;label.ZIndex=185;label.Parent=row
		local groupLabel=Instance.new("TextLabel");groupLabel.BackgroundTransparency=1;groupLabel.Position=UDim2.fromOffset(28,13);groupLabel.Size=UDim2.fromOffset(54,12);groupLabel.Text=string.upper(group);groupLabel.TextColor3=Color3.fromHex("7F8D73");groupLabel.TextSize=6;groupLabel.Font=Enum.Font.GothamBold;groupLabel.TextXAlignment=Enum.TextXAlignment.Left;groupLabel.ZIndex=185;groupLabel.Parent=row
		local bar=Instance.new("Frame");bar.BackgroundColor3=Color3.fromHex("20251C");bar.BorderSizePixel=0;bar.Position=UDim2.fromOffset(84,18);bar.Size=UDim2.new(1,-194,0,5);bar.ZIndex=185;bar.Parent=row;local fill=Instance.new("Frame");fill.BackgroundColor3=Color3.fromHex("B7FF1A");fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(value/100,1);fill.ZIndex=186;fill.Parent=bar
		local number=Instance.new("TextLabel");number.BackgroundTransparency=1;number.Position=UDim2.new(1,-70,0,5);number.Size=UDim2.fromOffset(30,20);number.Text=tostring(value);number.TextColor3=Color3.fromHex("FFFFFF");number.TextSize=9;number.Font=Enum.Font.GothamBlack;number.ZIndex=186;number.Parent=row
		local function bump(amount:number)
			local current=tonumber(tactics.Sliders[name])or 50
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)then amount*=2 end
			local nextValue=math.clamp(current+amount,0,100)
			tactics.Sliders[name]=nextValue
			number.Text=tostring(math.floor(nextValue))
			fill.Size=UDim2.fromScale(nextValue/100,1)
			self:_sendRuntimeTactics(self.TacticalSide)
			if self.TacticalStatus then self.TacticalStatus.Text=string.upper(name).." = "..tostring(math.floor(nextValue))end
		end
		local minus=Instance.new("TextButton");minus.BackgroundColor3=Color3.fromHex("1B2118");minus.BorderSizePixel=0;minus.Position=UDim2.new(1,-102,0,5);minus.Size=UDim2.fromOffset(24,20);minus.Text="-";minus.TextColor3=Color3.new(1,1,1);minus.TextSize=11;minus.Font=Enum.Font.GothamBlack;minus.ZIndex=186;minus.Parent=row;minus.Activated:Connect(function()bump(-5)end)
		local plus=Instance.new("TextButton");plus.BackgroundColor3=Color3.fromHex("1B2118");plus.BorderSizePixel=0;plus.Position=UDim2.new(1,-34,0,5);plus.Size=UDim2.fromOffset(24,20);plus.Text="+";plus.TextColor3=Color3.new(1,1,1);plus.TextSize=11;plus.Font=Enum.Font.GothamBlack;plus.ZIndex=186;plus.Parent=row;plus.Activated:Connect(function()bump(5)end)
		check.Activated:Connect(function()
			self.TacticalDebugOptions[group]=not self.TacticalDebugOptions[group]or nil
			self:_sendRuntimeTactics(self.TacticalSide)
			self:_renderTacticalPanel()
		end)
		y+=32
	end
end
function Controller:_activate(data:any)
	clearGreenScreenEffects()
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
	local bootCover = Instance.new("ScreenGui")
	bootCover.Name = "VTRMatchBootCover"
	bootCover.IgnoreGuiInset = true
	bootCover.ResetOnSpawn = false
	bootCover.DisplayOrder = 2200
	bootCover.Parent = player:WaitForChild("PlayerGui")
	local bootFrame = Instance.new("Frame")
	bootFrame.BackgroundColor3 = Color3.fromHex("020402")
	bootFrame.BorderSizePixel = 0
	bootFrame.Size = UDim2.fromScale(1, 1)
	bootFrame.Parent = bootCover
	task.spawn(function()
		if data.PracticeMode==true then
			task.wait(.25)
			if bootCover.Parent then bootCover:Destroy()end
			return
		end
		local started=os.clock()
		while bootCover.Parent and os.clock()-started<8 do
			if player.PlayerGui:FindFirstChild("VTRPrematchBroadcast") then
				task.wait(.45)
				break
			end
			task.wait(.05)
		end
		if bootCover.Parent then bootCover:Destroy() end
	end)
	self.Active=true;self.MatchStartKey=activationKey;self.ActivatingMatchKey=nil;self.MatchActivationRunningKey=nil;self.Ball=ball;self.TeamModels=data.TeamModels;self.ControlledSide=data.ControlledSide or"Home";self.WatchMode=data.WatchMode==true;self.PracticeMode=data.PracticeMode==true;self.Paused=false;self.Ranked=data.Ranked==true;self.MatchInPlay=self.PracticeMode;self.PrematchActive=not self.PracticeMode;self.PrematchSkipRequested=false;self.PrematchSkipUnlockAt=os.clock()+math.max(0,tonumber(data.PrematchSkipDelay)or 5);self.TacticalMode=false;self.TacticalPanelOpen=false;GuiService.SelectedObject=nil;local playerModule=require(player.PlayerScripts:WaitForChild("PlayerModule", 15));self.Controls=playerModule:GetControls();self.Controls:Disable();self.HUD=MatchHUDController.new(data);if self.HUD and self.HUD.SetSecondHalfResetCallback then self.HUD:SetSecondHalfResetCallback(function()if self.Action then self.Action:FireServer({Type="SecondHalfWatchdogReset"})end;if self.Camera and self.Camera.ReturnToLive then self.Camera:ReturnToLive()elseif self.Camera and self.Camera.EndCutscene then self.Camera:EndCutscene()end;if self.HUD then self.HUD:Flash("RESETTING SECOND HALF",1.0)end end)end;self.Commentary=nil;self.Celebrations=CelebrationPoseController.new();self.CrowdAmbience=CrowdAmbienceController.new();self.CrowdAmbience:Start();self.MatchSounds=MatchSoundController.new(ball,data.TeamModels);self.MatchSounds:Start();self.Camera=BroadcastCameraController.new(data.PitchCFrame,data.PitchWidth,data.PitchLength,ball,active);self.MouseAim=MouseAimController.new(workspace.CurrentCamera,data.PitchCFrame,data.PitchWidth,data.PitchLength);self.Input=InputController.new(self.Action,function(kind,charge)return self:_aimPayload(kind,charge)end);self.InputLock=MatchInputLockController.new(self.Action);self.TeamControl=TeamControlController.new(self.Action,self.Camera,self.HUD,active);self.BallRoll=BallRollVisualController.new(ball)
	self.HUD:SetPauseButtonCallback(function()self:_setPaused(true)end)
	if self.WatchMode then
		if self.ControlledIndicator then self.ControlledIndicator:Destroy();self.ControlledIndicator=nil end
	elseif not self.ControlledIndicator then
		self.ControlledIndicator=VoltraControlledPlayerIndicator.new(function()
			if self.WatchMode or not self.MatchInPlay or self.PrematchActive then return nil end
			if self.ActiveModel and tostring(self.ActiveModel:GetAttribute("VTRTeam")or"")~=tostring(self.ControlledSide or"")then return nil end
			return self.ActiveModel
		end)
	end
	self.HUD:SetManualSubstitutionCallback(function(benchIndex:number,outgoingModel:Model,outgoingName:string)
		self.Action:FireServer({Type="ManualSubstitution",BenchIndex=benchIndex,OutgoingModel=outgoingModel,OutgoingName=outgoingName})
	end)
	self.HUD:SetManualPositionSwapCallback(function(modelA:Model,modelB:Model)
		self.Action:FireServer({Type="ManualPositionSwap",ModelA=modelA,ModelB=modelB})
	end)
	local uiState=UIStateService:Get();local settings=uiState and uiState.Settings or {};settings.ManualPassKey=settings.ManualPassKey or "LeftControl";settings.LobbedPassKey=settings.LobbedPassKey or "LeftAlt";settings.ChangePlayerKey=settings.ChangePlayerKey or "Q";settings.TackleKey=settings.TackleKey or "E";settings.SlideTackleKey=settings.SlideTackleKey or "F";self.PauseKey=keyCodeFromSetting(settings.PauseKey,Enum.KeyCode.M);self.Input:SetAutoSwitch(UserInputService.TouchEnabled and "Instant" or settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(UserInputService.TouchEnabled and "Assisted" or settings.ReceiverAssist or "Light");if self.Input.SetControlsSettings then self.Input:SetControlsSettings(settings)end;if self.Input.SetShotModeChanged then self.Input:SetShotModeChanged(function(mode)if self.HUD and self.HUD.SetShotMode then self.HUD:SetShotMode(mode)end end)end;self.Indicators=PlayerIndicatorController.new(data.TeamModels,ball,self.HUD,"Off");self.Trainer=TrainerController.new(self.HUD.Gui,ball,settings.Trainer or "Basic");self.Minimap=MinimapController.new(self.HUD.Gui,data.PitchCFrame,data.PitchWidth,data.PitchLength,data.TeamModels,ball,settings.Minimap or "Medium",settings.MinimapOrientation or "Broadcast",settings.CameraSide or "Near",self.ControlledSide);self.AimLine=AimLineController.new(data.TeamModels,ball);self.GoalTarget=GoalReticleController.new(workspace.CurrentCamera,ball);self.FlightMarker=BallFlightMarkerController.new(ball);self.Cutscenes=MatchCutsceneController.new(self.Camera,self.HUD);self.Camera:SetMode(settings.CameraPreset or "Broadcast");self.Camera:ApplySettings(settings);if self.PracticeMode and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true);self:_createPracticeTuningPanel()end
	self.AnimationCache={};for _,side in data.TeamModels do for _,footballer in side do self.AnimationCache[footballer]=AnimationController.new(footballer)end end
	if self.ReplayController then self.ReplayController:Destroy()end;self.ReplayController=ReplayController.new(data,ball)
	self.HUD:SetResumeCallback(function()self:_setPaused(false)end);ContextActionService:BindActionAtPriority(PAUSE_ACTION,function(_,state)if state==Enum.UserInputState.Begin and self.Active then self:_setPaused(not self.Paused)end;return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+200,Enum.KeyCode.ButtonSelect,Enum.KeyCode.ButtonStart);self.PauseConnection=UserInputService.InputBegan:Connect(function(input,processed)
		if not self.Active then return end
		if input.KeyCode==(self.PauseKey or Enum.KeyCode.M) then self:_setPaused(not self.Paused);return end
		if input.KeyCode==Enum.KeyCode.One and not processed and self.Camera and self.Camera.ToggleShootingFocus and self.MatchInPlay and not self.Paused and self.WatchMode~=true then
			local enabled=self.Camera:ToggleShootingFocus()
			if self.HUD then self.HUD:Flash(enabled and"SHOOTING FOCUS CAMERA"or"WIDE BROADCAST CAMERA",.75)end
			return
		end
		if (input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.ButtonA) and self.PrematchActive and not self.PrematchSkipRequested then local remaining=math.ceil((tonumber(self.PrematchSkipUnlockAt)or 0)-os.clock());if remaining>0 then if self.HUD then self.HUD:Flash("SKIP IN "..tostring(remaining),.55)end;return end;self.PrematchSkipRequested=true;self.Action:FireServer({Type="PrematchSkip"});self:_setPrematchSkipProgress(1,self.Ranked and 2 or 1);if self.HUD then self.HUD:Flash(self.Ranked and"SKIP QUEUED"or"SKIPPING INTRO",.9)end;return end
	end)
	self.Camera:Start();if not self.PracticeMode then if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data)end;self.InputLock:Start();self.Input:Start();if self.Input and self.Input.SetShootingOnly then self.Input:SetShootingOnly(self.PracticeMode)end;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.PracticeMode and self.WatchMode~=true or false)end;if self.WatchMode then self.Input:SetSuppressed(true);if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"));if self.PracticeMode then if self.GoalTarget then self.GoalTarget:SetMode("Shot");self.GoalTarget:SetDefenseSource(nil);self.GoalTarget:SetMatchActive(self.WatchMode~=true);local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end end;if self.HUD then self.HUD:SetPhase("SHOOTING PRACTICE")end;self:_emitPracticeTuning(true)end
	task.spawn(function()
		while self.Active do
			clearGreenScreenEffects()
			task.wait(.35)
		end
	end)
	RunService:BindToRenderStep("VTRMatchGameplay",Enum.RenderPriority.Camera.Value+1,function(dt)self:_update(dt)end)
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
	if VTRCameraIgnoreDribbleImpulse(self and self.Ball or self and self.World and self.World.Ball or workspace:FindFirstChild(\"Ball\", true)) then return end
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
	self.Camera:Update(dt)
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
		end
		self.MouseAim:SetForcedGoalSign(forcedGoalSign)
	end
	self.MouseAim:Update()
	local root=self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?
	local ownerName=tostring(self.Ball:GetAttribute("OwnerModel")or"")
	local attackingSetPiece=self.SetPieceKind=="FreeKick"or self.SetPieceMode=="DirectShotFreeKick"or self.SetPieceKind=="Penalty"or self.SetPieceKind=="ThrowIn"or self.SetPieceMode=="ThrowIn"or self.SetPieceKind=="GoalKick"or self.SetPieceMode=="GoalKick"
	local hasBall=ownerName==self.ActiveModel.Name or self.SetPieceMode=="PenaltyDefense"or attackingSetPiece
	local passReceiver=tostring(self.Ball:GetAttribute("VTRPassReceiver")or"")
	local passAge=os.clock()-(tonumber(self.Ball:GetAttribute("VTRPassStartedAt"))or 0)
	local receivingPass=not hasBall and passReceiver~="" and passReceiver==self.ActiveModel.Name and passAge>=0 and passAge<5.8
	if self.Input and self.Input.SetActionContext then self.Input:SetActionContext(hasBall,receivingPass)end
	if self.Input and self.Input.SetMobileDefending then self.Input:SetMobileDefending(not(hasBall or receivingPass or attackingSetPiece))end
	local charge=self.Input:ChargeValue()
	local chargeKind=self.Input:ChargeKind()
	local aimingAtGoal=self.MouseAim:IsAimingAtGoal()
	local goalPoint=self.MouseAim:GetGoalAimPoint(chargeKind=="Shot"and charge or 0)
	local aimPosition=aimingAtGoal and goalPoint or self.MouseAim:GetAimWorldPosition()
	local shotOnTarget:boolean?=aimingAtGoal
	if self.PracticeMode and root and hasBall then
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
	if self.PracticeMode and root and hasBall and not aimingAtGoal then
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
	self.Indicators:SetPassTarget(preview,self.AimLine:IsTargetFallback())
	local shotReticleContext=self.PracticeMode or aimingAtGoal or self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense"or self.SetPieceMode=="DirectShotFreeKick"
	if self.PracticeMode and hasBall and aimPosition and self.GoalTarget then
		self.GoalTarget:Lock(aimPosition)
	end
	self.GoalTarget:Update(hasBall,shotReticleContext,aimingAtGoal or self.PracticeMode,aimPosition)
	if self.Trainer and not UserInputService.TouchEnabled then
		self.Trainer:SetBusy(chargeKind~=""or self.ActiveModel:GetAttribute("VTRSprinting")==true)
		self.Trainer:Update()
	end
	self.Minimap:Update(dt)
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
	local input=self.WatchMode and Vector2.zero or self.Input:Move();if not self.WatchMode then self.TeamControl:Update(dt,input)end;local movement=self.Camera:Movement(input);local sprinting=self.ActiveModel:GetAttribute("VTRSprinting")==true;self.Visual:Update(dt,movement,sprinting);self.BallRoll:Update(dt,hasBall);if self.FlightMarker then self.FlightMarker:Update(dt)end;if not(self.ActiveModel:GetAttribute("VTRCelebrating")==true or self.ActiveModel:GetAttribute("VTRCelebratingLocal")==true)then if root and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>.6 then self.Animation:Play(hasBall and"Dribble"or(sprinting and"Sprint"or"Jog"))else self.Animation:Play("Idle")end end;self:_updateTeamAnimations();self.HUD:SetStamina(self.Stamina/Config.Stamina.Maximum,self.Endurance/Config.Stamina.Maximum);self.HUD:SetCharge(charge,chargeKind);local owner=self.Ball:GetAttribute("OwnerModel");self.HUD:SetState(self.WatchMode and"WATCHING AI VS AI"or(owner==self.ActiveModel.Name and(sprinting and"Sprinting"or"Dribbling")or owner==""and"Loose Ball"or"Defending"))
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
function Controller:_finishGoalPresentation(payload:any)
	if not self.Active then return end
	if self.Action then self.Action:FireServer({Type="ReplayFinished"})end
	self.Cutscenes:Goal(payload)
	self:_flushReplayPayloads()
end
function Controller:_state(payload:any)
	if type(payload)~="table"then return end
	if self.Commentary then self.Commentary:HandleState(payload)end
	if payload.Type=="MatchStarted"then
		local key=matchStartKey(payload)
		if (self.Active and self.MatchStartKey==key)or self.ActivatingMatchKey==key or self.MatchActivationRunningKey==key then
			if workspace:GetAttribute("VTRKickoffDebug") ~= false then print("[VTR KICKOFF][Client] duplicate MatchStarted ignored",key)end
			return
		end
		self.ActivatingMatchKey=key
		local function activateOnce()
			if self.Active and self.MatchStartKey==key then return end
			if self.ActivatingMatchKey~=key then return end
			self:_activate(payload)
		end
		if workspace:GetAttribute("VTRKickoffDebug") ~= false then print("[VTR KICKOFF][Client] MatchStarted received; activating match camera", "ranked", payload.Ranked==true, "active", payload.ActivePlayer and payload.ActivePlayer.Name or "nil")end
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
	if self.ReplayBlocking and payload.Type~="Goal"then
		if payload.Type=="Clock"then
			self.ReplayQueuedClock=payload
		else
			self.ReplayQueuedPayloads=self.ReplayQueuedPayloads or{}
			table.insert(self.ReplayQueuedPayloads,payload)
		end
		return
	end
	if payload.Type=="ActivePlayer"and payload.Model and payload.Model:IsA("Model")then if payload.Reason=="KickoffReceiver"and self.Input then self.Input:SetSuppressed(self.WatchMode==true)end;if workspace:GetAttribute("VTRKickoffDebug") ~= false then print("[VTR KICKOFF][Client] ActivePlayer",payload.Model.Name,"reason",payload.Reason or"","inputSuppressed",self.Input and self.Input.Suppressed)end;self:_bindFootballer(payload.Model,payload.Name,payload.Position);if payload.Reason=="PenaltyDefense"then self.SetPieceMode="PenaltyDefense";self.MatchInPlay=false;if typeof(payload.PenaltyLocation)=="Vector3"and self.Camera and self.Camera.BeginCutscene then self.Camera:BeginCutscene("Penalty",payload.PenaltyLocation,45,typeof(payload.GoalPosition)=="Vector3"and payload.GoalPosition or nil)end;if self.AimLine then self.AimLine:SetMatchActive(true)end;if self.GoalTarget then self.GoalTarget:SetMatchActive(true);self.GoalTarget:SetMode("PenaltyDefense");self.GoalTarget:SetDefenseSource(payload.Model)end end
	elseif payload.Type=="PauseQueued"then self.HUD:ShowPauseQueue(Players.LocalPlayer.Name,true)
	elseif payload.Type=="PauseQueue"then self.HUD:ShowPauseQueue(tostring(payload.PlayerName or"PLAYER"),payload.Queued==true)
	elseif payload.Type=="PauseState"then payload.ControlledSide=self.ControlledSide;self.Paused=payload.Paused==true;self.InputLock:SetSprintEnabled(not self.Paused);local visible=not self.Paused and self.MatchInPlay==true;if self.Trainer then self.Trainer:SetMatchActive(not UserInputService.TouchEnabled and visible)end;self.Minimap:SetMatchActive(visible);self.AimLine:SetMatchActive(visible);self.GoalTarget:SetMatchActive(visible);self.HUD:SetPaused(self.Paused,self.Camera,function()self:_cleanup(true)end,payload,function()self.Action:FireServer({Type="Forfeit"})end)
	elseif payload.Type=="PauseTimer"then self.HUD:SetPauseTimer(payload.Remaining or 0)
	elseif payload.Type=="PauseResumeVote"then if payload.Ready~=true then self.HUD:Flash(tostring(payload.PlayerName or"PLAYER").." READY TO RESUME",1.0)end
	elseif payload.Type=="PrematchSkipLocked"then self.PrematchSkipRequested=false;if self.HUD then self.HUD:Flash("SKIP IN "..tostring(math.max(1,math.floor(tonumber(payload.Remaining)or 1))),.7)end
	elseif payload.Type=="PrematchSkipQueued"then self:_setPrematchSkipProgress(payload.ReadyCount,payload.TotalCount);if self.HUD then local total=math.max(1,math.floor(tonumber(payload.TotalCount)or 2));local count=math.clamp(math.floor(tonumber(payload.ReadyCount)or 1),0,total);self.HUD:Flash(payload.Ready and"INTRO SKIPPED"or(string.format("SKIP %d/%d",count,total)),1.0)end
	elseif payload.Type=="PrematchSkip"then self.PrematchActive=false;self.PrematchSkipRequested=true;if UISoundService.StopTransitions then UISoundService.StopTransitions()end;if self.Cutscenes then self.Cutscenes:SkipStadiumIntro()end;self:_playPrematchSkipTransition()
	elseif payload.Type=="PracticeReset"then self.PracticeMode=true;self.PrematchActive=false;self.MatchInPlay=true;self.Paused=false;self:_createPracticeTuningPanel();if payload.Shooter and payload.Shooter:IsA("Model")then self:_bindFootballer(payload.Shooter,payload.Shooter:GetAttribute("DisplayName"),payload.Shooter:GetAttribute("position"))end;if self.Input then if self.Input.SetShootingOnly then self.Input:SetShootingOnly(true)end;self.Input:SetSuppressed(false);if self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.WatchMode~=true)end end;if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(true)end;if self.MatchSounds then self.MatchSounds:SetMatchActive(true)end;if self.Trainer then self.Trainer:SetMatchActive(not UserInputService.TouchEnabled and self.WatchMode~=true)end;if self.Minimap then self.Minimap:SetMatchActive(true)end;if self.AimLine then self.AimLine:SetMatchActive(self.WatchMode~=true)end;if self.GoalTarget then self.GoalTarget:SetMode("Shot");self.GoalTarget:SetDefenseSource(nil);self.GoalTarget:SetMatchActive(self.WatchMode~=true);local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end end;if self.HUD then self.HUD:SetPhase("SHOOTING PRACTICE");if payload.Reason=="START"then self.HUD:Flash("SHOOTING PRACTICE",.9)end end;self:_emitPracticeTuning(true)
	elseif payload.Type=="PracticeShotResult"then local result=tostring(payload.Result or"MISS");self:_playPracticeResetTransition(result);if self.HUD then self.HUD:ResolveShotChance(result=="GOAL");self.HUD:Flash(result=="GOAL"and"GOAL"or result=="SAVE"and"SAVED"or"MISS",.85)end;if self.MatchSounds and result=="GOAL"and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end;if self.Visual then if result=="GOAL"then self.Visual:HoldShotTrail()else self.Visual:StopShotTrail()end end;if self.GoalTarget then self.GoalTarget:Unlock()end
	elseif payload.Type=="SwitchTarget"then self.TeamControl:SetSwitchTarget(payload.Model);self.Indicators:SetNextSwitch(payload.Model)
	elseif payload.Type=="Possession"then if self.HUD then self.HUD:SetPossession(payload.Owner or"",payload.OwnerUserId==Players.LocalPlayer.UserId)end;if self.Indicators then self.Indicators:SetBallCarrier(payload.Model)end;if self.Minimap then self.Minimap:SetBallCarrier(payload.Model)end;if payload.Model then if self.Visual then self.Visual:StopShotTrail()end;if self.GoalTarget then if self.PracticeMode and payload.Model==self.ActiveModel then local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end else self.GoalTarget:Unlock()end end end
	elseif payload.Type=="PassTarget"then self.Indicators:SetPassTarget(payload.Model)
	elseif payload.Type=="SetPiece"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted(payload.ActualKind or payload.Kind)end;local userRestart=payload.UserControlled==true and payload.WatchOnly~=true;if not userRestart then self:_ensureControlledSideActive()end;if self.Input and payload.Kind~="Corner" then self.Input:SetSuppressed(self.WatchMode==true or not userRestart)end;if self.Input and self.Input.SetDirectFreeKick then self.Input:SetDirectFreeKick(userRestart and payload.Mode=="DirectShotFreeKick")elseif self.Input and self.Input.ResetFreeKickModifiers and payload.Mode=="DirectShotFreeKick"then self.Input:ResetFreeKickModifiers()end;local actualKind=payload.ActualKind or payload.Kind;if userRestart and self.Input and self.Input.LockActions and (actualKind=="FreeKick"or actualKind=="Penalty"or actualKind=="ThrowIn"or actualKind=="GoalKick")then self.Input:LockActions(2)end;self.SetPieceGoalSign=userRestart and payload.GoalSign or nil;self.PenaltyAimSlot=userRestart and actualKind=="Penalty"and"MIDDLE"or self.PenaltyAimSlot;self.PenaltyAimPoint=userRestart and actualKind=="Penalty"and nil or self.PenaltyAimPoint;self.GamepadShotAimPoint=nil;self.FreeKickAimVector=userRestart and payload.Mode=="DirectShotFreeKick"and Vector2.new(0,.22)or self.FreeKickAimVector;local mobileRestart=(actualKind=="FreeKick"or actualKind=="ThrowIn"or actualKind=="Penalty"or actualKind=="GoalKick")and userRestart;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(mobileRestart and self.WatchMode~=true)end;self.MatchInPlay=false;self.SetPieceMode=userRestart and payload.Mode or nil;self.SetPieceKind=userRestart and actualKind or nil;if payload.Kind=="Offside"and self.HUD then self.HUD:Flash("OFFSIDE",1.05)end;if userRestart and payload.Taker and payload.Taker:IsA("Model")then self:_bindFootballer(payload.Taker,payload.Taker:GetAttribute("DisplayName"),payload.Taker:GetAttribute("position"))end;if self.Visual then self.Visual:ClearLock();self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Trainer then self.Trainer:SetMatchActive(false)end;self.Minimap:SetMatchActive(true);local aimingRestart=mobileRestart and self.WatchMode~=true;self.AimLine:SetMatchActive(aimingRestart);self.GoalTarget:SetMatchActive(aimingRestart);if actualKind=="Kickoff"then self.PendingKickoffSound=true;self.PendingFoulRestartWhistle=false;if self.Camera and self.Camera.ReturnToLive then self.Camera:ReturnToLive()end else self.PendingKickoffSound=false end;if self.FoulRestartWhistlePending and (actualKind=="FreeKick"or actualKind=="Penalty")then self.PendingFoulRestartWhistle=true;self.FoulRestartWhistlePending=false elseif actualKind~="FreeKick"and actualKind~="Penalty"then self.FoulRestartWhistlePending=false end;if payload.Kind=="Kickoff"and self.HUD then self.HUD:PlayMatchHudIntro();self.HUD:ShowKickoffScorer()end;self.Cutscenes:Play(payload)
	elseif payload.Type=="CornerMode"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted("Corner")end;self.Input:SetSuppressed(true);local takerAnimation=self.AnimationCache and self.AnimationCache[payload.Taker];if takerAnimation then takerAnimation:Play("Idle")end;if self.CornerAim then self.CornerAim:Destroy()end;if self.CornerCamera then self.CornerCamera:Destroy()end;self.CornerCamera=CornerCameraController.new(payload);self.CornerAim=CornerAimController.new(payload,self.Action,self.HUD);self.HUD:SetPhase("CORNER KICK")
	elseif payload.Type=="CornerReleased"then self.Input:SetSuppressed(false);if self.CornerAim then self.CornerAim:Destroy();self.CornerAim=nil end;if self.CornerCamera then self.CornerCamera:Destroy();self.CornerCamera=nil end;self.HUD:Flash(string.upper(payload.Delivery or"CROSS"),.7)
	elseif payload.Type=="Phase"then self.PrematchActive=false;if self.Input then if self.Input.SetShootingOnly then self.Input:SetShootingOnly(payload.Phase=="SHOOTING PRACTICE")end;self.Input:SetSuppressed(self.WatchMode==true);if self.Input.SetDirectFreeKick then self.Input:SetDirectFreeKick(false)end end;if workspace:GetAttribute("VTRKickoffDebug") ~= false then print("[VTR KICKOFF][Client] Phase",payload.Phase or"nil","active",self.ActiveModel and self.ActiveModel.Name or"nil","inputSuppressed",self.Input and self.Input.Suppressed)end;if self.Camera and payload.HoldCutscene~=true then if payload.Phase=="IN PLAY"and self.Camera.ReturnToLive then self.Camera:ReturnToLive()elseif self.Camera.EndCutscene then self.Camera:EndCutscene()end end;if self.Visual then self.Visual:ClearLock()end;self.SetPieceMode=nil;self.SetPieceKind=nil;self.SetPieceGoalSign=nil;self.PenaltyAimSlot=nil;self.PenaltyAimPoint=nil;self.GamepadShotAimPoint=nil;self.MatchInPlay=payload.Phase=="IN PLAY"or payload.Phase=="SHOOTING PRACTICE";if payload.Phase=="SHOOTING PRACTICE"then self.PracticeMode=true;self:_createPracticeTuningPanel();if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true)end end;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.MatchInPlay and self.WatchMode~=true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;if self.MatchSounds then self.MatchSounds:SetMatchActive(self.MatchInPlay)end;if self.Trainer then self.Trainer:SetMatchActive(not UserInputService.TouchEnabled and self.MatchInPlay and self.WatchMode~=true)end;self.Minimap:SetMatchActive(self.MatchInPlay);self.AimLine:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);self.GoalTarget:SetMode("Shot");self.GoalTarget:SetDefenseSource(nil);self.GoalTarget:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);if self.PracticeMode and self.MatchInPlay then local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end end;self.HUD:SetPhase(payload.Phase or"IN PLAY")
	elseif payload.Type=="HalfTime"then self:_resetSecondHalfWatchdog();if self.HUD and self.HUD.SetSecondHalfResetVisible then self.HUD:SetSecondHalfResetVisible(false)end;self.MatchInPlay=false;self.HalfTimePauseActive=true;self.Paused=true;if self.Trainer then self.Trainer:SetMatchActive(false)end;self.Minimap:SetMatchActive(false);self.AimLine:SetMatchActive(false);self.GoalTarget:SetMatchActive(false);self.Cutscenes:HalfTime(payload);payload.ControlledSide=self.ControlledSide;task.delay(12,function()if self.Active and self.HalfTimePauseActive and self.HUD then self.HUD:SetPaused(true,self.Camera,function()self:_cleanup(true)end,payload,function()self.Action:FireServer({Type="Forfeit"})end)end end)
	elseif payload.Type=="HalfTimeTimer"then if self.HUD then self.HUD:SetPauseTimer(payload.Remaining or 0)end
	elseif payload.Type=="HalfTimeResumeVote"then if self.HUD and payload.Ready~=true then self.HUD:Flash(tostring(payload.PlayerName or"PLAYER").." READY FOR SECOND HALF",1.0)end
	elseif payload.Type=="HalfTimeResume"then self.HalfTimePauseActive=false;self.Paused=false;self:_startSecondHalfWatchdog();if self.Camera and self.Camera.ReturnToLive then self.Camera:ReturnToLive()elseif self.Camera and self.Camera.EndCutscene then self.Camera:EndCutscene()end;if self.HUD then self.HUD:ClearPause();if self.HUD.SetSecondHalfResetVisible then self.HUD:SetSecondHalfResetVisible(true)end end
	elseif payload.Type=="Pass"then if self.MatchSounds then if self.PendingKickoffSound then self.PendingKickoffSound=false;self.PendingFoulRestartWhistle=false;self.MatchSounds:PlayKickoff()else self.PendingFoulRestartWhistle=false;self.MatchSounds:PlayKick()end end;if self.HUD then self.HUD:HideKickoffScorer()end;if self.Visual then self.Visual:ClearLock();self.Visual:SnapTo(self.Ball.Position,self.Ball.AssemblyLinearVelocity);self.Visual:PlayFlightTrail()end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Pass")end
	elseif payload.Type=="CornerKick"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if self.Visual then self.Visual:PlayFlightTrail()end
	elseif payload.Type=="Shot"then self.PendingKickoffSound=false;if self.MatchSounds then self.PendingFoulRestartWhistle=false;self.MatchSounds:PlayKick()end;if (self.SetPieceKind=="FreeKick"or self.SetPieceKind=="Penalty") and self.Camera and self.Camera.EndCutscene then task.delay(self.SetPieceKind=="Penalty"and 1.15 or .35,function()if self.Camera then self.Camera:EndCutscene()end end)end;if self.CrowdAmbience then self.CrowdAmbience:Boost(0.9)end;if self.ReplayController then self.ReplayController:MarkShot(payload.Actor)end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if self.HUD then self.HUD:ShowShotChance({XG=payload.ShotQuality or payload.ShotXG or payload.ScoringChance or payload.ScoringChancePercent},payload.Actor)end;if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Shoot")end
	elseif payload.Type=="ReceiveBall"and payload.Model==self.ActiveModel then self.Animation:Play("Receive")
	elseif payload.Type=="Tackle"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Tackle")end;if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Tackle")end
	elseif payload.Type=="SlideTackle"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("SlideTackle")end;self.HUD:Flash("SLIDE TACKLE",.55)
	elseif payload.Type=="DribbleMove"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play(payload.Animation or"DribbleMove1")end
	elseif payload.Type=="Block"then if self.HUD then self.HUD:ResolveShotChance(false)end;self.HUD:Flash("SHOT BLOCKED",.6)
	elseif payload.Type=="Clearance"then self.PendingKickoffSound=false;self.PendingFoulRestartWhistle=false;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if payload.Actor==self.ActiveModel and payload.Actor:GetAttribute("position")~="GK"then self.HUD:Flash("BALL CLEARED",.55)end
	elseif payload.Type=="Foul"then self.FoulRestartWhistlePending=true;self.HUD:ShowFoulBanner(payload)
	elseif payload.Type=="Offside"then self.HUD:Flash("OFFSIDE",1.1)
	elseif payload.Type=="Substitution"then self.HUD:ShowSubstitution(payload)
	elseif payload.Type=="GoalkeeperSave"then if self.HUD then self.HUD:ResolveShotChance(false)end;if self.Visual then self.Visual:StopShotTrail();self.Visual:SnapTo(self.Ball.Position,Vector3.zero,.18);task.delay(.08,function()if self.Visual and self.Ball then self.Visual:SnapTo(self.Ball.Position,Vector3.zero,.14)end end)end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Camera and self.Camera.EndCutscene then task.delay(self.SetPieceKind=="Penalty"and .65 or 1.5,function()if self.Camera then self.Camera:EndCutscene()end end)end;self.HUD:Flash("GREAT SAVE",.9)
	elseif payload.Type=="GoalkeeperClaim"then if self.Visual then self.Visual:StopShotTrail();self.Visual:SnapTo(self.Ball.Position,Vector3.zero,.18);task.delay(.08,function()if self.Visual and self.Ball then self.Visual:SnapTo(self.Ball.Position,Vector3.zero,.14)end end)end;if self.GoalTarget then self.GoalTarget:Unlock()end
	elseif payload.Type=="GoalkeeperMiss"then if self.Camera and self.Camera.EndCutscene then task.delay(self.SetPieceKind=="Penalty"and .65 or 1.0,function()if self.Camera then self.Camera:EndCutscene()end end)end
	elseif payload.Type=="Clock"then workspace:SetAttribute("VTRMatchHalf",tonumber(payload.Half)or 1);self.MatchGameSeconds=tonumber(payload.GameSeconds)or self.MatchGameSeconds;if tonumber(payload.Half)~=2 then self:_resetSecondHalfWatchdog()end;if self.HUD and self.HUD.SetSecondHalfResetVisible then self.HUD:SetSecondHalfResetVisible((tonumber(payload.Half)or 1)==2 and (tonumber(payload.GameSeconds)or 0)<=3000 and self.HalfTimePauseActive~=true)end;self.Stamina=tonumber(payload.Stamina)or self.Stamina;self.Endurance=tonumber(payload.Endurance)or self.Endurance;self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:UpdateActiveRating()
	elseif payload.Type=="Kickoff"then if self.Visual then self.Visual:StopShotTrail()end;self.HUD:Flash("Kick Off",1)
	elseif payload.Type=="GoalSoundPreview"then if self.MatchSounds and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end
	elseif payload.Type=="GoalSoundPreview"then if self.MatchSounds and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end
	elseif payload.Type=="Goal"then if self.ReplayController and self.ReplayController.SealGoalClip then self.ReplayController:SealGoalClip()end;if self.MatchSounds then self.MatchSounds:PlayGoal(payload.GoalMusicId,payload.GoalMusicStart)end;if self.CrowdAmbience then self.CrowdAmbience:Boost(3.2)end;if self.HUD then self.HUD:ResolveShotChance(true)end;self.MatchInPlay=false;if self.Visual then self.Visual:ClearLock();self.Visual:HoldShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Trainer then self.Trainer:SetMatchActive(false)end;self.Minimap:SetMatchActive(false);self.AimLine:SetMatchActive(false);self.GoalTarget:SetMatchActive(false);if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(false)end;self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:RememberGoalScorer(payload);self.ReplayBlocking=true;self.ReplayQueuedPayloads={};self.ReplayQueuedClock=nil;local function playReplay()if not self.Active then return end;self:_hideGoalCelebrationOverlay();if self.Camera and self.Camera.EndCutscene then self.Camera:EndCutscene(true)end;if self.ReplayController then self.ReplayController:PlayGoalReplay(function()self:_finishGoalPresentation(payload)end)else self:_finishGoalPresentation(payload)end end;local function playCelebration()if not self.Active then return end;self:_showGoalCelebrationOverlay(payload);local celebrationId=tostring(payload.CelebrationId or"");if self.Celebrations and payload.ScorerModel and celebrationId~="" then local scorerAnimation=self.AnimationCache and self.AnimationCache[payload.ScorerModel];if scorerAnimation and scorerAnimation.Deactivate then scorerAnimation:Deactivate()end;self.Celebrations:PlayGoalPresentation(payload.ScorerModel,celebrationId,{PitchCFrame=self.Camera and self.Camera.PitchCFrame or CFrame.new(),Width=self.Camera and self.Camera.Width or 76,Length=self.Camera and self.Camera.Length or 742,Team=payload.Team,CameraController=self.Camera,LiveCharacter=true},playReplay)else playReplay()end end;self:_playGoalEffect(payload,playCelebration)
	elseif payload.Type=="FinalChance"then if self.HUD then self.HUD:ShowFinalChance(payload.Active~=false)end
	elseif payload.Type=="Info"then if payload.Important==true then self.HUD:Flash(payload.Message,1.3)end
	elseif payload.Type=="MatchEnded"then
		self:_hideGoalCelebrationOverlay()
		if self.MatchSounds then self.MatchSounds:PlayFinalWhistle()end
		RunService:UnbindFromRenderStep("VTRMatchGameplay")
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
		ContextActionService:UnbindAction(PAUSE_ACTION)
		if self.PauseConnection then self.PauseConnection:Disconnect();self.PauseConnection=nil end
		local function showResult()
			self.HUD:ShowResult(payload,function()self:_cleanup(true)end)
		end
		local function showRewardsThenResult()
			local rankedWin = payload.Ranked == true and (payload.Result == "Win" or payload.Result == "ForfeitWin")
			if rankedWin and self.HUD and self.HUD.Gui then
				VoltraPackRoulette.Play(self.HUD.Gui,payload,showResult)
			else
				showResult()
			end
		end
		task.delay(math.max(0,tonumber(payload.ResultDelay)or 2),function()
			if not self.HUD then return end
			if self.HUD and payload.Stats then
				self.HUD:ShowHalfTime(payload,{Title="PLAYER OF\nTHE GAME",Duration=4.2,OnComplete=showRewardsThenResult})
			else
				showRewardsThenResult()
			end
		end)
	end
end
function Controller:_cleanup(restoreMenu:boolean)
	RunService:UnbindFromRenderStep("VTRMatchGameplay");ContextActionService:UnbindAction(PAUSE_ACTION);if self.PauseConnection then self.PauseConnection:Disconnect();self.PauseConnection=nil end;self:_hideGoalCelebrationOverlay();self:_destroyPracticeTuningPanel();if self.CornerAim then self.CornerAim:Destroy();self.CornerAim=nil end;if self.CornerCamera then self.CornerCamera:Destroy();self.CornerCamera=nil end;if self.Input then self.Input:Destroy()end;if self.InputLock then self.InputLock:Destroy()end;if self.Camera then self.Camera:Destroy()end;if self.Visual then self.Visual:Destroy()end;if self.BallRoll then self.BallRoll:Destroy()end;if self.FlightMarker then self.FlightMarker:Destroy();self.FlightMarker=nil end;if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end;if self.MatchSounds then self.MatchSounds:Destroy();self.MatchSounds=nil end;if self.CrowdAmbience then self.CrowdAmbience:Destroy();self.CrowdAmbience=nil end;if self.Commentary then self.Commentary:Destroy();self.Commentary=nil end;for _,controller in self.AnimationCache or{}do controller:Destroy()end;self.AnimationCache={};self.Animation=nil;if self.TeamControl then self.TeamControl:Destroy()end;if self.Indicators then self.Indicators:Destroy()end;if self.Trainer then self.Trainer:Destroy()end;if self.Minimap then self.Minimap:Destroy()end;if self.AimLine then self.AimLine:Destroy()end;if self.GoalTarget then self.GoalTarget:Destroy()end;if self.Cutscenes then self.Cutscenes:Destroy()end;if self.HUD then self.HUD:Destroy()end;if self.Controls then self.Controls:Enable()end;self.Active=false;self.MatchStartKey=nil;self.ActivatingMatchKey=nil;self.MatchActivationRunningKey=nil
	if restoreMenu then
		Players.LocalPlayer:SetAttribute("VTRInMatch",false)
		setMenuVisible(true)
		clearGreenScreenEffects()
	end
end
local function vtrClearSetPiecePreviewObjects()
	for _,container in ipairs({workspace, game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")}) do
		for _,obj in ipairs(container:GetDescendants()) do
			local n=string.lower(obj.Name)
			local isPath=(string.find(n,"preview") or string.find(n,"trajectory") or string.find(n,"pathway") or string.find(n,"aimpath"))
			local isSetPiece=(string.find(n,"free") or string.find(n,"setpiece") or string.find(n,"penalty") or string.find(n,"vtr"))
			if isPath and isSetPiece then
				obj:Destroy()
			end
		end
	end
end

local function vtrBindSetPiecePreviewClear(remote)
	if not remote:IsA("RemoteEvent") then
		return
	end
	local n=string.lower(remote.Name)
	if string.find(n,"setpiece") or string.find(n,"free") or string.find(n,"penalty") or string.find(n,"decision") then
		remote.OnClientEvent:Connect(function(payload)
			if typeof(payload)=="table" then
				local t=tostring(payload.Type or payload.type or "")
				if string.find(t,"ClearSetPiecePreview") or string.find(t,"Auto") or string.find(t,"Decision") or string.find(t,"Resolved") or string.find(t,"KickTaken") then
					task.defer(vtrClearSetPiecePreviewObjects)
					task.delay(.35,vtrClearSetPiecePreviewObjects)
				end
			end
		end)
	end
end

for _,remote in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
	vtrBindSetPiecePreviewClear(remote)
end

game:GetService("ReplicatedStorage").DescendantAdded:Connect(vtrBindSetPiecePreviewClear)

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

return Controller
