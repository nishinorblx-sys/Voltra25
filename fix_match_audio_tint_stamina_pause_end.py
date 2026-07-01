from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

prematch_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
prematch = prematch_path.read_text(encoding="utf-8")

prematch = prematch.replace(
	'table.insert(activeIntroSounds, playPresentationSound(INTRO_TRACKS[math.random(1, #INTRO_TRACKS)], .58, false))',
	'table.insert(activeIntroSounds, playPresentationSound(INTRO_TRACKS[math.random(1, #INTRO_TRACKS)], .58, true))'
)

prematch = prematch.replace("stopPresentationSound()", "")
prematch = prematch.replace(
'''	task.delay(TOTAL_DURATION, function()
		stopIntroAudio()
		
		if gui.Parent then gui:Destroy() end
		if onComplete then onComplete() end
	end)''',
'''	task.delay(TOTAL_DURATION, function()
		Presentation.StopAudio()
		if gui.Parent then gui:Destroy() end
		if onComplete then onComplete() end
	end)'''
)

if "function Presentation.StopAudio()" not in prematch:
    prematch = prematch.replace(
        "local function startIntroAudio(gui: ScreenGui)",
        "function Presentation.StopAudio()\n\tstopIntroAudio()\nend\n\nlocal function startIntroAudio(gui: ScreenGui)",
        1
    )

prematch_path.write_text(prematch, encoding="utf-8", newline="\n")

cutscene_path = Path("src/client/Gameplay/MatchCutsceneController.lua")
cutscene = cutscene_path.read_text(encoding="utf-8")
cutscene = cutscene.replace(
'''	if PrematchBroadcastPresentation.StopAudio then
		PrematchBroadcastPresentation.StopAudio()
	end
	if gui then gui:Destroy() end''',
'''	if PrematchBroadcastPresentation.StopAudio then
		PrematchBroadcastPresentation.StopAudio()
	end
	if gui then gui:Destroy() end'''
)
cutscene_path.write_text(cutscene, encoding="utf-8", newline="\n")

sound_path = Path("src/client/Gameplay/MatchSoundController.lua")
sound = sound_path.read_text(encoding="utf-8")

sound = re.sub(
r'''local GOAL_COMMENTATORS = \{
.*?
\}''',
'''local GOAL_COMMENTATORS = {
	"rbxassetid://103341909626250",
	"rbxassetid://74702312530338",
	"rbxassetid://103290564397158",
	"rbxassetid://85367905011258",
	"rbxassetid://117754134274157",
	"rbxassetid://72037349498821",
	"rbxassetid://95283998273205",
	"rbxassetid://135072046987673",
}''',
sound,
count=1,
flags=re.S
)

sound = sound.replace('local FINAL_WHISTLE = "rbxassetid://72085323238660"', 'local FINAL_WHISTLE = "rbxassetid://135741471105087"')

sound = re.sub(
r'''local GOAL_SOUNDS = \{
.*?
\}''',
'''local GOAL_SOUNDS = {
	"rbxassetid://78442706550929",
	"rbxassetid://119353871044168",
	"rbxassetid://106000542837895",
	"rbxassetid://75642333208760",
}''',
sound,
count=1,
flags=re.S
)

sound = sound.replace(
'''	self.LastDribble = 0
	self.Connection = nil''',
'''	self.LastDribble = 0
	self.LastGoalSfxAt = 0
	self.Connection = nil''',
1
)

sound = re.sub(
r'''function Controller:PlayGoal\(\)
.*?
end''',
'''function Controller:PlayGoal()
	if os.clock() - (self.LastGoalSfxAt or 0) > .75 then
		self.LastGoalSfxAt = os.clock()
		playOneShot(GOAL_SOUNDS[math.random(1, #GOAL_SOUNDS)], 0.7, 1)
		playOneShot("rbxassetid://75642333208760", 0.58, 1)
	end
	task.delay(0.12, function()
		playOneShot(GOAL_COMMENTATORS[math.random(1, #GOAL_COMMENTATORS)], 0.76, 1)
	end)
end

function Controller:PlayGoalPreview()
	if os.clock() - (self.LastGoalSfxAt or 0) <= .75 then return end
	self.LastGoalSfxAt = os.clock()
	playOneShot(GOAL_SOUNDS[math.random(1, #GOAL_SOUNDS)], 0.64, 1)
	playOneShot("rbxassetid://75642333208760", 0.52, 1)
end''',
sound,
count=1,
flags=re.S
)

sound_path.write_text(sound, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

if 'local Lighting=game:GetService("Lighting")' not in gameplay:
    gameplay = gameplay.replace(
        'local UserInputService=game:GetService("UserInputService")',
        'local UserInputService=game:GetService("UserInputService")\nlocal Lighting=game:GetService("Lighting")',
        1
    )

gameplay = re.sub(
r'''local function setMenuVisible\(visible:boolean\)
.*?
end
local TACTIC_DEBUG_GROUPS''',
'''local function clearGreenScreenEffects()
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
local TACTIC_DEBUG_GROUPS''',
gameplay,
count=1,
flags=re.S
)

if "local function clearGreenScreenEffects()" not in gameplay:
    gameplay = gameplay.replace(
        "local TACTIC_DEBUG_GROUPS",
        '''local function clearGreenScreenEffects()
	for _, inst in ipairs(Lighting:GetDescendants()) do
		if inst:IsA("ColorCorrectionEffect") then
			inst.Enabled = false
			inst.TintColor = Color3.new(1,1,1)
			inst.Saturation = 0
			inst.Contrast = 0
			inst.Brightness = 0
		end
	end
	if workspace.CurrentCamera then
		for _, inst in ipairs(workspace.CurrentCamera:GetDescendants()) do
			if inst:IsA("ColorCorrectionEffect") then
				inst.Enabled = false
				inst.TintColor = Color3.new(1,1,1)
				inst.Saturation = 0
				inst.Contrast = 0
				inst.Brightness = 0
			end
		end
	end
	Lighting.ColorShift_Top = Color3.new(0,0,0)
	Lighting.ColorShift_Bottom = Color3.new(0,0,0)
end
local TACTIC_DEBUG_GROUPS''',
        1
    )

if "while self.Active do\n\t\t\tclearGreenScreenEffects()" not in gameplay:
    gameplay = gameplay.replace(
'''	self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.WatchMode then self.Input:SetSuppressed(true);if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))''',
'''	self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.WatchMode then self.Input:SetSuppressed(true);if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))
	task.spawn(function()
		while self.Active do
			clearGreenScreenEffects()
			task.wait(.25)
		end
	end)''',
1
    )

gameplay = gameplay.replace(
'''	elseif payload.Type=="Shot"then if self.MatchSounds then self.MatchSounds:PlayKick()end;''',
'''	elseif payload.Type=="Shot"then if self.MatchSounds then self.MatchSounds:PlayKick()end;'''
)

gameplay = gameplay.replace(
'''	elseif payload.Type=="Goal"then if self.MatchSounds then self.MatchSounds:PlayGoal()end;''',
'''	elseif payload.Type=="GoalSoundPreview"then if self.MatchSounds and self.MatchSounds.PlayGoalPreview then self.MatchSounds:PlayGoalPreview()end
	elseif payload.Type=="Goal"then if self.MatchSounds then self.MatchSounds:PlayGoal()end;''',
1
)

gameplay = gameplay.replace(
'''	if restoreMenu then setMenuVisible(true)
	clearGreenScreenEffects()end''',
'''	if restoreMenu then
		Players.LocalPlayer:SetAttribute("VTRInMatch",false)
		setMenuVisible(true)
		clearGreenScreenEffects()
	end''',
1
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

hud_path = Path("src/client/Gameplay/MatchHUDController.lua")
hud = hud_path.read_text(encoding="utf-8")

hud = re.sub(
r'''function Controller:SetStamina\(value: number,endurance:number\?\)
.*?
end''',
'''function Controller:SetStamina(value: number,endurance:number?)
	local reserveRatio=math.clamp(value,0,1)
	if self.EnduranceFill then
		self.EnduranceFill.Visible=false
		self.EnduranceFill.Size=UDim2.fromScale(1,1)
	end
	self.Fill.Size=UDim2.fromScale(reserveRatio,1)
end''',
hud,
count=1,
flags=re.S
)

hud_path.write_text(hud, encoding="utf-8", newline="\n")

stamina_path = Path("src/server/Gameplay/StaminaService.lua")
stamina = stamina_path.read_text(encoding="utf-8")

stamina = re.sub(
r'''function Service:Step\(model: Model, dt: number, state: any\): \(number,number\)
.*?
end''',
'''function Service:Step(model: Model, dt: number, state: any): (number,number)
	local staminaStat = math.clamp(tonumber(model:GetAttribute("Stamina")) or 65, 1, 99)
	local reserve = math.clamp(tonumber(model:GetAttribute("VTRSprintStamina")) or tonumber(model:GetAttribute("VTRStamina")) or Config.Maximum, 0, Config.Maximum)
	local sprintDuration = math.max(0, tonumber(model:GetAttribute("VTRSprintDuration")) or 0)
	local controlled = state.UserControlled == true
	local sprintLocked = model:GetAttribute("VTRSprintLocked") == true and not controlled
	local sprinting = controlled and not sprintLocked and state.Sprinting == true and (tonumber(state.MoveMagnitude) or 0) > 0.1
	local speed = math.max(0, tonumber(state.CurrentSpeed) or 0)
	local quality = math.clamp((staminaStat - 35) / 64, 0, 1)
	if sprinting then
		sprintDuration += dt
		local speedModifier = 0.9 + math.clamp(speed / 30, 0, 1) * 0.16
		local durationModifier = 1 + math.clamp(sprintDuration / Config.SprintDurationRampSeconds, 0, 1) * Config.SprintDurationMaxPenalty
		local possessionModifier = state.HasBall == true and 1.04 or 1
		local drain = (Config.SprintReserveDrainMax - (Config.SprintReserveDrainMax - Config.SprintReserveDrainMin) * quality) * buildModifier(model) * positionModifier(model) * speedModifier * durationModifier * possessionModifier
		reserve = math.max(0, reserve - drain * dt)
	else
		sprintDuration = math.max(0, sprintDuration - dt * 2.1)
		local idle = speed < 5
		local recovery = idle and (Config.IdleRecoveryMin + (Config.IdleRecoveryMax - Config.IdleRecoveryMin) * quality) or (Config.JogRecoveryMin + (Config.JogRecoveryMax - Config.JogRecoveryMin) * quality)
		if not controlled then
			recovery = math.max(recovery * Config.UnusedRecoveryMultiplier, Config.IdleRecoveryMax * 1.35)
		end
		reserve = math.min(Config.Maximum, reserve + recovery * dt)
	end
	if reserve <= .05 then
		sprintLocked = true
	elseif sprintLocked and reserve >= Config.ExhaustedRecoveryThreshold then
		sprintLocked = false
	end
	model:SetAttribute("VTREndurance", reserve)
	model:SetAttribute("VTRSprintStamina", reserve)
	model:SetAttribute("VTRStamina", reserve)
	model:SetAttribute("VTRSprintDuration", sprintDuration)
	model:SetAttribute("VTRSprintLocked", sprintLocked)
	return reserve, reserve
end''',
stamina,
count=1,
flags=re.S
)

stamina_path.write_text(stamina, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

if "local function safeReturnCFrame" not in runtime:
    runtime = runtime.replace(
'''local function lookAtFlat(position:Vector3,target:Vector3):CFrame
	local flat=Vector3.new(target.X,position.Y,target.Z)
	if (flat-position).Magnitude<.05 then flat=position+Vector3.zAxis end
	return CFrame.lookAt(position,flat)
end''',
'''local function lookAtFlat(position:Vector3,target:Vector3):CFrame
	local flat=Vector3.new(target.X,position.Y,target.Z)
	if (flat-position).Magnitude<.05 then flat=position+Vector3.zAxis end
	return CFrame.lookAt(position,flat)
end
local function safeReturnCFrame(state:any):CFrame
	if state and typeof(state.ReturnCFrame)=="CFrame" then return state.ReturnCFrame + Vector3.new(0,3,0) end
	local spawn=Workspace:FindFirstChildWhichIsA("SpawnLocation",true)
	if spawn then return spawn.CFrame + Vector3.new(0,5,0) end
	return CFrame.new(0,18,0)
end''',
1
    )

runtime = runtime.replace('character:PivotTo(state and state.ReturnCFrame or CFrame.new(0,8,0))', 'character:PivotTo(safeReturnCFrame(state))')
runtime = runtime.replace(
'''if humanoid then humanoid.WalkSpeed=state and state.PreviousSpeed or 16;humanoid.JumpPower=state and state.PreviousJump or 50;humanoid.AutoRotate=true end''',
'''if humanoid then humanoid.WalkSpeed=state and state.PreviousSpeed or 16;humanoid.JumpPower=state and state.PreviousJump or 50;humanoid.AutoRotate=true;humanoid.PlatformStand=false;humanoid.Sit=false;humanoid.Health=math.max(1,humanoid.MaxHealth) end'''
)

runtime = replace_once(
runtime,
'''	session.Paused=true
	session.PauseQueued=false
	session.PauseRequestedBy=nil
	session.PauseRequester=requester
	session.PauseResumeVotes={}
	self:_setPlayersFrozen(session,true)
	broadcast(self.State,session,self:_pausePayload(session,true,requester))''',
'''	session.Paused=true
	session.PauseQueued=false
	session.PauseRequestedBy=nil
	session.PauseRequester=requester
	session.PauseResumeVotes={}
	if session.World and session.World.Ball then
		session.World.Ball:SetAttribute("VTRPauseSavedVelocity",session.World.Ball.AssemblyLinearVelocity)
		session.World.Ball:SetAttribute("VTRPauseSavedAngularVelocity",session.World.Ball.AssemblyAngularVelocity)
		session.World.Ball:SetAttribute("VTRWorldPaused",true)
		session.World.Ball.Anchored=true
	end
	for _,model in session.Models or{}do
		local root=model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart")then
			model:SetAttribute("VTRPauseSavedVelocity",root.AssemblyLinearVelocity)
			model:SetAttribute("VTRPauseSavedAngularVelocity",root.AssemblyAngularVelocity)
			root.Anchored=true
		end
	end
	self:_setPlayersFrozen(session,true)
	broadcast(self.State,session,self:_pausePayload(session,true,requester))''',
"open pause freeze"
)

runtime = replace_once(
runtime,
'''	broadcast(self.State, session, {Type="Pause", Active=false})''',
'''	if session.World and session.World.Ball then
		session.World.Ball:SetAttribute("VTRWorldPaused",nil)
	end
	broadcast(self.State,session,self:_pausePayload(session,false,nil))''',
"resume pause payload"
)

runtime = replace_once(
runtime,
'''	if team=="Home"then session.World.HomeScore.Value+=1 else session.World.AwayScore.Value+=1 end''',
'''	broadcast(self.State,session,{Type="GoalSoundPreview",Team=team})
	task.wait(.08)
	if team=="Home"then session.World.HomeScore.Value+=1 else session.World.AwayScore.Value+=1 end''',
"goal preview sound before score"
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = replace_once(
ball,
'''function Service:Step(dt: number)
	local owner = self.Possession:GetOwner()''',
'''function Service:Step(dt: number)
	if self.Ball:GetAttribute("VTRWorldPaused")==true then return end
	local owner = self.Possession:GetOwner()''',
"ball pause freeze"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

print("fixed prematch audio, green tint cleanup, stamina, pause freeze, menu return, match end safety, and goal audio")