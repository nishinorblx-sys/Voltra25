--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
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
local CommentaryController=require(script.Parent.CommentaryController)
local RankedQueuePresentation=require(script.Parent.Parent.Components.RankedQueuePresentation)
local UIStateService=require(script.Parent.Parent.Services.UIStateService)
local PenaltyConfig=require(ReplicatedStorage.VTR.Shared.PenaltyConfig)
local Controller={};Controller.__index=Controller
local function setMenuVisible(visible:boolean)
	local gui=Players.LocalPlayer.PlayerGui:FindFirstChild("VTR25");local root=gui and gui:FindFirstChild("Root");if not root or not root:IsA("Frame")then return end
	root.BackgroundTransparency=visible and 0 or 1
	local energy=root:FindFirstChild("BackgroundEnergy");if energy and energy:IsA("GuiObject")then energy.Visible=visible end
	for _,name in{"Sidebar","Topbar","Content"}do local item=root:FindFirstChild(name);if item and item:IsA("GuiObject")then item.Visible=visible end end
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
	self.ActiveModel=model;self.Visual=BallVisualController.new(self.Ball,model);self.Camera:SetActive(model);self.TeamControl:SetActive(model,name,position);self.Indicators:SetActive(model);self.Trainer:SetActive(model);self.Minimap:SetActive(model);self.MouseAim:SetActive(model);self.AimLine:SetActive(model)
	self.Stamina=tonumber(model:GetAttribute("VTRSprintStamina"))or tonumber(model:GetAttribute("VTRStamina"))or Config.Stamina.Maximum;self.Endurance=tonumber(model:GetAttribute("VTREndurance"))or Config.Stamina.Maximum;if self.HUD then self.HUD:SetStamina(self.Stamina/Config.Stamina.Maximum,self.Endurance/Config.Stamina.Maximum)end
end
function Controller:_reticleSwitchTarget(point:Vector3?):Model?
	if not point or not self.ActiveModel or not self.TeamModels then return nil end
	local side=tostring(self.ActiveModel:GetAttribute("VTRTeam")or"Home");local best:Model?=nil;local bestDistance=12
	for _,teammate in self.TeamModels[side]or{}do if teammate~=self.ActiveModel then local teammateRoot=teammate:FindFirstChild("HumanoidRootPart")::BasePart?;if teammateRoot then local distance=Vector3.new(teammateRoot.Position.X-point.X,0,teammateRoot.Position.Z-point.Z).Magnitude;if distance<bestDistance then best=teammate;bestDistance=distance end end end end
	return best
end
function Controller:_aimPayload(kind:string?,shotCharge:number?):any
	local position=self.MouseAim:GetAimWorldPosition();local switchTarget=kind=="Switch"and self:_reticleSwitchTarget(position)or nil
	local root=self.ActiveModel and self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?;if not root then return{Direction=self.Camera:Aim(kind),Position=position,GoalTarget=false,TargetModel=switchTarget or(kind=="Pass"and self.LockedPassTarget or nil)}end
	local goalTarget=kind=="Shot"and self.MouseAim:IsAimingAtGoal();position=goalTarget and self.MouseAim:GetGoalAimPoint(shotCharge or 0)or position
	local penaltySlot=nil
	if kind=="Shot" and (self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense") then
		local goalSign=tonumber(self.Ball:GetAttribute("VTRPenaltyGoalSign"))or(self.ControlledSide=="Home"and-1 or 1)
		if position then penaltySlot=PenaltyConfig.SlotFromGoalPoint(self.Camera.PitchCFrame,self.Camera.Length,goalSign,position,self.Camera.Width);position=PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,penaltySlot,self.Camera.Width);goalTarget=true end
	end
	if goalTarget and position and self.GoalTarget then self.GoalTarget:Lock(position)end;local offset=position and(position-root.Position)or Vector3.zero;local direction=offset.Magnitude>.01 and offset.Unit or self.MouseAim:GetAimDirectionFromPlayer(root.Position);local freeKickCurve,freeKickLift=0,0;if kind=="Shot"and self.SetPieceMode=="DirectShotFreeKick"and self.Input and self.Input.FreeKickModifiers then freeKickCurve,freeKickLift=self.Input:FreeKickModifiers()end;return{Direction=direction,Position=position,GoalTarget=goalTarget,TargetModel=switchTarget or(kind=="Pass"and self.LockedPassTarget or nil),FreeKickCurve=freeKickCurve,FreeKickLift=freeKickLift,PenaltySlot=penaltySlot}
end
function Controller:_playPrematchSkipTransition()
	local gui=Instance.new("ScreenGui");gui.Name="VTRPrematchSkipTransition";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=112;gui.Parent=Players.LocalPlayer.PlayerGui
	DeviceScaleService.Apply(gui)
	local overlay=Instance.new("CanvasGroup");overlay.BackgroundColor3=Color3.new(0,0,0);overlay.BorderSizePixel=0;overlay.GroupTransparency=1;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=112;overlay.Parent=gui
	local slash=Instance.new("Frame");slash.AnchorPoint=Vector2.new(.5,.5);slash.BackgroundColor3=Color3.fromHex("B7FF1A");slash.BorderSizePixel=0;slash.Position=UDim2.fromScale(-.25,.5);slash.Rotation=-16;slash.Size=UDim2.fromScale(.55,1.7);slash.ZIndex=113;slash.Parent=overlay
	local TweenService=game:GetService("TweenService")
	TweenService:Create(overlay,TweenInfo.new(.16),{GroupTransparency=0}):Play()
	TweenService:Create(slash,TweenInfo.new(.36,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.fromScale(1.22,.5)}):Play()
	task.delay(.42,function()if not gui.Parent then return end;TweenService:Create(overlay,TweenInfo.new(.16),{GroupTransparency=1}):Play();task.delay(.18,function()if gui.Parent then gui:Destroy()end end)end)
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
	local toggle=Instance.new("TextButton");toggle.AnchorPoint=Vector2.new(1,0);toggle.BackgroundColor3=Color3.fromHex("B7FF1A");toggle.BorderSizePixel=0;toggle.Position=UDim2.new(1,-18,0,104);toggle.Size=UDim2.fromOffset(92,28);toggle.Text="HIDE";toggle.TextColor3=Color3.fromHex("111111");toggle.TextSize=10;toggle.Font=Enum.Font.GothamBlack;toggle.ZIndex=184;toggle.Parent=overlay
	local panel=Instance.new("Frame");panel.AnchorPoint=Vector2.new(1,.5);panel.BackgroundColor3=Color3.fromHex("070A06");panel.BackgroundTransparency=.06;panel.BorderSizePixel=0;panel.Position=UDim2.new(1,-18,.5,16);panel.Size=UDim2.fromOffset(330,500);panel.ZIndex=182;panel.Parent=overlay;self.TacticalPanel=panel;local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("B7FF1A");stroke.Thickness=1;stroke.Transparency=.25;stroke.Parent=panel
	toggle.Activated:Connect(function()self.TacticalPanelOpen=not self.TacticalPanelOpen;panel.Visible=self.TacticalPanelOpen;toggle.Text=self.TacticalPanelOpen and"HIDE"or"SHOW"end)
	self:_renderTacticalPanel()
end
function Controller:_renderTacticalPanel()
	local panel=self.TacticalPanel;if not panel then return end
	for _,child in panel:GetChildren()do if child:IsA("GuiObject")then child:Destroy()end end
	local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(14,10);title.Size=UDim2.new(1,-28,0,22);title.Text="LIVE AI";title.TextColor3=Color3.new(1,1,1);title.TextSize=15;title.Font=Enum.Font.GothamBlack;title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=183;title.Parent=panel
	local status=Instance.new("TextLabel");status.BackgroundTransparency=1;status.Position=UDim2.fromOffset(14,32);status.Size=UDim2.new(1,-28,0,16);status.Text=self.TacticalSide.." SELECTED";status.TextColor3=Color3.fromHex("B7FF1A");status.TextSize=8;status.Font=Enum.Font.GothamBold;status.TextXAlignment=Enum.TextXAlignment.Left;status.ZIndex=183;status.Parent=panel;self.TacticalStatus=status
	for index,side in ipairs({"Home","Away"})do local tab=Instance.new("TextButton");tab.BackgroundColor3=side==self.TacticalSide and Color3.fromHex("B7FF1A")or Color3.fromHex("1B2118");tab.BorderSizePixel=0;tab.Position=UDim2.fromOffset(14+(index-1)*82,56);tab.Size=UDim2.fromOffset(76,26);tab.Text=string.upper(side);tab.TextColor3=side==self.TacticalSide and Color3.fromHex("111111")or Color3.fromHex("F5F7F2");tab.TextSize=10;tab.Font=Enum.Font.GothamBlack;tab.ZIndex=184;tab.Parent=panel;tab.Activated:Connect(function()self.TacticalSide=side;self:_renderTacticalPanel()end)end
	local output=Instance.new("TextButton");output.BackgroundColor3=Color3.fromHex("2A351F");output.BorderSizePixel=0;output.Position=UDim2.new(1,-100,0,56);output.Size=UDim2.fromOffset(86,26);output.Text="OUTPUT";output.TextColor3=Color3.fromHex("B7FF1A");output.TextSize=10;output.Font=Enum.Font.GothamBlack;output.ZIndex=184;output.Parent=panel
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
		local number=Instance.new("TextLabel");number.BackgroundTransparency=1;number.Position=UDim2.new(1,-70,0,5);number.Size=UDim2.fromOffset(30,20);number.Text=tostring(value);number.TextColor3=Color3.fromHex("B7FF1A");number.TextSize=9;number.Font=Enum.Font.GothamBlack;number.ZIndex=186;number.Parent=row
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
	if self.Active then self:_cleanup(false)end;local player=Players.LocalPlayer;local ball=data.Ball;if not ball or not ball.Parent then local world=workspace:FindFirstChild(data.WorldName);ball=world and world:FindFirstChild(Config.Ball.Name,true)end;local active=data.ActivePlayer;if not ball or not active or not active.Parent then return end
	setMenuVisible(false)
	self.Active=true;self.Ball=ball;self.TeamModels=data.TeamModels;self.ControlledSide=data.ControlledSide or"Home";self.WatchMode=data.WatchMode==true;self.Paused=false;self.Ranked=data.Ranked==true;self.MatchInPlay=false;self.PrematchActive=true;self.PrematchSkipRequested=false;self.TacticalMode=false;self.TacticalPanelOpen=true;GuiService.SelectedObject=nil;local playerModule=require(player.PlayerScripts:WaitForChild("PlayerModule"));self.Controls=playerModule:GetControls();self.Controls:Disable();self.HUD=MatchHUDController.new(data);self.Commentary=CommentaryController.new(self.HUD.Gui);self.Camera=BroadcastCameraController.new(data.PitchCFrame,data.PitchWidth,data.PitchLength,ball,active);self.MouseAim=MouseAimController.new(workspace.CurrentCamera,data.PitchCFrame,data.PitchWidth,data.PitchLength);self.Input=InputController.new(self.Action,function(kind,charge)return self:_aimPayload(kind,charge)end);self.InputLock=MatchInputLockController.new(self.Action);self.TeamControl=TeamControlController.new(self.Action,self.Camera,self.HUD,active);self.BallRoll=BallRollVisualController.new(ball);self:_createTacticalPanel()
	self.HUD:SetPauseButtonCallback(function()self:_setPaused(true)end)
	self.HUD:SetManualSubstitutionCallback(function(benchIndex:number,outgoingModel:Model,outgoingName:string)
		self.Action:FireServer({Type="ManualSubstitution",BenchIndex=benchIndex,OutgoingModel=outgoingModel,OutgoingName=outgoingName})
	end)
	self.HUD:SetManualPositionSwapCallback(function(modelA:Model,modelB:Model)
		self.Action:FireServer({Type="ManualPositionSwap",ModelA=modelA,ModelB=modelB})
	end)
	local uiState=UIStateService:Get();local settings=uiState and uiState.Settings or {};self.PauseKey=keyCodeFromSetting(settings.PauseKey,Enum.KeyCode.M);self.Input:SetAutoSwitch(settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(settings.ReceiverAssist or "Light");self.Indicators=PlayerIndicatorController.new(data.TeamModels,ball,self.HUD,"Off");self.Trainer=TrainerController.new(self.HUD.Gui,ball,settings.Trainer or "Basic");self.Minimap=MinimapController.new(self.HUD.Gui,data.PitchCFrame,data.PitchWidth,data.PitchLength,data.TeamModels,ball,settings.Minimap or "Medium",settings.MinimapOrientation or "Broadcast",settings.CameraSide or "Near",self.ControlledSide);self.AimLine=AimLineController.new(data.TeamModels,ball);self.GoalTarget=GoalReticleController.new(workspace.CurrentCamera,ball);self.FlightMarker=BallFlightMarkerController.new(ball);self.Cutscenes=MatchCutsceneController.new(self.Camera,self.HUD);self.Camera:SetMode(settings.CameraPreset or "Broadcast");self.Camera:ApplySettings(settings)
	self.AnimationCache={};for _,side in data.TeamModels do for _,footballer in side do self.AnimationCache[footballer]=AnimationController.new(footballer)end end
	if self.ReplayController then self.ReplayController:Destroy()end;self.ReplayController=ReplayController.new(data,ball)
	self.HUD:SetResumeCallback(function()self:_setPaused(false)end);self.PauseConnection=UserInputService.InputBegan:Connect(function(input,processed)if not self.Active then return end;if input.KeyCode==Enum.KeyCode.Six and not processed then self:_toggleTacticalMode();return end;if input.KeyCode==Enum.KeyCode.ButtonStart or input.KeyCode==(self.PauseKey or Enum.KeyCode.M) then self:_setPaused(not self.Paused);return end;if input.KeyCode==Enum.KeyCode.Space and not processed and self.PrematchActive and not self.PrematchSkipRequested then self.PrematchSkipRequested=true;self.Action:FireServer({Type="PrematchSkip"});if self.HUD then self.HUD:Flash(self.Ranked and"SKIP QUEUED"or"SKIPPING INTRO",.9)end;return end end)
	self.Camera:Start();self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.WatchMode then self.Input:SetSuppressed(true)end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))
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
	self.Camera:Update(dt);if self.CornerAim then self.CornerAim:Update();self.CornerCamera:SetTarget(self.CornerAim:GetTarget());self.CornerCamera:Update(dt);return end;self.MouseAim:Update();local root=self.ActiveModel:FindFirstChild("HumanoidRootPart")::BasePart?;local hasBall=self.Ball:GetAttribute("OwnerModel")==self.ActiveModel.Name or self.SetPieceMode=="PenaltyDefense";local charge=self.Input:ChargeValue();local chargeKind=self.Input:ChargeKind();local aimingAtGoal=self.MouseAim:IsAimingAtGoal();local goalPoint=self.MouseAim:GetGoalAimPoint(chargeKind=="Shot"and charge or 0);local aimPosition=aimingAtGoal and goalPoint or self.MouseAim:GetAimWorldPosition();if (self.SetPieceMode=="Penalty"or self.SetPieceMode=="PenaltyDefense")then local goalSign=tonumber(self.Ball:GetAttribute("VTRPenaltyGoalSign"))or(self.ControlledSide=="Home"and-1 or 1);local slot=PenaltyConfig.SlotFromGoalPoint(self.Camera.PitchCFrame,self.Camera.Length,goalSign,aimPosition,self.Camera.Width);aimPosition=PenaltyConfig.PointForSlot(self.Camera.PitchCFrame,self.Camera.Length,goalSign,slot,self.Camera.Width);aimingAtGoal=true end;local aimDirection=root and aimPosition and(aimPosition-root.Position).Magnitude>.01 and(aimPosition-root.Position).Unit or root and self.MouseAim:GetAimDirectionFromPlayer(root.Position)or self.Camera:Aim();self.Indicators:SetAimDirection(aimDirection);self.Indicators:Update(dt);local freeKickCurve,freeKickLift=0,0;if self.SetPieceMode=="DirectShotFreeKick"and self.Input and self.Input.FreeKickModifiers then freeKickCurve,freeKickLift=self.Input:FreeKickModifiers()end;local preview=self.AimLine:Update(dt,aimPosition,hasBall,chargeKind,charge,aimingAtGoal,freeKickCurve,freeKickLift,self.SetPieceMode);self.LockedPassTarget=preview;self.Indicators:SetPassTarget(preview,self.AimLine:IsTargetFallback());self.GoalTarget:Update(hasBall,true,aimingAtGoal,aimPosition);self.Trainer:SetBusy(chargeKind~=""or self.ActiveModel:GetAttribute("VTRSprinting")==true);self.Trainer:Update();self.Minimap:Update(dt)
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
		if workspace:GetAttribute("VTRKickoffDebug") ~= false then print("[VTR KICKOFF][Client] MatchStarted received; activating match camera", "ranked", payload.Ranked==true, "active", payload.ActivePlayer and payload.ActivePlayer.Name or "nil")end
		if payload.Ranked==true then local gui=Players.LocalPlayer.PlayerGui:FindFirstChild("VTR25");local root=gui and gui:FindFirstChild("Root");if root then RankedQueuePresentation.ShowMatchFound(root,payload,function()if Players.LocalPlayer:GetAttribute("VTRInMatch")then self:_activate(payload)end end)else task.delay(3.8,function()if Players.LocalPlayer:GetAttribute("VTRInMatch")then self:_activate(payload)end end)end
		else task.defer(function()if Players.LocalPlayer:GetAttribute("VTRInMatch")then self:_activate(payload)end end)end
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
	if payload.Type=="ActivePlayer"and payload.Model and payload.Model:IsA("Model")then if payload.Reason=="KickoffReceiver"and self.Input then self.Input:SetSuppressed(self.WatchMode==true)end;if workspace:GetAttribute("VTRKickoffDebug") ~= false then print("[VTR KICKOFF][Client] ActivePlayer",payload.Model.Name,"reason",payload.Reason or"","inputSuppressed",self.Input and self.Input.Suppressed)end;self:_bindFootballer(payload.Model,payload.Name,payload.Position);if payload.Reason=="PenaltyDefense"then self.SetPieceMode="PenaltyDefense";self.MatchInPlay=false;if self.AimLine then self.AimLine:SetMatchActive(true)end;if self.GoalTarget then self.GoalTarget:SetMatchActive(true)end end
	elseif payload.Type=="PauseQueued"then self.HUD:ShowPauseQueue(Players.LocalPlayer.Name,true)
	elseif payload.Type=="PauseQueue"then self.HUD:ShowPauseQueue(tostring(payload.PlayerName or"PLAYER"),payload.Queued==true)
	elseif payload.Type=="PauseState"then payload.ControlledSide=self.ControlledSide;self.Paused=payload.Paused==true;self.InputLock:SetSprintEnabled(not self.Paused);local visible=not self.Paused and self.MatchInPlay==true;self.Trainer:SetMatchActive(visible);self.Minimap:SetMatchActive(visible);self.AimLine:SetMatchActive(visible);self.GoalTarget:SetMatchActive(visible);self.HUD:SetPaused(self.Paused,self.Camera,function()self:_cleanup(true)end,payload,function()self.Action:FireServer({Type="Forfeit"})end)
	elseif payload.Type=="PauseTimer"then self.HUD:SetPauseTimer(payload.Remaining or 0)
	elseif payload.Type=="PauseResumeVote"then if payload.Ready~=true then self.HUD:Flash(tostring(payload.PlayerName or"PLAYER").." READY TO RESUME",1.0)end
	elseif payload.Type=="PrematchSkipQueued"then if self.HUD then self.HUD:Flash(payload.Ready and"INTRO SKIPPED"or(tostring(payload.PlayerName or"PLAYER").." WANTS TO SKIP"),1.0)end
	elseif payload.Type=="PrematchSkip"then self.PrematchActive=false;self.PrematchSkipRequested=true;if self.Cutscenes then self.Cutscenes:SkipStadiumIntro()end;self:_playPrematchSkipTransition()
	elseif payload.Type=="SwitchTarget"then self.TeamControl:SetSwitchTarget(payload.Model);self.Indicators:SetNextSwitch(payload.Model)
	elseif payload.Type=="Possession"then self.HUD:SetPossession(payload.Owner or"",payload.OwnerUserId==Players.LocalPlayer.UserId);self.Indicators:SetBallCarrier(payload.Model);if self.Minimap then self.Minimap:SetBallCarrier(payload.Model)end;if payload.Model then if self.Visual then self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end end
	elseif payload.Type=="PassTarget"then self.Indicators:SetPassTarget(payload.Model)
	elseif payload.Type=="SetPiece"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted(payload.Kind)end;if self.Input and payload.Kind~="Corner" then self.Input:SetSuppressed(self.WatchMode==true)end;if self.Input and self.Input.ResetFreeKickModifiers and payload.Mode=="DirectShotFreeKick"then self.Input:ResetFreeKickModifiers()end;self.MatchInPlay=false;self.SetPieceMode=payload.Mode;self.SetPieceKind=payload.Kind;if payload.Taker and payload.Taker:IsA("Model")then self:_bindFootballer(payload.Taker,payload.Taker:GetAttribute("DisplayName"),payload.Taker:GetAttribute("position"))end;if self.Visual then self.Visual:ClearLock();self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;self.Trainer:SetMatchActive(false);self.Minimap:SetMatchActive(false);local aimingRestart=(payload.Kind=="FreeKick"or payload.Kind=="Penalty")and self.WatchMode~=true;self.AimLine:SetMatchActive(aimingRestart);self.GoalTarget:SetMatchActive(aimingRestart);if payload.Kind=="Kickoff"and self.HUD then self.HUD:PlayMatchHudIntro();self.HUD:ShowKickoffScorer()end;self.Cutscenes:Play(payload)
	elseif payload.Type=="CornerMode"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted("Corner")end;self.Input:SetSuppressed(true);local takerAnimation=self.AnimationCache and self.AnimationCache[payload.Taker];if takerAnimation then takerAnimation:Play("Idle")end;if self.CornerAim then self.CornerAim:Destroy()end;if self.CornerCamera then self.CornerCamera:Destroy()end;self.CornerCamera=CornerCameraController.new(payload);self.CornerAim=CornerAimController.new(payload,self.Action,self.HUD);self.HUD:SetPhase("CORNER KICK")
	elseif payload.Type=="CornerReleased"then self.Input:SetSuppressed(false);if self.CornerAim then self.CornerAim:Destroy();self.CornerAim=nil end;if self.CornerCamera then self.CornerCamera:Destroy();self.CornerCamera=nil end;self.HUD:Flash(string.upper(payload.Delivery or"CROSS"),.7)
	elseif payload.Type=="Phase"then self.PrematchActive=false;if self.Input then self.Input:SetSuppressed(self.WatchMode==true)end;if workspace:GetAttribute("VTRKickoffDebug") ~= false then print("[VTR KICKOFF][Client] Phase",payload.Phase or"nil","active",self.ActiveModel and self.ActiveModel.Name or"nil","inputSuppressed",self.Input and self.Input.Suppressed)end;if self.Camera and self.Camera.EndCutscene and payload.HoldCutscene~=true then self.Camera:EndCutscene()end;if self.Visual then self.Visual:ClearLock()end;self.SetPieceMode=nil;self.SetPieceKind=nil;self.MatchInPlay=payload.Phase=="IN PLAY";self.Trainer:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);self.Minimap:SetMatchActive(self.MatchInPlay);self.AimLine:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);self.GoalTarget:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);self.HUD:SetPhase(payload.Phase or"IN PLAY")
	elseif payload.Type=="HalfTime"then self.MatchInPlay=false;self.HalfTimePauseActive=true;self.Paused=true;self.Trainer:SetMatchActive(false);self.Minimap:SetMatchActive(false);self.AimLine:SetMatchActive(false);self.GoalTarget:SetMatchActive(false);self.Cutscenes:HalfTime(payload);payload.ControlledSide=self.ControlledSide;task.delay(8,function()if self.Active and self.HalfTimePauseActive and self.HUD then self.HUD:SetPaused(true,self.Camera,function()self:_cleanup(true)end,payload,function()self.Action:FireServer({Type="Forfeit"})end)end end)
	elseif payload.Type=="HalfTimeTimer"then if self.HUD then self.HUD:SetPauseTimer(payload.Remaining or 0)end
	elseif payload.Type=="HalfTimeResume"then self.HalfTimePauseActive=false;self.Paused=false;if self.HUD then self.HUD:ClearPause()end
	elseif payload.Type=="Pass"then if self.HUD then self.HUD:HideKickoffScorer()end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Pass")end
	elseif payload.Type=="CornerKick"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if self.Visual then self.Visual:PlayFlightTrail()end
	elseif payload.Type=="Shot"then if self.ReplayController then self.ReplayController:MarkShot(payload.Actor)end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if self.HUD then self.HUD:ShowShotChance(payload.ScoringChance or payload.ScoringChancePercent,payload.Actor)end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Shoot")end
	elseif payload.Type=="ReceiveBall"and payload.Model==self.ActiveModel then self.Animation:Play("Receive")
	elseif payload.Type=="Tackle"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Tackle")end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Tackle")end
	elseif payload.Type=="SlideTackle"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("SlideTackle")end;self.HUD:Flash("SLIDE TACKLE",.55)
	elseif payload.Type=="DribbleMove"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play(payload.Animation or"DribbleMove1")end
	elseif payload.Type=="Block"then if self.HUD then self.HUD:ResolveShotChance(false)end;self.HUD:Flash("SHOT BLOCKED",.6)
	elseif payload.Type=="Clearance"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;self.HUD:Flash("CLEARANCE",.55)
	elseif payload.Type=="Foul"then self.HUD:ShowFoulBanner(payload)
	elseif payload.Type=="Offside"then self.HUD:Flash("OFFSIDE",1.1)
	elseif payload.Type=="Substitution"then self.HUD:ShowSubstitution(payload)
	elseif payload.Type=="GoalkeeperSave"then if self.HUD then self.HUD:ResolveShotChance(false)end;if self.Visual then self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Camera and self.Camera.EndCutscene then task.delay(1.5,function()if self.Camera then self.Camera:EndCutscene()end end)end;self.HUD:Flash("GREAT SAVE",.9)
	elseif payload.Type=="Clock"then self.Stamina=tonumber(payload.Stamina)or self.Stamina;self.Endurance=tonumber(payload.Endurance)or self.Endurance;self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:UpdateActiveRating()
	elseif payload.Type=="Kickoff"then if self.Visual then self.Visual:StopShotTrail()end;self.HUD:Flash("Kick Off",1)
	elseif payload.Type=="Goal"then if self.HUD then self.HUD:ResolveShotChance(true)end;self.MatchInPlay=false;if self.Visual then self.Visual:ClearLock();self.Visual:HoldShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;self.Trainer:SetMatchActive(false);self.Minimap:SetMatchActive(false);self.AimLine:SetMatchActive(false);self.GoalTarget:SetMatchActive(false);self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:RememberGoalScorer(payload);self.ReplayBlocking=true;self.ReplayQueuedPayloads={};self.ReplayQueuedClock=nil;if self.ReplayController then self.ReplayController:PlayGoalReplay(function()self:_finishGoalPresentation(payload)end)else self:_finishGoalPresentation(payload)end
	elseif payload.Type=="Info"then if payload.Important==true then self.HUD:Flash(payload.Message,1.3)end
	elseif payload.Type=="MatchEnded"then
		RunService:UnbindFromRenderStep("VTRMatchGameplay")
		if self.HUD then self.HUD:ClearPause()end
		self.Input:Destroy();self.Input=nil
		self.InputLock:Destroy();self.InputLock=nil
		self.Camera:Destroy();self.Camera=nil
		self.Visual:Destroy();self.Visual=nil
		self.BallRoll:Destroy();self.BallRoll=nil
		if self.FlightMarker then self.FlightMarker:Destroy();self.FlightMarker=nil end
		if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end
		for _,controller in self.AnimationCache or{}do controller:Destroy()end;self.AnimationCache={};self.Animation=nil
		self.TeamControl:Destroy();self.TeamControl=nil
		self.Indicators:Destroy();self.Indicators=nil
		self.Trainer:Destroy();self.Trainer=nil
		self.Minimap:Destroy();self.Minimap=nil
		self.AimLine:Destroy();self.AimLine=nil
		self.GoalTarget:Destroy();self.GoalTarget=nil
		self.Cutscenes:Destroy();self.Cutscenes=nil
		if self.PauseConnection then self.PauseConnection:Disconnect();self.PauseConnection=nil end
		self.HUD:ShowResult(payload,function()self:_cleanup(true)end)
	end
end
function Controller:_cleanup(restoreMenu:boolean)
	RunService:UnbindFromRenderStep("VTRMatchGameplay");if self.PauseConnection then self.PauseConnection:Disconnect();self.PauseConnection=nil end;if self.CornerAim then self.CornerAim:Destroy();self.CornerAim=nil end;if self.CornerCamera then self.CornerCamera:Destroy();self.CornerCamera=nil end;if self.Input then self.Input:Destroy()end;if self.InputLock then self.InputLock:Destroy()end;if self.Camera then self.Camera:Destroy()end;if self.Visual then self.Visual:Destroy()end;if self.BallRoll then self.BallRoll:Destroy()end;if self.FlightMarker then self.FlightMarker:Destroy();self.FlightMarker=nil end;if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end;if self.Commentary then self.Commentary:Destroy();self.Commentary=nil end;for _,controller in self.AnimationCache or{}do controller:Destroy()end;self.AnimationCache={};self.Animation=nil;if self.TeamControl then self.TeamControl:Destroy()end;if self.Indicators then self.Indicators:Destroy()end;if self.Trainer then self.Trainer:Destroy()end;if self.Minimap then self.Minimap:Destroy()end;if self.AimLine then self.AimLine:Destroy()end;if self.GoalTarget then self.GoalTarget:Destroy()end;if self.Cutscenes then self.Cutscenes:Destroy()end;if self.HUD then self.HUD:Destroy()end;if self.Controls then self.Controls:Enable()end;self.Active=false
	if restoreMenu then setMenuVisible(true)end
end
return Controller
