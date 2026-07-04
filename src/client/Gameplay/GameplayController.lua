--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)
local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
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
local RankedQueuePresentation=require(script.Parent.Parent.Components.RankedQueuePresentation)
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
local SHOOTING_TUNING={{Key="Speed",Label="Shot Speed",Min=.55,Max=1.55,Default=1},{Key="Accuracy",Label="Accuracy",Min=.55,Max=1.55,Default=1},{Key="Lift",Label="Lift",Min=.55,Max=1.55,Default=1.2},{Key="Curve",Label="Curve",Min=.55,Max=1.55,Default=1},{Key="Power",Label="Power Scale",Min=.55,Max=1.55,Default=1}}
local function formatSliderValue(value:number):string return string.format("%.2fx",value)end
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
function Controller:_bindFootballer(model:Model,name:string?,position:string?)
	if self.Animation then self.Animation:Deactivate()end;if self.Visual then self.Visual:Destroy()end;self.AnimationCache=self.AnimationCache or{};self.Animation=self.AnimationCache[model];if not self.Animation then self.Animation=AnimationController.new(model);self.AnimationCache[model]=self.Animation end
	self.ActiveModel=model;self.Visual=BallVisualController.new(self.Ball,model);self.Camera:SetActive(model);self.TeamControl:SetActive(model,name,position);self.Indicators:SetActive(model);if self.Trainer and not UserInputService.TouchEnabled then self.Trainer:SetActive(model)end;self.Minimap:SetActive(model);self.MouseAim:SetActive(model);self.AimLine:SetActive(model)
	self.Stamina=tonumber(model:GetAttribute("VTRSprintStamina"))or tonumber(model:GetAttribute("VTRStamina"))or Config.Stamina.Maximum;self.Endurance=tonumber(model:GetAttribute("VTREndurance"))or Config.Stamina.Maximum;if self.HUD then self.HUD:SetStamina(self.Stamina/Config.Stamina.Maximum,self.Endurance/Config.Stamina.Maximum)end
end
function Controller:_reticleSwitchTarget(point:Vector3?):Model?
	if not point or not self.ActiveModel or not self.TeamModels then return nil end
	local side=tostring(self.ActiveModel:GetAttribute("VTRTeam")or"Home");local best:Model?=nil;local bestDistance=math.huge
	for _,teammate in self.TeamModels[side]or{}do if teammate~=self.ActiveModel then local teammateRoot=teammate:FindFirstChild("HumanoidRootPart")::BasePart?;if teammateRoot then local distance=Vector3.new(teammateRoot.Position.X-point.X,0,teammateRoot.Position.Z-point.Z).Magnitude;if distance<bestDistance then best=teammate;bestDistance=distance end end end end
	return best
end

function Controller:_mobileAimPayload(kind:string?,charge:number?,root:BasePart):any?
	if not self.Input or not self.Input.MobileAimVector then return nil end
	local vector=self.Input:MobileAimVector(kind)
	if (kind=="Shot"or kind=="GamepadShot") and (self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense") and self.Camera and self.Camera.PitchCFrame then
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
	return{Direction=direction,Position=position,GoalTarget=goalTarget,TargetModel=kind=="Pass"and self:_reticleSwitchTarget(position)or nil}
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
	if self.PracticeMode and kind=="Shot"then local practiceTarget,practiceOnTarget=self:_practiceGoalPoint(shotCharge or 0);if practiceTarget then position=practiceTarget;goalTarget=practiceOnTarget==true end end
	if kind=="Shot"and self.SetPieceMode=="DirectShotFreeKick"and self.SetPieceGoalSign and position and self.Camera and self.Camera.PitchCFrame then
		local rectangle=GoalModelResolver.ResolveByAttackSign(self.SetPieceGoalSign,self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length)
		position=GoalModelResolver.ClampPoint(rectangle,position)
		goalTarget=true
	end
	local penaltySlot=nil
	if kind=="Shot" and (self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense") then
		local goalSign=tonumber(self.Ball:GetAttribute("VTRPenaltyGoalSign"))or self.SetPieceGoalSign or(self.ControlledSide=="Home"and-1 or 1)
		local rectangle=GoalModelResolver.ResolveByAttackSign(goalSign,self.Camera.PitchCFrame,self.Camera.Width,self.Camera.Length)
		position=position and GoalModelResolver.ClampPoint(rectangle,position)or PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,self.PenaltyAimSlot or"MIDDLE",self.Camera.Width)
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
function Controller:_practiceGoalSign():number
	local half=tonumber(workspace:GetAttribute("VTRMatchHalf"))or 1
	local team=tostring(self.ActiveModel and self.ActiveModel:GetAttribute("VTRTeam")or"Home")
	return team=="Home"and(half>=2 and 1 or-1)or(half>=2 and-1 or 1)
end
function Controller:_practiceGoalPoint(charge:number?):(Vector3?, boolean)
	if not self.Camera or not self.Camera.PitchCFrame then return nil,false end
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
		fill.Size=UDim2.fromScale(alpha,1);knob.Position=UDim2.fromScale(alpha,.5);valueLabel.Text=formatSliderValue(value)
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
	local reset=Instance.new("TextButton");reset.Name="ResetShot";reset.BackgroundColor3=Color3.fromHex("B7FF1A");reset.BorderSizePixel=0;reset.Position=UDim2.fromOffset(18,73);reset.Size=UDim2.new(1,-36,0,34);reset.Text="RESET SHOT";reset.TextColor3=Color3.fromHex("050705");reset.TextSize=14;reset.Font=Enum.Font.GothamBlack;reset.AutoButtonColor=true;reset.Parent=panel
	local resetCorner=Instance.new("UICorner");resetCorner.CornerRadius=UDim.new(0,6);resetCorner.Parent=reset
	table.insert(self.PracticeTuningConnections,reset.Activated:Connect(function()self:_requestPracticeReset()end))
	local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(18,122);list.Size=UDim2.new(1,-36,1,-140);list.CanvasSize=UDim2.fromOffset(0,0);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.ScrollingDirection=Enum.ScrollingDirection.Y;list.ScrollBarThickness=5;list.ScrollBarImageColor3=Color3.fromHex("B7FF1A");list.Parent=panel
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
	self.Active=true;self.MatchStartKey=activationKey;self.ActivatingMatchKey=nil;self.MatchActivationRunningKey=nil;self.Ball=ball;self.TeamModels=data.TeamModels;self.ControlledSide=data.ControlledSide or"Home";self.WatchMode=data.WatchMode==true;self.PracticeMode=data.PracticeMode==true;self.Paused=false;self.Ranked=data.Ranked==true;self.MatchInPlay=self.PracticeMode;self.PrematchActive=not self.PracticeMode;self.PrematchSkipRequested=false;self.TacticalMode=false;self.TacticalPanelOpen=false;GuiService.SelectedObject=nil;local playerModule=require(player.PlayerScripts:WaitForChild("PlayerModule", 15));self.Controls=playerModule:GetControls();self.Controls:Disable();self.HUD=MatchHUDController.new(data);self.Commentary=nil;self.CrowdAmbience=CrowdAmbienceController.new();self.CrowdAmbience:Start();self.MatchSounds=MatchSoundController.new(ball,data.TeamModels);self.MatchSounds:Start();self.Camera=BroadcastCameraController.new(data.PitchCFrame,data.PitchWidth,data.PitchLength,ball,active);self.MouseAim=MouseAimController.new(workspace.CurrentCamera,data.PitchCFrame,data.PitchWidth,data.PitchLength);self.Input=InputController.new(self.Action,function(kind,charge)return self:_aimPayload(kind,charge)end);self.InputLock=MatchInputLockController.new(self.Action);self.TeamControl=TeamControlController.new(self.Action,self.Camera,self.HUD,active);self.BallRoll=BallRollVisualController.new(ball)
	self.HUD:SetPauseButtonCallback(function()self:_setPaused(true)end)
	if self.WatchMode then
		if self.ControlledIndicator then self.ControlledIndicator:Destroy();self.ControlledIndicator=nil end
	elseif not self.ControlledIndicator then
		self.ControlledIndicator=VoltraControlledPlayerIndicator.new(function()
			if self.WatchMode or not self.MatchInPlay or self.PrematchActive then return nil end
			return self.ActiveModel
		end)
	end
	self.HUD:SetManualSubstitutionCallback(function(benchIndex:number,outgoingModel:Model,outgoingName:string)
		self.Action:FireServer({Type="ManualSubstitution",BenchIndex=benchIndex,OutgoingModel=outgoingModel,OutgoingName=outgoingName})
	end)
	self.HUD:SetManualPositionSwapCallback(function(modelA:Model,modelB:Model)
		self.Action:FireServer({Type="ManualPositionSwap",ModelA=modelA,ModelB=modelB})
	end)
	local uiState=UIStateService:Get();local settings=uiState and uiState.Settings or {};settings.ManualPassKey=settings.ManualPassKey or "LeftControl";settings.LobbedPassKey=settings.LobbedPassKey or "LeftAlt";settings.ChangePlayerKey=settings.ChangePlayerKey or "Q";settings.TackleKey=settings.TackleKey or "E";settings.SlideTackleKey=settings.SlideTackleKey or "F";self.PauseKey=keyCodeFromSetting(settings.PauseKey,Enum.KeyCode.M);self.Input:SetAutoSwitch(UserInputService.TouchEnabled and "Instant" or settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(UserInputService.TouchEnabled and "Assisted" or settings.ReceiverAssist or "Light");if self.Input.SetControlsSettings then self.Input:SetControlsSettings(settings)end;self.Indicators=PlayerIndicatorController.new(data.TeamModels,ball,self.HUD,"Off");self.Trainer=TrainerController.new(self.HUD.Gui,ball,settings.Trainer or "Basic");self.Minimap=MinimapController.new(self.HUD.Gui,data.PitchCFrame,data.PitchWidth,data.PitchLength,data.TeamModels,ball,settings.Minimap or "Medium",settings.MinimapOrientation or "Broadcast",settings.CameraSide or "Near",self.ControlledSide);self.AimLine=AimLineController.new(data.TeamModels,ball);self.GoalTarget=GoalReticleController.new(workspace.CurrentCamera,ball);self.FlightMarker=BallFlightMarkerController.new(ball);self.Cutscenes=MatchCutsceneController.new(self.Camera,self.HUD);self.Camera:SetMode(settings.CameraPreset or "Broadcast");self.Camera:ApplySettings(settings);if self.PracticeMode and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true);self:_createPracticeTuningPanel()end
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
		if (input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.ButtonA) and not processed and self.PrematchActive and not self.PrematchSkipRequested then self.PrematchSkipRequested=true;self.Action:FireServer({Type="PrematchSkip"});if self.HUD then self.HUD:Flash(self.Ranked and"SKIP QUEUED"or"SKIPPING INTRO",.9)end;return end
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
		local goalkeeper=model:GetAttribute("position")=="GK"
		if model:GetAttribute("VTRForceIdle")==true then controller:Play(goalkeeper and"GoalkeeperIdle"or"Idle");continue end
		local speed=Vector3.new(modelRoot.AssemblyLinearVelocity.X,0,modelRoot.AssemblyLinearVelocity.Z).Magnitude;local hasBall=self.Ball:GetAttribute("OwnerModel")==model.Name
		if speed>.65 then controller:Play(goalkeeper and"GoalkeeperMove"or(hasBall and"Dribble"or(model:GetAttribute("VTRSprinting")==true and"Sprint"or"Jog")))else controller:Play(goalkeeper and"GoalkeeperIdle"or"Idle")end
	end
end
function Controller:_update(dt:number)
	if not self.Active or not self.ActiveModel or not self.ActiveModel.Parent then return end
	self.Camera:Update(dt)
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
		aimPosition=aimPosition and GoalModelResolver.ClampPoint(rectangle,aimPosition)or PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,self.PenaltyAimSlot or"MIDDLE",self.Camera.Width)
		local slot=PenaltyConfig.NormalizeSlot(PenaltyConfig.SlotFromGoalPoint(self.Camera.PitchCFrame,self.Camera.Length,goalSign,aimPosition,self.Camera.Width))or PenaltyConfig.NormalizeSlot(self.PenaltyAimSlot)or"MIDDLE"
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
		self.HUD:SetCharge(self.SetPieceMode=="DirectShotFreeKick"and chargeKind=="Shot"and 0 or charge,chargeKind)
		return
	end
	local input=self.WatchMode and Vector2.zero or self.Input:Move();if not self.WatchMode then self.TeamControl:Update(dt,input)end;local movement=self.Camera:Movement(input);local sprinting=self.ActiveModel:GetAttribute("VTRSprinting")==true;self.Visual:Update(dt,movement,sprinting);self.BallRoll:Update(dt,hasBall);if self.FlightMarker then self.FlightMarker:Update(dt)end;if root and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>.6 then self.Animation:Play(hasBall and"Dribble"or(sprinting and"Sprint"or"Jog"))else self.Animation:Play("Idle")end;self:_updateTeamAnimations();self.HUD:SetStamina(self.Stamina/Config.Stamina.Maximum,self.Endurance/Config.Stamina.Maximum);self.HUD:SetCharge((self.SetPieceMode=="DirectShotFreeKick"and chargeKind=="Shot")and 0 or charge,chargeKind);local owner=self.Ball:GetAttribute("OwnerModel");self.HUD:SetState(self.WatchMode and"WATCHING AI VS AI"or(owner==self.ActiveModel.Name and(sprinting and"Sprinting"or"Dribbling")or owner==""and"Loose Ball"or"Defending"))
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
	if payload.Team=="Home"then self.Animation:Play("GoalCelebration")end
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
		if payload.Ranked==true then local gui=Players.LocalPlayer.PlayerGui:FindFirstChild("VTR25");local root=gui and gui:FindFirstChild("Root");if root then RankedQueuePresentation.ShowMatchFound(root,payload,activateOnce);task.delay(4.2,activateOnce)else task.delay(3.8,activateOnce)end
		else task.defer(activateOnce)end
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
	elseif payload.Type=="PrematchSkipQueued"then if self.HUD then self.HUD:Flash(payload.Ready and"INTRO SKIPPED"or(tostring(payload.PlayerName or"PLAYER").." WANTS TO SKIP"),1.0)end
	elseif payload.Type=="PrematchSkip"then self.PrematchActive=false;self.PrematchSkipRequested=true;if UISoundService.StopTransitions then UISoundService.StopTransitions()end;if self.Cutscenes then self.Cutscenes:SkipStadiumIntro()end;self:_playPrematchSkipTransition()
	elseif payload.Type=="PracticeReset"then self.PracticeMode=true;self.PrematchActive=false;self.MatchInPlay=true;self.Paused=false;self:_createPracticeTuningPanel();if payload.Shooter and payload.Shooter:IsA("Model")then self:_bindFootballer(payload.Shooter,payload.Shooter:GetAttribute("DisplayName"),payload.Shooter:GetAttribute("position"))end;if self.Input then if self.Input.SetShootingOnly then self.Input:SetShootingOnly(true)end;self.Input:SetSuppressed(false);if self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.WatchMode~=true)end end;if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(true)end;if self.MatchSounds then self.MatchSounds:SetMatchActive(true)end;if self.Trainer then self.Trainer:SetMatchActive(not UserInputService.TouchEnabled and self.WatchMode~=true)end;if self.Minimap then self.Minimap:SetMatchActive(true)end;if self.AimLine then self.AimLine:SetMatchActive(self.WatchMode~=true)end;if self.GoalTarget then self.GoalTarget:SetMode("Shot");self.GoalTarget:SetDefenseSource(nil);self.GoalTarget:SetMatchActive(self.WatchMode~=true);local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end end;if self.HUD then self.HUD:SetPhase("SHOOTING PRACTICE");if payload.Reason=="START"then self.HUD:Flash("SHOOTING PRACTICE",.9)end end;self:_emitPracticeTuning(true)
	elseif payload.Type=="PracticeShotResult"then local result=tostring(payload.Result or"MISS");self:_playPracticeResetTransition(result);if self.HUD then self.HUD:ResolveShotChance(result=="GOAL");self.HUD:Flash(result=="GOAL"and"GOAL"or result=="SAVE"and"SAVED"or"MISS",.85)end;if self.MatchSounds and result=="GOAL"and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end;if self.Visual then if result=="GOAL"then self.Visual:HoldShotTrail()else self.Visual:StopShotTrail()end end;if self.GoalTarget then self.GoalTarget:Unlock()end
	elseif payload.Type=="SwitchTarget"then self.TeamControl:SetSwitchTarget(payload.Model);self.Indicators:SetNextSwitch(payload.Model)
	elseif payload.Type=="Possession"then if self.HUD then self.HUD:SetPossession(payload.Owner or"",payload.OwnerUserId==Players.LocalPlayer.UserId)end;if self.Indicators then self.Indicators:SetBallCarrier(payload.Model)end;if self.Minimap then self.Minimap:SetBallCarrier(payload.Model)end;if payload.Model then if self.Visual then self.Visual:StopShotTrail()end;if self.GoalTarget then if self.PracticeMode and payload.Model==self.ActiveModel then local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end else self.GoalTarget:Unlock()end end end
	elseif payload.Type=="PassTarget"then self.Indicators:SetPassTarget(payload.Model)
	elseif payload.Type=="SetPiece"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted(payload.ActualKind or payload.Kind)end;if self.Input and payload.Kind~="Corner" then self.Input:SetSuppressed(self.WatchMode==true)end;if self.Input and self.Input.SetDirectFreeKick then self.Input:SetDirectFreeKick(payload.Mode=="DirectShotFreeKick")elseif self.Input and self.Input.ResetFreeKickModifiers and payload.Mode=="DirectShotFreeKick"then self.Input:ResetFreeKickModifiers()end;local actualKind=payload.ActualKind or payload.Kind;if self.Input and self.Input.LockActions and (actualKind=="FreeKick"or actualKind=="Penalty"or actualKind=="ThrowIn"or actualKind=="GoalKick")then self.Input:LockActions(2)end;self.SetPieceGoalSign=payload.GoalSign;self.PenaltyAimSlot=actualKind=="Penalty"and"MIDDLE"or self.PenaltyAimSlot;self.PenaltyAimPoint=actualKind=="Penalty"and nil or self.PenaltyAimPoint;self.GamepadShotAimPoint=nil;self.FreeKickAimVector=payload.Mode=="DirectShotFreeKick"and Vector2.new(0,.22)or self.FreeKickAimVector;local mobileRestart=actualKind=="FreeKick"or actualKind=="ThrowIn"or actualKind=="Penalty"or actualKind=="GoalKick";if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(mobileRestart and self.WatchMode~=true)end;self.MatchInPlay=false;self.SetPieceMode=payload.Mode;self.SetPieceKind=actualKind;if payload.Kind=="Offside"and self.HUD then self.HUD:Flash("OFFSIDE",1.05)end;if payload.Taker and payload.Taker:IsA("Model")then self:_bindFootballer(payload.Taker,payload.Taker:GetAttribute("DisplayName"),payload.Taker:GetAttribute("position"))end;if self.Visual then self.Visual:ClearLock();self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Trainer then self.Trainer:SetMatchActive(false)end;self.Minimap:SetMatchActive(true);local aimingRestart=mobileRestart and self.WatchMode~=true;self.AimLine:SetMatchActive(aimingRestart);self.GoalTarget:SetMatchActive(aimingRestart);if actualKind=="Kickoff"then self.PendingKickoffSound=true;self.PendingFoulRestartWhistle=false else self.PendingKickoffSound=false end;if self.FoulRestartWhistlePending and (actualKind=="FreeKick"or actualKind=="Penalty")then self.PendingFoulRestartWhistle=true;self.FoulRestartWhistlePending=false elseif actualKind~="FreeKick"and actualKind~="Penalty"then self.FoulRestartWhistlePending=false end;if payload.Kind=="Kickoff"and self.HUD then self.HUD:PlayMatchHudIntro();self.HUD:ShowKickoffScorer()end;self.Cutscenes:Play(payload)
	elseif payload.Type=="CornerMode"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted("Corner")end;self.Input:SetSuppressed(true);local takerAnimation=self.AnimationCache and self.AnimationCache[payload.Taker];if takerAnimation then takerAnimation:Play("Idle")end;if self.CornerAim then self.CornerAim:Destroy()end;if self.CornerCamera then self.CornerCamera:Destroy()end;self.CornerCamera=CornerCameraController.new(payload);self.CornerAim=CornerAimController.new(payload,self.Action,self.HUD);self.HUD:SetPhase("CORNER KICK")
	elseif payload.Type=="CornerReleased"then self.Input:SetSuppressed(false);if self.CornerAim then self.CornerAim:Destroy();self.CornerAim=nil end;if self.CornerCamera then self.CornerCamera:Destroy();self.CornerCamera=nil end;self.HUD:Flash(string.upper(payload.Delivery or"CROSS"),.7)
	elseif payload.Type=="Phase"then self.PrematchActive=false;if self.Input then if self.Input.SetShootingOnly then self.Input:SetShootingOnly(payload.Phase=="SHOOTING PRACTICE")end;self.Input:SetSuppressed(self.WatchMode==true);if self.Input.SetDirectFreeKick then self.Input:SetDirectFreeKick(false)end end;if workspace:GetAttribute("VTRKickoffDebug") ~= false then print("[VTR KICKOFF][Client] Phase",payload.Phase or"nil","active",self.ActiveModel and self.ActiveModel.Name or"nil","inputSuppressed",self.Input and self.Input.Suppressed)end;if self.Camera and self.Camera.EndCutscene and payload.HoldCutscene~=true then self.Camera:EndCutscene()end;if self.Visual then self.Visual:ClearLock()end;self.SetPieceMode=nil;self.SetPieceKind=nil;self.SetPieceGoalSign=nil;self.PenaltyAimSlot=nil;self.PenaltyAimPoint=nil;self.GamepadShotAimPoint=nil;self.MatchInPlay=payload.Phase=="IN PLAY"or payload.Phase=="SHOOTING PRACTICE";if payload.Phase=="SHOOTING PRACTICE"then self.PracticeMode=true;self:_createPracticeTuningPanel();if self.Camera and self.Camera.SetShootingFocus then self.Camera:SetShootingFocus(true)end end;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.MatchInPlay and self.WatchMode~=true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;if self.MatchSounds then self.MatchSounds:SetMatchActive(self.MatchInPlay)end;if self.Trainer then self.Trainer:SetMatchActive(not UserInputService.TouchEnabled and self.MatchInPlay and self.WatchMode~=true)end;self.Minimap:SetMatchActive(self.MatchInPlay);self.AimLine:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);self.GoalTarget:SetMode("Shot");self.GoalTarget:SetDefenseSource(nil);self.GoalTarget:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);if self.PracticeMode and self.MatchInPlay then local target=self:_practiceGoalPoint(0);if target then self.GoalTarget:Lock(target)end end;self.HUD:SetPhase(payload.Phase or"IN PLAY")
	elseif payload.Type=="HalfTime"then self.MatchInPlay=false;self.HalfTimePauseActive=true;self.Paused=true;if self.Trainer then self.Trainer:SetMatchActive(false)end;self.Minimap:SetMatchActive(false);self.AimLine:SetMatchActive(false);self.GoalTarget:SetMatchActive(false);self.Cutscenes:HalfTime(payload);payload.ControlledSide=self.ControlledSide;task.delay(8,function()if self.Active and self.HalfTimePauseActive and self.HUD then self.HUD:SetPaused(true,self.Camera,function()self:_cleanup(true)end,payload,function()self.Action:FireServer({Type="Forfeit"})end)end end)
	elseif payload.Type=="HalfTimeTimer"then if self.HUD then self.HUD:SetPauseTimer(payload.Remaining or 0)end
	elseif payload.Type=="HalfTimeResumeVote"then if self.HUD and payload.Ready~=true then self.HUD:Flash(tostring(payload.PlayerName or"PLAYER").." READY FOR SECOND HALF",1.0)end
	elseif payload.Type=="HalfTimeResume"then self.HalfTimePauseActive=false;self.Paused=false;if self.HUD then self.HUD:ClearPause()end
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
	elseif payload.Type=="Clock"then workspace:SetAttribute("VTRMatchHalf",tonumber(payload.Half)or 1);self.Stamina=tonumber(payload.Stamina)or self.Stamina;self.Endurance=tonumber(payload.Endurance)or self.Endurance;self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:UpdateActiveRating()
	elseif payload.Type=="Kickoff"then if self.Visual then self.Visual:StopShotTrail()end;self.HUD:Flash("Kick Off",1)
	elseif payload.Type=="GoalSoundPreview"then if self.MatchSounds and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end
	elseif payload.Type=="GoalSoundPreview"then if self.MatchSounds and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end
	elseif payload.Type=="Goal"then if self.MatchSounds then self.MatchSounds:PlayGoal()end;if self.CrowdAmbience then self.CrowdAmbience:Boost(3.2)end;if self.HUD then self.HUD:ResolveShotChance(true)end;self.MatchInPlay=false;if self.Visual then self.Visual:ClearLock();self.Visual:HoldShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Trainer then self.Trainer:SetMatchActive(false)end;self.Minimap:SetMatchActive(false);self.AimLine:SetMatchActive(false);self.GoalTarget:SetMatchActive(false);self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:RememberGoalScorer(payload);self.ReplayBlocking=true;self.ReplayQueuedPayloads={};self.ReplayQueuedClock=nil;if self.ReplayController then self.ReplayController:PlayGoalReplay(function()self:_finishGoalPresentation(payload)end)else self:_finishGoalPresentation(payload)end
	elseif payload.Type=="FinalChance"then if self.HUD then self.HUD:ShowFinalChance(payload.Active~=false)end
	elseif payload.Type=="Info"then if payload.Important==true then self.HUD:Flash(payload.Message,1.3)end
	elseif payload.Type=="MatchEnded"then
		if self.MatchSounds then self.MatchSounds:PlayFinalWhistle()end
		RunService:UnbindFromRenderStep("VTRMatchGameplay")
		self:_destroyPracticeTuningPanel()
		if self.HUD then self.HUD:ClearPause();self.HUD:ShowFinalChance(false)end
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
	RunService:UnbindFromRenderStep("VTRMatchGameplay");ContextActionService:UnbindAction(PAUSE_ACTION);if self.PauseConnection then self.PauseConnection:Disconnect();self.PauseConnection=nil end;self:_destroyPracticeTuningPanel();if self.CornerAim then self.CornerAim:Destroy();self.CornerAim=nil end;if self.CornerCamera then self.CornerCamera:Destroy();self.CornerCamera=nil end;if self.Input then self.Input:Destroy()end;if self.InputLock then self.InputLock:Destroy()end;if self.Camera then self.Camera:Destroy()end;if self.Visual then self.Visual:Destroy()end;if self.BallRoll then self.BallRoll:Destroy()end;if self.FlightMarker then self.FlightMarker:Destroy();self.FlightMarker=nil end;if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end;if self.MatchSounds then self.MatchSounds:Destroy();self.MatchSounds=nil end;if self.CrowdAmbience then self.CrowdAmbience:Destroy();self.CrowdAmbience=nil end;if self.Commentary then self.Commentary:Destroy();self.Commentary=nil end;for _,controller in self.AnimationCache or{}do controller:Destroy()end;self.AnimationCache={};self.Animation=nil;if self.TeamControl then self.TeamControl:Destroy()end;if self.Indicators then self.Indicators:Destroy()end;if self.Trainer then self.Trainer:Destroy()end;if self.Minimap then self.Minimap:Destroy()end;if self.AimLine then self.AimLine:Destroy()end;if self.GoalTarget then self.GoalTarget:Destroy()end;if self.Cutscenes then self.Cutscenes:Destroy()end;if self.HUD then self.HUD:Destroy()end;if self.Controls then self.Controls:Enable()end;self.Active=false;self.MatchStartKey=nil;self.ActivatingMatchKey=nil;self.MatchActivationRunningKey=nil
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
