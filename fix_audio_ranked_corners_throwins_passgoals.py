from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

sound_path = Path("src/client/Gameplay/MatchSoundController.lua")
sound = sound_path.read_text(encoding="utf-8")

sound = re.sub(
r'''local function playOneShot\(soundId: string, volume: number, speed: number\?\)
.*?
end''',
'''local function playOneShot(soundId: string, volume: number, speed: number?)
	local sound = Instance.new("Sound")
	sound.Name = "VTRMatchOneShot"
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	sound:Play()
	task.delay(180, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end''',
sound,
count=1,
flags=re.S
)

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

prematch_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
prematch = prematch_path.read_text(encoding="utf-8")

prematch = re.sub(
r'''local function playPresentationSound\(soundId: string, volume: number\?, looped: boolean\?\)
.*?
end''',
'''local function playPresentationSound(soundId: string, volume: number?, looped: boolean?)
	local sound = Instance.new("Sound")
	sound.Name = "VTRPresentationAudio"
	sound.SoundId = soundId
	sound.Volume = volume or .62
	sound.Looped = looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		if sound.Parent then sound:Destroy() end
	end)
	sound:Play()
	return sound
end''',
prematch,
count=1,
flags=re.S
)

prematch = prematch.replace(
	'table.insert(activeIntroSounds, playPresentationSound(INTRO_TRACKS[math.random(1, #INTRO_TRACKS)], .58, true))',
	'table.insert(activeIntroSounds, playPresentationSound(INTRO_TRACKS[math.random(1, #INTRO_TRACKS)], .58, false))'
)

prematch = prematch.replace(
	'table.insert(activeIntroSounds, playPresentationSound(INTRO_TRACKS[math.random(1, #INTRO_TRACKS)], .58, false))',
	'table.insert(activeIntroSounds, playPresentationSound(INTRO_TRACKS[math.random(1, #INTRO_TRACKS)], .58, false))'
)

prematch = prematch.replace("stopPresentationSound()", "")

if "function Presentation.StopAudio()" not in prematch:
    prematch = prematch.replace(
        "local function startIntroAudio(gui: ScreenGui)",
        "function Presentation.StopAudio()\n\tstopIntroAudio()\nend\n\nlocal function startIntroAudio(gui: ScreenGui)",
        1
    )

prematch = prematch.replace("gui.Destroying:Connect(stopIntroAudio)", "")

prematch = re.sub(
r'''	task.delay\(TOTAL_DURATION, function\(\)
.*?
		if gui.Parent then gui:Destroy\(\) end
		if onComplete then onComplete\(\) end
	end\)''',
'''	task.delay(TOTAL_DURATION, function()
		Presentation.StopAudio()
		if gui.Parent then gui:Destroy() end
		if onComplete then onComplete() end
	end)''',
prematch,
count=1,
flags=re.S
)

prematch_path.write_text(prematch, encoding="utf-8", newline="\n")

corner_client_path = Path("src/client/Gameplay/CornerAimController.lua")
corner_client_path.write_text('''--!strict
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local Controller={};Controller.__index=Controller

local function root(model:Model):BasePart?
	return model:FindFirstChild("HumanoidRootPart")::BasePart?
end

local function isKeeper(model:Model):boolean
	return tostring(model:GetAttribute("position")or"")=="GK"
end

function Controller.new(data:any,remote:RemoteEvent,hud:any)
	local self=setmetatable({Data=data,Remote=remote,HUD=hud,Connections={},Labels={},Active=true,Candidates={}},Controller)
	local teamModels=data.TeamModels and data.TeamModels[data.Team] or {}
	for _,model in teamModels do
		local modelRoot=root(model)
		if model~=data.Taker and modelRoot and not isKeeper(model) then
			local localPosition=data.PitchCFrame:PointToObjectSpace(modelRoot.Position)
			local inBox=math.abs(localPosition.X)<=data.PitchWidth*.43 and ((tonumber(data.GoalSign)or 1)>0 and localPosition.Z>=data.PitchLength*.5-132 or (tonumber(data.GoalSign)or 1)<0 and localPosition.Z<=-data.PitchLength*.5+132)
			if inBox then
				table.insert(self.Candidates,model)
				local gui=Instance.new("BillboardGui")
				gui.Name="VTRCornerReceiverPick"
				gui.Adornee=modelRoot
				gui.Size=UDim2.fromOffset(132,34)
				gui.StudsOffsetWorldSpace=Vector3.new(0,4.2,0)
				gui.AlwaysOnTop=true
				gui.Parent=Players.LocalPlayer.PlayerGui
				local text=Instance.new("TextLabel")
				text.Size=UDim2.fromScale(1,1)
				text.BackgroundColor3=Color3.fromRGB(2,4,2)
				text.BackgroundTransparency=.18
				text.BorderSizePixel=0
				text.Text=string.upper(tostring(model:GetAttribute("DisplayName")or model.Name))
				text.TextColor3=Color3.fromRGB(245,247,242)
				text.TextStrokeTransparency=.6
				text.Font=Enum.Font.GothamBlack
				text.TextSize=9
				text.Parent=gui
				table.insert(self.Labels,gui)
			end
		end
	end
	local trainer=Instance.new("BillboardGui")
	trainer.Name="VTRCornerTrainer"
	trainer.Adornee=data.Ball
	trainer.Size=UDim2.fromOffset(240,54)
	trainer.StudsOffsetWorldSpace=Vector3.new(0,3.4,0)
	trainer.AlwaysOnTop=true
	trainer.Parent=Players.LocalPlayer.PlayerGui
	local text=Instance.new("TextLabel")
	text.Size=UDim2.fromScale(1,1)
	text.BackgroundTransparency=1
	text.Text="CLICK A TARGET IN THE BOX"
	text.TextColor3=Color3.fromRGB(240,244,238)
	text.TextStrokeTransparency=.55
	text.Font=Enum.Font.GothamBold
	text.TextSize=12
	text.Parent=trainer
	self.Trainer=trainer
	table.insert(self.Connections,UserInputService.InputBegan:Connect(function(input,processed)
		if processed or not self.Active then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 then
			self:_release()
		end
	end))
	return self
end

function Controller:_screenBest():Model?
	local camera=workspace.CurrentCamera
	if not camera then return self.Candidates[1] end
	local mouse=UserInputService:GetMouseLocation()
	local best=nil
	local bestScore=math.huge
	for _,model in self.Candidates do
		local modelRoot=root(model)
		if modelRoot then
			local point,visible=camera:WorldToViewportPoint(modelRoot.Position+Vector3.new(0,3,0))
			if visible and point.Z>0 then
				local distance=(Vector2.new(point.X,point.Y)-mouse).Magnitude
				if distance<bestScore then
					bestScore=distance
					best=model
				end
			end
		end
	end
	return best or self.Candidates[1]
end

function Controller:_release()
	if not self.Active then return end
	local receiver=self:_screenBest()
	if not receiver then return end
	local receiverRoot=root(receiver)
	if not receiverRoot then return end
	self.Active=false
	self.Remote:FireServer({Type="CornerKick",Delivery="Cross",Power=.66,Target=receiverRoot.Position,Receiver=receiver})
end

function Controller:Update()
	if not self.Active then return end
	if self.HUD then self.HUD:SetCharge(0,"")end
end

function Controller:GetTarget():Vector3
	local receiver=self:_screenBest()
	local receiverRoot=receiver and root(receiver)
	return receiverRoot and receiverRoot.Position or self.Data.Ball.Position
end

function Controller:Destroy()
	self.Active=false
	for _,connection in self.Connections do connection:Disconnect()end
	for _,gui in self.Labels do if gui.Parent then gui:Destroy()end end
	if self.Trainer then self.Trainer:Destroy()end
	if self.HUD then self.HUD:SetCharge(0,"")end
end

return Controller
''', encoding="utf-8", newline="\n")

formation_path = Path("src/server/Gameplay/FormationPositionService.lua")
formation = formation_path.read_text(encoding="utf-8")

formation = re.sub(
r'''function Service.ThrowIn\(teams: any, restartTeam: string, location: Vector3, pitchCFrame: CFrame, width: number, length: number\): Model
.*?
end

function Service.GoalKick''',
'''function Service.ThrowIn(teams: any, restartTeam: string, location: Vector3, pitchCFrame: CFrame, width: number, length: number): Model
	local localExit = pitchCFrame:PointToObjectSpace(location)
	local touchSign = localExit.X >= 0 and 1 or -1
	local x = touchSign * (width / 2 - 1.2)
	local z = math.clamp(localExit.Z, -length / 2 + 8, length / 2 - 8)
	local spot = world(pitchCFrame, x, z)
	local taker = nil
	local nearest = math.huge
	for _, model in teams[restartTeam] do
		local modelRoot = root(model)
		if modelRoot and not isKeeper(model) and (modelRoot.Position - spot).Magnitude < nearest then
			nearest = (modelRoot.Position - spot).Magnitude
			taker = model
		end
	end
	taker = taker or teams[restartTeam][2] or teams[restartTeam][1]
	move(taker, spot, world(pitchCFrame, 0, z))
	local options = {}
	for _, model in teams[restartTeam] do
		if model ~= taker and not isKeeper(model) and root(model) then
			table.insert(options, model)
		end
	end
	table.sort(options, function(a, b) return ((root(a) :: BasePart).Position - spot).Magnitude < ((root(b) :: BasePart).Position - spot).Magnitude end)
	for index = 1, math.min(2, #options) do
		local option = options[index]
		local optionPosition = world(pitchCFrame, x - touchSign * (index == 1 and 13 or 20), z + (index == 1 and 0 or -17))
		move(option, optionPosition, spot)
	end
	local protected: {[Model]: boolean} = {[taker] = true}
	for index = 1, math.min(2, #options) do
		protected[options[index]] = true
	end
	for index, model in teams[restartTeam] do
		if protected[model] or isKeeper(model) then continue end
		local lane = ((index - 1) % 5 - 2) * width * 0.16
		local depth = math.clamp(z + (restartTeam == "Home" and 1 or -1) * (46 + math.floor((index - 1) / 4) * 28), -length / 2 + 28, length / 2 - 28)
		move(model, world(pitchCFrame, lane, depth), spot)
	end
	return taker
end

function Service.GoalKick''',
formation,
count=1,
flags=re.S
)

formation_path.write_text(formation, encoding="utf-8", newline="\n")

setpiece_path = Path("src/server/Gameplay/SetPieceService.lua")
setpiece = setpiece_path.read_text(encoding="utf-8")

setpiece = replace_once(
setpiece,
'''	if delivery~="Short"then
		local plan=cornerDeliveryPlan(active.Data,self.Teams,active.Data.Team or active.Data.RestartTeam or tostring(active.Data.Taker:GetAttribute("VTRTeam") or "Home"))
		plannedReceiver=plan.Receiver
		target=plan.Target
		delivery=plan.Delivery
		power=plan.Power
		active.Data.CornerReceiver=plannedReceiver
		active.Data.CornerPlanRole=plan.Role
	end''',
'''	if delivery~="Short"then
		local requested=payload.Receiver
		local team=active.Data.Team or active.Data.RestartTeam or tostring(active.Data.Taker:GetAttribute("VTRTeam") or "Home")
		if typeof(requested)=="Instance" and requested:IsA("Model") and requested:GetAttribute("VTRTeam")==team and requested~=active.Data.Taker and not isKeeper(requested) then
			plannedReceiver=requested
			target=select(1,cornerLanding(active.Data,requested,tostring(requested:GetAttribute("VTRCornerRole") or "PenaltySpot")))
			delivery="Cross"
			power=math.clamp(power>.05 and power or .66,.45,.78)
			active.Data.CornerReceiver=plannedReceiver
			active.Data.CornerPlanRole=tostring(requested:GetAttribute("VTRCornerRole") or "PenaltySpot")
		else
			local plan=cornerDeliveryPlan(active.Data,self.Teams,team)
			plannedReceiver=plan.Receiver
			target=plan.Target
			delivery=plan.Delivery
			power=plan.Power
			active.Data.CornerReceiver=plannedReceiver
			active.Data.CornerPlanRole=plan.Role
		end
	end''',
"corner receiver selection"
)

setpiece = setpiece.replace(
'''if userControlled==true and player and player.Parent then self.Remote:FireClient(player,{Type="CornerMode",Team=restartTeam,Taker=taker,Ball=self.World.Ball,Location=ballPosition,CornerSign=data.CornerSign,GoalSign=data.GoalSign,PitchCFrame=self.World.PitchCFrame,PitchWidth=self.World.Width,PitchLength=self.World.Length})''',
'''if userControlled==true and player and player.Parent then self.Remote:FireClient(player,{Type="CornerMode",Team=restartTeam,Taker=taker,Ball=self.World.Ball,Location=ballPosition,CornerSign=data.CornerSign,GoalSign=data.GoalSign,PitchCFrame=self.World.PitchCFrame,PitchWidth=self.World.Width,PitchLength=self.World.Length,TeamModels=self.Teams})''',
1
)

setpiece_path.write_text(setpiece, encoding="utf-8", newline="\n")

goal_path = Path("src/server/Gameplay/GoalService.lua")
goal = goal_path.read_text(encoding="utf-8")

if "function Service:_denyNonShotGoal" not in goal:
    goal = goal.replace(
'''function Service:_recordGoalEntry(team: string, previous: Vector3, current: Vector3, now: number)''',
'''function Service:_denyNonShotGoal(goal: any, current: Vector3): boolean
	local kind = tostring(self.Ball:GetAttribute("VTRMotionKind") or "")
	if kind == "Shot" or kind == "Corner" or self.Ball:GetAttribute("VTRPenaltyShotActive") == true then
		return false
	end
	if kind == "Pass" or kind == "Clearance" or kind == "Dribble" then
		local safe = self.PreviousBallPosition
		if typeof(safe) ~= "Vector3" then safe = current end
		self.Ball.CFrame = CFrame.new(safe)
		self.Ball.AssemblyLinearVelocity = Vector3.zero
		self.Ball.AssemblyAngularVelocity = Vector3.zero
		self.Ball:SetAttribute("VTRDeniedNonShotGoalAt", os.clock())
		self.PreviousBallPosition = safe
		self.PreviousStepClock = os.clock()
		self.PreviousBallVelocity = Vector3.zero
		for _, item in self.Goals do item.WasInside = false end
		return true
	end
	return false
end

function Service:_recordGoalEntry(team: string, previous: Vector3, current: Vector3, now: number)''',
1
    )

goal = goal.replace(
'''if inside and not goal.WasInside then goal.WasInside=true;self:_recordGoalEntry(goal.Team, previous, current, now);return end''',
'''if inside and not goal.WasInside then goal.WasInside=true;if self:_denyNonShotGoal(goal,current) then return end;self:_recordGoalEntry(goal.Team, previous, current, now);return end''',
1
)

goal = goal.replace(
'''if fullyInside then
				self:_recordGoalEntry(goal.Team, previous, current, now)
				return
			end''',
'''if fullyInside then
				if self:_denyNonShotGoal(goal,crossing) then return end
				self:_recordGoalEntry(goal.Team, previous, current, now)
				return
			end''',
1
)

goal_path.write_text(goal, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = re.sub(
r'''	if kind~="Kickoff" then
		task.delay\(10,function\(\)
.*?
		end\)
	end''',
'''	''',
runtime,
count=1,
flags=re.S
)

runtime = runtime.replace(
'''		if session.PendingAIPenalty and not session.Running and session.Phase=="Penalty"and os.clock()>=session.PendingAIPenalty.At then
			self:_releaseAIPenalty(session)
		end''',
'''		if false and session.PendingAIPenalty and not session.Running and session.Phase=="Penalty"and os.clock()>=session.PendingAIPenalty.At then
			self:_releaseAIPenalty(session)
		end''',
1
)

runtime = replace_once(
runtime,
'''	if team=="Home"then session.World.HomeScore.Value+=1 else session.World.AwayScore.Value+=1 end''',
'''	broadcast(self.State,session,{Type="GoalSoundPreview",Team=team})
	task.wait(.08)
	if team=="Home"then session.World.HomeScore.Value+=1 else session.World.AwayScore.Value+=1 end''',
"goal sound before score"
)

runtime = runtime.replace('character:PivotTo(state and state.ReturnCFrame or CFrame.new(0,8,0))', 'character:PivotTo(state and state.ReturnCFrame or CFrame.new(0,12,0))')
runtime = runtime.replace(
'''humanoid.WalkSpeed=state and state.PreviousSpeed or 16;humanoid.JumpPower=state and state.PreviousJump or 50;humanoid.AutoRotate=true''',
'''humanoid.WalkSpeed=state and state.PreviousSpeed or 16;humanoid.JumpPower=state and state.PreviousJump or 50;humanoid.AutoRotate=true;humanoid.PlatformStand=false;humanoid.Sit=false;humanoid.Health=math.max(1,humanoid.MaxHealth)'''
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

if 'local Lighting=game:GetService("Lighting")' not in gameplay:
    gameplay = gameplay.replace('local UserInputService=game:GetService("UserInputService")', 'local UserInputService=game:GetService("UserInputService")\nlocal Lighting=game:GetService("Lighting")', 1)

if "local function clearGreenScreenEffects()" not in gameplay:
    gameplay = gameplay.replace(
'''local Controller={};Controller.__index=Controller''',
'''local Controller={};Controller.__index=Controller
local function clearGreenScreenEffects()
	for _, inst in ipairs(Lighting:GetDescendants()) do
		if inst:IsA("ColorCorrectionEffect") then
			inst.Enabled=false
			inst.TintColor=Color3.new(1,1,1)
			inst.Saturation=0
			inst.Contrast=0
			inst.Brightness=0
		elseif inst:IsA("Atmosphere") then
			local c=inst.Color
			local d=inst.Decay
			if c.G>c.R+.06 and c.G>c.B+.06 then inst.Color=Color3.fromRGB(198,198,198)end
			if d.G>d.R+.06 and d.G>d.B+.06 then inst.Decay=Color3.fromRGB(106,112,120)end
		end
	end
	if workspace.CurrentCamera then
		for _, inst in ipairs(workspace.CurrentCamera:GetDescendants()) do
			if inst:IsA("ColorCorrectionEffect") then
				inst.Enabled=false
				inst.TintColor=Color3.new(1,1,1)
				inst.Saturation=0
				inst.Contrast=0
				inst.Brightness=0
			end
		end
	end
	Lighting.ColorShift_Top=Color3.new(0,0,0)
	Lighting.ColorShift_Bottom=Color3.new(0,0,0)
end''',
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

ranked_pack_path = Path("src/server/Services/RankedWinPackReward.lua")
ranked_pack = ranked_pack_path.read_text(encoding="utf-8")

ranked_pack = ranked_pack.replace(
'''	if publish and progression and progression.GetClientData then
		pcall(function()
			publish(player, "Progression", progression:GetClientData(player))
		end)
	end''',
'''	if publish and progression and progression.GetClientData then
		pcall(function()
			publish(player, "Progression", progression:GetClientData(player))
		end)
	end
	if publish and progression and progression.Inventory and progression.Inventory.GetClientData then
		pcall(function()
			publish(player, "Inventory", progression.Inventory:GetClientData(player))
		end)
	end''',
1
)

ranked_pack_path.write_text(ranked_pack, encoding="utf-8", newline="\n")

ranked_queue_path = Path("src/server/Services/RankedQueueService.lua")
ranked_queue = ranked_queue_path.read_text(encoding="utf-8")

ranked_queue = ranked_queue.replace(
'''		self.RankedProfiles:RecordServerResult(home, homeResult, rpFor(homeResult), away.Name, score, personal("Home"))
		self.RankedProfiles:RecordServerResult(away, awayResult, rpFor(awayResult), home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), personal("Away"))''',
'''		if ended.RankedResultsRecorded==true then return end
		ended.RankedResultsRecorded=true
		self.RankedProfiles:RecordServerResult(home, homeResult, rpFor(homeResult), away.Name, score, personal("Home"))
		self.RankedProfiles:RecordServerResult(away, awayResult, rpFor(awayResult), home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), personal("Away"))''',
1
)

ranked_queue = ranked_queue.replace(
'''		local rewards = {}
		local homeScore=ended.World.HomeScore.Value''',
'''		local rewards = {}
		local homeScore=ended.World.HomeScore.Value''',
1
)

ranked_queue = ranked_queue.replace(
'''		local homeResult=resultFor(home,"Home",homeScore,awayScore)
		local awayResult=resultFor(away,"Away",homeScore,awayScore)''',
'''		local homeResult=resultFor(home,"Home",homeScore,awayScore)
		local awayResult=resultFor(away,"Away",homeScore,awayScore)
		if ended.RankedResultsRecorded~=true then
			ended.RankedResultsRecorded=true
			local score=tostring(homeScore).."-"..tostring(awayScore)
			local serialized=ended.Stats:Serialize(homeScore,awayScore,ended.Clock:Payload().GameSeconds)
			local function personal(side:string):any
				local best=nil
				for _,entry in serialized.PlayerRatings or{}do
					if entry.Team==side and (not best or entry.Rating>best.Rating)then best=entry end
				end
				return{PlayerRating=best and best.Rating or 6,Team=side,Match=side=="Home"and serialized.Home or serialized.Away,Full=serialized,MOTM=serialized.MOTM}
			end
			self.RankedProfiles:RecordServerResult(home,homeResult,rpFor(homeResult),away.Name,score,personal("Home"))
			self.RankedProfiles:RecordServerResult(away,awayResult,rpFor(awayResult),home.Name,tostring(awayScore).."-"..tostring(homeScore),personal("Away"))
			if self.Publish and self.RankedProfiles.GetClientData then
				pcall(function()self.Publish(home,"Ranked",self.RankedProfiles:GetClientData(home))end)
				pcall(function()self.Publish(away,"Ranked",self.RankedProfiles:GetClientData(away))end)
			end
		end''',
1
)

ranked_queue_path.write_text(ranked_queue, encoding="utf-8", newline="\n")

print("fixed audio cutoff, intro audio, pass goals, throw-ins, corner target selection, auto decisions, ranked progression, and pack inventory publish")