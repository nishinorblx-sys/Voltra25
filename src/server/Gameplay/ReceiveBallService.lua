--!strict
local Service = {}
Service.__index = Service
local ReceiverMovementService = require(script.Parent.ReceiverMovementService)

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clearReceiver(receiver: Model)
	ReceiverMovementService.Clear(receiver)
end

function Service.new(ball: BasePart, possession: any, remote: RemoteEvent)
	return setmetatable({Ball = ball, Possession = possession, Remote = remote, Pending = {}}, Service)
end

function Service:Expect(player: Player, receiver: Model, receivePoint: Vector3)
	if (tonumber(receiver:GetAttribute("VTRCannotRecoverBallUntil")) or 0) > os.clock() or (tonumber(receiver:GetAttribute("VTRStunnedUntil")) or 0) > os.clock() then return end
	local receiverRoot = root(receiver)
	if not receiverRoot then return end
	self.Pending[player] = {Model = receiver, Point = receivePoint, Started = os.clock(), InitialDistance = (self.Ball.Position - receivePoint).Magnitude}
end

function Service:Step()
	for player, entry in self.Pending do
		local receiver: Model = entry.Model
		if not receiver.Parent or os.clock() - entry.Started > 4.2 or (tonumber(receiver:GetAttribute("VTRCannotRecoverBallUntil")) or 0) > os.clock() or (tonumber(receiver:GetAttribute("VTRStunnedUntil")) or 0) > os.clock() then
			if receiver.Parent then clearReceiver(receiver) end
			self.Pending[player] = nil
			continue
		end
		local owner = self.Possession:GetOwner()
		if owner == receiver then
			if tostring(receiver:GetAttribute("position") or "") == "GK" then
				self.Ball.AssemblyLinearVelocity = Vector3.zero
				self.Ball.AssemblyAngularVelocity = Vector3.zero
			else
				local control = math.clamp((tonumber(receiver:GetAttribute("BallControl")) or tonumber(receiver:GetAttribute("DRI")) or 60) / 100, 0.35, 0.95)
				self.Ball.AssemblyLinearVelocity *= 0.28 + control * 0.34
			end
			clearReceiver(receiver)
			self.Remote:FireClient(player, {Type = "ReceiveBall", Model = receiver})
			self.Pending[player] = nil
		elseif owner ~= nil and owner ~= receiver then
			clearReceiver(receiver)
			self.Pending[player] = nil
		end
	end
end

function Service:Cancel(player: Player)
	local entry = self.Pending[player]
	if entry and entry.Model and entry.Model.Parent then
		clearReceiver(entry.Model)
	end
	self.Pending[player] = nil
end

function Service:Clear()
	for _, entry in self.Pending do
		if entry.Model and entry.Model.Parent then clearReceiver(entry.Model) end
	end
	table.clear(self.Pending)
end

return Service
