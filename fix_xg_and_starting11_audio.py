from pathlib import Path
import re

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
	if goalChance>=.995 then
		if shooter then
			shooter:SetAttribute("VTRShotXG",1)
			shooter:SetAttribute("VTRShotSaveChance",0)
		end
		return 0
	end
	if goalChance<=.005 then
		if shooter then
			shooter:SetAttribute("VTRShotXG",0)
			shooter:SetAttribute("VTRShotSaveChance",.99)
		end
		return .99
	end
	if shooter then
		shooter:SetAttribute("VTRShotXG",goalChance)
		shooter:SetAttribute("VTRShotSaveChance",1-goalChance)
	end
	return 1-goalChance
end''',
gk,
count=1,
flags=re.S
)

gk = gk.replace(
	'local chance=saveProbability(keeper,rectangle,target,time,self.BallService.LastShotXG,self.BallService.LastShooter)',
	'local chance=saveProbability(keeper,rectangle,target,time,self.BallService.LastShotChance,self.BallService.LastShooter)',
	1
)

gk_path.write_text(gk, encoding="utf-8", newline="\n")

sound_path = Path("src/client/Gameplay/MatchSoundController.lua")
sound = sound_path.read_text(encoding="utf-8")

sound = sound.replace(
	'local DRIBBLE_SOUND = "rbxassetid://108255149267958"',
	'local DRIBBLE_SOUND = "rbxassetid://108878640377793"',
	1
)

sound = sound.replace(
	'playOneShot(DRIBBLE_SOUND, 0.18, math.random(96, 104) / 100)',
	'playOneShot(DRIBBLE_SOUND, 0.24, math.random(96, 104) / 100)',
	1
)

sound_path.write_text(sound, encoding="utf-8", newline="\n")

presentation_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
presentation = presentation_path.read_text(encoding="utf-8")

if 'local SoundService = game:GetService("SoundService")' not in presentation:
	presentation = presentation.replace(
		'local TweenService = game:GetService("TweenService")',
		'local TweenService = game:GetService("TweenService")\nlocal SoundService = game:GetService("SoundService")',
		1
	)

if "STARTING_XI_SOUND_ONE" not in presentation:
	presentation = presentation.replace(
'''local Presentation = {}
local TOTAL_DURATION = 66.0''',
'''local Presentation = {}
local TOTAL_DURATION = 66.0
local STARTING_XI_SOUND_ONE = "rbxassetid://111250989374137"
local STARTING_XI_SOUND_TWO = "rbxassetid://76843129252399"

local function playPresentationSound(soundId: string, volume: number?)
	local sound = Instance.new("Sound")
	sound.Name = "VTRStartingXIAudio"
	sound.SoundId = soundId
	sound.Volume = volume or .62
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		if sound.Parent then sound:Destroy() end
	end)
	sound:Play()
	task.delay(8, function()
		if sound.Parent then sound:Destroy() end
	end)
end'''
		,1
	)

presentation = presentation.replace(
'''	task.delay(31.0, function()
		slideOut(playerCard, UDim2.fromScale(0.37, 0.86))''',
'''	task.delay(31.0, function()
		playPresentationSound(STARTING_XI_SOUND_ONE,.66)
		slideOut(playerCard, UDim2.fromScale(0.37, 0.86))''',
1
)

presentation = presentation.replace(
'''	task.delay(51.0, function()
		slideOut(playerCard, UDim2.fromScale(0.37, 0.86))''',
'''	task.delay(51.0, function()
		playPresentationSound(STARTING_XI_SOUND_TWO,.66)
		slideOut(playerCard, UDim2.fromScale(0.37, 0.86))''',
1
)

presentation_path.write_text(presentation, encoding="utf-8", newline="\n")

print("fixed xg save math, guaranteed 1.00 xg goals, starting xi audio, and running-with-ball dribble audio")