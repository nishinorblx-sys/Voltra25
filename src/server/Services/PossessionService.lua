--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local PossessionService = {}
PossessionService.__index = PossessionService

function PossessionService.new(ball: BasePart, stateRemote: RemoteEvent)
	local self = setmetatable({ Ball = ball, StateRemote = stateRemote, Owner = nil, BlockedUntil = {} }, PossessionService)
	ball:SetAttribute("OwnerUserId", 0)
	Players.PlayerRemoving:Connect(function(player)
		self.BlockedUntil[player] = nil
		if self.Owner == player then self:Release(nil, 0) end
	end)
	return self
end

function PossessionService:GetOwner(): Player?
	return self.Owner
end

function PossessionService:BlockPickup(player: Player, duration: number)
	self.BlockedUntil[player] = os.clock() + math.clamp(duration, 0, 2)
end

function PossessionService:CanPickup(player: Player): boolean
	if self.Owner or (self.BlockedUntil[player] or 0) > os.clock() then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	return (root.Position - self.Ball.Position).Magnitude <= Config.Ball.PossessionRange
end

function PossessionService:TryPickup(player: Player): boolean
	if not self:CanPickup(player) then return false end
	self.Owner = player
	self.Ball:SetAttribute("OwnerUserId", player.UserId)
	self.StateRemote:FireAllClients({ Type = "Possession", OwnerUserId = player.UserId })
	return true
end

function PossessionService:Release(velocity: Vector3?, blockDuration: number?)
	local oldOwner = self.Owner
	self.Owner = nil
	self.Ball:SetAttribute("OwnerUserId", 0)
	if oldOwner then self:BlockPickup(oldOwner, blockDuration or Config.Ball.PickupCooldown) end
	if velocity then self.Ball.AssemblyLinearVelocity = velocity end
	self.StateRemote:FireAllClients({ Type = "Possession", OwnerUserId = 0 })
end

function PossessionService:ForceReset()
	self.Owner = nil
	table.clear(self.BlockedUntil)
	self.Ball:SetAttribute("OwnerUserId", 0)
	self.StateRemote:FireAllClients({ Type = "Possession", OwnerUserId = 0 })
end

return PossessionService
