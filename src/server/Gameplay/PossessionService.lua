--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)

local Service = {}
Service.__index = Service

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function alive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return root(model) ~= nil and humanoid ~= nil and humanoid.Health > 0
end

function Service.new(ball: BasePart, stateRemote: RemoteEvent)
	return setmetatable({Ball = ball, Remote = stateRemote, Owner = nil, Blocked = {}}, Service)
end

function Service:GetOwner(): Model?
	return self.Owner
end

function Service:_setOwner(model: Model)
	local now = os.clock()
	self.Owner = model
	model:SetAttribute("VTRHasBall", true)
	model:SetAttribute("VTRPossessionStartedAt", now)
	if tostring(model:GetAttribute("position") or "") == "GK" then
		model:SetAttribute("VTRGoalkeeperTackleImmuneUntil", now + 3)
	end
	local displayName = model:GetAttribute("DisplayName") or model.Name
	local team = model:GetAttribute("VTRTeam")
	self.Ball:SetAttribute("OwnerModel", model.Name)
	self.Ball:SetAttribute("OwnerUserId", model:GetAttribute("VTRUserId") or 0)
	self.Ball:SetAttribute("VTRPossessionTeam", team)
	self.Remote:FireAllClients({Type = "Possession", Owner = displayName, OwnerUserId = model:GetAttribute("VTRUserId") or 0, Model = model, Team = team})
end

function Service:CanPickup(model: Model): boolean
	local modelRoot = root(model)
	return self.Owner == nil
		and modelRoot ~= nil
		and alive(model)
		and (self.Blocked[model] or 0) <= os.clock()
		and (tonumber(model:GetAttribute("VTRCannotRecoverBallUntil")) or 0) <= os.clock()
		and (modelRoot.Position - self.Ball.Position).Magnitude <= Config.Ball.PossessionRange
end

function Service:Pickup(model: Model): boolean
	if not self:CanPickup(model) then return false end
	self:_setOwner(model)
	return true
end

function Service:ForcePickup(model: Model, maxDistance: number?): boolean
	local modelRoot = root(model)
	if not modelRoot or not alive(model) then return false end
	if maxDistance and (modelRoot.Position - self.Ball.Position).Magnitude > math.max(0, maxDistance) then return false end
	if model:GetAttribute("VTRSetPieceTaker") ~= true and ((tonumber(model:GetAttribute("VTRCannotRecoverBallUntil")) or 0) > os.clock() or (tonumber(model:GetAttribute("VTRStunnedUntil")) or 0) > os.clock()) then return false end
	if self.Owner and self.Owner ~= model then self.Owner:SetAttribute("VTRHasBall", false) end
	table.clear(self.Blocked)
	self:_setOwner(model)
	return true
end

function Service:Block(model: Model, duration: number)
	self.Blocked[model] = os.clock() + math.clamp(duration, 0, 2)
end

function Service:Release(velocity: Vector3?, duration: number?)
	local old = self.Owner
	self.Owner = nil
	if old then old:SetAttribute("VTRHasBall", false) end
	self.Ball:SetAttribute("OwnerModel", "")
	self.Ball:SetAttribute("OwnerUserId", 0)
	self.Ball:SetAttribute("VTRPossessionTeam", "")
	if old then self:Block(old, duration or Config.Ball.PickupCooldown) end
	if velocity then self.Ball.AssemblyLinearVelocity = velocity end
	self.Remote:FireAllClients({Type = "Possession", Owner = "", OwnerUserId = 0, Model = nil})
end

function Service:Reset()
	if self.Owner then self.Owner:SetAttribute("VTRHasBall", false) end
	self.Owner = nil
	table.clear(self.Blocked)
	self.Ball:SetAttribute("OwnerModel", "")
	self.Ball:SetAttribute("OwnerUserId", 0)
	self.Ball:SetAttribute("VTRPossessionTeam", "")
	self.Remote:FireAllClients({Type = "Possession", Owner = "", OwnerUserId = 0, Model = nil})
end

return Service
