--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local BallService = {}
BallService.__index = BallService

local function horizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function validDirection(value: any): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and value.Magnitude >= 0.2 and value.Magnitude <= Config.Validation.MaximumPayloadMagnitude
end

function BallService.new(ball: BasePart, possession: any, stateRemote: RemoteEvent)
	return setmetatable({ Ball = ball, Possession = possession, StateRemote = stateRemote, LastAction = {}, PickupAccumulator = 0 }, BallService)
end

function BallService:Start()
	self.Ball:SetNetworkOwner(nil)
	RunService.Heartbeat:Connect(function(delta) self:_step(delta) end)
end

function BallService:_character(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then return nil, nil end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

function BallService:_allowed(player: Player, action: string): boolean
	local cooldown = Config.Validation.ActionCooldowns[action]
	if not cooldown then return false end
	self.LastAction[player] = self.LastAction[player] or {}
	local now = os.clock()
	if now - (self.LastAction[player][action] or 0) < cooldown then return false end
	self.LastAction[player][action] = now
	return true
end

function BallService:_aimAllowed(root: BasePart, direction: Vector3): boolean
	local facing = horizontal(root.CFrame.LookVector).Unit
	local aim = horizontal(direction)
	return aim.Magnitude > 0.1 and facing:Dot(aim.Unit) >= Config.Validation.MinimumAimDot
end

function BallService:HandleAction(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.Type) ~= "string" or #payload.Type > 16 then return end
	local action = payload.Type
	if action ~= "Pass" and action ~= "Shot" and action ~= "Tackle" and action ~= "Skill" then return end
	if not self:_allowed(player, action) then return end
	local root, humanoid = self:_character(player)
	if not root or not humanoid or humanoid.Health <= 0 then return end

	if action == "Tackle" then
		local owner = self.Possession:GetOwner()
		if not owner or owner == player then return end
		local ownerRoot = self:_character(owner)
		if not ownerRoot or (ownerRoot.Position - root.Position).Magnitude > Config.Ball.TackleRange then return end
		local towardOwner = horizontal(ownerRoot.Position - root.Position)
		if towardOwner.Magnitude < 0.1 or horizontal(root.CFrame.LookVector).Unit:Dot(towardOwner.Unit) < 0.15 then return end
		self.Possession:BlockPickup(owner, 0.65)
		self.Possession:Release(towardOwner.Unit * 24 + Vector3.new(0, 7, 0), 0.65)
		self.Possession:BlockPickup(player, 0.12)
		self.StateRemote:FireAllClients({ Type = "Tackle", UserId = player.UserId })
		return
	end

	if self.Possession:GetOwner() ~= player then return end
	if (root.Position - self.Ball.Position).Magnitude > Config.Ball.PossessionRange + 3 then
		self.Possession:Release(nil, 0.2)
		return
	end
	if not validDirection(payload.Direction) or not self:_aimAllowed(root, payload.Direction) then return end
	local direction = payload.Direction.Unit
	if action == "Pass" then
		local passDirection = (horizontal(direction).Unit + Vector3.new(0, 0.035, 0)).Unit
		self.Possession:Release(passDirection * Config.Ball.PassSpeed, Config.Ball.PickupCooldown)
	elseif action == "Shot" then
		if type(payload.Charge) ~= "number" or payload.Charge ~= payload.Charge or payload.Charge == math.huge or payload.Charge == -math.huge then return end
		local charge = math.clamp(payload.Charge, 0, 1)
		local speed = Config.Ball.ShotMinSpeed + (Config.Ball.ShotMaxSpeed - Config.Ball.ShotMinSpeed) * charge
		local shotDirection = (horizontal(direction).Unit + Vector3.new(0, Config.Ball.ShotLift + charge * 0.08, 0)).Unit
		self.Possession:Release(shotDirection * speed, 0.55)
	elseif action == "Skill" then
		local touchDirection = (horizontal(direction).Unit + Vector3.new(0, 0.12, 0)).Unit
		self.Possession:Release(touchDirection * Config.Ball.SkillTouchSpeed, 0.22)
	end
end

function BallService:_step(delta: number)
	local owner = self.Possession:GetOwner()
	if owner then
		local root, humanoid = self:_character(owner)
		if not root or not humanoid or humanoid.Health <= 0 then self.Possession:Release(nil, 0); return end
		local distance = (root.Position - self.Ball.Position).Magnitude
		if distance > Config.Ball.PossessionRange + 4 then self.Possession:Release(nil, 0.15); return end
		local direction = horizontal(root.CFrame.LookVector).Unit
		local target = root.Position + direction * Config.Ball.DribbleDistance - Vector3.new(0, Config.Ball.DribbleVerticalOffset, 0)
		local errorVector = horizontal(target - self.Ball.Position)
		local inherited = horizontal(root.AssemblyLinearVelocity)
		local desired = errorVector * Config.Ball.DribbleResponsiveness + inherited * 0.75
		if desired.Magnitude > Config.Ball.MaxDribbleSpeed then desired = desired.Unit * Config.Ball.MaxDribbleSpeed end
		self.Ball.AssemblyLinearVelocity = Vector3.new(desired.X, self.Ball.AssemblyLinearVelocity.Y, desired.Z)
	else
		self.PickupAccumulator += delta
		if self.PickupAccumulator >= 0.1 and self.Ball.AssemblyLinearVelocity.Magnitude < 62 then
			self.PickupAccumulator = 0
			local nearest, nearestDistance = nil, Config.Ball.PossessionRange
			for _, player in Players:GetPlayers() do
				local root, humanoid = self:_character(player)
				if root and humanoid and humanoid.Health > 0 then
					local distance = (root.Position - self.Ball.Position).Magnitude
					if distance < nearestDistance and self.Possession:CanPickup(player) then nearest, nearestDistance = player, distance end
				end
			end
			if nearest then self.Possession:TryPickup(nearest) end
		end
	end
end

return BallService
