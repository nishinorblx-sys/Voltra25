from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

setup_path = Path("src/server/Services/MatchSetupService.lua")
setup = setup_path.read_text(encoding="utf-8")

setup = replace_once(
    setup,
'''	options:SetTeleportData({MatchMode="AICampaignSolo",Action=action,ReturnPlaceId=game.PlaceId})''',
'''	local profile=self.Profiles:GetProfile(player)
	local setupSnapshot=profile and profile.MatchSetup and table.clone(profile.MatchSetup) or nil
	options:SetTeleportData({MatchMode="AICampaignSolo",Action=action,ReturnPlaceId=game.PlaceId,Setup=setupSnapshot})''',
    "teleport setup snapshot"
)

setup = re.sub(
r'''function Service:HandleSoloCampaignTeleport\(player:Player\):boolean
.*?
end

function Service:GetClientData''',
'''function Service:HandleSoloCampaignTeleport(player:Player):boolean
	local joinData=player:GetJoinData()
	local teleportData=joinData and joinData.TeleportData
	if type(teleportData)~="table" or teleportData.MatchMode~="AICampaignSolo" then return false end
	player:SetAttribute("VTRAICampaignSoloServer",true)
	player:SetAttribute("VTRAICampaignAutoStarting",true)
	task.spawn(function()
		local started=os.clock()
		local action=tostring(teleportData.Action or "Manual")
		while player.Parent==Players and os.clock()-started<45 do
			local profile=self.Profiles:GetProfile(player)
			if profile then
				if type(teleportData.Setup)=="table" then
					profile.MatchSetup=table.clone(teleportData.Setup)
					profile.MatchSetup.Completed=true
				end
				local character=player.Character
				if character and character:FindFirstChildOfClass("Humanoid") then
					local ok,message,data
					if action=="Manage" then
						ok,message,data=self:WatchMatch(player)
					else
						ok,message,data=self:StartMatch(player)
					end
					if ok then
						player:SetAttribute("VTRAICampaignAutoStarting",false)
						return
					end
				end
			end
			task.wait(.35)
		end
		player:SetAttribute("VTRAICampaignAutoStarting",false)
	end)
	return true
end

function Service:GetClientData''',
setup,
count=1,
flags=re.S
)

setup_path.write_text(setup, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = replace_once(
    ball,
'''		self.LastShotChance=shotChance
		self.LastShotChancePercent=math.floor(shotChance*100+.5)
		self.LastShotXG=xg;self.LastShooter=model;self.Stats:RecordShot(model,targetPoint~=nil,xg)''',
'''		self.LastShotChance=shotChance
		self.LastShotChancePercent=math.floor(shotChance*100+.5)
		self.LastShotXG=shotChance
		self.LastShooter=model
		self.Stats:RecordShot(model,targetPoint~=nil,shotChance)''',
    "shot xg equals scoring chance"
)

ball = replace_once(
    ball,
'''		eventPayload.ShotXG=self.LastShotChance
		eventPayload.StatsXG=self.LastShotXG''',
'''		eventPayload.ShotXG=self.LastShotChance
		eventPayload.StatsXG=self.LastShotChance''',
    "shot event xg same chance"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

gk = re.sub(
r'''local function saveProbability\(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number\?,shooter:Model\?\):number
.*?
end''',
'''local function saveProbability(keeper:Model,rectangle:any,target:Vector3,time:number,xg:number?,shooter:Model?):number
	local shooterRoot=root(shooter)
	local goalChance=tonumber(xg)
	if goalChance==nil or goalChance<=0 then
		local distance=160
		if shooterRoot then
			local goalCenter=GoalModelResolver.Point(rectangle,(rectangle.Left+rectangle.RightBound)*.5,(rectangle.Bottom+rectangle.Top)*.5)
			distance=Vector3.new(shooterRoot.Position.X-goalCenter.X,0,shooterRoot.Position.Z-goalCenter.Z).Magnitude
		end
		goalChance=distanceGoalChance(distance)
	end
	goalChance=math.clamp(goalChance,0,1)
	local saveChance=1-goalChance
	if goalChance>=.999 then
		goalChance=1
		saveChance=0
	elseif goalChance<=.001 then
		goalChance=0
		saveChance=.99
	else
		saveChance=math.clamp(saveChance,.01,.99)
	end
	if shooter then
		shooter:SetAttribute("VTRShotXG",goalChance)
		shooter:SetAttribute("VTRShotSaveChance",saveChance)
	end
	return saveChance
end''',
gk,
count=1,
flags=re.S
)

gk = gk.replace(
    'local chance=saveProbability(keeper,rectangle,target,time,self.BallService.LastShotXG,self.BallService.LastShooter)',
    'local chance=saveProbability(keeper,rectangle,target,time,self.BallService.LastShotChance or self.BallService.LastShotXG,self.BallService.LastShooter)',
    1
)

gk = replace_once(
    gk,
'''	local willSave=self.Random:NextNumber()<=chance''',
'''	local willSave=false
	if chance<=0 then
		willSave=false
	elseif chance>=1 then
		willSave=true
	else
		willSave=self.Random:NextNumber()<=chance
	end''',
    "deterministic save endpoints"
)

gk = replace_once(
    gk,
'''function Service:_finish(save: any)
	local keeper: Model = save.Keeper''',
'''function Service:_finish(save: any)
	if save and save.WillSave==false then
		self:_miss(save)
		return
	end
	local keeper: Model = save.Keeper''',
    "protect no save finish"
)

gk_path.write_text(gk, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = replace_once(
    runtime,
'''for _,participant in session.Players do local state=session.PlayerState[participant];local active=session.TeamControl:GetActive(participant);if active and state then local sprinting=active:GetAttribute("VTRSprintLocked")~=true and(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0)>.1 and state.Stamina>=Config.Stamina.MinimumToSprint;activeOwners[active]=participant;sprintingByModel[active]=sprinting end end''',
'''for _,participant in session.Players do local state=session.PlayerState[participant];local active=session.TeamControl:GetActive(participant);if active and state then local sprintLocked=active:GetAttribute("VTRSprintLocked")==true and active:GetAttribute("controlledByUser")~=true;local sprinting=not sprintLocked and(tonumber(active:GetAttribute("VTRMoveMagnitude"))or 0)>.1 and state.Stamina>=Config.Stamina.MinimumToSprint;activeOwners[active]=participant;sprintingByModel[active]=sprinting end end''',
    "manual sprint without ball"
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

ui_sound_path = Path("src/client/Services/UISoundService.lua")
if ui_sound_path.exists():
    ui = ui_sound_path.read_text(encoding="utf-8")
    ui = re.sub(
r'''local HOVER_SOUNDS = \{
.*?
\}''',
'''local HOVER_SOUNDS = {
	"rbxassetid://98484565371608",
}''',
ui,
count=1,
flags=re.S
    )
    ui_sound_path.write_text(ui, encoding="utf-8", newline="\n")
else:
    print("skipped UISoundService missing")

print("fixed AI campaign autostart, xG keeper save logic, manual no-ball sprint, and hover sound")