from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = gameplay.replace(
'''self.MatchInPlay=payload.Phase=="IN PLAY";if self.MatchInPlay and self.PendingKickoffSound and self.MatchSounds then self.PendingKickoffSound=false;self.MatchSounds:PlayKickoff()end;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.MatchInPlay and self.WatchMode~=true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;''',
'''self.MatchInPlay=payload.Phase=="IN PLAY";if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.MatchInPlay and self.WatchMode~=true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;''',
1
)

gameplay = gameplay.replace(
'''	elseif payload.Type=="Pass"then if self.MatchSounds then self.MatchSounds:PlayKick()end;if self.HUD then self.HUD:HideKickoffScorer()end;if self.Ball then self.Ball.LocalTransparencyModifier=0 end;if self.Visual then self.Visual:PlayFlightTrail()end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Pass")end''',
'''	elseif payload.Type=="Pass"then if self.MatchSounds then if self.PendingKickoffSound then self.PendingKickoffSound=false;self.MatchSounds:PlayKickoff()else self.MatchSounds:PlayKick()end end;if self.HUD then self.HUD:HideKickoffScorer()end;if self.Ball then self.Ball.LocalTransparencyModifier=0 end;if self.Visual then self.Visual:PlayFlightTrail()end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Pass")end;if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Pass")end''',
1
)

gameplay = gameplay.replace(
'''	elseif payload.Type=="Shot"then if self.MatchSounds then self.MatchSounds:PlayKick()end;if self.CrowdAmbience then self.CrowdAmbience:Boost(0.9)end;if self.ReplayController then self.ReplayController:MarkShot(payload.Actor)end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if self.HUD then self.HUD:ShowShotChance(payload.ShotXG or payload.ScoringChance or payload.ScoringChancePercent,payload.Actor)end;if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Shoot")end''',
'''	elseif payload.Type=="Shot"then if self.MatchSounds then self.MatchSounds:PlayKick()end;if self.SetPieceKind=="FreeKick" and self.Camera and self.Camera.EndCutscene then task.delay(.35,function()if self.Camera then self.Camera:EndCutscene()end end)end;if self.CrowdAmbience then self.CrowdAmbience:Boost(0.9)end;if self.ReplayController then self.ReplayController:MarkShot(payload.Actor)end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if self.HUD then self.HUD:ShowShotChance(payload.ShotXG or payload.ScoringChance or payload.ScoringChancePercent,payload.Actor)end;if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Shoot")end''',
1
)

gameplay = gameplay.replace(
'''	elseif payload.Type=="Kickoff"then if self.MatchSounds then self.MatchSounds:PlayKickoff()end;if self.Visual then self.Visual:StopShotTrail()end;self.HUD:Flash("Kick Off",1)''',
'''	elseif payload.Type=="Kickoff"then if self.Visual then self.Visual:StopShotTrail()end;self.HUD:Flash("Kick Off",1)''',
1
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

camera_path = Path("src/client/Gameplay/BroadcastCameraController.lua")
camera = camera_path.read_text(encoding="utf-8")
camera = camera.replace("local BROADCAST_ZOOM_MULTIPLIER = 0.8", "local BROADCAST_ZOOM_MULTIPLIER = 0.68")
camera = camera.replace("local BROADCAST_FOV = 37", "local BROADCAST_FOV = 34")
camera = camera.replace("Broadcast = {Height = 128, Side = 160, Fov = 37, Smooth = 0.11}", "Broadcast = {Height = 108, Side = 136, Fov = 34, Smooth = 0.10}")
camera = camera.replace('["End to End"] = {Height = 174, Side = 0, Fov = 42, Smooth = 0.12}', '["End to End"] = {Height = 148, Side = 0, Fov = 39, Smooth = 0.11}')
camera_path.write_text(camera, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = runtime.replace(
'''broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=(restartMode=="DirectShotFreeKick"or restartMode=="Penalty") and payload.Type=="Shot"})''',
'''broadcast(self.State,session,{Type="Phase",Phase="IN PLAY",HoldCutscene=(restartMode=="Penalty") and payload.Type=="Shot"})''',
1
)

runtime = runtime.replace(
'''if kind~="Kickoff"then session.Clock:Record(kind)end''',
'''if kind~="Kickoff"then session.Clock:Record(kind)end''',
1
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

setpiece_path = Path("src/server/Gameplay/SetPieceService.lua")
setpiece = setpiece_path.read_text(encoding="utf-8")

setpiece = replace_once(
setpiece,
'''	local attackers=teams[restartTeam]
	for index,model in attackers do
		if model~=taker then
			local x=((index%5)-2)*13
			local z=goalSign*(length*.5-34-(index%3)*6)
			if index==4 or index==5 then z=0 end
			face(model,localWorld(pitchCFrame,x,3,z),location)
		end
	end''',
'''	local attackers=teams[restartTeam]
	for index,model in attackers do
		if model~=taker then
			if isKeeper(model) then
				local homeSpot=localWorld(pitchCFrame,0,3,-goalSign*(length*.5-8))
				face(model,homeSpot,location)
				model:SetAttribute("VTRForceIdle",true)
			else
				local x=((index%5)-2)*13
				local z=goalSign*(length*.5-34-(index%3)*6)
				if index==4 or index==5 then z=0 end
				face(model,localWorld(pitchCFrame,x,3,z),location)
			end
		end
	end''',
"free kick attackers keeper home"
)

setpiece_path.write_text(setpiece, encoding="utf-8", newline="\n")

ref_path = Path("src/server/Gameplay/RefereeService.lua")
ref = ref_path.read_text(encoding="utf-8")

ref = ref.replace(
'''	local inWidth=math.abs(localPoint.X)<=22
	if not inWidth then return nil end
	local nearPositive=math.abs((self.Length*.5)-localPoint.Z)<=18
	local nearNegative=math.abs((-self.Length*.5)-localPoint.Z)<=18''',
'''	local inWidth=math.abs(localPoint.X)<=44
	if not inWidth then return nil end
	local nearPositive=localPoint.Z >= self.Length*.5 - 82
	local nearNegative=localPoint.Z <= -self.Length*.5 + 82''',
1
)

ref = ref.replace(
'''	local restartKind=(boxOwner~=nil and boxOwner==team and victimTeam==restartTeam)and"Penalty"or"FreeKick"''',
'''	local restartKind=(boxOwner~=nil and boxOwner==team and victimTeam==restartTeam)and"Penalty"or"FreeKick"''',
1
)

ref_path.write_text(ref, encoding="utf-8", newline="\n")

clock_path = Path("src/server/Gameplay/MatchClockService.lua")
clock = clock_path.read_text(encoding="utf-8")

clock = clock.replace(
'''local STOPPAGE_MINUTES = {Goal = 0.75, Foul = 0.55, Corner = 0.22, GoalKick = 0.14, ThrowIn = 0.12, Injury = 1.0, Substitution = 0.55}''',
'''local STOPPAGE_MINUTES = {Goal = 0.95, Foul = 0.65, Corner = 0.25, GoalKick = 0.18, ThrowIn = 0.14, FreeKick = 0.28, Penalty = 0.55, Injury = 1.0, Substitution = 0.55}''',
1
)

clock = clock.replace(
'''		self.AddedMinutes = raw <= 0.05 and 0 or math.clamp(math.floor(raw + 0.65), 1, 5)''',
'''		self.AddedMinutes = raw <= 0.05 and 0 or math.clamp(math.floor(raw + 0.65), 1, 7)''',
1
)

clock_path.write_text(clock, encoding="utf-8", newline="\n")

hud_path = Path("src/client/Gameplay/MatchHUDController.lua")
hud = hud_path.read_text(encoding="utf-8")

new_set_clock = '''function Controller:SetClock(seconds: number, home: number?, away: number?, addedMinutes: number?, inAddedTime: boolean?, addedElapsed: number?)
	local value = math.max(0, tonumber(seconds) or 0)
	local halfBase = value >= 2700 and 45 or 0
	local minute = math.floor(value / 60)
	local second = math.floor(value % 60)
	if inAddedTime then
		local base = value >= 5400 and 90 or 45
		local added = math.max(1, math.ceil((tonumber(addedElapsed) or 0) / 60))
		self.Clock.Text = string.format("%d+%d", base, added)
	else
		self.Clock.Text = string.format("%02d:%02d", minute, second)
	end
	if not self.AddedTimeLabel and self.ClockPanel then
		local added = label(self.ClockPanel, "", UDim2.new(1, -42, 0, 0), UDim2.fromOffset(40, 18), 9)
		added.Name = "AddedTimeLabel"
		added.TextXAlignment = Enum.TextXAlignment.Center
		added.TextColor3 = Theme.Colors.Black
		added.BackgroundColor3 = Theme.Colors.Electric
		added.BackgroundTransparency = .06
		added.Visible = false
		added.ZIndex = self.Clock.ZIndex + 2
		corner(added, 3)
		self.AddedTimeLabel = added
	end
	local addedTotal = tonumber(addedMinutes) or 0
	if self.AddedTimeLabel then
		self.AddedTimeLabel.Visible = addedTotal > 0
		self.AddedTimeLabel.Text = "+" .. tostring(addedTotal)
	end
	if home ~= nil then self.HomeScoreLabel.Text = tostring(home) end
	if away ~= nil then self.AwayScoreLabel.Text = tostring(away) end
end'''

hud, count = re.subn(
	r'''function Controller:SetClock\(seconds: number, home: number\?, away: number\?, addedMinutes: number\?, inAddedTime: boolean\?, addedElapsed: number\?\)
.*?
end''',
	new_set_clock,
	hud,
	count=1,
	flags=re.S
)

if count == 0:
	hud = hud.replace(
'''function Controller:SetPhase(value: string)''',
new_set_clock + "\n\nfunction Controller:SetPhase(value: string)",
1
)

hud_path.write_text(hud, encoding="utf-8", newline="\n")

print("fixed kickoff whistle timing, broadcast zoom, free kick camera release, keeper free kick position, box fouls, and extra time display")