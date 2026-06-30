--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local Remotes = require(ReplicatedStorage.VTR.Shared.Remotes)
local BallService = require(script.Parent.BallService)
local PossessionService = require(script.Parent.PossessionService)

local MatchTestService = {}
MatchTestService.__index = MatchTestService

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, transparency: number?, collide: boolean?): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Anchored = true
	result.CanCollide = if collide == nil then true else collide
	result.CanTouch = true
	result.Color = color
	result.Material = Enum.Material.SmoothPlastic
	result.Size = size
	result.Position = position
	result.Transparency = transparency or 0
	result.Parent = parent
	return result
end

function MatchTestService.new()
	return setmetatable({ PlayerState = {}, GoalLocked = false, TeamCounter = 0 }, MatchTestService)
end

function MatchTestService:Start()
	local actionRemote, stateRemote = Remotes.Create()
	self.ActionRemote = actionRemote
	self.StateRemote = stateRemote
	local pitch, ball, score = self:_createWorld()
	self.Pitch = pitch
	self.Ball = ball
	self.Score = score
	self.Possession = PossessionService.new(ball, stateRemote)
	self.BallService = BallService.new(ball, self.Possession, stateRemote)
	self.BallService:Start()

	actionRemote.OnServerEvent:Connect(function(player, payload) self:_onAction(player, payload) end)
	Players.PlayerAdded:Connect(function(player) self:_bindPlayer(player) end)
	Players.PlayerRemoving:Connect(function(player) self.PlayerState[player] = nil end)
	for _, player in Players:GetPlayers() do self:_bindPlayer(player) end
	RunService.Heartbeat:Connect(function(delta) self:_step(delta) end)
end

function MatchTestService:_createWorld(): (Model, BasePart, Folder)
	local old = workspace:FindFirstChild("VTRTestMatch")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "VTRTestMatch"
	model.Parent = workspace

	local width, length = Config.Pitch.Width, Config.Pitch.Length
	part(model, "Pitch", Vector3.new(width, 1, length), Vector3.new(0, -0.5, 0), Color3.fromHex("162B18"), 0, true).Material = Enum.Material.Grass
	part(model, "TouchlineLeft", Vector3.new(0.35, 0.08, length), Vector3.new(-width / 2 + 1, 0.05, 0), Color3.fromHex("D9D9D9"), 0, false)
	part(model, "TouchlineRight", Vector3.new(0.35, 0.08, length), Vector3.new(width / 2 - 1, 0.05, 0), Color3.fromHex("D9D9D9"), 0, false)
	part(model, "GoalLineNorth", Vector3.new(width, 0.08, 0.35), Vector3.new(0, 0.05, -length / 2 + 1), Color3.fromHex("D9D9D9"), 0, false)
	part(model, "GoalLineSouth", Vector3.new(width, 0.08, 0.35), Vector3.new(0, 0.05, length / 2 - 1), Color3.fromHex("D9D9D9"), 0, false)
	part(model, "Halfway", Vector3.new(width - 2, 0.08, 0.35), Vector3.new(0, 0.05, 0), Color3.fromHex("D9D9D9"), 0, false)
	local center = part(model, "CenterSpot", Vector3.new(1, 0.09, 1), Vector3.new(0, 0.07, 0), Color3.fromHex("B7FF1A"), 0, false)
	center.Shape = Enum.PartType.Cylinder
	center.Orientation = Vector3.new(0, 0, 90)

	local wallColor = Color3.fromHex("111111")
	part(model, "WestWall", Vector3.new(2, 12, length + 10), Vector3.new(-width / 2 - 1, 5, 0), wallColor, 0.65, true)
	part(model, "EastWall", Vector3.new(2, 12, length + 10), Vector3.new(width / 2 + 1, 5, 0), wallColor, 0.65, true)
	part(model, "NorthBack", Vector3.new(width + 4, 12, 2), Vector3.new(0, 5, -length / 2 - 4), wallColor, 0.65, true)
	part(model, "SouthBack", Vector3.new(width + 4, 12, 2), Vector3.new(0, 5, length / 2 + 4), wallColor, 0.65, true)

	for _, z in { -length / 2, length / 2 } do
		for _, x in { -Config.Pitch.GoalWidth / 2, Config.Pitch.GoalWidth / 2 } do
			part(model, "GoalPost", Vector3.new(0.7, Config.Pitch.GoalHeight, 0.7), Vector3.new(x, Config.Pitch.GoalHeight / 2, z), Color3.fromHex("F5F7F2"), 0, true)
		end
		part(model, "Crossbar", Vector3.new(Config.Pitch.GoalWidth, 0.7, 0.7), Vector3.new(0, Config.Pitch.GoalHeight, z), Color3.fromHex("F5F7F2"), 0, true)
	end

	local homeSpawn = Instance.new("SpawnLocation")
	homeSpawn.Name = "HomeSpawn"
	homeSpawn.Anchored = true
	homeSpawn.CanCollide = false
	homeSpawn.Transparency = 1
	homeSpawn.Neutral = true
	homeSpawn.Size = Vector3.new(8, 1, 8)
	homeSpawn.CFrame = CFrame.lookAt(Vector3.new(-12, 1, -28), Vector3.new(0, 1, 0))
	homeSpawn.Parent = model
	local awaySpawn = homeSpawn:Clone()
	awaySpawn.Name = "AwaySpawn"
	awaySpawn.CFrame = CFrame.lookAt(Vector3.new(12, 1, 28), Vector3.new(0, 1, 0))
	awaySpawn.Parent = model

	local ball = Instance.new("Part")
	ball.Name = Config.Ball.Name
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Config.Ball.Radius * 2
	ball.Position = Vector3.new(0, Config.Ball.Radius + 0.2, 0)
	ball.Color = Color3.fromHex("F5F7F2")
	ball.Material = Enum.Material.SmoothPlastic
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.45, 0.55, 1, 1)
	ball.Parent = model
	ball:SetNetworkOwner(nil)

	local score = Instance.new("Folder")
	score.Name = "Score"
	score.Parent = model
	local home = Instance.new("IntValue")
	home.Name = "Home"
	home.Parent = score
	local away = Instance.new("IntValue")
	away.Name = "Away"
	away.Parent = score
	return model, ball, score
end

function MatchTestService:_bindPlayer(player: Player)
	if self.PlayerState[player] then return end
	self.TeamCounter += 1
	self.PlayerState[player] = { Stamina = Config.Stamina.Maximum, Sprinting = false, SendAccumulator = 0, LastSprint = 0, Team = if self.TeamCounter % 2 == 0 then "Away" else "Home" }
	player:SetAttribute("MatchTeam", self.PlayerState[player].Team)
	local function spawn(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not humanoid or not root then return end
		humanoid.WalkSpeed = Config.Movement.WalkSpeed
		local spawnPart = self.Pitch:FindFirstChild(self.PlayerState[player].Team .. "Spawn") :: BasePart
		character:PivotTo(spawnPart.CFrame * CFrame.new(0, 4, 0))
	end
	player.CharacterAdded:Connect(spawn)
	if player.Character then task.spawn(spawn, player.Character) end
end

function MatchTestService:_onAction(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.Type) ~= "string" then return end
	if payload.Type == "Sprint" then
		if type(payload.Active) ~= "boolean" then return end
		local state = self.PlayerState[player]
		if not state or os.clock() - state.LastSprint < Config.Validation.ActionCooldowns.Sprint then return end
		state.LastSprint = os.clock()
		state.Sprinting = payload.Active and state.Stamina >= Config.Stamina.MinimumToSprint
		return
	end
	self.BallService:HandleAction(player, payload)
end

function MatchTestService:_step(delta: number)
	for player, state in self.PlayerState do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			local moving = humanoid.MoveDirection.Magnitude > 0.1
			if state.Sprinting and moving and state.Stamina > 0 then
				state.Stamina = math.max(0, state.Stamina - Config.Stamina.DrainPerSecond * delta)
				humanoid.WalkSpeed = Config.Movement.SprintSpeed
				if state.Stamina <= 0 then state.Sprinting = false end
			else
				state.Stamina = math.min(Config.Stamina.Maximum, state.Stamina + Config.Stamina.RecoveryPerSecond * delta)
				humanoid.WalkSpeed = Config.Movement.WalkSpeed
			end
			local horizontalVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
			if horizontalVelocity.Magnitude > Config.Movement.MaxServerHorizontalSpeed then
				local clamped = horizontalVelocity.Unit * Config.Movement.MaxServerHorizontalSpeed
				root.AssemblyLinearVelocity = Vector3.new(clamped.X, root.AssemblyLinearVelocity.Y, clamped.Z)
			end
			state.SendAccumulator += delta
			if state.SendAccumulator >= 0.12 then
				state.SendAccumulator = 0
				self.StateRemote:FireClient(player, { Type = "Stamina", Value = state.Stamina, Sprinting = state.Sprinting })
			end
		end
	end
	if not self.GoalLocked then
		local limit = Config.Pitch.Length / 2 - 0.5
		if math.abs(self.Ball.Position.X) <= Config.Pitch.GoalWidth / 2 then
			if self.Ball.Position.Z >= limit then self:_goal("Home") elseif self.Ball.Position.Z <= -limit then self:_goal("Away") end
		end
	end
end

function MatchTestService:_goal(team: string)
	if self.GoalLocked then return end
	self.GoalLocked = true
	local value = self.Score:FindFirstChild(team) :: IntValue
	value.Value += 1
	self.Possession:ForceReset()
	local homeScore = self.Score:FindFirstChild("Home") :: IntValue
	local awayScore = self.Score:FindFirstChild("Away") :: IntValue
	self.StateRemote:FireAllClients({ Type = "Goal", Team = team, Home = homeScore.Value, Away = awayScore.Value })
	task.delay(1.5, function()
		self.Ball.AssemblyLinearVelocity = Vector3.zero
		self.Ball.AssemblyAngularVelocity = Vector3.zero
		self.Ball.CFrame = CFrame.new(0, Config.Ball.Radius + 0.2, 0)
		self.GoalLocked = false
	end)
end

return MatchTestService
