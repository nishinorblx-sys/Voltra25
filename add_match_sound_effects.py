from pathlib import Path

sound_path = Path("src/client/Gameplay/MatchSoundController.lua")
sound_path.write_text('''--!strict
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Controller = {}
Controller.__index = Controller

local KICK_SOUND = "rbxassetid://107963207460422"
local GOAL_COMMENTATOR = "rbxassetid://103341909626250"
local FINAL_WHISTLE = "rbxassetid://72085323238660"
local DRIBBLE_SOUND = "rbxassetid://108255149267958"

local GOAL_SOUNDS = {
	"rbxassetid://78442706550929",
	"rbxassetid://119353871044168",
	"rbxassetid://106000542837895",
}

local function playOneShot(soundId: string, volume: number, speed: number?)
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
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function allModels(teamModels: any): {Model}
	local result = {}
	for _, list in teamModels or {} do
		for _, model in list do
			if typeof(model) == "Instance" and model:IsA("Model") then
				table.insert(result, model)
			end
		end
	end
	return result
end

function Controller.new(ball: BasePart, teamModels: any)
	local self = setmetatable({}, Controller)
	self.Ball = ball
	self.TeamModels = teamModels
	self.Models = allModels(teamModels)
	self.MatchActive = false
	self.LastDribble = 0
	self.Connection = nil
	return self
end

function Controller:Start()
	if self.Connection then return end
	self.Connection = RunService.Heartbeat:Connect(function()
		self:_step()
	end)
end

function Controller:SetMatchActive(active: boolean)
	self.MatchActive = active == true
end

function Controller:PlayKick()
	playOneShot(KICK_SOUND, 0.36, 1)
end

function Controller:PlayGoal()
	playOneShot(GOAL_SOUNDS[math.random(1, #GOAL_SOUNDS)], 0.7, 1)
	task.delay(0.22, function()
		playOneShot(GOAL_COMMENTATOR, 0.76, 1)
	end)
end

function Controller:PlayFinalWhistle()
	playOneShot(FINAL_WHISTLE, 0.72, 1)
end

function Controller:_ownerModel(): Model?
	if not self.Ball then return nil end
	local ownerName = tostring(self.Ball:GetAttribute("OwnerModel") or "")
	if ownerName == "" then return nil end
	for _, model in self.Models do
		if model.Name == ownerName then
			return model
		end
	end
	return nil
end

function Controller:_step()
	if not self.MatchActive then return end
	if os.clock() - self.LastDribble < 1 then return end
	local owner = self:_ownerModel()
	if not owner then return end
	local root = owner:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	if moving < 4 then return end
	self.LastDribble = os.clock()
	playOneShot(DRIBBLE_SOUND, 0.18, math.random(96, 104) / 100)
end

function Controller:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

return Controller
''', encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
text = gameplay_path.read_text(encoding="utf-8")

if "MatchSoundController" not in text:
    if "local CrowdAmbienceController=require(script.Parent.CrowdAmbienceController)" in text:
        text = text.replace(
            "local CrowdAmbienceController=require(script.Parent.CrowdAmbienceController)",
            "local CrowdAmbienceController=require(script.Parent.CrowdAmbienceController)\nlocal MatchSoundController=require(script.Parent.MatchSoundController)",
            1
        )
    else:
        text = text.replace(
            "local CommentaryController=require(script.Parent.CommentaryController)",
            "local CommentaryController=require(script.Parent.CommentaryController)\nlocal MatchSoundController=require(script.Parent.MatchSoundController)",
            1
        )

if "self.MatchSounds=MatchSoundController.new(ball,data.TeamModels)" not in text:
    text = text.replace(
        "self.CrowdAmbience=CrowdAmbienceController.new();self.CrowdAmbience:Start();self.Camera=BroadcastCameraController.new",
        "self.CrowdAmbience=CrowdAmbienceController.new();self.CrowdAmbience:Start();self.MatchSounds=MatchSoundController.new(ball,data.TeamModels);self.MatchSounds:Start();self.Camera=BroadcastCameraController.new",
        1
    )

text = text.replace(
    "self.MatchInPlay=payload.Phase==\"IN PLAY\";if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;",
    "self.MatchInPlay=payload.Phase==\"IN PLAY\";if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;if self.MatchSounds then self.MatchSounds:SetMatchActive(self.MatchInPlay)end;",
    1
)

text = text.replace(
    "elseif payload.Type==\"Pass\"then if self.HUD then",
    "elseif payload.Type==\"Pass\"then if self.MatchSounds then self.MatchSounds:PlayKick()end;if self.HUD then",
    1
)

text = text.replace(
    "elseif payload.Type==\"Shot\"then if self.CrowdAmbience then self.CrowdAmbience:Boost(0.9)end;if self.ReplayController then",
    "elseif payload.Type==\"Shot\"then if self.MatchSounds then self.MatchSounds:PlayKick()end;if self.CrowdAmbience then self.CrowdAmbience:Boost(0.9)end;if self.ReplayController then",
    1
)

text = text.replace(
    "elseif payload.Type==\"Goal\"then if self.CrowdAmbience then self.CrowdAmbience:Boost(3.2)end;",
    "elseif payload.Type==\"Goal\"then if self.MatchSounds then self.MatchSounds:PlayGoal()end;if self.CrowdAmbience then self.CrowdAmbience:Boost(3.2)end;",
    1
)

text = text.replace(
    "elseif payload.Type==\"MatchEnded\"then\n\t\tRunService:UnbindFromRenderStep(\"VTRMatchGameplay\")",
    "elseif payload.Type==\"MatchEnded\"then\n\t\tif self.MatchSounds then self.MatchSounds:PlayFinalWhistle()end\n\t\tRunService:UnbindFromRenderStep(\"VTRMatchGameplay\")",
    1
)

text = text.replace(
    "if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end\n\t\tif self.CrowdAmbience then self.CrowdAmbience:Destroy();self.CrowdAmbience=nil end",
    "if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end\n\t\tif self.MatchSounds then self.MatchSounds:Destroy();self.MatchSounds=nil end\n\t\tif self.CrowdAmbience then self.CrowdAmbience:Destroy();self.CrowdAmbience=nil end",
    1
)

text = text.replace(
    "if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end;if self.CrowdAmbience then",
    "if self.ReplayController then self.ReplayController:Destroy();self.ReplayController=nil end;if self.MatchSounds then self.MatchSounds:Destroy();self.MatchSounds=nil end;if self.CrowdAmbience then",
    1
)

gameplay_path.write_text(text, encoding="utf-8", newline="\n")

print("added match sound effects")