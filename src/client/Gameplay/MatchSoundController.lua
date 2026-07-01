--!strict
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Controller = {}
Controller.__index = Controller

local KICK_SOUND = "rbxassetid://107963207460422"
local KICKOFF_SOUND = "rbxassetid://99361731737732"
local GOAL_COMMENTATORS = {
	"rbxassetid://103341909626250",
	"rbxassetid://74702312530338",
	"rbxassetid://103290564397158",
	"rbxassetid://85367905011258",
	"rbxassetid://117754134274157",
	"rbxassetid://72037349498821",
	"rbxassetid://95283998273205",
	"rbxassetid://135072046987673",
}
local FINAL_WHISTLE = "rbxassetid://135741471105087"
local DRIBBLE_SOUND = "rbxassetid://108878640377793"

local GOAL_SOUNDS = {
	"rbxassetid://78442706550929",
	"rbxassetid://119353871044168",
	"rbxassetid://106000542837895",
	"rbxassetid://75642333208760",
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
	self.LastGoalSfxAt = 0
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

function Controller:PlayKickoff()
	playOneShot(KICKOFF_SOUND, 0.62, 1)
end

function Controller:PlayGoal()
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
	playOneShot(DRIBBLE_SOUND, 0.24, math.random(96, 104) / 100)
end

function Controller:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

return Controller
